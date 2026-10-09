import java.io.IOException;
import java.nio.file.AccessDeniedException;
import java.nio.file.AtomicMoveNotSupportedException;
import java.nio.file.FileSystemException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.lwjglx.opengl.Display;
import se.krka.kahlua.j2se.KahluaTableImpl;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.vm.KahluaThread;
import zombie.GameTime;
import zombie.Lua.LuaManager;
import zombie.characters.IsoPlayer;
import zombie.iso.IsoWorld;

/** Read-only native player identity and capture metadata for one participant JVM.
 * It neither creates nor converts a player, assigns SQL identity, nor saves it.
 */
public final class StudyParticipant {
    public static final String SCHEMA = "sao-native-participant/1";
    record Binding(Object owner, int playerIndex, int playerSqlId, String save,
                   int attempt, double worldHours, boolean alive,
                   double x, double y, double z, String label, boolean ready) { }
    record StartSample(Object owner, int playerIndex, int playerSqlId, String save,
                       String mode, int attempt, double worldHours, long observedAt,
                       long observedTick, String context) { }
    static final long STATE_INTERVAL_NANOS = 100_000_000L;
    // Allow two missed producer intervals, then withhold this sampled context.
    // This is a freshness ceiling, not a claim about achieved native cadence.
    static final long START_MAX_AGE_NANOS = 3 * STATE_INTERVAL_NANOS;
    static final long START_MAX_AGE_MILLIS = START_MAX_AGE_NANOS / 1_000_000L;
    private static String session;
    private static int attempt;
    private static Path statePath;
    private static final Object configuration = new Object();
    private static volatile Binding latest;
    private static volatile StudyViewCapture.CaptureContext latestNativeCapture;
    private static long nativeCaptureEpoch;
    private static volatile StartSample latestStart;
    private static long lastStateTick;
    private static boolean stateSampled;
    private static StartSample captureWatermarkSample;
    private static long lastStartCaptureUnix, lastStartCaptureTick;
    // System clocks in production; controlled offline fixtures inject suppliers.
    private static java.util.function.LongSupplier wallClock = System::currentTimeMillis;
    private static java.util.function.LongSupplier elapsedClock = System::nanoTime;
    private static volatile StatePublisher publisher;
    private static volatile StatePublisher objectivePublisher;
    private static long lastObjectiveTick;
    private static boolean shutdownHookRegistered;
    private StudyParticipant() { }

    static void configure() {
        synchronized (configuration) {
            if (Boolean.getBoolean("study.observer")) throw new IllegalStateException("participant refuses observer host");
            String configuredSession = System.getProperty("study.participantSession", "");
            if (!UUID.fromString(configuredSession).toString().equals(configuredSession)) throw new IllegalArgumentException("participant session differs");
            int configuredAttempt = Integer.parseInt(System.getProperty("study.attempt", "0"));
            if (configuredAttempt < 1) throw new IllegalArgumentException("participant attempt required");
            Path configuredPath = Path.of(System.getProperty("study.participantState", ""));
            if (!configuredPath.isAbsolute()) throw new IllegalArgumentException("absolute participant state path required");
            // Configuration happens when the adapter arms. Drain a previous writer
            // outside the monitor used by native body and frame sampling.
            StatePublisher previous = publisher;
            if (previous != null && !previous.close(2000))
                throw new IllegalStateException("previous participant publisher did not drain");
            StatePublisher previousObjective = objectivePublisher;
            if (previousObjective != null && !previousObjective.close(2000))
                throw new IllegalStateException("previous objective publisher did not drain");
            synchronized (StudyParticipant.class) {
                session = configuredSession; attempt = configuredAttempt; statePath = configuredPath;
                latest = null; latestStart = null; stateSampled = false; lastStateTick = 0;
                latestNativeCapture = null; nativeCaptureEpoch = 0;
                captureWatermarkSample = null;
                publisher = new StatePublisher(statePath, StudyParticipant::publish);
                objectivePublisher = new StatePublisher(statePath.resolveSibling("objective-review-state.json"),
                    StudyParticipant::publish);
                lastObjectiveTick = 0;
                if (!shutdownHookRegistered) {
                    Runtime.getRuntime().addShutdownHook(new Thread(() -> {
                        if (!finishPublication(2000))
                            System.err.println("[StudyParticipant] final publication did not drain");
                    }, "sao-participant-state-shutdown"));
                    shutdownHookRegistered = true;
                }
            }
        }
    }

