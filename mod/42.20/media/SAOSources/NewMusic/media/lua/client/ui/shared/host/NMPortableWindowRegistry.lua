local registry = {}

_G.NMPortableWindowRegistry = registry
_G.NMUiLifecycleWindowRegistry = registry

local function probeEnabled()
    return NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("ui_lifecycle") == true
end

local function registryProbeThrottleKey(playerNum, targetKey)
    return "uiLifecycleProbe.registryLookup." .. tostring(playerNum or 0) .. "." .. tostring(targetKey)
end

local function logRegistryProbe(tag, detail, throttleKey, throttleMs)
    if not (probeEnabled() and NMCore and NMCore.logChannel) then
        return
    end
    if throttleKey and NMCore.shouldLogEvery then
        local nowMs = 0
        if getTimestampMs then
            nowMs = tonumber(getTimestampMs()) or 0
        end
        if nowMs <= 0 and getTimeInMillis then
            nowMs = tonumber(getTimeInMillis()) or 0
        end
        if nowMs <= 0 and getTimestamp then
            nowMs = (tonumber(getTimestamp()) or 0) * 1000
        end
        if not NMCore.shouldLogEvery(throttleKey, nowMs, throttleMs or 1000) then
            return
        end
    end
    NMCore.logChannel("ui_lifecycle", tostring(tag or "ui_lifecycle_registry"), tostring(detail or ""))
end

local function playerKey(playerNum)
    return tostring(tonumber(playerNum) or 0)
end

local function ensurePlayerBucket(env, playerNum)
    env.windowsByPlayer = env.windowsByPlayer or {}
    local key = playerKey(playerNum)
    local bucket = env.windowsByPlayer[key]
    if type(bucket) ~= "table" then
        bucket = {}
        env.windowsByPlayer[key] = bucket
    end
    return bucket, key
end

local function resolveWindowTargetKey(window)
    if not window then
        return ""
    end
    local targetKey = tostring(window._nmPortableTargetKey or "")
    if targetKey ~= "" then
        return targetKey
    end
    targetKey = registry.targetKey(window.target)
    if targetKey ~= "" then
        window._nmPortableTargetKey = targetKey
    end
    return targetKey
end

local function purgeStaleBucketEntry(bucket, key)
    local entry = bucket and bucket[key] or nil
    if entry and entry.javaObject then
        return entry
    end
    if entry then
        bucket[key] = nil
    end
    return nil
end

local function rehydrateBucketEntry(bucket, normalizedTargetKey)
    for key, entry in pairs(bucket) do
        if entry and entry.javaObject then
            local entryTargetKey = resolveWindowTargetKey(entry)
            if entryTargetKey == normalizedTargetKey then
                bucket[normalizedTargetKey] = entry
                if key ~= normalizedTargetKey then
                    bucket[key] = nil
                end
                entry._nmPortableTargetKey = normalizedTargetKey
                return entry, key
            end
        elseif entry then
            bucket[key] = nil
        end
    end
    return nil, nil
end

local function itemTargetKey(itemId, uuid)
    local normalizedUuid = tostring(uuid or "")
    if normalizedUuid ~= "" then
        return "item_uuid:" .. normalizedUuid
    end
    return "item_id:" .. tostring(itemId or "")
end

local function vehicleTargetKey(vehicleId, partId)
    return "vehicle:" .. tostring(vehicleId or "") .. ":" .. tostring(partId or "")
end

function registry.targetKey(target)
    if type(target) ~= "table" then
        return ""
    end
    local kind = tostring(target.kind or "")
    if kind == "vehicle" then
        return vehicleTargetKey(target.vehicleId, target.partId)
    end
    if kind == "item" then
        return itemTargetKey(target.itemId, target.uuid)
    end
    return ""
end

function registry.itemTargetKey(itemId, uuid)
    return itemTargetKey(itemId, uuid)
end

function registry.vehicleTargetKey(vehicleId, partId)
    return vehicleTargetKey(vehicleId, partId)
end

