require "loot/NMManagedSpawnCatalog"
require "loot/NMMediaLootPool"

NMLootResolvedPools = NMLootResolvedPools or {}

local resolvedPools = NMLootResolvedPools

local MEDIA_CATEGORY_ORDER = NMManagedSpawnCatalog.getMediaCategoryOrder and NMManagedSpawnCatalog.getMediaCategoryOrder()
    or { "cassettes", "vinyl", "cds" }
local DEVICE_CATEGORY_ORDER = NMManagedSpawnCatalog.getDeviceCategoryOrder and NMManagedSpawnCatalog.getDeviceCategoryOrder()
    or { "walkman", "boombox", "cdplayer", "recordplayer" }

local ROUTE_ORDER = {
    "standard",
    "topUp"
}

local function cloneMediaUnit(unit, category)
    if type(unit) ~= "table" then
        return nil
    end
    return {
        key = tostring(unit.key or unit.canonical or unit.spawnFullType or ""),
        canonicalKey = tostring(unit.canonicalKey or unit.canonical or unit.canonicalMediaFullType or ""),
        canonical = tostring(unit.canonical or unit.canonicalKey or unit.canonicalMediaFullType or ""),
        canonicalMediaFullType = tostring(unit.canonicalMediaFullType or unit.insertedMediaFullType or unit.spawnFullType or ""),
        insertedMediaFullType = tostring(unit.insertedMediaFullType or unit.canonicalMediaFullType or unit.spawnFullType or ""),
        spawnFullType = tostring(unit.spawnFullType or ""),
        loadedOnly = unit.loadedOnly == true,
        variantKind = tostring(unit.variantKind or (unit.loadedOnly == true and "loaded" or "loose")),
        carrier = tostring(unit.carrier or ""),
        owner = tostring(unit.owner or ""),
        modId = tostring(unit.modId or ""),
        variantWeight = tonumber(unit.variantWeight) or 1.0,
        category = tostring(category or unit.category or ""),
        emptyCompanionFullType = tostring(unit.emptyCompanionFullType or "") ~= "" and tostring(unit.emptyCompanionFullType) or nil,
        hasCompanionCase = unit.hasCompanionCase == true,
        companionZombieCaseFullType = tostring(unit.companionZombieCaseFullType or "") ~= "" and tostring(unit.companionZombieCaseFullType) or nil,
        isBaseZomboidOST = unit.isBaseZomboidOST == true
    }
end

local function cloneDeviceUnit(unit, category)
    if type(unit) ~= "table" then
        return nil
    end
    return {
        key = tostring(unit.key or unit.spawnFullType or ""),
        spawnFullType = tostring(unit.spawnFullType or ""),
        deviceType = tostring(unit.deviceType or ""),
        supportedCarrier = tostring(unit.supportedCarrier or ""),
        variantWeight = tonumber(unit.variantWeight) or 1.0,
        modId = tostring(unit.modId or ""),
        owner = tostring(unit.owner or ""),
        category = tostring(category or unit.category or "")
    }
end

local function newCategoryMaps(order)
    local out = {}
    for i = 1, #(order or {}) do
        out[order[i]] = {}
    end
    return out
end

local function newCountMap(order)
    local out = {}
    for i = 1, #(order or {}) do
        out[order[i]] = 0
    end
    return out
end

local function newRouteView()
    return {
        media = newCategoryMaps(MEDIA_CATEGORY_ORDER),
        devices = newCategoryMaps(DEVICE_CATEGORY_ORDER)
    }
end

local function areMediaCasesEnabled()
    return not (NMRuntimeConfig and NMRuntimeConfig.getMediaSpawnsWithCasesEnabled)
        or NMRuntimeConfig.getMediaSpawnsWithCasesEnabled() == true
end

local function isZomboidOSTEnabled()
    return not (NMRuntimeConfig and NMRuntimeConfig.getZomboidOSTEnabled)
        or NMRuntimeConfig.getZomboidOSTEnabled() == true
end

local function isConvertVanillaEnabled()
    return not (NMRuntimeConfig and NMRuntimeConfig.getConvertVanillaCDsAndCDPlayersEnabled)
        or NMRuntimeConfig.getConvertVanillaCDsAndCDPlayersEnabled() == true
end

local function getRate(getter)
    if type(getter) ~= "function" then
        return 0
    end
    return tonumber(getter()) or 0
end

