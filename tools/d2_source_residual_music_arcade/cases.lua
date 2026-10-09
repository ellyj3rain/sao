if MODE=='time' then
 getNowMs=function()check(false,'foreign_control_foreign_helper_consulted')end
 check(NMDeviceUiTime.nowMs()==NOW,'timestamp_native_first_foreign_ignored')
 getTimestampMs=function()return nil end;getTimeInMillis=function()return '123' end
 check(NMDeviceUiTime.nowMs()==123,'millis_second_numeric')
 getTimeInMillis=function()return nil end;getTimestamp=function()return '2.5' end
 check(NMDeviceUiTime.nowMs()==2500,'seconds_converted_once')
 getTimestamp=nil;check(NMDeviceUiTime.nowMs()==0,'absent_timestamp_zero')
 getTimestampMs=nativeTimestampMs;local lo=nativeTimestampMs();local now=NMDeviceUiTime.nowMs();local hi=nativeTimestampMs();check(now>=lo and now<=hi,'actual_installed_timestamp_ms')
 getTimestampMs=nil;getTimeInMillis=nativeTimeInMillis;lo=nativeTimeInMillis();now=NMDeviceUiTime.nowMs();hi=nativeTimeInMillis();check(now>=lo and now<=hi,'actual_installed_millis')
 getTimeInMillis=nil;getTimestamp=nativeTimestamp;lo=nativeTimestamp()*1000;now=NMDeviceUiTime.nowMs();hi=nativeTimestamp()*1000;check(now>=lo and now<=hi,'actual_installed_timestamp_seconds')
