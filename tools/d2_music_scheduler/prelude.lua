isClient=function()return false end
isServer=function()return false end
getText=function(value)return value end
Events=setmetatable({},{__index=function()return {Add=function()end,Remove=function()end}end})
SandboxVars={NewMusic={MaxActiveWorldSourcesPerClient=10}}
getTimestampMs=function()return __milliseconds end
getTimestamp=function()return math.floor(__milliseconds/1000)end
getActivatedMods=function()return {contains=function()return true end}end
ZombRand=function()return 0 end
local loaded={}
function require(name)
 if loaded[name]then return loaded[name]end
 for _,root in ipairs({'shared/','client/',''})do
  local key=root..name..'.lua'
  if __sources[key]then loaded[name]=true;local value=assert(loadstring(__sources[key],key))();loaded[name]=value or true;return loaded[name]end
 end
 error('unavailable exact installed module '..name)
end
SAOJavaBridge={sameNativeLuaSourceFunction=function(_,a,b)return __nativeSame(a,b)end,
 nativeLuaSourceFunctionUsesEnvironment=function(_,a,b)return __nativeEnvironment(a,b)end}
function __source(path,environment)
 local fn=assert(loadstring(assert(__sources[path],path),path))
 if environment then setfenv(fn,environment)end
 return fn()
end
for _,path in ipairs({
 'shared/core/NMCore.lua','shared/core/NMRuntimeConfig.lua',
 'shared/contracts/NMDeviceProfileCatalog.lua','shared/contracts/NMDeviceProfiles.lua',
 'shared/contracts/NMDeviceProfilesRuntime.lua','shared/contracts/NMDeviceProfilesPortable.lua',
 'shared/state/NMDeviceState.lua','shared/state/NMTransitionCommon.lua','shared/state/NMTransitionActionHandlers.lua',
 'shared/state/NMDeviceTransitions.lua','shared/contracts/NMMediaContract.lua','shared/music/NMTrackCatalog.lua',
 'shared/playback_progression/NMTrackCountResolver.lua','shared/audio/NMFadeMath.lua','shared/audio/NMOcclusionMath.lua',
 'shared/audio/NMPlaybackAudibility.lua','shared/audio/NMPlaybackRuntimeCommon.lua','shared/audio/NMPlaybackRuntime.lua',
 'shared/slot/NMInventoryHelpers.lua','shared/vehicle/NMVehicleHelpers.lua','shared/registry/NMRegistryPolicy.lua',
 'shared/registry/NMWorldRegistrySnapshot.lua','client/cache/NMClientVehicleAttachmentResolver.lua','client/cache/NMClientVehicleSourceUpdater.lua','client/cache/NMClientWorldSourceCache.lua',
 'shared/audio/NMZombieAttraction.lua','client/runtime/NMClientOwnershipConflictPolicy.lua',
 'client/runtime/NMClientVehicleContinuity.lua','client/runtime/NMClientDetachedOrchestration.lua',
 'client/runtime/NMClientDetachedPlaybackPass.lua','client/runtime/NMClientSPLocalRuntime.lua',
 'client/runtime/NMClientTrackProgressionDispatch.lua','client/runtime/NMClientTrackFinishedDispatch.lua',
 'client/runtime/NMClientPlaybackTick.lua','client/runtime/NMClientMainRuntime.lua'
})do __source(path)end
__auditNames={NMClientDetachedPlaybackPass='client/runtime/NMClientDetachedPlaybackPass.lua',
 NMClientWorldSourceCache='client/cache/NMClientWorldSourceCache.lua',NMPlaybackRuntime='shared/audio/NMPlaybackRuntime.lua',
 NMPlaybackRuntimeCommon='shared/audio/NMPlaybackRuntimeCommon.lua',NMClientSPLocalRuntime='client/runtime/NMClientSPLocalRuntime.lua',
 NMClientTrackFinishedDispatch='client/runtime/NMClientTrackFinishedDispatch.lua',NMClientPlaybackTick='client/runtime/NMClientPlaybackTick.lua',
 NMClientMainRuntime='client/runtime/NMClientMainRuntime.lua'}
