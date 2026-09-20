#!/usr/bin/env python3
"""Borders 163/169/174: native person continuation and dormant physiology.

native_person_cases.json owns the executable cases. The historical crosswalk
retains every former control and its mutation fingerprint. One production
compilation supplies unchanged classes; each mutation compiles successfully in
its own directory and runs the complete, unchanged probe in a fresh JVM.
"""
from __future__ import annotations

import argparse
from collections import Counter
import copy
import hashlib
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile
import time

from menu_reach import strip_lua


ROOT = pathlib.Path(__file__).resolve().parent.parent
DEFAULT_GAME = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = pathlib.Path(os.environ.get("PZ_DIR", str(DEFAULT_GAME))) / "projectzomboid.jar"
JDK = pathlib.Path(os.environ.get("JDK_BIN", r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"))
JAVA_SOURCES = {
    "SAONativeSnapshot.java": "java/src/com/sao/engine/SAONativeSnapshot.java",
    "SAOHibernation.java": "java/src/com/sao/engine/SAOHibernation.java",
}
REQUIRED = [*JAVA_SOURCES.values(), "tools/luacheck/PersonSnapshotProbe.java",
            "java/src/com/sao/bridge/SAOBridge.java",
            "mod/42.20/media/lua/client/SAO_Body.lua",
            "mod/42.20/media/lua/shared/SAO_BodySnapshot.lua",
            "mod/42.20/media/lua/client/SAO_AfflictedReturn.lua"]
HISTORICAL_CONTROLS = {163: 19, 169: 12, 174: 5}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def mutation_digest(case):
    payload = {key: case[key] for key in ("source", "before", "after", "expected")}
    return digest(json.dumps(payload, sort_keys=True, separators=(",", ":")).encode())


def validate_inventory(inventory, crosswalk):
    """Refuse loss or drift against the preserved pre-consolidation controls."""
    if inventory.get("schema") != 1 or crosswalk.get("schema") != 1:
        raise RuntimeError("Native case inventory schema unsupported")
    controls = inventory.get("controls", [])
    indexed = {}
    for case in controls:
        if set(case) != {"id", "source", "before", "after", "expected"}:
            raise RuntimeError("Native case inventory fields changed")
        if not all(isinstance(value, str) and value for key, value in case.items()
                   if key != "after") or not isinstance(case["after"], str):
            raise RuntimeError("Native case inventory contains empty or invalid fields")
        name = case["id"]
        if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", name) or name in indexed:
            raise RuntimeError("Native case inventory duplicate or invalid case: " + name)
        if case["source"] not in JAVA_SOURCES or case["before"] == case["after"]:
            raise RuntimeError("Native case inventory has no supported mutation: " + name)
        indexed[name] = case

    history = crosswalk.get("controls", [])
    if Counter(row["border"] for row in history) != HISTORICAL_CONTROLS:
        raise RuntimeError("Native crosswalk historical control accounting changed")
    old_names, mapped = set(), set()
    for row in history:
        identity = (row["entry_point"], row["former_control"])
        if identity in old_names:
            raise RuntimeError("Native crosswalk repeats a historical control")
        old_names.add(identity)
        name = row["case"]
        if name not in indexed:
            raise RuntimeError("Native case inventory missing declared control: " + name)
        if mutation_digest(indexed[name]) != row["mutation_sha256"]:
            raise RuntimeError("Native case inventory altered declared control: " + name)
        mapped.add(name)
    if mapped != set(indexed):
        raise RuntimeError("Native case inventory contains an unmapped control")

    production = inventory.get("production", {})
    baselines = crosswalk.get("production", [])
    if (production.get("id") != "production"
            or Counter(row["border"] for row in baselines) != {163: 1, 169: 1, 174: 1}
            or any(row["case"] != "production" for row in baselines)
            or production.get("required_stdout") != [row["required_stdout"] for row in baselines]):
        raise RuntimeError("Native case inventory production assertions changed")


def load_inventory(path, crosswalk):
    inventory = json.loads(path.read_text(encoding="utf-8-sig"))
    validate_inventory(inventory, crosswalk)
    return inventory


def inventory_controls(inventory, crosswalk):
    """Mutate real JSON input and require the production loader to refuse it."""
    missing = copy.deepcopy(inventory)
    missing["controls"].pop()
    altered = copy.deepcopy(inventory)
    altered["controls"][0]["expected"] = "unrelated compiler error"
    baseline = copy.deepcopy(inventory)
    baseline["production"]["required_stdout"].pop()
    controls = [("missing-control", missing, "missing declared control"),
                ("altered-control", altered, "altered declared control"),
                ("missing-baseline-assertion", baseline, "production assertions changed")]
    results = []
    with tempfile.TemporaryDirectory(prefix="sao-native-inventory-") as tmp:
        for name, mutated, reason in controls:
            path = pathlib.Path(tmp) / (name + ".json")
            path.write_text(json.dumps(mutated), encoding="utf-8")
            if path.read_text(encoding="utf-8") == json.dumps(inventory):
                raise RuntimeError("Inventory control did not change input: " + name)
            try:
                load_inventory(path, crosswalk)
            except RuntimeError as error:
                if reason not in str(error):
                    raise RuntimeError("Inventory control failed for another reason: " + name) from error
                results.append({"case": name, "passed": True, "reason": str(error)})
            else:
                raise RuntimeError("Inventory control was accepted: " + name)
    return results


def routing(root):
    text = {pathlib.Path(name).name: (root / name).read_text(encoding="utf-8-sig")
            for name in REQUIRED}
    body = strip_lua(text["SAO_Body.lua"], strings=False)
    snapshot = strip_lua(text["SAO_BodySnapshot.lua"], strings=False)
    returned = strip_lua(text["SAO_AfflictedReturn.lua"], strings=False)
    hibernation = text["SAOHibernation.java"]
    checks = {
        "capture-validation": re.search(r"SAOJavaBridge\s*:\s*validateHibernation\s*\(", snapshot),
        "body-restoration": re.search(r"SAOJavaBridge\s*:\s*awaken\s*\(", body),
        "v4-writer": 'private static final String PREFIX_V4 = "v4;";' in text["SAONativeSnapshot.java"],
        "v3-reader": 'private static final String PREFIX_V3 = "v3;";' in text["SAONativeSnapshot.java"],
        "native-routing": hibernation.count("SAONativeSnapshot.isNative(packed)") >= 2,
        "bridge-version": "hibernationVersion(Object packed)" in text["SAOBridge.java"],
        "legacy-sidecar-only": re.search(r"snapshotVersion\s*<\s*4\s+and\s+rec\.bodyVisual", body),
        "migration-provenance": "rec.hibernationMigration = { from = snapshotVersion" in body,
        "new-capture-clears-sidecar": "rec.bodyVisual = captured.visual" in snapshot,
        "return-clears-sidecar": re.search(
            r"if\s+SAO\.BodySnapshot\.version\(p\.packed\)\s*>=\s*4\s+then\s+rec\.bodyVisual\s*=\s*nil", returned),
    }
    for method in ("capture", "validate", "restore"):
        checks["native-" + method] = re.search(r"SAONativeSnapshot\." + method + r"\s*\(", hibernation)
    for method in ("capture", "valid", "commit", "version"):
        checks["snapshot-owner-" + method] = re.search(r"SAO\.BodySnapshot\." + method + r"\s*\(", body)
    missing = [name for name, present in checks.items() if not present]
    if missing:
        raise RuntimeError("Continuity routing missing: " + ", ".join(missing))
    return list(checks)


def execute(root, inventory, receipt):
    sources = {name: (root / relative).read_text(encoding="utf-8-sig")
               for name, relative in JAVA_SOURCES.items()}
    # Check every mutation before the first compile, so inventory drift fails
    # without paying for a partial native run.
    for case in inventory["controls"]:
        original = sources[case["source"]]
        if original.count(case["before"]) != 1:
            raise RuntimeError(f"Control {case['id']} no longer has exactly one source target")
        if original.replace(case["before"], case["after"], 1) == original:
            raise RuntimeError("Control did not change source: " + case["id"])

    def run(argv, cwd, phase, name):
        start = time.perf_counter()
        result = subprocess.run([str(value) for value in argv], cwd=cwd,
                                capture_output=True, text=True, encoding="utf-8",
                                errors="replace", timeout=60)
        receipt["commands"].append({
            "case": name, "phase": phase, "argv": [str(value) for value in argv],
            "cwd": str(cwd), "seconds": time.perf_counter() - start,
            "returncode": result.returncode, "stdout": result.stdout, "stderr": result.stderr,
        })
        return result

    with tempfile.TemporaryDirectory(prefix="sao-native-person-") as tmp:
        scratch = pathlib.Path(tmp)
        compiler = run([JDK / "javac.exe", "-version"], scratch, "compiler", "inputs")
        if compiler.returncode:
            raise RuntimeError("Native compiler version unavailable")
        receipt["compiler_version"] = (compiler.stdout + compiler.stderr).strip()
        receipt["engine_sha256"] = digest(PZ.read_bytes())
        receipt["compiler_sha256"] = digest((JDK / "javac.exe").read_bytes())
        receipt["java_sha256"] = digest((JDK / "java.exe").read_bytes())
        receipt["compile_options"] = ["-encoding", "UTF-8"]
        production_classes = scratch / "production" / "classes"

        for case in [inventory["production"], *inventory["controls"]]:
            name = case["id"]
            work = scratch / name
            classes = work / "classes"
            classes.mkdir(parents=True)
            if name == "production":
                inputs = [root / relative for relative in JAVA_SOURCES.values()]
                inputs.append(root / "tools/luacheck/PersonSnapshotProbe.java")
                compile_classpath = str(PZ)
                runtime_paths = [classes, PZ]
            else:
                changed = work / case["source"]
                changed.write_text(sources[case["source"]].replace(case["before"], case["after"], 1),
                                   encoding="utf-8")
                inputs = [changed]
                compile_classpath = os.pathsep.join(map(str, (production_classes, PZ)))
                runtime_paths = [classes, production_classes, PZ]
            compiled = run([JDK / "javac.exe", "-encoding", "UTF-8", "-cp", compile_classpath,
                            "-d", classes, *inputs], work, "compile", name)
            if compiled.returncode:
                raise RuntimeError(f"{name} did not compile: {compiled.stdout}{compiled.stderr}")
            result = run([JDK / "java.exe", f"-Duser.home={work}", "-cp",
                          os.pathsep.join(map(str, runtime_paths)), "PersonSnapshotProbe"],
                         work, "probe", name)
            output = result.stdout + result.stderr
            if name == "production":
                if result.returncode or any(marker not in result.stdout for marker in case["required_stdout"]):
                    raise RuntimeError("Native person production probe failed: " + output)
                receipt["results"].append({"case": name, "passed": True, "compiled": True})
                print("PASS native person production: all three former baseline assertions")
            else:
                if not result.returncode or case["expected"] not in output:
                    raise RuntimeError(f"Control {name} did not fail for {case['expected']}: {output}")
                receipt["results"].append({"case": name, "passed": True, "compiled": True,
                                           "reason": case["expected"]})
                print(f"CONTROL {name}: {case['expected']}")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?", type=pathlib.Path, default=ROOT)
    parser.add_argument("--receipt", type=pathlib.Path)
    parser.add_argument("--inventory", type=pathlib.Path)
    parser.add_argument("--check-inventory", action="store_true")
    args = parser.parse_args(argv)
    root = args.root.resolve()
    receipt = {"borders": [163, 169, 174], "results": [], "commands": []}
    start = time.perf_counter()
    try:
        path = args.inventory or root / "tools/native_person_cases.json"
        crosswalk = json.loads((root / "tools/native_person_crosswalk.json").read_text(encoding="utf-8-sig"))
        inventory = load_inventory(path, crosswalk)
        receipt["inventory_controls"] = inventory_controls(inventory, crosswalk)
        receipt["historical_controls"] = sum(HISTORICAL_CONTROLS.values())
        receipt["distinct_controls"] = len(inventory["controls"])
        receipt["inventory_sha256"] = digest(path.read_bytes())
        if args.check_inventory:
            receipt["status"] = "PASS"
            print("PASS native case inventory: 36 historical controls, 35 distinct controls, three baseline assertions; three inventory controls refuse")
        else:
            for relative in REQUIRED:
                if not (root / relative).is_file():
                    raise RuntimeError("Required native person source missing: " + relative)
            receipt["routing"] = routing(root)
            receipt["source_sha256"] = {name: digest((root / name).read_bytes()) for name in REQUIRED}
            if not all(path.is_file() for path in (PZ, JDK / "javac.exe", JDK / "java.exe")):
                receipt["status"] = "SKIPPED"
                print("SKIPPED native person VM: installed engine/JDK absent; inventory and source routing checked")
            else:
                execute(root, inventory, receipt)
                receipt["status"] = "PASS"
                print("  163) PASS -- native person continuation and dormant physiology (includes 169/174); 35 compiled controls")
    except (OSError, RuntimeError, ValueError, KeyError, TypeError, subprocess.TimeoutExpired) as error:
        receipt["status"] = "FAIL"
        receipt["error"] = str(error)
        print("FAULT " + str(error))
    receipt["seconds"] = time.perf_counter() - start
    if args.receipt:
        args.receipt.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    return 0 if receipt["status"] in ("PASS", "SKIPPED") else 1


if __name__ == "__main__":
    sys.exit(main())
