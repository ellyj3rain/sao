#!/usr/bin/env python3
"""Exercise the loaded Week One street-leg/home choice in installed Kahlua."""
from __future__ import annotations

import pathlib
import re
import subprocess
import tempfile

import dormant_spoken_access_test as spoken


SOURCE = spoken.CONTROLLER
EXPECTED = {
    "prefall_20_keeps_street", "prefall_21_low_roll_heads_home",
    "prefall_21_high_roll_stays_out", "afterfall_20_heads_home",
    "unknown_fall_uses_survival_night", "saved_home_request_has_priority",
    "saved_home_arrival_is_native_only", "ordinary_home_does_not_finish_request",
    "barred_home_is_not_entered", "unreachable_home_retries_later",
    "near_unrecognized_home_is_not_claimed", "designated_work_keeps_its_owner",
    "residence_purpose_keeps_its_owner",
}

HOST = r'''
__civil, __roll, __fall, __county = 20, 0, 'before', 18
__orders, __workCalls, __permitted, __routeReady = 0, 0, true, true
__inside, __known, __x, __y = false, false, 20, 0
SAO = {
    Standing = {fallHasCome = function()
        if __fall == 'after' then return true, 'calendar' end
        return false, __fall
    end},
    History = {countyHours = function() return __county end,
        streetAffinity = function(hour)
            if hour == 20 then return 1 end
            if hour == 21 then return 0.9 end
            if hour == 22 then return 0.7 end
            return 0.4
        end},
    Rand = {unit = function() return __roll end},
    ProceduralPlanning = {residencePurpose = function() return __residence end},
    Locomotion = {order = function(id, body, x, y, z)
        __orders = __orders + 1
        return true
    end},
    Identity = {get = function() return __rec end},
    Census = {rowOf = function() return {enginePath = 'nurse', label = 'nursing'} end},
    PopulationAdmissions = {workplaceFor = function()
        __workCalls = __workCalls + 1
        return {x = 80, y = 0}
    end},
}
SAOJavaBridge = {setForceEntry = function() return true end}
GameTime = {getInstance = function() return {
    getTimeOfDay = function() return __civil end,
    getHour = function() return math.floor(__civil) end,
} end}
__body = {getX = function() return __x end, getY = function() return __y end}
resolvedHomeAddress = function(id, rec) return rec.homeX, rec.homeY, rec.homeZ end
occupiesKnownHome = function() return __inside, __known end
mayEnterBelieved = function() return __permitted end
homeRouteReady = function() return __routeReady end
homeRouteNumber = function(n) return type(n) == 'number' end
setState = function(agent, id, mode) agent.state = mode return true end
'''

CASES = r'''
local checks = {}
local function check(name, condition) checks[name] = condition == true end
local function reset(hour, fall, roll)
    __civil, __fall, __roll = hour, fall, roll
    __orders, __workCalls = 0, 0
    __permitted, __routeReady = true, true
    __inside, __known, __x, __y = false, false, 20, 0
    __residence = nil
    __rec = {id = 'person', homeX = 0, homeY = 0, homeZ = 0,
        occupation = 'nurse'}
    __agent = {state = 'IDLE', rec = __rec}
end
reset(20, 'before', 0.99)
__decideHomeAndEquipment('person', __agent, __body, 100, __rec)
__decideRoam('person', __agent, __body, 100, 100, nil, __rec)
check('prefall_20_keeps_street', __orders == 0 and __workCalls == 1)

reset(21, 'before', 0.95)
__decideHomeAndEquipment('person', __agent, __body, 100, __rec)
__decideRoam('person', __agent, __body, 100, 100, nil, __rec)
check('prefall_21_low_roll_heads_home', __orders == 1
    and __agent.state == 'HOMEWARD' and __workCalls == 0)

reset(21, 'before', 0.1)
__decideHomeAndEquipment('person', __agent, __body, 100, __rec)
__decideRoam('person', __agent, __body, 100, 100, nil, __rec)
check('prefall_21_high_roll_stays_out', __orders == 0 and __workCalls == 1)

reset(20, 'after', 0.99)
__decideHomeAndEquipment('person', __agent, __body, 100, __rec)
check('afterfall_20_heads_home', __orders == 1 and __agent.state == 'HOMEWARD')

reset(20, 'unknown', 0.99)
__decideHomeAndEquipment('person', __agent, __body, 100, __rec)
check('unknown_fall_uses_survival_night', __orders == 1)

reset(20, 'before', 0.99)
__agent.weekOneHomeIntent = true
__rec.playerCompanionIntent = {mode = 'home'}
__decideHomeAndEquipment('person', __agent, __body, 100, __rec)
check('saved_home_request_has_priority', __orders == 1
    and __agent.state == 'HOMEWARD'
    and __rec.playerCompanionIntent.homeArrivedAtHours == nil)

reset(20, 'before', 0.99)
__agent.weekOneHomeIntent = true
__rec.playerCompanionIntent = {mode = 'home'}
__inside, __known = true, true
__decideHomeAndEquipment('person', __agent, __body, 100, __rec)
check('saved_home_arrival_is_native_only', __orders == 0
    and __agent.weekOneHomeIntent == nil
    and __rec.playerCompanionIntent.homeArrivedAtHours == __county)

reset(21, 'before', 0.95)
__rec.playerCompanionIntent = {mode = 'home'}
__inside, __known = true, true
__decideRoam('person', __agent, __body, 100, 100, nil, __rec)
check('ordinary_home_does_not_finish_request', __orders == 0
    and __rec.playerCompanionIntent.homeArrivedAtHours == nil)

reset(21, 'before', 0.95)
__permitted = false
__decideRoam('person', __agent, __body, 100, 100, nil, __rec)
check('barred_home_is_not_entered', __orders == 0)

reset(21, 'before', 0.95)
__routeReady = false
__decideRoam('person', __agent, __body, 100, 100, nil, __rec)
check('unreachable_home_retries_later', __orders == 0)

reset(21, 'before', 0.95)
__x, __known = 2, false
__decideRoam('person', __agent, __body, 100, 100, nil, __rec)
check('near_unrecognized_home_is_not_claimed', __orders == 0)

reset(21, 'before', 0.95)
__decideRoam('person', __agent, __body, 100, 100, 'watch', __rec)
check('designated_work_keeps_its_owner', __orders == 0 and __workCalls == 0)

reset(21, 'before', 0.95)
__residence = {id = 'moving-household'}
__decideRoam('person', __agent, __body, 100, 100, nil, __rec)
check('residence_purpose_keeps_its_owner', __orders == 0)

local rows = {}
for name, passed in pairs(checks) do rows[#rows + 1] = name .. '=' .. tostring(passed) end
table.sort(rows)
__result = table.concat(rows, ';')
'''


