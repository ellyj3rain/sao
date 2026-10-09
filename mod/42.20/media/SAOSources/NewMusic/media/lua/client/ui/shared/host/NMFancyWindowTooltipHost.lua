NMFancyWindowTooltipHost = NMFancyWindowTooltipHost or {}

local function ensureTooltipUi(window)
    if not window then
        return nil
    end
    if not window.tooltipUI then
        window.tooltipUI = ISToolTip:new()
        window.tooltipUI:initialise()
        window.tooltipUI:instantiate()
        window.tooltipUI:setOwner(window)
        window.tooltipUI:setVisible(false)
        window.tooltipUI:setAlwaysOnTop(true)
        window.tooltipUI.followMouse = false
    end
    return window.tooltipUI
end

local function resolveTooltipOptions(window, text)
    local options = window and window.getTooltipUiOptions and window:getTooltipUiOptions(text) or nil
    if type(options) ~= "table" then
        options = {}
    end
    local maxLineWidth = tonumber(options.maxLineWidth) or 300
    local offsetY = tonumber(options.offsetY) or 24
    local cacheText = options.cacheText ~= false
    return {
        maxLineWidth = maxLineWidth,
        offsetY = offsetY,
        cacheText = cacheText,
    }
end

function NMFancyWindowTooltipHost.updateHoverTooltip(window)
    if not (window and window.getHoverTooltipAt) then
        return nil
    end
    local absX = window.getAbsoluteX and window:getAbsoluteX() or 0
    local absY = window.getAbsoluteY and window:getAbsoluteY() or 0
    local localX = (getMouseX and getMouseX() or 0) - absX
    local localY = (getMouseY and getMouseY() or 0) - absY
    if localX < 0 or localY < 0 or localX >= window.width or localY >= window.height then
        window.tooltip = nil
        return nil
    end
    window.tooltip = window:getHoverTooltipAt(localX, localY)
    return window.tooltip
end

function NMFancyWindowTooltipHost.hideTooltipUi(window)
    if not window then
        return
    end
    if window.tooltipUI and window.tooltipUI:getIsVisible() then
        window.tooltipUI:setVisible(false)
        window.tooltipUI:removeFromUIManager()
    end
    window._nmTooltipLastText = nil
end

function NMFancyWindowTooltipHost.updateTooltipUi(window)
    local text = tostring(window and window.tooltip or "")
    if text == "" then
        NMFancyWindowTooltipHost.hideTooltipUi(window)
        return
    end

    local tooltipUi = ensureTooltipUi(window)
    local options = resolveTooltipOptions(window, text)
    if not tooltipUi:getIsVisible() then
        tooltipUi.maxLineWidth = options.maxLineWidth
        tooltipUi:addToUIManager()
        tooltipUi:setVisible(true)
    end
    if tonumber(tooltipUi.maxLineWidth) ~= options.maxLineWidth then
        tooltipUi.maxLineWidth = options.maxLineWidth
    end
    if options.cacheText ~= true or tostring(window._nmTooltipLastText or "") ~= text then
        tooltipUi.description = text
        window._nmTooltipLastText = text
    end
    tooltipUi:setDesiredPosition(getMouseX and getMouseX() or 0, (getMouseY and getMouseY() or 0) + options.offsetY)
end

_G.NMFancyWindowTooltipHost = NMFancyWindowTooltipHost

return NMFancyWindowTooltipHost
