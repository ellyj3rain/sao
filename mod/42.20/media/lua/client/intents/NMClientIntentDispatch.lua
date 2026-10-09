-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
-- Client intent dispatch for SP-local apply and MP network send.
-- Dependencies are loaded by module bootstrap/order.
if not NMSourceDescriptorSummary then
    pcall(require, "registry/NMSourceDescriptorSummary")
end
if not NMTrackCountResolver then
    pcall(require, "playback_progression/NMTrackCountResolver")
end
if not NMIntentAuthority then
    pcall(require, "intent/NMIntentAuthority")
end
if not NMIntentInventoryOps then
    pcall(require, "intent/NMIntentInventoryOps")
end
if not NMIntentPayloadBuilder then
    pcall(require, "intent/NMIntentPayloadBuilder")
end

NMClientIntentDispatch = NMClientIntentDispatch or {}
NMClientIntentDispatch._corpseAudioSeen = NMClientIntentDispatch._corpseAudioSeen or {}

local function doesActionAdvancePlaybackContinuity(action)
    if NMPlaybackContinuityPolicy and NMPlaybackContinuityPolicy.doesActionAdvancePlaybackContinuity then
        return NMPlaybackContinuityPolicy.doesActionAdvancePlaybackContinuity(action) == true
    end
    local name = tostring(action or "")
    return name == "play"
        or name == "stop"
        or name == "next_track"
        or name == "prev_track"
        or name == "power_on"
        or name == "power_off"
        or name == "track_finished"
        or name == "track_finished_world"
end

local function isCorpseRecoveredItemState(item, state)
    local itemMd = item and item.getModData and item:getModData() or nil
    return (type(state) == "table" and (state._nmCorpseRecovered == true or tostring(state.lastStopReason or "") == "corpse_reconcile"))
        or (type(itemMd) == "table" and itemMd.nmCorpseRecovered == true)
end

local function logCorpseAudio(tag, uuid, detail)
    if not (NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("zombie_corpse")) then
        return
    end
    local key = tostring(uuid or "")
    local sig = tostring(tag or "") .. "|" .. tostring(detail or "")
    local seenKey = key .. "|" .. tostring(tag or "")
    if NMClientIntentDispatch._corpseAudioSeen[seenKey] == sig then
        return
    end
    NMClientIntentDispatch._corpseAudioSeen[seenKey] = sig
    if NMCore and NMCore.logChannel then
        NMCore.logChannel("zombie_corpse", tostring(tag or "corpse_audio"), tostring(detail or ""))
    end
end

local function logSlotAuthority(tag, detail)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("slot")) then
        return
    end
    NMCore.logChannel("slot", tostring(tag or "slot_authority"), tostring(detail or ""))
end

local function logVehicleSlotTrace(stage, detail)
    logSlotAuthority(stage or "vehicle_slot_trace", detail)
end

local function nowIntentLogMs()
    if getTimestampMs then
        local ms = tonumber(getTimestampMs())
        if ms then
            return ms
        end
    end
    if getTimeInMillis then
        local ms = tonumber(getTimeInMillis())
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

local function logIntent(tag, detail, options)
    if not (NMCore and NMCore.logChannel) then
        return
    end
    local opts = type(options) == "table" and options or nil
    if opts and opts.debugKnob then
        if not (NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled(opts.debugKnob)) then
            return
        end
    end
    if opts and opts.throttleKey and NMCore.shouldLogEvery then
        local throttleMs = math.max(250, tonumber(opts.throttleMs) or 1500)
        local logKey = "intent." .. tostring(opts.throttleKey or "")
        if not NMCore.shouldLogEvery(logKey, nowIntentLogMs(), throttleMs) then
            return
        end
    end
    NMCore.logChannel("intent", tostring(tag or "intent"), tostring(detail or ""))
end

local function logCycleModeProbe(scope, stateBefore, stateAfter, payload)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("vehicle")) then
        return
    end
    local beforePolicy = tostring(stateBefore and stateBefore.playbackPolicy or "autoplay")
    local afterPolicy = tostring(stateAfter and stateAfter.playbackPolicy or "autoplay")
    local beforeEpoch = tonumber(stateBefore and stateBefore.playbackEpoch) or 0
    local afterEpoch = tonumber(stateAfter and stateAfter.playbackEpoch) or 0
    local beforePlaying = tostring(stateBefore and stateBefore.isPlaying == true)
    local afterPlaying = tostring(stateAfter and stateAfter.isPlaying == true)
    local requestedPolicy = tostring(payload and payload.playbackPolicy or "")
    local uuid = tostring(stateAfter and stateAfter.deviceUUID or stateBefore and stateBefore.deviceUUID or "")
    local throttleKey = string.format(
        "cycleModeProbe.cycleMode.%s.%s.%s.%s",
        tostring(scope or "item"),
        tostring(uuid),
        tostring(beforePolicy),
        tostring(afterPolicy)
    )
    if NMCore.shouldLogEvery and not NMCore.shouldLogEvery(throttleKey, nowIntentLogMs(), 500) then
        return
    end
    NMCore.logChannel(
        "vehicle",
        "cycle_mode_apply",
        string.format(
            "scope=%s uuid=%s requested=%s beforePolicy=%s afterPolicy=%s beforeEpoch=%s afterEpoch=%s beforePlaying=%s afterPlaying=%s",
            tostring(scope or "item"),
            tostring(uuid),
            tostring(requestedPolicy),
            tostring(beforePolicy),
            tostring(afterPolicy),
            tostring(beforeEpoch),
            tostring(afterEpoch),
            beforePlaying,
            afterPlaying
        )
    )
end

local describeSourceDescriptorArgs = NMSourceDescriptorSummary and NMSourceDescriptorSummary.describeArgs or function()
    return "none"
end

