-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
-- Device state schema defaults, import/export, revision and epoch helpers.
NMDeviceState = NMDeviceState or {}
NMDeviceState._identityWriteBlockedSeen = NMDeviceState._identityWriteBlockedSeen or {}

local mutableIdentityContexts = {
    explicit_init = true,
    migration_tool = true
}

local function generateFallbackUuid(deviceType)
    local now = nil
    if getTimestampMs then
        now = tonumber(getTimestampMs())
    end
    if now == nil and getTimestamp then
        local ts = tonumber(getTimestamp())
        if ts then
            now = ts * 1000
        end
    end
    if now == nil then
        now = 0
    end
    local rand = 0
    if ZombRand then
        rand = ZombRand(0x7fffffff)
    end
    return tostring(deviceType or "dev")
        .. "-" .. tostring(now)
        .. "-" .. string.format("%08x", tonumber(rand) or 0)
end

local function ensureAuthorityState(state)
    local authority = NMAuthorityV4 or NMAuthorityV3
    if authority and authority.ensureState then
        return authority.ensureState(state)
    end
    return state
end

local function hasAnyEntries(tbl)
    if type(tbl) ~= "table" then
        return false
    end
    for _ in pairs(tbl) do
        return true
    end
    return false
end

local function cloneNumericArray(values)
    if type(values) ~= "table" then
        return nil
    end
    local out = {}
    for i = 1, #values do
        local n = tonumber(values[i])
        if not n then
            return nil
        end
        out[i] = math.floor(n)
    end
    return #out > 0 and out or {}
end

local function selectDefaultHeadphoneFullType(deviceUUID, profile)
    if profile and profile.defaultHeadphoneFullType and tostring(profile.defaultHeadphoneFullType) ~= "" then
        return tostring(profile.defaultHeadphoneFullType)
    end
    return "Base.Earbuds"
end

local function clearShuffleState(state)
    if type(state) ~= "table" then
        return
    end
    state.shuffleMediaFullType = nil
    state.shuffleTrackCount = nil
    state.shuffleOrder = nil
    state.shuffleCursor = nil
end

local function resolvesContainerBinding(item)
    if not (item and item.getFullType and NMMediaContract and NMMediaContract.resolveContainerMediaBinding) then
        return false
    end
    local boundMedia = tostring(NMMediaContract.resolveContainerMediaBinding(item:getFullType()) or "")
    return boundMedia ~= ""
end

function NMDeviceState.normalizeMediaState(state, profile, item)
    if type(state) ~= "table" then
        return false
    end

    local changed = false
    local mediaFullType = tostring(state.mediaFullType or "")
    local isMediaContainerOnly = profile and profile.isMediaContainerOnly == true or resolvesContainerBinding(item)

    if mediaFullType == "" then
        if state.mediaDisplayName ~= nil then
            state.mediaDisplayName = nil
            changed = true
        end
        if state.mediaRecordedMediaIndex ~= nil then
            state.mediaRecordedMediaIndex = nil
            changed = true
        end
        if tonumber(state.trackIndex) ~= 1 then
            state.trackIndex = 1
            changed = true
        end
        if state.shuffleMediaFullType ~= nil
            or state.shuffleTrackCount ~= nil
            or state.shuffleOrder ~= nil
            or state.shuffleCursor ~= nil then
            clearShuffleState(state)
            changed = true
        end
        if isMediaContainerOnly ~= true and state.mediaEjectFullType ~= nil then
            state.mediaEjectFullType = nil
            changed = true
        end
    end

    return changed
end

