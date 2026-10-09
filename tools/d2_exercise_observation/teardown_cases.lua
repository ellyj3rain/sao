local E=SAO.LeisureExercise
local checks=0
local function check(name,yes)assert(yes,'SOURCE_EXERCISE:'..name);checks=checks+1;print('CASE '..name)end
local function fresh(kind)
    __hours=10;__ms=1000000;__busy=false;__denied=false;__conceptDenied=false;__queueRefuse=false
    __resetFitness();__emitter:reset();__resetNoise();__lastSourceXPAmount=nil;__lastSourceXPDelta=nil
    __records={person={id='person'},other={id='other'}};__bodies={person=__body,other=__other}
    __body:getModData().SAOPersonId='person';__body:getModData().SAOExternalToken=nil
    __body:setPrimaryHandItem(nil);__body:setSecondaryHandItem(nil);__body:setAsleep(false)
    __body:getStats():set(CharacterStat.ENDURANCE,1);__body:getStats():set(CharacterStat.THIRST,.1)
    __body:getStats():set(CharacterStat.BOREDOM,30);__body:getStats():set(CharacterStat.UNHAPPINESS,30)
    __body:getStats():set(CharacterStat.STRESS,.8)
    __body:getModData().LSHiddenSkills=nil;__body:getModData().LSZenActive=nil
    __body:getModData().LSMoodles={Zen={Level=0,Value=0},Embarrassed={Level=0,Value=0},WasTaughtSkill={Level=0,Value=0}}
    __body:setHealth(100);ISTimedActionQueue.queues={};__observations={};__objects={};__instances={}
    SandboxVars.ElecShutModifier=30;SandboxVars.Yoga.RequiresMat=false;SandboxVars.FWOWorkingTreadmill.FitnessXPMultiply=1
    local props=__machine:getSprite():getProperties()
    props:set('Facing','S')
    if kind=='benchpress' then
        props:set('CustomName','Contraption');props:set('GroupName','Fitness')
        __body:getInventory():AddItem(__barbell);__body:setPrimaryHandItem(__barbell)
    else props:set('CustomName','Hamster Wheel');props:set('GroupName','Human') end
    local key='object:10:19:0:0:fitness'
    __observations={{actorId='person',kind='object',source='native-personal-visibility',concept=kind=='benchpress' and 'fitness-bench' or 'fitness-treadmill',
        key=key,objectIndex=0,spriteName='fixture-bench',facing='S',runtimeInstance='native-machine-1',at=SAO.History.ticks()}}
    __objects[key]=__machine;__instances[key]='native-machine-1'
end
local function offer(activity)
    for _,o in ipairs(E.offers('person',__body))do if o.activity==activity then return o end end
end
local function begin(activity)
    local o=assert(offer(activity),'missing-source-offer '..activity)
    local purpose={id='purpose',domain='leisure',status='maintained',affordance=o.sourceId,cursor=1,
        leisure={activity=o.activity,itemKey=o.itemKey},steps={{id='perform-activity',owner='SAO.LeisureExercise',token='leisure:performed',status='available'}}}
    __records.person.proceduralPlanning={schema=1,purposes={purpose=purpose},order={'purpose'},spatial={},spatialOrder={},practice={}}
    local ok,w=E.begin('person',__body,o,'purpose');assert(ok,'source-begin '..tostring(w))
    return w,__action
end

local function follower(action)
 local q=ISTimedActionQueue.getTimedActionQueue(__body)
 local nextAction={character=__body,isValidStart=function()return true end,getJobDelta=function()return 0 end,begin=function()end,forceCancel=function()end,isStarted=function()return false end}
 table.insert(q.queue,nextAction)
 return q,nextAction
end
local function started()
 fresh('benchpress');local w,a=begin('benchpress');a:start();a:update()
 assert(__emitter:isPlaying('FWObench'),'missing actual source sound')
 return w,a
