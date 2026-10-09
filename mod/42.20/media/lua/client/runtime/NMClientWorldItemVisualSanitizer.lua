-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
NMClientWorldItemVisualSanitizer = NMClientWorldItemVisualSanitizer or {}
NMClientWorldItemVisualSanitizer._diag = NMClientWorldItemVisualSanitizer._diag or {
    lastLogMs = 0,
    counters = {}
}

local pendingWorldSync = {}
local SWEEP_INTERVAL_TICKS = 30
local SWEEP_RADIUS = 12
local SWEEP_BUDGET_SQUARES = 45
local RETRY_TICKS = 60
local activeSweep = nil
local UI_INVALIDATION_DIAG_INTERVAL_MS = 5000

local function nowRealMs()
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

local function countUiInvalidation(name)
    if not (NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("memory") == true) then
        return
    end
    local key = tostring(name or "unknown")
    NMClientWorldItemVisualSanitizer._diag.counters[key] = (tonumber(NMClientWorldItemVisualSanitizer._diag.counters[key]) or 0) + 1
end

local function flushUiInvalidationDiag()
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("memory") == true) then
        return
    end
    local nowMs = nowRealMs()
    if (nowMs - (tonumber(NMClientWorldItemVisualSanitizer._diag.lastLogMs) or 0)) < UI_INVALIDATION_DIAG_INTERVAL_MS then
        return
    end
    NMClientWorldItemVisualSanitizer._diag.lastLogMs = nowMs
    local parts = {}
    for name, count in pairs(NMClientWorldItemVisualSanitizer._diag.counters) do
        parts[#parts + 1] = string.format("%s=%d", tostring(name), tonumber(count) or 0)
        NMClientWorldItemVisualSanitizer._diag.counters[name] = nil
    end
    if #parts > 0 then
        NMCore.logChannel("memory", "client_ui_invalidation_diag", table.concat(parts, " | "))
    end
end

local function mapHasAny(tbl)
    for _ in pairs(tbl) do
        return true
    end
    return false
end

local function logRuntime(tag, detail)
    if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
        NMCore.logChannel("runtime", tostring(tag or "world_item_visual"), tostring(detail or ""))
    end
end

local function isWorldInventoryObject(obj)
    return obj and instanceof and instanceof(obj, "IsoWorldInventoryObject")
end

local function getWorldItemFullType(obj)
    local item = obj and obj.getItem and obj:getItem() or nil
    return item and item.getFullType and tostring(item:getFullType() or "") or ""
end

local function queuePendingWorld(obj, reason)
    if not isWorldInventoryObject(obj) then
        return
    end
    pendingWorldSync[obj] = {
        obj = obj,
        ticks = RETRY_TICKS,
        reason = tostring(reason or "pending")
    }
    NMClientWorldItemVisualSanitizer._pendingNearbySweep = true
end

local function sanitizeWorldObject(obj, reason)
    if not isWorldInventoryObject(obj) then
        return false
    end
    local item = obj:getItem()
    local fullType = item and item.getFullType and tostring(item:getFullType() or "") or ""
    if not NMWorldItemVisuals.isRelevantFullType(fullType) then
        return false
    end
    local ok, status = NMWorldItemVisuals.ensureVisual(item)
    if ok ~= true or tostring(status or "") ~= "visual_ready" then
        logRuntime(
            "world_item_visual_sanitize",
            string.format(
                "reason=%s fullType=%s ok=%s status=%s",
                tostring(reason or "unknown"),
                tostring(fullType),
                tostring(ok == true),
                tostring(status or "")
            )
        )
    end
    return ok == true
end

local function startNearbyWorldSweep(player)
    local square = player and player.getCurrentSquare and player:getCurrentSquare() or nil
    local cell = getCell and getCell() or nil
    if not square or not cell then
        activeSweep = nil
        return false
    end

    local sx = square:getX()
    local sy = square:getY()
    local sz = square:getZ()
    activeSweep = {
        cell = cell,
        minX = sx - SWEEP_RADIUS,
        maxX = sx + SWEEP_RADIUS,
        minY = sy - SWEEP_RADIUS,
        maxY = sy + SWEEP_RADIUS,
        x = sx - SWEEP_RADIUS,
        y = sy - SWEEP_RADIUS,
        z = sz,
        processed = 0
    }
    return true
end

local function processSweepSquare(sweep)
    local gridSquare = sweep.cell:getGridSquare(sweep.x, sweep.y, sweep.z)
    local processed = 0
    if gridSquare and gridSquare.getWorldObjects then
        local worldObjects = gridSquare:getWorldObjects()
        for i = 0, worldObjects:size() - 1 do
            local obj = worldObjects:get(i)
            if isWorldInventoryObject(obj) then
                local fullType = getWorldItemFullType(obj)
                if NMWorldItemVisuals.isRelevantFullType(fullType) then
                    sanitizeWorldObject(obj, "nearby_sweep")
                    processed = processed + 1
                end
            end
        end
    end
    return processed
end

local function advanceSweepCursor(sweep)
    sweep.y = sweep.y + 1
    if sweep.y > sweep.maxY then
        sweep.y = sweep.minY
        sweep.x = sweep.x + 1
    end
    return sweep.x <= sweep.maxX
end

local function continueNearbyWorldSweep()
    local sweep = activeSweep
    if not (sweep and sweep.cell) then
        return 0
    end

    local processed = 0
    local visitedSquares = 0
    while activeSweep and visitedSquares < SWEEP_BUDGET_SQUARES do
        local squareProcessed = processSweepSquare(sweep)
        processed = processed + squareProcessed
        sweep.processed = (tonumber(sweep.processed) or 0) + squareProcessed
        visitedSquares = visitedSquares + 1
        if not advanceSweepCursor(sweep) then
            activeSweep = nil
            break
        end
    end
    return processed
end

local function maybeStartNearbyWorldSweep(player)
    if activeSweep then
        return
    end
    startNearbyWorldSweep(player)
end

function NMClientWorldItemVisualSanitizer.onObjectAdded(obj)
    if not isWorldInventoryObject(obj) then
        return
    end
    local fullType = getWorldItemFullType(obj)
    if not NMWorldItemVisuals.isRelevantFullType(fullType) then
        return
    end
    if not sanitizeWorldObject(obj, "object_added") then
        queuePendingWorld(obj, "object_added_retry")
    end
    NMClientWorldItemVisualSanitizer._pendingNearbySweep = true
end

function NMClientWorldItemVisualSanitizer.requestNearbySweep(_reason)
    countUiInvalidation("world_sanitizer_request")
    countUiInvalidation("world_sanitizer_request_" .. tostring(_reason or "unknown"))
    NMClientWorldItemVisualSanitizer._pendingNearbySweep = true
    flushUiInvalidationDiag()
end

function NMClientWorldItemVisualSanitizer.hasPendingWork()
    return activeSweep ~= nil
        or NMClientWorldItemVisualSanitizer._pendingNearbySweep == true
        or mapHasAny(pendingWorldSync)
end

function NMClientWorldItemVisualSanitizer.runPendingRetries()
    for obj, entry in pairs(pendingWorldSync) do
        if not isWorldInventoryObject(obj) then
            pendingWorldSync[obj] = nil
        else
            entry.ticks = (tonumber(entry.ticks) or 0) - 1
            if sanitizeWorldObject(obj, entry.reason or "pending_retry") or entry.ticks <= 0 then
                pendingWorldSync[obj] = nil
            end
        end
    end
end

function NMClientWorldItemVisualSanitizer.runNearbySweep(player)
    if NMClientWorldItemVisualSanitizer._pendingNearbySweep == true and not activeSweep then
        maybeStartNearbyWorldSweep(player)
        if activeSweep then
            NMClientWorldItemVisualSanitizer._pendingNearbySweep = false
        end
    end
    return continueNearbyWorldSweep()
end

function NMClientWorldItemVisualSanitizer.onGameStart()
    pendingWorldSync = {}
    activeSweep = nil
    NMClientWorldItemVisualSanitizer._pendingNearbySweep = true
end

return NMClientWorldItemVisualSanitizer
