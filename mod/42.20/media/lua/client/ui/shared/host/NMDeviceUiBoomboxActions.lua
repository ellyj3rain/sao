-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
NMDeviceUiBoomboxActions = NMDeviceUiBoomboxActions or {}

local VALID_POLICIES = {
    autoplay = true,
    loop_song = true,
    loop_album = true,
    shuffle = true,
}

local function hasUsablePower(state)
    if not state then
        return false
    end
    if state.batteryPresent == nil then
        return true
    end
    return state.batteryPresent == true and (tonumber(state.batteryCharge) or 0) > 0
end

function NMDeviceUiBoomboxActions.execute(window, action, payload, context)
    local ctx = context or {}
    local state = ctx.state
    local dispatch = ctx.dispatch
    if type(dispatch) ~= "function" then
        return nil, nil
    end

    if action == "play" then
        local trackCount = ctx.resolveTrackCount and ctx.resolveTrackCount() or 0
        if not (state and state.isOn == true) then
            if hasUsablePower(state) ~= true then
                return false, "battery_unavailable"
            end
            local ok, reason = dispatch("power_on", {})
            if ok ~= true then
                return ok, reason
            end
        end
        return dispatch("play", { trackCount = trackCount })
    end

    if action == "power_on" then
        if hasUsablePower(state) ~= true then
            return false, "battery_unavailable"
        end
        return dispatch("power_on", {})
    end

    if action == "power_off" then
        return dispatch("power_off", {})
    end

    if action == "stop" then
        if state and state.isOn == true then
            return dispatch("stop", {})
        end
        return true, nil
    end

    if action == "eject_media" then
        if window and window.ejectMediaViaControl then
            return window:ejectMediaViaControl(), nil
        end
        return false, "missing_eject_control"
    end

    if action == "open_lid" then
        if window.isLidManuallyOpen == true then
            return true, nil
        end
        window.isLidManuallyOpen = true
        if window.syncLidFromMedia then
            window:syncLidFromMedia(false)
        end
        return true, nil
    end

    if action == "close_lid" then
        if window.isLidManuallyOpen ~= true then
            return true, nil
        end
        window.isLidManuallyOpen = false
        if window.syncLidFromMedia then
            window:syncLidFromMedia(false)
        end
        return true, nil
    end

    if action == "set_playback_policy" then
        local policy = tostring(payload and payload.playbackPolicy or "autoplay")
        if VALID_POLICIES[policy] ~= true then
            return false, "invalid_policy"
        end
        return dispatch("cycle_mode", { playbackPolicy = policy })
    end

    return nil, nil
end

return NMDeviceUiBoomboxActions