local function validateNonRootMediaSourceDescriptor(descriptor)
    if type(descriptor) ~= "table" then
        return true, nil
    end
    local kind = tostring(descriptor.kind or "")
    if kind == "" or kind == "player_inventory" then
        return true, nil
    end
    if kind == "vehicle_part_container" then
        if tostring(descriptor.vehicleId or "") == "" or tostring(descriptor.partId or "") == "" then
            return false, "vehicle_descriptor_incomplete"
        end
        return true, nil
    end
    if kind == "world_object_container" then
        if descriptor.objectIndex == nil then
            return false, "world_object_descriptor_incomplete"
        end
        return true, nil
    end
    if kind == "corpse_container" then
        if descriptor.deadBodyIndex == nil then
            return false, "corpse_descriptor_incomplete"
        end
        return true, nil
    end
    return true, nil
end

local function buildVehicleAuthorityContext(player, vehicle)
    return {
        sourceX = vehicle and tonumber(vehicle:getX()) or nil,
        sourceY = vehicle and tonumber(vehicle:getY()) or nil,
        sourceZ = vehicle and tonumber(vehicle:getZ()) or nil,
        sourceOwner = NMIntentAuthority.resolveSourceOwnerIdentity(player)
    }
end

local function updateSPWorldSourceCache(player, item, profile, state, action, options)
    if NMCore.isMPClientRuntime and NMCore.isMPClientRuntime() then
        return
    end
    if not (item and profile and state and state.deviceUUID) then
        return
    end

    local uuid = tostring(state.deviceUUID or "")
    if uuid == "" then
        return
    end

    local mode = NMClientModeReconcile.resolveModeForItem(player, item, profile, state)
    if mode == "attached" or mode == "placed" or mode == "stowed" then
        state.playbackMode = "world"
    else
        state.playbackMode = "inventory"
    end

    local isWorldMode = mode == "attached" or mode == "placed" or mode == "stowed"
    local shouldCacheNow = mode == "placed" or mode == "stowed"
    local isWorldActive = NMRegistryPolicy.isWorldSyncStateActive and NMRegistryPolicy.isWorldSyncStateActive(state) or false
    local keepWorldSource = isWorldMode and shouldCacheNow and isWorldActive
    local opts = type(options) == "table" and options or nil
    local isLevelOnlyAction = action == "set_volume" or action == "mute_on" or action == "mute_off"
    if isLevelOnlyAction
        and opts
        and opts.prevKeepWorldSource == false
        and keepWorldSource == false then
        if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
            NMCore.logChannel(
                "runtime",
                "sp_cache_skip_noop",
                string.format(
                    "uuid=%s action=%s prevKeep=%s keep=%s",
                    uuid, tostring(action), tostring(opts.prevKeepWorldSource), tostring(keepWorldSource)
                )
            )
        end
        return
    end

    if not keepWorldSource then
        NMClientWorldSourceCache.remove(uuid)
        NMWorldRegistrySnapshot.removeSP(uuid)
        if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
            NMCore.logChannel(
                "runtime",
                "sp_cache_remove",
                string.format(
                    "uuid=%s action=%s mode=%s keep=false worldMode=%s shouldCacheNow=%s worldActive=%s muted=%s isOn=%s isPlaying=%s playbackMode=%s",
                    uuid,
                    tostring(action or "unknown"),
                    tostring(mode),
                    tostring(isWorldMode),
                    tostring(shouldCacheNow),
                    tostring(isWorldActive),
                    tostring(state.isMuted == true),
                    tostring(state.isOn == true),
                    tostring(state.isPlaying == true),
                    tostring(state.playbackMode or "nil")
                )
            )
        end
        return
    end

    local sourceX, sourceY, sourceZ = 0, 0, 0
    local sourceMode = "placed"
    if mode == "placed" then
        local worldItem = item.getWorldItem and item:getWorldItem() or nil
        local square = worldItem and worldItem.getSquare and worldItem:getSquare() or nil
        if square then
            sourceX = square:getX() + 0.5
            sourceY = square:getY() + 0.5
            sourceZ = square:getZ()
        elseif player and player.getX and player.getY and player.getZ then
            sourceX = tonumber(player:getX()) or 0
            sourceY = tonumber(player:getY()) or 0
            sourceZ = tonumber(player:getZ()) or 0
            sourceMode = "attached"
        end
    else
        sourceMode = (mode == "attached" or mode == "stowed") and mode or "attached"
        if player and player.getX and player.getY and player.getZ then
            sourceX = tonumber(player:getX()) or 0
            sourceY = tonumber(player:getY()) or 0
            sourceZ = tonumber(player:getZ()) or 0
        end
    end

    NMClientWorldSourceCache.upsertFromPayload({
        uuid = uuid,
        kind = "item",
        profileType = item and item.getFullType and item:getFullType() or nil,
        state = state,
        sourceMode = sourceMode,
        x = sourceX,
        y = sourceY,
        z = sourceZ,
        itemId = NMCore.itemId and NMCore.itemId(item) or nil,
        itemFullType = item and item.getFullType and item:getFullType() or nil,
        sourceEpoch = tonumber(state.sourceGeneration) or 0
    })
    NMWorldRegistrySnapshot.upsertSP({
        kind = "item",
        uuid = uuid,
        profileType = item and item.getFullType and item:getFullType() or nil,
        sourceMode = sourceMode,
        sourceEpoch = tonumber(state.sourceGeneration) or 0,
        x = sourceX,
        y = sourceY,
        z = sourceZ,
        itemId = NMCore.itemId and NMCore.itemId(item) or nil,
        itemFullType = item and item.getFullType and item:getFullType() or nil,
        state = NMDeviceState.export(state),
        revision = tonumber(state.revision) or 0,
        playbackEpoch = tonumber(state.playbackEpoch) or 0
    })
    if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
        NMCore.logChannel(
            "runtime",
            "sp_cache_upsert",
            string.format(
                "uuid=%s action=%s mode=%s source=%s x=%.2f y=%.2f z=%.2f isOn=%s isPlaying=%s media=%s",
                uuid,
                tostring(action or "unknown"),
                tostring(mode),
                tostring(sourceMode),
                tonumber(sourceX) or 0,
                tonumber(sourceY) or 0,
                tonumber(sourceZ) or 0,
                tostring(state.isOn == true),
                tostring(state.isPlaying == true),
                tostring(state.mediaFullType or "nil")
            )
        )
    end
end

