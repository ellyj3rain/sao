-- SAO_Population — durable world inhabitants (ARCHITECTURE §Population).
-- ---------------------------------------------------------------------------
-- Survivors are inhabitants of the map, not a refill effect around the
-- player. New identities originate from the map's REAL spawn-region point
-- tables (F-005; shape verified from shipped source: regions[i] = { name,
-- points = { profession -> { {posX,posY,posZ}, ... } } }) — region-balanced,
-- at real houses in real towns, wherever the player happens to be. The
-- player-band governs only which records carry live BODIES, because engine
-- cells exist only near players; a distant survivor is dormant where they
-- are, not absent.
--
-- Death is durable: dead records stay as death records, corpses belong to
-- the engine, and the world refills a loss only after the configured days —
-- at a spawn region, never at the site of the loss, never near the player.
--
-- Every number here is a sandbox option; nothing is hardcoded policy.

SAO = SAO or {}
SAO.Population = SAO.Population or {}
local Pop = SAO.Population

local TICK_INTERVAL = 240   -- population cadence, in county ticks;
                            -- DayLength determines its wall-clock duration.

-- [C112] Read from the county's clock every pass, never incremented -
-- the quantized law lives in SAO_History.ticks. The local stays for
-- the fallback frame axis a session needs when SAO_History did not
-- load, which [C62] already says out loud is a dead county.
local tickCounter = 0
-- [C112] The last tick a population pass ran at - the cadence law's
-- stamp (last fired plus a span, never a modulo, which a clock that
-- can skip values would step straight over).
local lastPassAt = nil
local booted = false
-- [C17] The crowd ledger's session cursor: the bridge counts pool
-- takes monotonically per session; this remembers how many were
-- already folded into the durable ledger.
local poolTakenSeen = 0
-- [C17] How many taken zombies restitution returns per daily pulse.
-- A pace, not a quota: a late enable repays accumulated history at a
-- walk instead of dumping it into one night.
local RESTITUTION_PER_DAY = 6

-- [B47] One door out. `log` is what happened once; `tally` is
-- what happens once per person, counted rather than printed.
local function log(msg) SAO.Log.line("POP", msg) end
local function tally(kind) SAO.Log.tally("POP", kind) end

-- [B33] Said once, not every tick: cfg() runs inside populationTick.
local radiusWarned = false

local function cfg()
    local sv = SandboxVars and SandboxVars.SurvivorAwareness or nil
    -- [B33] These two are a hysteresis PAIR, not two free dials.
    -- `materializeBand` reads them as opposite ends of one band, in
    -- one if/elseif chain: a shell is built at d <= materialize and
    -- torn down at d > hibernate. The gap between them is the band
    -- where neither branch fires and the world holds still.
    --
    -- Invert them and that band becomes a thrash zone. The tick that
    -- builds a shell makes hasBody true, which arms the branch that
    -- tears it down, which makes hasBody false again - so a survivor
    -- standing in it flickers for exactly as long as they stand
    -- there. The options screen declares the two independently and
    -- has no way to express a constraint across them, so the pair is
    -- reconciled here.
    --
    -- The TIGHTER dial carries the intent. Someone pulling hibernate
    -- down wants a smaller live county, so materialize follows it
    -- down - rather than hibernate being quietly pushed back up to a
    -- number they did not choose.
    local mat = (sv and tonumber(sv.MaterializeRadius)) or 45
    local hib = (sv and tonumber(sv.HibernateRadius)) or 70
    local MIN_GAP = 10
    if hib < mat + MIN_GAP then
        local wasMat, wasHib = mat, hib
        mat = hib - MIN_GAP
        if mat < 20 then
            mat = 20
            hib = mat + MIN_GAP
        end
        if not radiusWarned then
            radiusWarned = true
            log("the radii left no still band (" .. wasMat .. "/"
                .. wasHib .. "); holding them apart at " .. mat .. "/"
                .. hib .. " so nobody flickers")
        end
    end
    return {
        enable = sv == nil or sv.Enable ~= false,
        -- [C12] Representation is not implementation (DR-017): the
        -- screen offers a worded switch and a plain number, and the
        -- INTERNAL sentinel (0 = derive from the map, the DR-008
        -- schema default) is manufactured here and only here. An old
        -- world that wrote a number into the sentinel-era dial should
        -- flip the new switch to keep governing it.
        population = (sv and sv.PopulationGoverned == true)
            and ((tonumber(sv.Population)) or 216) or 0,
        -- [B28] The ceiling arrivals may raise the county TO.
        -- Equal to or below population means a closed county:
        -- the number you start with is the number there is.
        -- [C12] Same shape: ungovered follows population 3:1
        -- downstream, spelled internally as the 0 sentinel.
        newcomers = (sv and sv.NewcomersGoverned == true)
            and ((tonumber(sv.Newcomers)) or 500) or 0,
        -- [B29] How many walk together when the road brings
        -- anyone. The month is unchanged; this is magnitude,
        -- which [B28] settled is the honest knob because how
        -- many people are walking is not a fact about us.
        roadTraffic = (sv and tonumber(sv.RoadTraffic)) or 2,
        -- [B33] How hard the country outside is pushing. Not a
        -- schedule and not a second magnitude: it scales how much the
        -- month shortens as the sky stays quiet. [C12] The screen
        -- says it in words (six steps); this is where the word
        -- becomes the scalar the road maths always ran on - step 1
        -- leaves the month exactly as it was, which is what an
        -- untouched world gets.
        roadPressure = (((sv and tonumber(sv.RoadPressureStep)) or 1) - 1),
        materialize = mat,
        hibernate = hib,
        refillDays = (sv and tonumber(sv.RefillDays)) or 2.0,
    }
