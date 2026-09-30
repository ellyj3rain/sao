#!/usr/bin/env python3
"""Border 216: private labor assessment drives maintained native resource chains.

Production Labor, ProceduralPlanning, Cognition, WorldSources and SourceUse run
in installed Kahlua. Native bridge responses and bodies are controlled here;
source transfer ownership and prior Cooking native probes remain separate.
No renderer, simulation prevalence, future yield or dataset acceptance is claimed.
"""
from pathlib import Path
import json
import os
import re
import shutil
import subprocess
import tempfile

import source_use_test as fixture

ROOT = Path(__file__).resolve().parent.parent
LUA = ROOT / 'mod/42.20/media/lua'
GAME, JDK = fixture.PZ_DIR, fixture.JDK
FILES = {
    'world': LUA / 'shared/SAO_WorldSources.lua',
    'labor': LUA / 'shared/SAO_Labor.lua',
    'models': LUA / 'shared/SAO_CognitiveModels.lua',
    'cognition': LUA / 'shared/SAO_Cognition.lua',
    'planner': LUA / 'shared/SAO_ProceduralPlanning.lua',
    'source': LUA / 'client/SAO_SourceUse.lua',
}
BEFORE = fixture.snapshot(1, 1, 's1', [{
    'id': 'C:pantry:0', 'fp': 'pantry', 'rev': 'r1', 'kind': 'container',
    'x': 8, 'y': 8, 'building': 42, 'quantities': {'food': 2, 'water': 1},
    'items': [{'id': 12, 'type': 'Base.Chicken', 'amount': 1, 'cats': 'food'},
              {'id': 13, 'type': 'Base.Apple', 'amount': 1, 'cats': 'food'},
              {'id': 14, 'type': 'Base.WaterBottle', 'amount': 1, 'cats': 'water'}],
}])
AFTER = fixture.snapshot(1, 1, 's2', [{
    'id': 'C:pantry:0', 'fp': 'pantry', 'rev': 'r2', 'kind': 'container',
    'x': 8, 'y': 8, 'building': 42, 'quantities': {'food': 1, 'water': 1},
    'items': [{'id': 13, 'type': 'Base.Apple', 'amount': 1, 'cats': 'food'},
              {'id': 14, 'type': 'Base.WaterBottle', 'amount': 1, 'cats': 'water'}],
}])

SETUP = r'''
require=function() end
SAO.Census={skillOf=function() return 0 end}
SAO.Lessons={has=function(_,work) return work=='quartermaster' end}
SAO.Standing.mayEngageZombie=function() return false end
SAO.Material={storeForPerson=function() return {items={actual=1}} end}
SandboxVars={SurvivorAwareness={Material=true}}
__hours=48
SAO.History.countyHours=function() return __hours end
SAOJavaBridge.carriedWorldTransferItem=function()
    return 'T|operation=acquire|source=C:pantry:0|id=12|type=Base.Chicken|uses=1|amount=1|fluid=|poison=0|rotten=0|cats=food'
end
'''

