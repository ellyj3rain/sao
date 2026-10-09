-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
local NMUiAutoClose = require "ui/shared/host/NMUiAutoClose"
local FancySettingsWindow = require "ui/shared/host/NMFancySettingsWindow"

local env = _G.NMDeviceWindowEnv
setfenv(1, env)

local GENERIC_GEAR_MAX_SIZE = 13
local GENERIC_GEAR_GAP = 3
local GENERIC_GEAR_TINT = 1.6
local GENERIC_GEAR_TOOLTIP_FALLBACK = "Settings"

local function pointInRect(x, y, rect)
    return rect
        and x >= rect.x
        and y >= rect.y
        and x < rect.x + rect.w
        and y < rect.y + rect.h
end

local function getGenericGearRect(window)
    if not window then
        return nil
    end
    local titleHeight = window.titleBarHeight and window:titleBarHeight() or 16
    local size = math.max(10, math.min(GENERIC_GEAR_MAX_SIZE, titleHeight - 2))
    local closeButton = window.closeButton
    local closeX = closeButton and closeButton.getX and closeButton:getX() or 1
    local closeW = closeButton and closeButton.getWidth and closeButton:getWidth() or math.max(12, titleHeight - 2)
    return {
        x = closeX + closeW + GENERIC_GEAR_GAP,
        y = math.max(1, math.floor((titleHeight - size) * 0.5)),
        w = size,
        h = size
    }
end

local function renderGenericGear(window)
    if not (window and window.drawTextureScaled) then
        return
    end
    local tex = FancySettingsWindow.getGearTexture and FancySettingsWindow.getGearTexture() or nil
    if not tex then
        return
    end
    local rect = getGenericGearRect(window)
    if not rect then
        return
    end
    local alpha = window._nmGenericGearPressed == true and 0.95 or 0.8
    window:drawTextureScaled(tex, rect.x, rect.y, rect.w, rect.h, alpha, GENERIC_GEAR_TINT, GENERIC_GEAR_TINT, GENERIC_GEAR_TINT)
end

local function updateGenericGearTooltip(window, x, y)
    if not window then
        return false
    end
    local settingsTooltip = FancySettingsWindow.getSettingsTooltipText and FancySettingsWindow.getSettingsTooltipText() or GENERIC_GEAR_TOOLTIP_FALLBACK
    if pointInRect(x, y, getGenericGearRect(window)) then
        window.tooltip = settingsTooltip
        return true
    end
    if window.tooltip == settingsTooltip then
        window.tooltip = nil
    end
    return false
end

local function autoCloseProbeEnabled()
    return NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("ui_auto_close") == true
end

local function autoCloseWindowKey(window)
    local target = window and window.target or nil
    if not target then
        return "none"
    end
    if target.kind == "vehicle" then
        return table.concat({
            "vehicle",
            tostring(target.vehicleId or ""),
            tostring(target.partId or "")
        }, "|")
    end
    return table.concat({
        tostring(target.kind or "item"),
        tostring(target.itemId or ""),
        tostring(target.uuid or "")
    }, "|")
end

local function autoCloseProbe(window, tag, detail, throttleMs)
    if not autoCloseProbeEnabled() then
        return
    end
    if not (NMCore and NMCore.logChannel and NMCore.shouldLogEvery) then
        return
    end
    local nowMs = 0
    if getTimestampMs then
        nowMs = tonumber(getTimestampMs()) or 0
    end
    if nowMs <= 0 and getTimestamp then
        nowMs = (tonumber(getTimestamp()) or 0) * 1000
    end
    if nowMs <= 0 and getTimeInMillis then
        nowMs = tonumber(getTimeInMillis()) or 0
    end
    local key = "uiAutoCloseProbe.generic." .. tostring(tag or "unknown") .. "." .. autoCloseWindowKey(window)
    if not NMCore.shouldLogEvery(key, nowMs, throttleMs or 1000) then
        return
    end
    NMCore.logChannel("ui_auto_close", tostring(tag or "autoclose"), tostring(detail or ""))
end

local function logAutoCloseResult(window, result)
    local event = NMUiAutoClose.buildProbeEvent("generic", window and window.target or nil, result, {
        includeNoPositionKind = true,
        includeResolvedKind = true,
        detachedCounter = "autoclose.detached",
        fastWorldCounter = "autoclose.fast",
    })
    if event.counter and NMUIRenderProbe and NMUIRenderProbe.count then
        NMUIRenderProbe.count(window, event.counter, 1)
    end
    autoCloseProbe(window, event.tag, event.detail, event.throttleMs)