end

local function playerPos()
    local p = getSpecificPlayer(0)
    if not p then return nil end
    return p:getX(), p:getY(), p:getZ()
end

local function hoursNow()
    local ok, h = pcall(function() return SAO.History.countyHours() end)
    return ok and h or 0
end

-- [C62] The county's clock is one module's answer now, and every
-- system in this file that gates on a change of day reads it through
-- a pcall that answers zero when it cannot be reached. A zero here
-- is not a small wrong number: it is a clock that never moves, which
-- is exactly the defect [C62] was written to fix, and it would be
-- silent.
--
-- So it is asked once, at boot, and said out loud if it is not
-- there. The seam is marked dark for the same reason - the Ledger is
-- the only place a player would ever find this out ([B33]).
local clockSaid = false
local function clockAnswers()
    if clockSaid then return end
    clockSaid = true
    local ok, h = pcall(function() return SAO.History.countyHours() end)
    if ok and type(h) == "number" then return end
    log("THE COUNTY HAS NO CLOCK: SAO.History.countyHours() cannot be"
        .. " reached, so every day-gated system in this file - the"
        .. " attrition roll, thirst and hunger, the softening of old"
        .. " feelings - reads hour zero forever and none of them will"
        .. " ever see a new day. SAO_History.lua did not load.")
    if SAO.Seams then
        SAO.Seams.wentDark("county-clock",
            "SAO.History.countyHours() is not reachable")
    end
end

-- Population owns cadence; each responsibility receives this pass's time.
local function ensurePopulation(conf)
    return SAO.PopulationAdmissions.ensurePopulation(conf, tickCounter)
end
local function genesisSettled() return SAO.PopulationAdmissions.genesisSettled() end
local function resolveTarget(conf) return SAO.PopulationAdmissions.resolveTarget(conf) end
local function loadRegionPoints() return SAO.PopulationAdmissions.loadRegionPoints() end
local function materializeBand(px, py, conf)
    return SAO.PopulationRepresentation.materializeBand(px, py, conf)
end
local function inhabitKnox() return SAO.PopulationRepresentation.inhabitKnox() end
local function dormantLife(conf) return SAO.DormantPopulation.dormantLife(conf, tickCounter) end
local function dormantAttrition() return SAO.DormantPopulation.dormantAttrition(tickCounter) end
local function dormantSettle() return SAO.DormantPopulation.dormantSettle() end
local function consumeProvisioningResults()
    if SAO.Provisioning and SAO.Provisioning.consumeCompleted then
        return SAO.Provisioning.consumeCompleted(32)
    end
