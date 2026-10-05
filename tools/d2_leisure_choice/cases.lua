-- Actual installed materials/body and production eligibility/learning/dispatch;
-- only physical admission receivers and prior canonical sound receipts are controlled.
require=function() end
Events={OnTick={Add=function() end},OnGameStart={Add=function() end,Remove=function() end},
    OnInitGlobalModData={Add=function() end}}
ISLogSystem={logAction=function() end}
ISInventoryPage={}
SkillBook={}
getText=function(x)return x end
SAO={Identity={},Body={active={},foreign={}},Controller={agents={}},
    Log={line=function()end},Hash={of=function()return 1 end,unit=function()return .5 end},
    History={countyHours=function()return __hours end,literacyOf=function()return 'reads' end},
    Disposition={traits=function()return {discipline=.5} end,isSmoker=function()return false end},
    Standing={groupOf=function()return nil end},Lessons={has=function()return false end},
    Census={JOB_PERK={}},Labor={capabilityOf=function()return {}end},Gesture={}}
SAO.Identity.get=function(id)return __records[id]end
SAO.Body.get=function(id)return SAO.Body.active[id]end
SAO.Gesture.instrumentOutcome=function(id,sequence)return __receipts[id] and __receipts[id][sequence]end
SAO.Gesture.nextInstrumentSequence=function(id)return (__records[id].instrumentSequence or 0)+1 end
SAO.Gesture.playInstrument=function(id,body,kind,itemType,item,purposeId)
    __dispatch[#__dispatch+1]={kind='instrument',item=item,purposeId=purposeId}
    return not __refuseInstrument and SAO.Needs.instrumentAvailable(id,body,item)~=nil
end
ModData={get=function(key)return __stores[key]end,
    getOrCreate=function(key)__stores[key]=__stores[key] or {};return __stores[key]end}
-- CASES
local C,P=SAO.Cognition,SAO.ProceduralPlanning
local nativeBegin=SAO.Study.beginLeisure
SAO.Study.beginLeisure=function(id,body,item)
    __dispatch[#__dispatch+1]={kind='reading',item=item}
    return not __refuseReading and SAO.Study.readingEligibility(id,body,item,'leisure')
end
SAO.Study.describe=function()return 'controlled native reading admission' end
local count=0
local function check(name,condition)
    assert(condition,'D2_LEISURE_CHOICE:'..name);count=count+1;print('CASE '..name)
end
local function fresh()
    __hours=10;__records={person={id='person'},foreign={id='foreign'}};__stores={};__receipts={person={},foreign={}}
    __dispatch={};__refuseInstrument=false;__refuseReading=false
    __body:getInventory():clear();__other:getInventory():clear()
    __body:getInventory():AddItem(__harmonica);__body:getInventory():AddItem(__book)
    __body:getModData().SAOPersonId='person';__body:getModData().SAOExternalOwner=nil
    __body:getModData().SAOExternalToken=nil;__body:getModData().ZAOOwned=nil
    __body:setAsleep(false);__body:setCanShout(true)
    SAO.Body.active.person=__body;SAO.Body.foreign.person=nil
    local rec=__records.person;local agent={rec=rec,state='REST'};SAO.Controller.agents.person=agent
    assert(C.configure(0,12,3))
    return rec,agent
end
local function learn(id,sequence,success)
    __receipts[id][sequence]={actorId=id,sequence=sequence,workId='instrument:'..id..':'..sequence,
        bodyGenerationKnown=false,verb='blow-harmonica',itemType='Base.Harmonica',itemId=tostring(__harmonica:getID()),
        status=success and 'completed' or 'interrupted',admittedAtHours=9,atHours=10,
        soundEmitted=success,worldSoundEmitted=success,soundHandle=success and 1 or nil,
        startedAtHours=success and 9 or nil,endedAtHours=success and 10 or nil,
        soundEnded=success,cleanupPending=false,queueAdmitted=true}
    assert(C.instrumentOutcome(id,sequence))
end
local function decide(rec,agent)
    __dispatch={};agent.pressure=nil
    local admitted=__restActivity('person',agent,__body,10000,rec)
    return __dispatch[1] and __dispatch[1].kind,admitted
end
local function predicted(rec,kind)
    for _,row in ipairs(rec.leisureDecision.interpretations.models[1].ranked) do
        if string.find(row.id,kind..':',1,true)==1 then return row.predictions end
    end
end
do
    local rec,agent=fresh();local kind,admitted=decide(rec,agent)
    check('cold_dispatch_uses_material_tie_without_fake_experience',kind=='instrument' and admitted and rec.cognition==nil)
    check('both_viable_plain_alternatives_retained',#rec.leisureDecision.alternatives==2
        and rec.leisureDecision.status=='admitted' and #predicted(rec,'reading')==0
        and rec.leisureDecision.alternatives[2].itemType=='Base.Book'
        and rec.leisureDecision.alternatives[2].itemKey==tostring(__book:getID())
        and predicted(rec,'instrument')[1].sourceId=='native:sound:BlowHarmonica')
end
do
    local rec,agent=fresh();learn('person',1,false);local kind,admitted=decide(rec,agent)
    check('negative_native_evidence_changes_actual_receiver',kind=='reading' and admitted and #__dispatch==1)
    check('unselected_instrument_creates_no_purpose',rec.proceduralPlanning==nil)
    check('private_exact_consequence_retained',predicted(rec,'instrument')[1].basis=='exact-experience'
        and #predicted(rec,'instrument')[1].evidenceIds==1 and #predicted(rec,'reading')==0)
    learn('person',2,true);learn('person',3,true);agent.nextPageAt=nil
    check('contrary_success_changes_actual_receiver_back',decide(rec,agent)=='instrument')
end
do
    local rec,agent=fresh();learn('foreign',1,false)
    check('another_person_evidence_cannot_change_receiver',decide(rec,agent)=='instrument')
end
do
    local rec,agent=fresh();assert(C.configure(1,12,3));learn('person',1,false)
    check('configured_associative_choice_reaches_selected_receiver',decide(rec,agent)=='reading'
        and rec.leisureDecision.interpretations.selectedModelId=='associative')
end
do
    local rec,agent=fresh();learn('person',1,false)
    rec=__roundTrip(rec);__records.person=rec;agent.rec=rec
    check('serialized_private_evidence_changes_new_dispatch',decide(rec,agent)=='reading')
    local restored=__roundTrip(rec)
    check('decision_snapshot_survives_native_serialization',restored.leisureDecision.selected==rec.leisureDecision.selected
        and #restored.leisureDecision.alternatives==2 and restored.leisureDecision.interpretations.models[1].ranked[1].id==rec.leisureDecision.selected)
end
do
    local rec,agent=fresh();learn('person',1,true);agent.nextTuneAt=10001
    check('instrument_cooldown_precedes_learned_preference',decide(rec,agent)=='reading' and #rec.leisureDecision.alternatives==1)
    rec,agent=fresh();learn('person',1,false);agent.nextPageAt=10001
    check('reading_cooldown_removes_unavailable_alternative',decide(rec,agent)=='instrument' and #rec.leisureDecision.alternatives==1)
end
do
    local rec,agent=fresh();learn('person',1,true)
    __body:getInventory():Remove(__harmonica);__other:getInventory():AddItem(__harmonica)
    check('foreign_carried_instrument_never_enters_choice',decide(rec,agent)=='reading' and #rec.leisureDecision.alternatives==1)
    rec,agent=fresh();learn('person',1,false)
    __body:getInventory():Remove(__book);__body:getInventory():AddItem(__idcard)
    rec.reading=__idcard:getFullType()
    check('native_uninteresting_card_is_not_a_reading_alternative',decide(rec,agent)=='instrument'
        and #rec.leisureDecision.alternatives==1)
    SAO.Body.active.person=__other
    check('foreign_body_cannot_dispatch_or_rewrite_decision',decide(rec,agent)==nil and #__dispatch==0)
end
do
    local rec,agent=fresh();__body:setAsleep(true)
    check('sleeping_body_cannot_create_choice_or_dispatch',decide(rec,agent)==nil
        and rec.leisureDecision==nil and rec.proceduralPlanning==nil)
end
do
    local rec,agent=fresh();__body:getInventory():clear();rec.keepsake='remembered'
    check('absent_material_preserves_keepsake_fallback',decide(rec,agent)==nil and agent.nextKeepsakeAt==13600
        and rec.leisureDecision.status=='unavailable')
end
do
    local rec,agent=fresh();__refuseInstrument=true
    local kind,admitted=decide(rec,agent)
    check('selected_refusal_retains_exact_attempt_without_other_dispatch',kind=='instrument' and not admitted
        and #__dispatch==1 and agent.nextTuneAt==10300 and rec.leisureDecision.status=='refused')
    local purpose=P.pending('person','recreate','blow-harmonica')
    check('failed_admission_does_not_complete_purpose',purpose and purpose.status~='completed'
        and purpose.steps[purpose.cursor].status~='completed')
end
do
    local rec,agent=fresh();__refuseInstrument=true
    local first=__restActivity('person',agent,__body,10000,rec)
    local firstPressure=agent.pressure
    local second=__restActivity('person',agent,__body,10100,rec)
    check('refused_instrument_allows_next_call_reading_during_retry_window',not first and second
        and firstPressure.phase=='refused' and #__dispatch==2
        and __dispatch[1].kind=='instrument' and __dispatch[2].kind=='reading'
        and agent.nextTuneAt==10300 and agent.nextPageAt==13100)
    __restActivity('person',agent,__body,10101,rec)
    check('admitted_reading_keeps_normal_reconsideration_hold',#__dispatch==2 and agent.pressure.phase=='preparing')
end
do
    local rec,agent=fresh()
    P.planLeisure('person',{activity='read '..__book:getFullType(),itemKey=tostring(__book:getID()),
        owner='SAONeeds',affordance=__book:getFullType(),atLocation=true,locationKey='10:20:0'})
    check('maintained_exact_reading_purpose_supplies_continuity',decide(rec,agent)=='reading')
    rec,agent=fresh()
    P.planLeisure('person',{activity='read '..__book:getFullType(),itemKey='another-item',
        owner='SAONeeds',affordance=__book:getFullType(),atLocation=true,locationKey='10:20:0'})
    check('another_item_purpose_cannot_supply_continuity',decide(rec,agent)=='instrument')
end
print('PASS D2 leisure choice '..count)
