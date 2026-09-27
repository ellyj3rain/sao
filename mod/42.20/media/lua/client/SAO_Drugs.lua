-- Owned alcohol and pharmacology cadence. Source provenance is recorded in CREDITS.
require "SAO_Pharmacology"

SAO = SAO or {}
SAO.Drugs = SAO.Drugs or {}
local Dg = SAO.Drugs

local function log(msg) SAO.Log.line("DRUG", msg) end

local function applyStat(stats, name, delta)
    local stat = CharacterStat and CharacterStat[name]
    if not stat then return false end
    if delta >= 0 then stats:add(stat, delta) else stats:remove(stat, -delta) end
    return true
end

local function statOf(stats, name)
    local ok, v = pcall(function()
        return stats:get(CharacterStat[name])
    end)
    if ok and type(v) == "number" then return v end
    return nil
end

-- ---------------------------------------------------------------------------
-- The ladder: The Alcoholic's late withdrawal, at their own figures.
-- ---------------------------------------------------------------------------

-- Sickness builds at their rate while the chance draw hits, capped by
-- the phase (their MaxWithdrawal column); past their poison line the
-- body takes their poison range onto the engine's own food sickness;
-- past their death line the drink itself can kill.
local WITHDRAWAL_RATE = 0.001
local MAX_WITHDRAWAL = { 0.3, 0.5, 0.7, 1.0 }
local POISON_LINE = 0.6
local POISON_CHANCE = 50
local POISON_HIT_FLOOR = 0.5           -- of their twenty-five
local POISON_HIT_CEIL = 25
local POISON_CAP = 95
local DEATH_LINE = 0.9
local DEATH_CHANCE = 100

-- The per-drink relief, their column: the shakes die, half the stress
-- and unhappiness and then a little more off, fatigue halved, pain
-- eased, the poison worked out at half the body's running total, and
-- a tolerant drink holds less.
local STRESS_PER_DRINK = 0.10
local UNHAPPY_PER_DRINK = 0.10
local PAIN_PER_DRINK = 0.10
local POISON_RELIEF = 0.5
local BASE_TOLERANCE = 0.65

-- Their daily tolerance build: eight drinks or more in a day moves a
-- hundredth toward their cap. The day is the county's own
-- ([C112]), read off countyHours like every day fact.
local TOLERANCE_DRINKS = 8
local TOLERANCE_BUILD = 0.01
local TOLERANCE_MAX = 0.1

-- Historical poison inflicted remains useful as a life-history fact, but the
-- brain-health producer needs the body's current toxic burden after native
-- clearance and treatment.  This observation is the only value exposed to
-- that producer.
function Dg.refreshToxicBurden(rec, body)
    if not rec or not body then return nil end
    local stats = nil
    pcall(function() stats = body:getStats() end)
    if not stats then return nil end
    local current = statOf(stats, "FOOD_SICKNESS")
    if type(current) ~= "number" then return nil end
    if current < 0 then current = 0 end
    if current > POISON_CAP then current = POISON_CAP end
    rec.currentToxicBurden = current
    return current
end

local function countyDay()
    local ok, hours = pcall(function() return SAO.History.countyHours() end)
    if not ok or type(hours) ~= "number" then return nil end
    return math.floor(hours / 24.0)
end

