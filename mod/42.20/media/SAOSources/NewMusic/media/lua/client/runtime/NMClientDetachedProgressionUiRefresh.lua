-- Canonical detached SP progression follow-up for portable UI invalidation and
-- transition-local churn dedupe.
NMClientDetachedProgressionUiRefresh = NMClientDetachedProgressionUiRefresh or {}

NMClientDetachedProgressionUiRefresh._lastUiRefreshSigByUuid = NMClientDetachedProgressionUiRefresh._lastUiRefreshSigByUuid or {}
NMClientDetachedProgressionUiRefresh._lastRuntimeRefreshSigByUuid = NMClientDetachedProgressionUiRefresh._lastRuntimeRefreshSigByUuid or {}
NMClientDetachedProgressionUiRefresh._lastTrackLabelProbeSigByUuid = NMClientDetachedProgressionUiRefresh._lastTrackLabelProbeSigByUuid or {}
NMClientDetachedProgressionUiRefresh._lastTrackLabelProbeMsByUuid = NMClientDetachedProgressionUiRefresh._lastTrackLabelProbeMsByUuid or {}

local function nowRealMs()
    if getTimestampMs then
        local ms = tonumber(getTimestampMs())
        if ms then
            return ms
        end
    end
    if getTimestamp then
        local ts = tonumber(getTimestamp())
        if ts then
            return ts * 1000
        end
    end
    return 0
end

local function buildTransitionSig(state)
    return table.concat({
        tostring(state and state.revision or 0),
        tostring(state and state.playbackEpoch or 0),
        tostring(state and state.trackIndex or 0),
        tostring(state and state.mediaFullType or "")
    }, "|")
end

local function logPlaybackProgression(tag, detail)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("playback_progression")) then
        return
    end
    NMCore.logChannel("playback_progression", tostring(tag or "detached_progression"), tostring(detail or ""))
end

local function logUiLifecycle(tag, detail)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("ui_lifecycle")) then
        return
    end
    NMCore.logChannel("ui_lifecycle", tostring(tag or "ui_lifecycle"), tostring(detail or ""))
end

local function logTrackLabelProbe(uuid, itemId, state)
    if not (NMCore and NMCore.logChannel and (
        (NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("ui_lifecycle"))
        or (NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("playback_progression"))
    )) then
        return
    end

    local inspected = NMBoomboxWindow and NMBoomboxWindow.inspectOpenItemWindowTarget and NMBoomboxWindow.inspectOpenItemWindowTarget(0) or nil
    if not inspected then
        return
    end

    local incomingItemId = tostring(itemId or "")
    local inspectedItemId = tostring(inspected.itemId or "")
    local incomingUuid = tostring(uuid or "")
    local inspectedUuid = tostring(inspected.uuid or "")
    if incomingUuid ~= "" and inspectedUuid ~= "" and incomingUuid ~= inspectedUuid then
        return
    end
    if incomingUuid == "" and incomingItemId ~= "" and inspectedItemId ~= incomingItemId then
        return
    end

    local probeSig = table.concat({
        tostring(inspected.uiFamily or "unknown"),
        tostring(inspected.displayTrackIndex or ""),
        tostring(inspected.displayLabelText or ""),
        tostring(inspected.resolvedTrackIndex or ""),
        tostring(inspected.resolvedLabelText or ""),
        tostring(inspected.localTrackIndex or ""),
        tostring(inspected.localLabelText or ""),
        tostring(inspected.playbackEpoch or ""),
        tostring(inspected.contextRevision or ""),
        tostring(inspected.renderRevision or "")
    }, "|")
    local key = incomingUuid ~= "" and incomingUuid or incomingItemId
    local nowMs = nowRealMs()
    local previousSig = tostring(NMClientDetachedProgressionUiRefresh._lastTrackLabelProbeSigByUuid[key] or "")
    local previousMs = tonumber(NMClientDetachedProgressionUiRefresh._lastTrackLabelProbeMsByUuid[key]) or 0
    if previousSig == probeSig and (nowMs - previousMs) < 1000 then
        return
    end
    NMClientDetachedProgressionUiRefresh._lastTrackLabelProbeSigByUuid[key] = probeSig
    NMClientDetachedProgressionUiRefresh._lastTrackLabelProbeMsByUuid[key] = nowMs

    local detail = string.format(
        "uuid=%s itemId=%s displayedTrack=%s displayedLabel=%s resolvedTrack=%s resolvedLabel=%s localTrack=%s localLabel=%s epoch=%s contextRevision=%s renderRevision=%s cacheTarget=%s hasItemRef=%s",
        tostring(incomingUuid),
        tostring(incomingItemId ~= "" and incomingItemId or inspectedItemId),
        tostring(inspected.displayTrackIndex or "nil"),
        tostring(inspected.displayLabelText or "nil"),
        tostring(inspected.resolvedTrackIndex or "nil"),
        tostring(inspected.resolvedLabelText or "nil"),
        tostring(inspected.localTrackIndex or "nil"),
        tostring(inspected.localLabelText or "nil"),
        tostring(inspected.playbackEpoch or tonumber(state and state.playbackEpoch) or 0),
        tostring(inspected.contextRevision or 0),
        tostring(inspected.renderRevision or 0),
        tostring(inspected.contextCacheReused == true),
        tostring(inspected.hasItemRef == true)
    )
    logUiLifecycle("ui_track_label_state", detail)
    logPlaybackProgression("ui_track_label_state", detail)
