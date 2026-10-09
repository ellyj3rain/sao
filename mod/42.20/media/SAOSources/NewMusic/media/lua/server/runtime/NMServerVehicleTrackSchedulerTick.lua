-- Host shell for the shared world-authoritative track progression runtime.
if type(NMServerWorldTrackRuntime) ~= "table" then
    NMServerWorldTrackRuntime = NMServerWorldTrackRuntime or {}
end

NMServerVehicleTrackSchedulerTick = NMServerVehicleTrackSchedulerTick or {}
NMServerVehicleTrackSchedulerTick._schedulerStateSig = NMServerVehicleTrackSchedulerTick._schedulerStateSig or {}
NMServerVehicleTrackSchedulerTick._dueWriteSig = NMServerVehicleTrackSchedulerTick._dueWriteSig or {}
NMServerVehicleTrackSchedulerTick._dueWriteBlockedSig = NMServerVehicleTrackSchedulerTick._dueWriteBlockedSig or {}
NMServerVehicleTrackSchedulerTick._lastAdvanceTickMs = NMServerVehicleTrackSchedulerTick._lastAdvanceTickMs or {}
NMServerVehicleTrackSchedulerTick._durationProbeSig = NMServerVehicleTrackSchedulerTick._durationProbeSig or {}
NMServerVehicleTrackSchedulerTick._dueTransitionProbeSig = NMServerVehicleTrackSchedulerTick._dueTransitionProbeSig or {}
NMServerVehicleTrackSchedulerTick._timelineRepairSig = NMServerVehicleTrackSchedulerTick._timelineRepairSig or {}
NMServerVehicleTrackSchedulerTick._unknownOpenDueBlockedSig = NMServerVehicleTrackSchedulerTick._unknownOpenDueBlockedSig or {}
NMServerVehicleTrackSchedulerTick._unknownOpenStallHeartbeatMs = NMServerVehicleTrackSchedulerTick._unknownOpenStallHeartbeatMs or {}

local TRACK_DEADLINE_TICK_MS = 50
local UNKNOWN_OPEN_CHECK_TICKS = 120

local function logRuntimeProbe(tag, detail)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("playback_progression")) then
        return
    end
    NMCore.logChannel("playback_progression", tostring(tag or "tag"), tostring(detail or ""))
end

local function nowRealMs()
    if getTimestampMs then
        local ms = tonumber(getTimestampMs())
        if ms then return ms end
    end
    if getTimestamp then
        local ts = tonumber(getTimestamp())
        if ts then return ts * 1000 end
    end
    return 0
end

local function resolveTrackCountFromMedia(state)
    if not state or not state.mediaFullType or not NMMusic or not NMMusic.resolveTracks then
        return 0
    end
    local ok, resolved = pcall(NMMusic.resolveTracks, state.mediaFullType)
    if not ok or type(resolved) ~= "table" or type(resolved.tracks) ~= "table" then
        return 0
    end
    return #resolved.tracks
end

local function resolveTrackCount(state, entry)
    local fromState = tonumber(state and state.trackCount) or 0
    if fromState > 0 then
        return math.max(1, math.floor(fromState))
    end
    local fromEntry = tonumber(entry and entry.trackCount) or 0
    if fromEntry > 0 then
        return math.max(1, math.floor(fromEntry))
    end
    return resolveTrackCountFromMedia(state)
end

