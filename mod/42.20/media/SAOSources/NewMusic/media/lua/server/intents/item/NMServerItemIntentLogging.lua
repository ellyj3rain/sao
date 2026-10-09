NMServerItemIntentLogging = NMServerItemIntentLogging or {}

local function isChannelEnabled(name)
    return NMCore
        and NMCore.logChannel
        and NMCore.isSubsystemDebugEnabled
        and NMCore.isSubsystemDebugEnabled(name)
end

function NMServerItemIntentLogging.isIntentEnabled()
    return isChannelEnabled("intent")
end

function NMServerItemIntentLogging.isSlotEnabled()
    return isChannelEnabled("slot")
end

function NMServerItemIntentLogging.isProgressionEnabled()
    return isChannelEnabled("playback_progression")
end

function NMServerItemIntentLogging.describeSourceDescriptorArgs(args, prefix)
    local readFn = NMSourceDescriptorSummary and NMSourceDescriptorSummary.describeArgs or nil
    if type(readFn) == "function" then
        return readFn(args, prefix)
    end
    return "none"
end

function NMServerItemIntentLogging.logIntent(tag, detail)
    if NMServerItemIntentLogging.isIntentEnabled() then
        NMCore.logChannel("intent", tostring(tag or "intent"), tostring(detail or ""))
    end
end

function NMServerItemIntentLogging.logSlotAuthority(tag, detail)
    if NMServerItemIntentLogging.isSlotEnabled() then
        NMCore.logChannel("slot", tostring(tag or "slot_authority"), tostring(detail or ""))
    end
end

function NMServerItemIntentLogging.logRuntime(tag, detail)
    NMRuntimeProbeAdapter.emit("runtime", "runtime", tostring(tag or "runtime"), tostring(detail or ""))
end

function NMServerItemIntentLogging.logProgression(cache, tag, key, detail)
    if not NMServerItemIntentLogging.isProgressionEnabled() then
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

function NMServerItemIntentLogging.logItemResolveReject(targetPlayer, targetArgs, resolveErr)
    if not (NMCore and NMCore.logChannel) then
        return
    end
    NMCore.logChannel(
        "intent",
        "server_intent_rejected",
        string.format(
            "action=%s reason=%s player=%s itemId=%s uuid=%s itemFullType=%s",
            tostring(targetArgs and targetArgs.action or "unknown"),
            tostring(resolveErr or "unknown"),
            tostring(targetPlayer and targetPlayer.getUsername and targetPlayer:getUsername() or "unknown"),
            tostring(targetArgs and targetArgs.itemId or ""),
            tostring(targetArgs and targetArgs.uuid or ""),
            tostring(targetArgs and targetArgs.itemFullType or "nil")
        )
    )
end

return NMServerItemIntentLogging
