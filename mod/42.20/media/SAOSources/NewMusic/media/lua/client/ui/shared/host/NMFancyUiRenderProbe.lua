NMFancyUiRenderProbe = NMFancyUiRenderProbe or {}

function NMFancyUiRenderProbe.begin(window)
    if NMUIRenderProbe and NMUIRenderProbe.beginWindow then
        return NMUIRenderProbe.beginWindow(window)
    end
    return nil
end

function NMFancyUiRenderProbe.finish(window, key, started)
    if NMUIRenderProbe and NMUIRenderProbe.endWindow then
        NMUIRenderProbe.endWindow(window, tostring(key or ""), started)
    end
end

function NMFancyUiRenderProbe.count(window, key, delta)
    if NMUIRenderProbe and NMUIRenderProbe.count then
        NMUIRenderProbe.count(window, tostring(key or ""), tonumber(delta) or 1)
    end
end

return NMFancyUiRenderProbe
