import java.nio.ByteBuffer;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.regex.Pattern;
import se.krka.kahlua.converter.KahluaConverterManager;
import se.krka.kahlua.integration.LuaCaller;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.*;
import zombie.Lua.LuaManager;
import zombie.inventory.InventoryItem;
import zombie.iso.*;
import zombie.iso.objects.IsoWorldInventoryObject;
import zombie.scripting.ScriptManager;
import zombie.scripting.ScriptParser;
import zombie.scripting.objects.*;
import zombie.world.*;

/** Real installed item allocation/drop/list ownership; isolated synthetic loaded floor geometry. */
public final class LooseItemsProbe {
    private static InventoryItem item(String type) {
        var item=LuaManager.GlobalObject.instanceItem(type);
        if(item!=null) {
            // No GL renderer in this fixture. Native world-object construction
            // still requires a named icon even though no pixels are rendered.
            var icon=new zombie.core.textures.Texture();icon.setNameOnly("fixture-loose-item-icon.png");item.setTexture(icon);
        }
        return item;
    }
    private static final class Info extends ItemInfo {
        Info(Item item, short id) {
            name=item.getName(); moduleName="Base"; fullType="Base."+name;
            registryId=id; isLoaded=true; scriptItem=item; entityScript=item; modId="pz-vanilla";
        }
    }
    private static final class Dictionary extends DictionaryData {
        void register(Item item, short id) {
            var info=new Info(item,id);
            itemIdToInfoMap.put(id,info); itemTypeToInfoMap.put(info.getFullType(),info);
        }
    }
    private static void register(Path game, ScriptModule module, Dictionary dictionary, String file, String name, short id) throws Exception {
        String text=ScriptParser.stripComments(Files.readString(game.resolve("media/scripts/generated/items/"+file)));
        var match=Pattern.compile("\\bitem\\s+"+Pattern.quote(name)+"\\s*\\{").matcher(text);
        if(!match.find()) throw new AssertionError("Missing installed item "+name);
        int end=match.end(),depth=1;
        while(depth>0&&end<text.length()) {char c=text.charAt(end++); if(c=='{')depth++;else if(c=='}')depth--;}
        if(depth!=0) throw new AssertionError("Unclosed item "+name);
        var item=new Item(); item.setModule(module); item.setName(name); item.Load(name,text.substring(match.start(),end));
        item.setRegistry_id(id); module.items.getScriptMap().put(name,item); dictionary.register(item,id);
    }
    private static IsoGridSquare floor(IsoCell cell,int z) {
        var square=new IsoGridSquare(cell,null,128,128,z);
        square.chunk=new IsoChunk(cell);square.chunk.wx=16;square.chunk.wy=16;square.chunk.loaded=true;
        var floor=new IsoObject(cell,square,new zombie.iso.sprite.IsoSprite());
        floor.getProperties().set(zombie.iso.SpriteDetails.IsoFlagType.solidfloor);
        square.getObjects().add(floor);square.getProperties().set(zombie.iso.SpriteDetails.IsoFlagType.solidfloor);
        return square;
    }
    public static void main(String[] args) throws Exception {
        zombie.GameWindow.gameThread=Thread.currentThread();
        zombie.core.random.RandStandard.INSTANCE.init();
        zombie.ZomboidFileSystem.instance.setCacheDir(args[2]);
        zombie.ZomboidFileSystem.instance.init();
        zombie.GameTime.setInstance(new zombie.GameTime());
        var platform=new J2SEPlatform(); var env=platform.newEnvironment();
        var thread=new KahluaThread(platform,env);thread.debugOwnerThread=Thread.currentThread();
        LuaManager.platform=platform;LuaManager.env=env;LuaManager.thread=thread;
        zombie.ui.UIManager.defaultthread=thread;
        LuaManager.converterManager=new KahluaConverterManager();zombie.Lua.KahluaNumberConverter.install(LuaManager.converterManager);
        LuaManager.caller=new LuaCaller(LuaManager.converterManager);
        LuaManager.exposer=new LuaManager.Exposer(LuaManager.converterManager,platform,env);
        zombie.Lua.LuaEventManager.register(platform,env);
        var cell=new IsoCell(1,1);IsoWorld.instance.currentCell=cell;WorldReuserThread.instance.stop();
        var dict=new Dictionary();var data=WorldDictionary.class.getDeclaredField("data");data.setAccessible(true);data.set(null,dict);
        var module=new ScriptModule();module.name="Base";ScriptManager.instance.moduleMap.put("Base",module);
        register(Path.of(args[0]),module,dict,"normal.txt","Harmonica",(short)3101);
        register(Path.of(args[0]),module,dict,"literature.txt","Notebook",(short)3102);
        var directSquare=floor(cell,1);
        var directItem=item("Base.Harmonica");
        try { directSquare.AddWorldInventoryItem(directItem,.5f,.5f,0,false); }
        catch(Throwable error){error.printStackTrace();System.exit(1);}
        Class<?>[] types={IsoGridSquare.class,IsoObject.class,IsoWorldInventoryObject.class,
            InventoryItem.class,zombie.inventory.types.Literature.class,ItemTag.class,ArrayList.class,zombie.util.list.PZArrayList.class};
        for(var type:types)LuaManager.exposer.setExposed(type);
        for(var type:types)LuaManager.exposer.exposeLikeJava(type,env);
        env.rawset("__square",(JavaFunction)(f,n)->f.push(floor(cell,((Double)f.get(0)).intValue())));
        var meta=(KahluaTable)KahluaUtil.getClassMetatables(platform,env).rawget(IsoGridSquare.class);
        var methods=(KahluaTable)meta.rawget("__index");
        Object originalDrop=methods.rawget("AddWorldInventoryItem"),originalSupport=methods.rawget("TreatAsSolidFloor");
        env.rawset("__fault",(JavaFunction)(f,n)->{
            var square=(IsoGridSquare)f.get(0);int mode=((Double)f.get(1)).intValue();
            methods.rawset("AddWorldInventoryItem",originalDrop);methods.rawset("TreatAsSolidFloor",originalSupport);
            if(mode==1)square.getObjects().clear();
            if(mode==2)methods.rawset("TreatAsSolidFloor",(JavaFunction)(g,k)->g.push(false));
            if(mode==3)square.getProperties().set(zombie.iso.SpriteDetails.IsoFlagType.solid);
            if(mode==4)square.getProperties().set(zombie.iso.SpriteDetails.IsoFlagType.solidtrans);
            if(mode>=5)methods.rawset("AddWorldInventoryItem",(JavaFunction)(g,k)->{
                var sq=(IsoGridSquare)g.get(0);var item=(InventoryItem)g.get(1);
                var result=sq.AddWorldInventoryItem(item,((Double)g.get(2)).floatValue(),((Double)g.get(3)).floatValue(),((Double)g.get(4)).floatValue(),(Boolean)g.get(5));
                if(mode==5)throw new IllegalStateException("controlled-exception-after-real-native-drop");
                if(mode==6)return g.push(item("Base.Harmonica"));
                if(mode==7)item.setID(item.getID()+1);
                if(mode==8)item.getWorldItem().setSquare(floor(cell,1));
                return g.push(result);
            });
            return 0;
        });
        env.rawset("__item",(JavaFunction)(f,n)->f.push(item((String)f.get(0))));
        env.rawset("instanceof",(JavaFunction)(f,n)->{
            boolean yes=false;for(Class<?> c=f.get(0)==null?null:f.get(0).getClass();c!=null;c=c.getSuperclass())
                if(c.getSimpleName().equals(f.get(1)))yes=true;
            return f.push(yes);
        });
        env.rawset("__roundtrip",(JavaFunction)(f,n)->{
            try{var b=ByteBuffer.allocate(1024*1024);((KahluaTable)f.get(0)).save(b);b.flip();
                var value=platform.newTable();value.load(b,249);if(b.hasRemaining())throw new AssertionError("Unconsumed state");return f.push(value);
            }catch(Exception e){throw new IllegalStateException(e);}
        });
        env.rawset("print",(JavaFunction)(f,n)->{System.out.println(f.get(0));return 0;});
        try{
            Object[] result=thread.pcall(LuaCompiler.loadstring(Files.readString(Path.of(args[1])),args[1],env),new Object[0]);
            if(!Boolean.TRUE.equals(result[0])) {for(Object value:result)System.err.println(value);System.exit(1);}
        }
        catch(Throwable e){e.printStackTrace();System.exit(1);}
        System.out.println("NATIVE_LOOSE_ITEMS_PASS");
    }
}
