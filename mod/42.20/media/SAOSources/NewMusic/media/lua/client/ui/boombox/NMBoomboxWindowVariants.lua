local env = _G.NMBoomboxWindowEnv
setfenv(1, env)

local function fancyTexturePath(path)
    if NMFancyDeviceUiScale and NMFancyDeviceUiScale.resolveTexturePath then
        return NMFancyDeviceUiScale.resolveTexturePath(path)
    end
    return path
end

local function getFancyTexture(path)
    if not getTexture then
        return nil
    end
    return getTexture(fancyTexturePath(path))
end

local function getFancyTextureScaleKey()
    if NMFancyDeviceUiScale and NMFancyDeviceUiScale.getTextureScaleKey then
        return NMFancyDeviceUiScale.getTextureScaleKey()
    end
    return "1x"
end

function normalizeBoomboxVariantToken(rawToken)
    local text = tostring(rawToken or "")
    local token = text:match("Boombox([A-Za-z]+)$")
        or text:match("NM_Boombox([A-Za-z]+)$")
        or text:match("World_NM_Boombox([A-Za-z]+)$")
        or text:match("^([A-Za-z]+)$")
    token = tostring(token or "")
    if token == "" then
        return nil
    end
    return token
end

function resolveBoomboxVariantFromItem(item)
    if not item then
        return BOOMBOX_UI_VARIANT_FALLBACK
    end
    if item.getScriptItem then
        local okScript, scriptItem = pcall(item.getScriptItem, item)
        if okScript and scriptItem then
            if scriptItem.getWorldStaticModel then
                local okWorld, token = pcall(scriptItem.getWorldStaticModel, scriptItem)
                local variant = okWorld and normalizeBoomboxVariantToken(token) or nil
                if variant then return variant end
            end
            if scriptItem.getStaticModel then
                local okStatic, token = pcall(scriptItem.getStaticModel, scriptItem)
                local variant = okStatic and normalizeBoomboxVariantToken(token) or nil
                if variant then return variant end
            end
        end
    end
    if item.getWorldStaticModel then
        local okWorld, token = pcall(item.getWorldStaticModel, item)
        local variant = okWorld and normalizeBoomboxVariantToken(token) or nil
        if variant then return variant end
    end
    if item.getStaticModel then
        local okStatic, token = pcall(item.getStaticModel, item)
        local variant = okStatic and normalizeBoomboxVariantToken(token) or nil
        if variant then return variant end
    end
    if item.getFullType then
        local variant = normalizeBoomboxVariantToken(item:getFullType())
        if variant then return variant end
    end
    if item.getType then
        local variant = normalizeBoomboxVariantToken(item:getType())
        if variant then return variant end
    end
    return BOOMBOX_UI_VARIANT_FALLBACK
end

