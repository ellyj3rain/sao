-- SAO_WorldKnowledge - dated personal acquisitions from the county record.
--
-- Speakeasy owns protected prose, extraction review and training standing.
-- This runtime owns the other half of that seam: whether one particular
-- person actually acquired and still carries a hash-bound claim identifier.
-- No read creates an acquisition. Population/history producers write the
-- personal event once; readers receive detached plain tables.

SAO = SAO or {}
SAO.WorldKnowledge = SAO.WorldKnowledge or {}
local W = SAO.WorldKnowledge

local SCHEMA_VERSION = 1
local FIRST_RECORD_DAY = -8 -- July 1 relative to the shipped July 9 day zero.

-- Data port from Zomboid-Speakeasy. Protected text deliberately does not cross
-- the licence boundary. Speakeasy verifies these exact bytes before it may
-- associate its reviewed extraction with this acquisition.
local CLAIMS = {
    {
        id = "knox-telecommunications-outage-1993-07-02",
        sourceOwner = "Zomboid-Speakeasy",
        sourcePath = "world/us-1993/knox-event.md",
        sourceSha256 = "bc4b723d8ba8a35eca4a43e88e1457c4dc225d7213ead5c52364f966c6aa0676",
        sourceLine = 71,
        excerptSha256 = "f663ffcbaa873c8fb228e1fbdf8574861a0f149559d1fec20695c6be32e82c60",
        eventYear = 1993,
        recordDay = -7, -- July 2.
        eventResolution = "date",
        carrier = "county",
        path = "lived",
        minimumAge = 18,
        access = "area-wide-telephone-and-internet-outage",
    },
}

local function finite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return nil end
    seen[value] = true
    local out = {}
    for key, child in pairs(value) do out[copy(key, seen)] = copy(child, seen) end
    seen[value] = nil
    return out
end

local function recordOf(person)
    if type(person) == "table" then return person end
    if not (SAO.Identity and SAO.Identity.get) then return nil end
    return SAO.Identity.get(person)
end

local function stateOf(rec, create)
    if not rec then return nil end
    local state = rec.worldKnowledge
    if state == nil and create then
        state = { schemaVersion = SCHEMA_VERSION, presence = {}, acquisitions = {} }
        rec.worldKnowledge = state
    end
    if type(state) ~= "table" or state.schemaVersion ~= SCHEMA_VERSION
        or type(state.presence) ~= "table"
        or type(state.acquisitions) ~= "table" then return nil end
    -- One active acquisition per versioned claim. Besides rejecting a
    -- malformed save, this is the bound that makes claimsOf's deterministic
    -- sort safe in Kahlua's recursive quicksort.
    if #state.acquisitions > #CLAIMS then return nil end
    return state
end

local function hourFor(recordDay)
    if not (SAO.History and SAO.History.recordHour) then return nil end
    local ok, hour = pcall(SAO.History.recordHour, recordDay)
    return (ok and finite(hour)) and hour or nil
end

local function nowHour()
    if not (SAO.History and SAO.History.countyHours) then return nil end
    local ok, hour = pcall(SAO.History.countyHours)
    return (ok and finite(hour)) and hour or nil
end

local function activePresence(state)
    for _, entry in ipairs(state.presence) do
        if entry.throughHour == nil then return entry end
    end
    return nil
end

local function appendPresence(rec, state, source, region, fromHour,
                              fromRecordDay)
    if type(source) ~= "string" or source == ""
        or type(region) ~= "string" or region == ""
        or not finite(fromHour) then return nil, "incomplete-presence" end
    local open = activePresence(state)
    if open then
        if open.source == source and open.region == region
            and open.fromHour == fromHour
            and open.fromRecordDay == fromRecordDay then
            return open
        end
        return nil, "presence-already-open"
    end
    local sequence = #state.presence + 1
    local entry = {
        schemaVersion = SCHEMA_VERSION,
        recordId = tostring(rec.id) .. "/county-presence/" .. tostring(sequence),
        personId = tostring(rec.id),
        source = source,
        region = region,
        fromHour = fromHour,
        fromRecordDay = fromRecordDay,
        throughHour = nil,
        producer = "SAO.PopulationAdmissions",
    }
    state.presence[sequence] = entry
    return entry
end

local function resolvePending(rec, state)
    local pending = state.pendingPresence
    if type(pending) ~= "table" then return true end
    local fromHour = pending.fromHour
    if not finite(fromHour) and type(pending.fromRecordDay) == "number" then
        fromHour = hourFor(pending.fromRecordDay)
    end
    if not finite(fromHour) then return false, "calendar-unavailable" end
    local entry, why = appendPresence(rec, state, pending.source,
        pending.region, fromHour, pending.fromRecordDay)
    if not entry then return false, why end
    state.pendingPresence = nil
    return true
end

-- Population is the only producer of county presence. Initial residents have
-- a life in this county beginning on the record's first day. Later arrivals
-- begin at the actual admission hour and therefore cannot inherit its past.
function W.markCountyPresence(person, initialResident)
    local rec = recordOf(person)
    if not rec or type(rec.id) ~= "string" or rec.id == ""
        or type(rec.originRegion) ~= "string" or rec.originRegion == "" then
        return false, "person-origin-unavailable"
    end
    local state = stateOf(rec, true)
    if not state then return false, "world-knowledge-store-unreadable" end
    if activePresence(state) then return true end
    if state.pendingPresence then
        local ready, why = resolvePending(rec, state)
        if not ready then return false, why end
        W.advancePerson(rec)
        return true
    end
    local pending = {
        source = initialResident and "genesis-origin" or "admitted-arrival",
        region = rec.originRegion,
    }
    if initialResident then
        pending.fromRecordDay = FIRST_RECORD_DAY
    else
        pending.fromHour = nowHour()
    end
    state.pendingPresence = pending
    local ready, why = resolvePending(rec, state)
    if not ready then return false, why end
    W.advancePerson(rec)
    return true
