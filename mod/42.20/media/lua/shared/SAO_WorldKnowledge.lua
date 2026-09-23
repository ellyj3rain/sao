-- SAO_WorldKnowledge - dated personal acquisitions from the county record.
--
-- Speakeasy owns protected prose, extraction review and training standing.
-- This runtime owns the other half of that seam: whether one particular
-- person actually acquired and still carries a hash-bound claim identifier.
-- A native reading completion writes a personal receipt. Knowledge queries
-- return detached plain tables without creating acquisitions.

SAO = SAO or {}
SAO.WorldKnowledge = SAO.WorldKnowledge or {}
local W = SAO.WorldKnowledge

local SCHEMA_VERSION = 2
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
        eventResolution = "publication-date",
        carrier = "print",
        path = "read",
        knowledgeKind = "reported",
        printInfoKey = "Print_Media_KnoxKnews_July2_info",
        printTextKey = "Print_Text_KnoxKnews_July2_info",
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
        state = { schemaVersion = SCHEMA_VERSION, presence = {}, acquisitions = {},
            readReceipts = {} }
        rec.worldKnowledge = state
    end
    -- Only a producer migrates. The old assertion remains available for audit,
    -- but presence and age never certify personal acquisition.
    if create and type(state) == "table" and state.schemaVersion == 1
        and type(state.presence) == "table" and type(state.acquisitions) == "table" then
        state = { schemaVersion = SCHEMA_VERSION, presence = copy(state.presence),
            pendingPresence = copy(state.pendingPresence), acquisitions = {}, readReceipts = {},
            legacy = { reason = "county-presence-does-not-prove-acquisition", state = state } }
        rec.worldKnowledge = state
    end
    if type(state) ~= "table" or state.schemaVersion ~= SCHEMA_VERSION
        or type(state.presence) ~= "table"
        or type(state.acquisitions) ~= "table"
        or type(state.readReceipts) ~= "table" then return nil end
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

-- Time passage resolves presence bookkeeping; it grants no report knowledge.
function W.advancePerson(person, atHour)
    local state = stateOf(recordOf(person), true)
    if not state then return 0 end
    resolvePending(recordOf(person), state)
    return 0
end

local function claimFor(id)
    for _, claim in ipairs(CLAIMS) do
        if claim.id == id then return claim end
    end
    return nil
end

local function nonempty(value)
    return type(value) == "string" and value ~= ""
end

local function validAcquisition(entry, state, rec, atHour)
    if type(entry) ~= "table" then return false end
    local claim = claimFor(entry.claimId)
    local receipt = state.readReceipts[entry.receiptId]
    local published = claim and hourFor(claim.recordDay)
    if not claim or not finite(published) or type(receipt) ~= "table"
        or entry.schemaVersion ~= SCHEMA_VERSION or entry.personId ~= rec.id
        or entry.path ~= "read" or entry.knowledgeKind ~= "reported"
        or entry.carrier ~= "print" or entry.access ~= "completed-native-print-read"
        or type(entry.retained) ~= "boolean" or not finite(entry.acquiredHour)
        or not finite(atHour) or entry.acquiredHour > atHour
        or entry.acquiredHour < published then return false end
    local source, event = entry.source, entry.sourceEvent
    if type(source) ~= "table" or source.owner ~= claim.sourceOwner
        or source.path ~= claim.sourcePath or source.line ~= claim.sourceLine
        or source.sha256 ~= claim.sourceSha256 or source.excerptSha256 ~= claim.excerptSha256
        or type(event) ~= "table" or event.kind ~= "dated-report"
        or event.recordDay ~= claim.recordDay or event.atHours ~= published
        or event.resolution ~= "publication-date" then return false end
    return receipt.schemaVersion == 1 and receipt.recordId == entry.receiptId
        and receipt.recordId == rec.id .. "/print-read/" .. claim.id
        and entry.recordId == rec.id .. "/world-report/" .. claim.id
        and receipt.personId == rec.id and receipt.claimId == claim.id
        and receipt.producer == "ISReadABook.complete" and receipt.result == "completed"
        and receipt.completedHour == entry.acquiredHour
        and receipt.infoKey == claim.printInfoKey and receipt.textKey == claim.printTextKey
        and finite(receipt.itemId) and receipt.itemId >= 0
        and receipt.itemId == math.floor(receipt.itemId)
        and nonempty(receipt.itemType) and nonempty(receipt.mediaId)
        and entry.producer == "SAO.WorldKnowledge.completedPrintRead"
end

