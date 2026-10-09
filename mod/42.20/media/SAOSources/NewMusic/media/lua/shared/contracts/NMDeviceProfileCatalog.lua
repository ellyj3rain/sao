-- Device profile catalog data and default registration map.
NMDeviceProfileCatalog = NMDeviceProfileCatalog or {}

function NMDeviceProfileCatalog.registerDefaults(register, mediaContract)
    local walkmanProfile = {
        deviceType = "walkman",
        supportedCarrier = mediaContract.CASSETTE_CARRIER,
        allowInventoryPlayback = true,
        inventoryPlaybackMode = "personal",
        attachedPlaybackMode = "personal",
        allowPlacedWorldPlayback = false,
        placedPlaybackMode = "none",
        supportsHeadphones = true,
        defaultHeadphonesPresent = true,
        allowNoHeadphonesMutedPlayback = true,
        supportsBattery = true,
        requiresHeadphonesForPlayback = true,
        requiresBattery = true,
        defaultBatteryPresent = true,
        defaultBatteryCharge = 1.0,
        requiresExternalPower = false,
        defaultPlaybackMode = "inventory",
        personalVolumeScale = 1.0,
        worldVolumeScale = 1.0,
        vehicleVolumeScale = 1.0,
        powerDrainPerMinute = 0.00025,
        worldMaxRange = 0
    }

    local boomboxProfile = {
        deviceType = "boombox",
        supportedCarrier = mediaContract.CASSETTE_CARRIER,
        allowInventoryPlayback = false,
        inventoryPlaybackMode = "none",
        attachedPlaybackMode = "world",
        attachedPlaybackModeWithHeadphones = "personal",
        allowPlacedWorldPlayback = true,
        placedPlaybackMode = "world",
        placedPlaybackModeWithHeadphones = "silent",
        supportsHeadphones = true,
        defaultHeadphonesPresent = false,
        supportsBattery = true,
        requiresHeadphonesForPlayback = false,
        requiresBattery = true,
        defaultBatteryPresent = true,
        defaultBatteryCharge = 1.0,
        requiresExternalPower = false,
        defaultPlaybackMode = "world",
        personalVolumeScale = 1.0,
        worldVolumeScale = 1.0,
        vehicleVolumeScale = 1.0,
        powerDrainPerMinute = 0.00067,
        worldMinRange = 8,
        worldMaxRange = 35,
        worldTrackingRange = 1500,
        worldTrackingFloors = 12,
        worldMinFloors = 1,
        worldMaxFloors = 8,
        worldVerticalCurveExponent = 1.35,
        worldCurveExponent = 1.0,
        worldFalloffExponent = 1.0,
        zombieMinRange = 8,
        zombieMaxRange = 100,
        zombiePlayerGateRange = 60,
        zombieCurveExponent = 1.0,
        zombiePulseMs = 5000
    }

    local vinylplayerProfile = {
        deviceType = "vinylplayer",
        supportedCarrier = mediaContract.VINYL_CARRIER,
        allowInventoryPlayback = false,
        inventoryPlaybackMode = "none",
        attachedPlaybackMode = "none",
        allowPlacedWorldPlayback = true,
        placedPlaybackMode = "world",
        supportsHeadphones = false,
        supportsBattery = false,
        requiresHeadphonesForPlayback = false,
        requiresBattery = false,
        requiresExternalPower = true,
        externalPowerType = "grid_or_generator",
        defaultPlaybackMode = "world",
        personalVolumeScale = 1.0,
        worldVolumeScale = 1.0,
        vehicleVolumeScale = 1.0,
        powerDrainPerMinute = 0.0,
        worldMinRange = 8,
        worldMaxRange = 35,
        worldTrackingRange = 1500,
        worldTrackingFloors = 12,
        worldMinFloors = 1,
        worldMaxFloors = 8,
        worldVerticalCurveExponent = 1.35,
        worldCurveExponent = 1.0,
        worldFalloffExponent = 1.0,
        zombieMinRange = 8,
        zombieMaxRange = 100,
        zombiePlayerGateRange = 60,
        zombieCurveExponent = 1.0,
        zombiePulseMs = 5000
    }

    local cdPlayerProfile = {
        deviceType = "cdplayer",
        supportedCarrier = mediaContract.CD_CARRIER,
        allowInventoryPlayback = true,
        inventoryPlaybackMode = "personal",
        attachedPlaybackMode = "personal",
        allowPlacedWorldPlayback = false,
        placedPlaybackMode = "none",
        supportsHeadphones = true,
        defaultHeadphonesPresent = true,
        allowNoHeadphonesMutedPlayback = true,
        supportsBattery = true,
        requiresHeadphonesForPlayback = true,
        requiresBattery = true,
        defaultBatteryPresent = true,
        defaultBatteryCharge = 1.0,
        requiresExternalPower = false,
        defaultPlaybackMode = "inventory",
        personalVolumeScale = 1.0,
        worldVolumeScale = 1.0,
        vehicleVolumeScale = 1.0,
        powerDrainPerMinute = 0.0015,
        worldMaxRange = 0
    }

    local mediaContainerCDProfile = {
        deviceType = "media_container",
        supportedCarrier = mediaContract.CD_CARRIER,
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

    local mediaContainerVinylProfile = {
        deviceType = "media_container",
        supportedCarrier = mediaContract.VINYL_CARRIER,
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

    local mediaContainerCassetteProfile = {
        deviceType = "media_container",
        supportedCarrier = mediaContract.CASSETTE_CARRIER,
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

    register("NewMusic.WalkmanBlue", walkmanProfile)
    register("NewMusic.WalkmanPurple", walkmanProfile)
    register("NewMusic.WalkmanRed", walkmanProfile)
    register("NewMusic.WalkmanBlack", walkmanProfile)
    register("NewMusic.WalkmanPink", walkmanProfile)
    register("NewMusic.WalkmanGreen", walkmanProfile)
    register("NewMusic.WalkmanCamo", walkmanProfile)
    register("NewMusic.WalkmanOrange", walkmanProfile)
    register("NewMusic.WalkmanYellow", walkmanProfile)
    register("NewMusic.WalkmanCyan", walkmanProfile)
    register("NewMusic.WalkmanMagenta", walkmanProfile)
    register("NewMusic.WalkmanWhite", walkmanProfile)
    register("NewMusic.WalkmanLore", walkmanProfile)

    register("NewMusic.BoomboxGrey", boomboxProfile)
    register("NewMusic.BoomboxBlue", boomboxProfile)
    register("NewMusic.BoomboxCamo", boomboxProfile)
    register("NewMusic.BoomboxBlack", boomboxProfile)
    register("NewMusic.BoomboxGreen", boomboxProfile)
    register("NewMusic.BoomboxPink", boomboxProfile)
    register("NewMusic.BoomboxRed", boomboxProfile)
    register("NewMusic.BoomboxWhite", boomboxProfile)
    register("NewMusic.BoomboxOrange", boomboxProfile)
    register("NewMusic.BoomboxYellow", boomboxProfile)
    register("NewMusic.BoomboxCyan", boomboxProfile)
    register("NewMusic.BoomboxMagenta", boomboxProfile)
    register("NewMusic.BoomboxPurple", boomboxProfile)
    register("NewMusic.BoomboxOddbolt", boomboxProfile)

    register("NewMusic.VinylplayerEbony", vinylplayerProfile)
    register("NewMusic.VinylplayerOak", vinylplayerProfile)
    register("NewMusic.VinylplayerRosewood", vinylplayerProfile)
    register("NewMusic.VinylplayerMetal", vinylplayerProfile)

    register("NewMusic.CDPlayerBlue", cdPlayerProfile)
    register("NewMusic.CDPlayerBlack", cdPlayerProfile)
    register("NewMusic.CDPlayerCow", cdPlayerProfile)
    register("NewMusic.CDPlayerGreen", cdPlayerProfile)
    register("NewMusic.CDPlayerOrange", cdPlayerProfile)
    register("NewMusic.CDPlayerPurple", cdPlayerProfile)
    register("NewMusic.CDPlayerRed", cdPlayerProfile)
    register("NewMusic.CDPlayerWhite", cdPlayerProfile)
    register("NewMusic.CDPlayerYellow", cdPlayerProfile)
    register("NewMusic.CDPlayerMagenta", cdPlayerProfile)
    register("NewMusic.CDPlayerPink", cdPlayerProfile)
    register("NewMusic.CDPlayerCyan", cdPlayerProfile)

end



