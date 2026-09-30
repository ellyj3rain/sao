#!/usr/bin/env python3
"""Border 217: maintained resource work and accepted-work reading preemption.

Installed Kahlua executes production Controller phases, Organization, Study,
Labor, planning, SourceUse and Cooking. Native reading Lua is installed truth;
body, movement, transfer, cooking and queue receivers are controlled. This
does not claim loaded-world behavior, helper assent or dataset admission.
"""
from pathlib import Path
import json
import os
import re
import shutil
import subprocess
import tempfile

import source_use_test as source_fixture
import study_test as study_fixture

ROOT = Path(__file__).resolve().parent.parent
GAME = Path(os.environ.get('PZ_DIR', str(study_fixture.GAME)))
JDK = Path(os.environ.get('JDK_BIN', str(study_fixture.JDK)))
LUA = ROOT / 'mod/42.20/media/lua'
FILES = {
    'controller': LUA / 'client/SAO_Controller.lua',
    'planner': LUA / 'shared/SAO_ProceduralPlanning.lua',
    'labor': LUA / 'shared/SAO_Labor.lua',
    'organization': LUA / 'shared/SAO_Organization.lua',
    'study': LUA / 'client/SAO_Study.lua',
    'needs': LUA / 'client/SAO_Needs.lua',
    'world': LUA / 'shared/SAO_WorldSources.lua',
    'source': LUA / 'client/SAO_SourceUse.lua',
    'cooking': LUA / 'client/SAO_Cooking.lua',
    'locomotion': LUA / 'client/SAO_Locomotion.lua',
}

COMMON = r'''
local Ctl=SAO.Controller
local setState=function(agent,id,state,reason) agent.state=state agent.reason=reason return true end
local policy=function() return {desperation=0.8} end
local SUPPORTED_COORDINATION={['food-delivery']=true,provisioning=true,['cooperative-action']=true}
local coordinationProcedureStep=function(plan)
    return plan.intendedStepId and plan.privateProcedure and plan.privateProcedure.beliefs[plan.intendedStepId]
end
local procedureStepDestination=function(step) return step and step.target end
local coordinationDestination=function(plan) return plan.proposal and plan.proposal.destination end
local coordinationRequesterInSight=function() return nil end
local carriedSupply=function(body,category) return __committedCargo==true end
local advanceCoordination=function(id,body,owner,activity,agent,selected)
    __replacement=(__replacement or 0)+1 __replacementCommitment=selected and selected.id
    return true
end
'''

PREEMPT_CASES = r'''
local checks={}
local function check(name,value) checks[#checks+1]=name..'='..tostring(value==true) end
local S,P,Org,Ctl=SAO.Study,SAO.ProceduralPlanning,SAO.Organization,SAO.Controller
local function reset()
    Org.processes={} Org.processOrder={} Org.processMeta={sequence=0}
    __records.a={id='a',bodyOwnerToken='owner-1'} __records.b={id='b'}
    local body,book=fixture('a') body.isAsleep=function() return false end
    body.isExistInTheWorld=function() return body.attached end
    SAO.Body.active={a=body} SAO.Body.foreign={}
    SAO.Controller.agents={a={state='IDLE',rec=__records.a}}
    SAOJavaBridge.isShell=function() return body.shell~=false end
    book.getFluidContainerFromSelfOrWorldItem=function() return nil end
    body.getX=function() return 1 end body.getY=function() return 1 end body.getZ=function() return 0 end
    SAO.Standing={mayAttemptBelieved=function() return true end,mayTakeCurrent=function() return true end}
    SAO.Perception={knownPlaces=function() return {[1]={cx=1,cy=1,minX=0,minY=0,maxX=3,maxY=3}} end}
    SAO.WorldSources={privatelyKnowsItem=function() return true end,
        actionOptions=function() return __materialAvailable and {options={{parameters={sourceId='known',revision='r1',itemId=20,itemType=__materialType,sourceX=1,sourceY=1,sourceZ=0}}}} end,
        inspectionCandidate=function() return nil end}
    SAO.SourceUse={} __materialAvailable=true __committedCargo=false __materialType='Base.Apple'
    SAOJavaBridge.findFoodSource=function() return __nativeMaterialAvailable==false and '' or '1:1:0:apple' end
    SAOJavaBridge.foodSourceItem=function() return {getID=function() return 20 end,getFullType=function() return 'Base.Apple' end} end
    SAOJavaBridge.foodSourceWithinReach=function() return true end __nativeMaterialAvailable=true
    __replacement=0 ISTimedActionQueue.accept=true
    check('fixture_'..tostring(#checks),true)
    S.begin('a',body,book)
    local action=ISTimedActionQueue.queues[body].action
    action.action={getJobDelta=function() return 0.4 end} action:update()
    return body,book,SAO.Controller.agents.a,action
end
local function proposal(cooperative)
    return Org.raiseMatter('b',cooperative and 'cooperative-action' or 'food-delivery',nil,
        cooperative and {cooperative=true,procedure={
            {id='first',verb='move',domain='movement',capability='move',completesOn='route:arrived',target={x=2,y=2,z=0}},
            {id='second',verb='move',domain='movement',capability='move',dependsOn={'first'},completesOn='route:arrived',target={x=3,y=3,z=0}}}}
        or {scope={category='food'}},{'a'},{need=.8})
end
local function accept(process,delivered,step)
    Org.recordReception(process.id,'a',1,'controlled-native-transport','b',{})
    Org.respond(process.id,'a','accept',step and {stepIds={step}} or {},
        {capabilities={move=true,acquire=true,carry=true,deliver=true,execute=true},canExecute=true})
    if delivered then Org.deliverResponse(process.id,'a','b','controlled-native-return',{}) end
    return Org.activeCommitment('a')
end
local body,book,agent,action=reset()
local process=proposal(false)
check('unheard_proposal_preserves_native_reading',not Ctl.preemptStudyForCoordination('a',agent,body)
    and S.active('a',body) and __replacement==0)
accept(process,false)
check('undelivered_acceptance_preserves_native_reading',not Ctl.preemptStudyForCoordination('a',agent,body)
    and S.active('a',body) and __replacement==0)
local commitment=accept(process,true)
local purposeId=__records.a.studyWork.purposeId
check('delivered_commitment_cancels_before_replacement',Ctl.preemptStudyForCoordination('a',agent,body)
    and __replacement==1 and not ISTimedActionQueue.hasAction(action) and body.pages==40
    and __records.a.studyWork.status=='interrupted'
    and P.studyPurpose('a','Cooking').id==purposeId)
check('cancelled_reading_resumes_same_pages_and_purpose',S.begin('a',body,book)
    and __records.a.studyWork.purposeId==purposeId
    and ISTimedActionQueue.queues[body].action.startPage==40)
body,book,agent,action=reset() process=proposal(false) accept(process,true) __materialAvailable=false
check('accepted_work_without_private_means_keeps_reading',not Ctl.preemptStudyForCoordination('a',agent,body)
    and S.active('a',body) and __replacement==0)
body,book,agent,action=reset()
process=Org.raiseMatter('b','cooperative-action',nil,{cooperative=true,scope={category='food'},
    procedure={{id='fetch',verb='acquire',domain='material',capability='acquire',completesOn='source:acquired'}}},{'a'},{})
commitment=accept(process,true,'fetch')
check('ready_accepted_material_step_interrupts_reading',commitment~=nil
    and Org.workPlan(commitment.id,'a').intendedStepId=='fetch'
    and Ctl.preemptStudyForCoordination('a',agent,body) and __replacement==1
    and not ISTimedActionQueue.hasAction(action))
body,book,agent,action=reset()
process=Org.raiseMatter('b','cooperative-action',nil,{cooperative=true,scope={category='food'},
    procedure={{id='fetch',verb='acquire',domain='material',capability='acquire',completesOn='source:acquired'}}},{'a'},{})
commitment=accept(process,true,'fetch') __materialAvailable=false
check('accepted_material_step_without_means_keeps_reading',commitment~=nil
    and not Ctl.preemptStudyForCoordination('a',agent,body) and __replacement==0 and S.active('a',body))
body,book,agent,action=reset() process=proposal(false) accept(process,true) __nativeMaterialAvailable=false
check('distant_private_source_does_not_cancel_reading',not Ctl.preemptStudyForCoordination('a',agent,body)
    and __replacement==0 and S.active('a',body))

body,book,agent,action=reset() process=proposal(true) commitment=accept(process,true,'second')
local private=commitment and Org.workPlan(commitment.id,'a')
check('dependency_blocked_work_keeps_reading',commitment~=nil and private.intendedStepId==nil
    and not Ctl.preemptStudyForCoordination('a',agent,body) and S.active('a',body) and __replacement==0)
body,book,agent,action=reset() process=proposal(false) commitment=accept(process,true)
commitment.work.pendingReceiptId='other-native-receipt'
check('existing_native_owner_keeps_reading',not Ctl.preemptStudyForCoordination('a',agent,body) and __replacement==0)
commitment.work.pendingReceiptId=nil commitment.work.owner='ZAO.Driver'
check('different_executor_keeps_reading',not Ctl.preemptStudyForCoordination('a',agent,body) and __replacement==0)
body,book,agent,action=reset() process=proposal(false) accept(process,true) body.shell=false
check('fake_body_keeps_native_reading',not Ctl.preemptStudyForCoordination('a',agent,body) and __replacement==0)
body,book,agent,action=reset() process=proposal(false) accept(process,true)
local otherAction={character=body,workId='different'}
ISTimedActionQueue.queues[body].queue[#ISTimedActionQueue.queues[body].queue+1]=otherAction
check('another_queued_owner_prevents_reading_clear',not Ctl.preemptStudyForCoordination('a',agent,body)
    and ISTimedActionQueue.hasAction(action) and ISTimedActionQueue.hasAction(otherAction) and __replacement==0)
body,book,agent,action=reset() process=proposal(false) accept(process,true)
local clear=ISTimedActionQueue.clear ISTimedActionQueue.clear=function() error('native cancellation refused') end
check('cancellation_refusal_blocks_replacement',Ctl.preemptStudyForCoordination('a',agent,body)
    and ISTimedActionQueue.hasAction(action) and __replacement==0 and body.pages==40)
check('failed_cancel_holds_subsequent_decision',Ctl.preemptStudyForCoordination('a',agent,body) and __replacement==0)
ISTimedActionQueue.clear=clear
check('exact_cancel_retry_releases_native_owner',Ctl.preemptStudyForCoordination('a',agent,body)
    and not ISTimedActionQueue.hasAction(action) and __replacement==1)
__resourceResults=table.concat(checks,'\n')
'''

