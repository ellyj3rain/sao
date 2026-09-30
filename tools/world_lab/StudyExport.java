import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.CharBuffer;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;
import java.nio.file.AtomicMoveNotSupportedException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.IdentityHashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.vm.KahluaTableIterator;
import se.krka.kahlua.vm.KahluaUtil;
import zombie.GameWindow;
import zombie.Lua.LuaManager;

/** Tool-owned observation export. Live tables are read only by the game thread. */
public final class StudyExport {
    private static final int MAX_NODES = 262144;
    private static final int MAX_DEPTH = 40;
    private static final long MAX_BYTES = 64L * 1024 * 1024;
    private static StudyExport bound;
    private static KahluaTable boundEnvironment;
    private static Object boundExposer;
    private final Thread owner;
    private final Object publicationLock = new Object();
    private final Map<Long, Receipt> receipts = new LinkedHashMap<>();
    private final ThreadPoolExecutor worker;
    private Epoch epoch;
    private long nextTicket;
    private boolean closed;

    private record Epoch(long number, String key, String definition, String save,
                         String session, String observer, String engine, Path root) {}
    private sealed interface Node permits Scalar, Sequence, Mapping {}
    private record Scalar(Object value) implements Node {}
    private record Sequence(List<Node> values) implements Node {
        Sequence { values = List.copyOf(values); }
    }
    private record Entry(String key, Node value) {}
    private record Mapping(List<Entry> values) implements Node {
        Mapping { values = List.copyOf(values); }
    }
    private static final class Capacity extends RuntimeException {
        final String reason;
        Capacity(String reason) { super(null, null, false, false); this.reason = reason; }
    }
    private static final class Receipt {
        final long ticket;
        final String kind, key;
        final Epoch epoch;
        volatile String status = "reserved";
        volatile String failure;
        volatile String reason;
        volatile long sequence, completedAt;
        Receipt(long ticket, String kind, String key, Epoch epoch) {
            this.ticket = ticket; this.kind = kind; this.key = key; this.epoch = epoch;
        }
    }

    private StudyExport() {
        owner = Thread.currentThread();
        worker = new ThreadPoolExecutor(1, 1, 0, TimeUnit.MILLISECONDS,
            new ArrayBlockingQueue<>(2), task -> {
                Thread thread = new Thread(task, "StudyWorld-export");
                thread.setDaemon(true); thread.setPriority(Thread.MIN_PRIORITY); return thread;
            }, new ThreadPoolExecutor.AbortPolicy());
    }

