-- SAO_Lessons - survival knowledge with provenance (DR-006 S2).
-- ---------------------------------------------------------------------------
-- A lesson is a named piece of survival knowledge. Weight is provenance:
-- lived 1.0, witnessed 0.6, told 0.4 - the ladder this framework already
-- speaks in standing and perception. Lessons echo into traits (bounded at
-- the disposition primitive alongside the formative past) and the
-- sharpest touch decisions directly through the query API below.
--
-- Storage on the record: rec.lessonsKnown = { [key] = weight (max-merged) },
-- rec.lessonEchoes = summed trait deltas scaled by weight. [A14]'s plain
-- rec.lessons list migrates on first touch at lived weight.

SAO = SAO or {}
SAO.Lessons = SAO.Lessons or {}
local L = SAO.Lessons

-- [B47] One door out: everything this module says goes
-- through the shared logger.
local function log(msg) SAO.Log.line("LESSON", msg) end

-- The registry. Echoes are at LIVED weight; acquisition scales them.
L.REGISTRY = {
    ["measure-the-danger"] = {
        echoes = { nerve = -0.04, selfPreservation = 0.06 },
        line = "The danger is always closer than it seems.",
    },
    ["claimed-places-bite"] = {
        echoes = { discipline = 0.03 },
        line = "Taking from a claimed place costs more than it gives.",
    },
    ["noise-is-a-debt"] = {
        echoes = {},
        line = "Every loud thing is borrowed trouble.",
    },
    ["people-are-worth-it"] = {
        echoes = { compassion = 0.05 },
        line = "Help people. It comes back.",
    },
    ["routine-is-armor"] = {
        echoes = { initiative = -0.04, discipline = 0.04 },
        line = "Keep the routine. The routine keeps you.",
    },
    ["doors-decide-lives"] = {
        echoes = {},
        line = "Who you let in decides everything.",
    },
    ["running-has-a-price"] = {
        echoes = { compassion = 0.03 },
        line = "Run TOWARD someone, never just away.",
    },
    ["bind-wounds-fast"] = {
        echoes = { selfPreservation = 0.04 },
        line = "A scratch untreated is a grave half-dug.",
    },
    ["the-county-collects"] = {
        echoes = { selfPreservation = 0.03 },
        line = "Nobody's luck holds. Plan like it won't.",
    },
    ["trust-carefully"] = {
        echoes = { selfPreservation = 0.04, compassion = -0.03 },
        line = "Trust is spent, not given.",
    },
    -- Trauma claims (S7): minted only by losing a BONDED partner, forked
    -- once by disposition at the moment of loss. Full lived weight.
    ["nothing-left-to-lose"] = {
        echoes = { aggression = 0.10, selfPreservation = -0.06 },
        line = "They took everything already. Let them try me.",
    },
    ["never-again-that-close"] = {
        echoes = { nerve = -0.10, selfPreservation = 0.10 },
        line = "Never again that close. To anyone.",
    },
}

-- Cause of death -> the lesson a death teaches those who learn of it.
L.CAUSE_LESSONS = {
    combat = "measure-the-danger",
    bleeding = "bind-wounds-fast",
    unknown = "the-county-collects",
}

-- F-038: the cause vocabulary outgrew the exact map ("killed by <name>",
-- "the county took them") and those graves taught NOTHING. Normalize:
-- exact match, then the murder prefix (a killed friend teaches
-- trust-carefully - people did this), then the default.
function L.lessonForCause(cause)
    cause = tostring(cause or "unknown")
    local exact = L.CAUSE_LESSONS[cause]
    if exact then return exact end
    if string.sub(cause, 1, 9) == "killed by" then
        return "trust-carefully"
    end
    return L.CAUSE_LESSONS.unknown
end

local function recompute(rec)
    local echoes = {}
    for key, weight in pairs(rec.lessonsKnown or {}) do
        local entry = L.REGISTRY[key]
        if entry then
            for trait, delta in pairs(entry.echoes) do
                echoes[trait] = (echoes[trait] or 0) + delta * weight
            end
        end
    end
    rec.lessonEchoes = echoes
end

local function migrate(rec)
    if rec.lessonsKnown == nil then
        rec.lessonsKnown = {}
        for _, key in ipairs(rec.lessons or {}) do
            rec.lessonsKnown[key] = 1.0
        end
        recompute(rec)
    end
    return rec.lessonsKnown
end

