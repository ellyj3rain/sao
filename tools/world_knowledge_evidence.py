#!/usr/bin/env python3
"""Generate the bounded R12 decision/acquisition evidence port.

The controlled ground supplies an exact native source and holder. Production
WorldSources, SourceUse, WorldKnowledge and decision-capture modules produce the
records in the installed Project Zomboid Kahlua runtime. This proves the bounded
mechanism and does not claim a sampled natural county or loaded-save acceptance.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import shutil
import subprocess
import tempfile

import county_sweep as Sweep
import decision_capture_test as Capture
import source_use_test as Source


ROOT = pathlib.Path(__file__).resolve().parent.parent
WORLD_KNOWLEDGE = ROOT / "mod/42.20/media/lua/shared/SAO_WorldKnowledge.lua"
HISTORY = ROOT / "mod/42.20/media/lua/shared/SAO_History.lua"
POPULATION = ROOT / "mod/42.20/media/lua/client/SAO_Population.lua"
ADMISSIONS = ROOT / "mod/42.20/media/lua/client/SAO_PopulationAdmissions.lua"
RECORD = ROOT / "java/src/com/sao/engine/SAORecord.java"
BRIDGE = ROOT / "java/src/com/sao/bridge/SAOBridge.java"
VERSION = ROOT / "VERSION"
RUN_ID = "r12-knox-lived-source-example-v1"
COUNTY = "CountyR12Controlled"


EXAMPLE = r'''
  local sourceId = offered.options[2].id
  SAO.SourceUse.chooseOption = function(offer) return offer.options[2] end
  record.originRegion = "Muldraugh, KY"
  SAO.History.recordHour = function(day)
      if day == -8 then return -192 end
      if day == -7 then return -168 end
      return nil
  end
  SAO.History.ageInYear = function(id, year) return 31 end
  local marked, markWhy = SAO.WorldKnowledge.markCountyPresence(record, true)
  check("presence_recorded", marked == true and markWhy == nil)
  check("claim_acquired", #SAO.WorldKnowledge.claimsOf("actor",48) == 1)
  local owner = SAODecisionCapture.beginSourceUse({runId="RUN_ID",county="COUNTY"})
  local reservation, first, second = toTransfer("actor",body,p,"food")
  check("exact_selected_source", reservation and reservation.sourceId == sourceId
      and first == "moving" and second == "using")
  __carriedItem, __busy, __observeText = __sourceItem, false, SOURCE_POST
  SAO.SourceUse.tick("actor",body)
  __queued:complete(); __busy = false
  local final = SAO.SourceUse.tick("actor",body)
  local capture = owner.finish()
  local observations = SAO.WorldKnowledge.observe("actor",48)
  local presence = SAO.WorldKnowledge.presenceOf("actor")
  return '{"checks":' .. SAODecisionCapture.encode(checks)
      .. ',"final":' .. SAODecisionCapture.encode(final)
      .. ',"observations":' .. SAODecisionCapture.encode(observations)
      .. ',"presence":' .. SAODecisionCapture.encode(presence)
      .. ',"capture":' .. capture .. '}'
end)()'''.replace("RUN_ID", RUN_ID).replace("COUNTY", COUNTY)


def encoded(value: object) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True,
                      separators=(",", ":"), allow_nan=False).encode("utf-8")


def digest(value: object) -> str:
    return hashlib.sha256(encoded(value)).hexdigest()


def sha256(path: pathlib.Path) -> str:
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def source_label(path: pathlib.Path) -> str:
    """A stable manifest key; local install paths are evidence, not identity."""
    try:
        return path.resolve().relative_to(ROOT.resolve()).as_posix()
    except ValueError:
        if path.resolve() == Sweep.PZ.resolve():
            return "installed/projectzomboid.jar"
        if path.resolve() == Sweep.STDLIB.resolve():
            return "installed/stdlib.lua"
        raise RuntimeError("unlabelled external evidence source: " + str(path))


def run_kahlua() -> dict:
    other = Source.source("C:second:0", "second-fp", "second-r1", 9, 8,
                          42, 109, "Base.Banana")
    hidden = Source.source("C:hidden:0", "hidden-fp", "hidden-r1", 8, 8,
                           99, 110, "Base.Pear")
    snapshot = Source.snapshot(1, 1, "source-pre", [Source.FOOD, other, hidden])
    post = Source.snapshot(1, 1, "source-post", [Source.FOOD, dict(
        other, rev="second-r2", state="spent", quantities={}, items=[]), hidden])
    expression = (Capture.SOURCE_SETUP + EXAMPLE).replace(
        "SOURCE_SNAPSHOT", json.dumps(snapshot)).replace("SOURCE_POST", json.dumps(post))
    with tempfile.TemporaryDirectory(prefix="sao-r12-evidence-") as temporary:
        work = pathlib.Path(temporary)
        shutil.copy2(Sweep.STDLIB, work / "stdlib.lua")
        for compiled in Sweep.OUT.glob("LuaRun*.class"):
            shutil.copy2(compiled, work / compiled.name)
        prelude = work / "prelude.lua"
        prelude.write_text(Source.ACTION_PRELUDE, encoding="utf-8")
        probe = work / "probe.lua"
        probe.write_text("__r12Evidence = " + expression, encoding="utf-8")
        completed = subprocess.run(
            [str(Sweep.JDK / "java.exe"), "-cp", f"{Sweep.PZ};.", "LuaRun",
             str(prelude), str(Source.WORLD), str(Source.SOURCE_USE),
             str(WORLD_KNOWLEDGE), str(Capture.CAPTURE), str(probe),
             "--", "__r12Evidence"], cwd=work, capture_output=True, text=True,
            encoding="utf-8", errors="replace", timeout=180)
        values = [line[6:] for line in completed.stdout.splitlines()
                  if line.startswith("VALUE ")]
        if completed.returncode or len(values) != 1:
            raise RuntimeError("R12 evidence probe failed: " +
                               (completed.stdout + completed.stderr)[-1800:])
        result = json.loads(values[0])
    bad = [check for check in result.get("checks", []) if not check.endswith("=true")]
    if bad or result.get("final") != "completed":
        raise RuntimeError("R12 production checks failed: " + repr(bad))
    Capture.Dump.validate_source_capture(result["capture"], "R12 example")
    if len(result.get("observations", [])) != 1 or len(result.get("presence", [])) != 1:
        raise RuntimeError("R12 personal evidence is incomplete")
    return result


def calendar_values() -> dict:
    source = """\