JOIN_CASES = PREEMPT_CASES.split('local body,book,agent,action=reset()', 1)[0] + r'''
local function transferOwner()
    SAOJavaBridge.foodSourceContainer=function() return __nativeContainer end
    __nativeContainer={}
    SAO.SourceUse.beginTransfer=function(id,body,category,admission,item,container,operation,context)
        if SAO.Needs.busy(body) or item:getID()~=20 or container~=__nativeContainer then return false end
        local queued=SAO.Needs.queueVerified({character=body,Type='controlled-native-transfer'})
        if not queued then return false end
        __replacement=__replacement+1
        local reservation={id='controlled-native-transfer/'..tostring(__replacement)}
        SAO.Organization.noteWorkAdmission(context.commitmentId,'SourceUse',reservation.id,{operation=operation})
        return true,reservation
    end
end
local body,book,agent,action=reset() transferOwner()
local process=proposal(false) local commitment=accept(process,true)
check('actual_coordination_and_needs_queue_after_reading_cancellation',Ctl.preemptStudyForCoordination('a',agent,body)
    and agent.state=='TAKE' and __replacement==1 and not ISTimedActionQueue.hasAction(action)
    and SAO.Needs.busy(body) and commitment.work.pendingReceiptId=='controlled-native-transfer/1'
    and __records.a.studyWork.status=='interrupted' and body.pages==40)
body,book,agent,action=reset() transferOwner() process=proposal(false) accept(process,true)
__nativeMaterialAvailable=false
check('actual_collection_selector_refuses_distant_memory_before_cancel',not Ctl.preemptStudyForCoordination('a',agent,body)
    and agent.state=='IDLE' and __replacement==0 and S.active('a',body))
body,book,agent,action=reset() transferOwner() process=proposal(false) accept(process,true)
local clear=ISTimedActionQueue.clear ISTimedActionQueue.clear=function() error('native cancellation refused') end
check('actual_needs_collection_never_admits_over_refused_reading_cancel',Ctl.preemptStudyForCoordination('a',agent,body)
    and __replacement==0 and ISTimedActionQueue.hasAction(action))
ISTimedActionQueue.clear=clear
local function water()
    __materialType='Base.WaterBottle'
    local item={getID=function() return 20 end,getFullType=function() return __materialType end,
        getFluidContainerFromSelfOrWorldItem=function() return {getAmount=function() return 1 end,
            isWaterSource=function() return true end,isPoisonous=function() return false end,
            isTainted=function() return false end} end}
    SAOJavaBridge.findNearbyContainer=function() return __nativeContainer end
    SAOJavaBridge.privateContainerItems=function() return {size=function() return 1 end,get=function() return item end} end
    SAOJavaBridge.containerAccessibleNow=function() return __holderAccessible end
    __holderAccessible=true
    local process=Org.raiseMatter('b','provisioning',nil,{scope={category='water'}},{'a'},{})
    return accept(process,true)
end
body,book,agent,action=reset() transferOwner() commitment=water()
check('native_potable_water_collection_preempts_and_queues',Ctl.preemptStudyForCoordination('a',agent,body)
    and agent.state=='TAKE' and __replacement==1 and not ISTimedActionQueue.hasAction(action)
    and commitment.work.pendingReceiptId=='controlled-native-transfer/1')
body,book,agent,action=reset() transferOwner() water() __holderAccessible=false
check('water_holder_out_of_native_reach_preserves_reading',not Ctl.preemptStudyForCoordination('a',agent,body)
    and S.active('a',body) and __replacement==0)
body,book,agent,action=reset() transferOwner() water()
SAO.Standing.mayTakeCurrent=function() return false end
check('current_water_permission_refusal_preserves_reading',not Ctl.preemptStudyForCoordination('a',agent,body)
    and S.active('a',body) and __replacement==0)
__resourceResults=table.concat(checks,'\n')
'''

