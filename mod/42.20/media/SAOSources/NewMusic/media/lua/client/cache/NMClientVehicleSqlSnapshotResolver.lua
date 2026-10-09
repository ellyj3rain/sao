-- Client SQL snapshot diagnostics/resolution evidence built from iterator traversal.
-- This module is not client authority for attachment/routing decisions.
NMClientVehicleSqlSnapshotResolver = NMClientVehicleSqlSnapshotResolver or {}

local function nowMs()
    if getTimestampMs then
        local ms = tonumber(getTimestampMs())
        if ms then return ms end
    end
    if getTimestamp then
        local ts = tonumber(getTimestamp())
        if ts then return ts * 1000 end
    end
    return 0
end

local function getSql(vehicle)
    if not vehicle then
        return ""
    end
    return tostring(NMVehicleHelpers and NMVehicleHelpers.getVehicleSqlIdString and NMVehicleHelpers.getVehicleSqlIdString(vehicle) or "")
end

local function getRuntimeId(vehicle)
    if not vehicle then
        return ""
    end
    return tostring(NMVehicleHelpers and NMVehicleHelpers.getVehicleIdString and NMVehicleHelpers.getVehicleIdString(vehicle) or "")
end

local function distance(vehicle, tx, ty)
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
    return math.sqrt((dx * dx) + (dy * dy))
end

