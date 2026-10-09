require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "ISUI/ISTickBox"
require "ISUI/ISComboBox"
require "RadioCom/ISUIRadio/ISSliderPanel"

NMFancySettingsWindow = NMFancySettingsWindow or {}

local ClientModOptions = rawget(_G, "NMClientModOptions") or require "runtime/NMClientModOptions"

local WINDOW_TITLE_KEY = "ContextMenu_StoveSetting"
local WINDOW_FALLBACK_TITLE = "Settings"
local GEAR_TEXTURE_PATH = "media/textures/UI/UI_NM_Gear.png"
local WINDOW_GAP = 12
local PADDING = 12
local ROW_HEIGHT = 22
local ROW_GAP = 8
local LABEL_GAP = 12
local CONTROL_WIDTH = 240
local BUTTON_WIDTH = 90
local BUTTON_HEIGHT = 26
local SLIDER_VALUE_WIDTH = 52
local GEAR_SCALE = 1.1

local QuickAccessWindow = ISCollapsableWindow:derive("NMFancyQuickAccessSettingsWindow")

local function getSettingsText()
    if getText then
        local translated = getText(WINDOW_TITLE_KEY)
        if translated and translated ~= WINDOW_TITLE_KEY then
            return translated
        end
    end
    return WINDOW_FALLBACK_TITLE
end

local function setTooltip(element, text)
    if not element then
        return
    end
    element.tooltip = text
    if element.isSliderPanel == true then
        element.toolTipText = text
    else
        element.toolTip = text
    end
    if element.setTooltip then
        element:setTooltip(text)
    end
end

local function getExpandedRect(rect, scale)
    if not rect then
        return nil
    end
    local resolvedScale = tonumber(scale) or 1.0
    if resolvedScale <= 1.0 then
        return {
            x = rect.x,
            y = rect.y,
            w = rect.w,
            h = rect.h,
        }
    end
    local width = math.max(1, math.floor((rect.w * resolvedScale) + 0.5))
    local height = math.max(1, math.floor((rect.h * resolvedScale) + 0.5))
    return {
        x = rect.x - math.floor(((width - rect.w) * 0.5) + 0.5),
        y = rect.y - math.floor(((height - rect.h) * 0.5) + 0.5),
        w = width,
        h = height,
    }
end

local function getGearTexture()
    if NMFancyDeviceUiScale and NMFancyDeviceUiScale.getTexture then
        return NMFancyDeviceUiScale.getTexture(GEAR_TEXTURE_PATH)
    end
    return getTexture and getTexture(GEAR_TEXTURE_PATH) or nil
end

local function resolveGearTint(window, model)
    if window and window.resolveSettingsGearTint then
        local alpha, r, g, b = window:resolveSettingsGearTint(model)
        return tonumber(alpha) or 1.0, tonumber(r) or 1.0, tonumber(g) or 1.0, tonumber(b) or 1.0
    end
    if model and type(model.closeTint) == "table" then
        return 1.0, tonumber(model.closeTint[1]) or 1.0, tonumber(model.closeTint[2]) or 1.0, tonumber(model.closeTint[3]) or 1.0
    end
    return 1.0, 1.0, 1.0, 1.0
end

local function getFontHeight(font)
    local tm = getTextManager and getTextManager() or nil
    if not (tm and tm.getFontFromEnum) then
        return 14
    end
    local resolved = tm:getFontFromEnum(font or UIFont.Small)
    return resolved and resolved:getLineHeight() or 14
end

local function measureTextWidth(font, text)
    local tm = getTextManager and getTextManager() or nil
    if not (tm and tm.MeasureStringX) then
        return string.len(tostring(text or "")) * 7
    end
    return tm:MeasureStringX(font or UIFont.Small, tostring(text or ""))
end

local function clamp(value, minValue, maxValue)
    local numeric = tonumber(value) or minValue
    if numeric < minValue then
        return minValue
    end
    if numeric > maxValue then
        return maxValue
    end
    return numeric
end

local function roundToStep(value, step, minValue, maxValue)
    local resolvedStep = tonumber(step) or 1
    local numeric = tonumber(value) or minValue
    if resolvedStep <= 0 then
        return clamp(numeric, minValue, maxValue)
    end
    local snapped = minValue + (math.floor((((numeric - minValue) / resolvedStep) + 0.5)) * resolvedStep)
    return clamp(snapped, minValue, maxValue)
