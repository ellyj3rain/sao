local env = _G.NMCDPlayerWindowEnv
setfenv(1, env)

local FancySettingsWindow = require "ui/shared/host/NMFancySettingsWindow"
require "ui/cdplayer/NMCDPlayerDisplayRenderState"

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

local function ensureTextureValue(cache, key, path)
    local resolvedPath = path
    if NMFancyDeviceUiScale and NMFancyDeviceUiScale.resolveTexturePath then
        resolvedPath = NMFancyDeviceUiScale.resolveTexturePath(path)
    end
    local cacheKey = tostring(key or "") .. "|" .. tostring(resolvedPath or "")
    if cache[cacheKey] == nil and getTexture then
        cache[cacheKey] = resolvedPath and (getTexture(resolvedPath) or false) or false
    end
    if cache[cacheKey] == false then
        return nil
    end
    return cache[cacheKey]
end

local FRONT_VARIANTS = {
    CDPlayerBlack = "Black",
    CDPlayerBlue = "Blue",
    CDPlayerCow = "Cow",
    CDPlayerCyan = "Cyan",
    CDPlayerGreen = "Green",
    CDPlayerMagenta = "Magenta",
    CDPlayerOrange = "Orange",
    CDPlayerPink = "Pink",
    CDPlayerPurple = "Purple",
    CDPlayerRed = "Red",
    CDPlayerWhite = "White",
    CDPlayerYellow = "Yellow",
}

local function ensureFrontTextureCache()
    UI_TEXTURES.frontByVariant = UI_TEXTURES.frontByVariant or {}
    return UI_TEXTURES.frontByVariant
end

local function ensureButtonTextureCache()
    UI_TEXTURES.buttonByKind = UI_TEXTURES.buttonByKind or {}
    return UI_TEXTURES.buttonByKind
end

local function ensureSideTextureCache()
    UI_TEXTURES.sideButton = UI_TEXTURES.sideButton or {}
    return UI_TEXTURES.sideButton
end

local function ensureLidTextureCache()
    UI_TEXTURES.lidByVariant = UI_TEXTURES.lidByVariant or {}
    return UI_TEXTURES.lidByVariant
end

local function getDisplayTexture(window, transport)
    local cacheKey = "displayOff"
    local texturePath = DISPLAY_TEXTURE_PATH
    if window and window.isDisplayPoweredOn and window:isDisplayPoweredOn(transport) == true then
        cacheKey = "displayOn"
        texturePath = DISPLAY_TEXTURE_ON_PATH
    end
    UI_TEXTURES.displayByState = UI_TEXTURES.displayByState or {}
    return ensureTextureValue(UI_TEXTURES.displayByState, cacheKey, texturePath)
end

local function getAuxIngressTexture()
    UI_TEXTURES.auxIngress = UI_TEXTURES.auxIngress or nil
    return ensureTextureValue(UI_TEXTURES, "auxIngress", AUX_INGRESS_TEXTURE_PATH)
end

local function getRectCenterForOddSizedTexture(rect)
    local x = tonumber(rect and rect.x) or 0
    local y = tonumber(rect and rect.y) or 0
    local w = tonumber(rect and rect.w) or 0
    local h = tonumber(rect and rect.h) or 0
    return x + math.floor(math.max(0, w - 1) * 0.5 + 0.5), y + math.floor(math.max(0, h - 1) * 0.5 + 0.5)
end

local function getSideTexture(key, path)
    local cache = ensureSideTextureCache()
    local cacheKey = tostring(key or "") .. "|" .. tostring(path or "")
    return ensureTextureValue(cache, cacheKey, path)
end

local function resolveFrontVariantFromFullType(fullType)
    local key = tostring(fullType or "")
    if key == "" then
        return FRONT_TEXTURE_FALLBACK_VARIANT
    end
    local short = key:match("([^%.]+)$") or key
    return FRONT_VARIANTS[short] or FRONT_TEXTURE_FALLBACK_VARIANT
end