function NMDeviceState.ensure(item, profile)
    if not item or not item.getModData or not profile then
        return nil
    end
    local md = item:getModData()
    md[NMCore.StateKey] = md[NMCore.StateKey] or {}
    local state = md[NMCore.StateKey]

    if state.schemaVersion == nil then state.schemaVersion = NMCore.StateVersion end
    if state.deviceUUID == nil or tostring(state.deviceUUID or "") == "" then
        state.deviceUUID = generateFallbackUuid(profile.deviceType)
    end
    if state.deviceType == nil then state.deviceType = profile.deviceType end
    if state.revision == nil then state.revision = 0 end
    if state.stateVersion == nil then state.stateVersion = 4 end

    if state.isPlaying == nil then state.isPlaying = false end
    if state.desiredIsPlaying == nil then state.desiredIsPlaying = false end
    if state.isOn == nil then state.isOn = false end
    if state.desiredIsOn == nil then state.desiredIsOn = false end
    if state.volume == nil then state.volume = 1.0 end
    if state.trackIndex == nil then state.trackIndex = 1 end
    if state.trackCount == nil then state.trackCount = 0 end

    if state.mediaFullType == nil then state.mediaFullType = nil end
    if state.mediaEjectFullType == nil then state.mediaEjectFullType = nil end
    if state.mediaRecordedMediaIndex == nil then state.mediaRecordedMediaIndex = nil end
    if state.mediaDisplayName == nil then state.mediaDisplayName = nil end
    if state._headphoneSlotInitialized ~= true then
        -- Initialize defaults once for fresh devices only.
        -- Existing progressed saves (revision > 0) keep explicit nil as "empty slot".
        local hasProgress = (tonumber(state.revision) or 0) > 0
        if state.headphoneItemFullType ~= nil or hasProgress then
            state._headphoneSlotInitialized = true
        else
            local defaultHeadphonesEnabled = profile.defaultHeadphonesPresent == true
            if defaultHeadphonesEnabled then
                state.headphoneItemFullType = selectDefaultHeadphoneFullType(state.deviceUUID, profile)
            else
                state.headphoneItemFullType = nil
            end
            state._headphoneSlotInitialized = true
        end
    end

    if state.batteryPresent == nil then
        if profile.defaultBatteryPresent ~= nil then
            state.batteryPresent = profile.defaultBatteryPresent == true
        else
            state.batteryPresent = profile.supportsBattery == true
        end
    end
    if state.batteryCharge == nil then
        if state.batteryPresent then
            state.batteryCharge = NMCore.clamp(tonumber(profile.defaultBatteryCharge) or 1.0, 0.0, 1.0)
        else
            state.batteryCharge = 0.0
        end
    end

    if state.lastStopReason == nil then state.lastStopReason = nil end
    if state.playbackMode == nil then state.playbackMode = profile.defaultPlaybackMode or "inventory" end
    if state.playbackPolicy == nil then state.playbackPolicy = "autoplay" end
    if state.isHold == nil then state.isHold = false end
    if state.shuffleMediaFullType == nil then state.shuffleMediaFullType = nil end
    if state.shuffleTrackCount == nil then state.shuffleTrackCount = nil end
    if state.shuffleOrder == nil then state.shuffleOrder = nil end
    if state.shuffleCursor == nil then state.shuffleCursor = nil end
    if state.playbackEpoch == nil then state.playbackEpoch = 0 end
    if state.zombieDormant == nil then state.zombieDormant = false end
    if state.zombieDormantReason == nil then state.zombieDormantReason = nil end
    if state.zombieDormantStrategy == nil then state.zombieDormantStrategy = nil end
    if state.serverTrackStartedAtMs == nil then state.serverTrackStartedAtMs = nil end
    if state.serverTrackDurationMs == nil then state.serverTrackDurationMs = nil end
    if state.serverTrackDueAtMs == nil then state.serverTrackDueAtMs = nil end
    if state._serverTrackTimingMode == nil then state._serverTrackTimingMode = nil end
    if state._serverTrackArmToken == nil then state._serverTrackArmToken = nil end
    if state.observedTrackDurationHints == nil then state.observedTrackDurationHints = nil end
    if state.isMuted == nil then state.isMuted = false end
    if state.muteReason == nil then state.muteReason = nil end

    if profile.isMediaContainerOnly == true and item and item.getFullType then
        local containerFullType = tostring(item:getFullType() or "")
        local boundMedia = NMMediaContract
            and NMMediaContract.resolveContainerMediaBinding
            and NMMediaContract.resolveContainerMediaBinding(containerFullType)
            or nil
        if boundMedia and boundMedia ~= "" and state.mediaEjectFullType == nil then
            state.mediaEjectFullType = boundMedia
        end
        if boundMedia and boundMedia ~= "" and state.mediaFullType == nil then
            local isLoaded = NMMediaContract
                and NMMediaContract.isContainerLoadedFullType
                and NMMediaContract.isContainerLoadedFullType(containerFullType)
                or false
            if isLoaded then
                state.mediaFullType = boundMedia
                state.mediaEjectFullType = boundMedia
            end
        end
    end

    NMDeviceState.normalizeMediaState(state, profile, item)

    ensureAuthorityState(state)
    return state
end

function NMDeviceState.bumpRevision(state)
    if not state then
        return
    end
    state.revision = (tonumber(state.revision) or 0) + 1
end

function NMDeviceState.bumpPlaybackEpoch(state)
    if not state then
        return
    end
    state.playbackEpoch = (tonumber(state.playbackEpoch) or 0) + 1
end

