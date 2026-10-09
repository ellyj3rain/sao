-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
-- Legacy compatibility shim for older loaders expecting music/NMMusic.
return require "contracts/NMMediaContract"
