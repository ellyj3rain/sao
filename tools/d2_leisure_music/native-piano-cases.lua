local count=0
local function check(name,value)count=count+1;assert(value,'D2_NATIVE_PIANO:'..name);print('CASE '..name)end
local M,S=SAO.LeisureMusic,SAO.LeisureSkill
__initSourceTraits()
local traitOk,traitValue=pcall(function()return __body:hasTrait(CharacterTrait.VIRTUOSO)end)
check("native_source_registered_traits",traitOk and traitValue==false and CharacterTrait.TONEDEAF~=nil)
Perks=__nativePerks;CharacterTrait=__nativeCharacterTrait;Metabolics=__nativeMetabolics
MoodleType=__nativeMoodleType;IsoDirections=__nativeIsoDirections;instanceof=__nativeinstanceof
__active=true;__owned=true;__familiar=true;__admit=true;__tali=false;__sourceDrift=false
__hours=10;__seconds=61;__milliseconds=100000;__delta=0;__volume=.61;__queued=nil;__consumed=0
__records={person={id='person',bodyOwnerToken='native:music:1'}}
__body:getModData().SAOPersonId='person';__body:getModData().SAOExternalToken='native:music:1'
SAO.Identity.get=function(id)return __records[id]end
SAO.Body={get=function(id)return id=='person' and __body or nil end}
SAO.Needs.ownsRecoveryBody=function(id,body)return id=='person' and body==__body and not body:isDead() and body:getModData().SAOExternalToken=='native:music:1'end
SAO.Needs.workAvailable=function()return __queued==nil end
SAO.ProceduralPlanning.hobbyAdmission=function(id,pid,wid)
    local w=M.work(id);if __admit and w and w.workId==wid and w.purposeId==pid then w.ownerName='SAO.LeisureMusic';return w end
end
local actualCommand=sendClientCommand
sendClientCommand=function()error('native source command escaped actor adapter')end
SAOJavaBridge={privateCarriedItems=function()return {size=function()return 0 end}end}
SAO.Perception={leisureObjects=function()
    return {{key='native:piano',actorId='person',x=10,y=19,z=0,spriteName='recreational_01_8',runtimeInstance='native:piano:1'},
        {key='native:pair',actorId='person',x=11,y=19,z=0,spriteName='recreational_01_9',runtimeInstance='native:pair:1'}}
end,resolveLeisureObject=function(id,body,key)
    if id~='person' or body~=__body then return nil end
    if key=='native:piano' then return __piano end
    if key=='native:pair' and not __lostPair then return __pair end
end}
addSound=function(body)assert(body==__body)end -- Audio hardware and world sound receiver remain controlled.
__body:setSittingOnFurniture(true);__body:setSitOnGround(false)
__body:setPrimaryHandItem(nil);__body:setSecondaryHandItem(nil)
LSMoodleManager.init(__body)
local stats=__body:getStats();stats:set(CharacterStat.BOREDOM,15);stats:set(CharacterStat.STRESS,.2)
stats:set(CharacterStat.UNHAPPINESS,30);stats:set(CharacterStat.ENDURANCE,.8);stats:set(CharacterStat.FATIGUE,.2)
local perk=Perks.Music;__body:setPerkLevelDebug(perk,0)
check('native_body_and_piano',__body:isExistInTheWorld() and __body:isSittingOnFurniture()
    and instanceof(__piano,'IsoObject') and __piano:getSquare():getObjects():contains(__piano)
    and __pair:getSquare():getObjects():contains(__pair) and __body:isFacingObject(__piano,.8))
local function offer(activity)
    for _,row in ipairs(M.offers('person',__body))do if row.instrumentType=='Piano' and row.activity==activity then return row end end
end
local function begin(activity)
    local o=assert(offer(activity),'native piano offer absent')
    local ok,w=M.begin('person',__body,o,'purpose:1');assert(ok,tostring(w));return w,__queued,o