local function resolveCurrentTrackDurationMs(state)
    local fallbackMs = tonumber(NMRuntimeConfig and NMRuntimeConfig.getServerVehicleTrackDurationMs and NMRuntimeConfig.getServerVehicleTrackDurationMs()
        or NMRuntimeConfig and NMRuntimeConfig.get and NMRuntimeConfig.get("serverVehicleTrackDurationMs", 210000)
        or 210000) or 210000
    local resolvedDuration = NMServerTrackTimeline.resolveProgressionInfo(state, "world")
    local row = resolvedDuration and resolvedDuration.row or nil

    local probeKey = table.concat({
        tostring(state and state.mediaFullType or "nil"),
        tostring(resolvedDuration and resolvedDuration.trackIndex or tonumber(state and state.trackIndex) or 1),
        tostring(row and row.authoredDurationMs or nil),
        tostring(row and row.authoredDurationSeconds or nil),
        tostring(row and row.authoredLengthSeconds or nil),
        tostring(row and row.authoredDuration or nil),
        tostring(row and row.durationMs or nil),
        tostring(row and row.durationSeconds or nil),
        tostring(row and row.lengthSeconds or nil),
        tostring(row and row.duration or nil),
        tostring(resolvedDuration and resolvedDuration.knownDuration == true),
        tostring(resolvedDuration and resolvedDuration.timingMode or ""),
        tostring(resolvedDuration and resolvedDuration.source or "fallback")
    }, "|")
    if tostring(NMServerVehicleTrackSchedulerTick._durationProbeSig[probeKey] or "") ~= probeKey then
        NMServerVehicleTrackSchedulerTick._durationProbeSig[probeKey] = probeKey
        logRuntimeProbe(
            "server_track_duration_probe",
            string.format(
                "media=%s idx=%s authoredDurationMs=%s authoredDurationSeconds=%s authoredLengthSeconds=%s authoredDuration=%s playlistDurationMs=%s playlistDurationSeconds=%s playlistLengthSeconds=%s playlistDuration=%s fallbackMs=%s known=%s timingMode=%s source=%s resolvedMs=%s",
                tostring(state and state.mediaFullType or "nil"),
                tostring(resolvedDuration and resolvedDuration.trackIndex or tonumber(state and state.trackIndex) or 1),
                tostring(row and row.authoredDurationMs or nil),
                tostring(row and row.authoredDurationSeconds or nil),
                tostring(row and row.authoredLengthSeconds or nil),
                tostring(row and row.authoredDuration or nil),
                tostring(row and row.durationMs or nil),
                tostring(row and row.durationSeconds or nil),
                tostring(row and row.lengthSeconds or nil),
                tostring(row and row.duration or nil),
                tostring(math.max(1000, math.floor(fallbackMs + 0.5))),
                tostring(resolvedDuration and resolvedDuration.knownDuration == true),
                tostring(resolvedDuration and resolvedDuration.timingMode or ""),
                tostring(resolvedDuration and resolvedDuration.source or "fallback"),
                tostring(resolvedDuration and resolvedDuration.durationMs or nil)
            )
        )
    end
    return resolvedDuration and resolvedDuration.durationMs or math.max(1000, math.floor(fallbackMs + 0.5))
end

local function resolveCurrentTrackProgressionInfo(state)
    return NMServerTrackTimeline.resolveProgressionInfo(state, "world")
end

local function recipients(applyFn)
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if not players then
        return
    end
    for i = 0, players:size() - 1 do
        local p = players:get(i)
        if p then
            applyFn(p)
        end
    end
end

local function resolveProgressionCause(progression)
    local timingMode = tostring(progression and progression.timingMode or "")
    if timingMode == "unknown_open" then
        return "unknown_open"
    end
    return "metadata_due"
end

local function shouldEmitStateSync(entry, playerObj, state)
    return NMServerSchedulerSyncState.shouldEmitStateSync(entry, playerObj, state)
end

local function syncVehicleStateToClients(entry, state)
    if not (entry and state and sendServerCommand) then
        return
    end
    local sessionToken = NMServerBootReset and NMServerBootReset.getSessionToken and NMServerBootReset.getSessionToken() or nil
    local canonicalSourceGen = math.max(
        tonumber(entry and entry.sourceEpoch) or 0,
        tonumber(entry and entry.sourceGeneration) or 0,
        tonumber(state and state.sourceGeneration) or 0
    )
    recipients(function(playerObj)
        if not shouldEmitStateSync(entry, playerObj, state) then
            return
        end
        sendServerCommand(playerObj, NMCore.NetModule, "state", {
            vehicleId = tostring(entry.vehicleId or ""),
            vehicleIdHint = tostring(entry.vehicleIdHint or entry.vehicleId or ""),
            vehicleSqlId = tostring(entry.vehicleSqlId or ""),
            vehicleSqlIdHint = tostring(entry.vehicleSqlIdHint or entry.vehicleSqlId or ""),
            partId = tostring(entry.partId or "Radio"),
            ownerId = tostring(entry.ownerId or ""),
            sourceMode = tostring(entry.sourceMode or "vehicle"),
            state = NMDeviceState.export(state),
            sourceGeneration = canonicalSourceGen,
            transitionReason = entry.transitionReason ~= nil and tostring(entry.transitionReason) or nil,
            serverSessionToken = sessionToken
        })
    end)
