// Border 61's instrument - run our Lua ON the engine, not near it.
//
// [B48] found that four modules computed an FNV step Kahlua cannot
// perform: `value * 16777619` overruns the 2^53 a double holds, so
// every character rounded its low bits away and the county's whole
// personality space collapsed to six values.
//
// [B48] had already tested four hypotheses about that code and
// cleared all four - by simulating the Lua in Python, in exact
// integers. The simulation was not wrong about the code. It was wrong
// about the machine, and a model more capable than the machine will
// always confirm that the code is fine.
//
// So this stops modelling. It loads real files into a real Kahlua VM -
// the one out of projectzomboid.jar when that jar is present, or the
// same se.krka.kahlua classes from the bundled kahlua jar when it is
// not - calls a real function, and prints what the engine actually
// returns.
//
// Usage: LuaRun [--engine <game dir>] <chunk.lua> [<chunk.lua> ...]
//               -- <lua expression>
// The expression is evaluated last and its value printed, one per
// line, as `VALUE <text>`. Anything thrown prints as `ERROR <text>`.
//
// [C86] --engine exposes the real shipped bridge into the environment
// before the chunks load (so the sweep prelude can capture it and
// forward to it), and after they load runs the game's own script pass
// over its own generated profession files. A county asked for engine
// data this way names its people from the engine's own pools and
// skills them from the engine's own definitions - and, because a name
// costs two county draws and the catalog grows every engine
// profession, it is NOT the county the same save name builds without
// the flag. [C66] holds per harness shape; the two runs are different
// counties and their rows cite different dumps.
//
// [C126] Engine helpers live in LuaRunEngine, loaded by name, so this
// file compiles against Kahlua alone. --engine still needs the game
// jar on the classpath at run time.
import java.io.FileInputStream;
import java.io.InputStreamReader;
import java.io.Reader;
import java.lang.reflect.Field;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.vm.KahluaThread;
import se.krka.kahlua.vm.LuaClosure;

public class LuaRun {
    public static void main(String[] args) {
        List<String> chunks = new ArrayList<>();
        String expr = null;
        String engineGame = null;
        boolean afterSep = false;
        boolean wantGame = false;
        for (String a : args) {
            if (wantGame) { engineGame = a; wantGame = false; continue; }
            if ("--".equals(a)) { afterSep = true; continue; }
            if (!afterSep && "--engine".equals(a)) { wantGame = true; continue; }
            if (afterSep) expr = (expr == null) ? a : expr + " " + a;
            else chunks.add(a);
        }
        if (expr == null) {
            System.out.println("ERROR no expression given after --");
            System.exit(2);
        }
        if (engineGame == null && wantGame) {
            System.out.println("ERROR --engine needs the game directory");
            System.exit(2);
        }

        J2SEPlatform platform = new J2SEPlatform();
        KahluaTable env = platform.newEnvironment();
        KahluaThread thread = new KahluaThread(platform, env);
        // The game's Kahlua fork checks this field from inside pcall
        // and NPEs when it is unset. Stock kahlua2 has no such field.
        try {
            Field f = thread.getClass().getField("debugOwnerThread");
            f.set(thread, Thread.currentThread());
        } catch (ReflectiveOperationException ignored) {
            // stock kahlua2
        }

        if (engineGame != null && !exposeEngine(env, platform, thread)) {
            System.exit(3);
        }

        try {
            for (String path : chunks) {
                try (Reader r = new InputStreamReader(
                        new FileInputStream(path), StandardCharsets.UTF_8)) {
                    LuaClosure c = LuaCompiler.loadis(r, path, env);
                    thread.call(c, null, null, null);
                }
            }
            if (engineGame != null && !loadEngineScripts(engineGame)) {
                System.exit(3);
            }
            LuaClosure probe = LuaCompiler.loadstring(
                "return " + expr, "probe", env);
            Object out = thread.call(probe, null, null, null);
            System.out.println("VALUE " + render(out));
        } catch (Throwable t) {
            String m = t.getMessage();
            System.out.println("ERROR " + t.getClass().getSimpleName() + ": "
                    + (m == null ? "(no message)" : m.replace('\n', ' ')));
            System.exit(1);
        }
    }

    private static boolean exposeEngine(KahluaTable env, J2SEPlatform platform,
            KahluaThread thread) {
        try {
            Class<?> helper = Class.forName("LuaRunEngine");
            Object ok = helper.getMethod("expose", KahluaTable.class,
                    J2SEPlatform.class, KahluaThread.class)
                .invoke(null, env, platform, thread);
            return Boolean.TRUE.equals(ok);
        } catch (ClassNotFoundException e) {
            System.out.println("ERROR --engine needs the game jar "
                + "and LuaRunEngine on the classpath");
            return false;
        } catch (Throwable t) {
            System.out.println("ERROR engine exposure failed: "
                + t.getClass().getSimpleName() + ": " + t.getMessage());
            return false;
        }
    }

    private static boolean loadEngineScripts(String game) {
        try {
            Class<?> helper = Class.forName("LuaRunEngine");
            Object ok = helper.getMethod("loadScripts", String.class)
                .invoke(null, game);
            return Boolean.TRUE.equals(ok);
        } catch (ClassNotFoundException e) {
            System.out.println("ERROR --engine needs the game jar "
                + "and LuaRunEngine on the classpath");
            return false;
        } catch (Throwable t) {
            System.out.println("ERROR engine scripts failed: "
                + t.getClass().getSimpleName() + ": " + t.getMessage());
            return false;
        }
    }

    // Kahlua hands back Doubles for every number; print integers without
    // the trailing .0 so a caller can compare them as written.
    private static String render(Object o) {
        if (o instanceof Double) {
            double d = (Double) o;
            if (d == Math.rint(d) && !Double.isInfinite(d)) {
                return String.valueOf((long) d);
            }
        }
        return String.valueOf(o);
    }
}
