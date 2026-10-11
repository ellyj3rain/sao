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
public final class ShelterConstructionNativeProbe {
    private static ScriptModule module;
    private static final Map<String,GameEntityScript> entities=new LinkedHashMap<>();
    private static Receiver actor;
    private static BuildLogic logic;
    private static CraftRecipe selected;
    private static final Map<Integer,InventoryItem> items=new LinkedHashMap<>();
    private static IsoThumpable created;
    private static int skill=8;
    private static String selectedEntity="Base.WoodenWallFrame";
    private static float sleepBefore,sleepAfter;
    private static Path gamePath;
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
        gamePath=game;
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
        for(String name:List.of("Hammer","Plank","Nails","Hinge","Doorknob")){
            if(module.getItem(name)!=null)continue;
            String file=List.of("Hammer","Plank").contains(name)?"weapon":"normal";
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
        String[] registered={"WoodenWallFrame","entity_woodenwallframe",
            "WoodenWallLvl1","entity_wood_walllvl1",
            "WoodenWallLvl2","entity_wood_walllvl2",
            "WoodenWallLvl3","entity_wood_walllvl3",
            "WoodDoorFrameLvl1","entity_wood_doorframelvl1",
            "WoodDoorFrameLvl2","entity_wood_doorframelvl2",
            "WoodDoorFrameLvl3","entity_wood_doorframelvl3",
            "WoodenDoorLvl1","entity_woodendoorlvl1",
            "WoodenDoorLvl2","entity_woodendoorlvl2",
            "WoodenDoorLvl3","entity_woodendoorlvl3"};
        for(int n=0;n<registered.length;n+=2){
            String name=registered[n];
            String definition=block(game.resolve("media/scripts/generated/entities/walls/"+registered[n+1]+".txt"),"entity",name);
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
        boolean server=zombie.network.GameServer.server;zombie.network.GameServer.server=true;
        var manager=zombie.iso.sprite.IsoSpriteManager.instance;
        String path=game.resolve("media/newtiledefinitions.tiles").toString();
        zombie.iso.IsoWorld.instance.LoadTileDefinitionsPropertyStrings(manager,path,0);
        zombie.core.TilePropertyAliasMap.instance.Generate(zombie.iso.IsoWorld.PropertyValueMap);
        zombie.iso.IsoWorld.instance.LoadTileDefinitions(manager,path,0);
        zombie.network.GameServer.server=server;
        var needed=new HashSet<String>();
        for(var entity:entities.values())needed.addAll(((zombie.scripting.entity.components.spriteconfig.SpriteConfigScript)
            entity.getComponentScriptFor(ComponentType.SpriteConfig)).getAllTileNames());
        try(var in=new java.io.DataInputStream(new java.io.BufferedInputStream(Files.newInputStream(game.resolve("media/newtiledefinitions.tiles"))))){
            if(!Arrays.equals(in.readNBytes(4),new byte[]{'t','d','e','f'})||integer(in)!=1)throw new IllegalStateException("native tiles format");
            int sets=integer(in);
            for(int set=0;set<sets;set++){
                String name=line(in);line(in);integer(in);integer(in);integer(in);int count=integer(in);
                for(int index=0;index<count;index++){
                    Map<String,String> props=new HashMap<>();int properties=integer(in);
                    for(int n=0;n<properties;n++)props.put(line(in),line(in));
                    if(needed.contains(name+"_"+index))tileProperties.put(name+"_"+index,props);
                }
            }
        }
    }
    private static zombie.entity.components.spriteconfig.SpriteConfigManager.ObjectInfo info(String id){
        for(var i:zombie.entity.components.spriteconfig.SpriteConfigManager.GetObjectInfoList())
            if(i.getScript().getParent().getScriptObjectFullType().equals(id))return i;
        throw new IllegalArgumentException("native ObjectInfo absent "+id);
    }
    public static IsoThumpable createShelterPart(String sprite,IsoGridSquare square)throws Exception{
        String open=selectedEntity.startsWith("Base.WoodenDoorLvl")?info(selectedEntity).getFace(face+"_OPEN").getTileInfo(0,0,0).getSpriteName():null;
        IsoThumpable object=open==null?new IsoThumpable(square==null?null:square.getCell(),square,sprite,face.equals("N"),null)
            :new IsoThumpable(square==null?null:square.getCell(),square,sprite,open,face.equals("N"),null);
        object.setName(selectedEntity.substring(5));object.setMaxHealth(500);object.setHealth(500);
        object.setIsDoor(object.getType()==zombie.iso.SpriteDetails.IsoObjectType.doorN||object.getType()==zombie.iso.SpriteDetails.IsoObjectType.doorW);
        object.setIsDoorFrame(object.getType()==zombie.iso.SpriteDetails.IsoObjectType.doorFrN||object.getType()==zombie.iso.SpriteDetails.IsoObjectType.doorFrW);
        GameEntityFactory.CreateIsoObjectEntity(object,entity(selectedEntity),true);
        if(object.getEntityScript()==null||!object.getEntityScript().getFullName().equals(selectedEntity))
            throw new IllegalStateException("native bed entity factory refused "+sprite);
        createdParts.add(object);return object;
    }
    private static void reset(String id)throws Exception{
        actor=(Receiver)unsafe().allocateInstance(Receiver.class);actor.inventory=new ItemContainer();
        actor.inventory.setType("inventory");actor.history=new PlayerCraftHistory(actor);actor.xp=new XpReceiver(actor);
        selectedEntity=id;selected=recipe(id);items.clear();created=null;createdParts.clear();skill=8;
        boolean prior=zombie.network.GameServer.server;zombie.network.GameServer.server=true;
        int itemId=100;
        for(int i=0;i<selected.getInputs().size();i++){
            InputScript input=selected.getInputs().get(i);
            String type=i==0?"Hammer":i==1?"Plank":i==2?"Nails":i==3?"Hinge":"Doorknob";
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
        return info(selectedEntity).getFace(face).getTileInfo(0,0,0).getSpriteName();
    }
    private static com.sao.engine.SAOIsoPlayerShell sceneBody;
    private static zombie.iso.IsoCell sceneCell;
    private static zombie.iso.areas.isoregion.data.DataRoot sceneRoot;
    private static IsoThumpable sceneDoor;
    private static String sceneFace;
    private static String sceneCaptureKey,sceneCaptureRevision;
    private static int passageCount;
    private static void staticField(Class<?> type,String name,Object value)throws Exception{
        var f=type.getDeclaredField(name);f.setAccessible(true);f.set(null,value);
    }
    private static void sceneSetup(String orientation,String actorId)throws Exception{
        System.out.println("SCENE before boot");System.out.flush();
        var platform=zombie.Lua.LuaManager.platform;var env=zombie.Lua.LuaManager.env;var thread=zombie.Lua.LuaManager.thread;
        var boot=MovementCrossingProbe.class.getDeclaredMethod("boot");boot.setAccessible(true);sceneCell=(zombie.iso.IsoCell)boot.invoke(null);
        System.out.println("SCENE after boot");System.out.flush();
        System.out.println("SCENE before region setup");System.out.flush();
        sceneRoot=new zombie.iso.areas.isoregion.data.DataRoot();staticField(zombie.iso.areas.isoregion.IsoRegions.class,"dataRoot",sceneRoot);
        var ctor=zombie.iso.areas.isoregion.IsoRegionWorker.class.getDeclaredConstructor();ctor.setAccessible(true);
        staticField(zombie.iso.areas.isoregion.IsoRegions.class,"regionWorker",ctor.newInstance());
        var logger=zombie.iso.areas.isoregion.IsoRegionsLogger.class.getDeclaredConstructor(boolean.class);logger.setAccessible(true);
        staticField(zombie.iso.areas.isoregion.IsoRegions.class,"logger",logger.newInstance(false));
        var person=MovementCrossingProbe.class.getDeclaredMethod("person",zombie.iso.IsoCell.class);person.setAccessible(true);
        sceneBody=(com.sao.engine.SAOIsoPlayerShell)person.invoke(null,sceneCell);
        System.out.println("SCENE after person");System.out.flush();
        var animationField=zombie.characters.IsoGameCharacter.class.getDeclaredField("animPlayer");animationField.setAccessible(true);
        var animation=(zombie.core.skinnedmodel.animation.AnimationPlayer)animationField.get(sceneBody);
        var skin=new zombie.core.skinnedmodel.model.SkinningData(new HashMap<>(),new ArrayList<>(),new ArrayList<>(),new ArrayList<>(),new ArrayList<>(),new HashMap<>());
        var skinField=zombie.core.skinnedmodel.animation.AnimationPlayer.class.getDeclaredField("skinningData");skinField.setAccessible(true);skinField.set(animation,skin);
        var first=zombie.core.skinnedmodel.animation.AnimationPlayer.class.getDeclaredField("boneTransformsNeedFirstFrame");first.setAccessible(true);first.setBoolean(animation,false);
        animation.setAngle(orientation.equals("N")?-(float)Math.PI/2:(float)Math.PI);sceneBody.setSlowFactor(0);
        var animationUpdate=zombie.characters.IsoGameCharacter.class.getDeclaredField("animationUpdatingThisFrame");animationUpdate.setAccessible(true);animationUpdate.setBoolean(sceneBody,false);

        sceneBody.getModData().rawset("SAOPersonId",actorId);sceneBody.setSquare(sceneBody.getCurrentSquare());
        sceneBody.setCollidable(true);sceneBody.setNoClip(false);sceneBody.setLast(sceneBody.getCurrentSquare());
        sceneBody.setLastX(sceneBody.getX());sceneBody.setLastY(sceneBody.getY());sceneBody.setLastZ(0);
        var state=zombie.ai.StateMachine.class.getDeclaredField("currentState");state.setAccessible(true);
        state.set(sceneBody.getStateMachine(),zombie.ai.states.IdleState.instance());
        sceneCell.getObjectList().add(sceneBody);sceneBody.getCurrentSquare().getMovingObjects().add(sceneBody);
        // Native map-door toggling invalidates these visual cache receivers.
        var maskField=zombie.iso.weather.fx.WeatherFxMask.class.getDeclaredField("playerMasks");maskField.setAccessible(true);
        var masks=(Object[])maskField.get(null);var maskCtor=Class.forName("zombie.iso.weather.fx.WeatherFxMask$PlayerFxMask").getDeclaredConstructor();
        for(int index=0;index<masks.length;index++)if(masks[index]==null)masks[index]=maskCtor.newInstance();
        for(int x=5;x<18;x++)for(int y=14;y<26;y++){
            var sq=sceneCell.getGridSquare(x,y,0);var floor=new zombie.iso.IsoObject(sceneCell);floor.setSquare(sq);
            var sprite=new zombie.iso.sprite.IsoSprite();sprite.getProperties().set(zombie.iso.SpriteDetails.IsoFlagType.solidfloor);
            floor.setSprite(sprite);sq.getObjects().add(floor);sq.RecalcProperties();sq.setSolidFloor(true);
        }
        sceneFace=orientation;sceneDoor=null;passageCount=0;
        var building=new zombie.iso.areas.IsoBuilding(sceneCell);building.def=new zombie.iso.BuildingDef();building.def.id=71;
        var room=new zombie.iso.areas.IsoRoom();room.def=new zombie.iso.RoomDef(71,"existing-test-room");room.def.setBuilding(building.def);room.building=building;
        for(int x=10;x<=13;x++)for(int y=20;y<=23;y++){
            var floor=sceneCell.getGridSquare(x,y,0);floor.haveRoof=true;floor.setRoomID(71);floor.setRoom(room);
            var roof=new IsoGridSquare(sceneCell,null,x,y,1);roof.chunk=floor.chunk;
            var ceiling=new zombie.iso.IsoObject(sceneCell);ceiling.setSquare(roof);
            var ceilingSprite=new zombie.iso.sprite.IsoSprite();ceilingSprite.getProperties().set(zombie.iso.SpriteDetails.IsoFlagType.solidfloor);
            ceiling.setSprite(ceilingSprite);roof.getObjects().add(ceiling);roof.RecalcProperties();roof.setSolidFloor(true);roof.chunk.setSquare(x%8,y%8,1,roof);
        }
        String oldEntity=selectedEntity,oldFace=face;selectedEntity="Base.WoodenWallLvl1";
        for(int x=10;x<=13;x++)for(int y=20;y<=23;y++)for(String edge:List.of("N","W","S","E")){
            if(edge.equals("N")&&y!=20||edge.equals("W")&&x!=10||edge.equals("S")&&y!=23||edge.equals("E")&&x!=13)continue;
            if(x==10&&y==20&&edge.equals(orientation))continue;
            face=edge.equals("N")||edge.equals("S")?"N":"W";
            var sq=sceneCell.getGridSquare(edge.equals("E")?x+1:x,edge.equals("S")?y+1:y,0);
            var object=createShelterPart(spriteInfo(face,0),sq);sq.getObjects().add(object);sq.getSpecialObjects().add(object);sq.RecalcAllWithNeighbours(true);
        }
        selectedEntity=oldEntity;face=oldFace;createdParts.clear();System.out.println("SCENE before regions");System.out.flush();sceneRegions();
        System.out.println("SCENE after regions");System.out.flush();
        sceneBody.setForwardDirection(orientation.equals("N")?0:-1,orientation.equals("N")?-1:0);
        zombie.Lua.LuaManager.platform=platform;zombie.Lua.LuaManager.env=env;zombie.Lua.LuaManager.thread=thread;
        var globalsPlatform=new J2SEPlatform();var globalsEnv=globalsPlatform.newEnvironment();var globalsThread=new KahluaThread(globalsPlatform,globalsEnv);
        zombie.Lua.LuaManager.platform=globalsPlatform;zombie.Lua.LuaManager.env=globalsEnv;zombie.Lua.LuaManager.thread=globalsThread;
        globalsThread.call(LuaCompiler.loadstring(Files.readString(gamePath.resolve("media/lua/shared/defines.lua")),"native-defines",globalsEnv),null,null,null);
        zombie.ZomboidGlobals.Load();
        zombie.Lua.LuaManager.platform=platform;zombie.Lua.LuaManager.env=env;zombie.Lua.LuaManager.thread=thread;
        zombie.GameTime.getInstance().setMinutesPerDay(60);zombie.GameTime.getInstance().setMultiplier(5);
        sceneBody.getStats().set(zombie.characters.CharacterStat.FATIGUE,.65f);
        sceneBody.getStats().set(zombie.characters.CharacterStat.HUNGER,.1f);sceneBody.getStats().set(zombie.characters.CharacterStat.THIRST,.1f);
        sceneBody.getStats().set(zombie.characters.CharacterStat.ENDURANCE,.8f);
    }
    private static void sceneRegions()throws Exception{
        var calculate=zombie.iso.areas.isoregion.IsoRegions.class.getDeclaredMethod("calculateSquareFlags",IsoGridSquare.class);calculate.setAccessible(true);
        for(int z=0;z<=1;z++)for(int x=5;x<18;x++)for(int y=14;y<26;y++){
            var sq=sceneCell.getGridSquare(x,y,z);if(sq==null)continue;
            sceneRoot.select.reset(x,y,z,true,true);
            sceneRoot.updateExistingSquare(x,y,z,(Byte)calculate.invoke(null,sq));
        }
        var chunks=new ArrayList<zombie.iso.areas.isoregion.data.DataChunk>();sceneRoot.getAllChunks(chunks);
        for(var chunk:chunks){chunk.setDirtyAllActive();sceneRoot.EnqueueDirtyDataChunk(chunk);}
        sceneRoot.processDirtyChunks();sceneBody.getCurrentSquare().ResetIsoWorldRegion();
    }
    private static IsoThumpable sceneCreate(String sprite)throws Exception{
        var sq=sceneCell.getGridSquare(10,20,0);var object=createShelterPart(sprite,sq);
        if(object.isDoor())sceneDoor=object;
        return object;
    }
    private static boolean scenePass(boolean inside)throws Exception{
        int tx=inside?10:10-(sceneFace.equals("W")?1:0),ty=inside?20:20-(sceneFace.equals("N")?1:0);
        var from=sceneBody.getCurrentSquare();boolean arrived=sceneMove(tx+.5,ty+.5,0);
        boolean pass=arrived&&from!=sceneBody.getCurrentSquare();
        System.out.println("PASSAGE actual="+sceneBody.getX()+","+sceneBody.getY()+" target="+tx+","+ty+" result="+pass);
        if(pass)passageCount++;return pass;
    }
    private static boolean sceneMove(double x,double y,double z)throws Exception{
        int tx=(int)Math.floor(x),ty=(int)Math.floor(y);
        var route=new com.sao.engine.SAORouteState();route.setRoute(List.of(new float[]{tx+.5f,ty+.5f,0}));route.requested=true;
        int ticks=0;
        while((sceneBody.getCurrentSquare()!=sceneCell.getGridSquare(tx,ty,(int)z)||Math.hypot(sceneBody.getX()-x,sceneBody.getY()-y)>.35)&&ticks++<100){
            String result=com.sao.engine.SAOMovement.tick(sceneBody,route);
            if(ticks==1)System.out.println("DRIVE "+result+" direction="+sceneBody.playerMoveDir.x+","+sceneBody.playerMoveDir.y);
            if(result.startsWith("Failed")||result.startsWith("THREW"))return false;
            float dx=sceneBody.playerMoveDir.x*.06f,dy=sceneBody.playerMoveDir.y*.06f;
            // The headless scheduler supplies history, not position; native update normally does this.
            sceneBody.setLastX(sceneBody.getX());sceneBody.setLastY(sceneBody.getY());sceneBody.setLastZ(sceneBody.getZ());
            sceneBody.preupdate();sceneBody.moveUnmodded(dx,dy);
            if(ticks==1)System.out.println("STRIDE "+dx+","+dy+" next="+sceneBody.getNextX()+","+sceneBody.getNextY()+" slow="+sceneBody.getSlowFactor());
            sceneBody.postupdate();
            if(ticks==1)System.out.println("POST current="+sceneBody.getX()+","+sceneBody.getY()+","+sceneBody.getZ()+" next="+sceneBody.getNextX()+","+sceneBody.getNextY()+" cellSame="+(sceneBody.getCell()==sceneCell)+" squareSame="+(sceneBody.findCurrentGridSquare()==sceneBody.getCurrentSquare()));
        }
        boolean arrived=sceneBody.getCurrentSquare()==sceneCell.getGridSquare(tx,ty,(int)z)&&Math.hypot(sceneBody.getX()-x,sceneBody.getY()-y)<=.35;
        System.out.println("MOVE actual="+sceneBody.getX()+","+sceneBody.getY()+" target="+x+","+y+" result="+arrived+" ticks="+ticks);
        return arrived;
    }
    private static Object op(String name,Object a,Object b)throws Exception{
        int i=a instanceof Number?((Number)a).intValue():0;
        switch(name){
            case "reset":reset((String)a);return true;
            case "sceneSetup":sceneSetup((String)a,b instanceof String?(String)b:"native-shelter-person");return true;
            case "sceneToggle": {if(sceneDoor==null)return false;boolean old=sceneDoor.IsOpen();sceneDoor.ToggleDoor(sceneBody);return old!=sceneDoor.IsOpen();}
            case "sceneOpen":return sceneDoor!=null&&sceneDoor.IsOpen();
            case "scenePass":return scenePass(Boolean.TRUE.equals(a));
            case "scenePassages":return passageCount;
            case "scenePosition": {var value=zombie.Lua.LuaManager.platform.newTable();value.rawset("x",(double)sceneBody.getX());value.rawset("y",(double)sceneBody.getY());value.rawset("z",(double)sceneBody.getZ());return value;}
            case "sceneMove": {String[] parts=((String)a).split(",");return sceneMove(Double.parseDouble(parts[0]),Double.parseDouble(parts[1]),Double.parseDouble(parts[2]));}
            case "sceneCover": {String[] parts=((String)a).split(",");sceneRegions();return com.sao.engine.SAOShelterConstruction.cover(sceneBody,Integer.parseInt(parts[0]),Integer.parseInt(parts[1]),Integer.parseInt(parts[2]));}
            case "sceneGroundClear": {String[] parts=((String)a).split(",");return com.sao.engine.SAORecoveryPlace.groundClear(sceneBody,Double.parseDouble(parts[0]),Double.parseDouble(parts[1]),Double.parseDouble(parts[2]));}
            case "sceneNeeds": {var value=zombie.Lua.LuaManager.platform.newTable();for(String kind:List.of("HUNGER","THIRST","FATIGUE","ENDURANCE"))value.rawset(kind.toLowerCase(),(double)sceneBody.getStats().get((zombie.characters.CharacterStat)zombie.characters.CharacterStat.class.getField(kind).get(null)));return value;}
            case "sceneAsleep":return sceneBody.isAsleep();
            case "sceneSleep":com.sao.engine.SAONeeds.setShellAsleep(sceneBody,Boolean.TRUE.equals(a));return sceneBody.isAsleep();
            case "sceneSleepTicks": {
                if(!sceneBody.isAsleep())return false;
                IsoPlayer.setInstance(sceneBody);var wake=IsoGameCharacter.class.getDeclaredMethod("updateStats_WakeState");wake.setAccessible(true);
                sleepBefore=sceneBody.getStats().get(zombie.characters.CharacterStat.FATIGUE);
                int ticks=0;while(sceneBody.getStats().get(zombie.characters.CharacterStat.FATIGUE)>.28f&&ticks++<100000)wake.invoke(sceneBody);
                sleepAfter=sceneBody.getStats().get(zombie.characters.CharacterStat.FATIGUE);
                System.out.println("SLEEP_SAMPLE before="+sleepBefore+" after="+sleepAfter+" ticks="+ticks+" actor="+sceneBody.getModData().rawget("SAOPersonId"));
                return sleepAfter<sleepBefore&&sleepAfter<=.3f;
            }
            case "sceneBeginPassage": {
                var rows=com.sao.engine.SAOShelterConstruction.observe(sceneBody,10,20,0);
                System.out.println("CAPTURE rows="+rows.len()+" roof="+sceneCell.getGridSquare(10,20,0).haveRoof+" free="+sceneCell.getGridSquare(10,20,0).isFree(false)+" current="+sceneBody.getX()+","+sceneBody.getY());
                var free=com.sao.engine.SAOShelterConstruction.class.getDeclaredMethod("free",com.sao.engine.SAOIsoPlayerShell.class,IsoGridSquare.class);free.setAccessible(true);
                var visible=com.sao.engine.SAOShelterConstruction.class.getDeclaredMethod("visible",com.sao.engine.SAOIsoPlayerShell.class,IsoGridSquare.class);visible.setAccessible(true);
                var sq=sceneCell.getGridSquare(10,20,0);
                System.out.println("CAPTURE guards free="+free.invoke(null,sceneBody,sq)+" visible="+visible.invoke(null,sceneBody,sq)
                    +" solid="+sq.isSolid()+" trans="+sq.isSolidTrans()+" floor="+sq.isSolidFloor()+" actor="+sceneBody.getModData().rawget("SAOPersonId"));

                for(int n=1;n<=rows.len();n++){
                    var row=(KahluaTable)rows.rawget((double)n);
                    if("door".equals(row.rawget("mode"))&&sceneFace.equals(row.rawget("face"))){
                        sceneCaptureKey=(String)row.rawget("key");sceneCaptureRevision=(String)row.rawget("revision");
                        return com.sao.engine.SAOShelterConstruction.beginPassage(sceneBody,sceneDoor,sceneCaptureKey,sceneCaptureRevision,Boolean.TRUE.equals(a));
                    }
                }
                return null;
            }
            case "scenePassageReceipt":return com.sao.engine.SAOShelterConstruction.passage(sceneBody,(String)a);
            case "sceneRecoveryPlaces": {
                sceneBody.setForwardDirection(1,1);
                var animationField=IsoGameCharacter.class.getDeclaredField("animPlayer");animationField.setAccessible(true);
                ((zombie.core.skinnedmodel.animation.AnimationPlayer)animationField.get(sceneBody)).setAngle((float)Math.PI/4);
                var view=com.sao.engine.SAORecoveryPlace.observe(sceneBody,8);
                var places=view==null?null:(KahluaTable)view.rawget("places");
                var diagnosis=view==null?null:(KahluaTable)view.rawget("diagnostics");
                System.out.println("RECOVERY_QUERY places="+(places==null?-1:places.len())+" room="+sceneBody.getCurrentSquare().getRoom()
                    +" visibility="+(diagnosis==null?null:diagnosis.rawget("groundRejectedVisibility"))+" clearance="+(diagnosis==null?null:diagnosis.rawget("groundRejectedClearance")));
                return view;
            }
            case "sceneRecoveryValid": {
                String[] parts=((String)a).split(",");
                return com.sao.engine.SAOShelterConstruction.recoveryValid(sceneBody,sceneCaptureKey,sceneCaptureRevision,
                    Double.parseDouble(parts[0]),Double.parseDouble(parts[1]),Double.parseDouble(parts[2]),Boolean.TRUE.equals(b));
            }

            case "sceneForgetPassage":com.sao.engine.SAOShelterConstruction.forgetPassage(sceneBody,(String)a);return true;

            case "sceneEnclosed": {sceneRegions();var region=sceneBody.getCurrentSquare().getIsoWorldRegion();return region instanceof zombie.iso.areas.isoregion.regions.IsoWorldRegion r&&r.isEnclosed();}
            case "sceneRoofed": {var region=sceneBody.getCurrentSquare().getIsoWorldRegion();return region!=null&&region.isFullyRoofed();}
            case "sceneRoof":return sceneBody.getCurrentSquare().haveRoof;

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
            case "otherSprite": {String[] x=((String)a).split("\\|");return info(x[0]).getFace(x[1]).getTileInfo(0,0,0).getSpriteName();}
            case "facing":return tileProperties.get(spriteInfo((String)a,0)).get("Facing");
            case "previousStages":return info((String)a).getScript().getPreviousStages().toString();
            case "spriteType":return zombie.iso.sprite.IsoSpriteManager.instance.getSprite((String)a).getType().name();
            case "spriteHasFlag":return zombie.iso.sprite.IsoSpriteManager.instance.getSprite((String)a).getProperties().has(zombie.iso.SpriteDetails.IsoFlagType.valueOf((String)b));
            case "creationFlags": {
                var builder=(KahluaTable)a;
                // Installed ISBuildUtil.setInfo applies these before the object is added.
                created.setCanPassThrough(Boolean.TRUE.equals(builder.rawget("canPassThrough")));
                created.setBlockAllTheSquare(Boolean.TRUE.equals(builder.rawget("blockAllTheSquare")));
                created.setIsThumpable(Boolean.TRUE.equals(builder.rawget("isThumpable")));
                if(sceneCell!=null){
                    var sq=created.getSquare();sq.getObjects().add(created);sq.getSpecialObjects().add(created);
                    sq.RecalcAllWithNeighbours(true);sceneRegions();
                }
                return true;
            }
            case "spriteHasProp":return zombie.iso.sprite.IsoSpriteManager.instance.getSprite((String)a).getProperties().has(zombie.core.properties.IsoPropertyType.valueOf((String)b));

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
            case "factory":created=sceneCell==null?createShelterPart((String)a,null):sceneCreate((String)a);return true;
            case "createdCount":return createdParts.size();
            case "createdGrid":return createdParts.size()==2&&createdParts.get(0).getSprite().getSpriteGrid()==createdParts.get(1).getSprite().getSpriteGrid();
            case "createdEntity":return created.getEntityScript().getFullName();
            case "materialCategory":return com.sao.engine.SAONeeds.wantsMaterial(items.get(i),(String)b);
            default:throw new IllegalArgumentException(name);
        }
    }

    private static void checkPort(String name,boolean pass) {
        System.out.println("JAVA "+name+"="+pass);if(!pass)throw new AssertionError(name);
    }
    private static void nativeConstructionFlags(IsoThumpable object)throws Exception{
        var p=object.getProperties();boolean canPass=true;
        for(var flag:List.of(zombie.iso.SpriteDetails.IsoFlagType.solid,zombie.iso.SpriteDetails.IsoFlagType.solidtrans,
            zombie.iso.SpriteDetails.IsoFlagType.doorN,zombie.iso.SpriteDetails.IsoFlagType.doorW,
            zombie.iso.SpriteDetails.IsoFlagType.WallN,zombie.iso.SpriteDetails.IsoFlagType.WallNTrans,
            zombie.iso.SpriteDetails.IsoFlagType.WallW,zombie.iso.SpriteDetails.IsoFlagType.WallWTrans,zombie.iso.SpriteDetails.IsoFlagType.WallNW))
            if(p.has(flag))canPass=false;
        var builder=zombie.Lua.LuaManager.platform.newTable();builder.rawset("canPassThrough",canPass);
        builder.rawset("blockAllTheSquare",p.has(zombie.core.properties.IsoPropertyType.BLOCKS_PLACEMENT));
        builder.rawset("isThumpable",info(selectedEntity).getScript().getClass().getMethod("getIsThumpable").invoke(info(selectedEntity).getScript()));
        created=object;op("creationFlags",builder,null);
    }
    private static void structuralDoor()throws Exception{
        face="N";selectedEntity="Base.WoodDoorFrameLvl1";nativeConstructionFlags(sceneCreate(spriteInfo("N",0)));
        selectedEntity="Base.WoodenDoorLvl1";nativeConstructionFlags(sceneCreate(spriteInfo("N",0)));
    }
    private static void removeNorthWall(int x,int y){
        var sq=sceneCell.getGridSquare(x,y,0);
        for(int index=sq.getObjects().size()-1;index>=0;index--){
            var object=sq.getObjects().get(index);
            if(object.getEntityScript()!=null&&object.getEntityScript().getFullName().contains("Wall")){
                sq.getObjects().remove(index);sq.getSpecialObjects().remove(object);
            }
        }
        sq.RecalcAllWithNeighbours(true);
    }
    private static zombie.iso.objects.IsoDoor mapDoor(int x,int y){
        var sq=sceneCell.getGridSquare(x,y,0);var door=new zombie.iso.objects.IsoDoor(sceneCell,sq,info("Base.WoodenDoorLvl1").getFace("N").getTileInfo(0,0,0).getSpriteName(),true);
        door.setOpenSprite(zombie.iso.sprite.IsoSpriteManager.instance.getSprite(info("Base.WoodenDoorLvl1").getFace("N_OPEN").getTileInfo(0,0,0).getSpriteName()));
        sq.getObjects().add(door);sq.getSpecialObjects().add(door);sq.RecalcAllWithNeighbours(true);return door;
    }
    private static void focusedNative(String mode)throws Exception{
        if(mode.equals("materials")){
            reset("Base.WoodenDoorLvl1");
            var category=Class.forName("com.sao.engine.SAOWorldSources$ItemRow").getDeclaredMethod("categories",InventoryItem.class,zombie.entity.components.fluids.FluidContainer.class,float.class,boolean.class);category.setAccessible(true);
            for(String kind:List.of("hinge","doorknob")){
                String type=kind.equals("hinge")?"Base.Hinge":"Base.Doorknob";InventoryItem exact=null,plank=null;
                for(var item:items.values()){if(item.getFullType().equals(type))exact=item;if(item.getFullType().equals("Base.Plank"))plank=item;}
                checkPort("native_"+kind+"_exact_category",exact!=null&&com.sao.engine.SAONeeds.wantsMaterial(exact,kind)&&!com.sao.engine.SAONeeds.wantsMaterial(plank,kind));
                checkPort("native_"+kind+"_world_source_projection",((List<?>)category.invoke(null,exact,null,0f,false)).contains(kind));
                exact.setIsCraftingConsumed(true);checkPort("native_"+kind+"_consumed_refuses",!com.sao.engine.SAONeeds.wantsMaterial(exact,kind));
            }
            return;
        }
        sceneSetup("N","native-shelter-control");
        if(mode.equals("map-door-closed")){
            var door=mapDoor(10,20);removeNorthWall(10,21);sceneRegions();
            checkPort("native_closed_door_breach_approach",sceneMove(10.5,21.5,0));
            var visible=com.sao.engine.SAOShelterConstruction.class.getDeclaredMethod("visible",com.sao.engine.SAOIsoPlayerShell.class,IsoGridSquare.class);visible.setAccessible(true);
            boolean own=(Boolean)visible.invoke(null,sceneBody,sceneCell.getGridSquare(10,20,0));
            boolean hidden=(Boolean)visible.invoke(null,sceneBody,sceneCell.getGridSquare(10,19,0));
            boolean breachVisible=(Boolean)visible.invoke(null,sceneBody,sceneCell.getGridSquare(9,21,0));
            System.out.println("CLOSED_DOOR ownVisible="+own+" exteriorVisible="+hidden+" breachVisible="+breachVisible+" open="+door.IsOpen());
            checkPort("native_closed_door_observation_bound",own&&!hidden&&breachVisible&&!door.IsOpen());
            var rows=com.sao.engine.SAOShelterConstruction.observe(sceneBody,10,21,0);boolean wall=false,observedDoor=false;
            for(int n=1;n<=rows.len();n++){
                var row=(KahluaTable)rows.rawget((double)n);
                System.out.println("CLOSED_DOOR row="+row.rawget("x")+","+row.rawget("y")+" face="+row.rawget("face")+" mode="+row.rawget("mode"));
                if(Double.valueOf(10).equals(row.rawget("x"))&&Double.valueOf(21).equals(row.rawget("y"))&&"W".equals(row.rawget("face")))wall="wall-frame".equals(row.rawget("mode"));
                if(Double.valueOf(10).equals(row.rawget("x"))&&Double.valueOf(20).equals(row.rawget("y"))&&"N".equals(row.rawget("face")))
                    observedDoor="door".equals(row.rawget("mode"))&&Double.valueOf(10).equals(row.rawget("approachX"))
                        &&Double.valueOf(20).equals(row.rawget("approachY"))&&Double.valueOf(10).equals(row.rawget("insideX"))
                        &&Double.valueOf(20).equals(row.rawget("insideY"))
                        &&com.sao.engine.SAOShelterConstruction.door(sceneBody,(String)row.rawget("key"),(String)row.rawget("revision"))==door;
            }
            checkPort("native_closed_door_prevents_redundant_door_frame",wall);
            checkPort("native_closed_door_row_uses_observed_inside_approach",observedDoor);return;
        }
        if(mode.equals("map-door")){
            var door=mapDoor(10,20);removeNorthWall(11,20);sceneRegions();
            door.ToggleDoor(sceneBody);checkPort("native_map_door_visible_opening",door.IsOpen());
            var rows=com.sao.engine.SAOShelterConstruction.observe(sceneBody,10,20,0);boolean occupied=false,breach=false;
            System.out.println("MAP_DOOR rows="+rows.len()+" health="+door.getHealth()+" free="+sceneBody.getCurrentSquare().isFree(false)
                +" solid="+sceneBody.getCurrentSquare().isSolid()+" trans="+sceneBody.getCurrentSquare().isSolidTrans()+" floor="+sceneBody.getCurrentSquare().isSolidFloor());
            var free=com.sao.engine.SAOShelterConstruction.class.getDeclaredMethod("free",com.sao.engine.SAOIsoPlayerShell.class,IsoGridSquare.class);free.setAccessible(true);
            var visible=com.sao.engine.SAOShelterConstruction.class.getDeclaredMethod("visible",com.sao.engine.SAOIsoPlayerShell.class,IsoGridSquare.class);visible.setAccessible(true);
            System.out.println("MAP_DOOR guards roof="+sceneBody.getCurrentSquare().haveRoof+" free="+free.invoke(null,sceneBody,sceneBody.getCurrentSquare())
                +" visible="+visible.invoke(null,sceneBody,sceneBody.getCurrentSquare())+" eye="+sceneBody.getCurrentSquare().getX()+","+sceneBody.getCurrentSquare().getY());
            var identity=Class.forName("com.sao.engine.SAOConceptObservation").getDeclaredMethod("actor",com.sao.engine.SAOIsoPlayerShell.class);identity.setAccessible(true);
            System.out.println("MAP_DOOR actor="+identity.invoke(null,sceneBody)+" world="+sceneBody.isExistInTheWorld()+" cell="+(sceneBody.getCell()==zombie.iso.IsoWorld.instance.currentCell)
                +" grid="+(sceneBody.findCurrentGridSquare()==sceneBody.getCurrentSquare())+" player="+Arrays.asList(IsoPlayer.players).contains(sceneBody));
            for(int n=1;n<=rows.len();n++){
                var row=(KahluaTable)rows.rawget((double)n);
                System.out.println("MAP_DOOR row="+row.rawget("x")+","+row.rawget("y")+" face="+row.rawget("face")+" mode="+row.rawget("mode"));
                if(Double.valueOf(10).equals(row.rawget("x"))&&Double.valueOf(20).equals(row.rawget("y"))&&"N".equals(row.rawget("face")))
                    occupied="door".equals(row.rawget("mode"))&&com.sao.engine.SAOShelterConstruction.door(sceneBody,(String)row.rawget("key"),(String)row.rawget("revision"))==door;
                if(Double.valueOf(11).equals(row.rawget("x"))&&Double.valueOf(20).equals(row.rawget("y"))&&"N".equals(row.rawget("face")))breach="wall-frame".equals(row.rawget("mode"));
            }
            checkPort("native_map_door_is_observed_occupied",occupied);checkPort("native_map_door_preserves_other_wall_breach",breach);return;
        }
        structuralDoor();
        if(mode.equals("door-admission")){
            var rows=com.sao.engine.SAOShelterConstruction.observe(sceneBody,10,20,0);boolean closed=false;
            for(int n=1;n<=rows.len();n++){
                var row=(KahluaTable)rows.rawget((double)n);
                if("door".equals(row.rawget("mode"))&&"N".equals(row.rawget("face"))){
                    sceneCaptureKey=(String)row.rawget("key");sceneCaptureRevision=(String)row.rawget("revision");
                    closed=com.sao.engine.SAOShelterConstruction.door(sceneBody,sceneCaptureKey,sceneCaptureRevision)==sceneDoor&&!sceneDoor.IsOpen();
                }
            }
            checkPort("native_constructed_closed_door_observe_and_lookup",closed);
            checkPort("native_closed_door_cannot_admit_passage",com.sao.engine.SAOShelterConstruction.beginPassage(sceneBody,sceneDoor,sceneCaptureKey,sceneCaptureRevision,false)==null);
            sceneDoor.ToggleDoor(sceneBody);checkPort("native_constructed_door_opening_observed",sceneDoor.IsOpen());
            String token=com.sao.engine.SAOShelterConstruction.beginPassage(sceneBody,sceneDoor,sceneCaptureKey,sceneCaptureRevision,false);
            checkPort("native_opening_admits_exact_selected_capture",token!=null);com.sao.engine.SAOShelterConstruction.forgetPassage(sceneBody,token);
            var outside=sceneCell.getGridSquare(10,19,0);var person=MovementCrossingProbe.class.getDeclaredMethod("person",zombie.iso.IsoCell.class);person.setAccessible(true);
            var other=(com.sao.engine.SAOIsoPlayerShell)person.invoke(null,sceneCell);
            other.getCurrentSquare().getMovingObjects().remove(other);
            other.setX(10.5f);other.setY(19.5f);other.setCurrent(outside);other.setSquare(outside);outside.getMovingObjects().add(other);sceneCell.getObjectList().add(other);
            var visible=com.sao.engine.SAOShelterConstruction.class.getDeclaredMethod("visible",com.sao.engine.SAOIsoPlayerShell.class,IsoGridSquare.class);visible.setAccessible(true);
            var free=com.sao.engine.SAOShelterConstruction.class.getDeclaredMethod("free",com.sao.engine.SAOIsoPlayerShell.class,IsoGridSquare.class);free.setAccessible(true);
            boolean fromFree=(Boolean)free.invoke(null,sceneBody,sceneBody.getCurrentSquare());
            boolean lookup=com.sao.engine.SAOShelterConstruction.door(sceneBody,sceneCaptureKey,sceneCaptureRevision)==sceneDoor;
            System.out.println("OCCUPIED_EXTERIOR fromFree="+fromFree+" lookup="+lookup);
            checkPort("native_occupied_exterior_is_visible_but_unavailable",fromFree&&lookup&&(Boolean)visible.invoke(null,sceneBody,outside)&&!(Boolean)free.invoke(null,sceneBody,outside));
            checkPort("native_occupied_exterior_refuses_selected_capture",com.sao.engine.SAOShelterConstruction.beginPassage(sceneBody,sceneDoor,sceneCaptureKey,sceneCaptureRevision,false)==null);
            outside.getMovingObjects().remove(other);sceneCell.getObjectList().remove(other);
            zombie.iso.sprite.IsoSprite curtainSprite=null;
            for(int n=0;n<128;n++){
                var sprite=zombie.iso.sprite.IsoSpriteManager.instance.getSprite("fixtures_windows_curtains_01_"+n);
                if(sprite!=null&&sprite.getType()==zombie.iso.SpriteDetails.IsoObjectType.curtainS){curtainSprite=sprite;break;}
            }
            if(curtainSprite==null)throw new IllegalStateException("native south curtain sprite absent");
            var curtain=new zombie.iso.objects.IsoCurtain(sceneCell,outside,curtainSprite,true,true);
            outside.getObjects().add(curtain);outside.getSpecialObjects().add(curtain);outside.RecalcAllWithNeighbours(true);curtain.ToggleDoor(sceneBody);
            boolean hidden=!(Boolean)visible.invoke(null,sceneBody,outside),clear=(Boolean)free.invoke(null,sceneBody,outside);
            fromFree=(Boolean)free.invoke(null,sceneBody,sceneBody.getCurrentSquare());
            lookup=com.sao.engine.SAOShelterConstruction.door(sceneBody,sceneCaptureKey,sceneCaptureRevision)==sceneDoor;
            System.out.println("HIDDEN_EXTERIOR visible="+!hidden+" free="+clear+" fromFree="+fromFree+" lookup="+lookup+" curtainOpen="+curtain.IsOpen()+" type="+curtain.getType());
            checkPort("native_hidden_exterior_is_clear_but_unobserved",hidden&&clear&&fromFree&&lookup&&!curtain.IsOpen()&&sceneDoor.IsOpen());
            checkPort("native_hidden_exterior_refuses_selected_capture",com.sao.engine.SAOShelterConstruction.beginPassage(sceneBody,sceneDoor,sceneCaptureKey,sceneCaptureRevision,false)==null);return;
        }
        if(mode.equals("outside")){
            var rows=com.sao.engine.SAOShelterConstruction.observe(sceneBody,10,20,0);
            for(int n=1;n<=rows.len();n++){var row=(KahluaTable)rows.rawget((double)n);if("door".equals(row.rawget("mode"))&&"N".equals(row.rawget("face"))){sceneCaptureKey=(String)row.rawget("key");sceneCaptureRevision=(String)row.rawget("revision");}}
            var view=(KahluaTable)op("sceneRecoveryPlaces",null,null);var places=(KahluaTable)view.rawget("places");boolean safe=places.len()>0;
            for(int n=1;n<=places.len();n++)if("ground:10:20:0".equals(((KahluaTable)places.rawget((double)n)).rawget("key")))safe=false;
            checkPort("native_safe_ground_place_excludes_doorway",safe);
            checkPort("native_shelter_outside_place_refuses",!com.sao.engine.SAOShelterConstruction.recoveryValid(sceneBody,sceneCaptureKey,sceneCaptureRevision,10.5,19.5,0,false));return;
        }
        removeNorthWall(13,20);var other=mapDoor(13,20);sceneRegions();
        checkPort("native_other_door_approach",sceneMove(13.5,20.5,0));other.ToggleDoor(sceneBody);
        checkPort("native_other_door_opened",other.IsOpen());checkPort("native_selected_door_approach",sceneMove(10.5,20.5,0));
        sceneDoor.ToggleDoor(sceneBody);String token=(String)op("sceneBeginPassage",false,null);checkPort("native_selected_capture_admitted",token!=null);
        boolean around=sceneMove(12.5,21.5,0)&&sceneMove(13.5,20.5,0)&&sceneMove(13.5,19.5,0)&&sceneMove(10.5,19.5,0);
        checkPort("native_route_around_arrival_does_not_credit_selected_door",around&&!com.sao.engine.SAOShelterConstruction.passage(sceneBody,token));
        com.sao.engine.SAOShelterConstruction.forgetPassage(sceneBody,token);
        token=(String)op("sceneBeginPassage",true,null);checkPort("native_inward_capture_admitted",token!=null);
        var inside=sceneCell.getGridSquare(10,20,0);
        // Known-bad control: coordinates/current are set before stationary native physics.
        sceneBody.setX(10.5f);sceneBody.setY(20.5f);sceneBody.setCurrent(inside);sceneBody.setSquare(inside);
        sceneBody.setLastX(sceneBody.getX());sceneBody.setLastY(sceneBody.getY());sceneBody.setLastZ(0);
        sceneBody.preupdate();sceneBody.postupdate();
        checkPort("native_setter_before_postupdate_does_not_credit_passage",!com.sao.engine.SAOShelterConstruction.passage(sceneBody,token));
    }
    public static void main(String[] args)throws Exception{
        J2SEPlatform platform=new J2SEPlatform();KahluaTable env=platform.newEnvironment();KahluaThread thread=new KahluaThread(platform,env);thread.debugOwnerThread=Thread.currentThread();
        zombie.Lua.LuaManager.env=env;zombie.Lua.LuaManager.thread=thread;
        zombie.Lua.LuaManager.caller=new se.krka.kahlua.integration.LuaCaller(new se.krka.kahlua.converter.KahluaConverterManager());
        env.rawset("print",(JavaFunction)(f,n)->{for(int i=0;i<n;i++)System.out.print((i==0?"":"\t")+f.get(i));System.out.println();return 0;});
        thread.call(LuaCompiler.loadstring("ISTimedActionQueue={queues={},getTimedActionQueue=function() return {queue={}} end}","empty",env),null,null,null);
        initialise(Path.of(args[0]));
        if(args.length>1&&args[1].equals("--focused-native")){focusedNative(args[2]);return;}
        if(args.length>1&&args[1].equals("--scene-only")){sceneSetup("N","native-shelter-person");System.out.println("SCENE READY");return;}
        if(args.length==1){
            for(String id:entities.keySet()){
                reset(id);System.out.println("ENTITY "+id+" recipe="+selected.getScriptObjectFullType()+" nativeEligible="+logic.canPerformCurrentRecipe());
                System.out.println("PAYMENT "+logic.performCurrentRecipe());op("process",null,null);
                for(String orientation:List.of("N","W")){
                    face=orientation;createdParts.clear();createShelterPart(spriteInfo(orientation,0),null);
                    System.out.println("FACTORY face="+orientation+" count="+createdParts.size()+" entity="+createdParts.get(0).getEntityScript().getFullName()+" north="+createdParts.get(0).getNorth());
                }
            }return;
        }
        env.rawset("__nativeShelter",(JavaFunction)(f,n)->{try{Object result=op((String)f.get(0),n>1?f.get(1):null,n>2?f.get(2):null);
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
