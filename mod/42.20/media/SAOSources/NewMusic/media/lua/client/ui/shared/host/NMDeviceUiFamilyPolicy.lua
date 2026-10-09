require "ui/shared/host/NMDeviceUiChromePolicy"

NMDeviceUiFamilyPolicy = NMDeviceUiFamilyPolicy or {}

local policies = {
    generic = {
        familyId = "generic",
        chrome = "vanilla_window",
        chromePolicy = NMDeviceUiChromePolicy.get("vanilla_window"),
        slots = { "media", "headphones", "battery" },
        controls = {
            "close_window",
            "play",
            "stop",
            "next_track",
            "prev_track",
            "power_on",
            "power_off",
            "mute_on",
            "mute_off",
            "cycle_mode",
            "set_volume",
        },
        supportsMute = true,
        supportsHold = false,
        supportsLid = false,
        supportsShuffleMode = true,
        mechanics = {
            powerControl = "separate_power_button",
            mediaVisual = "generic",
            volumeControl = "generic",
            transportLayout = "generic",
        },
    },
    cdplayer = {
        familyId = "cdplayer",
        chrome = "fancy_window",
        chromePolicy = NMDeviceUiChromePolicy.get("fancy_window"),
        slots = { "media", "headphones", "battery" },
        controls = {
            "close_window",
            "play",
            "stop",
            "next_track",
            "prev_track",
            "power_on",
            "power_off",
            "cycle_mode",
            "hold_on",
            "hold_off",
            "set_volume",
            "open_lid",
            "close_lid",
        },
        supportsMute = false,
        supportsHold = true,
        supportsLid = true,
        supportsShuffleMode = true,
        mechanics = {
            powerControl = "separate_power_button",
            holdControl = "hold_switch",
            mediaVisual = "cd_disc",
            lidKind = "cd_lid",
            displayKind = "cd_display",
            volumeControl = "button_pair",
            transportLayout = "cd_cluster",
            hasSpinningMedia = true,
        },
    },
    walkman = {
        familyId = "walkman",
        chrome = "fancy_window",
        chromePolicy = NMDeviceUiChromePolicy.get("fancy_window"),
        slots = { "media", "headphones", "battery" },
        controls = {
            "close_window",
            "play",
            "stop",
            "next_track",
            "prev_track",
            "power_on",
            "power_off",
            "cycle_mode",
            "set_volume",
            "open_lid",
            "close_lid",
        },
        supportsMute = false,
        supportsHold = false,
        supportsLid = true,
        supportsShuffleMode = false,
        mechanics = {
            powerControl = "combined_play_power",
            mediaVisual = "cassette",
            lidKind = "cassette_lid",
            volumeControl = "side_wheel",
            transportLayout = "walkman_buttons",
            hasCassetteSpools = true,
        },
    },
    boombox = {
        familyId = "boombox",
        chrome = "fancy_window",
        chromePolicy = NMDeviceUiChromePolicy.get("fancy_window"),
        slots = { "media", "battery", "headphones" },
        controls = {
            "close_window",
            "play",
            "stop",
            "next_track",
            "prev_track",
            "power_on",
            "power_off",
            "set_volume",
            "open_lid",
            "close_lid",
            "eject_media",
            "set_playback_policy",
        },
        supportsMute = false,
        supportsHold = false,
        supportsLid = true,
        supportsShuffleMode = true,
        mechanics = {
            powerControl = "separate_power_switch",
            mediaVisual = "cassette",
            lidKind = "cassette_lid",
            volumeControl = "knob",
            transportLayout = "boombox_front_top_buttons",
            hasCassetteSpools = true,
        },
    }
}

function NMDeviceUiFamilyPolicy.get(familyId)
    return policies[tostring(familyId or "")] or nil
end

function NMDeviceUiFamilyPolicy.resolveForWindow(window)
    if window and window._nmUiFamilyPolicy then
        return window._nmUiFamilyPolicy
    end
    return NMDeviceUiFamilyPolicy.get(window and window._nmUiPerfKind or nil)
end

function NMDeviceUiFamilyPolicy.getMechanics(familyId)
    local policy = NMDeviceUiFamilyPolicy.get(familyId)
    return policy and policy.mechanics or nil
end

function NMDeviceUiFamilyPolicy.resolveMechanicsForWindow(window)
    local policy = NMDeviceUiFamilyPolicy.resolveForWindow(window)
    return policy and policy.mechanics or nil
end

return NMDeviceUiFamilyPolicy
