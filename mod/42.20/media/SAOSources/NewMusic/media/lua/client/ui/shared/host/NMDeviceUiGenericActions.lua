NMDeviceUiGenericActions = NMDeviceUiGenericActions or {}

function NMDeviceUiGenericActions.execute(window, action, payload, context)
    local ctx = context or {}
    local dispatch = ctx.dispatch
    if type(dispatch) ~= "function" then
        return nil, nil
    end

    if action == "play" or action == "stop" then
        local trackCount = ctx.resolveTrackCount and ctx.resolveTrackCount() or 0
        return dispatch(action, { trackCount = trackCount })
    end

    if action == "mute_on" then
        return dispatch("mute_on", {
            isMuted = true,
            muteReason = tostring(payload and payload.muteReason or "manual"),
        })
    end

    if action == "mute_off" then
        return dispatch("mute_off", {
            isMuted = false,
            muteReason = tostring(payload and payload.muteReason or "manual"),
        })
    end

    return nil, nil
end

return NMDeviceUiGenericActions
