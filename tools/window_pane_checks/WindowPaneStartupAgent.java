import java.lang.instrument.Instrumentation;
/** Test entry installs precisely the production startup weave. */
public final class WindowPaneStartupAgent {
    public static void premain(String arguments,Instrumentation instrumentation){
        com.sao.agent.SAOWindowPaneDefinitionWeave.install(instrumentation);
    }
}
