import java.lang.instrument.Instrumentation;
import net.bytebuddy.agent.builder.AgentBuilder;
import net.bytebuddy.matcher.ElementMatchers;

/** Deliberately recreates a native dependency resolved inside a later mod's
 * transformation, after the real study/SAO/ZombieBuddy bootstrap has returned. */
public final class LateNativeLoadAgent {
    private static Instrumentation instrumentation;
    public static boolean nestedLoad;
    public static void premain(String args, Instrumentation value) { instrumentation = value; }

    public static void resolveDuringLaterTransform() {
        new AgentBuilder.Default().disableClassFormatChanges()
            .with(AgentBuilder.RedefinitionStrategy.RETRANSFORMATION)
            .type(ElementMatchers.named("zombie.WorldSoundManager"))
            .transform((builder, type, loader, module, domain) -> {
                try {
                    Class.forName("zombie.WorldSoundManager$WorldSound", false, loader);
                    nestedLoad = true;
                } catch (ClassNotFoundException failure) { throw new IllegalStateException(failure); }
                return builder;
            }).installOn(instrumentation);
        try { Class.forName("zombie.WorldSoundManager", false, ClassLoader.getSystemClassLoader()); }
        catch (ClassNotFoundException failure) { throw new IllegalStateException(failure); }
    }

    public static Class<?> loadedSound() {
        for (Class<?> type : instrumentation.getAllLoadedClasses())
            if (type.getName().equals("zombie.WorldSoundManager$WorldSound")) return type;
        return null;
    }
}
