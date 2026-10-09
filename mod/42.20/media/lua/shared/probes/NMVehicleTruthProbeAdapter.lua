-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
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

