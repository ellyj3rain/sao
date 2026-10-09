local M=SAO.LeisureMusic
SAO.Needs.ownsRecoveryBody=function(id,body)return id=='person'and body==__body and __owned end
local count=0
local function check(name,value)assert(value,'D2_WORLD_JOIN:'..name);count=count+1;print('CASE '..name)end
local function options()
 return {valid={},inventoryOwners={},currentInventoryByUuid={},spPulseCandidates={},tickCount=1,
  nowRealMs=function()return __milliseconds end,observeMemoryDuration=function()end,
  consumeAndDispatchTrackFinished=NMClientTrackFinishedDispatch.consumeAndDispatchTrackFinished,
  shouldLogDetachedSync=function()return false end,
  applySPLocalVehiclePowerGuard=function(profile,state,source,uuid)NMClientSPLocalRuntime.applyVehiclePowerGuard(profile,state,source,uuid,{nowMs=function()return __milliseconds end,vehiclePowerTickMs={}})end,
  resolveVehicleCanonicalGeneration=function()return 1 end,persistVehicleCanonicalGeneration=function()end,setVehicleIdentityState=function()end,
  detachedOrchestration=NMClientDetachedOrchestration,continuity=NMClientVehicleContinuity,
  ownershipConflictState={},detachedRemoveLogMs={}}
end
local state=__worldFixture('placed',false)
check('unadmitted_music_has_no_selected_sources',#M.publicPlaybackSources()==0)
local work=__worldBegin()
check('maintained_music_supplies_exact_source',#M.publicPlaybackSources()==1 and M.publicPlaybackSources()[1].actorId=='person'and M.publicPlaybackSources()[1].body==__body)
check('music_admission_requests_original_pass',NMClientPlaybackTick._forceFullPass==true)
local opt=options();local result=NMClientDetachedPlaybackPass.run(__operator,opt)
check('music_selected_source_original_scheduler',result.detachedSyncCount==1 and opt.valid['public:1']and __emitterCount==1)
M.advance('person',__body)
check('music_current_native_receiver_hears_rendered_source',M.work('person').nativeProgress.soundObserved==true)
__stopSound();__milliseconds=101000;opt.tickCount=2;NMClientDetachedPlaybackPass.run(__operator,opt);M.advance('person',__body)
check('music_false_edge_keeps_work_active',M.outcome('person',work.sequence)==nil)
__milliseconds=102000;opt.tickCount=3;NMClientDetachedPlaybackPass.run(__operator,opt);M.advance('person',__body)
__milliseconds=103000;opt.tickCount=4;NMClientDetachedPlaybackPass.run(__operator,opt)
-- Exercise the original source's public confirmation-retirement operation.
-- This controlled source-host call qualifies loss of the shared confirmation,
-- without forging a Music callback, outcome or ending receipt.
NMPlaybackRuntime.invalidateTrackEnded('public:1')
check('original_source_retires_live_terminal_confirmation',NMPlaybackRuntime.TrackEndAwaitingAdvance['public:1']==nil)
M.advance('person',__body)
local outcome=M.outcome('person',work.sequence)
check('music_completed_after_original_native_dispatch',outcome and outcome.status=='completed'and state.playbackEpoch>work.playback.playbackEpoch)
local ending=outcome and outcome.nativeProgress.sourceTrackEndAwaitingAdvance
check('music_receipt_keeps_pre_dispatch_tuple',ending and ending.playbackEpoch==work.playback.playbackEpoch and ending.trackIndex==work.playback.trackIndex and ending.sourceGeneration==work.playback.sourceGeneration)
check('music_receipt_actual_source_debounce',ending and ending.falseCount>=ending.falseChecks and ending.pendingElapsedMs>=ending.windowMs)
check('music_completion_preserves_original_dispatch_custody',NMPlaybackRuntime.TrackEnded['public:1']==nil)
state=__worldFixture('placed',false);__admit=false
local offer=__worldOffer();check('music_planner_refusal_no_selected_source',not M.begin('person',__body,offer,'purpose:1')and #M.publicPlaybackSources()==0)
state=__worldFixture('placed',false);work=__worldBegin();__hearing=false
check('unheard_music_cannot_extend_source_scheduler',#M.publicPlaybackSources()==0)
opt=options();result=NMClientDetachedPlaybackPass.run(__operator,opt)
check('unheard_no_remote_emitter',result.detachedSyncCount==0 and __emitterCount==0)
__hearing=true;__visible=false
check('hidden_music_cannot_extend_source_scheduler',#M.publicPlaybackSources()==0)
__visible=true;state.revision=state.revision+1
check('changed_source_tuple_cannot_extend_scheduler',#M.publicPlaybackSources()==0)
state=__worldFixture('placed',false);work=__worldBegin();__admit=false
check('retired_purpose_cannot_extend_scheduler',#M.publicPlaybackSources()==0)
state=__worldFixture('placed',false);work=__worldBegin();__body.getModData().SAOExternalToken='replacement-generation'
check('replaced_body_cannot_extend_scheduler',#M.publicPlaybackSources()==0)
state=__worldFixture('placed',false);work=__worldBegin()
local peer={};for k,v in pairs(__body)do peer[k]=v end
peer.getModData=function()return {SAOPersonId='peer',SAOExternalToken='peer-generation:1'}end
peer.getStats=function()return __stats2 end;__records.peer={id='peer'}
local bodies={person=__body,peer=peer};SAO.Needs.ownsRecoveryBody=function(id,body)return bodies[id]==body and __owned end
SAO.Perception.resolveLeisureAudioSource=function(id,body,key)return __visible and bodies[id]==body and key==__row.key and __target or nil end
SAO.Perception.canHearLeisureSource=function(id,body,row,range)return __hearing and __visible and row.actorId==id and bodies[id]==body and range>0 end
local peerOffer;for _,row in ipairs(M.offers('peer',peer))do if row.audioSourceKey then peerOffer=row;break end end
local revision=state.revision;local ok,peerWork=M.begin('peer',peer,peerOffer,'purpose:1')
check('joined_second_listener_keeps_original_play_intent',ok and state.revision==revision and #M.publicPlaybackSources()==2)
opt=options();result=NMClientDetachedPlaybackPass.run(__operator,opt)
check('joined_two_listeners_one_original_emitter',result.detachedSyncCount==1 and __emitterCount==1)
M.advance('person',__body);M.advance('peer',peer)
check('joined_receivers_hear_independently',M.work('person').nativeProgress.soundObserved and M.work('peer').nativeProgress.soundObserved)
M.interrupt('person',__body,'person-leaves')
check('joined_personal_stop_preserves_other_transport',#M.publicPlaybackSources()==1 and NMPlaybackRuntime.Active['public:1']and state.isPlaying)
__stopSound()
for n=1,3 do __milliseconds=100000+n*1000;opt.tickCount=n+1;NMClientDetachedPlaybackPass.run(__operator,opt);M.advance('peer',peer)end
check('joined_terminal_bound_to_remaining_receiver',M.outcome('peer',peerWork.sequence).status=='completed'and M.outcome('person',work.sequence).status=='interrupted')
check('joined_listening_no_direct_skill_grant',__skillRequests==0)
M.reset('joined-proof-finished');print('PASS D2 world scheduler join '..count)
