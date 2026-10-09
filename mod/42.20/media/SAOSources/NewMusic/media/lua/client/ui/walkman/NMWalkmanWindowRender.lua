local env = _G.NMWalkmanWindowEnv
setfenv(1, env)

local FancySettingsWindow = require "ui/shared/host/NMFancySettingsWindow"
local ReadoutLabelRenderer = require "ui/shared/NMReadoutLabelRenderer"
local RenderProbe = require "ui/shared/host/NMFancyUiRenderProbe"

local WALKMAN_CHROME_TEXTURE_BUNDLES = {}
local WALKMAN_OVERLAY_TEXTURE_BUNDLES = {}

local function getWalkmanTextureScaleKey()
    return NMFancyDeviceUiScale and NMFancyDeviceUiScale.getTextureScaleKey and NMFancyDeviceUiScale.getTextureScaleKey() or "1x"
end

local function ensureTextureSlot(key, path)
    local scaleKey = getWalkmanTextureScaleKey()
    local cacheKey = tostring(key or "") .. "|" .. scaleKey
    UI_TEXTURES[cacheKey] = UI_TEXTURES[cacheKey] or nil
    if UI_TEXTURES[cacheKey] == nil and getTexture then
        local resolvedPath = NMFancyDeviceUiScale and NMFancyDeviceUiScale.resolveTexturePath and NMFancyDeviceUiScale.resolveTexturePath(path) or path
        UI_TEXTURES[cacheKey] = getTexture(resolvedPath) or false
    end
    if UI_TEXTURES[cacheKey] == false then
        return nil
    end
    if key and key ~= "" then
        UI_TEXTURES[key] = UI_TEXTURES[cacheKey]
    end
    return UI_TEXTURES[cacheKey]
end

local function drawTextureScaledAngleSafe(window, texture, rect, angle, alpha, r, g, b)
    if NMFancyDeviceUiScale and NMFancyDeviceUiScale.drawTextureScaledAngle then
        return NMFancyDeviceUiScale.drawTextureScaledAngle(window, texture, rect, angle, alpha, r, g, b)
    end
    if window and texture and rect and window.drawTextureScaled then
        window:drawTextureScaled(texture, rect.x, rect.y, rect.w, rect.h, alpha or 1.0, r or 1.0, g or 1.0, b or 1.0)
        return true
    end
    return false
end

local function buildWalkmanChromeTextures()
    return {
        backplateBase = ensureTextureSlot("backplateBase", BACKPLATE_BASE_TEXTURE_PATH),
        backplateSlotBg = ensureTextureSlot("backplateSlotBg", BACKPLATE_SLOT_BG_TEXTURE_PATH),
        lidEdge = ensureTextureSlot("lidEdge", LID_EDGE_TEXTURE_PATH),
        playButton = ensureTextureSlot("playButton", PLAY_BUTTON_TEXTURE_PATH),
        prevButton = ensureTextureSlot("prevButton", PREV_BUTTON_TEXTURE_PATH),
        nextButton = ensureTextureSlot("nextButton", NEXT_BUTTON_TEXTURE_PATH),
        volumeWheel = ensureTextureSlot("volumeWheel", VOLUME_WHEEL_TEXTURE_PATH),
        loopButton = ensureTextureSlot("loopButton", LOOP_BUTTON_TEXTURE_PATH),
        spool = ensureTextureSlot("spool", SPOOL_TEXTURE_PATH),
    }
end

local function getWalkmanChromeTextures(window)
    local scaleKey = getWalkmanTextureScaleKey()
    local cached = WALKMAN_CHROME_TEXTURE_BUNDLES[scaleKey]
    if cached then
        RenderProbe.count(window, "texture_bundle_cache_hit", 1)
        return cached
    end
    local built = buildWalkmanChromeTextures()
    WALKMAN_CHROME_TEXTURE_BUNDLES[scaleKey] = built
    RenderProbe.count(window, "texture_bundle_cache_miss", 1)
    return built
end

local function buildWalkmanOverlayTextures()
    return {
        close = ensureTextureSlot("close", CLOSE_TEXTURE_PATH),
        stopButton = ensureTextureSlot("stopButton", STOP_BUTTON_TEXTURE_PATH),
    }
end

local function getWalkmanOverlayTextures(window)
    local scaleKey = getWalkmanTextureScaleKey()
    local cached = WALKMAN_OVERLAY_TEXTURE_BUNDLES[scaleKey]
    if cached then
        RenderProbe.count(window, "texture_bundle_cache_hit", 1)
        return cached
    end
    local built = buildWalkmanOverlayTextures()
    WALKMAN_OVERLAY_TEXTURE_BUNDLES[scaleKey] = built
    RenderProbe.count(window, "texture_bundle_cache_miss", 1)
    return built
end

