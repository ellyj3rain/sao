require "intents/item/NMServerItemIntentLogging"

NMServerItemIntentIngress = NMServerItemIntentIngress or {}

function NMServerItemIntentIngress.isSourceDescriptorNearby(player, descriptor)
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
    local maxDistSq = kind == "vehicle_part_container" and 25 or 9
    return ((dx * dx) + (dy * dy)) <= maxDistSq and dz <= 2
end

function NMServerItemIntentIngress.replicateNormalizedItemMove(meta, liveItem)
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

function NMServerItemIntentIngress.normalizeIngressArgsToMainInventory(player, args, action)
    if NMServerMediaIngress and NMServerMediaIngress.normalizeInsertArgsToMainInventory then
        return NMServerMediaIngress.normalizeInsertArgsToMainInventory(player, args, action, {
            hostTag = "item",
            beginTag = "server_item_normalize_begin",
            okTag = "server_item_normalize_ok",
            rejectTag = "server_item_normalize_reject",
            rootOkTag = "server_item_normalize_root_ok",
            logSlotAuthority = NMServerItemIntentLogging.logSlotAuthority,
            describeSourceDescriptorArgs = NMServerItemIntentLogging.describeSourceDescriptorArgs,
            isSourceDescriptorNearby = NMServerItemIntentIngress.isSourceDescriptorNearby,
            replicateNormalizedItemMove = NMServerItemIntentIngress.replicateNormalizedItemMove
        })
    end
    return false, "normalize_helper_missing"
end

return NMServerItemIntentIngress
