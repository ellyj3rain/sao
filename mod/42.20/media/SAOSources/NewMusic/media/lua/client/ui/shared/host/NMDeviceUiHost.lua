require "ui/shared/host/NMDeviceUiFamilyPolicy"
require "ui/shared/host/NMDeviceUiCapabilities"
require "ui/shared/host/NMDeviceUiControlContract"
require "ui/shared/host/NMDeviceUiChromePolicy"

NMDeviceUiHost = NMDeviceUiHost or {}

local function copyArray(values)
    local out = {}
    for i = 1, #(values or {}) do
        out[i] = values[i]
    end
    return out
end

local function resolveWindowState(window, frame)
    local resolved = frame and frame.resolved or nil
    if resolved == nil and window then
        if window.resolveContextCached then
            resolved = window:resolveContextCached()
        elseif window.resolveContext then
            resolved = window:resolveContext()
        end
    end
    local state = resolved and resolved.state or nil
    return state, resolved
end

local function resolveTransportState(window, resolved)
    if not (window and window.buildTransportState) then
        return nil
    end
    local ok, transport = pcall(window.buildTransportState, window, resolved)
    if ok and type(transport) == "table" then
        return transport
    end
    return nil
end

function NMDeviceUiHost.resolveTransportState(window, options)
    local opts = options or {}
    local explicitTransport = opts.transport
    if type(explicitTransport) == "table" then
        return explicitTransport
    end
    local frame = opts.frame
    if type(frame) == "table" and type(frame.transport) == "table" then
        return frame.transport
    end
    local renderModel = opts.renderModel
    if type(renderModel) == "table" and type(renderModel.transport) == "table" then
        return renderModel.transport
    end
    local resolved = opts.resolved
    return resolveTransportState(window, resolved)
end

function NMDeviceUiHost.resolveControlTransportState(window, options)
    local opts = options or {}
    local explicitTransport = opts.transport
    if type(explicitTransport) == "table" then
        return explicitTransport
    end
    local resolved = opts.resolved
    if resolved == nil and window then
        if window.resolveContextFresh then
            resolved = window:resolveContextFresh()
        elseif window.resolveContextCached then
            resolved = window:resolveContextCached()
        elseif window.resolveContext then
            resolved = window:resolveContext()
        end
    end
    -- Control paths must use fresh window-local state and never trust cached render-model
    -- transport snapshots, which are presentation data and may lag other windows/devices.
    return resolveTransportState(window, resolved)
end

function NMDeviceUiHost.getPassiveTransportKey(window)
    if NMDeviceUiHost.getContextRevisionKey then
        return NMDeviceUiHost.getContextRevisionKey(window)
    end
    return string.format(
        "%s|%s",
        tostring(window and window._nmContextRevision or 0),
        tostring(window and window._nmContextCacheTargetKey or "")
    )
end

function NMDeviceUiHost.getFamilyMechanics(window)
    if NMDeviceUiFamilyPolicy and NMDeviceUiFamilyPolicy.resolveMechanicsForWindow then
        return NMDeviceUiFamilyPolicy.resolveMechanicsForWindow(window)
    end
    local policy = window and window.getUiFamilyPolicy and window:getUiFamilyPolicy() or nil
    return policy and policy.mechanics or nil
end

function NMDeviceUiHost.getPowerControlKind(window)
    local mechanics = NMDeviceUiHost.getFamilyMechanics(window)
    return tostring(mechanics and mechanics.powerControl or "")
end

function NMDeviceUiHost.hasCombinedPlayPower(window)
    return NMDeviceUiHost.getPowerControlKind(window) == "combined_play_power"
end

function NMDeviceUiHost.hasSeparatePowerControl(window)
    local kind = NMDeviceUiHost.getPowerControlKind(window)
    return kind == "separate_power_button" or kind == "separate_power_switch"
end

function NMDeviceUiHost.hasHoldControl(window)
    local mechanics = NMDeviceUiHost.getFamilyMechanics(window)
    if mechanics and tostring(mechanics.holdControl or "") ~= "" then
        return true
    end
    local policy = window and window.getUiFamilyPolicy and window:getUiFamilyPolicy() or nil
    return policy and policy.supportsHold == true or false
end

function NMDeviceUiHost.getMediaVisualKind(window)
    local mechanics = NMDeviceUiHost.getFamilyMechanics(window)
    return tostring(mechanics and mechanics.mediaVisual or "")
end