CASES = r'''
local checks={}
local function check(name,value) checks[#checks+1]=name..'='..tostring(value==true) end
local P,L,C,M=SAO.ProceduralPlanning,SAO.Labor,SAO.Cognition,SAO.CognitiveModels
local place={id=42,cx=8,cy=8,minX=8,minY=8,maxX=16,maxY=16}
local function reset()
    __stores={} __records={a={id='a',occupation='salesperson'},b={id='b'}}
    __bodies={a=__newBody(8,8),b=__newBody(8,8)} __places={[42]=place}
    SAO.Body.active=__bodies
    SAO.WorldSources.applySnapshot(SAO.WorldSources.parse(__before))
    local quantities,revision,access,facts=SAO.WorldSources.beliefSnapshot(place)
    __known={a={[42]={cx=8,cy=8,sources=quantities,sourceRevision=revision,
        sourceAccess=access,sourceFacts=facts}},b={[42]={cx=8,cy=8,sourceFacts={}}}}
    __targetAnswer='READY:8:8:0:8:8:0' __bindAnswer='BOUND:8:8:0'
    __observeText=__before __sourceItem={exact=true} __carriedItem=nil
    __sourceContainer={} __permissionContainer={} __busy=false __queued=nil
    __routeAllowed=true __standingAllowed=true __queueReject=false __hours=48
    return {category='food',pressure=.35,atHours=48,carriedReady=0,carriedRaw=0,
        carriedWater=0,carriedItems=0,needs={fatigue=.25},health=.85,
        contacts={'b','b','a'},commitments={{id='accepted/1',owner='Posture',status='paused'}},
        sources={{sourceId='C:pantry:0',revision='r1',place=place,category='food',
            quantity=2,quantityUnit='item',itemType='Base.Chicken',itemId=12,
            known=true,distance=8,cookable=true}},inspectPlace=place}
end
local context=reset()
local caps=L.capabilityOf('a')
check('zero_native_skill_allows_basic_attempt',caps.canCook and caps.canForage and caps.canTreat)
local profile=L.assess('a',context)
check('occupation_remains_prior_life',profile.capacity.priorLife=='salesperson'
    and profile.capacity.skills.Cooking==0 and __records.a.occupation=='salesperson')
context.skills={Cooking=6}
profile=L.assess('a',context)
check('actual_native_skill_overrides_prior_life_readiness',profile.capacity.skills.Cooking==6
    and profile.options[1].technique.level==6 and profile.capacity.health==.85)
context.skills=nil
check('labor_material_toggle_still_scopes_existing_store',L.choose('a',1,0)=='quartermaster')
SandboxVars.SurvivorAwareness.Material=false
check('disabled_material_store_stays_unread',L.choose('a',1,0)=='cook')
SandboxVars.SurvivorAwareness.Material=true
profile=L.assess('a',context)
check('eight_labor_dimensions_keep_unknown_social_evidence',profile.dimensions.slack.status=='unknown'
    and profile.dimensions.groupValues.status=='unknown' and profile.dimensions.lowPressureWish.status=='open'
    and profile.dimensions.openProjects.status=='person-private' and #profile.contacts==1)
context.pressure=0
check('zero_pressure_preserves_slack',P.planResource('a',context)==nil and __records.a.proceduralPlanning==nil)
context.pressure=.35 context.carriedReady=1
check('held_ready_resource_avoids_new_labor',P.planResource('a',context)==nil)
context.carriedReady=0
check('unknown_actor_source_is_not_an_option',#L.assess('b',context).options==1
    and L.assess('b',context).options[1].kind=='inspect')
context.sources[1].revision='unobserved'
check('wrong_private_revision_cannot_supply_item',#L.assess('a',context).options==1)
context.sources[1].revision='r1'
context.sources[1].place={id=42,cx=500,cy=500}
check('remembered_identity_cannot_smuggle_unknown_coordinates',#L.assess('a',context).options==1)
context.sources[1].place=place
local purpose,step=P.planResource('a',context)
check('actual_choice_drives_acquire_then_prepare',step.verb=='acquire' and step.itemId==12
    and step.sourceRevision=='r1' and #purpose.steps==2 and purpose.steps[2].owner=='Cooking')
check('models_independently_disagree_on_feasible_routes',purpose.interpretations.disagreement==true
    and purpose.interpretations.models[1].selected==purpose.selectedStrategy
    and purpose.interpretations.models[2].selected=='inspect:42')
local original=M.interpretPlans
local seen={}
M.interpretPlans=function(model,state,candidates,ctx)
    seen[#seen+1]=candidates[1].evidence
    local answer=original(model,state,candidates,ctx)
    state.tainted=true candidates[1].evidence=0
    return answer
end
P.planResource('a',context)
M.interpretPlans=original
check('independent_models_receive_same_feasible_candidates',#seen==2 and seen[1]==seen[2]
    and not __records.a.cognition.models.ordinary.tainted and not __records.a.cognition.models.associative.tainted)
local revision,events=purpose.revision,#purpose.events
local again=P.planResource('a',context)
check('decision_ticks_do_not_replace_goal',again==purpose and purpose.revision==revision
    and #purpose.events==events and #__records.a.proceduralPlanning.order==1)
P.interrupt('a',purpose.id,'accepted-cooperation',48)
again,step=P.planResource('a',context)
check('interruption_retains_same_chain',again==purpose and step.itemId==12 and #purpose.steps==2)
local fabricated=P.recordResult('a',purpose.id,{owner='SAO.SourceUse',token='resource:acquired',status='completed'})
check('unverified_resource_result_never_grants_credit',fabricated==false and purpose.cursor==1)
-- Restore this isolated motivating defect's cursor so its mutation control
-- can report its named false verdict without corrupting later owner cases.
if fabricated then purpose.cursor=1 purpose.steps[1].status='available' end
local ok,reservation=SAO.SourceUse.beginAcquisition('a',__bodies.a,place,'food',{
    purposeId=purpose.id,purposeStepId=step.id,sourceId=step.sourceId,itemId=step.itemId,
    sourceRevision=step.sourceRevision,acceptItem=function(t) return t=='Base.Chicken' end})
check('native_acquisition_admission_keeps_goal_pending',ok==true and reservation
    and purpose.admission.correlationId==reservation.id and purpose.cursor==1)
context.sources={} context.inspectPlace=nil
again,step=P.planResource('a',context)
check('admitted_attempt_is_not_replaced_by_later_assessment',again==purpose and step.itemId==12)
SAO.SourceUse.onMovementDone('a',__bodies.a,'arrived')
__carriedItem=__sourceItem __busy=false __observeText=__after
SAO.SourceUse.tick('a',__bodies.a)
local receipt=SAO.WorldSources.actionOutcome(reservation.id,'a')
check('native_transfer_advances_only_acquisition',receipt and P.consumeSourceResult(receipt)==true
    and purpose.cursor==2 and purpose.status=='maintained' and purpose.steps[2].acquiredItemId==12)
check('native_receipt_replay_never_advances_preparation',P.consumeSourceResult(receipt)==true and purpose.cursor==2)
P.interrupt('a',purpose.id,'urgent-threat',49)
context.carriedRaw=1 context.carriedRawItems={{itemId=12,itemType='Base.Chicken',cookable=true}}
context.atHours=49
again,step=P.planResource('a',context)
check('completed_acquisition_and_exact_item_survive_interruption',again==purpose and purpose.cursor==2
    and #purpose.steps==2 and purpose.steps[1].status=='completed' and step.acquiredItemId==12)
SAO.ProceduralPlanning=nil
P=__reloadPlanner()
again,step=P.planResource('a',context)
check('module_reload_keeps_person_private_resource_chain',again==purpose and purpose.cursor==2
    and #__records.a.proceduralPlanning.order==1 and step.acquiredItemId==12)
local work={id='cooking/a/1',itemId=12,requestedPurposeId=purpose.id,requestedPurposeStepId=step.id}
check('explicit_cooking_admission_binds_resource_chain',P.admitCooking('a',work)==true
    and work.purposeId==purpose.id and purpose.admission.correlationId==work.id)
local old={id=work.id,actorId='a',purposeId=purpose.id,purposeStepId=step.id,
    status='completed',retrieved=true,heatObserved=true,shutdown='off',atHours=50}
__records.a.cookingOutcomes={old}
check('native_preparation_credit_cannot_be_fabricated',P.consumeCookingResult('a',old)==false and purpose.status~='completed')
old.nativeCredit=old.id
local replacement={id='cooking/a/2',itemId=12,requestedPurposeId=purpose.id,requestedPurposeStepId=step.id}
P.admitCooking('a',replacement)
check('superseded_preparation_never_completes_replacement',P.consumeCookingResult('a',old)==true
    and purpose.status~='completed' and purpose.admission.correlationId==replacement.id)
local outcome={id=replacement.id,actorId='a',purposeId=purpose.id,purposeStepId=step.id,
    status='completed',nativeCredit=replacement.id,retrieved=true,heatObserved=true,shutdown='off',atHours=50}
__records.a.cookingOutcomes[# __records.a.cookingOutcomes+1]=outcome
check('native_preparation_finishes_exact_retained_goal',P.consumeCookingResult('a',outcome)==true
    and purpose.status=='completed' and P.resourceDemand('a','food')==nil)
local completed=__records.a.proceduralPlanning.practice.Cooking.completed
check('preparation_completion_is_exact_once',P.consumeCookingResult('a',outcome)==true
    and __records.a.proceduralPlanning.practice.Cooking.completed==completed)
profile=L.assess('a',context)
check('time_evidence_comes_from_native_observed_work',profile.capacity.timeEvidence.samples==1
    and profile.capacity.timeEvidence.basis=='actor-native-admission-to-completed-result'
    and profile.capacity.timeEvidence.observedMinimumHours==2)
local snapshot=P.snapshot('a')
snapshot.purposes[1].demand.pressure=0 snapshot.purposes[1].sequence[1].itemId=99
snapshot.purposes[1].interpretations.models[1].selected='forged'
check('resource_observation_is_bounded_detached_data',purpose.demand.pressure==.35
    and purpose.steps[1].itemId==12 and purpose.interpretations.models[1].selected~='forged'
    and snapshot.purposes[1].labor.slack.status=='unknown')

context=reset() context.sources={} context.inspectPlace=nil
purpose,step=P.planResource('a',context)
check('unmet_demand_keeps_blocker_and_contacts',purpose.status=='blocked' and not step
    and purpose.contacts[1]=='b' and purpose.blockers[1]=='no-known-executable-resource-route'
    and purpose.labor.materialsAndSpace.completeness=='partial')
context.carriedReady=1 context.carriedReadyItems={{itemId=55,itemType='Base.Apple'}}
again,step=P.planResource('a',context)
check('new_owned_food_resolves_blocked_goal_without_work_credit',again==purpose and not step
    and purpose.status=='completed' and purpose.resolution=='native-owned-usable-stock'
    and P.resourceDemand('a','food')==nil and not __records.a.proceduralPlanning.practice.Cooking)
context=reset() context.category='water' context.sources={} context.inspectPlace=nil
purpose,step=P.planResource('a',context)
context.carriedWater=1
again,step=P.planResource('a',context)
check('new_owned_water_resolves_blocked_goal_without_work_credit',again==purpose and not step
    and purpose.status=='completed' and P.resourceDemand('a','water')==nil)
context=reset()
purpose,step=P.planResource('a',context)
ok,reservation=SAO.SourceUse.beginAcquisition('a',__bodies.a,place,'food',{
    purposeId=purpose.id,purposeStepId=step.id,sourceId=step.sourceId,itemId=step.itemId,
    sourceRevision=step.sourceRevision,acceptItem=function(t) return t=='Base.Chicken' end})
context.carriedReady=1 context.carriedReadyItems={{itemId=55,itemType='Base.Apple'}}
again,step=P.planResource('a',context)
check('new_owned_stock_keeps_active_native_admission_authority',ok and again==purpose and step
    and purpose.status=='maintained' and purpose.admission.correlationId==reservation.id)
P.interrupt('a',purpose.id,'actual-danger',48)
again,step=P.planResource('a',context)
check('interrupted_native_admission_precedes_stock_resolution',again==purpose and step
    and purpose.status=='interrupted' and purpose.admission.correlationId==reservation.id)
context=reset() context.sources={} context.inspectPlace=nil
purpose,step=P.planResource('a',context)
context.inspectPlace=place
again,step=P.planResource('a',context)
check('new_private_inspection_option_revises_same_goal',again==purpose and step.verb=='inspect')
context.sources={{sourceId='C:pantry:0',revision='r1',place=place,category='food',quantity=2,
    itemId=13,itemType='Base.Apple',known=true,cookable=false,distance=1}}
again,step=P.planResource('a',context)
check('inspection_facts_recompile_without_fake_completion',again==purpose and step.verb=='acquire'
    and step.itemId==13 and not purpose.completedSteps)
local interpret=C.interpretPlans
C.interpretPlans=function(id,candidates,ctx)
    local value=interpret(id,candidates,ctx)
    value.models[1].selected='inspect:42'
    return value
end
again,step=P.planResource('a',context)
C.interpretPlans=interpret
check('ordinary_selected_alternative_changes_executed_owner',step.verb=='inspect' and step.owner=='SAONeeds')

context=reset() context.category='water' context.inspectPlace=nil
context.sources={{sourceId='C:pantry:0',revision='r1',place=place,category='water',quantity=1,
    itemId=14,itemType='Base.WaterBottle',known=true,distance=1}}
purpose,step=P.planResource('a',context)
check('water_goal_acquires_actual_item_without_cooking',step.verb=='acquire' and step.itemId==14
    and #purpose.steps==1 and step.quantityUnit=='item')
context=reset() context.sources[1].cookable=nil context.inspectPlace=nil
purpose,step=P.planResource('a',context)
ok,reservation=SAO.SourceUse.beginAcquisition('a',__bodies.a,place,'food',{
    purposeId=purpose.id,purposeStepId=step.id,sourceId=step.sourceId,itemId=step.itemId,
    sourceRevision=step.sourceRevision,acceptItem=function(t) return t=='Base.Chicken' end})
SAO.SourceUse.onMovementDone('a',__bodies.a,'arrived')
__carriedItem=__sourceItem __busy=false __observeText=__after
SAO.SourceUse.tick('a',__bodies.a)
receipt=SAO.WorldSources.actionOutcome(reservation.id,'a')
P.consumeSourceResult(receipt)
check('unknown_food_transfer_requires_owned_usable_state',purpose.status=='maintained'
    and purpose.steps[purpose.cursor].conditional==true)
context.sources={} context.carriedReady=1
context.carriedReadyItems={{itemId=12,itemType='Base.Apple'}}
again,step=P.planResource('a',context)
check('same_id_wrong_native_type_never_confirms_food',purpose.status~='completed')
context.carriedReadyItems={{itemId=12,itemType='Base.Chicken'}}
again,step=P.planResource('a',context)
check('native_ready_item_resolves_conditional_work_without_practice',again==purpose and not step
    and purpose.status=='completed' and purpose.steps[2].status=='not-required'
    and not __records.a.proceduralPlanning.practice.Cooking)
context=reset() context.carriedRaw=1 context.carriedRawItems={{itemId=55,itemType='Base.Chicken',cookable=true}}
context.obligationActive=true
purpose,step=P.planResource('a',context)
check('accepted_time_claim_blocks_personal_work_without_job_assignment',purpose.status=='blocked'
    and purpose.blockers[1]=='accepted-work-in-progress' and __records.a.designation==nil)
check('wrong_native_item_cannot_bind_requested_cooking',not P.admitCooking('a',{
    id='wrong-item',itemId=99,requestedPurposeId=purpose.id,requestedPurposeStepId=step.id}))
context=reset()
purpose,step=P.planResource('a',context)
ok,reservation=SAO.SourceUse.beginAcquisition('a',__bodies.a,place,'food',{
    purposeId=purpose.id,purposeStepId=step.id,sourceId=step.sourceId,itemId=step.itemId,
    sourceRevision=step.sourceRevision,acceptItem=function(t) return t=='Base.Chicken' end})
SAO.WorldSources.failAction(reservation.id,'a','native-route-refused')
receipt=SAO.WorldSources.actionOutcome(reservation.id,'a')
check('native_refusal_retains_demand_and_retires_active_admission',P.consumeSourceResult(receipt)==true
    and purpose.status=='interrupted' and purpose.cursor==1 and not purpose.admission
    and purpose.lastAdmission.correlationId==reservation.id)
events=#purpose.events
check('failed_native_resource_receipt_replays_without_repeated_penalty',P.consumeSourceResult(receipt)==true
    and #purpose.events==events and purpose.cursor==1)
context=reset()
purpose,step=P.planResource('a',context)
ok,reservation=SAO.SourceUse.beginAcquisition('a',__bodies.a,place,'food',{
    purposeId=purpose.id,purposeStepId=step.id,sourceId=step.sourceId,itemId=step.itemId,
    sourceRevision=step.sourceRevision,acceptItem=function(t) return t=='Base.Chicken' end})
SAO.SourceUse.onMovementDone('a',__bodies.a,'arrived')
__carriedItem=__sourceItem __busy=false __observeText=__after
SAO.SourceUse.tick('a',__bodies.a)
receipt=SAO.WorldSources.actionOutcome(reservation.id,'a')
P.consumeSourceResult(receipt)
SAO.WorldSources.applySnapshot(SAO.WorldSources.parse(string.gsub(__before,'rev=r1','rev=r3')))
local quantities,revision,access,facts=SAO.WorldSources.beliefSnapshot(place)
__known.a[42]={cx=8,cy=8,sources=quantities,sourceRevision=revision,sourceAccess=access,sourceFacts=facts}
context.sources[1].revision='r3' context.inspectPlace=nil
again,step=P.planResource('a',context)
check('returned_item_new_revision_requires_new_acquisition',again==purpose and step.verb=='acquire'
    and purpose.cursor==1 and step.sourceRevision=='r3' and step.status=='available'
    and #purpose.completedSteps==1 and purpose.completedSteps[1].status=='completed')
-- Resource production remains a separate native authority. The planner sees
-- detached private options and canonical terminal receipts from that owner.
local productionOutcomes={}
SAO.ResourceProduction={privatelyKnown=function(id,option)
    local own=__known[id] and __known[id][42]
    local fact=own and own.sourceFacts[option.sourceId]
    return fact and fact.revision==option.sourceRevision and fact.fingerprint==option.fingerprint or false
end,outcome=function(id,key) return productionOutcomes[id] and productionOutcomes[id][key] end}
context=reset() context.category='water' context.sources={} context.inspectPlace=nil
context.productionOptions={{kind='refill-water',owner='SAO.ResourceProduction',category='water',
    sourceId='F:sink',sourceRevision='water-r1',fingerprint='sink-physical',
    sourceX=8,sourceY=8,sourceZ=0,place=place,itemId=71,itemType='Base.WaterBottle',
    beforeAmount=0,capacity=1,quantityUnit='fluid',known=true}}
check('unobserved_fixture_never_becomes_production_knowledge',#L.assess('a',context).options==0)
__known.a[42].sourceFacts['F:sink']={revision='water-r1',fingerprint='sink-physical'}
profile=L.assess('a',context)
check('known_water_fixture_is_a_material_affordance_not_ready_stock',#profile.options==1
    and profile.options[1].kind=='refill-water' and profile.demand.ownedWater==0
    and profile.dimensions.materialsAndSpace.privateOptions==1)
purpose,step=P.planResource('a',context)
check('water_production_binds_actual_fixture_vessel_and_revision',step.verb=='produce'
    and step.owner=='SAO.ResourceProduction' and step.itemId==71 and step.sourceRevision=='water-r1'
    and step.fingerprint=='sink-physical' and step.token=='resource:filled' and #purpose.steps==1)
local work={id='refill/a/1',actorId='a',kind='refill-water',sourceId='F:sink',
    sourceRevision='water-r1',fingerprint='sink-physical',itemId=72,itemType='Base.WaterBottle',
    requestedPurposeId=purpose.id,requestedPurposeStepId=step.id}
check('different_vessel_cannot_admit_current_refill_step',not P.admitProduction('a',work))
work.itemId=71
check('exact_native_production_admission_retains_private_purpose',P.admitProduction('a',work)
    and work.purposeId==purpose.id and purpose.admission.correlationId==work.id)
local result={id=work.id,actorId='a',kind=work.kind,sourceId=work.sourceId,
    sourceRevision=work.sourceRevision,fingerprint=work.fingerprint,itemId=work.itemId,itemType=work.itemType,
    purposeId=purpose.id,purposeStepId=step.id,token='resource:filled',status='pending',
    beforeAmount=0,afterAmount=.2,nativeGain=.2,held=true,clean=true,nativeCredit=work.id,atHours=49}
productionOutcomes.a={[work.id]=result}
check('pending_native_production_never_retires_admission',not P.consumeProductionResult('a',result)
    and purpose.admission.correlationId==work.id and purpose.cursor==1)
result.status='completed' result.nativeCredit=nil
check('production_queue_without_native_credit_never_completes_plan',not P.consumeProductionResult('a',result)
    and purpose.status~='completed')
result.nativeCredit=work.id result.fingerprint='different-fixture'
check('different_physical_fixture_receipt_never_advances_plan',not P.consumeProductionResult('a',result))
result.fingerprint=work.fingerprint result.nativeGain=0
check('caller_claimed_fill_cannot_replace_canonical_gain',not P.consumeProductionResult('a',{
    id=work.id,purposeId=purpose.id,status='completed',nativeGain=99}) and purpose.cursor==1)
result.nativeGain=.2
check('measured_native_fill_completes_exact_goal',P.consumeProductionResult('a',result)
    and purpose.status=='completed' and __records.a.proceduralPlanning.practice['refill-water'].completed==1)
local refillCompleted=__records.a.proceduralPlanning.practice['refill-water'].completed
check('native_fill_receipt_is_exact_once',P.consumeProductionResult('a',result)
    and __records.a.proceduralPlanning.practice['refill-water'].completed==refillCompleted)
context=reset() context.category='water' context.sources={} context.inspectPlace=nil
context.productionOptions={{kind='refill-water',owner='SAO.ResourceProduction',category='water',
    sourceId='F:sink',sourceRevision='water-r1',fingerprint='sink-physical',
    sourceX=8,sourceY=8,sourceZ=0,place=place,itemId=71,itemType='Base.WaterBottle',beforeAmount=0,capacity=1}}
__known.a[42].sourceFacts['F:sink']={revision='water-r1',fingerprint='sink-physical'}
purpose,step=P.planResource('a',context)
work={id='refill/a/2',actorId='a',kind='refill-water',sourceId='F:sink',sourceRevision='water-r1',
    fingerprint='sink-physical',itemId=71,itemType='Base.WaterBottle',purposeId=purpose.id,purposeStepId=step.id}
P.admitProduction('a',work)
result={id=work.id,actorId='a',kind=work.kind,sourceId=work.sourceId,sourceRevision=work.sourceRevision,
    fingerprint=work.fingerprint,itemId=work.itemId,itemType=work.itemType,purposeId=purpose.id,
    purposeStepId=step.id,token='resource:filled',status='interrupted',detail='danger',
    beforeAmount=0,afterAmount=.1,nativeGain=.1,held=true,clean=true,atHours=49}
productionOutcomes.a={[work.id]=result}
local interrupted=P.consumeProductionResult('a',result)
context.carriedWater=1
P.planResource('a',context)
check('interrupted_partial_fill_supplies_stock_without_completed_work_credit',interrupted
    and purpose.resolution=='native-owned-usable-stock'
    and __records.a.proceduralPlanning.practice['refill-water'].completed==0)
context.carriedWater=0 context.atHours=50
local other={kind='refill-water',owner='SAO.ResourceProduction',category='water',
    sourceId='F:other',sourceRevision='water-r1',fingerprint='other-physical',
    sourceX=9,sourceY=8,sourceZ=0,place=place,itemId=71,itemType='Base.WaterBottle',beforeAmount=0,capacity=1}
context.productionOptions[2]=other
__known.a[42].sourceFacts['F:other']={revision='water-r1',fingerprint='other-physical'}
purpose,step=P.planResource('a',context)
local failedSource=step.sourceId
local function failFill()
    local attempt={id='refill/failure/'..step.sourceId,actorId='a',kind='refill-water',
        sourceId=step.sourceId,sourceRevision=step.sourceRevision,fingerprint=step.fingerprint,
        itemId=step.itemId,itemType=step.itemType,purposeId=purpose.id,purposeStepId=step.id}
    P.admitProduction('a',attempt)
    local failure={id=attempt.id,actorId='a',kind='refill-water',sourceId=step.sourceId,
        sourceRevision=step.sourceRevision,fingerprint=step.fingerprint,itemId=step.itemId,itemType=step.itemType,
        purposeId=purpose.id,purposeStepId=step.id,token='resource:filled',status='failed',detail='native-route-refused',atHours=50}
    productionOutcomes.a[attempt.id]=failure
    return P.consumeProductionResult('a',failure)
end
failFill()
purpose,step=P.planResource('a',context)
check('failed_fixture_yields_to_another_privately_known_route',step and step.sourceId~=failedSource
    and purpose.routeFailures[1].retryAt>50)
failFill()
purpose,step=P.planResource('a',context)
check('failed_routes_wait_without_blindly_repeating_work',not step and purpose.status=='blocked'
    and purpose.blockers[1]=='known-route-retry-delayed' and #purpose.routeFailures==2)
context.inspectPlace=place
purpose,step=P.planResource('a',context)
check('failed_production_can_reconsider_private_inspection',step and step.verb=='inspect')
context.inspectPlace=nil context.atHours=50.1
purpose,step=P.planResource('a',context)
check('bounded_route_delay_allows_a_later_native_attempt',step and step.owner=='SAO.ResourceProduction'
    and not purpose.admission)
local refused=step.id
local deferred=P.deferResourceRoute('a',purpose.id,refused,'native-queue-refused',50.1)
purpose,step=P.planResource('a',context)
check('unadmitted_native_refusal_is_feedback_without_work_credit',deferred
    and (not step or step.id~=refused) and not purpose.admission
    and __records.a.proceduralPlanning.practice['refill-water'].completed==0)
context=reset() context.sources={} context.inspectPlace=nil context.carriedRaw=1
context.carriedRawItems={{itemId=55,itemType='Base.Chicken',cookable=true}}
purpose,step=P.planResource('a',context)
local cookingFailure={id='failed-cooking',actorId='a',purposeId=purpose.id,purposeStepId=step.id,
    status='failed',detail='native-appliance-refused',atHours=48}
P.admitCooking('a',{id=cookingFailure.id,itemId=55,requestedPurposeId=purpose.id,requestedPurposeStepId=step.id})
__records.a.cookingOutcomes={cookingFailure}
P.consumeCookingResult('a',cookingFailure)
purpose,step=P.planResource('a',context)
check('failed_cooking_retains_demand_without_immediate_retry',not step and purpose.status=='blocked'
    and purpose.blockers[1]=='known-route-retry-delayed')
context.sources={{sourceId='C:pantry:0',revision='r1',place=place,category='food',quantity=1,
    itemId=13,itemType='Base.Apple',known=true,distance=1}}
purpose,step=P.planResource('a',context)
check('failed_cooking_can_choose_another_actual_food_route',step and step.verb=='acquire' and step.itemId==13)
context=reset() context.category='water' context.sources={} context.productionOptions={}
for index=1,16 do
    local key='F:fixture-'..tostring(index)
    __known.a[42].sourceFacts[key]={revision='r1',fingerprint=key}
    context.productionOptions[index]={kind='refill-water',owner='SAO.ResourceProduction',category='water',
        sourceId=key,sourceRevision='r1',fingerprint=key,sourceX=8,sourceY=8,sourceZ=0,
        place=place,itemId=71,itemType='Base.WaterBottle',beforeAmount=0,capacity=1}
end
purpose,step=P.planResource('a',context)
check('rich_option_frame_keeps_both_models_and_private_inspection',purpose.interpretations
    and #purpose.interpretations.models==2 and #purpose.alternatives==17
    and purpose.interpretations.models[2].selected=='inspect:42')
context=reset()
__records.a.resourceProductionWork={id='actual-native-refill-owner'}
local acquisition,acquireWhy=SAO.SourceUse.beginAcquisition('a',__bodies.a,place,'food',{})
check('direct_acquisition_cannot_replace_native_resource_owner',not acquisition
    and acquireWhy=='native-resource-owner-busy' and not __records.a.worldSourceReservation)
local transfer,transferWhy=SAO.SourceUse.beginTransfer('a',__bodies.a,'water','standing',
    __sourceItem,__sourceContainer,'acquire',{})
check('direct_collection_cannot_replace_native_resource_owner',not transfer
    and transferWhy=='native-resource-owner-busy' and not __records.a.worldSourceReservation)
__laborResults=table.concat(checks,'\n')
'''

