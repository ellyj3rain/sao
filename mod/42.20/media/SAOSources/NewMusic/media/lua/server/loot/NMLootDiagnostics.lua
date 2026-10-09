require "loot/NMLootDebugHelpers"
require "loot/NMLootSandboxSettings"

NMLootDiagnostics = NMLootDiagnostics or {}

local diagnostics = NMLootDiagnostics

local CATEGORY_ORDER = NMLootSandboxSettings.CATEGORY_ORDER
local MEDIA_CATEGORY_ORDER = NMLootSandboxSettings.MEDIA_CATEGORY_ORDER
local DEVICE_CATEGORY_ORDER = NMLootSandboxSettings.DEVICE_CATEGORY_ORDER
local VEHICLE_ROLE_ORDER = NMLootSandboxSettings.VEHICLE_ROLE_ORDER
local MUSIC_STORE_TARGET_ORDER = NMLootSandboxSettings.MUSIC_STORE_TARGET_ORDER
local MUSIC_STORE_CATEGORY_FLOOR_BUDGETS = NMLootSandboxSettings.MUSIC_STORE_CATEGORY_FLOOR_BUDGETS

local LOOT_RESULT_KEYS = NMLootDebugHelpers and NMLootDebugHelpers.getResultKeys and NMLootDebugHelpers.getResultKeys() or {
    inserted = "inserted",
    increased = "increased",
    alreadyPresent = "already_present",
    replaced = "replaced",
    skipped = "skipped",
    rejected = "rejected"
}

local function countTrueEntries(map)
    local n = 0
    for _, enabled in pairs(map or {}) do
        if enabled == true then
            n = n + 1
        end
    end
    return n
end

