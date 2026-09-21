#!/usr/bin/env python3
"""Border 185 - measured dormant rest produces spoken access.

The production bodyless owner runs in Project Zomboid's Kahlua VM. It proves
clocked fatigue, rest, sleep, wake, movement exclusion and conversation
admission. Native snapshot routing and the loaded/bodyless handoff are checked
at their production boundaries; the normal Java build verifies engine types.
"""
from __future__ import annotations

import pathlib
import re
import shutil
import subprocess
import tempfile


ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
DORMANT = LUA / "client/SAO_DormantPopulation.lua"
COMMUNICATION = LUA / "shared/SAO_Communication.lua"
POPULATION = LUA / "client/SAO_Population.lua"
BODY = LUA / "client/SAO_Body.lua"
SNAPSHOT_LUA = LUA / "shared/SAO_BodySnapshot.lua"
CONTROLLER = LUA / "client/SAO_Controller.lua"
IDENTITY = LUA / "shared/SAO_Identity.lua"
SNAPSHOT_JAVA = ROOT / "java/src/com/sao/engine/SAONativeSnapshot.java"
BRIDGE = ROOT / "java/src/com/sao/bridge/SAOBridge.java"
CASES = ROOT / "tools/sweep/dormant_spoken_access_cases.lua"
RUNNER = ROOT / "tools/luacheck/LuaRun.java"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
GAME = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = GAME / "projectzomboid.jar"
STDLIB = GAME / "stdlib.lua"

EXPECTED = {
    "sleep_transition_at_22", "sleeping_movement_holds",
    "sleep_transition_blocks_encounter", "morning_wake_is_produced",
    "morning_wake_admits_encounter", "legacy_unknown_not_defaulted",
    "legacy_unknown_blocks_encounter", "native_state_is_acquired",
    "native_awake_law_advances", "saved_sleep_traits_change_fatigue",
}

PRELUDE = r'''
__now, __tick, __records = 0, 9000, {}
SAO = {
    Log = { line = function() end, tally = function() end },
    History = {
        countyHours = function() return __now end,
        countyTimeOfDay = function() return __now % 24 end,
    },
    Identity = {
        all = function() return __records end,
        get = function(id) return __records[tostring(id)] end,
    },
    Claims = { isHeld = function() return false end },
    Body = {
        get = function() return nil end,
        hasRepresentation = function() return false end,
    },
    Controller = { agents = {} },
    WorldSources = {
        reconcileReservations = function() end,
        ownsActor = function() return false end,
        pendingActionFor = function() return nil end,
    },
    Standing = {
        fallHasCome = function() return false, 'before' end,
        insideClaim = function() return false end,
    },
    Perception = { EARSHOT = 10 },
}
SandboxVars = { SurvivorAwareness = {} }
getSpecificPlayer = function() return nil end
SAOJavaBridge = {
    dormantAwakeFatiguePerHour = function() return 0.1242 end,
    hibernationRestState = function(self, packed)
        if packed == 'native-pack' then return 'AVAILABLE:0.6:0.4:0.7' end
        return 'UNKNOWN:fixture'
    end,
    hibernationHearingAccess = function(self, packed)
        if packed == 'native-pack' then return 'AVAILABLE:1.0' end
        return 'UNKNOWN:fixture'
    end,
    speechWeatherHearing = function() return 1.0 end,
}
'''


def static_checks() -> dict[str, bool]:
    population = POPULATION.read_text(encoding="utf-8")
    body = BODY.read_text(encoding="utf-8")
    capture = SNAPSHOT_LUA.read_text(encoding="utf-8")
    controller = CONTROLLER.read_text(encoding="utf-8")
    identity = IDENTITY.read_text(encoding="utf-8")
    native = SNAPSHOT_JAVA.read_text(encoding="utf-8")
    bridge = BRIDGE.read_text(encoding="utf-8")
    life_at = population.find('runSub("dormant-life", dormantLife, conf)')
    encounter_at = population.find('runSub("encounters", dormantEncounters)')
    awaken_at = body.find("SAOJavaBridge:awaken(body, rec.hibernation, elapsed)")
    apply_at = body.find("SAOJavaBridge:applyDormantRestState(")
    return {
        "life_precedes_encounter": 0 <= life_at < encounter_at,
        "overlay_follows_native_restore": 0 <= awaken_at < apply_at,
        "capture_refreshes_overlay": all(token in capture for token in (
            "hibernationRestState", 'dormantPhysiologyOrigin = "native-snapshot"',
            "dormantPhysiologyAtHours = captured.hours")),
        "loaded_sleep_reconstructs": all(token in controller for token in (
            "rec.dormantSleeping == true", "agent.sleeping = true",
            "agent.lastRestHours")),
        "generated_origin_is_explicit": all(token in identity for token in (
            'dormantPhysiologyOrigin = "generated-default"',
            "dormantFatigue = 0.0", "dormantEndurance = 1.0")),
        "native_read_is_bodyless": all(token in native for token in (
            "public static String restState", "snapshot.sections()[1]",
            "savedSleepNeed(snapshot.sections()[3])")),
        "native_apply_is_bounded": all(token in native for token in (
            "public static boolean applyRestState", "fatigue < 0.0",
            "endurance > 1.0")),
        "bridge_routes_measurement": all(token in bridge for token in (
            "hibernationRestState(Object packed)",
            "dormantAwakeFatiguePerHour()", "applyDormantRestState(")),
    }


