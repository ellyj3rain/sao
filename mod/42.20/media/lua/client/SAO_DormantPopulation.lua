-- DormantPopulation - advancement of records without loaded bodies.

SAO = SAO or {}
SAO.DormantPopulation = SAO.DormantPopulation or {}
local D = SAO.DormantPopulation
local function log(msg) SAO.Log.line("POP", msg) end
local function tally(kind) SAO.Log.tally("POP", kind) end
local function hoursNow()
    local ok, h = pcall(function() return SAO.History.countyHours() end)
    return ok and h or 0
end

local function pickOriginFor(path) return SAO.PopulationAdmissions.tradeGroundFor(path) end
local function biteWindowHours() return SAO.PhysicalFacts.biteWindowHours() end
-- Dormant life (sanctioned unloaded-world simulation): a dormant survivor
-- is not a statue. On a slow per-person cadence their RECORD position
-- drifts - by day toward a waypoint in their home's wider neighborhood, by
-- night toward home itself. Coarse on purpose: a few tiles a minute, no
-- pathfinding, no walls - the abstraction of a person going about a day,
-- not a hidden puppet. Drift near the player's band simply means the band
-- pass materializes them: someone wanders past your camp because they
-- were WALKING somewhere, not because a spawner owed you an encounter.
-- [B37] Where a day goes.
--
-- It used to go to `homeX + SAO.Rand.int(-24, 25)`: a coordinate, not a
-- place. The county's own map has always known where the buildings
-- are and what their rooms are called, and the mod had never read it
-- once - so a day can now go somewhere that HAS something rather than
-- somewhere that is merely elsewhere.
--
-- Belief-gated exactly as [A20] gates avoidance: they still bend away
-- from ground they KNOW belongs to a company theirs is feuding with,
-- and nobody dodges a camp they never heard of.
--
-- Returns nil out in the wilderness, where there is nothing to walk to
-- and the old drift is the honest answer.
local UNVISITED = 1000000

-- [B37] How long somebody goes before the going stops being a choice.
--
-- These are days, and they are the real ones: a person is in trouble
-- after about three days without water and about three weeks without
-- food. That ratio is a fact about bodies, not a dial - which is why
-- it is written here as days rather than tuned. The engine agrees
-- with the shape of it (`ZomboidGlobals.thirstIncrease` outruns
-- `hungerIncrease` by an order), but its rates are per-frame and this
-- clock is per-day, so the honest anchor is the body rather than a
-- scaled engine constant.
--
-- Nothing here simulates a stomach. What is tracked is a fact the
-- county already produces: the last day they actually REACHED
-- somewhere with water or food in it. Need is derived from where
-- they have been, which is the only way they could know it too.
-- [C79] How often a bad encounter is survived rather than fatal, for
-- somebody with no advantages at all. Divided by how well they handle
-- danger, so the capable get away from more of them. OURS: the engine
-- settles this on a loaded body's own damage and there is no body in
-- the dormant county, so no figure in the build establishes it.
local ESCAPE_BASE = 0.30

local THIRST_PATIENCE = 2
local HUNGER_PATIENCE = 7
-- The distance each need actually has to run before it kills. These
-- are what make thirst and hunger COMPARABLE: a day without water
-- costs seven times what a day without food does, so the two are
-- weighed as fractions of their own fuse rather than as raw days.
local THIRST_LETHAL = 3
local HUNGER_LETHAL = 21
-- Desperation outranks curiosity by construction: a person two days
-- dry is not exploring the county, they are looking for water.
local DESPERATE = 10000000

