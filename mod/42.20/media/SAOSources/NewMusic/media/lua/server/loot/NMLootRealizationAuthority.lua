require "loot/NMManagedSpawnCatalog"
require "loot/NMLootSandboxSettings"
require "loot/NMLootStandardMediaTargets"

NMLootRealizationAuthority = NMLootRealizationAuthority or {}

local authority = NMLootRealizationAuthority

local MEDIA_CATEGORY_ORDER = NMLootSandboxSettings.MEDIA_CATEGORY_ORDER
local DEVICE_CATEGORY_ORDER = NMLootSandboxSettings.DEVICE_CATEGORY_ORDER
local VEHICLE_ROLE_ORDER = NMLootSandboxSettings.VEHICLE_ROLE_ORDER
local MUSIC_STORE_TARGET_ORDER = NMLootSandboxSettings.MUSIC_STORE_TARGET_ORDER
local clamp = NMLootSandboxSettings.clamp
local resolveCategoryRate = NMLootSandboxSettings.resolveCategoryRate
local resolveIndependentMediaLaneBudget = NMLootSandboxSettings.resolveIndependentMediaLaneBudget

local STANDARD_RESIDENTIAL_MEDIA_ROUTE_CLASS = "residential_misc"

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

local function resolveStandardMediaVehicleRouteCap(role)
    if tostring(role or "") == "glovebox" then
        return 2
    end
    return 3
end

local function orderedMediaUnitsForCategory(pool, category)
    return NMManagedSpawnCatalog.orderedMediaUnitsForCategory({ media = pool or {} }, category)
end

local function orderedDeviceUnitsForCategory(pool, category)
    return NMManagedSpawnCatalog.orderedDeviceUnitsForCategory({ devices = pool or {} }, category)
end