function NMDeviceUiHost.resolvePassiveTransportState(window, resolved, options)
    if not window then
        return nil, ""
    end
    local opts = type(options) == "table" and options or {}
    local cacheField = tostring(opts.cacheField or "_nmPassiveTransportCache")
    local key = NMDeviceUiHost.getPassiveTransportKey(window)
    local cached = window[cacheField]
    if type(cached) == "table" and cached.key == key then
        return cached.transport, key
    end
    local transport = NMDeviceUiHost.resolveTransportState(window, {
        resolved = resolved,
        renderModel = window._nmRenderModel,
    })
    window[cacheField] = {
        key = key,
        transport = transport,
    }
    return transport, key
end

function NMDeviceUiHost.markPassiveTransportSyncedForNextPrerender(window, transportKey, options)
    if not window then
        return
    end
    local opts = type(options) == "table" and options or {}
    local keyField = tostring(opts.keyField or "_nmPassiveTransportSyncedKey")
    local epochField = tostring(opts.epochField or "_nmPassiveTransportSyncedPrerenderEpoch")
    window[keyField] = tostring(transportKey or NMDeviceUiHost.getPassiveTransportKey(window))
    window[epochField] = (tonumber(window._nmFrameEpoch) or 0) + 1
end

function NMDeviceUiHost.hasPassiveTransportSyncForCurrentFrame(window, options)
    if not window then
        return false
    end
    local opts = type(options) == "table" and options or {}
    local keyField = tostring(opts.keyField or "_nmPassiveTransportSyncedKey")
    local epochField = tostring(opts.epochField or "_nmPassiveTransportSyncedPrerenderEpoch")
    local expectedEpoch = tonumber(window[epochField])
    if expectedEpoch == nil or expectedEpoch ~= (tonumber(window._nmFrameEpoch) or 0) then
        return false
    end
    return tostring(window[keyField] or "") == tostring(NMDeviceUiHost.getPassiveTransportKey(window))
end

local function buildChromeState(window, policy)
    local chromePolicy = window and window.getUiChromePolicy and window:getUiChromePolicy() or nil
    local capabilities = window and window.getUiCapabilities and window:getUiCapabilities() or nil
    return {
        id = tostring(chromePolicy and chromePolicy.id or policy and policy.chrome or "unknown"),
        policy = chromePolicy,
        supportsHeaderDrag = capabilities and capabilities.supportsHeaderDrag == true or false,
        supportsCollapse = capabilities and capabilities.supportsCollapse == true or false,
        supportsMinimize = capabilities and capabilities.supportsMinimize == true or false,
        closePlacement = tostring(capabilities and capabilities.closePlacement or chromePolicy and chromePolicy.closePlacement or "unknown"),
    }
end

local function buildControlState(window, policy, state, transport)
    local controls = copyArray(policy and policy.controls or {})
    local controlMap = {}
    for i = 1, #controls do
        local key = tostring(controls[i] or "")
        if key ~= "" then
            controlMap[key] = true
        end
    end
    return {
        order = controls,
        supported = controlMap,
        isPlaying = transport and transport.isPlaying == true or state and state.isPlaying == true or false,
        isOn = transport and transport.isOn == true or state and state.isOn == true or false,
        isMuted = state and state.isMuted == true or false,
        isHold = transport and transport.isHold == true or state and state.isHold == true or false,
        volume = tonumber(transport and transport.volume or state and state.volume or 1.0) or 1.0,
        playbackPolicy = tostring(transport and transport.playbackPolicy or state and state.playbackPolicy or "autoplay"),
        trackCount = tonumber(transport and transport.trackCount or 0) or 0,
        hasMedia = transport and transport.hasMedia == true or tostring(state and state.mediaFullType or "") ~= "",
        hasUsablePower = transport and transport.hasUsablePower == true or false,
    }
end

local function ensureRevisions(window)
    window._nmContextRevision = tonumber(window._nmContextRevision) or 0
    window._nmSlotRevision = tonumber(window._nmSlotRevision) or 0
    window._nmSlotContentRevision = tonumber(window._nmSlotContentRevision) or window._nmSlotRevision or 0
    window._nmRenderRevision = tonumber(window._nmRenderRevision) or 0
    window._nmAnimationRevision = tonumber(window._nmAnimationRevision) or 0
end

function NMDeviceUiHost.attachFamilyPolicy(window, familyId)
    if not window then
        return nil
    end
    local policy = NMDeviceUiFamilyPolicy.get(familyId)
    window._nmUiFamilyPolicy = policy
    window._nmUiChromePolicy = policy and policy.chromePolicy or NMDeviceUiChromePolicy.get(policy and policy.chrome or nil)
    window._nmUiCapabilities = NMDeviceUiCapabilities.fromPolicy(policy)
    ensureRevisions(window)
    return policy
end