SOURCE = source_fixture.snapshot(1, 1, 's1', [{
    'id': 'C:food:0', 'fp': 'food', 'rev': 'r1', 'kind': 'container',
    'x': 8, 'y': 8, 'building': 42, 'quantities': {'food': 2},
    'items': [{'id': 11, 'type': 'Base.Apple', 'amount': 0, 'cats': 'food'},
              {'id': 12, 'type': 'Base.MuttonChop', 'amount': 0, 'cats': 'food'}],
}])
POST = source_fixture.snapshot(1, 1, 's2', [{
    'id': 'C:food:0', 'fp': 'food', 'rev': 'r2', 'kind': 'container',
    'x': 8, 'y': 8, 'building': 42, 'quantities': {'food': 1},
    'items': [{'id': 11, 'type': 'Base.Apple', 'amount': 0, 'cats': 'food'}],
}])
POST_APPLE = source_fixture.snapshot(1, 1, 's2', [{
    'id': 'C:food:0', 'fp': 'food', 'rev': 'r2', 'kind': 'container',
    'x': 8, 'y': 8, 'building': 42, 'quantities': {'food': 1},
    'items': [{'id': 12, 'type': 'Base.MuttonChop', 'amount': 0, 'cats': 'food'}],
}])

RESOURCE_SETUP = r'''
require=function() end
SAO.Controller={agents={}}
SAO.Census={skillOf=function() return 0 end}
SAO.Lessons={desperationBump=function() return 0 end}
SAO.Disposition={eatAt=function() return .5 end,drinkAt=function() return .5 end}
function instanceof(item,kind) return item.kind==kind end
SkillBook={Cooking={perk={getId=function() return 'Cooking' end}}}
function getScriptManager() return {getItem=function(_,name)
    return {isIsCookable=function() return name=='Base.MuttonChop' end}
end} end
local p={id=42,cx=8,cy=8,minX=8,minY=8,maxX=16,maxY=16}
function __resetResource()
    __stores={} __records={a={id='a'},b={id='b'}} __known={} __places={[42]=p}
    __bodies={a=__newBody(8,8),b=__newBody(8,8)} SAO.Body.active=__bodies SAO.Body.foreign={}
    SAO.WorldSources.applySnapshot(SAO.WorldSources.parse(__before))
    local q,rev,access,facts=SAO.WorldSources.beliefSnapshot(p)
    __known.a={[42]={cx=8,cy=8,minX=8,minY=8,maxX=16,maxY=16,
        sources=q,sourceRevision=rev,sourceAccess=access,sourceFacts=facts}}
    local body=__bodies.a body.getModData=function() return {SAOPersonId='a'} end
    body.isDead=function() return false end body.isAsleep=function() return false end
    body.isExistInTheWorld=function() return true end body.getPerkLevel=function() return 0 end
    body.getBodyDamage=function() return {getOverallBodyHealth=function() return 100 end} end
    __bodies.b.getPerkLevel=body.getPerkLevel __bodies.b.getBodyDamage=body.getBodyDamage
    SAO.Controller.agents={a={state='IDLE',rec=__records.a}}
    SAOJavaBridge.isShell=function() return true end
    __inventory={}
    SAOJavaBridge.privateCarriedItems=function() return {size=function() return #__inventory end,
        get=function(_,index) return __inventory[index+1] end} end
    __targetAnswer='READY:8:8:0:8:8:0' __bindAnswer='BOUND:8:8:0' __observeText=__before
    __routeAllowed=true __standingAllowed=true __sourceItem={exact=true} __sourceContainer={} __permissionContainer={}
    __carriedItem=nil __queueReject=false __busy=false __queued=nil
    SAOJavaBridge.carriedWorldTransferItem=function()
        local reservation=SAO.WorldSources.reservation(__records.a.worldSourceReservation)
        return 'T|operation=acquire|source=C:food:0|id='..tostring(reservation.itemId)
            ..'|type='..reservation.itemType..'|uses=1|amount=0|fluid=|poison=0|rotten=0|cats=food'
    end
    -- Visible inspection is controlled independently of remembered stock.
    SAO.WorldSources.inspectionCandidate=function() return __inspect end
    SAO.WorldSources.inspectionFailed=function() end
    SAO.Locomotion.jobs={} __inspect=nil
    return body,SAO.Controller.agents.a
end
'''

