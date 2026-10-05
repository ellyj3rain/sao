-- Appended to the ordinary and conceptual fixtures. Geometry itself is native-
-- probed separately; these scalar offers control the real Lua owner handoff.
local placementChecks=0
local function placed(name,value)
    if not value then error("PLACEMENT:"..name) end
    placementChecks=placementChecks+1
end
local nativePlaces,selectedPlace,poseWork
local controlledBegin=SAO.Needs.beginRecovery
local function ground(x,y)
    return {key="ground:"..x..":"..y,kind="ground",available=true,x=x,y=y,z=0}
end
local function bed(x,y)
    return {key="bed:exact",kind="bed",available=true,x=x,y=y,z=0,
        objectX=x+1,objectY=y,objectZ=0,objectIndex=2}
end
local function freshPlacement()
    freshConcepts();SAO.Needs.resetRecoveries("world-reset")
    SAO.Needs.beginRecovery=function(id,b,kind,place)
        selectedPlace=place;return controlledBegin(id,b,kind,place)
    end
    selectedPlace=nil;poseWork=nil;nativePlaces={}
    body.x,body.y,body.z=0,0,0
    body.getX=function(self)return self.x end
    body.getY=function(self)return self.y end
    body.getZ=function(self)return self.z end
    body.getCurrentStateName=function()return "IdleState" end
    body.isClimbing=function()return false end
    SAOJavaBridge.recoveryPlaces=function()
        return {actorId="runner",status="available",places=nativePlaces}
    end
end
local function offerPlace(kind)
    return Ctl.offerRecovery("runner",agent,body,100,needs,kind or "sleep")
end
local function arrive()
    local job=SAO.Locomotion.jobs.runner
    body.x,body.y,body.z=job.goal.x,job.goal.y,job.goal.z
    job.done,job.result=true,"arrived"
    return Ctl.finishRecoveryPlaceMovement("runner",agent,body)
end
freshPlacement();nativePlaces={ground(0,0),bed(3.5,.5)}
placed("bed_precedes_nearby_floor",offerPlace() and agent.state=="TRAVEL" and __ordered.x==3.5
    and rec.recoveryPlacement.place.kind=="bed" and admitted==nil)
placed("choice_and_route_grant_no_sleep",not agent.sleeping and not rec.recoveryIntent and not rec.recoveryExperiences)
placed("exact_arrival_admits_selected_bed",arrive() and admitted=="sleep" and selectedPlace.kind=="bed"
    and agent.recovery and rec.recoveryPlacement.status=="preparing")
freshPlacement();nativePlaces={bed(3.5,.5)}
agent.state="FOLLOW";SAO.Locomotion.order("runner",body,3,.5,0)
placed("nearby_old_goal_is_replaced_exactly",offerPlace() and __starts==2 and __cancels==1
    and SAO.Locomotion.jobs.runner.goal.x==3.5 and agent.recoveryRoute.job==SAO.Locomotion.jobs.runner)
freshPlacement();nativePlaces={bed(3.5,.5)}
agent.state="FOLLOW";SAO.Locomotion.order("runner",body,3,.5,0);body.isClimbing=function()return true end
placed("native_crossing_is_not_cancelled_for_place",not offerPlace() and __starts==1 and __cancels==0)
freshPlacement();nativePlaces={bed(3.5,.5)}
agent.state="FOLLOW";SAO.Locomotion.order("runner",body,3,.5,0)
SAO.Locomotion.jobs.runner.lastVerdict="Transition:STARTED_WINDOW_CLIMB"
placed("pending_crossing_is_not_cancelled_for_place",not offerPlace() and __starts==1 and __cancels==0)
freshPlacement();nativePlaces={bed(3.5,.5)}
agent.state="FOLLOW";SAO.Locomotion.order("runner",body,3,.5,0)
body.getCurrentStateName=function()return "PlayerOpenWindowState" end
placed("native_window_action_is_not_cancelled_for_place",not offerPlace() and __starts==1 and __cancels==0)
freshPlacement();nativePlaces={bed(3.5,.5)}
agent.state="FOLLOW";SAO.Locomotion.order("runner",body,3,.5,0)
SAOJavaBridge.setForceEntry=function()return false end
placed("refused_native_admission_keeps_existing_route",not offerPlace() and __starts==1 and __cancels==0)
freshPlacement();nativePlaces={ground(2.5,2.5)}
placed("clear_ground_requires_route_off_current_tile",offerPlace() and agent.recoveryRoute and __ordered.x==2.5 and admitted==nil)
placed("ground_fallback_reason_is_retained",rec.recoveryPlacement.reason:find("no presently admissible bed",1,true)~=nil)
placed("ground_arrival_uses_existing_owner",arrive() and admitted=="sleep" and selectedPlace.kind=="ground")
freshPlacement();observe()
local beforeGoal=P.planConceptInquiry("runner",P.conceptInquiryOffer("runner","relief-from-tiredness",100),100)
placed("no_place_refuses_arbitrary_floor",offerPlace() and not admitted and not agent.sleeping
    and rec.recoveryPlacement.status=="unresolved" and agent.inquiryRoute)
