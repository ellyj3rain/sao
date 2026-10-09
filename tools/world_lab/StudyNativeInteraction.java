import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.vm.KahluaThread;
import zombie.Lua.LuaManager;
import zombie.core.Core;

/** Fixed native speech seam. File IO stays outside GameWindow.logic; the game
 * thread revalidates the selected body before invoking the installed SAO module.
 * This adapter neither spawns people nor supplies an agent's private knowledge.
 */
public final class StudyNativeInteraction {
    static final String SCHEMA = "sao.native-interaction-command/1";
    static final Set<String> FIELDS = Set.of("schema", "sessionId", "pid", "attempt", "sequence",
        "save", "saveMode", "playerIndex", "playerSqlId", "issuedAtUnixMs", "expiresAtUnixMs",
        "personId", "text", "inputMode", "bindingEpoch");
    record Request(long sequence, Map<String,Object> fields, String invalid) { }
    private static volatile Request pending;
    private static volatile long completed;
    private static String session;
    private static int attempt;
    private static Path directory;
    private static StudyParticipant.StatePublisher writer;
    private static long lastTick;
    private static boolean sampled;
    private static String result;
    private static boolean configured;
    private static long bindingEpoch;
    private static StudyParticipant.Binding epochBody;
    private static String epochMode;

    private StudyNativeInteraction() { }

    public static synchronized void configure() {
        if (configured) throw new IllegalStateException("native interaction already configured");
        if (!Boolean.getBoolean("study.nativePlay") || Boolean.getBoolean("study.observer")
                || !Boolean.getBoolean("study.participantInput"))
            throw new IllegalStateException("native interaction requires real player host");
        session = System.getProperty("study.participantSession", "");
        if (!UUID.fromString(session).toString().equals(session)) throw new IllegalArgumentException("interaction session");
        attempt = Integer.parseInt(System.getProperty("study.attempt", "0"));
        if (attempt < 1) throw new IllegalArgumentException("interaction attempt");
        directory = Path.of(System.getProperty("study.interactionDirectory", ""));
        try {
            if (!directory.isAbsolute() || !Files.isDirectory(directory, LinkOption.NOFOLLOW_LINKS)
                    || !directory.toRealPath().equals(directory.normalize())
                    || !Files.isDirectory(directory.resolve("commands"), LinkOption.NOFOLLOW_LINKS)
                    || Files.isSymbolicLink(directory.resolve("commands")))
                throw new IllegalArgumentException("interaction directory");
        } catch (java.io.IOException failure) { throw new IllegalArgumentException("interaction directory unavailable", failure); }
        writer = new StudyParticipant.StatePublisher(directory.resolve("state.json"), StudyNativeInteraction::publish);
        configured = true;
        Thread reader = new Thread(StudyNativeInteraction::readCommands, "sao-native-interaction-input");
        reader.setDaemon(true); reader.start();
        Runtime.getRuntime().addShutdownHook(new Thread(() -> writer.close(2000), "sao-native-interaction-drain"));
    }

    private static void publish(Path target, String bytes) throws java.io.IOException {
        Path temporary = target.resolveSibling(target.getFileName() + ".tmp");
        Files.writeString(temporary, bytes, StandardCharsets.UTF_8);
        try { Files.move(temporary, target, java.nio.file.StandardCopyOption.ATOMIC_MOVE, java.nio.file.StandardCopyOption.REPLACE_EXISTING); }
        catch (java.nio.file.AtomicMoveNotSupportedException unsupported) {
            Files.move(temporary, target, java.nio.file.StandardCopyOption.REPLACE_EXISTING);
        }
    }

    private static void readCommands() {
        while (!Thread.currentThread().isInterrupted()) {
            try {
                if (pending == null) {
                    long sequence = completed + 1;
                    Path path = directory.resolve("commands").resolve(String.format(java.util.Locale.ROOT, "%016d.json", sequence));
                    if (Files.exists(path, LinkOption.NOFOLLOW_LINKS)) {
                        Request request;
                        try {
                            if (!Files.isRegularFile(path, LinkOption.NOFOLLOW_LINKS) || Files.size(path) > 8192)
                                throw new IllegalArgumentException("unsafe interaction command");
                            String raw = Files.readString(path, StandardCharsets.UTF_8);
                            if (raw.getBytes(StandardCharsets.UTF_8).length > 8192) throw new IllegalArgumentException("interaction size");
                            Map<String,Object> fields = parseFlat(raw, FIELDS);
                            if (integer(fields,"sequence") != sequence) throw new IllegalArgumentException("interaction sequence");
                            request = new Request(sequence, fields, null);
                        } catch (RuntimeException | java.io.IOException refused) {
                            request = new Request(sequence, Map.of(), "Invalid source-bound communication request.");
                        }
                        pending = request;
                    }
                }
                Thread.sleep(50);
            } catch (InterruptedException stopped) { Thread.currentThread().interrupt(); return; }
            catch (RuntimeException unavailable) {
                try { Thread.sleep(100); } catch (InterruptedException stopped) { Thread.currentThread().interrupt(); return; }
            }
        }
    }

