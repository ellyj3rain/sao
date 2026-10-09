-- Pure fade and range math for world audio attenuation.
NMFadeMath = NMFadeMath or {}

function NMFadeMath.computeLoudnessFactor(profile, volume)
    local v = NMCore.clamp(tonumber(volume) or 0, 0, 1)
    local exponent = tonumber(profile and profile.worldCurveExponent) or 1.0
    return NMCore.clamp(v ^ exponent, 0.0, 1.0)
end

function NMFadeMath.computeWorldRange(profile, volume)
    if NMDeviceProfiles and NMDeviceProfiles.computeWorldRange then
        return NMDeviceProfiles.computeWorldRange(profile, volume)
    end
    local minRange = tonumber(profile and profile.worldMinRange) or 0
    local maxRange = tonumber(profile and profile.worldMaxRange) or 0
    if maxRange <= 0 then
        return 0
    end
    if maxRange < minRange then
        maxRange = minRange
    end
    local loudness = NMFadeMath.computeLoudnessFactor(profile, volume)
    return minRange + ((maxRange - minRange) * loudness)
end

function NMFadeMath.computeHorizontalFalloff(distance, range, exponent)
    local d = math.max(0.0, tonumber(distance) or 0.0)
    local r = tonumber(range) or 0.0
    if r <= 0.0 then
        return 0.0
    end
    local t = NMCore.clamp(d / r, 0.0, 1.0)
    local e = tonumber(exponent) or 1.0
    local falloff = 1.0 - (t ^ e)
    return NMCore.clamp(falloff, 0.0, 1.0)
end

function NMFadeMath.computeWorldFloorCap(profile, volume)
    local minFloors = tonumber(profile and profile.worldMinFloors)
    local maxFloors = tonumber(profile and profile.worldMaxFloors)
    if minFloors == nil and maxFloors == nil then
        return 0
    end
    minFloors = minFloors or 0
    maxFloors = maxFloors or minFloors
    if maxFloors < minFloors then
        maxFloors = minFloors
    end
    local v = NMCore.clamp(tonumber(volume) or 0, 0, 1)
    local exponent = tonumber(profile and profile.worldVerticalCurveExponent) or 1.0
    local loudness = NMCore.clamp(v ^ exponent, 0.0, 1.0)
    return minFloors + ((maxFloors - minFloors) * loudness)
end

function NMFadeMath.computeVerticalFadeMultiplier(dzFloors, profile, baseVolume)
    local dz = tonumber(dzFloors) or 0
    if dz <= 0 then
        return 1.0
    end
    local floorCap = tonumber(NMFadeMath.computeWorldFloorCap(profile, baseVolume)) or 0
    if floorCap <= 0 then
        return 1.0
    end

    local minAudible = 0.10
    local exponent = tonumber(profile and profile.worldVerticalCurveExponent) or 1.0
    exponent = NMCore.clamp(exponent, 0.1, 8.0)

    local t = NMCore.clamp(dz / floorCap, 0.0, 1.0)
    local nearFade = minAudible + ((1.0 - minAudible) * (1.0 - (t ^ exponent)))
    if dz <= floorCap then
        return NMCore.clamp(nearFade, 0.0, 1.0)
    end

    local trackingFloors = tonumber(NMDeviceProfiles and NMDeviceProfiles.getWorldTrackingFloors and NMDeviceProfiles.getWorldTrackingFloors(profile) or 0) or 0
    if trackingFloors <= floorCap then
        return NMCore.clamp(minAudible, 0.0, 1.0)
    end

    local tailT = NMCore.clamp((dz - floorCap) / (trackingFloors - floorCap), 0.0, 1.0)
    local tailFade = minAudible * (1.0 - (tailT ^ exponent))
    return NMCore.clamp(tailFade, 0.0, 1.0)
end