function diagnostics.formatCountMap(map, order)
    local parts = {}
    local keys = order or CATEGORY_ORDER
    for i = 1, #keys do
        local key = keys[i]
        parts[#parts + 1] = key .. "=" .. tostring(tonumber(map and map[key]) or 0)
    end
    return table.concat(parts, " ")
end

function diagnostics.formatNameSet(nameSet)
    local names = {}
    for name, enabled in pairs(nameSet or {}) do
        if enabled == true then
            names[#names + 1] = tostring(name)
        end
    end
    table.sort(names)
    return table.concat(names, ",")
end

function diagnostics.formatStringArray(values)
    local out = {}
    for i = 1, #(values or {}) do
        out[i] = tostring(values[i])
    end
    table.sort(out)
    return table.concat(out, ",")
end

function diagnostics.formatRouteResultCounts(resultCounts)
    local orderedResults = {
        LOOT_RESULT_KEYS.inserted,
        LOOT_RESULT_KEYS.increased,
        LOOT_RESULT_KEYS.alreadyPresent,
        LOOT_RESULT_KEYS.skipped,
        LOOT_RESULT_KEYS.rejected
    }
    local parts = {}
    for i = 1, #orderedResults do
        local key = orderedResults[i]
        local count = tonumber(resultCounts and resultCounts[key]) or 0
        if count > 0 then
            parts[#parts + 1] = string.format("%s=%s", tostring(key), tostring(count))
        end
    end
    if #parts < 1 then
        return "none"
    end
    return table.concat(parts, ",")
end

function diagnostics.formatBudgetDiagnosticsSummary(data, order)
    local parts = {}
    local useOrder = order or CATEGORY_ORDER
    for i = 1, #useOrder do
        local category = useOrder[i]
        local diag = data and data[category] or nil
        if diag then
            parts[#parts + 1] = string.format(
                "%s={rate=%.3f scalar=%.3f share=%.4f rawWeight=%.3f budget=%.3f procedural[%s] vehicle[%s] mail[%s]}",
                tostring(category),
                tonumber(diag.rate) or 0,
                tonumber(diag.multiplier) or 0,
                tonumber(diag.share) or 0,
                tonumber(diag.rawWeight) or 0,
                tonumber(diag.budget) or 0,
                diagnostics.formatRouteResultCounts(diag.resultCounts and diag.resultCounts.procedural or nil),
                diagnostics.formatRouteResultCounts(diag.resultCounts and diag.resultCounts.vehicle or nil),
                diagnostics.formatRouteResultCounts(diag.resultCounts and diag.resultCounts.mail or nil)
            )
        end
    end
    return table.concat(parts, " ")
end

function diagnostics.formatRawSandboxLootSettings(raw)
    return string.format(
        "cassettes=%s vinyl=%s cds=%s walkman=%s boombox=%s cdplayer=%s recordplayer=%s",
        tostring(raw and raw.cassettes),
        tostring(raw and raw.vinyl),
        tostring(raw and raw.cds),
        tostring(raw and raw.walkman),
        tostring(raw and raw.boombox),
        tostring(raw and raw.cdplayer),
        tostring(raw and raw.recordplayer)
    )
end

function diagnostics.formatCategoryFloatMap(order, resolver)
    local parts = {}
    for i = 1, #order do
        local key = order[i]
        parts[#parts + 1] = string.format("%s=%.2f", tostring(key), tonumber(resolver(key)) or 0)
    end
    return table.concat(parts, " ")
end

function diagnostics.formatMusicStoreLaneSummary(laneByCategory)
    local parts = {}
    for i = 1, #MUSIC_STORE_TARGET_ORDER do
        local lane = MUSIC_STORE_TARGET_ORDER[i]
        local counts = laneByCategory[lane]
        if type(counts) == "table" then
            parts[#parts + 1] = string.format("%s={%s}", lane, diagnostics.formatCountMap(counts, CATEGORY_ORDER))
        end
    end
    return table.concat(parts, " ")
end

function diagnostics.formatVanillaCDProfileWeights(weights)
    return string.format(
        "cds=%s cassettes=%s vinyl=%s",
        tostring(tonumber(weights and weights.cds) or 0),
        tostring(tonumber(weights and weights.cassettes) or 0),
        tostring(tonumber(weights and weights.vinyl) or 0)
    )
end

function diagnostics.formatSourceCategorySummary(sourceRecord)
    return string.format(
        "total=%s byCategory={%s}",
        tostring(tonumber(sourceRecord and sourceRecord.total) or 0),
        diagnostics.formatCountMap(sourceRecord and sourceRecord.byCategory or {}, CATEGORY_ORDER)
    )
end

function diagnostics.formatResolvedRouteCounts(routeRecord)
    if type(routeRecord) ~= "table" then
        return "none"
    end
    return string.format(
        "media={%s} loose={%s} loaded={%s} devices={%s}",
        diagnostics.formatCountMap(routeRecord.media or {}, MEDIA_CATEGORY_ORDER),
        diagnostics.formatCountMap(routeRecord.loose or {}, MEDIA_CATEGORY_ORDER),
        diagnostics.formatCountMap(routeRecord.loaded or {}, MEDIA_CATEGORY_ORDER),
        diagnostics.formatCountMap(routeRecord.devices or {}, DEVICE_CATEGORY_ORDER)
    )
end

local function shouldEmitSandboxLootLog(distributionAuditEnabled, tag)
    if distributionAuditEnabled then
        return true
    end
    local key = tostring(tag or "")
    return key == "sandbox.loot build summary"
        or key == "sandbox.loot route summary"
        or key == "sandbox.loot timing summary"
end

local function logLoot(distributionAuditEnabled, tag, detail)
    if not shouldEmitSandboxLootLog(distributionAuditEnabled, tag) then
        return
    end
    if NMLootDebugHelpers and NMLootDebugHelpers.logLoot then
        NMLootDebugHelpers.logLoot(tag or "sandbox.loot", detail or "")
    end
end

function diagnostics.logSandboxLoot(distributionAuditEnabled, tag, detail)
    logLoot(distributionAuditEnabled == true, tag, detail)
end

function diagnostics.emitSandboxLootSummary(context)
    local distributionAuditEnabled = context.distributionAuditEnabled == true
    local rawSandboxLoot = context.rawSandboxLoot
    local lootPolicy = context.lootPolicy
    local resolvedRateFormatter = function(category)
        return NMLootSandboxSettings.resolveCategoryRate(category, lootPolicy)
    end

    logLoot(distributionAuditEnabled, "sandbox.loot raw sandbox settings", diagnostics.formatRawSandboxLootSettings(rawSandboxLoot))
    logLoot(
        distributionAuditEnabled,
        "sandbox.loot zomboid ost toggle",
        string.format(
            "pagePresent=%s keyPresent=%s rawValue=%s resolved=%s state=%s removed=%s",
            tostring(context.lootBuildZomboidOST and context.lootBuildZomboidOST.pagePresent),
            tostring(context.lootBuildZomboidOST and context.lootBuildZomboidOST.keyPresent),
            tostring(context.lootBuildZomboidOST and context.lootBuildZomboidOST.rawValue),
            tostring(context.lootBuildZomboidOST and context.lootBuildZomboidOST.enabled),
            tostring(context.lootBuildZomboidOST and context.lootBuildZomboidOST.state),
            tostring(context.filteredBaseZomboidOST)
        )
    )
    logLoot(
        distributionAuditEnabled,
        "sandbox.loot resolved rates",
        diagnostics.formatCategoryFloatMap(CATEGORY_ORDER, resolvedRateFormatter)
    )
    logLoot(distributionAuditEnabled, "sandbox.loot bound-media rewrites", tostring(context.rewrites))
    logLoot(
        distributionAuditEnabled,
        "sandbox.loot compatible child mods",
        string.format(
            "count=%s mods=%s",
            tostring(countTrueEntries(context.compatibleChildMods)),
            diagnostics.formatNameSet(context.compatibleChildMods)
        )
    )
    logLoot(
        distributionAuditEnabled,
        "sandbox.loot media case mode",
        string.format(
            "enabled=%s rewriteMode=%s rewrites=%s",
            tostring(context.mediaSpawnsWithCases),
            context.mediaSpawnsWithCases and "applied" or "skipped",
            tostring(context.rewrites)
        )
    )
    logLoot(
        distributionAuditEnabled,
        "sandbox.loot allowed vehicle targets",
        string.format(
            "total=%s glovebox=%s seatrear=%s cargo=%s uniqueItems=%s",
            tostring(context.vehicleTargetCount),
            tostring(context.vehicleRoleCounts and context.vehicleRoleCounts.glovebox),
            tostring(context.vehicleRoleCounts and context.vehicleRoleCounts.seatrear),
            tostring(context.vehicleRoleCounts and context.vehicleRoleCounts.cargo),
            tostring(context.tableShape and context.tableShape.vehicleUniqueItems)
        )
    )
    logLoot(
        distributionAuditEnabled,
        "sandbox.loot table shape",
        string.format(
            "proceduralItems=%s proceduralJunk=%s suburbsItems=%s vehicleSurfaced=%s vehicleUniqueItems=%s totalUniqueItems=%s",
            tostring(context.tableShape and context.tableShape.proceduralItems),
            tostring(context.tableShape and context.tableShape.proceduralJunk),
            tostring(context.tableShape and context.tableShape.suburbsItems),
            tostring(context.tableShape and context.tableShape.vehicleSurfaced),
            tostring(context.tableShape and context.tableShape.vehicleUniqueItems),
            tostring(context.tableShape and context.tableShape.totalUniqueItems)
        )
    )
    logLoot(distributionAuditEnabled, "sandbox.loot base zomboid ost filtered", tostring(context.filteredBaseZomboidOST))
    logLoot(
        distributionAuditEnabled,
        "sandbox.loot resolved pools",
        string.format(
            "standard={%s} topUp={%s}",
            diagnostics.formatResolvedRouteCounts(context.resolvedPoolCounts and context.resolvedPoolCounts.standard or nil),
            diagnostics.formatResolvedRouteCounts(context.resolvedPoolCounts and context.resolvedPoolCounts.topUp or nil)
        )
    )
    logLoot(
        distributionAuditEnabled,
        "sandbox.loot managed media footprint",
        string.format(
            "uniqueManaged=%s presentInMerged=%s byCategory={%s} presentByCategory={%s} oversizedRisk=%s:%s",
            tostring(context.mediaFootprint and context.mediaFootprint.uniqueManagedMedia),
            tostring(context.mediaFootprint and context.mediaFootprint.presentManagedMedia),
            diagnostics.formatCountMap(context.mediaFootprint and context.mediaFootprint.managedMediaCounts or {}, MEDIA_CATEGORY_ORDER),
            diagnostics.formatCountMap(context.mediaFootprint and context.mediaFootprint.presentManagedCounts or {}, MEDIA_CATEGORY_ORDER),
            tostring(context.mediaFootprint and context.mediaFootprint.oversizedRiskCategory ~= "" and context.mediaFootprint.oversizedRiskCategory or "none"),
            tostring(context.mediaFootprint and context.mediaFootprint.oversizedRiskCount)
        )
    )

    if distributionAuditEnabled then
        logLoot(
            distributionAuditEnabled,
            "sandbox.loot audit bindings",
            string.format(
                "boundMedia=%s rewrites=%s compatibleChildMods=%s vehicleTargets=%s",
                tostring(context.boundMediaCount),
                tostring(context.rewrites),
                tostring(countTrueEntries(context.compatibleChildMods)),
                tostring(context.vehicleTargetCount)
            )
        )
    end

    logLoot(
        distributionAuditEnabled,
        "sandbox.loot build summary",
        string.format(
            "preset=%s rawRates={%s} resolvedRates={%s} rewrites=%s ostRemoved=%s vehicleTargets=%s managedLoot={%s} managedSpawnMedia={%s} managedSpawnDevices={%s} presentManagedMedia=%s/%s",
            tostring(context.activeDebugPreset or ""),
            diagnostics.formatRawSandboxLootSettings(rawSandboxLoot),
            diagnostics.formatCategoryFloatMap(CATEGORY_ORDER, resolvedRateFormatter),
            tostring(context.rewrites),
            tostring(context.filteredBaseZomboidOST),
            tostring(context.vehicleTargetCount),
            diagnostics.formatCountMap(context.mediaFootprint and context.mediaFootprint.managedLootCounts or {}, CATEGORY_ORDER),
            diagnostics.formatCountMap(context.managedSpawnMediaCounts, MEDIA_CATEGORY_ORDER),
            diagnostics.formatCountMap(context.managedSpawnDeviceCounts, DEVICE_CATEGORY_ORDER),
            tostring(context.mediaFootprint and context.mediaFootprint.presentManagedMedia),
            tostring(context.mediaFootprint and context.mediaFootprint.uniqueManagedMedia)
        )
    )
    logLoot(
        distributionAuditEnabled,
        "sandbox.loot route summary",
        string.format(
            "standard={source=%s mediaRawWeights=%s mediaShares=%s compensatedRawWeights=%s compensatedShares=%s totalMediaBudget=%.3f} topUp={disabled=%s source=%s} diagnostics={%s}",
            diagnostics.formatSourceCategorySummary(context.injected and context.injected.bySource and context.injected.bySource.standard or nil),
            diagnostics.formatCategoryFloatMap(MEDIA_CATEGORY_ORDER, function(category)
                return context.standardRoute and context.standardRoute.mediaRawWeights and context.standardRoute.mediaRawWeights[category] or 0
            end),
            diagnostics.formatCategoryFloatMap(MEDIA_CATEGORY_ORDER, function(category)
                return context.standardRoute and context.standardRoute.mediaShares and context.standardRoute.mediaShares[category] or 0
            end),
            diagnostics.formatCategoryFloatMap(MEDIA_CATEGORY_ORDER, function(category)
                return context.standardRoute and context.standardRoute.compensatedMediaRawWeights and context.standardRoute.compensatedMediaRawWeights[category] or 0
            end),
            diagnostics.formatCategoryFloatMap(MEDIA_CATEGORY_ORDER, function(category)
                return context.standardRoute and context.standardRoute.compensatedMediaShares and context.standardRoute.compensatedMediaShares[category] or 0
            end),
            tonumber(context.standardRoute and context.standardRoute.totalMediaBudget) or 0,
            tostring(context.topUp and context.topUp.disabled == true),
            diagnostics.formatSourceCategorySummary(context.injected and context.injected.bySource and context.injected.bySource.topUp or nil),
            diagnostics.formatBudgetDiagnosticsSummary(context.budgetDiagnostics, CATEGORY_ORDER)
        )
    )
    logLoot(distributionAuditEnabled, "sandbox.loot base category counts", diagnostics.formatCountMap(context.baseCategoryCounts))
    logLoot(distributionAuditEnabled, "sandbox.loot child category counts", diagnostics.formatCountMap(context.childPoolCounts, MEDIA_CATEGORY_ORDER))
    logLoot(distributionAuditEnabled, "sandbox.loot base present counts", diagnostics.formatCountMap(context.basePresentCounts))
    logLoot(distributionAuditEnabled, "sandbox.loot base missing counts", diagnostics.formatCountMap(context.baseMissingCounts))
    logLoot(distributionAuditEnabled, "sandbox.loot music store target weights", diagnostics.formatCountMap(context.musicStoreCategoryWeights, CATEGORY_ORDER))
    logLoot(distributionAuditEnabled, "sandbox.loot music store floors", diagnostics.formatCountMap(MUSIC_STORE_CATEGORY_FLOOR_BUDGETS, CATEGORY_ORDER))
    logLoot(distributionAuditEnabled, "sandbox.loot music store lane weights", diagnostics.formatMusicStoreLaneSummary(context.musicStoreLaneWeights or {}))
    logLoot(distributionAuditEnabled, "sandbox.loot managed spawn media pool", diagnostics.formatCountMap(context.managedSpawnMediaCounts, MEDIA_CATEGORY_ORDER))
    logLoot(distributionAuditEnabled, "sandbox.loot managed spawn device pool", diagnostics.formatCountMap(context.managedSpawnDeviceCounts, DEVICE_CATEGORY_ORDER))
    logLoot(distributionAuditEnabled, "sandbox.loot managed spawn child media pool", diagnostics.formatCountMap(context.managedSpawnChildMediaCounts, MEDIA_CATEGORY_ORDER))
    logLoot(
        distributionAuditEnabled,
        "sandbox.loot managed spawn media ownership",
        string.format(
            "base={%s} child={%s}",
            diagnostics.formatCountMap(context.managedSpawnMediaOwnership and context.managedSpawnMediaOwnership.base or {}, MEDIA_CATEGORY_ORDER),
            diagnostics.formatCountMap(context.managedSpawnMediaOwnership and context.managedSpawnMediaOwnership.child or {}, MEDIA_CATEGORY_ORDER)
        )
    )
    logLoot(
        distributionAuditEnabled,
        "sandbox.loot managed spawn placeholders",
        string.format(
            "cassettes=%s vinyl=%s cds=%s",
            tostring(context.managedSpawnPlaceholders and context.managedSpawnPlaceholders.cassettes or ""),
            tostring(context.managedSpawnPlaceholders and context.managedSpawnPlaceholders.vinyl or ""),
            tostring(context.managedSpawnPlaceholders and context.managedSpawnPlaceholders.cds or "")
        )
    )
    logLoot(
        distributionAuditEnabled,
        "sandbox.loot vanilla replace",
        string.format(
            "enabled=%s mode=%s cdPlayerVariants=%s",
            tostring(context.vanillaCDEnabled == true),
            tostring(context.vanillaCDConfig and context.vanillaCDConfig.mode or "vanillaReplace"),
            tostring(context.cdPlayerVariantCount or 0)
        )
    )
    logLoot(
        distributionAuditEnabled,
        "sandbox.loot music store top-up",
        string.format(
            "active=%s standard={source=%s totalMediaBudget=%.3f} topup={%s}",
            tostring(not (context.topUp and context.topUp.disabled == true)),
            diagnostics.formatSourceCategorySummary(context.injected and context.injected.bySource and context.injected.bySource.standard or nil),
            tonumber(context.standardRoute and context.standardRoute.totalMediaBudget) or 0,
            diagnostics.formatSourceCategorySummary(context.injected and context.injected.bySource and context.injected.bySource.topUp or nil)
        )
    )
    logLoot(
        distributionAuditEnabled,
        "sandbox.loot loaded representatives",
        string.format(
            "loadedOnly=%s loadedCount=%s bareCount=%s bareItems=%s",
            tostring(countTrueEntries(context.bareMediaRepresentatives) == 0),
            tostring(countTrueEntries(context.loadedRepresentatives)),
            tostring(countTrueEntries(context.bareMediaRepresentatives)),
            diagnostics.formatNameSet(context.bareMediaRepresentatives)
        )
    )
    logLoot(
        distributionAuditEnabled,
        "sandbox.loot skipped child mods",
        string.format("count=%s mods=%s", tostring(countTrueEntries(context.skippedMods)), diagnostics.formatNameSet(context.skippedMods))
    )
    if distributionAuditEnabled then
        logLoot(
            distributionAuditEnabled,
            "sandbox.loot false-positive candidates",
            string.format(
                "count=%s items=%s",
                tostring(countTrueEntries(context.skippedFalsePositives)),
                diagnostics.formatNameSet(context.skippedFalsePositives)
            )
        )
        logLoot(
            distributionAuditEnabled,
            "sandbox.loot audit summary",
            string.format(
                "baseTouched=%s childTouched=%s injected=%s",
                tostring(context.baseTouched),
                tostring(context.childTouched),
                tostring(context.injected and context.injected.total)
            )
        )
    end

    logLoot(distributionAuditEnabled, "sandbox.loot base touch count", tostring(context.baseTouched))
    logLoot(distributionAuditEnabled, "sandbox.loot child touch count", tostring(context.childTouched))
    for i = 1, #CATEGORY_ORDER do
        local category = CATEGORY_ORDER[i]
        local diag = context.budgetDiagnostics and context.budgetDiagnostics[category] or nil
        if diag then
            logLoot(
                distributionAuditEnabled,
                "sandbox.loot category budget",
                string.format(
                    "category=%s rate=%.2f scalar=%.2f share=%.4f rawWeight=%.2f scale=%.2f laneAmp=%.2f poolSize=%s estWeight=%.2f targets={proc:%s vehicle:%s mail:%s} laneWeight={proc:%.2f vehicle:%.2f mail:%.2f} entries={proc:%s vehicle:%s mail:%s} avgTargetWeight={proc:%.3f vehicle:%.3f mail:%.3f} avgEntryWeight={proc:%.4f vehicle:%.4f mail:%.4f}",
                    tostring(category),
                    tonumber(diag.rate) or 0,
                    tonumber(diag.multiplier) or 0,
                    tonumber(diag.share) or 0,
                    tonumber(diag.rawWeight) or 0,
                    tonumber(diag.budget) or 0,
                    tonumber(diag.laneAmplifier) or 1.0,
                    tostring(tonumber(diag.poolSize) or 0),
                    tonumber(diag.estimatedWeight) or 0,
                    tostring(diag.eligibleTargets and diag.eligibleTargets.procedural or 0),
                    tostring(diag.eligibleTargets and diag.eligibleTargets.vehicle or 0),
                    tostring(diag.eligibleTargets and diag.eligibleTargets.mail or 0),
                    tonumber(diag.laneWeight and diag.laneWeight.procedural) or 0,
                    tonumber(diag.laneWeight and diag.laneWeight.vehicle) or 0,
                    tonumber(diag.laneWeight and diag.laneWeight.mail) or 0,
                    tostring(diag.injectedEntries and diag.injectedEntries.procedural or 0),
                    tostring(diag.injectedEntries and diag.injectedEntries.vehicle or 0),
                    tostring(diag.injectedEntries and diag.injectedEntries.mail or 0),
                    tonumber(diag.averageTargetWeight and diag.averageTargetWeight.procedural) or 0,
                    tonumber(diag.averageTargetWeight and diag.averageTargetWeight.vehicle) or 0,
                    tonumber(diag.averageTargetWeight and diag.averageTargetWeight.mail) or 0,
                    tonumber(diag.averageEntryWeight and diag.averageEntryWeight.procedural) or 0,
                    tonumber(diag.averageEntryWeight and diag.averageEntryWeight.vehicle) or 0,
                    tonumber(diag.averageEntryWeight and diag.averageEntryWeight.mail) or 0
                )
            )
        end
    end
    logLoot(
        distributionAuditEnabled,
        "sandbox.loot injection summary",
        string.format(
            "total=%s byCategory={%s} byRole={%s}",
            tostring(context.injected and context.injected.total),
            diagnostics.formatCountMap(context.injected and context.injected.byCategory or {}),
            diagnostics.formatCountMap(context.injected and context.injected.byRole or {}, VEHICLE_ROLE_ORDER)
        )
    )
    logLoot(
        distributionAuditEnabled,
        "sandbox.loot timing summary",
        string.format(
            "elapsedMs=%d allItems=%d compatibleModsMs=%d overridesMs=%d rewritesMs=%d vehicleTargetsMs=%d presenceIndexMs=%d managedPoolsMs=%d filterBaseOstMs=%d baseSplitPresenceMs=%d baseTouchMs=%d childFanoutMs=%d injectBudgetMs=%d baseMedia=%d baseDevices=%d childPacks=%d vehicleTargets=%d",
            tonumber(context.elapsedMs) or 0,
            tonumber(context.allItemCount) or 0,
            tonumber(context.compatibleChildModsMs) or 0,
            tonumber(context.overridesMs) or 0,
            tonumber(context.rewritesMs) or 0,
            tonumber(context.vehicleTargetsMs) or 0,
            tonumber(context.presenceIndexMs) or 0,
            tonumber(context.managedPoolsMs) or 0,
            tonumber(context.filterBaseOstMs) or 0,
            tonumber(context.baseSplitPresenceMs) or 0,
            tonumber(context.baseTouchMs) or 0,
            tonumber(context.childFanoutMs) or 0,
            tonumber(context.injectBudgetMs) or 0,
            tonumber(context.baseMediaCount) or 0,
            tonumber(context.baseDeviceCount) or 0,
            tonumber(context.childPackCount) or 0,
            tonumber(context.vehicleTargetCount) or 0
        )
    )
end

return diagnostics
