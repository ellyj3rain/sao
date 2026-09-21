#!/usr/bin/env python3
"""Private completed-transfer memory cases called by Border 180.

Production Perception and Knowledge run in the installed Kahlua VM. The
adapters provide county time, existing trust gates and a conversation verdict;
physical conversation admission is exercised separately by its own producer.
"""
from __future__ import annotations

import pathlib
import re
import shutil
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
PERCEPTION = ROOT / "mod/42.20/media/lua/shared/SAO_Perception.lua"
KNOWLEDGE = ROOT / "mod/42.20/media/lua/shared/SAO_Knowledge.lua"
DISPOSITION = ROOT / "mod/42.20/media/lua/shared/SAO_Disposition.lua"
CASES = ROOT / "tools/sweep/delivery_knowledge_cases.lua"

EXPECTED = {
    "performed_and_observed", "private_witness_scope", "neutral_visible_fields",
    "no_source_inventory_or_social_effect", "receipt_and_reader_detached",
    "duplicate_preserves_acquisition", "conflicting_identity_refused",
    "unperformed_result_refused", "consume_not_transfer_memory",
    "pending_without_observation_refused", "unproved_observation_refused",
    "proved_terminal_observation_retained", "request_historical_geometry_withheld",
    "legacy_no_witness_invention", "actor_binding_refused",
    "invalid_witness_atomic_refusal", "future_event_refused",
    "invalid_coordinate_refused", "acquire_water_supported",
    "testimony_preserves_event_and_origin", "retelling_keeps_immediate_teller",
    "testimony_cycle_no_refresh", "told_never_overwrites_firsthand",
    "captured_firsthand_supersedes_testimony", "physical_conversation_required",
    "missing_communication_fails_closed", "listener_skepticism_preserved",
    "speaker_trust_preserved", "conversation_channel_forwarded",
    "return_report_grounded", "return_report_firsthand_only",
    "return_report_channel_required", "episode_outlives_position_sighting",
    "person_specific_retention", "forgotten_not_told_or_claimed",
    "event_age_never_rejuvenated", "unavailable_reader_is_read_only",
    "past_view_excludes_future_acquisition", "bounded_by_event_time",
    "deterministic_equal_time_order", "persistent_bind_preserves_episode",
    "knowledge_food_provenance", "knowledge_read_only_detached",
    "knowledge_topic_and_time_separation", "knowledge_water_supported",
    "no_relationship_policy_created",
    "observation_position_frozen", "private_own_appraisal", "appraisal_detached",
    "appraisal_does_not_travel", "reciprocity_strongest_without_accumulation",
    "forgotten_appraisal_unavailable", "invalid_appraisal_atomic_refusal",
    "evicted_event_cannot_return", "eviction_floor_survives_bind",
    "request_original_private", "request_geometry_stays_unknown",
    "request_testimony_provenance", "request_geometry_private_and_detached",
    "request_cycle_no_refresh", "request_channel_required",
    "request_trust_gates_preserved", "knowledge_food_request",
    "request_expires_from_origin", "unsupported_request_channel_refused",
    "request_return_report", "request_report_preserves_firsthand_scope",
    "request_bound_and_eviction_floor",
    "disposition_zero_need_neutral", "disposition_hostility_can_decline",
    "disposition_compassion_differs", "disposition_reciprocity_changes_own_choice",
}

PRELUDE = r'''
__now, __canConverse, __socialWrites = 100, true, 0
__factors, __trust, __persisted = {}, {}, {}
__traitUnits = {}
__communicationPresent = true
SAO = {
    Log = { line = function() end },
    History = { countyHours = function() return __now end,
        ticks = function() return __now * 9000 end, TICKS_PER_HOUR = 9000 },
    Conditions = { memoryFactor = function(id) return __factors[id] or 1 end },
    Identity = { get = function(id) return { id=id, x=10, y=12 } end },
    Body = { get = function() return nil end },
    Hash = { unit = function(id, salt) return __traitUnits[id] or 0.5 end },
    Standing = {
        trust = function(a,b) return __trust[a .. '|' .. b] or 0.6 end,
        sameGroup = function() return false end,
        groupOf = function() return nil end,
        adjustTrust = function() __socialWrites = __socialWrites + 1 end,
        addDebt = function() __socialWrites = __socialWrites + 1 end,
        settleDebt = function() __socialWrites = __socialWrites + 1 end,
    },
    Communication = { canConverse = function(a,b,channel)
        __lastChannel = channel
        if not __communicationPresent then error('communication unavailable') end
        return __canConverse
    end },
}
ModData = { getOrCreate = function() return __persisted end }
'''

