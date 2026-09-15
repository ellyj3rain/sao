// [C86] Engine-mode helpers for LuaRun. Compiled only when
// projectzomboid.jar is on the classpath. LuaRun loads this class
// by name so the plain runner still compiles against Kahlua alone.
import java.nio.file.Files;
import java.nio.file.Path;

import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.vm.KahluaThread;

import zombie.characters.SurvivorFactory;
import zombie.characters.professions.CharacterProfessionDefinition;
import zombie.scripting.ScriptLoadMode;
import zombie.scripting.ScriptManager;
import zombie.scripting.ScriptParser;
import zombie.scripting.objects.ScriptModule;

public class LuaRunEngine {
    public static boolean expose(KahluaTable env, J2SEPlatform platform,
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
            exposer.exposeLikeJava(bridge, env);
            env.rawset("SAOJavaBridge", bridge.getField("INSTANCE").get(null));
            exposer.setExposed(SurvivorFactory.class);
            exposer.exposeLikeJava(SurvivorFactory.class, env);
            return true;
        } catch (Throwable t) {
            System.out.println("ERROR engine exposure failed: "
                + t.getClass().getSimpleName() + ": " + t.getMessage());
            return false;
        }
    }

    public static boolean loadScripts(String game) {
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
}
