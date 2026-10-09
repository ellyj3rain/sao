local NMClientRegistrySyncLogging = {}

local function runtimeDebugEnabled()
    return NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") == true or false
end

function NMClientRegistrySyncLogging.emitRequestNow(reason, nowMs)
    if not runtimeDebugEnabled() then
        return
    end
    local reasonKey = reason ~= nil and tostring(reason) or "unspecified"
    local gateKey = "runtimeProbe.registry_sync_request_now." .. reasonKey
    if not NMCore.shouldLogEvery or NMCore.shouldLogEvery(gateKey, nowMs, 15000) then
        NMRuntimeProbeAdapter.emit("runtime", "runtime", "registry_sync_request_now", "reason=" .. reasonKey)
    end
end

return NMClientRegistrySyncLogging
