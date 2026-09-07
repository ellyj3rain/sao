#!/usr/bin/env python3
r"""Border 105 - age is a system on the county's people ([C30], DR-032).

The county has children and elders, the age decides the work, the
pace and the size, the stage drifts the body, and the old die of it.
This border drives SAO_History in the engine's own Kahlua VM (via
tools/luacheck/LuaRun, the [B48] instrument) against a stub county
and asks it real questions, then holds the age module and the body
to their seams by text.

WHAT THIS HOLDS
---------------
  1. The bands: over a few hundred people the county has children
     (under 18) and elders (past 68) in the shares the bands declare,
     every age is a fact about the person (the same id answers the
     same age twice), and nobody is under six.
  2. The stages: five, at Getting Old's boundaries, and the age
     decides the work - a child is a student, an elder a retiree,
     whatever the census dealt.
  3. The size and the pace: an adult answers 1 for both; a child
     answers less than 1 for both and never below the floors; an
     elder walks slower than an adult.
  4. The old die of it: the daily risk is zero under sixty, rises
     with age, and at eighty is the life table's yearly probability
     spread over the year.
  5. The module: SAO_Age runs every ten minutes, drifts the living
     by stage, rolls the day for everyone, marks the living and
     takes the dormant with the cause "old age", and calls nothing
     the jar does not carry (no setTripping).
  6. The body takes its pace after its size.

An optional argv[1] points the checker at another tree root, which is
how the control runs against the pre-[C30] tree: bands that stop at
nineteen and sixty-eight, no stages, no module - it faults every way.
"""
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
HERE = pathlib.Path(__file__).resolve().parent
SHARED = ROOT / "mod" / "42.20" / "media" / "lua" / "shared"
CLIENT = ROOT / "mod" / "42.20" / "media" / "lua" / "client"
HASH = SHARED / "SAO_Hash.lua"
HISTORY = SHARED / "SAO_History.lua"
AGE = CLIENT / "SAO_Age.lua"
BODY = CLIENT / "SAO_Body.lua"
PRELUDE = HERE / "luacheck" / "probe_age.lua"
SRC = HERE / "luacheck" / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"


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
        done = subprocess.run(
            [str(JDK / "java.exe"), "-cp", f"{PZ};.", "LuaRun",
             str(PRELUDE), str(HASH), str(HISTORY), "--", expr],
            cwd=str(work), capture_output=True, text=True, timeout=180)
    return (done.stdout or "").strip().split("\n")[-1] if done.stdout else "ERROR no output"


def value(line):
    return line[6:] if line.startswith("VALUE ") else None


