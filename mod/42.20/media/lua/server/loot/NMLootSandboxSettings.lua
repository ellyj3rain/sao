-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
NMLootSandboxSettings = NMLootSandboxSettings or {}

local settings = NMLootSandboxSettings
local resolvePolicyCategoryRate = nil

settings.BASE_MEDIA_DEFAULT = 0.6
settings.BASE_DEVICE_DEFAULT = 0.6
settings.BASELINE_FEEL_NO_BOOST_RATE = 0.1
settings.MEDIA_BASELINE_FEEL_MULTIPLIER = 1.0
settings.MEDIA_ROUTE_BASELINE_TARGET_RATE = 2.4
settings.DEVICE_BASELINE_FEEL_MULTIPLIER = 1.8
settings.DEVICE_INTENSITY_MULTIPLIER = 0.25
settings.VEHICLE_RESPONSE_BASE = 0.18
settings.VEHICLE_RESPONSE_EXPONENT = 0.72
settings.MEDIA_INDEPENDENT_LANE_RATE_POINTS = {
    { rate = 0.0, budget = 0.0 },
    { rate = 0.1, budget = 0.17 },
    { rate = 0.6, budget = 1.0 },
    { rate = 4.0, budget = 10.0 }
}
settings.MUSIC_STORE_TOPUP_REFERENCE_RATE = 0.6
settings.MUSIC_STORE_TOPUP_DECAY_EXPONENT = 1.35

settings.CATEGORY_ORDER = {
    "cassettes",
    "vinyl",
    "cds",
    "walkman",
    "boombox",
    "cdplayer",
    "recordplayer"
}

settings.MEDIA_CATEGORY_ORDER = {
    "cassettes",
    "vinyl",
    "cds"
}

settings.DEVICE_CATEGORY_ORDER = {
    "walkman",
    "boombox",
    "cdplayer",
    "recordplayer"
}

settings.VEHICLE_ROLE_ORDER = {
    "glovebox",
    "seatrear",
    "cargo"
}

settings.MUSIC_STORE_MEDIA_MIN_PRESENCE_UNITS = {
    cassettes = 0.0,
    vinyl = 3.0,
    cds = 1.0
}

settings.MUSIC_STORE_TARGET_ORDER = {
    "MusicStoreCases",
    "MusicStoreCDs",
    "MusicStoreShelves",
    "MusicStoreCounter",
    "MusicStoreSpeaker",
    "MusicStoreOthers"
}

settings.MUSIC_STORE_PROCEDURAL_WEIGHT_OVERRIDES = {
    cassettes = {
        MusicStoreCDs = 14.0,
        MusicStoreShelves = 10.0,
        MusicStoreCounter = 8.0,
        MusicStoreSpeaker = 7.0,
        MusicStoreOthers = 6.0
    },
    vinyl = {
        MusicStoreCases = 32.0,
        MusicStoreCDs = 24.0,
        MusicStoreShelves = 30.0,
        MusicStoreCounter = 18.0,
        MusicStoreSpeaker = 16.0
    },
    cds = {
        MusicStoreCDs = 15.0,
        MusicStoreShelves = 11.0,
        MusicStoreCounter = 9.0,
        MusicStoreSpeaker = 7.0,
        MusicStoreOthers = 6.0
    },
    walkman = {
        MusicStoreCDs = 7.0,
        MusicStoreShelves = 8.0,
        MusicStoreCounter = 6.0,
        MusicStoreOthers = 6.0
    },
    boombox = {
        MusicStoreCDs = 4.0,
        MusicStoreShelves = 5.0,
        MusicStoreCounter = 4.0,
        MusicStoreOthers = 4.0
    },
    cdplayer = {
        MusicStoreCDs = 9.0,
        MusicStoreShelves = 10.0,
        MusicStoreCounter = 7.0
    },
    recordplayer = {
        MusicStoreCDs = 8.0,
        MusicStoreShelves = 12.0,
        MusicStoreCounter = 8.0,
        MusicStoreSpeaker = 7.0,
        MusicStoreOthers = 5.0
    }
}

settings.MUSIC_STORE_CATEGORY_FLOOR_BUDGETS = {
    cassettes = 0.75,
    vinyl = 1.20,
    cds = 0.75,
    walkman = 0.45,
    boombox = 0.30,
    cdplayer = 0.55,
    recordplayer = 0.75
}

settings.MUSIC_STORE_MEDIA_TOPUP_BIAS = {
    cassettes = 0.24,
    vinyl = 0.58,
    cds = 0.18
}