def compile_runner(work: pathlib.Path) -> None:
    shutil.copy2(STDLIB, work / "stdlib.lua")
    result = subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(work), str(RUNNER)],
        capture_output=True, text=True, timeout=120)
    if result.returncode:
        raise RuntimeError((result.stderr or result.stdout)[-3000:])


def run_cases(work: pathlib.Path, dormant_text: str | None = None):
    prelude = work / "prelude.lua"
    prelude.write_text(PRELUDE, encoding="utf-8")
    dormant = DORMANT
    if dormant_text is not None:
        dormant = work / "SAO_DormantPopulation.lua"
        dormant.write_text(dormant_text, encoding="utf-8")
    probe = work / "cases.lua"
    probe.write_text(
        "local ok, result = pcall(function()\n"
        + CASES.read_text(encoding="utf-8")
        + "\nend)\n__result = ok and result or ('ERROR: ' .. tostring(result))\n",
        encoding="utf-8")
    result = subprocess.run(
        [str(JDK / "java.exe"), "-cp", f"{PZ};.", "LuaRun",
         str(prelude), str(SNAPSHOT_LUA), str(dormant), str(COMMUNICATION),
         str(probe), "--", "__result"],
        cwd=work, capture_output=True, text=True, timeout=120)
    output = (result.stdout or "") + (result.stderr or "")
    lines = (result.stdout or "").strip().splitlines()
    value = lines[-1][6:] if lines and lines[-1].startswith("VALUE ") else ""
    checks = dict(re.findall(r"([a-z0-9_]+)=(true|false)", value))
    return checks, output


def main() -> int:
    required = (DORMANT, COMMUNICATION, POPULATION, BODY, SNAPSHOT_LUA,
                CONTROLLER, IDENTITY, SNAPSHOT_JAVA, BRIDGE, CASES, RUNNER)
    missing = [str(path.relative_to(ROOT)) for path in required if not path.is_file()]
    if missing:
        print(f"FAULT missing dormant spoken-access inputs: {missing}")
        return 1
    anchors = static_checks()
    if not all(anchors.values()):
        print(f"FAULT dormant spoken-access integration: {anchors}")
        return 1
    # Known-bad static controls: encounter-before-life and applying the overlay
    # before native restoration must each invalidate their corresponding seam.
    population = POPULATION.read_text(encoding="utf-8")
    swapped = population.replace(
        'runSub("dormant-life", dormantLife, conf)',
        'runSub("late-dormant-life", dormantLife, conf)', 1)
    body = BODY.read_text(encoding="utf-8")
    no_apply = body.replace("SAOJavaBridge:applyDormantRestState(",
                            "SAOJavaBridge:missingDormantRestState(", 1)
    if swapped == population or no_apply == body:
        print("FAULT dormant spoken-access static control anchor")
        return 1
    if ('runSub("dormant-life", dormantLife, conf)' in swapped
            or "SAOJavaBridge:applyDormantRestState(" in no_apply):
        print("FAULT dormant spoken-access static control survived")
        return 1
    print(f"Border 185 PASS: {len(anchors)} dormant spoken-access integration anchors and 2 controls")

    if not all(path.is_file() for path in
               (PZ, STDLIB, JDK / "java.exe", JDK / "javac.exe")):
        print("SKIPPED dormant spoken-access Kahlua VM: installed engine/JDK absent")
        return 0
    with tempfile.TemporaryDirectory(prefix="sao-dormant-spoken-") as temporary:
        work = pathlib.Path(temporary)
        compile_runner(work)
        checks, detail = run_cases(work)
        failed = sorted(name for name, value in checks.items() if value != "true")
        if set(checks) != EXPECTED or failed:
            print(f"FAULT dormant spoken-access cases missing={sorted(EXPECTED-set(checks))} "
                  f"extra={sorted(set(checks)-EXPECTED)} failed={failed}")
            print(detail[-4000:])
            return 1
        print(f"PASS {len(checks)} production dormant spoken-access cases")

        original = DORMANT.read_text(encoding="utf-8")
        mutations = (
            ("sleep-state-write", "rec.dormantSleeping = sleeping",
             "rec.dormantSleeping = false", "sleep_transition_at_22"),
            ("legacy-default", 'and rec.dormantPhysiologyOrigin == "generated-default" then',
             "and true then", "legacy_unknown_not_defaulted"),
            ("sleep-recovery", "math.max(0, fatigue - hours / 8.0)",
             "math.max(0, fatigue)", "morning_wake_is_produced"),
        )
        for name, before, after, expected in mutations:
            if original.count(before) != 1:
                print(f"FAULT dormant spoken-access mutation anchor: {name}")
                return 1
            altered, detail = run_cases(work, original.replace(before, after, 1))
            if set(altered) != EXPECTED or altered.get(expected) != "false":
                print(f"FAULT dormant spoken-access mutation survived: {name} -> {expected}")
                print(detail[-4000:])
                return 1
            print(f"CONTROL {name}: {expected}=false")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