    /** Native Lua-owner thread only. No filesystem reads or waits occur here. */
    public static synchronized void poll() {
        if (!configured) return;
        long tick = System.nanoTime(), elapsed = tick - lastTick;
        if (sampled && elapsed >= 0 && elapsed < 100_000_000L) return;
        sampled = true; lastTick = tick;
        KahluaThread luaThread = LuaManager.thread;
        if (!ownsLuaThread(luaThread)) return;
        long now = System.currentTimeMillis();
        StudyParticipant.Binding body = StudyParticipant.binding();
        String mode = body == null ? "" : Core.getInstance().getGameMode();
        if (!ownsLuaThread(luaThread)) return;
        observeEpoch(body, mode);
        Request request = pending;
        if (request != null) {
            String denial = request.invalid();
            if (denial == null) denial = eligibility(request.fields(), body, mode, now, session, attempt,
                ProcessHandle.current().pid(), bindingEpoch);
            String response;
            try {
                response = denial != null ? response("rejected", denial)
                    : call("speak", body.owner(), request.fields().get("personId"), request.fields().get("text"),
                        request.fields().get("inputMode"), Long.toString(request.sequence()), Long.toString(bindingEpoch));
                Map<String,Object> outcome = parseFlat(response, Set.of("status", "message"));
                String status = text(outcome, "status", 16), message = text(outcome, "message", 512);
                if (!Set.of("applied", "rejected").contains(status)) throw new IllegalArgumentException("interaction outcome");
                result = "{\"sequence\":" + request.sequence() + ",\"status\":" + StudyParticipant.quote(status)
                    + ",\"message\":" + StudyParticipant.quote(message) + "}";
                completed = request.sequence(); pending = null;
            } catch (LuaOwnershipUnavailable waiting) {
                // No callback entered: retain the original request and lease.
                // Its identity and expiry are checked again on the owning thread.
            } catch (RuntimeException | LinkageError unavailable) {
                result = "{\"sequence\":" + request.sequence() + ",\"status\":\"unknown\",\"message\":\"Native communication outcome is unknown; the utterance may have been emitted. Inspect retained receipts before another request.\"}";
                completed = request.sequence(); pending = null;
            }
        }
        String people = "{\"people\":[],\"omittedPeople\":0,\"omittedEvents\":0}", availability = "unavailable";
        if (body != null && body.ready() && body.alive()) {
            try { people = call("nearby", body.owner(), Long.toString(bindingEpoch)); availability = "available"; }
            catch (RuntimeException | LinkageError unavailable) { /* No invented people or receipt. */ }
        }
        // Receipt clocks follow the callbacks they describe; an emission inside
        // this sample cannot receive a timestamp later than its enclosing row.
        long observedAt = System.currentTimeMillis(), duration = System.nanoTime() - tick;
        String value = "{\"schema\":\"sao.native-interaction-state/1\",\"sessionId\":" + StudyParticipant.quote(session)
            + ",\"pid\":" + ProcessHandle.current().pid() + ",\"attempt\":" + attempt
            + ",\"save\":" + StudyParticipant.quote(body == null ? "" : body.save())
            + ",\"saveMode\":" + StudyParticipant.quote(mode == null ? "" : mode)
            + ",\"playerIndex\":0,\"playerSqlId\":" + (body == null ? -1 : body.playerSqlId())
            + ",\"capturedAtUnixMs\":" + observedAt + ",\"gameThreadDurationNs\":" + duration
            + ",\"worldHours\":" + (body == null ? "0" : Double.toString(body.worldHours()))
            + ",\"bindingEpoch\":" + bindingEpoch + ",\"status\":" + StudyParticipant.quote(availability) + ",\"nearby\":" + people
            + ",\"lastCommandSequence\":" + completed + (result == null ? "" : ",\"commandResult\":" + result) + "}\n";
        writer.offer(value, false);
    }

    static void observeEpoch(StudyParticipant.Binding body, String mode) {
        if (body == null) {
            if (epochBody != null) bindingEpoch++;
            epochBody = null; epochMode = null;
            return;
        }
        if (epochBody == null || epochBody.owner() != body.owner()
                || epochBody.playerSqlId() != body.playerSqlId() || epochBody.playerIndex() != body.playerIndex()
                || !epochBody.save().equals(body.save()) || !java.util.Objects.equals(epochMode, mode)
                || body.worldHours() < epochBody.worldHours()) bindingEpoch++;
        epochBody = body; epochMode = mode;
    }

