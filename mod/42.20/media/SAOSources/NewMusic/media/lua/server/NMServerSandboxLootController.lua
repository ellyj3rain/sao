NMServerSandboxLootController = NMServerSandboxLootController or {}

require "loot/NMManagedSpawnCatalog"
require "loot/NMLootContainerClassifier"
require "loot/NMLootPlaceholderResolver"
require "loot/NMLootBuildContext"
require "loot/NMLootDebugHelpers"
require "loot/NMLootDiagnostics"
require "loot/NMLootPolicySnapshot"
require "loot/NMLootRealizationAuthority"
require "loot/NMLootResolvedPools"
require "loot/NMLootRoutePlanner"
require "loot/NMLateBuildContainerRecovery"
require "loot/NMServerLootProbe"
require "loot/NMVanillaCDLootConverter"

local controller = NMServerSandboxLootController
local formatRawSandboxLootSettings = NMLootDiagnostics.formatRawSandboxLootSettings
local lastLootProbeConfig = nil
local sandboxLootApplied = false
local sandboxLootApplying = false
local sandboxLootCacheKey = nil
local sandboxLootEpoch = 0
local sandboxLootState = "uninitialized"
local lastAcceptedSnapshot = nil
local lastObservedSnapshot = nil
local lastObservedStage = nil
local activeLootPolicy = nil
local postDistributionHookRegistered = false
local preDistributionHookRegistered = false
local fillContainerHookRegistered = false
local tickHookRegistered = false
local initGlobalModDataHookRegistered = false
local firstResidentialFillLogged = false
local pendingRebuildStage = nil
local pendingRebuildReason = nil
local pendingRebuildSnapshot = nil
local fillContainerDeferredLogEpoch = nil
local pendingRebuildLateReason = false
local lateBuildRecoveryAllowed = false
local runtimeRecoveryEnabledEpoch = nil
local provisionalBootstrapCacheKey = nil
local provisionalBootstrapObservationCount = 0
local provisionalBootstrapWaitingLogKey = nil
local pendingBootstrapSnapshot = nil
local pendingBootstrapReason = nil
local pendingBootstrapStage = nil
local fillObservedBeforeBootstrapApply = false
local fillObservedBeforeBootstrapApplyLogged = false
local postDistributionMergeObserved = false
local vanillaPickerParseLikelyCompleted = false
local bootstrapIsNewGame = nil
local SESSION_FILL_POST_PROCESS_STATE = setmetatable({}, { __mode = "k" })
local logLootBootstrap

local function shouldKeepTickHookRegistered()
    return sandboxLootApplied ~= true
        or sandboxLootApplying == true
        or pendingRebuildStage ~= nil
        or sandboxLootState == "deferred_waiting_for_authoritative_snapshot"
end

local function syncTickHookRegistration()
    if not (Events and Events.OnTick) then
        return
    end
    if shouldKeepTickHookRegistered() == true then
        if Events.OnTick.Add and not tickHookRegistered then
            Events.OnTick.Add(controller.onTick)
            tickHookRegistered = true
            if logLootBootstrap then
                logLootBootstrap("registerEventHooks_tick", "registered=true")
            end
        end
        return
    end
    if Events.OnTick.Remove and tickHookRegistered then
        Events.OnTick.Remove(controller.onTick)
        tickHookRegistered = false
        if logLootBootstrap then
            logLootBootstrap("registerEventHooks_tick", "registered=false")
        end
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
        local ts = tonumber(getTimestamp())
        if ts then
            return ts * 1000
        end
    end
    return 0
end

local function elapsedMs(startedAt)
    local startMs = tonumber(startedAt) or 0
    local delta = nowMs() - startMs
    if delta < 0 then
        return 0
    end
    return delta
end

local function isLootDebugEnabled()
    return NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("loot") == true
end

local function isLootProbeEnabled()
    return NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("loot_probe") == true
end

local function logLoot(tag, detail)
    NMLootDiagnostics.logSandboxLoot(isLootDebugEnabled(), tag, detail)
end

local function transitionLootState(nextState, reason, buildId)
    local nextValue = tostring(nextState or "unknown")
    local previousValue = tostring(sandboxLootState or "unknown")
    if previousValue == nextValue then
        return
    end
    sandboxLootState = nextValue
    logLoot(
        "sandbox.loot state",
        string.format(
            "from=%s to=%s reason=%s buildId=%s epoch=%s",
            previousValue,
            nextValue,
            tostring(reason or ""),
            tostring(buildId or ""),
            tostring(sandboxLootEpoch)
        )
    )
end

logLootBootstrap = function(stage, extra)
    logLoot(
        "sandbox.loot bootstrap",
        string.format(
            "stage=%s applied=%s applying=%s distroReady=%s extra=%s",
            tostring(stage or "unknown"),
            tostring(sandboxLootApplied),
            tostring(sandboxLootApplying),
            tostring(areDistributionTablesReady and areDistributionTablesReady() or false),
            tostring(extra or "")
        )
    )
end

local function isResidentialDresserContext(context)
    local roomLower = string.lower(tostring(context and context.roomName or ""))
    local typeLower = string.lower(tostring(context and context.containerType or ""))
    local parentLower = string.lower(tostring(context and context.parentType or ""))
    local roomLooksResidential = roomLower == "bedroom"
        or string.find(roomLower, "bed", 1, true) ~= nil
        or string.find(roomLower, "living", 1, true) ~= nil
    local typeLooksDresser = string.find(typeLower, "dresser", 1, true) ~= nil
    local parentLooksResidential = string.find(parentLower, "dresser", 1, true) ~= nil
        or string.find(parentLower, "drawers", 1, true) ~= nil
    return roomLooksResidential and (typeLooksDresser or parentLooksResidential)
end

local function buildLootProbeConfig(buildContext)
    return {
        preset = "subsystem:loot_probe",
        rawRatesText = formatRawSandboxLootSettings(buildContext.rawSandboxLoot),
        managedLootMap = buildContext.mediaFootprint.managedLootMap
    }
end

local function cloneTableShallow(source)
    if type(source) ~= "table" then
        return source
    end
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = value
    end
    return copy
end

local function buildLootPolicy(snapshot)
    return NMLootPolicySnapshot and NMLootPolicySnapshot.createFromSandboxSnapshot and NMLootPolicySnapshot.createFromSandboxSnapshot(snapshot) or nil
end

