#!/usr/bin/env python3
r"""Export immutable decision evidence from completed county simulations.

The instrument observes the shipped Standing election in the same Kahlua county
runner used by the evidence sweep. A decision document is serialized before the
real election. Its authored result is serialized afterwards under a separate
field. Nested records, beliefs, claims, relations and need state therefore
cannot change the decision-time bytes later in the run.

Source-use capture also records private executable options, the runtime choice
and its exact reservation result when that executor is loaded. Enacted
Organization appraisals separately emit full-namespace version 3 rows: the
actor-private decision is frozen before response delivery while native work and
process results remain under a later horizon. All captured runtime choices
remain unratified and conditioning-ineligible.

Publication is all-or-nothing. Every requested county must reach the requested
horizon with no protected callback or capture-reader failures. Only then is a
complete directory renamed into place. The run envelope carries the namespace,
clock, settings, random state, engine mode, schemas and source hashes needed to
reproduce or reject it.

  python tools/county_dump.py --runs 12
  python tools/county_dump.py --runs 24 --out C:/wherever
  python tools/county_dump.py --runs 12 --engine
"""
from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import json
import math
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import time
import uuid

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import county_sweep as Sweep                                    # noqa: E402


CAPTURE_LUA = Sweep.SWEEP / "decision_capture.lua"
EVIDENCE_LUA = Sweep.SWEEP / "evidence.lua"

RUN = r'''(function()
  _G.__world = 'RUN_NAME'
  local evidence = SAOSweepEvidence.begin()
  local capture = SAODecisionCapture.begin({
      runId = 'RUN_ID', county = _G.__world })
  local standing = ModData.getOrCreate('SurvivorAwareness_Standing')

  -- The shipped tick owner builds and advances the county. The instrument
  -- observes its election verb and creates no people, groups or outcomes.
  local tick = _G.__handlers.OnTick
  for index = 1, 240 * 9000 do
    tick()
    evidence.observe()
    if index % 240 == 0
      and (tonumber(standing.yearsRun) or 0)
        >= (tonumber(standing.yearsOwed) or -1) then
      break
    end
  end

  local alive, dead = 0, 0
  for _, record in pairs(SAO.Identity.all()) do
    if record.dead then dead = dead + 1 else alive = alive + 1 end
  end
  local reachedHours = SAO.History.countyHours()
  local captured = capture.finish()
  local observed = evidence.finish()
  return '{"schema":"sao-decision-run-runtime"'
    .. ',"schemaVersion":1'
    .. ',"runId":' .. SAODecisionCapture.encode('RUN_ID')
    .. ',"county":' .. SAODecisionCapture.encode(_G.__world)
    .. ',"ranTo":' .. tostring(standing.yearsRun)
    .. ',"yearsTicks":' .. tostring(standing.yearsTicks or 0)
    .. ',"reachedHours":' .. tostring(reachedHours)
    .. ',"alive":' .. tostring(alive)
    .. ',"dead":' .. tostring(dead)
    .. ',"capture":' .. captured
    .. ',"evidence":' .. observed .. '}'
end)()'''


def stable_run_identity(name, lua, paths, owed, refill, engine,
                        capture_invocation_id, joint=False):
    identity = Sweep.provenance(
        name, lua, owed, refill, None, engine, joint, paths)
    identity["capture"] = {
        "schema": "sao-decision-run-v2",
        "eventSchema": "sao-decision-event-v1",
        "coordinationSchema": "speakeasy-decision-row-v3",
        "clockSchema": "sao-county-hours-v1",
    }
    identity["model"] = {"used": False, "hashes": {}}
    for path in (pathlib.Path(__file__).resolve(), CAPTURE_LUA, EVIDENCE_LUA):
        identity["sourceHashes"][str(path)] = Sweep.sha256(path)
    material = json.dumps(
        identity, sort_keys=True, separators=(",", ":")).encode("utf-8")
    configuration_hash = hashlib.sha256(material).hexdigest()
    identity["configurationSha256"] = configuration_hash
    identity["captureInvocationId"] = capture_invocation_id
    run_id = ("sao-run-" + capture_invocation_id[:16] + "-"
              + configuration_hash[:12])
    return identity, run_id


