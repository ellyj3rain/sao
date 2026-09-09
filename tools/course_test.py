#!/usr/bin/env python3
r"""Border 142 - the body fights, and the cadence cannot change how well.

[C11] and F-047 established what the engine does with a bite: it
infects with CERTAINTY on this build, and the infected die at exactly
`infectionTime + pickMortalityDuration`. `dormantAttrition` reads the
record's mirror of that hour as a due date - "past it, death is not a
risk, it is due" - so today every bitten person in the county dies on
schedule and nothing they did beforehand makes any difference.

`SAO_Course` makes it a race the body can win, on inputs the record
already produces by living: how long since they reached water, how long
since they ate, whether a house is keeping them, whether a wound is
already septic, how old they are, what they carry.

WHAT THIS BORDER IS FOR, AND IT IS NOT THE FORMULA.

A border reading `PERFECT_COURSE_GAIN` out of the source would pass a
tree that computed it and then handed the answer to whichever half of
the county happened to call it. The property that matters is that the
two halves cannot disagree, and that is measured by running the
shipped module in the engine's own Kahlua VM and asking it the same
question at different cadences.

THE DEFECT THIS WAS WRITTEN AGAINST, FOUND BY WRITING IT.

The first draft of `gainFor` sampled the curve at the step's midpoint
and multiplied by the step's width, which is the obvious way to write
it. One step across a whole course then samples sin at its peak and
returns pi/2; twenty-four steps of a twenty-fourth sum to 1. A dormant
body taking one step a day would out-fight a loaded body taking
hundreds - which is [C75]'s defect, the two halves of the county
disagreeing because a pass means different things in each, arriving in
a different module a day later.

The step is the exact integral now. The area of sin(pi*x) over [a, b],
normalised, is (cos(pi*a) - cos(pi*b))/2 - one over a whole course and
additive over any partition of it, so cadence cannot move the total.
That is [B39] and [B42]: loaded and unloaded are governed by one rule.

ITS CONTROL is any tree before this batch, where `SAO_Course.lua` does
not exist and no bitten person has ever fought anything. The border
names that rather than merely failing to import.
"""
import math
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
HERE = pathlib.Path(__file__).resolve().parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
SRC = HERE / "luacheck" / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

# The course model stands on the hash and nothing else, which is what
# "offline by construction" in its header claims. Loading only these
# two is itself a check on that claim: a module that had quietly grown
# a dependency would fail to load here.
MODULES = [
    "shared/SAO_Log.lua",
    "shared/SAO_Hash.lua",
    "shared/SAO_Course.lua",
]

PRELUDE = r'''
SAO = SAO or {}

-- A body wanting for nothing, so the quality term is 1 and what is
-- left is the curve and the cadence.
function PERFECT()
    return { dryDays = 0, hungryDays = 0 }
end

-- Sum the course in `n` equal steps. The whole point is that this is
-- the same number for every n.
function SUM(inputs, n)
    local total, step = 0.0, 1.0 / n
    for i = 0, n - 1 do
        total = total + SAO.Course.gainFor(inputs, i * step, step)
    end
    return total
end
'''


def build():
    cls = OUT / "LuaRun.class"
    if cls.exists() and cls.stat().st_mtime >= SRC.stat().st_mtime:
        return True
    OUT.mkdir(parents=True, exist_ok=True)
    done = subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(OUT), str(SRC)],
        capture_output=True, text=True, timeout=300)
    return done.returncode == 0


def probe(expr):
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(STDLIB, work / "stdlib.lua")
        for c in OUT.glob("*.class"):
            shutil.copy2(c, work / c.name)
        prelude = work / "prelude.lua"
        prelude.write_text(PRELUDE, encoding="utf-8")
        args = [str(JDK / "java.exe"), "-cp", "%s;." % PZ, "LuaRun",
                str(prelude)]
        args += [str(LUA / m) for m in MODULES if (LUA / m).exists()]
        args += ["--", expr]
        done = subprocess.run(args, cwd=str(work), capture_output=True,
                              text=True, timeout=900)
    out = done.stdout or ""
    at = out.find("VALUE ")
    if at < 0:
        return "ERROR " + (out + (done.stderr or "")).strip()[-400:]
    return out[at + 6:].strip().split("\n")[0]


def numbers(line):
    return {k: float(v) for k, v in
            re.findall(r"([A-Za-z_]+)=(-?[0-9.eE+-]+)", line or "")}


