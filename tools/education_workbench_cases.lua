-- Actual Perception object row, private source-backed meaning, ordinary chooser,
-- Controller, Locomotion and WorldSources. Only native visibility, route and
-- inventory receivers are controlled; native workbench production is separate.
local benchChecks=0
local function bc(name,condition)
    __lastWorkbenchCase=name
    if not condition then error("WORKBENCH:"..name) end
    benchChecks=benchChecks+1
end
local W=__workbenchWorldSources
local function empty(value)for _ in pairs(value or {}) do return false end return true end
local sourceId,otherSource="C:bench:0","C:other:0"
local fingerprint=string.rep("a",64)
local memories,candidateCalls,inspectCalls,nativePermission,visibleSource
SAO.History.ticksFromHours=function(h)return h*9000 end
SAO.Lessons.desperationBump=function()return 0 end
local function candidateRow(id,x)
    return "C|id="..id.."|fp="..fingerprint.."|sx="..x.."|sy=0|sz=0|x="..(x-1).."|y=0|z=0|reachable=1\n"
end
SAOJavaBridge.worldInspectionMemory=function(_,b)
    memories[b]=memories[b] or {};return memories[b]
end
SAOJavaBridge.worldInspectionCandidates=function()
    candidateCalls=candidateCalls+1
    return "H|protocol=SAOWI1\n"..candidateRow(otherSource,6)
        ..(visibleSource and candidateRow(sourceId,3) or "").."E\n"
end
SAOJavaBridge.worldInspectContainer=function(_,b,id,fp,x,y,z)
    inspectCalls=inspectCalls+1
    bc("native_receiver_exact_holder",id==sourceId and fp==fingerprint and x==3 and y==0 and z==0)
    return "I|source="..sourceId.."\nH|protocol=SAOWS1|status=OBSERVED|detail=|mode=controlled-native|cx=0|cy=0|revision=r1|sources=1\n"
        .."S|id="..sourceId.."|fp="..fingerprint.."|rev=s1|kind=container|x=3|y=0|z=0|building=house:A|explored=1|state=spent|access=accessible|container=workbench\nE\n"
