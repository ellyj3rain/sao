-- Device UUID allocator and item registry identity helpers.
NMDeviceRegistry = NMDeviceRegistry or {}
NMDeviceRegistry.SeqModDataKey = NMDeviceRegistry.SeqModDataKey or (NMCore.ModId .. "_registry")

local function nowMillisString()
    if getTimestampMs then
        local ts = tonumber(getTimestampMs())
        if ts and ts > 0 then
            return tostring(ts)
        end
    end
    return tostring(ZombRand and ZombRand(1000000000) or 0)
end

local function randomChunk()
    local v = ZombRand and ZombRand(0x7fffffff) or 0
    return string.format("%08x", tonumber(v) or 0)
end

local function nextDeviceSequence()
    if isClient and isClient() and (not isServer or not isServer()) then
        return nil
    end
    if not (ModData and ModData.getOrCreate) then
        return nil
    end
    local md = ModData.getOrCreate(NMDeviceRegistry.SeqModDataKey)
    local seq = tonumber(md.nextDeviceSeq) or 1
    md.nextDeviceSeq = seq + 1
    if isServer and isServer() and ModData.transmit then
        ModData.transmit(NMDeviceRegistry.SeqModDataKey)
    end
    return seq
end

function NMDeviceRegistry.generateUUID(deviceType)
    local seq = nextDeviceSequence()
    local seqPart = seq and string.format("%08d", seq) or "00000000"
    return tostring(deviceType or "dev") .. "-" .. seqPart .. "-" .. nowMillisString() .. "-" .. randomChunk()
end

function NMDeviceRegistry.ensure(item, deviceType)
    if not item or not item.getModData then
        return nil
    end
    local md = item:getModData()
    md[NMCore.RegistryKey] = md[NMCore.RegistryKey] or {}
    local reg = md[NMCore.RegistryKey]
    if not reg.deviceUUID or reg.deviceUUID == "" then
        reg.deviceUUID = NMDeviceRegistry.generateUUID(deviceType)
    end
    if deviceType and (not reg.deviceType or reg.deviceType == "") then
        reg.deviceType = tostring(deviceType)
    end
    return reg.deviceUUID
end

function NMDeviceRegistry.get(item)
    if not item or not item.getModData then
        return nil
    end
    local reg = item:getModData()[NMCore.RegistryKey]
    if not reg then
        return nil
    end
    return reg.deviceUUID
end