settings.MUSIC_STORE_DEVICE_TOPUP_BIAS = {
    walkman = 0.18,
    boombox = 0.12,
    cdplayer = 0.10,
    recordplayer = 0.60
}

settings.MUSIC_STORE_TOPUP_TARGET_FLOORS = {
    cassettes = 8.0,
    vinyl = 26.0,
    cds = 8.0,
    walkman = 5.0,
    boombox = 2.5,
    cdplayer = 2.0,
    recordplayer = 10.0
}

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

local function pow(base, exponent)
    if math and math.pow then
        return math.pow(base, exponent)
    end
    return (tonumber(base) or 0) ^ (tonumber(exponent) or 0)
end

local function resolveBaselineFeelMultiplier(rate, baseRate, multiplier)
    local r = tonumber(rate) or 0
    local base = tonumber(baseRate) or 0
    local boost = tonumber(multiplier) or 1.0
    local floorRate = clamp(tonumber(settings.BASELINE_FEEL_NO_BOOST_RATE) or 0, 0.0, base)
    if r <= 0 or base <= 0 or boost <= 1.0 or r > base then
        return 1.0
    end
    if r <= floorRate or floorRate >= base then
        return 1.0
    end
    local t = clamp((r - floorRate) / (base - floorRate), 0.0, 1.0)
    return 1.0 + ((boost - 1.0) * t)
end

local function resolveEffectiveMediaRouteRate(rate)
    local r = clamp(rate, 0.0, 4.0)
    if r <= 0 then
        return 0
    end

    local baseRate = math.max(0.0001, tonumber(settings.BASE_MEDIA_DEFAULT) or 0.6)
    local floorRate = clamp(tonumber(settings.BASELINE_FEEL_NO_BOOST_RATE) or 0.1, 0.0, baseRate)
    local targetRate = clamp(tonumber(settings.MEDIA_ROUTE_BASELINE_TARGET_RATE) or baseRate, baseRate, 4.0)

    if r <= floorRate or targetRate <= baseRate then
        return r
    end

    if r <= baseRate then
        local t = clamp((r - floorRate) / math.max(0.0001, baseRate - floorRate), 0.0, 1.0)
        return floorRate + ((targetRate - floorRate) * t)
    end

    local t = clamp((r - baseRate) / math.max(0.0001, 4.0 - baseRate), 0.0, 1.0)
    return targetRate + ((4.0 - targetRate) * t)
end

local function resolveSandboxPage()
    return type(SandboxVars) == "table" and type(SandboxVars.NewMusic) == "table" and SandboxVars.NewMusic or nil
end

function settings.clamp(value, minValue, maxValue)
    return clamp(value, minValue, maxValue)
end

function settings.pow(base, exponent)
    return pow(base, exponent)
end

function settings.getRawSandboxLootSettings()
    local page = resolveSandboxPage()
    return {
        cassettes = page and page.CassettesSpawnRate or nil,
        vinyl = page and page.VinylRecordsSpawnRate or nil,
        cds = page and page.CDsSpawnRate or nil,
        walkman = page and page.WalkmanSpawnRate or nil,
        boombox = page and page.BoomboxSpawnRate or nil,
        cdplayer = page and page.CDPlayerSpawnRate or nil,
        recordplayer = page and page.RecordPlayerSpawnRate or nil,
        _pagePresent = page ~= nil
    }
end

function settings.setPolicyRateResolver(resolver)
    if type(resolver) == "function" then
        resolvePolicyCategoryRate = resolver
        return
    end
    resolvePolicyCategoryRate = nil
end

function settings.resolveLootBuildZomboidOSTSetting()
    local page = resolveSandboxPage()
    local rawValue = page and page.ZomboidOST or nil
    local resolvedValue = false
    local state = "missing"

    if rawValue == true or rawValue == false then
        resolvedValue = rawValue == true
        state = resolvedValue and "enabled" or "disabled"
    else
        local asNumber = tonumber(rawValue)
        if asNumber ~= nil then
            resolvedValue = asNumber ~= 0
            state = resolvedValue and "enabled" or "disabled"
        else
            local text = tostring(rawValue or ""):lower()
            if text == "true" or text == "yes" or text == "on" then
                resolvedValue = true
                state = "enabled"
            elseif text == "false" or text == "no" or text == "off" then
                resolvedValue = false
                state = "disabled"
            end
        end
    end

    return {
        pagePresent = page ~= nil,
        keyPresent = rawValue ~= nil,
        rawValue = rawValue,
        enabled = resolvedValue,
        state = state
    }
