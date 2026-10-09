    private static void audioExtra(SAOIsoPlayerShell body,IsoCell cell)throws Exception {
        var square=cell.getGridSquare(11,19,0);var hidden=cell.getGridSquare(13,19,0);
        var item=new zombie.inventory.InventoryItem("NewMusic","BoomboxBlue","BoomboxBlue","");item.setID(8311);
        var placed=new zombie.iso.objects.IsoWorldInventoryObject(cell);placed.item=item;placed.setSquare(square);
        item.setWorldItem(placed);square.getWorldObjects().add(placed);
        var row=conceptRow(body,"placed-item");String key=(String)row.rawget("key"),instance=(String)row.rawget("runtimeInstance");
        var target=com.sao.engine.SAOLeisureAudioAccess.resolve(body,key,instance);
        check("audio_exact_native_object_item",target!=null&&target.rawget("object")==placed&&target.rawget("item")==item);
        check("audio_foreign_instance_refused",com.sao.engine.SAOLeisureAudioAccess.resolve(body,key,"foreign")==null);
        check("audio_native_near_hearing",com.sao.engine.SAOPerceptionScanner.canHearSourceNow(body,square,10));
        check("audio_source_target_hearing",com.sao.engine.SAOLeisureAudioAccess.canHear(body,key,instance,10));
        check("audio_native_distance_limit",!com.sao.engine.SAOPerceptionScanner.canHearSourceNow(body,square,.1f));
        check("audio_native_wall_blocks",!com.sao.engine.SAOPerceptionScanner.canHearSourceNow(body,hidden,10));
        var upper=zombie.iso.IsoGridSquare.getNew(cell,null,11,19,1);cell.setCacheGridSquare(11,19,1,upper);
        check("audio_native_other_floor_refused",!com.sao.engine.SAOPerceptionScanner.canHearSourceNow(body,upper,10));
        body.getCharacterTraits().set(zombie.scripting.objects.CharacterTrait.DEAF,true);
        check("audio_native_deaf_refused",!com.sao.engine.SAOPerceptionScanner.canHearSourceNow(body,square,10)
            &&!com.sao.engine.SAOLeisureAudioAccess.canHear(body,key,instance,10));
        body.getCharacterTraits().set(zombie.scripting.objects.CharacterTrait.DEAF,false);body.setAsleep(true);
        check("audio_native_sleep_refused",!com.sao.engine.SAOPerceptionScanner.canHearSourceNow(body,square,10)
            &&com.sao.engine.SAOLeisureAudioAccess.resolve(body,key,instance)==null);body.setAsleep(false);
        item.setWorldItem(null);check("audio_native_item_custody_revocation",com.sao.engine.SAOLeisureAudioAccess.resolve(body,key,instance)==null);item.setWorldItem(placed);
        square.getWorldObjects().remove(placed);placed.setSquare(hidden);hidden.getWorldObjects().add(placed);
        check("audio_hidden_target_refused",com.sao.engine.SAOLeisureAudioAccess.resolve(body,key,instance)==null);
        hidden.getWorldObjects().remove(placed);placed.setSquare(square);square.getWorldObjects().add(placed);
        var replacement=new zombie.iso.objects.IsoWorldInventoryObject(cell);replacement.item=item;replacement.setSquare(square);item.setWorldItem(replacement);
        square.getWorldObjects().set(0,replacement);
        check("audio_same_index_native_replacement_refused",com.sao.engine.SAOLeisureAudioAccess.resolve(body,key,instance)==null);
        square.getWorldObjects().remove(replacement);
        body.getModData().rawset("SAOExternalOwner","foreign");
        check("audio_foreign_owner_refused",!com.sao.engine.SAOPerceptionScanner.canHearSourceNow(body,square,10)
            &&com.sao.engine.SAOLeisureAudioAccess.resolve(body,key,instance)==null);body.getModData().rawset("SAOExternalOwner",null);
        check("audio_invalid_hearing_range_refused",!com.sao.engine.SAOPerceptionScanner.canHearSourceNow(body,square,Float.NaN)
            &&!com.sao.engine.SAOPerceptionScanner.canHearSourceNow(body,square,0));
        var vehicle=new zombie.vehicles.BaseVehicle(cell);vehicle.vehicleId=74;vehicle.sqlId=8312;
        vehicle.setX(11.5f);vehicle.setY(19.5f);vehicle.setZ(0);vehicle.setCurrent(square);
        var part=new zombie.vehicles.VehiclePart(vehicle);var definition=new zombie.scripting.objects.VehicleScript.Part();definition.id="Radio";
        part.setScriptPart(definition);vehicle.getParts().add(part);
        var itemField=zombie.vehicles.VehiclePart.class.getDeclaredField("item");itemField.setAccessible(true);itemField.set(part,item);
        cell.getVehicles().add(vehicle);row=conceptRow(body,"audio-device");key=(String)row.rawget("key");instance=(String)row.rawget("runtimeInstance");
        target=com.sao.engine.SAOLeisureAudioAccess.resolve(body,key,instance);
        check("audio_vehicle_exact_native_receiver",target!=null&&target.rawget("vehicle")==vehicle&&target.rawget("part")==part);
        check("audio_vehicle_actual_hearing",com.sao.engine.SAOLeisureAudioAccess.canHear(body,key,instance,10));
        check("audio_vehicle_foreign_part_refused",com.sao.engine.SAOLeisureAudioAccess.resolve(body,key,"foreign-part")==null);
        vehicle.sqlId++;
        check("audio_vehicle_replaced_persistent_identity_refused",com.sao.engine.SAOLeisureAudioAccess.resolve(body,key,instance)==null);vehicle.sqlId--;
        itemField.set(part,null);check("audio_vehicle_removed_radio_item_refused",com.sao.engine.SAOLeisureAudioAccess.resolve(body,key,instance)==null);itemField.set(part,item);
        vehicle.setX(13.5f);vehicle.setCurrent(hidden);
        check("audio_vehicle_hidden_receiver_refused",com.sao.engine.SAOLeisureAudioAccess.resolve(body,key,instance)==null);
        cell.getVehicles().remove(vehicle);
    }