RESOURCE_CASES = r'''
local checks={}
local function check(name,value) checks[#checks+1]=name..'='..tostring(value==true) end
local Ctl,P=SAO.Controller,SAO.ProceduralPlanning
local n={hunger=.3,thirst=0,fatigue=0}
local body,agent=__resetResource()
local c=Ctl.resourceContext('a',agent,body,n,'food',.3)
check('keyed_private_place_supplies_exact_two_items',#c.sources==2 and c.sources[1].place.id==42
    and c.sources[1].revision=='r1' and c.skills.Cooking==0)
SAOJavaBridge.cookingOffers=function() return {foods={{sourceId='C:food:0',itemId=12,carried=false},
    {sourceId='uninspected',itemId=99,carried=false}}} end
c=Ctl.resourceContext('a',agent,body,n,'food',.3)
local rawKnown=false
for _, source in ipairs(c.sources) do if source.itemId==12 and source.cookable then rawKnown=true end end
check('native_raw_offer_only_labels_exact_privately_known_item',rawKnown and #c.sources==2)
local other=Ctl.resourceContext('b',agent,__bodies.b,n,'food',.3)
check('other_mind_has_no_source_options',#other.sources==0)
__inventory={{getID=function() return 90 end,getFullType=function() return 'Base.WaterBottle' end,
    getFluidContainerFromSelfOrWorldItem=function() return {getAmount=function() return 0 end,
    isWaterSource=function() return true end,isPoisonous=function() return false end,isTainted=function() return false end} end}}
check('empty_water_vessel_is_not_usable_supply',Ctl.resourceContext('a',agent,body,n,'water',.3).carriedWater==0)
__inventory={}
check('resource_goal_enters_real_acquisition_owner',Ctl.advanceResourcePurpose('a',agent,body,1,n)
    and agent.state=='SOURCEWARD' and __records.a.worldSourceReservation~=nil)
local purpose,step=P.resourceDemand('a','food') local reservation=SAO.WorldSources.reservation(__records.a.worldSourceReservation)
check('queued_acquisition_has_no_resource_credit',purpose.cursor==1 and step.verb=='acquire'
    and purpose.admission.correlationId==reservation.id)
SAO.SourceUse.onMovementDone('a',body,'arrived') SAO.SourceUse.onMovementDone('a',body,'arrived')
__carriedItem=__sourceItem __busy=false __observeText=reservation.itemId==11 and __afterApple or __after
local completed=SAO.SourceUse.tick('a',body)
local result=SAO.WorldSources.actionOutcome(reservation.id,'a')
check('canonical_transfer_advances_exact_resource_goal',completed=='completed' and result
    and P.consumeSourceResult(result) and (purpose.status=='completed' or purpose.cursor==2
        and purpose.steps[2].acquiredItemId==reservation.itemId and purpose.steps[2].owner=='Cooking'))

body,agent=__resetResource()
check('zero_pressure_keeps_personal_slack',not Ctl.advanceResourcePurpose('a',agent,body,1,{hunger=0,thirst=0,fatigue=0})
    and P.resourceDemand('a')==nil and agent.state=='IDLE')
body,agent=__resetResource() agent.resting=true
check('chosen_rest_does_not_start_resource_work',not Ctl.advanceResourcePurpose('a',agent,body,1,n)
    and P.resourceDemand('a')==nil)
body,agent=__resetResource() __busy=true
check('existing_native_action_does_not_start_resource_work',not Ctl.advanceResourcePurpose('a',agent,body,1,n))
body,agent=__resetResource() SAOJavaBridge.isShell=function() return false end
check('fake_resource_body_cannot_start_native_work',not Ctl.advanceResourcePurpose('a',agent,body,1,n))
body,agent=__resetResource() __known.a={}
check('unremembered_stock_is_not_a_resource_action',not Ctl.advanceResourcePurpose('a',agent,body,1,n)
    and __records.a.worldSourceReservation==nil)
body,agent=__resetResource()
SAO.WorldSources.applySnapshot(SAO.WorldSources.parse(__after))
c=Ctl.resourceContext('a',agent,body,n,'food',.3)
check('newer_world_stock_does_not_enter_private_resource_plan',#c.sources==0)
body,agent=__resetResource()
__known.a[42].sourceFacts={} __known.a[42].sourceRevision=''
__inspect={x=8,y=8,z=0,sourceId='C:food:0'}
check('remembered_unknown_contents_get_real_inspection_route',Ctl.advanceResourcePurpose('a',agent,body,1,n)
    and agent.state=='FORAGE' and agent.forageInspection==__inspect
    and P.resourceDemand('a').steps[1].verb=='inspect')
body,agent=__resetResource()
__known.a[42].sourceFacts={} __known.a[42].sourceRevision=''
__inspect={x=100,y=8,z=0,sourceId='foreign'}
check('foreign_inspection_does_not_hydrate_private_ground',not Ctl.advanceResourcePurpose('a',agent,body,1,n)
    and agent.forageInspection==nil)
body,agent=__resetResource()
Ctl.advanceResourcePurpose('a',agent,body,1,n) local held=P.resourceDemand('a')
SAO.WorldSources.failAction(__records.a.worldSourceReservation,'a','blocked-native-route')
P.consumeSourceResult(SAO.WorldSources.actionOutcome(held.admission.correlationId,'a'))
__records.a.worldSourceReservation=nil agent.state='IDLE'
check('resource_cadence_does_not_recreate_or_oscillate',not Ctl.advanceResourcePurpose('a',agent,body,2,n)
    and P.resourceDemand('a').id==held.id and #__records.a.proceduralPlanning.order==1)
__resourceResults=table.concat(checks,'\n')
'''

