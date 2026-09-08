-- SAO_Habits - habits are facts about a person ([C33], DR-032; the
-- society arc's S6).
-- ---------------------------------------------------------------------------
-- The operator ruled that the dependency model the catalogue settled
-- on comes into SAO's habits (CREDITS.md): The Alcoholic (axxessdenied,
-- MIT) for the drinker - hours since the last drink, four withdrawal
-- phases, the habit lost after three weeks dry and gained by drinking
-- often; N and C's Narcotics (page figures) for the users the county
-- fell with - a dependency gained by frequent use, lost after eighteen
-- to twenty clean days, with withdrawal at days one, five and ten.
-- Smoking ([A14]) stays as it was: a third of the county, and the end
-- did not help anyone quit.
--
-- A habit is drawn from the person's own hash at the record's
-- prevalence like a condition ([C32]) and then LIVES on the record:
-- the last drink, the days clean, the habit quit or acquired. Nobody
-- in the county has a supply of anything but drink, so a user's
-- withdrawal runs from the world's first day and the dependency is
-- gone by the twentieth - which is exactly the county the living
-- start ([C28], DR-031) walks into.
--
-- Read by the age drift (what the body carries every ten minutes),
-- the controller (a drink when the shakes come, and where to find
-- one), the knowledge surface and the panel (plain words).
--
-- OFFLINE BY CONSTRUCTION: loads in a bare VM with SAO_Hash and
-- SAO_History; every engine read sits behind pcall.

SAO = SAO or {}
SAO.Habits = SAO.Habits or {}
local Hb = SAO.Habits

local function hashOf(id, salt)
    return SAO.Hash.of(id, salt)
end

local function ageOf(id)
    local age = nil
    pcall(function() age = SAO.History.ageOf(id) end)
    return age or 34
end

-- [C51] A habit LIVES on a record - the last drink, the days clean,
-- the habit quit or acquired - and the player has no SAO record.
-- Without somewhere to write, the player's dry clock would run from
-- world zero and never reset, a drink would do nothing, and the habit
-- could never lapse: maximum withdrawal from the first minute,
-- forever, with no counterplay. So a key with no record may have a
-- table bound to stand in for one. SAO_Traits binds the player's own
-- modData, which the save persists, and every write path below works
-- unchanged.
Hb.bound = Hb.bound or {}

function Hb.bindRecord(id, tbl)
    if not id then return end
    Hb.bound[tostring(id)] = tbl
end

local function recordOf(id)
    local rec = nil
    pcall(function() rec = SAO.Identity.get(id) end)
    if rec then return rec end
    return Hb.bound[tostring(id)]
end

local function worldHours()
    local hours = 0
    pcall(function() hours = GameTime.getInstance():getWorldAgeHours() end)
    return hours
end