elseif MODE=='ledger' then
 NMServerZombieVisualTargetLedger={logDiag=function()check(false,'foreign_control_foreign_diagnostic_owner')end}
 DEBUG=false;NMServerZombieVisualTargetPublisher.onTick(1,60);check(#LOGS==0,'debug_off_no_diagnostic')
 DEBUG=true;NMServerZombieVisualTargetPublisher.onTick(1,120)
 local n=0;for _,row in ipairs(LOGS)do if type(row)=='string' and string.find(row,'target_ledger')then n=n+1 end end
 check(n==1,'exact_ledger_diagnostic_once');check(#COMMANDS==0,'diagnostic_no_duplicate_publication')
elseif MODE=='media' then
 NMUI={logPortableUiProbe=function()check(false,'foreign_control_foreign_diagnostic_owner')end}
 local fn=nativeLocal(1,'logPortableUiProbe')
 DEBUG=false;fn('test','detail');check(#LOGS==0,'portable_debug_off')
 DEBUG=true;fn('test','detail');check(#LOGS==1 and LOGS[1].channel=='portable_ui' and LOGS[1].tag=='test','portable_exact_log_contract')
 fn(nil,nil);check(LOGS[2].tag=='portable_ui' and LOGS[2].detail=='','portable_nil_defaults')
elseif MODE=='radial' then
 getLoopPolicy=function()return 'foreign' end
 playWalkmanTransportSound=function()check(false,'foreign_control_foreign_helper')end;playCDPlayerTransportSound=playWalkmanTransportSound;playCDPlayerRandomBeep=playWalkmanTransportSound;playCDPlayerManualPlaySound=playWalkmanTransportSound
 local mode=nativeLocal(4,'handleWalkmanMode');local play=nativeLocal(4,'handleCDPlayerPlayStop')
 local window={state={playbackPolicy='autoplay',mediaFullType='cassette'}}
 function window:resolveContextCached()return{state=self.state}end
 function window:executeUiControl(command,args)self.command=command;self.args=args;return self.success~=false end
 mode(window);check(window.args.playbackPolicy=='loop_song','window_owned_policy');check(#UI_SOUNDS==1 and UI_SOUNDS[1].window==window and UI_SOUNDS[1].name=='NM_Walkman_Power_On','walkman_exact_private_sound')
 window.state.playbackPolicy='loop_song';mode(window);check(window.args.playbackPolicy=='loop_album','loop_song_to_album')
 window.state.playbackPolicy='loop_album';mode(window);check(window.args.playbackPolicy=='autoplay','loop_album_to_auto')
 local foreign=rawget(NMWalkmanWindowEnv,'playWalkmanTransportSound');NMWalkmanWindowEnv.playWalkmanTransportSound=nil;local n=#UI_SOUNDS;mode(window);check(#UI_SOUNDS==n,'missing_private_helper_does_not_use_foreign');NMWalkmanWindowEnv.playWalkmanTransportSound=foreign
 function window:buildTransportState()return self.transport end
 window.transport={trackCount=2,isPlaying=true,isOn=true};n=#UI_SOUNDS;check(play(window)==true,'cd_stop_success');check(#UI_SOUNDS==n+2 and UI_SOUNDS[n+1].window==window and UI_SOUNDS[n+2].window==window,'cd_stop_poweroff_private_sounds')
 window.transport={trackCount=2,isPlaying=false,isOn=false};n=#UI_SOUNDS;check(play(window)==true,'cd_play_success');check(#UI_SOUNDS==n+2 and UI_SOUNDS[n+2].name=='CDManualPlay','cd_poweron_manual_private_sounds')
 window.success=false;n=#UI_SOUNDS;check(play(window)==false and #UI_SOUNDS==n,'failed_control_no_sound')
elseif MODE=='contextdrag' or MODE=='framedrag' then
 if MODE=='contextdrag' then Module2(NMSlotHostLifecycle) end
 resolveDraggedInventoryItemsSnapshot=function()return {'foreign'},true end
 local item={getFullType=function()return 'Base.Battery' end};ISMouseDrag.dragging={item}
 local fn=MODE=='contextdrag' and NMSlotHostLifecycle.resolveDraggedItemsSnapshot or D2_TEST_LOCAL
 check(type(fn)=='function','exact_source_drag_function')
 local items,ok=fn({});check(ok==true and #items==1 and items[1]==item,'actual_shared_drag_owner_not_foreign')
 ISMouseDrag.dragging={};items,ok=fn({});check(ok and #items==0,'empty_drag')
 ISMouseDrag.dragging=5;items,ok=fn({});check(ok==false and items==nil,'invalid_drag_not_accepted')
elseif MODE=='battery' then
 local owner=NMBatterySlotEnv;owner.resolveBatterySlotFullType=function(_,state)return state.fullType or '' end;owner.isMouseOverButton=function(button)return button.hover==true end;NMSlotHostLifecycle.resolveDraggedItemsSnapshot=function()return DRAG or {},true end;owner.isCompatibleBatteryDrag=function(items)return items[1]=='battery'end
 timed={active=true};local reads=0
 setmetatable(owner,{__index=function(_,key)if key=='timed' then reads=reads+1 end return _G[key]end})
 local window={};local button={hover=false};local resolved={state={fullType=''}}
 check(owner.resolveSlotStyle(window,button,resolved)=='slot','empty_no_progress')
 window._nmBatterySlotTimedProgress={active=true};check(owner.resolveSlotStyle(window,button,resolved)=='slot','empty_active_progress_same_style')
 window._nmBatterySlotTimedProgress={active=false};check(owner.resolveSlotStyle(window,button,resolved)=='slot','empty_inactive_progress_same_style')
 button.hover=true;check(owner.resolveSlotStyle(window,button,resolved)=='slot_hover','empty_hover')
 DRAG={'battery'};check(owner.resolveSlotStyle(window,button,resolved)=='slot_drag','valid_drag')
 DRAG={'cassette'};check(owner.resolveSlotStyle(window,button,resolved)=='slot_hover','invalid_drag')
 resolved.state.fullType='Base.Battery';button.hover=false;check(owner.resolveSlotStyle(window,button,resolved)=='slot_filled','filled_style')
 check(reads==0,'no_unowned_timed_read');check(timed.active==true,'foreign_timed_not_mutated')
elseif MODE=='policy' then
 local policy=Module1;local expected={PAMsfplay=46000,PAMdroidsplay=30000,PAMpinballplay=29000,PAddplay=58000,PAsiplay=38000,PAafplay=50000,PAtzplay=53000,PAijplay=60500,PAdkplay=55000,PAt2play=60000,PAcenplay=60000,PAdigplay=64000,PAnbaplay=62000,PAtmntplay=62000,PAmkplay=60000,PAfhplay=60000,PAbk2000play=70000,PAetpmplay=60000,PAswplay=60000,PAmbplay=60000}
 for name,duration in pairs(expected)do check(policy.getLoopDurationMs(name)==duration,'duration_'..name)end
 check(policy.getLoopDurationMs('unknown')==25000,'unknown_original_25000');check(policy.getLoopDurationMs(nil)==25000,'nil_original_25000')
elseif MODE=='worldsounds' then
 getLoopDurationMs=function()return 999999 end
 for i,entry in ipairs({{'PAMpinballplay',29000},{'PAbk2000play',70000},{'unknown',25000}})do
  local key='key'..i;nativeEmit('OnServerCommand','ProjectArcade','WorldSoundStart',{key=key,sound=entry[1],x=i,y=2,z=0});nativeEmit('OnTick')
  check(#EMISSIONS==1,'world_clip_once_'..i)
  NOW=10000+entry[2]-201;nativeEmit('OnTick');check(#EMISSIONS==1,'duration_not_early_'..i)
  NOW=10000+entry[2]-200;nativeEmit('OnTick');check(#EMISSIONS==2,'duration_exact_'..i)
  nativeEmit('OnServerCommand','ProjectArcade','WorldSoundStop',{key=key});EMISSIONS={};NOW=10000
 end
elseif MODE=='punch' then
 PLAYER={getX=function()return 12 end,getY=function()return 34 end,getZ=function()return 1 end}
 PA_PlayOneShotAtCharacter=function()check(false,'foreign_control_foreign_one_shot')end
 nativeEmit('OnServerCommand','other','PunchingHSResult',{isHighscore=true});check(#EMISSIONS==0,'unrelated_module_silent')
 nativeEmit('OnServerCommand','ProjectArcade','PunchingHSResult',{isHighscore=false});check(#EMISSIONS==0,'not_highscore_silent')
 nativeEmit('OnServerCommand','ProjectArcade','PunchingHSResult',{isHighscore=true,score=400,showKind='male'})
 check(#EMISSIONS==1 and EMISSIONS[1].clip.name=='PAhighscore','mp_exact_highscore_one_shot');check(EMISSIONS[1].pos[1]==12 and EMISSIONS[1].pos[2]==34 and EMISSIONS[1].pos[3]==1,'exact_receiving_character');check(EMISSIONS[1].volume==0.5 and EMISSIONS[1].is3D==true,'source_volume_and_3d')
 PLAYER=nil;nativeEmit('OnServerCommand','ProjectArcade','PunchingHSResult',{isHighscore=true});check(#EMISSIONS==1,'absent_recipient_silent')
elseif MODE=='punchsp' then
 local data={};ModData={getOrCreate=function()return data end}
 PLAYER={getX=function()return 12 end,getY=function()return 34 end,getZ=function()return 1 end,isFemale=function()return false end,getUsername=function()return 'SourcePlayer'end}
 PA_PlayOneShotAtCharacter=function()check(false,'foreign_control_foreign_helper')end
 local fn=nativeLocal(1,'updateGlobalHighScores')
 check(fn(PLAYER,400)==true and #EMISSIONS==1,'sp_exact_highscore_one_shot')
 check(fn(PLAYER,399)==false and #EMISSIONS==1,'sp_lower_score_no_duplicate')
 check(fn(PLAYER,400)==false and #EMISSIONS==1,'sp_equal_score_no_duplicate')
elseif MODE=='nb' then
 MOD_ID='Neat_Building';nativeEmit('OnGameBoot');check(ProjectArcade_NBCompatPatched==nil,'absent_provider_does_not_consume_admission')
 NB_BuildRecipeCode={Floors={}};nativeEmit('OnGameStart');check(ProjectArcade_NBCompatPatched==nil,'partial_provider_does_not_consume_admission')
 local original=function(params)NB_PARAMS=params;return 'nb' end;NB_BuildRecipeCode.Floors.OnCreate=original
 MOD_ID='NeatBuilding';nativeEmit('OnGameBoot');check(NB_BuildRecipeCode.Floors.OnCreate==original,'wrong_id_rejected')
 MOD_ID='Neat_Building';nativeEmit('OnGameStart');local wrapped=NB_BuildRecipeCode.Floors.OnCreate;check(wrapped~=original and ProjectArcade_NBCompatPatched==true,'late_complete_provider_admitted')
 nativeEmit('OnGameBoot');nativeEmit('OnGameStart');check(NB_BuildRecipeCode.Floors.OnCreate==wrapped,'exactly_once_wrapper')
 local params={x=1};check(ProjectArcade.RecipeBridge.Floors.OnCreate(params)=='nb' and NB_PARAMS==params,'actual_id_bridge_target')
 MOD_ID='NeatBuilding';check(ProjectArcade.RecipeBridge.Floors.OnCreate(params)=='native' and NATIVE_BUILD==params,'wrong_id_native_fallback')
 NB_BuildRecipeCode=nil;MOD_ID='Neat_Building';check(ProjectArcade.RecipeBridge.Floors.OnCreate(params)=='native','absent_provider_native_fallback')
elseif MODE=='tetris' then
 nativeEmit('OnGameBoot');check(true,'absent_optional_provider_no_error')
 for _,owner in ipairs({'TetrisItemData','TetrisContainerData','TetrisPocketData'})do _G[owner]={} end
 TetrisItemData.registerItemDefinitions=function()REGISTRATIONS=(REGISTRATIONS or 0)+1 end
 nativeEmit('OnGameBoot');check(REGISTRATIONS==nil,'partial_provider_atomic_no_registration')
 TetrisContainerData.registerContainerDefinitions=function()REGISTRATIONS=(REGISTRATIONS or 0)+1 end
 nativeEmit('OnGameBoot');check(REGISTRATIONS==nil,'two_partial_providers_atomic')
 TetrisPocketData.registerPocketDefinitions=function()REGISTRATIONS=(REGISTRATIONS or 0)+1 end
 nativeEmit('OnGameBoot');check(REGISTRATIONS==3,'controlled_complete_provider_all_three')
elseif MODE=='server' then
 isSinglePlayer=function()check(false,'foreign_control_unowned_server_hook')end
 local fn=nativeLocal(1,'announcePunchingHighScore');SERVER=false;fn('one',200);check(#COMMANDS==0,'sp_server_chain_silent')
 SERVER=true;fn('one',200);check(#COMMANDS==1,'server_broadcast_once')
 isServer=function()return nativeServer(true)end;fn('two',300);check(#COMMANDS==2,'actual_installed_server_predicate')
 isServer=function()return nativeServer(false)end;fn('three',400);check(#COMMANDS==2,'actual_installed_sp_predicate')
elseif MODE=='tiletrue' or MODE=='tilefalse' or MODE=='tilenil' or string.find(MODE,'native%-tile') then
 local expected=string.find(MODE,'native%-tile') and 2 or 1
 check(#OVERLAYS==(string.find(MODE,'tiletrue') and 0 or expected),'exact_native_editor_guard_'..MODE)
elseif MODE=='ambient' then
 local before=nativeCount('OnTickEvenPaused');check(before==1,'single_existing_ambient_event_owner')
 local square={getX=function()return 8 end,getY=function()return 9 end,getZ=function()return 0 end,isOutside=function()return false end,getRoom=function()return{}end,getObjects=function()return list({})end,RecalcProperties=function()end}
 local md={};local obj={getSquare=function()return square end,getSprite=function()return{getName=function()return 'pa_arcades_0'end}end,getModData=function()return md end,getOverlaySprite=function()return nil end,getChildSprites=function()return nil end,hasAttachedAnimSprites=function()return false end,setOverlaySprite=function()end,transmitUpdatedSprite=function()end,transmitModData=function()end}
 IsoSpriteManager={instance={getSprite=function()return nil end}}
 local char={faceLocation=function()end};local action=ProjectArcade_PlayArcadeTimedAction:new(char,obj,3000,1,'Base.SilverCoin',true)
 action.setActionAnim=function()end
 ArcadeAmbientSound={suppressForObject=function()check(false,'foreign_control_foreign_ambient_owner')end}
 D2_AMBIENT_LAST['20,21,0']=12
 ProjectArcade_PlayArcadeTimedAction.start(action);check(nativeCount('OnTickEvenPaused')==before,'action_no_duplicate_ambient_event')
 check(D2_AMBIENT_LAST['8,9,0']==NOW and D2_AMBIENT_LAST['20,21,0']==12,'exact_object_suppression_other_object_preserved')
 local last=nativeLocal(1,'checkNearbyArcades')
 check(type(last)=='function','complete_ambient_module_live_owner')
elseif MODE=='menu' then
 safeGetText=function()check(false,'foreign_control_foreign_locale_fallback')end
 local fn=nativeLocal(1,'doBuildMenu');local square={getObjects=function(self)return list({OBJ})end};OBJ={getSprite=function()return{getName=function()return 'pa_arcades_0'end}end,getSquare=function()return square end}
 local context={addOption=function(self,label,obj,callback)self.label=label;self.obj=obj;return{}end}
 getText=function()return nil end
 PLAYER={}
 fn(0,context,{OBJ},false);check(context.label=='ContextMenu_PlayArcade' and context.obj==OBJ,'nil_locale_exact_key_fallback')
end
PROVEN=true