COOKING_CASES = r'''
local checks={}
local function check(name,value) checks[#checks+1]=name..'='..tostring(value==true) end
local P=SAO.ProceduralPlanning local labor=SAO.Labor
local executor=SAO.Controller
local function setup()
    newFixture() SAO.ProceduralPlanning=P SAO.Labor=labor
    SAO.Census={skillOf=function() return 0 end}
    SAO.Perception={knownPlaces=function() return {} end}
    local p,s=P.planResource(F.rec.id,{category='food',pressure=.4,carriedRaw=1,
        carriedRawItems={{itemId=71,itemType='Base.MuttonChop',cookable=true}}})
    return p,s
end
local p,s=setup()
local begun,work=SAO.Cooking.begin(F.rec.id,F.body,{privateFood=true,purposeId=p.id,purposeStepId=s.id,acquiredItemId=71})
check('cooking_binds_requested_resource_step',begun==true and work.purposeId==p.id and work.purposeStepId==s.id
    and work.requestedPurposeId==p.id and p.admission.correlationId==work.id)
check('cooking_admission_is_not_prepared_resource',p.status~='completed' and p.cursor==1)
SAO.Cooking.interrupt(F.rec.id,F.body,'accepted shared work') P.reconcileCooking(F.rec.id)
check('interrupted_held_food_retains_exact_goal_and_item',p.status=='interrupted'
    and p.steps[p.cursor].acquiredItemId==71 and F.food:getContainer()==F.inventory)
local retained,nextStep=P.planResource(F.rec.id,{category='food',pressure=.1,carriedRaw=1,
    carriedRawItems={{itemId=71,itemType='Base.MuttonChop',cookable=true}}})
check('held_raw_chain_survives_reassessment_at_lower_pressure',retained==p and nextStep.acquiredItemId==71)
p,s=setup() F.foodOffer.itemId=72
check('another_held_item_cannot_fulfill_bound_cooking_step',not SAO.Cooking.begin(F.rec.id,F.body,
    {privateFood=true,purposeId=p.id,purposeStepId=s.id,acquiredItemId=71}) and F.rec.cookingWork==nil)
p,s=setup() F.foodOffer.itemId=72 SAO.ProceduralPlanning=nil
check('native_food_selector_respects_requested_item_independently',not SAO.Cooking.begin(F.rec.id,F.body,
    {privateFood=true,acquiredItemId=71}) and F.rec.cookingWork==nil)
p,s=setup()
check('wrong_purpose_step_cannot_admit_cooking',not SAO.Cooking.begin(F.rec.id,F.body,
    {privateFood=true,purposeId=p.id,purposeStepId='wrong',acquiredItemId=71}) and p.admission==nil)
p,s=setup()
SAO.Controller.resourceContext=executor.resourceContext SAO.Controller.advanceResourcePurpose=executor.advanceResourcePurpose
SAO.Disposition={eatAt=function() return .5 end,drinkAt=function() return .5 end}
F.body.getPerkLevel=function() return 0 end
F.food.kind='Food' F.food.isRotten=function() return false end
F.food.getPoisonPower=function() return 0 end F.food.getHungChange=function() return -.4 end
F.food.getFluidContainerFromSelfOrWorldItem=function() return nil end
F.body.getBodyDamage=function() return {getOverallBodyHealth=function() return 100 end} end
SAOJavaBridge.privateCarriedItems=function() return F.inventory.items end
local agent=SAO.Controller.agents[F.rec.id]
check('controller_continues_held_raw_goal_into_native_cooking',executor.advanceResourcePurpose(F.rec.id,agent,F.body,1,
    {hunger=.3,thirst=0,fatigue=0}) and agent.state=='COOK' and F.rec.cookingWork.purposeId==p.id)
local work=F.rec.cookingWork
tickCooking() settleTransfer() completeToggle() tickCooking()
nativeCooked() tickCooking() settleTransfer() completeToggle() tickCooking()
P.reconcileCooking(F.rec.id)
check('completed_native_cooking_finishes_requested_resource_goal',p.status=='completed'
    and lastOutcome().nativeCredit==work.id and lastOutcome().retrieved==true and lastOutcome().shutdown=='off')
__resourceResults=table.concat(checks,'\n')
'''

CONTACT_SETUP = r'''
SAO.Controller={agents={}}
SAO.Disposition={drinkAt=function() return .35 end,eatAt=function() return .45 end}
SAO.Needs={read=function() return __needs end,bleeding=function() return __bleeding or 0 end}
SAO.SourceUse={beforeStateChange=function() return __sourceReconciled~=false end}
SAO.Communication={exchangeProcesses=function() return __spoken and {} or nil end}
SAO.Coordination={pendingContact=function() return __candidate end}
SAO.Standing={}
__orders=0 __cancelCalls=0 __needs={thirst=0,hunger=0,fatigue=0}
__cancelResult='MOVE_CANCELLED' __nativeStatus='IDLE'
SAOJavaBridge.moveTo=function() __orders=__orders+1 __nativeStatus='Working' return 'MOVE_STARTED' end
SAOJavaBridge.tickMove=function() return __nativeTick or 'Working' end
SAOJavaBridge.cancelMove=function()
    __cancelCalls=__cancelCalls+1
    if __cancelResult=='MOVE_CANCELLED' then __nativeStatus='IDLE' end
    return __cancelResult
end
SAOJavaBridge.movementIdle=function() return __nativeStatus=='IDLE' end
SAOJavaBridge.isShell=function() return true end
local Ctl=SAO.Controller
local CONTACT_STATES={CONTACTWARD=true,CONTACTWAIT=true}
local MOVEMENT_STATES={CONTACTWARD=true}
local PRESSURE_ANSWER={DRINK='need',EAT='need'}
local ARRIVAL_REACH=3
local tickCount=100
local log=function() end
local setStateRef
local decideNeedsAndCompanion=function(id,agent,body,tick,needs)
    __needsCalled=__needsCalled+1
    if __reliefAvailable and (needs.thirst>=.35 or needs.hunger>=.45 or __bleeding>0) then
        __admittedAfterCancel=__nativeStatus=='IDLE'
        return setStateRef(agent,id,'DRINK','native bodily relief admitted','need')
    end
    return false
end
'''

