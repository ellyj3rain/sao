require "Definitions/AttachedWeaponDefinitions"
require "zombies/NMZombieDeviceVariantCatalog"

NMZombieAttachedDefinitions = NMZombieAttachedDefinitions or {}

local NATURAL_OUTFITS = {
    walkman = {
        "Backpacker",
        "Evacuee",
        "Grunge",
        "Punk",
        "Student",
        "Varsity",
        "Young"
    },
    cd_player = {
        "Backpacker",
        "Evacuee",
        "Grunge",
        "Punk",
        "Student",
        "Varsity",
        "Young"
    },
    boombox = {
        "Backpacker",
        "Evacuee",
        "Grunge",
        "Punk",
        "Student",
        "Varsity",
        "Young"
    }
}

local NATURAL_DEVICE_POOLS = {}
local NATURAL_LOCATION_BY_OUTCOME = {}
local DEBUG_OUTFIT_BY_KIND = {}
local DEBUG_DEVICE_BY_KIND = {}
local DEBUG_LOCATION_BY_KIND = {}

local KNOWN_VARIANTS = NMZombieDeviceVariantCatalog and NMZombieDeviceVariantCatalog.getVariantIds and NMZombieDeviceVariantCatalog.getVariantIds() or { "walkman" }
for i = 1, #KNOWN_VARIANTS do
    local variantId = KNOWN_VARIANTS[i]
    local spec = NMZombieDeviceVariantCatalog and NMZombieDeviceVariantCatalog.getSpec and NMZombieDeviceVariantCatalog.getSpec(variantId) or nil
    if spec then
        NATURAL_DEVICE_POOLS[variantId] = { tostring(spec.fullType or "") }
        NATURAL_LOCATION_BY_OUTCOME[variantId] = { tostring(spec.attachmentLocation or "") }
        DEBUG_OUTFIT_BY_KIND[variantId] = "Backpacker"
        DEBUG_DEVICE_BY_KIND[variantId] = tostring(spec.fullType or "")
        DEBUG_LOCATION_BY_KIND[variantId] = { tostring(spec.attachmentLocation or "") }
    end
end

local function hasText(value)
    return tostring(value or "") ~= ""
end

local function clamp(value, minValue, maxValue)
    local n = tonumber(value) or 0
    if n < minValue then
        return minValue
    end
    if n > maxValue then
        return maxValue
    end
    return n
end

local function makeDefinition(id, chance, outfits, locations, ensureItem, weapons)
    return {
        id = tostring(id or ""),
        chance = clamp(chance, 0, 100),
        outfit = outfits,
        weaponLocation = locations,
        bloodLocations = nil,
        addHoles = false,
        daySurvived = 0,
        ensureItem = hasText(ensureItem) and tostring(ensureItem) or nil,
        weapons = weapons
    }
end

local function registerDefinition(key, definition)
    if not (AttachedWeaponDefinitions and hasText(key) and type(definition) == "table") then
        return
    end
    AttachedWeaponDefinitions[key] = definition
end

local function registerNaturalDefinition(outcome)
    local key = "nmMusicNatural_" .. tostring(outcome or "")
    local spec = NMZombieDeviceVariantCatalog and NMZombieDeviceVariantCatalog.getSpec and NMZombieDeviceVariantCatalog.getSpec(outcome) or nil
    registerDefinition(
        key,
        makeDefinition(
            key,
            100,
            NATURAL_OUTFITS[outcome],
            NATURAL_LOCATION_BY_OUTCOME[outcome],
            spec and spec.ensureItem or nil,
            NATURAL_DEVICE_POOLS[outcome]
        )
    )
end

local function registerDebugDefinition(kind)
    local key = "nmMusicDebug_" .. tostring(kind or "")
    local spec = NMZombieDeviceVariantCatalog and NMZombieDeviceVariantCatalog.getSpec and NMZombieDeviceVariantCatalog.getSpec(kind) or nil
    registerDefinition(
        key,
        makeDefinition(
            key,
            100,
            { DEBUG_OUTFIT_BY_KIND[kind] },
            DEBUG_LOCATION_BY_KIND[kind],
            spec and spec.ensureItem or nil,
            { DEBUG_DEVICE_BY_KIND[kind] }
        )
    )
end

function NMZombieAttachedDefinitions.register()
    if NMZombieAttachedDefinitions._registered == true then
        return
    end
    for i = 1, #KNOWN_VARIANTS do
        registerNaturalDefinition(KNOWN_VARIANTS[i])
        registerDebugDefinition(KNOWN_VARIANTS[i])
    end
    NMZombieAttachedDefinitions._registered = true
end

NMZombieAttachedDefinitions.register()

return NMZombieAttachedDefinitions
