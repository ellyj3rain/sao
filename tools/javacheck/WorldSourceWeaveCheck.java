import com.sao.agent.SAOLootDensityWeave;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;

/** Offline verification of R10a's one engine weave against installed bytes. */
public final class WorldSourceWeaveCheck {
    private WorldSourceWeaveCheck() {
    }

    public static void main(String[] args) throws Exception {
        String resource = SAOLootDensityWeave.TARGET.replace('.', '/') + ".class";
        byte[] original;
        try (InputStream in = ClassLoader.getSystemResourceAsStream(resource)) {
            if (in == null) {
                System.out.println("WEAVE FAIL target absent " + resource);
                return;
            }
            original = in.readAllBytes();
        }
        String marker = "com/sao/engine/SAOWorldSources";
        boolean before = contains(original, marker);
        byte[] woven = SAOLootDensityWeave.weave(original);
        boolean after = contains(woven, marker);

        boolean verified = false;
        int methods = -1;
        try {
            Loader loader = new Loader(ClassLoader.getSystemClassLoader(),
                SAOLootDensityWeave.TARGET, woven);
            Class<?> target = loader.loadClass(SAOLootDensityWeave.TARGET);
            methods = target.getDeclaredMethods().length;
            verified = true;
        } catch (Throwable throwable) {
            System.out.println("woven-class-verified=false " + throwable);
        }
        System.out.println("original-mentions-world-sources=" + before);
        System.out.println("woven-mentions-world-sources=" + after);
        System.out.println("woven-class-verified=" + verified + " methods=" + methods);
        System.out.println("WEAVE " + (!before && after && verified ? "PASS" : "FAIL"));
    }

    private static boolean contains(byte[] haystack, String needle) {
        byte[] bytes = needle.getBytes(StandardCharsets.UTF_8);
        outer:
        for (int i = 0; i + bytes.length <= haystack.length; i++) {
            for (int j = 0; j < bytes.length; j++) {
                if (haystack[i + j] != bytes[j]) continue outer;
            }
            return true;
        }
        return false;
    }

    private static final class Loader extends ClassLoader {
        private final String target;
        private final byte[] bytes;

        Loader(ClassLoader parent, String target, byte[] bytes) {
            super(parent);
            this.target = target;
            this.bytes = bytes;
        }

        @Override
        protected Class<?> loadClass(String name, boolean resolve)
                throws ClassNotFoundException {
            if (name.equals(target)) {
                Class<?> value = findLoadedClass(name);
                if (value == null) value = defineClass(name, bytes, 0, bytes.length);
                if (resolve) resolveClass(value);
                return value;
            }
            return super.loadClass(name, resolve);
        }
    }
}
