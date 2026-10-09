NMServerSPZombieIntakeQueue = NMServerSPZombieIntakeQueue or {}

function NMServerSPZombieIntakeQueue.ensure(flowState)
    flowState._pendingSPZombieIntake = flowState._pendingSPZombieIntake or {}
    flowState._pendingSPZombieIntakeSet = flowState._pendingSPZombieIntakeSet or {}
    flowState._recentSPAttemptByZombieId = flowState._recentSPAttemptByZombieId or {}
    flowState._recentSPSettledByZombieId = flowState._recentSPSettledByZombieId or {}
    return flowState._pendingSPZombieIntake, flowState._pendingSPZombieIntakeSet, flowState._recentSPAttemptByZombieId, flowState._recentSPSettledByZombieId
end

local function buildRuntimeZombieFallbackKey(zombie)
    if not zombie then
        return ""
    end
    local ref = tostring(zombie or "")
    if ref == "" or ref == "nil" then
        return ""
    end
    local x = zombie.getX and math.floor((tonumber(zombie:getX()) or 0) * 10 + 0.5) or -1
    local y = zombie.getY and math.floor((tonumber(zombie:getY()) or 0) * 10 + 0.5) or -1
    local z = zombie.getZ and math.floor((tonumber(zombie:getZ()) or 0) * 10 + 0.5) or -1
    return string.format("runtime:%s:%d:%d:%d", ref, x, y, z)
end

function NMServerSPZombieIntakeQueue.getZombieQueueKey(zombie)
    local onlineId = zombie and zombie.getOnlineID and zombie:getOnlineID() or nil
    if tonumber(onlineId) and tonumber(onlineId) >= 0 then
        return tostring(onlineId)
    end
    local objectId = zombie and zombie.getObjectID and zombie:getObjectID() or nil
    if tonumber(objectId) and tonumber(objectId) >= 0 then
        return tostring(objectId)
    end
    return buildRuntimeZombieFallbackKey(zombie)
end

function NMServerSPZombieIntakeQueue.isStableZombieQueueKey(zombieKey)
    local key = tostring(zombieKey or "")
    return key ~= "" and key ~= "-1"
end

function NMServerSPZombieIntakeQueue.getStableZombieQueueKey(zombie)
    local key = NMServerSPZombieIntakeQueue.getZombieQueueKey(zombie)
    if NMServerSPZombieIntakeQueue.isStableZombieQueueKey(key) ~= true then
        return ""
    end
    return key
end

function NMServerSPZombieIntakeQueue.getPendingCount(flowState)
    local queue = flowState and flowState._pendingSPZombieIntake or nil
    return queue and #queue or 0
end

function NMServerSPZombieIntakeQueue.getOldestPendingTick(flowState)
    local queue = flowState and flowState._pendingSPZombieIntake or nil
    if not (queue and queue[1]) then
        return 0
    end
    return tonumber(queue[1].enqueuedTick) or 0
end

function NMServerSPZombieIntakeQueue.getRecentAttemptTick(flowState, zombieKey)
    local _, _, attemptTicks = NMServerSPZombieIntakeQueue.ensure(flowState)
    return tonumber(attemptTicks[tostring(zombieKey or "")]) or 0
end

function NMServerSPZombieIntakeQueue.recordAttemptTick(flowState, zombieKey, tick)
    local _, _, attemptTicks = NMServerSPZombieIntakeQueue.ensure(flowState)
    attemptTicks[tostring(zombieKey or "")] = tonumber(tick) or 0
end

function NMServerSPZombieIntakeQueue.getRecentSettledTick(flowState, zombieKey)
    local _, _, _, settledTicks = NMServerSPZombieIntakeQueue.ensure(flowState)
    return tonumber(settledTicks[tostring(zombieKey or "")]) or 0
end

function NMServerSPZombieIntakeQueue.recordRecentSettledTick(flowState, zombieKey, tick)
    local _, _, _, settledTicks = NMServerSPZombieIntakeQueue.ensure(flowState)
    settledTicks[tostring(zombieKey or "")] = tonumber(tick) or 0
end

function NMServerSPZombieIntakeQueue.clearRecentSettledTick(flowState, zombieKey)
    local _, _, _, settledTicks = NMServerSPZombieIntakeQueue.ensure(flowState)
    settledTicks[tostring(zombieKey or "")] = nil
end

function NMServerSPZombieIntakeQueue.enqueue(flowState, zombie, source, diag, keyFn, enqueuedTick)
    local queue, queueSet = NMServerSPZombieIntakeQueue.ensure(flowState)
    local resolveKey = keyFn or NMServerSPZombieIntakeQueue.getZombieQueueKey
    local key = tostring(resolveKey(zombie) or "")
    local normalizedSource = tostring(source or "scan_nearby")
    if key == "" then
        return false, "missing_key", key
    end
    if NMServerSPZombieIntakeQueue.isStableZombieQueueKey(key) ~= true then
        return false, "invalid_placeholder_key", key
    end
    if queueSet[key] == true then
        return false, "duplicate", key
    end
    queueSet[key] = true
    queue[#queue + 1] = {
        key = key,
        zombie = zombie,
        source = normalizedSource,
        enqueuedTick = tonumber(enqueuedTick) or 0
    }
    if diag and normalizedSource ~= "zombie_update" then
        diag.scanEnqueued = (diag.scanEnqueued or 0) + 1
    end
    return true, "enqueued", key
end

function NMServerSPZombieIntakeQueue.dequeue(flowState)
    local queue, queueSet = NMServerSPZombieIntakeQueue.ensure(flowState)
    while #queue > 0 do
        local entry = table.remove(queue, 1)
        if entry then
            queueSet[tostring(entry.key or "")] = nil
            return entry
        end
    end
    return nil
end

function NMServerSPZombieIntakeQueue.drain(flowState, limit, shouldProcessFn, applyFn, diag)
    local remaining = math.max(0, tonumber(limit) or 0)
    local processed = 0
    while remaining > 0 do
        local entry = NMServerSPZombieIntakeQueue.dequeue(flowState)
        if not entry then
            break
        end
        local shouldProcess = true
        if shouldProcessFn then
            shouldProcess = shouldProcessFn(entry.zombie, entry.key, entry.source)
        end
        if shouldProcess == true then
            if applyFn then
                applyFn(entry.zombie, entry.key, entry.source)
            end
            processed = processed + 1
            remaining = remaining - 1
        end
    end
    if diag then
        diag.queueProcessed = (diag.queueProcessed or 0) + processed
    end
    return processed
end

return NMServerSPZombieIntakeQueue
