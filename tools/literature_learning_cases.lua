-- Real native items/actions/source receivers; controlled people, clocks,
-- route arrival, scheduling and body presentation. Explicit response overrides
-- below are labeled synthetic and prove admission/scoring, not general policy.
local S,K,P,C,Q=SAO.Study,SAO.ConceptKnowledge,SAO.ProceduralPlanning,SAO.Cognition,SAO.Knowledge
local nativeContext,nativeMemories=SAO.Perception.conceptContext,SAO.Perception.conceptMemories
local count=0
local function check(name,value)
    print("LITERATURE "..name.."="..tostring(value==true));count=count+1
    assert(value==true,"LITERATURE_FAILED:"..name)
end
local originalBridge=SAOJavaBridge
SAOJavaBridge=setmetatable({observeWorldChunk=function()return __materialSnapshot()end},
    {__index=function(_,key)return function(_,...)return originalBridge[key](originalBridge,...)end end})
SAO.Body={get=function(id)return __bodies[id]end,active={},foreign={}}
SAO.Standing={mayAttemptBelieved=function()return true end,mayTakeCurrent=function()return true end,
    provisioningContextAt=function()return "personal" end,groupOf=function()end}
SAO.Places={at=function()end};SAO.Perception.knownPlaces=function(id)return __known[id]or{}end
SAO.Perception.learnInspectedSource=function()return true end
SAO.Locomotion={order=function()return true end,cancel=function()end}
SAO.Needs.busy=function()return __queue~=nil end
SAO.Needs.resetOwnedQueue=function(a)if __queue==a then __queue=nil end end
ISTimedActionQueue.clear=function(body)__queue=nil;body:getCharacterActions():clear()end
ISInventoryTransferAction.soundDelay=0
__records={person={id="person",bodyOwnerToken="literature-test",testAge=30,discipline=.85},other={id="other",bodyOwnerToken="literature-other",testAge=30,discipline=.85}}
__bodies={person=__body,other=__other};__known={};SAO.Body.active=__bodies
SAO.Controller.agents={person={rec=__records.person,state="IDLE"},other={rec=__records.other,state="IDLE"}}
__body:getModData().SAOPersonId="person";__body:getModData().SAOExternalToken="literature-test"
__other:getModData().SAOPersonId="other";__other:getModData().SAOExternalToken="literature-other"
__body:setAsleep(false);__body:setHealth(100);__other:setAsleep(false);__other:setHealth(100)
__clearInventory();__queue=nil
local items={}
for _,topic in ipairs({"Civilian","Engineering","Military"})do
    local item=__newPamphlet(topic);items[topic]=item
    local d=S.sources.definition(item:getFullType())
    check("native_carrier_"..topic:lower(),item:canBeWrite() and item:getCustomPages():size()==4
        and item:getName()=="Buildings, routes and upkeep: "..topic:lower() and item:getLuaCreate()=="SAO_Literature_OnCreate")
    check("native_oncreate_exact_"..topic:lower(),S.sources.binding(item)~=nil and item:seePage(1)==d.pages[1])
    check("native_oncreate_idempotent_"..topic:lower(),SAO_Literature_OnCreate(item) and item:getCustomPages():size()==4)
    check("source_provenance_"..topic:lower(),d.authoredDate=="2026-10-11" and d.edition=="fictional-simulated-1992"
        and d.historicalPublication==false and d.textHash==__literalHash(table.concat(d.pages,"\n")) and d.license=="GPL-3.0")
end
local held=items.Civilian
__year=1991
check("before_fictional_edition_refused",S.sources.binding(held)==nil)
__year=1993
local restored=__itemReload(held)
check("native_item_save_reload_pages_binding",S.sources.binding(restored)~=nil and restored:seePage(4)==held:seePage(4))
for _,name in ipairs({"BookstoreBooks","LibraryBooks"})do
    local pool=ProceduralDistributions.list[name];local before=#pool.items
    assert(SAO.LiteratureLoot.install());local counts={}
    for index=1,#pool.items,2 do counts[pool.items[index]]=(counts[pool.items[index]]or 0)+1 end
    check("ordinary_pool_idempotent_"..name:lower(),before==#pool.items and counts[held:getFullType()]==1
        and counts[items.Engineering:getFullType()]==1 and counts[items.Military:getFullType()]==1 and before>6)
