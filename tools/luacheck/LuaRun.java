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
// the one out of projectzomboid.jar - calls a real function, and
// prints what the engine actually returns.
//
// Usage: LuaRun <chunk.lua> [<chunk.lua> ...] -- <lua expression>
// The expression is evaluated last and its value printed, one per
// line, as `VALUE <text>`. Anything thrown prints as `ERROR <text>`.
import java.io.FileInputStream;
import java.io.InputStreamReader;
import java.io.Reader;
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
        boolean afterSep = false;
        for (String a : args) {
            if ("--".equals(a)) { afterSep = true; continue; }
            if (afterSep) expr = (expr == null) ? a : expr + " " + a;
            else chunks.add(a);
        }
        if (expr == null) {
            System.out.println("ERROR no expression given after --");
            System.exit(2);
        }

        J2SEPlatform platform = new J2SEPlatform();
        KahluaTable env = platform.newEnvironment();
        KahluaThread thread = new KahluaThread(platform, env);
        // Kahlua checks this field from inside pcall and NPEs when
        // it is unset - the game fills it in on its own Lua thread.
        thread.debugOwnerThread = Thread.currentThread();

        try {
            for (String path : chunks) {
                try (Reader r = new InputStreamReader(
                        new FileInputStream(path), StandardCharsets.UTF_8)) {
                    LuaClosure c = LuaCompiler.loadis(r, path, env);
                    thread.call(c, null, null, null);
                }
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
