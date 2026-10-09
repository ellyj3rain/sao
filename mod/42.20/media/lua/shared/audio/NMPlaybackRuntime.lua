-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
-- Playback runtime state and emitter lifecycle for local and detached sources.
NMPlaybackRuntime = NMPlaybackRuntime or {}
NMPlaybackRuntime.Active = NMPlaybackRuntime.Active or {}
NMPlaybackRuntime.TrackEnded = NMPlaybackRuntime.TrackEnded or {}
NMPlaybackRuntime.TrackEndPending = NMPlaybackRuntime.TrackEndPending or {}
NMPlaybackRuntime.TrackEndAwaitingAdvance = NMPlaybackRuntime.TrackEndAwaitingAdvance or {}
NMPlaybackRuntime.MissingSinceTick = NMPlaybackRuntime.MissingSinceTick or {}
NMPlaybackRuntime.MissingSinceMs = NMPlaybackRuntime.MissingSinceMs or {}
NMPlaybackRuntime.PowerTick = NMPlaybackRuntime.PowerTick or {}
NMPlaybackRuntime._corpseAudioSeen = NMPlaybackRuntime._corpseAudioSeen or {}
NMPlaybackRuntime.SoundStartFailures = NMPlaybackRuntime.SoundStartFailures or {}
local runtimeDiag = type(NMPlaybackRuntimeDiagnostics) == "table" and NMPlaybackRuntimeDiagnostics or {
    ensure = function(_) end,
    updateVehicleEmitter = function(_, _, _, _, _) end,
    logEmitterTeardown = function(_, _, _, _) end,
    snapshot = function(_) return {} end
}
runtimeDiag.ensure(NMPlaybackRuntime)
local ATTACHED_WORLD_SMOOTH_MS = 125
local ATTACHED_WORLD_SNAP_DIST = 6.0
local SOUND_START_FAILURE_COOLDOWN_MS = 300000

local function shouldLogLifecycleProbe(tag, uuid, signature, minIntervalMs)
    if runtimeDiag and runtimeDiag.shouldLogLifecycleProbe then
        return runtimeDiag.shouldLogLifecycleProbe(NMPlaybackRuntime, tag, uuid, signature, minIntervalMs)
    end
    return true
end

local function countActiveChannels(active)
    if not active then
        return 0
    end
    if active.mode == "dual" then
        local count = 0
        if active.world then
            count = count + 1
        end
        if active.personal then
            count = count + 1
        end
        return count
    end
    return 1
end

local function stopPlaybackChannel(channel)
    if channel and channel.emitter and channel.soundId then
        if channel.emitter.stopSound then
            channel.emitter:stopSound(channel.soundId)
        elseif channel.emitter.stopAll then
            channel.emitter:stopAll()
        end
    end
end

local function stopActiveInstance(active)
    if not active then
        return
    end
    if active.mode == "dual" then
        stopPlaybackChannel(active.world)
        stopPlaybackChannel(active.personal)
        return
    end
    stopPlaybackChannel(active)
end

local function stopEntry(uuid, reason)
    local key = tostring(uuid or "")
    if key == "" then return end
    local active = NMPlaybackRuntime.Active[key]
    local hasActive = active ~= nil
    if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
        local context = tostring(active and active.context or "nil")
        local missingTick = tonumber(NMPlaybackRuntime.MissingSinceTick[key])
        local missingMs = tonumber(NMPlaybackRuntime.MissingSinceMs[key])
        if hasActive then
            NMCore.logChannel(
                "runtime",
                "playback_stop_reason",
                string.format(
                    "uuid=%s reason=%s context=%s missingTick=%s missingMs=%s",
                    tostring(key),
                    tostring(reason or "unknown"),
                    tostring(context),
                    tostring(missingTick ~= nil and missingTick or "nil"),
                    tostring(missingMs ~= nil and missingMs or "nil")
                )
            )
        elseif tostring(reason or "") ~= "not_playing" then
            local signature = tostring(reason or "unknown") .. "|ignored"
            if shouldLogLifecycleProbe("playback_stop_ignored", key, signature, 1000) then
                NMCore.logChannel(
                    "runtime",
                    "playback_stop_ignored",
                    string.format(
                        "uuid=%s reason=%s context=%s missingTick=%s missingMs=%s",
                        tostring(key),
                        tostring(reason or "unknown"),
                        tostring(context),
                        tostring(missingTick ~= nil and missingTick or "nil"),
                        tostring(missingMs ~= nil and missingMs or "nil")
                    )
                )
            end
        end
    end
    if runtimeDiag and runtimeDiag.countEvent then
        runtimeDiag.countEvent(NMPlaybackRuntime, "emitter_stops", countActiveChannels(active))
    end
    if runtimeDiag and runtimeDiag.logEmitterTeardown then
        runtimeDiag.logEmitterTeardown(NMPlaybackRuntime, key, reason, active)
    end
    stopActiveInstance(active)
    if tostring(reason or "") ~= "track_end" then
        NMPlaybackRuntime.TrackEnded[key] = nil
        NMPlaybackRuntime.TrackEndAwaitingAdvance[key] = nil
    end
    NMPlaybackRuntime.TrackEndPending[key] = nil
    NMPlaybackRuntime.Active[key] = nil
    NMPlaybackRuntime.MissingSinceMs[key] = nil
end

local function isMPVehicleContext(context)
    return tostring(context or "") == "vehicle"
        and NMCore
        and NMCore.isMPClientRuntime
        and NMCore.isMPClientRuntime()
end

local function isMPWorldItemAuthorityContext(context, state)
    if not (NMCore and NMCore.isMPClientRuntime and NMCore.isMPClientRuntime()) then
        return false
    end
    if tostring(state and state.playbackMode or "") ~= "world" then
        return false
    end
    local mode = tostring(context or "")
    return mode ~= "inventory" and mode ~= "vehicle"
end

local function getPlaybackEmitter(player, source, useWorldOutput)
    if useWorldOutput and source and source.x and source.y and source.z and getWorld and getWorld() and getWorld().getFreeEmitter then
        local emitter = getWorld():getFreeEmitter(source.x, source.y, source.z)
        if emitter and emitter.setPos then
            emitter:setPos(source.x, source.y, source.z)
        end
        if emitter then
            if runtimeDiag and runtimeDiag.countEvent then
                runtimeDiag.countEvent(NMPlaybackRuntime, "world_emitter_acquires", 1)
            end
            return emitter, true
        end
    end
    if player and player.getEmitter then
        local emitter = player:getEmitter()
        if emitter then
            return emitter, false
        end
    end
    return nil, false
end

local function getCurrentTrack(state)
    if not state or not state.mediaFullType or not NMMusic or not NMMusic.resolveTracks then
        return nil, nil
    end
    local startedMs = NMPlaybackRuntimeCommon.getNowRealMs and NMPlaybackRuntimeCommon.getNowRealMs() or 0
    local ok, resolved = pcall(NMMusic.resolveTracks, state.mediaFullType)
    if runtimeDiag and runtimeDiag.countEvent then
        runtimeDiag.countEvent(NMPlaybackRuntime, "resolve_tracks_calls", 1)
    end
    if runtimeDiag and runtimeDiag.observeDuration then
        local finishedMs = NMPlaybackRuntimeCommon.getNowRealMs and NMPlaybackRuntimeCommon.getNowRealMs() or startedMs
        runtimeDiag.observeDuration(NMPlaybackRuntime, "resolve_tracks_ms", math.max(0, finishedMs - startedMs))
    end
    if not ok or type(resolved) ~= "table" or type(resolved.tracks) ~= "table" or #resolved.tracks < 1 then
        return nil, nil
    end
    local idx = tonumber(state.trackIndex) or 1
    if idx < 1 then idx = 1 end
    if idx > #resolved.tracks then idx = #resolved.tracks end
    state.trackIndex = idx
    return resolved.tracks[idx], resolved
end

local function parseModuleName(fullType)
    if not fullType then
        return nil
    end
    local s = tostring(fullType)
    local dotPos = string.find(s, "%.")
    if not dotPos then
        return nil
    end
    return string.sub(s, 1, dotPos - 1)
end

