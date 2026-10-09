-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
local env = _G.NMHeadphoneSlotEnv
setfenv(1, env)

NMHeadphoneSlotTimedAction = NMHeadphoneSlotTimedAction or ISBaseTimedAction:derive("NMHeadphoneSlotTimedAction")

function NMHeadphoneSlotTimedAction:isValid()
    return self.window ~= nil and self.actionName ~= nil and self.actionName ~= ""
end

function NMHeadphoneSlotTimedAction:waitToStart()
    return false
end

function NMHeadphoneSlotTimedAction:start()
    if self.window then
        self.window._nmHeadphoneSlotTimedProgress = { active = true, delta = 0.0, action = self.actionName }
        NMSlotHostLifecycle.invalidateForTimedAction(self.window, { context = true })
    end
end

function NMHeadphoneSlotTimedAction:update()
    local delta = 0.0
    if self.action and self.action.getJobDelta then
        delta = tonumber(self.action:getJobDelta()) or 0.0
    end
    if self.window then
        self.window._nmHeadphoneSlotTimedProgress = {
            active = true,
            delta = NMCore.clamp(delta, 0.0, 1.0),
            action = self.actionName
        }
        NMSlotHostLifecycle.invalidateForTimedAction(self.window, { context = false })
    end
end

function NMHeadphoneSlotTimedAction:stop()
    if self.window then
        self.window._nmHeadphoneSlotTimedProgress = nil
        self.window._nmHeadphoneWearSyncInFlight = false
        if self.actionName == "eject_headphones"
            and NMSlotHostLifecycle
            and NMSlotHostLifecycle.clearAwaitingAuthoritativeSlotEject then
            NMSlotHostLifecycle.clearAwaitingAuthoritativeSlotEject(self.window, "headphones")
        end
        if self.actionName == "eject_headphones" and self.window._nmSlotRemoveInFlightByType then
            self.window._nmSlotRemoveInFlightByType.headphones = nil
        end
        NMSlotHostLifecycle.invalidateForTimedAction(self.window, { context = true })
    end
    ISBaseTimedAction.stop(self)
end

function NMHeadphoneSlotTimedAction:perform()
    if self.window then
        self.window._nmHeadphoneSlotTimedProgress = nil
        local pendingEjectFullType = tostring(self.window._nmPendingHeadphoneSlotFullType or "")
        local ok = self.window:dispatchSlotAction(self.actionName, self.args or {})
        if ok == true then
            self.window._nmPendingHeadphoneSlotFullType = nil
            if self.actionName == "eject_headphones"
                and pendingEjectFullType ~= ""
                and NMSlotHostLifecycle
                and NMSlotHostLifecycle.markAwaitingAuthoritativeSlotEject then
                NMSlotHostLifecycle.markAwaitingAuthoritativeSlotEject(self.window, "headphones", pendingEjectFullType)
            end
            if self.actionName == "insert_headphones" then
                playPortableUiSoundEvent(self.window, "slot_headphone_insert_success")
            elseif self.actionName == "eject_headphones" then
                playPortableUiSoundEvent(self.window, "slot_headphone_eject_success")
            end
        end
        if self.actionName == "eject_headphones" and self.window._nmSlotRemoveInFlightByType then
            self.window._nmSlotRemoveInFlightByType.headphones = nil
        end
        if ok == false then
            if self.actionName == "eject_headphones"
                and NMSlotHostLifecycle
                and NMSlotHostLifecycle.clearAwaitingAuthoritativeSlotEject then
                NMSlotHostLifecycle.clearAwaitingAuthoritativeSlotEject(self.window, "headphones")
            end
            self.window._nmHeadphoneWearSyncInFlight = false
            self.window._nmPendingHeadphoneSlotFullType = nil
        end
        NMSlotHostLifecycle.invalidateForTimedAction(self.window, { context = true })
    end
    ISBaseTimedAction.perform(self)
end

function NMHeadphoneSlotTimedAction:new(playerObj, window, actionName, args)
    local o = ISBaseTimedAction.new(self, playerObj)
    o.stopOnWalk = true
    o.stopOnRun = true
    -- Match vanilla wear/unequip action pacing.
    o.maxTime = 50
    o.playerObj = playerObj
    o.window = window
    o.actionName = tostring(actionName or "")
    o.args = args or {}
    return o
end

