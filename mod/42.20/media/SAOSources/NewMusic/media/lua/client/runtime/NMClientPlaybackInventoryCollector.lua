-- Helpers for collecting managed inventory devices and normalizing rebound state.
NMClientPlaybackInventoryCollector = NMClientPlaybackInventoryCollector or {}

local function collectManagedFromContainer(container, out)
    if not container or not container.getItems then
        return
    end
    local items = container:getItems()
    if not items then
        return
    end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            local profile = NMDeviceProfiles.getForItem(item)
            if profile then
                local state = NMDeviceState.ensure(item, profile)
                if state and state.deviceUUID then
                    local itemMd = item.getModData and item:getModData() or nil
                    if itemMd and itemMd.nmCorpseRecovered == true then
                        state._nmCorpseRecovered = true
                    end
                    out[#out + 1] = {
                        item = item,
                        profile = profile,
                        state = state,
                        uuid = tostring(state.deviceUUID)
                    }
                end
            end
            if item.IsInventoryContainer and item:IsInventoryContainer() then
                collectManagedFromContainer(item:getInventory(), out)
            end
        end
    end
end

function NMClientPlaybackInventoryCollector.collectManaged(player, out)
    if not (player and player.getInventory and out) then
        return out
    end
    collectManagedFromContainer(player:getInventory(), out)
    return out
end

function NMClientPlaybackInventoryCollector.normalizeCorpseRecoveredInventoryState(item, profile, state, uuid, options)
    if not (item and profile and state and uuid and uuid ~= "") then
        return false
    end
    if not (NMDeviceProfiles and NMDeviceProfiles.isPortableTrackedProfile and NMDeviceProfiles.isPortableTrackedProfile(profile) == true) then
        return false
    end
    local itemMd = item and item.getModData and item:getModData() or nil
    local corpseRecovered = state._nmCorpseRecovered == true
        or tostring(state.lastStopReason or "") == "corpse_reconcile"
        or (itemMd and itemMd.nmCorpseRecovered == true)

    local reboundSeen = options and options.corpseInventoryReboundSeen or nil
    if corpseRecovered ~= true then
        if reboundSeen then
            reboundSeen[uuid] = nil
        end
        return false
    end

    if reboundSeen and reboundSeen[uuid] == true then
        return false
    end
    if reboundSeen then
        reboundSeen[uuid] = true
    end

    local cleanupRuntime = options and options.cleanupRuntime or nil
    if type(cleanupRuntime) == "function" then
        cleanupRuntime(uuid, state, item)
    end

    state.authoritativeMode = "off"
    state.sourceKind = "inventory"
    state.sourceOwner = nil
    state.sourceX = nil
    state.sourceY = nil
    state.sourceZ = nil
    state.sourceGeneration = 0
    state.playbackMode = "inventory"
    state.zombieDormant = false
    state.zombieDormantReason = nil
    state.zombieDormantStrategy = nil
    state._nmCorpseRecovered = nil
    if tostring(state.lastStopReason or "") == "corpse_reconcile" then
        state.lastStopReason = "corpse_recovered_stopped"
    end
    if itemMd then
        itemMd.nmCorpseRecovered = nil
        itemMd.nmCorpseRecoveredFullType = nil
        itemMd.nmCorpseRecoveredDeviceUUID = nil
    end

    local logRuntime = options and options.logRuntime or nil
    if logRuntime then
        logRuntime(
            "corpse_inventory_rebind",
            string.format(
                "uuid=%s playbackMode=%s media=%s headphones=%s sourceKind=%s sourceGeneration=%s",
                tostring(uuid),
                tostring(state.playbackMode or ""),
                tostring(state.mediaFullType or "nil"),
                tostring(state.headphoneItemFullType or "nil"),
                tostring(state.sourceKind or ""),
                tostring(state.sourceGeneration or 0)
            )
        )
    end

    if reboundSeen then
        reboundSeen[uuid] = nil
    end

    return true
end

return NMClientPlaybackInventoryCollector