function __audited()
 local env=setmetatable({},{__index=_G});env._G=env
 for name in pairs(__auditNames)do env[name]={}end
 local out={}
 for name,path in pairs(__auditNames)do __source(path,env);out[name]=env[name]end
 return out,env
end
local function body(x,y)
 return {getX=function()return x end,getY=function()return y end,getZ=function()return 0 end,
  getSquare=function()return {getX=function()return math.floor(x)end,getY=function()return math.floor(y)end,getZ=function()return 0 end,haveElectricity=function()return true end}end,
  getVehicle=function()return nil end,getInventory=function()return {}end,isOutside=function()return true end,
  getOnlineID=function()return -1 end,getUsername=function()return 'controlled-operator'end,
  getPlayerNum=function()return 0 end,isDead=function()return false end,hasTrait=function()return false end}
end
__operator=body(10000,10000);__npc=body(10,10);__peer=body(10,10)
getPlayer=function()return __operator end
getNumActivePlayers=function()return 1 end
getSpecificPlayer=function()return __operator end
getCore=function()return {getVersionNumber=function()return '42.20'end}end
local store={}
ModData={getOrCreate=function(key)store[key]=store[key]or{};return store[key]end}
function __resetHost()
 __milliseconds=100000;__emitterCount=0;__sounds={};__pulseCount=0;__pulseRows={};__nextSound=0
 __candidates={};__captured={};__vehicle=nil;__vehiclePower=1;__vehicleLoaded=true;SandboxVars.NewMusic.MaxActiveWorldSourcesPerClient=10
 NMPlaybackRuntime.Active={};NMPlaybackRuntime.TrackEnded={};NMPlaybackRuntime.TrackEndPending={}
 NMPlaybackRuntime.TrackEndAwaitingAdvance={};NMPlaybackRuntime.PowerTick={};NMPlaybackRuntime.MissingSinceTick={};NMPlaybackRuntime.MissingSinceMs={}
 NMClientWorldSourceCache.entries={};store={}
end
getWorld=function()return {getFreeEmitter=function()
 __emitterCount=__emitterCount+1
 return {playSound=function(_,sound)__nextSound=__nextSound+1;__sounds[__nextSound]={playing=true,name=sound};return __nextSound end,
  isPlaying=function(_,id)return __sounds[id]and __sounds[id].playing==true end,
  stopSound=function(_,id)if __sounds[id]then __sounds[id].playing=false end end,
  stopAll=function()for _,row in pairs(__sounds)do row.playing=false end end,
  setPos=function()end,setVolume=function(_,id,value)if __sounds[id]then __sounds[id].volume=value end end,
  setSoundPitch=function()end,set3D=function()end,tick=function()end}
 end,returnOwnershipOfEmitter=function()end}end
