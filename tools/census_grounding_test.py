#!/usr/bin/env python3
r"""Border 24 - who the county is, against who Kentucky was.

The operator's direction: research the rates so the default
reflects what the reality was at the time, rather than controlling
it from sandbox guesses.

`Census.BASE` sums to exactly 10000 and it is NOT an uncited table -
its header states the grounding plainly: "per-10k adults of a
defensible circa-1993 Meade/Hardin County, Kentucky - rural, riverine,
manufacturing-heavy, and sitting in Fort Knox's lap", with the
operator's own ratification of approximation recorded beside it.

So the gap this closes is not provenance. It is that the claim was
never CHECKED against anything. A stated grounding nothing tests is a
sentence, and it drifts the moment a row is added or reweighted - the
same class as [B33]'s default drift, one field over.

PROVENANCE OF THE REFERENCE, stated plainly because it is the point:
the 1990 shares below are the US employed-civilian distribution by
major occupational group under the 1990 Census Occupational
Classification, as reported by web search on 2026-08-27. The primary
source is
https://www.bls.gov/cps/majocc19902002.htm
which refused direct retrieval (HTTP 403), so these figures are
SEARCH-REPORTED AND NOT VERIFIED AGAINST THE PRIMARY TABLE. They are
recorded here at that confidence and no higher. Anyone who can open
the BLS table should correct them and delete this paragraph.

WHAT THIS BORDER DOES AND DOES NOT FAIL ON
------------------------------------------
It does NOT fail on divergence from the national distribution. Knox
County is rural Kentucky, not the United States: more farming and
fewer executives is the correct answer here, not a defect, and a
border that demanded national shares would be measuring the wrong
country.

It fails on three things it can actually know:

  1. A base row nobody classified. A new occupation added without
     saying what kind of work it is silently leaves the comparison,
     and the distribution stops being checkable.
  2. The base table no longer summing to 10000.
  3. An entire major group at ZERO that the reference says was more
     than 3% of everyone working. That is not a regional difference,
     it is a population the county cannot produce at all.

Rule 3 is why this exists: it found that the county had no managers,
no supervisors and no technicians of any kind.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CENSUS = (ROOT / "mod" / "42.20" / "media" / "lua" / "shared"
          / "SAO_Census.lua")

# US employed civilians, 1990, by major occupational group.
# See the provenance note above: search-reported, not verified.
REFERENCE_1990 = {
    "executive, administrative, managerial": 10.2,
    "professional specialty": 12.9,
    "technicians and related support": 3.4,
    "marketing and sales": 11.5,
    "administrative support, clerical": 17.9,
    "service": 15.7,
    "precision production, craft, repair": 11.5,
    "operators, fabricators, laborers": 14.1,
    "farming, forestry, fishing": 2.9,
}

# Our own rows, classified into those groups. This is OUR reading of
# OUR table - authored, and the only way the comparison can exist -
# so an unclassified row is a border finding rather than a silent gap.
GROUP_OF = {
    "manager": "executive, administrative, managerial",
    "foreman": "executive, administrative, managerial",
    "owner": "executive, administrative, managerial",
    "labtech": "technicians and related support",
    "emt": "technicians and related support",
    "electech": "technicians and related support",
    "teacher": "professional specialty",
    "engineer": "professional specialty",
    "nurse": "professional specialty",
    "doctor": "professional specialty",
    "minister": "professional specialty",
    "salesperson": "marketing and sales",
    "clerk": "administrative support, clerical",
    "postal": "administrative support, clerical",
    "waitress": "service",
    "bartender": "service",
    "burgerflipper": "service",
    "chef": "service",
    "nursesaide": "service",
    "security": "service",
    "police": "service",
    "fireofficer": "service",
    "fitness": "service",
    "parkranger": "service",
    "carpenter": "precision production, craft, repair",
    "electrician": "precision production, craft, repair",
    "mechanic": "precision production, craft, repair",
    "metalworker": "precision production, craft, repair",
    "repairman": "precision production, craft, repair",
    "smither": "precision production, craft, repair",
    "tailor": "precision production, craft, repair",
    "factoryhand": "operators, fabricators, laborers",
    "trucker": "operators, fabricators, laborers",
    "construction": "operators, fabricators, laborers",
    "farmhand": "farming, forestry, fishing",
    "farmer": "farming, forestry, fishing",
    "rancher": "farming, forestry, fishing",
    "fisherman": "farming, forestry, fishing",
    "lumberjack": "farming, forestry, fishing",
}

# Rows that are not an occupation at all. The 1990 shares are over
# EMPLOYED CIVILIANS, so comparing our whole table against them would
# be comparing a population to a workforce - a homemaker is not an
# unemployed anything, and a retiree is not a rare occupation.
NOT_IN_WORKFORCE = {"homemaker", "retiree", "student", "unemployed"}

# Employed, but outside the civilian classification the reference uses.
OUTSIDE_CLASSIFICATION = {"soldier", "veteran", "burglar"}


def base_rows():
    src = CENSUS.read_text(encoding="utf-8", errors="ignore")
    m = re.search(r"Census\.BASE = \{(.*?)\n\}", src, re.S)
    if not m:
        raise SystemExit("census_grounding: Census.BASE moved; blind")
    rows = re.findall(
        r'\{ key = "([^"]+)",\s*label = "([^"]+)",\s*per10k = (\d+)',
        m.group(1))
    if not rows:
        raise SystemExit("census_grounding: parsed no rows; blind")
    return [(k, l, int(p)) for k, l, p in rows], src


def main():
    rows, src = base_rows()
    total = sum(p for _, _, p in rows)

    faults = []
    unclassified = [k for k, _, _ in rows
                    if k not in GROUP_OF
                    and k not in NOT_IN_WORKFORCE
                    and k not in OUTSIDE_CLASSIFICATION]
    for k in unclassified:
        faults.append(f"base row {k!r} is classified into no major group "
                      "- the distribution is no longer checkable")
    if total != 10000:
        faults.append(f"the base table sums to {total}, not 10000")

    outside = sum(p for k, _, p in rows if k in OUTSIDE_CLASSIFICATION)
    idle = sum(p for k, _, p in rows if k in NOT_IN_WORKFORCE)
    employed = total - idle - outside

    ours = {g: 0 for g in REFERENCE_1990}
    for k, _, p in rows:
        g = GROUP_OF.get(k)
        if g:
            ours[g] += p

    print("=" * 74)
    print("WHO THE COUNTY IS, AGAINST WHO KENTUCKY WAS")
    print("=" * 74)
    print(f"  base table {total}/10k over {len(rows)} lives")
    print(f"    not in the workforce : {idle:>5}  "
          f"({100.0 * idle / total:.1f}%)  homemaker, retiree, student, "
          "out-of-work")
    print(f"    outside the classing : {outside:>5}  "
          f"({100.0 * outside / total:.1f}%)  soldier, veteran, burglar")
    print(f"    employed civilians   : {employed:>5}  "
          f"({100.0 * employed / total:.1f}%)  <- what the 1990 shares "
          "are OVER")
    print()
    print(f"  {'major group':<38} {'ours':>7} {'1990':>7}   ")
    print(f"  {'-' * 38} {'-' * 7} {'-' * 7}")
    for g in sorted(REFERENCE_1990, key=lambda x: -REFERENCE_1990[x]):
        share = 100.0 * ours[g] / employed if employed else 0.0
        ref = REFERENCE_1990[g]
        mark = ""
        if ours[g] == 0 and ref > 3.0:
            mark = "  <- ABSENT"
            faults.append(
                f"nobody in the county is {g} - the reference puts it at "
                f"{ref}% of everyone working, and this is not a regional "
                "difference but a population we cannot produce")
        elif share > ref * 1.8:
            mark = "  (well over)"
        elif share < ref * 0.55:
            mark = "  (well under)"
        print(f"  {g:<38} {share:>6.1f}% {ref:>6.1f}%{mark}")

    print()
    print("  Divergence is NOT a fault: Knox County is rural Kentucky,")
    print("  so more farming and fewer executives is the right answer.")
    print("  An empty group is a fault - that is a kind of person the")
    print("  county can never produce.")

    # [B38] The county's composition is ours, not the mod list's.
    # Measured on the operator's session: 31 mod-registered lives, 24
    # of them at exactly 60/10k, together about a seventh of everyone -
    # and that share grew with every profession mod installed. The
    # bucket rates are relative weight AMONG those lives; the block is
    # held to a fixed share of the county however many arrive.
    print()
    print("  THE MOD-ADDED SHARE")
    m = re.search(r"^local MOD_SHARE = (\d+)$", src, re.M)
    share = int(m.group(1)) if m else None
    links = {
        "the block is bounded": share is not None,
        "and applied": "if modTotal > MOD_SHARE then" in src,
        "scaled, not truncated": "local scale = MOD_SHARE / modTotal" in src,
        "never rounded out of existence":
            "math.max(1, scaled)" in src,
        "bucket rates are still relative":
            "per10k = BUCKETS[bucket] or BUCKETS.trades" in src,
    }
    if share is not None:
        print(f"    at most {share}/10k of a {total}/10k county "
              f"({100.0 * share / (total + share):.1f}% of everyone) may be "
              "lives no base row describes")
    for k, v in links.items():
        print(f"    {'yes' if v else 'NO '}  {k}")
        if not v:
            faults.append(f"the mod-added share is unbounded: {k}")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  24) census grounding: {len(rows)} lives all classified, "
          f"{total}/10k, no major group empty")
    return 0


if __name__ == "__main__":
    sys.exit(main())
