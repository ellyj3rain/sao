-- SAO_Hash.lua - one hash, computed exactly ([B48]).
--
-- Four modules carried their own copy of this line:
--
--     value = (value * 16777619 + string.byte(text, i)) % 4294967296
--
-- It is FNV, it is correct arithmetic, and **this engine cannot do
-- it**. Kahlua's numbers are doubles. `value` runs to 2^32 - 1, so
-- `value * 16777619` reaches 7.2e16 - eight times past the 2^53 the
-- mantissa can hold exactly - and every character rounds the bottom
-- bits away.
--
-- What that costs, measured over fifty-nine real ids:
--
--     hash(id, "aggression") % 1000
--       exact  : 59 distinct values
--       doubles:  6 distinct values, two of them covering forty ids
--
-- The county's whole personality space - nerve, discipline,
-- aggression, initiative, self-preservation, compassion, appetite,
-- talkativeness, and through Census and Appearance the occupations and
-- faces too - collapsed to a handful of profiles. Everybody was
-- roughly the same person.
--
-- It surfaced as [B48]: forty-nine survivors in a row learning
-- `doors-decide-lives`. With aggression pinned at 0.83 or 0.64 for
-- almost everyone, that grammar entry fits almost everyone, and the
-- entry above it (`nerve < 0.45`) fits almost nobody - so the first
-- fitting entry was the same for the whole county. Four hypotheses in
-- [B48] were tested and disproved because all four were simulated in
-- Python, in exact integers, which is the one thing the engine is not
-- doing.
--
-- THE FIX
--
-- Split the multiply so no intermediate leaves exact range. With
-- v = hi * 65536 + lo:
--
--     v * M = ((hi * M) % 65536) * 65536 + lo * M     (mod 2^32)
--
-- `(hi * M) % 65536 * 65536` stays under 2^32, and `lo * M` under
-- 1.1e12. Both are exact in a double. Verified against exact integer
-- FNV over sixteen hundred id/salt pairs: zero mismatches.
--
-- This is the same value the arithmetic always MEANT, so it is not a
-- new hash - it is the one that was written, finally computed. Every
-- existing survivor's traits move, because until now they were nearly
-- all the same and now they are not.

SAO = SAO or {}
SAO.Hash = SAO.Hash or {}
local H = SAO.Hash

local PRIME = 16777619
local WRAP = 4294967296
local HALF = 65536

-- One FNV step, with the multiply split so no intermediate leaves the
-- 2^53 a double holds exactly.
local function step(value, byte)
    local hi = math.floor(value / HALF)
    local lo = value % HALF
    return (((hi * PRIME) % HALF) * HALF + lo * PRIME + byte) % WRAP
end

-- The 32-bit value for an id and a salt. Callers reduce it themselves -
-- a trait wants 0..1, a pool index wants a modulus.
--
-- [B48] TWO passes, and the second is not decoration.
--
-- Our ids are `sao-1`, `sao-2`, `sao-3`. They differ in the MIDDLE of
-- the hashed text, so after one FNV pass two consecutive ids differ by
-- exactly the same amount every time - the tail of the string
-- multiplies that difference by a constant. The result is an
-- arithmetic progression, and the engine says so plainly:
--
--     nerve, sao-1..8 : 0.172 0.296 0.420 0.544 0.668 0.792 0.216 0.340
--
-- A step of 0.124, over and over. The MARGINAL spread is right - every
-- value distinct, the right fraction below any threshold - and the
-- SEQUENCE is a ramp. Since households are contiguous blocks of ids,
-- a family came out sorted by nerve rather than made of individuals,
-- and any trait threshold cut the county into runs instead of a
-- scatter.
--
-- The second pass runs the same steps over the DECIMAL DIGITS of the
-- first result. Two ids one apart produce first-pass values a fixed
-- distance apart, but their decimal spellings differ in several
-- digits at once, so the second pass has no constant difference left
-- to carry. Multiplying or adding could not have fixed this: both are
-- linear, and a constant difference survives them.
function H.of(id, salt)
    local text = tostring(id) .. ":" .. tostring(salt)
    local value = 2166136261
    for index = 1, #text do
        value = step(value, string.byte(text, index))
    end
    local digits = tostring(value)
    value = 2166136261
    for index = 1, #digits do
        value = step(value, string.byte(digits, index))
    end
    return value
end

-- 0.000 .. 0.999, the form every trait is built from.
function H.unit(id, salt)
    return (H.of(id, salt) % 1000) / 1000
end

SAO.Log = SAO.Log or {}
if SAO.Log.line then
    SAO.Log.line("HASH", "one hash, split so the mantissa holds it")
end