    static String eligibility(Map<String,Object> fields, StudyParticipant.Binding body, String mode,
            long now, String expectedSession, int expectedAttempt, long pid, long currentEpoch) {
        try {
            if (!SCHEMA.equals(text(fields,"schema",64)) || !expectedSession.equals(text(fields,"sessionId",36))
                    || integer(fields,"pid") != pid || integer(fields,"attempt") != expectedAttempt)
                return "The native process or session changed.";
            if (body == null || !body.ready() || !body.alive()) return "Choose a living character in the game first.";
            if (integer(fields,"bindingEpoch") != currentEpoch) return "The native body lifetime changed.";
            if (integer(fields,"playerIndex") != body.playerIndex() || integer(fields,"playerSqlId") != body.playerSqlId()
                    || !body.save().equals(text(fields,"save",160)) || !java.util.Objects.equals(mode,text(fields,"saveMode",80)))
                return "The selected native character or save changed.";
            long issued = integer(fields,"issuedAtUnixMs"), expiry = integer(fields,"expiresAtUnixMs");
            if (issued > now || expiry <= now || expiry < issued || expiry - issued > 5000)
                return "The communication request expired or its source clock changed.";
            text(fields,"personId",128); text(fields,"text",384);
            if (!Set.of("typed","dictated").contains(text(fields,"inputMode",16))) return "Unknown communication input origin.";
            return null;
        } catch (RuntimeException invalid) { return "Invalid source-bound communication request."; }
    }

    static String text(Map<String,Object> fields, String key, int max) {
        Object raw = fields.get(key);
        if (!(raw instanceof String value) || value.isBlank() || value.length() > max) throw new IllegalArgumentException(key);
        for (int i=0; i<value.length(); i++) {
            char c = value.charAt(i);
            if (c < 32 || c == 127) throw new IllegalArgumentException(key);
            if (Character.isHighSurrogate(c)) {
                if (++i >= value.length() || !Character.isLowSurrogate(value.charAt(i))) throw new IllegalArgumentException(key);
            } else if (Character.isLowSurrogate(c)) throw new IllegalArgumentException(key);
        }
        return value;
    }

    static long integer(Map<String,Object> fields, String key) {
        if (!(fields.get(key) instanceof Long value) || value < 0 || value > 9007199254740991L)
            throw new IllegalArgumentException(key);
        return value;
    }

    /** Reuse the installed adapter's strict JSON token reader, with a flat seam
     * and exact fields; nested objects, duplicates and trailing input fail. */
    static Map<String,Object> parseFlat(String raw, Set<String> allowed) {
        var reader = new StudyParticipantInput.JsonObject.Reader(raw);
        var fields = new LinkedHashMap<String,Object>();
        reader.need('{');
        if (!reader.take('}')) {
            do {
                String key = reader.string(); reader.need(':'); Object value = reader.value(1);
                if (!allowed.contains(key) || fields.containsKey(key) || !(value instanceof String || value instanceof Long))
                    throw new IllegalArgumentException("interaction field");
                fields.put(key, value);
            } while (reader.take(','));
            reader.need('}');
        }
        reader.ws();
        if (reader.i != raw.length() || !fields.keySet().equals(allowed)) throw new IllegalArgumentException("interaction document");
        return fields;
    }

    private static boolean ownsLuaThread(KahluaThread thread) {
        return thread != null && LuaManager.thread == thread
            && thread.debugOwnerThread == Thread.currentThread();
    }

    private static void requireLuaOwnership(KahluaThread thread) {
        if (!ownsLuaThread(thread)) throw new LuaOwnershipUnavailable();
    }

    private static final class LuaOwnershipUnavailable extends IllegalStateException {
        LuaOwnershipUnavailable() { super("Native Lua runtime belongs to another thread or is unavailable."); }
    }

    private static String call(String function, Object... arguments) {
        KahluaThread thread = LuaManager.thread;
        requireLuaOwnership(thread);
        KahluaTable environment = LuaManager.env;
        if (environment == null || LuaManager.caller == null) throw new LuaOwnershipUnavailable();
        requireLuaOwnership(thread);
        Object root = environment.rawget("SAO");
        requireLuaOwnership(thread);
        Object module = root instanceof KahluaTable table ? table.rawget("MousecatInteraction") : null;
        requireLuaOwnership(thread);
        Object callback = module instanceof KahluaTable table ? table.rawget(function) : null;
        if (callback == null) throw new IllegalStateException("native communication module unavailable");
        requireLuaOwnership(thread);
        Object[] value = LuaManager.caller.pcall(thread, callback, arguments);
        if (value.length < 2 || !Boolean.TRUE.equals(value[0]) || !(value[1] instanceof String result)
                || result.getBytes(StandardCharsets.UTF_8).length > 49152)
            throw new IllegalStateException("native communication callback refused");
        return result;
    }

    private static String response(String status, String message) {
        return "{\"status\":" + StudyParticipant.quote(status) + ",\"message\":" + StudyParticipant.quote(message) + "}";
    }
}