local function areDistributionTablesReady()
    local hasProcedural = ProceduralDistributions and type(ProceduralDistributions.list) == "table"
    local hasSuburbs = type(SuburbsDistributions) == "table"
    return hasProcedural or hasSuburbs
end

local function getSandboxBoolean(getter, defaultValue)
    if type(getter) ~= "function" then
        return defaultValue == true
    end
    local value = getter()
    if value == nil then
        return defaultValue == true
    end
    return value == true
end

local function getSandboxRate(getter, defaultValue)
    local value = type(getter) == "function" and tonumber(getter()) or nil
    if value == nil then
        return tonumber(defaultValue) or 0
    end
    return value
end

local function captureLootSandboxSnapshot(stage)
    local snapshot = {
        stage = tostring(stage or "unknown"),
        authority = tostring(NMCore and NMCore.getRuntimeAuthorityMode and NMCore.getRuntimeAuthorityMode() or "unknown"),
        mediaSpawnsWithCases = getSandboxBoolean(NMRuntimeConfig and NMRuntimeConfig.getMediaSpawnsWithCasesEnabled or nil, true),
        zomboidOST = getSandboxBoolean(NMRuntimeConfig and NMRuntimeConfig.getZomboidOSTEnabled or nil, true),
        convertVanilla = getSandboxBoolean(NMRuntimeConfig and NMRuntimeConfig.getConvertVanillaCDsAndCDPlayersEnabled or nil, false),
        cassettes = getSandboxRate(NMRuntimeConfig and NMRuntimeConfig.getCassettesSpawnRate or nil, 0.6),
        vinyl = getSandboxRate(NMRuntimeConfig and NMRuntimeConfig.getVinylRecordsSpawnRate or nil, 0.3),
        cds = getSandboxRate(NMRuntimeConfig and NMRuntimeConfig.getCDsSpawnRate or nil, 0.6),
        walkman = getSandboxRate(NMRuntimeConfig and NMRuntimeConfig.getWalkmanSpawnRate or nil, 0.6),
        boombox = getSandboxRate(NMRuntimeConfig and NMRuntimeConfig.getBoomboxSpawnRate or nil, 0.6),
        cdplayer = getSandboxRate(NMRuntimeConfig and NMRuntimeConfig.getCDPlayerSpawnRate or nil, 0.6),
        recordplayer = getSandboxRate(NMRuntimeConfig and NMRuntimeConfig.getRecordPlayerSpawnRate or nil, 0.6)
    }
    snapshot.cacheKey = table.concat({
        "cases=" .. tostring(snapshot.mediaSpawnsWithCases),
        "ost=" .. tostring(snapshot.zomboidOST),
        "convertVanilla=" .. tostring(snapshot.convertVanilla),
        "cassettes=" .. tostring(snapshot.cassettes),
        "vinyl=" .. tostring(snapshot.vinyl),
        "cds=" .. tostring(snapshot.cds),
        "walkman=" .. tostring(snapshot.walkman),
        "boombox=" .. tostring(snapshot.boombox),
        "cdplayer=" .. tostring(snapshot.cdplayer),
        "recordplayer=" .. tostring(snapshot.recordplayer)
    }, "|")
    snapshot.defaultLike = snapshot.mediaSpawnsWithCases == true
        and snapshot.zomboidOST == true
        and math.abs(snapshot.cassettes - 0.6) < 0.0001
        and math.abs(snapshot.vinyl - 0.6) < 0.0001
        and math.abs(snapshot.cds - 0.6) < 0.0001
        and math.abs(snapshot.walkman - 0.6) < 0.0001
        and math.abs(snapshot.boombox - 0.6) < 0.0001
        and math.abs(snapshot.cdplayer - 0.6) < 0.0001
        and math.abs(snapshot.recordplayer - 0.6) < 0.0001
    return snapshot
end

local function formatSnapshot(snapshot)
    if type(snapshot) ~= "table" then
        return "nil"
    end
    return string.format(
        "stage=%s authority=%s defaultLike=%s cacheKey=%s cases=%s ost=%s convertVanilla=%s rates={cassettes=%s vinyl=%s cds=%s walkman=%s boombox=%s cdplayer=%s recordplayer=%s}",
        tostring(snapshot.stage or "unknown"),
        tostring(snapshot.authority or "unknown"),
        tostring(snapshot.defaultLike == true),
        tostring(snapshot.cacheKey or ""),
        tostring(snapshot.mediaSpawnsWithCases),
        tostring(snapshot.zomboidOST),
        tostring(snapshot.convertVanilla),
        tostring(snapshot.cassettes),
        tostring(snapshot.vinyl),
        tostring(snapshot.cds),
        tostring(snapshot.walkman),
        tostring(snapshot.boombox),
        tostring(snapshot.cdplayer),
        tostring(snapshot.recordplayer)
    )
end

local function logSnapshot(snapshot, accepted, reason)
    logLoot(
        "sandbox.loot snapshot",
        string.format(
            "%s accepted=%s reason=%s",
            formatSnapshot(snapshot),
            tostring(accepted == true),
            tostring(reason or "")
        )
    )
end

local function logObservedSnapshot(snapshot)
    logLoot(
        "sandbox.loot snapshot_observed",
        string.format(
            "%s accepted=pending reason=pending state=%s",
            formatSnapshot(snapshot),
            tostring(sandboxLootState)
        )
    )
end

local function clearBootstrapStabilization()
    provisionalBootstrapCacheKey = nil
    provisionalBootstrapObservationCount = 0
    provisionalBootstrapWaitingLogKey = nil
end

local function clearPendingBootstrapApply()
    pendingBootstrapSnapshot = nil
    pendingBootstrapReason = nil
    pendingBootstrapStage = nil
    fillObservedBeforeBootstrapApply = false
    fillObservedBeforeBootstrapApplyLogged = false
end

local function markVanillaPickerParseLikelyCompleted(reason)
    if vanillaPickerParseLikelyCompleted == true then
        return
    end
    vanillaPickerParseLikelyCompleted = true
    logLoot(
        "sandbox.loot vanilla_picker_parse_window_passed",
        string.format(
            "reason=%s postDistributionMergeObserved=%s state=%s epoch=%s",
            tostring(reason or ""),
            tostring(postDistributionMergeObserved == true),
            tostring(sandboxLootState or "unknown"),
            tostring(sandboxLootEpoch or 0)
        )
    )
end

local function shouldReparseVanillaPickerAfterBuild(stage)
    if vanillaPickerParseLikelyCompleted == true then
        return true
    end
    local currentStage = tostring(stage or "")
    return currentStage ~= "pre_distribution_merge"
        and currentStage ~= "post_distribution_merge"
        and currentStage ~= "ensure_initialized"
