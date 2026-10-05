-- Uses the existing production Controller/Perception/ConceptKnowledge fixture.
-- The native visible workshop cue is controlled here; native producer proof is separate.
local exposureChecks=0
local function ec(name,condition)
    if not condition then error("EXPOSURE:"..name) end
    exposureChecks=exposureChecks+1
end
for name,method in pairs(__educationBridge) do SAOJavaBridge[name]=method end
SAO.History.TICKS_PER_DAY=216000
SAO.History.ticks=function()return hours*9000 end
SAO.History.birthYearOf=function()return 1960 end
local E,R=SAO.Education,SAO.EducationRegistry
local world={sentinel=98}
ec("registry_three_admitted",R.load(world,_raw,_rawSha,_worldSha,_bankSha,_archiveSha,SAO.History.ticks()))
local function workshop()
    freshConcepts();needs.fatigue=.1
    view.observations[1].concept="workshop"
    observe()
end
workshop()
ec("unattached_content_unknown",K.infer("runner","workshop","tools","house:A").status=="unresolved")
ec("unattached_no_inquiry",P.conceptInquiryOffer("runner","tools",100).status=="unresolved" and __starts==0)
ec("person_prior_attached",R.attach("runner",SAO.History.ticks(),1960))
local prior=rec.education
local roots=E.backgroundRelations("runner")
local work,civic
for _,edge in ipairs(roots or {}) do
    if edge.basis=="authored-work-training-exposure" and edge.from=="workshop" then work=edge end
    if edge.basis=="authored-community-literary-exposure" then civic=edge end
end
ec("two_authored_sources_distinct",#roots==(__workbenchProof and 5 or 4) and work and civic and work.exposureReceiptSha256~=civic.exposureReceiptSha256)
ec("work_exact_source_event",work.from=="workshop" and work.into=="tools" and work.sourceRegionId=="source-region"
    and work.exposureStartYear==1982 and work.exposureEndYear==1983 and work.exposureEventId=="work-reading-1982"
    and work.acquisitionChannel=="guided-practice" and work.carrierId=="explicit-workshop"
    and work.sourceInstitutionId==nil and #work.contentExposureHistorySha256==64)
ec("civic_exposure_has_no_assent",civic.contentRole=="reported-norm" and civic.assent=="not-established"
    and civic.retention=="unassessed" and civic.conditions[2]=="voluntary-participation"
    and civic.conditions[3]=="response-unconfirmed" and rec.organization==nil)
work.conditions[1]="forged";work.from="forged"
local fresh=E.backgroundRelations("runner")
ec("query_detached_no_relearning",fresh[3].from=="workshop" and fresh[3].conditions[1]=="personally-observed-place"
    and rec.education==prior)
local inferred=K.infer("runner","workshop","tools","house:A")
ec("work_content_changes_shared_inference",inferred.status=="expectation" and inferred.paths[1].modal)
local offer=P.conceptInquiryOffer("runner","tools",100)
ec("actual_planner_selects_content_inquiry",offer.status=="actionable" and offer.desiredConcept=="tools"
    and offer.frontier.entryX==2 and offer.path.roots[1].basis=="authored-work-training-exposure")
ec("actual_controller_dispatches_selected_inquiry",Ctl.dispatchOrdinaryPurpose("runner",agent,body,100,needs,"inquiry",{payload=offer})
    and __starts==1 and __ordered.x==2)
ec("inquiry_did_not_produce_tools_or_mastery",#E.conditioning("runner",SAO.History.ticks()).concepts==0
    and rec.cookReceipts==nil and admitted==nil)
local saved=__roundtrip(rec);local savedWorld=__roundtrip(world)
local savedBeliefs=__roundtrip(Per.beliefs.runner)
workshop();rec=saved;agent.rec=rec;Per.beliefs.runner=savedBeliefs;R.clear()
ec("reload_without_binding_unknown",E.backgroundRelations("runner")==nil)
ec("reload_source_rebind",R.bind(savedWorld,_rawSha,_worldSha,_bankSha,_archiveSha,SAO.History.ticks()))
for _,purpose in pairs(rec.proceduralPlanning and rec.proceduralPlanning.purposes or {}) do purpose.admission=nil end
offer=P.conceptInquiryOffer("runner","tools",100)
ec("reload_retains_source_and_selected_action",offer.status=="actionable"
    and offer.path.roots[1].exposureReceiptSha256==inferred.paths[1].roots[1].exposureReceiptSha256
    and Ctl.dispatchOrdinaryPurpose("runner",agent,body,100,needs,"inquiry",{payload=offer}) and __ordered.x==2)
workshop();R.attach("runner",SAO.History.ticks(),1960)
retainedEdge("workshop","tools","house:A",false,"may-contain")
ec("contrary_private_evidence_changes_actual_action",K.infer("runner","workshop","tools","house:A").status=="challenged"
    and P.conceptInquiryOffer("runner","tools",100).status=="unresolved" and __starts==0)
workshop();R.attach("runner",SAO.History.ticks(),1960)
local meaning=K.infer("runner","family-cooperation","possible-mutual-support")
ec("civic_conditional_mechanism_only",meaning.status=="expectation" and meaning.paths[1].modal
    and meaning.paths[1].roots[1].assent=="not-established" and rec.organization==nil)
ec("no_completed_consequence_from_norm",rec.cognition==nil or #(rec.cognition.experiences or {})==0)
permission=false;offer=P.conceptInquiryOffer("runner","tools",100)
ec("source_grants_no_permission",not Ctl.dispatchOrdinaryPurpose("runner",agent,body,100,needs,"inquiry",{payload=offer}) and __starts==0)
permission=true
local own=SAO.Identity.get;local other={id="unexposed",occupation="mechanic",culture="source-region"}
SAO.Identity.get=function(id)if id=="unexposed" then return other end return own(id)end
ec("labels_and_empty_history_unknown",R.attach("unexposed",SAO.History.ticks(),1960)
    and #E.backgroundRelations("unexposed")==0 and K.infer("unexposed","workshop","tools").status=="unresolved")
other.education=__roundtrip(rec.education)
ec("foreign_retained_prior_refused",E.backgroundRelations("unexposed")==nil)
SAO.Identity.get=own
SAO.History.birthYearOf=function()return 1961 end
ec("current_birth_refusal_hides_content",E.backgroundRelations("runner")==nil)
SAO.History.birthYearOf=function()return 1960 end
_persistedWorld=savedWorld;_persistedActor=saved
__result="PASS background exposures "..exposureChecks.."; inherited concepts "..conceptChecks.."; ordinary "..checks
