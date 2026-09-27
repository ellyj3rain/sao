import java.lang.instrument.Instrumentation;
public final class OrientationProbeAgent {
    public static void premain(String args, Instrumentation instrumentation) throws Exception {
        if ("preload".equals(args)) Class.forName("zombie.WorldSoundManager$WorldSound", false, ClassLoader.getSystemClassLoader());
        com.sao.agent.SAOOrientationWeave.install(instrumentation);
    }
}
