NMIntentPayloadBuilder = NMIntentPayloadBuilder or {}

if not NMTrackCountResolver then
    pcall(require, "playback_progression/NMTrackCountResolver")
end

local function resolveMediaPayload(inventory, itemId, itemUuid)
    if not (inventory and itemId and NMInventoryHelpers and NMInventoryHelpers.resolveItemByIdOrUuid) then
        return nil
    end
    local media = NMInventoryHelpers.resolveItemByIdOrUuid(inventory, itemId, itemUuid)
    return NMMediaHelpers.resolveMediaInsertPayload(media)
end

function NMIntentPayloadBuilder.buildItemPayload(player, item, profile, args)
    args = args or {}
    local trackCount = tonumber(args.trackCount) or 0
    if trackCount < 1 then
        local state = profile and item and NMDeviceState and NMDeviceState.ensure and NMDeviceState.ensure(item, profile) or nil
        trackCount = NMTrackCountResolver and NMTrackCountResolver.resolveFromState and NMTrackCountResolver.resolveFromState(state) or 0
    end
    local payload = {
        isOn = args.isOn,
        isPlaying = args.isPlaying,
        volume = args.volume,
        playbackMode = args.playbackMode,
        playbackPolicy = args.playbackPolicy,
        observedDurationMs = args.observedDurationMs,
        mediaItemId = args.mediaItemId,
        headphoneItemId = args.headphoneItemId,
        batteryItemId = args.batteryItemId,
        mediaFullType = nil,
        mediaCarrier = nil,
        mediaEjectFullType = nil,
        mediaCanonicalFullType = nil,
        mediaRecordedMediaIndex = nil,
        mediaDisplayName = nil,
        headphoneItemFullType = nil,
        batteryCharge = nil,
        externalPowerAvailable = NMInventoryHelpers.resolveExternalPowerAvailable(player, item, profile),
        trackCount = trackCount,
        hasTrack = trackCount > 0
    }

    local inventory = player and player.getInventory and player:getInventory() or nil
    local mediaPayload = resolveMediaPayload(inventory, args.mediaItemId, args.mediaItemUuid)
    if mediaPayload then
        payload.mediaFullType = mediaPayload.mediaFullType
        payload.mediaItemFullType = mediaPayload.mediaEjectFullType or mediaPayload.mediaFullType
        payload.mediaCarrier = mediaPayload.mediaCarrier
        payload.mediaEjectFullType = mediaPayload.mediaEjectFullType
        payload.mediaCanonicalFullType = mediaPayload.mediaCanonicalFullType
        payload.mediaRecordedMediaIndex = mediaPayload.mediaRecordedMediaIndex
        payload.mediaDisplayName = mediaPayload.mediaDisplayName
    end

    payload.requiredMediaFullType = NMMediaContract
        and NMMediaContract.resolveContainerMediaBinding
        and NMMediaContract.resolveContainerMediaBinding(item and item.getFullType and item:getFullType() or nil)
        or nil

    if inventory and args.headphoneItemId then
        local hp = NMInventoryHelpers.findItemById(inventory, args.headphoneItemId)
        if hp and hp.getFullType then
            payload.headphoneItemFullType = hp:getFullType()
        end
    end

    if inventory and args.batteryItemId then
        local bat = NMInventoryHelpers.findItemById(inventory, args.batteryItemId)
        payload.batteryCharge = NMCore.readDrainableFraction(bat, 0.0)
    end

    return payload
end

function NMIntentPayloadBuilder.buildVehiclePayload(player, vehicle, part, state, args)
    args = args or {}
    local action = tostring(args.action or "")
    local trackCount = tonumber(args.trackCount) or 0
    if trackCount < 1 then
        trackCount = NMTrackCountResolver and NMTrackCountResolver.resolveFromState and NMTrackCountResolver.resolveFromState(state) or 0
    end

    local inventory = player and player.getInventory and player:getInventory() or nil
    local mediaPayload = resolveMediaPayload(inventory, args.mediaItemId, args.mediaItemUuid)
    local allowMediaArgFallback = action ~= "insert_media"
    return {
        isOn = args.isOn,
        isPlaying = args.isPlaying,
        volume = args.volume,
        playbackMode = "world",
        playbackPolicy = args.playbackPolicy,
        observedDurationMs = args.observedDurationMs,
        mediaItemId = args.mediaItemId,
        mediaFullType = mediaPayload and mediaPayload.mediaFullType or allowMediaArgFallback and args.mediaFullType or nil,
        mediaItemFullType = mediaPayload and (mediaPayload.mediaEjectFullType or mediaPayload.mediaFullType)
            or allowMediaArgFallback and (args.mediaEjectFullType or args.mediaFullType)
            or nil,
        mediaCarrier = mediaPayload and mediaPayload.mediaCarrier or allowMediaArgFallback and args.mediaCarrier or nil,
        mediaEjectFullType = mediaPayload and mediaPayload.mediaEjectFullType or allowMediaArgFallback and args.mediaEjectFullType or nil,
        mediaCanonicalFullType = mediaPayload and mediaPayload.mediaCanonicalFullType or allowMediaArgFallback and args.mediaCanonicalFullType or nil,
        mediaRecordedMediaIndex = mediaPayload and mediaPayload.mediaRecordedMediaIndex or allowMediaArgFallback and args.mediaRecordedMediaIndex or nil,
        mediaDisplayName = mediaPayload and mediaPayload.mediaDisplayName or allowMediaArgFallback and args.mediaDisplayName or nil,
        externalPowerAvailable = NMVehicleHelpers.vehicleHasUsableBatteryPower and NMVehicleHelpers.vehicleHasUsableBatteryPower(vehicle, part) or NMVehicleHelpers.vehicleHasPower(vehicle, part),
        trackCount = trackCount,
        hasTrack = trackCount > 0
    }, trackCount
end

return NMIntentPayloadBuilder
