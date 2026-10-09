-- Shared world-authoritative track progression runtime for vehicle and item hosts.
if not NMServerTrackTimeline then
    pcall(require, "server/helpers/NMServerTrackTimeline")
end
if not NMServerUnknownOpenPolicy then
    pcall(require, "server/runtime/NMServerUnknownOpenPolicy")
end

NMServerWorldTrackRuntime = NMServerWorldTrackRuntime or {}

local function noop() end

local function emitRuntimeProbe(options, tag, detail)
    local fn = type(options and options.emitRuntimeProbe) == "function" and options.emitRuntimeProbe or noop
    fn(tag, detail)
end

local function emitStoreLog(stores, storeName, key, sig, options, tag, detail)
    local store = stores and stores[storeName] or nil
    if type(store) == "table" then
        if tostring(store[key] or "") == tostring(sig or "") then
            return
        end
        store[key] = tostring(sig or "")
    end
    emitRuntimeProbe(options, tag, detail)
end

local function canWriteDue(reason)
    return reason == "play" or reason == "advance_success"
end

local function logDueWrite(entry, state, reason, oldDueMs, dueMs, startMs, durationMs, options)
    local stores = type(options and options.stores) == "table" and options.stores or {}
    local uuid = tostring(entry and entry.uuid or "")
    local sig = table.concat({
        tostring(reason or "unknown"),
        tostring(math.floor(tonumber(oldDueMs) or -1)),
        tostring(math.floor(tonumber(dueMs) or -1)),
        tostring(math.floor(tonumber(startMs) or -1)),
        tostring(math.floor(tonumber(durationMs) or -1)),
        tostring(tonumber(state and state.playbackEpoch) or 0),
        tostring(tonumber(state and state.trackIndex) or 0)
    }, "|")
    local key = uuid ~= "" and uuid or tostring(entry)
    emitStoreLog(
        stores,
        "dueWriteSig",
        key,
        sig,
        options,
        "server_track_due_write",
        string.format(
            "uuid=%s reason=%s oldDueAtMs=%s newDueAtMs=%s startAtMs=%s durationMs=%s playbackEpoch=%s trackIndex=%s",
            tostring(uuid),
            tostring(reason or "unknown"),
            tostring(oldDueMs and math.floor(oldDueMs) or "nil"),
            tostring(dueMs and math.floor(dueMs) or "nil"),
            tostring(startMs and math.floor(startMs) or "nil"),
            tostring(durationMs and math.floor(durationMs) or "nil"),
            tostring(tonumber(state and state.playbackEpoch) or 0),
            tostring(tonumber(state and state.trackIndex) or 0)
        )
    )
end

