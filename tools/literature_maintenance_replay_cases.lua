-- Narrow D316-R4 proof. Real native text/read/response and table save/load;
-- clocks, actors, conversation admission and room/door geometry are controlled.
local S,K,P,Communication=SAO.Study,SAO.ConceptKnowledge,SAO.ProceduralPlanning,SAO.Communication
local count=0
local function check(name,value)
    print("LITERATURE "..name.."="..tostring(value==true));count=count+1
    assert(value==true,"LITERATURE_FAILED:"..name)
end
SAO.Body={get=function(id)return __bodies[id]end,active={},foreign={}}
SAO.Standing={mayAttemptBelieved=function()return true end,mayTakeCurrent=function()return true end,
    sameGroup=function()return false end,trust=function()return .8 end,groupOf=function()end}
SAO.Perception.knownPlaces=function()return {}end
SAO.Needs.busy=function()return __queue~=nil end
Communication.canConverse=function()return true end
__records={person={id="person",bodyOwnerToken="replay-teacher",testAge=30,discipline=.85},
    other={id="other",bodyOwnerToken="replay-recipient",testAge=30,discipline=.85}}
__bodies={person=__body,other=__other};SAO.Body.active=__bodies
SAO.Controller.agents={person={rec=__records.person,state="IDLE"},other={rec=__records.other,state="IDLE"}}
__body:getModData().SAOPersonId="person";__body:getModData().SAOExternalToken="replay-teacher"
__other:getModData().SAOPersonId="other";__other:getModData().SAOExternalToken="replay-recipient"
__body:setAsleep(false);__body:setHealth(100);__other:setAsleep(false);__other:setHealth(100)
__clearInventory();__queue=nil;assert(SAO.Cognition.configure(.5,12,3))
local function finish(a)
    __nativeAction(a.action,"start");__nativeAction(a.action,"progress",1)
    __nativeAction(a.action,"perform");__nativeAction(a.action,"complete")
end
local function readAndAssess(id,body,item)
    assert(S.beginLeisure(id,body,item));finish(__queue)
    local exposure=assert(S.sourceExposure(id,__records[id].studySequence))
    local offer=assert(S.learningOffer(id,body,item));assert(S.beginAssessment(id,body,offer));finish(__queue)
    return exposure,assert(S.assessmentOutcome(id,__records[id].studyAssessmentSequence))
end
local civilian=__newPamphlet("Civilian");__give(civilian,false)
local exposure,teacherResponse=readAndAssess("person",__body,civilian)
check("narrow_native_source_response",teacherResponse.verdict=="passed" and teacherResponse.sourceId==exposure.sourceId)
P.maintain("other",{key="recipient-privacy",domain="shelter",objective="look for privacy"})
for i=1,2 do assert(Communication.deliverConceptAssociation("person","other","spoken")) end
local received=K.receivedLiteratureRelations("other");local first=received[1]
check("narrow_received_only_before_reading",first~=nil and #received==2 and __records.other.conceptKnowledge.readingAssessments==nil)
__nativeSpatialContext();assert(SAO.Perception.observeConcepts("other",__other,100))
local offer=assert(P.literatureInquiryOffer("other",100));local purpose=assert(P.planConceptInquiry("other",offer,100))
local memory=assert(K.receivedLiteratureMemory("other",first.id))
local state=__records.other.conceptKnowledge
local row=state.relations["room|may-contain|quiet-room|*"]
local usedAt,usage,maintenanceCount=memory.lastUsedAt,memory.usageCount,#row.maintenanceReceipts
local receivedCount=#state.receivedUseReceipts
check("narrow_first_owned_received_use",usage==1 and maintenanceCount==1 and receivedCount==1)
__hours=__hours+1
check("received_use_replay_before_reading_store_is_inert",K.consumeInquiryUse("other",purpose.id)
    and K.receivedLiteratureMemory("other",first.id).lastUsedAt==usedAt
    and K.receivedLiteratureMemory("other",first.id).usageCount==usage and #row.maintenanceReceipts==maintenanceCount)
local engineering=__newPamphlet("Engineering");__give(engineering,true)
local ownExposure,ownResponse=readAndAssess("other",__other,engineering)
check("normal_native_reading_creates_own_assessed_store",ownResponse.verdict=="passed" and ownResponse.actorId=="other"
    and ownResponse.sourceId~=first.sourceId and #state.readingAssessments.rows==1 and #state.readingAssessments.useReceipts==0)
__hours=__hours+1
local replayed=K.consumeInquiryUse("other",purpose.id)
local after=K.receivedLiteratureMemory("other",first.id)
check("received_use_replay_after_actual_reading_store_is_inert",replayed and after.usageCount==usage and after.lastUsedAt==usedAt
    and #row.maintenanceReceipts==maintenanceCount and #state.receivedUseReceipts==receivedCount
    and #state.readingAssessments.useReceipts==0)
__records.other=__roundTrip(__records.other);SAO.Controller.agents.other.rec=__records.other
state=__records.other.conceptKnowledge;row=state.relations["room|may-contain|quiet-room|*"]
__hours=__hours+1
check("received_ledger_transition_save_replay_is_inert",K.consumeInquiryUse("other",purpose.id)
    and K.receivedLiteratureMemory("other",first.id).usageCount==usage
    and K.receivedLiteratureMemory("other",first.id).lastUsedAt==usedAt
    and #row.maintenanceReceipts==maintenanceCount and #state.receivedUseReceipts==receivedCount
    and #state.readingAssessments.useReceipts==0)
-- New actual reception and a different maintained goal produce new owned
-- source-dependent work. Both ledgers can coexist without blocking it.
for i=1,2 do assert(Communication.deliverConceptAssociation("person","other","spoken")) end
P.maintain("other",{key="recipient-shared-work",domain="social",objective="look for shared work space"})
local shared=P.conceptInquiryOffer("other","cooperation",100)
check("new_source_dependent_work_has_distinct_path",shared and shared.status=="actionable" and shared.path.id~=offer.path.id
    and shared.path.roots[1].basis=="received-literature-association")
local sharedId=shared.path.roots[1].id
local beforeShared=K.receivedLiteratureMemory("other",sharedId)
__hours=__hours+1
local sharedPurpose=P.planConceptInquiry("other",shared,100)
local afterShared=K.receivedLiteratureMemory("other",sharedId)
check("genuine_new_source_work_still_maintains",sharedPurpose~=nil and sharedPurpose.id~=purpose.id
    and afterShared.usageCount==beforeShared.usageCount+1 and afterShared.lastUsedAt==__hours
    and #state.readingAssessments.useReceipts==1 and #state.receivedUseReceipts==receivedCount)
__hours=__hours+1
check("both_ledger_replays_remain_inert_after_new_work",K.consumeInquiryUse("other",purpose.id)
    and K.consumeInquiryUse("other",sharedPurpose.id) and K.receivedLiteratureMemory("other",first.id).usageCount==usage
    and K.receivedLiteratureMemory("other",first.id).lastUsedAt==usedAt
    and K.receivedLiteratureMemory("other",sharedId).usageCount==afterShared.usageCount
    and K.receivedLiteratureMemory("other",sharedId).lastUsedAt==afterShared.lastUsedAt
    and #state.receivedUseReceipts==receivedCount and #state.readingAssessments.useReceipts==1)
print("PASS literature learning "..count)
