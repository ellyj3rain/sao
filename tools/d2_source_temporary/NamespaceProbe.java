import java.nio.file.*;import java.util.*;
import zombie.Lua.Event;import zombie.Lua.LuaManager;
import se.krka.kahlua.converter.KahluaConverterManager;import se.krka.kahlua.integration.LuaCaller;
import se.krka.kahlua.j2se.J2SEPlatform;import se.krka.kahlua.luaj.compiler.LuaCompiler;import se.krka.kahlua.vm.*;
public final class NamespaceProbe {
 public static void main(String[] args)throws Exception {
  var platform=J2SEPlatform.getInstance();var env=platform.newEnvironment();var thread=new KahluaThread(platform,env);thread.debugOwnerThread=Thread.currentThread();LuaManager.env=env;LuaManager.thread=thread;
  var events=platform.newTable();env.rawset("Events",events);var nativeEvents=new HashMap<String,Event>();var caller=new LuaCaller(new KahluaConverterManager());
  for(String name:List.of("OnClientCommand","OnInitGlobalModData","OnFillWorldObjectContextMenu")){var e=new Event(name,nativeEvents.size());e.register(platform,events);nativeEvents.put(name,e);}
  env.rawset("emitServer",(JavaFunction)(f,n)->{nativeEvents.get("OnClientCommand").trigger(env,caller,new Object[]{"LS",f.get(0),f.get(1),f.get(2)});return 0;});
  env.rawset("nativeEventCount",(JavaFunction)(f,n)->f.push((double)nativeEvents.get((String)f.get(0)).callbacks.size()));
  var cats=platform.newTable();env.rawset("CATALOGUES",cats);env.rawset("MODE",args[0]);
  for(int i=1;i<args.length;i++){String file=args[i],key=null;if(file.startsWith("catalogue:")){int eq=file.indexOf('=');key=file.substring(10,eq);file=file.substring(eq+1);}try(var input=Files.newBufferedReader(Path.of(file))){Object result=thread.call(LuaCompiler.loadis(input,file,env),null,null,null);if(key!=null)cats.rawset(key,result);}}
  if(!Boolean.TRUE.equals(env.rawget("PROVEN")))throw new AssertionError("D2_TEMP:no-proof");System.out.println("PASS namespace mode="+args[0]+" checks="+env.rawget("CHECKS"));
 }
}
