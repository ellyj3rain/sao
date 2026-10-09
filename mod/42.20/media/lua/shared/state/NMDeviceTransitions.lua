-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
-- Stateless transition rules applied to mutable device state records.
NMDeviceTransitions = NMDeviceTransitions or {}

local enforcePlayableByAction = {
    play = true,
    power_on = true,
    power_off = true,
    eject_media = true,
    eject_battery = true,
    track_finished = true
}

function NMDeviceTransitions.apply(profile, state, action, payload)
    if not profile or not state then
        return false, "invalid_state", nil
    end
    payload = payload or {}
    action = tostring(action or "")

    local ops = {}
    local changed, reason = NMTransitionActionHandlers.apply(profile, state, action, payload, ops)
    if reason then
        return false, reason, nil
    end

    if enforcePlayableByAction[action] and NMTransitionCommon.enforcePlayableState(profile, state, payload) then
        changed = true
    end
    return changed, nil, ops
end



