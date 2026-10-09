NMDeviceUiPresentationContract = NMDeviceUiPresentationContract or {}

local function copyFields(source)
    local out = {}
    for key, value in pairs(source or {}) do
        out[key] = value
    end
    return out
end

local function ensurePresentation(model)
    if not model then
        return nil
    end
    model.presentation = model.presentation or {}
    return model.presentation
end

local function setSection(model, sectionKey, kind, fields)
    local presentation = ensurePresentation(model)
    if not presentation then
        return nil
    end
    local section = copyFields(fields)
    section.kind = tostring(kind or section.kind or "")
    presentation[sectionKey] = section
    return section
end

function NMDeviceUiPresentationContract.setBackground(model, kind, fields)
    return setSection(model, "background", kind, fields)
end

function NMDeviceUiPresentationContract.setShell(model, kind, fields)
    return setSection(model, "shell", kind, fields)
end

function NMDeviceUiPresentationContract.setWorldItem(model, kind, fields)
    return setSection(model, "worldItem", kind, fields)
end

function NMDeviceUiPresentationContract.setLid(model, kind, fields)
    return setSection(model, "lid", kind, fields)
end

function NMDeviceUiPresentationContract.setVolumeControl(model, kind, fields)
    return setSection(model, "volumeControl", kind, fields)
end

return NMDeviceUiPresentationContract
