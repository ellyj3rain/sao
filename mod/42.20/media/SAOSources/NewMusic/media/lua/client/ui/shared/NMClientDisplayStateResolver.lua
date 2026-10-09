-- Shared client-side authoritative display-state resolver for UI menus.
NMClientDisplayStateResolver = NMClientDisplayStateResolver or {}

local function cloneState(src)
    local out = {}
    if type(src) ~= "table" then
        return out
    end
    for k, v in pairs(src) do
        out[k] = v
    end
    return out
end

local function monotonicTupleIsNewer(localState, snap)
    local localGen = tonumber(localState and localState.sourceGeneration) or 0
    local localRev = tonumber(localState and localState.revision) or 0
    local localEpoch = tonumber(localState and localState.playbackEpoch) or 0
    local snapGen = tonumber(snap and snap.sourceGeneration) or 0
    local snapRev = tonumber(snap and snap.revision) or 0
    local snapEpoch = tonumber(snap and snap.playbackEpoch) or 0

    if snapGen > localGen then
        return true
    end
    if snapGen < localGen then
        return false
    end
    if snapRev > localRev then
        return true
    end
    if snapRev < localRev then
        return false
    end
    return snapEpoch >= localEpoch
end

local function resolveMergedDisplayState(localState)
    if type(localState) ~= "table" then
        return localState
    end
    local uuid = tostring(localState.deviceUUID or "")
    if uuid == "" then
        return localState
    end

    local entry = NMClientWorldSourceCache and NMClientWorldSourceCache.get and NMClientWorldSourceCache.get(uuid) or nil
    local snap = entry and entry.stateSnapshot or nil
    if type(snap) ~= "table" then
        return localState
    end

    if not monotonicTupleIsNewer(localState, snap) then
        return localState
    end

    local merged = cloneState(localState)
    NMDeviceState.import(merged, snap)
    return merged
end

function NMClientDisplayStateResolver.resolve(localState)
    return resolveMergedDisplayState(localState)
end

function NMClientDisplayStateResolver.resolveForLiveItem(item, localState)
    if type(localState) ~= "table" then
        return localState
    end
    local worldItem = item and item.getWorldItem and item:getWorldItem() or nil
    if not worldItem then
        return localState
    end
    return resolveMergedDisplayState(localState)
end

return NMClientDisplayStateResolver
