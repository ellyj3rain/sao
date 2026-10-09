require "loot/NMLootDebugHelpers"
require "loot/NMLootContainerClassifier"
require "loot/NMLootPlaceholderResolver"
require "loot/NMVanillaCDLootConverter"

NMServerLootProbe = NMServerLootProbe or {}

local probe = NMServerLootProbe

local CATEGORY_ORDER = {
    "cassettes",
    "vinyl",
    "cds",
    "walkman",
    "boombox",
    "cdplayer",
    "recordplayer"
}

local MIN_AGGREGATE_LOG_INTERVAL_MS = 5000
local FORCE_AGGREGATE_LOG_ITEM_DELTA = 5
local VANILLA_DISC_LEAK_LOG_INTERVAL_MS = 15000
local VISIBLE_REPAIR_ATTEMPT_INTERVAL_MS = 5000
local VISIBLE_REPAIR_LOG_INTERVAL_MS = 5000

local lastSessionLogKey = ""
local lastVisibleRepairAttemptByKey = {}
local lastVisibleRepairLogByKey = {}

local ROUTE_CLASS_ORDER = {
    "music_store",
    "electronics",
    "residential_misc",
    "mail",
    "vehicle_glovebox",
    "vehicle_seatrear",
    "vehicle_cargo",
    "other"
}

local VEHICLE_ROUTE_CLASS_ORDER = {
    "vehicle_glovebox",
    "vehicle_seatrear",
    "vehicle_cargo"
}

local function newCategoryCounts()
    return {
        cassettes = 0,
        vinyl = 0,
        cds = 0,
        walkman = 0,
        boombox = 0,
        cdplayer = 0,
        recordplayer = 0
    }
end

local function newRouteCounts()
    return {
        containers = 0,
        managedContainers = 0,
        managedItems = 0,
        placeholderContainers = 0,
        placeholderItems = 0,
        totals = newCategoryCounts(),
        placeholders = newCategoryCounts()
    }
end

local function newRouteMap()
    local routes = {}
    for i = 1, #ROUTE_CLASS_ORDER do
        routes[ROUTE_CLASS_ORDER[i]] = newRouteCounts()
    end
    return routes
end

local function newVanillaReplaceCounts()
    return {
        observedVanillaCDs = 0,
        replaced = 0,
        discarded = 0,
        failed = 0,
        cassettes = 0,
        cds = 0,
        observedVanillaCDPlayers = 0,
        cdPlayerReplaced = 0,
        cdPlayerDiscarded = 0,
        cdPlayerFailed = 0,
        walkman = 0,
        cdplayer = 0,
        postFillContainers = 0,
        postFillItems = 0
    }
end

local function newState()
    return {
        configured = false,
        preset = "",
        rawRatesText = "",
        managedLootMap = {},
        totals = newCategoryCounts(),
        vehicleTotals = newCategoryCounts(),
        placeholderTotals = newCategoryCounts(),
        vehiclePlaceholderTotals = newCategoryCounts(),
        lastLoggedTotals = newCategoryCounts(),
        lastLoggedPlaceholderTotals = newCategoryCounts(),
        vanillaReplace = newVanillaReplaceCounts(),
        lastLoggedVanillaReplace = newVanillaReplaceCounts(),
        lastLoggedManagedItems = 0,
        lastLoggedPlaceholderItems = 0,
        lastAggregateLogMs = nil,
        observedContainers = 0,
        observedManagedContainers = 0,
        observedManagedItems = 0,
        observedPlaceholderContainers = 0,
        observedPlaceholderItems = 0,
        observedVehicleContainers = 0,
        observedManagedVehicleContainers = 0,
        observedManagedVehicleItems = 0,
        observedVehiclePlaceholderContainers = 0,
        observedVehiclePlaceholderItems = 0,
        routeCounts = newRouteMap(),
        seenContainers = setmetatable({}, { __mode = "k" }),
        vanillaDiscLeakSeenContainers = setmetatable({}, { __mode = "k" }),
        lastVanillaDiscLeakLogMs = nil
    }
end

local state = newState()

local function shouldLog()
    return NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("loot_probe") == true
end

local function logProbe(tag, detail)
    if shouldLog() and NMCore and NMCore.logChannel then
        NMCore.logChannel("loot_probe", tostring(tag or "loot_probe"), tostring(detail or ""))
    end
end

local function nowMs()
    if getTimestampMs then
        local ms = tonumber(getTimestampMs())
        if ms then
            return ms
        end
    end
    if getTimestamp then
        local seconds = tonumber(getTimestamp())
        if seconds then
            return seconds * 1000
        end
    end
    return 0
end

local function resolveContainerItems(container)
    if NMLootDebugHelpers and NMLootDebugHelpers.resolveContainerItems then
        return NMLootDebugHelpers.resolveContainerItems(container, "loot_probe.skip_container")
    end
    return nil
end

