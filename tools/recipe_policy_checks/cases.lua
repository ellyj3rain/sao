local P = SAO.RecipePolicy
local function check(name, value) __check(name, value == true) end
local function request(recipe, fields)
    local r = {id = "purpose-1", consumerId = "construction-1", kind = "material-upkeep", sourceRevision = "native-source-1"}
    for k,v in pairs(fields or {}) do r[k] = v end
    return r
end
local function describe(name, f, fields, workplace)
    local recipe = ScriptManager.instance:getCraftRecipe("Base." .. name)
    return P.describe(recipe, f.body, request(name,fields), workplace)
end
local function reservations(callback)
    return {ownerId = "person-1", purposeId = "purpose-1", canUse = callback or function() return true end}
end
local function select(policy, f, callback)
    local s, issues = P.selectInputs(policy, f.body, reservations(callback), f.containers)
    if not s then for _,row in ipairs(issues or {}) do print("SELECTION", row.reason, row.index, row.detail) end end
    return s, issues
end
local function reason(issues, wanted)
    for _, row in ipairs(issues or {}) do if row.reason == wanted then return true end end
    return false
end
local function plain(v, seen)
    local t = type(v)
    if t == "nil" or t == "string" or t == "number" or t == "boolean" then return true end
    if t ~= "table" or getmetatable(v) ~= nil then return false end
    seen = seen or {}; if seen[v] then return false end; seen[v] = true
    for k,x in pairs(v) do if not plain(k,seen) or not plain(x,seen) then return false end end
    seen[v] = nil;return true
end

local f = __reset("saw")
local complete = true
for _,name in ipairs({"FixWithDuctTape","FixWithAdhesiveTape","FixWithZipties","FixWithGlue","FixWithWoodGlue",
    "FixWithEpoxy","FixWithEpoxyAndRags","SharpenBlade","SharpenBladePoorlyWithFile","SharpenBladeWithGrindstone",
    "MakeCrudeWhetstone","FixSaw","ReplaceHacksawBlade","ReplaceSmallSawBlade"}) do
    local member = describe(name,f)
    local row = member and P.project(member)
    if not row or not plain(row) or row.recipe ~= "Base." .. name or #row.slots ~= member.recipe:getInputCount() then complete = false end
    if row then __projection(name,row) end
end
check("repair14_registered_projection",complete)
local p, why = describe("SawLogs",f,{desiredType="Base.Plank",desiredAmount=6,desiredState={held=true}})
check("registered_description",p ~= nil and why == nil)
if not p then error("native description unavailable: " .. tostring(why)) end
local projected = P.project(p)
__projection("SawLogs",projected)
check("source_demand_explicit",projected.recipe == "Base.SawLogs" and projected.sourceRevision == "native-source-1"
    and projected.purpose.desiredAmount == 6 and projected.purpose.consumerId == "construction-1")
check("projection_no_local_facts",projected.knowledge.acquiredLocalFacts == false and projected.workplace.acquisitionRequired == true)
check("projection_plain",plain(projected))
local saved = __roundtrip(projected)
check("native_save_roundtrip",saved.recipe == projected.recipe and saved.slots[1].index == projected.slots[1].index
    and saved.purpose.desiredState.held == true)
