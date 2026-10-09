require "intents/item/NMServerItemIntentLogging"
require "intents/item/NMServerItemIntentTargeting"

NMServerItemIntentTransition = NMServerItemIntentTransition or {}

local function countItemIdInContainer(container, itemId)
    local id = tostring(itemId or "")
    if not container or id == "" then
        return 0
    end
    local items = container.getItems and container:getItems() or nil
    if not items then
        return 0
    end
    local count = 0
    for i = 0, items:size() - 1 do
        local entry = items:get(i)
        if entry and tostring(entry:getID() or "") == id then
            count = count + 1
        end
    end
    return count
end

local function logContainerDupGuard(kind, stage, container, item)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime")) then
        return
    end
    local itemId = item and tostring(item:getID() or "") or ""
    if itemId == "" then
        return
    end
    local duplicateCount = countItemIdInContainer(container, itemId)
    if duplicateCount > 1 then
        NMServerItemIntentLogging.logRuntime(
            "server_ops_container_dup_guard",
            string.format(
                "kind=%s stage=%s itemId=%s duplicates=%d containerType=%s",
                tostring(kind or "unknown"),
                tostring(stage or "unknown"),
                tostring(itemId),
                tonumber(duplicateCount) or 0,
                tostring(container and container.getType and container:getType() or "unknown")
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

local function mapActionToReducerEvent(action)
    local name = tostring(action or "")
    if not (NMServerCanonicalReducer and NMServerCanonicalReducer.Event) then
        return nil
    end
    if name == "play" then
        return NMServerCanonicalReducer.Event.INTENT_START
    end
    if name == "stop" then
        return NMServerCanonicalReducer.Event.INTENT_STOP
    end
    if name == "next_track" then
        return NMServerCanonicalReducer.Event.INTENT_NEXT
    end
    if name == "prev_track" then
        return NMServerCanonicalReducer.Event.INTENT_PREV
    end
    if name == "track_finished" then
        return NMServerCanonicalReducer.Event.HINT_TRACK_FINISHED
    end
    return nil
end

function NMServerItemIntentTransition.isSyncAction(action)
    local name = tostring(action or "")
    return name == "sync_attached_world"
        or name == "sync_placed_world"
        or name == "sync_inventory_stowed"
        or name == "sync_portable_attached"
        or name == "sync_portable_placed"
        or name == "sync_portable_stowed"
end

function NMServerItemIntentTransition.isTransportAction(action)
    local name = tostring(action or "")
    return name == "play" or name == "stop"
end

function NMServerItemIntentTransition.applyObservedDurationHint(state, args)
    return NMTrackProgressionContract.applyObservedDurationHint(state, args and args.observedDurationMs)
end

function NMServerItemIntentTransition.reconcileHeadphoneWearState(player, profile, state, actionName, sourceMode)
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
            and not NMInsertedHeadphonePolicy.isGroundContext(mode) then
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

function NMServerItemIntentTransition.applyTransitionOps(player, inventory, ops)
    return NMIntentInventoryOps.applyTransitionOps(player, inventory, ops, {
        onConsume = function(kind, itemId, container, consumed)
            if kind == "media" and NMServerItemIntentLogging.isSlotEnabled() then
                NMServerItemIntentLogging.logSlotAuthority(
                    "server_item_consume_media_ok",
                    string.format(
                        "itemId=%s consumedFullType=%s containerType=%s",
                        tostring(itemId or ""),
                        tostring(consumed and consumed.getFullType and consumed:getFullType() or ""),
                        tostring(container and container.getType and container:getType() or "")
                    )
                )
            end
            if sendRemoveItemFromContainer and container and consumed then
                logContainerDupGuard(kind, "before_remove_replica", container, consumed)
                sendRemoveItemFromContainer(container, consumed)
                NMServerItemIntentLogging.logRuntime(
                    "server_ops_remove_replica",
                    "kind=" .. tostring(kind) .. " itemId=" .. tostring(itemId or "")
                )
            end
        end,
        onConsumeFail = function(kind, itemId, err)
            if kind == "media" and NMServerItemIntentLogging.isSlotEnabled() then
                NMServerItemIntentLogging.logSlotAuthority(
                    "server_item_consume_media_fail",
                    "itemId=" .. tostring(itemId or "") .. " reason=" .. tostring(err or "")
                )
            end
        end,
        onProduce = function(kind, fullType, value, container, out)
            if kind == "media" and NMServerItemIntentLogging.isSlotEnabled() then
                NMServerItemIntentLogging.logSlotAuthority(
                    "server_item_produce_media_ok",
                    string.format(
                        "fullType=%s outItemId=%s outItemUuid=%s containerType=%s",
                        tostring(fullType or ""),
                        tostring(NMCore.itemId(out) or ""),
                        tostring(NMInventoryHelpers.getItemStateUuid and NMInventoryHelpers.getItemStateUuid(out) or ""),
                        tostring(container and container.getType and container:getType() or "")
                    )
                )
            end
            if sendAddItemToContainer and container then
                logContainerDupGuard(kind, "before_add_replica", container, out)
                sendAddItemToContainer(container, out)
                logContainerDupGuard(kind, "after_add_replica", container, out)
                if kind == "battery" then
                    NMServerItemIntentLogging.logRuntime("server_ops_add_replica", "kind=battery charge=" .. tostring(value))
                else
                    NMServerItemIntentLogging.logRuntime(
                        "server_ops_add_replica",
                        "kind=" .. tostring(kind) .. " fullType=" .. tostring(fullType or "")
                    )
                end
            end
        end,
        onProduceFail = function(kind, fullType, _, err)
            if kind == "media" and NMServerItemIntentLogging.isSlotEnabled() then
                NMServerItemIntentLogging.logSlotAuthority(
                    "server_item_produce_media_fail",
                    "fullType=" .. tostring(fullType or "") .. " reason=" .. tostring(err or "")
                )
            end
        end
    })
end

function NMServerItemIntentTransition.maybeSwapContainerVisualVariant(ctx)
    if not (ctx and ctx.item and ctx.profile and ctx.state and ctx.inventory) then
        return false, nil
    end
    if ctx.profile.isMediaContainerOnly ~= true then
        return false, nil
    end

    local currentFullType = tostring(ctx.item.getFullType and ctx.item:getFullType() or "")
    if currentFullType == "" then
        return false, nil
    end
    local wantLoaded = ctx.state.mediaFullType ~= nil
    local targetFullType = NMMediaContract
        and NMMediaContract.resolveContainerSwapFullType
        and NMMediaContract.resolveContainerSwapFullType(currentFullType, wantLoaded)
        or nil
    targetFullType = tostring(targetFullType or "")
    if targetFullType == "" or targetFullType == currentFullType then
        return false, nil
    end

    local ownerContainer = resolveOwningContainer(ctx.item, ctx.inventory)
    if not ownerContainer then
        return false, "container_swap_owner_missing"
    end

    local exportedState = NMDeviceState.export(ctx.state)
    local originalItemId = tostring(ctx.item.getID and ctx.item:getID() or "")
    local removed, removeErr, removeContainer, removedItem = NMIntentInventoryOps.removeItemById(ownerContainer, originalItemId)
    if not removed then
        return false, "container_swap_remove_failed:" .. tostring(removeErr or "unknown")
    end
    if sendRemoveItemFromContainer and removeContainer and removedItem then
        sendRemoveItemFromContainer(removeContainer, removedItem)
    end

    local swappedItem, addErr, addContainer = NMIntentInventoryOps.addItemByFullType(ownerContainer, targetFullType)
    if not swappedItem then
        return false, "container_swap_add_failed:" .. tostring(addErr or "unknown")
    end
    if sendAddItemToContainer and addContainer then
        sendAddItemToContainer(addContainer, swappedItem)
    end

    local swappedProfile = NMDeviceProfiles.getForItem(swappedItem) or ctx.profile
    local swappedState = NMDeviceState.ensure(swappedItem, swappedProfile)
    if not swappedState then
        return false, "container_swap_state_failed"
    end
    NMDeviceState.import(swappedState, exportedState)

    ctx.item = swappedItem
    ctx.profile = swappedProfile
    ctx.state = swappedState
    ctx.itemId = tostring(swappedItem.getID and swappedItem:getID() or "")
    NMServerItemIntentTargeting.refreshRequestContext(ctx)
    return true, nil
end

function NMServerItemIntentTransition.normalizeTransportAction(action, _, _)
    return tostring(action or "")
end

function NMServerItemIntentTransition.staleRevisionRejected(ctx, action)
    if not NMServerItemIntentTransition.isTransportAction(action) then
        return false
    end
    local expected = tonumber(ctx.args and ctx.args.expectedRevision)
    if expected == nil then
        return false
    end
    local current = tonumber(ctx.state and ctx.state.revision) or 0
    if expected == current then
        return false
    end
    if NMServerItemIntentLogging.isIntentEnabled() then
        NMServerItemIntentLogging.logIntent(
            "server_transport_rejected_stale_revision",
            string.format(
                "action=%s player=%s item=%s expectedRevision=%d currentRevision=%d",
                tostring(action),
                tostring(ctx.playerName or "unknown"),
                tostring(ctx.itemFullType or "unknown"),
                tonumber(expected) or -1,
                tonumber(current) or -1
            )
        )
    end
    return true
end

function NMServerItemIntentTransition.buildPayload(ctx)
    if NMServerItemIntentTransition.isSyncAction(ctx.action) then
        return nil
    end
    return NMIntentPayloadBuilder.buildItemPayload(ctx.player, ctx.item, ctx.profile, ctx.args)
end

local function resolveSyncPlaybackMode(ctx)
    local action = tostring(ctx and ctx.action or "")
    if action == "sync_attached_world" or action == "sync_placed_world" or action == "sync_inventory_stowed" then
        return "world", "explicit_world"
    end

    local sourceMode = tostring(ctx and ctx.args and ctx.args.sourceMode or ctx and ctx.sourceModeHint or "")
    if sourceMode == "" then
        sourceMode = "off"
    end
    local resolvedOutput = "none"
    if NMDeviceProfiles and NMDeviceProfiles.resolveOutputMode then
        resolvedOutput = tostring(NMDeviceProfiles.resolveOutputMode(ctx.profile, ctx.state, sourceMode, true) or "none")
    end
    if action == "sync_portable_placed" and (resolvedOutput == "world" or resolvedOutput == "silent") then
        return "world", resolvedOutput
    end
    if resolvedOutput == "world" then
        return "world", resolvedOutput
    end
    if action == "sync_portable_attached" and resolvedOutput == "personal" then
        return "personal", resolvedOutput
    end
    if action == "sync_portable_stowed"
        and (resolvedOutput == "personal"
            or (resolvedOutput == "silent"
                and NMDeviceProfiles
                and NMDeviceProfiles.isPortableSilentProfile
                and NMDeviceProfiles.isPortableSilentProfile(ctx.profile) == true)) then
        return "personal", resolvedOutput
    end
    return "inventory", resolvedOutput
end

local function logSyncPlaybackModeResolution(ctx, oldMode, desiredMode, resolvedOutput)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("memory")) then
        return
    end
    local state = ctx and ctx.state or nil
    local profile = ctx and ctx.profile or nil
    local keep = false
    if NMRegistryPolicy and NMRegistryPolicy.shouldKeepWorldSourceState then
        keep = NMRegistryPolicy.shouldKeepWorldSourceState(state) == true
    end
    NMCore.logChannel(
        "memory",
        "server_sync_playback_mode_diag",
        string.format(
            "action=%s sourceMode=%s deviceType=%s oldPlaybackMode=%s resolvedOutput=%s resolvedPlaybackMode=%s keepWorldSource=%s",
            tostring(ctx and ctx.action or ""),
            tostring(ctx and ctx.args and ctx.args.sourceMode or ctx and ctx.sourceModeHint or ""),
            tostring(profile and profile.deviceType or "unknown"),
            tostring(oldMode or ""),
            tostring(resolvedOutput or ""),
            tostring(desiredMode or ""),
            tostring(keep)
        )
    )
end

function NMServerItemIntentTransition.applyIntentTransition(ctx, payload)
    if NMServerItemIntentTransition.isSyncAction(ctx.action) then
        local previousPlaybackMode = tostring(ctx.state.playbackMode or "")
        local desiredPlaybackMode, resolvedOutput = resolveSyncPlaybackMode(ctx)
        local changed = false
        if tostring(ctx.state.playbackMode or "") ~= desiredPlaybackMode then
            ctx.state.playbackMode = desiredPlaybackMode
            changed = true
        end
        logSyncPlaybackModeResolution(ctx, previousPlaybackMode, desiredPlaybackMode, resolvedOutput)
        return changed, nil, nil
    end
    local reducerEvent = mapActionToReducerEvent(ctx.action)
    if reducerEvent and NMServerCanonicalReducer and NMServerCanonicalReducer.dispatch then
        return NMServerCanonicalReducer.dispatch({
            eventType = reducerEvent,
            nowMs = getTimestampMs and tonumber(getTimestampMs()) or nil,
            profile = ctx.profile,
            state = ctx.state,
            intentPayload = payload
        })
    end
    return NMDeviceTransitions.apply(ctx.profile, ctx.state, ctx.action, payload)
end

return NMServerItemIntentTransition
