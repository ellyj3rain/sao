NMDeviceUiSlotContract = NMDeviceUiSlotContract or {}

local function copyTable(values)
    local out = {}
    for key, value in pairs(values or {}) do
        out[key] = value
    end
    return out
end

function NMDeviceUiSlotContract.buildContentState(slotId, spec)
    local fullType = tostring(spec and spec.fullType or "")
    local occupied = fullType ~= ""
    local texture = spec and spec.texture or nil
    local placeholderKey = tostring(spec and spec.placeholderKey or "")
    local acceptedFullTypes = copyTable(spec and spec.acceptedFullTypes or {})
    local acceptedCarriers = copyTable(spec and spec.acceptedCarriers or {})
    local state = {
        slotId = tostring(slotId or ""),
        styleKey = occupied and "slot_filled" or "slot",
        occupied = occupied,
        fullType = fullType,
        fillPct = spec and spec.fillPct or nil,
        tooltip = spec and spec.tooltip or nil,
        supported = spec and spec.supported ~= false or true,
        texture = texture,
        placeholderKey = placeholderKey ~= "" and placeholderKey or nil,
        content = {
            fullType = fullType,
            occupied = occupied,
            texture = texture,
        },
        acceptance = {
            acceptedFullTypes = acceptedFullTypes,
            acceptedCarriers = acceptedCarriers,
            insertAction = tostring(spec and spec.insertAction or ""),
            ejectAction = tostring(spec and spec.ejectAction or ""),
        },
        presentation = {
            placeholderKey = placeholderKey ~= "" and placeholderKey or nil,
            tooltip = spec and spec.tooltip or nil,
            texture = texture,
        },
    }
    for key, value in pairs(spec or {}) do
        if state[key] == nil then
            state[key] = value
        end
    end
    return state
end

function NMDeviceUiSlotContract.buildInteractionState(slotId, spec)
    return {
        slotId = tostring(slotId or ""),
        styleKey = tostring(spec and spec.styleKey or "slot"),
        mouseOver = spec and spec.mouseOver == true or false,
        dragActive = spec and spec.dragActive == true or false,
        canAcceptDrag = spec and spec.canAcceptDrag == true or false,
    }
end

function NMDeviceUiSlotContract.compose(contentState, interactionState)
    if type(contentState) ~= "table" then
        return interactionState
    end
    if type(interactionState) ~= "table" then
        return contentState
    end
    local composed = copyTable(contentState)
    for key, value in pairs(interactionState) do
        composed[key] = value
    end
    return composed
end

return NMDeviceUiSlotContract
