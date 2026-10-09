NMLootStandardMediaResidentialMultiplier = 7.0
NMLootStandardMediaVehicleMultiplier = 1.0
NMLootStandardDeviceMultiplier = 3.0
NMLootStandardDeviceVehicleMultiplier = 1.5
NMLootMusicStoreMediaTopUpMultiplier = 40.0
NMLootMusicStoreDeviceTopUpMultiplier = 3.0

NMLootStandardDeviceRatePoints = {
    { rate = 0.0, budget = 0.0 },
    { rate = 0.1, budget = 0.006 },
    { rate = 0.6, budget = 0.047 },
    { rate = 4.0, budget = 0.75 }
}

NMLootMusicStoreMediaTopUpRatePoints = {
    { rate = 0.1, budget = 0.22 },
    { rate = 0.6, budget = 1.0 },
    { rate = 4.0, budget = 3.5 }
}

NMLootMusicStoreMediaTopUpBias = {
    cassettes = 0.45,
    vinyl = 1.0,
    cds = 0.45
}

NMLootMusicStoreDeviceTopUpBias = {
    walkman = 0.45,
    boombox = 0.6,
    cdplayer = 0.45,
    recordplayer = 1.0
}

NMLootMusicStoreMediaTopUpTargets = {
    { name = "MusicStoreCases", weight = 3.5 },
    { name = "MusicStoreCDs", weight = 3.0 },
    { name = "MusicStoreSpeaker", weight = 1.5 },
    { name = "MusicStoreOthers", weight = 1.5 }
}

NMLootStandardMediaTargets = {
    cassettes = {
        { name = "ElectronicStoreMusic", weight = 1.25 },
        { name = "CrateElectronics", weight = 0.85 },
        { name = "ElectronicStoreCases", weight = 0.85 },
        { name = "ElectronicStoreMisc", weight = 0.75 },
        { name = "GigamartHouseElectronics", weight = 0.65 },
        { name = "CrateCompactDiscs", weight = 0.95 },
        { name = "BookstoreMusic", weight = 0.65 },
        { name = "LibraryMusic", weight = 0.45 },
        { name = "UniversityLibraryMusic", weight = 0.45 },
        { name = "RecRoomShelf", weight = 0.65 },
        { name = "SchoolLockers", weight = 0.75 },
        { name = "SchoolLockersBad", weight = 0.75 },
        { name = "SchoolDesk", weight = 0.45 },
        { name = "LivingRoomShelf", weight = 1.0 },
        { name = "LivingRoomShelfClassy", weight = 1.0 },
        { name = "LivingRoomShelfRedneck", weight = 0.9 },
        { name = "LivingRoomShelfNoTapes", weight = 0.7 },
        { name = "LivingRoomSideTable", weight = 0.55 },
        { name = "LivingRoomCabinet", weight = 0.65 },
        { name = "BedroomDresser", weight = 0.85 },
        { name = "BedroomDresserClassy", weight = 0.85 },
        { name = "StoreShelfCombo", weight = 0.45 }
    },
    cds = {
        { name = "ElectronicStoreMusic", weight = 1.25 },
        { name = "CrateElectronics", weight = 0.85 },
        { name = "ElectronicStoreCases", weight = 0.85 },
        { name = "ElectronicStoreMisc", weight = 0.75 },
        { name = "GigamartHouseElectronics", weight = 0.65 },
        { name = "CrateCompactDiscs", weight = 0.95 },
        { name = "BookstoreMusic", weight = 0.65 },
        { name = "LibraryMusic", weight = 0.45 },
        { name = "UniversityLibraryMusic", weight = 0.45 },
        { name = "RecRoomShelf", weight = 0.65 },
        { name = "SchoolLockers", weight = 0.75 },
        { name = "SchoolLockersBad", weight = 0.75 },
        { name = "SchoolDesk", weight = 0.45 },
        { name = "LivingRoomShelf", weight = 1.0 },
        { name = "LivingRoomShelfClassy", weight = 1.0 },
        { name = "LivingRoomShelfRedneck", weight = 0.9 },
        { name = "LivingRoomShelfNoTapes", weight = 0.7 },
        { name = "LivingRoomSideTable", weight = 0.55 },
        { name = "LivingRoomCabinet", weight = 0.65 },
        { name = "BedroomDresser", weight = 0.85 },
        { name = "BedroomDresserClassy", weight = 0.85 },
        { name = "StoreShelfCombo", weight = 0.45 }
    },
    vinyl = {
        { name = "ElectronicStoreMusic", weight = 0.85 },
        { name = "CrateElectronics", weight = 0.65 },
        { name = "ElectronicStoreCases", weight = 0.65 },
        { name = "ElectronicStoreMisc", weight = 0.55 },
        { name = "GigamartHouseElectronics", weight = 0.45 },
        { name = "BookstoreMusic", weight = 0.6 },
        { name = "LibraryMusic", weight = 0.35 },
        { name = "UniversityLibraryMusic", weight = 0.35 },
        { name = "RecRoomShelf", weight = 0.7 },
        { name = "LivingRoomShelf", weight = 1.0 },
        { name = "LivingRoomShelfClassy", weight = 1.0 },
        { name = "LivingRoomShelfRedneck", weight = 0.9 },
        { name = "LivingRoomShelfNoTapes", weight = 0.7 },
        { name = "LivingRoomSideTable", weight = 0.5 },
        { name = "LivingRoomCabinet", weight = 0.75 },
        { name = "BedroomDresser", weight = 0.75 },
        { name = "BedroomDresserClassy", weight = 0.75 },
        { name = "StoreShelfCombo", weight = 0.35 }
    }
}

NMLootStandardDeviceTargets = {
    walkman = NMLootStandardMediaTargets.cassettes,
    boombox = NMLootStandardMediaTargets.cassettes,
    cdplayer = NMLootStandardMediaTargets.cds,
    recordplayer = {
        { name = "ElectronicStoreMusic", weight = 0.85 },
        { name = "CrateElectronics", weight = 0.65 },
        { name = "ElectronicStoreCases", weight = 0.65 },
        { name = "ElectronicStoreMisc", weight = 0.55 },
        { name = "GigamartHouseElectronics", weight = 0.45 },
        { name = "BookstoreMusic", weight = 0.6 },
        { name = "RecRoomShelf", weight = 0.7 },
        { name = "LivingRoomShelf", weight = 1.0 },
        { name = "LivingRoomShelfClassy", weight = 1.0 },
        { name = "LivingRoomShelfRedneck", weight = 0.9 },
        { name = "LivingRoomShelfNoTapes", weight = 0.7 },
        { name = "LivingRoomSideTable", weight = 0.5 },
        { name = "LivingRoomCabinet", weight = 0.75 },
        { name = "BedroomDresser", weight = 0.75 },
        { name = "BedroomDresserClassy", weight = 0.75 },
        { name = "StoreShelfCombo", weight = 0.35 }
    }
}

return NMLootStandardMediaTargets
