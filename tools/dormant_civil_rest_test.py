#!/usr/bin/env python3
"""Run actual History and Dormant rest across native and catch-up civil time."""
from __future__ import annotations

import pathlib
import re
import subprocess
import tempfile

import dormant_spoken_access_test as spoken


HISTORY = spoken.LUA / "shared/SAO_History.lua"
EXPECTED = {
    "live_22_sleeps", "live_05_still_sleeps", "live_06_wakes",
    "live_noon_awake", "live_13_awake", "historical_22_sleeps",
    "historical_without_native_civil_sleeps", "join_recalculates_phase",
    "missing_live_civil_holds_state", "equal_hour_join_wakes",
    "equal_hour_join_does_not_charge", "equal_hour_repoll_is_idempotent",
    "equal_hour_missing_civil_holds_state",
}

HOST = spoken.PRELUDE + r'''
__behind, __hours, __civil = 0, 0, 7
__store = {}
ModData = {getOrCreate = function() return __store end}
GameTime = {getInstance = function() return {
    getWorldAgeHours = function() return __hours end,
    getTimeOfDay = function() return __civil end,
} end}
SAOJavaBridge.daysBehindAtStart = function() return __behind end
SAO.History = {}
'''

CASES = r'''
local H, D = SAO.History, SAO.DormantPopulation
local checks = {}
local function check(name, condition) checks[name] = condition == true end
local function close(a, b) return math.abs(a - b) < 0.00001 end
local function person(id, last)
    return {id = id, x = 0, y = 0, homeX = 0, homeY = 0,
        dormantPhysiologyOrigin = 'generated-default',
        dormantFatigue = 0.8, dormantEndurance = 1,
        dormantSleepNeed = 1, dormantPhysiologyAtHours = last,
        dormantSleeping = false}
end
local function world(store, behind, age, civil)
    __store, __behind, __hours, __civil = store, behind, age, civil
    H.rebindWorld()
end

world({}, 0, 15, 22)
local evening = person('evening', 14.9)
check('live_22_sleeps', D.advanceRest('evening', evening, 15)
    and evening.dormantSleeping == true and evening.dormantResting == true)
world({}, 0, 22, 5)
local predawn = person('predawn', 21.9)
check('live_05_still_sleeps', D.advanceRest('predawn', predawn, 22)
    and predawn.dormantSleeping == true)
world({}, 0, 23, 6)
check('live_06_wakes', D.advanceRest('predawn', predawn, 23)
    and predawn.dormantSleeping == false and predawn.dormantResting == nil)
world({}, 0, 5, 12)
local noon = person('noon', 4.9)
check('live_noon_awake', D.advanceRest('noon', noon, 5)
    and noon.dormantSleeping == false and noon.dormantResting == nil)
world({}, 0, 6, 13)
local one = person('one', 5.9)
check('live_13_awake', D.advanceRest('one', one, 6)
    and one.dormantSleeping == false and one.dormantResting == nil)

world({yearsAsked = true, yearsRun = 0, yearsOwed = 10,
    yearsTicks = 23 * 9000}, 10, 0, nil)
local old = person('old', 22)
check('historical_22_sleeps', D.advanceRest('old', old, 23)
    and old.dormantSleeping == true)
check('historical_without_native_civil_sleeps', old.dormantResting == true)

world({yearsAsked = true, yearsRun = 10, yearsOwed = 10,
    yearsTicks = 240 * 9000}, 10, 2, 9)
local crossing = person('crossing', 239)
check('join_recalculates_phase', D.advanceRest('crossing', crossing, 242)
    and close(crossing.dormantFatigue, 0.74952)
    and crossing.dormantSleeping == false
    and crossing.dormantResting == nil)

world({yearsAsked = true, yearsRun = 9, yearsOwed = 10,
    yearsTicks = 240 * 9000}, 10, 0, nil)
local same = person('same', 240)
same.dormantSleeping, same.dormantResting = true, true
local oldFatigue, oldEndurance = same.dormantFatigue, same.dormantEndurance
-- The stored final historical midnight and first live 07:00 are both 240.
world({yearsAsked = true, yearsRun = 10, yearsOwed = 10,
    yearsTicks = 240 * 9000}, 10, 0, 7)
check('equal_hour_join_wakes', D.advanceRest('same', same, 240)
    and same.dormantSleeping == false and same.dormantResting == nil)
check('equal_hour_join_does_not_charge',
    same.dormantPhysiologyAtHours == 240
    and same.dormantFatigue == oldFatigue
    and same.dormantEndurance == oldEndurance)
check('equal_hour_repoll_is_idempotent', D.advanceRest('same', same, 240)
    and same.dormantSleeping == false and same.dormantResting == nil
    and same.dormantPhysiologyAtHours == 240
    and same.dormantFatigue == oldFatigue
    and same.dormantEndurance == oldEndurance)
world({yearsAsked = true, yearsRun = 10, yearsOwed = 10,
    yearsTicks = 240 * 9000}, 10, 0, nil)
local held = person('held', 240)
held.dormantSleeping, held.dormantResting = true, true
check('equal_hour_missing_civil_holds_state',
    D.advanceRest('held', held, 240) == false
    and held.dormantSleeping == true and held.dormantResting == true
    and held.dormantFatigue == 0.8 and held.dormantPhysiologyAtHours == 240)

world({}, 0, 16, nil)
local unknown = person('unknown', 15)
check('missing_live_civil_holds_state',
    D.advanceRest('unknown', unknown, 16) == false
    and unknown.dormantPhysiologyAtHours == 15
    and unknown.dormantFatigue == 0.8
    and unknown.dormantSleeping == false)

local rows = {}
for name, passed in pairs(checks) do rows[#rows + 1] = name .. '=' .. tostring(passed) end
table.sort(rows)
__result = table.concat(rows, ';')
'''


