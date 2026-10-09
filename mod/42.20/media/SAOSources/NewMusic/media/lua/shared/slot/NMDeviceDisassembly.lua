-- Shared New Music device disassembly helpers and loot tables.

NMDeviceDisassembly = NMDeviceDisassembly or {}

local PROFILE_BY_DEVICE_TYPE = {
    walkman = "walkman",
    cdplayer = "walkman",
    boombox = "boombox",
    vinylplayer = "vinylplayer"
}

local XP_ELECTRICAL = 30
local SCREWDRIVER_WORLD_RADIUS = 1

local function predicateNotBroken(item)
    return item and item.isBroken and (not item:isBroken())
end

local function rollRange(minValue, maxValue)
    local minN = tonumber(minValue) or 0
    local maxN = tonumber(maxValue) or 0
    if maxN < minN then
        minN, maxN = maxN, minN
    end
    return minN + ZombRand((maxN - minN) + 1)
end

local function rollChance(value)
    local chance = tonumber(value) or 0
    if chance <= 0 then return false end
    if chance >= 1 then return true end
    return ZombRand(100) < math.floor((chance * 100) + 0.5)
end

local function rollSkillCount(maxCount, skillLevel, baseChance, bonusPerLevel)
    local limit = tonumber(maxCount) or 0
    if limit <= 0 then
        return 0
    end
    local lvl = tonumber(skillLevel) or 0
    local chance = (tonumber(baseChance) or 0) + (lvl * (tonumber(bonusPerLevel) or 0))
    if chance < 0 then chance = 0 end
    if chance > 0.95 then chance = 0.95 end
    local count = 0
    for _ = 1, limit do
        if rollChance(chance) then
            count = count + 1
        end
    end
    return count
end

local function addItemCount(inventory, fullType, count)
    if not (inventory and inventory.AddItem and fullType) then
        return
    end
    local n = tonumber(count) or 0
    if n <= 0 then
        return
    end
    for _ = 1, n do
        NMWorldItemVisuals.addItemWithVisual(inventory, fullType)
    end
end

local function getPerkLevel(player, perk)
    if not (player and player.getPerkLevel and perk) then
        return 0
    end
    return tonumber(player:getPerkLevel(perk)) or 0
end

local function awardElectricalXP(player, amount)
    if not (player and player.getXp and Perks and Perks.Electrical) then
        return
    end
    local xpObj = player:getXp()
    if xpObj and xpObj.AddXP then
        xpObj:AddXP(Perks.Electrical, tonumber(amount) or 0)
    end
end

local function resolveBulbFromType(fullTypeOrType)
    local key = tostring(fullTypeOrType or ""):lower()
    if key == "" then
        return nil
    end
    if string.find(key, "red", 1, true) then return "Base.LightBulbRed" end
    if string.find(key, "blue", 1, true) then return "Base.LightBulbBlue" end
    if string.find(key, "green", 1, true) then return "Base.LightBulbGreen" end
    if string.find(key, "pink", 1, true) or string.find(key, "magenta", 1, true) then return "Base.LightBulbPink" end
    if string.find(key, "purple", 1, true) then return "Base.LightBulbPurple" end
    if string.find(key, "yellow", 1, true) then return "Base.LightBulbYellow" end
    if string.find(key, "orange", 1, true) then return "Base.LightBulbOrange" end
    if string.find(key, "white", 1, true) then return "Base.LightBulbWhite" end
    return nil
end

local function resolveProfileKey(profile)
    local deviceType = profile and tostring(profile.deviceType or "") or ""
    return PROFILE_BY_DEVICE_TYPE[deviceType]
end

function NMDeviceDisassembly.isEnabled()
    if NMRuntimeConfig and NMRuntimeConfig.getDisassemblyEnabled then
        return NMRuntimeConfig.getDisassemblyEnabled()
    end
    return true
end

function NMDeviceDisassembly.resolveProfileForItem(item, profile)
    local managedProfile = profile or (NMDeviceProfiles and NMDeviceProfiles.getForItem and NMDeviceProfiles.getForItem(item) or nil)
    local key = resolveProfileKey(managedProfile)
    if not key then
        return nil
    end
    return {
        key = key,
        profile = managedProfile,
        electricalXP = XP_ELECTRICAL
    }
end

function NMDeviceDisassembly.canDisassembleItem(item, profile)
    if NMDeviceDisassembly.isEnabled() ~= true then
        return false
    end
    return NMDeviceDisassembly.resolveProfileForItem(item, profile) ~= nil
end

function NMDeviceDisassembly.findScrewdriverInInventory(player)
    local inv = player and player.getInventory and player:getInventory() or nil
    if not (inv and inv.getFirstTagEvalRecurse and ItemTag and ItemTag.SCREWDRIVER) then
        return nil
    end
    return inv:getFirstTagEvalRecurse(ItemTag.SCREWDRIVER, predicateNotBroken)