function NMDeviceState.export(state)
    if not state then
        return nil
    end
    return {
        stateVersion = tonumber(state.stateVersion) or 4,
        schemaVersion = state.schemaVersion,
        deviceUUID = state.deviceUUID,
        deviceType = state.deviceType,
        revision = state.revision,
        playbackEpoch = state.playbackEpoch,
        authoritativeMode = state.authoritativeMode,
        sourceGeneration = state.sourceGeneration,
        sourceKind = state.sourceKind,
        sourceX = state.sourceX,
        sourceY = state.sourceY,
        sourceZ = state.sourceZ,
        sourceOwner = state.sourceOwner,
        isMuted = state.isMuted == true,
        muteReason = tostring(state.muteReason or ""),
        isOn = state.isOn,
        desiredIsOn = state.desiredIsOn,
        isPlaying = state.isPlaying,
        desiredIsPlaying = state.desiredIsPlaying,
        volume = state.volume,
        trackIndex = state.trackIndex,
        trackCount = state.trackCount,
        mediaFullType = state.mediaFullType,
        mediaEjectFullType = state.mediaEjectFullType,
        mediaRecordedMediaIndex = state.mediaRecordedMediaIndex,
        mediaDisplayName = state.mediaDisplayName,
        headphoneItemFullType = state.headphoneItemFullType,
        batteryPresent = state.batteryPresent,
        batteryCharge = state.batteryCharge,
        lastStopReason = state.lastStopReason,
        playbackMode = state.playbackMode,
        playbackPolicy = state.playbackPolicy,
        isHold = state.isHold == true,
        shuffleMediaFullType = state.shuffleMediaFullType,
        shuffleTrackCount = state.shuffleTrackCount,
        shuffleOrder = cloneNumericArray(state.shuffleOrder),
        shuffleCursor = state.shuffleCursor,
        zombieDormant = state.zombieDormant == true,
        zombieDormantReason = state.zombieDormantReason,
        zombieDormantStrategy = state.zombieDormantStrategy,
        serverTrackStartedAtMs = state.serverTrackStartedAtMs,
        serverTrackDurationMs = state.serverTrackDurationMs,
        serverTrackDueAtMs = state.serverTrackDueAtMs,
        _serverTrackTimingMode = state._serverTrackTimingMode,
        _serverTrackArmToken = state._serverTrackArmToken,
        observedTrackDurationHints = state.observedTrackDurationHints
    }
end

function NMDeviceState.peek(item)
    if not item or not item.getModData then
        return nil
    end
    local md = item:getModData()
    if not md then
        return nil
    end
    local state = md[NMCore.StateKey]
    if type(state) ~= "table" then
        return nil
    end
    return state
end

function NMDeviceState.canMutateIdentity(context)
    return mutableIdentityContexts[tostring(context or "")] == true
end

function NMDeviceState.logIdentityWriteBlocked(context, path, detail)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime")) then
        return
    end
    local key = table.concat({
        tostring(context or ""),
        tostring(path or ""),
        tostring(detail or "")
    }, "|")
    if NMDeviceState._identityWriteBlockedSeen[key] == true then
        return
    end
    NMDeviceState._identityWriteBlockedSeen[key] = true
    NMCore.logChannel(
        "runtime",
        "identity_write_blocked",
        string.format("context=%s path=%s detail=%s", tostring(context or ""), tostring(path or ""), tostring(detail or ""))
    )
end

function NMDeviceState.ensureInitialized(item, profile, reason)
    local context = tostring(reason or "explicit_init")
    if not NMDeviceState.canMutateIdentity(context) then
        NMDeviceState.logIdentityWriteBlocked(context, "NMDeviceState.ensureInitialized", "forbidden_context")
        return nil
    end
    return NMDeviceState.ensure(item, profile)
end

