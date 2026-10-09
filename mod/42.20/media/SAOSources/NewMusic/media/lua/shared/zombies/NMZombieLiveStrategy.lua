NMZombieLiveStrategy = NMZombieLiveStrategy or {}

local VALID_STRATEGIES = {
    sp_runtime_attach = true,
    mp_assignment_flow = true
}

local STRATEGY_ALIASES = {
    -- Compatibility-only aliases for persisted config or stale diagnostics.
    mp_runtime_attach_with_support = "mp_assignment_flow",
    mp_legacy_assignment_flow = "mp_assignment_flow"
}

local function runtimeMode()
    if NMCore and NMCore.getRuntimeAuthorityMode then
        return tostring(NMCore.getRuntimeAuthorityMode() or "")
    end
    return ""
end

local function readConfiguredStrategy(key, fallback)
    local runtime = type(NMRuntimeConfig) == "table" and NMRuntimeConfig or nil
    local configured = runtime and runtime.get and tostring(runtime.get(key, fallback) or fallback) or tostring(fallback or "")
    configured = tostring(STRATEGY_ALIASES[configured] or configured)
    if VALID_STRATEGIES[configured] == true then
        return configured
    end
    return tostring(fallback or "")
end

function NMZombieLiveStrategy.getLiveVisualStrategy()
    if NMCore and NMCore.isMultiplayerMode and NMCore.isMultiplayerMode() == true then
        return readConfiguredStrategy("zombieLiveVisualStrategyMP", "mp_assignment_flow")
    end
    return readConfiguredStrategy("zombieLiveVisualStrategySP", "sp_runtime_attach")
end

function NMZombieLiveStrategy.shouldRunSPRuntimeAttach()
    return NMZombieLiveStrategy.getLiveVisualStrategy() == "sp_runtime_attach"
        and not (NMCore and NMCore.isMPClientRuntime and NMCore.isMPClientRuntime() == true)
end

function NMZombieLiveStrategy.shouldRunMPAssignmentFlow()
    return NMZombieLiveStrategy.getLiveVisualStrategy() == "mp_assignment_flow"
        and not (NMCore and NMCore.isMPClientRuntime and NMCore.isMPClientRuntime() == true)
end

function NMZombieLiveStrategy.shouldRunMPLegacyAssignmentFlow()
    return NMZombieLiveStrategy.shouldRunMPAssignmentFlow()
end

function NMZombieLiveStrategy.getRuntimeSummary()
    return string.format(
        "mode=%s strategy=%s",
        runtimeMode(),
        tostring(NMZombieLiveStrategy.getLiveVisualStrategy())
    )
end

return NMZombieLiveStrategy
