-- SAO_History - the apocalypse clock and the settled past (DR-006 S1,
-- corrected at [A14]).
-- ---------------------------------------------------------------------------
-- A survivor's past is a SMALL set of settled claims with provenance -
-- paid-for (lived), seen, or told - plus an epistemic age: how many months
-- of apocalypse they have had to learn anything at all. Claims echo into
-- traits (bounded at the disposition primitive) and feed the lesson
-- economy (S2). TEXT IS ONLY A RENDERING of the claims, produced at read
-- time and never stored; the record holds knowledge, not narrative.
--
-- Sparsity is the discipline: most claims carry no name and no story. At
-- most ONE claim - the costliest lived one - may carry the name of who it
-- cost, and only sometimes. The dead are an attribution, not a cast.

SAO = SAO or {}
SAO.History = SAO.History or {}
local H = SAO.History

-- [B47] One door out. `log` is what happened once; `tally` is
-- what happens once per person, counted rather than printed.
local function log(msg) SAO.Log.line("HISTORY", msg) end
local function tally(kind) SAO.Log.tally("HISTORY", kind) end

-- ---------------------------------------------------------------------------
-- [C62] WHAT HOUR IT IS FOR THE COUNTY.
--
-- Sixty-eight places in this tree ask GameTime for the world age in
-- hours, and every one of them means "how far along is this county".
-- They stamp when somebody last drank, when a feeling was last aged,
-- when a death's word is due, when a bite is due to kill.
--
-- [C45] lives the days a later save owes before anybody is spawned,
-- and the game clock does not move while it does. So all sixty-eight
-- read the same hour for the whole span, and the systems gated on a
-- CHANGE of day never saw one:
--
--   * attrition stamped `lastRiskDay` on the first simulated day and
--     its `today > lastRiskDay` gate was false every day after, so
--     nobody died in three years;
--   * `lastWaterDay` and `lastFoodDay` never advanced, so nobody
--     grew thirsty and nobody went looking for water;
--   * `lastDriftDay` matched, so no feeling aged;
--   * the winter multiplier read GameTime's month, which was the
--     save's start month for the whole span.
--
-- A thousand simulated days changed almost nothing. [C45] said the
-- county lives the years; what it actually did was call the systems
-- that live them and hand each one a clock that had stopped.
--
-- This is the hour those systems read now. While the years are being
-- lived it is the day being lived, times twenty-four. Otherwise it is
-- the days this save began behind the record plus the game's own
-- hours, which carries on from where the years stopped: a stamp made
-- during the years has to stay in the past once play begins, and
-- dropping back to the game's own zero would put every one of them in
-- the future.
--
-- A save with no years behind it reads the game's own hours and
-- nothing else, so nothing that ran before this runs differently.
-- ---------------------------------------------------------------------------

-- The shared store, which is where [C45] keeps how far the years have
-- got. Memoised on success only: a bare VM has no ModData and must
-- keep falling through rather than caching the absence.
local storeMemo = nil
local function yearsState()
    if storeMemo ~= nil then return storeMemo end
    local ok, s = pcall(function()
        return ModData.getOrCreate("SurvivorAwareness_Standing")
    end)
    if not ok or type(s) ~= "table" then return nil end
    storeMemo = s
    return s
end

-- The day the county is living, while it is living the years. Nil at
-- every other time, which is what tells the two clocks below to read
-- the game's own.
local function livingDay()
    local s = yearsState()
    if not s or not s.yearsAsked then return nil end
    local run = tonumber(s.yearsRun) or 0
    local owed = tonumber(s.yearsOwed) or 0
    if run >= owed then return nil end
    return run
end

-- [C63] The switch that says this county starts before its own
-- outbreak. The same one `SAO_Record.placeTimeline` reads, so the
-- record's timeline and the days the county owes cannot disagree
-- about which saves the record is moved onto.
local function dayZeroAsked()
    local sv = SandboxVars and SandboxVars.SurvivorAwareness or nil
    return (sv and sv.DayZero == true) or false
end

-- [C63] How many days of history this save begins with behind it,
-- and -1 when the clock cannot be read.
--
-- One reader, because there were two and they answered differently.
-- `[C45]`'s years pass asked the bridge for this number and
-- remembered it for the life of the save; `SAORecord.countyMonth0`
-- worked it out again from `recordDayOf`, which knows nothing about
-- the day-zero switch. A shifted July 20 start would have read its
-- months eleven days early for the whole save while its clock read
-- them correctly.
function H.daysOwed()
    local days = nil
    pcall(function()
        days = SAOJavaBridge:daysBehindAtStart(dayZeroAsked())
    end)
    return (type(days) == "number") and days or -1
end

-- How far behind the record this save began, in hours. Constant for
-- a save, so it is asked once; a bridge that is not up yet answers
-- nothing and is asked again next time rather than being remembered
-- as zero.
local behindMemo = nil
local function hoursBehind()
    if behindMemo then return behindMemo end
    local days = H.daysOwed()
    if days < 0 then return 0 end
    behindMemo = days * 24.0
    return behindMemo
end

-- The county's clock, in hours. Never negative and never goes
-- backwards, which is what every stamp in this mod assumes.
function H.countyHours()
    local day = livingDay()
    if day then return day * 24.0 end
    local hours = 0
    pcall(function()
        hours = GameTime.getInstance():getWorldAgeHours()
    end)
    return hoursBehind() + (tonumber(hours) or 0)
