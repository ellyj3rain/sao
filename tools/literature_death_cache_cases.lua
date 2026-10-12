-- Narrow disposable assessment-cache lifetime proof. Real native literature,
-- reading and action handles; exact production Identity death funnel. Clock,
-- actor registry and foreign successor queue placement are controlled.
local S,K,P=SAO.Study,SAO.ConceptKnowledge,SAO.ProceduralPlanning
local count=0
local function check(name,value)
    print('LITERATURE '..name..'='..tostring(value==true));count=count+1
    assert(value==true,'LITERATURE_FAILED:'..name)
end
SAO.Body={get=function(id)return __bodies[id]end,active={},foreign={}}
SAO.Standing={mayAttemptBelieved=function()return true end,groupOf=function()end}
SAO.Controller.agents={}
SAO.Needs.busy=function()return __queue~=nil end
__records={};__bodies={};SAO.Body.active=__bodies
local function finish(a)
    __nativeAction(a.action,'start');__nativeAction(a.action,'progress',1)
    __nativeAction(a.action,'perform');__nativeAction(a.action,'complete')
end
local function prepared(id,body,token)
    __queue=nil;body:getCharacterActions():clear();body:getInventory():getItems():clear()
    local rec={id=id,bodyOwnerToken=token,testAge=30,discipline=.85,forename='Cache',surname='Probe',x=10,y=20}
    __records[id]=rec;__bodies[id]=body;SAO.Controller.agents[id]={rec=rec,state='IDLE'}
    body:getModData().SAOPersonId=id;body:getModData().SAOExternalToken=token
    body:setAsleep(false);body:setHealth(100)
    local item=__newPamphlet('Civilian');__give(item,body==__other)
    assert(S.beginLeisure(id,body,item));finish(__queue)
    local offer=assert(S.learningOffer(id,body,item));assert(S.beginAssessment(id,body,offer))
    local action=__queue;__nativeAction(action.action,'start')
    return rec,item,action
end
local rec,item,action=prepared('person',__body,'death-first')
check('death_cache_active_owned_action',S.__deathCacheProbe('person')~=nil and S.__deathCacheProbe('person').action==action)
check('actual_death_retires_owned_assessment',SAO.Identity.markDead(rec,100,'focused-test')==true
    and rec.studyAssessmentWork.status=='interrupted' and S.__deathCacheProbe('person')==nil)
check('death_keeps_plain_person_and_native_items',__records.person==rec and rec.dead and rec.diedAtHours==__hours
    and #rec.noteReadingOutcomes==1 and __body:getInventory():contains(item))
local stale,staleItem,staleAction=prepared('other',__other,'death-terminal')
stale.studyAssessmentWork.status='completed'
check('terminal_cache_exists_before_death',S.__deathCacheProbe('other')~=nil)
SAO.Identity.markDead(stale,101,'focused-stale-terminal')
check('terminal_learning_cache_dropped_by_death',S.__deathCacheProbe('other')==nil and __records.other==stale
    and stale.studyAssessmentWork.status=='completed' and __other:getInventory():contains(staleItem))
local mismatched,mismatchItem,mismatchAction=prepared('person',__body,'death-mismatched')
mismatched.studyAssessmentWork=__roundTrip(mismatched.studyAssessmentWork)
local foreign={character=__body,personId='foreign',workId='foreign-successor'}
local queue=ISTimedActionQueue.getTimedActionQueue(__body)
queue.queue={mismatchAction,foreign};queue.current=foreign;__queue=foreign
__body:getModData().SAOExternalToken='foreign-successor-generation'
SAO.Identity.markDead(mismatched,102,'focused-mismatched-work')
check('mismatched_cache_disposed_without_foreign_queue_mutation',S.__deathCacheProbe('person')==nil
    and __queue==foreign and queue.current==foreign and queue.queue[2]==foreign)
check('mismatched_death_keeps_plain_record_and_item',__records.person==mismatched and mismatched.dead
    and mismatched.noteReadingOutcomes[1].status=='completed' and __body:getInventory():contains(mismatchItem))
__nativeAction(mismatchAction.action,'complete')
check('retired_foreign_generation_cannot_mint_assessment',mismatched.studyAssessmentOutcomes==nil and __queue==foreign)
print('PASS literature learning '..count)
