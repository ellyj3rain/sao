#!/usr/bin/env python3
"""Bounded Kahlua proof of SAO's saved Week One physical impact input."""
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
BWO = Path(r"C:\Program Files (x86)\Steam\steamapps\workshop\content\108600"
           r"\3403180543\mods\BanditsWeekOne\42.20\media\lua\shared\BWOEvents.lua")
BWO_GMD = BWO.with_name("BWOGMD.lua")
MODULE = ROOT / "mod/42.20/media/lua/client/SAO_WeekOneEvents.lua"
POPULATION = ROOT / "mod/42.20/media/lua/client/SAO_Population.lua"
CASES = ROOT / "tools/weekone_owned_impact_cases.lua"
RUNNER = ROOT / "tools/luacheck/LuaRun.java"
NATIVE_SIGNAL_USAGE = ROOT / "tools/world_lab/StudyWorld.lua"
NATIVE_SIGNAL_CONTROL = ROOT / "tools/world_lab_test.py"
JAR = GAME / "projectzomboid.jar"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: weekone_owned_impact_test.py <new-output-dir>")
    out = Path(sys.argv[1]).resolve()
    out.mkdir(parents=True, exist_ok=False)
    paths = [MODULE, POPULATION, CASES, RUNNER, NATIVE_SIGNAL_USAGE,
             NATIVE_SIGNAL_CONTROL, JAR, GAME / "stdlib.lua", BWO, BWO_GMD]
    before = {str(path): sha(path) for path in paths}
    shutil.copy2(GAME / "stdlib.lua", out / "stdlib.lua")
    classpath = str(JAR) + ";" + str(out)
    compiled = subprocess.run(
        [str(JDK / "javac.exe"), "-encoding", "UTF-8", "-cp", str(JAR),
         "-d", str(out), str(RUNNER)], cwd=out, capture_output=True,
        text=True, timeout=120)
    (out / "compile.log").write_text(compiled.stdout + compiled.stderr,
                                     encoding="utf-8")
    if compiled.returncode:
        print(compiled.stderr)
        return 2

    engine = subprocess.run(
        [str(JDK / "javap.exe"), "-classpath", str(JAR),
         "zombie.iso.objects.IsoTrap"], cwd=out, capture_output=True,
        text=True, timeout=30)
    (out / "isotrap-api.log").write_text(engine.stdout + engine.stderr,
                                         encoding="utf-8")
    api_pinned = engine.returncode == 0 and all(token in engine.stdout for token in (
        "IsoTrap(zombie.inventory.types.HandWeapon, zombie.iso.IsoCell, zombie.iso.IsoGridSquare)",
        "triggerExplosion(boolean)",
    ))
    source = MODULE.read_text(encoding="utf-8")
    population = POPULATION.read_text(encoding="utf-8")
    bwo = BWO.read_text(encoding="utf-8")
    bwo_gmd = BWO_GMD.read_text(encoding="utf-8")
    hook_pinned = all(token in population for token in (
        "SAO.WeekOneEvents.onDay(day)",
        'runSub("week-one-impact", function()',
        "SAO.WeekOneEvents.pollLoadedImpact()",
    )) and all(token in source for token in (
        "Events.OnInitGlobalModData.Add(W.onWorldData)",
        "Events.OnGameStart.Add(W.onStart)",
    ))
    prior_pinned = all(token in bwo for token in (
        "BWOEvents.BombDrop = function(params)",
        "IsoTrap.new(attacker, item, cell, square)",
        "trap:triggerExplosion(false)",
        'BWOScheduler.Add("JetFighterStage2", chunk, 10000 + d)',
    )) and all(token in bwo_gmd for token in (
        'ModData.getOrCreate("BanditWeekOne")',
        "globalData.QueryCache", "globalData.EventBuildings",
        "globalData.PlaceEvents", "globalData.Sandbox",
    ))
    native_signal_pinned = (
        'Events.OnInitGlobalModData.Add(function(isNewWorld)' in
        NATIVE_SIGNAL_USAGE.read_text(encoding="utf-8")
        and 'newGame = isNewWorld == true' in
        NATIVE_SIGNAL_USAGE.read_text(encoding="utf-8")
        and 'Events.OnNewGame.Add(function() if selected() then newGame = true end end)' in
        NATIVE_SIGNAL_CONTROL.read_text(encoding="utf-8")
    )

    controls = {
        "ignore-native-week-window": (
            "native < WEEK_HOURS", "true",
            "native-week-boundary/county-still-first-week"),
        "ignore-new-world-flag": (
            "newWorldSignal == true and native < WEEK_HOURS",
            "true and native < WEEK_HOURS",
            "preexisting-first-day-player/no-new-owner"),
        "ignore-missing-signal": (
            "if admit ~= true or newWorldSignal == nil then return nil end",
            "if admit ~= true then return nil end",
            "missing-native-world-signal/fails-closed"),
        "allow-pre-start-admission": (
            "if admit ~= true or newWorldSignal == nil then return nil end",
            "if newWorldSignal == nil then return nil end",
            "before-on-game-start/no-owner-committed"),
        "ignore-source-owner": (
            'row.producer = (active or footprint) and "BanditsWeekOne"',
            'row.producer = false and "BanditsWeekOne"',
            "source-active/source-owned-no-duplicate"),
        "lower-density-threshold": (
            "local MIN_CLUSTER = 5", "local MIN_CLUSTER = 4",
            "low-density/no-strike"),
        "ignore-terminal-status": (
            'if not row or row.status ~= "watching" then return false end',
            'if not row or false then return false end',
            "reload/terminal-impact-not-repeated"),
        "ignore-county-evidence": (
            "if #evidence == 0 then return false end",
            "if false then return false end",
            "no-county-evidence/no-actor-or-impact"),
        "force-positive-draw": (
            "local selected = roll < threshold",
            "local selected = true",
            "county-evidence/draw-can-refuse-impact"),
        "reroll-every-poll": (
            "if row.opportunity then return row.opportunity.selected == true end",
            "if false then return false end",
            "loaded-density/one-physical-impact"),
        "ignore-saved-source": (
            "local footprint = active == true and true or sourceFootprint()",
            "local footprint = false",
            "saved-bwo-then-uninstalled/source-ownership-preserved"),
    }

    def run(name: str, path: Path) -> dict:
        done = subprocess.run(
            [str(JDK / "java.exe"), "-cp", classpath, "LuaRun", CASES,
             path, "--", "fixtureCases()"], cwd=out, capture_output=True,
            text=True, timeout=120)
        log = out / (name + ".log")
        log.write_text(done.stdout + done.stderr, encoding="utf-8")
        return {"name": name, "exitCode": done.returncode,
                "pass": [x[5:] for x in done.stdout.splitlines()
                         if x.startswith("PASS ")],
                "fail": [x[5:] for x in done.stdout.splitlines()
                         if x.startswith("FAIL ")],
                "value": re.findall(r"(?m)^VALUE (.+)$", done.stdout),
                "logSha256": sha(log)}

    runs = [run("production", MODULE)]
    for name, (needle, replacement, _) in controls.items():
        if source.count(needle) != 1:
            raise AssertionError(f"{name}: mutation anchor count {source.count(needle)}")
        mutation = out / (name + ".lua")
        mutation.write_text(source.replace(needle, replacement), encoding="utf-8")
        runs.append(run(name, mutation))
    assert before == {str(path): sha(path) for path in paths}, "source changed during test"
    production = runs[0]
    verdict = api_pinned and hook_pinned and prior_pinned \
        and native_signal_pinned and production["exitCode"] == 0 \
        and production["value"] == ["38:"]
    for run_result in runs[1:]:
        expected = controls[run_result["name"]][2]
        verdict = verdict and run_result["exitCode"] == 0 \
            and len(run_result["value"]) == 1 \
            and expected in run_result["value"][0]
    receipt = {
        "schema": "sao.weekone-owned-impact/1",
        "status": "PASS" if verdict else "FAIL",
        "boundary": ("installed Kahlua executes production SAO event Lua with "
                     "synthetic native ports; installed JAR signatures and BWO "
                     "source pinned; no loaded game, save, sound, damage, NPC "
                     "reaction, aircraft or path observed"),
        "sourcePins": before,
        "engineApiPinned": api_pinned,
        "populationHooksPinned": hook_pinned,
        "bwoPriorPinned": prior_pinned,
        "nativeSignalPriorPinned": native_signal_pinned,
        "runs": runs,
    }
    (out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n",
                                      encoding="utf-8")
    for item in runs:
        print(item["name"], item["exitCode"], item["value"], item["fail"])
    return 0 if verdict else 1


if __name__ == "__main__":
    raise SystemExit(main())
