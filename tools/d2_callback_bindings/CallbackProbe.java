import java.nio.file.*;
import java.util.*;
import zombie.Lua.Event;
import zombie.Lua.LuaManager;
import se.krka.kahlua.converter.KahluaConverterManager;
import se.krka.kahlua.integration.LuaCaller;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.*;

/** Actual installed Event registration/removal/dispatch, controlled source actor services. */
public final class CallbackProbe {
    public static void main(String[] args) throws Exception {
        var platform=J2SEPlatform.getInstance();
        var env=platform.newEnvironment();
        var thread=new KahluaThread(platform,env);
        thread.debugOwnerThread=Thread.currentThread();
        LuaManager.thread=thread;
        var caller=new LuaCaller(new KahluaConverterManager());
        var events=platform.newTable();
        env.rawset("Events",events);
        var nativeEvents=new LinkedHashMap<String,Event>();
        for(String name:List.of("OnTick","OnZombieDead","OnWeaponHitCharacter","OnPlayerUpdate")) {
            var event=new Event(name,nativeEvents.size());event.register(platform,events);nativeEvents.put(name,event);
        }
        env.rawset("eventCount",(JavaFunction)(frame,count)->frame.push((double)nativeEvents.get((String)frame.get(0)).callbacks.size()));
        env.rawset("emit",(JavaFunction)(frame,count)->{
            Object[] values=new Object[count-1];for(int i=1;i<count;i++)values[i-1]=frame.get(i);
            nativeEvents.get((String)frame.get(0)).trigger(env,caller,values);return 0;
        });
        env.rawset("CASE",args[0]);
        for(int i=1;i<args.length;i++) {
            try(var input=Files.newBufferedReader(Path.of(args[i]))) {
                thread.call(LuaCompiler.loadis(input,args[i],env),null,null,null);
            }
        }
        if(!Boolean.TRUE.equals(env.rawget("LIFECYCLE_PROVEN")))throw new AssertionError("D2_CALLBACK:no_lifecycle");
        System.out.println("PASS native Event lifecycle "+args[0]+" checks="+env.rawget("CHECKS"));
    }
}
