-- SP detached world-source snapshot persistence and hydration helpers.
NMWorldRegistrySnapshot = NMWorldRegistrySnapshot or {}
NMWorldRegistrySnapshot.Key = NMWorldRegistrySnapshot.Key or (NMCore.ModId .. "_sp_world_snapshot_v1")
NMWorldRegistrySnapshot.SchemaVersion = NMWorldRegistrySnapshot.SchemaVersion or 1
NMWorldRegistrySnapshot.DefaultStaleMinutes = NMWorldRegistrySnapshot.DefaultStaleMinutes or 4320

local function nowRealMinutes()
    local ms = nil
    if getTimestampMs then
        ms = tonumber(getTimestampMs())
    end
    if ms == nil and getTimestamp then
        local ts = tonumber(getTimestamp())
        if ts then
            ms = ts * 1000
        end
    end
    if ms == nil and os and os.time then
        local t = tonumber(os.time())
        if t then
            ms = t * 1000
        end
    end
    if ms == nil then
        return 0.0
    end
    return ms / 60000.0
end

local function getStore(createIfMissing)
    if not ModData or not ModData.getOrCreate then
        return nil
    end
    local md = ModData.getOrCreate(NMWorldRegistrySnapshot.Key)
    if not md then
        return nil
    end
    if createIfMissing and type(md.entries) ~= "table" then
        md.entries = {}
    end
    md.schemaVersion = NMWorldRegistrySnapshot.SchemaVersion
    return md
end

local function isFiniteNumber(v)
    local n = tonumber(v)
    return n ~= nil and n == n
end

local function coerceEntry(raw, nowMin, staleMinutes)
    if type(raw) ~= "table" then
        return nil
    end
    local uuid = tostring(raw.uuid or "")
    local kind = tostring(raw.kind or "")
    if uuid == "" then return nil end
    if kind ~= "item" and kind ~= "vehicle" then return nil end
    if not isFiniteNumber(raw.x) or not isFiniteNumber(raw.y) or not isFiniteNumber(raw.z) then
        return nil
    end
    if type(raw.state) ~= "table" then return nil end
    if tostring(raw.state.deviceUUID or "") ~= uuid then return nil end

    if kind == "item" then
        if tostring(raw.itemId or "") == "" or tostring(raw.itemFullType or "") == "" then
            return nil
        end
    else
        if tostring(raw.vehicleId or "") == "" or tostring(raw.partId or "") == "" then
            return nil
        end
    end

    local updated = tonumber(raw.updatedAtRealMinutes) or 0
    if staleMinutes > 0 and updated > 0 and nowMin > 0 and (nowMin - updated) > staleMinutes then
        return nil
    end

    local out = {
        uuid = uuid,
        kind = kind,
        x = tonumber(raw.x) or 0,
        y = tonumber(raw.y) or 0,
        z = tonumber(raw.z) or 0,
        state = raw.state,
        revision = tonumber(raw.revision) or tonumber(raw.state and raw.state.revision) or 0,
        playbackEpoch = tonumber(raw.playbackEpoch) or tonumber(raw.state and raw.state.playbackEpoch) or 0,
        updatedAtRealMinutes = updated
    }

    if kind == "item" then
        out.itemId = tostring(raw.itemId)
        out.itemFullType = tostring(raw.itemFullType)
    else
        out.vehicleId = tostring(raw.vehicleId)
        out.vehicleIdHint = tostring(raw.vehicleIdHint or raw.vehicleId or "")
        out.vehicleSqlId = tostring(raw.vehicleSqlId or "")
        out.vehicleSqlIdHint = tostring(raw.vehicleSqlIdHint or raw.vehicleSqlId or "")
        out.partId = tostring(raw.partId)
        out.windowsOpen = raw.windowsOpen == true
    end
    return out
end

function NMWorldRegistrySnapshot.loadSP()
    local md = getStore(true)
    if not md then
        return {}
    end
    local nowMin = nowRealMinutes()
    local staleMinutes = tonumber(NMWorldRegistrySnapshot.DefaultStaleMinutes) or 4320
    local cleaned = {}
    local entries = md.entries or {}
    for _, raw in pairs(entries) do
        local entry = coerceEntry(raw, nowMin, staleMinutes)
        if entry then
            local prev = cleaned[entry.uuid]
            if (not prev) or ((tonumber(entry.updatedAtRealMinutes) or 0) >= (tonumber(prev.updatedAtRealMinutes) or 0)) then
                cleaned[entry.uuid] = entry
            end
        end
    end
    md.entries = cleaned
    return cleaned
end

function NMWorldRegistrySnapshot.upsertSP(entry)
    local md = getStore(true)
    if not md then
        return false
    end
    local nowMin = nowRealMinutes()
    local staleMinutes = tonumber(NMWorldRegistrySnapshot.DefaultStaleMinutes) or 4320
    local clean = coerceEntry(entry, nowMin, staleMinutes)
    if not clean then
        return false
    end
    clean.updatedAtRealMinutes = nowMin
    md.entries[clean.uuid] = clean
    return true
end

function NMWorldRegistrySnapshot.removeSP(uuid)
    if uuid == nil then return end
    local md = getStore(true)
    if not md or type(md.entries) ~= "table" then
        return
    end
    md.entries[tostring(uuid)] = nil
end

function NMWorldRegistrySnapshot.seedCacheForPlayerSP(player, seedFn)
    if not player or type(seedFn) ~= "function" then
        return 0
    end
    local seeded = 0
    local entries = NMWorldRegistrySnapshot.loadSP()
    for _, entry in pairs(entries) do
        if seedFn(entry) == true then
            seeded = seeded + 1
        end
    end
    return seeded
end

