import java.nio.file.*;
import java.util.*;
import zombie.Lua.Event;
import zombie.Lua.LuaManager;
import zombie.iso.IsoObject;
import zombie.core.skinnedmodel.visual.ItemVisual;
import se.krka.kahlua.converter.KahluaConverterManager;
import se.krka.kahlua.integration.LuaCaller;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.*;
/** Native Kahlua/ItemVisual/IsoObject moddata; actor, queue, scene, audio/network host explicitly controlled. */
public final class InventionProbe {
 public static void main(String[] args) throws Exception {
  var platform=J2SEPlatform.getInstance();var env=platform.newEnvironment();var thread=new KahluaThread(platform,env);thread.debugOwnerThread=Thread.currentThread();LuaManager.env=env;LuaManager.thread=thread;
  var events=platform.newTable();env.rawset("Events",events);var actualEvents=new LinkedHashMap<String,Event>();var caller=new LuaCaller(new KahluaConverterManager());
  for(String name:List.of("OnTick","EveryOneMinute","OnEquipPrimary")){var event=new Event(name,actualEvents.size());event.register(platform,events);actualEvents.put(name,event);}
  env.rawset("nativeEventCount",(JavaFunction)(f,n)->f.push((double)actualEvents.get((String)f.get(0)).callbacks.size()));
  var visual=new ItemVisual();var visualWrapper=platform.newTable();
  visualWrapper.rawset("setTextureChoice",(JavaFunction)(f,n)->{visual.setTextureChoice(((Number)f.get(1)).intValue());return 0;});
  visualWrapper.rawset("getTextureChoice",(JavaFunction)(f,n)->f.push((double)visual.getTextureChoice()));env.rawset("NATIVE_VISUAL",visualWrapper);
  var object=new IsoObject();env.rawset("NATIVE_ICE_DATA",object.getModData());env.rawset("MODE",args[0]);
  try {for(int i=1;i<args.length;i++)try(var in=Files.newBufferedReader(Path.of(args[i]))){thread.call(LuaCompiler.loadis(in,args[i],env),null,null,null);}}
  finally {System.out.println("NATIVE_MEASURED texture="+visual.getTextureChoice()+" iceData="+object.getModData().rawget("movableData"));}
  if(!Boolean.TRUE.equals(env.rawget("PROVEN")))throw new AssertionError("D2_INVENTION:no-proof");
  System.out.println("PASS native source mode="+args[0]+" checks="+env.rawget("CHECKS"));
 }
}
