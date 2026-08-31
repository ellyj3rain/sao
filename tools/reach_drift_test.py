#!/usr/bin/env python3
r"""Border 55 - two reaches less than a tile apart.

Border 49 catches a bare radius that EQUALS a named reach. [B41]'s
drift does not always land on equality. `SAO_Controller.lua` asked "am
I already at the body, or must I walk there first" at **2.5** tiles in
two places, and asked the identical question as `ARRIVAL_REACH` - **3**
- in five others. Exactly equal never happened, so nothing said
anything for a hundred batches.

Half a tile is not a distinction anyone chose. This world moves in
whole tiles: a body is on a square or it is on the next one, and no
design decision in it has ever turned on the difference between 2.5
and 3. Two reaches that close are one rule written twice by two
people who never compared notes.

WHERE THE LINE SITS, AND WHY THERE
----------------------------------
Under **one tile** of gap, and only for reaches of two tiles or more.

The gap: a full tile IS a real difference - three tiles and four tiles
are different squares and can be different rules, and a border that
complained about them would be noise that teaches people to ignore it.
Anything less than a tile cannot be reached for deliberately.

The floor: below two tiles the numbers stop being about how far
someone will go and start being about arithmetic. `len < 0.1` guards a
division by a zero-length vector before normalising it; the gap
between that and a one-tile step is not drift, it is two different
kinds of question. Above two tiles every value is a claim about the
world.

Both halves of that are a judgement, and both are stated here rather
than tuned until the output looked tidy - a threshold chosen to make a
number small is how [B47] found five batches of census reporting
whatever a regex happened to match.

WHAT IT COMPARES
----------------
Every reach in the tree, named and bare, read through the same
`reach_scan` both other reach borders use. A named reach is included
because the drift that matters most is a bare number sitting half a
tile from a constant that already says what it means.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from menu_reach import strip_lua                       # noqa: E402
from reach_scan import bare_reaches, line_of           # noqa: E402

FLOOR = 2.0      # below this the numbers are arithmetic, not distance
GAP = 1.0        # a whole tile apart may be two rules; less may not

NAME = r"(?:[A-Za-z_][\w.]*\.)?([A-Z][A-Z0-9_]{2,})"
SQ_NAME = re.compile(
    r"(\w+)\s*\*\s*\1\s*\+\s*(\w+)\s*\*\s*\2\s*<=\s*" + NAME)
FLAT_NAME = re.compile(r"\b\w*[Dd]ist\w*\s*<=\s*" + NAME)
DECL = re.compile(
    r"^\s*(?:local\s+)?(?:[A-Za-z_][\w.]*\.)?([A-Z][A-Z0-9_]{2,})"
    r"\s*=\s*([0-9][0-9.]*)\s*(?:--.*)?$", re.M)

# Pairs that really are less than a tile apart on purpose. Keyed by the
# two values, with why the smaller one must not become the larger.
ALLOWED = {}


def main():
    faults = []
    print("=" * 74)
    print("TWO REACHES LESS THAN A TILE APART")
    print("=" * 74)

    srcs = {p: strip_lua(p.read_text(encoding="utf-8", errors="ignore"),
                         strings=False)
            for p in sorted(LUA.rglob("*.lua"))}

    declared, used = {}, set()
    for src in srcs.values():
        for m in DECL.finditer(src):
            declared[m.group(1)] = float(m.group(2))
        for m in SQ_NAME.finditer(src):
            used.add(m.group(3))
        for m in FLAT_NAME.finditer(src):
            used.add(m.group(1))

    where = {}
    for name in sorted(used):
        if name in declared:
            where.setdefault(round(declared[name], 2), []).append(name)
    for path, src in srcs.items():
        for off, tiles, _spell in bare_reaches(src):
            where.setdefault(round(tiles, 2), []).append(
                f"{path.name}:{line_of(src, off)}")

    values = sorted(v for v in where if v >= FLOOR)
    print(f"  distinct reach values at or above {FLOOR:g} tiles: "
          f"{len(values)}")
    if not values:
        faults.append(
            "no reach values were read at all, so this border is comparing "
            "an empty set with itself and its verdict means nothing")

    seen = set()
    for i, a in enumerate(values):
        for b in values[i + 1:]:
            if not 0 < b - a < GAP:
                continue
            key = (a, b)
            seen.add(key)
            if key in ALLOWED:
                continue
            faults.append(
                f"{a:g} tiles and {b:g} tiles are {b - a:g} of a tile apart. "
                f"{a:g} is at {', '.join(where[a][:4])}; {b:g} is at "
                f"{', '.join(where[b][:4])}. Nothing in a world that moves "
                "in whole tiles turns on that difference, so these are one "
                "rule written twice - wire the smaller to whatever names "
                "the larger, or add the pair to ALLOWED with the reason "
                "they must stay apart")

    print(f"  pairs closer than {GAP:g} tile: {len(seen)}   "
          f"argued: {len(ALLOWED)}")

    for key in sorted(ALLOWED):
        if key not in seen:
            faults.append(
                f"ALLOWED argues {key[0]:g} against {key[1]:g} and no such "
                "pair exists any more - the reason has outlived what it was "
                "about")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  55) reach drift: no two of the {len(values)} reaches this "
          f"county uses sit less than a tile apart unargued")
    return 0


if __name__ == "__main__":
    sys.exit(main())
