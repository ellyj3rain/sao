require "ui/shared/NMReadoutLabelState"

_G.NMCDPlayerWindow = _G.NMCDPlayerWindow or {}
_G.NMCDPlayerWindowEnv = _G.NMCDPlayerWindowEnv or {}
local env = _G.NMCDPlayerWindowEnv
if getmetatable(env) == nil then
    setmetatable(env, { __index = _G })
end
env.NMCDPlayerWindow = _G.NMCDPlayerWindow
setfenv(1, env)

NMCDPlayerDisplayRenderState = NMCDPlayerDisplayRenderState or {}

local function ensureDisplayIconTextureCache()
    UI_TEXTURES.displayIconByPolicy = UI_TEXTURES.displayIconByPolicy or {}
    return UI_TEXTURES.displayIconByPolicy
end

local function ensureDisplayBatteryTextureCache()
    UI_TEXTURES.displayBatteryByStage = UI_TEXTURES.displayBatteryByStage or {}
    return UI_TEXTURES.displayBatteryByStage
end

local function getDisplayModeIconTexture(policy)
    local key = tostring(policy or "autoplay")
    local texturePath = DISPLAY_MODE_ICON_AUTOPLAY_TEXTURE_PATH
    if key == "loop_song" then
        texturePath = DISPLAY_MODE_ICON_LOOP_SONG_TEXTURE_PATH
    elseif key == "loop_album" then
        texturePath = DISPLAY_MODE_ICON_LOOP_ALBUM_TEXTURE_PATH
    elseif key == "shuffle" then
        texturePath = DISPLAY_MODE_ICON_SHUFFLE_TEXTURE_PATH
    end
    if NMFancyDeviceUiScale and NMFancyDeviceUiScale.resolveTexturePath then
        texturePath = NMFancyDeviceUiScale.resolveTexturePath(texturePath)
    end
    local cache = ensureDisplayIconTextureCache()
    local cacheKey = key .. "|" .. tostring(texturePath or "")
    if cache[cacheKey] == nil and getTexture then
        cache[cacheKey] = getTexture(texturePath) or false
    end
    if cache[cacheKey] == false then
        return nil
    end
    return cache[cacheKey]
end

local function getDisplayBatteryTexture(stageKey)
    local key = tostring(stageKey or "00")
    local texturePath = "media/textures/UI/CDPlayer/NM_UI_CDPlayer_Display_Battery_" .. key .. ".png"
    if NMFancyDeviceUiScale and NMFancyDeviceUiScale.resolveTexturePath then
        texturePath = NMFancyDeviceUiScale.resolveTexturePath(texturePath)
    end
    local cache = ensureDisplayBatteryTextureCache()
    local cacheKey = key .. "|" .. tostring(texturePath or "")
    if cache[cacheKey] == nil and getTexture then
        cache[cacheKey] = getTexture(texturePath) or false
    end
    if cache[cacheKey] == false then
        return nil
    end
    return cache[cacheKey]
end

local function formatDisplayClockText()
    local gameTime = getGameTime and getGameTime() or nil
    if not gameTime then
        return nil
    end

    local hour = nil
    if gameTime.getHour then
        hour = tonumber(gameTime:getHour())
    elseif gameTime.getHours then
        hour = tonumber(gameTime:getHours())
    end

    local minute = nil
    if gameTime.getMinutes then
        minute = tonumber(gameTime:getMinutes())
    elseif gameTime.getMinute then
        minute = tonumber(gameTime:getMinute())
    end

    if minute == nil and gameTime.getTimeOfDay then
        local timeOfDay = tonumber(gameTime:getTimeOfDay())
        if timeOfDay then
            local wholeHour = math.floor(timeOfDay)
            hour = hour or wholeHour
            minute = math.floor((timeOfDay - wholeHour) * 60 + 0.5)
        end
    end

    hour = math.floor(tonumber(hour) or 0)
    minute = math.floor(tonumber(minute) or 0)

    if hour < 0 then
        hour = 0
    elseif hour >= 24 then
        hour = hour % 24
    end
    if minute < 0 then
        minute = 0
    elseif minute >= 60 then
        minute = minute % 60
    end

    local meridiem = hour >= 12 and "PM" or "AM"
    local hour12 = hour % 12
    if hour12 == 0 then
        hour12 = 12
    end
    return string.format("%d:%02d %s", hour12, minute, meridiem)
end

local function resolveBatteryStageKey(window, transport, resolved)
    if not (window and window.isDisplayPoweredOn and window:isDisplayPoweredOn(transport) == true) then
        return nil
    end

    local ctx = resolved or (window.resolveContextCached and window:resolveContextCached()) or nil
    local state = ctx and ctx.state or nil
    local profile = ctx and ctx.profile or nil
    if not (profile and profile.supportsBattery == true) then
        return nil
    end
    if not (state and state.batteryPresent == true) then
        return nil
    end

    local charge = clamp01(tonumber(state.batteryCharge) or 0.0)
    if charge < DISPLAY_BATTERY_FLASH_THRESHOLD then
        local nowMs = tonumber(window._nmFrameNowMs) or getNowMs()
        local phase = math.floor(nowMs / DISPLAY_BATTERY_FLASH_INTERVAL_MS) % 2
        if phase == 0 then
            return "20"
        end
        return "00"
    end
    if charge > 0.80 then
        return "100"
    end
    if charge > 0.60 then
        return "80"
    end
    if charge > 0.40 then
        return "60"
    end
    if charge > 0.20 then
        return "40"
    end
    return "20"