function NMDeviceUiHost.initWindow(window, familyId)
    local policy = NMDeviceUiHost.attachFamilyPolicy(window, familyId)
    if not window then
        return policy
    end
    window.getUiFamilyPolicy = window.getUiFamilyPolicy or function(self)
        return self._nmUiFamilyPolicy
    end
    window.getUiCapabilities = window.getUiCapabilities or function(self)
        return self._nmUiCapabilities
    end
    window.getUiChromePolicy = window.getUiChromePolicy or function(self)
        return self._nmUiChromePolicy
    end
    window.normalizeUiAction = window.normalizeUiAction or function(self, action)
        return NMDeviceUiControlContract.normalizeAction(action)
    end
    window.executeUiControl = window.executeUiControl or function(self, action, args)
        return NMDeviceUiControlContract.execute(self, action, args or {})
    end
    return policy
end

function NMDeviceUiHost.touchAnimation(window)
    if not window then
        return 0
    end
    ensureRevisions(window)
    window._nmAnimationRevision = window._nmAnimationRevision + 1
    if NMUIRenderProbe and NMUIRenderProbe.count then
        NMUIRenderProbe.count(window, "revision_bump.animation", 1)
    end
    return window._nmAnimationRevision
end

function NMDeviceUiHost.getContextRevisionKey(window)
    ensureRevisions(window)
    return string.format(
        "%s|%s",
        tostring(window._nmContextRevision or 0),
        tostring(window._nmContextCacheTargetKey or "")
    )
end

function NMDeviceUiHost.getSlotRevisionKey(window)
    ensureRevisions(window)
    return string.format(
        "%s",
        tostring(window._nmSlotContentRevision or window._nmSlotRevision or 0)
    )
end

function NMDeviceUiHost.getInteractionRevisionKey(window)
    ensureRevisions(window)
    return string.format(
        "%s|%s",
        tostring(window._nmFrameEpoch or 0),
        tostring(window._nmAnimationRevision or 0)
    )
end

function NMDeviceUiHost.getRenderRevisionKey(window, includeFrameEpoch)
    ensureRevisions(window)
    local suffix = ""
    if includeFrameEpoch == true then
        suffix = "|" .. tostring(window._nmFrameEpoch or 0)
    end
    return string.format(
        "%s|%s%s",
        tostring(window._nmRenderRevision or 0),
        tostring(window._nmAnimationRevision or 0),
        suffix
    )
end

local function splitRevisionKey(key)
    local values = {}
    local index = 1
    for part in string.gmatch(tostring(key or "") .. "|", "([^|]*)|") do
        if part == "" and index > 1 and index > #values + 1 then
            break
        end
        values[index] = part
        index = index + 1
        if index > 4 then
            break
        end
    end
    return values
end

local function countRenderModelMissReason(window, previousKey, nextKey, includeFrameEpoch)
    if not (NMUIRenderProbe and NMUIRenderProbe.count) then
        return
    end
    if not window._nmRenderModel or tostring(previousKey or "") == "" then
        NMUIRenderProbe.count(window, "render_model.miss_missing_cache", 1)
        return
    end
    local previous = splitRevisionKey(previousKey)
    local nextParts = splitRevisionKey(nextKey)
    if tostring(previous[1] or "") ~= tostring(nextParts[1] or "") then
        NMUIRenderProbe.count(window, "render_model.miss_render_revision", 1)
    end
    if tostring(previous[2] or "") ~= tostring(nextParts[2] or "") then
        NMUIRenderProbe.count(window, "render_model.miss_animation_revision", 1)
    end
    if includeFrameEpoch == true and tostring(previous[3] or "") ~= tostring(nextParts[3] or "") then
        NMUIRenderProbe.count(window, "render_model.miss_frame_epoch", 1)
    end
end

function NMDeviceUiHost.buildCommonRenderModel(window, frame, options)
    if not window then
        return nil
    end
    local opts = options or {}
    local policy = NMDeviceUiFamilyPolicy.resolveForWindow(window)
    local resolved = opts.resolved
    local state = opts.state
    if resolved == nil or state == nil then
        state, resolved = resolveWindowState(window, frame)
    end
    local transport = NMDeviceUiHost.resolveTransportState(window, {
        window = window,
        frame = frame,
        resolved = resolved,
        transport = opts.transport,
    })
    if type(frame) == "table" and type(frame.transport) ~= "table" and type(transport) == "table" then
        frame.transport = transport
    end
    local includeSlotFrameModel = opts.includeSlotFrameModel ~= false
    local slotModel = includeSlotFrameModel and opts.slotModel or nil
    if includeSlotFrameModel and slotModel == nil and window.buildSlotFrameModel then
        slotModel = window:buildSlotFrameModel()
    end
    return {
        familyId = tostring(policy and policy.familyId or "unknown"),
        family = {
            id = tostring(policy and policy.familyId or "unknown"),
            policy = policy,
        },
        policy = policy,
        chromePolicy = window.getUiChromePolicy and window:getUiChromePolicy() or nil,
        chrome = buildChromeState(window, policy),
        capabilities = window.getUiCapabilities and window:getUiCapabilities() or nil,
        target = window.target,
        resolved = resolved,
        state = state,
        transport = transport,
        nowMs = frame and frame.nowMs or tonumber(window._nmFrameNowMs) or 0,
        interaction = {
            dragItems = frame and frame.dragItems or nil,
            dragOk = frame and frame.dragOk == true or false,
        },
        controls = buildControlState(window, policy, state, transport),
        slotModel = slotModel,
        media = slotModel and slotModel.media or nil,
        headphones = slotModel and slotModel.headphones or nil,
        battery = slotModel and slotModel.battery or nil,
    }
