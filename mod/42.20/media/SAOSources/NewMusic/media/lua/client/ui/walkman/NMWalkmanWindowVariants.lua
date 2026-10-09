local env = _G.NMWalkmanWindowEnv
setfenv(1, env)

local function getFancyTexture(path)
    if NMFancyDeviceUiScale and NMFancyDeviceUiScale.getTexture then
        return NMFancyDeviceUiScale.getTexture(path)
    end
    return getTexture and getTexture(path) or nil
end

local function getFancyTextureScaleKey()
    if NMFancyDeviceUiScale and NMFancyDeviceUiScale.getTextureScaleKey then
        return NMFancyDeviceUiScale.getTextureScaleKey()
    end
    return "1x"
end

function normalizeWalkmanVariantToken(rawToken)
    local text = tostring(rawToken or "")
    local token = text:match("Walkman([A-Za-z]+)$")
        or text:match("NM_Walkman([A-Za-z]+)$")
        or text:match("World_NM_Walkman([A-Za-z]+)$")
        or text:match("^([A-Za-z]+)$")
    token = tostring(token or "")
    if token == "" then
        return nil
    end
    return token
end

function resolveWalkmanVariantFromItem(item)
    if not item then
        return WALKMAN_UI_VARIANT_FALLBACK
    end

    if item.getScriptItem then
        local okScript, scriptItem = pcall(item.getScriptItem, item)
        if okScript and scriptItem then
            if scriptItem.getWorldStaticModel then
                local okWorld, token = pcall(scriptItem.getWorldStaticModel, scriptItem)
                local variant = okWorld and normalizeWalkmanVariantToken(token) or nil
                if variant then
                    return variant
                end
            end
            if scriptItem.getStaticModel then
                local okStatic, token = pcall(scriptItem.getStaticModel, scriptItem)
                local variant = okStatic and normalizeWalkmanVariantToken(token) or nil
                if variant then
                    return variant
                end
            end
        end
    end

    if item.getWorldStaticModel then
        local okWorld, token = pcall(item.getWorldStaticModel, item)
        local variant = okWorld and normalizeWalkmanVariantToken(token) or nil
        if variant then
            return variant
        end
    end

    if item.getStaticModel then
        local okStatic, token = pcall(item.getStaticModel, item)
        local variant = okStatic and normalizeWalkmanVariantToken(token) or nil
        if variant then
            return variant
        end
    end

    if item.getFullType then
        local variant = normalizeWalkmanVariantToken(item:getFullType())
        if variant then
            return variant
        end
    end

    if item.getType then
        local variant = normalizeWalkmanVariantToken(item:getType())
        if variant then
            return variant
        end
    end

    return WALKMAN_UI_VARIANT_FALLBACK
end

function getWalkmanUITexturesForVariant(variant)
    local token = normalizeWalkmanVariantToken(variant) or WALKMAN_UI_VARIANT_FALLBACK
    local cacheKey = token .. "|" .. getFancyTextureScaleKey()
    local cached = WALKMAN_UI_TEXTURES_BY_VARIANT[cacheKey]
    if cached then
        return cached
    end

    local basePath = BACKPLATE_BASE_TEXTURE_PATH
    if token == "White" then
        basePath = BACKPLATE_BASE_DARK_TEXTURE_PATH
    end

    local textures = {
        variant = token,
        base = getFancyTexture(basePath),
        side = getFancyTexture("media/textures/UI/Walkman/NM_UI_Walkman_Side_" .. token .. ".png"),
        lid = getFancyTexture("media/textures/UI/Walkman/NM_UI_Walkman_Lid_" .. token .. ".png"),
        play = nil,
        prev = nil,
        next = nil,
        stop = nil,
    }
    if token == "Lore" then
        textures.play = getFancyTexture("media/textures/UI/Walkman/NM_UI_Button_Play_Lore.png")
        textures.prev = getFancyTexture("media/textures/UI/Walkman/NM_UI_Button_Prev_Lore.png")
        textures.next = getFancyTexture("media/textures/UI/Walkman/NM_UI_Button_Next_Lore.png")
        textures.stop = getFancyTexture("media/textures/UI/Walkman/NM_UI_Button_Stop_Lore.png")
    elseif token == "White" then
        textures.play = getFancyTexture(PLAY_BUTTON_DARK_TEXTURE_PATH)
        textures.prev = getFancyTexture(PREV_BUTTON_DARK_TEXTURE_PATH)
        textures.next = getFancyTexture(NEXT_BUTTON_DARK_TEXTURE_PATH)
        textures.stop = getFancyTexture(STOP_BUTTON_TEXTURE_PATH)
    else
        textures.play = getFancyTexture(PLAY_BUTTON_TEXTURE_PATH)
        textures.prev = getFancyTexture(PREV_BUTTON_TEXTURE_PATH)
        textures.next = getFancyTexture(NEXT_BUTTON_TEXTURE_PATH)
        textures.stop = getFancyTexture(STOP_BUTTON_TEXTURE_PATH)
    end
    WALKMAN_UI_TEXTURES_BY_VARIANT[cacheKey] = textures
    return textures
end

function resolveWalkmanCloseTintForVariant(variant)
    local token = normalizeWalkmanVariantToken(variant) or WALKMAN_UI_VARIANT_FALLBACK
    if token == "Moo" then
        return 1.0, 1.0, 1.0
    end
    return 0.78, 0.78, 0.78
end

function WalkmanWindow:resolveWalkmanUIVariant(resolved)
    local ctx = resolved or self:resolveContextCached()
    local item = ctx and ctx.item or nil
    return resolveWalkmanVariantFromItem(item)
end

function WalkmanWindow:resolveWalkmanUITextures(resolvedOrVariant)
    local variant = nil
    if type(resolvedOrVariant) == "string" then
        variant = resolvedOrVariant
    else
        variant = self:resolveWalkmanUIVariant(resolvedOrVariant)
    end
    return getWalkmanUITexturesForVariant(variant)
end

