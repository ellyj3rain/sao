-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
local env = _G.NMContextMenusEnv
setfenv(1, env)

local function isFancyUIEnabled()
    if NMRuntimeConfig and NMRuntimeConfig.getFancyUIEnabled then
        return NMRuntimeConfig.getFancyUIEnabled() == true
    end
    return true
end

local function logPortableUiProbe(tag, detail)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("portable_ui")) then
        return
    end
    NMCore.logChannel("portable_ui", tostring(tag or "portable_ui"), tostring(detail or ""))
end

local function logLooseMediaCompat(tag, detail)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime")) then
        return
    end
    NMCore.logChannel("runtime", tostring(tag or "loose_media_compat"), tostring(detail or ""))
end

local function buildLooseMediaSourceKey(item, itemIdHint)
    local itemId = item and item.getID and tostring(item:getID() or "") or tostring(itemIdHint or "")
    if itemId ~= "" then
        return "id:" .. itemId
    end
    local itemUuid = item and NMInventoryHelpers and NMInventoryHelpers.getItemStateUuid and NMInventoryHelpers.getItemStateUuid(item) or ""
    itemUuid = tostring(itemUuid or "")
    if itemUuid ~= "" then
        return "uuid:" .. itemUuid
    end
    local fullType = item and item.getFullType and tostring(item:getFullType() or "") or ""
    local container = item and item.getContainer and item:getContainer() or nil
    local containerKey = container and tostring(container) or ""
    if fullType ~= "" or containerKey ~= "" then
        return "fallback:" .. fullType .. "|" .. containerKey
    end
    return ""
end

local function clearLooseMediaFlipPending(requestId)
    local requestKey = tostring(requestId or "")
    if requestKey == "" then
        return
    end
    local sourceKey = NMContextMenus._flipPendingSourceByRequest[requestKey]
    NMContextMenus._flipPendingSourceByRequest[requestKey] = nil
    NMContextMenus._flipInFlight[requestKey] = nil
    if sourceKey and sourceKey ~= "" then
        if NMContextMenus._flipPendingRequestBySource[sourceKey] == requestKey then
            NMContextMenus._flipPendingRequestBySource[sourceKey] = nil
        end
    end
end

local function markLooseMediaFlipPending(sourceKey, requestId)
    local requestKey = tostring(requestId or "")
    local resolvedSourceKey = tostring(sourceKey or "")
    if requestKey == "" or resolvedSourceKey == "" then
        return false
    end
    local existingRequestId = tostring(NMContextMenus._flipPendingRequestBySource[resolvedSourceKey] or "")
    if existingRequestId ~= "" and existingRequestId ~= requestKey then
        logLooseMediaCompat(
            "flip_duplicate_transform_ignored",
            string.format(
                "sourceKey=%s existingRequestId=%s requestId=%s",
                tostring(resolvedSourceKey),
                tostring(existingRequestId),
                tostring(requestKey)
            )
        )
        return false
    end
    NMContextMenus._flipPendingRequestBySource[resolvedSourceKey] = requestKey
    NMContextMenus._flipPendingSourceByRequest[requestKey] = resolvedSourceKey
    NMContextMenus._flipInFlight[requestKey] = true
    logLooseMediaCompat(
        "flip_transform_begin",
        string.format(
            "sourceKey=%s requestId=%s",
            tostring(resolvedSourceKey),
            tostring(requestKey)
        )
    )
    return true
end

function traceLooseMediaClick(player, tag, item)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime")) then
        return
    end
    local inv = player and player.getInventory and player:getInventory() or nil
    local itemId = item and item.getID and tostring(item:getID() or "") or ""
    local fullType = item and item.getFullType and tostring(item:getFullType() or "") or ""
    local container = item and item.getContainer and item:getContainer() or nil
    local inInv = false
    if inv and itemId ~= "" and NMInventoryHelpers and NMInventoryHelpers.findItemById then
        inInv = NMInventoryHelpers.findItemById(inv, itemId) ~= nil
    end
    NMCore.logChannel(
        "runtime",
        tostring(tag or "loose_media_click"),
        string.format(
            "itemId=%s fullType=%s hasContainer=%s inRootInventory=%s",
            tostring(itemId),
            tostring(fullType),
            tostring(container ~= nil),
            tostring(inInv)
        )
    )
