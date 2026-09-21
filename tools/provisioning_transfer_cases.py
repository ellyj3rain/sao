#!/usr/bin/env python3
"""Execute exact provisioning transfer ledger cases in the installed Kahlua VM.

Native inspection and carried metadata are controlled adapters here. SourceUse
and the Java holder checks have separate integration evidence. Defect controls
mutate the production Lua loaded by the same existing LuaRun runner.
"""
import json
import pathlib
import re
import tempfile

import source_use_test as native_use

ROOT = native_use.ROOT
WORLD = native_use.WORLD
CASES = ROOT / "tools/sweep/provisioning_transfer_cases.lua"


def metadata_snapshot(revision, sources):
    text = native_use.snapshot(1, 1, revision, sources)
    items = {str(item["id"]): item for source in sources
             for item in source.get("items", [])}
    lines = []
    for line in text.splitlines():
        if line.startswith("I|"):
            item_id = re.search(r"\|id=(-?\d+)\|", line).group(1)
            for key in ("condition", "currentUses"):
                if key in items[item_id]:
                    line += f"|{key}={items[item_id][key]}"
        lines.append(line)
    return "\n".join(lines) + "\n"


APPLE = {"id": 101, "type": "Base.Apple", "amount": 0,
         "cats": "food", "condition": 10, "currentUses": 1}
HAMMER = {"id": 202, "type": "Base.Hammer", "amount": 0,
          "cats": "tools", "condition": 10, "currentUses": 1}
WATER = {"id": 102, "type": "Base.WaterBottle", "amount": 0.75,
         "fluid": "Water", "cats": "water", "condition": 10,
         "currentUses": 0.75}


def holder(revision, items):
    quantities = {}
    for item in items:
        for category in item["cats"].split(","):
            quantities[category] = quantities.get(category, 0) + (
                item["amount"] if category == "water" else 1)
    return {"id": "C:food-token:0", "fp": "food-fp", "rev": revision,
            "kind": "container", "x": 8, "y": 8, "building": 42,
            "state": "available" if items else "spent",
            "items": items, "quantities": quantities}


NEIGHBOR = native_use.source("C:neighbor:0", "neighbor-fp", "neighbor-r1",
                             9, 8, 42, 901, "Base.Banana")
NEIGHBOR_POST = dict(NEIGHBOR, rev="neighbor-r2", state="spent", items=[], quantities={})
PEAR = dict(APPLE, id=103, type="Base.Pear")
NEIGHBOR_STORED = dict(NEIGHBOR, rev="neighbor-r2",
                       items=NEIGHBOR["items"] + [PEAR], quantities={"food": 2})


def transfer_row(operation="store", item=APPLE, source_id="C:food-token:0"):
    text = (f"T|operation={operation}|source={source_id}|id={item['id']}"
            f"|type={item['type']}|uses=1|amount={item['amount']:.6f}"
            f"|fluid={item.get('fluid', '')}|poison=0|rotten=0"
            f"|cats={item['cats']}")
    for key in ("condition", "currentUses"):
        if key in item:
            text += f"|{key}={item[key]}"
    return text


