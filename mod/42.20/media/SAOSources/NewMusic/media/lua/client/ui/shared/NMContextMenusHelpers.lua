local env = _G.NMContextMenusEnv
setfenv(1, env)

local UiLifecycleItemWindows = require "ui/shared/host/NMUiLifecycleItemWindows"

function collectSelectedInventoryItems(items)
    local out = {}
    if not items then return out end
    for i = 1, #items do
        local entry = items[i]
        if type(entry) == "table" and entry.items then
            for j = 1, #entry.items do
                local it = entry.items[j]
                if it then
                    out[#out + 1] = it
                end
            end
        elseif entry and type(entry) == "userdata" then
            out[#out + 1] = entry
        end
    end
    return out
end

function isItemInPlayerInventory(player, item)
    if not (player and item and player.getInventory and item.getID) then
        return false
    end
    local inv = player:getInventory()
    if not inv then
        return false
    end
    local targetId = tostring(item:getID() or "")
    if targetId == "" then
        return false
    end
    local all = {}
    NMInventoryHelpers.collectItemsRecursive(inv, all)
    for i = 1, #all do
        local it = all[i]
        if it and it.getID and tostring(it:getID() or "") == targetId then
            return true
        end
    end
    return false
end

function setOptionIcon(option, texture)
    if not option or not texture then
        return
    end
    option.iconTexture = texture
end

function resolveTextureByItemType(typeName)
    local key = tostring(typeName or "")
    if key == "" or not getTexture then
        return nil
    end
    local texKey = "Item_NM_" .. key
    return getTexture(texKey) or getTexture("media/textures/" .. texKey .. ".png")
end

function resolveTextureByFullType(fullType)
    local ft = tostring(fullType or "")
    if ft == "" or not getTexture then
        return nil
    end

    local scriptItem = ScriptManager and ScriptManager.instance and ScriptManager.instance.FindItem
        and ScriptManager.instance:FindItem(ft) or nil
    if scriptItem and scriptItem.getIcon then
        local iconName = tostring(scriptItem:getIcon() or "")
        if iconName ~= "" then
            local tex = getTexture("Item_" .. iconName) or getTexture("media/textures/Item_" .. iconName .. ".png")
            if tex then
                return tex
            end
        end
    end

    local mediaType = ft
    local dotPos = string.find(mediaType, "%.")
    if dotPos then
        mediaType = string.sub(mediaType, dotPos + 1)
    end
    return getTexture("Item_" .. mediaType)
        or getTexture("media/textures/Item_" .. mediaType .. ".png")
        or resolveTextureByItemType(mediaType)
end

function resolveItemIconTexture(item, profile, state)
    if profile and profile.isMediaContainerOnly == true then
        local mediaFullType = tostring(state and state.mediaFullType or "")
        if mediaFullType == "" and item and item.getFullType and NMMediaContract and NMMediaContract.resolveContainerMediaBinding then
            mediaFullType = tostring(NMMediaContract.resolveContainerMediaBinding(item:getFullType()) or "")
        end
        if mediaFullType ~= "" then
            local mediaTex = resolveTextureByFullType(mediaFullType)
            if mediaTex then
                return mediaTex
            end
        end
    end

    local typeName = item and item.getType and tostring(item:getType() or "") or ""
    local texture = resolveTextureByItemType(typeName)
    if texture then
        return texture
    end

    local deviceType = profile and tostring(profile.deviceType or "") or ""
    local fallbackKey = fallbackIconByDeviceType[deviceType]
    if fallbackKey and getTexture then
        texture = getTexture(fallbackKey) or getTexture("media/textures/" .. fallbackKey .. ".png")
    end
    if texture then
        return texture
    end

    return nil
end

function resolveProfileDeviceTypeLabel(profile)
    local deviceType = profile and tostring(profile.deviceType or "") or ""
    if deviceType == "boombox" then return NMTranslations.ui("Boombox", "Boombox") end
    if deviceType == "walkman" then return NMTranslations.ui("Walkman", "Walkman") end
    if deviceType == "vinylplayer" then return NMTranslations.ui("VinylPlayer", "Vinyl Player") end
    if deviceType == "cdplayer" then return NMTranslations.ui("CDPlayer", "CD Player") end
    if deviceType == "vehicle_radio" then return NMTranslations.ui("Vehicle", "Vehicle") end
    if deviceType ~= "" then
        local pretty = deviceType:gsub("_", " ")
        pretty = pretty:gsub("(%a)([%w_']*)", function(first, rest)
            return string.upper(first) .. string.lower(rest or "")
        end)
        return pretty
    end
    return NMTranslations.ui("Device", "Device")
end

function resolveDeviceMenuLabel(item, profile)
    local displayName = item and item.getDisplayName and tostring(item:getDisplayName() or "") or ""
    if displayName ~= "" then
        return displayName
    end
    return resolveProfileDeviceTypeLabel(profile)
end

function NMContextMenus.resolveMenuIconTexture(item, profile, state)
    return resolveItemIconTexture(item, profile, state)
end

function collectCandidates(player, predicate)
    local inv = player and player.getInventory and player:getInventory() or nil
    if not inv then return {} end
    local all = {}
    NMInventoryHelpers.collectItemsRecursive(inv, all)
    local out = {}
    for i = 1, #all do
        local it = all[i]
        if it and predicate(it) then
            out[#out + 1] = it
        end
    end
    return out
end

function resolveLiveItemByIdOrAlias(player, itemId)
    local id = tostring(itemId or "")
    if id == "" then
        return nil, id
    end
    local inv = player and player.getInventory and player:getInventory() or nil
    if not inv then
        return nil, id
    end
    local seen = {}
    local current = id
    local newest = current
    local advanced = false
    -- Prefer newest known alias first; stale pre-flip ids can linger client-side.
    for _ = 1, 8 do
        if seen[current] then
            break
        end
        seen[current] = true
        local nextId = NMContextMenus._flipIdAlias and NMContextMenus._flipIdAlias[current] or nil
        nextId = tostring(nextId or "")
        if nextId == "" or nextId == current then
            break
        end
        current = nextId
        newest = current
        advanced = true
    end
    local foundNewest = NMInventoryHelpers and NMInventoryHelpers.findItemById and NMInventoryHelpers.findItemById(inv, newest) or nil
    if foundNewest then
        return foundNewest, newest
    end
    if advanced then
        -- Critical safety: never fall back to stale pre-flip ids after aliasing.
        -- If newest is not visible yet, wait for sync instead of sending stale ids.
        return nil, newest
    end
    local found = NMInventoryHelpers and NMInventoryHelpers.findItemById and NMInventoryHelpers.findItemById(inv, id) or nil
    if found then
        return found, id
    end
    return nil, current
end

function collectMediaCandidates(player, carrier)
    return collectCandidates(player, function(it)
        local profile = NMDeviceProfiles and NMDeviceProfiles.getForItem and NMDeviceProfiles.getForItem(it) or nil
        if profile and profile.isMediaContainerOnly ~= true then
            return false
        end
        local fullType = it.getFullType and it:getFullType() or nil
        local typeName = it.getType and it:getType() or nil
        local resolved = NMMediaContract.resolveMediaCarrier(fullType or typeName)
        return resolved and tostring(resolved) == tostring(carrier or "")
    end)
end

function addAction(menu, label, player, fn)
    if not menu then
        return nil
    end
    return menu:addOption(label, player, fn)
end

function resolveDeviceUiLifecycleOptionSpec(player, item)
    if not (player and item and NMDeviceUI) then
        return nil
    end
    local playerNum = player.getPlayerNum and player:getPlayerNum() or 0
    local openWindow = NMDeviceUI.findOpenForItem and NMDeviceUI.findOpenForItem(playerNum, item) or nil
    if openWindow then
        local identity = UiLifecycleItemWindows.resolveItemLifecycleContext(item)
        return {
            label = NMTranslations.ui("Close", "Close"),
            handler = function(p, targetItem)
                local targetPlayerNum = p and p.getPlayerNum and p:getPlayerNum() or playerNum
                local targetIdentity = UiLifecycleItemWindows.resolveItemLifecycleContext(targetItem)
                NMDeviceUI.closeForItem(targetPlayerNum, targetIdentity.itemId, targetIdentity.itemUuid)
            end,
        }
    end
    return {
        label = NMTranslations.ui("Open", "Open"),
        handler = function(p, targetItem)
            local targetPlayerNum = p and p.getPlayerNum and p:getPlayerNum() or playerNum
            NMDeviceUI.openForItem(targetPlayerNum, targetItem)
        end,
    }
end

function addDeviceUiLifecycleOption(menu, player, item, profile, state)
    local spec = resolveDeviceUiLifecycleOptionSpec(player, item)
    if not spec then
        return nil
    end
    local option = menu:addOption(spec.label, player, spec.handler, item)
    setOptionIcon(option, NMContextMenus.resolveMenuIconTexture(item, profile, state))
    return option
end

function canShowDeviceDisassemble(player, item, profile)
    if not (NMDeviceDisassembly and NMDeviceDisassembly.isEnabled and NMDeviceDisassembly.isEnabled()) then
        return false
    end
    if not (NMDeviceDisassembly and NMDeviceDisassembly.canDisassembleNow) then
        return false
    end
    return NMDeviceDisassembly.canDisassembleNow(player, item, profile)
end

function queueDeviceDisassembleAction(player, item)
    if not (player and item and NMDeviceDisassembly and NMDeviceDisassembly.resolveScrewdriver) then
        return
    end
    local screwdriver = NMDeviceDisassembly.resolveScrewdriver(player)
    if not screwdriver then
        return
    end
    if ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.equipWeapon then
        ISInventoryPaneContextMenu.equipWeapon(screwdriver, true, false, player:getPlayerNum())
    end
    ISTimedActionQueue.add(NMDisassembleDeviceAction:new(player, item, 120))
end

function addInsertSubmenu(menu, label, player, candidates, onPick)
    local option = menu:addOption(label, player, nil)
    local sub = ISContextMenu:getNew(menu)
    menu:addSubMenu(option, sub)
    if #candidates < 1 then
        local none = sub:addOption(NMTranslations.ui("NoCompatibleItemInInventory", "No compatible item in inventory"), player, function() end)
        none.notAvailable = true
        return
    end
    for i = 1, #candidates do
        local it = candidates[i]
        local name = it.getDisplayName and tostring(it:getDisplayName() or NMTranslations.ui("Device", "Device")) or NMTranslations.ui("Device", "Device")
        sub:addOption(name, player, function(p)
            onPick(p, it)
        end)
    end
end

function resolveMediaActionLabel(profile, hasMedia)
    local carrier = tostring(profile and profile.supportedCarrier or "")
    if carrier == tostring(NMMediaContract and NMMediaContract.CASSETTE_CARRIER or "") then
        return hasMedia and NMTranslations.ui("RemoveCassette", "Remove Cassette") or NMTranslations.ui("InsertCassette", "Insert Cassette")
    end
    if carrier == tostring(NMMediaContract and NMMediaContract.CD_CARRIER or "") then
        return hasMedia and NMTranslations.ui("RemoveCD", "Remove CD") or NMTranslations.ui("InsertCD", "Insert CD")
    end
    if carrier == tostring(NMMediaContract and NMMediaContract.VINYL_CARRIER or "") then
        return hasMedia and NMTranslations.ui("RemoveVinyl", "Remove Vinyl") or NMTranslations.ui("InsertVinyl", "Insert Vinyl")
    end
    return hasMedia and NMTranslations.ui("EjectMedia", "Eject Media") or NMTranslations.ui("InsertMedia", "Insert Media")
end

function buildCaseMediaInsertArgs(mediaItem)
    local payload = NMMediaHelpers and NMMediaHelpers.resolveMediaInsertPayload and NMMediaHelpers.resolveMediaInsertPayload(mediaItem) or nil
    if not payload then
        return nil
    end
    return {
        mediaItemId = NMCore.itemId(mediaItem),
        mediaItemUuid = NMInventoryHelpers and NMInventoryHelpers.getItemStateUuid and NMInventoryHelpers.getItemStateUuid(mediaItem) or nil,
        mediaFullType = payload.mediaFullType,
        mediaCarrier = payload.mediaCarrier,
        mediaEjectFullType = payload.mediaEjectFullType,
        mediaCanonicalFullType = payload.mediaCanonicalFullType,
        mediaRecordedMediaIndex = payload.mediaRecordedMediaIndex,
        mediaDisplayName = payload.mediaDisplayName
    }
end

