-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
NMServerSPZombieAssignmentFlow = NMServerSPZombieAssignmentFlow or {}
require "zombies/NMZombieAudioVisualSupport"
require "zombies/NMZombieDeviceVariantCatalog"
require "zombies/NMZombieMediaPayloadResolver"
require "zombies/NMZombieMediaPayloadRuntime"
require "zombies/NMServerZombieScanHelpers"
require "zombies/NMServerZombieAssignmentShared"
require "zombies/NMServerZombieAssignmentApplyShared"
require "zombies/NMServerZombieAssignmentOutcomeShared"
require "zombies/NMServerSPZombieIntakeQueue"
require "zombies/NMServerSPZombieAssignmentEligibility"

local STRATEGY_NAME = "sp_runtime_attach"
local HEARTBEAT_TICKS = 900
local SCAN_INTERVAL_TICKS = 30
local SCAN_RADIUS_SQ = 50 * 50
local SCAN_ZOMBIE_LIMIT = 32
local SCAN_PLAYER_LIMIT = 4
local ACTIVE_QUEUE_WAKE_INTERVAL_TICKS = 10
local ACTIVE_DRAIN_LIMIT = 24
local MAINTENANCE_DRAIN_LIMIT = 32
local FAILED_RETRY_TICKS = 600
local LOADED_SWEEP_LIMIT = 12
local ACTIVE_ELIGIBLE_WINDOW_TICKS = 45
local ACTIVE_PROCESSED_WINDOW_TICKS = 60
local NEARBY_IDLE_WINDOW_TICKS = 30
local COOLDOWN_INTEREST_WINDOW_TICKS = 20
local RECENT_SETTLED_SKIP_TICKS = 90
local IDLE_DRAIN_BACKOFF_TICKS = 45
local UPDATE_RETRY_TICKS = 45
local FAILED_UPDATE_RETRY_TICKS = 120
local UPDATE_STATELESS_RETRY_TICKS = 90
local UPDATE_DIAG_LOG_INTERVAL_MS = 5000
local HELPER_DIAG_LOG_INTERVAL_MS = 5000