end

local function resolveFancyPortableWindowApi(deviceType)
    if deviceType == "walkman" then
        return NMWalkmanWindow
    end
    if deviceType == "cdplayer" then
        return NMCDPlayerWindow
    end
    if deviceType == "boombox" then
        return NMBoomboxWindow
    end
    return nil
end

local function resolveFancyPortableLooseMediaLogTag(deviceType)
    if deviceType == "cdplayer" then
        return "loose_media_cdplayer_queue"
    end
    if deviceType == "boombox" then
        return "loose_media_boombox_queue"
    end
    return "loose_media_walkman_queue"
end

function tryQueueOpenFancyPortableMediaAction(p, targetItem, actionName, args)
    if not isFancyUIEnabled() then
        return false
    end
    if not (p and targetItem and actionName) then
        return false
    end
    local profile = NMDeviceProfiles and NMDeviceProfiles.getForItem and NMDeviceProfiles.getForItem(targetItem) or nil
    local deviceType = tostring(profile and profile.deviceType or "")
    if deviceType ~= "walkman" and deviceType ~= "cdplayer" and deviceType ~= "boombox" then
        return false
    end
    local playerNum = p.getPlayerNum and p:getPlayerNum() or 0
    local win = nil
    local windowApi = resolveFancyPortableWindowApi(deviceType)
    if not windowApi then
        return false
    end
    if windowApi.findOpenForItem then
        win = windowApi.findOpenForItem(playerNum, targetItem)
    end
    if not win and windowApi.openForItem then
        win = windowApi.openForItem(playerNum, targetItem)
    end
    if not win then
        return false
    end
    local mediaEnv = rawget(_G, "NMMediaSlotEnv")
    local sharedQueue = mediaEnv and mediaEnv.queueMediaSlotAction or nil
    if not sharedQueue then
        return false
    end
    local action = tostring(actionName or "")
    local payload = args or {}
    if action == "insert_media" then
        win._nmPendingMediaSlotFullType = tostring(payload.mediaEjectFullType or payload.mediaFullType or "")
        if deviceType == "cdplayer" and win.queueContextMediaInsert then
            return win:queueContextMediaInsert(targetItem, {
                mediaFullType = payload.mediaFullType,
                mediaEjectFullType = payload.mediaEjectFullType
            }, payload) == true
        end
        win.isLidManuallyOpen = true
    elseif action == "eject_media" then
        win._nmSlotRemoveInFlightByType = win._nmSlotRemoveInFlightByType or {}
        if win._nmSlotRemoveInFlightByType.media then
            return false
        end
        local currentMediaState = win.getCassetteDisplayMediaState and win:getCassetteDisplayMediaState() or nil
        local fullType = tostring(currentMediaState and currentMediaState.fullType or payload.mediaEjectFullType or payload.mediaFullType or "")
        if fullType == "" then
            return false
        end
        win._nmSlotRemoveInFlightByType.media = true
        win._nmPendingMediaSlotFullType = fullType
        win.isLidManuallyOpen = (deviceType == "cdplayer") and false or true
    else
        return false
    end
    if win.syncLidFromMedia then
        win:syncLidFromMedia(false)
    end
    logPortableUiProbe(
        resolveFancyPortableLooseMediaLogTag(deviceType),
        string.format(
            "player=%s action=%s targetItemId=%s targetUuid=%s mediaItemId=%s mediaFullType=%s slotTraceId=%s",
            tostring(playerNum or 0),
            tostring(action or ""),
            tostring(win.target and win.target.itemId or ""),
            tostring(win.target and win.target.uuid or ""),
            tostring(payload.mediaItemId or ""),
            tostring(payload.mediaEjectFullType or payload.mediaFullType or ""),
            tostring(payload.slotTraceId or "")
        )
    )
    return sharedQueue(win, action, payload) == true
