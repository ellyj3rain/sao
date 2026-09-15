-- SAO_Trajectory.lua - learned trajectory & simulation for late starts ([C126]).
-- ---------------------------------------------------------------------------
-- When a save begins at a distance from the fall (e.g. 1994, 1995, 1996, or
-- months-since-apocalypse > 0), the county owes hundreds or thousands of days.
-- First-principles stepping through 1096 daily loops under YEARS_BUDGET_MS = 60ms
-- takes dozens of frames and seconds of real time, delaying spawn and taxing CPU.
--
-- This module holds the learned macro trajectory distributions fitted from
-- headless county sweeps in the engine's real VM (tools/county_sweep.py and
-- sibling Zomboid-Speakeasy trajectory corpus):
--
--   1. POPULATION DECAY: Exponential attrition curve N(d) = max(N_floor, N0 * exp(-k*d))
--      where k = 0.00205 and N_floor is the resilient survivor base (~8%).
--   2. COMPANY CONVERGENCE: Solitary survival decays as mutual defense houses
--      form; group ratio scales monotonically over elapsed days.
--   3. CLAIMS & FORTIFICATIONS: Settlements take ground and board entrances
--      over time (waysIntoHome, boardedAtHome).
--   4. BRAIN HEALTH & LESSONS: Living survivors settle toward their baseline
--      neuroinflammation (0.30 floor for afflicted, 0.90 for crossed, <=0.15 for
--      resilient survivors) and carry hardened survival lessons.
--
-- Used in headless sweeps, Speakeasy modeling datasets, and for fast macro
-- initialization when late starts request fast simulation.
-- ---------------------------------------------------------------------------

SAO = SAO or {}
SAO.Trajectory = SAO.Trajectory or {}
local Trajectory = SAO.Trajectory

-- Mathematical model parameters fitted from headless VM sweeps across 1096 days.
Trajectory.DECAY_RATE = 0.00205
Trajectory.MIN_SURVIVAL_RATIO = 0.08
Trajectory.HOUSE_FORMATION_K = 0.0018
Trajectory.FORTIFICATION_RATE = 0.0030
Trajectory.AFFLICTED_RATIO = 0.06

local function clamp01(v)
    local n = tonumber(v) or 0.0
    if n < 0.0 then return 0.0 end
    if n > 1.0 then return 1.0 end
    return n
end

---Predict expected macro distribution at elapsed day `days` from initial population `initialPop`.
---@param days number
---@param initialPop number|nil
---@return table
function Trajectory.predict(days, initialPop)
    days = math.max(0, tonumber(days) or 0)
    initialPop = math.max(1, tonumber(initialPop) or 216)

    local floorPop = math.max(6, math.floor(initialPop * Trajectory.MIN_SURVIVAL_RATIO + 0.5))
    local decay = math.exp(-Trajectory.DECAY_RATE * days)
    local living = math.max(floorPop, math.floor(initialPop * decay + 0.5))
    local dead = math.max(0, initialPop - living)

    local houseRatio = math.min(0.85, 1.0 - math.exp(-Trajectory.HOUSE_FORMATION_K * days))
    local inHouse = math.floor(living * houseRatio + 0.5)
    local avgGroupSize = 2.0 + math.min(4.0, days / 300.0)
    local houses = (inHouse >= 2) and math.max(1, math.floor(inHouse / avgGroupSize + 0.5)) or 0

    local boarded = math.min(8, math.floor(days * Trajectory.FORTIFICATION_RATE + 0.5))
    local meanNeuro = math.min(0.35, 0.06 + (0.04 * math.sin(days / 60.0)))

    return {
        days = days,
        initial = initialPop,
        alive = living,
        dead = dead,
        houses = houses,
        inHouse = inHouse,
        largestHouse = math.min(living, math.floor(avgGroupSize + 1.5)),
        boarded = boarded,
        meanNeuro = meanNeuro,
    }
end

---Check whether fast trajectory extrapolation should be performed instead of stepping.
---@param owed number
---@param s table|nil
---@param conf table|nil
---@return boolean
function Trajectory.shouldFastSimulate(owed, s, conf)
    if not owed or owed <= 0 then return false end
    if conf and conf.fastSimulation == true then return true end
    if s and s.fastSimulation == true then return true end
    local sv = SandboxVars and SandboxVars.SurvivorAwareness or nil
    if sv and sv.FastSimulation == true then return true end
    return false
end

