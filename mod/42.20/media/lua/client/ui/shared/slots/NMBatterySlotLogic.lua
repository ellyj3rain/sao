-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
local env = _G.NMBatterySlotEnv
setfenv(1, env)

require "ui/shared/slots/NMDeviceUiSlotContract"
require "ui/shared/slots/NMSlotPlaceholderRender"

local AUTHORITATIVE_EJECT_TIMEOUT_MS = 1000

local function resolveWindowContext(window)
    if not window then
        return nil
    end
    if window.resolveContextCached then
        return window:resolveContextCached()
    end
    return window.resolveContext and window:resolveContext() or nil
end

local function resolveDraggedItems(window, frame)
    if frame and frame.dragOk == true and type(frame.dragItems) == "table" then
        return frame.dragItems, true
    end
    if NMSlotHostLifecycle and NMSlotHostLifecycle.resolveDraggedItemsSnapshot then
        return NMSlotHostLifecycle.resolveDraggedItemsSnapshot(window)
    end
    return getDraggedInventoryItems()
end

local function markAwaitingAuthoritativeBatteryEject(window, fullType)
    if NMSlotHostLifecycle and NMSlotHostLifecycle.markAwaitingAuthoritativeSlotEject then
        NMSlotHostLifecycle.markAwaitingAuthoritativeSlotEject(window, "battery", fullType)
    end
end

local function clearAwaitingAuthoritativeBatteryEject(window)
    if NMSlotHostLifecycle and NMSlotHostLifecycle.clearAwaitingAuthoritativeSlotEject then
        NMSlotHostLifecycle.clearAwaitingAuthoritativeSlotEject(window, "battery")
    end
end

local function getAwaitingAuthoritativeBatteryEject(window)
    if NMSlotHostLifecycle and NMSlotHostLifecycle.getAwaitingAuthoritativeSlotEject then
        return NMSlotHostLifecycle.getAwaitingAuthoritativeSlotEject(window, "battery")
    end
    return nil
end

local function isAwaitingAuthoritativeBatteryEject(window, fullType)
    if NMSlotHostLifecycle and NMSlotHostLifecycle.isAwaitingAuthoritativeSlotEject then
        return NMSlotHostLifecycle.isAwaitingAuthoritativeSlotEject(window, "battery", fullType)
    end
    return false
end

function isDuplicateBatteryEjectBlocked(window, fullType)
    local ejectFullType = tostring(fullType or "")
    if ejectFullType == "" then
        return false
    end
    if isAwaitingAuthoritativeBatteryEject(window, ejectFullType) then
        return true
    end
    if window and window._nmSlotRemoveInFlightByType and window._nmSlotRemoveInFlightByType.battery then
        return true
    end
    if window and tostring(window._nmPendingBatterySlotFullType or "") == ejectFullType then
        return true
    end
    return false
end

function queueBatterySlotAction(window, actionName, args)
    if not window then return false end
    if window._nmSlotRangeGateEnabled ~= false and not canQueueSlotAction(window) then
        return false
    end
    local payload = args or {}
    if payload.slotTraceId == nil then
        payload.slotTraceId = nextSlotTraceId()
    end
    local pendingEjectFullType = tostring(window._nmPendingBatterySlotFullType or "")
    local resolved = resolveWindowContext(window)
    local playerObj = resolved and resolved.player or nil
    if not (playerObj and ISTimedActionQueue and NMBatterySlotTimedAction) then
        local ok = window:dispatchSlotAction(actionName, payload)
        if ok == true and actionName == "eject_battery" and pendingEjectFullType ~= "" then
            markAwaitingAuthoritativeBatteryEject(window, pendingEjectFullType)
        end
        if ok ~= true and actionName == "eject_battery" then
            clearAwaitingAuthoritativeBatteryEject(window)
        end
        return ok
    end
    ISTimedActionQueue.add(NMBatterySlotTimedAction:new(playerObj, window, actionName, payload))
    return true
end

function isBatteryInsertPending(window, state)
    if not window then
        return false
    end
    local timed = window._nmBatterySlotTimedProgress or nil
    if timed and timed.active == true and tostring(timed.action or "") == "insert_battery" then
        return true
    end
    if tostring(window._nmPendingBatterySlotFullType or "") ~= BATTERY_FULL_TYPE then
        return false
    end
    return not (state and state.batteryPresent == true)