local function getFrontTexture(variant)
    local resolvedVariant = tostring(variant or FRONT_TEXTURE_FALLBACK_VARIANT or "Cyan")
    local cache = ensureFrontTextureCache()
    local path = tostring(FRONT_TEXTURE_PATH_PREFIX or "") .. resolvedVariant .. ".png"
    return ensureTextureValue(cache, resolvedVariant, path)
end

local function getLidTexture(variant)
    local resolvedVariant = tostring(variant or FRONT_TEXTURE_FALLBACK_VARIANT or "Cyan")
    local cache = ensureLidTextureCache()
    local path = tostring(LID_TEXTURE_PATH_PREFIX or "") .. resolvedVariant .. ".png"
    return ensureTextureValue(cache, resolvedVariant, path)
end

local function resolveCloseTintForVariant(variant)
    local resolvedVariant = tostring(variant or FRONT_TEXTURE_FALLBACK_VARIANT or "Cyan")
    if resolvedVariant == "Cow" or resolvedVariant == "Black" then
        return 1.0, 1.0, 1.0, 1.0
    end
    return CLOSE_TEXTURE_ALPHA, CLOSE_TEXTURE_TINT_R, CLOSE_TEXTURE_TINT_G, CLOSE_TEXTURE_TINT_B
end

function CDPlayerWindow:getFrontVariant()
    local item = self.target and self.target.itemRef or nil
    if item and item.getFullType then
        return resolveFrontVariantFromFullType(item:getFullType())
    end

    local resolved = self.resolveContextCached and self:resolveContextCached() or nil
    local resolvedItem = resolved and resolved.item or nil
    if resolvedItem and resolvedItem.getFullType then
        return resolveFrontVariantFromFullType(resolvedItem:getFullType())
    end

    return FRONT_TEXTURE_FALLBACK_VARIANT
end

function CDPlayerWindow:usesTealButtonVariant()
    return self:getFrontVariant() == "White"
end

function CDPlayerWindow:getButtonTexturePath(kind)
    if self:usesTealButtonVariant() == true then
        if kind == "prev" then
            return "media/textures/UI/CDPlayer/NM_UI_CDPlayer_Teal_Button_Prev.png"
        elseif kind == "next" then
            return "media/textures/UI/CDPlayer/NM_UI_CDPlayer_Teal_Button_Next.png"
        elseif kind == "vol_up" then
            return "media/textures/UI/CDPlayer/NM_UI_CDPlayer_Teal_Button_Vol_Up.png"
        elseif kind == "vol_down" then
            return "media/textures/UI/CDPlayer/NM_UI_CDPlayer_Teal_Button_Vol_Down.png"
        elseif kind == "play_stop" then
            return "media/textures/UI/CDPlayer/NM_UI_CDPlayer_Teal_Button_Play_Stop.png"
        end
    end

    if kind == "prev" then
        return BUTTON_TEXTURE_PREV_PATH
    elseif kind == "next" then
        return BUTTON_TEXTURE_NEXT_PATH
    elseif kind == "vol_up" then
        return BUTTON_TEXTURE_VOL_UP_PATH
    elseif kind == "vol_down" then
        return BUTTON_TEXTURE_VOL_DOWN_PATH
    elseif kind == "play_stop" then
        return BUTTON_TEXTURE_PLAY_STOP_PATH
    end
    return nil
end

function CDPlayerWindow:getButtonTexture(kind)
    local cache = ensureButtonTextureCache()
    local path = self:getButtonTexturePath(kind)
    local cacheKey = tostring(kind or "") .. "|" .. tostring(path or "")
    return ensureTextureValue(cache, cacheKey, path)
end

