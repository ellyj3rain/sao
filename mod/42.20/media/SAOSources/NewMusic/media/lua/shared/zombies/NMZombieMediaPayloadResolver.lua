NMZombieMediaPayloadResolver = NMZombieMediaPayloadResolver or {}
require "loot/NMManagedSpawnCatalog"

local MEDIA_CATEGORY_BY_VARIANT = {
    walkman = "cassettes",
    cd_player = "cds",
    boombox = "cassettes"
}

local MEDIA_RATE_GETTERS = {
    cassettes = function()
        return NMRuntimeConfig and NMRuntimeConfig.getCassettesSpawnRate and NMRuntimeConfig.getCassettesSpawnRate() or 0
    end,
    cds = function()
        return NMRuntimeConfig and NMRuntimeConfig.getCDsSpawnRate and NMRuntimeConfig.getCDsSpawnRate() or 0
    end
}

local VANILLA_CD_PREFIX = "vanilla_cd:"
local EARBUD_FULL_TYPE = "Base.Earbuds"

local function hasText(value)
    return tostring(value or "") ~= ""
end

local function sanitizeMediaFields(payload)
    payload.insertedMediaFullType = hasText(payload.insertedMediaFullType) and tostring(payload.insertedMediaFullType) or nil
    payload.mediaEjectFullType = hasText(payload.mediaEjectFullType) and tostring(payload.mediaEjectFullType) or payload.insertedMediaFullType
    payload.caseFullType = hasText(payload.caseFullType) and tostring(payload.caseFullType) or nil
    payload.caseEmptyType = hasText(payload.caseEmptyType) and tostring(payload.caseEmptyType) or nil
    if payload.insertedMediaFullType == nil then
        payload.mediaRecordedMediaIndex = nil
    end
end

local function sanitizePayloadForSandbox(payload)
    if type(payload) ~= "table" then
        return payload
    end

    sanitizeMediaFields(payload)

    local ostEnabled = NMRuntimeConfig and NMRuntimeConfig.getZomboidOSTEnabled and NMRuntimeConfig.getZomboidOSTEnabled() == true or false
    local casesEnabled = not (NMRuntimeConfig and NMRuntimeConfig.getMediaSpawnsWithCasesEnabled)
        or NMRuntimeConfig.getMediaSpawnsWithCasesEnabled() == true
    local insertedMediaFullType = tostring(payload.insertedMediaFullType or "")
    local insertedIsBaseOst = insertedMediaFullType ~= ""
        and NMManagedSpawnCatalog
        and NMManagedSpawnCatalog.isBaseZomboidOSTMediaFullType
        and NMManagedSpawnCatalog.isBaseZomboidOSTMediaFullType(insertedMediaFullType) == true
        or false

    if not ostEnabled and insertedIsBaseOst then
        payload.insertedMediaFullType = nil
        payload.mediaEjectFullType = nil
        payload.mediaRecordedMediaIndex = nil
        payload.caseFullType = nil
        payload.caseEmptyType = nil
        if payload.deviceEnabled == true then
            payload.mediaMode = "device_only"
        else
            payload.mediaMode = "none"
        end
    end

    if not casesEnabled then
        payload.caseFullType = nil
        payload.caseEmptyType = nil
    end

    if payload.mediaMode == "device_with_media" then
        if not hasText(payload.insertedMediaFullType) then
            payload.mediaMode = payload.deviceEnabled == true and "device_only" or "none"
            payload.mediaEjectFullType = nil
            payload.mediaRecordedMediaIndex = nil
            payload.caseEmptyType = nil
        end
    elseif payload.mediaMode == "media_only" then
        if not hasText(payload.insertedMediaFullType) or not hasText(payload.caseFullType) then
            payload.mediaMode = payload.deviceEnabled == true and "device_only" or "none"
            payload.mediaEjectFullType = nil
            payload.mediaRecordedMediaIndex = nil
            payload.caseFullType = nil
        end
    elseif payload.mediaMode == "device_only" then
        payload.insertedMediaFullType = nil
        payload.mediaEjectFullType = nil
        payload.mediaRecordedMediaIndex = nil
        payload.caseFullType = nil
        payload.caseEmptyType = nil
    elseif payload.mediaMode ~= "none" then
        payload.mediaMode = payload.deviceEnabled == true and "device_only" or "none"
        if payload.mediaMode == "none" then
            payload.insertedMediaFullType = nil
            payload.mediaEjectFullType = nil
            payload.mediaRecordedMediaIndex = nil
        end
        payload.caseFullType = nil
        payload.caseEmptyType = nil
    end

    if payload.mediaMode == "none" then
        payload.mediaEnabled = false
        payload.insertedMediaFullType = nil
        payload.mediaEjectFullType = nil
        payload.mediaRecordedMediaIndex = nil
        payload.caseFullType = nil
        payload.caseEmptyType = nil
    else
        payload.mediaEnabled = payload.mediaEnabled == true or hasText(payload.insertedMediaFullType)
    end

    return payload