local function setTrackTimeline(entry, state, startedAtMs, durationMs, reason, options)
    local prior = NMServerTrackTimeline.read(entry, state)
    local oldDueMs = tonumber(prior and prior.dueAtMs)
    local stores = type(options and options.stores) == "table" and options.stores or {}
    if not canWriteDue(reason) then
        local key = tostring(entry and entry.uuid or tostring(entry))
        local blockedSig = table.concat({
            tostring(reason or "unknown"),
            tostring(math.floor(tonumber(oldDueMs) or -1)),
            tostring(tonumber(state and state.playbackEpoch) or 0),
            tostring(tonumber(state and state.trackIndex) or 0)
        }, "|")
        emitStoreLog(
            stores,
            "dueWriteBlockedSig",
            key,
            blockedSig,
            options,
            "deadline_write_forbidden",
            string.format(
                "uuid=%s reason=%s oldDueAtMs=%s playbackEpoch=%s trackIndex=%s",
                tostring(entry and entry.uuid or ""),
                tostring(reason or "unknown"),
                tostring(oldDueMs and math.floor(oldDueMs) or "nil"),
                tostring(tonumber(state and state.playbackEpoch) or 0),
                tostring(tonumber(state and state.trackIndex) or 0)
            )
        )
        return oldDueMs or 0
    end

    local arm = NMServerTrackTimeline.armForReason(entry, state, startedAtMs, tostring(entry and entry.kind or "world"), reason)
    if not arm then
        return oldDueMs or 0
    end
    local dueMs = tonumber(arm and arm.dueAtMs) or 0
    local startMs = tonumber(arm and arm.startedAtMs) or math.max(0, math.floor(tonumber(startedAtMs) or 0))
    local durMs = tonumber(arm and arm.durationMs) or math.max(1000, math.floor(tonumber(durationMs) or 0))
    local timingMode = tostring(arm and arm.timingMode or "")
    local armToken = tostring(arm and arm.armToken or "")
    if tostring(arm and arm.status or "") == "skipped_duplicate" then
        emitRuntimeProbe(
            options,
            "progression_arm_skipped_duplicate",
            string.format(
                "uuid=%s reason=%s token=%s dueAtMs=%s playbackEpoch=%s trackIndex=%s",
                tostring(entry and entry.uuid or ""),
                tostring(reason or "unknown"),
                tostring(armToken),
                tostring(dueMs and math.floor(dueMs) or 0),
                tostring(tonumber(state and state.playbackEpoch) or 0),
                tostring(tonumber(state and state.trackIndex) or 0)
            )
        )
        return dueMs
    end

    emitRuntimeProbe(
        options,
        "progression_arm_applied",
        string.format(
            "uuid=%s reason=%s token=%s dueAtMs=%s playbackEpoch=%s trackIndex=%s",
            tostring(entry and entry.uuid or ""),
            tostring(reason or "unknown"),
            tostring(armToken),
            tostring(dueMs and math.floor(dueMs) or 0),
            tostring(tonumber(state and state.playbackEpoch) or 0),
            tostring(tonumber(state and state.trackIndex) or 0)
        )
    )
    logDueWrite(entry, state, reason or "set_timeline", oldDueMs, dueMs, startMs, durMs, options)
    if timingMode == "unknown_open" then
        emitRuntimeProbe(
            options,
            "unknown_open_timing_armed",
            string.format(
                "uuid=%s reason=%s token=%s startedAtMs=%s dueAtMs=nil",
                tostring(entry and entry.uuid or ""),
                tostring(reason or "unknown"),
                tostring(armToken),
                tostring(math.floor(startMs))
            )
        )
    end
    return dueMs
end

function NMServerWorldTrackRuntime.clearTrackTimeline(entry, state, options)
    local prior = NMServerTrackTimeline.read(entry, state)
    local oldDueMs = tonumber(prior and prior.dueAtMs)
    NMServerTrackTimeline.clear(entry, state)
    if oldDueMs and oldDueMs > 0 then
        logDueWrite(entry, state, "clear_timeline", oldDueMs, nil, nil, nil, options)
    end
end

function NMServerWorldTrackRuntime.applyRestartResume(entry, state, nowMsValue, reason, options)
    local previousTimeline = NMServerTrackTimeline.read(entry, nil)
    local oldDueAtMs = tonumber(previousTimeline and previousTimeline.dueAtMs) or 0
    local rearmedTimeline = NMServerTrackTimeline.read(nil, state)
    local newStartedAtMs = tonumber(rearmedTimeline and rearmedTimeline.startedAtMs) or nowMsValue
    local newDurationMs = tonumber(rearmedTimeline and rearmedTimeline.durationMs) or 0
    local newDueAtMs = tonumber(rearmedTimeline and rearmedTimeline.dueAtMs) or 0
    local timingMode = tostring(rearmedTimeline and rearmedTimeline.timingMode or "")

    entry.serverTrackStartedAtMs = newStartedAtMs
    entry.serverTrackDurationMs = timingMode == "known_due" and newDurationMs or nil
    entry.serverTrackDueAtMs = timingMode == "known_due" and newDueAtMs or nil
    entry._serverTrackStartedAtMs = newStartedAtMs
    entry._serverTrackDurationMs = timingMode == "known_due" and newDurationMs or nil
    entry._serverTrackNextTransitionAtMs = timingMode == "known_due" and newDueAtMs or nil
    entry._serverTrackTimingMode = timingMode ~= "" and timingMode or "unknown_open"

    logDueWrite(
        entry,
        state,
        reason,
        oldDueAtMs > 0 and oldDueAtMs or nil,
        newDueAtMs > 0 and newDueAtMs or nil,
        newStartedAtMs,
        newDurationMs > 0 and newDurationMs or nil,
        options
    )

    local onRestartResume = type(options and options.onRestartResume) == "function" and options.onRestartResume or nil
    if onRestartResume then
        onRestartResume(entry, state, nowMsValue)
    end
    local bumpAndSync = type(options and options.bumpAndSyncAuthoritativeState) == "function" and options.bumpAndSyncAuthoritativeState or nil
    if bumpAndSync then
        bumpAndSync(entry, state)
    end
    return timingMode, newDueAtMs
