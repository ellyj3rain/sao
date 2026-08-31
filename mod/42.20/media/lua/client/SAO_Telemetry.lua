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
        return GameTime.getInstance():getWorldAgeHours()
    end)
    fields.hours = ok and h or 0
    fields.day = math.floor((ok and h or 0) / 24.0)
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

-- The county once a day, laid beside the events rather than instead
-- of them. Counts only - anything per-person is an event.
function T.county()
    if not on() then return end
    local living, dead, lessons, units, dry, hungry = 0, 0, 0, 0, 0, 0
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
            end
        end
    end)
    if not ok then return end
    T.event("county", {
        living = living, dead = dead,
        lessonsHeld = lessons,
        inUnits = units,
        perPerson = (living > 0) and (lessons / living) or 0,
    })
    T.flush()
end

SAO.Log.line("TELEM", "telemetry module loaded (writing " .. FILE
    .. " when enabled)")

return T