local function resolveOwningContainer(item, fallbackInventory)
    local container = item and item.getContainer and item:getContainer() or nil
    if container and container.DoRemoveItem and container.AddItem then
        return container
    end
    return fallbackInventory
end

local function normalizeIngressArgsToMainInventory(player, action, args)
    local act = tostring(action or "")
    local spec = nil
    if act == "insert_headphones" then
        spec = { idKey = "headphoneItemId", uuidKey = "headphoneItemUuid" }
    elseif act == "insert_media" then
        spec = { idKey = "mediaItemId", uuidKey = "mediaItemUuid" }
    elseif act == "insert_battery" then
        spec = { idKey = "batteryItemId", uuidKey = "batteryItemUuid" }
    end
    if not spec then
        return true, nil
    end
    if act == "insert_media"
        and NMCore
        and NMCore.isMPClientRuntime
        and NMCore.isMPClientRuntime()
        and NMInventoryHelpers
        and NMInventoryHelpers.findAccessibleItemByIdOrUuid then
        logSlotAuthority(
            "client_normalize_mp_begin",
            string.format(
                "action=%s host=%s mediaItemId=%s mediaItemUuid=%s slotTraceId=%s descriptor=%s",
                tostring(act),
                tostring(args and args.vehicleId and args.vehicleId ~= "" and "vehicle" or "item"),
                tostring(args and args[spec.idKey] or ""),
                tostring(spec.uuidKey and args and args[spec.uuidKey] or ""),
                tostring(args and args.slotTraceId or ""),
                describeSourceDescriptorArgs(args, "mediaSource")
            )
        )
        local liveItem = NMInventoryHelpers.findAccessibleItemByIdOrUuid(player, args and args[spec.idKey], args and args[spec.uuidKey])
        if not liveItem then
            logSlotAuthority(
                "client_normalize_mp_missing",
                string.format(
                    "action=%s host=%s mediaItemId=%s mediaItemUuid=%s slotTraceId=%s",
                    tostring(act),
                    tostring(args and args.vehicleId and args.vehicleId ~= "" and "vehicle" or "item"),
                    tostring(args and args[spec.idKey] or ""),
                    tostring(spec.uuidKey and args and args[spec.uuidKey] or ""),
                    tostring(args and args.slotTraceId or "")
                )
            )
            return false, "source_item_not_found"
        end
        if NMInventoryHelpers.writeSourceDescriptorToArgs and NMInventoryHelpers.describeAccessibleItemSource then
            local descriptor = NMInventoryHelpers.describeAccessibleItemSource(player, liveItem, {
                host = tostring(args and args.vehicleId and args.vehicleId ~= "" and "vehicle" or "item"),
                slotTraceId = tostring(args and args.slotTraceId or "")
            })
            if descriptor then
                local descriptorOk, descriptorErr = validateNonRootMediaSourceDescriptor(descriptor)
                if not descriptorOk then
                    logSlotAuthority(
                        "client_normalize_mp_reject",
                        string.format(
                            "action=%s host=%s reason=%s mediaItemId=%s mediaItemUuid=%s slotTraceId=%s descriptor=kind=%s vehicleId=%s partId=%s objectIndex=%s deadBodyIndex=%s",
                            tostring(act),
                            tostring(args and args.vehicleId and args.vehicleId ~= "" and "vehicle" or "item"),
                            tostring(descriptorErr or "descriptor_invalid"),
                            tostring(args and args[spec.idKey] or ""),
                            tostring(spec.uuidKey and args and args[spec.uuidKey] or ""),
                            tostring(args and args.slotTraceId or ""),
                            tostring(descriptor.kind or ""),
                            tostring(descriptor.vehicleId or ""),
                            tostring(descriptor.partId or ""),
                            tostring(descriptor.objectIndex or ""),
                            tostring(descriptor.deadBodyIndex or "")
                        )
                    )
                    return false, descriptorErr or "descriptor_invalid"
                end
                NMInventoryHelpers.writeSourceDescriptorToArgs(args, "mediaSource", descriptor)
            end
        end
        logSlotAuthority(
            "client_normalize_mp_ready",
            string.format(
                "action=%s host=%s mediaItemId=%s mediaItemUuid=%s liveFullType=%s slotTraceId=%s descriptor=%s",
                tostring(act),
                tostring(args and args.vehicleId and args.vehicleId ~= "" and "vehicle" or "item"),
                tostring(args and args[spec.idKey] or ""),
                tostring(spec.uuidKey and args and args[spec.uuidKey] or ""),
                tostring(liveItem and liveItem.getFullType and liveItem:getFullType() or ""),
                tostring(args and args.slotTraceId or ""),
                describeSourceDescriptorArgs(args, "mediaSource")
            )
        )
        return true, nil, liveItem, {
            moved = false,
            deferred = true
        }
    end
    if not (NMInventoryHelpers and NMInventoryHelpers.normalizeItemToMainInventory) then
        return false, "normalize_helper_missing"
    end
    local liveItem, err, meta = NMInventoryHelpers.normalizeItemToMainInventory(player, args and args[spec.idKey], args and args[spec.uuidKey])
    if not liveItem then
        return false, err or "normalize_failed"
    end
    args[spec.idKey] = NMCore.itemId(liveItem)
    if spec.uuidKey then
        args[spec.uuidKey] = NMInventoryHelpers.getItemStateUuid and NMInventoryHelpers.getItemStateUuid(liveItem) or nil
    end
    return true, nil, liveItem, meta
end

