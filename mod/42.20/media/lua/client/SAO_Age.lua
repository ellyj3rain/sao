-- SAO_Age - age as a system on the county's people ([C30], DR-032).
--
-- [B37] gave everybody an age and [B38] put it on their heads; [C29]
-- put a child's size on the render path. This is the rest of what age
-- does to a person while they live: the drift of a body's stamina,
-- tiredness, pain and stress by life stage, and death of old age.
--
-- The stage effects are Getting Old's (Devlin; source public, taken
-- with the author's permission as the operator settled it - see
-- CREDITS.md): five stages, and per stage a small drift on the
-- engine's own stats at a sixty percent chance, with an elder marked
-- for death decaying faster until the body gives out. The mod applies
-- its numbers on every player update; the numbers read as intent at
-- a cadence, and ours is once per ten in-game minutes, which is where
-- this file puts them. Its stumble uses a Stats method this build
-- does not have (javap: no setTripping on 42.20's Stats), so there is
-- no stumble here - nothing is called that the jar does not carry.
--
-- The death roll is NOT the mod's per-frame chance. It is the life
-- table: the yearly probability of dying at an age, spread over the
-- days of the year, taken from SAO_History.oldAgeRiskPerDay (NCHS,
-- United States Life Tables, 1997, the nearest year whose table is
-- machine-readable; the 1993 table is an image scan). The roll is a
-- fact about the person and the day - the same hash everything else
-- about a person is drawn from - so two sessions agree who died
-- when. A dormant elder dies on the roll; a living one is marked, and
-- the drift finishes it the way the mod does, so the body dies on the
-- engine's own path and the corpse net records it ([C8]).

SAO = SAO or {}
SAO.Age = SAO.Age or {}
local Age = SAO.Age

local function log(msg) SAO.Log.line("AGE", msg) end

-- Getting Old's per-stage drift, at its chance. Signs: endurance is a
-- reserve (down is worse); fatigue, pain and stress are loads (up is
-- worse). Children take the young stage's drift - the mod starts at
-- twelve - and the county's own children begin at six.
local DRIFT = {
    child  = { ENDURANCE = 0.015, FATIGUE = -0.015, PAIN = -0.015 },
    young  = { ENDURANCE = 0.015, FATIGUE = -0.015, PAIN = -0.015 },
    adult  = {},
    middle = { ENDURANCE = -0.010, FATIGUE = 0.010, PAIN = 0.010, STRESS = 0.010 },
    elder  = { ENDURANCE = -0.020, FATIGUE = 0.020, PAIN = 0.020, STRESS = 0.020 },
}
local DRIFT_CHANCE = 60           -- percent, per pass, per stat
local DYING_BASE = 0.030          -- per pass once marked, scaled by age
local DYING_CHANCE = 50

local function chance(percent, id, salt)
    return (SAO.Hash.of(id, salt) % 100) < percent
end

local function applyStat(stats, name, delta)
    local stat = CharacterStat and CharacterStat[name]
    if not stat then return false end
    if delta >= 0 then stats:add(stat, delta) else stats:remove(stat, -delta) end
    return true
end

-- One pass of drift on a living body, once per ten in-game minutes.
function Age.drift(rec, body, pass)
    if not rec or not body or rec.dead then return end
    local age = SAO.History.ageOf(rec.id)
    local stage = SAO.History.stageOf(age)
    local stats = nil
    pcall(function() stats = body:getStats() end)
    if not stats then return end
    local salt = "age-drift:" .. tostring(pass)
    -- [C31] A child's fear has a floor the engine's own panic never
    -- drops below (Growing Up's, through SAO_Disposition.fear, on the
    -- engine's 0 to 100 scale): held here at the ten-minute pass
    -- rather than every second, this module's cadence for everything
    -- age does to a person. [C32] The anxious and the haunted carry
    -- one at any age, through the same read, so this asks everyone.
    do
        local fear = 0
        pcall(function() fear = SAO.Disposition.fear(rec.id) end)
        local floor = fear * 100
        if floor > 0 then
            pcall(function()
                if stats:get(CharacterStat.PANIC) < floor then
                    stats:set(CharacterStat.PANIC, floor)
                end
            end)
        end
    end
    -- [C32] The pace of learning, refreshed each pass: the age's
    -- ([C31]) times the conditions' (a focus that changes by the day).
    pcall(function()
        SAOJavaBridge:setXpScale(body, SAO.History.xpScaleOf(age)
            * SAO.Conditions.learningScale(rec.id))
    end)
    if rec.dyingOfOldAge then
        -- Getting Old's decline: faster past seventy, and the body's
        -- own health goes with it, so the engine's death path ends it.
        local ageFactor = math.max((age - 70) / 30, 0)
        local decay = DYING_BASE * (1 + ageFactor * 5)
        if chance(DYING_CHANCE, rec.id, salt) then
            applyStat(stats, "ENDURANCE", -decay)
            applyStat(stats, "FATIGUE", decay)
            applyStat(stats, "PAIN", decay)
            applyStat(stats, "STRESS", decay)
            pcall(function()
                local bd = body:getBodyDamage()
                bd:setOverallBodyHealth(bd:getOverallBodyHealth() - decay)
                body:setHealth(body:getHealth() - decay / 2)
            end)
        end
        return
    end
    local drift = DRIFT[stage]
    if not drift then return end
    for name, delta in pairs(drift) do
        if chance(DRIFT_CHANCE, rec.id, salt .. ":" .. name) then
            applyStat(stats, name, delta)
        end
    end
    -- [C32] What a condition carries every ten minutes, in the same
    -- terms at the same chance (SAO_Conditions.drift: the low and the
    -- sleepless tire, the anxious carry stress, the short of breath
    -- lose stamina, a spell turns both).
    local carried = nil
    pcall(function() carried = SAO.Conditions.drift(rec.id) end)
    if type(carried) == "table" then
        for name, delta in pairs(carried) do
            if chance(DRIFT_CHANCE, rec.id, salt .. ":carried:" .. name) then
                applyStat(stats, name, delta)
            end
        end
    end
    -- [C33] What a habit carries: the shakes by the hours dry and a
    -- dependency's withdrawal by the days clean (SAO_Habits.drift),
    -- every pass - withdrawal is not a chance.
    local habit = nil
    pcall(function() habit = SAO.Habits.drift(rec.id, nil, pass) end)
    if type(habit) == "table" then
        for name, delta in pairs(habit) do
            applyStat(stats, name, delta)
        end
    end
end

-- [C33] The day settles the habits: three weeks dry and the drinker
-- is one no longer; eighteen to twenty clean days and a dependency
-- is gone. Records, not bodies - a habit lives on the person.
function Age.settleHabits(rec, today)
    if not rec or rec.dead then return 0 end
    local settled = 0
    pcall(function()
        if SAO.Habits.settleDrinker(rec.id) then
            settled = settled + 1
            log(rec.id .. " has been dry three weeks - the drink has let go")
        end
        local n = SAO.Habits.settleUsers(rec.id)
        if n > 0 then
            settled = settled + n
            log(rec.id .. " is clean - " .. n .. " dependency gone")
        end
    end)
    return settled
end

-- [C32] Dementia's day (Neurodiverse Traits' Alzheimer's, CREDITS.md):
-- the skills lose some of what they hold, through the bridge, which
-- walks them the way the mod does. Bodies only - a skill lives on a
-- body. The roll is seeded from the person and the day.
function Age.forgetSkills(rec, body, today)
    if not (rec and body and SAOJavaBridge) then return 0 end
    local loses = false
    pcall(function() loses = SAO.Conditions.losesSkillsToday(rec.id) end)
    if not loses then return 0 end
    local seed = SAO.Hash.of(rec.id, "skill-loss:" .. tostring(today))
    local forgot = 0
    pcall(function()
        forgot = SAOJavaBridge:loseSkillMemory(body,
            SAO.Conditions.SKILL_LOSS_SHARE, SAO.Conditions.SKILL_LOSS_CHANCE, seed)
    end)
    if type(forgot) == "number" and forgot > 0 then
        log(rec.id .. " forgets some of what they knew (" .. forgot .. " skills)")
    end
    return forgot
end

-- [C32] Psychosis's hour: a threat nobody else hears, placed in the
-- person's own beliefs (SAO_Perception.hallucinate) and acted on like
-- any heard one.
function Age.hearThings(rec, body, pass)
    local hears = false
    pcall(function() hears = SAO.Conditions.hearsThingsNow(rec.id, pass) end)
    if not hears then return false end
    local placed = false
    pcall(function()
        local tick = SAO.Controller.tick()
        local x, y = SAO.Perception.hallucinate(rec.id, tick, body:getX(), body:getY())
        placed = x ~= nil
    end)
    if placed then log(rec.id .. " hears something nobody else does") end
    return placed
end

-- The day's roll for everyone alive, dormant or not. Marks the living
-- (the drift finishes them); takes the dormant on the spot, with the
-- cause the death report will carry.
function Age.dailyRoll(rec, today, tick)
    if not rec or rec.dead or rec.dyingOfOldAge then return false end
    local age = SAO.History.ageOf(rec.id)
    local risk = SAO.History.oldAgeRiskPerDay(age)
    if risk <= 0 then return false end
    local roll = (SAO.Hash.of(rec.id, "old-age:" .. tostring(today)) % 1000000) / 1000000
    if roll >= risk then return false end
    if SAO.Body.get(rec.id) then
        rec.dyingOfOldAge = true
        log(rec.id .. " (" .. age .. ") is failing - old age")
    else
        SAO.Identity.markDead(rec, tick, "old age")
        log(rec.id .. " (" .. age .. ") died of old age, at home")
    end
    return true
end

-- [C39] The player's own conditions, on the same cadence and through
-- the same functions the county's people get: what the condition
-- carries every ten minutes, dementia's day, psychosis's hour. Only
-- the conditions - SAO does not own the player's ageing, so no stage
-- drift, no fear floor over their own panic and no day of old age.
-- Silent for a player who took none, which is most of them.
--
-- [C51] And the habits, which [C39] left out: a player could not take
-- one at all, and nothing would have driven it if they could. The
-- withdrawal is the same call the county's people get in `Age.drift`
-- - SAO_Habits.drift on the same ten-minute pass - and the day that
-- settles a habit is the same call `settleHabits` makes for a record.
-- The player's key is not in SAO_Identity.all(), which is why the
-- daily settle has to be made here rather than inherited from the
-- loop below.
function Age.playerPass(player, key, pass, today)
    if not (player and key) then return false end
    local carried = nil
    pcall(function() carried = SAO.Conditions.drift(key) end)
    local habit = nil
    pcall(function() habit = SAO.Habits.drift(key, nil, pass) end)
    local acted = false
    local stats = nil
    pcall(function() stats = player:getStats() end)
    if type(carried) == "table" and stats then
        for name, delta in pairs(carried) do
            if chance(DRIFT_CHANCE, key, "carried:" .. name
                .. ":" .. tostring(pass)) then
                applyStat(stats, name, delta)
                acted = true
            end
        end
    end
    -- The withdrawal is not a chance the way a condition's carry is:
    -- SAO_Habits already rolled the shakes inside `drift`, and what
    -- it returns is what this pass costs. Rolling it again here would
    -- halve every figure the sources gave.
    if type(habit) == "table" and stats then
        for name, delta in pairs(habit) do
            applyStat(stats, name, delta)
            acted = true
        end
    end
    pcall(Age.hearThings, { id = key }, player, pass)
    if today then
        pcall(Age.forgetSkills, { id = key }, player, today)
        pcall(function() SAO.Habits.settleDrinker(key) end)
        pcall(function() SAO.Habits.settleUsers(key) end)
    end
    return acted
end

-- [C60] The place the player is standing in, spent by what the engine
-- says they emptied. `SAO_Places.take` records a survivor's taking and
-- the player's went nowhere, so a stripped shop still read as stocked
-- and the county kept walking to it ([B39]'s standing gap).
--
-- Read on the player's own ten-minute pass, which is where everything
-- else about them already happens. The radius is the reach the needs
-- layer already uses for the containers around somebody; the place is
-- the one SAO_Places puts at their feet, and where there is no place
-- there is nothing to spend.
local LOOT_REACH = 8

function Age.playerLoots(player)
    if not player then return 0 end
    local x, y = nil, nil
    pcall(function() x, y = player:getX(), player:getY() end)
    if not (x and y) then return 0 end
    local place = nil
    pcall(function() place = SAO.Places.at(math.floor(x), math.floor(y)) end)
    if not place then return 0 end
    local reading = nil
    pcall(function()
        reading = SAOJavaBridge:lootedNearby(player, LOOT_REACH)
    end)
    if type(reading) ~= "string" then return 0 end
    local looted, total = string.match(reading, "^(%d+)@(%d+)$")
    looted, total = tonumber(looted) or 0, tonumber(total) or 0
    -- Both halves are read. `total` is what separates a room that was
    -- stripped from one that never had anything to strip, and the log
    -- is the only place that difference is legible - a receipt that
    -- says "3 of 3" is a different claim from "3 of 40".
    if looted <= 0 or total <= 0 then return 0 end
    local spent = 0
    pcall(function() spent = SAO.Places.observeLooted(place, looted) end)
    if spent and spent > 0 then
        SAO.Log.line("AGE", "the player has emptied " .. looted .. " of "
            .. total .. " container(s) here - " .. tostring(place.id)
            .. " is spent by " .. spent .. " more")
    end
    return spent or 0
end

-- [C51] A drink the PLAYER took. The county's people go through
-- `SAO.Habits.drank` because the controller walks them to a bottle
-- and queues the action; the player just drinks, and there is no
-- event for it. So this reads the engine's own alcohol level
-- (`CharacterStat.INTOXICATION`, javap-verified on
-- `zombie.characters.CharacterStat`) and calls it a drink when the
-- level has RISEN since the last pass. A read rather than a hook: it
-- cannot miss an action shape it was not written for, and it cannot
-- break anything if the stat is ever renamed - the level simply never
-- rises and the clock never resets, which is the same as today.
--
-- The threshold is the engine's own resolution and not a tuned
-- number: any rise at all is a drink. Falling or level is not.
local lastIntoxication = nil

function Age.playerDrinks(player, key)
    if not (player and key) then return false end
    local level = nil
    pcall(function()
        level = player:getStats():get(CharacterStat.INTOXICATION)
    end)
    if type(level) ~= "number" then return false end
    local was = lastIntoxication
    lastIntoxication = level
    if was == nil or level <= was then return false end
    local drank = false
    pcall(function() drank = SAO.Habits.drank(key) end)
    return drank == true
end

local lastDay = nil
local passCounter = 0

local function everyTenMinutes()
    passCounter = passCounter + 1
    local okH, hours = pcall(function()
        return SAO.History.countyHours()
    end)
    if not okH then return end
    local today = math.floor(hours / 24.0)
    local newDay = lastDay ~= today
    for id, body in pairs(SAO.Body.active) do
        local rec = SAO.Identity.get(id)
        if rec then
            pcall(Age.drift, rec, body, passCounter)
            pcall(Age.hearThings, rec, body, passCounter)
            if newDay then pcall(Age.forgetSkills, rec, body, today) end
        end
    end
    -- [C39] The player carries what they took.
    pcall(function()
        local me = getSpecificPlayer(0)
        if not me then return end
        local key = SAO.Standing.playerKey(me)
        if key then
            -- [C51] The drink is read BEFORE the pass, so a drink
            -- taken this pass stops this pass's shakes rather than
            -- the next one's.
            Age.playerDrinks(me, key)
            Age.playerLoots(me)                       -- [C60]
            Age.playerPass(me, key, passCounter, newDay and today or nil)
        end
    end)
    if newDay then
        lastDay = today
        local tick = passCounter
        for id, rec in pairs(SAO.Identity.all()) do
            pcall(Age.dailyRoll, rec, today, tick)
            pcall(Age.settleHabits, rec, today)
        end
    end
end

if Events and Events.EveryTenMinutes then
    Events.EveryTenMinutes.Add(everyTenMinutes)
end

log("age module loaded (stage drift every ten minutes, the day's roll for old age,"
    .. " what a condition carries, dementia's day, psychosis's hour,"
    .. " the shakes and the day that settles a habit)")

return Age
