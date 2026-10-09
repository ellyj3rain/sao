-- Shared server-side media ingress normalization helpers.

NMServerMediaIngress = NMServerMediaIngress or {}

local helper = NMServerMediaIngress

local function resolveInsertSpec(action)
    local act = tostring(action or "")
    if act == "insert_headphones" then
        return { idKey = "headphoneItemId", uuidKey = "headphoneItemUuid" }
    end
    if act == "insert_media" then
        return { idKey = "mediaItemId", uuidKey = "mediaItemUuid" }
    end
    if act == "insert_battery" then
        return { idKey = "batteryItemId", uuidKey = "batteryItemUuid" }
    end
    return nil
end

local function resolveLogger(opts)
    return type(opts) == "table" and type(opts.logSlotAuthority) == "function" and opts.logSlotAuthority or nil
end

local function resolveTraceLogger(opts)
    return type(opts) == "table" and type(opts.logTraceReject) == "function" and opts.logTraceReject or nil
end

local function describeDescriptor(args, opts)
    if type(opts) == "table" and type(opts.describeSourceDescriptorArgs) == "function" then
        return tostring(opts.describeSourceDescriptorArgs(args, "mediaSource") or "none")
    end
    return "none"
end

local function writeResolvedArgs(args, spec, liveItem)
    args[spec.idKey] = NMCore.itemId(liveItem)
    if spec.uuidKey then
        args[spec.uuidKey] = NMInventoryHelpers.getItemStateUuid and NMInventoryHelpers.getItemStateUuid(liveItem) or nil
    end
end

local function isResolvedInsertMediaItemValid(liveItem)
    return NMMediaHelpers
        and NMMediaHelpers.isInsertableMediaItem
        and NMMediaHelpers.isInsertableMediaItem(liveItem) == true
end

local function logReject(opts, reason, args, descriptorText)
    local logger = resolveLogger(opts)
    if not logger then
        return
    end
    local tag = tostring(opts and opts.rejectTag or "server_normalize_reject")
    if descriptorText ~= nil then
        logger(
            tag,
            string.format(
                "reason=%s slotTraceId=%s descriptor=%s",
                tostring(reason or "normalize_failed"),
                tostring(args and args.slotTraceId or ""),
                tostring(descriptorText or "none")
            )
        )
        return
    end
    logger(tag, "reason=" .. tostring(reason or "normalize_failed") .. " slotTraceId=" .. tostring(args and args.slotTraceId or ""))
end

