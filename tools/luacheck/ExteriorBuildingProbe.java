import com.sao.engine.*;
import java.util.*;
import zombie.iso.*;
import zombie.iso.areas.*;
import zombie.iso.objects.IsoDoor;
import zombie.iso.objects.IsoWindow;
import zombie.iso.objects.IsoBarricade;
import zombie.iso.SpriteDetails.IsoFlagType;
import zombie.iso.sprite.IsoSprite;

/** Installed engine squares, vision, doors, movement and exact holder authority. */
public final class ExteriorBuildingProbe {
    static int checks;
    static void check(String name, boolean result) {
        System.out.println("CHECK " + name + "=" + result);
        if (!result) throw new AssertionError(name);
        checks++;
    }
    static String scan(SAOIsoPlayerShell body) { return SAOPerceptionScanner.scan(body); }
    static void position(SAOIsoPlayerShell body, IsoCell cell, float x, float y) {
        body.setX(x); body.setY(y); body.setZ(0); body.setCurrent(cell.getGridSquare((int)x,(int)y,0));
    }
    static SAORouteState route(float x, float y) {
        var route = new SAORouteState(); route.setRoute(List.of(new float[]{x,y,0})); route.requested=true;
        return route;
    }
    public static void main(String[] args) throws Exception {
        var boot=MovementCrossingProbe.class.getDeclaredMethod("boot"); boot.setAccessible(true);
        IsoCell cell=(IsoCell)boot.invoke(null);
        // Native door opening invalidates the real per-player weather masks.
        // Initialize those engine objects without starting a renderer.
        var masksField=zombie.iso.weather.fx.WeatherFxMask.class.getDeclaredField("playerMasks");masksField.setAccessible(true);
        Object[] masks=(Object[])masksField.get(null);
        var maskType=Class.forName("zombie.iso.weather.fx.WeatherFxMask$PlayerFxMask");
        for(int index=0;index<masks.length;index++) masks[index]=maskType.getConstructor().newInstance();
        var person=MovementCrossingProbe.class.getDeclaredMethod("person",IsoCell.class); person.setAccessible(true);
        var body=(SAOIsoPlayerShell)person.invoke(null,cell);
        body.setForwardDirection(0,1);
        for(int x=0;x<32;x++) for(int y=8;y<32;y++) {
            var square=cell.getGridSquare(x,y,0); if(square!=null) {square.getProperties().set(IsoFlagType.exterior);square.setSolidFloor(true);}
        }
        var def=new BuildingDef(); def.id=42; def.x=10;def.y=26;def.x2=30;def.y2=30;
        var building=new IsoBuilding(cell);building.def=def;
        var room=new IsoRoom();room.building=building;room.def=new RoomDef();room.def.building=def;
        var inside=cell.getGridSquare(10,26,0);
        var holderSquare=cell.getGridSquare(10,27,0);
        inside.setRoomID(1);holderSquare.setRoomID(1);inside.setRoom(room);holderSquare.setRoom(room);
        inside.getProperties().unset(IsoFlagType.exterior);holderSquare.getProperties().unset(IsoFlagType.exterior);
        var door=new IsoDoor(cell);door.setSquare(inside);door.setSprite(new IsoSprite());door.north=true;
        door.setOpenSprite(new IsoSprite());
        var closed=IsoDoor.class.getDeclaredField("closedSprite");closed.setAccessible(true);closed.set(door,door.getSprite());
        door.setKeyId(1729);door.setLockedByKey(true);
        inside.getObjects().add(door);inside.getSpecialObjects().add(door);
        var outside=cell.getGridSquare(10,25,0);
        System.out.println("BOUNDARY door="+outside.getDoorTo(inside)+" def="+(inside.getBuildingDef()==def)+" free="+outside.isFree(false)+" floor="+outside.isSolidFloor());
        check("loaded_native_exterior_boundary",outside.getDoorTo(inside)==door&&inside.getBuildingDef()==def&&outside.isFree(false));
        String sight=scan(body);System.out.println("BUILDING_SCAN "+sight);
        check("visible_unentered_building_lead",sight.contains("B:42:10.5:26.0:0:10.5:25.5:door"));
        check("exterior_row_has_no_center_layout_or_stock",Arrays.stream(sight.split("\\|")).filter(s->s.startsWith("B:")).allMatch(s->s.split(":").length==9)
            && !sight.contains("20.0") && !sight.contains("food") && !sight.contains("room"));
        check("closed_door_does_not_reveal_lock",sight.contains("B:42:10.5:26.0:0:10.5:25.5:door:closed") && !sight.contains("locked"));
        var secondInside=cell.getGridSquare(12,26,0);
        secondInside.setRoomID(1);secondInside.setRoom(room);
        secondInside.getProperties().unset(IsoFlagType.exterior);
        var secondDoor=new IsoDoor(cell);secondDoor.setSquare(secondInside);secondDoor.north=true;
        secondDoor.setSprite(new IsoSprite());secondDoor.setOpenSprite(new IsoSprite());
        closed.set(secondDoor,secondDoor.getSprite());
        secondInside.getObjects().add(secondDoor);secondInside.getSpecialObjects().add(secondDoor);
        String twoEntrances=scan(body);
        check("distinct_visible_doors_same_building_offered",twoEntrances.contains("B:42:10.5:26.0:0:10.5:25.5:door")
            && twoEntrances.contains("B:42:12.5:26.0:0:12.5:25.5:door"));
        secondInside.getObjects().remove(secondDoor);secondInside.getSpecialObjects().remove(secondDoor);
        var window=new IsoWindow(cell);window.setSquare(secondInside);window.setSprite(new IsoSprite());
        var north=IsoWindow.class.getDeclaredField("north");north.setAccessible(true);north.setBoolean(window,true);
        var open=IsoWindow.class.getDeclaredField("open");open.setAccessible(true);
        secondInside.getObjects().add(window);secondInside.getSpecialObjects().add(window);
        check("actual_native_window_boundary",cell.getGridSquare(12,25,0).getWindowTo(secondInside)==window);
        window.setIsLocked(true);
        check("visible_closed_window_no_hidden_lock",scan(body).contains("B:42:12.5:26.0:0:12.5:25.5:window:closed") && !scan(body).contains("locked"));
        open.setBoolean(window,true);
        check("visible_open_window_state",scan(body).contains("B:42:12.5:26.0:0:12.5:25.5:window:open"));
        body.setForwardDirection(0,-1);
        check("unseen_window_not_acquired",!scan(body).contains(":window:"));body.setForwardDirection(0,1);
        open.setBoolean(window,false);window.setSmashed(true);
        check("visible_smashed_window_state",scan(body).contains("B:42:12.5:26.0:0:12.5:25.5:window:smashed"));
        window.setGlassRemoved(true);
        check("visible_cleared_window_state",scan(body).contains("B:42:12.5:26.0:0:12.5:25.5:window:clear"));
        var windowOutside=cell.getGridSquare(12,25,0);
        // Plank mutation recalculates square properties. Give the controlled map
        // actual floor objects so it does not erase its synthetic floor flag.
        var windowFloors=new java.util.ArrayList<zombie.iso.IsoObject>();
        for (var floorSquare : new zombie.iso.IsoGridSquare[]{windowOutside,secondInside}) {
            var floorSprite=new IsoSprite();floorSprite.getProperties().set(IsoFlagType.solidfloor);
            var floorObject=new zombie.iso.IsoObject(cell);floorObject.setSquare(floorSquare);floorObject.setSprite(floorSprite);
            floorSquare.getObjects().add(floorObject);windowFloors.add(floorObject);
        }
        var barricade=new IsoBarricade(windowOutside,IsoDirections.S);barricade.addPlank(null);
        windowOutside.getObjects().add(barricade);windowOutside.getSpecialObjects().add(barricade);
        check("visible_window_barricade_state",window.getBarricadeForCharacter(body)==barricade
            && windowOutside.isFree(false) && scan(body).contains("B:42:12.5:26.0:0:12.5:25.5:window:barricaded"));
        var apertureState=SAOPerceptionScanner.class.getDeclaredMethod("exteriorApertureState",zombie.characters.IsoGameCharacter.class,zombie.iso.IsoObject.class,IsoWindow.class);
        apertureState.setAccessible(true);
        check("native_visible_barricade_classification",apertureState.invoke(null,body,null,window).equals("barricaded"));
        windowOutside.getObjects().remove(barricade);windowOutside.getSpecialObjects().remove(barricade);
        windowOutside.setCachedIsFree(false);
        var hiddenBarricade=new IsoBarricade(secondInside,IsoDirections.N);hiddenBarricade.addPlank(null);
        secondInside.getObjects().add(hiddenBarricade);secondInside.getSpecialObjects().add(hiddenBarricade);
        check("opposite_window_barricade_not_exposed",scan(body).contains("B:42:12.5:26.0:0:12.5:25.5:window:clear"));
        secondInside.getObjects().remove(hiddenBarricade);secondInside.getSpecialObjects().remove(hiddenBarricade);
        position(body,cell,12.5f,25.5f);
        // The controlled window has no artwork for its destroyed sprite; native
        // smashed-window mutation cleared it. Supply that fixture sprite here.
        window.setSprite(new IsoSprite());
        secondInside.getProperties().set(IsoFlagType.makeWindowInvincible);
        window.getSprite().getProperties().set(IsoFlagType.makeWindowInvincible);
        check("native_window_clear_but_crossing_blocked",window.isGlassRemoved() && !window.canClimbThrough(body));
        var blockedWindowRoute=route(12.5f,26.5f);blockedWindowRoute.targetX=29.5f;blockedWindowRoute.targetY=29.5f;
        check("blocked_window_uses_actual_failure",SAOMovement.tick(body,blockedWindowRoute).equals("FailedObstacle:FAILED_BLOCKED_WINDOW"));
        check("blocked_window_retains_authenticated_before_state",("MOVE_BARRIER@12@25@12@26@0@window@clear@FAILED_BLOCKED_WINDOW").equals(blockedWindowRoute.barrierResult));
        var handle=SAOMovement.class.getDeclaredMethod("handleRouteTransition",SAOIsoPlayerShell.class,SAORouteState.class,float[].class);
        handle.setAccessible(true);
        var barrierReceipt=SAOMovement.class.getDeclaredMethod("barrierResult",SAOIsoPlayerShell.class,SAORouteState.class,IsoGridSquare.class,float[].class,String.class);
        barrierReceipt.setAccessible(true);
        var boundAttempt=route(12.5f,26.5f);float[] windowNode={12.5f,26.5f,0};
        handle.invoke(null,body,boundAttempt,windowNode);
        check("blocked_window_wrong_edge_refuses",barrierReceipt.invoke(null,body,boundAttempt,windowOutside,new float[]{13.5f,25.5f,0},"FAILED_BLOCKED_WINDOW")==null);
        boundAttempt.routeGeneration++;
        check("blocked_window_wrong_route_state_refuses",barrierReceipt.invoke(null,body,boundAttempt,windowOutside,windowNode,"FAILED_BLOCKED_WINDOW")==null);
        secondInside.getProperties().unset(IsoFlagType.makeWindowInvincible);
        window.getSprite().getProperties().unset(IsoFlagType.makeWindowInvincible);
        var windowRoute=route(12.5f,26.5f);
        String windowEntry=SAOMovement.tick(body,windowRoute);
        check("observed_clear_window_uses_native_crossing",windowEntry.equals("Transition:STARTED_WINDOW_CLIMB") && body.getActionContext().hasEventOccurred("EventClimbWindow"));
        check("window_request_does_not_prove_crossing",windowRoute.consumeCrossing().equals("MOVE_CROSSING_UNAVAILABLE"));
        var stateMethod=MovementCrossingProbe.class.getDeclaredMethod("state",SAOIsoPlayerShell.class,zombie.ai.State.class);
        stateMethod.setAccessible(true);
        stateMethod.invoke(null,body,zombie.ai.states.ClimbThroughWindowState.instance());
        SAOMovement.tick(body,windowRoute);
        position(body,cell,12.5f,26.5f);
        SAOMovement.tick(body,windowRoute);
        check("window_position_during_climb_does_not_complete",windowRoute.consumeCrossing().equals("MOVE_CROSSING_UNAVAILABLE"));
        stateMethod.invoke(null,body,(Object)null);
        body.getActionContext().clearActionContextEvents();
        SAOMovement.tick(body,windowRoute);
        check("actual_window_crossing_keeps_before_state",windowRoute.consumeCrossing().equals("MOVE_CROSSING@0@1@12@25@12@26@0@window@clear"));
        check("crossing_receipt_consumed_once",windowRoute.consumeCrossing().equals("MOVE_CROSSING_UNAVAILABLE"));
        body.getActionContext().clearActionContextEvents();
        position(body,cell,10.5f,20.5f);
        secondInside.getObjects().remove(window);secondInside.getSpecialObjects().remove(window);
        // Retire the window-specific geometry before the existing holder fixture.
        for (var floorObject : windowFloors) floorObject.getSquare().getObjects().remove(floorObject);
        secondInside.setRoom(null);secondInside.setRoomID(-1);
        secondInside.getProperties().set(IsoFlagType.exterior);
        outside.chunk.setSquare(outside.getX()%8,outside.getY()%8,0,null);
        check("unloaded_exterior_not_acquired",!scan(body).contains("B:42:"));
        outside.chunk.setSquare(outside.getX()%8,outside.getY()%8,0,outside);
        body.setForwardDirection(0,-1);check("behind_body_not_acquired",!scan(body).contains("B:42:"));body.setForwardDirection(0,1);
        position(body,cell,10.5f,9.5f);check("outside_range_not_acquired",!scan(body).contains("B:42:"));position(body,cell,10.5f,20.5f);
        var upper=new IsoGridSquare(cell,null,10,20,1);upper.chunk=body.getCurrentSquare().chunk;
        upper.chunk.setSquare(10%8,20%8,1,upper);body.setZ(1);body.setCurrent(upper);
        check("different_floor_not_acquired",!scan(body).contains("B:42:"));position(body,cell,10.5f,20.5f);
        var wall=cell.getGridSquare(10,24,0);var before=cell.getGridSquare(10,23,0);
        wall.getProperties().set(IsoFlagType.WallN);wall.getProperties().set(IsoFlagType.collideN);
        wall.ReCalculateVisionBlocked(before);before.ReCalculateVisionBlocked(wall);
        check("native_intervening_wall_hides_lead",!scan(body).contains("B:42:"));
        wall.getProperties().unset(IsoFlagType.WallN);wall.getProperties().unset(IsoFlagType.collideN);
        wall.ReCalculateVisionBlocked(before);before.ReCalculateVisionBlocked(wall);
        outside.getProperties().set(IsoFlagType.solid);outside.setCachedIsFree(false);outside.setCacheIsFree(false);
        check("blocked_exterior_approach_not_offered",!scan(body).contains("B:42:"));
        outside.getProperties().unset(IsoFlagType.solid);outside.setCachedIsFree(false);outside.setCacheIsFree(false);
        body.getModData().rawset("SAO_ObserverAnchor",true);check("god_camera_does_not_acquire_leads",!scan(body).contains("B:42:"));
        body.getModData().rawset("SAO_ObserverAnchor",null);
        var holder=new IsoObject(cell);holder.setSquare(holderSquare);holderSquare.getObjects().add(holder);
        var container=new zombie.inventory.ItemContainer("counter",holderSquare,holder);holder.setContainer(container);container.setExplored(true);
        check("closed_door_does_not_offer_hidden_holder",!SAOWorldSources.inspectionCandidates(body,12).contains("C|id="));
        position(body,cell,10.5f,25.5f);
        check("actual_exterior_approach_arrives",SAOMovement.tick(body,route(10.5f,25.5f)).equals("Succeeded"));
        var lockedRoute=route(10.5f,26.5f);lockedRoute.targetX=29.5f;lockedRoute.targetY=29.5f;
        check("physical_locked_entry_refuses",SAOMovement.tick(body,lockedRoute).equals("FailedObstacle:FAILED_LOCKED_DOOR"));
        check("native_failed_edge_is_not_final_target","MOVE_BARRIER@10@25@10@26@0@door@closed@FAILED_LOCKED_DOOR".equals(lockedRoute.barrierResult));
        lockedRoute.clearRoute();check("retired_route_drops_barrier_receipt",lockedRoute.barrierResult==null);
        door.setLockedByKey(false);
        var openedRoute=route(10.5f,26.5f);
        String entry=SAOMovement.tick(body,openedRoute);System.out.println("NATIVE_DOOR_ENTRY "+entry);
        check("observed_closed_door_opened_by_native_movement",door.IsOpen() && entry.contains("OPENING_DOOR"));
        check("opening_door_does_not_prove_crossing",openedRoute.consumeCrossing().equals("MOVE_CROSSING_UNAVAILABLE"));
        position(body,cell,10.5f,26.5f);
        SAOMovement.tick(body,openedRoute);
        check("actual_door_crossing_keeps_before_state",openedRoute.consumeCrossing().equals("MOVE_CROSSING@0@1@10@25@10@26@0@door@closed"));
        position(body,cell,10.5f,25.5f);
        var detour=route(10.5f,26.5f);
        SAOMovement.tick(body,detour);
        position(body,cell,11.5f,25.5f);
        SAOMovement.tick(body,detour);
        position(body,cell,10.5f,26.5f);
        SAOMovement.tick(body,detour);
        check("detour_does_not_teach_nominated_door",detour.consumeCrossing().equals("MOVE_CROSSING_UNAVAILABLE"));
        position(body,cell,10.5f,25.5f);
        var replacedAperture=route(10.5f,26.5f);
        SAOMovement.tick(body,replacedAperture);
        inside.getObjects().remove(door);inside.getSpecialObjects().remove(door);
        var substitute=new IsoDoor(cell);substitute.setSquare(inside);substitute.north=true;substitute.setSprite(new IsoSprite());
        inside.getObjects().add(substitute);inside.getSpecialObjects().add(substitute);
        position(body,cell,10.5f,26.5f);
        SAOMovement.tick(body,replacedAperture);
        check("replacement_aperture_does_not_teach",replacedAperture.consumeCrossing().equals("MOVE_CROSSING_UNAVAILABLE"));
        inside.getObjects().remove(substitute);inside.getSpecialObjects().remove(substitute);
        inside.getObjects().add(door);inside.getSpecialObjects().add(door);
        position(body,cell,10.5f,25.5f);
        var foreignRoute=route(10.5f,26.5f);
        SAOMovement.tick(body,foreignRoute);
        var foreignBody=(SAOIsoPlayerShell)person.invoke(null,cell);
        position(foreignBody,cell,10.5f,26.5f);
        SAOMovement.tick(foreignBody,foreignRoute);
        check("foreign_body_does_not_consume_crossing",foreignRoute.consumeCrossing().equals("MOVE_CROSSING_UNAVAILABLE"));
        var cancelled=route(10.5f,26.5f);
        SAOMovement.tick(body,cancelled);SAOMovement.cancel(body,cancelled);
        position(body,cell,10.5f,26.5f);
        SAOMovement.tick(body,cancelled);
        check("cancelled_route_drops_crossing",cancelled.consumeCrossing().equals("MOVE_CROSSING_UNAVAILABLE"));
        var restarted=new SAORouteState();
        String firstStart=SAOMovement.begin(body,restarted,10,25,0);
        String nextStart=SAOMovement.begin(body,restarted,10,25,0);
        check("native_route_generation_changes_on_restart",firstStart.endsWith("route=1") && nextStart.endsWith("route=2"));
        position(body,cell,10.5f,25.5f);
        String holders=SAOWorldSources.inspectionCandidates(body,12);System.out.println("HOLDERS "+holders);
        check("open_visible_doorway_offers_exact_holder",holders.contains("C|id=") && !holders.contains("q:food"));
        var row=Arrays.stream(holders.split("\n")).filter(s->s.startsWith("C|")).findFirst().orElseThrow();
        var fields=new HashMap<String,String>();for(String field:row.split("\\|")){int eq=field.indexOf('=');if(eq>0)fields.put(field.substring(0,eq),field.substring(eq+1));}
        String id=java.net.URLDecoder.decode(fields.get("id"),java.nio.charset.StandardCharsets.UTF_8);
        String fp=fields.get("fp");
        var other=(SAOIsoPlayerShell)person.invoke(null,cell);
        check("foreign_actor_cannot_inspect_offered_source",SAOWorldSources.inspectContainer(other,id,fp,10,27,0).equals("NOT_OFFERED"));
        position(body,cell,10.5f,20.5f);
        check("current_reach_refuses_remote_inspection",SAOWorldSources.inspectContainer(body,id,fp,10,27,0).equals("ACCESS_REFUSED"));
        position(body,cell,10.5f,26.5f);
        holder.setSquare(cell.getGridSquare(11,27,0));
        check("changed_native_holder_identity_refuses",SAOWorldSources.inspectContainer(body,id,fp,10,27,0).equals("SOURCE_CHANGED"));
        holder.setSquare(holderSquare);
        String inspected=SAOWorldSources.inspectContainer(body,id,fp,10,27,0);System.out.println("INSPECTED "+inspected);
        if (inspected.equals("INSPECTION_FAILED")) System.out.println(java.nio.file.Files.readString(java.nio.file.Path.of(System.getProperty("user.home"),"Zomboid","SAOAgent.log")));
        check("actual_reachable_holder_inspection",inspected.startsWith("I|source="));
        System.out.println("PASS exterior native checks="+checks);
    }
}
