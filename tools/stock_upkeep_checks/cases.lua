local R=SAO.ResourceProduction
local function check(name,value) __check(name,value==true) end
local outputDemand={id="exact-output-demand",consumerId="upkeep-consumer",kind="recipe-stock",sourceRevision="registered-output-1",
    desiredType="Base.CrudeWhetstone",desiredAmount=1,consumerRecipeId="Base.SharpenBlade"}
local outputFixture=__stockFixture("stone","Base.MakeCrudeWhetstone","recipe-stock")
local unrelated=true
for _,recipeId in ipairs({"Base.SawLogs","Base.RefillBlowTorch","Base.OpenBoxOfBullets50"}) do
    if R.recipePolicy(outputFixture.id,outputFixture.body,recipeId,outputDemand,outputFixture.step.recipeWorkplace)~=nil then unrelated=false end
end
check("unrelated_stock_recipe_refused",unrelated)
local f=__stockFixture("saw","Base.SawLogs","recipe-stock")
check("native_stock_admission",__stockBegin(f))
local row=__stockFinish(f)
check("native_three_outputs",row~=nil and row.status=="completed" and row.outputCount==3 and row.stockAvailable==true)
check("exact_native_payment",row~=nil and row.paymentMeasured==true and row.inputEffects[1].consumedNative==true
    and row.inputEffects[1].after.uses==0 and not f.body:getInventory():contains(f.native.items.Log))
check("retained_request_and_consumer",row~=nil and row.recipeDemand.consumerRecipeId=="Base.Wood_Bed"
    and f.purpose.cursor==2 and row.purposeDelivered==true)
check("plain_native_save",row~=nil and __roundtrip(row).outputs[1].itemType=="Base.Plank")
if not row then error("stock did not close") end

f=__stockFixture("saw","Base.SawLogs","recipe-stock")
check("successor_admission",__stockBegin(f));row=__stockFinish(f,true)
check("successor_preserves_completion",row~=nil and row.status=="completed" and row.nativeCredit==row.id
    and ISTimedActionQueue.getTimedActionQueue(f.body).current~=nil)

f=__stockFixture("saw","Base.SawLogs","recipe-stock");f.body.dropOutputs=true
check("drop_admission",__stockBegin(f));row=__stockFinish(f)
check("world_output_not_stock",row~=nil and row.status=="completed" and row.outputCount==3 and row.held==false
    and row.stockAvailable==false and row.outputs[1].custody=="world-unacquired" and row.outputs[1].world.x==0
    and f.purpose.cursor==1)

f=__stockFixture("replace","Base.ReplaceHacksawBlade","recipe-upkeep","condition")
check("replacement_admission",__stockBegin(f));row=__stockFinish(f)
check("native_replacement_effect",row~=nil and row.nativeCompleted and row.improved and row.replacementItemId~=nil
    and row.replacementItemId~=row.targetItemId and row.targetRetained==false and row.outputs[1].held
    and row.inputEffects[1].destroyedNative and __callbackCount()==1)

f=__stockFixture("refuel","Base.RefillBlowTorch","recipe-upkeep","uses")
check("refill_admission",__stockBegin(f));row=__stockFinish(f)
if row then __projection("refill-effect",row) end
check("native_refill_and_kept_supply",row~=nil and row.nativeCompleted and row.improved and row.targetAfter.uses>row.targetBefore.uses
    and row.replacementItemId~=nil and row.inputEffects[2].keptNative
    and row.inputEffects[2].after.usesFloat<row.inputEffects[2].before.usesFloat and __callbackCount()==1)

f=__stockFixture("epoxy","Base.FixWithEpoxy","recipe-upkeep","condition")
check("multi_input_admission",__stockBegin(f));row=__stockFinish(f)
check("native_four_input_callback",row~=nil and row.nativeAttempted and #row.inputEffects==4 and row.paymentMeasured
    and row.inputEffects[3].after.uses<row.inputEffects[3].before.uses and __callbackCount()==1)

f=__stockFixture("tape-two","Base.FixWithDuctTape","recipe-upkeep","condition")
check("partial_split_admission",__stockBegin(f));row=__stockFinish(f)
check("native_split_payment",row~=nil and #row.inputEffects==3 and row.inputEffects[2].after.uses==0
    and row.inputEffects[3].after.uses==0 and row.paymentMeasured and __callbackCount()==1)

f=__stockFixture("grind","Base.SharpenBladeWithGrindstone","recipe-upkeep","sharpness")
check("one_target_station_admission",__stockBegin(f));row=__stockFinish(f)
check("native_station_callback",row~=nil and row.nativeAttempted and row.nativeCompleted and #row.inputEffects==1
    and __callbackCount()==1 and row.recipeWorkplace.key=="observed-surface")

