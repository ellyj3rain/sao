#!/usr/bin/env python3
"""Scoped typed-array observation export and package-bound historical decoding."""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

import world_lab as Lab
from native_proof_preflight import installed_presence

ROOT = Lab.ROOT
GAME = Path(os.environ.get("PZ_DIR", r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"))
JDK = Path(os.environ.get("JDK_BIN", str(Path.home() / "Peanut Butter/JetBrains/Java/bin")))
JAVA = ("StudyExport.java", "StudyObserver.java", "StudyViewCapture.java", "StudyVideoCapture.java", "ObservationArraysProbe.java")


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def run(out):
    out.mkdir(parents=True, exist_ok=False)
    inputs = [Path(__file__).resolve(), ROOT / "tools/world_lab.py", ROOT / "tools/world_lab_definition.py",
              ROOT / "tools/world_lab/StudyWorld.lua", ROOT / "tools/world_lab/ObservationArraysChecks.lua",
              ROOT / "tools/world_lab/definition.example.json", ROOT / "tools/world_lab/authored_map.py",
              GAME / "projectzomboid.jar", GAME / "ZombieBuddy.jar", JDK / "javac.exe", GAME / "jre64/bin/java.exe"]
    inputs += [ROOT / "tools/world_lab" / name for name in JAVA]
    inputs.append(Path(__file__).with_name('native_proof_preflight.py'))
    preflight = installed_presence(inputs, GAME, JDK, "world lab observation arrays")
    if preflight is not None:
        raise SystemExit(preflight)
    receipt = {"schema": "sao-observation-arrays-proof/1", "status": "INCOMPLETE", "checks": [], "controls": [],
               "inputsBefore": {str(path): digest(path) for path in inputs}, "commands": []}

    def retain():
        (out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")

    def check(value, name):
        Lab.require(value, name)
        receipt["checks"].append(name)
        print("PASS", name, flush=True)

    def command(argv, label, expected=0):
        completed = subprocess.run(list(map(str, argv)), cwd=GAME, text=True, encoding="utf-8",
                                   errors="replace", capture_output=True, timeout=90)
        stdout, stderr = out / (label + ".stdout.log"), out / (label + ".stderr.log")
        stdout.write_bytes(completed.stdout.encode("utf-8"))
        stderr.write_bytes(completed.stderr.encode("utf-8"))
        receipt["commands"].append({"command": list(map(str, argv)), "cwd": str(GAME), "exitCode": completed.returncode,
                                    "stdout": str(stdout), "stdoutSha256": digest(stdout),
                                    "stderr": str(stderr), "stderrSha256": digest(stderr)})
        retain()
        Lab.require(completed.returncode == expected, label + " failed: " + completed.stdout[-2500:] + completed.stderr[-2500:])
        return completed.stdout

    retain()
    try:
        definition = Lab.load(ROOT / "tools/world_lab/definition.example.json")
        definition["id"] = "awareness-array-proof"
        definition["sandbox"]["SurvivorAwareness.Population"] = 2
        definition["sandbox"]["SurvivorAwareness.Newcomers"] = 2
        definition["observation"]["windows"] = [{"id": "home", "x": 128, "y": 128, "z": 0, "width": 1, "height": 1}]
        definition["observation"]["sites"] = [{"id": "home", "label": "Home", "x": 128, "y": 128, "z": 0}]
        report = {"id": "report-1", "kind": "outbreak", "affirmed": True, "sourceId": "fixture-radio",
                  "sourceAtHours": 1, "receivedAtHours": 1, "certainty": "reported"}
        definition["situation"] = {"initialPeopleBySite": {"home": 2}, "initialAwareness": [
            {"siteId": "home", "actorOrdinal": 1, "entries": []},
            {"siteId": "home", "actorOrdinal": 2, "entries": [report]}]}
        definition["sandbox"].update(StartMonth=1, StartDay=1)
        definition["situation"]["initialLifeHistory"] = [
            dict(siteId="home", actorOrdinal=1, startDate="1993-01-01", birthYear=1960, episodes=[]),
            dict(siteId="home", actorOrdinal=2, startDate="1993-01-01", birthYear=1965, episodes=[
                dict(id="prior-movie", occurredOn="1992-06-01", acquiredOn="1992-06-01", participants=[],
                     subject="cinema", action="watched", description="A prior shared movie night. café 🎬",
                     valence=.5, salience=.6, sourceId="authored-movie", sourceSha256="a" * 64,
                     provenance="authored-synthetic", relations=[])])]
        package = out / "package"
        manifest = Lab.build(definition, package, GAME)
        verified = Lab.verify_package(package)
        receipt["packageSha256"] = Lab.seal(manifest)
        runtime_path = next(package.glob("mod/*/42.20/media/lua/client/*.lua"))
        header, source = runtime_path.read_text(encoding="utf-8").split("\n", 1)
        fixture = (ROOT / "tools/world_lab/ObservationArraysChecks.lua").read_text(encoding="utf-8")
        classes = out / "classes"; classes.mkdir()
        classpath = os.pathsep.join(map(str, (GAME / "projectzomboid.jar", GAME / "ZombieBuddy.jar", classes)))
        command([JDK / "javac.exe", "-encoding", "UTF-8", "-cp", classpath, "-d", classes,
                 *[ROOT / "tools/world_lab" / name for name in JAVA]], "compile")

        def native(runtime, label):
            lane = out / label; lane.mkdir()
            script = lane / "checks.lua"
            script.write_text(header + "\n" + fixture + "\nlocal Study=(function()\n" + runtime
                              + "\nend)()\nRunArrayChecks(Study)\n", encoding="utf-8")
            cache = lane / "cache"; cache.mkdir()
            text = command([GAME / "jre64/bin/java.exe", "-Djava.awt.headless=true", "-cp", classpath,
                            "ObservationArraysProbe", script, cache], label)
            native_path = Path(next(row.removeprefix("NATIVE_FILE ") for row in text.splitlines() if row.startswith("NATIVE_FILE ")))
            fallback = Lab.load(cache / "fallback.json")
            actual = Lab.load(native_path)
            receipt.setdefault("nativeArtifacts", []).append({"label": label, "native": str(native_path),
                "nativeSha256": digest(native_path), "fallback": str(cache / "fallback.json"),
                "fallbackSha256": digest(cache / "fallback.json"), "scriptSha256": digest(script)})
            return fallback, actual, native_path

        fallback, frame, native_path = native(source, "production")
        for label, candidate in (("fallback", fallback), ("native", frame)):
            check(candidate["situation"] == definition["situation"], label + " preserves empty and populated awareness arrays")
            Lab.validate_frame(candidate, verified[1]["origins"]); Lab.bind_frame(candidate, verified)
            check(True, label + " actual observer frame validates and binds")
            state = candidate['people'][0]['context']['personState']
            check(state['actorId'] == 'array-person', label + ' person state retains exact current owner')
            episode = state['modelView']['recall']['episodes'][0]
            question = state['modelView']['situation']['questions'][0]
            inference = question['conceptualEvidence']['conditionalHarm']
            lists = [episode['participants'], episode['relations'], question['evidence'], question['anticipated'],
                     question['revisions'][0]['evidence'], question['revisions'][0]['observations']]
            lists += [inference[key] for key in ('paths','contradictions','missing','parentIds','evidenceIds','roots')]
            check(all(value == [] for value in lists), label + ' nested person-state lists preserve empty arrays')
            frozen = candidate['people'][0]['context']['cognition']['episodes'][0]['decisionPersonState']
            check(frozen['actorId'] == 'array-person' and frozen['decisionId'] == 'decision/1'
                  and frozen['atHours'] == 2 and frozen['atTick'] == 120,
                  label + ' frozen decision state retains exact decision owner and clock')
            frozen_view = frozen['personState']['modelView']
            frozen_question = frozen_view['situation']['questions'][0]
            frozen_lists = [frozen_view['recall']['episodes'][0]['participants'],
                            frozen_view['recall']['episodes'][0]['relations'], frozen_question['evidence'],
                            frozen_question['anticipated'], frozen_question['revisions'][0]['evidence'],
                            frozen_question['revisions'][0]['observations']]
            frozen_lists += [frozen_question['conceptualEvidence']['conditionalHarm'][key]
                             for key in ('paths','contradictions','missing','parentIds','evidenceIds','roots')]
            check(all(value == [] for value in frozen_lists), label + ' frozen decision lists preserve empty arrays')
        check(frame == fallback, "both real serializers preserve identical complete frame semantics")
        evidence_marker = 'or key=="evidence" or key=="revisions" or key=="observations"'
        Lab.require(source.count(evidence_marker) == 1, 'person evidence array seam differs')
        bad_person_fallback, bad_person_native, _ = native(source.replace(evidence_marker, ''), 'missing-person-evidence-marker')
        for label, candidate in (('fallback', bad_person_fallback), ('native', bad_person_native)):
            question = candidate['people'][0]['context']['personState']['modelView']['situation']['questions'][0]
            check(question['evidence'] == {}, label + ' omitted person marker reproduces empty-object defect')
            frozen = candidate['people'][0]['context']['cognition']['episodes'][0]['decisionPersonState']['personState']
            check(frozen['modelView']['situation']['questions'][0]['evidence'] == {},
                  label + ' omitted marker reproduces frozen decision empty-object defect')
        receipt['controls'].append('missing person evidence marker caught through both actual serializers')
        budget_marker = 'local trial={left=math.min(512*1024,budget.bytes)-32}'
        Lab.require(source.count(budget_marker) == 1, 'person-state byte budget seam differs')
        small_fallback, small_native, _ = native(source.replace(budget_marker, 'local trial={left=16}'), 'person-state-small-budget')
        for label, candidate in (('fallback', small_fallback), ('native', small_native)):
            check('personState' not in candidate['people'][0]['context'], label + ' oversized person state withheld whole')
            check('people.array-person.personState' in candidate['coverage']['omittedFields'], label + ' person-state omission retained')
        query_marker = 'return SAO.PersonState.query(person.id,body,SAO.History.ticks())'
        Lab.require(source.count(query_marker) == 1, 'person-state query seam differs')
        failed_fallback, failed_native, _ = native(source.replace(query_marker, 'error("controlled unavailable person owner")'), 'person-state-owner-unavailable')
        for label, candidate in (('fallback', failed_fallback), ('native', failed_native)):
            check('personState' not in candidate['people'][0]['context'], label + ' failed person owner leaves core observation intact')
            check('people.array-person.personState' in candidate['coverage']['omittedFields'], label + ' failed person owner omission retained')
        clean = Lab.inspect_frames(native_path, package)
        check("observationNormalizations" not in clean, "zero corrections preserve inspection receipt schema")
        check(set(clean) == {"schema", "frames", "definitionSha256", "save", "map", "session", "firstHours", "lastHours",
                            "coverage", "population", "packageSha256", "datasetAdmission", "behavioralVerdict"},
              "unchanged inspection keys remain exact")

        life_marker = "setmetatable(person.episodes, arrayMeta)"
        Lab.require(source.count(life_marker) == 1, "life array marker control seam differs")
        old_life_fallback, old_life_native, _ = native(source.replace(life_marker, "-- missing life array marker"), "missing-life-marker")
        for label, candidate in (("fallback", old_life_fallback), ("native", old_life_native)):
            check(candidate["situation"]["initialLifeHistory"][0]["episodes"] == {}, label + " missing life marker preserves defective empty-object encoding")
            try:
                Lab.validate_frame(candidate, verified[1]["origins"])
            except ValueError as error:
                check(str(error) == "life history permits0..64 episodes", label + " life marker control fails at exact schema boundary")
            else:
                raise AssertionError(label + " missing life marker survived")
        receipt["controls"].append("missing life marker rejected by actual native and fallback serializers")

        original_marker = "setmetatable(person.entries, arrayMeta)"
        Lab.require(source.count(original_marker) == 1, "array marker control seam differs")
        bad_fallback, bad_native, _ = native(source.replace(original_marker, "-- restored missing array marker"), "missing-marker")
        for label, candidate in (("fallback", bad_fallback), ("native", bad_native)):
            check(candidate["situation"]["initialAwareness"][0]["entries"] == {},
                  label + " restored missing marker reproduces exact native incident")
            try:
                Lab.validate_frame(candidate, verified[1]["origins"])
            except ValueError as error:
                check(str(error) == "initial awareness permits0..8 reports", label + " marker control fails at exact array boundary")
            else:
                raise AssertionError(label + " missing-marker control survived")
        receipt["controls"].append("restored missing marker: actual fallback and native worker reproduce original rejection")

        historical = copy.deepcopy(frame)
        historical["situation"]["initialAwareness"][0]["entries"] = {}
        cases = out / "decoder"; cases.mkdir()

        def write_case(candidate, label):
            path = cases / (label + ".json")
            path.write_bytes(Lab.canonical(candidate) + b"\n")
            return path

        historical_path = write_case(historical, "historical-empty")
        old_hash = digest(historical_path)
        decoded, corrections = Lab._observation_arrays(historical, verified)
        check(historical["situation"]["initialAwareness"][0]["entries"] == {}, "decoder does not mutate raw parsed frame")
        check(decoded == frame and len(corrections) == 1, "decoder changes only declared empty-array shape")
        restored = Lab.inspect_frames(historical_path, package)
        provenance = restored.pop("observationNormalizations")
        check(restored == clean, "historical decoded inspection equals fully typed production inspection")
        check(provenance == [{"source": historical_path.name, "sourceSha256": old_hash, "decodedSha256": Lab.seal(frame),
                             "corrections": [{"path": "/situation/initialAwareness/0/entries",
                                "encoding": "empty-lua-table-to-authored-array", "siteId": "home", "actorOrdinal": 1}]}],
              "normalization provenance pins raw bytes decoded bytes and exact actor path")
        check(digest(historical_path) == old_hash, "historical observation bytes remain unchanged")

        def rejected(candidate, label, use_package=True):
            path = write_case(candidate, label)
            try:
                Lab.inspect_frames(path, package if use_package else None)
            except ValueError:
                check(True, "refused " + label)
                return
            raise AssertionError("accepted " + label)

        rejected(historical, "unbound-empty", False)
        mutations = {
            "foreign-definition": lambda x: x.update(definitionSha256="f" * 64),
            "foreign-observer": lambda x: x.update(observerSha256="f" * 64),
            "foreign-engine": lambda x: x.update(packageEngineJarSha256="f" * 64),
            "foreign-map": lambda x: x.update(map="different-map"),
            "foreign-site": lambda x: x["situation"]["initialAwareness"][0].update(siteId="elsewhere"),
            "foreign-ordinal": lambda x: x["situation"]["initialAwareness"][0].update(actorOrdinal=3),
            "boolean-ordinal": lambda x: x["situation"]["initialAwareness"][0].update(actorOrdinal=True),
            "nonempty-object": lambda x: x["situation"]["initialAwareness"][0].update(entries={"unexpected": report}),
            "nonempty-authored-binding": lambda x: x["situation"]["initialAwareness"][1].update(entries={}),
            "missing-entries": lambda x: x["situation"]["initialAwareness"][0].pop("entries"),
            "extra-row-field": lambda x: x["situation"]["initialAwareness"][0].update(personId="foreign"),
            "malformed-row": lambda x: x["situation"]["initialAwareness"].__setitem__(0, []),
            "duplicate-person": lambda x: x["situation"]["initialAwareness"].append(copy.deepcopy(x["situation"]["initialAwareness"][0])),
            "reordered-people": lambda x: x["situation"]["initialAwareness"].reverse(),
            "changed-report": lambda x: x["situation"]["initialAwareness"][1]["entries"][0].update(sourceId="unbound-radio"),
            "different-valid-sandbox": lambda x: x["sandbox"].update({"SurvivorAwareness.Population": 3}),
            "foreign-person-state": lambda x: x['people'][0]['context']['personState'].update(actorId='foreign'),
            "malformed-person-state-status": lambda x: x['people'][0]['context']['personState'].update(status='healthy'),
            "foreign-person-model-view": lambda x: x['people'][0]['context']['personState']['modelView'].update(actorId='foreign'),
            "future-person-state-clock": lambda x: x['people'][0]['context']['personState'].update(atHours=3),
            "foreign-frozen-person": lambda x: x['people'][0]['context']['cognition']['episodes'][0]['decisionPersonState'].update(actorId='foreign'),
            "foreign-frozen-decision": lambda x: x['people'][0]['context']['cognition']['episodes'][0]['decisionPersonState'].update(decisionId='different'),
            "future-frozen-clock": lambda x: x['people'][0]['context']['cognition']['episodes'][0]['decisionPersonState'].update(atHours=3),
            "foreign-frozen-model": lambda x: x['people'][0]['context']['cognition']['episodes'][0]['decisionPersonState']['personState']['modelView'].update(actorId='foreign'),
            "boolean-frozen-tick": lambda x: x['people'][0]['context']['cognition']['episodes'][0]['decisionPersonState'].update(atTick=True),
            "missing-frozen-state": lambda x: x['people'][0]['context']['cognition']['episodes'][0]['decisionPersonState'].pop('personState'),
        }
        for label, mutation in mutations.items():
            changed = copy.deepcopy(historical); mutation(changed); rejected(changed, label)
        authored = copy.deepcopy(definition); authored["situation"]["initialAwareness"][0]["entries"] = {}
        try:
            Lab.validate(authored)
        except ValueError as error:
            check(str(error) == "initial awareness permits0..8 reports", "authored empty object remains strictly invalid")
        else:
            raise AssertionError("authored empty object accepted")

        # The normalization is not a replacement for exact full source binding.
        original_bind = Lab.bind_frame
        Lab.bind_frame = lambda *_: None
        try:
            changed = copy.deepcopy(historical)
            mutations["changed-report"](changed)
            try:
                rejected(changed, "full-binding-control")
            except AssertionError as error:
                Lab.require(str(error) == "accepted full-binding-control", "wrong full-binding control failure")
                receipt["controls"].append("removed full bind: changed nonempty report is detected by refusal assertion")
            else:
                raise AssertionError("full-binding control did not reach causal assertion")
        finally:
            Lab.bind_frame = original_bind

        package_definition = package / "definition.json"
        original_bytes = package_definition.read_bytes()
        try:
            package_definition.write_bytes(original_bytes + b" ")
            rejected(historical, "modified-package-file")
        finally:
            package_definition.write_bytes(original_bytes)
        check(Lab.verify_package(package) == verified, "isolated tamper fixture restored exact package bytes")
        receipt["status"] = "PASS"
    except Exception as failure:
        receipt["failure"] = str(failure)
        raise
    finally:
        receipt["inputsAfter"] = {str(path): digest(path) for path in inputs}
        receipt["changedInputs"] = [path for path, sha in receipt["inputsBefore"].items() if receipt["inputsAfter"][path] != sha]
        if receipt["changedInputs"]:
            receipt["status"] = "INCOMPLETE"
        retain()
    Lab.require(not receipt["changedInputs"], "proof inputs changed during execution")
    print(f"PASS observation arrays: {len(receipt['checks'])} checks; {len(receipt['controls'])} restored controls")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    try:
        run(args.output_dir.resolve())
    except Exception as failure:
        print("FAIL observation arrays:", failure)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
