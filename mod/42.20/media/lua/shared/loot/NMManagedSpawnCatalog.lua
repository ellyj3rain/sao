-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
-- Shared managed media/device spawn catalog for sandbox loot and zombie features.
NMManagedSpawnCatalog = NMManagedSpawnCatalog or {}

local CATEGORY_ORDER = {
    "cassettes",
    "vinyl",
    "cds",
    "walkman",
    "boombox",
    "cdplayer",
    "recordplayer"
}

local MEDIA_CATEGORY_ORDER = {
    "cassettes",
    "vinyl",
    "cds"
}

local DEVICE_CATEGORY_ORDER = {
    "walkman",
    "boombox",
    "cdplayer",
    "recordplayer"
}

local RARE_DEVICE_VARIANT_WEIGHTS = {
    ["NewMusic.WalkmanLore"] = 0.25,
    ["NewMusic.BoomboxOddbolt"] = 0.25,
    ["NewMusic.CDPlayerCow"] = 0.25
}

local BASE_ZOMBOID_OST_MEDIA = {
    ["NewMusic.CassettePZOSTA"] = true,
    ["NewMusic.CassettePZOSTB"] = true,
    ["NewMusic.CassettePZOSTCaseEmpty"] = true,
    ["NewMusic.CassettePZOSTCaseFull"] = true,
    ["NewMusic.CDPZOSTA"] = true,
    ["NewMusic.CDPZOSTB"] = true,
    ["NewMusic.CDPZOSTCoverEmpty"] = true,
    ["NewMusic.CDPZOSTCoverFull"] = true,
    ["NewMusic.VinylPZOSTA"] = true,
    ["NewMusic.VinylPZOSTB"] = true,
    ["NewMusic.JacketPZOSTEmpty"] = true,
    ["NewMusic.JacketPZOSTFull"] = true,
}

local function toLower(value)
    return string.lower(tostring(value or ""))
end

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function splitFullType(fullType)
    local raw = tostring(fullType or "")
    local dot = string.find(raw, "%.")
    if not dot then
        return "", raw
    end
    return string.sub(raw, 1, dot - 1), string.sub(raw, dot + 1)
end

local function countItemsInMap(itemMap)
    local n = 0
    for _ in pairs(itemMap or {}) do
        n = n + 1
    end
    return n
end

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

local function logCatalog(tag, detail)
    if NMCore and NMCore.logChannel then
        NMCore.logChannel("loot", tostring(tag or "spawn.catalog"), tostring(detail or ""))
    end
end

local function isTargetModId(modId)
    local lower = toLower(modId)
    return lower == "newmusic" or lower == "talisnewmusic"
end

local function valueContainsRequiredMod(value, expectedModId)
    local expected = toLower(expectedModId)
    if expected == "" or value == nil then
        return false
    end

    if type(value) == "string" then
        local lower = toLower(value)
        for token in string.gmatch(lower, "[^,;]+") do
            if trim(token) == expected then
                return true
            end
        end
        return trim(lower) == expected
    end

    if type(value) == "table" then
        for _, entry in pairs(value) do
            if valueContainsRequiredMod(entry, expected) then
                return true
            end
        end
        return false
    end

    if type(value) == "userdata" then
        local okSize, size = pcall(function()
            return value:size()
        end)
        if okSize and type(size) == "number" then
            for i = 0, size - 1 do
                local okEntry, entry = pcall(function()
                    return value:get(i)
                end)
                if okEntry and valueContainsRequiredMod(entry, expected) then
                    return true
                end
            end
        end
    end

    return false
end

local function resolveMediaCategoryFromCarrier(carrier)
    local c = tostring(carrier or "")
    if not (NMMediaContract and NMMediaContract.getCarrierKeys) then
        return nil
    end
    local carriers = NMMediaContract.getCarrierKeys()
    if c == tostring(carriers.cassette or "") then
        return "cassettes"
    end
    if c == tostring(carriers.vinyl or "") then
        return "vinyl"
    end
    if c == tostring(carriers.cd or "") then
        return "cds"
    end
    return nil
end

