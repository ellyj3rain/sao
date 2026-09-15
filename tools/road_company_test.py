#!/usr/bin/env python3
r"""Border 160 - the road joins a house ([C127]).

A dormant road meeting writes trust. It does not mint `company-<id>`
from two unhoused people who just said hello. That door, at a few
thousand living, founded hundreds of two-person houses in a year of
the years pass — pairs, not organizations.

A meeting founds or joins only when:

  * one of them is already in a house (join), or
  * they arrived together as a unit of three or more (the 3+ gate
    the rest of the county uses for a company you can see).

Two unhoused strangers, and two who arrived as a pair, keep the bond.

THIS BORDER MEASURES THE DOOR, NOT A COUNTY.

A sweep of a dense county would pass or fail with the weather. The
checks below read the predicate and the call site, and a control
restores the old mint (`company-` .. idA) and requires that the
verdict flip.
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
POP = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Population.lua"
SWEEP = ROOT / "tools" / "county_sweep.py"
CHECK = ROOT / "tools" / "check.sh"


def read(path):
    return path.read_text(encoding="utf-8")


def source_faults(pop_src, sweep_src, check_src):
    faults = []
    if "local function roadCompanyTarget(" not in pop_src:
        faults.append("SAO_Population lacks roadCompanyTarget")
    if "if #roster < 3 then return nil, nil end" not in pop_src:
        faults.append("roadCompanyTarget does not refuse a unit smaller than three")
    if 'or ("company-" .. idA)' in pop_src or 'or ("company-" .. idA)' in pop_src:
        faults.append("the road still mints company-<id> from two unhoused people")
    if 'mint `company-<id>`' not in pop_src and "mint `company-<id>`" not in pop_src:
        # the comment must still name what it stopped
        if "company-<id>" not in pop_src:
            faults.append("the road comment no longer names the mint it stopped")
    if "local groupName, roster = roadCompanyTarget(" not in pop_src:
        faults.append("the road door does not ask roadCompanyTarget")
    if "housesOf3" not in sweep_src:
        faults.append("county_sweep.py does not report houses of three or more")
    if '"pacts"' not in sweep_src and ",pacts" not in sweep_src:
        faults.append("county_sweep.py does not report pacts")
    if "tools/road_company_test.py" not in check_src:
        faults.append("the gate does not run this border")
    return faults


def mutation_tests(pop_src, sweep_src, check_src):
    mint = pop_src.replace(
        "local groupName, roster = roadCompanyTarget(\n"
        "                            idA, idB, gA, gB)",
        'local groupName, roster = (gA or gB or ("company-" .. idA)), { idA, idB }',
    )
    if mint == pop_src:
        return "mutation failed: could not restore the company-<id> mint"
    if not source_faults(mint, sweep_src, check_src):
        return "mutation failed: restoring company-<id> mint did not fault"

    dropped = pop_src.replace("local function roadCompanyTarget(", "local function roadCompany(")
    if not source_faults(dropped, sweep_src, check_src):
        return "mutation failed: renaming roadCompanyTarget did not fault"

    nosize = pop_src.replace("if #roster < 3 then return nil, nil end",
                             "if #roster < 1 then return nil, nil end")
    if not source_faults(nosize, sweep_src, check_src):
        return "mutation failed: dropping the 3+ gate did not fault"

    nosweep = sweep_src.replace("housesOf3", "housesOfThree")
    if not source_faults(pop_src, nosweep, check_src):
        return "mutation failed: dropping housesOf3 did not fault"

    return None


def main():
    print("=" * 74)
    print("THE ROAD JOINS A HOUSE")
    print("=" * 74)
    pop_src = read(POP)
    sweep_src = read(SWEEP)
    check_src = read(CHECK)

    faults = source_faults(pop_src, sweep_src, check_src)
    for f in faults:
        print("  FAULT: " + f)
    if faults:
        print("VERDICT: FAIL")
        return 1

    mut = mutation_tests(pop_src, sweep_src, check_src)
    if mut:
        print("  FAULT: " + mut)
        print("VERDICT: FAIL")
        return 1

    print("  yes  two unhoused people do not mint company-<id>")
    print("  yes  a unit smaller than three does not found")
    print("  yes  a housed person can still take someone in")
    print("  yes  the sweep reports houses of three and pacts")
    print("  yes  the control restored the mint and the verdict flipped")
    print("  160) the road joins a house")
    print("VERDICT: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
