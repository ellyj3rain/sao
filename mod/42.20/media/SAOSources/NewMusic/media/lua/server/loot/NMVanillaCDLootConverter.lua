require "loot/NMLootDebugHelpers"
require "loot/NMLootPlaceholderResolver"

NMVanillaCDLootConverter = NMVanillaCDLootConverter or {}

local converter = NMVanillaCDLootConverter

local VANILLA_DISC_TYPES = {
    ["Disc_Retail"] = true,
    ["Base.Disc_Retail"] = true
}

local VANILLA_CD_PLAYER_TYPES = {
    ["CDplayer"] = true,
    ["Base.CDplayer"] = true,
    ["CDPlayer"] = true,
    ["Base.CDPlayer"] = true
}

local CURVE_POINTS = {
    { rate = 0.0, strength = 0.0 },
    { rate = 0.1, strength = 0.1 },
    { rate = 0.6, strength = 0.5 },
    { rate = 4.0, strength = 1.0 }
}

local state = {
    stats = nil
}

local function newStats()
    return {
        mode = "vanillaReplace",
        observedVanillaCDs = 0,
        replaced = 0,
        discarded = 0,
        failed = 0,
        replacements = {
            cassettes = 0,
            cds = 0
        },
        observedVanillaCDPlayers = 0,
        cdPlayerReplaced = 0,
        cdPlayerDiscarded = 0,
        cdPlayerFailed = 0,
        deviceReplacements = {
            walkman = 0,
            cdplayer = 0
        }
    }
end

local function resetStats()
    state.stats = newStats()
end

local function getRate(getter, fallback)
    local value = type(getter) == "function" and tonumber(getter()) or nil
    if value == nil then
        return tonumber(fallback) or 0
    end
    return value
end

local function isEnabled()
    return NMRuntimeConfig
        and NMRuntimeConfig.getConvertVanillaCDsAndCDPlayersEnabled
        and NMRuntimeConfig.getConvertVanillaCDsAndCDPlayersEnabled() == true
end

