-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
local env = _G.NMBoomboxWindowEnv
setfenv(1, env)

local FancySettingsWindow = require "ui/shared/host/NMFancySettingsWindow"
local ReadoutLabelRenderer = require "ui/shared/NMReadoutLabelRenderer"
local RenderProbe = require "ui/shared/host/NMFancyUiRenderProbe"

local BUTTON_TEXTURE_BY_KIND = {
    play = "play",
    stop = "stop",
    prev = "prev",
    next = "next",
    eject = "eject",
}

local TOP_BUTTON_TEXTURE_BY_KIND = {
    play = "topPlay",
    stop = "topStop",
    prev = "topPrev",
    next = "topNext",
}

local function drawTextureScaledSafe(window, texture, rect, alpha, r, g, b)
    if texture and rect then
        window:drawTextureScaled(texture, rect.x, rect.y, rect.w, rect.h, alpha or 1.0, r or 1.0, g or 1.0, b or 1.0)
    end
end

local function drawTextureScaledAngleSafe(window, texture, rect, angle, alpha, r, g, b)
    if NMFancyDeviceUiScale and NMFancyDeviceUiScale.drawTextureScaledAngle then
        return NMFancyDeviceUiScale.drawTextureScaledAngle(window, texture, rect, angle, alpha, r, g, b)
    end
    return drawTextureScaledSafe(window, texture, rect, alpha, r, g, b)
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

local function offsetStateRectY(state, offsetY)
    if not state or offsetY == 0 then
        return state
    end
    local copy = {}
    for k, v in pairs(state) do
        copy[k] = v
    end
    if copy.y ~= nil then
        copy.y = copy.y + offsetY
    end
    if copy.rect then
        copy.rect = offsetRectY(copy.rect, offsetY)
    end
    return copy
end

local function resolveCloseTint(model)
    local variant = tostring(model and model.variant or "")
    if variant == "Oddbolt" or variant == "Black" then
        return 1.0, 1.0, 1.0
    end
    return CLOSE_TINT.r, CLOSE_TINT.g, CLOSE_TINT.b
end

local function mainButtonPressed(window, kind)
    if kind == "play" then
        local pulse = window._nmMainButtonPulseByKind[kind]
        return window._nmMainButtonDownByKind.play == true or (pulse and pulse.phase == "down")
    end
    local pulse = window._nmMainButtonPulseByKind[kind]
    return pulse and pulse.phase == "down"
end

local function drawMainButton(window, textures, kind, canvasOffsetY)
    local rect = offsetRectY(window:getMainButtonRect(kind), canvasOffsetY)
    local isPressed = mainButtonPressed(window, kind)
    local topRect = { x = rect.x, y = rect.y, w = rect.w, h = MAIN_BUTTON_TOP_H }
    local midH = isPressed and MAIN_BUTTON_MID_PRESSED_H or MAIN_BUTTON_MID_H
    local midRect = { x = rect.x, y = rect.y + MAIN_BUTTON_TOP_H, w = rect.w, h = midH }
    local bottomRect = { x = rect.x, y = rect.y + MAIN_BUTTON_TOP_H + MAIN_BUTTON_MID_H, w = rect.w, h = isPressed and 0 or MAIN_BUTTON_BOTTOM_H }
    local tint = isPressed and 0.78 or 1.0
    local topTexture = kind == "prev" and textures.buttonTopPrev or textures.buttonTop
    local bottomTexture = kind == "prev" and textures.buttonBottomPrev or textures.buttonBottom
    drawTextureScaledSafe(window, topTexture, topRect, 1.0, tint, tint, tint)
    drawTextureScaledSafe(window, textures[BUTTON_TEXTURE_BY_KIND[kind]], midRect, 1.0, tint, tint, tint)
    if bottomRect.h > 0 then
        drawTextureScaledSafe(window, bottomTexture, bottomRect, 1.0, 1.0, 1.0, 1.0)
    end
end

local function drawTopCollapsedButton(window, textures, kind)
    if window.isCollapsed ~= true then
        return
    end
    local rect = window:getTopCollapsedButtonVisualRect(kind)
    drawTextureScaledSafe(window, textures[TOP_BUTTON_TEXTURE_BY_KIND[kind]], rect, 1.0, 1.0, 1.0, 1.0)
