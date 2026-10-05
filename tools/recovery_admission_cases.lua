-- Real Controller + Needs admission and actual adapter custody, with controlled
-- native state/geometry. No forced state transition or physiological credit.
local pendingChecks=0
local function waitingCheck(name,value)
    if not value then error("ADMISSION:"..name.." reason="..tostring(rec and rec.recoveryPlacement and rec.recoveryPlacement.reason)) end
    pendingChecks=pendingChecks+1
end
local state,poseCalls,actualAdapter= "WalkTowardState",0,__actualRecoveryPose
local function freshWaiting()
    SAO.RecoveryPose={cancel=function()return true end,retire=function()end}
    freshPlacement()
    SAO.RecoveryPose={captureCustody=actualAdapter.captureCustody,ownsCustody=actualAdapter.ownsCustody,
        begin=function(b,k,id,place)poseCalls=poseCalls+1;return {body=b,kind=k,id=id,place=place}end,
        cancel=function()return true end,retire=function()end,observed=function()return false end}
    state="WalkTowardState";poseCalls=0
    body.getCurrentStateName=function()return state end
    SAO.Needs.beginRecovery=__actualBeginRecovery
    nativePlaces={bed(0,0)}
    local result,why=Ctl.admitRecoveryPlace("runner",agent,body,100,"sleep",nativePlaces[1])
    return result
end
waitingCheck("arrival_holds_selected_intent",freshWaiting() and agent.recoveryAdmission
    and rec.recoveryPlacement.reason=="native-body-not-idle"
    and rec.recoveryPlacement.nativeState=="WalkTowardState" and rec.recoveryPlacement.status=="waiting-native-idle")
waitingCheck("wait_grants_no_pose_or_sleep",poseCalls==0 and not agent.recovery and not agent.sleeping
    and not rec.recoveryIntent and not rec.recoveryExperiences)
waitingCheck("native_boundary_wait_not_new_route",Ctl.updateRecovery("runner",agent,body,101,needs,false)
    and agent.recoveryAdmission and poseCalls==0 and not SAO.Locomotion.jobs.runner)
state="IdleState"
waitingCheck("actual_idle_admits_exact_selection",Ctl.updateRecovery("runner",agent,body,102,needs,false)
    and poseCalls==1 and not agent.recoveryAdmission and agent.recovery
    and rec.recoveryIntent.status=="preparing" and rec.recoveryIntent.place.key=="bed:exact")
waitingCheck("idle_admission_is_not_sleep_credit",not agent.sleeping and not rec.recoveryExperiences)
freshWaiting();rec.recoveryPlacement.place.x=99;rec.recoveryPlacement.kind="rest"
waitingCheck("frozen_choice_ignores_public_view_mutation",agent.recoveryAdmission.place.x==0
    and agent.recoveryAdmission.kind=="sleep")
state="IdleState"
waitingCheck("frozen_choice_retries_original_action",Ctl.updateRecovery("runner",agent,body,101,needs,false)
    and rec.recoveryIntent.kind=="sleep" and rec.recoveryIntent.place.x==0)
freshWaiting();rec.bodyOwnerToken="replacement"
waitingCheck("returned_token_cannot_retry",not Ctl.updateRecovery("runner",agent,body,101,needs,false)
    and not agent.recoveryAdmission and poseCalls==0 and rec.recoveryPlacement.reason=="body-binding-lost")
freshWaiting();local replacement={}
waitingCheck("foreign_body_cannot_retry",not Ctl.updateRecovery("runner",agent,replacement,101,needs,false)
    and not agent.recoveryAdmission and poseCalls==0)
freshWaiting();local originalRec=agent.rec;agent.rec={}
waitingCheck("foreign_record_cannot_retry",not Ctl.updateRecovery("runner",agent,body,101,needs,false)
    and not agent.recoveryAdmission and poseCalls==0)
agent.rec=originalRec
freshWaiting();nativePlaces[1].objectIndex=3
waitingCheck("changed_bed_cannot_retry",not Ctl.updateRecovery("runner",agent,body,101,needs,false)
    and not agent.recoveryAdmission and poseCalls==0 and rec.recoveryPlacement.reason=="recovery-place-unavailable")