local function getCDPlayerChromeTextures(window, model, liveState)
    UI_TEXTURES.base = UI_TEXTURES.base or nil
    UI_TEXTURES.close = UI_TEXTURES.close or nil
    local transport = liveState and liveState.transport or nil
    return {
        base = ensureTextureValue(UI_TEXTURES, "base", BASE_TEXTURE_PATH),
        close = ensureTextureValue(UI_TEXTURES, "close", CLOSE_TEXTURE_PATH),
        front = getFrontTexture(model and model.frontVariant or nil),
        lid = getLidTexture(model and model.frontVariant or nil),
        auxIngress = getAuxIngressTexture(),
        display = getDisplayTexture(window, transport),
        sideButtonBg = window:getSideButtonBgTexture(),
        sideButtonFg = window:getSideButtonTexture(),
        indicator = window:getPowerIndicatorTexture(transport),
        hold = window:getHoldButtonTexture(),
        open = window:getOpenButtonTexture(),
        modeLabel = window:getModeLabelTexture(),
        holdLabel = window:getHoldLabelTexture(),
        powerLabel = window:getPowerLabelTexture(),
    }
end

local function resolveCDLiveRenderState(window, resolved, model)
    local epoch = tonumber(window and window._nmFrameEpoch) or 0
    local cached = window and window._nmCDLiveRenderState or nil
    if cached and cached.epoch == epoch then
        return cached
    end

    local transport = NMDeviceUiHost.resolveTransportState(window, {
        resolved = resolved,
        renderModel = model,
    })
    local insertedCDTexture, insertedCDTexturePath = window:getInsertedCDWorldTexture()
    local state = {
        epoch = epoch,
        transport = transport,
        lidState = window:getLidRenderState(),
        displayPoweredOn = window:isDisplayPoweredOn(transport),
        powerIndicatorState = window:getPowerIndicatorState(transport),
        displaySongLabelState = NMCDPlayerDisplayRenderState.buildSongLabelState(window, transport, resolved),
        displayModeIconState = NMCDPlayerDisplayRenderState.buildModeIconState(window, transport),
        displayBatteryState = NMCDPlayerDisplayRenderState.buildBatteryIndicatorState(window, transport, resolved),
        displayClockState = NMCDPlayerDisplayRenderState.buildClockState(window, transport),
        timedCDState = window:getTimedCDAnimationState(),
        insertedCDState = {
            fullType = window:getInsertedMediaFullType(),
            texture = insertedCDTexture,
            texturePath = insertedCDTexturePath,
            scaleTier = NMFancyDeviceUiScale and NMFancyDeviceUiScale.getScaleTier and NMFancyDeviceUiScale.getScaleTier() or "100",
            visible = insertedCDTexture ~= nil,
            spin = window:shouldSpinInsertedCD(transport) == true,
            angle = tonumber(window._nmWorldCDSpinAngle) or 0.0,
            rect = window:getWorldCDRect(),
        },
    }
    window._nmCDLiveRenderState = state
    return state
end

function CDPlayerWindow:getCDLiveRenderState(resolved, model)
    local renderModel = model or (self.getRenderModel and self:getRenderModel() or nil)
    local renderContext = resolved or (self.resolveContextCached and self:resolveContextCached() or nil)
    return resolveCDLiveRenderState(self, renderContext, renderModel)
end

function CDPlayerWindow:getSideButtonTexture()
    local path = SIDE_BUTTON_TEXTURE_PATH
    if self:usesTealButtonVariant() == true then
        path = "media/textures/UI/CDPlayer/NM_UI_CDPlayer_Teal_Button_Power.png"
    end
    return getSideTexture("fg", path)
end

function CDPlayerWindow:getSideButtonBgTexture()
    return getSideTexture("bg", SIDE_BUTTON_BG_TEXTURE_PATH)
end

function CDPlayerWindow:getPowerIndicatorTexture(transport)
    local state = self:getPowerIndicatorState(transport)
    if state == "on" then
        return getSideTexture("indicator_on", POWER_INDICATOR_TEXTURE_ON_PATH)
    end
    if state == "standby" then
        return getSideTexture("indicator_standby", POWER_INDICATOR_TEXTURE_STANDBY_PATH)
    end
    return getSideTexture("indicator_off", POWER_INDICATOR_TEXTURE_OFF_PATH)
end