function WalkmanWindow:prerender()
    local perfStart = NMUIRenderProbe and NMUIRenderProbe.beginWindow and NMUIRenderProbe.beginWindow(self) or nil
    self:beginFrameEpoch("prerender")
    local resolved = self:resolveContextCached()
    local model = self:getRenderModel()
    self:syncPlayButtonFromTransport(resolved, true, false)
    local nowMs = getNowMs()
    if NMHeadphoneSlot and NMHeadphoneSlot.tickWearSyncWindow then
        NMHeadphoneSlot.tickWearSyncWindow(self, {
            nowMs = nowMs,
            resolved = resolved,
            visible = self.headphoneSlot and self.headphoneSlot.button ~= nil,
            idlePollMs = 1000,
            activePollMs = 250,
        })
    else
        self._nmHeadphoneWearSyncActive = false
    end
    ISPanel.prerender(self)
    if self.backgroundColor then
        self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
    end
    local chromeTextures = getWalkmanChromeTextures(self)
    if chromeTextures.volumeWheel then
        local wheelRect = self:getVolumeWheelRect()
        local effectiveVolume = self._nmWheelDragging == true and self._nmWheelPreviewVolume or self._nmWheelStableVolume
        local wheelAngle = self:getVolumeWheelAngle(effectiveVolume or 1.0)
        drawTextureScaledAngleSafe(self, chromeTextures.volumeWheel, wheelRect, wheelAngle)
    end
    if chromeTextures.loopButton then
        local loopRect = self:getLoopButtonRect()
        self:drawTextureScaled(chromeTextures.loopButton, loopRect.x, loopRect.y, loopRect.w, loopRect.h, 1.0, 1.0, 1.0, 1.0)
    end
    local walkmanTextures = model and model.textures or nil
    local playButtonTexture = walkmanTextures and walkmanTextures.play or chromeTextures.playButton
    local prevButtonTexture = walkmanTextures and walkmanTextures.prev or chromeTextures.prevButton
    local nextButtonTexture = walkmanTextures and walkmanTextures.next or chromeTextures.nextButton
    if playButtonTexture then
        local playRect = self:getPlayButtonRect()
        self:drawTextureScaled(playButtonTexture, playRect.x, playRect.y, playRect.w, playRect.h, 1.0, 1.0, 1.0, 1.0)
    end
    if prevButtonTexture then
        local prevRect = self:getPrevButtonRect()
        self:drawTextureScaled(prevButtonTexture, prevRect.x, prevRect.y, prevRect.w, prevRect.h, 1.0, 1.0, 1.0, 1.0)
    end
    if nextButtonTexture then
        local nextRect = self:getNextButtonRect()
        self:drawTextureScaled(nextButtonTexture, nextRect.x, nextRect.y, nextRect.w, nextRect.h, 1.0, 1.0, 1.0, 1.0)
    end
    if walkmanTextures and walkmanTextures.base then
        self:drawTextureScaled(walkmanTextures.base, 0, 0, self.width, self.height, 1.0, 1.0, 1.0, 1.0)
    elseif chromeTextures.backplateBase then
        self:drawTextureScaled(chromeTextures.backplateBase, 0, 0, self.width, self.height, 1.0, 1.0, 1.0, 1.0)
    end
    if walkmanTextures and walkmanTextures.side then
        local sideRect = self:getWalkmanSideRect()
        self:drawTextureScaled(walkmanTextures.side, sideRect.x, sideRect.y, sideRect.w, sideRect.h, 1.0, 1.0, 1.0, 1.0)
    end
    if chromeTextures.backplateSlotBg then
        self:drawTextureScaled(chromeTextures.backplateSlotBg, 0, 0, self.width, self.height, 1.0, 1.0, 1.0, 1.0)
    end
    local timedCassetteState = self:getTimedCassetteAnimationState()
    if timedCassetteState and timedCassetteState.visible == true and timedCassetteState.texture then
        self:drawTextureScaled(timedCassetteState.texture, timedCassetteState.x, timedCassetteState.y, timedCassetteState.w, timedCassetteState.h, timedCassetteState.alpha, 1.0, 1.0, 1.0)
    else
        local cassetteMediaState = model and model.cassetteMediaState or nil
        if cassetteMediaState and cassetteMediaState.visible == true and cassetteMediaState.texture then
            local cassetteRect = self:getCassetteDisplayRect()
            self:drawTextureScaled(cassetteMediaState.texture, cassetteRect.x, cassetteRect.y, cassetteRect.w, cassetteRect.h, 1.0, 1.0, 1.0, 1.0)
            local labelState = NMWalkmanRenderState.buildCassetteLabelState(self, resolved, model and model.variant or nil)
            if labelState then
                ReadoutLabelRenderer.draw(self, labelState, {
                    background = CASSETTE_LABEL_BG,
                    color = CASSETTE_LABEL_TEXT_COLOR,
                    padX = CASSETTE_LABEL_TEXT_PAD_X,
                    font = UIFont.Small,
                    cacheName = "cassette",
                })
            end
            if chromeTextures.spool then
                local leftRect = self:getCassetteSpoolRect(1)
                local rightRect = self:getCassetteSpoolRect(2)
                drawTextureScaledAngleSafe(self, chromeTextures.spool, leftRect, tonumber(self._nmLeftSpoolAngle) or 0.0)
                drawTextureScaledAngleSafe(self, chromeTextures.spool, rightRect, tonumber(self._nmRightSpoolAngle) or 0.0)
            end
        end
    end
    if NMUIRenderProbe and NMUIRenderProbe.endWindow then
        NMUIRenderProbe.endWindow(self, "device.prerender", perfStart)
    end
