-- Canonical client state-apply follow-up ownership for cache refresh, registry rehydrate,
-- vehicle loot refresh, and ui lifecycle invalidation/rebind side effects.
NMClientStateApplyFollowUp = NMClientStateApplyFollowUp or {}

local rehydrateRefreshSeen = rehydrateRefreshSeen or {}
local uiRefreshSigSeen = uiRefreshSigSeen or {}
local uiRefreshMsSeen = uiRefreshMsSeen or {}
local uiRefreshActionSeen = uiRefreshActionSeen or {}

local function buildDisplayTransitionSig(revision, playbackEpoch, trackIndex, mediaFullType)
    return table.concat({
        tostring(tonumber(revision) or 0),
        tostring(tonumber(playbackEpoch) or 0),
        tostring(tonumber(trackIndex) or 0),
        tostring(mediaFullType or "")
    }, "|")
end

local function didDisplayTransitionChange(beforeRevision, beforePlaybackEpoch, beforeTrackIndex, beforeMediaFullType, state)
    local beforeSig = buildDisplayTransitionSig(
        beforeRevision,
        beforePlaybackEpoch,
        beforeTrackIndex,
        beforeMediaFullType
    )
    local afterSig = buildDisplayTransitionSig(
        state and state.revision,
        state and state.playbackEpoch,
        state and state.trackIndex,
        state and state.mediaFullType
    )
    return beforeSig ~= afterSig, beforeSig, afterSig
end

local function shouldAdoptAuthorityVehicleSqlHint(entry, incomingVehicleSqlIdHint, incomingGen, acceptedGen, allowEqualGenIdentityOverwrite)
    local incomingHint = tostring(incomingVehicleSqlIdHint or "")
    if incomingHint == "" then
        return false
    end
    local currentHint = tostring(entry and entry.vehicleSqlIdHint or "")
    local currentSqlId = tostring(entry and entry.vehicleSqlId or "")
    local observedHint = tostring(entry and entry._observedVehicleSqlIdHint or "")
    if currentHint == "" and currentSqlId == "" then
        return true
    end
    if currentHint == incomingHint or currentSqlId == incomingHint then
        return true
    end
    if allowEqualGenIdentityOverwrite or tonumber(incomingGen) > tonumber(acceptedGen) then
        return true
    end
    if observedHint ~= "" and observedHint ~= incomingHint then
        return false
    end
    return false
end

local function nowRealMs()
    if getTimestampMs then
        local ms = tonumber(getTimestampMs())
        if ms then
            return ms
        end
    end
    if getTimestamp then
        local ts = tonumber(getTimestamp())
        if ts then
            return ts * 1000
        end
    end
    return 0
end

local function getLocalPlayer()
    return getPlayer and getPlayer() or getSpecificPlayer and getSpecificPlayer(0) or nil
end

local function inspectUiLifecycleWindows(playerNum)
    if NMDeviceUI and NMDeviceUI.inspectOpenItemWindows then
        return NMDeviceUI.inspectOpenItemWindows(playerNum)
    end
    if NMDeviceUI and NMDeviceUI.inspectOpenPortableWindows then
        return NMDeviceUI.inspectOpenPortableWindows(playerNum)
    end
    return {}
end

local function logUiLifecycleProbe(tag, detail)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("ui_lifecycle")) then
        return
    end
    NMCore.logChannel("ui_lifecycle", tostring(tag or "ui_lifecycle"), tostring(detail or ""))
end

local function uiLifecycleDebugEnabled()
    return NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("ui_lifecycle") == true or false
end

local function logVehicleSlotTrace(stage, detail)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("slot")) then
        return
    end
    NMCore.logChannel("slot", tostring(stage or "vehicle_slot_trace"), tostring(detail or ""))
end

local function logApplyResult(tag, detail)
    NMRuntimeProbeAdapter.emit("runtime", "runtime", tag, detail or "")
end

local function logVehicleRebindTrace(tag, uuid, detail)
    if NMCore and NMCore.logVehicleRebindTrace then
        NMCore.logVehicleRebindTrace(tag, uuid, detail)
    end
end