def runtime_command(work, prelude, host, lua, paths, engine, run):
    classpath = "%s;%s;." % (Sweep.PZ, Sweep.SAO_JAR) if engine \
        else "%s;." % Sweep.PZ
    command = [str(Sweep.JDK / "java.exe"), "-cp", classpath, "LuaRun"]
    if engine:
        command += ["--engine", str(Sweep.GAME)]
    command += [str(prelude), str(host)]
    if engine:
        command += [str(Sweep.ENGINE_FILL_LUA), str(Sweep.SWEEP / "engine_fill.lua")]
    command += [str(Sweep.CACHE / "map.lua"), str(Sweep.SWEEP / "places.lua")]
    command += [str(path) for path in paths]
    command += [str(Sweep.CACHE / "regions.lua"), str(EVIDENCE_LUA),
                str(CAPTURE_LUA), "--", run]
    return command


def one(name, lua, paths, owed, refill, engine=False, timeout=3600,
        capture_invocation_id=None, joint=False):
    if owed <= 0 or not re.fullmatch(r"[A-Za-z0-9_.-]+", name):
        raise Sweep.EvidenceError(
            "positive calendar days and a safe county name are required")
    capture_invocation_id = capture_invocation_id or uuid.uuid4().hex
    identity, run_id = stable_run_identity(
        name, lua, paths, owed, refill, engine, capture_invocation_id, joint)
    prelude_text = (Sweep.SWEEP / "prelude.lua").read_text(encoding="utf-8")
    prelude_text = prelude_text.replace(
        "_G.__owed = 1096", "_G.__owed = %d" % owed)
    if refill is not None:
        prelude_text = prelude_text.replace(
            "RefillDays = 2.0", "RefillDays = %s" % refill)

    with tempfile.TemporaryDirectory(prefix="sao-decision-run-") as temporary:
        work = pathlib.Path(temporary)
        shutil.copy2(Sweep.STDLIB, work / "stdlib.lua")
        for compiled in Sweep.OUT.glob("*.class"):
            shutil.copy2(compiled, work / compiled.name)
        prelude = work / "prelude.lua"
        prelude.write_text(prelude_text, encoding="utf-8")
        host = work / "evidence_host.lua"
        host.write_text(Sweep.evidence_host(owed), encoding="utf-8")
        script = RUN.replace("RUN_NAME", name).replace("RUN_ID", run_id)
        command = runtime_command(
            work, prelude, host, lua, paths, engine, script)
        try:
            completed = subprocess.run(
                command, cwd=str(work), capture_output=True, text=True,
                encoding="utf-8", errors="replace", timeout=timeout)
        except subprocess.TimeoutExpired as exc:
            raise Sweep.EvidenceError(
                "%s timed out before completing %s days" % (name, owed)) from exc
        except OSError as exc:
            raise Sweep.EvidenceError(
                "%s VM could not start: %s" % (name, exc)) from exc

    output = completed.stdout or ""
    if completed.returncode != 0 or re.search(r"^ERROR ", output, re.M):
        raise Sweep.EvidenceError(
            "%s VM failed (exit %s): %s" %
            (name, completed.returncode, (output + completed.stderr)[-4000:]))
    values = re.findall(r"^VALUE (.+)$", output, re.M)
    if len(values) != 1:
        raise Sweep.EvidenceError(
            "%s did not return exactly one decision result" % name)
    try:
        runtime = json.loads(values[0])
    except ValueError as exc:
        raise Sweep.EvidenceError(
            "%s returned invalid decision JSON: %s" % (name, exc)) from exc

    engine_counts = None
    match = re.search(
        r"^ENGINE pools male=(\d+) female=(\d+) surnames=(\d+) "
        r"professions=(\d+)$", output, re.M)
    if match:
        engine_counts = {
            label: int(value) for label, value in
            zip(("male", "female", "surnames", "professions"), match.groups())
        }
    if runtime.get("runId") != run_id or runtime.get("county") != name:
        raise Sweep.EvidenceError("%s returned a different run namespace" % name)
    capture = runtime.get("capture")
    if not isinstance(capture, dict):
        raise Sweep.EvidenceError("%s omitted its capture envelope" % name)
    if capture.get("captureFailureCount") != 0:
        raise Sweep.EvidenceError(
            "%s capture readers failed: %s" % (name, capture.get("failures")))
    events = capture.get("events")
    if not isinstance(events, list) or capture.get("eventCount") != len(events):
        raise Sweep.EvidenceError("%s returned an inconsistent event count" % name)
    if capture.get("attemptedEvents", 0) < len(events):
        raise Sweep.EvidenceError("%s returned impossible capture accounting" % name)
    source_actions = capture.get("sourceActions")
    validate_source_capture(source_actions, name)
    coordination_actions = capture.get("coordinationActions")
    validate_coordination_capture(coordination_actions, name, run_id)
    Sweep.validate_result(runtime, owed, engine, engine_counts, joint)

    evidence = runtime["evidence"]
    reached_hours = runtime.get("reachedHours")
    if reached_hours != owed * 24:
        raise Sweep.EvidenceError(
            "%s clock reached %s hours for a %s-hour request" %
            (name, reached_hours, owed * 24))
    return {
        "schema": "sao-decision-run",
        "schemaVersion": 2,
        "run": {
            "id": run_id,
            "captureInvocationId": capture_invocation_id,
            "county": name,
            "engineMode": "engine" if engine else "plain",
            "complete": True,
            "horizon": {
                "requestedDays": owed,
                "requestedHours": owed * 24,
                "reachedDays": runtime["ranTo"],
                "reachedHours": reached_hours,
            },
            "clock": {
                "schema": "sao-county-hours-v1",
                "historyOrigin": identity["historyOrigin"],
                "yearsTicks": runtime["yearsTicks"],
            },
            "random": {
                "seed": evidence.get("seed"),
                "drawCount": evidence.get("drawCount"),
            },
            "settings": {
                "sandbox": evidence.get("sandbox"),
                "refillOverride": refill,
            },
            "schemas": identity["capture"],
            "provenance": identity,
        },
        "outcomeSummary": {
            "alive": runtime["alive"],
            "dead": runtime["dead"],
        },
        "captureAccounting": {
            "attemptedEvents": capture["attemptedEvents"],
            "eventCount": capture["eventCount"],
            "readerFailures": capture["captureFailureCount"],
        },
        "conditioning": {
            "status": "ineligible",
            "reasons": [
                "executable-options-not-captured",
                "choice-not-captured",
            ],
        },
        "events": events,
        "sourceActions": source_actions,
        "coordinationActions": coordination_actions,
    }