end
check("no_omniscient_exposure_or_assessment",S.sourceExposure("person",1)==nil and #K.assessedRelations("person")==0)
local W,Use=SAO.WorldSources,SAO.SourceUse
local snapshot=assert(W.parse(__setMaterialSource(held,false)));assert(W.applySnapshot(snapshot))
local sourceId="C:acquisition-native:0";local fact=assert(W.beliefFact(sourceId))
local place={id="source:"..sourceId,sourceId=sourceId,cx=__body:getX(),cy=__body:getY(),z=math.floor(__body:getZ()),
    minX=math.floor(__body:getX()),minY=math.floor(__body:getY()),maxX=math.floor(__body:getX())+1,maxY=math.floor(__body:getY())+1,
    sources={reading=true},sourceRevision=sourceId.."@"..fact.revision,sourceFacts={[sourceId]=fact}}
__known.person={[place.id]=place}
local options=W.actionOptions(place,"reading","person",__body,1,"standing","acquire")
local selected=options.options[1]
check("normal_private_source_option",selected~=nil and selected.parameters.itemId==held:getID()
    and not __body:getInventory():contains(held))
local otherOptions=W.actionOptions(place,"reading","other",__other,1,"standing","acquire")
check("unobserved_other_has_no_option",otherOptions==nil or #otherOptions.options==0)
local p,step,acquirePlace=P.planLeisureAcquisition("person",__body,selected,"reading",place)
check("normal_acquisition_purpose",p~=nil and step.verb=="acquire")
local params=selected.parameters
check("normal_sourceuse_admission",Use.beginAcquisition("person",__body,acquirePlace,"reading",{
    purposeId=p.id,purposeStepId=step.id,sourceId=params.sourceId,itemId=params.itemId,itemType=params.itemType,sourceRevision=params.revision})==true)
local reservation=W.pendingActionFor("person")
check("native_transfer_arrival",Use.onMovementDone("person",__body,"arrived")=="using" and __queue~=nil)
local action=__queue
__nativeAction(action.action,"start");__nativeAction(action.action,"progress",.4)
check("partial_transfer_does_not_grant_custody",not __body:getInventory():contains(held))
__nativeAction(action.action,"progress",1);__nativeAction(action.action,"perform");__queue=nil
check("ordinary_native_acquisition_custody",__body:getInventory():contains(held) and held:getContainer()==__body:getInventory())
check("normal_sourceuse_native_result",Use.tick("person",__body)=="completed")
local receipt=W.actionOutcome(reservation.id,"person")
check("normal_acquisition_exact_owner_result",receipt.actorId=="person" and receipt.measurement=="native-item-transfer" and P.consumeSourceResult(receipt))
check("normal_acquisition_replay_once",P.consumeSourceResult(receipt) and p.cursor==2)
local function read(id,body,item)
    assert(S.beginLeisure(id,body,item),"reading failed")
    local a=__queue
    __nativeAction(a.action,"start");__nativeAction(a.action,"progress",1);__nativeAction(a.action,"perform");__nativeAction(a.action,"complete")
    return a,S.sourceExposure(id,__records[id].studySequence)
end
local reading,e=read("person",__body,held)
check("actual_native_read_exact_exposure",e and e.actorId=="person" and e.itemId==tostring(held:getID())
    and e.workId==reading.workId and e.sourceId==S.sources.binding(held).sourceId and e.content.pages[4]==held:seePage(4))
check("reading_does_not_mint_understanding",#K.assessedRelations("person")==0 and __records.person.studyAssessmentOutcomes==nil)
local canonical=__records.person.noteReadingOutcomes[1]
canonical.status="interrupted"
check("incomplete_native_exposure_refused",S.sourceExposure("person",canonical.sequence)==nil)
canonical.status="completed"
local savedHash=canonical.literature.textHash;canonical.literature.textHash=string.rep("0",64)
check("wrong_exposure_hash_refused",S.sourceExposure("person",canonical.sequence)==nil)
canonical.literature.textHash=savedHash
canonical.literature.revision=2
check("wrong_exposure_revision_refused",S.sourceExposure("person",canonical.sequence)==nil)
canonical.literature.revision=1
check("wrong_person_exposure_refused",S.sourceExposure("other",canonical.sequence)==nil)
local page=held:seePage(1);held:addPage(1,page.." Edited.")
check("edited_literal_source_refused",S.sources.binding(held)==nil and not SAO_Literature_OnCreate(held) and S.learningOffer("person",__body)==nil)
held:addPage(1,page)
check("exact_revision_restoration_recognized",S.sources.binding(held)~=nil)
assert(C.configure(.5,12,3))
local exactOffer=assert(S.learningOffer("person",__body))
local exactItem=exactOffer.itemId;exactOffer.itemId="foreign-item"
check("wrong_assessment_item_refused",not S.beginAssessment("person",__body,exactOffer))
exactOffer.itemId=exactItem;exactOffer.actorId="other"
check("wrong_assessment_actor_refused",not S.beginAssessment("person",__body,exactOffer))
exactOffer.actorId="person";local exactHash=exactOffer.textHash;exactOffer.textHash=string.rep("0",64)
check("wrong_assessment_hash_refused",not S.beginAssessment("person",__body,exactOffer))
exactOffer.textHash=exactHash;exactOffer.revision=2
check("wrong_assessment_revision_refused",not S.beginAssessment("person",__body,exactOffer))
exactOffer.revision=1
SAO.Standing.mayAttemptBelieved=function()return false end
check("assessment_current_standing_refused",not S.beginAssessment("person",__body,exactOffer))
SAO.Standing.mayAttemptBelieved=function()return true end
local Ctl=SAO.Controller
local candidates,receivers=Ctl.leisureOffers("person",Ctl.agents.person,__body,10000)
local learningKey
for key,receiver in pairs(receivers)do if receiver.kind=="reading-assessment"then learningKey=key end end
check("ordinary_assessment_offer",learningKey~=nil)
local views=C.interpretPlans("person",candidates,{domain="ordinary-purpose",pressure=0})
check("ordinary_model_can_select_assessment",views~=nil and receivers[views.selected]~=nil)
check("ordinary_assessment_dispatch",Ctl.beginLeisureOffer("person",Ctl.agents.person,__body,10000,{key=learningKey,payload=receivers[learningKey]})==true)
local assessment=__queue
__nativeAction(assessment.action,"start");__nativeAction(assessment.action,"progress",1)
check("response_distinct_from_rubric",__records.person.studyAssessmentWork.responseOwner=="SAO.Cognition.literal-and-arithmetic/1"
    and __records.person.studyAssessmentWork.responseActorId=="person" and __records.person.studyAssessmentWork.response~=nil
    and S.assessmentOutcome("person",1)==nil)
__nativeAction(assessment.action,"perform");__nativeAction(assessment.action,"complete")
local learned=S.assessmentOutcome("person",1)
check("source_bound_literal_response",learned and learned.verdict=="passed" and #K.assessedRelations("person")==6)
local modelBefore=C.snapshot("person",true)
check("distinct_assessment_cognition_owner",C.assessmentOutcome("person",1)==true and modelBefore~=nil and #modelBefore.models==2
    and modelBefore.experiences[1].kind=="reading-assessment" and modelBefore.experiences[1].sourceId==e.sourceId)
local modelAfter=C.snapshot("person",true)
check("independent_models_receive_once",#modelBefore.experiences==#modelAfter.experiences
    and #modelAfter.models[1].beliefs>0 and #modelAfter.models[2].beliefs>0)
check("assessed_literal_inference",K.infer("person","room","privacy").status=="expectation"
    and K.infer("person","room","privacy").paths[1].roots[1].sourceId==e.sourceId)
check("no_unseen_local_facts",K.infer("person","room","privacy").paths[1].x==nil)
local seq=__records.person.conceptKnowledge.readingAssessments.sequence
check("assessment_replay_once",K.consumeAssessment("person",1) and __records.person.conceptKnowledge.readingAssessments.sequence==seq)
local Communication=SAO.Communication
-- Physical conversation admission is controlled here; the actual received
-- owner capability and its retirement execute production Communication.
Communication.canConverse=function()return true end
SAO.Standing.sameGroup=function()return false end;SAO.Standing.trust=function()return .8 end
local message=Communication.deliverConceptAssociation("person","other","spoken")
check("actual_received_teaching_owner",message~=nil and __records.other.conceptKnowledge~=nil
    and #K.assessedRelations("other")==0 and S.sourceExposure("other",1)==nil)
check("received_teaching_capability_retired",Communication.conceptReception(message)==nil)
local generic=Communication.send("person","other","concept-association",{from="room",relation="supports",into="privacy"})
Communication.deliver(generic)
check("generic_message_is_not_teaching",K.receiveAssociation("other",generic)==false)
local row=__records.person.conceptKnowledge.readingAssessments.rows[1]
row.actorId="other"
check("foreign_assessment_receipt_rejected",#K.assessedRelations("person")==0)
row.actorId="person"
__records.person=__roundTrip(__records.person);Ctl.agents.person.rec=__records.person
check("native_person_save_reload_learning",#K.assessedRelations("person")==6 and K.consumeAssessment("person",1))
local fresh=__freshLearning(__records.person,__hours,__sourcesPath,__conceptPath)
check("fresh_vm_retains_owned_assessment",#fresh==6 and fresh[1].actorId=="person")
local catalogue=Q.claimCatalogue("person",nil,90000,"literature-snapshot",{"literature"})
check("current_claim_catalogue_owned_source",catalogue and #catalogue.claims==6 and catalogue.claims[1].fact.textHash==e.textHash)
check("current_claim_selection",Q.selectClaims(catalogue,{snapshotRef=catalogue.snapshotRef,claimRefs={catalogue.claims[1].ref}})~=nil)
__year=1991
check("current_world_era_revalidates_saved_source",#K.assessedRelations("person")==0 and #Q.about("person","literature")==0)
__year=1993
local memory=K.assessmentMemory("person",e.sourceId)
local h=__body:getStats();h:set(CharacterStat.FATIGUE,.9);h:set(CharacterStat.PAIN,100)
local strained=K.assessmentMemory("person",e.sourceId)
check("current_health_changes_retrieval",strained.strength<memory.strength and strained.currentCondition.status=="acquired-current-body")
h:set(CharacterStat.FATIGUE,0);h:set(CharacterStat.PAIN,0)
__hours=__hours+.5;__records.person.testAge=31
check("aging_makes_retrieval_due",S.learningOffer("person",__body).mode=="retrieval")
__records.person.testAge=30
local function assess(id,body,item,response)
    local offer=assert(S.learningOffer(id,body,item));assert(S.beginAssessment(id,body,offer))
    local a=__queue;__nativeAction(a.action,"start")
    if response then assert(S.submitResponse(id,body,a.workId,response)) end
    __nativeAction(a.action,"progress",1);__nativeAction(a.action,"perform");__nativeAction(a.action,"complete")
    return S.assessmentOutcome(id,__records[id].studyAssessmentSequence)
end
local transfer=assess("person",__body,held)
check("heldout_literal_retrieval",transfer.verdict=="passed" and transfer.task.mode=="transfer")
__hours=__hours+24
local retrieved=assess("person",__body,held)
check("successful_explicit_retrieval",retrieved.verdict=="passed" and retrieved.task.mode=="retrieval")
local mutable=__records.person.conceptKnowledge.readingAssessments.rows[#K.assessmentReceipts("person")]
local oldTime=__hours;__hours=__hours+1000
check("old_memory_is_unavailable",#K.assessedRelations("person")==0 and K.assessmentMemory("person",e.sourceId).response==nil)
check("forgotten_cached_claim_refused",Q.selectClaims(catalogue,{snapshotRef=catalogue.snapshotRef,claimRefs={catalogue.claims[1].ref}})==nil)
local reacquired=assess("person",__body,held)
check("rereading_exposed_material_reacquires",reacquired.verdict=="passed" and reacquired.task.mode=="comprehension" and #K.assessedRelations("person")==6)
__hours=__hours+6
local wrong=assess("person",__body,held,{kind="structured-reconstruction",relations={},explanation="Synthetic wrong test response."})
check("incorrect_explicit_response_fails",wrong.verdict=="failed" and #K.assessedRelations("person")==0)
__hours=__hours+6
local unsupported=assess("person",__body,held,{kind="free-explanation",text="Synthetic semantic explanation."})
check("unsupported_semantic_response_unscored",unsupported.verdict=="unscored" and #K.assessedRelations("person")==0)
__hours=__hours+6;assert(assess("person",__body,held).verdict=="passed")
__give(items.Engineering,false)
local _,engineeringExposure=read("person",__body,items.Engineering)
local engineered=assess("person",__body,items.Engineering)
check("source_specific_arithmetic_comprehension",engineered.sourceId==engineeringExposure.sourceId and engineered.verdict=="passed" and engineered.response.days==4)
__hours=__hours+.5
local numericTransfer=assess("person",__body,items.Engineering)
check("heldout_quantity_transfer",numericTransfer.task.mode=="transfer" and numericTransfer.response.days==7 and numericTransfer.verdict=="passed")
__give(items.Military,false);local _,militaryExposure=read("person",__body,items.Military)
local military=assess("person",__body,items.Military)
check("military_conditional_arithmetic",military.verdict=="passed" and military.response.days==3
    and K.infer("person","passage","supply-continuity").status=="expectation")
check("distinct_source_inference",K.infer("person","room","serviceability").paths[1].roots[1].sourceId==engineeringExposure.sourceId
    and K.infer("person","passage","supply-continuity").paths[1].roots[1].sourceId==militaryExposure.sourceId)
-- Same physical source, separate exposure, response and private purpose.
__give(held,true);local _,otherExposure=read("other",__other,held)
local otherLearning=assess("other",__other,held)
check("same_pages_distinct_person_response",otherLearning.actorId=="other" and otherLearning.itemId==learned.itemId and otherLearning.verdict=="passed"
    and otherExposure.content.pages[1]==e.content.pages[1])
local highAttribute=K.assessmentPolicy("other",engineeringExposure.sourceId)
__records.other.discipline=.15
local lowAttribute=K.assessmentPolicy("other",engineeringExposure.sourceId)
check("attributes_change_formation_retention",lowAttribute.halfLifeHours<highAttribute.halfLifeHours)
__records.other.discipline=.85
local lowInterest=K.assessmentPolicy("other",engineeringExposure.sourceId)
local interestPurpose=P.maintain("other",{key="upkeep-interest",domain="construction",objective="investigate upkeep"})
local highInterest=K.assessmentPolicy("other",engineeringExposure.sourceId)
check("purpose_interest_changes_retention",highInterest.halfLifeHours>lowInterest.halfLifeHours)
interestPurpose.status="abandoned"
__hours=__hours+.5;assert(assess("other",__other,held).verdict=="passed")
__hours=__hours+24
local retrievalOffer=assert(S.learningOffer("other",__other,held));assert(retrievalOffer.mode=="retrieval")
assert(S.beginAssessment("other",__other,retrievalOffer))
local retrievalAction=__queue;__nativeAction(retrievalAction.action,"start")
__other:getStats():set(CharacterStat.FATIGUE,.9);__other:getStats():set(CharacterStat.PAIN,100)
__nativeAction(retrievalAction.action,"progress",1);__nativeAction(retrievalAction.action,"perform");__nativeAction(retrievalAction.action,"complete")
local failedRecall=S.assessmentOutcome("other",__records.other.studyAssessmentSequence)
check("ordinary_failed_retrieval_from_current_health",failedRecall.task.mode=="retrieval" and failedRecall.verdict=="failed"
    and failedRecall.responseOwner=="SAO.Cognition.literal-and-arithmetic/1")
__other:getStats():set(CharacterStat.FATIGUE,0);__other:getStats():set(CharacterStat.PAIN,0)
__hours=__hours+6;assert(assess("other",__other,held).verdict=="passed")
SAO.Perception.conceptContext=function(id,tick)return {status="observed",roomId="room:known",buildingId="house:known",
    observations={{kind="room",concept="room",roomId="room:known",buildingId="house:known",key="room:known",x=10,y=20,z=0}},
    frontiers={{kind="doorway",key="door:known",roomId="room:known",buildingId="house:known",entryX=11,entryY=20,entryZ=0}}}end
SAO.Perception.conceptMemories=function()return {}end
P.maintain("person",{key="privacy-purpose",domain="shelter",objective="find a private room"})
P.maintain("other",{key="shared-work-purpose",domain="social",objective="find space for cooperation"})
local privateOffer=P.literatureInquiryOffer("person",90000);local commonOffer=P.literatureInquiryOffer("other",90000)
check("same_source_distinct_private_inquiries",privateOffer and commonOffer and privateOffer.goal=="privacy" and commonOffer.goal=="cooperation"
    and privateOffer.desiredConcept~=commonOffer.desiredConcept and privateOffer.frontier.entryX==commonOffer.frontier.entryX)
local beforeUse=K.assessmentMemory("person",e.sourceId)
local inquiryPurpose=P.planConceptInquiry("person",privateOffer,90000)
check("ordinary_source_inquiry_maintained",inquiryPurpose~=nil and inquiryPurpose.inquiry.path.roots[1].assessmentId~=nil)
local afterUse=K.assessmentMemory("person",e.sourceId)
check("actual_plan_use_refreshes_once",afterUse.usageCount==1 and K.consumeInquiryUse("person",inquiryPurpose.id)
    and K.assessmentMemory("person",e.sourceId).usageCount==1 and afterUse.strength>beforeUse.strength)
local retained=__records.person.conceptKnowledge
retained.sequence=retained.sequence+1;local contraryKey="room|may-contain|quiet-room|house:known"
retained.order[#retained.order+1]=contraryKey
retained.relations[contraryKey]={id="concept/person/"..retained.sequence,actorId="person",from="room",relation="may-contain",into="quiet-room",
    contextId="house:known",affirmed=false,basis="personal-association",sourceId="synthetic-contrary-personal-experience",acquiredAt=__hours,modal=true}
check("contrary_private_experience_revises_inquiry",K.infer("person","room","privacy","house:known").status=="challenged")
check("local_exception_preserves_other_place",K.infer("person","room","privacy","another-house").status=="expectation")
local saved=__records.person.conceptKnowledge.readingAssessments.sequence
Q.about("person","literature");K.assessedRelations("person");K.assessmentMemory("person",e.sourceId)
check("query_does_not_rehearse_or_grant",__records.person.conceptKnowledge.readingAssessments.sequence==saved and K.assessmentMemory("person",e.sourceId).usageCount==1)
__hours=__hours+30
local offer=assert(S.learningOffer("other",__other));assert(S.beginAssessment("other",__other,offer))
local pendingSequence=__records.other.studyAssessmentSequence
local pending=__queue;__nativeAction(pending.action,"start");__nativeAction(pending.action,"progress",.3)
S.interruptAssessment("other",__other,"synthetic urgent work")
check("interrupted_response_no_assessment",S.assessmentOutcome("other",pendingSequence)==nil and __records.other.studyAssessmentWork.status=="interrupted")
__hours=__hours+6
local liveOffer=assert(S.learningOffer("other",__other));assert(S.beginAssessment("other",__other,liveOffer))
local reloadSequence=__records.other.studyAssessmentSequence
local pendingAgain=__queue;__nativeAction(pendingAgain.action,"start")
__reloadOwners(__sourcesPath,__studyPath)
S.reconcileLearning("other",__other)
check("plain_reload_pending_work_is_interruption",__records.other.studyAssessmentWork.status=="interrupted" and S.assessmentOutcome("other",reloadSequence)==nil
    and SAO.Needs.workAvailable(__other))
check("no_recipe_xp_or_imported_education_grant",__records.person.education==nil and __records.person.studyOutcomes==nil)
-- Corrected military consumer: actual native room/door/LOS geometry supplies
-- the private context through unchanged production Perception acquisition.
local nativeView=__nativeSpatialContext()
SAO.Perception.conceptContext=nativeContext;SAO.Perception.conceptMemories=nativeMemories
local nativeTick=123456
check("native_spatial_acquisition",nativeView.actorId=="person" and #nativeView.frontiers>0
    and SAO.Perception.observeConcepts("person",__body,nativeTick)==true)
local acquired=SAO.Perception.conceptContext("person",nativeTick,__body)
check("native_occupied_room_frontier_private",acquired.status=="observed" and acquired.roomId=="3161" and acquired.buildingId=="316"
    and #acquired.frontiers>0 and acquired.observations[1].source=="native-personal-visibility")
for _,identity in ipairs(__records.person.proceduralPlanning.order)do
    local concern=__records.person.proceduralPlanning.purposes[identity]
    if concern.key=="privacy-purpose" then concern.status="abandoned" end
end
P.maintain("person",{key="supplies-through-known-building",domain="resources",objective="investigate a possible supply route"})
local militaryInquiry=P.literatureInquiryOffer("person",nativeTick)
check("native_military_ordinary_inquiry",militaryInquiry and militaryInquiry.goal=="supply-continuity"
    and militaryInquiry.desiredConcept=="alternate-route" and militaryInquiry.frontier.roomId=="3161"
    and militaryInquiry.path.roots[1].sourceId==militaryExposure.sourceId)
local militaryPurpose=P.planConceptInquiry("person",militaryInquiry,nativeTick)
check("native_military_plan_uses_acquired_frontier",militaryPurpose~=nil and militaryPurpose.steps[1].x==acquired.frontiers[1].entryX
    and militaryPurpose.inquiry.path.roots[1].sourceRevision==2 and militaryPurpose.inquiry.path.modal==true)
check("native_far_side_not_invented",militaryInquiry.observedMeans==nil and militaryInquiry.path.x==nil
    and militaryInquiry.path.missing[1]~=nil)
local militaryRow
for _,r in ipairs(__records.person.conceptKnowledge.readingAssessments.rows)do if r.sourceId==militaryExposure.sourceId then militaryRow=r end end
local militaryHash=militaryRow.textHash;militaryRow.textHash=string.rep("0",64)
local invalidMilitary=P.literatureInquiryOffer("person",nativeTick)
check("native_military_requires_retained_source",invalidMilitary==nil or invalidMilitary.goal~="supply-continuity")
militaryRow.textHash=militaryHash
SAO.Locomotion.jobs={};local inquiryOrders=0
SAO.Locomotion.order=function(id,body,x,y,z)
    inquiryOrders=inquiryOrders+1;SAO.Locomotion.jobs[id]={body=body,goal={x=x,y=y,z=z},done=false};return true
end
SAO.Standing.mayAttemptBelieved=function()return false end
check("native_military_current_standing_refuses_dispatch",not Ctl.beginConceptInquiry("person",Ctl.agents.person,__body,nativeTick,militaryInquiry)
    and inquiryOrders==0)
SAO.Standing.mayAttemptBelieved=function()return true end
check("native_military_ordinary_controller_dispatch",Ctl.beginConceptInquiry("person",Ctl.agents.person,__body,nativeTick,militaryInquiry)
    and inquiryOrders==1 and Ctl.agents.person.inquiryRoute~=nil)
SAO.Locomotion.jobs.person=nil;Ctl.agents.person.inquiryRoute=nil;Ctl.agents.person.state="IDLE"
local beforeOther=SAO.Perception.conceptContext("other",nativeTick,__other)
check("military_private_evidence_not_shared",beforeOther.status~="observed")
check("native_other_observer_acquires_own_context",SAO.Perception.observeConcepts("other",__other,nativeTick)==true)
P.maintain("other",{key="other-supply-purpose",domain="resources",objective="investigate supplies"})
check("military_unexposed_person_no_source_inquiry",P.literatureInquiryOffer("other",nativeTick)==nil
    or P.literatureInquiryOffer("other",nativeTick).goal~="supply-continuity")
-- A newly addressed native listener receives actual owner-authenticated
-- teaching. Its memory is maintained independently of the teacher's memory.
local listener=__newRecipient();__records.listener={id="listener",bodyOwnerToken="listener-token",testAge=30,discipline=.85}
__bodies.listener=listener;SAO.Body.active.listener=listener;__known.listener={}
listener:getModData().SAOPersonId="listener";listener:getModData().SAOExternalToken="listener-token"
SAO.Controller.agents.listener={rec=__records.listener,state="IDLE"}
P.maintain("listener",{key="listener-privacy",domain="shelter",objective="investigate privacy"})
local teacherRows=K.assessmentReceipts("person");local originalAssessment
for _,r in ipairs(teacherRows)do if r.sourceId==e.sourceId and r.verdict=="passed" then originalAssessment=r end end
local teacherHalfLife=originalAssessment.policy.halfLifeHours*(1+math.min(originalAssessment.usageCount,8)*.1)
__hours=math.max(__hours,originalAssessment.lastUsedAt+1.4*teacherHalfLife)
check("teacher_source_retained_at_actual_teaching",K.assessmentMemory("person",e.sourceId).retained)
local firstTeaching,secondTeaching
for attempt=1,16 do
    local delivered=Communication.deliverConceptAssociation("person","listener","spoken")
    if delivered then if not firstTeaching then firstTeaching=delivered else secondTeaching=delivered end end
    if #K.receivedLiteratureRelations("listener")>=2 then break end
end
local received=K.receivedLiteratureRelations("listener");local heard=received[1]
check("received_source_and_actor_provenance",firstTeaching~=nil and secondTeaching~=nil and heard~=nil
    and heard.sourceId==e.sourceId and heard.textHash==e.textHash and heard.sourceRevision==e.revision
    and heard.literature.assessmentActorId=="person" and heard.literature.assessmentId==originalAssessment.id
    and heard.recipientAssessment=="unassessed" and #K.assessedRelations("listener")==0)
local recalled=K.receivedLiteratureMemory("listener",heard.id)
check("received_retrieval_is_recipient_owned",recalled.actorId=="listener" and recalled.response.from==heard.from
    and recalled.originalAssessment.assessmentActorId=="person" and recalled.recipientAssessment=="unassessed")
local conditionBefore=K.receivedLiteratureMemory("listener",heard.id)
listener:getStats():set(CharacterStat.FATIGUE,.9);listener:getStats():set(CharacterStat.PAIN,100)
local conditionAfter=K.receivedLiteratureMemory("listener",heard.id)
check("received_current_health_affects_retrieval",conditionAfter.strength<conditionBefore.strength
    and conditionAfter.currentCondition.actorId=="listener")
listener:getStats():set(CharacterStat.FATIGUE,0);listener:getStats():set(CharacterStat.PAIN,0)
local receiverPolicy=K.assessmentPolicy("listener",e.sourceId);__records.listener.discipline=.15
check("received_recipient_attributes_define_policy",K.assessmentPolicy("listener",e.sourceId).halfLifeHours<receiverPolicy.halfLifeHours)
__records.listener.discipline=.85
__hours=__hours+.9*receiverPolicy.halfLifeHours
local recipientAfterTeacher=K.receivedLiteratureMemory("listener",heard.id)
check("recipient_memory_independent_of_teacher_forgetting",not K.assessmentMemory("person",e.sourceId).retained
    and recipientAfterTeacher~=nil and recipientAfterTeacher.retained and K.infer("listener","room","privacy").status=="expectation")
__records.listener=__roundTrip(__records.listener);SAO.Controller.agents.listener.rec=__records.listener
check("received_native_save_reload_retains_source_policy",K.receivedLiteratureMemory("listener",heard.id).retained
    and __records.listener.conceptKnowledge.relations["room|may-contain|quiet-room|*"].policy.formationCondition.actorId=="listener")
__records.listener.testAge=31
check("received_aging_makes_upkeep_due",K.receivedLiteratureMemory("listener",heard.id).maintenanceDue==true)
check("received_native_observer_acquires_own_ground",SAO.Perception.observeConcepts("listener",listener,nativeTick)==true)
local heardInquiry=P.literatureInquiryOffer("listener",nativeTick)
check("received_relation_reaches_ordinary_inquiry",heardInquiry and heardInquiry.goal=="privacy"
    and heardInquiry.path.roots[1].basis=="received-literature-association")
local heardPurpose=P.planConceptInquiry("listener",heardInquiry,nativeTick)
local maintained=K.receivedLiteratureMemory("listener",heard.id)
check("received_actual_use_maintains_recipient_once",heardPurpose~=nil and maintained.usageCount==1 and not maintained.maintenanceDue
    and K.consumeInquiryUse("listener",heardPurpose.id) and K.receivedLiteratureMemory("listener",heard.id).usageCount==1)
check("received_teacher_assessment_not_granted",#K.assessmentReceipts("listener")==0)
__hours=__hours+10000
local staleHeard=K.receivedLiteratureMemory("listener",heard.id)
local reoffer=K.teachingOffer("listener","other")
check("received_literature_expires_without_rehearsal",not staleHeard.retained and staleHeard.response==nil
    and #K.receivedLiteratureRelations("listener")==0 and K.infer("listener","room","privacy").status=="unresolved"
    and (not reoffer or reoffer.basis~="received-literature-association"))
check("received_expiry_blocks_ordinary_inquiry",P.literatureInquiryOffer("listener",nativeTick)==nil)
-- Genuine new reception after new source retrieval can reacquire a forgotten
-- proposition; retaining its old row is not a fresh acquisition.
__give(held,false)
local renewedTeacher=assess("person",__body,held)
check("teacher_actual_source_retrieval_before_reteaching",renewedTeacher.verdict=="passed")
for attempt=1,16 do
    Communication.deliverConceptAssociation("person","listener","spoken")
    if #K.receivedLiteratureRelations("listener")>=2 then break end
end
local reacquiredHeard=K.receivedLiteratureRelations("listener")[1]
check("received_forgotten_association_reacquired_only_by_new_reception",reacquiredHeard~=nil
    and reacquiredHeard.id~=heard.id and reacquiredHeard.literature.assessmentActorId=="person"
    and reacquiredHeard.literature.assessmentId==renewedTeacher.id and #K.assessedRelations("listener")==0)
print("PASS literature learning "..count)