end
local function bench()
    freshConcepts();needs.fatigue=.1;SAO.WorldSources=W;W.resetRuntime()
    SAO.SourceUse=nil
    memories={};candidateCalls=0;inspectCalls=0;nativePermission=true;visibleSource=true
    SAO.Standing.mayTakeCurrent=function()return nativePermission end
    object("workbench")
    local row=view.observations[#view.observations]
    row.key="object:bench";row.sourceId=sourceId;row.x=3;row.y=0
    observe()
end
local function attach()bc("same_person_receipt_attached",R.attach("runner",SAO.History.ticks(),1960))end
local function offered()return P.conceptInquiryOffer("runner","tools",100)end
local function dispatch(value)
    return Ctl.dispatchOrdinaryPurpose("runner",agent,body,100,needs,"inquiry",{payload=value or offered()})
end
local function currentPurpose()
    local context=agent.forageInspection
    local receipt=context and W.inspectionOutcome("runner",context.purposeInspectionId)
    return receipt and rec.proceduralPlanning.purposes[receipt.purposeId],receipt
end
bench()
bc("unexposed_bench_unknown",K.infer("runner","workbench","tools","house:A").status=="unresolved"
    and offered().status=="unresolved" and __starts==0)
attach()
local result=K.infer("runner","workbench","tools","house:A")
local root=result.paths and result.paths[1] and result.paths[1].roots[1]
bc("conditional_bench_content",result.status=="expectation" and root and root.modal
    and root.conditions[1]=="observed-purpose-specific-workbench" and root.conditions[2]=="contents-unconfirmed"
    and root.exposureReceiptSha256==K.infer("runner","workshop","tools").paths[1].roots[1].exposureReceiptSha256)
local offer=offered()
bc("actual_object_holder_inquiry_selected",offer.status=="actionable" and offer.mode=="inspect-holder"
    and offer.sourceId==sourceId and offer.observedMeans.kind=="object" and offer.path.roots[1].from=="workbench"
    and offer.frontier==nil and offer.approach==nil)
bc("query_does_not_select_native_holder",candidateCalls==0 and inspectCalls==0 and rec.proceduralPlanning==nil
    and empty(memories) and empty(Per.knownPlaces("runner",true)))
bc("actual_bench_route_dispatched",dispatch(offer) and __starts==1 and __ordered.x==2
    and __ordered.x~=offer.observedMeans.x and agent.state=="FORAGE" and candidateCalls==1)
local purpose,receipt=currentPurpose()
bc("typed_native_inspection_admitted",purpose and receipt and receipt.status=="admitted"
    and purpose.inquiry.goal=="tools" and purpose.steps[1].token=="inquiry:inspected"
    and purpose.steps[1].sourceId==sourceId and purpose.steps[1].fingerprint==fingerprint and inspectCalls==0)
bc("generic_completion_cannot_finish_inquiry",not P.recordResult("runner",purpose.id,{owner="SAO.WorldSources",
    token="inquiry:inspected",status="completed",correlationId=receipt.id}) and purpose.status~="completed")
local fake=__roundtrip(receipt);fake.id="invented-inspection";fake.status="completed";fake.nativeInspected=true;fake.privateLearned=true
bc("invented_native_receipt_refused",not P.consumeInspectionResult("runner",fake))
-- A genuine admitted personal goal remains the same while its current evidence
-- changes. Other candidate utilities and personality/body inputs stay fixed.
Ctl.__inspectionProbeState(agent,"runner","FLEE","danger")
SAO.Locomotion.cancel("runner");agent.state="IDLE"
bc("interrupted_holder_keeps_goal",purpose.inquiry.goal=="tools" and purpose.status=="maintained"
    and purpose.admission==nil and W.inspectionOutcome("runner",receipt.id).status=="interrupted" and inspectCalls==0)
local kind,choice=Ctl.chooseOrdinaryPurpose("runner",agent,body,100,needs)
local sameUtility=rec.ordinaryPurposeDecision.alternatives[#rec.ordinaryPurposeDecision.alternatives].utility
bc("ordinary_chooser_resumes_genuine_inquiry",kind=="inquiry" and choice.payload.sourceId==sourceId and candidateCalls==1)
R.clear()
local without=Ctl.chooseOrdinaryPurpose("runner",agent,body,100,needs)
bc("same_utilities_missing_private_content_changes_choice",without=="continue"
    and rec.ordinaryPurposeDecision.alternatives[#rec.ordinaryPurposeDecision.alternatives].utility==sameUtility
    and purpose.inquiry.goal=="tools" and candidateCalls==1)
bc("provider_restored",R.bind(world,_rawSha,_worldSha,_bankSha,_archiveSha,SAO.History.ticks()))
kind,choice=Ctl.chooseOrdinaryPurpose("runner",agent,body,100,needs)
bc("restored_content_rejoins_actual_choice",kind=="inquiry" and Ctl.dispatchOrdinaryPurpose("runner",agent,body,100,needs,kind,choice))
purpose,receipt=currentPurpose()
__verdict="Succeeded";Ctl.__fleeProbeTick(101)
Ctl.__followProbeMovement("runner",agent,body)
local completed=W.inspectionOutcome("runner",receipt.id)
local known=Per.knownPlaces("runner",true)["source:"..sourceId]
bc("native_inspection_updates_only_private_holder",inspectCalls==1 and completed.status=="completed"
    and completed.nativeInspected and completed.privateLearned and completed.planningAcknowledged
    and known.sourceFacts[sourceId].state=="spent" and known.sourceFacts[otherSource]==nil)
bc("inspection_does_not_complete_material_goal",purpose.status=="maintained" and purpose.inquiry.goal=="tools"
    and purpose.admission==nil and empty(rec.proceduralPlanning.practice) and rec.cookReceipts==nil
    and purpose.inquiry.attempts["holder:"..sourceId].receiptId==receipt.id)
local version=#purpose.events;W.reconcilePurposeInspections("runner",body)
bc("canonical_inspection_delivered_once",#purpose.events==version)
bc("same_holder_not_repeated",offered().status=="unresolved" and #P.pendingConceptInquiries("runner",100)==0)
local oneHolderBeliefs=__roundtrip(Per.beliefs.runner)
object("workbench")
local otherHolder=view.observations[#view.observations]
otherHolder.key="object:other-holder";otherHolder.sourceId=otherSource;otherHolder.x=6;otherHolder.y=0
observe()
bc("inspection_is_exact_holder_not_all_bench_contents",offered().sourceId==otherSource
    and K.infer("runner","workbench","tools","house:A").status=="expectation")
Per.beliefs.runner=oneHolderBeliefs
local saved=__roundtrip(rec);local savedBeliefs=__roundtrip(Per.beliefs.runner)
rec=saved;agent.rec=rec;Per.beliefs.runner=savedBeliefs;W.resetRuntime()
W.reconcilePurposeInspections("runner",body)
bc("completed_private_attempt_survives_reload",offered().status=="unresolved"
    and rec.proceduralPlanning.purposes[purpose.id].status=="maintained" and inspectCalls==1)
bench();attach();dispatch()
purpose,receipt=currentPurpose();rec=__roundtrip(rec);agent.rec=rec
W.resetRuntime();W.reconcilePurposeInspections("runner",body)
purpose=rec.proceduralPlanning.purposes[purpose.id]
bc("reload_pending_never_fakes_inspection",W.inspectionOutcome("runner",receipt.id).status=="interrupted"
    and purpose.admission==nil and purpose.inquiry.goal=="tools" and inspectCalls==0 and purpose.status=="maintained")
bench();attach();retainedEdge("workbench","tools","house:A",false,"may-contain")
bc("observed_contrary_bench_blocks_inquiry",K.infer("runner","workbench","tools","house:A").status=="challenged"
    and offered().status=="unresolved" and __starts==0)
bench();attach();view.observations[#view.observations].sourceId=nil;observe()
bc("object_without_native_holder_unresolved",offered().status=="unresolved" and candidateCalls==0)
bench();attach();offer=offered();visibleSource=false
bc("absent_exact_holder_does_not_pick_other",not dispatch(offer) and __starts==0 and inspectCalls==0)
bench();attach();offer=offered();nativePermission=false
bc("current_native_permission_refuses_before_route",not dispatch(offer) and __starts==0)
bench();attach();offer=offered();permission=false
bc("believed_permission_refuses_before_candidate",not dispatch(offer) and candidateCalls==0 and __starts==0)
bench();attach();offer=offered();owned=true
bc("busy_body_retains_current_owner",not dispatch(offer) and candidateCalls==0 and __starts==0)
bench();attach();offer=offered();retainedEdge("workbench","tools","house:A",false,"may-contain")
bc("selected_path_rechecked_before_native_offer",not dispatch(offer) and candidateCalls==0 and __starts==0)
bench();attach();offer=offered();offer.sourceId=otherSource
bc("changed_selected_source_refused",not dispatch(offer) and candidateCalls==0 and __starts==0)
bench();attach();dispatch();purpose,receipt=currentPurpose()
W.inspectionFailed("runner",body,agent.forageInspection,"done:Failed")
bc("failed_approach_no_inspection_or_learning",inspectCalls==0 and purpose.status=="maintained"
    and purpose.inquiry.goal=="tools" and purpose.admission==nil
    and W.inspectionOutcome("runner",receipt.id).nativeInspected==false)
-- Existing resource inspection token retains its own canonical receipt path.
-- The maintained food plan is a controlled input; admission, native inspection,
-- private acquisition and result consumption below are production owners.
bench()
local context=W.inspectionCandidate("runner",body,"standing",12,sourceId)
local foodPurpose=P.maintain("runner",{key="legacy-food-inspection",domain="provisioning",objective="seek food"})
foodPurpose.resourceCategory="food"
foodPurpose.steps={{id="legacy-inspect",owner="SAO.WorldSources",verb="inspect",token="resource:inspected",
    status="available",target=sourceId,sourceId=sourceId,fingerprint=context.fingerprint,
    sourceX=context.sourceX,sourceY=context.sourceY,sourceZ=context.sourceZ}}
foodPurpose.cursor=1
bc("legacy_resource_inspection_admitted",W.beginPurposeInspection("runner",body,context,foodPurpose.id,"legacy-inspect")~=nil)
bc("legacy_resource_inspection_consumes_actual_owner",W.inspectContainer("runner",body,context)
    and foodPurpose.steps[1].status=="completed" and foodPurpose.status=="maintained"
    and foodPurpose.awaitingReassessment and foodPurpose.admission==nil)
bc("legacy_empty_inspection_does_not_satisfy_food",foodPurpose.resourceCategory=="food"
    and Per.knownPlaces("runner",true)["source:"..sourceId].sourceFacts[sourceId].state=="spent")
__result=__result.."; workbench "..benchChecks
