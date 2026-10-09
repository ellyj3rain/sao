require "ISUI/ISButton"
require "ISUI/ISPanel"
require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISTimedActionQueue"
require "ui/shared/NMSlotButtonStyles"
require "ui/shared/slots/NMSlotHostLifecycle"
require "ui/shared/slots/NMPortableSlotHoverResolver"
require "ui/shared/slots/NMPortableUiSoundContract"

_G.NMBatterySlot = _G.NMBatterySlot or {}
_G.NMBatterySlotEnv = _G.NMBatterySlotEnv or {}
local env = _G.NMBatterySlotEnv
if getmetatable(env) == nil then
    setmetatable(env, { __index = _G })
end

env.NMBatterySlot = _G.NMBatterySlot
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

env.BATTERY_FULL_TYPE = env.BATTERY_FULL_TYPE or "Base.Battery"
env.DRAG_THRESHOLD = env.DRAG_THRESHOLD or 4
env.BAR_PAD_TOP = env.BAR_PAD_TOP or 4
env.BAR_H = env.BAR_H or 6
env.BAR_BG = env.BAR_BG or { a = 0.95, r = 0.05, g = 0.05, b = 0.05 }
env.BAR_FILL = env.BAR_FILL or { a = 0.95, r = 0.20, g = 0.80, b = 0.20 }
env.BAR_EMPTY_FILL = env.BAR_EMPTY_FILL or { a = 0.95, r = 0.80, g = 0.14, b = 0.14 }
env.SLOT_PROGRESS_FILL = env.SLOT_PROGRESS_FILL or { a = 0.60, r = 0.26, g = 0.78, b = 0.22 }
env.EMPTY_SLOT_VECTOR_COLOR = env.EMPTY_SLOT_VECTOR_COLOR or { r = 0.11, g = 0.11, b = 0.11, a = 1.00 }
env.EMPTY_BATTERY_ICON_SCALE = env.EMPTY_BATTERY_ICON_SCALE or 0.72
env.BATTERY_TEXTURE = env.BATTERY_TEXTURE or nil
env.EMPTY_BATTERY_PLACEHOLDER_TEXTURE = env.EMPTY_BATTERY_PLACEHOLDER_TEXTURE or nil
env.EMPTY_BATTERY_VECTOR_SHAPES = env.EMPTY_BATTERY_VECTOR_SHAPES or nil

return env
