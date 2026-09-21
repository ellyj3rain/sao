#!/usr/bin/env python3
r"""Border 181 - decision evidence is frozen, namespaced and fail-closed.

The engine probe changes the same nested record, belief and claim while the
observed election runs and again after it returns. The exported decision must
retain the pre-election values while the separately exported result sees the
new designation. Required-reader and cyclic-table controls still execute the
real election but make the capture ineligible. Publication is directory-atomic
and a failed rename leaves no apparent dump.
"""
from __future__ import annotations

import hashlib
import json
import pathlib
import shutil
import subprocess
import tempfile

import county_dump as Dump
import county_sweep as Sweep


ROOT = pathlib.Path(__file__).resolve().parent.parent
CAPTURE = ROOT / "tools" / "sweep" / "decision_capture.lua"
COUNTY = ROOT / "tools" / "county_dump.py"

PRELUDE = r'''
SAO = {}
local state = {
    groups = { alpha = "home", beta = "home" },
    groupClaims = {
        home = { x = 10, y = 20, facts = { status = "before" } },
        rival = { x = 30, y = 40 },
    },
    groupMeta = { home = {} },
}
ModData = { getOrCreate = function() return state end }
plainNameOf = function(first, last) return first .. " " .. last end

__captureRecords = {
    alpha = { id = "alpha", forename = "Ada", surname = "North",
        occupation = "carpenter", profile = { note = "before",
            control = "line\nunit" .. string.char(1) } },
    beta = { id = "beta", forename = "Ben", surname = "South",
        occupation = "farmer", profile = { note = "steady" } },
}
__captureBeliefs = {
    alpha = { evidence = { value = "before" } },
    beta = {},
}
__captureState = state
__captureRealCalls = 0

SAO.Identity = {
    get = function(id) return __captureRecords[id] end,
}
SAO.History = {
    countyHours = function() return 42 end,
    ageOf = function(id) return id == "alpha" and 31 or 44 end,
}
SAO.Disposition = {
    circle = function(id) return id == "alpha" and "near" or "middle" end,
    traits = function(id) return { patience = id == "alpha" and 0.7 or 0.4 } end,
}
SAO.Conditions = { of = function(id) return { tired = false } end }
SAO.Habits = { of = function(id) return { keepsWatch = true } end }
SAO.Lessons = { renderClaims = function(id) return { ["lesson-one"] = true } end }
SAO.Census = {
    JOB_PERK = { carpenter = "Woodwork", farmer = "Farming" },
    classOf = function(occupation) return "work:" .. occupation end,
    skillOf = function(id, perk) return id == "alpha" and 5 or 2 end,
}
SAO.Perception = { beliefs = __captureBeliefs }
SAO.Rand = { state = function() return "seed-one", 17 end }
SAO.Standing = {
    creedOf = function(group) return { name = "make-do" } end,
    trust = function(source, target) return source == "alpha" and 0.6 or 0.3 end,
    isHostileTo = function() return false end,
    larderOf = function() return "low" end,
    waterStoreOf = function() return "steady" end,
    hearthOf = function() return true end,
    feudBetween = function(left, right) return right == "rival" end,
}
SAO.Standing.electLeader = function(group)
    __captureRealCalls = __captureRealCalls + 1
    __captureRecords.alpha.profile.note = "during"
    __captureBeliefs.alpha.evidence.value = "during"
    __captureState.groupClaims.home.facts.status = "during"
    __captureRecords.alpha.designation = "leader"
    __captureRecords.alpha.designatedBy = "standing-election"
    __captureState.groupMeta.home.leaderId = "alpha"
    return "alpha", true
end
'''

SUCCESS = r'''(function()
    local owner = SAODecisionCapture.begin({
        runId = "run-one", county = "County000" })
    local selected, changed = SAO.Standing.electLeader("home")
    __captureRecords.alpha.profile.note = "after"
    __captureBeliefs.alpha.evidence.value = "after"
    __captureState.groupClaims.home.facts.status = "after"
    local captured = owner.finish()
    return '{"selected":' .. SAODecisionCapture.encode(selected)
        .. ',"changed":' .. SAODecisionCapture.encode(changed)
        .. ',"realCalls":' .. tostring(__captureRealCalls)
        .. ',"capture":' .. captured .. '}'
end)()'''

