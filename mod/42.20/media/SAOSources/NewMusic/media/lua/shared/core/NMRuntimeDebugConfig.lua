-- Canonical subsystem debug configuration layered onto NMRuntimeConfig.
NMRuntimeConfig = NMRuntimeConfig or {}

local values = NMRuntimeConfig._values or {}

local subsystemNames = {
    "core",
    "intent",
    "state",
    "runtime",
    "runtime_apply",
    "runtime_route",
    "memory",
    "playback_progression",
    "playback_transition",
    "vehicle",
    "vehicle_identity",
    "vehicle_route",
    "vehicle_trace",
    "zombie_assignment",
    "zombie_corpse",
    "zombie_visual",
    "zombie_attraction",
    "network",
    "registry",
    "loot",
    "loot_probe",
    "ui_render",
    "ui_refresh",
    "ui_auto_close",
    "ui_lifecycle",
    "slot"
}

local ZOMBIE_SUBSYSTEMS = {
    "zombie_assignment",
    "zombie_corpse",
    "zombie_visual",
    "zombie_attraction"
}

local legacySubsystemMap = {
    core = { "core" },
    intent = { "intent" },
    state = { "state" },
    emitter = { "runtime" },
    memoryProbe = { "memory" },
    runtimeProbe = { "runtime" },
    runtimeApplyProbe = { "runtime_apply" },
    runtimeRouteProbe = { "runtime_route" },
    progressionProbe = { "playback_progression" },
    vehicleRebindTrace = { "vehicle" },
    transitionProbe = { "playback_transition" },
    items = { "runtime" },
    net = { "network" },
    registry = { "registry" },
    lootDiagnostics = { "loot" },
    lootProbe = { "loot_probe" },
    zombie = ZOMBIE_SUBSYSTEMS,
    zombieDiagnostics = ZOMBIE_SUBSYSTEMS,
    vehicleDiagnostics = { "vehicle" },
    vehicleTruthProbe = { "vehicle" },
    vehicleIdentityProbe = { "vehicle_identity" },
    vehicleRouteProbe = { "vehicle_route" },
    vehicleTraceProbe = { "vehicle_trace" },
    uiPerfProbe = { "ui_render" },
    uiRefreshProbe = { "ui_refresh" },
    uiAutoCloseProbe = { "ui_auto_close" },
    portableUiProbe = { "ui_lifecycle" },
    portable_ui = { "ui_lifecycle" },
    uiLifecycleProbe = { "ui_lifecycle" },
    cycleModeProbe = { "vehicle" },
    slotAuthorityProbe = { "slot" },
    playback = { "runtime" }
}

local presetDefinitions = {
    sp_loot_reload_probe = {
        "core",
        "loot",
        "loot_probe"
    }
}

local function ensureSubsystemDefaults()
    values.debugSubsystems = values.debugSubsystems or {}
    for i = 1, #subsystemNames do
        local key = subsystemNames[i]
        if values.debugSubsystems[key] == nil then
            values.debugSubsystems[key] = false
        end
    end
end

local function resolveSubsystemNames(name)
    local key = tostring(name or "")
    if key == "" then
        return nil
    end
    if legacySubsystemMap[key] then
        local resolved = legacySubsystemMap[key]
        local out = {}
        for i = 1, #resolved do
            out[i] = resolved[i]
        end
        return out
    end
    for i = 1, #subsystemNames do
        if subsystemNames[i] == key then
            return { key }
        end
    end
    return nil
end

ensureSubsystemDefaults()

function NMRuntimeConfig.resolveSubsystemDebugName(name)
    local keys = resolveSubsystemNames(name)
    return keys and keys[1] or nil
end

function NMRuntimeConfig.isSubsystemDebugEnabled(name)
    local keys = resolveSubsystemNames(name)
    if not keys then
        return false
    end
    for i = 1, #keys do
        if values.debugSubsystems[keys[i]] == true then
            return true
        end
    end
    return false
end

function NMRuntimeConfig.setSubsystemDebugEnabled(name, enabled)
    local keys = resolveSubsystemNames(name)
    if not keys then
        return false
    end
    for i = 1, #keys do
        values.debugSubsystems[keys[i]] = enabled == true
    end
    return true
end

function NMRuntimeConfig.getSubsystemDebugNames()
    local out = {}
    for i = 1, #subsystemNames do
        out[i] = subsystemNames[i]
    end
    return out
end

function NMRuntimeConfig.getSubsystemDebugSnapshot()
    local out = {}
    local subsystems = values.debugSubsystems or {}
    for i = 1, #subsystemNames do
        local key = subsystemNames[i]
        out[key] = subsystems[key] == true
    end
    return out
end

function NMRuntimeConfig.getSubsystemDebugPresetNames()
    local out = {}
    for name in pairs(presetDefinitions) do
        out[#out + 1] = tostring(name)
    end
    table.sort(out)
    return out
end

function NMRuntimeConfig.applySubsystemDebugPreset(name, enabled)
    local preset = presetDefinitions[tostring(name or "")]
    if type(preset) ~= "table" then
        return false
    end
    for i = 1, #preset do
        values.debugSubsystems[preset[i]] = enabled ~= false
    end
    return true
end

function NMRuntimeConfig.formatSubsystemDebugSummary(snapshot)
    local subsystems = snapshot or NMRuntimeConfig.getSubsystemDebugSnapshot()
    local parts = {}
    for i = 1, #subsystemNames do
        local key = subsystemNames[i]
        parts[#parts + 1] = tostring(key) .. ":" .. tostring(subsystems[key] == true)
    end
    return table.concat(parts, ",")
end

return NMRuntimeConfig
