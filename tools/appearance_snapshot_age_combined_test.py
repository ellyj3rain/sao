#!/usr/bin/env python3
"""Installed headless v4 snapshot then production Kahlua age on one native body."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parent.parent
THIS = Path(__file__).resolve()
GAME = Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
JDK = Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
APPEARANCE = ROOT / "mod/42.20/media/lua/client/SAO_Appearance.lua"
SNAPSHOT = ROOT / "java/src/com/sao/engine/SAONativeSnapshot.java"
PROBE = ROOT / "tools/appearance_snapshot_age_combined/AppearanceSnapshotAgeProbe.java"
CASES = ROOT / "tools/appearance_snapshot_age_combined/cases.lua"
JAR = GAME / "projectzomboid.jar"
ZB = GAME / "ZombieBuddy.jar"
STDLIB = GAME / "stdlib.lua"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(argv: list[Path | str], work: Path, log: Path) -> dict:
    result = subprocess.run([str(arg) for arg in argv], cwd=work,
                            capture_output=True, text=True, encoding="utf-8",
                            errors="replace", timeout=120)
    log.write_text(result.stdout + result.stderr, encoding="utf-8")
    return {
        "exitCode": result.returncode,
        "passes": re.findall(r"(?m)^PASS (.+)$", result.stdout),
        "failures": re.findall(r"(?m)^FAIL (.+)$", result.stdout),
        "value": re.findall(r"(?m)^VALUE (.+)$", result.stdout),
        "logSha256": sha(log),
    }


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: appearance_snapshot_age_combined_test.py <new-output-dir>")
    out = Path(sys.argv[1]).resolve()
    out.mkdir(parents=True, exist_ok=False)
    pins = (THIS, APPEARANCE, SNAPSHOT, PROBE, CASES, JAR, ZB, STDLIB,
            JDK / "java.exe", JDK / "javac.exe")
    source_pins = {str(path): sha(path) for path in pins}
    shutil.copy2(STDLIB, out / "stdlib.lua")
    classes = out / "classes"
    classes.mkdir()
    cp = os.pathsep.join(map(str, (classes, JAR, ZB)))
    compile_result = run([JDK / "javac.exe", "-encoding", "UTF-8", "-cp",
                          os.pathsep.join(map(str, (JAR, ZB))), "-d", classes,
                          SNAPSHOT, PROBE], out, out / "compile.log")
    if compile_result["exitCode"]:
        print((out / "compile.log").read_text(encoding="utf-8"))
        return 2
    source = APPEARANCE.read_text(encoding="utf-8")
    controls = {
        "descriptor-instead-of-display": (
            "pcall(function() visual = body:getHumanVisual() end)",
            "pcall(function() visual = body:getDescriptor():getHumanVisual() end)",
            "combined/display-and-descriptor"),
        "omit-descriptor-alignment": (
            "    syncDisplay(body, visual)",
            "    -- omitted descriptor alignment",
            "combined/display-and-descriptor"),
        "overwrite-dye": (
            "    if current and not sameColour(current, base)\n"
            "        and not sameColour(current, previous)\n"
            "        and not sameColour(current, target) then return false, nil, false end",
            "    if false then return false, nil, false end",
            "choice/later-age-preserves-dye"),
        "invent-missing-age": (
            "    if not age then return false end",
            "    if not age then age = 45 end",
            "missing-age/refuses"),
    }

    def lua(name: str, path: Path, classpath: str = cp) -> dict:
        return run([JDK / "java.exe", f"-Duser.home={out}", "-cp", classpath,
                    "AppearanceSnapshotAgeProbe", path, CASES], out,
                   out / f"{name}.log")

    production = lua("production", APPEARANCE)
    inverses = {}
    for name, (needle, replacement, _) in controls.items():
        if source.count(needle) != 1:
            raise AssertionError(f"{name} anchor count is {source.count(needle)}")
        mutant = out / f"{name}.lua"
        mutant.write_text(source.replace(needle, replacement, 1), encoding="utf-8")
        inverses[name] = lua(name, mutant)

    snapshot_source = SNAPSHOT.read_text(encoding="utf-8")
    snapshot_needle = "        if (snapshot.schema() >= 4) restoreVisual(shell, sections[8]);"
    if snapshot_source.count(snapshot_needle) != 1:
        raise AssertionError("native visual restoration mutation anchor changed")
    snapshot_mutant = out / "SAONativeSnapshot.java"
    snapshot_mutant.write_text(snapshot_source.replace(snapshot_needle,
        "        if (snapshot.schema() >= 4) readVisual(sections[8]);", 1),
        encoding="utf-8")
    mutant_classes = out / "snapshot-mutant-classes"
    mutant_classes.mkdir()
    snapshot_compile = run([JDK / "javac.exe", "-encoding", "UTF-8", "-cp",
                            os.pathsep.join(map(str, (JAR, ZB))), "-d",
                            mutant_classes, snapshot_mutant, PROBE], out,
                           out / "snapshot-mutant-compile.log")
    snapshot_inverse = (lua("snapshot-omit-visual", APPEARANCE,
                            os.pathsep.join(map(str, (mutant_classes, JAR, ZB))))
                        if snapshot_compile["exitCode"] == 0 else None)

    expected_native = {"native/v4-capture", "native/new-body",
                       "native/stale-display-before-restore", "native/v4-restore",
                       "native/display-restored", "native/descriptor-distinct"}
    expected_lua = {"bridge/same-restored-native-body", "combined/age-after-v4-restore",
                    "combined/display-and-descriptor", "combined/same-age-idempotent",
                    "reload/v4-preserves-age-display", "reload/same-age-idempotent",
                    "reload/later-age-progresses", "reload/later-age-idempotent",
                    "choice/v4-preserves-dye", "choice/later-age-preserves-dye",
                    "missing-age/refuses"}
    if set(re.findall(r'check\("([^"]+)"', CASES.read_text(encoding="utf-8"))) != expected_lua:
        raise AssertionError("Lua case inventory drifted")
    good = (production["exitCode"] == 0 and production["failures"] == []
            and set(production["passes"]) == expected_native
            and production["value"] == [f"{len(expected_lua)}:"])
    for name, result in inverses.items():
        good = good and result["exitCode"] == 0
        good = good and len(result["value"]) == 1
        good = good and result["value"][0].startswith(f"{len(expected_lua)}:")
        good = good and controls[name][2] in result["value"][0]
        good = good and set(result["passes"]) == expected_native
    good = good and snapshot_inverse is not None
    if snapshot_inverse is not None:
        good = good and snapshot_inverse["exitCode"] != 0
        good = good and "native/display-restored" in (out / "snapshot-omit-visual.log").read_text(encoding="utf-8")
        good = good and {"native/v4-capture", "native/new-body",
                             "native/stale-display-before-restore",
                             "native/v4-restore"} == set(snapshot_inverse["passes"])
    good = good and source_pins == {str(path): sha(path) for path in pins}
    receipt = {
        "schema": "sao.appearance-snapshot-age-combined/1",
        "status": "PASS" if good else "FAIL",
        "boundary": "installed Project Zomboid JVM/Kahlua native IsoPlayer v4 component snapshot and production SAO_Appearance.applyAge on the same restored Java object; no rendered game, native saved game, deployed mod, peer acceptance, or full body performance",
        "sourcePins": source_pins,
        "production": production,
        "inverses": inverses,
        "snapshotVisualInverse": {"compile": snapshot_compile,
                                  "run": snapshot_inverse},
    }
    (out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n",
                                      encoding="utf-8")
    print("appearance snapshot age combined", receipt["status"])
    for name, result in [("production", production), *inverses.items()]:
        print(name, "exit", result["exitCode"], "pass", len(result["passes"]),
              "fail", result["failures"], "value", result["value"])
    return 0 if good else 1


if __name__ == "__main__":
    raise SystemExit(main())
