local M=SAO.LeisureMusic
local count=0
local function check(name,value)count=count+1;assert(value,'D2_WORLD_AUDIO:'..name);print('CASE '..name)end
local function source(path)local fn=assert(loadstring(assert(__sources['NewMusic:'..path]),path));return fn()end
for _,path in ipairs({'shared/core/NMCore.lua','shared/core/NMRuntimeConfig.lua','shared/contracts/NMDeviceProfileCatalog.lua',
 'shared/contracts/NMDeviceProfiles.lua','shared/contracts/NMDeviceProfilesRuntime.lua','shared/contracts/NMDeviceProfilesPortable.lua',
 'shared/state/NMDeviceState.lua','shared/state/NMTransitionCommon.lua','shared/state/NMTransitionActionHandlers.lua','shared/state/NMDeviceTransitions.lua',
 'shared/intent/NMIntentPayloadBuilder.lua','shared/intent/NMIntentInventoryOps.lua','shared/playback_progression/NMTrackCountResolver.lua',
 'shared/audio/NMFadeMath.lua','shared/audio/NMOcclusionMath.lua','shared/audio/NMPlaybackAudibility.lua',
 'shared/audio/NMPlaybackRuntimeCommon.lua','shared/audio/NMPlaybackRuntime.lua','shared/slot/NMInventoryHelpers.lua',
 'shared/vehicle/NMVehicleHelpers.lua','shared/registry/NMRegistryPolicy.lua','shared/registry/NMWorldRegistrySnapshot.lua',
 'client/cache/NMClientVehicleAttachmentResolver.lua','client/cache/NMClientVehicleSourceUpdater.lua','client/cache/NMClientWorldSourceCache.lua','shared/state/NMAuthorityStateCommon.lua','shared/state/NMAuthorityState.lua','shared/intent/NMIntentAuthority.lua',
 'shared/audio/NMZombieAttraction.lua','client/runtime/NMClientOwnershipConflictPolicy.lua','client/runtime/NMClientVehicleContinuity.lua','client/runtime/NMClientDetachedOrchestration.lua','client/runtime/NMClientDetachedPlaybackPass.lua','client/runtime/NMClientSPLocalRuntime.lua','client/runtime/NMClientTrackProgressionDispatch.lua','client/runtime/NMClientTrackFinishedDispatch.lua','client/runtime/NMClientPlaybackTick.lua','client/runtime/NMClientMainRuntime.lua'})do source(path)end
