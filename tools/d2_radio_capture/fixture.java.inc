    public static SAOIsoPlayerShell npc,operator;
    public static int checks,deviceUpdates,npcChat,operatorChat,managerChat;
    public static String lastPresentation;
    public static zombie.inventory.types.Radio watched;
    public static boolean throwPresentation;
    public static java.lang.reflect.Field field(Class<?> type,String name)throws Exception{
        var value=type.getDeclaredField(name);value.setAccessible(true);return value;
    }
    private static void check(String name,boolean value){if(!value)throw new AssertionError("RADIO_CAPTURE:"+name);checks++;System.out.println("CASE "+name);}
    public static final class ChatSink {
        @net.bytebuddy.asm.Advice.OnMethodEnter(skipOn=net.bytebuddy.asm.Advice.OnNonDefaultValue.class)
        public static boolean enter(@net.bytebuddy.asm.Advice.This Object chat,@net.bytebuddy.asm.Advice.AllArguments Object[] args)throws Exception{
            Object owner=field(zombie.chat.ChatElement.class,"owner").get(chat);
            if(owner==npc)npcChat++;if(owner==operator)operatorChat++;
            if(args.length>0&&args[0] instanceof String text)lastPresentation=text;
            if(throwPresentation&&owner==npc)throw new IllegalStateException("controlled text hardware refusal");return true;
        }
    }
    public static final class ManagerSink {
        @net.bytebuddy.asm.Advice.OnMethodEnter(skipOn=net.bytebuddy.asm.Advice.OnNonDefaultValue.class)
        public static boolean enter(){managerChat++;return true;}
    }
    public static final class CountUpdate {
        @net.bytebuddy.asm.Advice.OnMethodEnter
        public static void enter(@net.bytebuddy.asm.Advice.This zombie.radio.devices.DeviceData data){
            if(data.getParent()==watched)deviceUpdates++;
        }
    }
    private static void installHardware(java.lang.instrument.Instrumentation instrumentation){
        new net.bytebuddy.agent.builder.AgentBuilder.Default().disableClassFormatChanges()
            .with(net.bytebuddy.agent.builder.AgentBuilder.RedefinitionStrategy.RETRANSFORMATION)
            .type(net.bytebuddy.matcher.ElementMatchers.named("zombie.chat.ChatElement"))
            .transform((builder,type,loader,module,domain)->builder.visit(net.bytebuddy.asm.Advice.to(ChatSink.class)
                .on(net.bytebuddy.matcher.ElementMatchers.named("addChatLine"))))
            .type(net.bytebuddy.matcher.ElementMatchers.named("zombie.chat.ChatManager"))
            .transform((builder,type,loader,module,domain)->builder.visit(net.bytebuddy.asm.Advice.to(ManagerSink.class)
                .on(net.bytebuddy.matcher.ElementMatchers.named("showRadioMessage").or(net.bytebuddy.matcher.ElementMatchers.named("showStaticRadioSound")))))
            .type(net.bytebuddy.matcher.ElementMatchers.named("zombie.radio.devices.DeviceData"))
            .transform((builder,type,loader,module,domain)->builder.visit(net.bytebuddy.asm.Advice.to(CountUpdate.class)
                .on(net.bytebuddy.matcher.ElementMatchers.named("update").and(net.bytebuddy.matcher.ElementMatchers.takesArguments(boolean.class,boolean.class)))))
            .installOn(instrumentation);
    }
    private static void configure(zombie.inventory.types.Radio radio,SAOIsoPlayerShell body)throws Exception{
        body.getInventory().AddItem(radio);body.setPrimaryHandItem(radio);body.setSecondaryHandItem(null);
        var nativeEquip=zombie.characters.IsoGameCharacter.class.getDeclaredMethod("radioEquipedCheck");nativeEquip.setAccessible(true);nativeEquip.invoke(body);
        var data=radio.getDeviceData();data.setIsPortable(true);data.setHasBattery(true);data.setPower(1);data.setDeviceVolumeRaw(.5f);
        data.setMinChannelRange(200);data.setMaxChannelRange(100000);data.setChannelRaw(88000);data.setIsTurnedOn(true);
        field(zombie.radio.devices.DeviceData.class,"emitter").set(data,new zombie.audio.DummySoundEmitter());
    }
    private static KahluaTable events(String work){return com.sao.engine.SAORadioPlayback.events(npc,work,0);}
    private static KahluaTable latest(String work){var rows=events(work);return rows==null||rows.len()==0?null:(KahluaTable)rows.rawget((double)rows.len());}
    private static int count(String work){var rows=events(work);return rows==null?0:rows.len();}
    private static void broadcast(String text,int channel){zombie.radio.ZomboidRadio.getInstance().DistributeTransmission(100,100,channel,text,"fixture-guid","fixture-codes",1,.8f,.6f,-1,false);}
    private static void text(zombie.inventory.types.Radio radio,String line){radio.AddDeviceText(line,1,.8f,.6f,"fixture-guid","fixture-codes",5);}
    @SuppressWarnings("unchecked")
    private static void expireLast(SAOIsoPlayerShell body)throws Exception{
        var listeners=(java.util.Map<Object,Object>)field(com.sao.engine.SAORadioPlayback.class,"LISTENERS").get(null);
        Object listener=listeners.get(body);var queue=(java.util.ArrayDeque<Object>)field(listener.getClass(),"events").get(listener);
        Object old=queue.removeLast();var components=old.getClass().getRecordComponents();Object[] args=new Object[components.length];Class<?>[] types=new Class<?>[components.length];
        for(int i=0;i<components.length;i++){var getter=components[i].getAccessor();getter.setAccessible(true);args[i]=getter.invoke(old);types[i]=components[i].getType();if(components[i].getName().equals("nanoTime"))args[i]=System.nanoTime()-6_000_000_000L;}
        var ctor=old.getClass().getDeclaredConstructor(types);ctor.setAccessible(true);queue.addLast(ctor.newInstance(args));
    }
    private static void frame(int value)throws Exception{field(zombie.iso.IsoWorld.class,"frameNo").setInt(zombie.iso.IsoWorld.instance,value);}
    private static void exercise(SAOIsoPlayerShell body,SAOIsoPlayerShell other,zombie.inventory.types.Radio radio,zombie.inventory.types.Radio operatorRadio,KahluaThread thread,KahluaTable env)throws Exception{
        npc=body;operator=other;watched=radio;
        npc.getModData().rawset("SAOPersonId","radio-person");npc.getModData().rawset("SAOExternalToken","radio-body-1");
        operator.getModData().rawset("SAOPersonId","operator-person");operator.playerIndex=0;
        zombie.characters.IsoPlayer.players[0]=operator;zombie.characters.IsoPlayer.numPlayers=1;
        configure(radio,npc);configure(operatorRadio,operator);
        var instrumentation=net.bytebuddy.agent.ByteBuddyAgent.install();installHardware(instrumentation);
        com.sao.agent.SAORadioPlaybackWeave.install(instrumentation);
        check("all_seven_original_targets_transformed",com.sao.agent.SAORadioPlaybackWeave.ready());
        System.out.println("WEAVE "+com.sao.agent.SAORadioPlaybackWeave.report());
        check("actual_off_slot_native_receiver",npc.getEquipedRadio()==radio&&radio.getPlayer()==npc&&zombie.characters.IsoPlayer.players[0]!=npc);
        zombie.Lua.LuaEventManager.AddEvent("OnDeviceText").register(zombie.Lua.LuaManager.platform,(KahluaTable)env.rawget("Events"));
        thread.call(LuaCompiler.loadstring("__deviceEvents=0;Events.OnDeviceText.Add(function()__deviceEvents=__deviceEvents+1 end)","radio-event-observer",env),null,null,null);
        broadcast("native-before-work",88000);
        check("preadmission_emission_not_captured",events("work-1")==null);
        check("register_current_native_receiver",com.sao.engine.SAORadioPlayback.register(npc,"work-1",radio,"private-carried-radio"));
        check("native_foreign_receiver_refused",!com.sao.engine.SAORadioPlayback.register(npc,"foreign",operatorRadio,"foreign-source"));
        check("native_same_registration_idempotent",com.sao.engine.SAORadioPlayback.register(npc,"work-1",radio,"private-carried-radio"));
        check("native_different_work_refused",!com.sao.engine.SAORadioPlayback.register(npc,"different-work",radio,"private-carried-radio"));
        int prior=count("work-1"),opChat=operatorChat,managerBefore=managerChat;double eventBefore=((Number)env.rawget("__deviceEvents")).doubleValue();
        broadcast("native-current-owned-emission",88000);
        var row=latest("work-1");
        check("original_distribution_private_capture",count("work-1")==prior+1&&row!=null&&"native-current-owned-emission".equals(row.rawget("text")));
        check("native_payload_exact_binding","radio-person".equals(row.rawget("actorId"))&&"work-1".equals(row.rawget("workId"))
            &&"fixture-guid".equals(row.rawget("guid"))&&"fixture-codes".equals(row.rawget("codes"))&&Double.valueOf(88000).equals(row.rawget("channel")));
        check("original_operator_chat_retained",operatorChat>opChat);
        check("operator_event_and_private_scope",((Number)env.rawget("__deviceEvents")).doubleValue()==eventBefore+1&&!com.sao.engine.SAORadioPlayback.privateChat());
        check("private_manager_operator_route_preserved",managerChat==managerBefore+1);
        long sequence=((Number)row.rawget("sequence")).longValue();
        check("native_emission_current",com.sao.engine.SAORadioPlayback.eventCurrent(npc,"work-1",sequence,radio));
        check("wrong_work_and_source_refused",!com.sao.engine.SAORadioPlayback.eventCurrent(npc,"other",sequence,radio)
            &&!com.sao.engine.SAORadioPlayback.eventCurrent(npc,"work-1",sequence,operatorRadio));
        radio.getDeviceData().setChannelRaw(88100);
        check("changed_channel_invalidates_emission",!com.sao.engine.SAORadioPlayback.eventCurrent(npc,"work-1",sequence,radio));
        prior=count("work-1");broadcast("wrong-current-channel",88000);
        check("original_wrong_channel_not_captured",count("work-1")==prior);radio.getDeviceData().setChannelRaw(88000);
        radio.getDeviceData().setMediaIndex((short)3);
        check("changed_media_invalidates_emission",!com.sao.engine.SAORadioPlayback.eventCurrent(npc,"work-1",sequence,radio));radio.getDeviceData().setMediaIndex((short)-1);
        npc.getCharacterTraits().set(zombie.scripting.objects.CharacterTrait.DEAF,true);text(radio,"deaf-line");
        check("native_deaf_emission_not_captured",count("work-1")==prior);npc.getCharacterTraits().set(zombie.scripting.objects.CharacterTrait.DEAF,false);
        npc.setAsleep(true);text(radio,"asleep-line");check("native_sleep_emission_not_captured",events("work-1")==null);npc.setAsleep(false);
        npc.getModData().rawset("SAOExternalToken","replacement-token");text(radio,"stale-generation-line");
        check("native_body_generation_refused",events("work-1")==null);npc.getModData().rawset("SAOExternalToken","radio-body-1");
        npc.setPrimaryHandItem(null);var nativeEquip=zombie.characters.IsoGameCharacter.class.getDeclaredMethod("radioEquipedCheck");nativeEquip.setAccessible(true);nativeEquip.invoke(npc);text(radio,"lost-equipped-custody");
        check("lost_receiver_custody_not_captured",count("work-1")==prior);npc.setPrimaryHandItem(radio);nativeEquip.invoke(npc);
        prior=count("work-1");text(radio,"native-concrete-radio-line");
        check("concrete_original_text_capture",count("work-1")==prior+1&&"native-concrete-radio-line".equals(latest("work-1").rawget("text")));
        npc.getModData().rawset("SAOExternalOwner","foreign");text(radio,"foreign-owned-body");
        check("native_foreign_body_owner_refused",events("work-1")==null);npc.getModData().rawset("SAOExternalOwner",null);
        prior=count("work-1");throwPresentation=true;
        try{text(radio,"failed-original-presentation");}catch(IllegalStateException expected){}
        finally{throwPresentation=false;}
        check("failed_original_method_not_captured",count("work-1")==prior&&!com.sao.engine.SAORadioPlayback.privateChat());
        throwPresentation=true;prior=count("work-1");opChat=operatorChat;
        try{broadcast("throwing-owned-private-distribution",88000);}finally{throwPresentation=false;}
        check("throwing_distribution_finally_scope",count("work-1")==prior&&operatorChat>opChat&&!com.sao.engine.SAORadioPlayback.privateChat());
        managerBefore=managerChat;zombie.chat.ChatManager.getInstance().showStaticRadioSound("after-private-exception");
        check("operator_manager_after_exception_retained",managerChat==managerBefore+1);
        prior=count("work-1");radio.AddDeviceText(operator,"foreign-explicit-recipient",1f,.8f,.6f,"fixture-guid","fixture-codes",5);
        check("foreign_default_recipient_refused",count("work-1")==prior);
        radio.getDeviceData().setTurnedOnRaw(false);text(radio,"powered-off-line");
        check("powered_off_emission_refused",count("work-1")==prior);radio.getDeviceData().setTurnedOnRaw(true);
        radio.getDeviceData().setDeviceVolumeRaw(0);text(radio,"muted-line");
        check("zero_volume_emission_refused",count("work-1")==prior);radio.getDeviceData().setDeviceVolumeRaw(.5f);
        var copied=latest("work-1");String originalText=(String)copied.rawget("text");copied.rawset("text","caller-forgery");
        check("detached_event_no_caller_rewrite",originalText.equals(latest("work-1").rawget("text")));
        check("cursor_no_duplicate_replay",com.sao.engine.SAORadioPlayback.events(npc,"work-1",((Number)copied.rawget("sequence")).longValue()).len()==0);
        expireLast(npc);long expired=((Number)copied.rawget("sequence")).longValue();
        check("stale_event_refused",!com.sao.engine.SAORadioPlayback.eventCurrent(npc,"work-1",expired,radio));
        check("stale_event_not_exported",com.sao.engine.SAORadioPlayback.events(npc,"work-1",expired-1).len()==0);
        frame(50);int updates=deviceUpdates;var tick=com.sao.engine.SAORadioPlayback.tick(npc,"work-1");
        check("actual_native_device_update_once",tick!=null&&Boolean.TRUE.equals(tick.rawget("nativeAdvanced"))&&deviceUpdates==updates+1);
        tick=com.sao.engine.SAORadioPlayback.tick(npc,"work-1");radio.update();
        check("same_native_frame_not_double_updated",tick!=null&&Boolean.FALSE.equals(tick.rawget("nativeAdvanced"))&&deviceUpdates==updates+1);
        frame(51);tick=com.sao.engine.SAORadioPlayback.tick(npc,"work-1");
        check("next_native_frame_updates",Boolean.TRUE.equals(tick.rawget("nativeAdvanced"))&&deviceUpdates==updates+2);
        check("portable_update_scope_released",!com.sao.engine.SAORadioPlayback.privateChat());
        var recorded=new zombie.radio.media.RecordedMedia();
        var media=recorded.register("CDs","fixture-current-media","fixture-current-title",0);
        media.addLine("fixture-native-media-line",1f,.7f,.4f,"fixture-media-codes");
        var unseen=recorded.register("CDs","fixture-unheard-media","fixture-unheard-title",0);
        unseen.addLine("fixture-unheard-line",1f,1f,1f,"unheard-codes");
        field(zombie.radio.ZomboidRadio.class,"recordedMedia").set(null,recorded);
        var device=radio.getDeviceData();device.setMediaIndex(media.getIndex());device.StartPlayMedia();
        check("actual_native_media_started",device.isPlayingMedia()&&device.getMediaData()==media);
        prior=count("work-1");eventBefore=((Number)env.rawget("__deviceEvents")).doubleValue();
        field(zombie.radio.devices.DeviceData.class,"lineCounter").setFloat(device,0);frame(52);
        tick=com.sao.engine.SAORadioPlayback.tick(npc,"work-1");row=latest("work-1");
        check("original_device_media_emission",count("work-1")==prior+1&&media.getLine(0).getTranslatedText().equals(row.rawget("text"))
            &&"fixture-native-media-line".equals(row.rawget("guid"))&&"fixture-media-codes".equals(row.rawget("codes"))
            &&Double.valueOf(media.getIndex()).equals(row.rawget("mediaIndex")));
        check("media_private_event_scope",((Number)env.rawget("__deviceEvents")).doubleValue()==eventBefore&&!com.sao.engine.SAORadioPlayback.privateChat());
        prior=count("work-1");broadcast("broadcast-during-media",88000);
        check("original_playing_media_refuses_broadcast",count("work-1")==prior);
        com.sao.engine.SAORadioPlayback.tick(npc,"work-1");check("same_frame_media_no_duplicate",count("work-1")==prior);
        check("unheard_registry_no_capture",!"fixture-unheard-line".equals(row.rawget("text"))&&field(zombie.radio.devices.DeviceData.class,"mediaLineIndex").getInt(device)==1);
        device.StopPlayMedia();field(zombie.radio.devices.DeviceData.class,"stopMediaCounter").setFloat(device,0);device.updateMediaPlaying();
        check("actual_native_media_stop_completed",!device.isPlayingMedia());device.setMediaIndex((short)-1);
        for(int i=0;i<40;i++)text(radio,"bounded-source-line-"+i);
        check("bounded_emission_ring",count("work-1")==32&&"bounded-source-line-39".equals(latest("work-1").rawget("text")));
        zombie.network.GameClient.client=true;
        check("multiplayer_registration_refused",!com.sao.engine.SAORadioPlayback.register(npc,"mp",radio,"mp-source")&&events("work-1")==null);
        zombie.network.GameClient.client=false;
        com.sao.engine.SAORadioPlayback.unregister(npc,"work-1");
        check("unregister_retired_work",events("work-1")==null);
        broadcast("after-retired-work",88000);check("retired_work_no_capture",events("work-1")==null);
        var worldSource=new zombie.iso.objects.IsoWaveSignal(npc.getCell());worldSource.setSquare(npc.getCurrentSquare());npc.getCurrentSquare().getObjects().add(worldSource);
        var worldData=new zombie.radio.devices.DeviceData(worldSource);worldSource.setDeviceData(worldData);
        worldData.setTurnedOnRaw(true);worldData.setDeviceVolumeRaw(.5f);worldData.setChannelRaw(88000);
        field(zombie.radio.devices.DeviceData.class,"emitter").set(worldData,new zombie.audio.DummySoundEmitter());
        check("native_visible_world_receiver_register",com.sao.engine.SAORadioPlayback.register(npc,"world-work",worldSource,"personally-visible-world-radio"));
        prior=count("world-work");broadcast("separate-equipped-radio-broadcast",88000);
        check("world_listener_cannot_capture_separate_radio",count("world-work")==prior);
        worldSource.AddDeviceText("actual-selected-world-emission",1f,.8f,.6f,"world-guid","world-codes",5);
        check("original_selected_world_text_capture",count("world-work")==prior+1&&"actual-selected-world-emission".equals(latest("world-work").rawget("text")));
        com.sao.engine.SAORadioPlayback.resetRuntimeForWorld();
        check("runtime_reset_loses_work_custody",events("world-work")==null&&events("work-1")==null&&!com.sao.engine.SAORadioPlayback.privateChat());
        var clock=zombie.GameTime.getInstance();clock.setNightsSurvived(0);clock.setTimeOfDay(19);
        check("explicit_county_clock_registration",com.sao.engine.SAORadioPlayback.register(npc,"clock-work",radio,"clock-source",1012d));
        text(radio,"county-offset-emission");row=latest("clock-work");
        check("exact_county_native_offset",Double.valueOf(1012).equals(row.rawget("atHours"))&&Double.valueOf(12).equals(row.rawget("engineAtHours"))
            &&"native-emission-registration-county-offset".equals(row.rawget("clockAuthority")));
        clock.setTimeOfDay(20);text(radio,"county-offset-later");row=latest("clock-work");
        check("county_native_elapsed_delta",Double.valueOf(1013).equals(row.rawget("atHours"))&&Double.valueOf(13).equals(row.rawget("engineAtHours")));
        sequence=((Number)row.rawget("sequence")).longValue();clock.setTimeOfDay(18);prior=count("clock-work");text(radio,"regressed-clock-line");
        check("regressed_clock_no_emission",count("clock-work")==prior);
        check("regressed_clock_event_not_current",!com.sao.engine.SAORadioPlayback.eventCurrent(npc,"clock-work",sequence,radio));
        clock.setTimeOfDay(20);check("immutable_county_event_mapping",Double.valueOf(1013).equals(latest("clock-work").rawget("atHours")));
        com.sao.engine.SAORadioPlayback.resetRuntimeForWorld();
        check("nonfinite_county_registration_refused",!com.sao.engine.SAORadioPlayback.register(npc,"invalid-clock",radio,"clock-source",Double.NaN));
        System.out.println("PASS native radio capture "+checks);
    }
