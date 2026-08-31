// Border 50 - the engine's own parser, run on our Lua before the game
// gets it. [B45] shipped six rewritten `if` conditions and noted that
// nothing in check.sh would have caught a broken one; the game would
// have, at load, which is the worst place to find out.
//
// This does not reimplement a Lua parser. It calls the compiler that
// ships inside projectzomboid.jar - se.krka.kahlua.luaj.compiler
// .LuaCompiler - so the answer is the engine's answer, not a guess at
// what the engine would say. Prints "OK <path>" or "FAIL <path>: msg"
// per argument, and exits 1 if any failed.
import java.io.FileInputStream;
import java.io.InputStreamReader;
import java.io.Reader;
import java.nio.charset.StandardCharsets;

import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.KahluaTable;

public class LuaSyntax {
    public static void main(String[] args) {
        J2SEPlatform platform = new J2SEPlatform();
        KahluaTable env = platform.newTable();
        int bad = 0;
        for (String path : args) {
            try (Reader r = new InputStreamReader(
                    new FileInputStream(path), StandardCharsets.UTF_8)) {
                LuaCompiler.loadis(r, path, env);
                System.out.println("OK " + path);
            } catch (Throwable t) {
                bad++;
                String m = t.getMessage();
                System.out.println("FAIL " + path + ": "
                        + t.getClass().getSimpleName() + ": "
                        + (m == null ? "(no message)" : m.replace('\n', ' ')));
            }
        }
        System.exit(bad == 0 ? 0 : 1);
    }
}
