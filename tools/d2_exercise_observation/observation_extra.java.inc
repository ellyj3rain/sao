    private static void extra(SAOIsoPlayerShell body,IsoCell cell)throws Exception {
        var square=cell.getGridSquare(11,19,0);
        var arcade=furniture(cell,11,19,"Workshop");
        String[] sprites={"recreational_01_16","recreational_01_17","recreational_01_18","recreational_01_19",
            "recreational_01_20","recreational_01_21","recreational_01_22","recreational_01_23","recreational_01_24","recreational_01_27",
            "pa_arcades_0","pa_arcades_39","pa_complex_0","pa_complex_9","pa_pinballs_0","pa_pinballs_3",
            "pa_pinballs_4","pa_pinballs_7","pa_pinballs_8","pa_pinballs_11","pa_pinballs_12","pa_pinballs_27"};
        for(var sprite:sprites){arcade.getSprite().setName(sprite);check("arcade_source_sprite_"+sprite,conceptRow(body,"arcade-machine")!=null);}
        for(var sprite:new String[]{"recreational_01_15","recreational_01_25","pa_arcades_40","pa_complex_10","pa_pinballs_1"}){
            arcade.getSprite().setName(sprite);check("adjacent_arcade_sprite_refused_"+sprite,conceptRow(body,"arcade-machine")==null);
        }
        square.getObjects().remove(arcade);
        var item=new zombie.inventory.InventoryItem("NewMusic","BoomboxBlue","BoomboxBlue","");item.setID(8301);
        var placed=new zombie.iso.objects.IsoWorldInventoryObject(cell);
        placed.item=item;placed.setSquare(square);item.setWorldItem(placed);square.getWorldObjects().add(placed);square.getObjects().add(placed);
        var row=conceptRow(body,"placed-item");
        check("placed_actual_world_collection",row!=null&&"worldObjects".equals(row.rawget("objectCollection"))
            &&Double.valueOf(square.getWorldObjects().indexOf(placed)).equals(row.rawget("objectIndex"))
            &&"8301".equals(row.rawget("itemKey"))&&item.getFullType().equals(row.rawget("itemType")));
        check("placed_exact_native_class",placed.getClass().getName().equals(row.rawget("className"))
            &&Integer.toHexString(System.identityHashCode(placed)).equals(row.rawget("runtimeInstance")));
        check("placed_duplicate_acquired_once",count(SAOConceptObservation.observe(body,6),"placed-item")==1);
        check("placed_private_state_withheld",row.rawget("UUID")==null&&row.rawget("media")==null&&row.rawget("deviceState")==null);
        check("placed_not_resolved_as_regular_collection",SAOConceptObservation.resolveVisibleObject(body,(String)row.rawget("key"),(String)row.rawget("runtimeInstance"))==null);
        item.setWorldItem(null);check("placed_replaced_item_custody_refused",conceptRow(body,"placed-item")==null);item.setWorldItem(placed);
        square.getObjects().remove(placed);square.getWorldObjects().remove(placed);
        var hiddenSquare=cell.getGridSquare(13,19,0);placed.setSquare(hiddenSquare);hiddenSquare.getWorldObjects().add(placed);
        check("placed_hidden_native_wall_excluded",conceptRow(body,"placed-item")==null);
        hiddenSquare.getWorldObjects().remove(placed);placed.setSquare(square);square.getWorldObjects().add(placed);
        var priorRoom=square.getRoom();var priorRoomId=square.getRoomID();assign(square,null,-1);
        row=conceptRow(body,"placed-item");
        check("outdoor_visible_object_without_room",row!=null&&row.rawget("roomId")==null&&row.rawget("buildingId")==null);
        assign(square,priorRoom,priorRoomId);square.getWorldObjects().remove(placed);
        zombie.Lua.LuaManager.thread=new se.krka.kahlua.vm.KahluaThread(zombie.Lua.LuaManager.platform,zombie.Lua.LuaManager.env);
        zombie.Lua.LuaManager.thread.debugOwnerThread=Thread.currentThread();
        var vehicle=new zombie.vehicles.BaseVehicle(cell);vehicle.vehicleId=73;vehicle.sqlId=8302;
        vehicle.setSquare(square);vehicle.setCurrent(square);vehicle.setX(11.5f);vehicle.setY(19.5f);vehicle.setZ(0);
        var part=new zombie.vehicles.VehiclePart(vehicle);var scriptPart=new zombie.scripting.objects.VehicleScript.Part();
        scriptPart.id="Radio";part.setScriptPart(scriptPart);vehicle.getParts().add(part);
        var partItemField=zombie.vehicles.VehiclePart.class.getDeclaredField("item");partItemField.setAccessible(true);partItemField.set(part,item);
        cell.getVehicles().add(vehicle);
        row=conceptRow(body,"audio-device");
        check("vehicle_visible_radio_native_part",row!=null&&"vehicle".equals(row.rawget("objectCollection"))
            &&"Radio".equals(row.rawget("partId"))&&Double.valueOf(73).equals(row.rawget("vehicleId"))
            &&Double.valueOf(8302).equals(row.rawget("vehicleSqlId"))&&"8301".equals(row.rawget("itemKey")));
        check("vehicle_exact_runtime_custody",Integer.toHexString(System.identityHashCode(vehicle)).equals(row.rawget("vehicleRuntimeInstance"))
            &&Integer.toHexString(System.identityHashCode(part)).equals(row.rawget("partRuntimeInstance")));
        check("vehicle_private_state_withheld",row.rawget("UUID")==null&&row.rawget("media")==null&&row.rawget("batteryCharge")==null);
        vehicle.setSquare(hiddenSquare);vehicle.setCurrent(hiddenSquare);vehicle.setX(13.5f);
        check("vehicle_hidden_native_wall_excluded",conceptRow(body,"audio-device")==null);
        vehicle.setSquare(square);vehicle.setCurrent(square);vehicle.setX(11.5f);vehicle.setZ(1);
        // The actual square owns its floor. A mismatched vehicle position must not leak its radio.
        check("vehicle_position_floor_mismatch_refused",conceptRow(body,"audio-device")==null);
        vehicle.setZ(0);
        var passengersField=zombie.vehicles.BaseVehicle.class.getDeclaredField("passengers");passengersField.setAccessible(true);
        var passenger=new zombie.vehicles.BaseVehicle.Passenger();
        passengersField.set(vehicle,new zombie.vehicles.BaseVehicle.Passenger[]{passenger});
        check("native_passenger_admission",vehicle.setPassenger(0,body,new org.joml.Vector3f()));
        vehicle.setSquare(hiddenSquare);vehicle.setCurrent(hiddenSquare);vehicle.setX(13.5f);
        body.setVehicle(vehicle);body.setForwardDirection(-1,0);
        row=conceptRow(body,"audio-device");
        check("current_occupant_custody_acquired",row!=null&&"current-occupant".equals(row.rawget("acquisition")));
        vehicle.clearPassenger(0);
        check("spoof_vehicle_without_native_seat_refused",conceptRow(body,"audio-device")==null);
        body.setVehicle(null);body.setForwardDirection(1,0);cell.getVehicles().remove(vehicle);
    }