def validate_source_capture(capture, name):
    if (not isinstance(capture, dict)
            or capture.get("schema") != "sao-source-decision-capture"
            or capture.get("schemaVersion") != 1
            or capture.get("status") not in {"observed", "unavailable"}
            or capture.get("captureFailureCount") != 0
            or capture.get("failures") not in ([], {})):
        raise Sweep.EvidenceError("%s source-action capture failed or is absent" % name)
    events = capture.get("events")
    if (not isinstance(events, list)
            or capture.get("eventCount") != len(events)
            or capture.get("attemptedEvents") != len(events)
            or (capture["status"] == "unavailable" and events)):
        raise Sweep.EvidenceError("%s source-action accounting is inconsistent" % name)


def validate_coordination_capture(capture, name, expected_run_id=None):
    if (not isinstance(capture, dict)
            or capture.get("schema") != "sao-coordination-decision-capture"
            or capture.get("schemaVersion") != 1
            or capture.get("status") not in {"observed", "unavailable"}
            or capture.get("captureFailureCount") != 0
            or capture.get("failures") not in ([], {})):
        raise Sweep.EvidenceError(
            "%s coordination capture failed or is absent" % name)
    events = capture.get("events")
    attempted = capture.get("attemptedEvents")
    if (not isinstance(events, list) or not isinstance(attempted, int)
            or capture.get("eventCount") != len(events)
            or attempted < len(events)
            or (capture["status"] == "unavailable"
                and (events or attempted != 0))):
        raise Sweep.EvidenceError(
            "%s coordination capture accounting is inconsistent" % name)
    namespaces = set()
    fields = ("runId", "county", "personId", "eventId", "hour")
    for index, row in enumerate(events, 1):
        where = "%s coordination row %d" % (name, index)
        namespace = row.get("namespace") if isinstance(row, dict) else None
        if (not isinstance(row, dict)
                or row.get("schema") != "speakeasy-decision-row"
                or row.get("schemaVersion") != 3
                or not isinstance(namespace, dict)
                or set(namespace) != set(fields)):
            raise Sweep.EvidenceError("%s is not a full v3 decision row" % where)
        if (not all(isinstance(namespace[field], str) and namespace[field]
                    for field in fields[:-1])
                or not isinstance(namespace["hour"], (int, float))
                or isinstance(namespace["hour"], bool)
                or not math.isfinite(namespace["hour"])):
            raise Sweep.EvidenceError("%s has an invalid namespace" % where)
        key = tuple(namespace[field] for field in fields)
        if key in namespaces:
            raise Sweep.EvidenceError("%s repeats a full namespace" % where)
        namespaces.add(key)
        if ((expected_run_id and namespace["runId"] != expected_run_id)
                or namespace["county"] != name
                or not isinstance(row.get("person"), dict)
                or row["person"].get("id") != namespace["personId"]
                or not isinstance(row.get("situation"), dict)
                or row["situation"].get("county") != name
                or row["situation"].get("hour") != namespace["hour"]):
            raise Sweep.EvidenceError("%s differs from its namespace" % where)
        options = row.get("options")
        if not isinstance(options, list) or not options \
                or not all(isinstance(item, dict) for item in options):
            raise Sweep.EvidenceError("%s has no executable options" % where)
        option_ids = {item.get("id") for item in options}
        if (len(option_ids) != len(options) or None in option_ids
                or any(item.get("owner") != "SAO.Organization.respond"
                       or not isinstance(item.get("parameters"), dict)
                       or not isinstance(item.get("eligibility"), dict)
                       or item["eligibility"].get("status") != "eligible"
                       or not item["eligibility"].get("evidence")
                       for item in options)
                or not isinstance(row.get("choice"), dict)
                or row["choice"].get("optionId") not in option_ids):
            raise Sweep.EvidenceError("%s has invalid executable options" % where)
        conditioning = row.get("conditioning")
        evidence = row.get("enactedProcess")
        if (not isinstance(conditioning, dict)
                or conditioning.get("status") != "ineligible"
                or conditioning.get("decisionHour") != namespace["hour"]
                or not conditioning.get("exclusions")
                or not isinstance(evidence, dict) or evidence.get("schema") != 1
                or evidence.get("actorId") != namespace["personId"]
                or not isinstance(evidence.get("decisionTime"), dict)
                or evidence["decisionTime"].get("asOfHour") != namespace["hour"]
                or not isinstance(evidence.get("laterOutcome"), dict)):
            raise Sweep.EvidenceError(
                "%s mixes its decision and outcome horizons" % where)


