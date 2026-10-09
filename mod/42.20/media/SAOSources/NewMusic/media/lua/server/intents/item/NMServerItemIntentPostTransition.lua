require "intents/item/NMServerItemIntentLogging"
require "intents/item/NMServerItemIntentTargeting"
require "intents/item/NMServerItemIntentTransition"

NMServerItemIntentPostTransition = NMServerItemIntentPostTransition or {}

local function getCanonicalEntry(ctx)
    if not (ctx and ctx.state and ctx.state.deviceUUID and NMServerRegistryState and NMServerRegistryState.worldRegistry) then
        return nil, nil
    end
    local uuid = tostring(ctx.deviceUUID or ctx.state.deviceUUID or "")
    if uuid == "" then
        return nil, nil
    end
    if tostring(ctx._canonicalEntryUuid or "") ~= uuid then
        ctx._canonicalEntryUuid = uuid
        ctx._canonicalEntry = NMServerRegistryState.worldRegistry[uuid]
    end
    return ctx._canonicalEntry, uuid
end

local function deriveEffectiveMode(ctx, overrideHint)
    local hint = overrideHint
    if hint == nil then
        hint = ctx.sourceModeHint
    end
    return NMServerItemIntentTargeting.deriveServerSourceMode(
        ctx.player,
        ctx.item,
        ctx.profile,
        ctx.state,
        hint
    )
end

local function applyAuthorityForMode(ctx, effectiveMode)
    return NMIntentAuthority.applyMode(
        ctx.state,
        effectiveMode,
        NMServerItemIntentTargeting.buildItemAuthorityContext(ctx.player, ctx.item, ctx.profile, effectiveMode)
    )
end

local function finalizeAuthorityAndReplication(ctx, effectiveMode)
    local mode = tostring(effectiveMode or "off")
    if mode == "" then
        mode = "off"
    end

    NMServerIntentFinalization.run({
        resolveKeep = function()
            return NMRegistryPolicy.shouldKeepWorldSourceState(ctx.state)
        end,
        repairKeep = function(keep)
            local worldMode = mode == "placed" or mode == "attached" or mode == "stowed"
            local playingWorld = tostring(ctx.state and ctx.state.playbackMode or "") == "world"
                and ctx.state
                and ctx.state.isPlaying == true
            if (not keep) and worldMode and playingWorld then
                NMServerItemIntentLogging.logRuntime(
                    "server_item_registry_invariant_repair",
                    string.format(
                        "uuid=%s action=%s mode=%s forcedKeep=true authoritativeMode=%s playbackMode=%s isOn=%s isPlaying=%s",
                        tostring(ctx.state and ctx.state.deviceUUID or ""),
                        tostring(ctx.action or ""),
                        tostring(mode),
                        tostring(ctx.state and ctx.state.authoritativeMode or ""),
                        tostring(ctx.state and ctx.state.playbackMode or ""),
                        tostring(ctx.state and ctx.state.isOn == true),
                        tostring(ctx.state and ctx.state.isPlaying == true)
                    )
                )
                return true
            end
            return keep
        end,
        emitState = function()
            NMServerItemIntentTargeting.sendStateForContext(ctx, ctx.player, ctx.item, ctx.state, mode)
        end,
        resolveEntry = function()
            return NMServerItemIntentTargeting.ensureRegistryEntryForContext(ctx, ctx.item, ctx.profile, ctx.state, mode)
        end,
        broadcastEntry = function(entry, op)
            NMServerItemIntentTargeting.broadcastRegistryEntry(entry, ctx.state, op)
        end,
        removeEntry = function(entry)
            NMServerRegistryState.worldRegistry[tostring(entry.uuid)] = nil
        end,
        afterEntry = function(entry, op)
            NMServerItemIntentLogging.logRuntime(
                "server_item_registry_upsert_remove",
                string.format(
                    "uuid=%s op=%s sourceMode=%s isOn=%s isPlaying=%s",
                    tostring(entry.uuid or ""),
                    tostring(op),
                    tostring(mode),
                    tostring(ctx.state and ctx.state.isOn == true),
                    tostring(ctx.state and ctx.state.isPlaying == true)
                )
            )
        end,
        onMissingEntry = function()
            NMServerItemIntentTargeting.broadcastObserverStateForContext(ctx, ctx.player, ctx.item, ctx.state, mode, ctx.action)
        end
    })
end

