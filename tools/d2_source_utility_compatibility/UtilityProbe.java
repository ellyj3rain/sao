import java.nio.file.*;
import java.lang.reflect.*;
import java.util.*;
import java.util.function.Function;
import zombie.Lua.Event;
import zombie.Lua.LuaManager;
import zombie.iso.IsoCell;
import zombie.iso.objects.IsoFeedingTrough;
import zombie.entity.components.fluids.FluidContainer;
import zombie.inventory.ItemContainer;
import zombie.core.Language;
import zombie.core.Translator;
import se.krka.kahlua.converter.KahluaConverterManager;
import se.krka.kahlua.integration.LuaCaller;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.*;

/** Native Event/feeding-trough fluid/Translator; Lua receiver wrappers and audio/queue host are controlled. */
public final class UtilityProbe {
    @SuppressWarnings("unchecked")
    public static void main(String[] args) throws Exception {
        var platform=J2SEPlatform.getInstance();var env=platform.newEnvironment();
        var thread=new KahluaThread(platform,env);thread.debugOwnerThread=Thread.currentThread();
        LuaManager.env=env;LuaManager.thread=thread;
        var caller=new LuaCaller(new KahluaConverterManager());
        var events=platform.newTable();env.rawset("Events",events);
        var actualEvents=new LinkedHashMap<String,Event>();
        for(String name:List.of("OnTick","EveryOneMinute")) {
            var event=new Event(name,actualEvents.size());event.register(platform,events);actualEvents.put(name,event);
        }
        env.rawset("eventCount",(JavaFunction)(f,n)->f.push((double)actualEvents.get((String)f.get(0)).callbacks.size()));
        env.rawset("emit",(JavaFunction)(f,n)->{actualEvents.get((String)f.get(0)).trigger(env,caller,new Object[0]);return 0;});
        var trough=new IsoFeedingTrough((IsoCell)null);trough.removeFluidContainer();
        var receiver=platform.newTable();var wrappers=new IdentityHashMap<FluidContainer,KahluaTable>();
        int[] creations={0};
        receiver.rawset("createFluidContainer",(JavaFunction)(f,n)->{trough.createFluidContainer();creations[0]++;return 0;});
        receiver.rawset("getFluidContainer",(JavaFunction)(f,n)->{
            var nativeFluid=trough.getFluidContainer();if(nativeFluid==null)return f.push(null);
            var wrapper=wrappers.computeIfAbsent(nativeFluid,x->{
                var t=platform.newTable();
                t.rawset("setCapacity",(JavaFunction)(a,c)->{x.setCapacity(((Number)a.get(1)).floatValue());return 0;});
                t.rawset("getCapacity",(JavaFunction)(a,c)->a.push((double)x.getCapacity()));
                return t;
            });return f.push(wrapper);
        });
        env.rawset("NATIVE_ENTITY",receiver);
        env.rawset("nativeFluidCapacity",(JavaFunction)(f,n)->f.push((double)trough.getFluidContainer().getCapacity()));
        env.rawset("nativeCreationCount",(JavaFunction)(f,n)->f.push((double)creations[0]));
        env.rawset("nativeRemoveFluid",(JavaFunction)(f,n)->{trough.removeFluidContainer();return 0;});
        var inventory=new ItemContainer();
        env.rawset("nativeCurrencyCount",(JavaFunction)(f,n)->f.push((double)inventory.getCountTypeRecurse((String)f.get(0))));
        var ctor=Language.class.getDeclaredConstructor(String.class,String.class,String.class,boolean.class);ctor.setAccessible(true);
        var english=ctor.newInstance("EN","English",null,false);Translator.language=english;
        var loader=Translator.class.getDeclaredMethod("tryFillMapFromFile",String.class,String.class,Map.class,Language.class,Function.class);loader.setAccessible(true);
        var mapField=Translator.class.getDeclaredField("contextMenu");mapField.setAccessible(true);
        var map=(Map<String,String>)mapField.get(null);map.clear();
        loader.invoke(null,args[0],"ContextMenu",map,english,Function.identity());
        loader.invoke(null,args[1],"ContextMenu",map,english,Function.identity());
        env.rawset("getText",(JavaFunction)(f,n)->f.push(Translator.getText((String)f.get(0))));
        env.rawset("MODE",args[2]);
        try {
            for(int i=3;i<args.length;i++)try(var input=Files.newBufferedReader(Path.of(args[i]))) {
                thread.call(LuaCompiler.loadis(input,args[i],env),null,null,null);
            }
        } finally {
            System.out.println("NATIVE_MEASURED creations="+creations[0]+" fluidPresent="+(trough.getFluidContainer()!=null)
                +" capacity="+(trough.getFluidContainer()==null?"absent":trough.getFluidContainer().getCapacity())
                +" nativeCurrency="+inventory.getCountTypeRecurse("Base.SilverCoin"));
        }
        if(!Boolean.TRUE.equals(env.rawget("PROVEN")))throw new AssertionError("D2_UTILITY:no_proof");
        System.out.println("PASS native utility mode="+args[2]+" checks="+env.rawget("CHECKS"));
    }
}