end

local function reparseVanillaPickerAfterDelayedBuild(stage, snapshot)
    if not (ItemPickerJava and ItemPickerJava.Parse) then
        logLoot(
            "sandbox.loot vanilla_picker_reparse_skipped",
            string.format(
                "reason=missing_ItemPickerJava_Parse stage=%s snapshot={%s}",
                tostring(stage or "unknown"),
                formatSnapshot(snapshot)
            )
        )
        return false
    end
    local startedAt = nowMs()
    logLoot(
        "sandbox.loot vanilla_picker_reparse_start",
        string.format(
            "stage=%s initSandboxLootSettings=%s snapshot={%s}",
            tostring(stage or "unknown"),
            tostring(ItemPickerJava.InitSandboxLootSettings ~= nil),
            formatSnapshot(snapshot)
        )
    )
    local okParse, parseError = pcall(ItemPickerJava.Parse)
    if okParse ~= true then
        logLoot(
            "sandbox.loot vanilla_picker_reparse_failed",
            string.format(
                "stage=%s error=%s",
                tostring(stage or "unknown"),
                tostring(parseError or "")
            )
        )
        return false
    end
    if ItemPickerJava.InitSandboxLootSettings then
        local okSettings, settingsError = pcall(ItemPickerJava.InitSandboxLootSettings)
        if okSettings ~= true then
            logLoot(
                "sandbox.loot vanilla_picker_settings_refresh_failed",
                string.format(
                    "stage=%s error=%s",
                    tostring(stage or "unknown"),
                    tostring(settingsError or "")
                )
            )
        end
    end
    logLoot(
        "sandbox.loot vanilla_picker_reparse_end",
        string.format(
            "stage=%s elapsedMs=%s",
            tostring(stage or "unknown"),
            tostring(elapsedMs(startedAt))
        )
    )
    return true
end

local function noteProvisionalBootstrapSnapshot(snapshot, stage)
    if type(snapshot) ~= "table" then
        return 0
    end
    if lastAcceptedSnapshot ~= nil then
        return 0
    end
    local currentStage = tostring(stage or snapshot.stage or "unknown")
    if currentStage == "fill_container" then
        return provisionalBootstrapObservationCount
    end
    local cacheKey = tostring(snapshot.cacheKey or "")
    if provisionalBootstrapCacheKey ~= cacheKey then
        provisionalBootstrapCacheKey = cacheKey
        provisionalBootstrapObservationCount = 1
        provisionalBootstrapWaitingLogKey = nil
    else
        provisionalBootstrapObservationCount = provisionalBootstrapObservationCount + 1
    end
    return provisionalBootstrapObservationCount
end

local function isSnapshotAuthoritative(snapshot, stage)
    if type(snapshot) ~= "table" then
        return false, "missing_snapshot"
    end
    local currentStage = tostring(stage or snapshot.stage or "unknown")
    local isSpLocal = tostring(snapshot.authority or "") == "sp_local"
    if not isSpLocal then
        return true, "non_sp_local"
    end
    if snapshot.defaultLike ~= true then
        return true, "non_default_snapshot"
    end
    if lastAcceptedSnapshot ~= nil then
        return true, "default_like_after_build"
    end
    local bootstrapObservationCount = noteProvisionalBootstrapSnapshot(snapshot, currentStage)
    if bootstrapObservationCount >= 3 and currentStage ~= "fill_container" then
        return true, "default_like_bootstrap_stable"
    end
    if currentStage == "fill_container" then
        return false, "default_like_fill_container_waiting"
    end
    return false, "awaiting_stable_bootstrap_snapshot"
end

local function clearPendingRebuild()
    pendingRebuildStage = nil
    pendingRebuildReason = nil
    pendingRebuildSnapshot = nil
    fillContainerDeferredLogEpoch = nil
    pendingRebuildLateReason = false
    syncTickHookRegistration()
end

local function resetLootBuildState()
    sandboxLootApplied = false
    sandboxLootApplying = false
    sandboxLootCacheKey = nil
    activeLootPolicy = nil
    firstResidentialFillLogged = false
    lateBuildRecoveryAllowed = false
    runtimeRecoveryEnabledEpoch = nil
    clearPendingBootstrapApply()
    if NMLootPlaceholderResolver and NMLootPlaceholderResolver.configure then
        NMLootPlaceholderResolver.configure({
            cacheKey = "invalidated",
            policy = { casesEnabled = true, ostEnabled = true },
            routes = {
                standard = { media = { cassettes = {}, vinyl = {}, cds = {} }, devices = { walkman = {}, boombox = {}, cdplayer = {}, recordplayer = {} } },
                topUp = { media = { cassettes = {}, vinyl = {}, cds = {} }, devices = { walkman = {}, boombox = {}, cdplayer = {}, recordplayer = {} } }
            }
        })
    end
    syncTickHookRegistration()
end

local function scheduleRebuild(snapshot, reason, requestedStage)
    resetLootBuildState()
    pendingRebuildSnapshot = snapshot
    pendingRebuildReason = tostring(reason or "")
    pendingRebuildLateReason = tostring(reason or "") == "late_authoritative_snapshot"
    local requestedStageValue = tostring(requestedStage or snapshot and snapshot.stage or lastObservedStage or "retry_tick")
    if requestedStageValue == "fill_container" then
        requestedStageValue = "retry_tick_after_fill_snapshot"
    end
    pendingRebuildStage = requestedStageValue
    transitionLootState("pending_rebuild_after_snapshot", reason, sandboxLootEpoch)
    logLoot(
        "sandbox.loot rebuild_scheduled",
        string.format(
            "epoch=%s reason=%s requestedStage=%s snapshot={%s}",
            tostring(sandboxLootEpoch),
            tostring(reason or ""),
            tostring(pendingRebuildStage or ""),
            formatSnapshot(snapshot)
        )
    )
    syncTickHookRegistration()
end

local function deferUntilAuthoritativeSnapshot(reason, snapshot)
    resetLootBuildState()
    pendingRebuildSnapshot = snapshot
    pendingRebuildReason = tostring(reason or "")
    pendingRebuildStage = nil
    if lastAcceptedSnapshot == nil then
        pendingBootstrapSnapshot = cloneTableShallow(snapshot)
        pendingBootstrapReason = tostring(reason or "")
        pendingBootstrapStage = tostring(snapshot and snapshot.stage or lastObservedStage or "bootstrap_waiting_for_authoritative_snapshot")
    end
    transitionLootState("deferred_waiting_for_authoritative_snapshot", reason, sandboxLootEpoch)
    syncTickHookRegistration()
