-- SAO_Course - the course an infected body runs, and whether it wins.
-- ---------------------------------------------------------------------------
-- [C11] and F-047 established what the engine does: a bite infects with
-- CERTAINTY on this build, and the infected die at exactly
-- `infectionTime + pickMortalityDuration`. The record carries that hour
-- as `biteDeathAtHours`, and `dormantAttrition` reads it as a due date
-- rather than a risk - "past it, death is not a risk, it is due."
--
-- So today every bitten person in the county dies on schedule, and
-- nothing they did before the bite makes any difference to it. That is
-- the fact this module changes. A body fights, and whether it wins
-- follows from the condition it was in - which is a thing the county
-- already knows about every one of its people.
--
-- WHAT DRIVES IT. The inputs are the ones the record already produces
-- by living: how long since they reached water, how long since they
-- ate, whether a house is keeping them, whether a wound is already
-- septic, how old they are, what they carry. None of it is new
-- bookkeeping. `dormantAttrition` computes most of it already for a
-- different purpose.
--
-- WHAT IT IS MEASURED AGAINST. The course's length is the engine's own
-- mortality window - the sandbox's `ZombieLore.Mortality` table, the
-- same one `biteWindowHours` mirrors. Progress is therefore expressed
-- as a fraction of the course rather than in days, and the model reads
-- the same on a thirty-second window as on a three-day one. A player
-- who set a fast pathogen gets a fast one, and the fight scales to it
-- instead of arguing with it.
--
-- THE ONE TUNED NUMBER is `PERFECT_COURSE_GAIN`, and it says plainly
-- what it means: the total immune progress a body in perfect condition
-- makes across a whole course. At 1.0 a perfect body exactly ties; the
-- value here is what a perfect body's odds are, and nothing else in the
-- file is a difficulty dial in disguise. Knox is fictional and no
-- source establishes how a human fights it, so this is OURS and says
-- so - the surrounding shape is principled, this number is a choice.
--
-- OFFLINE BY CONSTRUCTION: loads in a bare VM with SAO_Hash; every
-- engine read sits behind pcall and every input is optional.

SAO = SAO or {}
SAO.Course = SAO.Course or {}
local Co = SAO.Course

-- What a body of MEDIAN constitution in good condition achieves over
-- one whole course. Winning takes 1.0.
--
-- This number is the odds, and the odds are the operator's. It sits
-- here below one on purpose: at the value set, a median body kept in
-- good condition still loses, and throwing off an infection takes a
-- constitution well above the middle, or a house keeping somebody, or
-- having survived it before - usually more than one of the three.
-- A county where a bite is survivable by anybody who has been drinking
-- is a county where Knox has stopped meaning anything, which is a
-- worse outcome than the defect this batch fixes.
--
-- [C79] Border 143 ran a county and found nobody had ever thrown an
-- infection off. Raising this looked like the fix and was not: the
-- defect was in `advance`, which integrated the course's REMAINING
-- half instead of its elapsed one, so every body forfeited the first
-- part of every course and could not win at any value. The number is
-- back where the reasoning put it, and the arithmetic it was chosen
-- against now actually happens.
Co.PERFECT_COURSE_GAIN = 0.55

-- And the spread, which is what stops this being a threshold.
--
-- Every term in `qualityOf` is circumstance, and circumstance is the
-- same for two people living the same way - so without this the model
-- answers identically for everybody in identical conditions, and a
-- bite is either survivable by all of them or by none. Constitution is
-- the per-body variation the county already draws everything else
-- from: hashed off the person's own id, stable for their whole life,
-- and never rolled at the moment it is read.
Co.CONSTITUTION_LOW = 0.55
Co.CONSTITUTION_HIGH = 1.60

function Co.constitutionOf(id)
    if id == nil then return 1.0 end
    local u = 0.5
    pcall(function() u = SAO.Hash.unit(tostring(id), "course-constitution") end)
    if type(u) ~= "number" then u = 0.5 end
    return Co.CONSTITUTION_LOW
        + u * (Co.CONSTITUTION_HIGH - Co.CONSTITUTION_LOW)
end

-- The response is weakest when the infection has barely started and
-- when it is nearly over, and strongest in between. Antibodies
-- (lonegamedev, MIT) uses `sin(level * pi)` for this and it is the
-- right shape: it creates a window in the middle of the course where
-- what somebody does still matters, instead of a race that is decided
-- at the first hour. Taken and credited in CREDITS.md.
--
-- Normalised by pi/2 because sin over [0,1] integrates to 2/pi, so a
-- perfect body accumulates exactly PERFECT_COURSE_GAIN over a full
-- course rather than 64 percent of it. The constant means what it says.
local CURVE_NORM = math.pi / 2.0

