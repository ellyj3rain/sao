#!/usr/bin/env python3
"""Border 219: exact native carried-vessel refill, private planning and outcomes.

Installed Kahlua executes installed ISTakeWaterAction and production resource
owner/planner/Controller code. Controlled native receivers isolate boundaries;
the separate native fixture probe exercises the actual loaded-source adapter.
"""
from pathlib import Path
import os
import re
import shutil
import subprocess
import tempfile

import resource_execution_test as execution
from lua_read import function_body

ROOT = Path(__file__).resolve().parent.parent
GAME, JDK = execution.GAME, execution.JDK
LUA = ROOT / 'mod/42.20/media/lua'
FILES = {
    'production': LUA / 'client/SAO_ResourceProduction.lua',
    'planner': LUA / 'shared/SAO_ProceduralPlanning.lua',
    'labor': LUA / 'shared/SAO_Labor.lua',
    'controller': LUA / 'client/SAO_Controller.lua',
    'models': LUA / 'shared/SAO_CognitiveModels.lua',
    'cognition': LUA / 'shared/SAO_Cognition.lua',
    'experience': LUA / 'client/SAO_CapabilityExperience.lua',
    'locomotion': LUA / 'client/SAO_Locomotion.lua',
    'organization': LUA / 'shared/SAO_Organization.lua',
    'sources': LUA / 'shared/SAO_WorldSources.lua',
    'perception': LUA / 'shared/SAO_Perception.lua',
    'needs': LUA / 'client/SAO_Needs.lua',
    'identity': LUA / 'shared/SAO_Identity.lua',
}
PRELUDE = r'''
require=function() end print=function() end
Events={OnGameStart={Add=function() end}}
isClient=function() return false end
isServer=function() return false end
sendItemStats=function() end
ISLogSystem={logAction=function() end}
ZomboidGlobals={EquippedOrWornEncumbranceMultiplier=.3}
instanceof=function(item,kind) return item.kind==kind end
SAO={}
local function list(values) return {size=function() return #values end,get=function(self,i) return values[i+1] end} end
function fixture(personId)
    personId=personId or 'a'
    if SAO.ResourceProduction then SAO.ResourceProduction.reset() end
    local production,planner,labor,controller=SAO.ResourceProduction,SAO.ProceduralPlanning,SAO.Labor,SAO.Controller
    local models,cognition,cooking,pharmacology=SAO.CognitiveModels,SAO.Cognition,SAO.Cooking,SAO.Pharmacology
    local locomotion=SAO.Locomotion
    local organization=SAO.Organization
    F={at=10,private=true,allowed=true,reachable=true,sourceValid=true,queueAccept=true,cancelAccept=true,
        sourceRevision='r1',transferCalls=0,queueCalls=0,routeCalls=0,capacity=2,amount=0,sourceAmount=4}
    F.rec={id=personId,bodyOwnerToken='owned-a'} F.requester={id='b'} F.inventory={setDrawDirty=function() end}
    F.fluid={getAmount=function() return F.amount end,getCapacity=function() return F.capacity end,
        isWaterSource=function() return F.amount>0 and not F.nonwater end,
        isPoisonous=function() return F.poison==true end,isTainted=function() return F.tainted==true end}
    F.item={kind='InventoryItem',getID=function() return 51 end,getFullType=function() return 'Base.WaterBottle' end,
        getContainer=function() return F.itemLost and nil or F.inventory end,
        canStoreWater=function() return not F.notVessel end,getFluidContainer=function() return F.fluid end,
        getFluidContainerFromSelfOrWorldItem=function() return F.fluid end,isEquipped=function() return false end,
        syncItemFields=function() end,setBeingFilled=function() end,setJobDelta=function() end}
    F.body={data={SAOPersonId=personId,SAOExternalToken='owned-a'},getModData=function(self) return self.data end,
        getInventory=function() return F.inventory end,getCurrentSquare=function() return {} end,
        isExistInTheWorld=function() return true end,isDead=function() return false end,isAsleep=function() return false end,
        getVehicle=function() end,isAttacking=function() return false end,isAiming=function() return false end,
        isClimbing=function() return false end,isClimbingRope=function() return false end,
        getX=function() return 1.5 end,getY=function() return 1.5 end,getZ=function() return 0 end,
        getFreeInventoryCapacity=function() return F.freeCapacity or 10 end,isEquippedClothing=function() return false end,
        isTimedActionInstant=function() return false end,hasFullInventory=function() return false end,
        getBodyDamage=function() return {getOverallBodyHealth=function() return F.health or 100 end} end,setIsFarming=function() end}
    F.fixture={getFluidAmount=function() return F.sourceAmount end,hasFluid=function() return F.sourceAmount>0 end,
        transferFluidTo=function(self,fluid,amount)
            F.transferCalls=F.transferCalls+1
            if F.noTransfer then return end
            local gain=math.min(amount,F.sourceAmount,F.capacity-F.amount)
            F.sourceAmount=F.sourceAmount-gain F.amount=F.amount+gain
        end}
    F.fact={id='F:known-tap',kind='fluid',state='available',fingerprint='fp1',revision='r1',x=2,y=1,z=0,
        explored=true,quantities={water=4}}
    F.belief={cx=2,cy=1,z=0,minX=0,maxX=4,minY=0,maxY=4,sources={water=true},
        sourceRevision='F:known-tap@r1',sourceFacts={['F:known-tap']=F.fact}}
    SAO={ResourceProduction=production,ProceduralPlanning=planner,Labor=labor,Controller=controller or {agents={}},
        CognitiveModels=models,Cognition=cognition,Cooking=cooking or {},Pharmacology=pharmacology or {},
        Organization=organization,
        Identity={get=function(id) return id==personId and F.rec or id=='b' and F.requester end},
        Body={active={[personId]=F.body},foreign={},get=function(id) return id==personId and F.body end},
        History={countyHours=function() return F.at end},
        Perception={knownPlaces=function() return F.private and {[1]=F.belief} or {} end},
        Standing={mayTakeCurrent=function() return F.allowed end,mayAttemptBelieved=function() return F.allowed end},
        Disposition={eatAt=function() return .6 end,drinkAt=function() return .6 end},
        WorldSources={privatelyKnowsItem=function() return false end,actionOptions=function() end,inspectionCandidate=function() end},
        SourceUse={},Observation={record=function() end},Log={line=function() end},
        Needs={busy=function(body) local q=ISTimedActionQueue.queues[body] return q and #q.queue>0 or false end,
            read=function() return {hunger=F.hunger or 0,thirst=F.thirst or .3,fatigue=F.fatigue or 0} end,
            bleeding=function() return F.bleeding or 0 end,
            portableWaterItem=function(item) return __portableWaterItem(item) end,
            queueVerified=function(action) ISTimedActionQueue.add(action) return ISTimedActionQueue.hasAction(action) end},
        Locomotion=locomotion or {jobs={}}}
    SAO.Locomotion.jobs={}
    if organization then organization.processes={} organization.processOrder={} organization.processMeta={sequence=0} end
    SAO.Controller.agents={[personId]={rec=F.rec,state='IDLE'}}
    local store={settings={enabled=true,opponentShare=.5,opportunitiesPerHour=12,maxDepth=3}}
    ModData={get=function() return store end,getOrCreate=function() return store end}
    SAOJavaBridge={isShell=function() return not F.fake end,privateCarriedItems=function() return list({F.item}) end,
        worldRefillTarget=function(self,body,id,fp,revision) return F.sourceValid and revision==F.sourceRevision and 'READY:1:1:0' or 'REVISION_CHANGED' end,
        worldRefillObject=function(self,body,id,fp,revision) return F.sourceValid and F.reachable and revision==F.sourceRevision and F.fixture or nil end,
        worldRefillValid=function(self,body,object) return F.sourceValid and F.reachable and object==F.fixture end,
        moveTo=function() F.routeCalls=F.routeCalls+1 return not F.routeRefused and 'MOVE_STARTED' or 'FAILED' end,
        tickMove=function() if F.arrived then F.reachable=true return 'Succeeded' end return 'Working' end,
        cancelMove=function() return F.routeCancelRefused and 'CANCEL_FAILED controlled' or 'MOVE_CANCELLED' end,
        findCarriedFood=function() return F.readyFood end}
    ISTimedActionQueue={queues={},hasAction=function(action)
        for _,member in ipairs((ISTimedActionQueue.queues[action.character] or {}).queue or {}) do
            if action==member then return true end end return false end,
        add=function(action)
            F.queueCalls=F.queueCalls+1 if not F.queueAccept then return end
            local queue={queue={action}} ISTimedActionQueue.queues[action.character]=queue
            F.action=action action.action={forceStop=function()
                if F.cancelAccept then action:stop() end end}
            queue.resetQueue=function() queue.queue={} end queue.onCompleted=function() queue.queue={} end
        end,
        getTimedActionQueue=function(body) return ISTimedActionQueue.queues[body] end}
    return F.body,SAO.Controller.agents[personId]
end
'''
CASES = r'''
local checks={}
local function check(name,value) checks[#checks+1]=name..'='..tostring(value==true) end
local R,P,Ctl=SAO.ResourceProduction,SAO.ProceduralPlanning,SAO.Controller
local function begin()
    local body,agent=fixture()
    local started=Ctl.advanceResourcePurpose('a',agent,body,100,{hunger=0,thirst=.3,fatigue=0})
    local purpose,step=P.resourceDemand('a','water')
    return started,purpose,step,body,agent
end
local started,purpose,step=begin()
check('private_sink_empty_vessel_drives_real_native_action',started and F.action and F.action.item==F.item
    and F.action.waterObject==F.fixture and step.owner=='SAO.ResourceProduction' and F.transferCalls==0)
if not started then __productionResults=table.concat(checks,'\n') return end
check('queued_refill_is_not_goal_completion',purpose.status~='completed' and purpose.admission~=nil and F.amount==0)
F.action:updateUse(.5)
check('native_incremental_transfer_is_real_owned_water',F.amount==1 and F.transferCalls==1 and purpose.status~='completed')
F.action:complete() F.action:perform() R.tick('a',F.body)
local outcome=F.rec.resourceProductionOutcomes[1]
check('actual_water_transfer_completes_exact_maintained_goal',purpose.status=='completed' and outcome.nativeGain==2
    and outcome.nativeCredit==outcome.id and outcome.held and outcome.clean and outcome.purposeDelivered)
check('native_refill_teaches_both_independent_models',F.rec.cognition and F.rec.cognition.models.ordinary.revision>0
    and F.rec.cognition.models.associative.revision>0 and #F.rec.cognition.experiences==1 and outcome.experienceDelivered)
local event=F.rec.cognition and F.rec.cognition.experiences[1]
check('filled_water_is_acquisition_without_thirst_relief',event and event.kind=='acquire' and event.category=='water'
    and event.thirstDelta==nil and event.hungerDelta==nil and event.detail=='native-vessel-water-fill'
    and outcome.cognitiveToken and outcome.cognitiveToken.producer=='ResourceProduction')
check('production_receipt_is_exact_once',R.tick('a',F.body)=='idle' and #F.rec.resourceProductionOutcomes==1)
check('cognitive_receipt_replay_is_exact_once',R.onOutcome('a',outcome) and #F.rec.cognition.experiences==1
    and F.rec.cognition.models.ordinary.revision==1 and F.rec.cognition.models.associative.revision==1)
fixture() F.private=false
check('foreign_observer_source_is_not_a_private_option',#R.options('a',F.body,'water')==0)
fixture() local option=R.options('a',F.body,'water')[1] F.belief.sourceRevision='F:known-tap@r2'
check('exact_private_revision_independently_gates_option',not R.privatelyKnown('a',option))
fixture() F.fact.revision='r2' F.belief.sourceRevision='F:known-tap@r2'
local option=R.options('a',F.body,'water')[1]
check('stale_native_fixture_revision_refuses_before_queue',not R.begin('a',F.body,option,{purposeId='missing',purposeStepId='missing'}) and F.queueCalls==0)
fixture() F.notVessel=true
check('non_vessel_cannot_be_an_invented_water_tool',#R.options('a',F.body,'water')==0)
fixture() F.amount=.5 F.nonwater=true
check('nonwater_held_fluid_is_not_a_refill_option',#R.options('a',F.body,'water')==0)
fixture() F.tainted=true
check('tainted_held_vessel_is_not_a_refill_option',#R.options('a',F.body,'water')==0)
fixture() F.fake=true
check('fake_body_cannot_execute_refill',#R.options('a',F.body,'water')==0)
started,purpose=begin() F.action:complete() F.action:perform() F.amount=0 R.tick('a',F.body)
check('lost_filled_item_gain_never_completes_goal',purpose.status~='completed' and not purpose.admission)
started,purpose=begin() F.noTransfer=true F.action:complete() F.action:perform() R.tick('a',F.body)
check('native_complete_without_gain_fails_and_clears_admission',purpose.status~='completed' and not purpose.admission
    and F.rec.resourceProductionOutcomes[1].status=='failed')
check('failed_fill_censors_without_success_association',F.rec.cognition and #F.rec.cognition.experiences==1
    and F.rec.cognition.experiences[1].status=='unavailable' and F.rec.cognition.models.ordinary.revision==0
    and F.rec.cognition.models.associative.revision==0)
started,purpose=begin() F.amount=2 F.noTransfer=true F.action:complete() F.action:perform() R.tick('a',F.body)
check('unrelated_fluid_gain_cannot_create_native_credit',purpose.status~='completed'
    and F.rec.resourceProductionOutcomes[1].nativeGain==0 and not purpose.admission)
started,purpose=begin() F.action:updateUse(.25) R.interrupt('a',F.body,'danger')
check('interrupted_partial_water_is_evidence_without_goal_credit',F.amount==.5 and not F.rec.resourceProductionWork
    and purpose.status~='completed' and not purpose.admission and F.rec.resourceProductionOutcomes[1].nativeGain==.5
    and F.rec.resourceProductionOutcomes[1].status=='interrupted')
check('interrupted_fill_does_not_teach_success',F.rec.cognition and F.rec.cognition.models.ordinary.revision==0
    and F.rec.cognition.models.associative.revision==0 and F.rec.cognition.experiences[1].status=='interrupted')
started,purpose=begin() F.cancelAccept=false
check('refused_native_cancellation_keeps_body_and_admission',not R.interrupt('a',F.body,'danger')
    and F.rec.resourceProductionWork~=nil and purpose.admission~=nil and SAO.Needs.busy(F.body))
F.cancelAccept=true R.interrupt('a',F.body,'danger')
check('later_cancellation_closes_same_attempt_once',F.rec.resourceProductionWork==nil and #F.rec.resourceProductionOutcomes==1 and not purpose.admission)
started,purpose=begin() F.sourceValid=false F.action:complete() F.action:perform() R.tick('a',F.body)
check('changed_source_identity_cannot_transfer_or_complete',F.transferCalls==0 and purpose.status~='completed' and not purpose.admission)
started,purpose=begin() F.allowed=false F.action:updateUse(1) F.action:complete() F.action:perform() R.tick('a',F.body)
check('current_permission_refusal_blocks_actual_native_transfer',F.transferCalls==0 and purpose.status~='completed' and not purpose.admission)
fixture() local body,agent=F.body,SAO.Controller.agents.a F.reachable=false
started=Ctl.advanceResourcePurpose('a',agent,body,100,{hunger=0,thirst=.3,fatigue=0})
purpose=P.resourceDemand('a','water')
check('native_route_is_admission_without_water_credit',started and F.routeCalls==1 and F.queueCalls==0 and purpose.admission~=nil)
local routePending=R.tick('a',body)=='moving' and F.rec.resourceProductionWork~=nil
    and not SAO.Locomotion.jobs.a.done and F.queueCalls==0
check('real_locomotion_pending_job_keeps_production_route',routePending)
if not routePending then __productionResults=table.concat(checks,'\n') return end
F.arrived=true R.tick('a',body) F.action:complete() F.action:perform() R.tick('a',body)
check('arrival_then_native_refill_finishes_same_goal',purpose.status=='completed' and F.transferCalls>0)
fixture() body,agent=F.body,SAO.Controller.agents.a F.queueAccept=false
started=Ctl.advanceResourcePurpose('a',agent,body,100,{hunger=0,thirst=.3,fatigue=0})
purpose=P.resourceDemand('a','water')
check('queue_refusal_does_not_leave_admission_or_owner',not started and not F.rec.resourceProductionWork and not purpose.admission)
started,purpose=begin() local action=F.action
action:complete() action:perform() R.tick('a',F.body)
local saved=F.rec.resourceProductionOutcomes[1]
check('caller_cannot_fabricate_completed_production_receipt',not P.consumeProductionResult('a',{id='forged',purposeId=purpose.id}))
check('caller_cannot_fabricate_cognitive_production_receipt',not R.onOutcome('a',{id='forged',status='completed'}))
saved.experienceDelivered=false saved.status='pending'
check('pending_native_result_never_enters_cognition',not R.onOutcome('a',saved) and #F.rec.cognition.experiences==1)
saved.status='completed' saved.nativeGain=0
check('unproven_native_gain_never_enters_cognition',not R.onOutcome('a',saved) and #F.rec.cognition.experiences==1)
started,purpose=begin() local callback=R.onOutcome R.onOutcome=function() return false end
F.action:complete() F.action:perform() R.tick('a',F.body)
local pending=F.rec.resourceProductionOutcomes[1]
local failedDelivery=not pending.experienceDelivered and #F.rec.cognition.experiences==0
R.onOutcome=callback R.tick('a',F.body)
check('cognitive_delivery_retries_canonical_receipt',failedDelivery and pending.experienceDelivered
    and #F.rec.cognition.experiences==1 and F.rec.cognition.models.associative.revision==1)
started,purpose=begin() local firstId=F.rec.resourceProductionWork.id
R.interrupt('a',F.body,'finished test')
local body,agent=fixture('b') Ctl.advanceResourcePurpose('b',agent,body,100,{hunger=0,thirst=.3,fatigue=0})
check('different_actors_have_distinct_native_work_ids',F.rec.resourceProductionWork.id~=firstId
    and firstId=='resource-production/a/1' and F.rec.resourceProductionWork.id=='resource-production/b/1')
fixture() SAO.Locomotion.order('a',F.body,4,4,0)
local retained=SAO.Locomotion.jobs.a
local option=R.options('a',F.body,'water')[1]
check('unrelated_live_route_cannot_be_adopted_as_refill',not R.begin('a',F.body,option,{})
    and SAO.Locomotion.jobs.a==retained and F.queueCalls==0)
local Org=SAO.Organization
local function shared(due)
    local process=Org.raiseMatter('b','cooperative-action',nil,{cooperative=true,procedure={
        {id='first',verb='move',domain='movement',capability='move',completesOn='route:arrived',target={x=3,y=3,z=0}},
        {id='second',verb='move',domain='movement',capability='move',dependsOn={'first'},completesOn='route:arrived',target={x=4,y=4,z=0}}
    }},{'a'},{})
    Org.recordReception(process.id,'a',1,'controlled-native-transport','b',{})
    Org.respond(process.id,'a','accept',{stepIds={due}},{capabilities={move=true,execute=true},canExecute=true})
    Org.deliverResponse(process.id,'a','b','controlled-native-return',{})
    return Org.activeCommitment('a')
end
started,purpose,step,body,agent=begin() shared('first')
resourceOwnerTick('a',agent,body,100)
check('actual_accepted_ready_shared_work_preempts_refill',not F.rec.resourceProductionWork
    and agent.state=='IDLE' and F.rec.resourceProductionOutcomes[1].detail=='accepted-work-interrupted')
started,purpose,step,body,agent=begin() local commitment=shared('second')
resourceOwnerTick('a',agent,body,100)
check('accepted_dependency_blocked_work_preserves_refill',F.rec.resourceProductionWork~=nil and #(F.rec.resourceProductionOutcomes or {})==0)
started,purpose,step,body,agent=begin() commitment=shared('first') commitment.work.pendingReceiptId='prior-native-action'
resourceOwnerTick('a',agent,body,100)
check('pending_shared_native_receipt_preserves_refill',F.rec.resourceProductionWork~=nil and #(F.rec.resourceProductionOutcomes or {})==0)
started,purpose,step,body,agent=begin() commitment=shared('first') commitment.work.owner='Locomotion'
resourceOwnerTick('a',agent,body,100)
check('actual_locomotion_shared_owner_can_preempt_refill',F.rec.resourceProductionWork==nil)
started,purpose,step,body,agent=begin() commitment=shared('first') commitment.work.owner='ZAO.Driver'
resourceOwnerTick('a',agent,body,100)
check('foreign_shared_executor_preserves_refill',F.rec.resourceProductionWork~=nil)
body,agent=fixture() F.reachable=false F.thirst=.75
started=Ctl.advanceResourcePurpose('a',agent,body,100,{hunger=0,thirst=.75,fatigue=0})
local work=F.rec.resourceProductionWork local ownRoute=SAO.Locomotion.jobs.a
resourceOwnerTick('a',agent,body,100)
check('urgent_water_route_survives_its_initiating_thirst',started and F.rec.resourceProductionWork==work
    and SAO.Locomotion.jobs.a==ownRoute and not ownRoute.done and F.routeCalls==1
    and #(F.rec.resourceProductionOutcomes or {})==0)
F.arrived=true resourceOwnerTick('a',agent,body,160)
check('urgent_thirst_route_reaches_same_native_fill_action',F.rec.resourceProductionWork==work
    and F.action and F.action.item==F.item and work.stage=='filling')
if F.action then F.action:updateUse(.5) end resourceOwnerTick('a',agent,body,220)
check('bound_partial_water_keeps_exact_native_fill_owner',F.rec.resourceProductionWork==work
    and agent.state=='RESOURCE' and F.amount==1 and #(F.rec.resourceProductionOutcomes or {})==0)
if F.action then F.action:complete() F.action:perform() end resourceOwnerTick('a',agent,body,280)
check('urgent_water_owner_reaches_canonical_native_completion',not F.rec.resourceProductionWork
    and F.amount==2 and F.rec.resourceProductionOutcomes[1].status=='completed'
    and F.rec.resourceProductionOutcomes[1].nativeCredit==work.id)
body,agent=fixture() F.reachable=false F.thirst=.75
Ctl.advanceResourcePurpose('a',agent,body,100,{hunger=0,thirst=.75,fatigue=0})
F.hunger=.7
resourceOwnerTick('a',agent,body,100)
check('unrelated_urgent_hunger_interrupts_water_production',not F.rec.resourceProductionWork
    and F.rec.resourceProductionOutcomes[1].detail=='bodily-need-interrupted')
body,agent=fixture() F.reachable=false F.thirst=.75 F.bleeding=1
Ctl.advanceResourcePurpose('a',agent,body,100,{hunger=0,thirst=.75,fatigue=0})
resourceOwnerTick('a',agent,body,100)
check('bleeding_still_preempts_serving_water_route',not F.rec.resourceProductionWork)
body,agent=fixture() F.reachable=false F.thirst=.75 F.fatigue=.8 F.routeCancelRefused=true
Ctl.advanceResourcePurpose('a',agent,body,100,{hunger=0,thirst=.75,fatigue=0})
work=F.rec.resourceProductionWork ownRoute=SAO.Locomotion.jobs.a
resourceOwnerTick('a',agent,body,100)
check('refused_native_water_route_cancel_preserves_exact_owner',F.rec.resourceProductionWork==work
    and SAO.Locomotion.jobs.a==ownRoute and agent.state=='RESOURCE'
    and #(F.rec.resourceProductionOutcomes or {})==0)
F.routeCancelRefused=false resourceOwnerTick('a',agent,body,160)
check('acknowledged_water_route_cancel_retires_once',not F.rec.resourceProductionWork
    and not SAO.Locomotion.jobs.a and #F.rec.resourceProductionOutcomes==1)
body,agent=fixture() F.reachable=false F.thirst=.75 F.hunger=.7
Ctl.advanceResourcePurpose('a',agent,body,100,{hunger=.7,thirst=.75,fatigue=0})
work=F.rec.resourceProductionWork
resourceOwnerTick('a',agent,body,100) resourceOwnerTick('a',agent,body,160)
check('simultaneous_appraised_pressure_without_food_preserves_feasible_water_route',F.rec.resourceProductionWork==work
    and work.admittedNeeds.hunger==.7 and F.routeCalls==1 and #(F.rec.resourceProductionOutcomes or {})==0)
F.arrived=true resourceOwnerTick('a',agent,body,220)
if F.action then F.action:updateUse(.5) end resourceOwnerTick('a',agent,body,280)
check('simultaneous_pressure_preserves_exact_partial_vessel_and_action',F.rec.resourceProductionWork==work
    and F.amount==1 and F.action and ISTimedActionQueue.hasAction(F.action))
F.readyFood={id='actual-carried-ready-food'} resourceOwnerTick('a',agent,body,340)
check('distinct_native_ready_food_admits_competing_need',not F.rec.resourceProductionWork
    and F.rec.resourceProductionOutcomes[1].status=='interrupted')
body,agent=fixture() F.thirst=.75
Ctl.advanceResourcePurpose('a',agent,body,100,{hunger=0,thirst=.75,fatigue=0})
F.action:updateUse(.5)
local distinctFluid={getAmount=function() return 1 end,isWaterSource=function() return true end,
    isPoisonous=function() return false end,isTainted=function() return false end}
local otherWater={getFluidContainerFromSelfOrWorldItem=function() return distinctFluid end,
    getID=function() return 52 end,getFullType=function() return 'Base.WaterBottle' end,
    getContainer=function() return F.inventory end}
SAOJavaBridge.privateCarriedItems=function() return {size=function() return 2 end,
    get=function(self,index) return index==0 and F.item or otherWater end} end
resourceOwnerTick('a',agent,body,100)
check('distinct_native_ready_water_releases_immediate_relief',not F.rec.resourceProductionWork
    and F.rec.resourceProductionOutcomes[1].status=='interrupted')
body,agent=fixture() F.reachable=false F.thirst=.75 F.hunger=.7
Ctl.advanceResourcePurpose('a',agent,body,100,{hunger=.7,thirst=.75,fatigue=0}) F.hunger=.9
resourceOwnerTick('a',agent,body,100)
check('new_severe_hunger_reconsiders_the_admitted_water_plan',not F.rec.resourceProductionWork)
body,agent=fixture() F.reachable=false F.thirst=.75
Ctl.advanceResourcePurpose('a',agent,body,100,{hunger=0,thirst=.75,fatigue=0}) F.health=95
resourceOwnerTick('a',agent,body,100)
check('new_native_damage_preempts_the_resource_owner',not F.rec.resourceProductionWork)
__productionResults=table.concat(checks,'\n')
'''
CONTROLS = [
    ('production', 'admitted(belief, option.sourceId, option.sourceRevision)', 'true', 'exact_private_revision_independently_gates_option'),
    ('production', 'or gain <= 0.0001 or after <= work.beforeAmount + 0.0001', 'or after <= work.beforeAmount + 0.0001', 'unrelated_fluid_gain_cannot_create_native_credit'),
    ('production', 'return permission(work.actorId, work) and SAOJavaBridge:worldRefillValid', 'return SAOJavaBridge:worldRefillValid', 'current_permission_refusal_blocks_actual_native_transfer'),
    ('production', 'if queued(rt.action) then return false end', 'if false then return false end', 'refused_native_cancellation_keeps_body_and_admission'),
    ('controller', 'context.productionOptions = SAO.ResourceProduction and SAO.ResourceProduction.options(id, body, category) or {}', 'context.productionOptions = {}', 'private_sink_empty_vessel_drives_real_native_action'),
    ('production', 'if not rt.route.done then return "moving" end', 'if false then return "moving" end', 'real_locomotion_pending_job_keeps_production_route'),
    ('controller', 'organization.workPlan(commitment.id, id)', 'organization.workPlan(id, commitment.id)', 'actual_accepted_ready_shared_work_preempts_refill'),
    ('controller', 'and not (commitment.work and commitment.work.pendingReceiptId)', 'and not (commitment.work and commitment.work.nativeReceiptPending)', 'pending_shared_native_receipt_preserves_refill'),
    ('controller', 'or commitment.work.owner == "Locomotion")', 'or commitment.work.owner == "SAO.Locomotion")', 'actual_locomotion_shared_owner_can_preempt_refill'),
    ('production','and not R.servesNeed(id, body, "water")',
     'and true','urgent_water_route_survives_its_initiating_thirst'),
    ('production','if not fillingOwnVessel and SAO.Needs.portableWaterItem(item) then return false end',
     'if SAO.Needs.portableWaterItem(item) then return false end','bound_partial_water_keeps_exact_native_fill_owner'),
    ('production','if not ok or cancelled ~= "MOVE_CANCELLED" then return false end',
     'if false then return false end','refused_native_water_route_cancel_preserves_exact_owner'),
    ('production','prior.hunger < SAO.Disposition.eatAt(id)',
     'true','simultaneous_appraised_pressure_without_food_preserves_feasible_water_route'),
]
RELOAD_BEFORE = r'''
fixture()
Ctl=SAO.Controller
Ctl.advanceResourcePurpose('a',SAO.Controller.agents.a,F.body,100,{hunger=0,thirst=.3,fatigue=0})
__reloadPurpose=SAO.ProceduralPlanning.resourceDemand('a','water')
F.action:updateUse(.25) F.cancelAccept=false
'''
RELOAD_AFTER = r'''
local result=SAO.ResourceProduction.tick('a',F.body)
local kept=result=='cancelling' and F.rec.resourceProductionWork~=nil and __reloadPurpose.admission~=nil
F.cancelAccept=true result=SAO.ResourceProduction.tick('a',F.body)
local closed=result=='failed' and F.rec.resourceProductionWork==nil and __reloadPurpose.admission==nil
    and __reloadPurpose.status~='completed' and F.amount==.5 and not SAO.Needs.busy(F.body)
__productionResults='reload_refused_cancellation_preserves_native_owner='..tostring(kept)
    ..'\nreload_missing_native_credit_closes_as_failed='..tostring(closed)
'''