f=__stockFixture("saw","Base.SawLogs","recipe-stock")
check("interrupt_admission",__stockBegin(f));R.interrupt(f.id,f.body,"higher-purpose")
row=f.rec.resourceProductionOutcomes and f.rec.resourceProductionOutcomes[1]
check("unperformed_interrupt_no_credit",row~=nil and row.status=="interrupted" and not row.nativeAttempted and not row.nativeCredit
    and f.body:getInventory():contains(f.native.items.Log))

for _,member in ipairs({
    {"adhesive","Base.FixWithAdhesiveTape","condition"},{"zipties","Base.FixWithZipties","condition"},
    {"glue","Base.FixWithGlue","condition"},{"woodglue","Base.FixWithWoodGlue","condition"},
    {"epoxy-rags","Base.FixWithEpoxyAndRags","condition"},{"whetstone","Base.SharpenBlade","sharpness"},
    {"file-blade","Base.SharpenBladePoorlyWithFile","sharpness"},{"small-replace","Base.ReplaceSmallSawBlade","condition"},
    {"fix","Base.FixSaw","condition"}}) do
    f=__stockFixture(member[1],member[2],"recipe-upkeep",member[3])
    local admitted=__stockBegin(f);row=admitted and __stockFinish(f)
    if row then __projection("family-"..member[1],row) end
    check("repair_family_"..member[1]:gsub("-","_"),row~=nil and row.nativeAttempted and row.nativeCompleted and row.paymentMeasured and __callbackCount()==1)
