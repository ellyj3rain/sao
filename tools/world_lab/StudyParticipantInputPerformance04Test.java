import java.lang.instrument.Instrumentation;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.nio.charset.Charset;
import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.util.BitSet;
import net.bytebuddy.agent.builder.AgentBuilder;
import net.bytebuddy.asm.MemberSubstitution;
import net.bytebuddy.matcher.ElementMatchers;
import zombie.core.Core;
import zombie.input.KeyboardState;
import zombie.input.MouseState;
import org.lwjglx.opengl.Display;

/** Actual input implementation exercised against labeled engine stubs.
 * Probe substitutions count real production file/focus call sites. The
 * preimage control uses the same scalar-query packet and fails the bound.
 */
public final class StudyParticipantInputPerformance04Test {
    static final String SESSION = "12345678-1234-1234-1234-123456789abc";
    static Path root, lease;
    static int checks, failures;
    static Method begin;
    interface Run { void run() throws Exception; }

    public static final class Probes {
        static int fileProbes, fileSizes, fileReads, focusProbes;
        public static boolean regular(Path path, LinkOption[] options) {
            fileProbes++;
            return Files.isRegularFile(path, options);
        }
        public static long size(Path path) throws Exception {
            fileSizes++;
            return Files.size(path);
        }
        public static String read(Path path, Charset charset) throws Exception {
            fileReads++;
            return Files.readString(path, charset);
        }
        public static boolean focus() throws Exception {
            focusProbes++;
            Method method = Class.forName("StudyParticipantInput").getDeclaredMethod("focusLost");
            method.setAccessible(true);
            return (boolean) method.invoke(null);
        }
        static void reset() { fileProbes = fileSizes = fileReads = focusProbes = 0; }
    }

    public static final class ProbeAgent {
        public static void premain(String args, Instrumentation instrumentation) throws Exception {
            new AgentBuilder.Default().disableClassFormatChanges()
                .with(AgentBuilder.RedefinitionStrategy.RETRANSFORMATION)
                .with(AgentBuilder.Listener.StreamWriting.toSystemError().withErrorsOnly())
                .type(ElementMatchers.named("StudyParticipantInput"))
                .transform((builder, type, loader, module, domain) -> {
                    try {
                        return builder
                            .visit(MemberSubstitution.strict().method(ElementMatchers.named("isRegularFile")
                                .and(ElementMatchers.isDeclaredBy(Files.class)))
                                .replaceWith(Probes.class.getMethod("regular", Path.class, LinkOption[].class))
                                .on(ElementMatchers.any()))
                            .visit(MemberSubstitution.strict().method(ElementMatchers.named("size")
                                .and(ElementMatchers.isDeclaredBy(Files.class)))
                                .replaceWith(Probes.class.getMethod("size", Path.class)).on(ElementMatchers.any()))
                            .visit(MemberSubstitution.strict().method(ElementMatchers.named("readString")
                                .and(ElementMatchers.isDeclaredBy(Files.class)))
                                .replaceWith(Probes.class.getMethod("read", Path.class, Charset.class))
                                .on(ElementMatchers.any()))
                            .visit(MemberSubstitution.strict().method(ElementMatchers.named("focusLost")
                                .and(ElementMatchers.isDeclaredBy(ElementMatchers.named("StudyParticipantInput"))))
                                .replaceWith(Probes.class.getMethod("focus")).on(ElementMatchers.named("refresh")));
                    } catch (ReflectiveOperationException failure) { throw new IllegalStateException(failure); }
                }).installOn(instrumentation);
        }
    }

