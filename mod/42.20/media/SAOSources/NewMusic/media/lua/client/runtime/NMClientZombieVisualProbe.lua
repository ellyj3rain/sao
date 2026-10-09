NMClientZombieVisualProbe = NMClientZombieVisualProbe or {}
NMClientZombieVisualProbe.tick = NMClientZombieVisualProbe.tick or 0
NMClientZombieVisualProbe._clientVisualStateByZombieId = NMClientZombieVisualProbe._clientVisualStateByZombieId or {}
NMClientZombieVisualProbe._lastNearbyZombieTick = NMClientZombieVisualProbe._lastNearbyZombieTick or 0
NMClientZombieVisualProbe._lastRealizeTick = NMClientZombieVisualProbe._lastRealizeTick or 0
NMClientZombieVisualProbe._pendingAuthorityDrivenRefresh = NMClientZombieVisualProbe._pendingAuthorityDrivenRefresh == true
NMClientZombieVisualProbe._authorityRefreshUntilTick = NMClientZombieVisualProbe._authorityRefreshUntilTick or 0
NMClientZombieVisualProbe._lastMaintenanceTick = NMClientZombieVisualProbe._lastMaintenanceTick or 0
NMClientZombieVisualProbe._lastActiveScanTick = NMClientZombieVisualProbe._lastActiveScanTick or 0
require "zombies/NMZombieDeviceVariantCatalog"

local MOD_DATA_KEY = "nmZombieWalkmanProof"
local SUPPORT_FULL_TYPE = "Base.Belt2"
local PROBE_INTERVAL_TICKS = 120
local PROBE_RADIUS = 30
local PROBE_RADIUS_SQ = PROBE_RADIUS * PROBE_RADIUS
local AUTHORITY_RECHECK_TICKS = 600
local FALLBACK_RECHECK_TICKS = 240
local ACTIVE_NEARBY_WINDOW_TICKS = 30
local ACTIVE_REALIZE_WINDOW_TICKS = 40
local AUTHORITY_REFRESH_WINDOW_TICKS = 40
local ACTIVE_SCAN_INTERVAL_TICKS = 10
local STALE_VISUAL_STATE_TICKS = 1800
local VISUAL_STATE_PRUNE_BATCH_SIZE = 256
local ZOMBIE_VISUAL_DIAG_LOG_INTERVAL_MS = 5000
local HELPER_DIAG_LOG_INTERVAL_MS = 5000
local KNOWN_SPECS = NMZombieDeviceVariantCatalog and NMZombieDeviceVariantCatalog.getAllRealizationSpecs and NMZombieDeviceVariantCatalog.getAllRealizationSpecs() or {}
local diagState = {
    lastLogMs = 0,
    counters = {},
    helperLastLogMs = 0,
    helperCounters = {}
}

local function shouldLog()
    return NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("zombie_visual") == true
end

local function logProof(tag, detail)
    if not shouldLog() then
        return
    end
    print("[NewMusic] [ZombieProof] " .. tostring(tag or "") .. " " .. tostring(detail or ""))
end

local function markRealizeInterest()
    NMClientZombieVisualProbe._lastRealizeTick = tonumber(NMClientZombieVisualProbe.tick) or 0
    NMClientZombieVisualProbe._pendingAuthorityDrivenRefresh = false
    NMClientZombieVisualProbe._authorityRefreshUntilTick = 0
end

local function clearRealizeInterest()
    NMClientZombieVisualProbe._lastRealizeTick = 0
end

local function clearRecentInterest()
    NMClientZombieVisualProbe._lastNearbyZombieTick = 0
    clearRealizeInterest()
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

local function countDiag(name)
    if not (NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("memory") == true) then
        return
    end
    local key = tostring(name or "unknown")
    diagState.counters[key] = (tonumber(diagState.counters[key]) or 0) + 1
end

