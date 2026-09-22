#!/usr/bin/env python3
"""Border 187: explicit presence produces dated personal world knowledge."""
from __future__ import annotations

import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

import county_sweep as Sweep
import world_knowledge_evidence as Evidence


ROOT = pathlib.Path(__file__).resolve().parent.parent
WORLD = ROOT / "mod/42.20/media/lua/shared/SAO_WorldKnowledge.lua"
KNOWLEDGE = ROOT / "mod/42.20/media/lua/shared/SAO_Knowledge.lua"
CAPTURE = ROOT / "tools/sweep/decision_capture.lua"
ADMISSIONS = ROOT / "mod/42.20/media/lua/client/SAO_PopulationAdmissions.lua"
POPULATION = ROOT / "mod/42.20/media/lua/client/SAO_Population.lua"
CHECK = ROOT / "tools/check.sh"
CALENDAR = ROOT / "tools/record_calendar_test.py"
RECORD = ROOT / "java/src/com/sao/engine/SAORecord.java"


PRELUDE = r'''
SAO = {}
_G.__now = 0
_G.__calendar = true
_G.__recordHours = { [-8] = -192, [-7] = -168 }
_G.__ages = { adult=31, newcomer=31, child=12, future=31, pending=31, other=31 }
_G.__records = {}
SAO.Identity = {
    get = function(id) return __records[tostring(id)] end,
    all = function() return __records end,
}
SAO.History = {
    countyHours = function() return __now end,
    recordHour = function(day)
        if not __calendar then return nil end
        return __recordHours[day]
    end,
    ageInYear = function(id, year) return __ages[tostring(id)] end,
}
'''


PROBE = r'''(function()
    local function person(id)
        local rec = { id=id, originRegion="Muldraugh, KY" }
        __records[id] = rec
        return rec
    end
    local function count(rows) return type(rows) == "table" and #rows or -1 end

    local adult = person("adult")
    local adultMarked = SAO.WorldKnowledge.markCountyPresence(adult, true)
    local adultClaims = SAO.WorldKnowledge.claimsOf("adult", 0)
    local adultObservation = SAO.WorldKnowledge.observe("adult", 0)
    local adultPresence = SAO.WorldKnowledge.presenceOf("adult")
    local first = adultClaims[1]
    if first then
        first.claimId = "tampered"
        first.source.path = "tampered"
    end
    local detached = SAO.WorldKnowledge.claimsOf("adult", 0)
    SAO.WorldKnowledge.markCountyPresence(adult, true)
    local idempotentPresence = SAO.WorldKnowledge.presenceOf("adult")

    local newcomer = person("newcomer")
    SAO.WorldKnowledge.markCountyPresence(newcomer, false)
    local newcomerClaims = SAO.WorldKnowledge.claimsOf("newcomer", 0)

    local legacy = person("legacy")
    SAO.WorldKnowledge.advancePerson(legacy, 24)
    local legacyClaims = SAO.WorldKnowledge.claimsOf("legacy", 24)

    local child = person("child")
    SAO.WorldKnowledge.markCountyPresence(child, true)
    local childClaims = SAO.WorldKnowledge.claimsOf("child", 0)

    __recordHours = { [-8]=0, [-7]=24 }
    __now = 0
    local future = person("future")
    SAO.WorldKnowledge.markCountyPresence(future, true)
    local futureBefore = SAO.WorldKnowledge.claimsOf("future", 0)
    __now = 24
    SAO.WorldKnowledge.advancePerson(future)
    local futureAfter = SAO.WorldKnowledge.claimsOf("future", 24)

    __calendar = false
    local pending = person("pending")
    local pendingReady, pendingWhy = SAO.WorldKnowledge.markCountyPresence(pending, true)
    __calendar = true
    SAO.WorldKnowledge.advancePerson(pending, 24)
    local pendingAfter = SAO.WorldKnowledge.claimsOf("pending", 24)

    __recordHours = { [-8]=-192, [-7]=-168 }
    __now = 0
    local worldFacts = SAO.Knowledge.about("adult", "world") or {}
    local ports = SAO.WorldKnowledge.claimPorts()
    return SAODecisionCapture.encode({
        adultMarked=adultMarked,
        adultClaims=count(adultClaims),
        adultAcquired=adultClaims[1] and adultClaims[1].acquiredHour,
        adultPresence=count(adultPresence),
        adultPresenceFrom=adultPresence[1] and adultPresence[1].fromHour,
        adultObservation=count(adultObservation),
        observationAsOf=adultObservation[1] and adultObservation[1].asOfHour,
        observationChecks=adultObservation[1] and adultObservation[1].checks,
        detachedClaim=detached[1] and detached[1].claimId,
        detachedSource=detached[1] and detached[1].source.path,
        idempotentPresence=count(idempotentPresence),
        newcomerClaims=count(newcomerClaims),
        legacyClaims=count(legacyClaims),
        childClaims=count(childClaims),
        futureBefore=count(futureBefore),
        futureAfter=count(futureAfter),
        pendingReady=pendingReady,
        pendingWhy=pendingWhy,
        pendingAfter=count(pendingAfter),
        otherClaims=count(SAO.WorldKnowledge.claimsOf("other", 24)),
        worldFacts=count(worldFacts),
        worldFact=worldFacts[1] and worldFacts[1].claimId,
        portCount=count(ports),
        portHasText=ports[1] and ports[1].text ~= nil,
        portSource=ports[1] and ports[1].sourceSha256,
        portExcerpt=ports[1] and ports[1].excerptSha256,
    })
end)()'''


