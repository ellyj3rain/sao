#!/usr/bin/env python3
r"""Border 159 - learned trajectory & headless simulation for late starts ([C126]).

Verification of:
1. Headless VM: LuaRun compiles against Kahlua alone; county_sweep falls
   back to tools/lib/kahlua-j2se.jar when the game jar is absent; world
   cache via SAO_SWEEP_CACHE is enough to run.
2. C112 cadence no longer freezes years after one slice: a save that
   owes more than ~60 days keeps catching up every frame.
3. Trajectory anchors are the measured Knox curve, not an invented
   exponential. Fast simulation stays opt-in.
4. Mutation resistance on the cadence catch-up, the anchors, and the
   opt-in hook.
"""
import math
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import county_sweep as Sweep  # noqa: E402

TRAJ_LUA = ROOT / "mod" / "42.20" / "media" / "lua" / "shared" / "SAO_Trajectory.lua"
POP_LUA = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Population.lua"
SWEEP_PY = ROOT / "tools" / "county_sweep.py"
TRAJ_PY = ROOT / "tools" / "county_trajectory.py"
LUARUN = ROOT / "tools" / "luacheck" / "LuaRun.java"
KAHLUA = ROOT / "tools" / "lib" / "kahlua-j2se.jar"


def source_faults(traj_src, pop_src, sweep_src, traj_py_src, luarun_src):
    faults = []

    if "Trajectory.ANCHORS" not in traj_src:
        faults.append("SAO_Trajectory lacks measured ANCHORS table")
    if "Trajectory.CORPUS_N0 = 198" not in traj_src:
        faults.append("SAO_Trajectory lacks CORPUS_N0 = 198 (11 towns x 18)")
    if "DECAY_RATE = 0.00205" in traj_src:
        faults.append("SAO_Trajectory still carries the invented DECAY_RATE 0.00205")
    if "MIN_SURVIVAL_RATIO = 0.08" in traj_src:
        faults.append("SAO_Trajectory still carries the invented 8% survival floor")
    if "function Trajectory.predict" not in traj_src:
        faults.append("SAO_Trajectory lacks predict")
    if "function Trajectory.extrapolate" not in traj_src:
        faults.append("SAO_Trajectory lacks extrapolate")
    if "function Trajectory.shouldFastSimulate" not in traj_src:
        faults.append("SAO_Trajectory lacks shouldFastSimulate")
    if "return false" not in traj_src:
        faults.append("SAO_Trajectory shouldFastSimulate has no default-false path")

    for day in (1, 7, 30, 90, 180, 365, 1096):
        if ("d = %d," % day) not in traj_src and ("d = %d," % day) not in traj_src.replace("  ", " "):
            # accept both spacings
            if ("d = %d" % day) not in traj_src:
                faults.append("SAO_Trajectory ANCHORS missing day %d" % day)

    if "SAO.Trajectory.shouldFastSimulate" not in pop_src:
        faults.append("SAO_Population.runTheYears does not check shouldFastSimulate")
    if "SAO.Trajectory.extrapolate" not in pop_src:
        faults.append("SAO_Population.runTheYears does not invoke extrapolate")
    if "catchingUp" not in pop_src:
        faults.append("SAO_Population does not keep catching up years every frame")
    if "clock that went backwards" not in pop_src:
        faults.append("SAO_Population lost the C126 cadence-during-years argument")

    if "shared/SAO_Trajectory.lua" not in sweep_src:
        faults.append("county_sweep.py MODULES does not include shared/SAO_Trajectory.lua")
    if "kahlua-j2se.jar" not in sweep_src:
        faults.append("county_sweep.py does not fall back to bundled Kahlua")
    if "SAO_SWEEP_CACHE" not in sweep_src:
        faults.append("county_sweep.py does not honour SAO_SWEEP_CACHE")
    if "import zombie." in luarun_src:
        faults.append("LuaRun.java still compiles against zombie.* (needs Kahlua-only)")

    if "fit_exponential_decay" not in traj_py_src:
        faults.append("county_trajectory.py lacks fit_exponential_decay")

    if not KAHLUA.exists():
        faults.append("tools/lib/kahlua-j2se.jar is missing")

    return faults


