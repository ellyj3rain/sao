-- SAO_Rand - the county's own randomness, seeded and reproducible.
--
-- Forty-two places asked the engine for a random number through
-- `ZombRand`, which is the game's generator and carries no state SAO
-- can see, set or write down. So no county could ever be run twice:
-- a defect somebody reported could not be reproduced, and a sweep
-- that moved one sandbox dial could not tell whether the difference
-- it saw came from the dial or from the draw.
--
-- [C65] recorded that as a fact about the trajectory corpus rather
-- than a defect - samples, not replays. The operator ruled the other
-- way: SAO carries its own generator and every draw goes through it,
-- so a whole save is reproducible.
--
-- COUNTER-BASED, not a running state machine. A draw is
-- `SAO.Hash.of(n, seed)` for a counter n that only goes up. That
-- buys three things a stateful generator does not:
--
--   * the state is two small values - a seed string and a count - so
--     it persists into ModData as-is and cannot drift out of shape;
--   * the arithmetic is already verified. [B48] found the FNV step
--     overflowing Kahlua's mantissa and collapsing the county's whole
--     personality space to six values, and fixed it by splitting the
--     multiply. That work is in SAO_Hash and this reuses it rather
--     than writing a second answer to the same question;
--   * consecutive counters do not ramp. [B48]'s other half: ids one
--     apart produced an arithmetic progression, because a single FNV
--     pass carries a constant difference. `H.of` runs a second pass
--     over the DECIMAL DIGITS of the first result, which is exactly
--     what kills that, and a counter is the ids-one-apart case.
--
-- THE SEED IS DERIVED AND PRIVATE (operator, 2026-09-08). It comes
-- off the save's own identity, is written down once, and is never
-- shown or set. Two people cannot deliberately play the same county
-- and nobody has to think about it.

SAO = SAO or {}
SAO.Rand = SAO.Rand or {}
local R = SAO.Rand

local STORE = "SurvivorAwareness_Standing"

-- The counter goes FIRST and the answer comes from the MIDDLE of the
-- word. Both were measured, and the first draft of this module had
-- neither.
--
-- `SAO.Hash.of(seed, counter) % n` puts the counter at the end of the
-- hashed text and reads FNV's low digits. Over two thousand draws mod
-- one hundred that produced 1626 consecutive runs - four draws in
-- five were exactly the one before plus one:
--
--     14, 15, 16, 17, 18, 55, 56, 57, ...
--
-- which is [B48]'s ramp arriving by a different door, and [B38]'s
-- finding that FNV's low bits are a parity checksum of the input
-- rather than a random bit.
--
-- Putting the counter first lets one FNV pass multiply its difference
-- through the whole tail. Taking the answer from above the low
-- sixteen bits is what [B38] already does for its coin. Measured over
-- six thousand draws:
--
--     n     chi2      df    verdict
--     2     0.0       1     the case [B38] found catastrophic
--     6     1.9       5     critical value 11.07
--     100   101.6     99    critical value 123.2
--
-- and consecutive runs at 4 in 1999, against 1626 for the first
-- draft and about 20 expected by chance.
local HALF_WORD = 65536

-- Memoised: the draw happens inside loops over the whole county, and
-- opening the store per draw would put a table lookup on every one.
local memo = nil
local function store()
    if memo then return memo end
    local ok, s = pcall(function() return ModData.getOrCreate(STORE) end)
    if not ok or type(s) ~= "table" then return nil end
    memo = s
    return s
end

-- The save's own identity, as text.
--
-- `IsoWorld.getWorld()` is the save's folder name and is unique per
-- save; the start date distinguishes two saves made in the same
-- folder name across a delete. Both are javap-verified surfaces
-- (`zombie.iso.IsoWorld.getWorld`, `zombie.GameTime.getStartYear`).
--
-- Where neither can be read - a bare VM, a load before the world is
-- up - this returns nil rather than a constant, because a constant
-- would give every save on the machine the same county.
local function identity()
    local name = nil
    pcall(function() name = getWorld():getWorld() end)
    local y, m, d = nil, nil, nil
    pcall(function()
        local gt = GameTime.getInstance()
        y, m, d = gt:getStartYear(), gt:getStartMonth(), gt:getStartDay()
    end)
    if name == nil and y == nil then return nil end
    return tostring(name or "?") .. ":" .. tostring(y or "?")
        .. "-" .. tostring(m or "?") .. "-" .. tostring(d or "?")
end

-- The seed for this save. Written down on first use and read from
-- then on, so a save keeps the county it started with even if the
-- identity above ever reads differently.
function R.seed()
    local s = store()
    if s and s.randSeed then return s.randSeed end
    local seed = identity()
    if seed == nil then
        -- No save to be identified yet. Answer without recording, so
        -- the first real answer is the one that gets kept.
        return nil
    end
    if s then s.randSeed = seed end
    return seed
end

-- How many draws this save has made. In the save, so a reload
-- continues the sequence instead of repeating it.
local function nextCount(s)
    local n = (tonumber(s.randCount) or 0) + 1
    s.randCount = n
    return n
end

-- What `ZombRand` answers, at both of its arities.
--
-- `R.int(n)` is 0 .. n-1 and `R.int(a, b)` is a .. b-1, because
-- `zombie.Lua.LuaManager$GlobalObject` declares both `ZombRand(double)`
-- and `ZombRand(double, double)` (javap) and nine sites in this tree
-- use the second: three pairs of goal coordinates in SAO_Controller,
-- the dormant day's fallback drift, and the radio's broadcast id.
--
-- The first sweep of this batch replaced every call textually and gave
-- this function one parameter. Every two-argument site then passed its
-- LOW bound as `n`, which is negative at seven of them, and the guard
-- answered zero: every goal offset collapsed to the anchor tile, the
-- fallback drift stopped drifting, and every broadcast went out as
-- "SAOW-0". Border 22 caught it, indirectly, by asserting a spelling
-- of the drift line that no longer existed.
--
-- Falls through to the engine where there is no save to seed from, so
-- nothing that runs before a world exists runs differently - and it
-- falls through at the arity it was called with.
function R.int(a, b)
    local low, high
    if b == nil then
        low, high = 0, tonumber(a) or 0
    else
        low, high = tonumber(a) or 0, tonumber(b) or 0
    end
    local span = high - low
    if span <= 0 then return low end
    local s = store()
    local seed = R.seed()
    if not s or not seed then
        local v = low
        pcall(function()
            v = (b == nil) and ZombRand(high) or ZombRand(low, high)
        end)
        return v
    end
    return low + math.floor(SAO.Hash.of(nextCount(s), seed) / HALF_WORD) % span
end

-- 0.000 .. 0.999, the shape a chance wants.
function R.unit()
    return R.int(1000) / 1000
end

-- What the county would have to be told to run again. Read by the
-- trajectory record ([C65]) so a run can be replayed exactly.
function R.state()
    local s = store()
    return R.seed(), (s and tonumber(s.randCount)) or 0
end

SAO.Log = SAO.Log or {}
if SAO.Log.line then
    SAO.Log.line("RAND", "the county's own draw, seeded off the save")
end

return R
