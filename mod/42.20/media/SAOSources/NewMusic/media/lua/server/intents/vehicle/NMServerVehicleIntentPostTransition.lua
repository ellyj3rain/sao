require "intents/vehicle/NMServerVehicleIntentLogging"
require "intents/vehicle/NMServerVehicleIntentTargeting"
require "intents/vehicle/NMServerVehicleIntentTransition"
if not NMServerIntentFinalization then
    pcall(require, "intents/NMServerIntentFinalization")
end
if not NMServerTrackTimeline then
    pcall(require, "server/helpers/NMServerTrackTimeline")
end

NMServerVehicleIntentPostTransition = NMServerVehicleIntentPostTransition or {}

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

local function setServerTrackTimeline(state, entry, reason)
    if not state then
        return nil
    end
    return NMServerTrackTimeline.armForReason(entry, state, nowRealMs(), "vehicle", tostring(reason or "play"))
end

local function resolveTrackCount(ctx)
    local trackCount = tonumber(ctx.args and ctx.args.trackCount) or 0
    if trackCount < 1 then
        trackCount = NMTrackCountResolver and NMTrackCountResolver.resolveFromState and NMTrackCountResolver.resolveFromState(ctx.state) or 0
    end
    return trackCount
end

local function finalizeVehicleAuthorityAndReplication(ctx)
    NMServerIntentFinalization.run({
        resolveKeep = function()
            return NMRegistryPolicy.shouldKeepWorldSourceState(ctx.state)
        end,
        prepare = function()
            local entry, canonicalSourceGen = NMServerVehicleIntentTargeting.upsertRegistryForContext(
                ctx,
                ctx.vehicle,
                ctx.part,
                ctx.profile,
                ctx.state,
                ctx.action
            )
            if NMServerVehicleIntentTargeting.shouldRefreshVehicleTimeline(ctx.changed, ctx.state, entry, ctx.action) then
                setServerTrackTimeline(ctx.state, entry, ctx.action)
                NMServerVehicleIntentTargeting.invalidateExportState(ctx, ctx.state)
                entry.stateSnapshot = NMServerVehicleIntentTargeting.exportStateForContext(ctx, ctx.state)
                if NMServerRegistryBroadcast and NMServerRegistryBroadcast.touchEntry then
                    NMServerRegistryBroadcast.touchEntry(entry, ctx.state)
                end
            end
            NMServerVehicleIntentTargeting.suppressVanillaVehicleRadio(ctx.part)
            return {
                entry = entry,
                canonicalSourceGen = canonicalSourceGen
            }
        end,
        emitState = function(_, prepared)
            local canonicalSourceGen = prepared and prepared.canonicalSourceGen or nil
            if NMServerVehicleIntentLogging.isSlotEnabled() then
                NMServerVehicleIntentLogging.logVehicleSlotTrace(
                    "vehicle_slot_state_emit",
                    string.format(
                        "trace=%s host=vehicle ui=vehicle action=%s stage=state_emit result=ok vehicleId=%s partId=%s media=%s isOn=%s isPlaying=%s sourceGeneration=%s",
                        tostring(ctx.args and ctx.args.slotTraceId or ""),
                        tostring(ctx.action),
                        tostring(ctx.vehicleId or ""),
                        tostring(ctx.partId or ""),
                        tostring(ctx.state and ctx.state.mediaFullType or ""),
                        tostring(ctx.state and ctx.state.isOn == true),
                        tostring(ctx.state and ctx.state.isPlaying == true),
                        tostring(canonicalSourceGen or 0)
                    )
                )
            end
            NMServerVehicleIntentTargeting.sendStateForContext(
                ctx,
                ctx.player,
                ctx.vehicle,
                ctx.part,
                ctx.state,
                canonicalSourceGen,
                ctx.action,
                ctx.args and ctx.args.slotTraceId
            )
        end,
        resolveEntry = function(_, prepared)
            return prepared and prepared.entry or nil
        end,
        broadcastEntry = function(entry, op)
            NMServerVehicleIntentTargeting.broadcastRegistryEntryForContext(ctx, entry, ctx.state, op)
        end,
        removeEntry = NMServerVehicleIntentTargeting.removeRegistryEntry,
        afterEntry = function(entry, op)
            NMServerVehicleIntentLogging.logRuntime(
                "server_vehicle_registry",
                string.format(
                    "uuid=%s vehicleId=%s op=%s isOn=%s isPlaying=%s media=%s",
                    tostring(entry.uuid or "nil"),
                    tostring(entry.vehicleId or "nil"),
                    tostring(op),
                    tostring(ctx.state and ctx.state.isOn == true),
                    tostring(ctx.state and ctx.state.isPlaying == true),
                    tostring(ctx.state and ctx.state.mediaFullType or "nil")
                )
            )
        end
    })
end

