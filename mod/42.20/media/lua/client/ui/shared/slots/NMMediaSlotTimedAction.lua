-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
local env = _G.NMMediaSlotEnv
setfenv(1, env)

NMMediaSlotTimedAction = NMMediaSlotTimedAction or ISBaseTimedAction:derive("NMMediaSlotTimedAction")

local function logPortableUiProbe(tag, detail)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("portable_ui")) then
        return
    end
    NMCore.logChannel("portable_ui", tostring(tag or "portable_ui"), tostring(detail or ""))
end

local function resolveWindowFamily(window)
    if window and window.target and tostring(window.target.kind or "") == "vehicle" then
        return "vehicle"
    end
    if window and window.getFrontVariant then
        return "cdplayer"
    end
    if window and window.getBoomboxVariant then
        return "boombox"
    end
    if window and window.getLidRect and window.syncLidFromMedia then
        return "walkman"
    end
    return "generic"
end

function NMMediaSlotTimedAction:isValid()
    return self.window ~= nil and self.actionName ~= nil and self.actionName ~= ""
end

function NMMediaSlotTimedAction:waitToStart()
    return false
end

function NMMediaSlotTimedAction:start()
    if self.window then
        local windowFamily = resolveWindowFamily(self.window)
        local isLidWindow = windowFamily == "walkman" or windowFamily == "cdplayer" or windowFamily == "boombox"
        logPortableUiProbe(
            "timed_media_start",
            string.format(
                "ui=%s action=%s targetItemId=%s targetUuid=%s mediaItemId=%s mediaFullType=%s slotTraceId=%s",
                tostring(windowFamily),
                tostring(self.actionName or ""),
                tostring(self.window.target and self.window.target.itemId or ""),
                tostring(self.window.target and self.window.target.uuid or ""),
                tostring(self.args and self.args.mediaItemId or ""),
                tostring(self.window._nmPendingMediaSlotFullType or self.args and (self.args.mediaEjectFullType or self.args.mediaFullType) or ""),
                tostring(self.args and self.args.slotTraceId or "")
            )
        )
        if self.window.clearAwaitingAuthoritativeMediaInsert then
            self.window:clearAwaitingAuthoritativeMediaInsert()
        end
        self.window._nmMediaEjectInterrupted = nil
        if self.actionName == "insert_media" and windowFamily == "cdplayer" then
            self.window._nmCdInsertLandingSoundPlayed = false
        end
        self.window._nmMediaSlotTimedProgress = { active = true, delta = 0.0, action = self.actionName }
        if (windowFamily == "walkman" or windowFamily == "boombox") and self.actionName == "insert_media" then
            self.window._nmSuppressNextLidCloseSound = true
            playPortableUiSoundEvent(self.window, "lid_close")
        end
        if self.actionName == "eject_media" and isLidWindow then
            self.window.isLidManuallyOpen = true
        end
        NMSlotHostLifecycle.invalidateForTimedAction(self.window, { context = true })
        if self.window.syncLidFromMedia then
            self.window:syncLidFromMedia(false)
        end
    end
end

function NMMediaSlotTimedAction:update()
    local delta = 0.0
    if self.action and self.action.getJobDelta then
        delta = tonumber(self.action:getJobDelta()) or 0.0
    end
    if self.window then
        local clampedDelta = NMCore.clamp(delta, 0.0, 1.0)
        self.window._nmMediaSlotTimedProgress = {
            active = true,
            delta = clampedDelta,
            action = self.actionName
        }
        if self.actionName == "insert_media"
            and resolveWindowFamily(self.window) == "cdplayer"
            and self.window._nmCdInsertLandingSoundPlayed ~= true
            and clampedDelta >= 0.985 then
            playPortableUiSoundEvent(self.window, "slot_media_insert_success")
            self.window._nmCdInsertLandingSoundPlayed = true
        end
        NMSlotHostLifecycle.invalidateForTimedAction(self.window, { context = false })
    end
end

function NMMediaSlotTimedAction:stop()
    if self.window then
        logPortableUiProbe(
            "timed_media_stop",
            string.format(
                "ui=%s action=%s targetItemId=%s targetUuid=%s pendingMedia=%s slotTraceId=%s",
                tostring(resolveWindowFamily(self.window)),
                tostring(self.actionName or ""),
                tostring(self.window.target and self.window.target.itemId or ""),
                tostring(self.window.target and self.window.target.uuid or ""),
                tostring(self.window._nmPendingMediaSlotFullType or ""),
                tostring(self.args and self.args.slotTraceId or "")
            )
        )
        self.window._nmMediaSlotTimedProgress = nil
        if self.window.clearAwaitingAuthoritativeMediaEject then
            self.window:clearAwaitingAuthoritativeMediaEject()
        end
        if self.window.clearAwaitingAuthoritativeMediaInsert then
            self.window:clearAwaitingAuthoritativeMediaInsert()
        end
        if self.actionName == "insert_media" then
            self.window._nmSuppressNextLidCloseSound = nil
            self.window._nmCdInsertLandingSoundPlayed = nil
        end
        if self.actionName == "eject_media" and self.window._nmSlotRemoveInFlightByType then
            self.window._nmMediaEjectInterrupted = true
            self.window._nmSlotRemoveInFlightByType.media = nil
        end
        NMSlotHostLifecycle.invalidateForTimedAction(self.window, { context = true })
        if self.window.syncLidFromMedia then
            self.window:syncLidFromMedia(true)
        end
    end
    ISBaseTimedAction.stop(self)