local function resolveRegisteredMediaCarrier(fullType)
    local _, itemType = splitFullType(fullType)
    local mapped = type(GlobalMusic) == "table" and GlobalMusic[itemType] or nil
    if mapped and tostring(mapped) ~= "" then
        return tostring(
            (NMMediaContract and NMMediaContract.normalizeCarrierToken and NMMediaContract.normalizeCarrierToken(mapped))
            or mapped
        )
    end
    return nil
end

local function resolveDeviceCategoryFromProfile(profile)
    local deviceType = toLower(profile and profile.deviceType or "")
    if deviceType == "walkman" then
        return "walkman"
    end
    if deviceType == "boombox" then
        return "boombox"
    end
    if deviceType == "cdplayer" then
        return "cdplayer"
    end
    if deviceType == "vinylplayer" or deviceType == "recordplayer" then
        return "recordplayer"
    end
    return nil
end

local function newCategoryMaps()
    local out = {}
    for i = 1, #CATEGORY_ORDER do
        out[CATEGORY_ORDER[i]] = {}
    end
    return out
end

local function newUnitPools()
    return {
        media = newCategoryMaps(),
        devices = newCategoryMaps()
    }
end

local function isBaseZomboidOSTMediaUnit(unit)
    if type(unit) ~= "table" then
        return false
    end
    local key = tostring(unit.key or unit.canonical or "")
    local spawnFullType = tostring(unit.spawnFullType or "")
    return BASE_ZOMBOID_OST_MEDIA[key] == true or BASE_ZOMBOID_OST_MEDIA[spawnFullType] == true
end

local function isBaseZomboidOSTMediaFullType(fullType)
    return BASE_ZOMBOID_OST_MEDIA[tostring(fullType or "")] == true
end

local function addMediaUnit(targetPools, unit, metadata)
    if not unit or not unit.category or not unit.canonicalKey then
        return false
    end
    local category = tostring(unit.category)
    local bucket = targetPools.media[category]
    if type(bucket) ~= "table" then
        return false
    end
    local key = tostring(unit.canonicalKey)
    local loadedOnly = metadata and metadata.loadedOnly == true
    local variantSuffix = loadedOnly and "|loaded" or "|loose"
    local variantKey = key .. variantSuffix
    if bucket[variantKey] then
        return false
    end
    bucket[variantKey] = {
        key = variantKey,
        canonicalKey = key,
        canonical = key,
        canonicalMediaFullType = tostring(unit.canonicalMediaFullType or key),
        insertedMediaFullType = tostring(unit.insertedMediaFullType or key),
        spawnFullType = tostring(unit.spawnFullType or ""),
        loadedOnly = loadedOnly,
        variantKind = loadedOnly and "loaded" or "loose",
        carrier = tostring(unit.carrier or ""),
        emptyCompanionFullType = tostring(unit.emptyCompanionFullType or "") ~= "" and tostring(unit.emptyCompanionFullType) or nil,
        hasCompanionCase = unit.hasCompanionCase == true,
        looseZombieRepresentativeFullType = tostring(unit.looseZombieRepresentativeFullType or unit.spawnFullType or unit.canonicalMediaFullType or key),
        insertedZombieMediaFullType = tostring(unit.insertedZombieMediaFullType or unit.insertedMediaFullType or unit.canonicalMediaFullType or key),
        companionZombieCaseFullType = tostring(unit.companionZombieCaseFullType or unit.emptyCompanionFullType or "") ~= "" and tostring(unit.companionZombieCaseFullType or unit.emptyCompanionFullType) or nil,
        variantWeight = tonumber(unit.variantWeight) or 1.0,
        isBaseZomboidOST = isBaseZomboidOSTMediaUnit(unit),
        modId = metadata and metadata.modId or "",
        owner = metadata and metadata.owner or ""
    }
    return true
end

local function addDeviceUnit(targetPools, unit, metadata)
    if not unit or not unit.category or not unit.key then
        return false
    end
    local category = tostring(unit.category)
    local bucket = targetPools.devices[category]
    if type(bucket) ~= "table" then
        return false
    end
    local key = tostring(unit.key)
    if bucket[key] then
        return false
    end
    bucket[key] = {
        key = key,
        spawnFullType = tostring(unit.spawnFullType or ""),
        deviceType = tostring(unit.deviceType or ""),
        supportedCarrier = tostring(unit.supportedCarrier or ""),
        variantWeight = tonumber(unit.variantWeight) or 1.0,
        modId = metadata and metadata.modId or "",
        owner = metadata and metadata.owner or ""
    }
    return true
