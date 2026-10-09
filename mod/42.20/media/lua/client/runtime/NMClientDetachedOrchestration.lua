-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
-- Detached source orchestration helpers extracted from playback tick.
NMClientDetachedOrchestration = NMClientDetachedOrchestration or {}

function NMClientDetachedOrchestration.buildConflictStateKey(hasInventoryOwner, detachedContext)
    return tostring(hasInventoryOwner == true) .. ":" .. tostring(detachedContext or "unknown")
end

function NMClientDetachedOrchestration.shouldPruneDetachedForInventoryOwner(hasInventoryOwner, detachedContext)
    if hasInventoryOwner ~= true then
        return false
    end
    return tostring(detachedContext or "") ~= "vehicle"
end

function NMClientDetachedOrchestration.shouldEmitDetachedRemove(nowMsValue, lastMs, minIntervalMs)
    local nowMs = tonumber(nowMsValue) or 0
    local prev = tonumber(lastMs) or 0
    local intervalMs = math.max(0, tonumber(minIntervalMs) or 5000)
    return (nowMs - prev) >= intervalMs
end

function NMClientDetachedOrchestration.applyInventoryOwnershipGate(args)
    local input = type(args) == "table" and args or {}
    local hasInventoryOwner = input.hasInventoryOwner == true
    local detachedContext = tostring(input.detachedContext or "unknown")
    local conflictStateKey = NMClientDetachedOrchestration.buildConflictStateKey(hasInventoryOwner, detachedContext)
    local previousConflictState = tostring(input.previousConflictState or "")
    local conflictChanged = previousConflictState ~= conflictStateKey
    local shouldPrune = NMClientDetachedOrchestration.shouldPruneDetachedForInventoryOwner(hasInventoryOwner, detachedContext)
    local shouldEmitDetachedRemove = false
    if conflictChanged and shouldPrune then
        shouldEmitDetachedRemove = NMClientDetachedOrchestration.shouldEmitDetachedRemove(
            input.nowMsValue,
            input.lastDetachedRemoveMs,
            input.detachedRemoveIntervalMs
        )
    end
    return {
        conflictStateKey = conflictStateKey,
        conflictChanged = conflictChanged,
        shouldPrune = shouldPrune,
        shouldEmitDetachedRemove = shouldEmitDetachedRemove
    }
end

function NMClientDetachedOrchestration.makeDetachedSyncLogKey(deviceUuid)
    return "runtimeProbe.detached." .. tostring(deviceUuid or "")
end

local function readListenerPosition(playerObj)
    local sq = playerObj and playerObj.getSquare and playerObj:getSquare() or nil
    if sq then
        return sq:getX(), sq:getY(), sq:getZ()
    end
    local x = playerObj and playerObj.getX and tonumber(playerObj:getX()) or nil
    local y = playerObj and playerObj.getY and tonumber(playerObj:getY()) or nil
    local z = playerObj and playerObj.getZ and tonumber(playerObj:getZ()) or nil
    return x, y, z
end

function NMClientDetachedOrchestration.buildDetachedSyncDetail(playerObj, entry, state, source)
    local listenerX, listenerY, listenerZ = readListenerPosition(playerObj)
    local sourceX = tonumber(source and source.x) or 0
    local sourceY = tonumber(source and source.y) or 0
    local sourceZ = tonumber(source and source.z) or 0
    local distance = 0
    if listenerX ~= nil and listenerY ~= nil and listenerZ ~= nil then
        local dx = sourceX - listenerX
        local dy = sourceY - listenerY
        local dz = sourceZ - listenerZ
        distance = math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
    end
    return string.format(
        "uuid=%s ctx=%s sourceX=%.2f sourceY=%.2f sourceZ=%.2f listenerX=%s listenerY=%s listenerZ=%s distance=%.2f lastPayloadApplyMs=%s isOn=%s isPlaying=%s media=%s",
        tostring(state and state.deviceUUID or ""),
        tostring(source and source.context or "nil"),
        sourceX,
        sourceY,
        sourceZ,
        tostring(listenerX ~= nil and string.format("%.2f", listenerX) or "nil"),
        tostring(listenerY ~= nil and string.format("%.2f", listenerY) or "nil"),
        tostring(listenerZ ~= nil and string.format("%.2f", listenerZ) or "nil"),
        tonumber(distance) or 0,
        tostring(entry and entry._lastPayloadApplyMs or 0),
        tostring(state and state.isOn == true),
        tostring(state and state.isPlaying == true),
        tostring(state and state.mediaFullType or "nil")
    )
end

return NMClientDetachedOrchestration

