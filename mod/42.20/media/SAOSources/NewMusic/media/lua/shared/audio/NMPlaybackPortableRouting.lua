-- Portable tracked-source render policy layered on top of profile output resolution.
NMPlaybackPortableRouting = NMPlaybackPortableRouting or {}

local function isMPClientRuntime()
    return NMCore and NMCore.isMPClientRuntime and NMCore.isMPClientRuntime() == true
end

function NMPlaybackPortableRouting.shouldUseDualRender(profile, context)
    return NMDeviceProfiles
        and NMDeviceProfiles.isPortableTrackedContext
        and NMDeviceProfiles.isPortableTrackedContext(profile, context)
        and isMPClientRuntime()
end

function NMPlaybackPortableRouting.resolvePolicy(profile, state, context, outputMode, configuredVolume, effectiveVolume, personalOwnerAllowed)
    local trackedPortable = NMDeviceProfiles
        and NMDeviceProfiles.isPortableTrackedContext
        and NMDeviceProfiles.isPortableTrackedContext(profile, context)
    local audibility = tostring(outputMode or "none")

    if trackedPortable and audibility == "none" and state and state.isPlaying == true and state.mediaFullType ~= nil then
        audibility = "silent"
    end

    -- Silent portable profiles keep transport alive on placed/drop-pending paths without becoming world-audible.
    if trackedPortable
        and (context == "placed" or context == "drop_pending")
        and NMDeviceProfiles
        and NMDeviceProfiles.isPortableSilentProfile
        and NMDeviceProfiles.isPortableSilentProfile(profile) then
        audibility = "silent"
    end

    local dualRender = NMPlaybackPortableRouting.shouldUseDualRender(profile, context)
        and audibility ~= "personal"

    local keepSynced = trackedPortable
        and state
        and state.isPlaying == true
        and state.mediaFullType ~= nil
    local shouldPlay = keepSynced == true
        or (state and state.isPlaying == true and audibility ~= "none" and state.mediaFullType ~= nil and personalOwnerAllowed ~= false)

    local routeWorld = 0
    local routePersonal = 0
    if audibility == "world" then
        routeWorld = tonumber(effectiveVolume) or 0
    elseif audibility == "personal" and personalOwnerAllowed ~= false then
        routePersonal = tonumber(effectiveVolume) or 0
    end

    if trackedPortable and NMDeviceProfiles and NMDeviceProfiles.isPortableSilentProfile and NMDeviceProfiles.isPortableSilentProfile(profile) then
        routeWorld = 0
    end

    local singleWorldOutput = (audibility == "world")
        or (audibility == "silent" and context ~= "inventory")

    return {
        trackedPortable = trackedPortable == true,
        dualRender = dualRender == true,
        keepSynced = keepSynced == true,
        shouldPlay = shouldPlay == true,
        audibility = audibility,
        routeWorld = NMCore and NMCore.clamp and NMCore.clamp(routeWorld, 0, 1) or math.max(0, math.min(1, routeWorld)),
        routePersonal = NMCore and NMCore.clamp and NMCore.clamp(routePersonal, 0, 1) or math.max(0, math.min(1, routePersonal)),
        singleWorldOutput = singleWorldOutput == true,
        configuredVolume = tonumber(configuredVolume) or 0,
        effectiveVolume = tonumber(effectiveVolume) or 0
    }
end
