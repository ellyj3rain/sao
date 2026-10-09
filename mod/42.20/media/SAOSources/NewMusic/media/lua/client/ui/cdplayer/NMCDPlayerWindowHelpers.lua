require "ui/shared/host/NMDeviceUiTime"
require "ui/shared/slots/NMPortableUiSoundContract"

local env = _G.NMCDPlayerWindowEnv
setfenv(1, env)

local function clampToCircleWidth(radius, offset)
    local squared = (radius * radius) - (offset * offset)
    if squared <= 0 then
        return 0
    end
    return math.sqrt(squared)
end

local function buildHeaderRowSpans()
    local spans = {}
    for y = HEADER_ROW_TOP, HEADER_ROW_BOTTOM do
        local outerOffsetY = y - HEADER_OUTER_CENTER_Y
        local outerScaledOffset = (outerOffsetY / HEADER_OUTER_RADIUS_Y) * HEADER_OUTER_RADIUS_X
        local outerHalf = clampToCircleWidth(HEADER_OUTER_RADIUS_X, outerScaledOffset)
        local outerLeft = math.floor((HEADER_OUTER_CENTER_X - math.max(HEADER_OUTER_MIN_HALF_WIDTH, outerHalf)) + 0.5)
        local outerRight = math.floor((HEADER_OUTER_CENTER_X + math.max(HEADER_OUTER_MIN_HALF_WIDTH, outerHalf)) + 0.5)
        local row = {
            left1 = outerLeft,
            right1 = outerRight,
        }

        if y >= HEADER_INNER_TOP and y <= HEADER_INNER_LEG_BOTTOM then
            local innerOffsetY = y - HEADER_INNER_CENTER_Y
            local innerScaledOffset = (innerOffsetY / HEADER_INNER_RADIUS_Y) * HEADER_INNER_RADIUS_X
            local innerHalf = clampToCircleWidth(HEADER_INNER_RADIUS_X, innerScaledOffset)
            innerHalf = math.max(HEADER_INNER_MIN_HALF_WIDTH, innerHalf)
            local innerLeft = math.floor((HEADER_INNER_CENTER_X - innerHalf) + 0.5)
            local innerRight = math.floor((HEADER_INNER_CENTER_X + innerHalf) + 0.5)
            if innerRight > innerLeft then
                row.right1 = innerLeft
                row.left2 = innerRight
                row.right2 = outerRight
            end
        end

        spans[y] = row
    end
    return spans
end

local function hasEntries(tbl)
    if type(tbl) ~= "table" then
        return false
    end
    for _, _ in pairs(tbl) do
        return true
    end
    return false
end

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
    if type(md) ~= "table" then
        return nil
    end
    return md
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
    local sw = core and core:getScreenWidth() or 1280
    local sh = core and core:getScreenHeight() or 720
    return sw, sh
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

function targetCacheKey(target)
    if not target then
        return "none"
    end
    return table.concat({
        tostring(target.kind or ""),
        tostring(target.itemId or ""),
        tostring(target.uuid or "")
    }, "|")
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

function getLoopPolicy(state)
    return tostring(state and state.playbackPolicy or "autoplay")
end

function getNextLoopPolicy(policy)
    local current = tostring(policy or "autoplay")
    if current == "autoplay" then
        return "loop_song"
    end
    if current == "loop_song" then
        return "loop_album"
    end
    if current == "loop_album" then
        return "shuffle"
    end
    return "autoplay"
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

function playCDPlayerButtonSound(window, soundName)
    local name = tostring(soundName or "")
    if name == "" then
        return
    end
    NMPortableUiSoundContract.playNamedSound(window, name)
end

local CDPLAYER_BEEP_SOUNDS = {
    "NM_Beep_01",
    "NM_Beep_02",
    "NM_Beep_03",
    "NM_Beep_04",
    "NM_Beep_05",
    "NM_Beep_06",
}

local function pickRandomCDPlayerBeep(window)
    local count = #CDPLAYER_BEEP_SOUNDS
    if count <= 0 then
        return nil
    end

    local index = nil
    if ZombRand then
        index = ZombRand(count) + 1
    else
        index = math.random(count)
    end

    local soundName = CDPLAYER_BEEP_SOUNDS[index]
    if count > 1 and soundName == window._nmLastCDPlayerBeepSound then
        index = (index % count) + 1
        soundName = CDPLAYER_BEEP_SOUNDS[index]
    end
    window._nmLastCDPlayerBeepSound = soundName
    return soundName
end

function playCDPlayerRandomBeep(window)
    playCDPlayerButtonSound(window, pickRandomCDPlayerBeep(window))
