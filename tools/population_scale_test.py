#!/usr/bin/env python3
r"""Border 23 - the county sizes itself, and the road stays open.

[B38]. A flat sixty was one number for every possible map. Measured
against the operator's own install it came out as five people a town:
sixty spread round-robin across TWELVE spawn regions, two of which
came from map mods the flat number could not know about.

So the target derives from the map - one town's worth per spawn
region - and installing more county gets more people.

The trap this border exists for is the one that was actually hit
while writing it. Arrivals are gated on `newcomers > population`, and
`newcomers` was a second flat number (180). A derived county of 216
against a fixed ceiling of 180 closes the road **silently**: no error,
no log line, and the only symptom is that nobody ever walks in again -
which is indistinguishable from a quiet county. So the two numbers
have to move together, and that is asserted here rather than
remembered.

Mirrors the constants out of the shipped Lua; nothing here is a second
copy of them.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
POP = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Population.lua"
OPTS = ROOT / "mod" / "42.20" / "media" / "sandbox-options.txt"


def constants():
    src = POP.read_text(encoding="utf-8", errors="ignore")
    out = {}
    for name in ("PER_REGION", "DERIVED_FLOOR", "DERIVED_CEILING",
                 "NEWCOMER_RATIO", "NEWCOMER_CEILING"):
        m = re.search(rf"^local {name} = (\d+)$", src, re.M)
        if not m:
            raise SystemExit(
                f"population_scale_test: {name} moved; this mirror is blind")
        out[name] = int(m.group(1))
    return out, src


def target_for(regions, c):
    t = regions * c["PER_REGION"]
    return max(c["DERIVED_FLOOR"], min(c["DERIVED_CEILING"], t))


def ceiling_for(target, c):
    return min(c["NEWCOMER_CEILING"], target * c["NEWCOMER_RATIO"])


def main():
    c, src = constants()
    opts = OPTS.read_text(encoding="utf-8", errors="ignore")

    print("=" * 70)
    print("THE COUNTY SIZES ITSELF")
    print("=" * 70)
    print(f"  {c['PER_REGION']} people a town, held between "
          f"{c['DERIVED_FLOOR']} and {c['DERIVED_CEILING']}")
    print()
    print("  regions   people   road ceiling   what that is")
    notes = {
        1: "a single-town map",
        4: "a small map mod set",
        12: "the base map, and the operator's install",
        20: "a heavily mapped county",
        40: "everything on the workshop at once",
    }
    for n in (1, 4, 12, 20, 40):
        t = target_for(n, c)
        print(f"  {n:>7}   {t:>6}   {ceiling_for(t, c):>12}   {notes[n]}")

    ok = {}

    # 1. Bounded, for any map anybody could install.
    ok["bounded for every map"] = all(
        c["DERIVED_FLOOR"] <= target_for(n, c) <= c["DERIVED_CEILING"]
        for n in range(0, 200))

    # 2. Monotonic - more county is never fewer people.
    seq = [target_for(n, c) for n in range(0, 60)]
    ok["more county is never fewer people"] = all(
        b >= a for a, b in zip(seq, seq[1:]))

    # 3. Never smaller than the flat number it replaces.
    ok["never below the old flat sixty"] = min(seq) >= 60

    # 4. The map must actually change the answer. Every check above
    # passes with PER_REGION at zero - bounded, monotonic, never below
    # sixty - while the county quietly stops asking the map at all and
    # sits on the floor forever. Deriving from something means the
    # something has to move the result.
    ok["the map actually changes the answer"] = (
        target_for(20, c) > target_for(1, c))

    # 5. THE TRAP: the road must stay open at every scale.
    ok["the road stays open at every scale"] = all(
        ceiling_for(target_for(n, c), c) > target_for(n, c)
        for n in range(0, 200))

    # 5. Zero means ask the map, on the screen and in the Lua both.
    ok["screen default is derive (Population)"] = bool(re.search(
        r"option SurvivorAwareness\.Population \{\s*\n\s*type = integer,"
        r" min = 0, max = 500, default = 0,", opts))
    ok["screen default is derive (Newcomers)"] = bool(re.search(
        r"option SurvivorAwareness\.Newcomers \{\s*\n\s*type = integer,"
        r" min = 0, max = 500, default = 0,", opts))

    links = {
        "the map is asked": "local function countRegions()" in src
            and "SpawnRegionMgr.getSpawnRegions()" in src,
        "the target resolves": "local function resolveTarget(conf)" in src,
        "the ceiling resolves with it":
            "local function resolveNewcomers(conf, target)" in src,
        "an explicit number still wins":
            "if conf.population and conf.population > 0 then" in src,
        "and both are applied before anything reads them":
            "conf.population = resolveTarget(conf)" in src
            and "conf.newcomers = resolveNewcomers(conf, conf.population)"
            in src,
        "counted per region, not per spawn point":
            "if p.region and not seen[p.region] then" in src,
    }

    print()
    print("  THE SHIPPED LINKS")
    for k, v in links.items():
        print(f"    {'yes' if v else 'NO '}  {k}")

    print()
    print("VERDICT:")
    for k, v in ok.items():
        print(f"  {'yes' if v else 'NO '}  {k}")
    good = all(ok.values()) and all(links.values())
    if not good:
        print("  FAULT: the county does not size itself safely")
        return 1
    print(f"  23) population scale: {c['PER_REGION']}/region, "
          f"{c['DERIVED_FLOOR']}-{c['DERIVED_CEILING']}, road open at "
          f"every scale")
    return 0


if __name__ == "__main__":
    sys.exit(main())