local function addUniqueVehicle(out, seen, vehicle)
    if not vehicle then
        return
    end
    local rid = getRuntimeId(vehicle)
    local sql = getSql(vehicle)
    local vx = tonumber(vehicle.getX and vehicle:getX() or nil)
    local vy = tonumber(vehicle.getY and vehicle:getY() or nil)
    local vz = tonumber(vehicle.getZ and vehicle:getZ() or nil)
    local key = table.concat({
        tostring(rid ~= "" and rid or "nil"),
        tostring(sql ~= "" and sql or "nil"),
        vx and string.format("%.2f", vx) or "nil",
        vy and string.format("%.2f", vy) or "nil",
        vz and string.format("%.2f", vz) or "nil"
    }, "|")
    if seen[key] then
        return
    end
    seen[key] = true
    out[#out + 1] = vehicle
end

local function collectFromProbe(maxScan, opts, out, seen)
    local probe = NMVehiclePoolAccessor and NMVehiclePoolAccessor.collect and NMVehiclePoolAccessor.collect(maxScan or 300, opts) or nil
    local vehicles = probe and probe._vehicles or {}
    for i = 1, #vehicles do
        addUniqueVehicle(out, seen, vehicles[i])
    end
    return probe, tonumber(probe and probe.nonNilVehicles or #vehicles) or 0
end

local function summarizeSqlFromVehicles(vehicles, limit)
    local seenSql = {}
    local out = {}
    local cap = math.max(1, tonumber(limit) or 12)
    for i = 1, #(vehicles or {}) do
        local sql = getSql(vehicles[i])
        if sql ~= "" and not seenSql[sql] then
            seenSql[sql] = true
            out[#out + 1] = sql
            if #out >= cap then
                break
            end
        end
    end
    table.sort(out)
    return out
end

local function encodeSqlList(list)
    return table.concat(list or {}, ",")
end

local function collectSquareFallback(targetX, targetY, targetZ, radius, out, seen)
    local cell = getCell and getCell() or nil
    if not cell then
        return 0
    end
    local tx = tonumber(targetX)
    local ty = tonumber(targetY)
    local tz = math.floor(tonumber(targetZ) or 0)
    if tx == nil or ty == nil then
        return 0
    end
    local r = math.max(2, tonumber(radius) or 16)
    local before = #out
    local minX = math.floor(tx - r)
    local maxX = math.floor(tx + r)
    local minY = math.floor(ty - r)
    local maxY = math.floor(ty + r)
    for x = minX, maxX do
        for y = minY, maxY do
            local sq = cell.getGridSquare and cell:getGridSquare(x, y, tz) or nil
            if sq then
                local vA = sq.getVehicleContainer and sq:getVehicleContainer() or nil
                local vB = sq.getVehicle and sq:getVehicle() or nil
                addUniqueVehicle(out, seen, vA)
                addUniqueVehicle(out, seen, vB)
            end
        end
    end
    return math.max(0, #out - before)
end

local state = NMClientVehicleSqlSnapshotResolver._state or {
    bySql = {},
    byRuntime = {},
    allCandidates = {},
    meta = {
        builtAtMs = 0,
        entryCount = 0,
        poolSource = "none"
    },
    dirty = true,
    lastDirtyMs = 0
}
NMClientVehicleSqlSnapshotResolver._state = state

local function buildSnapshotInternal(maxScan, opts)
    opts = opts or {}
    local vehicles = {}
    local seen = {}
    local sourceCounts = {
        cellCount = 0,
        worldCellCount = 0,
        squareScanCount = 0
    }
    local sourceTags = {}
    local probeA, countA = collectFromProbe(maxScan, nil, vehicles, seen)
    local probeAVehicles = probeA and probeA._vehicles or {}
    sourceCounts.cellCount = countA
    sourceTags[#sourceTags + 1] = tostring(probeA and probeA.poolSource or "cell:none")

    local probeBVehicles = {}
    if sourceCounts.cellCount <= 0 then
        local world = getWorld and getWorld() or nil
        local wcell = world and world.getCell and world:getCell() or nil
        if wcell then
            local probeB, countB = collectFromProbe(maxScan, { cell = wcell }, vehicles, seen)
            probeBVehicles = probeB and probeB._vehicles or {}
            sourceCounts.worldCellCount = countB
            sourceTags[#sourceTags + 1] = tostring(probeB and probeB.poolSource or "worldCell:none")
        end
    end

    local squareAddedVehicles = {}
    if #vehicles <= 0 then
        local preSquareCount = #vehicles
        sourceCounts.squareScanCount = collectSquareFallback(
            opts.targetX,
            opts.targetY,
            opts.targetZ,
            opts.squareRadius or 24,
            vehicles,
            seen
        )
        for i = preSquareCount + 1, #vehicles do
            squareAddedVehicles[#squareAddedVehicles + 1] = vehicles[i]
        end
        sourceTags[#sourceTags + 1] = "square_scan"
    end

    local bySql = {}
    local byRuntime = {}
    local allCandidates = {}

    for i = 1, #vehicles do
        local vehicle = vehicles[i]
        local sql = getSql(vehicle)
        local runtimeId = getRuntimeId(vehicle)
        if sql ~= "" and runtimeId ~= "" then
            local candidate = {
                vehicle = vehicle,
                runtimeId = runtimeId,
                sqlId = sql,
                scriptName = tostring(vehicle and vehicle.getScriptName and vehicle:getScriptName() or "")
            }
            bySql[sql] = bySql[sql] or {}
            bySql[sql][#bySql[sql] + 1] = candidate
            allCandidates[#allCandidates + 1] = candidate
            byRuntime[runtimeId] = sql
        end
    end

    state.bySql = bySql
    state.byRuntime = byRuntime
    state.allCandidates = allCandidates
    state.meta = {
        builtAtMs = nowMs(),
        entryCount = tonumber(#vehicles) or 0,
        poolSource = table.concat(sourceTags, ";"),
        cellCount = tonumber(sourceCounts.cellCount) or 0,
        worldCellCount = tonumber(sourceCounts.worldCellCount) or 0,
        squareScanCount = tonumber(sourceCounts.squareScanCount) or 0,
        finalCount = tonumber(#vehicles) or 0,
        sourceSqlCell = encodeSqlList(summarizeSqlFromVehicles(probeAVehicles, 12)),
        sourceSqlWorldCell = encodeSqlList(summarizeSqlFromVehicles(probeBVehicles, 12)),
        sourceSqlSquare = encodeSqlList(summarizeSqlFromVehicles(squareAddedVehicles, 12)),
        sourceSqlFinal = encodeSqlList(summarizeSqlFromVehicles(vehicles, 12))
    }
    state.dirty = false
    return state.meta
end

function NMClientVehicleSqlSnapshotResolver.buildSnapshot(opts)
    opts = opts or {}
    return buildSnapshotInternal(tonumber(opts.maxScan) or 300, opts)
end

function NMClientVehicleSqlSnapshotResolver.markDirty(reason)
    state.dirty = true
    state.lastDirtyMs = nowMs()
    state.lastDirtyReason = tostring(reason or "unknown")
end

function NMClientVehicleSqlSnapshotResolver.getSnapshotMeta()
    return {
        builtAtMs = tonumber(state.meta and state.meta.builtAtMs) or 0,
        entryCount = tonumber(state.meta and state.meta.entryCount) or 0,
        poolSource = tostring(state.meta and state.meta.poolSource or "none"),
        cellCount = tonumber(state.meta and state.meta.cellCount) or 0,
        worldCellCount = tonumber(state.meta and state.meta.worldCellCount) or 0,
        squareScanCount = tonumber(state.meta and state.meta.squareScanCount) or 0,
        finalCount = tonumber(state.meta and state.meta.finalCount) or 0,
        sourceSqlCell = tostring(state.meta and state.meta.sourceSqlCell or ""),
        sourceSqlWorldCell = tostring(state.meta and state.meta.sourceSqlWorldCell or ""),
        sourceSqlSquare = tostring(state.meta and state.meta.sourceSqlSquare or ""),
        sourceSqlFinal = tostring(state.meta and state.meta.sourceSqlFinal or ""),
        ageMs = math.max(0, nowMs() - (tonumber(state.meta and state.meta.builtAtMs) or 0)),
        dirty = state.dirty == true
    }
end

local function encodeCandidates(candidates, tx, ty)
    local out = {}
    local cap = math.min(#(candidates or {}), 12)
    for i = 1, cap do
        local c = candidates[i]
        out[#out + 1] = {
            runtimeId = tostring(c and c.runtimeId or ""),
            sqlId = tostring(c and c.sqlId or ""),
            scriptName = tostring(c and c.scriptName or ""),
            distance = c and c.vehicle and distance(c.vehicle, tx, ty) or nil
        }
    end
    return out
end

function NMClientVehicleSqlSnapshotResolver.resolveBySql(uuid, wantedSql, partId, opts)
    opts = opts or {}
    local wanted = tostring(wantedSql or "")
    local now = nowMs()
    local heartbeatMs = tonumber(opts.heartbeatMs) or 1000
    local staleMs = tonumber(opts.staleMs) or 2000
    local builtAtMs = tonumber(state.meta and state.meta.builtAtMs) or 0
    local ageMs = math.max(0, now - builtAtMs)
    if state.dirty == true or builtAtMs <= 0 or ageMs >= heartbeatMs then
        buildSnapshotInternal(tonumber(opts.maxScan) or 300, opts)
        builtAtMs = tonumber(state.meta and state.meta.builtAtMs) or 0
        ageMs = math.max(0, now - builtAtMs)
    end
    if ageMs >= staleMs then
        buildSnapshotInternal(tonumber(opts.maxScan) or 300, opts)
        builtAtMs = tonumber(state.meta and state.meta.builtAtMs) or 0
        ageMs = math.max(0, now - builtAtMs)
    end

    if wanted == "" then
        return {
            resolved = false,
            reason = "sql_anchor_missing",
            stage = "sql_anchor_missing",
            candidates = {},
            snapshotAgeMs = ageMs,
            entryCount = tonumber(state.meta and state.meta.entryCount) or 0,
            poolSource = tostring(state.meta and state.meta.poolSource or "none")
        }
    end

    local candidates = state.bySql[wanted] or {}
    local encoded = encodeCandidates(candidates, tonumber(opts.targetX), tonumber(opts.targetY))
    if #candidates == 0 then
        local observed = encodeCandidates(state.allCandidates or {}, tonumber(opts.targetX), tonumber(opts.targetY))
        local sqlCell = tostring(state.meta and state.meta.sourceSqlCell or "")
        local sqlWorldCell = tostring(state.meta and state.meta.sourceSqlWorldCell or "")
        local sqlSquare = tostring(state.meta and state.meta.sourceSqlSquare or "")
        local sqlFinal = tostring(state.meta and state.meta.sourceSqlFinal or "")
        return {
            resolved = false,
            reason = "sql_anchor_not_found",
            stage = "sql_anchor_not_found",
            candidates = observed,
            snapshotAgeMs = ageMs,
            entryCount = tonumber(state.meta and state.meta.entryCount) or 0,
            poolSource = tostring(state.meta and state.meta.poolSource or "none"),
            sourceSqlCell = sqlCell,
            sourceSqlWorldCell = sqlWorldCell,
            sourceSqlSquare = sqlSquare,
            sourceSqlFinal = sqlFinal,
            wantedSqlInCell = wanted ~= "" and string.find("," .. sqlCell .. ",", "," .. wanted .. ",", 1, true) ~= nil,
            wantedSqlInWorldCell = wanted ~= "" and string.find("," .. sqlWorldCell .. ",", "," .. wanted .. ",", 1, true) ~= nil,
            wantedSqlInSquare = wanted ~= "" and string.find("," .. sqlSquare .. ",", "," .. wanted .. ",", 1, true) ~= nil,
            wantedSqlInFinal = wanted ~= "" and string.find("," .. sqlFinal .. ",", "," .. wanted .. ",", 1, true) ~= nil
        }
    end

    local selected = nil
    local preferredId = tostring(opts.preferredRuntimeId or "")
    if preferredId ~= "" then
        for i = 1, #candidates do
            if tostring(candidates[i].runtimeId or "") == preferredId then
                selected = candidates[i]
                break
            end
        end
    end
    if not selected then
        local tx = tonumber(opts.targetX)
        local ty = tonumber(opts.targetY)
        local bestDist = nil
        for i = 1, #candidates do
            local d = distance(candidates[i].vehicle, tx, ty)
            if d ~= nil and (bestDist == nil or d < bestDist) then
                bestDist = d
                selected = candidates[i]
            end
        end
        if not selected then
            selected = candidates[1]
        end
    end

    local vehicle = selected and selected.vehicle or nil
    local pid = tostring(partId or "Radio")
    local part = vehicle and vehicle.getPartById and vehicle:getPartById(pid) or nil
    if not part then
        return {
            resolved = false,
            reason = "sql_anchor_part_missing",
            stage = "sql_anchor_part_missing",
            vehicle = vehicle,
            vehicleId = tostring(selected and selected.runtimeId or ""),
            vehicleSqlId = tostring(selected and selected.sqlId or ""),
            candidates = encoded,
            snapshotAgeMs = ageMs,
            entryCount = tonumber(state.meta and state.meta.entryCount) or 0,
            poolSource = tostring(state.meta and state.meta.poolSource or "none")
        }
    end

    return {
        resolved = true,
        reason = "resolved_sql_anchor",
        stage = "sql_anchor_resolved",
        vehicle = vehicle,
        part = part,
        vehicleId = tostring(selected and selected.runtimeId or ""),
        vehicleSqlId = tostring(selected and selected.sqlId or ""),
        candidates = encoded,
        snapshotAgeMs = ageMs,
        entryCount = tonumber(state.meta and state.meta.entryCount) or 0,
        poolSource = tostring(state.meta and state.meta.poolSource or "none")
    }
end

return NMClientVehicleSqlSnapshotResolver

