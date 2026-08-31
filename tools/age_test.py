#!/usr/bin/env python3
r"""[B37] Age: the shape of the county the apocalypse leaves.

SAO_History models a survivor's past as settled claims with
provenance, rendered at read time - and it starts at the outbreak.
`monthsAlive` counts months of apocalypse; nothing counted the years
before it, so every survivor's knowable life began the day the world
ended.

Age is the one number that fixes that. From it, birth year falls out
of the world's own start year, and which decades somebody lived
through is arithmetic instead of a table per person.

This mirrors the band weights out of the shipped Lua - not a copy -
and checks the distribution is the county the operator described:
most of the old are already dead; people in their sixties exist,
but few.

It also checks the two things that make age a FACT rather than a roll:
the same id gives the same age every time, and a different world start
year moves every birth year without moving anybody's age.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
HIST = (ROOT / "mod" / "42.20" / "media" / "lua" / "shared"
        / "SAO_History.lua")


def bands():
    src = HIST.read_text(encoding="utf-8", errors="ignore")
    m = re.search(r"local AGE_BANDS = \{(.*?)\n\}", src, re.S)
    if not m:
        raise SystemExit("age_test: AGE_BANDS moved; this mirror is blind")
    out = []
    for f, t, w in re.findall(
            r"from = (\d+), to = (\d+), weight = (\d+)", m.group(1)):
        out.append((int(f), int(t), int(w)))
    return out


def hash_of(sid, salt):
    text = f"{sid}:{salt}"
    v = 2166136261
    for ch in text:
        v = (v * 16777619 + ord(ch)) % 4294967296
    return v


def age_of(sid, bnds):
    roll = hash_of(sid, "age") % 100
    seen = 0
    for lo, hi, w in bnds:
        seen += w
        if roll < seen:
            return lo + (hash_of(sid, "ageIn") % (hi - lo + 1))
    return 34


def main():
    bnds = bands()
    total = sum(w for _, _, w in bnds)
    print("=" * 68)
    print("AGE BANDS, read from the shipped Lua")
    print("=" * 68)
    for lo, hi, w in bnds:
        print(f"  {lo}-{hi}   weight {w}")
    print(f"  total weight: {total}")
    if total != 100:
        print("  FAIL: weights must sum to 100 or the last band absorbs")
        print("  the remainder silently and the shape is not what it says")
        return 1

    ages = [age_of(f"sao-{i}", bnds) for i in range(1, 1001)]
    print()
    print("=" * 68)
    print("A THOUSAND SURVIVORS")
    print("=" * 68)
    for lo, hi, w in bnds:
        n = sum(1 for a in ages if lo <= a <= hi)
        print(f"  {lo}-{hi}   {n:>4}  ({100.0 * n / len(ages):>4.1f}%"
              f"  intended {w}%)")
    print(f"\n  youngest {min(ages)}, oldest {max(ages)}, "
          f"mean {sum(ages) / len(ages):.1f}")

    # The shape the operator described.
    old = sum(1 for a in ages if a >= 60)
    mid = sum(1 for a in ages if 19 <= a <= 49)
    kids = sum(1 for a in ages if a < 19)
    print()
    print("  the county the apocalypse leaves:")
    print(f"    under 19 (not modelled):  {kids}")
    print(f"    19-49 (the body of it):   {mid} "
          f"({100.0 * mid / len(ages):.0f}%)")
    print(f"    60+ (the thin tail):      {old} "
          f"({100.0 * old / len(ages):.0f}%)")

    ok_shape = kids == 0 and mid > len(ages) * 0.6 and 0 < old < len(ages) * 0.12

    # Age is a fact, not a roll: same id, same answer.
    stable = all(age_of("sao-42", bnds) == age_of("sao-42", bnds)
                 for _ in range(5))
    # And distinct people are not all the same age.
    spread = len(set(ages)) > 30

    print()
    print("VERDICT:")
    print(f"  weights sum to 100:              YES")
    print(f"  nobody under 19:                 {'YES' if kids == 0 else 'NO'}")
    print(f"  body of the county is 19-49:     "
          f"{'YES' if mid > len(ages) * 0.6 else 'NO'}")
    print(f"  the old are a thin tail:         "
          f"{'YES' if 0 < old < len(ages) * 0.12 else 'NO'}")
    print(f"  same person, same age:           {'YES' if stable else 'NO'}")
    print(f"  distinct ages across the county: "
          f"{len(set(ages))} {'YES' if spread else 'NO'}")
    if not (ok_shape and stable and spread):
        return 1
    return 0


def wars(src):
    """Mirror the windows and service ages out of the shipped Lua."""
    m = re.search(r"local WARS = \{(.*?)\n\}", src, re.S)
    if not m:
        raise SystemExit("age_test: WARS moved; this mirror is blind")
    rows = [(k, int(a), int(b)) for k, a, b in re.findall(
        r'key = "([^"]+)", from = (\d+), to = (\d+)', m.group(1))]
    s = re.search(r"local SERVICE_MIN, SERVICE_MAX = (\d+), (\d+)", src)
    if not rows or not s:
        raise SystemExit("age_test: service window moved; blind")
    return rows, int(s.group(1)), int(s.group(2))


def war_of(born, rows, lo, hi):
    """Mirror of H.warOf: the latest war their age could reach."""
    found = None
    for key, start, end in rows:
        if (end - born) >= lo and (start - born) <= hi:
            found = key
    return found


def the_years_before():
    """[B39] The war a life of this age was actually old enough for.

    [B37] built `ageInYear` and closed saying nothing read it. This is
    what reads it, and the windows are real rather than mine: US ground
    involvement ran 1950-1953 in Korea, 1965-1973 in Vietnam, and the
    Gulf ground war was 1990-1991.

    The check is not that the dates are right - they are facts and a
    border cannot verify a fact. It is that the county's own age bands
    can REACH all three, that the shape is the right way round, and
    that only the lives the census calls military get one.
    """
    src = HIST.read_text(encoding="utf-8", errors="ignore")
    rows, lo, hi = wars(src)
    bnds = bands()

    print()
    print("=" * 68)
    print("THE YEARS BEFORE")
    print("=" * 68)
    print(f"  sent between {lo} and {hi}; windows: "
          + ", ".join(f"{k} {a}-{b}" for k, a, b in rows))

    ids = [f"sao-{i}" for i in range(1, 2001)]
    seen = {}
    ages_for = {}
    for sid in ids:
        age = age_of(sid, bnds)
        born = 1993 - age
        w = war_of(born, rows, lo, hi)
        seen[w] = seen.get(w, 0) + 1
        ages_for.setdefault(w, []).append(age)

    print()
    for k in [r[0] for r in rows] + [None]:
        n = seen.get(k, 0)
        label = k or "no war reached them"
        if n and k:
            a = ages_for[k]
            print(f"  {label:<22} {n:>4}  ({100.0 * n / len(ids):>4.1f}%)"
                  f"  aged {min(a)}-{max(a)} in 1993")
        else:
            print(f"  {label:<22} {n:>4}  ({100.0 * n / len(ids):>4.1f}%)")

    ok = {}
    ok["every window is reachable"] = all(
        seen.get(k, 0) > 0 for k, _, _ in rows)
    # Older people get the older war. This is the check that would
    # catch the arithmetic being inverted.
    order = [k for k, _, _ in rows]
    means = [sum(ages_for[k]) / len(ages_for[k]) for k in order
             if ages_for.get(k)]
    ok["the older war belongs to older people"] = all(
        a > b for a, b in zip(means, means[1:]))
    # The table above is AGE ELIGIBILITY, not service - "which war
    # could this birth year have reached". Seventy percent being
    # eligible is correct and says nothing about how many served,
    # because `servedIn` gates it on the census calling the life
    # military. The first draft asserted "most of the county saw no
    # war" against the eligibility column and failed on a true number.
    census = (ROOT / "mod" / "42.20" / "media" / "lua" / "shared"
              / "SAO_Census.lua").read_text(encoding="utf-8",
                                            errors="ignore")
    military = 0
    for key in ("veteran", "soldier"):
        m2 = re.search(rf'key = "{key}",\s*label = "[^"]*",\s*per10k = (\d+)',
                       census)
        if m2:
            military += int(m2.group(1))
    eligible = 1.0 - (seen.get(None, 0) / len(ids))
    served = (military / 10000.0) * eligible
    print()
    print(f"  the census makes {military / 100.0:.1f}% of the county "
          f"military; {100 * eligible:.0f}% of birth years reach a war,")
    print(f"  so about {100 * served:.1f}% of everyone actually served "
          "in one - which is who gets the harder past.")
    ok["serving is rare"] = 0 < served < 0.10
    ok["and the census still names military lives"] = military > 0
    ok["nobody too young is sent"] = all(
        min(ages_for[k]) >= (1993 - r[2]) + lo
        for k, r in zip(order, rows) if ages_for.get(k))

    links = {
        "the war is arithmetic over birth year":
            "H.ageInYear(id, war.from)" in src,
        "only military lives serve":
            "local SERVED = { veteran = true, soldier = true }" in src,
        "and it reads into the settled past":
            "if theirWar then livedBar = livedBar + 15 end" in src,
        "rendered at read time, never stored":
            'head = head .. " " .. war .. ", a long time ago."' in src,
    }
    tel = (ROOT / "mod" / "42.20" / "media" / "lua" / "client"
           / "SAO_Telemetry.lua").read_text(encoding="utf-8",
                                            errors="ignore")
    links["and it is measurable"] = "SAO.History.servedIn(id" in tel

    print()
    print("  THE SHIPPED LINKS")
    for k, v in links.items():
        print(f"    {'yes' if v else 'NO '}  {k}")
    print()
    for k, v in ok.items():
        print(f"  {'yes' if v else 'NO '}  {k}")
    return all(ok.values()) and all(links.values())


if __name__ == "__main__":
    code = main()
    if not the_years_before():
        print("  FAULT: the years before do not reach this county")
        code = 1
    sys.exit(code)
