#!/usr/bin/env python3
r"""[B33] How long the road actually takes.

The operator questioned a figure rather than a feeling: "twenty five
years, meaning... that's a lot of people, but it's subjective to what
people want." That number came from arrivals one a month, one at a
time, filling a county from 60 to 360 - 300 months, 25 years.

The month was a hardcoded 720.0 hours. [B33] makes the wait derive from
how long the sky has been quiet, on the reading that the country does
not stop falling the day the helicopter leaves: each month it stays
quiet, more of what is out there is walking.

    wait = 720 / (1 + pressure * sqrt(quietMonths))     floored at 24h

`pressure` is the only new dial. At 0 the term vanishes and the wait is
720 hours forever, which is exactly the behaviour that shipped - so an
untouched world is not merely close to the old one, it is identical,
and this mirror asserts that rather than claiming it.

Every constant is parsed out of SAO_Population.lua. Ported rules drift,
and these decide the answer.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = (ROOT / "mod" / "42.20" / "media" / "lua" / "client"
       / "SAO_Population.lua")

# PZ's default day length is one real hour per game day; the operator
# plays there, having moved down from an hour and a half.
REAL_HOURS_PER_GAME_DAY = 1.0


def constants():
    """Base month, floor, and the default pressure, from the Lua."""
    s = SRC.read_text(encoding="utf-8", errors="ignore")
    base = re.search(r"local accel = 1\.0 \+ .*?\n\s*\* math\.sqrt\("
                     r"quietH / ([0-9.]+)\)", s, re.S)
    wait = re.search(r"local wait = ([0-9.]+) / accel", s)
    floor = re.search(r"if wait < ([0-9.]+) then wait = \1 end", s)
    dflt = re.search(r"roadPressure = \(sv and tonumber\("
                     r"sv\.RoadPressure\)\) or ([0-9.]+)", s)
    traffic = re.search(r"roadTraffic = \(sv and tonumber\("
                        r"sv\.RoadTraffic\)\) or (\d+)", s)
    if not (base and wait and floor and dflt and traffic):
        raise SystemExit(
            "arrival_test: cannot find [B33]'s constants in "
            "SAO_Population.lua - the rule moved or was removed, and "
            "this mirror is blind")
    return (float(wait.group(1)), float(base.group(1)),
            float(floor.group(1)), float(dflt.group(1)),
            int(traffic.group(1)))


MONTH, SCALE, FLOOR, DEFAULT_PRESSURE, DEFAULT_TRAFFIC = constants()


def wait_at(quiet_hours, pressure):
    """The interval the Lua would compute, at this much quiet."""
    if quiet_hours < 0:
        quiet_hours = 0.0
    accel = 1.0 + pressure * ((quiet_hours / SCALE) ** 0.5)
    w = MONTH / accel
    return FLOOR if w < FLOOR else w


def fill(start, target, traffic, pressure, cap_years=200):
    """Game-hours from sky-quiet until the ceiling reaches target."""
    here, quiet = start, 0.0
    limit = cap_years * 365 * 24
    while here < target and quiet < limit:
        quiet += wait_at(quiet, pressure)
        here += traffic
    return quiet if here >= target else None


def years(h):
    return h / (24.0 * 365.0)


def main():
    print("=" * 70)
    print("CONTROL - pressure 0 must be the month that shipped, exactly")
    print("=" * 70)
    flat = [wait_at(q, 0.0) for q in (0, 720, 7200, 72000, 720000)]
    ok_flat = all(abs(w - MONTH) < 1e-9 for w in flat)
    print(f"  wait at 0 / 1 / 10 / 100 / 1000 months quiet: "
          f"{[round(w) for w in flat]}")
    print(f"  every one is {MONTH:.0f}h: {'YES' if ok_flat else 'NO'}")

    print()
    print("=" * 70)
    print("CONTROL - pressure above 0 must actually shorten the wait,")
    print("          and must never fall below the floor")
    print("=" * 70)
    rising = [wait_at(q, 1.0) for q in (0, 720, 7200, 72000)]
    ok_rise = all(a > b for a, b in zip(rising, rising[1:]))
    ok_floor = all(wait_at(q, 5.0) >= FLOOR
                   for q in range(0, 720000, 720))
    print(f"  pressure 1, waits at 0/1/10/100 months: "
          f"{[round(w) for w in rising]}")
    print(f"  strictly shortening: {'YES' if ok_rise else 'NO'}")
    print(f"  never below the {FLOOR:.0f}h floor even at pressure 5: "
          f"{'YES' if ok_floor else 'NO'}")

    print()
    print("=" * 70)
    print("THE OPERATOR'S FIGURE - 60 to 360, and what the dial does")
    print("=" * 70)
    print(f"  (defaults as shipped: pressure={DEFAULT_PRESSURE}, "
          f"traffic={DEFAULT_TRAFFIC})")
    print()
    print("  pressure   traffic 1     traffic 2     traffic 4     "
          "traffic 8")
    print("  " + "-" * 66)
    for p in (0.0, 0.5, 1.0, 2.0, 3.0, 5.0):
        row = f"  {p:<10}"
        for tr in (1, 2, 4, 8):
            h = fill(60, 360, tr, p)
            row += (f" {years(h):>6.1f}y     " if h is not None
                    else "   never    ")
        print(row)

    print()
    print("  the 25-year figure is pressure 0, traffic 1: "
          f"{years(fill(60, 360, 1, 0.0)):.1f}y")
    print("  today's shipped default (pressure 0, traffic 2):  "
          f"{years(fill(60, 360, DEFAULT_TRAFFIC, 0.0)):.1f}y")

    print()
    print("=" * 70)
    print("IN HOURS AT THE TABLE - one real hour per game day")
    print("=" * 70)
    print("  what it costs to reach 360, in hours actually played")
    for p in (0.0, 1.0, 3.0, 5.0):
        h = fill(60, 360, DEFAULT_TRAFFIC, p)
        played = (h / 24.0) * REAL_HOURS_PER_GAME_DAY
        print(f"    pressure {p:<4} traffic {DEFAULT_TRAFFIC}:  "
              f"{years(h):>5.1f} game-years = {played:>7.0f} hours "
              "played")

    print()
    print("VERDICT:")
    print(f"  pressure 0 is byte-for-byte the old month?  "
          f"{'YES' if ok_flat else 'NO'}")
    print(f"  pressure shortens the wait?                 "
          f"{'YES' if ok_rise else 'NO'}")
    print(f"  floor respected?                            "
          f"{'YES' if ok_floor else 'NO'}")
    if not (ok_flat and ok_rise and ok_floor):
        print("  INSTRUMENT FAILED ITS OWN CONTROLS")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
