_G.NMHeadphoneSlotEnv = _G.NMHeadphoneSlotEnv or {}
local env = _G.NMHeadphoneSlotEnv
if getmetatable(env) == nil then
    setmetatable(env, { __index = _G })
end
setfenv(1, env)

NMHeadphoneSlotPolling = NMHeadphoneSlotPolling or {}

local function resolveNowMs(window, options)
    return tonumber(options and options.nowMs)
        or (window and tonumber(window._nmFrameNowMs))
        or (getTimestampMs and tonumber(getTimestampMs()))
        or (getTimeInMillis and tonumber(getTimeInMillis()))
        or 0
end

local function isUiRefreshPending(window, nowMs)
    return NMSlotHostLifecycle
        and NMSlotHostLifecycle.isUiRefreshPending
        and NMSlotHostLifecycle.isUiRefreshPending(window, nowMs) == true
        or false
end

local function resolveSyncActive(window)
    return window and (
        window._nmHeadphoneWearSyncInFlight == true
        or window._nmPendingHeadphoneSlotFullType ~= nil
        or window._nmHeadphoneWearSyncActive == true
    ) or false
end

local function resolvePollIntervalMs(syncActive, recentUiRefresh, options)
    local idlePollMs = math.max(1, tonumber(options and options.idlePollMs) or 1000)
    local activePollMs = math.max(1, tonumber(options and options.activePollMs) or 200)
    if syncActive or recentUiRefresh then
        return activePollMs
    end
    return idlePollMs
end

function NMHeadphoneSlotPolling.tickWearSyncWindow(window, options)
    if not window then
        return false
    end
    local opts = options or {}
    if opts.visible ~= true then
        window._nmHeadphoneWearSyncActive = false
        return false
    end

    local nowMs = resolveNowMs(window, opts)
    local recentUiRefresh = isUiRefreshPending(window, nowMs)
    local syncActive = resolveSyncActive(window)
    local pollMs = resolvePollIntervalMs(syncActive, recentUiRefresh, opts)
    local lastHeadphoneSyncMs = tonumber(window._nmLastHeadphoneWearSyncMs) or 0
    if (nowMs - lastHeadphoneSyncMs) < pollMs then
        return false
    end

    window._nmLastHeadphoneWearSyncMs = nowMs
    local resolved = opts.resolved
    if resolved == nil and window.resolveContext then
        resolved = NMHeadphoneSlotContext.resolveWindowContext(window)
    end
    window._nmHeadphoneWearSyncNowMs = nowMs
    local active = NMHeadphoneSlotWearSync.tickWearSync(window, resolved) == true
    window._nmHeadphoneWearSyncNowMs = nil
    window._nmHeadphoneWearSyncActive = active
    if active ~= true and recentUiRefresh and NMSlotHostLifecycle and NMSlotHostLifecycle.clearUiRefreshPending then
        NMSlotHostLifecycle.clearUiRefreshPending(window)
    end
    return active
end

return NMHeadphoneSlotPolling
