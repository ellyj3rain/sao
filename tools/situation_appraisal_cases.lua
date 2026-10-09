-- Appended to the ordinary-purpose fixture. Production owners acquire private
-- observations; native rows, physical state and movement verdicts are controlled.
local ordinaryPerception=SAO.Perception
SAO.Perception=__situationModules.perception
for _,name in ipairs({"believedThreatCount","nearestBelievedZombie","hasLookedRecently"}) do SAO.Perception[name]=ordinaryPerception[name] end
SAO.ProceduralPlanning=__situationModules.planning
SAO.Locomotion=__situationModules.locomotion
SAO.Disposition=__situationModules.disposition
local S,P,Per,Ctl=SAO.SituationAppraisal,SAO.ProceduralPlanning,SAO.Perception,SAO.Controller
local count=0
local function empty(t)for _ in pairs(t)do return false end return true end
local function verify(name,value)if not value then error("SITUATION:"..name)end;count=count+1 end
local source,view,level,stress
local function entry(kind,affirmed,certainty)
    return {id="report:"..kind,kind=kind,affirmed=affirmed,sourceId="authored-report:personal",
        sourceAtHours=11,receivedAtHours=11,certainty=certainty or "reported"}
end
SAO.PopulationAdmissions={}
verify("owned_provider",SAO.PersonalAwareness.bindInitialProvider(SAO.PopulationAdmissions,function(r)
    return source and source.personId==r.id and source or nil end))
local function fresh(entries)
    reset();manual=nil;needs.fatigue=.1;level=0;stress=0
    SAO.Hash.of=function()return 9999 end
    SAO.History.ageOf=function()return 34 end
    SAO.History.ticks=function()return 100 end
    source={schema="sao-personal-awareness-initial/1",personId="runner",issuerId="fixture:admissions",
        sourceId="fixture:definition",admissionKey="fixture:runner",admittedAtHours=11,entries=entries or {}}
    SAO.Conditions.assert("runner",{})
    verify("awareness_attached",SAO.PersonalAwareness.attachInitial(rec))
    body.getZ=function()return 1 end
    body.getMoodles=function()return {getMoodleLevel=function()return level end}end
    MoodleType={TIRED="tired",DRUNK="drunk",PAIN="pain"}
    SAOJavaBridge.socialState=function()return "i=0;p=0;s="..stress..";a=0;m=0"end
    SAOJavaBridge.setForceEntry=function()return true end
    SAOJavaBridge.perceive=function()return ""end
    SAO.Locomotion.jobs={};__starts=0;__cancels=0
    Per.beliefs.runner={zombies={},people={},factions={},places={},sounds={},lastScanAt=0,scanCount=0}
    view={schema="sao.concept-observation/1",actorId="runner",observations={
        {key="room:A",concept="room",kind="room",buildingId="house:A",roomId="room:A",x=0,y=0,z=1}},
        frontiers={{key="door:A",kind="doorway",buildingId="house:A",roomId="room:A",x=1,y=0,z=1,
            entryX=2,entryY=0,entryZ=1,state="closed"}}}
    SAOJavaBridge.conceptObservations=function()return view end
    Ctl.__fleeProbeTick(100)
    verify("owned_observation",Per.observeConcepts("runner",body,100))
end
local function appraisal()return SAO.Cognition.appraiseSituation("runner",body,100)end
local function choice(at)return Ctl.chooseOrdinaryPurpose("runner",agent,body,at or 100,needs)end
local function go(at)
    at=at or 100
    local kind,offer=choice(at)
    return kind,offer,Ctl.dispatchOrdinaryPurpose("runner",agent,body,at,needs,kind,offer)
end
fresh({entry("outbreak",true)})
local a=appraisal() or {}
verify("reported_premise_uncertain",a.status=="questions" and a.questions[1].interpretation=="reported"
    and a.questions[1].anticipated[2].qualifier=="unknown" and a.questions[1].evidence[1].sourceId=="authored-report:personal")
verify("personal_concepts_support_conditional_consequences",a.questions[1].anticipated[3].qualifier=="conditional"
    and a.knowledge.conditionalHarm.paths[1].roots[1].basis=="declared-ordinary-life-prior")
