NMZombieMediaPayloadRuntime = NMZombieMediaPayloadRuntime or {}
require "zombies/NMZombieMediaPayloadResolver"
require "contracts/NMMediaContract"

local function hasText(value)
    return tostring(value or "") ~= ""
end

local function getInventory(holder)
    return holder and holder.getInventory and holder:getInventory() or holder
end

local function getRootModData(holder)
    return holder and holder.getModData and holder:getModData() or nil
end

local function getZombieLootModData(holder)
    local root = getRootModData(holder)
    if not root then
        return nil
    end
    root.nmZombieLoot = root.nmZombieLoot or {}
    return root.nmZombieLoot
end

local function getInventoryOwner(holder, inventory)
    if holder and holder.getInventory and holder.getModData then
        return holder
    end
    return inventory and inventory.getParent and inventory:getParent() or nil
end

local function isDeadBodyOwner(owner)
    return owner and instanceof and instanceof(owner, "IsoDeadBody")
end

local function resolveMediaDisplayName(fullType)
    local resolvedType = tostring(fullType or "")
    if resolvedType == "" then
        return nil
    end
    if NMMediaContract and NMMediaContract.getDisplayNameForFullType then
        local ok, display = pcall(NMMediaContract.getDisplayNameForFullType, resolvedType)
        local text = ok and tostring(display or "") or ""
        if text ~= "" then
            return text
        end
    end
    local scriptManager = ScriptManager and ScriptManager.instance or nil
    local item = scriptManager and scriptManager.FindItem and scriptManager:FindItem(resolvedType)
        or scriptManager and scriptManager.getItem and scriptManager:getItem(resolvedType)
        or nil
    if item and item.getDisplayName then
        local ok, display = pcall(item.getDisplayName, item)
        local text = ok and tostring(display or "") or ""
        if text ~= "" then
            return text
        end
    end
    local tracks = NMMusic and NMMusic.resolveTracks and NMMusic.resolveTracks(resolvedType) or nil
    local firstTrack = tracks and type(tracks.tracks) == "table" and tracks.tracks[1] or nil
    if firstTrack and hasText(firstTrack.label) then
        return tostring(firstTrack.label)
    end
    return nil
end

local function countItemsByFullType(inventory, fullType)
    local wanted = tostring(fullType or "")
    if wanted == "" then
        return 0
    end
    local count = 0
    local items = inventory and inventory.getItems and inventory:getItems() or nil
    if not (items and items.size) then
        return 0
    end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local current = item and item.getFullType and tostring(item:getFullType() or "") or ""
        if current == wanted then
            count = count + 1
        end
    end
    return count
end

