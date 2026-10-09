-- Canonical shared ui_render helper for family-agnostic readout text selection.
NMReadoutTextResolver = NMReadoutTextResolver or {}

local function clampTrackIndex(idx, count)
    local n = tonumber(idx) or 1
    if n < 1 then n = 1 end
    if n > count then n = count end
    return n
end

local function resolveMediaDisplayName(state)
    local fullType = tostring(state and state.mediaFullType or "")
    if fullType == "" then
        return NMTranslations.ui("NoMedia", "No Media")
    end

    local display = tostring(state and state.mediaDisplayName or "")
    if display ~= "" then
        return display
    end

    if NMMediaContract and NMMediaContract.getDisplayNameForFullType then
        local resolved = tostring(NMMediaContract.getDisplayNameForFullType(fullType) or "")
        if resolved ~= "" then
            return resolved
        end
    end

    local sm = getScriptManager and getScriptManager() or nil
    local scriptItem = sm and sm.getItem and sm:getItem(fullType) or nil
    if scriptItem and scriptItem.getDisplayName then
        local ok, name = pcall(scriptItem.getDisplayName, scriptItem)
        if ok and name and tostring(name) ~= "" then
            return tostring(name)
        end
    end

    return fullType
end

local function resolveSongLabel(state)
    local fullType = tostring(state and state.mediaFullType or "")
    if fullType == "" or not (NMMusic and NMMusic.resolveTracks) then
        return NMTranslations.ui("NoSong", "No Song")
    end

    local ok, resolved = pcall(NMMusic.resolveTracks, fullType)
    if not ok or type(resolved) ~= "table" or type(resolved.tracks) ~= "table" or #resolved.tracks < 1 then
        return NMTranslations.ui("NoSong", "No Song")
    end

    local idx = clampTrackIndex(state and state.trackIndex, #resolved.tracks)
    local row = resolved.tracks[idx]
    local fallback = type(row) == "table" and row.sound or row
    local label = NMTranslations.numberedTrackLabel(row, fallback)
    label = tostring(label or "")
    if label == "" then
        return NMTranslations.ui("NoSong", "No Song")
    end
    return label
end

local function isSingleTrackMedia(state)
    local fullType = tostring(state and state.mediaFullType or "")
    if fullType == "" or not (NMMusic and NMMusic.resolveTracks) then
        return false
    end
    local ok, resolved = pcall(NMMusic.resolveTracks, fullType)
    return ok and type(resolved) == "table" and type(resolved.tracks) == "table" and #resolved.tracks == 1
end

function NMReadoutTextResolver.resolveReadoutText(state)
    local mediaLabel = resolveMediaDisplayName(state)
    local songLabel = resolveSongLabel(state)
    if isSingleTrackMedia(state) then
        return mediaLabel
    end
    if tostring(mediaLabel) ~= "" and mediaLabel == songLabel then
        return mediaLabel
    end
    if tostring(songLabel or "") ~= "" and songLabel ~= NMTranslations.ui("NoSong", "No Song") then
        return songLabel
    end
    return mediaLabel
end
