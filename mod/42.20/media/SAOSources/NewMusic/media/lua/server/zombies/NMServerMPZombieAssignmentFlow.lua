NMServerMPZombieAssignmentFlow = NMServerMPZombieAssignmentFlow or {}
require "zombies/NMZombieAudioVisualSupport"
require "zombies/NMServerZombieScanHelpers"
require "zombies/NMServerMPZombieIntakeQueue"
require "zombies/NMServerMPZombieScanPolicy"
require "zombies/NMServerMPZombieAssignmentEligibility"
require "zombies/NMServerMPZombieAssignmentExecutor"

local STRATEGY_NAME = "mp_assignment_flow"
local SCAN_RADIUS = 14
local MAX_ZOMBIES_PER_PLAYER = 32
local HEARTBEAT_TICKS = 900
local TICK_INTERVAL = 90
local FAILURE_COOLDOWN_TICKS = 900
local NATURAL_INTAKE_SCAN_INTERVAL = 10
local NATURAL_INTAKE_RADIUS = 24
local NATURAL_INTAKE_MAX_ZOMBIES_PER_PLAYER = 192
local NATURAL_INTAKE_PROCESS_LIMIT = 96
local SAMPLE_LIMIT = 3
local SAMPLE_RECHECK_DELAY_TICKS = 120
local ACTIVE_RECENT_WINDOW_TICKS = 180
local INTEREST_LOG_INTERVAL_MS = 5000

NMServerMPZombieAssignmentFlow._diag = NMServerMPZombieAssignmentFlow._diag or {
    ticks = 0,
    attachAttempts = 0,
    attachSuccess = 0,
    attachFailure = 0,
    attachExcluded = 0,
    attachExcludedScrubbed = 0,
    attachSuppressed = 0,
    supportApplied = 0,
    queueEnqueued = 0,
    queueProcessed = 0,
    queueScanned = 0,
    fallbackApplied = 0,
    strategyAssignments = 0,
    attachedListVisible = 0,
    attachedListMissing = 0,
    inventoryStillHasProof = 0,
    supportStillWorn = 0,
    sampleBudget = 0,
    pendingSamples = {},
    lastReportedAttachSuccess = 0,
    lastReportedAttachFailure = 0,
    lastReportedSupportApplied = 0,
    lastReportedStrategyAssignments = 0,
    recentAssignmentTick = 0,
    recentTickRun = 0,
    schedulerTicks = 0,
    recentSchedulerAssignmentTick = 0,
    recentSchedulerTickRun = 0,
    interestCacheTick = nil,
    interestCache = nil,
    lastInterestLogMsByKind = {},
    lastInterestReasonByKind = {}
}

local CONSTANTS = {
    STRATEGY_NAME = STRATEGY_NAME,
    SCAN_RADIUS = SCAN_RADIUS,
    MAX_ZOMBIES_PER_PLAYER = MAX_ZOMBIES_PER_PLAYER,
    HEARTBEAT_TICKS = HEARTBEAT_TICKS,
    TICK_INTERVAL = TICK_INTERVAL,
    FAILURE_COOLDOWN_TICKS = FAILURE_COOLDOWN_TICKS,
    NATURAL_INTAKE_SCAN_INTERVAL = NATURAL_INTAKE_SCAN_INTERVAL,
    NATURAL_INTAKE_RADIUS = NATURAL_INTAKE_RADIUS,
    NATURAL_INTAKE_MAX_ZOMBIES_PER_PLAYER = NATURAL_INTAKE_MAX_ZOMBIES_PER_PLAYER,
    NATURAL_INTAKE_PROCESS_LIMIT = NATURAL_INTAKE_PROCESS_LIMIT,
    SAMPLE_LIMIT = SAMPLE_LIMIT,
    SAMPLE_RECHECK_DELAY_TICKS = SAMPLE_RECHECK_DELAY_TICKS
}