local function removeItemsByFullType(inventory, fullType, removeCount)
    local wanted = tostring(fullType or "")
    local remaining = tonumber(removeCount) or 0
    if wanted == "" or remaining <= 0 then
        return 0, {}
    end
    local removed = 0
    local removedItems = {}
    local items = inventory and inventory.getItems and inventory:getItems() or nil
    if not (items and items.size) then
        return 0, removedItems
    end
    local removals = {}
    for i = 0, items:size() - 1 do
        if removed + #removals >= remaining then
            break
        end
        local item = items:get(i)
        local current = item and item.getFullType and tostring(item:getFullType() or "") or ""
        if current == wanted then
            removals[#removals + 1] = item
        end
    end
    for i = 1, #removals do
        if NMZombieAudioVisualSupport and NMZombieAudioVisualSupport.removeInventoryItem and NMZombieAudioVisualSupport.removeInventoryItem(inventory, removals[i]) then
            removed = removed + 1
            removedItems[#removedItems + 1] = removals[i]
        end
    end
    return removed, removedItems
end

local function ensureItemCount(inventory, fullType, wantedCount)
    local wanted = math.max(0, math.floor(tonumber(wantedCount) or 0))
    local current = countItemsByFullType(inventory, fullType)
    local delta = {
        added = {},
        removed = {}
    }
    if current > wanted then
        local _, removedItems = removeItemsByFullType(inventory, fullType, current - wanted)
        delta.removed = removedItems
        return delta
    end
    while current < wanted do
        if NMZombieAudioVisualSupport and NMZombieAudioVisualSupport.addInventoryItem then
            local item = NMZombieAudioVisualSupport.addInventoryItem(inventory, { fullType = tostring(fullType or "") })
            if not item then
                break
            end
            delta.added[#delta.added + 1] = item
        else
            break
        end
        current = current + 1
    end
    return delta
end

local function syncContainerReplication(owner, inventory, delta)
    if type(delta) ~= "table" then
        return
    end
    if isDeadBodyOwner(owner) and sendRemoveItemFromContainer then
        for i = 1, #(delta.removed or {}) do
            pcall(sendRemoveItemFromContainer, inventory, delta.removed[i])
        end
    end
    if isDeadBodyOwner(owner) and sendAddItemToContainer then
        for i = 1, #(delta.added or {}) do
            pcall(sendAddItemToContainer, inventory, delta.added[i])
        end
    end
end

local function syncOwnerInventory(owner, changed)
    if changed ~= true then
        return
    end
    if owner and owner.doInventorySync then
        pcall(owner.doInventorySync, owner)
    end
end

function NMZombieMediaPayloadRuntime.buildCorpseLooseLootFullTypes(payload)
    local out = {}
    if type(payload) ~= "table" then
        return out
    end
    if tostring(payload.mediaMode or "") == "device_with_media" then
        local caseEmpty = tostring(payload.caseEmptyType or "")
        if caseEmpty ~= "" then
            out[#out + 1] = caseEmpty
        end
        return out
    end
    if tostring(payload.mediaMode or "") == "media_only" then
        local caseFull = tostring(payload.caseFullType or "")
        if caseFull ~= "" then
            out[#out + 1] = caseFull
        end
    end
    return out
end

function NMZombieMediaPayloadRuntime.stampCorpseLooseLoot(holder, payload)
    local zombieLoot = getZombieLootModData(holder)
    if not zombieLoot then
        return
    end
    local looseLoot = NMZombieMediaPayloadRuntime.buildCorpseLooseLootFullTypes(payload)
    zombieLoot.corpseLooseLootFullTypes = {}
    for i = 1, #looseLoot do
        zombieLoot.corpseLooseLootFullTypes[#zombieLoot.corpseLooseLootFullTypes + 1] = looseLoot[i]
    end
    if holder and holder.transmitModData then
        pcall(holder.transmitModData, holder)
    end
end

function NMZombieMediaPayloadRuntime.applyPayloadToState(state, payload)
    if type(state) ~= "table" or type(payload) ~= "table" then
        return
    end
    state.mediaFullType = payload.mediaMode == "device_with_media" and payload.insertedMediaFullType or nil
    state.mediaEjectFullType = payload.mediaMode == "device_with_media" and (payload.mediaEjectFullType or payload.insertedMediaFullType) or nil
    state.mediaRecordedMediaIndex = payload.mediaMode == "device_with_media" and payload.mediaRecordedMediaIndex or nil
    state.mediaDisplayName = payload.mediaMode == "device_with_media" and resolveMediaDisplayName(payload.insertedMediaFullType) or nil
    state.headphoneItemFullType = hasText(payload.headphoneItemFullType) and tostring(payload.headphoneItemFullType) or nil
    state._headphoneSlotInitialized = true
    state.batteryPresent = payload.batteryPresent == true
    state.batteryCharge = payload.batteryPresent == true and (tonumber(payload.batteryCharge) or 1.0) or 0.0
end

function NMZombieMediaPayloadRuntime.syncInventoryPayload(holder, payload, previousPayload)
    local inventory = getInventory(holder)
    if not inventory then
        return
    end
    local owner = getInventoryOwner(holder, inventory)
    local wantedFull = type(payload) == "table" and payload.mediaMode == "media_only" and payload.caseFullType or nil
    local wantedEmpty = type(payload) == "table" and payload.mediaMode == "device_with_media" and payload.caseEmptyType or nil
    local candidates = {}
    local changed = false

    local function addCandidate(fullType)
        local key = tostring(fullType or "")
        if key ~= "" then
            candidates[key] = true
        end
    end

    addCandidate(wantedFull)
    addCandidate(wantedEmpty)
    if type(previousPayload) == "table" then
        addCandidate(previousPayload.caseFullType)
        addCandidate(previousPayload.caseEmptyType)
    end

    for fullType in pairs(candidates) do
        local wantedCount = 0
        if fullType == tostring(wantedFull or "") then
            wantedCount = 1
        elseif fullType == tostring(wantedEmpty or "") then
            wantedCount = 1
        end
        local delta = ensureItemCount(inventory, fullType, wantedCount)
        if delta then
            if #(delta.added or {}) > 0 or #(delta.removed or {}) > 0 then
                changed = true
            end
            syncContainerReplication(owner, inventory, delta)
        end
    end
    syncOwnerInventory(owner, changed)
end

return NMZombieMediaPayloadRuntime