local function reconcileHeadphoneWearState(player, profile, state, actionName, sourceMode)
    if not (player and profile and state and NMDeviceProfiles.supportsHeadphones(profile)) then
        return false
    end
    local action = tostring(actionName or "")
    local current = tostring(state.headphoneItemFullType or "")
    local mode = tostring(sourceMode or state.authoritativeMode or "")
    if NMInsertedHeadphonePolicy
        and NMInsertedHeadphonePolicy.isGroundContext(mode)
        and NMInsertedHeadphonePolicy.shouldDetachOnGround(current) then
        state.headphoneItemFullType = nil
        return true
    end
    local worn = NMAttachmentHelpers.findWornHeadphones and NMAttachmentHelpers.findWornHeadphones(player) or nil
    local wearingHeadphones = worn ~= nil

    if current == "" and wearingHeadphones and worn and worn.getFullType then
        local wornFullType = tostring(worn:getFullType() or "")
        if NMInsertedHeadphonePolicy
            and NMInsertedHeadphonePolicy.canAutoReattachFromAvatar(wornFullType)
            and not (NMInsertedHeadphonePolicy.isGroundContext(mode)) then
            state.headphoneItemFullType = wornFullType
            return true
        end
    end
    if NMInsertedHeadphonePolicy
        and NMInsertedHeadphonePolicy.canAutoReattachFromAvatar(current)
        and (not wearingHeadphones)
        and action ~= "insert_headphones" then
        state.headphoneItemFullType = nil
        if profile.requiresHeadphones then
            NMTransitionCommon.setStopped(state, "headphones_removed")
        end
        return true
    end
    return false
end

local function maybeSwapContainerVisualVariantLocal(player, item, profile, state)
    if not (player and item and profile and state and profile.isMediaContainerOnly == true) then
        return item, profile, state, false, nil
    end
    local playerInventory = player.getInventory and player:getInventory() or nil
    local ownerContainer = resolveOwningContainer(item, playerInventory)
    if not ownerContainer then
        return item, profile, state, false, "missing_inventory"
    end

    local currentFullType = tostring(item.getFullType and item:getFullType() or "")
    if currentFullType == "" then
        return item, profile, state, false, nil
    end
    local wantLoaded = state.mediaFullType ~= nil
    local targetFullType = NMMediaContract
        and NMMediaContract.resolveContainerSwapFullType
        and NMMediaContract.resolveContainerSwapFullType(currentFullType, wantLoaded)
        or nil
    targetFullType = tostring(targetFullType or "")
    if targetFullType == "" or targetFullType == currentFullType then
        return item, profile, state, false, nil
    end

    local exportedState = NMDeviceState.export(state)
    local removed, removeErr = NMIntentInventoryOps.removeItemById(ownerContainer, NMCore.itemId(item))
    if not removed then
        return item, profile, state, false, "container_swap_remove_failed:" .. tostring(removeErr or "unknown")
    end

    local swappedItem, addErr = NMIntentInventoryOps.addItemByFullType(ownerContainer, targetFullType)
    if not swappedItem then
        return item, profile, state, false, "container_swap_add_failed:" .. tostring(addErr or "unknown")
    end

    local swappedProfile = NMDeviceProfiles.getForItem(swappedItem) or profile
    local swappedState = NMDeviceState.ensure(swappedItem, swappedProfile)
    if not swappedState then
        return item, profile, state, false, "container_swap_state_failed"
    end
    NMDeviceState.import(swappedState, exportedState)
    return swappedItem, swappedProfile, swappedState, true, nil
end