function NMServerVehicleIntentPostTransition.prepareContext(ctx)
    if NMServerBootReset and NMServerBootReset.normalizeState then
        NMServerBootReset.normalizeState(ctx.state, "vehicle", tostring(ctx.state and ctx.state.deviceUUID or ""))
    end
    NMServerVehicleIntentTargeting.refreshRequestContext(ctx)
    ctx.wasPlaying = ctx.state and ctx.state.isPlaying == true
    if ctx.trackCount == nil then
        ctx.trackCount = resolveTrackCount(ctx)
    end
    if NMServerVehicleIntentLogging.isSlotEnabled() then
        NMServerVehicleIntentLogging.logVehicleSlotTrace(
            "vehicle_slot_server_receive",
            string.format(
                "trace=%s host=vehicle ui=vehicle action=%s stage=server_receive result=ok vehicleId=%s partId=%s mediaItemId=%s mediaItemUuid=%s",
                tostring(ctx.args and ctx.args.slotTraceId or ""),
                tostring(ctx.args and ctx.args.action or ""),
                tostring(ctx.vehicleId or ""),
                tostring(ctx.partId or ""),
                tostring(ctx.args and ctx.args.mediaItemId or ""),
                tostring(ctx.args and ctx.args.mediaItemUuid or "")
            )
        )
    end
    return true
end

function NMServerVehicleIntentPostTransition.postVehicleIntentTransition(ctx, changed, reason, ops, stateBeforeIntent)
    local _, opsError = NMServerVehicleIntentTransition.applyTransitionOps(ctx.player, ctx.inventory, ops)
    if opsError then
        if NMServerVehicleIntentLogging.isSlotEnabled() then
            NMServerVehicleIntentLogging.logVehicleSlotTrace(
                "vehicle_slot_transition_apply",
                string.format(
                    "trace=%s host=vehicle ui=vehicle action=%s stage=transition_apply result=reject vehicleId=%s partId=%s reason=ops_failed:%s",
                    tostring(ctx.args and ctx.args.slotTraceId or ""),
                    tostring(ctx.action),
                    tostring(ctx.vehicleId or ""),
                    tostring(ctx.partId or ""),
                    tostring(opsError or "")
                )
            )
        end
        if stateBeforeIntent then
            NMDeviceState.import(ctx.state, stateBeforeIntent)
            NMServerVehicleIntentTargeting.invalidateExportState(ctx, ctx.state)
            NMServerVehicleIntentTargeting.refreshRequestContext(ctx)
        end
        NMServerVehicleIntentLogging.logIntent(
            "server_vehicle_ops_failed",
            string.format(
                "action=%s player=%s vehicle=%s part=%s mediaItemId=%s resolvedMedia=%s opsError=%s",
                tostring(ctx.action),
                tostring(ctx.playerName or "unknown"),
                tostring(ctx.vehicleId or "unknown"),
                tostring(ctx.partId or "unknown"),
                tostring(ctx.args and ctx.args.mediaItemId or ""),
                tostring(ctx.payload and ctx.payload.mediaFullType or ""),
                tostring(opsError)
            )
        )
        return false, { reason = "ops_failed:" .. tostring(opsError) }
    end

    if changed then
        if (ctx.action == "mute_on" or ctx.action == "mute_off" or ctx.action == "set_volume")
            and NMServerVehicleIntentLogging.isIntentEnabled() then
            NMServerVehicleIntentLogging.logIntent(
                "server_vehicle_level_change_applied",
                string.format(
                    "action=%s vehicle=%s part=%s wasPlaying=%s isPlaying=%s muted=%s volume=%.2f",
                    tostring(ctx.action),
                    tostring(ctx.vehicleId or "unknown"),
                    tostring(ctx.partId or "unknown"),
                    tostring(ctx.wasPlaying),
                    tostring(ctx.state and ctx.state.isPlaying == true),
                    tostring(ctx.state and ctx.state.isMuted == true),
                    tonumber(ctx.state and ctx.state.volume) or 0
                )
            )
        end
        if NMPlaybackContinuityPolicy.doesActionAdvancePlaybackContinuity(ctx.action) then
            NMDeviceState.bumpPlaybackEpoch(ctx.state)
        end
        NMIntentAuthority.applyIntent(
            ctx.state,
            "request_vehicle",
            NMServerVehicleIntentTargeting.buildVehicleAuthorityContext(ctx.player, ctx.vehicle)
        )
        NMDeviceState.bumpRevision(ctx.state)
        NMServerVehicleIntentLogging.logIntent(
            "server_vehicle_intent_applied",
            string.format(
                "action=%s vehicle=%s part=%s media=%s isOn=%s isPlaying=%s trackCount=%d",
                tostring(ctx.action),
                tostring(ctx.vehicleId or "unknown"),
                tostring(ctx.partId or "unknown"),
                tostring(ctx.state and ctx.state.mediaFullType or "nil"),
                tostring(ctx.state and ctx.state.isOn == true),
                tostring(ctx.state and ctx.state.isPlaying == true),
                tonumber(ctx.trackCount) or 0
            )
        )
    else
        NMServerVehicleIntentLogging.logIntent(
            "server_vehicle_intent_rejected",
            string.format(
                "action=%s reason=%s vehicle=%s part=%s media=%s isOn=%s isPlaying=%s trackCount=%d",
                tostring(ctx.action),
                tostring(reason or "none"),
                tostring(ctx.vehicleId or "unknown"),
                tostring(ctx.partId or "unknown"),
                tostring(ctx.state and ctx.state.mediaFullType or "nil"),
                tostring(ctx.state and ctx.state.isOn == true),
                tostring(ctx.state and ctx.state.isPlaying == true),
                tonumber(ctx.trackCount) or 0
            )
        )
    end
    return true, {}
end

function NMServerVehicleIntentPostTransition.finalizeTransition(ctx, changed)
    ctx.changed = changed == true
    finalizeVehicleAuthorityAndReplication(ctx)
end

return NMServerVehicleIntentPostTransition
