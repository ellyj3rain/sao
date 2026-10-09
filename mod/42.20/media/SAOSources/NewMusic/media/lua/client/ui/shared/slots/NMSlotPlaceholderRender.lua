NMSlotPlaceholderRender = NMSlotPlaceholderRender or {}

local DEFAULT_TINT = {
    a = 0.55,
    r = 0.12,
    g = 0.12,
    b = 0.12
}

local function resolveDimension(texture, primaryName, fallbackName, defaultValue)
    if not texture then
        return defaultValue
    end
    local primary = texture[primaryName]
    if primary then
        local ok, value = pcall(primary, texture)
        if ok and tonumber(value) ~= nil and tonumber(value) > 0 then
            return tonumber(value)
        end
    end
    local fallback = texture[fallbackName]
    if fallback then
        local ok, value = pcall(fallback, texture)
        if ok and tonumber(value) ~= nil and tonumber(value) > 0 then
            return tonumber(value)
        end
    end
    return defaultValue
end

local function resolveButtonDimension(button, key)
    return math.max(0, tonumber(button and button[key]) or 0)
end

local function nearlyEqual(left, right)
    return math.abs((tonumber(left) or 0) - (tonumber(right) or 0)) <= 0.5
end

function NMSlotPlaceholderRender.resolveDrawRect(button, texture, opts)
    if not (button and texture) then
        return nil
    end

    local buttonW = resolveButtonDimension(button, "width")
    local buttonH = resolveButtonDimension(button, "height")
    if buttonW <= 0 or buttonH <= 0 then
        return nil
    end

    local texW = resolveDimension(texture, "getWidthOrig", "getWidth", 32)
    local texH = resolveDimension(texture, "getHeightOrig", "getHeight", 32)
    local useNativeSize = (opts and opts.useNativeMatchedSize ~= false) and nearlyEqual(texW, buttonW) and nearlyEqual(texH, buttonH)
    if useNativeSize then
        return 0, 0, buttonW, buttonH
    end

    local inset = math.max(0, tonumber(opts and opts.inset) or 8)
    local maxW = math.max(1, buttonW - inset)
    local maxH = math.max(1, buttonH - inset)
    local scale = math.min(maxW / texW, maxH / texH)
    local drawW = texW * scale
    local drawH = texH * scale
    local left = (buttonW - drawW) * 0.5
    local top = (buttonH - drawH) * 0.5
    return left, top, drawW, drawH
end

function NMSlotPlaceholderRender.drawTexture(button, texture, opts)
    if not (button and texture) then
        return false
    end

    local left, top, drawW, drawH = NMSlotPlaceholderRender.resolveDrawRect(button, texture, opts)
    if not left then
        return false
    end

    local tint = opts and opts.tint or DEFAULT_TINT
    button:drawTextureScaled(texture, left, top, drawW, drawH, tint.a or DEFAULT_TINT.a, tint.r or DEFAULT_TINT.r, tint.g or DEFAULT_TINT.g, tint.b or DEFAULT_TINT.b)
    return true
end

return NMSlotPlaceholderRender
