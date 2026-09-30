print=__nativePrint
SAOJavaBridge=__realBridge
instanceof=__nativeInstanceof; moduleDotType=__nativeModuleDotType
ArrayList=__nativeArrays; ItemTag=__nativeItemTag; CharacterStat=__nativeCharacterStat
CharacterTrait=__nativeCharacterTrait
CharacterActionAnims={Eat="Eat",Drink="Drink",TakePills="TakePills"}
function isServer() return false end
function isDebugEnabled() return false end
function getPlayerInventory() return nil end
CCampfireSystem={instance={getLuaObjectOnSquare=function()return nil end}}
luautils={stringStarts=function(v,p)return type(v)=="string" and string.sub(v,1,#p)==p end}
function ISBaseTimedAction:stop() self.baseStopped=true end
local body, C, n = __realBody, SAO.Cognition, 0
local function check(name,value) print("CASE "..name.."="..tostring(value));assert(value,"PRODUCER:"..name);n=n+1 end
body:getModData().SAOPersonId="a"
SAO.Body={get=function(id)return id=="a" and body or nil end}
SAO.Habits={used=function()return false end}
ISTimedActionQueue={add=function(action)__queued=action end,hasAction=function(action)return action==__queued end}
check("enabled",C.configure(0,60,3))
local function choose(kind)
    hours=hours+1
    local action,episode=C.choose("a",{actorId="a",worldHours=hours,hunger=kind=="food" and .7 or 0,
        thirst=kind=="water" and .7 or 0,fatigue=.1,eatAt=.3,drinkAt=.3,foodAllowed=kind=="food",
        waterAllowed=kind=="water",inspectionAllowed=false,knownFood=1,knownWater=1,knownPlaces=1,
        capabilities={cook=true,forage=false,treat=false}})
    assert(action==kind and episode,"native admission")
    C.started("a",episode,true,"fixture queue")
    return records.a.cognition.episodes[#records.a.cognition.episodes]
end
local function count()return #(records.a.cognition and records.a.cognition.experiences or {})end
local episode=choose("food")
body:getStats():set(CharacterStat.HUNGER,.5)
local action=ISEatFoodAction:new(body,__single,1)
check("food_construction_is_not_evidence",action and count()==0 and episode.executionStatus=="queued")
action:start()
check("native_start_is_attempted",count()==0 and episode.executionStatus=="attempted")
action:perform()
check("native_perform_is_not_completion",count()==0 and math.abs(body:getStats():get(CharacterStat.HUNGER)-.5)<.0001)
check("native_food_complete",action:complete()==true and not body:getInventory():contains(__single))
local fact=records.a.cognition.experiences[1]
check("native_food_delta_published",count()==1 and fact.kind=="consume" and fact.category=="food"
    and fact.status=="completed" and math.abs(fact.hungerDelta-.03)<.001
    and episode.status=="observed" and episode.outcome.success)
local revision=records.a.cognition.models.ordinary.revision
check("completion_settled_once",action.saoCognitionSettled and C.publish("a",action.saoCognitionAdmission,{
    kind="consume",category="food",itemType=__single:getFullType(),status="completed",
    detail="native-complete",hungerDelta=fact.hungerDelta}) and count()==1
    and records.a.cognition.models.ordinary.revision==revision)

episode=choose("water");body:getStats():set(CharacterStat.THIRST,.5)
local fluid=__bottle:getFluidContainer();local amount=fluid:getAmount()
action=ISDrinkFluidAction:new(body,__bottle,.25);action:start();action:perform()
check("carried_water_perform_not_evidence",count()==1 and episode.executionStatus=="attempted")
check("carried_water_native_complete",action:complete()==true and fluid:getAmount()<amount
    and body:getStats():get(CharacterStat.THIRST)<.5)
fact=records.a.cognition.experiences[2]
check("carried_water_delta_published",count()==2 and fact.category=="water" and fact.thirstDelta>0
    and episode.status=="observed" and episode.outcome.success)

episode=choose("water");body:getStats():set(CharacterStat.THIRST,.5)
amount=__sink:getFluidAmount()
action=ISTakeWaterAction:new(body,nil,__sink,false);action:start();action:perform()
check("fixture_water_perform_not_evidence",count()==2)
check("fixture_water_native_complete",action:complete()==true and __sink:getFluidAmount()<amount
    and body:getStats():get(CharacterStat.THIRST)<.5)
fact=records.a.cognition.experiences[3]
check("fixture_water_delta_published",count()==3 and fact.category=="water" and fact.thirstDelta>0
    and fact.itemType==nil and episode.status=="observed")

episode=choose("water");body:getStats():set(CharacterStat.THIRST,.5)
action=ISDrinkFluidAction:new(body,__bottle,.2);action:start()
action:stop();fact=records.a.cognition.experiences[4]
check("native_stop_censored",count()==4 and fact.status=="interrupted" and fact.thirstDelta==nil
    and episode.status=="censored")
amount=__sink:getFluidAmount()
action=ISTakeWaterAction:new(body,__bottle,__sink,false)
check("bottle_filling_not_consumption",action.saoCognitionAdmission==nil and count()==4 and __sink:getFluidAmount()==amount)
episode=choose("water");body:getStats():set(CharacterStat.THIRST,0)
action=ISDrinkFluidAction:new(body,__bottle,.1);action:start();action:perform();action:complete()
fact=records.a.cognition.experiences[5]
check("measured_no_relief_is_counterevidence",count()==5 and fact.status=="no-effect" and fact.thirstDelta==0
    and episode.status=="observed" and episode.outcome.success==false)
revision=records.a.cognition.models.ordinary.revision
action:complete()
check("repeated_native_complete_no_double_learning",count()==5 and records.a.cognition.models.ordinary.revision==revision)
episode=choose("water");body:getStats():set(CharacterStat.THIRST,.5)
action=ISDrinkFluidAction:new(body,__bottle,.1);action:start();action.fluidContainer=nil
local completed=pcall(function()action:complete()end)
fact=records.a.cognition.experiences[6]
check("native_callback_error_censored",not completed and count()==6 and fact.status=="unavailable"
    and fact.thirstDelta==nil and episode.status=="censored" and records.a.cognition.models.ordinary.revision==revision)
episode=choose("water")
action=ISDrinkFluidAction:new(body,__bottle,.1);action:start()
local getter=SAO.Body.get;SAO.Body.get=function()return nil end
action:complete();SAO.Body.get=getter
fact=records.a.cognition.experiences[7]
check("replaced_body_binding_censored",count()==7 and fact.status=="unavailable" and fact.thirstDelta==nil
    and episode.status=="censored" and records.a.cognition.models.ordinary.revision==revision)
episode=choose("water")
action=ISDrinkFluidAction:new(body,__bottle,.1)
SAOJavaBridge={getNeeds=function()return "f=0.1" end};action:start();SAOJavaBridge=__realBridge
action:complete();fact=records.a.cognition.experiences[8]
check("absent_baseline_is_not_zero_need",count()==8 and fact.status=="unavailable" and fact.thirstDelta==nil
    and episode.status=="censored" and records.a.cognition.models.ordinary.revision==revision)
fluid:Empty();fluid=__cola:getFluidContainer()
local row=__observeNativeItem(__cola)
check("native_cola_observation_retains_drink_identity",__cola:getFullType()=='Base.Pop2'
    and string.find(row,'|fluid=Cola',1,true) and string.find(row,'|cats=drink',1,true)
    and not string.find(row,'drink,water',1,true) and string.find(row,'|hydrationAmount=0.300000',1,true)
    and string.find(row,'|tainted=0',1,true))
episode=choose("water");body:getStats():set(CharacterStat.THIRST,.5)
local before=count();amount=fluid:getAmount();__queued=nil
check("native_world_cola_is_not_carried_before_acquisition",not body:getInventory():contains(__cola)
    and __colaContainer:contains(__cola) and SAOJavaBridge:findCarriedDrink(body)==nil)
local transfer=SAO.Needs.worldSourceTransferAction(body,__cola,__colaContainer,body:getInventory(),__colaContainer)
check("native_cola_transfer_uses_existing_owner",transfer and SAO.Needs.queueVerified(transfer))
transfer:transferItem(__cola)
check("native_cola_acquisition_is_not_thirst_relief",body:getInventory():contains(__cola) and not __colaContainer:contains(__cola)
    and count()==before and body:getStats():get(CharacterStat.THIRST)==.5)
check("native_safe_cola_uses_existing_carried_drink",SAO.Needs.drinkCarried("a",body)
    and __queued and __queued.item==__cola and count()==before)
action=__queued;action:start();action:perform();action:complete()
fact=records.a.cognition.experiences[before+1]
check("native_cola_measures_actual_thirst_relief",count()==before+1 and fluid:getAmount()<amount
    and fact.kind=="consume" and fact.category=="water" and fact.thirstDelta>0
    and body:getStats():get(CharacterStat.THIRST)<.5 and episode.status=="observed")
fluid:Empty();fluid:addFluid(Fluid.Get('Cola'),.2);fluid:addFluid(Fluid.TaintedWater,.1);__queued=nil
check("native_tainted_cola_is_not_queued_for_thirst",not SAO.Needs.drinkCarried("a",body) and __queued==nil)
-- Installed beverage blend whitelists reject Bleach; use a native Water
-- mixture that the engine actually admits, then prove the contamination.
fluid:Empty();fluid:addFluid(Fluid.Water,.2);fluid:addFluid(Fluid.Bleach,.1);__queued=nil
check("native_poison_fixture_contains_bleach",fluid:contains(Fluid.Bleach) and fluid:isPoisonous()
    and fluid:getPrimaryFluid()==Fluid.Water)
check("native_poison_water_primary_is_not_queued_for_thirst",not SAO.Needs.drinkCarried("a",body) and __queued==nil)

fluid=__dietCola:getFluidContainer();row=__observeNativeItem(__dietCola)
check("native_diet_cola_definition_is_hydration",__dietCola:getFullType()=='Base.Pop'
    and fluid:getPrimaryFluid()==Fluid.Get('ColaDiet') and string.find(row,'|hydrationAmount=0.300000',1,true))
body:getInventory():AddItem(__dietCola)
episode=choose("water");body:getStats():set(CharacterStat.THIRST,.5)
before=count();amount=fluid:getAmount();__queued=nil
check("native_diet_cola_uses_existing_carried_drink",SAO.Needs.drinkCarried("a",body)
    and __queued and __queued.item==__dietCola and count()==before)
action=__queued;action:start();action:perform();action:complete()
fact=records.a.cognition.experiences[before+1]
check("native_diet_cola_measures_actual_thirst_relief",count()==before+1 and fluid:getAmount()<amount
    and fact.thirstDelta>0 and body:getStats():get(CharacterStat.THIRST)<.5 and episode.status=="observed")
__queued=nil
check("native_no_medicine_does_not_queue",not SAO.Needs.takePills("a",body) and __queued==nil)
__pills:setReduceInfectionPower(50)
check("native_nonfood_infection_property_does_not_queue",not SAO.Needs.takePills("a",body) and __queued==nil)
__pills:setReduceInfectionPower(0)
body:getInventory():AddItem(__antibiotics)
local infectionPower=__antibiotics:getReduceInfectionPower()
__antibiotics:setReduceInfectionPower(math.huge)
check("native_infinite_medicine_property_does_not_queue",not SAO.Needs.takePills("a",body) and __queued==nil)
__antibiotics:setReduceInfectionPower(0/0)
check("native_nonfinite_medicine_property_does_not_queue",not SAO.Needs.takePills("a",body) and __queued==nil)
__antibiotics:setReduceInfectionPower(infectionPower)
before=count()
check("native_carried_medicine_uses_native_property_owner",SAO.Needs.takePills("a",body)
    and __queued and __queued.item==__antibiotics and count()==before)
action=__queued
check("native_medicine_selection_is_not_consumption",body:getInventory():contains(__antibiotics))
action:start();action:perform();action:complete()
check("native_medicine_complete_consumes_actual_item",not body:getInventory():contains(__antibiotics))
NATIVE_EAT_RESULT="PASS cognition native use "..n
