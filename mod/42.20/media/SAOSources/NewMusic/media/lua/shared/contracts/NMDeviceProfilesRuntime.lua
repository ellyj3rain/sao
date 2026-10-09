-- Runtime mode/media/range policy helpers layered on top of NMDeviceProfiles.
NMDeviceProfiles = NMDeviceProfiles or {}

function NMDeviceProfiles.resolveMediaCarrier(mediaItem)
    if not mediaItem then return nil end
    local fullType = mediaItem.getFullType and mediaItem:getFullType() or nil
    local typeName = mediaItem.getType and mediaItem:getType() or nil
    if NMMediaContract and NMMediaContract.resolveMediaCarrier then
        return NMMediaContract.resolveMediaCarrier(fullType or typeName)
    end
    return nil
end

function NMDeviceProfiles.isCompatibleMedia(profile, mediaItem)
    if not profile or not mediaItem then return false end
    local carrier = NMDeviceProfiles.resolveMediaCarrier(mediaItem)
    return carrier ~= nil and carrier == profile.supportedCarrier
end

local function hasHeadphones(state)
    return state and state.headphoneItemFullType ~= nil
end

local function usesSandboxAudioRadius(profile)
    local deviceType = tostring(profile and profile.deviceType or "")
    return deviceType == "boombox" or deviceType == "vinylplayer" or deviceType == "vehicle_radio"
end

local function resolveEffectiveWorldMaxRange(profile)
    if usesSandboxAudioRadius(profile)
        and NMRuntimeConfig
        and NMRuntimeConfig.getAudioMaxRadius then
        return tonumber(NMRuntimeConfig.getAudioMaxRadius()) or 35
    end
    return tonumber(profile and profile.worldMaxRange) or 0
end

local function resolveEffectiveZombieMaxRange(profile)
    if usesSandboxAudioRadius(profile) then
        local minRange = tonumber(profile and profile.zombieMinRange) or 0
        local configuredMax = tonumber(NMRuntimeConfig and NMRuntimeConfig.getZombieAttractionRadius and NMRuntimeConfig.getZombieAttractionRadius() or 105) or 105
        local derivedMax = math.min(configuredMax, 200)
        if derivedMax < minRange then
            derivedMax = minRange
        end
        return derivedMax
    end
    return tonumber(profile and profile.zombieMaxRange)
end

function NMDeviceProfiles.resolveOutputMode(profile, state, context, ignorePlaybackRequirements)
    if not profile then return "none" end
    local mode = "none"
    local ctx = tostring(context or "")
    if ctx == "inventory" then
        mode = profile.inventoryPlaybackMode or "none"
    elseif ctx == "attached" or ctx == "pickup_pending" then
        mode = profile.attachedPlaybackMode or "none"
        local insertedType = state and state.headphoneItemFullType or nil
        if hasHeadphones(state)
            and profile.attachedPlaybackModeWithHeadphones ~= nil
            and (not NMInsertedHeadphonePolicy or NMInsertedHeadphonePolicy.shouldApplyAttachedOverride(insertedType)) then
            mode = profile.attachedPlaybackModeWithHeadphones
        end
    elseif ctx == "stowed" then
        mode = profile.inventoryPlaybackMode or "none"
        if mode == "none" and NMDeviceProfiles.canAnyWorldPlayback(profile) then mode = "silent" end
    elseif ctx == "placed" then
        mode = profile.placedPlaybackMode or "none"
        local insertedType = state and state.headphoneItemFullType or nil
        if hasHeadphones(state)
            and profile.placedPlaybackModeWithHeadphones ~= nil
            and NMInsertedHeadphonePolicy
            and NMInsertedHeadphonePolicy.shouldApplyPlacedOverride(insertedType) then
            mode = profile.placedPlaybackModeWithHeadphones
        end
    elseif ctx == "drop_pending" then
        mode = "silent"
    elseif ctx == "vehicle" then
        mode = profile.vehiclePlaybackMode or "none"
    end
    if mode ~= "none" and mode ~= "personal" and mode ~= "world" and mode ~= "silent" then
        mode = "none"
    end
    if (not ignorePlaybackRequirements) and mode ~= "none"
        and NMDeviceProfiles.requiresHeadphonesForPlayback(profile) and (not hasHeadphones(state)) then
        if NMDeviceProfiles.allowNoHeadphonesMutedPlayback
            and NMDeviceProfiles.allowNoHeadphonesMutedPlayback(profile)
            and mode == "personal" then
            return "silent"
        end
        return "none"
    end
    if mode == "none"
        and NMDeviceProfiles.isPortableTrackedContext
        and NMDeviceProfiles.isPortableTrackedContext(profile, ctx)
        and state
        and state.isPlaying == true
        and state.mediaFullType ~= nil then
        return "silent"
    end
    return mode