projected.purpose.desiredState.held=false
check("projection_separate_copy",P.project(p).purpose.desiredState.held == true)
local bodyState = __snapshot(f.body:getModData())
local s, issues = select(p,f)
check("native_saw_selection",s ~= nil and #s.slots == 2 and s.logic:canPerformCurrentRecipe())
check("native_exact_io",s ~= nil and s.slots[1].script == p.recipe:getIOForIndex(s.slots[1].index)
    and s.slots[2].items:get(0) == f.items.Saw)
check("no_input_effect",f.items.Log:getCurrentUses() == 1 and f.body:getInventory():contains(f.items.Log)
    and f.body:getInventory():contains(f.items.Saw))
check("no_body_preference_effect",__snapshot(f.body:getModData()) == bodyState)
check("fixed_output_unmeasured",saved.outputs[1].amount == 3 and saved.outputs[1].actualEffect == "unmeasured"
    and saved.outputs[1].callbackEffect == "native-unresolved")
local denied, deniedIssues = select(p,f,function() return false end)
check("reserved_items_refuse",denied == nil and reason(deniedIssues,"native-input-unmet"))
local calls = 0
local changed, changedIssues = select(p,f,function(item)
    calls=calls+1
    if calls == 2 then f.items.Log:setConditionNoSound(f.items.Log:getCondition()-1) end
    return true
end)
check("input_state_change_refuse",changed == nil and reason(changedIssues,"input-state-or-reservation-changed"))

f=__reset("fix");p=describe("FixSaw",f)
local q=P.project(p)
check("native_tag_projection",#q.slots[1].tags > 0 and q.slots[1].flags.isDamaged == true)
check("per_type_use_requirements",q.slots[1].itemAlternatives[1].amount ~= nil
    and q.slots[1].itemAlternatives[1].partialUse ~= nil)
check("kept_change_declared",q.slots[2].flags.isKeep == true and q.slots[2].flags.mayDegradeLight == true
    and q.slots[2].keptState == "native-effect-unmeasured" and q.callbacks.state == "native-unresolved")
s=select(p,f)
check("native_kept_tag_selection",s ~= nil and s.slots[1].items:get(0) == f.items.Saw and s.slots[2].items:get(0) == f.items.File)
f.items.Saw:setConditionNoSound(f.items.Saw:getConditionMax())
s,issues=select(p,f)
check("native_status_refuse",s == nil and reason(issues,"native-input-unmet"))
f.items.Saw:setConditionNoSound(3);f.body:setSkill(0)
s,issues=select(p,f)
check("current_skill_refuse",s == nil and reason(issues,"recipe-skill-unmet"))

f=__reset("stone");p=describe("MakeCrudeWhetstone",f)
f.body:setLearned(false);s,issues=select(p,f)
check("current_knowledge_refuse",s == nil and reason(issues,"recipe-not-learned"))
local absent, absentReason=P.describe(ScriptManager.instance:getCraftRecipe("Base.SawLogs"),f.body,{id="purpose-1"})
check("missing_request_refuse",absent == nil and absentReason == "purpose-consumerId-required")
local badState,badReason=describe("FixSaw",f,{desiredState={holder=f.body}})
check("nonplain_demand_refuse",badState == nil and badReason == "purpose-desiredState-not-plain")
local cycle={};cycle.self=cycle
badState,badReason=describe("FixSaw",f,{desiredState=cycle})
check("cyclic_demand_refuse",badState == nil and badReason == "purpose-desiredState-not-plain")

f=__reset("tape");p=describe("FixWithDuctTape",f,nil,{object=f.object,key="acquired-surface",revision="seen-1",authorized=true})
s=select(p,f)
check("partial_uses_native_selection",s ~= nil and s.slots[2].baselines[1].partialUse == true
    and s.slots[2].items:size() == 1 and P.project(p).slots[2].amount == 2)
f.items.DuctTape:setCurrentUses(1);s,issues=select(p,f)
check("partial_uses_short_refuse",s == nil and reason(issues,"native-input-unmet"))
f=__reset("tape-two");p=describe("FixWithDuctTape",f,nil,{object=f.object,key="acquired-surface",revision="seen-1",authorized=true})
s,issues=select(p,f)
check("partial_uses_split_selection",s ~= nil and s.slots[2].items:size() == 2 and s.slots[2].baselines[1].uses == 1
    and s.slots[2].baselines[2].uses == 1)

f=__reset("epoxy");p=describe("FixWithEpoxy",f,nil,{object=f.object,key="acquired-surface",revision="seen-1",authorized=true})
s,issues=select(p,f)
check("four_inputs_native_selection",s ~= nil and #s.slots == 4)
local last = 0
s,issues=select(p,f,function() last=last+1;return last <= 4 end)
check("current_reservation_refuse",s == nil and reason(issues,"input-state-or-reservation-changed"))

f=__reset("replace")
local recipe=ScriptManager.instance:getCraftRecipe("Base.ReplaceHacksawBlade")
local targetIndex=recipe:getIndexForIO(recipe:getInputs():get(0))
p=describe("ReplaceHacksawBlade",f,{targetItemId=tostring(f.items.Saw:getID()),targetSlotIndex=targetIndex})
q=P.project(p);s=select(p,f)
check("replacement_identity_declared",q.slots[1].flags.isDestroy == true and q.slots[1].flags.allowDestroyedItem == true
    and q.slots[2].flags.inheritCondition == true and q.outputs[1].itemTypes[1] == "Base.Saw"
    and q.outputs[1].actualEffect == "unmeasured")
check("exact_replacement_target",s ~= nil and s.slots[1].baselines[1].id == tostring(f.items.Saw:getID()))
p.purpose.targetItemId="foreign-target";s,issues=select(p,f)
check("foreign_target_refuse",s == nil and reason(issues,"exact-target-slot-unmet"))
local noTargetSlot,noTargetReason=describe("ReplaceHacksawBlade",f,{targetItemId="901"})
check("target_slot_required",noTargetSlot == nil and noTargetReason == "target-native-slot-required")

f=__reset("refuel");p=describe("RefillBlowTorch",f);q=P.project(p);s=select(p,f)
check("refuel_kept_changes_declared",q.slots[1].flags.isDestroy == true and q.slots[2].flags.isKeep == true
    and q.slots[2].flags.notEmpty == true and q.slots[2].keptState == "native-effect-unmeasured")
check("refuel_native_selection",s ~= nil and s.slots[1].items:get(0) == f.items.BlowTorch)
f.items.PropaneTank:setCurrentUses(0);s,issues=select(p,f)
check("empty_kept_supply_refuse",s == nil and reason(issues,"native-input-unmet"))

f=__reset("grind")
p,why=describe("SharpenBladeWithGrindstone",f)
check("one_target_station_projection",p ~= nil and #p.slots == 1 and P.project(p).workplace.specific == true
    and why == "acquired-authorized-workstation-required")
s,issues=select(p,f)
check("station_missing_refuse",s == nil and reason(issues,"acquired-authorized-workstation-required"))
local workplace={bench=f.bench,object=f.object,key="acquired-grindstone-1",revision="seen-1",authorized=true}
p=describe("SharpenBladeWithGrindstone",f,nil,workplace);s,issues=select(p,f)
check("one_target_native_station_selection",s ~= nil and #s.slots == 1)
f.object:setCustody(false);s,issues=select(p,f)
check("station_custody_refuse",s == nil and reason(issues,"current-workstation-custody-required"))
f.object:setCustody(true);f.object:setFar(true);s,issues=select(p,f)
check("station_range_refuse",s == nil and reason(issues,"native-workstation-range-or-kind-unmet"))

f=__reset("empty");p=describe("OpenBoxOfBullets50",f);q=P.project(p)
check("native_mapped_output_unknown",q.outputs[1].mapped == true and q.outputs[1].actualEffect == "unmeasured"
    and #q.outputs[1].itemTypes > 1)
for _,name in ipairs({"PolicyFluid","PolicyEnergy"}) do
    p=describe(name,f);q=P.project(p);s,issues=select(p,f)
    check(name == "PolicyFluid" and "fluid_channel_retained_refused" or "energy_channel_retained_refused",
        q.slots[1].resource ~= "Item" and #q.unsupported > 0 and s == nil and reason(issues,"resource-channel-not-selected"))
    if name == "PolicyEnergy" then check("energy_identity_plain",q.slots[1].energies[1] == "Electric") end
    if name == "PolicyFluid" then check("fluid_identity_plain",q.slots[1].fluids[1] == "Water") end
end
p=describe("PolicyVariable",f);q=P.project(p);s,issues=select(p,f)
check("variable_input_retained_refused",q.slots[1].variable == true and s == nil and reason(issues,"variable-input-ratio-required"))

f=__reset("saw");p=describe("PolicyOverlap",f);s,issues=select(p,f)
check("same_item_no_double_spend",s == nil and reason(issues,"native-input-unmet"))
p=describe("SawLogs",f);__dropRecipe("SawLogs");s,issues=select(p,f)
check("registration_change_refuse",s == nil and reason(issues,"recipe-registration-changed"))