end

local function presenceAt(state, hour)
    for _, entry in ipairs(state.presence) do
        if finite(entry.fromHour) and entry.fromHour <= hour
            and (entry.throughHour == nil or entry.throughHour >= hour) then
            return entry
        end
    end
    return nil
end

local function ageAtEvent(id, year)
    if not (SAO.History and SAO.History.ageInYear) then return nil end
    local ok, age = pcall(SAO.History.ageInYear, id, year)
    return (ok and finite(age)) and age or nil
end

local function acquired(state, claimId)
    for _, entry in ipairs(state.acquisitions) do
        if entry.claimId == claimId and entry.supersededAt == nil then return entry end
    end
    return nil
end

function W.advancePerson(person, atHour)
    local rec = recordOf(person)
    local state = stateOf(rec, false)
    if not state then return 0 end
    resolvePending(rec, state)
    atHour = tonumber(atHour) or nowHour()
    if not finite(atHour) then return 0 end
    local added = 0
    for _, claim in ipairs(CLAIMS) do
        if not acquired(state, claim.id) then
            local eventHour = hourFor(claim.recordDay)
            local presence = eventHour and presenceAt(state, eventHour) or nil
            local age = ageAtEvent(rec.id, claim.eventYear)
            if finite(eventHour) and eventHour <= atHour and presence
                and finite(age) and age >= claim.minimumAge then
                local sequence = #state.acquisitions + 1
                state.acquisitions[sequence] = {
                    schemaVersion = SCHEMA_VERSION,
                    recordId = tostring(rec.id) .. "/world-claim/"
                        .. tostring(sequence),
                    personId = tostring(rec.id),
                    claimId = claim.id,
                    source = {
                        owner = claim.sourceOwner,
                        path = claim.sourcePath,
                        sha256 = claim.sourceSha256,
                        line = claim.sourceLine,
                        excerptSha256 = claim.excerptSha256,
                    },
                    sourceEvent = {
                        kind = "county-lived-day",
                        recordDay = claim.recordDay,
                        atHours = eventHour,
                        resolution = claim.eventResolution,
                    },
                    acquiredHour = eventHour,
                    path = claim.path,
                    carrier = claim.carrier,
                    access = claim.access,
                    ageAtEvent = age,
                    presenceRecordId = presence.recordId,
                    retained = true,
                    retentionPolicy = "durable-until-explicit-supersession",
                    producer = "SAO.WorldKnowledge.advancePerson",
                }
                added = added + 1
            end
        end
    end
    return added
end

function W.advanceAll(atHour)
    if not (SAO.Identity and SAO.Identity.all) then return 0 end
    local added = 0
    for _, rec in pairs(SAO.Identity.all()) do
        added = added + W.advancePerson(rec, atHour)
    end
    return added
end

-- Detached holder records available at this moment. The decision capture uses
-- the same person record, but consumers do not need to know its storage shape.
function W.claimsOf(person, atHour)
    local rec = recordOf(person)
    local state = stateOf(rec, false)
    atHour = tonumber(atHour) or nowHour()
    if not state or not finite(atHour) then return {} end
    local out = {}
    for _, entry in ipairs(state.acquisitions) do
        if entry.retained == true and entry.supersededAt == nil
            and finite(entry.acquiredHour) and entry.acquiredHour <= atHour then
            out[#out + 1] = copy(entry)
        end
    end
    table.sort(out, function(left, right)
        if left.acquiredHour ~= right.acquiredHour then
            return left.acquiredHour < right.acquiredHour
        end
        return left.claimId < right.claimId
    end)
    return out
end

-- Separate retention observation for an evidence consumer. It names the
-- producer records used by each check and never alters the acquisition.
function W.observe(person, atHour)
    local rec = recordOf(person)
    atHour = tonumber(atHour) or nowHour()
    if not rec or not finite(atHour) then return {} end
    local out = {}
    for _, entry in ipairs(W.claimsOf(rec, atHour)) do
        out[#out + 1] = {
            schemaVersion = SCHEMA_VERSION,
            recordId = entry.recordId .. "/retention/" .. tostring(atHour),
            personId = rec.id,
            claimId = entry.claimId,
            acquiredHour = entry.acquiredHour,
            asOfHour = atHour,
            path = entry.path,
            retained = true,
            checks = {
                age = { status = "supported", recordId = entry.recordId },
                carrier = { status = "supported",
                    recordId = entry.presenceRecordId },
                access = { status = "supported",
                    recordId = entry.presenceRecordId },
                retention = { status = "supported", recordId = entry.recordId },
            },
            acquisition = entry,
        }
    end
    return out
end

function W.presenceOf(person)
    local state = stateOf(recordOf(person), false)
    return state and copy(state.presence) or {}
end

function W.claimPorts()
    return copy(CLAIMS)
end

return W
