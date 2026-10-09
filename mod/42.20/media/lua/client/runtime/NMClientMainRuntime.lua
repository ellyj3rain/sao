-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
NMClientMainRuntime = NMClientMainRuntime or {}

local ACTIVE_LANE_INTERVAL_TICKS = 10
local PLAYBACK_FAST_LANE_INTERVAL_TICKS = 3
local SLOW_LANE_INTERVAL_TICKS = 30
local CLIENT_SCHEDULER_LOG_INTERVAL_MS = 5000
local CLIENT_WRAPPER_LOG_INTERVAL_MS = 5000
local CLIENT_UI_INVALIDATION_LOG_INTERVAL_MS = 5000

local tickWorkProbe = NMClientMainRuntime._tickWorkProbe or {
    tick = 0,
    lastLogMs = 0,
    stages = {}
}
local clientSchedulerDiag = NMClientMainRuntime._clientSchedulerDiag or {
    lastLogMs = 0,
    counters = {}
}
local clientWrapperDiag = NMClientMainRuntime._clientWrapperDiag or {
    lastLogMs = 0,
    counters = {}
}
local clientUiInvalidationDiag = NMClientMainRuntime._clientUiInvalidationDiag or {
    lastLogMs = 0,
    counters = {}
}
local clientPlayerMoveDiag = NMClientMainRuntime._clientPlayerMoveDiag or {
    lastLogMs = 0,
    counters = {}
}

NMClientMainRuntime._tickWorkProbe = tickWorkProbe
NMClientMainRuntime._clientSchedulerDiag = clientSchedulerDiag
NMClientMainRuntime._clientWrapperDiag = clientWrapperDiag
NMClientMainRuntime._clientUiInvalidationDiag = clientUiInvalidationDiag
NMClientMainRuntime._clientPlayerMoveDiag = clientPlayerMoveDiag
NMClientMainRuntime._tickHookInstalled = NMClientMainRuntime._tickHookInstalled == true
NMClientMainRuntime._playerMoveHookInstalled = NMClientMainRuntime._playerMoveHookInstalled == true
NMClientMainRuntime._playerMoveHookFn = NMClientMainRuntime._playerMoveHookFn
NMClientMainRuntime._vehicleSeatHookInstalled = NMClientMainRuntime._vehicleSeatHookInstalled == true
NMClientMainRuntime._radialHookRetryTick = tonumber(NMClientMainRuntime._radialHookRetryTick) or 0

local function nowRealMs()
    if getTimestampMs then
        local ms = tonumber(getTimestampMs())
        if ms then
            return ms
        end
    end
    if getTimestamp then
        local ts = tonumber(getTimestamp())
        if ts then
            return ts * 1000
        end
    end
    return 0
end

local function tickWorkProbeEnabled()
    return NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("memory") == true
end

local function beginTickStage(enabled)
    if enabled ~= true then
        return 0
    end
    return nowRealMs()
end

local function recordTickStage(enabled, name, startedMs)
    if enabled ~= true then
        return
    end
    local elapsedMs = math.max(0, nowRealMs() - (tonumber(startedMs) or 0))
    local key = tostring(name or "unknown")
    local stage = tickWorkProbe.stages[key]
    if not stage then
        stage = { count = 0, sumMs = 0, maxMs = 0 }
        tickWorkProbe.stages[key] = stage
    end
    stage.count = (tonumber(stage.count) or 0) + 1
    stage.sumMs = (tonumber(stage.sumMs) or 0) + elapsedMs
    stage.maxMs = math.max(tonumber(stage.maxMs) or 0, elapsedMs)
end

local function flushTickWorkProbe(enabled)
    if enabled ~= true or not (NMCore and NMCore.logChannel) then
        return
    end
    local nowMs = nowRealMs()
    if (nowMs - (tonumber(tickWorkProbe.lastLogMs) or 0)) < 5000 then
        return
    end
    tickWorkProbe.lastLogMs = nowMs
    local parts = {}
    for name, stage in pairs(tickWorkProbe.stages) do
        local count = tonumber(stage.count) or 0
        if count > 0 then
            parts[#parts + 1] = string.format(
                "%s=count:%d avgMs:%.3f maxMs:%.3f",
                tostring(name),
                count,
                (tonumber(stage.sumMs) or 0) / count,
                tonumber(stage.maxMs) or 0
            )
        end
        tickWorkProbe.stages[name] = nil
    end
    if #parts > 0 then
        NMCore.logChannel("memory", "client_tick_work", table.concat(parts, " | "))
    end
end

local function countSchedulerDiag(enabled, name)
    if enabled ~= true then
        return
    end
    local key = tostring(name or "unknown")
    clientSchedulerDiag.counters[key] = (tonumber(clientSchedulerDiag.counters[key]) or 0) + 1
end

local function countNamedDiag(enabled, state, name)
    if enabled ~= true or type(state) ~= "table" then
        return
    end
    local key = tostring(name or "unknown")
    state.counters[key] = (tonumber(state.counters[key]) or 0) + 1
end

