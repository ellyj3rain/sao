import java.lang.reflect.Field;
import java.nio.ByteBuffer;
import java.nio.file.*;
import java.util.*;
import java.util.regex.*;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.*;
import sun.misc.Unsafe;
import zombie.Lua.LuaManager;
import zombie.characters.*;
import zombie.characters.skills.PerkFactory;
import zombie.entity.ComponentType;
import zombie.entity.components.crafting.CraftBench;
import zombie.entity.components.crafting.recipe.*;
import zombie.inventory.*;
import zombie.scripting.*;
import zombie.scripting.entity.GameEntityScript;
import zombie.scripting.entity.components.crafting.*;
import zombie.scripting.objects.*;

/** Actual registered metadata/items/selection/serialization, controlled unattached
 * actor knowledge/skills and station geometry/custody. No craft effects/game. */
public final class RecipePolicyNativeProbe {
    static ScriptModule module;
    static KahluaTable env;
    static J2SEPlatform platform;
    static Receiver body;
    static int itemId;
    static Unsafe unsafe() throws Exception {
        Field f=Unsafe.class.getDeclaredField("theUnsafe");f.setAccessible(true);return (Unsafe)f.get(null);
    }
    static <T> T construct(Class<T> type) throws Exception {
        var c=type.getDeclaredConstructor();c.setAccessible(true);return c.newInstance();
    }
    static String json(Object value) {
        if(value==null)return "null";
        if(value instanceof String s)return "\""+s.replace("\\","\\\\").replace("\"","\\\"").replace("\n","\\n").replace("\r","\\r").replace("\t","\\t")+"\"";
        if(value instanceof Number || value instanceof Boolean)return value.toString();
        if(value instanceof KahluaTable t && t.getMetatable()==null){
            List<String> entries=new ArrayList<>();var it=t.iterator();while(it.advance())entries.add(json(String.valueOf(it.getKey()))+":"+json(it.getValue()));
            Collections.sort(entries);return "{"+String.join(",",entries)+"}";
        }
        throw new AssertionError("nonplain projection "+value.getClass());
    }
    public static class Receiver extends IsoPlayer {
        ItemContainer inventory; PlayerCraftHistory history;
        public int skill=10; public boolean learned=true;
        public Receiver(){super((zombie.iso.IsoCell)null);}
        @Override public ItemContainer getInventory(){return inventory;}
        @Override public int getPerkLevel(PerkFactory.Perk p){return skill;}
        @Override public boolean isRecipeKnown(CraftRecipe r,boolean ignored){return learned;}
        @Override public PlayerCraftHistory getPlayerCraftHistory(){return history;}
        @Override public boolean isEquipped(InventoryItem item){return false;}
        @Override public boolean isEquippedClothing(InventoryItem item){return false;}
        @Override public boolean isLocalPlayer(){return false;}
        public void setSkill(int n){skill=n;}
        public void setLearned(boolean b){learned=b;}
    }
    public static class Station extends zombie.iso.IsoObject {
        public boolean custody=true; public GameEntityScript definition;
        public zombie.iso.IsoGridSquare square;
        public Station(){super((zombie.iso.IsoCell)null);}
        @Override public boolean isUsingPlayer(IsoPlayer actor){return custody;}
        @Override public GameEntityScript getEntityScript(){return definition;}
        @Override public zombie.iso.IsoGridSquare getSquare(){return square;}
        public void setCustody(boolean b){custody=b;}
        public void setFar(boolean b){square=new zombie.iso.IsoGridSquare(null,null,b?20:0,0,0);}
    }
    static String block(String source,String type,String name) {
        source=ScriptParser.stripComments(source);
        Matcher m=Pattern.compile("(?m)^\\s*"+type+"\\s+"+Pattern.quote(name)+"\\s*\\{").matcher(source);
        if(!m.find())throw new IllegalArgumentException("missing "+type+" "+name);
        int depth=1,end=m.end();while(depth>0){char c=source.charAt(end++);if(c=='{')depth++;if(c=='}')depth--;}
        return source.substring(m.start(),end);
    }
    static void register() throws Exception {
        for(Field f:ScriptManager.class.getDeclaredFields())if(ScriptBucketCollection.class.isAssignableFrom(f.getType())){
            f.setAccessible(true);ScriptBucketCollection c=(ScriptBucketCollection)f.get(ScriptManager.instance);
            var bucket=c.getBucketFromModule(module);
            for(Object value:bucket.getScriptMap().values()){
                BaseScriptObject s=(BaseScriptObject)value;
                c.getFullTypeToScriptMap().put(s.getScriptObjectFullType(),s);
                if(!bucket.getScriptList().contains(s))bucket.getScriptList().add(s);
                if(!c.getAllScripts().contains(s))c.getAllScripts().add(s);
            }
        }
    }
    static void loadRecipe(Path path,String name) throws Exception {
        String source=block(Files.readString(path),"craftRecipe",name);
        // Native timed-action geometry/animation is outside this read-only helper.
        // Keep native fields by loading exact timedAction blocks where available.
        CraftRecipe r=new CraftRecipe();r.setModule(module);r.InitLoadPP(name);r.Load(name,source);
        module.craftRecipes.getScriptMap().put(name,r);
    }
    static void initialise(Path game) throws Exception {
        zombie.core.random.RandStandard.INSTANCE.init();PerkFactory.init();zombie.entity.components.attributes.Attribute.init();
        zombie.network.GameServer.server=true;
        Field mod=ScriptManager.class.getDeclaredField("currentLoadFileMod");mod.setAccessible(true);mod.set(null,"pz-vanilla");
        module=new ScriptModule();module.name="Base";ScriptManager.instance.moduleMap.put("Base",module);ScriptManager.instance.moduleList.add(module);
        for(Field f:ScriptManager.class.getDeclaredFields())if(ScriptBucketCollection.class.isAssignableFrom(f.getType())){
            f.setAccessible(true);((ScriptBucketCollection<?>)f.get(ScriptManager.instance)).registerModule(module);
        }
        Set<String> wanted=new HashSet<>(List.of("Log","Saw","Plank","File","HacksawBlade","SmallSaw","SmallSawblade",
            "Stone2","CrudeWhetstone","Whetstone","Scissors","Epoxy","FiberglassTape","DuctTape","Scotchtape",
            "Glue","Woodglue","Zipties","RippedSheets","DenimStrips","BlowTorch","PropaneTank",
            "Hammer","Morningstar_Scrap_Short","KitchenKnife",
            "Bullets9mmBox","Bullets45Box","Bullets38Box","Bullets357Box","Bullets9mm","Bullets45","Bullets38","Bullets357"));
        try(var paths=Files.walk(game.resolve("media/scripts/generated/items"))){
            for(Path path:paths.filter(p->p.toString().endsWith(".txt")).sorted().toList()){
                String source=Files.readString(path);
                for(String name:new ArrayList<>(wanted))if(Pattern.compile("(?m)^\\s*item\\s+"+Pattern.quote(name)+"\\s*\\{").matcher(source).find()){
                    String definition=block(source,"item",name).replaceAll("(?im)^\\s*Researchablerecipes\\s*=.*$","");
                    Item item=new Item();item.setModule(module);item.setModID("pz-vanilla");item.InitLoadPP(name);item.Load(name,definition);
                    item.setDisplayName(name);module.items.getScriptMap().put(name,item);wanted.remove(name);
                    System.out.println("SOURCE "+path+" item="+name);
                }
            }
        }
        if(!wanted.isEmpty())throw new AssertionError("missing native items "+wanted);
        for(String type:List.of("fluid","energy")){
            String source=Files.readString(game.resolve("media/scripts/generated/"+(type.equals("fluid")?"fluids":"energies")+".txt"));
            Matcher entries=Pattern.compile("(?m)^\\s*"+type+"\\s+(\\w+)\\s*\\{").matcher(source);
            while(entries.find()){
                String name=entries.group(1);
                if(type.equals("fluid")){
                    FluidDefinitionScript s=construct(FluidDefinitionScript.class);s.setModule(module);s.InitLoadPP(name);s.Load(name,block(source,type,name));
                    module.fluidDefinitionScripts.getScriptMap().put(name,s);
                }else{
                    EnergyDefinitionScript s=construct(EnergyDefinitionScript.class);s.setModule(module);s.InitLoadPP(name);s.Load(name,block(source,type,name));
                    module.energyDefinitionScripts.getScriptMap().put(name,s);
                }
            }
        }
        Path recipes=game.resolve("media/scripts/generated/recipes");
        for(String name:List.of("FixWithDuctTape","FixWithAdhesiveTape","FixWithZipties","FixWithGlue","FixWithWoodGlue",
            "FixWithEpoxy","FixWithEpoxyAndRags","SharpenBlade","SharpenBladePoorlyWithFile","SharpenBladeWithGrindstone","MakeCrudeWhetstone","FixSaw"))
            loadRecipe(recipes.resolve("recipes_fixing.txt"),name);
        for(String name:List.of("ReplaceHacksawBlade","ReplaceSmallSawBlade"))loadRecipe(recipes.resolve("recipes.txt"),name);
        loadRecipe(recipes.resolve("recipes_carpentry.txt"),"SawLogs");
        loadRecipe(recipes.resolve("recipes_metalWelding.txt"),"RefillBlowTorch");
        loadRecipe(recipes.resolve("recipes_ammunition.txt"),"OpenBoxOfBullets50");
        String timedSource=Files.readString(game.resolve("media/scripts/generated/timedactions.txt"));
        Matcher names=Pattern.compile("(?m)^\\s*timedAction\\s+(\\w+)\\s*\\{").matcher(timedSource);
        while(names.find()){
            String name=names.group(1);TimedActionScript timed=new TimedActionScript();timed.setModule(module);timed.InitLoadPP(name);
            timed.Load(name,block(timedSource,"timedAction",name));module.timedActionScripts.getScriptMap().put(name,timed);
        }
        // Additional controlled channel declarations use the native parser and
        // registry. They are instrument cases, not shipped recipes or knowledge.
        for(String[] pair:new String[][]{{"PolicyFluid","fluid 2 [Water],"},{"PolicyEnergy","energy 3 [Electric],"},
            {"PolicyVariable","item variable[1:3] [Base.Log],"},{"PolicyOverlap","item 1 [Base.Log], item 1 [Base.Log],"}}){
            CraftRecipe r=new CraftRecipe();r.setModule(module);r.InitLoadPP(pair[0]);
            r.Load(pair[0],"craftRecipe "+pair[0]+" { Tags = InHandCraft, inputs { "+pair[1]+" } }");
            module.craftRecipes.getScriptMap().put(pair[0],r);
        }
        register();
        zombie.entity.components.fluids.Fluid.Init(ScriptLoadMode.Init);
        zombie.entity.energy.Energy.Init(ScriptLoadMode.Init);
        for(CraftRecipe r:module.craftRecipes.getScriptList())r.OnScriptsLoaded(ScriptLoadMode.Init);
        zombie.inventory.ItemTags.Init(ScriptManager.instance.getAllItems());
        for(CraftRecipe r:module.craftRecipes.getScriptList())r.OnPostWorldDictionaryInit();
        zombie.entity.components.crafting.recipe.CraftRecipeManager.Init();
        zombie.network.GameServer.server=false;
    }
    static InventoryItem item(String name) {
        zombie.network.GameServer.server=true;
        InventoryItem item=module.getItem(name).InstanceItem(null);item.setID(++itemId);
        if(item instanceof zombie.inventory.types.DrainableComboItem)item.setCurrentUses(4);
        body.inventory.AddItemBlind(item);item.setContainer(body.inventory);
        zombie.network.GameServer.server=false;return item;
    }
    static KahluaTable reset(String kind) throws Exception {
        body=(Receiver)unsafe().allocateInstance(Receiver.class);body.skill=10;body.learned=true;
        body.inventory=new ItemContainer();body.inventory.setType("inventory");body.history=new PlayerCraftHistory(body);itemId=900;
        KahluaTable row=platform.newTable(),items=platform.newTable();row.rawset("body",body);row.rawset("items",items);
        var containers=new ArrayList<ItemContainer>();containers.add(body.inventory);row.rawset("containers",containers);
        for(String name:switch(kind){
            case "saw" -> List.of("Log","Saw");
            case "fix" -> List.of("Saw","File");
            case "tape", "tape-two" -> List.of("Hammer","DuctTape");
            case "epoxy" -> List.of("Scissors","Hammer","Epoxy","FiberglassTape");
            case "replace" -> List.of("Saw","HacksawBlade");
            case "refuel" -> List.of("BlowTorch","PropaneTank");
            case "grind" -> List.of("Scissors");
            case "stone" -> List.of("Stone2");
            default -> List.<String>of();
        })items.rawset(name,item(name));
        for(String name:List.of("Saw","Hammer","Scissors"))if(items.rawget(name) instanceof InventoryItem i){i.setConditionNoSound(Math.max(1,i.getConditionMax()/2));if(!kind.equals("epoxy"))i.setSharpness(0.1f);}
        if(items.rawget("BlowTorch") instanceof InventoryItem i)i.setCurrentUses(0);
        if(kind.equals("tape-two")){
            ((InventoryItem)items.rawget("DuctTape")).setCurrentUses(1);var second=item("DuctTape");second.setCurrentUses(1);items.rawset("SecondTape",second);
            ((InventoryItem)items.rawget("Hammer")).setConditionNoSound(3);
        }
        if(kind.equals("epoxy") || kind.equals("tape") || kind.equals("tape-two")){
            Station station=(Station)unsafe().allocateInstance(Station.class);station.custody=true;station.setFar(false);row.rawset("object",station);
        }
        if(kind.equals("grind")){
            Path source=Path.of(System.getProperty("sao.game")).resolve("media/scripts/generated/entities/blacksmith/workstations/entity_grindstone.txt");
            GameEntityScript entity=new GameEntityScript();entity.setModule(module);entity.InitLoadPP("Grindstone");
            entity.Load("Grindstone","entity Grindstone { "+block(Files.readString(source),"component","CraftBench")+" }");
            entity.OnScriptsLoaded(ScriptLoadMode.Init);
            var bench=(CraftBench)ComponentType.CraftBench.CreateComponentFromScript(entity.getComponentScriptFor(ComponentType.CraftBench));
            Station station=(Station)unsafe().allocateInstance(Station.class);station.custody=true;station.definition=entity;station.setFar(false);
            row.rawset("bench",bench);row.rawset("object",station);
        }
        return row;
    }
    public static void main(String[] args) throws Exception {
        zombie.core.random.RandStandard.INSTANCE.init();
        platform=new J2SEPlatform();env=platform.newEnvironment();var thread=new KahluaThread(platform,env);thread.debugOwnerThread=Thread.currentThread();
        LuaManager.platform=platform;LuaManager.env=env;LuaManager.thread=thread;
        zombie.ui.UIManager.defaultthread=thread;
        LuaManager.converterManager=new se.krka.kahlua.converter.KahluaConverterManager();zombie.Lua.KahluaNumberConverter.install(LuaManager.converterManager);
        LuaManager.caller=new se.krka.kahlua.integration.LuaCaller(LuaManager.converterManager);
        LuaManager.exposer=new LuaManager.Exposer(LuaManager.converterManager,platform,env);
        for(Class<?> c:new Class<?>[]{Receiver.class,Station.class,ArrayList.class,Iterator.class,Collection.class,List.class,Set.class,
            CraftRecipe.class,InputScript.class,OutputScript.class,CraftRecipe.RequiredSkill.class,PerkFactory.Perk.class,
            CraftRecipeManager.class,CraftRecipeData.class,HandcraftLogic.class,zombie.entity.components.crafting.BaseCraftingLogic.class,
            Item.class,ScriptManager.class,CraftBench.class,InventoryItem.class,ItemContainer.class,
            zombie.inventory.types.DrainableComboItem.class,zombie.inventory.types.HandWeapon.class,
            zombie.characters.IsoGameCharacter.class,zombie.characters.IsoPlayer.class,
            zombie.scripting.objects.BaseScriptObject.class,java.util.HashSet.class,
            zombie.entity.components.resources.ResourceType.class,zombie.entity.components.crafting.ItemApplyMode.class,
            zombie.entity.components.crafting.FluidMatchMode.class,zombie.entity.energy.Energy.class,
            zombie.entity.components.fluids.Fluid.class}){LuaManager.exposer.setExposed(c);LuaManager.exposer.exposeLikeJava(c,env);}
        env.rawset("print",(JavaFunction)(f,n)->{for(int i=0;i<n;i++)System.out.print((i==0?"":" ")+f.get(i));System.out.println();return 0;});
        env.rawset("__check",(JavaFunction)(f,n)->{System.out.println("CHECK "+f.get(0)+"="+f.get(1));return 0;});
        thread.call(LuaCompiler.loadstring("ISTimedActionQueue={queues={},getTimedActionQueue=function() return {queue={}} end}","controlled-empty-action-queue",env),null,null,null);
        initialise(Path.of(args[0]));
        env.rawset("__reset",(JavaFunction)(f,n)->{try{return f.push(reset((String)f.get(0)));}catch(Exception e){throw new IllegalStateException(e);}});
        env.rawset("__roundtrip",(JavaFunction)(f,n)->{try{var bytes=ByteBuffer.allocate(1048576);((KahluaTable)f.get(0)).save(bytes);bytes.flip();var restored=platform.newTable();restored.load(bytes,zombie.iso.IsoWorld.WorldVersion);return f.push(restored);}catch(Exception e){throw new IllegalStateException(e);}});
        env.rawset("__snapshot",(JavaFunction)(f,n)->{try{var bytes=ByteBuffer.allocate(1048576);((KahluaTable)f.get(0)).save(bytes);return f.push(Base64.getEncoder().encodeToString(Arrays.copyOf(bytes.array(),bytes.position())));}catch(Exception e){throw new IllegalStateException(e);}});
        env.rawset("__projection",(JavaFunction)(f,n)->{System.out.println("PROJECTION "+f.get(0)+" "+json(f.get(1)));return 0;});
        env.rawset("__dropRecipe",(JavaFunction)(f,n)->{module.craftRecipes.getScriptMap().remove((String)f.get(0));
            try{Field field=ScriptManager.class.getDeclaredField("craftRecipes");field.setAccessible(true);((ScriptBucketCollection<?>)field.get(ScriptManager.instance)).getFullTypeToScriptMap().remove("Base."+f.get(0));}catch(Exception e){throw new IllegalStateException(e);}return 0;});
        for(int i=1;i<args.length;i++){
            Object[] result=thread.pcall(LuaCompiler.loadstring(Files.readString(Path.of(args[i])),args[i],env),new Object[0]);
            if(!Boolean.TRUE.equals(result[0]))throw new AssertionError(Arrays.toString(result));
        }
    }
}
