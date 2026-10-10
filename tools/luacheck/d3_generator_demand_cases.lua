-- Controlled Cooking receivers; actual Cooking and independent model modules
-- execute in installed Kahlua. Native power is covered by generator probes.
local checks = {}
local function check(name, value)
    checks[#checks+1] = name .. "=" .. tostring(value == true)
end
local function copy(v)
    if type(v) ~= "table" then return v end
    local out={} for k,x in pairs(v) do out[k]=copy(x) end return out
end
local models = SAO.CognitiveModels
local cognition = SAO.Cognition
local function utilityEvent(sequence, operation)
    return {id="generator/power-a/"..sequence, actorId="power-a", observerId="power-a",
        worldHours=10, occurredAtHours=10, kind="generator-operation", category="utilities",
        sourceId="J:machine", consumerId="E:stove", perspective="performed", status="completed",
        actionKind=operation, succeeded=true}
end
for _,operation in ipairs({"inspect","repair","fuel","connect","activate","verify-power"}) do
    local event=utilityEvent(1, operation)
    if operation=="repair" or operation=="fuel" then
        event.itemId,event.itemType=71,operation=="repair" and "Base.ElectronicsScrap" or "Base.PetrolCan"
        event.beforeValue,event.afterValue=1,2
    end
    check("model_accepts_"..operation:gsub("%-","_"), models.acceptsExperience(event))
    local bad=copy(event) bad.consumerId="E:"..string.rep("x",160)
    check("model_rejects_consumer_bound_"..operation:gsub("%-","_"), not models.acceptsExperience(bad))
end
local valid=utilityEvent(1,"verify-power")
for name,change in pairs({foreign_observer={observerId="other"}, physiological_credit={hungerDelta=.3},
    wrong_category={category="food"}, callback_only={succeeded=false}, wrong_source={sourceId="G:loose-item"},
    future={occurredAtHours=11}, covert_stock={foodPresent=true}, wrong_sequence={id="generator/power-a/0"}}) do
    local bad=copy(valid) for k,v in pairs(change) do bad[k]=v end
    check("model_rejects_"..name, not models.acceptsExperience(bad))
end
for _,name in ipairs({"ordinary","associative"}) do
    local state=models.newState(name)
    local result=models.observe(name,state,valid,4)
    check(name.."_retains_power", type(result)=="string" and result:sub(1,8)=="revised:" and #state.beliefOrder>0)
    local revision=state.revision
    check(name.."_replay_inert",models.observe(name,state,valid,4)=="ignored:duplicate" and state.revision==revision)
end
local function setupPower()
    newFixture()
    F.stove.powered=false
    SAO.WorldSources.generatorConsumer=function(body,object)
        if body~=F.body or object~=F.stove or not F.applianceReachable then return nil end
        return {sourceId="E:stove",fingerprint="stove-fp",revision="stove-r1",
            x=1,y=2,z=0,powered=F.stove.powered,kind="power-consumer"}
    end
end
setupPower()
local demand=SAO.Cooking.powerDemand(F.rec.id,F.body,{purposeId="meal:1"})
check("reached_use_retains_exact_food_and_consumer",demand~=nil and demand.consumer.sourceId=="E:stove"
    and demand.requestingPurposeId=="meal:1" and demand.foodItemId==71 and F.transferCalls==0 and F.xp==0)
if demand then demand.consumer.sourceId="forged" end
check("demand_return_detached",F.rec.cookingPowerDemand and F.rec.cookingPowerDemand.consumer.sourceId=="E:stove")
setupPower() F.applianceReachable=false
check("distant_use_has_no_power_request",SAO.Cooking.powerDemand(F.rec.id,F.body)==nil and F.rec.cookingPowerDemand==nil)
setupPower() F.allowed=false
check("refused_use_has_no_power_request",SAO.Cooking.powerDemand(F.rec.id,F.body)==nil)
setupPower() F.stove.powered=true
check("already_powered_has_no_request",SAO.Cooking.powerDemand(F.rec.id,F.body)==nil)
setupPower() F.changedSource="replacement"
check("changed_appliance_has_no_request",SAO.Cooking.powerDemand(F.rec.id,F.body)==nil)
setupPower()
local started=SAO.Cooking.begin(F.rec.id,F.body,{purposeId="meal:2"})
local status=SAO.Cooking.tick(F.rec.id,F.body)
check("unpowered_before_deposit_preserves_food",started==true and status=="no-effect"
    and F.transferCalls==0 and F.food.container==F.inventory and not F.food.cooked
    and F.rec.cookingPowerDemand~=nil and F.rec.cookingWork==nil and F.xp==0)
newFixture()
SAO.CognitiveModels,SAO.Cognition=models,cognition
local data={}
ModData={get=function(k)return data[k]end,getOrCreate=function(k)data[k]=data[k]or{};return data[k]end}
SAO.Hash={unit=function()return .2 end}
cognition.configure(.5,12,3)
local canonical
SAO.Generator={outcome=function(id,key)
    if canonical and id==F.rec.id and (key==canonical.id or key==canonical.sequence) then return copy(canonical) end
end}
local operations={"inspect","repair","fuel","connect","activate","verify-power"}
local nativeOwners={inspect="ISGeneratorInfoAction/SAO.Generator",repair="ISFixGenerator",fuel="ISAddFuel",
    connect="ISPlugGenerator",activate="ISActivateGenerator",["verify-power"]="SAO.Generator/NativePower"}
local tokens={inspect="utility:generator-inspected",repair="utility:generator-repaired",fuel="utility:generator-fuelled",
    connect="utility:generator-connected",activate="utility:generator-activated",["verify-power"]="utility:consumer-powered"}
local function receiptFor(sequence,operation)
    return {id="generator/"..F.rec.id.."/"..sequence,sequence=sequence,actorId=F.rec.id,
        operation=operation,token=tokens[operation],sourceId="J:machine",consumerId="E:stove",
        startedAt=9,atHours=10,status="completed",nativeOwner=nativeOwners[operation],nativeAttempted=true,
        nativeCompleted=true,nativeCredit="generator/"..F.rec.id.."/"..sequence,
        generatorAfter={sourceId="J:machine",inspected=true,condition=60,fuel=2,connected=true,active=true},
        inputItemId=71,inputItemType=operation=="repair" and "Base.ElectronicsScrap" or "Base.PetrolCan",
        inputConsumed=true,inputRetained=true,beforeCondition=56,afterCondition=60,beforeFuel=1,afterFuel=2,
        beforeInputAmount=3,afterInputAmount=2,beforeConnected=false,afterConnected=true,
        beforeActive=false,afterActive=true,outside=true,sourceCovered=true,consumerPowered=true}
end
for sequence,operation in ipairs(operations) do
    canonical=receiptFor(sequence,operation)
    check("canonical_"..operation:gsub("%-","_").."_teaches",cognition.generatorOutcome(F.rec.id,copy(canonical))==true
        and F.rec.cognition and #F.rec.cognition.experiences==sequence)
end
local ledger=F.rec.cognition
check("both_models_receive_same_private_utility",ledger.models.ordinary.revision==6 and ledger.models.associative.revision==6)
check("canonical_replay_teaches_once",cognition.generatorOutcome(F.rec.id,copy(canonical))==true and #ledger.experiences==6)
local forged=copy(canonical) forged.consumerId="E:replacement"
check("forged_generator_receipt_rejected",cognition.generatorOutcome(F.rec.id,forged)==false)
canonical=receiptFor(7,"verify-power") canonical.sourceCovered=false
check("activation_without_coverage_cannot_teach_power",cognition.generatorOutcome(F.rec.id,copy(canonical))==false
    and #ledger.experiences==6)
canonical=receiptFor(7,"fuel") canonical.afterInputAmount=2.5
check("unpaid_fuel_gain_cannot_teach",cognition.generatorOutcome(F.rec.id,copy(canonical))==false)
canonical=receiptFor(7,"activate") canonical.status="failed" canonical.nativeCredit=nil
check("failed_start_grants_no_experience",cognition.generatorOutcome(F.rec.id,copy(canonical))==true and #ledger.experiences==6)
local spoof=copy(ledger.experiences[1]) spoof.id="generator/"..F.rec.id.."/8"
check("public_experience_cannot_claim_generator_authority",cognition.experience(F.rec.id,spoof)==false)
__generatorDemandResults=table.concat(checks,"\n")