function NMClientIntentDispatch.applyIntentLocal(player, item, action, args)
    local profile = NMDeviceProfiles.getForItem(item)
    if not profile then
        logIntent(
            "apply_local_rejected",
            "action=" .. tostring(action) .. " reason=not_managed",
            {
                throttleKey = string.format("apply_local_rejected.%s.not_managed", tostring(action or "")),
                throttleMs = 2000
            }
        )
        return false, "not_managed"
    end

    local state = NMDeviceState.ensure(item, profile)
    local normalizedOk, normalizedErr = normalizeIngressArgsToMainInventory(player, action, args or {})
    if not normalizedOk then
        local rejectReason = tostring(normalizedErr or "normalize_failed")
        logIntent(
            "apply_local_rejected",
            "action=" .. tostring(action) .. " reason=" .. rejectReason,
            {
                throttleKey = string.format(
                    "apply_local_rejected.%s.%s.%s",
                    tostring(action or ""),
                    rejectReason,
                    tostring(NMCore and NMCore.itemId and NMCore.itemId(item) or "")
                ),
                throttleMs = 2000
            }
        )
        return false, "normalize_failed:" .. tostring(normalizedErr or "unknown")
    end
    local prevIsOn = state and state.isOn == true
    local prevMode = NMClientModeReconcile.resolveModeForItem(player, item, profile, state)
    local prevIsWorldMode = prevMode == "attached" or prevMode == "placed" or prevMode == "stowed"
    local prevShouldCacheNow = prevMode == "placed" or prevMode == "stowed"
    local prevIsWorldActive = NMRegistryPolicy.isWorldSyncStateActive and NMRegistryPolicy.isWorldSyncStateActive(state) or false
    local prevKeepWorldSource = prevIsWorldMode and prevShouldCacheNow and prevIsWorldActive
    local stateBeforeIntent = NMDeviceState.export(state)
    local preReconcileChanged = reconcileHeadphoneWearState(player, profile, state, action, prevMode)
    local wasPlaying = state and state.isPlaying == true
    local hadHeadphones = state and state.headphoneItemFullType ~= nil
    local payload = NMIntentPayloadBuilder.buildItemPayload(player, item, profile, args)
    if isCorpseRecoveredItemState(item, state) then
        state._nmCorpseRecovered = true
    end
    if isCorpseRecoveredItemState(item, state) and (action == "play" or action == "power_on") then
        logCorpseAudio(
            "intent_attempt",
            state.deviceUUID,
            string.format(
                "action=%s item=%s media=%s hasTrack=%s trackCount=%d mode=%s playbackMode=%s headphones=%s batteryPresent=%s batteryCharge=%.3f muted=%s isOn=%s isPlaying=%s",
                tostring(action),
                tostring(item and item.getFullType and item:getFullType() or "unknown"),
                tostring(state and state.mediaFullType or "nil"),
                tostring(payload and payload.hasTrack == true),
                tonumber(payload and payload.trackCount) or 0,
                tostring(prevMode or "unknown"),
                tostring(state and state.playbackMode or ""),
                tostring(state and state.headphoneItemFullType or "nil"),
                tostring(state and state.batteryPresent == true),
                tonumber(state and state.batteryCharge) or 0.0,
                tostring(state and state.isMuted == true),
                tostring(state and state.isOn == true),
                tostring(state and state.isPlaying == true)
            )
        )
    end
    local changed, reason, ops = NMDeviceTransitions.apply(profile, state, action, payload)
    if not changed then
        if preReconcileChanged then
            NMDeviceState.bumpRevision(state)
            updateSPWorldSourceCache(player, item, profile, state, action, {
                prevKeepWorldSource = prevKeepWorldSource
            })
        end
        if isCorpseRecoveredItemState(item, state) then
            logCorpseAudio(
                "intent_rejected",
                state.deviceUUID,
                string.format(
                    "action=%s reason=%s item=%s media=%s hasTrack=%s trackCount=%d mode=%s playbackMode=%s headphones=%s batteryPresent=%s batteryCharge=%.3f muted=%s isOn=%s isPlaying=%s",
                    tostring(action),
                    tostring(reason or "none"),
                    tostring(item and item.getFullType and item:getFullType() or "unknown"),
                    tostring(state and state.mediaFullType or "nil"),
                    tostring(payload and payload.hasTrack == true),
                    tonumber(payload and payload.trackCount) or 0,
                    tostring(prevMode or "unknown"),
                    tostring(state and state.playbackMode or ""),
                    tostring(state and state.headphoneItemFullType or "nil"),
                    tostring(state and state.batteryPresent == true),
                    tonumber(state and state.batteryCharge) or 0.0,
                    tostring(state and state.isMuted == true),
                    tostring(state and state.isOn == true),
                    tostring(state and state.isPlaying == true)
                )
            )
        end
        logIntent(
            "apply_local_rejected",
            string.format(
                "action=%s reason=%s item=%s media=%s isOn=%s isPlaying=%s hasTrack=%s trackCount=%d",
                tostring(action),
                tostring(reason or "none"),
                tostring(item and item.getFullType and item:getFullType() or "unknown"),
                tostring(state and state.mediaFullType or "nil"),
                tostring(state and state.isOn == true),
                tostring(state and state.isPlaying == true),
                tostring(payload and payload.hasTrack == true),
                tonumber(payload and payload.trackCount) or 0
            ),
            {
                throttleKey = string.format(
                    "apply_local_rejected.%s.%s.%s",
                    tostring(action or ""),
                    tostring(reason or "none"),
                    tostring(state and state.deviceUUID or "")
                ),
                throttleMs = 2000
            }
        )
        return false, reason
    end

    if isCorpseRecoveredItemState(item, state) then
        logCorpseAudio(
            "intent_applied",
            state.deviceUUID,
            string.format(
                "action=%s item=%s media=%s trackIndex=%d playbackMode=%s headphones=%s batteryPresent=%s batteryCharge=%.3f muted=%s isOn=%s isPlaying=%s",
                tostring(action),
                tostring(item and item.getFullType and item:getFullType() or "unknown"),
                tostring(state and state.mediaFullType or "nil"),
                tonumber(state and state.trackIndex) or 1,
                tostring(state and state.playbackMode or ""),
                tostring(state and state.headphoneItemFullType or "nil"),
                tostring(state and state.batteryPresent == true),
                tonumber(state and state.batteryCharge) or 0.0,
                tostring(state and state.isMuted == true),
                tostring(state and state.isOn == true),
                tostring(state and state.isPlaying == true)
            )
        )
    end

    if NMCore and NMCore.logChannel then
        NMCore.logChannel(
            "intent",
            "apply_local_applied",
            string.format(
                "action=%s item=%s media=%s isOn=%s isPlaying=%s trackIndex=%d",
                tostring(action),
                tostring(item and item.getFullType and item:getFullType() or "unknown"),
                tostring(state and state.mediaFullType or "nil"),
                tostring(state and state.isOn == true),
                tostring(state and state.isPlaying == true),
                tonumber(state and state.trackIndex) or 1
            )
        )
    end
    if (action == "mute_on" or action == "mute_off" or action == "set_volume")
        and NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("intent") then
        NMCore.logChannel(
            "intent",
            "level_change_applied",
            string.format(
                "action=%s item=%s wasPlaying=%s isPlaying=%s muted=%s volume=%.2f",
                tostring(action),
                tostring(item and item.getFullType and item:getFullType() or "unknown"),
                tostring(wasPlaying),
                tostring(state and state.isPlaying == true),
                tostring(state and state.isMuted == true),
                tonumber(state and state.volume) or 0
            )
        )
    end
    if (action == "insert_headphones" or action == "eject_headphones")
        and NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("intent") then
        local mode = NMClientModeReconcile.resolveModeForItem(player, item, profile, state)
        local output = NMDeviceProfiles.resolveOutputMode(profile, state, mode, false)
        NMCore.logChannel(
            "intent",
            "headphones_change_applied",
            string.format(
                "action=%s item=%s wasPlaying=%s isPlaying=%s hadHeadphones=%s hasHeadphones=%s mode=%s output=%s",
                tostring(action),
                tostring(item and item.getFullType and item:getFullType() or "unknown"),
                tostring(wasPlaying),
                tostring(state and state.isPlaying == true),
                tostring(hadHeadphones),
                tostring(state and state.headphoneItemFullType ~= nil),
                tostring(mode or "unknown"),
                tostring(output or "none")
            )
        )
    end

    local inv = player and player.getInventory and player:getInventory() or nil
    local _, opsError = NMIntentInventoryOps.applyTransitionOps(player, inv, ops)
    if opsError and NMCore and NMCore.logChannel then
        logIntent(
            "apply_local_ops_failed",
            tostring(opsError),
            {
                throttleKey = string.format(
                    "apply_local_ops_failed.%s.%s",
                    tostring(action or ""),
                    tostring(state and state.deviceUUID or "")
                ),
                throttleMs = 2000
            }
        )
        if stateBeforeIntent then
            NMDeviceState.import(state, stateBeforeIntent)
        end
        return false, "ops_failed:" .. tostring(opsError)
    end
    item, profile, state = maybeSwapContainerVisualVariantLocal(player, item, profile, state)
    local nextMode = NMClientModeReconcile.resolveModeForItem(player, item, profile, state)
    local postReconcileChanged = reconcileHeadphoneWearState(player, profile, state, action, nextMode)

    local playbackEpochBefore = tonumber(state and state.playbackEpoch) or 0

    if doesActionAdvancePlaybackContinuity(action) then
        NMDeviceState.bumpPlaybackEpoch(state)
    end
    if action == "cycle_mode" then
        logCycleModeProbe(
            "item",
            {
                deviceUUID = state and state.deviceUUID,
                playbackPolicy = stateBeforeIntent and stateBeforeIntent.playbackPolicy,
                playbackEpoch = playbackEpochBefore,
                isPlaying = stateBeforeIntent and stateBeforeIntent.isPlaying,
            },
            state,
            payload
        )
    end
    local nowIsOn = state and state.isOn == true
    if prevIsOn and (not nowIsOn) and NMPlaybackRuntime and NMPlaybackRuntime.resetPowerTick then
        NMPlaybackRuntime.resetPowerTick(state and state.deviceUUID, "intent_power_off")
    end
    if (not prevIsOn) and nowIsOn and NMPlaybackRuntime and NMPlaybackRuntime.resetPowerTick then
        NMPlaybackRuntime.resetPowerTick(state and state.deviceUUID, "intent_power_on")
    end
    if prevIsOn and (not nowIsOn) and NMPlaybackRuntime and NMPlaybackRuntime.forceStop then
        NMPlaybackRuntime.forceStop(player, state and state.deviceUUID, "intent_power_off_immediate")
    end
    NMDeviceState.bumpRevision(state)
    updateSPWorldSourceCache(player, item, profile, state, action, {
        prevKeepWorldSource = prevKeepWorldSource
    })
    return true, nil
