-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
local env = _G.NMBatterySlotEnv
setfenv(1, env)

NMBatterySlotTimedAction = NMBatterySlotTimedAction or ISBaseTimedAction:derive("NMBatterySlotTimedAction")

function NMBatterySlotTimedAction:isValid()
    return self.window ~= nil and self.actionName ~= nil and self.actionName ~= ""
end

function NMBatterySlotTimedAction:waitToStart()
    return false
end

function NMBatterySlotTimedAction:start()
    if self.window then
        self.window._nmBatterySlotTimedProgress = { active = true, delta = 0.0, action = self.actionName }
        NMSlotHostLifecycle.invalidateForTimedAction(self.window, { context = true })
    end
end

function NMBatterySlotTimedAction:update()
    local delta = 0.0
    if self.action and self.action.getJobDelta then
        delta = tonumber(self.action:getJobDelta()) or 0.0
    end
    if self.window then
        self.window._nmBatterySlotTimedProgress = {
            active = true,
            delta = NMCore.clamp(delta, 0.0, 1.0),
            action = self.actionName
        }
        NMSlotHostLifecycle.invalidateForTimedAction(self.window, { context = false })
    end
end

function NMBatterySlotTimedAction:stop()
    if self.window then
        self.window._nmBatterySlotTimedProgress = nil
        if self.actionName == "eject_battery"
            and NMSlotHostLifecycle
            and NMSlotHostLifecycle.clearAwaitingAuthoritativeSlotEject then
            NMSlotHostLifecycle.clearAwaitingAuthoritativeSlotEject(self.window, "battery")
        end
        if self.actionName == "eject_battery" and self.window._nmSlotRemoveInFlightByType then
            self.window._nmSlotRemoveInFlightByType.battery = nil
        end
        NMSlotHostLifecycle.invalidateForTimedAction(self.window, { context = true })
    end
    ISBaseTimedAction.stop(self)
end

function NMBatterySlotTimedAction:perform()
    if self.window then
        self.window._nmBatterySlotTimedProgress = nil
        local pendingEjectFullType = tostring(self.window._nmPendingBatterySlotFullType or "")
        local ok = self.window:dispatchSlotAction(self.actionName, self.args or {})
        if ok == true then
            self.window._nmPendingBatterySlotFullType = nil
            if self.actionName == "eject_battery"
                and pendingEjectFullType ~= ""
                and NMSlotHostLifecycle
                and NMSlotHostLifecycle.markAwaitingAuthoritativeSlotEject then
                NMSlotHostLifecycle.markAwaitingAuthoritativeSlotEject(self.window, "battery", pendingEjectFullType)
            end
            if self.actionName == "insert_battery" then
                playPortableUiSoundEvent(self.window, "slot_battery_insert_success")
            elseif self.actionName == "eject_battery" then
                playPortableUiSoundEvent(self.window, "slot_battery_eject_success")
            end
        end
        if self.actionName == "eject_battery" and self.window._nmSlotRemoveInFlightByType then
            self.window._nmSlotRemoveInFlightByType.battery = nil
        end
        if ok == false then
            if self.actionName == "eject_battery"
                and NMSlotHostLifecycle
                and NMSlotHostLifecycle.clearAwaitingAuthoritativeSlotEject then
                NMSlotHostLifecycle.clearAwaitingAuthoritativeSlotEject(self.window, "battery")
            end
            self.window._nmPendingBatterySlotFullType = nil
        end
        NMSlotHostLifecycle.invalidateForTimedAction(self.window, { context = true })
    end
    ISBaseTimedAction.perform(self)
end

function NMBatterySlotTimedAction:new(playerObj, window, actionName, args)
    local o = ISBaseTimedAction.new(self, playerObj)
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = 80
    o.playerObj = playerObj
    o.window = window
    o.actionName = tostring(actionName or "")
    o.args = args or {}
    return o
end

