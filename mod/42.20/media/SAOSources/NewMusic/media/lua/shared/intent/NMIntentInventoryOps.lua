NMIntentInventoryOps = NMIntentInventoryOps or {}

local function emitHook(hooks, hookName, ...)
    local fn = hooks and hooks[hookName] or nil
    if type(fn) == "function" then
        fn(...)
    end
end

function NMIntentInventoryOps.removeItemById(inventory, itemId)
    local id = tostring(itemId or "")
    if not inventory or id == "" then
        return false, "invalid_remove_args", nil, nil
    end
    local item = NMInventoryHelpers.findItemById(inventory, id)
    if not item then
        return false, "source_item_not_found", nil, nil
    end
    local container = item.getContainer and item:getContainer() or nil
    if container and container.DoRemoveItem then
        container:DoRemoveItem(item)
        return true, nil, container, item
    end
    if inventory.Remove then
        inventory:Remove(item)
        return true, nil, inventory, item
    end
    return false, "source_remove_failed", nil, nil
end

function NMIntentInventoryOps.addItemByFullType(inventory, fullType)
    if not inventory or not inventory.AddItem then
        return nil, "missing_inventory_add", nil
    end
    local typeName = tostring(fullType or "")
    if typeName == "" then
        return nil, "missing_item_type", nil
    end
    local item, err = NMWorldItemVisuals.addItemWithVisual(inventory, typeName)
    if not item then
        return nil, err or "add_item_failed", nil
    end
    return item, nil, inventory
end

function NMIntentInventoryOps.setRecordedMediaIndex(item, index)
    local value = tonumber(index)
    if not item or value == nil or value < 0 then
        return false
    end
    if item.setRecordedMediaIndex then
        local ok = pcall(item.setRecordedMediaIndex, item, value)
        if ok then
            return true
        end
    end
    if item.setRecordedMediaIndexInteger then
        local ok = pcall(item.setRecordedMediaIndexInteger, item, value)
        if ok then
            return true
        end
    end
    return false
end

function NMIntentInventoryOps.setDrainableFraction(item, fraction)
    local value = NMCore.clamp(tonumber(fraction) or 0.0, 0.0, 1.0)
    if item and item.setCurrentUsesFloat then
        local ok = pcall(item.setCurrentUsesFloat, item, value)
        if ok then
            return true
        end
    end
    if item and item.setUsedDelta then
        local ok = pcall(item.setUsedDelta, item, value)
        if ok then
            return true
        end
    end
    if item and item.setDelta then
        local ok = pcall(item.setDelta, item, value)
        if ok then
            return true
        end
    end
    return false
end

function NMIntentInventoryOps.applyTransitionOps(player, inventory, ops, hooks)
    if not ops then
        return false, nil
    end

    local applied = false
    local failures = {}
    local removeItemById = hooks and hooks.removeItemById or NMIntentInventoryOps.removeItemById
    local addItemByFullType = hooks and hooks.addItemByFullType or NMIntentInventoryOps.addItemByFullType

    if ops.wearHeadphoneItemId then
        local ok, err = false, "wear_helper_missing"
        if NMAttachmentHelpers.equipHeadphonesByItemId then
            ok, err = NMAttachmentHelpers.equipHeadphonesByItemId(player, ops.wearHeadphoneItemId)
        end
        if ok then
            applied = true
        else
            failures[#failures + 1] = "wear_headphones:" .. tostring(err)
        end
    end
    if ops.unequipHeadphones then
        local ok, err = false, "unequip_helper_missing"
        if NMAttachmentHelpers.unequipWornHeadphones then
            ok, err = NMAttachmentHelpers.unequipWornHeadphones(player)
        end
        if ok then
            applied = true
        else
            failures[#failures + 1] = "unequip_headphones:" .. tostring(err)
        end
    end

    local function consume(kind, itemId)
        local ok, err, container, consumed = removeItemById(inventory, itemId)
        if ok then
            applied = true
            emitHook(hooks, "onConsume", kind, itemId, container, consumed)
        else
            emitHook(hooks, "onConsumeFail", kind, itemId, err)
            failures[#failures + 1] = "consume_" .. tostring(kind) .. ":" .. tostring(err)
        end
    end

    local function produce(kind, fullType, value)
        local out, err, container = addItemByFullType(inventory, fullType)
        if out then
            if kind == "media" then
                NMIntentInventoryOps.setRecordedMediaIndex(out, value)
            elseif kind == "battery" then
                NMIntentInventoryOps.setDrainableFraction(out, value)
            end
            applied = true
            emitHook(hooks, "onProduce", kind, fullType, value, container, out)
        else
            emitHook(hooks, "onProduceFail", kind, fullType, value, err)
            failures[#failures + 1] = "produce_" .. tostring(kind) .. ":" .. tostring(err)
        end
    end

    if ops.consumeMediaItemId then
        consume("media", ops.consumeMediaItemId)
    end
    if ops.consumeHeadphoneItemId then
        consume("headphones", ops.consumeHeadphoneItemId)
    end
    if ops.consumeBatteryItemId then
        consume("battery", ops.consumeBatteryItemId)
    end

    if ops.produceMediaFullType then
        produce("media", ops.produceMediaFullType, ops.produceMediaRecordedMediaIndex)
    end
    if ops.produceHeadphoneFullType then
        produce("headphones", ops.produceHeadphoneFullType, nil)
    end
    if ops.produceBatteryCharge ~= nil then
        produce("battery", "Base.Battery", ops.produceBatteryCharge)
    end

    if #failures > 0 then
        return applied, table.concat(failures, ";")
    end
    return applied, nil
end

return NMIntentInventoryOps
