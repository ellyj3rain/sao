local f=__consumer
local function check(name,value)__check("consumer_"..name,value==true);if not value then error(name)end end
local rec,body,id=f.record,f.body,f.id
local P,Ctl=SAO.ProceduralPlanning,SAO.Controller
check("normal_cognition_defaults",SAO.Cognition.ensureGameDefaults()==true)
local originalAdd=ISTimedActionQueue.add
ISTimedActionQueue.add=function(action)
 local ok,result=pcall(originalAdd,action)
 print("CONSUMER_QUEUE_CALL",ok,result)
 if not ok then error(result)end
 return result
end
local agent={rec=rec,state="IDLE",stateSince=0,nextDecisionAt=0}
Ctl.agents[id]=agent
check("actual_record_body",SAO.Identity.get(id)==rec and SAO.Body.get(id)==body)
local targets=SAOJavaBridge:recipeUpkeepDemands(body)
local target
for _,row in ipairs(targets or {})do if row.targetItemId==tostring(f.target:getID()) and row.recipeId=="Base.SharpenBlade" then target=row end end
check("native_original_target",target~=nil)
local d={id="retained-upkeep:"..target.targetItemId,consumerId="held-item:"..target.targetItemId,kind="recipe-upkeep",
 sourceRevision=target.sourceRevision,targetItemId=target.targetItemId,targetSlotIndex=target.targetSlotIndex,desiredState=target.desiredState}