placed("failed_placement_preserves_inquiry",beforeGoal.inquiry.goal=="relief-from-tiredness" and beforeGoal.status~="completed")
freshPlacement();nativePlaces={bed(3.5,.5)};offerPlace();nativePlaces={}
placed("withdrawn_place_cannot_start_at_arrival",arrive() and not admitted and rec.recoveryPlacement.status=="unresolved")
placed("failed_place_is_temporarily_deferred",agent.recoveryPlaceRetry[SAO.Needs.recoveryApproachKey(bed(3.5,.5))]>100)
freshPlacement();nativePlaces={bed(3.5,.5)};offerPlace();permission=false
placed("standing_change_refuses_arrival",arrive() and not admitted)
freshPlacement();nativePlaces={bed(3.5,.5)};offerPlace()
local oldJob=SAO.Locomotion.jobs.runner
body.x,body.y=oldJob.goal.x,oldJob.goal.y
SAO.Locomotion.jobs.runner={body=body,done=true,result="arrived",goal=oldJob.goal}
placed("replacement_job_cannot_admit",not Ctl.finishRecoveryPlaceMovement("runner",agent,body)
    and not admitted and rec.recoveryPlacement.status=="interrupted")
freshPlacement();nativePlaces={bed(3.5,.5)};offerPlace();rec.bodyOwnerToken="new-owner"
placed("stale_owner_cannot_admit",not Ctl.finishRecoveryPlaceMovement("runner",agent,body) and not admitted)
freshPlacement();nativePlaces={bed(3.5,.5)};offerPlace()
nativePlaces[1]=bed(3.5,.5);nativePlaces[1].objectIndex=3
placed("changed_bed_object_cannot_inherit_target",arrive() and not admitted)
freshPlacement();nativePlaces={bed(3.5,.5)};offerPlace()
local wrongArrival=SAO.Locomotion.jobs.runner;wrongArrival.done=true;wrongArrival.result="arrived"
placed("route_receipt_needs_physical_arrival",Ctl.finishRecoveryPlaceMovement("runner",agent,body) and not admitted)
freshPlacement();nativePlaces={bed(3.5,.5)};offerPlace()
Ctl.__inspectionProbeState(agent,"runner","FLEE","new danger")
placed("interruption_preserves_selected_place",not agent.recoveryRoute and rec.recoveryPlacement.status=="interrupted"
    and rec.recoveryPlacement.place.key=="bed:exact" and not admitted)
freshPlacement();nativePlaces={bed(3.5,.5)};offerPlace();Ctl.drop("runner")
placed("drop_retains_unfinished_placement",rec.recoveryPlacement.status=="interrupted" and rec.recoveryPlacement.place.key=="bed:exact")
agent={rec=rec,state="IDLE"};Ctl.agents.runner=agent
placed("new_owner_reselects_fresh_place",offerPlace() and agent.recoveryRoute and not admitted)
freshPlacement()
GameTime={getInstance=function()return {getTimeOfDay=function()return 23 end}end}
body.setSitOnGround=function()end
local nativeSleepCalls=0
SAOJavaBridge.setShellAsleep=function(_,b,value)if value then nativeSleepCalls=nativeSleepCalls+1 end end
placed("night_requires_suitable_place",not Ctl.__placementNight("runner",agent,body,100,rec)
    and not agent.sleeping and not agent.resting and nativeSleepCalls==0 and not admitted)
nativePlaces={bed(3.5,.5)}
placed("night_uses_same_selected_place_route",Ctl.__placementNight("runner",agent,body,100,rec)
    and agent.recoveryRoute and rec.recoveryPlacement.place.kind=="bed" and nativeSleepCalls==0)
