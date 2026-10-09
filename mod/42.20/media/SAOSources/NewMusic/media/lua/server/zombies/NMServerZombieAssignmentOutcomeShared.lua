require "zombies/NMZombieAudioVisualSupport"
require "zombies/NMServerZombieAssignmentShared"

NMServerZombieAssignmentOutcomeShared = NMServerZombieAssignmentOutcomeShared or {}

local function getSpecForVariantId(variantId)
    return NMServerZombieAssignmentShared.getSpecForVariantId(variantId)
end

local function resolveDefaultSpec(selection, spec)
    return spec or getSpecForVariantId(selection and selection.variantId or "") or NMZombieAudioVisualSupport.DefaultSpec
end

function NMServerZombieAssignmentOutcomeShared.stampSelectionState(zombie, spec, opts)
    opts = opts or {}
    local selection = opts.selection
    local payload = opts.payload
    local status = tostring(opts.status or "excluded")
    local reason = tostring(opts.reason or "selection_state")
    local resolved = resolveDefaultSpec(selection, spec)
    NMZombieAudioVisualSupport.stampZombieStatus(zombie, resolved, {
        status = status,
        reason = reason,
        strategyName = tostring(opts.strategyName or ""),
        assignmentSource = opts.assignmentSource,
        selection = selection,
        payload = payload,
        processed = status == "excluded" or status == "suppressed" or status == "media_only",
        lastAttemptTick = tonumber(opts.lastAttemptTick) or 0,
        outcome = tostring(resolved.variantId or ""),
        deviceUUID = ""
    })
end

function NMServerZombieAssignmentOutcomeShared.stampFailedState(zombie, spec, opts)
    opts = opts or {}
    local resolved = resolveDefaultSpec(opts.selection, spec)
    NMZombieAudioVisualSupport.stampZombieStatus(zombie, resolved, {
        status = "failed",
        item = opts.item,
        reason = tostring(opts.reason or "unknown"),
        strategyName = tostring(opts.strategyName or ""),
        assignmentSource = opts.assignmentSource,
        selection = opts.selection,
        payload = opts.payload,
        processed = false,
        lastAttemptTick = tonumber(opts.lastAttemptTick) or 0,
        failedTick = tonumber(opts.failedTick) or tonumber(opts.lastAttemptTick) or 0,
        outcome = tostring(resolved.variantId or "")
    })
end

function NMServerZombieAssignmentOutcomeShared.stampAttachedState(zombie, spec, opts)
    opts = opts or {}
    NMZombieAudioVisualSupport.stampZombieStatus(zombie, spec, {
        status = "attached",
        item = opts.item,
        reason = opts.reason,
        strategyName = tostring(opts.strategyName or ""),
        assignmentSource = opts.assignmentSource,
        selection = opts.selection,
        payload = opts.payload,
        processed = true,
        lastAttemptTick = tonumber(opts.lastAttemptTick) or 0,
        outcome = tostring(spec and spec.variantId or "")
    })
end

return NMServerZombieAssignmentOutcomeShared
