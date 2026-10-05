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
import zombie.inventory.InventoryItemFactory;
import zombie.inventory.types.Literature;
import zombie.scripting.ScriptManager;
import zombie.scripting.ScriptParser;
import zombie.scripting.objects.*;
import zombie.world.*;

/** Installed literal items, native reading effects and Kahlua persistence;
 * action clock and canonical ownership are controlled by the Lua fixture. */
public final class D2ReadingProbe {
    static final class Info extends ItemInfo {
        Info(Item item, short id) {
            name=item.getName();moduleName="Base";fullType="Base."+name;
            registryId=id;isLoaded=true;scriptItem=item;entityScript=item;modId="pz-vanilla";
        }
    }
    static final class Dictionary extends DictionaryData {
        void register(Item item,short id) {
            var info=new Info(item,id);itemIdToInfoMap.put(id,info);itemTypeToInfoMap.put(info.getFullType(),info);
        }
    }
    static InventoryItem item(Path game,ScriptModule module,Dictionary dictionary,String name,short id) throws Exception {
        String text=ScriptParser.stripComments(Files.readString(game.resolve("media/scripts/generated/items/literature.txt")));
        var match=Pattern.compile("\\bitem\\s+"+Pattern.quote(name)+"\\s*\\{").matcher(text);
        if(!match.find())throw new AssertionError("Installed item missing: "+name);
        int end=match.end(),depth=1;
        while(depth>0&&end<text.length()){char c=text.charAt(end++);if(c=='{')depth++;else if(c=='}')depth--;}
        var definition=new Item();definition.setModule(module);definition.setName(name);
        definition.Load(name,text.substring(match.start(),end));definition.setRegistry_id(id);
        module.items.getScriptMap().put(name,definition);dictionary.register(definition,id);
        InventoryItem result=InventoryItemFactory.CreateItem("Base."+name);
        if(!(result instanceof Literature))throw new AssertionError("Native literature missing: "+name);
        result.setID(id);result.setName(name);return result;
    }
    public static void main(String[] args) throws Exception {
        var boot=MovementCrossingProbe.class.getDeclaredMethod("boot");boot.setAccessible(true);
        var cell=(zombie.iso.IsoCell)boot.invoke(null);
        var make=MovementCrossingProbe.class.getDeclaredMethod("person",zombie.iso.IsoCell.class);make.setAccessible(true);
        var body=(com.sao.engine.SAOIsoPlayerShell)make.invoke(null,cell);
        var platform=new J2SEPlatform();var env=platform.newEnvironment();
        var thread=new KahluaThread(platform,env);thread.debugOwnerThread=Thread.currentThread();
        LuaManager.platform=platform;LuaManager.env=env;LuaManager.thread=thread;
        LuaManager.converterManager=new KahluaConverterManager();zombie.Lua.KahluaNumberConverter.install(LuaManager.converterManager);
        LuaManager.caller=new LuaCaller(LuaManager.converterManager);zombie.ui.UIManager.defaultthread=thread;
        var exposer=new LuaManager.Exposer(LuaManager.converterManager,platform,env);
        Class<?>[] types={InventoryItem.class,Literature.class,ItemTag.class,ArrayList.class,
            zombie.inventory.ItemContainer.class,zombie.characters.IsoGameCharacter.class,
            zombie.characters.IsoPlayer.class,com.sao.engine.SAOIsoPlayerShell.class,
            zombie.characters.Stats.class,zombie.characters.CharacterStat.class};
        for(var type:types)exposer.setExposed(type);
        for(var type:types)exposer.exposeLikeJava(type,env);
        zombie.Lua.LuaEventManager.register(platform,env);
        var dictionary=new Dictionary();var data=WorldDictionary.class.getDeclaredField("data");data.setAccessible(true);data.set(null,dictionary);
        var module=new ScriptModule();module.name="Base";ScriptManager.instance.moduleMap.put("Base",module);
        var nativeItems=platform.newTable();short index=1800;
        for(String name:new String[]{"IDcard_Male","IDcard_Female","Book","ComicBook"}) {
            var value=item(Path.of(args[0]),module,dictionary,name,index++);
            body.getInventory().AddItem(value);nativeItems.rawset(name,value);
        }
        env.rawset("__nativeItems",nativeItems);env.rawset("__nativeBody",body);
        env.rawset("__nativeItemTag",env.rawget("ItemTag"));
        env.rawset("__nativeCharacterStat",env.rawget("CharacterStat"));
        env.rawset("__nativePrint",(JavaFunction)(frame,count)->{System.out.println(frame.get(0));return 0;});
        env.rawset("__nativeIsLiterature",(JavaFunction)(frame,count)->frame.push(frame.get(0) instanceof Literature));
        env.rawset("__nativeRoundtrip",(JavaFunction)(frame,count)->{
            try {var bytes=ByteBuffer.allocate(4*1024*1024);((KahluaTable)frame.get(0)).save(bytes);bytes.flip();
                var restored=platform.newTable();restored.load(bytes,249);return frame.push(restored);
            }catch(Exception error){throw new IllegalStateException(error);}
        });
        Path planner=null;
        for(String arg:args)if(arg.endsWith("plan.lua"))planner=Path.of(arg);
        final String planningSource=Files.readString(planner);
        env.rawset("__freshVMChoice",(JavaFunction)(frame,count)->{
            try {
                var bytes=ByteBuffer.allocate(4*1024*1024);((KahluaTable)frame.get(0)).save(bytes);bytes.flip();
                var freshPlatform=new J2SEPlatform();var fresh=freshPlatform.newEnvironment();
                var restored=freshPlatform.newTable();restored.load(bytes,249);
                fresh.rawset("__person",restored);fresh.rawset("__activity",frame.get(1));
                fresh.rawset("__itemKey",frame.get(2));fresh.rawset("__hours",frame.get(3));
                var vm=new KahluaThread(freshPlatform,fresh);vm.debugOwnerThread=Thread.currentThread();
                vm.call(LuaCompiler.loadstring("SAO={Identity={get=function(id) if id==__person.id then return __person end end},History={countyHours=function() return __hours end}}", "fresh-owner",fresh),null,null,null);
                vm.call(LuaCompiler.loadstring(planningSource,"fresh-planner",fresh),null,null,null);
                String query="local ok,why=SAO.ProceduralPlanning.leisureChoice(__person.id,__activity,__itemKey);return {eligible=ok,reason=why,person=__person}";
                if("__instrument__".equals(frame.get(1)))query="SAO.Gesture={instrumentWork=function() return nil end,instrumentOutcome=function() return nil end,nextInstrumentSequence=function() return (__person.instrumentSequence or 0)+1 end}; local P=SAO.ProceduralPlanning;P.reconcileInstrument(__person.id,'fresh-runtime-adoption');local p=P.planLeisure(__person.id,__itemKey);return {purpose=p,person=__person}";
                Object result=vm.call(LuaCompiler.loadstring(query,"fresh-choice",fresh),null,null,null);
                return frame.push(result);
            }catch(Exception error){throw new IllegalStateException(error);}
        });
        try {
            int i=1;
            for(;i<args.length&&!args[i].equals("--");i++)
                thread.call(LuaCompiler.loadstring(Files.readString(Path.of(args[i])),args[i],env),null,null,null);
            System.out.println("VALUE "+thread.call(LuaCompiler.loadstring("return "+args[i+1],"verdict",env),null,null,null));
        }catch(Throwable error){error.printStackTrace();System.exit(1);}
    }
}
