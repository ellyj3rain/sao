require "intents/item/NMServerItemIntentLogging"
require "intents/item/NMServerItemIntentTransition"
if not NMServerTrackTimeline then
    pcall(require, "server/helpers/NMServerTrackTimeline")
end

NMServerItemIntentTrackFinished = NMServerItemIntentTrackFinished or {}

local function ensureTrackFinishedHintAcceptance()
    if not NMServerTrackFinishedHintAcceptance then
        pcall(require, "intents/NMServerTrackFinishedHintAcceptance")
    end
    return NMServerTrackFinishedHintAcceptance
end

local function logItemTrackFinishedHintRejection(ctx, acceptReason, acceptInfo, progressionHintSig)
    if not NMServerItemIntentLogging.isProgressionEnabled() then
        return
    end
    NMServerItemIntentLogging.logProgression(
        progressionHintSig,
        "server_world_track_finished_hint_rejected",
        string.format(
            "%s:%s:%s:%s",
            tostring(acceptReason or "rejected"),
            tostring(ctx.state and ctx.state.deviceUUID or ""),
            tostring(ctx.state and ctx.state.playbackEpoch or 0),
            tostring(ctx.state and ctx.state.trackIndex or 0)
        ),
        string.format(
            "reason=%s uuid=%s item=%s ageMs=%s minHintAgeMs=%s startedAtMs=%s startedSource=%s token=%s",
            tostring(acceptReason or "rejected"),
            tostring(ctx.state and ctx.state.deviceUUID or ""),
            tostring(ctx.item and ctx.item.getFullType and ctx.item:getFullType() or "unknown"),
            tostring(acceptInfo and acceptInfo.ageMs or 0),
            tostring(acceptInfo and acceptInfo.minHintAgeMs or 0),
            tostring(acceptInfo and acceptInfo.startedAtMs or 0),
            tostring(acceptInfo and acceptInfo.startedSource or "unknown"),
            tostring(acceptInfo and acceptInfo.dedupeToken or "")
        )
    )
end

local function logItemTrackFinishedHintRevisionBypass(ctx, acceptInfo, progressionHintSig)
    if not (acceptInfo and acceptInfo.revisionBypassed == true) then
        return
    end
    if not NMServerItemIntentLogging.isProgressionEnabled() then
        return
    end
    NMServerItemIntentLogging.logProgression(
        progressionHintSig,
        "server_world_track_finished_hint_revision_bypass",
        string.format(
            "rev_bypass:%s:%s:%s",
            tostring(ctx.state and ctx.state.deviceUUID or ""),
            tostring(ctx.state and ctx.state.playbackEpoch or 0),
            tostring(ctx.state and ctx.state.trackIndex or 0)
        ),
        string.format(
            "reason=stale_revision_bypass uuid=%s item=%s expectedRevision=%s currentRevision=%s token=%s:%s",
            tostring(ctx.state and ctx.state.deviceUUID or ""),
            tostring(ctx.item and ctx.item.getFullType and ctx.item:getFullType() or "unknown"),
            tostring(tonumber(ctx.args and ctx.args.expectedRevision)),
            tostring(tonumber(ctx.state and ctx.state.revision) or 0),
            tostring(tonumber(ctx.state and ctx.state.playbackEpoch) or 0),
            tostring(tonumber(ctx.state and ctx.state.trackIndex) or 0)
        )
    )
end

local function logItemTrackFinishedHintStartedAtBypass(ctx, acceptInfo, progressionHintSig)
    if not (acceptInfo and acceptInfo.missingStartedAt == true) then
        return
    end
    if not NMServerItemIntentLogging.isProgressionEnabled() then
        return
    end
    NMServerItemIntentLogging.logProgression(
        progressionHintSig,
        "server_world_track_finished_hint_started_missing_bypass",
        string.format(
            "missing:%s:%s:%s",
            tostring(ctx.state and ctx.state.deviceUUID or ""),
            tostring(ctx.state and ctx.state.playbackEpoch or 0),
            tostring(ctx.state and ctx.state.trackIndex or 0)
        ),
        string.format(
            "reason=started_at_missing_bypass uuid=%s item=%s",
            tostring(ctx.state and ctx.state.deviceUUID or ""),
            tostring(ctx.item and ctx.item.getFullType and ctx.item:getFullType() or "unknown")
        )
    )
end

local function logItemTrackFinishedHintAccepted(ctx, acceptInfo, progressionHintSig)
    if not NMServerItemIntentLogging.isProgressionEnabled() then
        return
    end
    NMServerItemIntentLogging.logProgression(
        progressionHintSig,
        "server_world_track_finished_hint_accepted",
        "ok:" .. tostring(acceptInfo and acceptInfo.dedupeToken or ""),
        string.format(
            "cause=hint_accept token=%s uuid=%s item=%s ageMs=%s minHintAgeMs=%s trackIndex=%s playbackEpoch=%s",
            tostring(acceptInfo and acceptInfo.dedupeToken or ""),
            tostring(ctx.state and ctx.state.deviceUUID or ""),
            tostring(ctx.item and ctx.item.getFullType and ctx.item:getFullType() or "unknown"),
            tostring(acceptInfo and acceptInfo.ageMs or 0),
            tostring(acceptInfo and acceptInfo.minHintAgeMs or 0),
            tostring(ctx.state and ctx.state.trackIndex or 1),
            tostring(ctx.state and ctx.state.playbackEpoch or 0)
        )
    )
end

