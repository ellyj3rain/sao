-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
-- Action-specific transition handlers used by NMDeviceTransitions.
NMTransitionActionHandlers = NMTransitionActionHandlers or {}

local function logTrackFinishedTransition(state, outcome, policy, trackIndex, nextTrackIndex, trackCount, observedDurationMs)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("playback_progression")) then
        return
    end
    NMCore.logChannel(
        "playback_progression",
        "track_finished_transition",
        string.format(
            "uuid=%s outcome=%s policy=%s track=%s next=%s count=%s observedDurationMs=%s isOn=%s isPlaying=%s stopReason=%s",
            tostring(state and state.deviceUUID or "nil"),
            tostring(outcome or "unknown"),
            tostring(policy or "autoplay"),
            tostring(trackIndex or "nil"),
            tostring(nextTrackIndex or "nil"),
            tostring(trackCount or "nil"),
            tostring(observedDurationMs or 0),
            tostring(state and state.isOn == true),
            tostring(state and state.isPlaying == true),
            tostring(state and state.lastStopReason or "nil")
        )
    )
end

local function clearShuffleState(state)
    state.shuffleMediaFullType = nil
    state.shuffleTrackCount = nil
    state.shuffleOrder = nil
    state.shuffleCursor = nil
end

local function sameMediaIdentity(state, count)
    local media = tostring(state and state.mediaFullType or "")
    local trackedMedia = tostring(state and state.shuffleMediaFullType or "")
    local trackedCount = tonumber(state and state.shuffleTrackCount) or 0
    return media ~= "" and media == trackedMedia and trackedCount == count
end

local function validateShuffleOrder(order, count)
    if type(order) ~= "table" or count < 1 or #order ~= count then
        return false
    end
    local seen = {}
    for i = 1, #order do
        local idx = tonumber(order[i])
        if not idx then
            return false
        end
        idx = math.floor(idx)
        if idx < 1 or idx > count or seen[idx] == true then
            return false
        end
        seen[idx] = true
    end
    return true
end

local function shuffleRandom(maxValue)
    if maxValue <= 1 then
        return 1
    end
    if ZombRand then
        return ZombRand(maxValue) + 1
    end
    return math.random(maxValue)
end

