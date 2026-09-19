-- SAO_Neuro - the neuroinflammation graph, brain health as one curve ([C125]).
-- ---------------------------------------------------------------------------
-- Operator ruling 2026-09-13: a genuine per-person neuroinflammation graph
-- in the shape of Antibodies (lonegamedev, MIT), representing and
-- visualizing drug damage and Knox impact on the brain, signifying
-- afflicted health and crossed destruction, tied into memory and the
-- existing health markers.
--
-- ONE CONTINUOUS VALUE PER PERSON:
--   `rec.neuroinflammation` is a single continuous scalar in [0.0, 1.0].
--   It is NOT an enum, bucket, or tier.
--   0.0 = completely uninflamed, pristine neural state.
--   1.0 = maximal acute neuroinflammation / crossed terminal threshold.
--
-- FUNCTIONAL PROJECTIONS (derived from the single value, never stored as independent buckets):
--   `clarityOf(rec)`          = math.max(0.0, 1.0 - load)
--   `affectiveVolatility(rec)`= load * 0.85
--   `motorSteadiness(rec)`    = math.max(0.0, 1.0 - load * 0.70)
--
-- WHAT FEEDS IT (insult accumulation, never an authored outcome):
--   1. Knox pathogen course:
--      Uses the Antibodies sine activation curve: math.sin(pos * math.pi)
--      where pos is the infection position from SAO.Course.positionOf.
--      Peak cytokine and neuro-inflammatory storm occurs in the middle
--      of the course (pos = 0.5), tapering at the onset and terminal hours.
--   2. Peripheral sepsis / wound infection:
--      `rec.woundInfected` contributes baseline inflammatory pressure.
--   3. Drug & Toxin damage ([C121]):
--      `rec.drinkPoisonTotal` from The Alcoholic ladder, and severe
--      withdrawal phases (phase >= 3) from SAO.Habits.
--   4. Afflicted & Crossed baselines ([MUTATION.md]):
--      Afflicted returnees retain lessened capacity with a floor of 0.30.
--      Crossed bodies sit at a 0.90 floor (humanity burned out by neuroinflammation).
--
-- RESOLUTION & CLEARANCE:
--   In the absence of active insults, resting, hydrated, nourished bodies
--   clear neuroinflammation exponentially toward their baseline floor.
--
-- OFFLINE BY CONSTRUCTION:
--   Loads in a bare Kahlua VM without engine globals; engine reads behind pcall.

SAO = SAO or {}
SAO.Neuro = SAO.Neuro or {}
local Neuro = SAO.Neuro

-- Baselines and floors
Neuro.AFFLICTED_FLOOR = 0.30
Neuro.CROSSED_FLOOR = 0.90

-- Kinetic rates per hour
Neuro.KNOX_PEAK_RATE = 0.08      -- rate at peak of sine curve (pos = 0.5)
Neuro.SEPSIS_RATE = 0.02         -- baseline rate while wound is septic
Neuro.DRUG_TOXIN_RATE = 0.05     -- rate at maximum drug/alcohol poison
Neuro.WITHDRAWAL_RATE = 0.02     -- rate during severe withdrawal (phase >= 3)
Neuro.BASE_CLEARANCE_RATE = 0.04 -- exponential clearance rate per hour when insults cease

---Check if neuroinflammation is enabled via sandbox options.
---@return boolean
function Neuro.isActive()
    local sv = SandboxVars and SandboxVars.SurvivorAwareness
    if sv and sv.Neuroinflammation ~= nil then
        return sv.Neuroinflammation == true
    end
    return true
end

---Get the raw continuous neuroinflammation load of a record in [0.0, 1.0].
---@param rec table survivor record
---@return number continuous load
function Neuro.loadOf(rec)
    if not rec or not Neuro.isActive() then return 0.0 end
    local v = tonumber(rec.neuroinflammation)
    if not v then
        if rec.terminalState == "crossed" then return Neuro.CROSSED_FLOOR end
        if rec.terminalState == "afflicted" or rec.afflictedReturn then
            return Neuro.AFFLICTED_FLOOR
        end
        return 0.0
    end
    return math.max(0.0, math.min(1.0, v))
end

---Get the raw load by survivor ID.
---@param id string|number survivor id
---@return number continuous load
function Neuro.loadOfId(id)
    if not id then return 0.0 end
    local rec = nil
    pcall(function() rec = SAO.Identity and SAO.Identity.get(id) end)
    return Neuro.loadOf(rec)