import com.sao.engine.SAORecord;
public final class C74CalendarEvidence {
  public static void main(String[] args) {
    System.out.println(SAORecord.countyInstant(1993, 6, 8, 0.0, 0));
    System.out.println(SAORecord.countyInstant(1993, 6, 8, 48.0, 0));
    System.out.println(SAORecord.recordHourFor(1993, 6, 8, -7, 0, false));
  }
}
"""
    with tempfile.TemporaryDirectory(prefix="sao-r12-calendar-") as temporary:
        work = pathlib.Path(temporary)
        java = work / "C74CalendarEvidence.java"
        java.write_text(source, encoding="utf-8")
        classpath = os.pathsep.join([str(Source.JAR), str(Sweep.PZ)])
        built = subprocess.run(
            [str(Sweep.JDK / "javac.exe"), "-cp", classpath, "-d", str(work), str(java)],
            capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=180)
        if built.returncode:
            raise RuntimeError("calendar evidence compile failed: " + built.stderr[-1200:])
        ran = subprocess.run(
            [str(Sweep.JDK / "java.exe"), "-cp", os.pathsep.join([classpath, str(work)]),
             "C74CalendarEvidence"], capture_output=True, text=True, encoding="utf-8",
            errors="replace", timeout=180)
        lines = [line.strip() for line in ran.stdout.splitlines() if line.strip()]
        if ran.returncode or lines != ["1993-07-09T00:00:00",
                                      "1993-07-11T00:00:00", "-168.0"]:
            raise RuntimeError("calendar evidence values differ: " + repr(lines))
    return {"schema": "sao-county-calendar-evidence", "schemaVersion": 1,
            "recordId": "county-calendar/shipped-1993-07-09",
            "owner": "SAORecord", "anchorHour": 0,
            "anchorAt": lines[0], "horizonHour": 48, "horizonAt": lines[1],
            "claimEventRecordDay": -7, "claimEventHour": float(lines[2]),
            "resolution": "second", "policy": "save-start-minus-history-offset"}


def atomic_json(path: pathlib.Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_bytes(json.dumps(value, ensure_ascii=False, indent=2,
                                     sort_keys=True, allow_nan=False).encode("utf-8") + b"\n")
    os.replace(temporary, path)


def generate(destination: pathlib.Path) -> None:
    if not Sweep.build_runner():
        raise RuntimeError("LuaRun does not compile against the installed game")
    result = run_kahlua()
    capture = result["capture"]
    event = capture["events"][0]
    observation = result["observations"][0]
    acquisition = observation["acquisition"]
    presence = result["presence"][0]
    calendar = calendar_values()
    namespace = {"runId": event["runId"], "county": event["county"],
                 "personId": event["decision"]["person"]["id"],
                 "eventId": event["eventId"], "hour": event["decision"]["hours"]}
    records = [calendar, presence, acquisition, observation]
    evidence = {
        "schema": "sao-world-knowledge-evidence", "schemaVersion": 1,
        "namespace": namespace, "eventSha256": digest(event),
        "calendar": calendar, "presence": presence,
        "acquisition": acquisition, "retentionObservation": observation,
        "recordHashes": [{"recordId": row["recordId"], "sha256": digest(row)}
                         for row in records],
        "standing": "produced-not-adjudicated",
        "limitations": [
            "Controlled native source and holder; not a sampled natural county.",
            "Installed Kahlua runtime and production action modules; not loaded-save acceptance.",
            "SAO produces personal evidence and grants no extraction, choice, or training approval.",
        ],
    }
    destination.mkdir(parents=True, exist_ok=True)
    capture_path = destination / "decision-capture.json"
    evidence_path = destination / "world-knowledge-evidence.json"
    atomic_json(capture_path, capture)
    atomic_json(evidence_path, evidence)
    sources = [WORLD_KNOWLEDGE, HISTORY, POPULATION, ADMISSIONS, RECORD, BRIDGE,
               Source.WORLD, Source.SOURCE_USE, Capture.CAPTURE, pathlib.Path(__file__),
               Sweep.PZ, Sweep.STDLIB, Source.JAR, VERSION]
    manifest = {
        "schema": "sao-world-knowledge-evidence-manifest", "schemaVersion": 1,
        "example": RUN_ID, "version": VERSION.read_text(encoding="utf-8").strip(),
        "runtime": "Kahlua from the installed Project Zomboid jar",
        "files": {capture_path.name: sha256(capture_path),
                  evidence_path.name: sha256(evidence_path)},
        "sourceHashes": {source_label(path): sha256(path) for path in sources},
    }
    manifest["contentSha256"] = digest(manifest)
    atomic_json(destination / "manifest.json", manifest)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, type=pathlib.Path)
    args = parser.parse_args(argv)
    generate(args.out.resolve())
    print("wrote R12 decision/acquisition evidence to " + str(args.out.resolve()))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
