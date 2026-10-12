local function check(name,value)__check(name,value==true);if not value then error(name)end end
local id,body=__consumer.id,__consumer.body
local record=SAO.Identity.get(id)
check("workspace_same_native_person",record~=nil and SAO.Body.get(id)==body)
SAO.Perception.observeRecipeWorkplaces(id,body)
local available=SAO.Perception.recipeWorkplaces(id,body)
check("workspace_none_precreated",#available==0)
print("WORKSPACE_FIRST_PRIVATE_PROBE",id,record and record.bodyOwnerToken,body:getPerkLevel(Perks.Woodwork),body:getPerkLevel(Perks.Maintenance))
local P,Ctl=SAO.ProceduralPlanning,SAO.Controller
check("workspace_normal_model_defaults",SAO.Cognition.ensureGameDefaults()==true)
local agent={rec=record,state="IDLE",stateSince=0,nextDecisionAt=0};Ctl.agents[id]=agent
local targets=SAOJavaBridge:recipeUpkeepDemands(body);local target
for _,row in ipairs(targets or{})do if row.targetItemId==tostring(__consumer.target:getID())and row.recipeId=="Base.SharpenBlade"then target=row end end
check("workspace_original_native_deficit",target~=nil)
local demand={id="retained-workspace-upkeep:"..target.targetItemId,consumerId="held-item:"..target.targetItemId,kind="recipe-upkeep",
    sourceRevision=target.sourceRevision,targetItemId=target.targetItemId,targetSlotIndex=target.targetSlotIndex,desiredState=target.desiredState}
local context=Ctl.recipeWorkContext(id,body,demand,nil,nil,{itemType=target.itemType,deficit=.9})
local parent,parentStep=P.planRecipeWork(id,context)
print("WORKSPACE_UPKEEP_PLAN",parent and parent.id,parent and parent.status,parent and parent.recipeSupply.recipeId,parentStep and parentStep.id)
check("workspace_original_private_choice",parent~=nil and parent.recipeSupply.recipeId=="Base.SharpenBlade")
local requesting;for _,step in ipairs(parent.steps)do if step.productionKind=="recipe-upkeep"then requesting=step end end
local needs=SAOJavaBridge:recipeSupplyNeeds(body,requesting.recipeId);local stock
for _,slot in ipairs(needs.slots or{})do if slot.remainingFraction>0 then for _,item in ipairs(slot.alternatives or{})do
    if item.itemType=="Base.CrudeWhetstone"then stock={id="retained-workspace-stock:"..parent.id,consumerId=parent.id..":"..requesting.id,kind="recipe-stock",
        sourceRevision=needs.nativeRevision,desiredType=item.itemType,desiredAmount=item.desiredAmount,quantityUnit=item.quantityUnit,consumerRecipeId=requesting.recipeId}end
end end end
check("workspace_original_stock_gap",stock~=nil)
local supply,step=P.planRecipeWork(id,Ctl.recipeWorkContext(id,body,stock,parent.id,requesting.id))
print("WORKSPACE_STOCK_PLAN",supply and supply.id,supply and supply.status,supply and supply.recipeSupply.recipeId,step and step.id,step and step.status)
check("workspace_private_stock_choice",supply~=nil and supply.recipeSupply.recipeId=="Base.MakeCrudeWhetstone")

-- Exact native queue completion is the isolated animation-end port. Selection,
-- dispatch, validity, payment, placement and private acceptance remain owned.
local function finishNative()
 local queue=ISTimedActionQueue.getTimedActionQueue(body);local action=queue.current
 if not action then error("normal native action absent")end
 print("WORKSPACE_NATIVE_ACTION",action.Type,action:isValid(),action:isValidStart())
 local perform=action.perform
 function action:perform()
  local ok,result=pcall(perform,self);print("WORKSPACE_NATIVE_PERFORM",ok,result)
  if not ok then error(result)end;return result
 end
 if not action.action:isStarted()then action:start()end;action.action:forceComplete();action.action:perform();action.action:complete()
 body:getCharacterActions():remove(action.action)
 return action
end
local function settleInspection(p)
 local context=agent.forageInspection
 if not context then error("normal private inspection absent")end
 print("WORKSPACE_INSPECTION",context.sourceId,context.x,context.y)
 local ok,why=SAO.WorldSources.inspectContainer(id,body,context)
 print("WORKSPACE_INSPECTION_RESULT",ok,why)
 agent.forageInspection=nil;SAO.Locomotion.jobs[id]=nil;agent.state="IDLE"
 return ok
end
check("workspace_unknown_ingredients",#Ctl.recipeInputOffers(id,body,supply,step).options==0)
check("workspace_normal_donor_inspection_dispatch",Ctl.advanceRecipeWork(id,agent,body,1,supply,step))
check("workspace_actual_private_donor_inspection",settleInspection(supply))
for n=1,2 do
 supply,step=P.planRecipeWork(id,Ctl.recipeWorkContext(id,body,stock,parent.id,requesting.id))
 print("WORKSPACE_INGREDIENT_STEP",n,step and step.id,step and step.status)
 if not step or not step.recipeRequirement then error("native ingredient demand absent")end
 if not Ctl.advanceRecipeWork(id,agent,body,n+1,supply,step)then error("normal ingredient dispatch refused")end
 local result=SAO.SourceUse.onMovementDone(id,body,"arrived")
 if result=="moving"then result=SAO.SourceUse.onMovementDone(id,body,"arrived")end
 if result~="using"then error("native ingredient queue absent:"..tostring(result))end
 finishNative()
 if SAO.SourceUse.tick(id,body)~="completed"then error("native ingredient transfer incomplete")end
 agent.state="IDLE";SAO.Locomotion.jobs[id]=nil
end
check("workspace_native_stones_held",body:getInventory():getCountTypeRecurse("Base.Stone2")==2)
local rememberedTypes={};local refreshedFullList=false
for _,place in pairs(SAO.Perception.knownPlaces(id,true)or{})do for _,fact in pairs(place.sourceFacts or{})do
 for _,itemType in ipairs(fact.rememberedItemTypes or{})do rememberedTypes[itemType]=true end
 if fact.observedItems~=nil then refreshedFullList=true end
end end
check("workspace_prop_acquired_type_memory_survives_transfer",rememberedTypes["Base.Log"] and rememberedTypes["Base.TreeBranch2"] and rememberedTypes["Base.Twine"] and not refreshedFullList
 and body:getInventory():getCountTypeRecurse("Base.Plank")==0)
supply,step=P.planRecipeWork(id,Ctl.recipeWorkContext(id,body,stock,parent.id,requesting.id))
print("PROP_ORIGINAL_PENDING_STEP",step and step.id,step and step.verb,step and step.status,supply and supply.status)
for _,blocker in ipairs(supply.blockers or{})do print("PROP_ORIGINAL_BLOCKER",blocker)end
for _,anchor in ipairs(SAO.Perception.recipeWorkplaces(id,body))do print("PROP_EXISTING_SURFACE",anchor.key,anchor.genericSurface,anchor.x,anchor.y)end
check("workspace_original_recipe_blocked_on_surface",step.verb=="produce"and step.status=="blocked")
local context=Ctl.workspaceContext(id,body,supply,step)
print("PROP_NATIVE_WORKSPACE_OPTIONS",context and #context.options)
for _,option in ipairs(context and context.options or{})do
 print("PROP_NATIVE_WORKSPACE_OPTION",option.entityId,option.ready,option.reason,option.inputSourcesKnown)
end
check("workspace_prop_original_native_stool_offered",context~=nil and #context.options>0)
__consumerAllowApproach=true
check("workspace_prop_ordinary_workspace_dispatch",Ctl.advanceRecipeWork(id,agent,body,5,supply,step))
local workspacePurpose,workspaceStep=P.workspacePurpose(id)
print("PROP_PRIVATE_SELECTED",workspacePurpose and workspacePurpose.workspaceConstruction.entityId,workspaceStep and workspaceStep.id)
check("workspace_prop_actual_ordinary_stool_choice",workspacePurpose~=nil and workspacePurpose.workspaceConstruction.entityId=="Base.Log_Stool")
for n=1,5 do
 local current=Ctl.workspaceContext(id,body,supply,step)
 workspacePurpose,workspaceStep=P.planWorkspaceConstruction(id,current)
 print("PROP_MATERIAL_STEP",n,workspaceStep and workspaceStep.id,workspaceStep and workspaceStep.verb)
 if not workspaceStep or not workspaceStep.recipeRequirement then error("native prop material requirement absent")end
 if agent.forageInspection and not settleInspection(workspacePurpose)then error("native prop inspection failed")end
 if not record.worldSourceReservation then
  if not Ctl.advanceRecipeWork(id,agent,body,n+5,workspacePurpose,workspaceStep)then error("ordinary prop material dispatch refused")end
 end
 local result=SAO.SourceUse.onMovementDone(id,body,"arrived")
 if result=="moving"then result=SAO.SourceUse.onMovementDone(id,body,"arrived")end
 if result~="using"then error("native prop transfer queue absent:"..tostring(result))end
 finishNative()
 if SAO.SourceUse.tick(id,body)~="completed"then error("native prop transfer incomplete")end
 agent.state="IDLE";SAO.Locomotion.jobs[id]=nil
end
local twine
for i=0,body:getInventory():getItems():size()-1 do local item=body:getInventory():getItems():get(i)
 if item:getFullType()=="Base.Twine"then twine=item end
end
local beforeTwine=twine and twine:getCurrentUses()
print("PROP_ACTUAL_ACQUIRED",body:getInventory():getCountTypeRecurse("Base.Log"),body:getInventory():getCountTypeRecurse("Base.TreeBranch2"),beforeTwine)
check("workspace_prop_actual_native_materials_acquired",body:getInventory():getCountTypeRecurse("Base.Log")==1
 and body:getInventory():getCountTypeRecurse("Base.TreeBranch2")==3 and beforeTwine==5)
-- Save and rebind the actual quiet personal owners before physical admission.
local pendingPerson=__roundtrip(record)
local pendingBelief=__roundtrip(SAO.Perception.beliefs[id])
check("workspace_pending_person_belief_plain_save",pendingPerson.proceduralPlanning.purposes[workspacePurpose.id].workspaceConstruction.builtWorkId==nil
 and pendingBelief.constructionSites~=nil)
__nativeModData("SurvivorAwareness_Records").records[id]=pendingPerson
SAO.Perception.beliefs[id]=pendingBelief;record=pendingPerson;agent.rec=pendingPerson
parent=record.proceduralPlanning.purposes[parent.id];supply=record.proceduralPlanning.purposes[supply.id]
step=supply.steps[supply.cursor];workspacePurpose=record.proceduralPlanning.purposes[workspacePurpose.id]
check("workspace_pending_actual_record_rebind",SAO.Identity.get(id)==pendingPerson and P.workspacePurpose(id)==workspacePurpose)
local readyContext=Ctl.workspaceContext(id,body,supply,step)
for _,option in ipairs(readyContext and readyContext.options or{})do
 print("WORKSPACE_READY_BUILD_OPTION",option.entityId,option.ready,option.reason,option.inputSourcesKnown,option.recipeInputs and #option.recipeInputs)
end
local buildDispatch=Ctl.tryWorkspaceForRecipe(id,agent,body,10,supply,step)
local debugPurpose,debugStep=P.workspacePurpose(id)
print("WORKSPACE_BUILD_DISPATCH_RESULT",buildDispatch,agent.state,debugPurpose and debugPurpose.status,
 debugStep and debugStep.id,debugStep and debugStep.status,debugPurpose and debugPurpose.admission,
 record.resourceProductionWork,record.worldSourceReservation,SAO.Needs.busy(body),SAOJavaBridge:hasPendingActions(body))
for _,row in ipairs(record.resourceProductionOutcomes or{})do print("WORKSPACE_BUILD_PREOUTCOME",row.kind,row.status,row.detail)end
check("workspace_normal_build_dispatch",buildDispatch)
workspacePurpose,workspaceStep=P.workspacePurpose(id)
local pending=record.resourceProductionWork
print("WORKSPACE_PENDING_BUILD",pending and pending.id,pending and pending.stage,workspaceStep and workspaceStep.status)
check("workspace_existing_physical_owner",pending~=nil and pending.kind=="build-place"and pending.purposeId==workspacePurpose.id)
local activePerson=__roundtrip(record);local activeBelief=__roundtrip(SAO.Perception.beliefs[id])
check("workspace_active_native_work_plain_save",activePerson.resourceProductionWork.id==pending.id
 and activePerson.proceduralPlanning.purposes[workspacePurpose.id].admission.correlationId==pending.id
 and activeBelief.constructionSites~=nil)
local queue=ISTimedActionQueue.getTimedActionQueue(body)
if not queue.current then
 local route=SAO.Locomotion.jobs[id]
 if not route then error("native build lacks action and approach")end
 __moveConsumerTo(math.floor(route.goal.x),math.floor(route.goal.y))
 print("WORKSPACE_APPROACH_TICK",SAO.ResourceProduction.tick(id,body),record.resourceProductionWork and record.resourceProductionWork.stage,
  SAO.Locomotion.jobs[id],body:getX(),body:getY(),SAO.Perception.constructionSiteCurrent(id,body,workspacePurpose.workspaceConstruction.site,true))
end
local completedAction=finishNative()
SAO.ResourceProduction.reconcileSaved(id,body)
local buildOutcomes=record.resourceProductionOutcomes or{}
local buildRow=buildOutcomes[#buildOutcomes]
print("WORKSPACE_BUILD_RESULT",buildRow and buildRow.status,buildRow and buildRow.detail,buildRow and buildRow.resultMeasurement,
 buildRow and buildRow.nativeAttempted,buildRow and buildRow.nativeCompleted,buildRow and buildRow.constructed,
 record.resourceProductionWork and record.resourceProductionWork.stage)
local producedParts=completedAction.item and completedAction.item.saoCreatedParts or{}
print("PROP_RETAINED_NATIVE_PARTS",#producedParts,completedAction.item,completedAction.item and completedAction.item.saoCreated)
for index,part in ipairs(producedParts)do print("PROP_ACTUAL_FINAL_PART",index,__className(part),part:getSpriteName(),part:getObjectIndex(),part:getEntityScript() and part:getEntityScript():getScriptObjectFullType(),body:canUseAsGenericCraftingSurface(part))end
local own=workspacePurpose.workspaceConstruction
local fresh=SAOJavaBridge:constructionCreated(body,producedParts,own.entityId,own.site.face,own.site.cursor,own.site.x,own.site.y,own.site.z)
print("PROP_NATIVE_READER_CURRENT",fresh,own.entityId,own.site.face,own.site.cursor,own.site.x,own.site.y)
check("workspace_native_full_construction",buildRow and buildRow.status=="completed"and buildRow.nativeCredit==buildRow.id
 and buildRow.kind=="build-place"and buildRow.resultMeasurement~=nil and type(buildRow.resultMeasurement.parts)=="table"
 and #buildRow.resultMeasurement.parts==1)
check("workspace_private_constructed_retained",workspacePurpose.workspaceConstruction.builtWorkId==buildRow.id
 and workspacePurpose.status~="completed")
check("workspace_prop_actual_partial_payment",beforeTwine-twine:getCurrentUses()==4 and twine:getContainer()==body:getInventory()
 and body:getInventory():getCountTypeRecurse("Base.Log")==0 and body:getInventory():getCountTypeRecurse("Base.TreeBranch2")==0)
local prop=body:getCell():getGridSquare(buildRow.resultMeasurement.parts[1].x,buildRow.resultMeasurement.parts[1].y,buildRow.resultMeasurement.parts[1].z):getObjects():get(buildRow.resultMeasurement.parts[1].objectIndex)
check("workspace_prop_actual_native_class_exact_source_entity",__className(prop)=="zombie.iso.objects.IsoThumpable"and prop:getEntityScript()==ScriptManager.instance:getGameEntityScript("Base.Log_Stool")
 and buildRow.resultMeasurement.parts[1].sourceEntityId=="Base.Log_Stool")
check("workspace_prop_authentic_native_part_relation",buildRow.resultMeasurement.relationshipStatus=="confirmed"
 and prop:getModData().SAOPhysicalResult.workId==buildRow.id)
check("workspace_prop_wrong_native_script_changed",__changePropScript(prop,"Base.Wood_TableLvl1"))
local wrong=SAOJavaBridge:constructionCreated(body,{prop},own.entityId,own.site.face,own.site.cursor,own.site.x,own.site.y,own.site.z)
check("workspace_prop_wrong_native_script_refused",wrong==nil)
check("workspace_prop_native_script_restored",__changePropScript(prop,"Base.Log_Stool"))
check("workspace_prop_exact_native_script_rejoins",SAOJavaBridge:constructionCreated(body,{prop},own.entityId,own.site.face,own.site.cursor,own.site.x,own.site.y,own.site.z)~=nil)
check("workspace_prop_negative_native_cold_roundtrip",__coldReloadConstructedParts(buildRow.resultMeasurement.parts)==1)
SAO.Perception.observeRecipeWorkplaces(id,body)
local before=false
for _,anchor in ipairs(SAO.Perception.recipeWorkplaces(id,body)or{})do if SAO.Perception.constructedWorkspaceMatches(id,body,buildRow.id,anchor)then before=true end end
check("workspace_prop_negative_cold_current_match",before)
check("workspace_prop_same_slot_replacement",__alterConstructedParts(buildRow.resultMeasurement.parts,"replace")==1)
SAO.Perception.observeRecipeWorkplaces(id,body)
local after=false
for _,anchor in ipairs(SAO.Perception.recipeWorkplaces(id,body)or{})do if SAO.Perception.constructedWorkspaceMatches(id,body,buildRow.id,anchor)then after=true end end
check("workspace_prop_unrelated_replacement_refused",after==false)
check("workspace_prop_negative_original_still_pending",workspacePurpose.status~="completed" and own.useWorkId==nil and supply.recipeSupply.consumerWorkId==nil and body:getInventory():getCountTypeRecurse("Base.CrudeWhetstone")==0)
