-- Canonical client-side ownership for vehicle loot refresh and stale-reject UI guards.
NMClientVehicleLootRefresh = NMClientVehicleLootRefresh or {}

local vehicleLootStaleRejects = vehicleLootStaleRejects or {}

local function nowRealMs()
    if getTimestampMs then
        return tonumber(getTimestampMs()) or 0
    end
    return 0
end

local function logVehicleSlotTrace(stage, detail)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("slot")) then
        return
    end
    NMCore.logChannel("slot", tostring(stage or "vehicle_slot_trace"), tostring(detail or ""))
end

local function readContainerType(container)
    if not (container and container.getType) then
        return ""
    end
    return tostring(container:getType() or "")
end

local function buildVehicleLootStaleRejectKey(vehicleId, partId, itemId, itemUuid, containerType)
    return table.concat({
        tostring(vehicleId or ""),
        tostring(partId or ""),
        tostring(itemId or ""),
        tostring(itemUuid or ""),
        tostring(containerType or "")
    }, "|")
end

local function rememberVehicleLootStaleRejectKey(key)
    if key == "" then
        return
    end
    vehicleLootStaleRejects[key] = nowRealMs()
end

local function trimVehicleLootStaleRejects(nowMs)
    for key, atMs in pairs(vehicleLootStaleRejects) do
        if (nowMs - (tonumber(atMs) or 0)) > 5000 then
            vehicleLootStaleRejects[key] = nil
        end
    end
end

local function refreshInventoryPageContainers(page)
    if not page then
        return false
    end
    local refreshed = false
    if page.refreshBackpacks then
        refreshed = pcall(page.refreshBackpacks, page) or refreshed
    end
    local pane = page.inventoryPane or nil
    if pane and pane.refreshContainer then
        refreshed = pcall(pane.refreshContainer, pane) or refreshed
    end
    if pane and pane.inventory and pane.inventory.requestSync then
        refreshed = pcall(pane.inventory.requestSync, pane.inventory) or refreshed
    end
    if triggerEvent then
        pcall(triggerEvent, "OnRefreshInventoryWindowContainers", page, "begin")
        pcall(triggerEvent, "OnRefreshInventoryWindowContainers", page, "buttonsAdded")
        refreshed = true
    end
    return refreshed
end

local function requestInventoryServerItems(inventory)
    if inventory and inventory.requestServerItemsForContainer then
        return pcall(inventory.requestServerItemsForContainer, inventory)
    end
    if inventory and inventory.requestSync then
        return pcall(inventory.requestSync, inventory)
    end
    return false
end

local function resolveVehicleContainerIdentity(player, inventory)
    if not inventory then
        return "", "", ""
    end
    local vehicle = nil
    local part = nil
    if NMInventoryHelpers and NMInventoryHelpers.resolveVehiclePartByContainer then
        vehicle, part = NMInventoryHelpers.resolveVehiclePartByContainer(player, inventory, {
            allowTypeFallback = true
        })
    end
    local vehicleId = vehicle and vehicle.getId and tostring(vehicle:getId()) or ""
    local partId = part and part.getId and tostring(part:getId()) or ""
    return vehicleId, partId, readContainerType(inventory)
end

function NMClientVehicleLootRefresh.rememberVehicleLootStaleReject(traceContext)
    if type(traceContext) ~= "table" then
        return
    end
    local key = buildVehicleLootStaleRejectKey(
        traceContext.vehicleId,
        traceContext.sourcePartId or traceContext.partId,
        traceContext.mediaItemId,
        traceContext.mediaItemUuid,
        traceContext.containerType
    )
    rememberVehicleLootStaleRejectKey(key)
end

function NMClientVehicleLootRefresh.isVehicleLootStaleReject(descriptor)
    if type(descriptor) ~= "table" then
        return false
    end
    local nowMs = nowRealMs()
    trimVehicleLootStaleRejects(nowMs)
    local key = buildVehicleLootStaleRejectKey(
        descriptor.vehicleId,
        descriptor.partId,
        descriptor.itemId,
        descriptor.itemUuid,
        descriptor.containerType
    )
    local atMs = tonumber(vehicleLootStaleRejects[key]) or 0
    return atMs > 0 and (nowMs - atMs) <= 5000
end

function NMClientVehicleLootRefresh.refreshOpenVehicleLootPages(player, vehicleId, traceContext)
    local playerNum = player and player.getPlayerNum and tonumber(player:getPlayerNum()) or nil
    local targetVehicleId = tostring(vehicleId or "")
    if playerNum == nil or targetVehicleId == "" or not getPlayerLoot then
        return false
    end
    local lootPage = getPlayerLoot(playerNum)
    local backpacks = lootPage and type(lootPage.backpacks) == "table" and lootPage.backpacks or nil
    if not (lootPage and backpacks) then
        logVehicleSlotTrace(
            "vehicle_loot_refresh_request",
            string.format(
                "trace=%s vehicleId=%s partId=%s result=skip reason=loot_page_missing",
                tostring(traceContext and traceContext.slotTraceId or ""),
                tostring(targetVehicleId),
                tostring(traceContext and traceContext.partId or "")
            )
        )
        return false
    end

    local pane = lootPage.inventoryPane or nil
    local selectedInventory = pane and pane.inventory or nil
    local selectedVehicleId, selectedPartId, selectedContainerType = resolveVehicleContainerIdentity(player, selectedInventory)

    local matchedButtons = 0
    local requestedCount = 0
    local targetFound = false
    for i = 1, #backpacks do
        local button = backpacks[i]
        local inventory = button and button.inventory or nil
        local runtimeVehicleId = ""
        if inventory == selectedInventory then
            runtimeVehicleId = selectedVehicleId
        else
            runtimeVehicleId = select(1, resolveVehicleContainerIdentity(player, inventory))
        end
        local vehicleMatch = runtimeVehicleId ~= "" and runtimeVehicleId == targetVehicleId
        if vehicleMatch then
            matchedButtons = matchedButtons + 1
            targetFound = true
            if requestInventoryServerItems(inventory) then
                requestedCount = requestedCount + 1
            end
        end
    end

    if not targetFound and selectedVehicleId == targetVehicleId and selectedInventory then
        targetFound = true
        if requestInventoryServerItems(selectedInventory) then
            requestedCount = requestedCount + 1
        end
    end

    local refreshed = refreshInventoryPageContainers(lootPage)
    if targetFound and pane and pane.refreshContainer then
        pcall(pane.refreshContainer, pane)
    end
    if not refreshed and ISInventoryPage and ISInventoryPage.dirtyUI then
        pcall(ISInventoryPage.dirtyUI)
        refreshed = true
    end
    if ISInventoryPage then
        ISInventoryPage.renderDirty = true
    end

    if not targetFound then
        logVehicleSlotTrace(
            "vehicle_loot_refresh_request",
            string.format(
                "trace=%s vehicleId=%s partId=%s result=skip selectedVehicleId=%s selectedPartId=%s selectedContainerType=%s matchedButtons=%s requested=%s refreshed=%s",
                tostring(traceContext and traceContext.slotTraceId or ""),
                tostring(targetVehicleId),
                tostring(traceContext and traceContext.partId or ""),
                tostring(selectedVehicleId),
                tostring(selectedPartId),
                tostring(selectedContainerType),
                tostring(matchedButtons),
                tostring(requestedCount),
                tostring(refreshed)
            )
        )
    end
    return targetFound
end