freshWaiting();permission=false
waitingCheck("changed_permission_interrupts_wait",not Ctl.updateRecovery("runner",agent,body,101,needs,false)
    and not agent.recoveryAdmission and poseCalls==0)
freshWaiting()
waitingCheck("threat_interrupts_wait",not Ctl.updateRecovery("runner",agent,body,101,needs,true)
    and not agent.recoveryAdmission and poseCalls==0 and rec.recoveryPlacement.reason=="competing-survival-pressure")
freshWaiting();bleeding=true
waitingCheck("bleeding_interrupts_wait",not Ctl.updateRecovery("runner",agent,body,101,needs,false)
    and not agent.recoveryAdmission and poseCalls==0)
freshWaiting();needs.thirst=.99
waitingCheck("urgent_need_interrupts_wait",not Ctl.updateRecovery("runner",agent,body,101,needs,false)
    and not agent.recoveryAdmission and poseCalls==0)
freshWaiting();owned=true
waitingCheck("new_native_work_interrupts_wait",not Ctl.updateRecovery("runner",agent,body,101,needs,false)
    and not agent.recoveryAdmission and poseCalls==0 and rec.recoveryPlacement.reason=="body-work-unavailable")
freshWaiting()
waitingCheck("bounded_idle_wait_expires",not Ctl.updateRecovery("runner",agent,body,220,needs,false)
    and not agent.recoveryAdmission and poseCalls==0 and rec.recoveryPlacement.reason=="native-idle-wait-expired")
freshWaiting()
waitingCheck("rewound_tick_refuses_wait",not Ctl.updateRecovery("runner",agent,body,99,needs,false)
    and not agent.recoveryAdmission and poseCalls==0)
freshWaiting();Ctl.__inspectionProbeState(agent,"runner","FLEE","new danger")
waitingCheck("state_change_releases_pending_choice",not agent.recoveryAdmission
    and rec.recoveryPlacement.status=="interrupted" and poseCalls==0)
freshWaiting();local serialized=__nativeRoundtrip(rec)
waitingCheck("durable_observation_has_no_runtime_body",serialized.recoveryPlacement.status=="waiting-native-idle"
    and serialized.recoveryIntent==nil and serialized.recoveryPlacement.body==nil)
agent={rec=rec,state="IDLE"};Ctl.agents.runner=agent
waitingCheck("reload_does_not_invent_pending_authority",not Ctl.updateRecovery("runner",agent,body,101,needs,false)
    and not agent.recoveryAdmission and poseCalls==0 and not SAO.Needs.resumeRecovery("runner",body))
freshWaiting();agent.recoveryAdmission=nil
SAO.Needs.beginRecovery=function()return false,"native-bed-queue-refused"end
waitingCheck("nontransient_refusal_is_not_pending",not Ctl.admitRecoveryPlace("runner",agent,body,101,"sleep",nativePlaces[1])
    and not agent.recoveryAdmission and rec.recoveryPlacement.reason=="native-bed-queue-refused")
freshWaiting();agent.recoveryAdmission=nil;SAO.RecoveryPose.captureCustody=function()return nil end
waitingCheck("missing_custody_has_no_wait",not Ctl.admitRecoveryPlace("runner",agent,body,101,"sleep",nativePlaces[1])
    and not agent.recoveryAdmission)
local preparingChecks=0
local function prepared(name,value)
    if not value then error("PREPARING:"..name.." reason="..tostring(rec.recoveryPlacement and rec.recoveryPlacement.reason)) end
    preparingChecks=preparingChecks+1
end
local function freshSaved()
    freshWaiting();agent.recoveryAdmission=nil
    rec.recoveryIntent={kind="sleep",status="preparing",place=bed(0,0)}
    return rec.recoveryIntent
end
local function retrySaved(tick)
    return Ctl.resumePreparingRecovery("runner",agent,body,tick or 100,needs,false)
end
freshSaved()
local resumed,kind,status,choice=SAO.Needs.resumeRecovery("runner",body)
prepared("saved_preparation_survives_without_native_pose",not resumed and status=="saved-preparation"
    and kind=="sleep" and rec.recoveryIntent and choice.place.key=="bed:exact")
