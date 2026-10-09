-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
-- Compatibility-only shim for legacy top-level UI device lifecycle paths.
return require "ui/shared/host/NMDeviceUI"