end

function NMDeviceDisassembly.findNearbyWorldScrewdriver(player, radius)
    local sq = player and player.getSquare and player:getSquare() or nil
    local cell = getCell and getCell() or nil
    if not (sq and cell and ItemTag and ItemTag.SCREWDRIVER) then
        return nil
    end

    local px, py, pz = sq:getX(), sq:getY(), sq:getZ()
    local r = math.max(0, math.floor(tonumber(radius) or SCREWDRIVER_WORLD_RADIUS))
    for x = px - r, px + r do
        for y = py - r, py + r do
            local grid = cell:getGridSquare(x, y, pz)
            if grid and grid.getWorldObjects then
                local objs = grid:getWorldObjects()
                if objs then
                    for i = 0, objs:size() - 1 do
                        local obj = objs:get(i)
                        local item = obj and obj.getItem and obj:getItem() or nil
                        if item and item.hasTag and item:hasTag(ItemTag.SCREWDRIVER) and predicateNotBroken(item) then
                            return item
                        end
                    end
                end
            end
        end
    end
    return nil
end

function NMDeviceDisassembly.resolveScrewdriver(player)
    local screwdriver = NMDeviceDisassembly.findScrewdriverInInventory(player)
    if screwdriver then
        return screwdriver, "inventory"
    end
    screwdriver = NMDeviceDisassembly.findNearbyWorldScrewdriver(player, SCREWDRIVER_WORLD_RADIUS)
    if screwdriver then
        return screwdriver, "world"
    end
    return nil, nil
end

function NMDeviceDisassembly.canDisassembleNow(player, item, profile)
    if not NMDeviceDisassembly.canDisassembleItem(item, profile) then
        return false
    end
    return NMDeviceDisassembly.resolveScrewdriver(player) ~= nil
end

function NMDeviceDisassembly.ejectManagedInsertsToInventory(inventory, state)
    if not (inventory and state) then
        return
    end
    local plan = NMDeviceDisassembly.buildPlan(nil, nil, nil, state)
    NMDeviceDisassembly.applyPlanToInventory(nil, inventory, plan)
end

local function pushOutput(outputs, fullType, count, props)
    local typeName = tostring(fullType or "")
    local n = tonumber(count) or 0
    if typeName == "" or n <= 0 then
        return
    end
    outputs[#outputs + 1] = {
        fullType = typeName,
        count = math.max(1, math.floor(n)),
        props = props
    }
end

local function appendRewardOutputs(outputs, key, electricalSkill, metalSkill, fullType)
    if key == "walkman" then
        pushOutput(outputs, "Base.Aluminum", rollRange(0, 4))
        pushOutput(outputs, "Base.Amplifier", rollSkillCount(1, electricalSkill, 0.25, 0.05))
        pushOutput(outputs, "Base.ElectricWire", rollRange(0, 4))
        pushOutput(outputs, "Base.ElectronicsScrap", rollRange(1, 5))
        pushOutput(outputs, "Base.LightBulb", rollSkillCount(1, electricalSkill, 0.25, 0.05))
        local bulb = resolveBulbFromType(fullType)
        if bulb then
            pushOutput(outputs, bulb, rollSkillCount(1, electricalSkill, 0.20, 0.05))
        end
        return true
    end

    if key == "boombox" then
        pushOutput(outputs, "Base.Aluminum", rollRange(0, 4))
        pushOutput(outputs, "Base.Amplifier", rollSkillCount(2, electricalSkill, 0.25, 0.05))
        pushOutput(outputs, "Base.ElectronicsScrap", rollRange(1, 5))
        local wireCount = rollRange(0, 4)
        pushOutput(outputs, "Base.ElectricWire", wireCount)
        pushOutput(outputs, "Base.Wire", wireCount)
        pushOutput(outputs, "Base.LightBulb", rollSkillCount(1, electricalSkill, 0.25, 0.05))
        local bulb = resolveBulbFromType(fullType)
        if bulb then
            pushOutput(outputs, bulb, rollSkillCount(1, electricalSkill, 0.20, 0.05))
        end
        pushOutput(outputs, "Base.RadioTransmitter", rollSkillCount(1, electricalSkill, 0.20, 0.05))
        return true
    end

    if key == "vinylplayer" then
        pushOutput(outputs, "Base.ScrapWood", rollRange(0, 2))
        pushOutput(outputs, "Base.BrokenGlass", rollRange(0, 2))
        pushOutput(outputs, "Base.SmallSheetMetal", rollSkillCount(2, metalSkill, 0.25, 0.05))
        pushOutput(outputs, "Base.ElectronicsScrap", rollRange(1, 4))
        local wireCount = rollRange(0, 3)
        pushOutput(outputs, "Base.ElectricWire", wireCount)
        pushOutput(outputs, "Base.Wire", wireCount)
        pushOutput(outputs, "Base.Amplifier", rollSkillCount(2, electricalSkill, 0.25, 0.05))
        pushOutput(outputs, "Base.RadioReceiver", rollSkillCount(1, electricalSkill, 0.20, 0.05))
        pushOutput(outputs, "Base.Needle", rollRange(0, 1))
        return true
    end

    return false
