-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
-- Compatibility-only shim for child packs expecting NMAlbumPackBuilder at the shared root.
return require "music/NMAlbumPackBuilder"
