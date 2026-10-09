if not NMSourceDescriptorSummary then
    pcall(require, "registry/NMSourceDescriptorSummary")
end

NMServerVehicleIntentLogging = NMServerVehicleIntentLogging or {}

local function isChannelEnabled(name)
    return NMCore
        and NMCore.logChannel
        and NMCore.isSubsystemDebugEnabled
        and NMCore.isSubsystemDebugEnabled(name)
end

function NMServerVehicleIntentLogging.isIntentEnabled()
    return isChannelEnabled("intent")
end

function NMServerVehicleIntentLogging.isSlotEnabled()
    return isChannelEnabled("slot")
end

function NMServerVehicleIntentLogging.isRuntimeEnabled()
    return isChannelEnabled("runtime")
end

function NMServerVehicleIntentLogging.isProgressionEnabled()
    return isChannelEnabled("playback_progression")
end

function NMServerVehicleIntentLogging.describeSourceDescriptorArgs(args, prefix)
    local readFn = NMSourceDescriptorSummary and NMSourceDescriptorSummary.describeArgs or nil
    if type(readFn) == "function" then
        return readFn(args, prefix)
    end
    return "none"
end

function NMServerVehicleIntentLogging.logIntent(tag, detail)
    if NMServerVehicleIntentLogging.isIntentEnabled() then
        NMCore.logChannel("intent", tostring(tag or "intent"), tostring(detail or ""))
    end
end

function NMServerVehicleIntentLogging.logSlotAuthority(tag, detail)
    if NMServerVehicleIntentLogging.isSlotEnabled() then
        NMCore.logChannel("slot", tostring(tag or "slot_authority"), tostring(detail or ""))
    end
end

function NMServerVehicleIntentLogging.logVehicleSlotTrace(stage, detail)
    NMServerVehicleIntentLogging.logSlotAuthority(stage or "vehicle_slot_trace", detail)
end

function NMServerVehicleIntentLogging.logRuntime(tag, detail)
    if NMServerVehicleIntentLogging.isRuntimeEnabled() then
        NMCore.logChannel("runtime", tostring(tag or "runtime"), tostring(detail or ""))
    end
end

function NMServerVehicleIntentLogging.logProgression(cache, tag, key, detail)
    if not NMServerVehicleIntentLogging.isProgressionEnabled() then
        return
    end
    local sigKey = tostring(key or "")
    if sigKey ~= "" and type(cache) == "table" then
        local normalizedDetail = tostring(detail or "")
        if tostring(cache[sigKey] or "") == normalizedDetail then
            return
        end
        cache[sigKey] = normalizedDetail
    end
    NMCore.logChannel("playback_progression", tostring(tag or "progression"), tostring(detail or ""))
end

function NMServerVehicleIntentLogging.logVehicleResolveReject(targetPlayer, targetArgs, resolveErr)
    if not NMServerVehicleIntentLogging.isIntentEnabled() then
        return
    end
    NMServerVehicleIntentLogging.logIntent(
        "server_vehicle_intent_rejected",
        string.format(
            "action=%s reason=%s player=%s vehicleId=%s partId=%s",
            tostring(targetArgs and targetArgs.action or "unknown"),
            tostring(resolveErr or "unknown"),
            tostring(targetPlayer and targetPlayer.getUsername and targetPlayer:getUsername() or "unknown"),
            tostring(targetArgs and targetArgs.vehicleId or ""),
            tostring(targetArgs and targetArgs.partId or "")
        )
    )
end

function NMServerVehicleIntentLogging.logVehicleNormalizeReject(ctx, err)
    if not NMServerVehicleIntentLogging.isSlotEnabled() then
        return
    end
    NMServerVehicleIntentLogging.logVehicleSlotTrace(
        "vehicle_slot_server_receive",
        string.format(
            "trace=%s host=vehicle ui=vehicle action=%s stage=server_receive result=reject vehicleId=%s partId=%s reason=%s",
            tostring(ctx and ctx.args and ctx.args.slotTraceId or ""),
            tostring(ctx and (ctx.action or ctx.args and ctx.args.action) or ""),
            tostring(ctx and ctx.args and ctx.args.vehicleId or ""),
            tostring(ctx and ctx.args and ctx.args.partId or ""),
            tostring(err or "")
        )
    )
end

function NMServerVehicleIntentLogging.logIntentAttempt(ctx)
    if not NMServerVehicleIntentLogging.isIntentEnabled() then
        return
    end
    NMServerVehicleIntentLogging.logIntent(
        "server_vehicle_intent_attempt",
        string.format(
            "action=%s vehicle=%s part=%s media=%s isOn=%s isPlaying=%s trackCount=%d hasTrack=%s",
            tostring(ctx and ctx.action or ""),
            tostring(ctx and ctx.vehicleId or "unknown"),
            tostring(ctx and ctx.partId or "unknown"),
            tostring(ctx and ctx.state and ctx.state.mediaFullType or "nil"),
            tostring(ctx and ctx.state and ctx.state.isOn == true),
            tostring(ctx and ctx.state and ctx.state.isPlaying == true),
            tonumber(ctx and ctx.trackCount) or 0,
            tostring((tonumber(ctx and ctx.trackCount) or 0) > 0)
        )
    )
end

function NMServerVehicleIntentLogging.logTransitionResult(ctx, payload, changed, reason)
    if not NMServerVehicleIntentLogging.isSlotEnabled() then
        return
    end
    NMServerVehicleIntentLogging.logVehicleSlotTrace(
        "vehicle_slot_transition_apply",
        string.format(
            "trace=%s host=vehicle ui=vehicle action=%s stage=transition_apply result=%s vehicleId=%s partId=%s reason=%s mediaItemId=%s payloadMedia=%s ejectFullType=%s",
            tostring(ctx and ctx.args and ctx.args.slotTraceId or ""),
            tostring(ctx and ctx.action or ""),
            tostring(changed and "ok" or "reject"),
            tostring(ctx and ctx.vehicleId or ""),
            tostring(ctx and ctx.partId or ""),
            tostring(reason or ""),
            tostring(ctx and ctx.args and ctx.args.mediaItemId or ""),
            tostring(payload and payload.mediaFullType or ""),
            tostring(payload and payload.mediaEjectFullType or "")
        )
    )
end

return NMServerVehicleIntentLogging