addSound=function(owner,x,y,z,range,loudness)__pulseCount=__pulseCount+1;__pulseRows[#__pulseRows+1]={owner=owner,x=x,y=y,z=z,range=range,loudness=loudness}end
function __stopHardware()for _,row in pairs(__sounds)do row.playing=false end end
function __entry(uuid,x,y,volume,context)
 context=context or 'placed'
 local state={deviceUUID=uuid,revision=1,playbackEpoch=0,sourceGeneration=1,batteryPresent=true,batteryCharge=1,
  mediaFullType='Controlled.SchedulerTape',volume=volume or 1,isPlaying=true,isOn=true,desiredIsPlaying=true,desiredIsOn=true,playbackMode='world',trackIndex=1,trackCount=2,_headphoneSlotInitialized=true}
 local source={mode='world',context=context,x=x,y=y,z=0,windowsOpen=true}
 local entry={kind='item',profileType='NewMusic.BoomboxBlue',itemFullType='NewMusic.BoomboxBlue',itemId=uuid,stateSnapshot=state,source=source,sourceGeneration=1}
 NMClientWorldSourceCache.entries[uuid]=entry
 local profile=NMDeviceProfiles.getForFullType(entry.profileType)
 return entry,{uuid=uuid,body=__npc,profile=profile,context=context,state=state,source=source}
end
function __options()
 return {valid={},inventoryOwners={},currentInventoryByUuid={},spPulseCandidates={},tickCount=1,
  nowRealMs=function()return __milliseconds end,observeMemoryDuration=function()end,
  consumeAndDispatchTrackFinished=NMClientTrackFinishedDispatch.consumeAndDispatchTrackFinished,
  shouldLogDetachedSync=function()return false end,
  applySPLocalVehiclePowerGuard=function(profile,state,source,uuid)NMClientSPLocalRuntime.applyVehiclePowerGuard(profile,state,source,uuid,{nowMs=function()return __milliseconds end,vehiclePowerTickMs={}})end,
  resolveVehicleCanonicalGeneration=function()return 1 end,persistVehicleCanonicalGeneration=function()end,setVehicleIdentityState=function()end,
  detachedOrchestration=NMClientDetachedOrchestration,continuity=NMClientVehicleContinuity,
  ownershipConflictState={},detachedRemoveLogMs={}}
end
function __capture(uuid)
 local token=NMPlaybackRuntime.TrackEnded[uuid];local await=NMPlaybackRuntime.TrackEndAwaitingAdvance[uuid]
 if token and await then
  local out={};for k,v in pairs(token)do if type(v)~='table'and type(v)~='function'then out[k]=v end end
  __captured[uuid]=out
 end
end
__resetHost()
NMTrackCatalog.registerEntry('Controlled.SchedulerTape','nm_carrier_cassette',{{sound='ControlledSchedulerTrack1',durationSeconds=20},{sound='ControlledSchedulerTrack2',durationSeconds=20}})

getVehicleById=function(id)return __vehicleLoaded and __vehicle and id==__vehicle:getId()and __vehicle or nil end
getCell=function()return {getGridSquare=function()return nil end}end
function __vehicleEntry(uuid)
 local entry,row=__entry(uuid,10.5,10.5,1,'vehicle')
 local state=entry.stateSnapshot
 local part={getId=function()return 'Radio'end,getInventoryItem=function()return {}end,getDeviceData=function()return {}end,getModData=function()return {[NMCore.StateKey]=state}end}
 local vehicle={getId=function()return 12 end,getSqlId=function()return 144 end,getX=function()return 10.5 end,getY=function()return 10.5 end,getZ=function()return 0 end,
  getBatteryCharge=function()return __vehiclePower end,isEngineRunning=function()return false end,windowsOpen=function()return 1 end,
  getPartById=function(_,id)return id=='Radio'and part or nil end}
 part.getVehicle=function()return vehicle end;__vehicle=vehicle
 entry.uuid=uuid;entry.kind='vehicle';entry.profileType='vehicle_radio';entry.partId='Radio';entry.vehicleId='12';entry.vehicleSqlId='144';entry.vehicleIdHint='12';entry.vehicleSqlIdHint='144'
 NMClientWorldSourceCache.entries[uuid]=nil
 NMClientWorldSourceCache.upsertFromPayload({uuid=uuid,kind='vehicle',profileType='vehicle_radio',sourceMode='vehicle',sourceEpoch=1,
  state=state,x=10.5,y=10.5,z=0,vehicleId='12',vehicleIdHint='12',vehicleSqlId='144',vehicleSqlIdHint='144',partId='Radio',windowsOpen=true})
 entry=NMClientWorldSourceCache.get(uuid)
 row.source.partId='Radio'
 row.profile=NMDeviceProfiles.getVehicleProfile(part)
 return entry,row
end