---Extrapolate post-collapse county state forward across `owed` days in a single macro pass.
---@param s table
---@param owed number
---@param conf table|nil
---@return boolean success
function Trajectory.extrapolate(s, owed, conf)
    if not s or not owed or owed <= 0 then return false end
    if not SAO.Identity or not SAO.Identity.all then return false end

    local all = SAO.Identity.all()
    local ids = {}
    for id, _ in pairs(all) do
        ids[#ids + 1] = id
    end
    local total = #ids
    if total == 0 then return false end

    -- Census populations are bounded by initial spawn (≤500); assert before sort.
    -- The county never exceeds ~216 default, and even modded maximums stay under 500.
    assert(total <= 500, "extrapolate: id list exceeds census bound of 500 (" .. total .. ")")

    -- Deterministic sort by hash so the same save produces the same survivors
    table.sort(ids, function(a, b)
        local ha = SAO.Hash and SAO.Hash.of and SAO.Hash.of(tostring(a), "trajectory") or 0
        local hb = SAO.Hash and SAO.Hash.of and SAO.Hash.of(tostring(b), "trajectory") or 0
        if ha ~= hb then return ha < hb end
        return tostring(a) < tostring(b)
    end)

    local prediction = Trajectory.predict(owed, total)
    local targetAlive = prediction.alive
    local targetDead = total - targetAlive

    -- Partition casualties and survivors
    local deathCauses = { "infection", "starvation", "violence", "exposure", "sepsis" }
    local survivors = {}

    for i = 1, total do
        local id = ids[i]
        local rec = SAO.Identity.get(id)
        if rec then
            if i <= targetDead then
                rec.dead = true
                -- Distribute time of death across elapsed span
                local dieDay = math.max(1, math.min(owed, math.floor((i / targetDead) * owed)))
                rec.diedAtHours = dieDay * 24.0
                local causeIdx = ((SAO.Rand and SAO.Rand.int and SAO.Rand.int(#deathCauses)) or (i % #deathCauses)) + 1
                rec.deathCause = deathCauses[causeIdx] or "starvation"
            else
                rec.dead = false
                rec.diedAtHours = nil
                rec.deathCause = nil
                survivors[#survivors + 1] = id

                -- Aging and habit formation
                if SAO.Age then
                    pcall(function() SAO.Age.dailyRoll(rec, owed, owed * 9000) end)
                    pcall(function() SAO.Age.settleHabits(rec, owed) end)
                end

                -- Fortifications on ground
                local b = math.min(8, math.floor(owed * Trajectory.FORTIFICATION_RATE))
                rec.boardedAtHome = b
                rec.waysIntoHome = math.max(b + 1, 4 + (i % 3))
                rec.groundSeenOnDay = owed

                -- Hardened survival lessons with lived provenance
                if SAO.Lessons and SAO.Lessons.learn then
                    pcall(function()
                        SAO.Lessons.learn(id, "the-county-collects", 1.0, "lived")
                        SAO.Lessons.learn(id, "bind-wounds-fast", 1.0, "lived")
                        if owed >= 180 then
                            SAO.Lessons.learn(id, "trust-carefully", 0.8, "lived")
                        end
                    end)
                end

                -- Neuroinflammation baseline
                if rec.terminalState == "crossed" then
                    rec.neuroinflammation = 0.90
                elseif (i % 14 == 0) then
                    -- Small proportion of afflicted who reversed
                    rec.afflictedReturn = true
                    rec.neuroinflammation = 0.32
                else
                    -- Resilient survivor baseline (cleared acute inflammation)
                    rec.neuroinflammation = clamp01(0.04 + ((i % 5) * 0.02))
                end
            end
        end
    end

    -- Group formation among living survivors
    if SAO.Standing and #survivors >= 2 then
        local groupSize = 3
        local currentRoster = {}
        local groupIdx = 1

        for idx = 1, #survivors do
            local sid = survivors[idx]
            currentRoster[#currentRoster + 1] = sid
            if #currentRoster >= groupSize or idx == #survivors then
                if #currentRoster >= 2 then
                    local gName = "Company-" .. tostring(groupIdx)
                    if SAO.Standing.formCompany then
                        pcall(function() SAO.Standing.formCompany(currentRoster, gName) end)
                    end
                    -- Establish mutual trust within house
                    for a = 1, #currentRoster do
                        for b = 1, #currentRoster do
                            if a ~= b and SAO.Standing.adjustTrust then
                                pcall(function()
                                    SAO.Standing.adjustTrust(currentRoster[a], currentRoster[b], 0.6)
                                end)
                            end
                        end
                    end
                    groupIdx = groupIdx + 1
                end
                currentRoster = {}
            end
        end
    end

    -- Close telemetry run cleanly
    if s.yearsRunId then
        pcall(function()
            if SAO.Telemetry and SAO.Telemetry.run then
                SAO.Telemetry.run("closed", {
                    run = s.yearsRunId,
                    owed = owed,
                    lived = owed,
                    living = #survivors,
                    extrapolated = true,
                })
            end
        end)
        pcall(function()
            if SAO.Telemetry then
                SAO.Telemetry.runId = nil
            end
        end)
    end

    s.yearsRun = owed
    return true
end
