NMZombieSandboxRarity = NMZombieSandboxRarity or {}

local MIN_RATE = 0.0
local MAX_RATE = 4.0
local DEFAULT_RATE = 0.6
local LOW_ANCHOR_RATE = 0.1
local MID_ANCHOR_RATE = 3.0
local HIGH_ANCHOR_RATE = 3.9

local LOW_ANCHOR_PROBABILITY = 1.0 / 50000.0
local DEFAULT_PROBABILITY = 1.0 / 500.0
local MID_ANCHOR_PROBABILITY = 1.0 / 20.0
local HIGH_ANCHOR_PROBABILITY = 0.9
local MAX_PROBABILITY = 1.0

local WALKMAN_WEIGHT = 60.0
local CD_PLAYER_WEIGHT = 25.0
local BOOMBOX_WEIGHT = 15.0
local VARIANT_TOTAL_WEIGHT = WALKMAN_WEIGHT + CD_PLAYER_WEIGHT + BOOMBOX_WEIGHT
local LOW_POWER_EXPONENT = math.log(LOW_ANCHOR_PROBABILITY / DEFAULT_PROBABILITY) / math.log(LOW_ANCHOR_RATE / DEFAULT_RATE)

local function clamp(value, minValue, maxValue)
    local n = tonumber(value)
    if n == nil then
        return minValue
    end
    if n < minValue then
        return minValue
    end
    if n > maxValue then
        return maxValue
    end
    return n
end

local function lerp(a, b, t)
    return a + ((b - a) * t)
end

local function inverseLerp(a, b, value)
    if b == a then
        return 0.0
    end
    return clamp((value - a) / (b - a), 0.0, 1.0)
end

local function probabilityToOneIn(probability)
    if probability <= 0 then
        return math.huge
    end
    return 1.0 / probability
end

local function log10(value)
    return math.log(value) / math.log(10)
end

local function interpolateLogOneIn(rate, startRate, endRate, startProbability, endProbability)
    local t = inverseLerp(startRate, endRate, rate)
    local startOneIn = probabilityToOneIn(startProbability)
    local endOneIn = probabilityToOneIn(endProbability)
    local logValue = lerp(log10(startOneIn), log10(endOneIn), t)
    local oneIn = 10 ^ logValue
    return clamp(1.0 / oneIn, 0.0, 1.0)
end

local function mixHash(text, salt)
    local source = tostring(text or "") .. "|" .. tostring(salt or "")
    local total = 0
    for i = 1, #source do
        total = (total * 131 + string.byte(source, i) + i) % 2147483647
    end
    return total
end

local function deterministicRoll(text, salt)
    return mixHash(text, salt) / 2147483647.0
end

function NMZombieSandboxRarity.getTotalMusicZombieProbability(rate)
    local value = clamp(rate, MIN_RATE, MAX_RATE)
    if value <= MIN_RATE then
        return 0.0
    end
    if value >= MAX_RATE then
        return MAX_PROBABILITY
    end
    if value <= DEFAULT_RATE then
        return clamp(DEFAULT_PROBABILITY * ((value / DEFAULT_RATE) ^ LOW_POWER_EXPONENT), 0.0, 1.0)
    end
    if value <= MID_ANCHOR_RATE then
        return interpolateLogOneIn(value, DEFAULT_RATE, MID_ANCHOR_RATE, DEFAULT_PROBABILITY, MID_ANCHOR_PROBABILITY)
    end
    if value <= HIGH_ANCHOR_RATE then
        return interpolateLogOneIn(value, MID_ANCHOR_RATE, HIGH_ANCHOR_RATE, MID_ANCHOR_PROBABILITY, HIGH_ANCHOR_PROBABILITY)
    end
    return clamp(
        lerp(HIGH_ANCHOR_PROBABILITY, MAX_PROBABILITY, inverseLerp(HIGH_ANCHOR_RATE, MAX_RATE, value)),
        0.0,
        1.0
    )
end

function NMZombieSandboxRarity.getVariantWeights()
    return {
        walkman = WALKMAN_WEIGHT,
        cd_player = CD_PLAYER_WEIGHT,
        boombox = BOOMBOX_WEIGHT
    }
end

function NMZombieSandboxRarity.resolveExclusiveVariant(randomValue)
    local roll = clamp(randomValue, 0.0, 0.999999999)
    local walkmanShare = WALKMAN_WEIGHT / VARIANT_TOTAL_WEIGHT
    local cdPlayerShare = CD_PLAYER_WEIGHT / VARIANT_TOTAL_WEIGHT
    local walkmanCutoff = walkmanShare
    local cdPlayerCutoff = walkmanCutoff + cdPlayerShare
    if roll < walkmanCutoff then
        return "walkman"
    end
    if roll < cdPlayerCutoff then
        return "cd_player"
    end
    return "boombox"
end

function NMZombieSandboxRarity.resolveMusicZombieOutcome(zombieId, rate)
    local key = tostring(zombieId or "")
    local spawnProbability = NMZombieSandboxRarity.getTotalMusicZombieProbability(rate)
    local selectionRoll = deterministicRoll(key, "music_selection")
    local musicSelected = key ~= "" and selectionRoll < spawnProbability
    local variantId = "none"
    if musicSelected then
        local variantRoll = deterministicRoll(key, "music_variant")
        variantId = NMZombieSandboxRarity.resolveExclusiveVariant(variantRoll)
    end
    return {
        zombieId = key,
        spawnProbability = spawnProbability,
        selectionRoll = selectionRoll,
        musicSelected = musicSelected,
        selected = musicSelected,
        variantId = variantId
    }
end

return NMZombieSandboxRarity
