-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
require "ISUI/ISButton"
require "ui/shared/slots/NMPortableUiSoundContract"
NMPowerButton = NMPowerButton or {}

local UI_TEXTURE_ROOT = "media/textures/UI/"
local POWER_TEX_W = 48
local POWER_TEX_H = 48
local POWER_TEXTURES = {
    off = "UI_NM_Power_Off.png",
    on_power = "UI_NM_Power_On.png",
    on_no_power = "UI_NM_Power_On_NoPower.png"
}
local powerTextureCache = {}

local function powerProbeEnabled()
    return NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("portable_ui") == true
end

local function logPowerProbe(tag, detail)
    if not powerProbeEnabled() then
        return
    end
    NMCore.logChannel("portable_ui", tostring(tag or "power_control"), tostring(detail or ""))
end

local function playPowerClick(window, isTurningOn)
    NMPortableUiSoundContract.playPowerPress(window, isTurningOn == true)
end

local function getUiTexture(fileName)
    if not fileName or not getTexture then
        return nil
    end
    local path = UI_TEXTURE_ROOT .. tostring(fileName)
    local cached = powerTextureCache[path]
    if cached ~= nil then
        return cached ~= false and cached or nil
    end
    local tex = getTexture(path)
    powerTextureCache[path] = tex or false
    return tex
end

local function drawPowerTexture(button, stateToken)
    local textureName = POWER_TEXTURES[tostring(stateToken or "off")] or POWER_TEXTURES.off
    local tex = getUiTexture(textureName)
    if not tex or not button or not button.drawTexture then
        return false
    end
    local w = tonumber(button and button.width) or 0
    local h = tonumber(button and button.height) or 0
    if w <= 0 or h <= 0 then return false end
    local left = math.floor((w - POWER_TEX_W) * 0.5 + 0.5)
    local top = math.floor((h - POWER_TEX_H) * 0.5 + 0.5)
    button:drawTexture(tex, left, top, 1.0, 1.0, 1.0, 1.0)
    return true
end

function NMPowerButton.resolvePowerState(profile, state, externalPowerAvailable)
    if not state or state.isOn ~= true then
        return "off"
    end
    local needsBattery = NMDeviceProfiles.supportsBattery and NMDeviceProfiles.supportsBattery(profile)
    if needsBattery then
        local hasBatteryPower = state.batteryPresent == true and (tonumber(state.batteryCharge) or 0) > 0
        if hasBatteryPower then
            return "on_power"
        end
        return "on_no_power"
    end
    if NMDeviceProfiles.requiresExternalPower and NMDeviceProfiles.requiresExternalPower(profile) then
        if externalPowerAvailable == true then
            return "on_power"
        end
        return "on_no_power"
    end
    if state.isOn == true then
        return "on_power"
    end
    return "off"
end

function NMPowerButton.buildRenderState(window, frame)
    local resolved = frame and frame.resolved or (window and window.resolveContextCached and window:resolveContextCached()) or nil
    local stateToken = "off"
    if resolved then
        local externalPowerAvailable = nil
        if NMDeviceProfiles.requiresExternalPower and NMDeviceProfiles.requiresExternalPower(resolved.profile) then
            externalPowerAvailable = NMInventoryHelpers
                and NMInventoryHelpers.resolveExternalPowerAvailable
                and NMInventoryHelpers.resolveExternalPowerAvailable(resolved.player, resolved.item, resolved.profile)
        end
        stateToken = NMPowerButton.resolvePowerState(resolved.profile, resolved.state, externalPowerAvailable)
    end
    local tooltip = NMTranslations.ui("PowerOff", "Power: OFF")
    if stateToken == "on_power" then
        tooltip = NMTranslations.ui("PowerOn", "Power: ON")
    elseif stateToken == "on_no_power" then
        tooltip = NMTranslations.ui("PowerOnNoPower", "Power: ON (No Power)")
    end
    return {
        stateToken = stateToken,
        tooltip = tooltip,
    }
end

function NMPowerButton.attach(window, x, y, size)
    local btn = ISButton:new(x, y, size, size, "", window, function() end)
    btn:initialise()
    btn:instantiate()
    window:addChild(btn)
    btn.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    btn.backgroundColorMouseOver = { r = 0, g = 0, b = 0, a = 0 }
    btn.backgroundColorPressed = { r = 0, g = 0, b = 0, a = 0 }
    btn.backgroundColorEnabled = { r = 0, g = 0, b = 0, a = 0 }
    btn.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    btn.enable = true
    btn.pressed = false
    btn.target = window
    btn._nmCompatibilityControlType = "button"

    logPowerProbe(
        "power_control_attached",
        string.format(
            "ui=generic targetKind=%s targetItemId=%s targetUuid=%s controlType=%s visible=%s",
            tostring(window and window.target and window.target.kind or ""),
            tostring(window and window.target and window.target.itemId or ""),
            tostring(window and window.target and window.target.uuid or ""),
            tostring(btn._nmCompatibilityControlType or ""),
            tostring(btn.getIsVisible and btn:getIsVisible() == true or btn:isVisible() == true)
        )
    )

    btn.onMouseDown = function(selfBtn, xArg, yArg)
        if not (selfBtn.getIsVisible and selfBtn:getIsVisible() == true) then
            return false
        end
        if selfBtn.enable ~= true then
            return true
        end
        selfBtn.pressed = true
        return true
    end

    btn.onMouseUp = function(selfBtn, xArg, yArg)
        local isVisible = selfBtn.getIsVisible and selfBtn:getIsVisible() == true
        if not isVisible then
            return true
        end
        local process = (selfBtn.pressed == true)
        selfBtn.pressed = false
        if selfBtn.enable and process then
            local win = selfBtn.target
            local resolved = win and win.resolveContextCached and win:resolveContextCached()
                or (win and win.resolveContext and win:resolveContext() or nil)
            local currentIsOn = resolved and resolved.state and resolved.state.isOn == true
            if win then
                local action = currentIsOn and "power_off" or "power_on"
                win:executeUiControl(action, {})
                playPowerClick(win, currentIsOn ~= true)
            end
        end
        return true
    end

    btn.onMouseUpOutside = function(selfBtn, xArg, yArg)
        selfBtn.pressed = false
        return true
    end

    btn.render = function(self)
        self:setTitle("")
        local renderState = window.getRenderState and window:getRenderState("power") or nil
        local stateToken = renderState and renderState.stateToken or "off"
        drawPowerTexture(self, stateToken)
        self.tooltip = renderState and renderState.tooltip or NMTranslations.ui("PowerOff", "Power: OFF")
    end

    return btn
end

NMPowerButton.playPowerClick = playPowerClick
