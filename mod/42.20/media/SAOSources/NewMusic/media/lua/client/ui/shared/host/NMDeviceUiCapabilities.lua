NMDeviceUiCapabilities = NMDeviceUiCapabilities or {}

local function copyArray(values)
    local out = {}
    for i = 1, #(values or {}) do
        out[i] = values[i]
    end
    return out
end

function NMDeviceUiCapabilities.fromPolicy(policy)
    local chromePolicy = policy and policy.chromePolicy or nil
    local chromeId = tostring(chromePolicy and chromePolicy.id or policy and policy.chrome or "unknown")
    local capabilities = {
        familyId = tostring(policy and policy.familyId or "unknown"),
        chrome = chromeId,
        chromePolicy = chromePolicy,
        slots = copyArray(policy and policy.slots or {}),
        controls = copyArray(policy and policy.controls or {}),
        supportsMute = policy and policy.supportsMute == true or false,
        supportsHold = policy and policy.supportsHold == true or false,
        supportsLid = policy and policy.supportsLid == true or false,
        supportsShuffleMode = policy and policy.supportsShuffleMode == true or false,
        supportsFancyChrome = chromeId == "fancy_window",
        supportsVanillaChrome = chromeId == "vanilla_window",
        supportsHeaderDrag = chromePolicy and chromePolicy.supportsHeaderDrag == true or false,
        supportsCollapse = chromePolicy and chromePolicy.supportsCollapse == true or false,
        supportsMinimize = chromePolicy and chromePolicy.supportsMinimize == true or false,
        closePlacement = tostring(chromePolicy and chromePolicy.closePlacement or "unknown"),
    }
    return capabilities
end

return NMDeviceUiCapabilities
