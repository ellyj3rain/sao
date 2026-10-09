-- Core constants and low-level utilities shared by client and server.
NMCore = NMCore or {}

NMCore.ModId = "newmusic"
NMCore.BuildMarker = "NM_BUILD_2026-08-18_1"
NMCore.NetModule = "newmusic_device"
NMCore.StateKey = "nm_device_state"
NMCore.RegistryKey = "nm_device"
NMCore.StateVersion = 4
NMCore.Debug = false
NMCore.DebugPlayback = false
NMCore.DebugChannels = NMCore.DebugChannels or {}
NMCore.DebugThrottle = NMCore.DebugThrottle or {}
NMCore.SuppressVanillaWorldContext = true
NMCore.BuildVersionLineBySide = NMCore.BuildVersionLineBySide or {}

local function toBool(v)
    return v == true
end

local function mapLogSection(channel)
    local raw = tostring(channel or "")
    local map = {
        runtimeProbe = "TimeProbe",
        memoryProbe = "MemoryProbe",
        progressionProbe = "TimeProbe",
        vehicleTruthProbe = "VehicleTruthProbe",
        intent = "IntentProbe",
        core = "CoreProbe",
        registry = "RegistryProbe",
        lootDiagnostics = "LootProbe",
        lootProbe = "LootProbe",
        zombieDiagnostics = "ZombieProof",
        transitionProbe = "TransitionProbe",
        uiPerfProbe = "UiPerfProbe",
        uiAutoCloseProbe = "UiAutoCloseProbe",
        portableUiProbe = "UiLifecycleProbe",
        uiLifecycleProbe = "UiLifecycleProbe",
        cycleModeProbe = "CycleModeProbe",
        slotAuthorityProbe = "SlotAuthorityProbe"
    }
    if map[raw] then
        return map[raw]
    end
    local compact = raw:gsub("[^%w]+", " ")
    local words = {}
    for part in compact:gmatch("%S+") do
        words[#words + 1] = part
    end
    if #words == 0 then
        return "CoreProbe"
    end
    local out = {}
    for i = 1, #words do
        local w = words[i]
        if w:find("%u") and w:find("%l") then
            out[#out + 1] = w:sub(1, 1):upper() .. w:sub(2)
        else
            out[#out + 1] = w:sub(1, 1):upper() .. w:sub(2):lower()
        end
    end
    local joined = table.concat(out, "")
    if joined:sub(-5) ~= "Probe" then
        joined = joined .. "Probe"
    end
    return joined
end

local function debugPrint(msg)
    print("[NewMusic] [CoreProbe] " .. tostring(msg or ""))
end

local function derivePublicBuildVersion()
    local token = NMRuntimeConfig and NMRuntimeConfig.getBuildContentToken and tostring(NMRuntimeConfig.getBuildContentToken() or "") or ""
    local year, month, day, revision = token:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)%-.+%-(%d+)$")
    if year and month and day and revision then
        return string.format("v%s.%s.%s.%s", year, month, day, revision)
    end
    if token ~= "" then
        return "v" .. token
    end
    return "vunknown"
end

local function resolveSubsystemName(name)
    local runtime = type(NMRuntimeConfig) == "table" and NMRuntimeConfig or nil
    if runtime and runtime.resolveSubsystemDebugName then
        return runtime.resolveSubsystemDebugName(name)
    end
    local key = tostring(name or "")
    return key ~= "" and key or nil
end

local function syncLegacyDebugFields()
    local runtime = type(NMRuntimeConfig) == "table" and NMRuntimeConfig or nil
    NMCore.DebugChannels = NMCore.DebugChannels or {}
    local names = runtime and runtime.getSubsystemDebugNames and runtime.getSubsystemDebugNames() or {}
    local anyEnabled = false
    for i = 1, #names do
        local key = tostring(names[i])
        local enabled = runtime and runtime.isSubsystemDebugEnabled and runtime.isSubsystemDebugEnabled(key) == true or false
        NMCore.DebugChannels[key] = enabled
        if enabled then
            anyEnabled = true
        end
    end
    NMCore.Debug = anyEnabled
    NMCore.DebugPlayback = runtime and runtime.isSubsystemDebugEnabled and runtime.isSubsystemDebugEnabled("runtime") == true or false
end

syncLegacyDebugFields()

function NMCore.clamp(value, minValue, maxValue)
    if value == nil then
        return minValue
    end
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

function NMCore.itemId(item)
    if not item or not item.getID then
        return nil
    end
    return tostring(item:getID())
end

function NMCore.readDrainableFraction(item, defaultValue)
    if not item then
        return defaultValue
    end
    local value = nil
    if item.getCurrentUsesFloat then
        value = item:getCurrentUsesFloat()
    elseif item.getUsedDelta then
        value = item:getUsedDelta()
    elseif item.getDelta then
        value = item:getDelta()
    end
    value = tonumber(value)
    if value == nil then
        return defaultValue
    end
    return NMCore.clamp(value, 0.0, 1.0)
end

function NMCore.isSubsystemDebugEnabled(name)
    local key = resolveSubsystemName(name)
    if not key then
        return false
    end
    local runtime = type(NMRuntimeConfig) == "table" and NMRuntimeConfig or nil
    if runtime and runtime.isSubsystemDebugEnabled then
        return runtime.isSubsystemDebugEnabled(key) == true
    end
    return false
end

function NMCore.setSubsystemDebugEnabled(name, enabled)
    local key = resolveSubsystemName(name)
    if not key then
        return false
    end
    local runtime = type(NMRuntimeConfig) == "table" and NMRuntimeConfig or nil
    if runtime and runtime.setSubsystemDebugEnabled then
        local ok = runtime.setSubsystemDebugEnabled(key, toBool(enabled))
        syncLegacyDebugFields()
        debugPrint("setSubsystemDebugEnabled subsystem=" .. tostring(key) .. " enabled=" .. tostring(NMCore.isSubsystemDebugEnabled(key)))
        return ok == true
    end
    debugPrint("setSubsystemDebugEnabled failed subsystem=" .. tostring(key) .. " runtime_missing")
    return false
end

function NMCore.getSubsystemDebugSnapshot()
    local runtime = type(NMRuntimeConfig) == "table" and NMRuntimeConfig or nil
    if runtime and runtime.getSubsystemDebugSnapshot then
        return runtime.getSubsystemDebugSnapshot()
    end
    return {}
end

function NMCore.getSubsystemDebugNames()
    local runtime = type(NMRuntimeConfig) == "table" and NMRuntimeConfig or nil
    if runtime and runtime.getSubsystemDebugNames then
        return runtime.getSubsystemDebugNames()
    end
    return {}
end

function NMCore.dumpDebugState()
    local names = NMCore.getSubsystemDebugNames()
    local parts = {}
    for i = 1, #names do
        local key = tostring(names[i])
        parts[#parts + 1] = key .. "=" .. tostring(NMCore.isSubsystemDebugEnabled(key))
    end
    debugPrint("state subsystems={" .. table.concat(parts, ",") .. "}")
end

function NMCore.isDebugChannelEnabled(channel)
    return NMCore.isSubsystemDebugEnabled(channel)
end

function NMCore.shouldLogEvery(key, nowValue, interval)
    if key == nil then
        return true
    end
    local now = tonumber(nowValue) or 0
    local step = math.max(1, tonumber(interval) or 1)
    local last = tonumber(NMCore.DebugThrottle[key])
    if last ~= nil and (now - last) < step then
        return false
    end
    NMCore.DebugThrottle[key] = now
    return true
end

function NMCore.log(msg, detail)
    if not NMCore.isSubsystemDebugEnabled("state") then
        return
    end
    local line = tostring(msg)
    if detail ~= nil then
        line = line .. " " .. tostring(detail)
    end
    print("[NewMusic] [CoreProbe] " .. line)
end

function NMCore.logChannel(channel, msg, detail)
    if not NMCore.isSubsystemDebugEnabled(channel) then
        return
    end
    local line = tostring(msg)
    if detail ~= nil then
        line = line .. " " .. tostring(detail)
    end
    local section = mapLogSection(channel)
    print("[NewMusic] [" .. tostring(section) .. "] " .. line)
end

function NMCore.getPublicBuildVersion()
    return derivePublicBuildVersion()
end

function NMCore.logBuildVersionLine(side)
    local key = tostring(side or "unknown")
    if NMCore.BuildVersionLineBySide[key] == true then
        return
    end
    NMCore.BuildVersionLineBySide[key] = true
    print(string.format(
        "[New Music] [%s] side=%s",
        tostring(NMCore.getPublicBuildVersion()),
        key
    ))
end

local function trimString(v)
    local s = tostring(v or "")
    s = s:gsub("^%s+", "")
    s = s:gsub("%s+$", "")
    return s
end

function NMCore.getVehicleRebindTraceUUID()
    local runtime = type(NMRuntimeConfig) == "table" and NMRuntimeConfig or nil
    if not (runtime and runtime.get) then
        return ""
    end
    return trimString(runtime.get("vehicleRebindTraceUUID", ""))
end

function NMCore.isVehicleRebindTraceEnabled(uuid)
    if not NMCore.isSubsystemDebugEnabled("vehicle") then
        return false
    end
    local filterUuid = NMCore.getVehicleRebindTraceUUID()
    if filterUuid == "" then
        return true
    end
    return trimString(uuid) == filterUuid
end

function NMCore.logVehicleRebindTrace(tag, uuid, detail)
    if not NMCore.isVehicleRebindTraceEnabled(uuid) then
        return
    end
    local line = "uuid=" .. tostring(uuid or "")
    if detail ~= nil and tostring(detail) ~= "" then
        line = line .. " " .. tostring(detail)
    end
    NMCore.logChannel("vehicle", tostring(tag or "trace"), line)
end

function NMCore.getRuntimeAuthorityMode()
    local world = getWorld and getWorld() or nil
    local mode = world and world.getGameMode and tostring(world:getGameMode() or "") or ""
    local isSrv = isServer and isServer() or false
    local isCli = isClient and isClient() or false
    if mode == "Multiplayer" then
        if isSrv then
            return "mp_server_host"
        end
        if isCli then
            return "mp_client"
        end
        return "mp_unknown"
    end
    return "sp_local"
end

function NMCore.isMultiplayerMode()
    local world = getWorld and getWorld() or nil
    local mode = world and world.getGameMode and tostring(world:getGameMode() or "") or ""
    return mode == "Multiplayer"
end

function NMCore.isMPServerAuthority()
    return NMCore.isMultiplayerMode() and (isServer and isServer() or false)
end

function NMCore.isMPClientRuntime()
    return NMCore.isMultiplayerMode() and (isClient and isClient() or false)
end

return NMCore
