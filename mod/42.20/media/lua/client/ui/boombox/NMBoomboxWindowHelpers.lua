-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
require "ui/shared/host/NMDeviceUiTime"
require "ui/shared/slots/NMPortableUiSoundContract"

local env = _G.NMBoomboxWindowEnv
setfenv(1, env)

function getPlayer(playerNum)
    return getSpecificPlayer and getSpecificPlayer(playerNum) or nil
end

function getNowMs()
    return NMDeviceUiTime.nowMs()
end

function getPlayerModData(player)
    if not (player and player.getModData) then
        return nil
    end
    local md = player:getModData()
    return type(md) == "table" and md or nil
end

function getPersistedUIState(player, create)
    local md = getPlayerModData(player)
    if not md then
        return nil
    end
    local data = md[PERSISTED_UI_STATE_KEY]
    if type(data) ~= "table" then
        if create ~= true then
            return nil
        end
        data = {}
        md[PERSISTED_UI_STATE_KEY] = data
    end
    return data
end

function transmitPlayerModData(player)
    if player and player.transmitModData then
        pcall(player.transmitModData, player)
    end
end

function getScreenSize()
    local core = getCore and getCore() or nil
    return core and core:getScreenWidth() or 1280, core and core:getScreenHeight() or 720
end

function getFancyDeviceUiScale()
    if NMFancyDeviceUiScale and NMFancyDeviceUiScale.getEffectiveScale then
        return NMFancyDeviceUiScale.getEffectiveScale()
    end
    return 1.0
end

function clamp01(v)
    local n = tonumber(v) or 0.0
    if n < 0.0 then return 0.0 end
    if n > 1.0 then return 1.0 end
    return n
end

function pointInRect(x, y, rect)
    if not rect then
        return false
    end
    return x >= rect.x and y >= rect.y and x < (rect.x + rect.w) and y < (rect.y + rect.h)
end

local function isItemRefValidForTarget(item, target)
    if not (item and item.getID and target) then
        return false
    end
    local targetItemId = tostring(target.itemId or "")
    if targetItemId == "" or tostring(item:getID() or "") ~= targetItemId then
        return false
    end
    local targetUuid = tostring(target.uuid or "")
    if targetUuid ~= "" and NMInventoryHelpers and NMInventoryHelpers.getItemStateUuid then
        local itemUuid = tostring(NMInventoryHelpers.getItemStateUuid(item) or "")
        if itemUuid ~= "" and itemUuid ~= targetUuid then
            return false
        end
    end
    local worldItem = item.getWorldItem and item:getWorldItem() or nil
    if worldItem then
        return true
    end
    local container = item.getContainer and item:getContainer() or nil
    return container ~= nil
end

function resolveLiveItemByTarget(player, target)
    if not (player and target and NMInventoryHelpers) then
        return nil
    end
    local itemId = tostring(target.itemId or "")
    local uuid = tostring(target.uuid or "")
    local item = target.itemRef
    if isItemRefValidForTarget(item, target) then
        return item
    end
    local inv = player.getInventory and player:getInventory() or nil
    if inv and uuid ~= "" and NMInventoryHelpers.findItemByUuid then
        item = NMInventoryHelpers.findItemByUuid(inv, uuid)
        if item then return item end
    end
    if inv and itemId ~= "" and NMInventoryHelpers.findItemById then
        item = NMInventoryHelpers.findItemById(inv, itemId)
        if item then return item end
    end
    if uuid ~= "" and NMInventoryHelpers.findWorldItemByUuidNearPlayer then
        item = NMInventoryHelpers.findWorldItemByUuidNearPlayer(player, uuid, 8)
        if item then return item end
    end
    if itemId ~= "" and NMInventoryHelpers.findWorldItemByIdNearPlayer then
        return NMInventoryHelpers.findWorldItemByIdNearPlayer(player, itemId, 8)
    end
    return nil
end

function resolveContextFreshUncached(window)
    local player = window and getPlayer(window.playerNum) or nil
    if not (player and window and window.target and window.target.kind == "item") then
        return nil
    end
    local item = resolveLiveItemByTarget(player, window.target)
    if not item then
        return nil
    end
    window.target.itemRef = item
    local profile = NMDeviceProfiles and NMDeviceProfiles.getForItem and NMDeviceProfiles.getForItem(item) or nil
    local localState = profile and NMDeviceState and NMDeviceState.ensure and NMDeviceState.ensure(item, profile) or nil
    local state = localState
    if localState and NMClientDisplayStateResolver and NMClientDisplayStateResolver.resolveForLiveItem then
        state = NMClientDisplayStateResolver.resolveForLiveItem(item, localState)
    end
    if not (profile and state) then
        return nil
    end
    return {
        player = player,
        item = item,
        profile = profile,
        state = state,
        localState = localState,
        kind = "item"
    }
end

