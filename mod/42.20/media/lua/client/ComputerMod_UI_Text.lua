-- Integrated source: ComputerModkum; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("ComputerModkum") then return end
require "ISUI/ISUIElement"
require "ISUI/ISButton"

ComputerModUIText = ComputerModUIText or {}
ComputerModUIText.ActiveUserScale = ComputerModUIText.ActiveUserScale or 1
ComputerModUIText.ActiveInterfaceScale = ComputerModUIText.ActiveInterfaceScale or 1

local function isFont(font, name)
    return UIFont and UIFont[name] and font == UIFont[name]
end

local function getTargetHeight(font)
    if isFont(font, "Small") or isFont(font, "NewSmall") then
        return 17
    end
    if isFont(font, "Medium") or isFont(font, "NewMedium") or isFont(font, "Normal") then
        return 23
    end
    if isFont(font, "Large") or isFont(font, "NewLarge") then
        return 27
    end
    return nil
end

local function getRawHeight(font)
    local textManager = getTextManager and getTextManager() or nil
    if textManager and textManager.getFontHeight then
        local height = textManager:getFontHeight(font or UIFont.Small)
        if tonumber(height) and tonumber(height) > 0 then
            return tonumber(height)
        end
    end
    return getTargetHeight(font) or 14
end

local function getRawWidth(font, text)
    local value = tostring(text or "")
    local textManager = getTextManager and getTextManager() or nil
    if textManager and textManager.MeasureStringX then
        local width = textManager:MeasureStringX(font or UIFont.Small, value)
        if tonumber(width) then
            return math.max(0, tonumber(width))
        end
    end
    return string.len(value) * 7
end

function ComputerModUIText.getFontZoom(font)
    local resolvedFont = font or UIFont.Small
    local targetHeight = getTargetHeight(resolvedFont)
    if not targetHeight then return 1 end
    return math.min(1, targetHeight / math.max(1, getRawHeight(resolvedFont)))
end

function ComputerModUIText.getLineHeight(font)
    local resolvedFont = font or UIFont.Small
    local zoom = math.min(3.5, ComputerModUIText.getFontZoom(resolvedFont) * ComputerModUIText.ActiveUserScale * ComputerModUIText.ActiveInterfaceScale)
    return math.max(1, math.floor(getRawHeight(resolvedFont) * zoom + 0.5))
end

function ComputerModUIText.measureText(font, text, zoom)
    local resolvedFont = font or UIFont.Small
    local resolvedZoom = tonumber(zoom) or math.min(3.5, ComputerModUIText.getFontZoom(resolvedFont) * ComputerModUIText.ActiveUserScale * ComputerModUIText.ActiveInterfaceScale)
    return getRawWidth(resolvedFont, text) * resolvedZoom
end

local function getUserScale(element)
    local current = element
    while current do
        local scale = tonumber(current.ComputerModUserTextScale)
        if scale then return math.max(0.75, math.min(1.5, scale)) end
        current = current.parent
    end
    return math.max(0.75, math.min(1.5, tonumber(ComputerModUIText.ActiveUserScale) or 1))
end

local function getInterfaceScale(element)
    local current = element
    while current do
        local scale = tonumber(current.ComputerModInterfaceScale)
        if scale then return math.max(0.75, math.min(3, scale)) end
        current = current.parent
    end
    return math.max(0.75, math.min(3, tonumber(ComputerModUIText.ActiveInterfaceScale) or 1))
end

local function getElementZoom(element, font)
    local scale = tonumber(element and element.ComputerModTextScale) or 1
    return math.min(3.5, ComputerModUIText.getFontZoom(font) * math.max(0.1, scale) * getUserScale(element) * getInterfaceScale(element))
end

function ComputerModUIText.setUserScale(element, scale)
    local value = math.max(0.75, math.min(1.5, tonumber(scale) or 1))
    ComputerModUIText.ActiveUserScale = value
    if element then element.ComputerModUserTextScale = value end
end


function ComputerModUIText.setInterfaceScale(element, scale)
    local value = math.max(0.75, math.min(3, tonumber(scale) or 1))
    ComputerModUIText.ActiveInterfaceScale = value
    if element then element.ComputerModInterfaceScale = value end
end

local function getElementBounds(element, x, y)
    local width = element.getWidth and element:getWidth() or element.width or 0
    local height = element.getHeight and element:getHeight() or element.height or 0
    local left = 0
    local top = 0
    local right = math.max(0, tonumber(width) or 0)
    local bottom = math.max(0, tonumber(height) or 0)
    local screenX = tonumber(element.screenX)
    local screenY = tonumber(element.screenY)
    local screenW = tonumber(element.screenWidth)
    local screenH = tonumber(element.screenHeight)
    if screenX and screenY and screenW and screenH then
        local px = tonumber(x) or 0
        local py = tonumber(y) or 0
        if px >= screenX - 1 and px <= screenX + screenW + 1 and py >= screenY - 1 and py <= screenY + screenH + 1 then
            left = screenX
            top = screenY
            right = screenX + screenW
            bottom = screenY + screenH
        end
    end
    return left, top, right, bottom
end

