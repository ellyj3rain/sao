require "loot/NMManagedSpawnCatalog"
require "loot/NMLootDistributionUtils"
require "loot/NMLootDiagnostics"
require "loot/NMLootPolicySnapshot"
require "loot/NMLootRealizationAuthority"
require "loot/NMLootResolvedPools"
require "loot/NMLootSandboxSettings"
require "loot/NMMediaLootPool"

NMLootBuildContext = NMLootBuildContext or {}

local build = NMLootBuildContext

local CATEGORY_ORDER = NMLootSandboxSettings.CATEGORY_ORDER
local MEDIA_CATEGORY_ORDER = NMLootSandboxSettings.MEDIA_CATEGORY_ORDER
local DEVICE_CATEGORY_ORDER = NMLootSandboxSettings.DEVICE_CATEGORY_ORDER

local flattenUnitMap = NMManagedSpawnCatalog.flattenUnitMap
local countUnitPool = NMManagedSpawnCatalog.countUnitPool
local newCategoryMaps = NMManagedSpawnCatalog.newCategoryMaps
local buildManagedMediaFootprint = NMManagedSpawnCatalog.buildManagedMediaFootprint

local rewriteBoundMediaSpawnsToContainers = NMLootDistributionUtils.rewriteBoundMediaSpawnsToContainers
local collectAllowedVehicleTargets = NMLootDistributionUtils.collectAllowedVehicleTargets
local buildDistributionPresenceIndex = NMLootDistributionUtils.buildDistributionPresenceIndex
local collectUniqueDistributionTables = NMLootDistributionUtils.collectUniqueDistributionTables
local analyzeItemPresence = NMLootDistributionUtils.analyzeItemPresence
local hasAnyPresence = NMLootDistributionUtils.hasAnyPresence
local applyMultipliersForItems = NMLootDistributionUtils.applyMultipliersForItems

local resolveCategoryMultiplier = NMLootSandboxSettings.resolveCategoryMultiplier
local getRawSandboxLootSettings = NMLootSandboxSettings.getRawSandboxLootSettings
local resolveLootBuildZomboidOSTSetting = NMLootSandboxSettings.resolveLootBuildZomboidOSTSetting

local function nowMs()
    if getTimestampMs then
        local ms = tonumber(getTimestampMs())
        if ms then
            return ms
        end
    end
    if getTimestamp then
        local ts = tonumber(getTimestamp())
        if ts then
            return ts * 1000
        end
    end
    return 0
end

local function elapsedMs(startedAt)
    local startMs = tonumber(startedAt) or 0
    local delta = nowMs() - startMs
    if delta < 0 then
        return 0
    end
    return delta
end

local function countItemsInMap(itemMap)
    local n = 0
    for _ in pairs(itemMap or {}) do
        n = n + 1
    end
    return n
end