MUTATIONS = (
    ("terminal-result", PERCEPTION,
     'if receipt.status ~= "completed" and receipt.status ~= "conflict"',
     'if false',
     "unperformed_result_refused"),
    ("native-transfer-proof", PERCEPTION,
     'or observation.nativeTransferProven ~= true', 'or false',
     "unproved_observation_refused"),
    ("actor-binding", PERCEPTION,
     "or observation.actorId ~= receipt.actorId", "or false",
     "actor_binding_refused"),
    ("conversation-proof", PERCEPTION,
     "if not admitted or canConverse ~= true then return 0 end\n    local now = transferNow()",
     "if false then return 0 end\n    local now = transferNow()", "physical_conversation_required"),
    ("testimony-cycle", PERCEPTION,
     'if existing and (existing.source ~= "told" or fact.source == "told") then',
     'if existing and existing.source ~= "told" then', "testimony_cycle_no_refresh"),
    ("personal-retention", PERCEPTION,
     "return TRANSFER_HOURS * factor", "return TRANSFER_HOURS",
     "person_specific_retention"),
    ("episode-bound", PERCEPTION,
     "for i = 1, #ordered - TRANSFER_LIMIT do\n        b.transfers",
     "for i = 1, 0 do\n        b.transfers",
     "bounded_by_event_time"),
    ("knowledge-provenance", KNOWLEDGE,
     "source = episode.source, teller = episode.teller,",
     'source = "observed", teller = episode.teller,', "knowledge_food_provenance"),
    ("event-position", PERCEPTION,
     "x = observation.x, y = observation.y, z = observation.z,",
     "x = receipt.sourceX, y = receipt.sourceY, z = receipt.sourceZ,",
     "observation_position_frozen"),
    ("private-appraisal", PERCEPTION,
     'if includeAppraisal and fact.source == "observed"', 'if fact.appraisal ~= nil',
     "appraisal_does_not_travel"),
    ("eviction-watermark", PERCEPTION,
     'if type(b.transferFloor) == "table" and not transferOrder(b.transferFloor, fact) then',
     "if false then", "evicted_event_cannot_return"),
    ("request-channel", PERCEPTION,
     "if not admitted or canConverse ~= true then return 0 end\n    local requests, moved",
     "if false then return 0 end\n    local requests, moved", "request_channel_required"),
    ("request-origin-age", PERCEPTION,
     "and now - request.requestedAt <= AID_REQUEST_HOURS",
     "and now - request.acquiredAt <= AID_REQUEST_HOURS", "request_expires_from_origin"),
    ("request-historical-location", PERCEPTION,
     'if now == current and type(ground) == "table"',
     'if type(ground) == "table"', "request_historical_geometry_withheld"),
    ("appraisal-needs-pressure", DISPOSITION,
     "pressure * receptiveness", "receptiveness", "disposition_zero_need_neutral"),
    ("appraisal-private-standing", DISPOSITION,
     'trait(id, "compassion") - math.max(0, -trust)', 'trait(id, "compassion")',
     "disposition_hostility_can_decline"),
    ("reciprocity-existing-charity-consumer", DISPOSITION,
     "bar = bar - SAO.Perception.reciprocityToward(id, otherId) * 0.2", "bar = bar",
     "disposition_reciprocity_changes_own_choice"),
)


def _dependencies():
    import provisioning_result_test as border
    return border


