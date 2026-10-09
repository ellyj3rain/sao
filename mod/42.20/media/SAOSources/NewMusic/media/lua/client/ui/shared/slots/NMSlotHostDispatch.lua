return function(NMSlotHostLifecycle)
    function NMSlotHostLifecycle.invalidateRenderModel(window)
        if not window then
            return
        end
        if NMUIRenderProbe and NMUIRenderProbe.count then
            NMUIRenderProbe.count(window, "invalidate.render_model", 1)
        end
        window._nmRenderModel = nil
        window._nmRenderModelEpoch = nil
        window._nmRenderModelRevisionKey = nil
        window._nmRenderCache = nil
        window._nmRenderRevision = (tonumber(window._nmRenderRevision) or 0) + 1
        if NMUIRenderProbe and NMUIRenderProbe.count then
            NMUIRenderProbe.count(window, "revision_bump.render", 1)
        end
    end

    local function invalidateAfterIntent(window, options)
        if not window then
            return
        end
        local opts = options or {}
        NMSlotHostLifecycle.invalidateForUiChange(window, {
            cause = opts.cause or "slot_host_dispatch",
            visibility = opts.visibility,
            context = opts.context,
            slotFrame = opts.slotFrame,
            render = opts.render,
            pendingMs = opts.pendingMs,
        })
    end

    local function resolveFresh(window)
        return window and window.resolveContextFresh and window:resolveContextFresh() or nil
    end

    local function performIntent(resolved, action, payload)
        if not resolved then
            return false, "missing_context"
        end
        if resolved.kind == "vehicle" then
            local ok, reason = NMClientIntentDispatch.performVehicleIntent(
                resolved.player,
                resolved.vehicle,
                resolved.part,
                tostring(action or ""),
                payload or {}
            )
            return ok, reason
        end
        local ok, reason = NMClientIntentDispatch.performIntent(
            resolved.player,
            resolved.item,
            tostring(action or ""),
            payload or {}
        )
        return ok, reason
    end

    function NMSlotHostLifecycle.dispatchResolvedIntent(window, action, payload, options)
        local opts = options or {}
        local resolved = resolveFresh(window)
        if not resolved then
            if type(opts.onMissingContext) == "function" then
                opts.onMissingContext(tostring(action or ""), payload or {})
            end
            return false, "missing_context"
        end
        if type(opts.onBeforeIntent) == "function" then
            opts.onBeforeIntent(tostring(action or ""), payload or {}, resolved)
        end
        local ok, reason = performIntent(resolved, action, payload)
        if ok == true and opts.invalidateOnSuccess ~= false then
            invalidateAfterIntent(window, {
                cause = opts.cause or "slot_host_dispatch",
                visibility = opts.visibility,
                context = opts.context,
                slotFrame = opts.slotFrame,
                render = opts.render,
                pendingMs = opts.pendingMs,
            })
        end
        if type(opts.onAfterIntent) == "function" then
            opts.onAfterIntent(tostring(action or ""), payload or {}, resolved, ok, reason)
        end
        return ok, reason
    end

    function NMSlotHostLifecycle.dispatchUiControl(window, action, args, options)
        local opts = options or {}
        return NMDeviceUiHost.dispatch(window, action, args, function(normalizedAction, payload)
            return NMSlotHostLifecycle.dispatchResolvedIntent(window, normalizedAction, payload, opts)
        end)
    end

    function NMSlotHostLifecycle.dispatchSlotAction(window, action, args, options)
        local opts = options or {}
        return NMSlotHostLifecycle.dispatchResolvedIntent(window, tostring(action or ""), args or {}, opts)
    end
end