def run(module: pathlib.Path = WORLD) -> dict:
    with tempfile.TemporaryDirectory(prefix="sao-world-knowledge-") as temporary:
        work = pathlib.Path(temporary)
        shutil.copy2(Sweep.STDLIB, work / "stdlib.lua")
        for compiled in Sweep.OUT.glob("LuaRun*.class"):
            shutil.copy2(compiled, work / compiled.name)
        prelude = work / "prelude.lua"
        prelude.write_text(PRELUDE, encoding="utf-8")
        probe = work / "probe.lua"
        probe.write_text("__worldKnowledgeResult = " + PROBE, encoding="utf-8")
        completed = subprocess.run(
            [str(Sweep.JDK / "java.exe"), "-cp", f"{Sweep.PZ};.", "LuaRun",
             str(prelude), str(module), str(KNOWLEDGE), str(CAPTURE),
             str(probe), "--", "__worldKnowledgeResult"],
            cwd=work, capture_output=True, text=True, encoding="utf-8",
            errors="replace", timeout=180)
        values = [line[6:] for line in completed.stdout.splitlines()
                  if line.startswith("VALUE ")]
        if completed.returncode or len(values) != 1:
            raise RuntimeError("world-knowledge probe failed: " +
                               (completed.stdout + completed.stderr)[-1600:])
        return json.loads(values[0])


def faults_for(result: dict) -> list[str]:
    faults: list[str] = []
    expected = {
        "adultMarked": True,
        "adultClaims": 1,
        "adultAcquired": -168,
        "adultPresence": 1,
        "adultPresenceFrom": -192,
        "adultObservation": 1,
        "observationAsOf": 0,
        "detachedClaim": "knox-telecommunications-outage-1993-07-02",
        "detachedSource": "world/us-1993/knox-event.md",
        "idempotentPresence": 1,
        "newcomerClaims": 0,
        "legacyClaims": 0,
        "childClaims": 0,
        "futureBefore": 0,
        "futureAfter": 1,
        "pendingReady": False,
        "pendingWhy": "calendar-unavailable",
        "pendingAfter": 1,
        "otherClaims": 0,
        "worldFacts": 1,
        "worldFact": "knox-telecommunications-outage-1993-07-02",
        "portCount": 1,
        "portHasText": False,
        "portSource": "bc4b723d8ba8a35eca4a43e88e1457c4dc225d7213ead5c52364f966c6aa0676",
        "portExcerpt": "f663ffcbaa873c8fb228e1fbdf8574861a0f149559d1fec20695c6be32e82c60",
    }
    for name, wanted in expected.items():
        if result.get(name) != wanted:
            faults.append(f"{name}={result.get(name)!r}, wanted {wanted!r}")
    checks = result.get("observationChecks", {})
    if set(checks) != {"age", "carrier", "access", "retention"} or any(
            row.get("status") != "supported" for row in checks.values()):
        faults.append("retention observation lacks four supported personal checks")
    return faults