-- ---------------------------------------------------------------------------
-- Prevalence, per ten thousand, with the source beside each row.
-- ---------------------------------------------------------------------------
Hb.PREVALENCE = {
    -- Alcohol dependence, twelve-month, adults 18 and over: Grant BF et
    -- al., "Prevalence of DSM-IV alcohol abuse and dependence: United
    -- States, 1992" (the National Longitudinal Alcohol Epidemiologic
    -- Survey), Alcohol Health & Research World 1994;18(3):243-8 - 4.38
    -- percent (text). Abuse without dependence (3.03) is not a habit
    -- that withdraws, so it is not drawn. A national figure; Kentucky
    -- drank leaner that year (binge drinking 9.2 percent of adults
    -- against a 14.2 median, BRFSS 1993, MMWR 1996;45(SS-6)), which
    -- is noted and not applied - the record gives no state figure
    -- for dependence.
    drinker  = { per10k = 438, minAge = 18 },
    -- The users, per ten thousand by age, ages 12 and over: the 1993
    -- National Household Survey on Drug Abuse as tabled in SAMHSA's
    -- Preliminary Estimates from the 1994 NHSDA, Advance Report 10
    -- (1995), Tables 4-11, the 1993 columns (text). Past-month use
    -- stands in for the dependent: the record's dependence figure
    -- (1.8 percent, twelve-month, any drug, ages 15-54, the National
    -- Comorbidity Survey, Warner et al. 1995, abstract) is not split
    -- by substance, and N and C's own dependency is gained by use
    -- every few days, which a past-month user approximates.
    -- Marijuana, past month: 12-17 4.9, 18-25 11.1, 26-34 6.7, 35 and
    -- over 1.9 percent.
    cannabis = { bands = { { from = 12, to = 17, per10k = 490 },
                           { from = 18, to = 25, per10k = 1110 },
                           { from = 26, to = 34, per10k = 670 },
                           { from = 35, to = 200, per10k = 190 } } },
    -- Cocaine, any form, past month, the same report and the same
    -- 1993 columns: 12-17 0.4, 18-25 1.5, 26-34 1.0, 35 and over 0.4
    -- percent.
    cocaine  = { bands = { { from = 12, to = 17, per10k = 40 },
                           { from = 18, to = 25, per10k = 150 },
                           { from = 26, to = 34, per10k = 100 },
                           { from = 35, to = 200, per10k = 40 } } },
    -- Heroin, past YEAR, the same report (no past-month figure; it
    -- calls its own heroin estimates very conservative): 0.1 percent,
    -- ages 12+.
    opioids  = { per10k = 10, minAge = 12 },
    -- Stimulants, nonmedical, past YEAR, the same report: 1.1
    -- percent, ages 12+.
    stimulants = { per10k = 110, minAge = 12 },
    -- Sedatives 0.8 and tranquilizers about 1.2 percent, nonmedical,
    -- past YEAR, ages 12+, the same report, summed as the downers.
    sedatives  = { per10k = 200, minAge = 12 },
}

Hb.ORDER = { "drinker", "cannabis", "cocaine", "opioids", "stimulants", "sedatives" }

-- The Alcoholic's defaults (its sandbox table's first column): the
-- withdrawal phases begin at 12, 24, 48 and 72 hours since the last
-- drink; the habit is lost after 504 hours (three weeks) dry; drinking
-- often gains it (four points a drink, one off an hour, gained at
-- 200). Per hour of withdrawal the mod adds 0.10, 0.15, 0.25 and 0.30
-- stress and a chance of fatigue; per drink it takes 0.10 stress.
Hb.PHASES = { 12, 24, 48, 72 }
Hb.HOURS_TO_LOSE = 504
Hb.GAIN_PER_DRINK = 4
Hb.GAIN_AT = 200
local WITHDRAWAL_STRESS_PER_HOUR = { 0.10, 0.15, 0.25, 0.30 }
local WITHDRAWAL_FATIGUE_PER_HOUR = { 0.05, 0.05, 0.05, 0.10 }
local WITHDRAWAL_FATIGUE_CHANCE = { 14, 25, 33, 50 }   -- the mod's 1 in 7, 4, 3, 2
Hb.STRESS_PER_DRINK = 0.10

-- N and C's schedule for a dependency without a supply: withdrawal
-- medium from day one (day three for sedatives), bad from day five
-- (six), mild from day ten, and the dependency lost after eighteen to
-- twenty clean days (a fact about the person). The page gives the
-- tiers and not their sizes, so the sizes are ours and say so:
-- stress and fatigue per ten-minute pass.
local USER_SCHEDULE = {
    cannabis   = nil,   -- the page: no withdrawals
    cocaine    = { medium = 1, bad = 5, mild = 10 },
    opioids    = { medium = 1, bad = 5, mild = 10 },
    stimulants = { medium = 1, bad = 5, mild = 10 },
    sedatives  = { medium = 3, bad = 6, mild = 10 },
}
local TIER_LOAD = { mild = 0.005, medium = 0.010, bad = 0.020 }
Hb.CLEAN_DAYS_TO_LOSE = { 18, 20 }

local function per10kFor(key, age)
    local row = Hb.PREVALENCE[key]
    if not row then return 0 end
    if row.bands then
        for _, band in ipairs(row.bands) do
            if age >= band.from and age <= band.to then return band.per10k end
        end
        return 0
    end
    if row.minAge and age < row.minAge then return 0 end
    if row.maxAge and age > row.maxAge then return 0 end
    return row.per10k or 0
end

