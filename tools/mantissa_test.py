#!/usr/bin/env python3
r"""Border 60 - arithmetic this engine cannot actually do.

Four modules carried their own copy of this line:

    value = (value * 16777619 + string.byte(text, i)) % 4294967296

It is FNV. It is correct arithmetic. **Kahlua cannot compute it.**
Lua numbers are doubles, `value` runs to 2^32 - 1, so the product
reaches 7.2e16 - eight times past the 2^53 a mantissa holds exactly -
and every character rounds the bottom bits away.

Measured over fifty-nine real ids, `hash(id, "aggression") % 1000`:

    exact integers : 59 distinct values
    doubles        :  6 distinct values, two of them covering forty ids

The county's whole personality space - every trait, and through Census
and Appearance the occupations and the faces - collapsed to a handful
of profiles. Everybody was roughly the same person, and had been for
the life of the project.

It surfaced as [B48]: forty-nine survivors in a row learning the same
lesson. That batch tested four hypotheses and disproved all four, and
the reason it could not find this one is worth writing down - every
simulation was done in Python, in exact integers, which is precisely
the thing the engine is not doing. A model that is more capable than
the machine will confirm that the code is fine.

WHAT THIS CHECKS
----------------
Any expression mixing a multiplication by a numeric literal with a
modulus by a numeric literal, where **modulus x multiplier > 2^53**.
That is exactly the shape of a wrapping mix step, and the product is
exactly the largest intermediate it can produce.

The bound is the engine's, not a taste: a double holds integers
exactly up to 2^53 and not one past it.

Narrow on purpose. It does not try to bound every expression in the
tree - it catches the idiom that actually broke, in the form it
actually took, and says so with the numbers. A border that tried to
prove general arithmetic safe would be wrong more often than the code.

AND ONE DOOR
------------
The same hash existed in four files. Four copies is four places to fix
and three places to forget, so `SAO_Hash.lua` is now the only one
allowed to hold the constant.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
HASH_HOME = "SAO_Hash.lua"
SAFE = 2 ** 53
FNV_PRIME = "16777619"

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from menu_reach import strip_lua                       # noqa: E402

MUL = re.compile(r"\*\s*(\d{4,})")
MOD = re.compile(r"%\s*(\d{4,})")


def main():
    faults = []
    print("=" * 74)
    print("ARITHMETIC THIS ENGINE CANNOT ACTUALLY DO")
    print("=" * 74)

    srcs = {p: strip_lua(p.read_text(encoding="utf-8", errors="ignore"),
                         strings=False)
            for p in sorted(LUA.rglob("*.lua"))}
    if not srcs:
        print()
        print("VERDICT:")
        print("  FAULT: no Lua was read, so this border checked nothing")
        return 1

    examined, checked, homes = 0, 0, []
    for path, src in srcs.items():
        if FNV_PRIME in src:
            homes.append(path.name)
        for n, line in enumerate(src.split("\n"), 1):
            muls = [int(x) for x in MUL.findall(line)]
            mods = [int(x) for x in MOD.findall(line)]
            if not muls and not mods:
                continue
            # Every line doing arithmetic on a big literal is examined,
            # so a clean verdict names a real number rather than
            # reporting "0 checked" and passing - which is the shape
            # Border 54 exists to catch.
            examined += 1
            if not muls or not mods:
                continue
            checked += 1
            worst = max(muls) * max(mods)
            if worst > SAFE:
                faults.append(
                    f"{path.name}:{n} multiplies by {max(muls)} inside a "
                    f"wrap of {max(mods)}, so the largest intermediate is "
                    f"{worst:.3g} - {worst / SAFE:.1f}x past the {SAFE:.3g} "
                    "a double holds exactly. Every step rounds its low bits "
                    "away, and the result stops being the function that was "
                    "written. Split the multiply so no intermediate leaves "
                    "exact range")

    print(f"  lines doing arithmetic on a large literal: {examined}")
    print(f"  of those, a multiply inside a wrap        : {checked}")
    print(f"  files holding the FNV prime: {len(homes)}  "
          f"({', '.join(sorted(homes)) or 'none'})")

    if not homes:
        faults.append(
            f"nothing in the tree holds {FNV_PRIME}, so either the hash is "
            "gone or this border is reading the wrong files - and a hash "
            "nobody can find is one nobody can check")
    for name in sorted(homes):
        if name != HASH_HOME:
            faults.append(
                f"{name} holds the FNV prime and is not {HASH_HOME}. The "
                "same hash lived in four files before [B48]; four copies "
                "is four places to fix and three places to forget, and "
                "every one of them was computing something the engine "
                "cannot represent")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  60) mantissa: of {examined} lines doing arithmetic on a large "
          f"literal, none can exceed the {SAFE:.3g} a double holds exactly, "
          "and the hash lives in one file")
    return 0


if __name__ == "__main__":
    sys.exit(main())