def mutation(module_text: str, old: str, new: str) -> dict:
    if module_text.count(old) != 1:
        raise RuntimeError("mutation anchor does not occur exactly once: " + old)
    with tempfile.TemporaryDirectory(prefix="sao-world-knowledge-mutation-") as temporary:
        path = pathlib.Path(temporary) / "SAO_WorldKnowledge.lua"
        path.write_text(module_text.replace(old, new), encoding="utf-8")
        return run(path)


def calendar_control() -> str | None:
    """Compile one bad production source and require the mature anchor to move."""
    text = RECORD.read_text(encoding="utf-8")
    old = ".minusDays(Math.max(0, behind)).atStartOfDay();"
    new = ".atStartOfDay();"
    if text.count(old) != 1:
        return "calendar mutation anchor does not occur exactly once"
    helper = """\
import com.sao.engine.SAORecord;
public final class C74CalendarControl {
  public static void main(String[] args) {
    System.out.println(SAORecord.countyInstant(1996, 6, 8, 0.0, 1096));
  }
}
"""
    with tempfile.TemporaryDirectory(prefix="sao-calendar-control-") as temporary:
        work = pathlib.Path(temporary)
        source = work / "com/sao/engine/SAORecord.java"
        source.parent.mkdir(parents=True)
        source.write_text(text.replace(old, new), encoding="utf-8")
        control = work / "C74CalendarControl.java"
        control.write_text(helper, encoding="utf-8")
        classpath = os.pathsep.join([str(Evidence.Source.JAR), str(Sweep.PZ)])
        built = subprocess.run(
            [str(Sweep.JDK / "javac.exe"), "-cp", classpath, "-d", str(work),
             str(source), str(control)], capture_output=True, text=True,
            encoding="utf-8", errors="replace", timeout=240)
        if built.returncode:
            return "calendar mutation did not compile: " + built.stderr[-500:]
        ran = subprocess.run(
            [str(Sweep.JDK / "java.exe"), "-cp",
             os.pathsep.join([str(work), classpath]), "C74CalendarControl"],
            capture_output=True, text=True, encoding="utf-8", errors="replace",
            timeout=240)
        value = ran.stdout.strip()
        if ran.returncode:
            return "calendar mutation did not run: " + ran.stderr[-500:]
        if value == "1993-07-09T00:00:00":
            return "save-start-only calendar mutation did not change the verdict"
    return None


def port_faults(capture: dict, evidence: dict) -> list[str]:
    event = capture.get("events", [{}])[0]
    record = event.get("decision", {}).get("person", {}).get("record", {})
    acquisitions = record.get("worldKnowledge", {}).get("acquisitions", [])
    faults: list[str] = []
    if (capture.get("eventCount") != 1 or len(acquisitions) != 1
            or evidence.get("namespace", {}).get("personId") != "actor"
            or evidence.get("eventSha256") != Evidence.digest(event)
            or evidence.get("acquisition", {}).get("recordId")
            != acquisitions[0].get("recordId")):
        faults.append("native decision and same-person acquisition are not hash-bound")
    return faults


