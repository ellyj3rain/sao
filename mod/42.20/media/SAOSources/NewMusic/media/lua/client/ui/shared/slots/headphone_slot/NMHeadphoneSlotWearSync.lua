_G.NMHeadphoneSlotEnv = _G.NMHeadphoneSlotEnv or {}
local env = _G.NMHeadphoneSlotEnv
if getmetatable(env) == nil then
    setmetatable(env, { __index = _G })
end
setfenv(1, env)

local SYNC_COOLDOWN_MS = 600

NMHeadphoneSlotWearSync = NMHeadphoneSlotWearSync or {}

local function resolveNowMs(window, state)
    return (window and tonumber(window._nmHeadphoneWearSyncNowMs))
        or tonumber(state and state.nowMs)
        or (window and tonumber(window._nmFrameNowMs))
        or (getTimestampMs and tonumber(getTimestampMs()))
        or (getTimeInMillis and tonumber(getTimeInMillis()))
        or 0
end

local function resolveWornHeadphoneState(player)
    local wornHeadphones = NMAttachmentHelpers and NMAttachmentHelpers.findWornHeadphones
        and NMAttachmentHelpers.findWornHeadphones(player) or nil
    return wornHeadphones, wornHeadphones ~= nil
end

local function canRunWearSync(window, groundContext, nowMs)
    local timed = window and window._nmHeadphoneSlotTimedProgress or nil
    local syncBusy = timed and timed.active == true
    return window
        and (not groundContext)
        and (not syncBusy)
        and ((window._nmHeadphoneWearSyncInFlight == true) ~= true)
        and (nowMs - tonumber(window._nmHeadphoneWearSyncLastMs or 0) >= SYNC_COOLDOWN_MS)
end

local function beginWearSyncTransition(window, nowMs, pendingFullType)
    window._nmHeadphoneWearSyncInFlight = true
    window._nmHeadphoneWearSyncLastMs = nowMs
    window._nmPendingHeadphoneSlotFullType = pendingFullType
end

local function rollbackWearSyncTransition(window)
    NMHeadphoneSlotAuthority.clearHeadphoneTransientState(window, nil, true)
end

function NMHeadphoneSlotWearSync.resolveHeadphoneSlotFullType(window, state, allowSync)
    local authoritative = tostring((state and state.headphoneItemFullType) or "")
    local resolved = NMHeadphoneSlotContext.resolveWindowContext(window)
    local profile = resolved and resolved.profile or nil
    if not (profile and NMDeviceProfiles and NMDeviceProfiles.supportsHeadphones(profile)) then
        if NMHeadphoneSlotItems.isAllowedHeadphoneType(authoritative) then
            return authoritative
        end
        return ""
    end

    local player = resolved and resolved.player or nil
    local wornHeadphones, isWearingHeadphones = resolveWornHeadphoneState(player)
    local nowMs = resolveNowMs(window, state)
    local groundContext = NMHeadphoneSlotContext.resolveGroundContext(window, state, resolved)
    local canSync = allowSync == true and canRunWearSync(window, groundContext, nowMs)

    if canSync and authoritative == "" and isWearingHeadphones and wornHeadphones and wornHeadphones.getFullType
        and tostring(wornHeadphones:getFullType() or "") == "Base.Headphones" then
        local hpItemId = NMCore and NMCore.itemId and NMCore.itemId(wornHeadphones) or nil
        if hpItemId then
            beginWearSyncTransition(window, nowMs, "Base.Headphones")
            local ok = NMHeadphoneSlotActions.queueHeadphoneSlotAction(
                window,
                "insert_headphones",
                { headphoneItemId = hpItemId },
                { immediate = true }
            )
            if ok ~= true then
                rollbackWearSyncTransition(window)
            end
        end
    elseif canSync and authoritative == "Base.Headphones" and (not isWearingHeadphones) then
        beginWearSyncTransition(window, nowMs, "")
        local ok = NMHeadphoneSlotActions.queueHeadphoneSlotAction(window, "eject_headphones", {}, { immediate = true })
        if ok ~= true then
            rollbackWearSyncTransition(window)
        end
    end

    if groundContext and NMHeadphoneSlotItems.isGroundInsertionBlocked(authoritative) then
        authoritative = ""
    end
    if authoritative == "" and isWearingHeadphones and not groundContext then
        authoritative = "Base.Headphones"
    elseif authoritative == "Base.Headphones" and not isWearingHeadphones then
        authoritative = ""
    end

    local frameNowMs = (window and tonumber(window._nmFrameNowMs)) or 0
    local awaiting, awaitingAuthoritative = NMHeadphoneSlotAuthority.resolveAwaitingAuthoritativeEject(window, authoritative, frameNowMs)
    if awaiting then
        return awaitingAuthoritative
    end
    authoritative = awaitingAuthoritative

    local pending = window and window._nmPendingHeadphoneSlotFullType or nil
    local timed = window and window._nmHeadphoneSlotTimedProgress or nil
    local timedActive = timed and timed.active == true
    local timedAction = timedActive and tostring(timed.action or "") or ""
    if timedActive and timedAction == "eject_headphones" and tostring(pending or "") ~= "" then
        return tostring(pending or "")
    end
    if timedActive ~= true and pending ~= nil and tostring(pending or "") == authoritative then
        local removeInFlight = window and window._nmSlotRemoveInFlightByType and window._nmSlotRemoveInFlightByType.headphones == true
        if removeInFlight ~= true then
            NMHeadphoneSlotAuthority.clearHeadphoneTransientState(window, authoritative, false)
        end
    end
    if NMHeadphoneSlotItems.isAllowedHeadphoneType(authoritative) then
        return authoritative
    end
    return ""
end

function NMHeadphoneSlotWearSync.tickWearSync(window, resolved)
    local perfStart = NMUIRenderProbe and NMUIRenderProbe.beginWindow and NMUIRenderProbe.beginWindow(window) or nil
    if not window then
        return false
    end
    local ctx = resolved
    if not ctx then
        ctx = NMHeadphoneSlotContext.resolveWindowContext(window)
    end
    local state = ctx and ctx.state or nil
    if not state then
        if NMUIRenderProbe and NMUIRenderProbe.endWindow then
            NMUIRenderProbe.endWindow(window, "slot.headphone.sync_tick", perfStart)
        end
        return false
    end
    local fullType = NMHeadphoneSlotWearSync.resolveHeadphoneSlotFullType(window, state, true)
    if tostring(fullType or "") ~= "" then
        if NMUIRenderProbe and NMUIRenderProbe.count then
            NMUIRenderProbe.count(window, "slot.headphone.sync_active", 1)
        end
        if NMUIRenderProbe and NMUIRenderProbe.endWindow then
            NMUIRenderProbe.endWindow(window, "slot.headphone.sync_tick", perfStart)
        end
        return true
    end
    if window._nmHeadphoneWearSyncInFlight == true or window._nmPendingHeadphoneSlotFullType ~= nil then
        if NMUIRenderProbe and NMUIRenderProbe.endWindow then
            NMUIRenderProbe.endWindow(window, "slot.headphone.sync_tick", perfStart)
        end
        return true
    end
    if NMUIRenderProbe and NMUIRenderProbe.endWindow then
        NMUIRenderProbe.endWindow(window, "slot.headphone.sync_tick", perfStart)
    end
    return false
end

return NMHeadphoneSlotWearSync
