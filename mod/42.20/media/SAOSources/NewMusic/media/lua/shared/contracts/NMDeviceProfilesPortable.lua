-- Shared portable tracked-source helpers for walkman, CD player, and boombox.
NMDeviceProfiles = NMDeviceProfiles or {}

local portableTrackedTypes = {
    walkman = true,
    cdplayer = true,
    boombox = true
}

local portableSilentTypes = {
    walkman = true,
    cdplayer = true
}

function NMDeviceProfiles.isPortableTrackedProfile(profile)
    local deviceType = tostring(profile and profile.deviceType or "")
    return portableTrackedTypes[deviceType] == true
end

function NMDeviceProfiles.isPortableSilentProfile(profile)
    local deviceType = tostring(profile and profile.deviceType or "")
    return portableSilentTypes[deviceType] == true
end

function NMDeviceProfiles.isPortableWorldAudibleProfile(profile)
    return NMDeviceProfiles.isPortableTrackedProfile(profile)
        and not NMDeviceProfiles.isPortableSilentProfile(profile)
end

function NMDeviceProfiles.isPortableTrackedContext(profile, context)
    if not NMDeviceProfiles.isPortableTrackedProfile(profile) then
        return false
    end
    local normalized = tostring(context or "")
    return normalized == "attached"
        or normalized == "pickup_pending"
        or normalized == "stowed"
        or normalized == "placed"
        or normalized == "drop_pending"
end

function NMDeviceProfiles.resolvePortableTrackedAction(profile, mode)
    if not NMDeviceProfiles.isPortableTrackedProfile(profile) then
        return nil
    end
    local normalized = tostring(mode or "off")
    if normalized == "attached" then
        return "sync_portable_attached"
    end
    if normalized == "pickup_pending" then
        return "sync_portable_attached"
    end
    if normalized == "placed" then
        return "sync_portable_placed"
    end
    if normalized == "drop_pending" then
        return nil
    end
    if normalized == "stowed" then
        return "sync_portable_stowed"
    end
    return nil
end
