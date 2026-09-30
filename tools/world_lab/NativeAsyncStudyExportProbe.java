import java.lang.reflect.Field;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;
import se.krka.kahlua.converter.KahluaConverterManager;
import se.krka.kahlua.integration.LuaCaller;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.vm.KahluaThread;
import se.krka.kahlua.vm.JavaFunction;
import zombie.GameWindow;
import zombie.ZomboidFileSystem;
import zombie.Lua.LuaManager;
import zombie.ui.SpeedControls;
import zombie.ui.UIManager;
import sun.misc.Unsafe;

/** Actual installed VM/worker contract. No game window or shared output is used. */
public final class NativeAsyncStudyExportProbe {
    private static final String DEFINITION = "a".repeat(64), OBSERVER = "b".repeat(64), ENGINE = "c".repeat(64);
    private static final String SAVE = "AsyncStudy", SESSION = "worker-session";
    private static final String KEY = DEFINITION + "/" + SAVE + "/" + SESSION;
    private static J2SEPlatform platform;
    private static KahluaTable env, marker;
    private static KahluaThread thread;
    private static StudyExport export;
    private static Path root;
    private static int cases;

    private static void check(boolean truth, String label) {
        if (!truth) throw new AssertionError(label);
        cases++; System.out.println("PASS " + label);
    }
    private static Object lua(String source) throws Exception {
        return thread.call(LuaCompiler.loadstring(source, "async-export-probe", env), null, null, null);
    }
    private static String json(Object value) {
        Object result = thread.call(env.rawget("__encode"), value, null, null);
        if (!(result instanceof String)) throw new AssertionError("production Lua encoder did not return JSON");
        return (String) result;
    }
    private static KahluaTable table() { return platform.newTable(); }
    private static KahluaTable frame(boolean archive, long sequence) {
        KahluaTable result = table();
        result.rawset("definitionSha256", DEFINITION); result.rawset("save", SAVE);
        result.rawset("datasetAdmission", "unreviewed");
        if (archive) {
            result.rawset("session", SESSION); result.rawset("observerSha256", OBSERVER);
            result.rawset("packageEngineJarSha256", ENGINE); result.rawset("sequence", (double) sequence);
            result.rawset("hours", 2.75);
        }
        return result;
    }
    private static KahluaTable status(String kind, long sequence) {
        KahluaTable result = frame(true, sequence); result.rawset("status", kind);
        if (kind.equals("deferred")) result.rawset("attemptedSequence", (double) sequence);
        result.rawset("worldHours", 2.75);
        if (kind.equals("deferred")) result.rawset("reason", "encoded-byte-budget");
        return result;
    }
    private static String archiveName(long sequence) {
        StringBuilder save = new StringBuilder();
        for (char c : SAVE.toCharArray()) save.append(String.format("%02x", (int) c));
        return "StudyWorld/" + DEFINITION + "/" + save + "/" + SESSION + "/" + String.format("%016d", sequence) + ".json";
    }
    private static void strict(Runnable action, String fragment, String label) {
        try { action.run(); }
        catch (RuntimeException failure) {
            check(failure.getMessage() != null && failure.getMessage().contains(fragment), label); return;
        }
        throw new AssertionError(label + " accepted");
    }
    private static void await(double ticket, String expected) throws Exception {
        long limit = System.nanoTime() + TimeUnit.SECONDS.toNanos(10);
        while (export.receiptStatus(ticket).equals("pending") && System.nanoTime() < limit) Thread.sleep(5);
        check(export.receiptStatus(ticket).equals(expected), "terminal receipt " + expected);
    }
    private static Object field(Object value, String name) throws Exception {
        Field field = value.getClass().getDeclaredField(name); field.setAccessible(true); return field.get(value);
    }
    private static void host(String name, Object value) throws Exception {
        Field field = StudyObserver.class.getDeclaredField(name); field.setAccessible(true); field.set(null, value);
    }
    private static void stopControls() throws Exception {
        Field unsafeField = Unsafe.class.getDeclaredField("theUnsafe"); unsafeField.setAccessible(true);
        Unsafe unsafe = (Unsafe) unsafeField.get(null);
        // Only drawing receivers are omitted; the installed speed methods run.
        SpeedControls speed = (SpeedControls) unsafe.allocateInstance(SpeedControls.class);
        for (String name : new String[]{"play", "pause", "fastForward", "fasterForward", "wait", "stepForward"}) {
            zombie.ui.HUDButton button = (zombie.ui.HUDButton) unsafe.allocateInstance(zombie.ui.HUDButton.class);
            Field buttonName = zombie.ui.HUDButton.class.getDeclaredField("name"); buttonName.setAccessible(true); buttonName.set(button, name);
            Field buttonField = SpeedControls.class.getDeclaredField(name); buttonField.setAccessible(true); buttonField.set(null, button);
        }
        UIManager.setSpeedControls(speed);
        zombie.SoundManager.instance = new zombie.DummySoundManager();
        host("ready", true); host("stopping", false); host("exportDrainStarted", 0L);
        host("exportDrainFailed", false); host("runtimeFailure", null);
        Path stopState = root.resolve("observer-stop.json"); host("stateFile", stopState);
        host("lastSnapshot", "{\"schema\":\"sao-study-observer/1\",\"status\":\"stopping\",\"worldHours\":2.75,\"updatedAtUnixMs\":0,\"failure\":null}");
        Method drain = StudyObserver.class.getDeclaredMethod("drainExports"); drain.setAccessible(true);
        KahluaTable study = table(); env.rawset("SAO_StudyWorld", study);
        KahluaTable data = frame(true, 6);
        double ticket = export.reserve("archive", KEY + "/archive/6");
        AtomicReference<Boolean> paused = new AtomicReference<>(false);
        study.rawset("drainExports", (JavaFunction) (frame, count) -> {
            paused.set(speed.getCurrentGameSpeed() == 0);
            if (!export.receiptStatus(ticket).equals("published")) { frame.push(false); return 1; }
            export.release(ticket); frame.push(true); return 1;
        });
        try (Hold hold = new Hold()) {
            export.submitArchive(ticket, data, marker, 10000, archiveName(6), status("captured", 6), status("deferred", 6));
            speed.SetCurrentGameSpeed(3);
            export.requestStop("native-worker-probe");
            check(speed.getCurrentGameSpeed() == 0, "stop request pauses native clock before acknowledgement");
            check(Boolean.FALSE.equals(drain.invoke(null)), "stop drain waits for actual pending archive");
            check(paused.get(), "native clock is paused before Lua drain callback");
        }
        await(ticket, "published");
        check(Boolean.TRUE.equals(drain.invoke(null)) && !StudyExport.hasPending(), "stop drain acknowledges actual archive before shutdown");

        host("exportDrainStarted", System.currentTimeMillis() - 15001); host("exportDrainFailed", false);
        host("runtimeFailure", null);
        host("lastSnapshot", "{\"schema\":\"sao-study-observer/1\",\"status\":\"stopping\",\"worldHours\":2.75,\"updatedAtUnixMs\":0,\"failure\":null}");
        study.rawset("drainExports", (JavaFunction) (frame, count) -> { frame.push(false); return 1; });
        check(Boolean.TRUE.equals(drain.invoke(null)), "expired stop deadline completes visible failure publication");
        String failed = Files.readString(stopState);
        check(failed.contains("\"status\":\"failed\"") && failed.contains("export drain exceeded fifteen seconds")
            && failed.contains("\"worldHours\":2.75"), "timeout publishes failed observer state with retained native clock");
        check(StudyObserver.snapshot().equals(failed), "failed stop snapshot and durable state agree");
    }
    private static final class Hold implements AutoCloseable {
        final CountDownLatch entered = new CountDownLatch(1), release = new CountDownLatch(1);
        Hold() throws Exception {
            ((ThreadPoolExecutor) field(export, "worker")).execute(() -> {
                entered.countDown();
                try { release.await(); } catch (InterruptedException error) { Thread.currentThread().interrupt(); }
            });
            if (!entered.await(5, TimeUnit.SECONDS)) throw new AssertionError("worker did not enter test latch");
        }
        public void close() { release.countDown(); }
    }
    private static KahluaTable ownerGuard(KahluaTable table) {
        Thread owner = Thread.currentThread();
        return (KahluaTable) Proxy.newProxyInstance(KahluaTable.class.getClassLoader(), new Class<?>[]{KahluaTable.class},
            (proxy, method, arguments) -> {
                if (Thread.currentThread() != owner) throw new AssertionError("worker touched live Kahlua table");
                try { return method.invoke(table, arguments); }
                catch (InvocationTargetException error) { throw error.getCause(); }
            });
    }
    private static void start() { export.begin(DEFINITION, SAVE, SESSION, OBSERVER, ENGINE); }

