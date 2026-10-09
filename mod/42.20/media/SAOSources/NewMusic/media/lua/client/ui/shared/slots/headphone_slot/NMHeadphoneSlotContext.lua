_G.NMHeadphoneSlotEnv = _G.NMHeadphoneSlotEnv or {}
local env = _G.NMHeadphoneSlotEnv
if getmetatable(env) == nil then
    setmetatable(env, { __index = _G })
end
setfenv(1, env)

NMHeadphoneSlotContext = NMHeadphoneSlotContext or {}

function NMHeadphoneSlotContext.resolveWindowContext(window)
    if not window then
        return nil
    end
    if window.resolveContextCached then
        return window:resolveContextCached()
    end
    return window.resolveContext and window:resolveContext() or nil
end

function NMHeadphoneSlotContext.resolveDraggedItems(window, frame)
    if frame and frame.dragOk == true and type(frame.dragItems) == "table" then
        return frame.dragItems, true
    end
    if NMSlotHostLifecycle and NMSlotHostLifecycle.resolveDraggedItemsSnapshot then
        return NMSlotHostLifecycle.resolveDraggedItemsSnapshot(window)
    end
    return getDraggedInventoryItems()
end

function NMHeadphoneSlotContext.resolveGroundContext(window, state, resolved)
    local authoritativeMode = tostring(state and state.authoritativeMode or "")
    if NMInsertedHeadphonePolicy and NMInsertedHeadphonePolicy.isGroundContext(authoritativeMode) then
        return true
    end
    local ctx = resolved
    if not ctx then
        ctx = NMHeadphoneSlotContext.resolveWindowContext(window)
    end
    local item = ctx and ctx.item or nil
    local worldItem = item and item.getWorldItem and item:getWorldItem() or nil
    local square = worldItem and worldItem.getSquare and worldItem:getSquare() or nil
    return square ~= nil
end

return NMHeadphoneSlotContext