    /** Called on the native game thread by input or prepared-frame hooks. */
    static synchronized Binding binding() {
        boolean nativePlay = Boolean.getBoolean("study.nativePlay");
        StudyViewCapture.CaptureContext previousCapture = latestNativeCapture;
        // A reader must never accept the previous epoch while a new game-thread
        // body/menu sample is being assembled. Publish the new snapshot last.
        if (nativePlay) latestNativeCapture = null;
        Binding result = null;
        try {
            IsoPlayer[] players = IsoPlayer.players;
            IsoPlayer player = players.length > 0 ? players[0] : null;
            String save = StudyParticipantInput.nativeSaveName();
            double hours = GameTime.getInstance().getWorldAgeHours();
            if (player != null && player.getPlayerNum() == 0 && player.playerIndex == 0
                    && IsoWorld.instance != null && IsoWorld.instance.currentCell != null
                    && player.getCurrentSquare() != null && save != null
                    && Double.isFinite(hours) && hours >= 0) {
                double x = player.getX(), y = player.getY(), z = player.getZ();
                if (Double.isFinite(x) && Double.isFinite(y) && Double.isFinite(z)) {
                    String label = player.getDisplayName();
                    if (label == null) label = "";
                    if (label.length() > 160) label = label.substring(0, 160);
                    result = new Binding(player, player.getPlayerNum(), player.sqlId, save, attempt, hours,
                        !player.isDead(), x, y, z, label, player.sqlId > 0);
                }
            }
        } catch (RuntimeException | LinkageError unavailable) { /* Startup has no observable native body. */ }
        latest = result;
        if (nativePlay) sampleNativeCapture(result, previousCapture);
        return result;
    }

    /** Native game-thread reads stop here; publishers compare immutable samples. */
    private static void sampleNativeCapture(Binding body, StudyViewCapture.CaptureContext before) {
        String mode = null, save = body == null ? null : body.save();
        try { mode = zombie.core.Core.getInstance().getGameMode(); }
        catch (RuntimeException | LinkageError unavailable) { /* No native mode was observed. */ }
        if (body == null) try { save = StudyParticipantInput.nativeSaveName(); }
        catch (RuntimeException | LinkageError unavailable) { /* No native save was observed. */ }
        Object owner = body == null ? null : body.owner();
        boolean persisted = body != null && body.ready();
        Double hours = body == null ? null : body.worldHours();
        int slot = body == null ? -1 : body.playerIndex(), sql = body == null ? -1 : body.playerSqlId();
        boolean changed = before == null || before.owner() != owner
            || !java.util.Objects.equals(before.sessionId(), session) || before.attempt() != attempt
            || !java.util.Objects.equals(before.saveMode(), mode) || !java.util.Objects.equals(before.save(), save)
            || before.playerIndex() != slot || before.playerSqlId() != sql || before.persisted() != persisted
            || before.bodyObserved() != (body != null)
            || (before.worldHours() != null && hours != null && hours < before.worldHours());
        if (changed) nativeCaptureEpoch = Math.addExact(nativeCaptureEpoch, 1);
        latestNativeCapture = new StudyViewCapture.CaptureContext(owner, session, ProcessHandle.current().pid(), attempt,
            nativeCaptureEpoch, mode, save, body != null, persisted, hours, slot, sql);
    }

    public static boolean displayFocused() {
        try { return Display.isActive(); }
        catch (RuntimeException | LinkageError unavailable) { return false; }
    }