end

function NMCDPlayerDisplayRenderState.buildSongLabelState(window, transport, resolved)
    if not (window and window.isDisplayPoweredOn and window:isDisplayPoweredOn(transport) == true) then
        return nil
    end

    local viewport = window.getDisplayViewportRect and window:getDisplayViewportRect() or nil
    if not viewport then
        return nil
    end

    local ctx = resolved or (window.resolveContextCached and window:resolveContextCached()) or nil
    local state = ctx and ctx.state or nil
    local labelState = NMReadoutLabelState.build(window, {
        state = state,
        contentW = math.max(1, viewport.w - DISPLAY_TEXT_PAD_LEFT - DISPLAY_TEXT_PAD_RIGHT),
        nowMs = tonumber(window._nmFrameNowMs) or getNowMs(),
        pagerHost = window,
        x = viewport.x + DISPLAY_TEXT_PAD_LEFT,
        color = DISPLAY_TEXT_COLOR,
        emptyAsNil = true,
    })
    if not labelState then
        return nil
    end

    local tm = getTextManager and getTextManager() or nil
    local textH = tm and tm.MeasureStringY and tm:MeasureStringY(UIFont.Small, "Ag") or 10
    local textY = viewport.y + viewport.h - DISPLAY_TEXT_PAD_BOTTOM - textH
    local absWindowY = window.getAbsoluteY and window:getAbsoluteY() or window.getY and window:getY() or 0
    local _, screenH = getScreenSize()
    local maxAbsTextY = math.max(0, (tonumber(screenH) or 0) - textH - 2)
    local absTextY = absWindowY + textY
    if absTextY > maxAbsTextY then
        textY = textY - (absTextY - maxAbsTextY)
    end
    local minTextY = viewport.y + DISPLAY_TEXT_PAD_TOP
    if textY < minTextY then
        textY = minTextY
    end

    labelState.x = viewport.x + DISPLAY_TEXT_PAD_LEFT
    labelState.y = textY
    return labelState
end

function NMCDPlayerDisplayRenderState.buildModeIconState(window, transport)
    if not (window and window.isDisplayPoweredOn and window:isDisplayPoweredOn(transport) == true) then
        return nil
    end

    local transportState = NMDeviceUiHost.resolveTransportState(window, {
        transport = transport,
        renderModel = window and window._nmRenderModel or nil,
    })
    local texture = getDisplayModeIconTexture(transportState and transportState.playbackPolicy or "autoplay")
    if not texture then
        return nil
    end

    local viewport = window.getDisplayViewportRect and window:getDisplayViewportRect() or nil
    if not viewport then
        return nil
    end

    return {
        texture = texture,
        x = viewport.x + DISPLAY_MODE_ICON_PAD_LEFT,
        y = viewport.y + DISPLAY_MODE_ICON_PAD_TOP,
        w = DISPLAY_MODE_ICON_TARGET_W,
        h = DISPLAY_MODE_ICON_TARGET_H,
        alpha = DISPLAY_MODE_ICON_ALPHA,
    }
end

function NMCDPlayerDisplayRenderState.buildBatteryIndicatorState(window, transport, resolved)
    local stageKey = resolveBatteryStageKey(window, transport, resolved)
    if not stageKey then
        return nil
    end

    local texture = getDisplayBatteryTexture(stageKey)
    if not texture then
        return nil
    end

    local viewport = window.getDisplayViewportRect and window:getDisplayViewportRect() or nil
    if not viewport then
        return nil
    end

    return {
        texture = texture,
        x = viewport.x + viewport.w - DISPLAY_BATTERY_PAD_RIGHT - DISPLAY_BATTERY_W,
        y = viewport.y + DISPLAY_BATTERY_PAD_TOP,
        w = DISPLAY_BATTERY_W,
        h = DISPLAY_BATTERY_H,
    }
end

function NMCDPlayerDisplayRenderState.buildClockState(window, transport)
    if not (window and window.isDisplayPoweredOn and window:isDisplayPoweredOn(transport) == true) then
        return nil
    end

    local text = formatDisplayClockText()
    if not text or text == "" then
        return nil
    end

    local viewport = window.getDisplayViewportRect and window:getDisplayViewportRect() or nil
    if not viewport then
        return nil
    end

    local tm = getTextManager and getTextManager() or nil
    local textW = tm and tm.MeasureStringX and tm:MeasureStringX(UIFont.Small, text) or (#text * 6)
    return {
        text = text,
        x = viewport.x + math.floor((viewport.w - textW) * 0.5 + 0.5) + DISPLAY_CLOCK_OFFSET_X,
        y = viewport.y + DISPLAY_CLOCK_PAD_TOP,
        color = DISPLAY_TEXT_COLOR,
    }
end

return NMCDPlayerDisplayRenderState
