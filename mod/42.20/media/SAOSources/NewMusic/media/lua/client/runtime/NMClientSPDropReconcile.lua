require "runtime/NMClientPlacedWorldCandidate"

NMClientSPDropReconcile = NMClientSPDropReconcile or {}

local function detachGroundPersonalHeadphones(state)
    local current = tostring(state and state.headphoneItemFullType or "")
    if not (state and NMInsertedHeadphonePolicy and NMInsertedHeadphonePolicy.shouldDetachOnGround(current)) then
        return false
    end
    state.headphoneItemFullType = nil
    return true
end

local function upsertLocalPlacedTrackedContinuity(item, state, profileType, key, placedCandidate)
    if not (item and state and NMClientWorldSourceCache and NMClientWorldSourceCache.upsertFromPayload) then
        return false
    end
    local sourceItem = placedCandidate and placedCandidate.item or item
    local square = placedCandidate and placedCandidate.square or nil
    if not square then
        local worldItem = sourceItem and sourceItem.getWorldItem and sourceItem:getWorldItem() or nil
        square = worldItem and worldItem.getSquare and worldItem:getSquare() or nil
    end
    if not square then
        return false
    end
    detachGroundPersonalHeadphones(state)
    state.playbackMode = "world"
    NMClientWorldSourceCache.upsertFromPayload({
        uuid = key,
        kind = "item",
        profileType = profileType,
        state = NMDeviceState.export and NMDeviceState.export(state) or state,
        sourceMode = "placed",
        x = square:getX() + 0.5,
        y = square:getY() + 0.5,
        z = square:getZ(),
        itemId = NMCore.itemId and NMCore.itemId(sourceItem) or nil,
        itemFullType = sourceItem and sourceItem.getFullType and sourceItem:getFullType() or nil,
        sourceEpoch = tonumber(state.sourceGeneration) or 0,
        sourceGeneration = tonumber(state.sourceGeneration) or 0,
        ownerId = tostring(state.sourceOwner or "")
    })
    return true
end

local function requestImmediateDropRefresh(reason)
    local why = tostring(reason or "sp_drop_reconcile")
    if NMClientMainRuntime and NMClientMainRuntime.requestTickGateWake then
        NMClientMainRuntime.requestTickGateWake("sp_drop_" .. why)
    end
    if NMClientPlaybackTick and NMClientPlaybackTick.requestFullPass then
        NMClientPlaybackTick.requestFullPass("sp_drop_" .. why)
    elseif NMClientPlaybackTick and NMClientPlaybackTick.markDirty then
        NMClientPlaybackTick.markDirty("sp_drop_" .. why)
    end
    if NMClientMainRuntime and NMClientMainRuntime.requestVisualRefresh then
        NMClientMainRuntime.requestVisualRefresh("sp_drop_" .. why)
    end
end

