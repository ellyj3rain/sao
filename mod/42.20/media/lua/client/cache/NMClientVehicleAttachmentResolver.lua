-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
-- Client-side vehicle attachment resolver driven by authoritative stream hints.
NMClientVehicleAttachmentResolver = NMClientVehicleAttachmentResolver or {}

local function toNumber(v)
    local n = tonumber(v)
    if n == nil then
        return nil
    end
    return n
end

local function readPart(vehicle, partId)
    if not vehicle or not vehicle.getPartById then
        return nil
    end
    return vehicle:getPartById(tostring(partId or "Radio"))
end

local function readPartUuid(part)
    if not part or not part.getModData then
        return ""
    end
    local md = part:getModData()
    local node = md and md[NMCore.StateKey] or nil
    return tostring(node and node.deviceUUID or "")
end

local function runtimeId(vehicle)
    return NMVehicleHelpers and NMVehicleHelpers.getVehicleIdString and NMVehicleHelpers.getVehicleIdString(vehicle) or ""
end

local function sqlId(vehicle)
    return NMVehicleHelpers and NMVehicleHelpers.getVehicleSqlIdString and NMVehicleHelpers.getVehicleSqlIdString(vehicle) or ""
end

local function distSqTo(vehicle, tx, ty)
    if not vehicle or tx == nil or ty == nil then
        return nil
    end
    local vx = tonumber(vehicle.getX and vehicle:getX() or nil)
    local vy = tonumber(vehicle.getY and vehicle:getY() or nil)
    if vx == nil or vy == nil then
        return nil
    end
    local dx = vx - tx
    local dy = vy - ty
    return (dx * dx) + (dy * dy)
end

local function addCandidate(out, seen, vehicle, partId, targetUuid, tx, ty, source)
    local rid = runtimeId(vehicle)
    if rid == "" or seen[rid] then
        return
    end
    seen[rid] = true
    local part = readPart(vehicle, partId)
    local puid = readPartUuid(part)
    out[#out + 1] = {
        vehicle = vehicle,
        runtimeId = rid,
        sqlId = sqlId(vehicle),
        part = part,
        partUuid = puid,
        partMatches = targetUuid ~= "" and puid ~= "" and puid == targetUuid,
        distSq = distSqTo(vehicle, tx, ty),
        source = tostring(source or "unknown")
    }
end

local function addSquareCandidates(out, seen, tx, ty, tz, radius, partId, targetUuid)
    local cell = getCell and getCell() or nil
    if not cell then
        return
    end
    local cx = toNumber(tx)
    local cy = toNumber(ty)
    local cz = math.floor(toNumber(tz) or 0)
    if cx == nil or cy == nil then
        return
    end
    local r = math.max(1, math.floor(toNumber(radius) or 30))
    for x = math.floor(cx - r), math.floor(cx + r) do
        for y = math.floor(cy - r), math.floor(cy + r) do
            local sq = cell.getGridSquare and cell:getGridSquare(x, y, cz) or nil
            if sq then
                local vA = sq.getVehicleContainer and sq:getVehicleContainer() or nil
                local vB = sq.getVehicle and sq:getVehicle() or nil
                addCandidate(out, seen, vA, partId, targetUuid, cx, cy, "square")
                addCandidate(out, seen, vB, partId, targetUuid, cx, cy, "square")
            end
        end
    end
end

