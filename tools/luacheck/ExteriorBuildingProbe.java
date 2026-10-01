import com.sao.engine.*;
import java.util.*;
import zombie.iso.*;
import zombie.iso.areas.*;
import zombie.iso.objects.IsoDoor;
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
        check("exterior_row_has_no_center_layout_or_stock",Arrays.stream(sight.split("\\|")).filter(s->s.startsWith("B:")).allMatch(s->s.split(":").length==8)
            && !sight.contains("20.0") && !sight.contains("food") && !sight.contains("room"));
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
        check("physical_locked_entry_refuses",SAOMovement.tick(body,route(10.5f,26.5f)).equals("FailedObstacle:FAILED_LOCKED_DOOR"));
        door.setLockedByKey(false);
        String entry=SAOMovement.tick(body,route(10.5f,26.5f));System.out.println("NATIVE_DOOR_ENTRY "+entry);
        check("observed_closed_door_opened_by_native_movement",door.IsOpen() && entry.contains("OPENING_DOOR"));
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
        check("actual_reachable_holder_inspection",inspected.startsWith("I|source="));
        System.out.println("PASS exterior native checks="+checks);
    }
}
