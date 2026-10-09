-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
NMClientInventoryItemVisualSanitizer = NMClientInventoryItemVisualSanitizer or {}
NMClientInventoryItemVisualSanitizer._pendingSweep = NMClientInventoryItemVisualSanitizer._pendingSweep ~= false
NMClientInventoryItemVisualSanitizer._pendingReason = NMClientInventoryItemVisualSanitizer._pendingReason or "game_start"
NMClientInventoryItemVisualSanitizer._pendingReasonPriority = tonumber(NMClientInventoryItemVisualSanitizer._pendingReasonPriority) or 100
NMClientInventoryItemVisualSanitizer._lastRequestMs = tonumber(NMClientInventoryItemVisualSanitizer._lastRequestMs) or 0
NMClientInventoryItemVisualSanitizer._diag = NMClientInventoryItemVisualSanitizer._diag or {
    lastLogMs = 0,
    counters = {}
}

local UI_INVALIDATION_DIAG_INTERVAL_MS = 5000
local INVENTORY_REFRESH_COALESCE_MS = 250
local REASON_PRIORITIES = {
    inventory_refresh = 10,
    object_added = 40,
    clothing_updated = 80,
    game_start = 100
}

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

local function countUiInvalidation(name)
    if not (NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("memory") == true) then
        return
    end
    local key = tostring(name or "unknown")
    NMClientInventoryItemVisualSanitizer._diag.counters[key] = (tonumber(NMClientInventoryItemVisualSanitizer._diag.counters[key]) or 0) + 1
end

local function normalizeReason(reason)
    local normalized = tostring(reason or "inventory_refresh")
    if REASON_PRIORITIES[normalized] ~= nil then
        return normalized
    end
    return "inventory_refresh"
end

local function getReasonPriority(reason)
    return tonumber(REASON_PRIORITIES[normalizeReason(reason)] or 10) or 10
end

