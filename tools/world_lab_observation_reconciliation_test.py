#!/usr/bin/env python3
"""Exact observation-array reconciliation with real validators and private disk fixtures.

No game process, Java build, installed mod, live cache or real save is changed.
Synthetic native headers/PNG are filesystem contract fixtures, not gameplay.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
import shutil
import struct
import sys
import tempfile
import types
import zlib
from unittest.mock import patch

import world_lab as Lab
import world_lab_run as R
import world_lab_delivery as D

CONTROLS = {
    "other-error": ("and original.get(\"runtimeErrors\") == [OBSERVATION_ARRAY_ERROR]",
                    "and True", "REFUSAL other parser error"),
    "forced": ("supervision.get(\"forced\") is False and supervision.get(\"failure\") is None,\n                \"failed or forced run cannot be reconciled\"",
               "True,\n                \"failed or forced run cannot be reconciled\"", "REFUSAL forced supervision"),
    "no-correction": ("isinstance(normalizations, list) and normalizations\n                and all(row.get(\"corrections\") for row in normalizations)",
                      "True", "REFUSAL already typed observations"),
    "physical-verification": ("    _verify_run_receipt(destination, package, candidate[\"receipt\"], archived_receipt=original)",
                              "    # restored missing complete physical verification", "REFUSAL copied mod changed"),
    "native-error": ("    return found\n", "    return []\n", "REFUSAL native exception despite matching log pin"),
    "side-source": ("Lab.require(corrected == expected, \"observation reconciliation source or derivation differs\")",
                    "Lab.require(corrected['receipt'] == expected['receipt'], \"observation reconciliation source or derivation differs\")",
                    "REFUSAL stale decoder source"),
    "original-write": ("        publish(target, candidate)\n    return candidate",
                       "        publish(destination / 'run.json', candidate['receipt'])\n        publish(target, candidate)\n    return candidate",
                       "original reports remain byte-for-byte immutable"),
    "retained-source": ("Lab.require(side == expected, \"retained observation reconciliation source or derivation differs\")",
                         "Lab.require(True, \"retained observation reconciliation source or derivation differs\")",
                         "REFUSAL retained raw parent"),
}
DELIVERY_CONTROLS = {
    "unverified-delivery-parent": ("    observation_update_parent(destination, receipt)\n",
                                  "    # restored unverified derived predecessor\n",
                                  "REFUSAL unverified delivery predecessor"),
}
HISTORY_CONTROLS = {
    "history-current-source": ("    expected[\"sourceSha256\"] = sources\n", "",
                               "retained observation reconciliation source or derivation differs"),
    "history-source-content": ("        sources[name] = digest(path)\n",
                               "        sources[name] = Lab.load(side_path)['sourceSha256'][name]\n",
                               "REFUSAL retained decoder content changed"),
    "history-source-inventory": ("{p.relative_to(root).as_posix() for p in root.rglob(\"*\")} == expected",
                                 "True", "REFUSAL retained decoder extra file"),
    "history-semantic": ("Lab.require(side == expected, \"retained observation reconciliation source or derivation differs\")",
                         "Lab.require(True, \"retained observation reconciliation source or derivation differs\")",
                         "REFUSAL retained original identity"),
    "history-late-source": ("digest(side_path) == side_hash and _retained_reconciliation_sources(side_path) == sources",
                            "True", "REFUSAL retained decoder changed during replay"),
}


def put(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(value if isinstance(value, bytes) else Lab.canonical(value))


def png():
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(b"\0\0\0\0")) + chunk(b"IEND", b"")


def fixture(root):
    game = root / "controlled-engine-files"
    for name, content in {
        "projectzomboid.jar": b"controlled engine identity; never executed",
        "media/maps/Muldraugh, KY/map.info": b"Cell size is 256x256; Chunk size is 8x8",
        "media/lua/client/OptionScreens/WorldSelect.lua": b"setMinXCell setMaxXCell setMinYCell setMaxYCell setSeedString",
        "media/maps/challengemaps/The Forest/map.info": b"lots=NONE",
    }.items(): put(game / name, content)
    definition = Lab.load(Lab.ROOT / "tools/world_lab/definition.example.json")
    definition.update(id="array-reconciliation", generation={"roads": {}})
    definition["sandbox"].update({"SurvivorAwareness.Population": 2, "SurvivorAwareness.Newcomers": 2})
    definition["observation"]["windows"] = [{"id": "home", "x": 128, "y": 128, "z": 0, "width": 1, "height": 1}]
    definition["observation"]["sites"] = [{"id": "home", "label": "Home", "x": 128, "y": 128, "z": 0}]
    definition["situation"] = {"initialPeopleBySite": {"home": 2}, "initialAwareness": [
        {"siteId": "home", "actorOrdinal": 1, "entries": []},
        {"siteId": "home", "actorOrdinal": 2, "entries": [{"id": "heard-1", "kind": "outbreak", "affirmed": True,
            "sourceId": "private-radio", "sourceAtHours": 1, "receivedAtHours": 1, "certainty": "reported"}]}]}
    package = root / "package"
    manifest = Lab.build(definition, package, game)
    destination = root / "base-run"
    cache = destination / "cache"
    map_name = manifest["mapName"]
    shutil.copytree(package / "mod", cache / "mods")
    bootstrap = cache / "mods" / map_name / "42.20/media/lua/client/ZZStudyLaunch.lua"
    put(bootstrap, b"controlled launch; native terminal supplied independently")
    put(destination / "StudyLoadingAgent.jar", b"controlled adapter identity; never executed")
    put(cache / "options.ini", b"controlled renderer options")
    put(cache / "mods/default.txt", b"controlled mod order")
    for name in ("42.20/media/lua/shared/SAO_ConceptKnowledge.lua", "42.20/media/lua/client/SAO_Controller.lua",
                 "42.20/media/lua/client/SAO_Gesture.lua", "42.20/media/lua/client/SAO_ConflictResponse.lua"):
        put(cache / "mods" / D.MOD / name, ("old " + name).encode())
    mods = {map_name: {p.relative_to(cache / "mods" / map_name).as_posix(): R.digest(p)
                      for p in (cache / "mods" / map_name).rglob("*") if p.is_file() and p != bootstrap}}
    mods[D.MOD] = {p.relative_to(cache / "mods" / D.MOD).as_posix(): R.digest(p)
                  for p in (cache / "mods" / D.MOD).rglob("*") if p.is_file()}
    save = cache / "Saves/Sandbox/ArrayFixture"
    for name in ("map.bin", "map_t.bin", "map_sand.bin", "map_meta.bin", "map_zone.bin", "global_mod_data.bin", "WorldDictionary.bin", "map/0.bin"):
        put(save / name, b"controlled presence; not a native gameplay save")
    put(save / "mods.txt", ("mods\n{\n" + "".join(" mod = " + name + ",\n" for name in mods) + "}\n").encode())
    put(save / "map_ver.bin", struct.pack(">ii", 249, len(map_name)) + map_name.encode("utf-16-be"))
    seed = definition["seed"].encode()
    put(save / "map_worldgen.bin", struct.pack(">4sih", b"WGEN", 249, len(seed)) + seed + struct.pack(">iiii", 0, 0, 1, 1))
    attempt = destination / "attempts/0001"
    log = "\n".join(["[StudyLaunch] started attempt=1 save=ArrayFixture hours=2",
        "[StudyWorld] frame=1 hours=2", "[StudyWorld] frame=2 hours=2.25",
        "[StudyLaunch] wall-limit attempt=1 save=ArrayFixture start=2 end=2.3",
        "[StudyLaunch] native-save-returned attempt=1"])
    put(attempt / "stdout.log", log.encode()); put(attempt / "stderr.log", b"")
    state = {"schema": "sao-study-observer/1", "detached": True, "worldAdvanced": True, "hours": 2.3, "startHours": 2,
             "nativeAlive": False, "ghost": True, "zombiesDontAttack": True, "collidable": False, "playerSqlId": -1,
             "suppressedBirths": 1, "suppressedSaves": 1, "logicCalls": 1, "objects": 0, "additions": 0,
             "removals": 0, "squareMemberships": 0}
    put(attempt / "observer-state.json", state)
    image = attempt / "native-view/study-live-0000000000000001.png"
    put(image, png())
    put(attempt / "native-view/native.json", {"schema": "sao-native-viewport/1", "sequence": 1, "capturedAtUnixMs": 1,
        "image": {"file": image.name, "sha256": R.digest(image), "width": 1, "height": 1}})
    situation = copy.deepcopy(definition["situation"])
    situation["initialAwareness"][0]["entries"] = {}
    for sequence, hours in ((1, 2), (2, 2.25)):
        frame = {"schema": Lab.FRAME, "definitionSha256": manifest["definitionSha256"], "observerSha256": manifest["observerSha256"],
            "packageEngineJarSha256": manifest["engine"]["jar"]["sha256"], "engineVersion": "controlled", "map": map_name,
            "save": "ArrayFixture", "sequence": sequence, "hours": hours, "session": "fixture-session", "datasetAdmission": "unreviewed",
            "extent": definition["extent"], "sandbox": definition["sandbox"], "generation": definition["generation"],
            "situation": situation, "observationSites": definition["observation"]["sites"], "source": "loaded-native-world",
            "mods": list(mods), "windows": [{**definition["observation"]["windows"][0], "squares": [], "unavailable": 1}],
            "people": [], "processes": [], "population": {"total": 0, "captured": 0, "dead": 0, "represented": 0, "unrepresented": 0},
            "coverage": {"requestedSquares": 1, "loadedSquares": 0, "unavailableSquares": 1, "peopleComplete": True,
                "processesComplete": True, "physicalCoverage": "loaded-squares-only", "observerMovesWorld": False,
                "organizationAvailable": False, "totalProcesses": 0, "omittedFields": [], "omittedFieldCount": 0}}
        put(cache / f"Lua/StudyWorld/fixture/session/{sequence:016d}.json", frame)
    receipt = {"schema": "sao-study-run/1", "status": "incomplete", "datasetAdmission": "unreviewed", "exitCode": 0,
        "runtimeErrors": [R.OBSERVATION_ARRAY_ERROR], "watch": True, "host": "observer", "packageSha256": Lab.seal(manifest),
        "definitionSha256": manifest["definitionSha256"], "engineJarSha256": manifest["engine"]["jar"]["sha256"],
        "mapName": map_name, "mods": mods, "pid": 99999999, "loadingAgentSha256": R.digest(destination / "StudyLoadingAgent.jar"),
        "launchSha256": R.digest(bootstrap), "launchNumber": 1, "sessionId": "fixture-native-session", "hours": 1,
        "supervision": {"forced": False, "failure": None}, "observerDirectory": "attempts/0001", "mapDependency": None,
        "nativeImages": {}, "inspection": None, "terminal": None, "observationFiles": 2,
        "saveFiles": {p.relative_to(cache).as_posix(): R.digest(p) for p in (cache / "Saves").rglob("*") if p.is_file()},
        "observations": {p.relative_to(cache).as_posix(): R.digest(p) for p in (cache / "Lua/StudyWorld").rglob("*.json")},
        "logs": {name: R.digest(attempt / name) for name in ("stdout.log", "stderr.log")}}
    receipt["observerEvidence"] = R.observer_evidence(destination, receipt)
    put(destination / "run.json", receipt); put(attempt / "report.json", receipt)
    return destination, package


def checks(out):
    before = {str(Lab.ROOT / "tools" / name): R.digest(Lab.ROOT / "tools" / name) for name in R.RECONCILIATION_SOURCES}
    before[str(Path(__file__).resolve())] = R.digest(__file__)
    verdict = {"schema": "sao-observation-reconciliation-proof/1", "status": "INCOMPLETE", "checks": [], "inputsBefore": before,
               "scope": "Private controlled disk fixture with actual canonical package, frame, terminal, save and run validators; no native execution."}
    def check(value, label):
        if not value: raise AssertionError(label)
        verdict["checks"].append(label)
        print("PASS", label, flush=True)
    def refused(fn, label):
        try: fn()
        except (ValueError, OSError, KeyError, TypeError): check(True, "REFUSAL " + label)
        else: raise AssertionError("REFUSAL " + label)
    try:
        base, package = fixture(out)
        def lane(name):
            target = out / name
            shutil.copytree(base, target)
            return target
        def reports(target, mutate):
            receipt = Lab.load(target / "run.json"); mutate(receipt)
            put(target / "run.json", receipt); put(target / "attempts/0001/report.json", receipt)
        def invoke(target): return R.reconcile_observation_arrays(target, package)
        original = {p: p.read_bytes() for p in (base / "run.json", base / "attempts/0001/report.json")}
        refused(lambda: R.verify_run(base, package), "original incomplete is not silently completed")
        derived = R.observation_array_reconciliation(base, package)
        check(not (base / R.OBSERVATION_RECONCILIATION).exists(), "pure candidate verification writes no side receipt")
        allowed = {"inspection", "terminal", "save", "lastHours", "lastSequence", "player", "status", "runtimeErrors"}
        parent = Lab.load(base / "run.json")
        check({k:v for k,v in parent.items() if k not in allowed} == {k:v for k,v in derived["receipt"].items() if k not in allowed},
              "all non-derived original fields retained exactly")
        check(len(derived["event"]["normalizations"]) == 2 and derived["receipt"]["player"] == {"count": 0, "observerPersisted": False},
              "real canonical frame and saved-state validators derive both observations")
        # Invalid lanes precede publication so controls prove full prepublication refusal.
        target = lane("changed-mod")
        bootstrap = next((target / "cache/mods").glob("*/42.20/media/lua/client/ZZStudyLaunch.lua"))
        bootstrap.write_bytes(b"changed copied input")
        refused(lambda: invoke(target), "copied mod changed")
        check(not (target / R.OBSERVATION_RECONCILIATION).exists(), "failed physical verification publishes no side")
        changes = {
            "other parser error": lambda r: r.update(runtimeErrors=["unrelated parser failure"]),
            "additional error": lambda r: r["runtimeErrors"].append("another failure"),
            "forced supervision": lambda r: r["supervision"].update(forced=True),
            "failed supervision": lambda r: r["supervision"].update(failure="timeout"),
            "nonzero exit": lambda r: r.update(exitCode=1),
            "nonwatch": lambda r: r.update(watch=False),
            "player host": lambda r: r.update(host="player"),
            "approved dataset": lambda r: r.update(datasetAdmission="approved"),
            "foreign package": lambda r: r.update(packageSha256="f"*64),
            "completed original": lambda r: r.update(status="completed"),
            "missing observations": lambda r: r.update(observations={}),
            "missing save inventory": lambda r: r.update(saveFiles={}),
            "missing retained frame": lambda r: r["observations"].pop(next(iter(r["observations"]))),
            "unsafe observation path": lambda r: r.update(observations={"../run.json": R.digest(base / "run.json")}),
            "wrong observation count": lambda r: r.update(observationFiles=1),
        }
        for index, (name, change) in enumerate(changes.items()):
            target = lane(f"invalid-{index}"); reports(target, change)
            refused(lambda: invoke(target), name)
            check(not (target / R.OBSERVATION_RECONCILIATION).exists(), "no side after " + name)
        for index, (name, line) in enumerate((
            ("native exception despite matching log pin", "ExceptionLogger.logException: native failure"),
            ("positive-frame native error", "ERROR: General f:12 native action failed"))):
            target = lane("log-" + str(index)); log = target / "attempts/0001/stdout.log"
            log.write_bytes(log.read_bytes() + b"\n" + line.encode())
            reports(target, lambda r: r["logs"].update({"stdout.log": R.digest(log)}))
            refused(lambda: invoke(target), name)
        target = lane("missing-save-return"); log = target / "attempts/0001/stdout.log"
        log.write_text(log.read_text().replace("[StudyLaunch] native-save-returned attempt=1", ""))
        reports(target, lambda r: r["logs"].update({"stdout.log": R.digest(log)}))
        refused(lambda: invoke(target), "missing real terminal save return")
        target = lane("bad-save"); header = target / "cache/Saves/Sandbox/ArrayFixture/map_ver.bin"
        header.write_bytes(b"wrong native header")
        reports(target, lambda r: r["saveFiles"].update({header.relative_to(target / "cache").as_posix(): R.digest(header)}))
        refused(lambda: invoke(target), "invalid native save despite matching hash")
        target = lane("changed-report"); report = Lab.load(target / "attempts/0001/report.json")
        report["hours"] = 2; put(target / "attempts/0001/report.json", report)
        refused(lambda: invoke(target), "archived report differs")
        typed = lane("typed")
        for frame_path in (typed / "cache/Lua/StudyWorld").rglob("*.json"):
            frame = Lab.load(frame_path); frame["situation"]["initialAwareness"][0]["entries"] = []
            put(frame_path, frame)
        reports(typed, lambda r: r.update(observations={p.relative_to(typed / "cache").as_posix(): R.digest(p) for p in (typed / "cache/Lua/StudyWorld").rglob("*.json")}))
        refused(lambda: invoke(typed), "already typed observations")
        published = invoke(base)
        check(all(p.read_bytes() == content for p,content in original.items()), "original reports remain byte-for-byte immutable")
        check(published == derived and R.verify_run(base, package) == derived["receipt"], "normal verifier selects fully rederived bound side")
        side_bytes = (base / R.OBSERVATION_RECONCILIATION).read_bytes()
        check(invoke(base) == derived and (base / R.OBSERVATION_RECONCILIATION).read_bytes() == side_bytes,
              "identical reconciliation is idempotent")
        for index, (name, mutate) in enumerate((
            ("stale decoder source", lambda x: x["sourceSha256"].update({"world_lab.py": "f"*64})),
            ("foreign current parent", lambda x: x["original"].update(runSha256="f"*64)),
            ("foreign archived parent", lambda x: x["original"].update(reportSha256="f"*64)),
            ("forged derived status", lambda x: x["receipt"].update(datasetAdmission="approved")),
            ("forged normalization event", lambda x: x["event"].update(normalizations=[])),
            ("extra side field", lambda x: x.update(approval="invented")),
        )):
            target = lane("side-" + str(index)); changed = copy.deepcopy(derived); mutate(changed)
            put(target / R.OBSERVATION_RECONCILIATION, changed)
            refused(lambda: R.verify_run(target, package), name)
        target = lane("new-attempt")
        reports(target, lambda r: r.update(launchNumber=2, sessionId="new-attempt"))
        refused(lambda: R.verify_run(target, package), "old side cannot reclassify a newer attempt")
        target = lane("other-incomplete")
        reports(target, lambda r: r.update(runtimeErrors=["unrelated"])); refused(lambda: R.verify_run(target, package), "side cannot erase another incomplete error")
        target = lane("post-publication-save-change")
        (target / "cache/Saves/Sandbox/ArrayFixture/map.bin").write_bytes(b"changed")
        refused(lambda: R.verify_run(target, package), "normal side selection retains physical verification")
        complete = copy.deepcopy(derived["receipt"])
        complete["observations"] = Lab.load(typed / "run.json")["observations"]
        complete["inspection"] = Lab.inspect_frames(next((typed / "cache/Lua/StudyWorld").rglob("*.json")).parent, package)
        put(typed / "run.json", complete); put(typed / "attempts/0001/report.json", complete)
        put(typed / R.OBSERVATION_RECONCILIATION, derived)
        check("observationNormalizations" not in complete["inspection"] and R.verify_run(typed, package) == complete,
              "normal completed zero-correction receipt ignores unrelated stale side")
        def update(target):
            previous = R.verify_run(target, package)
            rows = []
            for name in ("42.20/media/lua/client/SAO_Gesture.lua", "42.20/media/lua/client/SAO_ConflictResponse.lua"):
                source = out / "update-sources" / name
                put(source, ("new " + name).encode())
                rows.append({"path": name, "source": str(source), "beforeSha256": previous["mods"][D.MOD][name], "afterSha256": R.digest(source)})
            value = {"schema": D.UPDATE_SCHEMA, "profile": "threat-gesture-release", "modId": D.MOD,
                     "predecessor": D.binding(previous, R.digest(target / "run.json")), "files": rows}
            path = target / "update.json"; put(path, value)
            return previous, path, value
        target = lane("delivery-rollback")
        previous, manifest_path, manifest = update(target)
        check(D.update_shape(manifest) == "threat-gesture-release"
              and set(D.PROFILES["threat-gesture-release"]) == {row["path"] for row in manifest["files"]},
              "named gesture release profile requires exactly both approved Lua files")
        for name, mutation in (
            ("gesture profile missing file", lambda v: v["files"].pop()),
            ("gesture profile extra file", lambda v: v["files"].append(dict(v["files"][0]))),
            ("gesture profile foreign file", lambda v: v["files"][0].update(path="42.20/media/lua/client/SAO_Controller.lua")),
            ("gesture profile wrong schema", lambda v: v.update(schema=D.SOURCE_SUBSET_SCHEMA)),
        ):
            changed = copy.deepcopy(manifest); mutation(changed)
            refused(lambda: D.update_shape(changed), name)
        preserved = {p: p.read_bytes() for p in target.rglob("*") if p.is_file()}
        with patch.object(D, "process_live", return_value=False):
            fake = copy.deepcopy(previous); fake["hours"] = 17
            refused(lambda: D.validate_update(target, fake, manifest_path), "unverified delivery predecessor")
            try:
                with D.resume_guard(target, gameplay=True):
                    attempt = target / "attempts/0002"; attempt.mkdir()
                    successor = copy.deepcopy(previous); successor["launchNumber"] = 2
                    D.apply_update(target, attempt, previous, successor, manifest_path)
                    D.verify_history(target, successor)
                    raise RuntimeError("controlled prelaunch failure")
            except RuntimeError as error:
                check(str(error) == "controlled prelaunch failure", "rollback reached post-update failure")
            check(all(path.read_bytes() == content for path,content in preserved.items()),
                  "rollback restores source bytes and preserves raw report and side")
            failures = list((target / "delivery-failures").glob("*/gameplay-lua-update"))
            check(len(failures) == 1 and (failures[0] / R.OBSERVATION_RECONCILIATION).read_bytes() == side_bytes,
                  "failed update retains exact corrective side beside original predecessor")
        target = lane("delivery-applied")
        previous, manifest_path, manifest = update(target)
        original_bytes = (target / "run.json").read_bytes()
        attempt = target / "attempts/0002"; attempt.mkdir()
        successor = copy.deepcopy(previous); successor["launchNumber"] = 2
        with patch.object(D, "process_live", return_value=False):
            D.apply_update(target, attempt, previous, successor, manifest_path)
        retained_root = attempt / "gameplay-lua-update"
        entry = successor["gameplayLuaUpdates"][-1]
        check((retained_root / "previous-run.json").read_bytes() == original_bytes
              and (target / "run.json").read_bytes() == original_bytes
              and (target / "attempts/0001/report.json").read_bytes() == original_bytes,
              "delivery retains original incomplete predecessor bytes and raw manifest hash")
        check(entry["predecessor"]["receiptSha256"] == hashlib.sha256(original_bytes).hexdigest()
              and entry["observationReconciliationSha256"] == R.digest(retained_root / R.OBSERVATION_RECONCILIATION),
              "history separately pins raw predecessor and corrective side")
        D.verify_history(target, successor)
        check(all(R.digest(target / "cache/mods" / D.MOD / row["path"]) == row["afterSha256"] for row in manifest["files"]),
              "retained history derives predecessor while current gameplay bytes have advanced")
        retained_side = retained_root / R.OBSERVATION_RECONCILIATION
        original_side = retained_side.read_bytes()
        for name, mutation in (
            ("retained side hash", lambda x: x["receipt"].update(save="foreign-save")),
            ("retained source pin", lambda x: x["sourceSha256"].update({"world_lab.py": "f"*64})),
            ("retained raw parent", lambda x: x["original"].update(runSha256="f"*64)),
            ("retained archived parent", lambda x: x["original"].update(reportSha256="f"*64)),
            ("retained package", lambda x: x.update(packageSha256="f"*64)),
            ("retained semantic result", lambda x: x["receipt"].update(save="foreign-save")),
        ):
            changed = Lab.decode(original_side.decode()); mutation(changed); put(retained_side, changed)
            changed_successor = copy.deepcopy(successor)
            if name != "retained side hash":
                changed_successor["gameplayLuaUpdates"][-1]["observationReconciliationSha256"] = R.digest(retained_side)
            refused(lambda: D.verify_history(target, changed_successor), name)
            retained_side.write_bytes(original_side)
        changed_manifest = copy.deepcopy(manifest); changed_manifest["predecessor"]["save"] = "foreign-save"
        put(retained_root / "manifest.json", changed_manifest)
        changed_successor = copy.deepcopy(successor)
        changed_successor["gameplayLuaUpdates"][-1].update(manifestSha256=R.digest(retained_root / "manifest.json"), predecessor=changed_manifest["predecessor"])
        refused(lambda: D.verify_history(target, changed_successor), "history manifest cannot change derived save")
        put(retained_root / "manifest.json", manifest)
        check((target / "run.json").read_bytes() == original_bytes, "all retained-history refusals preserve original run")
        verdict["status"] = "PASS"
    except Exception as error:
        verdict["failure"] = str(error)
        raise
    finally:
        verdict["inputsAfter"] = {path: R.digest(path) for path in before}
        verdict["changedInputs"] = [path for path in before if before[path] != verdict["inputsAfter"][path]]
        if verdict["changedInputs"]: verdict["status"] = "INCOMPLETE"
        put(out / "receipt.json", verdict)
    if verdict["changedInputs"]: raise AssertionError("proof inputs changed")
    print("PASS observation reconciliation", len(verdict["checks"]), "checks")


def history_checks(out):
    before = {str(Lab.ROOT / "tools" / name): R.digest(Lab.ROOT / "tools" / name) for name in R.RECONCILIATION_SOURCES}
    before[str(Path(__file__).resolve())] = R.digest(__file__)
    verdict = {"schema": "sao-observation-reconciliation-history-proof/1", "status": "INCOMPLETE",
               "inputsBefore": before, "checks": [],
               "scope": "Current canonical validators and private disk fixture; archived decoder bytes are never executed."}
    def check(value, label):
        if not value: raise AssertionError(label)
        verdict["checks"].append(label); print("PASS", label, flush=True)
    def refused(fn, label):
        try: fn()
        except (ValueError, OSError, KeyError, TypeError): check(True, "REFUSAL " + label)
        else: raise AssertionError("REFUSAL " + label)
    try:
        target, package = fixture(out)
        side = R.reconcile_observation_arrays(target, package)
        previous = R.verify_run(target, package)
        immutable = {p: p.read_bytes() for p in (target / "run.json", target / "attempts/0001/report.json",
                                                 target / R.OBSERVATION_RECONCILIATION)}
        rows = []
        for name in sorted(D.PROFILES["threat-gesture-release"]):
            source = out / "sources" / name
            put(source, ("updated " + name).encode())
            rows.append(dict(path=name, source=str(source), beforeSha256=previous["mods"][D.MOD][name], afterSha256=R.digest(source)))
        manifest = dict(schema=D.UPDATE_SCHEMA, profile="threat-gesture-release", modId=D.MOD,
            predecessor=D.binding(previous, R.digest(target / "run.json")), files=rows)
        manifest_path = out / "update.json"; put(manifest_path, manifest)
        # An unrelated future profile changes source identity without changing the
        # parent parser's semantics. Active side remains current-pinned.
        future_sources = R._reconciliation_sources()
        future_sources["world_lab_delivery.py"] = hashlib.sha256(
            (Path(D.__file__).read_text() + "\n# unrelated reviewed profile addition\n").encode()).hexdigest()
        with patch.object(R, "_reconciliation_sources", return_value=future_sources):
            refused(lambda: R.verify_run(target, package), "active side refuses current decoder drift")
        cache_before = {row["path"]: (target / "cache/mods" / D.MOD / row["path"]).read_bytes() for row in rows}
        with patch.object(D, "process_live", return_value=False):
            try:
                with D.resume_guard(target, gameplay=True):
                    attempt = target / "attempts/0002"; attempt.mkdir()
                    successor = copy.deepcopy(previous); successor["launchNumber"] = 2
                    D.apply_update(target, attempt, previous, successor, manifest_path)
                    root = attempt / "gameplay-lua-update"
                    check(R._retained_reconciliation_sources(root / R.OBSERVATION_RECONCILIATION) == side["sourceSha256"],
                          "all seven exact decoder files retained before gameplay continuation")
                    D.verify_history(target, successor)
                    with patch.dict(D.PROFILES, {"unrelated-future-profile": D.FILES}), \
                            patch.object(R, "_reconciliation_sources", return_value=future_sources), \
                            patch.object(R, "_verify_run_receipt", side_effect=AssertionError("history must not requalify current physical state")):
                        D.verify_history(target, successor)
                    check(True, "unrelated current profile permits identical historical semantic replay")
                    decoder = root / R.RECONCILIATION_DECODER
                    stored = decoder / "world_lab.py"
                    stored_raw = stored.read_bytes()
                    stored.write_bytes(stored_raw + b"\n# changed archived source\n")
                    refused(lambda: D.verify_history(target, successor), "retained decoder content changed")
                    stored.write_bytes(stored_raw)
                    stored.unlink()
                    refused(lambda: D.verify_history(target, successor), "retained decoder file missing")
                    stored.write_bytes(stored_raw)
                    extra = decoder / "unexpected.py"; extra.write_bytes(b"pass\n")
                    refused(lambda: D.verify_history(target, successor), "retained decoder extra file")
                    extra.unlink()
                    retained_side = root / R.OBSERVATION_RECONCILIATION
                    side_raw = retained_side.read_bytes()
                    for label, mutate in (
                        ("retained decoder source pin", lambda value: value["sourceSha256"].update({"world_lab.py": "f" * 64})),
                        ("retained original identity", lambda value: value["original"].update(runSha256="f" * 64)),
                        ("retained package identity", lambda value: value.update(packageSha256="f" * 64)),
                        ("retained normalization identity", lambda value: value["event"]["normalizations"][0].update(decodedSha256="f" * 64)),
                    ):
                        changed = Lab.decode(side_raw.decode()); mutate(changed); put(retained_side, changed)
                        changed_successor = copy.deepcopy(successor)
                        changed_successor["gameplayLuaUpdates"][-1]["observationReconciliationSha256"] = R.digest(retained_side)
                        refused(lambda: D.verify_history(target, changed_successor), label)
                        retained_side.write_bytes(side_raw)
                    expected_candidate = R._observation_array_candidate
                    def changed_event(*args, **kwargs):
                        result = expected_candidate(*args, **kwargs)
                        result["event"]["kind"] = "changed-meaning"
                        return result
                    with patch.object(R, "_observation_array_candidate", side_effect=changed_event):
                        refused(lambda: D.verify_history(target, successor), "current decoder changes event semantics")
                    def changed_receipt(*args, **kwargs):
                        result = expected_candidate(*args, **kwargs)
                        result["receipt"]["lastHours"] += .01
                        return result
                    with patch.object(R, "_observation_array_candidate", side_effect=changed_receipt):
                        refused(lambda: D.verify_history(target, successor), "current decoder changes derived receipt")
                    def changed_during_replay(*args, **kwargs):
                        result = expected_candidate(*args, **kwargs)
                        stored.write_bytes(stored_raw + b"\n# late mutation\n")
                        return result
                    with patch.object(R, "_observation_array_candidate", side_effect=changed_during_replay):
                        refused(lambda: D.verify_history(target, successor), "retained decoder changed during replay")
                    stored.write_bytes(stored_raw)
                    D.verify_history(target, successor)
                    raise RuntimeError("controlled rollback with archived decoder")
            except RuntimeError as error:
                check(str(error) == "controlled rollback with archived decoder", "rollback after verified historical replay")
        check(all((target / "cache/mods" / D.MOD / name).read_bytes() == raw for name, raw in cache_before.items()),
              "rollback restores every changed gameplay source")
        check(all(path.read_bytes() == raw for path, raw in immutable.items()), "rollback preserves original report archive and side bytes")
        failed = list((target / "delivery-failures").glob("*/gameplay-lua-update"))
        check(len(failed) == 1 and R._retained_reconciliation_sources(failed[0] / R.OBSERVATION_RECONCILIATION) == side["sourceSha256"],
              "rollback retains complete decoder custody with failed attempt")
        # Corrupt a staged archive before validation; no gameplay source may change.
        attempt = target / "attempts/0002"; attempt.mkdir()
        successor = copy.deepcopy(previous); successor["launchNumber"] = 2
        real_copy = shutil.copyfile
        def corrupted_stage(source, destination, *args, **kwargs):
            result = real_copy(source, destination, *args, **kwargs)
            destination = Path(destination)
            if R.RECONCILIATION_DECODER in destination.parts and destination.name == "world_lab.py":
                destination.write_bytes(destination.read_bytes() + b"\n# staged corruption\n")
            return result
        with patch.object(D, "process_live", return_value=False), patch.object(D.shutil, "copyfile", side_effect=corrupted_stage):
            refused(lambda: D.apply_update(target, attempt, previous, successor, manifest_path), "staged decoder differs before gameplay mutation")
        check(all((target / "cache/mods" / D.MOD / name).read_bytes() == raw for name, raw in cache_before.items()),
              "invalid staged decoder prevents all gameplay writes")
        verdict["status"] = "PASS"
    except Exception as error:
        verdict["failure"] = str(error)
        raise
    finally:
        verdict["inputsAfter"] = {path: R.digest(path) for path in before}
        verdict["changedInputs"] = [path for path in before if before[path] != verdict["inputsAfter"][path]]
        if verdict["changedInputs"]: verdict["status"] = "INCOMPLETE"
        put(out / "receipt.json", verdict)
    if verdict["changedInputs"]: raise AssertionError("proof inputs changed")
    print("PASS observation reconciliation history", len(verdict["checks"]), "checks")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--control", choices={**CONTROLS, **DELIVERY_CONTROLS, **HISTORY_CONTROLS})
    parser.add_argument("--history-only", action="store_true")
    args = parser.parse_args()
    out = args.output_dir.resolve() if args.output_dir else Path(tempfile.mkdtemp(prefix="sao-observation-reconciliation-")) / "proof"
    out.mkdir(parents=True, exist_ok=False)
    global R, D
    if args.control:
        delivery = args.control in DELIVERY_CONTROLS
        path = Path(D.__file__ if delivery else R.__file__)
        source = path.read_text(encoding="utf-8")
        before, after, marker = {**CONTROLS, **DELIVERY_CONTROLS, **HISTORY_CONTROLS}[args.control]
        Lab.require(source.count(before) == 1, "control seam not unique")
        source = source.replace(before, after)
        module = types.ModuleType("world_lab_run_control"); module.__file__ = str(path)
        exec(compile(source, str(path), "exec"), module.__dict__)
        if delivery:
            D = module
            R.Delivery = module
        else:
            R = module
            # Lazy delivery imports must inspect the same controlled runner.
            sys.modules["world_lab_run"] = module
        put(out / "control.json", {"name": args.control, "sourceSha256": hashlib.sha256(source.encode()).hexdigest(), "expectedFailure": marker})
    try:
        (history_checks if args.history_only or args.control in HISTORY_CONTROLS else checks)(out)
    except Exception as error:
        print("FAIL observation reconciliation:", error, flush=True)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
