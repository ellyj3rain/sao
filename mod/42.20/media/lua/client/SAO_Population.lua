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

local TICK_INTERVAL = 240   -- population pass cadence, in FRAMES (~4s at
                            -- 60fps; [B49] measured 64.5fps on the
                            -- operator's machine, so nearer 3.7s there)

local tickCounter = 0
local booted = false
local regionPoints = nil    -- flattened { {x,y,z,region=name}, ... }
local regionPointsByProfession = nil   -- F-030: declared BEFORE its writer

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
        population = (sv and tonumber(sv.Population)) or 0,    -- schema default (DR-008)
        -- [B28] The ceiling arrivals may raise the county TO.
        -- Equal to or below population means a closed county:
        -- the number you start with is the number there is.
        newcomers = (sv and tonumber(sv.Newcomers)) or 0,
        -- [B29] How many walk together when the road brings
        -- anyone. The month is unchanged; this is magnitude,
        -- which [B28] settled is the honest knob because how
        -- many people are walking is not a fact about us.
        roadTraffic = (sv and tonumber(sv.RoadTraffic)) or 2,
        -- [B33] How hard the country outside is pushing. Not a
        -- schedule and not a second magnitude: it scales how much the
        -- month shortens as the sky stays quiet. 0 leaves the month
        -- exactly as it was, which is what an untouched world gets.
        roadPressure = (sv and tonumber(sv.RoadPressure)) or 0.0,
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

local function dist(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return math.sqrt(dx * dx + dy * dy)
end

-- ---------------------------------------------------------------------------
-- World origins: the map's own spawn tables, flattened once per session.

local function loadRegionPoints()
    if regionPoints then return regionPoints end
    local flat = {}
    local ok, regions = pcall(function() return SpawnRegionMgr.getSpawnRegions() end)
    if not ok or type(regions) ~= "table" then
        log("spawn regions unavailable (" .. tostring(regions) .. "); genesis deferred")
        return nil
    end
    -- The engine's spawn points are keyed BY PROFESSION ([A18]): the
    -- vanilla spawnpoints tables are literally a per-profession map of
    -- where such a life would have been when it started. Keep the key.
    local byProfession = {}
    for _, region in ipairs(regions) do
        if region.name and type(region.points) == "table" then
            for professionKey, list in pairs(region.points) do
                if type(list) == "table" then
                    for _, point in ipairs(list) do
                        if point.posX and point.posY then
                            local p = {
                                x = math.floor(point.posX),
                                y = math.floor(point.posY),
                                z = math.floor(point.posZ or 0),
                                region = tostring(region.name),
                                profession = tostring(professionKey),
                            }
                            flat[#flat + 1] = p
                            local key = p.profession
                            byProfession[key] = byProfession[key] or {}
                            table.insert(byProfession[key], p)
                        end
                    end
                end
            end
        end
    end
    regionPointsByProfession = byProfession
    if #flat == 0 then
        log("spawn regions carried no usable points; genesis deferred")
        return nil
    end
    regionPoints = flat
    log("world origins loaded: " .. #flat .. " spawn points across the map")
    return regionPoints
end

-- [B38] How people arrive: alone, or in twos and threes.
--
-- A county of two hundred solitary strangers is not a county. Most
-- people who lived through the first night lived through it with
-- somebody, and the ones who did not are the exception worth having.
--
-- These are shares of ORIGINATIONS, not of people: a unit of three
-- counts once here and thrice in the county, so the head count skews
-- larger than the size column reads. At 45/35/20 the average unit is
-- 1.75 people, which turns a county of 216 into about 123 parties.
local UNIT_SIZES = {
    { size = 1, weight = 45 },
    { size = 2, weight = 35 },
    { size = 3, weight = 20 },
}

-- What held them together. Recorded as a kind and nothing more - who
-- exactly they are to each other is derived from their ages, which
-- are already facts about them ([B37]).
-- The field is `bond`, not `kind`. `kind = "..."` is this tree's
-- spelling for a NEWS kind and border 10 sweeps every Lua file for
-- it, so reusing the identifier here made three unit kinds look like
-- three radio bulletins nothing rendered. The convention is
-- load-bearing; the rename respects it rather than dodging it.
local UNIT_KINDS = {
    { bond = "family", weight = 45 },
    { bond = "friends", weight = 35 },
    { bond = "mixed", weight = 20 },
}

-- People thrown together by the outbreak trust each other less than
-- people who chose each other, and both less than blood.
local UNIT_TRUST = {
    family = 0.85,
    friends = 0.70,
    mixed = 0.50,
}

local function pickWeighted(rows, field)
    local total = 0
    for _, row in ipairs(rows) do total = total + row.weight end
    local roll = ZombRand(total)
    local seen = 0
    for _, row in ipairs(rows) do
        seen = seen + row.weight
        if roll < seen then return row[field] end
    end
    return rows[1][field]
end

local function rollUnit()
    return pickWeighted(UNIT_SIZES, "size"),
        pickWeighted(UNIT_KINDS, "bond")
end

-- [B38] How many people the county holds, when the county is ASKED
-- rather than told.
--
-- A flat sixty was one number for every possible map. The operator
-- played it and read it correctly: "it is a little low... there
-- should definitely be more people in each city than it felt like
-- there was." Measured against their own install, sixty people spread
-- round-robin across TWELVE regions is five per town - and two of
-- those twelve came from map mods, which the flat number could not
-- know about.
--
-- The map already states where people were: `SpawnRegionMgr` returns
-- one region per place the game thinks a life could have started, and
-- a mod that adds a town adds a region. So the county sizes itself,
-- and installing more county gets more people without touching a
-- setting.
--
-- Deliberately per-REGION and not per spawn point. Points are filed
-- per profession ([A18]), so counting them would make the population
-- grow every time a mod adds an occupation, which is a fact about
-- jobs rather than about how many people live here.
local PER_REGION = 18
local DERIVED_FLOOR = 60
local DERIVED_CEILING = 360

local derivedTarget = nil

local function countRegions()
    local points = loadRegionPoints()
    if not points then return nil end
    local seen, n = {}, 0
    for _, p in ipairs(points) do
        if p.region and not seen[p.region] then
            seen[p.region] = true
            n = n + 1
        end
    end
    if n == 0 then return nil end
    return n
end

-- The sandbox number governs when it is set. Zero means "ask the
-- map", which is the shipped default for a new world; an existing
-- world keeps whatever number it stored.
local function resolveTarget(conf)
    if conf.population and conf.population > 0 then
        return conf.population
    end
    if derivedTarget then return derivedTarget end
    local n = countRegions()
    if not n then
        -- Regions are not loadable yet. Hold at the old default
        -- rather than founding a county of zero.
        return DERIVED_FLOOR
    end
    local target = n * PER_REGION
    if target < DERIVED_FLOOR then target = DERIVED_FLOOR end
    if target > DERIVED_CEILING then target = DERIVED_CEILING end
    derivedTarget = target
    log("the county sizes itself: " .. n .. " regions x " .. PER_REGION
        .. " a town = " .. target .. " people")
    return target
end

-- The ceiling arrivals may raise the county TO. This has to move with
-- the population or deriving one silently closes the road: arrivals
-- are gated on `newcomers > population`, and a derived county of 216
-- against the old flat ceiling of 180 would mean nobody ever walks in
-- again, with no error and no log line. Same three-to-one the shipped
-- defaults always had (60 and 180), so a bigger county is exactly as
-- open as a small one was.
local NEWCOMER_RATIO = 3
local NEWCOMER_CEILING = 500

local function resolveNewcomers(conf, target)
    if conf.newcomers and conf.newcomers > 0 then return conf.newcomers end
    local ceiling = target * NEWCOMER_RATIO
    if ceiling > NEWCOMER_CEILING then ceiling = NEWCOMER_CEILING end
    return ceiling
end

-- Where such a life would have been ([A18]): a point filed under this
-- profession's own engine path, anywhere in the county - the nurse
-- holed up at a clinic point, the deputy at a station point. Nil when
-- the county never filed one; the caller keeps its ordinary origin.
local function pickOriginFor(enginePath)
    if not enginePath then return nil end
    loadRegionPoints()
    local list = regionPointsByProfession
        and regionPointsByProfession[enginePath] or nil
    if not list or #list == 0 then return nil end
    return list[ZombRand(#list) + 1]
end

-- Region-balanced pick: choose a region uniformly first, then a point within
-- it, so one town's long table does not swallow the population.
local function pickOrigin()
    local points = loadRegionPoints()
    if not points then return nil end
    local byRegion = {}
    for _, p in ipairs(points) do
        byRegion[p.region] = byRegion[p.region] or {}
        table.insert(byRegion[p.region], p)
    end
    local names = {}
    for name in pairs(byRegion) do names[#names + 1] = name end
    if #names == 0 then return nil end
    local regionList = byRegion[names[ZombRand(#names) + 1]]
    return regionList[ZombRand(#regionList) + 1]
end

-- ---------------------------------------------------------------------------

local lastHighwayLogAt = -9

local function hoursNow()
    local ok, h = pcall(function() return GameTime.getInstance():getWorldAgeHours() end)
    return ok and h or 0
end

-- [B28] THREE WORDS, and they are not synonyms. The operator drew
-- the distinction and it is the same perspective principle the
-- provenance ladder runs on - one person, three registers:
--
--   newcomer     this record's own neutral term. Internal only.
--   stranger     what the COUNTY reports, on the wire. A fact about
--                acquaintance and nothing more.
--   interloper   what a HOUSE THAT HOLDS GROUND calls them. A
--                judgment, and it has to be EARNED by their claim -
--                see the objection in SAO_Controller ([A15]).
--
-- The word used here and on the wire until [B28] was one this genre
-- reserves for zombies, so the single term for an arriving survivor
-- meant the opposite of a survivor. It is gone.

local function ensurePopulation(conf)
    -- [B28] THE ROAD. This runs BEFORE the refill clock and outside
    -- the death gate, because it is not about this county.
    --
    -- [B28] had it nested inside [A27]'s arrival branch, which only
    -- opens after first blood - so a county that had lost nobody
    -- would never see a newcomer no matter how long the sky had been
    -- quiet. That inverted the causation. Two questions were merged
    -- and they are separate:
    --
    --    who is on the road   the country beyond the county fell.
    --                         Nothing to do with us.
    --    who stops HERE       [A27]'s draw, which is entirely about
    --                         us, and which is untouched below.
    --
    -- The gate is the game's own lore read as engine state: GameTime
    -- knows the day the helicopter passes and the night count knows
    -- whether that day is behind us. Nobody has to be told the
    -- country fell. The sky went quiet, and people started walking.
    --
    -- One a month, flat. How many people are walking is not a fact
    -- about this county, so it is not read off our reputation.
    -- Admissions still land as pairs sometimes, because the existing
    -- "arrived together" bonding already does that - derived, rather
    -- than a second rate invented here.
    --
    -- Admission raises the CEILING and nothing else. Whether anyone
    -- actually settles is still the draw, the refill wait, and the
    -- roll further down.
    -- [B38] Resolved once per pass, before anything reads it, so
    -- every ceiling below is measured against the same number.
    conf.population = resolveTarget(conf)
    conf.newcomers = resolveNewcomers(conf, conf.population)
    local capNow = conf.population
    do
        local s70 = nil
        pcall(function()
            s70 = ModData.getOrCreate("SurvivorAwareness_Standing")
        end)
        if type(s70) == "table" then
            local admitted = tonumber(s70.newcomersAdmitted) or 0
            if conf.newcomers > conf.population then
                local skyQuiet = false
                pcall(function()
                    local gt70 = GameTime.getInstance()
                    local day70 = gt70:getHelicopterDay()
                    local nights70 = gt70:getNightsSurvived()
                    -- No helicopter scheduled means no moment to wait
                    -- for: there was never a sound to stop.
                    if day70 == nil or day70 <= 0 then
                        skyQuiet = true
                    elseif nights70 ~= nil and nights70 > day70 then
                        skyQuiet = true
                    end
                end)
                if skyQuiet then
                    local lastAt = tonumber(s70.lastAdmitAtHours)
                    local nowH70 = hoursNow()
                    -- [B33] The moment the sky went quiet, kept so the
                    -- road can be read against it. A save from before
                    -- this anchors on its own last admission, which is
                    -- the best evidence it carries - never on the
                    -- epoch, which would date the collapse to the
                    -- beginning of time.
                    if s70.skyQuietAtHours == nil then
                        s70.skyQuietAtHours =
                            tonumber(s70.lastAdmitAtHours) or nowH70
                    end
                    -- [B33] The month is not a schedule, it is a rate,
                    -- and a rate that never moves says the country
                    -- stopped falling the day the helicopter left. It
                    -- did not. Each month the sky stays quiet, more of
                    -- what is out there is on the road - so the
                    -- interval is read off how long it HAS been quiet,
                    -- which is engine state and nobody's invention.
                    --
                    -- Root, not linear: the road thickens quickly at
                    -- first and then keeps thickening slowly, instead
                    -- of running away. RoadPressure is how hard the
                    -- country outside is pushing, and at 0 the whole
                    -- term vanishes and the month is exactly the month
                    -- it always was.
                    --
                    -- This is still only who is ON the road. Whether
                    -- any of them stop HERE is the draw, untouched.
                    local quietH = nowH70
                        - (tonumber(s70.skyQuietAtHours) or nowH70)
                    if quietH < 0 then quietH = 0 end
                    local accel = 1.0 + (conf.roadPressure or 0.0)
                        * math.sqrt(quietH / 720.0)
                    local wait = 720.0 / accel
                    -- A day is the floor. Below that the road stops
                    -- being a road and becomes a queue.
                    if wait < 24.0 then wait = 24.0 end
                    if lastAt == nil then
                        -- The first month runs from the day the sky
                        -- went quiet, not from the epoch.
                        s70.lastAdmitAtHours = nowH70
                    elseif nowH70 - lastAt >= wait
                        and conf.population + admitted < conf.newcomers then
                        -- [B29] A group, not a person. The road is as
                        -- busy as the player said it is; the month is
                        -- untouched, and the county's own draw still
                        -- decides whether any of them stop here.
                        local came = conf.roadTraffic or 1
                        if came < 1 then came = 1 end
                        local room = conf.newcomers
                            - (conf.population + admitted)
                        if came > room then came = room end
                        admitted = admitted + came
                        s70.newcomersAdmitted = admitted
                        s70.lastAdmitAtHours = nowH70
                        log((came == 1 and "someone else is walking"
                            or (came .. " more are walking"))
                            .. " (room for "
                            .. (conf.population + admitted) .. " now)")
                    end
                end
            end
            capNow = conf.population + admitted
            if capNow > conf.newcomers then capNow = conf.newcomers end
            if capNow < conf.population then capNow = conf.population end
        end
    end
    -- Durable death: refill waits the configured days after the newest loss.
    local newestDeathHours = -1
    for _, rec in pairs(SAO.Identity.all()) do
        if rec.dead and (rec.diedAtHours or 0) > newestDeathHours then
            newestDeathHours = rec.diedAtHours or 0
        end
    end
    if newestDeathHours >= 0
        and (hoursNow() - newestDeathHours) < conf.refillDays * 24.0 then
        return
    end
    -- The highway ([A27]): after first blood, refill is ARRIVAL, and
    -- the county's reputation is a migration force. Wars turn newcomers
    -- away, mercy houses draw them in, winter thins the road. Genesis
    -- (before any death) stays unshaped - the county starts full.
    local arriving = newestDeathHours >= 0
    if arriving then
        local chance = 100
        local seen87, feuds87, mercy87 = {}, 0, 0
        for _, r87 in pairs(SAO.Identity.all()) do
            if not r87.dead then
                local g87 = SAO.Standing.groupOf(r87.id)
                if g87 and not seen87[g87] then
                    seen87[g87] = true
                    local c87 = SAO.Standing.creedOf
                        and SAO.Standing.creedOf(g87) or nil
                    if c87 and c87.name == "mercy" then
                        mercy87 = mercy87 + 1
                    end
                    for g2 in pairs(seen87) do
                        if g2 ~= g87
                            and SAO.Standing.feudBetween(g87, g2) then
                            feuds87 = feuds87 + 1
                        end
                    end
                end
            end
        end
        chance = chance - feuds87 * 20 + mercy87 * 10
        pcall(function()
            local m87 = GameTime.getInstance():getMonth()
            if m87 == 11 or m87 == 0 or m87 == 1
                or m87 == 10 or m87 == 2 then
                chance = math.floor(chance * 0.5)
            end
        end)
        chance = math.max(10, math.min(100, chance))
        if ZombRand(100) >= chance then
            if SAO.Identity.livingCount() < capNow
                and hoursNow() - lastHighwayLogAt >= 1 then
                lastHighwayLogAt = hoursNow()
                log("the highway carries them past ("
                    .. feuds87 .. " wars, " .. chance .. "% draw)")
            end
            return
        end
    end
    local count = SAO.Identity.livingCount()
    local bornThisPass = 0
    while count < capNow and bornThisPass < 6 do
        -- County-scale genesis is PACED ([A16]): six identities per pass
        -- (240 frames, ~4s at 60fps) - a save reaches a 60-person
        -- county inside a minute of
        -- play without a single-tick spike.
        bornThisPass = bornThisPass + 1
        local origin = pickOrigin()
        if not origin then return end
        local rec = SAO.Identity.create(nil, nil, origin.x, origin.y, origin.z)
        if not rec then return end
        pcall(function() SAO.History.generate(rec.id, rec) end)
        -- Where the life was lived ([A18]): the id decided the trade
        -- (inside generate); if the county filed spawn points under
        -- that trade's own engine path, this survivor started THERE -
        -- the record moves before any body exists (unloaded-world
        -- mutation, sanctioned domain).
        local row = SAO.Census and rec.occupation
            and SAO.Census.rowOf(rec.occupation) or nil
        local anchored = row and pickOriginFor(row.enginePath) or nil
        if anchored then
            origin = anchored
            rec.x, rec.y, rec.z = anchored.x, anchored.y, anchored.z
            rec.originAnchored = true
        end
        rec.originRegion = origin.region
        rec.homeX, rec.homeY, rec.homeZ = origin.x, origin.y, origin.z
        -- [B40] They know where they started.
        --
        -- `originAnchored` was written here and read NOWHERE in the
        -- tree - one mention in the whole mod. It records the thing
        -- [A18] built: a life that began at its own trade's ground,
        -- the nurse at a clinic point, the deputy at a station.
        --
        -- And underneath it was a plainer gap. Every survivor woke up
        -- SOMEWHERE, and [B37] gave the county a way to know places,
        -- and nobody knew the one place they had certainly been. The
        -- metagrid answers without a body, so genesis can ask.
        --
        -- Provenance `lived`, because they did not walk past it or
        -- hear about it - they were in it when the world ended
        -- ([B39]).
        pcall(function()
            local startedIn = SAO.Places.at(origin.x, origin.y)
            if startedIn then
                SAO.Perception.learnBuilding(rec.id, startedIn, 0, "lived")
                if rec.originAnchored then
                    rec.knowsTradeGround = true
                end
            end
        end)
        -- A home is a claim from the first day: a modest box around the
        -- spawn house, the social fact other survivors will respect.
        pcall(function()
            -- [B34] One ruler for everybody. Genesis happens before
            -- any body exists, so there is nothing to ask the engine
            -- about yet and this is the one claim still measured by a
            -- radius - the honest fallback, not a second policy. It
            -- goes through the same function as the others so it
            -- starts deriving the moment a body is there to ask.
            local mnX, mnY, mxX, mxY = SAO.Standing.groundAround(
                SAO.Body.get(rec.id), origin.x, origin.y, 4)
            SAO.Standing.claim(rec.id, mnX, mnY, mxX, mxY, origin.z)
        end)
        if arriving then
            -- An arrival is a FACT of the person and news on the air.
            rec.newcomer = true
            rec.arrivedAtHours = hoursNow()
            pcall(function()
                SAO.Standing.pushRadioNews({ kind = "stranger" })
            end)
        end
        -- [B47] Once per person at seeding: 129 lines in the
        -- operator's log. Someone ARRIVING up the road later is a
        -- real event and keeps its own line; the seeding of a county
        -- is one fact with a number on it.
        if arriving then
            log("someone came up the road into " .. origin.region
                .. (anchored and (" (at their " .. (row.label or "trade")
                    .. " ground)") or "")
                .. " (" .. (count + 1) .. "/" .. capNow .. ")")
        else
            tally("the world gained a survivor")
        end
        count = count + 1
        -- Together since day one ([A18]), and [B38] in twos and
        -- threes. The operator ruled that many should begin in twos
        -- and threes - family units, friend units, mixed units.
        --
        -- Before this, twenty percent of lives got a single bonded
        -- mate and everybody else started alone, so a county of two
        -- hundred was a hundred and seventy solitary people. Now a
        -- life originates as a UNIT, and what kind of unit it is is a
        -- fact about it - a BOND, never a pre-formed faction, so the
        -- 3+ perception gate for companies stays untouched.
        --
        -- The unit records only what kind it is. WHICH relation any
        -- two of them stand in is derived from their ages at read
        -- time, because their ages are already facts ([B37]) and
        -- choosing the relation and then choosing ages to match would
        -- be authoring the same thing twice.
        local size, kind = rollUnit()
        local unitId = (size > 1) and (rec.id .. "-u") or nil
        if unitId then
            rec.unitId, rec.unitKind = unitId, kind
        end
        local mates = { rec }
        for _ = 2, size do
            if count >= capNow or bornThisPass >= 8 then break end
            local mate = SAO.Identity.create(nil, nil,
                origin.x, origin.y, origin.z)
            if not mate then break end
            bornThisPass = bornThisPass + 1
            pcall(function() SAO.History.generate(mate.id, mate) end)
            if arriving then
                mate.newcomer = true
                mate.arrivedAtHours = hoursNow()
            end
            mate.originRegion = origin.region
            mate.homeX, mate.homeY, mate.homeZ = origin.x, origin.y, origin.z
            mate.unitId, mate.unitKind = unitId, kind
            mates[#mates + 1] = mate
            count = count + 1
        end
        if #mates > 1 then
            local trust = UNIT_TRUST[kind] or 0.6
            for a = 1, #mates do
                for b = a + 1, #mates do
                    pcall(function()
                        SAO.Standing.bond(mates[a].id, mates[b].id)
                        SAO.Standing.adjustTrust(mates[a].id, mates[b].id,
                            trust)
                        SAO.Standing.adjustTrust(mates[b].id, mates[a].id,
                            trust)
                    end)
                end
            end
            local who = {}
            for i = 2, #mates do who[#who + 1] = mates[i].id end
            log(table.concat(who, " and ") .. " came through the first "
                .. "night with " .. rec.id .. " (" .. kind .. " of "
                .. #mates .. ", " .. count .. "/" .. capNow .. ")")
        end
    end
end

local function backfillName(rec, body)
    if rec.forename ~= "Unnamed" or not SAOJavaBridge then return end
    local ok, name = pcall(function() return SAOJavaBridge:getShellName(body) end)
    if ok and type(name) == "string" and name ~= "" then
        local sep = string.find(name, "|", 1, true)
        if sep then
            rec.forename = string.sub(name, 1, sep - 1)
            rec.surname = string.sub(name, sep + 1)
            -- [B38] A family shares a name. Genesis cannot do this -
            -- names arrive from the engine shell when a body first
            -- materialises, long after the unit was formed - so the
            -- first of a family to be named keeps theirs and the rest
            -- take it when their turn comes.
            if rec.unitId and rec.unitKind == "family" then
                for _, other in pairs(SAO.Identity.all()) do
                    if other.unitId == rec.unitId and other.id ~= rec.id
                        and other.surname and other.surname ~= ""
                        and other.forename ~= "Unnamed" then
                        rec.surname = other.surname
                        break
                    end
                end
            end
            SAO.Identity.noteRenamed()   -- [A22] name index drops
            log(rec.id .. " is " .. rec.forename .. " " .. rec.surname
                .. " of " .. tostring(rec.originRegion))
        end
    end
end

local function materializeBand(px, py, conf)
    for id, rec in pairs(SAO.Identity.all()) do
      if not rec.dead then
        local hasBody = SAO.Body.get(id) ~= nil
        local d = dist(rec.x, rec.y, px, py)
        if rec.knox then
            -- Inhabitants are never conjured ([A17]): a Knox person's
            -- body is the legacy mod's business; absence means they are
            -- elsewhere, not ours to spawn. Passive adoption handles
            -- presence; nothing here may replace them.
        elseif not hasBody and d <= conf.materialize then
            local body = SAO.Body.materialize(rec)
            if body then
                backfillName(rec, body)
                -- [B38] Age reaches the head. Once per person, the
                -- first time a body exists to carry it.
                if SAO.Appearance and SAO.Appearance.applyAge then
                    pcall(SAO.Appearance.applyAge, rec, body)
                end
                rec.backstory = nil   -- [A14]: stored prose is not a record field
                if rec.epistemicMonths == nil then
                    pcall(function() SAO.History.generate(id, rec) end)
                end
                -- The person persists: restore what they carried and were,
                -- and let the dormant hours cost what they cost (F-013).
                if rec.hibernation and SAOJavaBridge then
                    local elapsed = 0
                    pcall(function()
                        elapsed = GameTime.getInstance():getWorldAgeHours()
                            - (rec.releasedAtHours or 0)
                    end)
                    if elapsed < 0 then elapsed = 0 end
                    local okA, journal = pcall(function()
                        return SAOJavaBridge:awaken(body, rec.hibernation, elapsed)
                    end)
                    log(rec.id .. " awakens: " .. (okA and tostring(journal) or "failed"))
                end
                -- A person owns things. What they carry follows who they are:
                -- the aggressive keep a weapon to hand; everyone has a knife
                -- in the kitchen. Granted once per record, at first meeting.
                if not rec.kitGranted and not rec.hibernation and SAOJavaBridge then
                    rec.kitGranted = true
                    -- Dress the trade ([A20]): the census becomes
                    -- visible - you SEE the deputy. Fresh bodies only;
                    -- an awakened person wears what they wore.
                    local outfitName = SAO.Census and SAO.Census.outfitOf
                        and SAO.Census.outfitOf(rec.occupation) or nil
                    if outfitName then
                        pcall(function()
                            SAOJavaBridge:dressInOutfit(body, outfitName)
                        end)
                    end
                    -- The pockets of the place ([A28]): nothing is
                    -- granted. The containers around their lived-in
                    -- ground hold the engine's OWN distributed loot
                    -- (census anchoring put the deputy at the station,
                    -- so the station's real lockers are their supply);
                    -- items are MOVED, not conjured - what they carry
                    -- leaves a shelf somewhere. WHO they are decides
                    -- what they spotted, by trait and class AXES,
                    -- never profession rows. Barren surroundings mean
                    -- poor pockets - that is what desperate means.
                    local t = SAO.Disposition.traits(id)
                    local cls = SAO.Census and SAO.Census.classOf
                        and SAO.Census.classOf(rec.occupation) or nil
                    -- Day zero innocence ([A29]): before the fall,
                    -- only the duty trades go armed - a civilian does
                    -- not carry a bat to the diner. The first horrors
                    -- change who reaches for weapons, through lessons,
                    -- not through this gate.
                    local dz200 = SandboxVars
                        and SandboxVars.SurvivorAwareness
                        and SandboxVars.SurvivorAwareness.DayZero == true
                    local dutyArmed = rec.occupation == "police"
                        or rec.occupation == "soldier"
                        or rec.occupation == "veteran"
                    pcall(function()
                        if (dz200 and dutyArmed)
                            or (not dz200
                                and (t.aggression > 0.55
                                    or cls == "hardened")) then
                            SAOJavaBridge:takeWantedFromNearby(
                                body, 10, "weapon", 1)
                        end
                        SAOJavaBridge:takeWantedFromNearby(body, 10,
                            "food", 1 + math.floor(t.appetite * 2 + 0.5))
                        SAOJavaBridge:takeWantedFromNearby(
                            body, 10, "water", 1)
                        -- Everybody grabs the flashlight ([B17]).
                        SAOJavaBridge:takeWantedFromNearby(
                            body, 10, "light", 1)
                        if cls == "carer" or t.compassion > 0.55 then
                            SAOJavaBridge:takeWantedFromNearby(
                                body, 10, "medical", 2)
                        end
                        if rec.occupation == "farmer"
                            or cls == "settled" then
                            -- Farm hands spot their gear ([B4]).
                            SAOJavaBridge:takeWantedFromNearby(
                                body, 10, "seeds", 2)
                        end
                        if cls == "trades" then
                            SAOJavaBridge:takeWantedFromNearby(
                                body, 10, "tool", 1)
                            -- Builders spot materials ([B2]).
                            SAOJavaBridge:takeWantedFromNearby(
                                body, 10, "plank", 2)
                            SAOJavaBridge:takeWantedFromNearby(
                                body, 10, "nails", 1)
                        end
                        if cls == "hardened" or cls == "outdoors"
                            or t.initiative > 0.6 then
                            SAOJavaBridge:takeWantedFromNearby(
                                body, 10, "device", 1)
                        end
                        SAOJavaBridge:equipBestMelee(body)
                        -- Ownership is READ, never asserted: the radio
                        -- claim derives from what the place actually
                        -- yielded ([A27] ownsRadio).
                        rec.hasRadio = SAO.Standing.ownsRadio(id) or nil
                        -- The journal ([A24]): a written snapshot of
                        -- who they are at first meeting - claims
                        -- rendered at WRITE time (staleness is what
                        -- journals are). Loot the corpse, read the
                        -- life.
                        pcall(function()
                            local jname = (SAO.Identity.displayName(rec)
                                or "A survivor") .. "'s journal"
                            local page1 = (SAO.Census.describe(rec) or "")
                            local orig = SAO.Census.originNote
                                and SAO.Census.originNote(rec) or nil
                            if orig then
                                page1 = page1 .. "\nIt started at "
                                    .. orig .. "."
                            end
                            local page2 = SAO.History.describe(id) or ""
                            -- The era in ink ([B1]): a journal written
                            -- after the world changed for them says
                            -- so; one written in innocence carries no
                            -- such line - the absence IS the era mark.
                            local fh9 = SAO.Lessons.firstLessonHours
                                and SAO.Lessons.firstLessonHours(id) or nil
                            if fh9 then
                                page2 = page2 .. "\nDay "
                                    .. math.max(1, math.floor(fh9 / 24))
                                    .. " was when I stopped believing"
                                    .. " it would pass."
                            end
                            SAOJavaBridge:giveJournal(body, jname,
                                page1, page2)
                        end)
                        -- The rest of the pockets ([A28], same law):
                        -- the habit and the temperament SPOT what the
                        -- place holds; nothing granted. Carer medical
                        -- spotting lives in the main pulls above.
                        if SAO.Disposition.isSmoker(id) then
                            SAOJavaBridge:takeWantedFromNearby(
                                body, 10, "smokes", 2)
                        end
                        -- [B25] The bar was 0.6 where both other
                        -- identity gates use 0.5 - the midpoint of
                        -- the human envelope [0.15, 0.85] this file's
                        -- own header declares. Nothing justified the
                        -- difference, and the 0.50-0.60 band it
                        -- created was a dead zone: too quiet to play,
                        -- and shut out of `reading` too unless
                        -- disciplined. Seven people in a county of
                        -- sixty lived in that band with nothing.
                        if SAO.Disposition.traits(id).talkativeness > 0.5 then
                            SAOJavaBridge:takeWantedFromNearby(
                                body, 10, "instrument", 1)
                        end
                        -- Ownership is READ: the instrument claim
                        -- derives from what the place actually
                        -- yielded, engine display category as the
                        -- truth.
                        local carried = SAOJavaBridge:carriedDisplayCategory(
                            body, "InstrumentWeapon")
                        rec.instrument = (carried ~= nil and carried ~= "")
                            and tostring(carried) or nil
                        -- [B22] What they carry FORWARD. The same law
                        -- as the instrument above - temperament spots
                        -- what the place holds, and ownership is READ
                        -- rather than granted - extended past the two
                        -- entries it had. Most of this county has no
                        -- useful trade, and a person is not their job.
                        if SAO.Disposition.traits(id).compassion > 0.5 then
                            SAOJavaBridge:takeWantedFromNearby(
                                body, 10, "memento", 1)
                        end
                        -- [B25] The `talkativeness <= 0.6` clause is
                        -- gone. Nothing else in the identity layer is
                        -- exclusive - a keepsake already sits happily
                        -- beside either of the others - and being
                        -- talkative is no reason a disciplined person
                        -- would not keep their books. It was also
                        -- written against the same constant as the
                        -- gate above, so moving that bar alone would
                        -- have taken the book off the two most
                        -- disciplined people in the county (0.82 and
                        -- 0.81) and handed them an instrument.
                        if SAO.Disposition.traits(id).discipline > 0.5 then
                            SAOJavaBridge:takeWantedFromNearby(
                                body, 10, "reading", 1)
                        end
                        -- [B26] Both of the engine's words for a
                        -- keepsake, because the seek side already
                        -- takes either. Reading only the display
                        -- category meant a survivor could pick up a
                        -- photo album and still be recorded as
                        -- carrying nothing forward.
                        local kept = SAOJavaBridge:carriedMemento(body)
                        rec.keepsake = (kept ~= nil and kept ~= "")
                            and tostring(kept) or nil
                        local read = SAOJavaBridge:carriedDisplayCategory(
                            body, "Literature")
                        rec.reading = (read ~= nil and read ~= "")
                            and tostring(read) or nil
                    end)
                end
                SAO.Controller.adopt(rec)
                log(rec.id .. " is nearby (" .. string.format("%.0f", d) .. " tiles)")
            end
        elseif hasBody and d > conf.hibernate then
            local body = SAO.Body.get(id)
            local bd = body and dist(body:getX(), body:getY(), px, py) or d
            if bd > conf.hibernate then
                -- [B10] The wound is a fact about the PERSON: stamped
                -- on the record as they go dark, so the dormant arc
                -- can weigh it without a body to read.
                pcall(function()
                    local b15 = SAO.Body.get(id)
                    if b15 and SAOJavaBridge then
                        local bd = b15:getBodyDamage()
                        if bd and bd:getNumPartsBitten() > 0 then
                            rec.bitten = true
                            rec.bittenAtHours = hoursNow()
                        end
                        local inf = SAOJavaBridge:woundInfection(b15)
                        if inf and inf > 0 then
                            rec.woundInfected = true
                        else
                            rec.woundInfected = nil
                        end
                    end
                end)
                SAO.Controller.drop(id)
                SAO.Body.release(rec)
                log(rec.id .. " continues without you (dormant at "
                    .. rec.x .. "," .. rec.y .. ")")
            end
        end
      end
    end
end

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
-- It used to go to `homeX + ZombRand(-24, 25)`: a coordinate, not a
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
-- [B39] How far a day can reach, from the county's own option.
--
-- `chooseDayPlace` used a hardcoded 24. The screen already asks the
-- player this question - ErrandRadius: "How far a survivor looks for
-- food, water, weapons, and ammunition when need sends them
-- searching" - and it governed the live path five times and the
-- dormant path never. The same asymmetry [B39] found in Desperation,
-- one option over.
--
-- Doubled, because the two are not the same span in time: a live
-- survivor's errand is one search and a dormant survivor's day is a
-- walk. At the shipped default of 12 this is exactly the 24 that was
-- hardcoded, so nothing moves unless the player moves it - which is
-- the point of it being an option.
local DAY_REACH_FACTOR = 2

local function dayReach()
    local sv = SandboxVars and SandboxVars.SurvivorAwareness or nil
    local errand = (sv and tonumber(sv.ErrandRadius)) or 12
    return errand * DAY_REACH_FACTOR
end

local function desperationLine()
    local sv = SandboxVars and SandboxVars.SurvivorAwareness or nil
    return (sv and tonumber(sv.Desperation)) or 0.7
end

local function daysWithout(rec, field, today)
    local last = rec[field]
    if last == nil then return 0 end
    return math.max(0, today - last)
end

local function chooseDayPlace(id, rec, reach)
    if not (SAO.Places and rec.homeX) then return nil end

    local ok, places = pcall(function()
        return SAO.Places.around(rec.homeX, rec.homeY, reach)
    end)
    if not ok or not places or #places == 0 then return nil end

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

    local best, bestScore
    for _, place in ipairs(places) do
        -- [B37] What it offers TODAY, not what its rooms are. After
        -- the county loses pressure a bathroom is a dry tap.
        local now = SAO.Places.offersNow(place) or {}
        local anyNow = false
        for _ in pairs(now) do anyNow = true; break end
        if anyNow then
            local barred = false
            if myG then
                for eg, fb in pairs((b and b.factions) or {}) do
                    if eg ~= myG
                        and SAO.Standing.feudBetween(myG, eg)
                        and place.cx >= fb.minX - SAO.Standing.FEUD_DETOUR
                        and place.cx <= fb.maxX + SAO.Standing.FEUD_DETOUR
                        and place.cy >= fb.minY - SAO.Standing.FEUD_DETOUR
                        and place.cy <= fb.maxY + SAO.Standing.FEUD_DETOUR then
                        barred = true
                        break
                    end
                end
            end
            -- [B39] Somebody else's ground. Belief-gated, like
            -- every other claim in this mod: a survivor who does not
            -- KNOW a place is held walks into it, and the one who
            -- knows respects it right up until the county's own
            -- desperation line, and then does not.
            if not barred and not desperate then
                local held = nil
                pcall(function()
                    held = SAO.Perception.believesClaimed(
                        id, place.cx, place.cy)
                end)
                if held and held ~= id then barred = true end
            end
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
                    score = UNVISITED + ZombRand(100000)
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
                if dry > THIRST_PATIENCE and now.water then
                    urgency = urgency
                        + math.floor(100 * dry / THIRST_LETHAL)
                end
                if hungry > HUNGER_PATIENCE and now.food then
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
    return best
end

local function dormantLife(conf)
    local okH, hour = pcall(function() return GameTime.getInstance():getTimeOfDay() end)
    if not okH then return end
    local night = hour >= 21.0 or hour < 6.0
    for id, rec in pairs(SAO.Identity.all()) do
        if not rec.dead and not rec.knox and not SAO.Body.get(id) and rec.homeX then
            rec.nextDormantMoveAt = rec.nextDormantMoveAt or 0
            if tickCounter >= rec.nextDormantMoveAt then
                rec.nextDormantMoveAt = tickCounter + 1800 + ZombRand(1800)
                local tx, ty
                if night then
                    tx, ty = rec.homeX, rec.homeY
                else
                    if not rec.dayGoalX
                        or (math.abs(rec.x - rec.dayGoalX) < 3
                            and math.abs(rec.y - rec.dayGoalY) < 3) then
                        local reach = dayReach()
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
                        if rec.dayGoalPlaceId then
                            pcall(function()
                                local arrived = SAO.Places.at(
                                    rec.dayGoalX, rec.dayGoalY)
                                if arrived
                                    and arrived.id == rec.dayGoalPlaceId then
                                    -- [B39] They walked here.
                                    SAO.Perception.learnBuilding(id,
                                        arrived, tickCounter,
                                        "observed")
                                    -- [B37] Getting there is the
                                    -- point of having gone. A place
                                    -- with water in it is a day they
                                    -- drank; nothing else in the mod
                                    -- can say that.
                                    local day = math.floor(
                                        hoursNow() / 24.0)
                                    -- [B37] What was
                                    -- actually there when they got
                                    -- there. A remembered tap that
                                    -- has since gone dry does not
                                    -- count as having drunk, so
                                    -- thirst keeps climbing and they
                                    -- try somewhere else.
                                    local got = SAO.Places.offersNow(
                                        arrived) or {}
                                    if got.water then
                                        rec.lastWaterDay = day
                                    end
                                    if got.food then
                                        rec.lastFoodDay = day
                                    end
                                    -- [B39] And the place has that
                                    -- much less in it. Recorded only
                                    -- when they actually took
                                    -- something, so walking through a
                                    -- warehouse for the shelter does
                                    -- not empty it.
                                    if got.water or got.food then
                                        SAO.Places.take(arrived)
                                    end
                                end
                            end)
                        end
                        local chosen = chooseDayPlace(id, rec, reach)
                        if chosen then
                            rec.dayGoalX, rec.dayGoalY = chosen.cx, chosen.cy
                            rec.dayGoalPlaceId = chosen.id
                        else
                            -- Wilderness, or a neighbourhood whose
                            -- every place is enemy ground. Nothing to
                            -- walk to, so the old drift stands.
                            rec.dayGoalX = rec.homeX
                                + ZombRand(-reach, reach + 1)
                            rec.dayGoalY = rec.homeY
                                + ZombRand(-reach, reach + 1)
                            rec.dayGoalPlaceId = nil
                        end
                    end
                    tx, ty = rec.dayGoalX, rec.dayGoalY
                end
                local dx, dy = tx - rec.x, ty - rec.y
                local len = math.sqrt(dx * dx + dy * dy)
                if len > 1.0 then
                    local step = math.min(4, len)
                    rec.x = math.floor(rec.x + dx / len * step + 0.5)
                    rec.y = math.floor(rec.y + dy / len * step + 0.5)
                end
                -- A day's walking teaches places ([A15]): drifting past a
                -- held claim leaves the coarse knowledge a passerby would
                -- have - the dormant learn the county too.
                -- [B42] The rule itself now lives in Perception and
                -- both halves read it. It was written here, inside a
                -- loop that gates on `not SAO.Body.get(id)`, so only
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

-- The county collects ([A20], DR-011): dormant life carries a small
-- daily risk - the tax binds the unwatched too. Modulated by what the
-- operator named load-bearing: hard claims held, class, company,
-- seasoning. A death out there has no corpse and no witness; WORD
-- finds the bonded and the company a day or two later, at told
-- weight, through the existing news machinery. Sandbox DormantRisk
-- scales it; 0 disables.
local function dormantAttrition()
    local sv = SandboxVars and SandboxVars.SurvivorAwareness or nil
    local riskMult = sv and tonumber(sv.DormantRisk) or 1.0
    if riskMult <= 0 then return end
    -- Winter bites ([A24]): the county is harder in the cold months.
    -- Engine month (0-11): Dec/Jan/Feb x1.5, Nov/Mar x1.25, else x1.0.
    pcall(function()
        local month = GameTime.getInstance():getMonth()
        if month == 11 or month == 0 or month == 1 then
            riskMult = riskMult * 1.5
        elseif month == 10 or month == 2 then
            riskMult = riskMult * 1.25
        end
    end)
    local okH, nowHours = pcall(function()
        return GameTime.getInstance():getWorldAgeHours()
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
            -- Word finds them: past-due news reaches the bonded and
            -- the company, once.
            if rec.deathNewsAt and not rec.deathNewsDelivered
                and nowHours >= rec.deathNewsAt then
                rec.deathNewsDelivered = true
                local hearers = {}
                local bondedKey = SAO.Standing.bondedWith(id)
                if bondedKey then hearers[bondedKey] = true end
                for _, fid in ipairs(SAO.Standing.fellowsOf(id)) do
                    hearers[fid] = true
                end
                local name = rec.forename
                for hearer in pairs(hearers) do
                    local hb = SAO.Perception.beliefs[hearer]
                    if hb and name then
                        local pb = hb.people[name]
                        if pb then
                            pb.dead = true
                            if rec.turnedDormant then pb.turned = true end
                        else
                            hb.people[name] = {
                                x = rec.x, y = rec.y, dist = 999,
                                at = tickCounter, source = "told",
                                dead = true,
                                turned = rec.turnedDormant or nil,
                            }
                        end
                    end
                    if SAO.Perception.deathNewsHandler and name then
                        pcall(SAO.Perception.deathNewsHandler,
                            hearer, name, tickCounter)
                    end
                end
                log("word finds the county: " .. id .. " never came back")
            end
        elseif not rec.knox and not SAO.Body.get(id) then
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
                if SAO.Lessons.has(id, "measure-the-danger") then
                    risk = risk * 0.5
                end
                if SAO.Lessons.has(id, "routine-is-armor") then
                    risk = risk * 0.7
                end
                local cls = SAO.Census and SAO.Census.classOf
                    and SAO.Census.classOf(rec.occupation) or nil
                if cls == "hardened" then risk = risk * 0.7
                elseif cls == "settled" then risk = risk * 1.3 end
                -- [B10] The bite follows you into the dark: a person
                -- who went dormant bitten is dying out there, and the
                -- odds are the engine's own turning odds, not a
                -- number of mine - steep, and steeper as the days
                -- pass. An infected wound argues more slowly.
                if rec.bitten then
                    local since = hoursNow() - (rec.bittenAtHours or 0)
                    risk = risk + 0.10 + math.min(0.5, since / 480)
                elseif rec.woundInfected then
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
                if pg3 and riskMult > 1.0 and SAO.Standing.hearthOf then
                    local hh3 = SAO.Standing.hearthOf(pg3)
                    if hh3 and hh3.burning then risk = risk * 0.8 end
                end
                if SAO.Standing.groupOf(id) then risk = risk * 0.6 end
                if (rec.contactMonths or 0) > 3 then risk = risk * 0.7 end
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
                if ZombRand(100000) < math.floor(risk * 100000) then
                    local deadGroup = SAO.Standing.groupOf(id)
                    -- [B10] The cause is the truth of it: a bite
                    -- kills as a bite, and the lessons machinery
                    -- teaches accordingly. Everything after - news,
                    -- grief, the election - is the same for any death.
                    if rec.bitten then
                        -- [B10] A bite death IS a turning, and people
                        -- know what a bite means. No body is
                        -- fabricated out there - only the claim, which
                        -- rides the word when it finds the county.
                        rec.turnedDormant = true
                        log(rec.id .. " died of the bite, alone")
                    end
                    SAO.Identity.markDead(rec, tickCounter,
                        rec.bitten and "zombie" or "the county took them")
                    rec.deathNewsAt = nowHours + 24 + ZombRand(48)
                    if deadGroup
                        and SAO.Standing.leaderOf(deadGroup) == id then
                        SAO.Standing.electLeader(deadGroup)
                    end
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
-- pairKey -> frame; a MEETING is minutes, not a 240-frame pulse (~4s
-- at 60fps)
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

-- One meeting per pair per roughly thirty to sixty seconds at 60fps of
-- adjacency. Without it the four-second population pulse compounded
-- trust about forty times the observed world's encounter rate
-- ([A13]) - so this is not a cadence, it is the correction for one.
local MEET_COOLDOWN = 1800

-- What a road meeting is worth. Deliberately tiny: trust is built by
-- crossing paths repeatedly over weeks, not by one conversation.
local ROAD_TRUST = 0.005

-- How far the abstraction steps a hostile pair apart. Nobody dies
-- unwitnessed, so the only thing an encounter between enemies does is
-- put ground between them.
local WIDE_BERTH = 3

-- [B51] `dormantLastMet` is keyed by a PAIR and nothing has ever
-- removed one. A pair with a dead member can never meet again, so
-- the entry is read by nobody for the rest of the session. Called
-- from `Identity.markDead`, which every death path funnels through.
function Pop.forgetPairs(id)
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

local function dormantEncounters()
    local sv = SandboxVars and SandboxVars.SurvivorAwareness or nil
    local companyAt = (sv and tonumber(sv.TrustToCompany)) or 0.5
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
        if not rec.dead and not SAO.Body.get(id) then
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
      elseif not recA.dead and not SAO.Body.get(idA) then
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
                -- One meeting per pair per ~30-60s at 60fps of
                -- adjacency: without this the 240-frame population
                -- pulse compounded trust ~40x the
                -- observed world's encounter rate ([A13] find).
                dormantLastMet[pairKey] = tickCounter
                    + MEET_COOLDOWN + ZombRand(MEET_COOLDOWN)
                if SAO.Standing.isHostileTo(idA, idB)
                    or SAO.Standing.isHostileTo(idB, idA) then
                    -- A wide berth: the abstraction steps them apart.
                    recB.x = recB.x
                        + (dx < 0 and -WIDE_BERTH or WIDE_BERTH)
                    log(idA .. " and " .. idB
                        .. " crossed paths dormant - hostile, kept apart")
                else
                    SAO.Standing.adjustTrust(idA, idB, ROAD_TRUST)
                    SAO.Standing.adjustTrust(idB, idA, ROAD_TRUST)
                    -- A road meeting is a conversation ([A17]): one
                    -- lesson may change hands, and the full word-of-mouth
                    -- verb runs both ways - places, faction names, and
                    -- the introduction travel the roads at told weight
                    -- (stale threat beliefs age out on their own horizon
                    -- and never travel). Knox inhabitants receive and
                    -- carry this knowledge purely through conversation.
                    local taughtAB = SAO.Lessons.tellOne(idA, idB)
                    if not taughtAB then SAO.Lessons.tellOne(idB, idA) end
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
                        SAO.Perception.tell(idA, idB, tickCounter)
                        SAO.Perception.tell(idB, idA, tickCounter)
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
                    -- Houses can break on the roads too ([A22]): a
                    -- same-group dormant meeting is an election moment
                    -- like any other.
                    if gA and gA == gB then
                        SAO.Standing.electLeader(gA)
                        local newHouse, core, n =
                            SAO.Standing.checkSchism(gA)
                        if newHouse then
                            log("SCHISM on the road: " .. tostring(core)
                                .. " leads " .. tostring(n) .. " out of "
                                .. tostring(SAO.Standing.factionName(gA)
                                    or gA))
                        end
                    end
                    if not (gA and gB)
                        and SAO.Standing.trust(idA, idB) > roadBar
                        and SAO.Standing.trust(idB, idA) > roadBar then
                        local groupName = gA or gB or ("company-" .. idA)
                        if SAO.Standing.circleRefuses(idA, groupName)
                            or SAO.Standing.circleRefuses(idB, groupName) then
                            log(idA .. " and " .. idB
                                .. " part ways friendly - somebody keeps"
                                .. " their own company")
                        else
                            SAO.Standing.joinGroup(idA, groupName)
                            SAO.Standing.joinGroup(idB, groupName)
                            -- [B47] 120 of these in one session, and
                            -- they never stop - the dormant half meets
                            -- people forever.
                            tally("kept company on the road")
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

-- The Knox base seed ([A19], DR-009 read-only): the legacy mod's own
-- world store names each survivor's group and each group's base. An
-- adoptee's HOME and their place-belief of their own base come from
-- there - what Nicole knows best is where Nicole lives, and the roads
-- ([A17]) can now carry it. Their store is never written.
local function seedKnoxBase(id, rec, kid)
    local okD, data = pcall(function()
        return ModData.getOrCreate("KnoxSurvivorsWorld")
    end)
    if not okD or type(data) ~= "table" then return end
    local survivors = data.survivors or {}
    local entry = survivors[kid] or survivors[tonumber(kid)] or nil
    if not entry then return end
    -- [B42] [A20] REVERSED, on operator direction and on DR-009,
    -- which it had always contradicted: "where the two systems collide
    -- SAO's reading overrides on SAO's side."
    --
    -- What stood here read a foreign profile's coarse archetype,
    -- mapped it onto a census key through a table written by hand -
    -- its own comment said "by closest life-shape" - and then did two
    -- things with it. It overwrote `rec.occupation`, which DR-009 says
    -- it may not. And it cleared `rec.occupationPresumed`, which is
    -- worse and was the part nobody was looking at.
    --
    -- That flag is this project's honesty about its own guessing.
    -- `Census.describe` says "carries themselves like a nurse" while it
    -- is set and "was a nurse in Riverside when it started" once it is
    -- not, and `Census.originNote` refuses to invent a beginning for a
    -- presumed trade at all ([A22]: "we do not put a beginning in the
    -- mouth of someone whose past we only guessed at"). So clearing it
    -- did not import a fact - it LAUNDERED OUR OWN GUESS INTO ONE, on
    -- the strength of thirteen authored equivalences.
    --
    -- Their profile is still read: the trust rows below and the camp
    -- come from it, because those are theirs to state. Who somebody
    -- was is ours to presume, and to say we presumed it.
    -- Their people came with them ([A21]): the legacy store keeps
    -- DIRECTIONAL relationship rows ("kid|kid" -> weight). Import this
    -- adoptee's outbound rows ONCE, at half-strength (weight/100,
    -- clamped to +-0.8) - Nicole trusts her squadmates in our economy
    -- too, but nothing imported can outweigh what gets earned here.
    -- Read-only; rows toward non-survivor targets (the player's KS-side
    -- id) are skipped - a named gap, not a guess.
    if not rec.ksTrustImported then
        rec.ksTrustImported = true
        local rels = data.relationships or {}
        local prefix = tostring(kid) .. "|"
        local imported = 0
        for key, row in pairs(rels) do
            if imported >= 20 then break end
            if tostring(key):sub(1, #prefix) == prefix
                and type(row) == "table" and tonumber(row.weight) then
                local targetKid = tostring(key):sub(#prefix + 1)
                if survivors[targetKid] then
                    local delta = math.max(-0.8, math.min(0.8,
                        tonumber(row.weight) / 100.0))
                    if delta ~= 0 then
                        SAO.Standing.adjustTrust(id, "ks:" .. targetKid, delta)
                        imported = imported + 1
                    end
                end
            end
        end
        if imported > 0 then
            log(id .. " brought their people with them ("
                .. imported .. " standing relations imported)")
        end
    end
    -- The base seed needs a group; solo lives stop here with their
    -- truth already kept ([A20] guard split).
    if not entry.groupId then return end
    local group = (data.groups or {})[entry.groupId]
    local base = group and group.baseId
        and (data.bases or {})[group.baseId] or nil
    if not base or not base.x then return end
    if not rec.homeX then
        rec.homeX, rec.homeY, rec.homeZ = base.x, base.y, base.z or 0
    end
    local bounds = {
        minX = base.x - 6, minY = base.y - 6,
        maxX = base.x + 6, maxY = base.y + 6,
    }
    pcall(function()
        -- [B39] Their OWN camp. The registry is the evidence here
        -- because they live in it - which is the one case where
        -- reading a table and having been somewhere are the same
        -- fact, and it is worth saying so rather than assuming it.
        SAO.Perception.learnPlace(id, "ks-camp:" .. tostring(group.baseId
            or entry.groupId), bounds, "observed")
    end)
    log(id .. " knows their own camp at " .. base.x .. "," .. base.y)
end

-- Inhabitation ([A17], DR-009): the Knox people already living in this
-- save ARE the population. A live Knox human seen in the world gets an
-- SAO record - id "ks:<name>", months-alive from the engine's own
-- hours-survived, contact-scaled past - and stands in the economy as a
-- PASSIVE agent: never driven, never released, never rewritten on the
-- KS side. Their body registers for the exchange; their death mourns.
local function inhabitKnox()
    if not SAOJavaBridge then return end
    local me = getSpecificPlayer(0)
    if not me then return end
    local ok, listed = pcall(function()
        return SAOJavaBridge:listKnoxHumans(me)
    end)
    if not ok or type(listed) ~= "string" then return end
    local seen = {}
    if listed ~= "" then
        for entry in string.gmatch(listed, "[^|]+") do
            local kid, name, kx, ky, hours = string.match(entry,
                "^([^:]+):([^:]+):(%-?%d+):(%-?%d+):(%d+)$")
            if kid and name then
                local id = "ks:" .. kid
                seen[id] = true
                -- The rename owes nothing ([A19]): a save that met this
                -- person under the [A17] name-keyed scheme holds their
                -- trust web at "ks:<name>". The kid-keyed record absorbs
                -- it once - standing (both directions), beliefs, and the
                -- legacy record's own settled fields - then the orphan
                -- is removed.
                -- [A24]: legacy name-keyed ids may be forename-only
                -- (pre-full-name era) or full-name - try both.
                local forenameOnly = string.match(name, "^([^ ]+)") or name
                local legacyId = "ks:" .. name
                if not SAO.Identity.get(legacyId) then
                    local alt = "ks:" .. forenameOnly
                    if SAO.Identity.get(alt) then legacyId = alt end
                end
                if legacyId ~= id then
                    local legacy = SAO.Identity.get(legacyId)
                    if legacy then
                        pcall(function()
                            SAO.Standing.migrateKey(legacyId, id)
                            if SAO.Perception.beliefs[legacyId]
                                and not SAO.Perception.beliefs[id] then
                                SAO.Perception.beliefs[id] =
                                    SAO.Perception.beliefs[legacyId]
                            end
                            SAO.Perception.beliefs[legacyId] = nil
                            if SAO.Identity.get(id) then
                                -- Both exist somehow: keep the kid-keyed
                                -- record, drop the orphan.
                                SAO.Identity.remove(legacyId)
                            else
                                -- Absorb by rebirth: the legacy record
                                -- BECOMES the kid-keyed one - history,
                                -- lessons, and all.
                                SAO.Identity.rekey(legacyId, id)
                            end
                            log(legacyId .. " -> " .. id
                                .. " (the rename owes nothing)")
                        end)
                    end
                end
                local rec = SAO.Identity.ensure(id, name, "", kx, ky, 0)
                if rec and not rec.knox then
                    rec.knox = true
                    local monthsAlive = (tonumber(hours) or 0) / (24.0 * 30.0)
                    seedKnoxBase(id, rec, kid)
                    pcall(function()
                        SAO.History.generate(id, rec, math.max(0.1, monthsAlive))
                    end)
                    log(id .. " inhabits the economy ("
                        .. string.format("%.1f", monthsAlive) .. " months survived)")
                end
                if rec then
                    -- [A22]: records adopted BEFORE the import/seed
                    -- eras catch up here - seedKnoxBase is guarded
                    -- per-feature (ksTrustImported, homeX, occupation
                    -- same-value), so this is a no-op once caught up.
                    if rec.knox and not rec.ksTrustImported then
                        seedKnoxBase(id, rec, kid)
                    end
                    -- [B42] The residue of [A20], in worlds that
                    -- already ran it. `H.generate` returns early once a
                    -- record has a past, so reversing the code does not
                    -- reach anyone already adopted: they keep an
                    -- occupation that came from a foreign archetype
                    -- through a hand-written table, asserted as fact.
                    --
                    -- They are identifiable exactly. The census flags
                    -- EVERY Knox draw as presumed, so a Knox record
                    -- holding an occupation with no flag can only have
                    -- got it from the seed that DR-012 removed. The
                    -- occupation itself is left alone - rewriting who
                    -- somebody is mid-save is the one thing worth
                    -- avoiding here - and only the warning label goes
                    -- back on, which is what [A22] wanted all along.
                    if rec.knox and rec.occupation
                        and not rec.occupationPresumed then
                        rec.occupationPresumed = true
                        log(id .. " was never known to have been a "
                            .. tostring(rec.occupation)
                            .. " - that was read off a legacy archetype;"
                            .. " the county presumes it now")
                    end
                    rec.x, rec.y = tonumber(kx), tonumber(ky)
                    local okB, kbody = pcall(function()
                        return SAOJavaBridge:knoxBodyByName(me, name)
                    end)
                    -- forename stays the belief-level name; the record id
                    -- is theirs for good.

                    if okB and kbody then
                        SAO.Body.knox[id] = kbody
                        SAO.Controller.adoptPassive(rec)
                    end
                end
            end
        end
    end
    -- Bodies that left the cell (or died) fall out of the live registry;
    -- records persist, deaths are noticed by the passive pass.
    for id in pairs(SAO.Body.knox) do
        if not seen[id] then
            SAO.Body.knox[id] = nil
        end
    end
end

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
        return GameTime.getInstance():getWorldAgeHours()
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
local BAND_PATIENCE = 15   -- passes (~60s at 60fps) before saying so

local function populationTick()
    tickCounter = tickCounter + 1
    if tickCounter % TICK_INTERVAL ~= 0 then return end
    local conf = cfg()
    if not conf.enable then return end
    local booting = not booted
    booted = true

    -- The county does not stop for anyone's death ([A17]): genesis,
    -- dormant days, and road meetings run playerless; only the presence
    -- band needs somebody to be present around.
    -- Bulkheads ([A21]): each subsystem behind its own pcall and
    -- fault counter - a broken seam disables ITSELF after 3 faults;
    -- the rest of the county keeps moving. The names make the log
    -- legible at a glance.
    runSub("genesis", ensurePopulation, conf)
    runSub("inhabit", inhabitKnox)
    runSub("dormant-life", dormantLife, conf)
    runSub("attrition", dormantAttrition)
    -- Time softens ([B8]): the county's feelings age once a day,
    -- inside the same bulkheaded rotation as everything else.
    runSub("drift", function()
        local moved = SAO.Standing.driftStandings()
        if moved and moved > 0 then
            log("time softens " .. moved .. " old feelings")
        end
    end)
    runSub("encounters", dormantEncounters)
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

Events.OnTick.Remove(onTick)
Events.OnTick.Add(onTick)

log("population module loaded")

return Pop