function CDPlayerWindow:getHoldButtonTexture()
    local path = HOLD_BUTTON_TEXTURE_PATH
    if self:usesTealButtonVariant() == true then
        path = "media/textures/UI/CDPlayer/NM_UI_CDPlayer_Teal_Button_Hold.png"
    end
    return getSideTexture("hold", path)
end

function CDPlayerWindow:getOpenButtonTexture()
    local path = OPEN_BUTTON_TEXTURE_PATH
    if self:usesTealButtonVariant() == true then
        path = "media/textures/UI/CDPlayer/NM_UI_CDPlayer_Teal_Button_Open.png"
    end
    return getSideTexture("open", path)
end

function CDPlayerWindow:getModeLabelTexture()
    return getSideTexture("label_mode", MODE_LABEL_TEXTURE_PATH)
end

function CDPlayerWindow:getHoldLabelTexture()
    return getSideTexture("label_hold", HOLD_LABEL_TEXTURE_PATH)
end

function CDPlayerWindow:getPowerLabelTexture()
    return getSideTexture("label_power", POWER_LABEL_TEXTURE_PATH)
end

function CDPlayerWindow:shouldSpinInsertedCD(transport)
    local timed = self._nmMediaSlotTimedProgress
    if timed and timed.active == true then
        return false
    end
    local transportState = NMDeviceUiHost.resolveTransportState(self, {
        transport = transport,
        renderModel = self._nmRenderModel,
    })
    return transportState and transportState.isPlaying == true and self:hasInsertedMedia() == true or false
end