local function strengthForRate(rate)
    local value = tonumber(rate) or 0
    if value <= CURVE_POINTS[1].rate then
        return CURVE_POINTS[1].strength
    end
    for i = 2, #CURVE_POINTS do
        local previous = CURVE_POINTS[i - 1]
        local current = CURVE_POINTS[i]
        if value <= current.rate then
            local span = current.rate - previous.rate
            if span <= 0 then
                return current.strength
            end
            local t = (value - previous.rate) / span
            return previous.strength + ((current.strength - previous.strength) * t)
        end
    end
    return CURVE_POINTS[#CURVE_POINTS].strength
end

local function rollChance(chance)
    local bounded = math.max(0.0, math.min(1.0, tonumber(chance) or 0.0))
    if bounded <= 0 then
        return false
    end
    if bounded >= 1 then
        return true
    end
    local roll = ZombRandFloat and ZombRandFloat(0.0, 1.0) or math.random()
    return roll < bounded
end

local function pickReplacementCategory(cassetteStrength, cdStrength)
    local cassette = math.max(0.0, tonumber(cassetteStrength) or 0.0)
    local cd = math.max(0.0, tonumber(cdStrength) or 0.0)
    local total = cassette + cd
    if total <= 0 then
        return nil
    end
    local roll = ZombRandFloat and ZombRandFloat(0.0, total) or (math.random() * total)
    if roll < cassette then
        return "cassettes"
    end
    return "cds"
end

local function pickDeviceReplacementCategory(walkmanStrength, cdPlayerStrength)
    local walkman = math.max(0.0, tonumber(walkmanStrength) or 0.0)
    local cdPlayer = math.max(0.0, tonumber(cdPlayerStrength) or 0.0)
    local total = walkman + cdPlayer
    if total <= 0 then
        return nil
    end
    local roll = ZombRandFloat and ZombRandFloat(0.0, total) or (math.random() * total)
    if roll < walkman then
        return "walkman"
    end
    return "cdplayer"
end

local function removeContainerItem(container, item)
    if not item then
        return false
    end
    local removed = false
    if container and container.Remove then
        local ok = pcall(container.Remove, container, item)
        removed = ok == true
    end
    if removed ~= true and container and container.DoRemoveItem then
        local ok = pcall(container.DoRemoveItem, container, item)
        removed = ok == true
    end
    if removed ~= true then
        return false
    end
    local items = container and container.getItems and container:getItems() or nil
    if not (items and items.size and items.get) then
        return true
    end
    for i = 0, items:size() - 1 do
        if items:get(i) == item then
            return false
        end
    end
    if sendRemoveItemFromContainer then
        pcall(sendRemoveItemFromContainer, container, item)
    end
    return true
end

local function cloneStats(stats)
    local source = stats or state.stats or newStats()
    return {
        mode = tostring(source.mode or "vanillaReplace"),
        observedVanillaCDs = tonumber(source.observedVanillaCDs) or 0,
        replaced = tonumber(source.replaced) or 0,
        discarded = tonumber(source.discarded) or 0,
        failed = tonumber(source.failed) or 0,
        replacements = {
            cassettes = tonumber(source.replacements and source.replacements.cassettes) or 0,
            cds = tonumber(source.replacements and source.replacements.cds) or 0
        },
        observedVanillaCDPlayers = tonumber(source.observedVanillaCDPlayers) or 0,
        cdPlayerReplaced = tonumber(source.cdPlayerReplaced) or 0,
        cdPlayerDiscarded = tonumber(source.cdPlayerDiscarded) or 0,
        cdPlayerFailed = tonumber(source.cdPlayerFailed) or 0,
        deviceReplacements = {
            walkman = tonumber(source.deviceReplacements and source.deviceReplacements.walkman) or 0,
            cdplayer = tonumber(source.deviceReplacements and source.deviceReplacements.cdplayer) or 0
        }
    }
end

function converter.configure()
    resetStats()
end

function converter.isEnabled()
    return isEnabled()
end

function converter.getStats()
    return cloneStats(state.stats)
end

function converter.getConfigurationSnapshot()
    local cassetteRate = getRate(NMRuntimeConfig and NMRuntimeConfig.getCassettesSpawnRate or nil, 0.6)
    local cdRate = getRate(NMRuntimeConfig and NMRuntimeConfig.getCDsSpawnRate or nil, 0.6)
    local walkmanRate = getRate(NMRuntimeConfig and NMRuntimeConfig.getWalkmanSpawnRate or nil, 0.6)
    local cdPlayerRate = getRate(NMRuntimeConfig and NMRuntimeConfig.getCDPlayerSpawnRate or nil, 0.6)
    local cassetteStrength = strengthForRate(cassetteRate)
    local cdStrength = strengthForRate(cdRate)
    local walkmanStrength = strengthForRate(walkmanRate)
    local cdPlayerStrength = strengthForRate(cdPlayerRate)
    return {
        mode = "vanillaReplace",
        enabled = isEnabled(),
        cassetteRate = cassetteRate,
        cdRate = cdRate,
        walkmanRate = walkmanRate,
        cdPlayerRate = cdPlayerRate,
        cassetteStrength = cassetteStrength,
        cdStrength = cdStrength,
        walkmanStrength = walkmanStrength,
        cdPlayerStrength = cdPlayerStrength,
        replaceChance = (cassetteStrength + cdStrength) / 2,
        cdPlayerReplaceChance = (walkmanStrength + cdPlayerStrength) / 2
    }
end

local function collectVanillaItems(items, types)
    local out = {}
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local fullType = item and item.getFullType and tostring(item:getFullType() or "") or ""
        if types[fullType] == true then
            out[#out + 1] = item
        end
    end
    return out
end

local function processVanillaDiscItems(resolvedContainer, vanillaCDs, context, delta)
    local cassetteStrength = strengthForRate(getRate(NMRuntimeConfig and NMRuntimeConfig.getCassettesSpawnRate or nil, 0.6))
    local cdStrength = strengthForRate(getRate(NMRuntimeConfig and NMRuntimeConfig.getCDsSpawnRate or nil, 0.6))
    local replaceChance = (cassetteStrength + cdStrength) / 2
    local selectionSession = {}
    local removalFailed = false

    for i = 1, #vanillaCDs do
        local item = vanillaCDs[i]
        delta.observedVanillaCDs = delta.observedVanillaCDs + 1
        state.stats.observedVanillaCDs = state.stats.observedVanillaCDs + 1

        local category = nil
        if rollChance(replaceChance) then
            category = pickReplacementCategory(cassetteStrength, cdStrength)
        end

        local removed = removeContainerItem(resolvedContainer, item)
        if removed ~= true then
            removalFailed = true
            delta.failed = delta.failed + 1
            state.stats.failed = state.stats.failed + 1
        elseif category == nil then
            delta.discarded = delta.discarded + 1
            state.stats.discarded = state.stats.discarded + 1
        elseif NMLootPlaceholderResolver
            and NMLootPlaceholderResolver.addResolvedItemForCategoryFromSource
        then
            local added = NMLootPlaceholderResolver.addResolvedItemForCategoryFromSource(
                resolvedContainer,
                category,
                "standard",
                selectionSession,
                context,
                "Base.Disc_Retail"
            )
            if added then
                delta.replaced = delta.replaced + 1
                delta.replacements[category] = (tonumber(delta.replacements[category]) or 0) + 1
                state.stats.replaced = state.stats.replaced + 1
                state.stats.replacements[category] = (tonumber(state.stats.replacements[category]) or 0) + 1
            else
                delta.failed = delta.failed + 1
                state.stats.failed = state.stats.failed + 1
            end
        else
            delta.failed = delta.failed + 1
            state.stats.failed = state.stats.failed + 1
        end
    end

    return removalFailed
end

local function processVanillaCDPlayerItems(resolvedContainer, vanillaCDPlayers, context, delta)
    local walkmanStrength = strengthForRate(getRate(NMRuntimeConfig and NMRuntimeConfig.getWalkmanSpawnRate or nil, 0.6))
    local cdPlayerStrength = strengthForRate(getRate(NMRuntimeConfig and NMRuntimeConfig.getCDPlayerSpawnRate or nil, 0.6))
    local replaceChance = (walkmanStrength + cdPlayerStrength) / 2
    local removalFailed = false

    for i = 1, #vanillaCDPlayers do
        local item = vanillaCDPlayers[i]
        delta.observedVanillaCDPlayers = delta.observedVanillaCDPlayers + 1
        state.stats.observedVanillaCDPlayers = state.stats.observedVanillaCDPlayers + 1

        local category = nil
        if rollChance(replaceChance) then
            category = pickDeviceReplacementCategory(walkmanStrength, cdPlayerStrength)
        end

        local removed = removeContainerItem(resolvedContainer, item)
        if removed ~= true then
            removalFailed = true
            delta.cdPlayerFailed = delta.cdPlayerFailed + 1
            state.stats.cdPlayerFailed = state.stats.cdPlayerFailed + 1
        elseif category == nil then
            delta.cdPlayerDiscarded = delta.cdPlayerDiscarded + 1
            state.stats.cdPlayerDiscarded = state.stats.cdPlayerDiscarded + 1
        elseif NMLootPlaceholderResolver
            and NMLootPlaceholderResolver.addResolvedDeviceItemForCategory
        then
            local added = NMLootPlaceholderResolver.addResolvedDeviceItemForCategory(
                resolvedContainer,
                category,
                "standard",
                context
            )
            if added then
                delta.cdPlayerReplaced = delta.cdPlayerReplaced + 1
                delta.deviceReplacements[category] = (tonumber(delta.deviceReplacements[category]) or 0) + 1
                state.stats.cdPlayerReplaced = state.stats.cdPlayerReplaced + 1
                state.stats.deviceReplacements[category] = (tonumber(state.stats.deviceReplacements[category]) or 0) + 1
            else
                delta.cdPlayerFailed = delta.cdPlayerFailed + 1
                state.stats.cdPlayerFailed = state.stats.cdPlayerFailed + 1
            end
        else
            delta.cdPlayerFailed = delta.cdPlayerFailed + 1
            state.stats.cdPlayerFailed = state.stats.cdPlayerFailed + 1
        end
    end

    return removalFailed
end

function converter.processContainer(container, context)
    if isEnabled() ~= true then
        return nil
    end
    if state.stats == nil then
        resetStats()
    end
    local resolvedContainer, items = NMLootDebugHelpers.resolveMutableContainer(container, "vanillaReplace.skip_container")
    if not (resolvedContainer and items and items.size and items.get) then
        return nil
    end

    local processState = nil
    local epoch = "unknown"
    local modData = resolvedContainer.getModData and resolvedContainer:getModData() or nil
    if type(modData) == "table" then
        modData.nmVanillaReplace = modData.nmVanillaReplace or {}
        processState = modData.nmVanillaReplace
        epoch = NMLootPlaceholderResolver
            and NMLootPlaceholderResolver.getCacheKey
            and NMLootPlaceholderResolver.getCacheKey()
            or "unknown"
    end

    local vanillaCDs = collectVanillaItems(items, VANILLA_DISC_TYPES)
    local vanillaCDPlayers = collectVanillaItems(items, VANILLA_CD_PLAYER_TYPES)
    if #vanillaCDs < 1 and #vanillaCDPlayers < 1 then
        return nil
    end
    if processState and tostring(processState.epoch or "") == tostring(epoch or "") then
        processState.epoch = ""
    end
    if processState then
        processState.pendingEpoch = tostring(epoch or "")
    end

    local delta = newStats()
    delta.mode = "vanillaReplace"
    local removalFailed = processVanillaDiscItems(resolvedContainer, vanillaCDs, context, delta)

    if processVanillaCDPlayerItems(resolvedContainer, vanillaCDPlayers, context, delta) == true then
        removalFailed = true
    end

    if processState and removalFailed ~= true then
        processState.epoch = tostring(processState.pendingEpoch or processState.epoch or "")
    end
    if processState then
        processState.pendingEpoch = nil
    end

    if NMServerLootProbe and NMServerLootProbe.recordVanillaReplace then
        NMServerLootProbe.recordVanillaReplace(delta)
    end
    return delta
end

return converter
