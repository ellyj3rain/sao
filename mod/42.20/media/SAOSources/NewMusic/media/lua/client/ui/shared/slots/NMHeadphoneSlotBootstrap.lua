require "ISUI/ISButton"
require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISTimedActionQueue"
require "ui/shared/NMSlotButtonStyles"
require "ui/shared/slots/NMSlotHostLifecycle"
require "ui/shared/slots/NMPortableSlotHoverResolver"
require "ui/shared/slots/NMPortableUiSoundContract"

_G.NMHeadphoneSlot = _G.NMHeadphoneSlot or {}
_G.NMHeadphoneSlotEnv = _G.NMHeadphoneSlotEnv or {}
local env = _G.NMHeadphoneSlotEnv
if getmetatable(env) == nil then
    setmetatable(env, { __index = _G })
end

env.NMHeadphoneSlot = _G.NMHeadphoneSlot
env.playPortableUiSoundEvent = env.playPortableUiSoundEvent or function(...)
    return NMPortableUiSoundContract and NMPortableUiSoundContract.playEvent and NMPortableUiSoundContract.playEvent(...)
end
env.playSlotUISound = env.playSlotUISound or function(...)
    return NMSlotActionCommon and NMSlotActionCommon.playSlotUISound and NMSlotActionCommon.playSlotUISound(...)
end
env.safeDraggedPayload = env.safeDraggedPayload or function(...)
    if NMSlotActionCommon and NMSlotActionCommon.safeDraggedPayload then
        return NMSlotActionCommon.safeDraggedPayload(...)
    end
    return nil, false
end
env.getDraggedInventoryItems = env.getDraggedInventoryItems or function(...)
    if NMSlotActionCommon and NMSlotActionCommon.getDraggedInventoryItems then
        return NMSlotActionCommon.getDraggedInventoryItems(...)
    end
    return nil, false
end
env.clearMouseDragState = env.clearMouseDragState or function(...)
    if NMSlotActionCommon and NMSlotActionCommon.clearMouseDragState then
        return NMSlotActionCommon.clearMouseDragState(...)
    end
end
env.nextSlotTraceId = env.nextSlotTraceId or function(...)
    if NMSlotActionCommon and NMSlotActionCommon.nextSlotTraceId then
        return NMSlotActionCommon.nextSlotTraceId(...)
    end
    return "0"
end
env.canQueueSlotAction = env.canQueueSlotAction or function(...)
    if NMSlotActionCommon and NMSlotActionCommon.canQueueSlotAction then
        return NMSlotActionCommon.canQueueSlotAction(...)
    end
    return false
end

env.DRAG_THRESHOLD = env.DRAG_THRESHOLD or 4
env.SLOT_PROGRESS_FILL = env.SLOT_PROGRESS_FILL or { a = 0.60, r = 0.26, g = 0.78, b = 0.22 }
env.EMPTY_SLOT_VECTOR_COLOR = env.EMPTY_SLOT_VECTOR_COLOR or { r = 0.11, g = 0.11, b = 0.11, a = 1.00 }
env.EMPTY_HEADPHONE_ICON_SCALE = env.EMPTY_HEADPHONE_ICON_SCALE or 0.82
env.EMPTY_HEADPHONE_VECTOR_SHAPES = env.EMPTY_HEADPHONE_VECTOR_SHAPES or nil
env.HEADPHONE_TYPES = env.HEADPHONE_TYPES or {
    ["Base.Headphones"] = true,
    ["Base.Earbuds"] = true
}
env.HEADPHONE_TEXTURE_CACHE = env.HEADPHONE_TEXTURE_CACHE or {}
env.EMPTY_PLACEHOLDER_BATTERY_TEXTURE = env.EMPTY_PLACEHOLDER_BATTERY_TEXTURE or nil
env.EMPTY_PLACEHOLDER_HEADPHONE_TEXTURE = env.EMPTY_PLACEHOLDER_HEADPHONE_TEXTURE or nil

return env