local function buildSoundCandidates(track, state)
    local out = {}
    local seen = {}
    local function push(value)
        if not value then return end
        local s = tostring(value)
        if s == "" or seen[s] then return end
        seen[s] = true
        out[#out + 1] = s
    end

    local raw = track and track.sound and tostring(track.sound) or nil
    local moduleName = parseModuleName(state and state.mediaFullType)
    push(raw)
    if moduleName and raw then
        push(moduleName .. "." .. raw)
        push(moduleName .. "_" .. raw)
    end
    return out
end

local function normalizeId(soundId)
    if soundId == nil then return nil end
    if tonumber(soundId) == 0 then return nil end
    return soundId
end

local function startSoundFromCandidates(emitter, candidates)
    if not emitter or type(candidates) ~= "table" then
        return nil, nil
    end
    if runtimeDiag and runtimeDiag.countEvent then
        runtimeDiag.countEvent(NMPlaybackRuntime, "sound_start_attempts", 1)
    end
    local soundIsoObj = nil
    if IsoObject and IsoObject.new then
        soundIsoObj = IsoObject.new()
    end
    for i = 1, #candidates do
        local candidate = candidates[i]
        local soundId = nil
        if emitter.playSoundImpl then
            local okImpl, id = pcall(emitter.playSoundImpl, emitter, candidate, soundIsoObj)
            if okImpl then
                soundId = normalizeId(id)
            elseif NMCore and NMCore.logChannel then
                NMCore.logChannel("emitter", "sound_start_exception", "method=playSoundImpl sound=" .. tostring(candidate) .. " err=" .. tostring(id))
            end
        end
        if soundId == nil and emitter.playSound then
            local okPlay, id = pcall(emitter.playSound, emitter, candidate)
            if okPlay then
                soundId = normalizeId(id)
            elseif NMCore and NMCore.logChannel then
                NMCore.logChannel("emitter", "sound_start_exception", "method=playSound sound=" .. tostring(candidate) .. " err=" .. tostring(id))
            end
        end
        if soundId then
            return soundId, candidate
        end
    end
    if runtimeDiag and runtimeDiag.countEvent then
        runtimeDiag.countEvent(NMPlaybackRuntime, "sound_start_failures", 1)
    end
    return nil, nil
end

local function getSourceMode(context, state, source)
    local sourceMode = tostring(source and (source.sourceMode or source.context) or "")
    if sourceMode ~= "" then
        return sourceMode
    end
    local authoritativeMode = tostring(state and state.authoritativeMode or "")
    if authoritativeMode ~= "" then
        return authoritativeMode
    end
    return tostring(context or "")
end

local function joinCandidates(candidates, maxCount)
    if type(candidates) ~= "table" or #candidates < 1 then
        return ""
    end
    local limit = math.max(1, tonumber(maxCount) or 6)
    local out = {}
    local count = math.min(#candidates, limit)
    for i = 1, count do
        out[#out + 1] = tostring(candidates[i])
    end
    if #candidates > count then
        out[#out + 1] = "..."
    end
    return table.concat(out, ",")
end

local function buildSoundStartFailureKey(uuid, state, candidates)
    local keyUuid = tostring(uuid or state and state.deviceUUID or "")
    if keyUuid == "" then
        return nil
    end
    return table.concat({
        keyUuid,
        tostring(state and state.mediaFullType or ""),
        tostring(tonumber(state and state.playbackEpoch) or 0),
        tostring(tonumber(state and state.trackIndex) or 0),
        joinCandidates(candidates, 12)
    }, "|")
end

local function getNowRealMsSafe()
    return NMPlaybackRuntimeCommon
        and NMPlaybackRuntimeCommon.getNowRealMs
        and NMPlaybackRuntimeCommon.getNowRealMs()
        or 0
end

local function getSoundStartFailureHold(uuid, state, candidates)
    local key = buildSoundStartFailureKey(uuid, state, candidates)
    if not key then
        return nil, nil
    end
    local entry = NMPlaybackRuntime.SoundStartFailures[key]
    if not entry then
        return nil, key
    end
    local nowMs = getNowRealMsSafe()
    if nowMs <= 0 or (nowMs - (tonumber(entry.lastMs) or 0)) >= SOUND_START_FAILURE_COOLDOWN_MS then
        NMPlaybackRuntime.SoundStartFailures[key] = nil
        return nil, key
    end
    return entry, key
end

local function noteSoundStartFailure(uuid, state, candidates, reason)
    local key = buildSoundStartFailureKey(uuid, state, candidates)
    if not key then
        return
    end
    local nowMs = getNowRealMsSafe()
    NMPlaybackRuntime.SoundStartFailures[key] = {
        lastMs = nowMs,
        reason = tostring(reason or "sound_start_failed"),
        mediaFullType = tostring(state and state.mediaFullType or ""),
        playbackEpoch = tonumber(state and state.playbackEpoch) or 0,
        trackIndex = tonumber(state and state.trackIndex) or 0,
        candidates = joinCandidates(candidates, 12)
    }
end

local function clearSoundStartFailure(uuid, state, candidates)
    local key = buildSoundStartFailureKey(uuid, state, candidates)
    if key then
        NMPlaybackRuntime.SoundStartFailures[key] = nil
    end
end

local function logTransitionProbe(msg, detail)
    if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("playback_transition") then
        NMCore.logChannel("playback_transition", msg, detail)
    end
end

local function logPortableTrackProgression(uuid, detail)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("playback_progression")) then
        return
    end
    NMCore.logChannel(
        "playback_progression",
        "portable_track_progression",
        string.format("uuid=%s %s", tostring(uuid or ""), tostring(detail or ""))
    )
end

local function isCorpseRecoveredState(state)
    return type(state) == "table" and (state._nmCorpseRecovered == true or tostring(state.lastStopReason or "") == "corpse_reconcile")
end

local function logCorpseAudio(uuid, tag, detail)
    if not (NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("zombie_corpse")) then
        return
    end
    local key = tostring(uuid or "") .. "|" .. tostring(tag or "")
    local sig = tostring(detail or "")
    if NMPlaybackRuntime._corpseAudioSeen[key] == sig then
        return
    end
    NMPlaybackRuntime._corpseAudioSeen[key] = sig
    if NMCore and NMCore.logChannel then
        NMCore.logChannel("zombie_corpse", tostring(tag or "corpse_audio"), tostring(detail or ""))
    end
end

local function isVehicleDualEmitterEnabled(context)
    return tostring(context or "") == "vehicle"
        and NMRuntimeConfig.getVehicleDualEmittersEnabled
        and NMRuntimeConfig.getVehicleDualEmittersEnabled() == true
end

local function makeSingleActive(emitter, soundId, selectedSound, state, source, context, trackCount, isWorldEmitter, centeredWorldOutput, rendererIntent, sound3D)
    return {
        mode = "single",
        emitter = emitter,
        soundId = soundId,
        sound = selectedSound,
        epoch = tonumber(state.playbackEpoch) or 0,
        isWorldEmitter = isWorldEmitter == true,
        _centeredWorldOutput = centeredWorldOutput == true,
        _sound3D = sound3D == nil and isWorldEmitter == true or sound3D == true,
        _rendererIntent = tostring(rendererIntent or (centeredWorldOutput == true and "world_centered" or (isWorldEmitter == true and "world_3d" or "personal"))),
        context = context,
        sourceGeneration = tonumber(state.sourceGeneration) or 0,
        trackIndex = tonumber(state.trackIndex) or 1,
        trackCount = tonumber(trackCount) or 1,
        startedAtMs = NMPlaybackRuntimeCommon.getNowRealMs and NMPlaybackRuntimeCommon.getNowRealMs() or 0,
        lastX = source and tonumber(source.x) or nil,
        lastY = source and tonumber(source.y) or nil,
        lastZ = source and tonumber(source.z) or nil,
        alive = true
    }
end

local function pickDualMonitorChannel(active)
    if not active or active.mode ~= "dual" then
        return nil, false
    end
    if active.world and active.world.alive then
        return active.world, true
    end
    if active.personal and active.personal.alive then
        return active.personal, false
    end
    return nil, false
end

local function updateDualCompatFields(active)
    if not active or active.mode ~= "dual" then
        return
    end
    local monitor, world = pickDualMonitorChannel(active)
    if monitor then
        active.emitter = monitor.emitter
        active.soundId = monitor.soundId
        active.sound = monitor.sound
        active.isWorldEmitter = world == true
    else
        active.emitter = nil
        active.soundId = nil
        active.sound = nil
        active.isWorldEmitter = false
    end
end

local function startPlaybackChannel(player, source, useWorldOutput, candidates, channelName, force3D)
    local emitter, isWorldEmitter = getPlaybackEmitter(player, source, useWorldOutput)
    if not emitter then
        return nil, "emitter_missing"
    end
    local soundId, selectedSound = startSoundFromCandidates(emitter, candidates)
    if soundId == nil or tonumber(soundId) == 0 then
        return nil, "sound_start_failed"
    end
    if emitter.set3D then
        local use3D = force3D
        if use3D == nil then
            use3D = isWorldEmitter == true
        end
        emitter:set3D(soundId, use3D == true)
    end
    if runtimeDiag and runtimeDiag.countEvent then
        runtimeDiag.countEvent(NMPlaybackRuntime, "emitter_starts", 1)
    end
    return {
        emitter = emitter,
        soundId = soundId,
        sound = selectedSound,
        isWorldEmitter = isWorldEmitter == true,
        _sound3D = force3D == nil and isWorldEmitter == true or force3D == true,
        channelName = channelName,
        alive = true
    }, nil
end

local function setChannelVolume(channel, value)
    if channel and channel.alive and channel.emitter and channel.soundId and channel.emitter.setVolume then
        channel.emitter:setVolume(channel.soundId, value)
    end
end

local function dist3d(ax, ay, az, bx, by, bz)
    local dx = (tonumber(ax) or 0) - (tonumber(bx) or 0)
    local dy = (tonumber(ay) or 0) - (tonumber(by) or 0)
    local dz = (tonumber(az) or 0) - (tonumber(bz) or 0)
    return math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
end

local function logChannelPosUpdate(channel, oldX, oldY, oldZ, newX, newY, newZ)
    if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled then
        local traceEnabled = NMCore.isSubsystemDebugEnabled("vehicle_trace")
        local emitterDebugEnabled = NMCore.isSubsystemDebugEnabled("emitter")
        if not (traceEnabled or emitterDebugEnabled) then
            return
        end
        local dist = dist3d(newX, newY, newZ, oldX or newX, oldY or newY, oldZ or newZ)
        local nowMs = NMPlaybackRuntimeCommon.getNowRealMs and NMPlaybackRuntimeCommon.getNowRealMs() or 0
        local lastMs = tonumber(channel._lastPosLogMs) or 0
        local shouldTrace = traceEnabled and (dist >= 1.0 or (nowMs - lastMs) >= 60000)
        local shouldLogEmitter = emitterDebugEnabled and (dist >= 6.0 or (nowMs - lastMs) >= 60000)
        if shouldTrace or shouldLogEmitter then
            channel._lastPosLogMs = nowMs
            NMCore.logChannel(
                shouldTrace and "vehicle_trace" or "emitter",
                "emitter_pos_update",
                string.format(
                    "channel=%s old=%.2f,%.2f,%.2f new=%.2f,%.2f,%.2f dist=%.2f",
                    tostring(channel.channelName or "single"),
                    tonumber(oldX) or tonumber(newX) or 0,
                    tonumber(oldY) or tonumber(newY) or 0,
                    tonumber(oldZ) or tonumber(newZ) or 0,
                    tonumber(newX) or 0,
                    tonumber(newY) or 0,
                    tonumber(newZ) or 0,
                    dist
                )
            )
        end
    end
end

local function applyChannelPos(channel, x, y, z)
    if channel and channel.alive and channel.emitter and channel.emitter.setPos and x and y and z then
        local oldX = tonumber(channel.lastX)
        local oldY = tonumber(channel.lastY)
        local oldZ = tonumber(channel.lastZ)
        channel.emitter:setPos(x, y, z)
        local newX = tonumber(x)
        local newY = tonumber(y)
        local newZ = tonumber(z)
        channel.lastX = newX
        channel.lastY = newY
        channel.lastZ = newZ
        logChannelPosUpdate(channel, oldX, oldY, oldZ, newX, newY, newZ)
    end
end

local function clearChannelSmoothing(channel)
    if not channel then
        return
    end
    channel._smoothTargetX = nil
    channel._smoothTargetY = nil
    channel._smoothTargetZ = nil
    channel._smoothStartX = nil
    channel._smoothStartY = nil
    channel._smoothStartZ = nil
    channel._smoothStartMs = nil
    channel._smoothSourceMode = nil
end

local function setChannelPos(channel, source, smoothAttached)
    if not (channel and channel.alive and channel.emitter and channel.emitter.setPos and source and source.x and source.y and source.z) then
        return
    end

    local targetX = tonumber(source.x)
    local targetY = tonumber(source.y)
    local targetZ = tonumber(source.z)
    if not (targetX and targetY and targetZ) then
        return
    end

    if smoothAttached ~= true then
        clearChannelSmoothing(channel)
        applyChannelPos(channel, targetX, targetY, targetZ)
        return
    end

    local nowMs = NMPlaybackRuntimeCommon.getNowRealMs and NMPlaybackRuntimeCommon.getNowRealMs() or 0
    local mode = tostring(source.sourceMode or source.context or "attached")
    local modeChanged = tostring(channel._smoothSourceMode or "") ~= mode
    local targetChanged = targetX ~= tonumber(channel._smoothTargetX)
        or targetY ~= tonumber(channel._smoothTargetY)
        or targetZ ~= tonumber(channel._smoothTargetZ)

    if modeChanged or targetChanged then
        local currentX = tonumber(channel.lastX)
        local currentY = tonumber(channel.lastY)
        local currentZ = tonumber(channel.lastZ)
        if not (currentX and currentY and currentZ)
            or modeChanged
            or dist3d(currentX, currentY, currentZ, targetX, targetY, targetZ) >= ATTACHED_WORLD_SNAP_DIST then
            clearChannelSmoothing(channel)
            channel._smoothSourceMode = mode
            applyChannelPos(channel, targetX, targetY, targetZ)
            return
        end

        channel._smoothSourceMode = mode
        channel._smoothStartX = currentX
        channel._smoothStartY = currentY
        channel._smoothStartZ = currentZ
        channel._smoothTargetX = targetX
        channel._smoothTargetY = targetY
        channel._smoothTargetZ = targetZ
        channel._smoothStartMs = nowMs
    end

    local startX = tonumber(channel._smoothStartX) or tonumber(channel.lastX) or targetX
    local startY = tonumber(channel._smoothStartY) or tonumber(channel.lastY) or targetY
    local startZ = tonumber(channel._smoothStartZ) or tonumber(channel.lastZ) or targetZ
    local startedMs = tonumber(channel._smoothStartMs) or nowMs
    local t = math.min(1.0, math.max(0.0, (nowMs - startedMs) / ATTACHED_WORLD_SMOOTH_MS))
    local nextX = startX + ((targetX - startX) * t)
    local nextY = startY + ((targetY - startY) * t)
    local nextZ = startZ + ((targetZ - startZ) * t)

    applyChannelPos(channel, nextX, nextY, nextZ)
    if t >= 1.0 then
        channel._smoothStartX = targetX
        channel._smoothStartY = targetY
        channel._smoothStartZ = targetZ
        channel._smoothStartMs = nowMs
    end
end

local function logVehicleRebindTrace(tag, uuid, detail)
    if NMCore and NMCore.logVehicleRebindTrace then
        NMCore.logVehicleRebindTrace(tag, uuid, detail)
    end
end

local function isChannelPlaying(channel)
    if not channel or not channel.emitter or not channel.soundId or not channel.emitter.isPlaying then
        return false
    end
    local ok, playing = pcall(function()
        return channel.emitter:isPlaying(channel.soundId)
    end)
    if not ok then
        return false
    end
    return playing ~= false
end

local function getSingleEmitterClass(useWorldOutput, centeredWorldOutput)
    if centeredWorldOutput == true then
        return "world_centered"
    end
    return useWorldOutput == true and "world" or "personal"
end

local function tryRetargetSingleRenderer(active, useWorldOutput, centeredWorldOutput, source, uuid)
    if not (active and active.emitter and active.soundId) then
        return false
    end
    if not active.emitter.set3D then
        return false
    end
    local targetWorld = useWorldOutput == true
    local target3D = targetWorld == true and centeredWorldOutput ~= true
    local ok = pcall(function()
        active.emitter:set3D(active.soundId, target3D == true)
    end)
    if not ok then
        return false
    end
    active.isWorldEmitter = targetWorld
    active._centeredWorldOutput = centeredWorldOutput == true
    active._sound3D = target3D == true
    active._rendererIntent = centeredWorldOutput == true and "world_centered" or (targetWorld == true and "world_3d" or "personal")
    active._lastRenderMode = "single"
    active._lastEmitterClass = getSingleEmitterClass(useWorldOutput, centeredWorldOutput)
    if targetWorld and source and source.x and source.y and source.z and active.emitter.setPos then
        active.emitter:setPos(source.x, source.y, source.z)
    end
    logTransitionProbe(
        "emitter_renderer_retarget_in_place",
        string.format(
            "uuid=%s world=%s centeredWorld=%s target3D=%s class=%s",
            tostring(uuid),
            tostring(targetWorld),
            tostring(centeredWorldOutput == true),
            tostring(target3D == true),
            tostring(active._lastEmitterClass or "")
        )
    )
    return true
end

local function tryRetargetChannel3D(channel, target3D, uuid, tag)
    if not (channel and channel.emitter and channel.soundId and channel.emitter.set3D) then
        return false
    end
    local ok = pcall(function()
        channel.emitter:set3D(channel.soundId, target3D == true)
    end)
    if not ok then
        return false
    end
    channel._sound3D = target3D == true
    logTransitionProbe(
        tostring(tag or "channel_renderer_retarget_in_place"),
        string.format("uuid=%s channel=%s world=%s", tostring(uuid), tostring(channel.channelName or "unknown"), tostring(target3D == true))
    )
    return true
end

local function isLocalPersonalListenerAllowed(player, state, source)
    if not (NMCore and NMCore.isMPClientRuntime and NMCore.isMPClientRuntime()) then
        return true
    end
    if not player then
        return true
    end
    local owner = tostring(
        (source and (source.ownerId or source.ownerOnlineId or source.ownerUsername))
        or (state and state.sourceOwner)
        or ""
    )
    local context = tostring(source and (source.context or source.mode) or "inventory")
    if owner == "" then
        if context ~= "inventory" and context ~= "vehicle" then
            return false
        end
        return true
    end
    local localOnlineId = player.getOnlineID and tostring(player:getOnlineID() or "") or ""
    local localUsername = player.getUsername and tostring(player:getUsername() or "") or ""
    if owner == localOnlineId or owner == localUsername then
        return true
    end
    if localUsername ~= "" and string.lower(owner) == string.lower(localUsername) then
        return true
    end
    return false
end

local function shouldSmoothAttachedWorldEmitter(player, context, state, source)
    if getSourceMode(context, state, source) ~= "attached" then
        return false
    end
    if not (NMCore and NMCore.isMPClientRuntime and NMCore.isMPClientRuntime()) then
        return false
    end
    return isLocalPersonalListenerAllowed(player, state, source) ~= true
end

local routeProbeSigByUuid = routeProbeSigByUuid or {}
local routeProbeMsByUuid = routeProbeMsByUuid or {}
local vehicleRouteShapeSigByUuid = vehicleRouteShapeSigByUuid or {}
local vehicleRouteShapeMsByUuid = vehicleRouteShapeMsByUuid or {}
local vehicleListenerTruthSigByUuid = vehicleListenerTruthSigByUuid or {}

local function getPlayerSeatDescriptor(player)
    if not player then
        return "", "", ""
    end
    local vehicle = player.getVehicle and player:getVehicle() or nil
    if not vehicle then
        return "out", "", ""
    end
    local seat = vehicle.getSeat and tonumber(vehicle:getSeat(player)) or nil
    local runtimeId = NMVehicleHelpers and NMVehicleHelpers.getVehicleIdString and tostring(NMVehicleHelpers.getVehicleIdString(vehicle) or "") or ""
    local sqlId = NMVehicleHelpers and NMVehicleHelpers.getVehicleSqlIdString and tostring(NMVehicleHelpers.getVehicleSqlIdString(vehicle) or "") or ""
    return tostring(seat or "unknown"), runtimeId, sqlId
end

local function isSpatialAudioEnabled()
    if NMRuntimeConfig and NMRuntimeConfig.getSpatialAudioEnabled then
        return NMRuntimeConfig.getSpatialAudioEnabled() ~= false
    end
    return true
end

local function resolveRendererIntent(audibility, routedOutputMode, useWorldOutput, useDualRender)
    local context = tostring(audibility and audibility.context or "")
    local route = tostring(routedOutputMode or audibility and audibility.audibility or "")
    local spatialEnabled = isSpatialAudioEnabled()
    local intent = {
        class = "personal",
        useWorldOutput = useWorldOutput == true,
        useDualRender = useDualRender == true,
        centeredWorldOutput = false,
        vehicleWorldCentered = false,
        worldChannel3D = useWorldOutput == true,
        singleEmitter3D = useWorldOutput == true
    }

    if context == "vehicle" then
        if audibility and audibility.localVehiclePersonalOverride == true then
            intent.class = "personal"
            intent.useWorldOutput = false
            intent.useDualRender = false
            intent.worldChannel3D = true
            intent.singleEmitter3D = false
            return intent
        end
        if useDualRender == true then
            if spatialEnabled then
                intent.class = "vehicle_dual"
                intent.vehicleWorldCentered = false
                intent.worldChannel3D = true
            else
                intent.class = "vehicle_dual_centered_world"
                intent.vehicleWorldCentered = true
                intent.worldChannel3D = false
            end
            intent.useWorldOutput = true
            intent.useDualRender = true
            intent.singleEmitter3D = true
            return intent
        end
    end

    if route == "world"
        and useWorldOutput == true
        and (tonumber(audibility and audibility.routeWorld) or 0) > 0.001 then
        if spatialEnabled then
            intent.class = "world_3d"
            intent.useWorldOutput = true
            intent.singleEmitter3D = true
        else
            intent.class = "world_centered"
            intent.useWorldOutput = true
            intent.centeredWorldOutput = true
            intent.singleEmitter3D = false
        end
        intent.useDualRender = false
        intent.worldChannel3D = intent.singleEmitter3D
        return intent
    end

    intent.class = useWorldOutput == true and "world_3d" or "personal"
    intent.singleEmitter3D = intent.useWorldOutput == true
    intent.worldChannel3D = intent.singleEmitter3D
    return intent
end

local function classifyVehicleListenerMatch(player, source)
    local seat, listenerVehicleId, listenerVehicleSqlId = getPlayerSeatDescriptor(player)
    local sourceVehicleId = tostring(source and (source.vehicleId or source.vehicleIdHint) or "")
    local sourceVehicleSqlId = tostring(source and (source.vehicleSqlId or source.vehicleSqlIdHint) or "")
    local inVehicleSeat = seat ~= "" and seat ~= "out" and seat ~= "unknown"
    local runtimeMatched = listenerVehicleId ~= "" and sourceVehicleId ~= "" and listenerVehicleId == sourceVehicleId
    local sqlMatched = listenerVehicleSqlId ~= "" and sourceVehicleSqlId ~= "" and listenerVehicleSqlId == sourceVehicleSqlId
    local matched = inVehicleSeat and (runtimeMatched or sqlMatched)
    local matchKind = "none"
    if runtimeMatched then
        matchKind = "runtime"
    elseif sqlMatched then
        matchKind = "sql"
    elseif not inVehicleSeat then
        matchKind = "seat_out"
    elseif listenerVehicleId == "" and listenerVehicleSqlId == "" then
        matchKind = "listener_unanchored"
    elseif sourceVehicleId == "" and sourceVehicleSqlId == "" then
        matchKind = "source_unanchored"
    else
        matchKind = "mismatch"
    end
    return {
        seat = seat,
        listenerVehicleId = listenerVehicleId,
        listenerVehicleSqlId = listenerVehicleSqlId,
        sourceVehicleId = sourceVehicleId,
        sourceVehicleSqlId = sourceVehicleSqlId,
        matched = matched == true,
        runtimeMatched = runtimeMatched == true,
        sqlMatched = sqlMatched == true,
        matchKind = matchKind
    }
end

local function resolveVehicleOccupantLocalEligibility(player, profile, source)
    local context = tostring(source and (source.context or source.mode) or "")
    if context ~= "vehicle" then
        return false, "context_not_vehicle", classifyVehicleListenerMatch(player, source)
    end
    if tostring(profile and profile.deviceType or "") ~= "vehicle_radio" then
        return false, "not_vehicle_radio", classifyVehicleListenerMatch(player, source)
    end
    local match = classifyVehicleListenerMatch(player, source)
    if match.matched == true then
        return true, "same_vehicle", match
    end
    if match.matchKind == "seat_out" then
        return false, "seat_out", match
    end
    if match.matchKind == "listener_unanchored" then
        return false, "listener_unanchored", match
    end
    if match.matchKind == "source_unanchored" then
        return false, "source_unanchored", match
    end
    return false, "vehicle_mismatch", match
end

local function noteVehicleListenerTruth(uuid, player, source, localVehiclePersonalOverride, occupantReason, vehicleMatch)
    local key = tostring(uuid or "")
    if key == "" then
        return nil
    end
    local match = vehicleMatch or classifyVehicleListenerMatch(player, source)
    local sig = table.concat({
        tostring(match.seat),
        tostring(match.matchKind),
        tostring(occupantReason or "unknown"),
        tostring(localVehiclePersonalOverride == true),
        tostring(match.runtimeMatched == true and match.listenerVehicleId or ""),
        tostring(match.runtimeMatched == true and match.sourceVehicleId or ""),
        tostring(match.sqlMatched == true and match.listenerVehicleSqlId or ""),
        tostring(match.sqlMatched == true and match.sourceVehicleSqlId or "")
    }, "|")
    local previous = tostring(vehicleListenerTruthSigByUuid[key] or "")
    if previous ~= sig then
        vehicleListenerTruthSigByUuid[key] = sig
        if previous ~= "" and NMClientPlaybackTick and NMClientPlaybackTick.requestFullPass then
            NMClientPlaybackTick.requestFullPass("vehicle_listener_truth_change")
        end
        if previous ~= "" then
            logTransitionProbe(
                "vehicle_listener_path_flip",
                string.format(
                    "uuid=%s seat=%s match=%s occupantLocal=%s occupantReason=%s listenerVehicleId=%s listenerVehicleSqlId=%s sourceVehicleId=%s sourceVehicleSqlId=%s",
                    tostring(key),
                    tostring(match.seat),
                    tostring(match.matchKind),
                    tostring(localVehiclePersonalOverride == true),
                    tostring(occupantReason or "unknown"),
                    tostring(match.listenerVehicleId),
                    tostring(match.listenerVehicleSqlId),
                    tostring(match.sourceVehicleId),
                    tostring(match.sourceVehicleSqlId)
                )
            )
        end
    end
    return match
end

local function shouldUseLocalVehiclePersonalOverride(player, profile, state, source)
    local eligible = resolveVehicleOccupantLocalEligibility(player, profile, source)
    return eligible == true
end

local function copyRouteProbeSource(source)
    if type(source) ~= "table" then
        return nil
    end
    return {
        mode = source.mode,
        context = source.context,
        x = tonumber(source.x),
        y = tonumber(source.y),
        z = tonumber(source.z)
    }
end

local function quantizeVehicleRouteBucket(value)
    local n = tonumber(value) or 0
    return math.floor((n * 4) + 0.5) / 4
end

local function classifyDualAudibleRoute(routeWorld, routePersonal)
    local worldAudible = (tonumber(routeWorld) or 0) > 0.001
    local personalAudible = (tonumber(routePersonal) or 0) > 0.001
    if worldAudible and personalAudible then
        return "dual"
    end
    if personalAudible then
        return "personal"
    end
    if worldAudible then
        return "world"
    end
    return "silent"
end

local function logVehicleRouteProbe(player, state, source, sig, detailBuilder)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("vehicle_route")) then
        return
    end
    local uuid = tostring(state and state.deviceUUID or "")
    if uuid == "" then
        return
    end
    local stableSig = tostring(sig or "")
    local now = NMPlaybackRuntimeCommon and NMPlaybackRuntimeCommon.getNowRealMs and NMPlaybackRuntimeCommon.getNowRealMs() or 0
    local changed = routeProbeSigByUuid[uuid] ~= stableSig
    local lastMs = tonumber(routeProbeMsByUuid[uuid]) or 0
    local heartbeat = (now - lastMs) >= 20000
    if not (changed or heartbeat) then
        return
    end
    routeProbeSigByUuid[uuid] = stableSig
    routeProbeMsByUuid[uuid] = now
    local line = nil
    if type(detailBuilder) == "function" then
        line = tostring(detailBuilder())
    else
        line = tostring(detailBuilder or stableSig)
    end
    NMCore.logChannel("vehicle_route", "vehicle_route_truth", line)
end

local function updateActiveRouteSnapshot(active, state, source, context, playbackMode, resolvedOutput, localVehiclePersonalOverride)
    if type(active) ~= "table" then
        return
    end
    active._routeProbeSnapshot = {
        source = copyRouteProbeSource(source),
        context = tostring(context or source and source.context or source and source.mode or active.context or "nil"),
        mode = tostring(context or source and source.context or source and source.mode or "nil"),
        playbackMode = tostring(playbackMode or "nil"),
        resolvedOutput = tostring(resolvedOutput or "nil"),
        rendererIntent = tostring(active._rendererIntent or ""),
        localVehiclePersonalOverride = localVehiclePersonalOverride == true,
        vehicleRouteDecision = tostring(active._lastVehicleRouteDecision or ""),
        vehicleDualRoutePreserved = active._vehicleDualRoutePreserved == true,
        isOn = state and state.isOn == true or false,
        isPlaying = state and state.isPlaying == true or false,
        media = tostring(state and state.mediaFullType or "nil")
    }
end

local function buildVehicleSourceIdentityKey(source)
    if type(source) ~= "table" then
        return ""
    end
    return table.concat({
        tostring(source.vehicleIdHint or source.vehicleId or ""),
        tostring(source.vehicleSqlIdHint or source.vehicleSqlId or ""),
        tostring(source.partId or "Radio")
    }, "|")
end

local function updateActiveAudibleStateSnapshot(
    active,
    state,
    source,
    context,
    resolvedOutput,
    localVehiclePersonalOverride,
    useDualRender,
    useWorldOutput,
    rendererIntent
)
    if type(active) ~= "table" then
        return
    end
    active._lastResolvedOutputMode = tostring(resolvedOutput or "")
    active._lastStateIsOn = state and state.isOn == true or false
    active._lastStateIsPlaying = state and state.isPlaying == true or false
    active._lastMediaFullType = tostring(state and state.mediaFullType or "")
    active._lastTrackIndex = tonumber(state and state.trackIndex) or tonumber(active.trackIndex) or -1
    active._lastPlaybackEpoch = tonumber(state and state.playbackEpoch) or tonumber(active.epoch) or -1
    active._lastRevision = tonumber(state and state.revision) or tonumber(active._lastRevision) or -1
    active._lastVehicleSourceIdentity = buildVehicleSourceIdentityKey(source)
    active._lastContext = tostring(context or active.context or "")
    active._lastUseDualRender = useDualRender == true
    active._lastUseWorldOutput = useWorldOutput == true
    active._localVehiclePersonalOverride = localVehiclePersonalOverride == true
    active._rendererIntent = tostring(rendererIntent or active._rendererIntent or "")
    active._lastRenderMode = useDualRender == true and "dual" or "single"
    active._lastEmitterClass = useDualRender == true and tostring(rendererIntent or "dual") or getSingleEmitterClass(useWorldOutput, active._centeredWorldOutput == true)
    active._lastOccupantLocalFlag = localVehiclePersonalOverride == true
end

local function hasSameVehicleSourceIdentity(active, source)
    if type(active) ~= "table" then
        return false
    end
    local activeKey = tostring(active._lastVehicleSourceIdentity or "")
    return activeKey ~= "" and activeKey == buildVehicleSourceIdentityKey(source)
end

local function getVehicleRouteTransitionSignature(active)
    if type(active) ~= "table" then
        return ""
    end
    return table.concat({
        tostring(active._lastRenderMode or (active.mode == "dual" and "dual" or "single")),
        tostring(active._lastEmitterClass or ((active.isWorldEmitter == true) and "world" or "personal")),
        tostring(active._lastResolvedOutputMode or ""),
        tostring(active._lastOccupantLocalFlag == true)
    }, "|")
end

local function hasSameVehicleAuthorityTrack(active, state, source)
    if not (active and state) then
        return false
    end
    if tostring(active.context or active._lastContext or "") ~= "vehicle" then
        return false
    end
    if tostring(active.mediaFullType or active._lastMediaFullType or "") ~= tostring(state.mediaFullType or "") then
        return false
    end
    if (tonumber(active.epoch or active._lastPlaybackEpoch) or -1) ~= (tonumber(state.playbackEpoch) or -1) then
        return false
    end
    if (tonumber(active.trackIndex or active._lastTrackIndex) or -1) ~= (tonumber(state.trackIndex) or -1) then
        return false
    end
    if (active._lastStateIsOn == true) ~= (state.isOn == true) then
        return false
    end
    if (active._lastStateIsPlaying == true) ~= (state.isPlaying == true) then
        return false
    end
    if tostring(active._lastVehicleSourceIdentity or "") ~= buildVehicleSourceIdentityKey(source) then
        return false
    end
    return true
end

local function logVehicleRouteTransitionDecision(uuid, state, active, decision, tickCount)
    if not (decision and decision.preserved == true) then
        return
    end
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("playback_transition")) then
        return
    end
    local key = table.concat({
        "transitionProbe.vehicleRoutePreserved",
        tostring(uuid),
        tostring(decision.reason or "unknown"),
        tostring(state and state.playbackEpoch or -1),
        tostring(state and state.trackIndex or -1)
    }, ".")
    if NMCore.shouldLogEvery and not NMCore.shouldLogEvery(key, tonumber(tickCount) or 0, 120) then
        return
    end
    logTransitionProbe(
        "vehicle_route_transition_preserved",
        string.format(
            "uuid=%s reason=%s from=%s toRender=%s toEmitter=%s output=%s occupantLocal=%s",
            tostring(uuid),
            tostring(decision.reason or "unknown"),
            tostring(getVehicleRouteTransitionSignature(active)),
            tostring(decision.targetRenderMode or "unknown"),
            tostring(decision.targetEmitterClass or "unknown"),
            tostring(decision.targetOutputMode or "unknown"),
            tostring(decision.occupantLocal == true)
        )
    )
end

local function resolveVehicleRenderShapeDecision(active, state, source, audibility, useDualRender, useWorldOutput, rendererIntent)
    if not (state and source and audibility) then
        return nil
    end
    if tostring(source.context or source.mode or (active and active.context) or "") ~= "vehicle" then
        return nil
    end
    local decision = {
        occupantLocal = audibility.localVehiclePersonalOverride == true,
        targetOutputMode = tostring(audibility.audibility or audibility.outputMode or "personal"),
        targetRenderMode = useDualRender == true and "dual" or "single",
        targetEmitterClass = useDualRender == true and tostring(rendererIntent or "vehicle_dual") or (useWorldOutput == true and "world" or "personal"),
        applyDualRender = useDualRender == true,
        preserveDualRoute = false
    }

    if not active then
        if audibility.localVehiclePersonalOverride == true and isVehicleDualEmitterEnabled("vehicle") == true then
            decision.reason = "vehicle_dual_bootstrap"
            decision.targetRenderMode = "dual"
            decision.targetEmitterClass = tostring(rendererIntent or "vehicle_dual")
            decision.applyDualRender = true
            decision.preserveDualRoute = true
        end
        return decision
    end

    local sameAuthorityTrack = hasSameVehicleAuthorityTrack(active, state, source) == true
    if sameAuthorityTrack then
        decision.preserved = true
        if audibility.localVehiclePersonalOverride == true and active.mode == "dual" and useDualRender ~= true then
            decision.reason = "same_vehicle_dual_to_personal"
            decision.preserveDualRoute = true
            return decision
        end
        if active._vehicleDualRoutePreserved == true and active.mode == "dual" and useDualRender ~= true then
            decision.reason = "vehicle_dual_route_flip_preserved"
            decision.preserveDualRoute = true
            return decision
        end
        if audibility.localVehiclePersonalOverride == true
            and active.mode ~= "dual"
            and active.isWorldEmitter == true
            and useDualRender ~= true
            and useWorldOutput ~= true then
            decision.reason = "same_vehicle_world_single_to_personal_single"
            return decision
        end
    end

    if hasSameVehicleSourceIdentity(active, source) == true and audibility.localVehiclePersonalOverride == true then
        decision.restartRequired = true
        decision.reason = "vehicle_authoritative_restart_preserve_dual"
        decision.targetRenderMode = "dual"
        decision.targetEmitterClass = tostring(rendererIntent or "vehicle_dual")
        decision.applyDualRender = true
        decision.preserveDualRoute = true
        return decision
    end
    return nil
end

local function logRestartSuppressedSameRoute(uuid, state, context)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("playback_progression")) then
        return
    end
    local nowMs = NMPlaybackRuntimeCommon and NMPlaybackRuntimeCommon.getNowRealMs and NMPlaybackRuntimeCommon.getNowRealMs() or 0
    local suppressKey = table.concat({
        "progressionProbe.restartSuppressedSameRoute",
        tostring(uuid),
        tostring(state and state.playbackEpoch or -1),
        tostring(state and state.trackIndex or -1)
    }, ".")
    if NMCore.shouldLogEvery and not NMCore.shouldLogEvery(suppressKey, nowMs, 10000) then
        return
    end
    NMCore.logChannel(
        "playback_progression",
        "restart_suppressed_same_route",
        string.format(
            "uuid=%s context=%s epoch=%s track=%s media=%s isOn=%s isPlaying=%s",
            tostring(uuid),
            tostring(context),
            tostring(state and state.playbackEpoch or -1),
            tostring(state and state.trackIndex or -1),
            tostring(state and state.mediaFullType or "nil"),
            tostring(state and state.isOn == true),
            tostring(state and state.isPlaying == true)
        )
    )
