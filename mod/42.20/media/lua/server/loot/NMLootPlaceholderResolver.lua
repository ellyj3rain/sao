-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
require "slot/NMWorldItemVisuals"
require "loot/NMManagedSpawnCatalog"
require "loot/NMLootDebugHelpers"
require "loot/NMLootResolvedPools"

NMLootPlaceholderResolver = NMLootPlaceholderResolver or {}

local resolver = NMLootPlaceholderResolver

local MEDIA_CATEGORY_ORDER = NMManagedSpawnCatalog.getMediaCategoryOrder and NMManagedSpawnCatalog.getMediaCategoryOrder()
    or { "cassettes", "vinyl", "cds" }
local DEVICE_CATEGORY_ORDER = NMManagedSpawnCatalog.getDeviceCategoryOrder and NMManagedSpawnCatalog.getDeviceCategoryOrder()
    or { "walkman", "boombox", "cdplayer", "recordplayer" }
local ROUTE_ORDER = NMLootResolvedPools.getRouteOrder and NMLootResolvedPools.getRouteOrder()
    or { "standard", "topUp" }

local MAX_PLACEHOLDER_REPLACEMENTS_PER_CONTAINER = 16
local DIRECT_RECOVERY_ALLOWS_DEVICES = false
local DEVICE_DUPLICATE_CAPS_PER_CONTAINER = {
    boombox = 1,
    recordplayer = 1
}
local DIRECT_REALIZATION_CATEGORY_ORDER = {
    cassettes = { "cassettes", "cds", "vinyl" },
    cds = { "cds", "cassettes", "vinyl" },
    vinyl = { "vinyl", "cds", "cassettes" },
    walkman = { "walkman", "cdplayer", "boombox", "recordplayer" },
    boombox = { "boombox", "cdplayer", "walkman", "recordplayer" },
    cdplayer = { "cdplayer", "walkman", "boombox", "recordplayer" },
    recordplayer = { "recordplayer", "boombox", "cdplayer", "walkman" }
}

local MEDIA_PLACEHOLDER_BY_CATEGORY_SOURCE = {
    standard = {
        cassettes = "NewMusic.LootRepMediaTape",
        vinyl = "NewMusic.LootRepMediaWax",
        cds = "NewMusic.LootRepMediaDisc"
    },
    topUp = {
        cassettes = "NewMusic.LootRepMediaTapeStoreTopUp",
        vinyl = "NewMusic.LootRepMediaWaxStoreTopUp",
        cds = "NewMusic.LootRepMediaDiscStoreTopUp"
    }
}

local DEVICE_PLACEHOLDER_BY_CATEGORY_SOURCE = {
    standard = {
        walkman = "NewMusic.LootRepDeviceWalkman",
        boombox = "NewMusic.LootRepDeviceBoombox",
        cdplayer = "NewMusic.LootRepDeviceCDPlayer",
        recordplayer = "NewMusic.LootRepDeviceRecordPlayer"
    },
    topUp = {
        walkman = "NewMusic.LootRepDeviceWalkmanStoreTopUp",
        boombox = "NewMusic.LootRepDeviceBoomboxStoreTopUp",
        cdplayer = "NewMusic.LootRepDeviceCDPlayerStoreTopUp",
        recordplayer = "NewMusic.LootRepDeviceRecordPlayerStoreTopUp"
    }
}

local PLACEHOLDER_METADATA_BY_FULLTYPE = {}
for source, mapping in pairs(MEDIA_PLACEHOLDER_BY_CATEGORY_SOURCE) do
    for category, fullType in pairs(mapping) do
        PLACEHOLDER_METADATA_BY_FULLTYPE[fullType] = {
            kind = "media",
            category = category,
            source = source
        }
    end
end
for source, mapping in pairs(DEVICE_PLACEHOLDER_BY_CATEGORY_SOURCE) do
    for category, fullType in pairs(mapping) do
        PLACEHOLDER_METADATA_BY_FULLTYPE[fullType] = {
            kind = "device",
            category = category,
            source = source
        }
    end
end

local function newRouteBuckets()
    local routes = {}
    for i = 1, #ROUTE_ORDER do
        local route = ROUTE_ORDER[i]
        routes[route] = {
            media = {},
            devices = {}
        }
        for j = 1, #MEDIA_CATEGORY_ORDER do
            routes[route].media[MEDIA_CATEGORY_ORDER[j]] = {}
        end
        for j = 1, #DEVICE_CATEGORY_ORDER do
            routes[route].devices[DEVICE_CATEGORY_ORDER[j]] = {}
        end
    end
    return routes
