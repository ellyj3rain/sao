require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ComputerMod_UI_Text"

ComputerModErrorDialog = ISPanel:derive("ComputerModErrorDialog")

local function dialogText(key, fallback)
    local lookup = "IGUI_ComputerMod_UI_" .. tostring(key):gsub("[^A-Za-z0-9]+", "_"):gsub("^_+", ""):gsub("_+$", "")
    if getText then
        local ok, value = pcall(getText, lookup)
        if ok and value and value ~= lookup then
            return value
        end
    end
    return fallback or key
end

local function scaled(value, scale)
    return math.max(1, math.floor((tonumber(value) or 0) * (tonumber(scale) or 1) + 0.5))
end

function ComputerModErrorDialog:new(x, y, width, height, owner)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.owner = owner
    o.message = ""
    o.dialogTitle = dialogText("Error")
    o.background = false
    o.border = false
    o.moveWithMouse = false
    return o
end

function ComputerModErrorDialog:initialise()
    ISPanel.initialise(self)
end

function ComputerModErrorDialog:createChildren()
    ISPanel.createChildren(self)
    self.okButton = ISButton:new(0, 0, 76, 22, dialogText("OK"), self, ComputerModErrorDialog.closeDialog)
    self.okButton:initialise()
    self.okButton.backgroundColor = {r = 0.75, g = 0.75, b = 0.75, a = 1}
    self.okButton.backgroundColorMouseOver = {r = 0.84, g = 0.84, b = 0.84, a = 1}
    self.okButton.borderColor = {r = 0.4, g = 0.4, b = 0.4, a = 1}
    self.okButton.textColor = {r = 0, g = 0, b = 0, a = 1}
    if ComputerModUIText then
        ComputerModUIText.installButton(self.okButton)
    end
    self:addChild(self.okButton)

    self.closeButton = ISButton:new(0, 0, 18, 16, "X", self, ComputerModErrorDialog.closeDialog)
    self.closeButton:initialise()
    self.closeButton.backgroundColor = {r = 0.8, g = 0, b = 0, a = 1}
    self.closeButton.backgroundColorMouseOver = {r = 0.94, g = 0.08, b = 0.08, a = 1}
    self.closeButton.borderColor = {r = 0.4, g = 0.4, b = 0.4, a = 1}
    self.closeButton.textColor = {r = 1, g = 1, b = 1, a = 1}
    if ComputerModUIText then
        ComputerModUIText.installButton(self.closeButton)
    end
    self:addChild(self.closeButton)
    self:updateLayout()
end

function ComputerModErrorDialog:getScale()
    return tonumber(self.owner and (self.owner.uiScale or self.owner.contentScale)) or 1
end

function ComputerModErrorDialog:getMessageLines(maxWidth)
    if self.owner and self.owner.wrapTextLines then
        local lines = self.owner:wrapTextLines(self.message, UIFont.Small, maxWidth, 6)
        if #lines > 0 then return lines end
    end
    return {tostring(self.message or "")}
end

