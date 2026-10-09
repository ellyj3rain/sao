import java.nio.file.*;import java.util.*;import java.util.regex.*;
import zombie.Lua.Event;import zombie.Lua.LuaManager;import zombie.network.GameServer;
import se.krka.kahlua.converter.KahluaConverterManager;import se.krka.kahlua.integration.LuaCaller;
import se.krka.kahlua.j2se.J2SEPlatform;import se.krka.kahlua.luaj.compiler.LuaCompiler;import se.krka.kahlua.vm.*;
/** Native compiler/Event/time/server predicate; controlled UI, scene and acoustic hosts. */
public final class ResidualMusicArcadeProbe {
 static KahluaTable env;static KahluaThread thread;static List<String> modules=new ArrayList<>();static Map<String,Event> events=new HashMap<>();
 static Object load(String file)throws Exception{try(var input=Files.newBufferedReader(Path.of(file))){var result=thread.pcall(LuaCompiler.loadis(input,file,env),new Object[]{});if(!Boolean.TRUE.equals(result[0])||env.rawget("FAILED_REASON")!=null)throw new AssertionError("source="+file+" result="+Arrays.toString(result)+" assertion="+env.rawget("FAILED_REASON"));return result.length>1?result[1]:null;}}
 static LuaClosure find(Object obj,Set<Object> seen,String name,int from,int to){
  if(obj==null||!seen.add(obj))return null;
  if(obj instanceof LuaClosure c){int min=Arrays.stream(c.prototype.lines).min().orElse(-1),max=Arrays.stream(c.prototype.lines).max().orElse(-1);
   if(min>=from&&max<to&&name.equals(c.prototype.name))return c;
   for(var u:c.upvalues){var found=find(u.getValue(),seen,name,from,to);if(found!=null)return found;}
  }else if(obj instanceof KahluaTable t){var it=t.iterator();while(it.advance()){var found=find(it.getValue(),seen,name,from,to);if(found!=null)return found;}}
  return null;
 }
 public static void main(String[]args)throws Exception{
  var platform=J2SEPlatform.getInstance();env=platform.newEnvironment();thread=new KahluaThread(platform,env);thread.debugOwnerThread=Thread.currentThread();LuaManager.env=env;LuaManager.thread=thread;
  var table=platform.newTable();env.rawset("Events",table);var caller=new LuaCaller(new KahluaConverterManager());
  env.rawset("nativeFail",(JavaFunction)(f,n)->{env.rawset("FAILED_REASON","D2_RESIDUAL:"+f.get(0));throw new AssertionError("D2_RESIDUAL:"+f.get(0));});
  for(String name:List.of("OnTick","OnTickEvenPaused","OnGameBoot","OnGameStart","OnPostMapLoad","OnServerCommand","OnClientCommand","OnPreFillWorldObjectContextMenu","OnKeyPressed","OnJoypadActivate","OnJoypadDeactivate","OnJoypadBeforeDeactivate","OnPlayerUpdate")){var e=new Event(name,events.size());e.register(platform,table);events.put(name,e);}
  env.rawset("nativeCount",(JavaFunction)(f,n)->f.push((double)events.get((String)f.get(0)).callbacks.size()));
  env.rawset("nativeEmit",(JavaFunction)(f,n)->{Object[]values=new Object[n-1];for(int i=1;i<n;i++)values[i-1]=f.get(i);events.get((String)f.get(0)).trigger(env,caller,values);return 0;});
  env.rawset("nativeReload",(JavaFunction)(f,n)->{try{load(modules.get(((Number)f.get(0)).intValue()-1));return 0;}catch(Exception e){throw new RuntimeException(e);}});
  env.rawset("nativeLocal",(JavaFunction)(f,n)->{try{int index=((Number)f.get(0)).intValue()-1;String file=modules.get(index),name=(String)f.get(1);String text=Files.readString(Path.of(file));var match=Pattern.compile("(?m)^\\s*local function "+Pattern.quote(name)+"\\(").matcher(text);if(!match.find())throw new AssertionError("local source absent:"+name);int from=(int)text.substring(0,match.start()).chars().filter(x->x=='\n').count()+1;var next=Pattern.compile("(?m)^\\s*(?:local function |function |\\w+\\.\\w+\\s*=\\s*function)").matcher(text);int to=Integer.MAX_VALUE;if(next.find(match.end()))to=(int)text.substring(0,next.start()).chars().filter(x->x=='\n').count()+1;var seen=Collections.newSetFromMap(new IdentityHashMap<Object,Boolean>());var c=find(env,seen,name,from,to);if(c==null){search:for(var e:events.values())for(var cb:e.callbacks){c=find(cb,seen,name,from,to);if(c!=null)break search;}}if(c==null)throw new AssertionError("no exact native closure:"+name);return f.push(c);}catch(Exception e){throw new RuntimeException(e);}});
  env.rawset("nativeTimestampMs",(JavaFunction)(f,n)->f.push((double)LuaManager.GlobalObject.getTimestampMs()));
  env.rawset("nativeTimeInMillis",(JavaFunction)(f,n)->f.push((double)LuaManager.GlobalObject.getTimeInMillis()));
  env.rawset("nativeTimestamp",(JavaFunction)(f,n)->f.push((double)LuaManager.GlobalObject.getTimestamp()));
  env.rawset("nativeServer",(JavaFunction)(f,n)->{GameServer.server=Boolean.TRUE.equals(f.get(0));return f.push(LuaManager.GlobalObject.isServer());});
  env.rawset("MODE",args[0]);env.rawset("CATALOGUES",platform.newTable());
  for(int i=1;i<args.length;i++){String file=args[i];if(file.startsWith("module=")){file=file.substring(7);String[] parts=file.split("=",2);String key=parts[0];file=parts[1];modules.add(file);Object result=load(file);env.rawset("Module"+modules.size(),result);((KahluaTable)env.rawget("CATALOGUES")).rawset(key,result==null?Boolean.TRUE:result);}else load(file);}
  if(!Boolean.TRUE.equals(env.rawget("PROVEN")))throw new AssertionError("D2_RESIDUAL:no-proof");System.out.println("PASS mode="+args[0]+" checks="+env.rawget("CHECKS"));
 }
}
