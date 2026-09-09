#!/usr/bin/env python3
r"""Border 144 - what an examiner can tell is bounded by the examiner.

`[C78]` gave a body a course and `[C79]` let the county catch it, and
neither was visible to anybody: a survivor sickened and died out there
and the only trace was a line in the log.

`SAO_Medical.readingOf` is the reading, and its whole design is one
rule - it reports what THIS examiner could tell, not what the record
knows. DR-007 draws Knox on two ledgers, what the pathogen does and
what anyone is permitted to know about it, and says never a percentage
on the forehead.

WHAT THIS HOLDS.

Two invariants that a renderer cannot be trusted to keep on its own.

**No number reaches a reading, at any skill.** A course position is a
fraction and a fever is not a percentage; the moment a digit appears in
one of these lines, DR-007 has been broken in the one place a player
would actually see it. This is checked across the whole skill range
against a record deliberately full of numbers.

**Looking at somebody does not change them.** The module says reading a
person informs nothing, and `Course.positionOf` REPAIRS a missing span
by writing one - so a reading that reached it carelessly would mutate
the patient. The record is compared field by field either side of every
call.

And the gate itself: untrained examiners never learn what it is,
trained ones can name it, practised ones can place it, and only a medic
gets a judgement about whether the body is winning.

ITS CONTROL is any tree without `SAO_Medical.lua`, where the county's
sickness is invisible and there is no reading to bound.
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
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
SRC = HERE / "luacheck" / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

# The reading stands on the course and the hash and nothing else. The
# WINDOW is deliberately absent: it needs the game's UI and cannot load
# here, which is why the judgement lives in a module that can.
MODULES = [
    "shared/SAO_Log.lua",
    "shared/SAO_Hash.lua",
    "shared/SAO_Course.lua",
    "client/SAO_Medical.lua",
]

PRELUDE = r'''
SAO = SAO or {}

-- A patient carrying everything a reading could possibly mention, so
-- nothing below passes for want of something to say.
function PATIENT()
    return {
        id = "p1", forename = "Someone",
        knoxInfected = true,
        biteDeathAtHours = 172.5,
        infectionSpanHours = 60.25,
        immuneProgress = 0.4137,
        infectionsSurvived = 2,
        woundInfected = true,
        lastWaterDay = 1,
    }
end

function JOIN(t)
    return table.concat(t, " | ")
end

-- Every field, flattened, so a change anywhere in the record shows up
-- as a different string.
function SNAP(r)
    local keys = {}
    for k in pairs(r) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    local out = {}
    for _, k in ipairs(keys) do
        out[#out + 1] = k .. "=" .. tostring(r[k])
    end
    return table.concat(out, ";")
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


def main():
    faults = []
    print("=" * 74)
    print("WHAT AN EXAMINER CAN TELL IS BOUNDED BY THE EXAMINER")
    print("=" * 74)

    if not (LUA / "client" / "SAO_Medical.lua").exists():
        print("  144) the reading is bounded: CONTROL")
        print("  CONTROL: SAO_Medical.lua is absent. On this tree the")
        print("  county's sickness is invisible - somebody runs a course")
        print("  and dies of it and nobody can see any of it - so there")
        print("  is no reading to bound.")
        return 1

    if not (JDK.exists() and PZ.exists() and STDLIB.exists()
            and SRC.exists()):
        print("  SKIPPED the VM - no JDK, engine jar, stdlib or runner")
        print("  144) the reading is bounded: TEXT ONLY, the engine "
              "install is absent")
        return 0

    if not build():
        print("  FAULT: LuaRun does not compile against the installed jar")
        return 1

    # 1. No digit ever reaches a line, at any skill. The patient is
    #    full of numbers; none of them may come out.
    line = probe(
        '(function()'
        ' local bad = ""'
        ' for s = 0, 10 do'
        '   local txt = JOIN(SAO.Medical.readingOf(PATIENT(), s, 120))'
        '   if string.find(txt, "%d") then'
        '     bad = bad .. " s" .. s'
        '   end'
        ' end'
        ' return "digits=" .. (bad == "" and "none" or bad)'
        ' end)()')
    if "digits=none" in line:
        print("  no digit in any reading, skills 0 to 10 : yes")
    else:
        print("  FAULT: a number reached a reading. DR-007 says never a")
        print("  percentage on the forehead, and this is the one place a")
        print("  player would actually see it.")
        print("    " + str(line)[:200])
        faults.append("digits")

    # 2. Looking at somebody does not change them. `positionOf` writes
    #    a repaired span, so a careless reading mutates its patient.
    line = probe(
        '(function()'
        ' local worst = "same"'
        ' for s = 0, 10 do'
        '   local r = PATIENT()'
        '   local before = SNAP(r)'
        '   SAO.Medical.readingOf(r, s, 120)'
        '   if SNAP(r) ~= before then worst = "changed" end'
        ' end'
        ' local r2 = PATIENT()'
        ' r2.infectionSpanHours = nil'
        ' local b2 = SNAP(r2)'
        ' SAO.Medical.readingOf(r2, 10, 120)'
        ' if SNAP(r2) ~= b2 then worst = "repaired" end'
        ' return "record=" .. worst'
        ' end)()')
    if "record=same" in line:
        print("  the patient is unchanged by being looked at : yes")
    else:
        print("  FAULT: looking at somebody changed them (%s)."
              % str(line)[:60])
        print("  A reading that repairs a missing span is a write, and")
        print("  this module's claim is that reading informs nothing.")
        faults.append("mutation")

    # 3. The gate itself, tier by tier. The phrases searched are the
    #    ones THIS patient produces - position 0.13 of the course, and
    #    progress ahead of it - because a border that searches for a
    #    line the subject cannot emit measures its own wording.
    #    The first draft did exactly that and reported the module
    #    silent when the module was answering correctly.
    line = probe(
        '(function()'
        ' local function has(s, word)'
        '   return string.find(JOIN(SAO.Medical.readingOf('
        '     PATIENT(), s, 120)), word) ~= nil and 1 or 0'
        ' end'
        ' return "naive=" .. has(0, "fever")'
        ' .. " trained=" .. has(3, "fever")'
        ' .. " placed3=" .. has(3, "set in")'
        ' .. " placed6=" .. has(6, "set in")'
        ' .. " judged6=" .. has(6, "holding it off")'
        ' .. " judged9=" .. has(9, "holding it off")'
        ' end)()')
    n = {k: int(v) for k, v in re.findall(r"(\w+)=(\d)", line or "")}
    if len(n) == 6:
        print("  untrained learns it is a fever          : %s"
              % ("yes" if n["naive"] else "no"))
        print("  trained does                            : %s"
              % ("yes" if n["trained"] else "no"))
        print("  trained can place it in the course      : %s"
              % ("yes" if n["placed3"] else "no"))
        print("  practised can                           : %s"
              % ("yes" if n["placed6"] else "no"))
        print("  practised gets a verdict on the body    : %s"
              % ("yes" if n["judged6"] else "no"))
        print("  a medic does                            : %s"
              % ("yes" if n["judged9"] else "no"))
        if n["naive"] or n["placed3"] or n["judged6"]:
            print("  FAULT: somebody was told more than their skill")
            print("  earns them.")
            faults.append("overtold")
        if not (n["trained"] and n["placed6"] and n["judged9"]):
            print("  FAULT: somebody was told less than their skill")
            print("  earns them, so the tiers do nothing.")
            faults.append("undertold")
    else:
        print("    " + str(line)[:200])
        faults.append("tiers")

    print("-" * 74)
    if faults:
        print("  144) what an examiner can tell: FAIL")
        print("REFUSED: " + ", ".join(sorted(set(faults))))
        return 1
    print("  144) a reading carries no number, changes nobody, and tells "
          "each examiner only what they could actually tell")
    print("MATCH: DR-007 holds where a player would see it.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