    public static void bind() {
        requireGameThread();
        if (LuaManager.env == null || LuaManager.exposer == null) return;
        if (bound != null && boundEnvironment == LuaManager.env && boundExposer == LuaManager.exposer) return;
        if (bound != null) bound.retire();
        bound = new StudyExport();
        LuaManager.exposer.setExposed(StudyExport.class);
        LuaManager.exposer.exposeLikeJava(StudyExport.class, LuaManager.env);
        LuaManager.env.rawset("SAO_StudyExport", bound);
        boundEnvironment = LuaManager.env; boundExposer = LuaManager.exposer;
    }
    public static boolean hasPending() {
        requireGameThread(); return bound != null && !bound.receipts.isEmpty();
    }
    public static void shutdown() {
        requireGameThread();
        if (bound == null) return;
        bound.requireOwner();
        if (!bound.receipts.isEmpty()) throw new IllegalStateException("unacknowledged export at shutdown");
        bound.closed = true; bound.worker.shutdown();
    }
    public static void abort() {
        requireGameThread(); if (bound != null) bound.retire();
    }
    private void retire() {
        requireOwner();
        synchronized (publicationLock) { epoch = null; closed = true; receipts.clear(); worker.getQueue().clear(); }
        worker.shutdownNow();
    }
    private static void requireGameThread() {
        if (Thread.currentThread() != GameWindow.gameThread)
            throw new IllegalStateException("study export requires the native game thread");
    }
    private void requireOwner() {
        requireGameThread();
        if (Thread.currentThread() != owner) throw new IllegalStateException("foreign export owner");
    }
    private static String hash(String value) {
        if (value == null || !value.matches("[a-f0-9]{64}")) throw new IllegalArgumentException("invalid export source hash");
        return value;
    }
    private static String identity(String value) {
        if (value == null || value.isEmpty() || value.length() > 256 || value.indexOf('\0') >= 0)
            throw new IllegalArgumentException("invalid export identity");
        return value;
    }
    public void begin(String definition, String save, String session, String observer, String engine) {
        requireOwner();
        if (closed) throw new IllegalStateException("export worker is closed");
        hash(definition); hash(observer); hash(engine); identity(save); identity(session);
        Path root = Path.of(LuaManager.getLuaCacheDir()).toAbsolutePath().normalize();
        synchronized (publicationLock) {
            long number = epoch == null ? 1 : epoch.number() + 1;
            epoch = new Epoch(number, definition + "/" + save + "/" + session,
                definition, save, session, observer, engine, root);
            receipts.clear(); worker.getQueue().clear();
        }
    }
    public double reserve(String kind, String key) {
        requireOwner();
        if (closed || epoch == null) throw new IllegalStateException("export has no active study");
        if (!("live".equals(kind) || "archive".equals(kind)) || key == null
                || !key.startsWith(epoch.key() + "/" + kind + "/") || key.length() > 1024)
            throw new IllegalArgumentException("foreign export reservation");
        for (Receipt receipt : receipts.values()) if (receipt.kind.equals(kind)) return 0;
        if (nextTicket >= 9007199254740991L) throw new IllegalStateException("export ticket exhausted");
        Receipt receipt = new Receipt(++nextTicket, kind, key, epoch);
        receipts.put(receipt.ticket, receipt); return receipt.ticket;
    }
    private Receipt receipt(double ticket) {
        requireOwner();
        if (!Double.isFinite(ticket) || ticket != Math.rint(ticket) || ticket < 1)
            throw new IllegalArgumentException("invalid export ticket");
        Receipt receipt = receipts.get((long) ticket);
        if (receipt == null || receipt.epoch != epoch) throw new IllegalStateException("foreign or retired export ticket");
        return receipt;
    }
    public String receiptStatus(double ticket) {
        String status = receipt(ticket).status; return "reserved".equals(status) ? "pending" : status;
    }
    public String receiptKey(double ticket) { return receipt(ticket).key; }
    public double receiptSequence(double ticket) { return receipt(ticket).sequence; }
    public double receiptCompletedAt(double ticket) { return receipt(ticket).completedAt; }
    public String receiptFailure(double ticket) { return receipt(ticket).failure; }
    public String receiptReason(double ticket) { return receipt(ticket).reason; }
    public void release(double ticket) {
        Receipt receipt = receipt(ticket);
        if ("pending".equals(receipt.status)) throw new IllegalStateException("pending export cannot be released");
        receipts.remove(receipt.ticket);
    }
    public void requestStop(String reason) { requireOwner(); StudyObserver.requestStop(reason); }

