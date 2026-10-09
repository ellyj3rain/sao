-- Server command router for NM net module and intent dispatch.
NMServerIntentRouter = NMServerIntentRouter or {}

local function isDebugControlAllowed(player)
    if not player then
        return false
    end
    local access = player.getAccessLevel and tostring(player:getAccessLevel() or "") or ""
    if access ~= "" and string.lower(access) ~= "none" then
        return true
    end
    return true
end

local function broadcastDebugSync(enabled, scope)
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if not players or not sendServerCommand then
        return
    end
    for i = 0, players:size() - 1 do
        local p = players:get(i)
        if p then
            sendServerCommand(p, NMCore.NetModule, "debug_sync", {
                enabled = enabled == true,
                subsystem = tostring(scope or "")
            })
        end
    end
end

local function sendRegistrySnapshot(player)
    if not player or not sendServerCommand then
        return
    end
    local count = 0
    for _, entry in pairs(NMServerRegistryState.worldRegistry) do
        count = count + 1
        local sessionToken = NMServerBootReset and NMServerBootReset.getSessionToken and NMServerBootReset.getSessionToken() or nil
        sendServerCommand(player, NMCore.NetModule, "registry_update", {
            op = "upsert",
            serverSessionToken = sessionToken,
            payload = {
                kind = tostring(entry.kind or "item"),
                uuid = tostring(entry.uuid or ""),
                itemId = entry.itemId,
                itemFullType = entry.itemFullType,
                vehicleId = entry.vehicleId,
                vehicleIdHint = entry.vehicleIdHint or entry.vehicleId,
                ownerId = entry.ownerId or entry.ownerOnlineId or entry.ownerUsername,
                partId = entry.partId,
                profileType = entry.profileType,
                x = entry.x,
                y = entry.y,
                z = entry.z,
                sourceMode = entry.sourceMode,
                sourceEpoch = entry.sourceEpoch,
                sourceGeneration = math.max(
                    tonumber(entry.sourceEpoch) or 0,
                    tonumber(entry.sourceGeneration) or 0,
                    tonumber(entry.stateSnapshot and entry.stateSnapshot.sourceGeneration) or 0
                ),
                sourceRebind = entry.sourceRebind == true,
                rebindReason = entry.rebindReason ~= nil and tostring(entry.rebindReason) or nil,
                windowsOpen = entry.windowsOpen == true,
                state = entry.stateSnapshot
            }
        })
    end
    local sessionToken = NMServerBootReset and NMServerBootReset.getSessionToken and NMServerBootReset.getSessionToken() or nil
    sendServerCommand(player, NMCore.NetModule, "registry_sync_ack", { count = count, serverSessionToken = sessionToken })
end

local function sendInventoryStateSnapshot(player)
    if not player or not sendServerCommand then
        return
    end
    local inv = player.getInventory and player:getInventory() or nil
    if not inv then
        return
    end
    local items = {}
    NMInventoryHelpers.collectItemsRecursive(inv, items)
    local count = 0
    local skippedZombieDormant = 0
    for i = 1, #items do
        local item = items[i]
        local profile = item and NMDeviceProfiles.getForItem and NMDeviceProfiles.getForItem(item) or nil
        if profile then
            local state = NMDeviceState.ensure(item, profile)
            if state then
                if NMServerBootReset and NMServerBootReset.normalizeState then
                    NMServerBootReset.normalizeState(state, "item", tostring(state.deviceUUID or item:getID() or ""))
                end
                if NMDeviceState and NMDeviceState.isZombieDormant and NMDeviceState.isZombieDormant(state) then
                    skippedZombieDormant = skippedZombieDormant + 1
                    if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
                        NMCore.logChannel(
                            "runtime",
                            "server_inventory_sync_skip_zombie_dormant",
                            string.format(
                                "player=%s itemId=%s uuid=%s item=%s",
                                tostring(player and player.getUsername and player:getUsername() or "unknown"),
                                tostring(item:getID() or ""),
                                tostring(state.deviceUUID or ""),
                                tostring(item:getFullType() or "unknown")
                            )
                        )
                    end
                else
                    sendServerCommand(player, NMCore.NetModule, "state", {
                        itemId = tostring(item:getID() or ""),
                        uuid = tostring(state.deviceUUID or ""),
                        itemFullType = tostring(item:getFullType() or ""),
                        state = NMDeviceState.export(state),
                        serverSessionToken = NMServerBootReset and NMServerBootReset.getSessionToken and NMServerBootReset.getSessionToken() or nil
                    })
                    count = count + 1
                end
            end
        end
    end
    if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
        NMCore.logChannel(
            "runtime",
            "server_inventory_sync_sent",
            string.format(
                "player=%s count=%d skippedZombieDormant=%d",
                tostring(player and player.getUsername and player:getUsername() or "unknown"),
                tonumber(count) or 0,
                tonumber(skippedZombieDormant) or 0
            )
        )
    end
