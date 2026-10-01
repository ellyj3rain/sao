#!/usr/bin/env python3
r"""Border 82 - the seat and the mesh move together; the follow crosses.

The operator's report, verbatim shape: the survivor could not enter a
vehicle at all, there was no order to ask them to, and a failed action
had once left a driven truck with no visible driver who could not
exit. And the follower could not go through a window the player had
just climbed - the neighbour framework's people could.

The walk found the mechanisms: `enter()` was called bare, without the
mesh placement vanilla's own ISEnterVehicle pairs it with, and exit
without the "outside" placement; the route supervisor had no branch
for a hoppable edge, so a fence was an eternal unnamed stall
("stalled:ManualRoute"); `riding` lived only on the runtime agent
table and was lost at re-adoption, leaving seated bodies running walk
orders from inside a car.

WHAT THIS HOLDS
---------------
  1. Every enter() is paired: seat claim, mesh "inside", verification,
     rollback through exit() on failure - and seat 0 is never taken.
  2. Every exit() is paired: seat read first, then "outside" placement.
  3. The route supervisor has the hoppable-edge branch - a fence is a
     crossing (climbOverFence), never a stall.
  4. The follow can work the edge its target crossed: traverseToward
     exists Java-side and the Controller reaches it (followTraverse).
  5. The riding flag is reconciled from the seat truth in BOTH
     directions in the Controller.
  6. Native human input and NPC movement use the same rendered-animation
     strafe basis. The installed input branch supplies the comparison;
     restoring the missing quarter-turn must fail that comparison.

An optional argv[1] points the checker at another tree root, which is
how the control runs against the pre-fix state.
"""
import pathlib
import argparse
import hashlib
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 and not sys.argv[1].startswith("--") \
    else pathlib.Path(__file__).resolve().parent.parent

