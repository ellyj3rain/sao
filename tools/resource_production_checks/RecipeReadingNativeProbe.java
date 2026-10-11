import com.sao.engine.SAOIsoPlayerShell;
import java.io.Reader;
import java.lang.reflect.*;
import java.nio.ByteBuffer;
import java.nio.file.*;
import java.util.*;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.*;
import zombie.inventory.InventoryItem;
import zombie.inventory.types.Literature;
import zombie.iso.*;
import zombie.scripting.ScriptManager;

/** Installed literature definitions, actual ReadLiterature and known recipes;
 * controlled Lua actor/animation/dispatch ports qualify the Study owner. */
public final class RecipeReadingNativeProbe {
    METADATA
    private static SAOIsoPlayerShell body;
    private static final Map<String,InventoryItem> prototypes=new LinkedHashMap<>();
    private static final Map<Integer,Literature> items=new LinkedHashMap<>();
    private static int nextItem=91000, creations, reads;
    private static Object invoke(String name,Class<?>[] signature,Object... args)throws Exception{
        Method method=MovementCrossingProbe.class.getDeclaredMethod(name,signature);
        method.setAccessible(true);return method.invoke(null,args);
    }
    private static void initialise(Path game)throws Exception{
        IsoCell cell=(IsoCell)invoke("boot",new Class<?>[0]);
        body=(SAOIsoPlayerShell)invoke("person",new Class<?>[]{IsoCell.class},cell);
        var dictionary=new MaterialDictionary();
        Field field=zombie.world.WorldDictionary.class.getDeclaredField("data");field.setAccessible(true);field.set(null,dictionary);
        short registry=1700;
        for(String name:List.of("MetalworkMag3","MetalworkMag1","ElectronicsMag4")){
            InventoryItem item=material(game.resolve("media/scripts/generated/items/literature.txt"),"Base",name,registry++,dictionary);
            prototypes.put(item.getFullType(),item);
        }
        var module=ScriptManager.instance.moduleMap.get("Base");
        for(Field bucket:ScriptManager.class.getDeclaredFields())if(zombie.scripting.ScriptBucketCollection.class.isAssignableFrom(bucket.getType())){
            bucket.setAccessible(true);((zombie.scripting.ScriptBucketCollection<?>)bucket.get(ScriptManager.instance)).registerModule(module);
        }
    }
    private static int integer(Object value){return ((Number)value).intValue();}
    private static Object nativeCall(LuaCallFrame f)throws Exception{
        String op=(String)f.get(0),key=f.get(1) instanceof String?(String)f.get(1):null;
        switch(op){
            case "reset":body.getInventory().getItems().clear();body.getKnownRecipes().clear();body.getAlreadyReadBook().clear();reads=0;return true;
            case "creations":return(double)creations;
            case "reads":return(double)reads;
            case "new-item":{
                InventoryItem value=prototypes.get(key).getScriptItem().InstanceItem(null,false);
                if(!(value instanceof Literature))throw new AssertionError("Native literature absent "+key);
                value.setID(nextItem++);items.put(value.getID(),(Literature)value);body.getInventory().AddItem(value);creations++;
                return(double)value.getID();
            }
            case "script":{
                var definition=ScriptManager.instance.getItem(key);if(definition==null)return null;
                return switch((String)f.get(2)){
                    case "pages"->(double)definition.getNumberOfPages();case "skill"->definition.getSkillTrained();
                    case "literature"->definition.isItemType(zombie.scripting.objects.ItemType.LITERATURE);
                    case "recipe"->definition.getLearnedRecipes()!=null&&definition.getLearnedRecipes().contains((String)f.get(3));
                    default->throw new IllegalArgumentException((String)f.get(2));};
            }
            case "item":{
                Literature item=items.get(integer(f.get(1)));
                return switch((String)f.get(2)){
                    case "pages"->(double)item.getNumberOfPages();case "type"->item.getFullType();
                    case "recipe"->item.getLearnedRecipes()!=null&&item.getLearnedRecipes().contains((String)f.get(3));
                    default->throw new IllegalArgumentException((String)f.get(2));};
            }
            case "known":return body.isRecipeActuallyKnown(key);
            case "read":body.ReadLiterature(items.get(integer(f.get(1))));reads++;return true;
            default:throw new IllegalArgumentException(op);
        }
    }
    public static void main(String[] args)throws Exception{
        Thread.setDefaultUncaughtExceptionHandler((t,e)->{e.printStackTrace();System.exit(1);});
        initialise(Path.of(args[0]));
        var platform=new J2SEPlatform();var env=platform.newEnvironment();var thread=new KahluaThread(platform,env);
        thread.debugOwnerThread=Thread.currentThread();zombie.Lua.LuaManager.platform=platform;
        zombie.Lua.LuaManager.env=env;zombie.Lua.LuaManager.thread=thread;
        env.rawset("print",(JavaFunction)(f,n)->{for(int i=0;i<n;i++)System.out.print((i==0?"":"\t")+f.get(i));System.out.println();return 0;});
        env.rawset("__recipeNative",(JavaFunction)(f,n)->{try{return f.push(nativeCall(f));}catch(Exception e){throw new IllegalStateException(e);}});
        env.rawset("__nativeRoundtrip",(JavaFunction)(f,n)->{try{
            var bytes=ByteBuffer.allocate(1048576);((KahluaTable)f.get(0)).save(bytes);bytes.flip();
            var restored=platform.newTable();restored.load(bytes,IsoWorld.WorldVersion);return f.push(restored);
        }catch(Exception e){throw new IllegalStateException(e);}});
        final Map<String,Path> reload=new HashMap<>();for(int i=1;i<args.length;i++){Path path=Path.of(args[i]);reload.put(path.getFileName().toString(),path);}
        env.rawset("__reloadReadingOwner",(JavaFunction)(f,n)->{try{
            Path path=reload.get("study.lua");thread.call(LuaCompiler.loadstring(Files.readString(path),path.toString(),env),null,null,null);return f.push(true);
        }catch(Exception e){throw new IllegalStateException(e);}});
        for(int i=1;i<args.length;i++)try(Reader reader=Files.newBufferedReader(Path.of(args[i]))){
            Object[] result=thread.pcall(LuaCompiler.loadis(reader,args[i],env),new Object[0]);
            if(!Boolean.TRUE.equals(result[0])){System.out.println("ERROR chunk="+args[i]);for(int j=1;j<result.length;j++)System.out.println(result[j]);System.exit(1);}
        }
        System.exit(0);
    }
}