function getBoomboxUITexturesForVariant(variant)
    local token = normalizeBoomboxVariantToken(variant) or BOOMBOX_UI_VARIANT_FALLBACK
    local cacheKey = token .. "|" .. getFancyTextureScaleKey()
    local cached = BOOMBOX_UI_TEXTURES_BY_VARIANT[cacheKey]
    if cached and cached.front and cached.lid then
        return cached
    end
    local fallbackToken = BOOMBOX_UI_VARIANT_FALLBACK
    local resolveVariantTexture = function(prefix, variantToken)
        return getFancyTexture(prefix .. variantToken .. ".png")
    end
    local resolveOddboltTexture = function(path, fallbackPath)
        local tex = getFancyTexture(path)
        if tex or not fallbackPath then
            return tex
        end
        return getFancyTexture(fallbackPath)
    end
    local front = resolveVariantTexture(FRONT_TEXTURE_PREFIX, token)
    local lid = resolveVariantTexture(LID_TEXTURE_PREFIX, token)
    if token ~= fallbackToken then
        front = front or resolveVariantTexture(FRONT_TEXTURE_PREFIX, fallbackToken)
        lid = lid or resolveVariantTexture(LID_TEXTURE_PREFIX, fallbackToken)
    end
    local textures = {
        variant = token,
        base = getFancyTexture(BASE_TEXTURE_PATH),
        front = front,
        lid = lid,
        lidEdge = getFancyTexture(LID_EDGE_TEXTURE_PATH),
        close = getFancyTexture(CLOSE_TEXTURE_PATH),
        powerBg = getFancyTexture(POWER_BG_TEXTURE_PATH),
        powerSlide = getFancyTexture(POWER_SLIDE_TEXTURE_PATH),
        buttonTop = getFancyTexture(BUTTON_TOP_TEXTURE_PATH),
        buttonBottom = getFancyTexture(BUTTON_BOTTOM_TEXTURE_PATH),
        buttonTopPrev = token == "Oddbolt"
            and resolveOddboltTexture("media/textures/UI/Boombox/NM_UI_Boombox_Button_Top_Oddbolt.png", BUTTON_TOP_TEXTURE_PATH)
            or getFancyTexture(BUTTON_TOP_TEXTURE_PATH),
        buttonBottomPrev = token == "Oddbolt"
            and resolveOddboltTexture("media/textures/UI/Boombox/NM_UI_Boombox_Button_Bottom_Oddbolt.png", BUTTON_BOTTOM_TEXTURE_PATH)
            or getFancyTexture(BUTTON_BOTTOM_TEXTURE_PATH),
        play = getFancyTexture(BUTTON_PLAY_TEXTURE_PATH),
        stop = getFancyTexture(BUTTON_STOP_TEXTURE_PATH),
        prev = token == "Oddbolt"
            and resolveOddboltTexture("media/textures/UI/Boombox/NM_UI_Boombox_Button_Prev_Oddbolt.png", BUTTON_PREV_TEXTURE_PATH)
            or getFancyTexture(BUTTON_PREV_TEXTURE_PATH),
        next = getFancyTexture(BUTTON_NEXT_TEXTURE_PATH),
        eject = getFancyTexture(BUTTON_EJECT_TEXTURE_PATH),
        topPlay = getFancyTexture(BUTTON_TOP_PLAY_TEXTURE_PATH),
        topStop = getFancyTexture(BUTTON_TOP_STOP_TEXTURE_PATH),
        topPrev = token == "Oddbolt"
            and resolveOddboltTexture("media/textures/UI/Boombox/NM_UI_Boombox_Button_Top_Prev_Oddbolt.png", BUTTON_TOP_PREV_TEXTURE_PATH)
            or getFancyTexture(BUTTON_TOP_PREV_TEXTURE_PATH),
        topNext = getFancyTexture(BUTTON_TOP_NEXT_TEXTURE_PATH),
        volumeBg = getFancyTexture(VOLUME_BG_TEXTURE_PATH),
        volumeKnob = token == "Oddbolt"
            and resolveOddboltTexture("media/textures/UI/Boombox/NM_UI_Boombox_Volume_Knob_Oddbolt.png", VOLUME_KNOB_TEXTURE_PATH)
            or getFancyTexture(VOLUME_KNOB_TEXTURE_PATH),
        modeBg = getFancyTexture(MODE_BG_TEXTURE_PATH),
        modeButton = getFancyTexture(MODE_BUTTON_TEXTURE_PATH),
        spool = getFancyTexture(SPOOL_TEXTURE_PATH),
        modeIcons = {
            getFancyTexture(MODE_ICON_REPEAT_SONG) or getFancyTexture("UI_NM_RepeatSong"),
            getFancyTexture(MODE_ICON_REPEAT_ALBUM) or getFancyTexture("UI_NM_RepeatAlbum"),
            getFancyTexture(MODE_ICON_SHUFFLE) or getFancyTexture("UI_NM_Shuffle"),
        }
    }
    BOOMBOX_UI_TEXTURES_BY_VARIANT[cacheKey] = textures
    return textures
end

function BoomboxWindow:getBoomboxVariant(resolved)
    local ctx = resolved or self:resolveContextCached()
    return resolveBoomboxVariantFromItem(ctx and ctx.item or nil)
end

function BoomboxWindow:resolveBoomboxUITextures(resolvedOrVariant)
    local variant = type(resolvedOrVariant) == "string" and resolvedOrVariant or self:getBoomboxVariant(resolvedOrVariant)
    return getBoomboxUITexturesForVariant(variant)
end
