require "ui/shared/host/NMDeviceUiPresentationContract"
require "ui/walkman/NMWalkmanRenderState"

local env = _G.NMWalkmanWindowEnv
setfenv(1, env)

local function logPortableUiProbe(tag, detail)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("portable_ui")) then
        return
    end
    NMCore.logChannel("portable_ui", tostring(tag or "portable_ui"), tostring(detail or ""))
end

function WalkmanWindow:hasInsertedCassette()
    local renderState = self:getSlotRenderState("media")
    return tostring(renderState and renderState.fullType or "") ~= ""
end

function WalkmanWindow:getCassetteDisplayMediaState()
    local renderState = self:getSlotRenderState("media")
    local fullType = tostring(renderState and renderState.fullType or "")
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
    elseif not NMMediaWorldTextureResolver or not NMMediaWorldTextureResolver.resolveTexture then
        mediaState = {
            fullType = fullType,
            texture = nil,
            texturePath = nil,
            visible = false,
        }
    else
        local texture, texturePath = NMMediaWorldTextureResolver.resolveTexture(fullType)
        mediaState = {
            fullType = fullType,
            texture = texture,
            texturePath = texturePath,
            visible = texture ~= nil,
        }
    end
    mediaState.epoch = epoch
    self._nmCassetteDisplayMediaState = mediaState
    return mediaState
end

function WalkmanWindow:getCassetteDisplayTexture()
    local mediaState = self:getCassetteDisplayMediaState()
    return mediaState.texture, mediaState.texturePath
end

function WalkmanWindow:markAwaitingAuthoritativeMediaEject(fullType)
    NMSlotHostLifecycle.markAwaitingAuthoritativeMediaEject(self, fullType)
end

function WalkmanWindow:clearAwaitingAuthoritativeMediaEject()
    NMSlotHostLifecycle.clearAwaitingAuthoritativeMediaEject(self)
end

function WalkmanWindow:isAwaitingAuthoritativeMediaEject(fullType)
    return NMSlotHostLifecycle.isAwaitingAuthoritativeMediaEject(self, fullType)
end

function WalkmanWindow:markAwaitingAuthoritativeMediaInsert(fullType)
    NMSlotHostLifecycle.markAwaitingAuthoritativeMediaInsert(self, fullType)
end

function WalkmanWindow:clearAwaitingAuthoritativeMediaInsert()
    NMSlotHostLifecycle.clearAwaitingAuthoritativeMediaInsert(self)
end

function WalkmanWindow:isAwaitingAuthoritativeMediaInsert(fullType)
    return NMSlotHostLifecycle.isAwaitingAuthoritativeMediaInsert(self, fullType)
end

function WalkmanWindow:invalidateContextCache()
    NMSlotHostLifecycle.invalidateContextCache(self)
end

function WalkmanWindow:onInvalidateSlotHostContextCache()
    self._nmCassetteDisplayMediaState = nil
end

function WalkmanWindow:beginFrameEpoch(reason)
    NMSlotHostLifecycle.beginFrameEpoch(self, reason)
end

function WalkmanWindow:resolveContextFreshUncached()
    return resolveContextFreshUncached(self)
end

function WalkmanWindow:resolveContext()
    return NMSlotHostLifecycle.resolveContext(self)
end

function WalkmanWindow:invalidateSlotFrameModel()
    NMSlotHostLifecycle.invalidateSlotFrameModel(self)
end

function WalkmanWindow:invalidateRenderModel()
    NMSlotHostLifecycle.invalidateRenderModel(self)
end

function WalkmanWindow:buildSlotFrameModel()
    return NMSlotHostLifecycle.buildSlotFrameModel(self)
end

function WalkmanWindow:getSlotRenderState(slotKey)
    return NMSlotHostLifecycle.getSlotRenderState(self, slotKey)
end

