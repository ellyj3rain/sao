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

local function store()
    local ok, value = pcall(function()
        return ModData.getOrCreate(STORE_KEY)
    end)
    if not ok or type(value) ~= "table" then return nil end
    value.schema = 2
    value.sources = value.sources or {}
    value.chunks = value.chunks or {}
    value.places = value.places or {}
    value.reservations = value.reservations or {}
    value.results = value.results or {}
    value.resultByActor = value.resultByActor or {}
    value.resultCounts = value.resultCounts or {}
    value.conflicts = value.conflicts or {}
    value.conflictBySource = value.conflictBySource or {}
    value.sequence = tonumber(value.sequence) or 0
    value.observationSequence = tonumber(value.observationSequence) or 0
    value.conflictSequence = tonumber(value.conflictSequence) or 0
    value.resultSequence = tonumber(value.resultSequence) or 0
    return value
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
    local out = {}
    for name in string.gmatch(tostring(value or ""), "[^,]+") do
        out[name] = true
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
                local item = {
                    id = tonumber(raw.id) or 0,
                    type = raw.type or "",
                    uses = tonumber(raw.uses) or 0,
                    amount = tonumber(raw.amount) or 0,
                    fluid = raw.fluid or "",
                    poison = tonumber(raw.poison) == 1,
                    rotten = tonumber(raw.rotten) == 1,
                    categories = categories(raw.cats),
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
        if reservation.status == "reserved"
            and reservation.chunkX == chunk.x and reservation.chunkY == chunk.y then
            return true
        end
    end
    return false
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
            conflict(value, priorConflict, observed, priorConflict.reason)
            changes = changes + 1
        elseif old and old.fingerprint ~= observed.fingerprint then
            value.sources[nativeSource.id] = nil
            conflict(value, old, observed, "physical-fingerprint-changed")
            changes = changes + 1
        elseif old and old.revision ~= observed.revision
            and pendingFor(value, nativeSource.id, exceptReservationId) then
            value.sources[nativeSource.id] = nil
            conflict(value, old, observed,
                "native-revision-changed-during-reservation")
            changes = changes + 1
        else
            if not old or old.revision ~= observed.revision
                or old.state ~= observed.state then
                changes = changes + 1
            end
            value.sources[nativeSource.id] = observed
        end
    end

    -- A complete scan that no longer contains a formerly observed identity is
    -- removal/movement, not empty stock. Keep a small bounded conflict receipt,
    -- not a duplicate of the vanished native inventory.
    for id in pairs((priorChunk and priorChunk.sourceIds) or {}) do
        local old = value.sources[id]
        if old and not seen[id] then
            value.sources[id] = nil
            conflict(value, old, nil, "native-source-missing")
            changes = changes + 1
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

function WS.status()
    if not SAOJavaBridge then return "bridge=missing" end
    local ok, result = pcall(function()
        return SAOJavaBridge:worldSourceStatus()
    end)
    return ok and tostring(result or "") or "bridge=failed"
end

function WS.observeChunk(chunkX, chunkY)
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

local function quantitiesAt(place, requireAccess)
    local value = store()
    local out = {}
    if not value or not place or place.id == nil then return out end
    local building = tostring(place.id)
    for _, source in pairs(value.sources) do
        if source.buildingId == building and source.state == "available" then
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
    local categoriesOut, accessOut, revisions = {}, {}, {}
    for category, quantity in pairs(categoriesNow) do
        if quantity > 0 then categoriesOut[category] = true end
    end
    for category, quantity in pairs(accessibleNow) do
        if quantity > 0 then accessOut[category] = true end
    end
    local value = store()
    if value and place and place.id ~= nil then
        local building = tostring(place.id)
        for id, source in pairs(value.sources) do
            if source.buildingId == building then
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
    return categoriesOut, table.concat(revisions, ","), accessOut
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

local function categoryItem(source, category, wanted)
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

function WS.reserve(place, category, actorId, quantity)
    local value = store()
    if not value or not place or place.id == nil or not actorId then return nil end
    quantity = tonumber(quantity) or 1
    if quantity <= 0 then return nil end
    local reservationCount = 0
    for _, reservation in pairs(value.reservations) do
        if reservation.status == "reserved" then
            reservationCount = reservationCount + 1
        end
    end
    if reservationCount >= MAX_RESERVATIONS then return nil end
    local building = tostring(place.id)
    local selectedSource, selectedItem, selectedAmount = nil, nil, nil
    for id, source in pairs(value.sources) do
        if source.buildingId == building
            and availableFrom(value, source, category) >= quantity then
            local item, amount = categoryItem(source, category, quantity)
            if item and (not selectedSource or id < selectedSource.id) then
                selectedSource, selectedItem, selectedAmount = source, item, amount
            end
        end
    end
    if selectedSource then
        local source, item, amount = selectedSource, selectedItem, selectedAmount
            value.sequence = value.sequence + 1
            local reservationId = "R:" .. value.sequence .. ":" .. tostring(actorId)
            local reservation = {
                id = reservationId,
                actorId = tostring(actorId),
                placeId = building,
                sourceId = source.id,
                chunkX = source.chunkX,
                chunkY = source.chunkY,
                fingerprint = source.fingerprint,
                revision = source.revision,
                itemId = item.id,
                category = category,
                quantity = amount,
                status = "reserved",
                reservedAt = nowHours(),
            }
            value.reservations[reservationId] = reservation
            return reservation
    end
    return nil
end

local function result(value, reservation, status, detail)
    reservation.status = status
    reservation.resultAt = nowHours()
    reservation.detail = detail
    local prior = value.resultByActor[reservation.actorId]
    if prior and prior ~= reservation.id then
        value.results[prior] = nil
        local oldReservation = value.reservations[prior]
        if oldReservation and oldReservation.status ~= "reserved" then
            value.reservations[prior] = nil
        end
    end
    value.resultSequence = value.resultSequence + 1
    value.results[reservation.id] = {
        reservationId = reservation.id,
        actorId = reservation.actorId,
        sourceId = reservation.sourceId,
        itemId = reservation.itemId,
        category = reservation.category,
        quantity = reservation.quantity,
        status = status,
        detail = detail,
        at = reservation.resultAt,
        order = value.resultSequence,
    }
    value.resultByActor[reservation.actorId] = reservation.id
    value.resultCounts[status] = (tonumber(value.resultCounts[status]) or 0) + 1
    local count = 0
    for _ in pairs(value.results) do count = count + 1 end
    while count > MAX_RESULTS do
        local oldestId, oldest = nil, nil
        for id, receipt in pairs(value.results) do
            if not oldest or (receipt.order or 0) < (oldest.order or 0) then
                oldestId, oldest = id, receipt
            end
        end
        if not oldestId then break end
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
end

function WS.release(reservationId, reason)
    local value = store()
    local reservation = value and value.reservations[reservationId]
    if not reservation or reservation.status ~= "reserved" then return false end
    result(value, reservation, "released", tostring(reason or "interrupted"))
    return true
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
            local represented = false
            pcall(function()
                represented = record and SAO.Body
                    and SAO.Body.hasRepresentation(reservation.actorId)
            end)
            if not record or record.dead or represented
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