local function logItemTrackFinishedHintObservedDuration(ctx, acceptInfo, progressionHintSig)
    if not (acceptInfo and acceptInfo.observedApplied == true) then
        return
    end
    if not NMServerItemIntentLogging.isProgressionEnabled() then
        return
    end
    NMServerItemIntentLogging.logProgression(
        progressionHintSig,
        "server_world_track_finished_hint_duration_recorded",
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

local function shapeItemTrackFinishedHintResult(ctx, acceptance, progressionHintSig)
    local acceptReason = acceptance and acceptance.reason or nil
    local acceptInfo = acceptance and acceptance.acceptInfo or nil
    if not (acceptance and acceptance.accepted) then
        logItemTrackFinishedHintRejection(ctx, acceptReason, acceptInfo, progressionHintSig)
        return false, acceptReason or "stale_state"
    end

    logItemTrackFinishedHintRevisionBypass(ctx, acceptInfo, progressionHintSig)
    logItemTrackFinishedHintStartedAtBypass(ctx, acceptInfo, progressionHintSig)
    logItemTrackFinishedHintAccepted(ctx, acceptInfo, progressionHintSig)
    logItemTrackFinishedHintObservedDuration(ctx, acceptInfo, progressionHintSig)
    return true, nil
end

function NMServerItemIntentTrackFinished.resolveTrackFinishedHintMinAgeMs()
    return NMTrackProgressionContract.resolveMinHintAgeMs()
end

function NMServerItemIntentTrackFinished.resolveStartedAtForHint(state)
    local timeline = NMServerTrackTimeline.read(nil, state)
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

function NMServerItemIntentTrackFinished.shouldGateWorldTrackFinished(ctx, action)
    if tostring(action or "") ~= "track_finished" then
        return false
    end
    if not (NMCore and NMCore.isMPServerAuthority and NMCore.isMPServerAuthority()) then
        return false
    end
    return tostring(ctx and ctx.state and ctx.state.playbackMode or "") == "world"
end

function NMServerItemIntentTrackFinished.validateExpectedToken(state, args)
    local ok, reason = NMTrackProgressionContract.validateExpectedToken(state, args)
    return ok, reason
end

function NMServerItemIntentTrackFinished.canBypassStaleRevisionForTrackFinished(state, args)
    if type(state) ~= "table" or type(args) ~= "table" then
        return false
    end
    local expectedEpoch = tonumber(args.expectedPlaybackEpoch)
    local expectedTrack = tonumber(args.expectedTrackIndex)
    if expectedEpoch == nil or expectedTrack == nil then
        return false
    end
    local currentEpoch = tonumber(state.playbackEpoch) or 0
    local currentTrack = tonumber(state.trackIndex) or 0
    if currentEpoch ~= expectedEpoch or currentTrack ~= expectedTrack then
        return false
    end
    return state.isOn == true and state.isPlaying == true
end

function NMServerItemIntentTrackFinished.handleBeforePayload(ctx, validation, acceptedTokenStore, progressionHintSig)
    if NMServerItemIntentTransition.isSyncAction(ctx.action) then
        return true
    end
    local hooks = validation or NMServerItemIntentTrackFinished
    if not hooks.shouldGateWorldTrackFinished(ctx, ctx.action) then
        return true
    end

    local progression = NMTrackProgressionContract.resolve(ctx.state, {
        fallbackMs = NMRuntimeConfig and NMRuntimeConfig.getServerVehicleTrackDurationMs and NMRuntimeConfig.getServerVehicleTrackDurationMs() or 210000,
        context = "world",
        worldAuthoritative = true
    })
    if NMServerItemIntentLogging.isProgressionEnabled() then
        NMServerItemIntentLogging.logProgression(
            progressionHintSig,
            "server_world_track_finished_hint_received",
            string.format(
                "recv:%s:%s:%s",
                tostring(ctx.deviceUUID or ""),
                tostring(ctx.state and ctx.state.playbackEpoch or 0),
                tostring(ctx.state and ctx.state.trackIndex or 0)
            ),
            string.format(
                "uuid=%s item=%s expectedRevision=%s expectedEpoch=%s expectedTrack=%s observedDurationMs=%s timingMode=%s durationSource=%s",
                tostring(ctx.deviceUUID or ""),
                tostring(ctx.itemFullType or "unknown"),
                tostring(ctx.args and ctx.args.expectedRevision or 0),
                tostring(ctx.args and ctx.args.expectedPlaybackEpoch or 0),
                tostring(ctx.args and ctx.args.expectedTrackIndex or 0),
                tostring(ctx.args and ctx.args.observedDurationMs or 0),
                tostring(progression and progression.timingMode or ""),
                tostring(progression and progression.source or "")
            )
        )
    end

    local acceptanceModule = ensureTrackFinishedHintAcceptance()
    local acceptance = acceptanceModule and acceptanceModule.accept and acceptanceModule.accept({
        state = ctx.state,
        args = ctx.args,
        acceptedTokenStore = acceptedTokenStore,
        sourceKey = tostring(ctx.deviceUUID or ""),
        resolveStartedAt = function()
            return hooks.resolveStartedAtForHint(ctx.state)
        end,
        minHintAgeMs = hooks.resolveTrackFinishedHintMinAgeMs(),
        allowStaleRevisionBypass = true,
        canBypassStaleRevision = hooks.canBypassStaleRevisionForTrackFinished,
        applyObservedDuration = function()
            return NMServerItemIntentTransition.applyObservedDurationHint(ctx.state, ctx.args)
        end
    }) or {
        accepted = false,
        reason = "missing_track_finished_hint_acceptance",
        acceptInfo = nil,
        startedAtMs = 0,
        startedSource = "missing"
    }

    return shapeItemTrackFinishedHintResult(ctx, acceptance, progressionHintSig)
end

return NMServerItemIntentTrackFinished
