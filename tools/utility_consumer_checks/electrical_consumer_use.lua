-- Original consumer join after the preserved native electrical service.
local id=__record.id;local P,C,N=SAO.ProceduralPlanning,SAO.Cooking,SAO.Needs
local function check(name,v)print("CONSUMER_CHECK "..name.."="..tostring(v==true));assert(v,name)end
__load(__game.."/media/lua/shared/TimedActions/ISEatFoodAction.lua")
__load(__game.."/media/lua/shared/TimedActions/ISTransferAction.lua")
__load(__unit.."/mod/42.20/media/lua/client/SAO_SourceUse.lua")
__load(__unit.."/mod/42.20/media/lua/client/SAO_Needs.lua")
local ready=P.poweredMeal(id)
check("same_original_meal_ready",ready and ready.purposeId==__foodPurpose.id and tostring(ready.foodItemId)==tostring(__food:getID()))
local step=__foodPurpose.steps[__foodPurpose.cursor]
local accepted=C.begin(id,body,{purposeId=__foodPurpose.id,purposeStepId=step.id,acquiredItemId=__food:getID(),privateFood=true,expectedSourceId=ready.applianceSourceId})
check("original_cooking_owner_admitted",accepted==true)
local minutes,iterations=0,0
while __record.cookingWork and minutes<300 and iterations<800 do
 iterations=iterations+1
 local status=C.tick(id,body)
 print("COOKING_STAGE",status,__record.cookingWork and __record.cookingWork.stage,__food:getCookingTime(),__food:isCooked())
 local q=ISTimedActionQueue.getTimedActionQueue(body)
 if q.current then check("original_consumer_action_start",__native("start",q.current.action)==true);check("original_consumer_action_clock",__native("finish",q.current.action)==true)end
 if __record.cookingWork and __record.cookingWork.stage=="heat"then
  local time=getGameTime();time:setTimeOfDay(time:getTimeOfDay()+1/60)
  local container=__food:getContainer();local appliance=container and container:getParent()
  check("heat_updates_actual_deposited_native_appliance",appliance and instanceof(appliance,"IsoStove"))
  for frame=1,120 do appliance:update();__food:update()end
  generator:update();minutes=minutes+1
 end
 if status=="unavailable"or status=="interrupted"or status=="no-effect"then break end
end
local row=C.outcome(id,__record.cookingSequence)
__native("dump","consumer-cooking",{record=__record,receipt=row,native=__native("facts"),stove=__native("stove"),minutes=minutes})
check("original_native_food_prepared",row and row.status=="completed"and row.nativeCredit==row.id and row.heatObserved and row.retrieved and __food:isCooked()and body:getInventory():contains(__food))
check("original_food_parent_completed",__foodPurpose.status=="completed")
local before=N.read(body)
check("original_food_use_queued",N.eatCarried(id,body)==true)
local q=ISTimedActionQueue.getTimedActionQueue(body)
if q.current then check("original_food_use_start",__native("start",q.current.action)==true);check("original_food_use_clock",__native("finish",q.current.action)==true)end
local after=N.read(body)
check("native_hunger_reduced",before and after and after.hunger<before.hunger)
local full=SAO.Cognition.snapshot(id,true);local bounded=SAO.Cognition.snapshot(id,false)
__native("dump","whole-consumer",{consumerQualified=true,captureHours=SAO.History.countyHours(),record=__record,native=__native("facts"),beforeNeed=before,afterNeed=after,full=full,bounded=bounded})
__native("dump","whole-full",full);__native("dump","whole-bounded",bounded)
local saved=__native("roundtrip",__record,"whole-person");__native("dump","whole-saved-person",saved)
print("PASS actual requested native electrical service / original preparation / original food use")
