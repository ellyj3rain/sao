#!/usr/bin/env python3
"""Execute the loaded IDLE decision tail, native night hold, and full roam."""
from __future__ import annotations

import pathlib
import re
import subprocess
import tempfile

import dormant_spoken_access_test as spoken


SOURCE = spoken.CONTROLLER
EXPECTED = {
    "prefall_22_no_work_out", "prefall_05_no_work_out",
    "prefall_22_seated_person_stands", "prefall_22_home_choice",
    "prefall_22_not_due_seats", "prefall_22_tired_sleeps",
    "prefall_22_sleep_preempts_street", "prefall_22_saved_home_wins",
    "postfall_22_keeps_night_hold", "postfall_22_does_not_start_cadence",
    "prefall_22_starts_cadence", "prefall_22_route_refusal_can_rest",
    "prefall_22_seated_refusal_reseats", "assigned_keeper_holds_watch",
    "postfall_keeper_is_assigned",
}

HOST = r'''
__civil, __roll, __fall = 22, 0, 'before'
__orders, __sleepOffers, __seat, __work = 0, 0, false, false
__routeReady, __inside, __x, __y = true, true, 0, 0
__county = 15
log = function() end
SAO = {
  Standing = {
    fallHasCome = function()
      if __fall == 'after' then return true, 'calendar' end
      return false, __fall
    end,
    groupOf = function() if __watch then return 'house' end end,
    larderOf = function() if __watch then return true end end,
    insideClaim = function() return false end,
    mayEnterBelieved = function() return true end,
  },
  History = {
    countyHours = function() return __county end,
    streetAffinity = function(hour)
      if hour >= 22 or hour < 6 then return 0.7 end
      return 0.4
    end,
    ageOf = function() return 30 end,
  },
  Rand = {unit = function() return __roll end,
      int = function() return 5 end},
  Identity = {get = function() return __rec end},
  Census = {rowOf = function()
      if __work then return {enginePath = 'nurse', label = 'nursing'} end
      return nil
  end},
  PopulationAdmissions = {workplaceFor = function()
      return {x = 80, y = 0}
  end},
  Disposition = {roamRange = function() return 10 end,
      roamInterval = function() return 100 end,
      circle = function() return 'loner' end},
  Lessons = {has = function() return false end},
  Perception = {believedThreatCount = function() return 0 end,
      believedFactionNear = function() return nil end},
  Locomotion = {order = function()
      __orders = __orders + 1
      __orderedWhileSeated = __seat
      return __routeReady
  end},
  Needs = {workAvailable = function() return false end,
      cold = function() return 0 end,
      read = function() return {fatigue = __fatigue} end,
      ownsRecoveryBody = function() return true end},
  Gesture = {seat = function() end, standUp = function() end},
  ProceduralPlanning = {residencePurpose = function() return nil end},
}
SAOJavaBridge = {setForceEntry = function() return true end,
    setShellAsleep = function() end}
GameTime = {getInstance = function() return {
    getTimeOfDay = function() return __civil end,
    getHour = function() return math.floor(__civil) end,
} end}
Ctl = {agents = {}, advancePersonalPurpose = function() return false end,
    offerRecovery = function(id, agent)
        __sleepOffers = __sleepOffers + 1
        agent.sleeping, agent.recovery = true, true
        return true
    end}
__body = {getX = function() return __x end,
    getY = function() return __y end,
    getZ = function() return 0 end,
    setSitOnGround = function(_, seated) __seat = seated end}
resolvedHomeAddress = function(id, rec) return rec.homeX, rec.homeY, rec.homeZ end
occupiesKnownHome = function() return __inside, __inside end
mayEnterBelieved = function() return true end
homeRouteReady = function() return __routeReady end
homeRouteNumber = function(n) return type(n) == 'number' end
setState = function(agent, id, mode) agent.state = mode return true end
nightKeeper = function() if __watch then return 'person' end end
decideRestActivity = function() return false end
decideLocalResources = function() return false end
decidePromiseAndSearch = function() return false end
'''

