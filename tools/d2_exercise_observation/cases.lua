local E=SAO.LeisureExercise
local checks=0
local function check(name,yes)assert(yes,'EXERCISE:'..name);checks=checks+1;print('CASE '..name)end
local function preparePurpose(offer,purposeId)
    local purpose={id=purposeId,domain='leisure',status='maintained',affordance=offer.sourceId,cursor=1,
        leisure={activity=offer.activity,itemKey=offer.itemKey},
        steps={{id='perform-activity',owner='SAO.LeisureExercise',token='leisure:performed',status='available'}}}
    __records.person.proceduralPlanning={schema=1,purposes={[purposeId]=purpose},order={purposeId},spatial={},spatialOrder={},practice={}}
    return purpose
end
local function fresh()
    __hours=10;__ms=1000000;__queueRefuse=false;__denied=false;__conceptDenied=false;__busy=false
    __records={person={id='person'},other={id='other'}};__bodies={person=__body,other=__other}
    for _,pair in ipairs({{__body,'person'},{__other,'other'}}) do
        pair[1]:getModData().SAOPersonId=pair[2];pair[1]:getModData().SAOExternalToken=nil
        pair[1]:setAsleep(false);pair[1]:getStats():set(CharacterStat.ENDURANCE,1)
        pair[1]:setPrimaryHandItem(nil);pair[1]:setSecondaryHandItem(nil)
        pair[1]:getFitness():init()
    end
    __queue.queue={}
    __observations={}
end
local function begin()
    local offer=E.offers('person',__body)[1]
    assert(offer and offer.activity=='squats','missing-native-squats')
    preparePurpose(offer,'purpose-1')
    local accepted,w=E.begin('person',__body,offer,'purpose-1')
    assert(accepted,'native-admission-refused '..tostring(w))
    return w,__action
end
local function elapsed()
    __hours=10.2;__ms=1600001
