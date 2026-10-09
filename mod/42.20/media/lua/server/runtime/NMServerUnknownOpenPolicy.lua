-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
NMServerUnknownOpenPolicy = NMServerUnknownOpenPolicy or {}

function NMServerUnknownOpenPolicy.handleUnknownOpenState(entry, state, progressionCurrent, nowMsValue, stores, emitFn)
    stores = stores or {}
    local blockedSigStore = stores.blockedSigStore or {}
    local heartbeatStore = stores.heartbeatStore or {}
    local logRuntimeProbe = type(emitFn) == "function" and emitFn or function() end

    local uuid = tostring(entry and entry.uuid or "")
    local token = string.format("%s:%s", tostring(tonumber(state and state.playbackEpoch) or 0), tostring(tonumber(state and state.trackIndex) or 0))
    local blockedSig = table.concat({ uuid, token, "unknown_open" }, "|")
    if tostring(blockedSigStore[uuid] or "") ~= blockedSig then
        blockedSigStore[uuid] = blockedSig
        logRuntimeProbe(
            "unknown_open_due_blocked",
            string.format(
                "uuid=%s token=%s reason=unknown_open_no_due_advance",
                tostring(uuid),
                tostring(token)
            )
        )
    end

    local stallHeartbeatKey = tostring(uuid) .. "|" .. tostring(token)
    local durationSourceDiagnostic = tostring(progressionCurrent and progressionCurrent.source or "fallback")
    if durationSourceDiagnostic == "fallback" then
        durationSourceDiagnostic = "fallback_non_authoritative"
    end
    local lastHeartbeat = tonumber(heartbeatStore[stallHeartbeatKey]) or 0
    if (nowMsValue - lastHeartbeat) >= NMRuntimeProbeAdapter.longHeartbeatMs() then
        heartbeatStore[stallHeartbeatKey] = nowMsValue
        logRuntimeProbe(
            "unknown_open_stall_observed",
            string.format(
                "uuid=%s token=%s isOn=%s isPlaying=%s timingMode=unknown_open durationSourceDiagnostic=%s",
                tostring(uuid),
                tostring(token),
                tostring(state and state.isOn == true),
                tostring(state and state.isPlaying == true),
                tostring(durationSourceDiagnostic)
            )
        )
    end
end

return NMServerUnknownOpenPolicy