end

local function newState()
    return {
        configured = false,
        cacheKey = "",
        policy = {
            casesEnabled = true,
            ostEnabled = true
        },
        routes = newRouteBuckets(),
        replacementStats = {
            replaced = 0,
            failed = 0,
            policyRejected = 0,
            policySkipped = 0,
            capped = 0
        }
    }
end

local state = newState()

local function logLoot(tag, detail)
    if NMLootDebugHelpers and NMLootDebugHelpers.logLoot then
        NMLootDebugHelpers.logLoot(tag or "placeholder", detail or "")
    end
end

local function addResolvedItem(container, fullType)
    if NMWorldItemVisuals and NMWorldItemVisuals.addItemWithVisual then
        local item = select(1, NMWorldItemVisuals.addItemWithVisual(container, fullType))
        if item then
            return item
        end
    end
    return container and container.AddItem and container:AddItem(fullType) or nil
end

local function removeContainerItem(container, item)
    if sendRemoveItemFromContainer then
        pcall(sendRemoveItemFromContainer, container, item)
    end
    if container and container.DoRemoveItem then
        container:DoRemoveItem(item)
        return true
    end
    if container and container.Remove then
        container:Remove(item)
        return true
    end
    return false
end

local function resolveDeviceDuplicateCap(category, source)
    if tostring(source or "") == "topUp" then
        return 0
    end
    return tonumber(DEVICE_DUPLICATE_CAPS_PER_CONTAINER[tostring(category or "")]) or 0
end

local function getRouteUnits(source, kind, category)
    local routeState = state.routes[tostring(source or "standard")] or state.routes.standard
    local resolvedKind = tostring(kind or "media")
    if resolvedKind == "device" then
        resolvedKind = "devices"
    elseif resolvedKind == "media" then
        resolvedKind = "media"
    end
    local bucket = routeState and routeState[resolvedKind] or nil
    return bucket and bucket[tostring(category or "")] or nil
end

local function normalizeSourceKey(source)
    local sourceKey = tostring(source or "standard")
    if state.routes[sourceKey] == nil then
        return "standard"
    end
    return sourceKey
end

local function getAuthorityProfile(routeClass)
    local resolvedRouteClass = tostring(routeClass or "")
    local authority = state.realizationAuthority or nil
    return authority and authority.profiles and authority.profiles[resolvedRouteClass] or nil
end

local function hasAuthorityProfileAttempts(routeClass)
    local profile = getAuthorityProfile(routeClass)
    local attempts = profile and profile.attempts or nil
    return type(attempts) == "table" and #attempts > 0
end

local function isAllowedMediaUnit(unit)
    if type(unit) ~= "table" then
        return false
    end
    if state.policy.ostEnabled ~= true and unit.isBaseZomboidOST == true then
        return false
    end
    if state.policy.casesEnabled ~= true and (unit.loadedOnly == true or unit.hasCompanionCase == true) then
        return false
    end
    return tostring(unit.spawnFullType or "") ~= ""
end