-- [B39] The line the county already draws.
--
-- `Desperation` is read nine times in SAO_Controller and zero times
-- here. So a LIVE survivor respects a claim until hunger or thirst
-- passes the threshold and then takes anyway - the sandbox option
-- says exactly that: "The hunger or thirst level past which survival
-- overrides property" - while the two hundred DORMANT ones had no
-- notion of anybody's property at all, and walked into a neighbour's
-- kitchen every day forever.
--
-- One threshold, both halves of the county, each in its own units: a
-- live body reads a 0..1 need off the engine, and a dormant one has
-- [B37]'s days-without measured against the distance that need has
-- to run before it kills.
-- [C25] How far a day can reach: knowledge, not a dial (DR-027).
--
-- [B39] pointed the ErrandRadius option at this path to cure a
-- live/dormant asymmetry, and the operator then ruled the option
-- itself a lie about what it measured: "They're operating off of
-- social structures and social incentives and personal desires and
-- understanding and awareness. It's not, oh, you can move within a
-- radius of twelve." So the dial is gone from the screen entirely,
-- and a dormant day reaches as far as the county's own derived
-- horizons: the home neighborhood (half the engine's own cell) for
-- a day of ordinary living, and need past patience cutting ahead of
-- curiosity to the nearest KNOWN place that offers the thing -
-- searched from where they stand, committed to by desperation, the
-- same law the loaded half walks in the controller.

local function desperationLine()
    local sv = SandboxVars and SandboxVars.SurvivorAwareness or nil
    return (sv and tonumber(sv.Desperation)) or 0.7
end

local function daysWithout(rec, field, today)
    local last = rec[field]
    if last == nil then return 0 end
    return math.max(0, today - last)
end

-- The person's own shortage beyond the same patience their next errand
-- reads. Standing uses this pressure without inspecting a house's stores.
function D.companyNeedPressure(id)
    local rec = SAO.Identity and SAO.Identity.get(id)
    if not rec or rec.dead then return 0 end
    local body = SAO.Body and SAO.Body.get(id)
    local dry, hungry = 0, 0
    if body then
        local need = SAO.Needs and SAO.Needs.read(body)
        if not need or not SAO.Disposition then return 0 end
        local thirstAt = SAO.Disposition.drinkAt(id)
        local hungerAt = SAO.Disposition.eatAt(id)
        dry = (tonumber(need.thirst) or 0) / thirstAt - 1
        hungry = (tonumber(need.hunger) or 0) / hungerAt - 1
    else
        local today = math.floor(hoursNow() / 24.0)
        dry = daysWithout(rec, "lastWaterDay", today) / THIRST_PATIENCE - 1
        hungry = daysWithout(rec, "lastFoodDay", today) / HUNGER_PATIENCE - 1
    end
    return math.max(0, math.min(1, math.max(dry, hungry)))
end

-- Whether a place is off limits to this person today: feud ground
-- always, somebody else's believed claim until desperation. One
-- function because [C25] gave the county two choosers - need and
-- curiosity - and two copies of a law is how they drift apart.
local function placeBarred(id, myG, b, place, desperate)
    if myG then
        for eg, fb in pairs((b and b.factions) or {}) do
            if eg ~= myG
                and SAO.Standing.feudBetween(myG, eg)
                and place.cx >= fb.minX - SAO.Standing.FEUD_DETOUR
                and place.cx <= fb.maxX + SAO.Standing.FEUD_DETOUR
                and place.cy >= fb.minY - SAO.Standing.FEUD_DETOUR
                and place.cy <= fb.maxY + SAO.Standing.FEUD_DETOUR then
                return true
            end
        end
    end
    -- [B39] Somebody else's ground. Belief-gated, like every other
    -- claim in this mod: a survivor who does not KNOW a place is
    -- held walks into it, and the one who knows respects it right up
    -- until the county's own desperation line, and then does not.
    if not desperate then
        local held = nil
        pcall(function()
            held = SAO.Perception.believesClaimed(id, place.cx, place.cy)
        end)
        if held and held ~= id then return true end
    end
    return false
end

-- [C72] Somebody worth the day.
--
-- Every term here is a fact the county already produces about this
-- person. Nothing is enumerated and nothing is scheduled.
--
--   * WHO IS A CANDIDATE is whoever they believe is somewhere, which
--     until [C71] was nobody at all. A belief comes from having stood
--     next to them; no survivor knows where anyone is for any other
--     reason, so knowledge is the whole of the reach (DR-027 - how
--     far a person GOES is knowledge and desire, never a radius).
--   * WHETHER THEY ARE WORTH IT is the trust already between them
--     against the county's own company line, which is the trust at
--     which two people would keep house. Somebody you would live
--     with is somebody you would cross town to see, and reusing that
--     line means the operator's dial moves both together. [C111]
--     added this person's own need on top of the trust - appetite,
--     isolation, and the county's openness - so the lonely go
--     looking before trust alone would carry them, by the same law
--     the formation doors hold.
--   * WHICH ONE is the one they most want to see that they can most
--     plausibly find: trust over the age of the sighting. An address
--     a week old is where somebody was, not where they are.
--   * WHETHER THEY SET OUT AT ALL is `initiative`, which Disposition
--     glosses as self-starts rather than waits. This is the one
--     decision in a dormant day that nothing outside prompts, so it
--     is the trait's plainest use. A hesitant person goes some days
--     and not others; nobody is barred and nobody is scheduled.
--
-- A belief they have already walked to and found nobody at is not
-- knowledge any more, and is skipped until a fresh sighting revives
-- it - the same discipline [C25] set for a known place that did not
-- pan out, which exists so nobody re-orders the same doorstep
-- forever.
local function chooseWhoToGoTo(id, rec, myG, b, desperate)
    if not (b and b.people) then return nil end
    local sv = SandboxVars and SandboxVars.SurvivorAwareness or nil
    local companyAt = (sv and tonumber(sv.TrustToCompany)) or 0.5
    local today = math.floor(hoursNow() / 24.0)
    local best, bestRank = nil, nil
    for key, pb in pairs(b.people) do
        -- Somebody believed to be where this person is standing is not
        -- somewhere to go. It is also what keeps a genesis belief
        -- durable: people who came through the first night together
        -- believe each other to be at the home they were both standing
        -- in, so on the first day there is nothing to walk to and the
        -- belief is not spent - and a month later, when the day's
        -- roaming has carried them apart, that same address is exactly
        -- where to look. The tolerance is the one `dormantLife` uses
        -- to decide a goal has been reached; a shorter one would send
        -- somebody on a walk they have already finished.
        local near = pb.x and pb.y
            and math.abs(rec.x - pb.x) < 3 and math.abs(rec.y - pb.y) < 3
        if not pb.dead and pb.x and pb.y and not near
            and not (pb.lookedAt and pb.at and pb.lookedAt >= pb.at) then
            local other = pb.id or SAO.Identity.idByName(key)
            local orec = other and SAO.Identity.get(other) or nil
            if orec and not orec.dead and other ~= id
                and not SAO.Standing.isHostileTo(id, other)
                and not placeBarred(id, myG, b,
                    { cx = pb.x, cy = pb.y }, desperate) then
                local trust = SAO.Standing.trust(id, other) or 0
                -- [C111] The gate reads the pair standing (trust plus
                -- this person's own pull, zeroed where trust is
                -- already spent against the candidate); the RANK
                -- below stays pure trust over sighting age, because
                -- the pull is the same for every candidate and orders
                -- nobody.
                if SAO.Standing.companyStanding(id, other)
                    >= companyAt then
                    local since = 0
                    if pb.atHours then
                        since = math.max(0,
                            today - math.floor(pb.atHours / 24.0))
                    end
                    local rank = trust / (1.0 + since)
                    if not bestRank or rank > bestRank then
                        best, bestRank = key, rank
                    end
                end
            end
        end
    end
    if not best then return nil end
    -- Asked once there is somebody to ask it about, so a survivor who
    -- knows of nobody spends no draw and the county's own sequence
    -- ([C66]) is not moved by a decision that was never available.
    local initiative = 0
    pcall(function()
        initiative = SAO.Disposition.traits(id).initiative or 0
    end)
    if SAO.Rand.unit() >= initiative then return nil end
    local pb = b.people[best]
    return { x = pb.x, y = pb.y, person = best, seenAt = pb.at }
end

-- [C72] Where the day goes. Named for what it answers now: the goal
-- may be a place or it may be a person, and until this batch a
-- dormant survivor had no way to decide to go to anybody. Every
-- meeting in the county was two need-driven walks coinciding within
-- three tiles.
local function chooseDayGoal(id, rec, reach, tickCounter)
    if not (SAO.Places and rec.homeX) then return nil end

    local myG = SAO.Standing.groupOf(id)
    local b = SAO.Perception.beliefs[id]

    -- [B37] What they have gone without, in days, derived from where
    -- they have actually been.
    local today = math.floor(hoursNow() / 24.0)
    local dry = daysWithout(rec, "lastWaterDay", today)
    local hungry = daysWithout(rec, "lastFoodDay", today)

    -- [B39] How far along they are, on the same 0..1 the live path
    -- compares against. Hard-won lessons move the line for the
    -- dormant exactly as they do for the loaded ([A19]).
    local urgency = math.max(dry / THIRST_LETHAL, hungry / HUNGER_LETHAL)
    local line = desperationLine()
    pcall(function()
        line = line + (SAO.Lessons.desperationBump(id) or 0)
    end)
    local desperate = urgency >= line

    -- [C25] Need cuts ahead of curiosity (DR-027). Past patience,
    -- the day goes to the nearest KNOWN place offering the pressing
    -- thing - searched from where they STAND, because knowledge
    -- moves with the walker - reaching past the neighborhood only
    -- when desperation commits them. Thirst outranks hunger on the
    -- one scale both are measured on: how far along the way to
    -- dying of it somebody is.
    local needOffer = nil
    if dry > THIRST_PATIENCE or hungry > HUNGER_PATIENCE then
        local offer = "food"
        if dry > THIRST_PATIENCE
            and (dry / THIRST_LETHAL) >= (hungry / HUNGER_LETHAL) then
            offer = "water"
        end
        needOffer = offer
        local okN, known = pcall(SAO.WorldSources.nearestBelieved,
            id, rec.x or rec.homeX, rec.y or rec.homeY, offer,
            desperate and SAO.Places.commitHorizon()
                or SAO.Places.comfortHorizon())
        if okN and known
            and not placeBarred(id, myG, b, known, desperate) then
            return { x = known.cx, y = known.cy, placeId = known.id,
                sourceNeed = offer }
        end
    end

    -- [C113] Before somebody, in an ordinary county: the trade's
    -- ground. Week One's street occupations, ported - the mail
    -- carrier on a postal round, the gardener out with the beds, are
    -- in their mod SPAWN-SIDE weights on a zombie spawner, and none
    -- of that crosses; what crosses is the idea re-expressed on this
    -- ontology's own fact - the census already decided who is what
    -- trade, and a person's trade already has ground filed under the
    -- engine's own profession path ([A18], `pickOriginFor`). So an
    -- ordinary day's second-priority walk, behind need and ahead of
    -- company, is TO WORK: a stable workplace picked once from the
    -- trade's own filed points and kept - a commuter does not re-apply
    -- for a different office every morning. A person the county
    -- anchored at their trade ground at genesis ([A18]) already lives
    -- where they work, and the near-check below sends them straight
    -- through to the social life [C72] built; a person with no filed
    -- trade ground falls through the same way. Nobody is barred from
    -- company by having a job - the next branch stands.
    --
    -- Gated by the county's own fall ([C42]): `fallHasCome` is read
    -- from the record's stamps, never the dial, and once it has come
    -- this branch is dead and the chooser is exactly what it was -
    -- need, then somebody, then places.
    if not needOffer then
        local fallen = true
        pcall(function() fallen = SAO.Standing.fallHasCome() end)
        if not fallen then
            local row = rec.occupation
                and SAO.Census.rowOf(rec.occupation) or nil
            if row and row.enginePath then
                if not (rec.workX and rec.workY) then
                    local w = pickOriginFor(row.enginePath)
                    if w then rec.workX, rec.workY = w.x, w.y end
                end
                if rec.workX and rec.workY
                    and (math.abs((rec.x or rec.homeX) - rec.workX) >= 3
                        or math.abs((rec.y or rec.homeY) - rec.workY) >= 3)
                    and not placeBarred(id, myG, b,
                        { cx = rec.workX, cy = rec.workY }, desperate) then
                    return { x = rec.workX, y = rec.workY }
                end
            end
        end
    end

    -- [C72] Need first, and then somebody. Thirst outranks company:
    -- a person two days dry is not visiting anybody. Past that, going
    -- to somebody cuts ahead of curiosity for the same reason need
    -- does ([C25]) - it is a decision about a thing that matters
    -- rather than about ground they have not seen.
    local who = not needOffer
        and chooseWhoToGoTo(id, rec, myG, b, desperate) or nil
    if who then return who end

    local ok, places = pcall(function()
        return SAO.Places.around(rec.homeX, rec.homeY, reach)
    end)
    if not ok or not places or #places == 0 then return nil end

    local best, bestScore
    for _, place in ipairs(places) do
        -- Room vocabulary says only that this ground is worth exploring.
        -- Exact availability is learned on arrival from WorldSources.
        local possible = place.offers or {}
        local anyPossible = false
        for _ in pairs(possible) do anyPossible = true; break end
        if anyPossible and (not needOffer or possible[needOffer]) then
            local barred = placeBarred(id, myG, b, place, desperate)
            if not barred then
                -- Somewhere never seen beats anywhere already seen,
                -- because that is where the county is still unknown to
                -- them; among those it is arbitrary, so that two
                -- survivors sharing a home do not walk in step. Among
                -- places they DO know, the one longest unseen wins.
                local age = SAO.Perception.placeAge(id, place.id,
                    tickCounter)
                local score
                if age then
                    score = math.min(age, UNVISITED - 1)
                else
                    score = UNVISITED + SAO.Rand.int(100000)
                end
                -- [B37] and then need overrides all of it.
                --
                -- The two are compared on ONE scale: how far along the
                -- way to dying of it somebody is. Counting raw days
                -- gets this backwards - twenty days hungry outnumbers
                -- four days dry and would send a man dying of thirst
                -- to look for a sandwich. Against the distance each
                -- one actually has to run, four days without water is
                -- past lethal and twenty days without food is not
                -- quite there. A place offering both is worth both.
                local urgency = 0
                if dry > THIRST_PATIENCE and possible.water then
                    urgency = urgency
                        + math.floor(100 * dry / THIRST_LETHAL)
                end
                if hungry > HUNGER_PATIENCE and possible.food then
                    urgency = urgency
                        + math.floor(100 * hungry / HUNGER_LETHAL)
                end
                score = score + DESPERATE * urgency
                if not bestScore or score > bestScore then
                    best, bestScore = place, score
                end
            end
        end
    end
    if not best then return nil end
    return { x = best.cx, y = best.cy, placeId = best.id,
        sourceNeed = needOffer }
end

-- Arrival can now establish exact native stock, but it cannot manufacture the
-- missing actor-specific access/action proof. A bodyless record has no source
-- floor, path, locked-door result, permission, carried item or native Eat/
-- DrinkFluid completion. The observation enters private belief and the need
-- remains unsatisfied until that executor exists. nil means the engine was busy
-- and this observation goal must be retained for a retry.
local function arriveAtPlace(id, rec, place, tickCounter)
    local complete, why = SAO.WorldSources.demandPlace(place)
    local category = rec.dayGoalSourceNeed
    if not complete then
        if why == "BUSY" or why == "busy" then return nil end
        return false, why
    end
    -- Only a complete building-bounded observation can replace private
    -- belief. A busy/failed partial pass leaves unvisited chunks unknown.
    SAO.Perception.learnBuilding(id, place, tickCounter, "observed")
    if not category then return true end
    return false, "access-unproven"
end

local function sourceOwnsDormantRecord(id)
    if SAO.WorldSources and SAO.WorldSources.ownsActor then
        return SAO.WorldSources.ownsActor(id) == true
    end
    return SAO.WorldSources and SAO.WorldSources.pendingActionFor
        and SAO.WorldSources.pendingActionFor(id) ~= nil or false
end

local function groupHasSourceOwner(group)
    if not (group and SAO.Standing and SAO.Standing.membersOf) then
        return false
    end
    for _, memberId in ipairs(SAO.Standing.membersOf(group)) do
        if sourceOwnsDormantRecord(memberId) then return true end
    end
    return false
end

-- Build 42.20's loaded awake law, expressed per game hour. The bridge
-- derives this from ZomboidGlobals and the current StatsDecrease sandbox
-- multiplier. The literal is the installed default (0.0000345 * 3600) and
-- keeps the non-agent fallback on the same clock.
local DEFAULT_AWAKE_FATIGUE_PER_HOUR = 0.1242
local SLEEP_THRESHOLD = 0.2
local RESTED_THRESHOLD = 0.000001

local function finite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function acquireDormantPhysiology(rec)
    local fatigue = tonumber(rec.dormantFatigue)
    local endurance = tonumber(rec.dormantEndurance)
    local sleepNeed = tonumber(rec.dormantSleepNeed)
    if rec.dormantPhysiologyOrigin and finite(fatigue) and finite(endurance)
        and finite(sleepNeed) and fatigue >= 0 and fatigue <= 1
        and endurance >= 0 and endurance <= 1 and sleepNeed > 0 then
        return fatigue, endurance, sleepNeed, rec.dormantPhysiologyOrigin
    end
    if rec.hibernation ~= nil and SAOJavaBridge
        and SAOJavaBridge.hibernationRestState then
        local ok, access = pcall(function()
            return SAOJavaBridge:hibernationRestState(rec.hibernation)
        end)
        if ok then
            fatigue, endurance, sleepNeed = SAO.BodySnapshot.restValues(access)
            if fatigue then
                return fatigue, endurance, sleepNeed, "native-snapshot"
            end
        end
        -- A legacy or invalid snapshot is not an empty body. It stays
        -- unknown until a supported native capture supplies measurements.
        return nil
    end
    if rec.hibernation == nil
        and rec.dormantPhysiologyOrigin == "generated-default" then
        return 0.0, 1.0, 1.0, "generated-default"
    end
    return nil
end

local function awakeFatigueBase()
    local base = DEFAULT_AWAKE_FATIGUE_PER_HOUR
    if SAOJavaBridge and SAOJavaBridge.dormantAwakeFatiguePerHour then
        local ok, measured = pcall(function()
            return SAOJavaBridge:dormantAwakeFatiguePerHour()
        end)
        if ok and finite(measured) and measured > 0 then base = measured end
    end
    return base
end

local function dormantAtHome(id, rec)
    local x, y = tonumber(rec.x), tonumber(rec.y)
    local hx, hy = tonumber(rec.homeX), tonumber(rec.homeY)
    if x and y and hx and hy and math.abs(x - hx) < 3
        and math.abs(y - hy) < 3 then return true end
    local ok, inside = pcall(function()
        return SAO.Standing.insideClaim(id, x, y)
    end)
    return ok and inside == true
end

local function restWindow(atHours)
    local hour = atHours % 24.0
    return hour >= 22.0 or hour < 6.0
end

local function nextRestBoundary(atHours)
    local hour = atHours % 24.0
    if hour < 6.0 then return atHours + (6.0 - hour) end
    if hour < 22.0 then return atHours + (22.0 - hour) end
    return atHours + (30.0 - hour)
end

local function advanceRestState(fatigue, endurance, sleepNeed, hours,
        sleeping, resting, fatigueBase)
    if sleeping then
        return math.max(0, fatigue - hours / 8.0),
            math.min(1, endurance + hours / 4.0)
    end
    local enduranceFactor = math.max(0.3, 1.0 - endurance)
    local restFactor = resting and 1.5 or 1.0
    local rate = fatigueBase * enduranceFactor * sleepNeed / restFactor
    return math.min(1, fatigue + hours * rate), endurance, rate
end

-- One durable physiology interval. Unknown legacy state is not defaulted;
-- native capture or explicit generated provenance must first supply it.
local function advanceDormantPhysiology(id, rec, nowHours, fatigueBase)
    local fatigue, endurance, sleepNeed, origin = acquireDormantPhysiology(rec)
    if not fatigue then return false end
    local last = tonumber(rec.dormantPhysiologyAtHours)
    if not finite(last) or last < 0 or last > nowHours then
        rec.dormantPhysiologyOrigin = origin
        rec.dormantFatigue = fatigue
        rec.dormantEndurance = endurance
        rec.dormantSleepNeed = sleepNeed
        rec.dormantPhysiologyAtHours = nowHours
        return true
    end
    if nowHours == last then return true end

    local sleeping = rec.dormantSleeping
    if sleeping ~= true and sleeping ~= false then sleeping = nil end
    local resting = rec.dormantResting == true
    local atHome = dormantAtHome(id, rec)
    local cursor = last
    while cursor < nowHours do
        local inWindow = restWindow(cursor)
        if not inWindow then
            -- Six o'clock is an action boundary, not an inference from an
            -- absent flag: the bodyless owner actually wakes the person.
            sleeping, resting = false, false
        elseif sleeping == true then
            resting = true
        elseif atHome then
            resting = true
            sleeping = fatigue > SLEEP_THRESHOLD
        else
            resting = false
        end

        local finish = math.min(nowHours, nextRestBoundary(cursor))
        local span = finish - cursor
        if sleeping == true then
            if fatigue <= RESTED_THRESHOLD then
                sleeping = false
            else
                local untilWake = (fatigue - RESTED_THRESHOLD) * 8.0
                span = math.min(span, untilWake)
                fatigue, endurance = advanceRestState(fatigue, endurance,
                    sleepNeed, span, true, true, fatigueBase)
                cursor = cursor + span
                if span >= untilWake - 0.0000001 then sleeping = false end
            end
        elseif sleeping == nil then
            -- Night away from known shelter provides no evidence of sleep or
            -- wakefulness. Spend the interval without manufacturing either.
            cursor = finish
        else
            local _, _, rate = advanceRestState(fatigue, endurance,
                sleepNeed, 0, false, resting, fatigueBase)
            if inWindow and atHome and fatigue <= SLEEP_THRESHOLD then
                local untilSleep = (SLEEP_THRESHOLD + 0.000001 - fatigue) / rate
                span = math.min(span, untilSleep)
            end
            fatigue, endurance = advanceRestState(fatigue, endurance,
                sleepNeed, span, false, resting, fatigueBase)
            cursor = cursor + span
            if inWindow and atHome and fatigue > SLEEP_THRESHOLD then
                sleeping = true
            end
        end
    end

    -- A boundary at exactly this pass happens before the encounter pass.
    if not restWindow(nowHours) then
        sleeping, resting = false, false
    elseif sleeping == true then
        resting = true
        if fatigue <= RESTED_THRESHOLD then sleeping = false end
    elseif atHome then
        resting = true
        sleeping = fatigue > SLEEP_THRESHOLD
    else
        resting = false
    end

    rec.dormantPhysiologyOrigin = origin
    rec.dormantFatigue = fatigue
    rec.dormantEndurance = endurance
    rec.dormantSleepNeed = sleepNeed
    rec.dormantPhysiologyAtHours = nowHours
    rec.dormantSleeping = sleeping
    rec.dormantResting = resting and true or nil
    return true
end

local function dormantLife(conf, tickCounter)
    SAO.WorldSources.reconcileReservations()
    -- [C62] The county's hour, not the engine's. This runs once
    -- per simulated day while [C45] lives the years and the
    -- engine's clock is stopped, so a save begun at night sent
    -- everybody home for the whole span.
    local hour = SAO.History.countyTimeOfDay()
    if type(hour) ~= "number" then return end
    local night = hour >= 21.0 or hour < 6.0
    local okHours, nowHours = pcall(function()
        return SAO.History.countyHours()
    end)
    if not okHours or not finite(nowHours) or nowHours < 0 then return end
    local fatigueBase = awakeFatigueBase()
    -- [C113] An ordinary county, in the county's own words. The
    -- street law only runs where the county says so: `fallHasCome`
    -- answers with its REASON, and "before" - the record's calendar
    -- exists and the fall is not on it - is the only county whose
    -- streets these are. "unknown" (no calendar readable) is not
    -- before; a county that cannot say when its fall is gets the
    -- survival law, not a street crowd it may not have earned.
    local preFall = false
    do
        local okF, fallen, why = pcall(function()
            return SAO.Standing.fallHasCome()
        end)
        preFall = okF and fallen == false and why == "before"
    end
    for id, rec in pairs(SAO.Identity.all()) do
        if not rec.dead and not SAO.Claims.isHeld(rec)
            and not SAO.Body.hasRepresentation(id)
            and not sourceOwnsDormantRecord(id) then
            advanceDormantPhysiology(id, rec, nowHours, fatigueBase)
            if SAO.Standing.maybeCallForBread then
                SAO.Standing.maybeCallForBread(id)
            end
            -- Acquired matters remain thoughts a dormant person can appraise;
            -- physical work still waits for a represented body. Any answer
            -- stays private until a later admitted encounter reaches its
            -- originator.
            if SAO.Controller and SAO.Controller.appraiseCoordination then
                SAO.Controller.appraiseCoordination(id, nil, "dormant")
            end
            if rec.homeX then
                rec.nextDormantMoveAt = rec.nextDormantMoveAt or 0
                -- [C112] This is the one persisted FUTURE due-time in the
                -- county, and a stamp written by an older build counted
                -- FRAMES - a number that can read as years ahead on the
                -- county's axis and would stall a walker forever. This
                -- field is only ever set to now + at most 3600, so
                -- anything further ahead than that is not of this domain:
                -- it is dropped, and the move is due now. One reload's
                -- reset per old save, then never again.
                if rec.nextDormantMoveAt > tickCounter + 3600 then
                    rec.nextDormantMoveAt = 0
                end
                -- An exact loaded action cannot become a bodyless approximation.
                -- Keep its record still until representation returns and the
                -- durable phase reconstructs against the carried item/source.
                if rec.dormantSleeping ~= true
                    and tickCounter >= rec.nextDormantMoveAt then
                    rec.nextDormantMoveAt = tickCounter + 1800 + SAO.Rand.int(1800)
                    local tx, ty
                    if night and not preFall then
                        tx, ty = rec.homeX, rec.homeY
                    else
                        if not rec.dayGoalX
                            or (math.abs(rec.x - rec.dayGoalX) < 3
                                and math.abs(rec.y - rec.dayGoalY) < 3) then
                            -- [C25] The day reaches the home
                            -- neighborhood - the county's derived
                            -- horizon, not a dial (DR-027). Need can
                            -- reach further inside chooseDayPlace.
                            local reach = SAO.Places.comfortHorizon()
                            -- [B37] Arriving is learning. The goal just
                            -- reached was a real building, so they now
                            -- know it is there and what it holds - the
                            -- only thing the operator allows them to know
                            -- off the road, and learned by being there
                            -- rather than read off a registry.
                            -- Only the ID goes on the record, which is
                            -- persisted; the place itself is re-read from
                            -- the map cache. Hanging a nested table off a
                            -- saved record would put the whole county in
                            -- every save file.
                            -- [C72] They went to where they last saw
                            -- somebody, and got there. Whether it paid off
                            -- is whether they have seen that person SINCE
                            -- they set out - the encounter pass writes a
                            -- fresh sighting the moment two people are
                            -- within meeting range, so a stamp that has
                            -- not moved means the address was empty.
                            --
                            -- An address that was empty stops being the
                            -- answer until a fresh sighting revives it,
                            -- which is [C25]'s rule for a known place that
                            -- did not pan out: without it somebody
                            -- re-orders the same doorstep every day
                            -- forever. Marking it on arrival regardless
                            -- would spend the belief of a person they had
                            -- just found.
                            if rec.dayGoalPerson then
                                pcall(function()
                                    local b2 = SAO.Perception.beliefs[id]
                                    local pb = b2 and b2.people
                                        and b2.people[rec.dayGoalPerson]
                                    if pb and (pb.at or 0)
                                        <= (rec.dayGoalSeenAt or 0) then
                                        pb.lookedAt = tickCounter
                                    end
                                end)
                            end
                            local retainSourceGoal = false
                            if rec.dayGoalPlaceId then
                                local okArrival, arrival = pcall(function()
                                    local arrived = SAO.Places.at(
                                        rec.dayGoalX, rec.dayGoalY)
                                    if arrived
                                        and arrived.id == rec.dayGoalPlaceId then
                                        return arriveAtPlace(id, rec, arrived,
                                            tickCounter)
                                    end
                                    return true
                                end)
                                retainSourceGoal = okArrival and arrival == nil
                            end
                            -- [C113] The street roll, at the leg
                            -- boundary - the one moment a decision is
                            -- actually being made, not every move gate
                            -- (a gate opens every dozen county minutes;
                            -- rolling there would churn a person between
                            -- home and street hourly at any affinity under
                            -- one). A person who has just ARRIVED, or has
                            -- no leg yet, rolls Week One's street hour:
                            -- out means the day-goal chooser answers
                            -- (work, somebody, places - the ordinary
                            -- errand), staying in means the next leg is
                            -- home, and home it stays until a later leg
                            -- rolls out. The night rule above no longer
                            -- holds pre-fall: the authored curve itself
                            -- thins the small hours (0.20, 0.15, 0.10,
                            -- 0.05, 0.05) and keeps the evening streets
                            -- fed (0.90, 0.70, 0.40) - which is the open
                            -- street the slice asked for, in the shape
                            -- its prior art authored.
                            local out = true
                            if preFall then
                                local affinity =
                                    SAO.History.streetAffinity(hour)
                                out = (affinity ~= nil)
                                    and (SAO.Rand.unit() < affinity)
                            end
                            local chosen = (not retainSourceGoal and out)
                                and chooseDayGoal(id, rec, reach, tickCounter) or nil
                            if retainSourceGoal then
                                -- The engine was between chunk operations. The
                                -- reservation and destination remain owned by this
                                -- person and the next dormant pass retries it.
                            elseif chosen then
                                rec.dayGoalX, rec.dayGoalY = chosen.x, chosen.y
                                rec.dayGoalPlaceId = chosen.placeId
                                rec.dayGoalSourceNeed = chosen.sourceNeed
                                -- [C72] All three are written every
                                -- time, so yesterday's subject cannot
                                -- survive into today's walk.
                                rec.dayGoalPerson = chosen.person
                                rec.dayGoalSeenAt = chosen.seenAt
                            elseif out then
                                -- Wilderness, or a neighbourhood whose
                                -- every place is enemy ground. Nothing to
                                -- walk to, so the old drift stands.
                                rec.dayGoalX = rec.homeX
                                    + SAO.Rand.int(-reach, reach + 1)
                                rec.dayGoalY = rec.homeY
                                    + SAO.Rand.int(-reach, reach + 1)
                                rec.dayGoalPlaceId = nil
                                rec.dayGoalSourceNeed = nil
                                rec.dayGoalPerson = nil
                                rec.dayGoalSeenAt = nil
                            else
                                -- Staying in: the leg is home, and the
                                -- goal machinery above is skipped
                                -- entirely - an evening in is an evening
                                -- in, not a failed errand.
                                rec.dayGoalX, rec.dayGoalY =
                                    rec.homeX, rec.homeY
                                rec.dayGoalPlaceId = nil
                                rec.dayGoalSourceNeed = nil
                                rec.dayGoalPerson = nil
                                rec.dayGoalSeenAt = nil
                            end
                        end
                        tx, ty = rec.dayGoalX, rec.dayGoalY
                    end
                    -- [C75] The clock is read on every pass, whether or
                    -- not there is anywhere to walk. Reading it only when
                    -- somebody moves would let a person standing at their
                    -- goal BANK the hours and then cross the county in one
                    -- stride the moment they were given a new one, which
                    -- is not walking. Idle time is spent, not saved.
                    local nowH = hoursNow()
                    local sinceH = 0
                    if rec.lastWalkHours then
                        sinceH = math.max(0, nowH - rec.lastWalkHours)
                    end
                    rec.lastWalkHours = nowH
                    local dx, dy = tx - rec.x, ty - rec.y
                    local len = math.sqrt(dx * dx + dy * dy)
                    if len > 1.0 then
                        -- [C75] How far the walking gets them, as a RATE
                        -- over the county's own clock rather than a fixed
                        -- number of tiles per pass.
                        --
                        -- It was `math.min(4, len)`, a constant per pass,
                        -- and a pass means two different things in the two
                        -- halves of the county. Live, `dormantLife` runs
                        -- every 240 county ticks ([C112]; it was frames)
                        -- and a move gate opens every
                        -- 1800 to 3600, so a game day holds hundreds of
                        -- them. In the years, `[C45]` calls this once per
                        -- simulated day, so a day held exactly one
                        -- move - four tiles.
                        -- Measured: 1.8 tiles per person per simulated day
                        -- (F-061), against a map fifteen thousand tiles
                        -- wide with towns hundreds of tiles apart.
                        --
                        -- The rate is not a figure chosen here. `[C25]`
                        -- ratified `comfortHorizon` as the home
                        -- neighbourhood, reached by a day of ordinary
                        -- living, and it derives from the engine's own
                        -- cell quantum (`getCellSizeInSquares`). So a day
                        -- of walking reaches it, half a day reaches half
                        -- of it, and a goal further off takes the days it
                        -- takes - nobody is capped, and where they go is
                        -- still decided by need and knowledge.
                        --
                        -- The pace of the age scales it, the same
                        -- modifier `[C30]` already sets on a live body:
                        -- short legs and old ones both walk slower.
                        --
                        -- Both halves read one rule, which is the law
                        -- ([B39], [B42]) - and the years keep `[C45]`'s
                        -- cost, because a day's distance is covered in
                        -- one pass rather than a day's passes.
                        local pace = 1.0
                        pcall(function()
                            pace = SAO.History.speedModOf(id) or 1.0
                        end)
                        local perDay = SAO.Places.comfortHorizon()
                        local step = math.min(len,
                            perDay * pace * (sinceH / 24.0))
                        rec.x = math.floor(rec.x + dx / len * step + 0.5)
                        rec.y = math.floor(rec.y + dy / len * step + 0.5)
                    end
                    -- A day's walking teaches places ([A15]): drifting past a
                    -- held claim leaves the coarse knowledge a passerby would
                    -- have - the dormant learn the county too.
                    -- [B42] The rule itself now lives in Perception and
                    -- both halves read it. It was written here, inside a
                    -- loop that gates on `not SAO.Body.hasRepresentation(id)`, so only
                    -- the UNLOADED could ever learn whose ground they were
                    -- walking on - including [B35]'s wiring for the
                    -- player's own claim, which meant a survivor standing
                    -- in the player's house could never learn it was
                    -- theirs. Same rule, both halves ([B39], [B39]).
                    pcall(function()
                        SAO.Perception.learnGroundNear(id, rec.x, rec.y)
                    end)
                end
            end
        end
    end
end

-- The county collects ([A20], DR-011): dormant life carries a small
-- daily risk - the tax binds the unwatched too. Modulated by what the
-- operator named load-bearing: hard claims held, class, company,
-- seasoning. A death out there has no corpse and no witness; WORD
-- finds the bonded and the company a day or two later, at told
-- weight, through the existing news machinery. Sandbox DormantRisk
-- scales it; 0 disables.
-- Word finds them: past-due news of a death reaches the bonded and the
-- company, once.
--
-- [C71] Lifted out of the attrition pass, which returns before
-- anything when `DormantRisk` is zero. That dial means the county
-- stops collecting; a death that has already happened is not part of
-- the risk, and turning the dial down left every pending notice
-- undelivered for the life of the save.
--
-- What it tells them is keyed by the person and written through
-- Perception's own verb. It read `rec.forename` - the sentinel for
-- anybody the county has never materialised, so the whole county's
-- dead shared one belief slot and each death overwrote the last - and
-- it wrote into `P.beliefs[hearer]` without opening one, so the news
-- reached nobody who had never been told anything by anybody. In a
-- dormant county that is nearly everybody.
local function deliverDeathNews(nowHours, tickCounter)
    for id, rec in pairs(SAO.Identity.all()) do
        if rec.dead and rec.deathNewsAt and not rec.deathNewsDelivered
            and nowHours >= rec.deathNewsAt then
            rec.deathNewsDelivered = true
            local hearers = {}
            local bondedKey = SAO.Standing.bondedWith(id)
            if bondedKey then hearers[bondedKey] = true end
            -- [C71] The house they died in, by name. This asked
            -- `fellowsOf(id)`, which reads the roster - and [C68]
            -- takes a corpse off the roster at the moment of death,
            -- so by the time the news is due a dead person has no
            -- fellows and the company half of "word finds the bonded
            -- and the company" had reached nobody since. The record
            -- keeps the house it died in, written by the same verb
            -- that removes the row.
            for _, fid in ipairs(SAO.Standing.membersOf(
                    rec.diedInGroup or SAO.Standing.groupOf(id))) do
                hearers[fid] = true
            end
            local key = SAO.Identity.beliefKey(rec)
            for hearer in pairs(hearers) do
                pcall(function()
                    SAO.Perception.learnOfDeath(hearer, key,
                        rec.x, rec.y, tickCounter, rec.turnedDormant)
                end)
            end
            log("word finds the county: " .. id .. " never came back")
        end
    end
end

local function dormantAttrition(tickCounter)
    local okNews, newsHours = pcall(function()
        return SAO.History.countyHours()
    end)
    if okNews then deliverDeathNews(newsHours, tickCounter) end
    local sv = SandboxVars and SandboxVars.SurvivorAwareness or nil
    local riskMult = sv and tonumber(sv.DormantRisk) or 1.0
    if riskMult <= 0 then return end
    -- Winter bites ([A24]): the county is harder in the cold months.
    -- Engine month (0-11): Dec/Jan/Feb x1.5, Nov/Mar x1.25, else x1.0.
    pcall(function()
        local month = SAO.History.countyMonth()
        if month == 11 or month == 0 or month == 1 then
            riskMult = riskMult * 1.5
        elseif month == 10 or month == 2 then
            riskMult = riskMult * 1.25
        end
    end)
    local okH, nowHours = pcall(function()
        return SAO.History.countyHours()
    end)
    if not okH then return end
    local today = math.floor(nowHours / 24.0)
    -- The pact kept, dormant mirror ([A26]): a bread-poor house in
    -- pact with a bread-rich one eats through the winter - the
    -- abstract bread arrives. Shapes computed once per pass.
    local pactFed = {}
    do
        local shapes = {}
        local function shapeOf(g)
            if shapes[g] == nil then
                shapes[g] = SAO.Standing.groupShape
                    and SAO.Standing.groupShape(g) or false
            end
            return shapes[g] or nil
        end
        for _, rec0 in pairs(SAO.Identity.all()) do
            if not rec0.dead then
                local g0 = SAO.Standing.groupOf(rec0.id)
                if g0 and pactFed[g0] == nil then
                    pactFed[g0] = false
                    local ally0 = SAO.Standing.pactPartnerOf
                        and SAO.Standing.pactPartnerOf(g0) or nil
                    if ally0 then
                        local mine = shapeOf(g0)
                        local theirs = shapeOf(ally0)
                        if mine and theirs
                            and mine.forageShare < 0.2
                            and theirs.forageShare >= 0.2 then
                            pactFed[g0] = true
                        end
                    end
                end
            end
        end
    end
    for id, rec in pairs(SAO.Identity.all()) do
        if rec.dead then
            -- Nothing here: word of a death is delivered above, before
            -- the risk dial can silence it.
        elseif not SAO.Claims.isHeld(rec) and not SAO.Body.hasRepresentation(id)
            and not sourceOwnsDormantRecord(id) then
            -- [B37] A world that predates this batch has never
            -- recorded either of these, and somebody who has "never"
            -- drunk must not start dying the day it lands. First
            -- sight counts as today.
            if rec.lastWaterDay == nil then rec.lastWaterDay = today end
            if rec.lastFoodDay == nil then rec.lastFoodDay = today end
            if rec.lastRiskDay == nil then
                rec.lastRiskDay = today
            elseif today > rec.lastRiskDay then
                rec.lastRiskDay = today
                local risk = 0.004 * riskMult
                -- [C79] The same facts, counted twice for two
                -- different questions. `risk` is how likely the county
                -- is to take them; `handles` is how well they deal
                -- with danger when it arrives, and it is the product
                -- of exactly the modifiers below that are about the
                -- PERSON rather than their condition or the weather.
                -- Lower is better in both.
                local handles = 1.0
                if SAO.Lessons.has(id, "measure-the-danger") then
                    risk = risk * 0.5
                    handles = handles * 0.5
                end
                if SAO.Lessons.has(id, "routine-is-armor") then
                    risk = risk * 0.7
                    handles = handles * 0.7
                end
                local cls = SAO.Census and SAO.Census.classOf
                    and SAO.Census.classOf(rec.occupation) or nil
                if cls == "hardened" then
                    risk = risk * 0.7
                    handles = handles * 0.7
                elseif cls == "settled" then
                    risk = risk * 1.3
                    handles = handles * 1.3
                end
                -- [C11] The bite follows you into the dark - on the
                -- engine's own clock, not by an accumulating chance.
                -- F-047: a bite infects with CERTAINTY (no roll exists
                -- on this build), and the infected die exactly at
                -- infectionTime + pickMortalityDuration. The record
                -- carries that hour, read off the body as it went dark
                -- or mirrored from the sandbox table; past it, death
                -- is not a risk, it is due. The old "+0.10 +
                -- min(0.5, since/480)" claimed to be the engine's own
                -- turning odds and matched nothing in the jar.
                if rec.woundInfected then
                    -- The per-part WOUND infection (the septic kind,
                    -- not Knox). The engine gives it no dormant clock,
                    -- so this multiplier is OUR tuning, and says so.
                    risk = risk * 1.6
                end
                local pg3 = SAO.Standing.groupOf(id)
                if pg3 and pactFed[pg3] then risk = risk * 0.8 end
                -- The warm house survives the cold ([B6], the [A26]
                -- dormant-mirror idiom): a house whose LAST COUNTED
                -- hearth was burning loses fewer people in the months
                -- the cold multiplier applies. A stale claim softens
                -- nothing - nobody is warmed by a fire nobody has
                -- seen lately.
                local warmedByHearth = false
                if pg3 and SAO.Standing.hearthOf then
                    local hh3 = SAO.Standing.hearthOf(pg3)
                    warmedByHearth = (hh3 and hh3.burning) and true or false
                end
                if warmedByHearth and riskMult > 1.0 then
                    risk = risk * 0.8
                end
                if SAO.Standing.groupOf(id) then
                    risk = risk * 0.6
                    handles = handles * 0.6
                end
                if (rec.contactMonths or 0) > 3 then
                    risk = risk * 0.7
                    handles = handles * 0.7
                end
                -- [B37] And here is the cause the death never had.
                -- Every modifier above this line is circumstance -
                -- what they know, who they are with, how cold it is.
                -- None of them was whether they had drunk anything.
                -- The operator, on the old flat roll: a death that
                -- just happens means nothing. This is what it means
                -- now.
                --
                -- Derived, not simulated: `lastWaterDay` is the last
                -- day they REACHED somewhere with water in it, which
                -- is a fact the county already produces now that days
                -- go to places. Capped, because this colours the
                -- tuned model rather than replacing it - and a person
                -- who is drinking is at exactly the risk they were.
                local dryDays = daysWithout(rec, "lastWaterDay", today)
                if dryDays > THIRST_PATIENCE then
                    risk = risk * math.min(4.0,
                        1.0 + 0.6 * (dryDays - THIRST_PATIENCE))
                end
                local hungryDays = daysWithout(rec, "lastFoodDay", today)
                if hungryDays > HUNGER_PATIENCE then
                    risk = risk * math.min(2.0,
                        1.0 + 0.15 * (hungryDays - HUNGER_PATIENCE))
                end
                -- [C78] The body fights. [C11] read the engine's own
                -- bite clock onto the record and `biteDue` treated it
                -- as a due date - past it, death was not a risk, it
                -- was due - so every bitten person in the county died
                -- on schedule and nothing they had done beforehand
                -- made any difference to it.
                --
                -- The clock still stands: the course does not move it
                -- (Border 142 holds that), and a body that loses dies
                -- at exactly the hour the engine picked. What it can
                -- do is get there first. Every input below is already
                -- computed above for the risk, so the fight costs the
                -- pass nothing it was not already paying.
                if rec.knoxInfected and SAO.Course then
                    local span = tonumber(rec.infectionSpanHours)
                    if not span or span <= 0 then
                        span = math.max(0.0001,
                            (tonumber(rec.biteDeathAtHours) or 0) - nowHours)
                        rec.infectionSpanHours = span
                    end
                    local burden = 0
                    pcall(function()
                        burden = #(SAO.Conditions.of(id) or {})
                    end)
                    local years = nil
                    pcall(function() years = SAO.History.ageOf(id) end)
                    local verdict = SAO.Course.advance(rec, nowHours, {
                        id = id,
                        dryDays = dryDays,
                        hungryDays = hungryDays,
                        woundInfected = rec.woundInfected,
                        inHouse = pg3 ~= nil,
                        warmed = warmedByHearth,
                        pactFed = pg3 and pactFed[pg3] or false,
                        age = years,
                        conditionBurden = burden,
                        infectionsSurvived = rec.infectionsSurvived,
                    }, 24.0 / span)
                    if verdict == "won" then
                        log(rec.id .. " fought off the infection"
                            .. " (" .. tostring(rec.infectionsSurvived)
                            .. " survived)")
                        tally("threwOff")
                    end
                end
                -- [C125] Advance the neuroinflammation graph
                if SAO.Neuro and SAO.Neuro.advance then
                    pcall(function()
                        SAO.Neuro.advance(rec, 24.0, nowHours)
                    end)
                end
                local biteDue = rec.biteDeathAtHours ~= nil
                    and nowHours >= rec.biteDeathAtHours
                -- [C79] The county can catch it.
                --
                -- `knoxInfected` had exactly one writer - the block
                -- releasing a body to the dormant county, reading the
                -- bite off the character as it went dark - so the
                -- unwatched county could never contract Knox at all.
                -- Nobody out there was ever bitten. `[C78]` gave the
                -- infected a fight and it reached almost nobody,
                -- because almost nobody out there was ever infected.
                --
                -- A bad day is not only a fatal day. When the county
                -- takes somebody, the encounter either kills them or
                -- they get away from it having been opened up - and on
                -- this build a bite infects with certainty (F-047), so
                -- getting away IS catching it. Which of the two
                -- happens follows from how well they handle danger,
                -- read off the modifiers already computed above rather
                -- than from a second stack invented for it.
                --
                -- `ESCAPE_BASE` is ours and says so: nothing in the
                -- build establishes how often a survivable encounter
                -- draws blood, because the engine settles that on a
                -- loaded body's own damage and there is no body here.
                -- Due beats rolled, and it is not a roll at all: a
                -- course that has run out is a death the engine already
                -- decided, so it never touches the ambient chance and
                -- never takes the bite path below.
                local tookThem = false
                if biteDue then
                    tookThem = true
                else
                    tookThem = SAO.Rand.int(100000)
                        < math.floor(risk * 100000)
                end
                if tookThem and not biteDue and not rec.knoxInfected
                    and SAO.Course then
                    local window = biteWindowHours()
                    if window and window > 0 then
                        local escape = ESCAPE_BASE / math.max(0.05, handles)
                        if escape > 0.85 then escape = 0.85 end
                        if SAO.Rand.unit() < escape then
                            rec.knoxInfected = true
                            rec.infectionStartedAtHours = nowHours
                            rec.biteDeathAtHours = nowHours + window
                            rec.infectionSpanHours = window
                            rec.immuneProgress = 0
                            pcall(function()
                                SAO.PathogenEvents.emit(
                                    "infection",
                                    id,
                                    today,
                                    { record = rec, atHours = nowHours })
                            end)
                            tookThem = false
                            tally("bitten")
                            log(rec.id .. " got away from something out"
                                .. " there, and it had teeth")
                        end
                    end
                end
                if tookThem then
                    -- [C11] Who rises mirrors the engine's own law
                    -- (shouldBecomeZombieAfterDeath, F-044): the
                    -- infected turn, and under Everyone's Infected
                    -- every death turns. No body is fabricated out
                    -- there - only the claim, which rides the word
                    -- when it finds the county.
                    local turns = biteDue or rec.knoxInfected or false
                    pcall(function()
                        if SandboxVars.ZombieLore.Transmission == 3 then
                            turns = true
                        end
                    end)
                    if turns then
                        rec.turnedDormant = true
                        log(rec.id .. (biteDue
                            and " died of the bite, alone"
                            or " died out there, and rose"))
                    end
                    SAO.Identity.markDead(rec, tickCounter,
                        turns and "zombie" or "the county took them")
                    rec.deathNewsAt = nowHours + 24 + SAO.Rand.int(48)
                    -- [C70] The house settles inside `markDead`. What
                    -- stood here re-elected only when the corpse had
                    -- been the leader, on a group captured BEFORE the
                    -- death - so it ran a second election over a house
                    -- that had already settled, and it was the same
                    -- call site [C68] removed from the controller.
                    -- [C68]'s border only read the controller, so this
                    -- one survived a batch written to delete it.
                    log(id .. " (" .. tostring(rec.forename)
                        .. ") didn't make it out there - the county collects")
                end
            end
        end
    end
end

-- Dormant encounters: two dormant survivors whose drifting days cross
-- (within 3 tiles at the same cadence pass) MEET - the social world does
-- not freeze when unobserved. Abstracted conversation: mutual trust
-- accrues, hostile pairs give each other a wide berth (no off-screen
-- combat in v1 - nobody dies unwitnessed), and company can form at the
-- same trust line the observed world uses. Standing ops only; no bodies.
-- pairKey -> county tick ([C112]); a MEETING is minutes, not a
-- 240-tick pass (~4s at 60fps frames on the default day)
local dormantLastMet = {}
local encounterCursor = nil -- rotate the outer loop across passes ([A16])

-- [B41] What the road meeting is made of, named.
--
-- The docstring above says two survivors meet "within 3 tiles" and the
-- code said `<= 9.0` - the square, which is correct and which nothing
-- connected to the sentence. [B40] found the same shape one module
-- over: a comment asserting an invariant the code only happened to
-- satisfy. Squaring a named range makes the two agree by construction.
local MEET_RANGE = 3

-- How many dormant records the outer sweep visits per pass. At
-- hundreds of records a full pairwise sweep is too heavy for one
-- tick, so the cursor rotates and coverage completes over several
-- passes at constant cost ([A16]).
local ENCOUNTER_BUDGET = 12

-- One meeting per pair per roughly thirty to sixty seconds of
-- adjacency (county ticks since [C112], a 9000th of a county hour
-- apiece - the seconds hold at the 60fps frames the derivation
-- assumed on the default day). Without it the four-second population pulse compounded
-- trust about forty times the observed world's encounter rate
-- ([A13]) - so this is not a cadence, it is the correction for one.
local MEET_COOLDOWN = 1800

-- What a road meeting is worth. [C111] raised it from 0.005 on the
-- operator's ruling (2026-09-12): at the old rate the company line
-- from nothing was two hundred meetings with the same person, so a
-- house only ever formed between people who already trusted each
-- other at genesis. At 0.02 the default line (0.5) is twenty-five
-- meetings - still built by crossing paths repeatedly over weeks,
-- never by one conversation. [C115] The number the ruling moved is
-- the operator's dial now (the screen ruling of 2026-09-13): read
-- here per meeting, so a world being played can be retuned; the
-- fallback is the ruled figure, which is also the declared default.
local function roadTrust()
    local sv = SandboxVars and SandboxVars.SurvivorAwareness or nil
    return (sv and tonumber(sv.RoadMeetingWorth)) or 0.02
end

-- How far the abstraction steps a hostile pair apart. Nobody dies
-- unwitnessed, so the only thing an encounter between enemies does is
-- put ground between them.
local WIDE_BERTH = 3

-- [B51] `dormantLastMet` is keyed by a PAIR and nothing has ever
-- removed one. A pair with a dead member can never meet again, so
-- the entry is read by nobody for the rest of the session. Called
-- from `Identity.markDead`, which every death path funnels through.
function D.forgetPairs(id)
    local a = tostring(id)
    local doomed = {}
    for key in pairs(dormantLastMet) do
        local left, right = string.match(key, "^([^|]+)|([^|]+)$")
        if left == a or right == a then
            doomed[#doomed + 1] = key
        end
    end
    for i = 1, #doomed do dormantLastMet[doomed[i]] = nil end
    return #doomed
end

-- [C76] Ground a house may not take, in the live path's own terms.
--
-- Another living company's claim, a living person's home, and a
-- feuding company's keep-out. Written once here because the settling
-- pass is the second reader of this law and two copies of a law is how
-- they drift ([C25]).
local function barredGround(myGroup, cx, cy)
    for og in pairs(SAO.Standing.allGroupClaims()) do
        -- [C108] A company's ground is every place its living
        -- members go, not only the seat it settled - the derived
        -- set answers here, so a house does not settle over
        -- another's stash while honouring their base.
        if og ~= myGroup
            and SAO.Standing.onGroundOf(og, cx, cy) then
            return true
        end
        -- [A20] And not in a feud's shadow either - around every
        -- place they hold.
        if og ~= myGroup and SAO.Standing.feudBetween(myGroup, og)
            and SAO.Standing.onGroundOf(og, cx, cy,
                SAO.Standing.FEUD_KEEP_OUT) then
            return true
        end
    end
    -- [B35] The player holds ground under a `player:` key and has no
    -- Identity record, so a guard written to skip the DEAD skipped the
    -- one owner who is never dead. Both are refused here.
    for owner, oc in pairs(SAO.Standing.allPersonalClaims()) do
        local orec = SAO.Identity.get(owner)
        if (SAO.Standing.isPlayerKey(owner) or (orec and not orec.dead))
            and cx >= oc.minX and cx <= oc.maxX
            and cy >= oc.minY and cy <= oc.maxY then
            return true
        end
    end
    return false
end

-- [C76] A house takes ground where its people already go.
--
-- `setGroupClaim`, `setHearth`, `setLarder` and `setWaterStore` had
-- call sites in `SAO_Controller` alone, which needs materialised
-- bodies. So a dormant house - and after `[C71]` and `[C72]` houses do
-- form and stand - had nowhere to be, and every survival modifier
-- reading those was inert unless a player happened to be watching.
--
-- The live path scouts through `SAOJavaBridge:scoutBase`, which reads
-- the loaded ground and needs a body. The dormant half has no body and
-- does not need one, because the fact already exists: `learnBuilding`
-- has recorded every arrival since `[B37]`, with the building's bounds,
-- what it offers, and how many times that person has been - and its
-- own comment says what that count means, that somewhere returned to
-- is somewhere that gave them something.
--
-- So a house settles on the building its members have actually
-- returned to most. Nothing is scored that the county did not already
-- measure by walking, and nothing is placed: a house whose people have
-- never gone back anywhere has no candidate and takes no ground, which
-- is a correct outcome rather than a failure. Competency follows from
-- who is in the house.
--
-- The two refusals are the live path's own, in its own words: never
-- over another living company's claim or a living person's home
-- ([A24], [B35]), and never inside a feuding company's keep-out
-- ([A20]). Contested ground comes from politics, not from blindness.
--
-- A house settles once and this pass never looks at it again, because
-- `groupClaimOf` answering is the skip. A house deciding to LEAVE is
-- not representable at all while a group's ground is one rectangle
-- under one name (DR-006 S4), and that is the operator's named
-- ontology error and its own batch - not something to smuggle in
-- here.
-- One house a pass ([B51]'s discipline). The walk is a house's members
-- times the buildings they have each entered, and `b.known` grows with
-- the walking - so an unbudgeted sweep over every unsettled house
-- would get more expensive exactly as the county got more interesting.
-- A house settling a day later than it could have is not a cost
-- anybody can see.
-- How many houses may settle in one pass. One: the work inside is a
-- house's members times the buildings each of them has entered, and
-- `b.known` grows with the walking ([C75]), so the walk is stopped at
-- the first house that takes ground rather than carried to the end of
-- the store.
local SETTLE_BUDGET = 1

local function dormantSettle()
    if not (SAO.Standing and SAO.Standing.setGroupClaim) then return end
    local seen, settled = {}, 0
    for id, rec in pairs(SAO.Identity.all()) do
        if not rec.dead and not SAO.Body.hasRepresentation(id) then
            local g = SAO.Standing.groupOf(id)
            if g and not seen[g]
                and not SAO.Standing.groupClaimOf(g)
                and SAO.Standing.groupSize(g) > 1
                and not groupHasSourceOwner(g) then
                seen[g] = true
                -- [C108] The scorer became a ranking, and the settle
                -- pass reads the top of it: one definition, so the
                -- seat and the set cannot drift apart ([C25]). The
                -- law is [C76]'s own - visits summed across the
                -- members who reach a place, water doubled - with
                -- recency breaking ties, and the first unbarred
                -- candidate is the one it always picked.
                local members = SAO.Standing.membersOf(g)
                local best, bestId = nil, nil
                for _, t in ipairs(SAO.Perception.returnsOf(members)) do
                    if not barredGround(g, t.place.cx, t.place.cy) then
                        best, bestId = t, t.id
                        break
                    end
                end
                if best then
                    local bp = best.place
                    SAO.Standing.setGroupClaim(g,
                        bp.minX - 1, bp.minY - 1,
                        bp.maxX + 1, bp.maxY + 1, 0)
                    -- Homes converge, as they do on the live path: the
                    -- base is where the house lives now, and the
                    -- dormant day's own anchor follows with no further
                    -- wiring.
                    for _, mid in ipairs(members) do
                        local mrec = SAO.Identity.get(mid)
                        if mrec then
                            mrec.homeX, mrec.homeY, mrec.homeZ =
                                bp.cx, bp.cy, 0
                        end
                    end
                    -- Say WHY this building and not another. A decision
                    -- whose reasons are computed and thrown away is
                    -- indistinguishable from one that was scripted.
                    log(tostring(SAO.Standing.factionName(g) or g)
                        .. " settles at " .. tostring(bp.cx) .. ","
                        .. tostring(bp.cy) .. ": " .. #members
                        .. " of them, " .. tostring(bestId)
                        .. " returned to "
                        .. tostring(best.visits) .. " times"
                        .. ((bp.sources and bp.sources.water)
                            and ", and it has water" or ""))
                    tally("settled")
                    settled = settled + 1
                end
            end
        end
        if settled >= SETTLE_BUDGET then break end
    end
end

-- [C63] A need date is evidence that a person ate or drank, never a shelf
-- count. The old dormant pass derived larder/water/hearth claims from those
-- dates and overwrote native observations with a different meaning. Retain the
-- scheduler name for save/tool compatibility, but do no projection until
-- dormant people perform receipt-bearing storage actions of their own.
local function dormantProvision()
    -- Consumption dates express need pressure, not inventory. They cannot
    -- replace a native shelf/water reading or a completed source result. Keep
    -- this scheduled seam as a compatibility no-op until dormant actors have
    -- their own performed acquisition/storage receipts.
    return 0
end

local function dormantEncounters(tickCounter)
    local sv = SandboxVars and SandboxVars.SurvivorAwareness or nil
    local companyAt = (sv and tonumber(sv.TrustToCompany)) or 0.5
    local day = math.floor(hoursNow() / 24.0)
    local met = {}
    -- [B51] The inner sweep used to be `pairs(SAO.Identity.all())`,
    -- run once per outer record. `all()` is the whole store and the
    -- store KEEPS THE DEAD ON PURPOSE - "death is durable: the record
    -- stays (a person existed and died there)" - in ModData, so the
    -- graveyard grows for the life of a save and across every session
    -- of it. The sweep's cost was 12 x (living + dead) and only the
    -- first term is capped.
    --
    -- Measured on the engine at 500 living: 1.6 ms a pass with no
    -- dead, 5.6 ms at five thousand dead, 13.1 ms at ten thousand -
    -- about 1.15 ms per thousand graves, on a 240-frame cadence.
    -- Thirteen milliseconds is most of a 60fps frame, arriving as a
    -- hitch every four seconds, and nothing bounds it.
    --
    -- One walk instead of twelve. The predicate is the inner loop's
    -- own former test, moved to where it is asked once per pass.
    local livingId, livingRec, livingN = {}, {}, 0
    for id, rec in pairs(SAO.Identity.all()) do
        if not rec.dead and not SAO.Body.hasRepresentation(id)
            and not sourceOwnsDormantRecord(id) then
            livingN = livingN + 1
            livingId[livingN] = id
            livingRec[livingN] = rec
        end
    end
    -- County scaling: at hundreds of dormant records the full pairwise
    -- sweep is too heavy for one pass. Rotate: up to 12 outer records per
    -- pass, resuming where the last pass stopped - full coverage every
    -- few passes, constant cost per tick.
    local outerBudget = ENCOUNTER_BUDGET
    local resumed = encounterCursor == nil
    local lastVisited = nil
    for idA, recA in pairs(SAO.Identity.all()) do
      if not resumed then
        if idA == encounterCursor then resumed = true end
      elseif outerBudget <= 0 then
        break
      elseif not recA.dead and not SAO.Body.hasRepresentation(idA)
          and not sourceOwnsDormantRecord(idA) then
        outerBudget = outerBudget - 1
        lastVisited = idA
        for li = 1, livingN do
          local idB, recB = livingId[li], livingRec[li]
          -- `dead` and `Body.get` are gone from this test on purpose:
          -- the list was built with exactly them. `idB > idA` and the
          -- `met` guard stay, because both are about the PAIR.
          if idB > idA and not met[idA .. "|" .. idB] then
            local dx, dy = recA.x - recB.x, recA.y - recB.y
            local pairKey = idA .. "|" .. idB
            if dx * dx + dy * dy <= MEET_RANGE * MEET_RANGE
                and tickCounter >= ((dormantLastMet[pairKey] or 0)) then
                met[pairKey] = true
                -- One meeting per pair per ~30-60s of adjacency
                -- (county ticks since [C112], a 9000th of a county
                -- hour apiece - 60fps frames on the default day): without
                -- this the 240-tick population
                -- pulse compounded trust ~40x the
                -- observed world's encounter rate ([A13] find).
                dormantLastMet[pairKey] = tickCounter
                    + MEET_COOLDOWN + SAO.Rand.int(MEET_COOLDOWN)
                -- [C71] They saw each other. Written before the
                -- branch below, because keeping a wide berth from
                -- somebody is still having seen them - and a survivor
                -- who cannot remember meeting anyone has no person to
                -- decide about tomorrow.
                -- [C87] The meet test already computed the pair's
                -- distance; it is passed rather than thrown away, so
                -- the belief carries how far apart they actually
                -- stood instead of a carried or zero seed.
                local metDist = math.sqrt(dx * dx + dy * dy)
                pcall(function()
                    SAO.Perception.sawPerson(idA,
                        SAO.Identity.beliefKey(SAO.Identity.get(idB)),
                        recB.x, recB.y, tickCounter, idB, metDist)
                    SAO.Perception.sawPerson(idB,
                        SAO.Identity.beliefKey(SAO.Identity.get(idA)),
                        recA.x, recA.y, tickCounter, idA, metDist)
                end)
                if SAO.Standing.isHostileTo(idA, idB)
                    or SAO.Standing.isHostileTo(idB, idA) then
                    -- A wide berth: the abstraction steps them apart.
                    recB.x = recB.x
                        + (dx < 0 and -WIDE_BERTH or WIDE_BERTH)
                    log(idA .. " and " .. idB
                        .. " crossed paths dormant - hostile, kept apart")
                else
                    SAO.Standing.adjustTrust(idA, idB, roadTrust())
                    SAO.Standing.adjustTrust(idB, idA, roadTrust())
                    -- A road meeting is a conversation ([A17]): one
                    -- lesson may change hands, and the full word-of-mouth
                    -- verb runs both ways - places, faction names, and
                    -- the introduction travel the roads at told weight
                    -- (stale threat beliefs age out on their own horizon
                    -- and never travel). Knox inhabitants receive and
                    -- carry this knowledge purely through conversation.
                    local taughtAB = SAO.Lessons.tellOne(idA, idB)
                    if not taughtAB then SAO.Lessons.tellOne(idB, idA) end
                    if SAO.Adaptation and SAO.Adaptation.tell then
                        pcall(function()
                            SAO.Adaptation.tell(idA, idB, day)
                            SAO.Adaptation.tell(idB, idA, day)
                        end)
                    end
                    -- Doctrine travels the roads too ([A18]): company
                    -- members from different camps argue or agree out
                    -- there, unwitnessed - the standing shifts are what
                    -- the county sees later.
                    local verdict = SAO.Standing.politick(idA, idB, tickCounter)
                    if verdict == "opposed" then
                        log(idA .. " and " .. idB
                            .. " argued doctrine on the road")
                    elseif verdict == "aligned" then
                        log(idA .. " and " .. idB
                            .. " found common cause on the road")
                    elseif verdict == "hostile" then
                        log("words became weapons between " .. idA
                            .. " and " .. idB .. " (on the road)")
                    elseif verdict == "peace" then
                        log("PEACE on the road: "
                            .. tostring(SAO.Standing.groupOf(idA)) .. " and "
                            .. tostring(SAO.Standing.groupOf(idB))
                            .. " end their feud")
                    elseif verdict == "feud-declared" then
                        log("FEUD declared on the road: "
                            .. tostring(SAO.Standing.groupOf(idA)) .. " vs "
                            .. tostring(SAO.Standing.groupOf(idB)))
                    elseif verdict == "pact" then
                        log("PACT on the road: "
                            .. tostring(SAO.Standing.groupOf(idA)) .. " and "
                            .. tostring(SAO.Standing.groupOf(idB))
                            .. " shook on bread-for-watch")
                    end
                    pcall(function()
                        SAO.Perception.tell(idA, idB, tickCounter, nil, "dormant-encounter")
                        SAO.Perception.tell(idB, idA, tickCounter, nil, "dormant-encounter")
                    end)
                    pcall(function()
                        if SAO.Controller and SAO.Controller.appraiseCoordination then
                            SAO.Controller.appraiseCoordination(idA, nil, "dormant")
                            SAO.Controller.appraiseCoordination(idB, nil, "dormant")
                        end
                        if SAO.Communication
                            and SAO.Communication.deliverPendingResponses then
                            SAO.Communication.deliverPendingResponses(idA, idB,
                                "dormant-encounter",
                                { exchange = "shared-matter" })
                            SAO.Communication.deliverPendingResponses(idB, idA,
                                "dormant-encounter",
                                { exchange = "shared-matter" })
                        end
                    end)
                    -- Grudges travel the roads too ([A23]): testimony
                    -- was the one cargo missing from dormant meetings -
                    -- the county's negative channel rode only doctrine.
                    -- Same credibility gates as anywhere (trust-scaled,
                    -- hostility only on the receiver's own collapse).
                    pcall(function()
                        SAO.Standing.tellGrudges(idA, idB)
                        SAO.Standing.tellGrudges(idB, idA)
                        -- The good word travels the roads too ([B8]).
                        SAO.Standing.tellCredits(idA, idB)
                        SAO.Standing.tellCredits(idB, idA)
                    end)
                    local gA, gB = SAO.Standing.groupOf(idA), SAO.Standing.groupOf(idB)
                    -- Mercy on the roads too ([A24]).
                    local roadBar = companyAt
                    do
                        local hostG = gA or gB
                        if hostG and gA ~= gB then
                            local hc = SAO.Standing.creedOf(hostG)
                            if hc and hc.name == "mercy" then
                                roadBar = companyAt - 0.1
                            end
                        end
                    end
                    -- The admitted encounter above carries concrete matters
                    -- and return responses. Roster authority and departure are
                    -- not inferred from a meeting, trust totals, or hostility.
                    -- [C111] Need reads alongside trust at the door
                    -- (`companyStanding`): each side's pull is their
                    -- own, and the mutual gate still clears on both
                    -- sides or not at all.
                    if not (gA and gB)
                        and SAO.Standing.companyStanding(idA, idB) > roadBar
                        and SAO.Standing.companyStanding(idB, idA) > roadBar then
                        local groupName = gA or gB or ("company-" .. idA)
                        if SAO.Standing.circleRefuses(idA, groupName, idB)
                            or SAO.Standing.circleRefuses(idB, groupName, idA) then
                            log(idA .. " and " .. idB
                                .. " part ways friendly - somebody keeps"
                                .. " their own company")
                        else
                            local process, response, changed, result =
                                SAO.Standing.proposeCompany(idA, idB,
                                    "dormant-encounter", "dormant")
                            if process and response and changed then
                                tally(result == "founded"
                                    and "kept company on the road"
                                    or "joined company on the road")
                            elseif process and response then
                                log(idA .. " and " .. idB
                                    .. " leave the membership proposal at "
                                    .. tostring(result))
                            end
                        end
                    end
                end
            end
          end
        end
      end
    end
    if not resumed then
        -- The cursor's record vanished (death/removal): restart the sweep
        -- next pass rather than stalling forever.
        encounterCursor = nil
    else
        encounterCursor = lastVisited   -- nil when the sweep wrapped: restart
    end
end

function D.rebindWorld()
    dormantLastMet = {}
    encounterCursor = nil
end

D.dormantLife = dormantLife
D.advanceDormantPhysiology = advanceDormantPhysiology
D.dormantAttrition = dormantAttrition
D.dormantSettle = dormantSettle
D.dormantProvision = dormantProvision
D.dormantEncounters = dormantEncounters
return D