end

local function invalidateLootBuild(reason, snapshot)
    clearPendingRebuild()
    resetLootBuildState()
    logLoot(
        "sandbox.loot epoch_invalidate",
        string.format(
            "epoch=%s reason=%s snapshot={%s}",
            tostring(sandboxLootEpoch),
            tostring(reason or ""),
            formatSnapshot(snapshot)
        )
    )
    syncTickHookRegistration()
end

local function observeSnapshot(stage)
    local previousCacheKey = lastObservedSnapshot and lastObservedSnapshot.cacheKey or nil
    local previousStage = lastObservedStage
    local snapshot = captureLootSandboxSnapshot(stage)
    lastObservedSnapshot = snapshot
    lastObservedStage = tostring(stage or "unknown")
    if previousCacheKey ~= snapshot.cacheKey or previousStage ~= lastObservedStage then
        logObservedSnapshot(snapshot)
    end
    if lastAcceptedSnapshot and lastAcceptedSnapshot.cacheKey ~= snapshot.cacheKey then
        local authoritative, reason = isSnapshotAuthoritative(snapshot, stage)
        if authoritative == true then
            scheduleRebuild(snapshot, "snapshot_changed_" .. tostring(reason or ""), stage or snapshot.stage)
        else
            invalidateLootBuild("snapshot_changed", snapshot)
            deferUntilAuthoritativeSnapshot(reason or "snapshot_changed_waiting", snapshot)
        end
    elseif sandboxLootApplied ~= true
        and sandboxLootApplying ~= true
        and sandboxLootState == "deferred_waiting_for_authoritative_snapshot"
    then
        local authoritative, reason = isSnapshotAuthoritative(snapshot, stage)
        if authoritative == true then
            scheduleRebuild(snapshot, "bootstrap_snapshot_ready_" .. tostring(reason or ""), stage or snapshot.stage)
        end
    end
    return snapshot
end