def main() -> int:
    print("=" * 74)
    print("DATED COUNTY PRESENCE PRODUCES PERSONAL WORLD KNOWLEDGE")
    print("=" * 74)
    required = (Sweep.JDK, Sweep.PZ, Sweep.STDLIB, WORLD, KNOWLEDGE, CAPTURE)
    if not all(path.exists() for path in required):
        print("  SKIPPED - installed VM or C74 source absent")
        print("  187) world-knowledge evidence: SKIPPED, engine absent")
        return 0
    if not Sweep.build_runner():
        print("  FAULT: LuaRun will not compile against the installed jar")
        return 1

    result = run()
    faults = faults_for(result)
    text = WORLD.read_text(encoding="utf-8")
    controls = {
        "future acquisition": ("eventHour <= atHour", "eventHour > atHour"),
        "presence interval": (
            "local presence = eventHour and presenceAt(state, eventHour) or nil",
            "local presence = eventHour and activePresence(state) or nil"),
        "adult claim boundary": (
            "and finite(age) and age >= claim.minimumAge then",
            "and finite(age) and age < claim.minimumAge then"),
        "detached reader": ("out[#out + 1] = copy(entry)",
                            "out[#out + 1] = entry"),
        "retention gate": ("entry.retained == true", "entry.retained ~= true"),
    }
    for label, (old, new) in controls.items():
        changed = mutation(text, old, new)
        if not faults_for(changed):
            faults.append(label + " mutation did not change the verdict")

    admissions = ADMISSIONS.read_text(encoding="utf-8")
    population = POPULATION.read_text(encoding="utf-8")
    knowledge = KNOWLEDGE.read_text(encoding="utf-8")
    static = {
        "origin precedes the genesis presence write":
            admissions.find("rec.originRegion = origin.region") >= 0
            and admissions.find("rec.originRegion = origin.region")
            < admissions.find("SAO.WorldKnowledge.markCountyPresence(rec, not arriving)"),
        "mates receive their own presence record":
            "SAO.WorldKnowledge.markCountyPresence(mate, not arriving)" in admissions,
        "the shared daily county advances dated claims":
            "SAO.WorldKnowledge.advanceAll(hoursNow())" in population,
        "the read-only knowledge surface exposes claim identifiers":
            '"world"' in knowledge and "SAO.WorldKnowledge.claimsOf" in knowledge,
        "protected prose did not cross into SAO":
            "Knox Telecommunications' telephone" not in text,
        "the gate runs Border 187": "tools/world_knowledge_test.py" in CHECK.read_text(encoding="utf-8"),
    }
    for label, passed in static.items():
        if not passed:
            faults.append(label)

    calendar = subprocess.run(
        [sys.executable, str(CALENDAR)], cwd=ROOT, capture_output=True, text=True,
        encoding="utf-8", errors="replace", timeout=240)
    if calendar.returncode or "RECORD PASS" not in calendar.stdout:
        faults.append("compiled county instant/record-hour calendar failed")
    calendar_fault = calendar_control()
    if calendar_fault:
        faults.append(calendar_fault)

    with tempfile.TemporaryDirectory(prefix="sao-r12-port-one-") as first_dir, \
            tempfile.TemporaryDirectory(prefix="sao-r12-port-two-") as second_dir:
        first, second = pathlib.Path(first_dir), pathlib.Path(second_dir)
        Evidence.generate(first)
        Evidence.generate(second)
        for name in ("decision-capture.json", "world-knowledge-evidence.json",
                     "manifest.json"):
            if (first / name).read_bytes() != (second / name).read_bytes():
                faults.append("R12 evidence port is not deterministic: " + name)
        capture = json.loads((first / "decision-capture.json").read_text(encoding="utf-8"))
        evidence = json.loads((first / "world-knowledge-evidence.json").read_text(encoding="utf-8"))
        faults.extend(port_faults(capture, evidence))
        changed = json.loads(json.dumps(evidence))
        changed["eventSha256"] = "0" * 64
        if not port_faults(capture, changed):
            faults.append("decision-binding mutation did not change the verdict")

    if faults:
        for fault in faults:
            print("  FAULT: " + fault)
        return 1
    print("  producer: explicit genesis interval; arrivals begin at admission")
    print("  acquisition: adult lived claim appears only on its record day")
    print("  reader: person-scoped, retention-observed and detached")
    print("  controls: time, presence, age, retention and detachment mutations rejected")
    print("  calendar: compiled exact instant and mature-save anchor pass")
    print("  port: deterministic native decision and same-person evidence bundle")
    print("  187) PASS - dated personal world-knowledge acquisition")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
