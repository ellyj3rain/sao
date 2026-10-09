-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
-- Shared mutable server registry runtime state.
NMServerRegistryState = NMServerRegistryState or {}
NMServerRegistryState.worldRegistry = NMServerRegistryState.worldRegistry or {}
NMServerRegistryState.registryTick = NMServerRegistryState.registryTick or 0
NMServerRegistryState.dormancySinceMinutes = NMServerRegistryState.dormancySinceMinutes or {}
NMServerRegistryState.unresolvedNearSinceMinutes = NMServerRegistryState.unresolvedNearSinceMinutes or {}
NMServerRegistryState.dormancyTombstones = NMServerRegistryState.dormancyTombstones or {}
NMServerRegistryState.zombieAttractionPulseState = NMServerRegistryState.zombieAttractionPulseState or {}
NMServerRegistryState.sourceRefreshSignature = NMServerRegistryState.sourceRefreshSignature or {}
NMServerRegistryState.vehicleRuntimeIdBySqlId = NMServerRegistryState.vehicleRuntimeIdBySqlId or {}
NMServerRegistryState.vehicleSqlIndexLastRefreshMs = NMServerRegistryState.vehicleSqlIndexLastRefreshMs or 0
NMServerRegistryState.vehiclePartUuidByIdentity = NMServerRegistryState.vehiclePartUuidByIdentity or {}
NMServerRegistryState.vehicleTruthSqlProofSigByUuid = NMServerRegistryState.vehicleTruthSqlProofSigByUuid or {}
NMServerRegistryState.vehicleTruthSqlProofMsByUuid = NMServerRegistryState.vehicleTruthSqlProofMsByUuid or {}