SNAPSHOTS = {
    "store_pre": metadata_snapshot("store-c1", [holder("store-r1", [HAMMER]), NEIGHBOR]),
    "store_post": metadata_snapshot("store-c2", [holder("store-r2", [HAMMER, APPLE]), NEIGHBOR]),
    "store_changed": metadata_snapshot("store-c2", [holder("store-r2", [dict(HAMMER, condition=9), APPLE]), NEIGHBOR]),
    "store_added": metadata_snapshot("store-c2", [holder("store-r2", [HAMMER, APPLE, dict(APPLE, id=103)]), NEIGHBOR]),
    "store_mismatch": metadata_snapshot("store-c2", [holder("store-r2", [HAMMER, dict(APPLE, currentUses=0.5)]), NEIGHBOR]),
    "acquire_pre": metadata_snapshot("acquire-c1", [holder("acquire-r1", [HAMMER, APPLE]), NEIGHBOR]),
    "acquire_post": metadata_snapshot("acquire-c2", [holder("acquire-r2", [HAMMER]), NEIGHBOR]),
    "water_pre": metadata_snapshot("water-c1", [holder("water-r1", [WATER]), NEIGHBOR]),
    "water_post": metadata_snapshot("water-c2", [holder("water-r2", []), NEIGHBOR]),
    "legacy_pre": metadata_snapshot("legacy-c1", [holder("legacy-r1", [{k: v for k, v in HAMMER.items() if k not in ("condition", "currentUses")}]), NEIGHBOR]),
    "legacy_post": metadata_snapshot("legacy-c2", [holder("legacy-r2", [HAMMER, APPLE]), NEIGHBOR]),
    "medicine": metadata_snapshot("medicine-c1", [holder("store-r1", [HAMMER]),
        native_use.source("C:medicine:0", "medicine-fp", "medicine-r1", 9, 8,
                          42, 902, "Base.Pills", "medicine")]),
    "dual_acquired": metadata_snapshot("dual-c2", [holder("acquire-r2", [HAMMER]), NEIGHBOR_POST]),
    "dual_stored": metadata_snapshot("dual-c2", [holder("acquire-r2", [HAMMER]), NEIGHBOR_STORED]),
    "dual_missing": metadata_snapshot("dual-c2", [NEIGHBOR]),
    "dual_missing_post": metadata_snapshot("dual-c3", [NEIGHBOR_POST]),
    "dual_replaced": metadata_snapshot("dual-c2", [dict(holder("replacement-r2", []), fp="replacement-fp"), NEIGHBOR]),
    "dual_replaced_post": metadata_snapshot("dual-c3", [dict(holder("replacement-r2", []), fp="replacement-fp"), NEIGHBOR_POST]),
}

PRELUDE = native_use.PRELUDE + r'''
SAO.Standing.mayTakeCurrent = function() return __permit ~= false end
SAO.Perception.learnInspectedSource = function(id, place, sourceId, tick, source)
    if __learnRefused then return false end
    local known = SAO.Perception._known[tostring(id)] or {}
    SAO.Perception._known[tostring(id)] = known
    known[place.id] = known[place.id] or {cx=place.cx, cy=place.cy, sourceFacts={}}
    local belief = known[place.id]
    belief.sourceFacts[sourceId] = SAO.WorldSources.beliefFact(sourceId)
    belief.at, belief.source = tick, source
    return true
end
SAOJavaBridge = {
    worldTransferOffer=function(self, body, item, container, operation)
        __offerCalls = (__offerCalls or 0) + 1
        return __offerText or ""
    end,
    carriedWorldTransferItem=function(self, body, id, fullType)
        return __carriedText or ""
    end,
}
'''


def prelude():
    values = dict(SNAPSHOTS)
    values.update(store_row=transfer_row(), acquire_row=transfer_row("acquire"),
                  water_row=transfer_row("acquire", WATER),
                  neighbor_acquire_row=transfer_row("acquire", NEIGHBOR["items"][0], NEIGHBOR["id"]),
                  neighbor_store_row=transfer_row("store", PEAR, NEIGHBOR["id"]))
    return PRELUDE + "\n" + "\n".join(
        f"__{name} = {json.dumps(text)}" for name, text in values.items())


EXPECTED = {
    "exact_private_offer", "detached_offer", "live_actor_required",
    "current_permission_required", "private_admission_required",
    "malformed_offer_refused", "complete_snapshot_required",
    "forged_choice_refused", "changed_choice_refused",
    "single_actor_and_source_owner", "carried_signature_required",
    "no_unperformed_completion", "failed_queue_no_stock_or_need_credit",
    "store_exact_addition", "transfer_no_need_stamp", "transfer_result_units",
    "repeated_delivery_isolated", "reload_retains_transfer",
    "concurrent_change_conflicts", "unrelated_addition_conflicts",
    "stored_contents_mismatch_conflicts", "acquire_exact_removal",
    "carried_acquisition_signature", "water_transfer_counts_item",
    "legacy_optional_metadata", "consume_retains_need_stamp",
    "schema6_migration", "future_schema_refused", "reservation_bound",
    "protected_result_bound", "store_duplicate_refused", "actor_result_isolation",
    "native_medicine_category", "same_chunk_acquire_acquire", "same_chunk_acquire_store",
    "same_chunk_acquire_consume", "foreign_missing_source_retained",
    "foreign_missing_membership_retained", "foreign_fingerprint_retained",
    "unscoped_changes_conflict", "invalid_owner_cannot_defer",
}

