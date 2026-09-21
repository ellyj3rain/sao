#!/usr/bin/env python3
"""Production delivery integrations called by Border 180.

Standing, Perception, Communication and Provisioning execute in installed
Kahlua. Native hearing, body availability, durable stores and acknowledgement
are explicit ports; native hearing internals have their own installed-engine
probe. Controller checks below are static integration anchors, not execution.
"""
from __future__ import annotations

import pathlib
import re
import shutil
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
LUA = ROOT / "mod/42.20/media/lua"
STANDING = LUA / "shared/SAO_Standing.lua"
PERCEPTION = LUA / "shared/SAO_Perception.lua"
COMMUNICATION = LUA / "shared/SAO_Communication.lua"
PROVISIONING = LUA / "shared/SAO_Provisioning.lua"
CONTROLLER = LUA / "client/SAO_Controller.lua"
CASES = ROOT / "tools/sweep/delivery_integration_cases.lua"

EXPECTED = {
    "request_origin_production_api", "request_cooldown_preserves_time",
    "failed_origin_has_no_cooldown", "failed_origin_retry",
    "global_request_has_no_private_backfill", "global_only_request_not_selected",
    "private_request_missing_location", "private_place_destination_retained",
    "private_destination_detached", "private_request_beats_global_location",
    "request_expiry_uses_original_time", "request_future_refused",
    "request_testimony_requires_conversation", "request_testimony_from_real_origin",
    "loaded_native_actor_listener", "loaded_listener_deaf_port_refusal",
    "loaded_native_failure_refused", "loaded_sleeping_agent_refused",
    "loaded_missing_body_refused", "loaded_player_identity", "unknown_channel_refused",
    "dormant_native_listener_access", "dormant_access_is_directed",
    "dormant_unknown_hearing_refused", "dormant_hearing_failure_refused",
    "dormant_dead_refused", "dormant_sleeping_refused",
    "dormant_missing_sleep_refused", "dormant_loaded_participant_refused",
    "dormant_floor_and_distance_refused", "same_actor_refused",
    "dormant_generated_hearing_provenance", "dormant_generated_cannot_override_deaf",
    "dormant_hearing_reduces_reach", "dormant_weather_reduces_reach",
    "dormant_zero_hearing_refused", "dormant_zero_weather_refused",
    "dormant_unknown_weather_refused",
    "receipt_memory_before_ack", "material_disabled_keeps_private_memory",
    "receipt_captured_witnesses_only", "receipt_original_location_retained",
    "unavailable_mind_blocks_ack", "mind_retry_records_original_time",
    "rejected_memory_blocks_ack", "ack_retry_preserves_private_acquisition",
    "legacy_receipt_does_not_invent_memory", "graph_retry_preserves_memory",
    "terminal_observation_bypasses_projection", "terminal_without_proof_cannot_ack",
    "terminal_memory_retry_idempotent",
}

PRELUDE = r'''
__now, __stores, __records, __bodies, __represented = 100, {}, {}, {}, {}
__unavailable, __hearing = {}, {}
__loadedResult, __loadedThrows, __hearingThrows = true, false, false
__ackAllowed, __ackCalls, __graphAvailable = true, {}, true
__nativeCalls, __hearingCalls = {}, {}
__weather, __weatherThrows = 1, false
SAO = {
    Log = { line = function() end },
    History = { countyHours = function() return __now end,
        ticks = function() return __now * 9000 end, TICKS_PER_HOUR = 9000 },
    Conditions = { memoryFactor = function() return 1 end },
    Identity = { get = function(id) return __records[tostring(id)] end,
        all = function() return __records end },
    Body = { get = function(id) return __bodies[tostring(id)] end,
        hasRepresentation = function(id)
            return __bodies[tostring(id)] ~= nil or __represented[tostring(id)] == true
        end },
    Controller = { agents = {} },
    GraphPersistence = { bind = function()
        return __graphAvailable, __graphAvailable and nil or 'unavailable'
    end },
    WorldSources = { acknowledgeResult = function(id, consumer, reason)
        local actor = SAO.Perception.transferFact('actor', id)
        local witness = SAO.Perception.transferFact('witness', id)
        __ackCalls[#__ackCalls + 1] = { id=id, consumer=consumer, reason=reason,
            actor=actor, witness=witness }
        return __ackAllowed
    end },
}
ModData = { getOrCreate = function(key)
    if __unavailable[key] then error('store unavailable: ' .. key) end
    __stores[key] = __stores[key] or {}
    return __stores[key]
end }
SandboxVars = { SurvivorAwareness = { Material = true } }
getSpecificPlayer = function(index) return index == 0 and __player or nil end
SAOJavaBridge = {
    canConverseNow = function(self, actor, listener, range)
        __nativeCalls[#__nativeCalls + 1] = {actor=actor,listener=listener,range=range}
        if __loadedThrows then error('native hearing unavailable') end
        return __loadedResult
    end,
    hibernationHearingAccess = function(self, packed)
        __hearingCalls[#__hearingCalls + 1] = packed
        if __hearingThrows then error('snapshot hearing unavailable') end
        return __hearing[packed] or 'UNKNOWN:fixture-unavailable'
    end,
    speechWeatherHearing = function()
        if __weatherThrows then error('weather hearing unavailable') end
        return __weather
    end,
}
'''


