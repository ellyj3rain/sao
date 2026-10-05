#!/usr/bin/env python3
"""Selected-person conflict projection in the installed Kahlua VM.

Production Observation is exercised through its public capture/selection path.
Controlled private appraisal records establish projection and omission behavior;
this does not establish native combat, learned competence, or loaded UI delivery.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import subprocess
import tempfile

import observation_test as inherited

ROOT = Path(__file__).resolve().parents[1]
LUA = ROOT / "mod/42.20/media/lua/client"
MODULE = LUA / "SAO_Observation.lua"
CASES = ROOT / "tools/conflict_observation_cases.lua"
JOIN_CASES = ROOT / "tools/conflict_observation_join_cases.lua"
PLANNING = ROOT / "mod/42.20/media/lua/shared/SAO_ProceduralPlanning.lua"
GAME = Path(os.environ.get("PZ_DIR", str(inherited.GAME)))
JDK = Path(os.environ.get("JDK_BIN", str(inherited.JDK)))


def fingerprint(path):
    return {"path": str(path.resolve()), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def controls():
    return [
        ("private-belief-source", 'conflictText(threat.source, "acquisition source unavailable")',
         '"observed"', "private-belief-source"),
        ("intent-not-execution", '"No native attempt admission recorded"',
         '"Native attempt executing"', "intent-is-intent"),
        ("reason-not-score", 'conflictText(view.reason, "No rationale recorded")',
         'tostring(view.score or 0)', "reason-not-score"),
        ("completion-not-clearance", '"Requires fresh perception; the attempt result does not establish that the threat is gone"',
         '"The threat is gone"', "completion-is-attempt"),
        ("foreign-person", 'or view.actorId ~= id', '', "reject-foreign-person"),
        ("alternative-bound", 'for index = 1, 4 do\n        local alternative',
         'for index = 1, 5 do\n        local alternative', "bounded-alternatives"),
        ("getter-failure-is-local", 'local ok, view = pcall(getter, id)',
         'local ok, view = true, getter(id)', "capture-available"),
        ("effect-uncertainty", 'effect.status == "possible" and "possible" or "unresolved"',
         'effect.status == "possible" and "possible" or effect.status', "unknown-effect-remains-uncertain"),
    ]


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--receipt", type=Path)
    parser.add_argument("--baseline-only", action="store_true")
    parser.add_argument("--join-only", action="store_true",
                        help="Refresh only the actual Planning-to-Observation join after a producer change.")
    args = parser.parse_args(argv)
    runner = ROOT / "tools/luacheck/LuaRun.java"
    names = ["SAO_Observation.lua", "SAO_Locomotion.lua", "SAO_Voice.lua", "SAO_Inspect.lua"]
    paths = [LUA / name for name in names] + [CASES, JOIN_CASES, PLANNING,
                                            Path(__file__), Path(inherited.__file__), runner]
    before = [fingerprint(p) for p in paths]
    receipt = {"schema": "sao-conflict-observation-proof/1", "status": "failed", "inputs": before,
               "boundary": __doc__.strip(), "baselineOnly": args.baseline_only,
               "joinOnly": args.join_only, "checks": {}, "controls": []}
    engine = GAME / "projectzomboid.jar"
    missing = [str(p) for p in [engine, JDK / "java.exe", JDK / "javac.exe"] if not p.is_file()]
    if missing:
        receipt.update(status="skipped", missingPrerequisites=missing)
        if args.receipt:
            args.receipt.parent.mkdir(parents=True, exist_ok=True)
            args.receipt.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
        print("SKIPPED: installed Kahlua/JDK unavailable")
        return 0
    receipt["engine"] = fingerprint(engine)
    sources = {name: (LUA / name).read_text(encoding="utf-8") for name in names}
    proof = CASES.read_text(encoding="utf-8")
    joined_proof = JOIN_CASES.read_text(encoding="utf-8")
    planning_source = PLANNING.read_text(encoding="utf-8")
    output_dir = args.receipt.resolve().parent if args.receipt else None
    if output_dir:
        output_dir.mkdir(parents=True, exist_ok=True)
    try:
        with tempfile.TemporaryDirectory(prefix="sao-conflict-observation-") as folder:
            temp = Path(folder)
            build = subprocess.run([str(JDK / "javac.exe"), "-encoding", "UTF-8", "-cp", str(engine),
                                    "-d", str(temp), str(runner)], capture_output=True, text=True, timeout=90)
            receipt["compileExitCode"] = build.returncode
            if output_dir:
                (output_dir / "compile.log").write_text(build.stdout + build.stderr, encoding="utf-8")
            assert build.returncode == 0, build.stdout + build.stderr
            (temp / "prelude.lua").write_text(inherited.PRELUDE, encoding="utf-8")
            (temp / "SAO_ProceduralPlanning.lua").write_text(planning_source, encoding="utf-8")

            def run(label, source, probe, joined=False):
                for name in names:
                    (temp / name).write_text(source if name == "SAO_Observation.lua" else sources[name], encoding="utf-8")
                (temp / "probe.lua").write_text("__result = " + probe, encoding="utf-8")
                planning_chunk = [str(temp / "SAO_ProceduralPlanning.lua")] if joined else []
                result = subprocess.run([str(JDK / "java.exe"), "-cp", str(temp) + os.pathsep + str(engine),
                    "LuaRun", str(temp / "prelude.lua"), *planning_chunk, *[str(temp / n) for n in names], str(temp / "probe.lua"),
                    "--", "__result"], cwd=GAME, capture_output=True, text=True, timeout=45)
                output = result.stdout + result.stderr
                if output_dir:
                    log = output_dir / (label + ".log")
                    log.write_text(output, encoding="utf-8")
                return result.returncode, output

            for label, probe, marker in [("conflict", proof, "CONFLICT_OBSERVATION_PASS"),
                                          ("actual-planning-join", joined_proof, "CONFLICT_OBSERVATION_JOIN_PASS"),
                                          ("existing-observation", inherited.PROBE, "OBSERVATION_PASS"),
                                          ("default-observation", inherited.DEFAULT_PROBE, "DEFAULT_OBSERVATION_PASS")]:
                if args.join_only and label != "actual-planning-join":
                    continue
                code, output = run(label, sources["SAO_Observation.lua"], probe, joined=label == "actual-planning-join")
                match = re.search(marker + r" (\d+) checks", output)
                assert code == 0 and match, label + ": " + output
                receipt["checks"][label] = {"exitCode": code, "count": int(match[1])}
                print(output.strip(), flush=True)
            if not args.baseline_only and not args.join_only:
                for label, old, new, expected in controls():
                    source = sources["SAO_Observation.lua"]
                    assert source.count(old) == 1, "control seam changed: " + label
                    code, output = run("control-" + label, source.replace(old, new), proof)
                    assert code != 0 and "CONFLICT_OBSERVATION_CHECK:" + expected in output, label + ": " + output
                    receipt["controls"].append({"name": label, "status": "detected", "exitCode": code, "expected": expected})
                    print("CONTROL_PASS " + label, flush=True)
        after = [fingerprint(p) for p in paths]
        receipt["changedInputs"] = [a["path"] for a, b in zip(before, after) if a != b]
        assert not receipt["changedInputs"], "proof inputs changed during execution"
        receipt["status"] = "passed"
        return 0
    except Exception as error:
        receipt["failure"] = str(error)
        print("FAILED: " + str(error), flush=True)
        return 1
    finally:
        if args.receipt:
            args.receipt.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
