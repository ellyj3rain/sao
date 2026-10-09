NMReadoutLabelRenderer = NMReadoutLabelRenderer or {}

local LABEL_HEIGHT_CACHE = {}

local function getScaleKey()
    if NMFancyDeviceUiScale and NMFancyDeviceUiScale.getTextureScaleKey then
        return NMFancyDeviceUiScale.getTextureScaleKey()
    end
    return "1x"
end

local function count(window, key)
    if NMUIRenderProbe and NMUIRenderProbe.count then
        NMUIRenderProbe.count(window, tostring(key or ""), 1)
    end
end

local function offsetRectY(rect, offsetY)
    if not rect or offsetY == 0 then
        return rect
    end
    return {
        x = rect.x,
        y = rect.y + offsetY,
        w = rect.w,
        h = rect.h,
    }
end

local function getTextHeight(window, font, sampleText, cacheName)
    local fontKey = tostring(font or UIFont.Small)
    local cacheKey = table.concat({
        tostring(cacheName or "readout"),
        fontKey,
        tostring(sampleText or "Ag"),
        getScaleKey(),
    }, "|")
    local cached = LABEL_HEIGHT_CACHE[cacheKey]
    if cached ~= nil then
        count(window, "readout_label_height_cache_hit")
        return cached
    end
    local tm = getTextManager and getTextManager() or nil
    local measured = tm and tm.MeasureStringY and tm:MeasureStringY(font or UIFont.Small, sampleText or "Ag") or 10
    LABEL_HEIGHT_CACHE[cacheKey] = measured
    count(window, "readout_label_height_cache_miss")
    return measured
end

function NMReadoutLabelRenderer.draw(window, labelState, options)
    if not (window and labelState and labelState.rect) then
        return false
    end
    local opts = type(options) == "table" and options or {}
    local font = opts.font or UIFont.Small
    local padX = tonumber(opts.padX) or 0
    local rect = offsetRectY(labelState.rect, tonumber(opts.offsetY) or 0)
    local bg = opts.background or opts.bg
    if bg then
        window:drawRect(rect.x, rect.y, rect.w, rect.h, bg.a, bg.r, bg.g, bg.b)
    end
    local textH = getTextHeight(window, font, opts.sampleText or "Ag", opts.cacheName)
    local textY = rect.y + math.floor(((rect.h - textH) * 0.5) + 0.5)
    local color = opts.color or labelState.color or { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }
    window:drawText(
        tostring(labelState.text or ""),
        rect.x + padX,
        textY,
        color.r,
        color.g,
        color.b,
        color.a,
        font
    )
    return true
end

return NMReadoutLabelRenderer
