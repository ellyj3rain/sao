#!/usr/bin/env python3
r"""What a simulated year actually costs, measured rather than guessed.

The operator ruled (DR-037) that the years between 1993 and a later
start run for real - the ground is loaded and the work happens. That
was questioned as unaffordable, and the question said so without
measuring anything, which is not how a claim gets made in this
repository.

So this measures. Two halves, and it is honest about which is which:

  THE RECORD SIDE, timed here. The county's own per-pass work - the
  conditions a body carries, what a habit does, the day's roll for old
  age, the standings softening - driven over a real county in the
  engine's own Kahlua VM, the same instrument every other border uses.
  The number that comes out is a real measurement on this machine.

  THE WORLD SIDE, bounded here and NOT timed. Loading ground needs the
  running game, so this reports the volume instead: how much map data
  a county's worth of claims covers, off the shipped files. Anyone
  reading this should treat the world-side line as an upper bound on
  data moved, not as a duration.

Run directly: `python tools/years_cost.py`. It prints a table and exits
0. It is deliberately NOT a gate border and asserts nothing, because a
measurement that fails a build is a threshold in disguise and no
threshold has been ratified - and it is named without `_test` for the
same reason, since the gate's own reach check treats every `*_test.py`
as a border that must be able to fail.
"""
import pathlib
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent
HERE = pathlib.Path(__file__).resolve().parent
SHARED = ROOT / "mod" / "42.20" / "media" / "lua" / "shared"
HASH = SHARED / "SAO_Hash.lua"
HISTORY = SHARED / "SAO_History.lua"
COND = SHARED / "SAO_Conditions.lua"
HABITS = SHARED / "SAO_Habits.lua"
PRELUDE = HERE / "luacheck" / "probe_age.lua"
SRC = HERE / "luacheck" / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"
MAPS = PZ_DIR / "media" / "maps" / "Muldraugh, KY"

# The county as the options screen ships it, and the ground one
# household holds (SAO_Population: groundAround(..., 4), a 9x9 box).
POPULATION = 216
CLAIM_SIDE = 9
CHUNK_SIDE = 8          # IsoChunk: a cell is 256 squares over 32 chunks
PASSES_PER_DAY = 144    # the age module's cadence: every ten in-game minutes
DAYS_PER_YEAR = 365

STORE = ("local store = {} SAO.Identity.get = function(id) local r = store[id] "
         "if not r then r = { id = id } store[id] = r end return r end ")


def build():
    cls = OUT / "LuaRun.class"
    if cls.exists() and cls.stat().st_mtime >= SRC.stat().st_mtime:
        return True
    OUT.mkdir(parents=True, exist_ok=True)
    done = subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(OUT), str(SRC)],
        capture_output=True, text=True, timeout=300)
    return done.returncode == 0


def probe(expr, timeout=1800):
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(STDLIB, work / "stdlib.lua")
        for c in OUT.glob("*.class"):
            shutil.copy2(c, work / c.name)
        started = time.time()
        done = subprocess.run(
            [str(JDK / "java.exe"), "-cp", f"{PZ};.", "LuaRun",
             str(PRELUDE), str(HASH), str(HISTORY), str(COND), str(HABITS),
             "--", expr],
            cwd=str(work), capture_output=True, text=True, timeout=timeout)
        wall = time.time() - started
    line = (done.stdout or "").strip().split("\n")[-1] if done.stdout else ""
    return (line[6:] if line.startswith("VALUE ") else line), wall


# One pass of the per-person work the years would drive, over the whole
# county: what each condition carries, what each habit carries, and the
# words - every call the age module makes on a living body every ten
# in-game minutes, minus the engine ones a dormant person has no body
# for.
def pass_expr(people, passes):
    return (
        "(function() " + STORE +
        "local Cn, Hb = SAO.Conditions, SAO.Habits "
        "local ids = {} for i = 1, %d do ids[i] = 'sao-' .. i end "
        "local touched = 0 "
        "for p = 1, %d do "
        "for i = 1, #ids do local id = ids[i] "
        "local d = Cn.drift(id) for _ in pairs(d) do touched = touched + 1 end "
        "local h = Hb.drift(id, nil, p) for _ in pairs(h) do touched = touched + 1 end "
        "if Cn.hearsThingsNow(id, p) then touched = touched + 1 end "
        "end end "
        "return 'touched=' .. touched end)()" % (people, passes))


def daily_expr(people, days):
    return (
        "(function() " + STORE +
        "local Cn, Hb, H = SAO.Conditions, SAO.Habits, SAO.History "
        "local ids = {} for i = 1, %d do ids[i] = 'sao-' .. i end "
        "local settled, lost = 0, 0 "
        "for day = 1, %d do "
        "for i = 1, #ids do local id = ids[i] "
        "local age = H.ageOf(id) "
        "if H.oldAgeRiskPerDay(age) > 0 then settled = settled + 1 end "
        "if Cn.losesSkillsToday(id) then lost = lost + 1 end "
        "Hb.settleUsers(id, day * 24) "
        "end end "
        "return 'settled=' .. settled .. ' lost=' .. lost end)()" % (people, days))


