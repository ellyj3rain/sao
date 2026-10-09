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
        return conceptRow(body,"workbench");
    }
    private static KahluaTable conceptRow(SAOIsoPlayerShell body,String concept) {
        var rows=(KahluaTable)SAOConceptObservation.observe(body,6).rawget("observations");
        for(int i=1;i<=rows.len();i++) {
            var row=(KahluaTable)rows.rawget((double)i);
            if(concept.equals(row.rawget("concept")))return row;
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
        properties.put("CustomName",new ArrayList<>(java.util.List.of("Bed","Chair","Sink","Workbench","Workshop","Painting","Sculpting","Microphone","Hamster Wheel","Contraption","Table")));
        properties.put("GroupName",new ArrayList<>(java.util.List.of("EaselCanvas","EaselCanvasSmall","EaselCanvasLarge","StationWork","Standing","Foreign","Human","Fitness","Ping Pong")));
        properties.put("Facing",new ArrayList<>(java.util.List.of("N","S","E","W")));
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
        var tank=furniture(cell,11,19,"Workshop");
        tank.getSprite().setName("controlled_visible_aquarium");
        var tankData=zombie.Lua.LuaManager.platform.newTable();
        var fish=zombie.Lua.LuaManager.platform.newTable();
        var privateFish=zombie.Lua.LuaManager.platform.newTable();
        privateFish.rawset("privateHealth",0.25);fish.rawset(1.0,privateFish);
        tankData.rawset("fish",fish);tankData.rawset("water",12.0);
        tankData.rawset("privateOwner","foreign");tank.getModData().rawset("KnoxAquarium",tankData);
        var hiddenTank=furniture(cell,13,19,"Workshop");
        hiddenTank.getModData().rawset("KnoxAquarium",tankData);
        var tankView=conceptRow(body,"aquarium");
        check("aquarium_visible_object_acquired",tankView!=null && count(SAOConceptObservation.observe(body,6),"aquarium")==1);
        check("aquarium_exact_physical_locator",Double.valueOf(tank.getObjectIndex()).equals(tankView.rawget("objectIndex"))
            && "controlled_visible_aquarium".equals(tankView.rawget("spriteName")));
        check("aquarium_visible_occupied_water_appearance",Boolean.TRUE.equals(tankView.rawget("aquariumOccupied"))
            && Boolean.TRUE.equals(tankView.rawget("aquariumWaterPresent")) && "water".equals(tankView.rawget("aquariumMode")));
        check("aquarium_private_health_and_quantity_withheld",tankView.rawget("fish")==null
            && tankView.rawget("privateOwner")==null && tankView.rawget("water")==null && tankView.rawget("privateHealth")==null);
        tankData.rawset("mode","dry");tankData.rawset("water",0.0);fish.wipe();
        tankView=conceptRow(body,"aquarium");
        check("aquarium_actual_appearance_change_reacquired","dry".equals(tankView.rawget("aquariumMode"))
            && Boolean.FALSE.equals(tankView.rawget("aquariumWaterPresent")) && Boolean.FALSE.equals(tankView.rawget("aquariumOccupied")));
        tank.getSquare().getObjects().remove(tank);hiddenTank.getSquare().getObjects().remove(hiddenTank);
        var canvas=furniture(cell,11,19,"Painting");
        canvas.getProperties().set("GroupName","EaselCanvasSmall");
        canvas.getSprite().setName("LS_Painting_26");
        var canvasView=conceptRow(body,"art-canvas");
        check("canvas_exact_source_classifier",canvasView!=null && "EaselCanvasSmall".equals(canvasView.rawget("groupName")));
        String canvasKey=(String)canvasView.rawget("key"), canvasInstance=(String)canvasView.rawget("runtimeInstance");
        check("selected_visible_exact_native_object",SAOConceptObservation.resolveVisibleObject(body,canvasKey,canvasInstance)==canvas);
        check("foreign_native_instance_refused",SAOConceptObservation.resolveVisibleObject(body,canvasKey,"foreign-instance")==null);
        canvas.getProperties().set("GroupName","Foreign");
        check("arbitrary_painting_label_not_canvas",conceptRow(body,"art-canvas")==null
            && SAOConceptObservation.resolveVisibleObject(body,canvasKey,canvasInstance)==null);
        canvas.getProperties().set("GroupName","EaselCanvasLarge");
        check("large_canvas_source_classifier",conceptRow(body,"art-canvas")!=null);
        canvas.getProperties().set("GroupName","EaselCanvas");
        check("medium_canvas_source_classifier",conceptRow(body,"art-canvas")!=null);
        var canvasSquare=canvas.getSquare();canvasSquare.getObjects().remove(canvas);
        var replacement=furniture(cell,11,19,"Painting");replacement.getProperties().set("GroupName","EaselCanvas");
        replacement.getSprite().setName("LS_Painting_26");
        check("same_index_replacement_requires_new_acquisition",SAOConceptObservation.resolveVisibleObject(body,canvasKey,canvasInstance)==null);
        canvasSquare.getObjects().remove(replacement);
        var sculpture=furniture(cell,11,19,"Sculpting");sculpture.getProperties().set("GroupName","StationWork");
        check("sculpture_exact_source_classifier",conceptRow(body,"art-sculpture")!=null);
        sculpture.getSquare().getObjects().remove(sculpture);
        var microphone=furniture(cell,11,19,"Microphone");microphone.getProperties().set("GroupName","Standing");
        check("microphone_exact_source_classifier",conceptRow(body,"microphone")!=null);
        microphone.getSquare().getObjects().remove(microphone);
        var piano=furniture(cell,11,19,"Workshop");piano.getSprite().setName("recreational_01_108");
        check("piano_exact_source_sprite",conceptRow(body,"piano")!=null);
        piano.getSprite().setName("recreational_01_107");
        check("nearby_sprite_not_invented_piano",conceptRow(body,"piano")==null);
        piano.getSquare().getObjects().remove(piano);
        var radio=new zombie.iso.objects.IsoRadio(cell,cell.getGridSquare(11,19,0),new IsoSprite());
        radio.getSquare().getObjects().add(radio);
        check("radio_actual_native_class",conceptRow(body,"audio-device")!=null);
        radio.getSquare().getObjects().remove(radio);
        var treadmill=furniture(cell,11,19,"Hamster Wheel");
        treadmill.getProperties().set("GroupName","Human");treadmill.getProperties().set("Facing","E");
        check("treadmill_source_props_and_facing",conceptRow(body,"fitness-treadmill")!=null
            && "E".equals(conceptRow(body,"fitness-treadmill").rawget("facing")));
        treadmill.getProperties().set("GroupName","Foreign");
        check("foreign_treadmill_group_refused",conceptRow(body,"fitness-treadmill")==null);
        treadmill.getSquare().getObjects().remove(treadmill);
        var benchPress=furniture(cell,11,19,"Contraption");benchPress.getProperties().set("GroupName","Fitness");
        check("bench_exact_source_props",conceptRow(body,"fitness-bench")!=null);
        benchPress.getSquare().getObjects().remove(benchPress);
        var mat=furniture(cell,11,19,"Workshop");mat.getSprite().setName("floors_rugs_01_48");
        check("yoga_source_mat_visible",conceptRow(body,"yoga-mat")!=null);
        mat.getSprite().setName("floors_rugs_01_60");
        check("adjacent_rug_not_invented_mat",conceptRow(body,"yoga-mat")==null);
        mat.getSquare().getObjects().remove(mat);
        var pingPong=furniture(cell,11,19,"Table");pingPong.getProperties().set("GroupName","Ping Pong");
        pingPong.getSprite().setName("LS_Recreation_0");
        check("pingpong_actual_source_table",conceptRow(body,"ping-pong-table")!=null);
        pingPong.getSprite().setName("LS_Recreation_4");
        check("adjacent_recreation_sprite_not_pingpong",conceptRow(body,"ping-pong-table")==null);
        pingPong.getSquare().getObjects().remove(pingPong);
        var computer=furniture(cell,11,19,"Workshop");computer.getSprite().setName("appliances_com_01_72");
        check("computer_source_device_visible",conceptRow(body,"computer")!=null);
        computer.getSprite().setName("appliances_com_01_71");
        check("adjacent_appliance_not_computer",conceptRow(body,"computer")==null);
        computer.getSquare().getObjects().remove(computer);
        var claw=furniture(cell,11,19,"Arcade");
        claw.getSprite().setName("pa_recreational_2");
        var clawClassifier=SAOConceptObservation.class.getDeclaredMethod("objectConcept",IsoObject.class);
        clawClassifier.setAccessible(true);
        check("claw_exact_source_classifier","claw-machine".equals(clawClassifier.invoke(null,claw)));
        check("claw_exact_source_sprite_observed",conceptRow(body,"claw-machine")!=null);
        for (int orientation = 3; orientation <= 5; orientation++) {
            claw.getSprite().setName("pa_recreational_" + orientation);
            check("claw_source_orientation_" + orientation,
                "claw-machine".equals(clawClassifier.invoke(null,claw))
                    && conceptRow(body,"claw-machine") != null);
        }
        claw.getSprite().setName("pa_recreational_6");
        check("adjacent_claw_sprite_not_invented",conceptRow(body,"claw-machine")==null);
        claw.getSquare().getObjects().remove(claw);
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
        check("indoor_has_no_outdoor_ground",((KahluaTable)observed.rawget("approaches")).len()==0);
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
        for(int x=16;x<=26;x++) for(int y=16;y<=24;y++) cell.getGridSquare(x,y,0).setSolidFloor(true);
        body.getCurrentSquare().getMovingObjects().remove(body);
        body.setX(20.5f); body.setY(20.5f);
        body.setCurrent(cell.getGridSquare(20,20,0)); body.setSquare(body.getCurrentSquare());
        body.getCurrentSquare().getMovingObjects().add(body);
        body.setForwardDirection(1,0);
        var outside=SAOConceptObservation.observe(body,6);
        var grounds=(KahluaTable)outside.rawget("approaches");
        boolean visibleGround=false, behindGround=false, semanticLeak=false;
        for(int i=1;i<=grounds.len();i++) {
            var ground=(KahluaTable)grounds.rawget((double)i);
            visibleGround|="ground:22:20:0".equals(ground.rawget("key"));
            behindGround|="ground:16:20:0".equals(ground.rawget("key"));
            semanticLeak|=ground.rawget("concept")!=null || ground.rawget("buildingId")!=null
                || ground.rawget("actorId")!=null;
        }
        check("personally_visible_outdoor_ground",visibleGround && grounds.len()<=16);
        check("ground_behind_gaze_withheld",!behindGround);
        check("ground_has_no_imported_meaning",!semanticLeak);
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
