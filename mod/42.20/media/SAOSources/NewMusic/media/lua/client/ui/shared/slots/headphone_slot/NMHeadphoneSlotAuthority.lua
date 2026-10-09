_G.NMHeadphoneSlotEnv = _G.NMHeadphoneSlotEnv or {}
local env = _G.NMHeadphoneSlotEnv
if getmetatable(env) == nil then
    setmetatable(env, { __index = _G })
end
setfenv(1, env)

local AUTHORITATIVE_EJECT_TIMEOUT_MS = 1000

NMHeadphoneSlotAuthority = NMHeadphoneSlotAuthority or {}

function NMHeadphoneSlotAuthority.clearHeadphoneTransientState(window, fullType, clearPendingAlways)
    if not window then
        return
    end
    window._nmHeadphoneWearSyncInFlight = false
    if window._nmSlotRemoveInFlightByType then
        window._nmSlotRemoveInFlightByType.headphones = nil
    end
    if clearPendingAlways == true or tostring(window._nmPendingHeadphoneSlotFullType or "") == tostring(fullType or "") then
        window._nmPendingHeadphoneSlotFullType = nil
    end
end

function NMHeadphoneSlotAuthority.markAwaitingAuthoritativeHeadphoneEject(window, fullType)
    if NMSlotHostLifecycle and NMSlotHostLifecycle.markAwaitingAuthoritativeSlotEject then
        NMSlotHostLifecycle.markAwaitingAuthoritativeSlotEject(window, "headphones", fullType)
    end
end

function NMHeadphoneSlotAuthority.clearAwaitingAuthoritativeHeadphoneEject(window)
    if NMSlotHostLifecycle and NMSlotHostLifecycle.clearAwaitingAuthoritativeSlotEject then
        NMSlotHostLifecycle.clearAwaitingAuthoritativeSlotEject(window, "headphones")
    end
end

function NMHeadphoneSlotAuthority.getAwaitingAuthoritativeHeadphoneEject(window)
    if NMSlotHostLifecycle and NMSlotHostLifecycle.getAwaitingAuthoritativeSlotEject then
        return NMSlotHostLifecycle.getAwaitingAuthoritativeSlotEject(window, "headphones")
    end
    return nil
end

function NMHeadphoneSlotAuthority.isAwaitingAuthoritativeHeadphoneEject(window, fullType)
    if NMSlotHostLifecycle and NMSlotHostLifecycle.isAwaitingAuthoritativeSlotEject then
        return NMSlotHostLifecycle.isAwaitingAuthoritativeSlotEject(window, "headphones", fullType)
    end
    return false
end

function NMHeadphoneSlotAuthority.isDuplicateHeadphoneEjectBlocked(window, fullType)
    local ejectFullType = tostring(fullType or "")
    if ejectFullType == "" then
        return false
    end
    if NMHeadphoneSlotAuthority.isAwaitingAuthoritativeHeadphoneEject(window, ejectFullType) then
        return true
    end
    if window and window._nmSlotRemoveInFlightByType and window._nmSlotRemoveInFlightByType.headphones then
        return true
    end
    if window and tostring(window._nmPendingHeadphoneSlotFullType or "") == ejectFullType then
        return true
    end
    return false
end

function NMHeadphoneSlotAuthority.resolveAwaitingAuthoritativeEject(window, authoritative, nowMs)
    local awaiting = NMHeadphoneSlotAuthority.getAwaitingAuthoritativeHeadphoneEject(window)
    if not awaiting then
        return false, authoritative
    end

    local awaitingFullType = tostring(awaiting.fullType or "")
    local awaitingStartedAtMs = tonumber(awaiting.startedAtMs) or 0
    if authoritative == "" or (awaitingFullType ~= "" and authoritative ~= awaitingFullType) then
        NMHeadphoneSlotAuthority.clearAwaitingAuthoritativeHeadphoneEject(window)
        return false, authoritative
    end

    if awaitingStartedAtMs > 0 and nowMs > 0 and (nowMs - awaitingStartedAtMs) >= AUTHORITATIVE_EJECT_TIMEOUT_MS then
        NMHeadphoneSlotAuthority.clearAwaitingAuthoritativeHeadphoneEject(window)
        NMHeadphoneSlotAuthority.clearHeadphoneTransientState(window, awaitingFullType, false)
        return false, authoritative
    end

    return true, ""
end

return NMHeadphoneSlotAuthority
