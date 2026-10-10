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
public final class NativeToolRepairProbe {
    private static ScriptModule module;
    private static CraftRecipe recipe;
    private static final HashMap<String,CraftRecipe> recipes=new HashMap<>();
    private static Receiver actor;
    private static HandcraftLogic logic;
    private static InventoryItem target, tool, floorTarget;
    private static ItemContainer alternateFloor;
    private static final HashMap<Integer, InventoryItem> items = new HashMap<>();
    private static final ArrayList<InventoryItem> outputs = new ArrayList<>();
    private static int skill=2, callbacks;
    private static Unsafe unsafe() throws Exception {
        Field f=Unsafe.class.getDeclaredField("theUnsafe"); f.setAccessible(true); return (Unsafe)f.get(null);
    }
    // The actor is unattached. Skills and XP receivers are controlled while
    // recipe parsing, selection, consumption, output construction and use run natively.
    public static class Receiver extends IsoPlayer {
        ItemContainer inventory; PlayerCraftHistory history; IsoGameCharacter.XP xp;
        public Receiver() { super((zombie.iso.IsoCell)null); }
        @Override public ItemContainer getInventory() { return inventory; }
        @Override public int getPerkLevel(PerkFactory.Perk p) { return skill; }
        @Override public int getWeaponLevel() { return 0; }
        @Override public int getWeaponLevel(zombie.inventory.types.HandWeapon weapon) { return 0; }
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
        for(String name:List.of("Saw","File","SmallSaw","HacksawBlade","KitchenKnife","HandAxe","Whetstone","CrudeWhetstone")) {
            Path p=game.resolve("media/scripts/generated/items/"+(List.of("File","KitchenKnife","HandAxe").contains(name)?"weapon":"normal")+".txt");
            // Research UI links require unrelated recipes; they do not supply
            // material/type/tag/condition fields used by this exact recipe.
            String definition=block(p,"item",name).replaceAll("(?im)^\\s*Researchablerecipes\\s*=.*$","");
            Item item=new Item();item.setModule(module);item.setModID("pz-vanilla");item.InitLoadPP(name);item.Load(name,definition);
            item.setDisplayName(name); // Controlled translation receiver, no language bootstrap.
            module.items.getScriptMap().put(name,item);
        }
        zombie.scripting.objects.TimedActionScript timed=new zombie.scripting.objects.TimedActionScript();timed.setModule(module);timed.InitLoadPP("SharpenBlade");
        timed.Load("SharpenBlade",block(game.resolve("media/scripts/generated/timedactions.txt"),"timedAction","SharpenBlade"));
        module.timedActionScripts.getScriptMap().put("SharpenBlade",timed);
        for(String name:List.of("FixSaw","SharpenBlade","SharpenBladePoorlyWithFile")) {
            CraftRecipe loaded=new CraftRecipe();loaded.setModule(module);loaded.InitLoadPP(name);
            loaded.Load(name,block(game.resolve("media/scripts/generated/recipes/recipes_fixing.txt"),"craftRecipe",name));
            module.craftRecipes.getScriptMap().put(name,loaded);recipes.put("Base."+name,loaded);
        }
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
        for(CraftRecipe loaded:recipes.values())loaded.OnScriptsLoaded(ScriptLoadMode.Init);
        zombie.inventory.ItemTags.Init(ScriptManager.instance.getAllItems());
        for(CraftRecipe loaded:recipes.values()) {
            loaded.OnPostWorldDictionaryInit();
            if(loaded.getInputs().size()!=2 || loaded.getOutputs().size()!=0)throw new IllegalStateException("native maintenance shape changed");
        }
        recipe=recipes.get("Base.FixSaw");
        zombie.network.GameServer.server=false;
    }
    private static void reset() throws Exception {
        recipe=recipes.get("Base.FixSaw");
        actor=(Receiver)unsafe().allocateInstance(Receiver.class);
        actor.inventory=new ItemContainer();actor.history=new PlayerCraftHistory(actor);actor.xp=new XpReceiver(actor);
        // Initialise no map/world/renderer; the native floor refresh handles null square.
        actor.inventory.setType("inventory");
        module.getItem("File").setConditionLowerChance(15);
        zombie.network.GameServer.server=true;
        target=module.getItem("Saw").InstanceItem(null);target.setID(701);target.setConditionNoSound(2);target.setHaveBeenRepaired(3);
        tool=module.getItem("File").InstanceItem(null);tool.setID(702);tool.setConditionNoSound(8);
        actor.inventory.AddItemBlind(target);actor.inventory.AddItemBlind(tool);
        target.setContainer(actor.inventory);tool.setContainer(actor.inventory);
        items.clear();items.put(701,target);items.put(702,tool);outputs.clear();logic=null;alternateFloor=null;floorTarget=null;skill=2;callbacks=0;
        zombie.network.GameServer.server=false;
    }
    private static void select() {
        logic=new HandcraftLogic(actor,null,null);
        ArrayList<ItemContainer> containers=new ArrayList<>();containers.add(actor.inventory);
        if(alternateFloor!=null)containers.add(alternateFloor);
        logic.setContainers(containers);logic.setRecipe(recipe);logic.setManualSelectInputs(true);logic.clearManualInputs();
        for(InputScript input:recipe.getInputs()) {
            ArrayList<InventoryItem> selected=new ArrayList<>();selected.add(input.isDamaged() || input.isSharpenable()?target:tool);
            if(!logic.setManualInputsFor(input,selected))throw new IllegalStateException("native manual inputs refused: "+input.isKeep()
                +" io="+recipe.containsIO(input)+" item="+selected.get(0).getFullType()+" container="+selected.get(0).getContainer()
                +" possible="+input.getPossibleInputItems()+" script="+selected.get(0).getScriptItem()
                +" match="+zombie.entity.components.crafting.recipe.CraftRecipeManager.getValidInputScriptForItem(recipe,selected.get(0),actor));
        }
    }
    private static Object operation(String op,Object value) throws Exception {
        switch(op) {
            case "reset": reset();return true;
            case "recipe": recipe=recipes.get((String)value);if(recipe==null)throw new IllegalArgumentException("unsupported recipe");logic=null;return true;
            case "targetType":
                actor.inventory.Remove(target);zombie.network.GameServer.server=true;
                target=module.getItem((String)value).InstanceItem(null);target.setID(701);
                target.setConditionNoSound(target.getConditionMax());target.setHaveBeenRepaired(3);
                if(target.hasSharpness())target.setSharpness(0);
                actor.inventory.AddItemBlind(target);target.setContainer(actor.inventory);items.put(701,target);
                zombie.network.GameServer.server=false;logic=null;return true;
            case "toolType":
                actor.inventory.Remove(tool);zombie.network.GameServer.server=true;
                tool=module.getItem((String)value).InstanceItem(null);tool.setID(702);tool.setConditionNoSound(Math.min(8,tool.getConditionMax()));
                actor.inventory.AddItemBlind(tool);tool.setContainer(actor.inventory);items.put(702,tool);
                zombie.network.GameServer.server=false;logic=null;return true;
            case "seed":
                Field randomField=zombie.core.random.RandAbstract.class.getDeclaredField("rand");randomField.setAccessible(true);
                // The installed generator keeps its cell state independently of Random.setSeed.
                // Reconstruct the same native four-byte-seeded generator for a repeatable receiver.
                randomField.set(zombie.core.random.RandStandard.INSTANCE,new org.uncommons.maths.random.CellularAutomatonRNG(
                    ByteBuffer.allocate(4).putInt(((Number)value).intValue()).array()));return true;
            case "addFloorTarget":
                zombie.network.GameServer.server=true;floorTarget=module.getItem("Saw").InstanceItem(null);floorTarget.setID(703);floorTarget.setConditionNoSound(1);
                zombie.network.GameServer.server=false;alternateFloor=new ItemContainer();alternateFloor.setType("floor");
                alternateFloor.AddItemBlind(floorTarget);floorTarget.setContainer(alternateFloor);return true;
            case "floorTargetUntouched": return alternateFloor!=null && alternateFloor.contains(floorTarget) && floorTarget.getCondition()==1;
            case "skill": skill=((Number)value).intValue();return skill;
            case "requiredSkill": return recipe.getRequiredSkillCount()==0 || zombie.entity.components.crafting.recipe.CraftRecipeManager.hasPlayerRequiredSkill(recipe.getRequiredSkill(0),actor);
            case "requiredSkillCount": return recipe.getRequiredSkillCount();
            case "setSharpness": target.setSharpness(((Number)value).floatValue());return target.getSharpness();
            case "setTargetCondition": target.setConditionNoSound(((Number)value).intValue());return target.getCondition();
            case "setToolCondition": tool.setConditionNoSound(((Number)value).intValue());return tool.getCondition();
            case "setToolWearChance": ((zombie.inventory.types.HandWeapon)tool).setConditionLowerChance(((Number)value).intValue());return true;
            case "eligible": select();return logic.canPerformCurrentRecipe();
            case "perform":
                if(logic==null)select();if(!logic.performCurrentRecipe())return false;
                logic.getCreatedOutputItems(outputs);return true;
            case "onCreate":
                callbacks++;
                logic.getRecipeData().luaCallOnCreate(actor);return true;
            case "process": logic.getRecipeData().processDestroyAndUsedItems(actor);return true;
            case "condition": return target.getCondition();
            case "maxCondition": return target.getConditionMax();
            case "toolMaxCondition": return tool.getConditionMax();
            case "hasSharpness": return target.hasSharpness();
            case "sharpness": return target.getSharpness();
            case "maxSharpness": return target.getMaxSharpness();
            case "isSharpenable": return target.isSharpenable();
            case "hasHeadCondition": return target.hasHeadCondition();
            case "headCondition": return target.getHeadCondition();
            case "maxHeadCondition": return target.getHeadConditionMax();
            case "repairCount": return target.getHaveBeenRepaired();
            case "toolCondition": return tool.getCondition();
            case "targetHeld": return actor.inventory.contains(target);
            case "toolHeld": return actor.inventory.contains(tool);
            case "consumedTarget": return logic.getRecipeData().getAllConsumedItems().contains(target);
            case "consumedTool": return logic.getRecipeData().getAllConsumedItems().contains(tool);
            case "keptExact": return logic.getRecipeData().getAllKeepInputItems().size()==2 && logic.getRecipeData().getAllKeepInputItems().contains(target) && logic.getRecipeData().getAllKeepInputItems().contains(tool);
            case "createdCount": return logic.getRecipeData().getAllCreatedItems().size();
            case "count": return outputs.size();
            case "callbacks": return callbacks;
            case "recipeTime": return recipe.getTime(actor);
            case "actionMetabolics": return String.valueOf(recipe.getTimedActionScript().getMetabolics());
            case "actionAnim": return recipe.getTimedActionScript().getActionAnim();
            case "actionSound": return recipe.getTimedActionScript().getSound();
            case "actionSoundTime": return String.valueOf(recipe.getTimedActionScript().getSoundTime());
            case "actionHasMuscleStrain": return recipe.getTimedActionScript().hasMuscleStrain();
            case "actionCantSit": return recipe.getTimedActionScript().isCantSit();
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
        KahluaTable onCreate=platform.newTable();
        onCreate.rawset("sharpenBlade",new JavaFunction(){public int call(LuaCallFrame frame,int n){
            zombie.scripting.logic.RecipeCodeOnCreate.sharpenBlade((zombie.entity.components.crafting.recipe.CraftRecipeData)frame.get(0),(IsoGameCharacter)frame.get(1));return 0;
        }});env.rawset("RecipeCodeOnCreate",onCreate);

        env.rawset("print",new JavaFunction(){public int call(LuaCallFrame frame,int n){
            for(int i=0;i<n;i++)System.out.print((i==0?"":"\t")+String.valueOf(frame.get(i)));
            System.out.println();return 0;
        }});
        thread.call(LuaCompiler.loadstring("ISTimedActionQueue={queues={},getTimedActionQueue=function() return {queue={}} end}","native-empty-queue",env),null,null,null);
        initialise(Path.of(args[0]));
        if(args.length==1){reset();select();System.out.println("native_can_perform="+logic.canPerformCurrentRecipe());
            System.out.println("native_perform="+operation("perform",null));
            operation("onCreate",null);operation("process",null);System.out.println("native_condition="+target.getCondition()+" file_condition="+tool.getCondition()+" repair_count="+target.getHaveBeenRepaired());return;}
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