end
local function dormantProvision() return SAO.DormantPopulation.dormantProvision() end
local function dormantEncounters() return SAO.DormantPopulation.dormantEncounters(tickCounter) end

-- Compatibility entry points retain the callers' existing contract.
function Pop.captureBodyFacts(...) return SAO.PhysicalFacts.captureBodyFacts(...) end
function Pop.commitBodyFacts(...) return SAO.PhysicalFacts.commitBodyFacts(...) end
function Pop.refreshBodyFacts(...) return SAO.PhysicalFacts.refreshBodyFacts(...) end
function Pop.companyNeedPressure(id) return SAO.DormantPopulation.companyNeedPressure(id) end
function Pop.forgetPairs(id) return SAO.DormantPopulation.forgetPairs(id) end
function Pop.tradeGroundFor(path) return SAO.PopulationAdmissions.tradeGroundFor(path) end

local subFaults = {}
local function runSub(name, fn, a, b, c)
    if (subFaults[name] or 0) >= 3 then return end
    local ok, err = pcall(fn, a, b, c)
    if not ok then
        subFaults[name] = (subFaults[name] or 0) + 1
        log("subsystem '" .. name .. "' fault " .. subFaults[name]
            .. "/3: " .. tostring(err))
        if subFaults[name] >= 3 then
            log("subsystem '" .. name .. "' DISABLED for this session")
            -- [B33] Permanent for this session, so the Ledger says so.
            if SAO.Seams then
                SAO.Seams.wentDark(name, err)
            end
        end
    end
end