REFRESH_FIXTURE = r'''
local baseFixture=fixture
local W,M=SAO.WorldSources,SAO.Perception
function fixture(outdoor)
    local body,agent=baseFixture()
    SAO.WorldSources,SAO.Perception=W,M
    local stores={SurvivorAwareness_Cognition={settings={enabled=true,opponentShare=.5,opportunitiesPerHour=12,maxDepth=3}}}
    ModData={get=function(key) return stores[key] end,getOrCreate=function(key)
        stores[key]=stores[key] or {} return stores[key] end}
    M.beliefs={} M.beliefVersion=0
    F.observeCalls=0 F.revisionSequence=1 F.otherRevision='u1'
    local placeId=outdoor and 'source:F:known-tap' or 1
    F.belief.id=placeId F.belief.sourceId=outdoor and 'F:known-tap' or nil
    M.beliefs.a={known={[placeId]=F.belief}}
    -- Independent detached memories are essential: physical ledger changes
    -- may be global, but only actual personal handling updates this mind.
    local peer={id=placeId,cx=2,cy=1,z=0,minX=0,maxX=4,minY=0,maxY=4,
        sourceId=F.belief.sourceId,sourceRevision='F:known-tap@r1',sourceFacts={}}
    M.beliefs.b={known={[placeId]=peer}}
    SAOJavaBridge.observeWorldChunk=function(self,cx,cy)
        F.observeCalls=F.observeCalls+1
        if F.observeUnavailable then return 'H|protocol=SAOWS1|status=UNAVAILABLE|cx=0|cy=0|sources=0\nE' end
        return 'H|protocol=SAOWS1|status=OBSERVED|detail=|mode=loaded|cx=0|cy=0|sources=2\n'
            ..'S|id=F:known-tap|fp=fp1|rev='..F.sourceRevision..'|kind=fluid|x=2|y=1|z=0|building='
            ..(outdoor and '-1' or '1')..'|explored=1|state=available|access=unknown|container=sink|q:water='..F.sourceAmount..'\n'
            ..'I|source=F:known-tap|id=0|type=|uses=0|amount='..F.sourceAmount..'|fluid=Water|poison=0|rotten=0|cats=water\n'
            ..'S|id=F:other-tap|fp=fp-other|rev='..F.otherRevision..'|kind=fluid|x=3|y=1|z=0|building=1|explored=1|state=available|access=unknown|container=sink|q:water=5\n'
            ..'I|source=F:other-tap|id=0|type=|uses=0|amount=5|fluid=Water|poison=0|rotten=0|cats=water\nE'
    end
    assert(W.observeChunk(0,0))
    F.belief.sourceFacts['F:known-tap']=W.beliefFact('F:known-tap')
    peer.sourceFacts['F:known-tap']=W.beliefFact('F:known-tap')
    F.belief.sourceFacts['F:other-tap']=W.beliefFact('F:other-tap')
    F.belief.sourceRevision='F:known-tap@r1,F:other-tap@u1'
    F.peer=peer F.placeId=placeId
    local transfer=F.fixture.transferFluidTo
    F.fixture.transferFluidTo=function(self,fluid,amount)
        local before=F.sourceAmount transfer(self,fluid,amount)
        if F.sourceAmount~=before then
            F.revisionSequence=F.revisionSequence+1 F.sourceRevision='r'..tostring(F.revisionSequence)
        end
    end
    return body,agent
end
function beginPrivateRefill(outdoor)
    local body,agent=fixture(outdoor)
    local options=SAO.ResourceProduction.options('a',body,'water')
    local chosen
    for _,option in ipairs(options) do if option.sourceId=='F:known-tap' then chosen=option break end end
    local context={category='water',pressure=.3,atHours=F.at,needs={fatigue=0,health=1},
        carriedReady=0,carriedRaw=0,carriedWater=0,carriedItems=1,sources={},productionOptions={chosen}}
    local purpose,step=SAO.ProceduralPlanning.planResource('a',context)
    assert(purpose and step and step.owner=='SAO.ResourceProduction')
    assert(SAO.ResourceProduction.begin('a',body,step,{purposeId=purpose.id,purposeStepId=step.id}))
    return purpose,step
end
'''
REFRESH_CASES = r'''
local checks={}
local function check(name,value) checks[#checks+1]=name..'='..tostring(value==true) end
local R,P,W,M=SAO.ResourceProduction,SAO.ProceduralPlanning,SAO.WorldSources,SAO.Perception
local function complete()
    F.action:complete() F.action:perform() R.tick('a',F.body)
    return F.rec.resourceProductionOutcomes[#F.rec.resourceProductionOutcomes]
end
local purpose,step=beginPrivateRefill()
check('private_place_is_detached_and_durable',F.rec.resourceProductionWork.place~=step.place
    and F.rec.resourceProductionWork.place.id==F.placeId and F.rec.resourceProductionWork.sourceChunkX==0)
F.otherRevision='u2'
local receipt=complete()
check('bound_fill_refreshes_actual_actor_source_revision',receipt.status=='completed'
    and receipt.sourceObservation.status=='confirmed' and receipt.sourceObservation.revision==F.sourceRevision
    and receipt.sourceRevision=='r1' and F.belief.sourceFacts['F:known-tap'].revision==F.sourceRevision
    and F.belief.sourceFacts['F:known-tap'].quantities.water==2)
check('handled_refresh_leaves_peer_and_unhandled_memories_private',F.peer.sourceFacts['F:known-tap'].revision=='r1'
    and F.peer.sourceFacts['F:known-tap'].quantities.water==4
    and F.belief.sourceFacts['F:other-tap'].revision=='u1' and W.beliefFact('F:other-tap').revision=='u2')
F.amount=0 F.at=F.at+1
local options=R.options('a',F.body,'water') local own
for _,candidate in ipairs(options) do if candidate.sourceId=='F:known-tap' then own=candidate break end end
local nextPurpose,nextStep=P.planResource('a',{category='water',pressure=.3,atHours=F.at,
    needs={fatigue=0,health=1},carriedWater=0,sources={},productionOptions={own}})
local second=nextStep and R.begin('a',F.body,nextStep,{purposeId=nextPurpose.id,purposeStepId=nextStep.id})
if second then complete() end
check('second_native_fill_uses_new_personal_revision',second==true and F.amount==2
    and #F.rec.resourceProductionOutcomes==2 and F.rec.resourceProductionOutcomes[2].status=='completed'
    and F.peer.sourceFacts['F:known-tap'].revision=='r1')
purpose,step=beginPrivateRefill() F.action:updateUse(.25) R.interrupt('a',F.body,'danger')
receipt=F.rec.resourceProductionOutcomes[1]
check('partial_interruption_refreshes_without_completion_credit',receipt.status=='interrupted' and not receipt.nativeCredit
    and purpose.status~='completed' and receipt.sourceObservation.status=='confirmed'
    and F.belief.sourceFacts['F:known-tap'].revision==F.sourceRevision
    and F.belief.sourceFacts['F:known-tap'].quantities.water==3.5 and F.peer.sourceFacts['F:known-tap'].revision=='r1')
beginPrivateRefill() F.noTransfer=true F.sourceRevision='r2' F.action:complete() F.action:perform() R.tick('a',F.body)
check('no_native_gain_cannot_refresh_private_fixture_memory',F.observeCalls==1
    and F.belief.sourceFacts['F:known-tap'].revision=='r1')
beginPrivateRefill() R.tick('a',F.body)
check('queued_action_cannot_refresh_private_source_memory',F.observeCalls==1 and F.belief.sourceFacts['F:known-tap'].revision=='r1')
fixture() F.reachable=false
local option
for _,candidate in ipairs(R.options('a',F.body,'water')) do if candidate.sourceId=='F:known-tap' then option=candidate break end end
local remotePurpose,remoteStep=P.planResource('a',{category='water',pressure=.3,atHours=F.at,needs={},carriedWater=0,sources={},productionOptions={option}})
R.begin('a',F.body,remoteStep,{purposeId=remotePurpose.id,purposeStepId=remoteStep.id})
R.interrupt('a',F.body,'route-refused')
check('unexecuted_remote_approach_cannot_reveal_fixture_contents',F.observeCalls==1
    and F.belief.sourceFacts['F:known-tap'].revision=='r1')
beginPrivateRefill() F.action:updateUse(.25) F.sourceValid=false R.interrupt('a',F.body,'replaced-fixture')
receipt=F.rec.resourceProductionOutcomes[1]
check('changed_fixture_blocks_handled_source_refresh',F.observeCalls==1 and receipt.sourceObservation.status=='unconfirmed'
    and F.belief.sourceFacts['F:known-tap'].revision=='r1')
beginPrivateRefill() F.observeUnavailable=true receipt=complete()
R.tick('a',F.body) R.options('a',F.body,'water') local count=F.observeCalls
R.tick('a',F.body) R.options('a',F.body,'water')
check('unavailable_handled_observation_retries_are_bounded',receipt.sourceObservation.status=='unconfirmed'
    and receipt.sourceObservation.attempts==3 and F.observeCalls==count and count==4
    and F.belief.sourceFacts['F:known-tap'].revision=='r1')
beginPrivateRefill() F.observeUnavailable=true receipt=complete()
F.observeUnavailable=false R.tick('a',F.body)
check('transient_observation_retries_only_same_handled_source',receipt.sourceObservation.status=='confirmed'
    and receipt.sourceObservation.attempts==2 and F.belief.sourceFacts['F:known-tap'].revision==F.sourceRevision
    and F.peer.sourceFacts['F:known-tap'].revision=='r1')
beginPrivateRefill() F.observeUnavailable=true receipt=complete()
F.observeUnavailable=false F.reachable=false R.tick('a',F.body)
check('leaving_fixture_retires_unconfirmed_refresh',receipt.sourceObservation.status=='unconfirmed'
    and receipt.sourceObservation.detail=='handled-source-no-longer-accessible' and F.observeCalls==2
    and F.belief.sourceFacts['F:known-tap'].revision=='r1')
purpose,step=beginPrivateRefill(true) receipt=complete()
check('outdoor_source_anchor_survives_native_refill_refresh',receipt.place.sourceId=='F:known-tap'
    and receipt.sourceObservation.status=='confirmed' and F.belief.sourceFacts['F:known-tap'].revision==F.sourceRevision
    and F.belief.sourceId=='F:known-tap' and M.knownPlaces('a',false)[F.placeId]==nil)
beginPrivateRefill() F.observeUnavailable=true receipt=complete()
R.detach('a',F.body,'death') F.observeUnavailable=false R.tick('a',F.body)
check('retirement_releases_unconfirmed_native_source_handles',receipt.sourceObservation.detail=='handled-source-body-retired'
    and receipt.sourceObservation.status=='unconfirmed' and F.observeCalls==2
    and F.belief.sourceFacts['F:known-tap'].revision=='r1')
beginPrivateRefill() F.action:updateUse(.25) F.observeUnavailable=true R.detach('a',F.body,'death')
receipt=F.rec.resourceProductionOutcomes[1] F.observeUnavailable=false R.tick('a',F.body)
check('active_partial_retirement_releases_new_observation_retry',receipt.status=='interrupted'
    and receipt.sourceObservation.detail=='handled-source-body-retired' and F.observeCalls==2
    and F.belief.sourceFacts['F:known-tap'].revision=='r1')
local outcomeCount=#F.rec.resourceProductionOutcomes local experienceCount=#F.rec.cognition.experiences
canonicalProductionDeathCleanup('a') R.detach('a',F.body,'death') R.tick('a',F.body)
check('canonical_death_and_controller_detach_are_exact_once',#F.rec.resourceProductionOutcomes==outcomeCount
    and #F.rec.cognition.experiences==experienceCount and F.observeCalls==2)
beginPrivateRefill() F.observeUnavailable=true receipt=complete()
R.reset() F.observeUnavailable=false R.tick('a',F.body)
check('world_reset_releases_unconfirmed_native_source_handles',receipt.sourceObservation.detail=='handled-source-observation-retired'
    and receipt.sourceObservation.status=='unconfirmed' and F.observeCalls==2)
beginPrivateRefill() F.observeUnavailable=true receipt=complete()
local dropped=SAO.Controller.drop('a') F.observeUnavailable=false R.tick('a',F.body)
check('controller_drop_retires_post_action_source_refresh',dropped and not SAO.Controller.agents.a
    and receipt.sourceObservation.detail=='handled-source-body-retired' and F.observeCalls==2)
__productionResults=table.concat(checks,'\n')
'''
REFRESH_CONTROLS = [
    ('production', 'pcall(learn, id, receipt.place, receipt.sourceId, tick, "observed-native-refill")',
     'pcall(learn, "b", receipt.place, receipt.sourceId, tick, "observed-native-refill")',
     'bound_fill_refreshes_actual_actor_source_revision'),
    ('production', 'or not physical(rt, receipt) then return stop("handled-source-no-longer-accessible")',
     'then return stop("handled-source-no-longer-accessible")', 'changed_fixture_blocks_handled_source_refresh'),
    ('production', 'if rt and gain > 0.0001 and rt.fixture then', 'if rt and rt.fixture then',
     'no_native_gain_cannot_refresh_private_fixture_memory'),
    ('production', 'sourceId = belief.sourceId, cx = belief.cx, cy = belief.cy, z = belief.z,\n        minX',
     'cx = belief.cx, cy = belief.cy, z = belief.z,\n        minX', 'outdoor_source_anchor_survives_native_refill_refresh'),
    ('production', 'retireRefresh(id, "handled-source-body-retired")', 'do end',
     'retirement_releases_unconfirmed_native_source_handles'),
    ('production', 'retireRefresh(id, "handled-source-body-retired")\n    return closed', 'do end\n    return closed',
     'active_partial_retirement_releases_new_observation_retry'),
    ('production', 'for id in pairs(sourceRefresh) do retireRefresh(id, "handled-source-observation-retired") end',
     'do end', 'world_reset_releases_unconfirmed_native_source_handles'),
    ('controller', 'SAO.ResourceProduction.detach(id, body, "controller-drop")', 'do end',
     'controller_drop_retires_post_action_source_refresh'),
]