end

local function shouldLogStalled(entry, state, nowMsValue, options)
    local stores = type(options and options.stores) == "table" and options.stores or {}
    local stalled = stores.stalledState or {}
    stores.stalledState = stalled
    local uuid = tostring(entry and entry.uuid or "")
    local signature = table.concat({
        tostring(tonumber(state and state.playbackEpoch) or 0),
        tostring(tonumber(state and state.trackIndex) or 1),
        tostring(tonumber(state and state.trackCount) or tonumber(entry and entry.trackCount) or 0),
        tostring(state and state.playbackPolicy or entry and entry.playbackPolicy or "autoplay"),
        tostring(state and state.mediaFullType or "nil")
    }, "|")
    local lastSig = tostring(stalled[uuid] and stalled[uuid].sig or "")
    local lastMs = tonumber(stalled[uuid] and stalled[uuid].ms) or 0
    if lastSig == signature and (nowMsValue - lastMs) < 10000 then
        return false
    end
    stalled[uuid] = { sig = signature, ms = nowMsValue }
    return true
end

local function ensureTimelineInvariant(entry, state, nowMsValue, options)
    if not (state and state.isOn == true and state.isPlaying == true) then
        return 0, false
    end
    local valid, timeline = NMServerTrackTimeline.isValid(entry, state)
    if valid then
        return timeline and timeline.dueAtMs or 0, false
    end
    local resolveCurrentTrackProgressionInfo = type(options and options.resolveCurrentTrackProgressionInfo) == "function" and options.resolveCurrentTrackProgressionInfo or nil
    local resolveCurrentTrackDurationMs = type(options and options.resolveCurrentTrackDurationMs) == "function" and options.resolveCurrentTrackDurationMs or nil
    local progression = resolveCurrentTrackProgressionInfo and resolveCurrentTrackProgressionInfo(state) or nil
    local resolveProgressionCause = type(options and options.resolveProgressionCause) == "function" and options.resolveProgressionCause or nil
    local repairedDueAtMs = setTrackTimeline(
        entry,
        state,
        nowMsValue,
        resolveCurrentTrackDurationMs and resolveCurrentTrackDurationMs(state) or 0,
        "play",
        options
    )
    local stores = type(options and options.stores) == "table" and options.stores or {}
    local sigKey = tostring(entry and entry.uuid or "")
    local sig = table.concat({
        tostring(state and state.playbackEpoch or 0),
        tostring(state and state.trackIndex or 0),
        tostring(timeline and timeline.startedAtMs or 0),
        tostring(timeline and timeline.durationMs or 0),
        tostring(timeline and timeline.dueAtMs or 0)
    }, "|")
    emitStoreLog(
        stores,
        "timelineRepairSig",
        sigKey,
        sig,
        options,
        "playing_without_timeline_repaired",
        string.format(
            "uuid=%s reason=missing_or_invalid_timeline context=%s cause=%s oldStart=%s oldDuration=%s oldDue=%s newDue=%s",
            tostring(sigKey),
            tostring(entry and entry.kind or "world"),
            tostring(resolveProgressionCause and resolveProgressionCause(progression) or "unknown_open"),
            tostring(timeline and timeline.startedAtMs or 0),
            tostring(timeline and timeline.durationMs or 0),
            tostring(timeline and timeline.dueAtMs or 0),
            tostring(repairedDueAtMs and math.floor(repairedDueAtMs) or 0)
        )
    )
    return repairedDueAtMs, true
end

