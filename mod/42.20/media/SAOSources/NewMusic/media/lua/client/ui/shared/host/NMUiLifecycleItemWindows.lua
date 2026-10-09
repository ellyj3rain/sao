local lifecycle = {}

local function getWindowRegistry(env)
    return env and env.WindowRegistry or nil
end

local function collectPlayerWindows(env, playerNum)
    local registry = getWindowRegistry(env)
    if registry and registry.collectWindows then
        return registry.collectWindows(env, playerNum) or {}
    end
    return {}
end

local function collectAllWindows(env)
    local registry = getWindowRegistry(env)
    if registry and registry.collectAllWindows then
        return registry.collectAllWindows(env) or {}
    end
    return {}
end

local function resolveItemTargetKey(itemId, itemUuid)
    local registry = rawget(_G, "NMUiLifecycleWindowRegistry") or rawget(_G, "NMPortableWindowRegistry") or nil
    return registry and registry.itemTargetKey and registry.itemTargetKey(itemId, itemUuid) or ""
end

local function itemWindowMatchesIdentity(window, itemId, itemUuid)
    if not (window and window.target and window.target.kind == "item") then
        return false
    end
    local target = window.target
    local targetItemId = tostring(target.itemId or "")
    local targetUuid = tostring(target.uuid or "")
    if itemUuid ~= "" and targetUuid ~= "" and targetUuid == itemUuid then
        return true
    end
    if itemId ~= "" and targetItemId == itemId and (itemUuid == "" or targetUuid == "") then
        return true
    end
    return false
end

function lifecycle.resolveItemWindowIdentity(item)
    if not item then
        return {
            itemId = "",
            itemUuid = "",
            targetKey = "",
            profile = nil,
            state = nil,
        }
    end
    local profile = NMDeviceProfiles and NMDeviceProfiles.getForItem and NMDeviceProfiles.getForItem(item) or nil
    local state = profile and NMDeviceState and NMDeviceState.ensure and NMDeviceState.ensure(item, profile) or nil
    local itemId = tostring(NMCore and NMCore.itemId and NMCore.itemId(item) or "")
    local itemUuid = tostring(
        state and state.deviceUUID
            or (NMInventoryHelpers and NMInventoryHelpers.getItemStateUuid and NMInventoryHelpers.getItemStateUuid(item))
            or ""
    )
    local targetKey = resolveItemTargetKey(itemId, itemUuid)
    return {
        itemId = itemId,
        itemUuid = itemUuid,
        targetKey = tostring(targetKey or ""),
        profile = profile,
        state = state,
    }
end

function lifecycle.resolveItemLifecycleContext(item)
    local identity = lifecycle.resolveItemWindowIdentity(item)
    identity.deviceType = tostring(identity.profile and identity.profile.deviceType or "")
    return identity
end

local function itemWindowMatchesTarget(window, itemId, itemUuid, options)
    if not (window and window.javaObject and window.target and window.target.kind == "item") then
        return false, "", ""
    end
    local target = window.target
    local targetItemId = tostring(target.itemId or "")
    local resolveWindowUuid = options and options.resolveWindowUuid or nil
    local targetUuid = resolveWindowUuid and tostring(resolveWindowUuid(window) or "") or tostring(target.uuid or "")
    return itemWindowMatchesIdentity(window, itemId, itemUuid)
        or (itemId ~= "" and targetItemId ~= "" and targetItemId == itemId and (itemUuid == "" or targetUuid == "" or itemUuid == targetUuid)),
        targetItemId,
        targetUuid
end

local function iterMatchingItemWindows(wins, itemId, itemUuid, options, visitor)
    local matched = false
    for i = 1, #wins do
        local win = wins[i]
        local isMatch, targetItemId, targetUuid = itemWindowMatchesTarget(win, itemId, itemUuid, options)
        if isMatch then
            matched = true
            if visitor(win, targetItemId, targetUuid) == true then
                return true
            end
        end
    end
    return matched
end

local function findFallbackItemWindow(env, playerNum, itemId, itemUuid)
    local incomingItemId = tostring(itemId or "")
    local incomingUuid = tostring(itemUuid or "")
    if incomingItemId == "" then
        return nil
    end
    local wins = collectPlayerWindows(env, playerNum)
    for i = 1, #wins do
        local win = wins[i]
        if itemWindowMatchesIdentity(win, incomingItemId, incomingUuid) then
            return win
        end
    end
    return nil
end

function lifecycle.findOpenItemWindowByIdentity(env, playerNum, identity)
    local resolved = type(identity) == "table" and identity or {}
    local itemId = tostring(resolved.itemId or "")
    local itemUuid = tostring(resolved.itemUuid or "")
    local targetKey = tostring(resolved.targetKey or "")
    local info = {
        targetKey = targetKey,
        registryHit = false,
        fallbackHit = false,
    }
    local registry = getWindowRegistry(env)
    if targetKey ~= "" and registry and registry.findWindow then
        local exact = registry.findWindow(env, playerNum, targetKey)
        if exact then
            info.registryHit = true
            return exact, info
        end
    end
    local fallback = findFallbackItemWindow(env, playerNum, itemId, itemUuid)
    if fallback then
        info.fallbackHit = true
    end
    return fallback, info
end

