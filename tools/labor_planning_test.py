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
import argparse
import hashlib

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
ROUTES = fixture.snapshot(1, 1, 'routes', [
    {'id': 'C:pantry:0', 'fp': 'pantry', 'rev': 'r1', 'kind': 'container',
     'x': 8, 'y': 8, 'building': 42, 'quantities': {'food': 1},
     'items': [{'id': 13, 'type': 'Base.Apple', 'amount': 1, 'cats': 'food'}]},
    {'id': 'C:remote:0', 'fp': 'remote', 'rev': 'r1', 'kind': 'container',
     'x': 56, 'y': 8, 'building': 42, 'quantities': {'food': 1},
     'items': [{'id': 15, 'type': 'Base.Apple', 'amount': 1, 'cats': 'food'}]},
])
MANY = fixture.snapshot(1, 1, 'many', [
    {'id':f'C:choice-{index:02d}:0','fp':f'choice-{index:02d}','rev':'r1','kind':'container',
     'x':8,'y':8,'building':42,'quantities':{'food':1},
     'items':[{'id':100+index,'type':'Base.Apple','amount':1,'cats':'food'}]}
    for index in range(1,13)
])

SETUP = r'''
require=function() end
ModData.get=function(key) return __stores[key] end
SAO.Census={skillOf=function() return 0 end}
SAO.Lessons={has=function(_,work) return work=='quartermaster' end}
SAO.Standing.mayEngageZombie=function() return false end
SAO.Material={storeForPerson=function() return {items={actual=1}} end}
SandboxVars={SurvivorAwareness={Material=true}}
__hours=48
SAO.History.countyHours=function() return __hours end
SAO.Perception.believedThreatCount=function(id,tick,radius,x,y)
    local n=0
    for _, threat in ipairs(__threats[id] or {}) do
        if threat.at<=tick and tick-threat.at<=60
            and (threat.x-x)^2+(threat.y-y)^2<=radius^2 then n=n+1 end
    end
    return n
end
SAO.Perception.nearestBelievedThreat=function(id,tick,x,y)
    local best
    for _, threat in ipairs(__threats[id] or {}) do
        if threat.at<=tick and tick-threat.at<=60 then
            local d=math.sqrt((threat.x-x)^2+(threat.y-y)^2)
            if not best or d<best.dist then
                best={dist=d,at=threat.at,source=threat.source,fromPerson=threat.fromPerson,form=threat.form}
            end
        end
    end
    return best
end
SAO.Perception.knownAidRequests=function(id) return __requests[id] or {},'available' end
SAO.Organization={activeCommitments=function(id) return __obligations[id] or {} end}
-- Controlled canonical Cooking reader; production Cognition owns qualification
-- and its private native-result capability. Heating/action probes are separate.
SAO.Cooking={outcome=function(id,sequence)
    local rec=__records[id]
    for _,receipt in ipairs(rec and rec.cookingOutcomes or {}) do
        if receipt.actorId==id and receipt.sequence==sequence then return receipt end
    end
end}
SAO.Disposition={wouldGiveToStranger=function(id) return __willing[id]==true end}
SAOJavaBridge.carriedWorldTransferItem=function()
    return 'T|operation=acquire|source=C:pantry:0|id=12|type=Base.Chicken|uses=1|amount=1|fluid=|poison=0|rotten=0|cats=food'
end
'''

