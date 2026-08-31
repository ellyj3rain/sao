#!/usr/bin/env python3
r"""Border 25 - the county arrives in twos and threes.

The operator ruled that many should arrive in groups of two or
three - family units, friend units, mixed units.

Before [B38] a life had a one-in-five chance of a single bonded mate
and otherwise started alone, so a county of two hundred was a hundred
and seventy solitary strangers.

The part this border exists to protect is not the shares - those are
a judgement and may move. It is that **the relation is DERIVED**. A
unit records only what kind it is; who two of its people are to each
other falls out of the ages they already have ([B37], which until now
read nowhere). Choosing a relation and then choosing ages to match
would be authoring the same fact twice, and would drift.

So this drives the derivation over a modelled county using the
shipped band weights and the shipped hash, and requires the shipped
links that make it real.
"""
import pathlib
import re
import sys
from collections import Counter

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
POP = LUA / "client" / "SAO_Population.lua"
HIST = LUA / "shared" / "SAO_History.lua"


def lua(path):
    return path.read_text(encoding="utf-8", errors="ignore")


def weighted(src, name, field):
    m = re.search(rf"local {name} = \{{(.*?)\n\}}", src, re.S)
    if not m:
        raise SystemExit(f"units_test: {name} moved; this mirror is blind")
    rows = re.findall(rf'{field} = "?(\w+)"?, weight = (\d+)', m.group(1))
    if not rows:
        raise SystemExit(f"units_test: parsed no {name} rows; blind")
    return [(k, int(w)) for k, w in rows]


def bands(src):
    m = re.search(r"local AGE_BANDS = \{(.*?)\n\}", src, re.S)
    return [(int(a), int(b), int(w)) for a, b, w in re.findall(
        r"from = (\d+), to = (\d+), weight = (\d+)", m.group(1))]


def hash_of(text, salt):
    v = 2166136261
    for ch in f"{text}:{salt}":
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