local function clearZombieDormantForPlayerOwnership(ctx)
    if not (ctx and ctx.state and ctx.item and ctx.inventory) then
        return false
    end
    if not (NMDeviceState and NMDeviceState.isZombieDormant and NMDeviceState.isZombieDormant(ctx.state)) then
        return false
    end
    if NMServerItemIntentTransition.isSyncAction(ctx.action) then
        return false
    end
    local container = ctx.item.getContainer and ctx.item:getContainer() or nil
    if container ~= ctx.inventory then
        return false
    end
    return NMDeviceState.setZombieDormant and NMDeviceState.setZombieDormant(ctx.state, false, nil, nil) == true or false
end

local function applyItemPostTransitionAuthority(ctx)
    local effectiveMode = deriveEffectiveMode(ctx)
    local authorityChanged = applyAuthorityForMode(ctx, effectiveMode)
    return effectiveMode, authorityChanged
end

local function applyItemTransitionOpsRollbackPolicy(ctx, ops, stateBeforeIntent)
    local opsApplied, opsError = NMServerItemIntentTransition.applyTransitionOps(ctx.player, ctx.inventory, ops)
    if opsError then
        if stateBeforeIntent then
            NMDeviceState.import(ctx.state, stateBeforeIntent)
            NMServerItemIntentTargeting.refreshRequestContext(ctx)
        end
        if NMServerItemIntentLogging.isIntentEnabled() then
            NMServerItemIntentLogging.logIntent(
                "server_ops_failed",
                string.format(
                    "action=%s player=%s itemId=%s item=%s opsError=%s",
                    tostring(ctx.action),
                    tostring(ctx.playerName or "unknown"),
                    tostring(ctx.itemId),
                    tostring(ctx.itemFullType or "unknown"),
                    tostring(opsError)
                )
            )
        end
        return false, "ops_failed:" .. tostring(opsError)
    end

    if opsApplied and NMServerItemIntentLogging.isIntentEnabled() then
        NMServerItemIntentLogging.logIntent(
            "server_ops_applied",
            string.format(
                "action=%s player=%s itemId=%s item=%s",
                tostring(ctx.action),
                tostring(ctx.playerName or "unknown"),
                tostring(ctx.itemId),
                tostring(ctx.itemFullType or "unknown")
            )
        )
    end

    return true, nil
end

local function applyItemContainerVisualSwapPolicy(ctx)
    local swappedVisual, swapErr = NMServerItemIntentTransition.maybeSwapContainerVisualVariant(ctx)
    if swapErr then
        if NMServerItemIntentLogging.isIntentEnabled() then
            NMServerItemIntentLogging.logIntent(
                "server_container_swap_failed",
                string.format(
                    "action=%s player=%s item=%s err=%s",
                    tostring(ctx.action),
                    tostring(ctx.playerName or "unknown"),
                    tostring(ctx.itemFullType or "unknown"),
                    tostring(swapErr)
                )
            )
        end
        return false
    end

    if swappedVisual and NMServerItemIntentLogging.isIntentEnabled() then
        NMServerItemIntentLogging.logIntent(
            "server_container_swap_applied",
            string.format(
                "action=%s player=%s item=%s media=%s",
                tostring(ctx.action),
                tostring(ctx.playerName or "unknown"),
                tostring(ctx.itemFullType or "unknown"),
                tostring(ctx.state and ctx.state.mediaFullType or "nil")
            )
        )
    end

    return swappedVisual == true
end

local function applyItemPostTransitionHeadphonePolicy(ctx, effectiveMode)
    return NMServerItemIntentTransition.reconcileHeadphoneWearState(ctx.player, ctx.profile, ctx.state, ctx.action, effectiveMode)
end

local function applyItemPostTransitionRevisionPolicy(ctx, changed, authorityChanged, dormantCleared, preReconcileChanged, postReconcileChanged)
    if changed and NMPlaybackContinuityPolicy.doesActionAdvancePlaybackContinuity(ctx.action) then
        NMDeviceState.bumpPlaybackEpoch(ctx.state)
    end
    if changed or authorityChanged or dormantCleared or preReconcileChanged or postReconcileChanged then
        NMDeviceState.bumpRevision(ctx.state)
    end
end