end

---Cognitive clarity projection in [0.0, 1.0], inversely proportional to load.
---1.0 = sharp, lucid recall; 0.0 = total delirium / acute confusion.
---@param rec table survivor record
---@return number clarity
function Neuro.clarityOf(rec)
    if not rec or not Neuro.isActive() then return 1.0 end
    local load = Neuro.loadOf(rec)
    return math.max(0.0, math.min(1.0, 1.0 - load))
end

---Cognitive clarity projection by survivor ID.
---@param id string|number survivor id
---@return number clarity
function Neuro.clarityOfId(id)
    if not id or not Neuro.isActive() then return 1.0 end
    local rec = nil
    pcall(function() rec = SAO.Identity and SAO.Identity.get(id) end)
    return Neuro.clarityOf(rec)
end

---Affective volatility projection in [0.0, 0.85].
---Amplifies panic, mood swings, and stress reactivity under high inflammatory load.
---@param rec table survivor record
---@return number volatility
function Neuro.affectiveVolatility(rec)
    if not rec or not Neuro.isActive() then return 0.0 end
    return Neuro.loadOf(rec) * 0.85
end

---Motor steadiness projection in [0.30, 1.0].
---Reflects physical tremors, motor incoordination, and slowing under high load.
---@param rec table survivor record
---@return number steadiness
function Neuro.motorSteadiness(rec)
    if not rec or not Neuro.isActive() then return 1.0 end
    return math.max(0.0, 1.0 - Neuro.loadOf(rec) * 0.70)
end

---Advance the neuroinflammation graph across elapsed time.
---@param rec table survivor record
---@param deltaHours number elapsed hours
---@param nowHours number current world/county hours
---@return number updated neuroinflammation load
function Neuro.advance(rec, deltaHours, nowHours)
    if not rec then return 0.0 end
    deltaHours = tonumber(deltaHours) or 0.0
    if deltaHours <= 0.0 then return Neuro.loadOf(rec) end
    if not Neuro.isActive() then
        rec.neuroinflammation = 0.0
        return 0.0
    end

    local current = tonumber(rec.neuroinflammation) or 0.0
    local floor = 0.0
    if rec.terminalState == "crossed" then
        floor = Neuro.CROSSED_FLOOR
    elseif rec.terminalState == "afflicted" or rec.afflictedReturn then
        floor = Neuro.AFFLICTED_FLOOR
    end
    if current < floor then current = floor end

    -- 1. Insult inputs
    local insultRate = 0.0

    -- Knox pathogen sine curve (Antibodies activation curve)
    if rec.knoxInfected and SAO.Course then
        local pos = 0.0
        pcall(function()
            pos = SAO.Course.positionOf(rec, nowHours) or 0.0
        end)
        pos = math.max(0.0, math.min(1.0, tonumber(pos) or 0.0))
        if pos > 0.0 and pos < 1.0 then
            local curve = math.sin(pos * math.pi)
            insultRate = insultRate + curve * Neuro.KNOX_PEAK_RATE
        end
    end

    -- Sepsis / Wound infection
    if rec.woundInfected then
        insultRate = insultRate + Neuro.SEPSIS_RATE
    end

    -- Drug & Alcohol poison damage (C121 ladder)
    local poison = tonumber(rec.drinkPoisonTotal) or 0.0
    if poison > 0.0 then
        local pNorm = math.min(1.0, poison / 100.0)
        insultRate = insultRate + pNorm * Neuro.DRUG_TOXIN_RATE
    end

    -- Severe withdrawal stress
    if SAO.Habits and rec.id then
        local phase = 0
        pcall(function()
            phase = SAO.Habits.withdrawalPhase(rec.id) or 0
        end)
        if phase >= 3 then
            insultRate = insultRate + Neuro.WITHDRAWAL_RATE
        end
    end

    -- 2. Integrate delta: insult accumulation vs clearance
    local newLoad = current
    if insultRate > 0.0 then
        newLoad = current + insultRate * deltaHours
    else
        local decay = math.exp(-Neuro.BASE_CLEARANCE_RATE * deltaHours)
        newLoad = floor + (current - floor) * decay
    end

    newLoad = math.max(floor, math.min(1.0, newLoad))
    rec.neuroinflammation = newLoad
    return newLoad
end

return Neuro