end

local function syncItemStateToClients(entry, state)
    if not (entry and state and sendServerCommand) then
        return
    end
    local sessionToken = NMServerBootReset and NMServerBootReset.getSessionToken and NMServerBootReset.getSessionToken() or nil
    recipients(function(playerObj)
        if not shouldEmitStateSync(entry, playerObj, state) then
            return
        end
        sendServerCommand(playerObj, NMCore.NetModule, "state", {
            itemId = tostring(entry.itemId or ""),
            uuid = tostring(entry.uuid or ""),
            itemFullType = tostring(entry.itemFullType or ""),
            sourceMode = tostring(entry.sourceMode or "placed"),
            state = NMDeviceState.export(state),
            sourceGeneration = math.max(
                tonumber(entry.sourceEpoch) or 0,
                tonumber(entry.sourceGeneration) or 0,
                tonumber(state.sourceGeneration) or 0
            ),
            transitionReason = entry.transitionReason ~= nil and tostring(entry.transitionReason) or nil,
            serverSessionToken = sessionToken
        })
    end)
end

local function isWorldAuthoritativeEntry(entry, state)
    if type(entry) ~= "table" or type(state) ~= "table" then
        return false
    end
    if state.isOn ~= true or state.isPlaying ~= true then
        return false
    end
    local mode = tostring(state.authoritativeMode or "")
    if tostring(entry.kind or "") == "vehicle" then
        return mode == "vehicle"
    end
    if tostring(entry.kind or "") == "item" then
        return mode == "placed" or mode == "stowed" or mode == "attached"
    end
    return false
end

local function resolveProfileForEntry(entry)
    if tostring(entry and entry.kind or "") == "vehicle" then
        return NMDeviceProfiles and (
            (NMDeviceProfiles.getForFullType and NMDeviceProfiles.getForFullType("vehicle_radio"))
            or NMDeviceProfiles.VehicleRadioProfile
        ) or nil
    end
    local fullType = tostring(entry and (entry.profileType or entry.itemFullType) or "")
    if fullType ~= "" and NMDeviceProfiles and NMDeviceProfiles.getForFullType then
        return NMDeviceProfiles.getForFullType(fullType)
    end
    return nil
end

local function isOwnerOnlineForAttached(entry, state)
    if tostring(entry and entry.kind or "") ~= "item" then
        return true
    end
    if tostring(state and state.authoritativeMode or entry and entry.sourceMode or "") ~= "attached" then
        return true
    end
    local owner = tostring(state and state.sourceOwner or entry and entry.ownerOnlineId or entry and entry.ownerUsername or entry and entry.ownerId or "")
    if owner == "" then
        return false
    end
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if not players then
        return false
    end
    local ownerLower = string.lower(owner)
    for i = 0, players:size() - 1 do
        local p = players:get(i)
        if p then
            local onlineId = p.getOnlineID and tostring(p:getOnlineID() or "") or ""
            local username = p.getUsername and tostring(p:getUsername() or "") or ""
            if owner == onlineId or owner == username or ownerLower == string.lower(username) then
                return true
            end
        end
    end
    return false
end

local applyRestartResume
local clearServerTrackTimeline

