require "intents/item/NMServerItemIntentLogging"

NMServerItemIntentTargeting = NMServerItemIntentTargeting or {}

local function normalizeMode(sourceMode)
    local mode = tostring(sourceMode or "")
    if mode == "" then
        return "off"
    end
    return mode
end

local function buildRequestSummary(ctx)
    if type(ctx) ~= "table" then
        return nil
    end

    local player = ctx.player
    local item = ctx.item
    local state = ctx.state
    local args = ctx.args or {}
    local summary = ctx._requestSummary or {}
    summary.playerOnlineId = player and player.getOnlineID and tostring(player:getOnlineID() or "") or ""
    summary.playerName = player and player.getUsername and tostring(player:getUsername() or "") or ""
    summary.itemId = item and item.getID and tostring(item:getID() or "") or tostring(ctx.itemId or args.itemId or "")
    summary.itemFullType = item and item.getFullType and tostring(item:getFullType() or "") or ""
    summary.deviceUUID = state and tostring(state.deviceUUID or "") or tostring(ctx.uuid or args.uuid or "")
    summary.sourceModeHint = tostring(args.sourceMode or "")
    ctx.itemId = summary.itemId
    ctx.uuid = summary.deviceUUID
    ctx.itemFullType = summary.itemFullType
    ctx.deviceUUID = summary.deviceUUID
    ctx.playerName = summary.playerName
    ctx.playerOnlineId = summary.playerOnlineId
    ctx.sourceModeHint = summary.sourceModeHint
    ctx._requestSummary = summary
    return summary
end

local function exportStateOnce(ctx, state)
    if type(ctx) == "table" then
        local cachedState = ctx._exportedStateSource
        if cachedState == state and type(ctx._exportedStateSnapshot) == "table" then
            return ctx._exportedStateSnapshot
        end
    end

    local snapshot = NMDeviceState.export(state)
    if type(ctx) == "table" then
        ctx._exportedStateSource = state
        ctx._exportedStateSnapshot = snapshot
    end
    return snapshot
end

local function buildReplicatedStatePayload(ctx, player, item, state, sourceMode)
    if not (player and item and state) then
        return nil
    end

    local summary = buildRequestSummary(ctx or {
        player = player,
        item = item,
        state = state,
        itemId = item and item.getID and tostring(item:getID() or "") or "",
        uuid = state and tostring(state.deviceUUID or "") or ""
    }) or {}

    return {
        itemId = tostring(summary.itemId or ""),
        uuid = tostring(summary.deviceUUID or ""),
        itemFullType = tostring(summary.itemFullType or ""),
        sourceMode = normalizeMode(sourceMode),
        ownerId = tostring(state.sourceOwner or ""),
        state = exportStateOnce(ctx, state),
        serverSessionToken = NMServerBootReset and NMServerBootReset.getSessionToken and NMServerBootReset.getSessionToken() or nil
    }
end

function NMServerItemIntentTargeting.hasWorldSquare(item)
    local worldItem = item and item.getWorldItem and item:getWorldItem() or nil
    local square = worldItem and worldItem.getSquare and worldItem:getSquare() or nil
    return square ~= nil, square
end

function NMServerItemIntentTargeting.isItemAttachedToPlayer(player, item, uuid)
    if not (player and item) then
        return false
    end
    local itemId = NMInventoryHelpers.getItemIdString(item)
    local stateUuid = tostring(uuid or "")

    local primary = player.getPrimaryHandItem and player:getPrimaryHandItem() or nil
    if NMAttachmentHelpers.itemMatchesTarget(primary, itemId, item, stateUuid) then
        return true
    end
    local secondary = player.getSecondaryHandItem and player:getSecondaryHandItem() or nil
    if NMAttachmentHelpers.itemMatchesTarget(secondary, itemId, item, stateUuid) then
        return true
    end

    local attachedItems = player.getAttachedItems and player:getAttachedItems() or nil
    if attachedItems then
        for i = 0, attachedItems:size() - 1 do
            local entry = attachedItems:get(i)
            local attachedItem = entry and entry.getItem and entry:getItem() or nil
            if NMAttachmentHelpers.itemMatchesTarget(attachedItem, itemId, item, stateUuid) then
                return true
            end
        end
    end

    return NMAttachmentHelpers.isItemWornOnBack(player, itemId, item, stateUuid)
end