local function executeAcceptedLootBuild(snapshot, stage, buildId, distributionAuditEnabled, totalStartedAt, buildWasLate)
    local vanillaPickerReparseRequired = shouldReparseVanillaPickerAfterBuild(stage)
    buildWasLate = buildWasLate == true
    clearPendingRebuild()
    clearBootstrapStabilization()
    clearPendingBootstrapApply()
    local lootPolicy = buildLootPolicy(snapshot)
    activeLootPolicy = NMLootPolicySnapshot and NMLootPolicySnapshot.clone and NMLootPolicySnapshot.clone(lootPolicy) or lootPolicy
    logLoot(
        "sandbox.loot build start",
        string.format(
            "buildId=%s stage=%s policy={%s}",
            tostring(buildId),
            tostring(stage or "unknown"),
            tostring(NMLootPolicySnapshot and NMLootPolicySnapshot.formatPolicy and NMLootPolicySnapshot.formatPolicy(activeLootPolicy) or "nil")
        )
    )
    local buildContext = NMLootBuildContext.create({
        distributionAuditEnabled = distributionAuditEnabled,
        lootPolicy = activeLootPolicy,
        buildId = tostring(buildId)
    })

    if distributionAuditEnabled then
        for i = 1, #(buildContext.childPackAuditEntries or {}) do
            logLoot("sandbox.loot child pack", buildContext.childPackAuditEntries[i])
        end
    end

    local phaseStartedAt = nowMs()
    local resolvedPools = buildContext.resolvedPools or NMLootResolvedPools.build(buildContext)
    sandboxLootCacheKey = tostring(resolvedPools and resolvedPools.cacheKey or "")
    sandboxLootEpoch = buildId
    lastAcceptedSnapshot = snapshot

    local routeResult = NMLootRoutePlanner.applyBuildContext(buildContext, {
        distributionAuditEnabled = distributionAuditEnabled,
        lootBuildEpoch = sandboxLootEpoch
    })
    local vanillaPickerReparseSucceeded = true
    if vanillaPickerReparseRequired == true then
        vanillaPickerReparseSucceeded = reparseVanillaPickerAfterDelayedBuild(stage, snapshot)
        if vanillaPickerReparseSucceeded ~= true then
            buildWasLate = true
        end
        logLoot(
            "sandbox.loot deferred_post_parse_reparse",
            string.format(
                "buildId=%s stage=%s reparseSucceeded=%s lateRecoveryRequired=%s snapshot={%s}",
                tostring(buildId),
                tostring(stage or "unknown"),
                tostring(vanillaPickerReparseSucceeded == true),
                tostring(buildWasLate == true),
                formatSnapshot(snapshot)
            )
        )
    else
        logLoot(
            "sandbox.loot eager_pre_parse",
            string.format(
                "buildId=%s stage=%s snapshot={%s}",
                tostring(buildId),
                tostring(stage or "unknown"),
                formatSnapshot(snapshot)
            )
        )
    end
    local injectBudgetMs = elapsedMs(phaseStartedAt)

    if NMLootPlaceholderResolver and NMLootPlaceholderResolver.configure then
        NMLootPlaceholderResolver.configure(resolvedPools)
    end
    if NMVanillaCDLootConverter and NMVanillaCDLootConverter.configure then
        NMVanillaCDLootConverter.configure()
    end
    lastLootProbeConfig = buildLootProbeConfig(buildContext)
    if NMServerLootProbe then
        if isLootProbeEnabled()
            and NMServerLootProbe.configure
        then
            NMServerLootProbe.configure(lastLootProbeConfig)
        elseif NMServerLootProbe.disable then
            NMServerLootProbe.disable()
        end
    end

    local vanillaCDConfig = NMVanillaCDLootConverter
        and NMVanillaCDLootConverter.getConfigurationSnapshot
        and NMVanillaCDLootConverter.getConfigurationSnapshot()
        or nil
    NMLootDiagnostics.emitSandboxLootSummary({
        distributionAuditEnabled = distributionAuditEnabled,
        activeDebugPreset = "subsystem:loot",
        lootPolicy = activeLootPolicy,
        rawSandboxLoot = buildContext.rawSandboxLoot,
        lootBuildZomboidOST = buildContext.lootBuildZomboidOST,
        filteredBaseZomboidOST = buildContext.filteredBaseZomboidOST,
        mediaSpawnsWithCases = buildContext.mediaSpawnsWithCases,
        rewrites = buildContext.rewrites,
        compatibleChildMods = buildContext.compatibleChildMods,
        boundMediaCount = buildContext.boundMediaCount,
        vehicleTargetCount = #buildContext.vehicleTargets,
        vehicleRoleCounts = buildContext.vehicleRoleCounts,
        tableShape = buildContext.tableShape,
        mediaFootprint = buildContext.mediaFootprint,
        baseCategoryCounts = buildContext.baseCategoryCounts,
        basePresentCounts = buildContext.basePresentCounts,
        baseMissingCounts = buildContext.baseMissingCounts,
        childPoolCounts = buildContext.childPoolCounts,
        managedSpawnMediaCounts = routeResult.managedSpawnMediaCounts,
        managedSpawnDeviceCounts = routeResult.managedSpawnDeviceCounts,
        resolvedPoolCounts = routeResult.resolvedPoolCounts,
        managedSpawnChildMediaCounts = buildContext.managedSpawnChildMediaCounts,
        managedSpawnMediaOwnership = routeResult.managedSpawnMediaOwnership,
        managedSpawnPlaceholders = routeResult.managedSpawnPlaceholders,
        injected = routeResult.injected,
        budgetDiagnostics = routeResult.budgetDiagnostics,
        backfill = routeResult.backfill,
        topUp = routeResult.topUp,
        standardRoute = routeResult.standardRoute,
        musicStoreCategoryWeights = routeResult.musicStoreCategoryWeights,
        musicStoreLaneWeights = routeResult.musicStoreLaneWeights,
        vanillaCDEnabled = NMVanillaCDLootConverter and NMVanillaCDLootConverter.isEnabled and NMVanillaCDLootConverter.isEnabled() == true,
        vanillaCDConfig = vanillaCDConfig,
        cdPlayerVariantCount = NMZombieDeviceVariantCatalog
            and NMZombieDeviceVariantCatalog.getVariantConfig
            and #(NMZombieDeviceVariantCatalog.getVariantConfig("cd_player").itemPool or {})
            or 0,
        bareMediaRepresentatives = buildContext.bareMediaRepresentatives,
        loadedRepresentatives = buildContext.overrides and buildContext.overrides.loadedRepresentatives or nil,
        skippedMods = buildContext.skippedMods,
        skippedFalsePositives = buildContext.skippedFalsePositives,
        baseTouched = buildContext.baseTouched,
        childTouched = buildContext.childTouched,
        elapsedMs = elapsedMs(totalStartedAt),
        lootBuildEpoch = sandboxLootEpoch,
        sandboxSnapshot = snapshot,
        allItemCount = buildContext.allItemCount,
        compatibleChildModsMs = buildContext.compatibleChildModsMs,
        overridesMs = buildContext.overridesMs,
        rewritesMs = buildContext.rewritesMs,
        vehicleTargetsMs = buildContext.vehicleTargetsMs,
        presenceIndexMs = buildContext.presenceIndexMs,
        managedPoolsMs = buildContext.managedPoolsMs,
        filterBaseOstMs = buildContext.filterBaseOstMs,
        baseSplitPresenceMs = buildContext.baseSplitPresenceMs,
        baseTouchMs = buildContext.baseTouchMs,
        childFanoutMs = buildContext.childFanoutMs,
        resolvedPoolsMs = buildContext.resolvedPoolsMs,
        injectBudgetMs = injectBudgetMs,
        baseMediaCount = buildContext.baseMediaCount,
        baseDeviceCount = buildContext.baseDeviceCount,
        childPackCount = buildContext.childPackCount
    })

    sandboxLootApplied = true
    sandboxLootApplying = false
    lateBuildRecoveryAllowed = buildWasLate
    runtimeRecoveryEnabledEpoch = lateBuildRecoveryAllowed and sandboxLootEpoch or nil
    transitionLootState("applied", "build_completed", buildId)
    if lateBuildRecoveryAllowed == true then
        logLoot(
            "sandbox.loot late_recovery_enabled",
            string.format(
                "epoch=%s stage=%s snapshot={%s}",
                tostring(sandboxLootEpoch),
                tostring(stage or "unknown"),
                formatSnapshot(snapshot)
            )
        )
    end
    logLoot(
        "sandbox.loot build end",
        string.format(
            "buildId=%s cacheKey=%s elapsedMs=%s resolvedPools={%s}",
            tostring(buildId),
            tostring(sandboxLootCacheKey),
            tostring(elapsedMs(totalStartedAt)),
            tostring(NMLootDiagnostics and NMLootDiagnostics.formatResolvedRouteCounts and NMLootDiagnostics.formatResolvedRouteCounts(resolvedPools and resolvedPools.countsByRoute and resolvedPools.countsByRoute.standard or nil) or "none")
        )
    )
    logLootBootstrap(
        "ensureInitialized_end",
        string.format(
            "result=true epoch=%s elapsedMs=%s rawRates=%s",
            tostring(sandboxLootEpoch),
            tostring(elapsedMs(totalStartedAt)),
            tostring(buildContext and buildContext.rawSandboxLoot and formatRawSandboxLootSettings(buildContext.rawSandboxLoot) or "nil")
        )
    )
    syncTickHookRegistration()
    return true
end