def relation(a, b, kind, bnds, gap):
    if kind == "friends":
        return "friend"
    if kind != "family":
        return "companion"
    aa, ab = age_of(a, bnds), age_of(b, bnds)
    if abs(aa - ab) >= gap:
        return "parent" if aa > ab else "child"
    first, second = (a, b) if str(a) < str(b) else (b, a)
    # Mirrors coinOf, and NOT `% 2`. FNV's low bit is a parity
    # checksum of the input, so across ids that differ by a digit it
    # barely moves - it gave 9% heads over a thousand pairs, which is
    # how a county of families came out three quarters siblings.
    coin = (hash_of(f"{first}+{second}", "kin") // 65536) % 2
    return "partner" if coin == 0 else "sibling"


def back(rel):
    return {"parent": "child", "child": "parent"}.get(rel, rel)


def main():
    psrc, hsrc = lua(POP), lua(HIST)
    sizes = weighted(psrc, "UNIT_SIZES", "size")
    kinds = weighted(psrc, "UNIT_KINDS", "bond")
    bnds = bands(hsrc)
    m = re.search(r"local GENERATION_GAP = (\d+)", hsrc)
    if not m:
        raise SystemExit("units_test: GENERATION_GAP moved; blind")
    gap = int(m.group(1))

    ok = {}
    print("=" * 70)
    print("HOW THE COUNTY ARRIVES")
    print("=" * 70)
    st = sum(w for _, w in sizes)
    kt = sum(w for _, w in kinds)
    avg = sum(int(s) * w for s, w in sizes) / st
    print(f"  unit sizes: " + ", ".join(
        f"{s} at {100 * w / st:.0f}%" for s, w in sizes))
    print(f"  unit kinds: " + ", ".join(
        f"{k} at {100 * w / kt:.0f}%" for k, w in kinds))
    print(f"  average unit {avg:.2f} people -> a county of 216 is about "
          f"{round(216 / avg)} parties, {round(216 / avg / 12)} a town")
    alone = next((w for s, w in sizes if int(s) == 1), 0)
    print(f"  and {100 * alone / st:.0f}% still come through it alone")

    ok["sizes are a distribution"] = st == 100
    ok["kinds are a distribution"] = kt == 100
    ok["most people are not alone"] = alone < st / 2
    ok["twos and threes exist"] = any(int(s) > 1 for s, _ in sizes)

    # Drive the derivation over a modelled county.
    print()
    print("=" * 70)
    print("WHO THEY TURN OUT TO BE - derived from ages, not chosen")
    print("=" * 70)
    seen = Counter()
    symmetric = True
    for i in range(0, 3000, 3):
        a, b = f"sao-{i}", f"sao-{i + 1}"
        for kind in ("family", "friends", "mixed"):
            r = relation(a, b, kind, bnds, gap)
            seen[(kind, r)] += 1
            if back(r) != relation(b, a, kind, bnds, gap):
                symmetric = False
    fam = {r: n for (k, r), n in seen.items() if k == "family"}
    famtot = sum(fam.values())
    for r in sorted(fam, key=lambda x: -fam[x]):
        print(f"  family -> {r:<9} {fam[r]:>5}  "
              f"({100.0 * fam[r] / famtot:.0f}%)")
    print(f"  friends -> friend, mixed -> companion")
    print(f"  a {gap}-year gap is what separates a household from a "
          "generation")

    ok["families are not all one relation"] = len(fam) >= 3
    ok["both generations appear"] = fam.get("parent", 0) > 0 \
        and fam.get("child", 0) > 0
    ok["and so do peers"] = fam.get("partner", 0) > 0 \
        and fam.get("sibling", 0) > 0
    ok["the relation reads the same from both sides"] = symmetric

    # The assertion that would have caught it. Partner and sibling are
    # a coin flip between two people of an age with each other, and
    # `hashOf % 2` made it 75/7 because FNV's low bit is a parity
    # checksum. A verdict alone would have passed - only printing the
    # distribution showed it - so the balance is now required.
    peers = fam.get("partner", 0) + fam.get("sibling", 0)
    split = fam.get("partner", 0) / peers if peers else 0
    print(f"  partner/sibling split {100 * split:.0f}/"
          f"{100 - 100 * split:.0f} - a coin, and it has to look like one")
    ok["the coin is not a parity checksum"] = 0.40 <= split <= 0.60

    links = {
        "origination rolls a unit": "local size, kind = rollUnit()" in psrc,
        "every pair in it is bonded":
            "for b = a + 1, #mates do" in psrc,
        "trust differs by kind": "UNIT_TRUST[kind]" in psrc,
        "the unit is recorded on the person":
            "mate.unitId, mate.unitKind = unitId, kind" in psrc,
        "a family shares its name":
            'rec.unitKind == "family"' in psrc,
        "the relation is derived": "function H.relationIn" in hsrc,
        "and it reads AGE": "H.ageOf(aId), H.ageOf(bId)" in hsrc,
        "the pair settles peer relations, not the person":
            'coinOf(pair, "kin")' in hsrc,
        # The RULE, not the function's existence. This mirror computes
        # the coin in Python, so mutating the Lua's arithmetic cannot
        # fail the model - the balance check above stays green while
        # the shipped county goes back to 75/7. Third time this trap
        # has been walked into ([B37] twice), so the shipped
        # expression itself is what is required.
        "and does not flip a parity checksum for a coin":
            "math.floor(hashOf(id, salt) / 65536) % 2" in hsrc,
        "no coin site went back to the low bit":
            "hashOf(id, 21) % 2" not in hsrc
            and 'hashOf(pair, "kin") % 2' not in hsrc,
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
        print("  FAULT: the county does not arrive as units, or the "
              "relation is not derived from age")
        return 1
    print(f"  25) units: {avg:.2f} people a unit, relations derived from "
          f"age across a {gap}-year generation")
    return 0


if __name__ == "__main__":
    sys.exit(main())