end

-- The county's calendar month, numbered 0 to 11 the way the engine
-- numbers them. The engine's own month is right whenever the game
-- clock is running and wrong for the whole of the years, so this
-- asks the record which month the county's hours have reached and
-- falls back to the engine where the record cannot answer.
function H.countyMonth()
    local month = nil
    pcall(function()
        month = SAOJavaBridge:countyMonth(H.countyHours(), dayZeroAsked())
    end)
    if type(month) == "number" and month >= 0 and month <= 11 then
        return month
    end
    pcall(function() month = GameTime.getInstance():getMonth() end)
    if type(month) == "number" and month >= 0 and month <= 11 then
        return month
    end
    return nil
end

-- The county's time of day, on the engine's own 0 to 24.
--
-- The same defect as the clock above and it needs a different answer.
-- [C45] runs ONE call per simulated day, so a simulated day has no
-- hours in it to be at; the engine's own time of day is whatever
-- o'clock the save was created at, held there for the whole span. A
-- save begun at three in the morning sent every survivor home to
-- sleep and kept them there for a thousand days, and a child's night
-- fear stood at its maximum for the same thousand.
--
-- So while the years run this says noon. That is a claim and not a
-- derivation: what a simulated day models is a day's worth of going
-- out and coming back, which happens in daylight, and the alternative
-- is running each of those days through its own twenty-four hours,
-- which F-055 measured and DR-037 ruled out.
--
-- Outside the years it is the engine's, unchanged.
local YEARS_HOUR = 12.0

function H.countyTimeOfDay()
    if livingDay() then return YEARS_HOUR end
    local hour = nil
    pcall(function() hour = GameTime.getInstance():getTimeOfDay() end)
    if type(hour) == "number" then return hour end
    return nil
end

-- Which day of the record's own calendar the county has reached.
-- Negative through an ordinary county that has not had its outbreak
-- yet, and nil when no calendar can be read at all.
--
-- This is not `countyHours` divided by twenty-four. That one counts
-- elapsed time from zero; this one is a position on a calendar that
-- runs from before day zero, and a shifted [C43] start begins at a
-- negative number on it while no time at all has elapsed.
function H.recordDay()
    local day = livingDay()
    if day then return day end
    local told = nil
    pcall(function() told = SAOJavaBridge:recordDayToday() end)
    if type(told) == "number" and told > -90000 then return told end
    return nil
end

-- Months since the outbreak began, as of NOW (fractional).
--
-- [C61] Off the record's own calendar, not the sandbox dial. This
-- number ages what every person in the county KNOWS - the split clock
-- below turns it into contact months, and the lesson pool and the
-- claims a person carries are drawn from that. It read
-- `SandboxVars.TimeSinceApo` while [C42] had already ruled that when
-- the fall happened is read from the record's calendar "and never
-- from the sandbox dial", and [C45] runs the county forward over the
-- days a later save owes off that same calendar.
--
-- So a 1996 save simulated about a thousand days of collapse and then
-- told every survivor in it that they were one month in, because the
-- dial's default is one. Three spellings of one fact, and the one
-- that decides what people know was reading a different source from
-- the two that decide what happened.
--
-- Before the fall the answer is zero, which is not a fallback: a
-- county that has not had its outbreak has nobody who has lived
-- through one, and that is day zero's whole premise ([A29] - innocent
-- by construction).
--
-- The dial remains the answer where the calendar cannot be read at
-- all - a bare VM, the offline mirrors, a load before the bridge is
-- up - so this module stays offline by construction and nothing that
-- ran before runs differently there.
function H.clockMonths()
    -- [C62] Through `recordDay`, so the months a person has had to
    -- learn anything advance while the years are being lived. It
    -- read the bridge directly and the bridge reads the game clock,
    -- which is stopped for the whole span.
    local day = H.recordDay()
    if day ~= nil then
        if day < 0 then return 0 end
        return day / 30.0
    end
    local sv = SandboxVars or nil
    local startMonths = (sv and tonumber(sv.TimeSinceApo)) or 1
    local elapsed = 0
    pcall(function()
        elapsed = GameTime.getInstance():getWorldAgeHours() / (24.0 * 30.0)
    end)
    return (startMonths - 1) + elapsed
end

local function hashOf(id, salt)
    -- [B48] Kahlua's numbers are doubles and the FNV step
    -- overflowed the mantissa, collapsing this to a handful of
    -- values. One implementation now, computed exactly.
    return SAO.Hash.of(id, salt)
end

-- [B38] A coin, and NOT `hashOf(...) % 2`.
--
-- FNV's low bit is a parity checksum of its input, not a random bit.
-- The step is `v = v * 16777619 + byte` and 16777619 is odd, so the
-- bottom bit of v is the running parity of every byte fed in, plus
-- the basis. Across ids that differ by a digit - which is every id
-- this mod makes - that parity barely moves.
--
-- Measured over a thousand pairs: `% 2` came up heads 9% of the time.
-- It was deciding partner-versus-sibling for every family in the
-- county, and - older than this batch - how many contacts a survivor
-- starts life with, two lines apart. A bit from the middle of the
-- word gives 51%.
local function coinOf(id, salt)
    return math.floor(hashOf(id, salt) / 65536) % 2