function Co.curveAt(pos)
    pos = tonumber(pos) or 0
    if pos < 0 then pos = 0 elseif pos > 1 then pos = 1 end
    return math.sin(pos * math.pi) * CURVE_NORM
end

-- Fractions of their own fuse, the way `dormantAttrition` already
-- weighs them ([B37]): a day without water costs seven times a day
-- without food because the fuses are three days and twenty-one.
local THIRST_LETHAL = 3.0
local HUNGER_LETHAL = 21.0

local function clamp01(v)
    v = tonumber(v) or 0
    if v < 0 then return 0 elseif v > 1 then return 1 end
    return v
end

-- How well this body is placed to fight, 0 to 1. Every term is a
-- fraction of something already established rather than a fresh
-- coefficient.
--
-- `inputs` is a plain table so the dormant half and a loaded body can
-- both fill it, from a record and from the engine respectively, and
-- the model cannot tell them apart ([B39], [B42]: one rule for both).
function Co.qualityOf(inputs)
    inputs = inputs or {}
    local dry = clamp01((tonumber(inputs.dryDays) or 0) / THIRST_LETHAL)
    local hungry = clamp01((tonumber(inputs.hungryDays) or 0) / HUNGER_LETHAL)

    -- Water first and hardest. A body without it is not fighting
    -- anything, and this is the same ordering the attrition pass uses.
    local q = (1.0 - dry) * (1.0 - 0.5 * hungry)

    -- A wound already going septic is a second fight in one body.
    if inputs.woundInfected then q = q * 0.6 end

    -- Being kept by somebody. The house that feeds and warms its
    -- people is the difference between lying down somewhere dry and
    -- lying down in the rain; the attrition pass already reads all
    -- three of these facts for its own risk.
    if inputs.inHouse then q = q * 1.15 end
    if inputs.warmed then q = q * 1.10 end
    if inputs.pactFed then q = q * 1.05 end

    -- The very old and the very young fight worse. The shape is the
    -- age curve the county already carries ([C30]); the floor is ours.
    local age = tonumber(inputs.age)
    if age then
        if age < 13 then q = q * (0.70 + 0.02 * math.max(0, age - 3))
        elseif age >= 60 then q = q * math.max(0.45, 1.0 - (age - 60) * 0.015) end
    end

    -- What they carry. A chronic illness is a body already occupied.
    local burden = tonumber(inputs.conditionBurden) or 0
    q = q * math.max(0.4, 1.0 - 0.15 * burden)

    -- Having beaten it before. Antibodies scales a term with infections
    -- survived and the idea is sound: a body that has fought this is
    -- better at fighting it. Bounded, because this must not become an
    -- immunity ladder.
    local survived = tonumber(inputs.infectionsSurvived) or 0
    if survived > 0 then
        q = q * (1.0 + math.min(0.30, 0.12 * survived))
    end

    -- The body they were born with. Drawn once from the id and never
    -- rolled, so two people living identically still do not die
    -- identically - which is the difference between a model and a
    -- threshold.
    if inputs.id ~= nil then
        q = q * Co.constitutionOf(inputs.id)
    end

    -- Floored and not capped. An earlier draft clamped this to [0, 1],
    -- which silently made every bonus above unreachable: a body
    -- wanting for nothing is already at 1, so being kept by a house,
    -- being warm, and having beaten the infection before all
    -- multiplied a number that was then thrown back down to 1. The
    -- terms were dead code that read as a model.
    --
    -- So this is a multiplier around 1 rather than a fraction of it,
    -- and `PERFECT_COURSE_GAIN` is what a body in good condition and
    -- NO better than that achieves. Care can carry somebody past it,
    -- which is the point of care.
    if q < 0 then return 0 end
    return q
end