function helper.normalizeInsertArgsToMainInventory(player, args, action, opts)
    local act = tostring(action or (args and args.action) or "")
    local spec = resolveInsertSpec(act)
    if not spec then
        return true, nil
    end

    if act == "insert_media"
        and NMInventoryHelpers
        and NMInventoryHelpers.readSourceDescriptorFromArgs
        and NMInventoryHelpers.resolveAccessibleItemFromSourceDescriptor then
        local descriptor = NMInventoryHelpers.readSourceDescriptorFromArgs(args, "mediaSource")
        local logger = resolveLogger(opts)
        local descriptorText = describeDescriptor(args, opts)
        if logger then
            logger(
                tostring(opts and opts.beginTag or "server_normalize_begin"),
                string.format(
                    "action=%s host=%s targetItemId=%s mediaItemId=%s mediaItemUuid=%s slotTraceId=%s descriptor=%s",
                    tostring(act),
                    tostring(opts and opts.hostTag or "item"),
                    tostring(args and args.itemId or args and args.vehicleId or ""),
                    tostring(args and args[spec.idKey] or ""),
                    tostring(spec.uuidKey and args and args[spec.uuidKey] or ""),
                    tostring(args and args.slotTraceId or ""),
                    descriptorText
                )
            )
        end
        if descriptor then
            local nearbyFn = type(opts) == "table" and opts.isSourceDescriptorNearby or nil
            if type(nearbyFn) == "function" and not nearbyFn(player, descriptor) then
                logReject(opts, "source_not_nearby", args)
                return false, "source_not_nearby"
            end
            local sourceItem, sourceContainer, sourceErr =
                NMInventoryHelpers.resolveAccessibleItemFromSourceDescriptor(player, descriptor, opts and opts.traceContext or nil)
            if not sourceItem then
                if type(opts) == "table" and type(opts.onSourceResolveReject) == "function" then
                    opts.onSourceResolveReject(player, args, descriptor, sourceErr)
                end
                logReject(opts, sourceErr or "source_descriptor_resolve_failed", args, descriptorText)
                return false, sourceErr or "source_descriptor_resolve_failed"
            end
            local liveItem, err, meta = nil, nil, nil
            if NMInventoryHelpers.normalizeExplicitItemToMainInventory then
                liveItem, err, meta = NMInventoryHelpers.normalizeExplicitItemToMainInventory(player, sourceItem)
            else
                liveItem, err, meta = NMInventoryHelpers.normalizeItemToMainInventory(
                    player,
                    args and args[spec.idKey],
                    args and args[spec.uuidKey],
                    sourceItem
                )
            end
            if not liveItem then
                local traceLogger = resolveTraceLogger(opts)
                if traceLogger then
                    traceLogger(args, act, err or "normalize_failed")
                end
                logReject(opts, err or "normalize_failed", args)
                return false, err or "normalize_failed"
            end
            if meta and meta.deferred == true then
                local traceLogger = resolveTraceLogger(opts)
                if traceLogger then
                    traceLogger(args, act, "normalize_deferred_disallowed")
                end
                logReject(opts, "normalize_deferred_disallowed", args)
                return false, "normalize_deferred_disallowed"
            end
            if meta and sourceContainer and meta.sourceContainer ~= sourceContainer then
                local traceLogger = resolveTraceLogger(opts)
                if traceLogger then
                    traceLogger(args, act, "source_container_mismatch")
                end
                logReject(opts, "source_container_mismatch", args)
                return false, "source_container_mismatch"
            end
            if not isResolvedInsertMediaItemValid(liveItem) then
                local traceLogger = resolveTraceLogger(opts)
                if traceLogger then
                    traceLogger(args, act, "invalid_media_item")
                end
                logReject(opts, "invalid_media_item", args, descriptorText)
                return false, "invalid_media_item"
            end
            writeResolvedArgs(args, spec, liveItem)
            if type(opts) == "table" and type(opts.replicateNormalizedItemMove) == "function" then
                opts.replicateNormalizedItemMove(meta, liveItem)
            end
            if logger then
                logger(
                    tostring(opts and opts.okTag or "server_normalize_ok"),
                    string.format(
                        "slotTraceId=%s moved=%s deferred=%s sourceContainerChanged=%s sourceContainerType=%s targetContainerType=%s liveItemId=%s liveItemUuid=%s fullType=%s",
                        tostring(args and args.slotTraceId or ""),
                        tostring(meta and meta.moved == true),
                        tostring(meta and meta.deferred == true),
                        tostring(meta and meta.sourceContainer ~= meta.targetContainer),
                        tostring(meta and meta.sourceContainer and meta.sourceContainer.getType and meta.sourceContainer:getType() or ""),
                        tostring(meta and meta.targetContainer and meta.targetContainer.getType and meta.targetContainer:getType() or ""),
                        tostring(args and args[spec.idKey] or ""),
                        tostring(spec.uuidKey and args and args[spec.uuidKey] or ""),
                        tostring(liveItem and liveItem.getFullType and liveItem:getFullType() or "")
                    )
                )
            end
            return true, nil
        end

        local inventory = player and player.getInventory and player:getInventory() or nil
        local liveItem = inventory and NMInventoryHelpers.resolveItemByIdOrUuid
            and NMInventoryHelpers.resolveItemByIdOrUuid(inventory, args and args[spec.idKey], args and args[spec.uuidKey])
            or nil
        if not liveItem then
            logReject(opts, "media_source_descriptor_missing", args)
            return false, "media_source_descriptor_missing"
        end
        if not isResolvedInsertMediaItemValid(liveItem) then
            logReject(opts, "invalid_media_item", args)
            return false, "invalid_media_item"
        end
        writeResolvedArgs(args, spec, liveItem)
        if logger then
            logger(
                tostring(opts and opts.rootOkTag or "server_normalize_root_ok"),
                "slotTraceId=" .. tostring(args and args.slotTraceId or "") .. " liveItemId=" .. tostring(args and args[spec.idKey] or "")
            )
        end
        return true, nil
    end

    if not (NMInventoryHelpers and NMInventoryHelpers.normalizeItemToMainInventory) then
        return false, "normalize_helper_missing"
    end
    local liveItem, err, meta = NMInventoryHelpers.normalizeItemToMainInventory(player, args and args[spec.idKey], args and args[spec.uuidKey])
    if not liveItem then
        return false, err or "normalize_failed"
    end
    writeResolvedArgs(args, spec, liveItem)
    if type(opts) == "table" and type(opts.replicateNormalizedItemMove) == "function" then
        opts.replicateNormalizedItemMove(meta, liveItem)
    end
    return true, nil
end