function authority.isMusicStoreTarget(listName)
    local name = tostring(listName or "")
    return string.sub(name, 1, #"MusicStore") == "MusicStore"
end

function authority.isResidentialProceduralTarget(listName)
    local name = tostring(listName or "")
    return name == "BedroomDresser"
        or name == "BedroomDresserClassy"
        or name == "LivingRoomSideTable"
        or name == "LivingRoomCabinet"
        or string.find(name, "LivingRoomShelf", 1, true) ~= nil
        or name == "RecRoomShelf"
end

function authority.resolveProceduralTargetCap(listName, source, kind)
    local name = tostring(listName or "")
    local sourceKey = tostring(source or "standard")
    local kindKey = tostring(kind or "media")
    if authority.isMusicStoreTarget(name) then
        if kindKey == "media" then
            return sourceKey == "topUp" and 3 or 2
        end
        return sourceKey == "topUp" and 2 or 1
    end
    if authority.isResidentialProceduralTarget(name) then
        return 1
    end
    if name == "StoreShelfCombo" then
        return kindKey == "media" and 2 or 1
    end
    if kindKey == "media" then
        return 2
    end
    return 1
end

function authority.resolveVehicleTargetCap(role, source, kind)
    local roleKey = tostring(role or "")
    local kindKey = tostring(kind or "media")
    if roleKey == "cargo" then
        return kindKey == "media" and 2 or 1
    end
    return 1
end

local function classifyProceduralTarget(listName)
    local name = tostring(listName or "")
    if authority.isMusicStoreTarget(name) then
        return "music_store"
    end
    if string.find(name, "ElectronicStore", 1, true) ~= nil
        or string.find(name, "Electronics", 1, true) ~= nil
        or string.find(name, "GigamartHouseElectronics", 1, true) ~= nil
        or string.find(name, "StoreShelfElectronics", 1, true) ~= nil
    then
        return "electronics"
    end
    if authority.isResidentialProceduralTarget(name) then
        return "residential_misc"
    end
    return "other"
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

local function ensureProfileAttempt(profiles, routeClass, route, kind)
    profiles[routeClass] = profiles[routeClass] or { id = routeClass, attempts = {} }
    local key = tostring(route or "") .. "|" .. tostring(kind or "")
    local attempt = profiles[routeClass].attempts[key]
    if attempt then
        return attempt
    end
    attempt = {
        id = key,
        route = tostring(route or "standard"),
        kind = tostring(kind or "media"),
        maxAdds = 0,
        rawWeights = {},
        categoryShares = {},
        totalWeight = 0
    }
    profiles[routeClass].attempts[key] = attempt
    return attempt
end

local function accumulateAttempt(profiles, routeClass, route, kind, category, weight, cap)
    if routeClass == "" or routeClass == "other" or weight <= 0 or cap <= 0 then
        return
    end
    local attempt = ensureProfileAttempt(profiles, routeClass, route, kind)
    attempt.maxAdds = math.max(tonumber(attempt.maxAdds) or 0, tonumber(cap) or 0)
    attempt.rawWeights[category] = (tonumber(attempt.rawWeights[category]) or 0) + weight
    attempt.totalWeight = (tonumber(attempt.totalWeight) or 0) + weight
end

local function finalizeProfiles(profiles)
    local routePriority = { standard = 1, topUp = 2 }
    local kindPriority = { media = 1, device = 2 }
    local finalized = {}
    for routeClass, profile in pairs(profiles) do
        local attempts = {}
        for _, attempt in pairs(profile.attempts) do
            local order = attempt.kind == "device" and DEVICE_CATEGORY_ORDER or MEDIA_CATEGORY_ORDER
            local totalWeight = tonumber(attempt.totalWeight) or 0
            for i = 1, #order do
                local category = order[i]
                local rawWeight = tonumber(attempt.rawWeights[category]) or 0
                attempt.categoryShares[category] = totalWeight > 0 and (rawWeight / totalWeight) or 0
            end
            if totalWeight > 0 and (tonumber(attempt.maxAdds) or 0) > 0 then
                attempts[#attempts + 1] = attempt
            end
        end
        table.sort(attempts, function(a, b)
            local aRoute = tonumber(routePriority[a.route]) or 99
            local bRoute = tonumber(routePriority[b.route]) or 99
            if aRoute ~= bRoute then
                return aRoute < bRoute
            end
            local aKind = tonumber(kindPriority[a.kind]) or 99
            local bKind = tonumber(kindPriority[b.kind]) or 99
            if aKind ~= bKind then
                return aKind < bKind
            end
            return (tonumber(a.totalWeight) or 0) > (tonumber(b.totalWeight) or 0)
        end)
        finalized[routeClass] = {
            id = routeClass,
            attempts = attempts
        }
    end
    return finalized
end

local function buildStandardProfiles(routes, lootPolicy, devicePool)
    local profiles = {}
    local standardRoute = routes and routes.standard or {}
    local laneBudgets = standardRoute.mediaShares or {}
    for i = 1, #MEDIA_CATEGORY_ORDER do
        local category = MEDIA_CATEGORY_ORDER[i]
        local laneBudget = tonumber(laneBudgets[category]) or 0
        if laneBudget > 0 then
            local targets = NMLootStandardMediaTargets and NMLootStandardMediaTargets[category] or {}
            for j = 1, #targets do
                local cfg = targets[j]
                local routeClass = classifyProceduralTarget(cfg.name)
                local weight = (tonumber(cfg.weight) or 0) * laneBudget
                if routeClass == STANDARD_RESIDENTIAL_MEDIA_ROUTE_CLASS then
                    weight = weight * resolveStandardMediaResidentialMultiplier()
                end
                accumulateAttempt(
                    profiles,
                    routeClass,
                    "standard",
                    "media",
                    category,
                    weight,
                    authority.resolveProceduralTargetCap(cfg.name, "standard", "media")
                )
            end
            for roleIndex = 1, #VEHICLE_ROLE_ORDER do
                local role = VEHICLE_ROLE_ORDER[roleIndex]
                if isVehicleMediaCategoryAllowed(category, role) then
                    accumulateAttempt(
                        profiles,
                        "vehicle_" .. tostring(role),
                        "standard",
                        "media",
                        category,
                        laneBudget * resolveStandardMediaResidentialMultiplier() * resolveStandardMediaVehicleMultiplier(),
                        resolveStandardMediaVehicleRouteCap(role)
                    )
                end
            end
        end

        local rate = clamp(resolveCategoryRate(category, lootPolicy), 0.0, 4.0)
        local topUpBudget = resolveMusicStoreMediaTopUpBudget(rate)
            * resolveMusicStoreMediaTopUpCategoryBias(category)
            * resolveMusicStoreMediaTopUpMultiplier()
        local topUpTargets = NMLootMusicStoreMediaTopUpTargets or {}
        for j = 1, #topUpTargets do
            local cfg = topUpTargets[j]
            local targetName = tostring(cfg and cfg.name or "")
            if authority.isMusicStoreTarget(targetName) then
                accumulateAttempt(
                    profiles,
                    "music_store",
                    "topUp",
                    "media",
                    category,
                    (tonumber(cfg.weight) or 0) * topUpBudget,
                    authority.resolveProceduralTargetCap(targetName, "topUp", "media")
                )
            end
        end
    end

    for i = 1, #DEVICE_CATEGORY_ORDER do
        local category = DEVICE_CATEGORY_ORDER[i]
        local rate = clamp(resolveCategoryRate(category, lootPolicy), 0.0, 4.0)
        local hasPool = #orderedDeviceUnitsForCategory(devicePool or {}, category) > 0
        local laneBudget = hasPool and resolveStandardDeviceLaneBudget(rate) or 0
        local topUpBudget = hasPool and (resolveMusicStoreMediaTopUpBudget(rate)
            * resolveMusicStoreDeviceTopUpCategoryBias(category)
            * resolveMusicStoreDeviceTopUpMultiplier()) or 0
        if topUpBudget > 0 then
            local topUpTargets = NMLootMusicStoreMediaTopUpTargets or {}
            for j = 1, #topUpTargets do
                local cfg = topUpTargets[j]
                local targetName = tostring(cfg and cfg.name or "")
                if authority.isMusicStoreTarget(targetName) then
                    accumulateAttempt(
                        profiles,
                        "music_store",
                        "topUp",
                        "device",
                        category,
                        (tonumber(cfg.weight) or 0) * topUpBudget,
                        authority.resolveProceduralTargetCap(targetName, "topUp", "device")
                    )
                end
            end
        end
        if laneBudget > 0 then
            local targets = NMLootStandardDeviceTargets and NMLootStandardDeviceTargets[category] or {}
            for j = 1, #targets do
                local cfg = targets[j]
                local targetName = tostring(cfg and cfg.name or "")
                local weight = (tonumber(cfg and cfg.weight) or 0)
                    * laneBudget
                    * resolveStandardMediaResidentialMultiplier()
                    * resolveStandardDeviceMultiplier()
                accumulateAttempt(
                    profiles,
                    classifyProceduralTarget(targetName),
                    "standard",
                    "device",
                    category,
                    weight,
                    authority.resolveProceduralTargetCap(targetName, "standard", "device")
                )
            end
            for roleIndex = 1, #VEHICLE_ROLE_ORDER do
                local role = VEHICLE_ROLE_ORDER[roleIndex]
                if isVehicleDeviceCategoryAllowed(category, role) then
                    accumulateAttempt(
                        profiles,
                        "vehicle_" .. tostring(role),
                        "standard",
                        "device",
                        category,
                        laneBudget
                            * resolveStandardMediaResidentialMultiplier()
                            * resolveStandardMediaVehicleMultiplier()
                            * resolveStandardDeviceMultiplier()
                            * resolveStandardDeviceVehicleMultiplier(),
                        authority.resolveVehicleTargetCap(role, "standard", "device")
                    )
                end
            end
        end
    end
    return finalizeProfiles(profiles)
end

function authority.build(config)
    local mediaPool = config and config.mediaPool or {}
    local devicePool = config and config.devicePool or {}
    local lootPolicy = config and config.lootPolicy or nil
    local standardMediaShares = {}
    local standardMediaRawWeights = {}
    local standardTotalMediaBudget = 0
    for i = 1, #MEDIA_CATEGORY_ORDER do
        local category = MEDIA_CATEGORY_ORDER[i]
        local rate = clamp(resolveCategoryRate(category, lootPolicy), 0.0, 4.0)
        local hasPool = #orderedMediaUnitsForCategory(mediaPool, category) > 0
        local laneBudget = hasPool and resolveIndependentMediaLaneBudget(rate) or 0
        standardMediaShares[category] = laneBudget
        standardMediaRawWeights[category] = laneBudget
        standardTotalMediaBudget = standardTotalMediaBudget + laneBudget
    end
    local standardCompensatedMediaShares, standardCompensatedMediaRawWeights = standardMediaShares, standardMediaRawWeights

    local routes = {
        standard = {
            mediaShares = standardMediaShares,
            mediaRawWeights = standardMediaRawWeights,
            compensatedMediaShares = standardCompensatedMediaShares,
            compensatedMediaRawWeights = standardCompensatedMediaRawWeights,
            totalMediaBudget = standardTotalMediaBudget
        },
        topUp = {
            disabled = false
        }
    }

    return {
        routes = routes,
        profiles = buildStandardProfiles(routes, lootPolicy, devicePool),
        targetDiagnostics = {
            musicStoreTargets = MUSIC_STORE_TARGET_ORDER
        }
    }
end

return authority
