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
public final class BedConstructionNativeProbe {
    private static ScriptModule module;
    private static final Map<String,GameEntityScript> entities=new LinkedHashMap<>();
    private static Receiver actor;
    private static BuildLogic logic;
    private static CraftRecipe selected;
    private static final Map<Integer,InventoryItem> items=new LinkedHashMap<>();
    private static IsoThumpable created;
    private static int skill=5;
    private static float sleepBefore,sleepAfter;
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
        for(String name:List.of("Hammer","Plank","Nails","Mattress")){
            if(module.getItem(name)!=null)continue;
            String file=List.of("Hammer","Plank").contains(name)?"weapon":name.equals("Mattress")?"moveable":"normal";
            String definition=block(game.resolve("media/scripts/generated/items/"+file+".txt"),"item",name)
                .replaceAll("(?im)^\\s*Researchablerecipes\\s*=.*$","");
            Item item=new Item();item.setModule(module);item.setModID("pz-vanilla");item.InitLoadPP(name);item.Load(name,definition);item.setDisplayName(name);
            module.items.getScriptMap().put(name,item);
        }
        if(module.timedActionScripts.getScriptMap().get("BuildWallHammer")==null){
            TimedActionScript timed=new TimedActionScript();timed.setModule(module);timed.InitLoadPP("BuildWallHammer");
            timed.Load("BuildWallHammer",block(game.resolve("media/scripts/generated/timedactions.txt"),"timedAction","BuildWallHammer"));
            module.timedActionScripts.getScriptMap().put("BuildWallHammer",timed);
        }
        for(String name:List.of("Wood_Bed")){
            String definition=block(game.resolve("media/scripts/generated/entities/furniture/entity_carpentry_bed.txt"),"entity",name);
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
        zombie.entity.components.spriteconfig.SpriteConfigManager.InitScriptsPostTileDef();nativeTiles(game);
        zombie.network.GameServer.server=priorServer;
    }
    public static GameEntityScript entity(String id){return entities.get(id);}
    public static CraftRecipe recipe(String id){return ((CraftRecipeComponentScript)entity(id).getComponentScriptFor(ComponentType.CraftRecipe)).getCraftRecipe();}
    private static String face="S";
    private static final ArrayList<IsoThumpable> createdParts=new ArrayList<>();
    private static final Map<String,Map<String,String>> tileProperties=new HashMap<>();
    private static int integer(java.io.DataInputStream in)throws Exception{return Integer.reverseBytes(in.readInt());}
    private static String line(java.io.DataInputStream in)throws Exception{
        java.io.ByteArrayOutputStream bytes=new java.io.ByteArrayOutputStream();int value;
        while((value=in.read())!='\n'){if(value<0)throw new java.io.EOFException();bytes.write(value);}
        return bytes.toString(StandardCharsets.UTF_8).trim();
    }
    private static void nativeTiles(Path game)throws Exception{
        try(var in=new java.io.DataInputStream(new java.io.BufferedInputStream(Files.newInputStream(game.resolve("media/newtiledefinitions.tiles"))))){
            if(!Arrays.equals(in.readNBytes(4),new byte[]{'t','d','e','f'})||integer(in)!=1)throw new IllegalStateException("native tiles format");
            int sets=integer(in);
            for(int set=0;set<sets;set++){
                String name=line(in);line(in);integer(in);integer(in);integer(in);int count=integer(in);
                for(int index=0;index<count;index++){
                    Map<String,String> props=new HashMap<>();int properties=integer(in);
                    for(int n=0;n<properties;n++)props.put(line(in),line(in));
                    if(name.equals("carpentry_02")&&index>=72&&index<=75)tileProperties.put(name+"_"+index,props);
                }
            }
        }
        for(String orientation:List.of("S","E")){
            var grid=new zombie.iso.sprite.IsoSpriteGrid(orientation.equals("S")?2:1,orientation.equals("S")?1:2);
            String[] names=orientation.equals("S")?new String[]{"carpentry_02_72","carpentry_02_73"}:new String[]{"carpentry_02_75","carpentry_02_74"};
            for(String name:names){
                var sprite=zombie.iso.sprite.IsoSpriteManager.instance.getSprite(name);
                var props=tileProperties.get(name);
                if(props==null||!props.containsKey("bed"))throw new IllegalStateException("native bed flag missing "+name);
                sprite.getProperties().set(zombie.iso.SpriteDetails.IsoFlagType.bed);
                sprite.getProperties().set("Facing",props.get("Facing"));
                String[] pos=props.get("SpriteGridPos").split(",");
                grid.setSprite(Integer.parseInt(pos[0]),Integer.parseInt(pos[1]),sprite);sprite.setSpriteGrid(grid);
            }
        }
    }
    public static IsoThumpable createBedPart(String sprite,IsoGridSquare square)throws Exception{
        IsoThumpable object=new IsoThumpable(square==null?null:square.getCell(),square,sprite,false,null);
        GameEntityFactory.CreateIsoObjectEntity(object,entity("Base.Wood_Bed"),true);
        if(object.getEntityScript()==null||!object.getEntityScript().getFullName().equals("Base.Wood_Bed"))
            throw new IllegalStateException("native bed entity factory refused "+sprite);
        createdParts.add(object);return object;
    }
    private static void reset(String id)throws Exception{
        actor=(Receiver)unsafe().allocateInstance(Receiver.class);actor.inventory=new ItemContainer();
        actor.inventory.setType("inventory");actor.history=new PlayerCraftHistory(actor);actor.xp=new XpReceiver(actor);
        selected=recipe(id);items.clear();created=null;createdParts.clear();skill=5;
        boolean prior=zombie.network.GameServer.server;zombie.network.GameServer.server=true;
        int itemId=100;
        for(int i=0;i<selected.getInputs().size();i++){
            InputScript input=selected.getInputs().get(i);
            String type=i==0?"Hammer":i==1?"Plank":i==2?"Nails":"Mattress";
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
    private static String spriteInfo(String face,int part) {
        return "S".equals(face)?(part==0?"carpentry_02_72":"carpentry_02_73"):(part==0?"carpentry_02_75":"carpentry_02_74");
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
            case "face":face=(String)a;return true;
            case "sprite":return spriteInfo((String)a,0);
            case "partSprite":return spriteInfo((String)a,((Number)b).intValue());
            case "facing":return tileProperties.get(spriteInfo((String)a,0)).get("Facing");
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
            case "factory":created=createBedPart((String)a,null);return true;
            case "createdCount":return createdParts.size();
            case "createdGrid":return createdParts.size()==2&&createdParts.get(0).getSprite().getSpriteGrid()==createdParts.get(1).getSprite().getSpriteGrid();
            case "createdEntity":return created.getEntityScript().getFullName();
            case "materialCategory":return com.sao.engine.SAONeeds.wantsMaterial(items.get(i),"mattress");
            default:throw new IllegalArgumentException(name);
        }
    }

    private static void checkPort(String name,boolean pass) {
        System.out.println("JAVA "+name+"="+pass);if(!pass)throw new AssertionError(name);
    }
    private static void geometry(Path game)throws Exception{
        var boot=MovementCrossingProbe.class.getDeclaredMethod("boot");boot.setAccessible(true);
        var cell=(zombie.iso.IsoCell)boot.invoke(null);
        var regions=zombie.iso.areas.isoregion.IsoRegions.class.getDeclaredField("dataRoot");regions.setAccessible(true);
        regions.set(null,new zombie.iso.areas.isoregion.data.DataRoot());
        var aliases=new HashMap<String,ArrayList<String>>();aliases.put("Facing",new ArrayList<>(List.of("N","S","E","W")));
        zombie.core.TilePropertyAliasMap.instance.Generate(aliases);initialise(game);
        var create=MovementCrossingProbe.class.getDeclaredMethod("person",zombie.iso.IsoCell.class);create.setAccessible(true);
        for(int x=5;x<19;x++)for(int y=15;y<27;y++)cell.getGridSquare(x,y,0).setSolidFloor(true);
        var body=(com.sao.engine.SAOIsoPlayerShell)create.invoke(null,cell);
        body.getModData().rawset("SAOPersonId","bed-native-person");body.setSquare(body.getCurrentSquare());
        cell.getObjectList().add(body);body.getCurrentSquare().getMovingObjects().add(body);body.setForwardDirection(1,0);
        for(String orientation:List.of("S","E")){
            String encoded=com.sao.engine.SAOBedConstruction.observe(body);
            String chosen=null;
            for(String row:encoded.split("\\|"))if(row.startsWith("11,20,0,"+orientation+","))chosen=row;
            checkPort("personally_visible_full_footprint_"+orientation,chosen!=null);
            String[] fields=chosen.split(",");
            int ax=Integer.parseInt(fields[5]),ay=Integer.parseInt(fields[6]);
            body.getCurrentSquare().getMovingObjects().remove(body);body.setX(ax+.5f);body.setY(ay+.5f);
            body.setCurrent(cell.getGridSquare(ax,ay,0));body.setSquare(body.getCurrentSquare());body.getCurrentSquare().getMovingObjects().add(body);
            checkPort("exact_observed_native_approach_"+orientation,com.sao.engine.SAOBedConstruction.placement(body,11,20,0,orientation,fields[4])==cell.getGridSquare(11,20,0));
            var occupant=(com.sao.engine.SAOIsoPlayerShell)create.invoke(null,cell);
            occupant.getCurrentSquare().getMovingObjects().remove(occupant);
            occupant.setX(ax+.5f);occupant.setY(ay+.5f);occupant.setCurrent(cell.getGridSquare(ax,ay,0));occupant.setSquare(occupant.getCurrentSquare());
            occupant.getCurrentSquare().getMovingObjects().add(occupant);cell.getObjectList().add(occupant);
            checkPort("retained_approach_occupant_refuses_"+orientation,com.sao.engine.SAOBedConstruction.placement(body,11,20,0,orientation,fields[4])==null);
            String refresh=null;
            for(String row:com.sao.engine.SAOBedConstruction.observe(body).split("\\|"))if(row.startsWith("11,20,0,"+orientation+","))refresh=row;
            checkPort("changed_approach_gets_fresh_revision_"+orientation,refresh!=null&&!refresh.split(",")[4].equals(fields[4]));
            occupant.getCurrentSquare().getMovingObjects().remove(occupant);cell.getObjectList().remove(occupant);
            var blockers=new ArrayList<com.sao.engine.SAOIsoPlayerShell>();
            int[][] legal=orientation.equals("S")?new int[][]{{11,19},{11,21},{12,19},{12,21},{13,20}}:new int[][]{{10,20},{12,20},{10,21},{12,21},{11,22}};
            for(int[] point:legal){
                var blocking=(com.sao.engine.SAOIsoPlayerShell)create.invoke(null,cell);
                blocking.getCurrentSquare().getMovingObjects().remove(blocking);
                blocking.setX(point[0]+.5f);blocking.setY(point[1]+.5f);blocking.setCurrent(cell.getGridSquare(point[0],point[1],0));blocking.setSquare(blocking.getCurrentSquare());
                blocking.getCurrentSquare().getMovingObjects().add(blocking);cell.getObjectList().add(blocking);blockers.add(blocking);
            }
            body.getCurrentSquare().getMovingObjects().remove(body);
            body.setX(orientation.equals("S")?10.5f:11.5f);body.setY(orientation.equals("S")?20.5f:19.5f);
            body.setCurrent(cell.getGridSquare((int)body.getX(),(int)body.getY(),0));body.setSquare(body.getCurrentSquare());body.getCurrentSquare().getMovingObjects().add(body);
            var method=com.sao.engine.SAOBedConstruction.class.getDeclaredMethod("approach",com.sao.engine.SAOIsoPlayerShell.class,IsoGridSquare.class,String.class);method.setAccessible(true);
            checkPort("head_end_only_cannot_offer_bed_"+orientation,method.invoke(null,body,cell.getGridSquare(11,20,0),orientation)==null);
            for(var blocking:blockers){blocking.getCurrentSquare().getMovingObjects().remove(blocking);cell.getObjectList().remove(blocking);}
            body.getCurrentSquare().getMovingObjects().remove(body);body.setX(ax+.5f);body.setY(ay+.5f);
            body.setCurrent(cell.getGridSquare(ax,ay,0));body.setSquare(body.getCurrentSquare());body.getCurrentSquare().getMovingObjects().add(body);

            var second=cell.getGridSquare(11+(orientation.equals("S")?1:0),20+(orientation.equals("E")?1:0),0);
            second.getProperties().set(zombie.iso.SpriteDetails.IsoFlagType.solid);second.RecalcProperties();
            checkPort("blocked_second_tile_refuses_"+orientation,com.sao.engine.SAOBedConstruction.placement(body,11,20,0,orientation,fields[4])==null);
            second.getProperties().unset(zombie.iso.SpriteDetails.IsoFlagType.solid);second.RecalcProperties();
            var head=createBedPart(spriteInfo(orientation,0),cell.getGridSquare(11,20,0));
            var foot=createBedPart(spriteInfo(orientation,1),second);
            head.getSquare().getObjects().add(head);foot.getSquare().getObjects().add(foot);
            checkPort("exact_native_parts_grid_and_facing_"+orientation,com.sao.engine.SAOBedConstruction.created(body,head,foot,11,20,0,orientation));
            var observation=com.sao.engine.SAORecoveryPlace.observe(body,8);
            var places=(KahluaTable)observation.rawget("places");KahluaTable bed=null;
            for(int i=1;i<=places.len();i++){
                var row=(KahluaTable)places.rawget((double)i);
                if("bed".equals(row.rawget("kind"))&&Boolean.TRUE.equals(row.rawget("available"))&&Double.valueOf(11).equals(row.rawget("objectX"))&&Double.valueOf(20).equals(row.rawget("objectY")))bed=row;
            }
            checkPort("native_created_bed_ordinary_recovery_source_"+orientation,bed!=null);
            if(orientation.equals("S")){
                var platform=new J2SEPlatform();var environment=platform.newEnvironment();var vm=new KahluaThread(platform,environment);
                zombie.Lua.LuaManager.platform=platform;zombie.Lua.LuaManager.env=environment;zombie.Lua.LuaManager.thread=vm;
                vm.call(LuaCompiler.loadstring(Files.readString(game.resolve("media/lua/shared/defines.lua")),"native-defines",environment),null,null,null);
                zombie.ZomboidGlobals.Load();
                zombie.GameTime.getInstance().setMinutesPerDay(60);zombie.GameTime.getInstance().setMultiplier(5);
                var state=zombie.ai.StateMachine.class.getDeclaredField("currentState");state.setAccessible(true);state.set(body.getStateMachine(),zombie.ai.states.IdleState.instance());
                body.setBed(head);body.setBedType(head.getProperties().get("BedType")==null?"badBed":head.getProperties().get("BedType"));
                body.getStats().set(zombie.characters.CharacterStat.FATIGUE,.65f);
                body.getStats().set(zombie.characters.CharacterStat.HUNGER,.1f);body.getStats().set(zombie.characters.CharacterStat.THIRST,.1f);
                com.sao.engine.SAONeeds.setShellAsleep(body,true);checkPort("native_constructed_bed_sleep_event_admitted",body.isAsleep()&&body.getBed()==head);
                IsoPlayer.setInstance(body);var wake=IsoGameCharacter.class.getDeclaredMethod("updateStats_WakeState");wake.setAccessible(true);
                sleepBefore=body.getStats().get(zombie.characters.CharacterStat.FATIGUE);
                int ticks=0;while(body.getStats().get(zombie.characters.CharacterStat.FATIGUE)>.28f&&ticks++<100000)wake.invoke(body);
                sleepAfter=body.getStats().get(zombie.characters.CharacterStat.FATIGUE);
                checkPort("native_constructed_bed_sleep_reduces_fatigue",sleepAfter<sleepBefore&&sleepAfter<=.3f);
                System.out.println("SLEEP_SAMPLE before="+sleepBefore+" after="+sleepAfter+" ticks="+ticks);
                com.sao.engine.SAONeeds.setShellAsleep(body,false);
            }
            head.getSquare().getObjects().remove(head);foot.getSquare().getObjects().remove(foot);createdParts.clear();
        }
        zombie.network.GameServer.server=true;
        var mattress=module.getItem("Mattress").InstanceItem(null);var plank=module.getItem("Plank").InstanceItem(null);
        zombie.network.GameServer.server=false;
        checkPort("native_exact_mattress_category",com.sao.engine.SAONeeds.wantsMaterial(mattress,"mattress")
            &&!com.sao.engine.SAONeeds.wantsMaterial(plank,"mattress"));
        mattress.setIsCraftingConsumed(true);
        checkPort("native_reserved_mattress_refused",!com.sao.engine.SAONeeds.wantsMaterial(mattress,"mattress"));
    }

    public static void main(String[] args)throws Exception{
        if(args.length>1&&args[1].equals("--geometry")){geometry(Path.of(args[0]));return;}
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
                for(String orientation:List.of("S","E")){
                    createdParts.clear();createBedPart(spriteInfo(orientation,0),null);createBedPart(spriteInfo(orientation,1),null);
                    System.out.println("FACTORY face="+orientation+" count="+createdParts.size()+" sameGrid="+op("createdGrid",null,null));
                }
            }return;
        }
        env.rawset("__nativeBed",(JavaFunction)(f,n)->{try{Object result=op((String)f.get(0),n>1?f.get(1):null,n>2?f.get(2):null);
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