NMServerSPZombieAssignmentFlow._diag = NMServerSPZombieAssignmentFlow._diag or {
    ticks = 0,
    drainEligible = 0,
    drainAttempted = 0,
    drainIneligibleSkip = 0,
    drainSettledSkip = 0,
    drainCooldownSkip = 0,
    queueProcessed = 0,
    queueDequeued = 0,
    queueCadenceWait = 0,
    queueLingering = 0,
    scanCalls = 0,
    scanCandidates = 0,
    scanNearby = 0,
    scanLoadedSweep = 0,
    scanEnqueued = 0,
    listCursor = 0,
    attachAttempts = 0,
    attachSuccess = 0,
    attachFailure = 0,
    locationFailures = 0,
    attachInventoryFallback = 0,
    attachExcluded = 0,
    attachExcludedScrubbed = 0,
    attachSuppressed = 0,
    recentNearbyPlayerTick = 0,
    recentEligibleAttachTick = 0,
    recentProcessedScanTick = 0,
    recentIdleDrainTick = 0,
    nextRetryPendingTick = 0,
    zeroEligibleDrainStreak = 0,
    interestQueuePending = 0,
    interestEligibleRecent = 0,
    interestProcessedRecent = 0,
    interestCooldownPending = 0,
    interestNearbyIdle = 0,
    interestBackoffIdle = 0,
    interestMaintenanceOnly = 0,
    hasActiveWorkHits = 0,
    stateActiveAttachWorkWins = 0,
    stateActiveRecentProcessingWins = 0,
    stateActiveCooldownPendingWins = 0,
    stateQueuePendingWins = 0,
    stateBackoffIdleWins = 0,
    stateNearbyButIdleWins = 0,
    stateMaintenanceOnlyWins = 0,
    stateTieQueueVsAttach = 0,
    stateTieQueueVsProcessed = 0,
    stateTieQueueVsCooldown = 0,
    stateTieAttachVsProcessed = 0,
    stateTieAttachVsCooldown = 0,
    stateTieProcessedVsCooldown = 0,
    stateActiveAttachAge = 0,
    stateRecentProcessedAge = 0,
    stateRecentIdleDrainAge = 0,
    stateNextRetryAge = 0,
    eligibleDecisionSeen = 0,
    attachAttemptTicked = 0,
    attachSuccessTicked = 0,
    attachFailureTicked = 0,
    processedWithoutAttach = 0,
    pendingQueueCount = 0,
    pendingQueueOldestAge = 0,
    lastDiagLogMs = 0,
    helperLastDiagLogMs = 0,
    helperCounters = {},
    phaseDurations = {}
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
        and NMZombieLiveStrategy.shouldRunSPRuntimeAttach
        and NMZombieLiveStrategy.shouldRunSPRuntimeAttach() == true
end

local function memoryDiagEnabled()
    return NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("memory") == true
end

local function shouldLogProofVerbose()
    return NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("zombie_assignment") == true
end

local function logProof(tag, detail, force)
    if not force and not shouldLogProofVerbose() then
        return
    end
    print("[NewMusic] [ZombieProof] " .. tostring(tag or "") .. " " .. tostring(detail or ""))
end

local function zombieDebugId(zombie)
    return tostring(zombie and zombie.getOnlineID and zombie:getOnlineID() or zombie and zombie.getObjectID and zombie:getObjectID() or "unknown")
end

local function isAliveZombie(zombie)
    return NMServerZombieScanHelpers.isAliveZombie(zombie)
end

local function getModData(holder)
    if memoryDiagEnabled() then
        local diag = NMServerSPZombieAssignmentFlow._diag
        diag.helperCounters["sp_shared.getModData"] = (tonumber(diag.helperCounters["sp_shared.getModData"]) or 0) + 1
    end
    return NMServerZombieAssignmentShared.getModData(holder)
end

local function collectCandidatePlayers()
    return NMServerZombieScanHelpers.collectCandidatePlayers({
        playerLimit = SCAN_PLAYER_LIMIT,
        includeSpecificPlayers = true,
        includeLocalPlayer = true
    })
end

local function collectScanPlayers()
    local players = collectCandidatePlayers() or {}
    if #players > 0 then
        return players
    end
    local out = {}
    local seen = {}
    local localPlayer = getPlayer and getPlayer() or nil
    if localPlayer then
        out[#out + 1] = localPlayer
        seen[localPlayer] = true
    end
    for i = 0, SCAN_PLAYER_LIMIT - 1 do
        local player = getSpecificPlayer and getSpecificPlayer(i) or nil
        if player and not seen[player] then
            out[#out + 1] = player
            seen[player] = true
            if #out >= SCAN_PLAYER_LIMIT then
                break
            end
        end
    end
    return out
end

local function hasPlayerAnchor()
    if getPlayer and getPlayer() then
        return true
    end
    for i = 0, SCAN_PLAYER_LIMIT - 1 do
        if getSpecificPlayer and getSpecificPlayer(i) then
            return true
        end
    end
    return false
end

local function isZombieNearAnyPlayer(zombie, players)
    return NMServerZombieScanHelpers.isZombieNearAnyPlayer(zombie, players, SCAN_RADIUS_SQ)
end

local function getSpecForVariantId(variantId)
    return NMServerZombieAssignmentShared.getSpecForVariantId(variantId)
end

local function getStampedVariantSpec(zombie)
    if memoryDiagEnabled() then
        local diag = NMServerSPZombieAssignmentFlow._diag
        diag.helperCounters["sp_shared.getStampedVariantSpec"] = (tonumber(diag.helperCounters["sp_shared.getStampedVariantSpec"]) or 0) + 1
    end
    return NMServerZombieAssignmentShared.getStampedVariantSpec(zombie)
end

local function findAttachedProofItem(zombie, spec)
    if memoryDiagEnabled() then
        local diag = NMServerSPZombieAssignmentFlow._diag
        diag.helperCounters["sp_shared.findAttachedProofItem"] = (tonumber(diag.helperCounters["sp_shared.findAttachedProofItem"]) or 0) + 1
    end
    local item, meta = NMServerZombieAssignmentShared.findAttachedProofItem(zombie, spec, { allowInventoryFallback = true })
    if meta and meta.usedInventoryFallback == true then
        NMServerSPZombieAssignmentFlow._diag.attachInventoryFallback = (NMServerSPZombieAssignmentFlow._diag.attachInventoryFallback or 0) + 1
    end
    return item
end

local function findInventoryProofItem(zombie, spec)
    if memoryDiagEnabled() then
        local diag = NMServerSPZombieAssignmentFlow._diag
        diag.helperCounters["sp_shared.findInventoryProofItem"] = (tonumber(diag.helperCounters["sp_shared.findInventoryProofItem"]) or 0) + 1
    end
    return NMServerZombieAssignmentShared.findInventoryProofItem(zombie, spec)
end

local function dumpAvailableAttachmentLocations(zombie)
    local attachedItems = zombie and zombie.getAttachedItems and zombie:getAttachedItems() or nil
    local group = attachedItems and attachedItems.getGroup and attachedItems:getGroup() or nil
    if not (group and group.size and group.getLocationByIndex) then
        return "locations=nil"
    end
    local out = {}
    for i = 0, group:size() - 1 do
        local entry = group:getLocationByIndex(i)
        out[#out + 1] = tostring(entry and entry.getId and entry:getId() or "")
    end
    return table.concat(out, ",")
end

local function stampSelectionOutcome(zombie, spec, outcome)
    NMServerZombieAssignmentOutcomeShared.stampSelectionState(zombie, spec, {
        strategyName = STRATEGY_NAME,
        selection = outcome and outcome.selection or nil,
        status = outcome and outcome.status or "excluded",
        reason = outcome and outcome.reason or "selection_state",
        payload = outcome and outcome.payload or nil,
        lastAttemptTick = tonumber(NMServerSPZombieAssignmentFlow._diag and NMServerSPZombieAssignmentFlow._diag.ticks or 0) or 0
    })
end

local function stampFailedOutcome(zombie, outcome)
    NMServerZombieAssignmentOutcomeShared.stampFailedState(zombie, outcome and outcome.spec or nil, {
        strategyName = STRATEGY_NAME,
        selection = outcome and outcome.selection or nil,
        item = outcome and outcome.item or nil,
        reason = outcome and outcome.reason or "unknown",
        payload = outcome and outcome.payload or nil,
        lastAttemptTick = tonumber(NMServerSPZombieAssignmentFlow._diag and NMServerSPZombieAssignmentFlow._diag.ticks or 0) or 0
    })
end

local function stampAttachedOutcome(zombie, outcome)
    NMServerZombieAssignmentOutcomeShared.stampAttachedState(zombie, outcome and outcome.spec or nil, {
        strategyName = STRATEGY_NAME,
        selection = outcome and outcome.selection or nil,
        item = outcome and outcome.item or nil,
        payload = outcome and outcome.payload or nil,
        lastAttemptTick = tonumber(NMServerSPZombieAssignmentFlow._diag and NMServerSPZombieAssignmentFlow._diag.ticks or 0) or 0
    })
end

local function markRecentTick(fieldName)
    local diag = NMServerSPZombieAssignmentFlow._diag
    diag[tostring(fieldName or "")] = tonumber(diag.ticks) or 0
end

local function getRecentDelta(currentTick, value)
    local recentTick = tonumber(value) or 0
    if recentTick <= 0 then
        return math.huge
    end
    return currentTick - recentTick
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

local function beginPhase()
    if memoryDiagEnabled() ~= true then
        return 0
    end
    return nowRealMs()
end

local function recordPhase(name, startedMs)
    if memoryDiagEnabled() ~= true then
        return
    end
    local diag = NMServerSPZombieAssignmentFlow._diag
    diag.phaseDurations = diag.phaseDurations or {}
    local key = tostring(name or "unknown")
    local slot = diag.phaseDurations[key]
    if not slot then
        slot = { count = 0, sumMs = 0, maxMs = 0 }
        diag.phaseDurations[key] = slot
    end
    local elapsedMs = math.max(0, nowRealMs() - (tonumber(startedMs) or 0))
    slot.count = (tonumber(slot.count) or 0) + 1
    slot.sumMs = (tonumber(slot.sumMs) or 0) + elapsedMs
    slot.maxMs = math.max(tonumber(slot.maxMs) or 0, elapsedMs)
end

local function countProbe(name)
    if memoryDiagEnabled() ~= true then
        return
    end
    local diag = NMServerSPZombieAssignmentFlow._diag
    diag.helperCounters = diag.helperCounters or {}
    local key = tostring(name or "unknown")
    diag.helperCounters[key] = (tonumber(diag.helperCounters[key]) or 0) + 1
end

local function countProbeBucket(prefix, value)
    local n = tonumber(value)
    local bucket = "none"
    if n ~= nil and n >= 0 then
        if n <= 10 then
            bucket = "0_10"
        elseif n <= 30 then
            bucket = "11_30"
        elseif n <= 60 then
            bucket = "31_60"
        elseif n <= 120 then
            bucket = "61_120"
        else
            bucket = "121_plus"
        end
    end
    countProbe(tostring(prefix or "bucket") .. "." .. bucket)
end

local function formatPhaseDurations(diag)
    local parts = {}
    local durations = diag and diag.phaseDurations or nil
    if type(durations) ~= "table" then
        return parts
    end
    for name, slot in pairs(durations) do
        local count = tonumber(slot.count) or 0
        if count > 0 then
            parts[#parts + 1] = string.format(
                "%s=count:%d avgMs:%.3f maxMs:%.3f",
                tostring(name),
                count,
                (tonumber(slot.sumMs) or 0) / count,
                tonumber(slot.maxMs) or 0
            )
        end
        durations[name] = nil
    end
    return parts
end

local function flushUpdateDiag()
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("memory") == true) then
        return
    end
    local diag = NMServerSPZombieAssignmentFlow._diag
    local nowMs = nowRealMs()
    if (nowMs - (tonumber(diag.lastDiagLogMs) or 0)) < UPDATE_DIAG_LOG_INTERVAL_MS then
        return
    end
    diag.lastDiagLogMs = nowMs
    NMCore.logChannel(
        "memory",
        "sp_zombie_update_diag",
        string.format(
            "drainEligible=%s drainAttempted=%s drainIneligibleSkip=%s drainSettledSkip=%s drainCooldownSkip=%s queueProcessed=%s queueDequeued=%s queueCadenceWait=%s queueLingering=%s scanEnqueued=%s interestQueuePending=%s interestEligibleRecent=%s interestProcessedRecent=%s interestCooldownPending=%s interestNearbyIdle=%s interestBackoffIdle=%s interestMaintenanceOnly=%s zeroEligibleDrainStreak=%s pendingQueueCount=%s pendingQueueOldestAge=%s eligibleDecisionSeen=%s attachAttemptTicked=%s attachSuccessTicked=%s attachFailureTicked=%s processedWithoutAttach=%s",
            tostring(diag.drainEligible or 0),
            tostring(diag.drainAttempted or 0),
            tostring(diag.drainIneligibleSkip or 0),
            tostring(diag.drainSettledSkip or 0),
            tostring(diag.drainCooldownSkip or 0),
            tostring(diag.queueProcessed or 0),
            tostring(diag.queueDequeued or 0),
            tostring(diag.queueCadenceWait or 0),
            tostring(diag.queueLingering or 0),
            tostring(diag.scanEnqueued or 0),
            tostring(diag.interestQueuePending or 0),
            tostring(diag.interestEligibleRecent or 0),
            tostring(diag.interestProcessedRecent or 0),
            tostring(diag.interestCooldownPending or 0),
            tostring(diag.interestNearbyIdle or 0),
            tostring(diag.interestBackoffIdle or 0),
            tostring(diag.interestMaintenanceOnly or 0),
            tostring(diag.zeroEligibleDrainStreak or 0),
            tostring(diag.pendingQueueCount or 0),
            tostring(diag.pendingQueueOldestAge or 0),
            tostring(diag.eligibleDecisionSeen or 0),
            tostring(diag.attachAttemptTicked or 0),
            tostring(diag.attachSuccessTicked or 0),
            tostring(diag.attachFailureTicked or 0),
            tostring(diag.processedWithoutAttach or 0)
        )
    )
    NMCore.logChannel(
        "memory",
        "sp_zombie_interest_diag",
        string.format(
            "hasActiveWorkHits=%s activeReasonAttach=%s activeReasonProcessed=%s activeReasonNearby=%s activeReasonRetry=%s activeReasonIdle=%s maintenanceReasonRetry=%s maintenanceReasonNoAnchor=%s maintenanceReasonNeverDrained=%s maintenanceReasonBackoffDue=%s maintenanceReasonBackoffWait=%s stateQueuePendingWins=%s stateActiveAttachWorkWins=%s stateActiveRecentProcessingWins=%s stateActiveCooldownPendingWins=%s stateBackoffIdleWins=%s stateNearbyButIdleWins=%s stateMaintenanceOnlyWins=%s stateTieQueueVsAttach=%s stateTieQueueVsProcessed=%s stateTieQueueVsCooldown=%s stateTieAttachVsProcessed=%s stateTieAttachVsCooldown=%s stateTieProcessedVsCooldown=%s activeAttachAge=%s recentProcessedAge=%s nearbyInterestAge=%s recentIdleDrainAge=%s nextRetryAge=%s",
            tostring(diag.hasActiveWorkHits or 0),
            tostring(diag.activeReasonAttach or 0),
            tostring(diag.activeReasonProcessed or 0),
            tostring(diag.activeReasonNearby or 0),
            tostring(diag.activeReasonRetry or 0),
            tostring(diag.activeReasonIdle or 0),
            tostring(diag.maintenanceReasonRetry or 0),
            tostring(diag.maintenanceReasonNoAnchor or 0),
            tostring(diag.maintenanceReasonNeverDrained or 0),
            tostring(diag.maintenanceReasonBackoffDue or 0),
            tostring(diag.maintenanceReasonBackoffWait or 0),
            tostring(diag.stateQueuePendingWins or 0),
            tostring(diag.stateActiveAttachWorkWins or 0),
            tostring(diag.stateActiveRecentProcessingWins or 0),
            tostring(diag.stateActiveCooldownPendingWins or 0),
            tostring(diag.stateBackoffIdleWins or 0),
            tostring(diag.stateNearbyButIdleWins or 0),
            tostring(diag.stateMaintenanceOnlyWins or 0),
            tostring(diag.stateTieQueueVsAttach or 0),
            tostring(diag.stateTieQueueVsProcessed or 0),
            tostring(diag.stateTieQueueVsCooldown or 0),
            tostring(diag.stateTieAttachVsProcessed or 0),
            tostring(diag.stateTieAttachVsCooldown or 0),
            tostring(diag.stateTieProcessedVsCooldown or 0),
            tostring(diag.stateActiveAttachAge or 0),
            tostring(diag.stateRecentProcessedAge or 0),
            tostring(diag.stateNearbyInterestAge or 0),
            tostring(diag.stateRecentIdleDrainAge or 0),
            tostring(diag.stateNextRetryAge or 0)
        )
    )
    local durationParts = formatPhaseDurations(diag)
    if #durationParts > 0 then
        NMCore.logChannel("memory", "sp_zombie_phase_diag", table.concat(durationParts, " | "))
    end
    diag.drainEligible = 0
    diag.drainAttempted = 0
    diag.drainIneligibleSkip = 0
    diag.drainSettledSkip = 0
    diag.drainCooldownSkip = 0
    diag.queueProcessed = 0
    diag.queueDequeued = 0
    diag.queueCadenceWait = 0
    diag.queueLingering = 0
    diag.scanEnqueued = 0
    diag.interestQueuePending = 0
    diag.interestEligibleRecent = 0
    diag.interestProcessedRecent = 0
    diag.interestCooldownPending = 0
    diag.interestNearbyIdle = 0
    diag.interestBackoffIdle = 0
    diag.interestMaintenanceOnly = 0
    diag.hasActiveWorkHits = 0
    diag.activeReasonAttach = 0
    diag.activeReasonProcessed = 0
    diag.activeReasonNearby = 0
    diag.activeReasonRetry = 0
    diag.activeReasonIdle = 0
    diag.maintenanceReasonRetry = 0
    diag.maintenanceReasonNoAnchor = 0
    diag.maintenanceReasonNeverDrained = 0
    diag.maintenanceReasonBackoffDue = 0
    diag.maintenanceReasonBackoffWait = 0
    diag.stateQueuePendingWins = 0
    diag.stateActiveAttachWorkWins = 0
    diag.stateActiveRecentProcessingWins = 0
    diag.stateActiveCooldownPendingWins = 0
    diag.stateBackoffIdleWins = 0
    diag.stateNearbyButIdleWins = 0
    diag.stateMaintenanceOnlyWins = 0
    diag.stateTieQueueVsAttach = 0
    diag.stateTieQueueVsProcessed = 0
    diag.stateTieQueueVsCooldown = 0
    diag.stateTieAttachVsProcessed = 0
    diag.stateTieAttachVsCooldown = 0
    diag.stateTieProcessedVsCooldown = 0
    diag.stateActiveAttachAge = 0
    diag.stateRecentProcessedAge = 0
    diag.stateNearbyInterestAge = 0
    diag.stateRecentIdleDrainAge = 0
    diag.stateNextRetryAge = 0
    diag.eligibleDecisionSeen = 0
    diag.attachAttemptTicked = 0
    diag.attachSuccessTicked = 0
    diag.attachFailureTicked = 0
    diag.processedWithoutAttach = 0
    diag.pendingQueueCount = 0
    diag.pendingQueueOldestAge = 0
end

local function flushHelperDiag()
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("memory") == true) then
        return
    end
    local diag = NMServerSPZombieAssignmentFlow._diag
    local nowMs = nowRealMs()
    if (nowMs - (tonumber(diag.helperLastDiagLogMs) or 0)) < HELPER_DIAG_LOG_INTERVAL_MS then
        return
    end
    diag.helperLastDiagLogMs = nowMs
    local parts = {}
    for name, count in pairs(diag.helperCounters) do
        parts[#parts + 1] = string.format("%s=%d", tostring(name), tonumber(count) or 0)
        diag.helperCounters[name] = nil
    end
    if #parts > 0 then
        NMCore.logChannel("memory", "fanout_helper_diag", table.concat(parts, " | "))
    end
end

local function countZombiesWithModulo(zombies, startIndex, count, visitor)
    return NMServerZombieScanHelpers.countZombiesWithModulo(zombies, startIndex, count, visitor)
end

local function getLoadedZombieList()
    local cell = getCell and getCell() or nil
    return cell and cell.getZombieList and cell:getZombieList() or nil
end

local noteDrainSkip

local function buildEligibilityDeps(zombieKey)
    local diag = NMServerSPZombieAssignmentFlow._diag
    return {
        zombieKey = zombieKey,
        nowTick = tonumber(diag and diag.ticks or 0) or 0,
        failedRetryTicks = FAILED_RETRY_TICKS,
        failedUpdateRetryTicks = FAILED_UPDATE_RETRY_TICKS,
        updateRetryTicks = UPDATE_RETRY_TICKS,
        statelessRetryTicks = UPDATE_STATELESS_RETRY_TICKS,
        getModData = getModData,
        getStampedVariantSpec = getStampedVariantSpec,
        findAttachedProofItem = findAttachedProofItem,
        findInventoryProofItem = findInventoryProofItem,
        getRecentAttemptTick = function(key)
            return NMServerSPZombieIntakeQueue.getRecentAttemptTick(NMServerSPZombieAssignmentFlow, key)
        end
    }
end

local function noteRecentSettledSkip()
    local diag = NMServerSPZombieAssignmentFlow._diag
    if memoryDiagEnabled() then
        diag.helperCounters["sp_skip_recent_settled"] = (tonumber(diag.helperCounters["sp_skip_recent_settled"]) or 0) + 1
    end
end

local function recordRecentSettledTick(zombieKey)
    NMServerSPZombieIntakeQueue.recordRecentSettledTick(
        NMServerSPZombieAssignmentFlow,
        zombieKey,
        tonumber(NMServerSPZombieAssignmentFlow._diag and NMServerSPZombieAssignmentFlow._diag.ticks or 0) or 0
    )
end

local function clearRecentSettledTick(zombieKey)
    NMServerSPZombieIntakeQueue.clearRecentSettledTick(NMServerSPZombieAssignmentFlow, zombieKey)
end

local function shouldSkipZombieCheaply(zombieKey)
    local diag = NMServerSPZombieAssignmentFlow._diag
    local currentTick = tonumber(diag and diag.ticks or 0) or 0
    local recentSettledTick = NMServerSPZombieIntakeQueue.getRecentSettledTick(NMServerSPZombieAssignmentFlow, zombieKey)
    if recentSettledTick > 0 and (currentTick - recentSettledTick) < RECENT_SETTLED_SKIP_TICKS then
        noteDrainSkip("settled")
        noteRecentSettledSkip()
        return false, "settled"
    end
    local lastRecentAttempt = NMServerSPZombieIntakeQueue.getRecentAttemptTick(NMServerSPZombieAssignmentFlow, zombieKey)
    if lastRecentAttempt > 0 and (currentTick - lastRecentAttempt) < UPDATE_RETRY_TICKS then
        noteDrainSkip("cooldown")
        local nextRetryTick = lastRecentAttempt + UPDATE_RETRY_TICKS
        local existing = tonumber(diag.nextRetryPendingTick or 0) or 0
        if existing <= 0 or nextRetryTick < existing then
            diag.nextRetryPendingTick = nextRetryTick
        end
        return false, "cooldown"
    end
    return true, "eligible"
end

local function ensureZombieHasProofDevice(zombie, zombieKey)
    NMServerSPZombieAssignmentFlow._diag.attachAttempts = (NMServerSPZombieAssignmentFlow._diag.attachAttempts or 0) + 1
    local outcome = NMServerZombieAssignmentApplyShared.applyAssignment(zombie, {
        strategyName = STRATEGY_NAME,
        allowAttachedInventoryFallback = true,
        companionCaseSource = "sp_runtime_attach",
        companionCaseRuntimeLabel = "sp"
    })
    local realization = outcome and outcome.realization or nil
    if outcome.status == "suppressed" then
        clearRecentSettledTick(zombieKey)
        NMServerSPZombieAssignmentFlow._diag.attachSuppressed = (NMServerSPZombieAssignmentFlow._diag.attachSuppressed or 0) + 1
        NMServerSPZombieAssignmentFlow._diag.attachFailureTicked = (NMServerSPZombieAssignmentFlow._diag.attachFailureTicked or 0) + 1
        stampSelectionOutcome(zombie, getSpecForVariantId(outcome.selection and outcome.selection.variantId or ""), outcome)
        if shouldLogProofVerbose() and realization then
            logProof("sp_realization_contract", string.format("zombie=%s status=%s proof=%s attachment=%s companion=%s", tostring(realization.zombieId or ""), tostring(realization.selectionStatus or ""), tostring(realization.proofItemStatus or ""), tostring(realization.attachmentStatus or ""), tostring(realization.companionCaseStatus or "")))
        end
        return false
    end
    if outcome.status == "excluded" or outcome.status == "media_only" then
        clearRecentSettledTick(zombieKey)
        NMServerSPZombieAssignmentFlow._diag.attachExcluded = (NMServerSPZombieAssignmentFlow._diag.attachExcluded or 0) + 1
        NMServerSPZombieAssignmentFlow._diag.attachExcludedScrubbed = (NMServerSPZombieAssignmentFlow._diag.attachExcludedScrubbed or 0) + (tonumber(outcome.removedCount) or 0)
        NMServerSPZombieAssignmentFlow._diag.attachFailureTicked = (NMServerSPZombieAssignmentFlow._diag.attachFailureTicked or 0) + 1
        stampSelectionOutcome(zombie, getSpecForVariantId(outcome.selection and outcome.selection.variantId or ""), outcome)
        if shouldLogProofVerbose() and realization then
            logProof("sp_realization_contract", string.format("zombie=%s status=%s proof=%s attachment=%s companion=%s", tostring(realization.zombieId or ""), tostring(realization.selectionStatus or ""), tostring(realization.proofItemStatus or ""), tostring(realization.attachmentStatus or ""), tostring(realization.companionCaseStatus or "")))
        end
        return false
    end
    if not outcome.ok and outcome.reason == "missing_proof_location" then
        clearRecentSettledTick(zombieKey)
        NMServerSPZombieAssignmentFlow._diag.attachFailure = (NMServerSPZombieAssignmentFlow._diag.attachFailure or 0) + 1
        NMServerSPZombieAssignmentFlow._diag.locationFailures = (NMServerSPZombieAssignmentFlow._diag.locationFailures or 0) + 1
        NMServerSPZombieAssignmentFlow._diag.attachFailureTicked = (NMServerSPZombieAssignmentFlow._diag.attachFailureTicked or 0) + 1
        stampFailedOutcome(zombie, {
            spec = outcome.spec,
            selection = outcome.selection,
            item = nil,
            reason = "missing_proof_location",
            payload = outcome.payload
        })
        logProof(
            "attach_failed",
            string.format(
                "zombie=%s reason=missing_proof_location location=%s model=%s locations=%s",
                zombieDebugId(zombie),
                tostring(outcome.spec and outcome.spec.attachmentLocation or ""),
                tostring(outcome.spec and outcome.spec.modelAttachmentName or ""),
                dumpAvailableAttachmentLocations(zombie)
            ),
            true
        )
        if shouldLogProofVerbose() and realization then
            logProof("sp_realization_contract", string.format("zombie=%s status=%s proof=%s attachment=%s companion=%s", tostring(realization.zombieId or ""), tostring(realization.selectionStatus or ""), tostring(realization.proofItemStatus or ""), tostring(realization.attachmentStatus or ""), tostring(realization.companionCaseStatus or "")))
        end
        return false
    end
    if not outcome.ok then
        clearRecentSettledTick(zombieKey)
        NMServerSPZombieAssignmentFlow._diag.attachFailure = (NMServerSPZombieAssignmentFlow._diag.attachFailure or 0) + 1
        NMServerSPZombieAssignmentFlow._diag.attachFailureTicked = (NMServerSPZombieAssignmentFlow._diag.attachFailureTicked or 0) + 1
        stampFailedOutcome(zombie, outcome)
        logProof(
            "attach_failed",
            string.format(
                "zombie=%s reason=%s locations=%s",
                zombieDebugId(zombie),
                tostring(outcome.reason or "unknown"),
                dumpAvailableAttachmentLocations(zombie)
            ),
            true
        )
        if shouldLogProofVerbose() and realization then
            logProof("sp_realization_contract", string.format("zombie=%s status=%s proof=%s attachment=%s companion=%s", tostring(realization.zombieId or ""), tostring(realization.selectionStatus or ""), tostring(realization.proofItemStatus or ""), tostring(realization.attachmentStatus or ""), tostring(realization.companionCaseStatus or "")))
        end
        return false
    end
    if outcome.usedInventoryFallback == true then
        NMServerSPZombieAssignmentFlow._diag.attachInventoryFallback = (NMServerSPZombieAssignmentFlow._diag.attachInventoryFallback or 0) + 1
    end
    recordRecentSettledTick(zombieKey)
    NMServerSPZombieAssignmentFlow._diag.attachSuccess = (NMServerSPZombieAssignmentFlow._diag.attachSuccess or 0) + 1
    NMServerSPZombieAssignmentFlow._diag.attachSuccessTicked = (NMServerSPZombieAssignmentFlow._diag.attachSuccessTicked or 0) + 1
    stampAttachedOutcome(zombie, outcome)
    if shouldLogProofVerbose() and realization then
        logProof("sp_realization_contract", string.format("zombie=%s status=%s proof=%s attachment=%s companion=%s", tostring(realization.zombieId or ""), tostring(realization.selectionStatus or ""), tostring(realization.proofItemStatus or ""), tostring(realization.attachmentStatus or ""), tostring(realization.companionCaseStatus or "")))
    end
    return true
end

noteDrainSkip = function(reason)
    local diag = NMServerSPZombieAssignmentFlow._diag
    if reason == "settled" then
        diag.drainSettledSkip = (diag.drainSettledSkip or 0) + 1
    elseif reason == "ineligible" then
        diag.drainIneligibleSkip = (diag.drainIneligibleSkip or 0) + 1
    elseif reason == "cooldown" then
        diag.drainCooldownSkip = (diag.drainCooldownSkip or 0) + 1
    end
end

local function shouldProcessZombie(zombie, zombieKey)
    countProbe("sp_eval_seen")
    local allowedPrecheck, precheckReason = shouldSkipZombieCheaply(zombieKey)
    if allowedPrecheck ~= true then
        countProbe("sp_eval_precheck_skip_" .. tostring(precheckReason or "unknown"))
        return false
    end
    local evaluateStartedMs = beginPhase()
    local allowed, reason, _, _, nextRetryTick = NMServerSPZombieAssignmentEligibility.evaluateZombie(zombie, buildEligibilityDeps(zombieKey))
    recordPhase("sp_eval_zombie", evaluateStartedMs)
    if allowed ~= true then
        countProbe("sp_eval_skip_" .. tostring(reason or "unknown"))
        noteDrainSkip(reason)
        if reason == "settled" then
            recordRecentSettledTick(zombieKey)
        else
            clearRecentSettledTick(zombieKey)
        end
        if reason == "cooldown" and tonumber(nextRetryTick or 0) > 0 then
            local diag = NMServerSPZombieAssignmentFlow._diag
            local existing = tonumber(diag.nextRetryPendingTick or 0) or 0
            if existing <= 0 or tonumber(nextRetryTick) < existing then
                diag.nextRetryPendingTick = tonumber(nextRetryTick) or 0
            end
        end
        return false
    end
    local diag = NMServerSPZombieAssignmentFlow._diag
    clearRecentSettledTick(zombieKey)
    diag.drainEligible = (diag.drainEligible or 0) + 1
    diag.eligibleDecisionSeen = (diag.eligibleDecisionSeen or 0) + 1
    countProbe("sp_eval_allowed")
    return true
end

local function applyDiscoveredZombie(zombie, zombieKey)
    local diag = NMServerSPZombieAssignmentFlow._diag
    diag.drainAttempted = (diag.drainAttempted or 0) + 1
    diag.attachAttemptTicked = (diag.attachAttemptTicked or 0) + 1
    clearRecentSettledTick(zombieKey)
    NMServerSPZombieIntakeQueue.recordAttemptTick(NMServerSPZombieAssignmentFlow, zombieKey, diag.ticks)
    local applyStartedMs = beginPhase()
    local applied = ensureZombieHasProofDevice(zombie, zombieKey) == true
    recordPhase("sp_apply_assignment", applyStartedMs)
    if applied == true then
        markRecentTick("recentEligibleAttachTick")
    else
        countProbe("sp_assignment_attempt_no_active_refresh")
    end
    return applied
end

local function tryProcessZombie(zombie, source)
    local diag = NMServerSPZombieAssignmentFlow._diag
    local zombieKey = NMServerSPZombieIntakeQueue.getStableZombieQueueKey(zombie)
    if zombieKey == "" then
        return false, false, "missing_key"
    end
    if shouldProcessZombie(zombie, zombieKey) ~= true then
        return false, false, "ineligible"
    end
    diag.scanEnqueued = (diag.scanEnqueued or 0) + 1
    local applied = applyDiscoveredZombie(zombie, zombieKey) == true
    if applied == true then
        markRecentTick("recentProcessedScanTick")
    end
    return true, applied, tostring(source or "scan")
end

function NMServerSPZombieAssignmentFlow.onZombieUpdate(zombie)
    if not shouldRun() then
        return
    end
    if not isAliveZombie(zombie) then
        flushUpdateDiag()
        flushHelperDiag()
        return
    end
    -- SP intentionally uses scan-based intake; keep the executor hook shape without
    -- reintroducing update-fanout-specific attribution noise into the active path.
    if memoryDiagEnabled() then
        local diag = NMServerSPZombieAssignmentFlow._diag
        diag.helperCounters["sp_onZombieUpdate_ignored"] = (tonumber(diag.helperCounters["sp_onZombieUpdate_ignored"]) or 0) + 1
    end
    flushUpdateDiag()
    flushHelperDiag()
end

function NMServerSPZombieAssignmentFlow.hasActiveWork()
    local activeStartedMs = beginPhase()
    if not shouldRun() then
        countProbe("sp_active_reason_idle")
        recordPhase("sp_has_active_work", activeStartedMs)
        return false
    end
    local diag = NMServerSPZombieAssignmentFlow._diag
    local currentTick = tonumber(diag.ticks) or 0
    local activeAttachAge = getRecentDelta(currentTick, diag.recentEligibleAttachTick)
    local activeProcessedAge = getRecentDelta(currentTick, diag.recentProcessedScanTick)
    local nearbyInterestAge = getRecentDelta(currentTick, diag.recentNearbyPlayerTick)
    local nextRetryTick = tonumber(diag.nextRetryPendingTick) or 0
    local hasNearbyInterest = nearbyInterestAge <= NEARBY_IDLE_WINDOW_TICKS
    local retryDueSoon = nextRetryTick > 0 and math.max(0, nextRetryTick - currentTick) <= FAILED_UPDATE_RETRY_TICKS
    local hasAttachInterest = activeAttachAge <= ACTIVE_ELIGIBLE_WINDOW_TICKS
    local hasProcessedInterest = activeProcessedAge <= ACTIVE_PROCESSED_WINDOW_TICKS
    local isActive = hasAttachInterest or hasProcessedInterest or hasNearbyInterest or retryDueSoon
    diag.stateActiveAttachAge = activeAttachAge ~= math.huge and activeAttachAge or -1
    diag.stateRecentProcessedAge = activeProcessedAge ~= math.huge and activeProcessedAge or -1
    diag.stateNearbyInterestAge = nearbyInterestAge ~= math.huge and nearbyInterestAge or -1
    diag.stateNextRetryAge = nextRetryTick > 0 and math.max(0, nextRetryTick - currentTick) or 0
    if hasAttachInterest then
        diag.activeReasonAttach = (tonumber(diag.activeReasonAttach) or 0) + 1
        countProbe("sp_active_reason_active_attach")
        countProbeBucket("sp_active_window_success_age", activeAttachAge)
    elseif hasProcessedInterest then
        diag.activeReasonProcessed = (tonumber(diag.activeReasonProcessed) or 0) + 1
        countProbe("sp_active_reason_recent_processed")
        countProbeBucket("sp_active_window_success_age", activeProcessedAge)
    elseif hasNearbyInterest then
        diag.activeReasonNearby = (tonumber(diag.activeReasonNearby) or 0) + 1
        countProbe("sp_active_reason_nearby_interest")
    elseif retryDueSoon then
        diag.activeReasonRetry = (tonumber(diag.activeReasonRetry) or 0) + 1
        countProbe("sp_active_reason_retry_due_soon")
    else
        diag.activeReasonIdle = (tonumber(diag.activeReasonIdle) or 0) + 1
        countProbe("sp_active_reason_idle")
    end
    if isActive then
        diag.hasActiveWorkHits = (diag.hasActiveWorkHits or 0) + 1
    end
    recordPhase("sp_has_active_work", activeStartedMs)
    return isActive
end

function NMServerSPZombieAssignmentFlow.hasMaintenanceWork()
    local maintenanceStartedMs = beginPhase()
    if not shouldRun() then
        countProbe("sp_maintenance_reason_backoff_wait")
        recordPhase("sp_has_maintenance_work", maintenanceStartedMs)
        return false
    end
    local diag = NMServerSPZombieAssignmentFlow._diag
    local currentTick = tonumber(diag.ticks) or 0
    local nextRetryTick = tonumber(diag.nextRetryPendingTick) or 0
    local retryDueSoon = nextRetryTick > 0 and math.max(0, nextRetryTick - currentTick) <= FAILED_UPDATE_RETRY_TICKS
    if retryDueSoon then
        diag.maintenanceReasonRetry = (tonumber(diag.maintenanceReasonRetry) or 0) + 1
        countProbe("sp_maintenance_reason_retry_due")
        recordPhase("sp_has_maintenance_work", maintenanceStartedMs)
        return true
    end
    if hasPlayerAnchor() ~= true then
        diag.maintenanceReasonNoAnchor = (tonumber(diag.maintenanceReasonNoAnchor) or 0) + 1
        countProbe("sp_maintenance_reason_no_player_anchor")
        recordPhase("sp_has_maintenance_work", maintenanceStartedMs)
        return false
    end
    local recentIdleDrainAge = getRecentDelta(currentTick, diag.recentIdleDrainTick)
    diag.stateRecentIdleDrainAge = recentIdleDrainAge ~= math.huge and recentIdleDrainAge or -1
    if recentIdleDrainAge == math.huge then
        diag.maintenanceReasonNeverDrained = (tonumber(diag.maintenanceReasonNeverDrained) or 0) + 1
        countProbe("sp_maintenance_reason_never_drained")
        recordPhase("sp_has_maintenance_work", maintenanceStartedMs)
        return true
    end
    if recentIdleDrainAge >= IDLE_DRAIN_BACKOFF_TICKS then
        diag.maintenanceReasonBackoffDue = (tonumber(diag.maintenanceReasonBackoffDue) or 0) + 1
        countProbe("sp_maintenance_reason_backoff_due")
        recordPhase("sp_has_maintenance_work", maintenanceStartedMs)
        return true
    end
    diag.maintenanceReasonBackoffWait = (tonumber(diag.maintenanceReasonBackoffWait) or 0) + 1
    countProbe("sp_maintenance_reason_backoff_wait")
    recordPhase("sp_has_maintenance_work", maintenanceStartedMs)
    return false
end

function NMServerSPZombieAssignmentFlow.getNextActiveWorkCheckTick()
    if not shouldRun() then
        return math.huge
    end
    local diag = NMServerSPZombieAssignmentFlow._diag
    local currentTick = tonumber(diag.ticks) or 0
    local activeAttachAge = getRecentDelta(currentTick, diag.recentEligibleAttachTick)
    local activeProcessedAge = getRecentDelta(currentTick, diag.recentProcessedScanTick)
    local nearbyInterestAge = getRecentDelta(currentTick, diag.recentNearbyPlayerTick)
    if activeAttachAge <= ACTIVE_ELIGIBLE_WINDOW_TICKS
        or activeProcessedAge <= ACTIVE_PROCESSED_WINDOW_TICKS
        or nearbyInterestAge <= NEARBY_IDLE_WINDOW_TICKS then
        return currentTick
    end

    local nextTick = math.huge
    local nextRetryTick = tonumber(diag.nextRetryPendingTick) or 0
    if nextRetryTick > 0 then
        nextTick = math.min(nextTick, math.max(currentTick, nextRetryTick - FAILED_UPDATE_RETRY_TICKS))
    end

    local recentIdleDrainTick = tonumber(diag.recentIdleDrainTick) or 0
    if recentIdleDrainTick <= 0 then
        nextTick = math.min(nextTick, currentTick)
    else
        nextTick = math.min(nextTick, math.max(currentTick, recentIdleDrainTick + IDLE_DRAIN_BACKOFF_TICKS))
    end

    return nextTick
end

function NMServerSPZombieAssignmentFlow.observeSchedulerTick(tickStep)
    local diag = NMServerSPZombieAssignmentFlow._diag
    diag.ticks = (tonumber(diag.ticks) or 0) + math.max(1, tonumber(tickStep) or 1)
end

function NMServerSPZombieAssignmentFlow.getSchedulingState()
    if not shouldRun() then
        return "maintenance_only"
    end
    local diag = NMServerSPZombieAssignmentFlow._diag
    local currentTick = tonumber(diag.ticks) or 0
    local activeAttachAge = getRecentDelta(currentTick, diag.recentEligibleAttachTick)
    local activeProcessedAge = getRecentDelta(currentTick, diag.recentProcessedScanTick)
    local nearbyInterestAge = getRecentDelta(currentTick, diag.recentNearbyPlayerTick)
    local nextRetryTick = tonumber(diag.nextRetryPendingTick) or 0
    local nextRetryAge = nextRetryTick > 0 and math.max(0, nextRetryTick - currentTick) or 0
    local activeAttach = activeAttachAge <= ACTIVE_ELIGIBLE_WINDOW_TICKS or nearbyInterestAge <= NEARBY_IDLE_WINDOW_TICKS
    local activeProcessed = activeProcessedAge <= ACTIVE_PROCESSED_WINDOW_TICKS
    local cooldownPending = nextRetryTick > 0 and nextRetryAge <= COOLDOWN_INTEREST_WINDOW_TICKS
    local maintenanceEligible = NMServerSPZombieAssignmentFlow.hasMaintenanceWork and NMServerSPZombieAssignmentFlow.hasMaintenanceWork() == true
    diag.stateActiveAttachAge = activeAttachAge ~= math.huge and activeAttachAge or -1
    diag.stateRecentProcessedAge = activeProcessedAge ~= math.huge and activeProcessedAge or -1
    local recentIdleDrainAge = getRecentDelta(currentTick, diag.recentIdleDrainTick)
    diag.stateRecentIdleDrainAge = recentIdleDrainAge ~= math.huge and recentIdleDrainAge or -1
    diag.stateNextRetryAge = nextRetryAge
    diag.pendingQueueCount = 0
    diag.pendingQueueOldestAge = 0
    if activeAttach then
        diag.stateActiveAttachWorkWins = (diag.stateActiveAttachWorkWins or 0) + 1
        return "active_attach_work"
    end
    if activeProcessed then
        diag.stateActiveRecentProcessingWins = (diag.stateActiveRecentProcessingWins or 0) + 1
        return "active_recent_processing"
    end
    if cooldownPending then
        diag.stateActiveCooldownPendingWins = (diag.stateActiveCooldownPendingWins or 0) + 1
        return "active_cooldown_pending"
    end
    if maintenanceEligible then
        diag.stateBackoffIdleWins = (diag.stateBackoffIdleWins or 0) + 1
        return "maintenance_backoff_due"
    end
    diag.stateMaintenanceOnlyWins = (diag.stateMaintenanceOnlyWins or 0) + 1
    return "maintenance_only"
end

function NMServerSPZombieAssignmentFlow.onTick(tickStep)
    if not shouldRun() then
        return
    end
    local diag = NMServerSPZombieAssignmentFlow._diag
    diag.nextRetryPendingTick = 0
    if (diag.ticks % SCAN_INTERVAL_TICKS) == 0 then
        local collectStartedMs = beginPhase()
        local players = collectScanPlayers()
        recordPhase("sp_collect_players", collectStartedMs)
        diag.scanCalls = (diag.scanCalls or 0) + 1
        if memoryDiagEnabled() then
            diag.helperCounters["sp_scan.playerAnchors." .. tostring(#players)] = (tonumber(diag.helperCounters["sp_scan.playerAnchors." .. tostring(#players)]) or 0) + 1
        end
        if #players > 0 then
            local attemptsRemaining = (tonumber(tickStep) or 0) <= 30 and ACTIVE_DRAIN_LIMIT or MAINTENANCE_DRAIN_LIMIT
            local loadedScanLimit = (tonumber(tickStep) or 0) <= 30 and ACTIVE_DRAIN_LIMIT or LOADED_SWEEP_LIMIT
            local directAttempted = 0
            local directApplied = 0
            local discoveredNearby = 0
            local zombies = getLoadedZombieList()
            if zombies and zombies.size then
                local zombieCount = zombies:size()
                if zombieCount > 0 then
                    local scanStartedMs = beginPhase()
                    local startIndex = tonumber(diag.listCursor) or 0
                    local seenLoaded = 0
                    countProbe("sp_loaded_zombie_list_sweep")
                    local swept = countZombiesWithModulo(zombies, startIndex, loadedScanLimit, function(zombie)
                        seenLoaded = seenLoaded + 1
                        countProbe("sp_loaded_zombie_list_seen")
                        if isAliveZombie(zombie) and isZombieNearAnyPlayer(zombie, players) then
                            discoveredNearby = discoveredNearby + 1
                            countProbe("sp_loaded_zombie_list_nearby")
                            if attemptsRemaining > 0 and directAttempted < SCAN_ZOMBIE_LIMIT then
                                local attempted, applied = tryProcessZombie(zombie, "scan_loaded_zombie_list")
                                if attempted == true then
                                    directAttempted = directAttempted + 1
                                    attemptsRemaining = attemptsRemaining - 1
                                    countProbe("sp_loaded_zombie_list_attempted")
                                end
                                if applied == true then
                                    directApplied = directApplied + 1
                                    countProbe("sp_loaded_zombie_list_applied")
                                elseif attempted == true then
                                    countProbe("sp_loaded_zombie_list_apply_failed")
                                end
                            end
                        end
                    end)
                    recordPhase("sp_loaded_zombie_list_sweep", scanStartedMs)
                    diag.scanLoadedSweep = (diag.scanLoadedSweep or 0) + swept
                    if zombieCount > 0 then
                        diag.listCursor = (startIndex + swept) % zombieCount
                    else
                        diag.listCursor = 0
                    end
                    if memoryDiagEnabled() then
                        diag.helperCounters["sp_loaded_zombie_list_sweep"] = (tonumber(diag.helperCounters["sp_loaded_zombie_list_sweep"]) or 0) + 1
                        diag.helperCounters["sp_loaded_zombie_list_seen"] = (tonumber(diag.helperCounters["sp_loaded_zombie_list_seen"]) or 0) + seenLoaded
                        diag.helperCounters["sp_loaded_zombie_list_nearby"] = (tonumber(diag.helperCounters["sp_loaded_zombie_list_nearby"]) or 0) + discoveredNearby
                        diag.helperCounters["sp_loaded_zombie_list_attempted"] = (tonumber(diag.helperCounters["sp_loaded_zombie_list_attempted"]) or 0) + directAttempted
                        diag.helperCounters["sp_loaded_zombie_list_applied"] = (tonumber(diag.helperCounters["sp_loaded_zombie_list_applied"]) or 0) + directApplied
                        diag.helperCounters["sp_loaded_zombie_list_apply_failed"] = (tonumber(diag.helperCounters["sp_loaded_zombie_list_apply_failed"]) or 0) + math.max(0, directAttempted - directApplied)
                        diag.helperCounters["sp_loaded_zombie_list.total." .. tostring(zombieCount)] = (tonumber(diag.helperCounters["sp_loaded_zombie_list.total." .. tostring(zombieCount)]) or 0) + 1
                    end
                else
                    countProbe("sp_loaded_zombie_list_empty")
                    if memoryDiagEnabled() then
                        diag.helperCounters["sp_loaded_zombie_list_empty"] = (tonumber(diag.helperCounters["sp_loaded_zombie_list_empty"]) or 0) + 1
                    end
                end
            else
                countProbe("sp_loaded_zombie_list_unavailable")
                if memoryDiagEnabled() then
                    diag.helperCounters["sp_loaded_zombie_list_unavailable"] = (tonumber(diag.helperCounters["sp_loaded_zombie_list_unavailable"]) or 0) + 1
                end
            end
            diag.scanCandidates = (diag.scanCandidates or 0) + discoveredNearby
            diag.scanNearby = (diag.scanNearby or 0) + discoveredNearby
            markRecentTick("recentIdleDrainTick")
            if directApplied > 0 then
                diag.zeroEligibleDrainStreak = 0
                markRecentTick("recentNearbyPlayerTick")
                markRecentTick("recentProcessedScanTick")
                countProbe("sp_nearby_active_refresh")
                countProbe("sp_success_active_refresh")
            elseif discoveredNearby > 0 then
                diag.zeroEligibleDrainStreak = (tonumber(diag.zeroEligibleDrainStreak) or 0) + 1
                countProbe("sp_nearby_idle_no_active_refresh")
                countProbe("sp_success_no_extended_active_refresh")
            else
                diag.zeroEligibleDrainStreak = 0
                countProbe("sp_nearby_empty_no_active_refresh")
                countProbe("maintenance_only_settled_scan")
            end
        elseif memoryDiagEnabled() then
            local key = string.format("sp_scan.empty players=%s", tostring(#players))
            diag.helperCounters[key] = (tonumber(diag.helperCounters[key]) or 0) + 1
        end
    end
    if (diag.ticks % HEARTBEAT_TICKS) ~= 0 then
        flushUpdateDiag()
        flushHelperDiag()
        return
    end
    flushUpdateDiag()
    flushHelperDiag()
end

return NMServerSPZombieAssignmentFlow
