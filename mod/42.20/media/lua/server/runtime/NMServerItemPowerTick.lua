-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
-- Server minute tick for authoritative item battery drain in all item contexts.
NMServerItemPowerTick = NMServerItemPowerTick or {}
NMServerItemPowerTick.lastDrainMs = NMServerItemPowerTick.lastDrainMs or {}

local function markAuthoritativeMutation(state)
    if not state then
        return
    end
    NMDeviceState.bumpRevision(state)
    state.sourceGeneration = (tonumber(state.sourceGeneration) or 0) + 1
end

local function nowRealMs()
    if getTimestampMs then
        local ms = tonumber(getTimestampMs())
        if ms then return ms end
    end
    if getTimestamp then
        local ts = tonumber(getTimestamp())
        if ts then return ts * 1000 end
    end
    return 0
end

local function isBatteryProfile(profile)
    if not profile then
        return false
    end
    if profile.vehicleUsesCarBattery == true then
        return false
    end
    return profile.requiresBattery == true
end

local function resolveItemSourceMode(item, state)
    local mode = tostring(state and state.authoritativeMode or "")
    if mode ~= "" and mode ~= "off" then
        return mode
    end
    local worldItem = item and item.getWorldItem and item:getWorldItem() or nil
    if worldItem then
        return "placed"
    end
    return "inventory"
end

local function isWorldAuthoritativeMode(mode)
    local m = tostring(mode or "")
    return m == "attached" or m == "stowed" or m == "placed"
end

local function sendStateToPlayer(player, item, state, sourceMode)
    if not (player and item and state and sendServerCommand and NMCore and NMCore.NetModule) then
        return
    end
    sendServerCommand(player, NMCore.NetModule, "state", {
        itemId = tostring(item:getID() or ""),
        uuid = tostring(state.deviceUUID or ""),
        itemFullType = tostring(item:getFullType() or ""),
        sourceMode = tostring(sourceMode or resolveItemSourceMode(item, state)),
        state = NMDeviceState.export(state),
        serverSessionToken = NMServerBootReset and NMServerBootReset.getSessionToken and NMServerBootReset.getSessionToken() or nil
    })
end

local function applyItemDrain(kind, key, state, nowMsValue, drainSeconds, logExtra)
    local prevMs = tonumber(NMServerItemPowerTick.lastDrainMs[key])
    if not state.isOn then
        NMServerItemPowerTick.lastDrainMs[key] = nowMsValue
        return false, false
    end
    local oldCharge = NMCore.clamp(tonumber(state.batteryCharge) or 0.0, 0.0, 1.0)
    if not prevMs then
        NMServerItemPowerTick.lastDrainMs[key] = nowMsValue
        return false, false
    end

    local deltaSeconds = math.max(0, (nowMsValue - prevMs) / 1000.0)
    if deltaSeconds <= 0 then
        return false, false
    end

    local mutated, stopped, nextCharge = false, false, oldCharge
    if NMServerCanonicalReducer and NMServerCanonicalReducer.applyBatteryDelta then
        mutated, stopped, nextCharge = NMServerCanonicalReducer.applyBatteryDelta({
            eventType = NMServerCanonicalReducer.Event and NMServerCanonicalReducer.Event.TICK_BATTERY or "TICK_BATTERY",
            kind = kind,
            key = key,
            state = state,
            deltaSeconds = deltaSeconds,
            drainSeconds = drainSeconds,
            oldCharge = oldCharge,
            markMutation = markAuthoritativeMutation
        })
    else
        nextCharge = NMServerBatteryAuthority.computeNextCharge(oldCharge, deltaSeconds, drainSeconds)
        state.batteryCharge = nextCharge
        mutated = (nextCharge ~= oldCharge)
        if mutated then
            markAuthoritativeMutation(state)
        end
        if nextCharge <= 0 then
            state.batteryCharge = 0.0
            stopped = NMServerBatteryAuthority.forceStateOff(state, "battery_empty")
            if stopped and not mutated then
                markAuthoritativeMutation(state)
            end
            if stopped then
                local token = string.format("%s:%s", tostring(tonumber(state.playbackEpoch) or -1), tostring(tonumber(state.trackIndex) or -1))
                NMServerBatteryAuthority.logEmptyStop(kind, key, "battery_empty", token)
            end
            mutated = true
        end
    end
    NMServerItemPowerTick.lastDrainMs[key] = nowMsValue
    NMServerBatteryAuthority.logBatteryTick(kind, key, nowMsValue, prevMs, oldCharge, nextCharge, drainSeconds, logExtra)
    return mutated, stopped
