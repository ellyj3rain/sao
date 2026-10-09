-- Device capability profiles and output mode resolution policies.
tmDeviceProfiles = tmDeviceProfiles or {}
NMDeviceProfiles = NMDeviceProfiles or tmDeviceProfiles
NMDeviceProfiles.byType = NMDeviceProfiles.byType or {}
local mediaContract = type(NMMediaContract) == "table" and NMMediaContract or {
    CASSETTE_CARRIER = "nm_carrier_cassette",
    VINYL_CARRIER = "nm_carrier_vinyl",
    CD_CARRIER = "nm_carrier_cd"
}

local function register(fullType, profile)
    local copy = {}
    for k, v in pairs(profile) do
        copy[k] = v
    end
    copy.fullType = fullType
    NMDeviceProfiles.byType[fullType] = copy
end

NMDeviceProfiles.VehicleRadioProfile = NMDeviceProfiles.VehicleRadioProfile or {
    deviceType = "vehicle_radio",
    supportedCarrier = mediaContract.CASSETTE_CARRIER,
    allowInventoryPlayback = false,
    inventoryPlaybackMode = "none",
    attachedPlaybackMode = "none",
    allowPlacedWorldPlayback = false,
    placedPlaybackMode = "none",
    allowVehiclePlayback = true,
    vehiclePlaybackMode = "world",
    supportsHeadphones = false,
    supportsBattery = false,
    requiresHeadphonesForPlayback = false,
    requiresBattery = false,
    requiresExternalPower = false,
    defaultPlaybackMode = "world",
    personalVolumeScale = 1.0,
    worldVolumeScale = 1.0,
    vehicleVolumeScale = 1.0,
    powerDrainPerMinute = 0.0,
    worldMinRange = 8,
    worldMaxRange = 35,
    worldTrackingRange = 1500,
    worldTrackingFloors = 12,
    worldMinFloors = 3,
    worldMaxFloors = 3,
    worldVerticalCurveExponent = 1.0,
    worldCurveExponent = 1.0,
    worldFalloffExponent = 1.0,
    zombieMinRange = 8,
    zombieMaxRange = 100,
    zombiePlayerGateRange = 60,
    zombieCurveExponent = 1.0,
    zombiePulseMs = 5000,
    vehicleUsesCarBattery = true,
    vehicleWindowOcclusion = true,
    vehicleClosedWindowMultiplier = 0.17,
    vehicleClosedRangeMultiplier = 0.75,
    vehicleClosedFalloffExponent = 0.6,
    vehicleClosedZombieRangeMultiplier = 0.15,
    vehicleClosedZombieFalloffExponent = 0.5,
    vehicleBatteryDrainPerMinute = 0.000025
}

if not NMDeviceProfiles._defaultsRegistered then
    if NMDeviceProfileCatalog and NMDeviceProfileCatalog.registerDefaults then
        NMDeviceProfileCatalog.registerDefaults(register, mediaContract)
    end
    NMDeviceProfiles._defaultsRegistered = true
end

function NMDeviceProfiles.getForFullType(fullType)
    if not fullType then return nil end
    local key = tostring(fullType)
    if key == "vehicle_radio" then
        return NMDeviceProfiles.VehicleRadioProfile
    end
    local profile = NMDeviceProfiles.byType[key]
    if profile then
        return profile
    end
    if NMMediaContract and NMMediaContract.resolveContainerMediaBinding then
        local boundMedia = NMMediaContract.resolveContainerMediaBinding(key)
        if boundMedia and tostring(boundMedia) ~= "" then
            local carrier = NMMediaContract.resolveMediaCarrier and NMMediaContract.resolveMediaCarrier(boundMedia) or nil
            if carrier and tostring(carrier) ~= "" and NMDeviceProfiles.registerContainerProfile then
                NMDeviceProfiles.registerContainerProfile(key, carrier)
                return NMDeviceProfiles.byType[key]
            end
        end
    end
    return nil
end

function NMDeviceProfiles.getForItem(item)
    if not item or not item.getFullType then return nil end
    return NMDeviceProfiles.getForFullType(item:getFullType())
end

function NMDeviceProfiles.canInventoryPlayback(profile)
    return profile ~= nil and profile.allowInventoryPlayback == true
end

function NMDeviceProfiles.canPlacedWorldPlayback(profile)
    return profile ~= nil and profile.allowPlacedWorldPlayback == true
end

function NMDeviceProfiles.canVehiclePlayback(profile)
    return profile ~= nil and profile.allowVehiclePlayback == true
end

function NMDeviceProfiles.canAnyWorldPlayback(profile)
    return (profile and profile.attachedPlaybackMode == "world")
        or NMDeviceProfiles.canPlacedWorldPlayback(profile)
        or NMDeviceProfiles.canVehiclePlayback(profile)
end

function NMDeviceProfiles.supportsHeadphones(profile)
    return profile ~= nil and profile.supportsHeadphones == true
end

function NMDeviceProfiles.supportsBattery(profile)
    return profile ~= nil and profile.supportsBattery == true
end

function NMDeviceProfiles.requiresHeadphonesForPlayback(profile)
    return profile ~= nil and profile.requiresHeadphonesForPlayback == true
end

function NMDeviceProfiles.allowNoHeadphonesMutedPlayback(profile)
    if not profile or profile.allowNoHeadphonesMutedPlayback ~= true then
        return false
    end
    if not NMRuntimeConfig or not NMRuntimeConfig.getAllowNoHeadphonesPlaybackMutedPersonal then
        return false
    end
    return NMRuntimeConfig.getAllowNoHeadphonesPlaybackMutedPersonal() == true
end

function NMDeviceProfiles.requiresExternalPower(profile)
    return profile ~= nil and profile.requiresExternalPower == true
end

function NMDeviceProfiles.getExternalPowerType(profile)
    if not profile then return "none" end
    return tostring(profile.externalPowerType or "none")
end

function NMDeviceProfiles.getVehicleProfile(part)
    if not part then return nil end
    local data = part.getDeviceData and part:getDeviceData() or nil
    local item = part.getInventoryItem and part:getInventoryItem() or nil
    if not data or not item then return nil end
    return NMDeviceProfiles.VehicleRadioProfile
end

function NMDeviceProfiles.registerContainerProfile(fullType, carrier)
    local key = tostring(fullType or "")
    local c = tostring(
        (NMMediaContract and NMMediaContract.normalizeCarrierToken and NMMediaContract.normalizeCarrierToken(carrier))
        or carrier
        or ""
    )
    if key == "" or c == "" then
        return false
    end
    NMDeviceProfiles.byType[key] = {
        fullType = key,
        deviceType = "media_container",
        supportedCarrier = c,
        allowInventoryPlayback = false,
        inventoryPlaybackMode = "none",
        attachedPlaybackMode = "none",
        allowPlacedWorldPlayback = false,
        placedPlaybackMode = "none",
        supportsHeadphones = false,
        supportsBattery = false,
        requiresHeadphonesForPlayback = false,
        requiresBattery = false,
        requiresExternalPower = false,
        defaultPlaybackMode = "inventory",
        personalVolumeScale = 0.0,
        worldVolumeScale = 0.0,
        vehicleVolumeScale = 0.0,
        powerDrainPerMinute = 0.0,
        worldMaxRange = 0,
        isMediaContainerOnly = true
    }
    return true
end