    static void field(String name, Object value) throws Exception {
        Field field = StudyParticipantInput.class.getDeclaredField(name);
        field.setAccessible(true); field.set(null, value);
    }
    static void reset() throws Exception {
        zombie.characters.IsoPlayer.players[0] = new zombie.characters.IsoPlayer();
        zombie.iso.IsoWorld.instance.currentCell = new zombie.iso.IsoCell();
        zombie.GameTime.hours = 25.5;
        Core.gameSaveWorld = "ScratchSave"; Core.currentTextEntryBox = null;
        zombie.ZomboidFileSystem.instance.directory = null;
        Display.active = true; Display.fail = false;
        for (String name : new String[] { "heldKeys", "heldButtons" }) {
            Field field = StudyParticipantInput.class.getDeclaredField(name);
            field.setAccessible(true); ((BitSet) field.get(null)).clear();
        }
        field("acceptedGeneration", -1L); field("acceptedLeaseId", null);
        field("releasing", false); field("offline", true);
        field("focusProbeAvailable", null); field("displayIsActive", null);
        System.setProperty("study.participantInput", "true");
        System.setProperty("study.participantSession", SESSION);
        System.setProperty("study.participantLease", lease.toString());
        System.clearProperty("study.observer");
        System.setProperty("study.attempt", "1");
        System.setProperty("study.participantState", root.resolve("state.json").toString());
        Files.deleteIfExists(lease);
        StudyParticipantInput.enableFromProperties(); Probes.reset();
    }
    static void begin() throws Exception { if (begin != null) begin.invoke(null); }
    static boolean key() throws Exception {
        begin(); return StudyParticipantInput.isKeyDown(new KeyboardState(), 17);
    }
    static String value(long generation, long expires, boolean released) {
        long pid = ProcessHandle.current().pid();
        return "{\"schema\":\"sao.participant-input-lease/1\",\"sessionId\":\"" + SESSION
            + "\",\"pid\":" + pid + ",\"holderPid\":" + pid + ",\"attempt\":1,\"save\":\"ScratchSave\""
            + ",\"playerIndex\":0,\"playerSqlId\":1,\"leaseId\":\"lease-a\",\"generation\":" + generation
            + ",\"expiresAtUnixMs\":" + expires + ",\"released\":" + released
            + ",\"keys\":[17],\"mouse\":{\"x\":10,\"y\":20,\"buttons\":[0]}}";
    }
    static String valid(long generation) { return value(generation, System.currentTimeMillis() + 1500, false); }
    static void write(String value) throws Exception { Files.writeString(lease, value); }
    static void require(boolean value, String label) { if (!value) throw new AssertionError(label); }
    static void test(String label, Run run) throws Exception {
        reset(); checks++;
        try { run.run(); System.out.println("CONTROL PASS " + label); }
        catch (Throwable failure) {
            failures++; System.out.println("CONTROL FAIL " + label + " :: " + failure);
        }
    }
    static void packet(boolean leased) throws Exception {
        KeyboardState keys = new KeyboardState(); MouseState mouse = new MouseState();
        if (Boolean.getBoolean("study.realInputUpdates")) {
            zombie.input.GameKeyboard.update(); zombie.input.Mouse.update();
            require(zombie.input.GameKeyboard.observed == leased, "instrumented native key snapshot");
            require(zombie.input.Mouse.observed == leased, "instrumented native mouse snapshot");
        } else {
            begin();
            for (int key = 1; key < 256; key++) {
                boolean down = StudyParticipantInput.isKeyDown(keys, key);
                require(down == (leased && key == 17), "scalar native key value " + key);
            }
            begin();
            require(StudyParticipantInput.getX(mouse) == (leased ? 10 : 77), "native X");
            require(StudyParticipantInput.getY(mouse) == (leased ? 20 : 88), "native Y");
            for (int button = 0; button < 8; button++) {
                for (int twice = 0; twice < 2; twice++) {
                    require(StudyParticipantInput.isButtonDown(mouse, button) == (leased && button == 0),
                        "scalar native button value " + button);
                }
            }
        }
    }
    static void performance(boolean leased) throws Exception {
        if (leased) write(valid(1));
        Probes.reset(); packet(leased);
        System.out.println("PROBES leased=" + leased + " file=" + Probes.fileProbes
            + " size=" + Probes.fileSizes + " read=" + Probes.fileReads + " focus=" + Probes.focusProbes);
        require(Probes.fileProbes == 2 && Probes.focusProbes == 2,
            "native update bound: file=" + Probes.fileProbes + " focus=" + Probes.focusProbes);
        require(Probes.fileSizes == (leased ? 2 : 0) && Probes.fileReads == (leased ? 2 : 0),
            "lease reads multiply with scalar queries");
    }