local function formatCountMap(map, order)
    local parts = {}
    local useOrder = order or CATEGORY_ORDER
    for i = 1, #useOrder do
        local key = useOrder[i]
        parts[#parts + 1] = key .. "=" .. tostring(tonumber(map and map[key]) or 0)
    end
    return table.concat(parts, " ")
end

local function countVehicleTargetsByRole(vehicleTargets)
    local counts = {
        glovebox = 0,
        seatrear = 0,
        cargo = 0
    }
    for i = 1, #(vehicleTargets or {}) do
        local role = tostring(vehicleTargets[i] and vehicleTargets[i].role or "")
        counts[role] = (tonumber(counts[role]) or 0) + 1
    end
    return counts
end

local function countPoolsByCategory(pools)
    local counts = newCategoryMaps()
    for i = 1, #CATEGORY_ORDER do
        local category = CATEGORY_ORDER[i]
        counts[category] = countItemsInMap(pools and pools.media and pools.media[category] or nil)
            + countItemsInMap(pools and pools.devices and pools.devices[category] or nil)
    end
    return counts
end

local function summarizeDistributionTableShape(vehicleTargets)
    local summary = {
        proceduralItems = 0,
        proceduralJunk = 0,
        suburbsItems = 0,
        vehicleSurfaced = #(vehicleTargets or {}),
        vehicleUniqueItems = 0,
        totalUniqueItems = 0
    }
    local seenUnique = {}
    local seenVehicle = {}

    local function mark(items, bucket)
        if type(items) ~= "table" then
            return
        end
        summary[bucket] = (tonumber(summary[bucket]) or 0) + 1
        if not seenUnique[items] then
            seenUnique[items] = true
            summary.totalUniqueItems = summary.totalUniqueItems + 1
        end
    end

    if ProceduralDistributions and ProceduralDistributions.list then
        for _, dist in pairs(ProceduralDistributions.list) do
            if type(dist) == "table" and type(dist.items) == "table" then
                mark(dist.items, "proceduralItems")
            end
            if type(dist) == "table" and type(dist.junk) == "table" and type(dist.junk.items) == "table" then
                mark(dist.junk.items, "proceduralJunk")
            end
        end
    end

    if SuburbsDistributions then
        for _, location in pairs(SuburbsDistributions) do
            if type(location) == "table" then
                for _, room in pairs(location) do
                    if type(room) == "table" then
                        if type(room.items) == "table" then mark(room.items, "suburbsItems") end
                        if type(room.counter) == "table" and type(room.counter.items) == "table" then mark(room.counter.items, "suburbsItems") end
                        if type(room.metal_shelves) == "table" and type(room.metal_shelves.items) == "table" then mark(room.metal_shelves.items, "suburbsItems") end
                        if type(room.shelves) == "table" and type(room.shelves.items) == "table" then mark(room.shelves.items, "suburbsItems") end
                        if type(room.crate) == "table" and type(room.crate.items) == "table" then mark(room.crate.items, "suburbsItems") end
                    end
                end
            end
        end
    end

    for i = 1, #(vehicleTargets or {}) do
        local items = vehicleTargets[i] and vehicleTargets[i].items or nil
        if type(items) == "table" and not seenVehicle[items] then
            seenVehicle[items] = true
            summary.vehicleUniqueItems = summary.vehicleUniqueItems + 1
        end
        mark(items, "vehicleItems")
    end

    return summary
end

local function appendDeviceSpawnMap(targetMap, devicePools)
    for fullType, category in pairs(flattenUnitMap(devicePools or {})) do
        targetMap[fullType] = category
    end
end

function build.create(options)
    local distributionAuditEnabled = false
    local lootPolicy = nil
    local buildId = ""
    if type(options) == "table" then
        distributionAuditEnabled = options.distributionAuditEnabled == true
        lootPolicy = options.lootPolicy
        buildId = tostring(options.buildId or "")
    else
        distributionAuditEnabled = options == true
    end
    local allItems = getAllItems and getAllItems() or nil
    local mediaSpawnsWithCases = lootPolicy ~= nil
        and lootPolicy.casesEnabled == true
        or not (NMRuntimeConfig and NMRuntimeConfig.getMediaSpawnsWithCasesEnabled)
        or NMRuntimeConfig.getMediaSpawnsWithCasesEnabled() == true
    if NMLootDiagnostics and NMLootDiagnostics.logSandboxLoot then
        NMLootDiagnostics.logSandboxLoot(
            distributionAuditEnabled == true,
            "sandbox.loot build_context_create_start",
            string.format(
                "buildId=%s allItems=%s mediaSpawnsWithCases=%s policy=%s",
                tostring(buildId),
                tostring(tonumber(allItems and allItems:size()) or 0),
                tostring(mediaSpawnsWithCases),
                tostring(NMLootPolicySnapshot and NMLootPolicySnapshot.formatPolicy and NMLootPolicySnapshot.formatPolicy(lootPolicy) or "runtime")
            )
        )
    end

    local phaseStartedAt = nowMs()
    local compatibleChildMods = NMManagedSpawnCatalog.buildCompatibleChildModSet()
    local compatibleChildModsMs = elapsedMs(phaseStartedAt)

    phaseStartedAt = nowMs()
    local overrides = NMManagedSpawnCatalog.buildLoadedContainerOverrideRegistry(allItems)
    local overridesMs = elapsedMs(phaseStartedAt)

    phaseStartedAt = nowMs()
    local rewrites = 0
    if mediaSpawnsWithCases then
        rewrites = rewriteBoundMediaSpawnsToContainers(overrides and overrides.mediaToContainer or nil)
    end
    local rewritesMs = elapsedMs(phaseStartedAt)

    phaseStartedAt = nowMs()
    local vehicleTargets = collectAllowedVehicleTargets()
    local vehicleTargetsMs = elapsedMs(phaseStartedAt)
    local vehicleRoleCounts = countVehicleTargetsByRole(vehicleTargets)
    local tableShape = summarizeDistributionTableShape(vehicleTargets)

    phaseStartedAt = nowMs()
    local presenceIndex = buildDistributionPresenceIndex(vehicleTargets)
    local presenceIndexMs = elapsedMs(phaseStartedAt)
    local distributionTables = collectUniqueDistributionTables(vehicleTargets)
    local multiplierIndexCache = {}

    phaseStartedAt = nowMs()
    local basePools, childPools, skippedMods, skippedFalsePositives, bareMediaRepresentatives =
        NMManagedSpawnCatalog.buildManagedPools(
            allItems,
            overrides,
            compatibleChildMods,
            { distributionAuditEnabled = distributionAuditEnabled == true }
        )
    local managedPoolsMs = elapsedMs(phaseStartedAt)

    local rawSandboxLoot = lootPolicy ~= nil
        and NMLootPolicySnapshot.toRawSandboxLootSettings(lootPolicy)
        or getRawSandboxLootSettings()
    local lootBuildZomboidOST = lootPolicy ~= nil
        and NMLootPolicySnapshot.toZomboidOSTSetting(lootPolicy)
        or resolveLootBuildZomboidOSTSetting()
    rawSandboxLoot.summary = string.format(
        "cassettes=%s vinyl=%s cds=%s walkman=%s boombox=%s cdplayer=%s recordplayer=%s",
        tostring(rawSandboxLoot and rawSandboxLoot.cassettes),
        tostring(rawSandboxLoot and rawSandboxLoot.vinyl),
        tostring(rawSandboxLoot and rawSandboxLoot.cds),
        tostring(rawSandboxLoot and rawSandboxLoot.walkman),
        tostring(rawSandboxLoot and rawSandboxLoot.boombox),
        tostring(rawSandboxLoot and rawSandboxLoot.cdplayer),
        tostring(rawSandboxLoot and rawSandboxLoot.recordplayer)
    )
    phaseStartedAt = nowMs()
    local filteredBaseZomboidOST = NMManagedSpawnCatalog.filterBaseZomboidOSTMedia(basePools, lootBuildZomboidOST.enabled)
    local filterBaseOstMs = elapsedMs(phaseStartedAt)

    phaseStartedAt = nowMs()
    local mediaLootPool = NMMediaLootPool.build({
        baseMedia = basePools and basePools.media or nil,
        childPools = childPools,
        policy = lootPolicy
    })
    local mediaLootPoolMs = elapsedMs(phaseStartedAt)

    local mediaFootprint = buildManagedMediaFootprint(basePools, childPools, presenceIndex)

    local baseAllMap = flattenUnitMap(basePools.media)
    appendDeviceSpawnMap(baseAllMap, basePools.devices)

    phaseStartedAt = nowMs()
    local _, basePresentMap, baseMissingMap = analyzeItemPresence(baseAllMap, presenceIndex)
    local baseSplitPresenceMs = elapsedMs(phaseStartedAt)

    phaseStartedAt = nowMs()
    local baseTouched = applyMultipliersForItems(baseAllMap, distributionTables, multiplierIndexCache, resolveCategoryMultiplier)
    local baseTouchMs = elapsedMs(phaseStartedAt)

    local managedSpawnMediaPool = newCategoryMaps()
    local managedSpawnDevicePool = newCategoryMaps()
    local baseMissingCounts = newCategoryMaps()
    local basePresentCounts = newCategoryMaps()
    local childPoolCounts = newCategoryMaps()
    local managedSpawnChildMediaCounts = newCategoryMaps()
    local childTouched = 0

    for i = 1, #MEDIA_CATEGORY_ORDER do
        local category = MEDIA_CATEGORY_ORDER[i]
        for key, unit in pairs(basePools.media[category] or {}) do
            local spawnFullType = tostring(unit and unit.spawnFullType or "")
            if basePresentMap[spawnFullType] then
                basePresentCounts[category] = (tonumber(basePresentCounts[category]) or 0) + 1
            elseif baseMissingMap[spawnFullType] then
                managedSpawnMediaPool[category][key] = unit
                baseMissingCounts[category] = (tonumber(baseMissingCounts[category]) or 0) + 1
            end
        end
    end

    for i = 1, #DEVICE_CATEGORY_ORDER do
        local category = DEVICE_CATEGORY_ORDER[i]
        for key, unit in pairs(basePools.devices[category] or {}) do
            local spawnFullType = tostring(unit and unit.spawnFullType or "")
            if basePresentMap[spawnFullType] then
                basePresentCounts[category] = (tonumber(basePresentCounts[category]) or 0) + 1
            elseif baseMissingMap[spawnFullType] then
                managedSpawnDevicePool[category][key] = unit
                baseMissingCounts[category] = (tonumber(baseMissingCounts[category]) or 0) + 1
            end
        end
    end

    local childPackAuditEntries = distributionAuditEnabled == true and {} or nil
    phaseStartedAt = nowMs()
    for modId, pools in pairs(childPools or {}) do
        local itemSet = flattenUnitMap(pools.media)
        local counts = countUnitPool(pools.media, MEDIA_CATEGORY_ORDER)
        for category, count in pairs(counts) do
            childPoolCounts[category] = (tonumber(childPoolCounts[category]) or 0) + (tonumber(count) or 0)
        end

        local presence, presentMap, missingMap = analyzeItemPresence(itemSet, presenceIndex)
        local ownsAnyPresence = hasAnyPresence(presence)
        childTouched = childTouched + applyMultipliersForItems(itemSet, distributionTables, multiplierIndexCache, resolveCategoryMultiplier)
        if not ownsAnyPresence then
            for i = 1, #MEDIA_CATEGORY_ORDER do
                local category = MEDIA_CATEGORY_ORDER[i]
                for key, unit in pairs(pools.media[category] or {}) do
                    if missingMap[tostring(unit and unit.spawnFullType or "")] then
                        managedSpawnMediaPool[category][key] = unit
                        managedSpawnChildMediaCounts[category] = (tonumber(managedSpawnChildMediaCounts[category]) or 0) + 1
                    end
                end
            end
        end

        if childPackAuditEntries then
            childPackAuditEntries[#childPackAuditEntries + 1] = string.format(
                "modId=%s ownsAny=%s presence={proc=%s,suburbs=%s,vehicle=%s} present=%s missing=%s eligibleManagedSpawn=%s byCategory={%s}",
                tostring(modId),
                tostring(ownsAnyPresence),
                tostring(presence and presence.procedural),
                tostring(presence and presence.suburbs),
                tostring(presence and presence.vehicle),
                tostring(countItemsInMap(presentMap)),
                tostring(countItemsInMap(missingMap)),
                tostring(not ownsAnyPresence),
                formatCountMap(counts, MEDIA_CATEGORY_ORDER)
            )
        end
    end
    local childFanoutMs = elapsedMs(phaseStartedAt)

    phaseStartedAt = nowMs()
    local resolvedPools = NMLootResolvedPools.build({
        managedSpawnMediaPool = managedSpawnMediaPool,
        managedSpawnDevicePool = managedSpawnDevicePool,
        lootPolicy = lootPolicy,
        buildId = buildId
    })
    local resolvedPoolsMs = elapsedMs(phaseStartedAt)

    return {
        buildId = buildId,
        allItems = allItems,
        allItemCount = tonumber(allItems and allItems:size()) or 0,
        lootPolicy = lootPolicy,
        mediaSpawnsWithCases = mediaSpawnsWithCases,
        compatibleChildMods = compatibleChildMods,
        overrides = overrides,
        boundMediaCount = countItemsInMap(overrides and overrides.mediaToContainer or nil),
        rewrites = rewrites,
        vehicleTargets = vehicleTargets,
        vehicleRoleCounts = vehicleRoleCounts,
        tableShape = tableShape,
        presenceIndex = presenceIndex,
        distributionTables = distributionTables,
        basePools = basePools,
        childPools = childPools,
        mediaFootprint = mediaFootprint,
        mediaLootPool = mediaLootPool,
        baseCategoryCounts = countPoolsByCategory(basePools),
        managedSpawnMediaPool = managedSpawnMediaPool,
        managedSpawnDevicePool = managedSpawnDevicePool,
        resolvedPools = resolvedPools,
        basePresentCounts = basePresentCounts,
        baseMissingCounts = baseMissingCounts,
        childPoolCounts = childPoolCounts,
        managedSpawnChildMediaCounts = managedSpawnChildMediaCounts,
        rawSandboxLoot = rawSandboxLoot,
        lootBuildZomboidOST = lootBuildZomboidOST,
        filteredBaseZomboidOST = filteredBaseZomboidOST,
        skippedMods = skippedMods,
        skippedFalsePositives = skippedFalsePositives,
        bareMediaRepresentatives = bareMediaRepresentatives,
        childPackAuditEntries = childPackAuditEntries,
        baseTouched = baseTouched,
        childTouched = childTouched,
        baseMediaCount = countItemsInMap(flattenUnitMap(basePools.media)),
        baseDeviceCount = countItemsInMap(flattenUnitMap(basePools.devices)),
        childPackCount = countItemsInMap(childPools),
        compatibleChildModsMs = compatibleChildModsMs,
        overridesMs = overridesMs,
        rewritesMs = rewritesMs,
        vehicleTargetsMs = vehicleTargetsMs,
        presenceIndexMs = presenceIndexMs,
        managedPoolsMs = managedPoolsMs,
        filterBaseOstMs = filterBaseOstMs,
        baseSplitPresenceMs = baseSplitPresenceMs,
        baseTouchMs = baseTouchMs,
        childFanoutMs = childFanoutMs,
        resolvedPoolsMs = resolvedPoolsMs,
        mediaLootPoolMs = mediaLootPoolMs
    }
end

return build