function NMServerItemIntentTargeting.deriveServerSourceMode(player, item, profile, state, hintedMode)
    local hasSquare = NMServerItemIntentTargeting.hasWorldSquare(item)
    if hasSquare then
        if NMDeviceProfiles.canPlacedWorldPlayback(profile) or NMDeviceProfiles.isPortableTrackedProfile(profile) then
            return "placed"
        end
        return "off"
    end

    local attached = NMServerItemIntentTargeting.isItemAttachedToPlayer(player, item, state and state.deviceUUID)
    if attached then
        return "attached"
    end

    local hint = tostring(hintedMode or "")
    if hint == "attached" or hint == "stowed" then
        return hint
    end

    local container = item and item.getContainer and item:getContainer() or nil
    if container then
        return "stowed"
    end
    return "off"
end

function NMServerItemIntentTargeting.buildItemAuthorityContext(player, item, profile, mode)
    local context = {}
    local ownerOnline = player and player.getOnlineID and tostring(player:getOnlineID() or "") or ""
    local ownerName = player and player.getUsername and tostring(player:getUsername() or "") or ""
    local ownerId = ownerOnline ~= "" and ownerOnline or ownerName
    local hasSquare, square = NMServerItemIntentTargeting.hasWorldSquare(item)
    if mode == "placed" and hasSquare then
        context.sourceX = square:getX() + 0.5
        context.sourceY = square:getY() + 0.5
        context.sourceZ = square:getZ()
        if NMDeviceProfiles.isPortableTrackedProfile(profile) then
            context.sourceOwner = ownerId
        else
            context.sourceOwner = NMCore.itemId and tostring(NMCore.itemId(item) or "") or ""
        end
    else
        context.sourceX = player and player.getX and tonumber(player:getX()) or nil
        context.sourceY = player and player.getY and tonumber(player:getY()) or nil
        context.sourceZ = player and player.getZ and tonumber(player:getZ()) or nil
        context.sourceOwner = ownerId
    end
    return context
end

function NMServerItemIntentTargeting.ensureRegistryEntry(item, profile, state, sourceMode)
    return NMServerItemIntentTargeting.ensureRegistryEntryForContext(nil, item, profile, state, sourceMode)
end

function NMServerItemIntentTargeting.ensureRegistryEntryForContext(ctx, item, profile, state, sourceMode)
    if not item or not profile or not state or not state.deviceUUID then
        return nil
    end
    local summary = buildRequestSummary(ctx or {
        item = item,
        state = state
    }) or {}
    local _, square = NMServerItemIntentTargeting.hasWorldSquare(item)
    local x = square and (square:getX() + 0.5) or tonumber(state.sourceX)
    local y = square and (square:getY() + 0.5) or tonumber(state.sourceY)
    local z = square and square:getZ() or tonumber(state.sourceZ)
    if x == nil then x = 0 end
    if y == nil then y = 0 end
    if z == nil then z = 0 end
    local owner = tostring(state.sourceOwner or "")
    local ownerOnlineId = ""
    local ownerUsername = ""
    if owner ~= "" then
        if owner:match("^%-?%d+$") then
            ownerOnlineId = owner
        else
            ownerUsername = owner
        end
    end
    local entry = {
        kind = "item",
        uuid = tostring(summary.deviceUUID or state.deviceUUID),
        itemId = tostring(summary.itemId or ""),
        itemFullType = tostring(summary.itemFullType or ""),
        profileType = tostring(profile.fullType or summary.itemFullType or ""),
        x = x,
        y = y,
        z = z,
        sourceMode = normalizeMode(sourceMode),
        sourceEpoch = tonumber(state.sourceGeneration) or 0,
        sourceRebind = false,
        ownerId = owner,
        ownerOnlineId = ownerOnlineId,
        ownerUsername = ownerUsername,
        stateSnapshot = exportStateOnce(ctx, state)
    }
    if NMServerRegistryBroadcast and NMServerRegistryBroadcast.touchEntry then
        NMServerRegistryBroadcast.touchEntry(entry, state)
    end
    NMServerRegistryState.worldRegistry[entry.uuid] = entry
    return entry
end

function NMServerItemIntentTargeting.sendState(player, item, state, sourceMode)
    return NMServerItemIntentTargeting.sendStateForContext(nil, player, item, state, sourceMode)
end