end

local function logMissingPowerControl(window)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("ui_lifecycle")) then
        return
    end
    local control = window and window.powerBtn or nil
    local controlType = control and control._nmCompatibilityControlType or ""
    local isVisible = control and control.getIsVisible and control:getIsVisible() == true or false
    if control and isVisible then
        return
    end
    NMCore.logChannel(
        "ui_lifecycle",
        "power_control_missing",
        string.format(
            "ui=generic targetKind=%s targetItemId=%s targetUuid=%s hasControl=%s controlType=%s visible=%s",
            tostring(window and window.target and window.target.kind or ""),
            tostring(window and window.target and window.target.itemId or ""),
            tostring(window and window.target and window.target.uuid or ""),
            tostring(control ~= nil),
            tostring(controlType),
            tostring(isVisible)
        )
    )
end

function DeviceWindow:prerender()
    local perfStart = NMUIRenderProbe and NMUIRenderProbe.beginWindow and NMUIRenderProbe.beginWindow(self) or nil
    self:beginFrameEpoch("prerender")
    NMSlotHostLifecycle.refreshSlotVisibility(self)
    self:buildRenderModel()
    if NMHeadphoneSlot and NMHeadphoneSlot.ensureGhostOverlay then
        NMHeadphoneSlot.ensureGhostOverlay()
    end
    ISCollapsableWindow.prerender(self)
    renderGenericGear(self)
    if NMUIRenderProbe and NMUIRenderProbe.endWindow then
        NMUIRenderProbe.endWindow(self, "device.prerender", perfStart)
    end
end

function DeviceWindow:render()
    local perfFrame = NMUIRenderProbe and NMUIRenderProbe.beginWindow and NMUIRenderProbe.beginWindow(self) or nil
    local perfRender = NMUIRenderProbe and NMUIRenderProbe.beginWindow and NMUIRenderProbe.beginWindow(self) or nil
    if self.volumeFader then
        self.volumeFader:setX(self.width - EDGE_PAD - FADER_W)
    end
    logMissingPowerControl(self)
    ISCollapsableWindow.render(self)
    self:logFrameDiagnostics()
    if NMUIRenderProbe and NMUIRenderProbe.endWindow then
        NMUIRenderProbe.endWindow(self, "device.render", perfRender)
        NMUIRenderProbe.endWindow(self, "device.frame", perfFrame)
    end
    if NMUIRenderProbe and NMUIRenderProbe.flush then
        NMUIRenderProbe.flush(self)
    end
end

function DeviceWindow:onMouseUp(x, y)
    if NMSlotHostLifecycle and NMSlotHostLifecycle.noteHostMouseUp then
        NMSlotHostLifecycle.noteHostMouseUp(self, "generic.onMouseUp")
    end
    if NMSlotHostLifecycle.finalizeOwnedSlotDrag and NMSlotHostLifecycle.finalizeOwnedSlotDrag(self) == true then
        return true
    end
    local shouldOpenSettings = self._nmGenericGearPressed == true and pointInRect(x, y, getGenericGearRect(self))
    self._nmGenericGearPressed = false
    if shouldOpenSettings then
        FancySettingsWindow.openForSourceWindow(self)
        return true
    end
    return ISCollapsableWindow.onMouseUp(self, x, y)
end

function DeviceWindow:onMouseDown(x, y)
    if NMGamepadWindowTracker and NMGamepadWindowTracker.markWindow then
        NMGamepadWindowTracker.markWindow(self, "generic")
    end
    if NMPortableMediaDropArbiter and NMPortableMediaDropArbiter.markWindowInteraction then
        NMPortableMediaDropArbiter.markWindowInteraction(self, "generic")
    end
    if pointInRect(x, y, getGenericGearRect(self)) then
        self._nmGenericGearPressed = true
        self:bringToTop()
        return true
    end
    return ISCollapsableWindow.onMouseDown(self, x, y)
end