local function canRunAuthoritativeMutation()
    if NMCore and NMCore.isMPClientRuntime and NMCore.isMPClientRuntime() == true then
        return false
    end
    if NMAuthorityContract and NMAuthorityContract.canMutateDurableStateAtRuntime then
        return NMAuthorityContract.canMutateDurableStateAtRuntime() == true
    end
    return true
end

local function shouldRun()
    return canRunAuthoritativeMutation()
        and NMZombieLiveStrategy
        and NMZombieLiveStrategy.shouldRunMPAssignmentFlow
        and NMZombieLiveStrategy.shouldRunMPAssignmentFlow() == true
end

local function shouldLogAssignment()
    return NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("zombie_assignment") == true
end

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

local function getOnlinePlayerCount()
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if players and players.size then
        return tonumber(players:size()) or 0
    end
    return 0
end

local function getPendingQueueCount()
    return NMServerMPZombieIntakeQueue.count and NMServerMPZombieIntakeQueue.count(NMServerMPZombieAssignmentFlow) or 0
end

local function getNextCadenceTickAfter(anchorTick, interval)
    local tick = tonumber(anchorTick) or 0
    local cadence = tonumber(interval) or 0
    if cadence <= 0 then
        return math.huge
    end
    return tick + cadence
end

local function getRecentAssignmentFollowupTick(recentAssignmentTick)
    local assignmentTick = tonumber(recentAssignmentTick) or 0
    if assignmentTick <= 0 then
        return math.huge
    end
    return assignmentTick + ACTIVE_RECENT_WINDOW_TICKS
end

local function resolveInterestSnapshot()
    local diag = NMServerMPZombieAssignmentFlow._diag
    local currentTick = tonumber(diag.schedulerTicks) or tonumber(diag.ticks) or 0
    if diag.interestCache and tonumber(diag.interestCacheTick) == currentTick then
        return diag.interestCache
    end

    local snapshot = {
        canRun = shouldRun() == true,
        pendingCount = 0,
        playerCount = 0,
        active = false,
        maintenance = false,
        activeReason = "disabled",
        maintenanceReason = "disabled"
    }

    if snapshot.canRun == true then
        snapshot.pendingCount = getPendingQueueCount()
        snapshot.playerCount = getOnlinePlayerCount()
        local recentAssignmentTick = tonumber(diag.recentSchedulerAssignmentTick) or tonumber(diag.recentAssignmentTick) or 0
        local recentTickRun = tonumber(diag.recentSchedulerTickRun) or tonumber(diag.recentTickRun) or 0
        local recentFollowupTick = getRecentAssignmentFollowupTick(recentAssignmentTick)
        local recentFollowupDue = recentFollowupTick <= currentTick and recentTickRun < recentFollowupTick
        local naturalScanDue = currentTick >= getNextCadenceTickAfter(recentTickRun, NATURAL_INTAKE_SCAN_INTERVAL)
        local fallbackScanDue = currentTick >= getNextCadenceTickAfter(recentTickRun, TICK_INTERVAL)

        if snapshot.pendingCount > 0 then
            snapshot.active = true
            snapshot.maintenance = true
            snapshot.activeReason = "pending_queue"
            snapshot.maintenanceReason = "pending_queue"
        elseif snapshot.playerCount > 0 and recentFollowupDue == true then
            snapshot.maintenance = true
            snapshot.activeReason = "idle"
            snapshot.maintenanceReason = "recent_assignment_followup_due"
        elseif snapshot.playerCount > 0 and recentTickRun <= 0 then
            snapshot.maintenance = true
            snapshot.activeReason = "idle"
            snapshot.maintenanceReason = "bootstrap"
        elseif snapshot.playerCount > 0 and (naturalScanDue == true or fallbackScanDue == true) then
            snapshot.activeReason = "idle"
            snapshot.maintenance = true
            snapshot.maintenanceReason = fallbackScanDue == true and "fallback_scan_due" or "natural_scan_due"
        elseif snapshot.playerCount > 0 then
            snapshot.activeReason = "idle"
            snapshot.maintenanceReason = "scan_wait"
        else
            snapshot.activeReason = "idle"
            snapshot.maintenanceReason = "no_players"
        end
    end

    diag.interestCacheTick = currentTick
    diag.interestCache = snapshot
    return snapshot