end

function getContextMenuPoint(button, x, y)
    local bx = button and button.getAbsoluteX and button:getAbsoluteX() or (getMouseX and getMouseX() or 0)
    local by = button and button.getAbsoluteY and button:getAbsoluteY() or (getMouseY and getMouseY() or 0)
    return bx + (tonumber(x) or 0), by + (tonumber(y) or 0)
end

function isCompatibleBatteryDrag(items)
    if type(items) ~= "table" or #items <= 0 then return false end
    for i = 1, #items do
        local item = items[i]
        local ft = item and item.getFullType and tostring(item:getFullType() or "") or ""
        if ft == BATTERY_FULL_TYPE then return true end
    end
    return false
end

function pickFirstBattery(items)
    if type(items) ~= "table" then return nil end
    for i = 1, #items do
        local item = items[i]
        local ft = item and item.getFullType and tostring(item:getFullType() or "") or ""
        if ft == BATTERY_FULL_TYPE then return item end
    end
    return nil
end

function normalizeBatteryIngressItem(window, item)
    local resolved = resolveWindowContext(window)
    local player = resolved and resolved.player or nil
    local itemId = item and NMCore and NMCore.itemId and NMCore.itemId(item) or nil
    local uuid = item and NMInventoryHelpers and NMInventoryHelpers.getItemStateUuid and NMInventoryHelpers.getItemStateUuid(item) or nil
    if not (player and itemId and NMInventoryHelpers and NMInventoryHelpers.normalizeItemToMainInventory) then
        return nil, "normalize_helper_missing"
    end
    return NMInventoryHelpers.normalizeItemToMainInventory(player, itemId, uuid)
end

function isMouseOverButton(button)
    if not button then return false end
    local mx = getMouseX and getMouseX() or 0
    local my = getMouseY and getMouseY() or 0
    local ax = button.getAbsoluteX and button:getAbsoluteX() or 0
    local ay = button.getAbsoluteY and button:getAbsoluteY() or 0
    local bw = tonumber(button.width) or 0
    local bh = tonumber(button.height) or 0
    if bw <= 0 or bh <= 0 then return false end
    return mx >= ax and mx < (ax + bw) and my >= ay and my < (ay + bh)
end

function readBatteryChargeFraction(item)
    if not item then return 1.0 end
    return NMCore.clamp(tonumber(NMCore.readDrainableFraction and NMCore.readDrainableFraction(item, 1.0) or 1.0) or 1.0, 0.0, 1.0)
end

function batteryChargePercentText(chargeFraction)
    local pct = math.floor((NMCore.clamp(tonumber(chargeFraction) or 0.0, 0.0, 1.0) * 100) + 0.5)
    if pct < 0 then pct = 0 end
    if pct > 100 then pct = 100 end

    local label = (type(getItemNameFromFullType) == "function" and getItemNameFromFullType(BATTERY_FULL_TYPE)) or "Battery"
    return tostring(label) .. ": " .. tostring(pct) .. "%"
end