CONTROLS = [
    ('source', 'return rec and rec.resourceProductionWork ~= nil', 'return false',
     'direct_acquisition_cannot_replace_native_resource_owner'),
    ('planner', 'if #candidates > 16 then', 'if false then',
     'rich_option_frame_keeps_both_models_and_private_inspection'),
    ('planner', 'if failure and finite(failure.retryAt) and at < failure.retryAt then',
     'if false then', 'failed_routes_wait_without_blindly_repeating_work'),
    ('planner', 'if held and retryReady then', 'if held then',
     'failed_cooking_retains_demand_without_immediate_retry'),
    ('planner', 'or step.itemId ~= work.itemId or step.itemType ~= work.itemType',
     'or false', 'different_vessel_cannot_admit_current_refill_step'),
    ('planner', 'not (canonical.nativeCredit == canonical.id) or canonical.held ~= true',
     'canonical.held ~= true', 'production_queue_without_native_credit_never_completes_plan'),
    ('planner', 'or canonical.fingerprint ~= step.fingerprint or canonical.itemId ~= step.itemId',
     'or canonical.itemId ~= step.itemId', 'different_physical_fixture_receipt_never_advances_plan'),
    ('labor', 'if private and category == "water" and candidate.category == category',
     'if category == "water" and candidate.category == category', 'unobserved_fixture_never_becomes_production_knowledge'),
    ('planner', 'if current and purpose.admission and purpose.admission.stepId == current.id then',
     'if current and purpose.admission and purpose.admission.stepId == current.id and purpose.status == "maintained" then',
     'interrupted_native_admission_precedes_stock_resolution'),
    ('planner', 'if suppliedGoal() then return purpose, nil end\n    local candidates',
     'if false then return purpose, nil end\n    local candidates', 'new_owned_food_resolves_blocked_goal_without_work_credit'),
    ('labor', '(SAO.Census.skillOf(id, "Cooking") or -1) >= 0',
     '(SAO.Census.skillOf(id, "Cooking") or -1) > 0', 'zero_native_skill_allows_basic_attempt'),
    ('labor', 'and privateSource(id, source)', 'and true', 'unknown_actor_source_is_not_an_option'),
    ('planner', 'if held and retryReady then', 'if false then', 'completed_acquisition_and_exact_item_survive_interruption'),
    ('planner', 'tostring(option.sourceRevision)\n                    .. ":" .. tostring(option.itemId)',
     '""\n                    .. ":" .. tostring(option.itemId)', 'returned_item_new_revision_requires_new_acquisition'),
    ('planner', 'authority ~= RESOURCE_RESULT', 'false', 'unverified_resource_result_never_grants_credit'),
    ('planner', 'canonical.nativeCredit ~= canonical.id', 'false', 'native_preparation_credit_cannot_be_fabricated'),
    ('planner', 'admission.correlationId ~= canonical.id', 'false', 'superseded_preparation_never_completes_replacement'),
    ('cognition', 'copy(s.models[name]), copy(candidates), copy(context or {}))',
     'copy(s.models[name]), candidates, copy(context or {}))', 'independent_models_receive_same_feasible_candidates'),
]