end

-- [B37] How old this person is, and therefore what they lived
-- through before any of this.
--
-- The clock below counts months of APOCALYPSE. Nothing counted the
-- years before it, so every survivor's knowable past began the day
-- the world ended and none of them remembered a decade of it. Age is
-- the one number that fixes that: birth year falls out of the world's
-- own start year, and which decades a person actually lived through
-- is then arithmetic rather than a table per person.
--
-- The shape used to be the county the apocalypse leaves behind rather
-- than a census of 1993: [B37] hand-set five bands from nineteen to
-- sixty-eight, skewed young because "the old die first", and kept no
-- children because the mod modelled none. [C30] replaces both with
-- the record and the ruling (DR-032): the weights below are the 1990
-- resident population of the United States by age (NCHS, Health,
-- United States, 2003, Table 1, "all persons, number in thousands":
-- 5-14 35,095; 15-24 37,013; 25-34 43,161; 35-44 37,435; 45-54
-- 25,057; 55-64 21,113; 65-74 18,045; 75-84 10,012; 85 and over
-- 3,021), spread evenly across the years inside each group and cut
-- to the county's own bands. Kentucky's own 1990 table sits on a
-- Census host that would not answer the day this was written; its
-- shares differ from the nation's by well under a point at both
-- ends. The county keeps no infants: it starts at six. Whoever dies
-- first is no longer authored into the bands - the attrition and the
-- age module decide that, person by person.
--
-- Deterministic from the same hash the traits use, so age is a fact
-- about WHO SOMEBODY IS rather than a roll at read time, and two
-- sessions agree about the same person.
local AGE_BANDS = {
    { from = 6, to = 14, weight = 31586 },
    { from = 15, to = 17, weight = 11104 },
    { from = 18, to = 24, weight = 25909 },
    { from = 25, to = 29, weight = 21581 },
    { from = 30, to = 39, weight = 40299 },
    { from = 40, to = 49, weight = 31247 },
    { from = 50, to = 59, weight = 23086 },
    { from = 60, to = 68, weight = 17775 },
    { from = 69, to = 74, weight = 10827 },
    { from = 75, to = 84, weight = 10012 },
    { from = 85, to = 90, weight = 3021 },
}
local AGE_TOTAL = 0
for _, band in ipairs(AGE_BANDS) do AGE_TOTAL = AGE_TOTAL + band.weight end

-- The bands as declared, for the border that checks the county
-- against them.
function H.bands()
    local out = {}
    for i, band in ipairs(AGE_BANDS) do
        out[i] = { from = band.from, to = band.to, weight = band.weight }
    end
    return out
end

function H.ageOf(id)
    local roll = hashOf(id, "age") % AGE_TOTAL
    local seen = 0
    for _, band in ipairs(AGE_BANDS) do
        seen = seen + band.weight
        if roll < seen then
            local span = band.to - band.from
            return band.from
                + (hashOf(id, "ageIn") % (span + 1))
        end
    end
    return 34
end

-- The year they were born, against the world's OWN start year - so a
-- sandbox that begins in 1997 moves everybody four years without a
-- second table.
function H.birthYearOf(id)
    local start = 1993
    pcall(function()
        local y = GameTime.getInstance():getStartYear()
        if y and y > 1900 then start = y end
    end)
    return start - H.ageOf(id)
end

-- How old they were in a given year - negative before they existed.
-- The whole point of carrying age: what a person can remember of a
-- decade depends entirely on how old they were during it.
function H.ageInYear(id, year)
    return (tonumber(year) or 0) - H.birthYearOf(id)
end

-- [C29] The body's size from the age. An adult is 1; a child is the
-- fraction of an adult's height, taken from the Growing Up mod's
-- height-by-age table (128 cm at 8 to 178 cm at 18, walked on its
-- growth curve - childhood slow, the teens fast) with the author's
-- permission as the operator settled it (CREDITS.md). 170 cm is that
-- table's adult reference, so 18 answers 1.0 and 8 answers 0.753.
-- Under 8 the table has nothing; the line is carried down three
-- percent a year, which is ours and said so. Nobody in the county is
-- under 19 yet ([B37]'s bands), so today this answers 1 for everyone;
-- the child bands arrive with the age batch. The body reads it once,
-- when it materializes (SAO_Body), and the woven advice applies it on
-- the render path from then on.
local GROWTH_START, GROWTH_ADULT = 8, 18
local GROWTH_CURVE = 1.20
local ADULT_REFERENCE_CM = 170
local HEIGHT_CM = {
    [8] = 128, [9] = 133, [10] = 138, [11] = 143, [12] = 149, [13] = 156,
    [14] = 163, [15] = 168, [16] = 172, [17] = 175, [18] = 178,
}

-- [C30] The life stages, Getting Old's five (Devlin; source public,
-- taken with the author's permission as the operator settled it -
-- CREDITS.md), with the county's own children below its first: child
-- under 18, young 18 to 25, adult 26 to 40, middle 41 to 60, elder 61
-- and over. The stage is what the drift and the work read.
function H.stageOf(age)
    age = tonumber(age) or 0
    if age < 18 then return "child" end
    if age <= 25 then return "young" end
    if age <= 40 then return "adult" end
    if age <= 60 then return "middle" end
    return "elder"
