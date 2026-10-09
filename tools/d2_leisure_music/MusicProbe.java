import java.nio.ByteBuffer;
import java.nio.file.Files;
import java.nio.file.Path;
import se.krka.kahlua.converter.KahluaConverterManager;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.*;
import zombie.Lua.LuaManager;

/** Native source compiler, Stats and save-load; physical hosts are controlled. */
public final class MusicProbe {
    public static void main(String[] args) throws Exception {
        var platform=new J2SEPlatform();var env=platform.newEnvironment();
        var thread=new KahluaThread(platform,env);thread.debugOwnerThread=Thread.currentThread();
        LuaManager.platform=platform;LuaManager.env=env;LuaManager.thread=thread;
        LuaManager.converterManager=new KahluaConverterManager();
        zombie.Lua.KahluaNumberConverter.install(LuaManager.converterManager);
        var exposer=new LuaManager.Exposer(LuaManager.converterManager,platform,env);
        for(var type:new Class<?>[]{zombie.characters.Stats.class,zombie.characters.CharacterStat.class}) {
            exposer.setExposed(type);exposer.exposeLikeJava(type,env);
        }
        LuaCompiler.register(env);
        var sources=platform.newTable();
        for(var row:Files.readAllLines(Path.of(args[0]))) {
            var parts=row.split("\t",2);sources.rawset(parts[0],Files.readString(Path.of(parts[1])).replace("\r\n","\n"));
        }
        env.rawset("__sources",sources);env.rawset("__stats",new zombie.characters.Stats());env.rawset("__stats2",new zombie.characters.Stats());
        env.rawset("print",(JavaFunction)(frame,count)->{System.out.println(frame.get(0));return 0;});
        env.rawset("__roundtrip",(JavaFunction)(frame,count)->{
            try {var bytes=ByteBuffer.allocate(1024*1024);((KahluaTable)frame.get(0)).save(bytes);bytes.flip();
                var restored=platform.newTable();restored.load(bytes,249);return frame.push(restored);
            } catch(Exception error){throw new IllegalStateException(error);}
        });
        env.rawset("__reload",(JavaFunction)(frame,count)->{
            try {thread.call(LuaCompiler.loadstring(Files.readString(Path.of(args[args.length-2])),"reload",env),null,null,null);}
            catch(Exception error){throw new IllegalStateException(error);}return 0;
        });
        for(int i=1;i<args.length;i++)thread.call(LuaCompiler.loadstring(Files.readString(Path.of(args[i])),args[i],env),null,null,null);
    }
}