end

function NMMediaSlotTimedAction:perform()
    if self.window then
        local windowFamily = resolveWindowFamily(self.window)
        local suppressSlotSounds = windowFamily == "walkman" or windowFamily == "boombox"
            or (windowFamily == "cdplayer" and self.actionName == "insert_media")
        local pendingInsertFullType = tostring(self.window._nmPendingMediaSlotFullType or "")
        local pendingEjectFullType = tostring(self.window._nmPendingMediaSlotFullType or "")
        logPortableUiProbe(
            "timed_media_perform_begin",
            string.format(
                "ui=%s action=%s targetItemId=%s targetUuid=%s mediaItemId=%s pendingMedia=%s slotTraceId=%s",
                tostring(windowFamily),
                tostring(self.actionName or ""),
                tostring(self.window.target and self.window.target.itemId or ""),
                tostring(self.window.target and self.window.target.uuid or ""),
                tostring(self.args and self.args.mediaItemId or ""),
                tostring(self.window._nmPendingMediaSlotFullType or ""),
                tostring(self.args and self.args.slotTraceId or "")
            )
        )
        self.window._nmMediaSlotTimedProgress = nil
        if self.actionName == "eject_media" then
            self.window._nmMediaEjectInterrupted = nil
        end
        local ok = self.window:dispatchSlotAction(self.actionName, self.args or {})
        logPortableUiProbe(
            "timed_media_perform_result",
            string.format(
                "ui=%s action=%s ok=%s targetItemId=%s targetUuid=%s mediaItemId=%s pendingBefore=%s slotTraceId=%s",
                tostring(windowFamily),
                tostring(self.actionName or ""),
                tostring(ok == true),
                tostring(self.window.target and self.window.target.itemId or ""),
                tostring(self.window.target and self.window.target.uuid or ""),
                tostring(self.args and self.args.mediaItemId or ""),
                tostring(self.actionName == "insert_media" and pendingInsertFullType or pendingEjectFullType),
                tostring(self.args and self.args.slotTraceId or "")
            )
        )
        if ok == true then
            self.window._nmPendingMediaSlotFullType = nil
            if self.actionName == "insert_media"
                and NMCore
                and NMCore.isMPClientRuntime
                and NMCore.isMPClientRuntime()
                and pendingInsertFullType ~= ""
                and self.window.markAwaitingAuthoritativeMediaInsert then
                self.window:markAwaitingAuthoritativeMediaInsert(pendingInsertFullType)
            end
            if self.actionName == "eject_media"
                and NMCore
                and NMCore.isMPClientRuntime
                and NMCore.isMPClientRuntime()
                and pendingEjectFullType ~= ""
                and self.window.markAwaitingAuthoritativeMediaEject then
                self.window:markAwaitingAuthoritativeMediaEject(pendingEjectFullType)
            end
            if not suppressSlotSounds then
                if self.actionName == "insert_media" then
                    playPortableUiSoundEvent(self.window, "slot_media_insert_success")
                elseif self.actionName == "eject_media" then
                    playPortableUiSoundEvent(self.window, "slot_media_eject_success")
                end
            end
        end
        if self.actionName == "eject_media" and self.window._nmSlotRemoveInFlightByType then
            self.window._nmSlotRemoveInFlightByType.media = nil
        end
        if ok == false or self.actionName ~= "insert_media" then
            self.window._nmSuppressNextLidCloseSound = nil
        end
        if ok == false then
            if self.window.clearAwaitingAuthoritativeMediaEject then
                self.window:clearAwaitingAuthoritativeMediaEject()
            end
            if self.window.clearAwaitingAuthoritativeMediaInsert then
                self.window:clearAwaitingAuthoritativeMediaInsert()
            end
            self.window._nmPendingMediaSlotFullType = nil
            self.window._nmCdInsertLandingSoundPlayed = nil
        end
        NMSlotHostLifecycle.invalidateForTimedAction(self.window, { context = true })
        if self.window.syncLidFromMedia then
            self.window:syncLidFromMedia(false)
        end
    end
    ISBaseTimedAction.perform(self)
end

function NMMediaSlotTimedAction:new(playerObj, window, actionName, args)
    local o = ISBaseTimedAction.new(self, playerObj)
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = 40
    o.playerObj = playerObj
    o.window = window
    o.actionName = tostring(actionName or "")
    o.args = args or {}
    return o
end