MUTATIONS = [
    ("foreign-pending-source-isolation",
     'if scopedSourceId and nativeSource.id ~= scopedSourceId\n            and pendingFor(value, nativeSource.id, nil) then',
     'if false then', "same_chunk_acquire_acquire"),
    ("foreign-missing-source-isolation",
     'if not seen[id] and scopedSourceId and id ~= scopedSourceId\n            and pendingFor(value, id, nil) then',
     'if false then', "foreign_missing_source_retained"),
    ("foreign-missing-source-membership", 'seen[id] = true\n        elseif old and not seen[id] then',
     'seen[id] = nil\n        elseif old and not seen[id] then', "foreign_missing_membership_retained"),
    ("storage-postcondition", 'if reservation.operation == "store" then',
     'if false then', "store_exact_addition"),
    ("consume-only-credit", 'and (reservation.operation or "consume") == "consume" then',
     'then', "transfer_no_need_stamp"),
    ("unrelated-item-conservation", 'if not signatureMatches(signature, observed.items and observed.items[key]) then',
     'if false then', "concurrent_change_conflicts"),
    ("carried-item-conservation", 'and signatureMatches(reservation.itemSignature, item)',
     'and true', "carried_signature_required"),
    ("transfer-proof-required", 'or not reservation.transferProven\n            or tonumber(quantity) ~= 1',
     'or false\n            or tonumber(quantity) ~= 1', "no_unperformed_completion"),
    ("exact-choice-revalidation", 'selected ~= nil and not sameActionOption(selected, option)',
     'false', "forged_choice_refused"),
    ("reservation-capacity", 'if reservationCount >= MAX_RESERVATIONS then',
     'if false then', "reservation_bound"),
    ("result-capacity", 'if durableInputs >= MAX_RESULTS then',
     'if false then', "protected_result_bound"),
    ("complete-native-category-vocabulary", '"medicine", "memento"',
     '"memento"', "native_medicine_category"),
]


def run_probe(expression, world_override=None, prelude_text=None):
    """Run one expression with the existing source-use Kahlua runner.

    world_override is optional production Lua text (for defect controls).
    prelude_text replaces the controlled adapter prelude when supplied.
    """
    original = native_use.PRELUDE, native_use.PROBE, native_use.WORLD
    with tempfile.TemporaryDirectory() as directory:
        try:
            native_use.PRELUDE = prelude() if prelude_text is None else prelude_text
            native_use.PROBE = expression
            if world_override is not None:
                path = pathlib.Path(directory) / WORLD.name
                path.write_text(world_override, encoding="utf-8")
                native_use.WORLD = path
            value, detail = native_use.kahlua_probe()
        finally:
            native_use.PRELUDE, native_use.PROBE, native_use.WORLD = original
    return value, detail


def run_cases(world_text=None):
    value, detail = run_probe(CASES.read_text(encoding="utf-8"), world_text)
    checks = dict(re.findall(r"([a-z0-9_]+)=(true|false)", value or ""))
    return checks, detail


def main():
    for path in (WORLD, CASES, native_use.RUNNER):
        if not path.is_file():
            print(f"FAIL repository input missing: {path}")
            return 1
    installed = (native_use.PZ, native_use.STDLIB,
                 native_use.JDK / "java.exe", native_use.JDK / "javac.exe")
    if not all(path.is_file() for path in installed):
        print("Provisioning transfer SKIPPED: installed game VM or JDK absent")
        return 0
    checks, detail = run_cases()
    failed = sorted(name for name, value in checks.items() if value != "true")
    if set(checks) != EXPECTED or failed:
        print(f"FAIL provisioning ledger: missing={sorted(EXPECTED-set(checks))} "
              f"extra={sorted(set(checks)-EXPECTED)} failed={failed}")
        print(detail[-1800:])
        return 1
    print(f"PASS {len(checks)} production WorldSources transfer cases")
    baseline = WORLD.read_text(encoding="utf-8")
    for name, before, after, expected_failure in MUTATIONS:
        if before not in baseline:
            print(f"FAIL mutation anchor missing: {name}")
            return 1
        mutated = baseline.replace(before, after, 1)
        if mutated == baseline:
            print(f"FAIL mutation did not land: {name}")
            return 1
        mutation_checks, detail = run_cases(mutated)
        if mutation_checks.get(expected_failure) != "false":
            print(f"FAIL mutation {name} did not reject {expected_failure}")
            print(detail[-1000:])
            return 1
        print(f"PASS defect control {name}: {expected_failure}")
    print("Controlled native metadata verifies Lua ownership and exact deltas; "
          "it does not establish live native transfers.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
