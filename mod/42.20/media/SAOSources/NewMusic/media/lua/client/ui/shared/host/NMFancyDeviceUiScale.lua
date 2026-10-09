NMFancyDeviceUiScale = NMFancyDeviceUiScale or {}

local MIN_EFFECTIVE_SCALE = 0.5
local MAX_EFFECTIVE_SCALE = 2.0
local SCALE_TIER_100 = "100"
local SCALE_TIER_150 = "150"
local SCALE_TIER_200 = "200"

local TIER_PATTERNS_BY_SCALE = {
    [SCALE_TIER_150] = {
        "NM_UI_VolumeWheel%.png$",
        "NM_UI_Walkman_Spool%.png$",
        "NM_UI_Boombox_Volume_Knob[^/]*%.png$",
        "NM_UI_CDPlayer_Button_Hold%.png$",
        "NM_UI_CDPlayer_Teal_Button_Hold%.png$",
    },
    [SCALE_TIER_200] = {
        "NM_UI_VolumeWheel%.png$",
        "NM_UI_Walkman_Spool%.png$",
        "NM_UI_Boombox_Volume_Knob[^/]*%.png$",
        "NM_UI_CDPlayer_Button_Hold%.png$",
        "NM_UI_CDPlayer_Teal_Button_Hold%.png$",
    },
}

local function clamp(value, minValue, maxValue)
    local n = tonumber(value)
    if n == nil then
        return minValue
    end
    if n < minValue then
        return minValue
    end
    if n > maxValue then
        return maxValue
    end
    return n
end

local function pathMatchesAnyPattern(path, patterns)
    local text = tostring(path or "")
    for i = 1, #patterns do
        if string.match(text, patterns[i]) then
            return true
        end
    end
    return false
end

local function getScaleTierForMultiplier(multiplier)
    local scale = clamp(multiplier, MIN_EFFECTIVE_SCALE, MAX_EFFECTIVE_SCALE)
    if scale >= 1.75 then
        return SCALE_TIER_200
    end
    if scale >= 1.25 then
        return SCALE_TIER_150
    end
    return SCALE_TIER_100
end

local function getTexturePathForTier(path, tier)
    local text = tostring(path or "")
    if text == "" then
        return text
    end
    if tier ~= SCALE_TIER_150 and tier ~= SCALE_TIER_200 then
        return text
    end

    local resolved = text:gsub("media/textures/UI/(Boombox)/", "media/textures/UI/%1/" .. tier .. "/", 1)
    if resolved ~= text then
        return resolved
    end
    resolved = text:gsub("media/textures/UI/(Walkman)/", "media/textures/UI/%1/" .. tier .. "/", 1)
    if resolved ~= text then
        return resolved
    end
    resolved = text:gsub("media/textures/UI/(CDPlayer)/", "media/textures/UI/%1/" .. tier .. "/", 1)
    if resolved ~= text then
        return resolved
    end
    resolved = text:gsub("media/textures/UI/([^/]+%.png)$", "media/textures/UI/" .. tier .. "/%1", 1)
    return resolved
end

function NMFancyDeviceUiScale.getUserMultiplier()
    if NMRuntimeConfig and NMRuntimeConfig.getFancyDeviceUiScaleMultiplier then
        return clamp(NMRuntimeConfig.getFancyDeviceUiScaleMultiplier(), MIN_EFFECTIVE_SCALE, MAX_EFFECTIVE_SCALE)
    end
    return 1.0
end

function NMFancyDeviceUiScale.getEffectiveScale()
    return NMFancyDeviceUiScale.getUserMultiplier()
end

function NMFancyDeviceUiScale.getScaleTier()
    return getScaleTierForMultiplier(NMFancyDeviceUiScale.getEffectiveScale())
end

function NMFancyDeviceUiScale.isHighResolutionTextureScale()
    return NMFancyDeviceUiScale.getScaleTier() == SCALE_TIER_200
end

function NMFancyDeviceUiScale.prefersHighResolutionTextures()
    local tier = NMFancyDeviceUiScale.getScaleTier()
    return tier == SCALE_TIER_150 or tier == SCALE_TIER_200
end

