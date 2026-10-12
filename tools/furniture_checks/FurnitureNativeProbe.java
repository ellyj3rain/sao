import java.lang.reflect.Field;
import java.nio.file.*;
import java.util.*;
import se.krka.kahlua.vm.*;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import zombie.Lua.LuaManager;
import zombie.iso.*;
import zombie.iso.sprite.*;
import zombie.iso.SpriteDetails.IsoFlagType;
import zombie.inventory.*;
import zombie.characters.CharacterTimedActions.*;
import java.nio.ByteBuffer;

/** Native furniture/containers/squares and installed moveable Lua; isolated
 * scene, controlled time/network/queue and native action-end flags. */
public final class FurnitureNativeProbe {
    private static int retainedItemId=9000;
    private static final class FixtureDictionary extends zombie.world.DictionaryData {
        void admit(java.util.Map<String,zombie.world.ItemInfo> pending)throws Exception {nextInfoId=2000;parseInfoLoadList(pending);parseCurrentInfoSet();}
    }
    static void chunk(KahluaThread t,KahluaTable e,Path p)throws Exception {
        Object[] r=t.pcall(LuaCompiler.loadstring(Files.readString(p),p.toString(),e),new Object[0]);
        if(!Boolean.TRUE.equals(r[0]))throw new AssertionError(Arrays.toString(r));
    }
    static Field field(Class<?> c,String n)throws Exception{var f=c.getDeclaredField(n);f.setAccessible(true);return f;}
    public static void main(String[] args)throws Exception {
        Path game=Path.of(args[0]),root=Path.of(args[1]);
        zombie.ZomboidFileSystem.instance.setCacheDir(System.getProperty("sao.furnitureCache"));
        var boot=MovementCrossingProbe.class.getDeclaredMethod("boot");boot.setAccessible(true);var cell=(IsoCell)boot.invoke(null);
        var person=MovementCrossingProbe.class.getDeclaredMethod("person",IsoCell.class);person.setAccessible(true);
        var body=(com.sao.engine.SAOIsoPlayerShell)person.invoke(null,cell);body.playerIndex=0;
        var pm=zombie.pathfind.PolygonalMap2.instance;
        var ct=Class.forName("zombie.pathfind.PolygonalMap2$PMThread").getDeclaredConstructor(zombie.pathfind.PolygonalMap2.class);ct.setAccessible(true);
        field(zombie.pathfind.PolygonalMap2.class,"thread").set(pm,ct.newInstance(pm));
        var aliases=new HashMap<String,ArrayList<String>>();
        for(String p:List.of("IsMoveAble","MoveType","PickUpWeight","CustomName","GroupName","IsoType","container","Facing","BedType"))
            aliases.put(p,new ArrayList<>(List.of("true","Object","10","Fixture","Furniture","IsoObject","crate","N","S","E","W","goodBed")));
        zombie.core.TilePropertyAliasMap.instance.Generate(aliases);
        var platform=new se.krka.kahlua.j2se.J2SEPlatform();var env=platform.newEnvironment();var thread=new KahluaThread(platform,env);
        thread.debugOwnerThread=Thread.currentThread();LuaManager.platform=platform;LuaManager.env=env;LuaManager.thread=thread;
        zombie.ui.UIManager.defaultthread=thread;
        LuaManager.converterManager=new se.krka.kahlua.converter.KahluaConverterManager();zombie.Lua.KahluaNumberConverter.install(LuaManager.converterManager);
        LuaManager.caller=new se.krka.kahlua.integration.LuaCaller(LuaManager.converterManager);
        LuaManager.exposer=new LuaManager.Exposer(LuaManager.converterManager,platform,env);LuaManager.exposer.exposeAll();
        for(Class<?> c:new Class<?>[]{com.sao.engine.SAOIsoPlayerShell.class,zombie.util.list.PZArrayList.class,ArrayList.class,
            zombie.inventory.types.Moveable.class,com.sao.bridge.SAOBridge.class}){
            LuaManager.exposer.setExposed(c);LuaManager.exposer.exposeLikeJava(c,env);
        }
        // Select the exact installed native item block in an isolated dictionary.
        zombie.world.WorldDictionary.StartScriptLoading();
        for(String n:List.of("currentLoadFileMod","currentLoadFileAbsPath","currentLoadFileName"))field(zombie.scripting.ScriptManager.class,n).set(null,"pz-vanilla");
        var source=Files.readString(game.resolve("media/scripts/generated/items/moveable.txt"));
        int start=source.indexOf("    item Moveable\n");if(start<0)start=source.indexOf("    item Moveable\r\n");
        int end=source.indexOf("    }",start)+5;
        zombie.scripting.ScriptManager.instance.ParseScript(zombie.scripting.ScriptLoadMode.Init,"module Moveables { "+source.substring(start,end)+" }");
        zombie.scripting.ScriptManager.instance.moduleMap.get("Moveables").items.LoadScripts(zombie.scripting.ScriptLoadMode.Init);
        // The isolated bucket fixture omits normal Translator name projection.
        zombie.scripting.ScriptManager.instance.moduleMap.get("Moveables").getItem("Moveable").setDisplayName("Moveable");
        String normals=Files.readString(game.resolve("media/scripts/generated/items/normal.txt"));
        int nailStart=normals.indexOf("    item Nails\n");if(nailStart<0)nailStart=normals.indexOf("    item Nails\r\n");
        int nailEnd=normals.indexOf("    }",nailStart)+5;
        zombie.scripting.ScriptManager.instance.ParseScript(zombie.scripting.ScriptLoadMode.Init,"module Base { "+normals.substring(nailStart,nailEnd)+" }");
        var base=zombie.scripting.ScriptManager.instance.moduleMap.get("Base");base.items.LoadScripts(zombie.scripting.ScriptLoadMode.Init);base.getItem("Nails").setDisplayName("Nails");
        var loadList=zombie.world.WorldDictionary.class.getDeclaredMethod("getItemLoadList");loadList.setAccessible(true);
        var dictionary=new FixtureDictionary();field(zombie.world.WorldDictionary.class,"data").set(null,dictionary);
        dictionary.admit((java.util.Map<String,zombie.world.ItemInfo>)loadList.invoke(null));
        System.out.println("FACTORY_DIAGNOSTIC script="+zombie.scripting.ScriptManager.instance.FindItem("Moveables.Moveable")+
            " item="+InventoryItemFactory.CreateItem("Moveables.Moveable"));
        env.rawset("__body",body);env.rawset("__cell",cell);env.rawset("__bridge",com.sao.bridge.SAOBridge.INSTANCE);
        env.rawset("require",(JavaFunction)(f,n)->f.push(platform.newTable()));
        env.rawset("print",(JavaFunction)(f,n)->{var values=new ArrayList<String>();for(int i=0;i<n;i++)values.add(String.valueOf(f.get(i)));System.out.println(String.join(" ",values));return 0;});
        env.rawset("__check",(JavaFunction)(f,n)->{System.out.println("CHECK "+f.get(0)+"="+f.get(1));if(!Boolean.TRUE.equals(f.get(1)))throw new AssertionError(f.get(0));return 0;});
        env.rawset("__fixture",(JavaFunction)(f,n)->{
            try {
                String family=(String)f.get(0);boolean filled=Boolean.TRUE.equals(f.get(1));
                for(int x=7;x<=17;x++)for(int y=16;y<=25;y++) {
                    var s=cell.getGridSquare(x,y,0);s.getObjects().clear();s.getSpecialObjects().clear();
                    var floor=new IsoObject(cell,s,IsoSpriteManager.instance.AddSprite("fixtures_floor_01_0",5100));
                    floor.getSprite().name="fixtures_floor_01_0";
                    floor.getSprite().getProperties().set(IsoFlagType.solidfloor);s.getObjects().add(floor);s.RecalcProperties();s.setSolidFloor(true);
                }
                int count=family.equals("single")?1:2;
                IsoSpriteGrid grid=family.equals("grid")?new IsoSpriteGrid(1,2):null;
                var objects=platform.newTable();
                for(int i=0;i<count;i++) {
                    String name=family.equals("linked")?"location_business_office_generic_01_"+(40+i):"fixtures_furniture_01_"+i;
                    var spr=IsoSpriteManager.instance.AddSprite(name,5200+i);spr.name=name;
                    for(String[] kv:new String[][]{{"IsMoveAble","true"},{"MoveType","Object"},{"PickUpWeight","10"},{"CustomName","Fixture"},{"GroupName","Furniture"},{"IsoType","IsoObject"}})spr.getProperties().set(kv[0],kv[1]);
                    if(filled)spr.getProperties().set("container","crate");
                    spr.getProperties().set(IsoFlagType.solidtrans);
                    if(grid!=null){grid.setSprite(0,i,spr);spr.setSpriteGrid(grid);}
                    if(i==0){var item=InventoryItemFactory.CreateItem("Moveables."+name);
                        System.out.println("SPRITE_FACTORY_DIAGNOSTIC "+name+" item="+item+" class="+(item==null?"nil":item.getClass())+
                            " read="+(item instanceof zombie.inventory.types.Moveable mov&&mov.ReadFromWorldSprite(name)));}
                    var square=cell.getGridSquare(10,20-(family.equals("linked")?i:-i),0);
                    var object=new IsoObject(cell,square,spr);square.getObjects().add(object);square.RecalcProperties();
                    if(filled){var c=new ItemContainer("crate",square,object);object.setContainer(c);
                        var item=InventoryItemFactory.CreateItem("Base.Nails");item.setID(++retainedItemId);c.AddItem(item);env.rawset("__item"+i,item);}
                    objects.rawset((double)i+1,object);
                }
                if(grid!=null)grid.validate();
                body.setX(9.5f);body.setY(20.5f);body.setZ(0);body.setCurrent(cell.getGridSquare(9,20,0));
                if(body.getSquare()!=null)body.getSquare().getMovingObjects().remove(body);
                body.setSquare(body.getCurrentSquare());body.setLast(body.getCurrentSquare());
                body.getCurrentSquare().getMovingObjects().add(body);
                if(!cell.getObjectList().contains(body))cell.getObjectList().add(body);
                body.setAsleep(false);body.setOnBed(false);body.setIsResting(false);body.setIgnoreMovement(false);
                body.setSitOnFurnitureObject(null);body.getCharacterActions().clear();
                body.clearVariable("OnBedStarted");body.clearVariable("OnBedAnim");body.clearVariable("forceGetUp");
                field(zombie.ai.StateMachine.class,"currentState").set(body.getStateMachine(),zombie.ai.states.IdleState.instance());
                env.rawset("__objects",objects);return f.push(true);
            }catch(Exception e){throw new IllegalStateException(e);}
        });
        env.rawset("__nativeAction",(JavaFunction)(f,n)->{
            try {var table=(KahluaTable)f.get(0);var action=table.rawget("action") instanceof LuaTimedActionNew old?old:new LuaTimedActionNew(table,body);
                field(LuaTimedActionNew.class,"started").setBoolean(action,true);field(BaseAction.class,"started").setBoolean(action,true);
                action.setCurrentTime(((Number)table.rawget("maxTime")).floatValue());table.rawset("action",action);return f.push(action);
            }catch(Exception e){throw new IllegalStateException(e);}
        });
        env.rawset("__finish",(JavaFunction)(f,n)->{
            var table=(KahluaTable)f.get(0);var action=(LuaTimedActionNew)table.rawget("action");
            action.perform();action.complete();body.getCharacterActions().remove(action);return f.push(true);
        });
        env.rawset("__nativeStop",(JavaFunction)(f,n)->{
            var table=(KahluaTable)f.get(0);var action=(LuaTimedActionNew)table.rawget("action");
            if(action!=null){action.stop();body.getCharacterActions().remove(action);}return f.push(true);
        });
        env.rawset("__roundtrip",(JavaFunction)(f,n)->{
            try {ByteBuffer bytes=ByteBuffer.allocate(8388608);((KahluaTable)f.get(0)).save(bytes);bytes.flip();
            var result=platform.newTable();result.load(bytes,zombie.iso.IsoWorld.WorldVersion);return f.push(result);
            }catch(Exception e){throw new IllegalStateException(e);}
        });
        env.rawset("__itemRoundtrip",(JavaFunction)(f,n)->{
            try {var item=(InventoryItem)f.get(0);ByteBuffer bytes=ByteBuffer.allocate(1048576);item.saveWithSize(bytes,false);bytes.flip();
                return f.push(InventoryItem.loadItem(bytes,zombie.iso.IsoWorld.WorldVersion));
            }catch(Exception e){throw new IllegalStateException(e);}
        });
        env.rawset("__position",(JavaFunction)(f,n)->{
            if(body.getSquare()!=null)body.getSquare().getMovingObjects().remove(body);
            float x=((Number)f.get(0)).floatValue(),y=((Number)f.get(1)).floatValue();
            body.setX(x);body.setY(y);body.setCurrent(cell.getGridSquare((int)Math.floor(x),(int)Math.floor(y),0));
            body.setSquare(body.getCurrentSquare());body.getSquare().getMovingObjects().add(body);return f.push(true);
        });
        env.rawset("__human",(JavaFunction)(f,n)->{body.setNpc(false);zombie.characters.IsoPlayer.players[0]=body;
            zombie.characters.IsoPlayer.setInstance(body);return f.push(true);});
        env.rawset("__computedRoute",(JavaFunction)(f,n)->{
            try {var method=com.sao.bridge.SAOBridge.class.getDeclaredMethod("routeState",com.sao.engine.SAOIsoPlayerShell.class);method.setAccessible(true);
                var route=(com.sao.engine.SAORouteState)method.invoke(com.sao.bridge.SAOBridge.INSTANCE,body);
                var nodes=new ArrayList<float[]>();for(int i=2;i+1<n;i+=2)nodes.add(new float[]{((Number)f.get(i)).floatValue()+.5f,((Number)f.get(i+1)).floatValue()+.5f,0});
                nodes.add(new float[]{((Number)f.get(0)).floatValue()+.5f,((Number)f.get(1)).floatValue()+.5f,0});route.setRoute(nodes);return f.push(true);
            }catch(Exception e){throw new IllegalStateException(e);}
        });
        env.rawset("__nativeFoot",(JavaFunction)(f,n)->{
            // Existing shelter fixture's bounded stride, native foot collision.
            float dx=body.playerMoveDir.x*.06f,dy=body.playerMoveDir.y*.06f;
            body.setLastX(body.getX());body.setLastY(body.getY());body.setLastZ(body.getZ());
            body.preupdate();body.moveUnmodded(dx,dy);body.postupdate();return f.push(true);
        });
        env.rawset("__bedEvent",(JavaFunction)(f,n)->{
            try {
                var table=(KahluaTable)f.get(0);
                var skin=RecoveryPoseProbe.skin(game);OrientationProbe.animation(body,skin);
                var group=zombie.characters.action.ActionGroup.getActionGroup("player");body.getActionContext().setGroup(group);
                var set=new zombie.core.skinnedmodel.advancedanimation.AnimationSet();set.name="player";
                var bedState=new zombie.core.skinnedmodel.advancedanimation.AnimState();bedState.name="onbed";bedState.set=set;
                for(String file:List.of("OnBedAwake.xml","OnBedAsleep.xml")) {
                    var parsed=zombie.core.skinnedmodel.advancedanimation.AnimNode.Parse(game.resolve("media/AnimSets/player/onbed/"+file).toString());
                    parsed.parentState=bedState;bedState.addNode(parsed);
                }
                set.states.put("onbed",bedState);body.getAdvancedAnimator().setAnimSet(set);
                thread.call(table.rawget("waitToStart"),table,null,null);thread.call(table.rawget("start"),table,null,null);
                field(zombie.ai.StateMachine.class,"currentState").set(body.getStateMachine(),zombie.ai.states.PlayerOnBedState.instance());
                zombie.ai.states.PlayerOnBedState.instance().enter(body);
                var node=zombie.core.skinnedmodel.advancedanimation.AnimNode.Parse(game.resolve("media/AnimSets/player/onbed/GetOnBed_FootRight.xml").toString());
                boolean delivered=false;
                for(var event:node.events)if(event.eventName.equalsIgnoreCase("OnBedStarted")) {
                    zombie.ai.states.PlayerOnBedState.instance().animEvent(body,null,null,event);delivered=true;
                }
                body.getAdvancedAnimator().setState("onbed",List.of());OrientationProbe.animate(body,60);
                return f.push(delivered && body.getVariableBoolean("OnBedStarted") && body.isOnBed());
            }catch(Exception e){throw new IllegalStateException(e);}
        });
        env.rawset("__animate",(JavaFunction)(f,n)->{OrientationProbe.animate(body,60);return f.push(true);});
        env.rawset("__nativeSleep",(JavaFunction)(f,n)->{
            try {
                zombie.ZomboidGlobals.Load();zombie.GameTime.getInstance().setMinutesPerDay(60);zombie.GameTime.getInstance().setMultiplier(5);
                zombie.characters.IsoPlayer.setInstance(body);
                var wake=zombie.characters.IsoGameCharacter.class.getDeclaredMethod("updateStats_WakeState");wake.setAccessible(true);
                float before=body.getStats().get(zombie.characters.CharacterStat.FATIGUE);int ticks=0;
                while(body.getStats().get(zombie.characters.CharacterStat.FATIGUE)>.28f && ticks++<100000)wake.invoke(body);
                float after=body.getStats().get(zombie.characters.CharacterStat.FATIGUE);
                System.out.println("NATIVE_SLEEP before="+before+" after="+after+" ticks="+ticks);return f.push(after<before);
            }catch(Exception e){throw new IllegalStateException(e);}
        });
        env.rawset("__reconstructBed",(JavaFunction)(f,n)->{
            String mode=(String)f.get(0);var former=(IsoObject)env.rawget("__bed");var oldGrid=former.getSprite().getSpriteGrid();
            var grid=mode.equals("changed")?new IsoSpriteGrid(1,2):oldGrid;IsoObject head=null;
            for(int y=21;y<=23;y++) {var square=cell.getGridSquare(10,y,0);
                for(int j=square.getObjects().size()-1;j>=0;j--){var object=square.getObjects().get(j);if(object.getProperties().has(IsoFlagType.bed))square.getObjects().remove(object);}
                square.RecalcProperties();}
            if(!mode.equals("missing"))for(int i=0;i<2;i++) {
                var spr=oldGrid.getSprite(0,i);
                if(mode.equals("changed")) {spr=IsoSpriteManager.instance.AddSprite("fixtures_other_bed_01_"+i,5500+i);spr.name="fixtures_other_bed_01_"+i;
                    spr.getProperties().set(IsoFlagType.bed);spr.getProperties().set("Facing","S");spr.getProperties().set("BedType","goodBed");
                    spr.getProperties().set(IsoFlagType.solidtrans);grid.setSprite(0,i,spr);spr.setSpriteGrid(grid);}
                var square=cell.getGridSquare(10,mode.equals("footprint")&&i==1?23:21+i,0);
                var rebuilt=new IsoObject(cell,square,spr);square.getObjects().add(rebuilt);square.RecalcProperties();if(i==0)head=rebuilt;
            }
            if(mode.equals("changed"))grid.validate();
            if(head!=null)env.rawset("__reconstructedBed",head);
            return f.push(head==null||head!=former);
        });
        env.rawset("__recoveryScene",(JavaFunction)(f,n)->{
            try {
                var chair=(IsoObject)((KahluaTable)env.rawget("__objects")).rawget(1.0);
                chair.getSquare().getObjects().remove(chair);chair.setSquare(cell.getGridSquare(9,21,0));chair.getSquare().getObjects().add(chair);
                chair.getSquare().RecalcProperties();cell.getGridSquare(10,20,0).RecalcProperties();
                var building=new zombie.iso.areas.IsoBuilding(cell);building.def=new BuildingDef();building.def.id=42;
                var room=new zombie.iso.areas.IsoRoom();room.def=new RoomDef(1,"fixture");room.def.setBuilding(building.def);room.building=building;
                for(int x=7;x<=17;x++)for(int y=16;y<=25;y++){var s=cell.getGridSquare(x,y,0);s.setRoom(room);s.setRoomID(1);}
                var grid=new IsoSpriteGrid(1,2);IsoObject head=null;
                for(int i=0;i<2;i++) {
                    var spr=IsoSpriteManager.instance.AddSprite("fixtures_bed_01_"+i,5300+i);spr.name="fixtures_bed_01_"+i;
                    spr.getProperties().set(IsoFlagType.bed);spr.getProperties().set("Facing","S");spr.getProperties().set("BedType","goodBed");
                    spr.getProperties().set(IsoFlagType.solidtrans);
                    grid.setSprite(0,i,spr);spr.setSpriteGrid(grid);
                    var s=cell.getGridSquare(10,21+i,0);var o=new IsoObject(cell,s,spr);s.getObjects().add(o);s.RecalcProperties();if(i==0)head=o;
                }
                grid.validate();env.rawset("__bed",head);
                for(int[] xy:new int[][]{{11,21},{9,22},{11,22},{10,23}}) {
                    var s=cell.getGridSquare(xy[0],xy[1],0);var spr=IsoSpriteManager.instance.AddSprite("fixtures_block_01_0",5400);
                    spr.name="fixtures_block_01_0";
                    spr.getProperties().set(IsoFlagType.solidtrans);s.getObjects().add(new IsoObject(cell,s,spr));s.RecalcProperties();
                }
                body.getModData().rawset("SAOPersonId","furniture-person");body.setForwardDirection(0,1);body.setNpc(true);
                zombie.characters.IsoPlayer.players[0]=null;
                field(zombie.ai.StateMachine.class,"currentState").set(body.getStateMachine(),zombie.ai.states.IdleState.instance());
                body.getStats().set(zombie.characters.CharacterStat.FATIGUE,.65f);
                body.getStats().set(zombie.characters.CharacterStat.HUNGER,.1f);body.getStats().set(zombie.characters.CharacterStat.THIRST,.1f);
                return f.push(true);
            }catch(Exception e){throw new IllegalStateException(e);}
        });
        chunk(thread,env,root.resolve("tools/furniture_checks/native_prelude.lua"));
        for(String file:List.of("media/lua/shared/ISBaseObject.lua","media/lua/shared/TimedActions/ISBaseTimedAction.lua",
            "media/lua/shared/Moveables/ISMoveableDefinitions.lua","media/lua/shared/Moveables/ISMoveableSpriteProps.lua"))chunk(thread,env,game.resolve(file));
        chunk(thread,env,Path.of(args[2]));
        chunk(thread,env,root.resolve("mod/42.20/media/lua/shared/SAO_FurnitureRelocationAction.lua"));
        if(args.length>3 && (args[3].equals("private") || args[3].equals("admitted") || args[3].equals("lifecycle") || args[3].equals("human"))) {
            chunk(thread,env,root.resolve("tools/furniture_checks/private_prelude.lua"));
            chunk(thread,env,game.resolve("media/lua/client/TimedActions/ISTimedActionQueue.lua"));
            chunk(thread,env,game.resolve("media/lua/client/TimedActions/WalkToTimedAction.lua"));
            chunk(thread,env,game.resolve("media/lua/client/TimedActions/ISInventoryTransferAction.lua"));
            chunk(thread,env,game.resolve("media/lua/shared/TimedActions/ISGetOnBedAction.lua"));
            chunk(thread,env,game.resolve("media/lua/shared/defines.lua"));
            if(args[3].equals("human")) {
                chunk(thread,env,root.resolve("mod/42.20/media/lua/client/SAO_FurnitureMovement.lua"));
                chunk(thread,env,root.resolve("mod/42.20/media/lua/client/SAO_FurnitureMenu.lua"));
                chunk(thread,env,root.resolve("tools/furniture_checks/human_cases.lua"));
            }else {
            for(String file:List.of("shared/SAO_CognitiveModels.lua","shared/SAO_Cognition.lua","shared/SAO_Perception.lua",
                "shared/SAO_Standing.lua","shared/SAO_ProceduralPlanning.lua","client/SAO_Needs.lua","client/SAO_Locomotion.lua",
                "client/SAO_FurnitureWork.lua","client/SAO_FurnitureMenu.lua","client/SAO_RecoveryPose.lua","client/SAO_Controller.lua"))
                chunk(thread,env,root.resolve("mod/42.20/media/lua/"+file));
            if(args[3].equals("admitted"))env.rawset("__admissionResume",true);
            chunk(thread,env,root.resolve(args[3].equals("lifecycle")?"tools/furniture_checks/private_lifecycle_cases.lua":"tools/furniture_checks/private_cases.lua"));
            }
        }else chunk(thread,env,root.resolve("tools/furniture_checks/native_cases.lua"));
        System.exit(0);
    }
}
