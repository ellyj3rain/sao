local count=0
local function check(name,value)count=count+1;print('CHECK '..name);assert(value,'D2_MUSIC:'..name)end
local M=SAO.LeisureMusic
local function offer(activity)
    local rows,why=M.offers('person',__body)
    for _,row in ipairs(rows)do if row.activity==activity then return row end end
    error('no offer '..activity..':'..tostring(why))
end
local function begin(activity)
    local o=offer(activity);local ok,w=M.begin('person',__body,o,'purpose:1')
    assert(ok,'begin failed:'..tostring(w));return w
end
local function learned()
    __body:getModData().HarmonicaLearnedTracks={{level=0,sound='Harmonica00FarewellWaltz',length=46,isaddon=0}}
end
__fresh();local ready=false
for _,intent in ipairs(M.intentOffers('person',__body))do
    if intent.activity=='dance' then ready=intent.requiresPreparation.sourceVoice end
end
check('dance_intent_requires_current_heard_source',not ready)
check('source_actor_voice_initialized',M.prepareActor('person',__body)
    and __body:getModData().PlayerVoice==0 and type(__body:getModData().PlayTracker)=='table')
check('source_event_registration_isolated',(__eventRegistrations or 0)==0)
local originalTracker=__body:getModData().PlayTracker
check('source_preparation_idempotent',M.prepareActor('person',__body) and __body:getModData().PlayTracker==originalTracker)
__fresh();local data=__body:getModData()
data.PlayTracker={existing=true,entries={{hoursSince=7}}}
local retainedTracker=data.PlayTracker
check('existing_tracker_missing_voice_repaired',M.prepareActor('person',__body)
    and data.PlayerVoice==0 and data.PlayTracker==retainedTracker
    and data.PlayTracker.entries[1].hoursSince==7)
data.PlayerVoice=3
check('valid_midgame_voice_preserved',M.prepareActor('person',__body)
    and data.PlayerVoice==3 and data.PlayTracker==retainedTracker)
data.PlayerVoice=9
check('invalid_midgame_voice_repaired',M.prepareActor('person',__body)
    and data.PlayerVoice==0 and data.PlayTracker==retainedTracker)
__reload()
check('reloaded_tracker_and_voice_preserved',M.prepareActor('person',__body)
    and data.PlayerVoice==0 and data.PlayTracker==retainedTracker)
data.PlayerVoice=nil;__sourceDrift=true
check('changed_repair_source_refused',not M.prepareActor('person',__body)
    and data.PlayerVoice==nil and data.PlayTracker==retainedTracker)
__sourceDrift=false;__owned=false
check('foreign_custody_cannot_repair_voice',not M.prepareActor('person',__body)
    and data.PlayerVoice==nil and data.PlayTracker==retainedTracker)
__fresh();data=__body:getModData();data.PlayTracker='broken'
check('invalid_tracker_not_overwritten',not M.prepareActor('person',__body)
    and data.PlayTracker=='broken' and data.PlayerVoice==nil)