-- [B47] The boot digest ([A22]): the console opens with the state
-- of the world.
--
-- It used to run at the TOP of the tick, before genesis, and the
-- operator's own log caught what that means:
--
--     [SAO][POP] day 1: 0 living, 0 dead, 0 companies, 0 at war
--                       / target 0 (sandbox-governed)
--
-- Two hundred and thirty-four people were created moments later. On a
-- new world the digest is structurally guaranteed to describe an empty
-- county, because the county has not been made yet - a report that
-- cannot be wrong because it never looks.
--
-- And `target 0` is worse than useless: 0 is the sandbox default
-- meaning "size it from the map" ([B38]), and the digest printed the
-- raw option instead of the resolved number. The one line meant to say
-- what world you are in said this mod is configured to create nobody,
-- which is the most alarming thing it could say and was false.
local function bootDigest(conf)
    local okH2, h2 = pcall(function()
        return SAO.History.countyHours()
    end)
    local day = okH2 and math.floor(h2 / 24) or 0
    local dead = 0
    for _, r in pairs(SAO.Identity.all()) do
        if r.dead then dead = dead + 1 end
    end
    local groupSet = {}
    local wars = 0
    for _, r in pairs(SAO.Identity.all()) do
        if not r.dead then
            local g = SAO.Standing.groupOf(r.id)
            if g and not groupSet[g] then
                groupSet[g] = true
                for g2 in pairs(groupSet) do
                    if g2 ~= g and SAO.Standing.feudBetween(g, g2) then
                        wars = wars + 1
                    end
                end
            end
        end
    end
    local companies = 0
    for _ in pairs(groupSet) do companies = companies + 1 end
    -- [B38] The county once a day, beside the event stream.
    if SAO.Telemetry and SAO.Telemetry.county then
        pcall(SAO.Telemetry.county)
    end
    log("day " .. day .. ": " .. SAO.Identity.livingCount()
        .. " living, " .. dead .. " dead, " .. companies
        .. " companies, " .. wars .. " at war / target "
        .. tostring(resolveTarget(conf))
        .. ((conf.population and conf.population > 0)
            and " (sandbox-governed)" or " (sized from the map)"))
    -- [C17] Restitution, on the same daily pulse (DR-021's state
    -- agreement). The ledger is the truth regardless of the dial:
    -- every body the pool took is counted durable. The dial decides
    -- whether the county RESTORES them - one virtual zombie on
    -- unloaded town ground per body taken, capped per day so a late
    -- enable repays history at a walk, never as a dump; placed far
    -- from you, jittered off the town point, through the engine's
    -- own addVirtualZombie (javap: static (int,int)). The layer only
    -- ever repays the ledger's debt - it invents no bodies the pool
    -- did not take (the derived totals stay unratified until the
    -- census has measured, DR-021).
    pcall(function()
        local ledger = ModData.getOrCreate("SurvivorAwareness_CrowdLedger")
        ledger.taken = ledger.taken or 0
        ledger.added = ledger.added or 0
        if SAOJavaBridge then
            local n = tonumber(SAOJavaBridge:poolTakenCount()) or 0
            local delta = n - (poolTakenSeen or 0)
            poolTakenSeen = n
            if delta > 0 then ledger.taken = ledger.taken + delta end
        end
        local on = false
        pcall(function()
            on = SandboxVars.SurvivorAwareness.RestoreTakenZombies == true
        end)
        if not on then return end
        local owed = ledger.taken - ledger.added
        if owed <= 0 then return end
        local points = loadRegionPoints()
        if not points or #points == 0 then return end
        local px, py = playerPos()
        local placed = 0
        local tries = 0
        while placed < math.min(owed, RESTITUTION_PER_DAY)
            and tries < 40 do
            tries = tries + 1
            local pt = points[SAO.Rand.int(#points) + 1]
            if pt and pt.x and pt.y then
                local far = true
                if px and py then
                    local dx, dy = pt.x - px, pt.y - py
                    far = (dx * dx + dy * dy)
                        > conf.hibernate * conf.hibernate
                end
                if far then
                    addVirtualZombie(
                        math.floor(pt.x) + SAO.Rand.int(21) - 10,
                        math.floor(pt.y) + SAO.Rand.int(21) - 10)
                    placed = placed + 1
                end
            end
        end
        if placed > 0 then
            ledger.added = ledger.added + placed
            log("restitution: " .. placed .. " of " .. owed
                .. " taken zombies returned to town ground")
        end
    end)
    -- [B33] Whether combat actually installed. The melee gate
    -- needs Instrumentation, which the shipping load path gets by
    -- self-attaching; when that fails the gate stays shut and
    -- SAOCombat refuses to start. That was reported only to a log
    -- FILE, so a world where survivors could never swing looked
    -- exactly like a world where they simply had not yet - and
    -- the bridge already had the question, with nothing asking it.
    pcall(function()
        if not SAOJavaBridge then return end
        if SAOJavaBridge:isCombatPatchReady() then return end
        log("combat is NOT armed on this build: the melee gate did"
            .. " not install, so survivors will not swing."
            .. " Everything else runs.")
    end)
end

-- [B47] The band is the only subsystem behind a bare `if`. Everything
-- else runs through runSub, which counts its own faults and marks a
-- seam dark so the Ledger says so; this one just does not happen, and
-- nothing anywhere says why. `playerPos()` is nil through every
-- loading screen, which is ordinary - so this reports once, when it
-- has been nil long enough to mean something other than "still
-- loading", and then never again.
local bandSkips = 0
local bandSaid = false
local BAND_PATIENCE = 15   -- population passes before reporting the absence

-- [C45] THE YEARS BETWEEN.
--
-- A save that begins in 1996 has three years of county behind it,
-- and DR-036 says the people the player meets are the people who
-- lived them. So the county's own machinery runs forward over those
-- days before anybody is materialised - the same dormant day, the
-- same meetings on the road, the same attrition, the same softening
-- of old feelings, the same table that kills the old - and whoever
-- is alive at the end of it is who the player walks into.
--
-- Nothing here is a second simulation and nothing is authored. Every
-- call below is the one the live county already makes; houses,
-- leaders, feuds and pacts arrive because `dormantEncounters` forms
-- them, exactly as it does in play.
--
-- Catch-up runs the same 240-tick dormant pass as the live county.
-- A calendar day contains 24 county hours, each of 9000 ticks. The
-- wall-clock budget limits a slice; it never changes the simulated cadence.
-- F-055 records the cost of this fidelity. Each slice may exceed its budget
-- by one indivisible population pass, never by the remainder of the years.
local YEARS_BUDGET_MS = 60

local function yearsStore()
    local ok, s = pcall(function()
        return ModData.getOrCreate("SurvivorAwareness_Standing")
    end)
    return (ok and type(s) == "table") and s or nil
end

-- How many days this save begins with behind it, asked once and
-- remembered. Zero is a real answer (a 1993 start has no years to
-- catch up on) and so the flag, not the number, says whether it has
-- been asked.
local function yearsOwed(s)
    if s.yearsAsked then return tonumber(s.yearsOwed) or 0 end
    -- [C63] Through SAO_History, which is the one place that reads
    -- the day-zero switch. Asked the bridge directly, this remembered
    -- a number the record's own timeline disagreed with, and it
    -- remembers it for the life of the save.
    local days = -1
    pcall(function() days = SAO.History.daysOwed() end)
    if type(days) ~= "number" or days < 0 then
        -- The clock was not there yet; ask again next pass rather
        -- than recording a nothing that would stand for the save.
        return nil
    end
    s.yearsAsked = true
    s.yearsOwed = days
    s.yearsRun = 0
    s.yearsTicks = 0
    if days > 0 then
        log("this save begins " .. days .. " days after the fall; the"
            .. " county will live them before anybody is spawned")
    end
    return days
end

-- [C46] THE GROUND, LOOKED AT WHILE THE YEARS RUN.
--
-- The years are lived with nobody materialised, so no claim's
-- ground is loaded and the county knows nothing about the places it
-- holds. The operator ruled the years run for real rather than
-- being recorded and dressed on arrival, and F-055 measured the
-- ground a whole county's households stand on at 432 chunks and
-- 406 KB, which is nothing. So the ground is loaded, one claim a
-- simulated day on a rotation, and what is there is kept on the
-- record of the person who holds it.
--
-- READ ONLY, and the Java side says why at length: a barricade is
-- not added and no chunk is saved, because saving writes into the
-- player's own save directory and nothing here has a live receipt
-- yet. What this buys is a county that knows what its places are
-- like; doing something about them is the next piece.
--
-- One a day, because that is the rotation a day deserves and it
-- keeps the whole span's ground cost proportional to the days
-- rather than to the county.
-- How long a reading stands before that ground is worth another
-- look. A month of simulated days: long enough that a small
-- county does not re-read the same yard on the rotation, short
-- enough that a place changing over years is noticed.
local GROUND_STALE_DAYS = 30

local function lookAtSomeGround(day)
    if not SAOJavaBridge then return end
    local holders = {}
    for id, rec in pairs(SAO.Identity.all()) do
        if not rec.dead then
            local claim = nil
            pcall(function() claim = SAO.Standing.claimOf(id) end)
            -- Ground read recently is not read again: a small county
            -- comes round the rotation often, and looking at the same
            -- yard three days running costs chunks and learns nothing.
            -- This is what `groundSeenOnDay` is for.
            local seen = tonumber(rec.groundSeenOnDay)
            local stale = (not seen) or (day - seen) >= GROUND_STALE_DAYS
            if claim and stale then
                holders[#holders + 1] = { id = id, claim = claim }
            end
        end
    end
    if #holders == 0 then return end
    local pick = holders[(day % #holders) + 1]
    local said = ""
    pcall(function()
        said = tostring(SAOJavaBridge:surveyClaim(pick.claim.minX,
            pick.claim.minY, pick.claim.maxX, pick.claim.maxY,
            pick.claim.z or 0))
    end)
    local ways = tonumber(said:match("ways=(%d+)"))
    local boarded = tonumber(said:match("boarded=(%d+)"))
    if not ways then return end
    local rec = SAO.Identity.get(pick.id)
    if not rec then return end
    -- What their place is: the ways into it, and how many of those
    -- are already shut. Facts about ground that was actually read.
    rec.waysIntoHome = ways
    rec.boardedAtHome = boarded or 0
    rec.groundSeenOnDay = day
end

-- [C65] The county line, once a day.
--
-- [B38] wrote "the county once a day, laid beside the events rather
-- than instead of them" and wired it into `bootDigest`, which runs on
-- the first population tick of a session and never again. So it was
-- once per load for the whole B era and the sentence describing it
-- was wrong.
--
-- It is daily now, on the county's own clock ([C62]), which means the
-- years pass drives it exactly as the live county does rather than
-- reaching for something only the years need.
local function dailyCounty()
    local day = math.floor(hoursNow() / 24.0)
    local s = yearsStore()
    if not s or s.lastCountyDay == day then return end
    local previousDay = tonumber(s.lastCountyDay)
    s.lastCountyDay = day
    -- Age and habits settle an elapsed day before its observations. The
    -- first partial day establishes the clock; it does not consume a day.
    -- Persisting that baseline also prevents a reload from ageing twice.
    if previousDay and day > previousDay then
        for id, rec in pairs(SAO.Identity.all()) do
            pcall(function() SAO.Age.dailyRoll(rec, day, tickCounter) end)
            pcall(function() SAO.Age.settleHabits(rec, day) end)
        end
    end
    pcall(function() SAO.Telemetry.county() end)
    -- [C65] twice over. The pathogen's day and the world's day-graph
    -- moved in behind the same gate the county line already was,
    -- because until they did they were called only from the simulated
    -- day - which Border 118 refused, and it was right: the live
    -- county's carriers would never have advanced and the world graph
    -- would never have been written, so the machinery the player met
    -- in a mature county was three years of work the living county
    -- itself had never once run. The years call this same function,
    -- and the day it computes here is the county's own - during the
    -- years `hoursNow` reads the day being lived, so the number is
    -- the simulated day itself, and across the boundary it is
    -- continuous with it.
    pcall(function() SAO.PathogenEvents.simulateDay(day) end)
    -- [C74] Dated lived claims become available only after their record day.
    -- This same daily pulse drives historical catch-up and live play, so a
    -- July 1 start cannot know July 2 early and a mature county retains the
    -- acquisition it actually lived.
    pcall(function()
        if SAO.WorldKnowledge and SAO.WorldKnowledge.advanceAll then
            SAO.WorldKnowledge.advanceAll(hoursNow())
        end
    end)
    -- [C116] The reverted come back on the same clock the pathogen's
    -- own day runs - after the advance, so a reversion this day's
    -- draw produced is taken back the same day, and the years pass
    -- drives the return exactly as the live county does.
    pcall(function()
        if SAO.AfflictedReturn and SAO.AfflictedReturn.adopt then
            SAO.AfflictedReturn.adopt(day)
        end
        if SAO.AfflictedReturn and SAO.AfflictedReturn.stampLive then
            SAO.AfflictedReturn.stampLive(day)
        end
    end)
    -- [C117] The cast-out and the gather on the same clock: after the
    -- return and the marks, standing's own daily question - the
    -- groupless afflicted taking the abandoned ground they have
    -- walked to. The years pass drives it exactly as the live county
    -- does, the [C65] law.
    pcall(function()
        if SAO.Standing and SAO.Standing.outcastDrift then
            SAO.Standing.outcastDrift()
        end
    end)
    -- [C119] The government's answer on the same clock: the draw, the
    -- strike, the fallout - one pass, gated on its own dial (default
    -- off) and its own world-persisted fate, so the years pass drives
    -- a struck county exactly as the live one does, the [C65] law.
    pcall(function()
        if SAO.Nuke and SAO.Nuke.onDay then SAO.Nuke.onDay() end
    end)
    pcall(function() SAO.WorldGenesis.applyDay(day) end)
end

-- One dormant pass, in one order, for catch-up and for the live county.
local function dormantCountyPass(conf)
    runSub("dormant-life", dormantLife, conf)
    runSub("attrition", dormantAttrition)
    runSub("drift", function() SAO.Standing.driftStandings() end)
    runSub("settle", dormantSettle)
    runSub("provision-results", consumeProvisioningResults)
    runSub("provision", dormantProvision)
    runSub("encounters", dormantEncounters)
    runSub("digest", dailyCounty)
end

local function oneYearsStep(conf, day, newDay)
    dormantCountyPass(conf)
    if newDay then
        pcall(lookAtSomeGround, day)
    end
end

-- Returns true while there are still years to live, which is what
-- holds the band back: nobody is materialised into a county that has
-- not finished happening.
local function runTheYears(conf)
    local s = yearsStore()
    if not s then return false end
    if not genesisSettled() then
        -- The county has to exist before it can have a history
        -- ([C41]); genesis runs ahead of this in the same pass.
        return true
    end
    local owed = yearsOwed(s)
    if owed == nil then return true end
    local run = tonumber(s.yearsRun) or 0
    if run >= owed then return false end

    -- [C65] The run this span's lines belong to.
    --
    -- Made once and kept in the save, because a span sliced across
    -- hundreds of passes and possibly a reload is ONE run, and a
    -- fresh identifier per pass would cut a single county's history
    -- into two thousand runs of one day each. Restored rather than
    -- regenerated on every entry for the same reason.
    if s.yearsRunId == nil then
        local stamp = 0
        pcall(function() stamp = getTimestampMs() end)
        s.yearsRunId = tostring(math.floor(stamp)) .. "-"
            .. tostring(SAO.Rand.int(100000))
        pcall(function()
            SAO.Telemetry.runId = s.yearsRunId
            local c = SAO.Telemetry.conditions()
            c.run = s.yearsRunId
            c.owed = owed
            SAO.Telemetry.run("opened", c)
        end)
    else
        pcall(function()
            if SAO.Telemetry.runId == nil then
                SAO.Telemetry.runId = s.yearsRunId
            end
        end)
    end

    local okT, startedMs = pcall(function() return getTimestampMs() end)
    local ticksADay = SAO.History.TICKS_PER_DAY
    local ticks = tonumber(s.yearsTicks) or (run * ticksADay)
    local targetTicks = owed * ticksADay
    local began = run
    while ticks < targetTicks do
        local priorDay = math.floor(ticks / ticksADay)
        ticks = math.min(targetTicks, ticks + TICK_INTERVAL)
        s.yearsTicks = ticks
        run = math.floor(ticks / ticksADay)
        -- Keep the elapsed clock active through the last pass. The completed
        -- day stamp is committed after its work, including at the boundary.
        tickCounter = ticks
        oneYearsStep(conf, run, run > priorDay)
        s.yearsRun = run
        lastPassAt = tickCounter
        -- Without a wall clock take one step only; a missing timer must not
        -- turn a bounded slice into an unbounded loop.
        if not okT or type(startedMs) ~= "number" then break end
        local okN, nowMs = pcall(function() return getTimestampMs() end)
        if not okN or type(nowMs) ~= "number"
            or nowMs - startedMs >= YEARS_BUDGET_MS then break end
    end
    if run >= owed then
        local alive = SAO.Identity.livingCount()
        log("the county has lived its " .. owed .. " days: " .. alive
            .. " alive to meet")
        -- [C65] The run is closed and the identifier cleared, so the
        -- play that follows is not filed under a run that has ended.
        pcall(function()
            SAO.Telemetry.run("closed",
                { run = s.yearsRunId, owed = owed, lived = run,
                  living = alive })
        end)
        -- Cleared in its own guard: a throw in the line above must not
        -- leave live play filed under a span of years that has ended.
        pcall(function() SAO.Telemetry.runId = nil end)
        return false
    end
    if run - began > 0 then
        log("the county is living the years: " .. run .. "/" .. owed
            .. " days")
    end
    return true
end

local function populationTick()
    local conf = cfg()
    if not conf.enable then return end
    -- Establish the historical clock before genesis writes any timestamps.
    -- A pending span runs on every host callback: its clock is advanced by
    -- the work below and cannot be gated on the future save-start clock.
    local ys = yearsStore()
    local owed = ys and yearsOwed(ys) or nil
    local pending = owed and (tonumber(ys.yearsRun) or 0) < owed
    do
        local okT, t = pcall(function() return SAO.History.ticks() end)
        tickCounter = (okT and type(t) == "number") and t
            or (tickCounter + 1)
    end
    if not pending
        and tickCounter - (lastPassAt or -TICK_INTERVAL) < TICK_INTERVAL then
        return
    end
    lastPassAt = tickCounter
    local booting = not booted
    booted = true
    -- [C62] Before anything reads it.
    clockAnswers()

    -- The county does not stop for anyone's death ([A17]): genesis,
    -- dormant days, and road meetings run playerless; only the presence
    -- band needs somebody to be present around.
    -- Bulkheads ([A21]): each subsystem behind its own pcall and
    -- fault counter - a broken seam disables ITSELF after 3 faults;
    -- the rest of the county keeps moving. The names make the log
    -- legible at a glance.
    runSub("returns", function()
        if SAO.AfflictedReturn then SAO.AfflictedReturn.resumePending() end
    end)
    runSub("genesis", ensurePopulation, conf)
    -- [C45] The years between, before anything else. While they are
    -- still being lived the live subsystems below are skipped - the
    -- years are already driving every one of them - and the band is
    -- held, so nobody is materialised into a county that has not
    -- finished happening.
    local livingTheYears = pending == true
    runSub("years", function()
        livingTheYears = runTheYears(conf)
    end)
    if livingTheYears then return end
    runSub("inhabit", inhabitKnox)
    for _, rec in pairs(SAO.Identity.all()) do
        SAO.Body.recover(rec)
    end
    if not pending then dormantCountyPass(conf) end
    local px, py = playerPos()
    if px then
        bandSkips = 0
        runSub("band", materializeBand, px, py, conf)
    else
        bandSkips = bandSkips + 1
        if bandSkips >= BAND_PATIENCE and not bandSaid then
            bandSaid = true
            log("nobody to stand near: the presence band has been"
                .. " skipped " .. bandSkips .. " passes running because"
                .. " getSpecificPlayer(0) returns nothing, so no body"
                .. " will be built until that changes")
        end
    end

    -- [B47] Last, not first. The digest describes the county, and
    -- until the subsystems above have run on a new world there is no
    -- county to describe.
    if booting then pcall(bootDigest, conf) end
end

-- Fault gate.
local popFaults = 0
local function onTick()
    local ok, err = pcall(populationTick)
    if ok then return end
    popFaults = popFaults + 1
    if popFaults == 1 then log("tick fault: " .. tostring(err)) end
    if popFaults >= 3 then
        Events.OnTick.Remove(onTick)
        log("population disabled after " .. popFaults .. " faults")
        -- [B33] The whole module, not one seam: the county stops
        -- growing, ageing and meeting anyone, and the Ledger is the
        -- only place a player would ever find that out.
        if SAO.Seams then
            SAO.Seams.wentDark("population", err)
        end
    end
end

function Pop.rebindWorld()
    tickCounter, lastPassAt, booted = 0, nil, false
    poolTakenSeen, radiusWarned, clockSaid = 0, false, false
    subFaults, popFaults = {}, 0
    bandSkips, bandSaid = 0, false
    SAO.PopulationAdmissions.rebindWorld()
    SAO.DormantPopulation.rebindWorld()
    -- A previous world's fault gate may have detached this callback.
    Events.OnTick.Remove(onTick)
    Events.OnTick.Add(onTick)
end

if Pop.onTick then Events.OnTick.Remove(Pop.onTick) end
Pop.onTick = onTick
Events.OnTick.Add(Pop.onTick)
if Events.OnInitGlobalModData then
    if Pop.onInitGlobalModData then
        Events.OnInitGlobalModData.Remove(Pop.onInitGlobalModData)
    end
    Pop.onInitGlobalModData = function() Pop.rebindWorld() end
    Events.OnInitGlobalModData.Add(Pop.onInitGlobalModData)
end

log("population module loaded")

return Pop
