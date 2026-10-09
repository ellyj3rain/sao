-- SAO_Perception â€” the Perception pillar (ARCHITECTURE Â§Perception).
-- ---------------------------------------------------------------------------
-- A survivor decides on a private belief set, never on map truth. This module
-- owns that belief set: acquisition (via the bridge scanner â€” one compact
-- string, no engine objects), provenance, memory decay, and the query API the
-- controller consumes. Nothing outside this file may hand the controller a
-- world fact.
--
-- Belief sets per survivor:
--   sounds[key]   { x, y, dist, at, source="heard", kind="unknown" }
--                 an audible origin without an identified cause; never a
--                 zombie or a shooter merely because a sound was heard
--   zombies[key]  { x, y, z?, dist, at, source, teller?, track? } - source is
--                 "observed" | "heard" (explicit phantom belief) |
--                 "told" (teller named; observed > heard > told, and told
--                 beliefs are never retold - no chains of whispers);
--                 a ZAO body may also carry form, performance, and
--                 attribute mutations. New direct sightings have a floor and
--                 observer-local continuous track. Reports carry locations and
--                 ordinals only; saved tracks never retain identity authority.
--   people[name]  { x, y, dist, at, source, condition ("ok|hurt|bad"
--                 with "+u" when visibly unkempt), seenInFaction? -
--                 durable across re-scans: a fresh look updates position,
--                 it does not cause amnesia; a living body changed by
--                 ZAO may also carry form, performance, and attributes }
--   factions[g]   { baseX/Y, bounds, at, source, name?, stance } - where
--                 a held place is (observed near it, or told); its NAME
--                 travels only by a member's introduction; no decay
--                 (places do not move; dissolved factions ghost in old
--                 heads deliberately)
--
-- Distance is PERSONAL (F-014): queries recompute from the asker's
-- position. Decay: a belief past its horizon is not acted on; past twice
-- the horizon it is forgotten. "Believes clear" and "has not looked" stay
-- distinguishable via lastScanAt.

SAO = SAO or {}
SAO.Perception = SAO.Perception or {}
local P = SAO.Perception
local awarenessReceiver=nil
function P.bindAwarenessReceiver(owner, receiver)
    if awarenessReceiver or not owner or owner~=SAO.PersonalAwareness or type(receiver)~="function" then return false end
    awarenessReceiver=receiver;return true
end
local function contactRecognition(id)
    local owner=SAO.Knowledge
    if owner and owner.contactRecognition then return owner.contactRecognition(id) end
end

-- id -> { zombies = { [key]=belief }, people = { [name]=belief },
--         lastScanAt, scanCount }
--
-- [C15] Whole minds survive the reload (DR-020): this table is bound
-- to a ModData store at game start, so the engine saves and loads it
-- with the world. Before the bind (module load runs earlier than
-- ModData), writes land in this plain table and are carried into the
-- store when it opens. Growth is bounded by the decay pass and the
-- death funnel (P.forget), as before.
P.beliefs = P.beliefs or {}
-- Native body references are session authority and never enter saved beliefs.
local conceptObservers = {}

-- [C108] Counted whenever any belief record is written, dropped, or
-- the whole store is swapped for a save's. Derived group answers
-- (a company's ranked places) recompute against this number, so a
-- derivation is never served after the facts moved under it - the
-- cost law of [C77] without a cache that lies.
P.beliefVersion = P.beliefVersion or 0

-- The bind itself lives at the bottom of this file, past the one
-- logging door it reports through.

-- [B49] measured this as frames and called the oddity by name: "a
-- belief's shelf life following the graphics card." [C112] ends the
-- oddity the whole-mod way - the tick is the county's clock now (a
-- 9000th of a county hour, `SAO.History.ticks`), so these spans keep
-- their numbers and their default-day pace on every machine, and the
-- horizons stay in step with the scan that feeds them because both
-- read the same axis.
local ZOMBIE_HORIZON = 600     -- county ticks a zombie belief stays actionable
local PEOPLE_HORIZON = 1800
local SCAN_INTERVAL  = 20      -- acquisition cadence per survivor, county ticks
local SCANNER_SIGHT_RANGE = 14 -- SAOPerceptionScanner.RANGE, in tiles
-- Audible occurrence authority belongs only to the current native body.
-- This table is never placed in the persistent belief store. A sound memory's
-- refreshed `at` field is not a new occurrence.
local soundPulses = {}
local SOUND_CUE_LIMIT = 64
local weekOneNativeSignals = {}
local WEEK_ONE_NATIVE_SIGNAL_LIMIT = 8
P.SOUND_CUE_FRESH = 120 -- county ticks from the first personal acquisition
P.WEEK_ONE_NATIVE_SIGNAL_FRESH = 120