end

local function drawCassetteLabel(window, labelState, canvasOffsetY)
    return ReadoutLabelRenderer.draw(window, labelState, {
        offsetY = canvasOffsetY,
        background = CASSETTE_LABEL_BG,
        color = CASSETTE_LABEL_TEXT_COLOR,
        padX = CASSETTE_LABEL_TEXT_PAD_X,
        font = UIFont.Small,
        cacheName = "cassette",
    })
end

local function resolveVisibleCassetteState(model)
    local timedCassetteState = model and model.timedCassetteState or nil
    if timedCassetteState and timedCassetteState.visible == true then
        return timedCassetteState, true
    end
    return model and model.cassetteMediaState or nil, false
end

local function drawCassetteAssembly(window, model, textures, canvasOffsetY)
    local cassetteState, timedVisible = resolveVisibleCassetteState(model)
    cassetteState = offsetStateRectY(cassetteState, canvasOffsetY)
    if cassetteState and cassetteState.visible == true and cassetteState.texture then
        drawTextureScaledSafe(window, cassetteState.texture, cassetteState, cassetteState.alpha or 1.0)
    end
    if timedVisible ~= true then
        local phaseStart = RenderProbe.begin(window)
        drawCassetteLabel(window, model and model.cassetteLabelState or nil, canvasOffsetY)
        RenderProbe.finish(window, "readout.label", phaseStart)
    end
    if cassetteState and cassetteState.visible == true and textures.spool then
        local phaseStart = RenderProbe.begin(window)
        local leftRect = window:getCassetteSpoolRect(1, cassetteState)
        local rightRect = window:getCassetteSpoolRect(2, cassetteState)
        drawTextureScaledAngleSafe(window, textures.spool, leftRect, tonumber(window._nmLeftSpoolAngle) or 0.0)
        drawTextureScaledAngleSafe(window, textures.spool, rightRect, tonumber(window._nmRightSpoolAngle) or 0.0)
        RenderProbe.finish(window, "cassette.spools", phaseStart)
    end
end

local function resolveLiveBoomboxRenderState(window, resolved, model)
    local epoch = tonumber(window and window._nmFrameEpoch) or 0
    local cached = window and window._nmBoomboxLiveRenderState or nil
    if cached and cached.epoch == epoch then
        return cached
    end

    local variant = model and model.variant or window:getBoomboxVariant(resolved)
    local textures = model and model.textures or window:resolveBoomboxUITextures(variant)
    local effectiveVolume = window._nmKnobDragging == true and window._nmKnobPreviewVolume or window._nmKnobStableVolume
    local wheelAngle = window:getVolumeKnobAngle(effectiveVolume or 1.0)
    local volumeLabelVisible = window:shouldShowVolumeLabel()
    local volumeLabelText = nil
    local volumeLabelRect = nil
    if volumeLabelVisible == true then
        volumeLabelText = window:getVolumeLabelText()
        volumeLabelRect = window:getVolumeLabelRect()
    end
    local lidState = window:getLidRenderState(textures)
    local lidEdgeState = window:getLidEdgeRenderState(lidState)
    local lidIngressVisible = window:shouldShowLidIngressZone()
    local cassetteMediaState = window:getCassetteDisplayMediaState()
    local timedCassetteState = window:getTimedCassetteAnimationState()
    local liveModel = {
        epoch = epoch,
        variant = variant,
        textures = textures,
        wheelAngle = wheelAngle,
        powerSwitchOn = window._nmPowerSwitchOn == true,
        volumeLabelVisible = volumeLabelVisible,
        lidState = lidState,
        lidEdgeState = lidEdgeState,
        lidIngressVisible = lidIngressVisible,
        cassetteMediaState = cassetteMediaState,
        timedCassetteState = timedCassetteState,
    }
    if liveModel.volumeLabelVisible == true then
        liveModel.volumeLabelText = volumeLabelText
        liveModel.volumeLabelRect = volumeLabelRect
    end
    if not (timedCassetteState and timedCassetteState.visible == true) then
        liveModel.cassetteLabelState = window:buildCassetteLabelState(resolved)
    end
    window._nmBoomboxLiveRenderState = liveModel
    return liveModel
