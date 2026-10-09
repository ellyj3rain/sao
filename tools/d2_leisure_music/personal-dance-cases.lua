-- Appended after the source-loaded personal-device fixture in cases.lua.
SandboxVars.Debug={DanceAnim=false};Metabolics.Fitness='Fitness';CharacterTrait.PARTYANIMAL='PARTYANIMAL'
local function personalOffer()
    local rows,why=M.offers('person',__body)
    assert(not why,tostring(why))
    for _,row in ipairs(rows)do if row.activity=='dance-to-recorded-music'then return row end end
end
local function freshPersonal()
    local state=device()
    __body.isDead=function()return false end
    __body.setMetabolicTarget=function(_,value)__metabolic=value end
    __metabolic=nil;__seconds=1
    return state
end
local function beginPersonal()
    local selected=assert(personalOffer(),'personal dance offer missing')
    local ok,work=M.begin('person',__body,selected,'purpose:1')
    assert(ok,tostring(work))
    return work,selected
end
local state=freshPersonal()
local intent
for _,candidate in ipairs(M.intentOffers('person',__body))do
    if candidate.activity=='dance-to-recorded-music'then intent=candidate;break end
end
check('personal_dance_intent_requests_native_voice_preparation',not personalOffer() and intent and intent.requiresPreparation.sourceVoice)
check('personal_dance_voice_prepared',M.prepareActor('person',__body) and personalOffer())
local offer=personalOffer()
check('personal_dance_typed_offer',offer.sourceId=='NewMusic' and offer.danceActionRevision and offer.participationUnit=='one-source-dance-cycle'
    and offer.itemKey=='item:20:NewMusic.WalkmanBlue' and offer.deviceUUID==state.deviceUUID and offer.mediaFullType==state.mediaFullType)
check('personal_dance_not_heard_before_intent',M.currentHeardMusic('person',__body)==nil)
local work,selected=beginPersonal()
check('personal_dance_one_admitted_work',work.activity=='dance-to-recorded-music' and state.isPlaying and not __queued
    and work.phase=='awaiting-source-personal-hearing' and not work.nativeProgress.soundObserved
    and not M.outcome('person',work.sequence))