function playBoomboxButtonSound(window, soundName)
    NMPortableUiSoundContract.playNamedSound(window, tostring(soundName or ""))
end

function playBoomboxSoundEvent(window, eventName)
    NMPortableUiSoundContract.playEvent(window, eventName)
end

function syncVolumeClickPercent(window, targetPct, playSound)
    if not window then
        return tonumber(targetPct) or 0
    end
    local normalizedTarget = math.max(0, math.min(100, math.floor((tonumber(targetPct) or 0) + 0.5)))
    local lastPct = tonumber(window._nmKnobLastClickPercent)
    if lastPct == nil then
        window._nmKnobLastClickPercent = normalizedTarget
        return normalizedTarget
    end
    if normalizedTarget == lastPct then
        return normalizedTarget
    end
    if playSound == true then
        local nowMs = getNowMs()
        local lastSoundMs = tonumber(window._nmKnobLastClickSoundMs) or 0
        if (nowMs - lastSoundMs) >= math.max(1, tonumber(VOLUME_CLICK_SOUND_MIN_MS) or 35) then
            playBoomboxButtonSound(window, "NM_Walkman_Volume_Click")
            window._nmKnobLastClickSoundMs = nowMs
        end
    end
    window._nmKnobLastClickPercent = normalizedTarget
    return normalizedTarget
end

function volumeToPercent(volume)
    return math.max(0, math.min(100, math.floor((clamp01(volume) * 100) + 0.5)))
end

