-- Legacy-compatible track catalog registry used by child packs.
NMTrackCatalog = NMTrackCatalog or {}
NMTrackCatalog.entries = NMTrackCatalog.entries or {}
NMTrackCatalog.aliases = NMTrackCatalog.aliases or {}

local function normalizeTracks(tracks)
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

function NMTrackCatalog.registerEntry(mediaFullType, carrier, tracks)
    local key = tostring(mediaFullType or "")
    if key == "" then
        return
    end
    local list = normalizeTracks(tracks)
    if #list < 1 then
        return
    end
    NMTrackCatalog.entries[key] = {
        carrier = carrier and tostring(carrier) or nil,
        tracks = list
    }
end

function NMTrackCatalog.registerAlias(fromMediaFullType, toMediaFullType)
    local fromKey = tostring(fromMediaFullType or "")
    local toKey = tostring(toMediaFullType or "")
    if fromKey == "" or toKey == "" then
        return
    end
    NMTrackCatalog.aliases[fromKey] = toKey
end

function NMTrackCatalog.resolveTracks(mediaFullType)
    local key = tostring(mediaFullType or "")
    if key == "" then
        return nil
    end
    local seen = {}
    while NMTrackCatalog.aliases[key] and not seen[key] do
        seen[key] = true
        key = tostring(NMTrackCatalog.aliases[key])
    end
    return NMTrackCatalog.entries[key]
end


