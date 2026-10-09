NMServerSlotIntentSpine = NMServerSlotIntentSpine or {}

local function callAdapterHook(adapter, hookName, ...)
    if type(adapter) == "table" and type(adapter[hookName]) == "function" then
        adapter[hookName](...)
    end
end

function NMServerSlotIntentSpine.process(player, args, adapter)
    if type(adapter) ~= "table" or type(adapter.resolveTarget) ~= "function" then
        return false, "slot_intent_adapter_missing"
    end

    local ctx, resolveErr = adapter.resolveTarget(player, args)
    if not ctx then
        callAdapterHook(adapter, "onResolveReject", player, args, resolveErr)
        return false, resolveErr
    end

    ctx.args = ctx.args or args or {}
    ctx.player = ctx.player or player

    if type(adapter.prepareContext) == "function" then
        local ok, err = adapter.prepareContext(ctx)
        if ok == false then
            return false, err
        end
    end

    local rawAction = tostring(ctx.args and ctx.args.action or "")
    if type(adapter.normalizeAction) == "function" then
        ctx.action = adapter.normalizeAction(ctx, rawAction)
    else
        ctx.action = rawAction
    end
    ctx.rawAction = rawAction

    if type(adapter.handlePreNormalizedAction) == "function" then
        local handled, ok, reason = adapter.handlePreNormalizedAction(ctx)
        if handled == true then
            return ok == true, reason
        end
    end

    local stateBeforeIntent = NMDeviceState and NMDeviceState.export and NMDeviceState.export(ctx.state) or nil
    ctx.stateBeforeIntent = stateBeforeIntent

    if type(adapter.normalizeIngress) == "function" then
        local normalizedOk, normalizedErr = adapter.normalizeIngress(ctx)
        if not normalizedOk then
            callAdapterHook(adapter, "onNormalizeReject", ctx, normalizedErr)
            return false, "normalize_failed:" .. tostring(normalizedErr or "unknown")
        end
    end

    if type(adapter.handlePreApply) == "function" then
        local handled, ok, reason = adapter.handlePreApply(ctx)
        if handled == true then
            return ok == true, reason
        end
    end

    if type(adapter.handleBeforePayload) == "function" then
        local accepted, acceptErr = adapter.handleBeforePayload(ctx)
        if accepted == false then
            callAdapterHook(adapter, "onTrackFinishedReject", ctx, acceptErr)
            return false, acceptErr
        end
    end

    local payload = nil
    if type(adapter.buildPayload) == "function" then
        payload = adapter.buildPayload(ctx)
    end
    ctx.payload = payload

    if type(adapter.validatePayload) == "function" then
        local payloadOk, payloadErr = adapter.validatePayload(ctx, payload)
        if payloadOk == false then
            return false, payloadErr
        end
    end

    if type(adapter.logIntentAttempt) == "function" then
        adapter.logIntentAttempt(ctx, payload)
    end

    local changed, reason, ops = false, nil, nil
    if type(adapter.applyTransition) == "function" then
        changed, reason, ops = adapter.applyTransition(ctx, payload)
    end
    ctx.changed = changed == true
    ctx.reason = reason
    ctx.ops = ops

    if type(adapter.afterApplyTransition) == "function" then
        local changedOverride, reasonOverride, opsOverride = adapter.afterApplyTransition(ctx, payload, changed, reason, ops)
        if changedOverride ~= nil then
            changed = changedOverride
            ctx.changed = changed == true
        end
        if reasonOverride ~= nil then
            reason = reasonOverride
            ctx.reason = reason
        end
        if opsOverride ~= nil then
            ops = opsOverride
            ctx.ops = ops
        end
    end

    if type(adapter.logTransitionResult) == "function" then
        adapter.logTransitionResult(ctx, payload, changed, reason)
    end

    local postOk = true
    local postState = nil
    if type(adapter.postTransition) == "function" then
        postOk, postState = adapter.postTransition(ctx, changed, reason, ops, stateBeforeIntent)
        if postOk == false then
            if type(adapter.finalizeRejectedTransition) == "function" then
                adapter.finalizeRejectedTransition(ctx, postState)
            end
            return false, postState and postState.reason or reason
        end
    end

    if type(adapter.finalizeTransition) == "function" then
        adapter.finalizeTransition(ctx, changed, reason, ops, postState)
    end

    if changed == true then
        return true, nil
    end
    return false, reason
end

return NMServerSlotIntentSpine