local function flushUiInvalidationDiag()
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("memory") == true) then
        return
    end
    local nowMs = nowRealMs()
    if (nowMs - (tonumber(NMClientInventoryItemVisualSanitizer._diag.lastLogMs) or 0)) < UI_INVALIDATION_DIAG_INTERVAL_MS then
        return
    end
    NMClientInventoryItemVisualSanitizer._diag.lastLogMs = nowMs
    local parts = {}
    for name, count in pairs(NMClientInventoryItemVisualSanitizer._diag.counters) do
        parts[#parts + 1] = string.format("%s=%d", tostring(name), tonumber(count) or 0)
        NMClientInventoryItemVisualSanitizer._diag.counters[name] = nil
    end
    if #parts > 0 then
        NMCore.logChannel("memory", "client_ui_invalidation_diag", table.concat(parts, " | "))
    end
end

local function logRuntime(tag, detail)
    if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
        NMCore.logChannel("runtime", tostring(tag or "inventory_item_visual"), tostring(detail or ""))
    end
end

local function sanitizeInventoryItem(item, reason)
    local fullType = item and item.getFullType and tostring(item:getFullType() or "") or ""
    if not NMWorldItemVisuals or not NMWorldItemVisuals.isRelevantFullType(fullType) then
        return false
    end
    local ok, status = NMWorldItemVisuals.ensureVisual(item)
    if ok ~= true then
        logRuntime(
            "inventory_item_visual_sanitize",
            string.format(
                "reason=%s fullType=%s ok=%s status=%s",
                tostring(reason or "unknown"),
                tostring(fullType),
                tostring(ok == true),
                tostring(status or "")
            )
        )
    end
    return ok == true
end

local function sweepPlayerInventory(player, reason)
    local inventory = player and player.getInventory and player:getInventory() or nil
    if not inventory then
        return 0
    end
    local processed = 0

    local function visit(container)
        if not container or not container.getItems then
            return
        end
        local items = container:getItems()
        if not items then
            return
        end
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if item then
                if sanitizeInventoryItem(item, reason) then
                    processed = processed + 1
                end
                if item.IsInventoryContainer and item:IsInventoryContainer() then
                    visit(item:getInventory())
                end
            end
        end
    end

    visit(inventory)
    return processed
end

function NMClientInventoryItemVisualSanitizer.requestSweep(_reason)
    local reason = normalizeReason(_reason)
    local priority = getReasonPriority(reason)
    local nowMs = nowRealMs()
    local pending = NMClientInventoryItemVisualSanitizer._pendingSweep == true
    local pendingReason = normalizeReason(NMClientInventoryItemVisualSanitizer._pendingReason)
    local pendingPriority = tonumber(NMClientInventoryItemVisualSanitizer._pendingReasonPriority) or getReasonPriority(pendingReason)

    countUiInvalidation("inventory_sanitizer_request_received")
    countUiInvalidation("inventory_sanitizer_request_received_" .. tostring(reason))

    if pending then
        if priority > pendingPriority then
            NMClientInventoryItemVisualSanitizer._pendingReason = reason
            NMClientInventoryItemVisualSanitizer._pendingReasonPriority = priority
            NMClientInventoryItemVisualSanitizer._lastRequestMs = nowMs
            countUiInvalidation("inventory_sanitizer_request_escalated")
            countUiInvalidation("inventory_sanitizer_request_escalated_" .. tostring(reason))
            flushUiInvalidationDiag()
            return true, "escalated"
        end
        if reason == "inventory_refresh" and pendingReason == "inventory_refresh" and (nowMs - (tonumber(NMClientInventoryItemVisualSanitizer._lastRequestMs) or 0)) <= INVENTORY_REFRESH_COALESCE_MS then
            countUiInvalidation("inventory_sanitizer_request_collapsed")
            countUiInvalidation("inventory_sanitizer_request_collapsed_" .. tostring(reason))
            flushUiInvalidationDiag()
            return false, "collapsed"
        end
        countUiInvalidation("inventory_sanitizer_request_already_pending")
        countUiInvalidation("inventory_sanitizer_request_already_pending_" .. tostring(reason))
        flushUiInvalidationDiag()
        return false, "already_pending"
    end

    flushUiInvalidationDiag()
    NMClientInventoryItemVisualSanitizer._pendingSweep = true
    NMClientInventoryItemVisualSanitizer._pendingReason = reason
    NMClientInventoryItemVisualSanitizer._pendingReasonPriority = priority
    NMClientInventoryItemVisualSanitizer._lastRequestMs = nowMs
    countUiInvalidation("inventory_sanitizer_request_accepted")
    countUiInvalidation("inventory_sanitizer_request_accepted_" .. tostring(reason))
    return true, "accepted"
end

function NMClientInventoryItemVisualSanitizer.hasPendingWork()
    return NMClientInventoryItemVisualSanitizer._pendingSweep == true
end

function NMClientInventoryItemVisualSanitizer.runInventorySweep(player, reason)
    if not player then
        return 0
    end
    local pendingReason = normalizeReason(NMClientInventoryItemVisualSanitizer._pendingReason)
    NMClientInventoryItemVisualSanitizer._pendingSweep = false
    NMClientInventoryItemVisualSanitizer._pendingReason = "inventory_refresh"
    NMClientInventoryItemVisualSanitizer._pendingReasonPriority = getReasonPriority("inventory_refresh")
    return sweepPlayerInventory(player, reason or pendingReason or "inventory_sweep")
end

function NMClientInventoryItemVisualSanitizer.onGameStart()
    NMClientInventoryItemVisualSanitizer._pendingSweep = true
    NMClientInventoryItemVisualSanitizer._pendingReason = "game_start"
    NMClientInventoryItemVisualSanitizer._pendingReasonPriority = getReasonPriority("game_start")
    NMClientInventoryItemVisualSanitizer._lastRequestMs = nowRealMs()
end

return NMClientInventoryItemVisualSanitizer
