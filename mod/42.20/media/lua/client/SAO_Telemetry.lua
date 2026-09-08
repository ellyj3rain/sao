-- SAO_Telemetry - the county, as data.
--
-- [B38]. The operator's direction: start measuring - decisions run
-- on measurable traits, and what people learn is data.
--
-- Nothing was missing from the RECORD. `lessonMeta[key]` has carried
-- `{ src, of, atHours }` per person per lesson since [A17] - a
-- timestamped, provenanced learning history for every survivor in the
-- county. Nothing has ever read it. The measurement gap was never
-- collection; it was that the collected thing never left the process.
--
-- So this is an instrument and not a feature. It writes what the
-- county already knows about itself to a file the operator can open,
-- and changes no behaviour whatsoever - a survivor with telemetry off
-- lives exactly the life a survivor with it on lives.
--
-- EVENT-SOURCED, deliberately. A daily snapshot of two hundred people
-- answers "what is the county like now" and destroys "what happened".
-- Learning is the thing being measured and learning is an event, so
-- the stream is events and the daily line is a summary laid beside
-- them, not instead of them.

SAO = SAO or {}
SAO.Telemetry = SAO.Telemetry or {}
local T = SAO.Telemetry

local FILE = "SAO_telemetry.jsonl"
-- Opening and closing a file per event would cost more than everything
-- being measured. Buffered, flushed on the day tick or when the buffer
-- fills, so a crash loses at most this much.
local FLUSH_AT = 64

T.buffer = T.buffer or {}
T.written = T.written or 0
T.enabled = nil

local function on()
    if T.enabled == nil then
        local sv = SandboxVars and SandboxVars.SurvivorAwareness or nil
        T.enabled = (sv == nil) or (sv.Telemetry ~= false)
    end
    return T.enabled
end

-- A flat JSON object. Values are strings, numbers or booleans only -
-- anything nested belongs in its own event rather than in a column.
local function esc(s)
    s = tostring(s)
    s = string.gsub(s, "\\", "\\\\")
    s = string.gsub(s, '"', '\\"')
    s = string.gsub(s, "\n", " ")
    return s
end