def main():
    faults = []
    print("=" * 74)
    print("AGE IS A SYSTEM ON THE COUNTY'S PEOPLE")
    print("=" * 74)

    for path, what in ((HASH, "SAO_Hash.lua"), (HISTORY, "SAO_History.lua"),
                       (AGE, "SAO_Age.lua"), (BODY, "SAO_Body.lua"), (PRELUDE, "the probe")):
        if not path.exists():
            faults.append(what + " does not exist")
    if faults:
        for fault in faults:
            print("  FAULT: " + fault)
        return 1
    if not build():
        print("  FAULT: LuaRun does not compile against the installed jar")
        return 1

    # 1. The bands, over 600 people.
    line = probe("(function() local c, a, e, young, twice = 0, 0, 0, 0, 0 "
                 "for i = 1, 600 do local id = 't' .. i local ag = SAO.History.ageOf(id) "
                 "if ag ~= SAO.History.ageOf(id) then twice = twice + 1 end "
                 "if ag < 6 then young = young + 1 end "
                 "if ag < 18 then c = c + 1 elseif ag > 68 then e = e + 1 else a = a + 1 end end "
                 "return c .. ',' .. a .. ',' .. e .. ',' .. young .. ',' .. twice end)()")
    shares = value(line)
    if not shares:
        faults.append("the bands did not answer: " + line)
    else:
        children, adults, elders, young, twice = (int(x) for x in shares.split(","))
        total = children + adults + elders
        print("     600 people: %d children, %d adults, %d elders (%.0f%% / %.0f%% / %.0f%%)"
              % (children, adults, elders, 100.0 * children / total,
                 100.0 * adults / total, 100.0 * elders / total))
        if children == 0:
            faults.append("the county has no children - the bands still stop at nineteen")
        if elders == 0:
            faults.append("the county has no one past sixty-eight - the bands still stop there")
        if young:
            faults.append("%d people are under six; the county keeps no infants" % young)
        if twice:
            faults.append("an age changed between two asks - it is a roll, not a fact")
        if not (0.12 <= children / total <= 0.32):
            faults.append("the children's share is off the declared band shares: %.2f" % (children / total))
        if not (0.03 <= elders / total <= 0.16):
            faults.append("the elders' share is off the declared band shares: %.2f" % (elders / total))

    # 2. Stages and the work.
    for age, stage in ((6, "child"), (17, "child"), (18, "young"), (25, "young"),
                       (26, "adult"), (40, "adult"), (41, "middle"), (60, "middle"),
                       (61, "elder"), (90, "elder")):
        got = value(probe("SAO.History.stageOf(%d)" % age))
        if got != stage:
            faults.append("stageOf(%d) answers %r, not %r" % (age, got, stage))
    work = value(probe(
        "(function() local kid, old = nil, nil "
        "for i = 1, 600 do local id = 't' .. i local ag = SAO.History.ageOf(id) "
        "if not kid and ag < 18 then kid = id end if not old and ag > 68 then old = id end end "
        "local rk = { id = kid } SAO.History.generate(kid, rk, 1) "
        "local ro = { id = old } SAO.History.generate(old, ro, 1) "
        "local ra = { id = 'adult-x', occupation = nil } "
        "return tostring(rk.occupation) .. ',' .. tostring(ro.occupation) end)()"))
    if work != "student,retiree":
        faults.append("the age does not decide the work (child, elder) - got " + repr(work))

    # 3. Size and pace.
    for expr, want in (("SAO.History.heightScaleOf('adult-x') >= 0.999", "true"),
                       ("SAO.History.speedModOf('adult-x') >= 0.999", "true")):
        pass
    line = probe("(function() local kid, old = nil, nil "
                 "for i = 1, 600 do local id = 't' .. i local ag = SAO.History.ageOf(id) "
                 "if not kid and ag < 12 then kid = id end if not old and ag > 78 then old = id end end "
                 "local adult = nil for i = 1, 600 do local id = 't' .. i local ag = SAO.History.ageOf(id) "
                 "if ag >= 26 and ag <= 40 then adult = id break end end "
                 "return string.format('%.3f,%.3f,%.3f,%.3f,%.3f,%.3f', "
                 "SAO.History.heightScaleOf(kid), SAO.History.speedModOf(kid), "
                 "SAO.History.heightScaleOf(adult), SAO.History.speedModOf(adult), "
                 "SAO.History.heightScaleOf(old), SAO.History.speedModOf(old)) end)()")
    got = value(line)
    if not got:
        faults.append("size and pace did not answer: " + line)
    else:
        kh, kp, ah, ap, oh, op = (float(x) for x in got.split(","))
        print("     child size %.3f pace %.3f | adult %.3f %.3f | elder %.3f %.3f" % (kh, kp, ah, ap, oh, op))
        if not (0.5 <= kh < 1.0):
            faults.append("a child under twelve is not smaller than an adult: %.3f" % kh)
        if not (0.5 <= kp < 1.0):
            faults.append("a child under twelve is not slower than an adult: %.3f" % kp)
        if ah != 1.0 or ap != 1.0:
            faults.append("an adult does not answer 1 for size and pace: %.3f %.3f" % (ah, ap))
        if oh != 1.0:
            faults.append("an elder's size is not 1 (no elder body is needed): %.3f" % oh)
        if not (0.6 <= op < 1.0):
            faults.append("an elder past seventy-eight is not slower than an adult: %.3f" % op)

    # 4. The old die of it.
    got = value(probe("string.format('%.6f,%.6f,%.6f,%.6f,%.6f', "
                      "SAO.History.oldAgeRiskPerDay(30), SAO.History.oldAgeRiskPerDay(59), "
                      "SAO.History.oldAgeRiskPerDay(60), SAO.History.oldAgeRiskPerDay(70), "
                      "SAO.History.oldAgeRiskPerDay(80))"))
    if not got:
        faults.append("the old-age risk did not answer")
    else:
        r30, r59, r60, r70, r80 = (float(x) for x in got.split(","))
        print("     old-age risk per day: 30 %.6f | 59 %.6f | 60 %.6f | 70 %.6f | 80 %.6f" % (r30, r59, r60, r70, r80))
        if r30 != 0.0 or r59 != 0.0:
            faults.append("the old-age risk is not zero under sixty")
        if not (r60 < r70 < r80):
            faults.append("the old-age risk does not rise with age")
        if not (0.05938 / 365 * 0.9 <= r80 <= 0.05938 / 365 * 1.1):
            faults.append("the risk at eighty is not the life table's 0.05938 a year spread over the days: %.6f" % r80)

    # 5. The module, by text.
    age = AGE.read_text(encoding="utf-8", errors="replace")
    code = "\n".join(l[:l.find("--")] if l.find("--") >= 0 else l for l in age.split("\n"))
    if "Events.EveryTenMinutes.Add(" not in code:
        faults.append("SAO_Age does not run every ten minutes")
    if 'markDead(rec, tick, "old age")' not in code:
        faults.append("a dormant death of old age does not carry its cause")
    if "rec.dyingOfOldAge = true" not in code:
        faults.append("a living elder is not marked for the drift to finish")
    if "setTripping" in code:
        faults.append("SAO_Age calls setTripping, which this build's Stats does not carry")
    for stage in ("child", "young", "middle", "elder"):
        if stage + " " not in code and stage + "=" not in code and stage + " =" not in code:
            faults.append("the drift table lacks the stage " + stage)
    if "oldAgeRiskPerDay" not in code:
        faults.append("the day's roll does not read the life table")

    # 6. The body takes its pace after its size.
    body = BODY.read_text(encoding="utf-8", errors="replace")
    sized_at = body.find("SAOJavaBridge:setBodyScale(body, scale)")
    paced_at = body.find("body:setSpeedMod(pace)")
    if sized_at < 0 or paced_at < 0 or paced_at < sized_at:
        faults.append("the body is not paced after it is sized")

    if faults:
        for fault in faults:
            print("  FAULT: " + fault)
        return 1
    print("  105) age: the county has children and elders as facts about the person,")
    print("       the age decides the work, the size and the pace, the stages drift the")
    print("       living every ten minutes, and the old die of it on the life table")
    return 0


if __name__ == "__main__":
    sys.exit(main())