end

local function resolveLoadedSpawnRepresentative(fullType, canonicalMedia, overrides)
    local current = tostring(fullType or "")
    local canonical = tostring(canonicalMedia or "")
    local loaded = overrides and overrides.canonicalToLoadedContainer and overrides.canonicalToLoadedContainer[canonical] or nil
    if loaded and loaded ~= "" then
        return loaded
    end

    if NMMediaContract and NMMediaContract.resolveContainerMediaBinding then
        local boundMedia = NMMediaContract.resolveContainerMediaBinding(current)
        if boundMedia and boundMedia ~= "" then
            if NMMediaContract.resolveContainerSwapFullType then
                local swapLoaded = NMMediaContract.resolveContainerSwapFullType(current, true)
                if swapLoaded and swapLoaded ~= "" then
                    return swapLoaded
                end
            end
            if NMMediaContract.isContainerLoadedFullType and NMMediaContract.isContainerLoadedFullType(current) == true then
                return current
            end
            return nil
        end
    end

    return nil
end

local function resolveEmptyCompanionFullType(loadedFullType)
    local current = tostring(loadedFullType or "")
    if current == "" then
        return nil
    end
    if not (NMMediaContract and NMMediaContract.resolveContainerSwapFullType) then
        return nil
    end
    local empty = NMMediaContract.resolveContainerSwapFullType(current, false)
    empty = tostring(empty or "")
    if empty == "" or empty == current then
        return nil
    end
    return empty
end

local function shouldSpawnManagedMediaWithCases()
    if NMRuntimeConfig and NMRuntimeConfig.getMediaSpawnsWithCasesEnabled then
        return NMRuntimeConfig.getMediaSpawnsWithCasesEnabled() == true
    end
    return true
end

local function buildLooseManagedMediaUnit(category, carrier, canonical)
    return {
        category = category,
        carrier = carrier,
        canonicalKey = canonical,
        canonicalMediaFullType = canonical,
        insertedMediaFullType = canonical,
        spawnFullType = canonical,
        loadedOnly = false,
        emptyCompanionFullType = nil,
        hasCompanionCase = false,
        looseZombieRepresentativeFullType = canonical,
        insertedZombieMediaFullType = canonical,
        companionZombieCaseFullType = nil
    }
end

local function resolveManagedMediaUnit(fullType, overrides)
    local current = tostring(fullType or "")
    if current == "" then
        return nil
    end

    local boundMedia = NMMediaContract and NMMediaContract.resolveContainerMediaBinding and NMMediaContract.resolveContainerMediaBinding(current) or nil
    if boundMedia and boundMedia ~= "" then
        local canonical = NMMediaContract and NMMediaContract.resolveMediaCanonical and NMMediaContract.resolveMediaCanonical(boundMedia) or boundMedia
        canonical = tostring(canonical or boundMedia)
        local carrier = resolveRegisteredMediaCarrier(canonical)
        local category = resolveMediaCategoryFromCarrier(carrier)
        if category and not shouldSpawnManagedMediaWithCases() then
            return buildLooseManagedMediaUnit(category, carrier, canonical)
        end
        local loaded = resolveLoadedSpawnRepresentative(current, canonical, overrides)
        if category and loaded and loaded ~= "" then
            local emptyCompanionFullType = resolveEmptyCompanionFullType(loaded)
            return {
                category = category,
                carrier = carrier,
                canonicalKey = canonical,
                canonicalMediaFullType = canonical,
                insertedMediaFullType = canonical,
                spawnFullType = loaded,
                loadedOnly = true,
                emptyCompanionFullType = emptyCompanionFullType,
                hasCompanionCase = emptyCompanionFullType ~= nil,
                looseZombieRepresentativeFullType = loaded,
                insertedZombieMediaFullType = canonical,
                companionZombieCaseFullType = emptyCompanionFullType
            }
        end
        return nil
    end

    local canonical = NMMediaContract and NMMediaContract.resolveMediaCanonical and NMMediaContract.resolveMediaCanonical(current) or current
    canonical = tostring(canonical or current)
    local carrier = resolveRegisteredMediaCarrier(canonical)
    local category = resolveMediaCategoryFromCarrier(carrier)
    if not category then
        return nil
    end
    if not shouldSpawnManagedMediaWithCases() then
        return buildLooseManagedMediaUnit(category, carrier, canonical)
    end

    local loaded = resolveLoadedSpawnRepresentative(current, canonical, overrides)
    if loaded and loaded ~= "" then
        local emptyCompanionFullType = resolveEmptyCompanionFullType(loaded)
        return {
            category = category,
            carrier = carrier,
            canonicalKey = canonical,
            canonicalMediaFullType = canonical,
            insertedMediaFullType = canonical,
            spawnFullType = loaded,
            loadedOnly = true,
            emptyCompanionFullType = emptyCompanionFullType,
            hasCompanionCase = emptyCompanionFullType ~= nil,
            looseZombieRepresentativeFullType = loaded,
            insertedZombieMediaFullType = canonical,
            companionZombieCaseFullType = emptyCompanionFullType
        }
    end

    return buildLooseManagedMediaUnit(category, carrier, canonical)
