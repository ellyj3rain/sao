-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end

local env = _G.NMContextMenusEnv
setfenv(1, env)

return NMContextMenus