end

function NMDeviceProfiles.computeWorldRange(profile, volume)
    local minRange = tonumber(profile and profile.worldMinRange) or 0
    local maxRange = resolveEffectiveWorldMaxRange(profile)
    if maxRange <= 0 then return 0 end
    if maxRange < minRange then maxRange = minRange end
    local v = NMCore.clamp(tonumber(volume) or 0, 0, 1)
    local exponent = tonumber(profile and profile.worldCurveExponent) or 1.0
    local loudness = NMCore.clamp(v ^ exponent, 0.0, 1.0)
    return minRange + ((maxRange - minRange) * loudness)
end

function NMDeviceProfiles.computeZombieRange(profile, volume, exponentMultiplier)
    local minRange = tonumber(profile and profile.zombieMinRange) or 0
    local maxRange = resolveEffectiveZombieMaxRange(profile) or minRange
    if maxRange < minRange then maxRange = minRange end
    local v = NMCore.clamp(tonumber(volume) or 0, 0, 1)
    local exponent = tonumber(profile and profile.zombieCurveExponent) or 1.0
    local extra = tonumber(exponentMultiplier) or 1.0
    if extra < 0.01 then extra = 0.01 end
    local loudness = NMCore.clamp(v ^ (exponent * extra), 0.0, 1.0)
    return minRange + ((maxRange - minRange) * loudness)
end

function NMDeviceProfiles.getWorldTrackingRange(profile)
    local cap = tonumber(NMRuntimeConfig and NMRuntimeConfig.getWorldTrackingCap and NMRuntimeConfig.getWorldTrackingCap() or 1500) or 1500
    local tracking = tonumber(profile and profile.worldTrackingRange)
    local baseRange = nil
    if tracking and tracking > 0 then
        baseRange = tracking
    else
        baseRange = resolveEffectiveWorldMaxRange(profile)
    end
    if cap <= 0 then
        return baseRange
    end
    return math.min(baseRange, cap)
end

function NMDeviceProfiles.getWorldTrackingFloors(profile)
    local tracking = tonumber(profile and profile.worldTrackingFloors)
    if tracking and tracking > 0 then return tracking end
    return tonumber(profile and profile.worldMaxFloors) or 0
end

function NMDeviceProfiles.getZombiePlayerGateRange(profile)
    local gateRange = nil
    if usesSandboxAudioRadius(profile) then
        gateRange = resolveEffectiveZombieMaxRange(profile)
    else
        gateRange = tonumber(profile and profile.zombiePlayerGateRange)
    end
    if gateRange and gateRange > 0 then return gateRange end
    return math.max(1, NMDeviceProfiles.computeZombieRange(profile, 1.0))
end

function NMDeviceProfiles.getZombiePulseIntervalMs(profile)
    local pulseMs = tonumber(profile and profile.zombiePulseMs)
    if pulseMs and pulseMs > 0 then
        return math.max(100, math.floor(pulseMs + 0.5))
    end
    return 1000
end

