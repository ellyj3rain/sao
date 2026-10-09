local W=SAO.LeisureMusicWorld
local count=0
local function check(name,value)assert(value,'D2_SCHEDULER:'..name);count=count+1;print('CASE '..name)end
local function copy(row)local out={}for k,v in pairs(row)do out[k]=v end return out end
local function candidate(entry,row)row.state=copy(entry.stateSnapshot);row.source=copy(entry.source);if row.context=='vehicle'then row.source.partId=__vehicle:getPartById('Radio'):getId() end;return row end
local function install()
 local audited=__audited()
 local ok=W.install(audited,function()return __candidates end,__capture)
 check('original_eight_module_install',ok and W.current())
end
local scalarCode='local value=...;return function(x)return x*value end'
local a=assert(loadstring(scalarCode)) (2);local b=assert(loadstring(scalarCode)) (3)
check('native_scalar_capture_guard',not __nativeSame(a,b))
local same=assert(loadstring(scalarCode)) (2)
check('native_same_prototype_and_capture',__nativeSame(a,same))
local callableCode='local callback=...;return function(x)return callback(x) end'
local c=assert(loadstring(callableCode)) (math.abs);local d=assert(loadstring(callableCode)) (math.floor)
check('native_java_callable_capture_guard',not __nativeSame(c,d))
local foreignEnv=setmetatable({},{__index=_G});foreignEnv._G=foreignEnv
local foreign=assert(loadstring('return function()return isClient()end'));setfenv(foreign,foreignEnv);foreign=foreign()
check('native_foreign_environment_guard',not __nativeEnvironment(foreign,_G))
local audited=__audited();local empty={}for name in pairs(audited)do empty[name]={}end
check('missing_audit_functions_refused',not W.install(empty,function()return __candidates end,__capture))
local savedTable=NMClientDetachedPlaybackPass;local savedRun=savedTable.run
NMClientDetachedPlaybackPass.run=function()return {}end
check('replaced_original_before_install_refused',not W.install(audited,function()return __candidates end,__capture))
NMClientDetachedPlaybackPass.run=savedRun
local privateMap,privateEnv=__audited()
NMClientDetachedPlaybackPass=privateMap.NMClientDetachedPlaybackPass
check('foreign_source_environment_refused',not W.install(privateMap,function()return __candidates end,__capture))
NMClientDetachedPlaybackPass=savedTable
-- Keep the original complete table, including unchanged installed helper bindings.

