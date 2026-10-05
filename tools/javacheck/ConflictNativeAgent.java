import java.lang.instrument.Instrumentation;
/** Install the real callback transformer only; no game/bootstrap thread. */
public final class ConflictNativeAgent {
    public static void premain(String arguments, Instrumentation instrumentation) {
        instrumentation.addTransformer(new com.sao.agent.SAOMeleeTransformer(), false);
    }
}
