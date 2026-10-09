-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
-- Media contract and legacy carrier token compatibility surface.
NMMediaContract = NMMediaContract or {}
tmMediaContract = tmMediaContract or NMMediaContract
NMMusic = NMMusic or {}
if type(GlobalMusic) ~= "table" then
    GlobalMusic = {}
end
NMVanillaCDCompat = NMVanillaCDCompat or { trackList = nil, carrier = "nm_carrier_cd" }

local LEGACY_CASSETTE_CARRIER = "tsarcraft_music_01_62"
local LEGACY_VINYL_CARRIER = "tsarcraft_music_01_63"
local LEGACY_CD_CARRIER = "tsarcraft_music_01_64"
local CASSETTE_CARRIER = "nm_carrier_cassette"
local VINYL_CARRIER = "nm_carrier_vinyl"
local CD_CARRIER = "nm_carrier_cd"
local VANILLA_CD_PREFIX = "NMVanillaCDIndex."
local containerVisualSwapPairs = {
    ["NewMusic.CDCoverEmpty"] = "NewMusic.CDCoverBlank",
    ["NewMusic.CDCoverBlank"] = "NewMusic.CDCoverEmpty"
}
local containerMediaBindings = {}
local mediaSidePairs = {}
local mediaCanonicalByType = {}

local function normalizeCarrierToken(token)
    local text = tostring(token or "")
    if text == "" then
        return ""
    end
    local lower = string.lower(text)
    if lower == string.lower(CASSETTE_CARRIER) or text == LEGACY_CASSETTE_CARRIER then
        return CASSETTE_CARRIER
    end
    if lower == string.lower(VINYL_CARRIER) or text == LEGACY_VINYL_CARRIER then
        return VINYL_CARRIER
    end
    if lower == string.lower(CD_CARRIER) or text == LEGACY_CD_CARRIER then
        return CD_CARRIER
    end
    return text
end

local function registerAlias(itemType, carrier)
    local key = tostring(itemType or "")
    local normalized = normalizeCarrierToken(carrier)
    if key == "" or normalized == "" then
        return
    end
    GlobalMusic[key] = normalized
end

registerAlias(LEGACY_CASSETTE_CARRIER, LEGACY_CASSETTE_CARRIER)
registerAlias(LEGACY_VINYL_CARRIER, LEGACY_VINYL_CARRIER)
registerAlias(LEGACY_CD_CARRIER, LEGACY_CD_CARRIER)
registerAlias("Disc_Retail", CD_CARRIER)
registerAlias("CassetteMainTheme", CASSETTE_CARRIER)
registerAlias("VinylMainTheme", VINYL_CARRIER)
registerAlias("CDMainTheme", CD_CARRIER)

function NMMediaContract.getCarrierKeys()
    return {
        cassette = CASSETTE_CARRIER,
        vinyl = VINYL_CARRIER,
        cd = CD_CARRIER
    }
end

function NMMediaContract.getLegacyCarriers()
    return {
        cassette = LEGACY_CASSETTE_CARRIER,
        vinyl = LEGACY_VINYL_CARRIER,
        cd = LEGACY_CD_CARRIER
    }
end

function NMMediaContract.isLegacyCarrier(token)
    local t = tostring(token or "")
    return t == LEGACY_CASSETTE_CARRIER or t == LEGACY_VINYL_CARRIER or t == LEGACY_CD_CARRIER
end

function NMMediaContract.registerMediaTypeAlias(itemType, carrier)
    if not itemType or not carrier then
        return
    end
    registerAlias(itemType, carrier)
end