local function chooseWeightedUnit(units, excluded)
    local candidateIndexes = {}
    local totalWeight = 0
    for i = 1, #(units or {}) do
        if not (excluded and excluded[i] == true) then
            local unit = units[i]
            local weight = tonumber(unit and unit.variantWeight) or 1.0
            if weight > 0 then
                candidateIndexes[#candidateIndexes + 1] = i
                totalWeight = totalWeight + weight
            end
        end
    end
    if #candidateIndexes < 1 then
        return nil, nil
    end
    if totalWeight <= 0 then
        local pick = (ZombRand and (ZombRand(#candidateIndexes) + 1)) or 1
        local index = candidateIndexes[pick]
        return index, units[index]
    end
    local roll = ZombRandFloat and ZombRandFloat(0.0, totalWeight) or math.random() * totalWeight
    local running = 0
    for i = 1, #candidateIndexes do
        local index = candidateIndexes[i]
        local unit = units[index]
        running = running + (tonumber(unit and unit.variantWeight) or 1.0)
        if roll < running or i == #candidateIndexes then
            return index, unit
        end
    end
    local fallbackIndex = candidateIndexes[#candidateIndexes]
    return fallbackIndex, units[fallbackIndex]
end

local function stampResolvedItem(item, category, source, unit, placeholderFullType, context)
    if not (item and item.getModData) then
        return
    end
    local modData = item:getModData()
    if type(modData) ~= "table" then
        return
    end
    modData.nmLootResolved = true
    modData.nmLootCategory = tostring(category or "")
    modData.nmLootSource = tostring(source or "standard")
    modData.nmLootPlaceholderFullType = tostring(placeholderFullType or "")
    modData.nmLootResolvedFullType = tostring(item.getFullType and item:getFullType() or "")
    modData.nmLootResolvedLoadedOnly = type(unit) == "table" and unit.loadedOnly == true or false
    modData.nmLootResolvedOwner = tostring(unit and unit.owner or "")
    if type(context) == "table" then
        modData.nmLootRoomName = tostring(context.roomName or "")
        modData.nmLootContainerType = tostring(context.containerType or "")
        modData.nmLootRouteClass = tostring(context.routeClass or "")
    end
end

local function logConfiguredPools()
    for i = 1, #ROUTE_ORDER do
        local route = ROUTE_ORDER[i]
        for j = 1, #MEDIA_CATEGORY_ORDER do
            local category = MEDIA_CATEGORY_ORDER[j]
            local units = getRouteUnits(route, "media", category) or {}
            local loose = 0
            local loaded = 0
            local ost = 0
            for k = 1, #units do
                if units[k].loadedOnly == true then
                    loaded = loaded + 1
                else
                    loose = loose + 1
                end
                if units[k].isBaseZomboidOST == true then
                    ost = ost + 1
                end
            end
            logLoot(
                "placeholder.policy_pool",
                string.format(
                    "route=%s category=%s cacheKey=%s casesEnabled=%s ostEnabled=%s total=%s loose=%s loaded=%s ost=%s",
                    tostring(route),
                    tostring(category),
                    tostring(state.cacheKey or ""),
                    tostring(state.policy.casesEnabled),
                    tostring(state.policy.ostEnabled),
                    tostring(#units),
                    tostring(loose),
                    tostring(loaded),
                    tostring(ost)
                )
            )
        end
    end
end

local function resolveMediaUnit(source, category, selectionSession)
    local units = getRouteUnits(source, "media", category) or {}
    local sessionKey = tostring(source or "standard") .. "|" .. tostring(category or "")
    local sessionState = selectionSession[sessionKey]
    if not sessionState then
        sessionState = { chosen = {} }
        selectionSession[sessionKey] = sessionState
    end
    local index, unit = chooseWeightedUnit(units, sessionState.chosen)
    if unit == nil then
        index, unit = chooseWeightedUnit(units, nil)
    end
    if not isAllowedMediaUnit(unit) then
        state.replacementStats.policyRejected = state.replacementStats.policyRejected + 1
        return nil, nil
    end
    if index then
        sessionState.chosen[index] = true
    end
    return index, unit
end

local function resolveDeviceUnit(source, category)
    local units = getRouteUnits(source, "device", category) or {}
    return chooseWeightedUnit(units, nil)
end

local function addResolvedItemForKind(container, kind, category, source, selectionSession, context, placeholderFullType)
    local sourceKey = normalizeSourceKey(source)
    if tostring(kind or "media") == "device" then
        return resolver.addResolvedDeviceItemForCategory(container, category, sourceKey, context)
    end
    return resolver.addResolvedItemForCategoryFromSource(
        container,
        category,
        sourceKey,
        selectionSession or {},
        context,
        placeholderFullType
    )
end

function resolver.addResolvedItemForCategory(container, category)
    return resolver.addResolvedItemForCategoryFromSource(container, category, "standard")
end

function resolver.addResolvedItemForCategoryFromSource(container, category, source, selectionSession, context, placeholderFullType)
    local _, unit = resolveMediaUnit(source, category, selectionSession or {})
    local resolvedType = tostring(unit and unit.spawnFullType or "")
    if resolvedType == "" then
        state.replacementStats.policySkipped = state.replacementStats.policySkipped + 1
        state.replacementStats.failed = state.replacementStats.failed + 1
        logLoot(
            "placeholder.replace_decision",
            string.format(
                "outcome=skipped_no_allowed_unit source=%s category=%s placeholder=%s %s",
                tostring(source or ""),
                tostring(category or ""),
                tostring(placeholderFullType or ""),
                NMLootDebugHelpers and NMLootDebugHelpers.formatContainerContext and NMLootDebugHelpers.formatContainerContext(context) or tostring(context and context.shape or "nil")
            )
        )
        return nil
    end
    local added = addResolvedItem(container, resolvedType)
    if not added then
        state.replacementStats.failed = state.replacementStats.failed + 1
        return nil
    end
    stampResolvedItem(added, category, source, unit, placeholderFullType, context)
    if sendAddItemToContainer then
        pcall(sendAddItemToContainer, container, added)
    end
    state.replacementStats.replaced = state.replacementStats.replaced + 1
    return added
end

function resolver.addResolvedDeviceItemForCategory(container, category, source, context)
    local _, unit = resolveDeviceUnit(source, category)
    local resolvedType = tostring(unit and unit.spawnFullType or "")
    if resolvedType == "" then
        state.replacementStats.failed = state.replacementStats.failed + 1
        return nil
    end
    local added = addResolvedItem(container, resolvedType)
    if not added then
        state.replacementStats.failed = state.replacementStats.failed + 1
        return nil
    end
    stampResolvedItem(added, category, source, unit, "", context)
    if sendAddItemToContainer then
        pcall(sendAddItemToContainer, container, added)
    end
    state.replacementStats.replaced = state.replacementStats.replaced + 1
    return added
end

local function buildAvailableMediaCategoriesForRoute(source, categoryShares)
    local candidates = {}
    local totalWeight = 0
    for i = 1, #MEDIA_CATEGORY_ORDER do
        local category = MEDIA_CATEGORY_ORDER[i]
        local weight = tonumber(categoryShares and categoryShares[category]) or 0
        if weight > 0 and #(getRouteUnits(source, "media", category) or {}) > 0 then
            candidates[#candidates + 1] = {
                category = category,
                weight = weight
            }
            totalWeight = totalWeight + weight
        end
    end
    return candidates, totalWeight
end

local function buildAvailableDeviceCategoriesForRoute(source, categoryShares)
    local candidates = {}
    local totalWeight = 0
    for i = 1, #DEVICE_CATEGORY_ORDER do
        local category = DEVICE_CATEGORY_ORDER[i]
        local weight = tonumber(categoryShares and categoryShares[category]) or 0
        if weight > 0 and #(getRouteUnits(source, "device", category) or {}) > 0 then
            candidates[#candidates + 1] = {
                category = category,
                weight = weight
            }
            totalWeight = totalWeight + weight
        end
    end
    return candidates, totalWeight
end

local function pickWeightedCategory(candidates, totalWeight)
    if #candidates < 1 then
        return nil
    end
    if totalWeight <= 0 then
        local pick = (ZombRand and (ZombRand(#candidates) + 1)) or 1
        return candidates[pick].category
    end
    local roll = ZombRandFloat and ZombRandFloat(0.0, totalWeight) or math.random() * totalWeight
    local running = 0
    for i = 1, #candidates do
        running = running + (tonumber(candidates[i].weight) or 0)
        if roll < running or i == #candidates then
            return candidates[i].category
        end
    end
    return candidates[#candidates].category
end

local function buildRecoveryOrder(candidates, preferredCategory)
    local ordered = {}
    local used = {}
    if preferredCategory ~= nil and preferredCategory ~= "" then
        ordered[#ordered + 1] = preferredCategory
        used[preferredCategory] = true
    end
    table.sort(candidates, function(a, b)
        return (tonumber(a.weight) or 0) > (tonumber(b.weight) or 0)
    end)
    for i = 1, #candidates do
        local category = tostring(candidates[i].category or "")
        if category ~= "" and used[category] ~= true then
            ordered[#ordered + 1] = category
            used[category] = true
        end
    end
    return ordered
end

function resolver.recoverLiveContainerFromAuthority(container, context)
    if not state.configured then
        return nil, "not_configured"
    end
    if not (container and container.getItems) then
        return nil, "invalid_container"
    end

    local routeClass = tostring(context and context.routeClass or "")
    local authority = state.realizationAuthority or nil
    local profile = authority and authority.profiles and authority.profiles[routeClass] or nil
    if type(profile) ~= "table" then
        return nil, "no_authority_profile"
    end

    local addedCount = 0
    local addedDetails = {}
    local selectionSession = {}
    local attempts = type(profile.attempts) == "table" and profile.attempts or {}
    if #attempts < 1 then
        return nil, "no_authority_budget"
    end

    for i = 1, #attempts do
        local attempt = attempts[i]
        local sourceKey = normalizeSourceKey(attempt and attempt.route or "standard")
        local kind = tostring(attempt and attempt.kind or "media")
        local maxAdds = math.max(0, tonumber(attempt and attempt.maxAdds) or 0)
        if maxAdds > 0 and (kind ~= "device" or DIRECT_RECOVERY_ALLOWS_DEVICES == true) then
            for addIndex = 1, maxAdds do
                local candidates = nil
                local totalWeight = 0
                if kind == "device" then
                    candidates, totalWeight = buildAvailableDeviceCategoriesForRoute(sourceKey, attempt.categoryShares)
                else
                    candidates, totalWeight = buildAvailableMediaCategoriesForRoute(sourceKey, attempt.categoryShares)
                end
                local preferredCategory = pickWeightedCategory(candidates, totalWeight)
                local recoveryOrder = buildRecoveryOrder(candidates, preferredCategory)
                local added = nil
                local chosenCategory = nil
                for j = 1, #recoveryOrder do
                    local category = recoveryOrder[j]
                    added = addResolvedItemForKind(container, kind, category, sourceKey, selectionSession, context, "")
                    if added then
                        chosenCategory = category
                        break
                    end
                end
                if added then
                    addedCount = addedCount + 1
                    addedDetails[#addedDetails + 1] = table.concat({
                        tostring(sourceKey),
                        tostring(kind),
                        tostring(chosenCategory or ""),
                        tostring(addIndex),
                        tostring(maxAdds)
                    }, ":")
                else
                    break
                end
            end
        end
    end

    if addedCount < 1 then
        return nil, "no_allowed_unit"
    end

    return {
        addedCount = addedCount,
        detail = table.concat(addedDetails, ","),
        source = tostring(attempts[1] and attempts[1].route or "")
    }, nil
end

function resolver.hasAuthorityProfile(routeClass)
    return hasAuthorityProfileAttempts(routeClass)
end

function resolver.canRecoverManagedLootForRoute(routeClass)
    local resolvedRouteClass = tostring(routeClass or "")
    if resolvedRouteClass == "" or resolvedRouteClass == "other" then
        return hasAuthorityProfileAttempts(resolvedRouteClass)
    end
    return hasAuthorityProfileAttempts(resolvedRouteClass)
end

function resolver.canRouteContainManagedPlaceholders(routeClass)
    return resolver.canRecoverManagedLootForRoute(routeClass)
end

function resolver.getMediaPlaceholderFullType(category, source)
    local sourceKey = tostring(source or "standard")
    local mapping = MEDIA_PLACEHOLDER_BY_CATEGORY_SOURCE[sourceKey] or MEDIA_PLACEHOLDER_BY_CATEGORY_SOURCE.standard
    return mapping and mapping[tostring(category or "")] or nil
end

function resolver.getDevicePlaceholderFullType(category, source)
    local sourceKey = tostring(source or "")
    local mapping = DEVICE_PLACEHOLDER_BY_CATEGORY_SOURCE[sourceKey]
    return mapping and mapping[tostring(category or "")] or nil
end

function resolver.isPlaceholderFullType(fullType)
    local metadata = PLACEHOLDER_METADATA_BY_FULLTYPE[tostring(fullType or "")]
    return metadata and metadata.category or nil
end

function resolver.configure(config)
    state = newState()
    local resolved = config and config.routes and config or nil
    if not resolved then
        resolved = NMLootResolvedPools.build({
            managedSpawnMediaPool = config or {},
            managedSpawnDevicePool = {}
        })
    end
    state.policy = resolved.policy or state.policy
    state.cacheKey = tostring(resolved.cacheKey or "")
    state.realizationAuthority = resolved.realizationAuthority or {}
    for i = 1, #ROUTE_ORDER do
        local route = ROUTE_ORDER[i]
        local routeConfig = resolved.routes and resolved.routes[route] or nil
        for j = 1, #MEDIA_CATEGORY_ORDER do
            local category = MEDIA_CATEGORY_ORDER[j]
            state.routes[route].media[category] = routeConfig and routeConfig.media and routeConfig.media[category] or {}
        end
        for j = 1, #DEVICE_CATEGORY_ORDER do
            local category = DEVICE_CATEGORY_ORDER[j]
            state.routes[route].devices[category] = routeConfig and routeConfig.devices and routeConfig.devices[category] or {}
        end
    end
    state.configured = true
    logConfiguredPools()
end

function resolver.replacePlaceholdersInContainer(container, context)
    if not state.configured then
        return 0
    end
    local routeClass = tostring(context and context.routeClass or "")
    if resolver.canRouteContainManagedPlaceholders(routeClass) ~= true then
        return 0
    end
    local resolvedContainer, items = NMLootDebugHelpers.resolveMutableContainer(container, "placeholder.skip_container")
    if not (resolvedContainer and items and items.size and items.get) then
        return 0
    end

    local placeholders = {}
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local fullType = item and item.getFullType and tostring(item:getFullType() or "") or ""
        local metadata = PLACEHOLDER_METADATA_BY_FULLTYPE[fullType]
        if metadata then
            placeholders[#placeholders + 1] = {
                item = item,
                metadata = metadata,
                placeholderFullType = fullType
            }
        end
    end

    if #placeholders > MAX_PLACEHOLDER_REPLACEMENTS_PER_CONTAINER then
        state.replacementStats.capped = state.replacementStats.capped + (#placeholders - MAX_PLACEHOLDER_REPLACEMENTS_PER_CONTAINER)
        logLoot(
            "placeholder.container_cap",
            string.format(
                "count=%s cap=%s %s",
                tostring(#placeholders),
                tostring(MAX_PLACEHOLDER_REPLACEMENTS_PER_CONTAINER),
                NMLootDebugHelpers and NMLootDebugHelpers.formatContainerContext and NMLootDebugHelpers.formatContainerContext(context) or tostring(context and context.shape or "nil")
            )
        )
    end

    local replaced = 0
    local selectionSession = {}
    local deviceReplacementsByCategory = {}
    local limit = math.min(#placeholders, MAX_PLACEHOLDER_REPLACEMENTS_PER_CONTAINER)
    for i = 1, limit do
        local rep = placeholders[i]
        local added = nil
        if rep.metadata.kind == "device" then
            local category = tostring(rep.metadata.category or "")
            local duplicateCap = resolveDeviceDuplicateCap(category, rep.metadata.source)
            local existingCount = tonumber(deviceReplacementsByCategory[category]) or 0
            if duplicateCap > 0 and existingCount >= duplicateCap then
                removeContainerItem(resolvedContainer, rep.item)
                state.replacementStats.capped = state.replacementStats.capped + 1
                logLoot(
                    "placeholder.device_duplicate_cap",
                    string.format(
                        "category=%s cap=%s %s",
                        tostring(category),
                        tostring(duplicateCap),
                        NMLootDebugHelpers and NMLootDebugHelpers.formatContainerContext and NMLootDebugHelpers.formatContainerContext(context) or tostring(context and context.shape or "nil")
                    )
                )
            else
                added = resolver.addResolvedDeviceItemForCategory(resolvedContainer, category, rep.metadata.source)
                if added then
                    deviceReplacementsByCategory[category] = existingCount + 1
                end
            end
        else
            added = resolver.addResolvedItemForCategoryFromSource(
                resolvedContainer,
                rep.metadata.category,
                rep.metadata.source,
                selectionSession,
                context,
                rep.placeholderFullType
            )
        end
        if added then
            removeContainerItem(resolvedContainer, rep.item)
            replaced = replaced + 1
        end
    end
    return replaced
end

function resolver.getCoverageSnapshot()
    local snapshot = {
        replacementStats = {
            replaced = state.replacementStats.replaced,
            failed = state.replacementStats.failed,
            capped = state.replacementStats.capped
        }
    }
    for i = 1, #ROUTE_ORDER do
        local route = ROUTE_ORDER[i]
        snapshot[route] = {
            media = {},
            devices = {}
        }
        for j = 1, #MEDIA_CATEGORY_ORDER do
            local category = MEDIA_CATEGORY_ORDER[j]
            snapshot[route].media[category] = #(state.routes[route].media[category] or {})
        end
        for j = 1, #DEVICE_CATEGORY_ORDER do
            local category = DEVICE_CATEGORY_ORDER[j]
            snapshot[route].devices[category] = #(state.routes[route].devices[category] or {})
        end
    end
    return snapshot
end

function resolver.getReplacementStats()
    return {
        replaced = state.replacementStats.replaced,
        failed = state.replacementStats.failed,
        policyRejected = state.replacementStats.policyRejected,
        policySkipped = state.replacementStats.policySkipped,
        capped = state.replacementStats.capped
    }
end

function resolver.getCategoryPoolSize(category, source)
    local units = getRouteUnits(source or "standard", "media", category)
    return #(units or {})
end

function resolver.getCacheKey()
    return tostring(state.cacheKey or "")
end

return resolver