install()
local entry,row=__entry('shared:1',10.5,10.5,1)
row=candidate(entry,row);local peer=copy(row);peer.body=__peer;__candidates={row,peer}
local originalOut={};NMClientWorldSourceCache.collectInRange(__operator,originalOut)
check('unscoped_original_collect_retained',#originalOut==0)
local options=__options();local callback=options.consumeAndDispatchTrackFinished
local result=NMClientDetachedPlaybackPass.run(__operator,options)
check('selected_outside_operator_range_kept',#result.detached==1 and result.detachedSyncCount==1 and options.valid['shared:1'])
check('selected_native_shallow_clone_parity',result.detached[1].entry~=entry and result.detached[1].entry.stateSnapshot==entry.stateSnapshot and result.detached[1].entry.source==entry.source)
check('two_persons_single_uuid_emitter',__emitterCount==1 and NMPlaybackRuntime.Active['shared:1']~=nil)
check('callback_restored_after_pass',options.consumeAndDispatchTrackFinished==callback)
local active=NMPlaybackRuntime.Active['shared:1'];local id=active.soundId or active.soundID or active.soundId or active.sound
check('outside_hearing_transport_runs',active and active.isWorldEmitter and __sounds[active.soundId]and __sounds[active.soundId].playing)
NMPlaybackRuntime.stopMissing(__operator,options.valid,60)
check('original_valid_mark_preserves_channel',NMPlaybackRuntime.Active['shared:1']==active)
local pulseState={nowMs=function()return __milliseconds end,zombieAttractionPulseState={}}
NMClientSPLocalRuntime.emitZombiePulses(__operator,options.spPulseCandidates,pulseState)
check('npc_near_pulse_original_shared_uuid_once',__pulseCount==1 and pulseState.zombieAttractionPulseState['shared:1'])
NMClientSPLocalRuntime.emitZombiePulses(__operator,options.spPulseCandidates,pulseState)
check('repeat_pulse_respects_original_cadence',__pulseCount==1)
-- Shared rendering is independent of the operator's audible channel volume.
W.reset();__resetHost();install()
entry,row=__entry('silent:1',10.5,10.5,0);row=candidate(entry,row);__candidates={row}
options=__options();NMClientDetachedPlaybackPass.run(__operator,options)
active=NMPlaybackRuntime.Active['silent:1']
check('zero_volume_original_transport_runs',active and __sounds[active.soundId].playing and __sounds[active.soundId].volume==0)
__stopHardware();__milliseconds=101000;NMClientDetachedPlaybackPass.run(__operator,options)
check('first_false_no_terminal',__captured['silent:1']==nil and entry.stateSnapshot.trackIndex==1)
__milliseconds=102000;NMClientDetachedPlaybackPass.run(__operator,options)
__milliseconds=103000;NMClientDetachedPlaybackPass.run(__operator,options)
local ending=__captured['silent:1']
check('copied_ending_before_original_advances',ending and ending.playbackEpoch==0 and ending.trackIndex==1 and entry.stateSnapshot.playbackEpoch==1 and entry.stateSnapshot.trackIndex==2)
check('original_debounced_terminal_evidence',ending and ending.falseCount>=ending.falseChecks and ending.pendingElapsedMs>=ending.windowMs)
check('original_consumed_terminal_detached_copy',ending and NMPlaybackRuntime.TrackEnded['silent:1']==nil)
check('original_progression_preserves_registry',NMClientWorldSourceCache.get('silent:1')and NMWorldRegistrySnapshot.loadSP()['silent:1'])
-- Existing operator entries consume their native slots before acquired NPC entries.
W.reset();__resetHost();install();SandboxVars.NewMusic.ActiveDeviceLimit=4
for i=1,4 do __entry('operator:'..i,10000+i,10000,1)end
entry,row=__entry('npc-over-cap',10.5,10.5,1);row=candidate(entry,row);__candidates={row}
options=__options();result=NMClientDetachedPlaybackPass.run(__operator,options)
check('native_cap_preserves_operator_entries',#result.detached==4 and not options.valid['npc-over-cap']and __emitterCount==4)
for _,d in ipairs(result.detached)do check('operator_entry_precedes_npc',d.uuid:find('operator:',1,true)==1)
local native=NMClientWorldSourceCache.get(d.uuid);check('original_native_shallow_clone_parity',d.entry~=native and d.entry.stateSnapshot==native.stateSnapshot and d.entry.source==native.source)end
SandboxVars.NewMusic.ActiveDeviceLimit=nil
-- The source's original inventory conflict prunes the selected detached entry.
W.reset();__resetHost();install();entry,row=__entry('conflict:1',10.5,10.5,1);row=candidate(entry,row);__candidates={row}
options=__options();options.inventoryOwners['conflict:1']=true;result=NMClientDetachedPlaybackPass.run(__operator,options)
check('original_inventory_conflict_prunes',result.detachedSyncCount==0 and NMClientWorldSourceCache.get('conflict:1')==nil and __emitterCount==0)
-- Wrong current tuple, native position or source context cannot extend the cache pass.
W.reset();__resetHost();install();entry,row=__entry('tuple:1',10.5,10.5,1);row=candidate(entry,row);__candidates={row}
entry.stateSnapshot.revision=2;options=__options();result=NMClientDetachedPlaybackPass.run(__operator,options)
check('stale_revision_refused',#result.detached==0 and __emitterCount==0)
row.state.revision=2;entry.stateSnapshot.playbackEpoch=1;result=NMClientDetachedPlaybackPass.run(__operator,__options())
check('foreign_playback_epoch_refused',#result.detached==0)
row.state.playbackEpoch=1;row.source.x=20;result=NMClientDetachedPlaybackPass.run(__operator,__options())
check('current_source_coordinate_required',#result.detached==0)
row.source.x=10.5;row.context='vehicle';result=NMClientDetachedPlaybackPass.run(__operator,__options())
check('foreign_source_context_refused',#result.detached==0)
row.context='placed';NMClientWorldSourceCache.entries['tuple:1']=nil;result=NMClientDetachedPlaybackPass.run(__operator,__options())
check('missing_canonical_cache_entry_refused',#result.detached==0)
-- Failures restore original callback and leave no borrowed player scope.
W.reset();__resetHost();install();entry,row=__entry('exception:1',10.5,10.5,1);row=candidate(entry,row);__candidates={row}
options=__options();local fault=function()error('controlled-original-callback-refusal')end;options.consumeAndDispatchTrackFinished=fault
local ok,why=pcall(NMClientDetachedPlaybackPass.run,__operator,options)
check('original_callback_failure_propagates',not ok and tostring(why):find('controlled-original-callback-refusal',1,true))
check('callback_restored_after_exception',options.consumeAndDispatchTrackFinished==fault)
local outside={};NMClientWorldSourceCache.collectInRange(__operator,outside)
check('collection_scope_released_after_exception',#outside==0)
local oldDependency=NMRuntimeConfig.getMaxActiveWorldSourcesPerClient
NMRuntimeConfig.getMaxActiveWorldSourcesPerClient=function()return 50 end
check('changed_dependency_invalidates_seal',not W.current())
result=NMClientDetachedPlaybackPass.run(__operator,__options())
check('tampered_dependency_no_npc_extension',#result.detached==0)
NMRuntimeConfig.getMaxActiveWorldSourcesPerClient=oldDependency;check('restored_exact_dependency_revalidates',W.current())
local oldSync=NMPlaybackRuntime.syncDevice;NMPlaybackRuntime.syncDevice=function()end
check('replaced_audited_function_invalidates',not W.current());NMPlaybackRuntime.syncDevice=oldSync
local oldTable=NMPlaybackRuntime;NMPlaybackRuntime={};check('replaced_audited_table_invalidates',not W.current());NMPlaybackRuntime=oldTable
-- reset retires only the wrappers that remain owned.
local runWrapper=NMClientDetachedPlaybackPass.run;W.reset()
check('reset_restores_original_native_function',NMClientDetachedPlaybackPass.run==savedRun and not W.current())
local emptyOut={};NMClientWorldSourceCache.collectInRange(__operator,emptyOut)
check('retired_wrapper_no_extension',#emptyOut==0)
W.reset();__resetHost();install();entry,row=__entry('missing:1',10.5,10.5,1);row=candidate(entry,row);__candidates={row}
options=__options();NMClientDetachedPlaybackPass.run(__operator,options);active=NMPlaybackRuntime.Active['missing:1']
__candidates={};options=__options();result=NMClientDetachedPlaybackPass.run(__operator,options)
check('lost_selection_not_valid_marked',#result.detached==0 and not options.valid['missing:1'])
NMPlaybackRuntime.stopMissing(__operator,options.valid,60)
check('original_missing_grace_retains_first',NMPlaybackRuntime.Active['missing:1']==active)
__milliseconds=110000;NMPlaybackRuntime.stopMissing(__operator,options.valid,600)
check('original_missing_timeout_stops_source',NMPlaybackRuntime.Active['missing:1']==nil and not __sounds[active.soundId].playing)
W.reset();__resetHost();install();entry,row=__vehicleEntry('vehicle:1');row=candidate(entry,row);__candidates={row}
check('original_cache_vehicle_no_source_part_metadata',entry.source.partId==nil and entry.partId=='Radio')
options=__options();result=NMClientDetachedPlaybackPass.run(__operator,options)
check('original_vehicle_native_cache_refresh',entry.source._vehicleResolved==true and entry.source.vehicle==nil and getVehicleById(entry.attachedRuntimeId)==__vehicle and entry.attachedRuntimeId==12)
check('original_vehicle_continuity_resolved',result.detachedSyncCount==1 and not entry._vehicleWasUnresolved and options.valid['vehicle:1'])
check('vehicle_original_runtime_transports',NMPlaybackRuntime.Active['vehicle:1']~=nil and __emitterCount>=1)
local vehiclePulse={nowMs=function()return __milliseconds end,zombieAttractionPulseState={}}
NMClientSPLocalRuntime.emitZombiePulses(__operator,options.spPulseCandidates,vehiclePulse)
check('original_cache_vehicle_npc_pulse',__pulseCount==1 and vehiclePulse.zombieAttractionPulseState['vehicle:1'])
-- Drop the controlled loaded-vehicle host, retain the actual source's last-good continuity.
__vehicleLoaded=false;options=__options();result=NMClientDetachedPlaybackPass.run(__operator,options)
check('original_vehicle_unresolved_continuity',entry.source._vehicleResolved==false and entry._vehicleWasUnresolved==true and entry._vehicleUnresolvedSinceMs==__milliseconds)
__vehicleLoaded=true;options=__options();result=NMClientDetachedPlaybackPass.run(__operator,options)
check('original_vehicle_resolved_continuity_returns',entry.source._vehicleResolved==true and entry._vehicleWasUnresolved==false)
__vehiclePower=0;options=__options();result=NMClientDetachedPlaybackPass.run(__operator,options)
check('original_vehicle_power_guard_stops',entry.stateSnapshot.isPlaying==false and entry.stateSnapshot.isOn==false and entry.stateSnapshot.lastStopReason=='vehicle_battery_empty')
check('vehicle_power_bumps_actual_epoch_revision',entry.stateSnapshot.playbackEpoch==1 and entry.stateSnapshot.revision==2)
check('vehicle_power_original_audio_cleanup',NMPlaybackRuntime.Active['vehicle:1']==nil)
W.reset();__resetHost();install();entry,row=__vehicleEntry('vehicle-match');row=candidate(entry,row);row.source.vehicleSqlId='foreign-sql';__candidates={row}
options=__options();result=NMClientDetachedPlaybackPass.run(__operator,options)
check('selected_vehicle_sql_identity_required',#result.detached==0)
row.source.vehicleSqlId='144';row.source.partId='OtherPart';result=NMClientDetachedPlaybackPass.run(__operator,__options())
check('selected_vehicle_part_identity_required',#result.detached==0)
W.reset();print('PASS D2 scheduler '..count)
