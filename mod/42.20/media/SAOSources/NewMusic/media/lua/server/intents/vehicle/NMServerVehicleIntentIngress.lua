if not NMServerMediaIngress then
    pcall(require, "intents/NMServerMediaIngress")
end

require "intents/vehicle/NMServerVehicleIntentLogging"

NMServerVehicleIntentIngress = NMServerVehicleIntentIngress or {}

function NMServerVehicleIntentIngress.replicateNormalizedItemMove(meta, liveItem)
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

function NMServerVehicleIntentIngress.isSourceDescriptorNearby(player, descriptor)
    local sq = player and player.getSquare and player:getSquare() or nil
    if not sq or type(descriptor) ~= "table" then
        return false
    end
    local kind = tostring(descriptor.kind or "")
    if kind == "player_inventory" then
        return true
    end
    if kind == "inventory_container_item" and descriptor.squareX == nil then
        return true
    end
    if kind == "vehicle_part_container" then
        local vehicleId = tonumber(descriptor.vehicleId)
        local vehicle = vehicleId ~= nil and getVehicleById and getVehicleById(vehicleId) or nil
        if not (vehicle and vehicle.getX and vehicle.getY and vehicle.getZ) then
            return false
        end
        local px, py, pz = sq:getX(), sq:getY(), sq:getZ()
        local dx = (tonumber(vehicle:getX()) or px) - px
        local dy = (tonumber(vehicle:getY()) or py) - py
        local dz = math.abs((tonumber(vehicle:getZ()) or pz) - pz)
        return ((dx * dx) + (dy * dy)) <= 25 and dz <= 2
    end
    local sx = tonumber(descriptor.squareX)
    local sy = tonumber(descriptor.squareY)
    local sz = tonumber(descriptor.squareZ)
    if sx == nil or sy == nil or sz == nil then
        return false
    end
    local px, py, pz = sq:getX(), sq:getY(), sq:getZ()
    local dx = sx - px
    local dy = sy - py
    local dz = math.abs(sz - pz)
    return ((dx * dx) + (dy * dy)) <= 9 and dz <= 2
end

function NMServerVehicleIntentIngress.sendVehicleLootStaleReject(player, args, descriptor, reason)
    if not (player and sendServerCommand and NMCore and NMCore.NetModule) then
        return
    end
    if tostring(reason or "") ~= "source_item_missing" then
        return
    end
    if type(descriptor) ~= "table" or tostring(descriptor.kind or "") ~= "vehicle_part_container" then
        return
    end
    sendServerCommand(player, NMCore.NetModule, "vehicle_loot_stale_reject", {
        slotTraceId = tostring(args and args.slotTraceId or ""),
        vehicleId = tostring(args and args.vehicleId or descriptor.vehicleId or ""),
        partId = tostring(args and args.partId or "Radio"),
        sourcePartId = tostring(descriptor.partId or ""),
        mediaItemId = tostring(args and args.mediaItemId or ""),
        mediaItemUuid = tostring(args and args.mediaItemUuid or ""),
        containerType = tostring(descriptor.containerType or ""),
        reason = tostring(reason or "")
    })
end

function NMServerVehicleIntentIngress.normalizeIngressArgsToMainInventory(player, args, action)
    if NMServerMediaIngress and NMServerMediaIngress.normalizeInsertArgsToMainInventory then
        return NMServerMediaIngress.normalizeInsertArgsToMainInventory(player, args, action, {
            hostTag = "vehicle",
            beginTag = "server_vehicle_normalize_begin",
            okTag = "server_vehicle_normalize_ok",
            rejectTag = "server_vehicle_normalize_reject",
            rootOkTag = "server_vehicle_normalize_root_ok",
            logSlotAuthority = NMServerVehicleIntentLogging.logSlotAuthority,
            describeSourceDescriptorArgs = NMServerVehicleIntentLogging.describeSourceDescriptorArgs,
            isSourceDescriptorNearby = NMServerVehicleIntentIngress.isSourceDescriptorNearby,
            replicateNormalizedItemMove = NMServerVehicleIntentIngress.replicateNormalizedItemMove,
            traceContext = {
                host = "vehicle",
                slotTraceId = tostring(args and args.slotTraceId or "")
            },
            onSourceResolveReject = function(targetPlayer, targetArgs, descriptor, reason)
                NMServerVehicleIntentIngress.sendVehicleLootStaleReject(targetPlayer, targetArgs, descriptor, reason)
            end,
            logTraceReject = function(targetArgs, act, reason)
                NMServerVehicleIntentLogging.logVehicleSlotTrace(
                    "vehicle_slot_transfer",
                    string.format(
                        "trace=%s host=vehicle ui=vehicle action=%s stage=transfer result=reject reason=%s vehicleId=%s partId=%s",
                        tostring(targetArgs and targetArgs.slotTraceId or ""),
                        tostring(act),
                        tostring(reason or "normalize_failed"),
                        tostring(targetArgs and targetArgs.vehicleId or ""),
                        tostring(targetArgs and targetArgs.partId or "")
                    )
                )
            end
        })
    end
    return false, "normalize_helper_missing"
end

return NMServerVehicleIntentIngress