end

function NMServerIntentRouter.onClientCommand(module, command, player, args)
    if module ~= NMCore.NetModule then
        return false
    end

    if command == "request_registry_sync" then
        sendRegistrySnapshot(player)
        return true
    end
    if command == "request_inventory_state_sync" then
        sendInventoryStateSnapshot(player)
        return true
    end
    if command == "media_flip" then
        if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
            NMCore.logChannel(
                "runtime",
                "flip_server_receive",
                string.format(
                    "player=%s itemId=%s",
                    tostring(player and player.getUsername and player:getUsername() or "unknown"),
                    tostring(args and args.itemId or "")
                )
            )
        end
        return NMServerLooseMediaHandlers.flipMediaSide(player, args)
    end
    if command == "device_disassemble" then
        return NMServerDeviceDisassembly.perform(player, args)
    end
    if command == "loot_probe_client_visible_vanilla_disc" then
        if NMServerLootProbe and NMServerLootProbe.inspectClientVisibleVanillaDisc then
            NMServerLootProbe.inspectClientVisibleVanillaDisc(player, args or {})
        end
        return true
    end
    if command == "repair_visible_vanilla_media" then
        if NMServerLootProbe and NMServerLootProbe.repairVisibleVanillaMedia then
            NMServerLootProbe.repairVisibleVanillaMedia(player, args or {})
        end
        return true
    end

    if command == "debug_set" then
        if not isDebugControlAllowed(player) then
            return true
        end
        local enabled = args and args.enabled == true
        local subsystem = tostring(args and args.subsystem or "")
        NMCore.setSubsystemDebugEnabled(subsystem, enabled)
        if subsystem == "loot_probe"
            and NMServerSandboxLootController
            and NMServerSandboxLootController.refreshLootProbeForDebugState
        then
            NMServerSandboxLootController.refreshLootProbeForDebugState("debug_set")
        end
        if NMCore and NMCore.logChannel then
            NMCore.logChannel(
                "core",
                "server_debug_set",
                string.format(
                    "player=%s enabled=%s subsystem=%s authority=%s",
                    tostring(player and player.getUsername and player:getUsername() or "unknown"),
                    tostring(enabled),
                    tostring(subsystem),
                    tostring(NMCore.getRuntimeAuthorityMode and NMCore.getRuntimeAuthorityMode() or "unknown")
                )
            )
        end
        broadcastDebugSync(enabled, subsystem)
        return true
    end
    if command ~= "intent" or not args or not args.action then
        return true
    end

    local action = tostring(args.action)
    if action == "sync_attached_world" then
        return NMServerItemIntentHandlers.handleSyncAttachedWorld(player, args)
    end
    if action == "sync_placed_world" then
        return NMServerItemIntentHandlers.handleSyncPlacedWorld(player, args)
    end
    if action == "sync_inventory_stowed" then
        return NMServerItemIntentHandlers.handleSyncInventoryStowed(player, args)
    end
    if action == "sync_portable_attached" then
        return NMServerItemIntentHandlers.handleSyncPortableAttached(player, args)
    end
    if action == "sync_portable_placed" then
        return NMServerItemIntentHandlers.handleSyncPortablePlaced(player, args)
    end
    if action == "sync_portable_stowed" then
        return NMServerItemIntentHandlers.handleSyncPortableStowed(player, args)
    end
    if action == "track_finished_world" then
        return NMServerItemIntentHandlers.handleTrackFinishedWorld(player, args)
    end

    if args.vehicleId ~= nil then
        return NMServerVehicleIntentHandlers.applyVehicleIntent(player, args)
    end
    return NMServerItemIntentHandlers.applyItemIntent(player, args)
end