-- [C51] The county's people have their habits drawn from their own
-- hash at the record's prevalence. The PLAYER's are not drawn: they
-- are the ones that person chose at creation, and they arrive as
-- engine traits (SAO_Traits), exactly as [C39] did the conditions.
-- Anyone whose habits are asserted answers from the assertion instead
-- of the draw, so the drift, the words and the panel read the player
-- the way they read anyone else.
--
-- The record still overrides an assertion, because quitting and
-- acquiring are things that happen to a person after creation and the
-- player is not exempt from them.
Hb.asserted = Hb.asserted or {}

function Hb.assert(id, set)
    if not id then return end
    Hb.asserted[tostring(id)] = set
end

-- The death funnel in SAO_Identity clears these the way it clears the
-- conditions', so a table keyed by a survivor id cannot hold entries
-- nothing will read again ([B51]'s law).
function Hb.forget(id)
    if not id then return end
    Hb.asserted[tostring(id)] = nil
    -- And the stand-in record bound for a key that has none. The
    -- player's is rebound at every creation; a survivor never has one
    -- because they have a real record, so this is a death's business
    -- either way.
    Hb.bound[tostring(id)] = nil
end

-- Drawn from the hash, or asserted for the player, then overridden by
-- what the record says has happened since: quit, or acquired.
function Hb.has(id, key)
    local rec = recordOf(id)
    if rec and rec.habitsQuit and rec.habitsQuit[key] then return false end
    if rec and rec.habitsGained and rec.habitsGained[key] then return true end
    local said = Hb.asserted[tostring(id)]
    if said ~= nil then return said[key] == true end
    local share = per10kFor(key, ageOf(id))
    if share <= 0 then return false end
    return (hashOf(id, "habit:" .. key) % 10000) < share
end

function Hb.of(id)
    local out = {}
    for _, key in ipairs(Hb.ORDER) do
        if Hb.has(id, key) then out[#out + 1] = key end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- The drinker.
-- ---------------------------------------------------------------------------

-- Hours since the last drink. Nobody has drunk before the record says
-- they did, so a drinker the world starts with has been dry since the
-- world began - the fall cut the supply the day it came.
function Hb.hoursDry(id, now)
    now = now or worldHours()
    local rec = recordOf(id)
    local last = rec and rec.lastDrinkHours or 0
    local dry = now - last
    if dry < 0 then dry = 0 end
    return dry
end

-- 0 while it is fine; 1 to 4 through the phases.
function Hb.withdrawalPhase(id, now)
    if not Hb.has(id, "drinker") then return 0 end
    local dry = Hb.hoursDry(id, now)
    local phase = 0
    for i, at in ipairs(Hb.PHASES) do
        if dry > at then phase = i end
    end
    return phase
end

-- A drink taken: the record remembers, the shakes stop, and somebody
-- who was not a drinker moves toward becoming one (the mod's four
-- points a drink against one off an hour).
function Hb.drank(id, now)
    now = now or worldHours()
    local rec = recordOf(id)
    if not rec then return false end
    rec.lastDrinkHours = now
    rec.drinks = (rec.drinks or 0) + 1
    if not Hb.has(id, "drinker") then
        local since = rec.gainClockHours or now
        local decay = math.floor(math.max(now - since, 0))
        rec.drinkGain = math.max((rec.drinkGain or 0) - decay, 0) + Hb.GAIN_PER_DRINK
        rec.gainClockHours = now
        if rec.drinkGain >= Hb.GAIN_AT then
            rec.habitsGained = rec.habitsGained or {}
            rec.habitsGained.drinker = true
            rec.habitsQuit = rec.habitsQuit or {}
            rec.habitsQuit.drinker = nil
        end
    end
    return true
end

-- Three weeks dry and the habit is gone (the mod's dynamic trait);
-- a fact about the person from then on.
function Hb.settleDrinker(id, now)
    if not Hb.has(id, "drinker") then return false end
    if Hb.hoursDry(id, now) <= Hb.HOURS_TO_LOSE then return false end
    local rec = recordOf(id)
    if not rec then return false end
    rec.habitsQuit = rec.habitsQuit or {}
    rec.habitsQuit.drinker = true
    rec.habitsGained = rec.habitsGained or {}
    rec.habitsGained.drinker = nil
    rec.drinkGain = 0
    return true
end

-- ---------------------------------------------------------------------------
-- The users the county fell with.
-- ---------------------------------------------------------------------------

-- Clean days: since the world began. Nobody in the county has a
-- supply of any of these, so nothing records a use and the count
-- reads no field for one - a field nobody writes is a lie waiting.
function Hb.cleanDays(id, now)
    now = now or worldHours()
    local days = now / 24
    if days < 0 then days = 0 end
    return days
end

function Hb.daysToLose(id)
    local lo, hi = Hb.CLEAN_DAYS_TO_LOSE[1], Hb.CLEAN_DAYS_TO_LOSE[2]
    return lo + (hashOf(id, "clean-days") % (hi - lo + 1))
end

-- "medium", "bad", "mild" or nil for a user of this key today.
function Hb.userTier(id, key, now)
    if not Hb.has(id, key) then return nil end
    local schedule = USER_SCHEDULE[key]
    if not schedule then return nil end
    local days = Hb.cleanDays(id, now)
    if days < schedule.medium then return nil end
    if days < schedule.bad then return "medium" end
    if days < schedule.mild then return "bad" end
    return "mild"
end

-- Past the clean days, the dependency is gone - for good.
function Hb.settleUsers(id, now)
    local rec = recordOf(id)
    if not rec then return 0 end
    local settled = 0
    local days = Hb.cleanDays(id, now)
    for _, key in ipairs(Hb.ORDER) do
        if key ~= "drinker" and Hb.has(id, key) and days > Hb.daysToLose(id) then
            rec.habitsQuit = rec.habitsQuit or {}
            rec.habitsQuit[key] = true
            settled = settled + 1
        end
    end
    return settled
end

-- ---------------------------------------------------------------------------
-- What the habits do, in the age drift's own terms (a reserve down
-- or a load up, per ten-minute pass; the mod's hourly figures over
-- six passes).
-- ---------------------------------------------------------------------------
function Hb.drift(id, now, pass)
    local out = {}
    local function add(stat, delta) out[stat] = (out[stat] or 0) + delta end
    local phase = Hb.withdrawalPhase(id, now)
    if phase > 0 then
        add("STRESS", WITHDRAWAL_STRESS_PER_HOUR[phase] / 6)
        local chance = WITHDRAWAL_FATIGUE_CHANCE[phase]
        if (hashOf(id, "shakes:" .. tostring(pass)) % 100) < chance then
            add("FATIGUE", WITHDRAWAL_FATIGUE_PER_HOUR[phase] / 6)
        end
        if phase >= 2 then add("PAIN", 0.005) end   -- the mod's headaches, ours in size
    end
    for _, key in ipairs(Hb.ORDER) do
        if key ~= "drinker" then
            local tier = Hb.userTier(id, key, now)
            if tier then
                add("STRESS", TIER_LOAD[tier])
                add("FATIGUE", TIER_LOAD[tier])
                if key == "opioids" then add("PAIN", TIER_LOAD[tier]) end
            end
        end
    end
    return out
end

-- Does this person want a drink badly enough to take one now? The
-- mod's phase one is twelve hours dry; the shakes start then.
function Hb.wantsDrink(id, now)
    return Hb.withdrawalPhase(id, now) >= 1
end

-- ---------------------------------------------------------------------------
-- In plain words (DR-017, DR-018).
-- ---------------------------------------------------------------------------
local USER_WORDS = {
    cannabis = "smoked weed", cocaine = "used cocaine", opioids = "used heroin",
    stimulants = "used speed", sedatives = "used downers",
}
local PHASE_WORDS = { "wants a drink", "shaking for a drink",
                      "sick for a drink", "very sick for a drink" }

function Hb.words(id, now)
    local out = {}
    if Hb.has(id, "drinker") then
        local phase = Hb.withdrawalPhase(id, now)
        out[#out + 1] = (phase > 0) and PHASE_WORDS[phase] or "drinks"
    end
    for _, key in ipairs(Hb.ORDER) do
        if key ~= "drinker" and Hb.has(id, key) then
            local tier = Hb.userTier(id, key, now)
            local word = USER_WORDS[key]
            if tier == "bad" then word = word .. ", sweating it out"
            elseif tier then word = word .. ", coming off it" end
            out[#out + 1] = word
        end
    end
    return out
end

function Hb.describe(id, now)
    local words = Hb.words(id, now)
    if #words == 0 then return nil end
    return table.concat(words, ", ")
end

return Hb