verify("pure_appraisal",rec.situationAppraisal==nil and rec.proceduralPlanning==nil)
a.questions[1].evidence[1].sourceId="tampered"
verify("detached_appraisal",appraisal().questions[1].evidence[1].sourceId=="authored-report:personal")
local kind,offer,admittedSituation=go()
verify("curiosity_without_deprivation_dispatches",kind=="inquiry" and offer.payload.mode=="situation"
    and admittedSituation and __starts==1 and agent.state=="TRAVEL")
verify("known_floor_not_sound_coordinate",__ordered.z==1 and __ordered.x==2)
verify("two_models_consume_epistemic_consequence",rec.ordinaryPurposeDecision.interpretations.models[1].ranked[1].predictions[1].kind=="investigate"
    and rec.ordinaryPurposeDecision.interpretations.models[2].ranked[1].predictions[1].basis=="unknown")
local purpose=P.pending("runner","investigate")
verify("question_history_attributed",rec.situationAppraisal.questions["reported:outbreak"].revisions[1].evidence[1].sourceId=="authored-report:personal")
Ctl.__inspectionProbeState(agent,"runner","IDLE","urgent interruption","need")
verify("interruption_preserves_question",purpose.status=="interrupted" and not purpose.admission
    and rec.situationAppraisal.questions["reported:outbreak"].revisions[1].localCauseConfirmed==false)
