_G.NMHeadphoneSlotEnv = _G.NMHeadphoneSlotEnv or {}
local env = _G.NMHeadphoneSlotEnv
if getmetatable(env) == nil then
    setmetatable(env, { __index = _G })
end
setfenv(1, env)

NMHeadphoneSlotActions = NMHeadphoneSlotActions or {}

function NMHeadphoneSlotActions.queueHeadphoneSlotAction(window, actionName, args, options)
    if not window then
        return false
    end
    if window._nmSlotRangeGateEnabled ~= false and not canQueueSlotAction(window) then
        return false
    end
    local payload = args or {}
    if payload.slotTraceId == nil then
        payload.slotTraceId = nextSlotTraceId()
    end
    local resolved = NMHeadphoneSlotContext.resolveWindowContext(window)
    local playerObj = resolved and resolved.player or nil
    local immediate = options and options.immediate == true
    local pendingEjectFullType = tostring(window._nmPendingHeadphoneSlotFullType or "")
    if immediate or not (playerObj and ISTimedActionQueue and NMHeadphoneSlotTimedAction) then
        local ok = window:dispatchSlotAction(actionName, payload)
        if ok == true and actionName == "eject_headphones" and pendingEjectFullType ~= "" then
            NMHeadphoneSlotAuthority.markAwaitingAuthoritativeHeadphoneEject(window, pendingEjectFullType)
        end
        if ok ~= true and actionName == "eject_headphones" then
            NMHeadphoneSlotAuthority.clearAwaitingAuthoritativeHeadphoneEject(window)
        end
        return ok
    end
    ISTimedActionQueue.add(NMHeadphoneSlotTimedAction:new(playerObj, window, actionName, payload))
    return true
end

function NMHeadphoneSlotActions.getContextMenuPoint(button, x, y)
    local bx = button and button.getAbsoluteX and button:getAbsoluteX() or (getMouseX and getMouseX() or 0)
    local by = button and button.getAbsoluteY and button:getAbsoluteY() or (getMouseY and getMouseY() or 0)
    return bx + (tonumber(x) or 0), by + (tonumber(y) or 0)
end

return NMHeadphoneSlotActions