end
local w,a=started();local q,f=follower(a)
check('off_slot_native_body',__offSlot() and __body:getModData().SAOPersonId=='person' and __body~=__other)
check('actual_native_queue_action',a.action~=nil and ISTimedActionQueue.hasAction(a))
a:stop();E.interrupt('person',__body,'urgent')
check('maintained_stop_preserves_follower',not ISTimedActionQueue.hasAction(a) and ISTimedActionQueue.hasAction(f))
check('maintained_stop_stops_sound',not __emitter:isPlaying('FWObench'))
w,a=started();q,f=follower(a)
local p=__records.person.proceduralPlanning.purposes.purpose;p.status='abandoned'
check('retired_interrupt_admitted',E.interrupt('person',__body,'retired'))
check('retired_interrupt_removes_owned_action',not ISTimedActionQueue.hasAction(a))
check('retired_interrupt_preserves_follower',ISTimedActionQueue.hasAction(f))
check('retired_sound_stopped',not __emitter:isPlaying('FWObench'))
check('retired_purpose_unchanged',p.status=='abandoned' and not E.outcome('person',w.sequence).plannerConsumed)
local endurance=__body:getStats():get(CharacterStat.ENDURANCE);local xp=__body:getXp():getXP(Perks.Strength)
a:animEvent('ActiveAnimLooped',nil);a:update();a:perform()
check('retired_callback_no_physical_or_XP',__body:getStats():get(CharacterStat.ENDURANCE)==endurance and __body:getXp():getXP(Perks.Strength)==xp)
w,a=started();q,f=follower(a);__records.person.proceduralPlanning.purposes.purpose.status='abandoned'
E.advance('person',__body)
check('retired_advance_removes_owned_action',not ISTimedActionQueue.hasAction(a) and ISTimedActionQueue.hasAction(f))
w,a=started();q,f=follower(a);__body:setHealth(0);__records.person.dead=true
check('native_body_dead',__body:isDead())
check('foreign_detach_refused',not E.detach('person',__other,'foreign') and ISTimedActionQueue.hasAction(a))
local currentExercise=__body:getFitness():getCurrentExe()
endurance=__body:getStats():get(CharacterStat.ENDURANCE);xp=__body:getXp():getXP(Perks.Strength)
local played=__emitter:getPlayed();local noise=__noiseCount()
check('dead_detach_owned',E.detach('person',__body,'death'))
check('death_removes_owned_action',not ISTimedActionQueue.hasAction(a) and ISTimedActionQueue.hasAction(f))
check('death_preserves_fitness_state',__body:getFitness():getCurrentExe()==currentExercise)
check('death_stops_exact_source_sound',not __emitter:isPlaying('FWObench') and __emitter:getPlayed()==played and __noiseCount()==noise)
a:animEvent('ActiveAnimLooped',nil);a:update();a:perform();a:stop()
check('death_no_postmortem_physical_XP',__body:getStats():get(CharacterStat.ENDURANCE)==endurance and __body:getXp():getXP(Perks.Strength)==xp)
check('death_interrupted_without_measured_after',E.outcome('person',w.sequence).status=='interrupted' and E.outcome('person',w.sequence).measuredEffects.afterUnavailable)
check('duplicate_detach_no_new_sound',not E.detach('person',__body,'again') and __emitter:getPlayed()==played)
w,a=started();q,f=follower(a)
currentExercise=__body:getFitness():getCurrentExe();__bodies.person=__other
local foreignEndurance=__other:getStats():get(CharacterStat.ENDURANCE)
check('replaced_body_exact_detach',E.detach('person',__body,'replacement'))
check('replaced_body_retained_fitness',__body:getFitness():getCurrentExe()==currentExercise and __other:getStats():get(CharacterStat.ENDURANCE)==foreignEndurance)
check('replaced_body_source_cleanup',not ISTimedActionQueue.hasAction(a) and ISTimedActionQueue.hasAction(f) and not __emitter:isPlaying('FWObench'))
w,a=started();q,f=follower(a);currentExercise=__body:getFitness():getCurrentExe()
__records.person.bodyOwnerToken='reassigned-owner'
check('retired_body_token_detach',E.detach('person',__body,'owner-token-ended'))
check('retired_body_token_no_fitness_write',__body:getFitness():getCurrentExe()==currentExercise and not ISTimedActionQueue.hasAction(a) and ISTimedActionQueue.hasAction(f))
check('no_clock_mutation',__clockWrites==0)
print('PASS source exercise '..checks)