function NMFancyDeviceUiScale.getTextureScaleKey()
    return NMFancyDeviceUiScale.getScaleTier()
end

function NMFancyDeviceUiScale.resolveTexturePath(path, opts)
    local text = tostring(path or "")
    if text == "" then
        return text
    end

    if opts and opts.forceOriginal == true then
        return text
    end

    local requestedTier = opts and tostring(opts.forceTier or "") or ""
    if requestedTier == "" then
        requestedTier = NMFancyDeviceUiScale.getScaleTier()
    end

    if requestedTier == SCALE_TIER_100 and not (opts and opts.forceHighResolution == true) then
        return text
    end
    if requestedTier ~= SCALE_TIER_150 and requestedTier ~= SCALE_TIER_200 then
        return text
    end

    local tierPatterns = TIER_PATTERNS_BY_SCALE[requestedTier] or nil
    if tierPatterns and pathMatchesAnyPattern(text, tierPatterns) then
        local tierPath = getTexturePathForTier(text, requestedTier)
        if tierPath ~= text and getTexture and getTexture(tierPath) then
            return tierPath
        end
        return text
    end

    local highResPath = getTexturePathForTier(text, SCALE_TIER_200)
    if highResPath ~= text and getTexture and getTexture(highResPath) then
        return highResPath
    end
    return text
end

function NMFancyDeviceUiScale.getTexture(path, opts)
    if not getTexture then
        return nil
    end
    return getTexture(NMFancyDeviceUiScale.resolveTexturePath(path, opts))
end

function NMFancyDeviceUiScale.scaleValue(value)
    local numeric = tonumber(value) or 0.0
    if numeric == 0.0 then
        return 0
    end
    return math.floor((numeric * NMFancyDeviceUiScale.getEffectiveScale()) + 0.5)
end

function NMFancyDeviceUiScale.drawTextureScaledAngle(window, texture, rect, angle, alpha, r, g, b)
    if not (window and texture and rect) then
        return false
    end

    local x = tonumber(rect.x) or 0
    local y = tonumber(rect.y) or 0
    local w = tonumber(rect.w) or 0
    local h = tonumber(rect.h) or 0
    if w <= 0 or h <= 0 then
        return false
    end

    local centerX = x + (w / 2)
    local centerY = y + (h / 2)
    local degrees = tonumber(angle) or 0.0
    local texW = texture.getWidthOrig and texture:getWidthOrig() or texture.getWidth and texture:getWidth() or w
    local texH = texture.getHeightOrig and texture:getHeightOrig() or texture.getHeight and texture:getHeight() or h
    local scale = math.min(w / math.max(1, texW), h / math.max(1, texH))
    local javaObject = window.javaObject
    if javaObject then
        local ok = pcall(javaObject.DrawTextureAngleScaled, javaObject, texture, centerX, centerY, degrees, w, h, alpha or 1.0)
        if ok then
            return true
        end
        ok = pcall(javaObject.DrawTextureAngleScaledColor, javaObject, texture, centerX, centerY, degrees, w, h, r or 1.0, g or 1.0, b or 1.0, alpha or 1.0)
        if ok then
            return true
        end
        ok = pcall(javaObject.DrawTextureAngleScaled, javaObject, texture, centerX, centerY, degrees, scale)
        if ok then
            return true
        end
        ok = pcall(javaObject.DrawTextureAngleScaledColor, javaObject, texture, centerX, centerY, degrees, scale, r or 1.0, g or 1.0, b or 1.0, alpha or 1.0)
        if ok then
            return true
        end
    end

    if window.DrawTextureAngle then
        window:DrawTextureAngle(texture, centerX, centerY, degrees)
        return true
    end
    if window.drawTextureScaled then
        window:drawTextureScaled(texture, x, y, w, h, alpha or 1.0, r or 1.0, g or 1.0, b or 1.0)
        return true
    end
    return false
end

function NMFancyDeviceUiScale.snapshot()
    return {
        userMultiplier = NMFancyDeviceUiScale.getUserMultiplier(),
        effectiveScale = NMFancyDeviceUiScale.getEffectiveScale(),
        scaleTier = NMFancyDeviceUiScale.getScaleTier(),
    }
end

return NMFancyDeviceUiScale