function resolveDraggedInventoryItemsSnapshot()
    if not ISMouseDrag then return {}, true end
    local dragging = ISMouseDrag.dragging
    if dragging == nil then return {}, true end
    if type(dragging) ~= "table" then return nil, false end
    if #dragging <= 0 then return {}, true end
    if not (ISInventoryPane and ISInventoryPane.getActualItems) then
        return nil, false
    end
    local ok, actual = pcall(ISInventoryPane.getActualItems, dragging)
    if not ok or type(actual) ~= "table" then
        return nil, false
    end
    local out = {}
    for i = 1, #actual do
        local item = actual[i]
        if item and item.getFullType then
            out[#out + 1] = item
        end
    end
    return out, true
end

function clearMouseDragState()
    if not ISMouseDrag then return end
    ISMouseDrag.dragging = nil
    ISMouseDrag.draggingFocus = nil
end

function resolveDeviceCarrier(window)
    local resolved = window and window.resolveContextCached and window:resolveContextCached() or nil
    local profile = resolved and resolved.profile or nil
    return tostring(profile and profile.supportedCarrier or "")
end

function isCompatibleBoomboxMediaItem(window, item)
    if not (window and item and item.getFullType) then return false end
    local profile = NMDeviceProfiles and NMDeviceProfiles.getForItem and NMDeviceProfiles.getForItem(item) or nil
    if profile and profile.isMediaContainerOnly ~= true then
        return false
    end
    local requiredCarrier = resolveDeviceCarrier(window)
    if requiredCarrier == "" then return false end
    local fullType = item:getFullType()
    local typeName = item.getType and item:getType() or nil
    local resolvedCarrier = NMMediaContract and NMMediaContract.resolveMediaCarrier and NMMediaContract.resolveMediaCarrier(fullType or typeName) or nil
    return tostring(resolvedCarrier or "") == requiredCarrier
end

function isCompatibleBoomboxMediaDrag(window, items)
    if type(items) ~= "table" or #items <= 0 then return false end
    for i = 1, #items do
        if isCompatibleBoomboxMediaItem(window, items[i]) then
            return true
        end
    end
    return false
end

function normalizeBoomboxMediaIngressItem(window, item)
    local resolved = window and window.resolveContext and window:resolveContext() or nil
    local player = resolved and resolved.player or nil
    local itemId = item and NMCore and NMCore.itemId and NMCore.itemId(item) or nil
    local uuid = item and NMInventoryHelpers and NMInventoryHelpers.getItemStateUuid and NMInventoryHelpers.getItemStateUuid(item) or nil
    if not (player and itemId and NMInventoryHelpers and NMInventoryHelpers.normalizeItemToMainInventory) then
        return nil
    end
    return NMInventoryHelpers.normalizeItemToMainInventory(player, itemId, uuid)
end

function canQueueBoomboxMediaAction(window)
    if not window then return false end
    local resolved = window.resolveContext and window:resolveContext() or nil
    local player = resolved and resolved.player or nil
    local item = resolved and resolved.item or nil
    if not (player and item) then return false end
    local location = NMDeviceUIRange and NMDeviceUIRange.resolvePortableTargetLocation
        and NMDeviceUIRange.resolvePortableTargetLocation(window and window.target or nil, item) or nil
    if location and location.mode == "inventory" then
        return true
    end
    if location and location.mode == "placed_world" then
        return NMDeviceUIRange and NMDeviceUIRange.isPlayerWithinSquare and NMDeviceUIRange.isPlayerWithinSquare(player, location.square) or true
    end
    if location and location.mode == "detached_placed" and player.DistToSquared then
        local distSq = tonumber(player:DistToSquared(location.x, location.y)) or 999999
        local thresholdSq = NMDeviceUIRange and NMDeviceUIRange.getWorldInteractionRangeSq and NMDeviceUIRange.getWorldInteractionRangeSq() or (2.8 * 2.8)
        return distSq <= thresholdSq
    end
    return false
end

function queueBoomboxMediaAction(window, actionName, args)
    if not window then return false end
    if window._nmSlotRangeGateEnabled ~= false and not canQueueBoomboxMediaAction(window) then
        return false
    end
    local mediaEnv = rawget(_G, "NMMediaSlotEnv")
    local sharedQueue = mediaEnv and mediaEnv.queueMediaSlotAction or nil
    if sharedQueue then
        return sharedQueue(window, actionName, args or {})
    end
    return false
end

function resolveTrackCount(state)
    if not state or not state.mediaFullType or not NMMusic or not NMMusic.resolveTracks then
        return 0
    end
    local ok, resolved = pcall(NMMusic.resolveTracks, state.mediaFullType)
    if not ok or type(resolved) ~= "table" or type(resolved.tracks) ~= "table" then
        return 0
    end
    return #resolved.tracks
end

function attachBoomboxSlots(window)
    if not window or window._nmSlotsAttached == true then
        return
    end
    local mediaRect = window:getSlotRect(1)
    local batteryRect = window:getSlotRect(2)
    local headphoneRect = window:getSlotRect(3)
    window.mediaSlot = NMMediaSlot and NMMediaSlot.attach and NMMediaSlot.attach(window, mediaRect.x, mediaRect.y, SLOT_SIZE) or nil
    window.batterySlot = NMBatterySlot and NMBatterySlot.attach and NMBatterySlot.attach(window, batteryRect.x, batteryRect.y, SLOT_SIZE) or nil
    window.headphoneSlot = NMHeadphoneSlot and NMHeadphoneSlot.attach and NMHeadphoneSlot.attach(window, headphoneRect.x, headphoneRect.y, SLOT_SIZE) or nil
    window._nmSlotsAttached = true
end

local function updateChildRect(child, x, y, width, height)
    if not child then
        return
    end
    if child.setX then child:setX(x) else child.x = x end
    if child.setY then child:setY(y) else child.y = y end
    if child.setWidth then child:setWidth(width) else child.width = width end
    if child.setHeight then child:setHeight(height) else child.height = height end
    if child.setWidthSilent then
        child:setWidthSilent(width)
    end
end

local function reflowBoomboxSlotChildren(window)
    if not window then
        return
    end

    local mediaRect = window:getSlotRect(1)
    local batteryRect = window:getSlotRect(2)
    local headphoneRect = window:getSlotRect(3)
    local batteryEnv = rawget(_G, "NMBatterySlotEnv") or nil
    local barPadTop = tonumber(batteryEnv and batteryEnv.BAR_PAD_TOP) or 4
    local barHeight = tonumber(batteryEnv and batteryEnv.BAR_H) or 6

    updateChildRect(window.mediaSlot and window.mediaSlot.button or nil, mediaRect.x, mediaRect.y, SLOT_SIZE, SLOT_SIZE)
    updateChildRect(window.headphoneSlot and window.headphoneSlot.button or nil, headphoneRect.x, headphoneRect.y, SLOT_SIZE, SLOT_SIZE)
    updateChildRect(window.batterySlot and window.batterySlot.button or nil, batteryRect.x, batteryRect.y, SLOT_SIZE, SLOT_SIZE)
    updateChildRect(window.batterySlot and window.batterySlot.bar or nil, batteryRect.x, batteryRect.y + SLOT_SIZE + barPadTop, SLOT_SIZE, barHeight)
end

function BoomboxWindow:applyCurrentScaleLayout()
    refreshBoomboxLayoutMetrics()
    local currentScale = getFancyDeviceUiScale()
    if math.abs((tonumber(self._nmAppliedFancyScale) or 0.0) - currentScale) < 0.0001 and self.width == PANEL_W and self.height == PANEL_H then
        return
    end

    self._nmAppliedFancyScale = currentScale
    if self.setWidth then self:setWidth(PANEL_W) else self.width = PANEL_W end
    if self.setHeight then self:setHeight(PANEL_H) else self.height = PANEL_H end
    self.width = PANEL_W
    self.height = PANEL_H

    reflowBoomboxSlotChildren(self)

    local clampedX = self:clampWindowX(self:getX())
    self:setX(clampedX)
    self._nmExpandedY = self:clampWindowY(self._nmExpandedY or self:getDefaultExpandedY())
    self:setY(self:getStateY(self.isCollapsed == true))
end