    public static void main(String[] args) throws Exception {
        root = Path.of(args[0]); Files.createDirectories(root); lease = root.resolve("lease.json");
        try { begin = StudyParticipantInput.class.getMethod("beginInputUpdate"); }
        catch (NoSuchMethodException preimage) { begin = null; }
        test("offline-query-io-bounded", () -> performance(false));
        test("owned-query-io-bounded", () -> performance(true));
        if (Boolean.getBoolean("study.onlyPerformance")) {
            System.out.println("checks=" + checks + "; failures=" + failures); System.exit(failures == 0 ? 0 : 1);
        }
        test("native-menu-before-update", () -> {
            zombie.characters.IsoPlayer.players[0] = null;
            KeyboardState state = new KeyboardState(); state.physical = true;
            require(StudyParticipantInput.isKeyDown(state, 17), "menu physical key");
            require(StudyParticipantInput.getX(new MouseState()) == 77 && StudyParticipantInput.getY(new MouseState()) == 88,
                "menu physical pointer"); require(Probes.fileProbes == 0, "getter performed disk I/O");
        });
        test("native-menu-no-body", () -> { zombie.characters.IsoPlayer.players[0] = null; write(valid(1)); require(!key(), "menu accepted bodyless lease"); });
        test("physical-button-native-only", () -> { MouseState state = new MouseState(); state.physical = true; require(StudyParticipantInput.isButtonDown(state, 0), "physical mouse"); });
        test("focus-loss-update", () -> { write(valid(1)); require(key(), "precondition"); Display.active = false; begin(); require(!StudyParticipantInput.isKeyDown(new KeyboardState(), 17), "focus retained input"); });
        test("focus-return-needs-new-generation", () -> { write(valid(1)); require(key(), "precondition"); Display.active = false; key(); Display.active = true; require(!key(), "focus auto-resumed"); write(valid(2)); require(key(), "new focused intent"); });
        test("focus-probe-failure", () -> { write(valid(1)); Display.fail = true; require(!key(), "failed focus admitted"); });
        test("typing-between-queries-immediate", () -> { write(valid(1)); require(key(), "precondition"); Core.currentTextEntryBox = () -> true; require(!StudyParticipantInput.isKeyDown(new KeyboardState(), 17) && StudyParticipantInput.getX(new MouseState()) == 77, "typing retained lease"); });
        test("typing-return-needs-new-generation", () -> { write(valid(1)); require(key(), "precondition"); Core.currentTextEntryBox = () -> true; key(); Core.currentTextEntryBox = null; require(!key(), "typing auto-resumed"); write(valid(2)); require(key(), "new typing intent"); });
        test("expiry-between-queries-immediate", () -> { write(value(1, System.currentTimeMillis() + 150, false)); require(key(), "precondition"); Thread.sleep(180); require(!StudyParticipantInput.isKeyDown(new KeyboardState(), 17), "expired scalar retained"); });
        test("death-between-queries-immediate", () -> { write(valid(1)); require(key(), "precondition"); zombie.characters.IsoPlayer.players[0].dead = true; require(!StudyParticipantInput.isKeyDown(new KeyboardState(), 17), "dead scalar retained"); });
        test("body-replacement-between-queries-immediate", () -> { write(valid(1)); require(key(), "precondition"); zombie.characters.IsoPlayer.players[0] = new zombie.characters.IsoPlayer(); require(!StudyParticipantInput.isKeyDown(new KeyboardState(), 17), "replaced scalar retained"); });
        test("sql-change-between-queries-immediate", () -> { write(valid(1)); require(key(), "precondition"); zombie.characters.IsoPlayer.players[0].sqlId = 7; require(!StudyParticipantInput.isKeyDown(new KeyboardState(), 17), "SQL scalar retained"); });
        test("save-change-between-queries-immediate", () -> { write(valid(1)); require(key(), "precondition"); Core.gameSaveWorld = "OtherSave"; require(!StudyParticipantInput.isKeyDown(new KeyboardState(), 17), "save scalar retained"); });
        test("save-disappears-between-queries-immediate", () -> { write(valid(1)); require(key(), "precondition"); Core.gameSaveWorld = null; require(!StudyParticipantInput.isKeyDown(new KeyboardState(), 17), "unknown save scalar retained"); });
        test("unloaded-square-between-queries-immediate", () -> { write(valid(1)); require(key(), "precondition"); zombie.characters.IsoPlayer.players[0].square = null; require(!StudyParticipantInput.isKeyDown(new KeyboardState(), 17), "unloaded scalar retained"); });
        test("native-positive-sql-seven", () -> { zombie.characters.IsoPlayer.players[0].sqlId = 7; write(valid(1).replace("\"playerSqlId\":1", "\"playerSqlId\":7")); require(key(), "native SQL7 refused"); });
        test("foreign-sql-refused", () -> { zombie.characters.IsoPlayer.players[0].sqlId = 7; write(valid(1)); require(!key(), "foreign SQL accepted"); });
        test("native-save-fallback", () -> { Core.gameSaveWorld = null; zombie.ZomboidFileSystem.instance.directory = "C:/isolated/ScratchSave"; write(valid(1)); require(key(), "native fallback refused"); });
        test("unknown-save-refused", () -> { Core.gameSaveWorld = null; write(valid(1)); require(!key(), "unknown save accepted"); });
        test("foreign-save-refused", () -> { write(valid(1).replace("ScratchSave", "OtherSave")); require(!key(), "foreign save accepted"); });
        test("foreign-session-refused", () -> { write(valid(1).replace(SESSION, "22345678-1234-1234-1234-123456789abc")); require(!key(), "foreign session accepted"); });
        test("foreign-pid-refused", () -> { write(valid(1).replace("\"pid\":" + ProcessHandle.current().pid(), "\"pid\":1")); require(!key(), "foreign PID accepted"); });
        test("dead-holder-refused", () -> { require(ProcessHandle.of(Integer.MAX_VALUE).isEmpty(), "dead PID control unavailable"); write(valid(1).replace("\"holderPid\":" + ProcessHandle.current().pid(), "\"holderPid\":" + Integer.MAX_VALUE)); require(!key(), "dead holder accepted"); });
        test("foreign-attempt-refused", () -> { write(valid(1).replace("\"attempt\":1", "\"attempt\":2")); require(!key(), "foreign attempt accepted"); });
        test("duplicate-fields-refused", () -> { write(valid(1).replace("\"keys\":[17]", "\"keys\":[17],\"keys\":[]")); require(!key(), "duplicate fields accepted"); });
        test("malformed-json-refused", () -> { write(valid(1) + " garbage"); require(!key(), "malformed JSON accepted"); });
        test("unknown-field-refused", () -> { String value = valid(1); write(value.substring(0, value.length() - 1) + ",\"unknown\":true}"); require(!key(), "unknown field accepted"); });
        test("release-update-and-generation-floor", () -> { write(valid(5)); require(key(), "precondition"); write(value(10, System.currentTimeMillis() + 1000, true)); require(!key(), "release retained"); write(valid(7)); require(!key(), "release generation rollback"); });
        test("rollback-refused", () -> { write(valid(10)); require(key(), "precondition"); write(valid(5)); require(!key(), "generation rollback"); });
        test("changed-lease-id-refused", () -> { write(valid(1)); require(key(), "precondition"); write(valid(2).replace("lease-a", "lease-b")); require(!key(), "lease identity changed"); });
        test("deleted-lease-update-and-new-intent", () -> { write(valid(1)); require(key(), "precondition"); Files.delete(lease); require(!key(), "deleted lease retained"); write(valid(1)); require(!key(), "same reconnect intent"); write(valid(2)); require(key(), "new reconnect intent"); });
        System.out.println("checks=" + checks + "; pass=" + (checks - failures) + "; failures=" + failures
            + "; scope=controlled-engine-stubs; realInputUpdates=" + Boolean.getBoolean("study.realInputUpdates"));
        System.exit(failures == 0 ? 0 : 1);
    }
}
