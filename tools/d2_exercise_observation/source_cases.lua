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
    __queue.queue={};__observations={};__objects={};__instances={}
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
fresh('benchpress')
__other:getModData().SAOPersonId='other';__other:getModData().SAOExternalToken=nil
__other:getFitness():init()
check('scoped_native_constructor_parity',__initDefinitions(__body,FitnessExercises.exercisesType)=='initialized'
    and SAOJavaBridge:fitnessExerciseXpModifier(__body,'benchpress')==SAOJavaBridge:fitnessExerciseXpModifier(__other,'benchpress')
    and SAOJavaBridge:fitnessExerciseXpModifier(__body,'squats')==SAOJavaBridge:fitnessExerciseXpModifier(__other,'squats'))
local foreignBefore=SAOJavaBridge:fitnessExerciseXpModifier(__other,'treadmill')
fresh('benchpress')
check('actual_bench_acquired_offer',offer('benchpress')~=nil)
local w,action=begin('benchpress');action:start()
local beforeXP=__body:getXp():getXP(Perks.Strength)
action:animEvent('ActiveAnimLooped',nil)
check('bench_native_source_XP',__body:getXp():getXP(Perks.Strength)>beforeXP and __lastSourceXPAmount==.12 and __lastSourceXPDelta>0)
check('bench_actual_native_repeat',action.repnb==1 and __body:getStats():get(CharacterStat.ENDURANCE)<1)
check('bench_actual_source_thirst',math.abs(__body:getStats():get(CharacterStat.THIRST)-.1025)<.00002)
check('bench_source_mood',__body:getStats():get(CharacterStat.BOREDOM)<30)
action:update()
check('bench_actor_sound_and_world_noise',__emitter:getPlayed()>0 and __emitter:isPlaying('FWObench') and __fwoNoiseExact())
__hours=10.2;__ms=1600001;__observations[1].at=SAO.History.ticks();action:update();E.advance('person',__body)
local out=E.outcome('person',w.sequence)
check('bench_typed_source_completion',out and out.status=='completed' and out.plannerConsumed)
check('bench_measured_native_XP',out.measuredEffects.deltas['XP:Strength']>0)
fresh('treadmill');w,action=begin('treadmill');action:start()
beforeXP=__body:getXp():getXP(Perks.Sprinting);action:animEvent('ActiveAnimLooped',nil)
check('treadmill_native_source_XP',__body:getXp():getXP(Perks.Sprinting)>beforeXP)
check('treadmill_native_source_thirst',math.abs(__body:getStats():get(CharacterStat.THIRST)-.1025)<.00002)
check('treadmill_native_source_modifier',math.abs(SAOJavaBridge:fitnessExerciseXpModifier(__body,'treadmill')-1.5)<.00002)
E.interrupt('person',__body,'cleanup')
fresh('treadmill');SandboxVars.ElecShutModifier=0
check('unpowered_treadmill_refused',offer('treadmill')==nil)
fresh('treadmill');__observations={}
check('unacquired_machine_refused',offer('treadmill')==nil)
fresh('treadmill');__observations[1].facing='N'
check('wrong_facing_refused',offer('treadmill')==nil)
fresh('benchpress');w,action=begin('benchpress');action:start();__observations[1].runtimeInstance='changed';__instances[__observations[1].key]='changed'
local endurance=__body:getStats():get(CharacterStat.ENDURANCE);action:animEvent('ActiveAnimLooped',nil)
check('machine_replacement_no_repeat',__body:getStats():get(CharacterStat.ENDURANCE)==endurance)
E.advance('person',__body);E.interrupt('person',__body,'cleanup')
fresh('benchpress');w,action=begin('benchpress');__body:setPrimaryHandItem(nil)
beforeXP=__body:getXp():getXP(Perks.Strength);action:animEvent('ActiveAnimLooped',nil)
check('lost_equipment_no_XP',__body:getXp():getXP(Perks.Strength)==beforeXP)
E.interrupt('person',__body,'cleanup')
fresh('benchpress');w,action=begin('benchpress');action:start()
__body:getInventory():AddItem(__replacementBarbell);__body:setPrimaryHandItem(__replacementBarbell)
beforeXP=__body:getXp():getXP(Perks.Strength);action:animEvent('ActiveAnimLooped',nil)
check('replaced_held_equipment_no_XP',__body:getXp():getXP(Perks.Strength)==beforeXP)
E.interrupt('person',__body,'cleanup')
fresh('treadmill');SandboxVars.FWOWorkingTreadmill.FitnessXPMultiply=2
local shared=FitnessExercises.exercisesType.treadmill.xpMod;w,action=begin('treadmill')
check('cold_native_actor_modifier',math.abs(SAOJavaBridge:fitnessExerciseXpModifier(__body,'treadmill')-3)<.00002)
check('equipment_never_mutates_shared_definitions',FitnessExercises.exercisesType.treadmill.xpMod==shared)
check('scoped_modifier_never_changes_other_body',SAOJavaBridge:fitnessExerciseXpModifier(__other,'treadmill')==foreignBefore)
E.interrupt('person',__body,'cleanup')
SandboxVars.FWOWorkingTreadmill.FitnessXPMultiply=3
check('existing_native_cache_retained',__initDefinitions(__body,FitnessExercises.exercisesType)=='retained'
    and math.abs(SAOJavaBridge:fitnessExerciseXpModifier(__body,'treadmill')-3)<.00002)