function NMMediaContract.resolveMediaCarrier(mediaFullTypeOrType)
    if not mediaFullTypeOrType then
        return nil
    end
    local key = tostring(mediaFullTypeOrType)
    local dotPos = string.find(key, "%.")
    if dotPos then
        key = string.sub(key, dotPos + 1)
    end
    local mapped = GlobalMusic[key]
    if mapped then
        local normalized = normalizeCarrierToken(mapped)
        if normalized ~= "" then
            if tostring(mapped) ~= normalized then
                GlobalMusic[key] = normalized
            end
            return normalized
        end
    end

    -- Legacy-pack fallback: many child packs rely on old TM bootstrap files.
    -- If those fail to require, infer carrier from historical type prefixes.
    local lower = string.lower(key)
    if string.sub(lower, 1, 8) == "cassette" then
        GlobalMusic[key] = CASSETTE_CARRIER
        return CASSETTE_CARRIER
    end
    if string.sub(lower, 1, 5) == "vinyl" then
        GlobalMusic[key] = VINYL_CARRIER
        return VINYL_CARRIER
    end
    if string.sub(lower, 1, 2) == "cd" then
        GlobalMusic[key] = CD_CARRIER
        return CD_CARRIER
    end
    return nil
end

function NMMusic.buildVanillaCDTrackKey(mediaIndex)
    local idx = tonumber(mediaIndex)
    if idx == nil then
        idx = -1
    end
    return VANILLA_CD_PREFIX .. tostring(math.floor(idx))
end