choice.place.x=99
prepared("saved_choice_is_detached",rec.recoveryIntent.place.x==0)
prepared("fresh_exact_custody_waits_without_queue",retrySaved() and agent.recoveryAdmission and poseCalls==0
    and not agent.recovery and not agent.sleeping and not rec.recoveryExperiences)
prepared("owned_clock_stamps_original_window",rec.recoveryIntent.resumeWaitStartedAt==100
    and rec.recoveryIntent.resumeWaitDeadline==220)
state="IdleState"
prepared("fresh_native_idle_requeues_exact_saved_choice",Ctl.updateRecovery("runner",agent,body,101,needs,false)
    and poseCalls==1 and agent.recovery and rec.recoveryIntent.status=="preparing")
prepared("fresh_queue_keeps_original_origin",rec.recoveryIntent.resumeWaitStartedAt==100)
prepared("queue_is_not_measured_recovery",not agent.sleeping and not rec.recoveryExperiences
    and SAO.Needs.recoveryStatus("runner",body).phase=="preparing")
SAO.Needs.resetRecoveries("module-reload")
agent={rec=rec,state="IDLE"};Ctl.agents.runner=agent;state="WalkTowardState"
prepared("second_reload_reuses_original_window",retrySaved(219) and agent.recoveryAdmission.deadline==220)
prepared("second_reload_cannot_refresh_window",not Ctl.updateRecovery("runner",agent,body,220,needs,false)
    and not rec.recoveryIntent and not agent.recoveryAdmission and poseCalls==1)
local actualSavedIntent=freshSaved();Ctl.__fleeProbeDecide("runner",agent,body)
prepared("actual_decide_consumes_saved_preparation",agent.recoveryAdmission~=nil and poseCalls==0
    and rec.recoveryIntent==actualSavedIntent and agent.recoveryAdmission.savedPreparation==actualSavedIntent
    and actualSavedIntent.resumeWaitDeadline~=nil and not agent.recovery)
freshSaved();rec.recoveryIntent.actorId="foreign"
prepared("foreign_person_refused",not retrySaved() and not rec.recoveryIntent and poseCalls==0)
freshSaved();rec.bodyOwnerToken="replacement"
prepared("returned_body_token_refused",not retrySaved() and poseCalls==0 and not agent.recoveryAdmission)
prepared("returned_token_does_not_erase_owner_choice",rec.recoveryIntent~=nil and rec.recoveryIntent.resumeWaitStartedAt==nil)
freshSaved();local heldIntent=rec.recoveryIntent
prepared("foreign_receiver_cannot_erase_owner_choice",not Ctl.resumePreparingRecovery("runner",agent,{},100,needs,false)
    and rec.recoveryIntent==heldIntent and heldIntent.resumeWaitStartedAt==nil and poseCalls==0)
freshSaved();agent.passive=true;heldIntent=rec.recoveryIntent
prepared("passive_receiver_cannot_erase_owner_choice",not retrySaved() and rec.recoveryIntent==heldIntent and poseCalls==0)
freshSaved();body.isDead=function()return true end
prepared("dead_body_refused",not retrySaved() and poseCalls==0)
freshSaved();nativePlaces[1].objectIndex=7
prepared("changed_native_place_refused",not retrySaved() and not rec.recoveryIntent and poseCalls==0)
freshSaved();permission=false
prepared("current_standing_refused",not retrySaved() and not rec.recoveryIntent and poseCalls==0)
freshSaved()
prepared("current_threat_refused",not Ctl.resumePreparingRecovery("runner",agent,body,100,needs,true)
    and not rec.recoveryIntent and poseCalls==0)
freshSaved();needs.hunger=.99
prepared("urgent_need_refused",not retrySaved() and not rec.recoveryIntent and poseCalls==0)
freshSaved();owned=true
prepared("native_owned_work_refused",not retrySaved() and not rec.recoveryIntent and poseCalls==0)
freshSaved();rec.worldSourceReservation={id="source-work"}
prepared("source_reservation_refused",not retrySaved() and not rec.recoveryIntent and poseCalls==0
    and rec.worldSourceReservation.id=="source-work")