local store={};ModData={getOrCreate=function(key)store[key]=store[key]or{};return store[key]end}
NMMusic={resolveTracks=function()return {tracks={{sound='ControlledPublicTrack',length=20}}}end}
local function fixture(kind,playing)
 M.reset('world-audio-fixture');__fresh();__tali=true;__items={};__primary=nil
 NMPlaybackRuntime.Active={};NMPlaybackRuntime.TrackEnded={};NMPlaybackRuntime.TrackEndAwaitingAdvance={};NMPlaybackRuntime.TrackEndPending={}
 NMClientWorldSourceCache.entries={};store={};__visible=true;__hearing=true;__power=true;__inside=kind=='vehicle';__emitterCount=0
 local sq={getX=function()return 10 end,getY=function()return 10 end,getZ=function()return 0 end,haveElectricity=function()return __power end}
 local md={nm_device_state={deviceUUID='public:1',revision=1,playbackEpoch=0,sourceGeneration=1,batteryPresent=true,batteryCharge=1,
  mediaFullType='Controlled.PublicTape',volume=1,isPlaying=playing==true,isOn=playing==true,trackIndex=1,trackCount=1,_headphoneSlotInitialized=true}}
 local device={getID=function()return 55 end,getFullType=function()return kind=='vinyl'and'NewMusic.VinylplayerOak'or'NewMusic.BoomboxBlue'end,
  getModData=function()return md end,getType=function()return 'BoomboxBlue'end}
 local object={getSquare=function()return sq end,getItem=function()return device end}
 device.getWorldItem=function()return object end
 local vehicle={getId=function()return 12 end,getSqlId=function()return 144 end,getX=function()return 10.5 end,getY=function()return 10.5 end,
  getZ=function()return 0 end,getBatteryCharge=function()return __power and .8 or 0 end,windowsOpen=function()return 1 end,getSeat=function()return 0 end}
 local part={getId=function()return 'Radio'end,getVehicle=function()return vehicle end,getInventoryItem=function()return device end,
  getDeviceData=function()return {}end,getModData=function()return md end}
 vehicle.getPartById=function(_,id)return id=='Radio'and part or nil end
 __body.getVehicle=function()return __inside and vehicle or nil end;__body.getSquare=function()return sq end
 __body.getInventory=function()return {}end
 __row={key=kind=='vehicle'and'vehicle-radio:12:144:vehicle1:part1'or'world-item:10:10:0:0',actorId='person',sourceKind=kind=='vehicle'and'vehicle'or'placed',
  x=10,y=10,z=0,objectCollection=kind=='vehicle'and'vehicle'or'worldObjects',runtimeInstance=kind=='vehicle'and'part1'or'object1',itemKey='55',itemType=device:getFullType(),
  vehicleId=kind=='vehicle'and 12 or nil,vehicleSqlId=kind=='vehicle'and 144 or nil,partId=kind=='vehicle'and'Radio'or nil,
  vehicleRuntimeInstance=kind=='vehicle'and'vehicle1'or nil,partRuntimeInstance=kind=='vehicle'and'part1'or nil}
 __target=kind=='vehicle'and{vehicle=vehicle,part=part}or{object=object,item=device}
 SAO.Perception.leisureAudioSources=function(id)if __visible then local row={};for k,v in pairs(__row)do row[k]=v end;row.actorId=id;return{row}end;return{}end
 SAO.Perception.resolveLeisureAudioSource=function(id,body,key)return __visible and id=='person'and body==__body and key==__row.key and __target or nil end
 SAO.Perception.canHearLeisureSource=function(id,body,row,range)return __hearing and __visible and row.actorId==id and body==__body and range>0 end
 local playingSounds={};local nextSound=0
 __publicEmitter={playSound=function(_,sound)nextSound=nextSound+1;playingSounds[nextSound]=true;return nextSound end,
  isPlaying=function(_,id)return playingSounds[id]==true end,stopSound=function(_,id)playingSounds[id]=false end,stopAll=function()playingSounds={}end,
  setPos=function()end,setVolume=function()end,setSoundPitch=function()end,set3D=function()end,tick=function()end}
 __stopSound=function()for id in pairs(playingSounds)do playingSounds[id]=false end end
 getWorld=function()return {getFreeEmitter=function()__emitterCount=__emitterCount+1;return __publicEmitter end,returnOwnershipOfEmitter=function()end}end
 local profile=kind=='vehicle'and NMDeviceProfiles.getVehicleProfile(part)or NMDeviceProfiles.getForItem(device)
 __source={mode='world',context=kind=='vehicle'and'vehicle'or'placed',x=10.5,y=10.5,z=0,windowsOpen=true,
  vehicle=kind=='vehicle'and vehicle or nil,vehicleId=kind=='vehicle'and'12'or nil,vehicleSqlId=kind=='vehicle'and'144'or nil}
 __rendererBody={};for k,v in pairs(__body)do __rendererBody[k]=v end;__rendererBody.getVehicle=function()return nil end
 __sourceTick=function()NMPlaybackRuntime.syncDevice(__rendererBody,profile,md.nm_device_state,__source,1)end
 return md.nm_device_state,profile
