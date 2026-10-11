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
import zombie.entity.GameEntityFactory;
import zombie.entity.components.build.BuildLogic;
import zombie.inventory.*;
import zombie.iso.*;
import zombie.iso.objects.*;
import zombie.scripting.*;
import zombie.scripting.entity.*;
import zombie.scripting.entity.components.crafting.*;
import zombie.scripting.objects.*;

/** Installed full gate recipe/payment/group mechanics, with explicit actor/dispatch receivers. */
public final class DoubleGateNativeProbe {
    private static Path game;
    private static ScriptModule module;
    private static final Map<String,GameEntityScript> entities=new LinkedHashMap<>();
    private static final Map<Integer,InventoryItem> items=new LinkedHashMap<>();
    private static final ArrayList<IsoThumpable> parts=new ArrayList<>();
    private static Receiver actor;private static BuildLogic logic;private static String entityId,face,groupId;
    private static CraftRecipe recipe;private static IsoThumpable created;private static IsoCell cell;private static com.sao.engine.SAOIsoPlayerShell body;
    private static zombie.inventory.types.Literature magazine;private static int reads,toggles;
    private static ItemContainer materialSource;
    private static int skill=8;private static Integer woodSkill;private static boolean learned=true;private static int rootX=10,rootY=20;
    public static class Receiver extends ShelterConstructionNativeProbe.Receiver {
        @Override public boolean isRecipeKnown(CraftRecipe recipe,boolean ignore){return learned||!recipe.needToBeLearn()||body!=null&&body.isRecipeActuallyKnown(recipe.getName());}
        @Override public int getPerkLevel(zombie.characters.skills.PerkFactory.Perk perk){return woodSkill!=null&&perk==zombie.characters.skills.PerkFactory.Perks.Woodwork?woodSkill:skill;}
    }
    private static Object field(String name)throws Exception{var f=ShelterConstructionNativeProbe.class.getDeclaredField(name);f.setAccessible(true);return f.get(null);}
    private static Object call(String name,Class<?>[] types,Object...args)throws Exception{var m=ShelterConstructionNativeProbe.class.getDeclaredMethod(name,types);m.setAccessible(true);return m.invoke(null,args);}
    private static String block(Path path,String type,String name)throws Exception{return (String)call("block",new Class<?>[]{Path.class,String.class,String.class},path,type,name);}
    private static void initialise()throws Exception{
        ShelterConstructionNativeProbe.initialise(game);module=(ScriptModule)field("module");boolean server=zombie.network.GameServer.server;zombie.network.GameServer.server=true;
        for(String name:List.of("BlowTorch","WeldingRods","MetalPipe","Wire","ScrapMetal")){
            String file=List.of("BlowTorch","WeldingRods","Wire").contains(name)?"drainable":name.equals("MetalPipe")?"weapon":"normal";
            String definition=block(game.resolve("media/scripts/generated/items/"+file+".txt"),"item",name).replaceAll("(?im)^\\s*Researchablerecipes\\s*=.*$","");
            var item=new Item();item.setModule(module);item.setModID("pz-vanilla");item.InitLoadPP(name);item.Load(name,definition);item.setDisplayName(name);module.items.getScriptMap().put(name,item);
        }
        String guideName="MetalworkMag3";String guideDefinition=block(game.resolve("media/scripts/generated/items/literature.txt"),"item",guideName);
        var guide=new Item();guide.setModule(module);guide.setModID("pz-vanilla");guide.InitLoadPP(guideName);guide.Load(guideName,guideDefinition);guide.setDisplayName(guideName);module.items.getScriptMap().put(guideName,guide);
        for(String name:List.of("BuildPoleFence","BuildWireFence")){
            var timed=new TimedActionScript();timed.setModule(module);timed.InitLoadPP(name);timed.Load(name,block(game.resolve("media/scripts/generated/timedactions.txt"),"timedAction",name));module.timedActionScripts.getScriptMap().put(name,timed);
        }
        String[] definitions={"DoubleDoor","entity_wood_doubledoor","DoubleFenceGate","entity_metal_doublepolegate","DoubleWireGate","entity_metal_doublewiregate"};
        var all=(Map<String,GameEntityScript>)field("entities");
        for(int n=0;n<definitions.length;n+=2){
            String name=definitions[n];String definition=block(game.resolve("media/scripts/generated/entities/walls/"+definitions[n+1]+".txt"),"entity",name).replaceAll("(?s)component UiConfig\\s*\\{.*?\\}","");
            var entity=new GameEntityScript();entity.setModule(module);entity.setModID("pz-vanilla");entity.InitLoadPP(name);entity.Load(name,definition);
            module.entities.getScriptMap().put(name,entity);entities.put("Base."+name,entity);all.put("Base."+name,entity);
        }
        call("indexBuckets",new Class<?>[]{});for(var entity:entities.values())entity.OnScriptsLoaded(ScriptLoadMode.Init);call("indexBuckets",new Class<?>[]{});
        ItemTags.Init(ScriptManager.instance.getAllItems());for(var entity:entities.values())entity.OnPostWorldDictionaryInit();
        zombie.entity.components.spriteconfig.SpriteConfigManager.InitScriptsPostTileDef();call("nativeTiles",new Class<?>[]{Path.class},game);zombie.network.GameServer.server=server;
    }
    private static zombie.entity.components.spriteconfig.SpriteConfigManager.ObjectInfo info(String id){
        for(var value:zombie.entity.components.spriteconfig.SpriteConfigManager.GetObjectInfoList())if(value.getScript().getParent().getScriptObjectFullType().equals(id))return value;
        throw new IllegalArgumentException(id);
    }
    private static CraftRecipe recipe(String id){return ((CraftRecipeComponentScript)entities.get(id).getComponentScriptFor(ComponentType.CraftRecipe)).getCraftRecipe();}
    private static String[] materials(String id){return id.equals("Base.DoubleDoor")?new String[]{"Hammer","Plank","Nails","Hinge","Doorknob"}
        :id.equals("Base.DoubleFenceGate")?new String[]{"BlowTorch","MetalPipe","Hinge","ScrapMetal","WeldingRods"}:new String[]{"BlowTorch","MetalPipe","Wire","Hinge","ScrapMetal","WeldingRods"};}
    private static void reset(String id)throws Exception{
        entityId=id;recipe=recipe(id);skill=8;woodSkill=null;learned=true;created=null;groupId=null;toggles=0;parts.clear();items.clear();
        actor=(Receiver)ShelterConstructionNativeProbe.unsafe().allocateInstance(Receiver.class);actor.inventory=new ItemContainer();actor.inventory.setType("inventory");actor.history=new PlayerCraftHistory(actor);actor.xp=new ShelterConstructionNativeProbe.XpReceiver(actor);
        boolean server=zombie.network.GameServer.server;zombie.network.GameServer.server=true;int next=100;
        for(int n=0;n<recipe.getInputs().size();n++){
            String type=materials(id)[n];boolean uses=type.equals("BlowTorch")||type.equals("WeldingRods")||type.equals("Wire");int count=uses?1:recipe.getInputs().get(n).getIntAmount();
            for(int i=0;i<count;i++){InventoryItem item=module.getItem(type).InstanceItem(null);item.setID(next++);if(uses)item.setCurrentUses(Math.min(50,((zombie.inventory.types.DrainableComboItem)item).getMaxUses()));actor.inventory.AddItem(item);items.put(item.getID(),item);}
        }
        zombie.network.GameServer.server=server;newLogic();setManual();
    }
    private static void newLogic(){logic=new BuildLogic(actor,null,null);var containers=new ArrayList<ItemContainer>();containers.add(actor.inventory);logic.setContainers(containers);logic.setRecipe(recipe);logic.setManualSelectInputs(true);logic.clearManualInputs();}
    private static void setManual(){int next=100;for(int n=0;n<recipe.getInputs().size();n++){
        var input=recipe.getInputs().get(n);var exact=new ArrayList<InventoryItem>();String type=materials(entityId)[n];int count=type.equals("BlowTorch")||type.equals("WeldingRods")||type.equals("Wire")?1:input.getIntAmount();
        for(int i=0;i<count;i++)exact.add(items.get(next++));if(!logic.setManualInputsFor(input,exact))throw new IllegalStateException("native gate manual input "+n);
    }logic.getPossibleCraftCount(true);logic.startCraftAction(null);}
    private static boolean sceneMove(double x,double y)throws Exception{return (Boolean)call("sceneMove",new Class<?>[]{double.class,double.class,double.class},x,y,0.0);}
    private static void scene(String actorId,String orientation)throws Exception{
        // Each specimen creates a new cell. Discard only asynchronous worker
        // notifications left by the previous cell; local native collision and
        // all notifications produced by this specimen remain untouched.
        var updates=zombie.MapCollisionData.class.getDeclaredField("squareUpdateBuffer");updates.setAccessible(true);
        ((ByteBuffer)updates.get(zombie.MapCollisionData.instance)).clear();
        face=orientation;call("sceneSetup",new Class<?>[]{String.class,String.class},orientation,actorId);cell=(IsoCell)field("sceneCell");body=(com.sao.engine.SAOIsoPlayerShell)field("sceneBody");
        for(int x=5;x<18;x++)for(int y=14;y<26;y++)for(int z=0;z<=1;z++){
            var sq=cell.getGridSquare(x,y,z);if(sq==null)continue;
            for(int n=sq.getObjects().size()-1;n>=0;n--){var object=sq.getObjects().get(n);if(object instanceof IsoThumpable||z>0){sq.getObjects().remove(n);sq.getSpecialObjects().remove(object);}}
            sq.setRoom(null);sq.setRoomID(-1);sq.haveRoof=false;sq.RecalcAllWithNeighbours(true);
        }
        for(int n:List.of(-1,4)){
            int x=rootX+(face.equals("N")?n:0),y=rootY+(face.equals("W")?n:0);var square=cell.getGridSquare(x,y,0);
            var wallInfo=(zombie.entity.components.spriteconfig.SpriteConfigManager.ObjectInfo)call("info",new Class<?>[]{String.class},"Base.WoodenWallLvl1");
            var object=new IsoThumpable(cell,square,wallInfo.getFace(face).getTileInfo(0,0,0).getSpriteName(),face.equals("N"),null);object.setCanPassThrough(false);square.getObjects().add(object);square.getSpecialObjects().add(object);square.RecalcAllWithNeighbours(true);
        }
        sceneMove(face.equals("N")?11.5:13.5,face.equals("N")?23.5:21.5);look();
    }
    private static void look()throws Exception{
        body.setForwardDirection(face.equals("N")?0:-1,face.equals("N")?-1:0);var f=zombie.characters.IsoGameCharacter.class.getDeclaredField("animPlayer");f.setAccessible(true);
        ((zombie.core.skinnedmodel.animation.AnimationPlayer)f.get(body)).setAngle(face.equals("N")?-(float)Math.PI/2:(float)Math.PI);
    }
    private static Object op(String name,Object a,Object b)throws Exception{
        int index=a instanceof Number?((Number)a).intValue():0;
        switch(name){
            case "reset":reset((String)a);return true;
            case "split":{
                var original=new ArrayList<InventoryItem>(items.values());int next=100+items.size();
                for(var item:original)if(item instanceof zombie.inventory.types.DrainableComboItem){
                    int quantity=item.getType().equals("Wire")?4:10;item.setCurrentUses(1);
                    for(int n=1;n<quantity;n++){var copy=module.getItem(item.getType()).InstanceItem(null);copy.setID(next++);copy.setCurrentUses(1);actor.inventory.AddItem(copy);items.put(copy.getID(),copy);}
                }
                newLogic();for(int n=0;n<recipe.getInputs().size();n++){
                    var exact=new ArrayList<InventoryItem>();String type=materials(entityId)[n];for(var item:items.values())if(item.getType().equals(type))exact.add(item);
                    if(!logic.setManualInputsFor(recipe.getInputs().get(n),exact))throw new IllegalStateException("pooled native input refused");
                }logic.getPossibleCraftCount(true);logic.startCraftAction(null);return true;
            }
            case "scene":scene((String)a,(String)b);return true;
            case "position":{var t=zombie.Lua.LuaManager.platform.newTable();t.rawset("x",(double)body.getX());t.rawset("y",(double)body.getY());t.rawset("z",(double)body.getZ());return t;}
            case "move":{var p=((String)a).split(",");return sceneMove(Double.parseDouble(p[0]),Double.parseDouble(p[1]));}
            case "look":look();return true;
            case "sites":return com.sao.engine.SAODoubleGate.observe(body);
            case "placement":return com.sao.engine.SAODoubleGate.placement(body,(String)a,(String)b)!=null;
            case "unroofed":return body.getCurrentSquare().getRoom()==null&&!body.getCurrentSquare().haveRoof;
            case "absent":return parts.isEmpty();
            case "inputCount":return recipe((String)a).getInputs().get(((Number)b).intValue()).getIntAmount();
            case "inputKeep":return recipe((String)a).getInputs().get(((Number)b).intValue()).isKeep();
            case "skillCount":return recipe((String)a).getRequiredSkillCount();
            case "skill":skill=index;return true;
            case "woodSkill":woodSkill=index;return true;
            case "known":learned=Boolean.TRUE.equals(a);return true;
            case "skillPass":return zombie.entity.components.crafting.recipe.CraftRecipeManager.hasPlayerRequiredSkill(recipe((String)a).getRequiredSkill(((Number)b).intValue()),actor);
            case "learnedPass":return zombie.entity.components.crafting.recipe.CraftRecipeManager.hasPlayerLearnedRecipe(recipe((String)a),actor);
            case "recordInput":return recipe((String)a).getInputs().get(((Number)b).intValue()).isRecordInput();
            case "faceWidth":return info((String)a).getFace((String)b).getWidth();
            case "faceHeight":return info((String)a).getFace((String)b).getHeight();
            case "sprite":{var p=((String)b).split(",");return info((String)a).getFace(face).getTileInfo(Integer.parseInt(p[0]),Integer.parseInt(p[1]),0).getSpriteName();}
            case "spriteType":return zombie.iso.sprite.IsoSpriteManager.instance.getSprite((String)a).getType().name();
            case "spriteFlag":return zombie.iso.sprite.IsoSpriteManager.instance.getSprite((String)a).getProperties().has(zombie.iso.SpriteDetails.IsoFlagType.valueOf((String)b));
            case "spriteProperty":return info((String)a).getScript().getClass().getMethod((String)b).invoke(info((String)a).getScript());
            case "count":return items.size();
            case "type":return items.get(index).getFullType();
            case "uses":return items.get(index).getCurrentUses();
            case "condition":return items.get(index).getCondition();
            case "held":return actor.inventory.contains(items.get(index));
            case "withdraw":{materialSource=new ItemContainer();var item=items.get(index);actor.inventory.Remove(item);materialSource.AddItem(item);return !actor.inventory.contains(item)&&materialSource.contains(item);}
            case "reclaim":{var item=items.get(index);if(materialSource==null||!materialSource.contains(item))return false;materialSource.Remove(item);actor.inventory.AddItem(item);return actor.inventory.contains(item);}
            case "materialCategory":return com.sao.engine.SAONeeds.wantsMaterial(items.get(index),(String)b);
            case "sourceCategories":{var type=Class.forName("com.sao.engine.SAOWorldSources$ItemRow");var method=type.getDeclaredMethod("of",InventoryItem.class);method.setAccessible(true);var row=method.invoke(null,items.get(index));var categories=type.getDeclaredField("categories");categories.setAccessible(true);return String.join(",",(ArrayList<String>)categories.get(row));}
            case "inputMatch":{var p=((String)a).split("\\|");return zombie.entity.components.crafting.recipe.CraftRecipeManager.getValidInputScriptForItem(recipe(p[0]),items.get(((Number)b).intValue()),actor)==recipe(p[0]).getInputs().get(Integer.parseInt(p[1]));}
            case "newLogic":newLogic();return true;
            case "manual":{var exact=new ArrayList<InventoryItem>();for(String id:((String)b).split(","))if(!id.isEmpty())exact.add(items.get(Integer.parseInt(id)));return logic.setManualInputsFor(recipe.getInputs().get(index),exact);}
            case "manualIds":{var data="progress".equals(a)?logic.getRecipeDataInProgress():logic.getRecipeData();return data.getManualInputsFor(recipe.getInputs().get(((Number)b).intValue()),new ArrayList<>()).stream().map(v->Integer.toString(v.getID())).collect(java.util.stream.Collectors.joining(","));}
            case "start":logic.startCraftAction(null);return true;
            case "stop":logic.stopCraftAction();return true;
            case "eligible":return logic.canPerformCurrentRecipe();
            case "possible":return logic.getPossibleCraftCount(true);
            case "perform":return logic.performCurrentRecipe();
            case "process":logic.getRecipeDataInProgress().luaCallOnCreate(actor);logic.getRecipeDataInProgress().processDestroyAndUsedItems(actor);return true;
            case "consumedCount":return logic.getRecipeDataInProgress().getAllConsumedItems().size();
            case "keptCount":return logic.getRecipeDataInProgress().getAllKeepInputItems().size();
            case "consumed":return logic.getRecipeDataInProgress().getAllConsumedItems().contains(items.get(index));
            case "kept":return logic.getRecipeDataInProgress().getAllKeepInputItems().contains(items.get(index));
            case "factory":{var p=((String)b).split(",");var sq=cell.getGridSquare(Integer.parseInt(p[0]),Integer.parseInt(p[1]),0);
                created=new IsoThumpable(cell,sq,(String)a,face.equals("N"),null);created.setIsDoor(true);created.setCanPassThrough(false);created.setIsThumpable(true);created.setMaxHealth(1000);created.setHealth(1000);
                created.setName(entityId.substring(5));GameEntityFactory.CreateIsoObjectEntity(created,entities.get(entityId),true);sq.getObjects().add(created);sq.getSpecialObjects().add(created);sq.RecalcAllWithNeighbours(true);parts.add(created);return true;}
            case "created":{for(int n=0;n<parts.size();n++){var o=parts.get(n);System.out.println("NATIVE_GATE_PART "+face+" n="+n+" index="+IsoDoor.getDoubleDoorIndex(o)+" pos="+o.getX()+","+o.getY()+" door="+o.isDoor()+" sprite="+o.getSpriteName());}var t=zombie.Lua.LuaManager.platform.newTable();for(int n=0;n<parts.size();n++)t.rawset((double)n+1,parts.get(n));groupId=groupId==null?com.sao.engine.SAODoubleGate.created(body,t,entityId,rootX,rootY,0,face):groupId;return groupId;}
            case "group":return com.sao.engine.SAODoubleGate.group(body,(String)a,entityId,rootX,rootY,0,face);
            case "leaf":return com.sao.engine.SAODoubleGate.leaf(body,(String)a,entityId,rootX,rootY,0,face)!=null;
            case "toggle":{var leaf=com.sao.engine.SAODoubleGate.leaf(body,(String)a,entityId,rootX,rootY,0,face);if(leaf==null)return false;System.out.println("GATE_NATIVE_OWN_TOGGLE before="+leaf.IsOpen()+" obstructed="+IsoDoor.isDoubleDoorObstructed(leaf)+" pos="+body.getX()+","+body.getY());toggles++;leaf.ToggleDoor(body);System.out.println("GATE_NATIVE_OWN_TOGGLE after="+leaf.IsOpen()+" group="+(com.sao.engine.SAODoubleGate.group(body,(String)a,entityId,rootX,rootY,0,face)!=null));return true;}
            case "toggleCount":return toggles;
            case "externalToggle":{var leaf=com.sao.engine.SAODoubleGate.leaf(body,(String)a,entityId,rootX,rootY,0,face);if(leaf==null)return false;var keep=zombie.characters.IsoPlayer.getInstance();try{var descriptor=new zombie.characters.SurvivorDesc(false);descriptor.getHumanVisual().setSkinTextureName("fixture");var external=new zombie.characters.IsoPlayer(cell,descriptor,(int)body.getX(),(int)body.getY(),0,false);external.getModData().rawset("SAOPersonId","controlled-external-gate-actor");toggles++;leaf.ToggleDoor(external);cell.getObjectList().remove(external);cell.getAddList().remove(external);external.removeFromSquare();return external!=body;}finally{zombie.characters.IsoPlayer.setInstance(keep);}}
            case "removeGroup":{var leaf=com.sao.engine.SAODoubleGate.leaf(body,groupId,entityId,rootX,rootY,0,face);if(leaf==null)return false;var removed=new ArrayList<IsoObject>();for(int n=1;n<=4;n++)removed.add(IsoDoor.getDoubleDoorObject(leaf,n));for(var object:removed)object.getSquare().RemoveTileObject(object);parts.clear();return com.sao.engine.SAODoubleGate.group(body,groupId,entityId,rootX,rootY,0,face)==null;}
            case "passBegin":return com.sao.engine.SAODoubleGate.beginPassage(body,(String)a,entityId,rootX,rootY,0,face,face.equals("N")?11:9,face.equals("N")?19:21);
            case "passage":return com.sao.engine.SAODoubleGate.passage(body,(String)a);
            case "passForget":com.sao.engine.SAODoubleGate.forgetPassage(body,(String)a);return true;
            case "noBoundary":{for(int n:List.of(-1,4)){var sq=cell.getGridSquare(rootX+(face.equals("N")?n:0),rootY+(face.equals("W")?n:0),0);for(int i=sq.getObjects().size()-1;i>=0;i--)if(sq.getObjects().get(i) instanceof IsoThumpable){var o=sq.getObjects().get(i);sq.getObjects().remove(i);sq.getSpecialObjects().remove(o);}sq.RecalcAllWithNeighbours(true);}return true;}
            case "removeMember":{var anchor=com.sao.engine.SAODoubleGate.leaf(body,groupId,entityId,rootX,rootY,0,face);var member=IsoDoor.getDoubleDoorObject(anchor,2);member.getSquare().RemoveTileObject(member);return true;}
            case "foreignMember":{var anchor=com.sao.engine.SAODoubleGate.leaf(body,groupId,entityId,rootX,rootY,0,face);var member=IsoDoor.getDoubleDoorObject(anchor,2);member.getModData().rawset("SAODoubleGateId","foreign-group");return true;}
            case "duplicateMember":{var anchor=com.sao.engine.SAODoubleGate.leaf(body,groupId,entityId,rootX,rootY,0,face);var member=(IsoThumpable)IsoDoor.getDoubleDoorObject(anchor,2);var square=member.getSquare();var copy=new IsoThumpable(cell,square,member.getSpriteName(),member.getNorth(),null);copy.setIsDoor(true);copy.getModData().rawset("SAODoubleGateId",groupId);copy.getModData().rawset("SAODoubleGateEntity",entityId);copy.getModData().rawset("SAODoubleGateMember",2.0);square.getObjects().add(copy);square.getSpecialObjects().add(copy);square.RecalcAllWithNeighbours(true);return IsoDoor.getDoubleDoorIndex(copy)==2;}
            case "obstruct":{var sq=cell.getGridSquare(face.equals("N")?10:9,face.equals("N")?21:20,0);var obstacle=new IsoObject(cell);obstacle.setSquare(sq);var sprite=new zombie.iso.sprite.IsoSprite();sprite.getProperties().set(zombie.iso.SpriteDetails.IsoFlagType.solid);sprite.getProperties().set(zombie.iso.SpriteDetails.IsoFlagType.solidtrans);obstacle.setSprite(sprite);sq.getObjects().add(obstacle);sq.RecalcAllWithNeighbours(true);return IsoDoor.isDoubleDoorObstructed(com.sao.engine.SAODoubleGate.leaf(body,groupId,entityId,rootX,rootY,0,face));}
            case "barricade":{var leaf=com.sao.engine.SAODoubleGate.leaf(body,groupId,entityId,rootX,rootY,0,face);var barricade=IsoBarricade.AddBarricadeToObject(leaf,false);if(barricade==null)return false;barricade.addPlank(body);return leaf.isBarricaded();}
            case "lock":{var leaf=com.sao.engine.SAODoubleGate.leaf(body,groupId,entityId,rootX,rootY,0,face);leaf.setKeyId(81031);leaf.setIsLocked(Boolean.TRUE.equals(a));leaf.setLockedByKey(Boolean.TRUE.equals(a));return true;}
            default:throw new IllegalArgumentException(name);
        }
    }
    private static Object recipeCall(LuaCallFrame f)throws Exception{
        String op=(String)f.get(0);String key=f.get(1) instanceof String?(String)f.get(1):null;
        switch(op){
            case "new-item":magazine=(zombie.inventory.types.Literature)module.getItem("MetalworkMag3").InstanceItem(null,false);magazine.setID(901);body.getInventory().AddItem(magazine);items.put(901,magazine);return 901.0;
            case "script":{var script=ScriptManager.instance.getItem(key);if(script==null)return null;return switch((String)f.get(2)){
                case "pages"->(double)script.getNumberOfPages();case "skill"->script.getSkillTrained();case "literature"->script.isItemType(zombie.scripting.objects.ItemType.LITERATURE);
                case "recipe"->script.getLearnedRecipes()!=null&&script.getLearnedRecipes().contains((String)f.get(3));default->throw new IllegalArgumentException();};}
            case "item":return switch((String)f.get(2)){case "pages"->(double)magazine.getNumberOfPages();case "type"->magazine.getFullType();case "recipe"->magazine.getLearnedRecipes().contains((String)f.get(3));default->throw new IllegalArgumentException();};
            case "known":return body.isRecipeActuallyKnown(key);
            case "read":body.ReadLiterature(magazine);reads++;return true;
            case "reads":return (double)reads;
            default:throw new IllegalArgumentException(op);
        }
    }
    public static void main(String[] args)throws Exception{
        game=Path.of(args[0]);var platform=new J2SEPlatform();var env=platform.newEnvironment();var thread=new KahluaThread(platform,env);thread.debugOwnerThread=Thread.currentThread();
        zombie.Lua.LuaManager.env=env;zombie.Lua.LuaManager.thread=thread;zombie.Lua.LuaManager.caller=new se.krka.kahlua.integration.LuaCaller(new se.krka.kahlua.converter.KahluaConverterManager());
        env.rawset("print",(JavaFunction)(f,n)->{for(int i=0;i<n;i++)System.out.print((i==0?"":"\t")+f.get(i));System.out.println();return 0;});
        thread.call(LuaCompiler.loadstring("ISTimedActionQueue={queues={},getTimedActionQueue=function() return {queue={}} end}","empty",env),null,null,null);initialise();
        env.rawset("__nativeShelter",(JavaFunction)(f,n)->{try{Object result=call("op",new Class<?>[]{String.class,Object.class,Object.class},(String)f.get(0),n>1?f.get(1):null,n>2?f.get(2):null);return f.push(result instanceof Number?((Number)result).doubleValue():result);}catch(Exception e){throw new IllegalStateException(e);}});
        env.rawset("__recipeNative",(JavaFunction)(f,n)->{try{return f.push(recipeCall(f));}catch(Exception e){e.printStackTrace();throw new IllegalStateException(e);}});
        env.rawset("__nativeGate",(JavaFunction)(f,n)->{try{Object result=op((String)f.get(0),n>1?f.get(1):null,n>2?f.get(2):null);return f.push(result instanceof Number?((Number)result).doubleValue():result);}catch(Throwable e){e.printStackTrace();throw new IllegalStateException(e);}});
        env.rawset("__nativeRoundtrip",(JavaFunction)(f,n)->{try{var bytes=ByteBuffer.allocate(2097152);((KahluaTable)f.get(0)).save(bytes);bytes.flip();var restored=platform.newTable();restored.load(bytes,IsoWorld.WorldVersion);return f.push(restored);}catch(Exception e){throw new IllegalStateException(e);}});
        Path production=null;for(String arg:args)if(Path.of(arg).getFileName().toString().equals("production.lua"))production=Path.of(arg);final Path reload=production;
        env.rawset("__reloadProduction",(JavaFunction)(f,n)->{try(Reader r=Files.newBufferedReader(reload)){Object[] v=thread.pcall(LuaCompiler.loadis(r,"reload",env),new Object[0]);if(!Boolean.TRUE.equals(v[0]))throw new IllegalStateException(Arrays.toString(v));return f.push(true);}catch(Exception e){throw new IllegalStateException(e);}});
        for(int i=1;i<args.length;i++)try(Reader reader=Files.newBufferedReader(Path.of(args[i]))){Object[] result=thread.pcall(LuaCompiler.loadis(reader,args[i],env),new Object[0]);if(!Boolean.TRUE.equals(result[0])){System.out.println("ERROR "+args[i]);for(int n=1;n<result.length;n++)System.out.println(result[n]);System.exit(1);}}
    }
}
