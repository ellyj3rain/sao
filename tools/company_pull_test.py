#!/usr/bin/env python3
r"""Border 152 - need stands alongside trust ([C111]).

The operator's ruling (2026-09-12, on the queue's item 3): a road
meeting is worth more, most people not only want but NEED to be
around people, and trust is not always the principal determinant of
whether a group forms - which depends on how far along into the
apocalypse the world is. Until that batch every formation gate read
trust alone, and with a meeting worth 0.005 the company line was two
hundred meetings off: a house could only ever grow out of trust
settled at genesis, and nobody lonely ever founded anything.

The law this border holds, from both sides:

  * The pull is three factors the county already holds - appetite
    (who somebody is), isolation (where they are right now), and
    openness (how far the county's condition makes company a need
    rather than a risk, months since the fall over a horizon of six
    - the one number here that is not already the county's, stated
    so the operator can move it).
  * Need substitutes for trust not yet built; it NEVER cancels trust
    already spent against somebody - the pull reads only where trust
    is not negative.
  * Zero whenever any factor cannot be read - offline, a bare VM, a
    dead or unknown id - so every gate degrades to trust alone,
    which is the law that ran before.
  * Every company door reads the pair standing - the road, the
    table, the companion seam, the player's own asks - and
    temperament still gates after the line clears; need does not
    overrule temperament.
  * Read once a county hour and held; a person's need does not
    change inside one.

The [C111] batch record closed with: "A border for this law belongs
to the end pass with the rest of the deferred verification; none was
written here, per the standing order." This is that border. The
arithmetic is MEASURED, not described: the VM runs the shipped
Standing behind the real sweep prelude, holds the isolation surface
the way a fixture holds a position, and steps the county's condition
through the split clock's own seam (recordDay - the fact clockMonths
reads).

An optional argv[1] points the checker at another tree root, which
is how its control runs.
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
CHECK = ROOT / "tools" / "check.sh"
SRC = HERE / "luacheck" / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
PRELUDE_FILE = ROOT / "tools" / "sweep" / "prelude.lua"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"

# The dormant county's own module set - what carries Standing and the
# history it reads. The same set Border 147 runs.
MODULES = [
    "shared/SAO_Log.lua", "shared/SAO_Hash.lua", "shared/SAO_Rand.lua",
    "shared/SAO_Census.lua", "shared/SAO_History.lua",
    "shared/SAO_Disposition.lua", "shared/SAO_Conditions.lua",
    "shared/SAO_Habits.lua", "shared/SAO_Claims.lua", "shared/SAO_Identity.lua",
    "shared/SAO_Lessons.lua", "shared/SAO_Knowledge.lua",
    "shared/SAO_Seams.lua", "shared/SAO_Standing.lua",
    "shared/SAO_Perception.lua", "shared/SAO_Places.lua",
    "client/SAO_Age.lua", "client/SAO_Telemetry.lua",
    "client/SAO_Population.lua",
]

PROBE = r"""(function()
  -- People are created in the county the prelude runs, exactly as
  -- the dump would see them, before anything is pinned; no pass runs
  -- in this probe, the pull and the standing are read directly.
  local function make(x, y)
    local r = SAO.Identity.create(nil, nil, x, y, 0)
    pcall(function() SAO.History.generate(r.id, r) end)
    return r
  end
  local me = make(10500, 9000)
  local mate = make(10503, 9000)
  local hermit = make(10600, 9100)
  local half = make(10600, 9200)
  local stranger = make(10700, 9300)

  -- The county's condition is stepped through its own seam: the
  -- split clock ([C61]) reads recordDay, so recordDay is what this
  -- probe holds - a fixture controlling the fact, not the formula.
  -- The isolation surface is held the way a fixture holds a
  -- position: per-person readings, pinned to the numbers this
  -- border measures, and nil for an id the county cannot read.
  _G.__months = 6
  SAO.History.recordDay = function()
    return (_G.__months or 6) * 30.0
  end
  SAO.Isolation = {
    of = function(id)
      if id == me.id then
        return { appetite = 0.8, isolation = 1.0 }
      elseif id == hermit.id then
        return { appetite = 0.1, isolation = 1.0 }
      elseif id == half.id then
        return { appetite = 0.8, isolation = 0.5 }
      end
      return nil
    end,
  }
  local function nextHour()
    _G.__hours = (_G.__hours or 0) + 1.0
  end

  local S = SAO.Standing
  -- Six months into collapse: openness is the whole horizon.
  local pullFull = S.companyPull(me.id)            -- 0.8
  local pullHermit = S.companyPull(hermit.id)      -- 0.1
  local pullHalf = S.companyPull(half.id)          -- 0.4
  -- The condition changes inside one county hour and the pull is
  -- held - a person's need does not change inside one.
  _G.__months = 3
  local memoHeld = S.companyPull(me.id)            -- 0.8 still
  nextHour()
  local pullHalved = S.companyPull(me.id)          -- 0.4

  -- Back at the horizon's end, in its own county hour (the memo
  -- above is doing its job, so the door readings must not borrow the
  -- months-3 hour's pull). The standing a company door reads: trust
  -- toward a mate, plus the pull. A fifth of trust and a
  -- four-fifths need is a whole line.
  nextHour()
  _G.__months = 6
  S.adjustTrust(me.id, mate.id, 0.2)
  local standCarry = S.companyStanding(me.id, mate.id)
  local bar = 0.5
  pcall(function()
    bar = tonumber(SandboxVars.SurvivorAwareness.TrustToCompany) or 0.5
  end)
  local doorYes = standCarry >= bar and 1 or 0
  -- No trust at all toward a stranger: need alone at the door, and
  -- a fully isolated sociable person's need carries the whole line.
  local standAlone = S.companyStanding(me.id, stranger.id)
  local doorAlone = standAlone >= bar and 1 or 0
  -- A quarrel, struck in one stroke so the arithmetic is exact:
  -- trust already spent against somebody. Need is standing right
  -- there at 0.8 and must not soften a word of it.
  S.adjustTrust(me.id, half.id, -0.4)
  local standQuarrel = S.companyStanding(me.id, half.id)
  -- An id the county cannot read: zero, which degrades every gate
  -- to trust alone - and trust toward an unknown is honestly zero.
  local pullUnknown = S.companyPull("nobody")
  local standUnknown = S.companyStanding("nobody", mate.id)

  -- An ordinary county, before the fall has had time to make company
  -- a need: the pull carries nobody, and the standing is the
  -- acquaintance and nothing else.
  nextHour()
  _G.__months = 0
  local pullBefore = S.companyPull(me.id)
  S.adjustTrust(me.id, stranger.id, 0.15)
  local standBefore = S.companyStanding(me.id, stranger.id)
  -- The memo holds this side of the clock too.
  _G.__months = 6
  local memoAfter = S.companyPull(me.id)

  return "pullFull=" .. tostring(pullFull)
    .. " pullHermit=" .. tostring(pullHermit)
    .. " pullHalf=" .. tostring(pullHalf)
    .. " memoHeld=" .. tostring(memoHeld)
    .. " pullHalved=" .. tostring(pullHalved)
    .. " standCarry=" .. tostring(standCarry)
    .. " doorYes=" .. tostring(doorYes)
    .. " standAlone=" .. tostring(standAlone)
    .. " doorAlone=" .. tostring(doorAlone)
    .. " standQuarrel=" .. tostring(standQuarrel)
    .. " pullUnknown=" .. tostring(pullUnknown)
    .. " standUnknown=" .. tostring(standUnknown)
    .. " pullBefore=" .. tostring(pullBefore)
    .. " standBefore=" .. tostring(standBefore)
    .. " memoAfter=" .. tostring(memoAfter)
end)()"""


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
        prelude.write_text(PRELUDE_FILE.read_text(encoding="utf-8"),
                           encoding="utf-8")
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
    return {k: v for k, v in re.findall(r"([\w.]+)=([-\w./:' ]+?)(?=\s\w+=|$)",
                                        line or "")}


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") \
        if path.exists() else ""


def main():
    faults = []
    print("=" * 74)
    print("NEED STANDS ALONGSIDE TRUST")
    print("=" * 74)

    standing = read(LUA / "shared" / "SAO_Standing.lua")
    population = read(LUA / "client" / "SAO_Population.lua")
    controller = read(LUA / "client" / "SAO_Controller.lua")
    harness = read(LUA / "client" / "SAO_Harness.lua")
    exchange = read(LUA / "client" / "SAO_Exchange.lua")

    seams = {
        "the pull reads the live isolation surface, not a static factor":
            "SAO.Isolation.of(id)" in standing,
        "the horizon of six months is stated so the operator can move it":
            "months / 6.0" in standing,
        "need never cancels trust already spent":
            "if t < 0 then return t end" in standing,
        "the pull is read once a county hour and held":
            "if hour ~= pullHour then" in standing,
        "a road meeting is worth more, both ways":
            "local ROAD_TRUST = 0.02" in population
            and population.count("adjustTrust(idA, idB, ROAD_TRUST)") == 1
            and population.count("adjustTrust(idB, idA, ROAD_TRUST)") == 1,
        "the road reads the pair standing":
            population.count("companyStanding(") >= 3,
        "the companion seam reads the pair standing":
            controller.count("companyStanding(") >= 1,
        "the player's own asks read the pair standing":
            harness.count("companyStanding(") >= 1,
        "the table reads the pair standing, both sides":
            exchange.count("companyStanding(") >= 2,
        "temperament still gates company after the line clears":
            population.count("circleRefuses") >= 1,
        "the gate runs this border":
            "tools/company_pull_test.py" in read(CHECK),
    }

    if not (JDK.exists() and PZ.exists() and STDLIB.exists()
            and SRC.exists()):
        print("  SKIPPED the VM - no JDK, engine jar, stdlib or runner")
        print()
        for k, v in seams.items():
            print("  %s  %s" % ("yes" if v else "NO ", k))
            if not v:
                faults.append(k)
        print()
        if faults:
            print("VERDICT: FAIL")
            return 1
        print("  152) need stands alongside trust: TEXT ONLY, the "
              "engine install is absent")
        return 0
    if not build():
        print("  FAULT: LuaRun does not compile against the installed jar")
        return 1

    line = probe(PROBE)
    got = numbers(line)
    print()
    print("     a sociable person alone, six months into collapse:")
    print("       " + line)
    print()

    if line.startswith("ERROR"):
        print("  FAULT: the VM would not run the probe")
        print("  " + line[:400])
        return 1

    want = {
        "pullFull": ("0.8",
                     "the full pull came back %s; appetite 0.8 at full "
                     "isolation in a county at the horizon's end must "
                     "read 0.8"),
        "pullHermit": ("0.1",
                       "a hermit's pull came back %s; an appetite of 0.1 "
                       "is a need that carries almost nothing, and it "
                       "must"),
        "pullHalf": ("0.4",
                     "a half-isolated person's pull came back %s; where "
                     "they are right now is half the product"),
        "memoHeld": ("0.8",
                     "the pull moved inside one county hour (%s); a "
                     "person's need does not change inside one"),
        "pullHalved": ("0.4",
                       "at three months the pull came back %s; the "
                       "horizon is six, so three months is half the "
                       "need"),
        "standCarry": ("1",
                       "trust 0.2 plus pull 0.8 came back %s; the "
                       "standing at a company door is the sum"),
        "doorYes": ("1",
                    "trust a fifth and need four fifths did not clear "
                    "the company line (%s); need substitutes for trust "
                    "not yet built"),
        "standAlone": ("0.8",
                       "with no trust at all the standing came back %s; "
                       "it must be the pull alone"),
        "doorAlone": ("1",
                      "a fully isolated sociable person's need did not "
                      "carry the whole line by itself (%s); in a county "
                      "six months into collapse it must"),
        "standQuarrel": ("-0.4",
                         "a quarrel of -0.4 with need standing at 0.8 "
                         "came back %s; need NEVER cancels trust already "
                         "spent against somebody"),
        "pullUnknown": ("0",
                        "an unreadable id pulled %s; zero whenever any "
                        "factor cannot be read"),
        "standUnknown": ("0",
                         "an unreadable id stood at %s; every gate "
                         "degrades to trust alone, and trust toward an "
                         "unknown is honestly zero"),
        "pullBefore": ("0",
                       "in an ordinary county the pull came back %s; "
                       "need carries nobody before the fall has made "
                       "company a need"),
        "standBefore": ("0.15",
                        "in an ordinary county the standing came back "
                        "%s; it must be the acquaintance and nothing "
                        "else"),
        "memoAfter": ("0",
                      "the pull moved inside one county hour (%s); the "
                      "memo must hold on this side of the clock too"),
    }
    for key, (expected, story) in want.items():
        if got.get(key) != expected:
            faults.append(story % got.get(key))

    print()
    for k, v in seams.items():
        print("  %s  %s" % ("yes" if v else "NO ", k))
        if not v:
            faults.append(k)

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print("  FAULT: " + f)
        print("  152) need stands alongside trust: FAIL")
        return 1
    print("  152) appetite times isolation times openness, summed onto "
          "trust only where trust is not negative, zero when unreadable, "
          "held within the county hour, at every door: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())