end
local function offer()local offers,why=M.offers('person',__body);if why then error('offer source failed:'..tostring(why))end;for _,o in ipairs(offers)do if o.audioSourceKey then return o end end end
local function begin()local o=assert(offer(),'public offer absent');local ok,w=M.begin('person',__body,o,'purpose:1');assert(ok,'source admission failed:'..tostring(w));return w end
local state=fixture('placed',false)
check('placed_source_profile',offer().sourceContext=='placed'and offer().deviceUUID=='public:1')
local w=begin();check('source_intent_updates_shared_registry',state.isPlaying and NMClientWorldSourceCache.get('public:1')and NMWorldRegistrySnapshot.loadSP()['public:1'])
check('intent_does_not_create_audio',__emitterCount==0 and not M.work('person').nativeProgress.soundObserved)
M.advance('person',__body);check('listener_does_not_drive_renderer',__emitterCount==0 and M.work('person').phase=='awaiting-source-world-hearing')
__sourceTick();check('original_public_renderer_one_emitter',__emitterCount==1 and NMPlaybackRuntime.Active['public:1'].isWorldEmitter)
__hearing=false;M.advance('person',__body);check('native_hearing_required',not M.work('person').nativeProgress.soundObserved)
__hearing=true;M.advance('person',__body);check('source_sound_and_native_receiver',M.work('person').nativeProgress.soundObserved and M.work('person').nativeProgress.sourceAudibility.range>0)
__stopSound();__milliseconds=101000;__sourceTick();M.advance('person',__body)
check('first_false_is_not_completion',M.outcome('person',w.sequence)==nil)
NMPlaybackRuntime.TrackEndAwaitingAdvance['public:1']={playbackEpoch=state.playbackEpoch,trackIndex=state.trackIndex,
 sourceGeneration=state.sourceGeneration,context='placed',falseCount=1,falseChecks=3,pendingElapsedMs=0,windowMs=900,setAtMs=__milliseconds}
