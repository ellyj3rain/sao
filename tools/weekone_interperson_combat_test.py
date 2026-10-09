#!/usr/bin/env python3
"""Installed Kahlua proof of SAO owned interperson conflict for Week One proxies."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
P = Path(r"C:\Users\jleyv\Peanut Butter\AI Assisted Software Engineering Mass Repository\Projects\mod-patches")
GAME = Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
JDK = Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
BANDITS = Path(r"C:\Program Files (x86)\Steam\steamapps\workshop\content\108600\3268487204\mods\Bandits\42.20\media\lua")
SOURCE = ROOT / "mod/42.20/media/lua/client/SAO_WeekOneInterpersonCombat.lua"
CASES = ROOT / "tools/weekone_interperson_combat_cases.lua"
PATCH = P / "patches/011-weekone-interperson-combat/patch.lua"
RUNNER = ROOT / "tools/luacheck/LuaRun.java"
UPSTREAM = BANDITS / "shared/BanditUtils.lua"
OUT = ROOT / "_scratch/d2-leisure-01/weekone21/interperson-combat02.json"
EXPECTED_UPSTREAM = "ab65995505dd93e1cd6be0d4f8cf0eda973736fbd30f68f62a0af9203038cf69"
INVERSES = [
    ("source-relation", "if not firstMarked and not secondMarked then",
     "if true then", "source clan/global hostility still authorizes two SAO people"),
    ("standing-positive", "return firstHostile == true or secondHostile == true",
     "return false", "one SAO Standing conflict did not reach physical source action"),
    ("same-group", "or firstGroup ~= nil and firstGroup == secondGroup then",
     "or false then", "same SAO group received conflict permission"),
    ("reverse-standing", "or secondHostile == true",
     "or false", "one SAO Standing conflict did not reach physical source action"),
    ("body-birth", "or marker.SAOWeekOneBorn ~= brain.born",
     "or false", "changed source body retained person combat authority"),
    ("crosswalk", "if not exact or currentBody ~= body or currentBrain ~= brain then return nil end",
     "if false then return nil end", "lost SAO crosswalk retained person combat authority"),
    ("live-body", "or alive ~= true or type(marker) ~= \"table\"",
     "or false or type(marker) ~= \"table\"",
     "dead source proxy retained person combat authority"),
    ("same-person", "if firstId == secondId then return false end",
     "if false then return false end", "same SAO person could fight itself"),
    ("mixed-owner", "if not firstMarked or not secondMarked then\n        return false",
     "if not firstMarked or not secondMarked then\n        return original(brain1, brain2)",
     "mixed relation promoted a marked person's source hostility"),
]


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    for path in (SOURCE, CASES, PATCH, RUNNER, UPSTREAM,
                 GAME / "projectzomboid.jar", GAME / "stdlib.lua",
                 JDK / "java.exe", JDK / "javac.exe"):
        if not path.is_file():
            raise RuntimeError(f"missing installed input: {path}")
    if sha(UPSTREAM) != EXPECTED_UPSTREAM:
        raise RuntimeError("selected Bandits2 relation source drifted")
    source_text = UPSTREAM.read_text(encoding="utf-8-sig")
    assert "function BanditUtils.AreEnemies(brain1, brain2)" in source_text
    assert "brain1.clan ~= brain2.clan" in source_text
    assert "BanditUtils.AreEnemies(brainEnemy, brainBandit)" in (
        BANDITS / "shared/ZombieActions/ZASmack.lua").read_text(encoding="utf-8-sig")
    original = SOURCE.read_text(encoding="utf-8")
    receipt = {"status": "INCOMPLETE", "sourcePins": {
        str(path): sha(path) for path in (SOURCE, CASES, PATCH, RUNNER, UPSTREAM)},
        "boundary": "Installed Kahlua; native body transfer, save reload and multiplayer unobserved",
        "checks": []}
    with tempfile.TemporaryDirectory(prefix="sao-interperson-combat-") as temp:
        work = Path(temp)
        (work / "stdlib.lua").write_bytes((GAME / "stdlib.lua").read_bytes())
        build = subprocess.run([str(JDK / "javac.exe"), "-cp",
            str(GAME / "projectzomboid.jar"), "-d", str(work), str(RUNNER)],
            cwd=work, capture_output=True, text=True, timeout=120)
        if build.returncode:
            raise RuntimeError("installed Kahlua runner compile: " + build.stderr)

        def run(name: str, candidate: str) -> str:
            path = work / "candidate.lua"
            path.write_text(candidate, encoding="utf-8")
            done = subprocess.run([str(JDK / "java.exe"), "-cp",
                f"{GAME / 'projectzomboid.jar'};{work}", "LuaRun",
                str(CASES), str(path), str(PATCH), "--",
                "__safeInterpersonCombat()"], cwd=work,
                capture_output=True, text=True, timeout=120)
            output = done.stdout + done.stderr
            receipt["checks"].append({"name": name,
                "exitCode": done.returncode, "output": output[-1200:]})
            return output

        current = run("current", original)
        if "VALUE PASS" not in current:
            raise RuntimeError("current interperson proof failed: " + current)
        for name, before, after, expected in INVERSES:
            if original.count(before) != 1:
                raise RuntimeError(f"inverse anchor drift: {name}")
            output = run(name, original.replace(before, after, 1))
            if "VALUE FAIL:" not in output or expected not in output:
                raise RuntimeError(f"{name} missed claimed control: {output}")
    receipt["status"] = "PASS"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(f"PASS Week One interperson Standing, {len(receipt['checks']) - 1} inverses")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