local function finiteSoundNumber(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function validSoundToken(token)
    if type(token) ~= "string" or #token > 56 then return false end
    local a, c, d, e, f, sequence = string.match(token,
        "^([0-9a-f]+)%-([0-9a-f]+)%-([0-9a-f]+)%-([0-9a-f]+)%-([0-9a-f]+)%-([1-9][0-9]*)$")
    return a ~= nil and #a == 8 and #c == 4 and #d == 4 and #e == 4
        and #f == 12 and #sequence <= 19
end

local function acquireSoundCue(id, body, entry, fields, x, y, distance, tick)
    if not string.match(entry, "^S:[^:|]+:[^:|]+:[^:|]+:cue:[^:|]+$")
        or #fields ~= 6 or fields[5] ~= "cue"
        or not validSoundToken(fields[6]) or not body
        or not finiteSoundNumber(x) or not finiteSoundNumber(y)
        or not finiteSoundNumber(distance) or distance < 0
        or not finiteSoundNumber(tick) then return end
    local row = soundPulses[id]
    if not row or row.body ~= body or tick < row.at then
        row = { body = body, at = tick, cues = {} }
        soundPulses[id] = row
    end
    row.at = tick
    local token, count = fields[6], 0
    local oldestToken, oldest
    for key, cue in pairs(row.cues) do
        if tick - cue.lastHeardAt > P.SOUND_CUE_FRESH then
            row.cues[key] = nil
        else
            count = count + 1
            if not oldest or cue.heardAt < oldest.heardAt
                or cue.heardAt == oldest.heardAt and cue.distance > oldest.distance
                or cue.heardAt == oldest.heardAt and cue.distance == oldest.distance
                    and key < oldestToken then
                oldestToken, oldest = key, cue
            end
        end
    end
    local cue = row.cues[token]
    if cue then
        -- The pulse's original origin and acquisition time stay fixed.
        if cue.x == x and cue.y == y then cue.lastHeardAt = tick end
    else
        -- A full private cache cannot silence a newly heard pulse. Discard
        -- its oldest occurrence; equal-age ties discard the farthest one.
        if count >= SOUND_CUE_LIMIT and oldestToken then
            row.cues[oldestToken] = nil
        end
        row.cues[token] = { cueId = token, x = x, y = y,
            distance = distance, heardAt = tick, lastHeardAt = tick,
            source = "heard" }
    end
end

-- Detached, bounded private cues. Legacy/restored sound beliefs provide no
-- pulse authority. The native actuator independently refuses consumed tokens.
function P.soundCues(id, body, tick)
    local out, row = {}, soundPulses[id]
    if not row or row.body ~= body or not finiteSoundNumber(tick) then return out end
    for _, cue in pairs(row.cues) do
        local age = tick - cue.heardAt
        if age >= 0 and age <= P.SOUND_CUE_FRESH then
            out[#out + 1] = { cueId = cue.cueId, x = cue.x, y = cue.y,
                distance = cue.distance, heardAt = cue.heardAt,
                lastHeardAt = cue.lastHeardAt, source = cue.source }
        end
    end
    -- The appraisal reads a bounded prefix. Give each person the newest,
    -- nearest personally heard occurrence first, independent of Lua's table
    -- iteration order; no cause or source identity is inferred here.
    table.sort(out, function(a, b)
        if a.heardAt ~= b.heardAt then return a.heardAt > b.heardAt end
        if a.distance ~= b.distance then return a.distance < b.distance end
        return a.cueId < b.cueId
    end)
    return out
end

function P.forgetSoundCues(id, body)
    local row = soundPulses[id]
    if row and (body == nil or row.body == body) then soundPulses[id] = nil end
    row = weekOneNativeSignals[id]
    if row and (body == nil or row.body == body) then weekOneNativeSignals[id] = nil end
end

local function nativeSignalCopy(cue)
    return { kind = cue.kind, x = cue.x, y = cue.y, z = cue.z,
        distance = cue.distance, heardAt = cue.heardAt,
        heardAtHours = cue.heardAtHours, source = cue.source }
end

-- The source body's native action and WorldSound are checked by the bridge.
-- A callout's origin is the current native player body; a horn's is the
-- current driven vehicle. This private contact carries no words or speaker
-- recognition. It is runtime-only because a saved cue cannot prove a current
-- native occurrence or retain the old body as hearing authority.
function P.acquireWeekOneNativeSignal(id, body, player, brain, kind)
    if type(id) ~= "string" or type(brain) ~= "table"
        or (kind ~= "callout" and kind ~= "horn")
        or not (SAO.Identity and SAO.Identity.get and SAO.Claims
            and SAO.Claims.heldBy and SAO.WeekOneContinuity
            and SAO.WeekOneContinuity.sourceBodyFor and SAOJavaBridge
            and SAOJavaBridge.weekOneNativeSignalHeard and SAO.History
            and SAO.History.ticks) then return nil end
    local rec = SAO.Identity.get(id)
    local phase = rec and rec.weekOne
    if not phase or rec.dead or phase.source ~= "BanditsWeekOne"
        or phase.status ~= "external" or phase.pending
        or SAO.Claims.heldBy(rec) ~= "BanditsWeekOne" then return nil end
    local okSource, sourceBody, sourceBrain = pcall(
        SAO.WeekOneContinuity.sourceBodyFor, id)
    if not okSource or sourceBody ~= body or type(sourceBrain) ~= "table"
        or sourceBrain.id ~= brain.id or sourceBrain.born ~= brain.born then return nil end
    local okHeard, heard = pcall(function()
        return SAOJavaBridge:weekOneNativeSignalHeard(player, body,
            id, brain.id, brain.born, kind)
    end)
    if not okHeard or heard ~= true then return nil end
    local okClock, tick, hours = pcall(function()
        return SAO.History.ticks(), getGameTime():getWorldAgeHours()
    end)
    if not okClock or not finiteSoundNumber(tick) or tick < 0
        or not finiteSoundNumber(hours) or hours < 0 then return nil end
    local okLocation, x, y, z, distance = pcall(function()
        local nativeSource = kind == "horn" and player:getVehicle() or player
        if not nativeSource then return nil end
        local sx, sy, sz = nativeSource:getX(), nativeSource:getY(), nativeSource:getZ()
        local dx, dy = sx - body:getX(), sy - body:getY()
        return sx, sy, sz, math.sqrt(dx * dx + dy * dy)
    end)
    if not okLocation or not finiteSoundNumber(x) or not finiteSoundNumber(y)
        or not finiteSoundNumber(z) or not finiteSoundNumber(distance)
        or distance < 0 then return nil end
    local row = weekOneNativeSignals[id]
    if not row or row.body ~= body or tick < row.at then
        row = { body = body, at = tick, cues = {} }
        weekOneNativeSignals[id] = row
    end
    row.at = tick
    local cues = row.cues
    for index = #cues, 1, -1 do
        if tick - cues[index].heardAt > P.WEEK_ONE_NATIVE_SIGNAL_FRESH then
            table.remove(cues, index)
        end
    end
    if #cues >= WEEK_ONE_NATIVE_SIGNAL_LIMIT then table.remove(cues, 1) end
    local cue = { kind = kind, x = x, y = y, z = z, distance = distance,
        heardAt = tick, heardAtHours = hours, source = "native-sound" }
    cues[#cues + 1] = cue
    return nativeSignalCopy(cue)
end

-- The body and county tick must still match. Callers receive copies so an
-- appraisal cannot mutate another person's private auditory history.
function P.weekOneNativeSignals(id, body, tick)
    local out, row = {}, weekOneNativeSignals[id]
    if not row or row.body ~= body or not finiteSoundNumber(tick)
        or tick < row.at then return out end
    for _, cue in ipairs(row.cues) do
        local age = tick - cue.heardAt
        if age >= 0 and age <= P.WEEK_ONE_NATIVE_SIGNAL_FRESH then
            out[#out + 1] = nativeSignalCopy(cue)
        end
    end
    return out
end

local function hearingCopy(row)
    local out = {}; for key, value in pairs(row) do
        if type(value) == "string" or type(value) == "number" or type(value) == "boolean" then out[key] = value end
    end
    return out
end

-- This establishes hearing of a personally visible emitter, never assent or pleasure.
function P.acquireInstrumentHearing(id, body, performerId, workId)
    local needs, gesture = SAO.Needs, SAO.Gesture
    local rec = SAO.Identity and SAO.Identity.get(id)
    local performer = SAO.Body and SAO.Body.get(performerId)
    if not rec or id == performerId or not needs or not needs.ownsRecoveryBody
        or not needs.ownsRecoveryBody(id, body) or not needs.ownsRecoveryBody(performerId, performer)
        or not gesture or not gesture.instrumentOccurrence then return nil end
    local occurrence = gesture.instrumentOccurrence(performerId, workId)
    if type(occurrence) ~= "table" or occurrence.actorId ~= performerId or occurrence.workId ~= workId
        or type(occurrence.pulseId) ~= "string" then return nil end
    local now = SAO.History and SAO.History.countyHours()
    if not finiteSoundNumber(now) or now < 0 then return nil end
    local clockOk, nativeNow = pcall(function() return GameTime.getInstance():getWorldAgeHours() end)
    if not clockOk or not finiteSoundNumber(nativeNow) or nativeNow < 0 then return nil end
    local ok, row = pcall(function()
        return SAOJavaBridge:claimInstrumentHearing(body, performer, workId, occurrence.pulseId)
    end)
    if not ok or type(row) ~= "table" or row.schema ~= "sao.instrument-hearing/1"
        or row.observerId ~= id or row.actorId ~= performerId or row.workId ~= workId
        or row.pulseId ~= occurrence.pulseId or row.epoch ~= occurrence.epoch or row.sequence ~= occurrence.sequence
        or row.emittedAtHours ~= occurrence.emittedAtHours
        or row.clock ~= "native-world-age-hours" or occurrence.clock ~= row.clock
        or not finiteSoundNumber(row.emittedAtHours) or row.emittedAtHours < 0
        or not finiteSoundNumber(row.heardAtHours) or row.heardAtHours < row.emittedAtHours
        or not finiteSoundNumber(row.witnessedAtHours) or row.witnessedAtHours < row.heardAtHours
        or not finiteSoundNumber(row.atHours) or row.atHours < row.witnessedAtHours or row.atHours > nativeNow
        or row.basis ~= "native-scanner-acquired-occurrence"
        or not needs.ownsRecoveryBody(id, body) or not needs.ownsRecoveryBody(performerId, performer) then return nil end
    local rows = type(rec.instrumentHearings) == "table" and rec.instrumentHearings or {}
    for _, old in ipairs(rows) do
        if type(old) == "table" and old.pulseId == row.pulseId then return nil end
    end
    row.acquiredAtCountyHours = now
    rows[#rows + 1] = hearingCopy(row)
    while #rows > 16 do
        table.remove(rows, 1)
        rec.instrumentHearingsOmitted = (tonumber(rec.instrumentHearingsOmitted) or 0) + 1
    end
    rec.instrumentHearings = rows
    return hearingCopy(row)
end

function P.instrumentHearing(id, performerId, workId)
    local rec = SAO.Identity and SAO.Identity.get(id)
    local rows = rec and rec.instrumentHearings
    local now = SAO.History and SAO.History.countyHours()
    local clockOk, nativeNow = pcall(function() return GameTime.getInstance():getWorldAgeHours() end)
    if type(rows) ~= "table" or not finiteSoundNumber(now) or not clockOk or not finiteSoundNumber(nativeNow) then return nil end
    for index = #rows, 1, -1 do
        local row = rows[index]
        if type(row) == "table" and row.schema == "sao.instrument-hearing/1" and row.observerId == id
            and row.actorId == performerId and row.workId == workId
            and row.clock == "native-world-age-hours" and row.basis == "native-scanner-acquired-occurrence"
            and validSoundToken(row.pulseId) and type(row.epoch) == "string"
            and finiteSoundNumber(row.sequence) and row.sequence > 0 and row.sequence == math.floor(row.sequence)
            and row.pulseId == row.epoch .. "-" .. tostring(row.sequence)
            and finiteSoundNumber(row.emittedAtHours) and row.emittedAtHours >= 0
            and finiteSoundNumber(row.heardAtHours) and row.heardAtHours >= row.emittedAtHours
            and finiteSoundNumber(row.witnessedAtHours) and row.witnessedAtHours >= row.heardAtHours
            and finiteSoundNumber(row.atHours) and row.atHours >= row.witnessedAtHours and row.atHours <= nativeNow
            and finiteSoundNumber(row.acquiredAtCountyHours) and row.acquiredAtCountyHours >= 0 and row.acquiredAtCountyHours <= now then
            return hearingCopy(row)
        end
    end
    return nil
end

local function validWeekOnePerformanceHearing(row, observerId, nativeNow, countyNow, observer)
    return type(row) == "table" and row.schema == "sao.weekone-performance-hearing/1"
        and row.observerId == observerId and type(row.actorId) == "string"
        and string.match(row.actorId, "^bwo%-") ~= nil
        and ((row.observerBrainId == nil and row.observerBorn == nil)
            or (finiteSoundNumber(row.observerBrainId)
                and row.observerBrainId == math.floor(row.observerBrainId)
                and finiteSoundNumber(row.observerBorn)
                and type(observer) == "table"
                and type(observer.weekOne) == "table"
                and observer.weekOne.source == "BanditsWeekOne"
                and row.observerBrainId == observer.weekOne.brainId
                and row.observerBorn == observer.weekOne.born))
        and row.clock == "native-world-age-hours"
        and row.basis == "native-scanner-acquired-occurrence"
        and validSoundToken(row.pulseId) and type(row.epoch) == "string"
        and finiteSoundNumber(row.sequence) and row.sequence > 0
        and row.sequence == math.floor(row.sequence)
        and row.pulseId == row.epoch .. "-" .. tostring(row.sequence)
        and finiteSoundNumber(row.brainId) and row.brainId == math.floor(row.brainId)
        and finiteSoundNumber(row.born) and type(row.soundId) == "string"
        and #row.soundId > 0 and #row.soundId <= 96
        and finiteSoundNumber(row.soundHandle) and row.soundHandle > 0
        and row.soundHandle == math.floor(row.soundHandle)
        and finiteSoundNumber(row.emittedAtHours) and row.emittedAtHours >= 0
        and finiteSoundNumber(row.heardAtHours)
        and row.heardAtHours >= row.emittedAtHours
        and finiteSoundNumber(row.witnessedAtHours)
        and row.witnessedAtHours >= row.heardAtHours
        and finiteSoundNumber(row.atHours)
        and row.atHours >= row.witnessedAtHours and row.atHours <= nativeNow
        and finiteSoundNumber(row.acquiredAtCountyHours)
        and row.acquiredAtCountyHours >= 0
        and row.acquiredAtCountyHours <= countyNow
end

-- A Week One source proxy can hear while its exact generation remains loaded.
-- This resolves an existing source-owned body; it does not transfer body control.
local function weekOneHearingObserver(id, body, rec, needs, source)
    if needs and needs.ownsRecoveryBody
        and needs.ownsRecoveryBody(id, body) then return "recovery" end
    local phase = rec and rec.weekOne
    if not phase or phase.source ~= "BanditsWeekOne"
        or phase.status ~= "external" or phase.pending
        or not (SAO.Claims and SAO.Claims.heldBy)
        or SAO.Claims.heldBy(rec) ~= "BanditsWeekOne"
        or not source or type(source.sourceBodyFor) ~= "function" then return nil end
    local ok, exactBody, brain = pcall(source.sourceBodyFor, id)
    if not ok or exactBody ~= body or type(brain) ~= "table"
        or brain.id ~= phase.brainId or brain.born ~= phase.born then return nil end
    return "weekone", brain.id, brain.born
end

-- A current native scanner acquisition is a private heard performance, not
-- an invitation, accepted collaboration, pleasure or instrumental skill.
function P.acquireWeekOnePerformanceHearing(id, body, performerId)
    local needs, source = SAO.Needs, SAO.WeekOneContinuity
    local rec = SAO.Identity and SAO.Identity.get(id)
    local performer = SAO.Identity and SAO.Identity.get(performerId)
    if not rec or rec.dead or not performer or performer.dead or id == performerId
        or not source or not source.livePerformance or not SAOJavaBridge
        or not SAOJavaBridge.claimWeekOnePerformanceHearing then return nil end
    local observerKind, observerBrainId, observerBorn =
        weekOneHearingObserver(id, body, rec, needs, source)
    if not observerKind then return nil end
    local phase = performer.weekOne
    if not phase or phase.source ~= "BanditsWeekOne" or phase.status ~= "external"
        or phase.pending or not (SAO.Claims and SAO.Claims.heldBy)
        or SAO.Claims.heldBy(performer) ~= "BanditsWeekOne" then return nil end
    local okSource, sourceBody, occurrence = pcall(source.livePerformance, performerId)
    if not okSource or not sourceBody or type(occurrence) ~= "table"
        or occurrence.schema ~= "sao.weekone-performance-occurrence/1"
        or occurrence.actorId ~= performerId or occurrence.brainId ~= phase.brainId
        or occurrence.born ~= phase.born or occurrence.clock ~= "native-world-age-hours"
        or not validSoundToken(occurrence.pulseId)
        or not finiteSoundNumber(occurrence.emittedAtHours) then return nil end
    -- A heard occurrence is private and exact-once. Once retained, another
    -- frame needs no native claim for the same currently playing pulse.
    local prior = rec.weekOnePerformanceHearings
    if type(prior) == "table" then
        for _, old in ipairs(prior) do
            if type(old) == "table" and old.pulseId == occurrence.pulseId then
                return nil
            end
        end
    end
    local good, row = pcall(function()
        return SAOJavaBridge:claimWeekOnePerformanceHearing(body, sourceBody,
            performerId, phase.brainId, phase.born, occurrence.pulseId)
    end)
    local countyNow = SAO.History and SAO.History.countyHours()
    local clockOk, nativeNow = pcall(function()
        return GameTime.getInstance():getWorldAgeHours()
    end)
    if type(row) == "table" and row.acquiredAtCountyHours == nil then
        row.acquiredAtCountyHours = countyNow
    end
    local stillLive, currentBody, currentOccurrence = pcall(
        source.livePerformance, performerId)
    local currentObserverKind, currentObserverBrainId, currentObserverBorn =
        weekOneHearingObserver(id, body, rec, needs, source)
    if not good or not clockOk or not finiteSoundNumber(countyNow)
        or not finiteSoundNumber(nativeNow)
        or not validWeekOnePerformanceHearing(row, id, nativeNow, countyNow, rec)
        or row.actorId ~= performerId or row.brainId ~= phase.brainId
        or row.born ~= phase.born or row.soundId ~= occurrence.soundId
        or row.soundHandle ~= occurrence.soundHandle
        or row.pulseId ~= occurrence.pulseId or row.epoch ~= occurrence.epoch
        or row.sequence ~= occurrence.sequence
        or row.emittedAtHours ~= occurrence.emittedAtHours
        or (observerKind == "weekone" and (row.observerBrainId ~= observerBrainId
            or row.observerBorn ~= observerBorn))
        or (observerKind == "recovery" and
            (row.observerBrainId ~= nil or row.observerBorn ~= nil))
        or currentObserverKind ~= observerKind
        or currentObserverBrainId ~= observerBrainId
        or currentObserverBorn ~= observerBorn
        or not stillLive or currentBody ~= sourceBody
        or type(currentOccurrence) ~= "table"
        or currentOccurrence.pulseId ~= occurrence.pulseId then return nil end
    local rows = type(rec.weekOnePerformanceHearings) == "table"
        and rec.weekOnePerformanceHearings or {}
    for _, old in ipairs(rows) do
        if type(old) == "table" and old.pulseId == row.pulseId then return nil end
    end
    rows[#rows + 1] = hearingCopy(row)
    while #rows > 16 do
        table.remove(rows, 1)
        rec.weekOnePerformanceHearingsOmitted =
            (tonumber(rec.weekOnePerformanceHearingsOmitted) or 0) + 1
    end
    rec.weekOnePerformanceHearings = rows
    return hearingCopy(row)
end

function P.weekOnePerformanceHearings(id)
    local rec = SAO.Identity and SAO.Identity.get(id)
    local rows = rec and rec.weekOnePerformanceHearings
    local countyNow = SAO.History and SAO.History.countyHours()
    local clockOk, nativeNow = pcall(function()
        return GameTime.getInstance():getWorldAgeHours()
    end)
    local out = {}
    if type(rows) ~= "table" or not finiteSoundNumber(countyNow)
        or not clockOk or not finiteSoundNumber(nativeNow) then return out end
    for _, row in ipairs(rows) do
        if validWeekOnePerformanceHearing(row, id, nativeNow, countyNow, rec) then
            out[#out + 1] = hearingCopy(row)
        end
    end
    return out
end
-- [B20] How long a recognised cry keeps its tile from being read
-- as a threat. ONE definition: the guard in the S-row path and
-- the prune in the decay pass both read this, or they drift and
-- the table leaks.
local CRY_RECOGNITION = 600

-- [C32] How long THIS person keeps a recent belief: the horizon above
-- times a factor that is a fact about them (SAO_Conditions.memoryFactor
-- - the demented keep the recent half as long, the old past
-- seventy-five a fifth less, the haunted keep a threat half again as
-- long). Knowledge decays per person, not at one rate (DR-032). One
-- for everyone else, so nothing below moves for them. Read once per
-- pass, not per belief.
local function horizonFor(id, kind)
    local base = (kind == "zombies") and ZOMBIE_HORIZON or PEOPLE_HORIZON
    local factor = 1.0
    pcall(function() factor = SAO.Conditions.memoryFactor(id, kind) end)
    if type(factor) ~= "number" or factor <= 0 then factor = 1.0 end
    return base * factor
end
P.horizonFor = horizonFor

local function parseAttributes(text)
    local attributes = {}
    for name, value in string.gmatch(
            tostring(text or ""), "([^=;]+)=([^;]+)") do
        attributes[name] = tonumber(value) or 0.0
    end
    return attributes
end
-- [C5] A person talking does not say coordinates. These bands turn a
-- believed position into the words somebody standing HERE would use
-- for it; the figures are judgments about speech, not reaches, and
-- nothing gates on them.
local WORD_CLOSE = 20          -- tiles: "just <dir> of here"
local WORD_WALK  = 75          -- tiles: "a short walk <dir>"
local WORD_FAR   = 300         -- tiles: "a good walk <dir>"

-- [C5] Where a thing is, said the way a person says it, from where
-- the speaker stands. World text is a person talking (SPEECH.md):
-- every renderer that used to print "at 10842,9195" reads this now.
function P.whereWord(x, y, fromX, fromY)
    if not (x and y and fromX and fromY) then return "somewhere about" end
    local dx, dy = x - fromX, y - fromY
    local d = math.sqrt(dx * dx + dy * dy)
    local dir
    if math.abs(dx) > 2 * math.abs(dy) then
        dir = dx > 0 and "east" or "west"
    elseif math.abs(dy) > 2 * math.abs(dx) then
        dir = dy > 0 and "south" or "north"
    else
        dir = (dy > 0 and "south" or "north")
            .. (dx > 0 and "east" or "west")
    end
    if d <= WORD_CLOSE then return "just " .. dir .. " of here" end
    if d <= WORD_WALK then return "a short walk " .. dir end
    if d <= WORD_FAR then return "a good walk " .. dir end
    return "a long way " .. dir
end
-- [B35] How close a survivor must be to notice a place is nobody's
-- now. The same eight tiles the dormant drift uses to LEARN a place
-- ([A15]), because learning and forgetting should not have different
-- reaches.
-- [B40] EXPORTED, because the comment above was a claim nobody
-- enforced. This was a file-level local read four times here, for
-- FORGETTING, while SAO_Population hardcoded the number eight times
-- for LEARNING - so "learning and forgetting should not have
-- different reaches" was true only by coincidence. Move this and the
-- two halves diverge silently: a survivor could learn a place at
-- eight tiles they can only forget at ten.
P.PLACE_SIGHT = 8

-- [B40] And how near to learn where a COMPANY's ground is. Wider
-- than a personal place because a faction's base is a bigger and more
-- visible thing - a camp is seen from further off than a house. Was
-- spelled bare four lines below; named here so the two sight reaches
-- sit together and their difference is a stated choice.
P.FACTION_SIGHT = 12

-- [B43] How wide a NAMED GROUND is, for the purpose of talking about
-- it. Not a sight reach at all - the two above are about learning a
-- place by being near it, and this is about which of your beliefs
-- COUNT as being about somewhere when you brief a goer or hear their
-- report.
--
-- [B19] built the report as "the briefing's own idiom, reversed and
-- bounded identically", and then bounded both with a bare `1600` -
-- forty tiles squared - written six times across `announceDeparture`
-- and `reportReturn`. Identical by intent and by coincidence at once:
-- nothing tied the two ends together, so the sentence saying they
-- match was true only for as long as nobody edited one of them.
--
-- Squared where it is used, the way [B41] made `MEET_RANGE` agree
-- with its own docstring by construction.
P.GROUND_REACH = 40

-- [B43] How far an ordinary spoken word carries. Two sites asked it
-- and both typed it bare: `announceDeparture` deciding who is close
-- enough to HEAR somebody say they are leaving, and the controller
-- deciding who is close enough to be TOLD something. That is one rule -
-- people within earshot - spelled in two files.
--
-- It sits four lines from GROUND_REACH deliberately, because the two
-- live in the SAME FUNCTION and are not the same thing: forty tiles is
-- what the announcement is ABOUT, ten is who can hear it. Different
-- numbers, one function, two rules - which is the trap of [B40] run
-- backwards, and the reason each is named for what it governs rather
-- than for how far it reaches.
--
-- A CRY is louder and is not this: `cryForHelp` carries 20 tiles scaled
-- by the weather's own masking, because screaming is not speaking.
P.EARSHOT = 10

-- [B47] One door out: everything this module says goes
-- through the shared logger.
local function log(msg) SAO.Log.line("PERCEPT", msg) end

-- Older acquisition put every world sound into the enemy bucket. Preserve
-- those audible observations as unknown sounds, while retaining explicitly
-- authored hallucinations and observed/reported threat evidence. Old told
-- records lack their original sensory kind and cannot be reconstructed here.
local function soundEvidence(b)
    b.sounds = b.sounds or {}
    if b.soundEvidenceVersion == 1 then return end
    for key, belief in pairs(b.zombies or {}) do
        if belief.source == "heard" and belief.phantom ~= true then
            local existing = b.sounds[key]
            if not existing or (existing.at or 0) < (belief.at or 0) then
                b.sounds[key] = { x = belief.x, y = belief.y, dist = belief.dist,
                    at = belief.at, source = "heard", kind = "unknown" }
            end
            b.zombies[key] = nil
        end
    end
    b.soundEvidenceVersion = 1
    P.beliefVersion = P.beliefVersion + 1
end

local function store(id)
    P.beliefs[id] = P.beliefs[id] or { zombies = {}, people = {},
        factions = {}, places = {}, lastScanAt = 0, scanCount = 0 }
    P.beliefs[id].factions = P.beliefs[id].factions or {}
    P.beliefs[id].places = P.beliefs[id].places or {}
    soundEvidence(P.beliefs[id])
    return P.beliefs[id]
end

-- Completed transfers are dated episodes, separate from short-lived position
-- sightings and current source contents. The initial recall span follows the
-- existing fourteen-day relation window; personal memory conditions scale it.
local TRANSFER_LIMIT = 64
local TRANSFER_HOURS = 14 * 24

local function transferNumber(value)
    return type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
end

local function transferNow(given)
    if given ~= nil then
        return transferNumber(given) and given >= 0 and given or nil
    end
    local ok, at = pcall(function() return SAO.History.countyHours() end)
    return ok and transferNumber(at) and at >= 0 and at or nil
end

local function appraisalCopy(fact, now)
    local appraisal = fact.appraisal
    if type(appraisal) ~= "table" or not transferNumber(appraisal.reciprocity)
        or appraisal.reciprocity < -1 or appraisal.reciprocity > 1 then return nil end
    if fact.source == "observed" and transferNumber(appraisal.pressure)
        and appraisal.pressure >= 0 and appraisal.pressure <= 1 then
        return { pressure = appraisal.pressure,
            reciprocity = appraisal.reciprocity }
    end
    if fact.source ~= "told" or appraisal.basis ~= "testimony-household-request"
        or not transferNumber(appraisal.appraisedAt)
        or appraisal.appraisedAt < fact.acquiredAt
        or (now ~= nil and appraisal.appraisedAt > now)
        or not transferNumber(appraisal.evidenceWeight)
        or appraisal.evidenceWeight < 0 or appraisal.evidenceWeight > 0.4
        or not transferNumber(appraisal.relationshipTrust)
        or appraisal.relationshipTrust < -1 or appraisal.relationshipTrust > 1
        or not transferNumber(appraisal.tellerTrust)
        or appraisal.tellerTrust < -1 or appraisal.tellerTrust > 1
        or not transferNumber(appraisal.compassion)
        or appraisal.compassion < 0.15 or appraisal.compassion > 0.85
        or type(appraisal.requestGroupId) ~= "string"
        or appraisal.requestGroupId == ""
        or appraisal.requestCategory ~= "food"
        or not transferNumber(appraisal.requestedAt)
        or not transferNumber(appraisal.requestAcquiredAt)
        or appraisal.requestedAt > fact.eventAt
        or appraisal.requestedAt > appraisal.requestAcquiredAt
        or appraisal.requestAcquiredAt > appraisal.appraisedAt
        or (appraisal.requestSource ~= "requested"
            and appraisal.requestSource ~= "told")
        or (appraisal.requestSource == "told"
            and (type(appraisal.requestTeller) ~= "string"
                or appraisal.requestTeller == ""))
        or (appraisal.requestSource == "requested"
            and appraisal.requestTeller ~= nil)
        or type(appraisal.requestOriginId) ~= "string"
        or appraisal.requestOriginId == ""
        or not transferNumber(appraisal.requestOriginAcquiredAt)
        or appraisal.requestOriginAcquiredAt < appraisal.requestedAt
        or appraisal.requestOriginAcquiredAt > appraisal.requestAcquiredAt
        or (appraisal.claimKind ~= "faction" and appraisal.claimKind ~= "place")
        or (appraisal.claimSource ~= "observed"
            and appraisal.claimSource ~= "heard"
            and appraisal.claimSource ~= "told")
        or (appraisal.claimSource == "told"
            and (type(appraisal.claimTeller) ~= "string"
                or appraisal.claimTeller == ""))
        or (appraisal.claimSource ~= "told"
            and appraisal.claimTeller ~= nil)
        or not transferNumber(appraisal.claimMinX)
        or not transferNumber(appraisal.claimMinY)
        or not transferNumber(appraisal.claimMaxX)
        or not transferNumber(appraisal.claimMaxY)
        or appraisal.claimMinX > appraisal.claimMaxX
        or appraisal.claimMinY > appraisal.claimMaxY
        or not transferNumber(fact.x) or not transferNumber(fact.y)
        or fact.x < appraisal.claimMinX or fact.x > appraisal.claimMaxX
        or fact.y < appraisal.claimMinY or fact.y > appraisal.claimMaxY then
        return nil
    end
    return {
        basis = appraisal.basis, appraisedAt = appraisal.appraisedAt,
        reciprocity = appraisal.reciprocity,
        evidenceWeight = appraisal.evidenceWeight,
        relationshipTrust = appraisal.relationshipTrust,
        tellerTrust = appraisal.tellerTrust,
        compassion = appraisal.compassion,
        requestGroupId = appraisal.requestGroupId,
        requestCategory = appraisal.requestCategory,
        requestedAt = appraisal.requestedAt,
        requestAcquiredAt = appraisal.requestAcquiredAt,
        requestSource = appraisal.requestSource,
        requestTeller = appraisal.requestTeller,
        requestOriginId = appraisal.requestOriginId,
        requestOriginAcquiredAt = appraisal.requestOriginAcquiredAt,
        claimKind = appraisal.claimKind,
        claimSource = appraisal.claimSource,
        claimTeller = appraisal.claimTeller,
        claimMinX = appraisal.claimMinX, claimMinY = appraisal.claimMinY,
        claimMaxX = appraisal.claimMaxX, claimMaxY = appraisal.claimMaxY,
    }
end

local function transferCopy(fact, includeAppraisal, now)
    local out = {}
    for _, key in ipairs({ "eventId", "actorId", "operation", "itemType",
        "category", "sourceId", "placeId", "x", "y", "z", "eventAt",
        "acquiredAt", "source", "teller", "originId", "originSource",
        "originAcquiredAt" }) do
        out[key] = fact[key]
    end
    if includeAppraisal then out.appraisal = appraisalCopy(fact, now) end
    return out
end

local function transferHorizon(id)
    local ok, factor = pcall(function()
        return SAO.Conditions.memoryFactor(id, "transfers")
    end)
    if not ok or not transferNumber(factor) or factor <= 0 then factor = 1 end
    return TRANSFER_HOURS * factor
end

local function transferState(fact, now, horizon)
    if type(fact) ~= "table" or not transferNumber(fact.eventAt)
        or not transferNumber(fact.acquiredAt)
        or fact.eventAt < 0 or fact.eventAt > fact.acquiredAt
        or fact.acquiredAt > now
        or type(fact.eventId) ~= "string" or fact.eventId == ""
        or type(fact.actorId) ~= "string" or fact.actorId == ""
        or type(fact.itemType) ~= "string" or fact.itemType == ""
        or type(fact.sourceId) ~= "string" or fact.sourceId == ""
        or (fact.operation ~= "store" and fact.operation ~= "acquire")
        or (fact.category ~= "food" and fact.category ~= "water")
        or not transferNumber(fact.x) or not transferNumber(fact.y)
        or not transferNumber(fact.z)
        or (fact.source ~= "performed" and fact.source ~= "observed"
            and fact.source ~= "told")
        or type(fact.originId) ~= "string" or fact.originId == ""
        or (fact.originSource ~= "performed" and fact.originSource ~= "observed")
        or not transferNumber(fact.originAcquiredAt)
        or fact.originAcquiredAt < fact.eventAt
        or fact.originAcquiredAt > fact.acquiredAt
        or (fact.source == "told" and (type(fact.teller) ~= "string"
            or fact.teller == "")) then return "unavailable" end
    return now - fact.eventAt <= horizon and "remembered" or "forgotten"
end

local function transferOrder(a, b)
    local atA, atB = tonumber(a.eventAt) or -math.huge,
        tonumber(b.eventAt) or -math.huge
    if atA ~= atB then return atA < atB end
    return tostring(a.eventId) < tostring(b.eventId)
end

-- A detached reader: questions neither create a mind nor refresh its memory.
-- Forgotten entries reveal no former actor, item or location to a consumer.
function P.transferFacts(id, nowHours)
    local now = transferNow(nowHours)
    local b = P.beliefs[tostring(id or "")]
    if not now or not b or type(b.transfers) ~= "table" then
        return {}, "unavailable"
    end
    local ordered = {}
    for eventId, fact in pairs(b.transfers) do
        ordered[#ordered + 1] = { eventId = tostring(eventId),
            eventAt = type(fact) == "table" and fact.eventAt or nil,
            fact = fact }
    end
    table.sort(ordered, transferOrder)
    local out, horizon = {}, transferHorizon(id)
    for _, entry in ipairs(ordered) do
        local state = transferState(entry.fact, now, horizon)
        local fact = state == "remembered" and transferCopy(entry.fact, true, now)
            or { eventId = entry.eventId }
        fact.state = state
        out[#out + 1] = fact
    end
    return out, "available"
end

function P.transferFact(id, eventId, nowHours)
    local facts, availability = P.transferFacts(id, nowHours)
    for _, fact in ipairs(facts) do
        if fact.eventId == tostring(eventId or "") then
            return fact, fact.state
        end
    end
    return nil, availability == "available" and "not-known" or "unavailable"
end

function P.reciprocityToward(id, actorId, nowHours)
    local strongest, eventId = 0, nil
    for _, fact in ipairs(P.transferFacts(id, nowHours)) do
        local value = fact.appraisal and fact.appraisal.reciprocity
        if fact.state == "remembered"
            and (fact.source == "observed" or fact.source == "told")
            and fact.actorId == tostring(actorId or "") and transferNumber(value)
            and math.abs(value) >= math.abs(strongest) then
            strongest, eventId = value, fact.eventId
        end
    end
    return strongest, eventId
end

local function sameTransfer(a, b)
    for _, key in ipairs({ "eventId", "actorId", "operation", "itemType",
        "category", "sourceId", "placeId", "x", "y", "z", "eventAt" }) do
        if a[key] ~= b[key] then return false end
    end
    return true
end

local function rememberTransfer(id, fact)
    local b = store(tostring(id))
    b.transfers = b.transfers or {}
    if type(b.transferFloor) == "table" and not transferOrder(b.transferFloor, fact) then
        return false
    end
    local existing = b.transfers[fact.eventId]
    -- The first telling stays dated; another telling cannot refresh it or
    -- replace a firsthand episode. A captured firsthand result may replace
    -- testimony about that exact same event.
    if existing and (existing.source ~= "told" or fact.source == "told") then
        return false
    end
    b.transfers[fact.eventId] = transferCopy(fact, true, transferNow())
    local ordered = {}
    for eventId, entry in pairs(b.transfers) do
        ordered[#ordered + 1] = { eventId = eventId, eventAt = entry.eventAt }
    end
    table.sort(ordered, transferOrder)
    for i = 1, #ordered - TRANSFER_LIMIT do
        b.transfers[ordered[i].eventId] = nil
        b.transferFloor = { eventAt = ordered[i].eventAt, eventId = ordered[i].eventId }
    end
    P.beliefVersion = P.beliefVersion + 1
    return b.transfers[fact.eventId] ~= nil
end

-- The action owner supplies witnesses captured at the native transfer. Later
-- membership, proximity and receipt reconciliation never add witnesses.
function P.receiveTransferResult(receipt)
    if type(receipt) ~= "table" then return false, "invalid-result" end
    local observation = receipt.transferObservation
    if receipt.status ~= "completed" and receipt.status ~= "conflict"
        and receipt.status ~= "released" and receipt.status ~= "interrupted" then
        return false, "unperformed-transfer"
    end
    if observation == nil then
        if receipt.status == "completed" then return true, "observation-unavailable" end
        return false, "unproved-transfer"
    end
    if type(observation) ~= "table" or observation.nativeTransferProven ~= true
        or (receipt.operation ~= "store" and receipt.operation ~= "acquire") then
        return false, "unproved-transfer"
    end
    local now = transferNow()
    if not now then return false, "clock-unavailable" end
    if type(observation) ~= "table"
        or type(observation.witnesses) ~= "table"
        or type(receipt.reservationId) ~= "string" or receipt.reservationId == ""
        or type(receipt.actorId) ~= "string" or receipt.actorId == ""
        or observation.actorId ~= receipt.actorId
        or type(receipt.itemType) ~= "string" or receipt.itemType == ""
        or type(receipt.sourceId) ~= "string" or receipt.sourceId == ""
        or (receipt.category ~= "food" and receipt.category ~= "water")
        or not transferNumber(observation.at) or observation.at < 0
        or not transferNumber(receipt.at) or observation.at > receipt.at
        or receipt.at > now or not transferNumber(observation.x)
        or not transferNumber(observation.y) or not transferNumber(observation.z) then
        return false, "invalid-observation"
    end
    local fact = { eventId = receipt.reservationId, actorId = receipt.actorId,
        operation = receipt.operation, itemType = receipt.itemType,
        category = receipt.category, sourceId = receipt.sourceId,
        placeId = receipt.placeId and tostring(receipt.placeId) or nil,
        x = observation.x, y = observation.y, z = observation.z,
        eventAt = observation.at, acquiredAt = observation.at,
        originAcquiredAt = observation.at }
    local recipients = { [receipt.actorId] = "performed" }
    local count = 0
    for key, witness in pairs(observation.witnesses) do
        count = count + 1
        if type(key) ~= "number" or key < 1 or key ~= math.floor(key)
            or type(witness) ~= "string" or witness == "" then
            return false, "invalid-witnesses"
        end
        if witness ~= receipt.actorId then recipients[witness] = "observed" end
    end
    if count ~= #observation.witnesses then return false, "invalid-witnesses" end
    local appraisals = observation.appraisals
    if appraisals ~= nil and type(appraisals) ~= "table" then
        return false, "invalid-appraisal"
    end
    for id, appraisal in pairs(appraisals or {}) do
        if recipients[id] ~= "observed" or receipt.operation ~= "store"
            or type(appraisal) ~= "table" or not transferNumber(appraisal.pressure)
            or appraisal.pressure < 0 or appraisal.pressure > 1
            or not transferNumber(appraisal.reciprocity)
            or appraisal.reciprocity < -1 or appraisal.reciprocity > 1 then
            return false, "invalid-appraisal"
        end
    end
    local cognitionCapabilities = observation.cognitionCapabilities
    if cognitionCapabilities ~= nil and type(cognitionCapabilities) ~= "table" then
        return false, "invalid-cognition-capabilities"
    end
    for id, caps in pairs(cognitionCapabilities or {}) do
        if recipients[id] ~= "observed" or type(caps) ~= "table"
            or type(caps.cook) ~= "boolean" or type(caps.forage) ~= "boolean"
            or type(caps.treat) ~= "boolean" then return false, "invalid-cognition-capabilities" end
    end
    for id in pairs(recipients) do
        local b = P.beliefs[id]
        local existing = b and b.transfers and b.transfers[fact.eventId]
        if existing and (type(existing) ~= "table" or not sameTransfer(existing, fact)) then
            return false, "conflicting-event"
        end
    end
    for id, source in pairs(recipients) do
        fact.source, fact.originSource, fact.originId = source, source, id
        fact.appraisal = source == "observed" and appraisals and appraisals[id] or nil
        rememberTransfer(id, fact)
        if source == "observed" and SAO.Cognition then
            pcall(SAO.Cognition.experience, id, {
                id = "world-transfer/" .. receipt.reservationId,
                actorId = receipt.actorId, observerId = id,
                worldHours = observation.at, kind = receipt.operation,
                category = receipt.category, sourceId = receipt.sourceId,
                itemType = receipt.itemType, perspective = "observed", status = "completed",
                capabilities = cognitionCapabilities and cognitionCapabilities[id],
                detail = "captured-native-transfer-witness" })
        end
    end
    return true, "recorded"
end

local function tellTransfers(fromId, toId, channel, aroundX, aroundY)
    local admitted, canConverse = pcall(function()
        return SAO.Communication.canConverse(fromId, toId, channel)
    end)
    if not admitted or canConverse ~= true then return 0 end
    local now = transferNow()
    if not now then return 0 end
    local facts, moved = P.transferFacts(fromId, now), 0
    for _, fact in ipairs(facts) do
        local inGround = true
        if aroundX and aroundY then
            local dx, dy = (fact.x or math.huge) - aroundX,
                (fact.y or math.huge) - aroundY
            inGround = fact.source ~= "told"
                and dx * dx + dy * dy <= P.GROUND_REACH * P.GROUND_REACH
        end
        if fact.state == "remembered" and inGround
            and now - fact.eventAt <= transferHorizon(toId) then
            local told = transferCopy(fact)
            told.source, told.teller, told.acquiredAt = "told", tostring(fromId), now
            if rememberTransfer(toId, told) then moved = moved + 1 end
        end
    end
    return moved
end

-- A broadcast receipt is transport evidence owned by the listener. It says
-- which physical endpoint received which bounded claims; it does not itself
-- make any claim true. Content-specific consumers run only after this write.
local RADIO_LIMIT = 64
local RADIO_CLAIM_FIELDS = { "kind", "group", "requestedAt", "speakerId",
    "id", "a", "b", "leader", "policy", "form", "x", "y", "z",
    "target", "creed", "left", "name", "processId", "processRevision" }
local RADIO_CLAIM_FIELD_SET = {}
for _, key in ipairs(RADIO_CLAIM_FIELDS) do RADIO_CLAIM_FIELD_SET[key] = true end

local function radioClaimCopy(item)
    if type(item) ~= "table" or type(item.kind) ~= "string"
        or item.kind == "" then return nil end
    local copy = {}
    for key, value in pairs(item) do
        if type(key) ~= "string" or not RADIO_CLAIM_FIELD_SET[key] then
            return nil
        end
        if type(value) ~= "string" and type(value) ~= "number"
            and type(value) ~= "boolean" then return nil end
        if type(value) == "number" and not transferNumber(value) then
            return nil
        end
        copy[key] = value
    end
    return copy
end

local function radioReceiptCopy(receipt)
    if type(receipt) ~= "table" then return nil end
    local out = { broadcastId = receipt.broadcastId,
        sourceId = receipt.sourceId, frequency = receipt.frequency,
        receivedAt = receipt.receivedAt,
        representation = receipt.representation,
        deviceItemId = receipt.deviceItemId,
        deviceType = receipt.deviceType, channel = receipt.channel,
        power = receipt.power, claims = {} }
    for _, item in ipairs(receipt.claims or {}) do
        local claim = radioClaimCopy(item)
        if not claim then return nil end
        out.claims[#out.claims + 1] = claim
    end
    return out
end

local function sameRadioReceipt(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for _, key in ipairs({ "broadcastId", "sourceId", "frequency",
        "receivedAt", "representation", "deviceItemId", "deviceType",
        "channel", "power" }) do
        if a[key] ~= b[key] then return false end
    end
    if #(a.claims or {}) ~= #(b.claims or {}) then return false end
    for i, left in ipairs(a.claims or {}) do
        local right = b.claims[i]
        for _, key in ipairs(RADIO_CLAIM_FIELDS) do
            if left[key] ~= right[key] then return false end
        end
    end
    return true
end

function P.recordRadioReception(id, broadcastId, sourceId, frequency,
        receivedAt, access, items)
    local now = transferNow()
    if not now or type(id) ~= "string" or id == ""
        or type(broadcastId) ~= "string" or broadcastId == ""
        or type(sourceId) ~= "string" or sourceId == ""
        or type(frequency) ~= "number" or frequency ~= math.floor(frequency)
        or frequency <= 0 or frequency > 1000000
        or not transferNumber(receivedAt) or receivedAt < 0 or receivedAt > now
        or type(access) ~= "table"
        or (access.representation ~= "loaded"
            and access.representation ~= "dormant")
        or type(access.deviceItemId) ~= "number"
        or access.deviceItemId ~= math.floor(access.deviceItemId)
        or type(access.deviceType) ~= "string" or access.deviceType == ""
        or access.channel ~= frequency or not transferNumber(access.power)
        or access.power < 0 or access.power > 1.000001
        or type(items) ~= "table" then return false, "invalid-reception" end
    local claims, count = {}, 0
    for key, item in pairs(items) do
        count = count + 1
        if type(key) ~= "number" or key < 1 or key ~= math.floor(key)
            or key > 64 then return false, "invalid-claims" end
        local claim = radioClaimCopy(item)
        if not claim then return false, "invalid-claims" end
        claims[key] = claim
    end
    if count ~= #items then return false, "invalid-claims" end
    local receipt = { broadcastId = broadcastId, sourceId = sourceId,
        frequency = frequency, receivedAt = receivedAt,
        representation = access.representation,
        deviceItemId = access.deviceItemId, deviceType = access.deviceType,
        channel = access.channel, power = access.power, claims = claims }
    local b = store(id)
    b.radioReceptions = b.radioReceptions or {}
    local existing = b.radioReceptions[broadcastId]
    if existing then
        return sameRadioReceipt(existing, receipt),
            sameRadioReceipt(existing, receipt) and radioReceiptCopy(existing)
                or "conflicting-reception"
    end
    local order = { eventAt = receivedAt, eventId = broadcastId }
    if type(b.radioReceptionFloor) == "table"
        and not transferOrder(b.radioReceptionFloor, order) then
        return false, "evicted-reception"
    end
    b.radioReceptions[broadcastId] = receipt
    local ordered = {}
    for eventId, value in pairs(b.radioReceptions) do
        ordered[#ordered + 1] = { eventId = eventId,
            eventAt = value.receivedAt }
    end
    table.sort(ordered, transferOrder)
    for i = 1, #ordered - RADIO_LIMIT do
        b.radioReceptions[ordered[i].eventId] = nil
        b.radioReceptionFloor = { eventAt = ordered[i].eventAt,
            eventId = ordered[i].eventId }
    end
    P.beliefVersion = P.beliefVersion + 1
    return b.radioReceptions[broadcastId] ~= nil,
        radioReceiptCopy(b.radioReceptions[broadcastId])
end

function P.radioReceptions(id, strict)
    local b = P.beliefs[tostring(id or "")]
    if strict and b and b.radioReceptions ~= nil
        and type(b.radioReceptions) ~= "table" then
        return nil, "radio-reception-unreadable"
    end
    if not b or type(b.radioReceptions) ~= "table" then return {} end
    local ordered = {}
    for broadcastId, receipt in pairs(b.radioReceptions) do
        if strict then
            if type(receipt) ~= "table" or type(receipt.claims) ~= "table" then
                return nil, "radio-reception-unreadable"
            end
            local count = 0
            for index in pairs(receipt.claims) do
                count = count + 1
                if type(index) ~= "number" or index < 1 or index ~= math.floor(index)
                    or index > #receipt.claims or count > 64 then
                    return nil, "radio-reception-unreadable"
                end
            end
            if count ~= #receipt.claims then return nil, "radio-reception-unreadable" end
        end
        local copy = radioReceiptCopy(receipt)
        if strict and (not copy or copy.broadcastId ~= broadcastId
            or type(copy.sourceId) ~= "string" or copy.sourceId == ""
            or not transferNumber(copy.receivedAt)) then
            return nil, "radio-reception-unreadable"
        end
        if copy then
            ordered[#ordered + 1] = { eventId = broadcastId,
                eventAt = copy.receivedAt, receipt = copy }
        end
    end
    table.sort(ordered, transferOrder)
    local out = {}
    for _, entry in ipairs(ordered) do out[#out + 1] = entry.receipt end
    return out
end

function P.radioReception(id, broadcastId)
    for _, receipt in ipairs(P.radioReceptions(id)) do
        if receipt.broadcastId == tostring(broadcastId or "") then
            return receipt
        end
    end
    return nil
end

local AID_REQUEST_HOURS = 96

function P.recordAidRequest(id, groupId, requestedAt, source, teller, category,
                            processId, processRevision, channel, evidence)
    local now = transferNow()
    if not now or type(id) ~= "string" or id == ""
        or type(groupId) ~= "string" or groupId == ""
        or not transferNumber(requestedAt) or requestedAt < 0
        or requestedAt > now or now - requestedAt > AID_REQUEST_HOURS
        or (category ~= nil and category ~= "food")
        or (source ~= "requested" and source ~= "told") then return false end
    category = category or "food"
    if processId ~= nil and (type(processId) ~= "string" or processId == ""
        or type(processRevision) ~= "number"
        or processRevision < 1
        or processRevision ~= math.floor(processRevision)) then return false end
    local originId, originAcquiredAt = id, requestedAt
    if source == "told" then
        if type(teller) ~= "string" or teller == "" then return false end
        local from = P.beliefs[teller]
        local original = from and from.aidRequests and from.aidRequests[groupId]
        local originalCategory = type(original) == "table"
            and (original.category or "food") or nil
        if type(original) ~= "table" or original.requestedAt ~= requestedAt
            or originalCategory ~= category
            or original.processId ~= processId
            or original.processRevision ~= processRevision
            or not transferNumber(original.acquiredAt)
            or original.acquiredAt > now then return false end
        originId = original.originId
        originAcquiredAt = original.originAcquiredAt
        if type(originId) ~= "string" or originId == ""
            or not transferNumber(originAcquiredAt)
            or originAcquiredAt < requestedAt
            or originAcquiredAt > now then return false end
    end
    local b = store(id)
    b.aidRequests = b.aidRequests or {}
    local order = { eventAt = requestedAt, eventId = groupId }
    if type(b.aidRequestFloor) == "table" and not transferOrder(b.aidRequestFloor, order) then
        return false
    end
    local existing = b.aidRequests[groupId]
    if type(existing) == "table" then
        if existing.requestedAt > requestedAt then return false end
        if (existing.category or "food") ~= category then return false end
        if existing.requestedAt == requestedAt
            and (existing.source == "requested" or source == "told") then
            return true
        end
    end
    b.aidRequests[groupId] = { groupId = groupId, category = category,
        requestedAt = requestedAt,
        acquiredAt = source == "requested" and requestedAt or now,
        source = source, teller = source == "told" and teller or nil,
        originId = originId, originAcquiredAt = originAcquiredAt,
        processId = processId, processRevision = processRevision }
    local ordered = {}
    for group, request in pairs(b.aidRequests) do
        ordered[#ordered + 1] = { eventId = group, eventAt = request.requestedAt }
    end
    table.sort(ordered, transferOrder)
    for i = 1, #ordered - TRANSFER_LIMIT do
        b.aidRequests[ordered[i].eventId] = nil
        b.aidRequestFloor = { eventAt = ordered[i].eventAt, eventId = ordered[i].eventId }
    end
    P.beliefVersion = P.beliefVersion + 1
    if processId and SAO.Organization and SAO.Organization.recordReception then
        local received = nil
        if source == "told" and SAO.Organization.recordTransportReception then
            received = SAO.Organization.recordTransportReception(processId,
                originId, id, processRevision, channel or source,
                teller, evidence or {
                    requestedAt = requestedAt, category = category })
        else
            received = SAO.Organization.recordReception(processId, id,
                processRevision, channel or source, teller or originId,
                evidence or { requestedAt = requestedAt, category = category })
        end
        if received ~= true then
            b.aidRequests[groupId] = existing
            return false
        end
    end
    return b.aidRequests[groupId] ~= nil
end

-- Request age and destination knowledge are independent. Hearing a request
-- can leave a person unable to locate the house that asked.
function P.knownAidRequests(id, nowHours)
    local current = transferNow()
    local b, now = P.beliefs[tostring(id or "")], transferNow(nowHours)
    if not now or not b or type(b.aidRequests) ~= "table" then
        return {}, "unavailable"
    end
    local out = {}
    for groupId, request in pairs(b.aidRequests) do
        if type(request) == "table" and transferNumber(request.requestedAt)
            and transferNumber(request.acquiredAt) and request.requestedAt >= 0
            and request.requestedAt <= request.acquiredAt and request.acquiredAt <= now
            and now - request.requestedAt <= AID_REQUEST_HOURS
            and (request.category == nil or request.category == "food")
            and (request.source == "requested" or request.source == "told") then
            -- C67 had one request producer, callForBread, so a persisted
            -- pre-C69 row with no category is unambiguously food.
            local category = request.category or "food"
            local copy = { groupId = groupId, category = category,
                requestedAt = request.requestedAt,
                acquiredAt = request.acquiredAt, source = request.source,
                teller = request.teller, originId = request.originId,
                originAcquiredAt = request.originAcquiredAt,
                processId = request.processId,
                processRevision = request.processRevision }
            local ground = b.factions and b.factions[groupId]
                or b.places and b.places[groupId]
            -- Legacy ground beliefs do not preserve this recipient's actual
            -- acquisition time. They support current routing, not a historical
            -- join that would give yesterday's request tomorrow's location.
            if now == current and type(ground) == "table" and transferNumber(ground.minX)
                and transferNumber(ground.minY) and transferNumber(ground.maxX)
                and transferNumber(ground.maxY) and ground.minX <= ground.maxX
                and ground.minY <= ground.maxY then
                copy.minX, copy.minY, copy.maxX, copy.maxY = ground.minX,
                    ground.minY, ground.maxX, ground.maxY
            end
            out[#out + 1] = copy
        end
    end
    table.sort(out, function(a, b)
        if a.requestedAt ~= b.requestedAt then return a.requestedAt < b.requestedAt end
        return tostring(a.groupId) < tostring(b.groupId)
    end)
    return out, "available"
end

function P.knownAidRequest(id, groupId, nowHours)
    local requests, availability = P.knownAidRequests(id, nowHours)
    for _, request in ipairs(requests) do
        if request.groupId == tostring(groupId or "") then return request, "available" end
    end
    return nil, availability == "available" and "not-known" or "unavailable"
end

function P.appraiseAidRequest(id, groupId, owner, currentActivity)
    if not (SAO.Coordination and SAO.Coordination.formResponse) then
        return nil, "coordination-unavailable"
    end
    local request = P.knownAidRequest(id, groupId)
    if not request or not request.processId then return nil, "request-unavailable" end
    return SAO.Coordination.formResponse(id, request.processId, nil,
        currentActivity or "dormant", owner or "Perception.aid-request")
end

local function tellAidRequests(fromId, toId, channel, aroundX, aroundY)
    local admitted, canConverse = pcall(function()
        return SAO.Communication.canConverse(fromId, toId, channel)
    end)
    if not admitted or canConverse ~= true then return 0 end
    local requests, moved = P.knownAidRequests(fromId), 0
    for _, request in ipairs(requests) do
        local inGround = true
        if aroundX and aroundY then
            local dx = request.minX and ((request.minX + request.maxX) / 2 - aroundX)
                or math.huge
            local dy = request.minY and ((request.minY + request.maxY) / 2 - aroundY)
                or math.huge
            inGround = request.source == "requested"
                and dx * dx + dy * dy <= P.GROUND_REACH * P.GROUND_REACH
        end
        local to = P.beliefs[toId]
        local existing = to and to.aidRequests and to.aidRequests[request.groupId]
        if inGround and (not existing or existing.requestedAt < request.requestedAt)
            and P.recordAidRequest(toId, request.groupId, request.requestedAt,
                "told", fromId, request.category, request.processId,
                request.processRevision, channel or "spoken",
                { teller = fromId }) then
            moved = moved + 1
            -- A bodyless recipient still answers from their own durable
            -- condition and relationship. The answer is formed here because
            -- this encounter proved acquisition; work waits for a body-owning
            -- executor and no dormant item transfer is invented.
            if request.processId and SAO.Coordination
                and SAO.Coordination.formResponse then
                SAO.Coordination.formResponse(toId, request.processId, nil,
                    "dormant", "Perception.dormant-encounter")
            end
        end
    end
    if SAO.Communication and SAO.Communication.deliverPendingResponses then
        moved = moved + SAO.Communication.deliverPendingResponses(
            fromId, toId, channel, { exchange = "aid-request" })
        moved = moved + SAO.Communication.deliverPendingResponses(
            toId, fromId, channel, { exchange = "aid-request" })
    end
    return moved
end

-- A non-witness can form a private response only from evidence that belongs to
-- them now.  The completed act and food request arrive independently; current
-- household membership and an explicit private ground claim join them.  No
-- historical body need, giver intent, trust write, or collectible debt is
-- reconstructed.  Once formed, this appraisal stays frozen with the episode.
function P.appraiseKnownTransfers(id)
    id = tostring(id or "")
    local now = transferNow()
    local b = P.beliefs[id]
    if id == "" or not now or not b or type(b.transfers) ~= "table"
        or not (SAO.Standing and SAO.Standing.groupOf
            and SAO.Standing.trust and SAO.Disposition
            and SAO.Disposition.testimonyAssistanceAppraisal) then return 0 end
    local okGroup, groupId = pcall(SAO.Standing.groupOf, id)
    groupId = okGroup and groupId and tostring(groupId) or nil
    if not groupId or groupId == "" then return 0 end
    local request = P.knownAidRequest(id, groupId, now)
    if not request or request.category ~= "food" then return 0 end
    local claim, claimKind = b.factions and b.factions[groupId], "faction"
    if type(claim) ~= "table" then
        claim, claimKind = b.places and b.places[groupId], "place"
    end
    if type(claim) ~= "table"
        or (claim.source ~= "observed" and claim.source ~= "heard"
            and claim.source ~= "told")
        or (claim.source == "told"
            and (type(claim.teller) ~= "string" or claim.teller == ""))
        or (claim.source ~= "told" and claim.teller ~= nil)
        or not transferNumber(claim.minX) or not transferNumber(claim.minY)
        or not transferNumber(claim.maxX) or not transferNumber(claim.maxY)
        or claim.minX > claim.maxX or claim.minY > claim.maxY then return 0 end
    local changed, horizon = 0, transferHorizon(id)
    for _, fact in pairs(b.transfers) do
        if transferState(fact, now, horizon) == "remembered"
            and fact.source == "told" and fact.operation == "store"
            and fact.category == request.category and fact.actorId ~= id
            and fact.appraisal == nil and request.requestedAt <= fact.eventAt
            and fact.x >= claim.minX and fact.x <= claim.maxX
            and fact.y >= claim.minY and fact.y <= claim.maxY then
            local okTrust, tellerTrust = pcall(SAO.Standing.trust,
                id, fact.teller)
            if okTrust and transferNumber(tellerTrust)
                and tellerTrust >= -1 and tellerTrust <= 1 then
                local okAppraisal, appraisal = pcall(
                    SAO.Disposition.testimonyAssistanceAppraisal,
                    id, fact.actorId, tellerTrust)
                if okAppraisal and type(appraisal) == "table" then
                    appraisal.basis = "testimony-household-request"
                    appraisal.appraisedAt = now
                    appraisal.requestGroupId = groupId
                    appraisal.requestCategory = request.category
                    appraisal.requestedAt = request.requestedAt
                    appraisal.requestAcquiredAt = request.acquiredAt
                    appraisal.requestSource = request.source
                    appraisal.requestTeller = request.teller
                    appraisal.requestOriginId = request.originId
                    appraisal.requestOriginAcquiredAt = request.originAcquiredAt
                    appraisal.claimKind = claimKind
                    appraisal.claimSource = claim.source
                    appraisal.claimTeller = claim.teller
                    appraisal.claimMinX, appraisal.claimMinY = claim.minX, claim.minY
                    appraisal.claimMaxX, appraisal.claimMaxY = claim.maxX, claim.maxY
                    fact.appraisal = appraisal
                    fact.appraisal = appraisalCopy(fact, now)
                    if fact.appraisal then changed = changed + 1 end
                end
            end
        end
    end
    if changed > 0 then P.beliefVersion = P.beliefVersion + 1 end
    return changed
end

local function split(s, sep)
    local parts = {}
    for piece in string.gmatch(s, "([^" .. sep .. "]+)") do
        parts[#parts + 1] = piece
    end
    return parts
end

-- A report describes a location and how many bodies were seen there. Its
-- ordinal has no relation to the witness's private continuous sight tracks.
local function zombieTile(belief)
    return belief.x .. "," .. belief.y
        .. (belief.z ~= nil and ("," .. belief.z) or "")
end

-- Sight memories and co-located reports have no population-sized bound.
-- Kahlua's recursive quicksort can exhaust its stack before the request is
-- trimmed. Merge adjacent runs iteratively: O(n log n) work, O(n) scratch,
-- and fixed call depth regardless of input order or report multiplicity.
local function sortSightEvidence(values, less)
    local count, width, scratch = #values, 1, {}
    while width < count do
        for first = 1, count, width * 2 do
            local middle = math.min(first + width, count + 1)
            local finish = math.min(first + width * 2, count + 1)
            local left, right = first, middle
            for out = first, finish - 1 do
                if left < middle and (right >= finish
                    or not less(values[right], values[left])) then
                    scratch[out] = values[left]
                    left = left + 1
                else
                    scratch[out] = values[right]
                    right = right + 1
                end
            end
        end
        for i = 1, count do values[i] = scratch[i] end
        width = width * 2
    end
end

-- Shared fixed-depth ordering; callers retain their own comparator and bounds.
P.sortEvidence = sortSightEvidence

local function zombieReports(zombies, accept)
    local ordered, reports, counts = {}, {}, {}
    for key, belief in pairs(zombies or {}) do
        if accept(belief) then
            ordered[#ordered + 1] = { key = tostring(key), belief = belief }
        end
    end
    sortSightEvidence(ordered, function(a, b)
        if a.belief.at ~= b.belief.at then return a.belief.at > b.belief.at end
        return a.key < b.key
    end)
    for _, row in ipairs(ordered) do
        local tile = zombieTile(row.belief)
        counts[tile] = (counts[tile] or 0) + 1
        local key = tile .. (counts[tile] > 1 and ("#" .. counts[tile]) or "")
        reports[key] = row.belief
    end
    return reports
end

local function knownZombieTiles(b, body)
    local keys, used, distance = {}, {}, {}
    local sx, sy, sz = body:getX(), body:getY(), body:getZ()
    for _, belief in pairs(b.zombies) do
        -- Old saves did not record floor. New sight cannot assign one to an
        -- old memory, so only a floor-bearing location requests correction.
        local dx, dy = belief.x - sx, belief.y - sy
        if belief.z ~= nil and math.abs(belief.z - sz) < 0.5
            and dx * dx + dy * dy <= SCANNER_SIGHT_RANGE * SCANNER_SIGHT_RANGE
            and belief.phantom ~= true then
            local key = zombieTile(belief)
            if not used[key] then keys[#keys + 1] = key used[key] = true end
            distance[key] = dx * dx + dy * dy
        end
    end
    sortSightEvidence(keys, function(a, c)
        if distance[a] ~= distance[c] then return distance[a] < distance[c] end
        return a < c
    end)
    while #keys > 512 do keys[#keys] = nil end
    return table.concat(keys, ";")
end

-- Acquisition: ask the scanner what is visible, integrate as observed beliefs.
-- [B19] `asleep` is not decoration. Acquisition used to run
-- "regardless of state", and that included asleep - so every
-- sleeping survivor in the county was a perfect sentry, registering
-- every zombie and passerby all night with their eyes shut. Nothing
-- depended on it, because nothing had to: an unwatched house was
-- never punished. Asleep, only what is effectively on top of you
-- registers, and nothing else does.
local observeOccupiedBuilding
local APERTURE_STATES = { open = true, closed = true, barricaded = true,
    smashed = true, clear = true, unknown = true }
-- Re-observation refreshes evidence without replacing a different entrance.
function P.exteriorLeadKey(lead)
    if type(lead) ~= "table" then return nil end
    local buildingId = tostring(lead.buildingId or "")
    if #buildingId > 20 or not string.match(buildingId, "^%-?%d+$")
        or not finiteSoundNumber(lead.cx) or not finiteSoundNumber(lead.cy)
        or not finiteSoundNumber(lead.surfaceX) or not finiteSoundNumber(lead.surfaceY)
        or not finiteSoundNumber(lead.z) or lead.z ~= math.floor(lead.z)
        or (lead.kind ~= "door" and lead.kind ~= "window" and lead.kind ~= "wall")
        or math.abs(lead.surfaceX - lead.cx) + math.abs(lead.surfaceY - lead.cy) ~= 0.5 then return nil end
    return buildingId .. ":" .. tostring(lead.surfaceX) .. ":" .. tostring(lead.surfaceY)
        .. ":" .. tostring(lead.cx) .. ":" .. tostring(lead.cy) .. ":" .. tostring(lead.z) .. ":" .. lead.kind
end
local function observeExteriorLead(id, body, b, fields, tick)
    if (#fields ~= 8 and #fields ~= 9) or not finiteSoundNumber(tick) or not body then return end
    local rec = SAO.Identity and SAO.Identity.get(id)
    local own = SAO.Body and SAO.Body.get and SAO.Body.get(id)
    local ok, admitted = pcall(function()
        local md = body:getModData()
        return rec and not rec.dead and own == body and not body:isDead() and not body:isAsleep()
            and md and tostring(md.SAOPersonId) == tostring(id) and not md.SAO_ObserverAnchor
    end)
    if not ok or not admitted then return end
    local key, sx, sy, z = fields[2], tonumber(fields[3]), tonumber(fields[4]), tonumber(fields[5])
    local x, y, kind = tonumber(fields[6]), tonumber(fields[7]), fields[8]
    local apertureState = fields[9] or "unknown"
    if not string.match(key or "", "^%-?%d+$") or #key > 20
        or not finiteSoundNumber(sx) or not finiteSoundNumber(sy) or not finiteSoundNumber(z)
        or not finiteSoundNumber(x) or not finiteSoundNumber(y) or z ~= math.floor(z)
        or (kind ~= "door" and kind ~= "window" and kind ~= "wall")
        or not APERTURE_STATES[apertureState]
        or math.abs(sx - x) + math.abs(sy - y) ~= 0.5 then return end
    local lead = { buildingId = key, cx = x, cy = y, z = z,
        surfaceX = sx, surfaceY = sy, kind = kind, at = tick,
        source = "native-visible-exterior", personId = tostring(id), apertureState = apertureState }
    local approachId = P.exteriorLeadKey(lead)
    if not approachId then return end
    b.buildingLeads = b.buildingLeads or {}
    local prior = b.buildingLeads[approachId]
    if prior and (apertureState == "unknown" or (prior.apertureState or "unknown") == "unknown"
        or apertureState == prior.apertureState) then
        lead.entryFailure = prior.entryFailure
    end
    if not b.buildingLeads[approachId] then
        local count, oldestKey, oldest = 0, nil, nil
        for savedKey, lead in pairs(b.buildingLeads) do
            count = count + 1
            if not oldest or lead.at < oldest then oldestKey, oldest = savedKey, lead.at end
        end
        if count >= 64 then b.buildingLeads[oldestKey] = nil end
    end
    b.buildingLeads[approachId] = lead
    P.beliefVersion = P.beliefVersion + 1
end

-- Native route ownership authenticates the observation. A failed route's goal
-- never substitutes for the edge the body actually encountered.
local function retainEntryExperience(id,rec,lead,key,at,condition,succeeded)
    local prior=rec.entryExperienceSequence or 0
    if not finiteSoundNumber(prior) or prior<0 then return false end
    local sequence=prior+1
    if not finiteSoundNumber(sequence) or sequence>9007199254740991 or sequence~=math.floor(sequence) then return false end
    rec.entryExperienceSequence=sequence
    local receipt={actorId=id,kind="entry-outcome",sequence=sequence,atHours=at,
        sourceId="exterior:"..key,actionKind=lead.kind,apertureState=condition or "unknown",succeeded=succeeded==true}
    rec.entryExperiences=rec.entryExperiences or {}
    rec.entryExperiences[#rec.entryExperiences+1]=receipt
    if #rec.entryExperiences>32 then table.remove(rec.entryExperiences,1) end
    if SAO.Cognition and SAO.Cognition.behaviorOutcome then SAO.Cognition.behaviorOutcome(id,receipt) end
    return true
end
function P.behaviorOutcome(id,sequence)
    local rec=SAO.Identity and SAO.Identity.get(id)
    for _,receipt in ipairs(rec and rec.entryExperiences or {}) do
        if receipt.sequence==sequence then local out={} for k,v in pairs(receipt) do out[k]=v end return out end
    end
end
-- Native movement retains the actual directed aperture crossing and its
-- pre-attempt condition. Arrival at the proposed interior tile is insufficient.
function P.noteEntrySuccess(id,body,job)
    local rec=SAO.Identity and SAO.Identity.get(id)
    local purpose=SAO.ProceduralPlanning and SAO.ProceduralPlanning.residencePurpose(id)
    local destination=purpose and purpose.destination
    local agent=SAO.Controller and SAO.Controller.agents[id]
    local binding=agent and agent.residenceRoute
    if type(job)~="table" or not rec or rec.dead or not purpose or purpose.cursor~=2
        or not destination or not destination.exterior or not purpose.admission
        or not binding or binding.job~=job or binding.routeId~=purpose.admission.correlationId
        or SAO.Body.get(id)~=body or SAO.Locomotion.jobs[id]~=job or job.body~=body
        or not job.done or job.result~="arrived" or job.entryOutcomeRecorded
        or not finiteSoundNumber(job.nativeRouteGeneration) or job.nativeRouteGeneration<1 then return false end
    local step=purpose.steps[2]
    if not step or not job.goal or step.x~=job.goal.x or step.y~=job.goal.y or step.z~=job.goal.z then return false end
    local key=destination.approachId
    local b=P.beliefs[id]
    local lead=b and b.buildingLeads and b.buildingLeads[key]
    if not lead or lead.personId~=id or P.exteriorLeadKey(lead)~=key
        or lead.kind~="door" and lead.kind~="window" then return false end
    local known=P.knownPlaces(id)
    if not known[lead.buildingId] and not known[tonumber(lead.buildingId)] then return false end
    local ok,owned=pcall(function()
        return not body:isDead() and not body:isAsleep() and tostring(body:getModData().SAOPersonId)==id
            and not body:getModData().SAO_ObserverAnchor
    end)
    if not ok or not owned then return false end
    for index,crossing in ipairs(job.crossings or {}) do
        if index>16 then break end
        if type(crossing)=="table" and crossing.source=="native-route-crossing"
            and crossing.route==job.nativeRouteGeneration and crossing.kind==lead.kind
            and finiteSoundNumber(crossing.sequence) and crossing.sequence>=1
            and finiteSoundNumber(crossing.x) and finiteSoundNumber(crossing.y)
            and finiteSoundNumber(crossing.tx) and finiteSoundNumber(crossing.ty)
            and crossing.z==lead.z and APERTURE_STATES[crossing.apertureState]
            and math.abs(crossing.x-crossing.tx)+math.abs(crossing.y-crossing.ty)==1
            and lead.cx==crossing.x+0.5 and lead.cy==crossing.y+0.5
            and lead.surfaceX==(crossing.x+crossing.tx+1)/2
            and lead.surfaceY==(crossing.y+crossing.ty+1)/2 then
            job.entryOutcomeRecorded=true
            lead.entryFailure=nil
            return retainEntryExperience(id,rec,lead,key,SAO.History.countyHours(),crossing.apertureState,true)
        end
    end
    return false
end
function P.noteEntryOutcome(id, body, job)
    local rec = SAO.Identity and SAO.Identity.get(id)
    local own = SAO.Body and SAO.Body.get and SAO.Body.get(id)
    local live = SAO.Locomotion and SAO.Locomotion.jobs and SAO.Locomotion.jobs[id]
    local edge = type(job) == "table" and job.barrier
    if type(job) ~= "table" or not rec or rec.dead or own ~= body or live ~= job or not job.done or job.body ~= body
        or type(edge) ~= "table" or edge.source ~= "native-route-interaction"
        or job.result ~= "FailedObstacle:" .. tostring(edge.reason) then return false end
    local accepted = { FAILED_LOCKED_DOOR = "door", FAILED_BARRICADED_DOOR = "door",
        FAILED_BARRICADED_WINDOW = "window", FAILED_WINDOW_DECLINED = "window",
        FAILED_BLOCKED_WINDOW = "window" }
    if accepted[edge.reason] ~= edge.kind then return false end
    for _, value in ipairs({ edge.x, edge.y, edge.tx, edge.ty, edge.z }) do
        if not finiteSoundNumber(value) or value ~= math.floor(value) then return false end
    end
    if not (finiteSoundNumber(edge.x) and finiteSoundNumber(edge.y)
        and finiteSoundNumber(edge.tx) and finiteSoundNumber(edge.ty) and finiteSoundNumber(edge.z))
        or math.abs(edge.x - edge.tx) + math.abs(edge.y - edge.ty) ~= 1 then return false end
    local ok, at, tick = pcall(function()
        local md = body:getModData()
        if body:isDead() or body:isAsleep() or not md or tostring(md.SAOPersonId) ~= tostring(id)
            or md.SAO_ObserverAnchor then return nil end
        return SAO.History.countyHours(), SAO.History.ticks()
    end)
    if not ok or not finiteSoundNumber(at) or not finiteSoundNumber(tick) then return false end
    local b, scanned = P.beliefs[id], 0
    for key, lead in pairs(b and b.buildingLeads or {}) do
        scanned = scanned + 1
        if scanned > 64 then break end
        if type(lead) == "table" and lead.personId == tostring(id)
            and lead.source == "native-visible-exterior" and P.exteriorLeadKey(lead) == key
            and finiteSoundNumber(lead.at) and lead.at <= tick and lead.kind == edge.kind
            and lead.cx == edge.x + 0.5 and lead.cy == edge.y + 0.5 and lead.z == edge.z
            and lead.surfaceX == (edge.x + edge.tx + 1) / 2
            and lead.surfaceY == (edge.y + edge.ty + 1) / 2 then
            if job.entryOutcomeRecorded then return false end
            local old = lead.entryFailure
            local attempts = type(old) == "table" and tonumber(old.attempts) or 0
            if not finiteSoundNumber(attempts) then attempts = 0 end
            lead.entryFailure = { reason = edge.reason, apertureState = edge.apertureState,
                at = tick, atHours = at, attempts = math.min(4, math.max(0, attempts) + 1),
                source = "native-route-interaction" }
            job.entryOutcomeRecorded = true
            retainEntryExperience(id,rec,lead,key,at,edge.apertureState)
            P.beliefVersion = P.beliefVersion + 1
            return true
        end
    end
    return false
end
local function rememberAudibleSound(id, body, b, entry, f, tick)
    -- The native scanner supplies personal audibility and an imprecise origin.
    -- Neither its quick path nor its full path identifies a cause or speaker.
    local x, y, d = tonumber(f[2]), tonumber(f[3]), tonumber(f[4])
    if not x or not y then return end
    local key = x .. "," .. y
    acquireSoundCue(id, body, entry, f, x, y, d, tick)
    local recognised = b.criedTiles and b.criedTiles[key]
    if not recognised or (tick - recognised) > CRY_RECOGNITION then
        b.sounds[key] = { x = x, y = y, dist = d, at = tick,
            source = "heard", kind = "unknown" }
    end
end

local function observeWeekOnePerformances(id, body)
    local source = SAO.WeekOneContinuity
    if not source or not source.livePerformanceIds then return end
    local listed, performers = pcall(source.livePerformanceIds)
    if listed and type(performers) == "table" then
        for _, performerId in ipairs(performers) do
            pcall(P.acquireWeekOnePerformanceHearing, id, body, performerId)
        end
    end
end

local function observeAudible(id, body, b, tick, asleep)
    -- Native sounds expire in engine updates, before the county-time sight
    -- cadence may run. Acquire this person's sound first, on every awake
    -- callback, including a callback that also performs a full sight scan.
    -- A performance claim consumes that exact scanner acquisition; trying
    -- the claim first can lose a pulse with only one live callback.
    if not asleep and SAOJavaBridge and SAOJavaBridge.perceiveAudibleSounds then
        local ok, heard = pcall(function()
            return SAOJavaBridge:perceiveAudibleSounds(body)
        end)
        if ok and type(heard) == "string" and heard ~= "" then
            for _, entry in ipairs(split(heard, "|")) do
                local f = split(entry, ":")
                if f[1] == "S" and #f >= 4 then
                    rememberAudibleSound(id, body, b, entry, f, tick)
                end
            end
        end
    end
    -- Source-owned performance audio and its WorldSound can end before the
    -- next sight scan. The claim still requires exact live source custody.
    if not asleep then observeWeekOnePerformances(id, body) end
end

function P.observeAudible(id, body, tick, asleep)
    local b = store(id)
    observeAudible(id, body, b, tick, asleep)
end

function P.observe(id, body, tick, asleep)
    local b = store(id)
    observeAudible(id, body, b, tick, asleep)
    if tick - b.lastScanAt < SCAN_INTERVAL then
        -- A person can change exact body custody within one county tick. The
        -- sight throttle may hold, but the new body cannot borrow old sight.
        if not asleep and (not conceptObservers[id]
            or conceptObservers[id].body ~= body) then
            pcall(function() P.observeConcepts(id, body, tick) end)
        end
        return
    end
    local priorScanAt = b.lastScanAt
    b.lastScanAt = tick
    b.scanCount = b.scanCount + 1

    -- [B42] Whoever has a body learns the ground they are standing on,
    -- on the same cadence they see by. Placed here rather than in the
    -- controller's tick because this is exactly where the LIVE half of
    -- perception already throttles itself, and because it must not
    -- depend on the bridge below - whose house this is is read off the
    -- county's own claims, not off the engine.
    --
    -- The player runs through here too ([B41]), so they now learn a
    -- neighbour's ground by walking past it rather than only by being
    -- told about it.
    pcall(function()
        P.learnGroundNear(id, body:getX(), body:getY())
    end)
    if not asleep then
        pcall(function() observeOccupiedBuilding(id, body, tick) end)
        pcall(function() P.observeConcepts(id, body, tick) end)
        pcall(function() P.observeLooseItems(id, body, tick) end)
    end

    if not SAOJavaBridge then return end
    local ok, seen = pcall(function()
        return SAOJavaBridge:perceive(body, asleep and "" or knownZombieTiles(b, body))
    end)
    if not ok or type(seen) ~= "string" then return end

    local priorTracks, currentSight, covered = {}, {}, {}
    for key, belief in pairs(b.zombies) do
        if belief.source == "observed" and belief.track and belief.at == priorScanAt then
            priorTracks[belief.track] = key
        end
    end

    if seen ~= "" then
        local rows = split(seen, "|")
        if asleep then
            -- The scanner already reports a real distance per row, so
            -- this bound is READ, not modelled. Four tiles is "in the
            -- room with you".
            local near = {}
            for _, entry in ipairs(rows) do
                local f0 = split(entry, ":")
                if f0[1] == "Z" then
                    local dd = tonumber(f0[4])
                    if dd and dd <= 4.0 then near[#near + 1] = entry end
                end
            end
            rows = near
        end
        for _, entry in ipairs(rows) do
            local f = split(entry, ":")
            if f[1] == "Z" and #f >= 4 then
                local x, y, d = tonumber(f[2]), tonumber(f[3]), tonumber(f[4])
                if x and y then
                    local belief = { x = x, y = y, dist = d, at = tick, source = "observed",
                        nativeReferent = "zombie" }
                    if f[6] == "zao" and f[7] and f[8] then
                        belief.form = f[7]
                        belief.formPerformance = tonumber(f[8]) or 0
                    end
                    if f[9] == "attrs" and f[10] then
                        belief.attributeMutations = parseAttributes(f[10])
                    end
                    -- [C124] Ground stance: crawler, tripping, or prone zombie.
                    for idx = 5, #f do
                        if f[idx] == "prone" then
                            belief.prone = true
                            break
                        end
                    end
                    if belief.form and belief.form ~= "none" then
                        pcall(function()
                            local day = math.floor(
                                (SAO.History.countyHours() or 0) / 24.0)
                            SAO.Adaptation.observe(
                                id,
                                belief.form,
                                belief.formPerformance,
                                "lived",
                                day)
                        end)
                    end
                    for idx = 5, #f - 1 do
                        if f[idx] == "track" then belief.track = f[idx + 1] end
                        if f[idx] == "floor" then belief.z = tonumber(f[idx + 1]) end
                    end
                    local sightKey = zombieTile(belief)
                    if belief.track then
                        sightKey = priorTracks[belief.track]
                            or ("seen:" .. belief.track .. ":" .. tick)
                    end
                    b.zombies[sightKey] = belief
                    currentSight[sightKey] = true
                    -- The turned are recognizable ([B3], corrected
                    -- [C8]): the zombie's descriptor is built FRESH at
                    -- reanimation, so a name in field 5 never comes off
                    -- a turned body any more - the id does, riding the
                    -- modData the engine copies through the turn
                    -- (F-044). One resolver reads both forms; a known
                    -- face on the dead is still the county's darkest
                    -- moment, once per witness.
                    local ztag = f[5]
                    if ztag == "track" or ztag == "floor" then ztag = nil end
                    if ztag and ztag ~= "" then
                        local zid, zrec, zname =
                            SAO.Identity.resolveBodyTag(ztag)
                        if zrec and zrec.dead and zname then
                            local pb = b.people[zname]
                            -- A familiar person now visibly changed is a narrow
                            -- personal association. An unfamiliar Z row supplies
                            -- physical contact authority, not outbreak knowledge.
                            if not asleep and awarenessReceiver and pb and pb.source=="observed"
                                and finiteSoundNumber(pb.at) and pb.at<=tick and not pb.turnedSeen then
                                pcall(awarenessReceiver,id,body,zid,tick)
                            end
                            if not pb then
                                pb = { x = x, y = y, dist = d, at = tick,
                                    source = "observed", dead = true }
                                b.people[zname] = pb
                            end
                            pb.dead = true
                            if not pb.turnedSeen then
                                pb.turnedSeen = true
                                pb.turned = true
                                if P.turnedHandler then
                                    pcall(P.turnedHandler, id, zname,
                                        zid, x, y, tick)
                                end
                            end
                        end
                    end
                end
            elseif f[1] == "B" then
                observeExteriorLead(id, body, b, f, tick)
            elseif f[1] == "V" and #f == 4 then
                local x, y, z = tonumber(f[2]), tonumber(f[3]), tonumber(f[4])
                if x and y and z then covered[zombieTile({ x = x, y = y, z = z })] = true end
            elseif f[1] == "S" and #f >= 4 then
                rememberAudibleSound(id, body, b, entry, f, tick)
            elseif f[1] == "P" and #f >= 5 then
                local name = f[2]
                local x, y, d = tonumber(f[3]), tonumber(f[4]), tonumber(f[5])
                if name and x and y then
                    -- Durable knowledge survives the fresh look: colors
                    -- seen once are remembered ([A15] - a re-scan is a
                    -- position update, not amnesia).
                    local prev = b.people[name]
                    -- The reunion ([A28]): the observed write has
                    -- always outranked told-dead by replacement; now
                    -- the correction is a MOMENT. Scanner P rows are
                    -- living only (engine gate), so this never fires
                    -- on a corpse.
                    if prev and prev.dead and P.reunionHandler then
                        pcall(P.reunionHandler, id, name,
                            prev.teller, prev.presumed == true, tick)
                    end
                    local okRH, rh = pcall(function()
                        return SAO.History.countyHours()
                    end)
                    -- Returns teach ([A28]): seeing someone whose
                    -- departure you were told closes the out-claim
                    -- and updates the house's sense of how long that
                    -- kind of errand takes.
                    if prev and prev.out and okRH then
                        local dur = rh - (prev.out.saidAtHours or rh)
                        if dur > 0.2 then
                            local outKey = SAO.Standing.keyForObserved
                                and SAO.Standing.keyForObserved(name) or nil
                            local og9 = outKey and SAO.Standing.groupOf
                                and SAO.Standing.groupOf(outKey) or nil
                            if og9 and SAO.Standing.noteVentureReturn then
                                SAO.Standing.noteVentureReturn(
                                    og9, prev.out.kind, dur)
                            end
                            -- [B19] And they REPORT. This is the
                            -- moment the tree already finds; the
                            -- out-claim still holds the ground they
                            -- were sent to, which is exactly the
                            -- bound the briefing used on the way out.
                            -- Housemates only - you do not tell a
                            -- stranger where the hordes are.
                            if outKey and og9 and prev.out.x
                                and SAO.Standing.groupOf(id) == og9
                                and P.beliefs[outKey] then
                                local told = P.reportReturn(outKey, id,
                                    tick, prev.out.x, prev.out.y)
                                if told > 0 then
                                    pcall(function()
                                        SAO.Voice.onEvent(outKey,
                                            "report", tick)
                                    end)
                                end
                            end
                        end
                    end
                    local form, formPerformance, attributeMutations
                    if f[7] == "zao" and f[8] and f[9] then
                        form = f[8]
                        formPerformance = tonumber(f[9]) or 0
                        if f[10] == "attrs" and f[11] then
                            attributeMutations = parseAttributes(f[11])
                        end
                    end
                    -- [C116] A living person carrying a form teaches
                    -- the witness what that form is, the same moment a
                    -- formed zombie does - the returned afflicted are
                    -- the county's own mid-course people, and what
                    -- their neighbors learn from seeing them is the
                    -- same learning, on the same cadence.
                    if form and form ~= "none" then
                        pcall(function()
                            local day = math.floor(
                                (SAO.History.countyHours() or 0) / 24.0)
                            SAO.Adaptation.observe(
                                id,
                                form,
                                formPerformance,
                                "lived",
                                day)
                        end)
                    end
                    local prone = (f[6] and string.find(f[6], "+p", 1, true) ~= nil) or false
                    local observedFloor
                    for index=7,#f-1 do
                        if f[index]=="floor" then
                            local floor=tonumber(f[index+1])
                            if finiteSoundNumber(floor) and floor==math.floor(floor) then observedFloor=floor end
                        end
                    end
                    b.people[name] = { x = x, y = y, z = observedFloor, dist = d, at = tick,
                        atHours = okRH and rh or nil,
                        source = "observed", condition = f[6] or "ok",
                        seenInFaction = prev and prev.seenInFaction or nil,
                        form = form,
                        formPerformance = formPerformance,
                        attributeMutations = attributeMutations,
                        prone = prone }
                end
            end
        end
    end

    -- Faction acquisition ([A15]): standing within sight of a HELD place
    -- forms an observed belief about it - where it is and whose it is not
    -- (theirs). The claim rects are the scan's world-read edge, the same
    -- as seeing a zombie is. What they CALL themselves is never observed;
    -- names travel only by word of mouth.
    -- [B19] You do not learn whose ground you are standing on with
    -- your eyes shut.
    if not asleep and SAO.Standing and SAO.Standing.allGroupClaims then
        local bx2, by2 = body:getX(), body:getY()
        local myGroup = SAO.Standing.groupOf and SAO.Standing.groupOf(id) or nil
        for groupName, c in pairs(SAO.Standing.allGroupClaims()) do
            if groupName ~= myGroup
                and bx2 >= c.minX - P.FACTION_SIGHT
                and bx2 <= c.maxX + P.FACTION_SIGHT
                and by2 >= c.minY - P.FACTION_SIGHT
                and by2 <= c.maxY + P.FACTION_SIGHT then
                local existing = b.factions[groupName]
                b.factions[groupName] = {
                    baseX = math.floor((c.minX + c.maxX) / 2),
                    baseY = math.floor((c.minY + c.maxY) / 2),
                    minX = c.minX, minY = c.minY, maxX = c.maxX, maxY = c.maxY,
                    at = tick, source = "observed",
                    name = existing and existing.name or nil,
                    stance = existing and existing.stance or "neutral",
                }
            end
        end
        -- Place acquisition ([A15]): a scanned person standing inside
        -- THEIR OWN claim is the observable scene "that is their place" -
        -- the claim rect is the same world-read edge the faction block
        -- uses. Durable; told never overrides observed.
        for name, pb in pairs(b.people) do
            if (tick - pb.at) <= SCAN_INTERVAL * 2 then
                local ownerKey = SAO.Standing.keyForObserved
                    and SAO.Standing.keyForObserved(name) or nil
                local oc = ownerKey and SAO.Standing.claimOf
                    and SAO.Standing.claimOf(ownerKey) or nil
                if oc and pb.x >= oc.minX and pb.x <= oc.maxX
                    and pb.y >= oc.minY and pb.y <= oc.maxY then
                    b.places[ownerKey] = {
                        minX = oc.minX, minY = oc.minY,
                        maxX = oc.maxX, maxY = oc.maxY,
                        at = tick, source = "observed",
                    }
                end
            end
        end

        -- Membership is inferred from where people stand: a person seen
        -- INSIDE a believed base wears its colors in this survivor's eyes.
        for name, pb in pairs(b.people) do
            if (tick - pb.at) <= SCAN_INTERVAL * 2 then
                for groupName, fb in pairs(b.factions) do
                    if pb.x >= fb.minX and pb.x <= fb.maxX
                        and pb.y >= fb.minY and pb.y <= fb.maxY then
                        pb.seenInFaction = groupName
                    end
                end
            end
        end
    end

    -- Current sight retires only a location the native scanner certified as
    -- fully visible on its recorded floor. Omission alone is never absence.
    for key, belief in pairs(b.zombies) do
        if belief.z ~= nil and covered[zombieTile(belief)]
            and not currentSight[key] and belief.phantom ~= true then
            b.zombies[key] = nil
        end
    end

    -- decay pass
    local zombieHorizon2 = horizonFor(id, "zombies") * 2   -- [C32] this person's
    local peopleHorizon2 = horizonFor(id, "people") * 2
    for key, belief in pairs(b.zombies) do
        if tick - belief.at > zombieHorizon2 then b.zombies[key] = nil end
    end
    for key, belief in pairs(b.sounds) do
        if tick - belief.at > zombieHorizon2 then b.sounds[key] = nil end
    end
    for name, belief in pairs(b.people) do
        -- F-033: memory of the dead is durable - a dead-flagged belief
        -- never decays, or the news would die with the clock and the
        -- county could not keep retelling its losses.
        if not belief.dead
            and tick - belief.at > peopleHorizon2 then
            b.people[name] = nil
        end
    end
    -- [B20] Recognised cries expire like everything else. Without this
    -- the table gains a permanent entry per cry per tile, in every
    -- hearer, persisted - an unbounded leak dressed as a memory. Past
    -- the recognition window the mark does nothing anyway, so keeping
    -- it is pure cost.
    if b.criedTiles then
        for key, at in pairs(b.criedTiles) do
            if tick - at > CRY_RECOGNITION then b.criedTiles[key] = nil end
        end
    end
    -- [B35] A place is unlearned the way it was learned: by being
    -- there. `places` was the one table nothing ever cleared, and
    -- unlike a stale sighting it was also WRONG - releaseClaim drops
    -- the claim and touches no belief, and believesClaimed asks
    -- whether the owner died but never whether the claim still
    -- stands. Ground given up stayed avoided for the whole session.
    --
    -- Not expiry by time: line 244 is right that place knowledge is
    -- durable, and a house does not stop being someone's because
    -- nobody looked at it. Proximity, so a survivor learns the ground
    -- is free by standing on it rather than by being told from
    -- nowhere.
    if b.places and SAO.Standing and SAO.Standing.claimOf then
        local okP, px, py = pcall(function()
            return body:getX(), body:getY()
        end)
        if okP and px and py then
            for ownerKey, pc in pairs(b.places) do
                if px >= pc.minX - P.PLACE_SIGHT
                    and px <= pc.maxX + P.PLACE_SIGHT
                    and py >= pc.minY - P.PLACE_SIGHT
                    and py <= pc.maxY + P.PLACE_SIGHT
                    and not SAO.Standing.claimOf(ownerKey) then
                    b.places[ownerKey] = nil
                end
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Query API (what the controller is allowed to know)

-- Distance is PERSONAL (F-014): a belief's position is memory, but how far
-- it is from ME is a fact about me, now. When the asker's position is
-- given, distance is recomputed from it; the formation-time value is only
-- the fallback for callers without a body.
local function distanceFor(belief, fromX, fromY)
    if fromX and fromY then
        local dx, dy = belief.x - fromX, belief.y - fromY
        return math.sqrt(dx * dx + dy * dy)
    end
    return belief.dist
end

-- Nearest zombie this survivor currently BELIEVES in, or nil. Never scans.
-- The returned table carries dist AS SEEN FROM (fromX, fromY) when given.
function P.nearestBelievedZombie(id, tick, fromX, fromY)
    local b = P.beliefs[id]
    if not b then return nil end
    local best, bestDist
    local horizon = horizonFor(id, "zombies")   -- [C32]
    for _, belief in pairs(b.zombies) do
        if (belief.source ~= "heard" or belief.phantom == true)
            and tick - belief.at <= horizon then
            local d = distanceFor(belief, fromX, fromY)
            if not best or d < bestDist then best, bestDist = belief, d end
        end
    end
    if best then
        return { x = best.x, y = best.y, z = best.z, dist = bestDist, at = best.at,
                 source = best.source, teller = best.teller, track = best.track,
                 form = best.form, formPerformance = best.formPerformance,
                 attributeMutations = best.attributeMutations,
                 prone = best.prone and true or false,
                 nativeReferent = "zombie", recognition = contactRecognition(id) }
    end
    return nil
end

-- Detached locations for a person's route-consequence appraisal. These are
-- beliefs, not a census or reacquired native targets: separate sight records
-- can describe the same body. Consumers must not add their multiplicity to
-- threat counts or refresh their original acquisition time.
function P.believedZombieContacts(id, tick, fromX, fromY, fromZ)
    local out, b = {}, P.beliefs[id]
    if not b or not finiteSoundNumber(tick) or not finiteSoundNumber(fromX)
        or not finiteSoundNumber(fromY) or not finiteSoundNumber(fromZ) then return out end
    local horizon = horizonFor(id, "zombies")
    local candidates, latest = {}, {}
    for key, belief in pairs(b.zombies or {}) do
        if type(belief) == "table" and finiteSoundNumber(belief.at)
            and tick >= belief.at and tick - belief.at <= horizon
            and finiteSoundNumber(belief.x) and finiteSoundNumber(belief.y)
            and (belief.z == nil or finiteSoundNumber(belief.z) and belief.z == math.floor(belief.z))
            and (belief.source == "observed" or belief.source == "told"
                or belief.source == "heard" and belief.phantom == true) then
            candidates[#candidates + 1] = { beliefKey = tostring(key), x = belief.x, y = belief.y, z = belief.z,
                dist = distanceFor(belief, fromX, fromY), at = belief.at,
                source = belief.source, teller = belief.teller, track = belief.track,
                phantom = belief.phantom == true, nativeReferent = "zombie",
                recognition = contactRecognition(id) }
            if belief.source == "observed" and type(belief.track) == "string" and belief.track ~= "" then
                latest[belief.track] = math.max(latest[belief.track] or belief.at, belief.at)
            end
        end
    end
    -- A failed scan can advance lastScanAt without replacing the prior sight
    -- row. Only the same native continuous track supplies identity authority
    -- to supersede its older position. Reacquisition tracks and reports remain
    -- separate hypotheses; equal-time contradictory locations remain uncertain.
    -- Apply precedence before floor filtering, so a newer other-floor sight
    -- does not leave the person's older same-floor location in this projection.
    for _, belief in ipairs(candidates) do
        local newer = belief.source == "observed" and latest[belief.track]
            and latest[belief.track] > belief.at
        if not newer and (belief.z == nil or belief.z == fromZ) then
            out[#out + 1] = belief
        end
    end
    table.sort(out, function(a, b) return a.beliefKey < b.beliefKey end)
    return out
end

-- [C116] The nearest LIVING person this survivor believes carries a
-- form - the returned afflicted, ghoul-shaped in a person's clothes
-- ([MUTATION.md]: the residue rides what capability survived). The
-- belief is a person-belief and decays on the people horizon; what it
-- carries is the form the scanner appended from the marks the
-- adoption stamped. The name rides along because a person is not a
-- tile: who they are is half of what seeing them means.
function P.nearestFormedPerson(id, tick, fromX, fromY)
    local b = P.beliefs[id]
    if not b then return nil end
    local best, bestDist, bestName
    local horizon = horizonFor(id, "people")   -- [C32]
    for name, belief in pairs(b.people) do
        if belief.form and belief.form ~= "none"
            and tick - belief.at <= horizon then
            local d = distanceFor(belief, fromX, fromY)
            if not best or d < bestDist then
                best, bestDist, bestName = belief, d, name
            end
        end
    end
    if best then
        return { x = best.x, y = best.y, z = best.z, dist = bestDist, at = best.at,
                 source = best.source, name = bestName,
                 form = best.form, formPerformance = best.formPerformance,
                 attributeMutations = best.attributeMutations,
                 fromPerson = true,
                 prone = best.prone and true or false }
    end
    return nil
end

-- [C117] Does this survivor currently BELIEVE a person carries a
-- form, and which? The belief reader for every standing-side
-- question about the afflicted among the living: keyed the way
-- beliefs are keyed (the person's belief key), fresh on the people
-- horizon, answering the form or nil. Never a scan, never the truth
-- - what they believe, which is what the house argues over and the
-- company door reads.
function P.believedFormOf(id, otherKey, tick)
    local rec = SAO.Identity and SAO.Identity.get
        and SAO.Identity.get(otherKey) or nil
    local key = rec and SAO.Identity.beliefKey(rec) or nil
    if not key then return nil end
    local pb = P.believedPerson(id, key)
    if not pb then return nil end
    if not (pb.form and pb.form ~= "none") then return nil end
    local horizon = horizonFor(id, "people")   -- [C32]
    if tick - (pb.at or 0) > horizon then return nil end
    return pb.form
end

-- [C116] The nearest believed carrier of a form, living or dead: the
-- zombie the survivor believes in and the person they believe is
-- shaped, whichever is closer. This is the pathogen pressure's read -
-- a body that carries the form presses the same nerve whatever
-- clothes it is wearing - and it is a SEPARATE query because the
-- callers that must never conflate the two (the engage machinery,
-- the threat count) still use the two single-kind queries.
function P.nearestBelievedThreat(id, tick, fromX, fromY)
    local zombie = P.nearestBelievedZombie(id, tick, fromX, fromY)
    local formed = P.nearestFormedPerson(id, tick, fromX, fromY)
    if formed and (not zombie or formed.dist < zombie.dist) then
        return formed
    end
    return zombie
end

function P.believedThreatCount(id, tick, radius, fromX, fromY)
    local b = P.beliefs[id]
    if not b then return 0 end
    local n, tiles = 0, {}
    local horizon = horizonFor(id, "zombies")   -- [C32]
    for _, belief in pairs(b.zombies) do
        if (belief.source ~= "heard" or belief.phantom == true)
            and tick - belief.at <= horizon
            and distanceFor(belief, fromX, fromY) <= (radius or 10) then
            if belief.phantom == true then
                n = n + 1
            else
                local key = zombieTile(belief)
                local tile = tiles[key] or { observed = 0, told = 0 }
                tiles[key] = tile
                local kind = belief.source == "told" and "told" or "observed"
                tile[kind] = tile[kind] + 1
            end
        end
    end
    -- A location report and one's own sight at that location are overlapping
    -- evidence, not two extra bodies. Multiple direct bodies remain distinct.
    for _, tile in pairs(tiles) do n = n + math.max(tile.observed, tile.told) end
    return n
end

-- Distinguishes "believes clear" from "has not looked recently".
function P.hasLookedRecently(id, tick)
    local b = P.beliefs[id]
    return b ~= nil and (tick - b.lastScanAt) <= SCAN_INTERVAL * 3
end

-- [C32] A threat nobody else hears (SAO_Conditions.hearsThingsNow;
-- Scotty's hallucination, at the county's cadence): a heard belief
-- placed six to twelve tiles off, on a bearing that is a fact about
-- the person and the moment, held and acted on like any other heard
-- belief and forgotten by the same decay. Marked so the record can
-- tell a phantom from a sound.
function P.hallucinate(id, tick, fromX, fromY)
    if not (fromX and fromY) then return nil end
    local b = store(id)
    local bearing = (SAO.Hash.of(id, "phantom-bearing:" .. tostring(tick)) % 360)
        * math.pi / 180
    local dist = 6 + (SAO.Hash.of(id, "phantom-dist:" .. tostring(tick)) % 7)
    local x = math.floor(fromX + math.cos(bearing) * dist)
    local y = math.floor(fromY + math.sin(bearing) * dist)
    b.zombies[x .. "," .. y] = { x = x, y = y, dist = dist, at = tick,
                                  source = "heard", phantom = true }
    return x, y
end

function P.believedPerson(id, name)
    local b = P.beliefs[id]
    return b and b.people[name] or nil
end

-- The people this person can name from their own retained knowledge.  This is
-- an addressing surface, not a reachability or liveness oracle: a privately
-- unknown death remains unknown, and an old location does not become proof
-- that speech can reach it.  Communication still has to admit the eventual
-- encounter before any proposal is received.
function P.knownPeople(id)
    local b = P.beliefs[tostring(id or "")]
    local out, seen = {}, {}
    for key, belief in pairs(b and b.people or {}) do
        if type(belief) == "table" and belief.dead ~= true then
            local otherId = belief.id
            if not otherId and SAO.Identity and SAO.Identity.idByName then
                otherId = SAO.Identity.idByName(key)
            end
            otherId = otherId and tostring(otherId) or nil
            if otherId and otherId ~= "" and otherId ~= tostring(id)
                and not seen[otherId] then
                seen[otherId] = true
                out[#out + 1] = {
                    id = otherId,
                    beliefKey = tostring(key),
                    observedAt = tonumber(belief.at),
                    observedAtHours = tonumber(belief.atHours),
                    lookedAt = tonumber(belief.lookedAt),
                    source = belief.source and tostring(belief.source) or nil,
                    x = tonumber(belief.x), y = tonumber(belief.y),
                    distance = tonumber(belief.dist),
                    condition = belief.condition
                        and tostring(belief.condition) or nil,
                    form = belief.form and tostring(belief.form) or nil,
                }
            end
        end
    end
    table.sort(out, function(a, b0)
        local ah, bh = tonumber(a.observedAtHours) or -math.huge,
            tonumber(b0.observedAtHours) or -math.huge
        if ah ~= bh then return ah > bh end
        local at, bt = tonumber(a.observedAt) or -math.huge,
            tonumber(b0.observedAt) or -math.huge
        if at ~= bt then return at > bt end
        return a.id < b0.id
    end)
    return out
end

-- Record that this person physically reached the last place where they knew
-- to look for somebody.  A newer sighting wins: arriving at yesterday's
-- address cannot consume knowledge acquired during the walk.  This marks a
-- failed location lead, not the other person's death, refusal, or absence
-- from the county.
function P.noteContactAttempt(id, beliefKey, observedAt, attemptedAt)
    id, beliefKey = tostring(id or ""), tostring(beliefKey or "")
    observedAt, attemptedAt = tonumber(observedAt), tonumber(attemptedAt)
    local b = P.beliefs[id]
    local belief = b and b.people and b.people[beliefKey] or nil
    if id == "" or beliefKey == "" or type(belief) ~= "table"
        or not observedAt or not attemptedAt
        or tonumber(belief.at) ~= observedAt then return false end
    belief.lookedAt = math.max(tonumber(belief.lookedAt) or 0, attemptedAt)
    return true
end

-- [C60] A participant candidate acquired by this person's own eyes. The
-- ordinary people horizon is memory; an immediate shared action needs the
-- last two scanner intervals and refuses told, dead or stale records.
function P.freshObservedPerson(id, name, tick, maxAge)
    if not (id and name and tick) then return nil end
    local belief = P.believedPerson(id, name)
    if not belief or belief.dead or belief.source ~= "observed" then
        return nil
    end
    local age = tick - (tonumber(belief.at) or -math.huge)
    if age < 0 or age > (maxAge or SCAN_INTERVAL * 2) then return nil end
    return belief
end

-- [C71] Laying eyes on somebody, from the half of the county that has
-- no eyes to scan with.
--
-- The live half writes this belief off the scanner - the `P` rows in
-- `observe` above. The dormant half has no body and no scanner, and it
-- has been producing firsthand meetings all along: two people standing
-- three tiles apart, teaching each other lessons, arguing doctrine,
-- passing grudges and credits, forming houses. None of it was ever
-- written down. Measured over eight counties of 1096 days: not one
-- survivor in any of them held a belief that a LIVING person was
-- anywhere, and the only person-beliefs that existed at all were death
-- notices. Law 1's second half calls that a defect - failing to act on
-- what they did see is as wrong as knowing what they did not.
--
-- Same write, same provenance, for a caller that knows who and where
-- rather than reading it off a scan. Durable knowledge survives it as
-- it does there: a fresh look is a position update, not amnesia.
function P.sawPerson(id, name, x, y, tick, otherId, dist)
    if not (id and name and x and y and tick) then return false end
    if name == "" or name == "Unnamed" then return false end
    local b = store(id)
    local prev = b.people[name]
    local hours = nil
    pcall(function() hours = SAO.History.countyHours() end)
    -- The reunion ([A28]): somebody you believed dead is standing in
    -- front of you. `observe` makes this a moment rather than a silent
    -- overwrite, and one rule with two spellings is how they drift.
    if prev and prev.dead and P.reunionHandler then
        pcall(P.reunionHandler, id, name, prev.teller,
            prev.presumed == true, tick)
    end
    b.people[name] = {
        x = x, y = y,
        -- [C87] The caller states the distance it measured; a road
        -- meeting passes the value it already computed rather than
        -- throwing it away, so a re-meeting refreshes the distance
        -- instead of carrying the first one forever. A caller that
        -- knows no distance - the same write from any other hand -
        -- keeps the seed honest: carried, then zero.
        dist = dist or (prev and prev.dist) or 0,
        at = tick, atHours = hours,
        source = "observed",
        condition = (prev and prev.condition) or "ok",
        seenInFaction = prev and prev.seenInFaction or nil,
        -- The dormant caller knows exactly who this is; the scanner
        -- never does, because it reads a name off a shell. Carried
        -- only where it is known, so `Identity.idByName` stays the
        -- answer everywhere else and this is never a second index.
        id = otherId and tostring(otherId) or (prev and prev.id) or nil,
    }
    return true
end

-- [C71] Somebody the county knew by their id has been given a name.
--
-- A person is keyed in this store by `Identity.beliefKey`, which is
-- their id until the engine hands `backfillName` a name off the first
-- shell built for them. Without this, everybody who had ever met them
-- would lose them at that moment and the county's memory of a person
-- would reset the first time a player walked near them.
--
-- Shaped on `Standing.migrateKey`, which does the same job for
-- relation rows. The sentinel is refused rather than moved: beliefs
-- keyed "Unnamed" were written before this batch and belong to no
-- particular person, so handing them to whoever materialises first
-- would invent a memory rather than carry one.
function P.migratePersonKey(oldKey, newKey)
    if not (oldKey and newKey) then return 0 end
    oldKey, newKey = tostring(oldKey), tostring(newKey)
    if oldKey == newKey or oldKey == "Unnamed" then return 0 end
    local moved = 0
    for _, b in pairs(P.beliefs) do
        local old = b.people and b.people[oldKey]
        if old then
            local held = b.people[newKey]
            -- The fresher sighting wins, and what only the older one
            -- knows is kept: a belief that somebody died does not
            -- expire because a newer look found their body walking.
            if not held or (old.at or 0) > (held.at or 0) then
                if held then
                    old.dead = old.dead or held.dead
                    old.turned = old.turned or held.turned
                    old.seenInFaction = old.seenInFaction
                        or held.seenInFaction
                end
                b.people[newKey] = old
            elseif old.dead and not held.dead then
                held.dead = true
                held.turned = held.turned or old.turned
            end
            b.people[oldKey] = nil
            moved = moved + 1
        end
    end
    return moved
end

-- [C71] Learning that somebody is dead, from the half of the county
-- that has no eyes.
--
-- `P.tell` carries death news between two people who are talking and
-- has always written this belief itself. The dormant attrition pass
-- wrote its own copy of the same thing - word reaching the bonded and
-- the company a day or two after somebody never came back - and it
-- read `P.beliefs[hearer]` directly rather than opening a store, so
-- for a survivor who had never been told anything by anybody the news
-- landed nowhere. In a dormant county that is nearly everybody: the
-- median county had ONE person in it holding any belief about any
-- person at all.
function P.learnOfDeath(id, key, x, y, tick, turned)
    if not (id and key and tick) then return false end
    if key == "" or key == "Unnamed" then return false end
    local b = store(id)
    local pb = b.people[key]
    if pb then
        pb.dead = true
        if turned then pb.turned = true end
    else
        b.people[key] = {
            x = x, y = y, dist = 999, at = tick,
            source = "told", dead = true, turned = turned or nil,
        }
    end
    if P.deathNewsHandler then
        pcall(P.deathNewsHandler, id, key, tick)
    end
    return true
end

function P.describe(id, tick)
    local b = P.beliefs[id]
    if not b then return "no-beliefs" end
    local zn, pn, sn = 0, 0, 0
    local zh, ph = horizonFor(id, "zombies"), horizonFor(id, "people")   -- [C32]
    for _, belief in pairs(b.zombies) do
        if (belief.source ~= "heard" or belief.phantom == true)
            and tick - belief.at <= zh then zn = zn + 1 end
    end
    for _, belief in pairs(b.people) do
        if tick - belief.at <= ph then pn = pn + 1 end
    end
    for _, belief in pairs(b.sounds or {}) do
        if tick - belief.at <= zh then sn = sn + 1 end
    end
    return "beliefs: zombies=" .. zn .. " people=" .. pn
        .. " sounds=" .. sn
        .. " scans=" .. b.scanCount
        .. " looked=" .. tostring(P.hasLookedRecently(id, tick))
end

-- [B41] The listener's skepticism, in ONE place.
--
-- `P.tell` has always applied it and said why - "the LISTENER's
-- skepticism is not waived by anyone choosing to speak" - and
-- `P.reportReturn` never had to, because a briefed goer reporting back
-- to the house that briefed them is not a stranger asking to be
-- believed. A PLAYER choosing to speak is neither of those, and the
-- moment a second caller needed the rule, the rule had to become
-- something both could read rather than a line living inside one of
-- them. Two spellings of one judgement is [B40]'s defect, and this is
-- where it would have started.
function P.willBelieve(toId, fromId)
    if SAO.Standing and SAO.Standing.trust(toId, fromId) < -0.2 then
        return false
    end
    return true
end

-- [B41] Is there anything this person could pass on at all?
--
-- The menu that offers it iterated `zombies` and `places` in the
-- harness, which was a second spelling of a rule that lives here, and
-- it had the rule wrong in both directions: it never counted
-- `factions`, which `tell` carries, and it counted every zombie belief
-- when `tell` carries only the ones that are still ACTIONABLE.
--
-- That second half is the whole complaint. `tell` shares a sighting
-- only while `tick - at <= ZOMBIE_HORIZON` - about ten seconds at
-- 60fps frames on the default day - and
-- forgets it entirely at twice that. A gate that ignores the horizon
-- opens on a memory the transfer will refuse, so the option appears,
-- you speak, and nothing crosses. Opening on exactly what can cross is
-- the rule; this reads `tell`'s own test rather than approximating it.
function P.hasAnythingToPass(id, tick)
    local b = P.beliefs[id]
    if not b then return false end
    for _ in pairs(b.factions or {}) do return true end
    for _ in pairs(b.places or {}) do return true end
    local horizon = horizonFor(id, "zombies")   -- [C32]
    for _, zb in pairs(b.zombies or {}) do
        if zb.source ~= "told"
            and (zb.source ~= "heard" or zb.phantom == true)
            and tick and (tick - zb.at) <= horizon then
            return true
        end
    end
    -- The death news. `tell` carries a person only when they are known
    -- dead, so this opens on the same condition: knowing somebody died
    -- and nothing else is a reason to speak, and the offer used to stay
    -- shut on it entirely.
    for _, pb in pairs(b.people or {}) do
        if pb.dead then return true end
    end
    for _, fact in ipairs(P.transferFacts(id)) do
        if fact.state == "remembered" then return true end
    end
    if #P.knownAidRequests(id) > 0 then return true end
    return false
end

-- Told-by exchange: survivor A shares actionable zombie beliefs with B.
-- Recorded as "told" with the teller named; a told belief never overrides an
-- observed one, and B's trust in A (Standing) gates acceptance.
-- [B27] `chosen` is the ONE distinction between how the player
-- communicates with them and how they communicate with each other.
-- Everything below this line - what crosses, at what provenance, who
-- is recorded as the teller, what the listener does with it - is
-- identical either way. Only the decision to open your mouth differs,
-- because for a survivor that decision is a trust calculation and for
-- a player it was a click.
function P.tell(fromId, toId, tick, chosen, channel)
    local from = P.beliefs[fromId]
    if not from then return 0 end
    -- The LISTENER's skepticism is not waived by anyone choosing to
    -- speak. A survivor who distrusts you does not believe you.
    if not P.willBelieve(toId, fromId) then return 0 end
    -- Warnings flow along trust or membership; strangers keep their own counsel.
    if not chosen and SAO.Standing
        and not SAO.Standing.sameGroup(fromId, toId)
        and SAO.Standing.trust(fromId, toId) < 0.3 then
        return 0
    end
    local to = store(toId)
    local shared = tellTransfers(fromId, toId, channel)
        + tellAidRequests(fromId, toId, channel)
    -- [C5] What actually landed, so the listener can SAY it. "They
    -- note 3 things" is not speech; a person acknowledges the thing
    -- itself. Every adoption below counts and leaves a note; the
    -- spoken acknowledgment is built at the end, most grave first.
    local deadName, factionNote, placeShared = nil, nil, false
    local zSharedN, zX, zY = 0, nil, nil
    -- The introduction: a member shares their OWN house's public facts
    -- firsthand ("we're the Rosewood Circle; we hold the place on the
    -- hill") - the only road a faction's NAME enters the belief web by.
    if SAO.Standing.sameGroup then
        local tellerGroup = SAO.Standing.groupOf(fromId)
        if tellerGroup and not SAO.Standing.sameGroup(fromId, toId) then
            local tc = SAO.Standing.groupClaimOf
                and SAO.Standing.groupClaimOf(tellerGroup) or nil
            local tname = SAO.Standing.factionName
                and SAO.Standing.factionName(tellerGroup) or nil
            if tc then
                local existing = to.factions[tellerGroup]
                if not existing or existing.source == "told" then
                    to.factions[tellerGroup] = {
                        baseX = math.floor((tc.minX + tc.maxX) / 2),
                        baseY = math.floor((tc.minY + tc.maxY) / 2),
                        minX = tc.minX, minY = tc.minY,
                        maxX = tc.maxX, maxY = tc.maxY,
                        at = tick, source = "told", teller = fromId,
                        name = tname,
                        stance = existing and existing.stance or "neutral",
                    }
                    shared = shared + 1
                    factionNote = factionNote
                        or { name = tname,
                             x = math.floor((tc.minX + tc.maxX) / 2),
                             y = math.floor((tc.minY + tc.maxY) / 2) }
                elseif not existing.name and tname then
                    existing.name = tname
                    shared = shared + 1
                    factionNote = factionNote or { name = tname,
                        x = existing.baseX, y = existing.baseY }
                end
            end
        end
    end

    -- Faction knowledge travels: where a base is, and what its people
    -- call themselves. Told never overrides observed.
    for groupName, fb in pairs(from.factions or {}) do
        local existing = to.factions[groupName]
        if not existing or existing.source == "told" then
            to.factions[groupName] = {
                baseX = fb.baseX, baseY = fb.baseY,
                minX = fb.minX, minY = fb.minY, maxX = fb.maxX, maxY = fb.maxY,
                at = fb.at, source = "told", teller = fromId,
                name = fb.name,
                stance = existing and existing.stance or "neutral",
            }
            shared = shared + 1
            factionNote = factionNote or { name = fb.name,
                x = fb.baseX, y = fb.baseY }
        elseif existing and not existing.name and fb.name then
            existing.name = fb.name
            shared = shared + 1
            factionNote = factionNote or { name = fb.name,
                x = existing.baseX, y = existing.baseY }
        end
    end
    -- Place knowledge travels ("that's the Reyes place - leave it be").
    for ownerKey, pc in pairs(from.places or {}) do
        local existing = to.places[ownerKey]
        if not existing or existing.source == "told" then
            to.places[ownerKey] = {
                minX = pc.minX, minY = pc.minY,
                maxX = pc.maxX, maxY = pc.maxY,
                at = pc.at, source = "told", teller = fromId,
            }
            shared = shared + 1
            placeShared = true
        end
    end
    -- News of the dead travels ([A19]): a teller who BELIEVES someone
    -- dead (they watched, or stood over the body) passes it on. The
    -- receiver's belief is told-weight; hearing of your bonded's death
    -- grieves through the handler - belief to belief, never a peek at
    -- the global record (DR-007).
    -- Fear presumes ([A28]): before passing word, a fearful and
    -- talkative teller reads their own stale beliefs the worst way -
    -- someone last SEEN hurt, unseen for a week of world time, is
    -- spoken of as dead. Presumption, not fabrication: the flag rides
    -- the belief so the reunion can weigh the teller's sin honestly.
    -- World-hours gate only (atHours) - beliefs lacking the stamp are
    -- never presumed (two tick clocks exist; hours is the shared one).
    do
        local okT, tt = pcall(function()
            return SAO.Disposition.traits(fromId)
        end)
        if okT and tt and tt.nerve < 0.4 and tt.talkativeness > 0.55 then
            local okH, nowH = pcall(function()
                return SAO.History.countyHours()
            end)
            if okH then
                -- The window is FELT, not flat ([A28]): the
                -- fearful bury sooner. nerve 0.15 presumes near five
                -- days; nerve up to the gate (0.4) holds past a week.
                local window = 96 + tt.nerve * 240
                for _, pb0 in pairs(from.people or {}) do
                    -- Everyone knows what a bite means ([B3]): the
                    -- bitten-absent are buried in half the time.
                    local w0 = window
                    if pb0.condition == "bitten" then w0 = window / 2 end
                    if not pb0.dead and pb0.source == "observed"
                        and pb0.condition and pb0.condition ~= "ok"
                        and pb0.atHours
                        and nowH - pb0.atHours > w0 then
                        pb0.dead = true
                        pb0.presumed = true
                    end
                end
            end
        end
    end
    for name, pb in pairs(from.people or {}) do
        if pb.dead then
            local existing = to.people[name]
            if existing then
                if not existing.dead then
                    existing.dead = true
                    shared = shared + 1
                    deadName = deadName or name
                    if P.deathNewsHandler then
                        pcall(P.deathNewsHandler, toId, name, tick)
                    end
                end
                -- "They TURNED" is exactly what people say ([B3]).
                if pb.turned and not existing.turned then
                    existing.turned = true
                end
            else
                to.people[name] = {
                    x = pb.x, y = pb.y, dist = pb.dist or 999,
                    at = tick, source = "told", teller = fromId,
                    dead = true, presumed = pb.presumed or nil,
                    turned = pb.turned or nil,
                }
                shared = shared + 1
                deadName = deadName or name
                if P.deathNewsHandler then
                    pcall(P.deathNewsHandler, toId, name, tick)
                end
            end
        end
    end
    local tellerHorizon = horizonFor(fromId, "zombies")   -- [C32] the teller's own
    local function canTellZombie(belief)
        return tick - belief.at <= tellerHorizon and belief.source ~= "told"
            and (belief.source ~= "heard" or belief.phantom == true)
    end
    for key, belief in pairs(zombieReports(from.zombies, canTellZombie)) do
        local existing = to.zombies[key]
        if not existing or existing.source == "told" then
            -- dist here is the TELLER's; every consumer recomputes
            -- from their own position (F-014), so it is only a seed.
            to.zombies[key] = {
                x = belief.x, y = belief.y, z = belief.z, dist = belief.dist,
                at = belief.at, source = "told", teller = fromId,
                form = belief.form,
                formPerformance = belief.formPerformance,
                attributeMutations = belief.attributeMutations,
            }
            shared = shared + 1
            zSharedN = zSharedN + 1
            if not zX then zX, zY = belief.x, belief.y end
            if belief.form and belief.form ~= "none" then
                pcall(function()
                    local day = math.floor(
                        (SAO.History.countyHours() or 0) / 24.0)
                    SAO.Adaptation.observe(
                        toId,
                        belief.form,
                        belief.formPerformance,
                        "told",
                        day)
                end)
            end
        end
    end
    -- [C5] The acknowledgment, gravest first, in the listener's own
    -- position words. This is what the LISTENER says back - the thing
    -- itself, never a count of things.
    local spoken = nil
    do
        local lx, ly = nil, nil
        pcall(function()
            local lb = SAO.Body and SAO.Body.get and SAO.Body.get(toId)
            if lb then lx, ly = lb:getX(), lb:getY() end
        end)
        if deadName then
            spoken = "So " .. deadName .. " is gone. I'll carry that."
        elseif zSharedN > 0 and zX then
            spoken = "The dead, " .. P.whereWord(zX, zY, lx or zX, ly or zY)
                .. ". I'll keep clear."
        elseif factionNote then
            spoken = (factionNote.name
                and ("The " .. factionNote.name .. ", ")
                or "Somebody holding ground, ")
                .. P.whereWord(factionNote.x, factionNote.y,
                    lx or factionNote.x, ly or factionNote.y)
                .. ". Good to know."
        elseif placeShared then
            spoken = "Whose ground is whose - I'll leave it be."
        end
    end
    P.appraiseKnownTransfers(toId)
    return shared, spoken
end

-- The word before the walk ([A28]): nobody leaves without telling
-- whoever is standing close enough to hear. The announcement is a
-- CLAIM in the hearers' heads - who went, what for, where roughly,
-- and when they said it. Only those told carry it; leaving unheard
-- is possible and worse.
-- The report ([B19]): the map that went out comes back. The briefing
-- moves the house's knowledge of a named ground TO the goer; nothing
-- ever moved what the goer LEARNED back, because P.tell carries
-- factions and places but never zombies - so the one thing a scout
-- is FOR could not travel. A person could stand in front of forty of
-- them, walk home, and the house would send the next one out blind.
--
-- The briefing's own idiom, reversed and bounded identically:
-- firsthand only (or the briefing would echo back and launder
-- told-knowledge into second-hand), about the ground they were sent
-- to, told-provenance with the teller stamped, and told never
-- overrides observed.
--
-- [B41] The player reports through this too, which is what made the
-- skepticism gate below necessary. A briefed goer coming home did not
-- need it - the house had sent them - so the rule lived in `tell`
-- alone. Once a second kind of speaker uses this road, a listener who
-- distrusts the speaker has to be able to refuse here as well, or
-- speaking would be believed simply because of which function carried
-- it. Applied to every caller rather than only the new one: the rule
-- is about the listener, not about the errand.
function P.reportReturn(fromId, toId, tick, aroundX, aroundY, channel)
    if not (aroundX and aroundY) then return 0 end
    local from = P.beliefs[fromId]
    local to = P.beliefs[toId]
    if not (from and to) then return 0 end
    if not P.willBelieve(toId, fromId) then return 0 end
    local moved = tellTransfers(fromId, toId, channel, aroundX, aroundY)
        + tellAidRequests(fromId, toId, channel, aroundX, aroundY)
    local function canReportZombie(zb)
        local dx, dy = zb.x - aroundX, zb.y - aroundY
        return zb.source ~= "told" and (zb.source ~= "heard" or zb.phantom == true)
            and dx * dx + dy * dy <= P.GROUND_REACH * P.GROUND_REACH
    end
    for key, zb in pairs(zombieReports(from.zombies, canReportZombie)) do
        local existing = to.zombies[key]
        if not existing or existing.source == "told" then
            to.zombies[key] = { x = zb.x, y = zb.y, z = zb.z,
                dist = zb.dist, at = zb.at,
                source = "told", teller = fromId,
                form = zb.form,
                formPerformance = zb.formPerformance,
                attributeMutations = zb.attributeMutations }
            moved = moved + 1
            if zb.form and zb.form ~= "none" then
                pcall(function()
                    local day = math.floor(
                        (SAO.History.countyHours() or 0) / 24.0)
                    SAO.Adaptation.observe(
                        toId,
                        zb.form,
                        zb.formPerformance,
                        "told",
                        day)
                end)
            end
        end
    end
    for gname, fb in pairs(from.factions or {}) do
        local fdx = (fb.baseX or 0) - aroundX
        local fdy = (fb.baseY or 0) - aroundY
        if fdx * fdx + fdy * fdy <= P.GROUND_REACH * P.GROUND_REACH and not to.factions[gname] then
            to.factions[gname] = { baseX = fb.baseX, baseY = fb.baseY,
                minX = fb.minX, minY = fb.minY,
                maxX = fb.maxX, maxY = fb.maxY, at = fb.at,
                source = "told", teller = fromId, name = fb.name,
                stance = fb.stance }
            moved = moved + 1
        end
    end
    P.appraiseKnownTransfers(toId)
    return moved
end

-- The cry ([B20]): a badly hurt person calls out, and the people who
-- know that voice learn it was a PERSON rather than a noise.
--
-- The shout itself is the engine's own (`Callout()`, what a player
-- does on Q) and is made by the caller - so the sound is real, the
-- radius is real, and it draws the dead exactly as a player's shout
-- does. This function is the other half: the meaning, carried to
-- whoever can make it out.
--
-- Without it a cry would be actively harmful. An anonymous world
-- sound lands on the `S:` path, which writes a ZOMBIE belief at the
-- sound's tile - so calling for help would send your own house
-- running from you.
function P.cryForHelp(fromId, tick)
    local fromRec = SAO.Identity and SAO.Identity.get
        and SAO.Identity.get(fromId) or nil
    -- [C71] The key this store holds them under, not the name a
    -- player would be shown.
    local fromName = fromRec and SAO.Identity.beliefKey(fromRec) or nil
    if not fromName then return 0 end
    local fromBody = SAO.Body and SAO.Body.get and SAO.Body.get(fromId)
    if not fromBody then return 0 end
    local fx, fy = fromBody:getX(), fromBody:getY()
    local g = SAO.Standing.groupOf and SAO.Standing.groupOf(fromId) or nil
    -- The scanner's own mask, not a second copy of it.
    local mask = 1.0
    pcall(function()
        mask = SAOJavaBridge:weatherHearing()
    end)
    mask = tonumber(mask) or 1.0
    -- A voice carries further than sight and not forever. The 20 is a
    -- judgment on a real scale; the MASKING is read.
    local reach = 20.0 * mask
    local tileKey = math.floor(fx) .. "," .. math.floor(fy)
    -- [B20] WHO heard, not just how many. A cry that goes unanswered
    -- has to know whose silence it was.
    local heardBy = {}
    for otherId, ob in pairs(P.beliefs) do
        if otherId ~= fromId and ob then
            local obody = SAO.Body.get(otherId)
            if obody then
                local dx, dy = obody:getX() - fx, obody:getY() - fy
                local d2 = dx * dx + dy * dy
                if d2 <= reach * reach then
                    -- You know that voice - and recognising it is
                    -- FAMILIARITY, not affection. This first read
                    -- `trust > 0.3`, which had it backwards: someone
                    -- who hates you knows your voice better than a
                    -- stranger who mildly approves of you, and would
                    -- have heard only an anonymous noise.
                    --
                    -- What they DO with it is a separate question the
                    -- tree already answers: the aid loop excludes
                    -- hostiles, and a hostile who now knows a hated
                    -- neighbour is hurt and nearby is handled by the
                    -- hostility machinery that already exists. Nobody
                    -- had to write "raiders hunt the wounded" - the
                    -- cry simply tells your enemies where you are and
                    -- that you are bleeding, which is the second
                    -- honest cost of screaming.
                    local knows = (g and SAO.Standing.groupOf(otherId) == g)
                        or SAO.Standing.knowsOf(otherId, fromId)
                    if knows then
                        local existing = ob.people[fromName]
                        if existing and existing.source == "observed" then
                            -- The ladder holds: heard never overwrites
                            -- observed. But hearing someone scream IS
                            -- current news about them, so the urgency
                            -- refreshes even though the provenance
                            -- does not fall.
                            existing.at = tick
                            existing.condition = "bad"
                        else
                            ob.people[fromName] = {
                                x = fx, y = fy, dist = math.sqrt(d2),
                                at = tick, source = "heard",
                                condition = "bad",
                            }
                        end
                        -- The voice identifies this sound. An actual
                        -- threat believed on the same tile remains
                        -- independent evidence.
                        ob.criedTiles = ob.criedTiles or {}
                        ob.criedTiles[tileKey] = tick
                        if ob.sounds then ob.sounds[tileKey] = nil end
                        heardBy[#heardBy + 1] = otherId
                    end
                end
            end
        end
    end
    -- [B20] The reach goes back with the hearers: the PLAYER is told
    -- by the Controller (where [B18] put that idiom), and it must use
    -- the same weather-masked distance a survivor standing there
    -- would have. A third distance constant is how the mask drifts.
    return heardBy, reach
end

function P.announceDeparture(fromId, kind, destX, destY)
    local fromRec = SAO.Identity and SAO.Identity.get
        and SAO.Identity.get(fromId) or nil
    -- [C71] The belief key, as above.
    local fromName = fromRec and SAO.Identity.beliefKey(fromRec) or nil
    if not fromName then return end
    local fromBody = SAO.Body and SAO.Body.get and SAO.Body.get(fromId)
    if not fromBody then return end
    local fx, fy = fromBody:getX(), fromBody:getY()
    local g = SAO.Standing.groupOf and SAO.Standing.groupOf(fromId) or nil
    if not g then return end
    local okH, nowH = pcall(function()
        return SAO.History.countyHours()
    end)
    if not okH then return end
    -- Announced terms ([B1]): the goer knows how long their own
    -- errands take - the house's learned expectation is THEIR
    -- estimate too, so the word carries a back-by time when history
    -- exists. Far scout runs sometimes carry "don't wait up"
    -- (noClock): no worry clock at all, and the hearer knows it.
    local backBy = nil
    local noClock = nil
    do
        local expected = SAO.Standing.ventureExpectation
            and SAO.Standing.ventureExpectation(g, kind) or nil
        if expected then
            backBy = nowH + expected * 1.5
        end
        if kind == "scout" and destX then
            local ddx, ddy = destX - fx, destY - fy
            if ddx * ddx + ddy * ddy > 40000
                and SAO.Rand.int(4) == 0 then
                noClock = true
                backBy = nil
            end
        end
    end
    local goerB = P.beliefs[fromId]
    -- [B19] The hearers are the point, not a by-product: this loop
    -- already finds every housemate in earshot and the caller had no
    -- way to know who they were, so nobody could ever decide to come
    -- along. Collected and returned; the JOINING is the Controller's
    -- to decide, because who does what is not Perception's pillar.
    local hearers = {}
    local bestBriefer, bestKnown = nil, 0
    for otherId, og in pairs(P.beliefs) do
        if otherId ~= fromId
            and SAO.Standing.groupOf(otherId) == g then
            local ob = SAO.Body.get(otherId)
            if ob then
                local dx, dy = ob:getX() - fx, ob:getY() - fy
                if dx * dx + dy * dy <= P.EARSHOT * P.EARSHOT then
                    hearers[#hearers + 1] = otherId
                    local b2 = P.beliefs[otherId]
                    local pb2 = b2.people[fromName]
                    if pb2 then
                        pb2.out = { kind = kind, x = destX, y = destY,
                            saidAtHours = nowH, backByHours = backBy,
                            noClock = noClock }
                    end
                    -- The briefing ([B1]): who among the hearers
                    -- knows the named ground best - counted as their
                    -- firsthand beliefs within 40 tiles of it.
                    if destX and goerB then
                        local known = 0
                        for _, zb in pairs(b2.zombies or {}) do
                            if zb.source ~= "told"
                                and (zb.source ~= "heard" or zb.phantom == true) then
                                local zdx, zdy = zb.x - destX, zb.y - destY
                                if zdx * zdx + zdy * zdy <= P.GROUND_REACH * P.GROUND_REACH then
                                    known = known + 1
                                end
                            end
                        end
                        for _, fb in pairs(b2.factions or {}) do
                            local fdx = (fb.baseX or 0) - destX
                            local fdy = (fb.baseY or 0) - destY
                            if fdx * fdx + fdy * fdy <= P.GROUND_REACH * P.GROUND_REACH then
                                known = known + 2
                            end
                        end
                        if known > bestKnown then
                            bestBriefer, bestKnown = otherId, known
                        end
                    end
                end
            end
        end
    end
    -- The knower dictates what is where ([B1]): their near-ground
    -- beliefs transfer told-provenance, the same idiom as every tell.
    -- Nobody knowing anything is also true - no briefing happens.
    if bestBriefer and goerB then
        local bB = P.beliefs[bestBriefer]
        local moved = 0
        local function canBriefZombie(zb)
            local zdx, zdy = zb.x - destX, zb.y - destY
            return zb.source ~= "told" and (zb.source ~= "heard" or zb.phantom == true)
                and zdx * zdx + zdy * zdy <= P.GROUND_REACH * P.GROUND_REACH
        end
        for key, zb in pairs(zombieReports(bB.zombies, canBriefZombie)) do
            local ex = goerB.zombies[key]
            if not ex or ex.source == "told" then
                goerB.zombies[key] = { x = zb.x, y = zb.y, z = zb.z,
                    dist = zb.dist, at = zb.at,
                    source = "told", teller = bestBriefer }
                moved = moved + 1
            end
        end
        for gname, fb in pairs(bB.factions or {}) do
            local fdx = (fb.baseX or 0) - destX
            local fdy = (fb.baseY or 0) - destY
            if fdx * fdx + fdy * fdy <= P.GROUND_REACH * P.GROUND_REACH
                and not goerB.factions[gname] then
                goerB.factions[gname] = { baseX = fb.baseX,
                    baseY = fb.baseY, minX = fb.minX, minY = fb.minY,
                    maxX = fb.maxX, maxY = fb.maxY, at = fb.at,
                    source = "told", name = fb.name,
                    stance = fb.stance }
                moved = moved + 1
            end
        end
        if moved > 0 then
            pcall(function()
                SAO.Voice.onEvent(bestBriefer, "briefing")
            end)
        end
    end
    return hearers
end


-- A believed faction base within `near` tiles of (x,y), or nil.
function P.believedFactionNear(id, x, y, near)
    local b = P.beliefs[id]
    if not b or not b.factions then return nil end
    for groupName, fb in pairs(b.factions) do
        if x >= fb.minX - (near or 0) and x <= fb.maxX + (near or 0)
            and y >= fb.minY - (near or 0) and y <= fb.maxY + (near or 0) then
            return groupName, fb
        end
    end
    return nil
end

function P.setFactionStance(id, groupName, stance)
    local b = P.beliefs[id]
    if b and b.factions and b.factions[groupName] then
        b.factions[groupName].stance = stance
    end
end

function P.factionStanceToward(id, personName)
    local b = P.beliefs[id]
    if not b then return nil end
    local pb = b.people[personName]
    local g = pb and pb.seenInFaction or nil
    if g and b.factions[g] then
        return b.factions[g].stance, g
    end
    return nil
end

-- The objection teaches ([A15]): being told off at the door is
-- firsthand knowledge of whose place this is.
-- [B39] How a place came to be known, said by the CALLER.
--
-- This wrote `source = "observed"` unconditionally, so no caller could
-- state how the knowledge arrived - and two of them had already
-- written the truth in a comment above the call. `SAO_Controller:5112`
-- says "Told, not seen: they know it because somebody standing there
-- said so" and then recorded that it was seen. The manner of
-- acquisition was stated in prose and lost in the data, which is the
-- root of the defect class [B35], [B35] and [B37] each fixed one
-- instance of.
--
-- Omission records "unknown" rather than claiming observation,
-- because a silent default claiming the strongest provenance is
-- exactly how this happened. Border 28 fails on "unknown", so a new
-- caller that forgets is caught rather than believed.
function P.learnPlace(id, ownerKey, bounds, source)
    local b = store(id)
    b.places[ownerKey] = {
        minX = bounds.minX, minY = bounds.minY,
        maxX = bounds.maxX, maxY = bounds.maxY,
        at = b.lastScanAt, source = tostring(source or "unknown"),
    }
    P.appraiseKnownTransfers(id)
end

-- [B42] Being near somebody's ground teaches you it is theirs, and a
-- claim that ended un-teaches the same way ([A15], [A15], [B35]).
--
-- This rule lived only inside `dormantLife`, which gates its whole
-- loop on `not SAO.Body.get(id)`. So an UNLOADED survivor drifting
-- past a fence learned whose house it was, and a survivor with a body
-- could stand in the kitchen indefinitely and never learn it. [B35]
-- wired the player's claim into this - the `isPlayerKey` branch below
-- exists for exactly that - and put it in the half that can never see
-- a survivor who is actually standing there, which is why the ledger
-- reports "Nobody has come past it yet" with somebody in the room.
--
-- The county's property law does not depend on whether a cell happens
-- to be loaded. Same rule, both halves, one spelling: [B39] and
-- [B39] are the same finding about `Desperation` and `ErrandRadius`.
function P.learnGroundNear(id, x, y)
    if not (x and y and SAO.Standing) then return end
    local sight = P.PLACE_SIGHT or 8
    local function near(c)
        return x >= c.minX - sight and x <= c.maxX + sight
            and y >= c.minY - sight and y <= c.maxY + sight
    end

    if SAO.Standing.allGroupClaims then
        for gname, c in pairs(SAO.Standing.allGroupClaims()) do
            if near(c) then
                local b = P.beliefs[id]
                if not (b and b.factions and b.factions[gname]) then
                    P.learnPlace(id, gname, c, "observed")
                end
            end
        end
    end

    -- [B35] Walking past also UNTEACHES. A claim that ended leaves
    -- the ground free, and you find that out the same way you found
    -- out it was held - by being there.
    local bU = P.beliefs[id]
    if bU and bU.places then
        for ownerKey, pc in pairs(bU.places) do
            if near(pc) and not SAO.Standing.claimOf(ownerKey) then
                bU.places[ownerKey] = nil
            end
        end
    end

    if SAO.Standing.allPersonalClaims then
        for ownerId, c in pairs(SAO.Standing.allPersonalClaims()) do
            if ownerId ~= id and near(c) then
                -- [B35] The player holds ground under a player: key
                -- and has no Identity record, so a guard written to
                -- skip the DEAD skips the player unless it says so.
                local orec = SAO.Identity and SAO.Identity.get(ownerId)
                if SAO.Standing.isPlayerKey(ownerId)
                    or (orec and not orec.dead) then
                    P.learnPlace(id, ownerId, c, "observed")
                end
            end
        end
    end
end

-- Does this survivor BELIEVE (x,y) is somebody's place? Returns the
-- owner key (personal) or group name (faction base), else nil.
function P.believesClaimed(id, x, y)
    local b = P.beliefs[id]
    if not b then return nil end
    for ownerKey, pc in pairs(b.places or {}) do
        if x >= pc.minX and x <= pc.maxX
            and y >= pc.minY and y <= pc.maxY then
            -- F-034: the estate rule reaches beliefs - the dead hold
            -- nothing (same authority claimedByOther already applies;
            -- record death is corpse-visible truth, not a rumor).
            local orec = SAO.Identity and SAO.Identity.get
                and SAO.Identity.get(ownerKey) or nil
            if not (orec and orec.dead) then
                return ownerKey
            end
        end
    end
    for groupName, fb in pairs(b.factions or {}) do
        if x >= fb.minX and x <= fb.maxX
            and y >= fb.minY and y <= fb.maxY then
            return groupName
        end
    end
    return nil
end

-- [B37] A place known as a PLACE, not as somebody's ground.
--
-- `b.places` above answers "whose is this?" and is keyed by owner. It
-- cannot represent the thing the operator named as the only thing a
-- survivor can know off the road - "that this is a house that has
-- things in it". Until now the belief store had no way to say it, so
-- the dormant day had nowhere to go and walked to a random
-- coordinate instead.
--
-- Keyed by building id, because a building is the same building
-- whoever is standing in it. `sources` is the exact native stock this
-- person observed on arrival; room vocabulary remains only a possible
-- reason to explore and never enters the belief as availability.
local rebuildKnownSources
local function canonicalBuildingBelief(b, place)
    local known = b.known
    if not known then return nil end
    local occupied = tostring(place.id)
    local was, alias = known[place.id], known[occupied]
    if place.id ~= occupied and alias then
        if was and was ~= alias then
            -- Earlier source inspection and arrival could leave two keys for
            -- this one building. Keep independent private facts, the existing
            -- native row on revision conflicts, and the larger visit count.
            was.sourceFacts = was.sourceFacts or {}
            for sourceId, fact in pairs(alias.sourceFacts or {}) do
                if was.sourceFacts[sourceId] == nil then
                    was.sourceFacts[sourceId] = fact
                end
            end
            was.visits = math.max(was.visits or 0, alias.visits or 0)
            if (alias.at or 0) > (was.at or 0) then
                was.at, was.source = alias.at, alias.source
            end
            rebuildKnownSources(was)
        else
            was = alias
        end
        known[place.id], known[occupied] = was, nil
        P.beliefVersion = P.beliefVersion + 1
    end
    return was
end

local function rememberBuildingVisit(id, place, tick, source, withSources)
    if not place or not place.id then return end
    local b = store(id)
    b.known = b.known or {}
    local was = canonicalBuildingBelief(b, place)
    local sources = was and was.sources or {}
    local sourceRevision = was and was.sourceRevision or ""
    local sourceAccess = was and was.sourceAccess or {}
    local sourceFacts = was and was.sourceFacts or {}
    if withSources then
        sources, sourceRevision, sourceAccess, sourceFacts = {}, "", {}, {}
        pcall(function()
            sources, sourceRevision, sourceAccess, sourceFacts =
                SAO.WorldSources.beliefSnapshot(place)
        end)
    end
    b.known[place.id] = {
        cx = place.cx, cy = place.cy,
        minX = place.minX, minY = place.minY,
        maxX = place.maxX, maxY = place.maxY,
        sources = sources,
        sourceAccess = sourceAccess,
        sourceRevision = sourceRevision,
        sourceFacts = sourceFacts,
        at = tick or b.lastScanAt,
        -- [B39] Said by the caller; "unknown" when nobody said.
        source = tostring(source or "unknown"),
        -- How many times they have been. Somewhere returned to is
        -- somewhere that gave them something.
        visits = (was and was.visits or 0) + 1,
    }
    if source == "observed" or source == "lived" then
        -- These callers admit an actual arrival, including the dormant and
        -- genesis paths. Persist it with the mind so loading a body here
        -- continues that visit instead of counting the same arrival twice.
        b.occupiedBuilding = tostring(place.id)
    end
    -- [C108] An arrival is a write; derived readers recompute.
    P.beliefVersion = P.beliefVersion + 1
end

function P.learnBuilding(id, place, tick, source)
    rememberBuildingVisit(id, place, tick, source, true)
end

observeOccupiedBuilding = function(id, body, tick)
    local square = body:getCurrentSquare()
    if not square then return end -- unavailable is not an observed exit
    local b = store(id)
    local def = square:getBuildingDef()
    if not def then
        -- A room can be temporarily unresolved on an interior square. Only
        -- the native exterior property is positive evidence of leaving.
        if square:isOutside() and b.occupiedBuilding ~= false then
            b.occupiedBuilding = false
            P.beliefVersion = P.beliefVersion + 1
        end
        return
    end
    local place = SAO.Places.at(body:getX(), body:getY())
    if not place or tostring(place.id) ~= tostring(def:getID()) then return end
    local occupied = tostring(place.id)
    local was = canonicalBuildingBelief(b, place)
    if b.occupiedBuilding == occupied then return end
    if b.occupiedBuilding == nil and was and (was.visits or 0) > 0 then
        -- Older saves already counted this known place, but have no entry
        -- receipt. Establish continuity without inventing another arrival.
        b.occupiedBuilding = occupied
        P.beliefVersion = P.beliefVersion + 1
        return
    end
    -- Occupying the building reveals its location, not other containers'
    -- current contents. Existing private source facts and revisions survive.
    rememberBuildingVisit(id, place, tick, "observed", false)
end

rebuildKnownSources = function(belief)
    local sources, access, revisions = {}, {}, {}
    for id, fact in pairs(belief.sourceFacts or {}) do
        if fact.state == "available" then
            for category, quantity in pairs(fact.quantities or {}) do
                if (tonumber(quantity) or 0) > 0 then
                    sources[category] = true
                    if fact.access == "accessible" then access[category] = true end
                end
            end
        end
        local entry = tostring(id) .. "@" .. tostring(fact.revision)
        local at = #revisions + 1
        while at > 1 and revisions[at - 1] > entry do
            revisions[at] = revisions[at - 1]
            at = at - 1
        end
        revisions[at] = entry
    end
    belief.sources = sources
    belief.sourceAccess = access
    belief.sourceRevision = table.concat(revisions, ",")
end

-- Refresh only the source this actor physically handled. Whole-building
-- learning here would reveal unrelated changes made outside their observation.
function P.learnSource(id, place, sourceId, tick, source)
    if not place or place.id == nil or not sourceId then return false end
    local b = store(id)
    b.known = b.known or {}
    local belief = b.known[place.id] or b.known[tostring(place.id)]
    if not belief then return false end
    belief.sourceFacts = belief.sourceFacts or {}
    belief.sourceFacts[tostring(sourceId)] = nil
    local fact = nil
    pcall(function() fact = SAO.WorldSources.beliefFact(sourceId) end)
    local belongs = fact and (fact.buildingId == tostring(place.id)
        or (fact.kind == "vehicle" and place.minX and place.minY
            and place.maxX and place.maxY
            and fact.x >= place.minX and fact.x < place.maxX
            and fact.y >= place.minY and fact.y < place.maxY))
    if belongs then belief.sourceFacts[tostring(sourceId)] = fact end
    rebuildKnownSources(belief)
    belief.at = tick or b.lastScanAt
    belief.source = tostring(source or "observed-source")
    P.beliefVersion = P.beliefVersion + 1
    return true
end

-- A current, reachable container inspection admits precisely one source.
-- The caller has verified the native inspection; other sources in the same
-- engine chunk never become this person's knowledge through this operation.
function P.learnInspectedSource(id, place, sourceId, tick, source)
    if not place or place.id == nil or not sourceId then return false end
    local fact = SAO.WorldSources and SAO.WorldSources.beliefFact(sourceId,
        source == "native-visible-ground" and "visible-ground" or nil)
    if not fact then return false end
    local belongs = tostring(fact.buildingId) == tostring(place.id)
        or tostring(place.sourceId or "") == tostring(sourceId)
        or (fact.kind == "vehicle" and place.minX and place.minY
            and place.maxX and place.maxY and fact.x >= place.minX
            and fact.x < place.maxX and fact.y >= place.minY
            and fact.y < place.maxY)
    if not belongs then return false end
    local b = store(tostring(id))
    b.known = b.known or {}
    local key = b.known[place.id] and place.id or tostring(place.id)
    local belief = b.known[place.id] or b.known[key] or { id = place.id }
    belief.cx, belief.cy, belief.z = place.cx, place.cy, place.z
    belief.minX, belief.minY = place.minX, place.minY
    belief.maxX, belief.maxY = place.maxX, place.maxY
    belief.sourceId = place.sourceId
    belief.sourceFacts = belief.sourceFacts or {}
    local priorFact = belief.sourceFacts[tostring(sourceId)]
    if source == "native-visible-ground" and priorFact and priorFact.knowledgeKind ~= "visible-ground"
        and priorFact.revision == fact.revision and priorFact.fingerprint == fact.fingerprint then fact = priorFact end
    belief.sourceFacts[tostring(sourceId)] = fact
    rebuildKnownSources(belief)
    belief.at = tick or b.lastScanAt
    belief.source = tostring(source or "unknown")
    b.known[key] = belief
    P.beliefVersion = P.beliefVersion + 1
    return true
end

function P.observeLooseItems(id, body, tick)
    local world = SAO.WorldSources
    if not world or not world.observeVisibleGround then return false end
    local current = SAO.History and SAO.History.ticks and SAO.History.ticks()
    if not finiteSoundNumber(current) or tick ~= nil and tick ~= current then return false end
    tick = current
    local rows = world.observeVisibleGround(id, body)
    for _, anchor in ipairs(rows) do
        local b = store(tostring(id))
        local known = b.known or {}
        if not known[anchor.id] then
            local count, oldest, at = 0, nil, nil
            for key, belief in pairs(known) do
                if belief.source == "native-visible-ground" then
                    count = count + 1
                    if not at or (belief.at or 0) < at then oldest, at = key, belief.at or 0 end
                end
            end
            if count >= 64 then known[oldest] = nil end
        end
        P.learnInspectedSource(id, anchor, anchor.sourceId, tick, "native-visible-ground")
    end
    return #rows > 0
end

-- Visibility acquires an exact holder's geometry, never its inventory. The
-- native offer owner must still possess this actor/body/context relationship.
function P.learnVisibleHolder(id, body, context)
    local world = SAO.WorldSources
    local anchor = world and world.currentInspectionAnchor and world.currentInspectionAnchor(id, body, context)
    if not anchor then return false end
    local b = store(tostring(id))
    b.known = b.known or {}
    local prior = b.known[anchor.id]
    if not prior then
        local count, oldestKey, oldestAt = 0, nil, nil
        for key, belief in pairs(b.known) do
            if belief.source == "native-visible-holder" then
                count = count + 1
                if not oldestAt or (belief.at or 0) < oldestAt then oldestKey, oldestAt = key, belief.at or 0 end
            end
        end
        if count >= 64 then b.known[oldestKey] = nil end
    end
    anchor.at = SAO.History and SAO.History.ticks and SAO.History.ticks() or b.lastScanAt
    anchor.source = "native-visible-holder"
    anchor.sources = prior and prior.sources or {}
    anchor.sourceFacts = prior and prior.sourceFacts or {}
    anchor.sourceAccess = prior and prior.sourceAccess or {}
    anchor.sourceRevision = prior and prior.sourceRevision or ""
    b.known[anchor.id] = anchor
    P.beliefVersion = P.beliefVersion + 1
    return true
end

function P.forgetSource(id, placeId, sourceId, tick, source)
    local b = store(id)
    local belief = b.known and (b.known[placeId]
        or b.known[tostring(placeId)]) or nil
    if not belief then return false end
    belief.sourceFacts = belief.sourceFacts or {}
    belief.sourceFacts[tostring(sourceId)] = nil
    rebuildKnownSources(belief)
    belief.at = tick or b.lastScanAt
    belief.source = tostring(source or "source-disproved")
    P.beliefVersion = P.beliefVersion + 1
    return true
end

-- Everything this survivor knows is out there. Empty for someone who
-- has not been anywhere, which is the correct answer for them.
function P.knownPlaces(id, includeSourceAnchors)
    local b = P.beliefs[id]
    local known = (b and b.known) or {}
    if includeSourceAnchors then return known end
    -- Physical source anchors carry remembered goods, not building visits.
    local places = {}
    for key, belief in pairs(known) do
        if not belief.sourceId then places[key] = belief end
    end
    return places
end

-- Native observer-specific visibility owns these anchors. Room identities are
-- geometric; a room's authored map label never becomes the person's knowledge.
-- A fresh native query projects this person's learned recognition. No query
-- writes a belief, recipe, acquisition time or outcome. Dormant knowledge stays
-- with native snapshot custody until its actual body is reconstructed.
function P.personalFoodKnowledge(id,body)
    if not SAO.Needs or not SAO.Needs.ownsRecoveryBody or not SAO.Needs.ownsRecoveryBody(id,body) then return nil end
    local at=SAO.History and SAO.History.countyHours()
    if not finiteSoundNumber(at) then return nil end
    local ok,view=pcall(function() return SAOJavaBridge:personalFoodKnowledge(body) end)
    if not ok or type(view)~="table" or view.schema~="sao.personal-food-knowledge/1"
        or view.actorId~=id or view.status~="available" or type(view.foods)~="table"
        or #view.foods>64 or not finiteSoundNumber(view.omitted) or view.omitted<0 then return nil end
    local out={actorId=id,atHours=at,foods={},omitted=view.omitted,
        acquisitionTime="unrecorded-native-acquisition",sourceOwner="IsoGameCharacter.isKnownPoison"}
    local seen={}
    local bases={["unrecognized"]=true,["visible-warning"]=true,["known-recipe:Herbalist"]=true,
        ["native-perk:Cooking"]=true,["own-poison-addition"]=true}
    for _,row in ipairs(view.foods) do
        if type(row)~="table" or not finiteSoundNumber(row.itemId) or row.itemId~=math.floor(row.itemId)
            or seen[row.itemId] or type(row.itemType)~="string" or #row.itemType==0 or #row.itemType>160
            or not finiteSoundNumber(row.relief) or row.relief<=0 or row.relief>16
            or type(row.recognizedPoison)~="boolean" or not bases[row.basis]
            or row.recognizedPoison~=(row.basis~="unrecognized") then return nil end
        seen[row.itemId]=true
        out.foods[#out.foods+1]={itemId=row.itemId,itemType=row.itemType,relief=row.relief,
            recognizedPoison=row.recognizedPoison,basis=row.basis}
    end
    return out
end
local function conceptCopy(row)
    local out={} for key,value in pairs(row) do if type(value)~="table" then out[key]=value end end return out
end
local SOURCE_GROUND_DIRECTIONS={
    {-1,-1},{0,-1},{1,-1},{-1,0},{1,0},{-1,1},{0,1},{1,1}
}
local function sourceConceptView(id,body)
    local source=SAO.WeekOneContinuity
    if not source or type(source.sourceBodyFor)~="function"
        or not SAOJavaBridge or not SAOJavaBridge.weekOneObservedFeature then return nil end
    local exact,owned,brain=pcall(source.sourceBodyFor,id)
    if not exact or owned~=body or type(brain)~="table"
        or not finiteSoundNumber(brain.id) or not finiteSoundNumber(brain.born) then return nil end
    local located,cell,x,y,z=pcall(function()
        return body:getCell(),body:getX(),body:getY(),body:getZ() end)
    if not located or not cell or not finiteSoundNumber(x) or not finiteSoundNumber(y)
        or not finiteSoundNumber(z) or z~=math.floor(z) then return nil end
    local okOutside,outside=pcall(function()
        local square=body:getCurrentSquare()
        return square and square:getRoom()==nil
    end)
    if not okOutside or outside~=true then return nil end
    local approaches={}
    for _,distance in ipairs({3,6}) do
        for _,direction in ipairs(SOURCE_GROUND_DIRECTIONS) do
            local gx=math.floor(x)+direction[1]*distance
            local gy=math.floor(y)+direction[2]*distance
            local okSquare,square=pcall(function()return cell:getGridSquare(gx,gy,z)end)
            local okVisible,visible=pcall(function()
                return square and SAOJavaBridge:weekOneObservedFeature(body,square,"ground")
            end)
            if okSquare and square and okVisible and visible==true then
                local okPosition,sx,sy,sz,room=pcall(function()
                    return square:getX(),square:getY(),square:getZ(),square:getRoom() end)
                if okPosition and finiteSoundNumber(sx) and finiteSoundNumber(sy)
                    and sz==z and sx==gx and sy==gy and room==nil then
                    approaches[#approaches+1]={key="ground:"..gx..":"..gy..":"..z,
                        kind="visible-ground",x=sx,y=sy,z=sz}
                end
            end
        end
    end
    return {schema="sao.concept-observation/1",actorId=id,
        status="available",coverage="source-current-visible-ground",
        observations={},frontiers={},approaches=approaches},brain
end
function P.observeConcepts(id,body,tick)
    if not finiteSoundNumber(tick) then return false,"concept-observer-unavailable" end
    local ordinary=SAO.Needs and SAO.Needs.ownsRecoveryBody
        and SAO.Needs.ownsRecoveryBody(id,body)
    local ok,view,sourceBrain
    if ordinary then
        ok,view=pcall(function() return SAOJavaBridge:conceptObservations(body,8) end)
    else
        ok,view,sourceBrain=pcall(sourceConceptView,id,body)
    end
    if not ok or type(view)~="table" or view.schema~="sao.concept-observation/1" or view.actorId~=id
        or type(view.observations)~="table" or type(view.frontiers)~="table" then
        conceptObservers[id]=nil
        local prior=P.beliefs[id] and P.beliefs[id].concepts
        if prior then prior.readerStatus="native-concept-observation-unavailable" end
        return false,"native-concept-observation-unavailable"
    end
    local b=store(id)
    local concepts=b.concepts or {observations={},order={},frontiers={},frontierOrder={}}
    b.concepts=concepts
    conceptObservers[id]={body=body,sourceBrainId=sourceBrain and sourceBrain.id,
        sourceBorn=sourceBrain and sourceBrain.born}
    concepts.at,concepts.status,concepts.readerStatus=tick,"observed","available"
    -- Source ground has its own exact body/visibility proof. A previous
    -- ordinary scan in this same tick cannot lend it objects or doorways.
    concepts.sourceGroundOnly=view.coverage=="source-current-visible-ground"
    concepts.currentRoomId,concepts.currentBuildingId=nil,nil
    concepts.approaches={}
    local function accept(row,frontier)
        if type(row)~="table" or type(row.key)~="string" or #row.key>160
            or not finiteSoundNumber(row.x) or not finiteSoundNumber(row.y) or not finiteSoundNumber(row.z) then return end
        if (frontier or row.kind=="room") and (row.buildingId==nil or row.roomId==nil) then return end
        if frontier then
            if row.kind~="doorway" or not finiteSoundNumber(row.entryX)
                or not finiteSoundNumber(row.entryY) or row.entryZ~=row.z
                or math.abs(row.entryX-row.x)+math.abs(row.entryY-row.y)>2 then return end
        elseif (row.kind~="room" and row.kind~="object") or type(row.concept)~="string"
            or #row.concept>96 or not row.concept:match("^[%w_:%-%.]+$") then return end
        local copy=conceptCopy(row)
        copy.recoverySourceId=type(row.recoverySourceId)=="string" and #row.recoverySourceId<=256
            and row.recoverySourceId:sub(1,4)=="bed:" and row.recoverySourceId or nil
        copy.actorId,copy.at,copy.source=id,tick,"native-personal-visibility"
        copy.buildingId=row.buildingId~=nil and tostring(row.buildingId) or nil
        copy.roomId=row.roomId~=nil and tostring(row.roomId) or nil
        local rows,order=frontier and concepts.frontiers or concepts.observations,
            frontier and concepts.frontierOrder or concepts.order
        if not rows[row.key] then
            if #order>=96 then rows[table.remove(order,1)]=nil end
            order[#order+1]=row.key
        end
        rows[row.key]=copy
        if not frontier and row.kind=="room" then
            concepts.currentRoomId,concepts.currentBuildingId=copy.roomId,copy.buildingId
        end
    end
    for index,row in ipairs(view.observations) do if index>64 then break end;accept(row,false) end
    for index,row in ipairs(view.frontiers) do if index>32 then break end;accept(row,true) end
    if type(view.approaches)=="table" then
        for index,row in ipairs(view.approaches) do
            if index>16 then break end
            local gx,gy,gz
            if type(row)=="table" and type(row.key)=="string" then
                gx,gy,gz=row.key:match("^ground:(%-?%d+):(%-?%d+):(%-?%d+)$")
            end
            if type(row)=="table" and row.kind=="visible-ground" and type(row.key)=="string"
                and #row.key<=160 and gx and gy and gz
                and finiteSoundNumber(row.x) and finiteSoundNumber(row.y)
                and finiteSoundNumber(row.z) and tonumber(gx)==math.floor(row.x)
                and tonumber(gy)==math.floor(row.y) and tonumber(gz)==row.z then
                concepts.approaches[#concepts.approaches+1]={key=row.key,kind=row.kind,
                    actorId=id,at=tick,source="native-personal-visibility",x=row.x,y=row.y,z=row.z}
            end
        end
    end
    if SAO.ConceptKnowledge and not concepts.sourceGroundOnly then
        for _,roomKey in ipairs(concepts.order) do
            local room=concepts.observations[roomKey]
            if room.kind=="room" and room.at==tick then
                for _,objectKey in ipairs(concepts.order) do
                    local object=concepts.observations[objectKey]
                    if object.kind=="object" and object.at==tick and object.roomId==room.roomId then
                        SAO.ConceptKnowledge.observeRelation(id,roomKey,objectKey)
                    end
                end
            end
        end
    end
    P.beliefVersion=P.beliefVersion+1
    -- Published only after the complete native concept read has succeeded.
    -- A scan timestamp alone can precede a failed or partial native read.
    if concepts.sourceGroundOnly then
        local located,x,y,z=pcall(function()
            return body:getX(),body:getY(),body:getZ()
        end)
        if not located or not finiteSoundNumber(x) or not finiteSoundNumber(y)
            or not finiteSoundNumber(z) then
            conceptObservers[id]=nil
            concepts.readerStatus="native-concept-observation-unavailable"
            return false,"source-position-unavailable"
        end
        conceptObservers[id].tileX=math.floor(x)
        conceptObservers[id].tileY=math.floor(y)
        conceptObservers[id].tileZ=z
    end
    conceptObservers[id].completedAt=tick
    return true
end
function P.conceptObservationReceipt(id,body,tick)
    local bound=conceptObservers[id]
    if not bound or bound.body~=body or bound.completedAt~=tick
        or P.conceptContext(id,tick,body).status~="observed" then return false end
    if bound.sourceBrainId then
        local located,x,y,z=pcall(function()
            return body:getX(),body:getY(),body:getZ()
        end)
        if not located or not finiteSoundNumber(x) or not finiteSoundNumber(y)
            or math.floor(x)~=bound.tileX or math.floor(y)~=bound.tileY
            or z~=bound.tileZ then return false end
    end
    return true
end
function P.conceptObservation(id,key)
    local concepts=P.beliefs[id] and P.beliefs[id].concepts
    local row=concepts and concepts.observations[key]
    return row and row.actorId==id and conceptCopy(row) or nil
end
function P.leisureObjects(id,body)
    local ok,tick=pcall(function()return SAO.History.ticks()end)
    if not ok or not SAO.Needs.ownsRecoveryBody(id,body) then return {} end
    local context=P.conceptContext(id,tick)
    local out={}
    for _,row in ipairs(context.observations or {}) do
        if row.actorId==id and row.kind=="object" and row.source=="native-personal-visibility"
            and type(row.objectIndex)=="number" and row.objectIndex>=0 and row.objectIndex%1==0
            and type(row.runtimeInstance)=="string" then out[#out+1]=conceptCopy(row) end
    end
    return out
end
function P.resolveLeisureObject(id,body,key)
    local ok,tick=pcall(function()return SAO.History.ticks()end)
    if not ok or not SAO.Needs.ownsRecoveryBody(id,body) then return nil end
    local prior=P.conceptObservation(id,key)
    if not prior or prior.actorId~=id or prior.source~="native-personal-visibility"
        or prior.kind~="object" or type(prior.runtimeInstance)~="string" then return nil end
    local refreshed=P.observeConcepts(id,body,tick)
    local current=refreshed and P.conceptObservation(id,key)
    if not current or current.at~=tick or current.runtimeInstance~=prior.runtimeInstance
        or current.objectIndex~=prior.objectIndex or current.spriteName~=prior.spriteName then return nil end
    local good,object=pcall(function()return SAOJavaBridge:resolveObservedObject(body,key,current.runtimeInstance)end)
    return good and object or nil
end
function P.canHearLeisureObject(id,body,source,range)
    if type(source)~="table" or source.actorId~=id or not finiteSoundNumber(range) or range<=0
        or not P.resolveLeisureObject(id,body,source.key) then return false end
    local current=P.conceptObservation(id,source.key)
    for _,field in ipairs({"runtimeInstance","objectIndex","spriteName","concept","x","y","z"}) do
        if current[field]~=source[field] then return false end
    end
    local ok,heard=pcall(function()
        return SAOJavaBridge:canHearLeisureObject(body,current.key,current.runtimeInstance,range)
    end)
    return ok and heard==true
end
function P.leisureAudioSources(id,body)
    if not SAO.Needs.ownsRecoveryBody(id,body) then return {} end
    local ok,tick=pcall(function()return SAO.History.ticks()end)
    if not ok then return {} end
    local context=P.conceptContext(id,tick);local out={}
    for _,row in ipairs(context.observations or {})do
        if row.actorId==id and row.kind=="object" and row.source=="native-personal-visibility"
            and type(row.runtimeInstance)=="string" then
            local kind=row.objectCollection=="worldObjects" and "placed"
                or row.objectCollection=="vehicle" and "vehicle" or nil
            if kind then local copy=conceptCopy(row);copy.sourceKind=kind;out[#out+1]=copy end
        end
    end
    return out
end
function P.resolveLeisureAudioSource(id,body,key)
    if not SAO.Needs.ownsRecoveryBody(id,body) then return nil end
    local prior=P.conceptObservation(id,key)
    if not prior or prior.actorId~=id or prior.source~="native-personal-visibility"
        or prior.kind~="object" or type(prior.runtimeInstance)~="string"
        or (prior.objectCollection~="worldObjects" and prior.objectCollection~="vehicle")then return nil end
    local ok,tick=pcall(function()return SAO.History.ticks()end)
    if not ok or not P.observeConcepts(id,body,tick)then return nil end
    local current=P.conceptObservation(id,key)
    if not current or current.at~=tick then return nil end
    for _,field in ipairs({"objectCollection","runtimeInstance","objectIndex","itemKey","itemType",
        "vehicleId","vehicleSqlId","vehicleRuntimeInstance","partId","partRuntimeInstance"})do
        if current[field]~=prior[field]then return nil end
    end
    local good,target=pcall(function()
        return SAOJavaBridge:resolveLeisureAudioSource(body,key,current.runtimeInstance)
    end)
    return good and target or nil
end
function P.canHearLeisureSource(id,body,source,range)
    if type(source)~="table" or source.actorId~=id or not finiteSoundNumber(range) or range<=0
        or not P.resolveLeisureAudioSource(id,body,source.key)then return false end
    local current=P.conceptObservation(id,source.key)
    for _,field in ipairs({"runtimeInstance","objectCollection","itemKey","itemType","vehicleId",
        "vehicleSqlId","vehicleRuntimeInstance","partId","partRuntimeInstance"})do
        if current[field]~=source[field]then return false end
    end
    local ok,heard=pcall(function()
        return SAOJavaBridge:canHearLeisureSource(body,current.key,current.runtimeInstance,range)
    end)
    return ok and heard==true
end
function P.conceptMemories(id,tick)
    local concepts=P.beliefs[id] and P.beliefs[id].concepts
    local out={}
    if not concepts or not finiteSoundNumber(tick) then return out end
    for _,key in ipairs(concepts.order or {}) do
        local row=concepts.observations[key]
        if row and row.actorId==id and row.source=="native-personal-visibility"
            and finiteSoundNumber(row.at) and row.at<=tick and finiteSoundNumber(row.x)
            and finiteSoundNumber(row.y) and finiteSoundNumber(row.z) then
            out[#out+1]=conceptCopy(row)
        end
    end
    return out
end
function P.conceptContext(id,tick,body)
    local concepts=P.beliefs[id] and P.beliefs[id].concepts
    if not concepts or concepts.readerStatus~="available" or not finiteSoundNumber(tick)
        or tick<concepts.at or tick-concepts.at>120 then
        return {status="observation-unavailable",observations={},frontiers={},approaches={}}
    end
    if body then
        local bound=conceptObservers[id]
        if not bound or bound.body~=body then
            return {status="observation-unavailable",observations={},frontiers={},approaches={}} end
        if concepts.sourceGroundOnly then
            local source=SAO.WeekOneContinuity
            local ok,current,brain=pcall(function()
                if source and source.sourceBodyFor then return source.sourceBodyFor(id) end
            end)
            if not ok or current~=body or type(brain)~="table"
                or brain.id~=bound.sourceBrainId or brain.born~=bound.sourceBorn then
                return {status="observation-unavailable",observations={},frontiers={},approaches={}} end
        end
    end
    local out={status="observed",at=concepts.at,roomId=concepts.currentRoomId,
        buildingId=concepts.currentBuildingId,observations={},frontiers={},approaches={}}
    local rec=SAO.Identity and SAO.Identity.get(id)
    local known=P.knownPlaces(id)
    local home=out.buildingId and (known[out.buildingId] or known[tonumber(out.buildingId)])
    if rec and home and finiteSoundNumber(rec.homeX) and finiteSoundNumber(rec.homeY)
        and finiteSoundNumber(home.minX) and finiteSoundNumber(home.maxX)
        and finiteSoundNumber(home.minY) and finiteSoundNumber(home.maxY)
        and rec.homeX>=home.minX and rec.homeX<home.maxX and rec.homeY>=home.minY and rec.homeY<home.maxY then
        out.observations[#out.observations+1]={key="residence:"..out.buildingId,concept="residence",kind="place",
            actorId=id,buildingId=out.buildingId,roomId=out.roomId,at=concepts.at,
            source="personally-remembered-home",x=rec.homeX,y=rec.homeY,z=rec.homeZ or 0}
    end
    if not concepts.sourceGroundOnly then
        for _,key in ipairs(concepts.order) do
            local row=concepts.observations[key]
            if row.actorId==id and row.at==concepts.at then out.observations[#out.observations+1]=conceptCopy(row) end
        end
        for _,key in ipairs(concepts.frontierOrder) do
            local row=concepts.frontiers[key]
            if row.actorId==id and row.at==concepts.at and row.roomId==out.roomId
                and row.buildingId==out.buildingId then out.frontiers[#out.frontiers+1]=conceptCopy(row) end
        end
    end
    for _,row in ipairs(concepts.approaches or {}) do
        if row.actorId==id and row.at==concepts.at then out.approaches[#out.approaches+1]=conceptCopy(row) end
    end
    return out
end

-- Exterior leads are separate from visits. The remembered destination is the
-- observed outside approach, never the map's unobserved building center.
function P.knownBuildingLeads(id, tick)
    local b, leads = P.beliefs[id], {}
    for key, lead in pairs(b and b.buildingLeads or {}) do
        local known = type(lead) == "table" and b.known
            and (b.known[lead.buildingId] or b.known[tonumber(lead.buildingId)])
        if type(lead) == "table" and lead.personId == tostring(id)
            and lead.source == "native-visible-exterior" and P.exteriorLeadKey(lead) == key
            and finiteSoundNumber(lead.cx) and finiteSoundNumber(lead.cy) and finiteSoundNumber(lead.z)
            and finiteSoundNumber(lead.at) and (not tick or lead.at <= tick)
            and not (known and (known.visits or 0) > 0) then
            leads[key] = { buildingId = lead.buildingId, cx = lead.cx, cy = lead.cy, z = lead.z,
                surfaceX = lead.surfaceX, surfaceY = lead.surfaceY, kind = lead.kind,
                at = lead.at, source = lead.source, personId = lead.personId,
                apertureState = APERTURE_STATES[lead.apertureState] and lead.apertureState or "unknown" }
            local failure = lead.entryFailure
            if type(failure) == "table" and failure.source == "native-route-interaction"
                and finiteSoundNumber(failure.at) and (not tick or failure.at <= tick)
                and finiteSoundNumber(failure.atHours) and finiteSoundNumber(failure.attempts)
                and failure.attempts >= 1 and failure.attempts <= 4 then
                leads[key].entryFailure = { reason = failure.reason, apertureState = failure.apertureState,
                    at = failure.at, atHours = failure.atHours, attempts = failure.attempts, source = failure.source }
            end
        end
    end
    return leads
end

-- Have they been here, and how long ago in ticks? nil when the place
-- is not one they know.
function P.placeAge(id, placeId, tick)
    local b = P.beliefs[id]
    local k = b and b.known and b.known[placeId]
    if not k then return nil end
    return (tick or 0) - (k.at or 0)
end

function P.forget(id)
    P.forgetSoundCues(id)
    conceptObservers[id] = nil
    if SAO.Orienting and SAO.Orienting.forget then SAO.Orienting.forget(id) end
    P.beliefs[id] = nil
    -- [C108] A dropped mind is a write; derived readers recompute.
    P.beliefVersion = P.beliefVersion + 1
end

-- [C108] A company's places, ranked - the generalised [C76] scorer.
--
-- [C76] picked ONE building for a settling house: the places its
-- members actually reach, visits summed across them times the
-- distinct members who reach them, water doubled. That same walk
-- answers a bigger question the operator named as a real error
-- rather than a missing feature (DR-006 S4): a group's ground is not
-- one rectangle under one name. So the same facts - every arrival
-- `learnBuilding` has recorded since [B37], the same score, the same
-- water doubling - are ranked here instead of picked from, and the
-- settling pass reads the top of the ranking, which keeps the seat
-- and the set from becoming two laws ([C25]).
--
-- Recency breaks ties: `lastAt` is when the last of them was last
-- there, so of two places equally returned to, the one somebody
-- still goes to ranks above the one they have stopped going to. A
-- place stops being the group's when its people stop going, and it
-- stops the same way it started - through the walking. Nothing is
-- stored, so nothing expires.
--
-- Living members only - callers pass `membersOf`, which already
-- refuses the dead - so the estate rule (F-034) holds on the derived
-- side too: the dead keep no ground.
--
-- Returns a list sorted best-first, each entry
--   { id = building id, place = the known record, visits, who,
--     lastAt, score }
-- Recomputed when asked; group-shaped readers cache against
-- `P.beliefVersion` so they do not pay this walk per call ([C77]).
function P.returnsOf(members)
    if not members then return {} end
    local returns = {}
    for _, mid in ipairs(members) do
        local b = P.beliefs[mid]
        if b and b.known then
            for pid, kp in pairs(b.known) do
                if not kp.sourceId and kp.minX and kp.cx then
                    local t = returns[pid]
                    if not t then
                        t = { id = pid, place = kp, visits = 0,
                              who = 0, lastAt = kp.at or 0 }
                        returns[pid] = t
                    end
                    t.visits = t.visits + (kp.visits or 1)
                    t.who = t.who + 1
                    if (kp.at or 0) > t.lastAt then
                        t.lastAt = kp.at
                    end
                end
            end
        end
    end
    local ranked = {}
    for _, t in pairs(returns) do
        local kp = t.place
        -- [C76]'s own score, unchanged: returned to, by more than
        -- one of them, worth returning to. Water is the only source
        -- weighed, because it is the need that kills first ([B37])
        -- and the one a base either has or does not.
        t.score = t.visits * t.who
        if kp.sources and kp.sources.water then
            t.score = t.score * 2
        end
        ranked[#ranked + 1] = t
    end
    table.sort(ranked, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.lastAt > b.lastAt
    end)
    return ranked
end

-- ---------------------------------------------------------------------------
-- [C15] Whole minds survive the reload (DR-020)

-- [C112] The rebase that lived here is GONE, and its reason with it:
-- it zeroed every tick-stamped field on bind because "the tick axis
-- cannot cross sessions - a frame count from a dead session is
-- meaningless in a live one." The tick is the county's clock now
-- (`SAO.History.ticks`, world-age quantized), so the axis crosses
-- sessions as of course as the atHours stamps always did: a belief
-- saved yesterday reads as yesterday, with no grace period and no
-- reset. Zeroing fresh stamps on every reload would now be the bug
-- the rebase cured - it would age a two-minute-old belief to the
-- beginning of the world on every load.
--
-- What a save from an older build carries instead is FRAME-domain
-- stamps, and they cut both ways. Most sit below the county's ticks
-- and read as ANCIENT - stale, pruned by their horizon, rescan: the
-- safe direction. But a long pre-[C112] session's frame count can sit
-- ABOVE a young county's ticks, and an `at` ahead of now reads as
-- ultra-fresh forever (every freshness test passes a negative age) -
-- the exact defect the old rebase existed to prevent. In the county
-- domain a stamp can never be ahead of now (stamps are made at now,
-- and the clock never runs backwards), so ahead-of-now is a domain
-- mark, not a value: the check below drops every such stamp to 0,
-- which reads as long ago. One reload's relearn per old save, both
-- directions safe, then never again. The durable truths are as they
-- were - dead-flagged people never decay (F-033), places prune by
-- proximity not time, and the world-hours stamps (atHours and the
-- out-terms) still carry a belief's REAL age for every reader that
-- needs it.
--
-- The scan self-throttle is the same law right side up: a stamp of 0
-- (or a defaulted one) reads as long ago, so "do it now" is the
-- default, never "never".
local function dropForeignStamps(b, now)
    if type(b) ~= "table" then return end
    for key, value in pairs(b) do
        if type(value) == "number" and type(key) == "string"
            and key:sub(-2) == "At" and not key:find("Hours")
            and value > now then
            b[key] = 0
        end
    end
    for _, tableName in ipairs({ "zombies", "people", "factions", "sounds" }) do
        local entries = b[tableName]
        if type(entries) == "table" then
            for _, entry in pairs(entries) do
                if type(entry) == "table"
                    and type(entry.at) == "number"
                    and entry.at > now then
                    entry.at = 0
                end
            end
        end
    end
    if type(b.criedTiles) == "table" then
        for key, value in pairs(b.criedTiles) do
            if type(value) == "number" and value > now then
                b.criedTiles[key] = 0
            end
        end
    end
    -- The owned-ground map and the known-buildings map both carry a
    -- tick-domain `at` on every entry (keyed by owner or building id,
    -- which is why the generic "At"-suffix walk above cannot reach
    -- them), and `placeAge` subtracts them from now exactly as the
    -- sighting stamps are subtracted - so a foreign ahead-of-now one
    -- reads as just-visited by the same arithmetic.
    for _, tableName in ipairs({ "places", "known" }) do
        local entries = b[tableName]
        if type(entries) == "table" then
            for _, entry in pairs(entries) do
                if type(entry) == "table"
                    and type(entry.at) == "number"
                    and entry.at > now then
                    entry.at = 0
                end
            end
        end
    end
end

function P.bindPersistentStore()
    -- A world/load boundary never restores pulse or body authority.
    soundPulses = {}
    weekOneNativeSignals = {}
    conceptObservers = {}
    if SAO.Orienting and SAO.Orienting.reset then SAO.Orienting.reset() end
    local ok, persisted = pcall(function()
        return ModData.getOrCreate("SurvivorAwareness_Beliefs")
    end)
    if not ok or type(persisted) ~= "table" then
        -- Stated, not silent: without the store, minds are
        -- session-scoped this run, exactly the pre-[C15] behavior.
        log("belief store unavailable (" .. tostring(persisted)
            .. "); minds are session-scoped this run")
        return false
    end
    if persisted == P.beliefs then
        for _, b in pairs(persisted) do
            if type(b) == "table" then soundEvidence(b) end
        end
        return true   -- already bound; a second start must not rebind
    end
    -- [C112] The domain check's now. Read through a pcall: a bind
    -- that happens before the bridge is up understates the county's
    -- hours by the days it owes, which can zero a legitimate stamp -
    -- and zeroing reads as ancient, the safe direction, so an early
    -- bind costs freshness, never correctness.
    local now = 0
    pcall(function() now = SAO.History.ticks() end)
    local restored = 0
    for _, b in pairs(persisted) do
        if type(b) == "table" then
            dropForeignStamps(b, now)
            soundEvidence(b)
            -- Restored records remain ordinary memories. Runtime tracking
            -- authority belongs only to the current native observer session.
            for _, belief in pairs(b.zombies or {}) do belief.track = nil end
            restored = restored + 1
        end
    end
    for id, b in pairs(P.beliefs) do
        if type(b) == "table" then soundEvidence(b) end
        persisted[id] = b   -- pre-bind session entries carry over
    end
    P.beliefs = persisted
    -- [C108] The store was swapped; derived readers recompute.
    P.beliefVersion = P.beliefVersion + 1
    log(restored .. " mind(s) restored from the save (DR-020)")
    return true
end

if Events and Events.OnGameStart then
    Events.OnGameStart.Add(function()
        pcall(P.bindPersistentStore)
    end)
end

return P
