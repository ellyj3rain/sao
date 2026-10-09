-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
-- Vehicle continuity helpers extracted from client playback tick orchestration.
NMClientVehicleContinuity = NMClientVehicleContinuity or {}

local function mirrorVehicleFlag(entry, liveEntry, key, value)
    if entry then
        entry[key] = value
    end
    if liveEntry and liveEntry ~= entry then
        liveEntry[key] = value
    end
end

function NMClientVehicleContinuity.setVehicleIdentityState(entry, liveEntry, uuid, nextState, reason)
    local current = tostring((entry and entry._vehicleIdentityState) or (liveEntry and liveEntry._vehicleIdentityState) or "")
    local target = tostring(nextState or "")
    if target == "" or current == target then
        mirrorVehicleFlag(entry, liveEntry, "_vehicleIdentityState", target ~= "" and target or current)
        return
    end
    mirrorVehicleFlag(entry, liveEntry, "_vehicleIdentityState", target)
    if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
        NMCore.logChannel(
            "runtime",
            "vehicle_identity_state_transition",
            string.format(
                "uuid=%s from=%s to=%s reason=%s",
                tostring(uuid),
                tostring(current ~= "" and current or "nil"),
                tostring(target),
                tostring(reason or "none")
            )
        )
    end
end

function NMClientVehicleContinuity.resolveVehicleCanonicalGeneration(state, entry, liveEntry, resolution)
    local stateGen = tonumber(state and state.sourceGeneration) or 0
    local entryStateSnapshotGen = tonumber(entry and entry.stateSnapshot and entry.stateSnapshot.sourceGeneration) or 0
    local liveStateSnapshotGen = tonumber(liveEntry and liveEntry.stateSnapshot and liveEntry.stateSnapshot.sourceGeneration) or 0
    local entryGen = math.max(
        tonumber(entry and entry.sourceGeneration) or 0,
        tonumber(entry and entry.sourceEpoch) or 0,
        entryStateSnapshotGen
    )
    local liveGen = math.max(
        tonumber(liveEntry and liveEntry.sourceGeneration) or 0,
        tonumber(liveEntry and liveEntry.sourceEpoch) or 0,
        liveStateSnapshotGen
    )
    local acceptedGen = math.max(
        tonumber(entry and entry._acceptedSourceGeneration) or 0,
        tonumber(liveEntry and liveEntry._acceptedSourceGeneration) or 0,
        tonumber(entry and entry._vehicleHydratedSourceGeneration) or 0,
        tonumber(liveEntry and liveEntry._vehicleHydratedSourceGeneration) or 0,
        tonumber(entry and entry._canonicalSourceGeneration) or 0,
        tonumber(liveEntry and liveEntry._canonicalSourceGeneration) or 0
    )
    local resolverGen = tonumber(resolution and resolution.sourceGenerationSeen) or 0
    local chosenGen = math.max(stateGen, entryGen, liveGen, acceptedGen, resolverGen)
    return chosenGen, stateGen, math.max(entryGen, liveGen), acceptedGen, resolverGen
end

function NMClientVehicleContinuity.persistVehicleCanonicalGeneration(entry, liveEntry, state, canonicalGen)
    local gen = tonumber(canonicalGen) or 0
    if gen < 0 then
        return
    end
    local function persist(target)
        if not target then
            return
        end
        target.sourceGeneration = math.max(tonumber(target.sourceGeneration) or 0, gen)
        target.sourceEpoch = math.max(tonumber(target.sourceEpoch) or 0, gen)
        target._acceptedSourceGeneration = math.max(tonumber(target._acceptedSourceGeneration) or 0, gen)
        target._canonicalSourceGeneration = math.max(tonumber(target._canonicalSourceGeneration) or 0, gen)
        if target.stateSnapshot then
            target.stateSnapshot.sourceGeneration = math.max(tonumber(target.stateSnapshot.sourceGeneration) or 0, gen)
        end
    end
    persist(entry)
    if liveEntry and liveEntry ~= entry then
        persist(liveEntry)
    end
    if state then
        state.sourceGeneration = math.max(tonumber(state.sourceGeneration) or 0, gen)
    end
end

function NMClientVehicleContinuity.setVehicleRestartRequired(entry, liveEntry, uuid, required, reason, generation)
    local wasRequired = (entry and entry._vehicleRestartRequired == true)
        or (liveEntry and liveEntry._vehicleRestartRequired == true)
    local prevReason = tostring((entry and entry._vehicleRestartRequiredReason) or (liveEntry and liveEntry._vehicleRestartRequiredReason) or "")
    local prevGen = math.max(
        tonumber(entry and entry._vehicleRestartRequiredGeneration) or -1,
        tonumber(liveEntry and liveEntry._vehicleRestartRequiredGeneration) or -1
    )
    local nextReason = tostring(reason or "")
    local nextGen = tonumber(generation) or -1

    if required then
        local normalized = tostring(nextReason or "")
        local terminal = normalized == "unresolved_timeout_stop"
            or normalized == "runtime_missing_after_resolve"
            or normalized == "world_channel_unhealthy_after_resolve"
        if not terminal then
            required = false
        end
    end

    if required then
        mirrorVehicleFlag(entry, liveEntry, "_vehicleRestartRequired", true)
        mirrorVehicleFlag(entry, liveEntry, "_vehicleRestartRequiredReason", nextReason)
        mirrorVehicleFlag(entry, liveEntry, "_vehicleRestartRequiredGeneration", nextGen)
        if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
            if (not wasRequired) or prevReason ~= nextReason or prevGen ~= nextGen then
                NMCore.logChannel(
                    "runtime",
                    "vehicle_restart_required_set",
                    string.format("uuid=%s reason=%s gen=%s", tostring(uuid), tostring(nextReason ~= "" and nextReason or "none"), tostring(nextGen))
                )
            end
        end
        return
    end

    mirrorVehicleFlag(entry, liveEntry, "_vehicleRestartRequired", false)
    mirrorVehicleFlag(entry, liveEntry, "_vehicleRestartRequiredReason", nil)
    mirrorVehicleFlag(entry, liveEntry, "_vehicleRestartRequiredGeneration", nil)
    if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") and wasRequired then
        NMCore.logChannel(
            "runtime",
            "vehicle_restart_required_clear",
            string.format(
                "uuid=%s reason=%s gen=%s",
                tostring(uuid),
                tostring(nextReason ~= "" and nextReason or "none"),
                tostring(nextGen)
            )
        )
    end