def map_volume():
    """How much shipped map data a county's claims cover, and what the
    whole map is - off the files, not from memory."""
    packs = sorted(MAPS.glob("*.lotpack"))
    if not packs:
        return None
    total = sum(p.stat().st_size for p in packs)
    cells = len(packs)
    per_cell = total / cells
    chunks_per_cell = (256 // CHUNK_SIDE) ** 2
    per_chunk = per_cell / chunks_per_cell
    # A claim is a 9x9 box; it touches at most four chunks when it
    # straddles both boundaries, which most will.
    chunks_per_claim = 4
    households = max(1, POPULATION // 2)   # units run one to several
    return {
        "cells": cells,
        "total_bytes": total,
        "per_cell": per_cell,
        "per_chunk": per_chunk,
        "households": households,
        "claim_chunks": households * chunks_per_claim,
        "claim_bytes": households * chunks_per_claim * per_chunk,
    }


def human(n):
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024 or unit == "GB":
            return "%.1f %s" % (n, unit)
        n /= 1024.0
    return str(n)


def main():
    print("=" * 74)
    print("WHAT A SIMULATED YEAR COSTS")
    print("=" * 74)
    if not (JDK.exists() and PZ.exists() and STDLIB.exists() and SRC.exists()):
        print("  no JDK, engine jar, stdlib or runner - nothing could be timed")
        return 0
    if not build():
        print("  the runner will not compile against the installed jar")
        return 0

    print()
    print("  THE RECORD SIDE - timed in the engine's own VM, on this machine")
    print("  %-34s %10s %12s" % ("what", "passes", "seconds"))

    # A short run first, so the sample is honest about warm-up, then a
    # longer one the extrapolation actually rests on.
    samples = []
    for passes in (10, 60):
        answer, wall = probe(pass_expr(POPULATION, passes))
        samples.append((passes, wall, answer))
        print("  %-34s %10d %12.2f" % ("ten-minute pass, whole county",
                                       passes, wall))

    # The second sample carries the per-pass cost with the VM already
    # warm; the first is kept only to show the warm-up exists.
    (p1, w1, _), (p2, w2, _) = samples
    per_pass = max(0.0, (w2 - w1) / max(1, (p2 - p1)))
    day = per_pass * PASSES_PER_DAY
    year = day * DAYS_PER_YEAR

    dayswork, dwall = probe(daily_expr(POPULATION, 30))
    per_day_roll = dwall / 30.0

    print()
    print("  %-34s %22.4f" % ("per ten-minute pass", per_pass))
    print("  %-34s %22.2f" % ("per simulated day (144 passes)", day))
    print("  %-34s %22.2f" % ("per simulated day, the day's roll", per_day_roll))
    print("  %-34s %22.1f" % ("per simulated YEAR, seconds",
                              year + per_day_roll * DAYS_PER_YEAR))
    print("  %-34s %22.1f" % ("three years, minutes",
                              (year + per_day_roll * DAYS_PER_YEAR) * 3 / 60.0))
    print()
    print("  county of %d, %d passes a day. This is the county's OWN work"
          % (POPULATION, PASSES_PER_DAY))
    print("  and none of it is the engine's: no bodies, no map, no rendering.")

    volume = map_volume()
    print()
    print("  THE WORLD SIDE - volume only, off the shipped files. NOT a")
    print("  duration: loading ground needs the running game and nothing")
    print("  here times it.")
    if not volume:
        print("    the shipped map was not found at %s" % MAPS)
        return 0
    print("  %-34s %22s" % ("shipped map, whole", human(volume["total_bytes"])))
    print("  %-34s %22d" % ("cells on disk", volume["cells"]))
    print("  %-34s %22s" % ("one cell, 256x256 squares", human(volume["per_cell"])))
    print("  %-34s %22s" % ("one chunk, 8x8 squares", human(volume["per_chunk"])))
    print("  %-34s %22d" % ("households at the shipped county", volume["households"]))
    print("  %-34s %22d" % ("chunks their claims touch", volume["claim_chunks"]))
    print("  %-34s %22s" % ("map data behind those claims",
                            human(volume["claim_bytes"])))
    print()
    print("  So the ground a county's households actually stand on is a")
    print("  small fraction of the map, and it is the same ground every")
    print("  time - which is the shape worth measuring in the game: load")
    print("  a claim, do the work, let it go, rather than holding a county")
    print("  loaded for three years.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