CASES = r'''
local checks={}
local function check(name,value) checks[#checks+1]=name..'='..tostring(value==true) end
local P,L,C,M=SAO.ProceduralPlanning,SAO.Labor,SAO.Cognition,SAO.CognitiveModels
local place={id=42,cx=8,cy=8,minX=8,minY=8,maxX=16,maxY=16}
local function inspectPlace()
    return {id=42,cx=8,cy=8,minX=8,minY=8,maxX=16,maxY=16,sourceId='C:pantry:0'}
end
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
    __threats={a={},b={}} __requests={a={},b={}} __obligations={a={},b={}} __willing={}
    return {category='food',pressure=.35,atHours=48,carriedReady=0,carriedRaw=0,
        carriedWater=0,carriedItems=0,needs={fatigue=.25},health=.85,
        contacts={'b','b','a'},commitments={{id='accepted/1',owner='Posture',status='paused'}},
        sources={{sourceId='C:pantry:0',revision='r1',place=place,category='food',
            quantity=2,quantityUnit='item',itemType='Base.Chicken',itemId=12,
            known=true,distance=8,cookable=true}},
        inspectPlace=inspectPlace(),
        inspectFingerprint='pantry',inspectX=8,inspectY=8,inspectZ=0}
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
    and purpose.interpretations.models[2].selected=='inspect:10:C:pantry:0:pantry')
local original=M.interpretPlans
local seen={}
M.interpretPlans=function(model,state,candidates,ctx)
    if #candidates>1 then seen[#seen+1]=candidates[1].evidence end
    local answer=original(model,state,candidates,ctx)
    state.tainted=true candidates[1].evidence=0
    return answer
end
P.planResource('a',context)
M.interpretPlans=original
check('independent_models_receive_same_feasible_candidates',#seen==2 and seen[1]==seen[2]
    and __records.a.cognition==nil)
check('cold_resource_interpretation_does_not_create_learning',__records.a.cognition==nil
    and purpose.interpretations.selectedModelId=='ordinary')
check('current_capability_cannot_backfill_historical_plan',C.interpretPlans('a',{
    {id='past',evidence=1,continuity=0,novelty=0,informationGain=0,blockers=0}},
    {pressure=.35,atHours=47})==nil and __records.a.cognition==nil)
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
if snapshot.purposes[1].interpretations then snapshot.purposes[1].interpretations.models[1].selected='forged' end
check('resource_observation_is_bounded_detached_data',purpose.demand.pressure==.35
    and purpose.steps[1].itemId==12 and purpose.interpretations and purpose.interpretations.models[1].selected~='forged'
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
context.inspectPlace=inspectPlace()
again,step=P.planResource('a',context)
check('new_private_inspection_option_revises_same_goal',again==purpose and step.verb=='inspect')
context.sources={{sourceId='C:pantry:0',revision='r1',place=place,category='food',quantity=2,
    itemId=13,itemType='Base.Apple',known=true,cookable=false,distance=1}}
again,step=P.planResource('a',context)
check('inspection_facts_recompile_without_fake_completion',again==purpose and step.verb=='acquire'
    and step.itemId==13 and not purpose.completedSteps)
C.configure(1,12,3)
again,step=P.planResource('a',context)
check('configured_associative_selection_changes_executed_owner',step.verb=='inspect'
    and step.owner=='SAO.WorldSources' and purpose.interpretations.selectedModelId=='associative'
    and purpose.selectedStrategy==purpose.interpretations.selected)
C.configure(0,12,3)
again,step=P.planResource('a',context)
check('configured_ordinary_selection_restores_exact_acquisition',step.verb=='acquire'
    and step.itemId==13 and purpose.interpretations.selectedModelId=='ordinary')

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
context.inspectPlace=inspectPlace() context.inspectFingerprint='pantry'
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
    and purpose.interpretations.models[2].selected=='inspect:10:C:pantry:0:pantry')
context.tick=100 context.position={x=0,y=8,z=0}
context.inspectX=8 context.inspectY=8 context.inspectZ=0
__records.a.homeX=0 __records.a.homeY=8 __records.a.homeZ=0
context.productionOptions[9].sourceX=56
__threats.a={{x=8,y=8,at=100,source='observed'}}
__records.a.proceduralPlanning=nil __records.a.cognition=nil
purpose,step=P.planResource('a',context)
check('candidate_bound_retains_route_with_private_risk_advantage',step.sourceId=='F:fixture-9'
    and purpose.interpretations and #purpose.interpretations.models==2)
context=reset()
__records.a.resourceProductionWork={id='actual-native-refill-owner'}
local acquisition,acquireWhy=SAO.SourceUse.beginAcquisition('a',__bodies.a,place,'food',{})
check('direct_acquisition_cannot_replace_native_resource_owner',not acquisition
    and acquireWhy=='native-resource-owner-busy' and not __records.a.worldSourceReservation)
local transfer,transferWhy=SAO.SourceUse.beginTransfer('a',__bodies.a,'water','standing',
    __sourceItem,__sourceContainer,'acquire',{})
check('direct_collection_cannot_replace_native_resource_owner',not transfer
    and transferWhy=='native-resource-owner-busy' and not __records.a.worldSourceReservation)

local function routes()
    local ctx=reset()
    SAO.WorldSources.applySnapshot(SAO.WorldSources.parse(__routes))
    local quantities,revision,access,facts=SAO.WorldSources.beliefSnapshot(place)
    __known.a[42]={cx=8,cy=8,sources=quantities,sourceRevision=revision,sourceAccess=access,sourceFacts=facts}
    ctx.sources={
        {sourceId='C:pantry:0',revision='r1',place=place,category='food',quantity=1,
            itemId=13,itemType='Base.Apple',known=true,distance=8},
        {sourceId='C:remote:0',revision='r1',place=place,category='food',quantity=1,
            itemId=15,itemType='Base.Apple',known=true,distance=56}}
    ctx.tick=100 ctx.position={x=0,y=8,z=0} ctx.inspectPlace=nil
    __records.a.homeX=0 __records.a.homeY=8 __records.a.homeZ=0
    return ctx
end
context=routes()
local calm=L.assess('a',context)
local baseline=M.planScore('ordinary',calm.options[1],context.pressure)
__threats.a={{x=8,y=8,at=100,source='observed',fromPerson=true,form='afflicted'}}
profile=L.assess('a',context)
purpose,step=P.planResource('a',context)
check('private_destination_danger_changes_route_ranking',step.sourceId=='C:remote:0'
    and purpose.interpretations.models[1].selected==purpose.selectedStrategy
    and purpose.interpretations.models[2].selected==purpose.selectedStrategy)
local risky
for _,option in ipairs(profile.options) do if option.sourceId=='C:pantry:0' then risky=option end end
check('formed_person_evidence_is_retained_without_route_certainty',risky.appraisal.danger.nearest.fromPerson
    and risky.appraisal.danger.nearest.form=='afflicted'
    and risky.appraisal.danger.status=='partial' and risky.uncertainty:find('whole route',1,true)~=nil)
__threats.a={} __threats.b={{x=8,y=8,at=100,source='observed'}}
profile=L.assess('a',context)
local actorPrivate=true
for _,option in ipairs(profile.options) do
    if option.appraisal.danger.status~='unknown' or option.appraisal.danger.ordinal~=0 then actorPrivate=false end
end
check('another_actor_threats_do_not_enter_private_appraisal',actorPrivate)
check('no_remembered_threat_preserves_unknown_safety',profile.options[1].appraisal.danger.believedCount==0
    and profile.options[1].uncertainty:find('does not establish safety',1,true)~=nil)
context.contacts={'b','c','d'} context.commitments={{id='unaccepted',actorId='a',status='accepted'}}
local contactsOnly=L.assess('a',context)
check('contacts_and_unproved_commitments_do_not_supply_support',contactsOnly.options[1].appraisal.requestValue==0
    and #contactsOnly.options[1].appraisal.social.responsibilities==0
    and M.planScore('ordinary',contactsOnly.options[1],context.pressure)==baseline)
__requests.b={{groupId='house',originId='b',category='food',source='requested',requestedAt=47,acquiredAt=47}}
__willing.a=true
check('another_actor_requests_do_not_enter_private_appraisal',#L.assess('a',context).options[1].appraisal.social.requests==0)
__requests.a=__requests.b
profile=L.assess('a',context)
check('acquired_request_informs_both_models_without_stock_reward',profile.options[1].appraisal.requestValue>0
    and M.planScore('ordinary',profile.options[1],context.pressure)>baseline
    and M.planScore('associative',profile.options[1],context.pressure)>M.planScore('associative',contactsOnly.options[1],context.pressure)
    and profile.options[1].appraisal.social.uncertainty:find('unsatisfied',1,true)~=nil)
__willing.a=false
profile=L.assess('a',context)
check('request_willingness_stays_with_disposition',profile.options[1].appraisal.requestValue==0
    and profile.options[1].appraisal.social.requests[1].willing==false)
__willing.a=true __requests.a[1].originId=nil
profile=L.assess('a',context)
check('unidentified_request_origin_does_not_invent_disposition_target',profile.options[1].appraisal.requestValue==0
    and profile.options[1].appraisal.social.requests[1].willing==nil)
__requests.a[1].originId='a'
check('own_food_request_does_not_invent_another_person_need',L.assess('a',context).options[1].appraisal.requestValue==0)
__requests.a={}
__obligations.a={{id='accepted/b',actorId='b',acceptedAt=47,status='accepted',
    scope={action='deliver-material',category='food'},beneficiaryId='c'}}
check('foreign_accepted_actor_cannot_supply_responsibility',#L.assess('a',context).options[1].appraisal.social.responsibilities==0)
__obligations.a[1].actorId='a' __obligations.a[1].acceptedAt=49
check('future_acceptance_cannot_supply_responsibility',#L.assess('a',context).options[1].appraisal.social.responsibilities==0)
__obligations.a[1].acceptedAt=47
profile=L.assess('a',context)
check('actual_assent_retains_unsatisfied_responsibility',profile.options[1].appraisal.requestValue==1
    and profile.options[1].appraisal.social.responsibilities[1].acceptedAt==47)
purpose,step=P.planResource('a',context)
context.carriedReady=1
purpose,step=P.planResource('a',context)
check('personal_stock_completion_does_not_satisfy_other_need',purpose.status=='completed' and not step
    and #purpose.labor.groupValues.responsibilities==1
    and purpose.appraisal.social.uncertainty:find('unsatisfied',1,true)~=nil)
context=routes() context.position.x=32
__records.a.homeX=56
purpose,step=P.planResource('a',context)
check('own_home_return_cost_changes_route_ranking',step.sourceId=='C:remote:0'
    and purpose.appraisal.travel.returnTiles==0 and purpose.appraisal.travel.outwardTiles==24)
__records.a.proceduralPlanning=nil
local interpretFallback=C.interpretPlans C.interpretPlans=nil
purpose,step=P.planResource('a',context)
C.interpretPlans=interpretFallback
check('cold_model_fallback_keeps_private_return_cost',step.sourceId=='C:remote:0' and not purpose.interpretations)
context.tick=nil context.position=nil __records.a.homeX=nil
profile=L.assess('a',context)
check('legacy_context_keeps_missing_position_and_danger_unknown',profile.options[1].appraisal.danger.status=='unknown'
    and profile.options[1].appraisal.travel.outwardTiles==nil and profile.options[1].appraisal.travel.returnTiles==nil)
local foreign=profile.options[1] foreign.appraisal.actorId='b'
check('model_refuses_foreign_detached_appraisal',M.interpretPlans('ordinary',M.newState('ordinary'),{foreign},
    {actorId='a',pressure=.35})==nil)

-- Current private alternatives stay fixed while observed outcomes change the
-- actual exact item/source selected by production planning. The experience
-- admission is production; controlled source receipts above own native credit.
local function learnedRoutes()
    local ctx=routes();C.configure(0,12,3)
    ctx.position.x=32;__records.a.homeX=32
    ctx.sources[1].distance=24;ctx.sources[2].distance=24
    return ctx
end
local function acquireEvidence(actor,serial,source,status)
    return C.experience(actor,{id='shared/'..actor..'/'..serial,actorId=actor,observerId=actor,
        kind='acquire',category='food',perspective='performed',status=status,
        sourceId=source,itemType='Base.Apple',worldHours=48})
end
context=learnedRoutes();purpose,step=P.planResource('a',context)
check('equal_known_routes_start_with_exact_pantry_item',step.itemId==13 and step.sourceId=='C:pantry:0')
check('measured_remote_acquisition_enters_personal_learning',acquireEvidence('a',1,'C:remote:0','completed'))
purpose,step=P.planResource('a',context)
check('shared_source_prediction_changes_actual_exact_item',step.verb=='acquire'
    and step.itemId==15 and step.sourceId=='C:remote:0')
local selectedPrediction=purpose.interpretations.models[1].ranked[1].predictions[1]
check('selected_resource_prediction_retains_exact_basis',selectedPrediction and selectedPrediction.kind=='acquire'
    and selectedPrediction.sourceId=='C:remote:0' and selectedPrediction.itemType=='Base.Apple'
    and selectedPrediction.probability>.5 and selectedPrediction.evidenceIds[1]=='shared/a/1')
local detachedPrediction=P.snapshot('a').purposes[1].interpretations.models[1].ranked[1].predictions[1]
check('resource_snapshot_preserves_shared_prediction_fields',detachedPrediction and detachedPrediction.kind=='acquire'
    and detachedPrediction.sourceId=='C:remote:0' and detachedPrediction.probability>.5
    and detachedPrediction.evidenceIds[1]=='shared/a/1')
if detachedPrediction and detachedPrediction.evidenceIds then
    detachedPrediction.evidenceIds[1]='foreign';detachedPrediction.probability=0
end
check('resource_snapshot_prediction_is_detached',selectedPrediction and selectedPrediction.evidenceIds[1]=='shared/a/1'
    and selectedPrediction.probability>.5)
for i=2,8 do assert(acquireEvidence('a',i,'C:remote:0','no-effect')) end
purpose,step=P.planResource('a',context)
check('unmeasured_acquire_no_effect_remains_censored',step.itemId==15 and step.sourceId=='C:remote:0'
    and __records.a.cognition.models.ordinary.revision==1
    and __records.a.cognition.models.associative.revision==1)
context=learnedRoutes();assert(acquireEvidence('b',1,'C:remote:0','completed'))
purpose,step=P.planResource('a',context)
check('another_person_source_learning_cannot_change_actual_item',step.itemId==13
    and step.sourceId=='C:pantry:0' and __records.a.cognition==nil)

context=reset();C.configure(0,12,3);context.sources={};context.inspectPlace=nil
context.carriedRaw=2;context.carriedRawItems={{itemId=55,itemType='Base.Chicken',cookable=true},
    {itemId=56,itemType='Base.FishFillet',cookable=true}}
purpose,step=P.planResource('a',context)
check('cold_preparation_uses_available_exact_item',step.acquiredItemId==55 and step.owner=='Cooking')
local genericAccepted,genericReason=C.experience('a',{id='cooking/a/1',actorId='a',observerId='a',kind='preparation',category='food',
    perspective='performed',status='completed',sourceId='oven:previous',itemType='Base.FishFillet',
    itemId=900,worldHours=48,occurredAtHours=47,beforeCookingTime=0,afterCookingTime=20,heatObserved=true})
purpose,step=P.planResource('a',context)
check('generic_preparation_cannot_teach_resource_choice',not genericAccepted
    and genericReason=='behavior-owner-required' and __records.a.cognition==nil
    and step.acquiredItemId==55 and step.owner=='Cooking')
-- Isolate each owner refusal from deliberately restored guard defects.
__records.a.cognition=nil
local prepared={id='cooking/a/1',sequence=1,actorId='a',status='completed',
    detail='native-food-cooked-and-retrieved',nativeCredit='cooking/a/1',
    sourceId='oven:previous',itemType='Base.FishFillet',itemId=900,
    startedAt=46,atHours=47,retrieved=true,heatObserved=true,
    beforeCookingTime=0,afterCookingTime=20}
local unownedAccepted,unownedReason=C.preparationOutcome('a',prepared)
check('unowned_preparation_cannot_teach_resource_choice',not unownedAccepted
    and unownedReason=='preparation-owner-unavailable' and __records.a.cognition==nil)
__records.a.cognition=nil
__records.a.cookingOutcomes={prepared}
local changed={};for key,value in pairs(prepared) do changed[key]=value end
changed.afterCookingTime=21
check('changed_preparation_receipt_cannot_teach_resource_choice',not C.preparationOutcome('a',changed)
    and __records.a.cognition==nil)
__records.a.cognition=nil
check('foreign_preparation_receipt_cannot_teach_resource_choice',not C.preparationOutcome('b',prepared)
    and __records.b.cognition==nil)
local preparedAccepted=C.preparationOutcome('a',prepared)
check('canonical_preparation_teaches_resource_choice',preparedAccepted==true
    and __records.a.cognition.experiences[1].id==prepared.id
    and __records.a.cognition.experiences[1].worldHours==48
    and __records.a.cognition.experiences[1].occurredAtHours==47)
local preparedCount=#__records.a.cognition.experiences
check('canonical_preparation_resource_replay_is_exact_once',C.preparationOutcome('a',prepared)==true
    and #__records.a.cognition.experiences==preparedCount)
context.carriedRawItems={{itemId=155,itemType='Base.Chicken',cookable=true},
    {itemId=156,itemType='Base.FishFillet',cookable=true}}
purpose,step=P.planResource('a',context)
check('preparation_experience_transfers_to_new_exact_owned_item',step.acquiredItemId==156
    and step.itemType=='Base.FishFillet' and step.owner=='Cooking'
    and purpose.interpretations.models[1].ranked[1].predictions[1]
    and purpose.interpretations.models[1].ranked[1].predictions[1].kind=='prepare')

local function manyRoutes()
    local ctx=reset();ctx.inspectPlace=nil;ctx.sources={}
    SAO.WorldSources.applySnapshot(SAO.WorldSources.parse(__many))
    local q,r,a,f=SAO.WorldSources.beliefSnapshot(place)
    __known.a[42]={cx=8,cy=8,sources=q,sourceRevision=r,sourceAccess=a,sourceFacts=f}
    for i=1,12 do
        local key='C:choice-'..(i<10 and '0' or '')..tostring(i)..':0'
        ctx.sources[i]={sourceId=key,revision='r1',place=place,category='food',quantity=1,
            itemId=100+i,itemType='Base.Apple',known=true,distance=1}
    end
    return ctx
end
context=manyRoutes();purpose,step=P.planResource('a',context)
for i=1,8 do
    if step then P.deferResourceRoute('a',purpose.id,step.id,'native-queue-refused',48) end
    purpose,step=P.planResource('a',context)
end
check('retry_filter_can_select_ninth_private_source',step and step.itemId==109
    and step.sourceId=='C:choice-09:0' and #purpose.routeFailures==8)
context=manyRoutes();local allSources=context.sources;context.sources={allSources[9]}
purpose,step=P.planResource('a',context);context.sources=allSources
purpose,step=P.planResource('a',context)
check('existing_ninth_strategy_remains_available_to_shared_selection',step and step.itemId==109
    and purpose.interpretations.selected==purpose.selectedStrategy)

context=reset();context.sources={};context.inspectPlace=nil;context.carriedRaw=2
local longType='Base.'..string.rep('x',156)
context.carriedRawItems={{itemId=55,itemType=longType,cookable=true},
    {itemId=56,itemType='Base.Chicken',cookable=true}}
local planned,longPurpose,longStep=pcall(P.planResource,'a',context)
check('unmodelled_long_identity_keeps_native_planning_available',planned and longPurpose and longStep
    and longStep.owner=='Cooking' and longStep.acquiredItemId==55 and longStep.itemType==longType)

context=reset() context.sources={}
context.inspectPlace.sourceId='C:pantry:0' context.inspectFingerprint='pantry'
context.inspectX=8 context.inspectY=8 context.inspectZ=0
purpose,step=P.planResource('a',context)
local inspection={id='inspection/a/1',actorId='a',purposeId=purpose.id,purposeStepId=step.id,
    sourceId=step.sourceId,fingerprint=step.fingerprint,sourceX=8,sourceY=8,sourceZ=0,status='admitted',atHours=48}
local admitted
SAO.WorldSources.inspectionAdmission=function(id,key)
    if admitted and id==admitted.actorId and key==admitted.id then return admitted end
end
check('fabricated_inspection_admission_never_pins_purpose',not P.admitInspection('a',inspection) and not purpose.admission)
admitted=inspection
check('inspection_admission_uses_exact_source_owner',step.owner=='SAO.WorldSources' and step.sourceId=='C:pantry:0'
    and P.admitInspection('a',inspection))
local canonical=inspection
SAO.WorldSources.inspectionOutcome=function(id,key) if id==canonical.actorId and key==canonical.id then return canonical end end
canonical.status='completed' canonical.nativeInspected=true canonical.privateLearned=false
check('native_inspection_without_private_learning_never_advances',not P.consumeInspectionResult('a',canonical)
    and purpose.cursor==1)
canonical.privateLearned=true canonical.sourceX=9
check('foreign_inspection_coordinates_never_advance',not P.consumeInspectionResult('a',canonical) and purpose.cursor==1)
canonical.sourceX=8
check('empty_inspection_completes_work_without_satisfying_need',P.consumeInspectionResult('a',canonical)
    and purpose.steps[1].status=='completed' and purpose.status=='maintained' and purpose.awaitingReassessment
    and not purpose.admission)
check('inspection_replay_does_not_complete_resource_goal',P.consumeInspectionResult('a',canonical)
    and purpose.status=='maintained')
purpose,step=P.planResource('a',context)
check('inspection_reassessment_retains_same_unsatisfied_purpose',purpose and step and step.status=='available'
    and #purpose.completedSteps==1)
inspection.id='inspection/a/2' inspection.status='admitted'
P.admitInspection('a',inspection)
canonical.status='completed' canonical.nativeInspected=true canonical.privateLearned=true
local replaced=purpose.admission.correlationId
purpose.admission.correlationId='inspection/replacement'
check('superseded_inspection_never_advances_replacement',P.consumeInspectionResult('a',canonical)
    and purpose.cursor==1 and purpose.admission.correlationId=='inspection/replacement')

context=reset() context.sources={}
purpose,step=P.planResource('a',context)
local failedHolderId=step.id
inspection={id='inspection/holder-a',actorId='a',purposeId=purpose.id,purposeStepId=step.id,
    sourceId=step.sourceId,fingerprint=step.fingerprint,sourceX=8,sourceY=8,sourceZ=0,status='admitted',atHours=48}
admitted=inspection canonical=inspection
P.admitInspection('a',inspection)
canonical.status='failed' canonical.reason='native-route-refused'
P.consumeInspectionResult('a',canonical)
context.inspectPlace.sourceId='C:pantry:B' context.inspectFingerprint='pantry-b' context.inspectX=9
purpose,step=P.planResource('a',context)
check('failed_holder_does_not_delay_another_in_same_place',step and step.sourceId=='C:pantry:B'
    and step.fingerprint=='pantry-b' and step.id==purpose.selectedStrategy and step.id~=failedHolderId
    and step.place.id==42 and purpose.routeFailures[1].strategy==failedHolderId)
context.inspectPlace.sourceId='C:pantry:0' context.inspectFingerprint='pantry' context.inspectX=8
purpose,step=P.planResource('a',context)
check('failed_exact_holder_retains_its_retry_delay',not step and purpose.status=='blocked'
    and purpose.blockers[1]=='known-route-retry-delayed' and purpose.routeFailures[1].retryAt>48)
context.inspectFingerprint='replacement-pantry'
purpose,step=P.planResource('a',context)
check('changed_holder_fingerprint_has_independent_inspection_identity',step and step.sourceId=='C:pantry:0'
    and step.fingerprint=='replacement-pantry' and step.id~=failedHolderId)
context=reset() context.sources={} context.inspectPlace.sourceId=nil context.inspectFingerprint=nil
purpose,step=P.planResource('a',context)
check('legacy_inspection_candidate_cannot_admit_without_holder_identity',step and step.id=='inspect:42'
    and not P.noteAdmission('a',purpose.id,step.owner,'legacy-unbound',step.id) and not purpose.admission)
__laborResults=table.concat(checks,'\n')
'''

