require "ui/shared/host/NMDeviceUiPresentationContract"
require "ui/shared/NMReadoutCachedLabelState"

local env = _G.NMBoomboxWindowEnv
setfenv(1, env)

local function buildCassetteLabelState(window, resolved)
    if not window then
        return nil
    end
    local mediaState = window.getCassetteDisplayMediaState and window:getCassetteDisplayMediaState() or nil
    if not (mediaState and mediaState.visible == true) then
        return nil
    end
    local ctx = resolved or (window.resolveContextCached and window:resolveContextCached()) or nil
    local state = ctx and ctx.state or nil
    local rect = window.getCassetteLabelRect and window:getCassetteLabelRect() or nil
    if not rect then
        return nil
    end

    return NMReadoutCachedLabelState.build(window, {
        state = state,
        rect = rect,
        padX = CASSETTE_LABEL_TEXT_PAD_X,
        nowMs = tonumber(window._nmFrameNowMs) or getNowMs(),
        pagerHost = window,
        emptyAsNil = true,
        cacheName = "boombox_cassette",
        stateIdentityParts = {
            state and state.mediaFullType,
            state and state.trackIndex,
            state and state.mediaDisplayName,
        },
        identityParts = {
            mediaState.fullType,
            mediaState.texturePath,
        },
    })
end

function BoomboxWindow:buildCassetteLabelState(resolved)
    return buildCassetteLabelState(self, resolved)
end

function BoomboxWindow:hasInsertedCassette()
    local renderState = self:getSlotRenderState("media")
    return tostring(renderState and renderState.fullType or "") ~= ""
end

function BoomboxWindow:getCassetteDisplayMediaState()
    local renderState = self:getSlotRenderState("media")
    local fullType = tostring(renderState and renderState.fullType or "")
    local displayRect = self:getCassetteDisplayRect()
    local epoch = tonumber(self._nmFrameEpoch) or 0
    local cached = self._nmCassetteDisplayMediaState
    if cached and cached.epoch == epoch and tostring(cached.fullType or "") == fullType then
        return cached
    end

    local mediaState = nil
    if fullType == "" then
        mediaState = {
            fullType = "",
            texture = nil,
            texturePath = nil,
            visible = false,
        }
    else
        local texture = nil
        local texturePath = nil
        if NMMediaWorldTextureResolver and NMMediaWorldTextureResolver.resolveTexture then
            texture, texturePath = NMMediaWorldTextureResolver.resolveTexture(fullType)
        end
        mediaState = {
            fullType = fullType,
            texture = texture,
            texturePath = texturePath,
            visible = texture ~= nil,
        }
    end

    mediaState.x = displayRect.x
    mediaState.y = displayRect.y
    mediaState.w = displayRect.w
    mediaState.h = displayRect.h
    mediaState.epoch = epoch
    self._nmCassetteDisplayMediaState = mediaState
    return mediaState
end

function BoomboxWindow:getTimedCassetteAnimationState()
    local timed = self._nmMediaSlotTimedProgress
    local actionName = timed and tostring(timed.action or "") or ""
    local isInsert = actionName == "insert_media"
    local isEject = actionName == "eject_media"
    local displayRect = self:getCassetteDisplayRect()
    if not (timed and timed.active == true and (isInsert or isEject)) then
        return {
            visible = false,
            action = "",
            fullType = "",
            texture = nil,
            texturePath = nil,
            x = displayRect.x,
            y = displayRect.y,
            w = displayRect.w,
            h = displayRect.h,
            alpha = 0.0,
            progress = 0.0
        }
    end
    local fullType = tostring(self._nmPendingMediaSlotFullType or "")
    if fullType == "" then
        return {
            visible = false,
            action = actionName,
            fullType = "",
            texture = nil,
            texturePath = nil,
            x = displayRect.x,
            y = displayRect.y,
            w = displayRect.w,
            h = displayRect.h,
            alpha = 0.0,
            progress = 0.0
        }
    end
    local texture, texturePath = nil, nil
    if NMMediaWorldTextureResolver and NMMediaWorldTextureResolver.resolveTexture then
        texture, texturePath = NMMediaWorldTextureResolver.resolveTexture(fullType)
    end
    if not texture then
        return {
            visible = false,
            action = actionName,
            fullType = fullType,
            texture = nil,
            texturePath = texturePath,
            x = displayRect.x,
            y = displayRect.y,
            w = displayRect.w,
            h = displayRect.h,
            alpha = 0.0,
            progress = 0.0
        }
    end
    local progress = clamp01(tonumber(timed.delta) or 0.0)
    local travelY = math.max(1, math.floor((200 * getFancyDeviceUiScale()) + 0.5))
    local startY = isInsert and (displayRect.y - travelY) or displayRect.y
    local endY = isInsert and displayRect.y or (displayRect.y - travelY)
    local alpha = isInsert and progress or (1.0 - progress)
    return {
        visible = true,
        action = actionName,
        fullType = fullType,
        texture = texture,
        texturePath = texturePath,
        x = displayRect.x,
        y = math.floor(startY + ((endY - startY) * progress) + 0.5),
        w = displayRect.w,
        h = displayRect.h,
        alpha = alpha,
        progress = progress,
    }
