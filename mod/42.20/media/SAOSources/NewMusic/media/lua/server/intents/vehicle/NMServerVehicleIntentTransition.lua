require "intents/vehicle/NMServerVehicleIntentLogging"

NMServerVehicleIntentTransition = NMServerVehicleIntentTransition or {}

local function isPowerOnRequest(action)
    return tostring(action or "") == "power_on"
end

function NMServerVehicleIntentTransition.applyTransitionOps(player, inventory, ops)
    return NMIntentInventoryOps.applyTransitionOps(player, inventory, ops, {
        onConsume = function(kind, itemId, container, consumed)
            if kind == "media" and NMServerVehicleIntentLogging.isSlotEnabled() then
                NMServerVehicleIntentLogging.logSlotAuthority(
                    "server_vehicle_consume_media_ok",
                    string.format(
                        "itemId=%s consumedFullType=%s containerType=%s",
                        tostring(itemId or ""),
                        tostring(consumed and consumed.getFullType and consumed:getFullType() or ""),
                        tostring(container and container.getType and container:getType() or "")
                    )
                )
            end
            if sendRemoveItemFromContainer and container and consumed then
                sendRemoveItemFromContainer(container, consumed)
            end
        end,
        onConsumeFail = function(kind, itemId, err)
            if kind == "media" and NMServerVehicleIntentLogging.isSlotEnabled() then
                NMServerVehicleIntentLogging.logSlotAuthority(
                    "server_vehicle_consume_media_fail",
                    "itemId=" .. tostring(itemId or "") .. " reason=" .. tostring(err or "")
                )
            end
        end,
        onProduce = function(kind, fullType, _, container, out)
            if kind == "media" and NMServerVehicleIntentLogging.isSlotEnabled() then
                NMServerVehicleIntentLogging.logSlotAuthority(
                    "server_vehicle_produce_media_ok",
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
                sendAddItemToContainer(container, out)
            end
        end,
        onProduceFail = function(kind, fullType, _, err)
            if kind == "media" and NMServerVehicleIntentLogging.isSlotEnabled() then
                NMServerVehicleIntentLogging.logSlotAuthority(
                    "server_vehicle_produce_media_fail",
                    "fullType=" .. tostring(fullType or "") .. " reason=" .. tostring(err or "")
                )
            end
        end
    })
end

function NMServerVehicleIntentTransition.buildPayload(ctx)
    local payload, trackCount = NMIntentPayloadBuilder.buildVehiclePayload(
        ctx.player,
        ctx.vehicle,
        ctx.part,
        ctx.state,
        ctx.args
    )
    ctx.trackCount = trackCount
    ctx.state.trackCount = math.max(0, math.floor(trackCount or 0))
    return payload
end

function NMServerVehicleIntentTransition.validatePayload(ctx, payload)
    if isPowerOnRequest(ctx.action) and payload.externalPowerAvailable ~= true then
        return false, "vehicle_battery_unavailable"
    end
    return true
end

function NMServerVehicleIntentTransition.applyIntentTransition(ctx, payload)
    return NMDeviceTransitions.apply(ctx.profile, ctx.state, ctx.action, payload)
end

function NMServerVehicleIntentTransition.afterApplyTransition(ctx, _, changed, reason, ops)
    if ctx.part
        and ctx.profile.vehicleUsesCarBattery
        and ctx.state.isOn
        and not (NMVehicleHelpers and NMVehicleHelpers.vehicleHasPower and NMVehicleHelpers.vehicleHasPower(ctx.vehicle, ctx.part)) then
        ctx.state.isOn = false
        ctx.state.desiredIsOn = false
        ctx.state.isPlaying = false
        ctx.state.desiredIsPlaying = false
        ctx.state.lastStopReason = "vehicle_battery_empty"
        changed = true
    end
    return changed, reason, ops
end

return NMServerVehicleIntentTransition