CASES = r'''
local checks = {}
local function check(name, condition) checks[name] = condition == true end
local function reset(hour, fall, roll)
    __civil, __fall, __roll = hour, fall, roll
    __county = (hour - 7 + 24) % 24
    __orders, __sleepOffers, __seat = 0, 0, false
    __orderedWhileSeated = nil
    __routeReady, __inside, __x, __y = true, true, 0, 0
    __work, __fatigue = false, 0.1
    __watch = false
    __rec = {id = 'person', homeX = 0, homeY = 0, homeZ = 0}
    __agent = {state = 'IDLE', rec = __rec, nextRoamAt = 100}
end

reset(22, 'before', 0.1)
__decisionTail('person', __agent, __body, 100, {fatigue = __fatigue})
check('prefall_22_no_work_out', __orders == 1
    and __agent.state == 'ROAM' and __agent.resting ~= true
    and __sleepOffers == 0)

reset(5, 'before', 0.1)
__decisionTail('person', __agent, __body, 100, {fatigue = __fatigue})
check('prefall_05_no_work_out', __orders == 1 and __agent.state == 'ROAM')

reset(22, 'before', 0.1)
__agent.resting, __seat = true, true
__decisionTail('person', __agent, __body, 100, {fatigue = __fatigue})
check('prefall_22_seated_person_stands', __orders == 1
    and __orderedWhileSeated == false and __seat == false
    and __agent.state == 'ROAM')

reset(22, 'before', 0.95)
__inside, __x = false, 20
__decisionTail('person', __agent, __body, 100, {fatigue = __fatigue})
check('prefall_22_home_choice', __orders == 1
    and __agent.state == 'HOMEWARD' and __sleepOffers == 0)

reset(22, 'before', 0.1)
__agent.nextRoamAt = 200
__decisionTail('person', __agent, __body, 100, {fatigue = __fatigue})
check('prefall_22_not_due_seats', __orders == 0
    and __agent.resting == true and __seat == true)

reset(22, 'before', 0.1)
__agent.nextRoamAt = nil
__decisionTail('person', __agent, __body, 100, {fatigue = __fatigue})
check('prefall_22_starts_cadence', __orders == 0
    and __agent.nextRoamAt == 200 and __agent.resting == true)

reset(22, 'before', 0.1)
__fatigue = 0.7
__decisionTail('person', __agent, __body, 100, {fatigue = __fatigue})
check('prefall_22_tired_sleeps', __orders == 0 and __sleepOffers == 1
    and __agent.sleeping == true and __agent.recovery == true)

reset(22, 'before', 0.1)
__agent.sleeping, __agent.resting = true, true
__fatigue = 0.7
__decisionTail('person', __agent, __body, 100, {fatigue = __fatigue})
check('prefall_22_sleep_preempts_street', __orders == 0
    and __agent.state == 'IDLE' and __sleepOffers == 1
    and __agent.sleeping == true)

reset(22, 'before', 0.1)
__inside, __x = false, 20
__agent.weekOneHomeIntent = true
__rec.playerCompanionIntent = {mode = 'home'}
__decisionTail('person', __agent, __body, 100, {fatigue = __fatigue})
check('prefall_22_saved_home_wins', __orders == 1
    and __agent.state == 'HOMEWARD' and __rec.playerCompanionIntent.homeArrivedAtHours == nil)

reset(22, 'before', 0.1)
__watch = true
__agent.keeperTonight = true
__agent.keeperNight = math.floor((__county + 2) / 24)
__decisionTail('person', __agent, __body, 100, {fatigue = __fatigue})
check('assigned_keeper_holds_watch', __orders == 0
    and __agent.state == 'IDLE' and __agent.resting == true
    and __agent.keeperTonight == true
    and __agent.pressure.answer == 'designation')

reset(22, 'after', 0.1)
__decisionTail('person', __agent, __body, 100, {fatigue = __fatigue})
check('postfall_22_keeps_night_hold', __orders == 0
    and __agent.resting == true and __seat == true)

reset(22, 'after', 0.1)
__watch = true
__decisionTail('person', __agent, __body, 100, {fatigue = __fatigue})
check('postfall_keeper_is_assigned', __orders == 0
    and __agent.keeperTonight == true and __agent.resting == true
    and __agent.pressure.answer == 'designation')

reset(22, 'after', 0.1)
__agent.nextRoamAt = nil
__decisionTail('person', __agent, __body, 100, {fatigue = __fatigue})
check('postfall_22_does_not_start_cadence', __orders == 0
    and __agent.nextRoamAt == nil and __agent.resting == true)

reset(22, 'before', 0.1)
__routeReady = false
__decisionTail('person', __agent, __body, 100, {fatigue = __fatigue})
check('prefall_22_route_refusal_can_rest', __orders == 1
    and __agent.state == 'IDLE' and __agent.resting == true)

reset(22, 'before', 0.1)
__routeReady = false
__agent.resting, __seat = true, true
__decisionTail('person', __agent, __body, 100, {fatigue = __fatigue})
check('prefall_22_seated_refusal_reseats', __orders == 1
    and __orderedWhileSeated == false and __agent.resting == true
    and __seat == true)

local rows = {}
for name, passed in pairs(checks) do rows[#rows + 1] = name .. '=' .. tostring(passed) end
table.sort(rows)
__result = table.concat(rows, ';')
'''


