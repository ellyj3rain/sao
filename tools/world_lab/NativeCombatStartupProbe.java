import java.lang.instrument.ClassFileTransformer;
import java.lang.instrument.Instrumentation;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.ProtectionDomain;

/** Inspect installed callback bytecode after the real study/gameplay agents. */
public final class NativeCombatStartupProbe {
    private static Instrumentation instrumentation;
    private static int checks;

    public static void premain(String ignored, Instrumentation value) {
        instrumentation = value;
    }

    private static void check(String name, boolean value) {
        checks++;
        System.out.println("CHECK " + name + "=" + value);
        if (!value) throw new AssertionError("COMBAT_STARTUP:" + name);
    }

    public static void main(String[] args) {
        try {
            var buddy = me.zed_0xff.zombie_buddy.Loader.class.getDeclaredField("g_instrumentation");
            buddy.setAccessible(true);
            check("native_zombiebuddy_installed", buddy.get(null) != null);
            check("observer_breakpoint_hook_installed", StudyLoadingAgent.emptyBreakpointLookupInstalled());
            Class<?> target = zombie.ai.states.SwipeStatePlayer.class;
            zombie.ai.states.SwipeStatePlayer.instance();
            Path destination = Path.of(args[0]);
            ClassFileTransformer capture = new ClassFileTransformer() {
                public byte[] transform(ClassLoader loader, String name, Class<?> redefined,
                        ProtectionDomain domain, byte[] bytes) {
                    if (redefined == target) {
                        try { Files.write(destination, bytes); }
                        catch (Exception failure) { throw new RuntimeException(failure); }
                    }
                    return null;
                }
            };
            instrumentation.addTransformer(capture, true);
            instrumentation.retransformClasses(target);
            instrumentation.removeTransformer(capture);
            check("actual_callback_bytes_retained", Files.isRegularFile(destination));
            check("combat_callbacks_ready", com.sao.agent.SAOCombatGate.isPatchReady());
            check("three_native_callbacks_transformed", com.sao.agent.SAOCombatGate.getPatchedCallCount() == 3);
            System.out.println("PASS native combat startup checks=" + checks);
            System.exit(0);
        } catch (Throwable failure) {
            failure.printStackTrace();
            System.exit(1);
        }
    }
}
