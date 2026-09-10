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
// The bridge is loaded by name, not by class, so this file still
// compiles against the engine jar alone - every border that builds
// LuaRun is untouched, and the mod's jar joins the classpath only
// where the caller asks for engine data.
import java.io.FileInputStream;
import java.io.InputStreamReader;
import java.io.Reader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.vm.KahluaThread;
import se.krka.kahlua.vm.LuaClosure;

import zombie.characters.SurvivorFactory;
import zombie.characters.professions.CharacterProfessionDefinition;
import zombie.scripting.ScriptLoadMode;
import zombie.scripting.ScriptManager;
import zombie.scripting.ScriptParser;
import zombie.scripting.objects.ScriptModule;

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
        // Kahlua checks this field from inside pcall and NPEs when
        // it is unset - the game fills it in on its own Lua thread.
        thread.debugOwnerThread = Thread.currentThread();

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
            if (engineGame != null
                    && !loadEngineScripts(engineGame, env, thread)) {
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

    // [C86] The real bridge and the engine's own statics, exposed into
    // this environment the way the game's own LuaManager.init() does
    // in play: its statics pointed here, its number converter
    // installed (Kahlua passes every Lua number as a Double, and this
    // is what narrows one to an int argument), its Exposer built over
    // this converter, platform and environment. The prelude captures
    // what this installs, so the exposure must happen before the
    // first chunk loads.
    private static boolean exposeEngine(KahluaTable env, J2SEPlatform platform,
            KahluaThread thread) {
        try {
            zombie.Lua.LuaManager.platform = platform;
            zombie.Lua.LuaManager.env = env;
            zombie.Lua.LuaManager.converterManager =
                new se.krka.kahlua.converter.KahluaConverterManager();
            zombie.Lua.LuaManager.caller =
                new se.krka.kahlua.integration.LuaCaller(
                    zombie.Lua.LuaManager.converterManager);
            zombie.Lua.KahluaNumberConverter.install(
                zombie.Lua.LuaManager.converterManager);
            zombie.Lua.LuaManager.thread = thread;
            zombie.Lua.LuaManager.Exposer exposer =
                new zombie.Lua.LuaManager.Exposer(
                    zombie.Lua.LuaManager.converterManager, platform, env);
            Class<?> bridge = Class.forName("com.sao.bridge.SAOBridge");
            exposer.setExposed(bridge);
            // The two-argument form: the one-argument exposeLikeJava
            // reads a field the Exposer's constructor leaves null.
            exposer.exposeLikeJava(bridge, env);
            env.rawset("SAOJavaBridge", bridge.getField("INSTANCE").get(null));
            // exposeStatics - inside exposeLikeJava - builds the
            // package-path table and installs env.SurvivorFactory
            // itself; rawsetting the Class object here would clobber
            // that table with a value no metatable answers for.
            exposer.setExposed(SurvivorFactory.class);
            exposer.exposeLikeJava(SurvivorFactory.class, env);
            return true;
        } catch (Throwable t) {
            System.out.println("ERROR engine exposure failed: "
                + t.getClass().getSimpleName() + ": " + t.getMessage());
            return false;
        }
    }

    // [C86] The engine's own two-phase script pass over its own
    // generated profession files, exactly the two phases the game
    // runs: ParseScript collects bodies into the module's buckets,
    // LoadScripts compiles them - traits before professions, because a
    // profession body grants traits it resolves through the trait
    // registry. The loader's own bookkeeping throws headless after
    // registration (getScriptObjectFullType, on a script whose name is
    // unset) and swallows itself into its per-script catch, so its
    // scriptList reads empty and hasLoadErrors true; the registry the
    // bridge reads completed first and is what the ENGINE line below
    // reports. ZomboidFileSystem.init roots its base folder here
    // because the profession constructor loads its icon through it,
    // and a null base is the thrower that left one definition of
    // twenty-five standing.
    private static boolean loadEngineScripts(String game, KahluaTable env,
            KahluaThread thread) {
        try {
            Path dir = Path.of(game, "media", "scripts", "generated",
                "characters");
            String traits = ScriptParser.stripComments(
                Files.readString(dir.resolve("character_traits.txt")));
            String professions = ScriptParser.stripComments(
                Files.readString(dir.resolve("character_professions.txt")));
            zombie.ZomboidFileSystem.instance.init();
            ScriptManager sm = ScriptManager.instance;
            sm.ParseScript(ScriptLoadMode.Init, traits);
            sm.ParseScript(ScriptLoadMode.Init, professions);
            ScriptModule base = sm.getModule("Base");
            base.characterTraitScripts.LoadScripts(ScriptLoadMode.Init);
            base.characterProfessionScripts.LoadScripts(ScriptLoadMode.Init);

            int male = SurvivorFactory.MaleForenames.size();
            int female = SurvivorFactory.FemaleForenames.size();
            int surnames = SurvivorFactory.Surnames.size();
            int defs = CharacterProfessionDefinition.getProfessions().size();
            System.out.println("ENGINE pools male=" + male + " female=" + female
                + " surnames=" + surnames + " professions=" + defs);
            // A run that would name nobody or skill nobody is not an
            // engine run that failed quietly - it is a run that did
            // not happen. The fills and the definitions either landed
            // or the whole run reports itself.
            if (male == 0 || female == 0 || surnames == 0 || defs == 0) {
                System.out.println("ERROR engine data absent: pools male="
                    + male + " female=" + female + " surnames=" + surnames
                    + " professions=" + defs);
                return false;
            }
            return true;
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