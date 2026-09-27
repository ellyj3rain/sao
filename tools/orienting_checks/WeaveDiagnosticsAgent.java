import java.lang.instrument.Instrumentation;

/** Exercises the real entry point and repeat native retransformation, without a game. */
public final class WeaveDiagnosticsAgent {
    public static String entryReport;
    public static void premain(String args, Instrumentation instrumentation) throws Exception {
        boolean preload = args != null && args.contains("preload");
        if (preload) Class.forName(com.sao.agent.SAOOrientationWeave.TARGET, false, ClassLoader.getSystemClassLoader());
        if (args != null && args.startsWith("full")) com.sao.agent.SAOAgent.premain("sound-probe", instrumentation);
        else com.sao.agent.SAOOrientationWeave.install(instrumentation);
        entryReport = com.sao.agent.SAOOrientationWeave.report();
        Class<?> target = Class.forName(com.sao.agent.SAOOrientationWeave.TARGET, false, ClassLoader.getSystemClassLoader());
        instrumentation.retransformClasses(target);
        instrumentation.retransformClasses(target);
        com.sao.agent.SAOOrientationWeave.install(instrumentation);
    }
}