local function logSqlAnchorLineage(uuid, entry, path, reason)
    if not (NMCore and NMCore.logChannel and NMRuntimeProbeAdapter and NMRuntimeProbeAdapter.isEnabled and NMRuntimeProbeAdapter.isEnabled("runtime", "sql_anchor_lineage")) then
        return
    end
    local state = entry and entry.stateSnapshot or nil
    logApplyResult(
        "sql_anchor_lineage",
        string.format(
            "uuid=%s sourceGen=%s revision=%s playbackEpoch=%s vehicleSqlId=%s vehicleSqlIdHint=%s runtimeVehicleIdHint=%s path=%s reason=%s",
            tostring(uuid or ""),
            tostring(entry and entry.sourceGeneration or 0),
            tostring(state and state.revision or 0),
            tostring(state and state.playbackEpoch or 0),
            tostring(entry and entry.vehicleSqlId or ""),
            tostring(entry and entry.vehicleSqlIdHint or ""),
            tostring(entry and entry.vehicleIdHint or ""),
            tostring(path or "unknown"),
            tostring(reason or "none")
        )
    )
end

local function snapshotsToLine(snaps)
    if type(snaps) ~= "table" or #snaps <= 0 then
        return "none"
    end
    local parts = {}
    for i = 1, #snaps do
        local snap = snaps[i]
        parts[#parts + 1] = string.format(
            "%s[itemId=%s uuid=%s hasRef=%s timed=%s pending=%s awaitInsert=%s awaitEject=%s]",
            tostring(snap.uiFamily or "unknown"),
            tostring(snap.itemId or ""),
            tostring(snap.uuid or ""),
            tostring(snap.hasItemRef == true),
            tostring(snap.mediaTimedAction or ""),
            tostring(snap.pendingMediaFullType or ""),
            tostring(snap.awaitingMediaInsert == true),
            tostring(snap.awaitingMediaEject == true)
        )
    end
    return table.concat(parts, " ")
end

function NMClientStateApplyFollowUp.requestFreshRegistryAfterApply(args, state)
    if not (NMClientRegistrySync and NMClientRegistrySync.requestNow and args and state) then
        return
    end
    local session = tostring(args.serverSessionToken or "")
    if session == "" then
        return
    end
    local uuid = tostring(args.uuid or state.deviceUUID or "")
    if uuid == "" then
        return
    end
    local sourceMode = tostring(args.sourceMode or "")
    if sourceMode ~= "placed" and sourceMode ~= "attached" and sourceMode ~= "stowed" and sourceMode ~= "vehicle" then
        return
    end
    local cacheEntry = NMClientWorldSourceCache and NMClientWorldSourceCache.get and NMClientWorldSourceCache.get(uuid) or nil
    local cacheSession = NMClientWorldSourceCache and NMClientWorldSourceCache.getLastServerSessionToken and NMClientWorldSourceCache.getLastServerSessionToken() or ""
    local incomingGen = tonumber(args.sourceGeneration) or tonumber(args.state and args.state.sourceGeneration) or 0
    local cacheGen = math.max(
        tonumber(cacheEntry and cacheEntry.sourceGeneration) or 0,
        tonumber(cacheEntry and cacheEntry.stateSnapshot and cacheEntry.stateSnapshot.sourceGeneration) or 0
    )
    local missingCache = cacheEntry == nil
    local sessionMismatch = cacheSession ~= "" and cacheSession ~= session
    local generationGap = incomingGen > (cacheGen + 1)
    if not (missingCache or sessionMismatch or generationGap) then
        return
    end
    local sig = table.concat({ session, uuid }, "|")
    local nowMs = nowRealMs()
    local lastMs = tonumber(rehydrateRefreshSeen[sig]) or 0
    if (nowMs - lastMs) < NMRuntimeProbeAdapter.shortHeartbeatMs() then
        return
    end
    rehydrateRefreshSeen[sig] = nowMs
    NMClientRegistrySync.requestNow(getLocalPlayer(), "rehydrate_state_apply")
end

