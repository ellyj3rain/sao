require "music/NMTrackCatalog"
pcall(require, "contracts/NMMediaContract")
pcall(require, "contracts/NMCoverViewResolver")
pcall(require, "contracts/NMDeviceProfiles")

-- Child-pack helper.
-- Album files describe the data.
-- This file turns that data into tracks, carriers, side pairs, containers, and covers.

NMAlbumPackBuilder = NMAlbumPackBuilder or {}

local carrierByKind = {
    cassette = (NMMediaContract and NMMediaContract.CASSETTE_CARRIER) or "nm_carrier_cassette",
    vinyl = (NMMediaContract and NMMediaContract.VINYL_CARRIER) or "nm_carrier_vinyl",
    cd = (NMMediaContract and NMMediaContract.CD_CARRIER) or "nm_carrier_cd",
}

local function norm(value)
    local text = tostring(value or "")
    if text == "" then
        return ""
    end
    return text
end

local function fullType(moduleName, itemType)
    local name = norm(itemType)
    if name == "" then
        return ""
    end
    if string.find(name, ".", 1, true) then
        return name
    end
    local moduleText = norm(moduleName)
    if moduleText == "" then
        return name
    end
    return moduleText .. "." .. name
end

local function shortType(itemType)
    local name = norm(itemType)
    local dotPos = string.find(name, ".", 1, true)
    if dotPos then
        return string.sub(name, dotPos + 1)
    end
    return name
end

local function registerCarrier(itemType, carrier)
    local key = shortType(itemType)
    if key == "" or carrier == "" then
        return
    end
    if NMMediaContract and NMMediaContract.registerMediaTypeAlias then
        NMMediaContract.registerMediaTypeAlias(key, carrier)
        return
    end
    GlobalMusic = GlobalMusic or {}
    GlobalMusic[key] = carrier
end

local function copyTrackRow(row)
    local sound = row.sound and tostring(row.sound) or ""
    if sound == "" then
        return nil
    end
    local out = {
        sound = sound,
        label = row.label and tostring(row.label) or sound,
    }
    local trackNumber = tonumber(row.trackNumber)
    if trackNumber and trackNumber > 0 then
        out.trackNumber = math.floor(trackNumber)
    end
    if row.durationMs ~= nil then out.durationMs = row.durationMs end
    if row.durationSeconds ~= nil then out.durationSeconds = row.durationSeconds end
    if row.lengthSeconds ~= nil then out.lengthSeconds = row.lengthSeconds end
    if row.duration ~= nil then out.duration = row.duration end
    return out
end