function collectEligibleBatteryItems(player)
    local inv = player and player.getInventory and player:getInventory() or nil
    if not inv then return {} end
    local all = {}
    NMInventoryHelpers.collectItemsRecursive(inv, all)
    local out = {}
    for i = 1, #all do
        local item = all[i]
        local ft = item and item.getFullType and tostring(item:getFullType() or "") or ""
        if ft == BATTERY_FULL_TYPE then
            out[#out + 1] = item
        end
    end
    table.sort(out, function(a, b)
        return readBatteryChargeFraction(a) > readBatteryChargeFraction(b)
    end)
    return out
end

function slotMenuItemLabel(item)
    return batteryChargePercentText(readBatteryChargeFraction(item))
end

function openEmptySlotContextMenu(window, button, x, y)
    if not ISContextMenu then return false end
    local resolved = resolveWindowContext(window)
    local player = resolved and resolved.player or nil
    local playerNum = player and player.getPlayerNum and tonumber(player:getPlayerNum()) or 0
    local cx, cy = getContextMenuPoint(button, x, y)
    local context = ISContextMenu.get(playerNum or 0, cx, cy)
    if not context then return false end

    local actionOption = context:addOption(NMTranslations.ui("InsertBattery", "Insert Battery"), nil, nil)
    if NMUIRenderProbe and NMUIRenderProbe.count then
        NMUIRenderProbe.count(window, "slot.candidate_scan", 1)
    end
    local items = collectEligibleBatteryItems(player)
    if #items <= 0 then
        actionOption.notAvailable = true
        return true
    end

    local sub = context:getNew(context)
    context:addSubMenu(actionOption, sub)
    for i = 1, #items do
        local item = items[i]
        local option = sub:addOption(slotMenuItemLabel(item), window, function(targetWin, targetItem)
            local liveItem = normalizeBatteryIngressItem(targetWin, targetItem)
            if not liveItem then
                targetWin._nmPendingBatterySlotFullType = nil
                return
            end
            targetWin._nmPendingBatterySlotFullType = BATTERY_FULL_TYPE
            if queueBatterySlotAction(targetWin, "insert_battery", { batteryItemId = NMCore.itemId(liveItem) }) ~= true then
                targetWin._nmPendingBatterySlotFullType = nil
            end
        end, item)
        option.itemForTexture = item
    end
    return true
end

function drawEmptyBatteryTexture(button)
    local scaleKey = NMFancyDeviceUiScale and NMFancyDeviceUiScale.getTextureScaleKey and NMFancyDeviceUiScale.getTextureScaleKey() or "1x"
    if EMPTY_BATTERY_PLACEHOLDER_TEXTURE_SCALE_KEY ~= scaleKey then
        EMPTY_BATTERY_PLACEHOLDER_TEXTURE = NMFancyDeviceUiScale and NMFancyDeviceUiScale.getTexture
            and NMFancyDeviceUiScale.getTexture("media/textures/UI/UI_NM_SlotEmpty_Battery.png")
            or getTexture and (getTexture("media/textures/UI/UI_NM_SlotEmpty_Battery.png") or getTexture("UI/UI_NM_SlotEmpty_Battery") or getTexture("UI_NM_SlotEmpty_Battery"))
            or nil
        EMPTY_BATTERY_PLACEHOLDER_TEXTURE_SCALE_KEY = scaleKey
    end
    local tex = EMPTY_BATTERY_PLACEHOLDER_TEXTURE
    return NMSlotPlaceholderRender and NMSlotPlaceholderRender.drawTexture and NMSlotPlaceholderRender.drawTexture(button, tex) or false
end

function drawBatteryTexture(button)
    if not BATTERY_TEXTURE then
        BATTERY_TEXTURE = getTexture and (getTexture("Item_Battery") or getTexture("media/textures/Item_Battery.png")) or nil
    end
    local tex = BATTERY_TEXTURE
    if not tex then return end
    local w = tonumber(button.width) or 0
    local h = tonumber(button.height) or 0
    local size = math.max(10, math.min(w, h) - 6)
    local left = math.floor((w - size) * 0.5 + 0.5)
    local top = math.floor((h - size) * 0.5 + 0.5)
    button:drawTextureScaledAspect(tex, left, top, size, size, 1.0, 1.0, 1.0, 1.0)
end

function resolveBatterySlotFullType(window, state)
    local authoritative = (state and state.batteryPresent == true) and BATTERY_FULL_TYPE or ""
    local awaiting = getAwaitingAuthoritativeBatteryEject(window)
    if awaiting then
        local awaitingFullType = tostring(awaiting.fullType or "")
        local awaitingStartedAtMs = tonumber(awaiting.startedAtMs) or 0
        local nowMs = (window and tonumber(window._nmFrameNowMs)) or 0
        if authoritative == "" or (awaitingFullType ~= "" and authoritative ~= awaitingFullType) then
            clearAwaitingAuthoritativeBatteryEject(window)
            awaiting = nil
        elseif awaitingStartedAtMs > 0 and nowMs > 0 and (nowMs - awaitingStartedAtMs) >= AUTHORITATIVE_EJECT_TIMEOUT_MS then
            clearAwaitingAuthoritativeBatteryEject(window)
            if window and window._nmSlotRemoveInFlightByType then
                window._nmSlotRemoveInFlightByType.battery = nil
            end
            if tostring(window and window._nmPendingBatterySlotFullType or "") == awaitingFullType then
                window._nmPendingBatterySlotFullType = nil
            end
            awaiting = nil
        else
            return ""
        end
    end
    local pending = window and window._nmPendingBatterySlotFullType or nil
    local timed = window and window._nmBatterySlotTimedProgress or nil
    local timedActive = timed and timed.active == true
    local timedAction = timedActive and tostring(timed.action or "") or ""
    if timedActive and timedAction == "eject_battery" and tostring(pending or "") ~= "" then
        return tostring(pending or "")
    end
    if timedActive ~= true and pending ~= nil and tostring(pending or "") == authoritative then
        local removeInFlight = window and window._nmSlotRemoveInFlightByType and window._nmSlotRemoveInFlightByType.battery == true
        if removeInFlight ~= true then
            window._nmPendingBatterySlotFullType = nil
            if window._nmSlotRemoveInFlightByType then
                window._nmSlotRemoveInFlightByType.battery = nil
            end
        end
    end
    return authoritative
end

function resolveSlotStyle(window, button, resolved)
    local state = resolved and resolved.state or nil
    local fullType = resolveBatterySlotFullType(window, state)
    local mouseOver = isMouseOverButton(button)
    local timed = window and window._nmBatterySlotTimedProgress or nil
    if fullType == "" and timed == nil and not mouseOver then
        return "slot"
    end
    if mouseOver then
        if NMUIRenderProbe and NMUIRenderProbe.count then
            NMUIRenderProbe.count(window, "slot.drag_check", 1)
        end
        local items, ok = resolveDraggedItems(window)
        if ok and type(items) == "table" and #items > 0 and isCompatibleBatteryDrag(items) then
            return "slot_drag"
        end
    end
    if fullType ~= "" then
        return "slot_filled"
    end
    if mouseOver then
        return "slot_hover"
    end
    return "slot"
end

function resolveBatteryTint(fullType)
    return { r = 1.0, g = 1.0, b = 1.0 }
end

function NMBatterySlot.buildContentState(window, frame)
    local resolved = frame and frame.resolved or resolveWindowContext(window)
    local state = resolved and resolved.state or nil
    local fullType = resolveBatterySlotFullType(window, state)
    local timed = window and window._nmBatterySlotTimedProgress or nil
    local fillPct = nil
    if timed and timed.active == true and timed.delta then
        fillPct = NMCore.clamp(tonumber(timed.delta) or 0.0, 0.0, 1.0)
    end
    local tooltip = NMTranslations.ui("InsertBattery", "Insert Battery")
    local batteryPct = NMCore.clamp(tonumber(state and state.batteryCharge or 0.0) or 0.0, 0.0, 1.0)
    if fullType ~= "" then
        tooltip = batteryChargePercentText(batteryPct)
    end
    return NMDeviceUiSlotContract.buildContentState("battery", {
        fullType = fullType,
        fillPct = fillPct,
        tooltip = tooltip,
        acceptedFullTypes = { [BATTERY_FULL_TYPE] = true },
        insertAction = "insert_battery",
        ejectAction = "eject_battery",
        batteryPct = batteryPct,
    })
end

function NMBatterySlot.buildInteractionState(window, frame, contentState)
    local button = window and window.batterySlot and window.batterySlot.button or nil
    local mouseOver = isMouseOverButton(button)
    local styleKey = tostring(contentState and contentState.styleKey or "slot")
    local canAcceptDrag = tostring(contentState and contentState.fullType or "") == "" and mouseOver
        and frame and frame.dragOk and type(frame.dragItems) == "table" and #frame.dragItems > 0
        and isCompatibleBatteryDrag(frame.dragItems) or false
    if canAcceptDrag then
        styleKey = "slot_drag"
    elseif mouseOver and tostring(contentState and contentState.fullType or "") == "" then
        styleKey = "slot_hover"
    end
    return NMDeviceUiSlotContract.buildInteractionState("battery", {
        styleKey = styleKey,
        mouseOver = mouseOver == true,
        dragActive = canAcceptDrag,
        canAcceptDrag = canAcceptDrag,
    })
end

function NMBatterySlot.buildRenderState(window, frame)
    local contentState = NMBatterySlot.buildContentState(window, frame)
    local interactionState = NMBatterySlot.buildInteractionState(window, frame, contentState)
    local out = {}
    for key, value in pairs(contentState or {}) do
        out[key] = value
    end
    for key, value in pairs(interactionState or {}) do
        out[key] = value
    end
    return out
end