fresh('treadmill');__observations={}
check('actual_yoga_source_offer',offer('yoga')~=nil)
SandboxVars.Yoga.RequiresMat=true
check('unacquired_required_mat_refused',offer('yoga')==nil)
SandboxVars.Yoga.RequiresMat=false;w,action=begin('yoga');action:waitToStart();action:start();for i=1,5 do action:update() end
local beforeYoga=__body:getModData().LSHiddenSkills.Yoga[2]
action:perform();E.advance('person',__body)
check('yoga_premature_perform_refused',E.outcome('person',w.sequence)==nil and E.work('person')~=nil)
for i=1,35 do action:update() end
E.advance('person',__body);out=E.outcome('person',w.sequence)
check('yoga_actual_source_pose_progress',out and out.nativeProgress.poses>=2 and out.nativeProgress.sourceUpdates>=1)
check('yoga_native_Fitness_and_Nimble',__body:getXp():getXP(Perks.Fitness)>0 and __body:getXp():getXP(Perks.Nimble)>0)
check('yoga_actual_hidden_skill',__body:getModData().LSHiddenSkills.Yoga[2]>beforeYoga)
check('yoga_typed_source_completion',out.status=='completed' and out.plannerConsumed)
check('yoga_exact_source_requests_applied',out.nativeProgress.skillRequests==out.nativeProgress.skillApplied)
fresh('treadmill');__observations={};__body:getModData().LSHiddenSkills={Yoga={1,0,250}}
shared=FitnessExercises.exercisesType.squats.xpMod;w,action=begin('yoga');action:waitToStart();action:start()
for i=1,35 do action:update() end;E.advance('person',__body)
check('yoga_bonus_never_mutates_shared_definitions',FitnessExercises.exercisesType.squats.xpMod==shared)
check('yoga_owns_future_source_bonus',__records.person.exerciseDefinitionScope~=nil and __body:getModData().LSZenActive~=nil)
fresh('treadmill');__observations={};w,action=begin('yoga');action:waitToStart();action:start();action:update()
__records.person.proceduralPlanning.purposes.purpose.status='abandoned'
beforeYoga=__body:getModData().LSHiddenSkills.Yoga[2];action:grantXP()
check('retired_yoga_helper_no_effect',__body:getModData().LSHiddenSkills.Yoga[2]==beforeYoga)
E.advance('person',__body)
check('retired_yoga_cannot_revive',__records.person.proceduralPlanning.purposes.purpose.status=='abandoned')
check('no_operator_clock_changes',__clockWrites==0)
fresh('treadmill');__observations={};w,action=begin('yoga');action:waitToStart();action:start()
for i=1,5 do action:update() end
local earned=__body:getXp():getXP(Perks.Fitness)
E.interrupt('person',__body,'urgent-need');out=E.outcome('person',w.sequence)
check('yoga_partial_native_XP_retained',out.status=='interrupted' and earned>0 and __body:getXp():getXP(Perks.Fitness)==earned)
check('yoga_partial_source_hidden_penalty',__body:getModData().LSHiddenSkills.Yoga[2]==0)
fresh('treadmill');__observations={};w,action=begin('yoga');action:waitToStart();action:start()
__body:getModData().SAOExternalToken='retired';__records.person.bodyOwnerToken='retired'
local beforeStress=__body:getStats():get(CharacterStat.STRESS);action:reducePainStressBoredom()
check('stale_yoga_helper_no_effect',__body:getStats():get(CharacterStat.STRESS)==beforeStress)
E.advance('person',__body)
fresh('treadmill');__observations={};w,action=begin('yoga');action:waitToStart();action:start()
for i=1,5 do action:update() end;earned=__body:getXp():getXP(Perks.Fitness)
__records=__roundTrip(__records);__reloadExercise();E=SAO.LeisureExercise;E.advance('person',__body)
check('yoga_reload_cannot_invent_completion',E.outcome('person',w.sequence).status=='interrupted')
check('yoga_reload_cannot_replay_skill',__body:getXp():getXP(Perks.Fitness)==earned)

