require "ISUI/ISCollapsableWindow"

NMCoverViewUI = NMCoverViewUI or {}

local CoverWindow = ISCollapsableWindow:derive("NMCoverViewWindow")

function CoverWindow:initialise()
    ISCollapsableWindow.initialise(self)
end

function CoverWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    self:setResizable(true)
    self.resizable = true
end

function CoverWindow:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed then
        return
    end
    local pad = 12
    local top = self:titleBarHeight() + pad
    local boxY = top
    local boxW = self.width - (pad * 2)
    local boxH = self.height - boxY - pad
    if boxW < 8 or boxH < 8 then
        return
    end

    self:drawRect(pad, boxY, boxW, boxH, 0.92, 0.06, 0.06, 0.06)
    self:drawRectBorder(pad, boxY, boxW, boxH, 0.9, 1, 1, 1)
    if self.coverTexture then
        self:drawTextureScaledAspect(self.coverTexture, pad + 1, boxY + 1, boxW - 2, boxH - 2, 1, 1, 1, 1)
    else
        self:drawTextCentre(NMTranslations.ui("NoCoverTexture", "No cover texture"), self.width / 2, boxY + (boxH / 2) - 8, 0.9, 0.9, 0.9, 1, UIFont.Small)
    end
end

function CoverWindow:new(x, y, width, height)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o.title = NMTranslations.uiStringFormat("WindowTitleFmt", "New Music - %s", NMTranslations.ui("ViewCover", "View Cover"))
    o.pin = true
    o.minimumWidth = 200
    o.minimumHeight = 200
    o.coverTexture = nil
    o.coverMode = ""
    return o
end

local singleton = nil

local function getOrCreateWindow()
    if singleton and singleton.javaObject then
        return singleton
    end
    local w, h = 512, 512
    local core = getCore and getCore() or nil
    local sw = core and core:getScreenWidth() or 1280
    local sh = core and core:getScreenHeight() or 720
    local x = math.floor((sw - w) / 2)
    local y = math.floor((sh - h) / 2)
    singleton = CoverWindow:new(x, y, w, h)
    singleton:initialise()
    singleton:addToUIManager()
    return singleton
end

function NMCoverViewUI.open(playerNum, texturePath, label, mode)
    local _ = playerNum
    local win = getOrCreateWindow()
    win.coverTexture = (texturePath and getTexture) and getTexture(texturePath) or nil
    win.coverMode = tostring(mode or "")
    if win:getWidth() < 200 then
        win:setWidth(200)
    end
    if win:getHeight() < 200 then
        win:setHeight(200)
    end
    local header = tostring(label or NMTranslations.ui("ViewCover", "View Cover"))
    if header == "" then
        header = NMTranslations.ui("ViewCover", "View Cover")
    end
    win.title = NMTranslations.uiStringFormat("WindowTitleFmt", "New Music - %s", tostring(header or ""))
    win:setVisible(true)
    win:bringToTop()
end