end

function tryQueueOpenWalkmanMediaAction(p, targetItem, actionName, args)
    return tryQueueOpenFancyPortableMediaAction(p, targetItem, actionName, args)
end

function tryQueueOpenWalkmanInsert(p, targetItem, args)
    return tryQueueOpenFancyPortableMediaAction(p, targetItem, "insert_media", args)
end

function addLooseMediaFlipAction(subMenu, player, mediaItem, capturedItemId)
    local mediaFullType = mediaItem and mediaItem.getFullType and tostring(mediaItem:getFullType() or "") or ""
    local flipTarget = NMMediaContract.resolveMediaFlipTarget and NMMediaContract.resolveMediaFlipTarget(mediaFullType) or nil
    if not (flipTarget and tostring(flipTarget) ~= "") then
        return
    end
    subMenu:addOption(NMTranslations.ui("Flip", "Flip"), player, function(p)
        local inv = p and p.getInventory and p:getInventory() or nil
        local liveItem, liveId = resolveLiveItemByIdOrAlias(p, capturedItemId)
        local sourceKey = buildLooseMediaSourceKey(liveItem or mediaItem, liveId or capturedItemId)
        traceLooseMediaClick(p, "flip_click_client", liveItem or mediaItem)
        if not inv then
            return
        end
        if not liveItem then
            local aliasOnlyId = tostring(liveId or "")
            if NMCore and NMCore.isMPClientRuntime and NMCore.isMPClientRuntime() and aliasOnlyId ~= "" and aliasOnlyId ~= tostring(capturedItemId or "") then
                if sourceKey == "" or not markLooseMediaFlipPending(sourceKey, aliasOnlyId) then
                    return
                end
                if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
                    NMCore.logChannel(
                        "runtime",
                        "flip_click_client_alias_only",
                        string.format(
                            "capturedItemId=%s resolvedItemId=%s target=%s",
                            tostring(capturedItemId or ""),
                            tostring(aliasOnlyId),
                            tostring(flipTarget)
                        )
                    )
                    NMCore.logChannel(
                        "runtime",
                        "flip_request_client",
                        string.format(
                            "itemId=%s fullType=%s target=%s mp=true aliasOnly=true",
                            tostring(aliasOnlyId),
                            tostring(mediaFullType),
                            tostring(flipTarget)
                        )
                    )
                end
                sendClientCommand(p, NMCore.NetModule, "media_flip", {
                    itemId = aliasOnlyId
                })
                return
            end
            if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
                NMCore.logChannel("runtime", "flip_click_client_no_live_item", "capturedItemId=" .. tostring(capturedItemId or ""))
            end
            return
        end
        if sourceKey == "" then
            logLooseMediaCompat(
                "flip_transform_abort",
                string.format(
                    "capturedItemId=%s reason=missing_source_key",
                    tostring(capturedItemId or "")
                )
            )
            return
        end
        local source = liveItem
        local owner = source.getContainer and source:getContainer() or nil
        if not owner then
            return
        end
        if not (NMInventoryHelpers and NMInventoryHelpers.isItemWithinInventoryTree and NMInventoryHelpers.isItemWithinInventoryTree(inv, source)) then
            return
        end

        if NMCore and NMCore.isMPClientRuntime and NMCore.isMPClientRuntime() then
            local requestId = tostring(liveId or "")
            if requestId == "" and source.getID then
                requestId = tostring(source:getID() or "")
            end
            if requestId == "" then
                return
            end
            if not markLooseMediaFlipPending(sourceKey, requestId) then
                return
            end
            if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
                NMCore.logChannel(
                    "runtime",
                    "flip_request_client",
                    string.format(
                        "itemId=%s fullType=%s target=%s mp=true",
                        tostring(requestId),
                        tostring(source.getFullType and source:getFullType() or ""),
                        tostring(flipTarget)
                    )
                )
            end
            sendClientCommand(p, NMCore.NetModule, "media_flip", {
                itemId = requestId
            })
            return
        end

        local resolvedSource = NMInventoryHelpers and NMInventoryHelpers.findAccessibleItemByIdOrUuid
            and NMInventoryHelpers.findAccessibleItemByIdOrUuid(p, liveId, sourceKey:match("^uuid:(.+)$"), source)
            or source
        if resolvedSource ~= source then
            logLooseMediaCompat(
                "flip_transform_abort",
                string.format(
                    "capturedItemId=%s liveId=%s reason=ambiguous_source_identity",
                    tostring(capturedItemId or ""),
                    tostring(liveId or "")
                )
            )
            return
        end
        if not markLooseMediaFlipPending(sourceKey, tostring(liveId or capturedItemId or "")) then
            return
        end
        local created = NMWorldItemVisuals.addItemWithVisual and select(1, NMWorldItemVisuals.addItemWithVisual(owner, flipTarget)) or nil
        if not created then
            clearLooseMediaFlipPending(tostring(liveId or capturedItemId or ""))
            return
        end
        if inv.DoRemoveItem then
            inv:DoRemoveItem(source)
        else
            inv:Remove(source)
        end
        clearLooseMediaFlipPending(tostring(liveId or capturedItemId or ""))
    end)
