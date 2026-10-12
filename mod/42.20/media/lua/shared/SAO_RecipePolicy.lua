-- Registered native recipe requirements and exact, read-only input selection.
-- ResourceProduction retains actions, effects, claims and durable work. A policy
-- describes possible means; it supplies no person-acquired local facts.
SAO = SAO or {}
SAO.RecipePolicy = {}
local P = SAO.RecipePolicy

local inputFlags = {
    "isExclusive", "isItemCount", "isKeep", "isDestroy", "isReplace", "isTool",
    "isToolLeft", "isToolRight", "isWorn", "isNotWorn", "isFull", "isEmpty",
    "notFull", "notEmpty", "isDamaged", "isUndamaged", "allowFrozenItem",
    "dontAllowFrozenItem", "allowRottenItem", "allowDestroyedItem", "isEmptyContainer",
    "isWholeFoodItem", "isUncookedFoodItem", "isCookedFoodItem", "isHeadPart",
    "isSharpenable", "dontPutBack", "inheritColor", "inheritCondition",
    "inheritHeadCondition", "inheritSharpness", "inheritUses", "isNotDull",
    "mayDegrade", "mayDegradeLight", "mayDegradeVeryLight", "mayDegradeHeavy",
    "sharpnessCheck", "allowFavorites", "isRecordInput", "isCanBeDoneFromFloor",
}

