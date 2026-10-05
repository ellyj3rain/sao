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
local function choice()return Ctl.chooseOrdinaryPurpose("runner",agent,body,100,needs)end
local function go()
    local kind,offer=choice()
    return kind,offer,Ctl.dispatchOrdinaryPurpose("runner",agent,body,100,needs,kind,offer)
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
verify("expired_pulse_still_records_owned_attempt",Ctl.finishConceptInquiryMovement("runner",agent,body)
    and #rec.situationAppraisal.questions["unclassified-sound"].revisions==2
    and S.query("runner",body,400).retainedQuestionCount==1 and #S.query("runner",body,400).questions==0)
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
__result="PASS situation appraisal: "..count.." checks"
