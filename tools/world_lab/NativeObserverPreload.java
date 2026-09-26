import java.lang.instrument.Instrumentation;

/** Probe-only preload reproducing an engine class defined before observer hooks.
 * It does not initialize the class, a world, renderer or native update loop.
 */
public final class NativeObserverPreload {
    public static void premain(String argument, Instrumentation instrumentation) throws Exception {
        Class<?> chunkMap = Class.forName("zombie.iso.IsoChunkMap", false, ClassLoader.getSystemClassLoader());
        boolean found = false;
        for (Class<?> loaded : instrumentation.getAllLoadedClasses()) if (loaded == chunkMap) found = true;
        if (!found) throw new AssertionError("probe failed to preload native chunk map");
        System.out.println("[StudyProbe] IsoChunkMap loaded before observer premain");
    }
}
