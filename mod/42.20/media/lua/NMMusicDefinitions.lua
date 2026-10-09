-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
-- Compatibility-only root shim for older loaders expecting NMMusicDefinitions.
return require "contracts/NMMediaContract"