end

function addLooseMediaInsertActions(subMenu, player, mediaItem, capturedItemId)
    local deviceTargets, containerTargets = collectLooseMediaInsertTargets(player, mediaItem)
    local insertRoot = subMenu:addOption(NMTranslations.ui("Insert", "Insert"), player, nil)
    local insertSub = ISContextMenu:getNew(subMenu)
    subMenu:addSubMenu(insertRoot, insertSub)
    if #deviceTargets < 1 and #containerTargets < 1 then
        local none = insertSub:addOption(NMTranslations.ui("NoValidTargets", "No valid targets"), player, function() end)
        none.notAvailable = true
        return
    end

    local function addTargetRow(target)
        local option = insertSub:addOption(target.displayName, player, function(p)
            local liveItem, liveId = resolveLiveItemByIdOrAlias(p, capturedItemId)
            traceLooseMediaClick(p, "insert_click_client", liveItem or mediaItem)
            if not liveId or tostring(liveId) == "" then
                if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
                    NMCore.logChannel("runtime", "insert_click_client_no_live_item", "capturedItemId=" .. tostring(capturedItemId or ""))
                end
                return
            end
            local args = buildCaseMediaInsertArgs(liveItem)
            logPortableUiProbe(
                "loose_media_insert_target",
                string.format(
                    "player=%s targetType=%s targetItemId=%s targetUuid=%s mediaItemId=%s mediaUuid=%s mediaFullType=%s",
                    tostring(p and p.getPlayerNum and p:getPlayerNum() or 0),
                    tostring(target.category or "device"),
                    tostring(target.item and NMCore and NMCore.itemId and NMCore.itemId(target.item) or ""),
                    tostring(target.item and NMInventoryHelpers and NMInventoryHelpers.getItemStateUuid and NMInventoryHelpers.getItemStateUuid(target.item) or ""),
                    tostring(liveId or ""),
                    tostring(liveItem and NMInventoryHelpers and NMInventoryHelpers.getItemStateUuid and NMInventoryHelpers.getItemStateUuid(liveItem) or ""),
                    tostring(args and (args.mediaEjectFullType or args.mediaFullType) or "")
                )
            )
            if target.category == "window" then
                local zone = target.zone
                local targetWin = zone and zone.window or nil
                local mediaEnv = rawget(_G, "NMMediaSlotEnv") or nil
                local queueDraggedMediaInsertFn = mediaEnv and mediaEnv.queueDraggedMediaInsert or nil
                if targetWin and queueDraggedMediaInsertFn and args then
                    if queueDraggedMediaInsertFn(targetWin, { liveItem }, "context_menu") == true then
                        return
                    end
                end
                return
            end
            if args and tryQueueOpenFancyPortableMediaAction(p, target.item, "insert_media", args) == true then
                return
            end
            NMClientIntentDispatch.performIntent(p, target.item, "insert_media", args or {
                mediaItemId = tostring(liveId)
            })
        end)
        setOptionIcon(option, resolveTextureByFullType(target.item and target.item.getFullType and target.item:getFullType() or ""))
    end

    for i = 1, #deviceTargets do
        addTargetRow(deviceTargets[i])
    end
    for i = 1, #containerTargets do
        addTargetRow(containerTargets[i])
    end