local function resolveVanillaCDTrackKey(mediaFullType)
    local key = tostring(mediaFullType or "")
    if string.sub(key, 1, #VANILLA_CD_PREFIX) ~= VANILLA_CD_PREFIX then
        return nil
    end
    local idx = tonumber(string.sub(key, #VANILLA_CD_PREFIX + 1))
    local list = NMVanillaCDCompat and NMVanillaCDCompat.trackList or nil
    if type(list) ~= "table" or #list < 1 then
        return nil
    end
    local n = #list
    local sel = 1
    if idx and idx >= 0 then
        sel = (idx % n) + 1
    end
    local track = list[sel]
    if type(track) ~= "table" or not track.sound then
        return nil
    end
    local row = { sound = tostring(track.sound), label = track.label and tostring(track.label) or tostring(track.sound) }
    local trackNumber = tonumber(track.trackNumber)
    if trackNumber and trackNumber > 0 then row.trackNumber = math.floor(trackNumber) end
    if track.durationMs ~= nil then row.durationMs = track.durationMs end
    if track.durationSeconds ~= nil then row.durationSeconds = track.durationSeconds end
    if track.lengthSeconds ~= nil then row.lengthSeconds = track.lengthSeconds end
    if track.duration ~= nil then row.duration = track.duration end
    return {
        carrier = NMVanillaCDCompat.carrier or CD_CARRIER,
        tracks = { row }
    }
end

function NMMusic.registerVanillaCDFallbackTracks(trackList, carrier)
    if type(trackList) ~= "table" or #trackList < 1 then
        NMVanillaCDCompat.trackList = nil
        NMVanillaCDCompat.carrier = carrier or CD_CARRIER
        return
    end
    local clean = {}
    for i = 1, #trackList do
        local e = trackList[i]
        if type(e) == "table" and e.sound and tostring(e.sound) ~= "" then
            local row = { sound = tostring(e.sound), label = e.label and tostring(e.label) or tostring(e.sound) }
            local trackNumber = tonumber(e.trackNumber)
            if trackNumber and trackNumber > 0 then row.trackNumber = math.floor(trackNumber) end
            if e.durationMs ~= nil then row.durationMs = e.durationMs end
            if e.durationSeconds ~= nil then row.durationSeconds = e.durationSeconds end
            if e.lengthSeconds ~= nil then row.lengthSeconds = e.lengthSeconds end
            if e.duration ~= nil then row.duration = e.duration end
            clean[#clean + 1] = row
        elseif type(e) == "string" and e ~= "" then
            clean[#clean + 1] = { sound = e, label = e }
        end
    end
    NMVanillaCDCompat.trackList = (#clean > 0) and clean or nil
    NMVanillaCDCompat.carrier = carrier or CD_CARRIER
end

function NMMusic.getSoundName(mediaItem)
    if not mediaItem then
        return nil
    end
    local dotPos = string.find(mediaItem, "%.")
    if dotPos then
        return string.sub(mediaItem, dotPos + 1)
    end
    return mediaItem
end

function NMMusic.resolveMediaCarrier(mediaFullTypeOrType)
    return NMMediaContract.resolveMediaCarrier(mediaFullTypeOrType)
end

local function normalizeTrackList(tracks)
    local out = {}
    local function copyTrackRow(row)
        local sound = row.sound and tostring(row.sound) or ""
        if sound == "" then
            return nil
        end
        local norm = {
            sound = sound,
            label = row.label and tostring(row.label) or sound
        }
        local trackNumber = tonumber(row.trackNumber)
        if trackNumber and trackNumber > 0 then
            norm.trackNumber = math.floor(trackNumber)
        end
        if row.durationMs ~= nil then norm.durationMs = row.durationMs end
        if row.durationSeconds ~= nil then norm.durationSeconds = row.durationSeconds end
        if row.lengthSeconds ~= nil then norm.lengthSeconds = row.lengthSeconds end
        if row.duration ~= nil then norm.duration = row.duration end
        return norm
    end
    if type(tracks) ~= "table" then
        return out
    end
    for i = 1, #tracks do
        local it = tracks[i]
        if type(it) == "table" and it.sound and tostring(it.sound) ~= "" then
            local row = copyTrackRow(it)
            if row then
                out[#out + 1] = row
            end
        elseif type(it) == "string" and it ~= "" then
            out[#out + 1] = { sound = it, label = it }
        end
    end
    return out
end

local function normalizeResolvedEntry(entry, fallbackCarrier)
    if type(entry) ~= "table" then
        return nil
    end
    local tracks = normalizeTrackList(entry.tracks)
    if #tracks < 1 then
        return nil
    end
    return {
        carrier = normalizeCarrierToken(entry.carrier and tostring(entry.carrier) or fallbackCarrier),
        tracks = tracks
    }
end

local function resolveFromGenericCatalog(catalog, mediaFullType)
    if type(catalog) ~= "table" then
        return nil
    end
    local entries = catalog.entries
    if type(entries) ~= "table" then
        return nil
    end
    local key = tostring(mediaFullType or "")
    local aliases = type(catalog.aliases) == "table" and catalog.aliases or nil
    if aliases then
        local seen = {}
        while aliases[key] and not seen[key] do
            seen[key] = true
            key = tostring(aliases[key])
        end
    end
    local entry = entries[key]
    return normalizeResolvedEntry(entry, nil)
end

function NMMusic.resolveTracks(mediaFullType)
    if not mediaFullType then
        return nil
    end

    local vanillaCD = resolveVanillaCDTrackKey(mediaFullType)
    if vanillaCD then
        return vanillaCD
    end

    if NMTrackCatalog and type(NMTrackCatalog.resolveTracks) == "function" then
        local ok, resolved = pcall(NMTrackCatalog.resolveTracks, mediaFullType)
        if ok then
            local norm = normalizeResolvedEntry(resolved, nil)
            if norm then
                return norm
            end
        end
    end

    for name, value in pairs(_G) do
        if type(name) == "string" and name ~= "NMTrackCatalog" and string.find(name, "TrackCatalog", 1, true) then
            local resolved = resolveFromGenericCatalog(value, mediaFullType)
            if resolved then
                return resolved
            end
        end
    end

    local fallbackSound = NMMusic.getSoundName(mediaFullType)
    local fallbackCarrier = NMMusic.resolveMediaCarrier(mediaFullType)
    if not fallbackSound or fallbackSound == "" then
        return nil
    end
    return {
        carrier = fallbackCarrier,
        tracks = {
            { sound = fallbackSound, label = fallbackSound }
        }
    }
end

function NMMediaContract.resolveContainerSwapFullType(currentFullType, wantLoaded)
    local current = tostring(currentFullType or "")
    if current == "" then
        return nil
    end
    local peer = containerVisualSwapPairs[current]
    if not peer or peer == "" then
        return nil
    end
    local loaded = tostring(wantLoaded) == "true"
    local isCurrentLoaded = current:find("Empty", 1, true) == nil
    if loaded == isCurrentLoaded then
        return current
    end
    return peer
end

function NMMediaContract.registerContainerSwapPair(fullTypeA, fullTypeB)
    local a = tostring(fullTypeA or "")
    local b = tostring(fullTypeB or "")
    if a == "" or b == "" or a == b then
        return false
    end
    containerVisualSwapPairs[a] = b
    containerVisualSwapPairs[b] = a
    return true
end

function NMMediaContract.registerContainerMediaBinding(containerFullType, mediaFullType)
    local c = tostring(containerFullType or "")
    local m = tostring(mediaFullType or "")
    if c == "" or m == "" then
        return false
    end
    containerMediaBindings[c] = m
    return true
end

function NMMediaContract.resolveContainerMediaBinding(containerFullType)
    local c = tostring(containerFullType or "")
    if c == "" then
        return nil
    end
    local m = containerMediaBindings[c]
    if not m or m == "" then
        return nil
    end
    return m
end

function NMMediaContract.isContainerLoadedFullType(containerFullType)
    local current = tostring(containerFullType or "")
    if current == "" then
        return false
    end
    local peer = containerVisualSwapPairs[current]
    if not peer or peer == "" then
        return current:find("Empty", 1, true) == nil
    end
    local loadedTarget = NMMediaContract.resolveContainerSwapFullType(current, true)
    if loadedTarget and loadedTarget ~= "" then
        return loadedTarget == current
    end
    return current:find("Empty", 1, true) == nil
end

function NMMediaContract.registerMediaSidePair(sideAFullType, sideBFullType, canonicalFullType)
    local a = tostring(sideAFullType or "")
    local b = tostring(sideBFullType or "")
    if a == "" or b == "" or a == b then
        return false
    end
    local canonical = tostring(canonicalFullType or a)
    if canonical == "" then
        canonical = a
    end
    mediaSidePairs[a] = b
    mediaSidePairs[b] = a
    mediaCanonicalByType[a] = canonical
    mediaCanonicalByType[b] = canonical
    mediaCanonicalByType[canonical] = canonical
    return true
end

function NMMediaContract.registerMediaSides(sideAFullType, sideBFullType)
    return NMMediaContract.registerMediaSidePair(sideAFullType, sideBFullType, sideAFullType)
end

function NMMediaContract.resolveMediaFlipTarget(mediaFullType)
    local key = tostring(mediaFullType or "")
    if key == "" then
        return nil
    end
    local peer = mediaSidePairs[key]
    if not peer or peer == "" then
        return nil
    end
    return peer
end

function NMMediaContract.resolveMediaCanonical(mediaFullType)
    local key = tostring(mediaFullType or "")
    if key == "" then
        return nil
    end
    local canonical = mediaCanonicalByType[key]
    if canonical and canonical ~= "" then
        return canonical
    end
    return key
end

function NMMediaContract.areMediaEquivalent(leftFullType, rightFullType)
    local left = NMMediaContract.resolveMediaCanonical(leftFullType)
    local right = NMMediaContract.resolveMediaCanonical(rightFullType)
    if not left or not right then
        return false
    end
    return tostring(left) == tostring(right)
end

NMMediaContract.CASSETTE_CARRIER = CASSETTE_CARRIER
NMMediaContract.VINYL_CARRIER = VINYL_CARRIER
NMMediaContract.CD_CARRIER = CD_CARRIER
NMMediaContract.LEGACY_CASSETTE_CARRIER = LEGACY_CASSETTE_CARRIER
NMMediaContract.LEGACY_VINYL_CARRIER = LEGACY_VINYL_CARRIER
NMMediaContract.LEGACY_CD_CARRIER = LEGACY_CD_CARRIER
NMMediaContract.normalizeCarrierToken = normalizeCarrierToken

tmMediaContract = NMMediaContract