local function buildTracksFromLabels(labels, soundPrefix, firstIndex, lastIndex)
    local tracks = {}
    local prefix = norm(soundPrefix)
    if type(labels) ~= "table" or prefix == "" then
        return tracks
    end

    for index = firstIndex, lastIndex do
        local label = labels[index]
        if type(label) == "table" then
            local row = copyTrackRow(label)
            if row then
                if not row.sound or row.sound == "" then
                    row.sound = string.format("%s%02d", prefix, index)
                end
                if row.trackNumber == nil then
                    row.trackNumber = index
                end
                tracks[#tracks + 1] = row
            end
        elseif type(label) == "string" and label ~= "" then
            tracks[#tracks + 1] = {
                sound = string.format("%s%02d", prefix, index),
                label = label,
                trackNumber = index,
            }
        end
    end

    return tracks
end

local function resolveTrackRows(albumDef, mediaDef, sideKey)
    local trackSource = mediaDef.trackSource or albumDef.trackSource or {}
    local explicit = trackSource.explicit
    if type(explicit) == "table" then
        local rows = explicit[sideKey]
        local out = {}
        if type(rows) ~= "table" then
            return out
        end
        for i = 1, #rows do
            local row = copyTrackRow(rows[i])
            if row then
                if row.trackNumber == nil then
                    row.trackNumber = i
                end
                out[#out + 1] = row
            end
        end
        return out
    end

    local labels = trackSource.labels or albumDef.tracks or {}
    local soundPrefix = trackSource.soundPrefix or albumDef.soundPrefix
    local ranges = mediaDef.ranges or {}
    local range = ranges[sideKey]
    if sideKey == "full" and type(range) ~= "table" then
        range = { 1, #labels }
    end
    if type(range) ~= "table" or tonumber(range[1]) == nil or tonumber(range[2]) == nil then
        return {}
    end

    return buildTracksFromLabels(labels, soundPrefix, tonumber(range[1]), tonumber(range[2]))
end

local function registerTrackEntry(mediaFullType, carrier, tracks)
    if mediaFullType == "" or carrier == "" or type(tracks) ~= "table" or #tracks < 1 then
        return
    end
    if NMTrackCatalog and NMTrackCatalog.registerEntry then
        NMTrackCatalog.registerEntry(mediaFullType, carrier, tracks)
    end
end

local function registerContainerBinding(moduleName, mediaKind, mediaDef, canonicalFullType)
    if not (NMMediaContract and NMDeviceProfiles) then
        return
    end

    local emptyFullType = fullType(moduleName, mediaDef.items and mediaDef.items.containerEmpty)
    local loadedFullType = fullType(moduleName, mediaDef.items and mediaDef.items.containerFull)
    local carrier = carrierByKind[mediaKind] or ""

    if emptyFullType == "" or loadedFullType == "" or canonicalFullType == "" or carrier == "" then
        return
    end

    if NMDeviceProfiles.registerContainerProfile then
        NMDeviceProfiles.registerContainerProfile(emptyFullType, carrier)
        NMDeviceProfiles.registerContainerProfile(loadedFullType, carrier)
    end
    if NMMediaContract.registerContainerSwapPair then
        NMMediaContract.registerContainerSwapPair(emptyFullType, loadedFullType)
    end
    if NMMediaContract.registerContainerMediaBinding then
        NMMediaContract.registerContainerMediaBinding(emptyFullType, canonicalFullType)
        NMMediaContract.registerContainerMediaBinding(loadedFullType, canonicalFullType)
    end
end

local function collectGroupItems(albumDef, groupDef, canonicalByKind, playableByKind)
    local itemSet = {}
    local ordered = {}

    local function addItem(fullTypeValue)
        local item = norm(fullTypeValue)
        if item == "" or itemSet[item] then
            return
        end
        itemSet[item] = true
        ordered[#ordered + 1] = item
    end

    local playableKinds = groupDef.includePlayable or {}
    for i = 1, #playableKinds do
        local kind = playableKinds[i]
        local playable = playableByKind[kind]
        if type(playable) == "table" then
            for j = 1, #playable do
                addItem(playable[j])
            end
        end
    end

    local containerKinds = groupDef.includeContainers or {}
    for i = 1, #containerKinds do
        local kind = containerKinds[i]
        local mediaDef = albumDef.media and albumDef.media[kind] or nil
        addItem(fullType(albumDef.module, mediaDef and mediaDef.items and mediaDef.items.containerFull))
    end

    local emptyContainerKinds = groupDef.includeEmptyContainers or {}
    for i = 1, #emptyContainerKinds do
        local kind = emptyContainerKinds[i]
        local mediaDef = albumDef.media and albumDef.media[kind] or nil
        addItem(fullType(albumDef.module, mediaDef and mediaDef.items and mediaDef.items.containerEmpty))
    end

    local extraItems = groupDef.itemTypes or {}
    for i = 1, #extraItems do
        addItem(fullType(albumDef.module, extraItems[i]))
    end

    return ordered
end

local function registerCoverGroups(albumDef, canonicalByKind, playableByKind)
    if not NMCoverViewResolver then
        return
    end

    local coverGroups = albumDef.coverGroups or {}
    for i = 1, #coverGroups do
        local groupDef = coverGroups[i]
        local mode = norm(groupDef.mode)
        local texture = norm(groupDef.texture)
        local items = collectGroupItems(albumDef, groupDef, canonicalByKind, playableByKind)

        if texture ~= "" and #items > 0 then
            for j = 1, #items do
                if mode == "fallback" and NMCoverViewResolver.registerFallbackCover then
                    NMCoverViewResolver.registerFallbackCover(items[j], texture)
                elseif mode ~= "fallback" and NMCoverViewResolver.registerLinkedCover then
                    NMCoverViewResolver.registerLinkedCover(items[j], texture)
                end
            end
        end
    end
end

function NMAlbumPackBuilder.registerAlbum(albumDef)
    if type(albumDef) ~= "table" then
        return false
    end

    local moduleName = norm(albumDef.module)
    local mediaDefs = type(albumDef.media) == "table" and albumDef.media or {}
    local canonicalByKind = {}
    local playableByKind = {}

    local orderedKinds = { "cassette", "vinyl", "cd" }
    for _, mediaKind in ipairs(orderedKinds) do
        local mediaDef = mediaDefs[mediaKind]
        local carrier = carrierByKind[mediaKind] or ""
        local playable = {}

        if type(mediaDef) == "table" and carrier ~= "" then
            local mode = norm(mediaDef.mode)
            if mode == "split" then
                local sideAFullType = fullType(moduleName, mediaDef.items and mediaDef.items.a)
                local sideBFullType = fullType(moduleName, mediaDef.items and mediaDef.items.b)
                local sideATracks = resolveTrackRows(albumDef, mediaDef, "a")
                local sideBTracks = resolveTrackRows(albumDef, mediaDef, "b")

                registerTrackEntry(sideAFullType, carrier, sideATracks)
                registerTrackEntry(sideBFullType, carrier, sideBTracks)
                registerCarrier(sideAFullType, carrier)
                registerCarrier(sideBFullType, carrier)

                if sideAFullType ~= "" then playable[#playable + 1] = sideAFullType end
                if sideBFullType ~= "" then playable[#playable + 1] = sideBFullType end
                canonicalByKind[mediaKind] = sideAFullType

                if NMMediaContract and NMMediaContract.registerMediaSides and sideAFullType ~= "" and sideBFullType ~= "" then
                    NMMediaContract.registerMediaSides(sideAFullType, sideBFullType)
                end
            elseif mode == "full" then
                local fullMediaType = fullType(moduleName, mediaDef.items and mediaDef.items.full)
                local fullTracks = resolveTrackRows(albumDef, mediaDef, "full")

                registerTrackEntry(fullMediaType, carrier, fullTracks)
                registerCarrier(fullMediaType, carrier)

                if fullMediaType ~= "" then playable[#playable + 1] = fullMediaType end
                canonicalByKind[mediaKind] = fullMediaType
            end

            playableByKind[mediaKind] = playable
            registerContainerBinding(moduleName, mediaKind, mediaDef, canonicalByKind[mediaKind] or "")
        end
    end

    registerCoverGroups(albumDef, canonicalByKind, playableByKind)
    return true
end

function NMAlbumPackBuilder.registerAlbumPack(packDef)
    if type(packDef) ~= "table" then
        return false
    end

    local albums = type(packDef.albums) == "table" and packDef.albums or {}
    for i = 1, #albums do
        local albumDef = albums[i]
        if type(albumDef) == "table" and norm(albumDef.module) == "" then
            albumDef.module = packDef.module
        end
        NMAlbumPackBuilder.registerAlbum(albumDef)
    end
    return true
end
