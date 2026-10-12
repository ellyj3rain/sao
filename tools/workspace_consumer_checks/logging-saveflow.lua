local function check(name,value)__check(name,value==true);if not value then error(name)end end
local id,body=__consumer.id,__consumer.body
local record=SAO.Identity.get(id)
local tree=__configureLoggingScene(__consumer.HandAxe)
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
local rememberedPlank=false;local refreshedFullList=false
for _,place in pairs(SAO.Perception.knownPlaces(id,true)or{})do for _,fact in pairs(place.sourceFacts or{})do
 for _,itemType in ipairs(fact.rememberedItemTypes or{})do if itemType=="Base.Plank"then rememberedPlank=true end end
 if fact.observedItems~=nil then refreshedFullList=true end
end end
check("workspace_acquired_type_memory_survives_transfer",rememberedPlank and not refreshedFullList
 and body:getInventory():getCountTypeRecurse("Base.Plank")==0)
supply,step=P.planRecipeWork(id,Ctl.recipeWorkContext(id,body,stock,parent.id,requesting.id))
check("workspace_original_recipe_blocked_on_surface",step.verb=="produce"and step.status=="blocked")

-- A declared physical stock change follows actual inspection and acquisition.
for index=__consumer.container:getItems():size()-1,0,-1 do
 local item=__consumer.container:getItems():get(index)
 if item:getFullType()=="Base.Plank"then __consumer.container:Remove(item);item:setContainer(nil)end