GameTime=nil
freshPlacement();nativePlaces={ground(0,0)}
SAO.Needs.beginRecovery=__actualBeginRecovery
SAO.RecoveryPose={begin=function(b,kind,id,place)
    selectedPlace=place;poseWork={body=b,kind=kind,id=id,place=place};return poseWork
end,observed=function()return true end,captureCustody=function(b)return {body=b,rec=rec,id="runner"}end,
cancel=function(work)poseWork=work;return true,"fixture-owned-exit"end,retire=function()end}
placed("native_owner_requires_explicit_place",not SAO.Needs.beginRecovery("runner",body,"sleep"))
placed("native_owner_forwards_and_retains_place",SAO.Needs.beginRecovery("runner",body,"sleep",nativePlaces[1])
    and selectedPlace.kind=="ground" and rec.recoveryIntent.place.key==nativePlaces[1].key
    and rec.recoveryIntent.status=="preparing")
SAO.Needs.stopRecovery("runner",body,"fixture-complete")
-- On reload a bed-bound physiological action must retain exactly that native
-- furniture pointer for cancellation, without rechecking pre-entry coordinates.
freshPlacement();SAO.Needs.beginRecovery=__actualBeginRecovery
local retainedBed=bed(3.5,.5)
local furniture={getObjectIndex=function()return 2 end,getX=function()return 4.5 end,
    getY=function()return .5 end,getZ=function()return 0 end}
body.isAsleep=function()return true end;body.isOnBed=function()return true end
body.getBed=function()return furniture end;body.getSitOnFurnitureObject=function()return furniture end
rec.recoveryIntent={kind="sleep",status="paused",place=retainedBed}
placed("bed_reload_retains_exact_native_binding",SAO.Needs.resumeRecovery("runner",body)
    and SAO.Needs.recoveryActive("runner",body))
SAO.Needs.stopRecovery("runner",body,"interrupted")
placed("bed_reload_cancellation_receives_exact_bed",poseWork and poseWork.bed==furniture)
rec.recoveryIntent={kind="sleep",status="paused",place=retainedBed}
body.getSitOnFurnitureObject=function()return {} end
placed("bed_reload_rejects_replaced_furniture",not SAO.Needs.resumeRecovery("runner",body) and not rec.recoveryIntent)
body.getSitOnFurnitureObject=function()return furniture end
rec.recoveryIntent={kind="sleep",status="paused",place=retainedBed}
SAO.RecoveryPose.observed=function()return false end
placed("bed_reacknowledgment_retains_binding",SAO.Needs.resumeRecovery("runner",body))
body.getBed=function()return {} end
placed("bed_swap_before_reacknowledgment_refuses_credit",SAO.Needs.pollRecovery("runner",body)=="failed"
    and not rec.recoveryIntent and not rec.recoveryExperiences)
body.getBed=function()return furniture end
rec.recoveryIntent={kind="sleep",status="paused",place=retainedBed}
SAO.RecoveryPose.observed=function()return true end
SAO.Needs.resumeRecovery("runner",body)
furniture.getObjectIndex=function()return -1 end
placed("removed_active_bed_refuses_measured_credit",SAO.Needs.pollRecovery("runner",body)=="failed"
    and not rec.recoveryIntent and not rec.recoveryExperiences)