function lifecycle.resolveLiveItemByTarget(player, target)
    if not (player and target) then
        return nil
    end
    local uuid = tostring(target.uuid or "")
    local itemId = tostring(target.itemId or "")
    local inv = player.getInventory and player:getInventory() or nil
    local item = nil
    if inv and uuid ~= "" and NMInventoryHelpers and NMInventoryHelpers.findItemByUuid then
        item = NMInventoryHelpers.findItemByUuid(inv, uuid)
    end
    if not item and inv and itemId ~= "" and NMInventoryHelpers and NMInventoryHelpers.findItemById then
        item = NMInventoryHelpers.findItemById(inv, itemId)
    end
    if not item and uuid ~= "" and NMInventoryHelpers and NMInventoryHelpers.findWorldItemByUuidNearPlayer then
        item = NMInventoryHelpers.findWorldItemByUuidNearPlayer(player, uuid, 8)
    end
    if not item and itemId ~= "" and NMInventoryHelpers and NMInventoryHelpers.findWorldItemByIdNearPlayer then
        item = NMInventoryHelpers.findWorldItemByIdNearPlayer(player, itemId, 8)
    end
    return item
end

function lifecycle.invalidateOpenItemWindows(env, itemId, itemUuid, options)
    local incomingItemId = tostring(itemId or "")
    local incomingUuid = tostring(itemUuid or "")
    if incomingItemId == "" then
        return false
    end
    local invalidated = false
    local wins = collectAllWindows(env)
    local opts = options or {}
    iterMatchingItemWindows(wins, incomingItemId, incomingUuid, opts, function(win)
        local deferred = opts.deferInvalidate and opts.deferInvalidate(win) == true or false
        if deferred ~= true and opts.invalidateWindow then
            opts.invalidateWindow(win)
        end
        invalidated = true
        return false
    end)
    return invalidated
end

function lifecycle.rebindOpenItemWindows(env, itemId, itemUuid, options)
    local incomingItemId = tostring(itemId or "")
    local incomingUuid = tostring(itemUuid or "")
    if incomingItemId == "" and incomingUuid == "" then
        return false
    end
    local rebound = false
    local wins = collectAllWindows(env)
    local opts = options or {}
    iterMatchingItemWindows(wins, incomingItemId, incomingUuid, opts, function(win, targetItemId, targetUuid)
        local player = getPlayer and getPlayer(win.playerNum) or nil
        if player then
            local item = lifecycle.resolveLiveItemByTarget(player, {
                itemId = incomingItemId ~= "" and incomingItemId or targetItemId,
                uuid = incomingUuid ~= "" and incomingUuid or targetUuid,
            })
            if item then
                local resolvedIdentity = lifecycle.resolveItemWindowIdentity(item)
                win.target.itemId = resolvedIdentity.itemId ~= "" and resolvedIdentity.itemId or nil
                win.target.uuid = resolvedIdentity.itemUuid ~= "" and resolvedIdentity.itemUuid or incomingUuid
                win.target.itemRef = item
                win._nmPortableTargetKey = resolvedIdentity.targetKey ~= "" and resolvedIdentity.targetKey
                    or resolveItemTargetKey(win.target.itemId, win.target.uuid)
                local deferred = opts.deferInvalidate and opts.deferInvalidate(win) == true or false
                if deferred ~= true and opts.invalidateWindow then
                    opts.invalidateWindow(win, item)
                end
                rebound = true
            end
        end
        return false
    end)
    return rebound
end

function lifecycle.inspectOpenItemWindowTarget(env, playerNum)
    local wins = collectPlayerWindows(env, playerNum)
    for i = 1, #wins do
        local win = wins[i]
        if win and win.javaObject and win.target and win.target.kind == "item" then
            return {
                playerNum = tonumber(win.playerNum) or 0,
                itemId = tostring(win.target.itemId or ""),
                uuid = tostring(win.target.uuid or ""),
                hasItemRef = win.target.itemRef ~= nil,
                mediaTimedAction = tostring(win._nmMediaSlotTimedProgress and win._nmMediaSlotTimedProgress.action or ""),
                pendingMediaFullType = tostring(win._nmPendingMediaSlotFullType or ""),
                awaitingMediaInsert = win.isAwaitingAuthoritativeMediaInsert and win:isAwaitingAuthoritativeMediaInsert() == true or false,
                awaitingMediaEject = win.isAwaitingAuthoritativeMediaEject and win:isAwaitingAuthoritativeMediaEject() == true or false,
            }
        end
    end
    return nil
end

function lifecycle.applyOpenItemWindowChange(env, itemId, itemUuid, options)
    local opts = options or {}
    if opts.mode == "rebind" then
        return lifecycle.rebindOpenItemWindows(env, itemId, itemUuid, opts)
    end
    return lifecycle.invalidateOpenItemWindows(env, itemId, itemUuid, opts)
end

function lifecycle.closeOpenForItemTarget(env, playerNum, itemId, itemUuid, options)
    local incomingItemId = tostring(itemId or "")
    local incomingUuid = tostring(itemUuid or "")
    if incomingItemId == "" then
        return false
    end
    local wins = collectPlayerWindows(env, playerNum)
    local opts = options or {}
    local closed = false
    iterMatchingItemWindows(wins, incomingItemId, incomingUuid, opts, function(win)
        if opts.closeWindow then
            opts.closeWindow(win)
        elseif win.close then
            win:close()
        elseif win.removeFromUIManager then
            win:removeFromUIManager()
        end
        closed = true
        return true
    end)
    return closed
end

return lifecycle
