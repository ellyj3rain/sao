-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
NMDeviceUiChromePolicy = NMDeviceUiChromePolicy or {}

local policies = {
    vanilla_window = {
        id = "vanilla_window",
        supportsHeaderDrag = false,
        supportsCollapse = false,
        supportsMinimize = false,
        closePlacement = "header",
        pinStyle = "vanilla",
    },
    fancy_window = {
        id = "fancy_window",
        supportsHeaderDrag = true,
        supportsCollapse = true,
        supportsMinimize = true,
        closePlacement = "top_left",
        pinStyle = "none",
    }
}

function NMDeviceUiChromePolicy.get(chromeId)
    return policies[tostring(chromeId or "")] or nil
end

return NMDeviceUiChromePolicy