function NMClientStateApplyFollowUp.refreshVehicleLootAfterApply(args)
    if not (args and NMClientVehicleLootRefresh and NMClientVehicleLootRefresh.refreshOpenVehicleLootPages) then
        return
    end
    local action = tostring(args.transitionReason or "")
    if action ~= "insert_media" and action ~= "eject_media" then
        return
    end
    local playerObj = getLocalPlayer()
    if not playerObj then
        return
    end
    NMClientVehicleLootRefresh.refreshOpenVehicleLootPages(playerObj, args.vehicleIdHint or args.vehicleId, {
        slotTraceId = tostring(args.slotTraceId or ""),
        partId = tostring(args.partId or "Radio")
    })
end

function NMClientStateApplyFollowUp.onVehicleLootStaleReject(args)
    if not args then
        return
    end
    local playerObj = getLocalPlayer()
    if NMClientVehicleLootRefresh and NMClientVehicleLootRefresh.rememberVehicleLootStaleReject then
        NMClientVehicleLootRefresh.rememberVehicleLootStaleReject(args)
    end
    logVehicleSlotTrace(
        "vehicle_loot_authoritative_stale_reject",
        string.format(
            "trace=%s vehicleId=%s partId=%s sourcePartId=%s mediaItemId=%s mediaItemUuid=%s containerType=%s result=reject reason=%s",
            tostring(args.slotTraceId or ""),
            tostring(args.vehicleId or ""),
            tostring(args.partId or ""),
            tostring(args.sourcePartId or ""),
            tostring(args.mediaItemId or ""),
            tostring(args.mediaItemUuid or ""),
            tostring(args.containerType or ""),
            tostring(args.reason or "source_item_missing")
        )
    )
    if playerObj and NMClientVehicleLootRefresh and NMClientVehicleLootRefresh.refreshOpenVehicleLootPages then
        NMClientVehicleLootRefresh.refreshOpenVehicleLootPages(playerObj, args.vehicleId, {
            slotTraceId = tostring(args.slotTraceId or ""),
            partId = tostring(args.partId or "Radio"),
            sourcePartId = tostring(args.sourcePartId or "")
        })
    end
end