local function buildShuffleOrder(count, currentTrack)
    local locked = tonumber(currentTrack)
    if locked then
        locked = math.max(1, math.min(count, math.floor(locked)))
    end
    local order = {}
    if locked then
        order[1] = locked
    end
    local rest = {}
    for idx = 1, count do
        if idx ~= locked then
            rest[#rest + 1] = idx
        end
    end
    for i = #rest, 2, -1 do
        local swap = shuffleRandom(i)
        rest[i], rest[swap] = rest[swap], rest[i]
    end
    for i = 1, #rest do
        order[#order + 1] = rest[i]
    end
    return order, locked and 1 or math.min(1, #order)
end

local function writeShuffleState(state, count, order, cursor)
    state.shuffleMediaFullType = tostring(state.mediaFullType or "")
    state.shuffleTrackCount = count
    state.shuffleOrder = order
    state.shuffleCursor = cursor
end

local function ensureShuffleState(state, count, forceReset)
    if count < 1 or tostring(state.mediaFullType or "") == "" then
        clearShuffleState(state)
        return nil, nil, false
    end
    local changed = false
    if forceReset == true
        or not sameMediaIdentity(state, count)
        or not validateShuffleOrder(state.shuffleOrder, count) then
        local order, cursor = buildShuffleOrder(count, state.trackIndex)
        writeShuffleState(state, count, order, cursor)
        return order, cursor, true
    end

    local order = state.shuffleOrder
    local cursor = math.max(1, math.min(#order, math.floor(tonumber(state.shuffleCursor) or 1)))
    if cursor ~= tonumber(state.shuffleCursor) then
        state.shuffleCursor = cursor
        changed = true
    end
    local currentTrack = math.max(1, math.min(count, math.floor(tonumber(state.trackIndex) or 1)))
    if tonumber(order[cursor]) ~= currentTrack then
        local found = nil
        for i = 1, #order do
            if tonumber(order[i]) == currentTrack then
                found = i
                break
            end
        end
        if found then
            cursor = found
            state.shuffleCursor = cursor
            changed = true
        else
            order, cursor = buildShuffleOrder(count, currentTrack)
            writeShuffleState(state, count, order, cursor)
            return order, cursor, true
        end
    end
    return order, cursor, changed
end

local function advanceShuffleTrack(state, count, step, wrapOnPrevious)
    local order, cursor, changed = ensureShuffleState(state, count, false)
    if not order or not cursor then
        return false
    end
    local nextCursor = cursor
    if step > 0 then
        if cursor >= #order then
            order, nextCursor = buildShuffleOrder(count, nil)
            changed = true
        else
            nextCursor = cursor + 1
        end
    else
        if cursor <= 1 then
            nextCursor = wrapOnPrevious == true and #order or 1
        else
            nextCursor = cursor - 1
        end
    end
    if nextCursor ~= cursor or changed == true then
        local nextTrack = tonumber(order[nextCursor]) or tonumber(state.trackIndex) or 1
        state.trackIndex = math.max(1, math.min(count, math.floor(nextTrack)))
        writeShuffleState(state, count, order, nextCursor)
        return true
    end
    return false
end

function NMTransitionActionHandlers.apply(profile, state, action, payload, ops)
    local changed = false

    if action == "insert_media" then
        if state.mediaFullType then return false, "media_present" end
        if payload.mediaCarrier ~= profile.supportedCarrier then return false, "wrong_media" end
        if not payload.mediaFullType then return false, "missing_media" end
        if payload.requiredMediaFullType and tostring(payload.requiredMediaFullType) ~= "" then
            local insertedType = payload.mediaItemFullType or payload.mediaEjectFullType or payload.mediaFullType
            local matchesRequired = false
            if NMMediaContract and NMMediaContract.areMediaEquivalent then
                matchesRequired = NMMediaContract.areMediaEquivalent(insertedType, payload.requiredMediaFullType)
            end
            if not matchesRequired and tostring(insertedType or "") ~= tostring(payload.requiredMediaFullType) then
                return false, "wrong_specific_media"
            end
        end
        state.mediaFullType = payload.mediaFullType
        state.mediaEjectFullType = payload.mediaEjectFullType or payload.mediaFullType
        if payload.requiredMediaFullType and tostring(payload.requiredMediaFullType) ~= "" then
            state.mediaEjectFullType = tostring(payload.requiredMediaFullType)
        end
        state.mediaRecordedMediaIndex = payload.mediaRecordedMediaIndex
        state.mediaDisplayName = payload.mediaDisplayName
        state.trackIndex = 1
        clearShuffleState(state)
        NMTransitionCommon.setStopped(state, nil)
        ops.consumeMediaItemId = payload.mediaItemId
        changed = true

    elseif action == "eject_media" then
        if not state.mediaFullType then return false, "no_media" end
        ops.produceMediaFullType = state.mediaEjectFullType or state.mediaFullType
        ops.produceMediaRecordedMediaIndex = state.mediaRecordedMediaIndex
        state.mediaFullType = nil
        state.mediaEjectFullType = nil
        state.mediaRecordedMediaIndex = nil
        state.mediaDisplayName = nil
        state.trackIndex = 1
        clearShuffleState(state)
        NMTransitionCommon.setStopped(state, "media_ejected")
        changed = true

    elseif action == "insert_headphones" then
        if not NMDeviceProfiles.supportsHeadphones(profile) then return false, "unsupported_headphones" end
        if state.headphoneItemFullType then return false, "headphones_present" end
        if not payload.headphoneItemFullType then return false, "missing_headphones" end
        state.headphoneItemFullType = payload.headphoneItemFullType
        if tostring(payload.headphoneItemFullType) == "Base.Headphones" then
            ops.wearHeadphoneItemId = payload.headphoneItemId
        else
            ops.consumeHeadphoneItemId = payload.headphoneItemId
        end
        changed = true

    elseif action == "eject_headphones" then
        if not NMDeviceProfiles.supportsHeadphones(profile) then return false, "unsupported_headphones" end
        if not state.headphoneItemFullType then return false, "no_headphones" end
        if tostring(state.headphoneItemFullType) == "Base.Headphones" then
            ops.unequipHeadphones = true
        else
            ops.produceHeadphoneFullType = state.headphoneItemFullType
        end
        state.headphoneItemFullType = nil
        if profile.requiresHeadphones then NMTransitionCommon.setStopped(state, "headphones_removed") end
        changed = true

    elseif action == "insert_battery" then
        if not NMDeviceProfiles.supportsBattery(profile) then return false, "unsupported_battery" end
        if state.batteryPresent then return false, "battery_present" end
        state.batteryPresent = true
        state.batteryCharge = NMCore.clamp(tonumber(payload.batteryCharge) or 0.0, 0.0, 1.0)
        ops.consumeBatteryItemId = payload.batteryItemId
        changed = true

    elseif action == "eject_battery" then
        if not NMDeviceProfiles.supportsBattery(profile) then return false, "unsupported_battery" end
        if not state.batteryPresent then return false, "no_battery" end
        ops.produceBatteryCharge = NMCore.clamp(tonumber(state.batteryCharge) or 0.0, 0.0, 1.0)
        state.batteryPresent = false
        state.batteryCharge = 0.0
        if profile.requiresBattery then
            state.isOn = false
            state.desiredIsOn = false
            NMTransitionCommon.setStopped(state, "battery_removed")
        end
        changed = true

    elseif action == "play" then
        if state.isPlaying and state.desiredIsPlaying then
            return false, "already_playing"
        end
        local ok, reason = NMTransitionCommon.canPlay(profile, state, payload.hasTrack == true, payload)
        if not ok then
            NMTransitionCommon.setStopped(state, reason)
            return false, reason
        end
        state.desiredIsPlaying = true
        state.isPlaying = true
        state.lastStopReason = nil
        if tostring(state.playbackPolicy or "autoplay") == "shuffle" then
            local _, _, shuffleChanged = ensureShuffleState(state, tonumber(payload.trackCount) or tonumber(state.trackCount) or 0, false)
            changed = shuffleChanged or changed
        end
        changed = true

    elseif action == "stop" then
        if not (state.isPlaying or state.desiredIsPlaying) then
            return false, "already_stopped"
        end
        NMTransitionCommon.setStopped(state, "manual_stop")
        changed = true

    elseif action == "power_on" or action == "power_off" then
        local want = action == "power_on"
        -- Power can be toggled on even without live power so UI can express On(NoPower).
        -- Actual playback viability remains enforced by canPlay()/runtime policy.
        if state.isOn ~= want or state.desiredIsOn ~= want then
            state.isOn = want
            state.desiredIsOn = want
            changed = true
        end
        if not want and (state.isPlaying or state.desiredIsPlaying) then
            NMTransitionCommon.setStopped(state, "powered_off")
            changed = true
        end

    elseif action == "hold_on" or action == "hold_off" then
        local want = action == "hold_on"
        if state.isHold ~= want then
            state.isHold = want
            changed = true
        end

    elseif action == "mute_on" or action == "mute_off" then
        local want = action == "mute_on"
        local reason = want and tostring(payload.muteReason or "manual") or nil
        if state.isMuted ~= want or state.muteReason ~= reason then
            state.isMuted = want
            state.muteReason = reason
            changed = true
        end

    elseif action == "set_volume" then
        local vol = NMCore.clamp(tonumber(payload.volume) or 1.0, 0.0, 1.0)
        if state.volume ~= vol then state.volume = vol; changed = true end

    elseif action == "next_track" or action == "prev_track" then
        local count = tonumber(payload.trackCount) or 0
        if count < 1 then return false, "no_track" end
        if tostring(state.playbackPolicy or "autoplay") == "shuffle" then
            changed = advanceShuffleTrack(state, count, action == "next_track" and 1 or -1, true) or changed
        else
            local idx = tonumber(state.trackIndex) or 1
            idx = action == "next_track" and (idx + 1) or (idx - 1)
            if idx > count then idx = 1 end
            if idx < 1 then idx = count end
            if idx ~= state.trackIndex then state.trackIndex = idx; changed = true end
        end

    elseif action == "set_output_mode" then
        local mode = tostring(payload.playbackMode or "")
        if mode ~= "inventory" and mode ~= "world" then return false, "invalid_mode" end
        if mode == "world" and not NMDeviceProfiles.canAnyWorldPlayback(profile) then return false, "mode_blocked" end
        if mode == "inventory" and not (NMDeviceProfiles.canInventoryPlayback(profile) or profile.attachedPlaybackMode == "personal") then
            return false, "mode_blocked"
        end
        if state.playbackMode ~= mode then state.playbackMode = mode; changed = true end

    elseif action == "cycle_mode" then
        local policy = tostring(payload.playbackPolicy or "")
        if policy ~= "autoplay" and policy ~= "loop_album" and policy ~= "loop_song" and policy ~= "shuffle" then return false, "invalid_policy" end
        local previous = tostring(state.playbackPolicy or "autoplay")
        if previous ~= policy then
            state.playbackPolicy = policy
            changed = true
            if policy == "shuffle" then
                local _, _, shuffleChanged = ensureShuffleState(state, tonumber(payload.trackCount) or tonumber(state.trackCount) or 0, true)
                changed = shuffleChanged or changed
            else
                clearShuffleState(state)
            end
        end

    elseif action == "track_finished" or action == "track_finished_world" then
        if not state.isPlaying then return false, "not_playing" end
        local count = tonumber(payload.trackCount) or 0
        if count < 1 then
            NMTransitionCommon.setStopped(state, "no_track")
            changed = true
        else
            local idx = math.max(1, math.min(tonumber(state.trackIndex) or 1, count))
            local policy = tostring(state.playbackPolicy or "autoplay")
            local observedDurationMs = tonumber(payload and payload.observedDurationMs) or 0
            if policy == "loop_song" then
                state.lastStopReason = nil
                logTrackFinishedTransition(state, "loop_song", policy, idx, idx, count, observedDurationMs)
                changed = true
            elseif policy == "shuffle" then
                changed = advanceShuffleTrack(state, count, 1, true) or changed
                state.lastStopReason = nil
                logTrackFinishedTransition(state, "shuffle_advance", policy, idx, tonumber(state.trackIndex) or idx, count, observedDurationMs)
            else
                local nextIdx = idx + 1
                if nextIdx > count then nextIdx = 1 end
                if policy == "loop_album" then
                    if nextIdx ~= state.trackIndex then state.trackIndex = nextIdx end
                    state.lastStopReason = nil
                    logTrackFinishedTransition(state, "track_advance", policy, idx, nextIdx, count, observedDurationMs)
                    changed = true
                else
                    if idx >= count then
                        state.trackIndex = 1
                        state.isOn = false
                        state.desiredIsOn = false
                        NMTransitionCommon.setStopped(state, "album_complete_power_off")
                        logTrackFinishedTransition(state, "album_complete_power_off", policy, idx, 1, count, observedDurationMs)
                        changed = true
                    else
                        state.trackIndex = nextIdx
                        state.lastStopReason = nil
                        logTrackFinishedTransition(state, "track_advance", policy, idx, nextIdx, count, observedDurationMs)
                        changed = true
                    end
                end
            end
        end

    else
        return false, "unknown_action"
    end

    return changed, nil
end