local function runItemPostTransitionMutationPolicies(ctx, stateBeforeIntent, changed, ops, preReconcileChanged)
    local effectiveMode, authorityChanged = applyItemPostTransitionAuthority(ctx)
    local dormantCleared = clearZombieDormantForPlayerOwnership(ctx)
    local opsOk, opsReason = applyItemTransitionOpsRollbackPolicy(ctx, ops, stateBeforeIntent)
    if not opsOk then
        return false, {
            reason = opsReason,
            effectiveMode = deriveEffectiveMode(ctx)
        }
    end

    applyItemContainerVisualSwapPolicy(ctx)
    local postReconcileChanged = applyItemPostTransitionHeadphonePolicy(ctx, effectiveMode)
    applyItemPostTransitionRevisionPolicy(
        ctx,
        changed,
        authorityChanged,
        dormantCleared,
        preReconcileChanged,
        postReconcileChanged
    )

    return true, {
        effectiveMode = effectiveMode,
        authorityChanged = authorityChanged,
        dormantCleared = dormantCleared,
        postReconcileChanged = postReconcileChanged
    }
end

function NMServerItemIntentPostTransition.importCanonicalIfNewer(ctx)
    local entry, uuid = getCanonicalEntry(ctx)
    if not entry or uuid == nil then
        return false
    end
    local canonical = entry and entry.stateSnapshot or nil
    if type(canonical) ~= "table" then
        return false
    end

    local localGen = tonumber(ctx.state.sourceGeneration) or 0
    local localRev = tonumber(ctx.state.revision) or 0
    local localEpoch = tonumber(ctx.state.playbackEpoch) or 0
    local canonicalGen = tonumber(canonical.sourceGeneration) or 0
    local canonicalRev = tonumber(canonical.revision) or 0
    local canonicalEpoch = tonumber(canonical.playbackEpoch) or 0

    local newer = false
    if canonicalGen > localGen then
        newer = true
    elseif canonicalGen == localGen and canonicalRev > localRev then
        newer = true
    elseif canonicalGen == localGen and canonicalRev == localRev and canonicalEpoch > localEpoch then
        newer = true
    end

    if not newer then
        return false
    end

    NMDeviceState.import(ctx.state, canonical)
    NMServerItemIntentTargeting.refreshRequestContext(ctx)
    NMServerItemIntentLogging.logRuntime(
        "server_item_canonical_refresh_before_intent",
        string.format(
            "uuid=%s localGen=%s localRev=%s localEpoch=%s canonicalGen=%s canonicalRev=%s canonicalEpoch=%s",
            tostring(uuid),
            tostring(localGen),
            tostring(localRev),
            tostring(localEpoch),
            tostring(canonicalGen),
            tostring(canonicalRev),
            tostring(canonicalEpoch)
        )
    )
    return true
end

function NMServerItemIntentPostTransition.hydrateTimelineFromCanonical(ctx)
    local entry, uuid = getCanonicalEntry(ctx)
    if not entry or uuid == nil then
        return false
    end
    local canonical = entry and entry.stateSnapshot or nil
    if type(canonical) ~= "table" then
        return false
    end
    local localStarted = tonumber(ctx.state.serverTrackStartedAtMs) or 0
    local canonicalStarted = tonumber(canonical.serverTrackStartedAtMs) or 0
    if localStarted > 0 or canonicalStarted <= 0 then
        return false
    end
    ctx.state.serverTrackStartedAtMs = canonical.serverTrackStartedAtMs
    ctx.state.serverTrackDurationMs = canonical.serverTrackDurationMs
    ctx.state.serverTrackDueAtMs = canonical.serverTrackDueAtMs
    ctx.state._serverTrackTimingMode = canonical._serverTrackTimingMode
    ctx.state._serverTrackArmToken = canonical._serverTrackArmToken
    NMServerItemIntentLogging.logRuntime(
        "server_item_timeline_hydrated_from_registry",
        string.format(
            "uuid=%s startedAtMs=%s dueAtMs=%s timingMode=%s",
            tostring(uuid),
            tostring(ctx.state.serverTrackStartedAtMs or 0),
            tostring(ctx.state.serverTrackDueAtMs or 0),
            tostring(ctx.state._serverTrackTimingMode or "")
        )
    )
    return true
end

function NMServerItemIntentPostTransition.prepareContext(ctx)
    NMServerItemIntentTargeting.refreshRequestContext(ctx)
    NMServerItemIntentPostTransition.importCanonicalIfNewer(ctx)
    if NMServerItemIntentTransition.isSyncAction(ctx.args and ctx.args.action) then
        NMServerItemIntentPostTransition.hydrateTimelineFromCanonical(ctx)
    end
    return true
end

