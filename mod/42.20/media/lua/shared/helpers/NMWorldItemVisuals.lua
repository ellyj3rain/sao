-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
-- Compatibility-only shim for legacy shared helper slot world-visual paths.
return require "slot/NMWorldItemVisuals"