end

-- [C30] The pace of the age, as the engine's speed modifier. A child's
-- is Growing Up's (0.70 at 8 to 1.00 at 18 on its visual age; under 8
-- the line is carried down and is ours). An adult's is 1. An elder's
-- slows from 68 to 0.80 at 90 - that line is ours, and said so: Getting
-- Old slows nobody, it tires them, and the drift carries that part.
function H.speedModOf(id)
    local age = H.ageOf(id)
    if age < GROWTH_START then return 0.65 end
    if age < GROWTH_ADULT then
        local t = ((age - GROWTH_START) / (GROWTH_ADULT - GROWTH_START)) ^ GROWTH_CURVE
        return 0.70 + t * 0.30
    end
    if age <= 68 then return 1.0 end
    local t = math.min(1, (age - 68) / (90 - 68))
    return 1.0 - 0.20 * t
end

-- [C30] The chance of dying of age itself, per day. Zero under sixty;
-- from sixty, the life table's yearly probability of dying at that
-- age, spread over the year's days. The table is NCHS, United States
-- Life Tables, 1997 (National Vital Statistics Reports vol. 47 no.
-- 28), total population - the nearest year whose table is
-- machine-readable; the 1993 table exists (Vital Statistics of the
-- United States 1993, Life Tables) and is an image scan, and the four
-- years between move these figures by a few percent, which is noted
-- and accepted. Between the table's ages the line is straight.
local LIFE_TABLE_YEARLY = {
    { 60, 0.01101 }, { 65, 0.01679 }, { 70, 0.02565 }, { 75, 0.03843 },
    { 80, 0.05938 }, { 85, 0.09653 }, { 90, 0.15085 }, { 95, 0.22354 },
}

