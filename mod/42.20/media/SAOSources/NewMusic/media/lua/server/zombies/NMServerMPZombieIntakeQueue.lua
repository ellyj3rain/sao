NMServerMPZombieIntakeQueue = NMServerMPZombieIntakeQueue or {}

function NMServerMPZombieIntakeQueue.ensure(flowState)
    flowState._pendingNaturalIntake = flowState._pendingNaturalIntake or {}
    flowState._pendingNaturalIntakeSet = flowState._pendingNaturalIntakeSet or {}
    return flowState._pendingNaturalIntake, flowState._pendingNaturalIntakeSet
end

function NMServerMPZombieIntakeQueue.getZombieQueueKey(zombie)
    return zombie and zombie.getObjectID and tostring(zombie:getObjectID() or "") or tostring(zombie)
end

function NMServerMPZombieIntakeQueue.count(flowState)
    local queue = flowState and flowState._pendingNaturalIntake or nil
    if type(queue) ~= "table" then
        return 0
    end
    return #queue
end

function NMServerMPZombieIntakeQueue.enqueue(flowState, zombie, source, shouldQueueFn, keyFn, diag)
    if shouldQueueFn and shouldQueueFn(zombie) ~= true then
        return false
    end
    local queue, queueSet = NMServerMPZombieIntakeQueue.ensure(flowState)
    local resolveKey = keyFn or NMServerMPZombieIntakeQueue.getZombieQueueKey
    local key = tostring(resolveKey(zombie) or "")
    if key == "" or queueSet[key] == true then
        return false
    end
    queueSet[key] = true
    queue[#queue + 1] = {
        key = key,
        zombie = zombie,
        source = tostring(source or "natural_intake")
    }
    if diag then
        diag.queueEnqueued = (diag.queueEnqueued or 0) + 1
    end
    return true
end

function NMServerMPZombieIntakeQueue.dequeue(flowState)
    local queue, queueSet = NMServerMPZombieIntakeQueue.ensure(flowState)
    while #queue > 0 do
        local entry = table.remove(queue, 1)
        if entry then
            queueSet[tostring(entry.key or "")] = nil
            return entry
        end
    end
    return nil
end

function NMServerMPZombieIntakeQueue.drain(flowState, limit, shouldQueueFn, applyFn, diag)
    local remaining = tonumber(limit) or 0
    local processed = 0
    while remaining > 0 do
        local entry = NMServerMPZombieIntakeQueue.dequeue(flowState)
        if not entry then
            break
        end
        local zombie = entry.zombie
        if not shouldQueueFn or shouldQueueFn(zombie) == true then
            if applyFn then
                applyFn(zombie, entry.source or "natural_intake")
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

return NMServerMPZombieIntakeQueue