SAO.Needs.beginRecovery=controlledBegin
-- A doorway is a directional frontier. Entering an unhelpful room must leave
-- a route back; an untried door takes precedence over that return route.
freshConcepts();observe();act()
local firstPurpose=P.pending("runner","investigate")
local firstRoute=SAO.Locomotion.jobs.runner;firstRoute.done=true;firstRoute.result="arrived"
Ctl.finishConceptInquiryMovement("runner",agent,body)
view.observations[1].roomId="room:B";view.observations[1].key="room:B"
view.frontiers[1].roomId="room:B";view.frontiers[1].entryX=0;observe()
local back=P.conceptInquiryOffer("runner","relief-from-tiredness",100)
placed("return_through_same_door_is_available",back.status=="actionable" and back.backtracking and back.frontier.entryX==0)
view.frontiers[2]={key="door:C",kind="doorway",roomId="room:B",buildingId="house:A",x=2,y=0,z=0,entryX=3,entryY=0,entryZ=0,state="open"};observe()
local onward=P.conceptInquiryOffer("runner","relief-from-tiredness",100)
placed("untried_door_precedes_backtracking",onward.frontier.key=="door:C" and not onward.backtracking)
agent.state="IDLE"
placed("actual_controller_tries_untried_branch",act()=="inquiry" and __ordered.x==3)
local blockedBranch=SAO.Locomotion.jobs.runner;blockedBranch.done=true;blockedBranch.result="blocked"
Ctl.finishConceptInquiryMovement("runner",agent,body)
view.frontiers[2]=nil;observe();agent.state="IDLE"
local returning=act()
placed("actual_controller_dispatches_return_route",returning=="inquiry" and __ordered.x==0)
local backRoute=SAO.Locomotion.jobs.runner;backRoute.done=true;backRoute.result="arrived"
Ctl.finishConceptInquiryMovement("runner",agent,body)
view.observations[1].roomId="room:A";view.observations[1].key="room:A"
view.frontiers[1].roomId="room:A";view.frontiers[1].entryX=2
view.frontiers[2]={key="door:D",kind="doorway",roomId="room:A",buildingId="house:A",x=0,y=2,z=0,entryX=0,entryY=3,entryZ=0,state="open"};observe()
placed("return_exposes_other_untried_branch",P.conceptInquiryOffer("runner","relief-from-tiredness",100).frontier.key=="door:D")
agent.state="IDLE";act()
local lastBranch=SAO.Locomotion.jobs.runner;lastBranch.done=true;lastBranch.result="blocked"
Ctl.finishConceptInquiryMovement("runner",agent,body)
view.frontiers[2]=nil;observe()
placed("each_directed_edge_is_bounded",P.conceptInquiryOffer("runner","relief-from-tiredness",100).status=="unresolved"
    and firstPurpose.inquiry.attempts["door:A@room:A"] and firstPurpose.inquiry.attempts["door:A@room:B"])
placed("backtracking_never_establishes_absence",K.infer("runner","room","bed","house:A").status=="expectation")
freshConcepts();observe();local staleOffer=P.conceptInquiryOffer("runner","relief-from-tiredness",100)
view.observations[1].roomId="room:B";view.observations[1].key="room:B";view.frontiers[1].roomId="room:B";observe()
placed("stale_frontier_direction_refused",P.planConceptInquiry("runner",staleOffer,100)==nil)
-- Query diagnostics distinguish lack of native admission from an empty set.
freshPlacement();nativePlaces={ground(0,0)}
local reportSource={schema="sao.recovery-place-diagnostics/1",bodyAdmission="accepted",visibleBedParts=4,
    nativeAsleep=false,nativeOnBed=false,visibleSquares=18,hiddenWorld={secret=true},
    bedRejections={{key="seen-bed",sprite="visible-sprite",reason="no-clear-approach",facing="E",gridWidth=2,gridHeight=2,
        approachRejectedVisibility=1,approachRejectedClearance=2,approachRejectedBoundary=0,privateContents="unknown"}}}
SAOJavaBridge.recoveryPlaces=function()return {actorId="runner",status="available",places=nativePlaces,diagnostics=reportSource}end
placed("diagnostic_intake_preserves_selection",#SAO.Needs.recoveryPlaces("runner",body)==1
    and rec.recoveryPlaceObservation.status=="available" and rec.recoveryPlaceObservation.acceptedCount==1)
local report=rec.recoveryPlaceObservation
placed("diagnostics_keep_query_position",report.x==body:getX() and report.requestedRadius==8 and report.atHours==hours)
placed("diagnostics_keep_visible_rejection_reason",report.diagnostics.visibleBedParts==4
    and report.diagnostics.bedRejections[1].reason=="no-clear-approach" and report.diagnostics.nativeAsleep==false)
placed("diagnostics_only_copy_whitelisted_scalars",not report.diagnostics.hiddenWorld
    and not report.diagnostics.bedRejections[1].privateContents)
reportSource.bedRejections[1].reason="changed";reportSource.visibleBedParts=8
placed("diagnostics_are_detached",report.diagnostics.visibleBedParts==4 and report.diagnostics.bedRejections[1].reason=="no-clear-approach")
SAOJavaBridge.recoveryPlaces=function()return {actorId="runner",status="available",places={}}end
placed("empty_available_is_distinct",#SAO.Needs.recoveryPlaces("runner",body)==0 and rec.recoveryPlaceObservation.status=="available"
    and rec.recoveryPlaceObservation.acceptedCount==0)