end

local function logInterestDecision(kind, reason, pendingCount, playerCount)
    if not shouldLogAssignment() then
        return
    end
    local diag = NMServerMPZombieAssignmentFlow._diag
    diag.lastInterestLogMsByKind = diag.lastInterestLogMsByKind or {}
    diag.lastInterestReasonByKind = diag.lastInterestReasonByKind or {}
    local kindKey = tostring(kind or "")
    local nowMs = nowRealMs()
    local shouldLogNow = tostring(reason or "") ~= tostring(diag.lastInterestReasonByKind[kindKey] or "")
        or (nowMs - (tonumber(diag.lastInterestLogMsByKind[kindKey]) or 0)) >= INTEREST_LOG_INTERVAL_MS
    if not shouldLogNow then
        return
    end
    diag.lastInterestReasonByKind[kindKey] = tostring(reason or "")
    diag.lastInterestLogMsByKind[kindKey] = nowMs
    NMCore.logChannel(
        "zombie_assignment",
        "mp_assignment_interest",
        string.format(
            "kind=%s reason=%s pending=%s players=%s ticks=%s recentAssignmentTick=%s recentTickRun=%s",
            tostring(kind or ""),
            tostring(reason or ""),
            tostring(pendingCount or 0),
            tostring(playerCount or 0),
            tostring(diag.schedulerTicks or diag.ticks or 0),
            tostring(diag.recentSchedulerAssignmentTick or diag.recentAssignmentTick or 0),
            tostring(diag.recentSchedulerTickRun or diag.recentTickRun or 0)
        )
    )
end

local function getModData(holder)
    return NMZombieAudioVisualSupport.getProofModData(holder)
end

local function buildEligibilityDeps(diag)
    return {
        isAliveZombie = NMServerZombieScanHelpers.isAliveZombie,
        getModData = getModData,
        nowTick = tonumber(diag and diag.ticks or 0) or 0,
        cooldownTicks = FAILURE_COOLDOWN_TICKS
    }
end

local function buildExecutorDeps(diag)
    return {
        diag = diag,
        flow = NMServerMPZombieAssignmentFlow,
        constants = CONSTANTS,
        getModData = getModData
    }
end

local function shouldQueueNaturalZombie(zombie, diag)
    return NMServerMPZombieAssignmentEligibility.shouldQueueNaturalZombie(zombie, buildEligibilityDeps(diag))
end

function NMServerMPZombieAssignmentFlow.hasActiveWork()
    local snapshot = resolveInterestSnapshot()
    logInterestDecision("active", snapshot.activeReason, snapshot.pendingCount, snapshot.playerCount)
    return snapshot.active == true
end

function NMServerMPZombieAssignmentFlow.hasMaintenanceWork()
    local snapshot = resolveInterestSnapshot()
    logInterestDecision("maintenance", snapshot.maintenanceReason, snapshot.pendingCount, snapshot.playerCount)
    return snapshot.maintenance == true
end

function NMServerMPZombieAssignmentFlow.getNextActiveWorkCheckTick()
    if shouldRun() ~= true then
        return math.huge
    end
    local diag = NMServerMPZombieAssignmentFlow._diag
    local currentTick = tonumber(diag.schedulerTicks) or tonumber(diag.ticks) or 0
    if getPendingQueueCount() > 0 then
        return currentTick
    end
    if getOnlinePlayerCount() <= 0 then
        return math.huge
    end

    local recentTickRun = tonumber(diag.recentSchedulerTickRun) or tonumber(diag.recentTickRun) or 0
    if recentTickRun <= 0 then
        return currentTick
    end

    local nextTick = math.huge
    local recentAssignmentTick = tonumber(diag.recentSchedulerAssignmentTick) or tonumber(diag.recentAssignmentTick) or 0
    local recentFollowupTick = getRecentAssignmentFollowupTick(recentAssignmentTick)
    if recentFollowupTick < math.huge and recentTickRun < recentFollowupTick then
        nextTick = math.min(nextTick, math.max(currentTick, recentFollowupTick))
    end
    nextTick = math.min(nextTick, getNextCadenceTickAfter(recentTickRun, NATURAL_INTAKE_SCAN_INTERVAL))
    nextTick = math.min(nextTick, getNextCadenceTickAfter(recentTickRun, TICK_INTERVAL))
    return nextTick