local function bumpAndSyncAuthoritativeState(entry, state)
    NMDeviceState.bumpRevision(state)
    local nextGen = math.max(
        tonumber(state.sourceGeneration) or 0,
        tonumber(entry.sourceEpoch) or 0,
        tonumber(entry.sourceGeneration) or 0
    ) + 1
    state.sourceGeneration = nextGen
    entry.sourceEpoch = nextGen
    entry.sourceGeneration = nextGen
    entry.stateSnapshot = NMDeviceState.export(state)
    NMServerRegistryBroadcast.broadcastEntry(
        NMServerRegistryState.worldRegistry,
        tostring(entry.uuid),
        nil,
        entry.stateSnapshot,
        "upsert",
        recipients
    )
    if tostring(entry.kind or "") == "vehicle" then
        syncVehicleStateToClients(entry, state)
    else
        syncItemStateToClients(entry, state)
    end
end

local function handleAttachedOwnerPresence(entry, state, nowMsValue)
    if tostring(entry and entry.kind or "") ~= "item" then
        return false
    end
    if tostring(state and state.authoritativeMode or entry and entry.sourceMode or "") ~= "attached" then
        entry._attachedOwnerPaused = false
        entry._attachedOwnerPausedResume = false
        entry._offlineRestartPending = nil
        entry._offlineRestartToken = nil
        entry._offlineRestartResumeSig = nil
        return false
    end

    local ownerOnline = isOwnerOnlineForAttached(entry, state)
    if not ownerOnline then
        if entry._attachedOwnerPaused ~= true then
            entry._attachedOwnerPaused = true
            entry._attachedOwnerPausedResume = (state.isOn == true and state.isPlaying == true)
            entry._offlineRestartPending = entry._attachedOwnerPausedResume == true
            entry._offlineRestartToken = string.format(
                "%s:%s",
                tostring(tonumber(state.playbackEpoch) or 0),
                tostring(tonumber(state.trackIndex) or 0)
            )
            if entry._attachedOwnerPausedResume == true then
                local changed = NMServerCanonicalReducer
                    and NMServerCanonicalReducer.dispatch
                    and NMServerCanonicalReducer.dispatch({
                        eventType = NMServerCanonicalReducer.Event and NMServerCanonicalReducer.Event.OWNER_OFFLINE_PAUSE or "OWNER_OFFLINE_PAUSE",
                        state = state
                    }) == true
                if changed then
                    clearServerTrackTimeline(entry, state)
                    entry._batteryDrainSkipUntilResume = true
                    if NMServerItemPowerTick and NMServerItemPowerTick.lastDrainMs then
                        NMServerItemPowerTick.lastDrainMs[tostring(entry.uuid or "")] = nowMsValue
                    end
                    if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
                        NMCore.logChannel(
                            "runtime",
                            "attached_offline_pause_applied",
                            string.format(
                                "uuid=%s restartPending=true playbackEpoch=%s trackIndex=%s",
                                tostring(entry.uuid or ""),
                                tostring(tonumber(state.playbackEpoch) or 0),
                                tostring(tonumber(state.trackIndex) or 0)
                            )
                        )
                    end
                    bumpAndSyncAuthoritativeState(entry, state)
                end
            end
        end
        return true
    end

    if entry._attachedOwnerPaused == true then
        local hasBattery = state.batteryPresent ~= true or (tonumber(state.batteryCharge) or 0) > 0
        local shouldResume = entry._offlineRestartPending == true and state.isOn == true and hasBattery
        if shouldResume then
            local resumeSig = string.format(
                "%s|%s|%s",
                tostring(entry._offlineRestartToken or ""),
                tostring(tonumber(state.sourceGeneration) or 0),
                tostring(tonumber(state.revision) or 0)
            )
            if tostring(entry._offlineRestartResumeSig or "") == resumeSig then
                entry._attachedOwnerPaused = false
                entry._attachedOwnerPausedResume = false
                entry._offlineRestartPending = nil
                entry._offlineRestartToken = nil
                entry._batteryDrainSkipUntilResume = nil
                return false
            end
            local changed = NMServerCanonicalReducer
                and NMServerCanonicalReducer.dispatch
                and NMServerCanonicalReducer.dispatch({
                    eventType = NMServerCanonicalReducer.Event and NMServerCanonicalReducer.Event.OWNER_ONLINE_RESUME or "OWNER_ONLINE_RESUME",
                    state = state,
                    nowMs = nowMsValue
                }) == true
            if changed then
                entry._batteryDrainSkipUntilResume = nil
                local timingMode, newDueAtMs = applyRestartResume(entry, state, nowMsValue, "restart_attached_owner_online")
                if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
                    NMCore.logChannel(
                        "runtime",
                        "attached_offline_resume_applied",
                        string.format(
                            "uuid=%s restart=true timingMode=%s dueAtMs=%s playbackEpoch=%s trackIndex=%s",
                            tostring(entry.uuid or ""),
                            tostring(timingMode),
                            tostring(math.floor(newDueAtMs)),
                            tostring(tonumber(state.playbackEpoch) or 0),
                            tostring(tonumber(state.trackIndex) or 0)
                        )
                    )
                end
                entry._offlineRestartResumeSig = resumeSig
            end
        end
        entry._attachedOwnerPaused = false
        entry._attachedOwnerPausedResume = false
        entry._offlineRestartPending = nil
        entry._offlineRestartToken = nil
        entry._batteryDrainSkipUntilResume = nil
    end
    return false