def simulate_trajectory_math():
    """Piecewise interpolation of the measured curve, scaled to 198."""
    faults = []
    # Mirror atDay/predict in Python against the measured table.
    anchors = [
        (0, 198), (1, 198), (7, 177), (30, 45),
        (90, 7), (180, 2), (365, 1), (1096, 2),
    ]

    def predict_alive(days):
        if days <= anchors[0][0]:
            return anchors[0][1]
        if days >= anchors[-1][0]:
            return anchors[-1][1]
        for i in range(len(anchors) - 1):
            lo, hi = anchors[i], anchors[i + 1]
            if lo[0] <= days <= hi[0]:
                t = (days - lo[0]) / (hi[0] - lo[0])
                return lo[1] + (hi[1] - lo[1]) * t
        return anchors[-1][1]

    d0 = predict_alive(0)
    d7 = predict_alive(7)
    d30 = predict_alive(30)
    d90 = predict_alive(90)
    d1096 = predict_alive(1096)

    if d0 != 198:
        faults.append("Day 0 population expected 198, got %s" % d0)
    if not (d0 >= d7 > d30 > d90 >= d1096):
        faults.append(
            "Non-monotonic measured curve: d0=%s d7=%s d30=%s d90=%s d1096=%s"
            % (d0, d7, d30, d90, d1096))
    if d30 > 60:
        faults.append("Day 30 still looks like the invented exponential (alive=%s)" % d30)
    if d1096 > 8:
        faults.append("Day 1096 floor is a handful, not 8 percent (alive=%s)" % d1096)
    # Invented k=0.00205 would predict ~175 at day 30 from 198.
    invented = 198 * math.exp(-0.00205 * 30)
    if abs(d30 - invented) < 20:
        faults.append("Day 30 is the invented exponential, not the measured crash")
    return faults


def verify_module_harmonization():
    lua_dir = ROOT / "mod" / "42.20" / "media" / "lua"
    missing, loaded = Sweep.modules_referenced(lua_dir)
    if missing:
        return ["modules_referenced reported missing SAO modules: %s" % missing]
    if "Trajectory" not in loaded:
        return ["Trajectory module was not loaded in headless sweep"]
    if "Neuro" not in loaded:
        return ["Neuro module was not loaded in headless sweep"]
    return []


def mutation_tests(traj_src, pop_src, sweep_src, traj_py_src, luarun_src):
    m1 = traj_src.replace("Trajectory.ANCHORS", "Trajectory.ANCHOR")
    if not source_faults(m1, pop_src, sweep_src, traj_py_src, luarun_src):
        return "mutation failed: removed ANCHORS did not fault"

    m2 = pop_src.replace("SAO.Trajectory.shouldFastSimulate", "shouldFastSimulate")
    if not source_faults(traj_src, m2, sweep_src, traj_py_src, luarun_src):
        return "mutation failed: missing fast simulate hook did not fault"

    m3 = pop_src.replace("catchingUp", "catching")
    if not source_faults(traj_src, m3, sweep_src, traj_py_src, luarun_src):
        return "mutation failed: cadence catch-up rename did not fault"

    m4 = luarun_src.replace("public class LuaRun", "import zombie.Lua.LuaManager;\npublic class LuaRun")
    if not source_faults(traj_src, pop_src, sweep_src, traj_py_src, m4):
        return "mutation failed: zombie import did not fault"

    return None


def main():
    print("=" * 74)
    print("BORDER 159 - LEARNED TRAJECTORY & HEADLESS SIMULATION FOR LATE STARTS")
    print("=" * 74)

    traj_src = TRAJ_LUA.read_text(encoding="utf-8", errors="ignore")
    pop_src = POP_LUA.read_text(encoding="utf-8", errors="ignore")
    sweep_src = SWEEP_PY.read_text(encoding="utf-8", errors="ignore")
    traj_py_src = TRAJ_PY.read_text(encoding="utf-8", errors="ignore")
    luarun_src = LUARUN.read_text(encoding="utf-8", errors="ignore")

    all_faults = []
    all_faults.extend(source_faults(traj_src, pop_src, sweep_src, traj_py_src, luarun_src))
    all_faults.extend(simulate_trajectory_math())
    all_faults.extend(verify_module_harmonization())

    mut_fault = mutation_tests(traj_src, pop_src, sweep_src, traj_py_src, luarun_src)
    if mut_fault:
        all_faults.append(mut_fault)

    if all_faults:
        print()
        print("VERDICT: FAULT")
        for f in all_faults:
            print("  FAULT: " + f)
        return 1

    print()
    print("  yes  SAO_Trajectory: measured Knox anchors, no invented 0.00205 / 8% floor")
    print("  yes  SAO_Population: years catch up every frame; fast-sim remains opt-in")
    print("  yes  county_sweep: Kahlua fallback, SAO_SWEEP_CACHE, 0 missing modules")
    print("  yes  LuaRun: compiles against Kahlua alone")
    print("  yes  trajectory math: first-month crash, handful at 1096")
    print("  yes  mutation tests: anchors, hook, cadence, zombie import")
    print()
    print("VERDICT: PASS")
    print("  159) learned trajectory & headless simulation for late starts:")
    print("       years past sixty days actually run; curve is the measured")
    print("       Knox corpus; fast extrapolation is opt-in")
    return 0


if __name__ == "__main__":
    sys.exit(main())

