-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
NMServerNoListenerPolicy = NMServerNoListenerPolicy or {}

function NMServerNoListenerPolicy.handleNoListenerPresence(entry, state, nowMsValue, deps)
    if type(entry) ~= "table" or type(state) ~= "table" then
        return false
    end
    deps = type(deps) == "table" and deps or {}
    local resolveProfileForEntry = deps.resolveProfileForEntry
    local clearServerTrackTimeline = deps.clearServerTrackTimeline
    local applyRestartResume = deps.applyRestartResume
    local bumpAndSyncAuthoritativeState = deps.bumpAndSyncAuthoritativeState

    if state.isOn ~= true then
        entry._noListenerFreezeActive = nil
        entry._noListenerRestartPending = nil
        entry._noListenerFreezeToken = nil
        entry._noListenerResumeSig = nil
        entry._noListenerMissingSinceMs = nil
        entry._noListenerPresentSinceMs = nil
        return false
    end
    local mode = tostring(state.authoritativeMode or entry.sourceMode or "")
    if mode == "off" or mode == "inventory" or mode == "attached" then
        entry._noListenerFreezeActive = nil
        entry._noListenerRestartPending = nil
        entry._noListenerFreezeToken = nil
        entry._noListenerResumeSig = nil
        entry._noListenerMissingSinceMs = nil
        entry._noListenerPresentSinceMs = nil
        return false
    end

    local profile = type(resolveProfileForEntry) == "function" and resolveProfileForEntry(entry) or nil
    local eval = NMServerListenerEligibility and NMServerListenerEligibility.evaluate and NMServerListenerEligibility.evaluate(entry, state, profile) or nil
    local hasEligibleListener = eval and eval.hasEligibleListener == true
    local freezeDebounceMs = tonumber(NMRuntimeConfig and NMRuntimeConfig.getNoListenerFreezeDebounceMs and NMRuntimeConfig.getNoListenerFreezeDebounceMs() or 3000) or 3000
    local resumeDebounceMs = tonumber(NMRuntimeConfig and NMRuntimeConfig.getNoListenerResumeDebounceMs and NMRuntimeConfig.getNoListenerResumeDebounceMs() or 1000) or 1000

    if not hasEligibleListener then
        entry._noListenerPresentSinceMs = nil
        if tonumber(entry._noListenerMissingSinceMs) == nil then
            entry._noListenerMissingSinceMs = nowMsValue
        end
        if (nowMsValue - (tonumber(entry._noListenerMissingSinceMs) or nowMsValue)) < math.max(0, freezeDebounceMs) then
            return false
        end
        if entry._noListenerFreezeActive ~= true then
            entry._noListenerFreezeActive = true
            entry._noListenerRestartPending = (state.isPlaying == true)
            entry._noListenerFreezeToken = string.format("%s:%s", tostring(tonumber(state.playbackEpoch) or 0), tostring(tonumber(state.trackIndex) or 0))
            if state.isPlaying == true then
                local changed = NMServerCanonicalReducer
                    and NMServerCanonicalReducer.dispatch
                    and NMServerCanonicalReducer.dispatch({
                        eventType = NMServerCanonicalReducer.Event and NMServerCanonicalReducer.Event.NO_LISTENER_FREEZE or "NO_LISTENER_FREEZE",
                        state = state
                    }) == true
                if changed then
                    if type(clearServerTrackTimeline) == "function" then
                        clearServerTrackTimeline(entry, state)
                    end
                    entry._batteryDrainSkipNoListener = true
                    if NMServerItemPowerTick and NMServerItemPowerTick.lastDrainMs then
                        NMServerItemPowerTick.lastDrainMs[tostring(entry.uuid or "")] = nowMsValue
                    end
                    if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
                        NMCore.logChannel(
                            "runtime",
                            "no_listener_freeze_applied",
                            string.format(
                                "uuid=%s mode=%s playbackEpoch=%s trackIndex=%s",
                                tostring(entry.uuid or ""),
                                tostring(mode),
                                tostring(tonumber(state.playbackEpoch) or 0),
                                tostring(tonumber(state.trackIndex) or 0)
                            )
                        )
                    end
                    if type(bumpAndSyncAuthoritativeState) == "function" then
                        bumpAndSyncAuthoritativeState(entry, state)
                    end
                end
            else
                entry._batteryDrainSkipNoListener = true
            end
        end
        return true
    end

    entry._noListenerMissingSinceMs = nil
    if tonumber(entry._noListenerPresentSinceMs) == nil then
        entry._noListenerPresentSinceMs = nowMsValue
    end
    if entry._noListenerFreezeActive == true then
        if (nowMsValue - (tonumber(entry._noListenerPresentSinceMs) or nowMsValue)) < math.max(0, resumeDebounceMs) then
            return true
        end
        local hasBattery = state.batteryPresent ~= true or (tonumber(state.batteryCharge) or 0) > 0
        local shouldResume = entry._noListenerRestartPending == true and state.isOn == true and hasBattery
        if shouldResume then
            local resumeSig = string.format(
                "%s|%s|%s",
                tostring(entry._noListenerFreezeToken or ""),
                tostring(tonumber(state.sourceGeneration) or 0),
                tostring(tonumber(state.revision) or 0)
            )
            if tostring(entry._noListenerResumeSig or "") ~= resumeSig then
                local changed = NMServerCanonicalReducer
                    and NMServerCanonicalReducer.dispatch
                    and NMServerCanonicalReducer.dispatch({
                        eventType = NMServerCanonicalReducer.Event and NMServerCanonicalReducer.Event.NO_LISTENER_RESUME_RESTART or "NO_LISTENER_RESUME_RESTART",
                        state = state,
                        nowMs = nowMsValue
                    }) == true
                if changed then
                    entry._batteryDrainSkipNoListener = nil
                    local timingMode, newDueAtMs = "unknown_open", 0
                    if type(applyRestartResume) == "function" then
                        timingMode, newDueAtMs = applyRestartResume(entry, state, nowMsValue, "restart_no_listener_resume")
                    end
                    entry._noListenerResumeSig = resumeSig
                    if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
                        NMCore.logChannel(
                            "runtime",
                            "no_listener_resume_restart_applied",
                            string.format(
                                "uuid=%s mode=%s timingMode=%s dueAtMs=%s playbackEpoch=%s trackIndex=%s",
                                tostring(entry.uuid or ""),
                                tostring(mode),
                                tostring(timingMode),
                                tostring(math.floor(newDueAtMs)),
                                tostring(tonumber(state.playbackEpoch) or 0),
                                tostring(tonumber(state.trackIndex) or 0)
                            )
                        )
                    end
                end
            end
        end
        entry._noListenerFreezeActive = nil
        entry._noListenerRestartPending = nil
        entry._noListenerFreezeToken = nil
        entry._batteryDrainSkipNoListener = nil
        entry._noListenerPresentSinceMs = nil
        return false
    end

    return false
end

return NMServerNoListenerPolicy