end

local function hasRegistryEntries()
    local worldRegistry = NMServerRegistryState and NMServerRegistryState.worldRegistry or nil
    if type(worldRegistry) ~= "table" then
        return false
    end
    for _ in pairs(worldRegistry) do
        return true
    end
    return false
end

function NMServerVehicleTrackSchedulerTick.hasWorldSources()
    return hasRegistryEntries()
end

local function msDeadlineToSchedulerTick(dueAtMs, nowMsValue, currentTick)
    local dueMs = tonumber(dueAtMs) or 0
    local nowMsNumber = tonumber(nowMsValue) or 0
    local tick = tonumber(currentTick) or 0
    if dueMs <= 0 then
        return math.huge
    end
    if nowMsNumber <= 0 or dueMs <= nowMsNumber then
        return tick
    end
    local msPerTick = math.max(1, tonumber(TRACK_DEADLINE_TICK_MS) or 50)
    local deltaTicks = math.max(1, math.ceil((dueMs - nowMsNumber) / msPerTick))
    return tick + deltaTicks
end

local function resolveEntryNextTrackCheckTick(entry, state, currentTick, nowMsValue)
    local tick = tonumber(currentTick) or 0
    if type(entry) ~= "table" or type(state) ~= "table" then
        return math.huge
    end
    if isWorldAuthoritativeEntry(entry, state) ~= true then
        return math.huge
    end
    local dueAtMs = tonumber(state.serverTrackDueAtMs)
        or tonumber(entry.serverTrackDueAtMs)
        or tonumber(entry._serverTrackNextTransitionAtMs)
        or 0
    if dueAtMs > 0 then
        return msDeadlineToSchedulerTick(dueAtMs, nowMsValue, tick)
    end
    local startedAtMs = tonumber(state.serverTrackStartedAtMs)
        or tonumber(entry.serverTrackStartedAtMs)
        or tonumber(entry._serverTrackStartedAtMs)
        or 0
    local timingMode = tostring(state.serverTrackTimingMode or entry.serverTrackTimingMode or "")
    if timingMode == "unknown_open" or startedAtMs > 0 then
        return tick + UNKNOWN_OPEN_CHECK_TICKS
    end
    return tick
end

function NMServerVehicleTrackSchedulerTick.getNextActiveWorkCheckTick(currentTick)
    local worldRegistry = NMServerRegistryState and NMServerRegistryState.worldRegistry or nil
    if type(worldRegistry) ~= "table" then
        return math.huge
    end
    local tick = tonumber(currentTick) or 0
    local nowMsValue = nowRealMs()
    local nextTick = math.huge
    for _, entry in pairs(worldRegistry) do
        local state = entry and entry.stateSnapshot or nil
        local entryNextTick = resolveEntryNextTrackCheckTick(entry, state, tick, nowMsValue)
        if entryNextTick < nextTick then
            nextTick = entryNextTick
        end
    end
    return nextTick
