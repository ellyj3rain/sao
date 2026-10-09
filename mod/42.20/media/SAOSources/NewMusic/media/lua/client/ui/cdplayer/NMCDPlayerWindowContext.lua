require "ui/shared/host/NMDeviceUiPresentationContract"
require "ui/cdplayer/NMCDPlayerDisplayRenderState"

local env = _G.NMCDPlayerWindowEnv
setfenv(1, env)

function CDPlayerWindow:invalidateContextCache()
    NMSlotHostLifecycle.invalidateContextCache(self)
end

function CDPlayerWindow:markAwaitingAuthoritativeMediaEject(fullType)
    NMSlotHostLifecycle.markAwaitingAuthoritativeMediaEject(self, fullType)
end

function CDPlayerWindow:clearAwaitingAuthoritativeMediaEject()
    NMSlotHostLifecycle.clearAwaitingAuthoritativeMediaEject(self)
end

function CDPlayerWindow:isAwaitingAuthoritativeMediaEject(fullType)
    return NMSlotHostLifecycle.isAwaitingAuthoritativeMediaEject(self, fullType)
end

function CDPlayerWindow:markAwaitingAuthoritativeMediaInsert(fullType)
    NMSlotHostLifecycle.markAwaitingAuthoritativeMediaInsert(self, fullType)
end

function CDPlayerWindow:clearAwaitingAuthoritativeMediaInsert()
    NMSlotHostLifecycle.clearAwaitingAuthoritativeMediaInsert(self)
end

function CDPlayerWindow:isAwaitingAuthoritativeMediaInsert(fullType)
    return NMSlotHostLifecycle.isAwaitingAuthoritativeMediaInsert(self, fullType)
end

function CDPlayerWindow:resolveContextFreshUncached()
    return resolveContextFreshUncached(self)
end

function CDPlayerWindow:resolveContext()
    return NMSlotHostLifecycle.resolveContext(self)
end

function CDPlayerWindow:beginFrameEpoch(reason)
    NMSlotHostLifecycle.beginFrameEpoch(self, reason)
end

function CDPlayerWindow:invalidateSlotFrameModel()
    NMSlotHostLifecycle.invalidateSlotFrameModel(self)
end

function CDPlayerWindow:invalidateRenderModel()
    NMSlotHostLifecycle.invalidateRenderModel(self)
end

function CDPlayerWindow:buildSlotFrameModel()
    return NMSlotHostLifecycle.buildSlotFrameModel(self)
end

function CDPlayerWindow:getSlotRenderState(slotKey)
    return NMSlotHostLifecycle.getSlotRenderState(self, slotKey)
end

function CDPlayerWindow:buildRenderModel()
    return NMDeviceUiHost.buildStableFamilyRenderModel(self, {
        decorateModel = function(window, model, build)
            local frontVariant = window:getFrontVariant()

            model.frontVariant = frontVariant
            NMDeviceUiPresentationContract.setBackground(model, "cdplayer_backplate", { variant = frontVariant })
            NMDeviceUiPresentationContract.setShell(model, "cdplayer_shell", { variant = frontVariant })
            NMDeviceUiPresentationContract.setWorldItem(model, "cd", { variant = frontVariant })
            NMDeviceUiPresentationContract.setLid(model, "hinged_lid", {
                variant = frontVariant,
            })
            NMDeviceUiPresentationContract.setVolumeControl(model, "button_step", {
                variant = frontVariant,
                stepPct = tonumber(BUTTON_VOLUME_STEP_PCT) or 0,
            })
            return model
        end,
    })
end

function CDPlayerWindow:getRenderModel()
    return self:buildRenderModel()
end

function CDPlayerWindow:getRenderState(key)
    local model = self:buildRenderModel()
    return model and model[key] or nil
end

function CDPlayerWindow:resolveContextCached()
    return self:resolveContext()
end

function CDPlayerWindow:resolveContextFresh()
    return NMSlotHostLifecycle.resolveContextFresh(self)
end

function CDPlayerWindow:dispatchUiControl(action, args)
    return NMSlotHostLifecycle.dispatchUiControl(self, action, args, {
        cause = "cdplayer_dispatch_ui_control",
        visibility = false,
    })
end

function CDPlayerWindow:dispatchSlotAction(action, args)
    return NMSlotHostLifecycle.dispatchSlotAction(self, action, args, {
        cause = "cdplayer_dispatch_slot_action",
        visibility = false,
    })
end

function CDPlayerWindow:dispatch(action, args)
    return self:dispatchSlotAction(action, args)
end
