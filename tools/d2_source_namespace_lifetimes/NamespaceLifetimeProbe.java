import java.nio.file.*;import java.util.*;import java.util.regex.*;
import zombie.Lua.Event;import zombie.Lua.LuaManager;
import se.krka.kahlua.converter.KahluaConverterManager;import se.krka.kahlua.integration.LuaCaller;
import se.krka.kahlua.j2se.J2SEPlatform;import se.krka.kahlua.luaj.compiler.LuaCompiler;import se.krka.kahlua.vm.*;
/** Complete source modules; native Event and compiler, controlled scene/UI hosts. */
public final class NamespaceLifetimeProbe {
 static KahluaTable env;static KahluaThread thread;static List<String> modules=new ArrayList<>();
 static void load(String file)throws Exception{try(var input=Files.newBufferedReader(Path.of(file))){thread.call(LuaCompiler.loadis(input,file,env),null,null,null);}}
 static LuaClosure find(Object obj,Set<Object> seen,String file,int from,int to){
  if(obj==null||!seen.add(obj))return null;
  if(obj instanceof LuaClosure c){int min=Arrays.stream(c.prototype.lines).min().orElse(-1),max=Arrays.stream(c.prototype.lines).max().orElse(-1);
   if(min>=from&&max<to&&file.equals(c.prototype.name))return c;
   for(var u:c.upvalues){var found=find(u.getValue(),seen,file,from,to);if(found!=null)return found;}
  }else if(obj instanceof KahluaTable t){var it=t.iterator();while(it.advance()){var found=find(it.getValue(),seen,file,from,to);if(found!=null)return found;}}
  return null;
 }
 public static void main(String[]args)throws Exception{
  var platform=J2SEPlatform.getInstance();env=platform.newEnvironment();thread=new KahluaThread(platform,env);thread.debugOwnerThread=Thread.currentThread();LuaManager.env=env;LuaManager.thread=thread;
  var events=platform.newTable();env.rawset("Events",events);var nativeEvents=new HashMap<String,Event>();var caller=new LuaCaller(new KahluaConverterManager());
  for(String name:List.of("OnPlayerUpdate","OnFillInventoryObjectContextMenu","OnGameStart","OnKeyPressed","OnKeyStartPressed","OnKeyKeepPressed","OnPlayerDeath","OnWeaponHitCharacter","OnZombieDead","EveryHours","OnClientCommand")){var e=new Event(name,nativeEvents.size());e.register(platform,events);nativeEvents.put(name,e);}
  env.rawset("nativeEventCount",(JavaFunction)(f,n)->f.push((double)nativeEvents.get((String)f.get(0)).callbacks.size()));
  env.rawset("nativeEmitPlayer",(JavaFunction)(f,n)->{nativeEvents.get("OnPlayerUpdate").trigger(env,caller,new Object[]{f.get(0)});return 0;});
  env.rawset("nativeReload",(JavaFunction)(f,n)->{try{load(modules.get(((Number)f.get(0)).intValue()-1));return 0;}catch(Exception e){throw new RuntimeException(e);}});
  env.rawset("nativeLocal",(JavaFunction)(f,n)->{try{String file=modules.get(0),name=(String)f.get(0);String text=Files.readString(Path.of(file));var match=Pattern.compile("(?m)^\\s*local function "+Pattern.quote(name)+"\\(").matcher(text);if(!match.find())throw new AssertionError("local source absent:"+name);int from=(int)text.substring(0,match.start()).chars().filter(x->x=='\n').count()+1;var next=Pattern.compile("(?m)^\\s*(?:local function |function |\\w+\\.\\w+\\s*=\\s*function)").matcher(text);int to=Integer.MAX_VALUE;if(next.find(match.end()))to=(int)text.substring(0,next.start()).chars().filter(x->x=='\n').count()+1;var c=find(env,Collections.newSetFromMap(new IdentityHashMap<>()),name,from,to);if(c==null)throw new AssertionError("no exact native closure:"+name+" lines="+from+":"+to);return f.push(c);}catch(Exception e){throw new RuntimeException(e);}});
  env.rawset("MODE",args[0]);env.rawset("CATALOGUES",platform.newTable());
  for(int i=1;i<args.length;i++){String file=args[i];if(file.startsWith("module=")){file=file.substring(7);modules.add(file);}load(file);}
  if(!Boolean.TRUE.equals(env.rawget("PROVEN")))throw new AssertionError("D2_NAMESPACE:no-proof");System.out.println("PASS namespace mode="+args[0]+" checks="+env.rawget("CHECKS"));
 }
}