function H.oldAgeRiskPerDay(age)
    age = tonumber(age) or 0
    if age < 60 then return 0 end
    local yearly = LIFE_TABLE_YEARLY[#LIFE_TABLE_YEARLY][2]
    for i = 1, #LIFE_TABLE_YEARLY - 1 do
        local a0, q0 = LIFE_TABLE_YEARLY[i][1], LIFE_TABLE_YEARLY[i][2]
        local a1, q1 = LIFE_TABLE_YEARLY[i + 1][1], LIFE_TABLE_YEARLY[i + 1][2]
        if age >= a0 and age < a1 then
            yearly = q0 + (q1 - q0) * ((age - a0) / (a1 - a0))
            break
        end
    end
    return yearly / 365
end

function H.heightScaleOf(id)
    local age = H.ageOf(id)
    if age >= GROWTH_ADULT then return 1.0 end
    if age < GROWTH_START then
        local atStart = HEIGHT_CM[GROWTH_START] / ADULT_REFERENCE_CM
        return math.max(0.5, atStart - (GROWTH_START - age) * 0.03)
    end
    local t = ((age - GROWTH_START) / (GROWTH_ADULT - GROWTH_START)) ^ GROWTH_CURVE
    local visual = GROWTH_START + t * (GROWTH_ADULT - GROWTH_START)
    local lo = math.floor(visual)
    local hi = math.min(GROWTH_ADULT, lo + 1)
    local cm = HEIGHT_CM[lo] + (HEIGHT_CM[hi] - HEIGHT_CM[lo]) * (visual - lo)
    return math.min(1.0, cm / ADULT_REFERENCE_CM)
end

-- [B39] The war they were old enough for.
--
-- [B37] built `ageInYear` and closed saying nothing read it. This
-- reads it, and it is the cleanest thing age can be asked: a person's
-- war is not a fact about them that needs storing, it is arithmetic
-- over the year they were born.
--
-- The windows are real and are not mine. US ground involvement ran
-- 1950-1953 in Korea, 1965-1973 in Vietnam, and the Gulf ground war
-- was 1990-1991. The operator's ruling for exactly this: model the
-- early 1990s as they were, not an invented decade. Modelling
-- a world that actually happened is fidelity, not invention.
--
-- Against the county's own age bands - nineteen to sixty-eight in
-- 1993, so born 1925 to 1974 - all three windows are reachable and
-- the youngest are too young for any of them, which is correct.
local WARS = {
    { key = "Korea", from = 1950, to = 1953 },
    { key = "Vietnam", from = 1965, to = 1973 },
    { key = "the Gulf", from = 1990, to = 1991 },
}

-- Old enough to be sent, young enough to be sent. Nobody is drafted
-- at sixteen and few at thirty.
local SERVICE_MIN, SERVICE_MAX = 18, 26

-- ---------------------------------------------------------------------------
-- [C31] The child's day. Growing Up's systems (PZ Chronicles; read with
-- the authors' permission as the operator settled it, CREDITS.md),
-- carried at SAO's own seams: the fear floor by age, the night, the
-- comfort object and the kills that harden; literacy; the experience
-- throttle and the birthday floors on strength and fitness; the kit a
-- child carries, drawn from their own temperament. The numbers are
-- the mod's; where a number is ours it says so.

-- The fear floor: 0.55 at eight (the mod's starting age; the county's
-- six- and seven-year-olds take the same floor), falling straight to
-- nothing at eighteen. A fraction of the engine's own panic scale.
local FEAR_FLOOR_START = 0.55
local FEAR_START_AGE = 8
local FEAR_ADULT_AGE = 18

function H.fearFloorOf(age)
    if type(age) ~= "number" then return 0 end
    if age >= FEAR_ADULT_AGE then return 0 end
    if age <= FEAR_START_AGE then return FEAR_FLOOR_START end
    local t = (age - FEAR_START_AGE) / (FEAR_ADULT_AGE - FEAR_START_AGE)
    return FEAR_FLOOR_START * (1 - t)
end

-- The night, ten in the evening to five in the morning: a fifth more
-- fear under twelve, a tenth to fourteen, none from fifteen. `hour` is
-- the engine's own time of day (GameTime.getTimeOfDay, 0 to 24).
local NIGHT_FROM, NIGHT_TO = 22, 5

function H.nightFearOf(age, hour)
    if type(age) ~= "number" or type(hour) ~= "number" then return 0 end
    if age >= 15 then return 0 end
    if not (hour >= NIGHT_FROM or hour < NIGHT_TO) then return 0 end
    if age < 12 then return 0.20 end
    return 0.10
end

-- What eases it: a comfort object carried (the mod's list; every item
-- verified against the shipped scripts) takes 0.60 off the floor -
-- the mod's figure, enough that a frightened child with a bear can
-- sleep - and every zombie the child has killed by their own hand
-- takes half a hundredth off it for good.
H.COMFORT_OBJECTS = { "Base.ToyBear", "Base.ToyBear_Crafted_Cotton",
                      "Base.ToyBear_Crafted_Burlap", "Base.Doll" }
H.COMFORT_EASE = 0.60
H.KILL_EASE = 0.005

-- Literacy. The mod counts easy reads until a child can read; the
-- county's children lived their school years before the fall, so the
-- reads are the years: none before eight, slow to eleven, reading
-- from twelve. What a slow reader takes from a book is the throttle's
-- business below, not a second gate.
function H.literacyOf(id)
    local age = H.ageOf(id)
    if age < 8 then return "none" end
    if age < 12 then return "slow" end
    return "reads"
end

-- The experience throttle: a quarter under ten, half under fourteen,
-- full from fourteen. Strength, fitness and sprinting are exempt (the
-- floors below pace those, and the mod found a quarter of a small
-- packet rounds to nothing). The bridge applies it on every grant.
function H.xpScaleOf(age)
    if type(age) ~= "number" then return 1.0 end
    if age < 10 then return 0.25 end
    if age < 14 then return 0.50 end
    return 1.0
end

-- The birthday floors: the strength and fitness a child of each age
-- has at least, reaching the engine's adult baseline of five at
-- eighteen. Under eight takes eight's. Nil for anyone grown.
local STRENGTH_FLOOR = { [8] = 0, [9] = 0, [10] = 1, [11] = 1, [12] = 2,
                         [13] = 2, [14] = 3, [15] = 3, [16] = 4, [17] = 4 }
local FITNESS_FLOOR  = { [8] = 0, [9] = 1, [10] = 1, [11] = 2, [12] = 2,
                         [13] = 3, [14] = 3, [15] = 4, [16] = 4, [17] = 5 }

function H.perkFloorsOf(age)
    if type(age) ~= "number" or age >= 18 then return nil end
    local a = math.floor(math.max(age, 8))
    return STRENGTH_FLOOR[a], FITNESS_FLOOR[a]
end

-- The kid types. The mod offers six to a player; here the type falls
-- out of the child's own eight axes (SAO_Disposition), so it is
-- derived, never dealt: the aggressive one is the bully, the
-- nerveless the crybaby, the quiet one shy, the disciplined the nerd,
-- the bold self-starter the jock, and the rest are scouts, the mod's
-- own default. A type is the outer fifth of the envelope on the axis
-- that names it (traits run 0.15 to 0.85, so 0.71 and 0.29), which
-- keeps any one type from being a third of the county's children.
-- The type decides only what the child carries; what the mod's
-- milestones fade with age - the fear, the slow learning - already
-- fades above.
function H.archetypeOf(id)
    local t = nil
    pcall(function() t = SAO.Disposition.traits(id) end)
    if not t then return "scout" end
    if t.aggression > 0.71 then return "bully" end
    if t.nerve < 0.29 then return "crybaby" end
    if t.talkativeness < 0.29 then return "shy" end
    if t.discipline > 0.71 then return "nerd" end
    if t.initiative > 0.55 and t.nerve > 0.55 then return "jock" end
    return "scout"
end

-- What each type carries (the mod's lists; every item verified
-- against the shipped scripts). Clothing is the census outfit's.
local KIT = {
    scout   = { "Base.Rope", "Base.WaterBottle", "Base.FishingRod",
                "Base.ChocoCakes" },
    jock    = { "Base.WaterBottle", "Base.Book_Sports" },
    nerd    = { "Base.Book_Horror", "Base.ComicBook", "Base.Pencil",
                "Base.PenLight" },
    shy     = { "Base.ComicBook", "Base.Yoyo" },
    bully   = { "Base.Plonkies" },
    crybaby = {},
}
-- A bought bear or a doll, not a crafted one: the county fell in 1993.
local KIT_COMFORT = { "Base.ToyBear", "Base.Doll" }
-- Who carries one is a fact about the person: most under twelve, some
-- to fourteen, none older. Ours, and said so.
local COMFORT_SHARE_UNDER_12 = 75
local COMFORT_SHARE_UNDER_15 = 30

function H.kitOf(id)
    local age = H.ageOf(id)
    if age >= 18 then return nil end
    local out = { "Base.Bag_Schoolbag_Kids" }
    local share = 0
    if age < 12 then share = COMFORT_SHARE_UNDER_12
    elseif age < 15 then share = COMFORT_SHARE_UNDER_15 end
    if share > 0 and (hashOf(id, "comfort") % 100) < share then
        out[#out + 1] = KIT_COMFORT[(hashOf(id, "comfort-which") % #KIT_COMFORT) + 1]
    end
    for _, item in ipairs(KIT[H.archetypeOf(id)] or {}) do
        out[#out + 1] = item
    end
    return out
end

-- Nil for somebody no war reached, which is most of the county.
function H.warOf(id)
    local found = nil
    for _, war in ipairs(WARS) do
        local atStart = H.ageInYear(id, war.from)
        local atEnd = H.ageInYear(id, war.to)
        -- They turned service age before it ended and had not aged out
        -- before it began.
        if atEnd >= SERVICE_MIN and atStart <= SERVICE_MAX then
            found = war.key
        end
    end
    return found
end

-- Did this person's life actually put them in one? Only the lives the
-- census already calls military - a schoolteacher born in 1948 was
-- the right age for Vietnam and did not go.
local SERVED = { veteran = true, soldier = true }

function H.servedIn(id, occupation)
    if not SERVED[tostring(occupation or "")] then return nil end
    return H.warOf(id)
end

local LOST_NAMES = {
    "Maria", "Devon", "Ruth", "Caleb", "Ana", "Marcus", "June", "Elias",
    "Priya", "Tom", "Rosa", "Walt", "Nadia", "Hank", "Simone", "Ray",
}

-- The claim grammar: which lessons a life like THIS could have settled,
-- and what each settles into. fits() reads base traits (the claim
-- explains the trait bend it echoes; it never contradicts the person).
local GRAMMAR = {
    { key = "measure-the-danger",  fits = function(t) return t.nerve < 0.45 end,
      echoes = { nerve = -0.08, selfPreservation = 0.10 }, mortal = true },
    { key = "doors-decide-lives",  fits = function(t) return t.aggression > 0.55 end,
      echoes = { aggression = 0.05, compassion = -0.06 }, mortal = false },
    { key = "people-are-worth-it", fits = function(t) return t.compassion > 0.55 end,
      echoes = { compassion = 0.08 }, mortal = true },
    { key = "claimed-places-bite", fits = function(t) return true end,
      echoes = { discipline = 0.05 }, mortal = false },
    { key = "routine-is-armor",    fits = function(t) return t.discipline > 0.5 end,
      echoes = { discipline = 0.05, initiative = -0.04 }, mortal = false },
    { key = "noise-is-a-debt",     fits = function(t) return t.initiative > 0.5 end,
      echoes = { nerve = 0.04 }, mortal = true },
    { key = "running-has-a-price", fits = function(t) return t.selfPreservation > 0.55 end,
      echoes = { selfPreservation = 0.06, compassion = 0.04 }, mortal = true },
}

-- The split clock ([A17]): world-time is the sandbox's (clockMonths);
-- each BODY carries contactMonths - months alive scaled by an isolation
-- factor - and everything settled rides CONTACT. A six-month hermit
-- (factor near the floor) has settled almost nothing; two people in the
-- same month hold different sets because their contact and their rolls
-- differ.
function H.contactFactor(id)
    -- 0.10 (hermit) .. 1.00 (gregarious); hash-stable per identity.
    return 0.10 + (hashOf(id, 77) % 900) / 1000.0
end

-- Settle the past once per record: contact months, a SPARSE claim set
-- with ROLLED provenance (a settled past includes hearsay a person
-- organized their life around), settled trait echoes scaled by how the
-- claim was acquired, and at most one named cost on a lived claim.
function H.generate(id, rec, monthsAliveOverride)
    if rec.epistemicMonths ~= nil then return end
    -- The census seam ([A18], DR-010): every generated past begins with
    -- who this person WAS. One seam covers every caller - genesis,
    -- harness spawn, Knox adoption, and whatever comes later.
    --
    -- [B42] This used to say that Knox adoptees "arrive with
    -- occupation ALREADY SET ([A20] - the seed runs before this); only
    -- the unreadable fall to a presumed draw". DR-012 reversed that, so
    -- ALL of them fall to the draw now and all of them are flagged
    -- honest. The sentence is replaced rather than left standing,
    -- because a comment describing a path that no longer exists is the
    -- same defect one layer up from the code.
    if not rec.occupation and SAO.Census then
        local row = SAO.Census.assign(id)
        if row then
            rec.occupation = row.key
            if rec.knox then rec.occupationPresumed = true end
        end
        -- [C30] The age decides the work before the draw does: a child
        -- is a student whatever the census dealt, and past sixty-eight
        -- a working life is over - a retiree, unless the draw already
        -- kept them home. Both rows are the census's own (DR-011: a
        -- retiree's day is not a student's), so everything downstream
        -- that reads a row reads a real one.
        local age = H.ageOf(id)
        if age < 18 then
            rec.occupation = "student"
        elseif age > 68 and rec.occupation ~= "homemaker" then
            rec.occupation = "retiree"
        end
    end
    local worldMonths = H.clockMonths()
    local monthsAlive = monthsAliveOverride or worldMonths
    local contact = monthsAlive * H.contactFactor(id)
    rec.monthsAlive = math.floor(monthsAlive * 10 + 0.5) / 10
    rec.contactMonths = math.floor(contact * 10 + 0.5) / 10
    rec.epistemicMonths = rec.contactMonths   -- readers keep working
    -- [B41] `rec.seasonedMonths = rec.contactMonths` used to follow.
    -- Three names for one number, and the third was read by nothing
    -- anywhere in the tree - `epistemicMonths` is the back-compat
    -- alias that IS read and says so on its own line. A duplicate
    -- nobody reads is not redundancy, it is a value that can drift
    -- from its source with nothing to notice.
    local traits = SAO.Disposition.traits(id)

    -- The past has a trade ([A18], census C3): occupation class biases
    -- WHICH claims settle (affinity = pick-pool multiplicity; the
    -- deputy's measure-the-danger crowds the draw) and HOW they were
    -- paid for (provenance tilt: hardened trades lived it; settled
    -- trades were mostly told). The CLOCK is deliberately untouched -
    -- contact and count stay occupation-blind so the hermit invariant
    -- holds; only the texture of the settled past bends.
    local occClass = (SAO.Census and SAO.Census.classOf)
        and SAO.Census.classOf(rec.occupation) or nil
    local AFFINITY = {
        hardened = { ["measure-the-danger"] = 3, ["doors-decide-lives"] = 2,
                     ["routine-is-armor"] = 2 },
        carer    = { ["people-are-worth-it"] = 3, ["running-has-a-price"] = 2 },
        outdoors = { ["noise-is-a-debt"] = 2, ["routine-is-armor"] = 2,
                     ["claimed-places-bite"] = 2 },
        settled  = { ["claimed-places-bite"] = 2, ["people-are-worth-it"] = 2 },
        trades   = { ["routine-is-armor"] = 2, ["doors-decide-lives"] = 2 },
    }
    local TILT = { hardened = 15, carer = 10, outdoors = 5,
                   settled = -15, trades = 0 }
    local affinity = occClass and AFFINITY[occClass] or nil
    local livedBar = 45 + (occClass and TILT[occClass] or 0)
    -- [B39] Somebody who was actually in one paid for more of what
    -- they know. This uses the bar that already exists rather than
    -- inventing a second mechanism, and it applies only to the lives
    -- the census calls military whose AGE put them in a real war.
    local theirWar = nil
    pcall(function() theirWar = H.servedIn(id, rec.occupation) end)
    if theirWar then livedBar = livedBar + 15 end

    -- Count rides CONTACT, not the slider: the hermit's half-year can
    -- settle less than a trader's fortnight.
    local count
    if contact < 0.5 then count = coinOf(id, 21)              -- 0..1
    elseif contact < 2 then count = 1 + coinOf(id, 21)        -- 1..2
    else count = 1 + hashOf(id, 21) % 3 end                   -- 1..3

    local fitting = {}
    for _, entry in ipairs(GRAMMAR) do
        if entry.fits(traits) then
            local times = (affinity and affinity[entry.key]) or 1
            for _ = 1, times do fitting[#fitting + 1] = entry end
        end
    end
    local echoes = {}
    local named = false
    local settled = 0
    local used = {}
    for k = 1, count do
        if #fitting == 0 then break end
        local index = (hashOf(id, 30 + k) % #fitting) + 1
        local pick = fitting[index]
        if pick == nil then
            -- [C18] Seen twice in the operator's first session on this
            -- build (F-048): the index landed outside a table the line
            -- above just proved non-empty. The arithmetic is exact
            -- non-negative integers and `fitting` is built densely, so
            -- WHY is not established - and guessing is what this
            -- repository does not do. Skipping the claim keeps one
            -- person's past from ending generate() for that whole
            -- population pass, and the line below hands the next
            -- session the numbers instead of another theory.
            log("claim pick missed: index " .. tostring(index) .. " of "
                .. tostring(#fitting) .. " for " .. tostring(id))
        elseif not used[pick.key] then
            used[pick.key] = true
            settled = settled + 1
            -- Provenance is ROLLED per claim: lived 45 / witnessed 25 /
            -- told 30. Echoes scale with the weight - hearsay bends a
            -- person less than what they paid for.
            local roll = hashOf(id, 90 + k) % 100
            local src, weight
            if roll < livedBar then src, weight = "lived", 1.0
            elseif roll < livedBar + 25 then src, weight = "witnessed", 0.6
            else src, weight = "told", 0.4 end
            for trait, delta in pairs(pick.echoes) do
                echoes[trait] = (echoes[trait] or 0) + delta * weight
            end
            local of = nil
            if src == "lived" and pick.mortal and not named
                and (hashOf(id, 50 + k) % 100) < 40 then
                named = true
                of = LOST_NAMES[(hashOf(id, 60 + k) % #LOST_NAMES) + 1]
            end
            -- Day zero ([A29]): a county that starts BEFORE the
            -- fall has no apocalypse lessons to seed - these pasts
            -- are pre-outbreak lives. The grammar still shaped their
            -- trait echoes (who they are); what the world TEACHES
            -- begins when the world starts teaching. Era is per
            -- person: the first witnessed horror writes the first
            -- lesson through the machinery that already exists.
            local dz = SandboxVars and SandboxVars.SurvivorAwareness
                and SandboxVars.SurvivorAwareness.DayZero == true
            if SAO.Lessons and not dz then
                SAO.Lessons.learn(id, pick.key, weight, src, of)
            end
            -- [B48] What the draw actually drew.
            --
            -- The operator's session settled forty-nine pasts and every
            -- single one of them was `doors-decide-lives`. Seven
            -- entries in the grammar, one of which (`claimed-places-bite`)
            -- fits EVERYBODY and so is in every pool ever built - and it
            -- came up not once.
            --
            -- Simulating this loop over the same id range gives a
            -- healthy spread across all seven, so the source as written
            -- does not explain it, and four batches of reading that log
            -- did not either. The draw is the county's most
            -- characterful decision and there has never been an
            -- instrument on it: the only way anyone found out was by
            -- noticing the same string forty-nine times by eye.
            --
            -- One counted line per key per flush, which [B47] made
            -- affordable. The next session says what the draw does.
            tally("settled '" .. tostring(pick.key) .. "'")
        end
    end
    rec.traitEchoes = echoes
    -- [B47] Once per person. The numbers differ per person and that
    -- is exactly why printing them 234 times told nobody anything;
    -- the count is the readable part.
    tally("history read")
end

-- Rendering, at read time only: terse claim lines, never chapters.
function H.describe(id)
    local rec = SAO.Identity.get(id)
    if not rec then return "no record" end
    local alive = tostring(rec.monthsAlive or rec.epistemicMonths or "?")
    local contact = tostring(rec.contactMonths or rec.epistemicMonths or "?")
    local head = alive .. " months out there, " .. contact .. " in company."
    -- [B39] Rendered at read time, never stored - the claims-not-
    -- chapters law. A war is one clause, not a biography.
    local war = nil
    pcall(function() war = H.servedIn(id, rec.occupation) end)
    if war then
        head = head .. " " .. war .. ", a long time ago."
    end
    -- [B41] What they kept.
    --
    -- `rec.keepsake` has always held the item's full type - the bridge
    -- writes `item.getFullType()` for anything in the Memento category
    -- or carrying IS_MEMENTO - and the one consumer tested truthiness,
    -- so the county knew somebody was carrying SOMETHING and never
    -- what.
    --
    -- The engine supplies the readable name and nothing else. There is
    -- no field saying who a memento was of, so nothing here says: the
    -- object is named and the meaning is left where it belongs, with
    -- whoever is looking at them.
    local kept = nil
    pcall(function()
        if rec.keepsake then
            local it = getScriptManager():getItem(tostring(rec.keepsake))
            local nm = it and it:getDisplayName() or nil
            if nm and nm ~= "" then kept = nm end
        end
    end)
    if kept then
        head = head .. " Still carrying " .. kept .. "."
    end
    if not SAO.Lessons then
        return head
    end
    local rendered = SAO.Lessons.renderClaims(id)
    if rendered == "" then
        return head .. " Nothing settled yet."
    end
    return head .. " " .. rendered
end

-- [B38] Who two people in a unit are to each other.
--
-- [B37] gave everybody an age and left it reading nowhere. This is
-- what reads it. A unit records only what KIND it is - family,
-- friends, mixed - and the specific relation falls out of the ages
-- the two already have, because choosing the relation and then
-- choosing ages to match would be authoring the same fact twice.
--
-- Sixteen years is the gap that separates a generation from a
-- household: below it two family members are of an age with each
-- other, above it one of them raised the other. Partner or sibling is
-- settled by the hash of the PAIR - a fact about the two of them,
-- stable across sessions, the same way every other fact here is
-- settled.
local GENERATION_GAP = 16

function H.relationIn(aId, bId, kind)
    if not aId or not bId or aId == bId then return nil end
    kind = tostring(kind or "mixed")
    if kind == "friends" then return "friend" end
    if kind ~= "family" then return "companion" end

    local ageA, ageB = H.ageOf(aId), H.ageOf(bId)
    if math.abs(ageA - ageB) >= GENERATION_GAP then
        return (ageA > ageB) and "parent" or "child"
    end
    -- Ordered so both sides ask the same question of the same pair.
    local first = (tostring(aId) < tostring(bId)) and aId or bId
    local second = (first == aId) and bId or aId
    local pair = tostring(first) .. "+" .. tostring(second)
    if coinOf(pair, "kin") == 0 then return "partner" end
    return "sibling"
end

-- The pair's relation as the OTHER one would put it. A parent's child
-- is a child; a partner's partner is a partner.
function H.relationBack(relation)
    if relation == "parent" then return "child" end
    if relation == "child" then return "parent" end
    return relation
end

log("history module loaded (clock at "
    .. string.format("%.1f", H.clockMonths()) .. " months)")

return H