local context=Ctl.recipeWorkContext(id,body,d,nil,nil,{itemType=target.itemType,deficit=.9})
local parent,parentStep=P.planRecipeWork(id,context)
print("CONSUMER_PRIVATE_OPTIONS",#context.options)
for _,option in ipairs(context.options)do print("CONSUMER_OPTION",option.recipeId,option.ready,option.reason)end
print("CONSUMER_PLAN",parent and parent.id,parent and parent.status,parent and parent.blockers and parent.blockers[1],
 parent and parent.recipeSupply and parent.recipeSupply.recipeId,parentStep and parentStep.id,parentStep and parentStep.status)
check("private_original_upkeep_choice",parent~=nil and parent.recipeSupply.recipeId=="Base.SharpenBlade" and parentStep.recipeRequirement~=nil)
local requesting
for _,step in ipairs(parent.steps)do if step.productionKind=="recipe-upkeep" then requesting=step end end
local needs=SAOJavaBridge:recipeSupplyNeeds(body,requesting.recipeId)
local stock
for _,slot in ipairs(needs.slots)do if slot.remainingFraction>0 then for _,a in ipairs(slot.alternatives)do
 if a.itemType=="Base.CrudeWhetstone" then stock={id="retained-stock:"..parent.id,consumerId=parent.id..":"..requesting.id,
  kind="recipe-stock",sourceRevision=needs.nativeRevision,desiredType=a.itemType,desiredAmount=a.desiredAmount,
  quantityUnit=a.quantityUnit,consumerRecipeId=requesting.recipeId} end
end end end
check("native_requesting_slot_stock",stock~=nil)
local supply,step=P.planRecipeWork(id,Ctl.recipeWorkContext(id,body,stock,parent.id,requesting.id))
check("private_stock_choice",supply~=nil and supply.recipeSupply.recipeId=="Base.MakeCrudeWhetstone" and step.recipeRequirement~=nil)
check("unseen_source_no_option",#Ctl.recipeInputOffers(id,body,supply,step).options==0)
local inspection=SAO.WorldSources.inspectionCandidate(id,body,"standing",12,f.sourceId)
local inspectStep=inspection and P.prepareRecipeInspection(id,supply.id,inspection)
check("demand_bound_inspection_admitted",inspectStep~=nil and SAO.WorldSources.beginPurposeInspection(id,body,inspection,supply.id,inspectStep.id)~=nil)
check("actual_native_private_inspection",SAO.WorldSources.inspectContainer(id,body,inspection)==true)
supply,step=P.planRecipeWork(id,Ctl.recipeWorkContext(id,body,stock,parent.id,requesting.id))
local offered=Ctl.recipeInputOffers(id,body,supply,step)
check("signed_exact_ingredients",#offered.options==2)
__consumerAllowApproach=true;__moveConsumerTo(31,20)
check("distant_source_not_currently_eligible",#Ctl.recipeInputOffers(id,body,supply,step).options==0)
check("private_remembered_source_approach",Ctl.advanceRecipeWork(id,agent,body,1,supply,step)
 and agent.state=="TRAVEL" and supply.recipeSupply.sourceInquiry~=nil and rec.worldSourceReservation==nil and step.itemId==nil)
local inquiry=supply.recipeSupply.sourceInquiry
check("inquiry_retains_demand_source",inquiry.sourceId==f.sourceId and inquiry.demandId==step.recipeRequirement.demandId
 and inquiry.fingerprint==f.fingerprint and SAO.Locomotion.jobs[id].goal.x==inquiry.x)
local savedInquiry=__roundtrip(rec)
check("pending_source_inquiry_save",savedInquiry.proceduralPlanning.purposes[supply.id].recipeSupply.sourceInquiry.sourceId==inquiry.sourceId)
__nativeModData("SurvivorAwareness_Records").records[id]=savedInquiry
rec=savedInquiry;f.record=rec;agent.rec=rec
parent=rec.proceduralPlanning.purposes[parent.id];supply=rec.proceduralPlanning.purposes[supply.id];step=supply.steps[supply.cursor]
f.container:Remove(f.first);f.first:setContainer(nil);f.container:Remove(f.second);f.second:setContainer(nil)
__moveConsumerTo(inquiry.x,inquiry.y);SAO.Locomotion.jobs[id]=nil;agent.state="IDLE"
check("normal_arrival_reinspection",Ctl.advanceRecipeWork(id,agent,body,1,supply,step)
 and agent.forageInspection~=nil and supply.recipeSupply.sourceInquiry==nil and rec.worldSourceReservation==nil)
check("actual_arrival_inspection",SAO.WorldSources.inspectContainer(id,body,agent.forageInspection)==true)
agent.forageInspection=nil;SAO.Locomotion.jobs[id]=nil;agent.state="IDLE"
supply,step=P.planRecipeWork(id,Ctl.recipeWorkContext(id,body,stock,parent.id,requesting.id))
check("changed_donor_memory_grants_no_stock",#Ctl.recipeInputOffers(id,body,supply,step).options==0 and rec.worldSourceReservation==nil)
f.container:AddItemBlind(f.first);f.first:setContainer(f.container);f.container:AddItemBlind(f.second);f.second:setContainer(f.container)
local refreshedInspection=SAO.WorldSources.inspectionCandidate(id,body,"standing",12,f.sourceId)
local refreshedStep=refreshedInspection and P.prepareRecipeInspection(id,supply.id,refreshedInspection)
check("restored_donor_current_inspection",refreshedStep~=nil
 and SAO.WorldSources.beginPurposeInspection(id,body,refreshedInspection,supply.id,refreshedStep.id)~=nil
 and SAO.WorldSources.inspectContainer(id,body,refreshedInspection)==true)
supply,step=P.planRecipeWork(id,Ctl.recipeWorkContext(id,body,stock,parent.id,requesting.id))
offered=Ctl.recipeInputOffers(id,body,supply,step)
check("fresh_arrival_exact_ingredients",#offered.options==2)
__consumerAllowApproach=false;__moveConsumerTo(10,20)
check("private_exact_source_choice",P.selectRecipeInput(id,supply.id,offered))
local requirement=step.recipeRequirement
check("current_private_demand",P.recipeInputAdmission(id,requirement.demandId,supply.id,step.id,requirement.recipeId,requirement.index,requirement.declaration))
rec.dead=true
check("dead_private_demand_refused",P.recipeInputAdmission(id,requirement.demandId,supply.id,step.id,requirement.recipeId,requirement.index,requirement.declaration)==false)
rec.dead=nil
SAO.Body.active[id]=nil
check("foreign_body_source_refused",SAO.WorldSources.recipeSlotOptions(step.place,"recipe-input",id,body,requirement,"standing")==nil)
SAO.Body.active[id]=body
local originalRevision=requirement.sourceRevision;requirement.sourceRevision="foreign-native-definition"
check("foreign_definition_demand_refused",P.recipeInputAdmission(id,requirement.demandId,supply.id,step.id,requirement.recipeId,requirement.index,requirement.declaration)==false)
requirement.sourceRevision=originalRevision
local savedActive=__roundtrip(rec)
check("active_person_save",savedActive.proceduralPlanning.purposes[supply.id].steps[1].recipeRequirement.declaration==requirement.declaration)
__nativeModData("SurvivorAwareness_Records").records[id]=savedActive
rec=savedActive;f.record=rec;agent.rec=rec
parent=rec.proceduralPlanning.purposes[parent.id];supply=rec.proceduralPlanning.purposes[supply.id];step=supply.steps[supply.cursor]
check("normal_acquisition_dispatch",Ctl.beginConstructionAcquisition(id,agent,body,1,supply,step))
local queued=SAO.SourceUse.onMovementDone(id,body,"arrived")
local failedReservation=rec.worldSourceReservation
print("CONSUMER_MOVE_DONE",queued,failedReservation)
if failedReservation then local result=SAO.WorldSources.actionOutcome(failedReservation,id);print("CONSUMER_SOURCE_STATE",result and result.status,result and result.detail,result and result.phase)end
check("reached_source_route",queued=="moving" or queued=="using")
if queued=="moving" then queued=SAO.SourceUse.onMovementDone(id,body,"arrived")end
print("CONSUMER_TRANSFER_STAGE",queued,rec.worldSourceReservation)
check("native_source_transfer_queued",queued=="using")
local queue=ISTimedActionQueue.getTimedActionQueue(body)
local action=queue.current
check("native_transfer_action_owned",action~=nil and action.saoSourceReservation==rec.worldSourceReservation)
local reservationId=rec.worldSourceReservation
local nativePerform=action.perform
function action:perform()
 print("CONSUMER_NATIVE_PERFORM_ENTER",self.Type,#(self.queueList or {}))
 local ok,result=pcall(nativePerform,self)
 print("CONSUMER_NATIVE_PERFORM_RETURN",ok,result)
 if not ok then error(result)end
 return result
end
print("CONSUMER_TRANSFER_VALID",action:isValid(),action:isValidStart())
action:start()
action.action:forceComplete()
action.action:perform()
action.action:complete()
body:getCharacterActions():remove(action.action) -- Controlled native animation-end acknowledgement.
print("CONSUMER_NATIVE_TRANSFER_END",queue.current,body:getInventory():getItems():size(),SAO.SourceUse.tick(id,body))
local receipt=SAO.WorldSources.actionOutcome(reservationId,id)
print("CONSUMER_RECEIPT",receipt and receipt.status,receipt and receipt.observedQuantity,receipt and receipt.quantityUnit,
 receipt and receipt.itemId,step.itemId,receipt and receipt.preRevision,step.sourceRevision)
print("CONSUMER_PROVISIONING",SAO.Provisioning.processReceipt(receipt))
print("CONSUMER_AFTER_RESULT",supply.admission,supply.cursor,supply.steps[supply.cursor] and supply.steps[supply.cursor].productionKind)
check("actual_transfer_and_private_result",receipt and receipt.status=="completed" and receipt.observedQuantity==1
 and supply.admission==nil and supply.steps[supply.cursor].productionKind=="recipe-stock")
-- The unchanged state cadence returns after the source owner has settled.
agent.state="IDLE"
supply,step=P.planRecipeWork(id,Ctl.recipeWorkContext(id,body,stock,parent.id,requesting.id))
print("CONSUMER_REMAINING_STEP",supply and supply.status,step and step.id,step and step.status,step and step.recipeRequirement,
 step and #Ctl.recipeInputOffers(id,body,supply,step).options)
for _,place in pairs(SAO.Perception.knownPlaces(id,true))do for _,fact in pairs(place.sourceFacts or {})do print("CONSUMER_REMAINING_SOURCE",fact.id,fact.revision,fact.state,fact.explored)end end
check("remaining_native_quantity",step.recipeRequirement~=nil and #Ctl.recipeInputOffers(id,body,supply,step).options==1)
check("second_exact_source_choice",P.selectRecipeInput(id,supply.id,Ctl.recipeInputOffers(id,body,supply,step)))
check("second_normal_acquisition",Ctl.beginConstructionAcquisition(id,agent,body,2,supply,step))
queued=SAO.SourceUse.onMovementDone(id,body,"arrived")
if queued=="moving"then queued=SAO.SourceUse.onMovementDone(id,body,"arrived")end
check("second_native_transfer_queued",queued=="using")
queue=ISTimedActionQueue.getTimedActionQueue(body);action=queue.current;reservationId=rec.worldSourceReservation
action:start();action.action:forceComplete();action.action:perform();action.action:complete()
body:getCharacterActions():remove(action.action)
check("second_actual_transfer",SAO.SourceUse.tick(id,body)=="completed" and body:getInventory():contains(f.first)
 and body:getInventory():contains(f.second))
agent.state="IDLE"
supply,step=P.planRecipeWork(id,Ctl.recipeWorkContext(id,body,stock,parent.id,requesting.id))
print("CONSUMER_READY_STOCK",supply.status,step and step.status,step and step.productionKind)
check("native_inputs_ready",step~=nil and step.productionKind=="recipe-stock" and step.status=="available" and step.recipeInputs~=nil)
check("normal_stock_dispatch",Ctl.beginConstructionProduction(id,agent,body,3,supply,step))
queue=ISTimedActionQueue.getTimedActionQueue(body);action=queue.current
print("CONSUMER_STOCK_ACTION",action and action.Type,action and action:isValid(),action and action:isValidStart())
check("native_stock_action_owned",action~=nil and rec.resourceProductionWork~=nil)
action:start();action.action:forceComplete();action.action:perform();action.action:complete()
body:getCharacterActions():remove(action.action)
SAO.ResourceProduction.reconcileSaved(id,body)
local stockRow=rec.resourceProductionOutcomes and rec.resourceProductionOutcomes[#rec.resourceProductionOutcomes]
print("CONSUMER_STOCK_RESULT",stockRow and stockRow.status,stockRow and stockRow.detail,stockRow and stockRow.outputCount)
check("native_stock_effect",stockRow~=nil and stockRow.status=="completed" and stockRow.nativeCredit==stockRow.id
 and stockRow.outputCount==1 and stockRow.outputs[1].itemType=="Base.CrudeWhetstone")
check("stock_does_not_complete_original_request",parent.status~="completed" and supply.status~="completed")
check("fresh_stock_availability",P.refreshRecipeSupply(id,body,supply.id)
 and supply.recipeSupply.currentAvailability.requestedStockAvailable==true)
local produced=body:getInventory():getItemFromType("Base.CrudeWhetstone")
body:getInventory():Remove(produced);produced:setContainer(nil)
check("historical_stock_not_current",P.refreshRecipeSupply(id,body,supply.id)==false and stockRow.stockAvailable==true)
body:getInventory():AddItemBlind(produced);produced:setContainer(body:getInventory())
check("restored_current_stock",P.refreshRecipeSupply(id,body,supply.id))
-- The exact authenticated native output is physically moved to the world;
-- its historical production never supplies current ownership or acquisition.
body:getInventory():Remove(produced);produced:setContainer(nil)
local worldOutput=__dropNativeOutput(produced)
print("CONSUMER_WORLD_OUTPUT",produced,worldOutput,body:getSquare():getWorldObjects():size(),worldOutput and worldOutput:getItem())
check("actual_output_world_identity",worldOutput~=nil and worldOutput:getItem()==produced and produced:getWorldItem()==worldOutput)
check("dropped_output_not_held",P.refreshRecipeSupply(id,body,supply.id)==false)
agent.state="IDLE"
check("normal_dropped_output_dispatch",Ctl.advanceRecipeWork(id,agent,body,3,supply,supply.steps[supply.cursor]))
queued=SAO.SourceUse.onMovementDone(id,body,"arrived")
if queued=="moving"then queued=SAO.SourceUse.onMovementDone(id,body,"arrived")end
queue=ISTimedActionQueue.getTimedActionQueue(body);action=queue.current;reservationId=rec.worldSourceReservation
check("native_ground_action_owned",queued=="using" and action~=nil and action.item==worldOutput)
action:start();action.action:forceComplete();action.action:perform();action.action:complete()
body:getCharacterActions():remove(action.action)
local groundResult=SAO.SourceUse.tick(id,body)
receipt=SAO.WorldSources.actionOutcome(reservationId,id)
check("native_output_acquired",groundResult=="completed" and receipt and receipt.status=="completed"
 and body:getInventory():contains(produced) and produced:getWorldItem()==nil)
check("acquired_output_current",P.refreshRecipeSupply(id,body,supply.id))
local stockId=stockRow.outputs[1].itemId
local beforeSharpness=f.target:getSharpness()
agent.state="IDLE"
parent,parentStep=P.planRecipeWork(id,Ctl.recipeWorkContext(id,body,d,nil,nil,{itemType=target.itemType,deficit=.9}))
check("original_upkeep_ready",parentStep~=nil and parentStep.productionKind=="recipe-upkeep" and parentStep.status=="available")
check("original_request_identity_retained",parentStep.id==supply.recipeSupply.parentStepId)
check("normal_original_upkeep_dispatch",Ctl.beginConstructionProduction(id,agent,body,4,parent,parentStep))
queue=ISTimedActionQueue.getTimedActionQueue(body);action=queue.current
action:start();action.action:forceComplete();action.action:perform();action.action:complete()
body:getCharacterActions():remove(action.action)
SAO.ResourceProduction.reconcileSaved(id,body)
local upkeep=rec.resourceProductionOutcomes and rec.resourceProductionOutcomes[#rec.resourceProductionOutcomes]
print("CONSUMER_ORIGINAL_USE",upkeep and upkeep.status,upkeep and upkeep.detail,f.target:getSharpness())
check("actual_original_upkeep_effect",upkeep~=nil and upkeep.status=="completed" and upkeep.nativeCredit==upkeep.id
 and upkeep.targetItemId==tostring(f.target:getID()) and f.target:getSharpness()>beforeSharpness)
local used=false
for _,input in ipairs(upkeep.inputEffects or {})do if input.itemId==stockId and input.keptNative and input.held then used=true end end
check("produced_stock_used_by_original_native_recipe",used)
check("requesting_use_closes_supply",P.reconcileRecipeConsumers(id,body) and supply.status=="completed"
 and supply.recipeSupply.consumerWorkId==upkeep.id)
local archive=SAO.Cognition.snapshot(id,true)
local craft,repair=0,0
for _,event in ipairs(archive and archive.experiences or {})do
 if event.kind=="material-crafting" and event.recipeId=="Base.MakeCrudeWhetstone" then craft=craft+1 end
 if event.kind=="tool-repair" and event.recipeId=="Base.SharpenBlade" then repair=repair+1 end
end
print("CONSUMER_ARCHIVE",archive,craft,repair,stockRow.experienceDelivered,upkeep.experienceDelivered)
check("independent_private_native_feedback",archive~=nil and craft==1 and repair==1)
local restored=__roundtrip(rec)
check("plain_native_person_save",restored.proceduralPlanning.purposes[supply.id].recipeSupply.consumerWorkId==upkeep.id
 and restored.resourceProductionOutcomes[1].outputs[1].itemId==stockId)
local forged=__roundtrip(stockRow);forged.detail="foreign receipt annotation"
check("forged_native_feedback_refused",SAO.Cognition.recipeProductionOutcome(id,forged)==false)
forged=__roundtrip(stockRow);forged.recipeId="Base.ForeignNativeRecipe"
check("foreign_recipe_feedback_refused",SAO.Cognition.recipeProductionOutcome(id,forged)==false)
check("terminal_replay_once",P.consumeRecipeProductionResult(id,stockRow) and P.consumeRecipeProductionResult(id,upkeep)
 and SAO.Cognition.recipeProductionOutcome(id,stockRow) and SAO.Cognition.recipeProductionOutcome(id,upkeep))
local replay=SAO.Cognition.snapshot(id,true)
check("feedback_replay_inert",replay~=nil and #replay.experiences==#archive.experiences)
-- A subsequent real native supply can become unneeded when the exact
-- original request finishes with different current held stock.
body:getInventory():Remove(produced);produced:setContainer(nil);f.target:setSharpness(.1)
local otherDemand=__roundtrip(d);otherDemand.id=d.id..":other-stock";otherDemand.consumerId=d.consumerId..":other-stock"
agent.state="IDLE"
local otherParent,otherRequest=P.planRecipeWork(id,Ctl.recipeWorkContext(id,body,otherDemand,nil,nil,{itemType=target.itemType,deficit=.9}))
local otherProducer
for _,s in ipairs(otherParent.steps)do if s.productionKind=="recipe-upkeep"then otherProducer=s end end
local otherStock=__roundtrip(stock);otherStock.id=stock.id..":other-stock";otherStock.consumerId=otherParent.id..":"..otherProducer.id
__seedHeldRecipeItem("Stone2");__seedHeldRecipeItem("Stone2")
local otherSupply,otherStep=P.planRecipeWork(id,Ctl.recipeWorkContext(id,body,otherStock,otherParent.id,otherProducer.id))
check("other_stock_native_supply_dispatch",otherStep~=nil and otherStep.verb=="produce"
 and Ctl.beginConstructionProduction(id,agent,body,5,otherSupply,otherStep))
queue=ISTimedActionQueue.getTimedActionQueue(body);action=queue.current
action:start();action.action:forceComplete();action.action:perform();action.action:complete();body:getCharacterActions():remove(action.action)
SAO.ResourceProduction.reconcileSaved(id,body)
local otherStockRow=rec.resourceProductionOutcomes[#rec.resourceProductionOutcomes]
check("other_stock_measured_production",otherStockRow.status=="completed"and otherStockRow.recipeId=="Base.MakeCrudeWhetstone")
P.refreshRecipeSupply(id,body,otherSupply.id)
local savedParentStatus=otherParent.status;otherParent.status="completed";P.reconcileRecipeConsumers(id,body)
check("forged_parent_completion_no_retirement",otherSupply.status=="maintained")
otherParent.status=savedParentStatus
local unused=body:getInventory():getItemFromType("Base.CrudeWhetstone");body:getInventory():Remove(unused);unused:setContainer(nil)
local differentStock=__seedHeldRecipeItem("CrudeWhetstone");P.refreshRecipeSupply(id,body,otherSupply.id)
agent.state="IDLE"
otherParent,otherRequest=P.planRecipeWork(id,Ctl.recipeWorkContext(id,body,otherDemand,nil,nil,{itemType=target.itemType,deficit=.9}))
check("other_stock_original_dispatch",otherRequest~=nil and Ctl.beginConstructionProduction(id,agent,body,6,otherParent,otherRequest))
queue=ISTimedActionQueue.getTimedActionQueue(body);action=queue.current
action:start();action.action:forceComplete();action.action:perform();action.action:complete();body:getCharacterActions():remove(action.action)
SAO.ResourceProduction.reconcileSaved(id,body)
local otherUse=rec.resourceProductionOutcomes[#rec.resourceProductionOutcomes]
check("other_stock_original_native_complete",otherParent.status=="completed"and otherUse.status=="completed"
 and otherUse.inputEffects[2].itemId==tostring(differentStock:getID()))
check("other_stock_retires_supplier_without_use_credit",P.reconcileRecipeConsumers(id,body)
 and otherSupply.status=="abandoned"and otherSupply.recipeSupply.consumerWorkId==nil
 and otherSupply.recipeSupply.retiredByWorkId==otherUse.id)
local retiredSave=__roundtrip(rec)
check("other_stock_retirement_plain_save",retiredSave.proceduralPlanning.purposes[otherSupply.id].recipeSupply.retiredByWorkId==otherUse.id)
local retirementEvents=#otherSupply.events;P.reconcileRecipeConsumers(id,body)
check("other_stock_retirement_replay_inert",#otherSupply.events==retirementEvents and otherSupply.recipeSupply.consumerWorkId==nil)
check("other_stock_dispatcher_released",P.recipePurpose(id)==nil)
body:getInventory():Remove(differentStock);differentStock:setContainer(nil)
body:getInventory():AddItemBlind(produced);produced:setContainer(body:getInventory())
archive=SAO.Cognition.snapshot(id,true)
-- A new privately retained upkeep request is interrupted by its physical owner
-- before native payment/effect, then its real native late completion is inert.
f.target:setSharpness(.1)
local interruptDemand=__roundtrip(d);interruptDemand.id=d.id..":interrupt";interruptDemand.consumerId=d.consumerId..":interrupt"
agent.state="IDLE"
local interruptedPurpose,interruptedStep=P.planRecipeWork(id,Ctl.recipeWorkContext(id,body,interruptDemand,nil,nil,{itemType=target.itemType,deficit=.9}))
check("private_interrupt_request",interruptedPurpose~=nil and interruptedStep~=nil and interruptedStep.status=="available")
check("normal_interrupt_dispatch",Ctl.beginConstructionProduction(id,agent,body,5,interruptedPurpose,interruptedStep))
queue=ISTimedActionQueue.getTimedActionQueue(body);action=queue.current
local interruptedWorkId=rec.resourceProductionWork.id
local interruptBefore=f.target:getSharpness()
action:start()
local interruptedSaved=__roundtrip(rec)
check("active_native_work_plain_save",interruptedSaved.resourceProductionWork.id==interruptedWorkId
 and interruptedSaved.proceduralPlanning.purposes[interruptedPurpose.id].admission.correlationId==interruptedWorkId)
SAO.ResourceProduction.interrupt(id,body,"isolated-higher-priority-work")
action:stop()
body:getCharacterActions():remove(action.action)
SAO.ResourceProduction.retryCraftCancellations()
local interrupted=SAO.ResourceProduction.outcome(id,interruptedWorkId)
print("CONSUMER_INTERRUPT",interrupted and interrupted.status,interrupted and interrupted.detail,rec.resourceProductionWork)
check("native_interruption_private_return",interrupted~=nil and interrupted.status=="interrupted"
 and interruptedPurpose.admission==nil and rec.resourceProductionWork==nil and f.target:getSharpness()==interruptBefore)
action:complete()
check("late_native_completion_inert",f.target:getSharpness()==interruptBefore and SAO.ResourceProduction.outcome(id,interruptedWorkId).status=="interrupted")
local afterInterrupt=SAO.Cognition.snapshot(id,true)
check("unperformed_interrupt_no_success_feedback",afterInterrupt~=nil and #afterInterrupt.experiences==#archive.experiences)
local stoppedSaved=__roundtrip(rec)
check("interrupted_person_save",stoppedSaved.proceduralPlanning.purposes[interruptedPurpose.id].admission==nil
 and stoppedSaved.resourceProductionWork==nil)
local function revokeNativeOwner(suffix,death)
 local demand=__roundtrip(d);demand.id=d.id..":"..suffix;demand.consumerId=d.consumerId..":"..suffix
 agent.state="IDLE"
 local purpose,step=P.planRecipeWork(id,Ctl.recipeWorkContext(id,body,demand,nil,nil,{itemType=target.itemType,deficit=.9}))
 if not purpose or not step or not Ctl.beginConstructionProduction(id,agent,body,6,purpose,step)then return false end
 local q=ISTimedActionQueue.getTimedActionQueue(body);local a=q.current;local workId=rec.resourceProductionWork.id
 local before=f.target:getSharpness();a:start()
 if death then rec.dead=true else SAO.Body.active[id]=nil end
 local refused=a:isValid()==false
 SAO.ResourceProduction.interrupt(id,body,"isolated-"..suffix.."-revocation")
 a:stop();a:perform();a:complete();body:getCharacterActions():remove(a.action)
 SAO.ResourceProduction.retryCraftCancellations()
 if death then rec.dead=nil else SAO.Body.active[id]=body end
 SAO.ResourceProduction.reconcileSaved(id,body)
 local result=SAO.ResourceProduction.outcome(id,workId)
 print("CONSUMER_REVOKED_OWNER",suffix,refused,result and result.status,result and result.nativeCompleted,purpose.admission)
 return refused and result~=nil and result.status~="completed" and result.nativeCompleted==false
  and purpose.admission==nil and rec.resourceProductionWork==nil and f.target:getSharpness()==before
end
check("body_death_prevents_native_effect",revokeNativeOwner("death",true))
check("body_transfer_prevents_native_effect",revokeNativeOwner("transfer",false))
local afterRevocation=SAO.Cognition.snapshot(id,true)
check("revoked_owner_no_success_feedback",afterRevocation~=nil and #afterRevocation.experiences==#archive.experiences)
local reload=__roundtrip(rec)
__nativeModData("SurvivorAwareness_Records").records[id]=reload
rec=reload;f.record=reload;agent.rec=reload
check("terminal_person_native_rebind",SAO.Identity.get(id)==reload and SAO.ResourceProduction.reconcileSaved(id,body)==true
 and reload.resourceProductionWork==nil)
check("restored_terminal_replay_once",P.consumeRecipeProductionResult(id,stockRow) and P.consumeRecipeProductionResult(id,upkeep)
 and SAO.Cognition.recipeProductionOutcome(id,stockRow) and SAO.Cognition.recipeProductionOutcome(id,upkeep))
local fullArchive=SAO.Cognition.snapshot(id,true)
check("restored_full_archive_preserved",fullArchive~=nil and #fullArchive.experiences==#archive.experiences)
local function quoted(s)
 return '"'..s:gsub('[%z\1-\31\\"]',function(c)
  if c=='"'then return '\\"'elseif c=='\\'then return '\\\\'else return string.format('\\u%04x',string.byte(c))end
 end)..'"'
end
local seen={}
local function json(value)
 local t=type(value)
 if t=="string"then return quoted(value)elseif t=="boolean"then return value and "true"or"false"
 elseif t=="number"then if value~=value or value==math.huge or value==-math.huge then error("nonfinite projection")end;return tostring(value)
 elseif t=="nil"then return "null"elseif t~="table"or seen[value]then error("nonplain/cyclic private projection")end
 seen[value]=true
 local keys={};local dense=true;local count=0
 for key in pairs(value)do keys[#keys+1]=key;count=count+1;if type(key)~="number"or key<1 or key~=math.floor(key)then dense=false end end
 dense=dense and count>0 and count==#value
 local fields={}
 if dense then for _,row in ipairs(value)do fields[#fields+1]=json(row)end
 else table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
  for _,key in ipairs(keys)do if type(key)~="string"and type(key)~="number"then error("nonplain projection key")end
   fields[#fields+1]=quoted(tostring(key))..":"..json(value[key])
  end
 end
 seen[value]=nil;return (dense and "["or"{")..table.concat(fields,",")..(dense and "]"or"}")
end
local refill=__nativeRefillObservations();local emptyTorch,partialTorch
for _,row in ipairs(refill.empty or {})do if row.targetItemId==refill.itemId and row.recipeId=="Base.RefillBlowTorch"then emptyTorch=row end end
for _,row in ipairs(refill.partial or {})do if row.targetItemId==refill.itemId and row.recipeId=="Base.RefillBlowTorch"then partialTorch=row end end
check("native_refill_quantity_observations",emptyTorch~=nil and partialTorch~=nil and emptyTorch.currentUses==0 and partialTorch.currentUses>0)
check("measured_private_refill_deficit",Ctl.recipeUpkeepTarget(emptyTorch).deficit==1
 and Ctl.recipeUpkeepTarget(partialTorch).deficit<1 and Ctl.recipeUpkeepTarget(partialTorch).deficit>0)
local bench=__prepareConsumerBench()
check("actual_unclaimed_native_bench",bench.object:getUsingPlayer()==nil and bench.initiallyUnclaimed==true)
body:getInventory():Remove(produced);produced:setContainer(nil)
f.target:setSharpness(.1)
local benchTarget
for _,row in ipairs(SAOJavaBridge:recipeUpkeepDemands(body)or{})do
 if row.targetItemId==tostring(f.target:getID())and row.recipeId=="Base.SharpenBladeWithGrindstone"then benchTarget=row end
end
local benchDemand={id="retained-bench:"..benchTarget.targetItemId,consumerId="held-item:"..benchTarget.targetItemId,
 kind="recipe-upkeep",sourceRevision=benchTarget.sourceRevision,targetItemId=benchTarget.targetItemId,
 targetSlotIndex=benchTarget.targetSlotIndex,desiredState=benchTarget.desiredState}
bench.object:setUsingPlayer(__nativeForeignBenchOwner())
local occupied=Ctl.recipeWorkContext(id,body,benchDemand,nil,nil,{itemType=benchTarget.itemType,deficit=.9})
local occupiedReady=false
for _,option in ipairs(occupied.options)do if option.recipeId=="Base.SharpenBladeWithGrindstone"and option.ready then occupiedReady=true end end
check("occupied_native_bench_not_ready",occupiedReady==false)
bench.object:setUsingPlayer(nil)
agent.state="IDLE"
local benchContext=Ctl.recipeWorkContext(id,body,benchDemand,nil,nil,{itemType=benchTarget.itemType,deficit=.9})
for _,option in ipairs(benchContext.options)do print("CONSUMER_BENCH_OPTION",option.recipeId,option.ready,option.reason,option.recipeWorkplace)
 for _,unmet in ipairs(option.unmet or{})do print("CONSUMER_BENCH_UNMET",unmet.reason)end
end
for n=0,body:getInventory():getItems():size()-1 do local item=body:getInventory():getItems():get(n);print("CONSUMER_BENCH_HELD",item:getFullType(),item:getID())end
local benchPurpose,benchStep=P.planRecipeWork(id,benchContext)
print("CONSUMER_BENCH_PLAN",benchPurpose and benchPurpose.recipeSupply.recipeId,benchStep and benchStep.status,bench.object:getUsingPlayer())
check("free_native_bench_private_ready",benchPurpose~=nil and benchStep~=nil and benchStep.status=="available"
 and benchStep.recipeId=="Base.SharpenBladeWithGrindstone" and bench.object:getUsingPlayer()==nil)
local originalBenchSprite=bench.object:getSprite()
bench.object:setSprite("crafted_01_121")
check("changed_native_bench_dispatch_refused",Ctl.beginConstructionProduction(id,agent,body,7,benchPurpose,benchStep)==false
 and rec.resourceProductionWork==nil and bench.object:getUsingPlayer()==nil)
bench.object:setSprite("crafted_01_120")
benchPurpose,benchStep=P.planRecipeWork(id,Ctl.recipeWorkContext(id,body,benchDemand,nil,nil,{itemType=benchTarget.itemType,deficit=.9}))
check("refused_bench_valid_reselection",benchStep~=nil and benchStep.status=="available" and benchStep.recipeId=="Base.SharpenBladeWithGrindstone")
check("normal_free_bench_dispatch",Ctl.beginConstructionProduction(id,agent,body,8,benchPurpose,benchStep))
check("native_bench_claim_exclusive",bench.object:isUsingPlayer(body)==true)
queue=ISTimedActionQueue.getTimedActionQueue(body);action=queue.current
local benchBefore=f.target:getSharpness()
action:start();action.action:forceComplete();action.action:perform();action.action:complete()
body:getCharacterActions():remove(action.action)
SAO.ResourceProduction.reconcileSaved(id,body)
local benchResult=rec.resourceProductionOutcomes[#rec.resourceProductionOutcomes]
check("native_bench_effect_and_release",benchResult.recipeId=="Base.SharpenBladeWithGrindstone"and benchResult.status=="completed"
 and f.target:getSharpness()>benchBefore and bench.object:getUsingPlayer()==nil and benchPurpose.admission==nil)
fullArchive=SAO.Cognition.snapshot(id,true)
check("full_private_archive_retained",__retainConsumerProjection("private-archive",json(fullArchive)))
check("full_person_save_retained",__retainConsumerProjection("person-save",json(__roundtrip(rec))))
check("native_outcome_projection_retained",__retainConsumerProjection("native-outcomes",json({stock=stockRow,upkeep=upkeep,
 acquisition=receipt,interruption=interrupted,bench=benchResult})))