function NMClientStateApplyFollowUp.updateVehicleCacheFromAuthority(args, state)
    if not (NMClientWorldSourceCache and state) then
        return
    end
    local uuid = tostring(state.deviceUUID or args and args.uuid or "")
    if uuid == "" then
        return
    end
    local incomingGen = tonumber(args and args.sourceGeneration) or tonumber(state.sourceGeneration) or 0
    local rebindReason = args and args.rebindReason ~= nil and tostring(args.rebindReason or "") or ""
    local allowEqualGenIdentityOverwrite = rebindReason ~= ""
    local entry = NMClientWorldSourceCache.get and NMClientWorldSourceCache.get(uuid) or nil
    if not entry then
        return
    end
    local acceptedGen = math.max(
        tonumber(entry._acceptedSourceGeneration) or 0,
        tonumber(entry.sourceEpoch) or 0
    )
    if incomingGen < acceptedGen then
        return
    end

    local incomingVehicleId = tostring(args and args.vehicleId or "")
    local incomingVehicleIdHint = tostring(args and args.vehicleIdHint or incomingVehicleId or "")
    local incomingVehicleSqlId = tostring(args and args.vehicleSqlId or "")
    local incomingVehicleSqlIdHint = tostring(args and args.vehicleSqlIdHint or incomingVehicleSqlId or "")
    local incomingOwnerId = tostring(args and args.ownerId or "")
    local currentVehicleId = tostring(entry.vehicleId or "")
    local priorAuthorityVehicleIdHint = tostring(entry._authorityVehicleIdHint or "")
    local priorAuthorityVehicleSqlIdHint = tostring(entry._authorityVehicleSqlIdHint or "")
    local isResolvedLocally = entry._vehicleSourceResolved == true
        or (entry.source and (entry.source._vehicleResolved == true or entry.source.vehicleResolved == true))
    if incomingGen == acceptedGen
        and isResolvedLocally
        and incomingVehicleId ~= ""
        and currentVehicleId ~= ""
        and incomingVehicleId ~= currentVehicleId
        and (not allowEqualGenIdentityOverwrite) then
        logVehicleRebindTrace(
            "authority_equal_gen_identity_guard",
            uuid,
            string.format(
                "incomingVehicleId=%s cachedVehicleId=%s sourceGen=%s action=ignore_equal_generation_overwrite",
                tostring(incomingVehicleId),
                tostring(currentVehicleId),
                tostring(incomingGen)
            )
        )
        return
    end

    entry._acceptedSourceGeneration = math.max(acceptedGen, incomingGen)
    entry.sourceEpoch = math.max(tonumber(entry.sourceEpoch) or 0, incomingGen)
    entry.sourceGeneration = math.max(tonumber(entry.sourceGeneration) or 0, incomingGen)
    if incomingVehicleIdHint ~= "" then
        entry._authorityVehicleIdHint = incomingVehicleIdHint
    end
    if incomingVehicleSqlIdHint ~= "" then
        entry._authorityVehicleSqlIdHint = incomingVehicleSqlIdHint
    end
    if incomingOwnerId ~= "" then
        entry._authorityOwnerIdHint = incomingOwnerId
        entry.ownerId = incomingOwnerId
    end
    if incomingVehicleIdHint ~= "" then
        entry.vehicleIdHint = incomingVehicleIdHint
    end
    local adoptAuthorityVehicleSql = shouldAdoptAuthorityVehicleSqlHint(
        entry,
        incomingVehicleSqlIdHint,
        incomingGen,
        acceptedGen,
        allowEqualGenIdentityOverwrite
    )
    if adoptAuthorityVehicleSql then
        entry.vehicleSqlIdHint = incomingVehicleSqlIdHint
        if tostring(entry.vehicleSqlId or "") == "" then
            entry.vehicleSqlId = incomingVehicleSqlIdHint
        end
    end
    entry._authorityPartIdHint = tostring(args and args.partId or entry.partId or "Radio")
    entry.rebindReason = rebindReason ~= "" and rebindReason or nil
    entry.source = entry.source or {}
    entry.source.mode = "world"
    entry.source.context = "vehicle"
    entry.source.ownerId = incomingOwnerId ~= "" and incomingOwnerId or tostring(entry.source.ownerId or entry.ownerId or "")
    if incomingVehicleIdHint ~= "" then
        entry.source.vehicleIdHint = incomingVehicleIdHint
    end
    if adoptAuthorityVehicleSql then
        entry.source.vehicleSqlIdHint = incomingVehicleSqlIdHint
    end
    if (entry.source.vehicleId == nil or tostring(entry.source.vehicleId or "") == "") and incomingVehicleIdHint ~= "" then
        entry.source.vehicleId = incomingVehicleIdHint ~= "" and incomingVehicleIdHint or incomingVehicleId or entry.vehicleId
    end
    if (entry.source.vehicleSqlId == nil or tostring(entry.source.vehicleSqlId or "") == "") and adoptAuthorityVehicleSql then
        entry.source.vehicleSqlId = incomingVehicleSqlIdHint ~= "" and incomingVehicleSqlIdHint or incomingVehicleSqlId or entry.vehicleSqlId
    end
    local authorityVehicleChanged = (
        (incomingVehicleIdHint ~= "" and incomingVehicleIdHint ~= priorAuthorityVehicleIdHint)
        or (incomingVehicleSqlIdHint ~= "" and incomingVehicleSqlIdHint ~= priorAuthorityVehicleSqlIdHint)
        or rebindReason ~= ""
    )
    if authorityVehicleChanged then
        entry.source._vehicleResolved = false
        entry.source.vehicleResolved = false
    end
    NMClientWorldSourceCache.entries[uuid] = entry
    logSqlAnchorLineage(uuid, entry, "client_state_apply_cache_update", "authoritative_apply")
end