local function capturePolicy()
    return {
        casesEnabled = areMediaCasesEnabled(),
        ostEnabled = isZomboidOSTEnabled(),
        convertVanilla = isConvertVanillaEnabled(),
        rates = {
            cassettes = getRate(NMRuntimeConfig and NMRuntimeConfig.getCassettesSpawnRate or nil),
            vinyl = getRate(NMRuntimeConfig and NMRuntimeConfig.getVinylRecordsSpawnRate or nil),
            cds = getRate(NMRuntimeConfig and NMRuntimeConfig.getCDsSpawnRate or nil),
            walkman = getRate(NMRuntimeConfig and NMRuntimeConfig.getWalkmanSpawnRate or nil),
            boombox = getRate(NMRuntimeConfig and NMRuntimeConfig.getBoomboxSpawnRate or nil),
            cdplayer = getRate(NMRuntimeConfig and NMRuntimeConfig.getCDPlayerSpawnRate or nil),
            recordplayer = getRate(NMRuntimeConfig and NMRuntimeConfig.getRecordPlayerSpawnRate or nil)
        }
    }
end

local function clonePolicy(policy)
    local cloned = NMLootPolicySnapshot and NMLootPolicySnapshot.clone and NMLootPolicySnapshot.clone(policy) or nil
    if cloned ~= nil then
        return cloned
    end
    return capturePolicy()
end

