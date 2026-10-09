require "loot/NMManagedSpawnCatalog"

NMMediaLootPool = NMMediaLootPool or {}

local pool = NMMediaLootPool

local MEDIA_CATEGORY_ORDER = NMManagedSpawnCatalog.getMediaCategoryOrder and NMManagedSpawnCatalog.getMediaCategoryOrder()
    or { "cassettes", "vinyl", "cds" }

local function newCategoryMaps()
    local out = {}
    for i = 1, #MEDIA_CATEGORY_ORDER do
        out[MEDIA_CATEGORY_ORDER[i]] = {}
    end
    return out
end

local function hasText(value)
    return tostring(value or "") ~= ""
end

local function cloneMediaUnit(unit, category)
    if type(unit) ~= "table" then
        return nil
    end
    local spawnFullType = tostring(unit.spawnFullType or "")
    if spawnFullType == "" then
        return nil
    end
    return {
        key = tostring(unit.key or unit.canonical or unit.spawnFullType or ""),
        canonicalKey = tostring(unit.canonicalKey or unit.canonical or unit.canonicalMediaFullType or ""),
        canonical = tostring(unit.canonical or unit.canonicalKey or unit.canonicalMediaFullType or ""),
        canonicalMediaFullType = tostring(unit.canonicalMediaFullType or unit.insertedMediaFullType or unit.spawnFullType or ""),
        insertedMediaFullType = tostring(unit.insertedMediaFullType or unit.canonicalMediaFullType or unit.spawnFullType or ""),
        spawnFullType = spawnFullType,
        loadedOnly = unit.loadedOnly == true,
        variantKind = tostring(unit.variantKind or (unit.loadedOnly == true and "loaded" or "loose")),
        carrier = tostring(unit.carrier or ""),
        owner = tostring(unit.owner or ""),
        modId = tostring(unit.modId or ""),
        variantWeight = tonumber(unit.variantWeight) or 1.0,
        category = tostring(category or unit.category or ""),
        emptyCompanionFullType = hasText(unit.emptyCompanionFullType) and tostring(unit.emptyCompanionFullType) or nil,
        hasCompanionCase = unit.hasCompanionCase == true,
        companionZombieCaseFullType = hasText(unit.companionZombieCaseFullType) and tostring(unit.companionZombieCaseFullType) or nil,
        isBaseZomboidOST = unit.isBaseZomboidOST == true
    }
end

local function addUnit(out, seenByCanonical, unit, category, policy)
    local cloned = cloneMediaUnit(unit, category)
    if not cloned then
        return false
    end
    if policy and policy.ostEnabled ~= true and cloned.isBaseZomboidOST == true then
        return false
    end

    local casesEnabled = not (policy and policy.casesEnabled ~= true)
    if casesEnabled ~= true and cloned.loadedOnly == true then
        return false
    end

    local canonical = tostring(cloned.canonicalMediaFullType or cloned.insertedMediaFullType or cloned.spawnFullType or "")
    local seenKey = canonical ~= "" and canonical or cloned.spawnFullType
    if casesEnabled ~= true and seenByCanonical[category][seenKey] == true then
        return false
    end
    if casesEnabled ~= true then
        seenByCanonical[category][seenKey] = true
    end

    out[category][#out[category] + 1] = cloned
    return true
end

local function addUnitsFromMediaMap(out, seenByCanonical, mediaMap, policy)
    for i = 1, #MEDIA_CATEGORY_ORDER do
        local category = MEDIA_CATEGORY_ORDER[i]
        for _, unit in pairs(mediaMap and mediaMap[category] or {}) do
            addUnit(out, seenByCanonical, unit, category, policy)
        end
    end
end

local function sortCategoryUnits(units)
    table.sort(units, function(a, b)
        local aKey = tostring(a and (a.key or a.canonical or a.spawnFullType) or "")
        local bKey = tostring(b and (b.key or b.canonical or b.spawnFullType) or "")
        return aKey < bKey
    end)
end

function pool.build(options)
    local opts = type(options) == "table" and options or {}
    local policy = opts.policy or {}
    local out = newCategoryMaps()
    local seenByCanonical = newCategoryMaps()

    addUnitsFromMediaMap(out, seenByCanonical, opts.baseMedia, policy)
    for _, childPools in pairs(opts.childPools or {}) do
        addUnitsFromMediaMap(out, seenByCanonical, childPools and childPools.media or nil, policy)
    end
    addUnitsFromMediaMap(out, seenByCanonical, opts.extraMedia, policy)

    local counts = {}
    for i = 1, #MEDIA_CATEGORY_ORDER do
        local category = MEDIA_CATEGORY_ORDER[i]
        sortCategoryUnits(out[category])
        counts[category] = #out[category]
    end

    return {
        media = out,
        counts = counts,
        policy = policy
    }
end

function pool.getCategoryOrder()
    return MEDIA_CATEGORY_ORDER
end

return NMMediaLootPool