end

local function formatPercent(value)
    local numeric = tonumber(value) or 0
    return string.format("%d%%", math.floor((numeric * 100) + 0.5))
end

local function updateSliderValueLabel(valueLabel, value)
    if not valueLabel then
        return
    end
    valueLabel:setName(formatPercent(value))
    if valueLabel.setWidthToContents then
        valueLabel:setWidthToContents()
    end
    valueLabel:setX(math.max(0, SLIDER_VALUE_WIDTH - valueLabel:getWidth()))
end

local function getScreenRect(window)
    if not window then
        return nil
    end
    local x = window.getAbsoluteX and window:getAbsoluteX() or window.getX and window:getX() or nil
    local y = window.getAbsoluteY and window:getAbsoluteY() or window.getY and window:getY() or nil
    local w = tonumber(window.width) or window.getWidth and window:getWidth() or 0
    local h = tonumber(window.height) or window.getHeight and window:getHeight() or 0
    if x == nil or y == nil or w <= 0 or h <= 0 then
        return nil
    end
    return { x = x, y = y, w = w, h = h }
end

local function computeWindowMetrics(specs)
    local labelWidth = 0
    for i = 1, #specs do
        labelWidth = math.max(labelWidth, measureTextWidth(UIFont.Small, tostring(specs[i].label or "")))
    end
    labelWidth = labelWidth + LABEL_GAP
    local width = PADDING + labelWidth + CONTROL_WIDTH + PADDING
    local bodyHeight = PADDING + (#specs * ROW_HEIGHT) + ((#specs - 1) * ROW_GAP) + ROW_GAP + BUTTON_HEIGHT + PADDING
    local titleHeight = getFontHeight(UIFont.Small) + 10
    local height = bodyHeight + titleHeight + 8
    return {
        width = math.max(280, width),
        height = math.max(180, height),
        labelWidth = labelWidth,
        rowY = PADDING + 4,
    }
end

local function computeSpawnPosition(sourceWindow, width, height)
    local screenW = getCore and getCore():getScreenWidth() or 1920
    local screenH = getCore and getCore():getScreenHeight() or 1080
    local x = math.max(0, math.floor((screenW - width) * 0.5))
    local y = math.max(0, math.floor((screenH - height) * 0.5))
    local sourceRect = getScreenRect(sourceWindow)
    if not sourceRect then
        return x, y
    end

    local preferredLeft = sourceRect.x - width - WINDOW_GAP
    local preferredRight = sourceRect.x + sourceRect.w + WINDOW_GAP
    if preferredLeft >= 0 then
        x = preferredLeft
    elseif preferredRight + width <= screenW then
        x = preferredRight
    else
        x = math.max(0, math.min(sourceRect.x, screenW - width))
    end

    y = math.max(0, math.min(sourceRect.y, screenH - height))
    return x, y
end

function QuickAccessWindow:onSliderChanged(slider, newValue)
    local control = slider and slider._nmControlRef or nil
    if not control then
        return
    end
    local spec = control.spec
    local value = roundToStep(newValue, spec.step or 0.05, spec.min or 0.0, spec.max or 1.0)
    slider:setCurrentValue(value, true)
    updateSliderValueLabel(control.valueLabel, value)
end

function QuickAccessWindow:update()
    ISCollapsableWindow.update(self)
    for _, control in pairs(self.controls or {}) do
        if control.type == "slider" and control.slider and control.valueLabel then
            updateSliderValueLabel(control.valueLabel, control.slider:getCurrentValue())
        end
    end
end

function QuickAccessWindow:close()
    if self.setVisible then
        self:setVisible(false)
    end
    if self.removeFromUIManager then
        self:removeFromUIManager()
    end
    if NMFancySettingsWindow.instance == self then
        NMFancySettingsWindow.instance = nil
    end
end

function QuickAccessWindow:createChildren()
    ISCollapsableWindow.createChildren(self)

    self.controls = {}
    local metrics = self._nmMetrics
    local specs = self.optionSpecs
    local labelX = PADDING
    local controlX = PADDING + metrics.labelWidth
    local y = metrics.rowY

    for i = 1, #specs do
        local spec = specs[i]
        local label = ISLabel:new(labelX, y + 3, ROW_HEIGHT, tostring(spec.label or ""), 1, 1, 1, 1, UIFont.Small, true)
        label:initialise()
        self:addChild(label)
        setTooltip(label, spec.tooltip)

        if spec.type == "slider" then
            local panel = ISPanel:new(controlX, y, CONTROL_WIDTH, ROW_HEIGHT)
            panel:initialise()
            panel:noBackground()
            panel.borderColor.a = 0.0
            self:addChild(panel)

            local valueLabel = ISLabel:new(0, 3, ROW_HEIGHT, "", 1, 1, 1, 1, UIFont.Small, true)
            valueLabel:initialise()
            panel:addChild(valueLabel)

            local slider = ISSliderPanel:new(SLIDER_VALUE_WIDTH, 0, CONTROL_WIDTH - SLIDER_VALUE_WIDTH, ROW_HEIGHT, self, self.onSliderChanged)
            slider:initialise()
            slider:setValues(spec.min or 0.0, spec.max or 1.0, spec.step or 0.05, (spec.step or 0.05) * 4)
            slider:setCurrentValue(tonumber(spec.value) or tonumber(spec.default) or 0.0, true)
            slider._nmControlRef = { spec = spec, valueLabel = valueLabel }
            panel:addChild(slider)
            setTooltip(slider, spec.tooltip)
            setTooltip(panel, spec.tooltip)

            self.controls[spec.key] = {
                type = spec.type,
                slider = slider,
                valueLabel = valueLabel,
                spec = spec,
            }
            self:onSliderChanged(slider, slider:getCurrentValue())
        elseif spec.type == "tickbox" then
            local tickBox = ISTickBox:new(controlX, y + 2, 20, ROW_HEIGHT, "", self, nil)
            tickBox:initialise()
            tickBox:addOption("")
            tickBox.choicesColor = { r = 1, g = 1, b = 1, a = 1 }
            tickBox:setSelected(1, spec.value == true)
            self:addChild(tickBox)
            setTooltip(tickBox, spec.tooltip)

            self.controls[spec.key] = {
                type = spec.type,
                tickBox = tickBox,
                spec = spec,
            }
        elseif spec.type == "combobox" then
            local combo = ISComboBox:new(controlX, y, CONTROL_WIDTH, ROW_HEIGHT, self, nil)
            combo:initialise()
            for choiceIndex = 1, #spec.choices do
                local choice = spec.choices[choiceIndex]
                combo:addOption(tostring(choice.label or ""), choice.value)
                if choice.value == spec.value then
                    combo.selected = choiceIndex
                end
            end
            self:addChild(combo)
            setTooltip(combo, spec.tooltip)

            self.controls[spec.key] = {
                type = spec.type,
                combo = combo,
                spec = spec,
            }
        end

        y = y + ROW_HEIGHT + ROW_GAP
    end

    self.applyButton = ISButton:new(PADDING, self.height - BUTTON_HEIGHT - PADDING, BUTTON_WIDTH, BUTTON_HEIGHT, "Apply", self, self.onApply)
    self.applyButton:initialise()
    if self.applyButton.enableAcceptColor then
        self.applyButton:enableAcceptColor()
    end
    self:addChild(self.applyButton)

    self.cancelButton = ISButton:new(self.width - BUTTON_WIDTH - PADDING, self.height - BUTTON_HEIGHT - PADDING, BUTTON_WIDTH, BUTTON_HEIGHT, getText and getText("UI_Cancel") or "Cancel", self, self.onCancel)
    self.cancelButton:initialise()
    if self.cancelButton.enableCancelColor then
        self.cancelButton:enableCancelColor()
    end
    self:addChild(self.cancelButton)
end

function QuickAccessWindow:collectDraftValues()
    local out = {}
    for key, control in pairs(self.controls) do
        if control.type == "slider" then
            out[key] = roundToStep(control.slider:getCurrentValue(), control.spec.step or 0.05, control.spec.min or 0.0, control.spec.max or 1.0)
        elseif control.type == "tickbox" then
            out[key] = control.tickBox:isSelected(1)
        elseif control.type == "combobox" then
            local selected = tonumber(control.combo.selected) or 1
            local choice = control.spec.choices[selected]
            out[key] = choice and choice.value or control.spec.value
        end
    end
    return out
end

function QuickAccessWindow:refreshFromRuntime()
    local current = ClientModOptions.getQuickAccessValues and ClientModOptions.getQuickAccessValues() or {}
    local updatedSpecs = ClientModOptions.getQuickAccessOptionSpecs and ClientModOptions.getQuickAccessOptionSpecs(current) or self.optionSpecs
    self.optionSpecs = updatedSpecs
    for i = 1, #updatedSpecs do
        local spec = updatedSpecs[i]
        local control = self.controls[spec.key]
        if control then
            control.spec = spec
            if control.type == "slider" then
                control.slider:setCurrentValue(tonumber(spec.value) or tonumber(spec.default) or 0.0, true)
                self:onSliderChanged(control.slider, control.slider:getCurrentValue())
            elseif control.type == "tickbox" then
                control.tickBox:setSelected(1, spec.value == true)
            elseif control.type == "combobox" then
                for choiceIndex = 1, #spec.choices do
                    if spec.choices[choiceIndex].value == spec.value then
                        control.combo.selected = choiceIndex
                        break
                    end
                end
            end
        end
    end
end

function QuickAccessWindow:setSourceWindow(sourceWindow)
    self.sourceWindow = sourceWindow
    local x, y = computeSpawnPosition(sourceWindow, self.width, self.height)
    self:setX(x)
    self:setY(y)
end

function QuickAccessWindow:onApply()
    local draftValues = self:collectDraftValues()
    if ClientModOptions.applyQuickAccessValues then
        ClientModOptions.applyQuickAccessValues(draftValues)
    end
    self:refreshFromRuntime()
end

function QuickAccessWindow:onCancel()
    self:close()
end

function QuickAccessWindow:new(x, y, width, height, specs)
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.title = getSettingsText()
    o.optionSpecs = specs or {}
    o._nmMetrics = computeWindowMetrics(o.optionSpecs)
    o.resizable = false
    o.pin = true
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.78 }
    o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 0.9 }
    o.moveWithMouse = true
    o.keepOnScreen = true
    return o
