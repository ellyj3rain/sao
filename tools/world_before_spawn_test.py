#!/usr/bin/env python3
r"""Border 115 - the world is generated before it is spawned ([C41],
DR-036).

Genesis used to pace at six people per pass whatever the state of the
save, so a sixty-person county took a minute of play to exist and the
first survivors a player met had woken into a world with almost nobody
in it. The county accreted around the player rather than being there
first. On a save that has never been settled the budget is now the
whole county, and because genesis runs ahead of the band in the tick
rotation it finishes before any body is materialised.

WHAT THIS HOLDS
---------------
  1. The budget is the target on a fresh save and the pace afterwards,
     read off the source rather than assumed.
  2. The pace is named once, not spelled twice - a bare 6 and a bare 8
     two hundred lines apart were the same rule written twice, and the
     mate slack must not be smaller than a unit can be or a family is
     cut in half at the budget's edge.
  3. The flag is written only when the target is actually reached, so
     an interrupted run carries on next pass instead of pacing a
     half-built county for the rest of the save.
  4. THE ORDERING LAW, which is what makes the claim true at all:
     genesis runs before the band in the tick, so "generated" really
     does precede "spawned". If that order ever inverts, the whole
     batch is a lie and this is the only thing that would notice.
  5. Nothing else changed about who a person is: the border checks the
     per-person work is still in the loop - the past, the trade
     ground, the home claim, the unit and its bonds.

An optional argv[1] points the checker at another tree root, which is
how its control runs: the pre-batch tree paces a fresh county.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
POP = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Population.lua"
REGISTRY = ROOT / "DECISION_REGISTRY.md"
ROADMAP = ROOT / "ROADMAP.md"
CHECK = ROOT / "tools" / "check.sh"


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""


def main():
    faults = []
    print("=" * 74)
    print("THE WORLD IS GENERATED BEFORE IT IS SPAWNED")
    print("=" * 74)

    if not POP.exists():
        print("  FAULT: SAO_Population.lua does not exist")
        return 1
    pop = read(POP)

    # 1. The budget.
    budget = re.search(r"local budget = (\w+) and (\w+) or (\w+)\n", pop)
    if not budget:
        faults.append(
            "genesis has no budget that changes with the county's state - a "
            "fresh save paces six at a time and the world grows around "
            "whoever is standing in it")
    else:
        settled_value, paced, whole = budget.groups()
        print("     budget: %s -> %s, otherwise %s" % (settled_value, paced, whole))
        if whole not in ("capNow", "target"):
            faults.append(
                "the unsettled budget is '%s' and not the county's own target, "
                "so a fresh save still does not settle in one pass" % whole)
        if paced == whole:
            faults.append("both arms of the budget are the same value, so the "
                          "branch decides nothing")
    if re.search(r"while count < capNow and bornThisPass < 6 do", pop):
        faults.append("the loop still carries the bare six it was written with")

    # 2. The pace, named once.
    pace = re.search(r"local PACE_PER_PASS = (\d+)\n", pop)
    mates = re.search(r"local PACE_MATES = (\d+)\n", pop)
    if not pace or not mates:
        faults.append("the pace and its mate slack are not named, so the same "
                      "rule is spelled twice two hundred lines apart again")
    else:
        print("     pace: %s a pass, %s of slack for a unit" % (pace.group(1),
                                                               mates.group(1)))
        if int(mates.group(1)) < 2:
            faults.append(
                "the mate slack is %s: a unit of three settled at the budget's "
                "edge would be cut in half, and a family that starts as two "
                "thirds of itself is a defect nobody would see"
                % mates.group(1))
    if re.search(r"bornThisPass >= 8 then break", pop):
        faults.append("the mate break still carries the bare eight")

    # 3. The flag, written only on reaching the target.
    flags = {
        "the flag is read before the budget is chosen":
            "local settled = genesisSettled()" in pop
            and pop.index("function genesisSettled") < pop.index("local settled = genesisSettled()"),
        "the flag is written only when the target is reached":
            "if wholeCounty and count >= capNow then" in pop
            and "markGenesisSettled(count, capNow)" in pop,
        "an interrupted run says so and carries on":
            "the next pass carries on before anyone spawns" in pop,
        "the flag lives in the county's own store":
            "s.countySettled = true" in pop,
    }

    # 4. The ordering law - the whole claim rests on it.
    genesis_at = pop.find('runSub("genesis"')
    band_at = pop.find('runSub("band"')
    flags["genesis runs before the band in the tick"] = (
        genesis_at >= 0 and band_at >= 0 and genesis_at < band_at)
    if genesis_at < 0 or band_at < 0:
        faults.append("the tick no longer names genesis and band as subsystems, "
                      "so the order that makes 'before it is spawned' true "
                      "cannot be read at all")

    # 5. The per-person work is still in the loop.
    loop_at = pop.find("while count < capNow and bornThisPass < budget do")
    loop = pop[loop_at:pop.find("\nlocal function backfillName", loop_at)] if loop_at >= 0 else ""
    for what, needle in (
            ("a past", "SAO.History.generate"),
            ("the trade's own ground", "pickOriginFor"),
            ("the place they woke in", "SAO.Perception.learnBuilding"),
            ("a home claim from the first day", "SAO.Standing.claim"),
            ("the unit they began in", "rec.unitId, rec.unitKind"),
            ("and its bonds", "SAO.Standing.bond")):
        flags["genesis still gives them " + what] = needle in loop

    flags["the registry carries the direction"] = (
        "## DR-036" in read(REGISTRY))
    flags["the roadmap carries the arc, not just this slice"] = (
        "## Day zero forward (DR-036" in read(ROADMAP)
        and "SHIPPED as `[C41]`" in read(ROADMAP))
    flags["the gate runs this border"] = (
        "tools/world_before_spawn_test.py" in read(CHECK))

    print()
    for k, v in flags.items():
        print(f"  {'yes' if v else 'NO '}  {k}")
        if not v:
            faults.append(k)

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print("  FAULT: " + f)
        return 1
    print("  115) the world is generated before it is spawned: the whole "
          "county on a fresh save, paced only once it exists, and genesis "
          "ahead of the band in the tick")
    return 0


if __name__ == "__main__":
    sys.exit(main())
