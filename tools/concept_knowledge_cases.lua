-- Appended to the ordinary-purpose fixture, retaining its controlled actors.
SAO.ProceduralPlanning=__conceptModules.planning
SAO.Locomotion=__conceptModules.locomotion
local ordinaryPerception=SAO.Perception
SAO.Perception=__conceptModules.perception
for _,name in ipairs({"believedThreatCount","nearestBelievedZombie","hasLookedRecently"}) do
    SAO.Perception[name]=ordinaryPerception[name]
end
local K,P,Per,Ctl=SAO.ConceptKnowledge,SAO.ProceduralPlanning,SAO.Perception,SAO.Controller
local conceptChecks=0
local function verify(name,value)
    if not value then error("CONCEPT:"..name) end
    conceptChecks=conceptChecks+1
end
local view
local function freshConcepts()
    reset();manual=nil;needs.fatigue=.82;traits.initiative=.15;traits.discipline=.15
    SAO.Locomotion.jobs={};__starts=0;__cancels=0;__ordered=nil
    Ctl.__fleeProbeTick(100)
    SAOJavaBridge.setForceEntry=function()return true end
    SAOJavaBridge.conceptObservations=function()return view end
    view={schema="sao.concept-observation/1",actorId="runner",
        observations={{key="room:A",concept="room",kind="room",buildingId="house:A",roomId="room:A",x=0,y=0,z=0}},
        frontiers={{key="door:A",kind="doorway",buildingId="house:A",roomId="room:A",
            x=1,y=0,z=0,entryX=2,entryY=0,entryZ=0,state="closed"}}}
end
local function observe()
    return Per.observeConcepts("runner",body,100)
end
local function object(concept)
    view.observations[#view.observations+1]={key="object:"..concept,concept=concept,kind="object",
        buildingId="house:A",roomId="room:A",x=0,y=1,z=0}
