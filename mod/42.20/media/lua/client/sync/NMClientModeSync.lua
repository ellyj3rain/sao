-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
-- MP mode-sync intent emitter for authoritative attached/placed/stowed transitions.
NMClientModeSync = NMClientModeSync or {}
NMClientModeSync._slots = NMClientModeSync._slots or {}

local function nowMs()
    if getTimestampMs then
        local v = tonumber(getTimestampMs())
        if v then return v end
    end
    if getTimestamp then
        local v = tonumber(getTimestamp())
        if v then return v * 1000 end
    end
    return 0
end

local function getSlot(uuid)
    local key = tostring(uuid or "")
    if key == "" then
        return nil
    end
    local slot = NMClientModeSync._slots[key]
    if not slot then
        slot = {
            action = nil,
            attempts = 0,
            nextRetryMs = 0,
            ackedMode = nil,
            ackedSourceGen = nil
        }
        NMClientModeSync._slots[key] = slot
    end
    return slot
end

local function resolveModeAction(profile, state, mode)
    if not (profile and state) then
        return nil
    end
    local portableAction = NMDeviceProfiles.resolvePortableTrackedAction and NMDeviceProfiles.resolvePortableTrackedAction(profile, mode) or nil
    if portableAction then
        return portableAction
    end
    if not NMRegistryPolicy.shouldKeepWorldSourceState(state) then
        return nil
    end
    local normalized = tostring(mode or "off")
    if normalized == "attached" and NMDeviceProfiles.canAnyWorldPlayback(profile) then
        return "sync_attached_world"
    end
    if normalized == "placed" and NMDeviceProfiles.canPlacedWorldPlayback(profile) then
        return "sync_placed_world"
    end
    if normalized == "stowed" and NMDeviceProfiles.canAnyWorldPlayback(profile) then
        local invOutput = NMDeviceProfiles.resolveOutputMode(profile, state, "inventory", true)
        if tostring(invOutput or "none") == "none" then
            return "sync_inventory_stowed"
        end
    end
    return nil
end

function NMClientModeSync.emit(player, item, profile, state, mode)
    if not (NMCore.isMPClientRuntime and NMCore.isMPClientRuntime()) then
        return
    end
    if not (player and item and profile and state and sendClientCommand) then
        return
    end
    if NMDeviceState and NMDeviceState.isZombieDormant and NMDeviceState.isZombieDormant(state) then
        return
    end

    local uuid = tostring(state.deviceUUID or "")
    local itemId = NMCore.itemId(item)
    if uuid == "" or not itemId or tostring(itemId) == "" then
        return
    end

    local action = resolveModeAction(profile, state, mode)
    local slot = getSlot(uuid)
    if not slot then
        return
    end
    if not action then
        slot.action = nil
        slot.attempts = 0
        slot.nextRetryMs = 0
        return
    end

    local now = nowMs()
    if slot.action ~= action then
        slot.action = action
        slot.attempts = 0
        slot.nextRetryMs = 0
    end
    local currentMode = tostring(mode or "off")
    local currentSourceGen = tonumber(state and state.sourceGeneration) or 0

    if tostring(slot.ackedMode or "") == currentMode and tonumber(slot.ackedSourceGen or -1) == currentSourceGen then
        return
    end
    if now < (tonumber(slot.nextRetryMs) or 0) then
        return
    end

    sendClientCommand(player, NMCore.NetModule, "intent", {
        action = action,
        uuid = uuid,
        itemId = tostring(itemId),
        sourceMode = tostring(mode or "off"),
        expectedRevision = tonumber(state.revision) or 0,
        expectedPlaybackEpoch = tonumber(state.playbackEpoch) or 0
    })

    slot.attempts = (tonumber(slot.attempts) or 0) + 1
    local retryMs = math.min(5000, 500 * (2 ^ math.max(0, slot.attempts - 1)))
    slot.nextRetryMs = now + retryMs
    NMRuntimeProbeAdapter.emit(
        "runtime",
        "runtime",
        "mode_sync_emit",
        string.format(
            "uuid=%s action=%s mode=%s attempt=%d retryMs=%d",
            tostring(uuid),
            tostring(action),
            tostring(mode or "off"),
            tonumber(slot.attempts) or 0,
            tonumber(retryMs) or 0
        )
    )
end

function NMClientModeSync.emitExplicit(player, item, state, action, sourceMode)
    if not (NMCore.isMPClientRuntime and NMCore.isMPClientRuntime()) then
        return false
    end
    if not (player and item and state and sendClientCommand) then
        return false
    end
    if NMDeviceState and NMDeviceState.isZombieDormant and NMDeviceState.isZombieDormant(state) then
        return false
    end
    local uuid = tostring(state.deviceUUID or "")
    local itemId = NMCore.itemId(item)
    local act = tostring(action or "")
    if uuid == "" or not itemId or tostring(itemId) == "" or act == "" then
        return false
    end
    sendClientCommand(player, NMCore.NetModule, "intent", {
        action = act,
        uuid = uuid,
        itemId = tostring(itemId),
        sourceMode = tostring(sourceMode or ""),
        expectedRevision = tonumber(state.revision) or 0,
        expectedPlaybackEpoch = tonumber(state.playbackEpoch) or 0
    })
    if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
        NMCore.logChannel(
            "runtime",
            "mode_sync_emit",
            string.format("uuid=%s action=%s mode=%s explicit=true", tostring(uuid), tostring(act), tostring(sourceMode or ""))
        )
    end
    return true
end

function NMClientModeSync.onAck(uuid, sourceMode, sourceGeneration)
    local slot = getSlot(uuid)
    if not slot then
        return
    end
    slot.action = nil
    slot.attempts = 0
    slot.nextRetryMs = 0
    slot.ackedMode = tostring(sourceMode or "")
    slot.ackedSourceGen = tonumber(sourceGeneration) or 0
end

function NMClientModeSync.prune(validMap)
    for uuid, _ in pairs(NMClientModeSync._slots or {}) do
        if not (validMap and validMap[uuid]) then
            NMClientModeSync._slots[uuid] = nil
        end
    end
end