CONTACT_CASES = r'''
local checks={}
local function check(name,value) checks[#checks+1]=name..'='..tostring(value==true) end
local Org,Ctl,Loco=SAO.Organization,SAO.Controller,SAO.Locomotion
local function reset()
    Org.processes={} Org.processOrder={} Org.processMeta={sequence=0}
    __records.a={id='a',bodyOwnerToken='owner-1'} __records.b={id='b'}
    local body=fixture('a') body.x=0.5 body.y=0.5
    body.getX=function() return body.x end body.getY=function() return body.y end body.getZ=function() return 0 end
    SAO.Body.active={a=body} SAO.Body.foreign={}
    local agent={state='IDLE',rec=__records.a}
    Ctl.agents={a=agent} Loco.jobs={}
    __needs={thirst=0,hunger=0,fatigue=0} __bleeding=0 __reliefAvailable=false __needsCalled=0
    __spoken=false __sourceReconciled=true __cancelResult='MOVE_CANCELLED' __nativeStatus='IDLE'
    __orders=0 __cancelCalls=0 __hours=10
    local process=Org.raiseMatter('a','provisioning',nil,{scope={category='water'}},{'b'},{need=.8})
    __candidate={processId=process.id,recipientId='b',beliefKey='B',observedAt=90,
        source='observed',x=10.5,y=0.5,processRevision=1}
    return body,agent,process
end
local function fail(body,agent,status)
    __nativeTick=status or 'FailedObstacle:FAILED_LOCKED_DOOR'
    Loco.tick('a')
    return Ctl.testContactRouteEnd('a',agent,body,Loco.status('a'))
end
local body,agent,process=reset()
check('native_contact_admission_binds_exact_route',Ctl.seekPendingContact('a',agent,body,100)
    and agent.contactRoute==Loco.jobs.a and process.contactAttempts[1].evidence.fromX==.5)
fail(body,agent)
check('locked_door_records_failed_contact_not_reception',process.contactAttempts[1].status=='failed'
    and process.contactAttempts[1].outcomeEvidence.locomotionStatus=='done:FailedObstacle:FAILED_LOCKED_DOOR'
    and agent.state=='IDLE' and #Org.pendingProposals('a','b')==1)
check('unchanged_failed_address_does_not_immediately_restart',not Ctl.seekPendingContact('a',agent,body,101)
    and __orders==1 and #process.contactAttempts==1)
__candidate.observedAt=1000 body.x=.65
check('fresh_timestamp_and_subtile_jitter_do_not_reset_delay',not Ctl.seekPendingContact('a',agent,body,102)
    and __orders==1)
__spoken=true
check('actual_speech_is_attempted_during_route_backoff',Ctl.seekPendingContact('a',agent,body,103) and __orders==1)
__spoken=false __hours=10+2/60
check('elapsed_delay_allows_one_real_retry',Ctl.seekPendingContact('a',agent,body,104) and __orders==2)
fail(body,agent,'FailedObstacle:FAILED_EDGE_COOLDOWN') __hours=10+5/60
Ctl.seekPendingContact('a',agent,body,105) fail(body,agent)
__hours=11
check('three_equivalent_failures_require_changed_evidence',not Ctl.seekPendingContact('a',agent,body,106)
    and __orders==3 and #process.contactAttempts==3)
__candidate.x=11.5 __candidate.observedAt=1001
check('independently_observed_changed_address_is_reconsidered',Ctl.seekPendingContact('a',agent,body,107)
    and __orders==4)
fail(body,agent) body.x=3.5 __hours=12
check('meaningful_actual_approach_change_is_reconsidered',Ctl.seekPendingContact('a',agent,body,108)
    and __orders==5)

body,agent,process=reset()
for i=1,3 do
    local attempt=Org.beginContact(process.id,'a','b',{owner='SAO.Controller',representation='loaded',x=10.5,y=.5})
    Org.finishContact(process.id,attempt.id,'a','failed',{reason='native-route-did-not-arrive',locomotionStatus='done:Failed'})
end
check('legacy_missing_route_context_is_not_failure_knowledge',Ctl.seekPendingContact('a',agent,body,110) and __orders==1)
body,agent,process=reset()
for i=1,3 do
    local attempt=Org.beginContact(process.id,'a','b',{owner='SAO.Controller',representation='loaded',
        x=10.5,y=.5,z=0,fromX=.5,fromY=.5,fromZ=0,observedAt=90,source='observed'})
    Org.finishContact(process.id,attempt.id,'a','failed',{reason='contact-arrival-not-recorded',locomotionStatus='done:arrived'})
end
check('arrival_recording_refusal_is_not_physical_route_failure',Ctl.seekPendingContact('a',agent,body,111) and __orders==1)
fail(body,agent) __hours=11
local attempt=Org.beginContact(process.id,'a','b',{owner='SAO.Controller',representation='loaded',
    x=20.5,y=.5,z=0,fromX=3.5,fromY=.5,fromZ=0,observedAt=95,source='observed'})
Org.arriveContact(process.id,attempt.id,'a',{}) Org.finishContact(process.id,attempt.id,'a','interrupted',{})
check('successful_later_approach_does_not_resurrect_old_failures',Ctl.seekPendingContact('a',agent,body,112)
    and __orders==2)
check('foreign_actor_cannot_query_contact_route_history',not Org.contactRouteMayStart(process.id,'b','a',
    {x=10.5,y=.5,z=0,fromX=.5,fromY=.5,fromZ=0}))

body,agent,process=reset() Ctl.seekPendingContact('a',agent,body,120)
__needs.thirst=.52 __reliefAvailable=true
Ctl.testContactDecision('a',agent,body,121)
check('deprivation_preempts_contact_before_native_relief',agent.state=='DRINK' and __admittedAfterCancel
    and process.contactAttempts[1].status=='interrupted' and not Loco.jobs.a and __needsCalled==1
    and #Org.pendingProposals('a','b')==1)
body,agent,process=reset() Ctl.seekPendingContact('a',agent,body,122)
__needs.hunger=.6 __reliefAvailable=true __cancelResult='CANCEL_FAILED controlled'
local contact=agent.contactAttemptId local route=agent.contactRoute
Ctl.testContactDecision('a',agent,body,123)
check('native_cancellation_refusal_preserves_contact_owner',agent.state=='CONTACTWARD'
    and agent.contactAttemptId==contact and Loco.jobs.a==route and __needsCalled==0
    and process.contactAttempts[1].status=='travelling')
body,agent,process=reset() Ctl.seekPendingContact('a',agent,body,124)
__needs.thirst=.52 __sourceReconciled=false __reliefAvailable=true
Ctl.testContactDecision('a',agent,body,125)
check('source_reconciliation_refusal_admits_no_replacement',agent.state=='CONTACTWARD'
    and process.contactAttempts[1].status=='travelling' and __needsCalled==0)
body,agent,process=reset() Ctl.seekPendingContact('a',agent,body,126)
__needs.thirst=.52 __records.a.resourceProductionWork={id='other-native-work'}
Ctl.testContactDecision('a',agent,body,127)
check('active_production_owner_cannot_be_cancelled_by_stale_contact',__cancelCalls==0
    and agent.state=='CONTACTWARD' and __needsCalled==0)
__records.a.resourceProductionWork=nil __records.a.cookingWork={id='other-cooking'}
Ctl.testContactDecision('a',agent,body,128)
check('active_cooking_owner_cannot_be_cancelled_by_stale_contact',__cancelCalls==0 and __needsCalled==0)
__records.a.cookingWork=nil __records.a.worldSourceReservation='other-source'
Ctl.testContactDecision('a',agent,body,129)
check('active_source_owner_cannot_be_cancelled_by_stale_contact',__cancelCalls==0 and __needsCalled==0)
body,agent,process=reset() Ctl.seekPendingContact('a',agent,body,130)
__needs.thirst=.52 Loco.jobs.a={body=body,goal={x=30,y=30,z=0},done=false}
local foreignRoute=Loco.jobs.a
Ctl.testContactDecision('a',agent,body,131)
check('newer_same_body_foreign_route_is_not_contact_cancellation',__cancelCalls==0
    and Loco.jobs.a==foreignRoute and __needsCalled==0)
body,agent,process=reset() Ctl.seekPendingContact('a',agent,body,132)
__needs.thirst=.52 body.data.SAOExternalOwner='foreign'
Ctl.testContactDecision('a',agent,body,133)
check('adopted_body_keeps_its_independent_owner',__cancelCalls==0 and __needsCalled==0)

body,agent,process=reset() __candidate.x=.5
Ctl.seekPendingContact('a',agent,body,140)
check('actual_address_arrival_does_not_grant_reception',agent.state=='CONTACTWAIT'
    and process.contactAttempts[1].arrivedAt==10 and #Org.pendingProposals('a','b')==1)
__needs.thirst=.52 Ctl.testContactDecision('a',agent,body,141)
check('contactwait_deprivation_without_relief_releases_ordinary_work',agent.state=='IDLE'
    and process.contactAttempts[1].status=='interrupted' and __ordinaryWork==1 and __orders==0)
__needs.thirst=0 Ctl.testContactDecision('a',agent,body,142)
check('resolved_needs_allow_contact_to_resume_normally',agent.state=='CONTACTWAIT'
    and #process.contactAttempts==2)
body,agent,process=reset() __needs.thirst=.52 __reliefAvailable=true
Ctl.testContactDecision('a',agent,body,150)
check('idle_urgent_need_precedes_pending_contact_selection',agent.state=='DRINK' and __orders==0)
body,agent,process=reset() __needs.thirst=.52
Ctl.testContactDecision('a',agent,body,151)
check('unavailable_relief_does_not_hide_maintained_resource_phase',agent.state=='IDLE' and __orders==0
    and __ordinaryWork==1)
body,agent,process=reset() Ctl.seekPendingContact('a',agent,body,152)
__bleeding=1
Ctl.testContactDecision('a',agent,body,153)
check('bleeding_releases_contact_ownership',agent.state=='IDLE' and process.contactAttempts[1].status=='interrupted')
__resourceResults=table.concat(checks,'\n')
'''