-- One step of the course. `dPos` is the fraction of the whole course
-- that elapsed in this step, so the caller decides the cadence and the
-- model does not care - a dormant day and a loaded tick both work.
--
-- THE STEP IS THE EXACT INTEGRAL, NOT A SAMPLE OF THE CURVE. Sampling
-- the curve at the step's midpoint and multiplying by its width is the
-- obvious way to write this and it makes the cadence decide the
-- answer: one step across a whole course samples sin at its peak and
-- returns pi/2, where twenty-four steps of a twenty-fourth sum to 1.
-- A dormant body taking one step a day would then out-fight a loaded
-- body taking hundreds, which is [C75]'s defect - the two halves of
-- the county disagreeing because a pass means different things in
-- each - arriving in a different module.
--
-- The integral of sin(pi*x) is -cos(pi*x)/pi, so the area over
-- [a, b] normalised by pi/2 is exactly (cos(pi*a) - cos(pi*b))/2,
-- which is 1 over a whole course and additive over any partition of
-- it. Cadence cannot change the total ([B39], [B42]).
function Co.gainFor(inputs, posStart, dPos)
    dPos = tonumber(dPos) or 0
    if dPos <= 0 then return 0 end
    local a = tonumber(posStart) or 0
    if a < 0 then a = 0 elseif a > 1 then a = 1 end
    local b = a + dPos
    if b > 1 then b = 1 end
    if b <= a then return 0 end
    local area = (math.cos(math.pi * a) - math.cos(math.pi * b)) / 2.0
    return Co.qualityOf(inputs) * area * Co.PERFECT_COURSE_GAIN
end

-- Where a record sits in its own course, 0 at the bite and 1 at the
-- hour the engine would take them.
--
-- `infectionSpanHours` is stamped when the clock is, and a record from
-- before this module has none - so the span falls back to whatever
-- remained when it was first seen, which is the same thing the
-- "unpicked" branch in the population pass already does. An old save
-- gets a shorter course rather than an error.
function Co.positionOf(rec, nowHours)
    if not rec or not rec.biteDeathAtHours then return nil end
    local now = tonumber(nowHours)
    local due = tonumber(rec.biteDeathAtHours)
    if not now or not due then return nil end
    local span = tonumber(rec.infectionSpanHours)
    if not span or span <= 0 then
        span = math.max(0.0001, due - now)
        rec.infectionSpanHours = span
    end
    local remaining = due - now
    local pos = 1.0 - (remaining / span)
    if pos < 0 then return 0 elseif pos > 1 then return 1 end
    return pos
end

-- One step, against a fixed deadline. The engine's hour stands and the
-- body races it: enough progress before the clock runs out and it
-- lives, otherwise it dies exactly when [C11] says it dies.
--
-- Returns "won", "lost" or "running".
--
-- EXTENDING THE DEADLINE WAS TRIED AND DROPPED. Antibodies wins by
-- moving `infectionTime` against `infectionMortalityDuration`, because
-- its win condition is antibodies exceeding infection at some moment
-- and buying hours is how a body gets there. Ported literally onto
-- this record it breaks: `positionOf` measures remaining against a
-- fixed span, so pushing the hour out drives the position backwards
-- and a body that fought WELL is reported as permanently at the start
-- of its own course, sitting in the weakest part of the curve forever.
-- Extending the span alongside the clock fixes the arithmetic and
-- leaves a model where a strong body holds the infection at bay
-- indefinitely, which is a different mechanic than the one wanted.
-- A race against the engine's own hour is what this is.
function Co.advance(rec, nowHours, inputs, dPos)
    if not rec or not rec.knoxInfected then return "running" end
    local pos = Co.positionOf(rec, nowHours)
    if pos == nil then return "running" end

    -- The step covers the ground just WALKED, not the ground ahead.
    -- `pos` is where the body has already got to, so the segment is
    -- [pos - dPos, pos]. Passing `pos` as the start integrates the
    -- course's remaining half instead of its elapsed one, and with a
    -- daily cadence against a two-day window the first observation is
    -- already at the midpoint - so the body silently forfeited the
    -- first half of every course it ever ran and could not win at any
    -- constant. Border 143 found it by running a county and finding
    -- nobody had ever thrown one off.
    local from = pos - dPos
    if from < 0 then from = 0 end
    rec.immuneProgress = (tonumber(rec.immuneProgress) or 0)
        + Co.gainFor(inputs, from, pos - from)

    if rec.immuneProgress >= 1.0 then
        -- Beaten. The clock goes, the flags go, and the body carries
        -- the fact that it has done this - which is an input next time.
        rec.knoxInfected = nil
        rec.biteDeathAtHours = nil
        rec.infectionSpanHours = nil
        rec.immuneProgress = nil
        rec.infectionsSurvived = (tonumber(rec.infectionsSurvived) or 0) + 1
        return "won"
    end

    local now = tonumber(nowHours) or 0
    if now >= (tonumber(rec.biteDeathAtHours) or 0) then return "lost" end
    return "running"
end

return Co