CONTROLS = [
    ('cognition', 'or supplied.kind=="preparation")', ')',
     'generic_preparation_cannot_teach_resource_choice'),
    ('cognition', 'if not canonical or not sameData(canonical,receipt) then return false,"preparation-owner-unavailable" end',
     'if false then return false,"preparation-owner-unavailable" end',
     'unowned_preparation_cannot_teach_resource_choice'),
    ('cognition', 'if not finite(frame.atHours, 0, now) or frame.atHours ~= now then return nil end',
     'if not finite(frame.atHours, 0, now) then return nil end', 'current_capability_cannot_backfill_historical_plan'),
    ('models', 'planCandidate(candidate, context, state == nil and context == nil)',
     'planCandidate(candidate, context)', 'unmodelled_long_identity_keeps_native_planning_available'),
    ('labor', 'for _, option in ipairs(sources) do\n        -- The input is bounded at 64.',
     'for index, option in ipairs(sources) do\n        if index > 8 then break end\n        -- The input is bounded at 64.',
     'retry_filter_can_select_ninth_private_source'),
    ('planner', 'interpretations = dataCopy(purpose.interpretations, 0, 8)',
     'interpretations = dataCopy(purpose.interpretations)', 'resource_snapshot_preserves_shared_prediction_fields'),
    ('planner', 'local selected = views and views.selected',
     'local selected = views and views.models[1].selected', 'configured_associative_selection_changes_executed_owner'),
    ('planner', 'consequences = dataCopy(option.consequences)',
     'consequences = {}', 'shared_source_prediction_changes_actual_exact_item'),
    ('models', 'c.sourceId ~= nil and b.sourceId == c.sourceId',
     'c.sourceId ~= nil', 'shared_source_prediction_changes_actual_exact_item'),
    ('labor', 'out[#out + 1] = { kind = "prepare", category = "food",\n            itemType = option.itemType, value = value }',
     'out[#out + 1] = { kind = "prepare", category = "food", value = value }', 'preparation_experience_transfers_to_new_exact_owned_item'),
    ('labor', 'inspectId = "inspect:" .. #inspect.sourceId .. ":" .. inspect.sourceId .. ":" .. fingerprint',
     'inspectId = "inspect:" .. tostring(inspect.id)', 'failed_holder_does_not_delay_another_in_same_place'),
    ('planner', 'steps[#steps + 1] = { id = option.id, verb = "inspect",',
     'steps[#steps + 1] = { id = "inspect:" .. tostring(option.place.id), verb = "inspect",',
     'failed_holder_does_not_delay_another_in_same_place'),
    ('planner', 'local aScore = SAO.CognitiveModels.planScore("ordinary", a, assessment.demand.pressure)\n            local bScore = SAO.CognitiveModels.planScore("ordinary", b, assessment.demand.pressure)\n            aScore, bScore = scores[a.id] or aScore or -math.huge,\n                scores[b.id] or bScore or -math.huge',
     'local aScore = a.evidence * 0.55 + a.continuity * 0.3 - math.min(1, a.blockers * 0.35)\n            local bScore = b.evidence * 0.55 + b.continuity * 0.3 - math.min(1, b.blockers * 0.35)',
     'candidate_bound_retains_route_with_private_risk_advantage'),
    ('planner', 'local score = SAO.CognitiveModels.planScore("ordinary", candidate, assessment.demand.pressure)',
     'local score = candidate.evidence * 0.55 + candidate.continuity * 0.3 - math.min(1, candidate.blockers * 0.35)',
     'cold_model_fallback_keeps_private_return_cost'),
    ('models', '- risk * 0.45', '- risk * 0', 'private_destination_danger_changes_route_ranking'),
    ('models', '- risk * 0.30', '- risk * 0', 'private_destination_danger_changes_route_ranking'),
    ('models', '- returning * 0.15', '- returning * 0', 'own_home_return_cost_changes_route_ranking'),
    ('labor', 'believedThreatCount(id, context.tick, 12, target.x, target.y)',
     'believedThreatCount("b", context.tick, 12, target.x, target.y)', 'another_actor_threats_do_not_enter_private_appraisal'),
    ('labor', 'knownAidRequests(id, at)', 'knownAidRequests("b", at)', 'another_actor_requests_do_not_enter_private_appraisal'),
    ('labor', 'obligation.actorId == id and finite(obligation.acceptedAt)',
     'finite(obligation.acceptedAt)', 'foreign_accepted_actor_cannot_supply_responsibility'),
    ('models', '+ request * 0.18', '+ request * 0', 'acquired_request_informs_both_models_without_stock_reward'),
    ('models', '+ request * 0.15', '+ request * 0', 'acquired_request_informs_both_models_without_stock_reward'),
    ('planner', 'canonical.nativeInspected ~= true or canonical.privateLearned ~= true',
     'canonical.nativeInspected ~= true', 'native_inspection_without_private_learning_never_advances'),
    ('planner', 'if not canonical or canonical.actorId ~= id or canonical.id ~= receipt.id or canonical.status ~= "admitted"',
     'canonical = receipt\n    if not canonical or canonical.actorId ~= id or canonical.id ~= receipt.id or canonical.status ~= "admitted"',
     'fabricated_inspection_admission_never_pins_purpose'),
    ('planner', 'or step.sourceX ~= canonical.sourceX or step.sourceY ~= canonical.sourceY or step.sourceZ ~= canonical.sourceZ then return false end',
     'then return false end', 'foreign_inspection_coordinates_never_advance'),
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
    ('cognition', 'own, copy(offered), detached(frame))',
     'own, offered, detached(frame))', 'independent_models_receive_same_feasible_candidates'),
]

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline-only',action='store_true')
    parser.add_argument('--control-from',help='Resume named controls after an independently recorded passing prefix')
    parser.add_argument('--control',action='append',default=[],
                        help='Run only the exact named causal control (repeatable)')
    parser.add_argument('--output',type=Path,default=ROOT/'_scratch/shared-reasoning/labor')
    args=parser.parse_args()
    missing = [str(path) for path in FILES.values() if not path.is_file()]
    if missing:
        print('FAULT Border 216: repository inputs missing: ' + ', '.join(missing)); return 1
    if not all(path.is_file() for path in (GAME/'projectzomboid.jar', GAME/'stdlib.lua', JDK/'java.exe', JDK/'javac.exe')):
        print('Border 216 SKIPPED: installed game VM or JDK absent'); return 0
    texts = {name: path.read_text(encoding='utf-8-sig') for name,path in FILES.items()}
    expected = set(re.findall(r"check\('([a-z0-9_]+)'", CASES))
    output=args.output.resolve();output.mkdir(parents=True,exist_ok=True)
    inputs=[Path(__file__).resolve(),Path(fixture.__file__).resolve(),ROOT/'tools/luacheck/LuaRun.java',
            *FILES.values(),GAME/'projectzomboid.jar',GAME/'stdlib.lua',JDK/'java.exe',JDK/'javac.exe']
    def pins():return {str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
    receipt={'schema':'sao-labor-proof/1','status':'RUNNING','boundary':__doc__,
             'inputs_before':pins(),'baselineOnly':args.baseline_only,'controlFrom':args.control_from,
             'controlTargets':args.control,'runs':[]}
    def save(): (output/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    def execute(command,cwd,name):
        done=subprocess.run(command,cwd=cwd,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=60)
        log=output/(name+'.log');log.write_text(done.stdout+done.stderr,encoding='utf-8')
        receipt['runs'].append({'name':name,'command':command,'exitCode':done.returncode,
            'logSha256':hashlib.sha256(log.read_bytes()).hexdigest()})
        save();return done
    try:
        with tempfile.TemporaryDirectory(prefix='sao-labor-planning-') as directory:
            work = Path(directory)
            shutil.copy2(GAME/'stdlib.lua', work/'stdlib.lua')
            compiled=execute([str(JDK/'javac.exe'), '-cp', str(GAME/'projectzomboid.jar'), '-d', str(work),
                            str(ROOT/'tools/luacheck/LuaRun.java')],work,'compile')
            if compiled.returncode: raise RuntimeError(compiled.stdout+compiled.stderr)
            def run(changed=None,label='production'):
                code = dict(texts); code.update(changed or {})
                chunks = {'prelude': fixture.ACTION_PRELUDE, 'setup': SETUP + '\n__before=' + json.dumps(BEFORE)
                          + '\n__after=' + json.dumps(AFTER) + '\n__routes=' + json.dumps(ROUTES)
                          + '\n__many=' + json.dumps(MANY), **code,
                          'reload': 'function __reloadPlanner()\n' + code['planner'] + '\nend', 'cases': CASES}
                paths=[]
                for name,text in chunks.items():
                    path = work/(name+'.lua'); path.write_text(text, encoding='utf-8'); paths.append(path)
                done = execute([str(JDK/'java.exe'), '-Djava.awt.headless=true', '-cp',
                    str(work)+os.pathsep+str(GAME/'projectzomboid.jar'), 'LuaRun', *map(str,paths), '--', '__laborResults'],
                    work,label)
                checks = dict(re.findall(r'^([a-z0-9_]+)=(true|false)$',done.stdout.replace('VALUE ',''),re.M))
                if done.returncode or set(checks) != expected:
                    raise RuntimeError(done.stdout[-6000:]+done.stderr[-1000:])
                return checks
            checks=run()
            failed=[name for name,value in checks.items() if value!='true']
            if failed: raise RuntimeError('failed cases: '+', '.join(failed))
            selected=[] if args.baseline_only else CONTROLS
            if args.control:
                if args.baseline_only or args.control_from:
                    raise RuntimeError('--control requires neither --baseline-only nor --control-from')
                unknown=set(args.control)-{control[3] for control in CONTROLS}
                if unknown:raise RuntimeError('unknown control target: '+', '.join(sorted(unknown)))
                selected=[control for control in CONTROLS if control[3] in args.control]
            if args.control_from:
                offset=next((i for i,c in enumerate(selected) if c[3]==args.control_from),None)
                if offset is None:raise RuntimeError('unknown control target: '+args.control_from)
                selected=selected[offset:]
            for index,(name,before,after,target) in enumerate(selected):
                if texts[name].count(before)!=1: raise RuntimeError(target+': mutation anchor differs')
                mutant=run({name:texts[name].replace(before,after,1)},str(index)+'-'+target)
                if mutant[target]!='false': raise RuntimeError(target+': mutation survived')
            receipt.update(status='PASS',cases=len(checks),controls=len(selected),inputs_after=pins())
            if receipt['inputs_before']!=receipt['inputs_after']:raise RuntimeError('relevant inputs changed during proof')
            save()
            print(f'Border 216 PASS: {len(checks)} production Kahlua cases; {len(selected)} named controls')
            return 0
    except Exception as error:
        receipt.update(status='FAIL',error=str(error));save()
        print('FAULT Border 216:',error); return 1

if __name__=='__main__': raise SystemExit(main())
