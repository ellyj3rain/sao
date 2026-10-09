NMServerDeviceDisassembly = NMServerDeviceDisassembly or {}

local function removeWorldItem(item)
    local worldItem = item and item.getWorldItem and item:getWorldItem() or nil
    local square = worldItem and worldItem.getSquare and worldItem:getSquare() or nil
    if square and square.transmitRemoveItemFromSquare then
        square:transmitRemoveItemFromSquare(worldItem)
        return true
    end
    return false
end

local function playerHasScrewdriver(player)
    local screwdriver = NMDeviceDisassembly and NMDeviceDisassembly.findScrewdriverInInventory
        and NMDeviceDisassembly.findScrewdriverInInventory(player) or nil
    return screwdriver ~= nil
end

local function broadcastRegistryRemove(entry, state)
    if not (entry and entry.uuid and NMServerRegistryBroadcast and NMServerRegistryBroadcast.broadcastEntry and NMServerRegistryState and NMServerRegistryState.worldRegistry) then
        return
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
    NMServerRegistryBroadcast.broadcastEntry(NMServerRegistryState.worldRegistry, tostring(entry.uuid), nil, state, "remove", recipients)
end

local function resolveTargetItem(player, args)
    local inv = player and player.getInventory and player:getInventory() or nil
    local itemId = tostring(args and args.itemId or "")
    local uuid = tostring(args and args.uuid or "")

    if inv and itemId ~= "" then
        local found = NMInventoryHelpers.findItemById(inv, itemId)
        if found then
            return found
        end
    end
    if inv and uuid ~= "" then
        local found = NMInventoryHelpers.findItemByUuid(inv, uuid)
        if found then
            return found
        end
    end
    if player and itemId ~= "" then
        local found = NMInventoryHelpers.findWorldItemByIdNearPlayer(player, itemId, 8)
        if found then
            return found
        end
    end
    if player and uuid ~= "" then
        local found = NMInventoryHelpers.findWorldItemByUuidNearPlayer(player, uuid, 8)
        if found then
            return found
        end
    end
    return nil
end

local function replicateNormalizedItemMove(meta, liveItem)
    if not (meta and meta.moved == true and liveItem) then
        return
    end
    local sourceItem = meta.sourceItem or liveItem
    local targetItem = meta.targetItem or liveItem
    if sendRemoveItemFromContainer and meta.sourceContainer and sourceItem then
        sendRemoveItemFromContainer(meta.sourceContainer, sourceItem)
    end
    if sendAddItemToContainer and meta.targetContainer and targetItem then
        sendAddItemToContainer(meta.targetContainer, targetItem)
    end
end

local function normalizeInventoryItemToRoot(player, item)
    local inv = player and player.getInventory and player:getInventory() or nil
    if not (player and inv and item) then
        return item, nil
    end
    local container = item.getContainer and item:getContainer() or nil
    if container == inv then
        return item, nil
    end
    local itemId = NMCore and NMCore.itemId and NMCore.itemId(item) or nil
    local uuid = NMInventoryHelpers and NMInventoryHelpers.getItemStateUuid and NMInventoryHelpers.getItemStateUuid(item) or nil
    if not (NMInventoryHelpers and NMInventoryHelpers.normalizeItemToMainInventory) then
        return nil, "normalize_helper_missing"
    end
    local liveItem, err, meta = NMInventoryHelpers.normalizeItemToMainInventory(player, itemId, uuid)
    if not liveItem then
        return nil, err or "normalize_failed"
    end
    replicateNormalizedItemMove(meta, liveItem)
    return liveItem, nil
end

local function removeInventoryItemWithReplication(inventory, item)
    if not (inventory and item) then
        return false, "invalid_remove_args"
    end
    local container = item.getContainer and item:getContainer() or nil
    local ownerContainer = container or inventory
    if sendRemoveItemFromContainer and ownerContainer then
        sendRemoveItemFromContainer(ownerContainer, item)
    end
    if container and container.DoRemoveItem then
        container:DoRemoveItem(item)
        return true, nil
    end
    if inventory.Remove then
        inventory:Remove(item)
        return true, nil
    end
    return false, "source_remove_failed"
end

