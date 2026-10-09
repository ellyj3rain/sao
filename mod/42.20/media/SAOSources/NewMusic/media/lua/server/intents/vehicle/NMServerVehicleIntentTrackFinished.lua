require "intents/vehicle/NMServerVehicleIntentLogging"
if not NMServerTrackTimeline then
    pcall(require, "server/helpers/NMServerTrackTimeline")
end
if not NMServerTrackFinishedHintAcceptance then
    pcall(require, "intents/NMServerTrackFinishedHintAcceptance")
end
if not NMServerItemIntentTrackFinished then
    pcall(require, "intents/item/NMServerItemIntentTrackFinished")
end

NMServerVehicleIntentTrackFinished = NMServerVehicleIntentTrackFinished or {}

function NMServerVehicleIntentTrackFinished.resolveCurrentTrackDurationInfo(state)
    local fallbackMs = tonumber(
        NMRuntimeConfig and NMRuntimeConfig.getServerVehicleTrackDurationMs and NMRuntimeConfig.getServerVehicleTrackDurationMs()
        or NMRuntimeConfig and NMRuntimeConfig.get and NMRuntimeConfig.get("serverVehicleTrackDurationMs", 210000)
        or 210000
    ) or 210000
    return NMTrackProgressionContract.resolve(state, {
        fallbackMs = fallbackMs,
        context = "vehicle",
        worldAuthoritative = true
    })
end

function NMServerVehicleIntentTrackFinished.resolveTrackFinishedHintMinAgeMs()
    return NMTrackProgressionContract.resolveMinHintAgeMs()
end

function NMServerVehicleIntentTrackFinished.resolveStartedAtForHint(state, registryEntry)
    local timeline = NMServerTrackTimeline.read(registryEntry, state)
    local startedAtMs = tonumber(timeline and timeline.startedAtMs) or 0
    if startedAtMs > 0 then
        return startedAtMs, "state_started"
    end
    local dueAtMs = tonumber(timeline and timeline.dueAtMs) or 0
    local durationMs = tonumber(timeline and timeline.durationMs) or 0
    if dueAtMs > 0 and durationMs > 0 then
        local derived = math.max(0, math.floor(dueAtMs - durationMs))
        if derived > 0 then
            return derived, "derived_due_minus_duration"
        end
    end
    return 0, "missing"
end

function NMServerVehicleIntentTrackFinished.validateExpectedToken(state, args)
    local ok, reason = NMTrackProgressionContract.validateExpectedToken(state, args)
    return ok, reason
end

function NMServerVehicleIntentTrackFinished.shouldGateTrackFinished(ctx, action)
    if tostring(action or "") ~= "track_finished" then
        return false
    end
    return NMCore and NMCore.isMPServerAuthority and NMCore.isMPServerAuthority() or false
end

local function logTrackFinishedHintRejection(ctx, acceptReason, acceptInfo, progressionHintSig)
    NMServerVehicleIntentLogging.logProgression(
        progressionHintSig,
        "server_vehicle_track_finished_hint_rejected",
        string.format(
            "%s:%s:%s:%s",
            tostring(acceptReason or "rejected"),
            tostring(ctx.state and ctx.state.deviceUUID or ""),
            tostring(ctx.state and ctx.state.playbackEpoch or 0),
            tostring(ctx.state and ctx.state.trackIndex or 0)
        ),
        string.format(
            "reason=%s vehicle=%s part=%s trackIndex=%s playbackEpoch=%s ageMs=%s minHintAgeMs=%s startedAtMs=%s startedSource=%s token=%s",
            tostring(acceptReason or "rejected"),
            tostring(ctx.vehicleId or "unknown"),
            tostring(ctx.partId or "unknown"),
            tostring(ctx.state and ctx.state.trackIndex or 1),
            tostring(ctx.state and ctx.state.playbackEpoch or 0),
            tostring(acceptInfo and acceptInfo.ageMs or 0),
            tostring(acceptInfo and acceptInfo.minHintAgeMs or 0),
            tostring(acceptInfo and acceptInfo.startedAtMs or 0),
            tostring(acceptInfo and acceptInfo.startedSource or "unknown"),
            tostring(acceptInfo and acceptInfo.dedupeToken or "")
        )
    )
end

local function logTrackFinishedHintRevisionBypass(ctx, acceptInfo, progressionHintSig)
    if not (acceptInfo and acceptInfo.revisionBypassed == true) then
        return
    end
    NMServerVehicleIntentLogging.logProgression(
        progressionHintSig,
        "server_vehicle_track_finished_hint_revision_bypass",
        string.format(
            "rev_bypass:%s:%s:%s",
            tostring(ctx.state and ctx.state.deviceUUID or ""),
            tostring(ctx.state and ctx.state.playbackEpoch or 0),
            tostring(ctx.state and ctx.state.trackIndex or 0)
        ),
        string.format(
            "reason=stale_revision_bypass vehicle=%s part=%s expectedRevision=%s currentRevision=%s token=%s:%s",
            tostring(ctx.vehicleId or "unknown"),
            tostring(ctx.partId or "unknown"),
            tostring(tonumber(ctx.args and ctx.args.expectedRevision)),
            tostring(tonumber(ctx.state and ctx.state.revision) or 0),
            tostring(tonumber(ctx.state and ctx.state.playbackEpoch) or 0),
            tostring(tonumber(ctx.state and ctx.state.trackIndex) or 0)
        )
    )
