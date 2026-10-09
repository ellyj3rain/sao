local env = _G.NMDeviceWindowEnv
setfenv(1, env)

function prewarmUIAssetsOnce()
    if UI_ASSETS_PREWARMED == true then
        return
    end
    UI_ASSETS_PREWARMED = true
    if not getTexture then
        return
    end
    for i = 1, #UI_PREWARM_TEXTURE_PATHS do
        local path = UI_PREWARM_TEXTURE_PATHS[i]
        pcall(getTexture, path)
    end
end

function refreshFaderSize()
    if NMVolumeFader and NMVolumeFader.getPanelSize then
        local w, h = NMVolumeFader.getPanelSize()
        if tonumber(w) and tonumber(h) then
            FADER_W = w
            FADER_H = h
        end
    end
end

function refreshPaneSizes()
    if NMReadoutPane and NMReadoutPane.getSize then
        local w, h = NMReadoutPane.getSize()
        if tonumber(w) and tonumber(h) then
            READOUT_W = w
            READOUT_H = h
        end
    end
    if NMCoverPane and NMCoverPane.getSize then
        local w, h = NMCoverPane.getSize()
        if tonumber(w) and tonumber(h) then
            COVER_W = w
            COVER_H = h
        end
    end
end

function getPlayer(playerNum)
    return getSpecificPlayer and getSpecificPlayer(playerNum) or nil
end

function resolveWindowDeviceTitle(profile)
    local deviceType = tostring(profile and profile.deviceType or "")
    if deviceType == "boombox" then return NMTranslations.ui("Boombox", "Boombox") end
    if deviceType == "walkman" then return NMTranslations.ui("Walkman", "Walkman") end
    if deviceType == "vinylplayer" then return NMTranslations.ui("VinylPlayer", "Vinyl Player") end
    if deviceType == "cdplayer" then return NMTranslations.ui("CDPlayer", "CD Player") end
    if deviceType == "vehicle_radio" then return NMTranslations.ui("Vehicle", "Vehicle") end
    if deviceType ~= "" then
        local pretty = deviceType:gsub("_", " ")
        pretty = pretty:gsub("(%a)([%w_']*)", function(first, rest)
            return string.upper(first) .. string.lower(rest or "")
        end)
        return pretty
    end
    return NMTranslations.ui("Device", "Device")
end