end

local function isPowerOnRequest(localAction, localArgs, localState)
    local name = tostring(localAction or "")
    if name == "power_on" then
        return true
    end
    return false
end

local function applyVehicleIntentLocal(player, vehicle, part, action, args)
    local profile = part and NMDeviceProfiles.getVehicleProfile(part) or nil
    if not profile then
        return false, "vehicle_profile_missing"
    end

    local state = NMDeviceState.ensure(part, profile)
    local stateBeforeIntent = NMDeviceState.export(state)
    local prevIsOn = state and state.isOn == true
    local inv = player and player.getInventory and player:getInventory() or nil
    local payload, trackCount = NMIntentPayloadBuilder.buildVehiclePayload(player, vehicle, part, state, args)
    if isPowerOnRequest(action, args, state) and payload.externalPowerAvailable ~= true then
        return false, "vehicle_battery_unavailable"
    end
    if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("intent") then
        NMCore.logChannel(
            "intent",
            "vehicle_intent_attempt",
            string.format(
                "action=%s vehicle=%s part=%s media=%s isOn=%s isPlaying=%s trackCount=%d hasTrack=%s",
                tostring(action),
                tostring(vehicle and vehicle.getId and vehicle:getId() or "unknown"),
                tostring(part and part.getId and part:getId() or "unknown"),
                tostring(state and state.mediaFullType or "nil"),
                tostring(state and state.isOn == true),
                tostring(state and state.isPlaying == true),
                tonumber(trackCount) or 0,
                tostring(trackCount > 0)
            )
        )
    end
    local changed, reason, ops = NMDeviceTransitions.apply(profile, state, action, payload)
    if part and profile.vehicleUsesCarBattery and state.isOn and (not NMVehicleHelpers.vehicleHasPower(vehicle, part)) then
        state.isOn = false
        state.desiredIsOn = false
        state.isPlaying = false
        state.desiredIsPlaying = false
        state.lastStopReason = "vehicle_battery_empty"
        changed = true
    end

    if not changed then
        if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("intent") then
            NMCore.logChannel(
                "intent",
                "vehicle_intent_rejected",
                string.format(
                    "action=%s reason=%s vehicle=%s part=%s media=%s isOn=%s isPlaying=%s trackCount=%d",
                    tostring(action),
                    tostring(reason or "none"),
                    tostring(vehicle and vehicle.getId and vehicle:getId() or "unknown"),
                    tostring(part and part.getId and part:getId() or "unknown"),
                    tostring(state and state.mediaFullType or "nil"),
                    tostring(state and state.isOn == true),
                    tostring(state and state.isPlaying == true),
                    tonumber(trackCount) or 0
                )
            )
        end
        return false, reason
    end

    local _, opsError = NMIntentInventoryOps.applyTransitionOps(player, inv, ops)
    if opsError and NMCore and NMCore.logChannel then
        logIntent(
            "vehicle_apply_local_ops_failed",
            string.format(
                "action=%s mediaItemId=%s resolvedMedia=%s opsError=%s",
                tostring(action),
                tostring(args.mediaItemId or ""),
                tostring(payload.mediaFullType or ""),
                tostring(opsError)
            ),
            {
                throttleKey = string.format(
                    "vehicle_apply_local_ops_failed.%s.%s.%s",
                    tostring(action),
                    tostring(state and state.deviceUUID or ""),
                    tostring(args.partId or "")
                ),
                throttleMs = 2000
            }
        )
        if stateBeforeIntent then
            NMDeviceState.import(state, stateBeforeIntent)
        end
        return false, "ops_failed:" .. tostring(opsError)
    end
    if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("intent") then
        NMCore.logChannel(
            "intent",
            "vehicle_intent_applied",
            string.format(
                "action=%s vehicle=%s part=%s media=%s isOn=%s isPlaying=%s trackCount=%d",
                tostring(action),
                tostring(vehicle and vehicle.getId and vehicle:getId() or "unknown"),
                tostring(part and part.getId and part:getId() or "unknown"),
                tostring(state and state.mediaFullType or "nil"),
                tostring(state and state.isOn == true),
                tostring(state and state.isPlaying == true),
                tonumber(trackCount) or 0
            )
        )
    end

    local playbackEpochBefore = tonumber(state and state.playbackEpoch) or 0

    if doesActionAdvancePlaybackContinuity(action) then
        NMDeviceState.bumpPlaybackEpoch(state)
    end
    if action == "cycle_mode" then
        logCycleModeProbe(
            "vehicle",
            {
                deviceUUID = state and state.deviceUUID,
                playbackPolicy = stateBeforeIntent and stateBeforeIntent.playbackPolicy,
                playbackEpoch = playbackEpochBefore,
                isPlaying = stateBeforeIntent and stateBeforeIntent.isPlaying,
            },
            state,
            payload
        )
    end
    local nowIsOn = state and state.isOn == true
    if prevIsOn and (not nowIsOn) and NMPlaybackRuntime and NMPlaybackRuntime.resetPowerTick then
        NMPlaybackRuntime.resetPowerTick(state and state.deviceUUID, "vehicle_intent_power_off")
    end
    if (not prevIsOn) and nowIsOn and NMPlaybackRuntime and NMPlaybackRuntime.resetPowerTick then
        NMPlaybackRuntime.resetPowerTick(state and state.deviceUUID, "vehicle_intent_power_on")
    end
    if prevIsOn and (not nowIsOn) and NMPlaybackRuntime and NMPlaybackRuntime.forceStop then
        NMPlaybackRuntime.forceStop(player, state and state.deviceUUID, "intent_power_off_immediate")
    end
    NMIntentAuthority.applyIntent(state, "request_vehicle", buildVehicleAuthorityContext(player, vehicle))
    NMDeviceState.bumpRevision(state)

    local keep = NMRegistryPolicy.shouldKeepWorldSourceState(state)
    local uuid = tostring(state.deviceUUID or "")
    local vehicleRuntimeId = vehicle and NMVehicleHelpers and NMVehicleHelpers.getVehicleIdString and NMVehicleHelpers.getVehicleIdString(vehicle)
        or vehicle and tostring(vehicle:getId()) or nil
    local vehicleSqlId = vehicle and NMVehicleHelpers and NMVehicleHelpers.getVehicleSqlIdString and NMVehicleHelpers.getVehicleSqlIdString(vehicle)
        or nil
    if keep and uuid ~= "" then
        NMClientWorldSourceCache.upsertFromPayload({
            kind = "vehicle",
            uuid = uuid,
            vehicleId = vehicleRuntimeId,
            vehicleIdHint = vehicleRuntimeId,
            vehicleSqlId = vehicleSqlId,
            vehicleSqlIdHint = vehicleSqlId,
            partId = part and tostring(part:getId()) or "Radio",
            profileType = "vehicle_radio",
            x = vehicle and tonumber(vehicle:getX()) or 0,
            y = vehicle and tonumber(vehicle:getY()) or 0,
            z = vehicle and tonumber(vehicle:getZ()) or 0,
            sourceMode = "vehicle",
            windowsOpen = vehicle and NMVehicleHelpers.vehicleWindowsOpen(vehicle) or false,
            sourceEpoch = tonumber(state.sourceGeneration) or 0,
            state = state
        })
        NMWorldRegistrySnapshot.upsertSP({
            kind = "vehicle",
            uuid = uuid,
            profileType = "vehicle_radio",
            sourceMode = "vehicle",
            sourceEpoch = tonumber(state.sourceGeneration) or 0,
            x = vehicle and tonumber(vehicle:getX()) or 0,
            y = vehicle and tonumber(vehicle:getY()) or 0,
            z = vehicle and tonumber(vehicle:getZ()) or 0,
            vehicleId = vehicleRuntimeId,
            vehicleIdHint = vehicleRuntimeId,
            vehicleSqlId = vehicleSqlId,
            vehicleSqlIdHint = vehicleSqlId,
            partId = part and tostring(part:getId()) or "Radio",
            windowsOpen = vehicle and NMVehicleHelpers.vehicleWindowsOpen(vehicle) or false,
            state = NMDeviceState.export(state),
            revision = tonumber(state.revision) or 0,
            playbackEpoch = tonumber(state.playbackEpoch) or 0
        })
        if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
            local cacheLogKey = "runtimeProbe.vehicle_cache_upsert." .. tostring(uuid)
            if not NMCore.shouldLogEvery or NMCore.shouldLogEvery(cacheLogKey, nowIntentLogMs(), 60000) then
                NMCore.logChannel("runtime", "vehicle_cache_upsert", "uuid=" .. tostring(uuid) .. " vehicleId=" .. tostring(vehicle and vehicle.getId and vehicle:getId() or "unknown"))
            end
        end
    elseif uuid ~= "" then
        NMClientWorldSourceCache.remove(uuid)
        NMWorldRegistrySnapshot.removeSP(uuid)
        if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
            NMCore.logChannel("runtime", "vehicle_cache_remove", "uuid=" .. tostring(uuid) .. " vehicleId=" .. tostring(vehicle and vehicle.getId and vehicle:getId() or "unknown"))
        end
    end

    if vehicle and vehicle.transmitPartModData then
        vehicle:transmitPartModData(part)
        vehicle:updateParts()
    end

    return true, nil
