-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
-- Listener-relative playback audibility policy (volume scaling, range/falloff, vehicle occlusion).
NMPlaybackAudibility = NMPlaybackAudibility or {}

local function outputScaleForChannel(profile, channelKind, context)
    if not profile then
        return 1.0
    end
    if channelKind == "personal" then
        local pv = tonumber(profile.personalVolumeScale)
        if pv ~= nil then
            return NMCore.clamp(pv, 0.0, 2.0)
        end
        local legacy = tonumber(profile.inventoryVolumeScale)
        if legacy ~= nil then
            return NMCore.clamp(legacy, 0.0, 2.0)
        end
        return 1.0
    end

    if tostring(context or "") == "vehicle" then
        local vv = tonumber(profile.vehicleVolumeScale)
        if vv ~= nil then
            return NMCore.clamp(vv, 0.0, 2.0)
        end
    end
    local wv = tonumber(profile.worldVolumeScale)
    if wv ~= nil then
        return NMCore.clamp(wv, 0.0, 2.0)
    end
    return 1.0
end

local function vehicleWindowsOpen(vehicle)
    if not vehicle then
        return false
    end
    if vehicle.windowsOpen then
        return (tonumber(vehicle:windowsOpen()) or 0) > 0
    end
    return false
end

local function listenerInSourceVehicle(player, source)
    if not player or not source or not player.getVehicle then
        return false
    end
    local listenerVehicle = player:getVehicle()
    if not listenerVehicle then
        return false
    end
    local listenerId = listenerVehicle.getId and tostring(listenerVehicle:getId()) or ""
    if listenerId == "" then
        return false
    end

    local sourceVehicleId = tostring(source.vehicleId or "")
    if sourceVehicleId ~= "" and sourceVehicleId == listenerId then
        return true
    end

    local sourceVehicle = source.vehicle
    if (not sourceVehicle) and sourceVehicleId ~= "" and getVehicleById then
        sourceVehicle = getVehicleById(tonumber(sourceVehicleId))
    end
    return sourceVehicle ~= nil and listenerVehicle == sourceVehicle
end

local function sourceClosedVehicleExternal(profile, player, source)
    if tostring(source and source.context or "") ~= "vehicle" then
        return false
    end
    if not profile or profile.vehicleWindowOcclusion ~= true then
        return false
    end
    local open = source and source.windowsOpen == true
    if not open and source and source.vehicle then
        open = vehicleWindowsOpen(source.vehicle)
    end
    if open then
        return false
    end
    return not listenerInSourceVehicle(player, source)
end

local function listenerClosedVehicleExternal(player, source)
    if not player or not player.getVehicle then
        return false
    end
    local listenerVehicle = player:getVehicle()
    if not listenerVehicle then
        return false
    end
    if vehicleWindowsOpen(listenerVehicle) then
        return false
    end
    return not listenerInSourceVehicle(player, source)
end

local function shouldApplyMasterVolume(profile, source, channelKind)
    if channelKind == "world" then
        return true
    end
    local context = tostring(source and source.context or "")
    if context ~= "vehicle" then
        return false
    end
    if tostring(profile and profile.deviceType or "") ~= "vehicle_radio" then
        return false
    end
    if not (NMRuntimeConfig and NMRuntimeConfig.getVehicleDualEmittersEnabled) then
        return false
    end
    return NMRuntimeConfig.getVehicleDualEmittersEnabled() == true
end

function NMPlaybackAudibility.computeChannelVolume(profile, state, player, source, channelKind, routedVolume)
    local base = NMCore.clamp(tonumber(routedVolume) or 0.0, 0.0, 1.0)
    if base <= 0.0 then
        return 0.0
    end

    local context = tostring(source and source.context or "")
    local volume = base * outputScaleForChannel(profile, channelKind, context)
    if channelKind ~= "world" and not shouldApplyMasterVolume(profile, source, channelKind) then
        return NMCore.clamp(volume, 0.0, 1.0)
    end

    if source and source.x and source.y and source.z and player and player.getX and player.getY then
        local dx = (tonumber(player:getX()) or 0) - (tonumber(source.x) or 0)
        local dy = (tonumber(player:getY()) or 0) - (tonumber(source.y) or 0)
        local dist = math.sqrt((dx * dx) + (dy * dy))

        local listenerZ = tonumber(player.getZ and player:getZ() or 0) or 0
        local sourceZ = tonumber(source.z) or 0
        local dzFloors = math.abs(listenerZ - sourceZ)
        local verticalFade = NMFadeMath.computeVerticalFadeMultiplier(dzFloors, profile, tonumber(state and state.volume) or 1.0)
        volume = volume * verticalFade

        local range = NMFadeMath.computeWorldRange(profile, tonumber(state and state.volume) or 1.0)
        local closedSourceExternal = sourceClosedVehicleExternal(profile, player, source)
        if closedSourceExternal then
            range = NMOcclusionMath.resolveClosedSourceRange(profile, range)
        end

        local exponent = tonumber(profile and profile.worldFalloffExponent) or 1.0
        if closedSourceExternal then
            exponent = NMOcclusionMath.resolveClosedSourceFalloffExponent(profile, exponent)
        end
        local falloff = NMFadeMath.computeHorizontalFalloff(dist, range, exponent)
        volume = volume * falloff

        if closedSourceExternal or listenerClosedVehicleExternal(player, source) then
            volume = NMOcclusionMath.applyClosedWindowVolume(profile, volume)
        end
    end

    local masterVolume = NMRuntimeConfig and NMRuntimeConfig.getNewMusicMasterVolume and NMRuntimeConfig.getNewMusicMasterVolume() or 1.0
    volume = volume * (NMCore and NMCore.clamp and NMCore.clamp(tonumber(masterVolume) or 1.0, 0.0, 1.0) or math.max(0.0, math.min(1.0, tonumber(masterVolume) or 1.0)))

    return NMCore.clamp(volume, 0.0, 1.0)
end

