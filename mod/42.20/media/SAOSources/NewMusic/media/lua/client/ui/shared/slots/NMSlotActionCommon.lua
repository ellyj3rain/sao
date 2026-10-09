require "ui/shared/slots/NMPortableUiSoundContract"

NMSlotActionCommon = NMSlotActionCommon or {}

local SLOT_TRACE_SEQ = 0
local SLOT_RELEASE_HANDLED_INSERT = "handled_insert"
local SLOT_RELEASE_HANDLED_EJECT = "handled_eject"
local SLOT_RELEASE_HANDLED_EXTRACT = "handled_extract"
local SLOT_RELEASE_CANCELED_CUSTOM_DRAG = "canceled_custom_drag"
local SLOT_RELEASE_NOT_OURS = "not_ours"

function NMSlotActionCommon.playSlotUISound(window, soundName, volume)
    local name = tostring(soundName or "")
    if name == "" then return end
    local legacyEvent = ({
        NM_BatteryIn = "slot_battery_insert_success",
        NM_BatteryOut = "slot_battery_eject_success",
        NM_ButtonClick = "ui_activate",
        NM_ButtonClick2 = "ui_activate_alt",
    })[name]
    if legacyEvent then
        NMPortableUiSoundContract.playEvent(window, legacyEvent)
        return
    end
    NMPortableUiSoundContract.playNamedSound(window, name)
end

function NMSlotActionCommon.safeDraggedPayload()
    if not ISMouseDrag then return nil, false end
    local dragging = ISMouseDrag.dragging
    if dragging == nil then return {}, true end
    if type(dragging) ~= "table" then return nil, false end
    return dragging, true
end