end

function BoomboxWindow:prerender()
    local perfStart = NMUIRenderProbe and NMUIRenderProbe.beginWindow and NMUIRenderProbe.beginWindow(self) or nil
    self:beginFrameEpoch("prerender")
    local resolved = self:resolveContextCached()
    local skipPassiveTransportSync = self:hasPassiveTransportSyncForCurrentFrame()
    local passiveTransport = nil
    if skipPassiveTransportSync ~= true then
        passiveTransport = self:resolvePassiveTransportState(resolved)
        local phaseStart = RenderProbe.begin(self)
        self:syncPowerSwitchFromTransport(resolved, false, passiveTransport)
        self:syncPlayButtonFromTransport(resolved, false, passiveTransport)
        RenderProbe.finish(self, "transport.passive_sync", phaseStart)
    end
    local model = self:getRenderModel()
    local liveState = resolveLiveBoomboxRenderState(self, resolved, model)
    local phaseStart = RenderProbe.begin(self)
    ISPanel.prerender(self)
    RenderProbe.finish(self, "panel.children", phaseStart)
    local textures = liveState and liveState.textures or self:resolveBoomboxUITextures()
    local canvasOffsetY = self:getCanvasOffsetY()

    phaseStart = RenderProbe.begin(self)
    drawTopCollapsedButton(self, textures, "play")
    drawTopCollapsedButton(self, textures, "stop")
    drawTopCollapsedButton(self, textures, "prev")
    drawTopCollapsedButton(self, textures, "next")

    drawTextureScaledSafe(self, textures.base, { x = BASE_X, y = BASE_Y + canvasOffsetY, w = BASE_W, h = BASE_H })
    drawTextureScaledSafe(self, textures.front, { x = FRONT_X, y = FRONT_Y + canvasOffsetY, w = FRONT_W, h = FRONT_H })
    RenderProbe.finish(self, "chrome.static", phaseStart)
    drawTextureScaledSafe(self, textures.powerBg, self:getPowerSwitchBgRect())
    drawTextureScaledSafe(self, textures.powerSlide, self:getPowerSwitchSlideRect(liveState and liveState.powerSwitchOn == true))
    drawCassetteAssembly(self, liveState, textures, canvasOffsetY)
    if NMUIRenderProbe and NMUIRenderProbe.endWindow then
        NMUIRenderProbe.endWindow(self, "device.prerender", perfStart)
    end
end

