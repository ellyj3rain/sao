-- SAO_Drugs - where the county meets the drug mods ([C121], the
-- totality arc's drugs batch; [A14] S6).
-- ---------------------------------------------------------------------------
-- C33 gave the county its own habit schedules: The Alcoholic's drinker
-- phases and N and C's Narcotics' per-family clean days, drawn at the
-- 1993 record's prevalence, with the supply cut the day the world
-- began. C121 source-reads both mods (CREDITS.md) and this file is
-- what came back:
--
-- THE CARRY. Where N and C's Narcotics is loaded, the county's own
-- bodies run their machinery - their own globals, on their own clock
-- shape, one pass per ten in-game minutes and one per minute, the
-- exact cadence their OnTick driver keeps for the player. Their
-- driver only ever finds the four player slots ([B46] law), so the
-- county's shells never appear in it, and no body is driven twice.
-- Their functions take the character as their argument, so they run
-- on a shell the same way they run on a player: their counters rise
-- in the shell's modData, their dependency traits are gained and
-- lost ON the shell, their highs and withdrawals apply to the shell's
-- own stats. Where their globals are absent the calls are nothing -
-- a nil global is checked, not called, so a county without the mod
-- runs exactly as C33 built it.
--
-- THE YIELD. Their withdrawal fires only on their own trait, so the
-- county's schedule yields family by family the moment the trait is
-- observed on the body - SAO_Habits reads the stamp this module keeps
-- on the record, and the two withdrawals never stack ([C121] there).
-- A use stamped without the trait does NOT yield: a person their
-- machinery has not taken over still has only the county's schedule,
-- which is what their tier packets not firing means.
--
-- METHADONE. Their methadone holds the opioid clock still, and
-- SAO_Habits provides the freeze and resume for exactly that; the
-- level is read here, because the engine read lives in the client
-- and the record is the county's own surface.
--
-- THE LADDER. The Alcoholic's late withdrawal is carried at its own
-- read figures: a sickness that builds through the phases, poisons
-- past its cap, and can kill - the drink being the only thing that
-- stops it, at the per-drink relief of their own numbers. Their death
-- is the county's death: the identity is marked with the cause FIRST
-- (markDead is idempotent, so the controller funnel's later marking
-- no-ops and the cause stands), and the body dies through their own
-- call. What is NOT carried is named in CREDITS.md - their poison
-- scaling by player trait, their alcoholicStress channel, their
-- headaches as BodyPart pain (C33's shakes are ours in size).
--
-- Every draw goes through the county's own generator ([C66] law) -
-- the same one-in-N shapes their randInt calls have.
--
-- OFFLINE BY CONSTRUCTION: every engine read sits behind pcall and
-- the event registration is guarded, so the file loads in a bare VM
-- and does nothing there.

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
-- The carry: N and C's own globals, on the county's bodies.
-- ---------------------------------------------------------------------------

-- Their registries.lua registers the traits their machinery gains and
-- loses, and the functions their driver calls per character. Their
-- names are written directly, the way this tree names every engine
-- global: the engine's interpreter is Kahlua, which registers rawget
-- and getfenv in its BaseLib and no _G (read in the jar, and no
-- vanilla script uses one), so a lookup by string would index a nil
-- on this engine and die in the pcall. A named global that is not
-- there reads nil, and the check is on the call - so a county
-- without their mod runs these lists and does nothing.
local function callNnC(fn, body)
    if type(fn) ~= "function" then return end
    pcall(fn, body)
end

local NNC_TEN = {
    function(body) callNnC(BenzoAddict, body) end,
    function(body) callNnC(CokeHead, body) end,
    function(body) callNnC(MethHead, body) end,
    function(body) callNnC(MDMAAddict, body) end,
    function(body) callNnC(OpioidAddict, body) end,
    function(body) callNnC(PotHead, body) end,
    function(body) callNnC(SteroidAddict, body) end,
}
local NNC_MINUTE = {
    function(body) callNnC(BenzoEffect, body) end,
    function(body) callNnC(CokeEffect, body) end,
    function(body) callNnC(MethEffect, body) end,
    function(body) callNnC(MDMAEffect, body) end,
    function(body) callNnC(OpioidEffect, body) end,
    function(body) callNnC(WeeeeedEffect, body) end,
    function(body) callNnC(SteroidEffect, body) end,
    function(body) callNnC(NnCPainRemoval, body) end,
}

-- The county families their traits carry, keyed by the record's own
-- family names (SAO_Habits' ORDER). Steroids and psychedelics are
-- usable and never sought - no verified 1993 dependency figure, and a
-- LOW-confidence claim never teaches.
local NNC_TRAIT = {
    sedatives  = "BenzoAddict",
    cocaine    = "CokeHead",
    stimulants = "MethHead",
    opioids    = "OpioidAddict",
    cannabis   = "PotHead",
}

-- The trait observation: their machinery withdraws only on their own
-- trait, so the trait is what the yield reads. Stamped on the record
-- ([C121] in SAO_Habits), never read here by the drift - this file is
-- the engine side of the seam and the record is the county's surface.
local function observeTraits(id, body)
    local rec = nil
    pcall(function() rec = SAO.Identity.get(id) end)
    if not rec or rec.dead then return end
    if not NnCReg then return end
    for key, regName in pairs(NNC_TRAIT) do
        local reg = NnCReg[regName]
        local holds = false
        if reg then
            pcall(function() holds = body:hasTrait(reg) == true end)
        end
        rec.nncWithdrawal = rec.nncWithdrawal or {}
        if holds and not rec.nncWithdrawal[key] then
            rec.nncWithdrawal[key] = true
            log(id .. "'s " .. key .. " withdrawal now carries on their own trait")
        elseif not holds and rec.nncWithdrawal[key] then
            rec.nncWithdrawal[key] = nil
            log(id .. "'s " .. key .. " withdrawal back on the county's clock")
        end
    end
    -- Their methadone freezes the opioid clock for exactly this
    -- purpose; SAO_Habits provides the pair and this is the reader.
    local frozen = nil
    pcall(function()
        local level = body:getModData().NnCMethadoneEffect
        frozen = type(level) == "number" and level > 0 or false
    end)
    if frozen == true then
        SAO.Habits.freezeUse(id, "opioids")
    elseif frozen == false then
        SAO.Habits.resumeUse(id, "opioids")
    end
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

-- ---------------------------------------------------------------------------
-- The driver: their clock shape, the county's bodies.
-- ---------------------------------------------------------------------------

local lastTenMinutes = nil
local lastOneMinute = nil
local lastDay = nil

local function countyDay()
    local ok, hours = pcall(function() return SAO.History.countyHours() end)
    if not ok or type(hours) ~= "number" then return nil end
    return math.floor(hours / 24.0)
end

local function onTick()
    local okT, current = pcall(function()
        return getGameTime():getMinutesStamp()
    end)
    if not okT or type(current) ~= "number" then return end
    if lastTenMinutes == nil then lastTenMinutes = current end
    if lastOneMinute == nil then lastOneMinute = current end
    local tenDue = (current - lastTenMinutes) >= 10
    local oneDue = (current - lastOneMinute) >= 1
    if not (tenDue or oneDue) then return end
    if tenDue then lastTenMinutes = current end
    if oneDue then lastOneMinute = current end
    local today = countyDay()
    local newDay = today ~= nil and lastDay ~= today
    if newDay then lastDay = today end
    local tick = nil
    pcall(function() tick = SAO.Controller.tick() end)
    for id, body in pairs(SAO.Body.active) do
        pcall(function()
            if SAO.Body.isTransitioning(SAO.Identity.get(id)) then return end
            if tenDue then
                -- Their ten-minute pass: the seven dependency steps,
                -- once - their pass scaling exists to fit their
                -- magnitudes to a day length, and the county's clock
                -- is its own ([C112]).
                for _, step in ipairs(NNC_TEN) do step(body) end
                observeTraits(id, body)
                local rec = nil
                pcall(function() rec = SAO.Identity.get(id) end)
                if rec then
                    Dg.ladder(rec, body, tick)
                    if newDay then Dg.daily(rec) end
                    if SAO.Neuro and SAO.Neuro.advance then
                        local h = 0
                        pcall(function() h = SAO.History and SAO.History.countyHours() or 0 end)
                        pcall(function()
                            SAO.Neuro.advance(rec, 10.0 / 60.0, h)
                        end)
                    end
                end
            end
            if oneDue then
                for _, step in ipairs(NNC_MINUTE) do step(body) end
            end
        end)
    end
end

if Events and Events.OnTick then
    Events.OnTick.Add(onTick)
end

SAO.Log = SAO.Log or {}
if SAO.Log.line then
    SAO.Log.line("DRUG", "the drug mods' own machinery on the county's bodies,"
        .. " the trait the yield reads, methadone's freeze, and the drink's"
        .. " ladder - sickness, poison, death, and what a drink relieves")
end

return Dg
