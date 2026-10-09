
local env = _G.NMDeviceWindowEnv
setfenv(1, env)

local UiLifecycleItemWindows = require "ui/shared/host/NMUiLifecycleItemWindows"

local function getButtonScreenRect(button)
    if not button then
        return nil
    end
    local x = button.getAbsoluteX and button:getAbsoluteX() or nil
    local y = button.getAbsoluteY and button:getAbsoluteY() or nil
    local w = tonumber(button.width) or 0
    local h = tonumber(button.height) or 0
    if x == nil or y == nil or w <= 0 or h <= 0 then
        return nil
    end
    return { x = x, y = y, w = w, h = h }
end

local function isWindowVisible(window)
    if not (window and window.javaObject) then
        return false
    end
    if window.getIsVisible then
        return window:getIsVisible() == true
    end
    if window.isVisible then
        return window:isVisible() == true
    end
    return true
end

local function getMediaSlotEnv()
    return rawget(_G, "NMMediaSlotEnv") or nil
end

local function supportsSharedMediaSlotTarget(target)
    if not target then
        return false
    end
    local kind = tostring(target.kind or "")
    return kind == "item" or kind == "vehicle"
end

local function resolveVehicleDisplayName(vehicle)
    if not vehicle then
        return NMTranslations.ui("Vehicle", "Vehicle")
    end
    if ISVehicleMenu and ISVehicleMenu.getVehicleDisplayName then
        local ok, displayName = pcall(ISVehicleMenu.getVehicleDisplayName, vehicle)
        if ok and tostring(displayName or "") ~= "" then
            return tostring(displayName)
        end
    end
    local script = vehicle.getScript and vehicle:getScript() or nil
    local carName = script and script.getCarModelName and tostring(script:getCarModelName() or "") or ""
    if carName == "" then
        carName = script and script.getName and tostring(script:getName() or "") or ""
    end
    if carName ~= "" and getTextOrNull then
        local translated = getTextOrNull("IGUI_VehicleName" .. carName)
        if translated and translated ~= "" then
            return translated
        end
    end
    if carName ~= "" then
        return carName
    end
    return NMTranslations.ui("Vehicle", "Vehicle")
end

local function collectPlayerWindows(playerNum)
    return WindowRegistry and WindowRegistry.collectWindows and WindowRegistry.collectWindows(env, playerNum) or {}
end

