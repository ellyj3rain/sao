-- Authoritative source-mode state and source generation transitions.
NMDeviceAuthorityState = NMDeviceAuthorityState or {}

function NMDeviceAuthorityState.isProfileEligible(profile)
    if not profile then
        return false
    end
    return NMDeviceAuthorityState.isDeviceTypeEligible(tostring(profile.deviceType or ""))
end

function NMDeviceAuthorityState.isDeviceTypeEligible(deviceType)
    local dt = tostring(deviceType or "")
    local scope = tostring(NMRuntimeConfig and NMRuntimeConfig.getAuthorityScope and NMRuntimeConfig.getAuthorityScope() or "all_world_devices")
    if scope == "boombox_only" then
        return dt == "boombox"
    elseif scope == "portable_world_devices" then
        return dt == "boombox" or dt == "vehicle_radio"
    end
    return dt ~= ""
end

function NMDeviceAuthorityState.ensureState(state)
    if not state then
        return nil
    end
    state.stateVersion = 4
    state.authoritativeMode = NMDeviceAuthorityStateCommon.normalizedMode(state.authoritativeMode)
    state.sourceGeneration = math.max(0, tonumber(state.sourceGeneration) or 0)
    state.sourceKind = tostring(state.sourceKind or "none")
    state.sourceX = NMDeviceAuthorityStateCommon.asNumber(state.sourceX)
    state.sourceY = NMDeviceAuthorityStateCommon.asNumber(state.sourceY)
    state.sourceZ = NMDeviceAuthorityStateCommon.asNumber(state.sourceZ)
    if state.sourceOwner == nil then
        state.sourceOwner = nil
    end
    state.isMuted = state.isMuted == true
    if state.isMuted ~= true then
        state.muteReason = nil
    elseif state.muteReason == nil then
        state.muteReason = "manual"
    end
    return state
end

function NMDeviceAuthorityState.applyIntent(state, intent, context)
    state = NMDeviceAuthorityState.ensureState(state)
    context = context or {}
    if not state then
        return false, "missing_state", nil
    end

    local resolved = NMDeviceAuthorityStateCommon.resolveIntent(intent, context)
    if not resolved then
        return false, "unknown_intent", nil
    end
    local targetMode = resolved.targetMode
    local sourceKind = resolved.sourceKind
    local sx, sy, sz = resolved.sx, resolved.sy, resolved.sz
    local sourceOwner = resolved.sourceOwner

    local unchanged = NMDeviceAuthorityStateCommon.sameSourceState(state, targetMode, sourceKind, sx, sy, sz, sourceOwner)
    if unchanged and context.forceGenerationBump ~= true then
        return false, nil, {
            previousMode = targetMode,
            nextMode = targetMode,
            previousGeneration = tonumber(state.sourceGeneration) or 0,
            nextGeneration = tonumber(state.sourceGeneration) or 0,
            generationBumped = false
        }
    end

    local previousMode = NMDeviceAuthorityStateCommon.normalizedMode(state.authoritativeMode)
    local previousGeneration = math.max(0, tonumber(state.sourceGeneration) or 0)
    local shouldBump = context.forceGenerationBump == true
        or previousMode ~= targetMode
        or tostring(state.sourceKind or "none") ~= tostring(sourceKind)
        or tostring(state.sourceOwner or "") ~= tostring(sourceOwner or "")

    state.authoritativeMode = targetMode
    state.sourceKind = sourceKind
    state.sourceOwner = sourceOwner
    state.sourceX = NMDeviceAuthorityStateCommon.asNumber(sx)
    state.sourceY = NMDeviceAuthorityStateCommon.asNumber(sy)
    state.sourceZ = NMDeviceAuthorityStateCommon.asNumber(sz)
    if shouldBump then
        state.sourceGeneration = previousGeneration + 1
    else
        state.sourceGeneration = previousGeneration
    end

    return true, nil, {
        previousMode = previousMode,
        nextMode = targetMode,
        previousGeneration = previousGeneration,
        nextGeneration = tonumber(state.sourceGeneration) or previousGeneration,
        generationBumped = shouldBump == true
    }
end

function NMDeviceAuthorityState.resolveSource(state, fallbackSource, fallbackOwner)
    state = NMDeviceAuthorityState.ensureState(state)
    if not state then
        return nil
    end
    local mode = NMDeviceAuthorityStateCommon.normalizedMode(state.authoritativeMode)
    if mode == "off" then
        return nil
    end

    local fallback = fallbackSource or {}
    local source = {
        mode = "world",
        context = mode,
        x = NMDeviceAuthorityStateCommon.asNumber(state.sourceX) or NMDeviceAuthorityStateCommon.asNumber(fallback.x),
        y = NMDeviceAuthorityStateCommon.asNumber(state.sourceY) or NMDeviceAuthorityStateCommon.asNumber(fallback.y),
        z = NMDeviceAuthorityStateCommon.asNumber(state.sourceZ) or NMDeviceAuthorityStateCommon.asNumber(fallback.z),
        sourceOwner = state.sourceOwner or fallbackOwner
    }
    if mode == "vehicle" then
        source.vehicleId = fallback.vehicleId
        source.vehicle = fallback.vehicle
        source.windowsOpen = fallback.windowsOpen
    end
    return source
end

function NMDeviceAuthorityState.isWorldActive(state)
    state = NMDeviceAuthorityState.ensureState(state)
    if not state then
        return false
    end
    if not NMDeviceAuthorityState.isDeviceTypeEligible(state.deviceType) then
        return false
    end
    if tostring(state.playbackMode or "") ~= "world" then
        return false
    end
    local mode = NMDeviceAuthorityStateCommon.normalizedMode(state.authoritativeMode)
    if mode == "off" then
        return false
    end
    return state.isOn == true
        or state.desiredIsOn == true
        or state.isPlaying == true
        or state.desiredIsPlaying == true
end

NMAuthorityV4 = NMAuthorityV4 or NMDeviceAuthorityState
NMAuthorityV3 = NMAuthorityV3 or NMDeviceAuthorityState



