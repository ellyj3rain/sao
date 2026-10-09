-- Shared authority contract for durable playback state across contexts.
NMAuthorityContract = NMAuthorityContract or {}

local CONTEXTS = {
    inventory = { battery = "server", playback = "server", progression = "server" },
    personal = { battery = "server", playback = "server", progression = "server" },
    attached = { battery = "server", playback = "server", progression = "server" },
    placed = { battery = "server", playback = "server", progression = "server" },
    stowed = { battery = "server", playback = "server", progression = "server" },
    vehicle_inside = { battery = "server", playback = "server", progression = "server" },
    vehicle_outside = { battery = "server", playback = "server", progression = "server" }
}

local DURABLE_FIELDS = {
    batteryPresent = true,
    batteryCharge = true,
    isOn = true,
    desiredIsOn = true,
    isPlaying = true,
    desiredIsPlaying = true,
    lastStopReason = true,
    trackIndex = true,
    trackCount = true,
    playbackEpoch = true,
    revision = true,
    serverTrackStartedAtMs = true,
    serverTrackDurationMs = true,
    serverTrackDueAtMs = true
}

local function normalizeContext(context)
    local key = tostring(context or "")
    if key == "" then
        key = "inventory"
    end
    if CONTEXTS[key] then
        return key
    end
    return "inventory"
end

function NMAuthorityContract.getContext(context)
    local key = normalizeContext(context)
    return CONTEXTS[key], key
end

function NMAuthorityContract.isDurableField(name)
    return DURABLE_FIELDS[tostring(name or "")] == true
end

function NMAuthorityContract.isMPServerRuntime()
    return NMCore and NMCore.isMPServerAuthority and NMCore.isMPServerAuthority() == true
end

function NMAuthorityContract.isMPClientRuntime()
    return NMCore and NMCore.isMPClientRuntime and NMCore.isMPClientRuntime() == true
end

function NMAuthorityContract.canMutateDurableStateAtRuntime()
    return not NMAuthorityContract.isMPClientRuntime()
end


