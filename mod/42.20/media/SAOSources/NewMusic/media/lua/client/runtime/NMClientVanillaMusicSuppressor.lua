-- Temporarily mutes vanilla background music while New Music is audibly playing for the local client.
NMClientVanillaMusicSuppressor = NMClientVanillaMusicSuppressor or {}
NMClientVanillaMusicSuppressor._tickAudible = false
NMClientVanillaMusicSuppressor._suppressed = NMClientVanillaMusicSuppressor._suppressed or false
NMClientVanillaMusicSuppressor._capturedVolume = NMClientVanillaMusicSuppressor._capturedVolume
NMClientVanillaMusicSuppressor._hasSessionCapture = NMClientVanillaMusicSuppressor._hasSessionCapture == true
NMClientVanillaMusicSuppressor._lastRefreshTick = NMClientVanillaMusicSuppressor._lastRefreshTick or 0

local function logRuntimeProbe(tag, detail)
    if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
        NMCore.logChannel("runtime", tag, detail)
    end
end

local function getMusicManager()
    if not getSoundManager then
        return nil
    end
    return getSoundManager()
end

local function clampVolume(value)
    return NMCore and NMCore.clamp and NMCore.clamp(tonumber(value) or 0, 0, 1) or math.max(0, math.min(1, tonumber(value) or 0))
end

local function getCurrentMusicVolume(sm)
    if not (sm and sm.getMusicVolume) then
        return nil
    end
    local ok, value = pcall(function()
        return sm:getMusicVolume()
    end)
    if not ok then
        return nil
    end
    return clampVolume(value)
end

local function setMusicVolume(sm, value)
    if not (sm and sm.setMusicVolume) then
        return false
    end
    local ok = pcall(function()
        sm:setMusicVolume(clampVolume(value))
    end)
    return ok == true
end

local function shouldMuteGameSoundtrackDuringPlayback()
    if NMRuntimeConfig and NMRuntimeConfig.getMuteGameSoundtrackDuringPlayback then
        return NMRuntimeConfig.getMuteGameSoundtrackDuringPlayback() ~= false
    end
    if NMClientModOptions and NMClientModOptions.getMuteGameSoundtrackDuringPlayback then
        return NMClientModOptions.getMuteGameSoundtrackDuringPlayback() ~= false
    end
    return true
end

local function captureSessionVolume(currentVolume)
    NMClientVanillaMusicSuppressor._capturedVolume = clampVolume(currentVolume or 0)
    NMClientVanillaMusicSuppressor._hasSessionCapture = true
end

local function clearSessionCapture()
    NMClientVanillaMusicSuppressor._capturedVolume = nil
    NMClientVanillaMusicSuppressor._hasSessionCapture = false
end

local function restoreCapturedVolume(sm, currentVolume, tickCount, reason)
    local restore = 0
    if NMClientVanillaMusicSuppressor._hasSessionCapture == true then
        restore = clampVolume(NMClientVanillaMusicSuppressor._capturedVolume or 0)
    end
    setMusicVolume(sm, restore)
    NMClientVanillaMusicSuppressor._suppressed = false
    clearSessionCapture()
    NMClientVanillaMusicSuppressor._lastRefreshTick = tonumber(tickCount) or 0
    logRuntimeProbe(
        "vanilla_music_suppress_end",
        string.format(
            "restored=%.3f current=%s reason=%s",
            tonumber(restore) or 0,
            tostring(currentVolume ~= nil and string.format("%.3f", currentVolume) or "nil"),
            tostring(reason or "not_audible")
        )
    )
end

function NMClientVanillaMusicSuppressor.beginTick()
    NMClientVanillaMusicSuppressor._tickAudible = false
end

function NMClientVanillaMusicSuppressor.observeAudibility(player, profile, state, source)
    if NMClientVanillaMusicSuppressor._tickAudible == true then
        return
    end
    if not (NMPlaybackRuntime and NMPlaybackRuntime.computeLocalListenerAudibility) then
        return
    end
    local audibility = NMPlaybackRuntime.computeLocalListenerAudibility(player, profile, state, source)
    if audibility and audibility.shouldSuppressVanillaMusic == true then
        NMClientVanillaMusicSuppressor._tickAudible = true
    end
end

function NMClientVanillaMusicSuppressor.endTick(tickCount)
    local sm = getMusicManager()
    if not sm then
        return
    end

    local audible = NMClientVanillaMusicSuppressor._tickAudible == true
    local suppressed = NMClientVanillaMusicSuppressor._suppressed == true
    local currentVolume = getCurrentMusicVolume(sm)
    local duckingEnabled = shouldMuteGameSoundtrackDuringPlayback()

    if duckingEnabled ~= true then
        if suppressed then
            restoreCapturedVolume(sm, currentVolume, tickCount, "disabled")
        else
            clearSessionCapture()
        end
        return
    end

    if audible then
        if not suppressed then
            captureSessionVolume(currentVolume)
            setMusicVolume(sm, 0)
            NMClientVanillaMusicSuppressor._suppressed = true
            NMClientVanillaMusicSuppressor._lastRefreshTick = tonumber(tickCount) or 0
            logRuntimeProbe(
                "vanilla_music_suppress_start",
                string.format(
                    "captured=%.3f current=%s",
                    tonumber(NMClientVanillaMusicSuppressor._capturedVolume) or 0,
                    tostring(currentVolume ~= nil and string.format("%.3f", currentVolume) or "nil")
                )
            )
            return
        end

        if currentVolume and currentVolume < 0 then
            currentVolume = 0
        end

        if currentVolume ~= 0 then
            setMusicVolume(sm, 0)
        end

        NMClientVanillaMusicSuppressor._lastRefreshTick = tonumber(tickCount) or 0
        return
    end

    if not suppressed then
        clearSessionCapture()
        return
    end

    restoreCapturedVolume(sm, currentVolume, tickCount, "not_audible")
end