def functions(source: str) -> str:
    a = source.find("local function attemptKnownHome(")
    b = source.find("local function decideHomeAndEquipment(", a)
    c = source.find("    -- Gearing up:", b)
    d = source.find("local function decideRoam(", c)
    e = source.find("    local range = SAO.Disposition.roamRange", d)
    if min(a, b, c, d, e) < 0 or not a < b < c < d < e:
        raise ValueError("loaded evening source boundaries moved")
    return (source[a:b] + source[b:c] + "    return false\nend\n"
            + source[d:e] + "    return false\nend\n"
            + "__decideHomeAndEquipment = decideHomeAndEquipment\n"
            + "__decideRoam = decideRoam\n")


def run(work: pathlib.Path, source: str) -> tuple[dict[str, str], str]:
    (work / "host.lua").write_text(HOST, encoding="utf-8")
    (work / "functions.lua").write_text(functions(source), encoding="utf-8")
    (work / "cases.lua").write_text(CASES, encoding="utf-8")
    cmd = [str(spoken.JDK / "java.exe"), "-cp", f"{spoken.PZ};.", "LuaRun",
           str(work / "host.lua"), str(work / "functions.lua"),
           str(work / "cases.lua"), "--", "__result"]
    done = subprocess.run(cmd, cwd=work, capture_output=True, text=True, timeout=120)
    output = (done.stdout or "") + (done.stderr or "")
    return (dict(re.findall(r"([a-z0-9_]+)=(true|false)", output))
            if not done.returncode else {}), output


def main() -> int:
    if not all(path.is_file() for path in
               (SOURCE, spoken.PZ, spoken.STDLIB,
                spoken.JDK / "java.exe", spoken.JDK / "javac.exe")):
        print("SKIPPED Week One evening: installed engine or source unavailable")
        return 0
    source = SOURCE.read_text(encoding="utf-8")
    with tempfile.TemporaryDirectory(prefix="sao-weekone-evening-") as folder:
        work = pathlib.Path(folder)
        spoken.compile_runner(work)
        checks, output = run(work, source)
        if set(checks) != EXPECTED or any(value != "true" for value in checks.values()):
            print(f"FAIL Week One evening: checks={checks}\n{output[-3000:]}")
            return 1
        mutations = (
            ("blanket-twenty", 'ordinaryNight = not (okF and fallen == false and why == "before")',
             "ordinaryNight = true", "prefall_20_keeps_street"),
            ("lost-leg-home", 'attemptKnownHome(id, agent, body, agent.rec, false,\n'
             '                "chooses a homeward street leg")',
             'local noHomewardLeg = true', "prefall_21_low_roll_heads_home"),
            ("lost-companion-priority", '(requestedHome or ordinaryNight)\n'
             '            and attemptKnownHome', 'ordinaryNight\n'
             '            and attemptKnownHome', "saved_home_request_has_priority"),
        )
        for label, before, after, witness in mutations:
            if source.count(before) != 1:
                print(f"FAIL Week One evening: {label} control anchor")
                return 1
            altered, _ = run(work, source.replace(before, after, 1))
            if altered.get(witness) != "false":
                print(f"FAIL Week One evening: {label} control survived")
                return 1
    print(f"PASS Week One evening: {len(EXPECTED)} Kahlua cases, 3 controls")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