local function encodeIdList(candidates, key)
    local out = {}
    local cap = math.min(#(candidates or {}), 12)
    for i = 1, cap do
        local value = tostring(candidates[i] and candidates[i][key] or "")
        if value ~= "" then
            out[#out + 1] = value
        end
    end
    return out
end

local function selectNearestUuidMatch(candidates)
    local selected = nil
    local best = nil
    for i = 1, #(candidates or {}) do
        local c = candidates[i]
        if c and c.part and c.partMatches == true then
            local d = tonumber(c.distSq)
            if selected == nil then
                selected = c
                best = d
            elseif d ~= nil and (best == nil or d < best) then
                selected = c
                best = d
            end
        end
    end
    return selected
end

local function matchesSqlAnchor(candidate, entry, source)
    if type(candidate) ~= "table" then
        return false
    end
    local candidateSql = tostring(candidate.sqlId or "")
    if candidateSql == "" then
        return false
    end
    local anchors = {
        tostring(entry and entry.vehicleSqlId or ""),
        tostring(entry and entry.vehicleSqlIdHint or ""),
        tostring(entry and entry._authorityVehicleSqlIdHint or ""),
        tostring(source and source.vehicleSqlId or ""),
        tostring(source and source.vehicleSqlIdHint or "")
    }
    for i = 1, #anchors do
        if anchors[i] ~= "" and anchors[i] == candidateSql then
            return true
        end
    end
    return false
end

function NMClientVehicleAttachmentResolver.resolveAttachment(entry, opts)
    opts = opts or {}
    local source = entry and entry.source or {}
    local partId = tostring(opts.partId or entry and (entry.partId or entry._authorityPartIdHint) or "Radio")
    local targetUuid = tostring(entry and entry.uuid or "")
    local tx = toNumber(opts.targetX or source.x)
    local ty = toNumber(opts.targetY or source.y)
    local tz = toNumber(opts.targetZ or source.z) or 0
    local runtimeHint = toNumber(opts.runtimeVehicleIdHint
        or entry and (entry._authorityVehicleIdHint or entry.vehicleIdHint or entry.vehicleId)
        or source.vehicleIdHint or source.vehicleId)
    local attachedRuntimeId = toNumber(opts.attachedRuntimeId or entry and (entry.attachedRuntimeId or entry._attachedRuntimeId))
    local candidates = {}
    local seen = {}
    local lastWeakReason = "unresolved_no_candidate"

    if attachedRuntimeId and getVehicleById then
        local attachedVehicle = getVehicleById(attachedRuntimeId)
        addCandidate(candidates, seen, attachedVehicle, partId, targetUuid, tx, ty, "latch")
        local c = candidates[#candidates]
        if c and c.runtimeId ~= "" and c.part and (c.partMatches == true or matchesSqlAnchor(c, entry, source)) then
            return {
                status = "resolved",
                reason = "latch_hold",
                vehicle = c.vehicle,
                runtimeId = c.runtimeId,
                sqlId = c.sqlId,
                part = c.part,
                candidateSource = c.source,
                partUuid = c.partUuid,
                partMatches = c.partMatches == true,
                degraded = false,
                candidates = candidates,
                candidateRuntimeIds = encodeIdList(candidates, "runtimeId"),
                candidateSqlIds = encodeIdList(candidates, "sqlId"),
                runtimeVehicleIdHint = tostring(runtimeHint or "")
            }
        elseif c and c.runtimeId ~= "" then
            lastWeakReason = "latch_uncorroborated"
        end
    end

    if runtimeHint and getVehicleById then
        local hintedVehicle = getVehicleById(runtimeHint)
        addCandidate(candidates, seen, hintedVehicle, partId, targetUuid, tx, ty, "runtime_hint")
        local c = candidates[#candidates]
        if c and c.runtimeId ~= "" and c.part and (c.partMatches == true or matchesSqlAnchor(c, entry, source)) then
            return {
                status = "resolved",
                reason = "runtime_hint",
                vehicle = c.vehicle,
                runtimeId = c.runtimeId,
                sqlId = c.sqlId,
                part = c.part,
                candidateSource = c.source,
                partUuid = c.partUuid,
                partMatches = c.partMatches == true,
                degraded = false,
                candidates = candidates,
                candidateRuntimeIds = encodeIdList(candidates, "runtimeId"),
                candidateSqlIds = encodeIdList(candidates, "sqlId"),
                runtimeVehicleIdHint = tostring(runtimeHint or "")
            }
        elseif c and c.runtimeId ~= "" then
            lastWeakReason = "runtime_hint_uncorroborated"
        end
    end

    if opts.allowSquareScan == false then
        return {
            status = "unresolved",
            reason = "square_scan_backoff",
            vehicle = nil,
            runtimeId = "",
            sqlId = "",
            part = nil,
            candidateSource = "",
            partUuid = "",
            partMatches = false,
            degraded = true,
            candidates = candidates,
            candidateRuntimeIds = encodeIdList(candidates, "runtimeId"),
            candidateSqlIds = encodeIdList(candidates, "sqlId"),
            runtimeVehicleIdHint = tostring(runtimeHint or ""),
            squareScanAttempted = false
        }
    end

    -- This broad square scan sits on the detached playback tick path via
    -- collectInRange -> refreshVehicleSource -> update -> resolveAttachment.
    addSquareCandidates(
        candidates,
        seen,
        tx,
        ty,
        tz,
        opts.radius or 30,
        partId,
        targetUuid
    )
    local matched = selectNearestUuidMatch(candidates)
    if matched then
        return {
            status = "resolved",
            reason = "uuid_part_scan",
            vehicle = matched.vehicle,
            runtimeId = matched.runtimeId,
            sqlId = matched.sqlId,
            part = matched.part,
            candidateSource = matched.source,
            partUuid = matched.partUuid,
            partMatches = matched.partMatches == true,
            degraded = false,
            candidates = candidates,
            candidateRuntimeIds = encodeIdList(candidates, "runtimeId"),
            candidateSqlIds = encodeIdList(candidates, "sqlId"),
            runtimeVehicleIdHint = tostring(runtimeHint or ""),
            squareScanAttempted = true
        }
    end

    return {
        status = "unresolved",
        reason = lastWeakReason,
        vehicle = nil,
        runtimeId = "",
        sqlId = "",
        part = nil,
        candidateSource = "",
        partUuid = "",
        partMatches = false,
        degraded = true,
        candidates = candidates,
        candidateRuntimeIds = encodeIdList(candidates, "runtimeId"),
        candidateSqlIds = encodeIdList(candidates, "sqlId"),
        runtimeVehicleIdHint = tostring(runtimeHint or ""),
        squareScanAttempted = true
    }
end

return NMClientVehicleAttachmentResolver

