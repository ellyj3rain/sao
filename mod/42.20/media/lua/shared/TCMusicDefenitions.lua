-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
-- Compatibility-only True Music shim in shared namespace.
-- Some legacy packs still resolve require() against shared paths at bootstrap.
if type(GlobalMusic) ~= "table" then
    GlobalMusic = {}
end