CONTROLS = [
    ('controller', 'commitment.acceptedAt ~= nil', 'false', 'delivered_commitment_cancels_before_replacement', 'study'),
    ('controller', 'if not cancelled or result ~= true or SAO.Needs.busy(body)\n                or SAO.Study.active(id, body) then',
     'if false then', 'cancellation_refusal_blocks_replacement', 'study'),
    ('world', 'physical.revision == source.revision', 'true',
     'newer_world_stock_does_not_enter_private_resource_plan', 'resource',
     ('controller','if p and SAO.WorldSources.privatelyKnowsItem(id, p.sourceId, p.itemId) then','if p then')),
    ('controller', 'inspect.x >= belief.minX and inspect.x <= belief.maxX\n                and inspect.y >= belief.minY and inspect.y <= belief.maxY then\n                context.inspectPlace',
     'true then\n                context.inspectPlace', 'foreign_inspection_does_not_hydrate_private_ground', 'resource'),
    ('cooking', 'requestedPurposeId = context.purposeId, requestedPurposeStepId = context.purposeStepId,',
     'requestedPurposeId = nil, requestedPurposeStepId = nil,', 'cooking_binds_requested_resource_step', 'cooking'),
    ('cooking', 'tostring(row.itemId) == tostring(context.acquiredItemId)',
     'true', 'native_food_selector_respects_requested_item_independently', 'cooking'),
    ('organization','if belief and ready then current = stepId end','if belief then current = stepId end',
     'dependency_blocked_work_keeps_reading','study'),
    ('controller','fluid and fluid:getAmount() > 0 and fluid:isWaterSource()',
     'fluid and fluid:isWaterSource()', 'empty_water_vessel_is_not_usable_supply','resource'),
    ('controller','state, returned = SAO.Needs.collectNearby(id, body, 20, 2,\n                context)',
     'state, returned = "TAKE", context', 'actual_coordination_and_needs_queue_after_reading_cancellation','join'),
    ('controller','if not current or accessible ~= true then return false end',
     'if false then return false end', 'water_holder_out_of_native_reach_preserves_reading','join'),
    ('controller','and SAO.Standing.mayTakeCurrent(id, source.sourceX, source.sourceY, "standing") == true then',
     'then', 'current_water_permission_refusal_preserves_reading','join'),
    ('organization','if latest and nowHours() < (tonumber(latest.endedAt) or nowHours())',
     'if false and nowHours() < (tonumber(latest.endedAt) or nowHours())',
     'unchanged_failed_address_does_not_immediately_restart','contact'),
    ('organization','if count >= MAX_CONTACT_ROUTE_FAILURES then',
     'if false then','three_equivalent_failures_require_changed_evidence','contact'),
    ('organization','local physicalFailure = attempt.status == "failed" and prior.owner == "SAO.Controller"',
     'local physicalFailure = attempt.status == "failed" or prior.owner == "SAO.Controller"',
     'legacy_missing_route_context_is_not_failure_knowledge','contact'),
    ('organization','and outcome.reason == "native-route-did-not-arrive"',
     'and true','arrival_recording_refusal_is_not_physical_route_failure','contact',
     ('organization','and not outcome.locomotionStatus:find("arrived", 1, true)','and true')),
    ('controller','if not ok or cancelled ~= "MOVE_CANCELLED" then return "held" end',
     'if false then return "held" end','native_cancellation_refusal_preserves_contact_owner','contact'),
    ('controller','or rec.resourceProductionWork or rec.cookingWork or rec.worldSourceReservation',
     'or false','active_production_owner_cannot_be_cancelled_by_stale_contact','contact'),
    ('controller','job ~= agent.contactRoute or job.body ~= body',
     'job.body ~= body','newer_same_body_foreign_route_is_not_contact_cancellation','contact'),
    ('controller','if agent.state == "IDLE" and not Ctl.contactNeedPriority(id, body, needs)',
     'if agent.state == "IDLE"','unavailable_relief_does_not_hide_maintained_resource_phase','contact'),
]


def controller_phases(text, real_coordination=False):
    begin = text.split('local function beginContainerInspection', 1)[1].split(
        '-- A delivered commitment can interrupt reading', 1)[0]
    phases = text.split('function Ctl.preemptStudyForCoordination', 1)[1].split(
        '-- Retained private prerequisites', 1)[0]
    common = COMMON
    if real_coordination:
        common = common.split('local advanceCoordination=function', 1)[0]
        common += r'''
local coordinationContext=function(plan,category) return {
    purpose='committed-delivery',category=category,admission='standing',haulRemaining=1,haulRadius=4,
    processId=plan.processId,processRevision=plan.processRevision,commitmentId=plan.commitmentId,
    deliveryGroup=plan.organizationId,requestedByGroup=plan.organizationId} end
local latestRoute=function(commitment)
    local routes=commitment.work and commitment.work.routeAttempts or {} return routes[#routes]
end
local tickCoordinationRoute=function() return false end
local pauseCoordinationRoute=function(commitment,reason) SAO.Organization.pauseWork(commitment.id,reason) end
'''
        common += 'local function advanceCoordination' + text.split('local function advanceCoordination', 1)[1].split(
            'function Ctl.advanceExternalCoordination', 1)[0]
    return common + '\nlocal function beginContainerInspection' + begin + '\nfunction Ctl.preemptStudyForCoordination' + phases