-- Capture the exact issue before the completion callback can move or alter it.
-- A source report is not a telephone or computer service observation.
local function readingSubject(action)
    if not action or action.forceStopped then return nil end
    local body, item = action.character, action.item
    if not body or not item then return nil end
    local id = body:getModData().SAOPersonId
    local rec = id and recordOf(id)
    if not rec or rec.id ~= id or rec.dead or SAO.Body.get(id) ~= body
        or not body:getInventory():contains(item) then return nil end
    local media = item:getModData().printMedia
    if type(media) ~= "table" or not nonempty(media.id) then return nil end
    local claim
    for _, candidate in ipairs(CLAIMS) do
        if media.info == candidate.printInfoKey and media.text == candidate.printTextKey then
            claim = candidate
        end
    end
    local hour = nowHour()
    local published = claim and hourFor(claim.recordDay)
    if not claim or not finite(hour) or not finite(published) or hour < published then return nil end
    local itemId, itemType = item:getID(), item:getFullType()
    if not finite(itemId) or itemId < 0 or itemId ~= math.floor(itemId)
        or not nonempty(itemType) then return nil end
    return { body = body, item = item, person = rec, claim = claim, hour = hour,
        itemId = itemId, itemType = itemType, mediaId = media.id,
        infoKey = media.info, textKey = media.text }
end

local function completedPrintRead(before, action, result)
    if not before or result ~= true then return false end
    local after = readingSubject(action)
    if not after or after.body ~= before.body or after.item ~= before.item
        or after.person ~= before.person or after.claim ~= before.claim
        or after.itemId ~= before.itemId or after.itemType ~= before.itemType
        or after.mediaId ~= before.mediaId or after.infoKey ~= before.infoKey
        or after.textKey ~= before.textKey or after.hour < before.hour
        or not after.body:getReadPrintMedia():contains(after.mediaId) then return false end
    local state = stateOf(after.person, true)
    if not state then return false end
    for _, entry in ipairs(state.acquisitions) do
        if entry.claimId == after.claim.id then
            return validAcquisition(entry, state, after.person, after.hour)
        end
    end
    if #state.acquisitions >= #CLAIMS then return false end
    local claim, id = after.claim, after.person.id
    local receiptId = id .. "/print-read/" .. claim.id
    local receipt = { schemaVersion = 1, recordId = receiptId, personId = id,
        claimId = claim.id, itemId = after.itemId, itemType = after.itemType,
        mediaId = after.mediaId, infoKey = after.infoKey, textKey = after.textKey,
        completedHour = after.hour, producer = "ISReadABook.complete", result = "completed" }
    local entry = { schemaVersion = SCHEMA_VERSION,
        recordId = id .. "/world-report/" .. claim.id, personId = id, claimId = claim.id,
        source = { owner = claim.sourceOwner, path = claim.sourcePath,
            sha256 = claim.sourceSha256, line = claim.sourceLine,
            excerptSha256 = claim.excerptSha256 },
        sourceEvent = { kind = "dated-report", recordDay = claim.recordDay,
            atHours = hourFor(claim.recordDay), resolution = "publication-date" },
        acquiredHour = after.hour, path = "read", knowledgeKind = "reported",
        carrier = "print", access = "completed-native-print-read", receiptId = receiptId,
        retained = true, retentionPolicy = "durable-until-explicit-supersession",
        producer = "SAO.WorldKnowledge.completedPrintRead" }
    state.readReceipts[receiptId] = receipt
    state.acquisitions[#state.acquisitions + 1] = entry
    return true
end

function W.installReadingObserver()
    if not ISReadABook or type(ISReadABook.complete) ~= "function" then return false end
    if ISReadABook.complete == W._observedReadComplete then return true end
    local original = ISReadABook.complete
    local wrapper = function(action, ...)
        local ok, before = pcall(readingSubject, action)
        local result = original(action, ...)
        if ok and before then
            local recorded, why = pcall(completedPrintRead, before, action, result)
            if not recorded and SAO.Log then SAO.Log.line("KNOWLEDGE", "print receipt failed: " .. tostring(why)) end
        end
        return result
    end
    W._observedReadComplete = wrapper
    ISReadABook.complete = wrapper
    return true
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
        if validAcquisition(entry, state, rec, atHour)
            and entry.retained == true and entry.supersededAt == nil then
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
                source = { status = "supported", recordId = entry.receiptId },
                acquisition = { status = "supported", recordId = entry.receiptId },
                access = { status = "supported", recordId = entry.receiptId },
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

function W.knowledgeEvidenceReady(person)
    local rec = recordOf(person)
    local state = stateOf(rec, false)
    local hour = nowHour()
    if not state or state.pendingPresence ~= nil or not finite(hour) then return false end
    local count, seen, receipts = 0, {}, {}
    for index, entry in pairs(state.acquisitions) do
        count = count + 1
        if type(index) ~= "number" or index < 1 or index ~= math.floor(index)
            or index > #state.acquisitions or not validAcquisition(entry, state, rec, hour)
            or seen[entry.claimId] then return false end
        seen[entry.claimId] = true
        receipts[entry.receiptId] = true
    end
    local receiptCount = 0
    for key in pairs(state.readReceipts) do
        if not receipts[key] then return false end
        receiptCount = receiptCount + 1
    end
    return count == #state.acquisitions and receiptCount == count
end

-- Shared timed actions are the native completion owner on the local/server VM.
-- Offline hosts without that engine module leave the observer unavailable.
pcall(function()
    require "TimedActions/ISReadABook"
    W.installReadingObserver()
end)

return W
