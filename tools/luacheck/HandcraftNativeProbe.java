import java.io.Reader;
import java.lang.reflect.Field;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.*;
import sun.misc.Unsafe;
import zombie.characters.IsoGameCharacter;
import zombie.characters.IsoPlayer;
import zombie.characters.PlayerCraftHistory;
import zombie.characters.skills.PerkFactory;
import zombie.entity.components.crafting.recipe.HandcraftLogic;
import zombie.inventory.InventoryItem;
import zombie.inventory.ItemContainer;
import zombie.scripting.ScriptLoadMode;
import zombie.scripting.ScriptManager;
import zombie.scripting.entity.components.crafting.CraftRecipe;
import zombie.scripting.entity.components.crafting.InputScript;
import zombie.scripting.objects.Item;
import zombie.scripting.objects.ScriptModule;

/** Native recipe/parser/material effects and installed Lua VM; no attached game. */
public final class HandcraftNativeProbe {
    private static ScriptModule module;
    private static CraftRecipe recipe;
    private static Receiver actor;
    private static HandcraftLogic logic;
    private static InventoryItem log, saw, floorLog;
    private static ItemContainer alternateFloor;
    private static final HashMap<Integer, InventoryItem> items = new HashMap<>();
    private static final ArrayList<InventoryItem> outputs = new ArrayList<>();
    private static Unsafe unsafe() throws Exception {
        Field f=Unsafe.class.getDeclaredField("theUnsafe"); f.setAccessible(true); return (Unsafe)f.get(null);
    }
    // The actor is unattached. Skills and XP receivers are controlled while
    // recipe parsing, selection, consumption, output construction and use run natively.
    public static class Receiver extends IsoPlayer {
        ItemContainer inventory; PlayerCraftHistory history; IsoGameCharacter.XP xp;
        public Receiver() { super((zombie.iso.IsoCell)null); }
        @Override public ItemContainer getInventory() { return inventory; }
        @Override public int getPerkLevel(PerkFactory.Perk p) { return 0; }
        @Override public boolean isRecipeKnown(CraftRecipe r, boolean ignore) { return !r.needToBeLearn(); }
        @Override public PlayerCraftHistory getPlayerCraftHistory() { return history; }
        @Override public IsoGameCharacter.XP getXp() { return xp; }
        @Override public boolean isEquipped(InventoryItem item) { return false; }
        @Override public boolean isEquippedClothing(InventoryItem item) { return false; }
        @Override public boolean isLocalPlayer() { return false; }
    }
    public static class XpReceiver extends IsoGameCharacter.XP {
        XpReceiver(Receiver a) { a.super(a); }
        @Override public void AddXP(PerkFactory.Perk p,float amount,boolean a,boolean b,boolean c,boolean d) {}
    }
    private static String block(Path path,String type,String name) throws Exception {
        String source=Files.readString(path), needle=type+" "+name;
        java.util.regex.Matcher match=java.util.regex.Pattern.compile("(?m)^\\s*"+type+"\\s+"+java.util.regex.Pattern.quote(name)+"\\s*\\{").matcher(source);
        if(!match.find())throw new IllegalStateException("missing native block "+needle);
        int start=match.start(), brace=source.indexOf('{',start), depth=1, end=brace+1;
        while(depth>0 && end<source.length()) { char c=source.charAt(end++); if(c=='{')depth++;if(c=='}')depth--; }
        return source.substring(start,end);
    }
    private static void initialise(Path game) throws Exception {
        zombie.core.random.RandStandard.INSTANCE.init(); PerkFactory.init();zombie.entity.components.attributes.Attribute.init();
        zombie.network.GameServer.server=true; // Headless item-script/texture preparation only.
        Field loadMod=ScriptManager.class.getDeclaredField("currentLoadFileMod");loadMod.setAccessible(true);loadMod.set(null,"pz-vanilla");
        module=new ScriptModule();module.name="Base";ScriptManager.instance.moduleMap.put("Base",module);
        ScriptManager.instance.moduleList.add(module);
        for(Field field:ScriptManager.class.getDeclaredFields())if(zombie.scripting.ScriptBucketCollection.class.isAssignableFrom(field.getType())){
            field.setAccessible(true);((zombie.scripting.ScriptBucketCollection<?>)field.get(ScriptManager.instance)).registerModule(module);
        }
        for(String name:List.of("Log","Saw","Plank")) {
            Path p=game.resolve("media/scripts/generated/items/"+(name.equals("Plank")?"weapon":"normal")+".txt");
            // Research UI links require unrelated recipes; they do not supply
            // material/type/tag/condition fields used by this exact recipe.
            String definition=block(p,"item",name).replaceAll("(?im)^\\s*Researchablerecipes\\s*=.*$","");
            Item item=new Item();item.setModule(module);item.setModID("pz-vanilla");item.InitLoadPP(name);item.Load(name,definition);
            item.setDisplayName(name); // Controlled translation receiver, no language bootstrap.
            module.items.getScriptMap().put(name,item);
        }
        recipe=new CraftRecipe();recipe.setModule(module);recipe.InitLoadPP("SawLogs");
        zombie.scripting.objects.TimedActionScript timed=new zombie.scripting.objects.TimedActionScript();timed.setModule(module);timed.InitLoadPP("SawLogs");
        timed.Load("SawLogs",block(game.resolve("media/scripts/generated/timedactions.txt"),"timedAction","SawLogs"));
        module.timedActionScripts.getScriptMap().put("SawLogs",timed);
        recipe.Load("SawLogs",block(game.resolve("media/scripts/generated/recipes/recipes_carpentry.txt"),"craftRecipe","SawLogs"));
        module.craftRecipes.getScriptMap().put("SawLogs",recipe);
        for(Field field:ScriptManager.class.getDeclaredFields())if(zombie.scripting.ScriptBucketCollection.class.isAssignableFrom(field.getType())){
            field.setAccessible(true);zombie.scripting.ScriptBucketCollection collection=(zombie.scripting.ScriptBucketCollection)field.get(ScriptManager.instance);
            zombie.scripting.ScriptBucket bucket=collection.getBucketFromModule(module);
            for(Object v:bucket.getScriptMap().values()){
                zombie.scripting.objects.BaseScriptObject script=(zombie.scripting.objects.BaseScriptObject)v;
                collection.getFullTypeToScriptMap().put(script.getScriptObjectFullType(),script);
                if(!bucket.getScriptList().contains(script))bucket.getScriptList().add(script);
                if(!collection.getAllScripts().contains(script))collection.getAllScripts().add(script);
            }
        }
        recipe.OnScriptsLoaded(ScriptLoadMode.Init);
        zombie.inventory.ItemTags.Init(ScriptManager.instance.getAllItems());
        recipe.OnPostWorldDictionaryInit();
        if(recipe.getInputs().size()!=2 || recipe.getOutputs().size()!=1 || recipe.getOutputs().get(0).getIntAmount()!=3)
            throw new IllegalStateException("native SawLogs shape changed");
        zombie.network.GameServer.server=false;
    }
    private static void reset() throws Exception {
        actor=(Receiver)unsafe().allocateInstance(Receiver.class);
        actor.inventory=new ItemContainer();actor.history=new PlayerCraftHistory(actor);actor.xp=new XpReceiver(actor);
        // Initialise no map/world/renderer; the native floor refresh handles null square.
        actor.inventory.setType("inventory");
        zombie.network.GameServer.server=true;
        log=module.getItem("Log").InstanceItem(null);log.setID(701);
        saw=module.getItem("Saw").InstanceItem(null);saw.setID(702);saw.setConditionNoSound(10);
        actor.inventory.AddItemBlind(log);actor.inventory.AddItemBlind(saw);
        log.setContainer(actor.inventory);saw.setContainer(actor.inventory);
        items.clear();items.put(701,log);items.put(702,saw);outputs.clear();logic=null;alternateFloor=null;floorLog=null;
        zombie.network.GameServer.server=false;
    }
    private static void select() {
        logic=new HandcraftLogic(actor,null,null);
        ArrayList<ItemContainer> containers=new ArrayList<>();containers.add(actor.inventory);
        if(alternateFloor!=null)containers.add(alternateFloor);
        logic.setContainers(containers);logic.setRecipe(recipe);logic.setManualSelectInputs(true);logic.clearManualInputs();
        for(InputScript input:recipe.getInputs()) {
            ArrayList<InventoryItem> selected=new ArrayList<>();selected.add(input.isKeep()?saw:log);
            if(!logic.setManualInputsFor(input,selected))throw new IllegalStateException("native manual inputs refused: "+input.isKeep()
                +" io="+recipe.containsIO(input)+" item="+selected.get(0).getFullType()+" container="+selected.get(0).getContainer()
                +" possible="+input.getPossibleInputItems()+" script="+selected.get(0).getScriptItem()
                +" match="+zombie.entity.components.crafting.recipe.CraftRecipeManager.getValidInputScriptForItem(recipe,selected.get(0),actor));
        }
    }
    private static Object operation(String op,Object value) throws Exception {
        switch(op) {
            case "reset": reset();return true;
            case "addFloorLog":
                zombie.network.GameServer.server=true;floorLog=module.getItem("Log").InstanceItem(null);floorLog.setID(703);
                zombie.network.GameServer.server=false;alternateFloor=new ItemContainer();alternateFloor.setType("floor");
                alternateFloor.AddItemBlind(floorLog);floorLog.setContainer(alternateFloor);return true;
            case "floorLogHeld": return alternateFloor!=null && alternateFloor.contains(floorLog) && floorLog.getCurrentUses()==1;
            case "eligible": select();return logic.canPerformCurrentRecipe();
            case "perform":
                if(logic==null)select();if(!logic.performCurrentRecipe())return false;
                logic.getCreatedOutputItems(outputs);
                for(InventoryItem item:outputs){ actor.inventory.AddItemBlind(item);item.setContainer(actor.inventory);items.put(item.getID(),item); }
                logic.getRecipeData().luaCallOnCreate(actor);
                logic.getRecipeData().processDestroyAndUsedItems(actor);
                return true;
            case "count": return outputs.size();
            case "outputId": return Integer.toString(outputs.get(((Number)value).intValue()).getID());
            case "outputType": return outputs.get(((Number)value).intValue()).getFullType();
            case "logUses": return log.getCurrentUses();
            case "logHeld": return actor.inventory.contains(log);
            case "sawCondition": return saw.getCondition();
            case "sawHeld": return actor.inventory.contains(saw);
            case "recordedLog": return logic.getRecipeData().getAllRecordedConsumedItems().contains(log);
            case "consumedLog": return logic.getRecipeData().getAllConsumedItems().contains(log);
            case "consumedDetail": return "recorded="+logic.getRecipeData().getAllRecordedConsumedItems()+" actual="+logic.getRecipeData().getAllConsumedItems();
            case "createdCount": return logic.getRecipeData().getAllCreatedItems().size();
            case "recipeTime": return recipe.getTime(actor);
            case "recipeInputs": return recipe.getInputs().size();
            case "recipeLearned": return !recipe.needToBeLearn();
            default: throw new IllegalArgumentException(op);
        }
    }
    public static void main(String[] args) throws Exception {
        J2SEPlatform platform=new J2SEPlatform();KahluaTable env=platform.newEnvironment();
        KahluaThread thread=new KahluaThread(platform,env);thread.debugOwnerThread=Thread.currentThread();
        zombie.Lua.LuaManager.env=env;zombie.Lua.LuaManager.thread=thread;
        zombie.Lua.LuaManager.caller=new se.krka.kahlua.integration.LuaCaller(new se.krka.kahlua.converter.KahluaConverterManager());
        env.rawset("print",new JavaFunction(){public int call(LuaCallFrame frame,int n){
            for(int i=0;i<n;i++)System.out.print((i==0?"":"\t")+String.valueOf(frame.get(i)));
            System.out.println();return 0;
        }});
        thread.call(LuaCompiler.loadstring("ISTimedActionQueue={queues={},getTimedActionQueue=function() return {queue={}} end}","native-empty-queue",env),null,null,null);
        initialise(Path.of(args[0]));
        if(args.length==1){reset();select();System.out.println("native_can_perform="+logic.canPerformCurrentRecipe());
            System.out.println("native_perform="+operation("perform",null));
            System.out.println("native_outputs="+outputs.size()+" log_held="+actor.inventory.contains(log)+" saw_held="+actor.inventory.contains(saw));return;}
        env.rawset("__nativeCraft",new JavaFunction(){public int call(LuaCallFrame frame,int n){
            try{Object result=operation((String)frame.get(0),n>1?frame.get(1):null);
                return frame.push(result instanceof Number ? ((Number)result).doubleValue() : result);}
            catch(Exception e){e.printStackTrace();throw new IllegalStateException(e);}
        }});
        env.rawset("__nativeRoundtrip",new JavaFunction(){public int call(LuaCallFrame frame,int n){
            try{ByteBuffer bytes=ByteBuffer.allocate(1048576);((KahluaTable)frame.get(0)).save(bytes);bytes.flip();
                KahluaTable restored=platform.newTable();restored.load(bytes,zombie.iso.IsoWorld.WorldVersion);
                if(bytes.hasRemaining())throw new IllegalStateException("unconsumed save bytes");return frame.push(restored);
            }catch(Exception e){throw new IllegalStateException(e);}
        }});
        Path production=null;
        for(String argument:args)if(Path.of(argument).getFileName().toString().equals("production.lua"))production=Path.of(argument);
        final Path reloadSource=production;
        env.rawset("__reloadProduction",new JavaFunction(){public int call(LuaCallFrame frame,int n){
            try(Reader reader=Files.newBufferedReader(reloadSource,StandardCharsets.UTF_8)){
                Object[] returned=thread.pcall(LuaCompiler.loadis(reader,"production-reload",env),new Object[0]);
                if(!Boolean.TRUE.equals(returned[0]))throw new IllegalStateException(java.util.Arrays.toString(returned));
                return frame.push(true);
            }catch(Exception e){throw new IllegalStateException(e);}
        }});
        for(int i=1;i<args.length;i++)try(Reader reader=Files.newBufferedReader(Path.of(args[i]),StandardCharsets.UTF_8)){
            Object[] returned=thread.pcall(LuaCompiler.loadis(reader,args[i],env),new Object[0]);
            if(!Boolean.TRUE.equals(returned[0])){System.out.println("ERROR chunk="+args[i]);
                for(int j=1;j<returned.length;j++)System.out.println(returned[j]);System.exit(1);}
        }
        System.out.println("VALUE "+thread.call(LuaCompiler.loadstring("return __windowResults","results",env),null,null,null));
    }
}