end

function NMContextMenus.onMediaFlipResult(player, args)
    if not (player and args and args.ok == true) then
        local failedOldId = tostring(args and args.oldItemId or "")
        if failedOldId ~= "" then
            clearLooseMediaFlipPending(failedOldId)
        end
        if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
            NMCore.logChannel(
                "runtime",
                "flip_ack_client_fail",
                string.format(
                    "ok=%s oldItemId=%s newItemId=%s reason=%s",
                    tostring(args and args.ok),
                    tostring(args and args.oldItemId or ""),
                    tostring(args and args.newItemId or ""),
                    tostring(args and args.reason or "")
                )
            )
        end
        return false
    end
    if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
        NMCore.logChannel(
            "runtime",
            "flip_ack_client_ok",
            string.format(
                "oldItemId=%s newItemId=%s target=%s recIdx=%s",
                tostring(args.oldItemId or ""),
                tostring(args.newItemId or ""),
                tostring(args.targetFullType or ""),
                tostring(args.recordedMediaIndex or "")
            )
        )
    end
    local oldItemId = tostring(args.oldItemId or "")
    local newItemId = tostring(args.newItemId or "")
    if oldItemId ~= "" then
        clearLooseMediaFlipPending(oldItemId)
    end
    if newItemId ~= "" then
        clearLooseMediaFlipPending(newItemId)
    end
    if oldItemId ~= "" and newItemId ~= "" and oldItemId ~= newItemId then
        NMContextMenus._flipIdAlias[oldItemId] = newItemId
    end
    local inv = player and player.getInventory and player:getInventory() or nil
    if inv and inv.requestSync then
        pcall(inv.requestSync, inv)
    end
    local playerNum = player and player.getPlayerNum and tonumber(player:getPlayerNum()) or nil
    local invPage = nil
    local lootPage = nil
    if playerNum ~= nil and getPlayerInventory then
        invPage = getPlayerInventory(playerNum)
        if invPage and invPage.refreshBackpacks then
            pcall(invPage.refreshBackpacks, invPage)
        end
    end
    if playerNum ~= nil and getPlayerLoot then
        lootPage = getPlayerLoot(playerNum)
        if lootPage and lootPage.refreshBackpacks then
            pcall(lootPage.refreshBackpacks, lootPage)
        end
    end
    if ISInventoryPage and ISInventoryPage.dirtyUI then
        pcall(ISInventoryPage.dirtyUI)
    end
    if ISInventoryPage then
        ISInventoryPage.renderDirty = true
    end
    if triggerEvent then
        if invPage then
            pcall(triggerEvent, "OnRefreshInventoryWindowContainers", invPage, "begin")
            pcall(triggerEvent, "OnRefreshInventoryWindowContainers", invPage, "buttonsAdded")
        end
        if lootPage then
            pcall(triggerEvent, "OnRefreshInventoryWindowContainers", lootPage, "begin")
            pcall(triggerEvent, "OnRefreshInventoryWindowContainers", lootPage, "buttonsAdded")
        end
    end
    if NMCore and NMCore.isMPClientRuntime and NMCore.isMPClientRuntime() and sendClientCommand then
        sendClientCommand(player, NMCore.NetModule, "request_inventory_state_sync", {})
    end
    return true
end