local function formatCountMap(map, order)
    local parts = {}
    for i = 1, #(order or {}) do
        local key = order[i]
        parts[#parts + 1] = key .. "=" .. tostring(tonumber(map and map[key]) or 0)
    end
    return table.concat(parts, " ")
end

local function formatResolvedRouteCounts(routeRecord)
    if type(routeRecord) ~= "table" then
        return "none"
    end
    return string.format(
        "media={%s} loose={%s} loaded={%s} devices={%s}",
        formatCountMap(routeRecord.media or {}, MEDIA_CATEGORY_ORDER),
        formatCountMap(routeRecord.loose or {}, MEDIA_CATEGORY_ORDER),
        formatCountMap(routeRecord.loaded or {}, MEDIA_CATEGORY_ORDER),
        formatCountMap(routeRecord.devices or {}, DEVICE_CATEGORY_ORDER)
    )
end

local function logResolvedPoolShape(buildId, policy, countsByRoute)
    if not (NMCore and NMCore.logChannel) then
        return
    end
    NMCore.logChannel(
        "loot",
        "sandbox.loot policy pool shape",
        string.format(
            "buildId=%s policy={%s} standard={%s} topUp={%s}",
            tostring(buildId or ""),
            tostring(NMLootPolicySnapshot and NMLootPolicySnapshot.formatPolicy and NMLootPolicySnapshot.formatPolicy(policy) or "unknown"),
            tostring(formatResolvedRouteCounts(countsByRoute and countsByRoute.standard)),
            tostring(formatResolvedRouteCounts(countsByRoute and countsByRoute.topUp))
        )
    )
end

local function formatAuthorityProfiles(realizationAuthority)
    local profiles = realizationAuthority and realizationAuthority.profiles or {}
    local orderedKeys = {
        "residential_misc",
        "electronics",
        "music_store",
        "vehicle_glovebox",
        "vehicle_seatrear",
        "vehicle_cargo"
    }
    local parts = {}
    for i = 1, #orderedKeys do
        local key = orderedKeys[i]
        local profile = profiles[key]
        if type(profile) == "table" and type(profile.attempts) == "table" and #profile.attempts > 0 then
            local attempts = {}
            for j = 1, #profile.attempts do
                local attempt = profile.attempts[j]
                attempts[#attempts + 1] = string.format(
                    "%s:%s:%s",
                    tostring(attempt.route or ""),
                    tostring(attempt.kind or ""),
                    tostring(attempt.maxAdds or 0)
                )
            end
            parts[#parts + 1] = tostring(key) .. "={" .. table.concat(attempts, ",") .. "}"
        end
    end
    return #parts > 0 and table.concat(parts, " ") or "none"
end

local function buildCacheKey(policy)
    local rates = policy and policy.rates or {}
    return table.concat({
        "cases=" .. tostring(policy and policy.casesEnabled == true),
        "ost=" .. tostring(policy and policy.ostEnabled == true),
        "convertVanilla=" .. tostring(policy and policy.convertVanilla == true),
        "cassettes=" .. tostring(rates.cassettes or 0),
        "vinyl=" .. tostring(rates.vinyl or 0),
        "cds=" .. tostring(rates.cds or 0),
        "walkman=" .. tostring(rates.walkman or 0),
        "boombox=" .. tostring(rates.boombox or 0),
        "cdplayer=" .. tostring(rates.cdplayer or 0),
        "recordplayer=" .. tostring(rates.recordplayer or 0)
    }, "|")
end

local function isAllowedMediaUnit(unit, policy)
    if type(unit) ~= "table" then
        return false
    end
    if policy and policy.ostEnabled ~= true and unit.isBaseZomboidOST == true then
        return false
    end
    if policy and policy.casesEnabled ~= true and (unit.loadedOnly == true or unit.hasCompanionCase == true) then
        return false
    end
    return tostring(unit.spawnFullType or "") ~= ""
end

local function addMediaUnitsForRoute(targetRoute, sourcePools, policy, counts)
    for i = 1, #MEDIA_CATEGORY_ORDER do
        local category = MEDIA_CATEGORY_ORDER[i]
        local ordered = NMManagedSpawnCatalog.orderedMediaUnitsForCategory({ media = sourcePools or {} }, category)
        for j = 1, #ordered do
            local cloned = cloneMediaUnit(ordered[j], category)
            if cloned and isAllowedMediaUnit(cloned, policy) then
                targetRoute.media[category][#targetRoute.media[category] + 1] = cloned
                counts.media[category] = (tonumber(counts.media[category]) or 0) + 1
                if cloned.loadedOnly == true then
                    counts.loaded[category] = (tonumber(counts.loaded[category]) or 0) + 1
                else
                    counts.loose[category] = (tonumber(counts.loose[category]) or 0) + 1
                end
            end
        end
    end
end

local function addDeviceUnitsForRoute(targetRoute, sourcePools, counts)
    for i = 1, #DEVICE_CATEGORY_ORDER do
        local category = DEVICE_CATEGORY_ORDER[i]
        local ordered = NMManagedSpawnCatalog.orderedDeviceUnitsForCategory({ devices = sourcePools or {} }, category)
        for j = 1, #ordered do
            local cloned = cloneDeviceUnit(ordered[j], category)
            if cloned and tostring(cloned.spawnFullType or "") ~= "" then
                targetRoute.devices[category][#targetRoute.devices[category] + 1] = cloned
                counts.devices[category] = (tonumber(counts.devices[category]) or 0) + 1
            end
        end
    end
end

local function newCounts()
    return {
        media = newCountMap(MEDIA_CATEGORY_ORDER),
        loose = newCountMap(MEDIA_CATEGORY_ORDER),
        loaded = newCountMap(MEDIA_CATEGORY_ORDER),
        devices = newCountMap(DEVICE_CATEGORY_ORDER)
    }
end

local function buildRouteViews(buildContext, policy)
    local routes = {}
    local countsByRoute = {}
    for i = 1, #ROUTE_ORDER do
        local route = ROUTE_ORDER[i]
        routes[route] = newRouteView()
        countsByRoute[route] = newCounts()
        if route == "standard" or route == "topUp" then
            local authoritativeMediaPool = buildContext
                and buildContext.mediaLootPool
                and buildContext.mediaLootPool.media
                or buildContext and buildContext.managedSpawnMediaPool
                or nil
            addMediaUnitsForRoute(routes[route], authoritativeMediaPool, policy, countsByRoute[route])
        end
        if route == "standard" or route == "topUp" then
            addDeviceUnitsForRoute(
                routes[route],
                buildContext and buildContext.managedSpawnDevicePool or nil,
                countsByRoute[route]
            )
        end
    end
    return routes, countsByRoute
end

function resolvedPools.build(buildContext)
    local policy = clonePolicy(buildContext and buildContext.lootPolicy or nil)
    local routes, countsByRoute = buildRouteViews(buildContext or {}, policy)
    local realizationAuthority = NMLootRealizationAuthority
        and NMLootRealizationAuthority.build
        and NMLootRealizationAuthority.build({
            mediaPool = routes.standard and routes.standard.media or nil,
            devicePool = routes.standard and routes.standard.devices or nil,
            lootPolicy = policy
        })
        or nil
    logResolvedPoolShape(buildContext and buildContext.buildId or "", policy, countsByRoute)
    if NMCore and NMCore.logChannel then
        NMCore.logChannel(
            "loot",
            "sandbox.loot authority profiles",
            string.format(
                "buildId=%s profiles=%s",
                tostring(buildContext and buildContext.buildId or ""),
                formatAuthorityProfiles(realizationAuthority)
            )
        )
    end
    return {
        cacheKey = buildCacheKey(policy),
        policy = policy,
        routes = routes,
        countsByRoute = countsByRoute,
        realizationAuthority = realizationAuthority
    }
end

function resolvedPools.getRouteOrder()
    return ROUTE_ORDER
end

return resolvedPools