    private static long limit(double bytes) {
        if (!Double.isFinite(bytes) || bytes != Math.rint(bytes) || bytes < 0 || bytes > MAX_BYTES)
            throw new IllegalArgumentException("invalid export byte bound");
        return (long) bytes;
    }
    public double measure(Object value, KahluaTable arrayMeta, double maxBytes) {
        requireOwner();
        try { Walker walker = new Walker(arrayMeta, limit(maxBytes), false); walker.walk(value, 0); return walker.used; }
        catch (Capacity capacity) { return -1; }
    }
    public String submitLive(double ticket, KahluaTable frame, KahluaTable arrayMeta, double maxBytes) {
        Receipt receipt = receipt(ticket);
        requireReserved(receipt, "live");
        requireFrame(frame, receipt.epoch, false);
        Node detached = detach(frame, arrayMeta, limit(maxBytes));
        enqueue(receipt, detached, null, null, null, limit(maxBytes)); return "accepted";
    }
    public String submitArchive(double ticket, KahluaTable frame, KahluaTable arrayMeta, double maxBytes,
                                String relativeName, KahluaTable captured, KahluaTable deferred) {
        Receipt receipt = receipt(ticket);
        requireReserved(receipt, "archive");
        requireFrame(frame, receipt.epoch, true);
        Object number = frame.rawget("sequence");
        if (!(number instanceof Double sequence) || !Double.isFinite(sequence)
                || sequence < 1 || sequence != Math.rint(sequence) || sequence > 9007199254740991L
                || !receipt.key.equals(receipt.epoch.key() + "/archive/" + KahluaUtil.numberToString(sequence)))
            throw new IllegalArgumentException("archive sequence differs from reservation");
        receipt.sequence = sequence.longValue();
        String expected = "StudyWorld/" + receipt.epoch.definition() + "/" + saveKey(receipt.epoch.save())
            + "/" + receipt.epoch.session() + "/" + String.format(java.util.Locale.ROOT, "%016d", receipt.sequence) + ".json";
        if (!expected.equals(relativeName)) throw new IllegalArgumentException("foreign archive path");
        Path target = resolve(receipt.epoch.root(), relativeName);
        requireFrame(captured, receipt.epoch, true); requireFrame(deferred, receipt.epoch, true);
        Object hours = frame.rawget("hours");
        if (!(hours instanceof Double clock) || !Double.isFinite(clock)
                || !hours.equals(captured.rawget("worldHours")) || !hours.equals(deferred.rawget("worldHours")))
            throw new IllegalArgumentException("archive status changed captured world clock");
        if (!"captured".equals(captured.rawget("status")) || !number.equals(captured.rawget("sequence"))
                || !"deferred".equals(deferred.rawget("status")) || !number.equals(deferred.rawget("attemptedSequence")))
            throw new IllegalArgumentException("archive status differs from capture");
        Node capturedCopy = detach(captured, arrayMeta, 16384), deferredCopy = detach(deferred, arrayMeta, 16384);
        Node detached;
        try { detached = detach(frame, arrayMeta, limit(maxBytes)); }
        catch (Capacity capacity) {
            detached = null; receipt.reason = capacity.reason;
            List<Entry> fields = new ArrayList<>(((Mapping) deferredCopy).values());
            for (int i = 0; i < fields.size(); i++) if (fields.get(i).key().equals("reason"))
                fields.set(i, new Entry("reason", new Scalar(capacity.reason)));
            deferredCopy = new Mapping(fields);
        }
        enqueue(receipt, detached, target, capturedCopy, deferredCopy, limit(maxBytes)); return "accepted";
    }
    private static void requireFrame(KahluaTable frame, Epoch epoch, boolean archive) {
        if (frame == null || !epoch.definition().equals(frame.rawget("definitionSha256"))
                || !epoch.save().equals(frame.rawget("save")) || !"unreviewed".equals(frame.rawget("datasetAdmission"))
                || archive && (!epoch.session().equals(frame.rawget("session"))
                    || !epoch.observer().equals(frame.rawget("observerSha256"))
                    || !epoch.engine().equals(frame.rawget("packageEngineJarSha256"))))
            throw new IllegalArgumentException("foreign export source identity");
    }
    private static void requireReserved(Receipt receipt, String kind) {
        if (!receipt.kind.equals(kind) || !"reserved".equals(receipt.status))
            throw new IllegalStateException("export reservation already submitted or wrong kind");
    }
    private static String saveKey(String save) {
        StringBuilder key = new StringBuilder();
        for (int i = 0; i < save.length(); i++) key.append(String.format(java.util.Locale.ROOT, "%02x", (int)save.charAt(i)));
        return key.toString();
    }
    private static Path resolve(Path root, String name) {
        if (name == null || name.indexOf('\\') >= 0 || name.indexOf(':') >= 0 || name.indexOf('\0') >= 0)
            throw new IllegalArgumentException("invalid export relative path");
        Path relative = Path.of(name);
        Path target = root.resolve(relative).normalize();
        if (relative.isAbsolute() || !target.startsWith(root) || target.equals(root))
            throw new IllegalArgumentException("export path escaped cache");
        return target;
    }
    private void enqueue(Receipt receipt, Node frame, Path archive, Node captured, Node deferred, long bytes) {
        receipt.status = "pending";
        try { worker.execute(() -> publish(receipt, frame, archive, captured, deferred, bytes)); }
        catch (RuntimeException failure) { fail(receipt, failure); }
    }
    private void publish(Receipt receipt, Node frame, Path archive, Node captured, Node deferred, long bytes) {
        List<Path> temporary = new ArrayList<>();
        try {
            if (Thread.currentThread() == owner) throw new IllegalStateException("encoding returned to live-table owner");
            boolean overflow = frame == null;
            byte[] data = overflow ? null : encode(frame, bytes, archive != null);
            Path target = archive == null ? resolve(receipt.epoch.root(), "StudyWorldLive.json") : archive;
            Path dataTemp = overflow ? null : writeTemporary(target, data, temporary);
            Path statusTarget = null, statusTemp = null;
            if (archive != null) {
                statusTarget = resolve(receipt.epoch.root(), "StudyWorldArchiveStatus.json");
                statusTemp = writeTemporary(statusTarget, encode(overflow ? deferred : captured, 16384, true), temporary);
            }
            synchronized (publicationLock) {
                if (closed || epoch != receipt.epoch || Thread.currentThread().isInterrupted()) return;
                if (dataTemp != null) promote(dataTemp, target);
                if (statusTemp != null) promote(statusTemp, statusTarget);
                receipt.completedAt = System.currentTimeMillis();
                receipt.status = overflow ? "deferred" : "published";
            }
        } catch (Exception failure) { fail(receipt, failure); }
        finally { for (Path path : temporary) try { Files.deleteIfExists(path); } catch (IOException ignored) {} }
    }
    private void fail(Receipt receipt, Exception failure) {
        synchronized (publicationLock) {
            if (epoch != receipt.epoch || closed) return;
            String message = failure.getClass().getSimpleName() + ": " + failure.getMessage();
            receipt.failure = message.substring(0, Math.min(message.length(), 1024));
            receipt.completedAt = System.currentTimeMillis(); receipt.status = "failed";
        }
    }
    private static Path writeTemporary(Path target, byte[] data, List<Path> temporary) throws IOException {
        if (Thread.currentThread().isInterrupted()) throw new IOException("export worker interrupted");
        Files.createDirectories(target.getParent());
        Path path = target.resolveSibling(target.getFileName() + "." + UUID.randomUUID() + ".tmp");
        temporary.add(path); Files.write(path, data);
        if (!Arrays.equals(data, Files.readAllBytes(path))) throw new IOException("export read-back differs");
        return path;
    }
    private static void promote(Path source, Path target) throws IOException {
        IOException last = null;
        for (int attempt = 0; attempt < 8; attempt++) {
            try { Files.move(source, target, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING); return; }
            catch (AtomicMoveNotSupportedException failure) { throw failure; }
            catch (IOException failure) {
                last = failure;
                try { Thread.sleep(25); } catch (InterruptedException interrupted) {
                    Thread.currentThread().interrupt(); throw new IOException("export promotion interrupted", interrupted);
                }
            }
        }
        throw last;
    }