def controller_anchors(text: str) -> dict[str, bool]:
    """Bounded source anchors; no claim to execute the whole controller."""
    start = text.find("local asked, askedClaim = nil, nil")
    end = text.find('elseif desig == "quartermaster"', max(0, start))
    block = text[start:end] if start >= 0 and end > start else ""
    block = re.sub(r"--[^\n]*", "", block)
    return {
        "controller_private_destination_anchor": bool(re.search(
            r"asked\s*,\s*askedClaim\s*=\s*SAO\.Standing\.nearestAsking\(pg,\s*id\)", block)
            and re.search(r"local\s+allyClaim\s*=\s*askedClaim\s+or\s*\(", block)),
        "controller_private_urgency_anchor": bool(re.search(
            r"SAO\.Perception\.knownAidRequests\(id\)", block)
            and re.search(r"request\.groupId\s*==\s*ally", block)
            and not re.search(r"SAO\.Standing\.larderOf\(ally\)", block)),
    }


MUTATIONS = (
    ("request-source-contract", STANDING,
     'recordAidRequest(speakerId, groupName, now, "requested")',
     'recordAidRequest(speakerId, groupName, now, "performed")',
     "request_origin_production_api"),
    ("failed-request-origin", STANDING,
     'recordAidRequest(speakerId, groupName, now, "requested") ~= true then',
     'recordAidRequest(speakerId, groupName, now, "requested") == nil then',
     "failed_origin_has_no_cooldown"),
    ("global-request-shortcut", STANDING,
     "local best, bestD, bestClaim = nil, 1e18, nil\n    for _, request",
     "local best, bestD, bestClaim = nil, 1e18, nil\n"
     "    for group in pairs(s.groupMeta or {}) do\n"
     "        if group ~= fromGroup and S.isAsking(group) then\n"
     "            return group, S.groupClaimOf(group)\n        end\n    end\n"
     "    for _, request", "global_only_request_not_selected"),
    ("private-destination-return", STANDING,
     "return best, bestClaim", "return best, nil", "private_place_destination_retained"),
    ("request-original-expiry", PERCEPTION,
     "and now - request.requestedAt <= AID_REQUEST_HOURS",
     "and now - request.acquiredAt <= AID_REQUEST_HOURS",
     "request_expiry_uses_original_time"),
    ("loaded-native-admission", COMMUNICATION,
     "return ok and heard == true", "return true", "loaded_listener_deaf_port_refusal"),
    ("dormant-floor", COMMUNICATION,
     "or az ~= bz then return false end", "then return false end",
     "dormant_floor_and_distance_refused"),
    ("dormant-deaf-listener", COMMUNICATION,
     'if listener then return nil, "deaf" end',
     'if false then return nil, "deaf" end', "dormant_access_is_directed"),
    ("dormant-sleep-evidence", COMMUNICATION,
     'if rec.dormantSleeping ~= false then return nil, "sleep-unobserved" end',
     'if false then return nil, "sleep-unobserved" end', "dormant_missing_sleep_refused"),
    ("receipt-memory-delivery", PROVISIONING,
     "if receipt.transferObservation ~= nil then", "if false then",
     "receipt_memory_before_ack"),
    ("receipt-durable-mind", PROVISIONING,
     "and SAO.Perception.bindPersistentStore() == true",
     "and true", "unavailable_mind_blocks_ack"),
    ("receipt-memory-refusal", PROVISIONING,
     'if accepted ~= true then return false, why or "perception-refused" end',
     'if false then return false, why or "perception-refused" end',
     "rejected_memory_blocks_ack"),
    ("observation-is-not-completion", PROVISIONING,
     'if receipt.status ~= "completed" then', 'if false then',
     "terminal_observation_bypasses_projection"),
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
    for path in (STANDING, PERCEPTION, COMMUNICATION, PROVISIONING):
        if path.name in overrides:
            altered = work / path.name
            altered.write_text(overrides[path.name], encoding="utf-8")
            chunks.append(altered)
        else:
            chunks.append(path)
    probe = work / "cases.lua"
    probe.write_text("local ok, result = pcall(function() return "
        + CASES.read_text(encoding="utf-8") + "\nend)\n"
        + "__deliveryIntegrationResult = ok and result or ('ERROR after ' .. "
        + "tostring(__deliveryIntegrationLast) .. ': ' .. tostring(result))\n",
        encoding="utf-8")
    chunks.append(probe)
    done = subprocess.run(
        [str(border.JDK / "java.exe"), "-cp", f"{border.PZ};.", "LuaRun",
         *map(str, chunks), "--", "__deliveryIntegrationResult"], cwd=work,
        capture_output=True, text=True, timeout=120)
    detail = (done.stdout or "") + (done.stderr or "")
    lines = (done.stdout or "").strip().splitlines()
    value = lines[-1][6:] if lines and lines[-1].startswith("VALUE ") else ""
    checks = dict(re.findall(r"([a-z0-9_]+)=(true|false)", value))
    return checks, detail


def run_cases(overrides=None):
    border = _dependencies()
    with tempfile.TemporaryDirectory(prefix="sao-delivery-integration-") as temporary:
        work = pathlib.Path(temporary)
        _compile(work, border)
        return _run(work, border, overrides)


def main() -> int:
    missing = [str(path.relative_to(ROOT)) for path in
               (STANDING, PERCEPTION, COMMUNICATION, PROVISIONING, CONTROLLER,
                CASES, ROOT / "tools/provisioning_result_test.py") if not path.is_file()]
    if missing:
        print(f"FAIL delivery integration repository inputs missing: {missing}")
        return 1
    original = CONTROLLER.read_text(encoding="utf-8")
    anchors = controller_anchors(original)
    if not all(anchors.values()):
        print(f"FAIL delivery Controller static anchors: {anchors}")
        return 1
    for name, before, after in (
        ("controller_private_destination_anchor", "local allyClaim = askedClaim or (",
         "local allyClaim = nil or ("),
        ("controller_private_urgency_anchor", "SAO.Perception.knownAidRequests(id)",
         "SAO.Standing.larderOf(ally)"),
    ):
        if before not in original or controller_anchors(original.replace(before, after))[name]:
            print(f"FAIL delivery Controller anchor control: {name}")
            return 1
    print("PASS 2 delivery Controller static anchors and 2 known-bad controls (not runtime coverage)")
    border = _dependencies()
    if not all(path.is_file() for path in (border.PZ, border.STDLIB,
            border.JDK / "java.exe", border.JDK / "javac.exe")):
        print("Delivery integration SKIPPED: installed game VM or JDK absent")
        return 0
    with tempfile.TemporaryDirectory(prefix="sao-delivery-integration-") as temporary:
        work = pathlib.Path(temporary)
        _compile(work, border)
        checks, detail = _run(work, border)
        failed = sorted(name for name, value in checks.items() if value != "true")
        if set(checks) != EXPECTED or failed:
            print(f"FAIL delivery integration missing={sorted(EXPECTED-set(checks))} "
                  f"extra={sorted(set(checks)-EXPECTED)} failed={failed}")
            print(detail[-4000:])
            return 1
        print(f"PASS {len(checks)} production delivery integration cases")
        for name, path, before, after, expected in MUTATIONS:
            original = path.read_text(encoding="utf-8")
            if original.count(before) != 1:
                print(f"FAIL delivery integration mutation anchor: {name}")
                return 1
            altered, detail = _run(work, border,
                {path.name: original.replace(before, after, 1)})
            if set(altered) != EXPECTED or altered.get(expected) != "false":
                print(f"FAIL delivery integration mutation {name} did not flip {expected}")
                print(detail[-4000:])
                return 1
            print(f"PASS delivery integration mutation {name}: {expected}=false")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