function NMServerItemIntentTargeting.sendStateForContext(ctx, player, item, state, sourceMode)
    if not player or not item or not state or not sendServerCommand then
        return
    end
    local payload = buildReplicatedStatePayload(ctx, player, item, state, sourceMode)
    sendServerCommand(player, NMCore.NetModule, "state", payload)
end

function NMServerItemIntentTargeting.broadcastObserverState(originPlayer, item, state, sourceMode, actionName)
    return NMServerItemIntentTargeting.broadcastObserverStateForContext(nil, originPlayer, item, state, sourceMode, actionName)
end

function NMServerItemIntentTargeting.broadcastObserverStateForContext(ctx, originPlayer, item, state, sourceMode, actionName)
    if not item or not state or not sendServerCommand then
        return 0
    end
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if not players then
        return 0
    end

    local summary = buildRequestSummary(ctx or {
        player = originPlayer,
        item = item,
        state = state
    }) or {}
    local originOnlineId = tostring(summary.playerOnlineId or "")
    local originUsername = tostring(summary.playerName or "")
    local payload = buildReplicatedStatePayload(ctx, originPlayer, item, state, sourceMode)

    local sent = 0
    for i = 0, players:size() - 1 do
        local p = players:get(i)
        if p then
            local targetOnlineId = p.getOnlineID and tostring(p:getOnlineID() or "") or ""
            local targetUsername = p.getUsername and tostring(p:getUsername() or "") or ""
            local samePlayer = false
            if originOnlineId ~= "" and targetOnlineId ~= "" then
                samePlayer = originOnlineId == targetOnlineId
            elseif originUsername ~= "" and targetUsername ~= "" then
                samePlayer = originUsername == targetUsername
            end
            if not samePlayer then
                sendServerCommand(p, NMCore.NetModule, "state", payload)
                sent = sent + 1
            end
        end
    end

    if sent > 0 and NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
        NMCore.logChannel(
            "runtime",
            "server_item_state_observer_broadcast",
            string.format(
                "action=%s count=%s itemId=%s uuid=%s media=%s",
                tostring(actionName or "unknown"),
                tostring(sent),
                tostring(payload.itemId or ""),
                tostring(payload.uuid or ""),
                tostring(state and state.mediaFullType or "nil")
            )
        )
    end

    return sent
end

function NMServerItemIntentTargeting.broadcastRegistryEntry(entry, state, op)
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
    NMServerRegistryBroadcast.broadcastEntry(
        NMServerRegistryState.worldRegistry,
        tostring(entry.uuid),
        nil,
        state,
        op,
        recipients
    )
end

function NMServerItemIntentTargeting.refreshRequestContext(ctx)
    return buildRequestSummary(ctx)
end

function NMServerItemIntentTargeting.resolveTarget(player, args)
    local inv = player and player.getInventory and player:getInventory() or nil
    if not inv then
        return nil, "missing_inventory"
    end

    local itemId = tostring(args and args.itemId or "")
    local uuid = tostring(args and args.uuid or "")
    local item = nil
    if itemId ~= "" then
        item = NMInventoryHelpers.findItemById(inv, itemId)
    end
    if (not item) and uuid ~= "" then
        item = NMInventoryHelpers.findItemByUuid(inv, uuid)
    end
    if (not item) and itemId ~= "" then
        item = NMInventoryHelpers.findWorldItemByIdNearPlayer(player, itemId, 8)
    end
    if (not item) and uuid ~= "" then
        item = NMInventoryHelpers.findWorldItemByUuidNearPlayer(player, uuid, 8)
    end
    if not item then
        return nil, "item_not_found"
    end

    local profile = NMDeviceProfiles.getForItem(item)
    if not profile and args and args.itemFullType and NMDeviceProfiles.getForFullType then
        profile = NMDeviceProfiles.getForFullType(tostring(args.itemFullType))
    end
    if not profile then
        return nil, "not_managed"
    end

    local state = NMDeviceState.ensure(item, profile)
    if not state then
        return nil, "missing_state"
    end
    if NMServerBootReset and NMServerBootReset.normalizeState then
        NMServerBootReset.normalizeState(state, "item", tostring(state.deviceUUID or itemId or uuid or ""))
    end

    local ctx = {
        player = player,
        inventory = inv,
        args = args or {},
        item = item,
        profile = profile,
        state = state,
        itemId = itemId,
        uuid = uuid
    }
    buildRequestSummary(ctx)
    return ctx, nil
end

return NMServerItemIntentTargeting