end

local function resolveManagedDeviceUnit(fullType)
    if not (NMDeviceProfiles and NMDeviceProfiles.getForFullType) then
        return nil
    end
    local profile = NMDeviceProfiles.getForFullType(fullType)
    if not profile or profile.isMediaContainerOnly == true then
        return nil
    end
    local category = resolveDeviceCategoryFromProfile(profile)
    if not category then
        return nil
    end
    return {
        category = category,
        key = tostring(fullType or ""),
        spawnFullType = tostring(fullType or ""),
        deviceType = tostring(profile.deviceType or ""),
        supportedCarrier = tostring(profile.supportedCarrier or ""),
        variantWeight = tonumber(RARE_DEVICE_VARIANT_WEIGHTS[tostring(fullType or "")]) or 1.0
    }
end

local function flattenUnitMap(unitMap)
    local out = {}
    for _, category in ipairs(CATEGORY_ORDER) do
        for _, unit in pairs(unitMap[category] or {}) do
            local spawnFullType = tostring(unit.spawnFullType or "")
            if spawnFullType ~= "" then
                out[spawnFullType] = category
            end
        end
    end
    return out
end

local function countUnitPool(unitMap, order)
    local counts = {}
    local useOrder = order or CATEGORY_ORDER
    for i = 1, #useOrder do
        local category = useOrder[i]
        counts[category] = countItemsInMap(unitMap and unitMap[category] or nil)
    end
    return counts
end

local function mergeUnitMapsInto(targetMap, unitMap, order)
    local useOrder = order or CATEGORY_ORDER
    for i = 1, #useOrder do
        local category = useOrder[i]
        for _, unit in pairs(unitMap and unitMap[category] or {}) do
            local spawnFullType = tostring(unit and unit.spawnFullType or "")
            if spawnFullType ~= "" and targetMap[spawnFullType] == nil then
                targetMap[spawnFullType] = category
            end
        end
    end
end