    public static void main(String[] args) throws Exception {
        GameWindow.gameThread = Thread.currentThread();
        zombie.core.random.RandStandard.INSTANCE.init();
        ZomboidFileSystem.instance.setCacheDir(args[1]);
        platform = new J2SEPlatform(); env = platform.newEnvironment();
        thread = new KahluaThread(platform, env); thread.debugOwnerThread = Thread.currentThread();
        LuaManager.platform = platform; LuaManager.env = env; LuaManager.thread = thread;
        LuaManager.converterManager = new KahluaConverterManager();
        zombie.Lua.KahluaNumberConverter.install(LuaManager.converterManager);
        LuaManager.caller = new LuaCaller(LuaManager.converterManager);
        LuaManager.exposer = new LuaManager.Exposer(LuaManager.converterManager, platform, env);
        try {
            StudyExport.bind(); export = (StudyExport) env.rawget("SAO_StudyExport");
            check(export != null, "actual installed exposer binds singleton");
            StudyExport.bind(); check(env.rawget("SAO_StudyExport") == export, "same environment retains owner");
            lua(Files.readString(Path.of(args[0]), StandardCharsets.UTF_8));
            marker = (KahluaTable) env.rawget("__marker"); root = Path.of(LuaManager.getLuaCacheDir());
            lua("SAO_StudyExport:begin('" + DEFINITION + "','" + SAVE + "','" + SESSION + "','" + OBSERVER + "','" + ENGINE + "')");
            check(((Double) lua("return SAO_StudyExport:measure('colon-bound',__marker,100)")) == 13,
                "actual Lua colon call preserves string and numeric arity");

            KahluaTable trials = (KahluaTable) env.rawget("__trials");
            for (int i = 1; i <= trials.len(); i++) {
                Object value = trials.rawget(i); byte[] expected = json(value).getBytes(StandardCharsets.UTF_8);
                check(export.measure(value, marker, expected.length) == expected.length, "production Lua exact UTF-8 bytes " + i);
                check(export.measure(value, marker, expected.length - 1) == -1, "production Lua one-under capacity " + i);
            }
            KahluaTable live = frame(false, 0), nested = table(); nested.rawset("observed", "before");
            live.rawset("corpus", trials); live.rawset("alias", ownerGuard(nested));
            String liveExpected = json(live); double liveBytes = liveExpected.getBytes(StandardCharsets.UTF_8).length;
            env.rawset("__live", live);
            double liveTicket = (Double) lua("return SAO_StudyExport:reserve('live','" + KEY + "/live/1')");
            check(StudyExport.hasPending(), "reservation counts as pending before snapshot");
            check(export.reserve("live", KEY + "/live/2") == 0, "busy live reservation refuses acquisition");
            try (Hold hold = new Hold()) {
                check(lua("return SAO_StudyExport:submitLive(" + (long) liveTicket + ",__live,__marker," + (long) liveBytes + ")").equals("accepted"),
                    "actual Lua colon call admits immutable native snapshot");
                check(export.receiptStatus(liveTicket).equals("pending"), "worker latch preserves pending receipt");
                nested.rawset("observed", "after"); live.rawset("new", "future mutation");
                strict(() -> export.release(liveTicket), "pending", "pending publication cannot be acknowledged");
            }
            if (args.length > 2 && args[2].equals("corrupt-readback")) {
                await(liveTicket, "failed");
                check(export.receiptFailure(liveTicket).contains("read-back differs")
                    && !Files.exists(root.resolve("StudyWorldLive.json")), "corrupt temporary readback cannot publish or acknowledge");
                export.release(liveTicket); System.out.println("VALUE PASS readback-fault"); return;
            }
            await(liveTicket, "published");
            check(Arrays.equals(Files.readAllBytes(root.resolve("StudyWorldLive.json")), liveExpected.getBytes(StandardCharsets.UTF_8)),
                "worker bytes match production Lua and ignore later live aliases");
            check(export.receiptKey(liveTicket).equals(KEY + "/live/1") && export.receiptCompletedAt(liveTicket) > 0,
                "live receipt retains exact owner and completed clock");
            export.release(liveTicket);

            KahluaTable split = frame(false, 0); split.rawset("split", "prefix\ud83d");
            String splitJson = json(split);
            double splitBound = (Double) thread.call(env.rawget("__count"), split, null, null);
            check(export.measure(split, marker, splitBound) == splitBound && export.measure(split, marker, splitBound - 1) == -1,
                "split-surrogate projection preserves conservative native Lua budget");
            var nativeWriter = LuaManager.GlobalObject.getFileWriter("writer-parity.json", true, false);
            check(nativeWriter != null, "actual native writer available in isolated cache");
            nativeWriter.write(splitJson); nativeWriter.close();
            double splitTicket = export.reserve("live", KEY + "/live/split");
            export.submitLive(splitTicket, split, marker, 10000); await(splitTicket, "published");
            check(Arrays.equals(Files.readAllBytes(root.resolve("writer-parity.json")), Files.readAllBytes(root.resolve("StudyWorldLive.json"))),
                "split-surrogate bytes match actual native UTF-8 writer"); export.release(splitTicket);

            KahluaTable archive = frame(true, 1); archive.rawset("payload", trials);
            KahluaTable captured = status("captured", 1), deferred = status("deferred", 1);
            String archiveExpected = json(archive) + "\n", capturedExpected = json(captured) + "\n";
            double archiveTicket = export.reserve("archive", KEY + "/archive/1");
            try (Hold hold = new Hold()) {
                export.submitArchive(archiveTicket, archive, marker, archiveExpected.getBytes(StandardCharsets.UTF_8).length - 1,
                    archiveName(1), captured, deferred);
                check(export.reserve("archive", KEY + "/archive/2") == 0, "pending archive cannot be replaced");
                double queuedLive = export.reserve("live", KEY + "/live/3");
                check(queuedLive > 0, "one live and one archive have independent bounded slots"); export.release(queuedLive);
                strict(StudyExport::shutdown, "unacknowledged", "shutdown refuses pending archive");
            }
            await(archiveTicket, "published");
            check(Arrays.equals(Files.readAllBytes(root.resolve(archiveName(1))), archiveExpected.getBytes(StandardCharsets.UTF_8)),
                "archive JSON plus native newline is byte-identical");
            check(Arrays.equals(Files.readAllBytes(root.resolve("StudyWorldArchiveStatus.json")), capturedExpected.getBytes(StandardCharsets.UTF_8)),
                "archive status readback precedes acknowledged publication");
            check(export.receiptSequence(archiveTicket) == 1, "archive receipt acknowledges exact sequence"); export.release(archiveTicket);

            KahluaTable overflow = frame(true, 2); overflow.rawset("payload", trials);
            double overflowTicket = export.reserve("archive", KEY + "/archive/2");
            export.submitArchive(overflowTicket, overflow, marker, 1, archiveName(2), status("captured", 2), status("deferred", 2));
            await(overflowTicket, "deferred");
            check(export.receiptReason(overflowTicket).equals("encoded-byte-budget"), "byte deferral reports actual capacity");
            check(!Files.exists(root.resolve(archiveName(2))), "overflow never publishes an archive");
            check(Files.readString(root.resolve("StudyWorldArchiveStatus.json")).equals(json(status("deferred", 2)) + "\n"),
                "overflow publishes exact deferred status"); export.release(overflowTicket);

            KahluaTable cycle = table(); cycle.rawset("cycle", cycle);
            strict(() -> export.measure(cycle, marker, 10000), "cyclic", "cyclic native table remains strict");
            strict(() -> export.measure(Double.NaN, marker, 100), "non-finite", "nonfinite scalar remains strict");
            strict(() -> export.measure(new Object(), marker, 100), "unsupported", "native userdata remains strict");
            strict(() -> export.reserve("live", "foreign/live/1"), "foreign", "foreign reservation refused");
            double malformed = export.reserve("live", KEY + "/live/4");
            KahluaTable foreign = frame(false, 0); foreign.rawset("definitionSha256", "d".repeat(64));
            strict(() -> export.submitLive(malformed, foreign, marker, 10000), "foreign", "foreign frame remains strict");
            export.release(malformed);
            KahluaTable deep = table(), cursor = deep;
            for (int i = 0; i < 45; i++) { KahluaTable next = table(); cursor.rawset("next", next); cursor = next; }
            check(export.measure(deep, marker, 100000) == -1, "depth capacity is a result");
            for (String kind : new String[]{"depth", "node"}) {
                long sequence = kind.equals("depth") ? 3 : 4;
                KahluaTable bounded = frame(true, sequence), payload = kind.equals("depth") ? deep : table();
                if (kind.equals("node")) for (int i = 1; i <= 262145; i++) payload.rawset(i, (Object) Boolean.TRUE);
                bounded.rawset("payload", payload);
                double boundedTicket = export.reserve("archive", KEY + "/archive/" + sequence);
                export.submitArchive(boundedTicket, bounded, marker, 64 * 1024 * 1024,
                    archiveName(sequence), status("captured", sequence), status("deferred", sequence));
                await(boundedTicket, "deferred");
                String reason = "detached-" + kind + "-budget";
                check(export.receiptReason(boundedTicket).equals(reason), "under-byte-limit deferral reports " + kind);
                check(Files.readString(root.resolve("StudyWorldArchiveStatus.json")).contains(reason), "status retains " + kind + " capacity");
                export.release(boundedTicket);
            }
            double clockTicket = export.reserve("archive", KEY + "/archive/5");
            KahluaTable wrongClock = status("captured", 5); wrongClock.rawset("worldHours", 2.76);
            strict(() -> export.submitArchive(clockTicket, frame(true, 5), marker, 10000, archiveName(5), wrongClock, status("deferred", 5)),
                "world clock", "status cannot substitute a later native clock"); export.release(clockTicket);
            AtomicReference<Throwable> other = new AtomicReference<>();
            KahluaTable guarded = ownerGuard(table());
            Thread foreignThread = new Thread(() -> { try { export.measure(guarded, marker, 100); } catch (Throwable e) { other.set(e); } });
            foreignThread.start(); foreignThread.join();
            check(other.get() instanceof IllegalStateException && other.get().getMessage().contains("game thread"),
                "foreign thread rejected before live-table access");

            double obsolete = export.reserve("live", KEY + "/live/5");
            byte[] previous = Files.readAllBytes(root.resolve("StudyWorldLive.json"));
            try (Hold hold = new Hold()) {
                export.submitLive(obsolete, frame(false, 0), marker, 10000); start();
            }
            ThreadPoolExecutor executor = (ThreadPoolExecutor) field(export, "worker");
            CountDownLatch drained = new CountDownLatch(1); executor.execute(drained::countDown);
            check(drained.await(5, TimeUnit.SECONDS), "retired queue drains boundedly");
            check(Arrays.equals(previous, Files.readAllBytes(root.resolve("StudyWorldLive.json"))), "retired epoch cannot promote queued output");
            strict(() -> export.receiptStatus(obsolete), "retired", "retired receipt cannot be acknowledged");

            double inFlight = export.reserve("live", KEY + "/live/in-flight");
            Object receipt = ((java.util.Map<?, ?>) field(export, "receipts")).get((long) inFlight);
            Method detach = StudyExport.class.getDeclaredMethod("detach", Object.class, KahluaTable.class, long.class);
            detach.setAccessible(true);
            KahluaTable oldFrame = frame(false, 0); oldFrame.rawset("oldEpoch", true);
            Object detached = detach.invoke(null, oldFrame, marker, 10000L);
            Method publish = Arrays.stream(StudyExport.class.getDeclaredMethods()).filter(m -> m.getName().equals("publish")).findFirst().orElseThrow();
            publish.setAccessible(true);
            start();
            AtomicReference<Throwable> oldFailure = new AtomicReference<>();
            Thread completion = new Thread(() -> {
                try { publish.invoke(export, receipt, detached, null, null, null, 10000L); }
                catch (Throwable error) { oldFailure.set(error); }
            });
            completion.start(); completion.join(10000);
            check(!completion.isAlive() && oldFailure.get() == null, "retired in-flight worker terminates without live table access");
            check(Arrays.equals(previous, Files.readAllBytes(root.resolve("StudyWorldLive.json"))),
                "retired epoch cannot promote a completed worker snapshot");

            Path livePath = root.resolve("StudyWorldLive.json"); Files.delete(livePath); Files.createDirectory(livePath);
            Files.writeString(livePath.resolve("occupied"), "do not replace");
            double ioTicket = export.reserve("live", KEY + "/live/6");
            export.submitLive(ioTicket, frame(false, 0), marker, 10000); await(ioTicket, "failed");
            check(export.receiptFailure(ioTicket) != null && Files.isDirectory(livePath), "failed atomic publication preserves target and reports failure");
            export.release(ioTicket);
            Files.delete(livePath.resolve("occupied")); Files.delete(livePath);
            String saveName = (String) env.rawget("__saveName"), saveHex = (String) env.rawget("__saveHex");
            export.begin(DEFINITION, saveName, SESSION, OBSERVER, ENGINE);
            KahluaTable unicodeFrame = frame(true, 1), unicodeCaptured = status("captured", 1), unicodeDeferred = status("deferred", 1);
            for (KahluaTable data : new KahluaTable[]{unicodeFrame, unicodeCaptured, unicodeDeferred}) data.rawset("save", saveName);
            double unicodeTicket = export.reserve("archive", DEFINITION + "/" + saveName + "/" + SESSION + "/archive/1");
            String unicodePath = "StudyWorld/" + DEFINITION + "/" + saveHex + "/" + SESSION + "/0000000000000001.json";
            export.submitArchive(unicodeTicket, unicodeFrame, marker, 10000, unicodePath, unicodeCaptured, unicodeDeferred);
            await(unicodeTicket, "published");
            check(Files.readString(root.resolve(unicodePath)).equals(json(unicodeFrame) + "\n"),
                "Unicode save path matches installed Lua gsub/string.byte identity"); export.release(unicodeTicket);
            start();
            double reserved = export.reserve("live", KEY + "/live/7"); export.release(reserved);
            check(!StudyExport.hasPending(), "unsubmitted reservation releases without acquisition");
            stopControls();
            StudyExport.shutdown();
            strict(() -> export.reserve("live", KEY + "/live/8"), "no active", "closed worker refuses new capture");
            System.out.println("VALUE PASS cases=" + cases);
        } finally { StudyExport.abort(); }
    }
}
