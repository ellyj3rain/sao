#!/usr/bin/env python3
"""Initial personal awareness: authored world -> real Admissions -> private owner.

Installed Kahlua serialization and owner reload; native identity creation,
history, placement and the Perception delivery callback are controlled. This
does not establish rendered behavior, source truth or completed learning.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

import flee_continuity_test as fixture
import world_lab as Lab
from native_proof_preflight import installed_presence

ROOT = Path(__file__).resolve().parents[1]
FILES = {
    "admissions": ROOT / "mod/42.20/media/lua/client/SAO_PopulationAdmissions.lua",
    "awareness": ROOT / "mod/42.20/media/lua/shared/SAO_PersonalAwareness.lua",
    "knowledge": ROOT / "mod/42.20/media/lua/shared/SAO_Knowledge.lua",
    "study": ROOT / "tools/world_lab/StudyWorld.lua",
    "cases": ROOT / "tools/initial_awareness_admission_cases.lua",
}
PROBE = ROOT / "tools/luacheck/PhysicalMeansLuaProbe.java"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def definition_cases():
    value = Lab.load(ROOT / "tools/world_lab/definition.example.json")
    value["sandbox"].update({"SurvivorAwareness.Population": 3, "SurvivorAwareness.Newcomers": 3})
    value["observation"]["sites"] = [
        dict(id="home", label="Home", x=128, y=128, z=0),
        dict(id="other", label="Other", x=384, y=128, z=0)]
    report = dict(id="radio-before-genesis", kind="outbreak", affirmed=True, sourceId="local-radio",
                  sourceAtHours=1, receivedAtHours=1.5, certainty="reported")
    value["situation"] = dict(initialPeopleBySite={"home": 2, "other": 1}, initialAwareness=[
        dict(siteId="home", actorOrdinal=1, entries=[]),
        dict(siteId="home", actorOrdinal=2, entries=[report])])
    results = []

    def accepted(name, candidate):
        before = copy.deepcopy(candidate)
        Lab.validate(candidate)
        assert candidate == before, "full validation mutated definition"
        results.append({"name": name, "result": "accepted"})

    accepted("explicit-empty-and-personal-report", value)
    omitted = copy.deepcopy(value); del omitted["situation"]["initialAwareness"]
    accepted("omitted-awareness-remains-legacy", omitted)
    negative = copy.deepcopy(value)
    negative["situation"]["initialAwareness"][1]["entries"][0]["affirmed"] = False
    accepted("contrary-personal-report", negative)
    mutations = {
        "missing-initial-people": lambda v: v["situation"].pop("initialPeopleBySite"),
        "empty-person-bindings": lambda v: v["situation"].update(initialAwareness=[]),
        "foreign-site": lambda v: v["situation"]["initialAwareness"][0].update(siteId="foreign"),
        "wrong-ordinal": lambda v: v["situation"]["initialAwareness"][0].update(actorOrdinal=3),
        "boolean-ordinal": lambda v: v["situation"]["initialAwareness"][0].update(actorOrdinal=True),
        "duplicate-person": lambda v: v["situation"]["initialAwareness"].append(copy.deepcopy(v["situation"]["initialAwareness"][0])),
        "foreign-person-id": lambda v: v["situation"]["initialAwareness"][0].update(personId="unrelated"),
        "object-instead-of-entries": lambda v: v["situation"]["initialAwareness"][0].update(entries={}),
        "duplicate-entry": lambda v: v["situation"]["initialAwareness"][1]["entries"].append(copy.deepcopy(report)),
        "too-many-entries": lambda v: v["situation"]["initialAwareness"][1].update(entries=[dict(report, id=f"row-{i}") for i in range(9)]),
    }
    entry_mutations = {
        "unsupported-kind": {"kind": "known-hostile-target"}, "nonboolean-claim": {"affirmed": 1},
        "invented-certainty": {"certainty": "certain"}, "empty-source": {"sourceId": ""},
        "control-source": {"sourceId": "radio\nother"}, "long-source": {"sourceId": "a" * 129},
        "source-after-reception": {"sourceAtHours": 2}, "negative-source-time": {"sourceAtHours": -1},
        "boolean-time": {"receivedAtHours": True}, "nan-time": {"receivedAtHours": float("nan")},
        "infinite-time": {"receivedAtHours": float("inf")}, "undeclared-target": {"targetId": "zombie-1"},
    }
    for name, fields in entry_mutations.items():
        mutations[name] = lambda v, fields=fields: v["situation"]["initialAwareness"][1]["entries"][0].update(fields)
    for name, mutate in mutations.items():
        candidate = copy.deepcopy(value); mutate(candidate)
        try:
            Lab.validate(candidate)
        except (ValueError, TypeError) as error:
            results.append({"name": name, "result": "refused", "reason": str(error)})
        else:
            raise AssertionError("full world validator admitted " + name)
    return results


def run(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "_scratch/d1-shared-reasoning/initial-awareness/admission-proof")
    parser.add_argument("--baseline-only", action="store_true")
    parser.add_argument("--variants", nargs="+")
    args = parser.parse_args(argv); out = args.output.resolve(); out.mkdir(parents=True, exist_ok=True)
    jar = fixture.GAME / "projectzomboid.jar"
    paths = list(dict.fromkeys([*FILES.values(), Path(__file__), PROBE, Path(fixture.__file__),
        ROOT / "tools/education_background_admission_cases.lua", ROOT / "tools/world_lab.py",
        ROOT / "tools/world_lab_definition.py", ROOT / "tools/world_lab/definition.example.json",
        jar, fixture.GAME / "stdlib.lua"]))
    paths.append(Path(__file__).with_name('native_proof_preflight.py'))
    preflight = installed_presence(paths, fixture.GAME, fixture.JDK, "initial awareness admission")
    if preflight is not None:
        raise SystemExit(preflight)
    pins = lambda: {str(path): digest(path) for path in paths}
    receipt = {"schema": "sao.initial-awareness-admission-proof/1", "status": "INCOMPLETE",
               "boundary": __doc__, "inputs": pins(), "runs": []}

    def save():
        (out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")

    def invoke(name, command, marker=None):
        process = subprocess.run(list(map(str, command)), cwd=out, capture_output=True, text=True, timeout=90)
        log = process.stdout + process.stderr
        (out / (name + ".log")).write_text(log, encoding="utf-8")
        receipt["runs"].append({"name": name, "command": list(map(str, command)), "cwd": str(out),
            "exit": process.returncode, "expectedFailure": marker, "logSha256": hashlib.sha256(log.encode()).hexdigest()})
        save(); return process.returncode, log

    save()
    try:
        receipt["definitionCases"] = definition_cases(); save()
        classes = out / "classes"; classes.mkdir(exist_ok=True)
        code, log = invoke("compile", [fixture.JDK / "javac.exe", "-cp", jar, "-d", classes, PROBE])
        assert code == 0, log
        shutil.copy2(fixture.GAME / "stdlib.lua", out / "stdlib.lua")
        sources = {key: path.read_text(encoding="utf-8") for key, path in FILES.items()}
        variants = [("production", None, None, None, None)]
        if not args.baseline_only:
            variants += [
                ("future-admission", "admissions", "or entry.receivedAtHours > now then return false end",
                 "then return false end", "future-reception-refused"),
                ("wrong-ordinal", "admissions", "row.actorOrdinal == ordinal", "row.actorOrdinal == 1",
                 "ordinal-ledger-not-name-order"),
                ("late-genesis", "admissions", 'for _ in pairs(SAO.Identity.all()) do return false, "initial-awareness-staged-after-genesis" end',
                 "-- late initial awareness admitted", "late-genesis-awareness-refused"),
                ("attachment-omitted", "admissions", "    if awarenessProviderBound then\n", "    if false then\n",
                 "ordinal-ledger-not-name-order"),
                ("study-staging-omitted", "study", "local awareness = Config.situation and Config.situation.initialAwareness",
                 "local awareness = nil", "actual-study-start-stages-awareness"),
                ("world-binding-omitted", "admissions",
                 "function A.stageInitialAwareness(definitionSha256, saveName, rows)\n    local store, why = educationWorld(definitionSha256, saveName)",
                 'function A.stageInitialAwareness(definitionSha256, saveName, rows)\n    local store, why = ModData.getOrCreate("SurvivorAwareness_Standing"), nil',
                 "wrong-world-refused"),
                ("missing-ledger-treated-as-omission", "admissions",
                 "    if origin and (not ordinal or not cohortCounts(initialCohort)) then return {} end",
                 "    -- invalid ledger treated as omission", "missing-preinitial-ledger-is-unavailable"),
                ("query-creates-source-store", "admissions",
                 '    local store = ModData.get("SurvivorAwareness_Standing")',
                 '    local store = ModData.getOrCreate("SurvivorAwareness_Standing")',
                 "missing-source-query-does-not-create-store"),
            ]
        if args.variants:
            allowed = {row[0] for row in variants}
            assert set(args.variants) <= allowed, "unknown variant"
            variants = [row for row in variants if row[0] in args.variants]
        for name, key, before, after, marker in variants:
            current = dict(sources)
            if key:
                assert current[key].count(before) == 1, (name, "mutation anchor", current[key].count(before))
                current[key] = current[key].replace(before, after, 1)
            directory = out / name; directory.mkdir(exist_ok=True)
            owners = "function __loadOwners()\n"
            for part in ("awareness", "admissions", "knowledge"):
                owners += "local function load_" + part + "()\n" + current[part] + "\nend\nload_" + part + "()\n"
            owners += "end\nfunction __loadStudy(Config)\n" + current["study"] + "\nend\n"
            (directory / "owners.lua").write_text(owners, encoding="utf-8")
            (directory / "cases.lua").write_text(current["cases"], encoding="utf-8")
            command = [fixture.JDK / "java.exe", "-cp", os.pathsep.join([str(jar), str(classes)]),
                       "PhysicalMeansLuaProbe", directory / "owners.lua", directory / "cases.lua", "--", "__result"]
            code, log = invoke(name, command, marker)
            if marker:
                assert code != 0 and "INITIAL_AWARENESS:" + marker in log, (name, log)
            else:
                assert code == 0 and "VALUE PASS initial awareness admission " in log, (name, log)
            print(name + ": " + log.strip().splitlines()[-1], flush=True)
        receipt["inputsAfter"] = pins()
        assert receipt["inputsAfter"] == receipt["inputs"], "source inputs changed during proof"
        receipt["status"] = "PASS"; save()
    except Exception as error:
        receipt["status"] = "FAIL"; receipt["error"] = str(error); save(); raise
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(run())
    except Exception as error:
        print("FAIL initial awareness admission: " + str(error), file=sys.stderr)
        raise SystemExit(1)