end
fresh()
local offers=E.offers('person',__body)
check('native_no_equipment_repertoire',#offers==4)
check('foreign_body_cannot_offer',#E.offers('person',__other)==0)
__conceptDenied=true;check('concept_required',#E.offers('person',__body)==0);__conceptDenied=false
__denied=true;check('standing_required',#E.offers('person',__body)==0);__denied=false
__busy=true;check('native_work_required',#E.offers('person',__body)==0);__busy=false
local offer=E.offers('person',__body)[1];offer.revision='spoof'
check('spoof_source_refused',not E.begin('person',__body,offer,'purpose-1'))
offer=E.offers('person',__body)[1]
check('typed_admission_precedes_native_queue',not E.begin('person',__body,offer,'missing-purpose') and #__queue.queue==0)
check('typed_refusal_has_no_fabricated_result',E.outcome('person',1)==nil and E.work('person')==nil)
fresh()
local w,action=begin()
check('detached_work',E.work('person')~=__records.person.exerciseLeisureWork)
local detached=E.work('person');detached.status='completed';check('detached_work_no_mutation',E.work('person').status=='prepared')
check('duplicate_admission_refused',not E.begin('person',__body,E.offers('person',__body)[1],'purpose-2'))
action:animEvent('ActiveAnimLooped',nil)
check('actual_native_repeat_progress',__records.person.exerciseLeisureWork~=nil and action.repnb==1)
local endurance=__body:getStats():get(CharacterStat.ENDURANCE)
check('actual_native_repeat_effect',endurance<1)
check('active_receipt_not_completed',E.advance('person',__body) and not E.outcome('person',w.sequence))
elapsed();action:update();E.advance('person',__body)
local out=E.outcome('person',w.sequence)
check('owned_duration_with_native_repeat_completes',out and out.status=='completed' and out.nativeProgress.repetitions==1)
check('actual_planner_consumes_native_completion',out.plannerConsumed==true and __records.person.proceduralPlanning.purposes['purpose-1'].status=='completed')
check('measured_native_effect',out.measuredEffects.deltas.ENDURANCE<0)
check('no_operator_clock_mutation',__clockWrites==0)
local n=#__records.person.exerciseLeisureOutcomes;E.advance('person',__body)
check('exact_once_terminal',# __records.person.exerciseLeisureOutcomes==n)
out.status='spoof';check('detached_outcome_no_mutation',E.outcome('person',w.sequence).status=='completed')
fresh();w,action=begin();elapsed();action:update();E.advance('person',__body)
check('duration_without_repeat_not_success',E.outcome('person',w.sequence).status=='interrupted')
fresh();w,action=begin();action:animEvent('ActiveAnimLooped',nil);elapsed();action:stop();E.advance('person',__body)
check('late_external_stop_not_completion',E.outcome('person',w.sequence).status=='interrupted')
fresh();w,action=begin();action:perform();E.advance('person',__body)
check('perform_preserves_operator_clock',__clockWrites==0 and E.outcome('person',w.sequence).status=='interrupted')
fresh();w,action=begin();action:animEvent('ActiveAnimLooped',nil);__hours=10.01;E.interrupt('person',__body,'need')
check('partial_progress_retained',E.outcome('person',w.sequence).status=='interrupted' and E.outcome('person',w.sequence).nativeProgress.repetitions==1)
fresh();w,action=begin();__queue.queue={};E.advance('person',__body)
check('queue_custody_required',E.outcome('person',w.sequence).reason=='native-queue-custody-lost')
fresh();w,action=begin();__body:getModData().SAOExternalToken='replaced';__records.person.bodyOwnerToken='replaced'
local before=__body:getStats():get(CharacterStat.ENDURANCE);action:animEvent('ActiveAnimLooped',nil);E.advance('person',__body)
check('stale_body_no_effect',__body:getStats():get(CharacterStat.ENDURANCE)==before and action.repnb==0)
check('stale_body_no_success',E.outcome('person',w.sequence).status=='interrupted')
check('stale_body_no_borrowed_measurement',E.outcome('person',w.sequence).measuredEffects.afterUnavailable==true)
check('stale_native_complete_refused',action:complete()==false)
fresh();w,action=begin();check('foreign_advance_refused',not E.advance('person',__other));check('foreign_interrupt_refused',not E.interrupt('person',__other))
E.interrupt('person',__body,'cleanup')
fresh();w,action=begin();__hours=9
local before=__body:getStats():get(CharacterStat.ENDURANCE)
action:animEvent('ActiveAnimLooped',nil)
check('regressed_clock_no_repeat',__body:getStats():get(CharacterStat.ENDURANCE)==before)
check('regressed_clock_no_receipt',not E.advance('person',__body) and not E.outcome('person',w.sequence))
__hours=10;E.interrupt('person',__body,'cleanup')
fresh();w,action=begin();__records.person.exerciseLeisureWork.actorId='other'
check('spoof_saved_actor_no_credit',not E.advance('person',__body) and not E.outcome('person',w.sequence))
__records.person.exerciseLeisureWork.actorId='person';E.interrupt('person',__body,'cleanup')
fresh();w,action=begin();__records.person.proceduralPlanning.purposes['purpose-1'].status='abandoned'
before=__body:getStats():get(CharacterStat.ENDURANCE);action:animEvent('ActiveAnimLooped',nil)
check('retired_purpose_cannot_repeat_native_exercise',__body:getStats():get(CharacterStat.ENDURANCE)==before)
E.advance('person',__body)
check('retired_purpose_cannot_revive',__records.person.proceduralPlanning.purposes['purpose-1'].status=='abandoned')
fresh();__queueRefuse=true
local queuedOffer=E.offers('person',__body)[1];preparePurpose(queuedOffer,'purpose-1')
check('queue_refusal_not_success',not E.begin('person',__body,queuedOffer,'purpose-1'))
check('queue_refusal_receipt',E.outcome('person',1).status=='interrupted')
fresh();w,action=begin();__records=__roundTrip(__records);__reloadGesture();E.advance('person',__body)
check('reload_cannot_invent_native_completion',E.outcome('person',w.sequence).status=='interrupted')
check('reload_outcome_reason',E.outcome('person',w.sequence).reason=='reload-native-custody-unavailable')
check('aquarium_prerequisite_explicit',E.sourceAvailability('aquarium')==true)
check('equipment_prerequisite_explicit',E.sourceAvailability('equipment-exercise')==false)
check('no_operator_clock_mutation_after_all_lifecycles',__clockWrites==0)
local function aquariumFresh()
    fresh();__conceptDenied=true
    SandboxVars.KnoxAquarium={}
    __tank:getModData().KnoxAquarium={mode='water',fish={{name='fixture'}},water=20}
    __body:getStats():set(CharacterStat.UNHAPPINESS,30)
    __body:getStats():set(CharacterStat.BOREDOM,30)
    __body:getStats():set(CharacterStat.STRESS,.8)
    local row={actorId='person',kind='object',concept='aquarium',source='native-personal-visibility',at=__hours*9000,
        key='object:10:20:0:0:aquarium',objectIndex=0,spriteName='fixture-aquarium',runtimeInstance='aquarium-1',
        aquariumMode='water',aquariumOccupied=true,aquariumWaterPresent=true}
    __observations={row}
    return row
end
local function aquariumBegin()
    local offer=E.offers('person',__body)[1];assert(offer and offer.family=='aquarium','tank-offer-missing')
    preparePurpose(offer,'aquarium-purpose')
    local ok,w=E.begin('person',__body,offer,'aquarium-purpose');assert(ok,'tank-admission-refused')
    return w
end
local function aquariumElapsed()
    __hours=10.02
    for _,row in ipairs(__observations) do row.at=__hours*9000 end
end
local row=aquariumFresh()
check('aquarium_actual_acquired_offer',#E.offers('person',__body)==1)
__observations={};check('aquarium_unobserved_tank_excluded',#E.offers('person',__body)==0)
__observations={row};row.source='map-truth';check('aquarium_hidden_not_acquired',#E.offers('person',__body)==0)
row.source='native-personal-visibility';row.at=__hours*9000-121
check('aquarium_stale_observation_refused',#E.offers('person',__body)==0)
row.at=__hours*9000+1;check('aquarium_future_observation_refused',#E.offers('person',__body)==0)
row.at=__hours*9000;row.actorId='other';check('aquarium_foreign_observation_refused',#E.offers('person',__body)==0)
row=aquariumFresh();row.runtimeInstance='unacquired-replacement'
check('aquarium_unacquired_replacement_refused',#E.offers('person',__body)==0)
row=aquariumFresh();row.spriteName='wrong';check('aquarium_exact_sprite_required',#E.offers('person',__body)==0)
row=aquariumFresh();__tank:getModData().KnoxAquarium.water=0
check('aquarium_water_change_refused',#E.offers('person',__body)==0)
row=aquariumFresh();__tank:getModData().KnoxAquarium.fish={}
check('aquarium_fish_change_refused',#E.offers('person',__body)==0)
row=aquariumFresh();SandboxVars.KnoxAquarium.ComfortEnabled=false
check('aquarium_sandbox_disable_respected',#E.offers('person',__body)==0)
row=aquariumFresh();__observations={row,row};w=aquariumBegin();aquariumElapsed();E.advance('person',__body)
out=E.outcome('person',w.sequence)
check('aquarium_actual_source_effect',out and out.status=='completed' and out.nativeProgress.applications==1)
check('actual_planner_consumes_aquarium_effect',out.plannerConsumed==true and __records.person.proceduralPlanning.purposes['aquarium-purpose'].status=='completed')
check('aquarium_duplicate_tank_not_counted',out.nativeProgress.tanks==1)
check('aquarium_measured_source_effect',math.abs(out.nativeProgress.sourceApplicationEffects.deltas.UNHAPPINESS+.5)<.00002)
check('aquarium_source_uses_actual_stats',math.abs(__body:getStats():get(CharacterStat.STRESS)-.6)<.00002)
-- Compare the original KA_Comfort receiver at identical actual native body,
-- single acquired physical tank and sandbox cap against the scoped adaptation.
__body:getStats():set(CharacterStat.UNHAPPINESS,30);__body:getStats():set(CharacterStat.BOREDOM,30);__body:getStats():set(CharacterStat.STRESS,.8)
getCell=function()return __body:getCell()end
local count=KnoxAquarium.applyComfort(__body)
check('aquarium_native_source_equivalence',count==1 and math.abs(__body:getStats():get(CharacterStat.UNHAPPINESS)-29.5)<.00002
    and math.abs(__body:getStats():get(CharacterStat.BOREDOM)-(30-1/3))<.00002
    and math.abs(__body:getStats():get(CharacterStat.STRESS)-.6)<.00002)
row=aquariumFresh();w=aquariumBegin();aquariumElapsed();__tank:getModData().KnoxAquarium.fish={};E.advance('person',__body)
check('aquarium_change_interrupts_without_effect',E.outcome('person',w.sequence).status=='interrupted' and __body:getStats():get(CharacterStat.UNHAPPINESS)==30)
row=aquariumFresh();__records.person.lastAquariumComfortAtHours=10.015;w=aquariumBegin();aquariumElapsed();E.advance('person',__body)
check('aquarium_cadence_prevents_repeat',E.outcome('person',w.sequence).reason=='comfort-cadence')
row=aquariumFresh();w=aquariumBegin();E.interrupt('person',__body,'need');check('aquarium_early_stop_no_effect',__body:getStats():get(CharacterStat.UNHAPPINESS)==30)
row=aquariumFresh();w=aquariumBegin();__records=__roundTrip(__records);__reloadGesture();aquariumElapsed();E.advance('person',__body)
check('aquarium_reload_cannot_award_comfort',E.outcome('person',w.sequence).status=='interrupted')
print('PASS exercise observation '..checks)