end

function playCDPlayerTransportSound(window, isPoweringOff)
    playCDPlayerRandomBeep(window)
end

function playCDPlayerManualPlaySound(window)
    NMPortableUiSoundContract.playCDManualPlay(window)
end

function playCDPlayerVolumeClick(window)
    playCDPlayerRandomBeep(window)
end

function playCDPlayerGenericClick(window, useAlternate)
    if useAlternate == true then
        playCDPlayerButtonSound(window, "NM_ButtonClick2")
        return
    end
    playCDPlayerButtonSound(window, "NM_ButtonClick")
end

function playCDPlayerLidSound(window, isOpening)
    NMPortableUiSoundContract.playLid(window, isOpening == true)
end

function playCDPlayerMediaSlotSound(window, isInsert)
    local eventName = isInsert == true and "slot_media_insert_success" or "slot_media_eject_success"
    NMPortableUiSoundContract.playEvent(window, eventName)
end

local function setChildInteractiveVisible(child, visible, interactive)
    if not child then
        return
    end
    local isVisible = (visible == true)
    if child.setVisible then
        child:setVisible(isVisible)
    else
        child.visible = isVisible
    end
    -- Keep slot controls visually styled by the shared slot renderer instead of
    -- flipping the underlying engine disabled state while hidden. Otherwise the
    -- disabled palette can persist after the control becomes visible again.
    if isVisible then
        if child.setEnable then
            child:setEnable((interactive == nil) or (interactive == true))
        else
            child.enable = ((interactive == nil) or (interactive == true))
        end
    end
    child._nmStyleAppliedKey = nil
    child._nmStyleAppliedEnabled = nil
end

function CDPlayerWindow:updateClosedLidSlotVisibility()
    local visible = self:shouldShowClosedLidSlots() == true
    if self.mediaSlot and self.mediaSlot.button then
        setChildInteractiveVisible(self.mediaSlot.button, visible, visible)
    end

    if self.headphoneSlot and self.headphoneSlot.button then
        setChildInteractiveVisible(self.headphoneSlot.button, visible, visible)
    end

    if self.batterySlot and self.batterySlot.button then
        setChildInteractiveVisible(self.batterySlot.button, visible, visible)
    end

    if self.cdplayerBatteryMeter then
        if self.cdplayerBatteryMeter.setVisible then
            self.cdplayerBatteryMeter:setVisible(visible)
        else
            self.cdplayerBatteryMeter.visible = visible
        end
        self.cdplayerBatteryMeter.enable = false
    end

    if self._nmSlotsVisible == visible then
        return
    end
    self._nmSlotsVisible = visible

    if visible ~= true then
        if self.mediaSlot and self.mediaSlot.cancelDrag then
            self.mediaSlot.cancelDrag()
        end
        if self.headphoneSlot and self.headphoneSlot.cancelDrag then
            self.headphoneSlot.cancelDrag()
        end
        if self.batterySlot and self.batterySlot.cancelDrag then
            self.batterySlot.cancelDrag()
        end
    end
end

function CDPlayerWindow:refreshSlotVisibility()
    self:updateClosedLidSlotVisibility()
end

