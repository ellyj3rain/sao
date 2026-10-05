import com.sao.bridge.SAOBridge;
import com.sao.engine.SAOConceptObservation;
import com.sao.engine.SAOIsoPlayerShell;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import se.krka.kahlua.vm.KahluaTable;
import zombie.characters.IsoPlayer;
import zombie.iso.*;
import zombie.iso.areas.*;
import zombie.iso.objects.IsoDoor;
import zombie.iso.sprite.IsoSprite;
import zombie.iso.SpriteDetails.IsoFlagType;

/** Installed native geometry/LOS with controlled rooms and furniture, not a rendered trial. */
public final class ConceptObservationProbe {
    private static int checks;
    private static void check(String name, boolean value) {
        if (!value) throw new AssertionError("CONCEPT:" + name);
        checks++; System.out.println("CHECK " + name);
    }
    private static Object fixture(String name, Class<?>[] types, Object... args) throws Exception {
        var method = MovementCrossingProbe.class.getDeclaredMethod(name, types);
        method.setAccessible(true); return method.invoke(null, args);
    }
    private static IsoObject furniture(IsoCell cell, int x, int y, String name) {
        var square = cell.getGridSquare(x,y,0); var object = new IsoObject(cell);
        object.setSquare(square); object.setSprite(new IsoSprite());
        object.getProperties().set("CustomName",name); square.getObjects().add(object); return object;
    }
    private static KahluaTable workbenchRow(SAOIsoPlayerShell body) {
        var rows=(KahluaTable)SAOConceptObservation.observe(body,6).rawget("observations");
        for(int i=1;i<=rows.len();i++) {
            var row=(KahluaTable)rows.rawget((double)i);
            if("workbench".equals(row.rawget("concept")))return row;
        }
        return null;
    }
    private static IsoRoom room(IsoBuilding building, long id, String name) {
        var room = new IsoRoom(); room.def = new RoomDef(id,name); room.roomDef = name;
        room.def.setBuilding(building.def); room.building = building; return room;
    }
    private static void assign(IsoGridSquare square, IsoRoom room, long id) {
        square.setRoomID(id); square.setRoom(room); square.setSolidFloor(true);
    }
    private static int count(KahluaTable result, String concept) {
        if (result == null) return -1;
        var rows = (KahluaTable) result.rawget("observations"); int count = 0;
        for (int i=1;i<=rows.len();i++) if (concept.equals(((KahluaTable)rows.rawget((double)i)).rawget("concept"))) count++;
        return count;
    }
    private static boolean sameFrontier(KahluaTable expected, KahluaTable result) {
        var rows=(KahluaTable)result.rawget("frontiers");
        if(rows.len()!=1) return false;
        var actual=(KahluaTable)rows.rawget(1.0);
        var fields=expected.iterator();
        while(fields.advance()) if(!java.util.Objects.equals(fields.getValue(),actual.rawget(fields.getKey()))) return false;
        fields=actual.iterator();
        while(fields.advance()) if(!java.util.Objects.equals(fields.getValue(),expected.rawget(fields.getKey()))) return false;
        return true;
    }
    private static void scalarTree(Object object, HashSet<Object> visited) {
        if (object instanceof KahluaTable table) {
            if (!visited.add(table)) return;
            var iterator=table.iterator(); while(iterator.advance()) {
                if (!(iterator.getKey() instanceof String || iterator.getKey() instanceof Double)) throw new AssertionError("CONCEPT:scalar_key");
                scalarTree(iterator.getValue(),visited);
            }
        } else if (!(object == null || object instanceof String || object instanceof Double || object instanceof Boolean)) throw new AssertionError("CONCEPT:scalar_value");
    }
    public static void main(String[] args) throws Exception {
        IsoCell cell=(IsoCell)fixture("boot",new Class<?>[0]);
        var regions=zombie.iso.areas.isoregion.IsoRegions.class.getDeclaredField("dataRoot");
        regions.setAccessible(true); regions.set(null,new zombie.iso.areas.isoregion.data.DataRoot());
        var properties=new HashMap<String,ArrayList<String>>();
        properties.put("CustomName",new ArrayList<>(java.util.List.of("Bed","Chair","Sink","Workbench","Workshop")));
        properties.put("BedType",new ArrayList<>(java.util.List.of("goodBed")));
        zombie.core.TilePropertyAliasMap.instance.Generate(properties);
        var body=(SAOIsoPlayerShell)fixture("person",new Class<?>[]{IsoCell.class},cell);
        // Body.spawn assigns ordinary SAO identity without an external-owner token.
        body.getModData().rawset("SAOPersonId","observer");
        body.setSquare(body.getCurrentSquare()); body.getCurrentSquare().getMovingObjects().add(body); cell.getObjectList().add(body);
        body.setForwardDirection(1,0);
        var building=new IsoBuilding(cell); building.def=new BuildingDef(); building.def.id=42;
        var occupied=room(building,1,"authored-bedroom"); var hidden=room(building,2,"secret-bedroom");
        for(int x=9;x<=11;x++) for(int y=19;y<=21;y++) assign(cell.getGridSquare(x,y,0),occupied,1);
        for(int x=12;x<=14;x++) for(int y=19;y<=21;y++) assign(cell.getGridSquare(x,y,0),hidden,2);
        var bed=furniture(cell,11,20,"Bed");
        var hiddenBed=furniture(cell,13,20,"Bed");
        var doorSquare=cell.getGridSquare(12,20,0); var door=new IsoDoor(cell);
        door.setSquare(doorSquare); door.north=false; door.setSprite(new IsoSprite());
        doorSquare.getObjects().add(door); doorSquare.getSpecialObjects().add(door);
        check("native_doorway_present",cell.getGridSquare(11,20,0).getDoorTo(doorSquare)==door);
        // Opaque native wall on the same boundary makes the hidden object's absence non-vacuous.
        doorSquare.getProperties().set(IsoFlagType.collideW); doorSquare.getProperties().set(IsoFlagType.cutW);
        doorSquare.ReCalculateVisionBlocked(cell.getGridSquare(11,20,0));
        cell.getGridSquare(11,20,0).ReCalculateVisionBlocked(doorSquare);
        check("native_hidden_boundary_blocks",LosUtil.lineClear(cell,10,20,0,13,20,0,false)==LosUtil.TestResults.Blocked);
        var observed=SAOConceptObservation.observe(body,6);
        check("ordinary_tokenless_observer_admitted",body.getModData().rawget("SAOExternalToken")==null
            && observed!=null && "observer".equals(observed.rawget("actorId")));
        check("visible_bed_observed",count(observed,"bed")==1);
        var bench=furniture(cell,11,21,"Workbench");
        var benchContainer=new zombie.inventory.ItemContainer("toolcabinet",bench.getSquare(),bench);
        bench.setContainer(benchContainer);
        var workshopLabel=furniture(cell,11,19,"Workshop");
        var benchView=SAOConceptObservation.observe(body,6);
        check("visible_workbench_object_observed",count(benchView,"workbench")==1
            && count(benchView,"workshop")==0);
        KahluaTable benchRow=null;
        var benchRows=(KahluaTable)benchView.rawget("observations");
        for(int i=1;i<=benchRows.len();i++) {
            var row=(KahluaTable)benchRows.rawget((double)i);
            if("workbench".equals(row.rawget("concept")))benchRow=row;
        }
        check("workbench_exact_holder_without_contents",benchRow!=null && "object".equals(benchRow.rawget("kind"))
            && benchRow.rawget("sourceId") instanceof String id && id.startsWith("C:")
            && benchRow.rawget("contents")==null && benchRow.rawget("tools")==null);
        String holderId=(String)benchRow.rawget("sourceId");
        var repeatedBench=SAOConceptObservation.observe(body,6);
        boolean sameHolder=false;
        var repeatedRows=(KahluaTable)repeatedBench.rawget("observations");
        for(int i=1;i<=repeatedRows.len();i++) {
            var row=(KahluaTable)repeatedRows.rawget((double)i);
            if("workbench".equals(row.rawget("concept")))sameHolder=holderId.equals(row.rawget("sourceId"));
        }
        check("workbench_holder_identity_stable",sameHolder);
        benchContainer.setSourceGrid(cell.getGridSquare(10,20,0));
        var changedBench=SAOConceptObservation.observe(body,6);
        boolean invalidHolderWithheld=false;
        var changedRows=(KahluaTable)changedBench.rawget("observations");
        for(int i=1;i<=changedRows.len();i++) {
            var row=(KahluaTable)changedRows.rawget((double)i);
            if("workbench".equals(row.rawget("concept")))invalidHolderWithheld=row.rawget("sourceId")==null;
        }
        check("workbench_foreign_container_withheld",invalidHolderWithheld);
        benchContainer.setSourceGrid(bench.getSquare());
        benchContainer.setParent(workshopLabel);
        check("workbench_foreign_parent_withheld",workbenchRow(body).rawget("sourceId")==null);
        benchContainer.setParent(bench);
        bench.getModData().rawset("SAOWorldSourceId",new Object());
        check("workbench_invalid_token_withheld",workbenchRow(body).rawget("sourceId")==null);
        bench.getModData().rawset("SAOWorldSourceId",holderId.split(":")[1]);
        var secondHolder=new zombie.inventory.ItemContainer("second-toolcabinet",bench.getSquare(),bench);
        bench.addSecondaryContainer(secondHolder);
        check("workbench_exact_first_holder_scope",bench.getContainerCount()==2
            && holderId.equals(workbenchRow(body).rawget("sourceId")) && holderId.endsWith(":0"));
        var hiddenBench=furniture(cell,13,21,"Workbench");
        hiddenBench.setContainer(new zombie.inventory.ItemContainer("toolcabinet",hiddenBench.getSquare(),hiddenBench));
        check("hidden_workbench_unobserved",count(SAOConceptObservation.observe(body,6),"workbench")==1
            && hiddenBench.getModData().rawget("SAOWorldSourceId")==null);
        check("authored_room_labels_not_observed",count(observed,"room")==1
            && count(observed,"authored-bedroom")==0 && count(observed,"secret-bedroom")==0);
        var frontiers=(KahluaTable)observed.rawget("frontiers");
        check("visible_doorway_frontier",frontiers.len()==1);
        var frontier=(KahluaTable)frontiers.rawget(1.0);
        check("frontier_exact_approach_and_entry",Double.valueOf(11.5).equals(frontier.rawget("x"))
            && Double.valueOf(12.5).equals(frontier.rawget("entryX")) && "1".equals(frontier.rawget("roomId")));
        check("frontier_far_room_unknown",frontier.rawget("targetRoomId")==null && frontier.rawget("concept")==null);
        // Keep the visible doorway and geometry identical while changing only hidden far-side metadata.
        var otherBuilding=new IsoBuilding(cell); otherBuilding.def=new BuildingDef(); otherBuilding.def.id=43;
        hidden.building=otherBuilding; hidden.def.setBuilding(otherBuilding.def);
        check("hidden_building_does_not_change_frontier",sameFrontier(frontier,SAOConceptObservation.observe(body,6)));
        hidden.building=null; hidden.def.setBuilding(null);
        check("missing_hidden_building_does_not_change_frontier",sameFrontier(frontier,SAOConceptObservation.observe(body,6)));
        hidden.building=building; hidden.def.setBuilding(building.def);
        scalarTree(observed,new HashSet<>());
        check("scalar_only_result",true);
        bed.getSquare().getObjects().add(bed);
        check("duplicate_native_object_once",count(SAOConceptObservation.observe(body,6),"bed")==1);
        bed.getSquare().getObjects().remove(bed);
        var back=furniture(cell,6,20,"Chair");
        check("behind_gaze_not_observed",count(SAOConceptObservation.observe(body,6),"seat")==0);
        body.setForwardDirection(-1,0);
        check("actual_gaze_changes_observation",count(SAOConceptObservation.observe(body,6),"seat")==1);
        body.setForwardDirection(1,0);
        check("radius_limited",count(SAOConceptObservation.observe(body,1),"bed")==1);
        check("invalid_range_refused",SAOConceptObservation.observe(body,0)==null && SAOConceptObservation.observe(body,15)==null);
        body.getModData().rawset("SAOExternalOwner","other");
        body.getModData().rawset("SAOExternalToken","external-owner-token");
        check("foreign_owner_refused",SAOConceptObservation.observe(body,6)==null);
        body.getModData().rawset("SAOExternalOwner",null); body.getModData().rawset("SAOExternalToken",null);
        body.getModData().rawset("ZAOOwned",true);
        check("zao_owner_refused",SAOConceptObservation.observe(body,6)==null); body.getModData().rawset("ZAOOwned",null);
        body.getModData().rawset("SAOPersonId",null);
        check("untagged_body_refused",SAOConceptObservation.observe(body,6)==null); body.getModData().rawset("SAOPersonId","observer");
        IsoPlayer.players[0]=body;
        check("slotted_body_refused",SAOConceptObservation.observe(body,6)==null); IsoPlayer.players[0]=null;
        var square=body.getCurrentSquare(); body.setCurrent(null);
        check("missing_current_square_refused",SAOConceptObservation.observe(body,6)==null); body.setCurrent(square);
        body.setCurrent(cell.getGridSquare(10,21,0));
        check("mismatched_current_square_refused",SAOConceptObservation.observe(body,6)==null); body.setCurrent(square);
        check("bridge_foreign_type_refused",SAOBridge.INSTANCE.conceptObservations(new Object(),6)==null);
        check("bridge_exposes_scalar_observation",SAOBridge.INSTANCE.conceptObservations(body,6)!=null);
        System.out.println("PASS concept observation "+checks);
    }
}