    static String json(Binding body, long observedAt) {
        boolean observed = body != null;
        boolean ready = observed && body.ready();
        String value = "{\"schema\":\"" + SCHEMA + "\",\"sessionId\":" + quote(session)
            + ",\"pid\":" + ProcessHandle.current().pid() + ",\"attempt\":" + attempt
            + ",\"save\":" + quote(observed ? body.save() : "")
            + ",\"playerIndex\":" + (observed ? body.playerIndex() : 0)
            + ",\"playerSqlId\":" + (observed ? body.playerSqlId() : -1)
            + ",\"capturedAtUnixMs\":" + observedAt
            + ",\"worldHours\":" + (observed ? Double.toString(body.worldHours()) : "0")
            + ",\"ready\":" + ready + ",\"displayFocused\":" + displayFocused()
            + ",\"alive\":" + (observed && body.alive());
        if (observed) value += ",\"body\":{\"x\":" + body.x() + ",\"y\":" + body.y()
            + ",\"z\":" + body.z() + ",\"label\":" + quote(body.label()) + "}";
        if (Boolean.getBoolean("study.nativePlay")) {
            String mode = observed ? zombie.core.Core.getInstance().getGameMode() : "";
            value += ",\"saveMode\":" + quote(mode == null ? "" : mode);
            String start = startContext(body, observedAt, mode);
            if (start != null) value += ",\"startContext\":" + start;
        }
        return value + "}";
    }

    /** GameWindow.logic exit; only immutable samples enter the writer mailbox. */
    public static synchronized void poll() {
        Binding body = binding();
        long now = wallClock.getAsLong(), tick = elapsedClock.getAsLong();
        StatePublisher writer = publisher;
        if (writer == null) return;
        long elapsed = tick - lastStateTick;
        if (stateSampled && elapsed >= 0 && elapsed < STATE_INTERVAL_NANOS) return;
        // Subtracting elapsed ticks also handles nanoTime's signed wrap. A
        // regressed injected clock resets scheduling rather than suspending it.
        stateSampled = true; lastStateTick = tick;
        // Start records have their own sampling clock. Rendered-frame capture
        // reuses immutable bytes and never reads Lua tables on the render path.
        if (Boolean.getBoolean("study.nativePlay") && body != null && body.owner() instanceof IsoPlayer player)
            latestStart = new StartSample(body.owner(), body.playerIndex(), body.playerSqlId(), body.save(),
                zombie.core.Core.getInstance().getGameMode(),
                body.attempt(), body.worldHours(), now, tick, StudyStartContext.observe(player));
        else { latestStart = null; captureWatermarkSample = null; }
        String sample = json(body, now) + "\n";
        writer.offer(sample, body != null && body.ready());
        if (Boolean.getBoolean("study.nativePlay") && objectivePublisher != null
                && (lastObjectiveTick == 0 || tick - lastObjectiveTick < 0
                    || tick - lastObjectiveTick >= 1_000_000_000L)) {
            lastObjectiveTick = tick;
            String reviews = ObjectiveReviews.observe(body, now, sample);
            if (reviews != null) objectivePublisher.offer(reviews + "\n", false);
        }
    }

    static synchronized String startContext(Binding body, long capturedAt, String mode) {
        StartSample sample = latestStart;
        if (body == null || sample == null || sample.owner() != body.owner()
                || sample.playerIndex() != body.playerIndex() || sample.playerSqlId() != body.playerSqlId()
                || !sample.save().equals(body.save()) || !java.util.Objects.equals(sample.mode(), mode)
                || sample.attempt() != body.attempt()
                || sample.observedAt() < 0 || sample.observedAt() > capturedAt
                || capturedAt - sample.observedAt() > START_MAX_AGE_MILLIS
                || !Double.isFinite(sample.worldHours()) || sample.worldHours() < 0
                || !Double.isFinite(body.worldHours()) || sample.worldHours() > body.worldHours()) return null;
        long tick = elapsedClock.getAsLong(), age = tick - sample.observedTick();
        if (age < 0 || age > START_MAX_AGE_NANOS) return null;
        if (captureWatermarkSample != sample) {
            captureWatermarkSample = sample;
            lastStartCaptureUnix = sample.observedAt(); lastStartCaptureTick = sample.observedTick();
        }
        // Preserve raw clock values. A new native sample starts a new watermark;
        // clock rollback never manufactures a corrected time or Lua reread.
        if (capturedAt < lastStartCaptureUnix || tick - lastStartCaptureTick < 0) return null;
        lastStartCaptureUnix = capturedAt; lastStartCaptureTick = tick;
        return "{\"capturedAtUnixMs\":" + sample.observedAt() + ",\"worldHours\":" + sample.worldHours()
            + ",\"context\":" + sample.context() + "}";
    }

