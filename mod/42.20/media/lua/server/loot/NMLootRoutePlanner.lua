-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
require "loot/NMLootPlaceholderResolver"
require "loot/NMLootDebugHelpers"
require "loot/NMLootDistributionUtils"
require "loot/NMLootRealizationAuthority"
require "loot/NMLootSandboxSettings"
require "loot/NMLootStandardMediaTargets"
require "loot/NMManagedSpawnCatalog"

NMLootRoutePlanner = NMLootRoutePlanner or {}

local planner = NMLootRoutePlanner

local BASE_MEDIA_DEFAULT = NMLootSandboxSettings.BASE_MEDIA_DEFAULT
local CATEGORY_ORDER = NMLootSandboxSettings.CATEGORY_ORDER
local MEDIA_CATEGORY_ORDER = NMLootSandboxSettings.MEDIA_CATEGORY_ORDER
local DEVICE_CATEGORY_ORDER = NMLootSandboxSettings.DEVICE_CATEGORY_ORDER
local VEHICLE_ROLE_ORDER = NMLootSandboxSettings.VEHICLE_ROLE_ORDER

local VEHICLE_ROLE_PRIORITY = {
    glovebox = 1,
    seatrear = 2,
    cargo = 3
}

local STANDARD_VEHICLE_DEVICE_LANE_CAPS = {
    boombox = 1,
    recordplayer = 1
}

local MUSIC_STORE_MEDIA_MIN_PRESENCE_UNITS = NMLootSandboxSettings.MUSIC_STORE_MEDIA_MIN_PRESENCE_UNITS
local MUSIC_STORE_TARGET_ORDER = NMLootSandboxSettings.MUSIC_STORE_TARGET_ORDER
local MUSIC_STORE_PROCEDURAL_WEIGHT_OVERRIDES = NMLootSandboxSettings.MUSIC_STORE_PROCEDURAL_WEIGHT_OVERRIDES
local MUSIC_STORE_DEVICE_TOPUP_BIAS = NMLootSandboxSettings.MUSIC_STORE_DEVICE_TOPUP_BIAS
local MUSIC_STORE_TOPUP_REFERENCE_RATE = NMLootSandboxSettings.MUSIC_STORE_TOPUP_REFERENCE_RATE
local MUSIC_STORE_TOPUP_DECAY_EXPONENT = NMLootSandboxSettings.MUSIC_STORE_TOPUP_DECAY_EXPONENT
local MUSIC_STORE_TOPUP_TARGET_FLOORS = NMLootSandboxSettings.MUSIC_STORE_TOPUP_TARGET_FLOORS

local LOOT_ROUTE_KEYS = NMLootDebugHelpers and NMLootDebugHelpers.getRouteKeys and NMLootDebugHelpers.getRouteKeys() or {
    standard = "standard",
    topUp = "topUp"
}
local LOOT_RESULT_KEYS = NMLootDebugHelpers and NMLootDebugHelpers.getResultKeys and NMLootDebugHelpers.getResultKeys() or {
    inserted = "inserted",
    increased = "increased",
    alreadyPresent = "already_present",
    replaced = "replaced",
    skipped = "skipped",
    rejected = "rejected"
}

local clamp = NMLootSandboxSettings.clamp
local pow = NMLootSandboxSettings.pow
local resolveCategoryRate = NMLootSandboxSettings.resolveCategoryRate
local normalizePlayableRate = NMLootSandboxSettings.normalizePlayableRate

local addItemIfMissingCached = NMLootDistributionUtils.addItemIfMissingCached
local addOrIncreaseItemWeightWithResult = NMLootDistributionUtils.addOrIncreaseItemWeightWithResult
local injectIntoProcedural = NMLootDistributionUtils.injectIntoProcedural
local isResidentialProceduralTarget = NMLootRealizationAuthority and NMLootRealizationAuthority.isResidentialProceduralTarget or function()
    return false
end

local ACTIVE_LOOT_POLICY = nil

local VEHICLE_ROLE_WEIGHT_CURVES = {
    cassettes = {
        glovebox = { low = 36.00, high = 48.00 },
        seatrear = { low = 0.20, high = 0.90 },
        cargo = { low = 0.24, high = 1.80 }
    },
    vinyl = {
        glovebox = { low = 0.0, high = 0.0 },
        seatrear = { low = 0.0, high = 0.0 },
        cargo = { low = 0.10, high = 1.30 }
    },
    cds = {
        glovebox = { low = 1.20, high = 2.40 },
        seatrear = { low = 0.22, high = 0.95 },
        cargo = { low = 0.22, high = 1.60 }
    },
    walkman = {
        glovebox = { low = 0.12, high = 1.20 },
        seatrear = { low = 0.05, high = 0.55 },
        cargo = { low = 0.08, high = 0.85 }
    },
    boombox = {
        glovebox = { low = 0.0, high = 0.0 },
        seatrear = { low = 0.0, high = 0.0 },
        cargo = { low = 0.08, high = 0.75 }
    },
    cdplayer = {
        glovebox = { low = 0.10, high = 0.95 },
        seatrear = { low = 0.05, high = 0.50 },
        cargo = { low = 0.08, high = 0.80 }
    },
    recordplayer = {
        glovebox = { low = 0.0, high = 0.0 },
        seatrear = { low = 0.0, high = 0.0 },
        cargo = { low = 0.045, high = 0.34 }
    }
}