end
local y=__body:getY();local w,action=begin('practice-instrument');action:start()
check('native_source_position_offset',math.abs(__body:getY()-(y-.3))<.0001 and LSUtil.pianoPos==false)
check('native_source_instance_binding',action.obj==__piano and action.objSquare==__piano:getSquare())
action:checkObj();check('original_source_native_pair_validation',action.instrument=='recreational_01_8')
action:update();action:update()
check('native_source_training_sound',M.work('person').nativeProgress.soundObserved and action.lastSound=='Piano00Chopstix')
local seq=__records.person.leisureMusicSkillSequence
local receipt=seq and S.receipt('person','SAO.LeisureMusic',w.sequence,seq)
check('joined_native_music_XP',receipt and receipt.status=='applied' and __body:getXp():getXP(perk)>0)
check('native_source_metabolic_effects',stats:get(CharacterStat.ENDURANCE)<.8 and stats:get(CharacterStat.FATIGUE)>.2)
__delta=1;action:perform()
check('native_piano_training_completed',M.outcome('person',w.sequence).status=='completed')
y=__body:getY();w,action=begin('practice-instrument');action:start()
check('native_position_no_repeat',__body:getY()==y)
__lostPair=true;M.advance('person',__body)
check('native_pair_custody_stops',M.outcome('person',w.sequence).status=='interrupted')
__lostPair=false;__body:setPerkLevelDebug(perk,2)
__body:getModData().PianoLearnedTracks={require('Instruments/Tracks/PlayPianoTracks')[10]}
w,action=begin('perform-instrument');action:start();action:update()
check('native_source_performance_sound',M.work('person').nativeProgress.soundObserved and action.gameSound~=0)
__emitter:finish();action:update()
if M.outcome('person',w.sequence).status~='completed' then error('native source performance failure:'..tostring(M.outcome('person',w.sequence).reason))end
check('native_source_performance_ending',M.outcome('person',w.sequence).status=='completed')
-- Actual native owned NewMusic device and source catalogue; initial inserted
-- media state/optional helper hosts remain controlled and are stated in receipt.
M.reset('native-audio-phase');__queued=nil;__emitter:reset();__body:setSittingOnFurniture(false)
__body:getInventory():AddItem(__device);__body:setPrimaryHandItem(__device)
SAOJavaBridge.privateCarriedItems=function(_,body)assert(body==__body);return body:getInventory():getItems()end
local function source(path)local f=assert(loadstring(assert(__sources['NewMusic:'..path]),path));return f()end
for _,path in ipairs({'shared/core/NMCore.lua','shared/core/NMRuntimeConfig.lua',
 'shared/contracts/NMDeviceProfileCatalog.lua','shared/contracts/NMDeviceProfiles.lua','shared/contracts/NMDeviceProfilesRuntime.lua','shared/contracts/NMDeviceProfilesPortable.lua',
 'shared/state/NMDeviceState.lua','shared/state/NMTransitionCommon.lua','shared/state/NMTransitionActionHandlers.lua','shared/state/NMDeviceTransitions.lua',
 'shared/intent/NMIntentPayloadBuilder.lua','shared/intent/NMIntentInventoryOps.lua','shared/playback_progression/NMTrackCountResolver.lua','shared/audio/NMPlaybackAudibility.lua',
 'shared/music/NMTrackCatalog.lua','shared/contracts/NMMediaContract.lua','shared/music/NMAlbumPackBuilder.lua','shared/music/NMProjectZomboidOST.lua',
 'shared/audio/NMPlaybackRuntimeCommon.lua','shared/audio/NMPlaybackRuntime.lua','client/intents/NMClientIntentDispatch.lua'})do source(path)end
__tali=true;__milliseconds=100000
NMInventoryHelpers={resolveExternalPowerAvailable=function()return false end,
 getItemIdString=function(item)return item and tostring(item:getID())or ''end,
 getItemUuidString=function(item)local st=item and NMDeviceState.peek(item);return st and tostring(st.deviceUUID)or ''end}
NMRegistryPolicy={isWorldSyncStateActive=function()return false end}
NMClientWorldSourceCache={remove=function()end};NMWorldRegistrySnapshot={removeSP=function()end}
local state=NMDeviceState.ensure(__device,NMDeviceProfiles.getForItem(__device))
state.deviceUUID='native:walkman:person';state.revision=1;state.playbackEpoch=0;state.sourceGeneration=1
state.mediaFullType='NewMusic.CassettePZOSTA';state.volume=1;state.isOn=false;state.isPlaying=false
state.batteryPresent=true;state.batteryCharge=1;state.headphoneItemFullType='NewMusic.Headphones';state._headphoneSlotInitialized=true
check('native_owned_source_audio_item',__device:getFullType()=='NewMusic.WalkmanBlue' and __body:getInventory():contains(__device)
 and __body:getPrimaryHandItem()==__device and #NMMusic.resolveTracks(state.mediaFullType).tracks==13)
local function audioOffer()for _,v in ipairs(M.offers('person',__body))do if v.activity=='listen-recorded-music'then return v end end end
local selected=assert(audioOffer(),'native source audio offer absent')
check('native_attached_source_truth',selected.sourceContext=='attached')
local admitted,work=M.begin('person',__body,selected,'purpose:1');assert(admitted,tostring(work))
local advanced,why=M.advance('person',__body);if not advanced then error(M.outcome('person',work.sequence).reason)end
check('native_original_catalogue_sound',M.work('person').nativeProgress.soundObserved
 and M.work('person').nativeProgress.sound=='NMZomboidTheme2' and __emitter:getPlayed()>0)
__milliseconds=101000;M.advance('person',__body)
check('native_actual_source_audio_battery_drain',state.batteryCharge<1 and state.batteryCharge>0)
__emitter:finish();M.advance('person',__body);__milliseconds=101300;M.advance('person',__body)
check('native_source_attached_ending_pending',M.outcome('person',work.sequence)==nil)
__milliseconds=101400;M.advance('person',__body)
local audioOutcome=M.outcome('person',work.sequence)
check('native_source_attached_ending',audioOutcome and audioOutcome.status=='completed'
 and audioOutcome.nativeProgress.trackEnded.policy=='sp_portable_follow' and not state.isPlaying)
state.isPlaying=false;selected=assert(audioOffer());admitted,work=M.begin('person',__body,selected,'purpose:1');assert(admitted)
M.advance('person',__body);__body:setPrimaryHandItem(nil);M.advance('person',__body)
local lostAttachment=M.outcome('person',work.sequence)
check('native_audio_attachment_loss_interrupts',lostAttachment and lostAttachment.status=='interrupted')
__body:setPrimaryHandItem(__device);state.isPlaying=false;selected=assert(audioOffer());admitted,work=M.begin('person',__body,selected,'purpose:1');assert(admitted)
M.advance('person',__body);check('native_audio_before_death_live',not __emitter:isClear())
__body:setHealth(0);M.advance('person',__body)
local deadAudio=M.outcome('person',work.sequence)
check('native_audio_death_owned_cleanup',__body:isDead() and deadAudio and deadAudio.status=='interrupted' and __emitter:isClear())
print('PASS native source piano '..count)