function WalkmanWindow:buildRenderModel()
    local revisionKey = NMDeviceUiHost and NMDeviceUiHost.getRenderRevisionKey and NMDeviceUiHost.getRenderRevisionKey(self, false) or nil
    if revisionKey ~= nil and self._nmRenderModel and self._nmRenderModelRevisionKey == revisionKey then
        if NMUIRenderProbe and NMUIRenderProbe.count then
            NMUIRenderProbe.count(self, "walkman_render_model_stable_cache_hit", 1)
        end
    elseif NMUIRenderProbe and NMUIRenderProbe.count then
        NMUIRenderProbe.count(self, "walkman_render_model_stable_cache_miss", 1)
    end
    return NMDeviceUiHost.buildStableFamilyRenderModel(self, {
        decorateModel = function(window, model, build)
            local resolved = build.resolved
            local variant = resolveWalkmanVariantFromItem(resolved and resolved.item or nil)
            local textures = getWalkmanUITexturesForVariant(variant)
            local lidState = window:getLidRenderState(textures)

            model.variant = variant
            model.textures = textures
            NMDeviceUiPresentationContract.setBackground(model, "walkman_backplate", { variant = variant })
            NMDeviceUiPresentationContract.setShell(model, "walkman_shell", { variant = variant })
            NMDeviceUiPresentationContract.setWorldItem(model, "cassette", { variant = variant })
            NMDeviceUiPresentationContract.setVolumeControl(model, "wheel", {
                variant = variant,
            })
            model.lidEdgeState = window:getLidEdgeRenderState(lidState)
            NMDeviceUiPresentationContract.setLid(model, "hinged_lid", {
                variant = variant,
                edgeState = model.lidEdgeState,
            })
            model.cassetteMediaState = window:getCassetteDisplayMediaState()
            model.closeTint = { resolveWalkmanCloseTintForVariant(variant) }
            return model
        end,
    })
end

function WalkmanWindow:getRenderModel()
    return self:buildRenderModel()
end

function WalkmanWindow:getRenderState(key)
    local model = self:buildRenderModel()
    return model and model[key] or nil
end

function WalkmanWindow:dispatchUiControl(action, args)
    return NMSlotHostLifecycle.dispatchUiControl(self, action, args, {
        cause = "walkman_dispatch_ui_control",
        visibility = false,
        onMissingContext = function(normalizedAction, payload)
            logPortableUiProbe(
                "walkman_dispatch_missing_context",
                string.format(
                    "action=%s targetItemId=%s targetUuid=%s mediaItemId=%s slotTraceId=%s",
                    tostring(normalizedAction or ""),
                    tostring(self.target and self.target.itemId or ""),
                    tostring(self.target and self.target.uuid or ""),
                    tostring(payload and payload.mediaItemId or ""),
                    tostring(payload and payload.slotTraceId or "")
                )
            )
        end,
        onBeforeIntent = function(normalizedAction, payload, resolved)
            logPortableUiProbe(
                "walkman_dispatch",
                string.format(
                    "action=%s targetItemId=%s targetUuid=%s resolvedItemId=%s mediaItemId=%s mediaFullType=%s pending=%s slotTraceId=%s",
                    tostring(normalizedAction or ""),
                    tostring(self.target and self.target.itemId or ""),
                    tostring(self.target and self.target.uuid or ""),
                    tostring(resolved.item and NMCore and NMCore.itemId and NMCore.itemId(resolved.item) or ""),
                    tostring(payload and payload.mediaItemId or ""),
                    tostring(payload and (payload.mediaEjectFullType or payload.mediaFullType) or ""),
                    tostring(self._nmPendingMediaSlotFullType or ""),
                    tostring(payload and payload.slotTraceId or "")
                )
            )
        end,
        onAfterIntent = function(normalizedAction, payload, resolved, ok, reason)
            logPortableUiProbe(
                "walkman_dispatch_result",
                string.format(
                    "action=%s ok=%s reason=%s targetItemId=%s targetUuid=%s pending=%s slotTraceId=%s",
                    tostring(normalizedAction or ""),
                    tostring(ok == true),
                    tostring(reason or ""),
                    tostring(self.target and self.target.itemId or ""),
                    tostring(self.target and self.target.uuid or ""),
                    tostring(self._nmPendingMediaSlotFullType or ""),
                    tostring(payload and payload.slotTraceId or "")
                )
            )
        end,
    })
end

function WalkmanWindow:dispatchSlotAction(action, args)
    return NMSlotHostLifecycle.dispatchSlotAction(self, action, args, {
        cause = "walkman_dispatch_slot_action",
        visibility = false,
    })
end

function WalkmanWindow:dispatch(action, args)
    return self:dispatchSlotAction(action, args)
end

function WalkmanWindow:resolveContextCached()
    return self:resolveContext()
end

function WalkmanWindow:resolveContextFresh()
    return NMSlotHostLifecycle.resolveContextFresh(self)
end
