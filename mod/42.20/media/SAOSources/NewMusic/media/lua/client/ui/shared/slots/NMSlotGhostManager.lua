NMSlotGhostManager = NMSlotGhostManager or {}

local function resolveActiveDrag()
    local batterySrc = NMBatterySlot and NMBatterySlot._ghostDragWindow or nil
    local batteryDrag = batterySrc and batterySrc._nmBatteryExtractDrag or nil
    if batteryDrag and batteryDrag.moved and batteryDrag.iconTex then
        return batterySrc, batteryDrag
    end

    local mediaSrc = NMMediaSlot and NMMediaSlot._ghostDragWindow or nil
    local mediaDrag = mediaSrc and mediaSrc._nmMediaExtractDrag or nil
    if mediaDrag and mediaDrag.moved and mediaDrag.iconTex then
        return mediaSrc, mediaDrag
    end

    local headphoneSrc = NMHeadphoneSlot and NMHeadphoneSlot._ghostDragWindow or nil
    local headphoneDrag = headphoneSrc and headphoneSrc._nmHeadphoneExtractDrag or nil
    if headphoneDrag and headphoneDrag.moved and headphoneDrag.iconTex then
        return headphoneSrc, headphoneDrag
    end

    return nil, nil
end

function NMSlotGhostManager.getActiveDrag()
    return resolveActiveDrag()
end

function NMSlotGhostManager.hasActiveDrag()
    local _, drag = resolveActiveDrag()
    return drag ~= nil
end

return NMSlotGhostManager