end

local function claimMutationPath(seenMap, key, path)
    local uuid = tostring(key or "")
    if uuid == "" then
        return false
    end
    local existing = seenMap[uuid]
    if existing then
        if existing ~= path and NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
            local nowMsValue = nowRealMs()
            local shouldLog = true
            if NMCore.shouldLogEvery then
                shouldLog = NMCore.shouldLogEvery("runtimeProbe.batteryPathSkip." .. tostring(uuid), nowMsValue, 20000)
            end
            if shouldLog then
                NMCore.logChannel(
                    "runtime",
                    "server_battery_path_skip_duplicate",
                    string.format("uuid=%s existing=%s skipped=%s", tostring(uuid), tostring(existing), tostring(path))
                )
            end
        end
        return false
    end
    seenMap[uuid] = tostring(path or "unknown")
    return true
end

local function isOwnerOnlineForAttached(entry, state)
    local mode = tostring(state and state.authoritativeMode or entry and entry.sourceMode or "")
    if mode ~= "attached" then
        return true
    end
    local owner = tostring(state and state.sourceOwner or entry and entry.ownerOnlineId or entry and entry.ownerUsername or entry and entry.ownerId or "")
    if owner == "" then
        return false
    end
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if not players then
        return false
    end
    local ownerLower = string.lower(owner)
    for i = 0, players:size() - 1 do
        local p = players:get(i)
        if p then
            local onlineId = p.getOnlineID and tostring(p:getOnlineID() or "") or ""
            local username = p.getUsername and tostring(p:getUsername() or "") or ""
            if owner == onlineId or owner == username or ownerLower == string.lower(username) then
                return true
            end
        end
    end
    return false
end

local function processWorldRegistry(nowMsValue, drainSeconds, seenUuids)
    local world = NMServerRegistryState and NMServerRegistryState.worldRegistry or nil
    if type(world) ~= "table" then
        return
    end
    for uuid, entry in pairs(world) do
        local state = entry and entry.stateSnapshot or nil
        local profileType = entry and (entry.profileType or entry.itemFullType) or nil
        local profile = profileType and NMDeviceProfiles and NMDeviceProfiles.getForFullType and NMDeviceProfiles.getForFullType(profileType) or nil
        if state and isBatteryProfile(profile) then
            local key = tostring(uuid or state.deviceUUID or "")
            if claimMutationPath(seenUuids, key, "world") then
                local listenerEval = NMServerListenerEligibility and NMServerListenerEligibility.evaluate and NMServerListenerEligibility.evaluate(entry, state, profile) or nil
                local noListenerFreeze = listenerEval and listenerEval.shouldFreezeForNoListener == true
                if noListenerFreeze then
                    NMServerItemPowerTick.lastDrainMs[key] = nowMsValue
                    if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") and NMCore.shouldLogEvery then
                        local logKey = "runtimeProbe.batterySkipNoListener." .. tostring(key)
                        if NMCore.shouldLogEvery(logKey, nowMsValue, 5000) then
                            NMCore.logChannel(
                                "runtime",
                                "battery_tick_skipped_no_listener",
                                string.format("uuid=%s mode=%s", tostring(key), tostring(state.authoritativeMode or "unknown"))
                            )
                        end
                    end
                elseif entry._batteryDrainSkipUntilResume == true then
                    NMServerItemPowerTick.lastDrainMs[key] = nowMsValue
                    if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") and NMCore.shouldLogEvery then
                        local logKey = "runtimeProbe.batterySkipOffline." .. tostring(key)
                        if NMCore.shouldLogEvery(logKey, nowMsValue, 5000) then
                            NMCore.logChannel(
                                "runtime",
                                "battery_tick_skipped_offline_pause",
                                string.format("uuid=%s mode=%s", tostring(key), tostring(state.authoritativeMode or "unknown"))
                            )
                        end
                    end
                elseif not isOwnerOnlineForAttached(entry, state) then
                    NMServerItemPowerTick.lastDrainMs[key] = nowMsValue
                else
                    local updated = applyItemDrain("item_world", key, state, nowMsValue, drainSeconds, "mode=" .. tostring(state.authoritativeMode or "nil"))
                    if updated then
                        entry.stateSnapshot = NMDeviceState.export(state)
                        world[uuid] = entry
                    end
                end
            end
        end
    end