local function values(list, method)
    local result = {}
    if list then
        local it = list:iterator()
        while it:hasNext() do
            local v = it:next()
            result[#result + 1] = method and tostring(v[method](v)) or tostring(v)
        end
    end
    return result
end

local function copyPlain(value, seen)
    local kind = type(value)
    if kind == "string" or kind == "boolean" or kind == "number" then return value end
    if kind ~= "table" or getmetatable(value) ~= nil then return nil end
    seen = seen or {}
    if seen[value] then return nil end
    seen[value] = true
    local result = {}
    for key, v in pairs(value) do
        if type(key) == "string" or type(key) == "number" then
            local copied = copyPlain(v, seen)
            if v ~= nil and copied == nil then seen[value] = nil; return nil end
            result[key] = copied
        else seen[value] = nil; return nil end
    end
    seen[value] = nil
    return result
end

local function issue(issues, code, index, channel)
    issues[#issues + 1] = {reason = code, index = index, channel = channel}
end

local function output(recipe, script)
    local resource = tostring(script:getResourceType())
    local mapper = script:getOutputMapper()
    return {
        index = recipe:getIndexForIO(script), resource = resource,
        declaration = script:getOriginalLine(), amount = script:getAmount(),
        maxAmount = script:getMaxAmount(), variable = script:isVariableAmount(),
        chance = script:getChance(), mapped = mapper ~= nil,
        itemTypes = values(script:getPossibleResultItems(), "getFullName"),
        fluids = values(script:getPossibleResultFluids(), "getFluidTypeString"),
        energies = values(script:getPossibleResultEnergies(), "getEnergyTypeString"),
        replaceInput = script:isReplaceInput(), createUses = script:isCreateUses(),
        applyOnTick = script:isApplyOnTick(), automationOnly = script:isAutomationOnly(),
        createToItem = script:hasCreateToItem(),
        -- Callback, mapper, variable and chance effects retain native authority.
        -- Even a fixed declaration is not a measured produced/held quantity.
        actualEffect = "unmeasured", callbackEffect = "native-unresolved",
    }
end

-- requestedPurpose is a plain request: id, consumerId, kind, sourceRevision;
-- optional desiredType/desiredAmount/desiredState, parentId, stepId and exact
-- targetItemId/targetSlotIndex (the native IO index, not the input-array index).
-- workplace is a transient port: bench, object, key, revision, authorized.
-- describe returns a runtime policy and its first unmet reason, or nil/reason
-- for invalid identity/request/API. Requirements remain available when unmet.
function P.describe(registeredRecipe, body, requestedPurpose, workplace)
    if not registeredRecipe or not body or type(requestedPurpose) ~= "table" then
        return nil, "recipe-body-purpose-required"
    end
    local purpose = {}
    for _, key in ipairs({"id", "consumerId", "consumerRecipeId", "consumerOwner", "consumerOperation", "quantityUnit", "kind", "sourceRevision", "parentId",
        "stepId", "desiredType", "desiredAmount", "desiredState", "targetItemId", "targetSlotIndex"}) do
        purpose[key] = copyPlain(requestedPurpose[key])
        if requestedPurpose[key] ~= nil and purpose[key] == nil then return nil, "purpose-" .. key .. "-not-plain" end
    end
    for _, key in ipairs({"id", "consumerId", "kind", "sourceRevision"}) do
        if type(purpose[key]) ~= "string" or purpose[key] == "" then return nil, "purpose-" .. key .. "-required" end
    end
    if purpose.targetItemId ~= nil and type(purpose.targetSlotIndex) ~= "number" then
        return nil, "target-native-slot-required"
    end
    local ok, policy = pcall(function()
        local name = registeredRecipe:getScriptObjectFullType()
        if ScriptManager.instance:getCraftRecipe(name) ~= registeredRecipe then return nil end
        local requirements = {
            schema = "sao-registered-recipe-policy/1", recipe = name,
            modId = registeredRecipe:getModID(), sourceRevision = purpose.sourceRevision,
            purpose = purpose, slots = {}, outputs = {}, skills = {}, unsupported = {},
            knowledge = {requiresLearnedRecipe = registeredRecipe:needToBeLearn(),
                acquiredLocalFacts = false},
            workplace = {specific = registeredRecipe:requiresSpecificWorkstation(),
                tags = values(registeredRecipe:getTags()),
                anySurface = registeredRecipe:isAnySurfaceCraft(),
                inHand = registeredRecipe:isInHandCraftCraft(),
                key = workplace and copyPlain(workplace.key),
                revision = workplace and copyPlain(workplace.revision),
                acquisitionRequired = true, standingRequired = true},
            -- The shipping Lua ABI does not expose CraftRecipe.LuaCall constants.
            -- Consumers must treat callbacks as native effects, never infer a
            -- guaranteed stock gain or unchanged kept item from output lines.
            callbacks = {state = "native-unresolved"},
        }
        local inputs, slots = registeredRecipe:getInputs(), {}
        for n = 0, inputs:size() - 1 do
            local native = inputs:get(n)
            local index = registeredRecipe:getIndexForIO(native)
            if index < 0 or registeredRecipe:getIOForIndex(index) ~= native then error("native IO identity") end
            local resource = tostring(native:getResourceType())
            local row = {index = index, resource = resource, declaration = native:getOriginalLine(),
                amount = native:getAmount(), maxAmount = native:getMaxAmount(),
                variable = native:isVariableAmount(), flags = {},
                itemTypes = values(native:getPossibleInputItems(), "getFullName"),
                tags = values(native:getItemTags()), fluids = values(native:getPossibleInputFluids(), "getFluidTypeString"),
                energies = values(native:getPossibleInputEnergies(), "getEnergyTypeString"),
                applyMode = tostring(native:getItemApplyMode()),
                fluidMatchMode = tostring(native:getFluidMatchMode()),
                acceptsAnyItem = native:isAcceptsAnyItem(),
                acceptsAnyFluid = native:isAcceptsAnyFluid(), acceptsAnyEnergy = native:isAcceptsAnyEnergy(),
                applyOnTick = native:isApplyOnTick(), automationOnly = native:isAutomationOnly(),
                createToItem = native:hasCreateToItem(), consumeFromItem = native:hasConsumeFromItem(),
                parentIndex = native:hasParentScript() and registeredRecipe:getIndexForIO(native:getParentScript()) or nil,
                keptState = native:isKeep() and "native-effect-unmeasured" or nil,
            }
            for _, flag in ipairs(inputFlags) do row.flags[flag] = native[flag](native) end
            row.itemAlternatives = {}
            local possible = native:getPossibleInputItems()
            if possible then for i = 0, possible:size() - 1 do
                local item = possible:get(i)
                local name = item:getFullName()
                row.itemAlternatives[#row.itemAlternatives + 1] = {itemType = name,
                    amount = native:getAmount(name), maxAmount = native:getMaxAmount(name),
                    partialUse = native:isUsesPartialItem(item)}
            end end
            if native:isReplace() then row.replacement = output(registeredRecipe, native:getReplaceOutputScript()) end
            if native:hasCreateToItem() then row.createdInItem = output(registeredRecipe, native:getCreateToItemScript()) end
            if native:hasConsumeFromItem() then row.consumeFromIndex = registeredRecipe:getIndexForIO(native:getConsumeFromItemScript()) end
            if resource ~= "Item" then issue(requirements.unsupported, "resource-channel-not-selected", index, resource) end
            if row.variable then issue(requirements.unsupported, "variable-input-ratio-required", index, resource) end
            if row.applyOnTick or row.automationOnly then issue(requirements.unsupported, "tick-or-automation-owner-required", index, resource) end
            if row.createToItem or row.consumeFromItem or native:hasParentScript() then
                issue(requirements.unsupported, "linked-resource-owner-required", index, resource)
            end
            requirements.slots[#requirements.slots + 1] = row
            slots[#slots + 1] = {index = index, script = native, requirement = row}
        end
        local outputs = registeredRecipe:getOutputs()
        for n = 0, outputs:size() - 1 do
            local row = output(registeredRecipe, outputs:get(n))
            requirements.outputs[#requirements.outputs + 1] = row
            if row.resource ~= "Item" or row.applyOnTick or row.automationOnly or row.createToItem then
                issue(requirements.unsupported, "output-resource-owner-required", row.index, row.resource)
            end
        end
        local unmet = {}
        if not CraftRecipeManager.hasPlayerLearnedRecipe(registeredRecipe, body) then issue(unmet, "recipe-not-learned") end
        for n = 0, registeredRecipe:getRequiredSkillCount() - 1 do
            local skill = registeredRecipe:getRequiredSkill(n)
            requirements.skills[#requirements.skills + 1] = {perkId=skill:getPerk():getId(),level=skill:getLevel()}
            if not CraftRecipeManager.hasPlayerRequiredSkill(skill, body) then issue(unmet, "recipe-skill-unmet", n) end
        end
        if requirements.workplace.specific and (not workplace or not workplace.bench or not workplace.object
            or not workplace.key or not workplace.revision or workplace.authorized ~= true) then
            issue(unmet, "acquired-authorized-workstation-required")
        end
        if requirements.workplace.anySurface and (not workplace or not workplace.object
            or not workplace.key or not workplace.revision or workplace.authorized ~= true) then
            issue(unmet, "acquired-authorized-work-surface-required")
        end
        return {recipe = registeredRecipe, body = body, purpose = purpose, workplace = workplace,
            slots = slots, requirements = requirements, unmet = unmet}
    end)
    if not ok then return nil, "native-recipe-description-unavailable" end
    if not policy then return nil, "recipe-registration-changed" end
    return policy, policy.unmet[1] and policy.unmet[1].reason or nil
end

-- reservationContext: ownerId, purposeId and canUse(item, nativeIndex, policy).
-- It reads current SourceUse/claim/Standing custody and returns exactly true.
-- candidateContainers is a native ArrayList of already admitted containers;
-- no map scan, nested-container discovery, reservation or stock mutation occurs.
-- Returns {logic,slots,policy} with transient native script/items/container handles,
-- or nil,{plain reason/index/channel...}. Every successful slot includes exact
-- id/type/uses/condition baselines; native quantity allocation remains authoritative.
-- Selection follows supplied container/item order. An unmet allocation is not
-- evidence that no alternative allocation or uninspected stock exists.
-- A supplied initialized native logic keeps its own recipe/body selection.
-- The ordinary handcraft caller omits it and retains the existing path.
function P.selectInputs(policy, body, reservationContext, candidateContainers, suppliedLogic)
    if not policy or body ~= policy.body or not reservationContext
        or type(reservationContext.canUse) ~= "function"
        or type(reservationContext.ownerId) ~= "string"
        or reservationContext.purposeId ~= policy.purpose.id or not candidateContainers then
        return nil, {{reason = "current-body-reservation-context-required"}}
    end
    local ok, selected, issues = pcall(function()
        local fresh, reason = P.describe(policy.recipe, body, policy.purpose, policy.workplace)
        if not fresh then return nil, {{reason = reason}} end
        if #fresh.unmet > 0 then return nil, fresh.unmet end
        if #fresh.requirements.unsupported > 0 then return nil, fresh.requirements.unsupported end
        local w = policy.workplace
        local prospective = w and w.object and reservationContext.prospectiveWorkstation == true
            and w.object:getUsingPlayer() == nil
        if w and w.bench and (w.authorized ~= true or not w.object
            or not w.object:isUsingPlayer(body) and not prospective) then
            return nil, {{reason = "current-workstation-custody-required"}}
        end
        local logic = suppliedLogic or HandcraftLogic.new(body, w and w.bench, w and w.object)
        if suppliedLogic and (logic:getRecipe() ~= fresh.recipe
            or logic:getRecipeData():getRecipe() ~= fresh.recipe
            or logic:getRecipeData():getCharacter() ~= body) then
            return nil, {{reason = "native-logic-recipe-or-body-changed"}}
        end
        logic:setContainers(candidateContainers)
        -- HandcraftLogic:setRecipe also writes the body's last selected UI
        -- recipe. A requirement probe binds only its private native data.
        if not suppliedLogic then logic:getRecipeData():setRecipe(policy.recipe) end
        logic:setManualSelectInputs(true)
        logic:clearManualInputs()
        -- Clear cached satisfaction when reusing an initialized BuildLogic.
        if suppliedLogic then logic:canPerformCurrentRecipe() end
        if (w and w.object and not logic:isCharacterInRangeOfWorkbench()) or not logic:hasRequiredWorkstation() then
            return nil, {{reason = "native-workstation-range-or-kind-unmet"}}
        end
        local candidates, seen = {}, {}
        for c = 0, candidateContainers:size() - 1 do
            local container = candidateContainers:get(c)
            local items = container:getItems()
            for n = 0, items:size() - 1 do
                local item = items:get(n)
                if not seen[item] and item:getContainer() == container then
                    seen[item] = true
                    candidates[#candidates + 1] = item
                end
            end
        end
        local used, slots = {}, {}
        for _, slot in ipairs(fresh.slots) do
            local items, baselines = ArrayList.new(), {}
            local target = fresh.purpose.targetSlotIndex == slot.index and fresh.purpose.targetItemId or nil
            for _, item in ipairs(candidates) do
                if not used[item] and (target == nil or tostring(item:getID()) == tostring(target))
                    and reservationContext.canUse(item, slot.index, fresh) == true
                    and CraftRecipeManager.isItemValidForInputScript(slot.script, item, body) then
                    items:add(item)
                    logic:setManualInputsFor(slot.script, items)
                    -- BuildLogic reads native cached satisfaction; refresh current data
                    -- before using that result to stop allocation.
                    if suppliedLogic then logic:canPerformCurrentRecipe() end
                    local accepted = logic:getManualInputsFor(slot.script, ArrayList.new())
                    if not accepted:contains(item) then
                        return nil, {{reason = "native-manual-input-refused", index = slot.index}}
                    end
                    baselines[#baselines + 1] = {item = item, id = tostring(item:getID()),
                        itemType = item:getFullType(), container = item:getContainer(),
                        uses = item:getCurrentUses(), condition = item:getCondition(),
                        partialUse = slot.script:isUsesPartialItem(item:getScriptItem())}
                    if logic:isInputSatisfied(slot.script) then break end
                end
            end
            if not logic:isInputSatisfied(slot.script) then
                return nil, {{reason = target and "exact-target-slot-unmet" or "native-input-unmet", index = slot.index}}
            end
            for _, baseline in ipairs(baselines) do used[baseline.item] = true end
            slots[#slots + 1] = {index = slot.index, script = slot.script, items = items, baselines = baselines}
        end
        if fresh.purpose.targetItemId ~= nil then
            local found = false
            for _, slot in ipairs(slots) do
                if slot.index == fresh.purpose.targetSlotIndex then found = true end
            end
            if not found then return nil, {{reason = "target-native-slot-missing"}} end
        end
        for _, slot in ipairs(slots) do
            for _, baseline in ipairs(slot.baselines) do
                local item = baseline.item
                if item:getContainer() ~= baseline.container or not baseline.container:getItems():contains(item)
                    or tostring(item:getID()) ~= baseline.id or item:getFullType() ~= baseline.itemType
                    or item:getCurrentUses() ~= baseline.uses or item:getCondition() ~= baseline.condition
                    or reservationContext.canUse(item, slot.index, fresh) ~= true
                    or not CraftRecipeManager.isItemValidForInputScript(slot.script, item, body) then
                    return nil, {{reason = "input-state-or-reservation-changed", index = slot.index}}
                end
            end
        end
        if ScriptManager.instance:getCraftRecipe(fresh.requirements.recipe) ~= fresh.recipe
            or not logic:canPerformCurrentRecipe() then return nil, {{reason = "native-current-recipe-refused"}} end
        return {logic = logic, slots = slots, policy = fresh}, {}
    end)
    if not ok then return nil, {{reason = "native-input-selection-unavailable", detail = tostring(selected)}} end
    return selected, issues
end

-- A fresh plain copy, with no native objects/functions/metatables. Existing
-- persistence owners save requests/requirements and reacquire registered handles.
function P.project(policy)
    if not policy or type(policy.requirements) ~= "table" then return nil end
    return copyPlain(policy.requirements)
end

-- An acquired exact item is rechecked at its existing source-transfer owner.
-- The declaration binds the selected native slot through save/reload; this is
-- eligibility only and neither reserves nor transfers the item.
function P.inputEligible(requirement,item,body)
    if type(requirement)~="table" or not item or not body then return false,"recipe-input-context-required" end
    local ok,eligible=pcall(function()
        local recipe=ScriptManager.instance:getCraftRecipe(requirement.recipeId)
        local input=recipe and recipe:getIOForIndex(requirement.index)
        return input~=nil and input:getResourceType()==ResourceType.Item
            and input:getOriginalLine()==requirement.declaration
            and not input:isVariableAmount() and not input:isApplyOnTick() and not input:isAutomationOnly()
            and not input:hasCreateToItem() and not input:hasConsumeFromItem() and not input:hasParentScript()
            and CraftRecipeManager.isItemValidForInputScript(input,item,body)==true
    end)
    return ok and eligible==true,ok and (eligible and nil or "native-input-state-refused") or "native-input-api-unavailable"
end

return P