check('personal_dance_no_duplicate_work',#M.offers('person',__body)==0 and not M.begin('person',__body,selected,'purpose:1'))
local peer={};for k,v in pairs(__body)do peer[k]=v end
peer.getModData=function()return {SAOPersonId='peer',SAOExternalToken='peer-generation'}end
__records.peer={id='peer'}
local ownRecovery=SAO.Needs.ownsRecoveryBody
SAO.Needs.ownsRecoveryBody=function(id,body)return id=='person'and body==__body or id=='peer'and body==peer end
check('headphones_never_foreign_hearing_before_emitter',M.currentHeardMusic('peer',peer)==nil)
local advanced,why=M.advance('person',__body)
assert(advanced,tostring(why))
local fact=M.currentHeardMusic('person',__body)
check('personal_hearing_exact_actor_item_body_source',fact and fact.actorId=='person' and fact.bodyToken=='generation:1'
    and fact.itemKey=='item:20:NewMusic.WalkmanBlue' and fact.deviceUUID==state.deviceUUID
    and fact.playbackEpoch==state.playbackEpoch and fact.sourceGeneration==state.sourceGeneration
    and fact.trackIndex==state.trackIndex and fact.mediaFullType==state.mediaFullType
    and fact.sourceSoundId==1 and fact.nativeHeard and fact.soundObserved and fact.worldVolume==0)
check('headphones_never_foreign_hearing_after_emitter',M.currentHeardMusic('peer',peer)==nil)
local entry=__taliRuntime.Active[state.deviceUUID]
local originalEmitter=entry.emitter
entry.emitter={isPlaying=function()return true end}
check('foreign_emitter_cannot_be_personal_hearing',M.currentHeardMusic('person',__body)==nil)
entry.emitter=originalEmitter
local originalAudibility=__taliRuntime.computeLocalListenerAudibility
__taliRuntime.computeLocalListenerAudibility=function(...)
    local row=originalAudibility(...);row.worldVolume=.5;return row
end
check('world_leak_cannot_be_personal_hearing',M.currentHeardMusic('person',__body)==nil)
__taliRuntime.computeLocalListenerAudibility=originalAudibility
state.playbackEpoch=state.playbackEpoch+1
check('foreign_epoch_cannot_be_personal_hearing',M.currentHeardMusic('person',__body)==nil)
state.playbackEpoch=state.playbackEpoch-1
__body:getModData().SAOExternalToken='foreign-generation'
check('foreign_body_token_cannot_be_personal_hearing',M.currentHeardMusic('person',__body)==nil)
__body:getModData().SAOExternalToken='generation:1'
check('source_hearing_queues_original_action',__queued and M.work('person').nativeProgress.sourcePersonalHearing
    and M.work('person').nativeProgress.sourceDanceQueued and not M.work('person').nativeProgress.sourceDanceCycle)
local action=__queued
action:start()
check('original_dance_started_while_recording_plays',M.work('person') and __playing[1] and state.isPlaying
    and __body:getModData().IsDancingFull==true and not M.outcome('person',work.sequence))
action:update()
check('partial_native_dance_has_no_completion',M.work('person') and not M.work('person').nativeProgress.sourceDanceCycle
    and not M.outcome('person',work.sequence) and __skillRequests==0)
__seconds=40;action:update()
local result=M.outcome('person',work.sequence)
check('original_native_cycle_completes_personal_dance',result and result.status=='completed'
    and result.nativeProgress.sourceDanceCycle and result.nativeProgress.sourceDanceCycle.sourceCallbackCompleted
    and result.nativeProgress.sourceDanceCycle.heardMusic.deviceUUID==state.deviceUUID
    and result.nativeProgress.sourceDanceCycle.heardMusic.bodyToken=='generation:1'
    and result.sourceAdaptations.rawRevision==selected.danceActionRevision
    and result.revision==selected.revision)
check('terminal_source_stop_is_exact',result.nativeProgress.sourcePlaybackStop.sourceStateExact
    and result.nativeProgress.sourcePlaybackStop.sourceStopAccepted and result.nativeProgress.sourcePlaybackStop.personalEmitterRetired
    and result.nativeProgress.sourcePlaybackStop.playbackEpoch==result.playback.playbackEpoch
    and not state.isPlaying and not __playing[1] and result.cleanupSucceeded)
check('native_dance_physiology_and_skills',__stats:get(CharacterStat.ENDURANCE)<.8 and __stats:get(CharacterStat.FATIGUE)>.2
    and __skillRequests==2 and __records.person.leisureMusicSkillRequests[1].perkName=='Dancing'
    and __records.person.leisureMusicSkillRequests[2].perkName=='Fitness')
check('personal_dance_retires_private_hearing',M.currentHeardMusic('person',__body)==nil and M.currentHeardMusic('peer',peer)==nil)
SAO.Needs.ownsRecoveryBody=ownRecovery

state=freshPersonal();M.prepareActor('person',__body);work=beginPersonal();M.advance('person',__body)
action=__queued;action:start();action:update()
local sourceConsume=SAO.LeisureSkill.consume;local reentered=false
SAO.LeisureSkill.consume=function(...)
    if not reentered then reentered=true;action:perform();return false end
    return sourceConsume(...)
end
__seconds=40;action:update();SAO.LeisureSkill.consume=sourceConsume
result=M.outcome('person',work.sequence)
check('partial_original_callback_cannot_complete_personal_dance',reentered and result and result.status=='interrupted'
    and result.nativeProgress.sourceDanceCyclePartial and not result.nativeProgress.sourceDanceCycle
    and not state.isPlaying)

state=freshPersonal();M.prepareActor('person',__body);work=beginPersonal()
__queueRefusal=true;M.advance('person',__body);result=M.outcome('person',work.sequence)
check('queue_refusal_retains_audio_only_failure',result and result.status=='interrupted' and result.terminalPhase=='personal-hearing-observed'
    and result.nativeProgress.sourcePersonalHearing and not result.nativeProgress.sourceDanceCycle and not state.isPlaying)

state=freshPersonal();M.prepareActor('person',__body);work=beginPersonal();__audioFailure=true
M.advance('person',__body);result=M.outcome('person',work.sequence)
check('silent_emitter_waits_without_dance_credit',not result and M.work('person').phase=='awaiting-source-personal-hearing'
    and not M.work('person').nativeProgress.sourcePersonalHearing and not __queued)
M.interrupt('person',__body,'no-personal-audio');result=M.outcome('person',work.sequence)
check('failed_emitter_never_queues_dance',result and result.status=='interrupted' and not result.nativeProgress.sourcePersonalHearing
    and not result.nativeProgress.sourceDanceCycle and not __queued and not state.isPlaying)

state=freshPersonal();M.prepareActor('person',__body);work=beginPersonal();M.advance('person',__body)
action=__queued;action:start();state.playbackEpoch=state.playbackEpoch+1;__seconds=40;action:update()
result=M.outcome('person',work.sequence)
check('changed_epoch_refuses_cycle_and_preserves_new_source',result and result.status=='interrupted' and not result.nativeProgress.sourceDanceCycle
    and result.nativeProgress.sourcePlaybackStop.sourceStateExact==false and state.isPlaying and __skillRequests==0)

state=freshPersonal();M.prepareActor('person',__body);work=beginPersonal();M.advance('person',__body)
action=__queued;action:start();state.mediaFullType='Other.Tape';__seconds=40;action:update();result=M.outcome('person',work.sequence)
check('changed_media_refuses_cycle_and_preserves_new_source',result and result.status=='interrupted' and not result.nativeProgress.sourceDanceCycle
    and state.isPlaying and __skillRequests==0)

for _,field in ipairs({'deviceUUID','revision','sourceGeneration','trackIndex'})do
    state=freshPersonal();M.prepareActor('person',__body);work=beginPersonal();M.advance('person',__body)
    action=__queued;action:start()
    if field=='deviceUUID'then state[field]='other-device'else state[field]=state[field]+1 end
    __seconds=40;action:update();result=M.outcome('person',work.sequence)
    check('changed_'..field..'_refuses_cycle',result and result.status=='interrupted'
        and not result.nativeProgress.sourceDanceCycle and state.isPlaying and __skillRequests==0)
end

state=freshPersonal();M.prepareActor('person',__body);work=beginPersonal();M.advance('person',__body)
action=__queued;action:start();__items={};__seconds=40;action:update();result=M.outcome('person',work.sequence)
check('lost_device_custody_refuses_cycle',result and result.status=='interrupted' and not result.nativeProgress.sourceDanceCycle
    and not result.nativeProgress.sourcePlaybackStop.sourceStateExact and __skillRequests==0)

state=freshPersonal();M.prepareActor('person',__body);work=beginPersonal();M.advance('person',__body)
action=__queued;action:start();M.interrupt('person',__body,'urgent-need');result=M.outcome('person',work.sequence)
check('urgent_interrupt_stops_personal_source_and_dance',result and result.status=='interrupted' and result.terminalPhase=='awaiting-native-dance-action'
    and not state.isPlaying and not __playing[1] and __body:getModData().IsDancingFull==false and __skillRequests==0)

state=freshPersonal();M.prepareActor('person',__body);work=beginPersonal();M.advance('person',__body)
local recoveryBeforeDeath=SAO.Needs.ownsRecoveryBody
SAO.Needs.ownsRecoveryBody=function(id,body)
    return recoveryBeforeDeath(id,body) and not body:isDead()
end
action=__queued;action:start();__body.isDead=function()return true end
check('death_revokes_recovery_body_owner',not SAO.Needs.ownsRecoveryBody('person',__body))
check('dead_actor_cannot_hold_personal_hearing',M.currentHeardMusic('person',__body)==nil)
M.interrupt('person',__body,'native-death');result=M.outcome('person',work.sequence)
check('death_stops_personal_source_without_cycle_credit',result and result.status=='interrupted' and not state.isPlaying
    and result.nativeProgress.sourcePlaybackStop.sourceStateExact and result.nativeProgress.sourcePlaybackStop.sourceStopAccepted
    and result.nativeProgress.sourcePlaybackStop.personalEmitterRetired
    and not __playing[1] and __body:getModData().IsDancingFull==false and __skillRequests==0)

state=freshPersonal();M.prepareActor('person',__body);work=beginPersonal();M.advance('person',__body)
action=__queued;action:start();state.playbackEpoch=state.playbackEpoch+1;__body.isDead=function()return true end
M.interrupt('person',__body,'native-death');result=M.outcome('person',work.sequence)
check('death_changed_source_preserves_new_playback_state',result and result.status=='interrupted'
    and result.nativeProgress.sourcePlaybackStop.sourceStateExact==false and not result.nativeProgress.sourcePlaybackStop.sourceStopAccepted
    and result.nativeProgress.sourcePlaybackStop.personalEmitterRetired and state.isPlaying and not __playing[1]
    and not result.nativeProgress.sourceDanceCycle and __skillRequests==0)

state=freshPersonal();M.prepareActor('person',__body);work=beginPersonal();M.advance('person',__body)
action=__queued;action:start();__items={};__body.isDead=function()return true end
M.interrupt('person',__body,'native-death');result=M.outcome('person',work.sequence)
check('death_transferred_item_preserves_source_state',result and result.status=='interrupted'
    and result.nativeProgress.sourcePlaybackStop.sourceStateExact==false and not result.nativeProgress.sourcePlaybackStop.sourceStopAccepted
    and result.nativeProgress.sourcePlaybackStop.personalEmitterRetired and state.isPlaying and not __playing[1]
    and not result.nativeProgress.sourceDanceCycle and __skillRequests==0)

state=freshPersonal();M.prepareActor('person',__body);work=beginPersonal();M.advance('person',__body)
action=__queued;action:start();__body:getModData().SAOExternalToken='foreign-generation';__body.isDead=function()return true end
M.interrupt('person',__body,'native-death');result=M.outcome('person',work.sequence)
check('death_foreign_body_token_preserves_source_state',result and result.status=='interrupted'
    and result.nativeProgress.sourcePlaybackStop.sourceStateExact==false and not result.nativeProgress.sourcePlaybackStop.sourceStopAccepted
    and result.nativeProgress.sourcePlaybackStop.personalEmitterRetired and state.isPlaying and not __playing[1]
    and not result.nativeProgress.sourceDanceCycle and __skillRequests==0)
SAO.Needs.ownsRecoveryBody=recoveryBeforeDeath

state=freshPersonal();M.prepareActor('person',__body);work=beginPersonal();M.advance('person',__body)
action=__queued;action:start();M.reset('module-reload');result=M.outcome('person',work.sequence)
check('reload_stops_personal_source_without_cycle_credit',result and result.status=='interrupted' and not state.isPlaying
    and not __playing[1] and __body:getModData().IsDancingFull==false and __skillRequests==0)

state=freshPersonal();M.prepareActor('person',__body)
state.mediaFullType=nil;state.batteryPresent=false;state.batteryCharge=0
local supplied={battery={itemKey='item:21:Base.Battery'},media={itemKey='item:22:Controlled.Tape'}}
local supplyReceipt={batteryItemKey=supplied.battery.itemKey,mediaItemKey=supplied.media.itemKey,source='controlled-supply-owner'}
local originalSupply=SAO.LeisureMusicSupply
SAO.LeisureMusicSupply={
    plan=function(_,_,_,current)if current.batteryPresent and current.mediaFullType then return nil end;return supplied end,
    outputMode=function(profile,current,context,selection)
        return selection and 'personal'or NMDeviceProfiles.resolveOutputMode(profile,current,context,false)
    end,
    materialKeys=function()return {battery=supplied.battery,media=supplied.media}end,
    retireSaved=function()end,prepareEnvironment=function()end,begin=function()return true end,
    advance=function()
        state.mediaFullType='Controlled.Tape';state.batteryPresent=true;state.batteryCharge=1
        return true,'ready',supplyReceipt
    end,release=function()return true end,
}
offer=assert(personalOffer())
check('supplied_personal_dance_offer_retains_material_keys',offer.sourceSupplies and offer.materials
    and offer.materials.battery.itemKey==supplied.battery.itemKey and offer.materials.media.itemKey==supplied.media.itemKey)
local accepted;accepted,work=M.begin('person',__body,offer,'purpose:1')
check('supplied_personal_dance_one_preparing_work',accepted and work.phase=='preparing-source-supplies' and not state.isPlaying)
M.advance('person',__body)
local suppliedWork=M.work('person')
check('supplied_personal_dance_resumes_same_work',suppliedWork and suppliedWork.sequence==work.sequence
    and suppliedWork.nativeProgress.sourceSupplyPreparation.batteryItemKey==supplied.battery.itemKey
    and suppliedWork.sourceOffer.sourceSupplies.media.itemKey==supplied.media.itemKey
    and suppliedWork.afterSupplyOffer.mediaFullType=='Controlled.Tape'
    and suppliedWork.nativeProgress.sourcePersonalHearing and __queued and state.isPlaying)
M.interrupt('person',__body,'supply-check-complete')
check('supplied_personal_dance_interrupt_retires_source',not state.isPlaying and not __playing[1]
    and M.outcome('person',work.sequence).status=='interrupted')
SAO.LeisureMusicSupply=originalSupply

state=freshPersonal();M.prepareActor('person',__body);state.headphoneItemFullType=nil
check('world_route_cannot_offer_personal_dance',not personalOffer())
state=freshPersonal();M.prepareActor('person',__body);state.batteryCharge=0
check('unpowered_device_cannot_offer_personal_dance',not personalOffer())
state=freshPersonal();M.prepareActor('person',__body);__tali=false
check('missing_recorded_source_cannot_offer_personal_dance',not personalOffer())
state=freshPersonal();M.prepareActor('person',__body)
local sourceAvailable=SAO.SourceIntegration.available
SAO.SourceIntegration.available=function(id)return id=='NewMusic'end
local listening=false
for _,candidate in ipairs(M.offers('person',__body))do if candidate.activity=='listen-recorded-music'then listening=true end end
check('missing_dance_source_cannot_offer_personal_dance',listening and not personalOffer())
SAO.SourceIntegration.available=sourceAvailable
print('PASS D2 personal dance '..count)
