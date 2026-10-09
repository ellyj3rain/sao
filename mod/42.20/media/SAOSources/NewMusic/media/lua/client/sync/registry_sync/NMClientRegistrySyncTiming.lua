local NMClientRegistrySyncTiming = {}

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

local function resolveCooldownMs()
    return math.max(500, tonumber(NMRuntimeConfig.getRegistryResyncCooldownMs and NMRuntimeConfig.getRegistryResyncCooldownMs() or 3000) or 3000)
end

local function resolveIntervalTicks()
    return math.max(30, tonumber(NMRuntimeConfig.getRegistryResyncIntervalTicks and NMRuntimeConfig.getRegistryResyncIntervalTicks() or 600) or 600)
end

local function resolveMoveDistance()
    local moveDist = math.max(1, tonumber(NMRuntimeConfig.getRegistryResyncMoveDistance and NMRuntimeConfig.getRegistryResyncMoveDistance() or 48) or 48)
    return moveDist, moveDist * moveDist
end

local function resolveTimeoutTicks()
    return math.max(30, tonumber(NMRuntimeConfig.getRegistryRequestTimeoutTicks and NMRuntimeConfig.getRegistryRequestTimeoutTicks() or 180) or 180)
end

function NMClientRegistrySyncTiming.resolveTickWindow()
    local nowMs = nowRealMs()
    local cooldownMs = resolveCooldownMs()
    local intervalTicks = resolveIntervalTicks()
    local timeoutTicks = resolveTimeoutTicks()
    local _, moveDist2 = resolveMoveDistance()
    return {
        nowMs = nowMs,
        cooldownMs = cooldownMs,
        intervalTicks = intervalTicks,
        timeoutTicks = timeoutTicks,
        moveDist2 = moveDist2
    }
end

function NMClientRegistrySyncTiming.resolveRequestWindow()
    local nowMs = nowRealMs()
    local cooldownMs = resolveCooldownMs()
    return {
        nowMs = nowMs,
        cooldownMs = cooldownMs
    }
end

function NMClientRegistrySyncTiming.isCooldownReady(lastRequestMs, nowMs, cooldownMs)
    return (tonumber(nowMs) or 0) - (tonumber(lastRequestMs) or 0) >= (tonumber(cooldownMs) or 0)
end

function NMClientRegistrySyncTiming.isTimeoutReached(currentTick, requestTick, timeoutTicks)
    return ((tonumber(currentTick) or 0) - (tonumber(requestTick) or 0)) >= (tonumber(timeoutTicks) or 0)
end

function NMClientRegistrySyncTiming.isDueNow(currentTick, nextTick)
    return (tonumber(currentTick) or 0) >= (tonumber(nextTick) or 0)
end

return NMClientRegistrySyncTiming
