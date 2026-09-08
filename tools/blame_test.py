#!/usr/bin/env python3
r"""Border 127 - seeing a death is not seeing who did it ([C55], Law 1).

Two sites in the controller judged a killer on a belief about the
VICTIM. A survivor holding a fresh close sighting of somebody who was
then shot from forty tiles away, by a person behind a wall they had
never laid eyes on, dropped their trust in that person by eight tenths
and could declare a blood feud. The engine's attacker tag named the
killer; nothing asked whether the witness could have known it. That is
omniscience, which Law 1 calls a failure of the decision model - and
the same law calls oblivion one, so the death itself must still land.

The rule now splits the two consequences. The sighting of the victim
still makes somebody a witness: they know their friend is dead, they
mourn, the belief travels. A name only lands where they could have
seen who. Each half of the county asks it in the currency it has,
which is [B47]'s rule: a live witness is asked whether they hold a
fresh OBSERVED belief of the killer at the place it happened; a
dormant one has no beliefs at all, so it is the positional question -
was the killer themselves within reach of the death.

This border runs the two predicates the controller uses, extracted
into the engine's own VM (tools/luacheck/LuaRun) with a belief store
and a county built by hand, over the cases that decide it:

  * the melee kill - the killer stood over the victim and the witness
    saw them - blame lands;
  * the shot from forty tiles - the witness saw the victim and never
    the killer - the death lands and the blame does not;
  * a sighting of the killer somewhere else entirely, fresh but far
    from the death, does not count as having seen it;
  * a stale sighting of the killer at the right place does not count;
  * a belief that was told rather than observed does not count;
  * the dormant half: a killer standing at the death is blamed, one
    forty tiles off is not, and a killer nobody can place at all is
    not.

An optional argv[1] points the checker at another tree root, which is
how its control runs: the pre-batch tree has no predicates to extract
and fails at the text seams.
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
CONTROLLER = LUA / "client" / "SAO_Controller.lua"
CHECK = ROOT / "tools" / "check.sh"
SRC = HERE / "luacheck" / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

# The controller is 6000 lines and loads the world at its foot, so the
# two predicates are lifted out of it by text and run on their own.
# Lifted rather than retyped: if the file's copy changes, this changes
# with it or stops finding them, and either way the border speaks up.
NEEDLES = ("local function sawThemThere(witnessId, whoName, atX, atY, tick)",
           "local function whereIs(key)",
           "local function wasThere(key, atX, atY)")

PRELUDE = '''
SAO = SAO or {}
SAO.Perception = { beliefs = {} }
SAO.Body = { get = function(k) return _G.__bodies and _G.__bodies[k] end }
SAO.Identity = { get = function(k) return _G.__recs and _G.__recs[k] end }
SAO.Standing = { isPlayerKey = function(k)
    return string.sub(tostring(k), 1, 7) == "player:" end }
getSpecificPlayer = function() return _G.__player end
local WITNESS_REACH = 10.0
local WITNESS_FRESH = 120
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


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""


def lift(text, needle):
    """One top-level local function: its header line down to the first
    line that is exactly `end` in column zero.

    Counting `do`/`then`/`end` was tried first and miscounted, because
    a one-line `if ... then return false end` opens and closes on the
    same line; it truncated two of the three predicates and the probe
    came back empty. Column zero is the whole rule here - these are
    file-scope locals in a file that indents everything inside them -
    and if that ever stops being true the lift returns something that
    will not load, which this border reports rather than passes.
    """
    lines = text.split("\n")
    start = None
    for n, line in enumerate(lines):
        if line.startswith(needle):
            start = n
            break
    if start is None:
        return None
    for n in range(start + 1, len(lines)):
        if lines[n] == "end":
            return "\n".join(lines[start:n + 1])
    return None


def probe(body, expr):
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(STDLIB, work / "stdlib.lua")
        for c in OUT.glob("*.class"):
            shutil.copy2(c, work / c.name)
        chunk = work / "predicates.lua"
        chunk.write_text(
            PRELUDE + body
            + "\n_G.sawThemThere = sawThemThere\n_G.wasThere = wasThere\n",
            encoding="utf-8")
        done = subprocess.run(
            [str(JDK / "java.exe"), "-cp", f"{PZ};.", "LuaRun",
             str(chunk), "--", expr],
            cwd=str(work), capture_output=True, text=True, timeout=900)
    return (done.stdout or "").strip().split("\n")[-1] if done.stdout else "ERROR no output"


def value(line):
    return line[6:] if line.startswith("VALUE ") else None


def numbers(line):
    return {k: v for k, v in re.findall(r"([\w.]+)=([-\w./']+)", line or "")}


# The death is at 100,100. NOW is tick 1000.
LIVE = (
    "(function() local out = {} "
    "SAO.Perception.beliefs['w'] = { people = { "
    "  Melee   = { x = 101, y = 100, at = 990, source = 'observed' }, "
    "  Sniper  = { x = 140, y = 100, at = 990, source = 'observed' }, "
    "  Stale   = { x = 100, y = 100, at = 200, source = 'observed' }, "
    "  Hearsay = { x = 100, y = 100, at = 990, source = 'told' } } } "
    "local function t(label, who) out[#out + 1] = label .. '=' .. "
    "tostring(sawThemThere('w', who, 100, 100, 1000)) end "
    "t('melee', 'Melee') t('sniper', 'Sniper') t('stale', 'Stale') "
    "t('hearsay', 'Hearsay') t('unknown', 'NeverSeen') t('nilname', nil) "
    "SAO.Perception.beliefs['blind'] = nil "
    "out[#out + 1] = 'nostore=' .. tostring(sawThemThere('blind', 'Melee', 100, 100, 1000)) "
    "return table.concat(out, ' ') end)()")

DORMANT = (
    "(function() local out = {} "
    "_G.__recs = { atTheKill = { x = 103, y = 100 }, "
    "              farOff = { x = 160, y = 100 }, "
    "              placeless = {} } "
    "_G.__bodies = {} "
    "_G.__player = { getX = function() return 104 end, "
    "                getY = function() return 100 end } "
    "local function t(label, key) out[#out + 1] = label .. '=' .. "
    "tostring(wasThere(key, 100, 100)) end "
    "t('atkill', 'atTheKill') t('faroff', 'farOff') "
    "t('placeless', 'placeless') t('nobody', 'noSuchPerson') "
    "t('player', 'player:me') "
    "_G.__bodies = { farOff = { getX = function() return 100 end, "
    "                           getY = function() return 100 end } } "
    "t('bodybeatsrecord', 'farOff') "
    "return table.concat(out, ' ') end)()")


def main():
    faults = []
    print("=" * 74)
    print("SEEING A DEATH IS NOT SEEING WHO DID IT")
    print("=" * 74)
    ctl = read(CONTROLLER)
    if not ctl:
        print("  FAULT: SAO_Controller.lua does not exist")
        return 1
    if not (JDK.exists() and PZ.exists() and STDLIB.exists() and SRC.exists()):
        print("  FAULT: no JDK, engine jar, stdlib or runner - nothing ran on the engine")
        return 1
    if not build():
        print("  FAULT: LuaRun does not compile against the installed jar")
        return 1

    lifted = []
    for needle in NEEDLES:
        got = lift(ctl, needle)
        if not got:
            faults.append("could not lift `%s` out of the controller"
                          % needle.split("(")[0].replace("local function ", ""))
        else:
            lifted.append(got)
    if faults:
        for f in faults:
            print("  FAULT: " + f)
        return 1
    body = "\n".join(lifted)
    print("     lifted %d predicates, %d lines" % (len(lifted), body.count("\n") + 1))

    live = numbers(value(probe(body, LIVE)))
    print("     live witness:    " + " ".join("%s=%s" % kv for kv in live.items()))
    wantL = {"melee": "true", "sniper": "false", "stale": "false",
             "hearsay": "false", "unknown": "false", "nilname": "false",
             "nostore": "false"}
    for k, v in wantL.items():
        if live.get(k) != v:
            faults.append("live witness: %s is %s, wanted %s"
                          % (k, live.get(k), v))

    dorm = numbers(value(probe(body, DORMANT)))
    print("     dormant witness: " + " ".join("%s=%s" % kv for kv in dorm.items()))
    wantD = {"atkill": "true", "faroff": "false", "placeless": "false",
             "nobody": "false", "player": "true", "bodybeatsrecord": "true"}
    for k, v in wantD.items():
        if dorm.get(k) != v:
            faults.append("dormant witness: %s is %s, wanted %s"
                          % (k, dorm.get(k), v))

    seams = {
        "the death site asks who, in each half's own currency":
            "sawWho = wasThere(attackerKey, dxs, dys)" in ctl
            and "sawWho = sawThemThere(witnessId, killerName," in ctl
            and "if attackerKey and sawWho" in ctl,
        "the wounding site asks the same question":
            "local sawWho = sawThemThere(witnessId, name," in ctl
            and "and sawWho\n" in ctl,
        "a death with no name attached still lands, and is said":
            "die and not who did it - no blame lands" in ctl,
        "the victim sighting still makes the witness":
            "if qualifies and seen then seen.dead = true end" in ctl,
        "the gate runs this border":
            "tools/blame_test.py" in read(CHECK),
    }
    print()
    for k, v in seams.items():
        print(f"  {'yes' if v else 'NO '}  {k}")
        if not v:
            faults.append(k)

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print("  FAULT: " + f)
        return 1
    print("  127) blame follows sight: a killer is named only by somebody "
          "who could have seen them, and the death still lands on everybody "
          "who saw it")
    return 0


if __name__ == "__main__":
    sys.exit(main())