    /** Shutdown drains sampled bytes without acquiring or resampling a body. */
    static boolean finishPublication(long timeoutMs) {
        StatePublisher writer = publisher;
        StatePublisher objective = objectivePublisher;
        boolean stateDone = writer == null || writer.close(timeoutMs);
        boolean objectiveDone = objective == null || objective.close(timeoutMs);
        return stateDone && objectiveDone;
    }

    /** Read-only Organization projection. Its Lua API validates the exact
     * returned work report and player review before any fields are exported.
     * The adapter never enters Lua when the current thread does not own it.
     */
    static final class ObjectiveReviews {
        static final int MAX_REVIEWS = 8, MAX_ATTEMPTS = 64, MAX_CHARS = 131072;

        static String observe(Binding body, long now, String sample) {
            if (body == null || !body.ready() || !(body.owner() instanceof IsoPlayer player)) return null;
            KahluaThread thread = LuaManager.thread;
            if (thread == null || thread.debugOwnerThread != Thread.currentThread()
                    || LuaManager.env == null || LuaManager.caller == null) return null;
            try {
                KahluaTable root = table(LuaManager.env.rawget("SAO"));
                KahluaTable standing = table(raw(root, "Standing"));
                KahluaTable organization = table(raw(root, "Organization"));
                KahluaTable history = table(raw(root, "History"));
                KahluaTable processes = table(raw(organization, "processes"));
                KahluaTable order = table(raw(organization, "processOrder"));
                // Standing.playerKey calls getModData. Its account branch is
                // already exposed separately and does not allocate modData.
                String keyFunction = player.hasModData() ? "playerKey" : "playerAccountKey";
                String playerId = string(invoke(thread, standing, keyFunction, player), 512);
                Double countyHours = number(invoke(thread, history, "countyHours"));
                Map<Object,Object> ordered = own(order), records = own(processes);
                if (playerId == null || countyHours == null || ordered == null || records == null || ordered.size() > 1024
                        || records.size() > 1024) return null;
                List<String> found = new ArrayList<>();
                Set<String> seenKeys = new HashSet<>();
                int omitted = 0;
                for (int index = ordered.size(); index >= 1; index--) {
                    Object id = ordered.get((double)index);
                    KahluaTable process = table(records.get(id));
                    if (process == null || !playerId.equals(raw(process, "originatorId"))
                            || !"cooperative-action".equals(raw(process, "kind"))) continue;
                    KahluaTable savedReviews = table(raw(process, "objectivePlayerReviews"));
                    Map<Object,Object> rows = own(savedReviews);
                    if (rows == null) continue;
                    if (found.size() == MAX_REVIEWS || rows.size() > 64) {
                        omitted = Math.min(65536, omitted + Math.min(rows.size(), 65536));
                        continue;
                    }
                    List<String> keys = new ArrayList<>();
                    for (Object key : rows.keySet()) if (key instanceof String name) keys.add(name);
                    Collections.sort(keys);
                    for (String key : keys) {
                        if (found.size() == MAX_REVIEWS) {
                            omitted = Math.min(65536, omitted + 1); continue;
                        }
                        KahluaTable stored = table(rows.get(key));
                        String helperId = string(raw(stored, "actorId"), 512);
                        Integer storedRevision = integer(raw(stored, "revision"));
                        if (helperId == null || storedRevision == null
                                || !key.equals(helperId + ":" + storedRevision)
                                || !(id instanceof String processId)) {
                            omitted = Math.min(65536, omitted + 1); continue;
                        }
                        if (!seenKeys.add(processId + "\u0000" + key)) continue;
                        Object review = invoke(thread, organization, "objectivePlayerReviewFor",
                            processId, helperId, playerId);
                        Object report = invoke(thread, organization, "objectiveReportFor",
                            processId, helperId, playerId);
                        String row = receipt(processId, playerId, helperId, table(report), table(review));
                        if (row == null || row.getBytes(StandardCharsets.UTF_8).length > 12000) {
                            omitted = Math.min(65536, omitted + 1); continue;
                        }
                        found.add(row);
                    }
                }
                if (found.isEmpty() && omitted == 0) return null;
                String mode = zombie.core.Core.getInstance().getGameMode();
                if (mode == null || mode.isEmpty() || mode.length() > 80) return null;
                StringBuilder value = new StringBuilder("{\"schema\":\"sao-native-objective-reviews/1\",\"sessionId\":")
                    .append(quote(session)).append(",\"pid\":").append(ProcessHandle.current().pid())
                    .append(",\"attempt\":").append(attempt).append(",\"save\":").append(quote(body.save()))
                    .append(",\"captureEpoch\":").append(nativeCaptureEpoch)
                    .append(",\"saveMode\":").append(quote(mode)).append(",\"playerIndex\":")
                    .append(body.playerIndex()).append(",\"playerSqlId\":").append(body.playerSqlId())
                    .append(",\"capturedAtUnixMs\":").append(now).append(",\"worldHours\":")
                    .append(body.worldHours()).append(",\"countyHours\":").append(countyHours)
                    .append(",\"sampleSha256\":").append(quote(sha256(sample)))
                    .append(",\"bodySample\":").append(quote(sample)).append(",\"omittedReviews\":")
                    .append(omitted).append(",\"reviews\":[");
                for (int i = 0; i < found.size(); i++) {
                    if (i > 0) value.append(',');
                    value.append(found.get(i));
                }
                value.append("]}");
                String output = value.toString();
                return output.getBytes(StandardCharsets.UTF_8).length <= MAX_CHARS ? output : null;
            } catch (RuntimeException | LinkageError unavailable) {
                return null;
            }
        }