NEEDS = ROOT / "java" / "src" / "com" / "sao" / "engine" / "SAONeeds.java"
MOVE = ROOT / "java" / "src" / "com" / "sao" / "engine" / "SAOMovement.java"
CTL = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Controller.lua"
ROUTE = pathlib.Path("java/src/com/sao/engine/SAORouteState.java")
MOVEMENT = pathlib.Path("java/src/com/sao/engine/SAOMovement.java")
PROBE = pathlib.Path("tools/luacheck/MovementCrossingProbe.java")
MOTION_PROBE = pathlib.Path("tools/luacheck/MotionIntentProbe.java")
CONTROLLER = pathlib.Path("mod/42.20/media/lua/client/SAO_Controller.lua")
LOCOMOTION = pathlib.Path("mod/42.20/media/lua/client/SAO_Locomotion.lua")
LUA_RUNNER = pathlib.Path("tools/luacheck/LuaRun.java")
CONTROLLER_FIXTURE = pathlib.Path("tools/flee_continuity_test.py")
GAME = pathlib.Path(os.environ.get("PZ_DIR", r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"))
JDK = pathlib.Path(os.environ.get("JDK_BIN", r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"))


def changed(source, before, after):
    if source.count(before) != 1:
        raise AssertionError("crossing mutation target drifted: " + before)
    return source.replace(before, after, 1)


def crossing_controls(move, route):
    yield "old-boolean-only-guard", MOVEMENT, changed(move,
        "return shell.isClimbing()\n"
        "            || shell.getCurrentState() == ClimbOverFenceState.instance()\n"
        "            || shell.getCurrentState() == ClimbThroughWindowState.instance();",
        "return shell.isClimbing();"), "ClimbOverFenceState_holds_arrival"
    old = """    private static String driveCapturedRoute(SAOIsoPlayerShell shell, SAORouteState state) {
        String crossing = yieldCrossing(shell, state);
        if (crossing != null) return crossing;
"""
    late = changed(move, old, "    private static String driveCapturedRoute(SAOIsoPlayerShell shell, SAORouteState state) {\n")
    late = changed(late, "        String transition = handleRouteTransition(shell, state, node);",
        "        String crossing = yieldCrossing(shell, state);\n"
        "        if (crossing != null) return crossing;\n"
        "        String transition = handleRouteTransition(shell, state, node);")
    yield "guard-after-arrival", MOVEMENT, late, "ClimbOverFenceState_holds_arrival"
    yield "capture-native-pending-route", MOVEMENT, changed(move,
        "        crossing = yieldCrossing(shell, state);\n        if (crossing != null) return crossing;\n",
        ""), "native_update_pending_route_not_captured"
    yield "ignore-native-pending-event", MOVEMENT, changed(move,
        "if (shell.getActionContext().hasEventOccurred(event)) {\n                state.pendingCrossingEvent = event;",
        "if (false) {\n                state.pendingCrossingEvent = event;"), "EventClimbFence_pending_does_not_arrive"
    yield "unentered-request-is-success", MOVEMENT, changed(move,
        'return "FAILED_CROSSING_NOT_ENTERED";', "return null;"), "EventClimbFence_unentered_request_fails"
    yield "refused-call-is-started", MOVEMENT, changed(move,
        "        return refused;", "        return accepted;"), "native_fence_refusal_not_started"
    yield "skip-post-exit-projection", MOVEMENT, changed(move,
        "if (state.realignAfterCrossing && !realignAfterCrossing(shell, state))",
        "if (false && !realignAfterCrossing(shell, state))"), "native_exit_projects_forward"
    yield "ignore-native-projection-refusal", MOVEMENT, changed(move,
        "                if (!Float.isFinite(NativeRoutePoint.X.getFloat(point))\n"
        "                        || !Float.isFinite(NativeRoutePoint.Y.getFloat(point))) return false;\n",
        ""), "native_projection_collision_not_skipped"
    yield "relax-blocked-diagonal", MOVEMENT, changed(move,
        'return current.isBlockedTo(next) ? "FAILED_BLOCKED_DIAGONAL" : "CLEAR";',
        'return "CLEAR";'), "ClimbOverFenceState_exit_keeps_diagonal_block"
    yield "carry-old-crossing-owner", ROUTE, changed(route,
        "        pendingCrossingEvent = null;\n        crossingObserved = false;\n        realignAfterCrossing = false;\n",
        ""), "cleared_route_does_not_inherit_pending"


def motion_checks(root, work, classes, java, live_cp, move, receipt, run, baseline_only):
    result = run([*java, "-cp", live_cp, "MotionIntentProbe"], work, "motion-production")
    if result.returncode or "MOTION INTENT PASS parityCases=64" not in result.stdout:
        raise AssertionError(result.stdout + result.stderr)
    receipt["motionChecks"] = [line.removeprefix("CHECK ").removesuffix("=true")
        for line in result.stdout.splitlines() if line.startswith("CHECK ") and line.endswith("=true")]
    receipt["motionParityCases"] = 64
    print("PASS native human/NPC movement basis: 64 angle/direction cases; "
        + str(len(receipt["motionChecks"])) + " checks", flush=True)
    receipt["motionControls"] = []
    if baseline_only:
        return
    controls = [
        ("original-animation-basis-mismatch", changed(move,
            "float animAngle = shell.getAnimAngleRadians() + (float) (Math.PI / 2);",
            "float animAngle = shell.getAnimAngleRadians();"), "native_control_basis_0_0"),
        ("direction-angle-radians-in-degree-setter", changed(move,
            "shell.setDirectionAngle((float) Math.toDegrees(Math.atan2(dirY, dirX)));",
            "shell.setDirectionAngle((float) Math.atan2(dirY, dirX));"), "native_direction_degrees_0_1"),
    ]
    for label, source, marker in controls:
        directory = work / label; directory.mkdir()
        code = directory / "SAOMovement.java"; code.write_text(source, encoding="utf-8")
        output = directory / "classes"; output.mkdir()
        compiled = run([JDK / "javac.exe", "-encoding", "UTF-8", "-cp", live_cp,
            "-d", output, code], directory, label + "-compile")
        if compiled.returncode:
            raise AssertionError(compiled.stdout + compiled.stderr)
        result = run([*java, "-cp", str(output) + os.pathsep + live_cp, "MotionIntentProbe"], directory, label)
        if result.returncode != 1 or f"CHECK {marker}=false" not in result.stdout:
            raise AssertionError("motion control did not reject its defect: " + label
                + "\n" + result.stdout + result.stderr)
        receipt["motionControls"].append(dict(name=label, rejected=True, marker=marker, exit=result.returncode))
        print("PASS control refused: " + label, flush=True)


OBSTACLE_PROBE = r'''
local checks={}
local function check(name,ok)
 if not ok then error('OBSTACLE_CHECK:'..name) end
 checks[#checks+1]=name
end
local function fixture(verdict,force,needs)
 __starts=0;__cancels=0;__batter=0;__forcing=0;__decisions=0;__cleared=0
 __verdict=verdict;__messages={};__injury=0;__player=nil
 local b={}
 function b:getX() return 10.5 end
 function b:getY() return 20.5 end
 function b:getZ() return 0 end
 function b:getVehicle() return nil end
 function b:isDead() return false end
 function SAO.Log.line(_,msg) __messages[#__messages+1]=msg end
 function SAO.Standing.claimedByOther() return nil end
 function SAO.Needs.hunger() return 0 end
 function SAO.Needs.read() return needs end
 function SAO.Needs.clearGear() __cleared=__cleared+1 end
 function SAO.Disposition.wouldForceEntry(_,flee,pressing)
  __decisions=__decisions+1;__pressing=pressing;return force
 end
 function SAOJavaBridge:batterBarrier(body,x,y)
  check('batter_retains_original_goal',body==b and x==11 and y==20)
  __batter=__batter+1;return 'DOOR'
 end
 function SAOJavaBridge:setForceEntry(_,value)
  if value then __forcing=__forcing+1 end
 end
 SAO.Locomotion.jobs={};__bodies={runner=b}
 local a={state='GEARWARD',rec={id='runner'},batterTries=2}
 SAO.Controller.agents={runner=a}
 SAO.Controller.__obstacleTick(100)
 check('initial_job_admitted',SAO.Locomotion.order('runner',b,11,20,0))
 local job=SAO.Locomotion.jobs.runner
 SAO.Locomotion.tick('runner')
 check('terminal_wire_'..verdict,SAO.Locomotion.status('runner')=='done:'..verdict)
 check('movement_consumer_called',SAO.Controller.__obstacleMovement('runner',a,b)==true)
 local refused=false
 for _,msg in ipairs(__messages) do
  if msg:find('declined forcing a locked door',1,true) then refused=true end
 end
 return a,job,refused
end
local function run(name,verdict,kind)
 for _,force in ipairs({false,true}) do
  local a,job,refused=fixture(verdict,force)
  local label=name..(force and '_force' or '_refuse')
  if kind=='none' then
   check(label..'_not_a_lock',__decisions==0 and __batter==0 and __forcing==0 and not refused)
   check(label..'_ordinary_failure',a.state=='IDLE' and __cleared==1
    and __starts==1 and a.batterTries==0)
  elseif force then
   check(label..'_force_retained',__decisions==1 and not refused
    and __batter==(kind=='barrier' and 1 or 0)
    and __forcing==(kind=='window' and 1 or 0))
   check(label..'_route_retried',a.state=='GEARWARD' and __starts==2 and __cleared==0
    and a.batterTries==3 and SAO.Locomotion.jobs.runner~=job)
  else
   check(label..'_refusal_retained',__decisions==1 and refused and __batter==0 and __forcing==0
    and a.state=='IDLE' and __cleared==1 and __starts==1 and a.batterTries==0)
  end
 end
end
run('blocked_diagonal',__nativeVerdicts.blocked_diagonal,'none')
run('locked_door',__nativeVerdicts.locked_door,'barrier')
run('barricaded_door',__nativeVerdicts.barricaded_door,'barrier')
run('barricaded_window',__nativeVerdicts.barricaded_window,'barrier')
run('window_declined',__nativeVerdicts.window_declined,'window')
fixture(__nativeVerdicts.locked_door,false,{hunger=.1,thirst=.2})
check('ordinary_needs_not_desperation',__pressing==0)
fixture(__nativeVerdicts.locked_door,false,{hunger=.99,thirst=.2})
check('hunger_desperation_retained',__pressing==.5)
fixture(__nativeVerdicts.locked_door,false,{hunger=.1,thirst=.99})
check('thirst_desperation_admitted',__pressing==.5)
fixture(__nativeVerdicts.locked_door,false,{hunger=.99,thirst=.99})
check('urgent_needs_not_double_counted',__pressing==.5)
-- Boundary cases are intentionally synthetic; real producer verdicts above
-- establish the native vocabulary. A malformed extension is not that code.
for _,code in ipairs({'FAILED_BLOCKED_WINDOW','FAILED_LOCKED_DOOR_EXTRA',
 'FAILED_BARRICADED_DOOR_EXTRA','FAILED_WINDOW_DECLINED_EXTRA'}) do
 run(code,'FailedObstacle:'..code,'none')
end
__obstacleResult='PASS '..#checks
'''


def obstacle_controls(controller):
    yield "ignore-thirst-desperation", changed(controller,
        '(needs2.thirst or 0) >= policy().desperation', 'false'), "thirst_desperation_admitted"
    exact = ('if s == "done:FailedObstacle:FAILED_LOCKED_DOOR"\n'
        '                or s == "done:FailedObstacle:FAILED_BARRICADED_DOOR"\n'
        '                or s == "done:FailedObstacle:FAILED_BARRICADED_WINDOW" then')
    yield "old-locked-substring", changed(controller, exact,
        'if s:find("LOCKED", 1, true) or s:find("BARRICADED", 1, true) then'), "blocked_diagonal_refuse_not_a_lock"
    for label, code, marker in (
        ("drop-locked-door", "FAILED_LOCKED_DOOR", "locked_door_refuse_refusal_retained"),
        ("drop-barricaded-door", "FAILED_BARRICADED_DOOR", "barricaded_door_refuse_refusal_retained"),
        ("drop-barricaded-window", "FAILED_BARRICADED_WINDOW", "barricaded_window_refuse_refusal_retained"),
        ("drop-window-declined", "FAILED_WINDOW_DECLINED", "window_declined_refuse_refusal_retained"),
    ):
        yield label, changed(controller, 's == "done:FailedObstacle:' + code + '"',
            's == "done:FailedObstacle:UNRECOGNIZED_' + code + '"'), marker
    yield "unanchored-native-code", changed(controller, 's == "done:FailedObstacle:FAILED_LOCKED_DOOR"',
        's:find("done:FailedObstacle:FAILED_LOCKED_DOOR", 1, true)'), "FAILED_LOCKED_DOOR_EXTRA_refuse_not_a_lock"


def obstacle_checks(root, work, classes, java, live_cp, verdicts, receipt, run, baseline_only):
    required = {"blocked_diagonal", "locked_door", "barricaded_door", "barricaded_window", "window_declined"}
    if set(verdicts) != required:
        raise AssertionError("native obstacle verdict output differs: " + str(verdicts))
    controller = (root / CONTROLLER).read_text(encoding="utf-8-sig")
    receipt["obstacleVerdicts"] = verdicts
    for relative in (CONTROLLER, LOCOMOTION, LUA_RUNNER, CONTROLLER_FIXTURE):
        receipt["sources"][str(relative)] = hashlib.sha256((root / relative).read_bytes()).hexdigest()
    spec = importlib.util.spec_from_file_location("sao_crossing_prelude", root / CONTROLLER_FIXTURE)
    fixture = importlib.util.module_from_spec(spec); spec.loader.exec_module(fixture)
    compiled = run([JDK / "javac.exe", "-encoding", "UTF-8", "-cp", live_cp, "-d", classes,
        root / LUA_RUNNER], work, "obstacle-kahlua-compile")
    if compiled.returncode: raise AssertionError(compiled.stdout + compiled.stderr)
    shutil.copy2(GAME / "stdlib.lua", work / "stdlib.lua")
    (work / "prelude.lua").write_text(fixture.PRELUDE, encoding="utf-8")
    (work / "locomotion.lua").write_text((root / LOCOMOTION).read_text(encoding="utf-8-sig"), encoding="utf-8")
    inputs = "__nativeVerdicts={" + ",".join(key + "=" + json.dumps(value) for key, value in sorted(verdicts.items())) + "}\n"
    (work / "obstacle.lua").write_text(inputs + OBSTACLE_PROBE, encoding="utf-8")

    def probe(source, phase):
        exposed = changed(source, "return Ctl\n", "Ctl.__obstacleMovement=updateMovement\n"
            "Ctl.__obstacleTick=function(t) tickCount=t end\nreturn Ctl\n")
        (work / "controller.lua").write_text(exposed, encoding="utf-8")
        return run([*java, "-cp", live_cp, "LuaRun", "prelude.lua", "locomotion.lua", "controller.lua",
            "obstacle.lua", "--", "__obstacleResult"], work, phase)

    result = probe(controller, "obstacle-production")
    count = re.search(r"VALUE PASS (\d+)", result.stdout)
    if result.returncode or not count: raise AssertionError(result.stdout + result.stderr)
    receipt["obstacleChecks"] = int(count.group(1))
    print("PASS actual native verdicts through Kahlua Controller/Locomotion: " + count.group(1) + " checks", flush=True)
    receipt["obstacleControls"] = []
    if baseline_only: return
    for label, source, marker in obstacle_controls(controller):
        result = probe(source, "obstacle-" + label)
        if not result.returncode or "OBSTACLE_CHECK:" + marker not in result.stdout:
            raise AssertionError("obstacle control did not reverse actual verdict: " + label + "\n" + result.stdout + result.stderr)
        receipt["obstacleControls"].append(dict(name=label, rejected=True, marker=marker))
        print("PASS control refused: " + label, flush=True)


def native_checks(root, receipt, baseline_only=False):
    jar = GAME / "projectzomboid.jar"
    if not jar.is_file():
        receipt["native"] = "skipped: installed engine unavailable"
        print("SKIPPED native crossing checks: installed engine unavailable")
        return
    receipt["engineJarSha256"] = hashlib.sha256(jar.read_bytes()).hexdigest()
    receipt["sources"] = {str(path): hashlib.sha256((root / path).read_bytes()).hexdigest()
        for path in (MOVEMENT, ROUTE, PROBE, MOTION_PROBE, pathlib.Path("tools/seat_and_crossing_test.py"))}
    move, route = ((root / path).read_text(encoding="utf-8-sig") for path in (MOVEMENT, ROUTE))
    classpath = os.pathsep.join(map(str, (jar, GAME / "ZombieBuddy.jar")))

    def run(command, work, phase):
        start = time.perf_counter()
        result = subprocess.run([str(value) for value in command], cwd=work, text=True,
            encoding="utf-8", errors="replace", capture_output=True, timeout=120)
        receipt.setdefault("commands", []).append(dict(phase=phase, exit=result.returncode,
            seconds=time.perf_counter() - start, stdout=result.stdout, stderr=result.stderr))
        return result

    with tempfile.TemporaryDirectory(prefix="sao-crossing-") as name:
        work = pathlib.Path(name); classes = work / "classes"; classes.mkdir()
        version = (root / "VERSION").read_text(encoding="utf-8-sig").strip()
        generated = work / "SAOVersion.java"
        generated.write_text("package com.sao; public final class SAOVersion { public static final String VALUE = "
            + json.dumps(version) + "; }\n", encoding="utf-8")
        compiled = run([JDK / "javac.exe", "-encoding", "UTF-8", "-cp", classpath, "-d", classes,
            *sorted((root / "java/src").rglob("*.java")), generated, root / PROBE,
            root / MOTION_PROBE], work, "production-compile")
        if compiled.returncode: raise AssertionError(compiled.stdout + compiled.stderr)
        live_cp = str(classes) + os.pathsep + classpath
        java = [JDK / "java.exe", f"-Duser.home={work}", "-Djava.awt.headless=true",
            "-Dstdout.encoding=UTF-8", "--enable-native-access=ALL-UNNAMED"]
        result = run([*java, "-cp", live_cp, "MovementCrossingProbe"], work, "production-probe")
        if result.returncode or "PASS movement crossing checks=" not in result.stdout:
            raise AssertionError(result.stdout + result.stderr)
        receipt["checks"] = [line.removeprefix("CHECK ").removesuffix("=true")
            for line in result.stdout.splitlines() if line.startswith("CHECK ") and line.endswith("=true")]
        print(next(line for line in result.stdout.splitlines() if line.startswith("PASS movement crossing")))
        motion_checks(root, work, classes, java, live_cp, move, receipt, run, baseline_only)
        verdicts = {}
        for line in result.stdout.splitlines():
            if not line.startswith("VERDICT "): continue
            key, value = line.removeprefix("VERDICT ").split("=", 1)
            if key in verdicts and verdicts[key] != value: raise AssertionError("native verdict changed within probe")
            verdicts[key] = value
        obstacle_checks(root, work, classes, java, live_cp, verdicts, receipt, run, baseline_only)
        receipt["controls"] = []
        if baseline_only: return
        for label, relative, source, marker in crossing_controls(move, route):
            directory = work / label; directory.mkdir()
            code = directory / relative.name; code.write_text(source, encoding="utf-8")
            output = directory / "classes"; output.mkdir()
            compiled = run([JDK / "javac.exe", "-encoding", "UTF-8", "-cp", live_cp, "-d", output, code], directory, label + "-compile")
            if compiled.returncode: raise AssertionError(compiled.stdout + compiled.stderr)
            result = run([*java, "-cp", str(output) + os.pathsep + live_cp, "MovementCrossingProbe"], directory, label)
            if not result.returncode or f"CHECK {marker}=false" not in result.stdout:
                raise AssertionError("crossing control did not reverse actual verdict: " + label + "\n" + result.stdout + result.stderr)
            receipt["controls"].append(dict(name=label, rejected=True, marker=marker))
            print("PASS control refused: " + label)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?", type=pathlib.Path, default=ROOT)
    parser.add_argument("--receipt", type=pathlib.Path)
    parser.add_argument("--baseline-only", action="store_true")
    args = parser.parse_args()
    faults = []

    needs = NEEDS.read_text(encoding="utf-8", errors="ignore")
    if not re.search(r'enter\(i, shell\)[\s\S]{0,400}?'
                     r'setCharacterPosition\(shell, i, "inside"\)', needs):
        faults.append("enter() is not paired with the \"inside\" mesh "
                      "placement - the occupant flag can move without "
                      "the body")
    if not re.search(r'getSeat\(shell\)[\s\S]{0,400}?exit\(shell\)'
                     r'[\s\S]{0,400}?"outside"', needs):
        faults.append("exit() is not paired with the \"outside\" mesh "
                      "placement - a released seat can keep a phantom "
                      "passenger")
    if not re.search(r"for \(int i = 1;", needs):
        faults.append("the seat loop does not start past the driver's "
                      "seat - nobody here drives")

    move = MOVE.read_text(encoding="utf-8", errors="ignore")
    if "getHoppableTo" not in move or "climbOverFence" not in move:
        faults.append("the route supervisor has no hoppable-edge branch "
                      "- a fence is an eternal unnamed stall")
    if "traverseToward" not in move:
        faults.append("there is no follow traversal - a follower cannot "
                      "cross what the player crossed")

    ctl = CTL.read_text(encoding="utf-8", errors="ignore")
    if "followTraverse" not in ctl:
        faults.append("the Controller never asks for the crossing - "
                      "the traversal exists and nothing reaches it")
    if not re.search(r"if not agent\.riding then[\s\S]{0,400}?"
                     r"agent\.riding = true", ctl):
        faults.append("riding is not reconciled from the seat truth - "
                      "a re-adopted passenger runs walk orders from "
                      "inside a car")

    print("=" * 74)
    print("THE SEAT AND THE MESH MOVE TOGETHER; THE FOLLOW CROSSES")
    print("=" * 74)
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    receipt = {"schema": "sao-native-crossing-checks/1", "boundary": "Installed native objects and production movement; controlled geometry/state, no rendered gameplay."}
    try:
        native_checks(args.root.resolve(), receipt, args.baseline_only)
        receipt["status"] = "passed"
    except (AssertionError, OSError, subprocess.TimeoutExpired) as error:
        receipt["status"], receipt["error"] = "failed", str(error)
        print("  FAULT: " + str(error))
    finally:
        if args.receipt:
            args.receipt.parent.mkdir(parents=True, exist_ok=True)
            args.receipt.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    if receipt["status"] != "passed": return 1
    print("  82) seats and crossings: every enter and exit moves the mesh with")
    print("      the flag, fences are crossings rather than stalls, the follow")
    print("      works the edge its target crossed, and the seat outranks the flag")
    return 0


if __name__ == "__main__":
    sys.exit(main())