function NMClientStateApplyFollowUp.refreshVehicleWindowAfterApply(apply)
    local context = type(apply) == "table" and apply or nil
    if not (context and context.state and NMDeviceUI and NMDeviceUI.invalidateOpenVehicleWindow) then
        return false
    end
    local vehicleId = tostring(context.vehicleIdHint or context.vehicleId or "")
    local partId = tostring(context.partId or "Radio")
    if vehicleId == "" then
        return false
    end
    local state = context.state
    local beforeRevision = tonumber(context.beforeRevision) or 0
    local beforePlaybackEpoch = tonumber(context.beforePlaybackEpoch) or 0
    local beforeTrackIndex = tonumber(context.beforeTrackIndex) or 0
    local beforeMediaFullType = tostring(context.beforeMediaFullType or "")
    local changed = didDisplayTransitionChange(
        beforeRevision,
        beforePlaybackEpoch,
        beforeTrackIndex,
        beforeMediaFullType,
        state
    )
    if not changed then
        return false
    end

    local invalidated = NMDeviceUI.invalidateOpenVehicleWindow(vehicleId, partId, tonumber(context.playerNum) or 0) == true
    return invalidated
end

function NMClientStateApplyFollowUp.refreshUiLifecycleItemWindow(apply)
    local context = type(apply) == "table" and apply or nil
    if not context then
        return false, false
    end
    local appliedItemId = tostring(context.itemId or "")
    local appliedUuid = tostring(context.uuid or "")
    local state = context.state
    local beforeMode = tostring(context.beforeMode or "")
    local afterMode = tostring(context.afterMode or "")
    local beforeRevision = tonumber(context.beforeRevision) or 0
    local beforePlaybackEpoch = tonumber(context.beforePlaybackEpoch) or 0
    local beforeTrackIndex = tonumber(context.beforeTrackIndex) or 0
    local beforeMediaFullType = tostring(context.beforeMediaFullType or "")
    local profile = context.profile
    local dormantPortable = context.dormantPortable == true
    local logLifecycleDetail = uiLifecycleDebugEnabled()
    local windowsBefore = logLifecycleDetail and inspectUiLifecycleWindows(0) or nil
    local portableTracked = NMDeviceProfiles
        and NMDeviceProfiles.isPortableTrackedProfile
        and NMDeviceProfiles.isPortableTrackedProfile(profile) == true
    local pickupRebind = portableTracked
        and (afterMode == "attached" or afterMode == "stowed")
        and NMClientPortableDropHandoff
        and NMClientPortableDropHandoff.consumePickupRebind
        and NMClientPortableDropHandoff.consumePickupRebind(appliedUuid) == true
    local uiActionKey = tostring(appliedUuid ~= "" and appliedUuid or appliedItemId)
    local uiActionSig = table.concat({
        tostring(appliedItemId ~= "" and appliedItemId or "nil"),
        tostring(appliedUuid ~= "" and appliedUuid or "nil"),
        buildDisplayTransitionSig(
            state and state.revision,
            state and state.playbackEpoch,
            state and state.trackIndex,
            state and state.mediaFullType
        ),
        tostring(state and state.mediaFullType or "nil"),
        tostring(state and state.isOn == true),
        tostring(state and state.isPlaying == true),
        tostring(state and state.trackIndex or -1),
        tostring(beforeMode),
        tostring(afterMode),
        tostring(dormantPortable)
    }, "|")
    if beforeMode == afterMode and pickupRebind ~= true and uiRefreshActionSeen[uiActionKey] == uiActionSig then
        return false, false
    end
    local displayChanged = false
    displayChanged = didDisplayTransitionChange(
        beforeRevision,
        beforePlaybackEpoch,
        beforeTrackIndex,
        beforeMediaFullType,
        state
    )
    local reboundWindow = false
    local invalidatedWindow = NMDeviceUI
        and NMDeviceUI.invalidateOpenItemWindow
        and NMDeviceUI.invalidateOpenItemWindow(appliedItemId, appliedUuid) == true
        or false
    if portableTracked
        and not dormantPortable
        and (beforeMode == "placed" or pickupRebind)
        and (afterMode == "attached" or afterMode == "stowed") then
        reboundWindow = NMDeviceUI
            and (NMDeviceUI.rebindOpenItemWindow or NMDeviceUI.rebindOpenPortableItemWindow)
            and ((NMDeviceUI.rebindOpenItemWindow and NMDeviceUI.rebindOpenItemWindow(appliedItemId, appliedUuid) == true)
                or (NMDeviceUI.rebindOpenPortableItemWindow and NMDeviceUI.rebindOpenPortableItemWindow(appliedItemId, appliedUuid) == true))
            or false
        if reboundWindow then
            invalidatedWindow = true
        end
        logApplyResult(
            "client_ui_lifecycle_rebind",
            "uuid="
                .. tostring(appliedUuid ~= "" and appliedUuid or "nil")
                .. " fromMode="
                .. tostring(beforeMode)
                .. " toMode="
                .. tostring(afterMode)
                .. " invalidated="
                .. tostring(invalidatedWindow)
                .. " rebound="
                .. tostring(reboundWindow)
        )
    end
    uiRefreshActionSeen[uiActionKey] = uiActionSig
    local uiRefreshSig = table.concat({
        tostring(appliedItemId ~= "" and appliedItemId or "nil"),
        tostring(appliedUuid ~= "" and appliedUuid or "nil"),
        tostring(invalidatedWindow),
        tostring(reboundWindow),
        tostring(state and state.mediaFullType or "nil"),
        tostring(beforeMode),
        tostring(afterMode)
    }, "|")
    if NMRuntimeProbeAdapter and NMRuntimeProbeAdapter.shouldEmitTransitionOrHeartbeat
        and NMRuntimeProbeAdapter.shouldEmitTransitionOrHeartbeat(
            uiRefreshSigSeen,
            uiRefreshMsSeen,
            tostring(appliedUuid ~= "" and appliedUuid or appliedItemId),
            uiRefreshSig,
            NMRuntimeProbeAdapter.longHeartbeatMs()
        ) then
        logApplyResult(
            "client_item_state_ui_refresh",
            string.format(
                "itemId=%s uuid=%s invalidated=%s rebound=%s media=%s fromMode=%s toMode=%s",
                tostring(appliedItemId ~= "" and appliedItemId or "nil"),
                tostring(appliedUuid ~= "" and appliedUuid or "nil"),
                tostring(invalidatedWindow),
                tostring(reboundWindow),
                tostring(state and state.mediaFullType or "nil"),
                tostring(beforeMode),
                tostring(afterMode)
            )
        )
    end
    if logLifecycleDetail then
        local windowsAfter = inspectUiLifecycleWindows(0)
        logUiLifecycleProbe(
            "state_apply_item_refresh",
            string.format(
                "itemId=%s uuid=%s media=%s invalidated=%s rebound=%s displayChanged=%s before=%s after=%s",
                tostring(appliedItemId ~= "" and appliedItemId or "nil"),
                tostring(appliedUuid ~= "" and appliedUuid or "nil"),
                tostring(state and state.mediaFullType or "nil"),
                tostring(invalidatedWindow),
                tostring(reboundWindow),
                tostring(displayChanged),
                snapshotsToLine(windowsBefore),
                snapshotsToLine(windowsAfter)
            )
        )
    end
    return invalidatedWindow, reboundWindow
end

NMClientStateApplyFollowUp.refreshPortableItemWindow = NMClientStateApplyFollowUp.refreshUiLifecycleItemWindow

function NMClientStateApplyFollowUp.invalidateDormantUiLifecycleWindow(itemId, uuid)
    if not (NMDeviceUI and NMDeviceUI.invalidateOpenItemWindow) then
        return false
    end
    local appliedItemId = tostring(itemId or "")
    local appliedUuid = tostring(uuid or "")
    if uiLifecycleDebugEnabled() then
        logUiLifecycleProbe(
            "state_apply_dormant_before",
            string.format(
                "itemId=%s uuid=%s windows=%s",
                tostring(appliedItemId ~= "" and appliedItemId or "nil"),
                tostring(appliedUuid ~= "" and appliedUuid or "nil"),
                tostring(#inspectUiLifecycleWindows(0))
            )
        )
    end
    return NMDeviceUI.invalidateOpenItemWindow(appliedItemId, appliedUuid) == true
end

NMClientStateApplyFollowUp.invalidateDormantPortableWindow = NMClientStateApplyFollowUp.invalidateDormantUiLifecycleWindow
