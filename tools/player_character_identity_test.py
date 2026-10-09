#!/usr/bin/env python3
"""Exercise saved player character keys in the production Standing module."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
GAME = Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
JDK = Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
SOURCE = ROOT / "mod/42.20/media/lua/shared/SAO_Standing.lua"
CASES = ROOT / "tools/player_character_identity_cases.lua"
RUNNER = ROOT / "tools/luacheck/LuaRun.java"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: player_character_identity_test.py <new-output-dir>")
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
        "collapse-character-key": (
            'return account .. "/character/" .. characterId',
            'return account', "creator/distinct-character-keys"),
        "ignore-account-binding": (
            'or receipt.accountKey ~= account',
            'or false', "creator/foreign-account-receipt-refused"),
        "ignore-native-body": (
            'receipt.nativeDescriptorId ~= descriptorId',
            'false', "creator/stale-body-receipt-refused"),
        "ignore-world-binding": (
            'receipt.world ~= world',
            'false', "creator/stale-world-receipt-refused"),
        "ignore-active-observation": (
            'local activeKey, matched = activePlayerKey(name)',
            'local activeKey, matched = nil, false',
            "standing/observed-active-character"),
        "ignore-online-observation": (
            'if type(getOnlinePlayers) == "function" then',
            'if false then',
            "standing/observed-online-character"),
        "drop-legacy-key": (
            'if receipt == nil then return account end',
            'if receipt == nil then return nil end',
            "legacy/account-key-preserved"),
        "assume-failed-moddata-is-legacy": (
            'if not ok then return nil end',
            'if not ok then return account end',
            "legacy/failed-moddata-refused"),
        "allow-missing-native-descriptor": (
            'or type(descriptorId) ~= "number"\n        or descriptorId < 0\n        or descriptorId ~= math.floor(descriptorId)',
            'or false', "creator/missing-native-descriptor-refused"),
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
        count = source.count(needle)
        assert count == (2 if name == "ignore-active-observation" else 1), (name, count)
        mutation = out / (name + ".lua")
        mutation.write_text(source.replace(needle, replacement, 1),
                            encoding="utf-8")
        runs.append(run(name, mutation))
    assert before == {str(path): sha(path) for path in paths}, "source changed during probe"
    production = runs[0]
    verdict = production["exitCode"] == 0 and production["value"] == ["19:"]
    for result in runs[1:]:
        expected = controls[result["name"]][2]
        verdict = (verdict and result["exitCode"] == 0
                   and len(result["value"]) == 1
                   and expected in result["value"][0])
    receipt = {
        "schema": "sao.player-character-identity/1",
        "status": "PASS" if verdict else "FAIL",
        "boundary": "installed Kahlua executes production Standing with synthetic native player bodies, world and ModData; no game or save observed",
        "sourcePins": before,
        "runs": runs,
    }
    (out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n",
                                      encoding="utf-8")
    for result in runs:
        print(result["name"], result["exitCode"], result["value"])
    return 0 if verdict else 1


if __name__ == "__main__":
    raise SystemExit(main())