end

function NMFancySettingsWindow.getSettingsText()
    return getSettingsText()
end

function NMFancySettingsWindow.getSettingsTooltipText()
    return getSettingsText()
end

function NMFancySettingsWindow.getGearTexture()
    return getGearTexture()
end

function NMFancySettingsWindow.resolveGearTint(window, model)
    return resolveGearTint(window, model)
end

function NMFancySettingsWindow.getGearDrawRect(rect)
    return getExpandedRect(rect, GEAR_SCALE)
end

function NMFancySettingsWindow.openForSourceWindow(sourceWindow)
    if sourceWindow and sourceWindow.tooltipUI and sourceWindow.tooltipUI:getIsVisible() then
        sourceWindow.tooltipUI:setVisible(false)
        if sourceWindow.tooltipUI.removeFromUIManager then
            sourceWindow.tooltipUI:removeFromUIManager()
        end
    end
    if sourceWindow then
        sourceWindow.tooltip = nil
    end

    local specs = ClientModOptions.getQuickAccessOptionSpecs and ClientModOptions.getQuickAccessOptionSpecs() or {}
    local metrics = computeWindowMetrics(specs)

    local existing = NMFancySettingsWindow.instance
    if existing and existing.javaObject then
        existing.optionSpecs = specs
        existing._nmMetrics = metrics
        existing:setWidth(metrics.width)
        existing:setHeight(metrics.height)
        existing:refreshFromRuntime()
        existing:setSourceWindow(sourceWindow)
        existing:setVisible(true)
        if existing:getIsVisible() ~= true then
            existing:addToUIManager()
        end
        existing:bringToTop()
        return existing
    end

    local x, y = computeSpawnPosition(sourceWindow, metrics.width, metrics.height)
    local window = QuickAccessWindow:new(x, y, metrics.width, metrics.height, specs)
    window:initialise()
    window:addToUIManager()
    window:setSourceWindow(sourceWindow)
    window:bringToTop()
    NMFancySettingsWindow.instance = window
    return window
end

return NMFancySettingsWindow