end

function NMClientDetachedProgressionUiRefresh.invalidateDetachedPortableWindow(uuid, itemId, state, sourceContext)
    local key = tostring(uuid or "")
    if key == "" then
        return false
    end
    local sig = buildTransitionSig(state)
    if tostring(NMClientDetachedProgressionUiRefresh._lastUiRefreshSigByUuid[key] or "") == sig then
        logTrackLabelProbe(uuid, itemId, state)
        return false
    end
    NMClientDetachedProgressionUiRefresh._lastUiRefreshSigByUuid[key] = sig

    local invalidated = NMDeviceUI
        and NMDeviceUI.invalidateOpenItemWindow
        and NMDeviceUI.invalidateOpenItemWindow(tostring(itemId or ""), key) == true
        or false
    logPlaybackProgression(
        "detached_sp_ui_refresh",
        string.format(
            "uuid=%s itemId=%s ctx=%s invalidated=%s revision=%s playbackEpoch=%s trackIndex=%s",
            tostring(key),
            tostring(itemId or ""),
            tostring(sourceContext or "unknown"),
            tostring(invalidated),
            tostring(state and state.revision or 0),
            tostring(state and state.playbackEpoch or 0),
            tostring(state and state.trackIndex or 0)
        )
    )
    logTrackLabelProbe(uuid, itemId, state)
    return invalidated
end

function NMClientDetachedProgressionUiRefresh.requestRuntimeRefresh(uuid, state, reason)
    local key = tostring(uuid or "")
    if key == "" then
        return false
    end
    local sig = buildTransitionSig(state)
    if tostring(NMClientDetachedProgressionUiRefresh._lastRuntimeRefreshSigByUuid[key] or "") == sig then
        logPlaybackProgression(
            "detached_sp_refresh_dedupe",
            string.format(
                "uuid=%s reason=%s revision=%s playbackEpoch=%s trackIndex=%s",
                tostring(key),
                tostring(reason or "track_finished"),
                tostring(state and state.revision or 0),
                tostring(state and state.playbackEpoch or 0),
                tostring(state and state.trackIndex or 0)
            )
        )
        if NMClientMainRuntime and NMClientMainRuntime.requestTickGateWake then
            NMClientMainRuntime.requestTickGateWake("detached_sp_" .. tostring(reason or "track_finished"))
        end
        return false
    end
    NMClientDetachedProgressionUiRefresh._lastRuntimeRefreshSigByUuid[key] = sig
    if NMClientMainRuntime and NMClientMainRuntime.requestTickGateWake then
        NMClientMainRuntime.requestTickGateWake("detached_sp_" .. tostring(reason or "track_finished"))
    end
    if NMClientPlaybackTick and NMClientPlaybackTick.requestFullPass then
        NMClientPlaybackTick.requestFullPass("detached_sp_" .. tostring(reason or "track_finished"))
    elseif NMClientPlaybackTick and NMClientPlaybackTick.markDirty then
        NMClientPlaybackTick.markDirty("detached_sp_" .. tostring(reason or "track_finished"))
    end
    return true
end

return NMClientDetachedProgressionUiRefresh
