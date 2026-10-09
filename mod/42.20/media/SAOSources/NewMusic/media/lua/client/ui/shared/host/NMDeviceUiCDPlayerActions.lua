NMDeviceUiCDPlayerActions = NMDeviceUiCDPlayerActions or {}

function NMDeviceUiCDPlayerActions.execute(window, action, payload, context)
    local ctx = context or {}
    local dispatch = ctx.dispatch
    if type(dispatch) ~= "function" then
        return nil, nil
    end

    if action == "play" or action == "stop" then
        local trackCount = ctx.resolveTrackCount and ctx.resolveTrackCount() or 0
        return dispatch(action, { trackCount = trackCount })
    end

    if action == "hold_on" then
        return dispatch("hold_on", {})
    end

    if action == "hold_off" then
        return dispatch("hold_off", {})
    end

    if action == "open_lid" then
        if window.isLidOpen == true then
            return true, nil
        end
        window.isLidManuallyOpen = true
        if window.syncLidFromMedia then
            window:syncLidFromMedia(false)
        end
        return true, nil
    end

    if action == "close_lid" then
        if window.isLidOpen ~= true then
            return true, nil
        end
        window.isLidManuallyOpen = false
        if window.syncLidFromMedia then
            window:syncLidFromMedia(false)
        end
        return true, nil
    end

    return nil, nil
end

return NMDeviceUiCDPlayerActions
