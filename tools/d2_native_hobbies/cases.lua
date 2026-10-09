local L=SAO.Leisure
local count=0
local function check(name,ok)assert(ok,'D2_HOBBY:'..name);count=count+1;print('CASE '..name)end
local function offer()return L.offers('person',__body)[1]end
local function begin()return L.begin('person',__body,offer(),'purpose:1')end
local function progress(delta)
    local action=__queued
    action:start();__delta=delta;action:update();return action
end
do
    local rec=__fresh();local offered=offer()
    check('source_bound_offer',offered and offered.actorId=='person' and offered.sourceId=='LifestyleHobbies'
        and #offered.revision==64 and offered.evidence.evidenceIds[1]=='acquired:person:meditation')
    check('plain_offer_save',__roundtrip(offered).activity=='meditate')
    check('prepared_admission',begin() and rec.leisureWork.phase=='prepared' and __consumed==0)
    check('duplicate_begin_refused',not begin())
    local action=progress(.5)
    action:update() -- Original source adjustStats invokes actual LSUtil over native Stats.
    check('source_actual_stress_effect',__stats:get(CharacterStat.STRESS)<.8)
    check('source_actual_boredom_cost',__stats:get(CharacterStat.BOREDOM)>15)
    check('native_progress_observed',L.work('person').nativeProgress.delta==.5)
    check('source_neck_pain_cost',__body:getBodyDamage():getBodyPart('Neck'):getAdditionalPain()>0)
    check('xp_not_manufactured',__xpMessages>0 and L.work('person').skillCredit==nil)
    __delta=1;action:update();action:perform()
    local result=L.outcome('person',1)
    check('completion_measured',result and result.status=='completed' and result.nativeProgress.delta==1
        and result.before.Stress>result.after.Stress and result.nativeOwner=='LSMeditateAction')
    check('completion_exact_once',__consumed==1 and #rec.leisureOutcomes==1)
    action:perform();action:stop();check('late_callbacks_no_credit',#rec.leisureOutcomes==1 and __consumed==1)
    result.after.Stress=999;check('detached_outcome',L.outcome('person',1).after.Stress~=999)
    check('foreign_outcome',L.outcome('foreign',1)==nil)
    check('native_persistence',__roundtrip(rec).leisureOutcomes[1].workId=='leisure:person:1')
end
do
    local rec=__fresh();check('partial_admitted',begin());local action=progress(.25);action:update();action:stop()
    local result=L.outcome('person',1)
    check('partial_is_interruption',result.status=='interrupted' and result.nativeProgress.delta==.25)
    check('partial_measured_preserved',result.after.Stress<result.before.Stress)
    check('interruption_no_completion',result.token=='leisure:interrupted')
end
do
    local rec=__fresh();check('no_progress_admitted',begin());__queued:start();__delta=1;__queued:perform()
    check('instant_perform_no_proof',L.outcome('person',1)==nil and rec.leisureWork.status=='active')
    __queued:stop();check('no_progress_interrupted',L.outcome('person',1).nativeProgress.delta==0)
end
do
    local rec=__fresh();local old=offer();old.actorId='foreign'
    check('spoof_offer_refused',not L.begin('person',__body,old,'purpose:1'))
    old=offer();old.revision='stale';check('stale_revision_refused',not L.begin('person',__body,old,'purpose:1'))
    old=offer();old.evidence.evidenceIds[1]='invented';check('spoof_evidence_refused',not L.begin('person',__body,old,'purpose:1'))
    old=offer();__body:getModData().SAOExternalToken='generation:2'
    check('stale_generation_refused',not L.begin('person',__body,old,'purpose:1'))
    check('unknown_purpose_refused',not L.begin('person',__body,offer(),'foreign:purpose'))
end
do
    __fresh();__owned=false;check('foreign_body_refused',offer()==nil)
    __fresh();__active=false;check('owned_source_missing_refused',offer()==nil)
    __fresh();__client=true;check('mp_binding_refused',offer()==nil)
    __fresh();__familiar=false;check('unacquired_concept_refused',offer()==nil)
    __fresh();__sitting=false;check('missing_posture_refused',offer()==nil)
    __fresh();__body:getModData().LSMoodles=nil;check('missing_source_person_state_refused',offer()==nil)
    __fresh();__stats:set(CharacterStat.BOREDOM,31);check('native_boredom_refusal',offer()==nil)
end
do
    local rec=__fresh();__body:getModData().LSMoodles=nil;__sitting=false
    local intent=L.intentOffers('person',__body)[1]
    check('intent_retains_real_preparation',intent and intent.requiresPreparation.sourceInitialization
        and intent.requiresPreparation.sitOnGround and offer()==nil)
    check('source_actor_initialized',L.prepareActor('person',__body)
        and __body:getModData().LSMoodles.MindfulState.Value==0
        and __body:getModData().LSMoodles.WasTaughtSkill.Value==0)
    check('initializer_provenance',rec.leisureSourceInitialization.nativeOwner=='LSMoodleManager.init')
    __sitting=true;check('source_preparation_makes_offer_executable',offer()~=nil)
    __body:getModData().LSMoodles.MindfulState.Value=.4
    check('source_init_preserves_valid_values',L.prepareActor('person',__body)
        and __body:getModData().LSMoodles.MindfulState.Value==.4)
    __owned=false;check('foreign_initializer_refused',not L.prepareActor('person',__body))
    __fresh();__familiar=false;check('unknown_concept_has_no_intent',#L.intentOffers('person',__body)==0)
end
do
    local rec=__fresh();__admit=false;check('planner_refusal_prevents_queue',not begin() and not __queued)
    check('planner_refusal_terminal',rec.leisureWork.reason=='leisure-planner-admission-refused')
    __fresh();__refuseQueue=true;check('native_queue_refusal',not begin() and not __queued)
end
do
    local rec=__fresh();check('reload_admitted',begin());progress(.25)
    __reload();check('reload_no_completion',rec.leisureWork.status=='interrupted' and #rec.leisureOutcomes==1)
    check('reload_revalidation',offer()~=nil and rec.leisureSequence==1)
end
do
    local rec=__fresh();check('lost_owner_admitted',begin());progress(.25);__owned=false
    check('lost_owner_interrupted',not L.advance('person',__body) and rec.leisureWork.status=='interrupted')
    check('lost_owner_after_not_fabricated',L.outcome('person',1).afterCurrent==false)
end
do
    local rec=__fresh();begin();local action=__queued;__soundFault=true;action:start()
    check('source_start_fault_interrupted',rec.leisureWork.status=='interrupted'
        and rec.leisureWork.reason=='native-source-start-failed' and not __queued)
    __fresh();begin();action=__queued;action:start();__soundFault=true;action:update()
    check('source_update_fault_cleanup',__records.person.leisureWork.status=='interrupted'
        and __body:getModData().IsMeditating==false and not __queued)
    __fresh();begin();action=progress(.25);__soundStopFault=true;action:stop()
    check('source_cleanup_fault_explicit',L.outcome('person',1).cleanupSucceeded==false)
end
check('unsafe_yoga_explicit',L.compatibility('yoga')=='source-fitnessBonus-mutates-global-exercises')
check('unsafe_music_explicit',L.compatibility('music')=='source-start-stop-mutate-operator-music-volume')
print('PASS D2 native hobbies '..count)
