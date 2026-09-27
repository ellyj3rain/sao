local W, P = SAO.WorldSources, SAO.Perception
local function count(values) local n = 0 for _ in pairs(values) do n = n + 1 end return n end
local function facts(id)
    local result = {}
    for _, place in pairs(P.knownPlaces(id, true)) do
        for key, fact in pairs(place.sourceFacts or {}) do result[key] = fact end
    end
    return result
end
local firstOk, first = pcall(W.inspectionCandidate, "a", bodies.a, "standing", 12)
assert(firstOk, "initial inspection offer threw: " .. tostring(first))
check("default_untargeted_offer_retains_order", first and first.sourceId == "C:first:0")
local target = W.inspectionCandidate("a", bodies.a, "standing", 12, "C:target:0")
check("exact_target_selected_without_fallback", target and target.sourceId == "C:target:0")
check("target_offer_teaches_nothing", count(facts("a")) == 0 and inspectCalls == 0)
check("target_native_receipt_teaches_only_exact_holder", W.inspectContainer("a", bodies.a, target)
    and inspectCalls == 1 and facts("a")["C:target:0"] and not facts("a")["C:first:0"])
target = W.inspectionCandidate("a", bodies.a, "standing", 12, "C:target:0")
check("explicit_known_target_can_be_reinspected", target and target.sourceId == "C:target:0")
check("explicit_target_still_inspects_natively", W.inspectContainer("a", bodies.a, target) and inspectCalls == 2)
check("ordinary_inspection_still_skips_known_target", W.inspectionCandidate("a", bodies.a, "standing", 12).sourceId == "C:first:0")
target = W.inspectionCandidate("b", bodies.b, "standing", 12, "C:target:0")
check("other_actor_has_no_borrowed_private_knowledge", target and count(facts("b")) == 0)
check("target_permission_rechecked_before_native_fill", (function()
    permitted = false local ok, why = W.inspectContainer("b", bodies.b, target)
    return not ok and why == "current-claim-refused" and inspectCalls == 2 end)())
check("unpermitted_target_not_offered", W.inspectionCandidate("a", bodies.a, "standing", 12, "C:target:0") == nil)
permitted = true
check("absent_target_does_not_select_other_holder", W.inspectionCandidate("a", bodies.a, "standing", 12, "C:missing:0") == nil)
check("bad_target_type_refused", W.inspectionCandidate("a", bodies.a, "standing", 12, {}) == nil)
check("empty_target_refused", W.inspectionCandidate("a", bodies.a, "standing", 12, "") == nil)
check("overlong_target_refused", W.inspectionCandidate("a", bodies.a, "standing", 12, string.rep("x", 513)) == nil)
local value = ModData.get("SurvivorAwareness_WorldSources")
value.conflictBySource["C:target:0"] = "conflict"
check("conflicted_target_does_not_fallback", W.inspectionCandidate("a", bodies.a, "standing", 12, "C:target:0") == nil)
value.conflictBySource["C:target:0"] = nil
value.reservations["R:other"] = { status = "reserved", sourceId = "C:target:0", actorId = "other" }
check("reserved_target_does_not_fallback", W.inspectionCandidate("a", bodies.a, "standing", 12, "C:target:0") == nil)
value.reservations["R:other"] = nil
target = W.inspectionCandidate("a", bodies.a, "standing", 12, "C:target:0")
W.resetRuntime()
check("reset_invalidates_targeted_context", not W.inspectContainer("a", bodies.a, target) and inspectCalls == 2)
RESULT = "PASS cooking exact inspection " .. checks