    private static Node detach(Object value, KahluaTable marker, long bytes) {
        return new Walker(marker, bytes, true).walk(value, 0);
    }
    /** Measurement and immutable detachment share the exact scalar/table grammar. */
    private static final class Walker {
        final KahluaTable marker;
        final boolean copying;
        final IdentityHashMap<KahluaTable, Boolean> active = new IdentityHashMap<>();
        long remaining, used;
        int nodes = MAX_NODES;
        Walker(KahluaTable marker, long bytes, boolean copying) {
            if (marker == null) throw new IllegalArgumentException("array marker unavailable");
            this.marker = marker; remaining = bytes; this.copying = copying;
        }
        void charge(long bytes) { if (bytes > remaining) throw new Capacity("encoded-byte-budget"); remaining -= bytes; used += bytes; }
        Node walk(Object value, int depth) {
            if (--nodes < 0) throw new Capacity("detached-node-budget");
            if (depth > MAX_DEPTH) throw new Capacity("detached-depth-budget");
            if (value == null || value instanceof String || value instanceof Boolean || value instanceof Double) {
                if (value instanceof String text) charge(quotedBytes(text));
                else if (value instanceof Double number) {
                    if (!Double.isFinite(number)) throw new IllegalArgumentException("non-finite observation");
                    charge(KahluaUtil.numberToString(number).length());
                } else charge(value == null ? 4 : Boolean.TRUE.equals(value) ? 4 : 5);
                return copying ? new Scalar(value) : null;
            }
            if (!(value instanceof KahluaTable table)) throw new IllegalArgumentException("unsupported observation value");
            if (active.put(table, true) != null) throw new IllegalArgumentException("cyclic observation");
            try {
                charge(2);
                List<Object[]> fields = new ArrayList<>();
                KahluaTableIterator iterator = table.iterator();
                while (iterator.advance()) {
                    if (fields.size() >= nodes) throw new Capacity("detached-node-budget");
                    fields.add(new Object[]{iterator.getKey(), iterator.getValue()});
                }
                int length = table.len();
                if (length > nodes) throw new Capacity("detached-node-budget");
                boolean array = table.getMetatable() == marker;
                if (!array) {
                    array = length > 0 && fields.size() == length;
                    for (Object[] field : fields) if (!(field[0] instanceof Double key)
                            || key != Math.rint(key) || key < 1 || key > length) array = false;
                }
                if (array) {
                    List<Node> values = copying ? new ArrayList<>(length) : null;
                    for (int i = 1; i <= length; i++) {
                        if (i > 1) charge(1);
                        Node child = walk(table.rawget(i), depth + 1); if (copying) values.add(child);
                    }
                    return copying ? new Sequence(values) : null;
                }
                List<Entry> values = copying ? new ArrayList<>(fields.size()) : null;
                for (int i = 0; i < fields.size(); i++) {
                    Object[] field = fields.get(i);
                    String key = keyText(field[0]); charge((i > 0 ? 2 : 1) + quotedBytes(key));
                    Node child = walk(field[1], depth + 1); if (copying) values.add(new Entry(key, child));
                }
                if (copying) values.sort(Comparator.comparing(Entry::key));
                return copying ? new Mapping(values) : null;
            } finally { active.remove(table); }
        }
    }
    private static String keyText(Object value) {
        if (value instanceof String text) return text;
        if (value instanceof Double number && Double.isFinite(number)) return KahluaUtil.numberToString(number);
        if (value instanceof Boolean bool) return bool.toString();
        throw new IllegalArgumentException("unsupported observation key");
    }
    private static long quotedBytes(String text) {
        long bytes = 2;
        for (int i = 0; i < text.length(); i++) {
            char c = text.charAt(i);
            if (c == '"' || c == '\\') bytes += 2;
            else if (c < 32) bytes += 6;
            else if (c < 128) bytes++;
            else if (c < 2048) bytes += 2;
            else if (Character.isHighSurrogate(c) && i + 1 < text.length()
                    && Character.isLowSurrogate(text.charAt(i + 1))) { bytes += 4; i++; }
            else bytes += 3;
        }
        return bytes;
    }
    private static byte[] encode(Node node, long bytes, boolean newline) throws IOException {
        StringBuilder output = new StringBuilder(); append(node, output);
        if (newline) output.append('\n');
        // Native UTF-8 writers replace isolated UTF-16 surrogates, including a
        // supplementary character split by an existing bounded projection.
        ByteBuffer encoded = StandardCharsets.UTF_8.newEncoder().onMalformedInput(CodingErrorAction.REPLACE)
            .onUnmappableCharacter(CodingErrorAction.REPLACE).encode(CharBuffer.wrap(output));
        byte[] result = new byte[encoded.remaining()]; encoded.get(result);
        if (result.length > bytes + (newline ? 1 : 0)) throw new IOException("detached encoding exceeds measured budget");
        return result;
    }
    private static void append(Node node, StringBuilder output) {
        if (Thread.currentThread().isInterrupted()) throw new IllegalStateException("export encoding interrupted");
        if (node instanceof Scalar scalar) {
            Object value = scalar.value();
            if (value instanceof String text) quote(text, output);
            else output.append(value == null ? "null" : value instanceof Double number
                ? KahluaUtil.numberToString(number) : value.toString());
        } else if (node instanceof Sequence sequence) {
            output.append('[');
            for (int i = 0; i < sequence.values().size(); i++) {
                if (i > 0) output.append(','); append(sequence.values().get(i), output);
            }
            output.append(']');
        } else {
            output.append('{'); List<Entry> entries = ((Mapping) node).values();
            for (int i = 0; i < entries.size(); i++) {
                if (i > 0) output.append(',');
                quote(entries.get(i).key(), output); output.append(':'); append(entries.get(i).value(), output);
            }
            output.append('}');
        }
    }
    private static void quote(String text, StringBuilder output) {
        output.append('"');
        for (int i = 0; i < text.length(); i++) {
            char c = text.charAt(i);
            if (c == '"' || c == '\\') output.append('\\').append(c);
            else if (c < 32) output.append("\\u00").append("0123456789abcdef".charAt(c >>> 4))
                .append("0123456789abcdef".charAt(c & 15));
            else output.append(c);
        }
        output.append('"');
    }
}