end

function BoomboxWindow:invalidateContextCache()
    NMSlotHostLifecycle.invalidateContextCache(self)
end

function BoomboxWindow:onInvalidateSlotHostContextCache()
    self._nmCassetteDisplayMediaState = nil
end

function BoomboxWindow:markAwaitingAuthoritativeMediaEject(fullType)
    NMSlotHostLifecycle.markAwaitingAuthoritativeMediaEject(self, fullType)
end

function BoomboxWindow:clearAwaitingAuthoritativeMediaEject()
    NMSlotHostLifecycle.clearAwaitingAuthoritativeMediaEject(self)
end

function BoomboxWindow:isAwaitingAuthoritativeMediaEject(fullType)
    return NMSlotHostLifecycle.isAwaitingAuthoritativeMediaEject(self, fullType)
end

function BoomboxWindow:markAwaitingAuthoritativeMediaInsert(fullType)
    NMSlotHostLifecycle.markAwaitingAuthoritativeMediaInsert(self, fullType)
end

function BoomboxWindow:clearAwaitingAuthoritativeMediaInsert()
    NMSlotHostLifecycle.clearAwaitingAuthoritativeMediaInsert(self)
end

function BoomboxWindow:isAwaitingAuthoritativeMediaInsert(fullType)
    return NMSlotHostLifecycle.isAwaitingAuthoritativeMediaInsert(self, fullType)
end

function BoomboxWindow:beginFrameEpoch(reason)
    NMSlotHostLifecycle.beginFrameEpoch(self, reason)
end

function BoomboxWindow:resolveContextFreshUncached()
    return resolveContextFreshUncached(self)
end

function BoomboxWindow:resolveContext()
    return NMSlotHostLifecycle.resolveContext(self)
end

function BoomboxWindow:resolveContextCached()
    return self:resolveContext()
end

function BoomboxWindow:resolveContextFresh()
    return NMSlotHostLifecycle.resolveContextFresh(self)
end

function BoomboxWindow:invalidateSlotFrameModel()
    NMSlotHostLifecycle.invalidateSlotFrameModel(self)
end

function BoomboxWindow:invalidateRenderModel()
    NMSlotHostLifecycle.invalidateRenderModel(self)
end

function BoomboxWindow:buildSlotFrameModel()
    return NMSlotHostLifecycle.buildSlotFrameModel(self)
end

function BoomboxWindow:getSlotRenderState(slotKey)
    return NMSlotHostLifecycle.getSlotRenderState(self, slotKey)
end

function BoomboxWindow:getModePolicy()
    local resolved = self:resolveContextCached()
    return tostring(resolved and resolved.state and resolved.state.playbackPolicy or "autoplay")
end

function BoomboxWindow:buildRenderModel()
    return NMDeviceUiHost.buildStableFamilyRenderModel(self, {
        decorateModel = function(window, model, build)
            local resolved = build.resolved
            local variant = window:getBoomboxVariant(resolved)
            local textures = window:resolveBoomboxUITextures(variant)
            model.variant = variant
            model.textures = textures
            NMDeviceUiPresentationContract.setBackground(model, "boombox_base", { variant = variant })
            NMDeviceUiPresentationContract.setShell(model, "boombox_shell", { variant = variant })
            NMDeviceUiPresentationContract.setWorldItem(model, "cassette", { variant = variant })
            NMDeviceUiPresentationContract.setVolumeControl(model, "knob", { variant = variant })
            NMDeviceUiPresentationContract.setLid(model, "hinged_lid", { variant = variant })
            return model
        end
    })
end

function BoomboxWindow:getRenderModel()
    return self:buildRenderModel()
end

function BoomboxWindow:getRenderState(key)
    local model = self:getRenderModel()
    return model and model[key] or nil
end

function BoomboxWindow:dispatchUiControl(action, args)
    return NMSlotHostLifecycle.dispatchUiControl(self, action, args, { cause = "boombox_dispatch_ui_control", visibility = false })
end

function BoomboxWindow:dispatchSlotAction(action, args)
    return NMSlotHostLifecycle.dispatchSlotAction(self, action, args, { cause = "boombox_dispatch_slot_action", visibility = false })
end

function BoomboxWindow:dispatch(action, args)
    return self:dispatchSlotAction(action, args)
end
