import com.sao.engine.*;
import java.nio.file.Path;
import java.util.*;
import se.krka.kahlua.vm.KahluaTable;
import zombie.characters.IsoPlayer;
import zombie.iso.*;
import zombie.iso.areas.*;
import zombie.iso.objects.IsoDoor;
import zombie.iso.sprite.*;
import zombie.iso.SpriteDetails.IsoFlagType;
import zombie.core.skinnedmodel.advancedanimation.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import zombie.Lua.LuaManager;
import se.krka.kahlua.vm.*;

/** Installed geometry and animation records; controlled native scene, no rendered integration claim. */
public final class RecoveryPlaceProbe {
    static int checks;
    static void check(String name,boolean value){if(!value)throw new AssertionError("RECOVERY_PLACE:"+name);checks++;System.out.println("CHECK "+name);}
    static Object fixture(String name,Class<?>[] types,Object...args)throws Exception{
        var method=MovementCrossingProbe.class.getDeclaredMethod(name,types);method.setAccessible(true);return method.invoke(null,args);
    }
    static SAOIsoPlayerShell person(IsoCell cell,String id)throws Exception{
        var body=(SAOIsoPlayerShell)fixture("person",new Class<?>[]{IsoCell.class},cell);
        body.getModData().rawset("SAOPersonId",id);body.setSquare(body.getCurrentSquare());
        body.getCurrentSquare().getMovingObjects().add(body);cell.getObjectList().add(body);body.setForwardDirection(1,0);return body;
    }
    static KahluaTable bedRow(KahluaTable result){
        var rows=(KahluaTable)result.rawget("places");
        for(int i=1;i<=rows.len();i++){var row=(KahluaTable)rows.rawget((double)i);if("bed".equals(row.rawget("kind")))return row;}
        return null;
    }
    static Set<String> conceptSources(SAOIsoPlayerShell body) {
        var result=SAOConceptObservation.observe(body,8);var found=new HashSet<String>();
        var rows=(KahluaTable)result.rawget("observations");
        for(int i=1;i<=rows.len();i++) {
            var row=(KahluaTable)rows.rawget((double)i);
            if(row.rawget("recoverySourceId") instanceof String key)found.add(key);
        }
        return found;
    }
    static boolean visible(SAOIsoPlayerShell body,IsoGridSquare square)throws Exception {
        var reader=SAOPerceptionScanner.class.getDeclaredMethod("canSeeWorldSquareNow",
            zombie.characters.IsoGameCharacter.class,IsoGridSquare.class,float.class);
        reader.setAccessible(true);return (Boolean)reader.invoke(null,body,square,8f);
    }
    static IsoObject part(IsoCell cell,int x,int y,IsoSprite sprite){
        var object=new IsoObject(cell);object.setSquare(cell.getGridSquare(x,y,0));object.setSprite(sprite);
        object.getProperties().set(IsoFlagType.bed);object.getProperties().set("BedType","goodBed");
        object.getSquare().getObjects().add(object);return object;
    }
    static void position(SAOIsoPlayerShell body,float x,float y){
        body.getCurrentSquare().getMovingObjects().remove(body);body.setX(x);body.setY(y);
        body.setCurrent(body.getCell().getGridSquare((int)Math.floor(x),(int)Math.floor(y),0));
        body.setSquare(body.getCurrentSquare());body.getCurrentSquare().getMovingObjects().add(body);
    }
    static int integer(DataInputStream in)throws Exception{return Integer.reverseBytes(in.readInt());}
    static String line(DataInputStream in)throws Exception{
        var bytes=new ByteArrayOutputStream();int value;
        while((value=in.read())!='\n'){if(value<0)throw new EOFException();bytes.write(value);}
        return bytes.toString(StandardCharsets.UTF_8).trim();
    }
    static Map<String,Map<String,String>> installedTiles(Path game)throws Exception{
        var found=new HashMap<String,Map<String,String>>();
        try(var in=new DataInputStream(new BufferedInputStream(new FileInputStream(game.resolve("media/newtiledefinitions.tiles").toFile())))){
            if(!Arrays.equals(in.readNBytes(4),new byte[]{'t','d','e','f'})||integer(in)!=1)throw new IOException("TDEF version");
            int sets=integer(in);
            for(int s=0;s<sets;s++){
                String name=line(in);line(in);integer(in);integer(in);integer(in);int tiles=integer(in);
                for(int i=0;i<tiles;i++){
                    var props=new HashMap<String,String>();int count=integer(in);
                    for(int p=0;p<count;p++)props.put(line(in),line(in));
                    if(name.equals("furniture_bedding_01")&&i>=40&&i<=43||name.equals("furniture_storage_01")&&i==49)
                        found.put(name+"_"+i,props);
                }
            }
        }
        return found;
    }
    static KahluaTable lowerBed(SAOIsoPlayerShell body){
        var rows=(KahluaTable)SAORecoveryPlace.observe(body,8).rawget("places");
        for(int i=1;i<=rows.len();i++){var row=(KahluaTable)rows.rawget((double)i);
            if("bed".equals(row.rawget("kind"))&&Double.valueOf(21).equals(row.rawget("objectY")))return row;}
        return null;
    }
    static boolean footSide(KahluaTable row){return row!=null&&Boolean.TRUE.equals(row.rawget("available"))
        &&Double.valueOf(13.5).equals(row.rawget("x"))&&Double.valueOf(22.5).equals(row.rawget("y"));}
    static String describe(Object value){
        if(!(value instanceof KahluaTable table))return String.valueOf(value);
        var text=new StringBuilder("{");var iterator=table.iterator();
        while(iterator.advance())text.append(iterator.getKey()).append('=').append(describe(iterator.getValue())).append(',');
        return text.append('}').toString();
    }
    static void installedFootEntry(SAOIsoPlayerShell body,IsoObject bed,Path game,Path pose)throws Exception{
        var platform=new se.krka.kahlua.j2se.J2SEPlatform();var env=platform.newEnvironment();
        var thread=new KahluaThread(platform,env);thread.debugOwnerThread=Thread.currentThread();
        LuaManager.platform=platform;LuaManager.env=env;LuaManager.thread=thread;
        LuaManager.converterManager=new se.krka.kahlua.converter.KahluaConverterManager();
        zombie.Lua.KahluaNumberConverter.install(LuaManager.converterManager);
        LuaManager.caller=new se.krka.kahlua.integration.LuaCaller(LuaManager.converterManager);
        var exposer=new LuaManager.Exposer(LuaManager.converterManager,platform,env);
        for(Class<?> type:new Class<?>[]{SAOIsoPlayerShell.class,zombie.characters.IsoPlayer.class,
            zombie.characters.IsoGameCharacter.class,IsoObject.class,zombie.core.properties.PropertyContainer.class,zombie.seating.SeatingManager.class}){
            exposer.setExposed(type);exposer.exposeLikeJava(type,env);}
        var seating=platform.newTable();seating.rawset("getInstance",(JavaFunction)(frame,count)->{
            frame.push(zombie.seating.SeatingManager.getInstance());return 1;});env.rawset("SeatingManager",seating);
        env.rawset("__body",body);env.rawset("__bed",bed);
        RecoveryPoseProbe.lua(thread,env,"require=function()end; isClient=function()return false end; isServer=function()return false end","prelude");
        for(String relative:List.of("media/lua/shared/ISBaseObject.lua","media/lua/shared/TimedActions/ISBaseTimedAction.lua",
                "media/lua/shared/TimedActions/ISGetOnBedAction.lua"))
            RecoveryPoseProbe.lua(thread,env,java.nio.file.Files.readString(game.resolve(relative)),relative);
        RecoveryPoseProbe.lua(thread,env,java.nio.file.Files.readString(pose),"production-recovery-pose");
        RecoveryPoseProbe.lua(thread,env,"__entry=SAO.RecoveryPose.newBedEntry(__body,__bed); __entry:waitToStart()","native-foot-entry");
        check("installed_action_selects_foot_right","FootRight".equals(body.getVariableString("OnBedDirection"))
            &&body.getSitOnFurnitureObject()==bed);
        // Use the installed FootRight node and clip to deliver its actual completion event.
        // Controlled turning has reached the action's before-entry direction; the engine owns the root snap.
        body.getAnimationPlayer().setTargetAndCurrentDirection(0,-1);
        RecoveryPoseProbe.lua(thread,env,"__entry:start()","native-foot-start");
        OrientationProbe.field(zombie.ai.StateMachine.class,"currentState")
            .set(body.getStateMachine(),zombie.ai.states.PlayerOnBedState.instance());
        zombie.ai.states.PlayerOnBedState.instance().enter(body);
        var node=AnimNode.Parse(game.resolve("media/AnimSets/player/onbed/GetOnBed_FootRight.xml").toString());
        if(Boolean.getBoolean("sao.test.omitBedEntryEvent"))node.events.clear();
        var state=body.getAdvancedAnimator().animSet.states.get("onbed");node.parentState=state;state.addNode(node);
        body.getAdvancedAnimator().setState("onbed",List.of());OrientationProbe.animate(body,10);
        var track=RecoveryPoseProbe.track(body,"Bob_GetInBed_Right");
        check("actual_foot_entry_clip",track.getBlendWeight()>0&&RecoveryPoseProbe.node(track).isActive());
        for(int i=0;i<600&&!body.getVariableBoolean("OnBedStarted");i++)OrientationProbe.animate(body,1);
        check("native_foot_entry_event",body.getVariableBoolean("OnBedStarted")&&"Awake".equals(body.getVariableString("OnBedAnim")));
        OrientationProbe.animate(body,60);
        check("entry_event_reaches_actual_awake_pose",SAORecoveryPose.isRecoveryPose(body,"rest"));
        zombie.ai.states.PlayerOnBedState.instance().exit(body);zombie.ai.states.PlayerGetUpState.instance().exit(body);
        check("entry_lifecycle_releases_exact_bed",!body.isOnBed()&&body.getSitOnFurnitureObject()==null);
    }
    public static void main(String[] args)throws Exception{
        var cell=(IsoCell)fixture("boot",new Class<?>[0]);
        var regions=zombie.iso.areas.isoregion.IsoRegions.class.getDeclaredField("dataRoot");regions.setAccessible(true);
        regions.set(null,new zombie.iso.areas.isoregion.data.DataRoot());
        var properties=new HashMap<String,ArrayList<String>>();properties.put("BedType",new ArrayList<>(List.of("goodBed")));
        properties.put("Facing",new ArrayList<>(List.of("N","S","W","E")));
        zombie.core.TilePropertyAliasMap.instance.Generate(properties);
        var building=new IsoBuilding(cell);building.def=new BuildingDef();building.def.id=42;
        var room=new IsoRoom();room.def=new RoomDef(1,"private-authored-label");room.def.setBuilding(building.def);room.building=building;
        for(int x=5;x<=18;x++)for(int y=15;y<=26;y++){var square=cell.getGridSquare(x,y,0);if(square==null)continue;
            square.setRoomID(1);square.setRoom(room);square.setSolidFloor(true);}
        var body=person(cell,"ordinary");
        check("ordinary_tokenless_places",SAORecoveryPlace.observe(body,8)!=null);
        var ordinaryReport=(KahluaTable)SAORecoveryPlace.observe(body,8).rawget("diagnostics");
        check("query_admission_diagnostic",ordinaryReport!=null&&"accepted".equals(ordinaryReport.rawget("bodyAdmission"))
            &&((Double)ordinaryReport.rawget("visibleSquares"))>0);
        var unavailable=com.sao.bridge.SAOBridge.INSTANCE.recoveryPlaces(null,8);
        check("bridge_unavailable_distinct_from_empty","unavailable".equals(unavailable.rawget("status"))
            &&unavailable.rawget("actorId")==null&&unavailable.rawget("places")==null);
        body.setAsleep(true);body.setOnBed(true);
        var asleepReport=(KahluaTable)com.sao.bridge.SAOBridge.INSTANCE.recoveryPlaces(body,8).rawget("diagnostics");
        check("unavailable_body_retains_native_sleep_flags",Boolean.TRUE.equals(asleepReport.rawget("nativeAsleep"))
            &&Boolean.TRUE.equals(asleepReport.rawget("nativeOnBed")));
        body.setAsleep(false);body.setOnBed(false);
        body.getCurrentSquare().setRoom(null);
        var empty=SAORecoveryPlace.observe(body,8);
        check("accepted_empty_query_is_available","available".equals(empty.rawget("status"))
            &&((KahluaTable)empty.rawget("places")).len()==0
            &&((Double)((KahluaTable)empty.rawget("diagnostics")).rawget("groundRejectedClearance"))>0);
        body.getCurrentSquare().setRoom(room);
        check("clear_ground_admitted",SAORecoveryPlace.groundClear(body,10.5,20.5,0));
        var boundary=cell.getGridSquare(11,20,0);var door=new IsoDoor(cell);door.setSquare(boundary);door.north=false;door.setSprite(new IsoSprite());
        boundary.getObjects().add(door);boundary.getSpecialObjects().add(door);
        door.setOpen(true);
        check("doorway_ground_refused",!SAORecoveryPlace.groundClear(body,10.5,20.5,0));
        boundary.getObjects().remove(door);boundary.getSpecialObjects().remove(door);
        boundary.getProperties().set(IsoFlagType.collideW);
        check("wall_envelope_refused",!SAORecoveryPlace.groundClear(body,10.5,20.5,0));boundary.getProperties().unset(IsoFlagType.collideW);
        var other=person(cell,"other");other.setCollidable(false);
        check("other_body_even_noncollidable_refused",!SAORecoveryPlace.groundClear(body,10.5,20.5,0));
        other.getCurrentSquare().getMovingObjects().remove(other);cell.getObjectList().remove(other);
        body.setForwardDirection(-1,0);
        check("unseen_place_refused",!SAORecoveryPlace.groundClear(body,15.5,20.5,0));body.setForwardDirection(1,0);
        var grid=new IsoSpriteGrid(1,2);var headSprite=new IsoSprite();var footSprite=new IsoSprite();
        grid.setSprite(0,0,headSprite);grid.setSprite(0,1,footSprite);headSprite.setSpriteGrid(grid);footSprite.setSpriteGrid(grid);
        headSprite.getProperties().set("Facing","S");footSprite.getProperties().set("Facing","S");
        var head=part(cell,12,20,headSprite);var foot=part(cell,12,21,footSprite);
        headSprite.setSpriteGrid(null);footSprite.setSpriteGrid(null);
        var unsupported=bedRow(SAORecoveryPlace.observe(body,8));
        check("unsupported_visible_bed_retained",unsupported!=null&&Boolean.FALSE.equals(unsupported.rawget("available")));
        check("unknown_grid_does_not_invent_shared_identity",conceptSources(body).size()==2);
        var unsupportedReport=(KahluaTable)SAORecoveryPlace.observe(body,8).rawget("diagnostics");
        var rejections=(KahluaTable)unsupportedReport.rawget("bedRejections");
        check("visible_bed_rejection_diagnostic",((Double)unsupportedReport.rawget("visibleBedParts"))==2
            &&rejections.len()>0&&"visible-bed-grid-or-head-unavailable".equals(((KahluaTable)rejections.rawget(1.0)).rawget("reason")));
        position(body,7.5f,20.5f);body.setForwardDirection(-1,0);
        var unseenReport=(KahluaTable)SAORecoveryPlace.observe(body,8).rawget("diagnostics");
        check("diagnostics_do_not_enumerate_unseen_beds",((Double)unseenReport.rawget("visibleBedParts"))==0
            &&((KahluaTable)unseenReport.rawget("bedRejections")).len()==0);
        check("unseen_sources_are_not_joined",conceptSources(body).isEmpty());
        position(body,10.5f,20.5f);body.setForwardDirection(1,0);
        headSprite.setSpriteGrid(grid);footSprite.setSpriteGrid(grid);
        var place=bedRow(SAORecoveryPlace.observe(body,8));
        check("visible_bed_has_native_approach",place!=null&&Boolean.TRUE.equals(place.rawget("available")));
        check("visible_parts_share_exact_recovery_source",conceptSources(body).equals(Set.of((String)place.rawget("key"))));
        // A wall hides the head while the foot remains personally visible.
        // The foot may identify only itself, even when its sprite grid has a head.
        position(body,11.5f,21.5f);body.setForwardDirection(1,0);
        var footSquare=foot.getSquare();footSquare.getProperties().set(IsoFlagType.collideN);footSquare.getProperties().set(IsoFlagType.cutN);
        footSquare.ReCalculateVisionBlocked(head.getSquare());head.getSquare().ReCalculateVisionBlocked(footSquare);
        check("head_obscured_while_foot_visible",!visible(body,head.getSquare())&&visible(body,footSquare));
        check("obscured_head_identity_not_inferred",!conceptSources(body).contains(place.rawget("key")));
        footSquare.getProperties().unset(IsoFlagType.collideN);footSquare.getProperties().unset(IsoFlagType.cutN);
        footSquare.ReCalculateVisionBlocked(head.getSquare());head.getSquare().ReCalculateVisionBlocked(footSquare);
        position(body,10.5f,20.5f);body.setForwardDirection(1,0);
        check("new_visibility_rejoins_exact_head",conceptSources(body).equals(Set.of((String)place.rawget("key"))));
        if(Boolean.getBoolean("sao.test.meansIdentityOnly")) {
            System.out.println("PASS recovery means identity "+checks);System.exit(0);
        }
        var doubleGrid=new IsoSpriteGrid(2,2);doubleGrid.setSprite(0,0,headSprite);doubleGrid.setSprite(0,1,footSprite);
        headSprite.setSpriteGrid(doubleGrid);footSprite.setSpriteGrid(doubleGrid);
        check("double_bed_column_supported",Boolean.TRUE.equals(bedRow(SAORecoveryPlace.observe(body,8)).rawget("available")));
        headSprite.setSpriteGrid(grid);footSprite.setSpriteGrid(grid);
        var adjacentRoom=new IsoRoom();adjacentRoom.def=new RoomDef(2,"unread-role");adjacentRoom.def.setBuilding(building.def);adjacentRoom.building=building;
        for(int x=11;x<=13;x++)for(int y=20;y<=21;y++)cell.getGridSquare(x,y,0).setRoom(adjacentRoom);
        check("visible_bed_across_room_boundary_supported",Boolean.TRUE.equals(bedRow(SAORecoveryPlace.observe(body,8)).rawget("available")));
        for(int x=11;x<=13;x++)for(int y=20;y<=21;y++)cell.getGridSquare(x,y,0).setRoom(room);
        var key=(String)place.rawget("key");
        check("bed_far_approach_refused",SAORecoveryPlace.resolveBed(body,key)==null);
        position(body,((Double)place.rawget("x")).floatValue(),((Double)place.rawget("y")).floatValue());
        check("exact_bed_resolved",SAORecoveryPlace.resolveBed(body,key)==head);
        position(body,body.getX(),body.getY()+.36f);
        check("bed_false_arrival_refused",SAORecoveryPlace.resolveBed(body,key)==null);
        position(body,((Double)place.rawget("x")).floatValue(),((Double)place.rawget("y")).floatValue());
        other.setOnBed(true);other.setSitOnFurnitureObject(head);other.setVariable("OnBedAnim","Asleep");cell.getObjectList().add(other);
        check("sleeping_bed_occupant_refused",SAORecoveryPlace.resolveBed(body,key)==null);cell.getObjectList().remove(other);
        head.getSquare().getObjects().remove(head);
        check("removed_bed_refused",SAORecoveryPlace.resolveBed(body,key)==null);head.getSquare().getObjects().add(head);
        body.getModData().rawset("SAOExternalOwner","other");
        check("foreign_body_refused",SAORecoveryPlace.observe(body,8)==null);body.getModData().rawset("SAOExternalOwner",null);
        IsoPlayer.players[0]=body;check("player_slot_refused",SAORecoveryPlace.observe(body,8)==null);IsoPlayer.players[0]=null;
        check("invalid_radius_refused",SAORecoveryPlace.observe(body,0)==null&&SAORecoveryPlace.observe(body,9)==null);
        for(float offset:new float[]{-.3f,0,.3f}) {
            position(body,11.5f,20.5f+offset);body.setDir(IsoDirections.E);body.setSitOnFurnitureObject(head);
            zombie.ai.states.PlayerOnBedState.instance().enter(body);
            check("native_bed_entry_alignment_"+offset,body.isOnBed()&&!body.isCollidable()
                &&Math.abs(body.getX()-11.7f)<.001 &&Math.abs(body.getY()-(20.5f+offset))<.001);
            zombie.ai.states.PlayerOnBedState.instance().exit(body);
            zombie.ai.states.PlayerGetUpState.instance().exit(body);
            check("native_getup_releases_bed_binding_"+offset,!body.isOnBed()&&body.getSitOnFurnitureObject()==null);
        }
        var game=Path.of(args[0]);var skin=RecoveryPoseProbe.skin(game);
        var parameters=zombie.core.skinnedmodel.model.jassimp.ProcessedAiSceneParams.create();
        parameters.scene=jassimp.Jassimp.importFile(game.resolve("media/anims_X/Bob/Bob_GetInBed_Right.x").toString());
        parameters.mode=zombie.core.skinnedmodel.model.jassimp.JAssImpImporter.LoadMode.Normal;
        parameters.animBonesScaleModifier=1;parameters.skinnedTo=skin;
        var imported=zombie.core.skinnedmodel.model.jassimp.ImportedSkeleton.process(
            zombie.core.skinnedmodel.model.jassimp.ImportedSkeletonParams.create(parameters,parameters.scene.getMeshes().get(0)));
        skin.animationClips.putAll((HashMap<String,zombie.core.skinnedmodel.animation.AnimationClip>)
            OrientationProbe.field(zombie.core.skinnedmodel.model.jassimp.ImportedSkeleton.class,"clips").get(imported));
        var posed=OrientationProbe.body(cell,skin);var state=new AnimState();state.name="onbed";state.set=posed.getAdvancedAnimator().animSet;
        for(String name:List.of("OnBedAwake","OnBedAsleep")){
            var node=AnimNode.Parse(game.resolve("media/AnimSets/player/onbed/"+name+".xml").toString());node.parentState=state;state.addNode(node);}
        posed.getAdvancedAnimator().animSet.states.put(state.name,state);posed.setOnBed(true);posed.setSitOnFurnitureObject(head);
        posed.setVariable("OnBedAnim","Asleep");posed.getAdvancedAnimator().setState("onbed",List.of());OrientationProbe.animate(posed,60);
        check("actual_native_bed_sleep_track",SAORecoveryPose.isRecoveryPose(posed,"sleep"));
        check("native_bed_sleep_distinct_from_rest",!SAORecoveryPose.isRecoveryPose(posed,"rest"));
        posed.setSitOnFurnitureObject(null);check("bed_pose_without_exact_furniture_refused",!SAORecoveryPose.isRecoveryPose(posed,"sleep"));
        // Actual failing authored layout translated to this isolated native scene.
        head.getSquare().getObjects().remove(head);foot.getSquare().getObjects().remove(foot);
        zombie.seating.SeatingManager.getInstance().init();
        var nativeTiles=installedTiles(game);var actualGrid=new IsoSpriteGrid(2,2);IsoObject lowerHead=null;
        for(int index=40;index<=43;index++){
            String name="furniture_bedding_01_"+index;var values=nativeTiles.get(name);
            check("actual_bed_properties_"+index,"E".equals(values.get("Facing"))&&"goodBed".equals(values.get("BedType"))
                &&values.containsKey("bed")&&values.containsKey("solidtrans"));
            String[] pos=values.get("SpriteGridPos").split(",");int gx=Integer.parseInt(pos[0]),gy=Integer.parseInt(pos[1]);
            var sprite=new IsoSprite();sprite.setName(name);sprite.setSpriteGrid(actualGrid);actualGrid.setSprite(gx,gy,sprite);
            sprite.tilesetName="furniture_bedding_01";sprite.tileSheetIndex=index;
            sprite.getProperties().set("Facing",values.get("Facing"));
            var object=part(cell,12+gx,20+gy,sprite);object.getProperties().set(IsoFlagType.solidtrans);
            object.getSquare().getProperties().set(IsoFlagType.solidtrans);
            if(gx==0&&gy==1)lowerHead=object;
            check("installed_seating_facing_"+index,new String[]{"S","E","N","N"}[index-40].equals(zombie.seating.SeatingManager.getInstance().getFacingDirection(object)));
        }
        check("actual_dresser_is_solidtrans",nativeTiles.get("furniture_storage_01_49").containsKey("solidtrans"));
        var dresser=new IsoObject(cell);dresser.setSquare(cell.getGridSquare(12,22,0));dresser.setSprite(new IsoSprite());
        dresser.getSprite().setName("furniture_storage_01_49");dresser.getProperties().set(IsoFlagType.solidtrans);
        dresser.getSquare().getObjects().add(dresser);dresser.getSquare().getProperties().set(IsoFlagType.solidtrans);
        for(int x=12;x<=13;x++){
            cell.getGridSquare(x,19,0).setRoom(null);cell.getGridSquare(x,20,0).getProperties().set(IsoFlagType.collideN);}
        position(body,14.5f,22.5f);body.setForwardDirection(-1,-1);
        var footPlace=lowerBed(body);
        System.out.println("AUTHORED_BED_RESULT "+describe(SAORecoveryPlace.observe(body,8)));
        check("actual_bed_dresser_head_blocked_foot_side_offered",footSide(footPlace));
        var entrySquare=cell.getGridSquare(13,22,0);entrySquare.getProperties().set(IsoFlagType.solidtrans);
        check("obstructed_foot_side_not_offered",!footSide(lowerBed(body)));entrySquare.getProperties().unset(IsoFlagType.solidtrans);
        entrySquare.getProperties().set(IsoFlagType.collideN);
        check("blocked_foot_side_edge_not_offered",!footSide(lowerBed(body)));entrySquare.getProperties().unset(IsoFlagType.collideN);
        position(body,13.5f,22.5f);
        check("actual_foot_side_resolves_exact_bed",SAORecoveryPlace.resolveBed(body,(String)footPlace.rawget("key"))==lowerHead);
        position(posed,13.5f,22.5f);posed.setOnBed(false);posed.clearVariable("OnBedAnim");posed.clearVariable("OnBedStarted");
        installedFootEntry(posed,lowerHead,game,Path.of(args[1]));
        for(float offset:new float[]{-.3f,0,.3f}){
            position(posed,13.5f+offset,22.5f);posed.setDir(IsoDirections.N);
            posed.getAnimationPlayer().setTargetAndCurrentDirection(0,-1);posed.setSitOnFurnitureObject(lowerHead);
            zombie.ai.states.PlayerOnBedState.instance().enter(posed);
            check("native_foot_side_entry_alignment_"+offset,posed.isOnBed()&&Math.abs(posed.getY()-22.3f)<.001
                &&Math.abs(posed.getX()-(13.5f+offset))<.001);
            zombie.ai.states.PlayerOnBedState.instance().exit(posed);zombie.ai.states.PlayerGetUpState.instance().exit(posed);
        }
        System.out.println("PASS recovery place "+checks);System.exit(0);
    }
}
