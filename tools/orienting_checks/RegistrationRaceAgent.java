import java.lang.instrument.Instrumentation;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Proxy;
import java.util.concurrent.atomic.AtomicBoolean;

/** Real native class admission just after the installer's loaded-class snapshot. */
public final class RegistrationRaceAgent {
    public static void premain(String args, Instrumentation instrumentation) {
        AtomicBoolean loaded = new AtomicBoolean();
        Instrumentation duringInstall = (Instrumentation) Proxy.newProxyInstance(
            RegistrationRaceAgent.class.getClassLoader(), new Class<?>[]{Instrumentation.class},
            (proxy, method, arguments) -> {
                Object result;
                try { result = method.invoke(instrumentation, arguments); }
                catch (InvocationTargetException error) { throw error.getCause(); }
                if (method.getName().equals("getAllLoadedClasses") && loaded.compareAndSet(false, true)) {
                    Class.forName("zombie.WorldSoundManager$WorldSound", false, ClassLoader.getSystemClassLoader());
                    System.out.println("NATIVE_SOUND_LOADED_AFTER_INSTALL_SNAPSHOT=true");
                }
                return result;
            });
        com.sao.agent.SAOOrientationWeave.install(duringInstall);
        System.out.println("AFTER_INSTALL " + com.sao.agent.SAOOrientationWeave.report());
    }
}