end

function NMServerVehicleTrackSchedulerTick.hasImmediateWork(currentTick)
    local nextTick = tonumber(NMServerVehicleTrackSchedulerTick.getNextActiveWorkCheckTick(currentTick))
    return nextTick ~= nil and nextTick <= (tonumber(currentTick) or 0)
end

local function publishEntryState(entry, state)
    entry.stateSnapshot = NMDeviceState.export(state)
    NMServerRegistryBroadcast.broadcastEntry(
        NMServerRegistryState.worldRegistry,
        tostring(entry.uuid),
        nil,
        entry.stateSnapshot,
        "upsert",
        recipients
    )
    if tostring(entry.kind or "") == "vehicle" then
        syncVehicleStateToClients(entry, state)
    else
        syncItemStateToClients(entry, state)
    end
end

local function describeResolvedState(entry, unresolved)
    local isVehicle = tostring(entry and entry.kind or "") == "vehicle"
    if isVehicle then
        return unresolved and "vehicle_unresolved" or "vehicle_live"
    end
    return "item_world"
end

local function buildWorldRuntimeOptions()
    return {
        stores = {
            dueWriteSig = NMServerVehicleTrackSchedulerTick._dueWriteSig,
            dueWriteBlockedSig = NMServerVehicleTrackSchedulerTick._dueWriteBlockedSig,
            timelineRepairSig = NMServerVehicleTrackSchedulerTick._timelineRepairSig,
            dueTransitionProbeSig = NMServerVehicleTrackSchedulerTick._dueTransitionProbeSig,
            lastAdvanceTickMs = NMServerVehicleTrackSchedulerTick._lastAdvanceTickMs,
            unknownOpenDueBlockedSig = NMServerVehicleTrackSchedulerTick._unknownOpenDueBlockedSig,
            unknownOpenStallHeartbeatMs = NMServerVehicleTrackSchedulerTick._unknownOpenStallHeartbeatMs,
            stalledState = NMServerVehicleTrackSchedulerTick._stalledState
        },
        emitRuntimeProbe = logRuntimeProbe,
        resolveTrackCount = resolveTrackCount,
        resolveCurrentTrackDurationMs = resolveCurrentTrackDurationMs,
        resolveCurrentTrackProgressionInfo = resolveCurrentTrackProgressionInfo,
        resolveProfileForEntry = resolveProfileForEntry,
        resolveProgressionCause = resolveProgressionCause,
        publishEntryState = publishEntryState,
        describeResolvedState = function(entry, state)
            local unresolved = tostring(entry and entry.kind or "") == "vehicle"
                and ((entry._vehicleResolved == false) or (entry._vehicleSourceResolved == false))
                or false
            return describeResolvedState(entry, unresolved)
        end,
        onRestartResume = function(entry, state, nowMsValue)
            if NMServerItemPowerTick and NMServerItemPowerTick.lastDrainMs then
                NMServerItemPowerTick.lastDrainMs[tostring(entry.uuid or "")] = nowMsValue
            end
        end,
        bumpAndSyncAuthoritativeState = bumpAndSyncAuthoritativeState
    }
end

applyRestartResume = function(entry, state, nowMsValue, dueReason)
    return NMServerWorldTrackRuntime.applyRestartResume(entry, state, nowMsValue, dueReason, buildWorldRuntimeOptions())
end

clearServerTrackTimeline = function(entry, state)
    return NMServerWorldTrackRuntime.clearTrackTimeline(entry, state, buildWorldRuntimeOptions())
end

