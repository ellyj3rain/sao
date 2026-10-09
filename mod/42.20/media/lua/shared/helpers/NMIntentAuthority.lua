-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
-- Compatibility-only shim for legacy shared helper intent-authority paths.
return require "intent/NMIntentAuthority"