end

function settings.resolveCategoryRate(category, lootPolicy)
    if type(resolvePolicyCategoryRate) == "function" then
        local overridden = resolvePolicyCategoryRate(lootPolicy, category)
        if overridden ~= nil then
            return overridden
        end
    end
    if type(lootPolicy) == "table" and type(lootPolicy.rates) == "table" then
        local key = tostring(category or "")
        if lootPolicy.rates[key] ~= nil then
            return tonumber(lootPolicy.rates[key]) or 0
        end
    end
    if category == "cassettes" then
        return NMRuntimeConfig.getCassettesSpawnRate() or settings.BASE_MEDIA_DEFAULT
    end
    if category == "vinyl" then
        return NMRuntimeConfig.getVinylRecordsSpawnRate() or 0.3
    end
    if category == "cds" then
        return NMRuntimeConfig.getCDsSpawnRate() or settings.BASE_MEDIA_DEFAULT
    end
    if category == "walkman" then
        return NMRuntimeConfig.getWalkmanSpawnRate() or settings.BASE_DEVICE_DEFAULT
    end
    if category == "boombox" then
        return NMRuntimeConfig.getBoomboxSpawnRate() or settings.BASE_DEVICE_DEFAULT
    end
    if category == "cdplayer" then
        return NMRuntimeConfig.getCDPlayerSpawnRate() or settings.BASE_DEVICE_DEFAULT
    end
    if category == "recordplayer" then
        return NMRuntimeConfig.getRecordPlayerSpawnRate() or settings.BASE_DEVICE_DEFAULT
    end
    return settings.BASE_MEDIA_DEFAULT
end

function settings.resolveCategoryMultiplier(category)
    local rate = clamp(settings.resolveCategoryRate(category), 0.0, 4.0)
    local baseRate = settings.BASE_MEDIA_DEFAULT
    local baselineFeel = settings.MEDIA_BASELINE_FEEL_MULTIPLIER
    if category == "walkman" or category == "boombox" or category == "cdplayer" or category == "recordplayer" then
        baseRate = settings.BASE_DEVICE_DEFAULT
        baselineFeel = settings.DEVICE_BASELINE_FEEL_MULTIPLIER
    else
        rate = resolveEffectiveMediaRouteRate(rate)
    end
    if tonumber(baseRate) == nil or baseRate <= 0 then
        baseRate = settings.BASE_MEDIA_DEFAULT
    end
    return (rate / baseRate) * resolveBaselineFeelMultiplier(rate, baseRate, baselineFeel)
end

function settings.isMediaCategory(category)
    local key = tostring(category or "")
    return key == "cassettes" or key == "vinyl" or key == "cds"
end

function settings.resolveIndependentMediaLaneBudget(rate)
    local r = clamp(rate, 0.0, 4.0)
    local points = settings.MEDIA_INDEPENDENT_LANE_RATE_POINTS
    if r <= tonumber(points[1].rate) then
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

function settings.computeTotalMediaBudget(mediaPool, orderedUnitsForCategory, scalarResolver)
    local total = 0
    for i = 1, #settings.MEDIA_CATEGORY_ORDER do
        local category = settings.MEDIA_CATEGORY_ORDER[i]
        if #orderedUnitsForCategory(mediaPool, category) > 0 then
            total = total + math.max(0, tonumber(scalarResolver(category)) or 0)
        end
    end
    return total
end

function settings.normalizePlayableRate(rate)
    local r = clamp(rate, 0.0, 4.0)
    if r <= 0 then
        return 0
    end
    if r <= settings.BASE_MEDIA_DEFAULT then
        return clamp(
            (r / settings.BASE_MEDIA_DEFAULT)
                * settings.VEHICLE_RESPONSE_BASE
                * resolveBaselineFeelMultiplier(r, settings.BASE_MEDIA_DEFAULT, settings.MEDIA_BASELINE_FEEL_MULTIPLIER),
            0.0,
            1.0
        )
    end
    local t = (r - settings.BASE_MEDIA_DEFAULT) / (4.0 - settings.BASE_MEDIA_DEFAULT)
    return clamp(
        settings.VEHICLE_RESPONSE_BASE + ((1.0 - settings.VEHICLE_RESPONSE_BASE) * pow(t, settings.VEHICLE_RESPONSE_EXPONENT)),
        0.0,
        1.0
    )
end

return settings