local function fitZoom(element, text, x, y, font, zoom, alignment, maxWidth, maxHeight)
    local rawWidth = getRawWidth(font, text)
    local rawHeight = getRawHeight(font)
    local left, top, right, bottom = getElementBounds(element, x, y)
    local available = tonumber(maxWidth)
    if rawWidth > 0 and not available then
        if alignment == "right" then
            available = (tonumber(x) or 0) - left - 2
        elseif alignment == "center" then
            available = math.min((tonumber(x) or 0) - left, right - (tonumber(x) or 0)) * 2 - 4
        else
            available = right - (tonumber(x) or 0) - 2
        end
    end
    if rawWidth > 0 and available and available > 0 and rawWidth * zoom > available then
        zoom = math.max(0.05, available / rawWidth)
    end
    local drawY = tonumber(y) or 0
    if rawHeight > 0 and drawY >= top and drawY < bottom then
        local availableHeight = math.min(bottom - drawY, tonumber(maxHeight) or (bottom - drawY))
        if rawHeight * zoom > availableHeight then
            zoom = math.max(0.05, availableHeight / rawHeight)
        end
    end
    return zoom
end

local function drawLine(element, text, x, y, r, g, b, a, font, alignment, maxWidth, maxHeight)
    local resolvedFont = font or UIFont.Small
    local zoom = fitZoom(element, text, x, y, resolvedFont, getElementZoom(element, resolvedFont), alignment, maxWidth, maxHeight)
    local rawWidth = getRawWidth(resolvedFont, text)
    local drawX = tonumber(x) or 0
    if alignment == "right" then
        drawX = drawX - rawWidth * zoom
    elseif alignment == "center" then
        drawX = drawX - rawWidth * zoom * 0.5
    end
    ISUIElement.drawTextZoomed(element, tostring(text or ""), drawX, tonumber(y) or 0, zoom, r, g, b, a, resolvedFont)
end

local function drawText(element, text, x, y, r, g, b, a, font, alignment, maxWidth, maxHeight)
    if text == nil then return end
    local value = tostring(text):gsub("\r\n", "\n")
    local resolvedFont = font or UIFont.Small
    local lineHeight = math.max(1, math.floor(getRawHeight(resolvedFont) * getElementZoom(element, resolvedFont) + 0.5))
    local index = 0
    for line in string.gmatch(value .. "\n", "(.-)\n") do
        drawLine(element, line, x, (tonumber(y) or 0) + index * lineHeight, r, g, b, a, font, alignment, maxWidth, maxHeight)
        index = index + 1
    end
end

function ComputerModUIText.drawText(element, text, x, y, r, g, b, a, font)
    drawText(element, text, x, y, r, g, b, a, font, "left", nil)
end

function ComputerModUIText.drawTextCentre(element, text, x, y, r, g, b, a, font)
    drawText(element, text, x, y, r, g, b, a, font, "center", nil)
end

function ComputerModUIText.drawTextRight(element, text, x, y, r, g, b, a, font)
    drawText(element, text, x, y, r, g, b, a, font, "right", nil)
end

function ComputerModUIText.drawTextInWidth(element, text, x, y, maxWidth, r, g, b, a, font, alignment, maxHeight)
    local mode = alignment or "left"
    local drawX = tonumber(x) or 0
    if mode == "center" then
        drawX = drawX + (tonumber(maxWidth) or 0) * 0.5
    elseif mode == "right" then
        drawX = drawX + (tonumber(maxWidth) or 0)
    end
    drawText(element, text, drawX, y, r, g, b, a, font, mode, maxWidth, maxHeight)
end

function ComputerModUIText.installPanelClass(panelClass, scale)
    if not panelClass then return end
    panelClass.ComputerModResponsiveTextInstalled = true
    panelClass.ComputerModTextScale = tonumber(scale) or panelClass.ComputerModTextScale or 1
    panelClass.drawText = ComputerModUIText.drawText
    panelClass.drawTextCentre = ComputerModUIText.drawTextCentre
    panelClass.drawTextRight = ComputerModUIText.drawTextRight
    panelClass.drawTextInWidth = ComputerModUIText.drawTextInWidth
end

function ComputerModUIText.renderButton(button)
    local title = tostring(button.title or "")
    button.title = ""
    ISButton.render(button)
    button.title = title
    if title == "" then return end
    local font = button.font or UIFont.Small
    local rawWidth = getRawWidth(font, title)
    local rawHeight = getRawHeight(font)
    local zoom = getElementZoom(button, font)
    local availableWidth = math.max(1, (button.width or 0) - 6)
    local availableHeight = math.max(1, (button.height or 0) - 4)
    if rawWidth > 0 then
        zoom = math.min(zoom, availableWidth / rawWidth)
    end
    if rawHeight > 0 then
        zoom = math.min(zoom, availableHeight / rawHeight)
    end
    zoom = math.max(0.05, zoom)
    local x = button.titleLeft and 3 or ((button.width or 0) - rawWidth * zoom) * 0.5
    local y = ((button.height or 0) - rawHeight * zoom) * 0.5 + (button.yoffset or 0)
    local color = button.textColor or {r=0, g=0, b=0, a=1}
    if not button.enable then
        color = {r=0.3, g=0.3, b=0.3, a=1}
    end
    ISUIElement.drawTextZoomed(button, title, x, y, zoom, color.r or 0, color.g or 0, color.b or 0, color.a or 1, font)
end

function ComputerModUIText.installButton(button)
    if not button or button.ComputerModResponsiveTextInstalled then return end
    button.ComputerModResponsiveTextInstalled = true
    button.drawText = ComputerModUIText.drawText
    button.drawTextCentre = ComputerModUIText.drawTextCentre
    button.drawTextRight = ComputerModUIText.drawTextRight
    button.drawTextInWidth = ComputerModUIText.drawTextInWidth
    button.render = ComputerModUIText.renderButton
end