end
f=__stockFixture("stone","Base.MakeCrudeWhetstone","recipe-stock")
check("whetstone_stock_admission",__stockBegin(f));row=__stockFinish(f)
check("native_whetstone_stock",row~=nil and row.status=="completed" and row.outputCount==1 and row.outputs[1].itemType=="Base.CrudeWhetstone"
    and #row.inputEffects==2 and row.inputEffects[1].consumedNative and row.inputEffects[2].consumedNative)

f=__stockFixture("replace","Base.ReplaceHacksawBlade","recipe-upkeep","condition")
check("missing_destroy_admission",__stockBegin(f));__omitDestroy=true;row=__stockFinish(f)
check("missing_native_destroy_no_credit",row~=nil and row.status~="completed" and not row.nativeCompleted and not row.nativeCredit)

f=__stockFixture("grind","Base.SharpenBladeWithGrindstone","recipe-upkeep","sharpness")
check("refused_engine_admission",__stockBegin(f))
local original=HandcraftLogic.new
HandcraftLogic.new=function(...)
    local logic=original(...);logic.performCurrentRecipe=function() return false end;return logic
end
row=__stockFinish(f);HandcraftLogic.new=original
check("refused_engine_no_completion",row~=nil and row.nativeAttempted and not row.nativeCompleted and not row.nativeCredit and __callbackCount()==0)

f=__stockFixture("saw","Base.SawLogs","recipe-stock")
local options=R.recipeOptions(f.id,f.body,f.step.recipeDemand,{{recipeId=f.step.recipeId,sourceRevision=f.step.sourceRevision,knowledgeKind="intrinsic"}})
check("selected_means_plain_options",#options==1 and options[1].ready and #options[1].recipeInputs==2 and options[1].requirements.recipe=="Base.SawLogs")
local denied=R.recipeOptions(f.id,f.body,f.step.recipeDemand,{{recipeId=f.step.recipeId,sourceRevision=f.step.sourceRevision,knowledgeKind="acquired"}})
check("missing_means_acquisition_refuse",#denied==0)
local reserved=ModData.getOrCreate("SurvivorAwareness_WorldSources");reserved.reservations={foreign={status="reserved",itemId=f.step.recipeInputs[1].items[1].itemId}}
check("current_input_reservation_refuse",__stockBegin(f)==false)
reserved.reservations={}

f=__stockFixture("saw","Base.SawLogs","recipe-stock")
f.rec.resourceProductionSequence=32
check("checkpoint_admission",__stockBegin(f))
local history={}
for n=1,32 do history[n]={id="resource-production/"..f.id.."/"..n,sequence=n,actorId=f.id,purposeId="prior-purpose",purposeDelivered=false,experienceDelivered=false} end
f.rec.resourceProductionOutcomes=history
local q=ISTimedActionQueue.getTimedActionQueue(f.body);local a=q.current
a:start();a.action.nativeFinished=true;a:perform();a:complete()
check("acknowledged_checkpoint_retained",f.rec.resourceProductionWork~=nil and f.rec.resourceProductionWork.terminalReceipt~=nil
    and f.rec.resourceProductionWork.terminalReceipt.nativeAcknowledged and not q.current)
local restored=__roundtrip(f.rec);f.rec=restored;__records[f.id]=restored;SAO.Controller.agents[f.id].rec=restored
f.purpose=restored.proceduralPlanning.purposes["purpose-1"];f.step=f.purpose.steps[1]
restored.resourceProductionOutcomes[1].purposeDelivered=true;restored.resourceProductionOutcomes[1].experienceDelivered=true
check("saved_checkpoint_once",R.reconcileSaved(f.id,f.body)==true and restored.resourceProductionWork==nil
    and restored.resourceProductionOutcomes[#restored.resourceProductionOutcomes].status=="completed" and f.purpose.cursor==2)
local receiptCount=#restored.resourceProductionOutcomes
R.reconcileSaved(f.id,f.body)
check("checkpoint_replay_inert",#restored.resourceProductionOutcomes==receiptCount)

f=__stockFixture("fix","Base.FixSaw","recipe-upkeep","condition")
local inputIndex=f.recipe:getIndexForIO(f.recipe:getInputs():get(1))
local requirement=SAO.Material.recipeRequirement(f.policy,inputIndex)
check("source_native_slot_requirement",requirement~=nil and requirement.index==inputIndex and requirement.recipeId=="Base.FixSaw"
    and SAO.Material.recipeObservedType(requirement,"Base.File"))
local sourceStore=ModData.getOrCreate("SurvivorAwareness_WorldSources")
local reservation={id="controlled-source-reservation",actorId=f.id,itemId=f.native.items.File:getID(),itemType="Base.File",status="reserved",recipeRequirement=requirement}
sourceStore.reservations[reservation.id]=reservation
check("bound_native_ingredient_current",SAO.SourceUse.recipeInputCurrent(reservation,f.native.items.File,f.body))
f.native.items.File:setConditionNoSound(0)
check("changed_native_ingredient_refuse",SAO.SourceUse.recipeInputCurrent(reservation,f.native.items.File,f.body)==false)
f.native.items.File:setConditionNoSound(8);reservation.recipeRequirement.declaration="changed source declaration"
check("changed_native_slot_refuse",SAO.SourceUse.recipeInputCurrent(reservation,f.native.items.File,f.body)==false)
sourceStore.reservations[reservation.id]=nil

f=__stockFixture("tape","Base.FixWithDuctTape","recipe-upkeep","condition")
inputIndex=f.recipe:getIndexForIO(f.recipe:getInputs():get(1))
requirement=SAO.Material.recipeRequirement(f.policy,inputIndex)
local outstanding=SAO.Material.recipeOutstanding(requirement,{{itemId=tostring(f.native.items.DuctTape:getID()),itemType="Base.DuctTape",currentUses=1,nativeEligible=true}})
check("partial_native_outstanding",outstanding~=nil and outstanding.remainingFraction==.5 and outstanding.quantityUnit=="native-slot-fraction")
local duplicate=SAO.Material.recipeOutstanding(requirement,{{itemId="same",itemType="Base.DuctTape",currentUses=1,nativeEligible=true},{itemId="same",itemType="Base.DuctTape",currentUses=1,nativeEligible=true}})
check("outstanding_double_spend_refuse",duplicate==nil)

f=__stockFixture("saw","Base.SawLogs","recipe-stock");f.step.recipeDemand.desiredAmount=6
check("partial_demand_admission",__stockBegin(f));row=__stockFinish(f)
check("partial_stock_keeps_demand",row~=nil and row.status=="completed" and row.requestedOutputAmount==3
    and row.afterAvailableAmount==3 and not row.stockAvailable and row.recipeDemand.desiredAmount==6 and f.purpose.cursor==1)
local availability=row and R.recipeOutputAvailability(f.id,f.body,row.id)
check("fresh_partial_stock_availability",availability~=nil and availability.totalAvailableAmount==3 and availability.requestedStockAvailable==false)

f=__stockFixture("saw","Base.SawLogs","recipe-stock");f.body.consumeSuccessorOutputs=true
check("consuming_successor_admission",__stockBegin(f));row=__stockFinish(f,true)
availability=row and R.recipeOutputAvailability(f.id,f.body,row.id)
check("consuming_successor_preserves_history",row~=nil and row.status=="completed" and row.outputCount==3
    and row.measuredAt==100 and availability~=nil and availability.availableAmount==0 and availability.totalAvailableAmount==0)

f=__stockFixture("grind","Base.SharpenBladeWithGrindstone","recipe-upkeep","sharpness")
check("native_station_free_before_admission",f.native.object:getUsingPlayer()==nil)
check("native_station_claimed",__stockBegin(f) and f.native.object:getUsingPlayer()==f.native.body)
row=__stockFinish(f)
check("native_station_released",row~=nil and f.native.object:getUsingPlayer()==nil)
f=__stockFixture("grind","Base.SharpenBladeWithGrindstone","recipe-upkeep","sharpness")
local other=__stockReset("empty").body
f.native.object:setUsingPlayer(other)
check("occupied_native_station_refuse",__stockBegin(f)==false and f.native.object:getUsingPlayer()==other)