__fresh();local o=offer('practice-instrument');o.actorId='foreign'
check('spoof_offer_refused',not M.begin('person',__body,o,'purpose:1'))
__fresh();local foreign={};for k,v in pairs(__body)do foreign[k]=v end
check('foreign_body_refused',#M.offers('person',foreign)==0)
__fresh();__active=false;check('owned_source_missing_refused',#M.offers('person',__body)==0)
__fresh();__familiar=false;check('no_private_concept_no_music',#M.offers('person',__body)==0)
__fresh();__primary=nil
check('unequipped_no_execution',#M.offers('person',__body)==0)
check('equipment_intent',M.intentOffers('person',__body)[1].requiresPreparation.equipPrimary)
__fresh();__admit=false;local ok,why=M.begin('person',__body,offer('practice-instrument'),'purpose:1')
check('planner_refusal_prevents_queue',not ok and __queued==nil and __consumed==1)
__fresh();__sourceDrift=true
check('changed_source_refused',not M.begin('person',__body,offer('practice-instrument'),'purpose:1'))
__fresh();local w=begin('practice-instrument');__queued:start()
if not __queued then error('source start failed:'..tostring(M.outcome('person',w.sequence).reason))end
check('global_volume_unchanged',__volume==.61)
check('global_clock_unchanged',__milliseconds==100000 and __hours==10)
__queued:update();check('authentic_practice_sound',#__played>0 and __played[1]=='Harmonica00FarewellWaltz')
if not M.work('person') then error('source update failed:'..tostring(M.outcome('person',w.sequence).reason))end
check('actual_world_sound',__worldSounds>0)
check('native_animation_selected',__animation~=nil)
check('actual_sound_observed',M.work('person').nativeProgress.soundObserved)
__delta=.25;__seconds=61;__queued:update()
check('native_stats_changed',__stats:get(CharacterStat.ENDURANCE)<.8 and __stats:get(CharacterStat.FATIGUE)>.2)
check('source_xp_requests_retained',__skillRequests>0 and __records.person.leisureMusicSkillRequests[1].perkName=='Music')
check('xp_has_canonical_callback',__records.person.leisureMusicSkillRequests[1].nativeProgress.sourceCallback=='update')
__tamperRequest=true;__queued:update();__tamperRequest=false
check('durable_skill_tampering_refused',__tamperResisted)
__delta=1;__queued:perform();local row=M.outcome('person',w.sequence)
check('practice_completed',row and row.status=='completed' and row.cleanupSucceeded)
check('exact_once_outcome',#__records.person.leisureMusicOutcomes==1 and __consumed==1)
row.nativeProgress.delta=99;check('detached_outcome',M.outcome('person',w.sequence).nativeProgress.delta~=99)
check('retired_xp_request_refused',M.skillRequest('person',w.sequence,__records.person.leisureMusicSkillRequests[1].sequence)==nil)
__fresh();learned();w=begin('perform-instrument');__queued:start();__queued:update();__delta=1;__queued:perform()
check('early_timer_no_completion',M.outcome('person',w.sequence).status=='interrupted')
__fresh();learned();w=begin('perform-instrument');__queued:start();__audioFailure=true;__queued:update();__queued:update()
check('failed_audio_no_completion',M.outcome('person',w.sequence).status=='interrupted')
__fresh();w=begin('practice-instrument');__queued:start();__audioFailure=true;__queued:update();__delta=1;__queued:perform()
check('failed_practice_audio_no_completion',M.outcome('person',w.sequence).status=='interrupted')
__fresh();learned();w=begin('perform-instrument');__queued:start();__queued:update()
local handle=__queued.gameSound;__playing[handle]=false;__queued:update()
row=M.outcome('person',w.sequence)
check('source_audio_ending_completed',row and row.status=='completed' and row.nativeProgress.soundObserved)
check('performance_native_stats',row.after.Endurance<row.before.Endurance)
__fresh();w=begin('practice-instrument');__queued:start();__queued:update();__items={};M.advance('person',__body)
row=M.outcome('person',w.sequence);check('lost_custody_interrupts',row and row.status=='interrupted')
__fresh();w=begin('practice-instrument');__queued:start();__queued:update();local saved=__roundtrip(__records.person)
check('durable_no_handles',saved.leisureMusicWork.nativeProgress.soundObserved and type(saved.leisureMusicWork.before)=='table')
__reload();check('reload_interrupts',M.outcome('person',w.sequence).status=='interrupted')
check('reload_no_replay',M.skillRequest('person',w.sequence,1)==nil)
__fresh();w=begin('practice-instrument');__queued:start();__queued:update();__body:getModData().SAOExternalToken='generation:2';M.advance('person',__body)
check('generation_changed_interrupts',M.outcome('person',w.sequence).status=='interrupted')
__fresh();w=begin('practice-instrument');__queued:start();__queued:update();M.interrupt('person',__body,'purpose-changed')
check('partial_never_completed',M.outcome('person',w.sequence).status=='interrupted')
check('partial_progress_retained',M.outcome('person',w.sequence).nativeProgress.soundObserved)
local function pianoOffer(activity)
    for _,candidate in ipairs(M.offers('person',__body))do
        if candidate.instrumentType=='Piano' and candidate.activity==activity then return candidate end
    end
end
__pianoFixture('recreational_01_8','recreational_01_9',1,0)
local po=pianoOffer('practice-instrument')
check('piano_personal_paired_offer',po and po.objectKey=='piano' and po.pairObjectKey=='pair'
    and po.sourceOffset.y==-.3 and po.menuRevision~=nil)
__objects={__objects[1]};check('piano_unobserved_pair_refused',pianoOffer('practice-instrument')==nil)
__pianoFixture('recreational_01_8','recreational_01_9',1,0);__furniture=false
check('piano_native_seat_required',pianoOffer('practice-instrument')==nil)
local intents=M.intentOffers('person',__body)
check('piano_seat_intent',intents[1] and intents[1].requiresPreparation.sitFurniture)
__furniture=true;__facing=false;check('piano_native_facing_required',pianoOffer('practice-instrument')==nil)
__facing=true;po=pianoOffer('practice-instrument');ok,w=M.begin('person',__body,po,'purpose:1');assert(ok,tostring(w))
local action=__queued;action:start()
if not M.work('person') then error('piano source start:'..tostring(M.outcome('person',w.sequence).reason)) end
check('piano_original_source_offset',__x==10.5 and math.abs(__y-11.2)<.00001 and LSUtil.pianoPos==false)
action:start();check('piano_start_exact_once',math.abs(__y-11.2)<.00001)
action:update();check('piano_original_practice_sound',__played[1]=='Piano00Chopstix' and M.work('person').nativeProgress.soundObserved)
__delta=1;action:perform();check('piano_source_practice_completed',M.outcome('person',w.sequence).status=='completed')
po=pianoOffer('practice-instrument');ok,w=M.begin('person',__body,po,'purpose:1');assert(ok,tostring(w));__queued:start()
check('piano_same_seat_no_accumulated_offset',math.abs(__y-11.2)<.00001)
__objectHandles.pair=nil;M.advance('person',__body)
local lostPair=M.outcome('person',w.sequence)
check('piano_pair_custody_loss_interrupts',lostPair and lostPair.status=='interrupted')
__pianoFixture('recreational_01_48','recreational_01_49',0,-1);__level=2
__body:getModData().PianoLearnedTracks={require('Instruments/Tracks/PlayPianoTracks')[10]}
po=pianoOffer('perform-instrument');ok,w=M.begin('person',__body,po,'purpose:1');assert(ok,tostring(w))
__queued:start();__queued:update()
check('piano_original_performance_and_offset',__played[1]==po.sound and math.abs(__x-10.4)<.00001)
__playing[__queued.gameSound]=false;__queued:update()
check('piano_actual_source_ending',M.outcome('person',w.sequence).status=='completed')
check('partial_audio_stopped',not __playing[1])
local instruments={'Banjo','GuitarAcoustic','GuitarElectric','GuitarElectricBass','Flute','Trumpet','Keytar','Saxophone','Violin','Harmonica'}
for _,kind in ipairs(instruments)do
    __fresh(kind);w=begin('practice-instrument');__queued:start()
    if not __queued then error('family '..kind..':'..tostring(M.outcome('person',w.sequence).reason))end
    __queued:update();local work=M.work('person')
    check('installed_instrument_'..kind,work and work.nativeProgress.soundObserved and #__played>0 and __animation~=nil)
    __delta=1;__queued:perform();check('installed_instrument_completion_'..kind,M.outcome('person',w.sequence).status=='completed')
end
__fresh();local voices=require('TimedActions/PlayerVoiceTracks');local voice
for _,v in ipairs(voices)do if v.Type=='Dancing' then voice=v.Voice;break end end
__body:getModData().PlayerVoice=voice
local danceAvailable=false;for _,row in ipairs(M.offers('person',__body))do if row.activity=='dance'then danceAvailable=true end end
check('dance_no_current_music_no_admission',not danceAvailable and __records.person.leisureMusicWork==nil)
__body:getModData().IsListeningToMusicStyle='disco'
danceAvailable=false;for _,row in ipairs(M.offers('person',__body))do if row.activity=='dance'then danceAvailable=true end end
check('stale_dance_style_not_current_hearing',not danceAvailable)
-- Full unchanged Tali dispatch/transition/runtime with controlled physical hosts
-- and media resolver; original profile, state, battery and ending policies run.
local function source(path,env)
    local fn=assert(loadstring(assert(__sources['NewMusic:'..path]),path));setfenv(fn,env or _G);return fn()
end
NMPlaybackRuntimeDiagnostics={ensure=function(rt)__taliRuntime=rt end}
for _,path in ipairs({'shared/core/NMCore.lua','shared/core/NMRuntimeConfig.lua',
    'shared/contracts/NMDeviceProfileCatalog.lua','shared/contracts/NMDeviceProfiles.lua','shared/contracts/NMDeviceProfilesRuntime.lua','shared/contracts/NMDeviceProfilesPortable.lua',
    'shared/state/NMDeviceState.lua','shared/state/NMTransitionCommon.lua','shared/state/NMTransitionActionHandlers.lua','shared/state/NMDeviceTransitions.lua',
    'shared/intent/NMIntentPayloadBuilder.lua','shared/intent/NMIntentInventoryOps.lua',
    'shared/playback_progression/NMTrackCountResolver.lua','shared/audio/NMPlaybackAudibility.lua',
    'shared/audio/NMPlaybackRuntimeCommon.lua','shared/audio/NMPlaybackRuntime.lua','client/intents/NMClientIntentDispatch.lua'})do source(path)end
NMInventoryHelpers={resolveExternalPowerAvailable=function()return false end,
 getItemIdString=function(item)return item and tostring(item:getID()) or '' end,
 getItemUuidString=function(item)local st=item and NMDeviceState.peek(item);return st and tostring(st.deviceUUID) or '' end}
NMClientModeReconcile={resolveModeForItem=function(body,item)assert(body==__body and item==__device);return 'inventory'end}
NMRegistryPolicy={isWorldSyncStateActive=function()return false end}
NMAttachmentHelpers={findWornHeadphones=function()return nil end}
NMClientWorldSourceCache={remove=function(uuid)assert(uuid=='device:person:1')end}
NMWorldRegistrySnapshot={removeSP=function(uuid)assert(uuid=='device:person:1')end}
NMClientPlaybackTick={requestFullPass=function()error('operator scheduler escaped isolation')end}
NMMusic={resolveTracks=function(media)
    assert(media=='Controlled.Tape');return {tracks={{sound='ControlledRecordedTrack',length=20}}}
end}
local function device()
    __fresh();__tali=true
    local md={nm_device_state={deviceUUID='device:person:1',revision=1,playbackEpoch=0,sourceGeneration=1,
        batteryPresent=true,batteryCharge=1,mediaFullType='Controlled.Tape',volume=1,isPlaying=false,isOn=false,
        headphoneItemFullType='NewMusic.Headphones',trackIndex=1,trackCount=1,_headphoneSlotInitialized=true}}
    __device={getID=function()return 20 end,getFullType=function()return 'NewMusic.WalkmanBlue'end,getType=function()return 'WalkmanBlue'end,
        getModData=function()return md end}
    __body.getInventory=function()return {}end;__items={__device};return md.nm_device_state
end
local state=device();o=offer('listen-recorded-music')
check('actual_profile_classifier',o.sourceId=='NewMusic' and o.deviceUUID==state.deviceUUID and o.sourceContext=='stowed')
local ok,w=M.begin('person',__body,o,'purpose:1')
if not ok then error('Tali source begin:'..tostring(w))end
check('intent_not_completion',M.outcome('person',w.sequence)==nil and not M.work('person').nativeProgress.soundObserved)
local accepted,why=M.advance('person',__body)
if not accepted then error('Tali source runtime:'..tostring(M.outcome('person',w.sequence).reason))end
check('tali_source_emitter_observed',M.work('person').nativeProgress.soundObserved and __played[1]=='ControlledRecordedTrack')
check('tali_operator_volume_unchanged',__volume==.61)
__milliseconds=101000;M.advance('person',__body)
check('tali_source_power_drains',state.batteryCharge<1 and state.batteryCharge>0)
__playing[1]=false;M.advance('person',__body)
check('tali_first_false_not_completion',M.outcome('person',w.sequence)==nil)
__milliseconds=101400;M.advance('person',__body)
check('tali_short_false_not_completion',M.outcome('person',w.sequence)==nil)
__milliseconds=102400;M.advance('person',__body);row=M.outcome('person',w.sequence)
check('tali_exact_source_ending',row and row.status=='completed' and row.nativeProgress.trackEnded.uuid=='device:person:1')
check('tali_ending_identity',row.nativeProgress.trackEnded.playbackEpoch==row.playback.playbackEpoch
    and row.nativeProgress.trackEnded.sourceGeneration==row.playback.sourceGeneration)
check('tali_actual_stop_state',not state.isPlaying and row.cleanupSucceeded)
check('tali_exact_once',# __records.person.leisureMusicOutcomes==1 and __consumed==1)
local function empty(t)for _ in pairs(t)do return false end;return true end
check('human_playback_maps_untouched',empty(NMPlaybackRuntime.Active) and empty(NMPlaybackRuntime.TrackEnded))
state=device();w=begin('listen-recorded-music');state.playbackEpoch=state.playbackEpoch+1;M.advance('person',__body)
row=M.outcome('person',w.sequence);check('tali_foreign_epoch_interrupts',row and row.status=='interrupted')
state=device();w=begin('listen-recorded-music');__items={};M.advance('person',__body)
check('tali_custody_loss_interrupts',M.outcome('person',w.sequence).status=='interrupted')
state=device();w=begin('listen-recorded-music');state.batteryCharge=0;M.advance('person',__body)
check('tali_power_loss_interrupts',M.outcome('person',w.sequence).status=='interrupted')
state=device();w=begin('listen-recorded-music');M.advance('person',__body);__reload()
check('tali_reload_interrupts',M.outcome('person',w.sequence).status=='interrupted' and not state.isPlaying)
state=device();o=offer('listen-recorded-music');state.revision=state.revision+1
check('tali_stale_revision_refused',not M.begin('person',__body,o,'purpose:1'))
state=device();w=begin('listen-recorded-music');M.advance('person',__body);state.mediaFullType='Other.Tape';M.advance('person',__body)
check('tali_media_changed_interrupts',M.outcome('person',w.sequence).status=='interrupted')
local function authenticEnding(state)
    local rt=__taliRuntime;local entry=rt.Active[state.deviceUUID]
    __playing[entry.soundId]=false
    local common=NMPlaybackRuntimeCommon
    local profile=NMDeviceProfiles.getForItem(__device)
    common.updateTrackEndState(rt.TrackEndPending,rt.TrackEnded,rt.TrackEndAwaitingAdvance,state.deviceUUID,state,entry,profile,M.work('person').sourceOffer.sourceContext,{})
    __milliseconds=__milliseconds+500
    common.updateTrackEndState(rt.TrackEndPending,rt.TrackEnded,rt.TrackEndAwaitingAdvance,state.deviceUUID,state,entry,profile,M.work('person').sourceOffer.sourceContext,{})
    __milliseconds=__milliseconds+1000
    common.updateTrackEndState(rt.TrackEndPending,rt.TrackEnded,rt.TrackEndAwaitingAdvance,state.deviceUUID,state,entry,profile,M.work('person').sourceOffer.sourceContext,{})
    return rt.TrackEnded[state.deviceUUID]
end
state=device();w=begin('listen-recorded-music');M.advance('person',__body)
local token=authenticEnding(state);token.playbackEpoch=token.playbackEpoch+1
M.advance('person',__body);row=M.outcome('person',w.sequence)
check('tali_foreign_callback_refused',row and row.status=='interrupted')
state=device();w=begin('listen-recorded-music');__audioFailure=true;M.advance('person',__body)
token=authenticEnding(state)
M.advance('person',__body);row=M.outcome('person',w.sequence)
check('tali_no_sound_callback_refused',row and row.status=='interrupted')
state=device();w=begin('listen-recorded-music');M.advance('person',__body)
token=authenticEnding(state);__playing[1]=true
M.advance('person',__body);row=M.outcome('person',w.sequence)
check('tali_premature_same_tuple_refused',row and row.status=='interrupted')
state=device();w=begin('listen-recorded-music');M.advance('person',__body);__admit=false;M.advance('person',__body)
row=M.outcome('person',w.sequence);check('maintained_purpose_required',row and row.status=='interrupted')
state=device();__device.getFullType=function()return 'NewMusic.BoomboxBlue'end;state.headphoneItemFullType=nil;__primary=__device
local worldAdmitted=false;for _,candidate in ipairs(M.offers('person',__body))do if candidate.activity=='listen-recorded-music'then worldAdmitted=true end end
check('tali_world_output_no_personal_admission',not worldAdmitted)
state=device();__primary=__device;o=offer('listen-recorded-music')
check('tali_actual_attached_source_mode',o and o.sourceContext=='attached' and o.modeRevision~=nil)
w=begin('listen-recorded-music');M.advance('person',__body)
check('tali_attached_source_sound',M.work('person').nativeProgress.soundObserved)
__primary=nil;M.advance('person',__body);row=M.outcome('person',w.sequence)
check('tali_actual_location_change_interrupts',row and row.status=='interrupted')
state=device();__primary=__device;w=begin('listen-recorded-music');M.advance('person',__body)
__milliseconds=101000;M.advance('person',__body);__playing[1]=false;M.advance('person',__body)
__milliseconds=101300;M.advance('person',__body)
check('tali_attached_source_pending_policy',M.outcome('person',w.sequence)==nil)
__milliseconds=101400;M.advance('person',__body);__milliseconds=102400;M.advance('person',__body)
row=M.outcome('person',w.sequence)
check('tali_attached_authentic_ending',row and row.status=='completed' and row.sourceOffer.sourceContext=='attached'
 and row.nativeProgress.trackEnded.context=='attached' and row.nativeProgress.trackEnded.policy=='sp_portable_follow')
state=device();w=begin('listen-recorded-music');M.advance('person',__body);token=authenticEnding(state);token.context='foreign-context'
M.advance('person',__body);row=M.outcome('person',w.sequence)
check('tali_foreign_source_context_callback_refused',row and row.status=='interrupted')
print('PASS D2 source music '..count)
