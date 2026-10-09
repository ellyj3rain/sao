require "ISUI/ISPanel"

NMNewMusicLogoDecoration = NMNewMusicLogoDecoration or {}

local W = 96
local H = 40
local LOGO_TEXTURE_PATH = "media/textures/UI/NewMusicLogo.png"
local COMPACT_W = 40
local COMPACT_H = 40
local COMPACT_TEXTURE_PATH = "media/textures/UI/NewMusic40.png"
local LOGO_ALPHA = 0.20
local LOGO_TEXTURE = nil
local COMPACT_TEXTURE = nil

local function getLogoTexture()
    if LOGO_TEXTURE ~= nil then
        return LOGO_TEXTURE
    end
    LOGO_TEXTURE = getTexture and getTexture(LOGO_TEXTURE_PATH) or false
    return LOGO_TEXTURE ~= false and LOGO_TEXTURE or nil
end

local function getCompactTexture()
    if COMPACT_TEXTURE ~= nil then
        return COMPACT_TEXTURE
    end
    COMPACT_TEXTURE = getTexture and getTexture(COMPACT_TEXTURE_PATH) or false
    return COMPACT_TEXTURE ~= false and COMPACT_TEXTURE or nil
end

function NMNewMusicLogoDecoration.getSize()
    return W, H
end

function NMNewMusicLogoDecoration.getCompactSize()
    return COMPACT_W, COMPACT_H
end

function NMNewMusicLogoDecoration.getAlpha()
    return LOGO_ALPHA
end

function NMNewMusicLogoDecoration.attach(window, x, y)
    local panel = ISPanel:new(x, y, W, H)
    panel:initialise()
    panel:instantiate()
    panel.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    panel.borderColor = { r = 0, g = 0, b = 0, a = 0 }

    panel.render = function(self)
        -- Temporary A/B hitch test: use a single PNG draw instead of vector poly/rect calls.
        local tex = getLogoTexture()
        if tex then
            self:drawTextureScaledAspect(tex, 0, 0, W, H, LOGO_ALPHA, 1.0, 1.0, 1.0)
        end
    end

    window:addChild(panel)
    return panel
end

function NMNewMusicLogoDecoration.attachCompact(window, x, y)
    local panel = ISPanel:new(x, y, COMPACT_W, COMPACT_H)
    panel:initialise()
    panel:instantiate()
    panel.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    panel.borderColor = { r = 0, g = 0, b = 0, a = 0 }

    panel.render = function(self)
        local tex = getCompactTexture()
        if tex then
            self:drawTextureScaledAspect(tex, 0, 0, COMPACT_W, COMPACT_H, LOGO_ALPHA, 1.0, 1.0, 1.0)
        end
    end

    window:addChild(panel)
    return panel
end