end

function NMServerMPZombieAssignmentFlow.observeSchedulerTick(tickStep)
    local diag = NMServerMPZombieAssignmentFlow._diag
    diag.schedulerTicks = (tonumber(diag.schedulerTicks) or 0) + math.max(1, tonumber(tickStep) or 1)
    diag.interestCacheTick = nil
    diag.interestCache = nil
end

function NMServerMPZombieAssignmentFlow.onZombieUpdate(zombie)
    if not shouldRun() then
        return
    end
    local diag = NMServerMPZombieAssignmentFlow._diag
    local enqueued = NMServerMPZombieIntakeQueue.enqueue(
        NMServerMPZombieAssignmentFlow,
        zombie,
        "zombie_update",
        function(candidate)
            return shouldQueueNaturalZombie(candidate, diag)
        end,
        NMServerMPZombieIntakeQueue.getZombieQueueKey,
        diag
    )
    if enqueued == true and NMServerTickGate and NMServerTickGate.wake then
        NMServerTickGate.wake("mp_zombie_update")
    end
end

function NMServerMPZombieAssignmentFlow.onTick(tickStep)
    if not shouldRun() then
        return
    end
    local diag = NMServerMPZombieAssignmentFlow._diag
    diag.ticks = (tonumber(diag.ticks) or 0) + math.max(1, tonumber(tickStep) or 1)
    diag.recentTickRun = tonumber(diag.ticks) or 0
    diag.recentSchedulerTickRun = tonumber(diag.schedulerTicks) or tonumber(diag.ticks) or 0
    local pendingBefore = getPendingQueueCount()
    local scannedBefore = tonumber(diag.queueScanned) or 0
    local processedBefore = tonumber(diag.queueProcessed) or 0
    local fallbackBefore = tonumber(diag.fallbackApplied) or 0
    local successBefore = tonumber(diag.attachSuccess) or 0
    local failureBefore = tonumber(diag.attachFailure) or 0

    local executorDeps = buildExecutorDeps(diag)
    NMServerMPZombieAssignmentExecutor.processPendingSamples(diag, executorDeps)

    local players = getOnlinePlayers and getOnlinePlayers() or nil
    local hasOnlinePlayers = players and players.size and players:size() > 0
    local fallbackPlayer = nil
    if not hasOnlinePlayers then
        fallbackPlayer = getPlayer and getPlayer() or nil
    end

    if NMServerMPZombieScanPolicy.shouldRunNaturalIntakeScan(diag.ticks, NATURAL_INTAKE_SCAN_INTERVAL) then
        NMServerMPZombieScanPolicy.observeNaturalCandidates(
            hasOnlinePlayers and players or nil,
            fallbackPlayer,
            function(zombie, source)
                NMServerMPZombieIntakeQueue.enqueue(
                    NMServerMPZombieAssignmentFlow,
                    zombie,
                    source,
                    function(candidate)
                        return shouldQueueNaturalZombie(candidate, diag)
                    end,
                    NMServerMPZombieIntakeQueue.getZombieQueueKey,
                    diag
                )
            end,
            diag,
            {
                source = "first_seen_scan",
                radius = NATURAL_INTAKE_RADIUS,
                maxZombies = NATURAL_INTAKE_MAX_ZOMBIES_PER_PLAYER
            }
        )
    end

    local processed = NMServerMPZombieIntakeQueue.drain(
        NMServerMPZombieAssignmentFlow,
        NATURAL_INTAKE_PROCESS_LIMIT,
        function(zombie)
            return shouldQueueNaturalZombie(zombie, diag)
        end,
        function(zombie, source)
            NMServerMPZombieAssignmentExecutor.applyAssignmentOutcome(zombie, source, executorDeps)
        end,
        diag
    )
    if processed > 0 then
        diag.recentAssignmentTick = tonumber(diag.ticks) or 0
        diag.recentSchedulerAssignmentTick = tonumber(diag.schedulerTicks) or tonumber(diag.ticks) or 0
    end

    if not NMServerMPZombieScanPolicy.shouldRunFallbackScan(diag.ticks, TICK_INTERVAL) then
        if shouldLogAssignment() then
            NMCore.logChannel(
                "zombie_assignment",
                "mp_assignment_tick",
                string.format(
                    "tickStep=%s ticks=%s pendingBefore=%s pendingAfter=%s scannedDelta=%s processedDelta=%s fallbackDelta=%s successDelta=%s failureDelta=%s fallbackDue=false",
                    tostring(tickStep or 1),
                    tostring(diag.ticks or 0),
                    tostring(pendingBefore),
                    tostring(getPendingQueueCount()),
                    tostring((tonumber(diag.queueScanned) or 0) - scannedBefore),
                    tostring((tonumber(diag.queueProcessed) or 0) - processedBefore),
                    tostring((tonumber(diag.fallbackApplied) or 0) - fallbackBefore),
                    tostring((tonumber(diag.attachSuccess) or 0) - successBefore),
                    tostring((tonumber(diag.attachFailure) or 0) - failureBefore)
                )
            )
        end
        return
    end

    diag.sampleBudget = SAMPLE_LIMIT
    local fallbackApplied = NMServerMPZombieScanPolicy.runFallback(
        hasOnlinePlayers and players or nil,
        fallbackPlayer,
        function(zombie, source)
            if shouldQueueNaturalZombie(zombie, diag) ~= true then
                return false
            end
            return NMServerMPZombieAssignmentExecutor.applyAssignmentOutcome(zombie, source, executorDeps)
        end,
        {
            source = "fallback_scan",
            radius = SCAN_RADIUS,
            maxZombies = MAX_ZOMBIES_PER_PLAYER
        }
    )
    diag.fallbackApplied = (diag.fallbackApplied or 0) + fallbackApplied
    if fallbackApplied > 0 then
        diag.recentAssignmentTick = tonumber(diag.ticks) or 0
        diag.recentSchedulerAssignmentTick = tonumber(diag.schedulerTicks) or tonumber(diag.ticks) or 0
    end

    diag.lastReportedAttachSuccess = diag.attachSuccess or 0
    diag.lastReportedAttachFailure = diag.attachFailure or 0
    diag.lastReportedSupportApplied = diag.supportApplied or 0
    diag.lastReportedStrategyAssignments = diag.strategyAssignments or 0

    if shouldLogAssignment() then
        NMCore.logChannel(
            "zombie_assignment",
            "mp_assignment_tick",
            string.format(
                "tickStep=%s ticks=%s pendingBefore=%s pendingAfter=%s scannedDelta=%s processedDelta=%s fallbackDelta=%s successDelta=%s failureDelta=%s fallbackDue=true",
                tostring(tickStep or 1),
                tostring(diag.ticks or 0),
                tostring(pendingBefore),
                tostring(getPendingQueueCount()),
                tostring((tonumber(diag.queueScanned) or 0) - scannedBefore),
                tostring((tonumber(diag.queueProcessed) or 0) - processedBefore),
                tostring((tonumber(diag.fallbackApplied) or 0) - fallbackBefore),
                tostring((tonumber(diag.attachSuccess) or 0) - successBefore),
                tostring((tonumber(diag.attachFailure) or 0) - failureBefore)
            )
        )
    end

    if (diag.ticks % HEARTBEAT_TICKS) ~= 0 then
        return
    end
end

return NMServerMPZombieAssignmentFlow
