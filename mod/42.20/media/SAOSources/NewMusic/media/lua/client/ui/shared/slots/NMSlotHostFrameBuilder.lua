local function resolveNowMs()
    local nowMs = (getTimestampMs and tonumber(getTimestampMs()))
        or (getTimeInMillis and tonumber(getTimeInMillis()))
        or 0
    if nowMs <= 0 and getTimestamp then
        nowMs = (tonumber(getTimestamp()) or 0) * 1000
    end
    return nowMs
end

local function resolveDraggedItemsSnapshot()
    if resolveDraggedInventoryItemsSnapshot then
        return resolveDraggedInventoryItemsSnapshot()
    end
    if NMSlotActionCommon and NMSlotActionCommon.getDraggedInventoryItems then
        return NMSlotActionCommon.getDraggedInventoryItems()
    end
    return {}, true
end

local function composeSlotRenderState(contentState, overlayState)
    if NMDeviceUiSlotContract and NMDeviceUiSlotContract.compose then
        return NMDeviceUiSlotContract.compose(contentState, overlayState)
    end
    return contentState or overlayState
end

return function(NMSlotHostLifecycle)
    function NMSlotHostLifecycle.buildHostFrame(window)
        if not window then
            return nil
        end
        NMSlotHostLifecycle.initHostState(window)
        local revisionKey = nil
        if NMDeviceUiHost and NMDeviceUiHost.getSlotRevisionKey then
            revisionKey = NMDeviceUiHost.getSlotRevisionKey(window)
        else
            revisionKey = string.format("%s|%s", tostring(window._nmSlotRevision or 0), tostring(window._nmFrameEpoch or 0))
        end
        if window._nmSlotHostFrame and window._nmSlotHostFrameRevisionKey == revisionKey then
            return window._nmSlotHostFrame
        end
        if NMUIRenderProbe and NMUIRenderProbe.count then
            NMUIRenderProbe.count(window, "host_frame.rebuild", 1)
        end
        local perfStart = NMUIRenderProbe and NMUIRenderProbe.beginWindow and NMUIRenderProbe.beginWindow(window) or nil

        local resolved = NMSlotHostLifecycle.resolveFrameContext(window)
        local frame = nil
        if window.buildSlotHostFrame then
            frame = window:buildSlotHostFrame(tonumber(window._nmFrameEpoch) or 0, tonumber(window._nmFrameNowMs) or resolveNowMs(), resolved, nil, false)
        end
        if type(frame) ~= "table" then
            frame = {}
        end
        frame.resolved = frame.resolved or resolved
        frame.nowMs = tonumber(frame.nowMs) or tonumber(window._nmFrameNowMs) or resolveNowMs()
        frame.epoch = tonumber(frame.epoch) or tonumber(window._nmFrameEpoch) or 0
        frame.window = frame.window or window

        window._nmSlotHostFrame = frame
        window._nmSlotHostFrameEpoch = tonumber(window._nmFrameEpoch) or 0
        window._nmSlotHostFrameRevisionKey = revisionKey
        if NMUIRenderProbe and NMUIRenderProbe.endWindow then
            NMUIRenderProbe.endWindow(window, "device.buildHostFrame", perfStart)
        end
        return frame
    end

    function NMSlotHostLifecycle.buildInteractionFrame(window, hostFrame)
        if not window then
            return nil
        end
        NMSlotHostLifecycle.initHostState(window)
        local revisionKey = nil
        if NMDeviceUiHost and NMDeviceUiHost.getInteractionRevisionKey then
            revisionKey = NMDeviceUiHost.getInteractionRevisionKey(window)
        else
            revisionKey = tostring(window._nmFrameEpoch or 0)
        end
        if window._nmSlotInteractionFrame and window._nmSlotInteractionFrameRevisionKey == revisionKey then
            return window._nmSlotInteractionFrame
        end
        local baseFrame = hostFrame or NMSlotHostLifecycle.buildHostFrame(window)
        local dragItems, dragOk = NMSlotHostLifecycle.resolveDraggedItemsSnapshot(window)
        local interactionFrame = {
            resolved = baseFrame and baseFrame.resolved or nil,
            nowMs = baseFrame and baseFrame.nowMs or tonumber(window._nmFrameNowMs) or resolveNowMs(),
            epoch = tonumber(window._nmFrameEpoch) or 0,
            window = window,
            dragItems = dragItems,
            dragOk = dragOk == true,
            transport = baseFrame and baseFrame.transport or nil,
        }
        window._nmSlotInteractionFrame = interactionFrame
        window._nmSlotInteractionFrameRevisionKey = revisionKey
        return interactionFrame
    end

    function NMSlotHostLifecycle.buildSlotContentModel(window)
        if not window then
            return nil
        end
        NMSlotHostLifecycle.initHostState(window)
        local revisionKey = nil
        if NMDeviceUiHost and NMDeviceUiHost.getSlotRevisionKey then
            revisionKey = NMDeviceUiHost.getSlotRevisionKey(window)
        else
            revisionKey = tostring(window._nmSlotContentRevision or window._nmSlotRevision or 0)
        end
        if window._nmSlotContentModel and window._nmSlotContentModelRevisionKey == revisionKey then
            return window._nmSlotContentModel
        end
        if NMUIRenderProbe and NMUIRenderProbe.count then
            NMUIRenderProbe.count(window, "slot_frame.content_rebuild", 1)
        end
        local perfStart = NMUIRenderProbe and NMUIRenderProbe.beginWindow and NMUIRenderProbe.beginWindow(window) or nil
        local frame = NMSlotHostLifecycle.buildHostFrame(window)
        local model = {}
        if NMMediaSlot then
            if NMMediaSlot.buildContentState then
                model.media = NMMediaSlot.buildContentState(window, frame)
            elseif NMMediaSlot.buildRenderState then
                model.media = NMMediaSlot.buildRenderState(window, frame)
            end
        end
        if NMHeadphoneSlot then
            if NMHeadphoneSlot.buildContentState then
                model.headphones = NMHeadphoneSlot.buildContentState(window, frame)
            elseif NMHeadphoneSlot.buildRenderState then
                model.headphones = NMHeadphoneSlot.buildRenderState(window, frame)
            end
        end
        if NMBatterySlot then
            if NMBatterySlot.buildContentState then
                model.battery = NMBatterySlot.buildContentState(window, frame)
            elseif NMBatterySlot.buildRenderState then
                model.battery = NMBatterySlot.buildRenderState(window, frame)
            end
        end
        window._nmSlotContentModel = model
        window._nmSlotContentModelRevisionKey = revisionKey
        if NMUIRenderProbe and NMUIRenderProbe.endWindow then
            NMUIRenderProbe.endWindow(window, "device.buildSlotFrameModel", perfStart)
        end
        return model
    end

    function NMSlotHostLifecycle.buildSlotFrameModel(window)
        if not window then
            return nil
        end
        NMSlotHostLifecycle.initHostState(window)
        local revisionKey = nil
        if NMDeviceUiHost and NMDeviceUiHost.getInteractionRevisionKey then
            revisionKey = string.format(
                "%s|%s",
                tostring(NMDeviceUiHost.getSlotRevisionKey(window) or ""),
                tostring(NMDeviceUiHost.getInteractionRevisionKey(window) or "")
            )
        else
            revisionKey = string.format("%s|%s", tostring(window._nmSlotContentRevision or window._nmSlotRevision or 0), tostring(window._nmFrameEpoch or 0))
        end
        if window._nmSlotFrameModel and window._nmSlotFrameModelRevisionKey == revisionKey then
            return window._nmSlotFrameModel
        end
        if NMUIRenderProbe and NMUIRenderProbe.count then
            NMUIRenderProbe.count(window, "slot_frame.interaction_rebuild", 1)
        end
        local contentModel = NMSlotHostLifecycle.buildSlotContentModel(window) or {}
        local hostFrame = NMSlotHostLifecycle.buildHostFrame(window)
        local interactionFrame = NMSlotHostLifecycle.buildInteractionFrame(window, hostFrame)
        local model = {}
        if NMMediaSlot then
            if NMMediaSlot.buildInteractionState then
                model.media = composeSlotRenderState(contentModel.media, NMMediaSlot.buildInteractionState(window, interactionFrame, contentModel.media))
            else
                model.media = contentModel.media
            end
        end
        if NMHeadphoneSlot then
            if NMHeadphoneSlot.buildInteractionState then
                model.headphones = composeSlotRenderState(contentModel.headphones, NMHeadphoneSlot.buildInteractionState(window, interactionFrame, contentModel.headphones))
            else
                model.headphones = contentModel.headphones
            end
        end
        if NMBatterySlot then
            if NMBatterySlot.buildInteractionState then
                model.battery = composeSlotRenderState(contentModel.battery, NMBatterySlot.buildInteractionState(window, interactionFrame, contentModel.battery))
            else
                model.battery = contentModel.battery
            end
        end
        window._nmSlotFrameModel = model
        window._nmSlotFrameModelEpoch = tonumber(window._nmFrameEpoch) or 0
        window._nmSlotFrameModelRevisionKey = revisionKey
        return model
    end

    function NMSlotHostLifecycle.getSlotRenderState(window, slotKey)
        local model = NMSlotHostLifecycle.buildSlotFrameModel(window)
        return model and model[slotKey] or nil
    end
end
