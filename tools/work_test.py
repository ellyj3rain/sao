#!/usr/bin/env python3
"""The work test ([B25]) - can the house ever judge anyone's work?

Fourth application of the [B24]/[B24]/[B24] method: probe a gate chain
for the link that can never fire.

[B21] lets a house revoke a designation when the state of the work
shows it. Its chain:

    a designation is dealt ([B2] class prior, then the skill yield)
      -> the house looks at the STATE of that work
           medic:         housemates carrying fouled dressings or
                          open bleeding
           cook:          food still dangerous raw in the larder
           quartermaster: the house's own counts gone stale
      -> two pieces of evidence revoke it, one per election
      -> [B13] re-deals next time, [B22] offers the road back

**Medic, cook and quartermaster are judgeable.** [B25] added the last,
correcting [B25]: all three of the house's counts are made in the
quartermaster's branch and nowhere else, so letting them age out is
their failure alone.

Watch, scout and forager stay deliberately unjudged - a quiet night
does not prove a good watch, and a thin larder may mean the county is
empty rather than the forager idle.

So the whole feature rests on a narrow mouth: **how often does a house
contain a judgeable job at all?**

## What this can and cannot price

**Cannot:** how often anyone is wounded, or how much raw food sits in
a larder. Those read real bodies and real containers on a real map.
Inventing rates for them would be authoring numbers, which [B23]
named as a trap and this project refuses.

**Can:** whether a judgeable designation exists to be judged. If the
county rarely produces one, [B21] is inert no matter how
often people are hurt - and that is a structural finding, not a
tuning question.

The mirror has no perks, so it cannot model [B2]'s skill yield (a
Doctor-skilled trucker taking the medic work, a chef taking the cook
work). It therefore UNDERSTATES both, and the census shares are
reported separately so the gap is visible rather than hidden.
"""
import contextlib
import io
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

_quiet = io.StringIO()
with contextlib.redirect_stdout(_quiet):
    import equilibrium_test as eq

# [B2]'s class prior, exactly: the leader leads, the rest work their class.
DESIG_BY_CLASS = {"hardened": "watch", "outdoors": "scout",
                  "carer": "medic", "settled": "quartermaster",
                  "trades": "forager"}
# [B25] The quartermaster makes all three of the house's counts -
# larder, water, hearth - and nobody else does. They are judged on
# letting those go stale. [B25] said they had no distinct work and
# was wrong.
JUDGEABLE = {"medic", "cook", "quartermaster"}


def houses():
    by_group = {}
    for member, g in eq.group.items():
        by_group.setdefault(g, []).append(member)
    return {g: sorted(m) for g, m in by_group.items()}


def census_shares():
    """Live census weights, so the skill-yield gap is visible."""
    src = (pathlib.Path(__file__).resolve().parent.parent
           / "mod/42.20/media/lua/shared/SAO_Census.lua"
           ).read_text(encoding="utf-8")
    rows = re.findall(
        r'\{ key = "([^"]+)",\s*label = "([^"]+)",\s*per10k = (\d+)', src)
    total = sum(int(p) for _, _, p in rows) or 1
    want = {"chef", "burgerflipper", "doctor", "nurse", "nursesaide"}
    return {k: int(p) / total for k, _, p in rows if k in want}, total


def main():
    hs = houses()
    print("The work test ([B25]) - reachability of [B21]'s judgement")
    print(f"county: {len(hs)} companies out of {eq.N} people")

    tally = {}
    with_judgeable = 0
    for g, ms in hs.items():
        lead = eq.leader_of(g)
        jobs = []
        for m in ms:
            if m == lead:
                tally["leads"] = tally.get("leads", 0) + 1
                continue
            j = DESIG_BY_CLASS[eq.CLASSES[m]]
            tally[j] = tally.get(j, 0) + 1
            jobs.append(j)
        if any(j in JUDGEABLE for j in jobs):
            with_judgeable += 1

    print("\n--- designations dealt by the class prior ---")
    for job in sorted(tally, key=lambda k: -tally[k]):
        mark = "  <- JUDGEABLE" if job in JUDGEABLE else ""
        print(f"  {job:14} {tally[job]:3}{mark}")

    print("\n--- the mouth of the chain ---")
    print(f"  companies holding a judgeable job: "
          f"{with_judgeable}/{len(hs)}")
    print(f"  companies where [B21] can never judge anyone: "
          f"{len(hs) - with_judgeable}/{len(hs)}")

    shares, total = census_shares()
    print("\n--- what the skill yield could add (mirror cannot model it) ---")
    for k in sorted(shares):
        print(f"  {k:14} {100.0 * shares[k]:5.2f}% of the census")
    print("  a chef or a line cook can take the COOK work via [B2]'s yield;")
    print("  the mirror has no perks, so the figures above are a floor.")

    print("\nVERDICT:")
    if with_judgeable == 0:
        print("  NO COMPANY CAN EVER BE JUDGED - structural block")
        print("    cause: the class prior produced no judgeable designation")
        return 1
    print(f"  [B21] is reachable in {with_judgeable} of {len(hs)} companies")
    print("  NOT priced here: how often anyone is wounded, or how much raw")
    print("  food sits in a larder - both read the real world.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