        private static String receipt(String processId, String playerId, String helperId,
                                      KahluaTable report, KahluaTable review) {
            if (report == null || review == null) return null;
            Integer revision = integer(raw(review, "revision"));
            String commitment = string(raw(review, "commitmentId"), 512);
            String outbound = string(raw(review, "outboundReceiptId"), 512);
            String watch = string(raw(review, "watchReceiptId"), 512);
            String returned = string(raw(review, "returnReceiptId"), 512);
            Double delivered = number(raw(report, "deliveredAt"));
            Double reviewed = number(raw(review, "reviewedAt"));
            if (revision == null || revision < 1 || commitment == null || outbound == null
                    || watch == null || returned == null || delivered == null || reviewed == null
                    || reviewed < delivered || !processId.equals(raw(review, "processId"))
                    || !processId.equals(raw(report, "processId"))
                    || !playerId.equals(raw(review, "playerId"))
                    || !playerId.equals(raw(report, "recipientId"))
                    || !helperId.equals(raw(review, "actorId"))
                    || !helperId.equals(raw(report, "actorId"))
                    || !revision.equals(integer(raw(report, "revision")))
                    || !outbound.equals(raw(report, "outboundReceiptId"))
                    || !watch.equals(raw(report, "watchReceiptId"))
                    || !returned.equals(raw(report, "returnReceiptId"))
                    || !delivered.equals(number(raw(review, "reportDeliveredAt")))
                    || !"completed".equals(raw(report, "status"))
                    || !"spoken".equals(raw(report, "channel"))
                    || !"inspected".equals(raw(review, "status"))) return null;
            KahluaTable attempts = table(raw(review, "attempts"));
            Map<Object,Object> attemptRows = own(attempts);
            if (attemptRows == null || attemptRows.size() > MAX_ATTEMPTS) return null;
            StringBuilder items = new StringBuilder("[");
            for (int index = 1; index <= attemptRows.size(); index++) {
                KahluaTable item = table(attemptRows.get((double)index));
                String id = string(raw(item, "id"), 512), step = string(raw(item, "stepId"), 80);
                String owner = string(raw(item, "owner"), 160), status = string(raw(item, "status"), 80);
                Double x = coordinate(raw(item, "x"), -2147483648d, 2147483648d);
                Double y = coordinate(raw(item, "y"), -2147483648d, 2147483648d);
                Double z = coordinate(raw(item, "z"), -32d, 32d);
                Double start = number(raw(item, "startedAt")), end = number(raw(item, "endedAt"));
                if (id == null || step == null || owner == null || status == null
                        || x == null || y == null || z == null || start == null
                        || end != null && end < start) return null;
                if (index > 1) items.append(',');
                items.append("{\"id\":").append(quote(id)).append(",\"stepId\":").append(quote(step))
                    .append(",\"owner\":").append(quote(owner)).append(",\"status\":").append(quote(status))
                    .append(",\"x\":").append(x).append(",\"y\":").append(y).append(",\"z\":")
                    .append(z).append(",\"startedAt\":").append(start).append(",\"endedAt\":")
                    .append(end == null ? "null" : end).append('}');
            }
            items.append(']');
            return new StringBuilder("{\"processId\":").append(quote(processId))
                .append(",\"revision\":").append(revision).append(",\"playerId\":")
                .append(quote(playerId)).append(",\"helperId\":").append(quote(helperId))
                .append(",\"commitmentId\":").append(quote(commitment))
                .append(",\"outboundReceiptId\":").append(quote(outbound))
                .append(",\"watchReceiptId\":").append(quote(watch))
                .append(",\"returnReceiptId\":").append(quote(returned))
                .append(",\"report\":{\"status\":\"completed\",\"channel\":\"spoken\",\"deliveredAt\":")
                .append(delivered).append("},\"review\":{\"status\":\"inspected\",\"reviewedAt\":")
                .append(reviewed).append(",\"attempts\":").append(items).append("}}")
                .toString();
        }

