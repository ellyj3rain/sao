#!/usr/bin/env python3
"""Qualify a single persisted strike owner in the shipped SAO Nuke module."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
GAME = Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
JDK = Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
SOURCE = ROOT / "mod/42.20/media/lua/client/SAO_Nuke.lua"
CASES = ROOT / "tools/weekone_nuke_owner_cases.lua"
RUNNER = ROOT / "tools/luacheck/LuaRun.java"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: weekone_nuke_owner_test.py <new-output-dir>")
    out = Path(sys.argv[1]).resolve()
    out.mkdir(parents=True, exist_ok=False)
    paths = [SOURCE, CASES, RUNNER, GAME / "projectzomboid.jar",
             GAME / "stdlib.lua"]
    before = {str(path): sha(path) for path in paths}
    shutil.copy2(GAME / "stdlib.lua", out / "stdlib.lua")
    classpath = str(GAME / "projectzomboid.jar") + ";" + str(out)
    compiled = subprocess.run(
        [str(JDK / "javac.exe"), "-encoding", "UTF-8", "-cp",
         str(GAME / "projectzomboid.jar"), "-d", str(out), str(RUNNER)],
        cwd=out, capture_output=True, text=True, timeout=120)
    (out / "compile.log").write_text(compiled.stdout + compiled.stderr,
                                      encoding="utf-8")
    if compiled.returncode:
        print(compiled.stderr)
        return 2

    source = SOURCE.read_text(encoding="utf-8")
    controls = {
        "ignore-weekone-choice": (
            "elseif weekOneSelected() then",
            "elseif false then",
            "weekone-priority/selected-on-first-day"),
        "invent-unselected-weekone-owner": (
            "elseif weekOneSelected() then",
            "elseif true then",
            "default-off/no-premature-weekone-owner"),
        "ignore-legacy-fate": (
            "if s.drawn or s.struck then",
            "if false then",
            "legacy-save/drawn-sao-owner"),
        "ignore-producer-guard": (
            'return producer(s) == "SAO" and saoSelected()',
            'return saoSelected()',
            "weekone-priority/selected-on-first-day"),
        "ignore-creator-none": (
            'or s.producer == "none" then',
            'then',
            "creator/none-survives-source-toggle"),
        "ignore-creator-provenance": (
            'if not creatorReceiptValid(choice, receipt) then',
            'if false then',
            "creator/foreign-receipt-refused"),
        "ignore-native-descriptor": (
            'or type(receipt.nativeDescriptorId) ~= "number"\n'
            '        or receipt.nativeDescriptorId < 0\n'
            '        or receipt.nativeDescriptorId % 1 ~= 0 then',
            'or false then',
            "creator/missing-native-descriptor-refused"),
        "ignore-seeded-descriptor-identity": (
            'and prior.playerKey == receipt.playerKey\n'
            '            and prior.nativeDescriptorId == receipt.nativeDescriptorId then',
            'and prior.playerKey == receipt.playerKey then',
            "creator/seeded-foreign-native-descriptor-refused"),
        "ignore-existing-world-owner": (
            'if (s.producer ~= nil and s.producer ~= choice)\n        or s.drawn or s.struck then',
            'if false then',
            "legacy/creator-cannot-override-world"),
        "ignore-pre-native-selector": (
            'if (s.producer ~= nil and s.producer ~= choice)',
            'if s.producer ~= nil',
            "creator/pre-native-selector-admits-same-choice"),
    }

    def run(name: str, path: Path) -> dict:
        done = subprocess.run(
            [str(JDK / "java.exe"), "-cp", classpath, "LuaRun", CASES,
             path, "--", "fixtureCases()"],
            cwd=out, capture_output=True, text=True, timeout=120)
        log = out / (name + ".log")
        log.write_text(done.stdout + done.stderr, encoding="utf-8")
        return {"name": name, "exitCode": done.returncode,
                "pass": [x[5:] for x in done.stdout.splitlines()
                         if x.startswith("PASS ")],
                "fail": [x[5:] for x in done.stdout.splitlines()
                         if x.startswith("FAIL ")],
                "value": re.findall(r"(?m)^VALUE (.+)$", done.stdout),
                "logSha256": sha(log)}

    runs = [run("production", SOURCE)]
    for name, (needle, replacement, _) in controls.items():
        assert source.count(needle) == 1, name
        mutation = out / (name + ".lua")
        mutation.write_text(source.replace(needle, replacement),
                            encoding="utf-8")
        runs.append(run(name, mutation))
    assert before == {str(path): sha(path) for path in paths}, "source changed during probe"
    production = runs[0]
    verdict = production["exitCode"] == 0 \
        and production["value"] == ["20:"]
    for result in runs[1:]:
        expected = controls[result["name"]][2]
        verdict = verdict and result["exitCode"] == 0 \
            and len(result["value"]) == 1 and expected in result["value"][0]
    receipt = {
        "schema": "sao.weekone-nuke-owner/1",
        "status": "PASS" if verdict else "FAIL",
        "boundary": "installed Kahlua executes production SAO strike authority with synthetic world options and ModData; no native game or save observed",
        "sourcePins": before,
        "runs": runs,
    }
    (out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n",
                                      encoding="utf-8")
    for run_result in runs:
        print(run_result["name"], run_result["exitCode"],
              run_result["value"])
    return 0 if verdict else 1


if __name__ == "__main__":
    raise SystemExit(main())
