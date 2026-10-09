NMSlotButtonStyles = NMSlotButtonStyles or {}

NMSlotButtonStyles.STATES = {
    slot = {
        enabled = true,
        bg = { r = 0.21, g = 0.21, b = 0.21, a = 0.95 },
        hover = { r = 0.21, g = 0.21, b = 0.21, a = 0.95 },
        border = { r = 0.75, g = 0.75, b = 0.75, a = 0.80 },
        text = { r = 1.00, g = 1.00, b = 1.00, a = 1.00 }
    },
    slot_hover = {
        enabled = true,
        bg = { r = 0.21, g = 0.21, b = 0.21, a = 0.95 },
        hover = { r = 0.32, g = 0.32, b = 0.32, a = 0.95 },
        border = { r = 0.78, g = 0.78, b = 0.78, a = 0.90 },
        text = { r = 1.00, g = 1.00, b = 1.00, a = 1.00 }
    },
    slot_drag = {
        enabled = true,
        bg = { r = 0.34, g = 0.34, b = 0.34, a = 0.95 },
        hover = { r = 0.39, g = 0.39, b = 0.39, a = 0.95 },
        border = { r = 0.92, g = 0.92, b = 0.92, a = 0.98 },
        text = { r = 1.00, g = 1.00, b = 1.00, a = 1.00 }
    },
    slot_filled = {
        enabled = true,
        bg = { r = 0.6078, g = 0.6078, b = 0.6078, a = 0.95 },
        hover = { r = 0.6078, g = 0.6078, b = 0.6078, a = 0.95 },
        border = { r = 0.92, g = 0.92, b = 0.92, a = 0.98 },
        text = { r = 1.00, g = 1.00, b = 1.00, a = 1.00 }
    }
}

local function applyPalette(button, style)
    button.backgroundColor = style.bg
    button.backgroundColorMouseOver = style.hover
    button.borderColor = style.border
    button.textColor = style.text
    button.backgroundColorEnabled = style.bg
    button.borderColorEnabled = style.border
end

function NMSlotButtonStyles.apply(button, stateKey)
    if not button then return end
    local resolvedKey = stateKey or "slot"
    local style = NMSlotButtonStyles.STATES[resolvedKey] or NMSlotButtonStyles.STATES.slot
    local enabled = (style.enabled == true)
    if button._nmStyleAppliedKey == resolvedKey and button._nmStyleAppliedEnabled == enabled then
        return
    end

    applyPalette(button, style)
    if button.setEnable then
        button:setEnable(enabled)
    else
        button.enable = enabled
    end
    button._nmStyleAppliedKey = resolvedKey
    button._nmStyleAppliedEnabled = enabled
end