end

local function logVehicleRouteShapeProbe(uuid, state, active, decision, restart, useDualRender, useWorldOutput, audibility, rendererIntent)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("vehicle_trace")) then
        return
    end
    local key = tostring(uuid or "")
    if key == "" then
        return
    end
    local activeMode = tostring(active and active.mode or "none")
    local activeEmitterClass = "none"
    if active then
        if active.mode == "dual" then
            activeEmitterClass = "dual"
        elseif active.isWorldEmitter == true then
            activeEmitterClass = "world"
        else
            activeEmitterClass = "personal"
        end
    end
    local routeSig = table.concat({
        tostring(NMClientPlaybackTick and NMClientPlaybackTick.getPendingVehicleSeatTransition and (NMClientPlaybackTick.getPendingVehicleSeatTransition() or {}).reason or "none"),
        tostring(state and state.playbackEpoch or -1),
        tostring(state and state.trackIndex or -1),
        activeMode,
        activeEmitterClass,
        tostring(active and active._vehicleDualRoutePreserved == true),
        tostring(active and active._vehicleRestartRenderShape or "none"),
        tostring(rendererIntent and rendererIntent.class or active and active._rendererIntent or "none"),
        tostring(active and active.world and active.world._sound3D == true),
        tostring(useDualRender == true),
        tostring(useWorldOutput == true),
        tostring(audibility and audibility.localVehiclePersonalOverride == true),
        tostring(decision and decision.reason or "none"),
        tostring(restart == true)
    }, "|")
    local nowMs = NMPlaybackRuntimeCommon and NMPlaybackRuntimeCommon.getNowRealMs and NMPlaybackRuntimeCommon.getNowRealMs() or 0
    local changed = tostring(vehicleRouteShapeSigByUuid[key] or "") ~= routeSig
    local restartSignal = restart == true or (decision and decision.restartRequired == true)
    local lastMs = tonumber(vehicleRouteShapeMsByUuid[key]) or 0
    local heartbeat = (nowMs - lastMs) >= 1000
    if not (changed or restartSignal or heartbeat) then
        return
    end
    vehicleRouteShapeSigByUuid[key] = routeSig
    vehicleRouteShapeMsByUuid[key] = nowMs
    local pendingSeat = NMClientPlaybackTick and NMClientPlaybackTick.getPendingVehicleSeatTransition and NMClientPlaybackTick.getPendingVehicleSeatTransition() or nil
    NMCore.logChannel(
        "vehicle_trace",
        "vehicle_route_shape",
        string.format(
            "uuid=%s epoch=%s track=%s intent=%s activeMode=%s activeEmitter=%s useDual=%s useWorld=%s world3D=%s occupantLocal=%s restart=%s decision=%s preserved=%s renderShape=%s pendingSeat=%s pendingEvent=%s pendingElapsedMs=%s",
            tostring(key),
            tostring(state and state.playbackEpoch or -1),
            tostring(state and state.trackIndex or -1),
            tostring(rendererIntent and rendererIntent.class or active and active._rendererIntent or "none"),
            tostring(activeMode),
            tostring(activeEmitterClass),
            tostring(useDualRender == true),
            tostring(useWorldOutput == true),
            tostring(active and active.world and active.world._sound3D == true),
            tostring(audibility and audibility.localVehiclePersonalOverride == true),
            tostring(restart == true),
            tostring(decision and decision.reason or "none"),
            tostring(active and active._vehicleDualRoutePreserved == true),
            tostring(active and active._vehicleRestartRenderShape or "none"),
            tostring(pendingSeat and pendingSeat.reason or "none"),
            tostring(pendingSeat and pendingSeat.event or ""),
            tostring(pendingSeat and pendingSeat.elapsedMs or "nil")
        )
    )
