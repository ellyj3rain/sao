-- Shared runtime probe adapter for transition/heartbeat dedupe emission.
NMRuntimeProbeAdapter = NMRuntimeProbeAdapter or {}
NMRuntimeProbeAdapter.HEARTBEAT_SHORT_MS = 15000
NMRuntimeProbeAdapter.HEARTBEAT_STANDARD_MS = 20000
NMRuntimeProbeAdapter.HEARTBEAT_LONG_MS = 60000

local TAG_SUBSYSTEM_OVERRIDES = {
    attached_payload_apply = "runtime_apply",
    client_detached_state_skip_owner_portable = "runtime_apply",
    client_item_state_ui_refresh = "ui_refresh",
    client_state_apply_ok = "runtime_apply",
    identity_state_probe = "runtime_apply",
    mode_sync_ack = "runtime_apply",
    mode_sync_emit = "runtime_apply",
    sql_anchor_lineage = "vehicle_identity",
    state_apply_drop_stale_item = "runtime_apply",
    ui_context_fallback = "ui_refresh",
    ui_context_frame = "ui_refresh",
    vehicle_identity_snapshot = "vehicle_identity",
    world_source_payload_apply = "runtime_apply"
}

function NMRuntimeProbeAdapter.shortHeartbeatMs()
    return NMRuntimeProbeAdapter.HEARTBEAT_SHORT_MS
end

function NMRuntimeProbeAdapter.standardHeartbeatMs()
    return NMRuntimeProbeAdapter.HEARTBEAT_STANDARD_MS
end

function NMRuntimeProbeAdapter.longHeartbeatMs()
    return NMRuntimeProbeAdapter.HEARTBEAT_LONG_MS
end

function NMRuntimeProbeAdapter.quantizeCoord(value, step)
    local n = tonumber(value)
    if n == nil then
        return "nil"
    end
    local bucket = math.max(0.001, tonumber(step) or 1.0)
    return string.format("%.2f", math.floor((n / bucket) + 0.5) * bucket)
end

local function nowMs()
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

local function ensureStore(store)
    if type(store) ~= "table" then
        return {}
    end
    return store
end

function NMRuntimeProbeAdapter.shouldEmitTransition(store, key, sig)
    local map = ensureStore(store)
    local k = tostring(key or "")
    local s = tostring(sig or "")
    local prev = tostring(map[k] or "")
    if prev == s then
        return false
    end
    map[k] = s
    return true
end

function NMRuntimeProbeAdapter.shouldEmitHeartbeat(store, key, intervalMs)
    local map = ensureStore(store)
    local k = tostring(key or "")
    local now = nowMs()
    local last = tonumber(map[k]) or 0
    local interval = math.max(1, tonumber(intervalMs) or 20000)
    if last > 0 and (now - last) < interval then
        return false
    end
    map[k] = now
    return true
end

function NMRuntimeProbeAdapter.shouldEmitTransitionOrHeartbeat(sigStore, msStore, key, sig, intervalMs)
    local changed = NMRuntimeProbeAdapter.shouldEmitTransition(sigStore, key, sig)
    if changed then
        NMRuntimeProbeAdapter.shouldEmitHeartbeat(msStore, key, 1)
        return true
    end
    return NMRuntimeProbeAdapter.shouldEmitHeartbeat(msStore, key, intervalMs)
end

function NMRuntimeProbeAdapter.shouldEmitBucketedTransitionOrHeartbeat(sigStore, msStore, key, options)
    local opts = type(options) == "table" and options or {}
    local parts = type(opts.parts) == "table" and opts.parts or {}
    local coordStep = tonumber(opts.coordStep) or 1.0
    local zStep = tonumber(opts.zStep) or coordStep
    local signatureParts = {}
    for i = 1, #parts do
        signatureParts[#signatureParts + 1] = tostring(parts[i])
    end
    signatureParts[#signatureParts + 1] = NMRuntimeProbeAdapter.quantizeCoord(opts.x, coordStep)
    signatureParts[#signatureParts + 1] = NMRuntimeProbeAdapter.quantizeCoord(opts.y, coordStep)
    signatureParts[#signatureParts + 1] = NMRuntimeProbeAdapter.quantizeCoord(opts.z, zStep)
    return NMRuntimeProbeAdapter.shouldEmitTransitionOrHeartbeat(
        sigStore,
        msStore,
        key,
        table.concat(signatureParts, "|"),
        opts.intervalMs
    )
end

function NMRuntimeProbeAdapter.resolveKnob(knob, tag)
    local override = TAG_SUBSYSTEM_OVERRIDES[tostring(tag or "")]
    if override ~= nil and override ~= "" then
        return override
    end
    return tostring(knob or "")
end

function NMRuntimeProbeAdapter.isEnabled(knob, tag)
    local resolvedKnob = NMRuntimeProbeAdapter.resolveKnob(knob, tag)
    return NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled(resolvedKnob) == true or false
end

function NMRuntimeProbeAdapter.emit(knob, channel, tag, detail)
    if not (NMCore and NMCore.logChannel and NMRuntimeProbeAdapter.isEnabled(knob, tag)) then
        return
    end
    NMCore.logChannel(tostring(channel or "runtime"), tostring(tag or "probe"), tostring(detail or ""))
end

return NMRuntimeProbeAdapter

