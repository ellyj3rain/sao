-- Appended within the full conceptual/ordinary-purpose fixture. Identity,
-- dated admission and present clarity are controlled; real recall, inference,
-- planning and Controller movement admission execute in installed Kahlua.
freshConcepts()
local M=SAO.PersonalMemory
SAO.PopulationAdmissions={}
local clarity=1
SAO.Neuro={clarityOf=function(person)assert(person==rec);return clarity end}
SAO.History.countyInstant=function(at)
    return string.format("1993-01-01T%02d:00:00",math.floor(at)%24)
end
local initial
verify("memory_provider_bound",M.bindInitialProvider(SAO.PopulationAdmissions,function(person)
    return person==rec and initial or nil
end))
view.observations[1].concept="factory"
observe()
verify("without_life_no_factory_rest_inference",K.infer("runner","factory","relief-from-tiredness","house:A").status=="unresolved"
    and P.conceptInquiryOffer("runner","relief-from-tiredness",100).status=="unresolved")
local sha=string.rep("a",64)
initial={schema="sao-personal-memory-initial/1",personId="runner",definitionSha256=sha,
    issuerId="initial-cohort:"..sha,sourceId="study-definition:"..sha,sourceSha256=sha,
    worldId=sha,saveId="reasoning-fixture",admissionKey=sha..":runner:1",admittedAtHours=12,
    startDate="1993-01-01",cutoffDate="1993-01-01",birthYear=1960,episodes={
        {id="first-job-break-room",ownerId="runner",occurredOn="1978-06-01",acquiredOn="1978-06-01",
            participants={"prior-coworker"},subject="factory",action="worked",
            description="During my first job, I slept on the break-room cot after a long shift.",
            valence=.4,salience=.95,sourceId="authored-work-life/runner",sourceSha256=sha,
            provenance="authored-synthetic",relations={{from="factory",relation="may-contain",into="bed",confidence=.9}}},
        {id="movie-night",ownerId="runner",occurredOn="1992-11-06",acquiredOn="1992-11-06",
            participants={"prior-loved-one"},subject="cinema",action="watched",
            description="I watched a movie beside my loved one and remembered their laughter.",
            valence=.9,salience=.8,sourceId="authored-personal-life/runner",sourceSha256=sha,
            provenance="authored-synthetic",relations={}}
    }}
verify("life_attached_for_actual_reasoner",M.attachInitial(rec))
local held=M.snapshot("runner")
local learned=K.infer("runner","factory","relief-from-tiredness","house:A")
verify("dated_first_job_changes_inferred_means",learned.status=="expectation" and learned.paths[1].roots[1].basis=="autobiographical-association"
    and learned.paths[1].roots[1].episodeId=="first-job-break-room"
    and learned.paths[1].roots[1].occurredOn=="1978-06-01")
verify("loved_one_memory_retains_content",M.query("runner","cinema").episodes[1].participants[1]=="prior-loved-one"
    and M.query("runner","cinema").episodes[1].description:find("laughter")~=nil)
local offer=P.conceptInquiryOffer("runner","relief-from-tiredness",100)
verify("own_history_supplies_current_inquiry",offer.status=="actionable" and offer.desiredConcept=="bed"
    and offer.path.roots[1].modal and offer.path.roots[1].x==nil)
verify("shared_controller_dispatches_history_inquiry",act()=="inquiry" and agent.inquiryRoute and __starts==1 and admitted==nil)
verify("history_not_granted_native_success",rec.nativeXP==nil and offer.path.status=="expectation")
clarity=0
verify("present_impairment_withholds_recalled_premise",M.query("runner").status=="inaccessible"
    and K.infer("runner","factory","relief-from-tiredness","house:A").status=="unresolved")
clarity=1
verify("recovery_restores_recall_without_new_history",K.infer("runner","factory","relief-from-tiredness","house:A").status=="expectation"
    and M.snapshot("runner").initial.episodes[1].description==held.initial.episodes[1].description)
local oldSource=initial.saveId
initial.saveId="foreign-save"
verify("rebound_custody_cannot_support_inference",M.query("runner").status=="unavailable"
    and K.infer("runner","factory","relief-from-tiredness","house:A").status=="unresolved")
initial.saveId=oldSource
local recordBefore=M.snapshot("runner")
local query=K.infer("runner","factory","relief-from-tiredness","house:A")
query.paths[1].roots[1].sourceId="changed-return"
verify("rationale_detached_from_life_source",M.snapshot("runner").initial.episodes[1].sourceId==recordBefore.initial.episodes[1].sourceId
    and K.infer("runner","factory","relief-from-tiredness","house:A").paths[1].roots[1].sourceId~=query.paths[1].roots[1].sourceId)
local originalRecord=SAO.Identity.get
SAO.Identity.get=function(id)if id=="other" then return {id="other"} end;return originalRecord(id)end
verify("autobiography_not_automatically_taught",K.teachingOffer("runner","other")==nil)
SAO.Identity.get=originalRecord
-- Historical contrary experience remains attributable without vetoing current
-- personally observed relations. This is a retained evidence fixture, not an
-- observation of absence or a clinical interpretation of the remembered event.
initial.episodes[1].relations[1].affirmed=false
rec.personalMemory=nil
verify("counterexample_history_attached",M.attachInitial(rec))
retainedEdge("factory","bed","house:A",true,"contains")
local reconciled=K.infer("runner","factory","relief-from-tiredness","house:A")
verify("fresh_positive_survives_recalled_counterexample",reconciled.status=="expectation" and #reconciled.paths>0
    and reconciled.contradictions[1].status=="recalled-counterexample"
    and reconciled.contradictions[1].episodeId=="first-job-break-room")
initial.episodes={}
for i=1,5 do
    local episode={id="many-premises-"..i,ownerId="runner",occurredOn="1992-12-01",acquiredOn="1992-12-01",
        participants={},subject="work",action="worked",description="An authored work recollection with bounded associations.",
        valence=.5,salience=.9,sourceId="authored-many-premises",sourceSha256=sha,provenance="authored-synthetic",relations={}}
    for j=1,16 do
        local n=(i-1)*16+j
        episode.relations[j]={from="historical-premise-"..n,relation="supports",into="detail-"..n,confidence=.9}
    end
    initial.episodes[i]=episode
end
initial.episodes[5].relations[16]={from="factory",relation="may-contain",into="bed",confidence=.9}
rec.personalMemory=nil;rec.conceptKnowledge=nil
verify("large_history_attached",M.attachInitial(rec))
local partial=K.infer("runner","factory","relief-from-tiredness","house:A")
verify("omitted_history_is_not_claimed_complete",partial.status=="unresolved" and partial.limitReached and partial.omittedRelations==16)
__result="PASS autobiography reasoning "..conceptChecks.."; inherited ordinary purpose "..checks