def functions(source: str) -> str:
    a = source.find("local function attemptKnownHome(")
    b = source.find("local function decideHomeAndEquipment(", a)
    c = source.find("    -- Gearing up:", b)
    n = source.find("local function decideNightAndDrift(", c)
    p = source.find("function Ctl.proposeLeisureParticipation(", n)
    r = source.find("local function decideRoam(", p)
    d = source.find("local function decide(", r)
    mark = source.find("    local rec = agent.rec\n    if decideHomeAndEquipment", d)
    tail_end = source.find("\nend\n\n-- The death sweep", mark)
    if min(a, b, c, n, p, r, d, mark, tail_end) < 0:
        raise ValueError("loaded night-order boundaries moved")
    return (source[a:b] + source[b:c] + "    return false\nend\n"
            + source[n:p] + source[r:d]
            + "function __decisionTail(id, agent, body, tick, needs)\n"
            + source[mark:tail_end] + "\nend\n")


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
        print("SKIPPED Week One night order: installed engine or source unavailable")
        return 0
    source = SOURCE.read_text(encoding="utf-8")
    with tempfile.TemporaryDirectory(prefix="sao-weekone-night-order-") as folder:
        work = pathlib.Path(folder)
        spoken.compile_runner(work)
        checks, output = run(work, source)
        if set(checks) != EXPECTED or any(value != "true" for value in checks.values()):
            print(f"FAIL Week One night order: checks={checks}\n{output[-4000:]}")
            return 1
        mutations = (
            ("night-preempts-street",
             "        if dueNightStreet then\n            if decideRoam",
             "        if false and dueNightStreet then\n            if decideRoam",
             "prefall_22_no_work_out"),
            ("night-vetoes-no-work",
             "            and not streetWork and not streetOut then",
             "            and not streetWork then",
             "prefall_22_no_work_out"),
            ("seat-blocks-route",
             "        if agent.resting and not agent.sleeping and not agent.recovery then",
             "        if false and agent.resting and not agent.sleeping and not agent.recovery then",
             "prefall_22_seated_person_stands"),
            ("keeper-abandons-watch",
             "            and not agent.keeperTonight\n            and not agent.recovery",
             "            and not agent.recovery",
             "assigned_keeper_holds_watch"),
        )
        for label, before, after, witness in mutations:
            if source.count(before) != 1:
                print(f"FAIL Week One night order: {label} control anchor")
                return 1
            altered, _ = run(work, source.replace(before, after, 1))
            if altered.get(witness) != "false":
                print(f"FAIL Week One night order: {label} control survived")
                return 1
    print(f"PASS Week One night order: {len(EXPECTED)} Kahlua cases, 4 controls")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