function NMServerVehicleTrackSchedulerTick.onTick()
    if not (NMCore and NMCore.isMPServerAuthority and NMCore.isMPServerAuthority()) then
        return
    end

    local nowMsValue = nowRealMs()
    for uuid, entry in pairs(NMServerRegistryState.worldRegistry) do
        if entry then
            local state = entry.stateSnapshot
            if type(state) == "table" then
                local blockedForAttachedOffline = handleAttachedOwnerPresence(entry, state, nowMsValue)
                if blockedForAttachedOffline then
                    NMServerRegistryState.worldRegistry[uuid] = entry
                    state = entry.stateSnapshot
                end
                local blockedForNoListener = NMServerNoListenerPolicy.handleNoListenerPresence(entry, state, nowMsValue, {
                    resolveProfileForEntry = resolveProfileForEntry,
                    clearServerTrackTimeline = clearServerTrackTimeline,
                    applyRestartResume = applyRestartResume,
                    bumpAndSyncAuthoritativeState = bumpAndSyncAuthoritativeState
                })
                if blockedForNoListener then
                    NMServerRegistryState.worldRegistry[uuid] = entry
                    state = entry.stateSnapshot
                end
            end
            if isWorldAuthoritativeEntry(entry, state) then
                -- Vehicles and world items both flow through the same shared track runtime here.
                if (tonumber(state.trackCount) or 0) < 1 and (tonumber(entry.trackCount) or 0) > 0 then
                    state.trackCount = tonumber(entry.trackCount) or 0
                end
                local epoch = tonumber(state and state.playbackEpoch) or 0
                local trackIndex = tonumber(state and state.trackIndex) or 1
                entry._serverTrackSchedulerSig = tostring(epoch) .. ":" .. tostring(trackIndex)
                local isVehicle = tostring(entry.kind or "") == "vehicle"
                local unresolved = isVehicle and ((entry._vehicleResolved == false) or (entry._vehicleSourceResolved == false)) or false
                local runtimeResult = NMServerWorldTrackRuntime.evaluateActiveEntry(
                    entry,
                    state,
                    nowMsValue,
                    buildWorldRuntimeOptions()
                ) or {}
                local dueAtMs = tonumber(runtimeResult.dueAtMs) or 0
                local timingMode = tostring(runtimeResult.timingMode or "unknown_open")
                local schedulerSig = string.format(
                    "active=true|unresolved=%s|isPlaying=%s|timing=%s|nextAt=%s",
                    tostring(unresolved),
                    tostring(state.isPlaying == true),
                    tostring(timingMode),
                    tostring(math.floor(dueAtMs))
                )
                if tostring(NMServerVehicleTrackSchedulerTick._schedulerStateSig[uuid] or "") ~= schedulerSig then
                    NMServerVehicleTrackSchedulerTick._schedulerStateSig[uuid] = schedulerSig
                    if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("playback_progression") then
                        NMCore.logChannel(
                            "playback_progression",
                            "server_track_scheduler_state",
                            string.format(
                                "uuid=%s unresolved=%s isPlaying=%s nextAtMs=%s",
                                tostring(uuid),
                                tostring(unresolved),
                                tostring(state.isPlaying == true),
                                tostring(math.floor(dueAtMs))
                            )
                        )
                    end
                end
            else
                entry._serverTrackSchedulerSig = nil
                if type(state) == "table" then
                    clearServerTrackTimeline(entry, state)
                else
                    entry._serverTrackDurationMs = nil
                    entry._serverTrackStartedAtMs = nil
                    entry._serverTrackNextTransitionAtMs = nil
                    entry.serverTrackStartedAtMs = nil
                    entry.serverTrackDurationMs = nil
                    entry.serverTrackDueAtMs = nil
                end
                local schedulerSig = "active=false"
                if tostring(NMServerVehicleTrackSchedulerTick._schedulerStateSig[uuid] or "") ~= schedulerSig then
                    NMServerVehicleTrackSchedulerTick._schedulerStateSig[uuid] = schedulerSig
                    if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("playback_progression") then
                        NMCore.logChannel(
                            "playback_progression",
                            "server_track_scheduler_state",
                            string.format(
                                "uuid=%s unresolved=%s isPlaying=%s nextAtMs=%s",
                                tostring(uuid),
                                tostring(tostring(entry.kind or "") == "vehicle" and ((entry._vehicleResolved == false) or (entry._vehicleSourceResolved == false)) or false),
                                tostring(state and state.isPlaying == true),
                                "nil"
                            )
                        )
                    end
                end
            end
        end
    end
end