function attachCDPlayerSlots(window)
    if not window or window._nmSlotsAttached == true then
        return
    end

    local mediaRect = window:getMediaSlotRect()
    local headphoneRect = window:getHeadphoneSlotRect()
    local batteryRect = window:getBatterySlotRect()

    window.mediaSlot = NMMediaSlot and NMMediaSlot.attach and NMMediaSlot.attach(window, mediaRect.x, mediaRect.y, SLOT_SIZE) or nil
    window.headphoneSlot = NMHeadphoneSlot and NMHeadphoneSlot.attach and NMHeadphoneSlot.attach(window, headphoneRect.x, headphoneRect.y, SLOT_SIZE) or nil
    window.batterySlot = NMBatterySlot and NMBatterySlot.attach and NMBatterySlot.attach(window, batteryRect.x, batteryRect.y, SLOT_SIZE) or nil

    if window.batterySlot and window.batterySlot.bar then
        window.batterySlot.bar:setVisible(false)
        window.batterySlot.bar.enable = false
    end

    local meterRect = window:getBatteryMeterRect()
    local meterPanel = ISPanel:new(meterRect.x, meterRect.y, meterRect.w, meterRect.h)
    meterPanel:initialise()
    meterPanel:instantiate()
    meterPanel.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    meterPanel.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    meterPanel.render = function(selfPanel)
        if window:shouldShowClosedLidSlots() ~= true then
            return
        end
        local renderState = window and window.getSlotRenderState and window:getSlotRenderState("battery") or nil
        local fullType = renderState and renderState.fullType or ""
        if fullType == "" then
            return
        end
        local w = tonumber(selfPanel.width) or 0
        local h = tonumber(selfPanel.height) or 0
        selfPanel:drawRect(0, 0, w, h, BATTERY_METER_BG.a, BATTERY_METER_BG.r, BATTERY_METER_BG.g, BATTERY_METER_BG.b)
        local pct = clamp01(renderState and renderState.batteryPct or 0.0)
        if pct <= 0.0001 then
            selfPanel:drawRect(0, 0, w, h, BATTERY_METER_EMPTY.a, BATTERY_METER_EMPTY.r, BATTERY_METER_EMPTY.g, BATTERY_METER_EMPTY.b)
            return
        end
        local fillW = math.floor((w * pct) + 0.5)
        if fillW > 0 then
            selfPanel:drawRect(0, 0, fillW, h, BATTERY_METER_FILL.a, BATTERY_METER_FILL.r, BATTERY_METER_FILL.g, BATTERY_METER_FILL.b)
        end
    end
    window:addChild(meterPanel)
    window.cdplayerBatteryMeter = meterPanel
    window._nmSlotsAttached = true
    window:updateClosedLidSlotVisibility()
end

if not hasEntries(HEADER_ROW_SPANS) then
    HEADER_ROW_SPANS = buildHeaderRowSpans()
    HEADER_ROW_SPANS._nmVersion = HEADER_SPAN_VERSION
elseif tostring(HEADER_ROW_SPANS._nmVersion or "") ~= tostring(HEADER_SPAN_VERSION or "") then
    HEADER_ROW_SPANS = buildHeaderRowSpans()
    HEADER_ROW_SPANS._nmVersion = HEADER_SPAN_VERSION
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

local function reflowCDPlayerChildren(window)
    if not window then
        return
    end
    local mediaRect = window:getMediaSlotRect()
    local headphoneRect = window:getHeadphoneSlotRect()
    local batteryRect = window:getBatterySlotRect()
    local meterRect = window:getBatteryMeterRect()
    local viewportRect = window:getDisplayViewportRect()

    updateChildRect(window.mediaSlot and window.mediaSlot.button or nil, mediaRect.x, mediaRect.y, SLOT_SIZE, SLOT_SIZE)
    updateChildRect(window.headphoneSlot and window.headphoneSlot.button or nil, headphoneRect.x, headphoneRect.y, SLOT_SIZE, SLOT_SIZE)
    updateChildRect(window.batterySlot and window.batterySlot.button or nil, batteryRect.x, batteryRect.y, SLOT_SIZE, SLOT_SIZE)
    updateChildRect(window.cdplayerBatteryMeter, meterRect.x, meterRect.y, meterRect.w, meterRect.h)
    updateChildRect(window.displaySongLabelPanel, viewportRect.x, viewportRect.y, viewportRect.w, viewportRect.h)
    updateChildRect(window.displayClockPanel, viewportRect.x, viewportRect.y, viewportRect.w, viewportRect.h)
end

function CDPlayerWindow:applyCurrentScaleLayout()
    refreshCDPlayerLayoutMetrics()
    HEADER_ROW_SPANS = buildHeaderRowSpans()
    HEADER_ROW_SPANS._nmVersion = HEADER_SPAN_VERSION

    local currentScale = getFancyDeviceUiScale()
    if math.abs((tonumber(self._nmAppliedFancyScale) or 0.0) - currentScale) < 0.0001 and self.width == PANEL_W and self.height == PANEL_H then
        return
    end

    self._nmAppliedFancyScale = currentScale
    if self.setWidth then self:setWidth(PANEL_W) else self.width = PANEL_W end
    if self.setHeight then self:setHeight(PANEL_H) else self.height = PANEL_H end
    self.width = PANEL_W
    self.height = PANEL_H
    self.lidCurrentY = self.isLidOpen == true and LID_OPEN_Y or LID_CLOSED_Y
    self.lidCurrentH = self.isLidOpen == true and LID_OPEN_H or LID_CLOSED_H

    reflowCDPlayerChildren(self)

    local clampedX = self:clampWindowX(self:getX())
    self:setX(clampedX)
    self._nmExpandedY = self:clampWindowY(self._nmExpandedY or self:getExpandedY())
    self:setY(self:getStateY(self.isCollapsed == true))
    self:updateClosedLidSlotVisibility()
end