rec.proceduralPlanning=__nativeRoundtrip(rec.proceduralPlanning)
rec.situationAppraisal=__nativeRoundtrip(rec.situationAppraisal)
rec.personalAwareness=__nativeRoundtrip(rec.personalAwareness)
purpose=rec.proceduralPlanning.purposes[purpose.id]
agent={rec=rec,state="IDLE"};Ctl.agents.runner=agent
verify("reload_reappraises_retained_inquiry",choice()=="inquiry" and rec.proceduralPlanning.purposes[purpose.id]==purpose)
kind,offer,admittedSituation=go()
verify("resumed_inquiry_uses_owner",admittedSituation and #rec.situationAppraisal.questions["reported:outbreak"].revisions==2)
local routeId=agent.inquiryRoute.routeId
local job=SAO.Locomotion.jobs.runner;job.done=true;job.result="arrived"
verify("native_result_consumed",Ctl.finishConceptInquiryMovement("runner",agent,body))
verify("approach_is_not_cause_confirmation",#rec.situationAppraisal.questions["reported:outbreak"].revisions==3
    and rec.situationAppraisal.questions["reported:outbreak"].revisions[3].localCauseConfirmed==false
    and empty(Per.beliefs.runner.zombies))
verify("attempt_not_repeated",P.situationInquiryOffer("runner",body,100)==nil)
verify("native_revision_consumed_once",not P.reviseSituationInquiry("runner",body,purpose.id,routeId,100)
    and #rec.situationAppraisal.questions["reported:outbreak"].revisions==3)
fresh({entry("outbreak",true)})
source.sourceId="foreign:definition"
verify("rebound_source_withholds_question",appraisal().status=="unavailable" and choice()=="continue")
fresh({entry("outbreak",true)})
rec.personalAwareness.actorId="other"
verify("foreign_source_withheld",appraisal().status=="unavailable" and choice()=="continue")
fresh({entry("outbreak",true)})
rec.situationAppraisal={schema=1,actorId="other",questions={},order={}}
verify("foreign_retained_question_withheld",appraisal().status=="unavailable")
fresh({entry("outbreak",true)})
rec.bodyOwnerToken="replacement"
verify("foreign_body_withheld",appraisal().status=="unavailable")
fresh({entry("outbreak",true)})
local clear=appraisal().questions[1].utility
level=4
verify("actual_readiness_blocks_inquiry",appraisal().status=="inaccessible" and choice()=="continue")
level=0
verify("readiness_recovery_recalls_same_report",choice()=="inquiry" and appraisal().questions[1].utility==clear)
rec.neuroinflammation=.8
verify("actual_neuro_changes_competing_value",appraisal().questions[1].utility<clear and choice()=="continue")
fresh({entry("outbreak",true)})
local unconditioned=appraisal().questions[1].utility
SAO.Conditions.assert("runner",{depression=true})
verify("owned_health_trait_bends_inquiry",appraisal().psychology.values.initiative.condition==-.15
    and appraisal().questions[1].utility<unconditioned)
SAO.Conditions.assert("runner",{anxiety=true})
verify("owned_fear_is_visible",appraisal().psychology.fear==.25 and appraisal().psychology.values.nerve.condition==-.1)
fresh({entry("outbreak",true)})
local calm=appraisal().questions[1].utility;stress=.9
verify("native_stress_changes_value",appraisal().psychology.temper.stress==.9 and appraisal().questions[1].utility<calm)
fresh({entry("outbreak",true)})
rec.traitEchoes={initiative=-.4,selfPreservation=-.4,nerve=-.4,discipline=.4}
verify("personal_values_can_choose_continuation",appraisal().questions[1].utility<.1 and choice()=="continue")
local contrary=entry("turned",false,"witnessed");contrary.id="witness:contrary"
fresh({entry("turned",true),contrary})
verify("known_witness_contradiction_retained",appraisal().questions[1].interpretation=="challenged"
    and #appraisal().questions[1].evidence==2 and not SAO.PersonalAwareness.query("runner").possible)
fresh()
Per.forgetSoundCues("runner",body)
SAOJavaBridge.perceive=function()return table.concat({
    "S:30:0:30:cue:01234567-89ab-cdef-0123-456789abcdef-8",
    "S:8:0:8:cue:01234567-89ab-cdef-0123-456789abcdef-9",
    "S:4:0:4:cue:01234567-89ab-cdef-0123-456789abcdef-10"},"|")end
Per.observe("runner",body,100,false)
local ordered=Per.soundCues("runner",body,100)
verify("personally_heard_cues_rank_near_before_far",#ordered==3
    and ordered[1].distance==4 and ordered[2].distance==8
    and ordered[3].distance==30 and appraisal().questions[1].evidence[1].id==ordered[1].cueId)
Per.forgetSoundCues("runner",body)
fresh()
local crowded={}
for i=1,64 do
    crowded[#crowded+1]="S:"..i..":0:"..i..":cue:01234567-89ab-cdef-0123-456789abcdef-"..i
end
SAOJavaBridge.perceive=function()return table.concat(crowded,"|")end
Per.observe("runner",body,100,false)
verify("private_sound_cache_bounded_at_capacity",#Per.soundCues("runner",body,100)==64)
SAO.History.ticks=function()return 120 end;Ctl.__fleeProbeTick(120)
SAOJavaBridge.perceive=function()return "S:1:0:1:cue:01234567-89ab-cdef-0123-456789abcdef-65"end
Per.observe("runner",body,120,false)
local newest=Per.soundCues("runner",body,120)
verify("new_heard_impact_survives_full_private_cache",#newest==64
    and newest[1].cueId=="01234567-89ab-cdef-0123-456789abcdef-65"
    and newest[1].heardAt==120
    and not (function()for _,cue in ipairs(newest) do if cue.distance==64 then return true end end end)())
verify("crowded_personal_appraisal_sees_new_pulse",S.query("runner",body,120).questions[1].evidence[1].id==newest[1].cueId)
Per.forgetSoundCues("runner",body)
fresh()
SAOJavaBridge.perceive=function()return "S:8:9:12:cue:01234567-89ab-cdef-0123-456789abcdef-1"end
Per.observe("runner",body,100,false)
verify("anonymous_sound_question_not_zombie",appraisal().questions[1].subject=="unclassified-sound"
    and appraisal().questions[1].interpretation=="unknown-cause" and empty(Per.beliefs.runner.zombies)
    and not SAO.PersonalAwareness.query("runner").possible)
verify("sound_can_prompt_actual_curiosity",choice()=="inquiry")
local _,_,soundAdmitted=go()
verify("sound_inquiry_native_admission",soundAdmitted)
SAO.History.ticks=function()return 400 end;Ctl.__fleeProbeTick(400)
local soundJob=SAO.Locomotion.jobs.runner;soundJob.done=true;soundJob.result="arrived"
local finishedSound=Ctl.finishConceptInquiryMovement("runner",agent,body)
local expiredSound=S.query("runner",body,400)
verify("expired_pulse_still_records_owned_attempt",finishedSound
    and #rec.situationAppraisal.questions["unclassified-sound"].revisions==2
    and expiredSound.retainedQuestionCount==1
    and expiredSound.questions[1] and expiredSound.questions[1].retained==true
    and expiredSound.questions[1].evidence[1].heardAt==100)
fresh()
body.getZ=function()return 0 end
view={schema="sao.concept-observation/1",actorId="runner",observations={
    {key="object:visible-approach",concept="container",kind="object",x=3,y=2,z=0}},frontiers={}}
Per.beliefs.runner.concepts=nil
verify("exterior_native_object_observed",Per.observeConcepts("runner",body,100))
SAOJavaBridge.perceive=function()return "S:8:9:12:cue:01234567-89ab-cdef-0123-456789abcdef-2"end
Per.observe("runner",body,100,false)
local exterior=P.situationInquiryOffer("runner",body,100)
verify("exterior_sound_can_prompt_owned_route",exterior and exterior.approach
    and exterior.observedMeans.key=="object:visible-approach"
    and exterior.contextId=="exterior:01234567-89ab-cdef-0123-456789abcdef-2"
    and choice()=="inquiry")
local _,_,exteriorAdmitted=go()
verify("exterior_inquiry_uses_visible_waypoint",exteriorAdmitted and __ordered.x==3 and __ordered.y==2
    and __ordered.z==0 and not SAO.PersonalAwareness.query("runner").possible)
local exteriorJob=SAO.Locomotion.jobs.runner;exteriorJob.done=true;exteriorJob.result="arrived"
SAO.History.ticks=function()return 400 end;hours=200;Ctl.__fleeProbeTick(400)
verify("exterior_attempt_survives_first_week",Ctl.finishConceptInquiryMovement("runner",agent,body)
    and rec.situationAppraisal.questions["unclassified-sound"].revisions[2].localCauseConfirmed==false)
rec.situationAppraisal=__nativeRoundtrip(rec.situationAppraisal)
rec.proceduralPlanning=__nativeRoundtrip(rec.proceduralPlanning)
verify("exterior_midgame_question_retained",S.query("runner",body,400).retainedQuestionCount==1
    and S.query("runner",body,400).questions[1].retained==true
    and #Per.soundCues("runner",body,400)==0)
view={schema="sao.concept-observation/1",actorId="runner",observations={},frontiers={},approaches={
    {key="ground:3:2:0",kind="visible-ground",x=3.5,y=2.5,z=0}}}
Per.beliefs.runner.concepts=nil
verify("midgame_ground_currently_visible",Per.observeConcepts("runner",body,400))
local later=P.situationInquiryOffer("runner",body,400)
verify("retained_sound_uses_current_visible_approach",later
    and later.contextId=="exterior:01234567-89ab-cdef-0123-456789abcdef-2"
    and later.observedMeans.key=="ground:3:2:0"
    and later.appraisal.retained==true
    and #Per.soundCues("runner",body,400)==0)
local laterKind,laterOffer,laterAdmitted=go(400)
verify("retained_midgame_kind",laterKind=="inquiry")
verify("retained_midgame_offer",laterOffer and laterOffer.payload
    and laterOffer.payload.observedMeans and laterOffer.payload.observedMeans.key=="ground:3:2:0")
verify("retained_midgame_route_admitted",laterAdmitted and agent.state=="TRAVEL"
    and __ordered.x==3.5 and __ordered.y==2.5 and __ordered.z==0)
verify("retained_midgame_original_hearing_attributed",
    rec.situationAppraisal.questions["unclassified-sound"].revisions[1].evidence[1].heardAt==100)
fresh()
body.getZ=function()return 0 end
view={schema="sao.concept-observation/1",actorId="runner",observations={},frontiers={},approaches={
    {key="ground:3:2:0",kind="visible-ground",x=3.5,y=2.5,z=0}}}
Per.beliefs.runner.concepts=nil
verify("exterior_native_ground_observed",Per.observeConcepts("runner",body,100))
SAOJavaBridge.perceive=function()return "S:8:9:12:cue:01234567-89ab-cdef-0123-456789abcdef-4"end
Per.observe("runner",body,100,false)
local ground=P.situationInquiryOffer("runner",body,100)
verify("open_ground_sound_has_personal_waypoint",ground and ground.observedMeans.key=="ground:3:2:0"
    and ground.approach.x==3.5 and ground.approach.y==2.5 and choice()=="inquiry")
local _,_,groundAdmitted=go()
verify("open_ground_inquiry_uses_existing_movement",groundAdmitted and __ordered.x==3.5
    and __ordered.y==2.5 and not SAO.PersonalAwareness.query("runner").possible)
fresh()
body.getZ=function()return 0 end
view={schema="sao.concept-observation/1",actorId="runner",observations={},frontiers={},approaches={
    {key="ground:3:2:0",kind="visible-ground",x=5.5,y=5.5,z=0}}}
Per.beliefs.runner.concepts=nil;Per.observeConcepts("runner",body,100)
SAOJavaBridge.perceive=function()return "S:8:9:12:cue:01234567-89ab-cdef-0123-456789abcdef-5"end
Per.observe("runner",body,100,false)
verify("forged_ground_coordinate_withheld",choice()=="continue" and __starts==0)
fresh()
body.getZ=function()return 0 end
view={schema="sao.concept-observation/1",actorId="runner",observations={
    {key="object:sideways",concept="container",kind="object",x=6,y=-5,z=0}},frontiers={}}
Per.beliefs.runner.concepts=nil;Per.observeConcepts("runner",body,100)
SAOJavaBridge.perceive=function()return "S:8:9:12:cue:01234567-89ab-cdef-0123-456789abcdef-3"end
Per.observe("runner",body,100,false)
verify("exterior_sideways_object_no_route",choice()=="continue" and __starts==0)
fresh()
Per.beliefs.runner.sounds={old={x=8,y=9,at=100,source="heard",kind="unknown"}}
Per.forgetSoundCues("runner",body)
verify("restored_sound_not_fresh_acquisition",#appraisal().questions==0 and choice()=="continue")
fresh({entry("outbreak",true)})
view.frontiers={};Per.beliefs.runner.concepts=nil;Per.observeConcepts("runner",body,100)
verify("no_observed_lead_no_invented_route",choice()=="continue" and __starts==0)
fresh({entry("outbreak",true)})
permission=false
verify("standing_refuses_investigation",choice()=="continue")
fresh({entry("outbreak",true)})
threat=true
verify("current_threat_keeps_existing_owner",choice()==nil and __starts==0)
threat=false;needs.thirst=.99
verify("urgent_need_keeps_existing_owner",choice()==nil)
fresh({entry("outbreak",true)})
go();rec.situationAppraisal.questions["reported:outbreak"].revisions[1].evidence[1].receivedAtHours=hours+1
verify("future_saved_question_withheld",appraisal().status=="unavailable")
fresh({entry("outbreak",true)})
go();rec.situationAppraisal.order[2]=rec.situationAppraisal.order[1]
verify("duplicate_saved_question_withheld",appraisal().status=="unavailable")
fresh({entry("outbreak",true)})
verify("future_query_clock_withheld",S.query("runner",body,101).status=="unavailable")
fresh()
verify("no_report_no_sound_preserves_continuation",choice()=="continue" and #appraisal().questions==0)
-- A BWO-owned Week One body stays foreign to SAO's actuator, but its exact
-- crosswalk lets the same SAO person own a private heard question and native
-- visible exterior approach. This fixture does not claim physical dispatch.
fresh()
local sourceBody={}
local sourceCell={}
local function sourceSquare(x,y,z)
    return {getX=function()return x end,getY=function()return y end,
        getZ=function()return z end,getRoom=function()return nil end}
end
sourceCell.getGridSquare=function(_,x,y,z)
    if z==0 and y==0 and (x==3 or x==6) then return sourceSquare(x,y,z) end
end
sourceBody.getCell=function()return sourceCell end
sourceBody.getCurrentSquare=function()return sourceSquare(0,0,0) end
sourceBody.getX=function()return 0 end
sourceBody.getY=function()return 0 end
sourceBody.getZ=function()return 0 end
sourceBody.getModData=function()return {SAOWeekOneOrigin="BanditsWeekOne",
    SAOWeekOnePersonId="runner",SAOWeekOneBrainId=77,SAOWeekOneBorn=1} end
rec.weekOne={source="BanditsWeekOne",status="external",brainId=77,born=1}
SAO.Body.active.runner=nil
SAO.Claims={heldBy=function(person)return person==rec and "BanditsWeekOne" or nil end}
SAO.WeekOneContinuity={sourceBodyFor=function(id)
    if id=="runner" and SAO.Body.active.runner==nil then return sourceBody,{id=77,born=1} end
end}
SAOJavaBridge.weekOneObservedFeature=function(_,found,square,kind)
    return found==sourceBody and kind=="ground" and square:getY()==0
        and (square:getX()==3 or square:getX()==6)
end
SAOJavaBridge.perceiveAudibleSounds=function(_,found)
    return found==sourceBody and "S:8:0:8:cue:01234567-89ab-cdef-0123-456789abcdef-6" or ""
end
-- A body handoff in the same county tick must not borrow the ordinary body's
-- earlier objects or doorway hypotheses as this source body's present sight.
Per.beliefs.runner.concepts={at=100,status="observed",readerStatus="available",
    observations={old={actorId="runner",at=100,kind="object",key="old",
        concept="container",source="native-personal-visibility",x=2,y=0,z=0}},
    order={"old"},frontiers={old={actorId="runner",at=100,kind="doorway",
        key="old",roomId="old",buildingId="old",x=2,y=0,z=0}},
    frontierOrder={"old"},approaches={}}
Per.beliefs.runner.lastScanAt=100
verify("source_context_withheld_before_rebound_scan",
    Per.conceptContext("runner",100,sourceBody).status=="observation-unavailable")
Per.observe("runner",sourceBody,100,false)
verify("source_rebound_refreshes_throttled_context",
    Per.conceptContext("runner",100,sourceBody).status=="observed"
    and #Per.conceptContext("runner",100,sourceBody).approaches==2)
verify("source_native_ground_only",Per.observeConcepts("runner",sourceBody,100)
    and #Per.conceptContext("runner",100).approaches==2)
verify("source_same_tick_does_not_borrow_ordinary_sight",
    #Per.conceptContext("runner",100).observations==0
    and #Per.conceptContext("runner",100).frontiers==0)
Per.observeAudible("runner",sourceBody,100,false)
local sourceSituation=S.query("runner",sourceBody,100)
verify("source_person_has_private_situation_question",sourceSituation.status=="questions"
    and sourceSituation.questions[1].subject=="unclassified-sound"
    and sourceSituation.questions[1].evidence[1].basis=="heard")
local sourceOffer=P.situationInquiryOffer("runner",sourceBody,100)
verify("source_private_ground_is_not_sound_origin",sourceOffer
    and sourceOffer.observedMeans.key=="ground:6:0:0"
    and sourceOffer.approach.x==6 and sourceOffer.approach.y==0)
local sourceComparison=SAO.Cognition.interpretPlans("runner",{
    {id="inquiry:unclassified-sound",kind="inquiry",evidence=1,
        continuity=0,novelty=1,informationGain=1,blockers=0,
        utility=sourceOffer.utility},
    {id="walk:visible-ground",kind="walk",evidence=1,
        continuity=0,novelty=0,informationGain=0,blockers=0,
        utility=.5}},
    {domain="leisure-action",pressure=.5})
verify("source_inquiry_competes_in_person_model",sourceComparison
    and #sourceComparison.models==2
    and sourceComparison.models[1].ranked[1]
    and sourceComparison.models[2].ranked[1])
local firstPurpose,firstStep=P.planSourceSituationInquiry(
    "runner",sourceBody,sourceOffer,100)
local firstSelection=firstPurpose and firstPurpose.inquiry.sourceSelection
verify("source_inquiry_uses_retained_person_purpose",firstStep
    and firstStep.owner=="SAO.WeekOneContinuity"
    and firstSelection and firstSelection.targetKey==firstStep.target
    and firstPurpose.admission
    and firstPurpose.admission.owner=="SAO.WeekOneContinuity"
    and firstPurpose.admission.stepId==firstStep.id
    and rec.situationAppraisal.questions["unclassified-sound"]~=nil)
P.interruptConceptInquiry("runner","controller-detach")
verify("controller_interrupt_preserves_source_admission",
    firstPurpose.admission
    and firstPurpose.admission.owner=="SAO.WeekOneContinuity"
    and firstPurpose.inquiry.sourceSelection.sequence==firstSelection.sequence)
rec.weekOne.sourceInquiry={purposeId=firstPurpose.id,
    sequence=firstSelection.sequence}
verify("lost_source_body_reconciles_unconfirmed_attempt",
    P.finishSourceSituationInquiry("runner",nil,firstPurpose.id,
        firstSelection.sequence,"interrupted",100)
    and firstPurpose.inquiry.attempts[firstStep.target].status=="route-unconfirmed"
    and firstPurpose.admission==nil
    and firstPurpose.lastAdmission.owner=="SAO.WeekOneContinuity")
rec.weekOne.sourceInquiry=nil
local nextOffer=P.situationInquiryOffer("runner",sourceBody,100)
verify("source_inquiry_uses_next_visible_lead",nextOffer
    and nextOffer.approach.x==3)
local secondPurpose,secondStep=P.planSourceSituationInquiry(
    "runner",sourceBody,nextOffer,100)
local secondSelection=secondPurpose and secondPurpose.inquiry.sourceSelection
rec.weekOne.sourceInquiry={purposeId=secondPurpose.id,
    sequence=secondSelection.sequence}
verify("source_position_requires_selected_ground",
    not P.finishSourceSituationInquiry("runner",sourceBody,secondPurpose.id,
        secondSelection.sequence,"observed",100))
sourceBody.getX=function()return 3.5 end
sourceBody.getY=function()return .5 end
sourceBody.getCurrentSquare=function()return sourceSquare(3,0,0) end
verify("source_new_tile_invalidates_prior_scan_receipt",
    not Per.conceptObservationReceipt("runner",sourceBody,100))
verify("source_arrival_needs_new_successful_sight",
    not P.finishSourceSituationInquiry("runner",sourceBody,secondPurpose.id,
        secondSelection.sequence,"observed",100))
verify("source_fresh_successful_concept_receipt",
    Per.observeConcepts("runner",sourceBody,100)
    and Per.conceptObservationReceipt("runner",sourceBody,100))
local sourceRevisions=rec.situationAppraisal.questions["unclassified-sound"].revisions
verify("source_position_and_sight_revise_without_cause_claim",
    P.finishSourceSituationInquiry("runner",sourceBody,secondPurpose.id,
        secondSelection.sequence,"observed",100)
    and secondPurpose.inquiry.attempts[secondStep.target].status=="approached"
    and secondPurpose.admission==nil
    and sourceRevisions[#sourceRevisions].outcome=="observed-after-route"
    and sourceRevisions[#sourceRevisions].localCauseConfirmed==false)
rec.weekOne.sourceInquiry=nil
sourceBody.getX=function()return 0 end
sourceBody.getY=function()return 0 end
sourceBody.getCurrentSquare=function()return sourceSquare(0,0,0) end
SAO.WeekOneContinuity.sourceBodyFor=function()return sourceBody,{id=77,born=2}end
verify("source_ground_requires_current_brain_generation",
    Per.conceptContext("runner",100,sourceBody).status=="observation-unavailable")
SAO.WeekOneContinuity.sourceBodyFor=function(id)
    if id=="runner" and SAO.Body.active.runner==nil then return sourceBody,{id=77,born=1} end
end
sourceBody.getCurrentSquare=function()
    return {getRoom=function()return {id="interior"}end}
end
Per.beliefs.runner.concepts=nil
verify("source_interior_cannot_claim_exterior_ground",
    not Per.observeConcepts("runner",sourceBody,100))
sourceBody.getCurrentSquare=function()return sourceSquare(0,0,0) end
SAO.WeekOneContinuity.sourceBodyFor=function()return nil end
verify("source_crosswalk_loss_withholds_question",
    S.query("runner",sourceBody,100).status=="unavailable"
    and not Per.observeConcepts("runner",sourceBody,100))
__result="PASS situation appraisal: "..count.." checks"