end

local function logTrackFinishedHintStartedAtBypass(ctx, acceptInfo, progressionHintSig)
    if not (acceptInfo and acceptInfo.missingStartedAt == true) then
        return
    end
    NMServerVehicleIntentLogging.logProgression(
        progressionHintSig,
        "server_vehicle_track_finished_hint_started_missing_bypass",
        string.format(
            "missing:%s:%s:%s",
            tostring(ctx.state and ctx.state.deviceUUID or ""),
            tostring(ctx.state and ctx.state.playbackEpoch or 0),
            tostring(ctx.state and ctx.state.trackIndex or 0)
        ),
        string.format(
            "reason=started_at_missing_bypass vehicle=%s part=%s nowMs=%s",
            tostring(ctx.vehicleId or "unknown"),
            tostring(ctx.partId or "unknown"),
            tostring(acceptInfo and acceptInfo.nowMs or 0)
        )
    )
end

local function logTrackFinishedHintAccepted(ctx, durationInfo, acceptInfo, progressionHintSig)
    NMServerVehicleIntentLogging.logProgression(
        progressionHintSig,
        "server_vehicle_track_finished_hint_accepted",
        "ok:" .. tostring(acceptInfo and acceptInfo.dedupeToken or ""),
        string.format(
            "cause=hint_accept token=%s vehicle=%s part=%s ageMs=%s minHintAgeMs=%s trackIndex=%s playbackEpoch=%s durationKnown=%s",
            tostring(acceptInfo and acceptInfo.dedupeToken or ""),
            tostring(ctx.vehicleId or "unknown"),
            tostring(ctx.partId or "unknown"),
            tostring(acceptInfo and acceptInfo.ageMs or 0),
            tostring(acceptInfo and acceptInfo.minHintAgeMs or 0),
            tostring(ctx.state and ctx.state.trackIndex or 1),
            tostring(ctx.state and ctx.state.playbackEpoch or 0),
            tostring(durationInfo and durationInfo.knownDuration == true)
        )
    )
end

local function logTrackFinishedHintObservedDuration(ctx, acceptInfo, progressionHintSig)
    if not (acceptInfo and acceptInfo.observedApplied == true) then
        return
    end
    NMServerVehicleIntentLogging.logProgression(
        progressionHintSig,
        "server_vehicle_track_finished_hint_duration_recorded",
        "hint_ms:" .. tostring(acceptInfo and acceptInfo.dedupeToken or ""),
        string.format(
            "uuid=%s trackIndex=%s playbackEpoch=%s observedDurationMs=%s",
            tostring(ctx.state and ctx.state.deviceUUID or ""),
            tostring(ctx.state and ctx.state.trackIndex or 1),
            tostring(ctx.state and ctx.state.playbackEpoch or 0),
            tostring(acceptInfo and acceptInfo.observedDurationMs or 0)
        )
    )
end

local function shapeTrackFinishedHintResult(ctx, durationInfo, acceptance, progressionHintSig)
    local acceptReason = acceptance and acceptance.reason or nil
    local acceptInfo = acceptance and acceptance.acceptInfo or nil
    if not (acceptance and acceptance.accepted) then
        logTrackFinishedHintRejection(ctx, acceptReason, acceptInfo, progressionHintSig)
        return false, acceptReason or "stale_state"
    end

    logTrackFinishedHintRevisionBypass(ctx, acceptInfo, progressionHintSig)
    logTrackFinishedHintStartedAtBypass(ctx, acceptInfo, progressionHintSig)
    logTrackFinishedHintAccepted(ctx, durationInfo, acceptInfo, progressionHintSig)
    logTrackFinishedHintObservedDuration(ctx, acceptInfo, progressionHintSig)
    return true, nil
end

function NMServerVehicleIntentTrackFinished.handleBeforePayload(ctx, validation, acceptedTokenStore, progressionHintSig)
    local hooks = validation or NMServerVehicleIntentTrackFinished
    if not hooks.shouldGateTrackFinished(ctx, ctx.action) then
        return true
    end

    local durationInfo = hooks.resolveCurrentTrackDurationInfo(ctx.state)
    local acceptanceModule = NMServerTrackFinishedHintAcceptance
    local acceptance = acceptanceModule and acceptanceModule.accept and acceptanceModule.accept({
        state = ctx.state,
        args = ctx.args,
        acceptedTokenStore = acceptedTokenStore,
        sourceKey = tostring(ctx.state and ctx.state.deviceUUID or ""),
        resolveStartedAt = function()
            return hooks.resolveStartedAtForHint(ctx.state, ctx.existingRegistryEntry)
        end,
        minHintAgeMs = hooks.resolveTrackFinishedHintMinAgeMs(),
        allowStaleRevisionBypass = true,
        canBypassStaleRevision = NMServerItemIntentTrackFinished
            and NMServerItemIntentTrackFinished.canBypassStaleRevisionForTrackFinished
            or nil,
        applyObservedDuration = function()
            return NMTrackProgressionContract.applyObservedDurationHint(ctx.state, ctx.args and ctx.args.observedDurationMs)
        end
    }) or {
        accepted = false,
        reason = "missing_track_finished_hint_acceptance",
        acceptInfo = nil,
        startedAtMs = 0,
        startedSource = "missing"
    }

    return shapeTrackFinishedHintResult(ctx, durationInfo, acceptance, progressionHintSig)
end

return NMServerVehicleIntentTrackFinished