local function orderedUnitsForCategory(unitMap, category)
    local values = {}
    for _, unit in pairs(unitMap and unitMap[category] or {}) do
        values[#values + 1] = unit
    end
    table.sort(values, function(a, b)
        return tostring(a.key or a.canonical or a.spawnFullType or "") < tostring(b.key or b.canonical or b.spawnFullType or "")
    end)
    return values
end

function NMManagedSpawnCatalog.buildCompatibleChildModSet()
    local startedAt = nowMs()
    local compatible = {}
    if not (getActivatedMods and getModInfoByID) then
        return compatible
    end

    local activated = getActivatedMods()
    if not activated then
        return compatible
    end

    local okSize, size = pcall(function()
        return activated:size()
    end)
    if not okSize or type(size) ~= "number" then
        return compatible
    end

    local candidateMethods = {
        "getRequire",
        "getRequireString",
        "getRequireValue",
        "getRequireList"
    }

    for i = 0, size - 1 do
        local modId = tostring(activated:get(i) or "")
        if modId ~= "" and not isTargetModId(modId) then
            local modInfo = getModInfoByID(modId)
            if modInfo then
                for _, methodName in ipairs(candidateMethods) do
                    local method = modInfo[methodName]
                    if method then
                        local okValue, value = pcall(method, modInfo)
                        if okValue and valueContainsRequiredMod(value, "NewMusic") then
                            compatible[toLower(modId)] = true
                            break
                        end
                    end
                end
            end
        end
    end

    logCatalog(
        "spawn.catalog compatible child mods",
        string.format(
            "elapsedMs=%d activated=%d compatible=%d",
            elapsedMs(startedAt),
            tonumber(size) or 0,
            countItemsInMap(compatible)
        )
    )

    return compatible
end

function NMManagedSpawnCatalog.buildLoadedContainerOverrideRegistry(allItems)
    local startedAt = nowMs()
    local overrides = {
        mediaToContainer = {},
        canonicalToLoadedContainer = {},
        loadedRepresentatives = {}
    }
    if not (NMMediaContract and NMMediaContract.resolveContainerMediaBinding and NMMediaContract.isContainerLoadedFullType) then
        return overrides
    end
    if not allItems then
        return overrides
    end

    for i = 0, allItems:size() - 1 do
        local item = allItems:get(i)
        if item then
            local containerFullType = tostring(item:getFullName() or "")
            local boundMedia = NMMediaContract.resolveContainerMediaBinding(containerFullType)
            if boundMedia and boundMedia ~= "" and NMMediaContract.isContainerLoadedFullType(containerFullType) == true then
                local canonical = NMMediaContract.resolveMediaCanonical and NMMediaContract.resolveMediaCanonical(boundMedia) or boundMedia
                canonical = tostring(canonical or boundMedia)
                if canonical ~= "" then
                    overrides.mediaToContainer[canonical] = containerFullType
                    overrides.canonicalToLoadedContainer[canonical] = containerFullType
                    overrides.loadedRepresentatives[containerFullType] = true
                end
            end
        end
    end

    logCatalog(
        "spawn.catalog loaded overrides",
        string.format(
            "elapsedMs=%d allItems=%d boundMedia=%d loadedRepresentatives=%d",
            elapsedMs(startedAt),
            tonumber(allItems:size()) or 0,
            countItemsInMap(overrides.mediaToContainer),
            countItemsInMap(overrides.loadedRepresentatives)
        )
    )

    return overrides
end

function NMManagedSpawnCatalog.buildManagedPools(allItems, overrides, compatibleChildMods, options)
    local startedAt = nowMs()
    local basePools = newUnitPools()
    local childPools = {}
    local skippedMods = {}
    local skippedFalsePositives = {}
    local bareMediaRepresentatives = {}
    local metrics = {
        mediaResolveMs = 0,
        deviceResolveMs = 0,
        mediaUnits = 0,
        deviceUnits = 0
    }

    if not allItems then
        return basePools, childPools, skippedMods, skippedFalsePositives, bareMediaRepresentatives
    end

    for i = 0, allItems:size() - 1 do
        local item = allItems:get(i)
        if item then
            local modId = tostring(item:getModID() or "")
            local fullType = tostring(item:getFullName() or "")
            local mediaResolveStartedAt = nowMs()
            local mediaUnit = resolveManagedMediaUnit(fullType, overrides)
            metrics.mediaResolveMs = metrics.mediaResolveMs + elapsedMs(mediaResolveStartedAt)
            local deviceResolveStartedAt = nowMs()
            local deviceUnit = resolveManagedDeviceUnit(fullType)
            metrics.deviceResolveMs = metrics.deviceResolveMs + elapsedMs(deviceResolveStartedAt)

            if mediaUnit then
                metrics.mediaUnits = metrics.mediaUnits + 1
                if mediaUnit.loadedOnly ~= true then
                    bareMediaRepresentatives[mediaUnit.spawnFullType] = true
                end
                local metadata = { modId = modId, owner = isTargetModId(modId) and "base" or "child", loadedOnly = mediaUnit.loadedOnly == true }
                if isTargetModId(modId) then
                    addMediaUnit(basePools, mediaUnit, metadata)
                elseif compatibleChildMods[toLower(modId)] then
                    childPools[modId] = childPools[modId] or newUnitPools()
                    addMediaUnit(childPools[modId], mediaUnit, metadata)
                elseif modId ~= "" and modId ~= "Base" and modId ~= "pz-vanilla" then
                    skippedMods[modId] = true
                end
            elseif deviceUnit then
                metrics.deviceUnits = metrics.deviceUnits + 1
                if isTargetModId(modId) then
                    addDeviceUnit(basePools, deviceUnit, { modId = modId, owner = "base" })
                elseif compatibleChildMods[toLower(modId)] then
                    childPools[modId] = childPools[modId] or newUnitPools()
                    addDeviceUnit(childPools[modId], deviceUnit, { modId = modId, owner = "child" })
                end
            end
        end
    end

    logCatalog(
        "spawn.catalog managed pools",
        string.format(
            "elapsedMs=%d allItems=%d mediaUnits=%d deviceUnits=%d mediaResolveMs=%d deviceResolveMs=%d skippedMods=%d falsePositives=%d childMods=%d bareMedia=%d",
            elapsedMs(startedAt),
            tonumber(allItems:size()) or 0,
            metrics.mediaUnits,
            metrics.deviceUnits,
            metrics.mediaResolveMs,
            metrics.deviceResolveMs,
            countItemsInMap(skippedMods),
            countItemsInMap(skippedFalsePositives),
            countItemsInMap(childPools),
            countItemsInMap(bareMediaRepresentatives)
        )
    )

    return basePools, childPools, skippedMods, skippedFalsePositives, bareMediaRepresentatives
end

function NMManagedSpawnCatalog.buildCatalog(allItems, options)
    local startedAt = nowMs()
    local compatibleChildMods = NMManagedSpawnCatalog.buildCompatibleChildModSet()
    local overrides = NMManagedSpawnCatalog.buildLoadedContainerOverrideRegistry(allItems)
    local basePools, childPools, skippedMods, skippedFalsePositives, bareMediaRepresentatives =
        NMManagedSpawnCatalog.buildManagedPools(allItems, overrides, compatibleChildMods, options)

    logCatalog(
        "spawn.catalog build total",
        string.format(
            "elapsedMs=%d allItems=%d compatibleChildMods=%d childPools=%d baseMedia=%d baseDevices=%d",
            elapsedMs(startedAt),
            tonumber(allItems and allItems:size()) or 0,
            countItemsInMap(compatibleChildMods),
            countItemsInMap(childPools),
            countItemsInMap(flattenUnitMap(basePools.media)),
            countItemsInMap(flattenUnitMap(basePools.devices))
        )
    )

    return {
        compatibleChildMods = compatibleChildMods,
        overrides = overrides,
        basePools = basePools,
        childPools = childPools,
        skippedMods = skippedMods,
        skippedFalsePositives = skippedFalsePositives,
        bareMediaRepresentatives = bareMediaRepresentatives
    }
end

function NMManagedSpawnCatalog.filterBaseZomboidOSTMedia(basePools, ostEnabled)
    if ostEnabled == nil and NMRuntimeConfig and NMRuntimeConfig.getZomboidOSTEnabled then
        ostEnabled = NMRuntimeConfig.getZomboidOSTEnabled() == true
    end
    if ostEnabled == true then
        return 0
    end

    local removed = 0
    for i = 1, #MEDIA_CATEGORY_ORDER do
        local category = MEDIA_CATEGORY_ORDER[i]
        local bucket = basePools and basePools.media and basePools.media[category] or nil
        if type(bucket) == "table" then
            for key, unit in pairs(bucket) do
                if isBaseZomboidOSTMediaUnit(unit) then
                    bucket[key] = nil
                    removed = removed + 1
                end
            end
        end
    end
    return removed
end

function NMManagedSpawnCatalog.isBaseZomboidOSTMediaFullType(fullType)
    return isBaseZomboidOSTMediaFullType(fullType)
end

function NMManagedSpawnCatalog.buildManagedMediaFootprint(basePools, childPools, presenceIndex)
    local managedMediaMap = {}
    local managedLootMap = {}
    mergeUnitMapsInto(managedMediaMap, basePools and basePools.media or nil, MEDIA_CATEGORY_ORDER)
    mergeUnitMapsInto(managedLootMap, basePools and basePools.media or nil, MEDIA_CATEGORY_ORDER)
    mergeUnitMapsInto(managedLootMap, basePools and basePools.devices or nil, DEVICE_CATEGORY_ORDER)
    for _, pools in pairs(childPools or {}) do
        mergeUnitMapsInto(managedMediaMap, pools and pools.media or nil, MEDIA_CATEGORY_ORDER)
        mergeUnitMapsInto(managedLootMap, pools and pools.media or nil, MEDIA_CATEGORY_ORDER)
        mergeUnitMapsInto(managedLootMap, pools and pools.devices or nil, DEVICE_CATEGORY_ORDER)
    end

    local managedMediaCounts = {}
    local managedLootCounts = {}
    local presentManagedCounts = {}
    for i = 1, #MEDIA_CATEGORY_ORDER do
        local category = MEDIA_CATEGORY_ORDER[i]
        managedMediaCounts[category] = 0
        presentManagedCounts[category] = 0
    end
    for i = 1, #CATEGORY_ORDER do
        managedLootCounts[CATEGORY_ORDER[i]] = 0
    end

    local presentManagedMedia = 0
    for fullType, category in pairs(managedMediaMap) do
        managedMediaCounts[category] = (tonumber(managedMediaCounts[category]) or 0) + 1
        local present = presenceIndex
            and (
                presenceIndex.procedural[fullType] == true
                or presenceIndex.suburbs[fullType] == true
                or presenceIndex.vehicle[fullType] == true
            )
        if present then
            presentManagedCounts[category] = (tonumber(presentManagedCounts[category]) or 0) + 1
            presentManagedMedia = presentManagedMedia + 1
        end
    end
    for _, category in pairs(managedLootMap) do
        managedLootCounts[category] = (tonumber(managedLootCounts[category]) or 0) + 1
    end

    local maxPresent = 0
    local maxCategory = ""
    for i = 1, #MEDIA_CATEGORY_ORDER do
        local category = MEDIA_CATEGORY_ORDER[i]
        local count = tonumber(presentManagedCounts[category]) or 0
        if count > maxPresent then
            maxPresent = count
            maxCategory = category
        end
    end

    return {
        managedMediaMap = managedMediaMap,
        managedLootMap = managedLootMap,
        managedMediaCounts = managedMediaCounts,
        managedLootCounts = managedLootCounts,
        presentManagedCounts = presentManagedCounts,
        uniqueManagedMedia = countItemsInMap(managedMediaMap),
        presentManagedMedia = presentManagedMedia,
        oversizedRiskCategory = maxCategory,
        oversizedRiskCount = maxPresent
    }
end

function NMManagedSpawnCatalog.newUnitPools()
    return newUnitPools()
end

function NMManagedSpawnCatalog.newCategoryMaps()
    return newCategoryMaps()
end

function NMManagedSpawnCatalog.flattenUnitMap(unitMap)
    return flattenUnitMap(unitMap)
end

function NMManagedSpawnCatalog.countUnitPool(unitMap, order)
    return countUnitPool(unitMap, order)
end

function NMManagedSpawnCatalog.orderedMediaUnitsForCategory(pools, category)
    return orderedUnitsForCategory(pools and pools.media or nil, category)
end

function NMManagedSpawnCatalog.orderedDeviceUnitsForCategory(pools, category)
    return orderedUnitsForCategory(pools and pools.devices or nil, category)
end

function NMManagedSpawnCatalog.getCategoryOrder()
    return CATEGORY_ORDER
end

function NMManagedSpawnCatalog.getMediaCategoryOrder()
    return MEDIA_CATEGORY_ORDER
end

function NMManagedSpawnCatalog.getDeviceCategoryOrder()
    return DEVICE_CATEGORY_ORDER
end

return NMManagedSpawnCatalog