local function flushNamedDiag(enabled, state, channel, intervalMs)
    if enabled ~= true or not (NMCore and NMCore.logChannel) or type(state) ~= "table" then
        return
    end
    local nowMs = nowRealMs()
    if (nowMs - (tonumber(state.lastLogMs) or 0)) < math.max(1, tonumber(intervalMs) or 0) then
        return
    end
    state.lastLogMs = nowMs
    local parts = {}
    for name, count in pairs(state.counters) do
        parts[#parts + 1] = string.format("%s=%d", tostring(name), tonumber(count) or 0)
        state.counters[name] = nil
    end
    if #parts > 0 then
        NMCore.logChannel("memory", tostring(channel or "client_diag"), table.concat(parts, " | "))
    end
end

local function flushSchedulerDiag(enabled)
    flushNamedDiag(enabled, clientSchedulerDiag, "client_tick_scheduler", CLIENT_SCHEDULER_LOG_INTERVAL_MS)
end

local function flushPlayerMoveDiag(enabled)
    flushNamedDiag(enabled, clientPlayerMoveDiag, "playback_player_move_diag", CLIENT_SCHEDULER_LOG_INTERVAL_MS)
end

local function isMPClientRuntime()
    return NMCore and NMCore.isMPClientRuntime and NMCore.isMPClientRuntime() == true
end

local function shouldRunCadence(interval)
    local tick = tonumber(tickWorkProbe.tick) or 0
    return interval > 0 and (tick % interval) == 0
end

local function shouldWakeForCadence(interval)
    local tick = tonumber(tickWorkProbe.tick) or 0
    local cadence = tonumber(interval) or 0
    if cadence <= 0 then
        return false
    end
    local remainder = tick % cadence
    return remainder == 0 or remainder == (cadence - 1)
end

local function maybeRetryRadialHooks(probeEnabled)
    NMClientMainRuntime._radialHookRetryTick = (tonumber(NMClientMainRuntime._radialHookRetryTick) or 0) + 1
    if (NMClientMainRuntime._radialHookRetryTick % 120) ~= 1 then
        return
    end
    if NMVehicleRadial and NMVehicleRadial.hookInstalled ~= true and not NMVehicleRadial.baseShowRadialMenu then
        countNamedDiag(probeEnabled, clientWrapperDiag, "vehicle_radial_install_attempt")
        NMVehicleRadial.installHook()
    end
    if NMGamepadRadial and NMGamepadRadial.hookInstalled ~= true and not NMGamepadRadial.baseOnDisplayDown then
        countNamedDiag(probeEnabled, clientWrapperDiag, "gamepad_radial_install_attempt")
        NMGamepadRadial.installHook()
    end
end

function NMClientMainRuntime.requestVisualRefresh(reason)
    local probeEnabled = tickWorkProbeEnabled()
    local normalizedReason = tostring(reason or "unknown")
    if NMClientMainRuntime.requestTickGateWake then
        NMClientMainRuntime.requestTickGateWake("visual_refresh_" .. normalizedReason)
    end
    countNamedDiag(probeEnabled, clientUiInvalidationDiag, "request_visual_refresh")
    countNamedDiag(probeEnabled, clientUiInvalidationDiag, "request_visual_refresh_" .. normalizedReason)
    if NMClientWorldItemVisualSanitizer and NMClientWorldItemVisualSanitizer.requestNearbySweep then
        NMClientWorldItemVisualSanitizer.requestNearbySweep(normalizedReason)
    end
    if NMClientInventoryItemVisualSanitizer and NMClientInventoryItemVisualSanitizer.requestSweep then
        NMClientInventoryItemVisualSanitizer.requestSweep(normalizedReason)
    end
end

function NMClientMainRuntime.markAuthorityRefresh(reason)
    if NMClientZombieVisualProbe and NMClientZombieVisualProbe.markAuthorityRefresh then
        NMClientZombieVisualProbe.markAuthorityRefresh(reason)
    end
end

function NMClientMainRuntime.requestTickGateWake(reason)
    if NMClientTickGate and NMClientTickGate.wake then
        NMClientTickGate.wake(reason)
    end
end

function NMClientMainRuntime.onPlayerMove(player)
    local probeEnabled = tickWorkProbeEnabled()
    countNamedDiag(probeEnabled, clientPlayerMoveDiag, "playback_player_move_event")
    local woke = false
    local wakeReason = "no_world_follow"
    if NMClientPlaybackTick and NMClientPlaybackTick.requestPlayerMoveWakeIfSettled then
        woke, wakeReason = NMClientPlaybackTick.requestPlayerMoveWakeIfSettled()
    end
    if woke == true then
        NMClientMainRuntime.requestTickGateWake("player_move")
        countNamedDiag(probeEnabled, clientPlayerMoveDiag, "playback_player_move_wake")
    elseif tostring(wakeReason or "") == "active" then
        countNamedDiag(probeEnabled, clientPlayerMoveDiag, "playback_player_move_ignored_active")
    else
        countNamedDiag(probeEnabled, clientPlayerMoveDiag, "playback_player_move_no_world_follow")
    end
    flushPlayerMoveDiag(probeEnabled)
end

local function installPlayerMoveHook()
    if NMClientMainRuntime._playerMoveHookInstalled == true
        and NMClientMainRuntime._playerMoveHookFn == NMClientMainRuntime.onPlayerMove then
        return
    end
    if Events and Events.OnPlayerMove and Events.OnPlayerMove.Remove and NMClientMainRuntime._playerMoveHookFn then
        Events.OnPlayerMove.Remove(NMClientMainRuntime._playerMoveHookFn)
    end
    if Events and Events.OnPlayerMove and Events.OnPlayerMove.Add then
        Events.OnPlayerMove.Add(NMClientMainRuntime.onPlayerMove)
        NMClientMainRuntime._playerMoveHookInstalled = true
        NMClientMainRuntime._playerMoveHookFn = NMClientMainRuntime.onPlayerMove
    end
end

local function reinstallPlayerMoveHook()
    if Events and Events.OnPlayerMove and Events.OnPlayerMove.Remove then
        Events.OnPlayerMove.Remove(NMClientMainRuntime._playerMoveHookFn or NMClientMainRuntime.onPlayerMove)
    end
    NMClientMainRuntime._playerMoveHookInstalled = false
    NMClientMainRuntime._playerMoveHookFn = nil
    installPlayerMoveHook()
end

local function isLocalVehicleSeatCharacter(character)
    local player = getPlayer and getPlayer() or nil
    if not (player and character) then
        return false
    end
    if player == character then
        return true
    end
    local playerNum = player.getPlayerNum and tonumber(player:getPlayerNum()) or nil
    local characterNum = character.getPlayerNum and tonumber(character:getPlayerNum()) or nil
    return playerNum ~= nil and characterNum ~= nil and playerNum == characterNum
end

local function handleVehicleSeatEvent(eventName, character)
    if isLocalVehicleSeatCharacter(character) ~= true then
        return
    end
    if NMClientPlaybackTick and NMClientPlaybackTick.observeVehicleSeatEvent then
        NMClientPlaybackTick.observeVehicleSeatEvent(eventName, character)
    elseif NMClientPlaybackTick and NMClientPlaybackTick.requestFullPass then
        NMClientPlaybackTick.requestFullPass("vehicle_seat_event_" .. tostring(eventName or "unknown"))
    end
    NMClientMainRuntime.requestTickGateWake("vehicle_seat_event")
end

function NMClientMainRuntime.onEnterVehicle(character)
    handleVehicleSeatEvent("enter", character)
end

function NMClientMainRuntime.onExitVehicle(character)
    handleVehicleSeatEvent("exit", character)
end

function NMClientMainRuntime.onSwitchVehicleSeat(character)
    handleVehicleSeatEvent("switch", character)
end

local function installVehicleSeatHooks()
    if NMClientMainRuntime._vehicleSeatHookInstalled == true then
        return
    end
    if Events and Events.OnEnterVehicle and Events.OnEnterVehicle.Add then
        Events.OnEnterVehicle.Add(NMClientMainRuntime.onEnterVehicle)
    end
    if Events and Events.OnExitVehicle and Events.OnExitVehicle.Add then
        Events.OnExitVehicle.Add(NMClientMainRuntime.onExitVehicle)
    end
    if Events and Events.OnSwitchVehicleSeat and Events.OnSwitchVehicleSeat.Add then
        Events.OnSwitchVehicleSeat.Add(NMClientMainRuntime.onSwitchVehicleSeat)
    end
    NMClientMainRuntime._vehicleSeatHookInstalled = true
end

local function reinstallVehicleSeatHooks()
    if Events and Events.OnEnterVehicle and Events.OnEnterVehicle.Remove then
        Events.OnEnterVehicle.Remove(NMClientMainRuntime.onEnterVehicle)
    end
    if Events and Events.OnExitVehicle and Events.OnExitVehicle.Remove then
        Events.OnExitVehicle.Remove(NMClientMainRuntime.onExitVehicle)
    end
    if Events and Events.OnSwitchVehicleSeat and Events.OnSwitchVehicleSeat.Remove then
        Events.OnSwitchVehicleSeat.Remove(NMClientMainRuntime.onSwitchVehicleSeat)
    end
    NMClientMainRuntime._vehicleSeatHookInstalled = false
    installVehicleSeatHooks()
end

function NMClientMainRuntime.getCurrentSchedulerTick()
    return tonumber(tickWorkProbe.tick) or 0
end

local function hasPendingWindowRestore()
    return (NMWalkmanWindow and NMWalkmanWindow.hasPendingPersistedRestore and NMWalkmanWindow.hasPendingPersistedRestore())
        or (NMCDPlayerWindow and NMCDPlayerWindow.hasPendingPersistedRestore and NMCDPlayerWindow.hasPendingPersistedRestore())
        or (NMBoomboxWindow and NMBoomboxWindow.hasPendingPersistedRestore and NMBoomboxWindow.hasPendingPersistedRestore())
end

local function shouldRunSlowLane()
    if shouldRunCadence(SLOW_LANE_INTERVAL_TICKS) then
        return true
    end
    return hasPendingWindowRestore()
        or (NMClientWorldItemVisualSanitizer and NMClientWorldItemVisualSanitizer.hasPendingWork and NMClientWorldItemVisualSanitizer.hasPendingWork())
        or (NMClientInventoryItemVisualSanitizer and NMClientInventoryItemVisualSanitizer.hasPendingWork and NMClientInventoryItemVisualSanitizer.hasPendingWork())
end

local function hasZombieCachePendingWork()
    return NMClientZombieVisualTargetCache
        and NMClientZombieVisualTargetCache.hasPendingWork
        and NMClientZombieVisualTargetCache.hasPendingWork() == true
end

function NMClientMainRuntime.advanceSchedulerTick(tickStep)
    local step = math.max(1, tonumber(tickStep) or 1)
    tickWorkProbe.tick = (tonumber(tickWorkProbe.tick) or 0) + step
    if NMClientPlaybackTick and NMClientPlaybackTick.observeSchedulerTick then
        NMClientPlaybackTick.observeSchedulerTick(step)
    end
    if NMClientZombieVisualProbe and NMClientZombieVisualProbe.observeSchedulerTick then
        NMClientZombieVisualProbe.observeSchedulerTick(step)
    end
    if NMClientRegistrySync and NMClientRegistrySync.observeSchedulerTick then
        NMClientRegistrySync.observeSchedulerTick(step)
    end
end

local function getNextCadenceTick(interval)
    local currentTick = tonumber(tickWorkProbe.tick) or 0
    local cadence = tonumber(interval) or 0
    if cadence <= 0 then
        return math.huge
    end
    local remainder = currentTick % cadence
    if remainder == 0 then
        return currentTick
    end
    return currentTick + (cadence - remainder)
end

local function getNextZombieMaintenanceRunnableTick()
    if not (NMClientZombieVisualProbe and NMClientZombieVisualProbe.getNextMaintenanceCheckTick) then
        return math.huge
    end
    local maintenanceTick = tonumber(NMClientZombieVisualProbe.getNextMaintenanceCheckTick()) or math.huge
    if maintenanceTick == math.huge then
        return math.huge
    end
    return math.max(maintenanceTick, getNextCadenceTick(SLOW_LANE_INTERVAL_TICKS))
end

function NMClientMainRuntime.getNextTickGateWakeTick()
    local currentTick = tonumber(tickWorkProbe.tick) or 0
    if NMClientMainRuntime.isTickHookInstalled and NMClientMainRuntime.isTickHookInstalled() == true then
        return currentTick + 1
    end
    if hasPendingWindowRestore() == true
        or (NMClientWorldItemVisualSanitizer and NMClientWorldItemVisualSanitizer.hasPendingWork and NMClientWorldItemVisualSanitizer.hasPendingWork() == true)
        or (NMClientInventoryItemVisualSanitizer and NMClientInventoryItemVisualSanitizer.hasPendingWork and NMClientInventoryItemVisualSanitizer.hasPendingWork() == true)
        or (NMClientPortableUiDragBlockProbe and NMClientPortableUiDragBlockProbe.hasPendingWork and NMClientPortableUiDragBlockProbe.hasPendingWork() == true) then
        return currentTick + 1
    end

    local nextWakeTick = math.huge
    if isMPClientRuntime() == true then
        if NMClientRegistrySync and NMClientRegistrySync.shouldRunThisTick and NMClientRegistrySync.shouldRunThisTick() == true then
            nextWakeTick = math.min(nextWakeTick, currentTick)
        elseif NMClientRegistrySync and NMClientRegistrySync.getNextRunTick then
            nextWakeTick = math.min(nextWakeTick, tonumber(NMClientRegistrySync.getNextRunTick()) or math.huge)
        end
    end
    if NMClientPlaybackTick and NMClientPlaybackTick.getNextPlaybackWorkTick then
        nextWakeTick = math.min(nextWakeTick, tonumber(NMClientPlaybackTick.getNextPlaybackWorkTick(getPlayer and getPlayer() or nil)) or math.huge)
    elseif NMClientPlaybackTick and NMClientPlaybackTick.getNextManagedInventoryCheckTick then
        nextWakeTick = math.min(nextWakeTick, tonumber(NMClientPlaybackTick.getNextManagedInventoryCheckTick()) or math.huge)
    end
    if NMClientZombieVisualProbe and NMClientZombieVisualProbe.getNextMaintenanceCheckTick then
        nextWakeTick = math.min(nextWakeTick, getNextZombieMaintenanceRunnableTick())
    else
        nextWakeTick = math.min(nextWakeTick, currentTick + 1)
    end
    if hasZombieCachePendingWork() == true then
        nextWakeTick = math.min(nextWakeTick, getNextCadenceTick(SLOW_LANE_INTERVAL_TICKS))
    end
    if nextWakeTick == math.huge then
        return math.huge
    end
    return math.max(currentTick, nextWakeTick)
end

function NMClientMainRuntime.hasAnyTickWork()
    local player = getPlayer and getPlayer() or nil
    local playbackInterested = false
    local playbackReason = "idle"
    if NMClientPlaybackTick and NMClientPlaybackTick.isPlaybackWorkDue then
        local due, reason = NMClientPlaybackTick.isPlaybackWorkDue(player, true)
        playbackInterested = due == true
        playbackReason = tostring(reason or "idle")
    elseif NMClientPlaybackTick and NMClientPlaybackTick.hasInterest then
        playbackInterested = NMClientPlaybackTick.hasInterest() == true
        playbackReason = playbackInterested and "legacy_playback_interest" or "idle"
    end
    local slowLaneDue = shouldRunSlowLane()
    local zombieActiveInterested = NMClientZombieVisualProbe and NMClientZombieVisualProbe.hasPendingWork and NMClientZombieVisualProbe.hasPendingWork(player) == true
    local zombieMaintenanceDue = slowLaneDue == true
        and NMClientZombieVisualProbe
        and NMClientZombieVisualProbe.shouldRunMaintenance
        and NMClientZombieVisualProbe.shouldRunMaintenance() == true
    local uiDragInterested = NMClientPortableUiDragBlockProbe and NMClientPortableUiDragBlockProbe.hasPendingWork and NMClientPortableUiDragBlockProbe.hasPendingWork() == true
    local windowRestorePending = hasPendingWindowRestore() == true
    local registrySyncDue = isMPClientRuntime()
        and NMClientRegistrySync
        and NMClientRegistrySync.shouldRunThisTick
        and NMClientRegistrySync.shouldRunThisTick() == true
    local zombieCachePending = hasZombieCachePendingWork() == true and shouldWakeForCadence(SLOW_LANE_INTERVAL_TICKS)
    if playbackInterested then
        return true, "playback_interest"
    end
    if zombieActiveInterested then
        return true, "zombie_interest"
    end
    if zombieMaintenanceDue then
        return true, "zombie_maintenance_due"
    end
    if uiDragInterested then
        return true, "ui_drag_interest"
    end
    if windowRestorePending then
        return true, "window_restore_pending"
    end
    if registrySyncDue then
        return true, "registry_sync_due"
    end
    if zombieCachePending then
        return true, "zombie_cache_pending"
    end
    return false, "idle"
end

function NMClientMainRuntime.isTickHookInstalled()
    return NMClientMainRuntime._tickHookInstalled == true
end

function NMClientMainRuntime.installTickHook()
    if NMClientMainRuntime._tickHookInstalled == true then
        return
    end
    if Events and Events.OnTick and Events.OnTick.Add then
        Events.OnTick.Add(NMClientMainRuntime.onTick)
        NMClientMainRuntime._tickHookInstalled = true
    end
end

function NMClientMainRuntime.removeTickHook()
    if NMClientMainRuntime._tickHookInstalled ~= true then
        return
    end
    if Events and Events.OnTick and Events.OnTick.Remove then
        Events.OnTick.Remove(NMClientMainRuntime.onTick)
        NMClientMainRuntime._tickHookInstalled = false
    end
end

local function shouldKeepClientTickGateRegistered()
    if NMClientPlaybackTick
        and NMClientPlaybackTick.hasColdManagedInventoryDeadline
        and NMClientPlaybackTick.hasColdManagedInventoryDeadline() == true then
        return true
    end
    local nextWakeTick = NMClientMainRuntime.getNextTickGateWakeTick
        and tonumber(NMClientMainRuntime.getNextTickGateWakeTick())
        or math.huge
    return nextWakeTick < math.huge
end

local function runStage(enabled, name, fn)
    local stageStartedMs = beginTickStage(enabled)
    fn()
    recordTickStage(enabled, name, stageStartedMs)
end

local function runWindowRestoreStages(probeEnabled)
    if NMWalkmanWindow and NMWalkmanWindow.tickPersistedRestore and NMWalkmanWindow.hasPendingPersistedRestore and NMWalkmanWindow.hasPendingPersistedRestore() then
        runStage(probeEnabled, "walkman_restore", NMWalkmanWindow.tickPersistedRestore)
    end
    if NMCDPlayerWindow and NMCDPlayerWindow.tickPersistedRestore and NMCDPlayerWindow.hasPendingPersistedRestore and NMCDPlayerWindow.hasPendingPersistedRestore() then
        runStage(probeEnabled, "cdplayer_restore", NMCDPlayerWindow.tickPersistedRestore)
    end
    if NMBoomboxWindow and NMBoomboxWindow.tickPersistedRestore and NMBoomboxWindow.hasPendingPersistedRestore and NMBoomboxWindow.hasPendingPersistedRestore() then
        runStage(probeEnabled, "boombox_restore", NMBoomboxWindow.tickPersistedRestore)
    end
end

local function runVisualSanitizerStages(probeEnabled, player)
    if NMClientWorldItemVisualSanitizer and NMClientWorldItemVisualSanitizer.runPendingRetries and NMClientWorldItemVisualSanitizer.hasPendingWork and NMClientWorldItemVisualSanitizer.hasPendingWork() then
        runStage(probeEnabled, "world_visual_retries", NMClientWorldItemVisualSanitizer.runPendingRetries)
        runStage(probeEnabled, "world_visual_sweep", function()
            NMClientWorldItemVisualSanitizer.runNearbySweep(player)
        end)
    end
    if NMClientInventoryItemVisualSanitizer and NMClientInventoryItemVisualSanitizer.runInventorySweep and NMClientInventoryItemVisualSanitizer.hasPendingWork and NMClientInventoryItemVisualSanitizer.hasPendingWork() then
        runStage(probeEnabled, "inventory_visual", function()
            NMClientInventoryItemVisualSanitizer.runInventorySweep(player, "scheduled_inventory_sweep")
        end)
    end
end

local function buildTickContext(probeEnabled)
    local player = getPlayer and getPlayer() or nil
    local playbackInterested = false
    local playbackReason = "idle"
    local playbackStatus = nil
    if NMClientPlaybackTick and NMClientPlaybackTick.isPlaybackWorkDue then
        local due, reason, status = NMClientPlaybackTick.isPlaybackWorkDue(player, true)
        playbackInterested = due == true
        playbackReason = tostring(reason or "idle")
        playbackStatus = status
    elseif NMClientPlaybackTick and NMClientPlaybackTick.hasInterest then
        playbackInterested = NMClientPlaybackTick.hasInterest() == true
        playbackReason = playbackInterested and "legacy_playback_interest" or "idle"
    end
    local slowLaneDue = shouldRunSlowLane()
    local playbackFastLaneDue = shouldRunCadence(PLAYBACK_FAST_LANE_INTERVAL_TICKS)
    if type(playbackStatus) == "table" then
        playbackFastLaneDue = playbackStatus.fastLanePositionDue == true
    end
    local context = {
        probeEnabled = probeEnabled,
        player = player,
        isMpRuntime = isMPClientRuntime(),
        activeLaneDue = shouldRunCadence(ACTIVE_LANE_INTERVAL_TICKS),
        playbackFastLaneDue = playbackFastLaneDue,
        slowLaneDue = slowLaneDue,
        playbackInterested = playbackInterested,
        playbackReason = playbackReason,
        playbackStatus = playbackStatus,
        zombieActiveInterested = NMClientZombieVisualProbe and NMClientZombieVisualProbe.hasPendingWork and NMClientZombieVisualProbe.hasPendingWork(player) == true,
        zombieMaintenanceDue = slowLaneDue == true
            and NMClientZombieVisualProbe
            and NMClientZombieVisualProbe.shouldRunMaintenance
            and NMClientZombieVisualProbe.shouldRunMaintenance() == true,
        uiDragInterested = NMClientPortableUiDragBlockProbe and NMClientPortableUiDragBlockProbe.hasPendingWork and NMClientPortableUiDragBlockProbe.hasPendingWork() == true
    }
    context.activeLaneInterested = context.zombieActiveInterested or context.uiDragInterested
    return context
end

local function recordWrapperPrepass(context)
    local probeEnabled = context.probeEnabled
    countNamedDiag(probeEnabled, clientWrapperDiag, "wrapper_tick")
    countNamedDiag(probeEnabled, clientWrapperDiag, context.activeLaneDue and "active_lane_due" or "active_lane_not_due")
    countNamedDiag(probeEnabled, clientWrapperDiag, context.slowLaneDue and "slow_lane_due" or "slow_lane_not_due")
    countNamedDiag(probeEnabled, clientWrapperDiag, context.playbackInterested and "playback_interest" or "playback_idle")
    if context.playbackInterested == true then
        countNamedDiag(probeEnabled, clientWrapperDiag, tostring(context.playbackReason or "playback_due"))
    elseif tostring(context.playbackReason or "") == "playback_active_cold_until" then
        countNamedDiag(probeEnabled, clientWrapperDiag, "playback_active_cold_until")
        countNamedDiag(probeEnabled, clientWrapperDiag, "playback_active_deadline_skip")
    end
    countNamedDiag(probeEnabled, clientWrapperDiag, context.zombieActiveInterested and "zombie_interest" or "zombie_idle")
    countNamedDiag(probeEnabled, clientWrapperDiag, context.zombieMaintenanceDue and "zombie_maintenance_due" or "zombie_maintenance_idle")
    countNamedDiag(probeEnabled, clientWrapperDiag, context.uiDragInterested and "ui_drag_interest" or "ui_drag_idle")
    countNamedDiag(probeEnabled, clientWrapperDiag, context.activeLaneInterested and "active_lane_interest" or "active_lane_cold")
end

local function runRegistryTickSlice(context)
    local probeEnabled = context.probeEnabled
    if context.isMpRuntime ~= true then
        countNamedDiag(probeEnabled, clientWrapperDiag, "sp_registry_branch")
        countSchedulerDiag(probeEnabled, "registry_sync_skip_sp")
        return
    end

    local registryDue = false
    if NMClientRegistrySync and NMClientRegistrySync.shouldRunThisTick then
        registryDue = NMClientRegistrySync.shouldRunThisTick()
    end
    countNamedDiag(probeEnabled, clientWrapperDiag, registryDue and "mp_registry_due" or "mp_registry_not_due")
    countSchedulerDiag(probeEnabled, registryDue and "registry_sync_due" or "registry_sync_skip")
    if registryDue == true and NMClientRegistrySync and NMClientRegistrySync.onTick then
        countSchedulerDiag(probeEnabled, "registry_sync_run")
        runStage(probeEnabled, "registry_sync", function()
            NMClientRegistrySync.onTick(context.player)
        end)
    end
end

local function runPlaybackTickSlice(context)
    local probeEnabled = context.probeEnabled
    if context.playbackInterested ~= true then
        if NMClientPlaybackTick and NMClientPlaybackTick.onTick then
            countSchedulerDiag(probeEnabled, "playback_skip_no_interest")
        elseif NMCore and NMCore.logChannel then
            NMCore.logChannel("core", "client_playback_tick_missing", "NMClientPlaybackTick.onTick=nil")
        end
        return
    end

    if not (NMClientPlaybackTick and NMClientPlaybackTick.onTick) then
        if NMCore and NMCore.logChannel then
            NMCore.logChannel("core", "client_playback_tick_missing", "NMClientPlaybackTick.onTick=nil")
        end
        return
    end

    local playbackDecision = NMClientPlaybackTick.getSchedulingDecision and NMClientPlaybackTick.getSchedulingDecision(context.player, context.playbackStatus) or nil
    local ranPlayback = false
    local ranPlaybackFull = false
    if playbackDecision and playbackDecision.forcedFull == true then
        countSchedulerDiag(probeEnabled, "playback_forced_full")
        local playbackStartedMs = beginTickStage(probeEnabled)
        NMClientPlaybackTick.onTick(context.player, 1, "full")
        recordTickStage(probeEnabled, "playback", playbackStartedMs)
        recordTickStage(probeEnabled, "playback_full", playbackStartedMs)
        ranPlayback = true
        ranPlaybackFull = true
    elseif context.activeLaneDue and playbackDecision and playbackDecision.fullDue == true then
        countSchedulerDiag(probeEnabled, "playback_active_lane_full")
        local playbackStartedMs = beginTickStage(probeEnabled)
        NMClientPlaybackTick.onTick(context.player, ACTIVE_LANE_INTERVAL_TICKS, "full")
        recordTickStage(probeEnabled, "playback", playbackStartedMs)
        recordTickStage(probeEnabled, "playback_full", playbackStartedMs)
        ranPlayback = true
        ranPlaybackFull = true
    end

    if ranPlaybackFull ~= true and playbackDecision and playbackDecision.runTrackMonitor == true then
        countSchedulerDiag(probeEnabled, "playback_track_monitor")
        local playbackStartedMs = beginTickStage(probeEnabled)
        NMClientPlaybackTick.onTick(context.player, ACTIVE_LANE_INTERVAL_TICKS, "track_monitor")
        recordTickStage(probeEnabled, "playback", playbackStartedMs)
        recordTickStage(probeEnabled, "playback_track_monitor", playbackStartedMs)
        ranPlayback = true
    end

    if ranPlaybackFull ~= true and ranPlayback ~= true and context.playbackFastLaneDue and playbackDecision and playbackDecision.runFastLanePosition == true then
        countSchedulerDiag(probeEnabled, "playback_fast_lane")
        local playbackStartedMs = beginTickStage(probeEnabled)
        NMClientPlaybackTick.onTick(context.player, PLAYBACK_FAST_LANE_INTERVAL_TICKS, "position_fast_lane")
        recordTickStage(probeEnabled, "playback", playbackStartedMs)
        recordTickStage(probeEnabled, "playback_fast_position", playbackStartedMs)
        ranPlayback = true
    end

    if ranPlayback ~= true then
        if playbackDecision and playbackDecision.runStableActive == true then
            countSchedulerDiag(probeEnabled, "playback_skip_stable")
        else
            countSchedulerDiag(probeEnabled, "playback_skip_idle")
        end
    end
end

local function runActiveLaneSlice(context)
    local probeEnabled = context.probeEnabled
    local activeWrapperStartedMs = beginTickStage(probeEnabled)
    if context.activeLaneDue and context.activeLaneInterested then
        countSchedulerDiag(probeEnabled, "active_lane_run")
        countNamedDiag(probeEnabled, clientWrapperDiag, "active_lane_body_entered")
        if context.zombieActiveInterested and NMClientZombieVisualProbe and NMClientZombieVisualProbe.onTick then
            runStage(probeEnabled, "zombie_visual", function()
                NMClientZombieVisualProbe.onTick(context.player, ACTIVE_LANE_INTERVAL_TICKS)
            end)
        else
            countSchedulerDiag(probeEnabled, "zombie_visual_skip")
        end
        if context.uiDragInterested and NMClientPortableUiDragBlockProbe and NMClientPortableUiDragBlockProbe.onTick then
            runStage(probeEnabled, "ui_drag_probe", NMClientPortableUiDragBlockProbe.onTick)
        else
            countSchedulerDiag(probeEnabled, "ui_drag_probe_skip")
        end
    else
        countSchedulerDiag(probeEnabled, "active_lane_skip")
        countNamedDiag(probeEnabled, clientWrapperDiag, "active_lane_body_skipped")
    end
    recordTickStage(probeEnabled, "client_wrapper_active", activeWrapperStartedMs)
end

local function runSlowLaneSlice(context)
    local probeEnabled = context.probeEnabled
    local slowWrapperStartedMs = beginTickStage(probeEnabled)
    if context.slowLaneDue then
        countSchedulerDiag(probeEnabled, "slow_lane_run")
        countNamedDiag(probeEnabled, clientWrapperDiag, "slow_lane_body_entered")
        runWindowRestoreStages(probeEnabled)
        runVisualSanitizerStages(probeEnabled, context.player)
        if context.zombieActiveInterested ~= true and context.zombieMaintenanceDue == true and NMClientZombieVisualProbe and NMClientZombieVisualProbe.onTick then
            runStage(probeEnabled, "zombie_visual_maintenance", function()
                NMClientZombieVisualProbe.onTick(context.player, SLOW_LANE_INTERVAL_TICKS)
            end)
        end
        if NMClientZombieVisualTargetCache and NMClientZombieVisualTargetCache.onTick and NMClientZombieVisualTargetCache.hasPendingWork and NMClientZombieVisualTargetCache.hasPendingWork() then
            runStage(probeEnabled, "zombie_cache", function()
                NMClientZombieVisualTargetCache.onTick(SLOW_LANE_INTERVAL_TICKS)
            end)
        else
            countSchedulerDiag(probeEnabled, "zombie_cache_skip")
        end
    else
        countSchedulerDiag(probeEnabled, "slow_lane_skip")
        countNamedDiag(probeEnabled, clientWrapperDiag, "slow_lane_body_skipped")
    end
    recordTickStage(probeEnabled, "client_wrapper_slow", slowWrapperStartedMs)
end

local function flushTickDiagnostics(probeEnabled)
    flushTickWorkProbe(probeEnabled)
    flushSchedulerDiag(probeEnabled)
    flushNamedDiag(probeEnabled, clientWrapperDiag, "client_tick_wrapper", CLIENT_WRAPPER_LOG_INTERVAL_MS)
    flushNamedDiag(probeEnabled, clientUiInvalidationDiag, "client_ui_invalidation_diag", CLIENT_UI_INVALIDATION_LOG_INTERVAL_MS)
    countNamedDiag(
        probeEnabled,
        clientPlayerMoveDiag,
        NMClientMainRuntime._playerMoveHookInstalled == true and "playback_player_move_hook_installed" or "playback_player_move_hook_unavailable"
    )
    flushPlayerMoveDiag(probeEnabled)
end

function NMClientMainRuntime.onTick()
    local probeEnabled = tickWorkProbeEnabled()
    local wrapperPreStartedMs = beginTickStage(probeEnabled)
    local context = buildTickContext(probeEnabled)
    recordWrapperPrepass(context)
    maybeRetryRadialHooks(probeEnabled)
    recordTickStage(probeEnabled, "client_wrapper_pre", wrapperPreStartedMs)
    runRegistryTickSlice(context)
    runPlaybackTickSlice(context)
    runActiveLaneSlice(context)
    runSlowLaneSlice(context)
    flushTickDiagnostics(probeEnabled)
end

function NMClientMainRuntime.onServerCommand(module, command, args)
    if module == NMCore.NetModule then
        if NMClientZombieVisualTargetCache and NMClientZombieVisualTargetCache.onServerCommand and NMClientZombieVisualTargetCache.onServerCommand(command, args) == true then
            return
        end
        if NMClientSessionProjection and NMClientSessionProjection.observeServerSessionToken then
            NMClientSessionProjection.observeServerSessionToken(args and args.serverSessionToken, command)
        end
        NMClientRegistrySync.onServerCommand(command, args)
        if command == "state" then
            local player = getPlayer and getPlayer() or nil
            NMClientStateSync.onServerState(player, args)
            NMClientMainRuntime.requestVisualRefresh("server_state")
            if NMClientPlaybackTick and NMClientPlaybackTick.markDirty then
                NMClientPlaybackTick.markDirty("server_state")
            end
            NMClientMainRuntime.markAuthorityRefresh("server_state")
        end
        if command == "vehicle_loot_stale_reject" then
            NMClientStateSync.onVehicleLootStaleReject(args or {})
            NMClientMainRuntime.requestVisualRefresh("vehicle_loot_stale_reject")
            if NMClientPlaybackTick and NMClientPlaybackTick.markDirty then
                NMClientPlaybackTick.markDirty("vehicle_loot_stale_reject")
            end
        end
        if command == "debug_sync" then
            local enabled = args and args.enabled == true
            local subsystem = tostring(args and args.subsystem or "")
            NMCore.setSubsystemDebugEnabled(subsystem, enabled)
            if NMCore and NMCore.logChannel then
                NMCore.logChannel("core", "debug_sync_applied", "enabled=" .. tostring(enabled) .. " subsystem=" .. tostring(subsystem))
                NMCore.logChannel(
                    "core",
                    "client_debug_sync",
                    string.format(
                        "enabled=%s subsystem=%s authority=%s",
                        tostring(enabled),
                        tostring(subsystem),
                        tostring(NMCore.getRuntimeAuthorityMode and NMCore.getRuntimeAuthorityMode() or "unknown")
                    )
                )
                if NMCore.dumpDebugState then
                    NMCore.dumpDebugState()
                end
            end
        end
        if command == "registry_update" and args and args.op and args.payload then
            NMClientWorldSourceCache.onRegistryUpdate(args.op, args.payload, args.serverSessionToken)
            if NMClientPlaybackTick and NMClientPlaybackTick.requestFullPass then
                NMClientPlaybackTick.requestFullPass("registry_update")
            end
            NMClientMainRuntime.requestVisualRefresh("registry_update")
            NMClientMainRuntime.markAuthorityRefresh("registry_update")
        end
        if command == "registry_snapshot_chunk" and args then
            NMClientWorldSourceCache.onRegistrySnapshotChunk(args)
            if NMClientPlaybackTick and NMClientPlaybackTick.requestFullPass then
                NMClientPlaybackTick.requestFullPass("registry_snapshot_chunk")
            end
            NMClientMainRuntime.requestVisualRefresh("registry_snapshot_chunk")
            NMClientMainRuntime.markAuthorityRefresh("registry_snapshot_chunk")
        end
        if command == "media_flip_result" then
            local player = getPlayer and getPlayer() or nil
            if NMContextMenus and NMContextMenus.onMediaFlipResult then
                NMContextMenus.onMediaFlipResult(player, args or {})
            end
        end
    end
    if NMDevicesClient.onServerCommand then
        NMDevicesClient.onServerCommand(module, command, args)
    end
end

function NMClientMainRuntime.onGameStart()
    NMClientMainRuntime.requestTickGateWake("on_game_start")
    reinstallPlayerMoveHook()
    reinstallVehicleSeatHooks()
    if NMClientPortableUiDragBlockProbe and NMClientPortableUiDragBlockProbe.onGameStart then
        NMClientPortableUiDragBlockProbe.onGameStart()
    end
    if NMClientSessionProjection and NMClientSessionProjection.onGameStart then
        NMClientSessionProjection.onGameStart()
    end
    if NMDeviceUI and NMDeviceUI.beginSessionStartAutoOpenSuppression then
        NMDeviceUI.beginSessionStartAutoOpenSuppression(0, "on_game_start")
    end
    NMClientRegistrySync.requestInitialSync()
    if not NMCore.isMPClientRuntime() then
        local player = getPlayer and getPlayer() or nil
        if player then
            local seeded = NMWorldRegistrySnapshot.seedCacheForPlayerSP(player, function(entry)
                if not entry or not entry.state then
                    return false
                end
                local sourceMode = tostring(entry.sourceMode or ((entry.kind == "vehicle") and "vehicle" or "placed"))
                local profileType = tostring(entry.profileType or ((entry.kind == "vehicle") and "vehicle_radio" or entry.itemFullType or ""))
                NMClientWorldSourceCache.upsertFromPayload({
                    kind = tostring(entry.kind or "item"),
                    uuid = tostring(entry.uuid or ""),
                    profileType = profileType ~= "" and profileType or nil,
                    sourceMode = sourceMode,
                    x = tonumber(entry.x) or 0,
                    y = tonumber(entry.y) or 0,
                    z = tonumber(entry.z) or 0,
                    sourceEpoch = tonumber(entry.sourceEpoch) or tonumber(entry.state.sourceGeneration) or 0,
                    itemId = entry.itemId,
                    itemFullType = entry.itemFullType,
                    vehicleId = entry.vehicleId,
                    vehicleIdHint = entry.vehicleIdHint,
                    vehicleSqlId = entry.vehicleSqlId,
                    vehicleSqlIdHint = entry.vehicleSqlIdHint,
                    partId = entry.partId,
                    windowsOpen = entry.windowsOpen == true,
                    state = entry.state
                })
                return true
            end)
            if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("core") then
                NMCore.logChannel("core", "sp_snapshot_seed", "seeded=" .. tostring(seeded or 0))
            end
        end
    end
    NMVehicleRadial.installHook()
    if NMGamepadRadial and NMGamepadRadial.installHook then
        NMGamepadRadial.installHook()
    end
    if NMDevicesClient.onGameStart then
        NMDevicesClient.onGameStart()
    end
    if NMClientPlaybackTick and NMClientPlaybackTick.beginStartupBootstrap then
        NMClientPlaybackTick.beginStartupBootstrap(120)
    end
    NMClientMainRuntime.markAuthorityRefresh("on_game_start")
    if NMClientWorldItemVisualSanitizer and NMClientWorldItemVisualSanitizer.onGameStart then
        NMClientWorldItemVisualSanitizer.onGameStart()
    end
    if NMClientInventoryItemVisualSanitizer and NMClientInventoryItemVisualSanitizer.onGameStart then
        NMClientInventoryItemVisualSanitizer.onGameStart()
    end
end

function NMClientMainRuntime.onObjectAdded(obj)
    local probeEnabled = tickWorkProbeEnabled()
    NMClientMainRuntime.requestTickGateWake("object_added")
    countNamedDiag(probeEnabled, clientUiInvalidationDiag, "event_on_object_added")
    if NMClientWorldItemVisualSanitizer and NMClientWorldItemVisualSanitizer.onObjectAdded then
        NMClientWorldItemVisualSanitizer.onObjectAdded(obj)
    end
    if NMClientInventoryItemVisualSanitizer and NMClientInventoryItemVisualSanitizer.requestSweep then
        NMClientInventoryItemVisualSanitizer.requestSweep("object_added")
    end
end

function NMClientMainRuntime.onRefreshInventoryWindowContainers()
    local probeEnabled = tickWorkProbeEnabled()
    NMClientMainRuntime.requestTickGateWake("inventory_refresh")
    if NMClientPlaybackTick and NMClientPlaybackTick.requestInventoryRefreshPass then
        NMClientPlaybackTick.requestInventoryRefreshPass("inventory_refresh")
    elseif NMClientPlaybackTick and NMClientPlaybackTick.requestFullPass then
        NMClientPlaybackTick.requestFullPass("inventory_refresh")
    elseif NMClientPlaybackTick and NMClientPlaybackTick.markDirty then
        NMClientPlaybackTick.markDirty("inventory_refresh")
    end
    countNamedDiag(probeEnabled, clientUiInvalidationDiag, "event_refresh_inventory_window_containers")
    if NMClientInventoryItemVisualSanitizer and NMClientInventoryItemVisualSanitizer.requestSweep then
        NMClientInventoryItemVisualSanitizer.requestSweep("inventory_refresh")
    end
end

function NMClientMainRuntime.onClothingUpdated()
    local probeEnabled = tickWorkProbeEnabled()
    NMClientMainRuntime.requestTickGateWake("clothing_updated")
    if NMClientPlaybackTick and NMClientPlaybackTick.requestFullPass then
        NMClientPlaybackTick.requestFullPass("clothing_updated")
    elseif NMClientPlaybackTick and NMClientPlaybackTick.markDirty then
        NMClientPlaybackTick.markDirty("clothing_updated")
    end
    countNamedDiag(probeEnabled, clientUiInvalidationDiag, "event_clothing_updated")
    if NMClientInventoryItemVisualSanitizer and NMClientInventoryItemVisualSanitizer.requestSweep then
        NMClientInventoryItemVisualSanitizer.requestSweep("clothing_updated")
    end
end

function NMClientMainRuntime.registerTickGate()
    installPlayerMoveHook()
    installVehicleSeatHooks()
    NMClientTickGate.register({
        advanceTick = NMClientMainRuntime.advanceSchedulerTick,
        hasAnyTickWork = NMClientMainRuntime.hasAnyTickWork,
        getCurrentTick = NMClientMainRuntime.getCurrentSchedulerTick,
        getNextWakeTick = NMClientMainRuntime.getNextTickGateWakeTick,
        isHookInstalled = NMClientMainRuntime.isTickHookInstalled,
        installHook = NMClientMainRuntime.installTickHook,
        removeHook = NMClientMainRuntime.removeTickHook,
        shouldKeepGateRegistered = shouldKeepClientTickGateRegistered
    })
end

return NMClientMainRuntime