-- One ten-minute pass of the ladder for a drinker in withdrawal.
-- Called with the controller's own tick so a death is marked with
-- when it happened.
function Dg.ladder(rec, body, tick)
    if not rec or not body or rec.dead then return end
    local phase = nil
    pcall(function() phase = SAO.Habits.withdrawalPhase(rec.id) end)
    phase = tonumber(phase) or 0
    if phase <= 0 then
        -- Their sickness only exists in withdrawal; a drink ends it
        -- and so does the end of the shakes.
        if rec.drinkSickness and rec.drinkSickness > 0 then
            rec.drinkSickness = 0
        end
        return
    end
    local sickness = rec.drinkSickness or 0
    if SAO.Rand.int(5 - phase) == 0 then
        sickness = sickness + WITHDRAWAL_RATE
        local cap = MAX_WITHDRAWAL[phase]
        if cap and sickness > cap then sickness = cap end
    end
    rec.drinkSickness = sickness
    if sickness <= POISON_LINE then return end
    local stats = nil
    pcall(function() stats = body:getStats() end)
    if not stats then return end
    -- Their poison: the engine's own food sickness takes the hit and
    -- the body keeps a running total the relief reads.
    if SAO.Rand.int(POISON_CHANCE) == 0 then
        local hit = SAO.Rand.int(math.floor(POISON_HIT_CEIL * POISON_HIT_FLOOR),
                                 POISON_HIT_CEIL)
        rec.drinkPoisonTotal = (rec.drinkPoisonTotal or 0) + hit
        local now = statOf(stats, "FOOD_SICKNESS") or 0
        local raised = now + hit
        if raised > POISON_CAP then raised = POISON_CAP end
        if raised > now then applyStat(stats, "FOOD_SICKNESS", raised - now) end
        rec.currentToxicBurden = raised
        log(rec.id .. " is drinking themselves sick")
    end
    -- Their death: the cause is marked before the body goes, and the
    -- controller's funnel marks nothing over it ([B51]'s funnel still
    -- takes the body's own business - pendingCorpses, the active map).
    if sickness > DEATH_LINE and SAO.Rand.int(DEATH_CHANCE) == 0 then
        pcall(SAO.Identity.markDead, rec, tick, "the drink")
        pcall(function() body:die() end)
        log(rec.id .. " died of the drink")
    end
end

-- The relief: every drink the county's people finish reaches this
-- through the SAO_Needs wrap, at their per-drink figures. The day's
-- count feeds the tolerance build; the sickness dies here.
function Dg.onDrink(id, body)
    local rec = nil
    pcall(function() rec = SAO.Identity.get(id) end)
    if not rec or rec.dead then return end
    local today = countyDay and countyDay() or nil
    if today ~= nil and Dg.completeThrough then Dg.completeThrough(rec, today) end
    rec.drinksToday = (rec.drinksToday or 0) + 1
    rec.drinkSickness = 0
    local stats = nil
    pcall(function() stats = body:getStats() end)
    if not stats then return end
    local tolerance = math.min(rec.drinkTolerance or 0, TOLERANCE_MAX)
    -- Set a stat toward its half, then take their little more off.
    local function halve(name)
        local v = statOf(stats, name)
        if v and v > 0 then applyStat(stats, name, v / 2 - v) end
    end
    halve("STRESS")
    applyStat(stats, "STRESS", -STRESS_PER_DRINK)
    halve("UNHAPPINESS")
    applyStat(stats, "UNHAPPINESS", -UNHAPPY_PER_DRINK)
    halve("FATIGUE")
    applyStat(stats, "PAIN", -PAIN_PER_DRINK)
    -- Their poison total is worked out at half - a body cannot go
    -- below the floor the engine keeps.
    local poison = rec.drinkPoisonTotal or 0
    if poison > 0 then
        local v = statOf(stats, "FOOD_SICKNESS")
        if v and v > 0 then
            local drop = poison * POISON_RELIEF
            if drop > v then drop = v end
            applyStat(stats, "FOOD_SICKNESS", -drop)
        end
    end
    Dg.refreshToxicBurden(rec, body)
    -- Their tolerance: a drink holds less on a body that built one.
    local intox = statOf(stats, "INTOXICATION")
    if intox and intox > 0 then
        applyStat(stats, "INTOXICATION", intox * (BASE_TOLERANCE - tolerance) - intox)
    end
end

-- The day fact: their tolerance builds at eight drinks a day.
function Dg.daily(rec)
    if not rec or rec.dead then return end
    if (rec.drinksToday or 0) >= TOLERANCE_DRINKS then
        local was = rec.drinkTolerance or 0
        rec.drinkTolerance = math.min(was + TOLERANCE_BUILD, TOLERANCE_MAX)
        if rec.drinkTolerance ~= was then
            log(rec.id .. "'s body is holding its drink better")
        end
    end
    rec.drinksToday = 0
end