        private static Object invoke(KahluaThread thread, KahluaTable module, String name, Object... args) {
            Object callback = raw(module, name);
            if (callback == null || LuaManager.thread != thread
                    || thread.debugOwnerThread != Thread.currentThread()) return null;
            Object[] answer = LuaManager.caller.pcall(thread, callback, args);
            return answer.length >= 2 && Boolean.TRUE.equals(answer[0]) ? answer[1] : null;
        }

        private static KahluaTable table(Object value) {
            return value instanceof KahluaTable source && own(source) != null ? source : null;
        }

        private static Map<Object,Object> own(KahluaTable table) {
            if (!(table instanceof KahluaTableImpl plain) || plain.getRewriteTable() != null) return null;
            Map<Object,Object> values = plain.delegate;
            return values != null && (values.getClass() == LinkedHashMap.class
                || values.getClass() == HashMap.class) ? values : null;
        }

        private static Object raw(KahluaTable table, Object key) {
            Map<Object,Object> values = own(table);
            return values == null ? null : values.get(key);
        }

        private static String string(Object value, int max) {
            if (!(value instanceof String text) || text.isEmpty() || text.length() > max) return null;
            for (int i = 0; i < text.length(); i++) {
                char c = text.charAt(i);
                if (c < 32 || c == 127) return null;
                if (Character.isHighSurrogate(c)) {
                    if (++i >= text.length() || !Character.isLowSurrogate(text.charAt(i))) return null;
                } else if (Character.isLowSurrogate(c)) return null;
            }
            return text;
        }