function ComputerModErrorDialog:updateLayout()
    local scale = self:getScale()
    local margin = scaled(10, scale)
    local minWidth = scaled(250, scale)
    local maxWidth = scaled(330, scale)
    self.dialogW = math.min(math.max(minWidth, math.floor(self.width * 0.58)), math.min(maxWidth, self.width - margin * 2))
    self.titleH = scaled(22, scale)
    self.iconW = scaled(40, scale)
    self.messagePadding = scaled(10, scale)
    self.messageX = self.iconW + self.messagePadding
    self.messageW = math.max(scaled(110, scale), self.dialogW - self.messageX - scaled(12, scale))
    self.messageLines = self:getMessageLines(self.messageW)
    self.lineH = ComputerModUIText and ComputerModUIText.getLineHeight(UIFont.Small) or scaled(17, scale)
    local messageH = math.max(scaled(30, scale), #self.messageLines * self.lineH)
    self.dialogH = self.titleH + scaled(10, scale) + messageH + scaled(36, scale)
    self.dialogH = math.min(self.dialogH, self.height - margin * 2)
    if self.dialogPlacement == "top_left" then
        self.dialogX = margin
        self.dialogY = margin
    elseif self.dialogPlacement == "top_right" then
        self.dialogX = self.width - self.dialogW - margin
        self.dialogY = margin
    elseif self.dialogPlacement == "bottom_left" then
        self.dialogX = margin
        self.dialogY = self.height - self.dialogH - margin
    elseif self.dialogPlacement == "bottom_right" then
        self.dialogX = self.width - self.dialogW - margin
        self.dialogY = self.height - self.dialogH - margin
    else
        self.dialogX = math.floor((self.width - self.dialogW) * 0.5)
        self.dialogY = math.floor((self.height - self.dialogH) * 0.5)
    end
    local okW = scaled(76, scale)
    local okH = scaled(22, scale)
    self.okButton:setX(self.dialogX + math.floor((self.dialogW - okW) * 0.5))
    self.okButton:setY(self.dialogY + self.dialogH - okH - scaled(7, scale))
    self.okButton:setWidth(okW)
    self.okButton:setHeight(okH)
    local closeW = scaled(18, scale)
    local closeH = scaled(16, scale)
    self.closeButton:setX(self.dialogX + self.dialogW - closeW - scaled(4, scale))
    self.closeButton:setY(self.dialogY + scaled(4, scale))
    self.closeButton:setWidth(closeW)
    self.closeButton:setHeight(closeH)
end

function ComputerModErrorDialog:open(message, title, placement, virusPopup)
    self.message = tostring(message or "")
    self.dialogTitle = tostring(title or dialogText("Error"))
    self.dialogPlacement = placement or "center"
    self.virusPopup = virusPopup == true
    self:updateLayout()
    self:setVisible(true)
    if self.bringToTop then
        self:bringToTop()
    end
end

function ComputerModErrorDialog:closeDialog()
    local virusPopup = self.virusPopup == true
    self.virusPopup = false
    self:setVisible(false)
    if self.owner and self.owner.onErrorDialogClosed then
        self.owner:onErrorDialogClosed(virusPopup)
    end
end

function ComputerModErrorDialog:prerender()
    local scale = self:getScale()
    local border = scaled(2, scale)
    local inset = scaled(3, scale)
    self:drawRect(self.dialogX, self.dialogY, self.dialogW, self.dialogH, 1, 0.85, 0.85, 0.82)
    self:drawRect(self.dialogX, self.dialogY, self.dialogW, border, 1, 1, 1, 1)
    self:drawRect(self.dialogX, self.dialogY, border, self.dialogH, 1, 1, 1, 1)
    self:drawRect(self.dialogX + self.dialogW - border, self.dialogY, border, self.dialogH, 1, 0.25, 0.25, 0.25)
    self:drawRect(self.dialogX, self.dialogY + self.dialogH - border, self.dialogW, border, 1, 0.25, 0.25, 0.25)
    self:drawRect(self.dialogX + inset, self.dialogY + inset, self.dialogW - inset * 2, self.titleH - inset, 1, 0.02, 0.02, 0.55)
    self:drawTextInWidth(self.dialogTitle, self.dialogX + scaled(8, scale), self.dialogY + scaled(5, scale), self.dialogW - self.closeButton.width - scaled(20, scale), 1, 1, 1, 1, UIFont.Small)

    local triangleX = self.dialogX + scaled(12, scale)
    local triangleY = self.dialogY + self.titleH + scaled(10, scale)
    local triangleW = scaled(28, scale)
    local triangleH = scaled(26, scale)
    for row = 0, triangleH - 1 do
        local ratio = row / math.max(1, triangleH - 1)
        local rowW = math.max(1, math.floor(triangleW * ratio))
        local rowX = triangleX + math.floor((triangleW - rowW) * 0.5)
        self:drawRect(rowX, triangleY + row, rowW, 1, 1, 0.05, 0.05, 0.05)
        if rowW > scaled(4, scale) and row < triangleH - scaled(2, scale) then
            self:drawRect(rowX + scaled(1, scale), triangleY + row, rowW - scaled(2, scale), 1, 1, 0.96, 0.82, 0.08)
        end
    end
    self:drawRect(triangleX + math.floor(triangleW * 0.47), triangleY + scaled(8, scale), scaled(2, scale), scaled(9, scale), 1, 0.03, 0.03, 0.03)
    self:drawRect(triangleX + math.floor(triangleW * 0.47), triangleY + scaled(20, scale), scaled(2, scale), scaled(2, scale), 1, 0.03, 0.03, 0.03)

    local textY = self.dialogY + self.titleH + scaled(11, scale)
    for i = 1, #self.messageLines do
        self:drawTextInWidth(self.messageLines[i], self.dialogX + self.messageX, textY + (i - 1) * self.lineH, self.messageW, 0.04, 0.04, 0.04, 1, UIFont.Small)
    end
end

function ComputerModErrorDialog:onMouseDown(x, y)
    return true
end

function ComputerModErrorDialog:onMouseUp(x, y)
    return true
end

function ComputerModErrorDialog:onMouseWheel(del)
    return true
end

function ComputerModErrorDialog:onRightMouseDown(x, y)
    return true
end

if ComputerModUIText then
    ComputerModUIText.installPanelClass(ComputerModErrorDialog)
end