function CDPlayerWindow:prerender()
    local perfStart = NMUIRenderProbe and NMUIRenderProbe.beginWindow and NMUIRenderProbe.beginWindow(self) or nil
    self:beginFrameEpoch("prerender")
    local model = self:getRenderModel()
    local resolved = self:resolveContextCached()
    local liveState = resolveCDLiveRenderState(self, resolved, model)
    local nowMs = getNowMs()
    if NMHeadphoneSlot and NMHeadphoneSlot.tickWearSyncWindow then
        NMHeadphoneSlot.tickWearSyncWindow(self, {
            nowMs = nowMs,
            resolved = resolved,
            visible = self:shouldShowClosedLidSlots() == true and self.headphoneSlot and self.headphoneSlot.button ~= nil,
            idlePollMs = 1000,
            activePollMs = 250,
        })
    else
        self._nmHeadphoneWearSyncActive = false
    end
    NMSlotHostLifecycle.refreshSlotVisibility(self)
    ISPanel.prerender(self)
    self:syncHoldButtonAnimation(false, liveState and liveState.transport or nil)
    local chromeTextures = getCDPlayerChromeTextures(self, model, liveState)
    if self.backgroundColor then
        self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
    end
    if chromeTextures.base then
        self:drawTextureScaled(chromeTextures.base, 0, 0, self.width, self.height, 1.0, 1.0, 1.0, 1.0)
    end
    if chromeTextures.front then
        local frontRect = self:getFrontRect()
        self:drawTextureScaled(chromeTextures.front, frontRect.x, frontRect.y, frontRect.w, frontRect.h, 1.0, 1.0, 1.0, 1.0)
    end
    if self:shouldShowAuxIngressHighlight() == true and chromeTextures.auxIngress then
        self:drawTextureScaled(chromeTextures.auxIngress, 0, 0, self.width, self.height, 1.0, 1.0, 1.0, 1.0)
    end
    if chromeTextures.display then
        local displayRect = self:getDisplayRect()
        self:drawTextureScaled(chromeTextures.display, displayRect.x, displayRect.y, displayRect.w, displayRect.h, 1.0, 1.0, 1.0, 1.0)
    end
    if chromeTextures.sideButtonBg then
        local modeBgRect = self:getSideButtonBgRect("mode")
        local powerBgRect = self:getSideButtonBgRect("power")
        self:drawTextureScaled(chromeTextures.sideButtonBg, modeBgRect.x, modeBgRect.y, modeBgRect.w, modeBgRect.h, 1.0, 1.0, 1.0, 1.0)
        self:drawTextureScaled(chromeTextures.sideButtonBg, powerBgRect.x, powerBgRect.y, powerBgRect.w, powerBgRect.h, 1.0, 1.0, 1.0, 1.0)
    end
    if chromeTextures.sideButtonFg then
        local sideRenderOrder = { "mode", "power" }
        for i = 1, #sideRenderOrder do
            local kind = sideRenderOrder[i]
            local rect = self:getSideButtonRect(kind)
            if rect then
                local r = 1.0
                local g = 1.0
                local b = 1.0
                if self:isButtonVisuallyPressed(kind) then
                    r = BUTTON_PRESSED_TINT_R
                    g = BUTTON_PRESSED_TINT_G
                    b = BUTTON_PRESSED_TINT_B
                end
                self:drawTextureScaled(chromeTextures.sideButtonFg, rect.x, rect.y, rect.w, rect.h, 1.0, r, g, b)
            end
        end
    end
    if chromeTextures.indicator then
        local indicatorRect = self:getPowerIndicatorRect()
        self:drawTextureScaled(chromeTextures.indicator, indicatorRect.x, indicatorRect.y, indicatorRect.w, indicatorRect.h, 1.0, 1.0, 1.0, 1.0)
    end
    if chromeTextures.hold then
        local holdRect = self:getHoldButtonRect()
        drawTextureScaledAngleSafe(self, chromeTextures.hold, holdRect, tonumber(self._nmHoldButtonAngle) or HOLD_BUTTON_ANGLE_UPRIGHT)
    end
    if chromeTextures.open then
        local openRect = self:getOpenButtonRect()
        local r = 1.0
        local g = 1.0
        local b = 1.0
        if self:isButtonVisuallyPressed("open") then
            r = BUTTON_PRESSED_TINT_R
            g = BUTTON_PRESSED_TINT_G
            b = BUTTON_PRESSED_TINT_B
        end
        self:drawTextureScaled(chromeTextures.open, openRect.x, openRect.y, openRect.w, openRect.h, 1.0, r, g, b)
    end
    if chromeTextures.modeLabel then
        local rect = self:getModeLabelRect()
        self:drawTextureScaled(chromeTextures.modeLabel, rect.x, rect.y, rect.w, rect.h, 1.0, 1.0, 1.0, 1.0)
    end
    if chromeTextures.holdLabel then
        local rect = self:getHoldLabelRect()
        self:drawTextureScaled(chromeTextures.holdLabel, rect.x, rect.y, rect.w, rect.h, 1.0, 1.0, 1.0, 1.0)
    end
    if chromeTextures.powerLabel then
        local rect = self:getPowerLabelRect()
        self:drawTextureScaled(chromeTextures.powerLabel, rect.x, rect.y, rect.w, rect.h, 1.0, 1.0, 1.0, 1.0)
    end
    local timedCDState = liveState and liveState.timedCDState or nil
    if timedCDState and timedCDState.visible == true and timedCDState.texture then
        self:drawTextureScaled(
            timedCDState.texture,
            timedCDState.x,
            timedCDState.y,
            timedCDState.w,
            timedCDState.h,
            clamp01(tonumber(timedCDState.alpha) or 0.0),
            1.0,
            1.0,
            1.0
        )
    else
        local insertedCDState = liveState and liveState.insertedCDState or nil
        local insertedCDTexture = insertedCDState and insertedCDState.texture or nil
        if insertedCDTexture then
            local cdRect = insertedCDState.rect
            if insertedCDState.spin == true then
                drawTextureScaledAngleSafe(self, insertedCDTexture, cdRect, tonumber(insertedCDState.angle) or 0.0)
            else
                self:drawTextureScaled(insertedCDTexture, cdRect.x, cdRect.y, cdRect.w, cdRect.h, 1.0, 1.0, 1.0, 1.0)
            end
        end
    end
    if chromeTextures.lid and liveState and liveState.lidState then
        local lidState = liveState.lidState
        self:drawTextureScaled(chromeTextures.lid, lidState.x, lidState.y, lidState.w, lidState.h, 1.0, 1.0, 1.0, 1.0)
    end
    local renderOrder = { "vol_up", "prev", "next", "vol_down", "play_stop" }
    for i = 1, #renderOrder do
        local kind = renderOrder[i]
        local texture = self:getButtonTexture(kind)
        local rect = self:getButtonRenderRect(kind)
        if texture and rect then
            local r = 1.0
            local g = 1.0
            local b = 1.0
            if self.isButtonVisuallyPressed and self:isButtonVisuallyPressed(kind) then
                r = BUTTON_PRESSED_TINT_R
                g = BUTTON_PRESSED_TINT_G
                b = BUTTON_PRESSED_TINT_B
            end
            self:drawTextureScaled(texture, rect.x, rect.y, rect.w, rect.h, 1.0, r, g, b)
        end
    end
    if NMUIRenderProbe and NMUIRenderProbe.endWindow then
        NMUIRenderProbe.endWindow(self, "device.prerender", perfStart)
    end