end

function NMPlaybackRuntime.getActiveRouteProbeSnapshot(uuid)
    local key = tostring(uuid or "")
    if key == "" then
        return nil
    end
    local active = NMPlaybackRuntime.Active and NMPlaybackRuntime.Active[key] or nil
    return active and active._routeProbeSnapshot or nil
end

function NMPlaybackRuntime.clearRecoveredPortableRuntime(uuid, reason)
    local key = tostring(uuid or "")
    if key == "" then
        return false
    end

    local changed = false
    if NMPlaybackRuntime.Active[key] ~= nil then
        NMPlaybackRuntime.forceStop(nil, key, tostring(reason or "corpse_recovered_cleanup"))
        changed = true
    end

    if NMPlaybackRuntime.MissingSinceTick[key] ~= nil or NMPlaybackRuntime.MissingSinceMs[key] ~= nil then
        NMPlaybackRuntime.MissingSinceTick[key] = nil
        NMPlaybackRuntime.MissingSinceMs[key] = nil
        changed = true
    end
    if NMPlaybackRuntime.PowerTick[key] ~= nil then
        NMPlaybackRuntime.PowerTick[key] = nil
        changed = true
    end
    if NMPlaybackRuntime.TrackEnded[key] ~= nil
        or NMPlaybackRuntime.TrackEndPending[key] ~= nil
        or NMPlaybackRuntime.TrackEndAwaitingAdvance[key] ~= nil then
        NMPlaybackRuntime.TrackEnded[key] = nil
        NMPlaybackRuntime.TrackEndPending[key] = nil
        NMPlaybackRuntime.TrackEndAwaitingAdvance[key] = nil
        changed = true
    end
    if routeProbeSigByUuid[key] ~= nil
        or routeProbeMsByUuid[key] ~= nil
        or vehicleRouteShapeSigByUuid[key] ~= nil
        or vehicleRouteShapeMsByUuid[key] ~= nil
        or vehicleListenerTruthSigByUuid[key] ~= nil then
        routeProbeSigByUuid[key] = nil
        routeProbeMsByUuid[key] = nil
        vehicleRouteShapeSigByUuid[key] = nil
        vehicleRouteShapeMsByUuid[key] = nil
        vehicleListenerTruthSigByUuid[key] = nil
        changed = true
    end
    return changed
end

