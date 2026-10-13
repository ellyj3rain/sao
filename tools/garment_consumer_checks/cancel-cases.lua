local function check(name,value)print("CHECK "..name.."="..tostring(value==true));if not value then error(name)end end
local id="garment-person";local rec=SAO.Identity.get(id);local Ctl,P,R=SAO.Controller,SAO.ProceduralPlanning,SAO.ResourceProduction
check("garment_normal_native_identity",rec~=nil and rec==__record and SAO.Body.get(id)==body)
check("garment_ordinary_nil_token",rec.bodyOwnerToken==nil and body:getModData().SAOExternalToken==nil)
check("garment_default_models",SAO.Cognition.ensureGameDefaults())
local agent={rec=rec,state="IDLE",stateSince=0,nextDecisionAt=0};Ctl.agents[id]=agent
check("garment_initial_missing_native_materials",body:getInventory():getCountTypeRecurse("Base.Needle")==0 and body:getInventory():getCountTypeRecurse("Base.Thread")==0)
check("garment_initial_declared_worn_damage",__scene.clothing:getVisual():getHole(BloodBodyPartType.Torso_Upper)>0)
local advanced=Ctl.tryGarmentWork(id,agent,body,1)
local purpose,step=P.garmentPurpose(id)
print("GARMENT_NORMAL_FIRST_DISPATCH",advanced,agent.state,purpose and purpose.id,step and step.id,step and step.verb,step and step.status)
check("garment_actual_private_choice",purpose~=nil and purpose.interpretations~=nil and purpose.garmentMaintenance~=nil)
check("garment_world_stock_requires_private_inspection",__scene.container:isExplored()and agent.forageInspection~=nil and step.verb=="inspect")

local function finishNative()
 local q=ISTimedActionQueue.getTimedActionQueue(body);local action=q.current
 if not action then error("ordinary native action absent")end
 print("GARMENT_NATIVE_ACTION",action.Type,action:isValid(),action:isValidStart())
 if not action.action:isStarted()then action:start()end
 action.action:forceComplete();action.action:perform();action.action:complete()
 body:getCharacterActions():remove(action.action)
 return action
end
local inspected,acquired=0,0
while not rec.resourceProductionWork do
 if agent.forageInspection then
  local context=agent.forageInspection
  local ok,why=SAO.WorldSources.inspectContainer(id,body,context)
  print("GARMENT_NORMAL_INSPECTION",ok,why,context.sourceId)
  if not ok then error("normal signed garment source inspection refused:"..tostring(why))end
  inspected=inspected+1;agent.forageInspection=nil;SAO.Locomotion.jobs[id]=nil;agent.state="IDLE"
 elseif rec.worldSourceReservation then
  local result=SAO.SourceUse.onMovementDone(id,body,"arrived")
  if result=="moving"then result=SAO.SourceUse.onMovementDone(id,body,"arrived")end
  print("GARMENT_NORMAL_SOURCE_USE",result)
  if result~="using"then error("normal garment source action absent:"..tostring(result))end
  finishNative();local terminal=SAO.SourceUse.tick(id,body)
  if terminal~="completed"then error("native garment input transfer failed:"..tostring(terminal))end
  print("GARMENT_NATIVE_INPUT_HELD",body:getInventory():getCountTypeRecurse("Base.Needle"),body:getInventory():getCountTypeRecurse("Base.Thread"),purpose.cursor,purpose.admission and purpose.admission.owner)
  acquired=acquired+1;agent.state="IDLE";SAO.Locomotion.jobs[id]=nil
 else
  print("GARMENT_ACTUAL_PROGRESS_STOPPED",step and step.status,purpose and purpose.admission and purpose.admission.owner);break
 end
 local ok=Ctl.tryGarmentWork(id,agent,body,acquired+inspected+2)
 purpose,step=P.garmentPurpose(id)
 print("GARMENT_NORMAL_ADVANCE",ok,agent.state,step and step.id,step and step.verb,step and step.status)
end
check("garment_actual_signed_inspection",inspected>0)
check("garment_actual_three_role_acquisitions",acquired==3)
check("garment_existing_r_actual_dispatch",rec.resourceProductionWork.kind=="maintain-garment"and rec.resourceProductionWork.purposeId==purpose.id)
local work=rec.resourceProductionWork;local action=ISTimedActionQueue.getTimedActionQueue(body).current
check("garment_cancel_actual_normal_owner",action~=nil and work.purposeId==purpose.id)
if not action.action:isStarted()then action:start()end
local thread=body:getInventory():getFirstTypeRecurse("Thread");local uses=thread:getCurrentUses()
check("garment_cancel_original_owned_stop",action:stop()==true)
local row=R.outcome(id,work.id)
check("garment_cancel_canonical_no_payment",row and row.status=="interrupted"and row.nativeCredit==nil and thread:getCurrentUses()==uses and __scene.clothing:getPatchType(BloodBodyPartType.Torso_Upper)==nil and rec.resourceProductionWork==nil)
local count=#rec.resourceProductionOutcomes
check("garment_cancel_late_completion_inert",action:complete()==false and #rec.resourceProductionOutcomes==count and thread:getCurrentUses()==uses)
check("garment_cancel_original_use_not_claimed",purpose.status~="completed"and purpose.garmentMaintenance.physicalResultId==nil and purpose.garmentMaintenance.wornUseReceipt==nil)