end

local function buildManagedOutputs(state)
    local outputs = {}
    local mediaType = tostring(state and (state.mediaEjectFullType or state.mediaFullType) or "")
    if mediaType ~= "" then
        pushOutput(outputs, mediaType, 1, {
            recordedMediaIndex = tonumber(state and state.mediaRecordedMediaIndex) or nil
        })
    end
    local hpType = tostring(state and state.headphoneItemFullType or "")
    if hpType ~= "" then
        pushOutput(outputs, hpType, 1)
    end
    if state and state.batteryPresent == true then
        pushOutput(outputs, "Base.Battery", 1, {
            usedDelta = NMCore and NMCore.clamp and NMCore.clamp(tonumber(state.batteryCharge) or 0.0, 0.0, 1.0) or (tonumber(state.batteryCharge) or 0.0)
        })
    end
    return outputs
end

local function applyOutputProps(item, props)
    if not (item and props) then
        return
    end
    local usedDelta = tonumber(props.usedDelta)
    if usedDelta ~= nil then
        if item.setUsedDelta then
            pcall(item.setUsedDelta, item, usedDelta)
        elseif item.setDelta then
            pcall(item.setDelta, item, usedDelta)
        elseif item.setCurrentUsesFloat then
            pcall(item.setCurrentUsesFloat, item, usedDelta)
        end
    end
    local mediaIndex = tonumber(props.recordedMediaIndex)
    if mediaIndex ~= nil and mediaIndex >= 0 then
        if item.setRecordedMediaIndex then
            pcall(item.setRecordedMediaIndex, item, mediaIndex)
        elseif item.setRecordedMediaIndexInteger then
            pcall(item.setRecordedMediaIndexInteger, item, mediaIndex)
        end
    end
end

function NMDeviceDisassembly.buildPlan(player, item, profile, state)
    local sourceState = state
    if sourceState == nil and item and profile and NMDeviceState and NMDeviceState.peek then
        sourceState = NMDeviceState.peek(item)
    end
    local outputs = buildManagedOutputs(sourceState)
    local resolvedProfile = profile or (item and NMDeviceProfiles and NMDeviceProfiles.getForItem and NMDeviceProfiles.getForItem(item) or nil)
    local fullType = item and item.getFullType and item:getFullType() or item and item.getType and item:getType() or ""
    local def = resolvedProfile and NMDeviceDisassembly.resolveProfileForItem(item, resolvedProfile) or nil
    if def then
        local electricalSkill = getPerkLevel(player, Perks and Perks.Electrical or nil)
        local metalSkill = getPerkLevel(player, Perks and Perks.MetalWelding or nil)
        local ok = appendRewardOutputs(outputs, def.key, electricalSkill, metalSkill, fullType)
        if not ok then
            return nil, "unsupported_profile"
        end
    end
    return {
        outputs = outputs,
        electricalXP = def and (tonumber(def.electricalXP) or 0) or 0,
        deviceType = def and def.key or nil
    }, nil
end

function NMDeviceDisassembly.applyPlanToInventory(player, inventory, plan, opts)
    if not inventory then
        return false, "missing_inventory"
    end
    local disassemblyPlan = plan or {}
    local outputs = disassemblyPlan.outputs or {}
    local onItemAdded = opts and opts.onItemAdded or nil
    for i = 1, #outputs do
        local output = outputs[i]
        local count = tonumber(output and output.count) or 0
        for _ = 1, count do
            local added = NMWorldItemVisuals.addItemWithVisual and select(1, NMWorldItemVisuals.addItemWithVisual(inventory, output.fullType)) or nil
            if not added then
                return false, "add_item_failed"
            end
            applyOutputProps(added, output.props)
            if type(onItemAdded) == "function" then
                onItemAdded(added, output)
            end
        end
    end
    if player and (tonumber(disassemblyPlan.electricalXP) or 0) > 0 then
        awardElectricalXP(player, disassemblyPlan.electricalXP)
    end
    return true, nil
end

function NMDeviceDisassembly.applyLootForItem(player, item, profile)
    if not (player and item and profile) then
        return false, "invalid_args"
    end
    local def = NMDeviceDisassembly.resolveProfileForItem(item, profile)
    if not def then
        return false, "unsupported_device"
    end
    local inventory = player.getInventory and player:getInventory() or nil
    if not inventory then
        return false, "missing_inventory"
    end
    local plan, planErr = NMDeviceDisassembly.buildPlan(player, item, profile, nil)
    if not plan then
        return false, planErr or "build_plan_failed"
    end
    return NMDeviceDisassembly.applyPlanToInventory(player, inventory, plan)
end