def main():
    faults = []
    print("=" * 74)
    print("THE BODY FIGHTS, AND THE CADENCE CANNOT CHANGE HOW WELL")
    print("=" * 74)

    module = LUA / "shared" / "SAO_Course.lua"
    if not module.exists():
        print("  142) the body fights the infection: CONTROL")
        print("  CONTROL: mod/42.20/media/lua/shared/SAO_Course.lua is")
        print("  absent. On this tree a bite is a due date and nobody")
        print("  fights it - which is exactly what [C11]/F-047 left and")
        print("  what this batch changes. Nothing to measure.")
        return 1

    # A machine without the game is not a machine with a defect. Every
    # engine read below needs the jar, the stdlib, the JDK and the
    # runner, and the gate holds every border to saying so plainly
    # rather than raising - which is what this one did on its first run.
    if not (JDK.exists() and PZ.exists() and STDLIB.exists()
            and SRC.exists()):
        print("  SKIPPED the VM - no JDK, engine jar, stdlib or runner")
        print("  142) the body fights: TEXT ONLY, the engine install "
              "is absent")
        print("  The course is measured by running the shipped module,")
        print("  so there is nothing this border can assert here.")
        return 0

    if not build():
        print("  FAULT: LuaRun does not compile against the installed jar")
        return 1

    # 1. Cadence independence, which is the whole reason for the file.
    line = probe(
        '"one=" .. SUM(PERFECT(), 1)'
        ' .. " day=" .. SUM(PERFECT(), 24)'
        ' .. " fine=" .. SUM(PERFECT(), 1000)')
    n = numbers(line)
    if len(n) < 3:
        print("  FAULT: cadence probe returned nothing usable")
        print("    " + str(line)[:300])
        faults.append("cadence")
    else:
        spread = max(n.values()) - min(n.values())
        print("  a whole course in 1 step      : %.9f" % n["one"])
        print("  the same course in 24 steps   : %.9f" % n["day"])
        print("  the same course in 1000 steps : %.9f" % n["fine"])
        print("  spread                        : %.3e" % spread)
        if spread > 1e-6:
            print("  FAULT: the cadence changes the answer. A dormant day")
            print("  and a loaded tick would fight at different strengths,")
            print("  which is [C75]'s defect in another module.")
            faults.append("cadence")

    # 2. And the total is the constant the file says it is, so the one
    #    tuned number in the model means what its name says.
    line = probe('"total=" .. SUM(PERFECT(), 500)'
                 ' .. " stated=" .. SAO.Course.PERFECT_COURSE_GAIN')
    n = numbers(line)
    if len(n) == 2:
        print("  a perfect body over a whole course: %.6f" % n["total"])
        print("  PERFECT_COURSE_GAIN says          : %.6f" % n["stated"])
        if abs(n["total"] - n["stated"]) > 1e-6:
            print("  FAULT: the constant does not mean what it says.")
            faults.append("constant")
    else:
        faults.append("constant")

    # 3. The curve does something: the middle of the course is where
    #    care pays, which is the reason for having a curve at all.
    line = probe(
        '"first=" .. SAO.Course.gainFor(PERFECT(), 0.0, 0.3333)'
        ' .. " middle=" .. SAO.Course.gainFor(PERFECT(), 0.3333, 0.3334)')
    n = numbers(line)
    if len(n) == 2:
        print("  first third of the course : %.6f" % n["first"])
        print("  middle third              : %.6f" % n["middle"])
        if n["middle"] <= n["first"]:
            print("  FAULT: the middle of the course is worth no more than")
            print("  the start, so the response curve is flat and there is")
            print("  no window in which what somebody does matters.")
            faults.append("curve")
    else:
        faults.append("curve")

    # 4. A body with no water does not win, whatever the cadence.
    line = probe(
        '"dry=" .. SUM({ dryDays = 3, hungryDays = 0 }, 100)'
        ' .. " base=" .. SUM(PERFECT(), 100)'
        ' .. " kept=" .. SUM({ dryDays = 0, hungryDays = 0,'
        ' inHouse = true }, 100)')
    n = numbers(line)
    if len(n) == 3:
        print("  three days without water : %.6f" % n["dry"])
        print("  wanting for nothing      : %.6f" % n["base"])
        print("  and a house keeping them : %.6f" % n["kept"])
        if n["dry"] > 0.001:
            print("  FAULT: a body without water still fights.")
            faults.append("thirst")
        # Care has to be able to carry somebody past the baseline, or
        # every bonus term in `qualityOf` is dead code that reads as a
        # model. An earlier draft clamped quality to [0, 1] and this
        # is the assertion that caught it.
        if n["kept"] <= n["base"]:
            print("  FAULT: being kept by a house buys nothing. The")
            print("  bonus terms are unreachable and the model is")
            print("  smaller than it looks.")
            faults.append("care")
    else:
        faults.append("thirst")

    # 5. Winning clears the engine's clock and is remembered; losing
    #    happens at the engine's own hour and never later.
    # LuaRun evaluates its argument as `return <expr>`, so a probe
    # that needs statements has to be an expression that contains
    # them. The first draft passed a bare `local ... return ...` block
    # and got a syntax error the border reported as a model failure.
    line = probe(
        '(function()'
        ' local r = { knoxInfected = true, biteDeathAtHours = 100,'
        ' infectionSpanHours = 100, immuneProgress = 0.99 }'
        ' local v = SAO.Course.advance(r, 50, PERFECT(), 0.5)'
        ' return "won=" .. (v == "won" and 1 or 0)'
        ' .. " cleared=" .. ((r.knoxInfected == nil'
        ' and r.biteDeathAtHours == nil) and 1 or 0)'
        ' .. " survived=" .. (r.infectionsSurvived or 0)'
        ' end)()')
    n = numbers(line)
    if len(n) == 3:
        print("  a body that gets there wins      : %d" % int(n["won"]))
        print("  the clock and the flags are gone : %d" % int(n["cleared"]))
        print("  and the body remembers it        : %d"
              % int(n["survived"]))
        if n["won"] != 1 or n["cleared"] != 1 or n["survived"] != 1:
            print("  FAULT: winning did not clear the course.")
            faults.append("win")
    else:
        faults.append("win")

    line = probe(
        '(function()'
        ' local r = { knoxInfected = true, biteDeathAtHours = 100,'
        ' infectionSpanHours = 100, immuneProgress = 0 }'
        ' SAO.Course.advance(r, 60, { dryDays = 3 }, 0.5)'
        ' return "due=" .. r.biteDeathAtHours'
        ' end)()')
    n = numbers(line)
    if len(n) == 1:
        print("  the engine's hour after a fight  : %.1f" % n["due"])
        if abs(n["due"] - 100.0) > 1e-9:
            print("  FAULT: the deadline moved. [C11] read it off the")
            print("  engine's own course and this model races it rather")
            print("  than editing it.")
            faults.append("deadline")
    else:
        faults.append("deadline")

    # 7. And the spread, which is what stops the model being a
    #    threshold. Two people in identical circumstances must not have
    #    identical odds, or a bite is survivable by everybody or by
    #    nobody and nothing in between ever happens.
    line = probe(
        '(function()'
        ' local lo, hi = 9e9, -9e9'
        ' for i = 1, 400 do'
        '   local v = SAO.Course.constitutionOf("p" .. i)'
        '   if v < lo then lo = v end'
        '   if v > hi then hi = v end'
        ' end'
        ' return "lo=" .. lo .. " hi=" .. hi'
        ' .. " same=" .. ((SAO.Course.constitutionOf("p7")'
        ' == SAO.Course.constitutionOf("p7")) and 1 or 0)'
        ' end)()')
    n = numbers(line)
    if len(n) == 3:
        print("  constitution across 400 people : %.3f to %.3f"
              % (n["lo"], n["hi"]))
        print("  and it is the same every read  : %d" % int(n["same"]))
        if n["hi"] - n["lo"] < 0.5:
            print("  FAULT: everybody has the same body. Identical")
            print("  circumstances give identical outcomes, so a bite is")
            print("  survivable by all or by none.")
            faults.append("spread")
        if n["same"] != 1:
            print("  FAULT: constitution is rolled rather than drawn.")
            faults.append("spread")
    else:
        faults.append("spread")

    print("-" * 74)
    if faults:
        print("  142) the body fights the infection: FAIL")
        print("REFUSED: " + ", ".join(sorted(set(faults))))
        return 1
    print("  142) a bitten body races the engine's own hour, and the "
          "cadence cannot change how well it runs")
    print("MATCH: the course totals what its constant says, the middle of")
    print("it is where care pays, a body without water never wins, and the")
    print("cadence cannot change any of it.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
