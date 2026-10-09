-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
require "loot/NMLootContainerClassifier"
require "loot/NMLootDebugHelpers"
require "loot/NMLootPlaceholderResolver"

NMLateBuildContainerRecovery = NMLateBuildContainerRecovery or {}

local recovery = NMLateBuildContainerRecovery

local SESSION_RECOVERY_STATE = setmetatable({}, { __mode = "k" })

local function logLoot(tag, detail)
    if NMLootDebugHelpers and NMLootDebugHelpers.logLoot then
        NMLootDebugHelpers.logLoot(tag or "late_recovery", detail or "")
    end
end

local function getContainerRecoveryState(container)
    if container == nil then
        return nil
    end
    local modData = container.getModData and container:getModData() or nil
    if type(modData) == "table" then
        modData.nmLateBuildRecovery = modData.nmLateBuildRecovery or {}
        return modData.nmLateBuildRecovery
    end
    local state = SESSION_RECOVERY_STATE[container]
    if type(state) ~= "table" then
        state = {}
        SESSION_RECOVERY_STATE[container] = state
    end
    return state
end

local function resolveRouteClass(roomName, containerType, container, context)
    if type(context) == "table" and tostring(context.routeClass or "") ~= "" then
        return tostring(context.routeClass)
    end
    local classified = NMLootContainerClassifier and NMLootContainerClassifier.classifyContainer
        and NMLootContainerClassifier.classifyContainer(roomName, containerType, container)
        or "other"
    return classified
end

local function scanContainerState(items, managedLootMap)
    local state = {
        hasManaged = false,
        hasPlaceholder = false
    }
    if not (items and items.size and items.get) then
        return state
    end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local fullType = item and item.getFullType and tostring(item:getFullType() or "") or ""
        if managedLootMap and managedLootMap[fullType] ~= nil then
            state.hasManaged = true
            return state
        end
        if NMLootPlaceholderResolver
            and NMLootPlaceholderResolver.isPlaceholderFullType
            and NMLootPlaceholderResolver.isPlaceholderFullType(fullType)
        then
            state.hasPlaceholder = true
        end
        local modData = item and item.getModData and item:getModData() or nil
        if type(modData) == "table" and modData.nmLootResolved == true then
            state.hasManaged = true
            return state
        end
    end
    return state
end

local function formatOutcomeDetail(outcome, routeClass, source, epoch, context, detail)
    return string.format(
        "outcome=%s epoch=%s routeClass=%s source=%s detail=%s %s",
        tostring(outcome or ""),
        tostring(epoch or ""),
        tostring(routeClass or ""),
        tostring(source or ""),
        tostring(detail or ""),
        NMLootDebugHelpers and NMLootDebugHelpers.formatContainerContext and NMLootDebugHelpers.formatContainerContext(context) or tostring(context and context.shape or "nil")
    )
end

local function maybeLogResult(result, context)
    if not (NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("loot") == true) then
        return
    end
    local detail = formatOutcomeDetail(
        result and result.outcome or "",
        result and result.routeClass or "",
        result and result.source or "",
        result and result.epoch or "",
        context,
        result and result.detail or ""
    )
    local bucketKey = table.concat({
        tostring(result and result.outcome or ""),
        tostring(result and result.epoch or ""),
        tostring(result and result.routeClass or ""),
        tostring(context and context.x or "?"),
        tostring(context and context.y or "?"),
        tostring(context and context.z or "?"),
        tostring(context and context.containerType or "")
    }, "|")
    if NMLootDebugHelpers and NMLootDebugHelpers.logLootThrottled then
        NMLootDebugHelpers.logLootThrottled("late_recovery", bucketKey, "late_recovery.container", detail)
        return
    end
    logLoot("late_recovery.container", detail)
end

local function stampRecoveryState(recoveryState, epoch, outcome)
    if type(recoveryState) ~= "table" then
        return
    end
    recoveryState.epoch = tostring(epoch or "")
    recoveryState.outcome = tostring(outcome or "")
end

function recovery.recoverContainer(roomName, containerType, container, context, controllerState)
    local epoch = tostring(controllerState and controllerState.epoch or "")
    local routeClass = resolveRouteClass(roomName, containerType, container, context)
    if type(context) == "table" then
        context.routeClass = routeClass
    end
    local result = {
        outcome = "skip_unknown",
        routeClass = routeClass,
        source = "",
        epoch = epoch,
        detail = ""
    }

    if not (controllerState and controllerState.runtimeRecoveryAllowed == true) then
        result.outcome = "skip_not_late"
        maybeLogResult(result, context)
        return result
    end

    local resolvedContainer, items = NMLootDebugHelpers.resolveMutableContainer(container, "late_recovery.skip_container")
    if not (resolvedContainer and items) then
        result.outcome = "skip_non_mutable"
        maybeLogResult(result, context)
        return result
    end

    local recoveryState = getContainerRecoveryState(resolvedContainer)
    if type(recoveryState) == "table" and tostring(recoveryState.epoch or "") == epoch then
        result.outcome = "skip_already_recovered"
        maybeLogResult(result, context)
        return result
    end

    if not (NMLootPlaceholderResolver and NMLootPlaceholderResolver.canRecoverManagedLootForRoute
        and NMLootPlaceholderResolver.canRecoverManagedLootForRoute(routeClass))
    then
        stampRecoveryState(recoveryState, epoch, "skip_no_authority_profile")
        result.outcome = "skip_no_authority_profile"
        maybeLogResult(result, context)
        return result
    end

    local managedLootMap = controllerState and controllerState.managedLootMap or nil
    local scan = scanContainerState(items, managedLootMap)
    if scan.hasManaged == true then
        stampRecoveryState(recoveryState, epoch, "skip_has_managed_loot")
        result.outcome = "skip_has_managed_loot"
        maybeLogResult(result, context)
        return result
    end

    if scan.hasPlaceholder == true
        and NMLootPlaceholderResolver
        and NMLootPlaceholderResolver.replacePlaceholdersInContainer
    then
        local replaced = NMLootPlaceholderResolver.replacePlaceholdersInContainer(resolvedContainer, context)
        if replaced and replaced > 0 then
            stampRecoveryState(recoveryState, epoch, "placeholder_replaced")
            result.outcome = "placeholder_replaced"
            result.detail = tostring(replaced)
            maybeLogResult(result, context)
            return result
        end
    end

    local recoveryResult, recoveryReason = NMLootPlaceholderResolver.recoverLiveContainerFromAuthority(resolvedContainer, context)
    if recoveryResult == nil then
        stampRecoveryState(recoveryState, epoch, "skip_no_resolved_items")
        if recoveryReason == "no_authority_profile" or recoveryReason == "no_authority_route" or recoveryReason == "no_authority_budget" then
            result.outcome = "skip_no_authority_profile"
        else
            result.outcome = "skip_no_resolved_items"
        end
        result.detail = tostring(recoveryReason or "")
        maybeLogResult(result, context)
        return result
    end

    stampRecoveryState(recoveryState, epoch, "resolved_added")
    result.outcome = "resolved_added"
    result.source = tostring(recoveryResult.source or "")
    result.detail = tostring(recoveryResult.addedCount or 0) .. "|" .. tostring(recoveryResult.detail or "")
    maybeLogResult(result, context)
    return result
end

return recovery
