import java.nio.file.Files;
import java.nio.file.Path;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.*;
import zombie.Lua.LuaManager;
import com.sao.bridge.SAOBridge;

/** Original installed Lua owners in native Kahlua; physical presentation host is controlled. */
public final class SchedulerProbe {
    public static void main(String[] args)throws Exception {
        var platform=new J2SEPlatform();var env=platform.newEnvironment();
        var thread=new KahluaThread(platform,env);thread.debugOwnerThread=Thread.currentThread();
        LuaManager.platform=platform;LuaManager.env=env;LuaManager.thread=thread;
        LuaCompiler.register(env);
        var sources=platform.newTable();
        for(String row:Files.readAllLines(Path.of(args[0]))){var parts=row.split("\t",2);sources.rawset(parts[0],Files.readString(Path.of(parts[1])).replace("\r\n","\n"));}
        env.rawset("__sources",sources);
        env.rawset("print",(JavaFunction)(frame,count)->{System.out.println(frame.get(0));return 0;});
        env.rawset("__nativeSame",(JavaFunction)(frame,count)->frame.push(SAOBridge.INSTANCE.sameNativeLuaSourceFunction(frame.get(0),frame.get(1))));
        env.rawset("__nativeEnvironment",(JavaFunction)(frame,count)->frame.push(SAOBridge.INSTANCE.nativeLuaSourceFunctionUsesEnvironment(frame.get(0),frame.get(1))));
        for(int i=1;i<args.length;i++)thread.call(LuaCompiler.loadstring(Files.readString(Path.of(args[i])),args[i],env),null,null,null);
    }
}