function NMServerWorldTrackRuntime.evaluateActiveEntry(entry, state, nowMsValue, options)
    local resolveTrackCount = type(options and options.resolveTrackCount) == "function" and options.resolveTrackCount or nil
    local resolveCurrentTrackProgressionInfo = type(options and options.resolveCurrentTrackProgressionInfo) == "function" and options.resolveCurrentTrackProgressionInfo or nil
    local resolveProfileForEntry = type(options and options.resolveProfileForEntry) == "function" and options.resolveProfileForEntry or nil
    local resolveProgressionCause = type(options and options.resolveProgressionCause) == "function" and options.resolveProgressionCause or nil
    local publishEntryState = type(options and options.publishEntryState) == "function" and options.publishEntryState or nil
    local dueAtMs = ensureTimelineInvariant(entry, state, nowMsValue, options)
    local progressionCurrent = resolveCurrentTrackProgressionInfo and resolveCurrentTrackProgressionInfo(state) or nil
    local timingMode = tostring(progressionCurrent and progressionCurrent.timingMode or "unknown_open")

    if timingMode == "unknown_open" then
        NMServerUnknownOpenPolicy.handleUnknownOpenState(
            entry,
            state,
            progressionCurrent,
            nowMsValue,
            {
                blockedSigStore = options and options.stores and options.stores.unknownOpenDueBlockedSig or nil,
                heartbeatStore = options and options.stores and options.stores.unknownOpenStallHeartbeatMs or nil
            },
            type(options and options.emitRuntimeProbe) == "function" and options.emitRuntimeProbe or nil
        )
        return {
            dueAtMs = tonumber(dueAtMs) or 0,
            timingMode = timingMode,
            advanced = false
        }
    end

    if not (tonumber(dueAtMs) > 0 and nowMsValue >= dueAtMs) then
        return {
            dueAtMs = tonumber(dueAtMs) or 0,
            timingMode = timingMode,
            advanced = false
        }
    end

    local stores = type(options and options.stores) == "table" and options.stores or {}
    local advanceKey = tostring(entry and entry.uuid or "")
    local lastAdvanceMs = tonumber(stores.lastAdvanceTickMs and stores.lastAdvanceTickMs[advanceKey]) or 0
    if lastAdvanceMs == nowMsValue then
        return {
            dueAtMs = tonumber(dueAtMs) or 0,
            timingMode = timingMode,
            advanced = false
        }
    end

    local trackCount = resolveTrackCount and resolveTrackCount(state, entry) or 0
    local beforeTrackIndex = tonumber(state and state.trackIndex) or 1
    local beforePolicy = tostring(state and state.playbackPolicy or entry and entry.playbackPolicy or "autoplay")
    local profile = resolveProfileForEntry and resolveProfileForEntry(entry) or nil
    local progressionBefore = resolveCurrentTrackProgressionInfo and resolveCurrentTrackProgressionInfo(state) or nil
    local progressionCause = resolveProgressionCause and resolveProgressionCause(progressionBefore) or "metadata_due"
    local changedByApply = false
    local applyReason = "profile_missing"
    if profile then
        changedByApply, applyReason = NMServerCanonicalReducer.dispatch({
            eventType = NMServerCanonicalReducer.Event.HINT_TRACK_FINISHED,
            profile = profile,
            state = state,
            intentPayload = {
                playbackMode = "world",
                trackCount = trackCount,
                hasTrack = trackCount > 0
            }
        })
        changedByApply = changedByApply == true
    end
    local afterTrackIndex = tonumber(state and state.trackIndex) or 1
    local dueSig = table.concat({
        tostring(entry and entry.uuid or ""),
        tostring(math.floor(tonumber(dueAtMs) or 0)),
        tostring(math.floor(nowMsValue)),
        tostring(beforeTrackIndex),
        tostring(afterTrackIndex),
        tostring(changedByApply),
        tostring(applyReason or "none")
    }, "|")
    emitStoreLog(
        stores,
        "dueTransitionProbeSig",
        tostring(entry and entry.uuid or ""),
        dueSig,
        options,
        "server_track_due_transition",
        string.format(
            "uuid=%s dueAtMs=%s nowMs=%s changed=%s reason=%s cause=%s profile=%s policy=%s trackIndex=%s->%s trackCount=%s",
            tostring(entry and entry.uuid or ""),
            tostring(math.floor(tonumber(dueAtMs) or 0)),
            tostring(math.floor(nowMsValue)),
            tostring(changedByApply),
            tostring(applyReason or "none"),
            tostring(progressionCause),
            tostring(profile and profile.deviceType or "nil"),
            tostring(beforePolicy),
            tostring(beforeTrackIndex),
            tostring(afterTrackIndex),
            tostring(trackCount)
        )
    )

    if changedByApply then
        NMDeviceState.bumpPlaybackEpoch(state)
        NMDeviceState.bumpRevision(state)
        local canonicalGen = math.max(
            tonumber(state.sourceGeneration) or 0,
            tonumber(entry.sourceEpoch) or 0,
            tonumber(entry.sourceGeneration) or 0
        ) + 1
        state.sourceGeneration = canonicalGen
        entry.sourceEpoch = canonicalGen
        entry.sourceGeneration = canonicalGen
        entry.playbackEpoch = tonumber(state.playbackEpoch) or 0
        entry.trackIndex = tonumber(state.trackIndex) or 1
        entry.trackCount = math.max(trackCount, tonumber(state.trackCount) or 0)
        state.trackCount = entry.trackCount
        entry.playbackPolicy = tostring(state.playbackPolicy or "autoplay")
        entry.transitionReason = (state.isPlaying == true)
            and "server_track_advance_apply"
            or tostring(state.lastStopReason or "album_complete_power_off")

        local progressionAfter = nil
        if state.isPlaying == true then
            setTrackTimeline(
                entry,
                state,
                nowMsValue,
                type(options and options.resolveCurrentTrackDurationMs) == "function" and options.resolveCurrentTrackDurationMs(state) or 0,
                "advance_success",
                options
            )
            progressionAfter = resolveCurrentTrackProgressionInfo and resolveCurrentTrackProgressionInfo(state) or nil
        else
            entry._serverTrackSchedulerSig = nil
            NMServerWorldTrackRuntime.clearTrackTimeline(entry, state, options)
        end
        entry.stateSnapshot = NMDeviceState.export(state)
        if type(stores.lastAdvanceTickMs) == "table" then
            stores.lastAdvanceTickMs[advanceKey] = nowMsValue
        end
        emitRuntimeProbe(
            options,
            "server_track_advance_apply",
            string.format(
                "uuid=%s kind=%s reason=%s cause=%s known=%s source=%s durationMs=%s trackIndex=%s trackCount=%s sourceGen=%s playbackEpoch=%s",
                tostring(entry and entry.uuid or ""),
                tostring(entry and entry.kind or "unknown"),
                tostring(entry and entry.transitionReason or "server_track_advance"),
                tostring(progressionCause),
                tostring(progressionAfter and progressionAfter.knownDuration == true),
                tostring(progressionAfter and progressionAfter.source or "fallback"),
                tostring(progressionAfter and progressionAfter.durationMs or "nil"),
                tostring(entry and entry.trackIndex or 1),
                tostring(entry and entry.trackCount or 0),
                tostring(entry and entry.sourceEpoch or 0),
                tostring(entry and entry.playbackEpoch or 0)
            )
        )
        if publishEntryState then
            publishEntryState(entry, state)
        end
        return {
            dueAtMs = tonumber(dueAtMs) or 0,
            timingMode = timingMode,
            advanced = true,
            applyReason = applyReason
        }
    end

    if shouldLogStalled(entry, state, nowMsValue, options) then
        local describeResolvedState = type(options and options.describeResolvedState) == "function" and options.describeResolvedState or nil
        emitRuntimeProbe(
            options,
            "server_track_advance_stalled",
            string.format(
                "uuid=%s reason=%s profile=%s trackCount=%s policy=%s media=%s resolvedState=%s sourceGen=%s playbackEpoch=%s",
                tostring(entry and entry.uuid or ""),
                tostring(applyReason or "none"),
                tostring(profile and profile.deviceType or "nil"),
                tostring(trackCount),
                tostring(state and state.playbackPolicy or entry and entry.playbackPolicy or "autoplay"),
                tostring(state and state.mediaFullType or "nil"),
                tostring(describeResolvedState and describeResolvedState(entry, state) or "world"),
                tostring(entry and entry.sourceEpoch or state and state.sourceGeneration or 0),
                tostring(state and state.playbackEpoch or 0)
            )
        )
    end
    entry.stateSnapshot = NMDeviceState.export(state)
    return {
        dueAtMs = tonumber(dueAtMs) or 0,
        timingMode = timingMode,
        advanced = false,
        applyReason = applyReason
    }
end

return NMServerWorldTrackRuntime