function NMClientSPDropReconcile.reconcile(args)
    local input = type(args) == "table" and args or {}
    local player = input.player
    local currentInventoryByUuid = input.currentInventoryByUuid or {}
    local previousInventoryByUuid = input.previousInventoryByUuid or {}
    local logTransitionProbe = input.logTransitionProbe
    if not player then
        return previousInventoryByUuid
    end

    if NMCore.isMPClientRuntime and NMCore.isMPClientRuntime() then
        if NMClientPortableDropHandoff and NMClientPortableDropHandoff.reconcilePending then
            NMClientPortableDropHandoff.reconcilePending(player, currentInventoryByUuid)
        end
        for uuid, prevItem in pairs(previousInventoryByUuid) do
            local key = tostring(uuid or "")
            if key ~= "" and (not currentInventoryByUuid[key]) then
                local item = prevItem
                local profile = item and NMDeviceProfiles.getForItem and NMDeviceProfiles.getForItem(item) or nil
                local state = item and profile and NMDeviceState.ensure and NMDeviceState.ensure(item, profile) or nil
                local shouldKeep = state and NMRegistryPolicy and NMRegistryPolicy.shouldKeepWorldSourceState and NMRegistryPolicy.shouldKeepWorldSourceState(state) or false
                local placedCandidate = NMClientPlacedWorldCandidate and NMClientPlacedWorldCandidate.resolve
                    and NMClientPlacedWorldCandidate.resolve(player, item, key)
                    or nil
                local square = placedCandidate and placedCandidate.square or nil
                if state then
                    detachGroundPersonalHeadphones(state)
                end
                local portableTrackedDrop = profile
                    and state
                    and square
                    and state.isOn == true
                    and state.isPlaying == true
                    and NMDeviceProfiles.isPortableTrackedProfile
                    and NMDeviceProfiles.isPortableTrackedProfile(profile)
                if portableTrackedDrop and NMClientModeSync and NMClientModeSync.emitExplicit then
                    upsertLocalPlacedTrackedContinuity(
                        item,
                        state,
                        item and item.getFullType and item:getFullType() or nil,
                        key,
                        placedCandidate
                    )
                    NMClientModeSync.emitExplicit(player, item, state, "sync_portable_placed", "placed")
                    requestImmediateDropRefresh("mp_portable_placed")
                elseif profile
                    and state
                    and state.isOn == true
                    and state.isPlaying == true
                    and NMDeviceProfiles.isPortableTrackedProfile
                    and NMDeviceProfiles.isPortableTrackedProfile(profile)
                    and NMClientPortableDropHandoff
                    and NMClientPortableDropHandoff.beginPending then
                    NMClientPortableDropHandoff.beginPending(
                        player,
                        item,
                        state,
                        item and item.getFullType and item:getFullType() or nil,
                        key
                    )
                elseif profile and state and shouldKeep and NMClientModeSync and NMClientModeSync.emitExplicit then
                    if NMDeviceProfiles.canPlacedWorldPlayback(profile) then
                        NMClientModeSync.emitExplicit(player, item, state, "sync_placed_world", "placed")
                    elseif NMDeviceProfiles.canAnyWorldPlayback(profile) then
                        NMClientModeSync.emitExplicit(player, item, state, "sync_inventory_stowed", "stowed")
                    end
                end
            end
        end
        return currentInventoryByUuid
    end

    for uuid, prevItem in pairs(previousInventoryByUuid) do
        local key = tostring(uuid or "")
        if key ~= "" and (not currentInventoryByUuid[key]) then
            local active = NMPlaybackRuntime and NMPlaybackRuntime.Active and NMPlaybackRuntime.Active[key] or nil
            local cached = NMClientWorldSourceCache and NMClientWorldSourceCache.get and NMClientWorldSourceCache.get(key) or nil
            if active and (not cached) then
                local item = prevItem
                local profile = item and NMDeviceProfiles.getForItem and NMDeviceProfiles.getForItem(item) or nil
                local state = item and profile and NMDeviceState.ensure and NMDeviceState.ensure(item, profile) or nil
                local placedCandidate = NMClientPlacedWorldCandidate and NMClientPlacedWorldCandidate.resolve
                    and NMClientPlacedWorldCandidate.resolve(player, item, key)
                    or nil
                local square = placedCandidate and placedCandidate.square or nil
                local sourceItem = placedCandidate and placedCandidate.item or item
                if state then
                    detachGroundPersonalHeadphones(state)
                end
                if profile and state and square and NMDeviceProfiles.isPortableTrackedProfile and NMDeviceProfiles.isPortableTrackedProfile(profile) and state.isOn == true and state.isPlaying == true then
                    state.playbackMode = "world"
                    upsertLocalPlacedTrackedContinuity(
                        item,
                        state,
                        item and item.getFullType and item:getFullType() or nil,
                        key,
                        placedCandidate
                    )
                    NMWorldRegistrySnapshot.upsertSP({
                        kind = "item",
                        uuid = key,
                        profileType = item and item.getFullType and item:getFullType() or nil,
                        sourceMode = "placed",
                        sourceEpoch = tonumber(state.sourceGeneration) or 0,
                        x = square:getX() + 0.5,
                        y = square:getY() + 0.5,
                        z = square:getZ(),
                        itemId = NMCore.itemId and NMCore.itemId(sourceItem) or nil,
                        itemFullType = sourceItem and sourceItem.getFullType and sourceItem:getFullType() or nil,
                        state = NMDeviceState.export(state),
                        revision = tonumber(state.revision) or 0,
                        playbackEpoch = tonumber(state.playbackEpoch) or 0
                    })
                    requestImmediateDropRefresh("sp_portable_placed")
                elseif profile and state and square and NMDeviceProfiles.canPlacedWorldPlayback(profile) then
                    state.playbackMode = "world"
                    NMClientWorldSourceCache.upsertFromPayload({
                        uuid = key,
                        kind = "item",
                        profileType = item and item.getFullType and item:getFullType() or nil,
                        state = state,
                        sourceMode = "placed",
                        x = square:getX() + 0.5,
                        y = square:getY() + 0.5,
                        z = square:getZ(),
                        itemId = NMCore.itemId and NMCore.itemId(sourceItem) or nil,
                        itemFullType = sourceItem and sourceItem.getFullType and sourceItem:getFullType() or nil,
                        sourceEpoch = tonumber(state.sourceGeneration) or 0
                    })
                    NMWorldRegistrySnapshot.upsertSP({
                        kind = "item",
                        uuid = key,
                        profileType = item and item.getFullType and item:getFullType() or nil,
                        sourceMode = "placed",
                        sourceEpoch = tonumber(state.sourceGeneration) or 0,
                        x = square:getX() + 0.5,
                        y = square:getY() + 0.5,
                        z = square:getZ(),
                        itemId = NMCore.itemId and NMCore.itemId(sourceItem) or nil,
                        itemFullType = sourceItem and sourceItem.getFullType and sourceItem:getFullType() or nil,
                        state = NMDeviceState.export(state),
                        revision = tonumber(state.revision) or 0,
                        playbackEpoch = tonumber(state.playbackEpoch) or 0
                    })
                    requestImmediateDropRefresh("sp_world_placed")
                    if logTransitionProbe then
                        logTransitionProbe(
                            "ownership_conflict_resolved",
                            string.format("uuid=%s winner=placed_reconcile detachedCtx=placed", key)
                        )
                    end
                end
            end
        end
    end

    return currentInventoryByUuid
end

return NMClientSPDropReconcile