def main():
    if not (GAME/'projectzomboid.jar').is_file() or not (JDK/'javac.exe').is_file():
        print('Border 219 SKIPPED: installed game VM and JDK absent')
        return 0
    texts={name:path.read_text(encoding='utf-8-sig') for name,path in FILES.items()}
    try:
        with tempfile.TemporaryDirectory(prefix='sao-resource-production-') as directory:
            work=Path(directory)
            shutil.copy2(GAME/'stdlib.lua',work/'stdlib.lua')
            build=subprocess.run([str(JDK/'javac.exe'),'-cp',str(GAME/'projectzomboid.jar'),'-d',str(work),
                str(ROOT/'tools/luacheck/LuaRun.java')],capture_output=True,text=True,timeout=60)
            if build.returncode: raise RuntimeError(build.stderr[-2500:])
            def run(changed=None,target=None,refresh=False):
                code=dict(texts); code.update(changed or {})
                paths=[]
                def add(name,text):
                    path=work/(name+'.lua');path.write_text(text,encoding='utf-8');paths.append(path)
                add('prelude',PRELUDE+'\nfixture()\n')
                predicate=function_body(code['needs'],'N.portableWaterItem')
                add('portable-water','local N={}\nfunction N.portableWaterItem('+predicate+'end\n__portableWaterItem=N.portableWaterItem\n')
                paths.extend([GAME/'media/lua/shared/ISBaseObject.lua',GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua',
                    GAME/'media/lua/shared/TimedActions/ISTakeWaterAction.lua'])
                for name in ['models','cognition','organization','labor','planner','locomotion','production','experience']: add(name,code[name])
                if refresh:
                    for name in ['sources','perception']: add(name,code[name])
                    add('refresh-fixture',REFRESH_FIXTURE)
                    death=code['identity'].split('    if SAO.ResourceProduction and SAO.ResourceProduction.detach then',1)[1].split('    end',1)[0]
                    add('canonical-production-death','function canonicalProductionDeathCleanup(id)\nlocal rec=SAO.Identity.get(id)\n'
                        +'if SAO.ResourceProduction and SAO.ResourceProduction.detach then'+death+'end\nend\n')
                    drop=code['controller'].split('function Ctl.drop(id)',1)[1].split('local setStateRef',1)[0]
                    add('drop-controller','local Ctl=SAO.Controller\nlocal clearLoadedContact=function() end\nlocal log=function() end\nfunction Ctl.drop(id)'+drop)
                add('controller',execution.controller_phases(code['controller']))
                phase=code['controller'].split('-- Native production owns its exact fixture/vessel action until it retires.',1)[1].split(
                    '-- Food preparation owns its routes and exact transfers as one operation.',1)[0]
                add('production-controller',"local selectedThreat=function() return nil end\nfunction resourceOwnerTick(id,agent,body,tickCount)\n"+execution.COMMON+phase+'\nend\n')
                cases=REFRESH_CASES if refresh else CASES
                add('cases',cases)
                done=subprocess.run([str(JDK/'java.exe'),'-Djava.awt.headless=true','-cp',str(work)+os.pathsep+str(GAME/'projectzomboid.jar'),
                    'LuaRun',*map(str,paths),'--','__productionResults'],cwd=work,capture_output=True,text=True,timeout=60)
                checks=dict(re.findall(r'([a-z0-9_]+)=(true|false)',done.stdout))
                expected=set(re.findall(r"check\('([a-z0-9_]+)'",cases))
                if done.returncode or (target not in checks if target else set(checks)!=expected):
                    raise RuntimeError((target or 'baseline')+': '+done.stdout[-5500:]+done.stderr[-1500:])
                return checks
            checks=run()
            failures=[name for name,value in checks.items() if value!='true']
            if failures: raise RuntimeError('cases: '+', '.join(failures))
            for name,before,after,target in CONTROLS:
                expected_count=2 if target=='actual_accepted_ready_shared_work_preempts_refill' else 1
                if texts[name].count(before)!=expected_count: raise RuntimeError(target+': mutation anchor differs')
                changed=texts[name].rsplit(before,1)
                if run({name:after.join(changed)},target)[target]!='false':
                    raise RuntimeError(target+': named defect survived')
            refresh_checks=run(refresh=True)
            failures=[name for name,value in refresh_checks.items() if value!='true']
            if failures: raise RuntimeError('handled-source cases: '+', '.join(failures))
            for name,before,after,target in REFRESH_CONTROLS:
                expected_count=2 if target=='retirement_releases_unconfirmed_native_source_handles' else 1
                if texts[name].count(before)!=expected_count: raise RuntimeError(target+': refresh mutation anchor differs')
                if run({name:texts[name].replace(before,after)},target,refresh=True)[target]!='false':
                    raise RuntimeError(target+': named refresh defect survived')
            before=work/'reload-before.lua';before.write_text(RELOAD_BEFORE,encoding='utf-8')
            after=work/'reload-after.lua';after.write_text(RELOAD_AFTER,encoding='utf-8')
            # Reload the actual owner module around a live native queued attempt.
            reload_paths=[work/'prelude.lua',GAME/'media/lua/shared/ISBaseObject.lua',
                GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua',GAME/'media/lua/shared/TimedActions/ISTakeWaterAction.lua',
                work/'labor.lua',work/'planner.lua',work/'production.lua',work/'controller.lua',before,work/'production.lua',after]
            reload_paths.insert(4,work/'models.lua');reload_paths.insert(5,work/'cognition.lua')
            reload_paths.insert(9,work/'experience.lua')
            reload_paths.insert(8,work/'locomotion.lua')
            for name in ['production','controller']:
                (work/(name+'.lua')).write_text(texts[name] if name=='production' else execution.controller_phases(texts[name]),encoding='utf-8')
            reloaded=subprocess.run([str(JDK/'java.exe'),'-cp',str(work)+os.pathsep+str(GAME/'projectzomboid.jar'),
                'LuaRun',*map(str,reload_paths),'--','__productionResults'],cwd=work,capture_output=True,text=True,timeout=60)
            reload_checks=dict(re.findall(r'([a-z0-9_]+)=(true|false)',reloaded.stdout))
            if reloaded.returncode or len(reload_checks)!=2 or 'false' in reload_checks.values():
                raise RuntimeError('reload: '+reloaded.stdout[-3000:]+reloaded.stderr[-1000:])
            cp=os.pathsep.join(map(str,[GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar',ROOT/'mod/42.20/media/java/SAO.jar']))
            sources=[ROOT/'java/src/com/sao/engine/SAOWorldSources.java',ROOT/'java/src/com/sao/bridge/SAOBridge.java',
                ROOT/'tools/luacheck/MovementCrossingProbe.java',ROOT/'tools/luacheck/ResourceApproachProbe.java',
                ROOT/'tools/resource_production_checks/ResourceRefillProbe.java']
            built=subprocess.run([str(JDK/'javac.exe'),'-encoding','UTF-8','-cp',cp,'-d',str(work),*map(str,sources)],
                capture_output=True,text=True,timeout=60)
            if built.returncode: raise RuntimeError('native adapter compile: '+built.stderr[-3500:])
            native=subprocess.run([str(JDK/'java.exe'),'-Duser.home='+str(work),'-Djava.awt.headless=true',
                '--enable-native-access=ALL-UNNAMED','-cp',str(work)+os.pathsep+cp,'ResourceRefillProbe'],
                cwd=work,capture_output=True,text=True,timeout=60)
            if native.returncode or 'RESOURCE_REFILL_NATIVE_OK' not in native.stdout:
                raise RuntimeError('native adapter: '+native.stdout[-3500:]+native.stderr[-2500:])
            native_count=len(re.findall(r'^CHECK .+=true$',native.stdout,re.M))
            native_java=(ROOT/'java/src/com/sao/engine/SAOWorldSources.java').read_text(encoding='utf-8')
            native_controls=[
                ('if (remembered.isEmpty() || (revision != null && !remembered.contains(revision))) {','if (false) {','foreign_fixture_is_not_native_private_knowledge'),
                ('if (revision != null && !revision.equals(physical.revision)) throw new ActionRefusal("REVISION_CHANGED");','if (false) throw new ActionRefusal("REVISION_CHANGED");','changed_fluid_revision_refuses_new_admission'),
                ('boolean cleanWater = amount > 0.0f && (fluid == null || !fluid.isPoisonous())','boolean cleanWater = amount > 0.0f && fluid != null && !fluid.isPoisonous()','native_pipe_reserve_projects_private_water'),
            ]
            for index,(before,after,target) in enumerate(native_controls):
                if native_java.count(before)!=1: raise RuntimeError(target+': native mutation anchor differs')
                mutant=work/('native-control-'+str(index))/'SAOWorldSources.java';mutant.parent.mkdir()
                mutant.write_text(native_java.replace(before,after,1),encoding='utf-8')
                built=subprocess.run([str(JDK/'javac.exe'),'-encoding','UTF-8','-cp',cp,'-d',str(work),str(mutant)],
                    capture_output=True,text=True,timeout=60)
                if built.returncode: raise RuntimeError(target+': native mutation compile: '+built.stderr[-1500:])
                changed=subprocess.run([str(JDK/'java.exe'),'-Duser.home='+str(work),'-Djava.awt.headless=true',
                    '--enable-native-access=ALL-UNNAMED','-cp',str(work)+os.pathsep+cp,'ResourceRefillProbe'],
                    cwd=work,capture_output=True,text=True,timeout=60)
                if changed.returncode==0 or 'CHECK '+target+'=false' not in changed.stdout:
                    raise RuntimeError(target+': native defect survived: '+changed.stdout[-1800:]+changed.stderr[-800:])
            print(f'Border 219 PASS: {len(checks)+len(reload_checks)+len(refresh_checks)} installed Kahlua cases, {native_count} native fixture checks; {len(CONTROLS)+len(REFRESH_CONTROLS)+len(native_controls)} named controls')
            return 0
    except Exception as error:
        print('FAULT Border 219:',error)
        return 1

if __name__=='__main__':
    raise SystemExit(main())
