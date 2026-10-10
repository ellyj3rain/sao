-- Production Planner/Labor/Controller and native Lua action paths. Physical
-- world receivers, source transport and their observation feed are controlled.
local checks={}
local function check(name,value) checks[#checks+1]=name..'='..tostring(value==true);__plumbingResults=table.concat(checks,'\n') end
local R,P,Ctl=SAO.ResourceProduction,SAO.ProceduralPlanning,SAO.Controller
local nativeDrink=SAO.Needs.drinkCarried
local function copy(value)
    if type(value)~='table' then return value end
    local out={} for k,v in pairs(value) do out[k]=copy(v) end return out
end
local function list(items) return {size=function() return #items end,get=function(self,i) return items[i+1] end} end
local function plumbingFixture(held,knownTool)
    local body,agent=fixture()
    F.heldTool,F.knownTool,F.x,F.y=held,knownTool,1.5,1.5
    F.thirst=.7
    F.sourceAmount,F.supplyAmount,F.connections,F.drinks=0,4,0,0
    F.connected=false;F.cell={};F.square={};F.world={getWorld=function() return 'd34-world' end,getCell=function() return F.cell end}
    getWorld=function() return F.world end
    ItemTag={PIPE_WRENCH='PIPE_WRENCH'}
    body.getX=function() return F.x end;body.getY=function() return F.y end
    body.getCell=function() return F.cell end;body.getCurrentSquare=function() return F.square end
    body.getPrimaryHandItem=function() return F.heldTool and F.wrench or nil end
    body.getSecondaryHandItem=function() end
    body.isEquipped=function(self,item) return item==F.wrench and F.heldTool end
    body.playSound=function() return 1 end;body.stopOrTriggerSound=function() end
    body.faceThisObject=function() end;body.setMetabolicTarget=function() end
    body.getMoodles=function() return {getMoodleLevel=function() return 0 end} end
    body.getEmitter=function() return {isPlaying=function() return false end,playSound=function() return 0 end} end
    body.DrinkFluid=function(self,item,amount) F.drinks=F.drinks+1;F.amount=F.amount*(1-amount);F.thirst=math.max(0,(F.thirst or .7)-.3) end
    F.inventory.containsRecursive=function(self,item) return item==F.item or item==F.wrench and F.heldTool end
    F.inventory.contains=F.inventory.containsRecursive
    F.item.isBroken=function() return false end;F.item.getCondition=function() return 10 end
    F.item.getIsCraftingConsumed=function() return false end;F.item.getType=function() return 'WaterBottle' end
    F.item.hasTag=function() return false end;F.item.getWorldItem=function() end;F.item.getEatType=function() return 'bottle' end
    F.fluid.getFilledRatio=function() return F.amount/F.capacity end;F.fluid.isEmpty=function() return F.amount<=0 end
    F.fluid.getProperties=function() return {getHungerChange=function() return 0 end} end
    F.fluid.getCustomDrinkSound=function() return '' end
    F.wrench={kind='InventoryItem',getID=function() return 61 end,getFullType=function() return 'Base.PipeWrench' end,
        getContainer=function() return F.heldTool and F.inventory or nil end,isBroken=function() return F.broken==true end,
        getCondition=function() return F.broken and 0 or 10 end,getIsCraftingConsumed=function() return false end,
        getType=function() return 'PipeWrench' end,hasTag=function(self,tag) return tag==ItemTag.PIPE_WRENCH end,
        canStoreWater=function() return false end,
        getFluidContainerFromSelfOrWorldItem=function() end}
    F.fixture.getUsesExternalWaterSource=function() return F.connected end
    F.fixture.data={canBeWaterPiped=true}
    F.fixture.getModData=function(self) return self.data end
    F.fixture.setUsesExternalWaterSource=function(self,connected) F.connected=connected;F.sourceAmount=F.supplyAmount end
    F.fixture.transmitModData=function() end;F.fixture.sendObjectChange=function() end
    F.fixture.getSquare=function() return F.square end
    IsoObjectChange={USES_EXTERNAL_WATER_SOURCE='external-water'}
    buildUtil={setHaveConstruction=function() F.connections=F.connections+1 end}
    F.fact.state,F.fact.plumbing,F.fact.quantities='empty','unconnected',{}
    F.fact.chunkX,F.fact.chunkY=0,0
    F.toolFact={id='C:known-wrench',kind='container',state='available',revision='wr1',fingerprint='wfp',x=8,y=1,z=0}
    F.belief.sourceFacts['C:known-wrench']=F.toolFact
    F.belief.sourceRevision='F:known-tap@r1,C:known-wrench@wr1'
    SAO.Needs.drinkCarried=nativeDrink;SAO.Needs.findWater=function() end
    SAO.Cooking.active=function() return false end
    SAOJavaBridge.privateCarriedItems=function() return list(F.heldTool and {F.item,F.wrench} or {F.item}) end
    SAOJavaBridge.findCarriedDrink=function() return F.amount>0 and not F.poison and not F.tainted and F.item or nil end
    SAOJavaBridge.hasPendingActions=function() return false end
    SAOJavaBridge.worldPlumbTarget=function(self,body,id,fp,rev)
        return F.sourceValid and F.allowed and id=='F:known-tap' and fp=='fp1' and rev==F.sourceRevision and 'READY:1:1:0' or 'UNAVAILABLE'
    end
    SAOJavaBridge.worldPlumbObject=function(self,body,id,fp,rev)
        return F.sourceValid and F.reachable and F.allowed and rev==F.sourceRevision and F.fixture or nil
    end
    SAOJavaBridge.worldPlumbValid=function(self,body,object,id,fp,x,y,z,completed)
        return F.sourceValid and F.reachable and F.allowed and object==F.fixture and id=='F:known-tap'
            and fp=='fp1' and x==2 and y==1 and z==0 and (completed and F.connected or not completed and not F.connected)
    end
    SAOJavaBridge.tickMove=function() if F.arrived then F.reachable=true;F.x=1.5;return 'Succeeded' end return 'Working' end
    SAO.WorldSources.privatelyKnowsItem=function(id,source,item) return F.knownTool and id=='a' and source=='C:known-wrench' and item==61 end
    SAO.WorldSources.actionOptions=function(place,category)
        if category~='pipe-wrench' or not F.knownTool then return end
        return {options={{parameters={sourceId='C:known-wrench',revision='wr1',itemId=61,itemType='Base.PipeWrench',sourceX=8,sourceY=1,sourceZ=0}}}}
    end
    SAO.WorldSources.observeChunk=function()
        F.sourceRevision=F.connected and (F.transferCalls>0 and 'r3' or 'r2') or 'r1'
        F.latest=copy(F.fact);F.latest.revision=F.sourceRevision;F.latest.plumbing=F.connected and 'connected' or 'unconnected'
        F.latest.quantities=F.sourceAmount>0 and {water=F.sourceAmount} or {}
        F.latest.state=F.sourceAmount>0 and 'available' or 'empty'
        F.latest.chunkX,F.latest.chunkY=0,0
        return true
    end
    SAO.WorldSources.beliefFact=function() return F.latest end
    SAO.Perception.learnSource=function(id,place,source)
        if id~='a' or source~='F:known-tap' then return false end
        F.fact=copy(F.latest);F.belief.sourceFacts[source]=F.fact
        F.belief.sourceRevision=source..'@'..F.sourceRevision..',C:known-wrench@wr1'
        return true
    end
    SAO.WorldSources.actionOutcome=function(reservation,id) return F.transfer and F.transfer.reservationId==reservation and id=='a' and F.transfer or nil end
    SAO.SourceUse.beginAcquisition=function(id,body,place,category,context)
        if F.rec.worldSourceReservation then return false end
        local reservation='source-transfer/a/1'
        if not P.noteAdmission(id,context.purposeId,'SAO.SourceUse',reservation,context.purposeStepId) then return false end
        F.acquisition=copy(context);F.acquisition.category=category;F.rec.worldSourceReservation=reservation
        return true
    end
    local queue={queue={},current=nil}
    function queue:indexOf(action) for i,member in ipairs(self.queue) do if member==action then return i end end return -1 end
    function queue:onCompleted(action) self.queue={};self.current=nil end
    function queue:resetQueue() self.queue={};self.current=nil end
    ISTimedActionQueue.queues[body]=queue
    ISTimedActionQueue.add=function(action)
        if not F.queueAccept then return end
        F.queueCalls=F.queueCalls+1;F.action=action;queue.queue={action};queue.current=action
        action.action={isStarted=function() return true end,finished=function() return true end,isForceComplete=function() return false end,
            forceStop=function() if F.cancelAccept then action:stop() end end}
    end
    return body,agent
end
local function acquired()
    local a=F.acquisition
    F.transfer={actorId='a',reservationId=F.rec.worldSourceReservation,purposeId=a.purposeId,purposeStepId=a.purposeStepId,
        operation='acquire',status='completed',sourceId=a.sourceId,preRevision=a.sourceRevision,itemId=a.itemId,itemType=a.itemType,
        category=a.category,measurement='native-item-transfer',observedQuantity=1,at=F.at}
    F.heldTool=true;F.x=8.5;F.reachable=false
    local accepted=P.consumeSourceResult(F.transfer)
    F.rec.worldSourceReservation=nil
    return accepted
end
local function completeNative()
    local action=F.action
    if action.start and action.itemToPipe then action:start() end
    local performed=action:perform()
    local completed=action:complete()
    R.tick('a',F.body)
    return completed,performed
end
local function returnAndConnect()
    F.arrived=true;R.tick('a',F.body)
    completeNative()
end

local body,agent=plumbingFixture(false,false)
local context=Ctl.resourceContext('a',agent,body,{thirst=.7},'water',.5,true)
context.productionOptions=R.options('a',body,'water')
local purpose,step=P.planResource('a',context)
check('dry_observed_fixture_retains_blocked_water_purpose',purpose and purpose.plumbing and purpose.status=='blocked'
    and step and step.productionKind=='plumb-fixture' and step.status=='blocked' and F.amount==0 and F.connections==0)
body,agent=plumbingFixture(true,false);F.private=false
check('unknown_fixture_cannot_supply_plumbing_work',#R.options('a',body,'water')==0
    and not Ctl.beginHydrationAcquisition('a',agent,body,100,{thirst=.7}) and F.connections==0)
body,agent=plumbingFixture(false,true)
local started=Ctl.testThirst('a',agent,body,100,{thirst=.7,hunger=0,fatigue=0})
purpose,step=P.resourceDemand('a','water')
local purposeId=purpose and purpose.id;local acquisitionStep=step and step.id
check('urgent_thirst_acquires_exact_private_wrench',started and agent.state=='SOURCEWARD' and F.acquisition
    and F.acquisition.purposeId==purposeId and F.acquisition.purposeStepId==acquisitionStep
    and F.acquisition.sourceId=='C:known-wrench' and F.acquisition.sourceRevision=='wr1'
    and F.acquisition.itemId==61 and F.acquisition.itemType=='Base.PipeWrench' and F.acquisition.category=='pipe-wrench')
-- control-boundary: urgent_thirst_acquires_exact_private_wrench
check('wrench_admission_has_no_water_or_connection_credit',purpose.admission and purpose.status~='completed'
    and F.amount==0 and F.connections==0 and not F.rec.resourceProductionWork)
local admitted=copy(purpose.admission)
F.fact.revision='r-changed';F.belief.sourceRevision='F:known-tap@r-changed,C:known-wrench@wr1'
Ctl.beginHydrationAcquisition('a',agent,body,200,{thirst=.7})
purpose,step=P.resourceDemand('a','water')
check('pending_wrench_admission_preserves_exact_fixture_and_step',purpose.id==purposeId and step.id==acquisitionStep
    and purpose.admission.correlationId==admitted.correlationId and purpose.plumbing.sourceRevision=='r1' and F.connections==0)
F.fact.revision='r1';F.belief.sourceRevision='F:known-tap@r1,C:known-wrench@wr1'
F.transfer={actorId='a',reservationId=F.rec.worldSourceReservation,purposeId=purposeId,purposeStepId=step.id,
    operation='acquire',status='completed',sourceId='C:known-wrench',preRevision='wrong-revision',itemId=61,itemType='Base.PipeWrench',
    category='pipe-wrench',measurement='native-item-transfer',observedQuantity=1,at=F.at}
check('wrong_wrench_source_revision_cannot_advance',not P.consumeSourceResult(F.transfer) and purpose.cursor==1 and purpose.admission~=nil)
-- control-boundary: wrong_wrench_source_revision_cannot_advance
F.rec=copy(F.rec);agent.rec=F.rec
purpose,step=P.resourceDemand('a','water')
check('saved_plain_fixture_and_pending_exact_acquisition_retain_same_purpose',purpose.id==purposeId and purpose.plumbing.sourceId=='F:known-tap'
    and purpose.plumbing.itemId==51 and purpose.plumbing.toolItemId=='61' and step.id==acquisitionStep and purpose.admission~=nil)
local transferAccepted=acquired();agent.state='IDLE'
started=Ctl.advanceResourcePurpose('a',agent,body,2000,{hunger=.59,thirst=.25,fatigue=0})
purpose,step=P.resourceDemand('a','water')
check('acquired_wrench_returns_to_retained_fixture_under_water_purpose',transferAccepted and started and agent.state=='RESOURCE'
    and purpose.id==purposeId and F.rec.resourceProductionWork and F.rec.resourceProductionWork.kind=='plumb-fixture'
    and F.rec.resourceProductionWork.sourceId=='F:known-tap' and F.rec.resourceProductionWork.toolItemId=='61'
    and F.rec.resourceProductionWork.purposeId==purposeId and F.routeCalls>0 and F.connections==0)
-- control-boundary: acquired_wrench_returns_to_retained_fixture_under_water_purpose
resourceOwnerTick('a',agent,body,2100)
check('ordinary_thirst_keeps_native_plumbing_return_in_progress',agent.state=='RESOURCE'
    and F.rec.resourceProductionWork and F.rec.resourceProductionWork.purposeId==purposeId and F.connections==0)
F.arrived=true;R.tick('a',body)
check('returned_fixture_is_reacquired_for_installed_native_plumbing',F.action and F.action.itemToPipe==F.fixture
    and F.action.wrench==F.wrench and F.rec.resourceProductionWork and F.rec.resourceProductionWork.purposeId==purposeId and F.connections==0)
completeNative()
local connection=F.rec.resourceProductionOutcomes and F.rec.resourceProductionOutcomes[1]
purpose,step=P.resourceDemand('a','water')
check('native_connection_keeps_same_water_objective_open',connection and connection.status=='completed' and connection.connected==true
    and F.connections==1 and F.amount==0 and purpose and purpose.id==purposeId and purpose.status~='completed'
    and purpose.awaitingReassessment==true and purpose.plumbing.connectedWorkId==connection.id)
-- control-boundary: native_connection_keeps_same_water_objective_open
check('handled_connection_refreshes_only_personal_exact_fixture',connection and connection.sourceObservation.status=='confirmed'
    and F.fact.revision=='r2' and F.fact.plumbing=='connected' and F.belief.sourceRevision=='F:known-tap@r2,C:known-wrench@wr1')
resourceOwnerTick('a',agent,body,3000)
check('completed_connection_owner_returns_controller_to_idle',agent.state=='IDLE' and not F.rec.resourceProductionWork)
local options=R.options('a',body,'water')
check('connected_private_fixture_offers_actual_water_refill',#options>0 and options[1].kind=='refill-water'
    and options[1].sourceRevision=='r2' and options[1].itemId==51 and F.amount==0)
started=Ctl.advanceResourcePurpose('a',agent,body,4000,{hunger=0,thirst=.3,fatigue=0})
purpose,step=P.resourceDemand('a','water')
check('same_water_purpose_dispatches_existing_native_refill',started and purpose and purpose.id==purposeId
    and F.action and F.action.waterObject==F.fixture and F.action.item==F.item
    and F.rec.resourceProductionWork.kind=='refill-water' and F.rec.resourceProductionWork.purposeId==purposeId and F.amount==0)
completeNative();resourceOwnerTick('a',agent,body,5000)
local waterPurpose=F.rec.proceduralPlanning.purposes[purposeId]
local water=F.rec.resourceProductionOutcomes[2]
check('only_measured_native_water_fulfils_hydration_stock',water and water.status=='completed' and water.nativeGain>0
    and F.amount>0 and waterPurpose.status=='completed' and waterPurpose.id==purposeId and F.transferCalls==1)
local events=#waterPurpose.events
check('connection_receipt_replay_has_no_second_completion',P.consumeProductionResult('a',connection)==true
    and #waterPurpose.events==events and F.connections==1 and waterPurpose.status=='completed')
F.thirst=.7
started=Ctl.testThirst('a',agent,body,6000,{thirst=.7,hunger=0,fatigue=0})
local beforeDrink=F.amount;local drink=F.action
if started and drink and drink.fluidContainer then drink:perform();drink:complete() end
check('ordinary_thirst_drinks_the_actual_refilled_vessel',started and agent.state=='DRINK' and drink.item==F.item
    and F.drinks==1 and F.amount<beforeDrink and F.thirst<.7 and waterPurpose.id==purposeId)

body,agent=plumbingFixture(true,false)
started=Ctl.beginHydrationAcquisition('a',agent,body,100,{thirst=.7})
purpose=P.resourceDemand('a','water');purposeId=purpose.id
F.supplyAmount=0
if started then completeNative() end
resourceOwnerTick('a',agent,body,1000)
started=Ctl.advanceResourcePurpose('a',agent,body,2000,{hunger=0,thirst=.3,fatigue=0})
purpose=P.resourceDemand('a','water')
check('connected_empty_fixture_retains_unfinished_same_water_purpose',not started and F.connections==1 and F.amount==0
    and purpose and purpose.id==purposeId and purpose.status~='completed' and F.rec.proceduralPlanning.nextPurpose==1)
agent.nextResourceAt=0
started=Ctl.advanceResourcePurpose('a',agent,body,3000,{hunger=.59,thirst=.1,fatigue=0})
local foodPurpose=P.resourceDemand('a','food')
local savedWater=F.rec.proceduralPlanning.purposes[purposeId]
check('blocked_connected_water_does_not_suppress_higher_food_pressure',foodPurpose and savedWater.status~='completed'
    and savedWater.plumbing.sourceId=='F:known-tap' and savedWater.id==purposeId and not savedWater.admission)
-- control-boundary: blocked_connected_water_does_not_suppress_higher_food_pressure
F.sourceAmount=4;SAO.WorldSources.observeChunk();SAO.Perception.learnSource('a',{id=1},'F:known-tap')
agent.state='IDLE';agent.nextResourceAt=0
started=Ctl.advanceResourcePurpose('a',agent,body,4000,{hunger=.1,thirst=.59,fatigue=0})
if started then completeNative();resourceOwnerTick('a',agent,body,5000) end
check('later_water_pressure_resumes_original_hydration_purpose',started and F.amount>0
    and F.rec.proceduralPlanning.purposes[purposeId].status=='completed' and F.rec.resourceProductionOutcomes[2].purposeId==purposeId)
body,agent=plumbingFixture(true,false)
Ctl.beginHydrationAcquisition('a',agent,body,100,{thirst=.7})
purpose=P.resourceDemand('a','water');purposeId=purpose.id
local interrupted=R.interrupt('a',body,'d34-interrupted')
purpose=P.resourceDemand('a','water')
check('interrupted_plumbing_preserves_water_purpose_without_effect_credit',interrupted and purpose and purpose.id==purposeId
    and purpose.status~='completed' and F.connections==0 and F.amount==0 and F.rec.resourceProductionOutcomes[1].status=='interrupted')
body,agent=plumbingFixture(false,true)
Ctl.beginHydrationAcquisition('a',agent,body,100,{thirst=.7});acquired();agent.state='IDLE';F.allowed=false
started=Ctl.advanceResourcePurpose('a',agent,body,2000,{hunger=0,thirst=.3,fatigue=0})
purpose=P.resourceDemand('a','water')
check('current_standing_refusal_preserves_retained_target_without_connection',not started and purpose and purpose.plumbing.sourceId=='F:known-tap'
    and purpose.status~='completed' and F.connections==0 and not F.rec.resourceProductionWork)
body,agent=plumbingFixture(true,false);F.fixture.data.canBeWaterPiped=nil
started=Ctl.beginHydrationAcquisition('a',agent,body,100,{thirst=.7})
purpose=P.resourceDemand('a','water');purposeId=purpose.id
if started then completeNative() end
resourceOwnerTick('a',agent,body,1000)
local connected=F.rec.resourceProductionOutcomes and F.rec.resourceProductionOutcomes[1]
started=Ctl.advanceResourcePurpose('a',agent,body,2000,{hunger=0,thirst=.3,fatigue=0})
if started then completeNative();resourceOwnerTick('a',agent,body,3000) end
check('fixed_sink_nil_moddata_connects_then_refills_same_water_purpose',connected and connected.status=='completed'
    and connected.beforeCanBeWaterPiped==false and connected.beforePlumbingEligible==true
    and F.connections==1 and F.amount>0 and F.rec.proceduralPlanning.purposes[purposeId].status=='completed')
__plumbingResults=table.concat(checks,'\n')