end

local function syncWorldSnapshotToInventoryItem(player, uuid, snapshot)
    if not (player and uuid and snapshot and NMInventoryHelpers and NMInventoryHelpers.findItemByUuid and NMDeviceState and NMDeviceState.peek) then
        return false
    end
    local inv = player.getInventory and player:getInventory() or nil
    if not inv then
        return false
    end
    local item = NMInventoryHelpers.findItemByUuid(inv, uuid)
    if not item then
        return false
    end
    local state = NMDeviceState.peek(item)
    if not state then
        return false
    end
    NMDeviceState.import(state, snapshot)
    return true
end

local function syncWorldSnapshotToAnyInventoryOwner(uuid, snapshot)
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if not players then
        return
    end
    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if syncWorldSnapshotToInventoryItem(player, uuid, snapshot) then
            return
        end
    end
end

local function processPlayerInventory(nowMsValue, drainSeconds, seenUuids)
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if not players then
        return
    end
    for i = 0, players:size() - 1 do
        local player = players:get(i)
        local inv = player and player.getInventory and player:getInventory() or nil
        if inv then
            local items = {}
            NMInventoryHelpers.collectItemsRecursive(inv, items)
            for j = 1, #items do
                local item = items[j]
                local profile = item and NMDeviceProfiles and NMDeviceProfiles.getForItem and NMDeviceProfiles.getForItem(item) or nil
                if isBatteryProfile(profile) then
                    local state = NMDeviceState.peek(item)
                    local key = tostring(state and state.deviceUUID or "")
                    if state and key ~= "" then
                        local worldEntry = NMServerRegistryState and NMServerRegistryState.worldRegistry and NMServerRegistryState.worldRegistry[key] or nil
                        local worldSnapshot = worldEntry and worldEntry.stateSnapshot or nil
                        local mode = tostring(state.authoritativeMode or "")
                        if isWorldAuthoritativeMode(mode) and type(worldSnapshot) ~= "table" then
                            -- World-capable authoritative modes never mutate through personal path.
                            NMServerItemPowerTick.lastDrainMs[key] = nowMsValue
                        elseif type(worldSnapshot) == "table" then
                            -- World entry is canonical when present; mirror it into inventory state and skip local drain.
                            NMDeviceState.import(state, worldSnapshot)
                            sendStateToPlayer(player, item, state, resolveItemSourceMode(item, state))
                            claimMutationPath(seenUuids, key, "world_mirror")
                        else
                            if claimMutationPath(seenUuids, key, "personal") then
                                local updated = applyItemDrain("item_personal", key, state, nowMsValue, drainSeconds, "mode=" .. tostring(resolveItemSourceMode(item, state)))
                                if updated then
                                    sendStateToPlayer(player, item, state, resolveItemSourceMode(item, state))
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

function NMServerItemPowerTick.onEveryOneMinute()
    if not (NMCore and NMCore.isMPServerAuthority and NMCore.isMPServerAuthority()) then
        return
    end
    local nowMsValue = nowRealMs()
    local drainSeconds = tonumber(NMRuntimeConfig.getBatteryDrainSecondsPortableFromSandbox and NMRuntimeConfig.getBatteryDrainSecondsPortableFromSandbox() or 86400) or 86400
    drainSeconds = math.max(1, drainSeconds)
    local seenUuids = {}

    processWorldRegistry(nowMsValue, drainSeconds, seenUuids)
    -- Keep inventory modData aligned to world canonical state to avoid battery/state forks.
    local world = NMServerRegistryState and NMServerRegistryState.worldRegistry or nil
    if type(world) == "table" then
        for uuid, entry in pairs(world) do
            if entry and type(entry.stateSnapshot) == "table" then
                syncWorldSnapshotToAnyInventoryOwner(tostring(uuid), entry.stateSnapshot)
            end
        end
    end
    processPlayerInventory(nowMsValue, drainSeconds, seenUuids)
end