local function orderedMediaUnitsForCategory(pool, category)
    return NMManagedSpawnCatalog.orderedMediaUnitsForCategory({ media = pool or {} }, category)
end

local function orderedDeviceUnitsForCategory(pool, category)
    return NMManagedSpawnCatalog.orderedDeviceUnitsForCategory({ devices = pool or {} }, category)
end

local function resolveActiveCategoryRate(category)
    return resolveCategoryRate(category, ACTIVE_LOOT_POLICY)
end

local function countUniqueVehicleTargetsByRoleMap(vehicleTargets)
    local grouped = { glovebox = {}, seatrear = {}, cargo = {} }
    local uniqueByItems = {}

    for i = 1, #(vehicleTargets or {}) do
        local target = vehicleTargets[i]
        local items = target and target.items or nil
        local role = tostring(target and target.role or "")
        if type(items) == "table" and grouped[role] then
            local uniqueTarget = uniqueByItems[items]
            if not uniqueTarget then
                uniqueTarget = { items = items, role = role, roles = {} }
                uniqueByItems[items] = uniqueTarget
            end
            uniqueTarget.roles[role] = true
            if (tonumber(VEHICLE_ROLE_PRIORITY[role]) or 999) < (tonumber(VEHICLE_ROLE_PRIORITY[uniqueTarget.role]) or 999) then
                uniqueTarget.role = role
            end
        end
    end

    for _, target in pairs(uniqueByItems) do
        grouped[target.role][#grouped[target.role] + 1] = target
    end

    return grouped
end

local function newInjectionSummary()
    local roles = {}
    for i = 1, #VEHICLE_ROLE_ORDER do
        roles[VEHICLE_ROLE_ORDER[i]] = 0
    end
    return {
        total = 0,
        byCategory = {},
        byRole = roles,
        bySource = {
            standard = { total = 0, byCategory = {} },
            topUp = { total = 0, byCategory = {} }
        }
    }
end

local function ensureCategoryDiagnostics(diag, category)
    diag[category] = diag[category] or {
        poolSize = 0,
        budget = 0,
        rate = 0,
        multiplier = 0,
        share = 0,
        rawWeight = 0,
        laneAmplifier = 1.0,
        estimatedWeight = 0,
        laneWeight = { procedural = 0, vehicle = 0, mail = 0 },
        injectedEntries = { procedural = 0, vehicle = 0, mail = 0 },
        eligibleTargets = { procedural = 0, vehicle = 0, mail = 0 },
        averageTargetWeight = { procedural = 0, vehicle = 0, mail = 0 },
        averageEntryWeight = { procedural = 0, vehicle = 0, mail = 0 },
        resultCounts = { procedural = {}, vehicle = {}, mail = {} },
        selectedUnits = {},
        strongProceduralAssigned = {},
        assignmentCounts = {}
    }
    return diag[category]
end

local function recordInjected(summary, category, role, source)
    if type(summary) ~= "table" then
        return
    end
    local sourceKey = tostring(source or LOOT_ROUTE_KEYS.standard)
    summary.total = (tonumber(summary.total) or 0) + 1
    if category then
        summary.byCategory[category] = (tonumber(summary.byCategory[category]) or 0) + 1
    end
    if role then
        summary.byRole[role] = (tonumber(summary.byRole[role]) or 0) + 1
    end
    summary.bySource[sourceKey] = summary.bySource[sourceKey] or { total = 0, byCategory = {} }
    summary.bySource[sourceKey].total = (tonumber(summary.bySource[sourceKey].total) or 0) + 1
    if category then
        summary.bySource[sourceKey].byCategory[category] = (tonumber(summary.bySource[sourceKey].byCategory[category]) or 0) + 1
    end
end

local function recordMutationResult(categoryDiag, lane, resultKey)
    categoryDiag.resultCounts[lane] = categoryDiag.resultCounts[lane] or {}
    categoryDiag.resultCounts[lane][resultKey] = (tonumber(categoryDiag.resultCounts[lane][resultKey]) or 0) + 1
end

local function recordInjectedEntry(categoryDiag, lane)
    categoryDiag.injectedEntries[lane] = (tonumber(categoryDiag.injectedEntries[lane]) or 0) + 1
end

local function isMusicStoreTarget(listName)
    local name = tostring(listName or "")
    return string.sub(name, 1, #"MusicStore") == "MusicStore"
end

local function isVehicleMediaCategoryAllowed(category, role)
    local categoryKey = tostring(category or "")
    local roleKey = tostring(role or "")
    if categoryKey == "vinyl" then
        return roleKey == "seatrear" or roleKey == "cargo"
    end
    return true
end

local function isVehicleDeviceCategoryAllowed(category, role)
    local categoryKey = tostring(category or "")
    local roleKey = tostring(role or "")
    if roleKey == "glovebox" then
        return categoryKey == "walkman" or categoryKey == "cdplayer"
    end
    if roleKey == "seatrear" then
        return categoryKey == "walkman" or categoryKey == "cdplayer" or categoryKey == "boombox"
    end
    if roleKey == "cargo" then
        return categoryKey == "walkman" or categoryKey == "cdplayer" or categoryKey == "boombox" or categoryKey == "recordplayer"
    end
    return false
end

local function resolveVehicleTargetCap(role, source, kind)
    local roleKey = tostring(role or "")
    local sourceKey = tostring(source or LOOT_ROUTE_KEYS.standard)
    local kindKey = tostring(kind or "media")
    if roleKey == "cargo" then
        return kindKey == "media" and 2 or 1
    end
    return 1
end

local function resolveMailTargetCap(kind)
    if tostring(kind or "media") == "media" then
        return 1
    end
    return 1
end

local function countPlaceholderEntries(items, metadataKind)
    if type(items) ~= "table" then
        return 0
    end
    local count = 0
    for i = 1, #items, 2 do
        local fullType = tostring(items[i] or "")
        if string.find(fullType, "NewMusic.LootRep", 1, true) == 1 then
            local isDevice = string.find(fullType, "NewMusic.LootRepDevice", 1, true) == 1
            if metadataKind == "device" and isDevice then
                count = count + 1
            elseif metadataKind == "media" and not isDevice then
                count = count + 1
            end
        end
    end
    return count
end

local function countItemEntries(items, targetFullType)
    if type(items) ~= "table" then
        return 0
    end
    local target = tostring(targetFullType or "")
    if target == "" then
        return 0
    end
    local count = 0
    for i = 1, #items, 2 do
        if tostring(items[i] or "") == target then
            count = count + 1
        end
    end
    return count
end

local function resolveAvailableStandardVehicleDeviceLaneSlots(items, category, placeholderFullType)
    local cap = tonumber(STANDARD_VEHICLE_DEVICE_LANE_CAPS[tostring(category or "")]) or 0
    if cap <= 0 then
        return 1
    end
    local current = 0
    local target = tostring(placeholderFullType or "")
    if type(items) == "table" and target ~= "" then
        for i = 1, #items, 2 do
            if tostring(items[i] or "") == target then
                current = current + 1
            end
        end
    end
    return math.max(0, cap - current)
end

resolveVehicleRoleTargetWeight = function(category, role, rate)
    local curve = VEHICLE_ROLE_WEIGHT_CURVES[category] and VEHICLE_ROLE_WEIGHT_CURVES[category][role] or nil
    if not curve then
        return 0
    end
    local low = tonumber(curve.low) or 0
    local high = tonumber(curve.high) or low
    if high <= 0 then
        return 0
    end
    return low + ((high - low) * normalizePlayableRate(rate))
end

local function countMediaPoolOwnership(unitMap)
    local owned = { base = {}, child = {} }
    for i = 1, #MEDIA_CATEGORY_ORDER do
        local category = MEDIA_CATEGORY_ORDER[i]
        owned.base[category] = 0
        owned.child[category] = 0
        for _, unit in pairs(unitMap and unitMap[category] or {}) do
            local owner = tostring(unit and unit.owner or "")
            if owner == "base" then
                owned.base[category] = owned.base[category] + 1
            else
                owned.child[category] = owned.child[category] + 1
            end
        end
    end
    return owned
end

local function buildMusicStoreTargetDiagnostics()
    local perCategory = {}
    local laneByCategory = {}
    for i = 1, #MUSIC_STORE_TARGET_ORDER do
        laneByCategory[MUSIC_STORE_TARGET_ORDER[i]] = {}
    end
    for i = 1, #CATEGORY_ORDER do
        local category = CATEGORY_ORDER[i]
        perCategory[category] = 0
        for j = 1, #MUSIC_STORE_TARGET_ORDER do
            laneByCategory[MUSIC_STORE_TARGET_ORDER[j]][category] = 0
        end
        local targets = NMLootMusicStoreMediaTopUpTargets or {}
        for j = 1, #targets do
            local name = tostring(targets[j] and targets[j].name or "")
            if isMusicStoreTarget(name) then
                local weight = tonumber(targets[j] and targets[j].weight) or 0
                laneByCategory[name][category] = weight
                perCategory[category] = perCategory[category] + weight
            end
        end
    end
    return perCategory, laneByCategory
end

local STANDARD_MEDIA_TARGETS = NMLootStandardMediaTargets

local function resolveStandardMediaResidentialMultiplier()
    return math.max(0, tonumber(NMLootStandardMediaResidentialMultiplier) or 1.0)
end

local function resolveStandardMediaVehicleMultiplier()
    return math.max(0, tonumber(NMLootStandardMediaVehicleMultiplier) or 1.0)
end

local function resolveStandardDeviceMultiplier()
    return math.max(0, tonumber(NMLootStandardDeviceMultiplier) or 1.0)
end

local function resolveStandardDeviceVehicleMultiplier()
    return math.max(0, tonumber(NMLootStandardDeviceVehicleMultiplier) or 1.0)
end

local function resolveStandardDeviceLaneBudget(rate)
    local points = NMLootStandardDeviceRatePoints or {}
    local r = clamp(rate, 0.0, 4.0)
    if #points < 1 then
        return 0
    end
    if r <= (tonumber(points[1].rate) or 0) then
        return tonumber(points[1].budget) or 0
    end
    for i = 2, #points do
        local previous = points[i - 1]
        local current = points[i]
        local previousRate = tonumber(previous.rate) or 0
        local currentRate = tonumber(current.rate) or previousRate
        if r <= currentRate then
            local previousBudget = tonumber(previous.budget) or 0
            local currentBudget = tonumber(current.budget) or previousBudget
            local t = clamp((r - previousRate) / math.max(0.0001, currentRate - previousRate), 0.0, 1.0)
            return previousBudget + ((currentBudget - previousBudget) * t)
        end
    end
    return tonumber(points[#points].budget) or 0
end

local function resolveMusicStoreMediaTopUpMultiplier()
    return math.max(0, tonumber(NMLootMusicStoreMediaTopUpMultiplier) or 1.0)
end

local function resolveMusicStoreDeviceTopUpMultiplier()
    return math.max(0, tonumber(NMLootMusicStoreDeviceTopUpMultiplier) or 1.0)
end

local function resolveMusicStoreMediaTopUpBudget(rate)
    local points = NMLootMusicStoreMediaTopUpRatePoints or {}
    local r = clamp(rate, 0.0, 4.0)
    if #points < 1 then
        return 0
    end
    if r <= (tonumber(points[1].rate) or 0) then
        return tonumber(points[1].budget) or 0
    end
    for i = 2, #points do
        local previous = points[i - 1]
        local current = points[i]
        local previousRate = tonumber(previous.rate) or 0
        local currentRate = tonumber(current.rate) or previousRate
        if r <= currentRate then
            local previousBudget = tonumber(previous.budget) or 0
            local currentBudget = tonumber(current.budget) or previousBudget
            local t = clamp((r - previousRate) / math.max(0.0001, currentRate - previousRate), 0.0, 1.0)
            return previousBudget + ((currentBudget - previousBudget) * t)
        end
    end
    return tonumber(points[#points].budget) or 0
end

local function resolveMusicStoreMediaTopUpCategoryBias(category)
    return math.max(0, tonumber(NMLootMusicStoreMediaTopUpBias and NMLootMusicStoreMediaTopUpBias[category]) or 0)
end

local function resolveMusicStoreDeviceTopUpCategoryBias(category)
    return math.max(0, tonumber(NMLootMusicStoreDeviceTopUpBias and NMLootMusicStoreDeviceTopUpBias[category]) or 0)
end

local function countCategoryUnits(pool, category)
    return #orderedMediaUnitsForCategory(pool or {}, category)
end

local function countDeviceCategoryUnits(pool, category)
    return #orderedDeviceUnitsForCategory(pool or {}, category)
end

local function ensureSimpleMediaDiag(diagnostics, category, rate, laneBudget, poolSize)
    local diag = ensureCategoryDiagnostics(diagnostics, category)
    diag.poolSize = poolSize
    diag.rate = rate
    diag.multiplier = laneBudget
    diag.share = laneBudget
    diag.rawWeight = laneBudget
    diag.budget = laneBudget
    return diag
end

local function ensureSimpleDeviceDiag(diagnostics, category, rate, laneBudget, poolSize)
    local diag = ensureCategoryDiagnostics(diagnostics, category)
    diag.poolSize = poolSize
    diag.rate = rate
    diag.multiplier = laneBudget
    diag.share = laneBudget
    diag.rawWeight = laneBudget
    diag.budget = laneBudget
    return diag
end

local function injectStandardMediaLane(category, placeholderFullType, laneBudget, summary, diagnostics, indexCache)
    if tostring(placeholderFullType or "") == "" or laneBudget <= 0 then
        return
    end
    local targets = STANDARD_MEDIA_TARGETS[category] or {}
    local categoryDiag = ensureCategoryDiagnostics(diagnostics, category)
    categoryDiag.eligibleTargets.procedural = #targets
    for i = 1, #targets do
        local cfg = targets[i]
        local targetName = tostring(cfg and cfg.name or "")
        local list = ProceduralDistributions and ProceduralDistributions.list and ProceduralDistributions.list[targetName] or nil
        local items = list and list.items or nil
        local weight = (tonumber(cfg and cfg.weight) or 0) * laneBudget
        if isResidentialProceduralTarget(targetName) then
            weight = weight * resolveStandardMediaResidentialMultiplier()
        end
        if targetName ~= "" and weight > 0 and type(items) == "table" then
            categoryDiag.estimatedWeight = categoryDiag.estimatedWeight + weight
            categoryDiag.laneWeight.procedural = categoryDiag.laneWeight.procedural + weight
            local injected = injectIntoProcedural(targetName, placeholderFullType, weight, indexCache)
            if injected then
                recordInjected(summary, category, nil, LOOT_ROUTE_KEYS.standard)
                recordInjectedEntry(categoryDiag, "procedural")
            else
                recordMutationResult(categoryDiag, "procedural", LOOT_RESULT_KEYS.alreadyPresent)
            end
        else
            recordMutationResult(categoryDiag, "procedural", LOOT_RESULT_KEYS.skipped)
        end
    end
    categoryDiag.averageTargetWeight.procedural = categoryDiag.laneWeight.procedural / math.max(1, categoryDiag.eligibleTargets.procedural)
    categoryDiag.averageEntryWeight.procedural = categoryDiag.laneWeight.procedural / math.max(1, tonumber(categoryDiag.injectedEntries.procedural) or 0)
end

local function injectStandardMediaVehicleLane(category, placeholderFullType, laneBudget, groupedVehicleTargets, summary, diagnostics, indexCache)
    if tostring(placeholderFullType or "") == "" or laneBudget <= 0 then
        return
    end

    local categoryDiag = ensureCategoryDiagnostics(diagnostics, category)
    local targetWeight = laneBudget
        * resolveStandardMediaResidentialMultiplier()
        * resolveStandardMediaVehicleMultiplier()

    local eligibleTargets = 0
    for i = 1, #VEHICLE_ROLE_ORDER do
        local role = VEHICLE_ROLE_ORDER[i]
        if isVehicleMediaCategoryAllowed(category, role) then
            eligibleTargets = eligibleTargets + #(groupedVehicleTargets[role] or {})
        end
    end
    categoryDiag.eligibleTargets.vehicle = eligibleTargets
    if eligibleTargets < 1 or targetWeight <= 0 then
        return
    end

    for i = 1, #VEHICLE_ROLE_ORDER do
        local role = VEHICLE_ROLE_ORDER[i]
        local targets = groupedVehicleTargets[role] or {}
        if isVehicleMediaCategoryAllowed(category, role) then
            for j = 1, #targets do
                local injected = addItemIfMissingCached(targets[j].items, placeholderFullType, targetWeight, indexCache)
                categoryDiag.estimatedWeight = categoryDiag.estimatedWeight + targetWeight
                categoryDiag.laneWeight.vehicle = categoryDiag.laneWeight.vehicle + targetWeight
                if injected then
                    recordInjected(summary, category, role, LOOT_ROUTE_KEYS.standard)
                    recordInjectedEntry(categoryDiag, "vehicle")
                else
                    recordMutationResult(categoryDiag, "vehicle", LOOT_RESULT_KEYS.alreadyPresent)
                end
            end
        end
    end

    categoryDiag.averageTargetWeight.vehicle = categoryDiag.laneWeight.vehicle / math.max(1, categoryDiag.eligibleTargets.vehicle)
    categoryDiag.averageEntryWeight.vehicle = categoryDiag.laneWeight.vehicle / math.max(1, tonumber(categoryDiag.injectedEntries.vehicle) or 0)
end

local function injectStandardDeviceLane(category, placeholderFullType, laneBudget, summary, diagnostics, indexCache)
    if tostring(placeholderFullType or "") == "" or laneBudget <= 0 then
        return
    end

    local targets = NMLootStandardDeviceTargets and NMLootStandardDeviceTargets[category] or {}
    local categoryDiag = ensureCategoryDiagnostics(diagnostics, category)
    categoryDiag.eligibleTargets.procedural = #targets
    if #targets < 1 then
        return
    end

    local laneMultiplier = resolveStandardMediaResidentialMultiplier() * resolveStandardDeviceMultiplier()
    for i = 1, #targets do
        local cfg = targets[i]
        local targetName = tostring(cfg and cfg.name or "")
        local list = ProceduralDistributions and ProceduralDistributions.list and ProceduralDistributions.list[targetName] or nil
        local items = list and list.items or nil
        local weight = (tonumber(cfg and cfg.weight) or 0) * laneBudget * laneMultiplier
        if targetName ~= "" and weight > 0 and type(items) == "table" then
            categoryDiag.estimatedWeight = categoryDiag.estimatedWeight + weight
            categoryDiag.laneWeight.procedural = categoryDiag.laneWeight.procedural + weight
            local resultKey = addOrIncreaseItemWeightWithResult(items, placeholderFullType, weight, indexCache)
            recordMutationResult(categoryDiag, "procedural", resultKey)
            if resultKey == LOOT_RESULT_KEYS.inserted or resultKey == LOOT_RESULT_KEYS.increased then
                recordInjected(summary, category, nil, LOOT_ROUTE_KEYS.standard)
                recordInjectedEntry(categoryDiag, "procedural")
            end
        else
            recordMutationResult(categoryDiag, "procedural", LOOT_RESULT_KEYS.skipped)
        end
    end

    categoryDiag.averageTargetWeight.procedural = categoryDiag.laneWeight.procedural / math.max(1, categoryDiag.eligibleTargets.procedural)
    categoryDiag.averageEntryWeight.procedural = categoryDiag.laneWeight.procedural / math.max(1, tonumber(categoryDiag.injectedEntries.procedural) or 0)
end

local function injectStandardDeviceVehicleLane(category, placeholderFullType, laneBudget, groupedVehicleTargets, summary, diagnostics, indexCache)
    if tostring(placeholderFullType or "") == "" or laneBudget <= 0 then
        return
    end

    local categoryDiag = ensureCategoryDiagnostics(diagnostics, category)
    local targetWeight = laneBudget
        * resolveStandardMediaResidentialMultiplier()
        * resolveStandardMediaVehicleMultiplier()
        * resolveStandardDeviceMultiplier()
        * resolveStandardDeviceVehicleMultiplier()

    local eligibleTargets = 0
    for i = 1, #VEHICLE_ROLE_ORDER do
        local role = VEHICLE_ROLE_ORDER[i]
        if isVehicleDeviceCategoryAllowed(category, role) then
            eligibleTargets = eligibleTargets + #(groupedVehicleTargets[role] or {})
        end
    end
    categoryDiag.eligibleTargets.vehicle = eligibleTargets
    if eligibleTargets < 1 or targetWeight <= 0 then
        return
    end

    for i = 1, #VEHICLE_ROLE_ORDER do
        local role = VEHICLE_ROLE_ORDER[i]
        local targets = groupedVehicleTargets[role] or {}
        if isVehicleDeviceCategoryAllowed(category, role) then
            for j = 1, #targets do
                if resolveAvailableStandardVehicleDeviceLaneSlots(targets[j].items, category, placeholderFullType) > 0 then
                    local injected = addItemIfMissingCached(targets[j].items, placeholderFullType, targetWeight, indexCache)
                    categoryDiag.estimatedWeight = categoryDiag.estimatedWeight + targetWeight
                    categoryDiag.laneWeight.vehicle = categoryDiag.laneWeight.vehicle + targetWeight
                    if injected then
                        recordInjected(summary, category, role, LOOT_ROUTE_KEYS.standard)
                        recordInjectedEntry(categoryDiag, "vehicle")
                    else
                        recordMutationResult(categoryDiag, "vehicle", LOOT_RESULT_KEYS.alreadyPresent)
                    end
                else
                    recordMutationResult(categoryDiag, "vehicle", LOOT_RESULT_KEYS.skipped)
                end
            end
        end
    end

    categoryDiag.averageTargetWeight.vehicle = categoryDiag.laneWeight.vehicle / math.max(1, categoryDiag.eligibleTargets.vehicle)
    categoryDiag.averageEntryWeight.vehicle = categoryDiag.laneWeight.vehicle / math.max(1, tonumber(categoryDiag.injectedEntries.vehicle) or 0)
end

local function injectMusicStoreMediaTopUpLane(category, placeholderFullType, rate, summary, diagnostics, indexCache)
    if tostring(placeholderFullType or "") == "" then
        return
    end

    local topUpBudget = resolveMusicStoreMediaTopUpBudget(rate)
        * resolveMusicStoreMediaTopUpCategoryBias(category)
        * resolveMusicStoreMediaTopUpMultiplier()
    if topUpBudget <= 0 then
        return
    end

    local targets = NMLootMusicStoreMediaTopUpTargets or {}
    local categoryDiag = ensureCategoryDiagnostics(diagnostics, category)
    local eligibleTargets = 0
    for i = 1, #targets do
        local targetName = tostring(targets[i] and targets[i].name or "")
        if isMusicStoreTarget(targetName) then
            eligibleTargets = eligibleTargets + 1
        end
    end
    categoryDiag.eligibleTargets.procedural = categoryDiag.eligibleTargets.procedural + eligibleTargets
    if eligibleTargets < 1 then
        return
    end

    for i = 1, #targets do
        local cfg = targets[i]
        local targetName = tostring(cfg and cfg.name or "")
        local list = ProceduralDistributions and ProceduralDistributions.list and ProceduralDistributions.list[targetName] or nil
        local items = list and list.items or nil
        local weight = (tonumber(cfg and cfg.weight) or 0) * topUpBudget
        if isMusicStoreTarget(targetName) and weight > 0 and type(items) == "table" then
            categoryDiag.estimatedWeight = categoryDiag.estimatedWeight + weight
            categoryDiag.laneWeight.procedural = categoryDiag.laneWeight.procedural + weight
            local injected = injectIntoProcedural(targetName, placeholderFullType, weight, indexCache)
            if injected then
                recordInjected(summary, category, nil, LOOT_ROUTE_KEYS.topUp)
                recordInjectedEntry(categoryDiag, "procedural")
            else
                recordMutationResult(categoryDiag, "procedural", LOOT_RESULT_KEYS.alreadyPresent)
            end
        else
            recordMutationResult(categoryDiag, "procedural", LOOT_RESULT_KEYS.skipped)
        end
    end

    categoryDiag.averageTargetWeight.procedural = categoryDiag.laneWeight.procedural / math.max(1, categoryDiag.eligibleTargets.procedural)
    categoryDiag.averageEntryWeight.procedural = categoryDiag.laneWeight.procedural / math.max(1, tonumber(categoryDiag.injectedEntries.procedural) or 0)
end

local function injectMusicStoreDeviceTopUpLane(category, placeholderFullType, rate, summary, diagnostics, indexCache)
    if tostring(placeholderFullType or "") == "" then
        return
    end

    local topUpBudget = resolveMusicStoreMediaTopUpBudget(rate)
        * resolveMusicStoreDeviceTopUpCategoryBias(category)
        * resolveMusicStoreDeviceTopUpMultiplier()
    if topUpBudget <= 0 then
        return
    end

    local targets = NMLootMusicStoreMediaTopUpTargets or {}
    local categoryDiag = ensureCategoryDiagnostics(diagnostics, category)
    local eligibleTargets = 0
    for i = 1, #targets do
        local targetName = tostring(targets[i] and targets[i].name or "")
        if isMusicStoreTarget(targetName) then
            eligibleTargets = eligibleTargets + 1
        end
    end
    categoryDiag.eligibleTargets.procedural = categoryDiag.eligibleTargets.procedural + eligibleTargets
    if eligibleTargets < 1 then
        return
    end

    for i = 1, #targets do
        local cfg = targets[i]
        local targetName = tostring(cfg and cfg.name or "")
        local list = ProceduralDistributions and ProceduralDistributions.list and ProceduralDistributions.list[targetName] or nil
        local items = list and list.items or nil
        local weight = (tonumber(cfg and cfg.weight) or 0) * topUpBudget
        if isMusicStoreTarget(targetName) and weight > 0 and type(items) == "table" then
            categoryDiag.estimatedWeight = categoryDiag.estimatedWeight + weight
            categoryDiag.laneWeight.procedural = categoryDiag.laneWeight.procedural + weight
            local injected = injectIntoProcedural(targetName, placeholderFullType, weight, indexCache)
            if injected then
                recordInjected(summary, category, nil, LOOT_ROUTE_KEYS.topUp)
                recordInjectedEntry(categoryDiag, "procedural")
            else
                recordMutationResult(categoryDiag, "procedural", LOOT_RESULT_KEYS.alreadyPresent)
            end
        else
            recordMutationResult(categoryDiag, "procedural", LOOT_RESULT_KEYS.skipped)
        end
    end

    categoryDiag.averageTargetWeight.procedural = categoryDiag.laneWeight.procedural / math.max(1, categoryDiag.eligibleTargets.procedural)
    categoryDiag.averageEntryWeight.procedural = categoryDiag.laneWeight.procedural / math.max(1, tonumber(categoryDiag.injectedEntries.procedural) or 0)
end

function planner.applyBuildContext(context, options)
    local resolvedPools = context and context.resolvedPools or nil
    local mediaPool = resolvedPools and resolvedPools.routes and resolvedPools.routes.standard and resolvedPools.routes.standard.media
        or context and context.mediaLootPool and context.mediaLootPool.media
        or context and context.managedSpawnMediaPool
        or {}
    local devicePool = resolvedPools and resolvedPools.routes and resolvedPools.routes.standard and resolvedPools.routes.standard.devices
        or context and context.managedSpawnDevicePool
        or {}
    local storeDevicePool = resolvedPools and resolvedPools.routes and resolvedPools.routes.topUp and resolvedPools.routes.topUp.devices
        or {}
    local distributionAuditEnabled = options and options.distributionAuditEnabled == true
    local injected = newInjectionSummary()
    local diagnostics = {}
    local indexCache = {}
    local groupedVehicleTargets = countUniqueVehicleTargetsByRoleMap(context and context.vehicleTargets or {})
    local laneBudgets = {}
    local laneWeights = {}
    local totalMediaBudget = 0
    ACTIVE_LOOT_POLICY = context and context.lootPolicy or nil

    for i = 1, #MEDIA_CATEGORY_ORDER do
        local category = MEDIA_CATEGORY_ORDER[i]
        local rate = clamp(resolveActiveCategoryRate(category), 0.0, 4.0)
        local poolSize = countCategoryUnits(mediaPool, category)
        local laneBudget = poolSize > 0 and NMLootSandboxSettings.resolveIndependentMediaLaneBudget(rate) or 0
        laneBudgets[category] = laneBudget
        laneWeights[category] = laneBudget
        totalMediaBudget = totalMediaBudget + laneBudget
        ensureSimpleMediaDiag(diagnostics, category, rate, laneBudget, poolSize)
        local topUpPlaceholderFullType = NMLootPlaceholderResolver
            and NMLootPlaceholderResolver.getMediaPlaceholderFullType
            and NMLootPlaceholderResolver.getMediaPlaceholderFullType(category, LOOT_ROUTE_KEYS.topUp)
            or nil
        injectMusicStoreMediaTopUpLane(category, topUpPlaceholderFullType, rate, injected, diagnostics, indexCache)
        if laneBudget > 0 then
            local placeholderFullType = NMLootPlaceholderResolver
                and NMLootPlaceholderResolver.getMediaPlaceholderFullType
                and NMLootPlaceholderResolver.getMediaPlaceholderFullType(category, LOOT_ROUTE_KEYS.standard)
                or nil
            injectStandardMediaLane(category, placeholderFullType, laneBudget, injected, diagnostics, indexCache)
            injectStandardMediaVehicleLane(category, placeholderFullType, laneBudget, groupedVehicleTargets, injected, diagnostics, indexCache)
        end
    end

    for i = 1, #DEVICE_CATEGORY_ORDER do
        local category = DEVICE_CATEGORY_ORDER[i]
        local rate = clamp(resolveActiveCategoryRate(category), 0.0, 4.0)
        local poolSize = countDeviceCategoryUnits(devicePool, category)
        local storePoolSize = countDeviceCategoryUnits(storeDevicePool, category)
        local laneBudget = poolSize > 0 and resolveStandardDeviceLaneBudget(rate) or 0
        ensureSimpleDeviceDiag(diagnostics, category, rate, laneBudget, poolSize)
        if storePoolSize > 0 then
            local topUpPlaceholderFullType = NMLootPlaceholderResolver
                and NMLootPlaceholderResolver.getDevicePlaceholderFullType
                and NMLootPlaceholderResolver.getDevicePlaceholderFullType(category, LOOT_ROUTE_KEYS.topUp)
                or nil
            injectMusicStoreDeviceTopUpLane(category, topUpPlaceholderFullType, rate, injected, diagnostics, indexCache)
        end
        if laneBudget > 0 then
            local placeholderFullType = NMLootPlaceholderResolver
                and NMLootPlaceholderResolver.getDevicePlaceholderFullType
                and NMLootPlaceholderResolver.getDevicePlaceholderFullType(category, LOOT_ROUTE_KEYS.standard)
                or nil
            injectStandardDeviceLane(category, placeholderFullType, laneBudget, injected, diagnostics, indexCache)
            injectStandardDeviceVehicleLane(category, placeholderFullType, laneBudget, groupedVehicleTargets, injected, diagnostics, indexCache)
        end
    end

    local musicStoreCategoryWeights = nil
    local musicStoreLaneWeights = nil
    local managedSpawnMediaOwnership = nil
    if distributionAuditEnabled then
        musicStoreCategoryWeights, musicStoreLaneWeights = buildMusicStoreTargetDiagnostics()
        managedSpawnMediaOwnership = countMediaPoolOwnership(mediaPool)
    end

    ACTIVE_LOOT_POLICY = nil
    return {
        buildId = context and context.buildId or "",
        injected = injected,
        budgetDiagnostics = diagnostics,
        topUp = { disabled = false },
        standardRoute = {
            mediaShares = laneBudgets,
            mediaRawWeights = laneWeights,
            compensatedMediaShares = laneBudgets,
            compensatedMediaRawWeights = laneWeights,
            totalMediaBudget = totalMediaBudget
        },
        managedSpawnMediaCounts = NMManagedSpawnCatalog.countUnitPool(mediaPool, MEDIA_CATEGORY_ORDER),
        managedSpawnDeviceCounts = NMManagedSpawnCatalog.countUnitPool(devicePool, DEVICE_CATEGORY_ORDER),
        resolvedPoolCounts = resolvedPools and resolvedPools.countsByRoute or nil,
        managedSpawnMediaOwnership = managedSpawnMediaOwnership,
        musicStoreCategoryWeights = musicStoreCategoryWeights,
        musicStoreLaneWeights = musicStoreLaneWeights,
        managedSpawnPlaceholders = {
            cassettes = NMLootPlaceholderResolver.getMediaPlaceholderFullType("cassettes") or "",
            vinyl = NMLootPlaceholderResolver.getMediaPlaceholderFullType("vinyl") or "",
            cds = NMLootPlaceholderResolver.getMediaPlaceholderFullType("cds") or ""
        }
    }
end

return planner
