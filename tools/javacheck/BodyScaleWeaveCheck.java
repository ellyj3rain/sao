import com.sao.agent.SAOBodyScale;
import com.sao.agent.SAOBodyScaleWeave;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import org.lwjgl.util.vector.Matrix4f;

/**
 * [C29] Border 104's Java half: weave the installed game's real
 * AnimationPlayer bytes with SAO's advice, off the game, and check
 * that (1) the original never mentions the scaler, (2) the woven class
 * does, (3) the woven class links and verifies in a throwaway loader
 * over the game jar - a broken stack map would throw here, not in the
 * operator's game - and (4) the scaler's matrix arithmetic scales the
 * axes and the translation and leaves the homogeneous row alone.
 * Prints one WEAVE PASS or WEAVE FAIL line; tools/body_scale_test.py
 * reads it.
 */
public final class BodyScaleWeaveCheck {

    private BodyScaleWeaveCheck() {
    }

    public static void main(String[] args) throws Exception {
        String resource = SAOBodyScaleWeave.TARGET.replace('.', '/') + ".class";
        byte[] original;
        try (InputStream in = ClassLoader.getSystemResourceAsStream(resource)) {
            if (in == null) {
                System.out.println("WEAVE FAIL target class not on the classpath: " + resource);
                return;
            }
            original = in.readAllBytes();
        }
        String marker = "com/sao/agent/SAOBodyScale";
        boolean before = contains(original, marker);
        byte[] woven = SAOBodyScaleWeave.weave(original);
        boolean after = contains(woven, marker);
        System.out.println("original-bytes=" + original.length
            + " original-mentions-scaler=" + before);
        System.out.println("woven-bytes=" + woven.length
            + " woven-mentions-scaler=" + after);

        boolean verified = false;
        int methods = -1;
        try {
            Loader loader = new Loader(ClassLoader.getSystemClassLoader(),
                SAOBodyScaleWeave.TARGET, woven);
            Class<?> defined = loader.loadClass(SAOBodyScaleWeave.TARGET);
            methods = defined.getDeclaredMethods().length;
            verified = true;
        } catch (Throwable throwable) {
            System.out.println("woven-class-verified=false " + throwable);
        }
        if (verified) {
            System.out.println("woven-class-verified=true methods=" + methods);
        }

        Matrix4f matrix = new Matrix4f();
        matrix.setIdentity();
        matrix.m30 = 2f;
        SAOBodyScale.scaleMatrix(matrix, 0.5f);
        boolean arithmetic = matrix.m00 == 0.5f && matrix.m11 == 0.5f
            && matrix.m22 == 0.5f && matrix.m33 == 1f && matrix.m30 == 1f
            && matrix.m03 == 0f;
        System.out.println("matrix m00=" + matrix.m00 + " m33=" + matrix.m33
            + " m30=" + matrix.m30 + " arithmetic=" + arithmetic);
        System.out.println("clamp nan=" + SAOBodyScale.clamp(Float.NaN)
            + " zero=" + SAOBodyScale.clamp(0f)
            + " tiny=" + SAOBodyScale.clamp(0.01f)
            + " huge=" + SAOBodyScale.clamp(9f));

        boolean pass = !before && after && verified && arithmetic
            && SAOBodyScale.clamp(Float.NaN) == 1f
            && SAOBodyScale.clamp(0.01f) == SAOBodyScale.MIN
            && SAOBodyScale.clamp(9f) == SAOBodyScale.MAX;
        System.out.println("WEAVE " + (pass ? "PASS" : "FAIL"));
    }

    private static boolean contains(byte[] haystack, String needle) {
        byte[] bytes = needle.getBytes(StandardCharsets.UTF_8);
        outer:
        for (int i = 0; i + bytes.length <= haystack.length; i++) {
            for (int j = 0; j < bytes.length; j++) {
                if (haystack[i + j] != bytes[j]) {
                    continue outer;
                }
            }
            return true;
        }
        return false;
    }

    /** Defines exactly one class from bytes; everything else delegates
     *  to the parent, so the woven class links against the game's own
     *  classes. */
    private static final class Loader extends ClassLoader {
        private final String name;
        private final byte[] bytes;

        Loader(ClassLoader parent, String name, byte[] bytes) {
            super(parent);
            this.name = name;
            this.bytes = bytes;
        }

        @Override
        protected Class<?> loadClass(String requested, boolean resolve)
            throws ClassNotFoundException {
            if (requested.equals(name)) {
                Class<?> defined = findLoadedClass(requested);
                if (defined == null) {
                    defined = defineClass(requested, bytes, 0, bytes.length);
                }
                if (resolve) {
                    resolveClass(defined);
                }
                return defined;
            }
            return super.loadClass(requested, resolve);
        }
    }
}
