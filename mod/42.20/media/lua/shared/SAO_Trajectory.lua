-- SAO_Trajectory.lua - late-start years and the measured Knox curve ([C126]).
-- ---------------------------------------------------------------------------
-- A save that begins after the fall owes days. Those days are lived
-- through the years pass ([C45], [C65]): first-principles, one day at
-- a time. Fast extrapolation is opt-in (sandbox FastSimulation) and
-- interpolates the measured headless curve rather than inventing one.
--
-- The curve is the compressed-day years ([C45]): one bundle per
-- calendar day, noon frozen, cooldowns opened at once. [C128] lives
-- those days on the live 240-tick cadence. These anchors stay until
-- that cadence is remeasured. FastSimulation interpolates them and
-- remains opt-in.
--
--   day     1    7   30   90  180  365 1096
--   alive 198  177   45    7    2    1  0 / 5
--
-- Most of the county dies in the first month. A handful remain at a
-- year, sometimes none at three. An exponential fitted across the
-- whole span predicts 175 alive on day 30; the county had 45. The
-- 8% floor that would keep 16 people standing at 1096 did not happen.
--
-- Houses collapse with the people: 25 standing at week one, 12 at
-- day 30, one or none by day 90. They do not converge toward 85%.
--
-- Used by the years pass when FastSimulation is on, by the headless
-- sweep, and as the Speakeasy trajectory corpus.
-- ---------------------------------------------------------------------------

SAO = SAO or {}
SAO.Trajectory = SAO.Trajectory or {}
local Trajectory = SAO.Trajectory

-- Genesis the 11 shipped towns actually produced ([B38] 18 a region).
Trajectory.CORPUS_N0 = 198

-- Measured headless points, plain (not --engine) Kahlua, Knox cache
-- dated 2026-09-09. One seed per horizon except 1096 (two seeds:
-- 0 and 5 alive); 1096 uses the midpoint 2.5 rounded at read time.
-- houses / inHouse / largestHouse are standing-at-end, not founded-ever.
Trajectory.ANCHORS = {
    { d = 0,    alive = 198, houses = 0,  inHouse = 0,  largest = 0, meanNeuro = 0.000 },
    { d = 1,    alive = 198, houses = 8,  inHouse = 17, largest = 3, meanNeuro = 0.000 },
    { d = 7,    alive = 177, houses = 25, inHouse = 54, largest = 3, meanNeuro = 0.056 },
    { d = 30,   alive =  45, houses = 12, inHouse = 24, largest = 2, meanNeuro = 0.022 },
    { d = 90,   alive =   7, houses =  1, inHouse =  2, largest = 2, meanNeuro = 0.143 },
    { d = 180,  alive =   2, houses =  0, inHouse =  0, largest = 0, meanNeuro = 0.000 },
    { d = 365,  alive =   1, houses =  0, inHouse =  0, largest = 0, meanNeuro = 0.000 },
    { d = 1096, alive =   2, houses =  0, inHouse =  1, largest = 1, meanNeuro = 0.000 },
}

local function clamp01(v)
    local n = tonumber(v) or 0.0
    if n < 0.0 then return 0.0 end
    if n > 1.0 then return 1.0 end
    return n
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function atDay(days)
    local a = Trajectory.ANCHORS
    if days <= a[1].d then return a[1] end
    if days >= a[#a].d then return a[#a] end
    for i = 1, #a - 1 do
        local lo, hi = a[i], a[i + 1]
        if days >= lo.d and days <= hi.d then
            local t = (days - lo.d) / (hi.d - lo.d)
            return {
                d = days,
                alive = lerp(lo.alive, hi.alive, t),
                houses = lerp(lo.houses, hi.houses, t),
                inHouse = lerp(lo.inHouse, hi.inHouse, t),
                largest = lerp(lo.largest, hi.largest, t),
                meanNeuro = lerp(lo.meanNeuro, hi.meanNeuro, t),
            }
        end
    end
    return a[#a]
end

---Predict expected macro distribution at elapsed day `days`.
---@param days number
---@param initialPop number|nil
---@return table
function Trajectory.predict(days, initialPop)
    days = math.max(0, tonumber(days) or 0)
    initialPop = math.max(1, tonumber(initialPop) or Trajectory.CORPUS_N0)
    local scale = initialPop / Trajectory.CORPUS_N0
    local p = atDay(days)
    local living = math.max(0, math.floor(p.alive * scale + 0.5))
    if living > initialPop then living = initialPop end
    local inHouse = math.min(living, math.max(0, math.floor(p.inHouse * scale + 0.5)))
    local houses = math.max(0, math.floor(p.houses * scale + 0.5))
    if living < 2 then
        houses = 0
        inHouse = 0
    end
    return {
        days = days,
        initial = initialPop,
        alive = living,
        dead = math.max(0, initialPop - living),
        houses = houses,
        inHouse = inHouse,
        largestHouse = math.min(living, math.max(0, math.floor(p.largest + 0.5))),
        boarded = 0,
        meanNeuro = p.meanNeuro,
        fitted = true,
    }
end

---Fast extrapolation is opt-in. Off, the years live every owed day.
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

---Apply the measured curve in one pass. Only when shouldFastSimulate is true.
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
    assert(total <= 500, "extrapolate: id list exceeds census bound of 500 (" .. total .. ")")

    table.sort(ids, function(a, b)
        local ha = SAO.Hash and SAO.Hash.of and SAO.Hash.of(tostring(a), "trajectory") or 0
        local hb = SAO.Hash and SAO.Hash.of and SAO.Hash.of(tostring(b), "trajectory") or 0
        if ha ~= hb then return ha < hb end
        return tostring(a) < tostring(b)
    end)

    local prediction = Trajectory.predict(owed, total)
    local targetAlive = prediction.alive
    local targetDead = total - targetAlive
    local survivors = {}

    for i = 1, total do
        local id = ids[i]
        local rec = SAO.Identity.get(id)
        if rec then
            if i <= targetDead then
                rec.dead = true
                local dieDay = 1
                if targetDead > 0 then
                    dieDay = math.max(1, math.min(owed, math.floor((i / targetDead) * owed)))
                end
                rec.diedAtHours = dieDay * 24.0
                rec.deathCause = "starvation"
            else
                rec.dead = false
                rec.diedAtHours = nil
                rec.deathCause = nil
                survivors[#survivors + 1] = id
                rec.groundSeenOnDay = owed
                rec.neuroinflammation = clamp01(prediction.meanNeuro)
            end
        end
    end

    if SAO.Standing and #survivors >= 2 then
        local groupSize = math.max(2, prediction.largestHouse)
        local currentRoster = {}
        local groupIdx = 1
        local housesWanted = prediction.houses
        for idx = 1, #survivors do
            if groupIdx > housesWanted and housesWanted > 0 then
                break
            end
            local sid = survivors[idx]
            currentRoster[#currentRoster + 1] = sid
            if #currentRoster >= groupSize or idx == #survivors then
                if #currentRoster >= 2 and SAO.Standing.formCompany then
                    local gName = "Company-" .. tostring(groupIdx)
                    pcall(function() SAO.Standing.formCompany(currentRoster, gName) end)
                    groupIdx = groupIdx + 1
                end
                currentRoster = {}
            end
        end
    end

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
            if SAO.Telemetry then SAO.Telemetry.runId = nil end
        end)
    end

    s.yearsRun = owed
    return true
end