def _compile(work: pathlib.Path, border) -> None:
    shutil.copy2(border.STDLIB, work / "stdlib.lua")
    compiled = subprocess.run(
        [str(border.JDK / "javac.exe"), "-cp", str(border.PZ), "-d", str(work),
         str(border.RUNNER)], capture_output=True, text=True, timeout=120)
    if compiled.returncode:
        raise RuntimeError((compiled.stderr or compiled.stdout)[-2000:])


def _run(work: pathlib.Path, border, overrides=None):
    overrides = overrides or {}
    prelude = work / "prelude.lua"
    prelude.write_text(PRELUDE, encoding="utf-8")
    chunks = [prelude]
    for path in (PERCEPTION, KNOWLEDGE, DISPOSITION):
        text = overrides.get(path.name)
        if text is not None:
            altered = work / path.name
            altered.write_text(text, encoding="utf-8")
            chunks.append(altered)
        else:
            chunks.append(path)
    probe = work / "cases.lua"
    probe.write_text("local ok, result = pcall(function() return "
        + CASES.read_text(encoding="utf-8") + "\nend)\n"
        + "__deliveryKnowledgeResult = ok and result or ('ERROR after ' .. "
        + "tostring(__deliveryKnowledgeLast) .. ': ' .. tostring(result))\n",
        encoding="utf-8")
    chunks.append(probe)
    done = subprocess.run(
        [str(border.JDK / "java.exe"), "-cp", f"{border.PZ};.", "LuaRun",
         *map(str, chunks), "--", "__deliveryKnowledgeResult"], cwd=work,
        capture_output=True, text=True, timeout=120)
    detail = (done.stdout or "") + (done.stderr or "")
    lines = (done.stdout or "").strip().splitlines()
    value = lines[-1][6:] if lines and lines[-1].startswith("VALUE ") else ""
    checks = dict(re.findall(r"([a-z0-9_]+)=(true|false)", value))
    return checks, detail


def run_cases(overrides=None):
    border = _dependencies()
    with tempfile.TemporaryDirectory(prefix="sao-delivery-knowledge-") as temporary:
        work = pathlib.Path(temporary)
        _compile(work, border)
        return _run(work, border, overrides)


def main() -> int:
    missing = [str(path.relative_to(ROOT)) for path in
               (PERCEPTION, KNOWLEDGE, DISPOSITION, CASES,
                ROOT / "tools/provisioning_result_test.py") if not path.is_file()]
    if missing:
        print(f"FAIL delivery knowledge repository inputs missing: {missing}")
        return 1
    border = _dependencies()
    if not all(path.is_file() for path in (border.PZ, border.STDLIB,
            border.JDK / "java.exe", border.JDK / "javac.exe")):
        print("Delivery knowledge SKIPPED: installed game VM or JDK absent")
        return 0
    with tempfile.TemporaryDirectory(prefix="sao-delivery-knowledge-") as temporary:
        work = pathlib.Path(temporary)
        _compile(work, border)
        checks, detail = _run(work, border)
        failed = sorted(name for name, value in checks.items() if value != "true")
        if set(checks) != EXPECTED or failed:
            print(f"FAIL delivery knowledge missing={sorted(EXPECTED-set(checks))} "
                  f"extra={sorted(set(checks)-EXPECTED)} failed={failed}")
            print(detail[-3000:])
            return 1
        print(f"PASS {len(checks)} production delivery knowledge cases")
        for name, path, before, after, expected in MUTATIONS:
            original = path.read_text(encoding="utf-8")
            if original.count(before) != 1:
                print(f"FAIL delivery knowledge mutation anchor: {name}")
                return 1
            altered, detail = _run(work, border,
                {path.name: original.replace(before, after, 1)})
            if set(altered) != EXPECTED or altered.get(expected) != "false":
                print(f"FAIL delivery knowledge mutation {name} did not flip {expected}")
                print(detail[-3000:])
                return 1
            print(f"PASS delivery knowledge mutation {name}: {expected}=false")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
