NMDeviceUiWalkmanActions = NMDeviceUiWalkmanActions or {}

function NMDeviceUiWalkmanActions.execute(window, action, payload, context)
    local ctx = context or {}
    local state = ctx.state
    local dispatch = ctx.dispatch
    if type(dispatch) ~= "function" then
        return nil, nil
    end

    if action == "play" then
        local trackCount = ctx.resolveTrackCount and ctx.resolveTrackCount() or 0
        if not (state and state.isOn == true) then
            local ok, reason = dispatch("power_on", {})
            if ok ~= true then
                return ok, reason
            end
        end
        return dispatch("play", { trackCount = trackCount })
    end

    if action == "stop" then
        return dispatch("power_off", {})
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
        if window.hasInsertedCassette and window:hasInsertedCassette() == true and window.ejectMediaViaLid then
            return window:ejectMediaViaLid(), nil
        end
        if window.isLidManuallyOpen ~= true then
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

return NMDeviceUiWalkmanActions