local function applySandboxLootControl(stage, options)
    if sandboxLootApplied or sandboxLootApplying then
        logLootBootstrap("ensureInitialized_short_circuit", "reason=already_applied_or_applying")
        return sandboxLootApplied
    end
    local allowBuildFromStage = options and options.allowBuildFromStage == true
    local requestedStage = tostring(stage or lastObservedStage or "ensure_initialized")
    sandboxLootApplying = true
    local buildId = sandboxLootEpoch + 1
    transitionLootState("building", allowBuildFromStage and "scheduled_rebuild" or "ensure_initialized", buildId)
    logLootBootstrap("ensureInitialized_start", "path=applySandboxLootControl stage=" .. requestedStage)

    local totalStartedAt = nowMs()
    local distributionAuditEnabled = isLootDebugEnabled()
    local snapshot = options and options.overrideSnapshot and cloneTableShallow(options.overrideSnapshot) or observeSnapshot(requestedStage)
    local authoritative = true
    local reason = tostring(options and options.overrideReason or "")
    if not (options and options.overrideSnapshot) then
        authoritative, reason = isSnapshotAuthoritative(snapshot, stage)
    elseif reason == "" then
        authoritative, reason = isSnapshotAuthoritative(snapshot, stage)
    end
    logSnapshot(snapshot, authoritative, reason)
    if authoritative ~= true then
        if reason == "awaiting_stable_bootstrap_snapshot" or reason == "default_like_fill_container_waiting" then
            local waitKey = table.concat({
                tostring(snapshot.cacheKey or ""),
                tostring(reason or ""),
                tostring(provisionalBootstrapObservationCount or 0)
            }, "|")
            if provisionalBootstrapWaitingLogKey ~= waitKey then
                provisionalBootstrapWaitingLogKey = waitKey
                logLoot(
                    "sandbox.loot bootstrap_waiting_for_stable_snapshot",
                    string.format(
                        "stage=%s reason=%s observations=%s provisionalCacheKey=%s snapshot={%s}",
                        tostring(stage or snapshot.stage or "unknown"),
                        tostring(reason or ""),
                        tostring(provisionalBootstrapObservationCount or 0),
                        tostring(provisionalBootstrapCacheKey or ""),
                        formatSnapshot(snapshot)
                    )
                )
            end
        end
        sandboxLootApplying = false
        deferUntilAuthoritativeSnapshot(reason, snapshot)
        logLootBootstrap("ensureInitialized_deferred", "reason=" .. tostring(reason))
        syncTickHookRegistration()
        return false
    end
    if provisionalBootstrapObservationCount > 0 then
        logLoot(
            "sandbox.loot bootstrap_stable_snapshot_accepted",
            string.format(
                "buildId=%s stage=%s reason=%s observations=%s provisionalCacheKey=%s snapshot={%s}",
                tostring(buildId),
                tostring(stage or "unknown"),
                tostring(reason),
                tostring(provisionalBootstrapObservationCount or 0),
                tostring(provisionalBootstrapCacheKey or ""),
                formatSnapshot(snapshot)
            )
        )
    end
    if tostring(stage or snapshot.stage or "") == "fill_container" and allowBuildFromStage == true then
        logLoot(
            "sandbox.loot fill_container_build_blocked",
            string.format(
                "buildId=%s reason=%s snapshot={%s}",
                tostring(buildId),
                tostring(reason),
                formatSnapshot(snapshot)
            )
        )
    end
    local buildWasLate = pendingRebuildLateReason == true
    return executeAcceptedLootBuild(snapshot, stage, buildId, distributionAuditEnabled, totalStartedAt, buildWasLate)
end

function controller.ensureInitialized()
    logLootBootstrap("ensureInitialized_enter", "public=true")
    if not areDistributionTablesReady() then
        logLootBootstrap("ensureInitialized_not_ready", "reason=distribution_tables_missing")
        return false
    end
    local currentSnapshot = observeSnapshot(lastObservedStage or "ensure_initialized")
    local currentCacheKey = tostring(currentSnapshot and currentSnapshot.cacheKey or "")
    if sandboxLootApplied and sandboxLootCacheKey ~= nil and sandboxLootCacheKey ~= "" and sandboxLootCacheKey ~= currentCacheKey then
        invalidateLootBuild("cache_key_changed", currentSnapshot)
        logLootBootstrap("ensureInitialized_cache_invalidate", "reason=sandbox_key_changed")
    end
    if sandboxLootApplied then
        transitionLootState("applied", "already_applied", sandboxLootEpoch)
        logLootBootstrap("ensureInitialized_already_applied", "result=true")
        return true
    end
    if sandboxLootApplying then
        transitionLootState("building", "already_applying", sandboxLootEpoch + 1)
        logLootBootstrap("ensureInitialized_already_applying", "result=false")
        return false
    end
    if pendingRebuildStage ~= nil then
        transitionLootState("pending_rebuild_after_snapshot", pendingRebuildReason or "pending_rebuild", sandboxLootEpoch)
        logLootBootstrap("ensureInitialized_pending", "stage=" .. tostring(pendingRebuildStage))
        return false
    end
    return applySandboxLootControl(lastObservedStage or "ensure_initialized", { allowBuildFromStage = true }) == true
end

function controller.getLootEpoch()
    return sandboxLootEpoch
end

function controller.isSandboxLootApplied()
    return sandboxLootApplied == true
end

function controller.getActiveLootPolicy()
    return NMLootPolicySnapshot and NMLootPolicySnapshot.clone and NMLootPolicySnapshot.clone(activeLootPolicy) or activeLootPolicy
end

function controller.isLateBuildRuntimeRecoveryAllowed()
    return lateBuildRecoveryAllowed == true and runtimeRecoveryEnabledEpoch == sandboxLootEpoch and sandboxLootApplied == true
end

function controller.getManagedLootMap()
    return lastLootProbeConfig and lastLootProbeConfig.managedLootMap or nil
end

function controller.refreshLootProbeForDebugState(reason)
    if not NMServerLootProbe then
        return false
    end
    if isLootProbeEnabled() ~= true then
        if NMServerLootProbe.disable then
            NMServerLootProbe.disable()
        end
        return false
    end
    if lastLootProbeConfig == nil then
        controller.ensureInitialized()
    end
    if lastLootProbeConfig and NMServerLootProbe.configure then
        NMServerLootProbe.configure(lastLootProbeConfig)
        if NMCore and NMCore.logChannel then
            NMCore.logChannel(
                "loot_probe",
                "loot_probe.refresh",
                string.format(
                    "reason=%s configured=true epoch=%s",
                    tostring(reason or ""),
                    tostring(sandboxLootEpoch or 0)
                )
            )
        end
        return true
    end
    if NMCore and NMCore.logChannel then
        NMCore.logChannel(
            "loot_probe",
            "loot_probe.refresh",
            string.format(
                "reason=%s configured=false epoch=%s hasConfig=%s",
                tostring(reason or ""),
                tostring(sandboxLootEpoch or 0),
                tostring(lastLootProbeConfig ~= nil)
            )
        )
    end
    return false
end

function controller.getRuntimeRecoveryState()
    return {
        epoch = sandboxLootEpoch,
        runtimeRecoveryAllowed = controller.isLateBuildRuntimeRecoveryAllowed(),
        lootPolicy = controller.getActiveLootPolicy(),
        managedLootMap = controller.getManagedLootMap()
    }
end

local function getRuntimeRecoveryEpoch()
    return tostring(sandboxLootEpoch or 0)
end

local function isRuntimeRecoveryAllowedForCurrentEpoch()
    return controller.isLateBuildRuntimeRecoveryAllowed() == true
end

