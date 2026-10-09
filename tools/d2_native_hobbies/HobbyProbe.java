import java.nio.ByteBuffer;
import java.nio.file.Files;
import java.nio.file.Path;
import se.krka.kahlua.converter.KahluaConverterManager;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.*;
import zombie.Lua.LuaManager;

/** Original source action/utility and native Stats/save-load. Body, clock,
 * queue, presentation, XP transport and canonical owner are controlled. */
public final class HobbyProbe {
    public static void main(String[] args) throws Exception {
        var platform = new J2SEPlatform(); var env = platform.newEnvironment();
        var thread = new KahluaThread(platform, env); thread.debugOwnerThread = Thread.currentThread();
        LuaCompiler.register(env);
        LuaManager.platform = platform; LuaManager.env = env; LuaManager.thread = thread;
        LuaManager.converterManager = new KahluaConverterManager();
        zombie.Lua.KahluaNumberConverter.install(LuaManager.converterManager);
        var exposer = new LuaManager.Exposer(LuaManager.converterManager, platform, env);
        for (var type : new Class<?>[]{ zombie.characters.Stats.class, zombie.characters.CharacterStat.class }) {
            exposer.setExposed(type); exposer.exposeLikeJava(type, env);
        }
        env.rawset("__stats", new zombie.characters.Stats());
        var sources=platform.newTable();
        sources.rawset("shared/LSUtil.lua",Files.readString(Path.of(args[3])).replace("\r\n","\n"));
        sources.rawset("shared/TimedActions/LSMeditateAction.lua",Files.readString(Path.of(args[4])).replace("\r\n","\n"));
        sources.rawset("client/TimedActions/PlayerVoiceTracks.lua",Files.readString(Path.of(args[5])).replace("\r\n","\n"));
        env.rawset("__sourceTexts",sources);
        env.rawset("print", (JavaFunction)(frame, count) -> { System.out.println(frame.get(0)); return 0; });
        env.rawset("__roundtrip", (JavaFunction)(frame, count) -> {
            try {
                var bytes = ByteBuffer.allocate(1024*1024); ((KahluaTable)frame.get(0)).save(bytes); bytes.flip();
                var restored = platform.newTable(); restored.load(bytes, 249); return frame.push(restored);
            } catch (Exception error) { throw new IllegalStateException(error); }
        });
        env.rawset("__reload", (JavaFunction)(frame, count) -> {
            try { thread.call(LuaCompiler.loadstring(Files.readString(Path.of(args[args.length-2])), "reload", env), null, null, null); }
            catch (Exception error) { throw new IllegalStateException(error); } return 0;
        });
        for (var path : args) thread.call(LuaCompiler.loadstring(Files.readString(Path.of(path)), path, env), null, null, null);
    }
}