end
-- Fixtures below are explicitly retained person beliefs, not claimed perception
-- of absence. The current production intake learns affirmative associations.
local function retainedEdge(from,into,context,affirmed,relation,actor)
    rec.conceptKnowledge=rec.conceptKnowledge or {schema=1,sequence=0,relations={},order={},omitted=0}
    local s=rec.conceptKnowledge;s.sequence=s.sequence+1
    local key="fixture:"..s.sequence
    s.order[#s.order+1]=key
    s.relations[key]={id=key,actorId=actor or "runner",from=from,into=into,relation=relation or "supports",
        affirmed=affirmed~=false,contextId=context,basis="personal-association",sourceId="fixture-source",
        acquiredAt=hours,modal=true}
end
freshConcepts()
local cold=K.infer("runner","house","relief-from-tiredness","house:A")
verify("cold_general_association",cold.status=="expectation" and cold.paths[1].depth==4
    and cold.paths[1].roots[1].into=="bedroom")
verify("query_does_not_write_knowledge",rec.conceptKnowledge==nil and rec.proceduralPlanning==nil)
verify("expectation_is_not_spatial_fact",cold.paths[1].modal and cold.paths[1].x==nil
    and cold.paths[1].roots[1].basis=="declared-ordinary-life-prior" and #cold.missing>0)
verify("food_cross_domain",K.infer("runner","kitchen","relief-from-hunger").status=="expectation")
verify("container_general_association",K.infer("runner","container","contents").status=="expectation")
verify("sleeping_furniture_affordance",K.infer("runner","sleeping-furniture","relief-from-tiredness").status=="expectation")
verify("unassociated_concept_honestly_unresolved",K.infer("runner","cupboard","flying").status=="unresolved")
verify("unknown_location_does_not_dispatch",P.conceptInquiryOffer("runner","relief-from-tiredness",100).status=="unresolved"
    and __starts==0 and rec.proceduralPlanning==nil)
verify("canonical_observation_admitted",observe()==true)
local inquiry=P.conceptInquiryOffer("runner","relief-from-tiredness",100)
verify("private_frontier_grounded_inquiry",inquiry.status=="actionable" and inquiry.desiredConcept=="bed"
    and inquiry.frontier.entryX==2 and inquiry.frontier.roomId=="room:A")
verify("query_does_not_create_purpose",rec.proceduralPlanning==nil)
local ownBefore=K.infer("runner","room","relief-from-exertion","house:A")
verify("novel_pair_not_in_foundation",ownBefore.status=="unresolved")
object("seat");observe()
local learned=K.infer("runner","room","relief-from-exertion","house:B")
verify("canonical_pair_generalizes_modally",learned.status=="expectation"
    and learned.paths[1].roots[1].basis=="personal-association" and learned.paths[1].modal)
local seq=rec.conceptKnowledge.sequence;observe()
verify("same_observation_deduplicates",rec.conceptKnowledge.sequence==seq)
-- The native defect had six visible containers in one room: source identity
-- alternated every scan although the two learned propositions were unchanged.
freshConcepts()
for i=1,6 do object("container");view.observations[#view.observations].key="object:container:"..i end
observe()
local learnedState=rec.conceptKnowledge
local localKey="room|contains|container|house:A"
local generalKey="room|typically-contains|container|*"
local localRow,generalRow=learnedState.relations[localKey],learnedState.relations[generalKey]
verify("six_objects_are_two_propositions",learnedState.sequence==2 and #learnedState.order==2)
verify("distinct_witnesses_retained_privately",#learnedState.witnesses[localRow.id].rows==6
    and localRow.witnesses==nil and generalRow.witnesses==nil)
local localId,generalId,primary,acquired=localRow.id,generalRow.id,localRow.sourceId,localRow.acquiredAt
local stableInquiry=P.conceptInquiryOffer("runner","relief-from-hunger",100)
hours=hours+1
Per.observeConcepts("runner",body,101)
verify("renewed_scan_preserves_propositions",learnedState.sequence==2
    and learnedState.relations[localKey].id==localId and learnedState.relations[generalKey].id==generalId)
verify("primary_acquisition_immutable",localRow.sourceId==primary and localRow.acquiredAt==acquired)
verify("witness_refresh_retains_first_time",learnedState.witnesses[localId].rows[1].acquiredAt==acquired
    and learnedState.witnesses[localId].rows[1].lastObservedAt==hours
    and #learnedState.witnesses[localId].rows==6)
local reordered={view.observations[1]}
for i=#view.observations,2,-1 do reordered[#reordered+1]=view.observations[i] end
view.observations=reordered;Per.observeConcepts("runner",body,102)
verify("reordered_scan_preserves_identity",learnedState.sequence==2
    and learnedState.relations[localKey].sourceId==primary)
object("container");view.observations[#view.observations].key="object:container:new"
Per.observeConcepts("runner",body,103)
verify("new_witness_not_new_proposition",learnedState.sequence==2
    and #learnedState.witnesses[localId].rows==7)
local refreshedInquiry=P.conceptInquiryOffer("runner","relief-from-hunger",103)
local refreshKind,refreshOffer=Ctl.chooseOrdinaryPurpose("runner",agent,body,103,needs)
local refreshDispatched=refreshKind and Ctl.dispatchOrdinaryPurpose("runner",agent,body,103,needs,refreshKind,refreshOffer)
verify("refresh_preserves_actual_inquiry_choice",refreshedInquiry.status==stableInquiry.status
    and refreshedInquiry.frontier.key==stableInquiry.frontier.key and refreshKind=="inquiry" and refreshDispatched and __ordered.x==2)
for i=8,20 do object("container");view.observations[#view.observations].key="object:container:"..i end
Per.observeConcepts("runner",body,104)
verify("witness_bound_exposes_truncation",#learnedState.witnesses[localId].rows==16
    and learnedState.witnesses[localId].truncated and learnedState.sequence==2
    and learnedState.relations[localKey].sourceId==primary)
-- Existing retained polarity/basis are semantic revisions, unlike another
-- witness. These fixtures do not claim a native observation-of-absence path.
localRow.affirmed=false
Per.observeConcepts("runner",body,105)
verify("changed_polarity_mints_revision",learnedState.sequence==3
    and learnedState.relations[localKey].affirmed and learnedState.relations[localKey].id~=localId
    and learnedState.witnesses[localId]==nil and learnedState.relations[generalKey].id==generalId)
local basisId=learnedState.relations[localKey].id
learnedState.relations[localKey].basis="taught-association"
Per.observeConcepts("runner",body,106)
verify("changed_basis_mints_revision",learnedState.sequence==4
    and learnedState.relations[localKey].basis=="observed-relation"
    and learnedState.relations[localKey].id~=basisId and learnedState.witnesses[basisId]==nil)
local beforeInvalid=learnedState.sequence
learnedState.relations[localKey].actorId="other"
Per.observeConcepts("runner",body,107)
verify("canonical_observation_replaces_foreign_row",learnedState.sequence==beforeInvalid+1
    and learnedState.relations[localKey].actorId=="runner"
    and learnedState.relations[localKey].sourceId==primary)
beforeInvalid=learnedState.sequence
learnedState.relations[localKey].acquiredAt=hours+1
Per.observeConcepts("runner",body,108)
verify("canonical_observation_replaces_future_row",learnedState.sequence==beforeInvalid+1
    and learnedState.relations[localKey].acquiredAt==hours)
beforeInvalid=learnedState.sequence
learnedState.relations[localKey].into="bed"
Per.observeConcepts("runner",body,109)
verify("canonical_observation_replaces_misfiled_meaning",learnedState.sequence==beforeInvalid+1
    and learnedState.relations[localKey].into=="container")
beforeInvalid=learnedState.sequence
learnedState.relations[localKey].id="concept/other/99"
Per.observeConcepts("runner",body,110)
verify("canonical_observation_replaces_foreign_identity",learnedState.sequence==beforeInvalid+1
    and learnedState.relations[localKey].id=="concept/runner/"..learnedState.sequence)
beforeInvalid=learnedState.sequence
learnedState.relations[localKey]=false
Per.observeConcepts("runner",body,111)
verify("canonical_observation_replaces_malformed_row",learnedState.sequence==beforeInvalid+1
    and learnedState.relations[localKey].into=="container")
local originalIdentity=SAO.Identity.get
SAO.Identity.get=function(id)if id=="other" then return {id="other"} else return originalIdentity(id)end end
verify("another_person_does_not_inherit_association",K.infer("other","room","relief-from-exertion","house:B").status=="unresolved")
SAO.Identity.get=originalIdentity
freshConcepts();retainedEdge("room","bed","house:A",false,"may-contain");observe()
verify("local_contradiction_blocks_expected_path",K.infer("runner","room","relief-from-tiredness","house:A").status=="challenged")
verify("local_exception_does_not_erase_general_prior",K.infer("runner","room","relief-from-tiredness","house:B").status=="expectation")
verify("contradicted_inquiry_falls_back_to_owner",act()=="recovery" and admitted=="sleep" and __starts==0)
local contradictedUtility=rec.ordinaryPurposeDecision.alternatives[2].utility
freshConcepts();observe()
verify("live_controller_dispatches_conceptual_inquiry",Ctl.__playerProbeDecide("runner",agent,body,100,needs)==true
    and agent.state=="TRAVEL" and __starts==1 and __ordered.x==2 and admitted==nil)
verify("same_utilities_different_relations_change_dispatch",rec.ordinaryPurposeDecision.alternatives[2].utility==contradictedUtility)
verify("selection_does_not_claim_effect",rec.ordinaryPurposeDecision.status=="admitted"
    and agent.rec.recoveryExperiences==nil and rec.ordinaryPurposeDecision.inquiry.path.into=="relief-from-tiredness")
local purpose=P.pending("runner","investigate")
verify("inquiry_purpose_retains_reason",purpose and purpose.inquiry.goal=="relief-from-tiredness" and purpose.rationale)
local route=SAO.Locomotion.jobs.runner;route.done=true;route.result="arrived"
verify("arrival_consumed_by_exact_owner",Ctl.__followProbeMovement("runner",agent,body)==true and purpose.admission==nil)
verify("arrival_does_not_invent_object",Per.conceptObservation("runner","object:bed")==nil
    and purpose.status=="maintained" and purpose.inquiry.attempts[P.conceptFrontierKey(view.frontiers[1])]
    and purpose.inquiry.attempts[P.conceptFrontierKey(view.frontiers[1])].status=="approached")
verify("same_frontier_not_repeated",P.conceptInquiryOffer("runner","relief-from-tiredness",100).status=="unresolved")
for i=1,12 do purpose.inquiry.attempts["used:"..i]={status="approached"} end
verify("local_attempt_budget_exposed",P.conceptInquiryOffer("runner","relief-from-tiredness",100).limitReached==true)
view.observations[1].buildingId="house:B";view.frontiers[1].buildingId="house:B";view.frontiers[1].key="door:B";observe()
verify("new_building_gets_own_search_budget",P.conceptInquiryOffer("runner","relief-from-tiredness",100).status=="actionable")
freshConcepts();rec.homeX=0;rec.homeY=0
Per.beliefs.runner.known={["house:A"]={minX=-1,maxX=3,minY=-1,maxY=3}}
object("bed");observe()
local context=Per.conceptContext("runner",100)
verify("remembered_residence_anchor",context.observations[1].concept=="residence"
    and context.observations[1].source=="personally-remembered-home")
verify("observed_means_precede_unlocated_room_label",P.conceptInquiryOffer("runner","relief-from-tiredness",100).status=="observed-means"
    and act()=="recovery" and admitted=="sleep" and __starts==0)
freshConcepts();object("container");observe()
verify("container_does_not_establish_contents",P.conceptInquiryOffer("runner","relief-from-hunger",100).status=="actionable")
freshConcepts();observe();local standingKind,standingOffer=choose();permission=false
verify("standing_refuses_inquiry",standingKind=="inquiry"
    and not Ctl.dispatchOrdinaryPurpose("runner",agent,body,100,needs,standingKind,standingOffer)
    and __starts==0 and agent.inquiryRoute==nil)
freshConcepts();rec.bodyOwnerToken="replacement"
verify("stale_token_observation_rejected",observe()==false and Per.beliefs.runner.concepts==nil)
freshConcepts();rec.bodyOwnerToken=nil
body.getModData=function()return {SAOPersonId="runner"}end
verify("ordinary_tokenless_body_observation_admitted",observe()==true
    and Per.conceptContext("runner",100).status=="observed"
    and P.conceptInquiryOffer("runner","relief-from-tiredness",100).status=="actionable")
freshConcepts();view.actorId="other"
verify("foreign_native_observation_rejected",observe()==false and Per.beliefs.runner.concepts==nil)
freshConcepts();observe();SAOJavaBridge.conceptObservations=nil
verify("missing_bridge_explicitly_unavailable",observe()==false and Per.conceptContext("runner",100).status=="observation-unavailable")
freshConcepts();view.frontiers={};observe()
verify("ungrounded_expectation_stays_unresolved",P.conceptInquiryOffer("runner","relief-from-tiredness",100).status=="unresolved" and __starts==0)
freshConcepts();observe();act();purpose=P.pending("runner","investigate")
Ctl.__inspectionProbeState(agent,"runner","IDLE","urgent need","need")
verify("interruption_preserves_unfinished_inquiry",purpose.status=="interrupted" and purpose.inquiry.path and not purpose.admission
    and agent.inquiryRoute==nil and __cancels>0)
local savedRecord=rec
agent={rec=savedRecord,state="IDLE"};Ctl.agents.runner=agent
verify("load_reconsiders_same_goal",act()=="inquiry" and P.pending("runner","investigate").id==purpose.id)
SAO.Locomotion.jobs.runner={body=body,done=true,result="arrived",goal={x=2,y=0,z=0}}
verify("replacement_job_cannot_complete_inquiry",Ctl.finishConceptInquiryMovement("runner",agent,body)==false
    and not purpose.inquiry.attempts[P.conceptFrontierKey(view.frontiers[1])] and purpose.status=="interrupted")
freshConcepts();observe();needs.hunger=.99
verify("urgent_need_precedes_inquiry",choose()==nil and __starts==0)
freshConcepts();observe();threat=true
verify("threat_precedes_inquiry",choose()==nil and __starts==0)
freshConcepts();retainedEdge("novel","seat",nil,true,"enables","other")
verify("foreign_retained_relation_rejected",K.infer("runner","novel","rest").status=="unresolved")
freshConcepts();retainedEdge("loop","loop",nil,true);retainedEdge("loop","node",nil,true);retainedEdge("node","loop",nil,true)
verify("cycles_terminate_without_claiming_end",K.infer("runner","loop","unreachable").status=="unresolved")
for i=1,9 do retainedEdge("depth"..i,"depth"..(i+1),nil,true) end
local bounded=K.infer("runner","depth1","depth10")
verify("depth_exhaustion_is_not_absence",bounded.status=="unresolved" and bounded.limitReached and bounded.omittedDerivations>0)
freshConcepts();observe();choose()
local thought=rec.ordinaryPurposeDecision.interpretations.models[1].interpretation
verify("conceptual_rationale_has_no_utility_numerics",not thought:find("%d") and not K.explain(cold.paths[1]):find("%d"))
freshConcepts();observe();Ctl.__fleeProbeDecide("runner",agent,body)
verify("full_live_decision_preserves_inquiry",agent.state=="TRAVEL" and agent.inquiryRoute and __starts==1 and admitted==nil)
__result="PASS concepts "..conceptChecks.."; inherited ordinary purpose "..checks