function DeviceWindow:onMouseUpOutside(x, y)
    if NMSlotHostLifecycle and NMSlotHostLifecycle.noteHostMouseUp then
        NMSlotHostLifecycle.noteHostMouseUp(self, "generic.onMouseUpOutside")
    end
    if NMSlotHostLifecycle.finalizeOwnedSlotDrag and NMSlotHostLifecycle.finalizeOwnedSlotDrag(self) == true then
        return true
    end
    self._nmGenericGearPressed = false
    return ISCollapsableWindow.onMouseUpOutside(self, x, y)
end

function DeviceWindow:onMouseMove(dx, dy)
    updateGenericGearTooltip(self, self:getMouseX(), self:getMouseY())
    return ISCollapsableWindow.onMouseMove(self, dx, dy)
end

function DeviceWindow:onMouseMoveOutside(dx, dy)
    self._nmGenericGearPressed = false
    local settingsTooltip = FancySettingsWindow.getSettingsTooltipText and FancySettingsWindow.getSettingsTooltipText() or GENERIC_GEAR_TOOLTIP_FALLBACK
    if self.tooltip == settingsTooltip then
        self.tooltip = nil
    end
    return ISCollapsableWindow.onMouseMoveOutside(self, dx, dy)
end

function DeviceWindow:close()
    autoCloseProbe(
        self,
        "autoclose_close",
        string.format(
            "ui=generic player=%s target=%s",
            tostring(self.playerNum or 0),
            tostring(autoCloseWindowKey(self))
        ),
        250
    )
    NMSlotHostLifecycle.cancelSharedSlotDrags(self)
    if NMGamepadWindowTracker and NMGamepadWindowTracker.unregisterWindow then
        NMGamepadWindowTracker.unregisterWindow(self)
    end
    if WindowRegistry and WindowRegistry.unregisterWindow then
        WindowRegistry.unregisterWindow(env, self)
    end
    if env and type(env.liveWindows) == "table" then
        for i = #env.liveWindows, 1, -1 do
            if env.liveWindows[i] == self or not (env.liveWindows[i] and env.liveWindows[i].javaObject) then
                table.remove(env.liveWindows, i)
            end
        end
    end
    ISCollapsableWindow.close(self)
end

function DeviceWindow:update()
    local perfStart = NMUIRenderProbe and NMUIRenderProbe.beginWindow and NMUIRenderProbe.beginWindow(self) or nil
    ISCollapsableWindow.update(self)
    local nowMs = NMUiAutoClose.getNowMs()
    local closed = NMUiAutoClose.tickWindowAutoClose(self, {
        nowMs = nowMs,
        pollMs = 250,
        reasonTag = "generic",
        probeFn = function(window, tick)
            autoCloseProbe(
                window,
                "autoclose_tick",
                string.format(
                    "ui=generic polled=%s nowMs=%s lastMs=%s delta=%s",
                    tostring(tick.due == true),
                    tostring(tick.nowMs),
                    tostring(tick.lastCheckMs),
                    tostring(tick.deltaMs)
                ),
                tick.due == true and 750 or 2000
            )
        end,
        evaluateFn = function(window)
            local perfAutoClose = NMUIRenderProbe and NMUIRenderProbe.beginWindow and NMUIRenderProbe.beginWindow(window) or nil
            local target = window.target
            if target and target.kind ~= "vehicle" and NMUIRenderProbe and NMUIRenderProbe.count then
                NMUIRenderProbe.count(window, "autoclose.slow", 1)
            end
            local result = NMUiAutoClose.evaluateWindowTarget(window, target)
            if NMUIRenderProbe and NMUIRenderProbe.endWindow then
                NMUIRenderProbe.endWindow(window, "device.autoCloseCheck", perfAutoClose)
            end
            return result
        end,
        resultFn = function(window, result)
            logAutoCloseResult(window, result)
        end,
    })
    if closed then
        if NMUIRenderProbe and NMUIRenderProbe.endWindow then
            NMUIRenderProbe.endWindow(self, "device.update", perfStart)
        end
        return
    end

    if NMHeadphoneSlot and NMHeadphoneSlot.tickWearSyncWindow then
        NMHeadphoneSlot.tickWearSyncWindow(self, {
            nowMs = nowMs,
            resolved = self:resolveContext(),
            visible = self._nmShowHeadphoneSlot == true,
            idlePollMs = 1000,
            activePollMs = 200,
        })
    else
        self._nmHeadphoneWearSyncActive = false
    end
    if NMUIRenderProbe and NMUIRenderProbe.endWindow then
        NMUIRenderProbe.endWindow(self, "device.update", perfStart)
    end
end
