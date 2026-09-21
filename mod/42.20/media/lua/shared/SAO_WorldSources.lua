-- SAO_WorldSources - exact native ground for loaded and dormant life (R10a).
--
-- Buildings remain geography. A room name can suggest a place worth
-- exploring, but only this ledger answers what the ground actually holds.
-- Java generates/loads bounded PZ chunks through the engine's native raw-chunk
-- path and returns exact source and item identities. This module persists a
-- bounded observation working set, keeps physical access separate, and refuses
-- identity/revision conflict. Native depletion remains behind the later
-- access-qualified action executor; observation never awards a resource.

SAO = SAO or {}
SAO.WorldSources = SAO.WorldSources or {}
local WS = SAO.WorldSources

local STORE_KEY = "SurvivorAwareness_WorldSources"
-- Build 42.20.4's exported IsoChunkMap.CHUNK_SIZE_IN_SQUARES. Border 178
-- reads the installed bytecode so this mapping cannot silently drift.
local CHUNK_SIZE = 8
local MAX_SOURCES_PER_CHUNK = 2048
local MAX_ITEMS_PER_SOURCE = 2048
local MAX_TRACKED_CHUNKS = 256
local MAX_TRACKED_PLACES = 256
local MAX_CONFLICTS = 1024
local MAX_RESERVATIONS = 2048
local MAX_RESULTS = 2048
local MAX_PENDING_LOADS = 1024
local MAX_POINTER_REPAIRS = 256
local MAX_PROJECTION_CHANGES = 2048
local MAX_ACTION_OPTIONS = 128
local RESULT_CONSUMER = "provisioning"
local SOURCE_CATEGORY_ORDER = {
    "device", "drink", "food", "fuel", "instrument", "medical",
    "memento", "nails", "plank", "reading", "smokes", "tools",
    "water", "weapons",
}
local SOURCE_CATEGORIES = {}
for _, name in ipairs(SOURCE_CATEGORY_ORDER) do
    SOURCE_CATEGORIES[name] = true
end

local loadedSeen = {}
local pendingLoads = {}
local loadTick = 0

local function log(message)
    if SAO.Log and SAO.Log.line then
        SAO.Log.line("SOURCES", tostring(message))
    end
end

local function nowHours()
    local value = 0
    pcall(function()
        value = SAO.History and SAO.History.countyHours() or 0
    end)
    return tonumber(value) or 0
end

local function trimResults(value)
    local count = 0
    for _ in pairs(value.results) do count = count + 1 end
    while count > MAX_RESULTS do
        local oldestId, oldest = nil, nil
        for id, receipt in pairs(value.results) do
            local acknowledgements = receipt.acknowledgements or {}
            local protected = receipt.status == "completed"
                and not acknowledgements[RESULT_CONSUMER]
            if not protected and (not oldest
                or (receipt.order or 0) < (oldest.order or 0)) then
                oldestId, oldest = id, receipt
            end
        end
        if not oldestId then return false end
        value.results[oldestId] = nil
        if oldest and value.resultByActor[oldest.actorId] == oldestId then
            value.resultByActor[oldest.actorId] = nil
        end
        local oldReservation = value.reservations[oldestId]
        if oldReservation and oldReservation.status ~= "reserved" then
            value.reservations[oldestId] = nil
        end
        count = count - 1
    end
    return true
end

local function store()
    local ok, value = pcall(function()
        return ModData.getOrCreate(STORE_KEY)
    end)
    if not ok or type(value) ~= "table" then return nil end
    local priorSchema = tonumber(value.schema) or 0
    if priorSchema > 5 then
        log("refusing unsupported world-source schema " .. tostring(priorSchema))
        return nil
    end
    value.sources = value.sources or {}
    value.chunks = value.chunks or {}
    value.places = value.places or {}
    value.reservations = value.reservations or {}
    value.results = value.results or {}
    value.resultByActor = value.resultByActor or {}
    value.resultCounts = value.resultCounts or {}
    value.pointerRepairs = value.pointerRepairs or {}
    value.projectionChanges = value.projectionChanges or {}
    value.conflicts = value.conflicts or {}
    value.conflictBySource = value.conflictBySource or {}
    value.sequence = tonumber(value.sequence) or 0
    value.observationSequence = tonumber(value.observationSequence) or 0
    value.conflictSequence = tonumber(value.conflictSequence) or 0
    value.resultSequence = tonumber(value.resultSequence) or 0
    value.pointerRepairSequence = tonumber(value.pointerRepairSequence) or 0
    value.projectionChangeSequence =
        tonumber(value.projectionChangeSequence) or 0
    value.migrationPointers = value.migrationPointers or {}
    if priorSchema < 3 then
        -- Schema 2 reservations described observation-only locks. They lack
        -- C62's live body, action phase, exact item type and postcondition, so
        -- relabeling them would invent resumable work. Preserve observations,
        -- conflicts and prior results; retire only incompatible active locks.
        for id, reservation in pairs(value.reservations) do
            if reservation.status == "reserved" then
                reservation.status = "released"
                reservation.detail = "schema-2-action-incompatible"
                reservation.resultAt = nowHours()
                value.resultSequence = value.resultSequence + 1
                if not value.results[id] then
                    value.results[id] = {
                        reservationId = id,
                        actorId = tostring(reservation.actorId or ""),
                        sourceId = reservation.sourceId,
                        itemId = reservation.itemId,
                        category = reservation.category,
                        quantity = reservation.quantity,
                        status = "released",
                        detail = reservation.detail,
                        at = reservation.resultAt,
                        order = value.resultSequence,
                    }
                    value.resultCounts.released =
                        (tonumber(value.resultCounts.released) or 0) + 1
                end
                if reservation.actorId then
                    local actor = tostring(reservation.actorId)
                    value.resultByActor[actor] = id
                    value.migrationPointers[actor] = id
                end
            end
        end
        trimResults(value)
        value.migratedFrom = priorSchema
    end
    if priorSchema < 4 then
        -- Schema 3 is C62's action ledger. Its completed receipts predate
        -- action-time provisioning attribution, and reservations already past
        -- final source binding cannot reconstruct that fact after upgrade.
        -- Mark those records explicitly so C63 can retire them without
        -- inferring later membership or granting house credit. Reservations
        -- still approaching a source will capture the new context at bind.
        for _, receipt in pairs(value.results) do
            if receipt.status == "completed"
                and receipt.provisioningContext == nil then
                receipt.provisioningContext = "legacy-unattributed"
            end
        end
        for _, reservation in pairs(value.reservations) do
            if reservation.status == "reserved"
                and (reservation.phase == "transferring"
                    or reservation.phase == "using"
                    or reservation.phase == "native-complete")
                and reservation.provisioningContext == nil then
                reservation.provisioningContext = "legacy-unattributed"
                reservation.provisioningGroup = nil
            end
        end
        value.migratedFrom = priorSchema
    end
    -- Schema 5 adds a durable latest-change queue for sources already copied
    -- into Material. Native truth may change without another survivor action;
    -- retaining that observation lets Provisioning refresh or retire the exact
    -- projection after reload instead of leaving house stock stale forever.
    if priorSchema < 5 then value.schema = 5 else value.schema = priorSchema end
    if SAO.Identity and SAO.Identity.get then
        for actorId, reservationId in pairs(value.migrationPointers) do
            local record = SAO.Identity.get(actorId)
            if record then
                if record.worldSourceReservation == reservationId then
                    record.worldSourceReservation = nil
                end
                value.migrationPointers[actorId] = nil
            end
        end
    end
    return value
end

local function trimProjectionChanges(value)
    local count = 0
    for _ in pairs(value.projectionChanges) do count = count + 1 end
    while count > MAX_PROJECTION_CHANGES do
        local oldestId, oldest = nil, nil
        for sourceId, change in pairs(value.projectionChanges) do
            if not oldest or (tonumber(change.order) or 0)
                < (tonumber(oldest.order) or 0) then
                oldestId, oldest = sourceId, change
            end
        end
        if not oldestId then return false end
        value.projectionChanges[oldestId] = nil
        count = count - 1
    end
    return true
end

