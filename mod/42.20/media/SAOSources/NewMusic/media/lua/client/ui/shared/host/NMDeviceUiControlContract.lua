require "ui/shared/host/NMDeviceUiWalkmanActions"
require "ui/shared/host/NMDeviceUiCDPlayerActions"
require "ui/shared/host/NMDeviceUiBoomboxActions"
require "ui/shared/host/NMDeviceUiGenericActions"

NMDeviceUiControlContract = NMDeviceUiControlContract or {}

local ACTIONS = {
    play = true,
    stop = true,
    power_on = true,
    power_off = true,
    next_track = true,
    prev_track = true,
    cycle_mode = true,
    set_volume = true,
    mute_on = true,
    mute_off = true,
    hold_on = true,
    hold_off = true,
    open_lid = true,
    close_lid = true,
    close_window = true,
    eject_media = true,
    set_playback_policy = true,
}

local function supportsControl(policy, action)
    local controls = type(policy and policy.controls) == "table" and policy.controls or {}
    local key = tostring(action or "")
    for i = 1, #controls do
        if tostring(controls[i] or "") == key then
            return true
        end
    end
    return false
end

function NMDeviceUiControlContract.normalizeAction(action)
    local key = tostring(action or "")
    if ACTIONS[key] == true then
        return key
    end
    return ""
end

function NMDeviceUiControlContract.supportsAction(policy, action)
    local normalized = NMDeviceUiControlContract.normalizeAction(action)
    if normalized == "" then
        return false
    end
    if normalized == "close_window" then
        return true
    end
    return supportsControl(policy, normalized)
end

local function resolveWindowState(window)
    local resolved = window and window.resolveContextFresh and window:resolveContextFresh()
        or (window and window.resolveContextCached and window:resolveContextCached())
        or (window and window.resolveContext and window:resolveContext() or nil)
    return resolved and resolved.state or nil, resolved
end

local function resolveTrackCountFromState(state)
    if not state or not state.mediaFullType or not NMMusic or not NMMusic.resolveTracks then
        return 0
    end
    local ok, resolved = pcall(NMMusic.resolveTracks, state.mediaFullType)
    if not ok or type(resolved) ~= "table" or type(resolved.tracks) ~= "table" then
        return 0
    end
    return #resolved.tracks
end

local function resolveTrackCount(window, state, resolved)
    if window and window.buildTransportState then
        local ok, transport = pcall(window.buildTransportState, window, resolved)
        if ok and type(transport) == "table" and tonumber(transport.trackCount) then
            return tonumber(transport.trackCount) or 0
        end
    end
    return resolveTrackCountFromState(state)
end

local function getCurrentPlaybackPolicy(window, state, resolved)
    if window and window.buildTransportState then
        local ok, transport = pcall(window.buildTransportState, window, resolved)
        if ok and type(transport) == "table" then
            return tostring(transport.playbackPolicy or "autoplay")
        end
    end
    return tostring(state and state.playbackPolicy or "autoplay")
end

local function getNextPlaybackPolicy(window, state, resolved)
    local policy = getCurrentPlaybackPolicy(window, state, resolved)
    local familyPolicy = window and window.getUiFamilyPolicy and window:getUiFamilyPolicy() or nil
    local supportsShuffle = familyPolicy and familyPolicy.supportsShuffleMode == true or false
    if policy == "autoplay" then
        return "loop_song"
    end
    if policy == "loop_song" then
        return "loop_album"
    end
    if policy == "loop_album" then
        if supportsShuffle then
            return "shuffle"
        end
        return "autoplay"
    end
    return "autoplay"
end

local function dispatchThroughWindow(window, action, args)
    if window and window.dispatchUiControl then
        return window:dispatchUiControl(action, args or {})
    end
    if not (window and window.dispatch) then
        return false, "missing_ui_dispatch"
    end
    return window:dispatch(action, args or {})
end

function NMDeviceUiControlContract.execute(window, action, args)
    local policy = window and window.getUiFamilyPolicy and window:getUiFamilyPolicy() or nil
    local normalized = NMDeviceUiControlContract.normalizeAction(action)
    if normalized == "" then
        return false, "unsupported_action"
    end
    if not NMDeviceUiControlContract.supportsAction(policy, normalized) then
        return false, "unsupported_action"
    end

    local payload = type(args) == "table" and args or {}
    local state = nil
    local resolved = nil
    if normalized ~= "close_window" then
        state, resolved = resolveWindowState(window)
    end

    if normalized == "close_window" then
        if window and window.close then
            window:close()
            return true, nil
        end
        return false, "missing_close"
    end

    local familyId = tostring(policy and policy.familyId or "")
    local familyContext = {
        state = state,
        resolved = resolved,
        dispatch = function(actionName, actionArgs)
            return dispatchThroughWindow(window, actionName, actionArgs)
        end,
        resolveTrackCount = function()
            return resolveTrackCount(window, state, resolved)
        end,
    }
    local handled, reason = nil, nil
    if familyId == "walkman" then
        handled, reason = NMDeviceUiWalkmanActions.execute(window, normalized, payload, familyContext)
    elseif familyId == "cdplayer" then
        handled, reason = NMDeviceUiCDPlayerActions.execute(window, normalized, payload, familyContext)
    elseif familyId == "boombox" then
        handled, reason = NMDeviceUiBoomboxActions.execute(window, normalized, payload, familyContext)
    elseif familyId == "generic" then
        handled, reason = NMDeviceUiGenericActions.execute(window, normalized, payload, familyContext)
    end
    if handled ~= nil then
        return handled, reason
    end

    if normalized == "cycle_mode" then
        local nextPolicy = tostring(payload.playbackPolicy or "")
        if nextPolicy == "" then
            nextPolicy = getNextPlaybackPolicy(window, state, resolved)
        end
        return dispatchThroughWindow(window, "cycle_mode", { playbackPolicy = nextPolicy })
    end

    if normalized == "set_playback_policy" then
        local nextPolicy = tostring(payload.playbackPolicy or "")
        if nextPolicy == "" then
            return false, "missing_policy"
        end
        return dispatchThroughWindow(window, "cycle_mode", { playbackPolicy = nextPolicy })
    end

    if normalized == "power_on" then
        if state and state.isOn == true then
            return false, "already_on"
        end
        return dispatchThroughWindow(window, "power_on", {})
    end
    if normalized == "power_off" then
        if state and state.isOn ~= true then
            return false, "already_off"
        end
        return dispatchThroughWindow(window, "power_off", {})
    end

    if normalized == "next_track" or normalized == "prev_track" then
        local trackCount = tonumber(payload.trackCount) or resolveTrackCount(window, state, resolved)
        return dispatchThroughWindow(window, normalized, { trackCount = trackCount })
    end

    if normalized == "set_volume" then
        return dispatchThroughWindow(window, "set_volume", { volume = payload.volume })
    end

    if normalized == "eject_media" then
        return dispatchThroughWindow(window, "eject_media", payload)
    end

    return dispatchThroughWindow(window, normalized, payload)
end

return NMDeviceUiControlContract
