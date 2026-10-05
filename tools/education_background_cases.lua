-- Appended to the existing actual Controller/ConceptKnowledge fixture.
local backgroundChecks=0
local function bgcheck(name,condition)
    if not condition then error("BACKGROUND:"..name) end
    backgroundChecks=backgroundChecks+1
end
for name,method in pairs(__educationBridge) do SAOJavaBridge[name]=method end
SAO.History.TICKS_PER_DAY=216000
SAO.History.ticks=function()return hours*9000 end
SAO.History.birthYearOf=function()return 1960 end
local E,R=SAO.Education,SAO.EducationRegistry
local world={sentinel=97}
bgcheck("source_registry_staged",R.load(world,_raw,_rawSha,_worldSha,_bankSha,_archiveSha,SAO.History.ticks()))
local function observedStove()
    freshConcepts();manual=nil;needs.fatigue=.1;needs.hunger=.65;foodCarried=false
    body.getX=function()return 9 end
    view.observations[1].key="room:B";view.observations[1].roomId="room:B";view.observations[1].x=9
    object("stove");view.observations[2].roomId="room:B";view.observations[2].x=9
    view.frontiers={};observe()
    body.getX=function()return 0 end
    view.observations={{key="room:A",concept="room",kind="room",buildingId="house:A",roomId="room:A",x=0,y=0,z=0}}
    view.frontiers={{key="door:A",kind="doorway",buildingId="house:A",roomId="room:A",x=1,y=0,z=0,entryX=2,entryY=0,entryZ=0,state="closed"}}
    observe()
end
observedStove()
bgcheck("unattached_background_refused",E.backgroundRelations("runner")==nil)
bgcheck("labels_not_content",K.infer("runner","stove","relief-from-hunger","house:A").status=="unresolved")
bgcheck("ordinary_actual_doorway",act()=="inquiry" and __starts==1 and __ordered.x==2)
local ordinaryUtilities={}
for _,candidate in ipairs(rec.ordinaryPurposeDecision.alternatives) do ordinaryUtilities[candidate.id]=candidate.utility end
observedStove()
bgcheck("canonical_person_attached",R.attach("runner",SAO.History.ticks(),1960))
local before=rec.education
local roots=E.backgroundRelations("runner")
bgcheck("supported_content_acquired",roots and #roots==2 and roots[1].from=="stove" and roots[2].into=="eating")
bgcheck("source_and_acquisition_retained",roots[1].sourceUnitId=="household-science-90255-95959-grade-8-practical-arts"
    and roots[1].exposureStartYear==1973 and roots[1].exposureEndYear==1974
    and roots[1].sourceInstitutionId=="source-region-school" and roots[1].retention=="unassessed"
    and roots[1].conditions[1]=="suitable-food" and roots[1].modal and roots[1].worldSha256==_worldSha)
roots[1].from="forged";roots[1].conditions[1]="all-food-created"
bgcheck("private_read_detached",E.backgroundRelations("runner")[1].from=="stove"
    and E.backgroundRelations("runner")[1].conditions[1]=="suitable-food" and rec.education==before)
bgcheck("no_native_or_assessment_grant",#E.conditioning("runner",SAO.History.ticks()).concepts==0
    and rec.cookReceipts==nil and rec.recoveryExperiences==nil)
local inferred=K.infer("runner","stove","relief-from-hunger","house:A")
bgcheck("background_composes_expectation",inferred.status=="expectation" and inferred.paths[1].modal
    and inferred.paths[1].roots[1].basis=="generated-schooling-exposure")
bgcheck("background_changes_actual_route",act()=="inquiry" and __starts==1 and __ordered.x==9
    and rec.ordinaryPurposeDecision.inquiry.mode=="remembered-means")
local fixed=true
for _,candidate in ipairs(rec.ordinaryPurposeDecision.alternatives) do
    if ordinaryUtilities[candidate.id]~=candidate.utility then fixed=false end
end
bgcheck("same_utilities_personal_content",fixed)
bgcheck("inquiry_is_not_cooking_completion",admitted==nil and rec.cookReceipts==nil
    and rec.ordinaryPurposeDecision.inquiry.path.into=="relief-from-hunger")
local saved=__roundtrip(rec)
local savedWorld=__roundtrip(world)
local savedBeliefs=__roundtrip(Per.beliefs.runner)
observedStove();rec=saved;agent.rec=rec;Per.beliefs.runner=savedBeliefs
R.clear()
bgcheck("reload_needs_independent_source_binding",E.backgroundRelations("runner")==nil)
bgcheck("saved_world_rebind",R.bind(savedWorld,_rawSha,_worldSha,_bankSha,_archiveSha,SAO.History.ticks()))
-- Clear retained active admission, just as reconstruction does; the unfinished
-- purpose and its source-held premise survive native table serialization.
for _,purpose in pairs(rec.proceduralPlanning and rec.proceduralPlanning.purposes or {}) do purpose.admission=nil end
bgcheck("saved_person_same_background_choice",act()=="inquiry" and __ordered.x==9
    and E.backgroundRelations("runner")[1].exposureReceiptSha256==inferred.paths[1].roots[1].exposureReceiptSha256)
observedStove();R.attach("runner",SAO.History.ticks(),1960)
retainedEdge("stove","cooking","house:A",false,"affords")
bgcheck("contrary_personal_evidence_defeats_background",K.infer("runner","stove","relief-from-hunger","house:A").status=="challenged"
    and act()=="inquiry" and __ordered.x==2)
observedStove();R.attach("runner",SAO.History.ticks(),1960);permission=false
local deniedKind,deniedOffer=choose()
bgcheck("background_grants_no_permission",deniedKind=="inquiry" and not Ctl.dispatchOrdinaryPurpose("runner",agent,body,100,needs,deniedKind,deniedOffer)
    and __starts==0)
observedStove();R.attach("runner",SAO.History.ticks(),1960);rec.dead=true
bgcheck("dead_person_refused",E.backgroundRelations("runner")==nil)
rec.dead=nil
local ownGet=SAO.Identity.get
local other={id="unexposed",occupation="cook",culture="source-region",age=33}
SAO.Identity.get=function(id)if id=="unexposed" then return other end return ownGet(id)end
bgcheck("unexposed_person_attaches_without_content",R.attach("unexposed",SAO.History.ticks(),1960)
    and #E.backgroundRelations("unexposed")==0)
SAO.Identity.get=function()return other end
bgcheck("misfiled_identity_refused",E.backgroundRelations("runner")==nil)
SAO.Identity.get=function(id)if id=="unexposed" then return other end return ownGet(id)end
other.education=__roundtrip(rec.education)
bgcheck("foreign_person_prior_refused",E.backgroundRelations("unexposed")==nil)
SAO.Identity.get=ownGet
R.clear()
bgcheck("foreign_world_refused",not R.bind(savedWorld,_rawSha,string.rep("d",64),_bankSha,_archiveSha,SAO.History.ticks()))
bgcheck("refusal_exposes_no_roots",E.backgroundRelations("runner")==nil)
_persistedWorld=savedWorld;_persistedActor=saved
__result="PASS background "..backgroundChecks.."; inherited concepts "..conceptChecks.."; ordinary "..checks
