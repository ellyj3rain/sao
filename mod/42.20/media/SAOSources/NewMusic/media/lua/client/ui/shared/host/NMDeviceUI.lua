
require "ui/walkman/NMWalkmanWindowBootstrap"
require "ui/cdplayer/NMCDPlayerWindowBootstrap"
require "ui/boombox/NMBoomboxWindowBootstrap"

NMDeviceUI = NMDeviceUI or {}

local UiLifecycleItemWindows = require "ui/shared/host/NMUiLifecycleItemWindows"
NMDeviceUI._startupAutoOpenSuppressedByPlayer = NMDeviceUI._startupAutoOpenSuppressedByPlayer or {}

local function useFancyPortableUI()
    if NMRuntimeConfig and NMRuntimeConfig.getFancyUIEnabled then
        return NMRuntimeConfig.getFancyUIEnabled() == true
    end
    return true
end

local function uiLifecycleImplementations()
    local out = {}
    if NMWalkmanWindow then
        out[#out + 1] = { name = "walkman", api = NMWalkmanWindow }
    end
    if NMCDPlayerWindow then
        out[#out + 1] = { name = "cdplayer", api = NMCDPlayerWindow }
    end
    if NMBoomboxWindow then
        out[#out + 1] = { name = "boombox", api = NMBoomboxWindow }
    end
    if NMDeviceWindow then
        out[#out + 1] = { name = "generic", api = NMDeviceWindow }
    end
    return out
end

local function closeWindowMapEntry(envName, playerNum)
    local env = rawget(_G, envName) or nil
    local registry = env and env.WindowRegistry or nil
    local closed = registry and registry.closeAllForPlayer and registry.closeAllForPlayer(env, playerNum) == true or false
    if closed ~= true then
        return false
    end
    if env and env.clearPersistedOpenFlag then
        pcall(env.clearPersistedOpenFlag, playerNum)
    end
    return closed
end

local function isUiLifecycleDebugEnabled()
    return NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("ui_lifecycle") == true or false
end

local function logUiLifecycleDispatch(actionName, detail)
    if not (NMCore and NMCore.logChannel and isUiLifecycleDebugEnabled()) then
        return
    end
    NMCore.logChannel("ui_lifecycle", "ui_lifecycle_" .. tostring(actionName or "unknown"), tostring(detail or ""))
end

local function inspectImplementationWindow(entry, playerNum)
    local api = entry and entry.api or nil
    if not (api and api.inspectOpenItemWindowTarget) then
        return nil
    end
    local inspected = api.inspectOpenItemWindowTarget(playerNum)
    if inspected then
        inspected.uiFamily = tostring(entry.name or "unknown")
    end
    return inspected
end

local function resolveWindowApiForItem(item)
    local resolved = UiLifecycleItemWindows.resolveItemLifecycleContext(item)
    local profile = resolved and resolved.profile or nil
    if profile and useFancyPortableUI() then
        local deviceType = tostring(resolved and resolved.deviceType or profile.deviceType or "")
        if deviceType == "walkman" and NMWalkmanWindow then
            return NMWalkmanWindow, resolved
        end
        if deviceType == "cdplayer" and NMCDPlayerWindow then
            return NMCDPlayerWindow, resolved
        end
        if deviceType == "boombox" and NMBoomboxWindow then
            return NMBoomboxWindow, resolved
        end
    end
    return NMDeviceWindow, resolved
end

local function uiLifecycleApiName(windowApi)
    if windowApi == NMWalkmanWindow then
        return "walkman"
    end
    if windowApi == NMCDPlayerWindow then
        return "cdplayer"
    end
    if windowApi == NMBoomboxWindow then
        return "boombox"
    end
    if windowApi == NMDeviceWindow then
        return "generic"
    end
    return "none"
end

local function snapshotsToLine(snapshots)
    if type(snapshots) ~= "table" or #snapshots <= 0 then
        return "none"
    end
    local parts = {}
    for i = 1, #snapshots do
        local snap = snapshots[i]
        parts[#parts + 1] = string.format(
            "%s[player=%s itemId=%s uuid=%s hasRef=%s timed=%s pending=%s awaitInsert=%s awaitEject=%s]",
            tostring(snap.uiFamily or "unknown"),
            tostring(snap.playerNum or 0),
            tostring(snap.itemId or ""),
            tostring(snap.uuid or ""),
            tostring(snap.hasItemRef == true),
            tostring(snap.mediaTimedAction or ""),
            tostring(snap.pendingMediaFullType or ""),
            tostring(snap.awaitingMediaInsert == true),
            tostring(snap.awaitingMediaEject == true)
        )
    end
    return table.concat(parts, " ")
end

local function itemIdentityLineFromResolved(item, resolved)
    local info = resolved or UiLifecycleItemWindows.resolveItemLifecycleContext(item)
    local profile = info and info.profile or nil
    local state = info and info.state or nil
    return string.format(
        "itemId=%s uuid=%s deviceType=%s stateUuid=%s",
        tostring(info and info.itemId or (NMCore and NMCore.itemId and NMCore.itemId(item) or "")),
        tostring(info and info.itemUuid or (NMInventoryHelpers and NMInventoryHelpers.getItemStateUuid and NMInventoryHelpers.getItemStateUuid(item) or "")),
        tostring(profile and profile.deviceType or ""),
        tostring(state and state.deviceUUID or "")
    )
end

local function startupSuppressionBucket()
    NMDeviceUI._startupAutoOpenSuppressedByPlayer = NMDeviceUI._startupAutoOpenSuppressedByPlayer or {}
    return NMDeviceUI._startupAutoOpenSuppressedByPlayer
end

local function withUiLifecycleImplementations(actionName, playerNum, itemId, uuid, callback)
    local implementations = uiLifecycleImplementations()
    local acceptedAny = false
    for i = 1, #implementations do
        local entry = implementations[i]
        local accepted = callback(entry) == true
        logUiLifecycleDispatch(
            actionName .. "_dispatch",
            string.format(
                "impl=%s player=%s itemId=%s uuid=%s accepted=%s",
                tostring(entry.name or "unknown"),
                tostring(playerNum or 0),
                tostring(itemId or ""),
                tostring(uuid or ""),
                tostring(accepted)
            )
        )
        acceptedAny = accepted or acceptedAny
    end
    return acceptedAny
end

local function collectUiLifecycleSnapshots(playerNum)
    if not isUiLifecycleDebugEnabled() then
        return nil
    end
    return NMDeviceUI.inspectOpenItemWindows(playerNum)
end

local function logUiLifecycleSnapshot(actionName, playerNum, itemId, uuid, before, after)
    if not (before and after) then
        return
    end
    logUiLifecycleDispatch(
        actionName .. "_snapshot",
        string.format(
            "player=%s itemId=%s uuid=%s before=%s after=%s",
            tostring(playerNum or 0),
            tostring(itemId or ""),
            tostring(uuid or ""),
            snapshotsToLine(before),
            snapshotsToLine(after)
        )
    )
end

function NMDeviceUI.openForItem(playerNum, item)
    local windowApi, resolved = resolveWindowApiForItem(item)
    logUiLifecycleDispatch(
        "open_for_item_request",
        string.format(
            "player=%s api=%s %s",
            tostring(playerNum or 0),
            tostring(uiLifecycleApiName(windowApi)),
            itemIdentityLineFromResolved(item, resolved)
        )
    )
    if windowApi and windowApi.openForItemResolved then
        return windowApi.openForItemResolved(playerNum, item, resolved)
    end
    if windowApi and windowApi.openForItem then
        return windowApi.openForItem(playerNum, item)
    end
    return nil
end

function NMDeviceUI.beginSessionStartAutoOpenSuppression(playerNum, reason)
    local resolvedPlayerNum = tonumber(playerNum) or 0
    local bucket = startupSuppressionBucket()
    bucket[tostring(resolvedPlayerNum)] = true
    logUiLifecycleDispatch(
        "startup_auto_open_suppression_begin",
        string.format("player=%s reason=%s", tostring(resolvedPlayerNum), tostring(reason or ""))
    )
end

function NMDeviceUI.endSessionStartAutoOpenSuppression(playerNum, reason)
    local resolvedPlayerNum = tonumber(playerNum) or 0
    local bucket = startupSuppressionBucket()
    bucket[tostring(resolvedPlayerNum)] = nil
    logUiLifecycleDispatch(
        "startup_auto_open_suppression_end",
        string.format("player=%s reason=%s", tostring(resolvedPlayerNum), tostring(reason or ""))
    )
end

function NMDeviceUI.canAutoOpenForAttachedTransition(playerNum, item)
    local resolvedPlayerNum = tonumber(playerNum) or 0
    local suppressed = startupSuppressionBucket()[tostring(resolvedPlayerNum)] == true
    logUiLifecycleDispatch(
        "startup_auto_open_policy",
        string.format(
            "player=%s allowed=%s suppressed=%s %s",
            tostring(resolvedPlayerNum),
            tostring(suppressed ~= true),
            tostring(suppressed),
            itemIdentityLineFromResolved(item)
        )
    )
    return suppressed ~= true
end

function NMDeviceUI.findOpenForItem(playerNum, item)
    if not item then
        return nil
    end
    local windowApi, resolved = resolveWindowApiForItem(item)
    if windowApi then
        local found = nil
        if windowApi.findOpenForItemResolved then
            found = windowApi.findOpenForItemResolved(playerNum, item, resolved)
        elseif windowApi.findOpenForItem then
            found = windowApi.findOpenForItem(playerNum, item)
        end
        logUiLifecycleDispatch(
            "find_open_for_item",
            string.format(
                "player=%s api=%s found=%s %s",
                tostring(playerNum or 0),
                tostring(uiLifecycleApiName(windowApi)),
                tostring(found ~= nil),
                itemIdentityLineFromResolved(item, resolved)
            )
        )
        return found
    end
    return nil
end

function NMDeviceUI.openForItemIfNeeded(playerNum, item)
    if not item then
        return nil
    end
    local existing = NMDeviceUI.findOpenForItem and NMDeviceUI.findOpenForItem(playerNum, item) or nil
    if existing then
        if existing.setVisible then
            existing:setVisible(true)
        end
        if existing.bringToTop then
            existing:bringToTop()
        end
        logUiLifecycleDispatch(
            "open_if_needed_reuse",
            string.format(
                "player=%s reused=true targetKind=%s targetItemId=%s targetUuid=%s %s",
                tostring(playerNum or 0),
                tostring(existing.target and existing.target.kind or ""),
                tostring(existing.target and existing.target.itemId or ""),
                tostring(existing.target and existing.target.uuid or ""),
                itemIdentityLineFromResolved(item)
            )
        )
        return existing
    end
    logUiLifecycleDispatch(
        "open_if_needed_create",
        string.format("player=%s reused=false %s", tostring(playerNum or 0), itemIdentityLineFromResolved(item))
    )
    return NMDeviceUI.openForItem(playerNum, item)
end

function NMDeviceUI.openForVehicle(playerNum, vehicle, part)
    return NMDeviceWindow.openForVehicle(playerNum, vehicle, part)
end

function NMDeviceUI.closeForItem(playerNum, itemId, uuid)
    local before = collectUiLifecycleSnapshots(playerNum)
    local closed = withUiLifecycleImplementations("close", playerNum, itemId, uuid, function(entry)
        local api = entry.api
        return api and api.closeOpenForItemTarget and api.closeOpenForItemTarget(playerNum, itemId, uuid) == true or false
    end)
    local after = before and NMDeviceUI.inspectOpenItemWindows(playerNum) or nil
    logUiLifecycleSnapshot("close", playerNum, itemId, uuid, before, after)
    return closed
end

function NMDeviceUI.invalidateOpenItemWindow(itemId, uuid)
    local playerNum = 0
    local before = collectUiLifecycleSnapshots(playerNum)
    local invalidated = withUiLifecycleImplementations("invalidate", playerNum, itemId, uuid, function(entry)
        local api = entry.api
        return api and api.invalidateOpenItemWindow and api.invalidateOpenItemWindow(itemId, uuid) == true or false
    end)
    local after = before and NMDeviceUI.inspectOpenItemWindows(playerNum) or nil
    logUiLifecycleSnapshot("invalidate", playerNum, itemId, uuid, before, after)
    return invalidated
end

function NMDeviceUI.invalidateOpenVehicleWindow(vehicleId, partId, playerNum)
    local resolvedPlayerNum = tonumber(playerNum) or 0
    local invalidated = NMDeviceWindow
        and NMDeviceWindow.invalidateOpenVehicleWindow
        and NMDeviceWindow.invalidateOpenVehicleWindow(resolvedPlayerNum, vehicleId, partId) == true
        or false
    logUiLifecycleDispatch(
        "invalidate_vehicle",
        string.format(
            "player=%s vehicleId=%s partId=%s invalidated=%s",
            tostring(resolvedPlayerNum),
            tostring(vehicleId or ""),
            tostring(partId or "Radio"),
            tostring(invalidated)
        )
    )
    return invalidated
end

function NMDeviceUI.rebindOpenItemWindow(itemId, uuid)
    local playerNum = 0
    local before = collectUiLifecycleSnapshots(playerNum)
    local rebound = withUiLifecycleImplementations("rebind", playerNum, itemId, uuid, function(entry)
        local api = entry.api
        return api and api.rebindOpenPortableItemWindow and api.rebindOpenPortableItemWindow(itemId, uuid) == true or false
    end)
    local after = before and NMDeviceUI.inspectOpenItemWindows(playerNum) or nil
    logUiLifecycleSnapshot("rebind", playerNum, itemId, uuid, before, after)
    return rebound
end

NMDeviceUI.rebindOpenPortableItemWindow = NMDeviceUI.rebindOpenItemWindow

function NMDeviceUI.inspectOpenItemWindowTarget(playerNum)
    local inspectedWindows = NMDeviceUI.inspectOpenItemWindows(playerNum)
    if #inspectedWindows > 0 then
        return inspectedWindows[#inspectedWindows]
    end
    return nil
end

function NMDeviceUI.inspectOpenItemWindows(playerNum)
    local implementations = uiLifecycleImplementations()
    local out = {}
    for i = 1, #implementations do
        local inspected = inspectImplementationWindow(implementations[i], playerNum)
        if inspected then
            out[#out + 1] = inspected
        end
    end
    return out
end

NMDeviceUI.inspectOpenPortableWindows = NMDeviceUI.inspectOpenItemWindows

function NMDeviceUI.closeAllForPlayer(playerNum, reason)
    local resolvedPlayerNum = tonumber(playerNum) or 0
    local closedWalkman = closeWindowMapEntry("NMWalkmanWindowEnv", resolvedPlayerNum)
    local closedCdPlayer = closeWindowMapEntry("NMCDPlayerWindowEnv", resolvedPlayerNum)
    local closedBoombox = closeWindowMapEntry("NMBoomboxWindowEnv", resolvedPlayerNum)
    local closedGeneric = closeWindowMapEntry("NMDeviceWindowEnv", resolvedPlayerNum)
    local closed = closedWalkman or closedCdPlayer or closedBoombox or closedGeneric
    logUiLifecycleDispatch(
        "close_all_for_player",
        string.format(
            "player=%s reason=%s walkman=%s cdplayer=%s boombox=%s generic=%s closed=%s",
            tostring(resolvedPlayerNum),
            tostring(reason or ""),
            tostring(closedWalkman),
            tostring(closedCdPlayer),
            tostring(closedBoombox),
            tostring(closedGeneric),
            tostring(closed)
        )
    )
    return closed
end