function NMPlaybackRuntime.computeLocalListenerAudibility(player, profile, state, source)
    if not (player and profile and state and source) then
        return nil
    end

    local context = (source and source.context) or ((source and source.mode == "world") and "placed" or "inventory")
    local originalOutputMode = NMDeviceProfiles.resolveOutputMode(profile, state, context, false)
    local outputMode = originalOutputMode
    local vehicleOutputCoerced = false
    local localVehiclePersonalOverride, occupantReason, vehicleMatch = resolveVehicleOccupantLocalEligibility(player, profile, source)
    if localVehiclePersonalOverride then
        outputMode = "personal"
        vehicleOutputCoerced = outputMode ~= originalOutputMode
    elseif context == "vehicle" and outputMode ~= "none" then
        outputMode = "world"
        vehicleOutputCoerced = outputMode ~= originalOutputMode
    end

    local configuredVolume = NMCore.clamp(tonumber(state.volume) or 0, 0, 1)
    local effectiveVolume = configuredVolume
    if outputMode == "silent" or state.isMuted == true then
        effectiveVolume = 0
    end

    local personalOwnerAllowed = true
    if outputMode == "personal" then
        if localVehiclePersonalOverride == true then
            personalOwnerAllowed = true
        else
            personalOwnerAllowed = isLocalPersonalListenerAllowed(player, state, source)
        end
        if not personalOwnerAllowed then
            effectiveVolume = 0
        end
    end

    local portablePolicy = NMPlaybackPortableRouting
        and NMPlaybackPortableRouting.resolvePolicy
        and NMPlaybackPortableRouting.resolvePolicy(profile, state, context, outputMode, configuredVolume, effectiveVolume, personalOwnerAllowed)
        or nil
    local routedOutputMode = portablePolicy and portablePolicy.audibility or outputMode
    local shouldPlay = portablePolicy and portablePolicy.shouldPlay
        or (state.isPlaying == true and outputMode ~= "none" and state.mediaFullType ~= nil and personalOwnerAllowed)

    local routedWorld = 0
    local routedPersonal = 0
    if context == "vehicle" and localVehiclePersonalOverride then
        routedWorld = 0
        routedPersonal = effectiveVolume
    elseif portablePolicy then
        routedWorld = portablePolicy.routeWorld
        routedPersonal = portablePolicy.routePersonal
    elseif outputMode == "world" then
        routedWorld = effectiveVolume
        if context == "vehicle" then
            routedPersonal = effectiveVolume
        end
    elseif outputMode == "personal" then
        routedPersonal = effectiveVolume
    end

    local worldVolume = NMPlaybackAudibility.computeChannelVolume(profile, state, player, source, "world", routedWorld)
    local personalVolume = NMPlaybackAudibility.computeChannelVolume(profile, state, player, source, "personal", routedPersonal)
    local shouldSuppressVanillaMusic = shouldPlay == true and ((worldVolume > 0.001) or (personalVolume > 0.001))
    if context == "vehicle" then
        local vehicleMatch = noteVehicleListenerTruth(
            tostring(state and state.deviceUUID or ""),
            player,
            source,
            localVehiclePersonalOverride,
            occupantReason,
            vehicleMatch
        ) or vehicleMatch or classifyVehicleListenerMatch(player, source)
        local owner = tostring(
            (source and (source.ownerId or source.ownerOnlineId or source.ownerUsername))
            or (state and state.sourceOwner)
            or ""
        )
        local routeSig = string.format(
            "uuid=%s seat=%s match=%s occupantLocal=%s occupantReason=%s outputOriginal=%s outputCoerced=%s dual=%s audibility=%s ownerAllowed=%s shouldPlay=%s routeWorld=%.2f routePersonal=%.2f",
            tostring(state and state.deviceUUID or ""),
            tostring(vehicleMatch.seat),
            tostring(vehicleMatch.matchKind),
            tostring(localVehiclePersonalOverride == true),
            tostring(occupantReason or "unknown"),
            tostring(originalOutputMode),
            tostring(outputMode),
            tostring(context == "vehicle" and localVehiclePersonalOverride ~= true and isVehicleDualEmitterEnabled(context) == true),
            tostring(routedOutputMode),
            tostring(personalOwnerAllowed == true),
            tostring(shouldPlay == true),
            quantizeVehicleRouteBucket(routedWorld),
            quantizeVehicleRouteBucket(routedPersonal)
        )
        logVehicleRouteProbe(player, state, source, routeSig, function()
            return string.format(
                "uuid=%s context=%s seat=%s match=%s occupantLocal=%s occupantReason=%s listenerVehicleId=%s listenerVehicleSqlId=%s sourceVehicleId=%s sourceVehicleSqlId=%s owner=%s outputOriginal=%s outputCoerced=%s coerced=%s audibility=%s ownerAllowed=%s shouldPlay=%s routeWorld=%.3f routePersonal=%.3f worldVolume=%.3f personalVolume=%.3f",
                tostring(state and state.deviceUUID or ""),
                tostring(context),
                tostring(vehicleMatch.seat),
                tostring(vehicleMatch.matchKind),
                tostring(localVehiclePersonalOverride == true),
                tostring(occupantReason or "unknown"),
                tostring(vehicleMatch.listenerVehicleId),
                tostring(vehicleMatch.listenerVehicleSqlId),
                tostring(vehicleMatch.sourceVehicleId),
                tostring(vehicleMatch.sourceVehicleSqlId),
                tostring(owner),
                tostring(originalOutputMode),
                tostring(outputMode),
                tostring(vehicleOutputCoerced == true),
                tostring(routedOutputMode),
                tostring(personalOwnerAllowed == true),
                tostring(shouldPlay == true),
                tonumber(routedWorld) or 0,
                tonumber(routedPersonal) or 0,
                tonumber(worldVolume) or 0,
                tonumber(personalVolume) or 0
            )
        end)
    end

    return {
        context = context,
        originalOutputMode = originalOutputMode,
        outputMode = outputMode,
        audibility = routedOutputMode,
        configuredVolume = configuredVolume,
        effectiveVolume = effectiveVolume,
        personalOwnerAllowed = personalOwnerAllowed == true,
        shouldPlay = shouldPlay == true,
        routeWorld = routedWorld,
        routePersonal = routedPersonal,
        worldVolume = worldVolume,
        personalVolume = personalVolume,
        shouldSuppressVanillaMusic = shouldSuppressVanillaMusic,
        vehicleOutputCoerced = vehicleOutputCoerced == true,
        localVehiclePersonalOverride = localVehiclePersonalOverride == true
    }
end

local function shouldSuppressOccupantLocalRestart(active, state, source, audibility, useDualRender, useWorldOutput)
    if not (active and state and audibility) then
        return false
    end
    if audibility.localVehiclePersonalOverride ~= true then
        return false
    end
    if active._localVehiclePersonalOverride ~= true then
        return false
    end
    if active.mode == "dual" or useDualRender == true or useWorldOutput == true or active.isWorldEmitter == true then
        return false
    end
    if tostring(active.context or "") ~= "vehicle" then
        return false
    end
    if tostring(active.mediaFullType or active._lastMediaFullType or "") ~= tostring(state.mediaFullType or "") then
        return false
    end
    if (tonumber(active.trackIndex or active._lastTrackIndex) or -1) ~= (tonumber(state.trackIndex) or -1) then
        return false
    end
    if (active._lastStateIsOn == true) ~= (state.isOn == true) then
        return false
    end
    if (active._lastStateIsPlaying == true) ~= (state.isPlaying == true) then
        return false
    end
    if tostring(active._lastResolvedOutputMode or "") ~= "personal" then
        return false
    end
    if active._lastUseDualRender == true or active._lastUseWorldOutput == true then
        return false
    end
    if tostring(active._lastContext or active.context or "") ~= "vehicle" then
        return false
    end
    if tostring(active._lastVehicleSourceIdentity or "") ~= buildVehicleSourceIdentityKey(source) then
        return false
    end
    return true
end