local function flushDiag()
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("memory") == true) then
        return
    end
    local nowMs = nowRealMs()
    if (nowMs - (tonumber(diagState.lastLogMs) or 0)) < ZOMBIE_VISUAL_DIAG_LOG_INTERVAL_MS then
        return
    end
    diagState.lastLogMs = nowMs
    local parts = {}
    for name, count in pairs(diagState.counters) do
        parts[#parts + 1] = string.format("%s=%d", tostring(name), tonumber(count) or 0)
        diagState.counters[name] = nil
    end
    if #parts > 0 then
        NMCore.logChannel("memory", "zombie_visual_interest", table.concat(parts, " | "))
    end
end

local function countHelperDiag(name)
    if not (NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("memory") == true) then
        return
    end
    local key = tostring(name or "unknown")
    diagState.helperCounters[key] = (tonumber(diagState.helperCounters[key]) or 0) + 1
end

local function flushHelperDiag()
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("memory") == true) then
        return
    end
    local nowMs = nowRealMs()
    if (nowMs - (tonumber(diagState.helperLastLogMs) or 0)) < HELPER_DIAG_LOG_INTERVAL_MS then
        return
    end
    diagState.helperLastLogMs = nowMs
    local parts = {}
    for name, count in pairs(diagState.helperCounters) do
        parts[#parts + 1] = string.format("%s=%d", tostring(name), tonumber(count) or 0)
        diagState.helperCounters[name] = nil
    end
    if #parts > 0 then
        NMCore.logChannel("memory", "fanout_helper_diag", table.concat(parts, " | "))
    end
end

local function requestAuthorityRefreshWindow(ticks)
    local currentTick = tonumber(NMClientZombieVisualProbe.tick) or 0
    local duration = math.max(1, tonumber(ticks) or AUTHORITY_REFRESH_WINDOW_TICKS)
    NMClientZombieVisualProbe._pendingAuthorityDrivenRefresh = true
    NMClientZombieVisualProbe._authorityRefreshUntilTick = math.max(
        tonumber(NMClientZombieVisualProbe._authorityRefreshUntilTick) or 0,
        currentTick + duration
    )
end

local function isAuthorityRefreshActive()
    if NMClientZombieVisualProbe._pendingAuthorityDrivenRefresh ~= true then
        return false
    end
    local currentTick = tonumber(NMClientZombieVisualProbe.tick) or 0
    if currentTick <= (tonumber(NMClientZombieVisualProbe._authorityRefreshUntilTick) or 0) then
        return true
    end
    NMClientZombieVisualProbe._pendingAuthorityDrivenRefresh = false
    NMClientZombieVisualProbe._authorityRefreshUntilTick = 0
    return false
end

local function shouldRun()
    if NMCore and NMCore.isMPClientRuntime and NMCore.isMPClientRuntime() == true then
        return true
    end
    return NMCore and NMCore.getRuntimeAuthorityMode and NMCore.getRuntimeAuthorityMode() == "sp_local"
end

local function safeSize(collection)
    if not collection then
        return 0
    end
    local sizeFn = collection.size
    if type(sizeFn) == "function" then
        local ok, value = pcall(sizeFn, collection)
        if ok then
            return tonumber(value) or 0
        end
    end
    local getSizeFn = collection.getSize
    if type(getSizeFn) == "function" then
        local ok, value = pcall(getSizeFn, collection)
        if ok then
            return tonumber(value) or 0
        end
    end
    return 0
end

local function getZombieId(zombie)
    if NMZombieVisualTargetContract and NMZombieVisualTargetContract.getZombieId then
        return NMZombieVisualTargetContract.getZombieId(zombie)
    end
    if zombie and zombie.getObjectID then
        return tostring(zombie:getObjectID() or "")
    end
    return tostring(zombie or "")
end

local function isAliveZombie(zombie)
    if not (zombie and instanceof and instanceof(zombie, "IsoZombie")) then
        return false
    end
    if zombie.isDead and zombie:isDead() then
        return false
    end
    if zombie.isOnDeathDone and zombie:isOnDeathDone() then
        return false
    end
    return true
end

local function getProofModData(zombie)
    local root = zombie and zombie.getModData and zombie:getModData() or nil
    local md = root and root[MOD_DATA_KEY] or nil
    if type(md) ~= "table" then
        return nil
    end
    return md
end

local function getDecisionSpec(decision)
    if type(decision) ~= "table" then
        return nil
    end
    return NMZombieDeviceVariantCatalog
        and NMZombieDeviceVariantCatalog.resolveStoredSpec
        and NMZombieDeviceVariantCatalog.resolveStoredSpec(decision)
        or nil
end

local function inspectAttachedItemsState(zombie)
    local attached = zombie and zombie.getAttachedItems and zombie:getAttachedItems() or nil
    local state = {
        attachedCount = safeSize(attached),
        countsByFullType = {},
        slotsByKey = {}
    }
    if state.attachedCount <= 0 then
        return state
    end
    for i = 0, state.attachedCount - 1 do
        local entry = attached:get(i)
        local location = entry and entry.getLocation and tostring(entry:getLocation() or "") or ""
        local item = entry and entry.getItem and entry:getItem() or nil
        local fullType = item and item.getFullType and tostring(item:getFullType() or "") or ""
        if fullType ~= "" then
            state.countsByFullType[fullType] = (tonumber(state.countsByFullType[fullType]) or 0) + 1
        end
        if location ~= "" and fullType ~= "" then
            state.slotsByKey[location .. "|" .. fullType] = true
        end
    end
    return state
end

local function getZombieVariantSpec(zombie, decision, allowDefaultFallback)
    local decisionSpec = getDecisionSpec(decision)
    if decisionSpec then
        return decisionSpec
    end
    local md = getProofModData(zombie)
    local spec = NMZombieDeviceVariantCatalog and NMZombieDeviceVariantCatalog.resolveStoredSpec and NMZombieDeviceVariantCatalog.resolveStoredSpec(md) or nil
    if spec then
        return spec
    end
    if allowDefaultFallback ~= true then
        return nil
    end
    return NMZombieDeviceVariantCatalog and NMZombieDeviceVariantCatalog.getDefaultSpec and NMZombieDeviceVariantCatalog.getDefaultSpec() or nil
end

local function hasAttachedProof(zombie, spec, decision, attachedItemsState)
    local resolved = type(spec) == "table" and spec or getZombieVariantSpec(zombie, decision)
    if not resolved then
        return false
    end
    local state = attachedItemsState or inspectAttachedItemsState(zombie)
    if (tonumber(state.attachedCount) or 0) <= 0 then
        return false
    end
    local key = tostring(resolved.attachmentLocation or "") .. "|" .. tostring(resolved.fullType or "")
    return state.slotsByKey[key] == true
end

local function hasAttachedSlot(slotLocation, wantedFullType, attachedItemsState)
    local wantedLocation = tostring(slotLocation or "")
    local wantedType = tostring(wantedFullType or "")
    if wantedLocation == "" or wantedType == "" then
        return false
    end
    local state = attachedItemsState or { slotsByKey = {} }
    return state.slotsByKey[wantedLocation .. "|" .. wantedType] == true
end

local function countMatchingAttachedSlots(wantedFullType, attachedItemsState)
    local wantedType = tostring(wantedFullType or "")
    if wantedType == "" then
        return 0
    end
    local state = attachedItemsState or { countsByFullType = {} }
    return tonumber(state.countsByFullType[wantedType]) or 0
end

local function getModelProbe(zombie)
    local legsSprite = zombie and (zombie.legsSprite or (zombie.getLegsSprite and zombie:getLegsSprite()) or nil) or nil
    local modelSlot = legsSprite and legsSprite.modelSlot or nil
    local attachedModels = modelSlot and modelSlot.attachedModels or nil
    local attachedModelCount = safeSize(attachedModels)
    return {
        hasLegsSprite = legsSprite ~= nil,
        hasModelSlot = modelSlot ~= nil,
        isActive = modelSlot and modelSlot.active == true or false,
        hasModel = modelSlot and modelSlot.model ~= nil or false,
        attachedModelCount = attachedModelCount
    }
end

local function createProofItem(zombie, spec)
    local resolved = type(spec) == "table" and spec or nil
    if not resolved then
        return nil, "missing_spec"
    end
    local fullType = tostring(resolved.fullType or "")
    local item = nil
    local usedType = nil
    if InventoryItemFactory and InventoryItemFactory.CreateItem then
        local ok, created = pcall(InventoryItemFactory.CreateItem, fullType)
        if ok and created then
            item = created
            usedType = fullType
        end
    end
    if not item and zombie and zombie.getInventory then
        local okInventory, inventory = pcall(zombie.getInventory, zombie)
        if okInventory and inventory and inventory.AddItem then
            local okAdd, created = pcall(function()
                return inventory:AddItem(fullType)
            end)
            if okAdd and created then
                item = created
                usedType = fullType
            end
        end
    end
    if not item then
        return nil, "item_create_failed"
    end
    if item.setAttachedToModel then
        pcall(item.setAttachedToModel, item, tostring(resolved.modelAttachmentName or ""))
    end
    return item, usedType
end

local function forceBeltVisualRefresh(zombie)
    if zombie and zombie.resetEquippedHandsModels then
        pcall(zombie.resetEquippedHandsModels, zombie)
    end
    if zombie and zombie.resetModelNextFrame then
        pcall(zombie.resetModelNextFrame, zombie)
    end
    if zombie and zombie.resetModel then
        pcall(zombie.resetModel, zombie)
    end
    return getModelProbe(zombie)
end

local function attachClientProofSlot(zombie, spec)
    local resolved = type(spec) == "table" and spec or nil
    if not resolved then
        return false, "missing_spec", nil
    end
    local item, reason = createProofItem(zombie, resolved)
    if not item then
        return false, reason, nil
    end
    if not (zombie and zombie.setAttachedItem) then
        return false, "missing_setAttachedItem", item
    end
    local ok, err = pcall(zombie.setAttachedItem, zombie, tostring(resolved.attachmentLocation or ""), item)
    if not ok then
        return false, tostring(err or "setAttachedItem_failed"), item
    end
    return true, nil, item
end

local function clearClientProofSlot(zombie, spec)
    local resolved = type(spec) == "table" and spec or nil
    if not resolved then
        return false, "missing_spec"
    end
    if not (zombie and zombie.setAttachedItem) then
        return false, "missing_setAttachedItem"
    end
    local ok, err = pcall(zombie.setAttachedItem, zombie, tostring(resolved.attachmentLocation or ""), nil)
    if not ok then
        return false, tostring(err or "clearAttachedItem_failed")
    end
    forceBeltVisualRefresh(zombie)
    return true
end

local function ensureClientProofVisual(zombie, decision, attachedItemsState)
    local zid = getZombieId(zombie)
    local beforeProbe = getModelProbe(zombie)
    local allowDefaultFallback = type(decision) == "table"
        and decision.authoritative ~= true
        and decision.allowDefaultFallback == true
    local spec = getZombieVariantSpec(zombie, decision, allowDefaultFallback)
    if not spec then
        if type(decision) == "table" and decision.authoritative == true and decision.selected == true then
            logProof("client_attach_failed", string.format("zombie=%s reason=missing_authoritative_realization", tostring(zid)))
        end
        return nil
    end
    local initialAttachedItemsState = attachedItemsState or inspectAttachedItemsState(zombie)
    local attachedBefore = countMatchingAttachedSlots(tostring(spec.fullType or ""), initialAttachedItemsState)
    local slot = tostring(spec.attachmentLocation or "")
    local madeAttach = false
    local visualState = NMClientZombieVisualProbe._clientVisualStateByZombieId[zid] or {}
    NMClientZombieVisualProbe._clientVisualStateByZombieId[zid] = visualState
    local decisionSource = tostring(decision and decision.source or "")
    local decisionState = tostring(decision and decision.state or "")
    local authoritative = decision and decision.authoritative == true or false
    if not hasAttachedSlot(slot, tostring(spec.fullType or ""), initialAttachedItemsState) then
        local ok, reason, item = attachClientProofSlot(zombie, spec)
        if ok then
            madeAttach = true
            logProof(
                "client_attach",
                string.format(
                    "zombie=%s source=%s authoritative=%s state=%s slot=%s item=%s attachedBefore=%s",
                    tostring(zid),
                    decisionSource,
                    tostring(authoritative),
                    decisionState,
                    tostring(slot),
                    tostring(item and item.getFullType and item:getFullType() or reason or tostring(spec.fullType or "")),
                    tostring(attachedBefore)
                )
            )
        else
            logProof(
                "client_attach_failed",
                string.format(
                    "zombie=%s slot=%s reason=%s",
                    tostring(zid),
                    tostring(slot),
                    tostring(reason or "unknown")
                )
            )
        end
    elseif shouldLog() then
        local existingSig = table.concat({
            tostring(zid),
            decisionSource,
            tostring(authoritative),
            decisionState,
            tostring(slot),
            tostring(spec.fullType or ""),
            tostring(attachedBefore)
        }, "|")
        if visualState.lastExistingVisualSig ~= existingSig then
            visualState.lastExistingVisualSig = existingSig
            logProof(
                "client_attach_existing",
                string.format(
                    "zombie=%s source=%s authoritative=%s state=%s slot=%s item=%s attached=%s",
                    tostring(zid),
                    decisionSource,
                    tostring(authoritative),
                    decisionState,
                    tostring(slot),
                    tostring(spec.fullType or ""),
                    tostring(attachedBefore)
                )
            )
        end
    end

    local afterProbe = beforeProbe
    if madeAttach or (attachedBefore > 0 and beforeProbe.attachedModelCount == 0) then
        afterProbe = forceBeltVisualRefresh(zombie) or afterProbe
    end

    local finalAttachedItemsState = madeAttach and inspectAttachedItemsState(zombie) or initialAttachedItemsState
    local attachedAfter = countMatchingAttachedSlots(tostring(spec.fullType or ""), finalAttachedItemsState)
    local supportedSlots = hasAttachedSlot(tostring(spec.attachmentLocation or ""), tostring(spec.fullType or ""), finalAttachedItemsState) and 1 or 0
    if madeAttach then
        visualState.clientProofAttached = true
    elseif attachedAfter > 0 and visualState.clientProofAttached ~= false then
        visualState.clientProofAttached = true
    end
    visualState.lastAttachedModelCount = afterProbe.attachedModelCount
    visualState.lastHasModelSlot = afterProbe.hasModelSlot
    visualState.lastScanTick = NMClientZombieVisualProbe.tick

    return {
        attachedSlots = attachedAfter,
        supportedSlots = supportedSlots,
        beforeProbe = beforeProbe,
        afterProbe = afterProbe,
        madeAttach = madeAttach,
        refreshedMissingModel = madeAttach ~= true and attachedBefore > 0 and beforeProbe.attachedModelCount == 0
    }
end

local function clearNonTargetClientProof(zombie, attachedItemsState)
    local zid = getZombieId(zombie)
    local visualState = NMClientZombieVisualProbe._clientVisualStateByZombieId[zid] or nil
    local clearedAny = false
    local currentAttachedItemsState = attachedItemsState or inspectAttachedItemsState(zombie)
    for i = 1, #KNOWN_SPECS do
        local spec = KNOWN_SPECS[i]
        if hasAttachedSlot(tostring(spec.attachmentLocation or ""), tostring(spec.fullType or ""), currentAttachedItemsState) then
            if not visualState or visualState.clientProofAttached ~= false then
                local cleared, reason = clearClientProofSlot(zombie, spec)
                if not cleared then
                    logProof(
                        "client_detach_failed",
                        string.format("zombie=%s slot=%s reason=%s", tostring(zid), tostring(spec.attachmentLocation or ""), tostring(reason or "unknown"))
                    )
                else
                    clearedAny = true
                    currentAttachedItemsState = inspectAttachedItemsState(zombie)
                    logProof("client_detach", string.format("zombie=%s slot=%s", tostring(zid), tostring(spec.attachmentLocation or "")))
                end
            end
        end
    end
    if visualState then
        visualState.clientProofAttached = false
        visualState.lastScanTick = NMClientZombieVisualProbe.tick
    end
    return clearedAny
end

local function getDecisionRevision(decision)
    if type(decision) ~= "table" then
        return 0
    end
    if tostring(decision.source or "") == "mp_snapshot" then
        return NMClientZombieVisualTargetCache and NMClientZombieVisualTargetCache.getRevision and NMClientZombieVisualTargetCache.getRevision() or 0
    end
    return tonumber(decision.selectionEpoch) or 0
end

local function getDecisionStateKey(decision)
    if type(decision) ~= "table" then
        return "none"
    end
    return table.concat({
        tostring(decision.source or ""),
        tostring(decision.state or ""),
        tostring(decision.variantId or ""),
        tostring(decision.fullType or ""),
        tostring(decision.attachmentLocation or ""),
        tostring(decision.modelAttachmentName or ""),
        tostring(getDecisionRevision(decision))
    }, "|")
end

local function shouldRealizeDecision(zombieId, decision, collectDiagnostics)
    countHelperDiag("zombie_probe.shouldRealizeDecision")
    local visualState = NMClientZombieVisualProbe._clientVisualStateByZombieId[zombieId] or {}
    NMClientZombieVisualProbe._clientVisualStateByZombieId[zombieId] = visualState
    visualState.lastTouchedTick = tonumber(NMClientZombieVisualProbe.tick) or 0
    local currentTick = tonumber(NMClientZombieVisualProbe.tick) or 0
    local decisionStateKey = getDecisionStateKey(decision)
    local previousStateKey = visualState.lastDecisionStateKey
    if collectDiagnostics then
        if previousStateKey == decisionStateKey then
            return true, visualState, "diagnostic_forced_same_state"
        end
        return true, visualState, "diagnostic_forced_new_state"
    end
    local recheckTicks = type(decision) == "table" and decision.authoritative == true and AUTHORITY_RECHECK_TICKS or FALLBACK_RECHECK_TICKS
    if previousStateKey ~= decisionStateKey then
        if previousStateKey == nil then
            return true, visualState, "first_state"
        end
        return true, visualState, "state_changed"
    end
    if (currentTick - (tonumber(visualState.lastDecisionTick) or 0)) >= recheckTicks then
        return true, visualState, "recheck_due_same_state"
    end
    return false, visualState, "clean_same_state"
end

local function countRealizeDecisionDiag(visualState, reason)
    local key = tostring(reason or "unknown")
    countDiag("zombie_visual_realize_reason_" .. key)
    if type(visualState) ~= "table" then
        return
    end
    if (tonumber(visualState.realizeDiagCount) or 0) > 0 then
        countDiag("zombie_visual_realize_repeat_zombie")
    else
        countDiag("zombie_visual_realize_new_zombie")
    end
    visualState.realizeDiagCount = (tonumber(visualState.realizeDiagCount) or 0) + 1
end

local function clearNonTargetVisualDecision(zombie, counts, attachedItemsState)
    if clearNonTargetClientProof(zombie, attachedItemsState) then
        counts.clearedProof = counts.clearedProof + 1
        return { clearedProof = true }
    end
    return nil
end

local function applyAuthoritativeVisualDecision(zombie, decision, counts, attachedItemsState)
    local decisionState = type(decision) == "table" and tostring(decision.state or "") or ""
    if decisionState == "selected" then
        counts.contractHits = counts.contractHits + 1
        return ensureClientProofVisual(zombie, decision, attachedItemsState)
    end
    if decisionState == "excluded" then
        counts.contractMisses = counts.contractMisses + 1
    elseif decisionState == "pending" then
        counts.pendingAuthority = counts.pendingAuthority + 1
    end
    return clearNonTargetVisualDecision(zombie, counts, attachedItemsState)
end

local function applyClientVisualFallback(zombie, decision, counts, attachedItemsState)
    counts.fallbackEligible = counts.fallbackEligible + 1
    local forced = ensureClientProofVisual(zombie, decision, attachedItemsState)
    if forced then
        logProof(
            "client_attach_fallback",
            string.format(
                "zombie=%s source=%s authoritative=%s state=%s reason=no_authoritative_record",
                tostring(getZombieId(zombie)),
                tostring(decision and decision.source or ""),
                tostring(decision and decision.authoritative == true or false),
                tostring(decision and decision.state or "")
            )
        )
    end
    return forced
end

local function realizeZombieVisualDecision(zombie, decision, authorityDrivenRuntime, counts, attachedItemsState)
    countHelperDiag("zombie_probe.realizeZombieVisualDecision")
    local decisionState = type(decision) == "table" and tostring(decision.state or "") or ""
    if decisionState == "selected" or decisionState == "excluded" or decisionState == "pending" then
        return applyAuthoritativeVisualDecision(zombie, decision, counts, attachedItemsState)
    end
    if authorityDrivenRuntime == true then
        return clearNonTargetVisualDecision(zombie, counts, attachedItemsState)
    end
    return applyClientVisualFallback(zombie, decision, counts, attachedItemsState)
end

local function didVisualWorkChange(reason, outcome)
    local key = tostring(reason or "")
    if key == "first_state" or key == "state_changed" or key == "diagnostic_forced_new_state" then
        return true
    end
    if type(outcome) ~= "table" then
        return false
    end
    return outcome.madeAttach == true
        or outcome.clearedProof == true
        or outcome.refreshedMissingModel == true
end

local function hasSupportWorn(zombie)
    local wornItems = zombie and zombie.getWornItems and zombie:getWornItems() or nil
    if not wornItems then
        return false
    end
    local size = wornItems.size and tonumber(wornItems:size()) or wornItems.getSize and tonumber(wornItems:getSize()) or -1
    if size <= 0 then
        return false
    end
    for i = 0, size - 1 do
        local entry = wornItems.get and wornItems:get(i) or wornItems.getItemByIndex and wornItems:getItemByIndex(i) or nil
        local item = entry and entry.getItem and entry:getItem() or entry and entry.getInventoryItem and entry:getInventoryItem() or entry
        local fullType = item and item.getFullType and tostring(item:getFullType() or "") or ""
        if fullType == SUPPORT_FULL_TYPE then
            return true
        end
    end
    return false
end

local function makeNearbyZombieCheck(player)
    local square = player and player.getCurrentSquare and player:getCurrentSquare() or nil
    if not square then
        return nil
    end
    local px = (tonumber(square:getX()) or 0) + 0.5
    local py = (tonumber(square:getY()) or 0) + 0.5
    local pz = tonumber(square:getZ()) or 0
    return function(zombie)
        if not (zombie and zombie.getX and zombie.getY) then
            return false
        end
        local zz = tonumber(zombie.getZ and zombie:getZ() or 0) or 0
        if math.abs(zz - pz) > 2 then
            return false
        end
        local dx = px - (tonumber(zombie:getX()) or 0)
        local dy = py - (tonumber(zombie:getY()) or 0)
        return ((dx * dx) + (dy * dy)) <= PROBE_RADIUS_SQ
    end
end

local function pruneClientVisualState(activeSeen)
    local states = NMClientZombieVisualProbe._clientVisualStateByZombieId or nil
    if type(states) ~= "table" then
        return 0
    end
    local currentTick = tonumber(NMClientZombieVisualProbe.tick) or 0
    local pruned = 0
    local scanned = 0
    for zombieId, visualState in pairs(states) do
        scanned = scanned + 1
        local keepActive = activeSeen and activeSeen[zombieId] == true
        if keepActive ~= true then
            local lastTouchedTick = math.max(
                tonumber(type(visualState) == "table" and visualState.lastTouchedTick or 0) or 0,
                tonumber(type(visualState) == "table" and visualState.lastScanTick or 0) or 0,
                tonumber(type(visualState) == "table" and visualState.lastDecisionTick or 0) or 0
            )
            if (currentTick - lastTouchedTick) >= STALE_VISUAL_STATE_TICKS then
                states[zombieId] = nil
                pruned = pruned + 1
            end
        end
        if scanned >= VISUAL_STATE_PRUNE_BATCH_SIZE and pruned <= 0 then
            break
        end
    end
    if pruned > 0 and shouldLog() then
        logProof("client_visual_state_prune", string.format("pruned=%s live=%s", tostring(pruned), tostring(scanned - pruned)))
    end
    return pruned
end

local function scanAroundPlayer(player)
    local allowZombie = makeNearbyZombieCheck(player)
    if not allowZombie then
        clearRecentInterest()
        pruneClientVisualState(nil)
        NMClientZombieVisualProbe._pendingAuthorityDrivenRefresh = false
        NMClientZombieVisualProbe._authorityRefreshUntilTick = 0
        return
    end
    local zombies = getCell() and getCell():getZombieList() or nil
    if not (zombies and zombies.size) then
        clearRecentInterest()
        pruneClientVisualState(nil)
        NMClientZombieVisualProbe._pendingAuthorityDrivenRefresh = false
        NMClientZombieVisualProbe._authorityRefreshUntilTick = 0
        return
    end
    local authorityDrivenRuntime = NMClientZombieVisualTargetCache
        and NMClientZombieVisualTargetCache.isAuthorityDrivenRuntime
        and NMClientZombieVisualTargetCache.isAuthorityDrivenRuntime() == true
    local collectDiagnostics = shouldLog()
    local counts = {
        nearby = 0,
        contractHits = 0,
        contractMisses = 0,
        pendingAuthority = 0,
        tagged = 0,
        taggedAttachedStatus = 0,
        visibleProof = 0,
        visibleAndTagged = 0,
        supportWorn = 0,
        forceAttached = 0,
        fallbackEligible = 0,
        clearedProof = 0,
        modelBuilt = 0
    }
    local seen = {}
    local meaningfulVisualWork = false
    local currentTick = tonumber(NMClientZombieVisualProbe.tick) or 0
    local lastRealizeTick = tonumber(NMClientZombieVisualProbe._lastRealizeTick) or 0
    local hadRealizeInterest = lastRealizeTick > 0 and (currentTick - lastRealizeTick) <= ACTIVE_REALIZE_WINDOW_TICKS
    for i = 0, zombies:size() - 1 do
        local zombie = zombies:get(i)
        local zid = getZombieId(zombie)
        if not seen[zid] and isAliveZombie(zombie) and allowZombie(zombie) then
            seen[zid] = true
            counts.nearby = counts.nearby + 1
            local visualState = NMClientZombieVisualProbe._clientVisualStateByZombieId[zid] or {}
            NMClientZombieVisualProbe._clientVisualStateByZombieId[zid] = visualState
            visualState.lastTouchedTick = tonumber(NMClientZombieVisualProbe.tick) or 0
            local decision = NMClientZombieVisualTargetCache
                and NMClientZombieVisualTargetCache.getZombieDecision
                and NMClientZombieVisualTargetCache.getZombieDecision(zombie) or nil
            countHelperDiag("zombie_probe.getZombieDecision")
            local shouldRealize, visualState, realizeReason = shouldRealizeDecision(zid, decision, collectDiagnostics)
            local attachedItemsState = nil
            local realizeOutcome = nil
            if shouldRealize then
                countRealizeDecisionDiag(visualState, realizeReason)
                attachedItemsState = inspectAttachedItemsState(zombie)
                realizeOutcome = realizeZombieVisualDecision(zombie, decision, authorityDrivenRuntime, counts, attachedItemsState)
                visualState.lastDecisionStateKey = getDecisionStateKey(decision)
                visualState.lastDecisionTick = tonumber(NMClientZombieVisualProbe.tick) or 0
                if didVisualWorkChange(realizeReason, realizeOutcome) then
                    meaningfulVisualWork = true
                    if tostring(realizeReason or "") == "recheck_due_same_state" then
                        countDiag("zombie_visual_same_state_mutated_refresh")
                    end
                elseif tostring(realizeReason or "") == "recheck_due_same_state" then
                    countDiag("zombie_visual_same_state_no_active_refresh")
                end
            end
            if collectDiagnostics then
                local md = getProofModData(zombie)
                attachedItemsState = attachedItemsState or inspectAttachedItemsState(zombie)
                local visible = hasAttachedProof(zombie, nil, decision, attachedItemsState)
                local support = hasSupportWorn(zombie)
                if md then
                    counts.tagged = counts.tagged + 1
                    if tostring(md.status or "") == "attached" then
                        counts.taggedAttachedStatus = counts.taggedAttachedStatus + 1
                    end
                end
                if visible then
                    counts.visibleProof = counts.visibleProof + 1
                end
                if support then
                    counts.supportWorn = counts.supportWorn + 1
                end
                if realizeOutcome and realizeOutcome.attachedSlots and realizeOutcome.attachedSlots > 0 then
                    counts.forceAttached = counts.forceAttached + 1
                end
                if realizeOutcome and realizeOutcome.afterProbe and realizeOutcome.afterProbe.attachedModelCount and realizeOutcome.afterProbe.attachedModelCount > 0 then
                    counts.modelBuilt = counts.modelBuilt + 1
                end
                if md and visible then
                    counts.visibleAndTagged = counts.visibleAndTagged + 1
                end
            end
        end
    end
    if meaningfulVisualWork == true then
        markRealizeInterest()
        countDiag("zombie_visual_meaningful_active_refresh")
        countDiag("zombie_visual_active_refresh_realize")
        countDiag("zombie_visual_realize_active_refresh")
    elseif counts.nearby > 0 then
        if hadRealizeInterest == true then
            countDiag("zombie_visual_realize_followup_no_work")
            clearRealizeInterest()
            countDiag("zombie_visual_realize_settled_clear")
        end
        countDiag("zombie_visual_nearby_no_active_refresh")
    elseif counts.nearby <= 0 then
        clearRecentInterest()
        NMClientZombieVisualProbe._pendingAuthorityDrivenRefresh = false
        NMClientZombieVisualProbe._authorityRefreshUntilTick = 0
    end
    pruneClientVisualState(seen)
    if not collectDiagnostics then
        flushHelperDiag()
        return
    end
    local summary = string.format(
        "nearby=%s authoritative=%s contractHits=%s contractMisses=%s pendingAuthority=%s fallbackEligible=%s clearedProof=%s tagged=%s taggedAttachedStatus=%s visibleProof=%s visibleAndTagged=%s supportWorn=%s forceAttached=%s modelBuilt=%s",
        tostring(counts.nearby),
        tostring(authorityDrivenRuntime),
        tostring(counts.contractHits),
        tostring(counts.contractMisses),
        tostring(counts.pendingAuthority),
        tostring(counts.fallbackEligible),
        tostring(counts.clearedProof),
        tostring(counts.tagged),
        tostring(counts.taggedAttachedStatus),
        tostring(counts.visibleProof),
        tostring(counts.visibleAndTagged),
        tostring(counts.supportWorn),
        tostring(counts.forceAttached),
        tostring(counts.modelBuilt)
    )
    if NMClientZombieVisualProbe._lastSummary ~= summary then
        NMClientZombieVisualProbe._lastSummary = summary
        logProof("client_visual_probe", summary)
    end
    flushHelperDiag()
end

function NMClientZombieVisualProbe.hasPendingWork(player)
    if not shouldRun() or not player then
        countDiag("inactive")
        flushDiag()
        flushHelperDiag()
        return false
    end
    if isAuthorityRefreshActive() == true then
        countDiag("authority_refresh_window")
        flushDiag()
        flushHelperDiag()
        return true
    end
    local currentTick = tonumber(NMClientZombieVisualProbe.tick) or 0
    if (currentTick - (tonumber(NMClientZombieVisualProbe._lastNearbyZombieTick) or 0)) <= ACTIVE_NEARBY_WINDOW_TICKS then
        countDiag("nearby_recent")
        flushDiag()
        flushHelperDiag()
        return true
    end
    if (currentTick - (tonumber(NMClientZombieVisualProbe._lastRealizeTick) or 0)) <= ACTIVE_REALIZE_WINDOW_TICKS then
        countDiag("realize_recent")
        flushDiag()
        flushHelperDiag()
        return true
    end
    countDiag("idle")
    flushDiag()
    flushHelperDiag()
    return false
end

function NMClientZombieVisualProbe.observeSchedulerTick(tickStep)
    NMClientZombieVisualProbe.tick = (tonumber(NMClientZombieVisualProbe.tick) or 0) + math.max(1, tonumber(tickStep) or 1)
end

function NMClientZombieVisualProbe.shouldRunMaintenance()
    local currentTick = tonumber(NMClientZombieVisualProbe.tick) or 0
    return (currentTick - (tonumber(NMClientZombieVisualProbe._lastMaintenanceTick) or 0)) >= PROBE_INTERVAL_TICKS
end

function NMClientZombieVisualProbe.getNextMaintenanceCheckTick()
    local currentTick = tonumber(NMClientZombieVisualProbe.tick) or 0
    local lastMaintenanceTick = tonumber(NMClientZombieVisualProbe._lastMaintenanceTick) or 0
    return math.max(currentTick, lastMaintenanceTick + PROBE_INTERVAL_TICKS)
end

function NMClientZombieVisualProbe.markAuthorityRefresh(reason)
    requestAuthorityRefreshWindow(AUTHORITY_REFRESH_WINDOW_TICKS)
end

function NMClientZombieVisualProbe.onTick(player, tickStep)
    if not shouldRun() then
        return
    end
    if not player then
        return
    end
    local currentTick = tonumber(NMClientZombieVisualProbe.tick) or 0
    local authorityRefreshActive = isAuthorityRefreshActive() == true
    local activeInterest = authorityRefreshActive
        or (currentTick - (tonumber(NMClientZombieVisualProbe._lastNearbyZombieTick) or 0)) <= ACTIVE_NEARBY_WINDOW_TICKS
        or (currentTick - (tonumber(NMClientZombieVisualProbe._lastRealizeTick) or 0)) <= ACTIVE_REALIZE_WINDOW_TICKS
    local shouldRunActiveScan = activeInterest and (currentTick - (tonumber(NMClientZombieVisualProbe._lastActiveScanTick) or 0)) >= ACTIVE_SCAN_INTERVAL_TICKS
    local shouldRunMaintenance = NMClientZombieVisualProbe.shouldRunMaintenance()
    if not shouldRunActiveScan and not shouldRunMaintenance then
        return
    end
    if shouldRunActiveScan then
        NMClientZombieVisualProbe._lastActiveScanTick = currentTick
    end
    if shouldRunMaintenance then
        countDiag("zombie_visual_maintenance_scan")
    end
    NMClientZombieVisualProbe._lastMaintenanceTick = currentTick
    scanAroundPlayer(player)
end

return NMClientZombieVisualProbe