def contact_phases(text):
    helpers = 'local function clearLoadedContact' + text.split('local function clearLoadedContact', 1)[1].split(
        'function Ctl.drop(id)', 1)[0]
    state = 'local function setState' + text.split('local function setState', 1)[1].split('setStateRef = setState', 1)[0]
    travel = 'local function orderTravelState' + text.split('local function orderTravelState', 1)[1].split(
        'local function startNearbyCollection', 1)[0]
    contact = 'function Ctl.contactNeedPriority' + text.split('function Ctl.contactNeedPriority', 1)[1].split(
        'local function coordinationContext', 1)[0]
    terminal = text.split('            if agent.state == "CONTACTWARD" then\n                local arrived', 1)[1].split(
        '            if agent.state == "HOMEWARD"', 1)[0]
    terminal = 'if agent.state == "CONTACTWARD" then\n                local arrived' + terminal
    terminal = terminal.split('            if agent.state ==', 1)[0]
    priority = text.split('    -- Needs are read before a contact', 1)[1].split(
        '    -- The branching graph', 1)[0]
    priority = '-- Needs are read before a contact' + priority
    return CONTACT_SETUP + helpers + state + '\nsetStateRef=setState\n' + travel + contact + (
        '\nfunction Ctl.testContactRouteEnd(id,agent,body,s)\n' + terminal + '\nend\n'
        'function Ctl.testContactDecision(id,agent,body,tick)\n__ordinaryWork=0\n' + priority
        + '\n__ordinaryWork=__ordinaryWork+1\nend\n')


def main():
    if not (GAME / 'projectzomboid.jar').is_file() or not (JDK / 'javac.exe').is_file():
        print('Border 217 SKIPPED: installed game VM and JDK absent')
        return 0
    texts = {name: path.read_text(encoding='utf-8-sig') for name, path in FILES.items()}
    try:
        with tempfile.TemporaryDirectory(prefix='sao-resource-execution-') as directory:
            work = Path(directory)
            shutil.copy2(GAME / 'stdlib.lua', work / 'stdlib.lua')
            build = subprocess.run([str(JDK / 'javac.exe'), '-cp', str(GAME / 'projectzomboid.jar'),
                '-d', str(work), str(ROOT / 'tools/luacheck/LuaRun.java')], capture_output=True, text=True)
            if build.returncode:
                raise RuntimeError('runner compile: ' + build.stderr[-3000:])

            def run(kind, changed=None):
                code = dict(texts)
                code.update(changed or {})
                paths = []

                def add(name, value):
                    path = work / (kind + '-' + name + '.lua')
                    path.write_text(value, encoding='utf-8')
                    paths.append(path)

                if kind in ['study', 'join']:
                    add('prelude', study_fixture.PRELUDE + '\nSAO.Controller={agents={}}\nSAO.Locomotion={order=function() return true end}\n')
                    paths.extend([GAME / 'media/lua/shared/ISBaseObject.lua',
                        GAME / 'media/lua/shared/TimedActions/ISBaseTimedAction.lua',
                        GAME / 'media/lua/client/TimedActions/ISInventoryTransferAction.lua',
                        GAME / 'media/lua/shared/TimedActions/ISReadABook.lua'])
                    for name in ['planner', 'organization', 'needs', 'study']:
                        add(name, code[name])
                    add('controller', controller_phases(code['controller'], real_coordination=kind == 'join'))
                    cases = (JOIN_CASES if kind == 'join' else PREEMPT_CASES).replace("    check('fixture_'..tostring(#checks),true)\n", '')
                elif kind == 'resource':
                    add('prelude', source_fixture.ACTION_PRELUDE)
                    add('setup', RESOURCE_SETUP + '\n__before=' + json.dumps(SOURCE) + '\n__after=' + json.dumps(POST)
                        + '\n__afterApple=' + json.dumps(POST_APPLE))
                    for name in ['world', 'labor', 'planner', 'source']:
                        add(name, code[name])
                    add('controller', controller_phases(code['controller']))
                    cases = RESOURCE_CASES
                elif kind == 'contact':
                    add('prelude', study_fixture.PRELUDE)
                    for name in ['organization','locomotion']:
                        add(name, code[name])
                    add('controller', contact_phases(code['controller']))
                    cases = CONTACT_CASES
                else:
                    paths.extend([ROOT / 'tools/cooking_checks/prelude.lua',
                        GAME / 'media/lua/shared/ISBaseObject.lua',
                        GAME / 'media/lua/shared/TimedActions/ISBaseTimedAction.lua',
                        GAME / 'media/lua/shared/TimedActions/ISToggleStoveAction.lua'])
                    add('initial', 'SAO.Controller={agents={}}\nfunction instanceof(item,kind) return item.kind==kind end\n')
                    for name in ['labor', 'planner', 'cooking']:
                        add(name, code[name])
                    add('controller', controller_phases(code['controller']))
                    cases = COOKING_CASES
                add('cases', cases)
                done = subprocess.run([str(JDK / 'java.exe'), '-Djava.awt.headless=true', '-cp',
                    str(work) + os.pathsep + str(GAME / 'projectzomboid.jar'), 'LuaRun', *map(str, paths),
                    '--', '__resourceResults'], cwd=work, capture_output=True, text=True, timeout=60)
                expected = set(re.findall(r"check\('([a-z0-9_]+)'", cases))
                checks = dict(re.findall(r'([a-z0-9_]+)=(true|false)', done.stdout))
                if done.returncode or set(checks) != expected:
                    raise RuntimeError(kind + ': ' + done.stdout[-6500:] + done.stderr[-1500:])
                return checks

            count = 0
            for kind in ['study', 'join', 'resource', 'cooking', 'contact']:
                checks = run(kind)
                count += len(checks)
                failures = [name for name, value in checks.items() if value != 'true']
                if failures:
                    raise RuntimeError(kind + ' failures: ' + ', '.join(failures))
            for entry in CONTROLS:
                name, before, after, target, kind = entry[:5]
                if texts[name].count(before) != 1:
                    raise RuntimeError(target + ': mutation anchor differs')
                mutations = {name: texts[name].replace(before, after, 1)}
                for second_name, second_before, second_after in entry[5:]:
                    second_text = mutations.get(second_name, texts[second_name])
                    if second_text.count(second_before) != 1:
                        raise RuntimeError(target + ': secondary mutation anchor differs')
                    mutations[second_name] = second_text.replace(second_before, second_after, 1)
                if run(kind, mutations)[target] != 'false':
                    raise RuntimeError(target + ': named defect control survived')
            print(f'Border 217 PASS: {count} installed Kahlua cases; {len(CONTROLS)} named controls')
            return 0
    except Exception as error:
        print('FAULT Border 217:', error)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