local function formatCategoryCounts(counts)
    local parts = {}
    for i = 1, #CATEGORY_ORDER do
        local key = CATEGORY_ORDER[i]
        parts[#parts + 1] = key .. "=" .. tostring(tonumber(counts and counts[key]) or 0)
    end
    return table.concat(parts, " ")
end

local function formatSessionHeader()
    return string.format(
        "preset=%s sandbox={%s}",
        tostring(state.preset or ""),
        tostring(state.rawRatesText or "")
    )
end

local function formatRunningTotals()
    return string.format(
        "containers=%s managedContainers=%s managedItems=%s placeholderContainers=%s placeholderItems=%s totals={%s} placeholders={%s}",
        tostring(state.observedContainers),
        tostring(state.observedManagedContainers),
        tostring(state.observedManagedItems),
        tostring(state.observedPlaceholderContainers),
        tostring(state.observedPlaceholderItems),
        formatCategoryCounts(state.totals),
        formatCategoryCounts(state.placeholderTotals)
    )
end

local function formatVehicleRunningTotals()
    return string.format(
        "containers=%s managedContainers=%s managedItems=%s placeholderContainers=%s placeholderItems=%s totals={%s} placeholders={%s}",
        tostring(state.observedVehicleContainers),
        tostring(state.observedManagedVehicleContainers),
        tostring(state.observedManagedVehicleItems),
        tostring(state.observedVehiclePlaceholderContainers),
        tostring(state.observedVehiclePlaceholderItems),
        formatCategoryCounts(state.vehicleTotals),
        formatCategoryCounts(state.vehiclePlaceholderTotals)
    )
end

local function classifyFillRoute(roomName, containerType, container)
    local routeClass = NMLootContainerClassifier
        and NMLootContainerClassifier.classifyContainer
        and NMLootContainerClassifier.classifyContainer(roomName, containerType, container)
        or ""
    routeClass = tostring(routeClass or "")
    if routeClass == "" then
        return "other"
    end
    return routeClass
end

local function isVehicleRoute(routeClass)
    return string.sub(tostring(routeClass or ""), 1, #"vehicle_") == "vehicle_"
end

local function formatRouteSummary(routeClass, route)
    return string.format(
        "%s={containers=%s managedContainers=%s managedItems=%s placeholderContainers=%s placeholderItems=%s totals={%s} placeholders={%s}}",
        tostring(routeClass or ""),
        tostring(route and route.containers or 0),
        tostring(route and route.managedContainers or 0),
        tostring(route and route.managedItems or 0),
        tostring(route and route.placeholderContainers or 0),
        tostring(route and route.placeholderItems or 0),
        formatCategoryCounts(route and route.totals or nil),
        formatCategoryCounts(route and route.placeholders or nil)
    )
end

local function formatVehicleRouteDetail()
    local parts = {}
    for i = 1, #VEHICLE_ROUTE_CLASS_ORDER do
        local routeClass = VEHICLE_ROUTE_CLASS_ORDER[i]
        parts[#parts + 1] = formatRouteSummary(routeClass, state.routeCounts[routeClass])
    end
    return table.concat(parts, " ")
end

local function formatMusicStoreRunningTotals()
    return formatRouteSummary("music_store", state.routeCounts.music_store)
end

local function formatVanillaReplaceTotals()
    return string.format(
        "observedVanillaCDs=%s replaced=%s discarded=%s failed=%s replacements={cassettes=%s cds=%s} observedVanillaCDPlayers=%s cdPlayerReplaced=%s cdPlayerDiscarded=%s cdPlayerFailed=%s deviceReplacements={walkman=%s cdplayer=%s} postFillVanilla={containers=%s items=%s}",
        tostring(state.vanillaReplace.observedVanillaCDs or 0),
        tostring(state.vanillaReplace.replaced or 0),
        tostring(state.vanillaReplace.discarded or 0),
        tostring(state.vanillaReplace.failed or 0),
        tostring(state.vanillaReplace.cassettes or 0),
        tostring(state.vanillaReplace.cds or 0),
        tostring(state.vanillaReplace.observedVanillaCDPlayers or 0),
        tostring(state.vanillaReplace.cdPlayerReplaced or 0),
        tostring(state.vanillaReplace.cdPlayerDiscarded or 0),
        tostring(state.vanillaReplace.cdPlayerFailed or 0),
        tostring(state.vanillaReplace.walkman or 0),
        tostring(state.vanillaReplace.cdplayer or 0),
        tostring(state.vanillaReplace.postFillContainers or 0),
        tostring(state.vanillaReplace.postFillItems or 0)
    )
end

local function countsChangedSinceLastLog()
    for i = 1, #CATEGORY_ORDER do
        local key = CATEGORY_ORDER[i]
        if (tonumber(state.totals[key]) or 0) ~= (tonumber(state.lastLoggedTotals[key]) or 0) then
            return true
        end
        if (tonumber(state.placeholderTotals[key]) or 0) ~= (tonumber(state.lastLoggedPlaceholderTotals[key]) or 0) then
            return true
        end
    end
    local vanillaKeys = {
        "observedVanillaCDs",
        "replaced",
        "discarded",
        "failed",
        "cassettes",
        "cds",
        "observedVanillaCDPlayers",
        "cdPlayerReplaced",
        "cdPlayerDiscarded",
        "cdPlayerFailed",
        "walkman",
        "cdplayer",
        "postFillContainers",
        "postFillItems"
    }
    for i = 1, #vanillaKeys do
        local key = vanillaKeys[i]
        if (tonumber(state.vanillaReplace[key]) or 0) ~= (tonumber(state.lastLoggedVanillaReplace[key]) or 0) then
            return true
        end
    end
    return false
end

local function rememberLoggedTotals(loggedAtMs)
    for i = 1, #CATEGORY_ORDER do
        local key = CATEGORY_ORDER[i]
        state.lastLoggedTotals[key] = tonumber(state.totals[key]) or 0
        state.lastLoggedPlaceholderTotals[key] = tonumber(state.placeholderTotals[key]) or 0
    end
    for key, _ in pairs(state.lastLoggedVanillaReplace) do
        state.lastLoggedVanillaReplace[key] = tonumber(state.vanillaReplace[key]) or 0
    end
    state.lastLoggedManagedItems = tonumber(state.observedManagedItems) or 0
    state.lastLoggedPlaceholderItems = tonumber(state.observedPlaceholderItems) or 0
    state.lastAggregateLogMs = tonumber(loggedAtMs) or nowMs()
end

local function shouldLogAggregateUpdate()
    if not countsChangedSinceLastLog() then
        return false
    end
    if state.lastAggregateLogMs == nil then
        return true
    end

    local managedDelta = (tonumber(state.observedManagedItems) or 0) - (tonumber(state.lastLoggedManagedItems) or 0)
    local placeholderDelta = (tonumber(state.observedPlaceholderItems) or 0) - (tonumber(state.lastLoggedPlaceholderItems) or 0)
    local vanillaDelta = (tonumber(state.vanillaReplace.observedVanillaCDs) or 0)
        - (tonumber(state.lastLoggedVanillaReplace.observedVanillaCDs) or 0)
    local vanillaDeviceDelta = (tonumber(state.vanillaReplace.observedVanillaCDPlayers) or 0)
        - (tonumber(state.lastLoggedVanillaReplace.observedVanillaCDPlayers) or 0)
    if managedDelta + placeholderDelta + vanillaDelta + vanillaDeviceDelta >= FORCE_AGGREGATE_LOG_ITEM_DELTA then
        return true
    end

    local elapsed = nowMs() - (tonumber(state.lastAggregateLogMs) or 0)
    return elapsed >= MIN_AGGREGATE_LOG_INTERVAL_MS
end

local function countObservedItemsInContainer(container)
    local counts = newCategoryCounts()
    local placeholderCounts = newCategoryCounts()
    local total = 0
    local placeholderTotal = 0
    local items = resolveContainerItems(container)
    if not (items and items.size and items.get) then
        return counts, total, placeholderCounts, placeholderTotal
    end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local fullType = item and item.getFullType and tostring(item:getFullType() or "") or ""
        local category = state.managedLootMap[fullType]
        if counts[category] ~= nil then
            counts[category] = (tonumber(counts[category]) or 0) + 1
            total = total + 1
        elseif NMLootPlaceholderResolver
            and NMLootPlaceholderResolver.isPlaceholderFullType
        then
            local placeholderCategory = NMLootPlaceholderResolver.isPlaceholderFullType(fullType)
            if placeholderCounts[placeholderCategory] ~= nil then
                placeholderCounts[placeholderCategory] = (tonumber(placeholderCounts[placeholderCategory]) or 0) + 1
                placeholderTotal = placeholderTotal + 1
            end
        end
    end
    return counts, total, placeholderCounts, placeholderTotal
end

local function countVanillaDiscsInContainer(container)
    local items = resolveContainerItems(container)
    if not (items and items.size and items.get) then
        return 0, ""
    end
    local count = 0
    local names = {}
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local fullType = item and item.getFullType and tostring(item:getFullType() or "") or ""
        local itemType = item and item.getType and tostring(item:getType() or "") or ""
        if fullType == "Disc_Retail" or fullType == "Base.Disc_Retail" or itemType == "Disc_Retail" then
            count = count + 1
            if #names < 5 then
                local name = item and item.getName and tostring(item:getName() or "") or fullType
                names[#names + 1] = name
            end
        end
    end
    return count, table.concat(names, "|")
end

local function countVanillaCDPlayersInContainer(container)
    local items = resolveContainerItems(container)
    if not (items and items.size and items.get) then
        return 0, ""
    end
    local count = 0
    local names = {}
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local fullType = item and item.getFullType and tostring(item:getFullType() or "") or ""
        local itemType = item and item.getType and tostring(item:getType() or "") or ""
        if fullType == "CDplayer" or fullType == "Base.CDplayer"
            or fullType == "CDPlayer" or fullType == "Base.CDPlayer"
            or itemType == "CDplayer" or itemType == "CDPlayer"
        then
            count = count + 1
            if #names < 5 then
                local name = item and item.getName and tostring(item:getName() or "") or fullType
                names[#names + 1] = name
            end
        end
    end
    return count, table.concat(names, "|")
end

local function countVanillaMediaInContainer(container)
    local discCount, discNames = countVanillaDiscsInContainer(container)
    local deviceCount, deviceNames = countVanillaCDPlayersInContainer(container)
    return {
        total = (tonumber(discCount) or 0) + (tonumber(deviceCount) or 0),
        discs = tonumber(discCount) or 0,
        devices = tonumber(deviceCount) or 0,
        discNames = tostring(discNames or ""),
        deviceNames = tostring(deviceNames or "")
    }
end

local function shouldLogVisibleRepair(key)
    if shouldLog() ~= true then
        return false
    end
    local currentMs = nowMs()
    local last = tonumber(lastVisibleRepairLogByKey[key]) or 0
    if last > 0 and (currentMs - last) < VISIBLE_REPAIR_LOG_INTERVAL_MS then
        return false
    end
    lastVisibleRepairLogByKey[key] = currentMs
    return true
end

local function isVisibleRepairAllowed()
    return (
        NMServerSandboxLootController
        and NMServerSandboxLootController.isSandboxLootApplied
        and NMServerSandboxLootController.isSandboxLootApplied() == true
        and NMVanillaCDLootConverter
        and NMVanillaCDLootConverter.isEnabled
        and NMVanillaCDLootConverter.isEnabled() == true
        and NMVanillaCDLootConverter.processContainer
    ) and true or false
end

local function playerRepairKey(player)
    if player and player.getOnlineID then
        local onlineId = player:getOnlineID()
        if onlineId ~= nil then
            return tostring(onlineId)
        end
    end
    if player and player.getUsername then
        return tostring(player:getUsername() or "unknown")
    end
    return "unknown"
end

local function shouldRunVisibleRepair(player, args)
    local key = table.concat({
        playerRepairKey(player),
        tostring(args and args.x or ""),
        tostring(args and args.y or ""),
        tostring(args and args.z or ""),
        tostring(args and args.containerType or ""),
        tostring(args and args.containerName or "")
    }, "|")
    local currentMs = nowMs()
    local last = tonumber(lastVisibleRepairAttemptByKey[key]) or 0
    if last > 0 and (currentMs - last) < VISIBLE_REPAIR_ATTEMPT_INTERVAL_MS then
        return false, key
    end
    lastVisibleRepairAttemptByKey[key] = currentMs
    return true, key
end

local function maybeLogVanillaDiscLeak(roomName, containerType, container, routeClass, count, names)
    if count <= 0 then
        return
    end
    state.vanillaReplace.postFillContainers = (tonumber(state.vanillaReplace.postFillContainers) or 0) + 1
    state.vanillaReplace.postFillItems = (tonumber(state.vanillaReplace.postFillItems) or 0) + count
    if state.vanillaDiscLeakSeenContainers[container] == true then
        return
    end
    state.vanillaDiscLeakSeenContainers[container] = true
    local currentMs = nowMs()
    local elapsed = currentMs - (tonumber(state.lastVanillaDiscLeakLogMs) or 0)
    if state.lastVanillaDiscLeakLogMs ~= nil and elapsed < VANILLA_DISC_LEAK_LOG_INTERVAL_MS then
        return
    end
    state.lastVanillaDiscLeakLogMs = currentMs
    local context = NMLootDebugHelpers
        and NMLootDebugHelpers.describeFullContainerContext
        and NMLootDebugHelpers.describeFullContainerContext(roomName, containerType, container, routeClass)
        or { shape = tostring(container or "nil") }
    logProbe(
        "loot_probe.vanilla_disc_leak",
        string.format(
            "count=%s names=%s room=%s containerType=%s routeClass=%s shape=%s",
            tostring(count),
            tostring(names or ""),
            tostring(roomName or ""),
            tostring(containerType or ""),
            tostring(routeClass or ""),
            tostring(context and context.shape or container or "nil")
        )
    )
end

local function recordRouteObservation(routeClass, counts, total, placeholderCounts, placeholderTotal)
    local key = tostring(routeClass or "other")
    local route = state.routeCounts[key]
    if type(route) ~= "table" then
        route = newRouteCounts()
        state.routeCounts[key] = route
    end

    route.containers = (tonumber(route.containers) or 0) + 1
    if total > 0 then
        route.managedContainers = (tonumber(route.managedContainers) or 0) + 1
        route.managedItems = (tonumber(route.managedItems) or 0) + total
    end
    if placeholderTotal > 0 then
        route.placeholderContainers = (tonumber(route.placeholderContainers) or 0) + 1
        route.placeholderItems = (tonumber(route.placeholderItems) or 0) + placeholderTotal
    end
    for i = 1, #CATEGORY_ORDER do
        local category = CATEGORY_ORDER[i]
        route.totals[category] = (tonumber(route.totals[category]) or 0) + (tonumber(counts and counts[category]) or 0)
        route.placeholders[category] = (tonumber(route.placeholders[category]) or 0) + (tonumber(placeholderCounts and placeholderCounts[category]) or 0)
    end
end

function probe.configure(config)
    state = newState()
    state.configured = true
    state.preset = tostring(config and config.preset or "")
    state.rawRatesText = tostring(config and config.rawRatesText or "")
    state.managedLootMap = config and config.managedLootMap or {}
    if shouldLog() then
        local sessionKey = tostring(state.preset or "") .. "|" .. tostring(state.rawRatesText or "")
        if sessionKey ~= lastSessionLogKey then
            lastSessionLogKey = sessionKey
            logProbe("loot_probe.session", formatSessionHeader())
        end
    end
end

function probe.disable()
    state = newState()
end

function probe.isConfigured()
    return state.configured == true
end

function probe.isFillObservationActive()
    return state.configured == true and shouldLog()
end

function probe.recordVanillaReplace(delta)
    if state.configured ~= true or type(delta) ~= "table" then
        return
    end
    state.vanillaReplace.observedVanillaCDs = (tonumber(state.vanillaReplace.observedVanillaCDs) or 0)
        + (tonumber(delta.observedVanillaCDs) or 0)
    state.vanillaReplace.replaced = (tonumber(state.vanillaReplace.replaced) or 0)
        + (tonumber(delta.replaced) or 0)
    state.vanillaReplace.discarded = (tonumber(state.vanillaReplace.discarded) or 0)
        + (tonumber(delta.discarded) or 0)
    state.vanillaReplace.failed = (tonumber(state.vanillaReplace.failed) or 0)
        + (tonumber(delta.failed) or 0)
    state.vanillaReplace.cassettes = (tonumber(state.vanillaReplace.cassettes) or 0)
        + (tonumber(delta.replacements and delta.replacements.cassettes) or 0)
    state.vanillaReplace.cds = (tonumber(state.vanillaReplace.cds) or 0)
        + (tonumber(delta.replacements and delta.replacements.cds) or 0)
    state.vanillaReplace.observedVanillaCDPlayers = (tonumber(state.vanillaReplace.observedVanillaCDPlayers) or 0)
        + (tonumber(delta.observedVanillaCDPlayers) or 0)
    state.vanillaReplace.cdPlayerReplaced = (tonumber(state.vanillaReplace.cdPlayerReplaced) or 0)
        + (tonumber(delta.cdPlayerReplaced) or 0)
    state.vanillaReplace.cdPlayerDiscarded = (tonumber(state.vanillaReplace.cdPlayerDiscarded) or 0)
        + (tonumber(delta.cdPlayerDiscarded) or 0)
    state.vanillaReplace.cdPlayerFailed = (tonumber(state.vanillaReplace.cdPlayerFailed) or 0)
        + (tonumber(delta.cdPlayerFailed) or 0)
    state.vanillaReplace.walkman = (tonumber(state.vanillaReplace.walkman) or 0)
        + (tonumber(delta.deviceReplacements and delta.deviceReplacements.walkman) or 0)
    state.vanillaReplace.cdplayer = (tonumber(state.vanillaReplace.cdplayer) or 0)
        + (tonumber(delta.deviceReplacements and delta.deviceReplacements.cdplayer) or 0)
end

function probe.onFillContainer(roomName, containerType, container)
    if not probe.isFillObservationActive() then
        return
    end
    if container ~= nil and state.seenContainers[container] then
        return
    end
    if container ~= nil then
        state.seenContainers[container] = true
    end

    state.observedContainers = (tonumber(state.observedContainers) or 0) + 1
    local routeClass = classifyFillRoute(roomName, containerType, container)
    local vehicleFill = isVehicleRoute(routeClass)
    if vehicleFill then
        state.observedVehicleContainers = (tonumber(state.observedVehicleContainers) or 0) + 1
    end

    local counts, total, placeholderCounts, placeholderTotal = countObservedItemsInContainer(container)
    local vanillaDiscCount, vanillaDiscNames = countVanillaDiscsInContainer(container)
    maybeLogVanillaDiscLeak(roomName, containerType, container, routeClass, vanillaDiscCount, vanillaDiscNames)
    recordRouteObservation(routeClass, counts, total, placeholderCounts, placeholderTotal)
    if total <= 0 and placeholderTotal <= 0 then
        if shouldLogAggregateUpdate() then
            local loggedAtMs = nowMs()
            logProbe("loot_probe.observed", formatRunningTotals())
            logProbe("loot_probe.observed_vehicle", formatVehicleRunningTotals())
            logProbe("loot_probe.observed_vehicle_detail", formatVehicleRouteDetail())
            logProbe("loot_probe.observed_music_store", formatMusicStoreRunningTotals())
            logProbe("loot_probe.observed_vanilla_replace", formatVanillaReplaceTotals())
            rememberLoggedTotals(loggedAtMs)
        end
        return
    end

    if total > 0 then
        state.observedManagedContainers = (tonumber(state.observedManagedContainers) or 0) + 1
        state.observedManagedItems = (tonumber(state.observedManagedItems) or 0) + total
    end
    if placeholderTotal > 0 then
        state.observedPlaceholderContainers = (tonumber(state.observedPlaceholderContainers) or 0) + 1
        state.observedPlaceholderItems = (tonumber(state.observedPlaceholderItems) or 0) + placeholderTotal
    end
    for i = 1, #CATEGORY_ORDER do
        local key = CATEGORY_ORDER[i]
        state.totals[key] = (tonumber(state.totals[key]) or 0) + (tonumber(counts[key]) or 0)
        state.placeholderTotals[key] = (tonumber(state.placeholderTotals[key]) or 0) + (tonumber(placeholderCounts[key]) or 0)
    end
    if vehicleFill then
        if total > 0 then
            state.observedManagedVehicleContainers = (tonumber(state.observedManagedVehicleContainers) or 0) + 1
            state.observedManagedVehicleItems = (tonumber(state.observedManagedVehicleItems) or 0) + total
        end
        if placeholderTotal > 0 then
            state.observedVehiclePlaceholderContainers = (tonumber(state.observedVehiclePlaceholderContainers) or 0) + 1
            state.observedVehiclePlaceholderItems = (tonumber(state.observedVehiclePlaceholderItems) or 0) + placeholderTotal
        end
        for i = 1, #CATEGORY_ORDER do
            local key = CATEGORY_ORDER[i]
            state.vehicleTotals[key] = (tonumber(state.vehicleTotals[key]) or 0) + (tonumber(counts[key]) or 0)
            state.vehiclePlaceholderTotals[key] = (tonumber(state.vehiclePlaceholderTotals[key]) or 0) + (tonumber(placeholderCounts[key]) or 0)
        end
    end

    if shouldLogAggregateUpdate() then
        local loggedAtMs = nowMs()
        logProbe("loot_probe.observed", formatRunningTotals())
        logProbe("loot_probe.observed_vehicle", formatVehicleRunningTotals())
        logProbe("loot_probe.observed_vehicle_detail", formatVehicleRouteDetail())
        logProbe("loot_probe.observed_music_store", formatMusicStoreRunningTotals())
        logProbe("loot_probe.observed_vanilla_replace", formatVanillaReplaceTotals())
        rememberLoggedTotals(loggedAtMs)
    end
end

local function containerSquareText(container)
    local square = nil
    if container and container.getSourceGrid then
        square = container:getSourceGrid()
    end
    if not square and container and container.getParent then
        local parent = container:getParent()
        if parent and parent.getSquare then
            square = parent:getSquare()
        end
    end
    if square and square.getX and square.getY and square.getZ then
        return string.format(
            "%d,%d,%d",
            tonumber(square:getX()) or 0,
            tonumber(square:getY()) or 0,
            tonumber(square:getZ()) or 0
        )
    end
    return ""
end

local function containerTypeText(container)
    if container and container.getType then
        return tostring(container:getType() or "")
    end
    return ""
end

local function appendServerVisibleMatch(matches, container, source, targetType)
    if not container then
        return 0, 0, 0, 0, 0
    end
    local discCount, discNames = countVanillaDiscsInContainer(container)
    local deviceCount, deviceNames = countVanillaCDPlayersInContainer(container)
    local count = discCount + deviceCount
    local cType = containerTypeText(container)
    local typeMatches = targetType == "" or cType == targetType
    if count > 0 or typeMatches then
        matches[#matches + 1] = string.format(
            "source=%s type=%s typeMatches=%s square=%s count=%d discCount=%d deviceCount=%d discNames={%s} deviceNames={%s} container=%s",
            tostring(source or ""),
            tostring(cType),
            tostring(typeMatches == true),
            tostring(containerSquareText(container)),
            tonumber(count) or 0,
            tonumber(discCount) or 0,
            tonumber(deviceCount) or 0,
            tostring(discNames or ""),
            tostring(deviceNames or ""),
            tostring(container)
        )
    end
    return 1, count > 0 and 1 or 0, discCount, deviceCount
end

local function inspectObjectContainers(matches, object, source, targetType, seen)
    if not object then
        return 0, 0, 0, 0
    end
    local inspected = 0
    local vanillaContainers = 0
    local vanillaDiscItems = 0
    local vanillaDeviceItems = 0
    if object.getContainer then
        local container = object:getContainer()
        if container and seen[container] ~= true then
            seen[container] = true
            local scanned, c, discItems, deviceItems = appendServerVisibleMatch(matches, container, source .. ":container", targetType)
            inspected = inspected + scanned
            vanillaContainers = vanillaContainers + c
            vanillaDiscItems = vanillaDiscItems + discItems
            vanillaDeviceItems = vanillaDeviceItems + deviceItems
        end
    end
    if object.getContainerCount and object.getContainerByIndex then
        for index = 0, object:getContainerCount() - 1 do
            local container = object:getContainerByIndex(index)
            if container and seen[container] ~= true then
                seen[container] = true
                local scanned, c, discItems, deviceItems = appendServerVisibleMatch(matches, container, source .. ":index" .. tostring(index), targetType)
                inspected = inspected + scanned
                vanillaContainers = vanillaContainers + c
                vanillaDiscItems = vanillaDiscItems + discItems
                vanillaDeviceItems = vanillaDeviceItems + deviceItems
            end
        end
    end
    return inspected, vanillaContainers, vanillaDiscItems, vanillaDeviceItems
end

local function repairObjectContainers(results, object, source, targetType, seen, args)
    if not object then
        return 0, 0, 0
    end
    local inspected = 0
    local repaired = 0
    local remaining = 0
    local function repairContainer(container, label)
        if not container or seen[container] == true then
            return
        end
        seen[container] = true
        local cType = containerTypeText(container)
        local typeMatches = targetType == "" or cType == targetType
        if typeMatches ~= true then
            return
        end
        inspected = inspected + 1
        local before = countVanillaMediaInContainer(container)
        if before.total < 1 then
            return
        end
        local routeClass = classifyFillRoute("", cType, container)
        local context = NMLootDebugHelpers
            and NMLootDebugHelpers.describeFullContainerContext
            and NMLootDebugHelpers.describeFullContainerContext("", cType, container, routeClass)
            or {
                roomName = "",
                containerType = cType,
                routeClass = routeClass,
                shape = tostring(container or "nil")
            }
        local delta = NMVanillaCDLootConverter.processContainer(container, context) or {}
        local after = countVanillaMediaInContainer(container)
        if before.total > after.total then
            repaired = repaired + 1
        end
        remaining = remaining + after.total
        local key = table.concat({
            tostring(args and args.x or ""),
            tostring(args and args.y or ""),
            tostring(args and args.z or ""),
            tostring(cType),
            tostring(label)
        }, "|")
        if shouldLogVisibleRepair(key) then
            results[#results + 1] = string.format(
                "source=%s type=%s routeClass=%s before={total=%d discs=%d devices=%d discNames={%s} deviceNames={%s}} delta={discObserved=%d discReplaced=%d discDiscarded=%d discFailed=%d deviceObserved=%d deviceReplaced=%d deviceDiscarded=%d deviceFailed=%d} after={total=%d discs=%d devices=%d}",
                tostring(label or source or ""),
                tostring(cType),
                tostring(routeClass),
                tonumber(before.total) or 0,
                tonumber(before.discs) or 0,
                tonumber(before.devices) or 0,
                tostring(before.discNames or ""),
                tostring(before.deviceNames or ""),
                tonumber(delta.observedVanillaCDs) or 0,
                tonumber(delta.replaced) or 0,
                tonumber(delta.discarded) or 0,
                tonumber(delta.failed) or 0,
                tonumber(delta.observedVanillaCDPlayers) or 0,
                tonumber(delta.cdPlayerReplaced) or 0,
                tonumber(delta.cdPlayerDiscarded) or 0,
                tonumber(delta.cdPlayerFailed) or 0,
                tonumber(after.total) or 0,
                tonumber(after.discs) or 0,
                tonumber(after.devices) or 0
            )
        end
    end
    if object.getContainer then
        repairContainer(object:getContainer(), source .. ":container")
    end
    if object.getContainerCount and object.getContainerByIndex then
        for index = 0, object:getContainerCount() - 1 do
            repairContainer(object:getContainerByIndex(index), source .. ":index" .. tostring(index))
        end
    end
    return inspected, repaired, remaining
end

function probe.repairVisibleVanillaMedia(player, args)
    local x = tonumber(args and args.x)
    local y = tonumber(args and args.y)
    local z = tonumber(args and args.z)
    if not (x and y and z and getCell) then
        logProbe("visible_vanilla_repair_attempt", "allowed=false reason=invalid_args")
        return false
    end
    if isVisibleRepairAllowed() ~= true then
        logProbe(
            "visible_vanilla_repair_attempt",
            string.format(
                "allowed=false reason=not_ready initialized=%s converterEnabled=%s clientSquare=%s,%s,%s",
                tostring(NMServerSandboxLootController and NMServerSandboxLootController.isSandboxLootApplied and NMServerSandboxLootController.isSandboxLootApplied() == true),
                tostring(NMVanillaCDLootConverter and NMVanillaCDLootConverter.isEnabled and NMVanillaCDLootConverter.isEnabled() == true),
                tostring(x),
                tostring(y),
                tostring(z)
            )
        )
        return false
    end
    local shouldRun, repairKey = shouldRunVisibleRepair(player, args)
    if shouldRun ~= true then
        logProbe(
            "visible_vanilla_repair_attempt",
            string.format(
                "allowed=false reason=throttled key=%s clientSquare=%s,%s,%s clientType=%s",
                tostring(repairKey or ""),
                tostring(x),
                tostring(y),
                tostring(z),
                tostring(args and args.containerType or "")
            )
        )
        return false
    end

    local square = getCell():getGridSquare(x, y, z)
    if not square then
        logProbe(
            "visible_vanilla_repair_attempt",
            string.format("allowed=false reason=square_missing clientSquare=%d,%d,%d", x, y, z)
        )
        return false
    end

    local targetType = tostring(args and args.containerType or "")
    local seen = {}
    local results = {}
    local inspectedContainers = 0
    local repairedContainers = 0
    local remainingVanillaItems = 0

    local objects = square.getObjects and square:getObjects() or nil
    if objects then
        for i = 0, objects:size() - 1 do
            local inspected, repaired, remaining = repairObjectContainers(results, objects:get(i), "object" .. tostring(i), targetType, seen, args)
            inspectedContainers = inspectedContainers + inspected
            repairedContainers = repairedContainers + repaired
            remainingVanillaItems = remainingVanillaItems + remaining
        end
    end
    local staticObjects = square.getStaticMovingObjects and square:getStaticMovingObjects() or nil
    if staticObjects then
        for i = 0, staticObjects:size() - 1 do
            local inspected, repaired, remaining = repairObjectContainers(results, staticObjects:get(i), "static" .. tostring(i), targetType, seen, args)
            inspectedContainers = inspectedContainers + inspected
            repairedContainers = repairedContainers + repaired
            remainingVanillaItems = remainingVanillaItems + remaining
        end
    end

    logProbe(
        "visible_vanilla_repair_attempt",
        string.format(
            "allowed=true player=%s clientSquare=%d,%d,%d clientType=%s clientCount=%s inspectedContainers=%d repairedContainers=%d remainingVanillaItems=%d details=[%s]",
            tostring(player and player.getUsername and player:getUsername() or "unknown"),
            x,
            y,
            z,
            tostring(targetType),
            tostring(args and args.count or ""),
            tonumber(inspectedContainers) or 0,
            tonumber(repairedContainers) or 0,
            tonumber(remainingVanillaItems) or 0,
            table.concat(results, " || ")
        )
    )
    return repairedContainers > 0
end

function probe.inspectClientVisibleVanillaDisc(player, args)
    if not shouldLog() then
        return false
    end
    local x = tonumber(args and args.x)
    local y = tonumber(args and args.y)
    local z = tonumber(args and args.z)
    if not (x and y and z and getCell) then
        logProbe("loot_probe.server_visible_vanilla_disc_check", "invalidArgs=true")
        return false
    end
    local square = getCell():getGridSquare(x, y, z)
    if not square then
        logProbe(
            "loot_probe.server_visible_vanilla_disc_check",
            string.format(
                "squareMissing=true clientSquare=%d,%d,%d clientType=%s clientCount=%s names={%s}",
                x,
                y,
                z,
                tostring(args and args.containerType or ""),
                tostring(args and args.count or ""),
                tostring(args and args.names or "")
            )
        )
        return false
    end

    local targetType = tostring(args and args.containerType or "")
    local seen = {}
    local matches = {}
    local inspectedContainers = 0
    local vanillaContainers = 0
    local vanillaDiscItems = 0
    local vanillaDeviceItems = 0

    local objects = square.getObjects and square:getObjects() or nil
    if objects then
        for i = 0, objects:size() - 1 do
            local scanned, c, discCount, deviceCount = inspectObjectContainers(matches, objects:get(i), "object" .. tostring(i), targetType, seen)
            inspectedContainers = inspectedContainers + scanned
            vanillaContainers = vanillaContainers + c
            vanillaDiscItems = vanillaDiscItems + discCount
            vanillaDeviceItems = vanillaDeviceItems + deviceCount
        end
    end
    local staticObjects = square.getStaticMovingObjects and square:getStaticMovingObjects() or nil
    if staticObjects then
        for i = 0, staticObjects:size() - 1 do
            local scanned, c, discCount, deviceCount = inspectObjectContainers(matches, staticObjects:get(i), "static" .. tostring(i), targetType, seen)
            inspectedContainers = inspectedContainers + scanned
            vanillaContainers = vanillaContainers + c
            vanillaDiscItems = vanillaDiscItems + discCount
            vanillaDeviceItems = vanillaDeviceItems + deviceCount
        end
    end

    logProbe(
        "loot_probe.server_visible_vanilla_disc_check",
        string.format(
            "clientSquare=%d,%d,%d clientPage=%s clientType=%s clientName=%s clientCount=%s clientDiscCount=%s clientDeviceCount=%s clientIds={%s} clientNames={%s} inspectedContainers=%d serverVanillaContainers=%d serverVanillaItems=%d serverVanillaDiscs=%d serverVanillaCDPlayers=%d matches=[%s]",
            x,
            y,
            z,
            tostring(args and args.page or ""),
            tostring(targetType),
            tostring(args and args.containerName or ""),
            tostring(args and args.count or ""),
            tostring(args and args.discCount or ""),
            tostring(args and args.deviceCount or ""),
            tostring(args and args.ids or ""),
            tostring(args and args.names or ""),
            tonumber(inspectedContainers) or 0,
            tonumber(vanillaContainers) or 0,
            (tonumber(vanillaDiscItems) or 0) + (tonumber(vanillaDeviceItems) or 0),
            tonumber(vanillaDiscItems) or 0,
            tonumber(vanillaDeviceItems) or 0,
            table.concat(matches, " || ")
        )
    )
    return true
end

return probe
