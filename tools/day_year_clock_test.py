#!/usr/bin/env python3
r"""Border 161 - a year is 365 days ([C129]).

Catch-up is living days. A year is 365 of them. Game time inside a
day is 24 hours, 9000 ticks an hour. Wall-clock per game day is the
engine's DayLength, default 1.5 real hours, and is variable.

[C45] named the catch-up "the years" and then compressed each day
into one bundle. [C112] derived the tick from 150 real seconds per
game hour (one real hour per game day). [C128] lived the days on the
live cadence and left both mistakes standing as comments and as a
derivation. [C129] names the three clocks so they cannot be mixed.

THIS BORDER HOLDS THE LAW IN THE FILES THAT STATE IT.

  * History names DAYS_PER_YEAR = 365 and uses it for old-age risk.
  * History names DEFAULT_REAL_HOURS_PER_GAME_DAY = 1.5.
  * TICKS_PER_HOUR stays 9000: the game-hour quantum, not a frame
    count at the wrong default.
  * The 150-real-seconds derivation is gone from History.lua.
  * Catch-up still steps TICK_INTERVAL. There is no year-step and
    no bundled oneYearsDay.
  * The leftover "pass itself still runs once per simulated day"
    is gone from Population.lua.

A control mutates 365, 1.5, and the 150-second sentence and requires
that the verdict flip.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
HIST = ROOT / "mod" / "42.20" / "media" / "lua" / "shared" / "SAO_History.lua"
POP = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Population.lua"
CHECK = ROOT / "tools" / "check.sh"


def read(path):
    return path.read_text(encoding="utf-8") if path.exists() else ""


def source_faults(hist, pop, check):
    faults = []
    if "local DAYS_PER_YEAR = 365" not in hist:
        faults.append("History does not name DAYS_PER_YEAR = 365")
    if "local DEFAULT_REAL_HOURS_PER_GAME_DAY = 1.5" not in hist:
        faults.append("History does not name the default 1.5 real hours per game day")
    if "local TICKS_PER_HOUR = 9000" not in hist:
        faults.append("TICKS_PER_HOUR is no longer 9000")
    if "function H.daysPerYear()" not in hist:
        faults.append("History does not export daysPerYear")
    if "function H.realHoursPerGameDay()" not in hist:
        faults.append("History does not export realHoursPerGameDay")
    if "function H.ticksPerGameDay()" not in hist:
        faults.append("History does not export ticksPerGameDay")
    if "return yearly / DAYS_PER_YEAR" not in hist:
        faults.append("old-age risk still divides the year by a bare 365")
    if re.search(r"yearly\s*/\s*365\b", hist):
        faults.append("old-age risk still has a bare 365")
    if "150 real seconds" in hist:
        faults.append("History still derives the tick from 150 real seconds per game hour")
    if "a real minute a" in hist:
        faults.append("History still calls the default day length a real minute a game hour")
    if "function oneYearsDay" in pop:
        faults.append("a compressed oneYearsDay is back")
    if re.search(r"ticksAYear\s*=", pop):
        faults.append("catch-up has a year-step")
    if "ticks = ticks + TICK_INTERVAL" not in pop:
        faults.append("catch-up does not take the live population step")
    if "local ticksADay = 9000 * 24" not in pop:
        faults.append("a game day is no longer 9000 ticks x 24 game hours")
    if "the pass itself still runs once per simulated day" in pop:
        faults.append("Population still says the pass runs once per simulated day")
    if "A year is 365" not in pop and "a year is 365" not in pop:
        faults.append("Population no longer says a year is 365 days")
    if "tools/day_year_clock_test.py" not in check:
        faults.append("the gate does not run this border")
    return faults


def mutation_tests(hist, pop, check):
    year = hist.replace("local DAYS_PER_YEAR = 365",
                        "local DAYS_PER_YEAR = 360")
    if year == hist:
        return "mutation failed: could not change DAYS_PER_YEAR"
    if not source_faults(year, pop, check):
        return "mutation failed: 360-day year did not fault"

    hours = hist.replace("local DEFAULT_REAL_HOURS_PER_GAME_DAY = 1.5",
                         "local DEFAULT_REAL_HOURS_PER_GAME_DAY = 1.0")
    if hours == hist:
        return "mutation failed: could not change default real hours"
    if not source_faults(hours, pop, check):
        return "mutation failed: 1.0 real hours per game day did not fault"

    injected = hist + "\n-- a real minute a game hour: 150 real seconds\n"
    if not source_faults(injected, pop, check):
        return "mutation failed: restoring 150 real seconds did not fault"

    once = pop.replace(
        "Catch-up takes the live step 900 times a day so those gates",
        "the pass itself still runs once per simulated day so those gates",
    )
    if once == pop:
        return "mutation failed: could not restore the once-per-day pass"
    if not source_faults(hist, once, check):
        return "mutation failed: restoring once-per-day pass did not fault"

    return None


def main():
    print("=" * 74)
    print("A YEAR IS 365 DAYS")
    print("=" * 74)
    hist = read(HIST)
    pop = read(POP)
    check = read(CHECK)

    faults = source_faults(hist, pop, check)
    for f in faults:
        print("  FAULT: " + f)
    if faults:
        print("VERDICT: FAIL")
        return 1

    mut = mutation_tests(hist, pop, check)
    if mut:
        print("  FAULT: " + mut)
        print("VERDICT: FAIL")
        return 1

    print("  yes  a year is 365 days")
    print("  yes  default wall-clock is 1.5 real hours per game day")
    print("  yes  a tick is still 1/9000 of a game hour")
    print("  yes  the 150-second derivation is gone")
    print("  yes  catch-up still steps TICK_INTERVAL, not a year")
    print("  yes  the once-per-day years pass is gone")
    print("  yes  the control flipped the verdict")
    print("  161) a year is 365 days")
    print("VERDICT: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