end
check("workspace_logging_donor_changed",__consumer.container:getItems():size()==0)
__consumerAllowApproach=true
local context=Ctl.workspaceContext(id,body,supply,step)
print("LOGGING_WORKSPACE_CONTEXT",context,context and #context.options)
check("workspace_logging_normal_workspace_dispatch",Ctl.advanceRecipeWork(id,agent,body,5,supply,step))
local wp,ws=P.workspacePurpose(id)
print("LOGGING_FIRST_WORKSPACE",wp and wp.id,ws and ws.id,agent.state,agent.forageInspection)
check("workspace_logging_actual_private_workspace",wp~=nil)
if agent.forageInspection then check("workspace_logging_fresh_empty_inspection",settleInspection(wp))end
agent.state="IDLE"
local materials=Ctl.tryWorkspaceForRecipe(id,agent,body,6,supply,step)
for _,purposeId in ipairs(record.proceduralPlanning.order or{})do
 local p=record.proceduralPlanning.purposes[purposeId];local current=p.steps[p.cursor]
 print("LOGGING_PRIVATE_PURPOSE",p.id,p.status,p.cursor,current and current.id,current and current.verb,
  p.recipeSupply and p.recipeSupply.recipeId,p.materialExtraction,p.blockers and p.blockers[1])
end
local sawRecipe=ScriptManager.instance:getCraftRecipe("Base.SawLogs")
print("LOGGING_SAW_RECIPE",sawRecipe,body:getInventory():getCountTypeRecurse("Base.Saw"),sawRecipe and body:isRecipeActuallyKnown(sawRecipe))
local sawPurpose,sawStep=P.recipePurpose(id)
local extractionContext=Ctl.extractionInputContext(id,body,sawPurpose,sawStep)
print("LOGGING_EXTRACTION_CONTEXT",#extractionContext.options,body:getPrimaryHandItem(),tree:getHealth())
local rawTree=SAOJavaBridge:extractionSourceObservation(body,tree,tree:getSquare(),3)
print("LOGGING_NATIVE_TREE_OBSERVATION",rawTree,rawTree and rawTree.present,instanceof(tree,"IsoTree"),tree:getObjectIndex(),body:getX(),body:getY())
local sources=SAO.Perception.extractionSources(id,body,"tree")
print("LOGGING_PRIVATE_TREE_SOURCES",#sources)
for _,source in ipairs(sources)do
 local binding=SAO.Perception.extractionSource(id,body,source)
 print("LOGGING_PRIVATE_TREE_BINDING",binding,source.sourceId,source.sourceRevision)
 if binding then
  local policy,why=SAO.ExtractionPolicy.describe("tree",body,binding.object,{id=sawPurpose.id,actorId=id,
   consumerId=sawPurpose.id..":"..sawStep.id,sourceId=source.sourceId,sourceRevision=source.sourceRevision},binding.observe,{radius=3})
  print("LOGGING_EXTRACTION_POLICY",policy,why)
 end
end
for _,option in ipairs(extractionContext.options or{})do
 print("LOGGING_EXTRACTION_OPTION",#option.id,option.id,option.source.sourceId,option.toolItemType)
end
local buildNeeds=SAOJavaBridge:recipeSupplyNeeds(body,"Base.Wood_TableLvl1")
for _,slot in ipairs(buildNeeds and buildNeeds.slots or{})do
 print("LOGGING_BUILD_SLOT",slot.index,slot.remainingFraction,slot.channelStatus)
 for _,alternative in ipairs(slot.alternatives or{})do if alternative.itemType=="Base.Plank"then
  local d={id="diagnostic-only",consumerId=wp.id,kind="recipe-stock",sourceRevision=buildNeeds.nativeRevision,
   desiredType=alternative.itemType,desiredAmount=alternative.desiredAmount,quantityUnit=alternative.quantityUnit,consumerRecipeId="Base.Wood_TableLvl1"}
  local c=Ctl.recipeWorkContext(id,body,d,wp.id,wp.steps[#wp.steps].id)
  print("LOGGING_NATIVE_STOCK_OPTIONS",#c.options)
  for _,o in ipairs(c.options)do print("LOGGING_NATIVE_STOCK_OPTION",o.recipeId,o.ready,o.reason)end
 end end
end
check("workspace_logging_normal_material_supply",materials)
print("LOGGING_SUPPLY",agent.state,record.resourceProductionWork,record.worldSourceReservation)
local extractionPurpose,extractionStep=P.extractionPurpose(id)
local nativeWork=record.resourceProductionWork
check("workspace_logging_private_extraction_admitted",extractionPurpose~=nil and nativeWork~=nil and nativeWork.kind=="extract-material"
 and nativeWork.purposeId==extractionPurpose.id)
local queue=ISTimedActionQueue.getTimedActionQueue(body);local action=queue.current
check("workspace_logging_original_tree_action",action~=nil and action.tree==tree and action:isValid())
local treeSquare=tree:getSquare();local sourceBefore=tree:getHealth();action:start()
print("LOGGING_TREE_START",sourceBefore,tree:getHealth(),tree:getLogYield(),record.resourceProductionWork and record.resourceProductionWork.stage)
check("workspace_logging_native_start_no_hit",tree:getHealth()==sourceBefore and tree:getObjectIndex()>=0)
local hitOk,hitWhy=pcall(action.animEvent,action,"ChopTree",nil)
print("LOGGING_TREE_HIT",hitOk,hitWhy,tree:getObjectIndex(),tree:getHealth(),tree:getSquare())
check("workspace_logging_actual_native_hit",hitOk and tree:getObjectIndex()<0)
action.action:forceComplete();action.action:perform();action.action:complete()
body:getCharacterActions():remove(action.action)
SAO.ResourceProduction.reconcileSaved(id,body)
local rows=record.resourceProductionOutcomes or{};local extractionRow=rows[#rows]
print("LOGGING_NATIVE_EXTRACTED",extractionRow and extractionRow.status,extractionRow and extractionRow.detail,
 extractionRow and extractionRow.newDrops and #extractionRow.newDrops,record.resourceProductionWork,
 extractionRow and extractionRow.nativeError,extractionRow and extractionRow.damage,extractionRow and extractionRow.sourceRemoved)
print("LOGGING_ACTUAL_WORLD_DROPS",treeSquare:getWorldObjects():size())
print("LOGGING_ACTUAL_HELD_LOGS",body:getInventory():getCountTypeRecurse("Base.Log"),tree:getLogYield())
for x=8,15 do for y=17,24 do
 local square=body:getCell():getGridSquare(x,y,0)
 for i=0,square:getWorldObjects():size()-1 do
  local item=square:getWorldObjects():get(i):getItem()
  print("LOGGING_ACTUAL_NEAR_DROP",x,y,item and item:getFullType(),item and item:getID())
 end
end end
check("workspace_logging_native_drops_measured",extractionRow~=nil and extractionRow.status=="completed"
 and extractionRow.nativeCredit==extractionRow.id and #extractionRow.newDrops>0)
check("workspace_logging_drops_not_stock_owned",body:getInventory():getCountTypeRecurse("Base.Log")==0
 and extractionPurpose.status~="completed" and extractionPurpose.materialExtraction.lastWorkId==extractionRow.id)

local extractionId=extractionPurpose.id;local sawId=sawPurpose.id;local supplierId=supply.id;local originalParentId=parent.id;local workspaceId=wp.id
local savedPending=__roundtrip(record);local savedPendingBelief=__roundtrip(SAO.Perception.beliefs[id])
check("workspace_logging_pending_drop_plain_save",savedPending.proceduralPlanning.purposes[extractionId].materialExtraction.lastWorkId==extractionRow.id
 and #savedPending.proceduralPlanning.purposes[extractionId].materialExtraction.newDrops==#extractionRow.newDrops
 and savedPending.proceduralPlanning.purposes[extractionId].materialExtraction.acquisitionId==nil
 and savedPendingBelief.extractionSources~=nil)
__nativeModData("SurvivorAwareness_Records").records[id]=savedPending;SAO.Perception.beliefs[id]=savedPendingBelief
record=savedPending;agent.rec=savedPending
parent=record.proceduralPlanning.purposes[originalParentId];supply=record.proceduralPlanning.purposes[supplierId]
wp=record.proceduralPlanning.purposes[workspaceId];sawPurpose=record.proceduralPlanning.purposes[sawId];sawStep=sawPurpose.steps[sawPurpose.cursor]
extractionPurpose=record.proceduralPlanning.purposes[extractionId]
check("workspace_logging_pending_drop_actual_rebind",SAO.Identity.get(id)==savedPending and P.extractionPurpose(id)==extractionPurpose
 and SAO.ResourceProduction.reconcileSaved(id,body) and body:getInventory():getCountTypeRecurse("Base.Log")==0)
agent.state="IDLE";SAO.Locomotion.jobs[id]=nil
check("workspace_logging_normal_extracted_input_dispatch",Ctl.advanceRecipeWork(id,agent,body,7,sawPurpose,sawStep))
print("LOGGING_DROP_RESERVATION",record.worldSourceReservation,agent.state,sawStep.sourceId,sawStep.itemId)
local dropResult=SAO.SourceUse.onMovementDone(id,body,"arrived")
if dropResult=="moving"then dropResult=SAO.SourceUse.onMovementDone(id,body,"arrived")end
print("LOGGING_DROP_MOVEMENT",dropResult)
check("workspace_logging_native_drop_queue",dropResult=="using")
finishNative()
check("workspace_logging_native_drop_transfer",SAO.SourceUse.tick(id,body)=="completed"
 and body:getInventory():getCountTypeRecurse("Base.Log")==1)
check("workspace_logging_extraction_acquired_closure",extractionPurpose.status=="completed"
 and extractionPurpose.materialExtraction.acquisitionId~=nil)
local acquisition=SAO.WorldSources.actionOutcome(extractionPurpose.materialExtraction.acquisitionId,id)
check("workspace_logging_saved_exact_native_drop_acquired",acquisition~=nil and acquisition.status=="completed"
 and acquisition.operation=="acquire" and acquisition.measurement=="native-item-transfer"
 and tostring(acquisition.itemId)==tostring(extractionPurpose.materialExtraction.selectedDropId)
 and acquisition.purposeId==sawPurpose.id and acquisition.purposeStepId==extractionPurpose.materialExtraction.parentStepId)
check("workspace_logging_saved_input_still_original",sawPurpose.status~="completed" and supply.status~="completed" and parent.status~="completed"
 and extractionPurpose.status=="completed" and body:getInventory():getCountTypeRecurse("Base.Plank")==0)
local eventCount=#SAO.Cognition.snapshot(id,true).experiences
check("workspace_logging_saved_extraction_replay_once",P.consumeExtractionProductionResult(id,extractionRow)
 and SAO.Cognition.materialExtractionOutcome(id,extractionRow)
 and extractionPurpose.status=="completed" and #SAO.Cognition.snapshot(id,true).experiences==eventCount)
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
check("workspace_full_private_archive_retained",__retainConsumerProjection("private-archive",json(SAO.Cognition.snapshot(id,true))))
check("workspace_full_person_save_retained",__retainConsumerProjection("person-save",json(__roundtrip(record))))
check("workspace_full_belief_save_retained",__retainConsumerProjection("private-belief",json(__roundtrip(SAO.Perception.beliefs[id]))))
check("workspace_canonical_outcomes_retained",__retainConsumerProjection("native-outcomes",json({extraction=SAO.ResourceProduction.outcome(id,extractionRow.id),acquisition=acquisition})))