freshSaved();agent.coordinationCommitment="accepted-work"
prepared("coordination_responsibility_refused",not retrySaved() and not rec.recoveryIntent and poseCalls==0
    and agent.coordinationCommitment=="accepted-work")
freshSaved();study=true
prepared("study_owner_refused_without_interrupt",not retrySaved() and not rec.recoveryIntent and poseCalls==0
    and study and not interrupted)
freshSaved();rec.cookingWork={id="cooking-owned"}
prepared("cooking_owner_refused",not retrySaved() and not rec.recoveryIntent and poseCalls==0
    and rec.cookingWork.id=="cooking-owned")
freshSaved();rec.resourceProductionWork={id="resource-owned"}
prepared("resource_owner_refused",not retrySaved() and not rec.recoveryIntent and poseCalls==0
    and rec.resourceProductionWork.id=="resource-owned")
freshSaved();agent.forageInspection={}
prepared("forage_owner_refused",not retrySaved() and not rec.recoveryIntent and poseCalls==0)
freshSaved();needs.fatigue=.2
prepared("relieved_need_refused",not retrySaved() and not rec.recoveryIntent and poseCalls==0)
freshSaved();needs.fatigue=nil
prepared("unknown_current_need_refused",not retrySaved() and not rec.recoveryIntent and poseCalls==0)
freshSaved();rec.recoveryIntent.requestedAtHours=hours+1
prepared("future_intent_refused",not retrySaved() and not rec.recoveryIntent and poseCalls==0)
freshSaved();rec.recoveryIntent.resumeWaitStartedAt=100;rec.recoveryIntent.resumeWaitDeadline=221
prepared("malformed_deadline_refused",not retrySaved() and not rec.recoveryIntent and poseCalls==0)
freshSaved();rec.recoveryIntent.resumeWaitStartedAt=100;rec.recoveryIntent.resumeWaitDeadline=220
prepared("backward_current_clock_refused",not retrySaved(99) and not rec.recoveryIntent and poseCalls==0)
freshSaved();SAO.RecoveryPose.captureCustody=function()return nil end
prepared("missing_fresh_custody_refused",not retrySaved() and not rec.recoveryIntent and poseCalls==0)
freshSaved();state="IdleState";SAO.RecoveryPose.begin=function()return nil,"native-bed-queue-refused"end
prepared("unsafe_queue_refusal_cancels_saved_choice",not retrySaved() and not rec.recoveryIntent
    and not agent.recoveryAdmission and not rec.recoveryExperiences)
freshSaved();retrySaved();local oldIntent=rec.recoveryIntent
rec.recoveryIntent={kind="sleep",status="preparing",place=bed(0,0)}
prepared("changed_choice_is_not_replaced_or_erased",not Ctl.updateRecovery("runner",agent,body,101,needs,false)
    and rec.recoveryIntent and rec.recoveryIntent~=oldIntent and rec.recoveryIntent.kind=="sleep" and poseCalls==0)
freshSaved();retrySaved();local saved=__nativeRoundtrip(rec)
prepared("serialized_intent_retains_only_scalars",saved.recoveryIntent.resumeWaitDeadline==220
    and saved.recoveryIntent.body==nil and saved.recoveryIntent.custody==nil and saved.recoveryIntent.pose==nil)
freshSaved();state="IdleState";nativePlaces={ground(0,0)}
rec.recoveryIntent={kind="rest",status="preparing",place=ground(0,0),oldFatigue=1,startedAtHours=0}
needs={hunger=.1,thirst=.1,fatigue=.9,endurance=.4}
local resting=false
body.isResting=function()return resting end
body.setIsResting=function(_,value)resting=value end
SAO.RecoveryPose.observed=function()return resting end
SAO.RecoveryPose.poll=function()resting=true;return "admitted" end
prepared("rest_resume_queues_without_prior_credit",retrySaved() and rec.recoveryIntent.status=="preparing"
    and not rec.recoveryExperiences and not resting)
hours=50
prepared("actual_pose_admits_fresh_segment",SAO.Needs.pollRecovery("runner",body)=="running"
    and rec.recoveryIntent.status=="recovering" and not rec.recoveryExperiences)