fresh('treadmill');__observations={};w,action=begin('yoga');action:waitToStart();action:start()
SandboxVars.FWOFitness.PassiveMultiplier=3;E.maintainActor('person',__body)
check('nonfitness_yoga_uses_source_passive_multiplier',__body:getXp():getMultiplier(Perks.Strength)==3)
local multiplier=__body:getXp():getMultiplier(Perks.Strength)
check('foreign_maintenance_refused',not E.maintainActor('person',__other) and __body:getXp():getMultiplier(Perks.Strength)==multiplier)
SandboxVars.FWOFitness.PassiveMultiplier=1;E.interrupt('person',__body,'cleanup')

local function intent(activity)
    for _,o in ipairs(E.intentOffers('person',__body)) do if o.activity==activity then return o end end
end
fresh('benchpress');__body:setPrimaryHandItem(nil)
check('unprepared_bench_is_intent_only',offer('benchpress')==nil and intent('benchpress')~=nil)
local intended=intent('benchpress')
check('intent_exact_source_carried_equipment',intended.requiresPreparation.equipPrimary.itemKey==tostring(__barbell:getID())
    and intended.requiresPreparation.equipPrimary.twoHands==true)
check('intent_has_no_native_effect',__body:getPrimaryHandItem()==nil and E.work('person')==nil)
fresh('treadmill');__body:getModData().LSMoodles=nil
check('yoga_initialization_is_intent_only',offer('yoga')==nil and intent('yoga').requiresPreparation.sourceInitialization==true)
check('yoga_intent_does_not_initialize_body',__body:getModData().LSMoodles==nil)
fresh('treadmill');__body:getStats():set(CharacterStat.ENDURANCE,.1)
check('exhausted_yoga_has_no_preparable_intent',intent('yoga')==nil)
fresh('treadmill');__observations={}
check('hidden_machine_cannot_generate_intent',intent('treadmill')==nil)
check('foreign_body_cannot_generate_intent',#E.intentOffers('person',__other)==0)
fresh('treadmill');__body:setY(21.5);__body:setCurrent(__body:getCell():getGridSquare(10,21,0))
intended=intent('treadmill')
check('intent_exact_observed_front_route',offer('treadmill')==nil and intended and intended.requiresPreparation.frontSquare.x==10
    and intended.requiresPreparation.frontSquare.y==20 and intended.requiresPreparation.targetZ==0
    and intended.targetX==10 and intended.targetY==20 and intended.targetZ==0)
__body:setY(20.5);__body:setCurrent(__body:getCell():getGridSquare(10,20,0))

-- Differential source receivers on the same actual NPC/body preparation.
local function physicalSnapshot()
    return {endurance=__body:getStats():get(CharacterStat.ENDURANCE),thirst=__body:getStats():get(CharacterStat.THIRST),
        boredom=__body:getStats():get(CharacterStat.BOREDOM),strength=__body:getXp():getXP(Perks.Strength),
        sprinting=__body:getXp():getXP(Perks.Sprinting),fitness=__body:getXp():getXP(Perks.Fitness),nimble=__body:getXp():getXP(Perks.Nimble)}
end
local function equal(a,b)
    for k,v in pairs(a) do if math.abs(v-b[k])>.00002 then return false end end return true
end
for _,activity in ipairs({'benchpress','treadmill'}) do
    fresh(activity);local nativeWork,nativeAction=begin(activity);nativeAction:start();nativeAction:animEvent('ActiveAnimLooped',nil)
    local scoped=physicalSnapshot();E.interrupt('person',__body,'cleanup')
    fresh(activity);__body:getFitness():init()
    local original=ISFitnessAction:new(__body,activity,10,FitnessExercises.exercisesType[activity],activity)
    ISTimedActionQueue.addGetUpAndThen(__body,original);original:start();original:animEvent('ActiveAnimLooped',nil)
    check(activity=='benchpress' and 'original_bench_native_effect_parity' or 'original_treadmill_native_effect_parity',equal(scoped,physicalSnapshot()))
end
fresh('treadmill');__observations={};local yogaWork,scopedYoga=begin('yoga');scopedYoga:waitToStart();scopedYoga:start()
for i=1,35 do scopedYoga:update() end;E.advance('person',__body)
local scoped=physicalSnapshot();local hidden=__body:getModData().LSHiddenSkills.Yoga[2]
fresh('treadmill');__observations={};HiddenSkills.getSkill(__body,'Yoga')
local original=LSYogaAction:new(__body,0,{'Beginner',50,1,2})
ISTimedActionQueue.addGetUpAndThen(__body,original);original:waitToStart();original:start()
for i=1,35 do original:update() end
check('original_yoga_native_effect_parity',equal(scoped,physicalSnapshot()) and __body:getModData().LSHiddenSkills.Yoga[2]==hidden)

print('PASS source exercise '..checks)