end

local function populateItemIntentArgs(item, action, args)
    args = args or {}
    args.itemId = NMCore.itemId(item)
    args.action = tostring(action or "")
    if item and item.getFullType and args.itemFullType == nil then
        args.itemFullType = tostring(item:getFullType() or "")
    end
    if args.uuid == nil then
        local profile = NMDeviceProfiles.getForItem(item)
        local state = profile and NMDeviceState.ensure(item, profile) or nil
        if state and state.deviceUUID then
            args.uuid = tostring(state.deviceUUID)
        end
    end
    return args
end

local function populateVehicleIntentArgs(vehicle, part, action, args)
    args = args or {}
    args.action = tostring(action or "")
    args.vehicleId = vehicle and tostring(vehicle:getId()) or nil
    args.partId = part and tostring(part:getId()) or "Radio"
    args.playbackMode = "world"
    return args
end

local function logVehicleClientDispatch(stage, args, result, reason)
    local action = tostring(args and args.action or "")
    local vehicleId = tostring(args and args.vehicleId or "")
    local partId = tostring(args and args.partId or "")
    local traceId = tostring(args and args.slotTraceId or "")
    if stage == "begin" then
        logVehicleSlotTrace(
            "vehicle_slot_client_dispatch_begin",
            string.format(
                "trace=%s host=vehicle ui=vehicle action=%s stage=client_dispatch_begin result=ok vehicleId=%s partId=%s mediaItemId=%s mediaItemUuid=%s descriptor=%s",
                traceId,
                action,
                vehicleId,
                partId,
                tostring(args and args.mediaItemId or ""),
                tostring(args and args.mediaItemUuid or ""),
                describeSourceDescriptorArgs(args, "mediaSource")
            )
        )
        return
    end
    logVehicleSlotTrace(
        "vehicle_slot_client_dispatch_result",
        string.format(
            "trace=%s host=vehicle ui=vehicle action=%s stage=client_dispatch_result result=%s vehicleId=%s partId=%s reason=%s",
            traceId,
            action,
            tostring(result or "reject"),
            vehicleId,
            partId,
            tostring(reason or "")
        )
    )
