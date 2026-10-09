-- Scheduler sync-state signature bookkeeping helpers.
NMServerSchedulerSyncState = NMServerSchedulerSyncState or {}

local stateSyncSig = stateSyncSig or {}

local function syncPlayerKey(playerObj)
    if not playerObj then
        return "nil"
    end
    local onlineId = playerObj.getOnlineID and tostring(playerObj:getOnlineID() or "") or ""
    if onlineId ~= "" then
        return onlineId
    end
    return playerObj.getUsername and tostring(playerObj:getUsername() or "") or "unknown"
end

function NMServerSchedulerSyncState.buildMeaningfulStateSignature(entry, state)
    state = state or {}
    return table.concat({
        tostring(entry and entry.kind or ""),
        tostring(entry and entry.uuid or entry and entry.vehicleSqlId or ""),
        tostring(entry and entry.sourceMode or ""),
        tostring(state.isOn == true),
        tostring(state.isPlaying == true),
        tostring(tonumber(state.playbackEpoch) or 0),
        tostring(tonumber(state.trackIndex) or 1),
        tostring(tonumber(state.trackCount) or 0),
        tostring(state.mediaFullType or ""),
        tostring(state.mediaDisplayName or ""),
        tostring(tonumber(state.battery) or 0),
        tostring(tonumber(state.volume) or 1),
        tostring(state.isMuted == true),
        tostring(state.lastStopReason or ""),
        tostring(entry and entry.transitionReason or "")
    }, "|")
end

function NMServerSchedulerSyncState.shouldEmitStateSync(entry, playerObj, state)
    local deviceKey = tostring(entry and (entry.uuid or entry.vehicleSqlId or entry.itemId) or "")
    local playerKey = syncPlayerKey(playerObj)
    local cacheKey = deviceKey .. "::" .. playerKey
    local sig = NMServerSchedulerSyncState.buildMeaningfulStateSignature(entry, state)
    local previous = stateSyncSig[cacheKey]
    if previous ~= nil and tostring(previous) == tostring(sig) then
        return false
    end
    stateSyncSig[cacheKey] = sig
    return true
end

return NMServerSchedulerSyncState