function NMDeviceState.import(state, data)
    if not state or not data then
        return
    end
    state.schemaVersion = tonumber(data.schemaVersion) or state.schemaVersion
    state.stateVersion = tonumber(data.stateVersion) or tonumber(state.stateVersion) or 4
    state.deviceUUID = data.deviceUUID or state.deviceUUID
    state.deviceType = data.deviceType or state.deviceType
    state.revision = tonumber(data.revision) or state.revision
    state.playbackEpoch = tonumber(data.playbackEpoch) or state.playbackEpoch
    state.authoritativeMode = data.authoritativeMode or state.authoritativeMode
    state.sourceGeneration = tonumber(data.sourceGeneration) or state.sourceGeneration
    state.sourceKind = data.sourceKind or state.sourceKind
    state.sourceX = tonumber(data.sourceX) or nil
    state.sourceY = tonumber(data.sourceY) or nil
    state.sourceZ = tonumber(data.sourceZ) or nil
    state.sourceOwner = data.sourceOwner

    if data.isMuted ~= nil then
        state.isMuted = data.isMuted == true
    end
    if data.muteReason ~= nil then
        local reason = tostring(data.muteReason or "")
        state.muteReason = reason ~= "" and reason or nil
    end

    state.isOn = data.isOn == true
    state.desiredIsOn = data.desiredIsOn == true
    state.isPlaying = data.isPlaying == true
    state.desiredIsPlaying = data.desiredIsPlaying == true
    state.volume = NMCore.clamp(tonumber(data.volume) or 1.0, 0.0, 1.0)
    state.trackIndex = tonumber(data.trackIndex) or 1
    state.trackCount = math.max(0, math.floor(tonumber(data.trackCount) or tonumber(state.trackCount) or 0))
    state.mediaFullType = data.mediaFullType
    state.mediaEjectFullType = data.mediaEjectFullType
    state.mediaRecordedMediaIndex = data.mediaRecordedMediaIndex
    state.mediaDisplayName = data.mediaDisplayName
    state.headphoneItemFullType = data.headphoneItemFullType
    state._headphoneSlotInitialized = true
    state.batteryPresent = data.batteryPresent == true
    state.batteryCharge = NMCore.clamp(tonumber(data.batteryCharge) or 0.0, 0.0, 1.0)
    state.lastStopReason = data.lastStopReason
    state.playbackMode = data.playbackMode or state.playbackMode
    if data.zombieDormant ~= nil then
        state.zombieDormant = data.zombieDormant == true
    end
    if data.zombieDormantReason ~= nil then
        local dormantReason = tostring(data.zombieDormantReason or "")
        state.zombieDormantReason = dormantReason ~= "" and dormantReason or nil
    end
    if data.zombieDormantStrategy ~= nil then
        local dormantStrategy = tostring(data.zombieDormantStrategy or "")
        state.zombieDormantStrategy = dormantStrategy ~= "" and dormantStrategy or nil
    end

    local policy = tostring(data.playbackPolicy or state.playbackPolicy or "autoplay")
    if policy ~= "autoplay" and policy ~= "loop_album" and policy ~= "loop_song" and policy ~= "shuffle" then
        policy = "autoplay"
    end
    state.playbackPolicy = policy
    if data.isHold ~= nil then
        state.isHold = data.isHold == true
    end
    local shuffleMediaFullType = tostring(data.shuffleMediaFullType or "")
    state.shuffleMediaFullType = shuffleMediaFullType ~= "" and shuffleMediaFullType or nil
    local shuffleTrackCount = tonumber(data.shuffleTrackCount)
    state.shuffleTrackCount = shuffleTrackCount and shuffleTrackCount > 0 and math.floor(shuffleTrackCount) or nil
    state.shuffleOrder = cloneNumericArray(data.shuffleOrder)
    local shuffleCursor = tonumber(data.shuffleCursor)
    state.shuffleCursor = shuffleCursor and shuffleCursor >= 1 and math.floor(shuffleCursor) or nil
    state.serverTrackStartedAtMs = tonumber(data.serverTrackStartedAtMs) or nil
    state.serverTrackDurationMs = tonumber(data.serverTrackDurationMs) or nil
    state.serverTrackDueAtMs = tonumber(data.serverTrackDueAtMs) or nil
    local timingMode = tostring(data._serverTrackTimingMode or "")
    state._serverTrackTimingMode = timingMode ~= "" and timingMode or nil
    local armToken = tostring(data._serverTrackArmToken or "")
    state._serverTrackArmToken = armToken ~= "" and armToken or nil
    if type(data.observedTrackDurationHints) == "table" then
        local clean = {}
        for k, v in pairs(data.observedTrackDurationHints) do
            local idx = tonumber(k)
            local ms = tonumber(v)
            if idx and idx >= 1 and ms and ms > 0 then
                clean[math.floor(idx)] = math.max(1000, math.floor(ms + 0.5))
            end
        end
        state.observedTrackDurationHints = hasAnyEntries(clean) and clean or nil
    end
    NMDeviceState.normalizeMediaState(state, nil, nil)
    ensureAuthorityState(state)
end

function NMDeviceState.isZombieDormant(state)
    return type(state) == "table" and state.zombieDormant == true
end

function NMDeviceState.setZombieDormant(state, dormant, reason, strategy)
    if type(state) ~= "table" then
        return false
    end
    local nextDormant = dormant == true
    local nextReason = nil
    local nextStrategy = nil
    if nextDormant then
        local reasonText = tostring(reason or "")
        local strategyText = tostring(strategy or "")
        nextReason = reasonText ~= "" and reasonText or nil
        nextStrategy = strategyText ~= "" and strategyText or nil
    end
    local changed = state.zombieDormant ~= nextDormant
        or state.zombieDormantReason ~= nextReason
        or state.zombieDormantStrategy ~= nextStrategy
    state.zombieDormant = nextDormant
    state.zombieDormantReason = nextReason
    state.zombieDormantStrategy = nextStrategy
    if nextDormant then
        state.isOn = false
        state.desiredIsOn = false
        state.isPlaying = false
        state.desiredIsPlaying = false
        state.playbackMode = "inventory"
        if nextReason then
            state.lastStopReason = nextReason
        end
    end
    return changed
end



