import java.io.Reader;
import java.lang.reflect.*;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.*;
import sun.misc.Unsafe;
import zombie.characters.*;
import zombie.characters.skills.PerkFactory;
import zombie.entity.ComponentType;
import zombie.entity.GameEntityFactory;
import zombie.entity.components.build.BuildLogic;
import zombie.entity.components.crafting.recipe.CraftRecipeData;
import zombie.inventory.*;
import zombie.iso.IsoGridSquare;
import zombie.iso.objects.IsoThumpable;
import zombie.scripting.*;
import zombie.scripting.entity.*;
import zombie.scripting.entity.components.crafting.*;
import zombie.scripting.objects.*;

/** Native entity scripts/build recipe payment/factory; controlled unattached actor. */
public final class RainCollectorNativeProbe {
    private static ScriptModule module;
    private static final Map<String,GameEntityScript> entities=new LinkedHashMap<>();
    private static Receiver actor;
    private static BuildLogic logic;
    private static CraftRecipe selected;
    private static final Map<Integer,InventoryItem> items=new LinkedHashMap<>();
    private static IsoThumpable created;
    private static int skill=5;
    public static Unsafe unsafe() throws Exception {
        Field f=Unsafe.class.getDeclaredField("theUnsafe");f.setAccessible(true);return (Unsafe)f.get(null);
    }
    public static class Receiver extends IsoPlayer {
        ItemContainer inventory;PlayerCraftHistory history;IsoGameCharacter.XP xp;
        public Receiver(){super((zombie.iso.IsoCell)null);}
        @Override public ItemContainer getInventory(){return inventory;}
        @Override public int getPerkLevel(PerkFactory.Perk p){return skill;}
        @Override public int getWeaponLevel(){return 0;}
        @Override public int getWeaponLevel(zombie.inventory.types.HandWeapon weapon){return 0;}
        @Override public boolean isRecipeKnown(CraftRecipe r,boolean ignore){return !r.needToBeLearn();}
        @Override public PlayerCraftHistory getPlayerCraftHistory(){return history;}
        @Override public IsoGameCharacter.XP getXp(){return xp;}
        @Override public boolean isEquipped(InventoryItem i){return i==items.get(100);}
        @Override public boolean isEquippedClothing(InventoryItem i){return false;}
        @Override public boolean isLocalPlayer(){return false;}
    }
    public static class XpReceiver extends IsoGameCharacter.XP {
        XpReceiver(Receiver a){a.super(a);}
        @Override public void AddXP(PerkFactory.Perk p,float amount,boolean a,boolean b,boolean c,boolean d){}
    }
    private static String block(Path path,String type,String name)throws Exception{
        String source=Files.readString(path);
        var m=java.util.regex.Pattern.compile("(?m)^\\s*"+type+"\\s+"+java.util.regex.Pattern.quote(name)+"\\s*\\{").matcher(source);
        if(!m.find())throw new IllegalStateException("missing "+type+" "+name);
        int start=m.start(),end=source.indexOf('{',start)+1,depth=1;
        while(depth>0){char c=source.charAt(end++);if(c=='{')depth++;if(c=='}')depth--;}
        return source.substring(start,end);
    }
    private static void indexBuckets()throws Exception{
        for(Field f:ScriptManager.class.getDeclaredFields())if(ScriptBucketCollection.class.isAssignableFrom(f.getType())){
            f.setAccessible(true);ScriptBucketCollection c=(ScriptBucketCollection)f.get(ScriptManager.instance);
            ScriptBucket bucket=c.getBucketFromModule(module);
            for(Object v:bucket.getScriptMap().values()){
                BaseScriptObject script=(BaseScriptObject)v;c.getFullTypeToScriptMap().put(script.getScriptObjectFullType(),script);
                if(!bucket.getScriptList().contains(script))bucket.getScriptList().add(script);
                if(!c.getAllScripts().contains(script))c.getAllScripts().add(script);
            }
        }
    }
    public static void initialise(Path game)throws Exception{
        if(!entities.isEmpty())return;
        zombie.core.random.RandStandard.INSTANCE.init();PerkFactory.init();zombie.entity.components.attributes.Attribute.init();
        boolean priorServer=zombie.network.GameServer.server;zombie.network.GameServer.server=true;
        Field loadMod=ScriptManager.class.getDeclaredField("currentLoadFileMod");loadMod.setAccessible(true);loadMod.set(null,"pz-vanilla");
        module=ScriptManager.instance.moduleMap.get("Base");
        if(module==null){
            module=new ScriptModule();module.name="Base";ScriptManager.instance.moduleMap.put("Base",module);ScriptManager.instance.moduleList.add(module);
            for(Field f:ScriptManager.class.getDeclaredFields())if(ScriptBucketCollection.class.isAssignableFrom(f.getType())){
                f.setAccessible(true);((ScriptBucketCollection<?>)f.get(ScriptManager.instance)).registerModule(module);
            }
        }
        for(String name:List.of("Hammer","Plank","Nails","Garbagebag","Tarp")){
            if(module.getItem(name)!=null)continue;
            String file=List.of("Hammer","Plank").contains(name)?"weapon":name.equals("Garbagebag")?"container":"normal";
            String definition=block(game.resolve("media/scripts/generated/items/"+file+".txt"),"item",name)
                .replaceAll("(?im)^\\s*Researchablerecipes\\s*=.*$","");
            Item item=new Item();item.setModule(module);item.setModID("pz-vanilla");item.InitLoadPP(name);item.Load(name,definition);item.setDisplayName(name);
            module.items.getScriptMap().put(name,item);
        }
        if(module.timedActionScripts.getScriptMap().get("BuildWoodenStructureMedium")==null){
            TimedActionScript timed=new TimedActionScript();timed.setModule(module);timed.InitLoadPP("BuildWoodenStructureMedium");
            timed.Load("BuildWoodenStructureMedium",block(game.resolve("media/scripts/generated/timedactions.txt"),"timedAction","BuildWoodenStructureMedium"));
            module.timedActionScripts.getScriptMap().put("BuildWoodenStructureMedium",timed);
        }
        for(String name:List.of("RainCollector","RainCollectorRound","RainCollector_Tarp","RainCollectorRound_Tarp")){
            String definition=block(game.resolve("media/scripts/generated/entities/outdoors/entity_raincollector"+(name.contains("_Tarp")?"_tarp":"")+".txt"),"entity",name);
            // UI skin registry is outside this unattended native operation.
            definition=definition.replaceAll("(?s)component UiConfig\\s*\\{.*?\\}","");
            GameEntityScript entity=new GameEntityScript();entity.setModule(module);entity.setModID("pz-vanilla");entity.InitLoadPP(name);entity.Load(name,definition);
            module.entities.getScriptMap().put(name,entity);entities.put("Base."+name,entity);
        }
        indexBuckets();
        for(GameEntityScript entity:entities.values())entity.OnScriptsLoaded(ScriptLoadMode.Init);
        indexBuckets();ItemTags.Init(ScriptManager.instance.getAllItems());
        for(GameEntityScript entity:entities.values())entity.OnPostWorldDictionaryInit();
        for(GameEntityScript entity:entities.values()){
            var sprites=(zombie.scripting.entity.components.spriteconfig.SpriteConfigScript)entity.getComponentScriptFor(ComponentType.SpriteConfig);
            for(String name:sprites.getAllTileNames())zombie.iso.sprite.IsoSpriteManager.instance.AddSprite(name).name=name;
        }
        zombie.entity.components.spriteconfig.SpriteConfigManager.InitScriptsPostTileDef();
        zombie.network.GameServer.server=priorServer;
    }
    public static GameEntityScript entity(String id){return entities.get(id);}
    public static CraftRecipe recipe(String id){return ((CraftRecipeComponentScript)entity(id).getComponentScriptFor(ComponentType.CraftRecipe)).getCraftRecipe();}
    public static IsoThumpable createCollector(String id,IsoGridSquare square)throws Exception{
        var script=(zombie.scripting.entity.components.spriteconfig.SpriteConfigScript)entity(id).getComponentScriptFor(ComponentType.SpriteConfig);
        IsoThumpable object=new IsoThumpable(square==null?null:square.getCell(),square,script.getAllTileNames().get(0),false,null);
        GameEntityFactory.CreateIsoObjectEntity(object,entity(id),true);
        if(object.getFluidContainer()==null){
            var method=GameEntityFactory.class.getDeclaredMethod("createEntity",zombie.entity.GameEntity.class,GameEntityScript.class,boolean.class);method.setAccessible(true);
            System.out.println("factory diagnosis sprite="+object.getSpriteName()+" infos="+zombie.entity.components.spriteconfig.SpriteConfigManager.GetObjectInfoList().size()+" script="+script.getScriptObjectFullType());
            method.invoke(null,object,entity(id),true);
        }
        return object;
    }
    private static void reset(String id)throws Exception{
        actor=(Receiver)unsafe().allocateInstance(Receiver.class);actor.inventory=new ItemContainer();
        actor.inventory.setType("inventory");actor.history=new PlayerCraftHistory(actor);actor.xp=new XpReceiver(actor);
        selected=recipe(id);items.clear();created=null;skill=5;
        boolean prior=zombie.network.GameServer.server;zombie.network.GameServer.server=true;
        int itemId=100;
        for(int i=0;i<selected.getInputs().size();i++){
            InputScript input=selected.getInputs().get(i);
            String type=i==0?"Hammer":i==1?"Plank":i==2?"Nails":id.contains("_Tarp")?"Tarp":"Garbagebag";
            for(int j=0;j<input.getIntAmount();j++){
                InventoryItem item=module.getItem(type).InstanceItem(null);item.setID(itemId++);actor.inventory.AddItem(item);items.put(item.getID(),item);
            }
        }
        zombie.network.GameServer.server=prior;
        logic=new BuildLogic(actor,null,null);ArrayList<ItemContainer> containers=new ArrayList<>();containers.add(actor.inventory);
        logic.setContainers(containers);logic.setRecipe(selected);logic.setManualSelectInputs(true);logic.clearManualInputs();
        int offset=100;
        for(InputScript input:selected.getInputs()){
            ArrayList<InventoryItem> exact=new ArrayList<>();for(int j=0;j<input.getIntAmount();j++)exact.add(items.get(offset++));
            if(!logic.setManualInputsFor(input,exact))throw new IllegalStateException("native manual selection refused input="+selected.getInputs().indexOf(input)
                +" count="+input.getIntAmount()+" type="+exact.get(0).getFullType()+" container="+exact.get(0).getContainer()
                +" matches="+(zombie.entity.components.crafting.recipe.CraftRecipeManager.getValidInputScriptForItem(selected,exact.get(0),actor)==input));
        }
        logic.getPossibleCraftCount(true);
        logic.startCraftAction(null);
        for(InputScript input:selected.getInputs())if(logic.getRecipeDataInProgress().getManualInputsFor(input,new ArrayList<>()).size()!=input.getIntAmount())
            throw new IllegalStateException("native in-progress manual slot missing");
    }
    private static Object op(String name,Object a,Object b)throws Exception{
        int i=a instanceof Number?((Number)a).intValue():0;
        switch(name){
            case "reset":reset((String)a);return true;
            case "entityCount":return entities.size();
            case "recipeId":return selected.getScriptObjectFullType();
            case "entityRecipeId":return recipe((String)a).getScriptObjectFullType();
            case "policyCount":return recipe((String)a).getInputs().get(((Number)b).intValue()).getIntAmount();
            case "policyKeep":return recipe((String)a).getInputs().get(((Number)b).intValue()).isKeep();
            case "policySkill":return zombie.entity.components.crafting.recipe.CraftRecipeManager.hasPlayerRequiredSkill(
                recipe((String)a).getRequiredSkill(((Number)b).intValue()),actor);
            case "policySkillCount":return recipe((String)a).getRequiredSkillCount();
            case "policyLearned":return zombie.entity.components.crafting.recipe.CraftRecipeManager.hasPlayerLearnedRecipe(recipe((String)a),actor);
            case "policyTime":return recipe((String)a).getTime(actor);
            case "spriteProp":return entity((String)a).getComponentScriptFor(ComponentType.SpriteConfig).getClass().getMethod((String)b).invoke(entity((String)a).getComponentScriptFor(ComponentType.SpriteConfig));
            case "sprite":return ((zombie.scripting.entity.components.spriteconfig.SpriteConfigScript)entity((String)a).getComponentScriptFor(ComponentType.SpriteConfig)).getAllTileNames().get(0);
            case "newLogic":logic=new BuildLogic(actor,null,null);return true;
            case "containers": {ArrayList<ItemContainer> containers=new ArrayList<>();containers.add(actor.inventory);logic.setContainers(containers);return true;}
            case "setRecipe":selected=recipe((String)a);logic.setRecipe(selected);return true;
            case "manualMode":logic.setManualSelectInputs(Boolean.TRUE.equals(a));return true;
            case "clearManual":logic.clearManualInputs();return true;
            case "manual": {
                ArrayList<InventoryItem> selectedItems=new ArrayList<>();
                for(String id:((String)b).split(","))if(!id.isEmpty())selectedItems.add(items.get(Integer.parseInt(id)));
                return logic.setManualInputsFor(selected.getInputs().get(i),selectedItems);
            }
            case "start":logic.startCraftAction(null);return true;
            case "stop":logic.stopCraftAction();return true;
            case "manualIds": {
                CraftRecipeData data="progress".equals(a)?logic.getRecipeDataInProgress():logic.getRecipeData();
                var selectedItems=data.getManualInputsFor(selected.getInputs().get(((Number)b).intValue()),new ArrayList<>());
                return selectedItems.stream().map(x->Integer.toString(x.getID())).collect(java.util.stream.Collectors.joining(","));
            }
            case "progressRecipe":return logic.getRecipeDataInProgress().getRecipe()!=null;
            case "inputMatches": {
                String[] descriptor=((String)a).split("\\|");
                return zombie.entity.components.crafting.recipe.CraftRecipeManager.getValidInputScriptForItem(
                    recipe(descriptor[0]),items.get(((Number)b).intValue()),actor)==recipe(descriptor[0]).getInputs().get(Integer.parseInt(descriptor[1]));
            }
            case "count":return items.size();
            case "type":return items.get(i).getFullType();
            case "condition":return items.get(i).getCondition();
            case "held":return actor.inventory.contains(items.get(i));
            case "inputCount":return selected.getInputs().get(i).getIntAmount();
            case "inputKeep":return selected.getInputs().get(i).isKeep();
            case "eligible":return logic.canPerformCurrentRecipe();
            case "possible":return logic.getPossibleCraftCount(true);
            case "perform":return logic.performCurrentRecipe();
            case "process":logic.getRecipeDataInProgress().luaCallOnCreate(actor);logic.getRecipeDataInProgress().processDestroyAndUsedItems(actor);return true;
            case "consumed":return logic.getRecipeDataInProgress().getAllConsumedItems().contains(items.get(i));
            case "kept":return logic.getRecipeDataInProgress().getAllKeepInputItems().contains(items.get(i));
            case "skill":skill=i;return true;
            case "capacity":return ((zombie.scripting.entity.components.fluids.FluidContainerScript)entity((String)a).getComponentScriptFor(ComponentType.FluidContainer)).getCapacity();
            case "rainFactor":return ((zombie.scripting.entity.components.fluids.FluidContainerScript)entity((String)a).getComponentScriptFor(ComponentType.FluidContainer)).getRainCatcher();
            case "inputEligible":return zombie.entity.components.crafting.recipe.CraftRecipeManager.getValidInputScriptForItem(selected,items.get(i),actor)==selected.getInputs().get(((Number)b).intValue());
            case "factory":created=createCollector((String)a,null);return true;
            case "createdAmount":return created.getFluidContainer().getAmount();
            case "createdCapacity":return created.getFluidContainer().getCapacity();
            default:throw new IllegalArgumentException(name);
        }
    }
    public static void main(String[] args)throws Exception{
        J2SEPlatform platform=new J2SEPlatform();KahluaTable env=platform.newEnvironment();KahluaThread thread=new KahluaThread(platform,env);thread.debugOwnerThread=Thread.currentThread();
        zombie.Lua.LuaManager.env=env;zombie.Lua.LuaManager.thread=thread;
        zombie.Lua.LuaManager.caller=new se.krka.kahlua.integration.LuaCaller(new se.krka.kahlua.converter.KahluaConverterManager());
        env.rawset("print",(JavaFunction)(f,n)->{for(int i=0;i<n;i++)System.out.print((i==0?"":"\t")+f.get(i));System.out.println();return 0;});
        thread.call(LuaCompiler.loadstring("ISTimedActionQueue={queues={},getTimedActionQueue=function() return {queue={}} end}","empty",env),null,null,null);
        initialise(Path.of(args[0]));
        if(args.length==1){
            for(String id:entities.keySet()){
                reset(id);System.out.println("ENTITY "+id+" recipe="+selected.getScriptObjectFullType()+" nativeEligible="+logic.canPerformCurrentRecipe());
                System.out.println("PAYMENT "+logic.performCurrentRecipe());op("process",null,null);
                created=createCollector(id,null);System.out.println("FACTORY capacity="+created.getFluidContainer().getCapacity()+" amount="+created.getFluidContainer().getAmount());
            }return;
        }
        env.rawset("__nativeCollector",(JavaFunction)(f,n)->{try{Object result=op((String)f.get(0),n>1?f.get(1):null,n>2?f.get(2):null);
            return f.push(result instanceof Number?((Number)result).doubleValue():result);}catch(Exception e){e.printStackTrace();throw new IllegalStateException(e);}});
        env.rawset("__nativeRoundtrip",(JavaFunction)(f,n)->{try{ByteBuffer bytes=ByteBuffer.allocate(1048576);((KahluaTable)f.get(0)).save(bytes);bytes.flip();
            KahluaTable restored=platform.newTable();restored.load(bytes,zombie.iso.IsoWorld.WorldVersion);return f.push(restored);}catch(Exception e){throw new IllegalStateException(e);}});
        Path production=null;for(String arg:args)if(Path.of(arg).getFileName().toString().equals("production.lua"))production=Path.of(arg);final Path reload=production;
        env.rawset("__reloadProduction",(JavaFunction)(f,n)->{try(Reader r=Files.newBufferedReader(reload)){Object[] v=thread.pcall(LuaCompiler.loadis(r,"reload",env),new Object[0]);
            if(!Boolean.TRUE.equals(v[0]))throw new IllegalStateException(Arrays.toString(v));return f.push(true);}catch(Exception e){throw new IllegalStateException(e);}});
        for(int i=1;i<args.length;i++)try(Reader reader=Files.newBufferedReader(Path.of(args[i]),StandardCharsets.UTF_8)){
            Object[] v=thread.pcall(LuaCompiler.loadis(reader,args[i],env),new Object[0]);if(!Boolean.TRUE.equals(v[0])){
                System.out.println("ERROR chunk="+args[i]);for(int j=1;j<v.length;j++)System.out.println(v[j]);System.exit(1);
            }
        }
    }
}