        private static Integer integer(Object value) {
            Double number = number(value);
            return number != null && number >= 0 && number <= Integer.MAX_VALUE
                && number == Math.rint(number) ? number.intValue() : null;
        }

        private static Double number(Object value) {
            if (!(value instanceof Number n)) return null;
            double number = n.doubleValue();
            return Double.isFinite(number) && number >= 0 && number <= 9007199254740991d ? number : null;
        }

        private static Double coordinate(Object value, double low, double high) {
            if (!(value instanceof Number n)) return null;
            double number = n.doubleValue();
            return Double.isFinite(number) && number >= low && number <= high ? number : null;
        }

        private static String sha256(String text) {
            try {
                byte[] bytes = MessageDigest.getInstance("SHA-256").digest(text.getBytes(StandardCharsets.UTF_8));
                StringBuilder result = new StringBuilder(64);
                for (byte b : bytes) result.append(String.format("%02x", b & 255));
                return result.toString();
            } catch (NoSuchAlgorithmException impossible) { throw new IllegalStateException(impossible); }
        }
    }

    @FunctionalInterface
    interface Publication { void write(Path target, String sample) throws IOException; }

    /** At most one pending state and one pending ready identity; no body references.
     * Filesystem work and bounded sharing retries never hold the sampling monitor.
     */
    static final class StatePublisher implements Runnable {
        static final int MAX_ATTEMPTS = 8;
        static final long RETRY_MS = 25;
        private final Object mailbox = new Object();
        private final Path stateTarget, identityTarget;
        private final Publication publication;
        private final Thread thread;
        private String pendingState, pendingIdentity, lastState, lastIdentity;
        private volatile String writtenState, writtenIdentity;
        private boolean closing;
        private volatile boolean stateFailed, identityFailed, workerFailed;

        StatePublisher(Path target, Publication publication) {
            stateTarget = target;
            identityTarget = target.resolveSibling("participant-identity.json");
            this.publication = publication;
            thread = new Thread(this, "sao-participant-state");
            thread.setDaemon(true);
            thread.start();
        }

        void offer(String sample, boolean ready) {
            synchronized (mailbox) {
                if (closing || workerFailed) return;
                pendingState = lastState = sample;
                // An unready sample can replace current state, never last identity.
                if (ready) pendingIdentity = lastIdentity = sample;
                mailbox.notifyAll();
            }
        }

        @Override public void run() {
            try {
                while (true) {
                    String state, identity;
                    synchronized (mailbox) {
                        while (pendingState == null && pendingIdentity == null && !closing)
                            mailbox.wait();
                        state = pendingState; identity = pendingIdentity;
                        pendingState = pendingIdentity = null;
                        if (state == null && identity == null && closing) return;
                    }
                    if (state != null) {
                        boolean ok = write(stateTarget, state, stateFailed);
                        stateFailed = !ok;
                        if (ok) writtenState = state;
                    }
                    if (identity != null) {
                        boolean ok = write(identityTarget, identity, identityFailed);
                        identityFailed = !ok;
                        if (ok) writtenIdentity = identity;
                    }
                }
            } catch (InterruptedException interrupted) {
                Thread.currentThread().interrupt();
                workerFailed = true;
            } catch (RuntimeException | LinkageError failure) {
                workerFailed = true;
                System.err.println("[StudyParticipant] state writer failed: " + failure);
            }
        }

        private boolean write(Path target, String sample, boolean alreadyFailed) throws InterruptedException {
            for (int number = 0; number < MAX_ATTEMPTS; number++) {
                try { publication.write(target, sample); return true; }
                catch (IOException failure) {
                    if (sharingConflict(failure) && number + 1 < MAX_ATTEMPTS) {
                        Thread.sleep(RETRY_MS);
                        continue;
                    }
                    if (!alreadyFailed)
                        System.err.println("[StudyParticipant] state publication failed: " + failure);
                    return false;
                }
            }
            return false;
        }