def main():
    missing = [str(path) for path in FILES.values() if not path.is_file()]
    if missing:
        print('FAULT Border 216: repository inputs missing: ' + ', '.join(missing)); return 1
    if not all(path.is_file() for path in (GAME/'projectzomboid.jar', GAME/'stdlib.lua', JDK/'java.exe', JDK/'javac.exe')):
        print('Border 216 SKIPPED: installed game VM or JDK absent'); return 0
    texts = {name: path.read_text(encoding='utf-8-sig') for name,path in FILES.items()}
    expected = set(re.findall(r"check\('([a-z0-9_]+)'", CASES))
    try:
        with tempfile.TemporaryDirectory(prefix='sao-labor-planning-') as directory:
            work = Path(directory)
            shutil.copy2(GAME/'stdlib.lua', work/'stdlib.lua')
            subprocess.run([str(JDK/'javac.exe'), '-cp', str(GAME/'projectzomboid.jar'), '-d', str(work),
                            str(ROOT/'tools/luacheck/LuaRun.java')], check=True, capture_output=True, text=True)
            def run(changed=None):
                code = dict(texts); code.update(changed or {})
                chunks = {'prelude': fixture.ACTION_PRELUDE, 'setup': SETUP + '\n__before=' + json.dumps(BEFORE)
                          + '\n__after=' + json.dumps(AFTER), **code,
                          'reload': 'function __reloadPlanner()\n' + code['planner'] + '\nend', 'cases': CASES}
                paths=[]
                for name,text in chunks.items():
                    path = work/(name+'.lua'); path.write_text(text, encoding='utf-8'); paths.append(path)
                done = subprocess.run([str(JDK/'java.exe'), '-Djava.awt.headless=true', '-cp',
                    str(work)+os.pathsep+str(GAME/'projectzomboid.jar'), 'LuaRun', *map(str,paths), '--', '__laborResults'],
                    cwd=work, capture_output=True, text=True, timeout=60)
                checks = dict(re.findall(r'^([a-z0-9_]+)=(true|false)$',done.stdout.replace('VALUE ',''),re.M))
                if done.returncode or set(checks) != expected:
                    raise RuntimeError(done.stdout[-6000:]+done.stderr[-1000:])
                return checks
            checks=run()
            failed=[name for name,value in checks.items() if value!='true']
            if failed: raise RuntimeError('failed cases: '+', '.join(failed))
            for name,before,after,target in CONTROLS:
                if texts[name].count(before)!=1: raise RuntimeError(target+': mutation anchor differs')
                mutant=run({name:texts[name].replace(before,after,1)})
                if mutant[target]!='false': raise RuntimeError(target+': mutation survived')
            print(f'Border 216 PASS: {len(checks)} production Kahlua cases; {len(CONTROLS)} named controls')
            return 0
    except Exception as error:
        print('FAULT Border 216:',error); return 1

if __name__=='__main__': raise SystemExit(main())