-- Learn a lesson at a provenance weight; max-merge (living it later
-- deepens what hearing it began). src is "lived"|"witnessed"|"told";
-- of optionally names who the lesson cost (rare, lived claims only).
-- Returns true when anything changed.
function L.learn(id, key, weight, src, of)
    local rec = SAO.Identity.get(id)
    if not rec or not L.REGISTRY[key] then return false end
    local known = migrate(rec)
    local current = known[key] or 0
    if weight <= current then return false end
    known[key] = weight
    rec.lessonMeta = rec.lessonMeta or {}
    local okLH, lh = pcall(function()
        return GameTime.getInstance():getWorldAgeHours()
    end)
    rec.lessonMeta[key] = {
        src = tostring(src or (weight >= 1.0 and "lived"
            or weight >= 0.6 and "witnessed" or "told")),
        of = of,
        atHours = okLH and lh or nil,
    }
    recompute(rec)
    -- [B38] The event this instrument exists for. Guarded because
    -- Lessons is shared/ and Telemetry is client/, so it may not be
    -- loaded yet - and because measuring must never be able to break
    -- the thing measured.
    if SAO.Telemetry and SAO.Telemetry.learned then
        pcall(SAO.Telemetry.learned, id, key, weight,
            rec.lessonMeta[key].src, of)
    end
    log(id .. " learned '" .. key .. "' at weight " .. weight)
    return true
end

-- Terse claim rendering: provenance-first, one line, never a chapter.
function L.renderClaims(id)
    local rec = SAO.Identity.get(id)
    if not rec then return "" end
    local parts = {}
    for key in pairs(migrate(rec)) do
        local meta = rec.lessonMeta and rec.lessonMeta[key] or nil
        local src = meta and meta.src or "told"
        local phrase
        if src == "lived" then phrase = "Paid for '" .. key .. "'"
        elseif src == "witnessed" then phrase = "Saw '" .. key .. "'"
        else phrase = "Was told '" .. key .. "'" end
        if meta and meta.of then
            phrase = phrase .. " (" .. tostring(meta.of) .. ")"
        end
        parts[#parts + 1] = phrase
    end
    table.sort(parts)
    return table.concat(parts, ". ") .. (#parts > 0 and "." or "")
end

-- The weight at which this survivor knows a lesson (0 = not at all).
function L.weight(id, key)
    local rec = SAO.Identity.get(id)
    if not rec then return 0 end
    return migrate(rec)[key] or 0
end

-- The day the world changed for THEM ([B1]): the hour of their
-- earliest dated lesson, or nil for the innocent and for lives whose
-- lessons predate the dating (honest degradation - old saves and
-- genesis-seeded pasts carry no date, and no claim is invented).
function L.firstLessonHours(id)
    local rec = SAO.Identity.get(id)
    if not rec or not rec.lessonMeta then return nil end
    local earliest = nil
    for _, meta in pairs(rec.lessonMeta) do
        if meta.atHours and (not earliest or meta.atHours < earliest) then
            earliest = meta.atHours
        end
    end
    return earliest
end

-- Innocence is having learned nothing yet ([B1]/T-002).
function L.hasAny(id)
    local rec = SAO.Identity.get(id)
    if not rec then return false end
    for _ in pairs(rec.lessonsKnown or {}) do return true end
    for _ in pairs(rec.lessons or {}) do return true end
    return false
end

function L.has(id, key)
    return L.weight(id, key) > 0
end

-- Decision touches (the sharpest lessons bite beyond trait echoes):
-- how much higher this survivor's desperation bar sits before they take
-- from claimed places (they KNOW what it costs).
function L.desperationBump(id)
    return 0.12 * L.weight(id, "claimed-places-bite")
end

-- The extra nerve required before opening fire when overwhelmed.
function L.shootBarBump(id)
    return 0.10 * L.weight(id, "noise-is-a-debt")
end

-- Charity comes easier to those who learned people are worth it.
function L.charityEase(id)
    return 0.08 * L.weight(id, "people-are-worth-it")
end

-- The objection's edge: those who learned doors decide lives object harder.
function L.objectionEdge(id)
    return 1.0 + L.weight(id, "doors-decide-lives")
end

-- One lesson told per conversation: the teller's best lesson the receiver
-- lacks (or holds weaker than told-weight would give). Returns the key or
-- nil. Gating mirrors Perception.tell: membership or teller-side trust.
function L.tellOne(fromId, toId)
    if SAO.Standing
        and not SAO.Standing.sameGroup(fromId, toId)
        and SAO.Standing.trust(fromId, toId) < 0.3 then
        return nil
    end
    local from = SAO.Identity.get(fromId)
    if not from then return nil end
    local bestKey, bestWeight
    for key, weight in pairs(migrate(from)) do
        local offered = weight * 0.4
        if offered > L.weight(toId, key)
            and (not bestWeight or weight > bestWeight) then
            bestKey, bestWeight = key, weight
        end
    end
    if bestKey and L.learn(toId, bestKey, bestWeight * 0.4, "told") then
        return bestKey
    end
    return nil
end

function L.describe(id)
    local rec = SAO.Identity.get(id)
    if not rec then return "no record" end
    local parts = {}
    for key, weight in pairs(migrate(rec)) do
        parts[#parts + 1] = key .. string.format(" (%.1f)", weight)
    end
    if #parts == 0 then return "knows nothing the hard way yet" end
    return table.concat(parts, ", ")
end

log("lessons module loaded (" .. tostring((function()
    local n = 0
    for _ in pairs(L.REGISTRY) do n = n + 1 end
    return n
end)()) .. " in the registry)")

return L