local function collectLiveWindows(playerNum)
    env.liveWindows = env.liveWindows or {}
    local out = {}
    local resolvedPlayerNum = tonumber(playerNum)
    for i = #env.liveWindows, 1, -1 do
        local win = env.liveWindows[i]
        if not (win and win.javaObject) then
            table.remove(env.liveWindows, i)
        elseif resolvedPlayerNum == nil or tonumber(win.playerNum) == resolvedPlayerNum then
            out[#out + 1] = win
        end
    end
    return out
end

local function registerLiveWindow(window)
    if not window then
        return
    end
    env.liveWindows = env.liveWindows or {}
    for i = 1, #env.liveWindows do
        if env.liveWindows[i] == window then
            return
        end
    end
    env.liveWindows[#env.liveWindows + 1] = window
end

local function unregisterLiveWindow(window)
    local windows = env.liveWindows or nil
    if type(windows) ~= "table" then
        return
    end
    for i = #windows, 1, -1 do
        if windows[i] == window or not (windows[i] and windows[i].javaObject) then
            table.remove(windows, i)
        end
    end
end

local function registerWindow(window)
    if WindowRegistry and WindowRegistry.registerWindow then
        WindowRegistry.registerWindow(env, window)
    end
end

local function resetWindowVisualState(window, reason)
    if not window then
        return false
    end
    local reset = NMTransportButtonRow and NMTransportButtonRow.resetVisualState and NMTransportButtonRow.resetVisualState(window) == true or false
    if reset and NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("ui_lifecycle") then
        NMCore.logChannel(
            "ui_lifecycle",
            "generic_window_transport_reset",
            string.format(
                "window=%s player=%s targetKey=%s reason=%s",
                tostring(window),
                tostring(window.playerNum or 0),
                tostring(WindowRegistry and WindowRegistry.targetKey and WindowRegistry.targetKey(window.target) or ""),
                tostring(reason or "")
            )
        )
    end
    return reset
end

local function logOpenTrace(tag, detail)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("ui_lifecycle")) then
        return
    end
    NMCore.logChannel("ui_lifecycle", tostring(tag or "generic_open"), tostring(detail or ""))
end

-- Safety net for pre-registry or stale-key windows during UI/session transitions.
-- Safety net for pre-registry or stale-key vehicle windows during UI/session transitions.
local function findFallbackOpenVehicleWindow(playerNum, vehicleId, partId)
    local wins = collectLiveWindows(playerNum)
    for i = 1, #wins do
        local candidate = wins[i]
        local target = candidate and candidate.target or nil
        if target
            and target.kind == "vehicle"
            and tostring(target.vehicleId or "") == vehicleId
            and tostring(target.partId or "") == partId then
            return candidate
        end
    end
    return nil
end

local function findDuplicateTargetWindows(playerNum, target, keepWindow)
    local wins = collectLiveWindows(playerNum)
    local out = {}
    local targetKey = WindowRegistry and WindowRegistry.targetKey and WindowRegistry.targetKey(target) or ""
    for i = 1, #wins do
        local win = wins[i]
        if win ~= keepWindow then
            local winKey = WindowRegistry and WindowRegistry.targetKey and WindowRegistry.targetKey(win.target) or ""
            if targetKey ~= "" and winKey == targetKey then
                out[#out + 1] = win
            end
        end
    end
    return out, targetKey
end

local function closeDuplicateTargetWindows(playerNum, target, keepWindow, reason)
    local duplicates, targetKey = findDuplicateTargetWindows(playerNum, target, keepWindow)
    local closed = 0
    for i = 1, #duplicates do
        local duplicate = duplicates[i]
        if duplicate and duplicate.close then
            duplicate:close()
            closed = closed + 1
        elseif duplicate and duplicate.removeFromUIManager then
            duplicate:removeFromUIManager()
            unregisterLiveWindow(duplicate)
            closed = closed + 1
        end
    end
    if closed > 0 then
        logOpenTrace(
            "generic_open_dedupe",
            string.format(
                "player=%s targetKey=%s keptWindow=%s closed=%s reason=%s",
                tostring(playerNum or 0),
                tostring(targetKey or ""),
                tostring(keepWindow),
                tostring(closed),
                tostring(reason or "")
            )
        )
    end
    return closed > 0
end

function DeviceWindow:new(x, y, width, height)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o.title = NMTranslations.uiStringFormat("WindowTitleFmt", "New Music - %s", NMTranslations.ui("Device", "Device"))
    o.pin = true
    o.resizable = true
    o.minimumWidth = 450
    o.minimumHeight = 560
    o.maximumWidth = 900
    o.maximumHeight = 700
    o.playerNum = 0
    o.target = nil
    o._nmFrameEpoch = 0
    o._nmFrameReason = "init"
    o._nmFrameResolveCount = 0
    o._nmFrameFallbackCount = 0
    o._nmContextCache = nil
    o._nmContextCacheEpoch = nil
    o._nmContextCacheTargetKey = nil
    o._nmPendingMediaSlotFullType = nil
    o._nmSlotRemoveInFlightByType = {}
    o._nmAwaitingAuthoritativeMediaEject = nil
    o._nmAwaitingAuthoritativeMediaInsert = nil
    o._nmSlotFrameModel = nil
    o._nmSlotFrameModelEpoch = nil
    o._nmRenderModel = nil
    o._nmRenderModelEpoch = nil
    o._nmLastDistanceCheckMs = 0
    o._nmLastHeadphoneWearSyncMs = 0
    o._nmHeadphoneWearSyncActive = false
    o._nmUiPerfKind = "generic"
    if NMDeviceUiHost and NMDeviceUiHost.initWindow then
        NMDeviceUiHost.initWindow(o, "generic")
    end
    return o
end

function getOrCreateWindow(playerNum)
    local w, h = 450, 560
    local core = getCore and getCore() or nil
    local sw = core and core:getScreenWidth() or 1280
    local sh = core and core:getScreenHeight() or 720
    local x = math.floor((sw - w) / 2)
    local y = math.floor((sh - h) / 2)
    local win = DeviceWindow:new(x, y, w, h)
    win.playerNum = tonumber(playerNum) or 0
    win:initialise()
    win:addToUIManager()
    registerLiveWindow(win)
    return win
end

function NMDeviceWindow.openForItemResolved(playerNum, item, resolvedContext)
    local player = getPlayer(playerNum)
    if not (player and item) then return nil end
    local resolved = type(resolvedContext) == "table" and resolvedContext or UiLifecycleItemWindows.resolveItemLifecycleContext(item)
    local profile = resolved and resolved.profile or NMDeviceProfiles.getForItem(item)
    if not profile or profile.isMediaContainerOnly == true then return nil end
    local state = resolved and resolved.state or NMDeviceState.ensure(item, profile)
    if not state then return nil end
    local identity = resolved and resolved.itemId and resolved or UiLifecycleItemWindows.resolveItemWindowIdentity(item)
    local itemUuid = tostring(identity.itemUuid or state.deviceUUID or "")
    local itemId = tostring(identity.itemId or NMCore.itemId(item) or "")
    local targetKey = tostring(identity.targetKey or "")
    local win, lookup = UiLifecycleItemWindows.findOpenItemWindowByIdentity(env, playerNum, identity)
    logOpenTrace(
        "generic_open_lookup",
        string.format(
            "player=%s targetKind=item targetKey=%s registryHit=%s itemId=%s uuid=%s",
            tostring(playerNum or 0),
            tostring(targetKey or ""),
            tostring(lookup and lookup.registryHit == true),
            tostring(itemId or ""),
            tostring(itemUuid or "")
        )
    )
    if lookup and lookup.registryHit ~= true then
        logOpenTrace(
            "generic_open_fallback",
            string.format(
                "player=%s targetKind=item targetKey=%s fallbackHit=%s itemId=%s uuid=%s",
                tostring(playerNum or 0),
                tostring(targetKey or ""),
                tostring(lookup and lookup.fallbackHit == true),
                tostring(itemId or ""),
                tostring(itemUuid or "")
            )
        )
    end
    local reusedExisting = win ~= nil
    if not win then
        win = getOrCreateWindow(playerNum)
    end
    win.target = {
        kind = "item",
        itemId = identity.itemId ~= "" and identity.itemId or NMCore.itemId(item),
        uuid = itemUuid,
        itemRef = item
    }
    registerLiveWindow(win)
    closeDuplicateTargetWindows(playerNum, win.target, win, reusedExisting and "reuse_item_window" or "open_item_window")
    resetWindowVisualState(win, reusedExisting and "reuse_item_window" or "open_item_window")
    win:invalidateContextCache()
    NMSlotHostLifecycle.refreshSlotVisibility(win)
    win.title = NMTranslations.uiStringFormat("WindowTitleFmt", "New Music - %s", tostring(resolveWindowDeviceTitle(profile) or ""))
    win:setVisible(true)
    win:bringToTop()
    if NMGamepadWindowTracker and NMGamepadWindowTracker.markWindow then
        NMGamepadWindowTracker.markWindow(win, "generic")
    end
    if NMPortableMediaDropArbiter and NMPortableMediaDropArbiter.markWindowInteraction then
        NMPortableMediaDropArbiter.markWindowInteraction(win, "generic")
    end
    registerWindow(win)
    logOpenTrace(
        "generic_open_result",
        string.format(
            "player=%s targetKind=item reused=%s targetKey=%s window=%s targetItemId=%s targetUuid=%s",
            tostring(playerNum or 0),
            tostring(reusedExisting),
            tostring(targetKey or ""),
            tostring(win),
            tostring(win.target and win.target.itemId or ""),
            tostring(win.target and win.target.uuid or "")
        )
    )
    return win
end

function NMDeviceWindow.openForItem(playerNum, item)
    return NMDeviceWindow.openForItemResolved(playerNum, item, nil)
end

function NMDeviceWindow.openForVehicle(playerNum, vehicle, part)
    local player = getPlayer(playerNum)
    if not (player and vehicle and part) then return nil end
    local profile = NMDeviceProfiles.getVehicleProfile(part)
    if not profile then return nil end
    local state = NMDeviceState.ensure(part, profile)
    if not state then return nil end
    local targetKey = WindowRegistry and WindowRegistry.vehicleTargetKey
        and WindowRegistry.vehicleTargetKey(
            tostring(vehicle.getId and vehicle:getId() or ""),
            tostring(part.getId and part:getId() or "Radio")
        )
        or ""
    local win = targetKey ~= "" and WindowRegistry and WindowRegistry.findWindow and WindowRegistry.findWindow(env, playerNum, targetKey) or nil
    logOpenTrace(
        "generic_open_lookup",
        string.format(
            "player=%s targetKind=vehicle targetKey=%s registryHit=%s vehicleId=%s partId=%s",
            tostring(playerNum or 0),
            tostring(targetKey or ""),
            tostring(win ~= nil),
            tostring(vehicle.getId and vehicle:getId() or ""),
            tostring(part.getId and part:getId() or "Radio")
        )
    )
    if not win then
        local vehicleId = tostring(vehicle.getId and vehicle:getId() or "")
        local partId = tostring(part.getId and part:getId() or "Radio")
        win = findFallbackOpenVehicleWindow(playerNum, vehicleId, partId)
        logOpenTrace(
            "generic_open_fallback",
            string.format(
                "player=%s targetKind=vehicle targetKey=%s fallbackHit=%s vehicleId=%s partId=%s",
                tostring(playerNum or 0),
                tostring(targetKey or ""),
                tostring(win ~= nil),
                tostring(vehicleId or ""),
                tostring(partId or "")
            )
        )
    end
    local reusedExisting = win ~= nil
    if not win then
        win = getOrCreateWindow(playerNum)
    end
    win.target = {
        kind = "vehicle",
        vehicleId = tostring(vehicle.getId and vehicle:getId() or ""),
        partId = tostring(part.getId and part:getId() or "Radio"),
        vehicleRef = vehicle,
        partRef = part
    }
    registerLiveWindow(win)
    closeDuplicateTargetWindows(playerNum, win.target, win, reusedExisting and "reuse_vehicle_window" or "open_vehicle_window")
    resetWindowVisualState(win, reusedExisting and "reuse_vehicle_window" or "open_vehicle_window")
    win:invalidateContextCache()
    NMSlotHostLifecycle.refreshSlotVisibility(win)
    win.title = NMTranslations.uiStringFormat("WindowTitleFmt", "New Music - %s", resolveVehicleDisplayName(vehicle))
    win:setVisible(true)
    win:bringToTop()
    if NMGamepadWindowTracker and NMGamepadWindowTracker.markWindow then
        NMGamepadWindowTracker.markWindow(win, "generic")
    end
    if NMPortableMediaDropArbiter and NMPortableMediaDropArbiter.markWindowInteraction then
        NMPortableMediaDropArbiter.markWindowInteraction(win, "generic")
    end
    registerWindow(win)
    logOpenTrace(
        "generic_open_result",
        string.format(
            "player=%s targetKind=vehicle reused=%s targetKey=%s window=%s vehicleId=%s partId=%s",
            tostring(playerNum or 0),
            tostring(reusedExisting),
            tostring(targetKey or ""),
            tostring(win),
            tostring(win.target and win.target.vehicleId or ""),
            tostring(win.target and win.target.partId or "")
        )
    )
    return win
end

function NMDeviceWindow.findOpenForItemResolved(playerNum, item, resolvedContext)
    if not item then
        return nil
    end
    local identity = type(resolvedContext) == "table" and resolvedContext or UiLifecycleItemWindows.resolveItemWindowIdentity(item)
    local exact = UiLifecycleItemWindows.findOpenItemWindowByIdentity(env, playerNum, identity)
    return exact
end

function NMDeviceWindow.findOpenForItem(playerNum, item)
    return NMDeviceWindow.findOpenForItemResolved(playerNum, item, nil)
end

function NMDeviceWindow.findOpenForVehicle(playerNum, vehicle, part)
    if not (vehicle and part) then
        return nil
    end
    local vehicleId = tostring(vehicle.getId and vehicle:getId() or "")
    local partId = tostring(part.getId and part:getId() or "Radio")
    local targetKey = WindowRegistry and WindowRegistry.vehicleTargetKey
        and WindowRegistry.vehicleTargetKey(vehicleId, partId)
        or ""
    if targetKey ~= "" and WindowRegistry and WindowRegistry.findWindow then
        local exact = WindowRegistry.findWindow(env, playerNum, targetKey)
        if exact then
            return exact
        end
    end
    return findFallbackOpenVehicleWindow(playerNum, vehicleId, partId)
end

function NMDeviceWindow.collectOpenMediaIngressZones(playerNum, dragItems)
    local mediaEnv = getMediaSlotEnv()
    local isCompatibleMediaDragFn = mediaEnv and mediaEnv.isCompatibleMediaDrag or nil
    local resolveMediaSlotFullTypeFn = mediaEnv and mediaEnv.resolveMediaSlotFullType or nil
    local queueDraggedMediaInsertFn = mediaEnv and mediaEnv.queueDraggedMediaInsert or nil
    local queueMediaSlotEjectFn = mediaEnv and mediaEnv.queueMediaSlotEject or nil
    if not (isCompatibleMediaDragFn and resolveMediaSlotFullTypeFn and queueDraggedMediaInsertFn and queueMediaSlotEjectFn) then
        return {}
    end
    local zones = {}
    local wins = collectPlayerWindows(playerNum)
    for i = 1, #wins do
        local win = wins[i]
        if isWindowVisible(win) and supportsSharedMediaSlotTarget(win.target) then
            local button = win.mediaSlot and win.mediaSlot.button or nil
            local rect = getButtonScreenRect(button)
            if rect then
                local resolved = win.resolveContextCached and win:resolveContextCached() or nil
                local state = resolved and resolved.state or nil
                local zone = NMSlotHostLifecycle.buildSharedMediaSlotZone({
        window = win,
        uiFamily = "generic",
        zoneKind = "slot",
        rect = rect,
        priority = 10,
        zOrder = NMPortableMediaDropArbiter and NMPortableMediaDropArbiter.getWindowZOrder and NMPortableMediaDropArbiter.getWindowZOrder(win) or 0,
        dragItems = dragItems,
        canAcceptDraggedMedia = function(items)
            return type(items) == "table"
                and #items > 0
                and isCompatibleMediaDragFn(win, items)
                and resolveMediaSlotFullTypeFn(win, state) == ""
                and not (win.isAwaitingAuthoritativeMediaEject and win:isAwaitingAuthoritativeMediaEject() == true)
        end,
        canEjectMedia = function()
            return resolveMediaSlotFullTypeFn(win, state) ~= ""
        end,
        canStartExtractDrag = function()
            return resolveMediaSlotFullTypeFn(win, state) ~= ""
        end
                })
                if zone then
                    zones[#zones + 1] = zone
                end
            end
        end
    end
    return zones
end

function NMDeviceWindow.collectOpenBatteryIngressZones(playerNum, dragItems)
    local batteryEnv = rawget(_G, "NMBatterySlotEnv") or nil
    local resolveBatterySlotFullTypeFn = batteryEnv and batteryEnv.resolveBatterySlotFullType or nil
    local isCompatibleBatteryDragFn = batteryEnv and batteryEnv.isCompatibleBatteryDrag or nil
    local pickFirstBatteryFn = batteryEnv and batteryEnv.pickFirstBattery or nil
    local normalizeBatteryIngressItemFn = batteryEnv and batteryEnv.normalizeBatteryIngressItem or nil
    local queueBatterySlotActionFn = batteryEnv and batteryEnv.queueBatterySlotAction or nil
    local beginBatteryExtractDragFn = batteryEnv and batteryEnv.beginBatteryExtractDrag or nil
    if not (resolveBatterySlotFullTypeFn and isCompatibleBatteryDragFn and pickFirstBatteryFn and normalizeBatteryIngressItemFn and queueBatterySlotActionFn and beginBatteryExtractDragFn) then
        return {}
    end
    local zones = {}
    local wins = collectPlayerWindows(playerNum)
    for i = 1, #wins do
        local win = wins[i]
        if isWindowVisible(win) and supportsSharedMediaSlotTarget(win.target) then
            local button = win.batterySlot and win.batterySlot.button or nil
            local rect = getButtonScreenRect(button)
            if rect then
                local resolved = win.resolveContextCached and win:resolveContextCached() or nil
                local state = resolved and resolved.state or nil
                local zone = NMSlotHostLifecycle.buildSharedPortableSlotZone({
                    window = win,
                    uiFamily = "generic",
                    zoneKind = "battery",
                    rect = rect,
                    priority = 10,
                    zOrder = NMPortableMediaDropArbiter and NMPortableMediaDropArbiter.getWindowZOrder and NMPortableMediaDropArbiter.getWindowZOrder(win) or 0,
                    dragItems = dragItems,
                    canAcceptDraggedMedia = function(items)
                        return type(items) == "table"
                            and #items > 0
                            and isCompatibleBatteryDragFn(items)
                            and resolveBatterySlotFullTypeFn(win, state) == ""
                    end,
                    canEjectMedia = function()
                        return resolveBatterySlotFullTypeFn(win, state) ~= ""
                    end,
                    canStartExtractDrag = function()
                        return resolveBatterySlotFullTypeFn(win, state) ~= ""
                    end
                })
                if zone then
                    zones[#zones + 1] = zone
                end
            end
        end
    end
    return zones
end

function NMDeviceWindow.collectOpenHeadphoneIngressZones(playerNum, dragItems)
    local headphoneEnv = rawget(_G, "NMHeadphoneSlotEnv") or nil
    local resolveHeadphoneSlotFullTypeFn = headphoneEnv and headphoneEnv.resolveHeadphoneSlotFullType or nil
    local isCompatibleHeadphoneDragFn = headphoneEnv and headphoneEnv.isCompatibleHeadphoneDrag or nil
    local pickFirstCompatibleHeadphoneFn = headphoneEnv and headphoneEnv.pickFirstCompatibleHeadphone or nil
    local normalizeHeadphoneIngressItemFn = headphoneEnv and headphoneEnv.normalizeHeadphoneIngressItem or nil
    local queueHeadphoneSlotActionFn = headphoneEnv and headphoneEnv.queueHeadphoneSlotAction or nil
    local beginHeadphoneExtractDragFn = headphoneEnv and headphoneEnv.beginHeadphoneExtractDrag or nil
    if not (resolveHeadphoneSlotFullTypeFn and isCompatibleHeadphoneDragFn and pickFirstCompatibleHeadphoneFn and normalizeHeadphoneIngressItemFn and queueHeadphoneSlotActionFn and beginHeadphoneExtractDragFn) then
        return {}
    end
    local zones = {}
    local wins = collectPlayerWindows(playerNum)
    for i = 1, #wins do
        local win = wins[i]
        if isWindowVisible(win) and supportsSharedMediaSlotTarget(win.target) then
            local button = win.headphoneSlot and win.headphoneSlot.button or nil
            local rect = getButtonScreenRect(button)
            if rect then
                local resolved = win.resolveContextCached and win:resolveContextCached() or nil
                local state = resolved and resolved.state or nil
                local zone = NMSlotHostLifecycle.buildSharedPortableSlotZone({
                    window = win,
                    uiFamily = "generic",
                    zoneKind = "headphones",
                    rect = rect,
                    priority = 10,
                    zOrder = NMPortableMediaDropArbiter and NMPortableMediaDropArbiter.getWindowZOrder and NMPortableMediaDropArbiter.getWindowZOrder(win) or 0,
                    dragItems = dragItems,
                    canAcceptDraggedMedia = function(items)
                        return type(items) == "table"
                            and #items > 0
                            and isCompatibleHeadphoneDragFn(win, items, resolved, state)
                            and resolveHeadphoneSlotFullTypeFn(win, state) == ""
                    end,
                    canEjectMedia = function()
                        return resolveHeadphoneSlotFullTypeFn(win, state) ~= ""
                    end,
                    canStartExtractDrag = function()
                        return resolveHeadphoneSlotFullTypeFn(win, state) ~= ""
                    end
                })
                if zone then
                    zones[#zones + 1] = zone
                end
            end
        end
    end
    return zones
end

return NMDeviceWindow