M.advance('person',__body);check('premature_public_confirmation_refused',M.outcome('person',w.sequence)==nil)
NMPlaybackRuntime.TrackEndAwaitingAdvance['public:1']=nil
__milliseconds=102000;__sourceTick();__milliseconds=103000;__sourceTick();local token=NMPlaybackRuntime.TrackEnded['public:1'];local await=NMPlaybackRuntime.TrackEndAwaitingAdvance['public:1']
check('original_debounce_confirmation',token and await and token.falseCount>=token.falseChecks)
M.advance('person',__body);check('completion_keeps_source_token',M.outcome('person',w.sequence).status=='completed'and NMPlaybackRuntime.TrackEnded['public:1']==token and NMPlaybackRuntime.TrackEndAwaitingAdvance['public:1']==await)
state=fixture('placed',false);w=begin();__sourceTick();M.advance('person',__body);M.interrupt('person',__body,'listener-leaves')
check('listener_interrupt_preserves_public_playback',state.isPlaying and NMPlaybackRuntime.Active['public:1']and __publicEmitter:isPlaying(NMPlaybackRuntime.Active['public:1'].soundId))
state=fixture('placed',true);w=begin();__sourceTick();M.advance('person',__body);__visible=false;M.advance('person',__body)
check('lost_visibility_interrupts',M.outcome('person',w.sequence)and M.outcome('person',w.sequence).status=='interrupted'and state.isPlaying)
state=fixture('placed',false);w=begin();__sourceTick();M.advance('person',__body);state.revision=state.revision+1;M.advance('person',__body)
check('foreign_playback_interrupts',M.outcome('person',w.sequence)and M.outcome('person',w.sequence).status=='interrupted')
state=fixture('vinyl',false);__power=false;check('external_power_required',offer()==nil);__power=true;w=begin();__sourceTick();M.advance('person',__body);__power=false;M.advance('person',__body)
check('live_power_loss_interrupts',M.outcome('person',w.sequence)and M.outcome('person',w.sequence).status=='interrupted')
state=fixture('vehicle',false);__inside=false;check('unoccupied_radio_control_refused',offer()==nil);__inside=true
check('occupied_vehicle_source_offer',offer()and offer().vehicleSqlId=='144');w=begin()
check('vehicle_original_intent_and_registry',state.isPlaying and NMClientWorldSourceCache.get('public:1').partId=='Radio')
__sourceTick();M.advance('person',__body)
check('native_occupant_uses_existing_world_emitter',M.work('person').nativeProgress.soundObserved and __emitterCount==1)
state=fixture('placed',false);w=begin();__sourceTick();local entry=NMPlaybackRuntime.Active['public:1'];entry.isWorldEmitter=false;M.advance('person',__body)
check('personal_channel_not_public_sound',not M.work('person').nativeProgress.soundObserved)
check('operator_volume_clock_unchanged',__volume==.61 and __milliseconds==100000)
state=fixture('placed',false);local original=offer();local spoof={};for k,v in pairs(original)do spoof[k]=v end;spoof.deviceUUID='foreign-public-device'
check('foreign_uuid_offer_refused',not M.begin('person',__body,spoof,'purpose:1'))
w=begin();check('duplicate_listener_admission_refused',not M.begin('person',__body,original,'purpose:1'))
check('foreign_body_cannot_advance',not M.advance('person',{},'foreign')and M.work('person')~=nil)
__sourceTick();M.advance('person',__body)
__stopSound();__milliseconds=101000;__sourceTick();__milliseconds=102000;__sourceTick();__milliseconds=103000;__sourceTick()
local actualAwait=NMPlaybackRuntime.TrackEndAwaitingAdvance['public:1'];local consumed=NMPlaybackRuntime.consumeTrackEndedToken('public:1')
M.advance('person',__body)
check('consumed_token_confirmation_still_observable',consumed and actualAwait and M.outcome('person',w.sequence).status=='completed'and NMPlaybackRuntime.TrackEndAwaitingAdvance['public:1']==actualAwait)
state=fixture('placed',false);w=begin();__sourceTick();M.advance('person',__body)
__stopSound();__milliseconds=101000;__sourceTick();__milliseconds=102000;__sourceTick();__milliseconds=103000;__sourceTick()
NMPlaybackRuntime.invalidateTrackEnded('public:1');state.playbackEpoch=state.playbackEpoch+1;state.trackIndex=2;M.advance('person',__body)
check('missed_confirmation_does_not_fabricate_completion',M.outcome('person',w.sequence).status=='interrupted')
state=fixture('placed',false);w=begin();__sourceTick();M.advance('person',__body)
__reload();M.advance('person',__body)
check('reload_interrupts_without_public_stop',M.outcome('person',w.sequence).status=='interrupted'and state.isPlaying and __emitterCount==1)
state=fixture('placed',false);w=begin();__sourceTick();M.advance('person',__body)
local peer={};for k,v in pairs(__body)do peer[k]=v end
peer.getModData=function()return {SAOPersonId='peer',SAOExternalToken='peer-generation:1'}end
peer.getStats=function()return __stats2 end;__records.peer={id='peer'}
local bodies={person=__body,peer=peer};SAO.Needs.ownsRecoveryBody=function(id,body)return bodies[id]==body and __owned end
SAO.Perception.resolveLeisureAudioSource=function(id,body,key)return __visible and bodies[id]==body and key==__row.key and __target or nil end
SAO.Perception.canHearLeisureSource=function(id,body,row,range)return __hearing and __visible and row.actorId==id and bodies[id]==body and range>0 end
local peerOffer;for _,row in ipairs(M.offers('peer',peer))do if row.audioSourceKey then peerOffer=row;break end end
local revision=state.revision;local ok,peerWork=M.begin('peer',peer,peerOffer,'purpose:1')
check('second_listener_does_not_replay_public_intent',ok and peerOffer.alreadyPlaying and state.revision==revision and __emitterCount==1)
M.advance('peer',peer);check('two_listeners_one_physical_emitter',M.work('peer').nativeProgress.soundObserved and M.work('person').nativeProgress.soundObserved and __emitterCount==1)
M.interrupt('person',__body,'person-leaves');check('other_listener_remains_independent',M.work('peer')and state.isPlaying and NMPlaybackRuntime.Active['public:1'].emitter==__publicEmitter)
__stopSound();__milliseconds=101000;__sourceTick();__milliseconds=102000;__sourceTick();__milliseconds=103000;__sourceTick()
M.advance('peer',peer);check('own_public_listening_outcome',M.outcome('person',w.sequence).status=='interrupted'and M.outcome('peer',peerWork.sequence).status=='completed')
M.reset('world-audio-terminal');print('PASS D2 world audio '..count)

__worldFixture=fixture;__worldOffer=offer;__worldBegin=begin
