// Border 51's instrument - every global name our Lua touches, as the
// engine sees it. Not a regex over source: Kahlua compiles the file
// and this walks the resulting bytecode, so a name reached through a
// table, a method call, or a nested closure is counted exactly once
// and a name that only appears inside a comment or a string is not
// counted at all.
//
// Opcode numbering is verified against the engine's own compiler, not
// remembered: compiling `WRITTEN = 1` and `local x = READ_ONE` yields
// op 7 carrying "WRITTEN" and op 5 carrying "READ_ONE". Note that
// `FOO.bar = 1` compiles to GETGLOBAL FOO + SETTABLE, so a write into
// a foreign namespace reads as a touch of FOO either way - which is
// the right granularity for a border about whose namespace we are in.
//
// Prints "<GET|SET> <name> <file>" per touch.
import java.io.FileInputStream;
import java.io.InputStreamReader;
import java.io.Reader;
import java.nio.charset.StandardCharsets;

import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.vm.LuaClosure;
import se.krka.kahlua.vm.Prototype;

public class LuaGlobals {
    private static final int OP_GETGLOBAL = 5;
    private static final int OP_SETGLOBAL = 7;

    public static void main(String[] args) {
        J2SEPlatform platform = new J2SEPlatform();
        KahluaTable env = platform.newTable();
        int bad = 0;
        for (String path : args) {
            try (Reader r = new InputStreamReader(
                    new FileInputStream(path), StandardCharsets.UTF_8)) {
                LuaClosure c = LuaCompiler.loadis(r, path, env);
                walk(c.prototype, path);
            } catch (Throwable t) {
                bad++;
                System.out.println("FAIL " + path + ": " + t);
            }
        }
        System.exit(bad == 0 ? 0 : 1);
    }

    private static void walk(Prototype p, String path) {
        for (int instruction : p.code) {
            int op = instruction & 0x3f;
            if (op != OP_GETGLOBAL && op != OP_SETGLOBAL) continue;
            int bx = (instruction >>> 14) & 0x3ffff;
            if (bx >= p.constants.length) continue;
            Object k = p.constants[bx];
            if (!(k instanceof String)) continue;
            System.out.println((op == OP_SETGLOBAL ? "SET " : "GET ")
                    + k + " " + path);
        }
        for (Prototype sub : p.prototypes) walk(sub, path);
    }
}
