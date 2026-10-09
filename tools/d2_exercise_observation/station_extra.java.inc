    private static void stations(SAOIsoPlayerShell body,IsoCell cell) {
        var square=cell.getGridSquare(11,19,0);
        var jukebox=furniture(cell,11,19,"Jukebox");jukebox.getSprite().setName("source_jukebox_fixture");
        var row=conceptRow(body,"jukebox");
        check("jukebox_source_custom_name",row!=null);
        String key=(String)row.rawget("key"),instance=(String)row.rawget("runtimeInstance");
        var bridge=SAOBridge.INSTANCE;
        check("jukebox_actual_native_hearing",bridge.canHearLeisureObject(body,key,instance,8));
        check("unknown_station_not_resolved",!bridge.canHearLeisureObject(body,"unknown",instance,8));
        check("wrong_instance_not_heard",!bridge.canHearLeisureObject(body,key,"foreign",8));
        check("invalid_range_refused",!bridge.canHearLeisureObject(body,key,instance,Double.NaN));
        check("zero_range_refused",!bridge.canHearLeisureObject(body,key,instance,0));
        check("negative_range_refused",!bridge.canHearLeisureObject(body,key,instance,-8));
        body.getCharacterTraits().add(zombie.scripting.objects.CharacterTrait.DEAF);
        check("native_deaf_station_refused",!bridge.canHearLeisureObject(body,key,instance,8));
        body.getCharacterTraits().remove(zombie.scripting.objects.CharacterTrait.DEAF);
        body.setAsleep(true);
        check("native_asleep_station_refused",!bridge.canHearLeisureObject(body,key,instance,8));body.setAsleep(false);
        square.getObjects().remove(jukebox);
        var replacement=furniture(cell,11,19,"Jukebox");replacement.getSprite().setName("source_jukebox_fixture");
        check("replaced_station_instance_refused",!bridge.canHearLeisureObject(body,key,instance,8));
        square.getObjects().remove(replacement);
        var hidden=furniture(cell,13,19,"Jukebox");hidden.getSprite().setName("source_jukebox_fixture");
        check("hidden_jukebox_unacquired",conceptRow(body,"jukebox")==null);
        hidden.getSquare().getObjects().remove(hidden);
        var booth=furniture(cell,11,19,"Booth");
        for(String sprite:new String[]{"ls_djbooth_01_1","ls_djbooth_01_4"}) {
            booth.getSprite().setName(sprite);check("dj_source_center_"+sprite,conceptRow(body,"dj-booth")!=null);
        }
        for(String sprite:new String[]{"ls_djbooth_01_0","ls_djbooth_01_2","ls_djbooth_01_3","ls_djbooth_01_5"}) {
            booth.getSprite().setName(sprite);
            check("dj_source_part_"+sprite,conceptRow(body,"dj-booth-part")!=null&&conceptRow(body,"dj-booth")==null);
        }
        for(String sprite:new String[]{"ls_djbooth_01_6","ls_djbooth_01_14","ls_djbooth_02_1"}) {
            booth.getSprite().setName(sprite);
            check("adjacent_dj_sprite_refused_"+sprite,conceptRow(body,"dj-booth-part")==null&&conceptRow(body,"dj-booth")==null);
        }
        booth.getSprite().setName("ls_djbooth_01_1");booth.getProperties().set("CustomName","Workshop");
        check("dj_source_custom_name_required",conceptRow(body,"dj-booth")==null);
        square.getObjects().remove(booth);
    }