function NMServerItemIntentPostTransition.handlePreNormalizedAction(ctx)
    local modeFrom = tostring(ctx.state and ctx.state.authoritativeMode or "off")
    local modeTo = tostring(ctx.sourceModeHint or modeFrom)
    ctx.preReconcileChanged = NMServerItemIntentTransition.reconcileHeadphoneWearState(
        ctx.player,
        ctx.profile,
        ctx.state,
        ctx.action,
        modeTo
    )
    if NMServerItemIntentTransition.isSyncAction(ctx.action)
        and ctx.state
        and ctx.state.isOn == true
        and ctx.state.isPlaying == true
        and modeFrom ~= modeTo then
        NMServerItemIntentLogging.logRuntime(
            "mode_churn_transport_neutral_applied",
            string.format(
                "uuid=%s token=%s:%s fromMode=%s toMode=%s",
                tostring(ctx.state and ctx.state.deviceUUID or ""),
                tostring(ctx.state and ctx.state.playbackEpoch or 0),
                tostring(ctx.state and ctx.state.trackIndex or 0),
                tostring(modeFrom),
                tostring(modeTo)
            )
        )
    end
    if NMServerItemIntentTransition.staleRevisionRejected(ctx, ctx.action) then
        local staleMode = deriveEffectiveMode(ctx)
        local authorityChanged = applyAuthorityForMode(ctx, staleMode)
        if authorityChanged or ctx.preReconcileChanged then
            NMDeviceState.bumpRevision(ctx.state)
        end
        finalizeAuthorityAndReplication(ctx, staleMode)
        return true, false, "stale_revision"
    end
    return false
end

function NMServerItemIntentPostTransition.postItemIntentTransition(ctx, changed, reason, ops, stateBeforeIntent)
    if (not NMServerItemIntentTransition.isSyncAction(ctx.action)) and changed ~= true then
        if NMServerItemIntentLogging.isIntentEnabled() then
            NMServerItemIntentLogging.logIntent(
                "server_intent_rejected",
                string.format(
                    "action=%s reason=%s player=%s item=%s media=%s isOn=%s isPlaying=%s hasTrack=%s trackCount=%d",
                    tostring(ctx.action),
                    tostring(reason or "none"),
                    tostring(ctx.playerName or "unknown"),
                    tostring(ctx.itemFullType or "unknown"),
                    tostring(ctx.state and ctx.state.mediaFullType or "nil"),
                    tostring(ctx.state and ctx.state.isOn == true),
                    tostring(ctx.state and ctx.state.isPlaying == true),
                    tostring(ctx.payload and ctx.payload.hasTrack == true),
                    tonumber(ctx.payload and ctx.payload.trackCount) or 0
                )
            )
        end
        local rejectedMode = deriveEffectiveMode(ctx)
        local rejectedAuthorityChanged = applyAuthorityForMode(ctx, rejectedMode)
        if rejectedAuthorityChanged or ctx.preReconcileChanged then
            NMDeviceState.bumpRevision(ctx.state)
        end
        return false, {
            reason = reason,
            effectiveMode = rejectedMode
        }
    end
    return runItemPostTransitionMutationPolicies(
        ctx,
        stateBeforeIntent,
        changed,
        ops,
        ctx.preReconcileChanged
    )
end

function NMServerItemIntentPostTransition.finalizeRejectedTransition(ctx, postState)
    finalizeAuthorityAndReplication(ctx, postState and postState.effectiveMode)
end

function NMServerItemIntentPostTransition.finalizeTransition(ctx, changed, _, _, postState)
    local effectiveMode = postState and postState.effectiveMode or "off"
    if changed == true and NMServerItemIntentLogging.isIntentEnabled() then
        NMServerItemIntentLogging.logIntent(
            "server_intent_applied",
            string.format(
                "action=%s rawAction=%s player=%s item=%s media=%s isOn=%s isPlaying=%s mode=%s trackIndex=%d",
                tostring(ctx.action),
                tostring(ctx.rawAction),
                tostring(ctx.playerName or "unknown"),
                tostring(ctx.itemFullType or "unknown"),
                tostring(ctx.state and ctx.state.mediaFullType or "nil"),
                tostring(ctx.state and ctx.state.isOn == true),
                tostring(ctx.state and ctx.state.isPlaying == true),
                tostring(effectiveMode),
                tonumber(ctx.state and ctx.state.trackIndex) or 1
            )
        )
    end
    finalizeAuthorityAndReplication(ctx, effectiveMode)
end

return NMServerItemIntentPostTransition