end

function CDPlayerWindow:render()
    local perfFrame = NMUIRenderProbe and NMUIRenderProbe.beginWindow and NMUIRenderProbe.beginWindow(self) or nil
    local perfRender = NMUIRenderProbe and NMUIRenderProbe.beginWindow and NMUIRenderProbe.beginWindow(self) or nil
    local model = self:getRenderModel()
    local resolved = self:resolveContextCached()
    local liveState = resolveCDLiveRenderState(self, resolved, model)
    local chromeTextures = getCDPlayerChromeTextures(self, model, liveState)
    ISPanel.render(self)
    local displayBattery = liveState and liveState.displayBatteryState or nil
    if displayBattery then
        self:drawTextureScaled(
            displayBattery.texture,
            displayBattery.x,
            displayBattery.y,
            displayBattery.w,
            displayBattery.h,
            1.0,
            1.0,
            1.0,
            1.0
        )
    end
    local displayModeIcon = liveState and liveState.displayModeIconState or nil
    if displayModeIcon then
        self:drawTextureScaled(
            displayModeIcon.texture,
            displayModeIcon.x,
            displayModeIcon.y,
            displayModeIcon.w,
            displayModeIcon.h,
            displayModeIcon.alpha,
            1.0,
            1.0,
            1.0
        )
    end
    if chromeTextures.close then
        local closeRect = self:getCloseRect()
        local closeAlpha, closeR, closeG, closeB = resolveCloseTintForVariant(model and model.frontVariant or nil)
        self:drawTextureScaled(
            chromeTextures.close,
            closeRect.x,
            closeRect.y,
            closeRect.w,
            closeRect.h,
            closeAlpha,
            closeR,
            closeG,
            closeB
        )
    end
    local gearTexture = FancySettingsWindow.getGearTexture and FancySettingsWindow.getGearTexture() or nil
    if gearTexture then
        local gearRect = self:getSettingsRect()
        local gearDrawRect = FancySettingsWindow.getGearDrawRect and FancySettingsWindow.getGearDrawRect(gearRect) or gearRect
        local gearAlpha, gearR, gearG, gearB = FancySettingsWindow.resolveGearTint(self, model)
        self:drawTextureScaled(gearTexture, gearDrawRect.x, gearDrawRect.y, gearDrawRect.w, gearDrawRect.h, gearAlpha, gearR, gearG, gearB)
    end
    if self.logFrameDiagnostics then
        self:logFrameDiagnostics()
    end
    if NMUIRenderProbe and NMUIRenderProbe.endWindow then
        NMUIRenderProbe.endWindow(self, "device.render", perfRender)
        NMUIRenderProbe.endWindow(self, "device.frame", perfFrame)
    end
    if NMUIRenderProbe and NMUIRenderProbe.flush then
        NMUIRenderProbe.flush(self)
    end
end
