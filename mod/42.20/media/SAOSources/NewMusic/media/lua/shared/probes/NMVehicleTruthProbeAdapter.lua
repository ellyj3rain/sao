-- Shared vehicle truth probe adapter with transition + heartbeat dedupe.
NMVehicleTruthProbeAdapter = NMVehicleTruthProbeAdapter or {}

function NMVehicleTruthProbeAdapter.emit(storeSig, storeMs, key, sig, intervalMs, emitFn)
    if NMRuntimeProbeAdapter.shouldEmitTransitionOrHeartbeat(storeSig, storeMs, key, sig, intervalMs) then
        emitFn()
        return true
    end
    return false
end

return NMVehicleTruthProbeAdapter