function NMSlotActionCommon.getDraggedInventoryItems()
    local dragging, resolved = NMSlotActionCommon.safeDraggedPayload()
    if not resolved then return nil, false end
    if not dragging or #dragging <= 0 then return {}, true end
    if not (ISInventoryPane and ISInventoryPane.getActualItems) then
        return nil, false
    end
    local ok, actual = pcall(ISInventoryPane.getActualItems, dragging)
    if not ok or type(actual) ~= "table" then
        return nil, false
    end
    local out = {}
    for i = 1, #actual do
        local item = actual[i]
        if item and item.getFullType then
            out[#out + 1] = item
        end
    end
    return out, true
end

function NMSlotActionCommon.clearMouseDragState()
    if not ISMouseDrag then return end
    ISMouseDrag.dragging = nil
    ISMouseDrag.draggingFocus = nil
end

function NMSlotActionCommon.nextSlotTraceId()
    SLOT_TRACE_SEQ = SLOT_TRACE_SEQ + 1
    return tostring(SLOT_TRACE_SEQ)
end

local function slotProbeEnabled()
    if not (NMCore and NMCore.isSubsystemDebugEnabled) then
        return false
    end
    if NMCore.isSubsystemDebugEnabled("slot") == true then
        return true
    end
    return NMCore.isSubsystemDebugEnabled("portable_ui") == true
end

local function slotProbeLogChannel()
    if not (NMCore and NMCore.logChannel) then
        return nil
    end
    if NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("slot") == true then
        return "slot"
    end
    if NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("portable_ui") == true then
        return "portable_ui"
    end
    return nil
end

local function safeProbeString(value)
    local text = tostring(value or "")
    text = text:gsub("%s+", " ")
    return text
end

function NMSlotActionCommon.resolveSlotHostFamily(window)
    if window and window.target and tostring(window.target.kind or "") == "vehicle" then
        return "vehicle"
    end
    if window and window.getFrontVariant then
        return "cdplayer"
    end
    if window and window.getBoomboxVariant then
        return "boombox"
    end
    if window and window.getLidRect and window.syncLidFromMedia then
        return "walkman"
    end
    return window and tostring(window.slotHostFamily or "generic") or "generic"
end

function NMSlotActionCommon.resolveSlotTargetSummary(window)
    local target = window and window.target or nil
    return {
        kind = tostring(target and target.kind or ""),
        itemId = tostring(target and target.itemId or ""),
        uuid = tostring(target and target.uuid or ""),
        vehicleId = tostring(target and target.vehicleId or ""),
        partId = tostring(target and target.partId or "")
    }
end

local function resolveGhostOwnerSummary(slotType)
    local owner = nil
    if slotType == "media" then
        owner = NMMediaSlot and NMMediaSlot._ghostDragWindow or nil
    elseif slotType == "battery" then
        owner = NMBatterySlot and NMBatterySlot._ghostDragWindow or nil
    elseif slotType == "headphones" then
        owner = NMHeadphoneSlot and NMHeadphoneSlot._ghostDragWindow or nil
    end
    if not owner then
        return "none"
    end
    local target = NMSlotActionCommon.resolveSlotTargetSummary(owner)
    return table.concat({
        NMSlotActionCommon.resolveSlotHostFamily(owner),
        target.kind,
        target.itemId,
        target.uuid,
        target.vehicleId,
        target.partId
    }, "|")
end

function NMSlotActionCommon.logSlotExtractEvent(eventName, context)
    if not slotProbeEnabled() then
        return
    end
    local channel = slotProbeLogChannel()
    if not channel then
        return
    end
    local ctx = context or {}
    local window = ctx.window
    local drag = ctx.drag or nil
    local target = NMSlotActionCommon.resolveSlotTargetSummary(window)
    local parts = {
        "slotType=" .. safeProbeString(ctx.slotType or (drag and drag.slotType) or ""),
        "hostFamily=" .. safeProbeString(ctx.hostFamily or NMSlotActionCommon.resolveSlotHostFamily(window)),
        "targetKind=" .. safeProbeString(ctx.targetKind or target.kind),
        "targetItemId=" .. safeProbeString(ctx.targetItemId or target.itemId),
        "targetUuid=" .. safeProbeString(ctx.targetUuid or target.uuid),
        "targetVehicleId=" .. safeProbeString(ctx.targetVehicleId or target.vehicleId),
        "targetPartId=" .. safeProbeString(ctx.targetPartId or target.partId),
        "sourceZone=" .. safeProbeString(ctx.sourceZone or (drag and drag.sourceZoneKind) or ""),
        "dragMoved=" .. safeProbeString(ctx.dragMoved ~= nil and tostring(ctx.dragMoved == true) or (drag and tostring(drag.moved == true) or "")),
        "ghostBefore=" .. safeProbeString(ctx.ghostBefore or resolveGhostOwnerSummary(ctx.slotType or (drag and drag.slotType) or "")),
        "ghostAfter=" .. safeProbeString(ctx.ghostAfter or resolveGhostOwnerSummary(ctx.slotType or (drag and drag.slotType) or "")),
        "returnValue=" .. safeProbeString(ctx.returnValue),
        "consumeDecision=" .. safeProbeString(ctx.consumeDecision),
        "entrypoint=" .. safeProbeString(ctx.entrypoint),
        "trace=" .. safeProbeString(ctx.traceId),
        "mouse=" .. safeProbeString(ctx.mouse),
        "winner=" .. safeProbeString(ctx.winner),
        "uiUnderMouse=" .. safeProbeString(ctx.uiUnderMouse),
        "detail=" .. safeProbeString(ctx.detail)
    }
    NMCore.logChannel(channel, tostring(eventName or "slot_extract"), table.concat(parts, " "))
end

function NMSlotActionCommon.slotReleaseOutcomes()
    return {
        handledInsert = SLOT_RELEASE_HANDLED_INSERT,
        handledEject = SLOT_RELEASE_HANDLED_EJECT,
        handledExtract = SLOT_RELEASE_HANDLED_EXTRACT,
        canceledCustomDrag = SLOT_RELEASE_CANCELED_CUSTOM_DRAG,
        notOurs = SLOT_RELEASE_NOT_OURS,
    }
end

function NMSlotActionCommon.shouldConsumeSlotReleaseOutcome(outcome)
    return outcome == SLOT_RELEASE_HANDLED_INSERT
        or outcome == SLOT_RELEASE_HANDLED_EJECT
        or outcome == SLOT_RELEASE_HANDLED_EXTRACT
end

function NMSlotActionCommon.resolveExtractReleaseOutcome(extractDrag, isReleaseOverSourceFn, cancelExtractFn, finalizeExtractFn)
    return NMSlotActionCommon.resolveExtractReleaseOutcomeWithCleanup(
        extractDrag,
        isReleaseOverSourceFn,
        cancelExtractFn,
        finalizeExtractFn,
        nil
    )
end

function NMSlotActionCommon.hasActiveVanillaInventoryDrag()
    local items, ok = NMSlotActionCommon.getDraggedInventoryItems()
    return ok == true and type(items) == "table" and #items > 0
end

function NMSlotActionCommon.resolveExtractReleaseOutcomeWithCleanup(extractDrag, isReleaseOverSourceFn, cancelExtractFn, finalizeExtractFn, cleanupFn, shouldYieldFn)
    if not extractDrag then
        return SLOT_RELEASE_NOT_OURS
    end
    local function finish(outcome)
        if cleanupFn then
            cleanupFn(outcome, extractDrag)
        end
        return outcome
    end
    if extractDrag.moved ~= true then
        if cancelExtractFn then
            cancelExtractFn()
        end
        return finish(SLOT_RELEASE_CANCELED_CUSTOM_DRAG)
    end
    if isReleaseOverSourceFn and isReleaseOverSourceFn(extractDrag) == true then
        if cancelExtractFn then
            cancelExtractFn()
        end
        return finish(SLOT_RELEASE_CANCELED_CUSTOM_DRAG)
    end
    if shouldYieldFn and shouldYieldFn(extractDrag) == true then
        return finish(SLOT_RELEASE_NOT_OURS)
    end
    if finalizeExtractFn and finalizeExtractFn() == true then
        return finish(SLOT_RELEASE_HANDLED_EXTRACT)
    end
    return finish(SLOT_RELEASE_NOT_OURS)
end

function NMSlotActionCommon.canQueueSlotAction(window)
    if not window then return false end
    local resolved = window.resolveContext and window:resolveContext() or nil
    local player = resolved and resolved.player or nil
    local item = resolved and resolved.item or nil
    local vehicle = resolved and resolved.vehicle or nil
    local part = resolved and resolved.part or nil
    if not player then return false end
    if vehicle and part then
        return true
    end
    if not item then return false end
    local location = NMDeviceUIRange and NMDeviceUIRange.resolvePortableTargetLocation
        and NMDeviceUIRange.resolvePortableTargetLocation(window and window.target or nil, item) or nil
    if location and location.mode == "inventory" then
        return true
    end
    if location and location.mode == "placed_world" then
        return NMDeviceUIRange and NMDeviceUIRange.isPlayerWithinSquare and NMDeviceUIRange.isPlayerWithinSquare(player, location.square) or true
    end
    if location and location.mode == "detached_placed" and player.DistToSquared then
        local distSq = tonumber(player:DistToSquared(location.x, location.y)) or 999999
        local thresholdSq = NMDeviceUIRange and NMDeviceUIRange.getWorldInteractionRangeSq and NMDeviceUIRange.getWorldInteractionRangeSq() or (2.8 * 2.8)
        return distSq <= thresholdSq
    end
    return false
end

return NMSlotActionCommon