READER_FAILURE = r'''(function()
    SAO.History.ageOf = function() error("age reader broke") end
    local owner = SAODecisionCapture.begin({
        runId = "run-reader", county = "County001" })
    SAO.Standing.electLeader("home")
    return '{"realCalls":' .. tostring(__captureRealCalls)
        .. ',"capture":' .. owner.finish() .. '}'
end)()'''

CYCLE_FAILURE = r'''(function()
    __captureRecords.alpha.profile.self = __captureRecords.alpha.profile
    local owner = SAODecisionCapture.begin({
        runId = "run-cycle", county = "County002" })
    SAO.Standing.electLeader("home")
    return '{"realCalls":' .. tostring(__captureRealCalls)
        .. ',"capture":' .. owner.finish() .. '}'
end)()'''


def run_probe(expression):
    with tempfile.TemporaryDirectory(prefix="sao-capture-border-") as temporary:
        work = pathlib.Path(temporary)
        shutil.copy2(Sweep.STDLIB, work / "stdlib.lua")
        for compiled in Sweep.OUT.glob("*.class"):
            shutil.copy2(compiled, work / compiled.name)
        prelude = work / "prelude.lua"
        prelude.write_text(PRELUDE, encoding="utf-8")
        completed = subprocess.run(
            [str(Sweep.JDK / "java.exe"), "-cp", "%s;." % Sweep.PZ,
             "LuaRun", str(prelude), str(CAPTURE), "--", expression],
            cwd=str(work), capture_output=True, text=True,
            encoding="utf-8", errors="replace", timeout=180)
    values = [line[6:] for line in (completed.stdout or "").splitlines()
              if line.startswith("VALUE ")]
    if completed.returncode or len(values) != 1:
        detail = (completed.stdout or "") + (completed.stderr or "")
        raise RuntimeError("capture probe failed: " + detail[-1000:])
    return values[0], json.loads(values[0])


def member(decision, identity):
    return next(row for row in decision["roster"] if row["id"] == identity)


def publication_controls(faults):
    fixture = {
        "schema": "sao-decision-run",
        "schemaVersion": 2,
        "run": {"id": "run-publish", "county": "County009",
                "captureInvocationId": "invocation-one"},
        "events": [],
    }
    with tempfile.TemporaryDirectory(prefix="sao-capture-publish-") as temporary:
        base = pathlib.Path(temporary) / "published"
        destination = Dump.publish(base, [fixture])
        manifest = json.loads((destination / "manifest.json").read_text())
        payload = destination / "County009.json"
        digest = hashlib.sha256(payload.read_bytes()).hexdigest()
        if (manifest.get("complete") is not True
                or manifest.get("runCount") != 1
                or manifest.get("captureInvocationIds") != ["invocation-one"]
                or manifest.get("files", {}).get(payload.name) != digest):
            faults.append("atomic publication manifest does not bind its run bytes")

    with tempfile.TemporaryDirectory(prefix="sao-capture-refusal-") as temporary:
        base = pathlib.Path(temporary) / "published"
        original = Dump.os.replace
        Dump.os.replace = lambda source, target: (_ for _ in ()).throw(
            OSError("controlled rename failure"))
        try:
            try:
                Dump.publish(base, [fixture])
                faults.append("publication accepted a failed atomic rename")
            except OSError:
                pass
        finally:
            Dump.os.replace = original
        if base.exists() and list(base.iterdir()):
            faults.append("failed publication left a partial dump visible")


def run_identity_controls(faults):
    original_provenance = Dump.Sweep.provenance
    original_sha256 = Dump.Sweep.sha256
    Dump.Sweep.provenance = lambda *args: {
        "sourceHashes": {}, "historyOrigin": {"iso": "1993-07-09"}}
    Dump.Sweep.sha256 = lambda path: "a" * 64
    try:
        first, first_id = Dump.stable_run_identity(
            "County000", pathlib.Path("lua"), [], 1096, None, False,
            "1" * 32)
        second, second_id = Dump.stable_run_identity(
            "County000", pathlib.Path("lua"), [], 1096, None, False,
            "2" * 32)
    finally:
        Dump.Sweep.provenance = original_provenance
        Dump.Sweep.sha256 = original_sha256
    if (first_id == second_id
            or first["configurationSha256"] != second["configurationSha256"]
            or first["captureInvocationId"] == second["captureInvocationId"]):
        faults.append("repeated executions reused one run identity")


