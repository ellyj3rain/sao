-- Full original controller callbacks run in installed Kahlua. Dependency services,
-- event bus and distribution tables are explicit controlled hosts; no game/world.
local function check(ok, name)
    assert(ok, "D2_LOOT_DIAGNOSTIC:" .. name)
    CHECKS = CHECKS + 1
end
local c = NMServerSandboxLootController
c.registerEventHooks()
check(#LOGS == 5, "five_original_event_registration_diagnostics")
for _, row in ipairs(LOGS) do
    check(row.tag == "sandbox.loot bootstrap", "original_bootstrap_logger")
    check(string.find(row.detail, "distroReady=" .. tostring(EXPECT_DIAGNOSTIC), 1, true) ~= nil,
        "lexical_readiness_matches_current_distribution_tables")
end
local beforeCount = #LOGS
c.registerEventHooks()
check(#LOGS == beforeCount, "source_registration_idempotent")
check(HOOKS.OnTick == c.onTick and HOOKS.OnFillContainer == c.onFillContainer,
    "original_gameplay_callbacks_registered")
HOOKS.OnTick()
HOOKS.OnTick()
check(#LOGS == beforeCount, "source_tick_no_pending_build")
if not EXPECT_READY then
    check(c.ensureInitialized() == false, "actual_gameplay_refuses_missing_distribution_tables")
    check(#LOGS == beforeCount + 2, "original_not_ready_gameplay_branch")
end
local state = c.getRuntimeRecoveryState()
check(c.getLootEpoch() == 0 and state.epoch == 0, "loot_epoch_unchanged")
check(c.isSandboxLootApplied() == false, "loot_applied_unchanged")
check(state.runtimeRecoveryAllowed == false and state.lootPolicy == nil and state.managedLootMap == nil,
    "original_loot_policy_and_recovery_unchanged")
check(ProceduralDistributions == ORIGINAL_PROCEDURAL and SuburbsDistributions == ORIGINAL_SUBURBS,
    "distribution_identity_unchanged")
check(not ORIGINAL_PROCEDURAL or ORIGINAL_PROCEDURAL.marker == "procedural-custody",
    "procedural_content_unchanged")
check(type(ORIGINAL_SUBURBS) ~= "table" or ORIGINAL_SUBURBS.marker == "suburbs-custody",
    "suburbs_content_unchanged")
check(REQUESTS == 14, "exact_original_requires_with_owned_prefix")
GAMEPLAY_STATE = "GAMEPLAY_STATE epoch=" .. tostring(state.epoch) .. " applied=" .. tostring(c.isSandboxLootApplied())
    .. " recovery=" .. tostring(state.runtimeRecoveryAllowed) .. " hooks=5 ready=" .. tostring(EXPECT_READY)
RESULT = "PASS D2 loot diagnostic " .. tostring(CHECKS) .. " | " .. GAMEPLAY_STATE