def run(work: pathlib.Path, dormant: pathlib.Path) -> tuple[dict[str, str], str]:
    host = work / "host.lua"
    cases = work / "cases.lua"
    host.write_text(HOST, encoding="utf-8")
    cases.write_text(CASES, encoding="utf-8")
    cmd = [str(spoken.JDK / "java.exe"), "-cp", f"{spoken.PZ};.", "LuaRun",
           str(host), str(HISTORY), str(dormant), str(cases), "--", "__result"]
    done = subprocess.run(cmd, cwd=work, capture_output=True, text=True, timeout=120)
    output = (done.stdout or "") + (done.stderr or "")
    rows = dict(re.findall(r"([a-z0-9_]+)=(true|false)", output))
    if done.returncode:
        return {}, output
    return rows, output


def main() -> int:
    if not all(path.is_file() for path in
               (HISTORY, spoken.DORMANT, spoken.PZ, spoken.STDLIB,
                spoken.JDK / "java.exe", spoken.JDK / "javac.exe")):
        print("SKIPPED dormant civil rest: installed engine or source unavailable")
        return 0
    with tempfile.TemporaryDirectory(prefix="sao-dormant-civil-") as folder:
        work = pathlib.Path(folder)
        spoken.compile_runner(work)
        checks, output = run(work, spoken.DORMANT)
        if set(checks) != EXPECTED or any(value != "true" for value in checks.values()):
            print(f"FAIL dormant civil rest: checks={checks}\n{output[-3000:]}")
            return 1
        source = spoken.DORMANT.read_text(encoding="utf-8")
        before = "return join and math.min(boundary, join) or boundary"
        if source.count(before) != 1:
            print("FAIL dormant civil rest: join-clamp control anchor")
            return 1
        mutated = work / "no-join-clamp.lua"
        mutated.write_text(source.replace(before, "return boundary", 1),
                           encoding="utf-8")
        altered, _ = run(work, mutated)
        if altered.get("join_recalculates_phase") != "false":
            print("FAIL dormant civil rest: join-clamp control survived")
            return 1
        early = "if nowHours == last then return true end"
        anchor = "    local sleeping = rec.dormantSleeping"
        if source.count(anchor) != 1:
            print("FAIL dormant civil rest: equal-hour control anchor")
            return 1
        mutated.write_text(source.replace(anchor, "    " + early + "\n\n" + anchor, 1),
                           encoding="utf-8")
        altered, _ = run(work, mutated)
        if altered.get("equal_hour_join_wakes") != "false":
            print("FAIL dormant civil rest: equal-hour control survived")
            return 1
    print(f"PASS dormant civil rest: {len(EXPECTED)} Kahlua cases, 2 controls")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