-- Close the currently counted drinking day exactly once.  `drugDay` is both
-- the day whose drinks are open and the durable cursor: after daily work it
-- advances to today, so reload cannot repeat tolerance gain.  Empty skipped
-- days have no aggregate to apply and therefore need no synthetic work.
-- A legacy record starts in the current day without inventing a boundary for
-- an unknown prior clock domain.
function Dg.completeThrough(rec, today)
    if not rec or rec.dead or type(today) ~= "number" then return 0 end
    today = math.floor(today)
    local open = tonumber(rec.drugDay)
    if open == nil or open > today then
        rec.drugDay = today
        return 0
    end
    if open == today then return 0 end
    Dg.daily(rec)
    rec.drugDay = today
    return today - open
end

-- ---------------------------------------------------------------------------
-- One physiology driver for the county's currently owned living bodies.
-- ---------------------------------------------------------------------------

local lastTenMinutes = nil
local lastOneMinute = nil

local function onTick()
    local okT, current = pcall(function()
        return getGameTime():getMinutesStamp()
    end)
    if not okT or type(current) ~= "number" then return end
    if lastTenMinutes == nil or current < lastTenMinutes then lastTenMinutes = current end
    if lastOneMinute == nil or current < lastOneMinute then lastOneMinute = current end
    local tenPasses = math.floor((current - lastTenMinutes) / 10)
    local onePasses = math.floor(current - lastOneMinute)
    if tenPasses <= 0 and onePasses <= 0 then return end
    if tenPasses > 0 then lastTenMinutes = lastTenMinutes + tenPasses * 10 end
    if onePasses > 0 then lastOneMinute = lastOneMinute + onePasses end
    local today = countyDay()
    local nowHours = nil
    pcall(function() nowHours = SAO.History and SAO.History.countyHours() or nil end)
    local tick = nil
    pcall(function() tick = SAO.Controller.tick() end)
    local seen={}
    local function visit(id,body)
        if seen[body] then return end
        local rec=SAO.Identity.get(id)
        if not SAO.Pharmacology.ownsBody(rec,body) then return end
        seen[body]=true
        local ran,failure=pcall(function()
            local rec = SAO.Identity.get(id)
            if rec and SAO.Pharmacology and nowHours then
                local current, reason = SAO.Pharmacology.advance(rec, body, nowHours)
                if not current and reason ~= "catching-up" then
                    log(tostring(id) .. " pharmacology unavailable: " .. tostring(reason))
                end
            end
            if tenPasses > 0 then
                local rec = nil
                pcall(function() rec = SAO.Identity.get(id) end)
                if rec then
                    for _ = 1, tenPasses do Dg.ladder(rec, body, tick) end
                    Dg.completeThrough(rec, today)
                    Dg.refreshToxicBurden(rec, body)
                    if SAO.Population and SAO.Population.refreshBodyFacts then
                        pcall(SAO.Population.refreshBodyFacts, rec, body, nowHours)
                    end
                    if SAO.Neuro and SAO.Neuro.observeBody then
                        pcall(SAO.Neuro.observeBody, rec, body, nowHours,
                            "loaded-body")
                    elseif SAO.Neuro and SAO.Neuro.advance then
                        pcall(function()
                            SAO.Neuro.advance(rec, tenPasses * 10.0 / 60.0,
                                nowHours or 0)
                        end)
                    end
                end
            end
        end)
        if not ran then log(tostring(id).." physiology receiver failed: "..tostring(failure)) end
    end
    for id,body in pairs(SAO.Body.active) do visit(id,body) end
    for id,body in pairs(SAO.Body.foreign) do visit(id,body) end
end

function Dg.resetRuntimeForWorld()
    lastTenMinutes=nil;lastOneMinute=nil
end
for _,name in ipairs({"OnGameStart","OnLoad","OnNewGame"}) do
    if Events and Events[name] then Events[name].Add(Dg.resetRuntimeForWorld) end
end

if Events and Events.OnTick then
    Events.OnTick.Add(onTick)
end

SAO.Log = SAO.Log or {}
if SAO.Log.line then
    SAO.Log.line("DRUG", "owned pharmacology and alcohol physiology ready")
end

return Dg