end

local function logClientDispatchNormalizationReject(kind, item, args, normalizedErr)
    if kind == "vehicle" then
        logVehicleClientDispatch("result", args, "reject", normalizedErr)
        logSlotAuthority(
            "client_vehicle_dispatch_reject",
            string.format(
                "action=%s vehicleId=%s partId=%s mediaItemId=%s mediaItemUuid=%s slotTraceId=%s reason=%s descriptor=%s",
                tostring(args.action or ""),
                tostring(args.vehicleId or ""),
                tostring(args.partId or ""),
                tostring(args.mediaItemId or ""),
                tostring(args.mediaItemUuid or ""),
                tostring(args.slotTraceId or ""),
                tostring(normalizedErr or ""),
                describeSourceDescriptorArgs(args, "mediaSource")
            )
        )
        return
    end
    logSlotAuthority(
        "client_item_dispatch_reject",
        string.format(
            "action=%s itemId=%s mediaItemId=%s mediaItemUuid=%s slotTraceId=%s reason=%s descriptor=%s",
            tostring(args.action or ""),
            tostring(NMCore.itemId(item) or ""),
            tostring(args.mediaItemId or ""),
            tostring(args.mediaItemUuid or ""),
            tostring(args.slotTraceId or ""),
            tostring(normalizedErr or ""),
            describeSourceDescriptorArgs(args, "mediaSource")
        )
    )
end

local function logClientDispatchSend(kind, item, args)
    if kind == "vehicle" then
        logVehicleClientDispatch("result", args, "ok", nil)
        logSlotAuthority(
            "client_vehicle_dispatch_send",
            string.format(
                "action=%s vehicleId=%s partId=%s mediaItemId=%s mediaItemUuid=%s slotTraceId=%s descriptor=%s",
                tostring(args.action or ""),
                tostring(args.vehicleId or ""),
                tostring(args.partId or ""),
                tostring(args.mediaItemId or ""),
                tostring(args.mediaItemUuid or ""),
                tostring(args.slotTraceId or ""),
                describeSourceDescriptorArgs(args, "mediaSource")
            )
        )
        return
    end
    logSlotAuthority(
        "client_item_dispatch_send",
        string.format(
            "action=%s itemId=%s mediaItemId=%s mediaItemUuid=%s slotTraceId=%s descriptor=%s",
            tostring(args.action or ""),
            tostring(NMCore.itemId(item) or ""),
            tostring(args.mediaItemId or ""),
            tostring(args.mediaItemUuid or ""),
            tostring(args.slotTraceId or ""),
            describeSourceDescriptorArgs(args, "mediaSource")
        )
    )
end

local function performClientIntentDispatch(player, args, options)
    local opts = type(options) == "table" and options or {}
    local onBegin = opts.onBegin
    local onNormalizeReject = opts.onNormalizeReject
    local onSend = opts.onSend
    local applyLocal = opts.applyLocal
    if onBegin then
        onBegin(args)
    end

    local normalizedOk, normalizedErr = normalizeIngressArgsToMainInventory(player, args.action, args)
    if not normalizedOk then
        if onNormalizeReject then
            onNormalizeReject(args, normalizedErr)
        end
        return false, "normalize_failed:" .. tostring(normalizedErr or "unknown")
    end

    if NMClientPlaybackTick and NMClientPlaybackTick.requestFullPass then
        NMClientPlaybackTick.requestFullPass("client_intent")
    end

    local isMpRuntime = NMCore.isMPClientRuntime and NMCore.isMPClientRuntime()
    if isMpRuntime and sendClientCommand then
        if onSend then
            onSend(args)
        end
        sendClientCommand(player, NMCore.NetModule, "intent", args)
        return true, nil
    end

    return applyLocal and applyLocal(player, args) or false, "dispatch_apply_missing"
end

function NMClientIntentDispatch.performIntent(player, item, action, args)
    args = populateItemIntentArgs(item, action, args)
    return performClientIntentDispatch(player, args, {
        onNormalizeReject = function(localArgs, normalizedErr)
            logClientDispatchNormalizationReject("item", item, localArgs, normalizedErr)
        end,
        onSend = function(localArgs)
            logClientDispatchSend("item", item, localArgs)
        end,
        applyLocal = function(localPlayer, localArgs)
            return NMClientIntentDispatch.applyIntentLocal(localPlayer, item, localArgs.action, localArgs)
        end
    })
end

function NMClientIntentDispatch.performVehicleIntent(player, vehicle, part, action, args)
    args = populateVehicleIntentArgs(vehicle, part, action, args)
    return performClientIntentDispatch(player, args, {
        onBegin = function(localArgs)
            logVehicleClientDispatch("begin", localArgs)
        end,
        onNormalizeReject = function(localArgs, normalizedErr)
            logClientDispatchNormalizationReject("vehicle", nil, localArgs, normalizedErr)
        end,
        onSend = function(localArgs)
            logClientDispatchSend("vehicle", nil, localArgs)
        end,
        applyLocal = function(localPlayer, localArgs)
            return applyVehicleIntentLocal(localPlayer, vehicle, part, localArgs.action, localArgs)
        end
    })
end