end

function WalkmanWindow:render()
    local perfFrame = NMUIRenderProbe and NMUIRenderProbe.beginWindow and NMUIRenderProbe.beginWindow(self) or nil
    local perfRender = NMUIRenderProbe and NMUIRenderProbe.beginWindow and NMUIRenderProbe.beginWindow(self) or nil
    local overlayTextures = getWalkmanOverlayTextures(self)
    ISPanel.render(self)
    local model = self:getRenderModel()
    local walkmanTextures = model and model.textures or nil
    local loopIconTexture = self:getLoopIconTexture()
    if loopIconTexture and self:shouldShowLoopIcon() == true then
        local loopIconRect = self:getLoopIconRect(loopIconTexture)
        self:drawTextureScaled(loopIconTexture, loopIconRect.x, loopIconRect.y, loopIconRect.w, loopIconRect.h, LOOP_ICON_ALPHA, 1.0, 1.0, 1.0)
    end
    local stopButtonTexture = walkmanTextures and walkmanTextures.stop or overlayTextures.stopButton
    if self.isPlayButtonDown == true and stopButtonTexture then
        local stopRect = self:getStopButtonRect()
        self:drawTextureScaled(stopButtonTexture, stopRect.x, stopRect.y, stopRect.w, stopRect.h, 1.0, 1.0, 1.0, 1.0)
    end
    if overlayTextures.close then
        local closeRect = self:getCloseRect()
        local closeR, closeG, closeB = 0.78, 0.78, 0.78
        if model and type(model.closeTint) == "table" then
            closeR, closeG, closeB = model.closeTint[1], model.closeTint[2], model.closeTint[3]
        end
        self:drawTextureScaled(overlayTextures.close, closeRect.x, closeRect.y, closeRect.w, closeRect.h, 1.0, closeR, closeG, closeB)
    end
    local gearTexture = FancySettingsWindow.getGearTexture and FancySettingsWindow.getGearTexture() or nil
    if gearTexture then
        local gearRect = self:getSettingsRect()
        local gearDrawRect = FancySettingsWindow.getGearDrawRect and FancySettingsWindow.getGearDrawRect(gearRect) or gearRect
        local gearAlpha, gearR, gearG, gearB = FancySettingsWindow.resolveGearTint(self, model)
        self:drawTextureScaled(gearTexture, gearDrawRect.x, gearDrawRect.y, gearDrawRect.w, gearDrawRect.h, gearAlpha, gearR, gearG, gearB)
    end
    if self:shouldShowVolumeLabel() == true then
        local labelRect = self:getVolumeLabelRect()
        self:drawText(self:getVolumeLabelText(), labelRect.x, labelRect.y, 1.0, 1.0, 1.0, 1.0, UIFont.Small)
    end
    local lidState = self:getLidRenderState(walkmanTextures)
    local lidEdgeState = self:getLidEdgeRenderState(lidState)
    if lidEdgeState and lidEdgeState.texture and lidEdgeState.visible == true then
        self:drawTextureScaled(lidEdgeState.texture, lidEdgeState.x, lidEdgeState.y, lidEdgeState.w, lidEdgeState.h, 1.0, 1.0, 1.0, 1.0)
    end
    if self:shouldShowLidIngressZone() == true then
        local ingressRect = self:getLidIngressZoneRect()
        self:drawRectBorder(ingressRect.x, ingressRect.y, ingressRect.w, ingressRect.h, LID_INGRESS_BORDER.a, LID_INGRESS_BORDER.r, LID_INGRESS_BORDER.g, LID_INGRESS_BORDER.b)
    end
    if lidState and lidState.texture then
        self:drawTextureScaled(lidState.texture, lidState.x, lidState.y, lidState.w, lidState.h, 1.0, 1.0, 1.0, 1.0)
    end
    if NMUIRenderProbe and NMUIRenderProbe.endWindow then
        NMUIRenderProbe.endWindow(self, "device.render", perfRender)
        NMUIRenderProbe.endWindow(self, "device.frame", perfFrame)
    end
    if NMUIRenderProbe and NMUIRenderProbe.flush then
        NMUIRenderProbe.flush(self)
    end
end