end

function NMDeviceUiHost.buildFamilyRenderModel(window, options)
    if not window then
        return nil
    end

    local opts = options or {}
    local includeFrameEpoch = opts.includeFrameEpoch ~= false
    local revisionKey = NMDeviceUiHost.getRenderRevisionKey(window, includeFrameEpoch)
    if window._nmRenderModel and window._nmRenderModelRevisionKey == revisionKey then
        return window._nmRenderModel
    end
    if NMUIRenderProbe and NMUIRenderProbe.count then
        NMUIRenderProbe.count(window, "render_model.rebuild", 1)
    end
    countRenderModelMissReason(window, window._nmRenderModelRevisionKey, revisionKey, includeFrameEpoch)

    local perfStart = NMUIRenderProbe and NMUIRenderProbe.beginWindow and NMUIRenderProbe.beginWindow(window) or nil
    local hostFrame = opts.hostFrame
    if hostFrame == nil and NMSlotHostLifecycle and NMSlotHostLifecycle.buildHostFrame then
        hostFrame = NMSlotHostLifecycle.buildHostFrame(window)
    end
    local frame = opts.frame
    if frame == nil and NMSlotHostLifecycle and NMSlotHostLifecycle.buildInteractionFrame then
        frame = NMSlotHostLifecycle.buildInteractionFrame(window, hostFrame)
    end
    local resolved = opts.resolved
    if resolved == nil and type(frame) == "table" then
        resolved = frame.resolved
    end
    local includeSlotFrameModel = opts.includeSlotFrameModel ~= false
    local slotModel = includeSlotFrameModel and opts.slotModel or nil
    if includeSlotFrameModel and slotModel == nil and window.buildSlotFrameModel then
        slotModel = window:buildSlotFrameModel()
    end
    local transport = NMDeviceUiHost.resolveTransportState(window, {
        frame = frame,
        resolved = resolved,
        transport = opts.transport,
    })
    local model = opts.model
    if type(model) ~= "table" then
        model = NMDeviceUiHost.buildCommonRenderModel(window, frame, {
            resolved = resolved,
            slotModel = slotModel,
            includeSlotFrameModel = includeSlotFrameModel,
            transport = transport,
            state = opts.state,
        })
    end

    local buildContext = {
        hostFrame = hostFrame,
        frame = frame,
        resolved = resolved,
        slotModel = slotModel,
        transport = transport,
        revisionKey = revisionKey,
    }
    if type(opts.decorateModel) == "function" then
        local decorated = opts.decorateModel(window, model, buildContext)
        if type(decorated) == "table" then
            model = decorated
        end
    end

    window._nmRenderModel = model
    window._nmRenderModelEpoch = tonumber(window._nmFrameEpoch) or 0
    window._nmRenderModelRevisionKey = revisionKey
    if NMUIRenderProbe and NMUIRenderProbe.endWindow then
        NMUIRenderProbe.endWindow(window, "device.buildRenderModel", perfStart)
    end
    return model
end

function NMDeviceUiHost.buildStableFamilyRenderModel(window, options)
    local opts = {}
    if type(options) == "table" then
        for key, value in pairs(options) do
            opts[key] = value
        end
    end
    opts.includeFrameEpoch = false
    opts.includeSlotFrameModel = false
    return NMDeviceUiHost.buildFamilyRenderModel(window, opts)
end

function NMDeviceUiHost.dispatch(window, action, args, executor)
    local normalized = NMDeviceUiControlContract.normalizeAction(action)
    if normalized == "close_window" then
        if window and window.close then
            window:close()
            return true, nil
        end
        return false, "missing_close"
    end
    if executor then
        local forwardedAction = normalized ~= "" and normalized or tostring(action or "")
        return executor(forwardedAction, args or {})
    end
    return false, "missing_executor"
end

return NMDeviceUiHost