local function detachGroundHeadphones(state)
    local current = tostring(state and state.headphoneItemFullType or "")
    if NMInsertedHeadphonePolicy
        and NMInsertedHeadphonePolicy.isGroundContext
        and NMInsertedHeadphonePolicy.isGroundContext("placed")
        and NMInsertedHeadphonePolicy.shouldDetachOnGround
        and NMInsertedHeadphonePolicy.shouldDetachOnGround(current) then
        state.headphoneItemFullType = nil
        return true
    end
    return false
end

local function cleanupDestroyedDevice(player, state)
    if not state then
        return nil
    end
    local uuid = tostring(state.deviceUUID or "")
    if uuid ~= "" and NMPlaybackRuntime and NMPlaybackRuntime.forceStop then
        pcall(NMPlaybackRuntime.forceStop, player, uuid, "device_disassembled")
    end
    if NMTransitionCommon and NMTransitionCommon.setStopped then
        NMTransitionCommon.setStopped(state, "device_disassembled")
    else
        state.isPlaying = false
        state.desiredIsPlaying = false
        state.lastStopReason = "device_disassembled"
    end
    state.isOn = false
    state.desiredIsOn = false
    state.playbackMode = "inventory"
    state.authoritativeMode = "off"
    state.sourceOwner = nil
    state.sourceX = nil
    state.sourceY = nil
    state.sourceZ = nil
    state.mediaFullType = nil
    state.mediaEjectFullType = nil
    state.mediaRecordedMediaIndex = nil
    detachGroundHeadphones(state)
    state.headphoneItemFullType = nil
    state.batteryPresent = false
    state.batteryCharge = 0.0
    if NMServerTrackTimeline and NMServerTrackTimeline.clear then
        local entry = uuid ~= "" and NMServerRegistryState and NMServerRegistryState.worldRegistry and NMServerRegistryState.worldRegistry[uuid] or nil
        NMServerTrackTimeline.clear(entry, state)
    end
    if NMDeviceState and NMDeviceState.bumpRevision then
        NMDeviceState.bumpRevision(state)
    end
    if uuid ~= "" and NMServerRegistryState and NMServerRegistryState.worldRegistry then
        local entry = NMServerRegistryState.worldRegistry[uuid]
        if entry then
            broadcastRegistryRemove(entry, state)
            NMServerRegistryState.worldRegistry[uuid] = nil
        end
    end
    return uuid ~= "" and uuid or nil
end

local function applyPlanToInventoryWithReplication(player, inventory, plan)
    local function onItemAdded(item)
        if sendAddItemToContainer then
            sendAddItemToContainer(inventory, item)
        end
    end
    return NMDeviceDisassembly.applyPlanToInventory(player, inventory, plan, {
        onItemAdded = onItemAdded
    })
end

function NMServerDeviceDisassembly.perform(player, args)
    if not player then
        return false
    end
    if NMDeviceDisassembly.isEnabled() ~= true then
        return false
    end
    if not playerHasScrewdriver(player) then
        return false
    end

    local item = resolveTargetItem(player, args or {})
    if not item then
        return false
    end
    local inv = player.getInventory and player:getInventory() or nil
    local isInventoryItem = inv ~= nil and item.getContainer and item:getContainer() ~= nil
    if isInventoryItem then
        local normalizedItem = normalizeInventoryItemToRoot(player, item)
        item = normalizedItem
        if not item then
            return false
        end
    end

    local profile = NMDeviceProfiles.getForItem and NMDeviceProfiles.getForItem(item) or nil
    if not (profile and NMDeviceDisassembly.canDisassembleItem(item, profile)) then
        return false
    end
    local state = NMDeviceState.ensure(item, profile)
    local plan = NMDeviceDisassembly.buildPlan(player, item, profile, state)
    if not plan then
        return false
    end

    cleanupDestroyedDevice(player, state)

    if isInventoryItem then
        if not inv then
            return false
        end
        local removed = removeInventoryItemWithReplication(inv, item)
        if not removed then
            return false
        end
        local ok = applyPlanToInventoryWithReplication(player, inv, plan)
        if not ok then
            return false
        end
        return true
    end

    if not removeWorldItem(item) then
        return false
    end
    if not inv then
        return false
    end
    local ok = applyPlanToInventoryWithReplication(player, inv, plan)
    if not ok then
        return false
    end
    return true
end