function BoomboxWindow:render()
    local perfFrame = NMUIRenderProbe and NMUIRenderProbe.beginWindow and NMUIRenderProbe.beginWindow(self) or nil
    local perfRender = NMUIRenderProbe and NMUIRenderProbe.beginWindow and NMUIRenderProbe.beginWindow(self) or nil
    ISPanel.render(self)
    local model = self:getRenderModel()
    local resolved = self:resolveContextCached()
    local liveState = resolveLiveBoomboxRenderState(self, resolved, model)
    local textures = liveState and liveState.textures or self:resolveBoomboxUITextures()
    local canvasOffsetY = self:getCanvasOffsetY()
    local volumeBgRect = offsetRectY(self:getVolumeBgRect(), canvasOffsetY)
    drawTextureScaledSafe(self, textures.volumeBg, volumeBgRect)
    if textures.volumeKnob then
        local knobRect = offsetRectY(self:getVolumeKnobRect(), canvasOffsetY)
        drawTextureScaledAngleSafe(self, textures.volumeKnob, knobRect, tonumber(liveState and liveState.wheelAngle) or 0.0)
    end

    if liveState and liveState.lidEdgeState and liveState.lidEdgeState.visible == true then
        local lidEdgeState = offsetStateRectY(liveState.lidEdgeState, canvasOffsetY)
        drawTextureScaledSafe(self, lidEdgeState.texture, lidEdgeState)
    end
    if liveState and liveState.lidState then
        local lidState = offsetStateRectY(liveState.lidState, canvasOffsetY)
        drawTextureScaledSafe(self, lidState.texture, lidState)
    end
    if liveState and liveState.lidIngressVisible == true then
        local ingressRect = offsetRectY(self:getLidIngressZoneRect(), canvasOffsetY)
        self:drawRectBorder(ingressRect.x, ingressRect.y, ingressRect.w, ingressRect.h, LID_INGRESS_BORDER.a, LID_INGRESS_BORDER.r, LID_INGRESS_BORDER.g, LID_INGRESS_BORDER.b)
    end

    drawMainButton(self, textures, "play", canvasOffsetY)
    drawMainButton(self, textures, "stop", canvasOffsetY)
    drawMainButton(self, textures, "prev", canvasOffsetY)
    drawMainButton(self, textures, "next", canvasOffsetY)
    drawMainButton(self, textures, "eject", canvasOffsetY)

    local closeR, closeG, closeB = resolveCloseTint(model)
    drawTextureScaledSafe(self, textures.close, self:getCloseRect(), 1.0, closeR, closeG, closeB)
    local gearTexture = FancySettingsWindow.getGearTexture and FancySettingsWindow.getGearTexture() or nil
    if gearTexture then
        local gearRect = self:getSettingsRect()
        local gearDrawRect = FancySettingsWindow.getGearDrawRect and FancySettingsWindow.getGearDrawRect(gearRect) or gearRect
        local gearAlpha, gearR, gearG, gearB = FancySettingsWindow.resolveGearTint(self, model)
        drawTextureScaledSafe(self, gearTexture, gearDrawRect, gearAlpha, gearR, gearG, gearB)
    end

    for i = 1, 3 do
        local rect = offsetRectY(self:getModeButtonRect(i), canvasOffsetY)
        drawTextureScaledSafe(self, textures.modeBg, rect)
        local selected = self:getSelectedModeIndex() == i
        local buttonRect = selected and { x = rect.x + 1, y = rect.y + 1, w = rect.w - 2, h = rect.h - 2 } or rect
        local tint = selected and MODE_BUTTON_SELECTED_TINT or 1.0
        drawTextureScaledSafe(self, textures.modeButton, buttonRect, 1.0, tint, tint, tint)
        local icon = textures.modeIcons and textures.modeIcons[i] or nil
        if icon then
            local texW = icon.getWidthOrig and icon:getWidthOrig() or 16
            local texH = icon.getHeightOrig and icon:getHeightOrig() or 16
            local pad = math.max(1, math.floor((2 * getFancyDeviceUiScale()) + 0.5))
            local maxW = math.max(1, rect.w - (pad * 2))
            local maxH = math.max(1, rect.h - (pad * 2))
            local fit = math.min(maxW / math.max(1, texW), maxH / math.max(1, texH))
            local iw = math.floor((texW * fit) + 0.5)
            local ih = math.floor((texH * fit) + 0.5)
            local ix = rect.x + math.floor(((rect.w - iw) * 0.5) + 0.5)
            local iy = rect.y + math.floor(((rect.h - ih) * 0.5) + 0.5)
            local iconAlpha = selected and math.min(1.0, MODE_ICON_ALPHA + 0.08) or MODE_ICON_ALPHA
            local iconTint = selected and 0.0 or 0.08
            self:drawTextureScaled(icon, ix, iy, iw, ih, iconAlpha, iconTint, iconTint, iconTint)
        end
    end

    if liveState and liveState.volumeLabelVisible == true then
        local labelRect = offsetRectY(liveState.volumeLabelRect, canvasOffsetY)
        self:drawText(liveState.volumeLabelText, labelRect.x, labelRect.y, 1.0, 1.0, 1.0, 1.0, UIFont.Small)
    end
    if NMUIRenderProbe and NMUIRenderProbe.endWindow then
        NMUIRenderProbe.endWindow(self, "device.render", perfRender)
        NMUIRenderProbe.endWindow(self, "device.frame", perfFrame)
    end
    if NMUIRenderProbe and NMUIRenderProbe.flush then
        NMUIRenderProbe.flush(self)
    end
end