SAOJavaBridge.recoveryPlaces=function()return nil end
SAO.Needs.recoveryPlaces("runner",body)
placed("unavailable_reader_is_distinct",rec.recoveryPlaceObservation.status=="unavailable")
SAOJavaBridge.recoveryPlaces=function()error("controlled native failure")end
SAO.Needs.recoveryPlaces("runner",body)
placed("query_error_distinguished",rec.recoveryPlaceObservation.status=="error" and rec.recoveryPlaceObservation.reason=="native-query-error")
SAOJavaBridge.recoveryPlaces=function()return {actorId="other",status="available",places={ground(0,0)}}end
placed("foreign_result_cannot_supply_places",#SAO.Needs.recoveryPlaces("runner",body)==0 and rec.recoveryPlaceObservation.reason=="native-result-invalid")
local lastReport=rec.recoveryPlaceObservation
SAOJavaBridge.recoveryPlaces=function()rec.bodyOwnerToken="changed";return {actorId="runner",status="available",places={}}end
placed("query_owner_change_does_not_write_report",#SAO.Needs.recoveryPlaces("runner",body)==0 and rec.recoveryPlaceObservation==lastReport)
-- The retained object is twenty tiles away. Only its personally occupied room
-- anchor supplies a destination; arrival causes observation, never native use.
local function rememberedMeans(concept)
    freshPlacement();object(concept);observe()
    body.x,body.y=20,0
    view.observations={{key="room:B",kind="room",concept="room",roomId="room:B",buildingId="house:A",x=20,y=0,z=0}}
    view.frontiers={};observe()
    SAO.Standing.insideClaim=function()return false end
end
rememberedMeans("bed")
local remembered=P.conceptInquiryOffer("runner","relief-from-tiredness",100)
placed("remembered_means_supplies_occupied_approach",remembered.status=="actionable" and remembered.mode=="remembered-means"
    and remembered.observedMeans.y==1 and remembered.approach.x==0 and remembered.approach.y==0)
placed("memory_query_does_not_create_purpose",rec.proceduralPlanning==nil)
placed("away_from_home_choice_approaches_memory",act()=="inquiry" and __ordered.x==0 and __ordered.y==0
    and agent.inquiryRoute and not admitted)
local rememberedPurpose=P.pending("runner","investigate")
placed("retained_purpose_keeps_observed_means",rememberedPurpose.inquiry.mode=="remembered-means"
    and rememberedPurpose.inquiry.observedMeans.concept=="bed")
local memoryJob=SAO.Locomotion.jobs.runner;body.x,body.y=0,0;memoryJob.done=true;memoryJob.result="arrived"
view.observations={{key="room:A",kind="room",concept="room",roomId="room:A",buildingId="house:A",x=0,y=0,z=0}}
object("bed");SAO.Standing.insideClaim=function()return permission end
placed("memory_arrival_is_observation_not_use",Ctl.finishConceptInquiryMovement("runner",agent,body)
    and Per.conceptObservation("runner","object:bed").at==100 and not admitted and not agent.recovery)
placed("memory_arrival_native_refusal_remains_unresolved",not offerPlace() and not admitted and rec.recoveryPlacement.status=="unresolved")
nativePlaces={bed(3.5,.5)}
placed("fresh_native_offer_after_memory_supplies_exact_route",offerPlace() and agent.recoveryRoute and __ordered.x==3.5)
placed("only_fresh_native_arrival_admits_memory_bed",arrive() and selectedPlace.kind=="bed" and admitted=="sleep")
rememberedMeans("seat");needs.fatigue=.2;needs.endurance=.25
placed("same_memory_mechanism_supports_other_effect",act()=="inquiry"
    and P.pending("runner","investigate").inquiry.goal=="relief-from-exertion")
rememberedMeans("bed");needs.fatigue=1
placed("extreme_recovery_uses_same_memory_consumer",offerPlace() and agent.inquiryRoute and not admitted)
rememberedMeans("bed")
Per.beliefs.runner.concepts.observations["room:A"]=nil
for index=#Per.beliefs.runner.concepts.order,1,-1 do
    if Per.beliefs.runner.concepts.order[index]=="room:A" then table.remove(Per.beliefs.runner.concepts.order,index) end
end
placed("no_occupied_anchor_never_invents_approach",P.conceptInquiryOffer("runner","relief-from-tiredness",100).status=="unresolved")
rememberedMeans("bed")
Per.beliefs.runner.concepts.observations["object:bed"].actorId="other"
placed("foreign_memory_does_not_supply_approach",P.conceptInquiryOffer("runner","relief-from-tiredness",100).status=="unresolved")
rememberedMeans("bed");local priorMemory=P.conceptInquiryOffer("runner","relief-from-tiredness",100)
retainedEdge("bed","sleep","house:A",false,"affords")
placed("contrary_relation_revokes_memory_route",P.planConceptInquiry("runner",priorMemory,100)==nil)
rememberedMeans("bed");permission=false
placed("memory_never_grants_entry_permission",act()=="inquiry" and not agent.inquiryRoute and not admitted and __starts==0)
rememberedMeans("bed")
local availableBefore=SAO.Needs.workAvailable
SAO.Needs.workAvailable=function()return false end
placed("remembered_means_respects_native_work_admission",act()=="inquiry" and not agent.inquiryRoute and not admitted and __starts==0)
SAO.Needs.workAvailable=availableBefore
rememberedMeans("bed");act()
local interruptedMemory=P.pending("runner","investigate")
Ctl.__inspectionProbeState(agent,"runner","FLEE","new danger")
placed("interruption_keeps_memory_intention",interruptedMemory.status=="interrupted" and interruptedMemory.inquiry.approach
    and interruptedMemory.inquiry.observedMeans and not interruptedMemory.admission)
Ctl.drop("runner")
agent={rec=rec,state="IDLE"};Ctl.agents.runner=agent
placed("reload_reconsiders_memory_without_granting_use",act()=="inquiry" and agent.inquiryRoute and not admitted
    and P.pending("runner","investigate").id==interruptedMemory.id)
rememberedMeans("bed")
local boundedMemory=P.planConceptInquiry("runner",P.conceptInquiryOffer("runner","relief-from-tiredness",100),100)
for i=1,12 do boundedMemory.inquiry.attempts["used:"..i]={status="approached"} end
view.observations={};observe()
placed("exhausted_remembered_search_is_distinct_from_no_association",P.conceptInquiryOffer("runner","relief-from-tiredness",100).limitReached==true)
SAO.Standing.insideClaim=function()return permission end
do
    local goal="relief-from-tiredness"
    local function failedVisibleBed()
        freshPlacement();object("bed")
        view.observations[#view.observations].recoverySourceId="bed:refused"
        view.observations[#view.observations+1]={key="object:foot",concept="bed",kind="object",
            recoverySourceId="bed:refused",buildingId="house:A",roomId="room:A",x=0,y=2,z=0}
        observe()
        nativePlaces={{key="bed:refused",kind="bed",x=.5,y=1.5,z=0,
            available=false,reason="native-bed-approach-unavailable"}}
    end
    failedVisibleBed()
    placed("failed_bed_does_not_complete_or_rewrite_association",P.conceptInquiryOffer("runner",goal,100).status=="observed-means"
        and not rec.proceduralPlanning and not rec.recoveryExperiences)
    placed("failed_visible_means_reopens_actual_inquiry",offerPlace() and agent.inquiryRoute
        and __ordered.x==2 and not admitted and not agent.recovery)
    local excluded,failure=P.meansUnavailable("runner",goal,"bed:refused")
    placed("failure_keeps_exact_native_provenance",excluded and failure.actorId=="runner"
        and failure.owner=="SAO.Needs" and failure.reason=="native-bed-approach-unavailable"
        and failure.sourceId=="bed:refused" and failure.scope=="geometry")
    placed("both_visible_parts_share_one_failed_means",P.conceptInquiryOffer("runner",goal,100).status=="actionable"
        and #rec.proceduralPlanning.meansFailureOrder==1)
    placed("failed_use_does_not_disprove_general_relation",K.infer("runner","bed",goal).status=="expectation"
        and not rec.recoveryExperiences)
    failure.goal="forged";failure.retryAtHours=0
    placed("failure_projection_detached",P.meansUnavailable("runner",goal,"bed:refused"))
    placed("unknown_source_is_not_excluded",not P.meansUnavailable("runner",goal,"bed:another"))
    placed("other_goal_is_not_excluded",not P.meansUnavailable("runner","relief-from-exertion","bed:refused"))
    placed("invented_receipt_cannot_exclude_means",not P.meansResult("runner","SAO.Needs",999999))
    placed("replayed_receipt_is_not_new_evidence",not P.meansResult("runner","SAO.Needs",rec.recoveryMeansSequence))
    local saved=rec.proceduralPlanning
    local savedPurpose=P.pending("runner","investigate")
    Ctl.drop("runner");agent={rec=rec,state="IDLE"};Ctl.agents.runner=agent
    placed("reload_retains_failure_and_inquiry_question",P.meansUnavailable("runner",goal,"bed:refused")
        and P.pending("runner","investigate").id==savedPurpose.id and not savedPurpose.admission)
    local beforeSerialization=rec
    local restored=__nativeRoundtrip({record=rec,belief=Per.beliefs.runner})
    rec=restored.record;agent.rec=rec;Per.beliefs.runner=restored.belief
    placed("native_serialization_keeps_exact_failure",P.meansUnavailable("runner",goal,"bed:refused")
        and rec~=beforeSerialization and P.pending("runner","investigate").id==savedPurpose.id)
    placed("restored_private_question_reaches_actual_route",offerPlace() and agent.inquiryRoute and __ordered.x==2
        and not admitted and not rec.recoveryExperiences)
    local ownGet=SAO.Identity.get
    SAO.Identity.get=function(id)if id=="other" then return {id="other",proceduralPlanning=saved} end return ownGet(id) end
    placed("foreign_failure_does_not_transfer",not P.meansUnavailable("other",goal,"bed:refused"))
    SAO.Identity.get=ownGet
    hours=hours+601/9000
    placed("failure_retry_uses_persisted_county_clock",not P.meansUnavailable("runner",goal,"bed:refused"))
    failedVisibleBed();SAO.Needs.recoveryPlaces("runner",body)
    local changed=bed(3.5,.5);changed.key="bed:refused";nativePlaces={changed}
    SAO.Needs.recoveryPlaces("runner",body)
    placed("changed_native_geometry_reopens_exact_means",not P.meansUnavailable("runner",goal,"bed:refused")
        and P.conceptInquiryOffer("runner",goal,100).status=="observed-means")
    failedVisibleBed();SAO.Needs.recoveryPlaces("runner",body)
    view.observations[2].recoverySourceId="bed:replacement";view.observations[3].recoverySourceId="bed:replacement";observe()
    placed("replacement_object_does_not_inherit_failure",P.conceptInquiryOffer("runner",goal,100).status=="observed-means")
    failedVisibleBed();nativePlaces[#nativePlaces+1]=bed(3.5,.5)
    placed("other_visible_bed_reaches_native_route",offerPlace() and agent.recoveryRoute
        and agent.recoveryRoute.place.key=="bed:exact" and __ordered.x==3.5 and not agent.inquiryRoute)
    placed("other_visible_bed_admits_after_exact_arrival",arrive() and admitted=="sleep")
    -- Visit B first; later A contains a refused source. A's refusal cannot
    -- consume B's private remembered means or substitute B's object tile.
    freshPlacement();body.x,body.y=10,0
    view.observations={{key="room:B",kind="room",concept="room",roomId="room:B",buildingId="house:A",x=10,y=0,z=0},
        {key="object:known-bed",kind="object",concept="bed",recoverySourceId="bed:known",roomId="room:B",buildingId="house:A",x=11,y=1,z=0}}
    observe();body.x,body.y=0,0
    view.observations={{key="room:A",kind="room",concept="room",roomId="room:A",buildingId="house:A",x=0,y=0,z=0},
        {key="object:blocked-bed",kind="object",concept="bed",recoverySourceId="bed:refused",roomId="room:A",buildingId="house:A",x=0,y=1,z=0}}
    observe();nativePlaces={{key="bed:refused",kind="bed",available=false,reason="native-bed-approach-unavailable",x=.5,y=1.5,z=0}}
    placed("failed_visible_bed_preserves_known_other_bed",offerPlace() and agent.inquiryRoute
        and __ordered.x==10 and __ordered.y==0 and not admitted
        and P.pending("runner","investigate").inquiry.observedMeans.key=="object:known-bed")
    failedVisibleBed();permission=false
    placed("failure_never_grants_search_permission",not offerPlace() and not agent.inquiryRoute and not admitted)
    failedVisibleBed();SAOJavaBridge.recoveryPlaces=function()return {actorId="other",status="available",places=nativePlaces}end
    SAO.Needs.recoveryPlaces("runner",body)
    placed("foreign_native_refusal_is_not_evidence",not P.meansUnavailable("runner",goal,"bed:refused"))
    failedVisibleBed();SAOJavaBridge.recoveryPlaces=function()return nil end
    SAO.Needs.recoveryPlaces("runner",body)
    placed("missing_reader_is_not_failed_furniture",not P.meansUnavailable("runner",goal,"bed:refused"))
    failedVisibleBed();nativePlaces={bed(3.5,.5)};nativePlaces[1].key="bed:refused"
    placed("real_approach_precedes_failed_route",offerPlace() and agent.recoveryRoute)
    local binding=agent.recoveryRoute;local job=SAO.Locomotion.jobs.runner
    job.done=true;job.result="blocked"
    placed("actual_failed_route_feeds_exact_means",Ctl.finishRecoveryPlaceMovement("runner",agent,body)
        and SAO.Needs.recoveryMeansUnavailable("runner","sleep",binding.place))
    SAO.Needs.recoveryPlaces("runner",body)
    placed("visible_geometry_cannot_erase_failed_route",SAO.Needs.recoveryMeansUnavailable("runner","sleep",binding.place))
    local changedApproach=bed(4.5,.5);changedApproach.key=binding.place.key
    placed("failed_route_does_not_exclude_new_exact_approach",not SAO.Needs.recoveryMeansUnavailable("runner","sleep",changedApproach))
    nativePlaces={changedApproach}
    placed("changed_approach_reaches_actual_controller_route",offerPlace("sleep") and agent.recoveryRoute
        and __ordered.x==4.5 and not agent.inquiryRoute and not admitted)
    local changedJob=SAO.Locomotion.jobs.runner;changedJob.done=true;changedJob.result="blocked"
    Ctl.finishRecoveryPlaceMovement("runner",agent,body);nativePlaces={binding.place}
    placed("failed_route_reopens_actual_search",offerPlace("sleep") and agent.inquiryRoute and __ordered.x==2)
    failedVisibleBed();nativePlaces={bed(3.5,.5)};offerPlace()
    binding=agent.recoveryRoute;job=SAO.Locomotion.jobs.runner;job.done=true;job.result="blocked"
    SAO.Locomotion.jobs.runner={body=body,done=true,result="blocked",goal=job.goal}
    placed("replacement_route_cannot_supply_refusal",not SAO.Needs.recoveryRouteResult("runner",body,binding.place,"sleep",job)
        and not SAO.Needs.recoveryMeansUnavailable("runner","sleep",binding.place))
    failedVisibleBed();nativePlaces={bed(0,0)};nativePlaces[1].key="bed:refused"
    SAO.Needs.beginRecovery=__actualBeginRecovery
    local poseBefore=SAO.RecoveryPose
    SAO.RecoveryPose={begin=function()return nil,"native-bed-entry-occupied"end}
    local refused=offerPlace("sleep")
    placed("exact_native_admission_refusal_reopens_search",refused and agent.inquiryRoute and not admitted
        and SAO.Needs.recoveryMeansUnavailable("runner","sleep",nativePlaces[1]))
    SAO.RecoveryPose=poseBefore
    failedVisibleBed();nativePlaces={bed(0,0)};nativePlaces[1].key="bed:refused"
    SAO.Needs.beginRecovery=__actualBeginRecovery
    SAO.RecoveryPose={begin=function()return nil,"native-bed-queue-refused"end}
    offerPlace("sleep")
    placed("queue_refusal_is_not_bad_furniture",not SAO.Needs.recoveryMeansUnavailable("runner","sleep",nativePlaces[1]))
    SAO.RecoveryPose=poseBefore
    failedVisibleBed();SAO.Needs.recoveryPlaces("runner",body)
    local ledger=rec.proceduralPlanning
    ledger.meansFailures[ledger.meansFailureOrder[1]].atHours=hours+1
    placed("future_refusal_cannot_change_current_inquiry",P.conceptInquiryOffer("runner",goal,100).status=="observed-means")
end
__result="PASS recovery placement "..placementChecks.."; concepts "..conceptChecks.."; ordinary "..checks
