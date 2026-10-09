-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
require "ui/shared/host/NMDeviceUiPresentationContract"

_G.NMDeviceWindow = _G.NMDeviceWindow or {}
_G.NMDeviceWindowEnv = _G.NMDeviceWindowEnv or {}
local env = _G.NMDeviceWindowEnv
if getmetatable(env) == nil then
    setmetatable(env, { __index = _G })
end
env.NMDeviceWindow = _G.NMDeviceWindow
setfenv(1, env)

local function logPortableUiProbe(tag, detail)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("portable_ui")) then
        return
    end
    NMCore.logChannel("portable_ui", tostring(tag or "portable_ui"), tostring(detail or ""))
end

local function logVehicleSlotTrace(stage, detail)
    if not (NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("slot")) then
        return
    end
    NMCore.logChannel("slot", tostring(stage or "vehicle_slot_trace"), tostring(detail or ""))
end

function resolveDraggedInventoryItemsSnapshot()
    if not ISMouseDrag then return {}, true end
    local dragging = ISMouseDrag.dragging
    if dragging == nil then return {}, true end
    if type(dragging) ~= "table" then return nil, false end
    if #dragging <= 0 then return {}, true end
    if not (ISInventoryPane and ISInventoryPane.getActualItems) then
        return nil, false
    end
    local ok, actual = pcall(ISInventoryPane.getActualItems, dragging)
    if not ok or type(actual) ~= "table" then
        return nil, false
    end
    local out = {}
    for i = 1, #actual do
        local item = actual[i]
        if item and item.getFullType then
            out[#out + 1] = item
        end
    end
    return out, true
end

function DeviceWindow:buildSlotFrameModel()
    return NMSlotHostLifecycle.buildSlotFrameModel(self)
end

function DeviceWindow:getSlotRenderState(slotKey)
    return NMSlotHostLifecycle.getSlotRenderState(self, slotKey)
end

function DeviceWindow:buildRenderModel()
    return NMDeviceUiHost.buildFamilyRenderModel(self, {
        decorateModel = function(window, model, build)
            local frame = build.frame
            local dragItems = frame and frame.dragItems or nil
            local dragOk = frame and frame.dragOk == true or false
            model.dragItems = dragItems
            model.dragOk = dragOk
            model.interaction = model.interaction or {}
            model.interaction.dragItems = dragItems
            model.interaction.dragOk = dragOk
            NMDeviceUiPresentationContract.setBackground(model, "generic_window", {})
            NMDeviceUiPresentationContract.setWorldItem(model, "cover", {})
            NMDeviceUiPresentationContract.setVolumeControl(model, "slider", {})
            if NMReadoutPane and NMReadoutPane.buildRenderState then
                model.readout = NMReadoutPane.buildRenderState(window, frame)
            end
            if NMCoverPane and NMCoverPane.buildRenderState then
                model.cover = NMCoverPane.buildRenderState(window, frame)
            end
            if NMTransportButtonRow and NMTransportButtonRow.buildRenderState then
                model.transport = NMTransportButtonRow.buildRenderState(window, frame)
            end
            if NMPowerButton and NMPowerButton.buildRenderState then
                model.power = NMPowerButton.buildRenderState(window, frame)
            end
            if NMVolumeFader and NMVolumeFader.buildRenderState then
                model.fader = NMVolumeFader.buildRenderState(window, frame)
            end
            return model
        end,
    })
end

function DeviceWindow:getRenderModel()
    return self:buildRenderModel()
end

function DeviceWindow:getRenderState(key)
    local model = self:buildRenderModel()
    return model and model[key] or nil
end

function DeviceWindow:dispatchUiControl(action, args)
    return NMSlotHostLifecycle.dispatchUiControl(self, action, args, {
        cause = "generic_dispatch_ui_control",
        visibility = false,
        onMissingContext = function(normalizedAction, payload)
            logPortableUiProbe(
                "generic_dispatch_missing_context",
                string.format(
                    "action=%s targetKind=%s targetItemId=%s targetUuid=%s mediaItemId=%s slotTraceId=%s",
                    tostring(normalizedAction or ""),
                    tostring(self.target and self.target.kind or ""),
                    tostring(self.target and self.target.itemId or ""),
                    tostring(self.target and self.target.uuid or ""),
                    tostring(payload and payload.mediaItemId or ""),
                    tostring(payload and payload.slotTraceId or "")
                )
            )
        end,
        onBeforeIntent = function(normalizedAction, payload, resolved)
            logPortableUiProbe(
                "generic_dispatch",
                string.format(
                    "action=%s targetKind=%s targetItemId=%s targetUuid=%s resolvedItemId=%s mediaItemId=%s mediaFullType=%s pending=%s slotTraceId=%s",
                    tostring(normalizedAction or ""),
                    tostring(self.target and self.target.kind or ""),
                    tostring(self.target and self.target.itemId or ""),
                    tostring(self.target and self.target.uuid or ""),
                    tostring(resolved.item and NMCore and NMCore.itemId and NMCore.itemId(resolved.item) or ""),
                    tostring(payload and payload.mediaItemId or ""),
                    tostring(payload and (payload.mediaEjectFullType or payload.mediaFullType) or ""),
                    tostring(self._nmPendingMediaSlotFullType or ""),
                    tostring(payload and payload.slotTraceId or "")
                )
            )
            if resolved.kind == "vehicle" then
                logVehicleSlotTrace(
                    "vehicle_slot_ui_dispatch",
                    string.format(
                        "trace=%s host=vehicle ui=vehicle action=%s stage=ui_dispatch result=ok targetKind=%s vehicleId=%s partId=%s pending=%s",
                        tostring(payload and payload.slotTraceId or ""),
                        tostring(normalizedAction or ""),
                        tostring(self.target and self.target.kind or ""),
                        tostring(resolved.vehicle and resolved.vehicle.getId and resolved.vehicle:getId() or ""),
                        tostring(resolved.part and resolved.part.getId and resolved.part:getId() or ""),
                        tostring(self._nmPendingMediaSlotFullType or "")
                    )
                )
            end
        end,
        onAfterIntent = function(normalizedAction, payload, resolved, ok, reason)
            logPortableUiProbe(
                "generic_dispatch_result",
                string.format(
                    "action=%s ok=%s reason=%s targetKind=%s targetItemId=%s targetUuid=%s pending=%s slotTraceId=%s",
                    tostring(normalizedAction or ""),
                    tostring(ok == true),
                    tostring(reason or ""),
                    tostring(self.target and self.target.kind or ""),
                    tostring(self.target and self.target.itemId or ""),
                    tostring(self.target and self.target.uuid or ""),
                    tostring(self._nmPendingMediaSlotFullType or ""),
                    tostring(payload and payload.slotTraceId or "")
                )
            )
            if resolved.kind == "vehicle" then
                logVehicleSlotTrace(
                    "vehicle_slot_ui_dispatch_result",
                    string.format(
                        "trace=%s host=vehicle ui=vehicle action=%s stage=ui_dispatch_result result=%s vehicleId=%s partId=%s reason=%s pending=%s",
                        tostring(payload and payload.slotTraceId or ""),
                        tostring(normalizedAction or ""),
                        tostring(ok == true and "ok" or "reject"),
                        tostring(resolved.vehicle and resolved.vehicle.getId and resolved.vehicle:getId() or ""),
                        tostring(resolved.part and resolved.part.getId and resolved.part:getId() or ""),
                        tostring(reason or ""),
                        tostring(self._nmPendingMediaSlotFullType or "")
                    )
                )
            end
        end,
    })
end

function DeviceWindow:dispatchSlotAction(action, args)
    return NMSlotHostLifecycle.dispatchSlotAction(self, action, args, {
        cause = "generic_dispatch_slot_action",
        visibility = false,
        onMissingContext = function(rawAction, payload)
            logPortableUiProbe(
                "generic_slot_dispatch_missing_context",
                string.format(
                    "action=%s targetKind=%s targetItemId=%s targetUuid=%s mediaItemId=%s slotTraceId=%s",
                    tostring(rawAction or ""),
                    tostring(self.target and self.target.kind or ""),
                    tostring(self.target and self.target.itemId or ""),
                    tostring(self.target and self.target.uuid or ""),
                    tostring(payload and payload.mediaItemId or ""),
                    tostring(payload and payload.slotTraceId or "")
                )
            )
        end,
    })
end

function DeviceWindow:dispatch(action, args)
    return self:dispatchSlotAction(action, args)
end