local function encode(fields)
    local parts, keys = {}, {}
    for k in pairs(fields) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local v = fields[k]
        local out
        if type(v) == "number" then
            -- Integers stay integers; a day count reading 12.0 in a
            -- column of 12s is noise in every tool that opens this.
            if v == math.floor(v) then
                out = string.format("%d", v)
            else
                out = string.format("%.4f", v)
            end
        elseif type(v) == "boolean" then
            out = v and "true" or "false"
        else
            out = '"' .. esc(v) .. '"'
        end
        parts[#parts + 1] = '"' .. esc(k) .. '":' .. out
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

function T.flush()
    if #T.buffer == 0 then return end
    local lines = T.buffer
    T.buffer = {}
    pcall(function()
        local writer = getFileWriter(FILE, true, true)
        if not writer then return end
        for _, line in ipairs(lines) do
            writer:write(line .. "\r\n")
        end
        writer:close()
        T.written = T.written + #lines
    end)
end

-- Every event carries WHEN in the world's own clock, because the
-- whole value of this is longitudinal.
function T.event(kind, fields)
    if not on() then return end
    fields = fields or {}
    fields.kind = kind
    local ok, h = pcall(function()
        return SAO.History.countyHours()
    end)
    fields.hours = ok and h or 0
    fields.day = math.floor((ok and h or 0) / 24.0)
    -- [C65] Which run this line belongs to, while a run is open.
    --
    -- A trajectory is only a trajectory if you can tell where one
    -- ends and the next begins. The file is append-only across every
    -- session on this machine, so without this the lines from three
    -- different counties interleave into one stream that reads like a
    -- single county behaving impossibly. Absent outside a run, which
    -- is what live play is.
    if T.runId then fields.run = T.runId end
    T.buffer[#T.buffer + 1] = encode(fields)
    if #T.buffer >= FLUSH_AT then T.flush() end
end

-- Who somebody was when the event happened. A learning event whose
-- subject cannot be characterised is a timestamp and nothing else.
function T.describe(id)
    local out = { who = tostring(id) }
    local rec = SAO.Identity and SAO.Identity.get and SAO.Identity.get(id)
    if not rec then return out end
    out.occupation = tostring(rec.occupation or "unknown")
    out.region = tostring(rec.originRegion or "unknown")
    out.months = tonumber(rec.contactMonths) or 0
    out.unit = tostring(rec.unitKind or "alone")
    -- [B40] Did their life and their place match on the first day?
    if rec.originAnchored then out.startedAtWork = true end
    -- [B41] The object itself, not a flag. Measurable, so what the
    -- county keeps can be counted rather than guessed at.
    if rec.keepsake then out.keepsake = tostring(rec.keepsake) end
    pcall(function() out.age = SAO.History.ageOf(id) end)
    pcall(function() out.born = SAO.History.birthYearOf(id) end)
    -- [B39] The war their age actually put them in, if their life
    -- did. Measurable rather than only true.
    pcall(function()
        local war = SAO.History.servedIn(id, rec.occupation)
        if war then out.war = war end
    end)
    pcall(function()
        out.class = tostring(SAO.Census.classOf(rec.occupation) or "trades")
    end)
    pcall(function()
        local g = SAO.Standing.groupOf(id)
        if g then out.company = tostring(g) end
    end)
    return out
end

-- A lesson landing is the event this whole instrument exists for:
-- WHAT was learned, at what weight, HOW it was come by, and when.
function T.learned(id, key, weight, src, of)
    if not on() then return end
    local f = T.describe(id)
    f.lesson = tostring(key)
    f.weight = tonumber(weight) or 0
    f.via = tostring(src or "unknown")
    if of then f.cost = tostring(of) end
    T.event("learned", f)
end

function T.died(id, cause)
    if not on() then return end
    local f = T.describe(id)
    f.cause = tostring(cause or "unknown")
    T.event("died", f)
end

-- [C65] A run opens and closes, and carries what it was run under.
--
-- A model fitted to these trajectories has to condition on the
-- circumstances that produced them, and every one of those is a
-- sandbox dial or a fact about the save. None of it is derivable
-- afterwards from the county lines themselves: two runs with the same
-- population curve can have had opposite risk settings.
--
-- The identifier is stored by the caller, not made here, because a
-- run that is resumed across a reload is the same run and this module
-- does not know that. It only stamps what it is told.
function T.run(phase, fields)
    if not on() then return end
    fields = fields or {}
    fields.phase = tostring(phase)
    T.event("run", fields)
    T.flush()
end

-- What a run was run under, read off the sandbox and the record.
-- Returns a flat table; the caller adds the run identifier and the
-- days owed, which are its own.
function T.conditions()
    local out = {}
    local sv = SandboxVars and SandboxVars.SurvivorAwareness or nil
    if sv then
        -- Every fallback here is the number `sandbox-options.txt`
        -- declares, not a zero. Border 33 refuses any other value and
        -- it caught five of these: a run whose dials were left alone
        -- would have been recorded as having had desperation 0 and no
        -- population target, and a model fitted to that would have
        -- learned the wrong conditioning for the commonest case there
        -- is.
        out.dormantRisk = tonumber(sv.DormantRisk) or 1.0
        out.trustToCompany = tonumber(sv.TrustToCompany) or 0.5
        out.desperation = tonumber(sv.Desperation) or 0.7
        out.refillDays = tonumber(sv.RefillDays) or 2.0
        out.roadTraffic = tonumber(sv.RoadTraffic) or 2
        out.populationGoverned = sv.PopulationGoverned == true
        out.population = tonumber(sv.Population) or 216
        out.newcomersGoverned = sv.NewcomersGoverned == true
        out.newcomers = tonumber(sv.Newcomers) or 500
        out.dayZero = sv.DayZero == true
    end
    pcall(function()
        local gt = GameTime.getInstance()
        out.startYear = gt:getStartYear()
        out.startMonth = gt:getStartMonth()
        out.startDay = gt:getStartDay()
    end)
    pcall(function() out.daysOwed = SAO.History.daysOwed() end)
    return out
end

-- The county as one line, laid beside the events rather than instead
-- of them. Counts only - anything per-person is an event.
--
-- [C65] This said "once a day" and its only caller was `bootDigest`,
-- which runs on the first population tick of a session and never
-- again. So in live play it is once per load, and the sentence
-- describing it had been wrong since [B38]. [C45]'s years pass calls
-- it once per simulated day, which is what makes a span of years a
-- trajectory rather than an endpoint. Giving live play a real daily
-- hook is a separate change and is not made here.
function T.county()
    if not on() then return end
    local living, dead, lessons, units = 0, 0, 0, 0
    -- [C65] `dry` and `hungry` were declared here and never assigned
    -- or emitted, so the county line said nothing about need - which
    -- is the pressure that drives most of what the county does.
    -- Counted as PEOPLE who have gone a day or more without, plus the
    -- worst case, because the tail is what kills and the mean hides
    -- it. No threshold is invented here: the patience constants
    -- belong to the attrition roll and stay there.
    local dry, hungry, dryMax, hungryMax = 0, 0, 0, 0
    -- [C65] What the county holds and how shut it is. Both are the
    -- outcome the years are run to produce, and neither reached the
    -- record of a run.
    local groups, grouped, claims, waysIn, waysShut = {}, 0, 0, 0, 0
    local groupCount, largest = 0, 0
    local today = 0
    pcall(function()
        today = math.floor(SAO.History.countyHours() / 24.0)
    end)
    local ok = pcall(function()
        for id, rec in pairs(SAO.Identity.all()) do
            if rec.dead then
                dead = dead + 1
            else
                living = living + 1
                if rec.unitId then units = units + 1 end
                for _ in pairs(rec.lessonsKnown or {}) do
                    lessons = lessons + 1
                end
                local w = tonumber(rec.lastWaterDay)
                if w and today - w >= 1 then
                    dry = dry + 1
                    if today - w > dryMax then dryMax = today - w end
                end
                local f = tonumber(rec.lastFoodDay)
                if f and today - f >= 1 then
                    hungry = hungry + 1
                    if today - f > hungryMax then hungryMax = today - f end
                end
                local g = SAO.Standing and SAO.Standing.groupOf
                    and SAO.Standing.groupOf(id) or nil
                if g then
                    grouped = grouped + 1
                    groups[g] = (groups[g] or 0) + 1
                end
                if SAO.Standing and SAO.Standing.claimOf
                    and SAO.Standing.claimOf(id) then
                    claims = claims + 1
                end
                -- [C46] surveyed this and only the panel ever read it.
                local ways = tonumber(rec.waysIntoHome)
                if ways then
                    waysIn = waysIn + ways
                    waysShut = waysShut + (tonumber(rec.boardedAtHome) or 0)
                end
            end
        end
        for _, n in pairs(groups) do
            groupCount = groupCount + 1
            if n > largest then largest = n end
        end
    end)
    if not ok then return end
    T.event("county", {
        living = living, dead = dead,
        lessonsHeld = lessons,
        inUnits = units,
        perPerson = (living > 0) and (lessons / living) or 0,
        dry = dry, dryDaysMax = dryMax,
        hungry = hungry, hungryDaysMax = hungryMax,
        groups = groupCount, grouped = grouped, largestGroup = largest,
        claimsHeld = claims,
        waysIn = waysIn, waysShut = waysShut,
    })
    -- [C16] The dead census (DR-021's instrument): raw counts from
    -- the bridge; density and projection derived HERE with the
    -- assumption carried by the field names. loadedDensityPerK is
    -- crowd per thousand loaded tiles; mapProjection assumes the
    -- loaded area samples the map, which oversamples wherever the
    -- player lingers - ratification reads many lines, never one.
    pcall(function()
        local me = getSpecificPlayer(0)
        if not me or not SAOJavaBridge then return end
        local s = SAOJavaBridge:deadCensus(me)
        if type(s) ~= "string" or s == "" then return end
        local crowd = tonumber(s:match("crowd=(%d+)"))
        local marked = tonumber(s:match("marked=(%d+)"))
        local loaded = tonumber(s:match("loadedTiles=(%d+)"))
        local mapT = tonumber(s:match("mapTiles=(%d+)"))
        if not crowd or not loaded or loaded <= 0 then return end
        local perK = crowd * 1000.0 / loaded
        T.event("deadcensus", {
            crowd = crowd,
            markedBodies = marked or 0,
            loadedTiles = loaded,
            mapTiles = mapT or 0,
            loadedDensityPerK = perK,
            mapProjection = (mapT and mapT > 0)
                and math.floor(perK * mapT / 1000.0) or 0,
        })
    end)
    T.flush()
end

SAO.Log.line("TELEM", "telemetry module loaded (writing " .. FILE
    .. " when enabled)")

return T