local function buildRuntimeRecoveryState()
    return {
        epoch = sandboxLootEpoch,
        runtimeRecoveryAllowed = true,
        lootPolicy = controller.getActiveLootPolicy(),
        managedLootMap = controller.getManagedLootMap()
    }
end

function controller.onTick()
    if sandboxLootApplied == true or sandboxLootApplying == true then
        return
    end
    if not areDistributionTablesReady() then
        return
    end
    if postDistributionMergeObserved == true then
        markVanillaPickerParseLikelyCompleted("tick_after_post_distribution_merge")
    end
    if pendingRebuildStage == nil then
        if sandboxLootState == "deferred_waiting_for_authoritative_snapshot" then
            logLootBootstrap(
                "onTick_bootstrap_probe",
                string.format(
                    "state=%s observations=%s provisionalCacheKey=%s",
                    tostring(sandboxLootState or "unknown"),
                    tostring(provisionalBootstrapObservationCount or 0),
                    tostring(provisionalBootstrapCacheKey or "")
                )
            )
            controller.ensureInitialized()
        end
        return
    end
    logLootBootstrap(
        "onTick_pending_rebuild",
        string.format(
            "stage=%s reason=%s",
            tostring(pendingRebuildStage or ""),
            tostring(pendingRebuildReason or "")
        )
    )
    applySandboxLootControl(pendingRebuildStage or "retry_tick", { allowBuildFromStage = true })
end

local function isLiveFillContainer(container)
    return container and instanceof and instanceof(container, "ItemContainer") == true
end

local function getContainerFillPostProcessState(container)
    if container == nil then
        return nil
    end
    local modData = container.getModData and container:getModData() or nil
    if type(modData) == "table" then
        modData.nmFillPostProcess = modData.nmFillPostProcess or {}
        return modData.nmFillPostProcess
    end
    local state = SESSION_FILL_POST_PROCESS_STATE[container]
    if type(state) ~= "table" then
        state = {}
        SESSION_FILL_POST_PROCESS_STATE[container] = state
    end
    return state
end

local buildFullFillContext

local function stampFillPostProcessState(state, epoch, outcome, routeClass)
    if type(state) ~= "table" then
        return
    end
    state.epoch = tostring(epoch or "")
    state.outcome = tostring(outcome or "")
    state.routeClass = tostring(routeClass or "")
end

local function canAttemptPlaceholderReplacement(routeClass)
    return NMLootPlaceholderResolver
        and NMLootPlaceholderResolver.canRouteContainManagedPlaceholders
        and NMLootPlaceholderResolver.canRouteContainManagedPlaceholders(routeClass) == true
end

local function canRouteAttemptLateRecovery(routeClass)
    return NMLootPlaceholderResolver
        and NMLootPlaceholderResolver.canRecoverManagedLootForRoute
        and NMLootPlaceholderResolver.canRecoverManagedLootForRoute(routeClass) == true
end

local function buildMinimalFillContext(roomName, containerType, routeClass)
    if NMLootDebugHelpers and NMLootDebugHelpers.describeMinimalContainerContext then
        return NMLootDebugHelpers.describeMinimalContainerContext(roomName, containerType, routeClass)
    end
    return {
        roomName = tostring(roomName or ""),
        containerType = tostring(containerType or ""),
        routeClass = tostring(routeClass or "")
    }
end

buildFullFillContext = function(roomName, containerType, container, routeClass)
    if NMLootDebugHelpers and NMLootDebugHelpers.describeFullContainerContext then
        return NMLootDebugHelpers.describeFullContainerContext(roomName, containerType, container, routeClass)
    end
    return {
        roomName = tostring(roomName or ""),
        containerType = tostring(containerType or ""),
        routeClass = tostring(routeClass or ""),
        shape = tostring(container or "nil")
    }
end

local function ensureFullFillContext(context, roomName, containerType, container, routeClass)
    if type(context) == "table" and context.shape ~= nil then
        return context
    end
    return buildFullFillContext(roomName, containerType, container, routeClass)
end

local function isLootProbeFillObservationActive()
    return NMServerLootProbe
        and NMServerLootProbe.isFillObservationActive
        and NMServerLootProbe.isFillObservationActive() == true
end

local function shouldConfigureLootProbeForFill()
    return isLootProbeEnabled()
        and NMServerLootProbe
        and lastLootProbeConfig
        and NMServerLootProbe.isConfigured
        and NMServerLootProbe.isConfigured() ~= true
        and NMServerLootProbe.configure
end

local function hasAnyFillProbeWork()
    return shouldConfigureLootProbeForFill() == true
        or isLootProbeFillObservationActive() == true
end

function controller.onPreDistributionMerge()
    observeSnapshot("pre_distribution_merge")
    logLootBootstrap("OnPreDistributionMerge_controller", "handler=controller.onPreDistributionMerge")
end

function controller.onPostDistributionMerge()
    postDistributionMergeObserved = true
    observeSnapshot("post_distribution_merge")
    logLootBootstrap("OnPostDistributionMerge", "handler=controller.onPostDistributionMerge")
    controller.ensureInitialized()
end

function controller.onInitGlobalModData(isNewGame)
    bootstrapIsNewGame = isNewGame == true
    logLoot(
        "sandbox.loot init_global_mod_data",
        string.format(
            "isNewGame=%s state=%s applied=%s epoch=%s parseLikelyCompleted=%s",
            tostring(bootstrapIsNewGame == true),
            tostring(sandboxLootState or "unknown"),
            tostring(sandboxLootApplied == true),
            tostring(sandboxLootEpoch or 0),
            tostring(vanillaPickerParseLikelyCompleted == true)
        )
    )
end