def publish(base, runs):
    base.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M%SZ", time.gmtime())
    destination = base / stamp
    suffix = 1
    while destination.exists():
        destination = base / (stamp + "-%d" % suffix)
        suffix += 1
    staging = pathlib.Path(tempfile.mkdtemp(prefix=".decision-dump-", dir=base))
    try:
        files = {}
        for run in sorted(runs, key=lambda item: item["run"]["county"]):
            name = run["run"]["county"] + ".json"
            path = staging / name
            path.write_text(
                json.dumps(run, indent=2, sort_keys=True) + "\n", encoding="utf-8")
            files[name] = Sweep.sha256(path)
            coordination = run.get("coordinationActions", {}).get("events", [])
            if coordination:
                coordination_name = run["run"]["county"] + ".coordination.jsonl"
                coordination_path = staging / coordination_name
                coordination_path.write_text("".join(
                    json.dumps(row, ensure_ascii=False, sort_keys=True,
                               separators=(",", ":")) + "\n"
                    for row in coordination), encoding="utf-8", newline="\n")
                files[coordination_name] = Sweep.sha256(coordination_path)
        manifest = {
            "schema": "sao-decision-dump-manifest",
            "schemaVersion": 1,
            "complete": True,
            "runCount": len(runs),
            "runIds": [run["run"]["id"] for run in
                       sorted(runs, key=lambda item: item["run"]["county"])],
            "captureInvocationIds": sorted({
                run["run"]["captureInvocationId"] for run in runs
            }),
            "coordinationRowCount": sum(len(
                run.get("coordinationActions", {}).get("events", []))
                for run in runs),
            "files": files,
        }
        (staging / "manifest.json").write_text(
            json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        os.replace(staging, destination)
    except BaseException:
        shutil.rmtree(staging, ignore_errors=True)
        raise
    return destination


def prepare_world_cache():
    newest = 0
    maps = Sweep.World.maps_dir(Sweep.GAME)
    if maps.is_dir():
        for directory in maps.iterdir():
            spawnpoints = directory / "spawnpoints.lua"
            if spawnpoints.is_file():
                newest = max(newest, spawnpoints.stat().st_mtime)
    present = (Sweep.CACHE / "map.lua").exists() \
        and (Sweep.CACHE / "regions.lua").exists()
    if present and (Sweep.CACHE / "map.lua").stat().st_mtime >= newest:
        print("  world cached at %s" % Sweep.CACHE)
        return True
    print("  reading the shipped world ...")
    built = Sweep.World.build(Sweep.GAME, Sweep.CACHE)
    if not built:
        print("  no shipped maps found under %s" % maps)
        return False
    print("  %d towns, %d spawn points, %d buildings" %
          (built["towns"], built["points"], built["buildings"]))
    return True


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--runs", type=int, default=12)
    parser.add_argument("--days", type=int, default=1096,
                        help="days the county owes at genesis")
    parser.add_argument("--refill", default=None,
                        help="RefillDays through the sandbox, not source code")
    parser.add_argument("--lua", default=None,
                        help="another tree's Lua root for a before/after run")
    parser.add_argument("--workers", type=int, default=6)
    parser.add_argument("--timeout", type=int, default=3600,
                        help="per-county process timeout in seconds")
    parser.add_argument("--out", default=None,
                        help="publication parent; defaults beside the sweep cache")
    parser.add_argument("--engine", action="store_true",
                        help="load real engine name and profession registries")
    parser.add_argument("--joint", action="store_true",
                        help="run the combined SAO+ZAO dormant simulation")
    args = parser.parse_args(argv)

    print("=" * 74)
    print("COUNTY DUMP - immutable decision evidence")
    print("=" * 74)
    if args.runs <= 0 or args.days <= 0 or args.workers <= 0 or args.timeout <= 0:
        print("  FAILED - runs, days, workers and timeout must all be positive")
        return 1
    required = (Sweep.JDK, Sweep.PZ, Sweep.STDLIB, Sweep.SRC, Sweep.GAME,
                CAPTURE_LUA, EVIDENCE_LUA)
    if not all(path.exists() for path in required):
        print("  FAILED - installed game, JDK, runner or capture source is absent")
        print("  No decision data was produced.")
        return 1
    if args.engine and not Sweep.SAO_JAR.exists():
        print("  FAILED - engine mode requires the built mod jar at %s" % Sweep.SAO_JAR)
        return 1
    if args.engine and not Sweep.ENGINE_FILL_LUA.exists():
        print("  FAILED - engine registry loader is absent at %s" %
              Sweep.ENGINE_FILL_LUA)
        return 1

    lua = pathlib.Path(args.lua).resolve() if args.lua \
        else Sweep.ROOT / "mod" / "42.20" / "media" / "lua"
    if not lua.is_dir():
        print("  FAILED - no Lua tree at %s" % lua)
        return 1
    try:
        paths = Sweep.require_modules(lua, args.joint)
    except Sweep.EvidenceError as exc:
        print("  FAILED - %s" % exc)
        return 1
    print("  %d shipped modules form each county" % len(paths))
    print("  loaded claim surveys are unavailable; no ground is fabricated")
    if not prepare_world_cache():
        return 1
    if not Sweep.build_runner():
        print("  FAILED - LuaRun will not compile against the installed jar")
        return 1

    base = pathlib.Path(args.out).resolve() if args.out \
        else pathlib.Path(tempfile.gettempdir()) / "sao-decision-dump"
    modes = []
    if args.engine:
        modes.append("engine data on")
    if args.joint:
        modes.append("joint pathogen on")
    suffix = "; " + ", ".join(modes) if modes else ""
    print("  %d counties, %d requested days; publication withheld until all pass%s"
          % (args.runs, args.days, suffix))
    print()

    completed, failures = [], []
    capture_invocation_id = uuid.uuid4().hex
    print("  capture invocation %s" % capture_invocation_id)
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = {
            pool.submit(one, "County%03d" % index, lua, paths, args.days,
                        args.refill, args.engine, args.timeout,
                        capture_invocation_id, args.joint): index
            for index in range(args.runs)
        }
        for future in concurrent.futures.as_completed(futures):
            index = futures[future]
            try:
                run = future.result()
            except (Sweep.EvidenceError, OSError, ValueError, KeyError,
                    TypeError, subprocess.SubprocessError) as exc:
                failures.append((index, str(exc)))
                print("  run %-3d REJECTED: %s" % (index, exc))
                continue
            completed.append(run)
            events = run["captureAccounting"]["eventCount"]
            coordination = run["coordinationActions"]["eventCount"]
            biggest = max(
                [event["decision"]["size"] for event in run["events"]] or [0])
            print("  run %-3d complete: alive=%-4d elections=%-4d coordination=%-4d"
                  " biggest roster=%d" %
                  (index, run["outcomeSummary"]["alive"], events,
                   coordination, biggest))

    if failures or len(completed) != args.runs:
        print()
        print("  REJECTED - %d/%d counties completed; no dump was published"
              % (len(completed), args.runs))
        return 1
    run_ids = [run["run"]["id"] for run in completed]
    event_ids = [event["eventId"] for run in completed for event in run["events"]]
    coordination_keys = [tuple(event["namespace"][field] for field in
                               ("runId", "county", "personId", "eventId", "hour"))
                         for run in completed
                         for event in run["coordinationActions"]["events"]]
    if (len(set(run_ids)) != len(run_ids)
            or len(set(event_ids)) != len(event_ids)
            or len(set(coordination_keys)) != len(coordination_keys)):
        print("  REJECTED - run or event namespaces collided; no dump was published")
        return 1

    try:
        destination = publish(base, completed)
    except OSError as exc:
        print("  REJECTED - atomic publication failed: %s" % exc)
        return 1
    moments = len(event_ids)
    coordination_moments = len(coordination_keys)
    members = sum(event["decision"]["size"]
                  for run in completed for event in run["events"])
    print()
    print("  %d counties completed; %d legacy decision moments, %d member views;"
          " %d enacted coordination decisions"
          % (len(completed), moments, members, coordination_moments))
    print("  published atomically at %s" % destination)
    print("  coordination rows retain executable options and the actual response;")
    print("  independent review and learned-runtime integration remain excluded")
    return 0


if __name__ == "__main__":
    sys.exit(main())
