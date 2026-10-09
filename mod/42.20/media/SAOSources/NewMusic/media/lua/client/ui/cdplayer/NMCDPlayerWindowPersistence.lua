local env = _G.NMCDPlayerWindowEnv
setfenv(1, env)

local function isFancyUIEnabled()
    if NMRuntimeConfig and NMRuntimeConfig.getFancyUIEnabled then
        return NMRuntimeConfig.getFancyUIEnabled() == true
    end
    return true
end

function persistWindowState(window, isOpen)
    local player = window and getPlayer(window.playerNum) or nil
    local target = window and window.target or nil
    local data = getPersistedUIState(player, true)
    if not data then
        return
    end
    data.open = (isOpen == true)
    data.collapsed = window and window.isCollapsed == true or false
    data.expandedY = window and tonumber(window._nmExpandedY or window.getExpandedY and window:getExpandedY()) or nil
    data.itemId = tostring(target and target.itemId or "")
    data.uuid = tostring(target and target.uuid or "")
    transmitPlayerModData(player)
end

function loadPersistedWindowState(playerNum)
    local player = getPlayer(playerNum)
    local data = getPersistedUIState(player, false)
    if type(data) ~= "table" then
        return nil
    end
    return {
        open = data.open == true,
        collapsed = data.collapsed == true,
        expandedY = tonumber(data.expandedY),
        itemId = tostring(data.itemId or ""),
        uuid = tostring(data.uuid or ""),
    }
end

function clearPersistedOpenFlag(playerNum)
    local player = getPlayer(playerNum)
    local data = getPersistedUIState(player, false)
    if not data then
        return
    end
    data.open = false
    transmitPlayerModData(player)
end

function resolvePersistedTargetItem(player, persisted)
    if not (player and persisted and NMInventoryHelpers) then
        return nil
    end
    local uuid = tostring(persisted.uuid or "")
    local itemId = tostring(persisted.itemId or "")
    local inv = player.getInventory and player:getInventory() or nil
    local item = nil
    if inv and uuid ~= "" and NMInventoryHelpers.findItemByUuid then
        item = NMInventoryHelpers.findItemByUuid(inv, uuid)
        if item then
            return item
        end
    end
    if inv and itemId ~= "" and NMInventoryHelpers.findItemById then
        item = NMInventoryHelpers.findItemById(inv, itemId)
        if item then
            return item
        end
    end
    if uuid ~= "" and NMInventoryHelpers.findWorldItemByUuidNearPlayer then
        item = NMInventoryHelpers.findWorldItemByUuidNearPlayer(player, uuid, 8)
        if item then
            return item
        end
    end
    if itemId ~= "" and NMInventoryHelpers.findWorldItemByIdNearPlayer then
        return NMInventoryHelpers.findWorldItemByIdNearPlayer(player, itemId, 8)
    end
    return nil
end

function NMCDPlayerWindow.queuePersistedRestore(playerNum)
    if not isFancyUIEnabled() then
        return
    end
    if NMClientMainRuntime and NMClientMainRuntime.requestTickGateWake then
        NMClientMainRuntime.requestTickGateWake("cdplayer_restore_queue")
    end
    local key = tostring(tonumber(playerNum) or 0)
    pendingRestoreByPlayer[key] = {
        playerNum = tonumber(playerNum) or 0,
        expiresAt = getNowMs() + RESTORE_RETRY_WINDOW_MS,
    }
end

function NMCDPlayerWindow.restorePersistedStateForPlayer(playerNum)
    if not isFancyUIEnabled() then
        pendingRestoreByPlayer[tostring(tonumber(playerNum) or 0)] = nil
        return false
    end
    local persisted = loadPersistedWindowState(playerNum)
    if not persisted or persisted.open ~= true then
        pendingRestoreByPlayer[tostring(tonumber(playerNum) or 0)] = nil
        return false
    end
    local player = getPlayer(playerNum)
    if not player then
        return false
    end
    local item = resolvePersistedTargetItem(player, persisted)
    if not item then
        return false
    end
    local win = NMCDPlayerWindow.openForItem(playerNum, item)
    if not win then
        return false
    end
    if persisted.expandedY ~= nil then
        win._nmExpandedY = win:clampWindowY(persisted.expandedY)
    end
    win:snapToState(persisted.collapsed == true)
    persistWindowState(win, true)
    pendingRestoreByPlayer[tostring(tonumber(playerNum) or 0)] = nil
    return true
end

function NMCDPlayerWindow.tickPersistedRestore()
    if not isFancyUIEnabled() then
        return
    end
    local nowMs = getNowMs()
    for key, entry in pairs(pendingRestoreByPlayer) do
        local playerNum = tonumber(entry and entry.playerNum) or 0
        if NMCDPlayerWindow.restorePersistedStateForPlayer(playerNum) == true then
            pendingRestoreByPlayer[key] = nil
        elseif nowMs >= (tonumber(entry and entry.expiresAt) or 0) then
            clearPersistedOpenFlag(playerNum)
            pendingRestoreByPlayer[key] = nil
        end
    end
end

function NMCDPlayerWindow.hasPendingPersistedRestore()
    for _ in pairs(pendingRestoreByPlayer) do
        return true
    end
    return false
end