needs={hunger=.1,thirst=.1,fatigue=.9,endurance=.85};hours=50.1
prepared("only_post_admission_measured_recovery_completes",SAO.Needs.pollRecovery("runner",body)=="completed"
    and rec.recoveryExperiences and #rec.recoveryExperiences==1)
prepared("measured_segment_excludes_preload_interval",math.abs(rec.recoveryExperiences[1].durationHours-.1)<.00001
    and rec.recoveryExperiences[1].beforeValue==.4)
__result="PASS recovery admission "..pendingChecks.."; preparing "..preparingChecks.."; placement "..placementChecks.."; concepts "..conceptChecks.."; ordinary "..checks
local reboundChecks=0
local function rebound(name,value)
    if not value then error("REBINDED:"..name.." reason="..tostring(rec.recoveryPlacement and rec.recoveryPlacement.reason)) end
    reboundChecks=reboundChecks+1
end
local function freshRoute()
    local intent=freshSaved()
    body.x,body.y=2,0;nativePlaces={}
    SAOJavaBridge.setForceEntry=function()return true end
    state="IdleState";Ctl.__recoveryProbeTick(100)
    return intent
end
local function arriveSaved(tick,currentKey)
    local route=agent.recoveryRoute
    body.x,body.y,body.z=route.place.x,route.place.y,route.place.z
    nativePlaces={bed(0,0)};nativePlaces[1].key=currentKey or "bed:new-runtime-object"
    route.job.done,route.job.result=true,"arrived"
    Ctl.__recoveryProbeTick(tick or 102)
    Ctl.__fleeProbeDecide("runner",agent,body)
end
local budgetChecks=0
local function budget(name,value)
    if not value then error("BUDGET:"..name.." reason="..tostring(rec.recoveryPlacement and rec.recoveryPlacement.reason)) end
    budgetChecks=budgetChecks+1
end
local function retireRouteForReload()
    SAO.Needs.resetRecoveries("module-reload")
    SAO.Locomotion.jobs.runner=nil
    agent={rec=rec,state="IDLE"};Ctl.agents.runner=agent
end
freshRoute();retrySaved()
budget("saved_navigation_uses_existing_travel_budget",agent.recoveryRoute
    and rec.recoveryIntent.resumeTravelStartedAt==100 and rec.recoveryIntent.resumeTravelDeadline==1900
    and rec.recoveryIntent.resumeWaitStartedAt==nil and poseCalls==0)
Ctl.__recoveryProbeTick(500);Ctl.__fleeProbeDecide("runner",agent,body)
budget("actual_decide_travel_over120_remains_guarded",agent.recoveryRoute
    and agent.recoveryRoute.deadline==1900 and poseCalls==0 and not rec.recoveryExperiences)
state="WalkTowardState";arriveSaved(500)
budget("first_observed_arrival_starts_only_idle120",agent.recoveryAdmission
    and agent.recoveryAdmission.startedAt==500 and agent.recoveryAdmission.deadline==620
    and rec.recoveryIntent.resumeWaitStartedAt==500 and rec.recoveryIntent.resumeTravelDeadline==1900
    and not agent.recoveryRoute and poseCalls==0 and not rec.recoveryExperiences)
state="IdleState";Ctl.updateRecovery("runner",agent,body,501,needs,false)
budget("fresh_queue_preserves_both_bounded_origins",agent.recovery and poseCalls==1
    and rec.recoveryIntent.resumeTravelStartedAt==100 and rec.recoveryIntent.resumeTravelDeadline==1900
    and rec.recoveryIntent.resumeWaitStartedAt==500 and rec.recoveryIntent.resumeWaitDeadline==620
    and not agent.sleeping and not rec.recoveryExperiences)
retireRouteForReload();state="WalkTowardState"
budget("second_reload_keeps_arrival_deadline",retrySaved(619) and agent.recoveryAdmission.deadline==620
    and rec.recoveryIntent.resumeTravelDeadline==1900)
budget("arrival_idle_deadline_cannot_renew",not Ctl.updateRecovery("runner",agent,body,620,needs,false)
    and not rec.recoveryIntent and not agent.recoveryAdmission and poseCalls==1)
freshRoute();retrySaved();local originalTravel=rec.recoveryIntent
retireRouteForReload()
budget("travel_reload_keeps_original1800",retrySaved(500) and agent.recoveryRoute.deadline==1900
    and rec.recoveryIntent==originalTravel and originalTravel.resumeWaitDeadline==nil and poseCalls==0)
retireRouteForReload()
budget("expired_travel_cannot_restart",not retrySaved(1900) and not rec.recoveryIntent
    and not agent.recoveryRoute and poseCalls==0)
freshRoute();retrySaved()
budget("live_travel_deadline_still_expires",not Ctl.updateRecovery("runner",agent,body,1900,needs,false)
    and not rec.recoveryIntent and not agent.recoveryRoute and poseCalls==0)
freshRoute();rec.recoveryIntent.resumeWaitStartedAt=100;rec.recoveryIntent.resumeWaitDeadline=220
budget("preexisting_wait_expires_before_displaced_restart",not retrySaved(220) and not rec.recoveryIntent
    and not agent.recoveryRoute and __ordered==nil and poseCalls==0)
freshRoute();rec.recoveryIntent.resumeWaitStartedAt=100;rec.recoveryIntent.resumeWaitDeadline=220
retrySaved();state="WalkTowardState";arriveSaved(210)
budget("arrival_preserves_preexisting_wait120",agent.recoveryAdmission
    and agent.recoveryAdmission.startedAt==100 and agent.recoveryAdmission.deadline==220
    and rec.recoveryIntent.resumeWaitDeadline==220 and poseCalls==0)
freshRoute();retrySaved();retireRouteForReload()
budget("travel_backward_clock_refused",not retrySaved(99) and not rec.recoveryIntent and poseCalls==0)
freshRoute();rec.recoveryIntent.resumeTravelStartedAt=100;rec.recoveryIntent.resumeTravelDeadline=1901
budget("malformed_travel_budget_refused",not retrySaved() and not rec.recoveryIntent and poseCalls==0)
freshRoute();rec.recoveryIntent.resumeTravelDeadline=1900
budget("partial_travel_clock_refused",not retrySaved() and not rec.recoveryIntent and poseCalls==0)
freshRoute();retrySaved();retireRouteForReload();body.x,body.y=0,0;nativePlaces={bed(0,0)}
budget("unobserved_expired_travel_cannot_become_idle_grace",not retrySaved(1900)
    and not rec.recoveryIntent and poseCalls==0)
freshRoute();retrySaved();state="WalkTowardState";arriveSaved(1850)
retireRouteForReload()
budget("observed_idle_window_outlives_completed_travel",retrySaved(1950)
    and agent.recoveryAdmission.deadline==1970 and rec.recoveryIntent.resumeTravelDeadline==1900 and poseCalls==0)
budget("late_idle_wait_still_bounded",not Ctl.updateRecovery("runner",agent,body,1970,needs,false)
    and not rec.recoveryIntent and poseCalls==0)

local originalSaved=freshRoute()
Ctl.__fleeProbeDecide("runner",agent,body)
rebound("actual_decide_routes_to_saved_approach",agent.recoveryRoute and agent.state=="TRAVEL"
    and agent.recoveryRoute.savedPreparation==originalSaved and __ordered.x==0 and __ordered.y==0
    and poseCalls==0 and not agent.recoveryAdmission and not agent.recovery and not rec.recoveryExperiences)
local originalJob=agent.recoveryRoute.job
Ctl.__recoveryProbeTick(101);Ctl.__fleeProbeDecide("runner",agent,body)
rebound("actual_decide_preserves_pending_route",agent.recoveryRoute and agent.recoveryRoute.job==originalJob
    and rec.recoveryIntent==originalSaved and rec.recoveryIntent.resumeWaitDeadline==nil
    and rec.recoveryIntent.resumeTravelDeadline==1900 and poseCalls==0)
arriveSaved(102)
rebound("actual_decide_reacquires_fresh_place_at_arrival",not agent.recoveryRoute and agent.recovery
    and rec.recoveryIntent.status=="preparing" and rec.recoveryIntent.place.key=="bed:new-runtime-object" and poseCalls==1)
rebound("fresh_key_preserves_prior_source_without_identity_claim",rec.recoveryIntent.resumePlaceSource.priorKey=="bed:exact"
    and rec.recoveryIntent.resumePlaceSource.currentKey=="bed:new-runtime-object"
    and rec.recoveryIntent.resumePlaceSource.persistentObjectIdentity==false
    and rec.recoveryIntent.resumeWaitStartedAt==102 and rec.recoveryIntent.resumeWaitDeadline==222
    and rec.recoveryIntent.resumeTravelStartedAt==100 and rec.recoveryIntent.resumeTravelDeadline==1900
    and not agent.sleeping and not rec.recoveryExperiences)
freshRoute();rec.recoveryIntent.resumeWaitStartedAt=100;rec.recoveryIntent.resumeWaitDeadline=220
retrySaved();state="WalkTowardState";arriveSaved(219)
rebound("arrival_native_idle_wait_keeps_route_deadline",agent.recoveryAdmission and not agent.recoveryRoute
    and agent.recoveryAdmission.place.key=="bed:new-runtime-object" and agent.recoveryAdmission.deadline==220
    and poseCalls==0 and not agent.recovery and not rec.recoveryExperiences)
rebound("arrival_wait_cannot_refresh_original_window",not Ctl.updateRecovery("runner",agent,body,220,needs,false)
    and not rec.recoveryIntent and not agent.recoveryAdmission and poseCalls==0)
freshSaved();state="IdleState";nativePlaces[1].key="bed:new-runtime-object"
rebound("normal_exact_place_check_stays_strict",not SAO.Needs.recoveryPlaceAt("runner",body,rec.recoveryIntent.place))
rebound("preparing_only_observed_tuple_supplies_new_key",retrySaved() and rec.recoveryIntent.place.key=="bed:new-runtime-object"
    and rec.recoveryIntent.resumePlaceSource.priorKey=="bed:exact")
freshRoute();retrySaved();body.x,body.y=0,0;nativePlaces={bed(0,0)};nativePlaces[1].objectIndex=9
agent.recoveryRoute.job.done,agent.recoveryRoute.job.result=true,"arrived"
rebound("changed_object_tuple_cannot_rebind",not Ctl.updateRecovery("runner",agent,body,102,needs,false)
    and not rec.recoveryIntent and poseCalls==0)
freshRoute();retrySaved();body.x,body.y=0,0;agent.recoveryRoute.job.done=true;agent.recoveryRoute.job.result="arrived"
rebound("unobserved_bed_at_arrival_grants_nothing",not Ctl.updateRecovery("runner",agent,body,102,needs,false)
    and not rec.recoveryIntent and poseCalls==0)
freshRoute();rec.recoveryIntent.resumeWaitStartedAt=100;rec.recoveryIntent.resumeWaitDeadline=220
retrySaved()
rebound("original_deadline_expires_during_travel",not Ctl.updateRecovery("runner",agent,body,220,needs,false)
    and not rec.recoveryIntent and not agent.recoveryRoute and poseCalls==0)
freshRoute();retrySaved();local foreignJob={body=body,done=false,goal={x=0,y=0,z=0}}
SAO.Locomotion.jobs.runner=foreignJob
rebound("replaced_job_preserves_foreign_movement",not Ctl.updateRecovery("runner",agent,body,101,needs,false)
    and SAO.Locomotion.jobs.runner==foreignJob and not rec.recoveryIntent and poseCalls==0)
freshRoute();retrySaved();local guardedRoute,guardedIntent=agent.recoveryRoute,rec.recoveryIntent
rebound("foreign_receiver_does_not_consume_existing_route",not Ctl.updateRecovery("runner",agent,{},101,needs,false)
    and agent.recoveryRoute==guardedRoute and rec.recoveryIntent==guardedIntent
    and SAO.Locomotion.jobs.runner==guardedRoute.job and poseCalls==0)
rebound("foreign_finish_does_not_consume_existing_route",not Ctl.finishRecoveryPlaceMovement("runner",agent,{})
    and agent.recoveryRoute==guardedRoute and rec.recoveryIntent==guardedIntent and poseCalls==0)
freshRoute();retrySaved();rec.worldSourceReservation={id="new-source-owner"}
rebound("new_reservation_interrupts_route_without_stealing_work",not Ctl.updateRecovery("runner",agent,body,101,needs,false)
    and rec.worldSourceReservation.id=="new-source-owner" and not rec.recoveryIntent and poseCalls==0)
freshRoute();retrySaved();local changedGoal=agent.recoveryRoute.job
changedGoal.goal={x=5,y=5,z=0}
rebound("changed_goal_is_not_cancelled_or_used",not Ctl.updateRecovery("runner",agent,body,101,needs,false)
    and SAO.Locomotion.jobs.runner==changedGoal and not rec.recoveryIntent and poseCalls==0)
freshRoute();retrySaved();SAOJavaBridge.setForceEntry=function()return false end
rebound("entry_permission_rechecked_during_route",not Ctl.updateRecovery("runner",agent,body,101,needs,false)
    and not rec.recoveryIntent and poseCalls==0)
freshRoute();retrySaved()
rebound("new_threat_cancels_exact_route",not Ctl.updateRecovery("runner",agent,body,101,needs,true)
    and not rec.recoveryIntent and not agent.recoveryRoute and poseCalls==0)
freshRoute();retrySaved();permission=false
rebound("standing_changed_during_travel_refuses",not Ctl.updateRecovery("runner",agent,body,101,needs,false)
    and not rec.recoveryIntent and poseCalls==0)
freshRoute();retrySaved();needs.thirst=.99
rebound("urgent_need_changed_during_travel_refuses",not Ctl.updateRecovery("runner",agent,body,101,needs,false)
    and not rec.recoveryIntent and poseCalls==0)
freshRoute();retrySaved();rec.bodyOwnerToken="new-owner"
rebound("changed_body_token_cannot_continue_route",not Ctl.updateRecovery("runner",agent,body,101,needs,false)
    and not agent.recoveryRoute and poseCalls==0 and __cancels==0)
freshRoute();retrySaved();local superseding={kind="sleep",status="preparing",place=bed(0,0)}
rec.recoveryIntent=superseding
rebound("superseded_choice_remains_untouched",not Ctl.updateRecovery("runner",agent,body,101,needs,false)
    and rec.recoveryIntent==superseding and poseCalls==0)
freshRoute();SAOJavaBridge.setForceEntry=function()return false end
rebound("fresh_native_entry_permission_refused",not retrySaved() and not rec.recoveryIntent
    and not agent.recoveryRoute and poseCalls==0)
freshRoute();local held=rec.recoveryIntent
rebound("foreign_receiver_cannot_start_or_clear_route",not Ctl.resumePreparingRecovery("runner",agent,{},100,needs,false)
    and rec.recoveryIntent==held and not agent.recoveryRoute and poseCalls==0)
freshRoute();rec.recoveryIntent.resumeWaitStartedAt=100;rec.recoveryIntent.resumeWaitDeadline=220
rebound("reloaded_travel_uses_retained_deadline",retrySaved(219) and agent.recoveryRoute.deadline==2019 and rec.recoveryIntent.resumeWaitDeadline==220
    and not Ctl.updateRecovery("runner",agent,body,220,needs,false) and not rec.recoveryIntent)
freshRoute();retrySaved();local frozenRoute=__nativeRoundtrip(rec)
rebound("route_runtime_handles_are_not_persisted",frozenRoute.recoveryIntent.place.key=="bed:exact"
    and frozenRoute.recoveryIntent.resumeWaitDeadline==nil and frozenRoute.recoveryIntent.resumeTravelDeadline==1900
    and frozenRoute.recoveryIntent.body==nil
    and frozenRoute.recoveryIntent.custody==nil and frozenRoute.recoveryIntent.job==nil)
__result="PASS recovery admission "..pendingChecks.."; preparing "..preparingChecks.."; rebind "..reboundChecks
    .."; budgets "..budgetChecks.."; placement "..placementChecks.."; concepts "..conceptChecks.."; ordinary "..checks
