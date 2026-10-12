import java.lang.reflect.*;
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
import zombie.entity.*;
import zombie.entity.components.build.BuildLogic;
import zombie.entity.components.crafting.*;
import zombie.entity.components.crafting.recipe.*;
import zombie.entity.components.spriteconfig.SpriteConfigManager;
import zombie.inventory.*;
import zombie.iso.*;
import zombie.scripting.*;
import zombie.scripting.entity.*;
import zombie.scripting.entity.components.crafting.*;
import zombie.scripting.entity.components.spriteconfig.SpriteConfigScript;
import zombie.scripting.objects.*;

/** Installed registered build policy/geometry and seeded actual station component.
 * Controlled unattached actor skills/knowledge/custody/range; no build effects. */
public final class ConstructionPolicyNativeProbe {
    static ScriptModule module; static J2SEPlatform platform; static KahluaTable env;
    static final Map<String, GameEntityScript> entities = new LinkedHashMap<>();
    static Unsafe unsafe() throws Exception {var f=Unsafe.class.getDeclaredField("theUnsafe");f.setAccessible(true);return (Unsafe)f.get(null);}
    public static class Receiver extends IsoPlayer {
        ItemContainer inventory; PlayerCraftHistory history; public int skill; public boolean learned;
        public Receiver(){super((IsoCell)null);}
        @Override public ItemContainer getInventory(){return inventory;}
        @Override public int getPerkLevel(PerkFactory.Perk p){return skill;}
        @Override public boolean isRecipeKnown(CraftRecipe r,boolean ignored){return learned;}
        @Override public PlayerCraftHistory getPlayerCraftHistory(){return history;}
        @Override public boolean isLocalPlayer(){return false;}
        public void setSkill(int n){skill=n;}
        public void setLearned(boolean b){learned=b;}
    }
    public static class Station extends IsoObject {
        GameEntityScript definition; IsoGridSquare square; public boolean custody;
        public Station(){super((IsoCell)null);}
        @Override public GameEntityScript getEntityScript(){return definition;}
        @Override public IsoGridSquare getSquare(){return square;}
        @Override public boolean isUsingPlayer(IsoPlayer player){return custody;}
        public void setCustody(boolean b){custody=b;}
        public void setFar(boolean b){square=new IsoGridSquare(null,null,b?20:0,0,0);}
    }
    static String block(String source,String type,String name){
        source=ScriptParser.stripComments(source);
        var m=Pattern.compile("(?m)^\\s*"+type+"\\s+"+Pattern.quote(name)+"\\s*\\{").matcher(source);
        if(!m.find())throw new IllegalArgumentException("missing native "+type+" "+name);
        int depth=1,end=m.end();while(depth>0){char c=source.charAt(end++);if(c=='{')depth++;if(c=='}')depth--;}
        return source.substring(m.start(),end);
    }
    static void register() throws Exception {
        for(Field f:ScriptManager.class.getDeclaredFields())if(ScriptBucketCollection.class.isAssignableFrom(f.getType())){
            f.setAccessible(true);ScriptBucketCollection c=(ScriptBucketCollection)f.get(ScriptManager.instance);
            var bucket=c.getBucketFromModule(module);
            for(Object value:bucket.getScriptMap().values()){
                var script=(BaseScriptObject)value;c.getFullTypeToScriptMap().put(script.getScriptObjectFullType(),script);
                if(!bucket.getScriptList().contains(script))bucket.getScriptList().add(script);
                if(!c.getAllScripts().contains(script))c.getAllScripts().add(script);
            }
        }
    }
    static void entity(String name,String definition) throws Exception {
        // UI skin preparation is outside this metadata probe; source policy stays.
        definition=definition.replaceAll("(?s)component UiConfig\\s*\\{.*?\\}","");
        var entity=new GameEntityScript();entity.setModule(module);entity.setModID("pz-vanilla");
        entity.InitLoadPP(name);entity.Load(name,definition);module.entities.getScriptMap().put(name,entity);entities.put(name,entity);
    }
    static void initialise(Path game) throws Exception {
        zombie.core.random.RandStandard.INSTANCE.init();PerkFactory.init();zombie.entity.components.attributes.Attribute.init();
        zombie.network.GameServer.server=true;
        Field mod=ScriptManager.class.getDeclaredField("currentLoadFileMod");mod.setAccessible(true);mod.set(null,"pz-vanilla");
        module=new ScriptModule();module.name="Base";ScriptManager.instance.moduleMap.put("Base",module);ScriptManager.instance.moduleList.add(module);
        for(Field f:ScriptManager.class.getDeclaredFields())if(ScriptBucketCollection.class.isAssignableFrom(f.getType())){
            f.setAccessible(true);((ScriptBucketCollection<?>)f.get(ScriptManager.instance)).registerModule(module);
        }
        for(String name:List.of("Hammer","Plank","Nails","StoneWheel","Scissors")){
            String file=List.of("Hammer","Plank","Scissors").contains(name)?"weapon":"normal";
            String definition=block(Files.readString(game.resolve("media/scripts/generated/items/"+file+".txt")),"item",name)
                .replaceAll("(?im)^\\s*Researchablerecipes\\s*=.*$","");
            var item=new Item();item.setModule(module);item.setModID("pz-vanilla");item.InitLoadPP(name);item.Load(name,definition);item.setDisplayName(name);
            module.items.getScriptMap().put(name,item);
        }
        String timedSource=Files.readString(game.resolve("media/scripts/generated/timedactions.txt"));
        for(String name:List.of("BuildWallHammer","BuildLowHammer","UseGrindingStone")){
            var timed=new TimedActionScript();timed.setModule(module);timed.InitLoadPP(name);timed.Load(name,block(timedSource,"timedAction",name));
            module.timedActionScripts.getScriptMap().put(name,timed);
        }
        for(String[] entry:new String[][]{
            {"Wood_TableLvl1","furniture/entity_carpentry_table_lvl1.txt"},
            {"Grindstone","blacksmith/workstations/entity_grindstone.txt"}}){
            entity(entry[0],block(Files.readString(game.resolve("media/scripts/generated/entities/"+entry[1])),"entity",entry[0]));
        }
        var grind=new CraftRecipe();grind.setModule(module);grind.InitLoadPP("SharpenBladeWithGrindstone");
        grind.Load("SharpenBladeWithGrindstone",block(Files.readString(game.resolve("media/scripts/generated/recipes/recipes_fixing.txt")),"craftRecipe","SharpenBladeWithGrindstone"));
        module.craftRecipes.getScriptMap().put("SharpenBladeWithGrindstone",grind);
        // Native-parsed instrument-only controls; never shipped definitions.
        for(String[] test:new String[][]{{"PolicyDebug","OnAddToMenu = debugTest,"},
            {"PolicyUnknown","OnAddToMenu = MissingConstructionPolicyCallback,"},
            {"PolicyLearned","NeedToBeLearn = true,"},
            {"PolicyVariable",""}}){
            String input=test[0].equals("PolicyVariable")?"item variable[1:3] [Base.Plank],":"item 1 [Base.Plank],";
            entity(test[0],"entity "+test[0]+" { component SpriteConfig { face S { layer { row = carpentry_01_24, } } } "
                +"component CraftRecipe { "+test[1]+" inputs { "+input+" } } }");
        }
        entity("PolicyBlocking", "entity PolicyBlocking { component SpriteConfig { face S { "
            +"layer { row = carpentry_01_24 true false, } layer { row = false false carpentry_01_25, } } } "
            +"component CraftRecipe { inputs { item 1 [Base.Plank], } } }");
        register();CraftRecipeManager.Init();
        for(var entity:entities.values())entity.OnScriptsLoaded(ScriptLoadMode.Init);register();
        grind.OnScriptsLoaded(ScriptLoadMode.Init);ItemTags.Init(ScriptManager.instance.getAllItems());
        for(var entity:entities.values())entity.OnPostWorldDictionaryInit();grind.OnPostWorldDictionaryInit();
        for(var entity:entities.values()){
            var sprite=(SpriteConfigScript)entity.getComponentScriptFor(ComponentType.SpriteConfig);
            for(String name:sprite.getAllTileNames())zombie.iso.sprite.IsoSpriteManager.instance.AddSprite(name).name=name;
        }
        SpriteConfigManager.InitScriptsPostTileDef();CraftRecipeManager.Init();zombie.network.GameServer.server=false;
    }
    static KahluaTable reset() throws Exception {
        var body=(Receiver)unsafe().allocateInstance(Receiver.class);body.skill=1;body.learned=true;
        body.inventory=new ItemContainer();body.inventory.setType("inventory");body.history=new PlayerCraftHistory(body);
        var row=platform.newTable();row.rawset("body",body);
        boolean previousServer=zombie.network.GameServer.server;zombie.network.GameServer.server=true;
        InventoryItem hammer;try{hammer=module.getItem("Hammer").InstanceItem(null);}finally{zombie.network.GameServer.server=previousServer;}
        hammer.setID(321);body.inventory.AddItemBlind(hammer);hammer.setContainer(body.inventory);row.rawset("hammer",hammer);
        var station=(Station)unsafe().allocateInstance(Station.class);station.definition=entities.get("Grindstone");station.custody=true;station.setFar(false);
        var bench=ComponentType.CraftBench.CreateComponentFromScript(station.definition.getComponentScriptFor(ComponentType.CraftBench));
        var add=GameEntity.class.getDeclaredMethod("addComponent",Component.class);add.setAccessible(true);add.invoke(station,bench);
        row.rawset("station",station);row.rawset("bench",bench);return row;
    }
    static void expose(Class<?> c){LuaManager.exposer.setExposed(c);LuaManager.exposer.exposeLikeJava(c,env);}
    public static void main(String[] args) throws Exception {
        platform=new J2SEPlatform();env=platform.newEnvironment();var thread=new KahluaThread(platform,env);thread.debugOwnerThread=Thread.currentThread();
        LuaManager.platform=platform;LuaManager.env=env;LuaManager.thread=thread;zombie.ui.UIManager.defaultthread=thread;
        LuaManager.converterManager=new se.krka.kahlua.converter.KahluaConverterManager();zombie.Lua.KahluaNumberConverter.install(LuaManager.converterManager);
        LuaManager.caller=new se.krka.kahlua.integration.LuaCaller(LuaManager.converterManager);LuaManager.exposer=new LuaManager.Exposer(LuaManager.converterManager,platform,env);
        for(Class<?> c:new Class<?>[]{Receiver.class,Station.class,ArrayList.class,Iterator.class,Collection.class,List.class,Set.class,
            GameEntity.class,GameEntityScript.class,ComponentScript.class,ComponentType.class,ScriptManager.class,BaseScriptObject.class,
            SpriteConfigScript.class,SpriteConfigManager.class,SpriteConfigManager.ObjectInfo.class,SpriteConfigManager.FaceInfo.class,SpriteConfigManager.TileInfo.class,
            BuildLogic.class,BaseCraftingLogic.class,CraftRecipe.class,CraftRecipeComponentScript.class,CraftBenchScript.class,CraftBench.class,
            InputScript.class,OutputScript.class,CraftRecipe.RequiredSkill.class,CraftRecipeManager.class,CraftRecipeData.class,
            PerkFactory.Perk.class,PerkFactory.Perks.class,Item.class,InventoryItem.class,ItemContainer.class,IsoObject.class,IsoGameCharacter.class,IsoPlayer.class,
            zombie.entity.components.resources.ResourceType.class,zombie.entity.components.crafting.ItemApplyMode.class,
            zombie.entity.components.crafting.FluidMatchMode.class,zombie.entity.energy.Energy.class,zombie.entity.components.fluids.Fluid.class})expose(c);
        env.rawset("print",(JavaFunction)(f,n)->{for(int i=0;i<n;i++)System.out.print((i==0?"":" ")+f.get(i));System.out.println();return 0;});
        env.rawset("__check",(JavaFunction)(f,n)->{System.out.println("CHECK "+f.get(0)+"="+f.get(1));return 0;});
        env.rawset("__reset",(JavaFunction)(f,n)->{try{return f.push(reset());}catch(Exception e){throw new IllegalStateException(e);}});
        env.rawset("__roundtrip",(JavaFunction)(f,n)->{try{var b=ByteBuffer.allocate(1048576);((KahluaTable)f.get(0)).save(b);b.flip();var t=platform.newTable();t.load(b,IsoWorld.WorldVersion);return f.push(t);}catch(Exception e){throw new IllegalStateException(e);}});
        env.rawset("__snapshot",(JavaFunction)(f,n)->{try{var b=ByteBuffer.allocate(1048576);((KahluaTable)f.get(0)).save(b);return f.push(Base64.getEncoder().encodeToString(Arrays.copyOf(b.array(),b.position())));}catch(Exception e){throw new IllegalStateException(e);}});
        env.rawset("__replaceRecipe",(JavaFunction)(f,n)->{try{
            // getCraftRecipe legitimately falls back to the entity component.
            // A changed registered recipe pointer is the actual stale identity.
            String full=(String)f.get(0),name=full.substring(full.indexOf('.')+1);
            var changed=new CraftRecipe();changed.setModule(module);changed.InitLoadPP(name);
            changed.Load(name,"craftRecipe "+name+" { inputs { item 1 [Base.Plank], } }");
            module.craftRecipes.getScriptMap().put(name,changed);register();return 0;
        }catch(Exception e){throw new IllegalStateException(e);}});
        initialise(Path.of(args[0]));
        // Actual installed callback source; no rewritten or port-returned tests.
        var prelude="ISTimedActionQueue={queues={},getTimedActionQueue=function() return {queue={}} end}; isDebugEnabled=function() return true end";
        thread.call(LuaCompiler.loadstring(prelude,"controlled-unattached-queue-and-debug",env),null,null,null);
        for(int i=1;i<args.length;i++){
            var result=thread.pcall(LuaCompiler.loadstring(Files.readString(Path.of(args[i])),args[i],env),new Object[0]);
            if(!Boolean.TRUE.equals(result[0]))throw new AssertionError(Arrays.toString(result));
        }
    }
}