def main():
    print("=" * 74)
    print("DECISION EVIDENCE FREEZES BEFORE THE WORLD MOVES")
    print("=" * 74)
    faults = []
    required = (Sweep.JDK, Sweep.PZ, Sweep.STDLIB, Sweep.SRC, CAPTURE, COUNTY)
    if not all(path.exists() for path in required):
        print("  SKIPPED - installed VM or decision capture source absent")
        print("  181) immutable decision evidence: SKIPPED, engine absent")
        return 0
    if not Sweep.build_runner():
        print("  FAULT: LuaRun will not compile against the installed jar")
        return 1

    raw, successful = run_probe(SUCCESS)
    repeated_raw, _ = run_probe(SUCCESS)
    capture = successful["capture"]
    if raw != repeated_raw:
        faults.append("the same decision evidence did not encode deterministically")
    if successful.get("realCalls") != 1 or successful.get("selected") != "alpha":
        faults.append("capture did not preserve the real election and its return")
    if capture.get("eventCount") != 1 or capture.get("captureFailureCount") != 0:
        faults.append("the valid election did not produce exactly one clean event")
    else:
        event = capture["events"][0]
        decision, result = event["decision"], event["result"]
        alpha = member(decision, "alpha")
        if alpha["record"]["profile"]["note"] != "before":
            faults.append("nested record changed after decision-time capture")
        if alpha["record"]["profile"]["control"] != "line\nunit\x01":
            faults.append("JSON control characters were not encoded losslessly")
        if alpha["beliefs"]["evidence"]["value"] != "before":
            faults.append("nested belief changed after decision-time capture")
        if decision["claim"]["facts"]["status"] != "before":
            faults.append("nested claim changed after decision-time capture")
        result_alpha = member(result, "alpha")
        if (result.get("leaderAfter") != "alpha"
                or result_alpha.get("designationAfter") != "leader"):
            faults.append("post-election result was not kept separately")
        if (event.get("runId") != "run-one"
                or event.get("county") != "County000"
                or not event.get("eventId", "").startswith(
                    "run-one/standing-election/")):
            faults.append("event lacks its run, county and event namespace")
        if (event.get("conditioning", {}).get("status") != "ineligible"
                or event.get("options", {}).get("status") != "not-captured"
                or event.get("choice", {}).get("status") != "not-captured"
                or event.get("consequences", {}).get("status")
                != "not-observed"):
            faults.append("legacy election was mislabeled as training-ready choice data")

    _, reader = run_probe(READER_FAILURE)
    reader_capture = reader["capture"]
    if (reader.get("realCalls") != 1 or reader_capture.get("eventCount") != 0
            or reader_capture.get("captureFailureCount") != 1
            or "History.ageOf" not in
            reader_capture.get("failures", [{}])[0].get("detail", "")):
        faults.append("a required-reader failure did not reject capture and preserve play")

    _, cycle = run_probe(CYCLE_FAILURE)
    cycle_capture = cycle["capture"]
    if (cycle.get("realCalls") != 1 or cycle_capture.get("eventCount") != 0
            or cycle_capture.get("captureFailureCount") != 1
            or "cycle" not in
            cycle_capture.get("failures", [{}])[0].get("detail", "")):
        faults.append("a nested cycle was hidden or interrupted the real election")

    capture_source = CAPTURE.read_text(encoding="utf-8")
    county_source = COUNTY.read_text(encoding="utf-8")
    freeze = capture_source.find("frozenDecision = encode(decision)")
    mutation = capture_source.find("local returned = pack(original(groupName))")
    if freeze < 0 or mutation < 0 or freeze > mutation:
        faults.append("production capture does not freeze before the real election")
    contracts = {
        "evidence host removes fabricated ground": "Sweep.evidence_host(owed)",
        "completed horizon is mandatory": "Sweep.validate_result(runtime, owed",
        "capture failures reject the run": 'capture.get("captureFailureCount") != 0',
        "run and event collisions reject": "len(set(event_ids)) != len(event_ids)",
        "publication is an atomic rename": "os.replace(staging, destination)",
        "no model is falsely attributed": '"used": False',
    }
    for label, token in contracts.items():
        if token not in county_source:
            faults.append(label)
    publication_controls(faults)
    run_identity_controls(faults)

    if faults:
        for fault in faults:
            print("  FAULT: " + fault)
        return 1
    print("  valid capture: nested record, belief and claim bytes stay pre-election")
    print("  controls: required-reader and cyclic captures rejected; play continued")
    print("  publication: complete manifest appears by one atomic directory rename")
    print("  181) PASS - immutable namespaced evidence; incomplete or failed runs withheld")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