function NMPlaybackRuntime.syncDevice(player, profile, state, source, tickCount)
    if not profile or not state or not state.deviceUUID then
        return
    end
    local uuid = tostring(state.deviceUUID)
    if NMDeviceState and NMDeviceState.isZombieDormant and NMDeviceState.isZombieDormant(state) then
        stopEntry(uuid, "zombie_dormant")
        return
    end
    if NMAuthorityContract and NMAuthorityContract.canMutateDurableStateAtRuntime and (not NMAuthorityContract.canMutateDurableStateAtRuntime()) then
        if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") and NMCore.shouldLogEvery then
            local skipKey = "runtimeProbe.clientBatterySkip." .. tostring(uuid)
            if NMCore.shouldLogEvery(skipKey, tonumber(tickCount) or 0, 600) then
                NMCore.logChannel(
                    "runtime",
                    "client_battery_drain_skipped_authority",
                    string.format("uuid=%s playbackMode=%s", tostring(uuid), tostring(state.playbackMode or "nil"))
                )
            end
        end
    else
        NMPlaybackRuntimeCommon.applyPowerDrain(NMPlaybackRuntime.PowerTick, profile, state, tickCount)
    end

    local audibility = NMPlaybackRuntime.computeLocalListenerAudibility(player, profile, state, source)
    if not audibility then
        return
    end
    local context = audibility.context
    local originalOutputMode = audibility.originalOutputMode
    local outputMode = audibility.outputMode
    local configuredVolume = audibility.configuredVolume
    local effectiveVolume = audibility.effectiveVolume
    local personalOwnerAllowed = audibility.personalOwnerAllowed == true
    local portablePolicy = NMPlaybackPortableRouting
        and NMPlaybackPortableRouting.resolvePolicy
        and NMPlaybackPortableRouting.resolvePolicy(profile, state, context, outputMode, configuredVolume, effectiveVolume, personalOwnerAllowed)
        or nil
    local routedOutputMode = portablePolicy and portablePolicy.audibility or audibility.audibility or outputMode
    local useWorldOutput = portablePolicy and portablePolicy.singleWorldOutput
        or ((outputMode == "world") or (outputMode == "silent" and context ~= "inventory"))
    local shouldPlay = audibility.shouldPlay == true
    local useDualVehicle = isVehicleDualEmitterEnabled(context) and (audibility.localVehiclePersonalOverride ~= true)
    local requestedDualRender = useDualVehicle or (portablePolicy and portablePolicy.dualRender == true)
    local rendererIntent = resolveRendererIntent(audibility, routedOutputMode, useWorldOutput, requestedDualRender)
    useWorldOutput = rendererIntent.useWorldOutput == true
    local useDualRender = rendererIntent.useDualRender == true
    local useCenteredWorldOutput = rendererIntent.centeredWorldOutput == true
    local vehicleWorldCentered = rendererIntent.vehicleWorldCentered == true
    local vehicleResolved = not (context == "vehicle" and source and source._vehicleResolved == false)

    if NMCore and NMCore.logChannel and NMCore.shouldLogEvery and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
        local routeKey = "runtimeProbe.route." .. uuid
        if NMCore.shouldLogEvery(routeKey, tonumber(tickCount) or 0, 60) then
            NMCore.logChannel(
                "runtime",
                "route",
                string.format(
                    "uuid=%s context=%s output=%s intent=%s worldOut=%s centeredWorld=%s vehicleWorldCentered=%s shouldPlay=%s isOn=%s isPlaying=%s muted=%s volume=%.2f effective=%.2f media=%s",
                    uuid,
                    tostring(context),
                    tostring(routedOutputMode),
                    tostring(rendererIntent.class),
                    tostring(useWorldOutput == true),
                    tostring(useCenteredWorldOutput == true),
                    tostring(vehicleWorldCentered == true),
                    tostring(shouldPlay == true),
                    tostring(state.isOn == true),
                    tostring(state.isPlaying == true),
                    tostring(state.isMuted == true),
                    configuredVolume,
                    effectiveVolume,
                    tostring(state.mediaFullType or "nil")
                )
            )
        end
    end

    if routedOutputMode == "personal" and not personalOwnerAllowed then
        if isCorpseRecoveredState(state) then
            logCorpseAudio(
                uuid,
                "runtime_personal_blocked",
                string.format(
                    "uuid=%s context=%s output=%s owner=%s localOnlineId=%s localUsername=%s",
                    tostring(uuid),
                    tostring(context),
                    tostring(routedOutputMode),
                    tostring((source and (source.ownerId or source.ownerOnlineId or source.ownerUsername)) or (state and state.sourceOwner) or ""),
                    tostring(player and player.getOnlineID and player:getOnlineID() or ""),
                    tostring(player and player.getUsername and player:getUsername() or "")
                )
            )
        end
        if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") and NMCore.shouldLogEvery then
            local key = "runtimeProbe.personal_world_block." .. tostring(uuid)
            if NMCore.shouldLogEvery(key, tonumber(tickCount) or 0, 300) then
                NMCore.logChannel(
                    "runtime",
                    "personal_world_blocked",
                    string.format(
                        "uuid=%s context=%s owner=%s localOnlineId=%s localUsername=%s",
                        tostring(uuid),
                        tostring(context),
                        tostring((source and (source.ownerId or source.ownerOnlineId or source.ownerUsername)) or (state and state.sourceOwner) or ""),
                        tostring(player and player.getOnlineID and player:getOnlineID() or ""),
                        tostring(player and player.getUsername and player:getUsername() or "")
                    )
                )
            end
        end
    end

    local active = NMPlaybackRuntime.Active[uuid]
    local vehicleRenderDecision = resolveVehicleRenderShapeDecision(active, state, source, audibility, useDualRender, useWorldOutput, rendererIntent.class)
    local effectiveUseDualRender = vehicleRenderDecision and vehicleRenderDecision.applyDualRender == true or useDualRender
    if not shouldPlay then
        if isCorpseRecoveredState(state) then
            logCorpseAudio(
                uuid,
                "runtime_route_blocked",
                string.format(
                    "uuid=%s context=%s output=%s routed=%s shouldPlay=%s isOn=%s isPlaying=%s muted=%s media=%s headphones=%s batteryPresent=%s batteryCharge=%.3f",
                    tostring(uuid),
                    tostring(context),
                    tostring(outputMode),
                    tostring(routedOutputMode),
                    tostring(shouldPlay == true),
                    tostring(state and state.isOn == true),
                    tostring(state and state.isPlaying == true),
                    tostring(state and state.isMuted == true),
                    tostring(state and state.mediaFullType or "nil"),
                    tostring(state and state.headphoneItemFullType or "nil"),
                    tostring(state and state.batteryPresent == true),
                    tonumber(state and state.batteryCharge) or 0.0
                )
            )
        end
        if state.isPlaying == true and NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
            NMCore.logChannel(
                "runtime",
                "route_blocked",
                string.format(
                    "uuid=%s context=%s output=%s isMuted=%s media=%s",
                    uuid,
                    tostring(context),
                    tostring(routedOutputMode),
                    tostring(state.isMuted == true),
                    tostring(state.mediaFullType or "nil")
                )
            )
        end
        stopEntry(uuid, "not_playing")
        return
    end

    local mpVehicleAuthority = isMPVehicleContext(context)
    local mpWorldItemAuthority = isMPWorldItemAuthorityContext(context, state)
    local trackEndAwait = NMPlaybackRuntime.TrackEndAwaitingAdvance[uuid]
    if trackEndAwait and mpVehicleAuthority then
        -- Keep await-map opportunistic in MP vehicle mode; client emits deduped hint and server remains authoritative.
        NMPlaybackRuntime.TrackEndAwaitingAdvance[uuid] = nil
    elseif trackEndAwait and mpWorldItemAuthority then
        local awaitingEpoch = tonumber(trackEndAwait.playbackEpoch) or -1
        local awaitingTrack = tonumber(trackEndAwait.trackIndex) or -1
        local stateEpoch = tonumber(state and state.playbackEpoch) or -1
        local stateTrack = tonumber(state and state.trackIndex) or -1
        if awaitingEpoch ~= stateEpoch or awaitingTrack ~= stateTrack then
            NMPlaybackRuntime.TrackEndAwaitingAdvance[uuid] = nil
        else
            if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("playback_progression") and NMCore.shouldLogEvery then
                local holdKey = "progressionProbe.world.await_hold." .. tostring(uuid) .. ":" .. tostring(stateEpoch) .. ":" .. tostring(stateTrack)
                if NMCore.shouldLogEvery(holdKey, tonumber(tickCount) or 0, 240) then
                    NMCore.logChannel(
                        "playback_progression",
                        "progression_world_replay_hold",
                        string.format("uuid=%s epoch=%s track=%s context=%s", tostring(uuid), tostring(stateEpoch), tostring(stateTrack), tostring(context))
                    )
                end
            end
            return
        end
    end

    local stateEpoch = tonumber(state and state.playbackEpoch) or -1
    local activeEpoch = tonumber(active and active.epoch) or -1
    local epochChanged = active ~= nil and activeEpoch ~= stateEpoch
    local restart = not active or epochChanged
    local restartUseDualRender = effectiveUseDualRender
    if epochChanged and shouldSuppressOccupantLocalRestart(active, state, source, audibility, effectiveUseDualRender, useWorldOutput) then
        restart = false
        active.epoch = stateEpoch
        active.sourceGeneration = tonumber(state and state.sourceGeneration) or tonumber(active.sourceGeneration) or 0
        active.trackIndex = tonumber(state and state.trackIndex) or tonumber(active.trackIndex) or 1
        active.mediaFullType = tostring(state and state.mediaFullType or active.mediaFullType or "")
        updateActiveAudibleStateSnapshot(
            active,
            state,
            source,
            context,
            routedOutputMode,
            audibility.localVehiclePersonalOverride == true,
            effectiveUseDualRender,
            useWorldOutput,
            rendererIntent.class
        )
        active._centeredWorldOutput = useCenteredWorldOutput == true
        active._rendererIntent = tostring(rendererIntent.class or "")
        logRestartSuppressedSameRoute(uuid, state, context)
    end
    if active and active.mode == "dual" and (not effectiveUseDualRender)
        and not (
            vehicleRenderDecision
            and (
                vehicleRenderDecision.reason == "same_vehicle_dual_to_personal"
                or vehicleRenderDecision.reason == "vehicle_dual_route_flip_preserved"
            )
        ) then
        restart = true
    end
    if active and active.mode ~= "dual" and restartUseDualRender then
        restart = true
    end
    local classFlipNeeded = false
    if active and active.mode ~= "dual" and (not effectiveUseDualRender) then
        classFlipNeeded = ((active.isWorldEmitter == true) ~= useWorldOutput)
            or ((active._centeredWorldOutput == true) ~= (useCenteredWorldOutput == true))
        if classFlipNeeded then
            if tryRetargetSingleRenderer(active, useWorldOutput, useCenteredWorldOutput, source, uuid) then
                classFlipNeeded = false
                if vehicleRenderDecision and vehicleRenderDecision.reason == "same_vehicle_world_single_to_personal_single" then
                    active._lastVehicleRouteDecision = tostring(vehicleRenderDecision.reason)
                    logVehicleRouteTransitionDecision(uuid, state, active, vehicleRenderDecision, tickCount)
                end
            else
                local reason = (active and active.emitter and active.emitter.set3D) and "retarget_failed" or "set3d_missing"
                logTransitionProbe(
                    "emitter_class_flip_restart",
                    string.format("uuid=%s reason=%s targetWorld=%s target3D=%s", tostring(uuid), tostring(reason), tostring(useWorldOutput == true), tostring(useWorldOutput == true and useCenteredWorldOutput ~= true))
                )
            end
        end
    end
    if classFlipNeeded then
        restart = true
    end
    if active and vehicleRenderDecision and vehicleRenderDecision.preserved == true then
        restart = false
        active._lastVehicleRouteDecision = tostring(vehicleRenderDecision.reason)
        logVehicleRouteTransitionDecision(uuid, state, active, vehicleRenderDecision, tickCount)
    elseif active and (not vehicleRenderDecision or vehicleRenderDecision.reason == nil) then
        active._lastVehicleRouteDecision = nil
    end

    if active and active.mode == "dual" and restart ~= true and tostring(context or "") == "vehicle" then
        active._rendererIntent = tostring(rendererIntent.class or active._rendererIntent or "")
        active._vehicleWorldCentered = vehicleWorldCentered == true
        local targetWorld3D = rendererIntent.worldChannel3D == true
        local currentWorld3D = active.world and active.world._sound3D == true
        if currentWorld3D ~= targetWorld3D then
            if tryRetargetChannel3D(active.world, targetWorld3D, uuid, "vehicle_world_renderer_retarget_in_place") ~= true then
                restart = true
                logTransitionProbe(
                    "vehicle_world_renderer_retarget_restart",
                    string.format("uuid=%s intent=%s targetWorld3D=%s", tostring(uuid), tostring(rendererIntent.class), tostring(targetWorld3D))
                )
                if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("vehicle_trace") then
                    NMCore.logChannel(
                        "vehicle_trace",
                        "vehicle_world_renderer_retarget",
                        string.format("uuid=%s result=restart intent=%s targetWorld3D=%s occupantLocal=%s", tostring(uuid), tostring(rendererIntent.class), tostring(targetWorld3D), tostring(audibility.localVehiclePersonalOverride == true))
                    )
                end
            elseif NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("vehicle_trace") then
                NMCore.logChannel(
                    "vehicle_trace",
                    "vehicle_world_renderer_retarget",
                    string.format("uuid=%s result=in_place intent=%s targetWorld3D=%s occupantLocal=%s", tostring(uuid), tostring(rendererIntent.class), tostring(targetWorld3D), tostring(audibility.localVehiclePersonalOverride == true))
                )
            end
        end
    end

    if active and active.mode == "dual" then
        updateDualCompatFields(active)
    end
    logVehicleRouteShapeProbe(uuid, state, active, vehicleRenderDecision, restart, restartUseDualRender, useWorldOutput, audibility, rendererIntent)

    local trackEndActive = active
    local trackEndMonitorChannel = "single"
    if active and active.mode == "dual" then
        local monitor = nil
        if outputMode == "personal" then
            monitor = active.personal
            trackEndMonitorChannel = "personal"
        else
            monitor = active.world
            trackEndMonitorChannel = "world"
        end
        trackEndActive = monitor and {
            emitter = monitor.emitter,
            soundId = monitor.soundId,
            startedAtMs = tonumber(monitor.startedAtMs) or tonumber(active.startedAtMs) or 0
        } or nil
    end

    if active
        and NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("playback_progression")
        and NMDeviceProfiles and NMDeviceProfiles.isPortableTrackedContext
        and NMDeviceProfiles.isPortableTrackedContext(profile, context) == true
        and NMCore.shouldLogEvery then
        local stateEpoch = tonumber(state and state.playbackEpoch) or -1
        local stateTrack = tonumber(state and state.trackIndex) or -1
        local pending = NMPlaybackRuntime.TrackEndPending[uuid]
        local ended = NMPlaybackRuntime.TrackEnded[uuid]
        local awaiting = NMPlaybackRuntime.TrackEndAwaitingAdvance[uuid]
        local shouldMonitor = pending ~= nil or awaiting ~= nil or ended ~= nil
        local logKey = "progressionProbe.portableMonitor." .. tostring(uuid) .. ":" .. tostring(stateEpoch) .. ":" .. tostring(stateTrack)
        if shouldMonitor and NMCore.shouldLogEvery(logKey, tonumber(tickCount) or 0, 240) then
            logPortableTrackProgression(
                uuid,
                string.format(
                    "stage=monitor context=%s output=%s activeMode=%s monitor=%s shouldPlay=%s pending=%s awaiting=%s ended=%s media=%s",
                    tostring(context),
                    tostring(routedOutputMode),
                    tostring(active and active.mode or "none"),
                    tostring(trackEndMonitorChannel),
                    tostring(shouldPlay == true),
                    tostring(pending ~= nil),
                    tostring(awaiting ~= nil),
                    tostring(ended ~= nil),
                    tostring(state and state.mediaFullType or "nil")
                )
            )
        end
    end

    if active and not restart and trackEndActive then
        if NMPlaybackRuntimeCommon.updateTrackEndState(
            NMPlaybackRuntime.TrackEndPending,
            NMPlaybackRuntime.TrackEnded,
            NMPlaybackRuntime.TrackEndAwaitingAdvance,
            uuid,
            state,
            trackEndActive,
            profile,
            context,
            source) then
            local endedToken = NMPlaybackRuntime.TrackEnded[uuid]
            logPortableTrackProgression(
                uuid,
                string.format(
                    "stage=token_set context=%s output=%s activeMode=%s monitor=%s epoch=%s track=%s",
                    tostring(context),
                    tostring(routedOutputMode),
                    tostring(active and active.mode or "none"),
                    tostring(trackEndMonitorChannel),
                    tostring(state and state.playbackEpoch or -1),
                    tostring(state and state.trackIndex or -1)
                )
            )
            if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("playback_progression") then
                NMCore.logChannel(
                    "playback_progression",
                    "client_track_end_token_set",
                    string.format(
                        "uuid=%s context=%s token=%s:%s setAtMs=%s firstFalseMs=%s pendingElapsedMs=%s falseCount=%s windowMs=%s falseChecks=%s policy=%s observedDurationMs=%s",
                        tostring(uuid),
                        tostring(context),
                        tostring(state and state.playbackEpoch or -1),
                        tostring(state and state.trackIndex or -1),
                        tostring(endedToken and endedToken.confirmedAtMs or "nil"),
                        tostring(endedToken and endedToken.firstFalseMs or "nil"),
                        tostring(endedToken and endedToken.pendingElapsedMs or "nil"),
                        tostring(endedToken and endedToken.falseCount or "nil"),
                        tostring(endedToken and endedToken.windowMs or "nil"),
                        tostring(endedToken and endedToken.falseChecks or "nil"),
                        tostring(endedToken and endedToken.policy or "default"),
                        tostring(endedToken and endedToken.observedDurationMs or "nil")
                    )
                )
            end
            stopEntry(uuid, "track_end")
            return
        elseif NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("playback_progression")
            and NMDeviceProfiles and NMDeviceProfiles.isPortableTrackedContext
            and NMDeviceProfiles.isPortableTrackedContext(profile, context) == true
            and NMCore.shouldLogEvery then
            local pending = NMPlaybackRuntime.TrackEndPending[uuid]
            local awaiting = NMPlaybackRuntime.TrackEndAwaitingAdvance[uuid]
            local stateEpoch = tonumber(state and state.playbackEpoch) or -1
            local stateTrack = tonumber(state and state.trackIndex) or -1
            local logKey = "progressionProbe.portableMonitorProgress." .. tostring(uuid) .. ":" .. tostring(stateEpoch) .. ":" .. tostring(stateTrack)
            if (pending ~= nil or awaiting ~= nil) and NMCore.shouldLogEvery(logKey, tonumber(tickCount) or 0, 300) then
                logPortableTrackProgression(
                    uuid,
                    string.format(
                        "stage=monitor_wait context=%s output=%s activeMode=%s monitor=%s pending=%s falseCount=%s awaiting=%s",
                        tostring(context),
                        tostring(routedOutputMode),
                        tostring(active and active.mode or "none"),
                        tostring(trackEndMonitorChannel),
                        tostring(pending ~= nil),
                        tostring(pending and pending.falseCount or 0),
                        tostring(awaiting ~= nil)
                    )
                )
            end
        end
    end

    if restart then
        if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("playback_progression") then
            local awaiting = NMPlaybackRuntime.TrackEndAwaitingAdvance[uuid]
            local nowMs = NMPlaybackRuntimeCommon and NMPlaybackRuntimeCommon.getNowRealMs and NMPlaybackRuntimeCommon.getNowRealMs() or 0
            local restartDelayMs = awaiting and awaiting.setAtMs and math.max(0, nowMs - tonumber(awaiting.setAtMs)) or nil
            NMCore.logChannel(
                "playback_progression",
                "client_track_restart",
                string.format(
                    "uuid=%s context=%s epoch=%s track=%s restartAtMs=%s delayFromTokenMs=%s awaiting=%s policy=%s",
                    tostring(uuid),
                    tostring(context),
                    tostring(state and state.playbackEpoch or -1),
                    tostring(state and state.trackIndex or -1),
                    tostring(nowMs),
                    tostring(restartDelayMs or "nil"),
                    tostring(awaiting ~= nil),
                    tostring(awaiting and awaiting.policy or "none")
                )
            )
        end
        stopEntry(uuid, "restart")

        local track, resolved = getCurrentTrack(state)
        if not track then
            state.isPlaying = false
            state.desiredIsPlaying = false
            state.lastStopReason = "no_track"
            if isCorpseRecoveredState(state) then
                logCorpseAudio(
                    uuid,
                    "runtime_no_track",
                    string.format(
                        "uuid=%s media=%s trackIndex=%d",
                        tostring(uuid),
                        tostring(state.mediaFullType or "nil"),
                        tonumber(state.trackIndex) or 1
                    )
                )
            end
            if NMCore and NMCore.logChannel then
                NMCore.logChannel(
                    "emitter",
                    "start_rejected",
                    string.format(
                        "uuid=%s reason=no_track media=%s trackIndex=%d",
                        uuid,
                        tostring(state.mediaFullType or "nil"),
                        tonumber(state.trackIndex) or 1
                    )
                )
            end
            return
        end

        local candidates = buildSoundCandidates(track, state)
        local heldFailure = getSoundStartFailureHold(uuid, state, candidates)
        if heldFailure then
            state.isPlaying = false
            state.desiredIsPlaying = false
            state.lastStopReason = tostring(heldFailure.reason or "sound_start_quarantined")
            if NMCore and NMCore.logChannel then
                local detail = string.format(
                    "uuid=%s reason=sound_start_quarantined media=%s track=%s epoch=%s candidates=%s",
                    tostring(uuid),
                    tostring(state.mediaFullType or "nil"),
                    tostring(track and track.sound or "nil"),
                    tostring(state.playbackEpoch or 0),
                    tostring(heldFailure.candidates or joinCandidates(candidates, 8))
                )
                if shouldLogLifecycleProbe("sound_start_quarantined", uuid, detail, 30000) then
                    NMCore.logChannel("emitter", "start_rejected", detail)
                end
            end
            return
        end
        if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("emitter") then
            NMCore.logChannel(
                "emitter",
                "start_attempt",
                string.format(
                    "uuid=%s media=%s track=%s candidates=%s context=%s output=%s dual=%s",
                    tostring(uuid),
                    tostring(state.mediaFullType or "nil"),
                    tostring(track and track.sound or "nil"),
                    joinCandidates(candidates, 8),
                    tostring(context),
                    tostring(routedOutputMode),
                    tostring(restartUseDualRender == true)
                )
            )
        end

        if restartUseDualRender then
            local worldChan, worldErr = startPlaybackChannel(player, source, true, candidates, "world", rendererIntent.worldChannel3D == true)
            local personalChan, personalErr = startPlaybackChannel(player, source, false, candidates, "personal")
            local worldAlive = worldChan ~= nil
            local personalAlive = personalChan ~= nil

            if not worldAlive and not personalAlive then
                state.isPlaying = false
                state.desiredIsPlaying = false
                state.lastStopReason = "sound_start_failed"
                noteSoundStartFailure(uuid, state, candidates, "dual_start_failed")
                if isCorpseRecoveredState(state) then
                    logCorpseAudio(
                        uuid,
                        "runtime_dual_start_failed",
                        string.format(
                            "uuid=%s media=%s worldErr=%s personalErr=%s",
                            tostring(uuid),
                            tostring(state.mediaFullType or "nil"),
                            tostring(worldErr or "nil"),
                            tostring(personalErr or "nil")
                        )
                    )
                end
                if NMCore and NMCore.logChannel then
                    NMCore.logChannel(
                        "emitter",
                        "start_rejected",
                        string.format(
                            "uuid=%s reason=dual_start_failed media=%s worldErr=%s personalErr=%s",
                            uuid,
                            tostring(state.mediaFullType or "nil"),
                            tostring(worldErr or "nil"),
                            tostring(personalErr or "nil")
                        )
                    )
                end
                return
            end
            clearSoundStartFailure(uuid, state, candidates)

            active = {
                mode = "dual",
                world = worldChan or { alive = false },
                personal = personalChan or { alive = false },
                epoch = tonumber(state.playbackEpoch) or 0,
                context = context,
                sourceGeneration = tonumber(state.sourceGeneration) or 0,
                trackIndex = tonumber(state.trackIndex) or 1,
                trackCount = (resolved and resolved.tracks and #resolved.tracks) or 1,
                startedAtMs = NMPlaybackRuntimeCommon.getNowRealMs and NMPlaybackRuntimeCommon.getNowRealMs() or 0,
                lastX = source and tonumber(source.x) or nil,
                lastY = source and tonumber(source.y) or nil,
                lastZ = source and tonumber(source.z) or nil,
                lastGainRoute = nil,
                _rendererIntent = tostring(rendererIntent.class or "vehicle_dual"),
                _vehicleWorldCentered = vehicleWorldCentered == true,
                _vehicleDualRoutePreserved = vehicleRenderDecision and vehicleRenderDecision.preserveDualRoute == true or false
            }
            if active.world then
                active.world.startedAtMs = active.startedAtMs
            end
            if active.personal then
                active.personal.startedAtMs = active.startedAtMs
            end
            active._vehicleRestartRenderShape = active._vehicleDualRoutePreserved == true and "dual_muted_world_personal" or nil
            updateDualCompatFields(active)
            NMPlaybackRuntime.Active[uuid] = active
            if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
                local listenerSeat, listenerVehicleId, listenerVehicleSqlId = getPlayerSeatDescriptor(player)
                local detail = string.format(
                    "uuid=%s mode=dual context=%s originalOutput=%s output=%s token=%s:%s sourceGen=%s dualReason=%s listenerSeat=%s listenerVehicleId=%s listenerVehicleSqlId=%s sourceVehicleId=%s sourceVehicleSqlId=%s worldAlive=%s personalAlive=%s worldIsWorld=%s personalIsWorld=%s worldSound=%s personalSound=%s",
                    tostring(uuid),
                    tostring(context),
                    tostring(originalOutputMode),
                    tostring(routedOutputMode),
                    tostring(active.epoch or 0),
                    tostring(active.trackIndex or 0),
                    tostring(active.sourceGeneration or 0),
                    tostring(
                        active._vehicleDualRoutePreserved == true
                            and (
                                vehicleRenderDecision and vehicleRenderDecision.reason or "vehicle_preserved_dual"
                            )
                            or (useDualVehicle == true and "vehicle" or (portablePolicy and portablePolicy.dualRender == true and "portable" or "unknown"))
                    ),
                    tostring(listenerSeat),
                    tostring(listenerVehicleId),
                    tostring(listenerVehicleSqlId),
                    tostring(source and (source.vehicleId or source.vehicleIdHint) or ""),
                    tostring(source and (source.vehicleSqlId or source.vehicleSqlIdHint) or ""),
                    tostring(worldAlive),
                    tostring(personalAlive),
                    tostring(worldChan and worldChan.isWorldEmitter == true),
                    tostring(personalChan and personalChan.isWorldEmitter == true),
                    tostring(worldChan and worldChan.sound or "nil"),
                    tostring(personalChan and personalChan.sound or "nil")
                )
                if shouldLogLifecycleProbe("emitter_create", uuid, detail, 3000) then
                    NMCore.logChannel("runtime", "emitter_create", detail)
                end
            end

            if NMCore and NMCore.logChannel then
                NMCore.logChannel(
                    "emitter",
                    "dual_start_result",
                    string.format(
                        "uuid=%s world=%s personal=%s worldSound=%s personalSound=%s trackIndex=%d trackCount=%d",
                        tostring(uuid),
                        tostring(worldAlive),
                        tostring(personalAlive),
                        tostring(worldChan and worldChan.sound or "nil"),
                        tostring(personalChan and personalChan.sound or "nil"),
                        tonumber(state.trackIndex) or 1,
                        (resolved and resolved.tracks and #resolved.tracks) or 1
                    )
                )
            end
            if (not worldAlive) or (not personalAlive) then
                logTransitionProbe(
                    "dual_failover",
                    string.format(
                        "uuid=%s worldAlive=%s personalAlive=%s worldErr=%s personalErr=%s",
                        tostring(uuid),
                        tostring(worldAlive),
                        tostring(personalAlive),
                        tostring(worldErr or "nil"),
                        tostring(personalErr or "nil")
                    )
                )
            end
        else
            local emitter, isWorldEmitter = getPlaybackEmitter(player, source, useWorldOutput)
            if not emitter then
                state.isPlaying = false
                state.desiredIsPlaying = false
                state.lastStopReason = "emitter_missing"
                if isCorpseRecoveredState(state) then
                    logCorpseAudio(
                        uuid,
                        "runtime_emitter_missing",
                        string.format(
                            "uuid=%s context=%s output=%s world=%s",
                            tostring(uuid),
                            tostring(context),
                            tostring(routedOutputMode),
                            tostring(useWorldOutput == true)
                        )
                    )
                end
                if NMCore and NMCore.logChannel then
                    NMCore.logChannel("emitter", "start_rejected", "uuid=" .. uuid .. " reason=emitter_missing")
                end
                return
            end

            local soundId, selectedSound = startSoundFromCandidates(emitter, candidates)
            if soundId == nil or tonumber(soundId) == 0 then
                state.isPlaying = false
                state.desiredIsPlaying = false
                state.lastStopReason = "sound_start_failed"
                noteSoundStartFailure(uuid, state, candidates, "sound_start_failed")
                if isCorpseRecoveredState(state) then
                    logCorpseAudio(
                        uuid,
                        "runtime_sound_start_failed",
                        string.format(
                            "uuid=%s media=%s track=%s candidates=%s context=%s output=%s",
                            tostring(uuid),
                            tostring(state.mediaFullType or "nil"),
                            tostring(track and track.sound or "nil"),
                            joinCandidates(candidates, 8),
                            tostring(context),
                            tostring(routedOutputMode)
                        )
                    )
                end
                if NMCore and NMCore.logChannel then
                    NMCore.logChannel(
                        "emitter",
                        "start_rejected",
                        string.format(
                            "uuid=%s reason=sound_start_failed media=%s track=%s candidates=%s",
                            uuid,
                            tostring(state.mediaFullType or "nil"),
                            tostring(track and track.sound or "nil"),
                            joinCandidates(candidates, 8)
                        )
                    )
                end
                return
            end
            clearSoundStartFailure(uuid, state, candidates)
            if NMCore and NMCore.logChannel then
                NMCore.logChannel(
                    "emitter",
                    "start_ok",
                    string.format(
                        "uuid=%s media=%s selected=%s soundId=%s trackIndex=%d trackCount=%d world=%s context=%s output=%s",
                        uuid,
                        tostring(state.mediaFullType or "nil"),
                        tostring(selectedSound or "nil"),
                        tostring(soundId),
                        tonumber(state.trackIndex) or 1,
                        (resolved and resolved.tracks and #resolved.tracks) or 1,
                        tostring(isWorldEmitter == true),
                        tostring(context),
                        tostring(routedOutputMode)
                    )
                )
            end
            if isCorpseRecoveredState(state) then
                logCorpseAudio(
                    uuid,
                    "runtime_start_ok",
                    string.format(
                        "uuid=%s media=%s selected=%s soundId=%s context=%s output=%s world=%s",
                        tostring(uuid),
                        tostring(state.mediaFullType or "nil"),
                        tostring(selectedSound or "nil"),
                        tostring(soundId),
                        tostring(context),
                        tostring(routedOutputMode),
                        tostring(isWorldEmitter == true)
                    )
                )
            end
            if emitter.set3D then
                emitter:set3D(soundId, rendererIntent.singleEmitter3D == true)
            end
            active = makeSingleActive(
                emitter,
                soundId,
                selectedSound,
                state,
                source,
                context,
                (resolved and resolved.tracks and #resolved.tracks) or 1,
                isWorldEmitter == true,
                useCenteredWorldOutput == true,
                rendererIntent.class,
                rendererIntent.singleEmitter3D == true
            )
            active._vehicleDualRoutePreserved = false
            active._vehicleRestartRenderShape = nil
            NMPlaybackRuntime.Active[uuid] = active
            if runtimeDiag and runtimeDiag.countEvent then
                runtimeDiag.countEvent(NMPlaybackRuntime, "emitter_starts", 1)
            end
            if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
                local detail = string.format(
                    "uuid=%s mode=single context=%s output=%s token=%s:%s sourceGen=%s world=%s sound=%s",
                    tostring(uuid),
                    tostring(context),
                    tostring(outputMode),
                    tostring(active.epoch or 0),
                    tostring(active.trackIndex or 0),
                    tostring(active.sourceGeneration or 0),
                    tostring(active.isWorldEmitter == true),
                    tostring(active.sound or "nil")
                )
                if shouldLogLifecycleProbe("emitter_create", uuid, detail, 3000) then
                    NMCore.logChannel("runtime", "emitter_create", detail)
                end
            end
        end
    end

    if not active then
        return
    end
    active.context = context
    active.mediaFullType = tostring(state and state.mediaFullType or active.mediaFullType or "")
    updateActiveRouteSnapshot(
        active,
        state,
        source,
        context,
        audibility.localVehiclePersonalOverride == true and "personal" or tostring(state and state.playbackMode or routedOutputMode),
        routedOutputMode,
        audibility.localVehiclePersonalOverride == true
    )
    updateActiveAudibleStateSnapshot(
        active,
        state,
        source,
        context,
        routedOutputMode,
        audibility.localVehiclePersonalOverride == true,
        useDualRender,
        useWorldOutput,
        rendererIntent.class
    )

    local smoothAttachedWorld = shouldSmoothAttachedWorldEmitter(player, context, state, source)

    if active.mode == "dual" then
        setChannelPos(active.world, source, smoothAttachedWorld)
        local routedWorld = tonumber(audibility.routeWorld) or 0
        local routedPersonal = tonumber(audibility.routePersonal) or 0
        local routeWorld = NMPlaybackAudibility.computeChannelVolume(profile, state, player, source, "world", routedWorld)
        local routePersonal = NMPlaybackAudibility.computeChannelVolume(profile, state, player, source, "personal", routedPersonal)
        setChannelVolume(active.world, routeWorld)
        setChannelVolume(active.personal, routePersonal)
        local nowMs = NMPlaybackRuntimeCommon.getNowRealMs and NMPlaybackRuntimeCommon.getNowRealMs() or 0
        local worldPlaying = isChannelPlaying(active.world)
        local personalPlaying = isChannelPlaying(active.personal)
        active.worldPlaying = worldPlaying
        active.personalPlaying = personalPlaying
        if worldPlaying then
            active.lastHealthyWorldMs = nowMs
        end
        updateDualCompatFields(active)

        local routeSig = string.format(
            "%s|audible=%s|w=%.2f|p=%.2f",
            tostring(routedOutputMode),
            tostring(classifyDualAudibleRoute(routeWorld, routePersonal)),
            quantizeVehicleRouteBucket(routeWorld),
            quantizeVehicleRouteBucket(routePersonal)
        )
        local routeChanged = tostring(active.lastGainRoute or "") ~= routeSig
        local nowMsForDualGain = NMPlaybackRuntimeCommon.getNowRealMs and NMPlaybackRuntimeCommon.getNowRealMs() or 0
        local lastDualGainLogMs = tonumber(active.lastDualGainLogMs) or 0
        local dualGainMinLogMs = math.max(1000, tonumber(NMRuntimeConfig.get("dualGainMinLogMs", 250)) or 250)
        local canLogDualGainNow = (nowMsForDualGain - lastDualGainLogMs) >= dualGainMinLogMs
        if (routeChanged and canLogDualGainNow)
            or (NMCore and NMCore.shouldLogEvery and NMCore.shouldLogEvery("transitionProbe.dualGain." .. uuid, tonumber(tickCount) or 0, 600)) then
            logTransitionProbe(
                "dual_gain_route",
                string.format(
                    "uuid=%s output=%s world=%.3f personal=%.3f worldAlive=%s personalAlive=%s",
                    tostring(uuid),
                    tostring(routedOutputMode),
                    routeWorld,
                    routePersonal,
                    tostring(active.world and active.world.alive == true),
                    tostring(active.personal and active.personal.alive == true)
                )
            )
            active.lastDualGainLogMs = nowMsForDualGain
        end
        active.lastGainRoute = routeSig
        if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("vehicle_trace")
            and NMCore.shouldLogEvery and NMCore.shouldLogEvery("runtimeProbe.vehicleChannelHealth." .. uuid, tonumber(tickCount) or 0, 300) then
            NMCore.logChannel(
                "vehicle_trace",
                "dual_channel_health",
                string.format(
                    "uuid=%s output=%s resolved=%s worldPlaying=%s personalPlaying=%s routeWorld=%.3f routePersonal=%.3f",
                    tostring(uuid),
                    tostring(routedOutputMode),
                    tostring(vehicleResolved),
                    tostring(worldPlaying),
                    tostring(personalPlaying),
                    routeWorld,
                    routePersonal
                )
            )
        end
        if context == "vehicle"
            and routeWorld > 0.001
            and routePersonal > 0.001
            and worldPlaying
            and personalPlaying
            and NMCore and NMCore.logChannel
            and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("playback_transition")
            and NMCore.shouldLogEvery and NMCore.shouldLogEvery("transitionProbe.vehicleBothAudible." .. uuid, tonumber(tickCount) or 0, 120) then
            logTransitionProbe(
                "vehicle_both_channels_audible",
                string.format(
                    "uuid=%s originalOutput=%s output=%s worldPlaying=%s personalPlaying=%s routeWorld=%.3f routePersonal=%.3f sourceVehicleId=%s",
                    tostring(uuid),
                    tostring(originalOutputMode),
                    tostring(routedOutputMode),
                    tostring(worldPlaying),
                    tostring(personalPlaying),
                    routeWorld,
                    routePersonal,
                    tostring(source and (source.vehicleId or source.vehicleIdHint) or "")
                )
            )
        end
        if context == "vehicle" and routedOutputMode == "world" and routeWorld <= 0.001
            and NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled
            and (NMCore.isSubsystemDebugEnabled("vehicle") or NMCore.isSubsystemDebugEnabled("vehicle_trace"))
            and NMCore.shouldLogEvery and NMCore.shouldLogEvery("runtimeProbe.vehicleSilentWorld." .. uuid, tonumber(tickCount) or 0, 60) then
            local px = player and player.getX and tonumber(player:getX()) or 0
            local py = player and player.getY and tonumber(player:getY()) or 0
            local sx = source and tonumber(source.x) or 0
            local sy = source and tonumber(source.y) or 0
            local dx = px - sx
            local dy = py - sy
            local dist = math.sqrt((dx * dx) + (dy * dy))
            NMCore.logChannel(
                NMCore.isSubsystemDebugEnabled("vehicle") and "vehicle" or "vehicle_trace",
                "vehicle_world_silent",
                string.format(
                    "uuid=%s output=%s dist=%.2f px=%.2f py=%.2f sx=%.2f sy=%.2f sourceVehicleId=%s",
                    tostring(uuid),
                    tostring(routedOutputMode),
                    dist,
                    px, py, sx, sy,
                    tostring(source and source.vehicleId or "nil")
                )
            )
        end
        local expectsWorldAudible = routedOutputMode == "world" and routeWorld > 0.001
        if context == "vehicle" and state.isPlaying == true and expectsWorldAudible and vehicleResolved then
            local lastHealthy = tonumber(active.lastHealthyWorldMs) or nowMs
            local graceMs = math.max(250, tonumber(NMRuntimeConfig.get("vehicleGhostWorldChannelGraceMs", 1500)) or 1500)
            local staleMs = math.floor(nowMs - lastHealthy)
            local currentAssertState = worldPlaying and "healthy" or ((nowMs - lastHealthy) < graceMs and "stale_pre_grace" or "stale_post_grace")
            local previousAssertState = tostring(active._vehicleChannelAssertState or "")
            if previousAssertState ~= currentAssertState then
                local emittedState = currentAssertState
                if currentAssertState == "healthy"
                    and (previousAssertState == "stale_pre_grace" or previousAssertState == "stale_post_grace") then
                    emittedState = "recovered"
                end
                active._vehicleChannelAssertState = currentAssertState
                logVehicleRebindTrace(
                    "runtime_channel_assert",
                    uuid,
                    string.format(
                        "state=%s expectWorld=%s worldPlaying=%s personalPlaying=%s routeWorld=%.3f staleMs=%d",
                        tostring(emittedState),
                        tostring(expectsWorldAudible),
                        tostring(worldPlaying),
                        tostring(personalPlaying),
                        routeWorld,
                        staleMs
                    )
                )
            end
        else
            active._vehicleChannelAssertState = nil
        end
        if (not (active.world and active.world.alive)) or (not (active.personal and active.personal.alive)) then
            local shouldLogMissing = true
            if NMCore and NMCore.shouldLogEvery then
                shouldLogMissing = NMCore.shouldLogEvery("transitionProbe.dualMissing." .. uuid, tonumber(tickCount) or 0, 120)
            end
            if shouldLogMissing then
                logTransitionProbe(
                    "dual_channel_missing",
                    string.format(
                        "uuid=%s worldAlive=%s personalAlive=%s",
                        tostring(uuid),
                        tostring(active.world and active.world.alive == true),
                        tostring(active.personal and active.personal.alive == true)
                    )
                )
            end
        end
        runtimeDiag.updateVehicleEmitter(NMPlaybackRuntime, uuid, active, source, context)
    elseif active.emitter and active.soundId then
        if active.isWorldEmitter and source and source.x and source.y and source.z and active.emitter.setPos then
            setChannelPos(active, source, smoothAttachedWorld)
            runtimeDiag.updateVehicleEmitter(NMPlaybackRuntime, uuid, active, source, context)
        end
        if active.emitter.setVolume then
            local centeredWorld = active._centeredWorldOutput == true
            local routed = (active.isWorldEmitter or centeredWorld) and (tonumber(audibility.routeWorld) or 0) or (tonumber(audibility.routePersonal) or 0)
            local channelKind = (active.isWorldEmitter or centeredWorld) and "world" or "personal"
            local resolvedVolume = NMPlaybackAudibility.computeChannelVolume(profile, state, player, source, channelKind, routed)
            active.emitter:setVolume(active.soundId, resolvedVolume)
        end
    end

end

function NMPlaybackRuntime.updateActiveEmitterPositionOnly(player, uuid, state, source)
    local key = tostring(uuid or state and state.deviceUUID or "")
    if key == "" then
        return false
    end
    local active = NMPlaybackRuntime.Active and NMPlaybackRuntime.Active[key] or nil
    if not active or not source or not (source.x and source.y and source.z) then
        return false
    end

    local context = source.context or source.mode or active.context
    active.context = context
    local smoothAttachedWorld = shouldSmoothAttachedWorldEmitter(player, context, state, source)

    if active.mode == "dual" then
        if active.world and active.world.alive then
            setChannelPos(active.world, source, smoothAttachedWorld)
            updateDualCompatFields(active)
            if runtimeDiag and runtimeDiag.updateVehicleEmitter then
                runtimeDiag.updateVehicleEmitter(NMPlaybackRuntime, key, active, source, context)
            end
            return true
        end
        return false
    end

    if active._localVehiclePersonalOverride == true then
        return false
    end

    if active.isWorldEmitter and active.emitter and active.soundId and active.emitter.setPos then
        setChannelPos(active, source, smoothAttachedWorld)
        if runtimeDiag and runtimeDiag.updateVehicleEmitter then
            runtimeDiag.updateVehicleEmitter(NMPlaybackRuntime, key, active, source, context)
        end
        return true
    end

    return false
end

function NMPlaybackRuntime.getDiagnosticsSnapshot()
    return runtimeDiag.snapshot(NMPlaybackRuntime)
end

function NMPlaybackRuntime.snapshot()
    return NMPlaybackRuntime.getDiagnosticsSnapshot()
end

function NMPlaybackRuntime.stopMissing(player, validUUIDs, tickNow)
    local now = tonumber(tickNow) or 0
    local nowMs = NMPlaybackRuntimeCommon.getNowRealMs and NMPlaybackRuntimeCommon.getNowRealMs() or 0
    local grace = math.max(1, tonumber(NMRuntimeConfig.get("emitterMissingGraceTicks", 60)) or 60)
    for uuid, _ in pairs(NMPlaybackRuntime.Active) do
        if validUUIDs and validUUIDs[uuid] then
            local since = tonumber(NMPlaybackRuntime.MissingSinceTick[uuid])
            local sinceMs = tonumber(NMPlaybackRuntime.MissingSinceMs[uuid])
            if since ~= nil and NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
                NMCore.logChannel(
                    "runtime",
                    "playback_missing_cleared",
                    string.format(
                        "uuid=%s missingSinceTick=%s missingForTicks=%s missingSinceMs=%s",
                        tostring(uuid),
                        tostring(since),
                        tostring(now - since),
                        tostring(sinceMs ~= nil and sinceMs or "nil")
                    )
                )
            end
            NMPlaybackRuntime.MissingSinceTick[uuid] = nil
            NMPlaybackRuntime.MissingSinceMs[uuid] = nil
        else
            local since = tonumber(NMPlaybackRuntime.MissingSinceTick[uuid])
            local sinceMs = tonumber(NMPlaybackRuntime.MissingSinceMs[uuid])
            if since == nil then
                NMPlaybackRuntime.MissingSinceTick[uuid] = now
                if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
                    NMCore.logChannel(
                        "runtime",
                        "playback_missing_started",
                        string.format("uuid=%s tick=%s grace=%s", tostring(uuid), tostring(now), tostring(grace))
                    )
                end
            end
            if sinceMs == nil then
                NMPlaybackRuntime.MissingSinceMs[uuid] = nowMs
            end
            if since ~= nil and (now - since) >= grace then
                if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
                    NMCore.logChannel(
                        "runtime",
                        "playback_missing_timeout",
                        string.format(
                            "uuid=%s missingSinceTick=%s missingForTicks=%s missingSinceMs=%s grace=%s",
                            tostring(uuid),
                            tostring(since),
                            tostring(now - since),
                            tostring(sinceMs ~= nil and sinceMs or "nil"),
                            tostring(grace)
                        )
                    )
                end
                NMPlaybackRuntime.MissingSinceTick[uuid] = nil
                NMPlaybackRuntime.MissingSinceMs[uuid] = nil
                if runtimeDiag and runtimeDiag.countEvent then
                    runtimeDiag.countEvent(NMPlaybackRuntime, "stop_missing_removals", 1)
                end
                stopEntry(uuid, "missing_timeout")
            end
        end
    end
end

function NMPlaybackRuntime.forceStop(player, uuid, reason)
    if not uuid then return end
    local key = tostring(uuid)
    NMPlaybackRuntime.MissingSinceTick[key] = nil
    NMPlaybackRuntime.MissingSinceMs[key] = nil
    stopEntry(key, tostring(reason or "force_stop"))
end

function NMPlaybackRuntime.resetPowerTick(uuid, reason)
    local key = tostring(uuid or "")
    if key == "" then
        return false
    end
    if NMPlaybackRuntime.PowerTick[key] == nil then
        return false
    end
    NMPlaybackRuntime.PowerTick[key] = nil
    if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
        NMCore.logChannel(
            "runtime",
            "battery_powertick_reset",
            string.format("uuid=%s reason=%s", tostring(key), tostring(reason or "unspecified"))
        )
    end
    return true
end

function NMPlaybackRuntime.invalidateTrackEnded(uuid)
    local key = tostring(uuid or "")
    if key == "" then return end
    NMPlaybackRuntime.TrackEnded[key] = nil
    NMPlaybackRuntime.TrackEndAwaitingAdvance[key] = nil
end

function NMPlaybackRuntime.consumeTrackEndedToken(uuid)
    local key = tostring(uuid or "")
    if key == "" then return nil end
    local payload = NMPlaybackRuntime.TrackEnded[key]
    if payload == nil then return nil end
    NMPlaybackRuntime.TrackEnded[key] = nil
    return payload
end