end

function NMClientVehicleContinuity.applyDetachedVehicleContinuity(args)
    local input = type(args) == "table" and args or {}
    local uuid = tostring(input.uuid or "")
    local entry = input.entry
    local liveEntry = input.liveEntry
    local state = input.state
    local src = input.src
    local nowMs = input.nowMs
    local resolveVehicleCanonicalGeneration = input.resolveVehicleCanonicalGeneration
    local persistVehicleCanonicalGeneration = input.persistVehicleCanonicalGeneration
    local setVehicleIdentityState = input.setVehicleIdentityState

    local resolutionMode = "stream_authority_unresolved"
    local targetEntry = liveEntry or entry
    if liveEntry then
        entry = liveEntry
    end
    src = entry and entry.source or src
    local detachedContext = tostring(src and src.context or input.detachedContext or "vehicle")
    state = entry and entry.stateSnapshot or state
    local vehicleResolved = src and src._vehicleResolved == true
    if vehicleResolved then
        resolutionMode = "stream_authority_resolved"
    end
    local resolution = {
        resolved = vehicleResolved == true,
        resolutionMode = resolutionMode,
        matchReason = resolutionMode,
        sourceGenerationSeen = tonumber(targetEntry and targetEntry.sourceGeneration) or 0
    }
    local wasUnresolved = (liveEntry and liveEntry._vehicleWasUnresolved == true)
        or (entry and entry._vehicleWasUnresolved == true)
    if not vehicleResolved then
        local nowMsValue = tonumber(nowMs) or 0
        local canonicalGen = resolveVehicleCanonicalGeneration and resolveVehicleCanonicalGeneration(state, entry, liveEntry, resolution) or 0
        if persistVehicleCanonicalGeneration then
            persistVehicleCanonicalGeneration(entry, liveEntry, state, canonicalGen)
        end
        if setVehicleIdentityState then
            setVehicleIdentityState(entry, liveEntry, uuid, "DETACHED_CONTINUITY", resolutionMode)
        end
        if not wasUnresolved then
            mirrorVehicleFlag(entry, liveEntry, "_vehicleWasUnresolved", true)
            mirrorVehicleFlag(entry, liveEntry, "_vehicleUnresolvedSinceMs", nowMsValue)
            mirrorVehicleFlag(entry, liveEntry, "_vehicleGraceStopped", false)
            if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
                NMCore.logChannel(
                    "runtime",
                    "vehicle_continuity_mode_enter",
                    string.format("uuid=%s mode=DETACHED_CONTINUITY reason=%s", tostring(uuid), tostring(resolutionMode))
                )
            end
        end
    elseif wasUnresolved then
        local canonicalGen = resolveVehicleCanonicalGeneration and resolveVehicleCanonicalGeneration(state, entry, liveEntry, resolution) or 0
        if persistVehicleCanonicalGeneration then
            persistVehicleCanonicalGeneration(entry, liveEntry, state, canonicalGen)
        end
        mirrorVehicleFlag(entry, liveEntry, "_vehicleWasUnresolved", false)
        mirrorVehicleFlag(entry, liveEntry, "_vehicleUnresolvedSinceMs", nil)
        mirrorVehicleFlag(entry, liveEntry, "_vehicleGraceStopped", false)
        if setVehicleIdentityState then
            setVehicleIdentityState(entry, liveEntry, uuid, "LIVE_RESOLVED", "stream_authority_resolved")
        end
        if NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("runtime") then
            NMCore.logChannel(
                "runtime",
                "vehicle_continuity_mode_exit",
                string.format("uuid=%s mode=DETACHED_CONTINUITY reason=resolved_continue", tostring(uuid))
            )
        end
    else
        mirrorVehicleFlag(entry, liveEntry, "_vehicleUnresolvedSinceMs", nil)
        mirrorVehicleFlag(entry, liveEntry, "_vehicleGraceStopped", false)
        if setVehicleIdentityState then
            setVehicleIdentityState(entry, liveEntry, uuid, "LIVE_RESOLVED", resolutionMode)
        end
    end

    return {
        entry = entry,
        liveEntry = liveEntry,
        state = state,
        src = src,
        detachedContext = detachedContext,
        resolution = resolution
    }
end

return NMClientVehicleContinuity

