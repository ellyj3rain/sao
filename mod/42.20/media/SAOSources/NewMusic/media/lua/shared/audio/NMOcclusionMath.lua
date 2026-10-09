-- Vehicle/window occlusion math for audio and zombie attraction attenuation.
NMOcclusionMath = NMOcclusionMath or {}

function NMOcclusionMath.resolveClosedSourceRange(profile, range)
    local r = tonumber(range) or 0.0
    local mult = tonumber(profile and profile.vehicleClosedRangeMultiplier) or 0.50
    return r * NMCore.clamp(mult, 0.05, 1.0)
end

function NMOcclusionMath.resolveClosedSourceFalloffExponent(profile, baseExponent)
    local e = tonumber(baseExponent) or 1.0
    local mult = tonumber(profile and profile.vehicleClosedFalloffExponent) or 2.0
    return e * NMCore.clamp(mult, 0.1, 8.0)
end

function NMOcclusionMath.resolveClosedWindowVolumeMultiplier(profile)
    local mult = tonumber(profile and profile.vehicleClosedWindowMultiplier) or 0.20
    return NMCore.clamp(mult, 0.0, 1.0)
end

function NMOcclusionMath.applyClosedWindowVolume(profile, volume)
    local v = tonumber(volume) or 0.0
    return v * NMOcclusionMath.resolveClosedWindowVolumeMultiplier(profile)
end

function NMOcclusionMath.resolveClosedZombieRangeMultiplier(profile)
    local mult = tonumber(profile and profile.vehicleClosedZombieRangeMultiplier)
        or tonumber(profile and profile.vehicleClosedRangeMultiplier)
        or 0.50
    return NMCore.clamp(mult, 0.0, 1.0)
end

function NMOcclusionMath.resolveClosedZombieExponentMultiplier(profile)
    local mult = tonumber(profile and profile.vehicleClosedZombieFalloffExponent)
        or tonumber(profile and profile.vehicleClosedFalloffExponent)
        or 1.0
    return NMCore.clamp(mult, 0.1, 8.0)
end