function registry.registerWindow(env, window)
    if not (env and window) then
        return ""
    end
    local targetKey = registry.targetKey(window.target)
    if targetKey == "" then
        return ""
    end
    local bucket = ensurePlayerBucket(env, window.playerNum)
    bucket[targetKey] = window
    window._nmPortableTargetKey = targetKey
    logRegistryProbe(
        "ui_lifecycle_registry_register",
        string.format(
            "player=%s targetKey=%s window=%s kind=%s",
            tostring(window.playerNum or 0),
            tostring(targetKey),
            tostring(window),
            tostring(window.target and window.target.kind or "")
        )
    )
    return targetKey
end

function registry.unregisterWindow(env, window)
    if not (env and window) then
        return false
    end
    local bucket = ensurePlayerBucket(env, window.playerNum)
    local targetKey = resolveWindowTargetKey(window)
    local removed = false
    if targetKey ~= "" and bucket[targetKey] == window then
        bucket[targetKey] = nil
        removed = true
    else
        for key, entry in pairs(bucket) do
            if entry == window then
                bucket[key] = nil
                removed = true
            end
        end
    end
    window._nmPortableTargetKey = nil
    logRegistryProbe(
        "ui_lifecycle_registry_unregister",
        string.format(
            "player=%s targetKey=%s removed=%s window=%s",
            tostring(window.playerNum or 0),
            tostring(targetKey),
            tostring(removed),
            tostring(window)
        )
    )
    return removed
end

function registry.findWindow(env, playerNum, targetKey)
    if not (env and targetKey) then
        return nil
    end
    local bucket = ensurePlayerBucket(env, playerNum)
    local normalizedTargetKey = tostring(targetKey or "")
    if normalizedTargetKey == "" then
        return nil
    end
    local lookupThrottleKey = registryProbeThrottleKey(playerNum, normalizedTargetKey)
    local win = purgeStaleBucketEntry(bucket, normalizedTargetKey)
    if win then
        logRegistryProbe(
            "ui_lifecycle_registry_lookup",
            string.format(
                "player=%s targetKey=%s hit=true stale=false source=direct",
                tostring(playerNum or 0),
                normalizedTargetKey
            ),
            lookupThrottleKey,
            1500
        )
        return win
    end
    if bucket[normalizedTargetKey] ~= nil then
        logRegistryProbe(
            "ui_lifecycle_registry_lookup",
            string.format(
                "player=%s targetKey=%s hit=false stale=true source=direct",
                tostring(playerNum or 0),
                normalizedTargetKey
            ),
            lookupThrottleKey,
            250
        )
    end
    local rehydrated, oldKey = rehydrateBucketEntry(bucket, normalizedTargetKey)
    if rehydrated then
        logRegistryProbe(
            "ui_lifecycle_registry_lookup",
            string.format(
                "player=%s targetKey=%s hit=true stale=false source=rehydrate oldKey=%s",
                tostring(playerNum or 0),
                normalizedTargetKey,
                tostring(oldKey or "")
            ),
            lookupThrottleKey,
            250
        )
        return rehydrated
    end
    logRegistryProbe(
        "ui_lifecycle_registry_lookup",
        string.format(
            "player=%s targetKey=%s hit=false stale=false source=miss",
            tostring(playerNum or 0),
            normalizedTargetKey
        ),
        lookupThrottleKey,
        1500
    )
    return nil
end

function registry.collectWindows(env, playerNum)
    if not env then
        return {}
    end
    local bucket = ensurePlayerBucket(env, playerNum)
    local out = {}
    for key, win in pairs(bucket) do
        if win and win.javaObject then
            out[#out + 1] = win
        else
            bucket[key] = nil
        end
    end
    return out
end

function registry.collectAllWindows(env)
    if not env then
        return {}
    end
    env.windowsByPlayer = env.windowsByPlayer or {}
    local out = {}
    for _, bucket in pairs(env.windowsByPlayer) do
        if type(bucket) == "table" then
            for key, win in pairs(bucket) do
                if win and win.javaObject then
                    out[#out + 1] = win
                else
                    bucket[key] = nil
                end
            end
        end
    end
    return out
end

function registry.closeAllForPlayer(env, playerNum)
    if not env then
        return false
    end
    local closed = false
    local windows = registry.collectWindows(env, playerNum)
    for i = 1, #windows do
        local win = windows[i]
        if win and win.close then
            win:close()
            closed = true
        elseif win and win.setVisible then
            win:setVisible(false)
            closed = true
        end
    end
    return closed
end

return registry