end

local function mixHash(text, salt)
    local source = tostring(text or "") .. "|" .. tostring(salt or "")
    local total = 0
    for i = 1, #source do
        total = (total * 131 + string.byte(source, i) + i) % 2147483647
    end
    return total
end

local function deterministicIndex(text, salt, count)
    local size = tonumber(count) or 0
    if size <= 1 then
        return 1
    end
    return (mixHash(text, salt) % size) + 1
end

local function appendUnits(out, unitMap, category)
    for _, unit in pairs(unitMap and unitMap[category] or {}) do
        out[#out + 1] = unit
    end
end

local function sortUnits(units)
    table.sort(units, function(a, b)
        return tostring(a.key or a.canonical or a.spawnFullType or "") < tostring(b.key or b.canonical or b.spawnFullType or "")
    end)
    return units
end

local function buildCombinedMediaPools(catalog)
    local out = {
        cassettes = {},
        cds = {}
    }
    local basePools = catalog and catalog.basePools or nil
    appendUnits(out.cassettes, basePools and basePools.media or nil, "cassettes")
    appendUnits(out.cds, basePools and basePools.media or nil, "cds")
    for _, childPools in pairs(catalog and catalog.childPools or {}) do
        appendUnits(out.cassettes, childPools and childPools.media or nil, "cassettes")
        appendUnits(out.cds, childPools and childPools.media or nil, "cds")
    end
    sortUnits(out.cassettes)
    sortUnits(out.cds)
    return out
end

local function resolveCatalog()
    local ostEnabled = NMRuntimeConfig and NMRuntimeConfig.getZomboidOSTEnabled and NMRuntimeConfig.getZomboidOSTEnabled() == true or false
    local casesEnabled = not (NMRuntimeConfig and NMRuntimeConfig.getMediaSpawnsWithCasesEnabled)
        or NMRuntimeConfig.getMediaSpawnsWithCasesEnabled() == true
    local token = tostring(NMRuntimeConfig and NMRuntimeConfig.getBuildContentToken and NMRuntimeConfig.getBuildContentToken() or "")
    local cache = NMZombieMediaPayloadResolver._catalogCache
    if cache and cache.ostEnabled == ostEnabled and cache.casesEnabled == casesEnabled and cache.token == token then
        return cache.catalog
    end
    local allItems = getAllItems and getAllItems() or nil
    local catalog = NMManagedSpawnCatalog and NMManagedSpawnCatalog.buildCatalog and NMManagedSpawnCatalog.buildCatalog(allItems, {}) or nil
    if catalog and NMManagedSpawnCatalog and NMManagedSpawnCatalog.filterBaseZomboidOSTMedia then
        NMManagedSpawnCatalog.filterBaseZomboidOSTMedia(catalog.basePools, ostEnabled)
    end
    local combinedMedia = buildCombinedMediaPools(catalog)
    NMZombieMediaPayloadResolver._catalogCache = {
        ostEnabled = ostEnabled,
        casesEnabled = casesEnabled,
        token = token,
        catalog = {
            managed = catalog,
            media = combinedMedia
        }
    }
    return NMZombieMediaPayloadResolver._catalogCache.catalog
end

local function resolveVariantId(selection)
    if type(selection) == "table" then
        return tostring(selection.variantId or "")
    end
    return tostring(selection or "")
end

local function resolveMediaCategory(variantId)
    return MEDIA_CATEGORY_BY_VARIANT[resolveVariantId(variantId)]
end

local function resolveMediaRate(category)
    local getter = MEDIA_RATE_GETTERS[tostring(category or "")]
    return getter and (tonumber(getter()) or 0) or 0
end

local function chooseMediaUnit(variantId, zombieId)
    local category = resolveMediaCategory(variantId)
    if not category then
        return nil
    end
    local catalog = resolveCatalog()
    local units = catalog and catalog.media and catalog.media[category] or nil
    if type(units) ~= "table" or #units < 1 then
        return nil
    end
    local index = deterministicIndex(zombieId, tostring(variantId) .. "_media", #units)
    return units[index]
end

local function resolveRecordedMediaIndex(mediaFullType)
    local key = tostring(mediaFullType or "")
    if string.sub(key, 1, #VANILLA_CD_PREFIX) ~= VANILLA_CD_PREFIX then
        return nil
    end
    local idx = tonumber(string.sub(key, #VANILLA_CD_PREFIX + 1))
    if idx == nil then
        return nil
    end
    return math.floor(idx)
end

local function resolveDefaultHeadphoneItemFullType(profile)
    if not (profile and profile.supportsHeadphones == true) then
        return nil
    end
    if profile.defaultHeadphonesPresent ~= true then
        return nil
    end
    if tostring(profile.defaultHeadphoneFullType or "") ~= "" then
        return tostring(profile.defaultHeadphoneFullType)
    end
    return EARBUD_FULL_TYPE
end

local function buildPayloadBase(variantId, realizedSpec)
    local profile = realizedSpec
        and NMDeviceProfiles
        and NMDeviceProfiles.getForFullType
        and NMDeviceProfiles.getForFullType(tostring(realizedSpec.fullType or ""))
        or nil
    local supportsBattery = profile and profile.supportsBattery == true
    return {
        variantId = tostring(variantId or ""),
        mediaCategory = tostring(resolveMediaCategory(variantId) or ""),
        deviceEnabled = realizedSpec ~= nil,
        mediaEnabled = false,
        mediaMode = "none",
        insertedMediaFullType = nil,
        mediaEjectFullType = nil,
        mediaRecordedMediaIndex = nil,
        caseFullType = nil,
        caseEmptyType = nil,
        headphoneItemFullType = resolveDefaultHeadphoneItemFullType(profile),
        batteryPresent = supportsBattery,
        batteryCharge = supportsBattery and 1.0 or 0.0
    }
end

function NMZombieMediaPayloadResolver.getMediaCategoryForVariant(variantId)
    return resolveMediaCategory(variantId)
end

function NMZombieMediaPayloadResolver.getMediaSpawnRateForVariant(variantId)
    return resolveMediaRate(resolveMediaCategory(variantId))
end

function NMZombieMediaPayloadResolver.resolveZombiePayload(selection, zombieId, realizedSpec)
    local variantId = resolveVariantId(selection)
    local payload = buildPayloadBase(variantId, realizedSpec)
    local mediaCategory = payload.mediaCategory
    if mediaCategory == "" then
        return sanitizePayloadForSandbox(payload)
    end

    local mediaRate = resolveMediaRate(mediaCategory)
    payload.mediaEnabled = mediaRate > 0
    if payload.deviceEnabled and payload.mediaEnabled then
        local mediaUnit = chooseMediaUnit(variantId, zombieId)
        if mediaUnit then
            payload.mediaMode = "device_with_media"
            payload.insertedMediaFullType = hasText(mediaUnit.insertedZombieMediaFullType) and tostring(mediaUnit.insertedZombieMediaFullType) or nil
            payload.mediaEjectFullType = payload.insertedMediaFullType
            payload.mediaRecordedMediaIndex = resolveRecordedMediaIndex(payload.insertedMediaFullType)
            payload.caseEmptyType = hasText(mediaUnit.companionZombieCaseFullType) and tostring(mediaUnit.companionZombieCaseFullType) or nil
            return sanitizePayloadForSandbox(payload)
        end
    end

    if payload.deviceEnabled then
        payload.mediaMode = "device_only"
        return sanitizePayloadForSandbox(payload)
    end

    if payload.mediaEnabled then
        local mediaUnit = chooseMediaUnit(variantId, zombieId)
        if mediaUnit then
            payload.mediaMode = "media_only"
            payload.caseFullType = hasText(mediaUnit.looseZombieRepresentativeFullType) and tostring(mediaUnit.looseZombieRepresentativeFullType) or nil
            payload.insertedMediaFullType = hasText(mediaUnit.insertedZombieMediaFullType) and tostring(mediaUnit.insertedZombieMediaFullType) or nil
            payload.mediaEjectFullType = payload.insertedMediaFullType
            payload.mediaRecordedMediaIndex = resolveRecordedMediaIndex(payload.insertedMediaFullType)
            return sanitizePayloadForSandbox(payload)
        end
    end

    return sanitizePayloadForSandbox(payload)
end

function NMZombieMediaPayloadResolver.resolveStoredPayload(data)
    if type(data) ~= "table" then
        return nil
    end
    local payload = {
        variantId = tostring(data.variantId or ""),
        mediaCategory = tostring(data.mediaCategory or ""),
        deviceEnabled = data.deviceEnabled == true,
        mediaEnabled = data.mediaEnabled == true,
        mediaMode = tostring(data.mediaMode or "none"),
        insertedMediaFullType = hasText(data.mediaFullType) and tostring(data.mediaFullType) or nil,
        mediaEjectFullType = hasText(data.mediaEjectFullType) and tostring(data.mediaEjectFullType) or nil,
        mediaRecordedMediaIndex = tonumber(data.mediaRecordedMediaIndex) or nil,
        caseFullType = hasText(data.caseFullType) and tostring(data.caseFullType) or nil,
        caseEmptyType = hasText(data.caseEmptyType) and tostring(data.caseEmptyType) or nil,
        headphoneItemFullType = hasText(data.headphoneItemFullType) and tostring(data.headphoneItemFullType) or nil,
        batteryPresent = data.batteryPresent == true,
        batteryCharge = tonumber(data.batteryCharge) or 0.0
    }
    return sanitizePayloadForSandbox(payload)
end

function NMZombieMediaPayloadResolver.sanitizePayloadForSandbox(payload)
    return sanitizePayloadForSandbox(payload)
end

return NMZombieMediaPayloadResolver