function controller.onFillContainer(roomName, containerType, container)
    if not isLiveFillContainer(container) then
        return
    end
    markVanillaPickerParseLikelyCompleted("fill_container")
    local routeClass = NMLootContainerClassifier
        and NMLootContainerClassifier.classifyContainer
        and NMLootContainerClassifier.classifyContainer(roomName, containerType, container)
        or nil
    local placeholderEligible = canAttemptPlaceholderReplacement(routeClass)
    local routeRecoveryEligible = canRouteAttemptLateRecovery(routeClass)
    local runtimeRecoveryAllowed = routeRecoveryEligible == true and isRuntimeRecoveryAllowedForCurrentEpoch() == true
    local recoveryEligible = routeRecoveryEligible == true and runtimeRecoveryAllowed == true
    local probeHasWork = hasAnyFillProbeWork()
    if placeholderEligible ~= true and recoveryEligible ~= true and probeHasWork ~= true then
        return
    end

    local context = buildMinimalFillContext(roomName, containerType, routeClass)
    if firstResidentialFillLogged ~= true and isResidentialDresserContext(context) then
        context = ensureFullFillContext(context, roomName, containerType, container, routeClass)
        firstResidentialFillLogged = true
        logLootBootstrap(
            "OnFillContainer_first_residential_dresser",
            NMLootDebugHelpers and NMLootDebugHelpers.formatContainerContext and NMLootDebugHelpers.formatContainerContext(context) or tostring(context.shape or "nil")
        )
    end
    observeSnapshot("fill_container")
    if sandboxLootApplied ~= true then
        fillObservedBeforeBootstrapApply = true
        if fillObservedBeforeBootstrapApplyLogged ~= true then
            fillObservedBeforeBootstrapApplyLogged = true
            logLoot(
                "sandbox.loot fill_before_bootstrap_apply",
                string.format(
                    "state=%s pendingStage=%s snapshot={%s}",
                    tostring(sandboxLootState or "unknown"),
                    tostring(pendingBootstrapStage or ""),
                    formatSnapshot(lastObservedSnapshot)
                )
            )
        end
    end
    if sandboxLootApplied ~= true and sandboxLootApplying ~= true then
        local currentEpoch = tostring(sandboxLootEpoch or 0) .. ":" .. tostring(sandboxLootState or "unknown")
        if fillContainerDeferredLogEpoch ~= currentEpoch then
            fillContainerDeferredLogEpoch = currentEpoch
            local pendingStage = pendingRebuildStage or pendingBootstrapStage or ""
            local pendingReason = pendingRebuildReason or pendingBootstrapReason or ""
            logLoot(
                "sandbox.loot fill_container_deferred",
                string.format(
                    "state=%s pendingStage=%s pendingReason=%s snapshot={%s}",
                    tostring(sandboxLootState or "unknown"),
                    tostring(pendingStage),
                    tostring(pendingReason),
                    formatSnapshot(lastObservedSnapshot)
                )
            )
        end
    end

    local processEpoch = getRuntimeRecoveryEpoch()
    local fillPostProcessState = getContainerFillPostProcessState(container)
    local previousOutcome = fillPostProcessState and tostring(fillPostProcessState.outcome or "") or ""
    local alreadyProcessedThisEpoch = fillPostProcessState
        and tostring(fillPostProcessState.epoch or "") == processEpoch
    local shouldSkipDeepWork = alreadyProcessedThisEpoch == true
        and (previousOutcome == "skip_no_route_work"
            or previousOutcome == "skip_noop"
            or previousOutcome == "placeholder_replaced"
            or previousOutcome == "late_recovery_attempted")

    local replaced = 0
    if shouldSkipDeepWork ~= true
        and placeholderEligible == true
        and NMLootPlaceholderResolver
        and NMLootPlaceholderResolver.replacePlaceholdersInContainer
    then
        context = ensureFullFillContext(context, roomName, containerType, container, routeClass)
        replaced = NMLootPlaceholderResolver.replacePlaceholdersInContainer(container, context) or 0
        if replaced and replaced > 3 and NMLootDebugHelpers and NMLootDebugHelpers.logLoot then
            NMLootDebugHelpers.logLoot(
                "placeholder.fill_event",
                string.format(
                    "epoch=%s replaced=%s %s",
                    tostring(sandboxLootEpoch),
                    tostring(replaced),
                    NMLootDebugHelpers.formatContainerContext and NMLootDebugHelpers.formatContainerContext(context) or tostring(context.shape or "nil")
                )
            )
        end
    end
    if shouldSkipDeepWork ~= true
        and replaced < 1
        and recoveryEligible == true
        and NMLateBuildContainerRecovery
        and NMLateBuildContainerRecovery.recoverContainer
    then
        context = ensureFullFillContext(context, roomName, containerType, container, routeClass)
        NMLateBuildContainerRecovery.recoverContainer(
            roomName,
            containerType,
            container,
            context,
            buildRuntimeRecoveryState()
        )
    end
    if shouldSkipDeepWork ~= true then
        if replaced > 0 then
            stampFillPostProcessState(fillPostProcessState, processEpoch, "placeholder_replaced", context.routeClass)
        elseif placeholderEligible ~= true and recoveryEligible ~= true then
            stampFillPostProcessState(fillPostProcessState, processEpoch, "skip_no_route_work", context.routeClass)
        elseif recoveryEligible == true then
            stampFillPostProcessState(fillPostProcessState, processEpoch, "late_recovery_attempted", context.routeClass)
        else
            stampFillPostProcessState(fillPostProcessState, processEpoch, "skip_noop", context.routeClass)
        end
    end
    if shouldConfigureLootProbeForFill() == true then
        NMServerLootProbe.configure(lastLootProbeConfig)
    end
    if isLootProbeFillObservationActive() == true
        and NMServerLootProbe
        and NMServerLootProbe.onFillContainer
    then
        NMServerLootProbe.onFillContainer(roomName, containerType, container)
    end
end

function controller.registerEventHooks()
    if Events and Events.OnInitGlobalModData and Events.OnInitGlobalModData.Add and not initGlobalModDataHookRegistered then
        Events.OnInitGlobalModData.Add(controller.onInitGlobalModData)
        initGlobalModDataHookRegistered = true
        logLootBootstrap("registerEventHooks_init_global_mod_data", "registered=true")
    end
    if Events and Events.OnPreDistributionMerge and Events.OnPreDistributionMerge.Add and not preDistributionHookRegistered then
        Events.OnPreDistributionMerge.Add(controller.onPreDistributionMerge)
        preDistributionHookRegistered = true
        logLootBootstrap("registerEventHooks_pre_distribution", "registered=true")
    end
    if Events and Events.OnPostDistributionMerge and Events.OnPostDistributionMerge.Add and not postDistributionHookRegistered then
        Events.OnPostDistributionMerge.Add(controller.onPostDistributionMerge)
        postDistributionHookRegistered = true
        logLootBootstrap("registerEventHooks_post_distribution", "registered=true")
    end
    if Events and Events.OnFillContainer and Events.OnFillContainer.Add and not fillContainerHookRegistered then
        Events.OnFillContainer.Add(controller.onFillContainer)
        fillContainerHookRegistered = true
        logLootBootstrap("registerEventHooks_fill_container", "registered=true")
    end
    syncTickHookRegistration()
end

return controller