local function recordProjectionChange(value, sourceId, prior, current, reason)
    sourceId = tostring(sourceId or "")
    if sourceId == "" then return end
    local projected = SAO.Material and SAO.Material.projectedOwner
        and SAO.Material.projectedOwner(sourceId) or nil
    -- A source never seen before and not projected cannot make any existing
    -- Material fact stale. Everything else retains its latest native change.
    if prior == nil and projected == nil then return end
    value.projectionChangeSequence = value.projectionChangeSequence + 1
    value.projectionChanges[sourceId] = {
        sourceId = sourceId,
        priorFingerprint = prior and prior.fingerprint or nil,
        fingerprint = current and current.fingerprint or nil,
        revision = current and current.revision or nil,
        state = current and current.state or "absent",
        chunkX = current and current.chunkX or prior and prior.chunkX or nil,
        chunkY = current and current.chunkY or prior and prior.chunkY or nil,
        observedAt = nowHours(),
        reason = tostring(reason or "native-source-changed"),
        order = value.projectionChangeSequence,
    }
    trimProjectionChanges(value)
end

local function decode(value)
    value = tostring(value or "")
    return (string.gsub(value, "%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end))
end

local function fields(line)
    local out = {}
    for piece in string.gmatch(tostring(line or ""), "[^|]+") do
        local key, value = string.match(piece, "^([^=]+)=(.*)$")
        if key then out[key] = decode(value) end
    end
    return out
end

local function categories(value)
    -- This is the complete vocabulary emitted by ItemRow.categories in the
    -- installed bridge. Keep the protocol finite here as well as in Java so
    -- an unexpected field cannot become an unbounded Kahlua sort/input.
    local out = {}
    for name in string.gmatch(tostring(value or ""), "[^,]+") do
        if not SOURCE_CATEGORIES[name] then return nil end
        out[name] = true
    end
    return out
end

local function itemSignature(item)
    if not item then return nil end
    -- Java emits these names in lexical order. Walk the same finite
    -- vocabulary explicitly: PZ 42's recursive table.sort can overflow on
    -- adversarial order even when a list has a nominal size ceiling.
    local names = {}
    for _, name in ipairs(SOURCE_CATEGORY_ORDER) do
        if item.categories and item.categories[name] then
            names[#names + 1] = name
        end
    end
    return table.concat({ tostring(item.type or ""),
        tostring(tonumber(item.uses) or 0),
        string.format("%.6f", tonumber(item.amount) or 0),
        tostring(item.fluid or ""),
        item.poison and "1" or "0", item.rotten and "1" or "0",
        table.concat(names, ",") }, "|")
end

local function itemSignatures(source)
    local out = {}
    for key, item in pairs((source and source.items) or {}) do
        out[tostring(key)] = itemSignature(item)
    end
    return out
end

-- Parse the Java observation protocol without mutating durable state. Keeping
-- this separate lets commit inspect APPLIED before it retires the reservation.
function WS.parse(text)
    if type(text) ~= "string" or text == "" then return nil end
    local snapshot = { sources = {}, ordered = {} }
    local current = nil
    local ended, headers = false, 0
    for line in string.gmatch(text, "[^\r\n]+") do
        if ended then return nil end
        local kind = string.sub(line, 1, 1)
        if kind == "H" then
            headers = headers + 1
            if headers ~= 1 or #snapshot.ordered > 0 then return nil end
            snapshot.header = fields(line)
        elseif kind == "S" then
            if not snapshot.header or #snapshot.ordered >= MAX_SOURCES_PER_CHUNK then
                return nil
            end
            local raw = fields(line)
            if not raw.id or snapshot.sources[raw.id] then return nil end
            current = {
                id = raw.id,
                fingerprint = raw.fp,
                revision = raw.rev,
                kind = raw.kind,
                x = tonumber(raw.x), y = tonumber(raw.y), z = tonumber(raw.z),
                buildingId = tostring(raw.building or "-1"),
                explored = tonumber(raw.explored) == 1,
                state = raw.state,
                access = raw.access or "unknown",
                container = raw.container or "",
                quantities = {}, items = {}, itemOrder = {},
            }
            for key, value in pairs(raw) do
                local category = string.match(key, "^q:(.+)$")
                if category then
                    current.quantities[category] = tonumber(value) or 0
                end
            end
            snapshot.sources[current.id] = current
            snapshot.ordered[#snapshot.ordered + 1] = current
        elseif kind == "I" then
            if not snapshot.header then return nil end
            local raw = fields(line)
            local source = snapshot.sources[raw.source]
            if not source or #source.itemOrder >= MAX_ITEMS_PER_SOURCE then
                return nil
            end
            if source then
                local itemCategories = categories(raw.cats)
                if not itemCategories then return nil end
                local item = {
                    id = tonumber(raw.id) or 0,
                    type = raw.type or "",
                    uses = tonumber(raw.uses) or 0,
                    amount = tonumber(raw.amount) or 0,
                    fluid = raw.fluid or "",
                    poison = tonumber(raw.poison) == 1,
                    rotten = tonumber(raw.rotten) == 1,
                    categories = itemCategories,
                }
                local key = tostring(item.id)
                if source.items[key] then return nil end
                source.items[key] = item
                source.itemOrder[#source.itemOrder + 1] = key
            end
        elseif line == "E" then
            ended = true
            current = nil
        else
            return nil
        end
    end
    local header = snapshot.header
    local declared = header and tonumber(header.sources) or nil
    if not ended or headers ~= 1 or not header or header.protocol ~= "SAOWS1"
        or not declared or declared ~= #snapshot.ordered then return nil end
    header.cx, header.cy = tonumber(header.cx), tonumber(header.cy)
    if not header.cx or not header.cy then return nil end
    return snapshot
end

local function pendingFor(value, sourceId, exceptId)
    for id, reservation in pairs(value.reservations) do
        if id ~= exceptId and reservation.status == "reserved"
            and reservation.sourceId == sourceId then
            return true
        end
    end
    return false
end

local function actionReservation(value, reservationId, sourceId)
    local reservation = reservationId
        and value.reservations[reservationId] or nil
    if reservation and reservation.status == "reserved"
        and reservation.sourceId == sourceId then return reservation end
    -- A loaded-world observer may see the exact transfer before the action's
    -- final source scan. Once the executor proved that exact item is carried,
    -- the same postcondition is safe to recognize outside the final call.
    for _, candidate in pairs(value.reservations) do
        if candidate.status == "reserved" and candidate.transferProven
            and candidate.sourceId == sourceId then return candidate end
    end
    return nil
end

-- The only source delta this action owns is removal of its exact selected
-- item. Additions, removals or changes to every other item remain concurrent
-- native changes and conflict even when the actor completed a use action.
local function expectedActionPost(reservation, observed)
    if not reservation or not reservation.transferProven or not observed
        or observed.id ~= reservation.sourceId
        or observed.kind ~= reservation.sourceKind
        or observed.fingerprint ~= reservation.fingerprint
        or observed.revision == reservation.preRevision then return false end
    local selected = tostring(reservation.itemId)
    if observed.items and observed.items[selected] then return false end
    local pre = reservation.preItems or {}
    if pre[selected] == nil then return false end
    for key, signature in pairs(pre) do
        if key ~= selected
            and itemSignature(observed.items and observed.items[key]) ~= signature then
            return false
        end
    end
    for key in pairs(observed.items or {}) do
        if pre[tostring(key)] == nil then return false end
    end
    return true
end

local function expectedGroundRemoval(reservation)
    if not reservation or not reservation.transferProven
        or reservation.sourceKind ~= "ground" then return false end
    local selected, count = tostring(reservation.itemId), 0
    for key in pairs(reservation.preItems or {}) do
        count = count + 1
        if tostring(key) ~= selected then return false end
    end
    return count == 1
end

local function copyObservation(source, header)
    return {
        id = source.id,
        fingerprint = source.fingerprint,
        revision = source.revision,
        kind = source.kind,
        x = source.x, y = source.y, z = source.z,
        chunkX = header.cx, chunkY = header.cy,
        buildingId = source.buildingId,
        explored = source.explored,
        state = source.state,
        access = source.access,
        container = source.container,
        quantities = source.quantities,
        items = source.items,
        itemOrder = source.itemOrder,
        observedAt = nowHours(),
        provenance = header.mode,
    }
end

local function trimConflicts(value)
    local count = 0
    for _ in pairs(value.conflicts) do count = count + 1 end
    while count > MAX_CONFLICTS do
        local oldestKey, oldest = nil, nil
        for key, receipt in pairs(value.conflicts) do
            if not pendingFor(value, receipt.id, nil)
                and (not oldest or (receipt.order or 0) < (oldest.order or 0)) then
                oldestKey, oldest = key, receipt
            end
        end
        if not oldestKey then return false end
        value.conflicts[oldestKey] = nil
        if oldest and value.conflictBySource[oldest.id] == oldest then
            value.conflictBySource[oldest.id] = nil
        end
        count = count - 1
    end
    return true
end

local function conflict(value, old, native, reason)
    local id = (old and old.id) or (native and native.id)
    if not id then return nil end
    local prior = value.conflictBySource[id]
    if prior and prior.key then value.conflicts[prior.key] = nil end
    value.conflictSequence = value.conflictSequence + 1
    local key = tostring(value.conflictSequence)
    local receipt = {
        key = key,
        id = id,
        state = "conflicted",
        access = "unknown",
        reason = reason,
        at = nowHours(),
        order = value.conflictSequence,
        chunkX = (old and old.chunkX) or (native and native.chunkX),
        chunkY = (old and old.chunkY) or (native and native.chunkY),
        buildingId = (old and old.buildingId)
            or (native and native.buildingId),
        fingerprint = old and old.fingerprint or nil,
        revision = old and old.revision or nil,
        nativeFingerprint = native and native.fingerprint or nil,
        nativeRevision = native and native.revision or nil,
        quantities = {}, items = {}, itemOrder = {},
    }
    receipt.conflict = { reason = reason, at = receipt.at }
    value.conflicts[key] = receipt
    value.conflictBySource[id] = receipt
    trimConflicts(value)
    return receipt
end

local function protectedChunk(value, chunk)
    for _, reservation in pairs(value.reservations) do
        if reservation.status == "reserved" then
            local originalX = tonumber(reservation.chunkX)
            local originalY = tonumber(reservation.chunkY)
            if originalX == chunk.x and originalY == chunk.y then return true end
            local currentX = tonumber(reservation.currentSourceX)
            local currentY = tonumber(reservation.currentSourceY)
            if currentX and currentY
                and math.floor(currentX / CHUNK_SIZE) == chunk.x
                and math.floor(currentY / CHUNK_SIZE) == chunk.y then
                return true
            end
        end
    end
    return false
end

local function genericObservationAllowed(chunkX, chunkY)
    local value = store()
    if not value then return false, "store-unavailable" end
    local chunk = { x = tonumber(chunkX), y = tonumber(chunkY) }
    if not chunk.x or not chunk.y then return false, "invalid-chunk" end
    if protectedChunk(value, chunk) then
        -- SourceUse owns its exact pre/post snapshots and applies them with the
        -- reservation identity. A generic observer has no completion proof;
        -- defer it so event order cannot misclassify the actor's own physical
        -- transfer as a concurrent native revision.
        return false, "reservation-protected"
    end
    return true
end

local function evictChunk(value, key, chunk)
    for id in pairs(chunk.sourceIds or {}) do
        local source = value.sources[id]
        if source and source.chunkX == chunk.x and source.chunkY == chunk.y then
            value.sources[id] = nil
        end
    end
    value.chunks[key] = nil
    for placeId, place in pairs(value.places) do
        if place.chunks and place.chunks[key] ~= nil then
            value.places[placeId] = nil
        end
    end
end

local function compactChunks(value)
    local count = 0
    for _ in pairs(value.chunks) do count = count + 1 end
    while count > MAX_TRACKED_CHUNKS do
        local oldestKey, oldest = nil, nil
        for key, chunk in pairs(value.chunks) do
            if not protectedChunk(value, chunk)
                and (not oldest or (chunk.order or 0) < (oldest.order or 0)) then
                oldestKey, oldest = key, chunk
            end
        end
        if not oldestKey then return false end
        evictChunk(value, oldestKey, oldest)
        count = count - 1
    end
    return true
end

local function compactPlaces(value)
    local count = 0
    for _ in pairs(value.places) do count = count + 1 end
    while count > MAX_TRACKED_PLACES do
        local oldestId, oldest = nil, nil
        for id, place in pairs(value.places) do
            if not oldest or (place.order or 0) < (oldest.order or 0) then
                oldestId, oldest = id, place
            end
        end
        if not oldestId then return false end
        value.places[oldestId] = nil
        count = count - 1
    end
    return true
end

-- Apply a complete chunk observation. Revision changes with no outstanding
-- reservation are ordinary native truth (player looting, rot, respawn). With
-- a reservation they are a conflict: automatic mutation stops until a fresh
-- native result resolves ownership. A physical fingerprint change is always a
-- conflict because a replacement object must never alias the old source.
function WS.applySnapshot(snapshot, exceptReservationId)
    local value = store()
    if not value or not snapshot or not snapshot.header then return false, 0 end
    local header = snapshot.header
    local accepted = header.status == "OBSERVED"
        or header.status == "HYDRATED"
    if not accepted or not header.cx or not header.cy then return false, 0 end

    local chunkKey = header.cx .. ":" .. header.cy
    local priorChunk = value.chunks[chunkKey]
    local seen, changes = {}, 0
    for _, nativeSource in ipairs(snapshot.ordered) do
        seen[nativeSource.id] = true
        local observed = copyObservation(nativeSource, header)
        local old = value.sources[nativeSource.id]
        local priorConflict = value.conflictBySource[nativeSource.id]
        if priorConflict then
            if not pendingFor(value, nativeSource.id, nil) then
                -- Conflict receipts are historical evidence, not a permanent
                -- poison pill. Once the owning reservation is terminal, one
                -- later complete native observation establishes current truth
                -- under its own revision while retaining the bounded receipt.
                value.conflictBySource[nativeSource.id] = nil
                priorConflict.resolvedAt = nowHours()
                priorConflict.resolutionRevision = observed.revision
                priorConflict.resolutionFingerprint = observed.fingerprint
                priorConflict.resolutionChunkX = observed.chunkX
                priorConflict.resolutionChunkY = observed.chunkY
                value.sources[nativeSource.id] = observed
                recordProjectionChange(value, nativeSource.id, old, observed,
                    "source-conflict-resolved")
            else
                -- Keep one bounded receipt while the owner is unresolved;
                -- refresh only its small native-side evidence.
                priorConflict.lastObservedAt = nowHours()
                priorConflict.nativeFingerprint = observed.fingerprint
                priorConflict.nativeRevision = observed.revision
                recordProjectionChange(value, nativeSource.id, old, nil,
                    "source-conflict-pending")
            end
            changes = changes + 1
        elseif old and old.fingerprint ~= observed.fingerprint then
            value.sources[nativeSource.id] = nil
            conflict(value, old, observed, "physical-fingerprint-changed")
            recordProjectionChange(value, nativeSource.id, old, nil,
                "physical-fingerprint-changed")
            changes = changes + 1
        elseif old and old.revision ~= observed.revision then
            local action = actionReservation(value, exceptReservationId,
                nativeSource.id)
            if expectedActionPost(action, observed) then
                changes = changes + 1
                value.sources[nativeSource.id] = observed
                recordProjectionChange(value, nativeSource.id, old, observed,
                    "native-action-postcondition")
            elseif pendingFor(value, nativeSource.id, nil) then
                value.sources[nativeSource.id] = nil
                conflict(value, old, observed,
                    action and "native-action-postcondition-failed"
                        or "native-revision-changed-during-reservation")
                recordProjectionChange(value, nativeSource.id, old, nil,
                    action and "native-action-postcondition-failed"
                        or "native-revision-changed-during-reservation")
                changes = changes + 1
            else
                changes = changes + 1
                value.sources[nativeSource.id] = observed
                recordProjectionChange(value, nativeSource.id, old, observed,
                    "native-revision-changed")
            end
        else
            if not old or old.revision ~= observed.revision
                or old.state ~= observed.state then
                changes = changes + 1
            end
            value.sources[nativeSource.id] = observed
            if old and old.state ~= observed.state then
                recordProjectionChange(value, nativeSource.id, old, observed,
                    "native-state-changed")
            elseif not old then
                recordProjectionChange(value, nativeSource.id, nil, observed,
                    "native-source-observed")
            end
        end
    end

    -- A complete scan that no longer contains a formerly observed identity is
    -- removal/movement, not empty stock. Keep a small bounded conflict receipt,
    -- not a duplicate of the vanished native inventory.
    for id in pairs((priorChunk and priorChunk.sourceIds) or {}) do
        local old = value.sources[id]
        if old and not seen[id] then
            -- A source already observed in another chunk has moved; clearing
            -- this chunk's old index must not delete the newer observation.
            if old.chunkX ~= header.cx or old.chunkY ~= header.cy then
                -- No source-state change: the replacement chunk owns it now.
            else
                value.sources[id] = nil
                local action = actionReservation(value, exceptReservationId, id)
                if not expectedGroundRemoval(action) then
                    conflict(value, old, nil,
                        action and "native-action-postcondition-failed"
                            or "native-source-missing")
                end
                recordProjectionChange(value, id, old, nil,
                    action and "native-action-postcondition-failed"
                        or "native-source-missing")
                changes = changes + 1
            end
        end
    end

    value.observationSequence = value.observationSequence + 1
    value.chunks[chunkKey] = {
        x = header.cx, y = header.cy,
        revision = header.revision,
        status = header.status,
        mode = header.mode,
        observedAt = nowHours(),
        priorRevision = priorChunk and priorChunk.revision or nil,
        sourceIds = seen,
        order = value.observationSequence,
    }
    compactChunks(value)
    return true, changes
end

-- Latest native changes waiting for the Material consumer. One source owns one
-- slot, so repeated rescans coalesce to the newest truth while its monotonic
-- order still makes acknowledgement compare-and-remove safe.
function WS.pendingProjectionChanges(limit)
    local value = store()
    if not value then return nil end
    -- A malformed/older save must not hand Kahlua's recursive table.sort an
    -- adversarially large list. The writer already trims to this ceiling; trim
    -- again at the read boundary before copying so the sorted list is bounded
    -- even when durable state was edited or interrupted outside that writer.
    if not trimProjectionChanges(value) then return nil end
    limit = math.floor(tonumber(limit) or 32)
    if limit < 1 then limit = 1 end
    if limit > 128 then limit = 128 end
    local ordered = {}
    for _, change in pairs(value.projectionChanges) do
        if #ordered >= MAX_PROJECTION_CHANGES then break end
        local copy = {}
        for key, item in pairs(change) do
            if type(item) == "string" or type(item) == "number"
                or type(item) == "boolean" then
                copy[key] = item
            end
        end
        ordered[#ordered + 1] = copy
    end
    table.sort(ordered, function(a, b)
        local ao, bo = tonumber(a.order) or 0, tonumber(b.order) or 0
        if ao ~= bo then return ao < bo end
        return tostring(a.sourceId) < tostring(b.sourceId)
    end)
    while #ordered > limit do table.remove(ordered) end
    return ordered
end

function WS.acknowledgeProjectionChange(sourceId, order)
    local value = store()
    sourceId = tostring(sourceId or "")
    local change = value and value.projectionChanges[sourceId] or nil
    if not change or tonumber(change.order) ~= tonumber(order) then
        return false
    end
    value.projectionChanges[sourceId] = nil
    return true
end

function WS.status()
    if not SAOJavaBridge then return "bridge=missing" end
    local ok, result = pcall(function()
        return SAOJavaBridge:worldSourceStatus()
    end)
    return ok and tostring(result or "") or "bridge=failed"
end

function WS.observeChunk(chunkX, chunkY)
    local allowed, why = genericObservationAllowed(chunkX, chunkY)
    if not allowed then return false, why end
    if not SAOJavaBridge then return false, "no-bridge" end
    local ok, text = pcall(function()
        return SAOJavaBridge:observeWorldChunk(chunkX, chunkY)
    end)
    if not ok then return false, "bridge-error" end
    local snapshot = WS.parse(text)
    if not snapshot then return false, "bad-protocol" end
    local accepted, changes = WS.applySnapshot(snapshot)
    return accepted, snapshot.header.status, changes
end

function WS.hydrateChunk(chunkX, chunkY)
    local allowed, why = genericObservationAllowed(chunkX, chunkY)
    if not allowed then return false, why end
    if not SAOJavaBridge then return false, "no-bridge" end
    local ok, text = pcall(function()
        return SAOJavaBridge:hydrateWorldChunk(chunkX, chunkY)
    end)
    if not ok then return false, "bridge-error" end
    local snapshot = WS.parse(text)
    if not snapshot then return false, "bad-protocol" end
    local accepted, changes = WS.applySnapshot(snapshot)
    return accepted, snapshot.header.status, changes
end

local function placeChunks(place)
    if not (place and place.minX and place.minY and place.maxX and place.maxY) then
        return nil
    end
    local minCX = math.floor(place.minX / CHUNK_SIZE)
    local minCY = math.floor(place.minY / CHUNK_SIZE)
    local maxCX = math.floor((math.max(place.minX + 1, place.maxX) - 1)
        / CHUNK_SIZE)
    local maxCY = math.floor((math.max(place.minY + 1, place.maxY) - 1)
        / CHUNK_SIZE)
    local out = {}
    for cy = minCY, maxCY do
        for cx = minCX, maxCX do
            out[#out + 1] = { x = cx, y = cy }
        end
    end
    return out
end

-- Demand is building-bounded and sequential. A failed/busy chunk remains
-- unknown and is retried by the next real search; partial observations are
-- still exact, but the place is not marked complete.
function WS.demandPlace(place)
    local chunks = placeChunks(place)
    local value = store()
    if not chunks or not value then return false, "bad-place" end
    local complete, last = true, "HYDRATED"
    local observed = {}
    for _, chunk in ipairs(chunks) do
        local ok, status = WS.hydrateChunk(chunk.x, chunk.y)
        observed[chunk.x .. ":" .. chunk.y] = ok and true or false
        if not ok then complete, last = false, status end
    end
    value.places[tostring(place.id)] = {
        complete = complete,
        chunks = observed,
        observedAt = nowHours(),
        source = "observed",
        provenance = "native-hydration",
        order = value.observationSequence,
    }
    compactPlaces(value)
    return complete, last
end

local function availableFrom(value, source, category)
    local quantity = tonumber(source.quantities
        and source.quantities[category]) or 0
    if source.state ~= "available" or source.access ~= "accessible"
        or quantity <= 0 then return 0 end
    -- The optimistic lock is source-revision wide. Two exact items in one
    -- container cannot both remain valid after either commit changes that
    -- revision, so a source has one in-flight owner at a time.
    if pendingFor(value, source.id, nil) then return 0 end
    return quantity
end

local function sourceBelongsToPlace(source, place)
    if not source or not place or place.id == nil then return false end
    if source.buildingId == tostring(place.id) then return true end
    -- Vehicles have no BuildingDef even when they stand inside the bounded
    -- place an actor just observed. Keep their exact moving identity in that
    -- private observation so final access can ask the vehicle part itself.
    return source.kind == "vehicle" and place.minX and place.minY
        and place.maxX and place.maxY
        and source.x >= place.minX and source.x < place.maxX
        and source.y >= place.minY and source.y < place.maxY
end

local function beliefFact(source)
    if not source then return nil end
    local fact = {
        id = source.id, fingerprint = source.fingerprint,
        revision = source.revision, kind = source.kind,
        x = source.x, y = source.y, z = source.z,
        chunkX = source.chunkX, chunkY = source.chunkY,
        buildingId = source.buildingId, explored = source.explored,
        state = source.state, access = source.access,
        container = source.container, quantities = {}, candidates = {},
    }
    for category, quantity in pairs(source.quantities or {}) do
        fact.quantities[category] = quantity
    end
    for _, key in ipairs(source.itemOrder or {}) do
        local item = source.items and source.items[key] or nil
        if item then
            for category, present in pairs(item.categories or {}) do
                if present and not fact.candidates[category] then
                    fact.candidates[category] = {
                        id = item.id, type = item.type, uses = item.uses,
                        amount = item.amount,
                        categories = { [category] = true },
                    }
                end
            end
        end
    end
    return fact
end

local function quantitiesAt(place, requireAccess)
    local value = store()
    local out = {}
    if not value or not place or place.id == nil then return out end
    for _, source in pairs(value.sources) do
        if sourceBelongsToPlace(source, place) and source.state == "available" then
            for category in pairs(source.quantities or {}) do
                local quantity = tonumber(source.quantities[category]) or 0
                if requireAccess then
                    quantity = availableFrom(value, source, category)
                end
                if quantity > 0 then
                    out[category] = (out[category] or 0) + quantity
                end
            end
        end
    end
    return out
end

-- Observed stock and executable availability are deliberately different.
-- Native hydration can establish the former. Only a later actor-specific
-- path/permission producer may mark a source accessible and establish the latter.
function WS.observedAt(place)
    return quantitiesAt(place, false)
end

function WS.availableAt(place)
    return quantitiesAt(place, true)
end

function WS.beliefSnapshot(place)
    local categoriesNow = WS.observedAt(place)
    local accessibleNow = WS.availableAt(place)
    local categoriesOut, accessOut, revisions, facts = {}, {}, {}, {}
    for category, quantity in pairs(categoriesNow) do
        if quantity > 0 then categoriesOut[category] = true end
    end
    for category, quantity in pairs(accessibleNow) do
        if quantity > 0 then accessOut[category] = true end
    end
    local value = store()
    if value and place and place.id ~= nil then
        for id, source in pairs(value.sources) do
            if sourceBelongsToPlace(source, place) then
                facts[id] = beliefFact(source)
                local entry = id .. "@" .. tostring(source.revision)
                -- Kahlua's table.sort recurses on input order. Insert this
                -- building's source revisions iteratively so a large or
                -- adversarially ordered building cannot exhaust its stack.
                local at = #revisions + 1
                while at > 1 and revisions[at - 1] > entry do
                    revisions[at] = revisions[at - 1]
                    at = at - 1
                end
                revisions[at] = entry
            end
        end
    end
    return categoriesOut, table.concat(revisions, ","), accessOut, facts
end


function WS.beliefFact(sourceId)
    local value = store()
    return value and beliefFact(value.sources[tostring(sourceId or "")]) or nil
end

function WS.nearestBelieved(id, x, y, category, horizon)
    if not (SAO.Perception and SAO.Perception.knownPlaces) then return nil end
    local known = SAO.Perception.knownPlaces(id)
    local best, bestDistance = nil, nil
    local limit = (tonumber(horizon) or 0) ^ 2
    for placeId, belief in pairs(known) do
        if belief.sources and belief.sources[category]
            and belief.sourceAccess and belief.sourceAccess[category] then
            local dx, dy = (belief.cx or 0) - x, (belief.cy or 0) - y
            local distance = dx * dx + dy * dy
            if distance <= limit and (not bestDistance or distance < bestDistance) then
                local place = nil
                pcall(function() place = SAO.Places.at(belief.cx, belief.cy) end)
                if place and tostring(place.id) == tostring(placeId) then
                    best, bestDistance = place, distance
                end
            end
        end
    end
    return best
end

-- A private observation may motivate an attempt without pretending it already
-- proved access. This is deliberately separate from nearestBelieved, whose
-- callers require a source that was already executable.
function WS.nearestObserved(id, x, y, category, horizon)
    if not (SAO.Perception and SAO.Perception.knownPlaces) then return nil end
    local known = SAO.Perception.knownPlaces(id)
    local best, bestDistance = nil, nil
    local limit = (tonumber(horizon) or 0) ^ 2
    for placeId, belief in pairs(known) do
        if belief.sources and belief.sources[category]
            and type(belief.sourceRevision) == "string"
            and belief.sourceRevision ~= "" then
            local dx, dy = (belief.cx or 0) - x, (belief.cy or 0) - y
            local distance = dx * dx + dy * dy
            if distance <= limit and (not bestDistance or distance < bestDistance) then
                local place = nil
                pcall(function() place = SAO.Places.at(belief.cx, belief.cy) end)
                if place and tostring(place.id) == tostring(placeId) then
                    best, bestDistance = place, distance
                end
            end
        end
    end
    return best
end

local function beliefHasRevision(belief, sourceId, revision)
    local wanted = tostring(sourceId) .. "@" .. tostring(revision)
    for entry in string.gmatch(tostring(belief and belief.sourceRevision or ""),
        "[^,]+") do
        if entry == wanted then return true end
    end
    return false
end

local function categoryItem(source, category, wanted)
    if source.candidates then
        local item = source.candidates[category]
        if item then
            local quantity = (category == "water" or category == "drink")
                and item.amount > 0 and item.amount or 1
            if quantity >= wanted then return item, wanted end
        end
        return nil
    end
    for _, itemKey in ipairs(source.itemOrder or {}) do
        local item = source.items[itemKey]
        if item and item.categories and item.categories[category] then
            local quantity = (category == "water" or category == "drink")
                and item.amount > 0 and item.amount or 1
            if quantity >= wanted then return item, wanted end
        end
    end
    return nil
end

-- Options describe attempts over this person's own observations. The caller
-- has already selected the place/category under its need and ration policy.
-- Neither listing nor selecting an option proves current physical access.
function WS.actionOptions(place, category, actorId, body, quantity, admission)
    local value = store()
    actorId = actorId and tostring(actorId) or nil
    category = tostring(category or "")
    if category ~= "food" and category ~= "water" then
        return nil, "unsupported-category"
    end
    if not value or not place or place.id == nil or not actorId or not body then
        return nil, "bad-request"
    end
    local record = SAO.Identity and SAO.Identity.get
        and SAO.Identity.get(actorId) or nil
    local live = SAO.Body and SAO.Body.get and SAO.Body.get(actorId) or nil
    if not record or record.dead or live ~= body then return nil, "no-live-body" end
    if record.worldSourceReservation then return nil, "already-pending" end
    admission = tostring(admission or "standing")
    local standingPermits = SAO.Standing and SAO.Standing.mayAttemptBelieved
        and SAO.Standing.mayAttemptBelieved(actorId, place.cx, place.cy,
            admission)
    if not standingPermits then
        return nil, "standing-refused"
    end
    local known = SAO.Perception and SAO.Perception.knownPlaces
        and SAO.Perception.knownPlaces(actorId) or nil
    local belief = known and (known[place.id] or known[tostring(place.id)]) or nil
    if not (belief and belief.sources and belief.sources[category]) then
        return nil, "not-privately-observed"
    end
    quantity = tonumber(quantity) or 1
    if quantity <= 0 or quantity ~= quantity or quantity == math.huge then
        return nil, "bad-quantity"
    end
    local reservationCount = 0
    for _, reservation in pairs(value.reservations) do
        if reservation.status == "reserved" then
            reservationCount = reservationCount + 1
        end
    end
    if reservationCount >= MAX_RESERVATIONS then return nil, "reservation-bound" end
    local durableInputs = reservationCount
    for _, receipt in pairs(value.results) do
        local acknowledgements = receipt.acknowledgements or {}
        if receipt.status == "completed"
            and not acknowledgements[RESULT_CONSUMER] then
            durableInputs = durableInputs + 1
        end
    end
    if durableInputs >= MAX_RESULTS then return nil, "result-bound" end

    local offered = {
        schemaVersion = 1, actorId = actorId, category = category,
        quantity = quantity, admission = admission, atHours = nowHours(),
        place = { id = place.id, cx = place.cx, cy = place.cy,
            minX = place.minX, minY = place.minY,
            maxX = place.maxX, maxY = place.maxY },
        scope = "selected-place-and-need", options = {}, candidateCount = 0,
        limit = MAX_ACTION_OPTIONS,
    }
    for id, source in pairs(belief.sourceFacts or {}) do
        local observed = tonumber(source.quantities
            and source.quantities[category]) or 0
        if sourceBelongsToPlace(source, place) and source.state == "available"
            and observed >= quantity and not pendingFor(value, id, nil)
            and beliefHasRevision(belief, id, source.revision) then
            local item, amount = categoryItem(source, category, quantity)
            if item and item.id ~= 0 then
                offered.candidateCount = offered.candidateCount + 1
                local option = {
                    id = tostring(id), owner = "SAO.SourceUse",
                    parameters = {
                        action = "attempt-source-use", actorId = actorId,
                        placeId = tostring(place.id), category = category,
                        admission = admission, quantity = amount,
                        sourceId = source.id, sourceKind = source.kind,
                        sourceX = source.x, sourceY = source.y, sourceZ = source.z,
                        chunkX = source.chunkX, chunkY = source.chunkY,
                        fingerprint = source.fingerprint, revision = source.revision,
                        itemId = item.id, itemType = item.type,
                        itemAmount = tonumber(item.amount) or 0,
                        itemUses = tonumber(item.uses) or 0,
                    },
                    eligibility = { status = "eligible", evidence = {
                        { kind = "private-source-revision", actorId = actorId,
                            sourceId = source.id, revision = source.revision,
                            beliefAtTick = belief.at, provenance = belief.source },
                        { kind = "attempt-admission", admission = admission,
                            atHours = offered.atHours,
                            physicalAccess = "revalidate-on-arrival" },
                    } },
                }
                -- Keep the same stable first-source policy with a bounded
                -- offered set, independent of Lua map iteration order.
                local at = #offered.options + 1
                while at > 1 and offered.options[at - 1].id > option.id do
                    at = at - 1
                end
                if at <= MAX_ACTION_OPTIONS then
                    table.insert(offered.options, at, option)
                    if #offered.options > MAX_ACTION_OPTIONS then
                        table.remove(offered.options)
                    end
                end
            end
        end
    end
    if #offered.options == 0 then return nil, "observed-revision-unavailable" end
    offered.truncated = offered.candidateCount > #offered.options
    return offered
end

local function sameActionOption(left, right)
    if type(left) ~= "table" or type(left.parameters) ~= "table"
        or left.id ~= right.id or left.owner ~= right.owner then return false end
    for key, value in pairs(right.parameters) do
        if left.parameters[key] ~= value then return false end
    end
    for key, value in pairs(left.parameters) do
        if right.parameters[key] ~= value then return false end
    end
    return true
end

-- Re-enumerate the actor's current eligible attempts before reserving. A
-- changed or forged selected descriptor is refused; a different source is
-- never silently substituted. The omitted selection retains the legacy API.
function WS.beginAction(place, category, actorId, body, quantity, admission, selected)
    local offered, why = WS.actionOptions(place, category, actorId, body,
        quantity, admission)
    if not offered then return nil, why end
    local option = offered.options[1]
    if selected ~= nil then
        option = nil
        for _, candidate in ipairs(offered.options) do
            if sameActionOption(selected, candidate) then option = candidate; break end
        end
        if not option then return nil, "selected-option-changed" end
    end
    local value = store()
    if not value then return nil, "store-unavailable" end
    actorId = tostring(actorId)
    local record = SAO.Identity.get(actorId)
    local parameters = option.parameters

    value.sequence = value.sequence + 1
    local reservationId = "R:" .. value.sequence .. ":" .. actorId
    local reservation = {
        id = reservationId, actorId = actorId, placeId = tostring(place.id),
        placeX = place.cx, placeY = place.cy, placeZ = 0,
        placeMinX = place.minX, placeMinY = place.minY,
        placeMaxX = place.maxX, placeMaxY = place.maxY,
        sourceId = parameters.sourceId,
        sourceKind = parameters.sourceKind,
        sourceX = parameters.sourceX, sourceY = parameters.sourceY,
        sourceZ = parameters.sourceZ,
        chunkX = parameters.chunkX, chunkY = parameters.chunkY,
        fingerprint = parameters.fingerprint,
        revision = parameters.revision,
        preRevision = parameters.revision,
        itemId = parameters.itemId,
        itemType = parameters.itemType,
        itemAmount = parameters.itemAmount,
        itemUses = parameters.itemUses,
        useTargetQuantity = category == "water"
            and (parameters.itemAmount * 0.5) or 1,
        category = category, quantity = parameters.quantity,
        admission = offered.admission,
        status = "reserved", phase = "approaching-place",
        reservedAt = nowHours(),
    }
    value.reservations[reservationId] = reservation
    record.worldSourceReservation = reservationId
    return reservation
end

function WS.reservation(reservationId)
    local value = store()
    return value and value.reservations[tostring(reservationId or "")] or nil
end

-- The record pointer is a join, not authority by itself. Repair missing,
-- terminal or cross-actor joins at every representation boundary so corrupt
-- save data cannot freeze a person forever. Keep a small durable diagnostic.
function WS.pendingActionFor(actorId)
    actorId = tostring(actorId or "")
    local record = SAO.Identity and SAO.Identity.get
        and SAO.Identity.get(actorId) or nil
    local pointer = record and record.worldSourceReservation or nil
    if not pointer then return nil end
    pointer = tostring(pointer)
    local value = store()
    if not value then
        -- A newer or temporarily unreadable ledger remains opaque authority.
        -- Downgrade code may not clear its join or let body/dormant/controller
        -- execution advance as though the action did not exist.
        return { id = pointer, actorId = actorId, status = "unavailable",
            phase = "unavailable", unavailable = true }
    end
    local reservation = value.reservations[pointer]
    if reservation and reservation.status == "reserved"
        and reservation.actorId == actorId then return reservation end
    record.worldSourceReservation = nil
    value.pointerRepairSequence = value.pointerRepairSequence + 1
    local key = tostring(value.pointerRepairSequence)
    value.pointerRepairs[key] = {
        actorId = actorId,
        reservationId = pointer,
        reason = not reservation and "missing"
            or reservation.status ~= "reserved" and "terminal"
            or "owner-mismatch",
        at = nowHours(),
        order = value.pointerRepairSequence,
    }
    local count = 0
    for _ in pairs(value.pointerRepairs) do count = count + 1 end
    while count > MAX_POINTER_REPAIRS do
        local oldestKey, oldest = nil, nil
        for repairKey, repair in pairs(value.pointerRepairs) do
            if not oldest or (repair.order or 0) < (oldest.order or 0) then
                oldestKey, oldest = repairKey, repair
            end
        end
        if not oldestKey then break end
        value.pointerRepairs[oldestKey] = nil
        count = count - 1
    end
    log("repaired stale action pointer " .. actorId .. " -> " .. pointer)
    return nil
end

-- Representation-independent ownership query for every bodyless simulator.
-- The pending-action reader also preserves opaque future-schema authority.
function WS.ownsActor(actorId)
    return WS.pendingActionFor(actorId) ~= nil
end

function WS.setPhase(reservationId, actorId, phase)
    local reservation = WS.reservation(reservationId)
    if not reservation or reservation.status ~= "reserved"
        or reservation.actorId ~= tostring(actorId) then return false end
    reservation.phase = tostring(phase or "")
    reservation.phaseAt = nowHours()
    return reservation.phase ~= ""
end

function WS.markTransferred(reservationId, actorId)
    local reservation = WS.reservation(reservationId)
    if not reservation or reservation.status ~= "reserved"
        or reservation.actorId ~= tostring(actorId) then return false end
    reservation.transferProven = true
    reservation.transferAt = nowHours()
    return true
end

-- The private belief stays compact. After Java has rebound the exact current
-- revision, take the full pre-item signature set from the global observation
-- only when it still matches that private revision. This cannot reveal a newer
-- state or change selection; it supplies the optimistic postcondition.
function WS.prepareActionPre(reservationId, actorId)
    local value = store()
    local reservation = value and value.reservations[tostring(reservationId or "")]
    local source = reservation and value.sources[reservation.sourceId] or nil
    if not reservation or reservation.status ~= "reserved"
        or reservation.actorId ~= tostring(actorId)
        or value.conflictBySource[reservation.sourceId]
        or not source or source.fingerprint ~= reservation.fingerprint
        or source.revision ~= reservation.preRevision
        or source.kind ~= reservation.sourceKind then return false end
    local item = source.items and source.items[tostring(reservation.itemId)] or nil
    if not item or item.type ~= reservation.itemType then return false end
    reservation.preItems = itemSignatures(source)
    return reservation.preItems[tostring(reservation.itemId)] ~= nil
end

local function result(value, reservation, status, detail)
    reservation.status = status
    reservation.resultAt = nowHours()
    reservation.detail = detail
    value.resultSequence = value.resultSequence + 1
    local options = SandboxVars and SandboxVars.SurvivorAwareness or nil
    local receipt = {
        reservationId = reservation.id,
        actorId = reservation.actorId,
        placeId = reservation.placeId,
        placeX = reservation.placeX,
        placeY = reservation.placeY,
        placeZ = reservation.placeZ,
        placeMinX = reservation.placeMinX,
        placeMinY = reservation.placeMinY,
        placeMaxX = reservation.placeMaxX,
        placeMaxY = reservation.placeMaxY,
        sourceId = reservation.sourceId,
        sourceFingerprint = reservation.fingerprint,
        sourceKind = reservation.sourceKind,
        sourceX = reservation.currentSourceX or reservation.sourceX,
        sourceY = reservation.currentSourceY or reservation.sourceY,
        sourceZ = reservation.currentSourceZ or reservation.sourceZ,
        itemId = reservation.itemId,
        itemType = reservation.itemType,
        category = reservation.category,
        provisioningGroup = reservation.provisioningGroup,
        provisioningContext = reservation.provisioningContext,
        provisioningClaimIncarnation =
            reservation.provisioningClaimIncarnation,
        materialProjectionEnabled = not options or options.Material ~= false,
        quantity = reservation.actualQuantity or reservation.quantity,
        requestedQuantity = reservation.quantity,
        observedQuantity = reservation.actualQuantity,
        preRevision = reservation.preRevision or reservation.revision,
        postRevision = reservation.postRevision,
        status = status,
        detail = detail,
        at = reservation.resultAt,
        order = value.resultSequence,
        acknowledgements = {},
    }
    value.results[reservation.id] = receipt
    value.resultByActor[reservation.actorId] = reservation.id
    value.resultCounts[status] = (tonumber(value.resultCounts[status]) or 0) + 1
    trimResults(value)
    local record = SAO.Identity and SAO.Identity.get
        and SAO.Identity.get(reservation.actorId) or nil
    if record and record.worldSourceReservation == reservation.id then
        record.worldSourceReservation = nil
    end
    return receipt
end

local function receiptCopy(receipt)
    return {
        reservationId = receipt.reservationId,
        actorId = receipt.actorId,
        placeId = receipt.placeId,
        placeX = receipt.placeX,
        placeY = receipt.placeY,
        placeZ = receipt.placeZ,
        placeMinX = receipt.placeMinX,
        placeMinY = receipt.placeMinY,
        placeMaxX = receipt.placeMaxX,
        placeMaxY = receipt.placeMaxY,
        sourceId = receipt.sourceId,
        sourceFingerprint = receipt.sourceFingerprint,
        sourceKind = receipt.sourceKind,
        sourceX = receipt.sourceX,
        sourceY = receipt.sourceY,
        sourceZ = receipt.sourceZ,
        itemId = receipt.itemId,
        itemType = receipt.itemType,
        category = receipt.category,
        provisioningGroup = receipt.provisioningGroup,
        provisioningContext = receipt.provisioningContext,
        provisioningClaimIncarnation = receipt.provisioningClaimIncarnation,
        materialProjectionEnabled = receipt.materialProjectionEnabled,
        quantity = receipt.quantity,
        preRevision = receipt.preRevision,
        postRevision = receipt.postRevision,
        status = receipt.status,
        detail = receipt.detail,
        at = receipt.at,
        order = receipt.order,
    }
end

-- A detached result for a single observed action. Evidence readers do not
-- acknowledge provisioning or hold ledger rows alive. Missing/older receipts
-- are explicitly unavailable, so a bounded ledger cannot look like success.
function WS.actionOutcome(reservationId, actorId)
    local value = store()
    if not value then return nil, "store-unavailable" end
    reservationId, actorId = tostring(reservationId or ""), tostring(actorId or "")
    local receipt = value.results[reservationId]
    if receipt and receipt.actorId == actorId then
        local outcome = receiptCopy(receipt)
        outcome.quantity = nil
        outcome.requestedQuantity = receipt.requestedQuantity
        outcome.observedQuantity = receipt.observedQuantity
        outcome.measurement = receipt.observedQuantity ~= nil
            and "native-use" or "not-recorded"
        return outcome
    end
    local reservation = value.reservations[reservationId]
    if reservation and reservation.actorId == actorId
        and reservation.status == "reserved" then
        return { reservationId = reservationId, actorId = actorId,
            status = "pending", phase = reservation.phase,
            sourceId = reservation.sourceId, itemId = reservation.itemId,
            at = nowHours() }
    end
    return nil, "result-not-retained"
end

-- Provisioning is the sole R9 owner of this bridge. It receives stable ordered
-- copies and acknowledges idempotently, so a downstream consumer cannot mutate
-- the ledger and reload delivery order cannot drift with Lua table iteration.
function WS.completedResults(consumer)
    local value = store()
    local out = {}
    consumer = tostring(consumer or "")
    if not value or consumer ~= RESULT_CONSUMER then return out end
    for _, receipt in pairs(value.results) do
        local acknowledgements = receipt.acknowledgements or {}
        if receipt.status == "completed" and not acknowledgements[consumer] then
            local copy = receiptCopy(receipt)
            -- Kahlua's recursive table.sort is unsafe at this ledger's
            -- advertised 2,048-result bound. Insert each bounded scalar copy
            -- iteratively by durable sequence, with identity as the tie break.
            local at = #out + 1
            while at > 1 do
                local prior = out[at - 1]
                local copyOrder = copy.order or 0
                local priorOrder = prior.order or 0
                local before = copyOrder < priorOrder
                    or (copyOrder == priorOrder
                        and tostring(copy.reservationId)
                            < tostring(prior.reservationId))
                if not before then break end
                out[at] = prior
                at = at - 1
            end
            out[at] = copy
        end
    end
    return out
end

function WS.acknowledgeResult(reservationId, consumer, reason)
    local value = store()
    consumer = tostring(consumer or "")
    local receipt = value and value.results[tostring(reservationId or "")]
    if not receipt or receipt.status ~= "completed"
        or consumer ~= RESULT_CONSUMER then
        return false
    end
    receipt.acknowledgements = receipt.acknowledgements or {}
    if receipt.acknowledgements[consumer] then return true end
    receipt.acknowledgements[consumer] = {
        at = nowHours(),
        reason = tostring(reason or "consumed"),
    }
    return true
end

function WS.resultAcknowledged(reservationId, consumer)
    local value = store()
    local receipt = value and value.results[tostring(reservationId or "")] or nil
    consumer = tostring(consumer or "")
    return type(receipt) == "table" and consumer ~= ""
        and type(receipt.acknowledgements) == "table"
        and receipt.acknowledgements[consumer] ~= nil
end

function WS.release(reservationId, reason)
    local value = store()
    local reservation = value and value.reservations[reservationId]
    if not reservation or reservation.status ~= "reserved" then return false end
    result(value, reservation, "released", tostring(reason or "interrupted"))
    return true
end

function WS.failAction(reservationId, actorId, reason)
    local value = store()
    local reservation = value and value.reservations[tostring(reservationId or "")]
    if not reservation or reservation.status ~= "reserved"
        or reservation.actorId ~= tostring(actorId) then return false end
    result(value, reservation, "conflict", tostring(reason or "action-refused"))
    return true
end

-- The native action wrapper calls this exactly once after vanilla complete or
-- stop. A stopped action that changed the item/body is durable interruption;
-- it never receives survival credit.
function WS.markNative(reservationId, actorId, status, quantity, detail)
    local reservation = WS.reservation(reservationId)
    if not reservation or reservation.status ~= "reserved"
        or reservation.actorId ~= tostring(actorId)
        or reservation.phase == "native-complete" then return false end
    if status ~= "completed" and status ~= "interrupted" then return false end
    reservation.phase = "native-complete"
    reservation.nativeStatus = status
    reservation.actualQuantity = math.max(0, tonumber(quantity) or 0)
    reservation.nativeDetail = tostring(detail or "native-use")
    reservation.phaseAt = nowHours()
    return true
end

-- Admit a post-source observation only when it is the exact expected delta
-- for this transfer. A successful scan of some other chunk cannot close the
-- reservation, and a conflict is reported to the executor rather than waited
-- on forever.
function WS.reconcileActionSnapshot(reservationId, actorId, chunkX, chunkY)
    local value = store()
    local reservation = value and value.reservations[tostring(reservationId or "")]
    if not reservation or reservation.status ~= "reserved"
        or reservation.actorId ~= tostring(actorId)
        or reservation.phase ~= "native-complete" then
        return false, "reservation-lost"
    end
    if value.conflictBySource[reservation.sourceId] then
        return false, "native-source-conflict"
    end
    chunkX, chunkY = tonumber(chunkX), tonumber(chunkY)
    if reservation.sourceKind == "ground" then
        if chunkX ~= tonumber(reservation.chunkX)
            or chunkY ~= tonumber(reservation.chunkY) then
            return false, "wrong-source-chunk"
        end
        if value.sources[reservation.sourceId] ~= nil
            or not expectedGroundRemoval(reservation) then
            return false, "post-delta-not-observed"
        end
        reservation.postRevision = "removed"
    else
        local post = value.sources[reservation.sourceId]
        if not post or post.chunkX ~= chunkX or post.chunkY ~= chunkY
            or not expectedActionPost(reservation, post) then
            return false, "post-delta-not-observed"
        end
        reservation.postRevision = post.revision
        reservation.currentSourceX = post.x
        reservation.currentSourceY = post.y
        reservation.currentSourceZ = post.z
    end
    reservation.reconciledAt = nowHours()
    return true
end

-- Publish the result only after a fresh native source observation has been
-- applied with this reservation as its optimistic-lock exception.
function WS.finishAction(reservationId, actorId)
    local value = store()
    local reservation = value and value.reservations[tostring(reservationId or "")]
    if not reservation or reservation.status ~= "reserved"
        or reservation.actorId ~= tostring(actorId)
        or reservation.phase ~= "native-complete"
        or not reservation.postRevision then return nil end
    local receipt = result(value, reservation, reservation.nativeStatus,
        reservation.nativeDetail)
    if receipt and receipt.status == "completed" then
        local record = SAO.Identity and SAO.Identity.get
            and SAO.Identity.get(reservation.actorId) or nil
        local today = math.floor(nowHours() / 24.0)
        if record and reservation.category == "food" then
            record.lastFoodDay = today
        elseif record and reservation.category == "water" then
            record.lastWaterDay = today
        end
    end
    return receipt
end

-- Release only genuinely orphaned reservations after load. A record that
-- still names its reservation owns it across a save/reload and may continue.
function WS.reconcileReservations()
    local value = store()
    if not value or not (SAO.Identity and SAO.Identity.get) then return 0 end
    local released = 0
    for id, reservation in pairs(value.reservations) do
        if reservation.status == "reserved" then
            local record = SAO.Identity.get(reservation.actorId)
            if not record or record.dead
                or record.worldSourceReservation ~= id then
                result(value, reservation, "released", "orphaned")
                if record and record.worldSourceReservation == id then
                    record.worldSourceReservation = nil
                end
                released = released + 1
            end
        end
    end
    return released
end

function WS.observeAt(x, y, radius)
    x, y, radius = tonumber(x), tonumber(y), tonumber(radius) or 0
    if not x or not y then return 0 end
    local changes = 0
    local minCX = math.floor((x - radius) / CHUNK_SIZE)
    local maxCX = math.floor((x + radius) / CHUNK_SIZE)
    local minCY = math.floor((y - radius) / CHUNK_SIZE)
    local maxCY = math.floor((y + radius) / CHUNK_SIZE)
    for cy = minCY, maxCY do
        for cx = minCX, maxCX do
            local ok, _, changed = WS.observeChunk(cx, cy)
            if ok then changes = changes + (changed or 0) end
        end
    end
    return changes
end

function WS.source(id)
    local value = store()
    if not value then return nil end
    id = tostring(id)
    return value.sources[id] or value.conflictBySource[id]
end

-- R9 receives an isolated scalar copy of the latest observed native source.
-- The durable WorldSources table remains the authority: material projection
-- may retain this copy, but it cannot mutate or alias the observation ledger.
-- A conflicted source is withheld until native observation resolves it.
function WS.sourceProjection(id)
    local value = store()
    if not value then return nil, "store-unavailable" end
    id = tostring(id or "")
    if value.conflictBySource[id] then return nil, "source-conflict" end
    local source = value.sources[id]
    if not source then return nil, "source-absent" end
    local copy = {
        id = source.id,
        fingerprint = source.fingerprint,
        revision = source.revision,
        kind = source.kind,
        x = source.x, y = source.y, z = source.z,
        chunkX = source.chunkX, chunkY = source.chunkY,
        buildingId = source.buildingId,
        explored = source.explored and true or false,
        state = source.state,
        access = source.access,
        container = source.container,
        observedAt = source.observedAt,
        provenance = source.provenance,
        quantities = {}, items = {}, itemOrder = {},
    }
    for _, category in ipairs(SOURCE_CATEGORY_ORDER) do
        local quantity = tonumber(source.quantities
            and source.quantities[category]) or 0
        if quantity > 0 then copy.quantities[category] = quantity end
    end
    for _, itemKey in ipairs(source.itemOrder or {}) do
        local item = source.items and source.items[itemKey] or nil
        if item then
            local categoriesCopy = {}
            for _, category in ipairs(SOURCE_CATEGORY_ORDER) do
                if item.categories and item.categories[category] then
                    categoriesCopy[category] = true
                end
            end
            local key = tostring(item.id)
            copy.items[key] = {
                id = item.id,
                type = item.type,
                uses = item.uses,
                amount = item.amount,
                fluid = item.fluid,
                poison = item.poison and true or false,
                rotten = item.rotten and true or false,
                categories = categoriesCopy,
            }
            copy.itemOrder[#copy.itemOrder + 1] = key
        end
    end
    return copy, "observed"
end

function WS.resetRuntime()
    loadedSeen = {}
    pendingLoads = {}
    loadTick = 0
end

if Events and Events.LoadGridsquare then
    if WS.onLoadGridSquare then Events.LoadGridsquare.Remove(WS.onLoadGridSquare) end
    WS.onLoadGridSquare = function(square)
        if not square then return end
        local cx, cy = nil, nil
        pcall(function()
            cx = math.floor(square:getX() / CHUNK_SIZE)
            cy = math.floor(square:getY() / CHUNK_SIZE)
        end)
        if not cx then return end
        local key = cx .. ":" .. cy
        if loadedSeen[key] then return end
        if not pendingLoads[key] then
            local count = 0
            for _ in pairs(pendingLoads) do count = count + 1 end
            if count >= MAX_PENDING_LOADS then
                log("loaded observation queue full at " .. key)
                return
            end
            -- LoadGridsquare is per-square and can fire before the chunk's
            -- main-thread load phase has finished. Observe on a later tick.
            pendingLoads[key] = { x = cx, y = cy, due = loadTick + 2,
                attempts = 0 }
        end
    end
    Events.LoadGridsquare.Add(WS.onLoadGridSquare)
end

function WS.processLoadedObservations()
    loadTick = loadTick + 1
    local handled = 0
    for key, request in pairs(pendingLoads) do
        if handled < 4 and loadTick >= (request.due or 0) then
            handled = handled + 1
            local ok, status = WS.observeChunk(request.x, request.y)
            if ok then
                loadedSeen[key] = true
                pendingLoads[key] = nil
            else
                request.attempts = (request.attempts or 0) + 1
                request.lastStatus = status
                request.due = loadTick + math.min(60,
                    2 + request.attempts * 2)
            end
        end
    end
    return handled
end

if Events and Events.OnTick then
    if WS.onWorldSourcesTick then Events.OnTick.Remove(WS.onWorldSourcesTick) end
    WS.onWorldSourcesTick = function() WS.processLoadedObservations() end
    Events.OnTick.Add(WS.onWorldSourcesTick)
end

if Events and Events.ReuseGridsquare then
    if WS.onReuseGridSquare then Events.ReuseGridsquare.Remove(WS.onReuseGridSquare) end
    WS.onReuseGridSquare = function(square)
        if not square then return end
        local ok, x, y = pcall(function()
            return square:getX(), square:getY()
        end)
        if ok and x and y then
            local key = math.floor(x / CHUNK_SIZE) .. ":"
                .. math.floor(y / CHUNK_SIZE)
            loadedSeen[key] = nil
            pendingLoads[key] = nil
        end
    end
    Events.ReuseGridsquare.Add(WS.onReuseGridSquare)
end

if Events and Events.OnInitGlobalModData then
    if WS.onInitGlobalModData then
        Events.OnInitGlobalModData.Remove(WS.onInitGlobalModData)
    end
    WS.onInitGlobalModData = function()
        WS.resetRuntime()
        WS.reconcileReservations()
    end
    Events.OnInitGlobalModData.Add(WS.onInitGlobalModData)
end

return WS