        boolean close(long timeoutMs) {
            if (timeoutMs < 1 || timeoutMs > 2000) throw new IllegalArgumentException("bounded publisher drain required");
            synchronized (mailbox) {
                closing = true;
                // An exhausted earlier write still receives one finite final
                // attempt. Pending newer samples retain their authority.
                if (pendingState == null && lastState != null && !lastState.equals(writtenState))
                    pendingState = lastState;
                if (pendingIdentity == null && lastIdentity != null && !lastIdentity.equals(writtenIdentity))
                    pendingIdentity = lastIdentity;
                mailbox.notifyAll();
            }
            try { thread.join(timeoutMs); }
            catch (InterruptedException interrupted) { Thread.currentThread().interrupt(); return false; }
            if (thread.isAlive()) { thread.interrupt(); return false; }
            return !workerFailed && !stateFailed && !identityFailed
                && (lastState == null || lastState.equals(writtenState))
                && (lastIdentity == null || lastIdentity.equals(writtenIdentity));
        }
    }

    private static boolean sharingConflict(IOException failure) {
        if (!System.getProperty("os.name", "").startsWith("Windows")) return false;
        if (failure instanceof AccessDeniedException) return true;
        if (!(failure instanceof FileSystemException system) || system.getReason() == null) return false;
        String reason = system.getReason().toLowerCase(java.util.Locale.ROOT);
        return reason.contains("used by another process") || reason.contains("sharing violation");
    }

    private static void publish(Path target, String sample) throws IOException {
        Files.createDirectories(target.getParent());
        Path temporary = target.resolveSibling(target.getFileName() + ".tmp");
        Files.writeString(temporary, sample);
        try { Files.move(temporary, target, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING); }
        catch (AtomicMoveNotSupportedException unsupported) { Files.move(temporary, target, StandardCopyOption.REPLACE_EXISTING); }
    }

    /** Snapshot of the actual body when SpriteRenderState.onReady commits it. */
    public static synchronized StudyViewCapture.FrameStamp frame() {
        Binding body = binding();
        boolean nativePlay = Boolean.getBoolean("study.nativePlay");
        if (body == null && !nativePlay) return null;
        StudyViewCapture.CaptureContext context = nativePlay ? latestNativeCapture : null;
        if (nativePlay && context == null) return null;
        var identity = new StudyViewCapture.ParticipantFrame(json(body, wallClock.getAsLong()),
            body == null ? null : body.owner(), body == null ? null : body.save(),
            body == null ? -1 : body.playerIndex(), body == null ? -1 : body.playerSqlId(), attempt, context);
        return new StudyViewCapture.FrameStamp(0, body == null ? 0 : body.worldHours(), new StudyObserver.SiteFrame[0],
            new StudyVideoCapture.Site[0], identity);
    }

    /** Publisher checks the latest game-thread identity; it never reads game state. */
    public static boolean isCurrent(StudyViewCapture.ParticipantFrame frame) {
        if (frame.capture() != null) {
            StudyViewCapture.CaptureContext current = latestNativeCapture;
            return Boolean.getBoolean("study.nativePlay") && current != null
                && current.sameSource(frame.capture()) && (latest == null) == (frame.body() == null);
        }
        Binding body = latest;
        return body != null && body.owner() == frame.body() && body.save().equals(frame.save())
            && body.playerIndex() == frame.playerIndex() && body.playerSqlId() == frame.playerSqlId()
            && body.attempt() == frame.attempt();
    }

    static String quote(String text) {
        if (text == null) text = "";
        StringBuilder out = new StringBuilder("\"");
        for (int at = 0; at < text.length(); at++) {
            char value = text.charAt(at);
            if (value == '\\' || value == '"') out.append('\\').append(value);
            else if (value < 0x20) out.append(String.format("\\u%04x", (int) value));
            else out.append(value);
        }
        return out.append('"').toString();
    }
}
