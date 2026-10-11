import java.io.Reader;
import java.lang.reflect.*;
import java.nio.ByteBuffer;
import java.nio.file.*;
import java.util.*;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.*;
import zombie.characters.PlayerCraftHistory;
import zombie.entity.ComponentType;
import zombie.entity.components.build.BuildLogic;
import zombie.inventory.*;
import zombie.iso.*;
import zombie.iso.objects.IsoThumpable;
import zombie.scripting.*;
import zombie.scripting.entity.*;
import zombie.scripting.objects.*;

/** Installed metal construction over the existing native shelter/entry/recovery specimen. */
public final class MetalShelterNativeProbe {
    private static Path game;private static ScriptModule module;private static int skill=8;private static boolean learned=true;
    private static com.sao.engine.SAOIsoPlayerShell body;
    private static IsoThumpable prior;private static int removedIndex=-1;private static int reads;
    private static zombie.inventory.types.Literature magazine;
    private static final Map<Integer,zombie.inventory.types.Literature> readingItems=new HashMap<>();private static int nextBook=901;
    private static ItemContainer materialSource;private static InventoryItem poolBar;
    private static final String[][] FAMILIES={{"MetalWallFrame","entity_metal_wallframe"},{"MetalWallLvl1","entity_metal_walllvl1"},{"MetalWallLvl2","entity_metal_walllvl2"},{"MetalDoorFrameLvl1","entity_metal_doorframelvl1"},{"MetalDoorFrameLvl2","entity_metal_doorframelvl2"},{"MetalDoorLvl1","entity_metal_doorlvl1"},{"MetalDoorLvl2","entity_metal_doorlvl2"}};
    public static class Receiver extends ShelterConstructionNativeProbe.Receiver {
        @Override public int getPerkLevel(zombie.characters.skills.PerkFactory.Perk perk){return skill;}
        @Override public boolean isRecipeKnown(zombie.scripting.entity.components.crafting.CraftRecipe recipe,boolean ignore){return !recipe.needToBeLearn()||learned||body!=null&&(ignore?body.isRecipeActuallyKnown(recipe):body.isRecipeKnown(recipe,false));}
    }
    private static Field field(String name)throws Exception{var f=ShelterConstructionNativeProbe.class.getDeclaredField(name);f.setAccessible(true);return f;}
    private static Object get(String name)throws Exception{return field(name).get(null);}
    private static void set(String name,Object value)throws Exception{field(name).set(null,value);}
    private static Object call(String name,Class<?>[] types,Object...values)throws Exception{var m=ShelterConstructionNativeProbe.class.getDeclaredMethod(name,types);m.setAccessible(true);return m.invoke(null,values);}
    private static String block(Path file,String type,String name)throws Exception{return (String)call("block",new Class<?>[]{Path.class,String.class,String.class},file,type,name);}
    private static zombie.scripting.entity.components.crafting.CraftRecipe recipe(String id)throws Exception{return (zombie.scripting.entity.components.crafting.CraftRecipe)call("recipe",new Class<?>[]{String.class},id);}
    private static void initialise()throws Exception{
        ShelterConstructionNativeProbe.initialise(game);module=(ScriptModule)get("module");boolean old=zombie.network.GameServer.server;zombie.network.GameServer.server=true;
        for(String name:List.of("MetalBar","SmallSheetMetal","BlowTorch","WeldingRods","MetalworkMag1","MetalworkMag3")){
            String domain=name.startsWith("MetalworkMag")?"literature":List.of("BlowTorch","WeldingRods").contains(name)?"drainable":name.equals("MetalBar")?"weapon":"normal";
            String definition=block(game.resolve("media/scripts/generated/items/"+domain+".txt"),"item",name).replaceAll("(?im)^\\s*Researchablerecipes\\s*=.*$","");
            var item=new Item();item.setModule(module);item.setModID("pz-vanilla");item.InitLoadPP(name);item.Load(name,definition);item.setDisplayName(name);module.items.getScriptMap().put(name,item);
        }
        var timed=new TimedActionScript();timed.setModule(module);timed.InitLoadPP("BuildWallMetal");timed.Load("BuildWallMetal",block(game.resolve("media/scripts/generated/timedactions.txt"),"timedAction","BuildWallMetal"));module.timedActionScripts.getScriptMap().put("BuildWallMetal",timed);
        var entities=(Map<String,GameEntityScript>)get("entities");var added=new ArrayList<GameEntityScript>();
        for(var entry:FAMILIES){var script=new GameEntityScript();script.setModule(module);script.setModID("pz-vanilla");script.InitLoadPP(entry[0]);script.Load(entry[0],block(game.resolve("media/scripts/generated/entities/walls/"+entry[1]+".txt"),"entity",entry[0]).replaceAll("(?s)component UiConfig\\s*\\{.*?\\}",""));module.entities.getScriptMap().put(entry[0],script);entities.put("Base."+entry[0],script);added.add(script);}
        call("indexBuckets",new Class<?>[]{});for(var entity:added)entity.OnScriptsLoaded(ScriptLoadMode.Init);call("indexBuckets",new Class<?>[]{});ItemTags.Init(ScriptManager.instance.getAllItems());for(var entity:added)entity.OnPostWorldDictionaryInit();
        for(var entity:added){var sprites=(zombie.scripting.entity.components.spriteconfig.SpriteConfigScript)entity.getComponentScriptFor(ComponentType.SpriteConfig);for(String name:sprites.getAllTileNames())zombie.iso.sprite.IsoSpriteManager.instance.AddSprite(name).name=name;}
        zombie.entity.components.spriteconfig.SpriteConfigManager.InitScriptsPostTileDef();call("nativeTiles",new Class<?>[]{Path.class},game);zombie.network.GameServer.server=old;
        var engine=zombie.entity.GameEntityManager.class.getDeclaredField("engine");engine.setAccessible(true);engine.set(null,new zombie.entity.Engine());
    }
    private static String[] materialTypes(String id){return id.contains("DoorLvl")?new String[]{"BlowTorch","SmallSheetMetal","WeldingRods","Hinge","Doorknob"}:id.contains("WallLvl")?new String[]{"BlowTorch","SmallSheetMetal","WeldingRods"}:new String[]{"BlowTorch","MetalBar","WeldingRods"};}
    private static void reset(String id)throws Exception{
        if(!id.startsWith("Base.Metal")){call("reset",new Class<?>[]{String.class},id);return;}
        if(id.contains("WallLvl")&&get("created") instanceof IsoThumpable old&&old.getObjectIndex()>=0){prior=old;removedIndex=-1;}
        set("selectedEntity",id);set("selected",recipe(id));set("created",null);((List<?>)get("createdParts")).clear();var items=(Map<Integer,InventoryItem>)get("items");items.clear();
        var actor=(Receiver)ShelterConstructionNativeProbe.unsafe().allocateInstance(Receiver.class);actor.inventory=new ItemContainer();actor.inventory.setType("inventory");actor.history=new PlayerCraftHistory(actor);actor.xp=new ShelterConstructionNativeProbe.XpReceiver(actor);set("actor",actor);
        boolean old=zombie.network.GameServer.server;zombie.network.GameServer.server=true;int next=100;var recipe=recipe(id);var types=materialTypes(id);
        for(int slot=0;slot<recipe.getInputs().size();slot++){boolean uses=slot==0||slot==2;int count=uses?1:recipe.getInputs().get(slot).getIntAmount();for(int n=0;n<count;n++){var item=module.getItem(types[slot]).InstanceItem(null);item.setID(next++);if(uses)item.setCurrentUses(((zombie.inventory.types.DrainableComboItem)item).getMaxUses());actor.inventory.AddItem(item);items.put(item.getID(),item);}}
        zombie.network.GameServer.server=old;var logic=new BuildLogic(actor,null,null);var containers=new ArrayList<ItemContainer>();containers.add(actor.inventory);logic.setContainers(containers);logic.setRecipe(recipe);logic.setManualSelectInputs(true);set("logic",logic);
    }
    private static Object op(String name,Object a,Object b)throws Exception{
        switch(name){
            case "reset":reset((String)a);return true;
            case "skill":skill=((Number)a).intValue();return true;
            case "skillValue":return skill;
            case "actualKnown":return learned||body!=null&&body.isRecipeActuallyKnown((String)a);
            case "knownFlags":return "visible="+body.isRecipeKnown(recipe((String)a),false)+",actor="+((Receiver)get("actor")).isRecipeKnown(recipe((String)a),false)+",sandbox="+zombie.SandboxOptions.instance.seeNotLearntRecipe.getValue()+",actual="+body.isRecipeActuallyKnown(recipe((String)a));
            case "known":learned=Boolean.TRUE.equals(a);return true;
            case "uses":return ((Map<Integer,InventoryItem>)get("items")).get(((Number)a).intValue()).getCurrentUses();
            case "withdraw":{materialSource=new ItemContainer();var item=((Map<Integer,InventoryItem>)get("items")).get(((Number)a).intValue());((ShelterConstructionNativeProbe.Receiver)get("actor")).inventory.Remove(item);materialSource.AddItem(item);return materialSource.contains(item);}
            case "reclaim":{var item=((Map<Integer,InventoryItem>)get("items")).get(((Number)a).intValue());if(materialSource==null||!materialSource.contains(item))return false;materialSource.Remove(item);return ((ShelterConstructionNativeProbe.Receiver)get("actor")).inventory.AddItem(item)==item;}
            case "withdrawManual":materialSource=new ItemContainer();body.getInventory().Remove(magazine);materialSource.AddItem(magazine);return materialSource.contains(magazine);
            case "reclaimManual":if(materialSource==null||!materialSource.contains(magazine))return false;materialSource.Remove(magazine);body.getInventory().AddItem(magazine);return body.getInventory().contains(magazine);
            case "manualHeld":return body.getInventory().contains(magazine);
            case "sourceCategories":{var type=Class.forName("com.sao.engine.SAOWorldSources$ItemRow");var method=type.getDeclaredMethod("of",InventoryItem.class);method.setAccessible(true);var item=a instanceof Number?((Map<Integer,InventoryItem>)get("items")).get(((Number)a).intValue()):magazine;var row=method.invoke(null,item);var categories=type.getDeclaredField("categories");categories.setAccessible(true);return String.join(",",(ArrayList<String>)categories.get(row));}
            case "manualCategory":return com.sao.engine.SAONeeds.wantsMaterial(magazine,(String)a);
            case "poolInputMatch":return zombie.entity.components.crafting.recipe.CraftRecipeManager.getValidInputScriptForItem(recipe("Base.MetalWallFrame"),poolBar,(ShelterConstructionNativeProbe.Receiver)get("actor"))==recipe("Base.MetalWallFrame").getInputs().get(1);
            case "manualPool":{var source=new ItemContainer();var type=Class.forName("com.sao.engine.SAOWorldSources$ItemRow");var of=type.getDeclaredMethod("of",InventoryItem.class);of.setAccessible(true);var fields=com.sao.engine.SAOWorldSources.class.getDeclaredMethod("itemFields",type);fields.setAccessible(true);var snapshot=new StringBuilder("H|protocol=SAOWS1|status=OBSERVED|mode=loaded|cx=1|cy=2|sources=1\nS|id=C:metal-manuals:0|fp=exact-manual-container|rev=manual-stock|kind=container|x=12|y=23|z=0|building=-1|explored=1|state=available|access=unknown|container=counter|q:weapons=129|q:shelter-manual=1|q:gate-manual=128");for(int n=0;n<129;n++){var item=module.getItem(n==128?"MetalworkMag1":"MetalworkMag3").InstanceItem(null,false);item.setID(2000+n);source.AddItem(item);snapshot.append("\nI|source=C:metal-manuals:0").append(fields.invoke(null,of.invoke(null,item)));}for(int n=0;n<129;n++){var item=module.getItem(n==128?"MetalBar":"Hammer").InstanceItem(null,false);item.setID(2200+n);source.AddItem(item);if(n==128)poolBar=item;snapshot.append("\nI|source=C:metal-manuals:0").append(fields.invoke(null,of.invoke(null,item)));}snapshot.append("\nE");return snapshot.toString();}
            case "setUses":((Map<Integer,InventoryItem>)get("items")).get(((Number)a).intValue()).setCurrentUses(((Number)b).intValue());return true;
            case "split":{var items=(Map<Integer,InventoryItem>)get("items");var actor=(ShelterConstructionNativeProbe.Receiver)get("actor");var copy=new ArrayList<>(items.values());int next=100+items.size();for(var item:copy)if(item instanceof zombie.inventory.types.DrainableComboItem){int amount=item.getFullType().equals("Base.BlowTorch")?recipe((String)get("selectedEntity")).getInputs().get(0).getIntAmount():recipe((String)get("selectedEntity")).getInputs().get(2).getIntAmount();item.setCurrentUses(1);for(int n=1;n<amount;n++){var extra=item.getScriptItem().InstanceItem(null,false);extra.setID(next++);extra.setCurrentUses(1);actor.inventory.AddItem(extra);items.put(extra.getID(),extra);}}return true;}
            case "replaceSeed":{if(prior!=null)prior.getSquare().transmitRemoveItemFromSquare(prior);return op("seed",a,b);}
            case "priorNorth":{var direction=IsoThumpable.class.getDeclaredField("north");direction.setAccessible(true);direction.setBoolean(prior,Boolean.TRUE.equals(a));return true;}
            case "nativeLock":{var door=(IsoThumpable)get("sceneDoor");door.setKeyId(81031);door.setIsLocked(Boolean.TRUE.equals(a));door.setLockedByKey(Boolean.TRUE.equals(a));return true;}
            case "nativeBarricade":{var door=(IsoThumpable)get("sceneDoor");var bar=zombie.iso.objects.IsoBarricade.AddBarricadeToObject(door,false);if(bar==null)return false;bar.addPlank(body);return door.isBarricaded();}
            case "nativeObstruct":{var door=(IsoThumpable)get("sceneDoor");var sq=door.getSquare();var obstacle=new IsoObject(sq.getCell());obstacle.setSquare(sq);var sprite=new zombie.iso.sprite.IsoSprite();sprite.getProperties().set(zombie.iso.SpriteDetails.IsoFlagType.solid);sprite.getProperties().set(zombie.iso.SpriteDetails.IsoFlagType.solidtrans);obstacle.setSprite(sprite);sq.getObjects().add(obstacle);sq.RecalcAllWithNeighbours(true);return door.isObstructed();}
            case "recordInput":return recipe((String)a).getInputs().get(((Number)b).intValue()).isRecordInput();
            case "previousList":{var info=call("info",new Class<?>[]{String.class},a);var script=info.getClass().getMethod("getScript").invoke(info);var names=(List<String>)script.getClass().getMethod("getPreviousStages").invoke(script);var table=zombie.Lua.LuaManager.platform.newTable();for(int n=0;n<names.size();n++)table.rawset((double)n+1,names.get(n));return table;}
            case "scene":{var update=zombie.MapCollisionData.class.getDeclaredField("squareUpdateBuffer");update.setAccessible(true);if(zombie.MapCollisionData.instance!=null)((ByteBuffer)update.get(zombie.MapCollisionData.instance)).clear();call("sceneSetup",new Class<?>[]{String.class,String.class},(String)b,(String)a);body=(com.sao.engine.SAOIsoPlayerShell)get("sceneBody");prior=null;removedIndex=-1;reads=0;nextBook=901;readingItems.clear();return true;}
            case "seed":{String original=(String)get("selectedEntity");set("selectedEntity",a);String face=(String)get("sceneFace");String sprite=(String)call("spriteInfo",new Class<?>[]{String.class,int.class},face,0);var object=(IsoThumpable)call("sceneCreate",new Class<?>[]{String.class},sprite);var square=object.getSquare();call("nativeConstructionFlags",new Class<?>[]{IsoThumpable.class},object);prior=object;set("selectedEntity",original);((List<?>)get("createdParts")).clear();call("sceneRegions",new Class<?>[]{});return true;}
            case "removePrior":{if(prior==null||!prior.getEntityScript().getFullName().equals(a)||prior.getObjectIndex()<0)return -1;removedIndex=prior.getObjectIndex();return prior.getSquare().transmitRemoveItemFromSquare(prior);}
            case "stageReplaced":{var created=(IsoThumpable)get("created");return prior!=null&&removedIndex>=0&&!prior.getSquare().getObjects().contains(prior)&&created.getObjectIndex()==removedIndex;}
            case "createdMeasured":return com.sao.engine.SAOShelterConstruction.created(body,(IsoThumpable)get("created"),removedIndex>=0?prior:null,(String)get("selectedEntity"),10,20,0,(String)get("sceneFace"));
            case "createdNorth":return ((IsoThumpable)get("created")).getNorth();
            case "captureDoor":{String[] keys=((String)a).split("\\|");set("sceneCaptureKey",keys[0]);set("sceneCaptureRevision",keys[1]);return com.sao.engine.SAOShelterConstruction.beginPassage(body,(IsoThumpable)get("sceneDoor"),keys[0],keys[1],Boolean.TRUE.equals(b));}
            case "doorPass":{var door=(IsoThumpable)get("sceneDoor");boolean inside=Boolean.TRUE.equals(a);var sq=door.getSquare();int x=sq.getX()-(inside||door.getNorth()?0:1),y=sq.getY()-(inside||!door.getNorth()?0:1);var from=body.getCurrentSquare();boolean arrived=(Boolean)call("sceneMove",new Class<?>[]{double.class,double.class,double.class},x+.5,y+.5,0.0);if(arrived&&from!=body.getCurrentSquare()&&from.getX()==sq.getX()-(inside&&!door.getNorth()?1:0)&&from.getY()==sq.getY()-(inside&&door.getNorth()?1:0))set("passageCount",((Integer)get("passageCount"))+1);return arrived;}
            case "wallScene":{String original=(String)get("selectedEntity");String oldFace=(String)get("face");set("face","N");call("removeNorthWall",new Class<?>[]{int.class,int.class},11,20);set("sceneBuildX",11);for(String entity:List.of("Base.WoodDoorFrameLvl1","Base.WoodenDoorLvl1")){set("selectedEntity",entity);String sprite=(String)call("spriteInfo",new Class<?>[]{String.class,int.class},"N",0);var object=call("sceneCreate",new Class<?>[]{String.class},sprite);call("nativeConstructionFlags",new Class<?>[]{IsoThumpable.class},object);}body.getAnimationPlayer().setAngle(-(float)Math.PI*3/4);body.setForwardDirection(-.707f,-.707f);set("sceneBuildX",10);set("face",oldFace);set("selectedEntity",original);((List<?>)get("createdParts")).clear();call("sceneRegions",new Class<?>[]{});return true;}
            case "creationFlags":{var builder=(KahluaTable)a;var created=(IsoThumpable)get("created");created.setCanPassThrough(Boolean.TRUE.equals(builder.rawget("canPassThrough")));created.setBlockAllTheSquare(Boolean.TRUE.equals(builder.rawget("blockAllTheSquare")));created.setIsThumpable(Boolean.TRUE.equals(builder.rawget("isThumpable")));return true;}
            case "addCreated":{var created=(IsoThumpable)get("created");created.getSquare().AddSpecialObject(created,((Number)a).intValue());created.getSquare().RecalcAllWithNeighbours(true);call("sceneRegions",new Class<?>[]{});return true;}
            default:return call("op",new Class<?>[]{String.class,Object.class,Object.class},name,a,b);
        }
    }
    private static Object recipeCall(LuaCallFrame f)throws Exception{
        String op=(String)f.get(0);String key=f.get(1) instanceof String?(String)f.get(1):null;
        switch(op){
            case "new-item":magazine=(zombie.inventory.types.Literature)module.getItem(key==null?"MetalworkMag1":key.substring(5)).InstanceItem(null,false);magazine.setID(nextBook++);readingItems.put(magazine.getID(),magazine);body.getInventory().AddItem(magazine);return (double)magazine.getID();
            case "script":{var script=ScriptManager.instance.getItem(key);if(script==null)return null;return switch((String)f.get(2)){
                case "pages"->(double)script.getNumberOfPages();case "skill"->script.getSkillTrained();case "literature"->script.isItemType(zombie.scripting.objects.ItemType.LITERATURE);
                case "recipe"->script.getLearnedRecipes()!=null&&script.getLearnedRecipes().contains((String)f.get(3));default->throw new IllegalArgumentException();};}
            case "item":{var item=readingItems.get(((Number)f.get(1)).intValue());return switch((String)f.get(2)){case "pages"->(double)item.getNumberOfPages();case "type"->item.getFullType();case "recipe"->item.getLearnedRecipes().contains((String)f.get(3));default->throw new IllegalArgumentException();};}
            case "known":return learned||body.isRecipeActuallyKnown(key);
            case "read":body.ReadLiterature(readingItems.get(((Number)f.get(1)).intValue()));reads++;return true;
            case "reads":return (double)reads;
            default:throw new IllegalArgumentException(op);
        }
    }
    public static void main(String[] args)throws Exception{
        game=Path.of(args[0]);var platform=new J2SEPlatform();var env=platform.newEnvironment();var thread=new KahluaThread(platform,env);thread.debugOwnerThread=Thread.currentThread();zombie.Lua.LuaManager.env=env;zombie.Lua.LuaManager.thread=thread;zombie.Lua.LuaManager.caller=new se.krka.kahlua.integration.LuaCaller(new se.krka.kahlua.converter.KahluaConverterManager());
        env.rawset("print",(JavaFunction)(f,n)->{for(int i=0;i<n;i++)System.out.print((i==0?"":"\t")+f.get(i));System.out.println();return 0;});thread.call(LuaCompiler.loadstring("ISTimedActionQueue={queues={},getTimedActionQueue=function()return {queue={}}end}","empty",env),null,null,null);initialise();
        zombie.ZomboidFileSystem.instance.init();
        Class.forName("zombie.SandboxOptions"); // Native default visibility initializes outside a sampled Lua callback stack.
        zombie.SandboxOptions.instance.seeNotLearntRecipe.setValue(true);
        env.rawset("__nativeShelter",(JavaFunction)(f,n)->{try{Object value=op((String)f.get(0),n>1?f.get(1):null,n>2?f.get(2):null);return f.push(value instanceof Number?((Number)value).doubleValue():value);}catch(Throwable e){e.printStackTrace();throw new IllegalStateException(e);}});
        env.rawset("__recipeNative",(JavaFunction)(f,n)->{try{return f.push(recipeCall(f));}catch(Exception e){throw new IllegalStateException(e);}});
        env.rawset("__nativeRoundtrip",(JavaFunction)(f,n)->{try{var buffer=ByteBuffer.allocate(2097152);((KahluaTable)f.get(0)).save(buffer);buffer.flip();var out=platform.newTable();out.load(buffer,IsoWorld.WorldVersion);return f.push(out);}catch(Exception e){throw new IllegalStateException(e);}});
        Path source=null;for(String arg:args)if(Path.of(arg).getFileName().toString().equals("production.lua"))source=Path.of(arg);final Path reload=source;
        env.rawset("__reloadProduction",(JavaFunction)(f,n)->{try(Reader reader=Files.newBufferedReader(reload)){Object[] result=thread.pcall(LuaCompiler.loadis(reader,"reload",env),new Object[0]);if(!Boolean.TRUE.equals(result[0]))throw new IllegalStateException(Arrays.toString(result));return f.push(true);}catch(Exception e){throw new IllegalStateException(e);}});
        for(int n=1;n<args.length;n++)try(Reader reader=Files.newBufferedReader(Path.of(args[n]))){Object[] result=thread.pcall(LuaCompiler.loadis(reader,args[n],env),new Object[0]);if(!Boolean.TRUE.equals(result[0])){System.out.println("ERROR "+args[n]);for(int i=1;i<result.length;i++)System.out.println(result[i]);System.exit(1);}}
    }
}
