#!/usr/bin/env python3
r"""Border 77 - a squared distance compared against a distance.

Comparing `dx*dx + dy*dy` against a radius without squaring it is the
oldest arithmetic mistake in this kind of code, and it is invisible.
`d2 <= 40` is a perfectly ordinary line. It reads as forty tiles. If
`d2` holds a squared distance it means **6.3**, and nothing about the
code, the log or the game will ever say so - a survivor simply is not
noticed until they are much closer than the number in the source says.

This tree already had the invariant, everywhere, unstated. All eleven
`math.sqrt` locals name their result for a plain distance - `d`, `len`,
`dlen`, `hd`, `cdist`, `pdist`, `trip`, `dh`. And **all twelve**
comparisons of a squared distance against a literal use a perfect
square: 400, 16, 196, 25, 1600, 100, 900, 4, 9, 144, 40000.

Two sites inverted the convention, both correct, both traps:

  * `SAO_UI.lua` named a `math.sqrt` result `d2` and compared it
    against `40`. Correct - forty tiles - and identical in shape to the
    mistake. The next person to make it "consistent" with the rest of
    the tree would change 40 to 1600 and move the reach from forty
    tiles to sixteen hundred.
  * `SAO_Harness.lua` named a sum of squares `d` and compared it
    against `bestD`. Also correct - comparing squares finds the nearest
    without a root - and one line comparing that `d` against a plain
    radius would have been silently wrong.

[B52] renamed both.

WHAT IS CHECKED
---------------
  1. a variable assigned `math.sqrt(...)` is not named for a square
  2. every squared distance compared against a numeric literal is
     compared against a perfect square - whether it is a named local
     or an inline `dx*dx + dy*dy`, which is how most of them are
     written

The second is the whole point. The first is narrow and has no
exceptions in this tree, and it is what makes the `SAO_UI` rename a
thing a border can hold rather than a thing somebody remembered.

WHAT IS NOT CHECKED, AND WHY
----------------------------
A third rule - *a sum of squares must be NAMED for one* - lasted one
run. It faulted `d7` in `SAO_Controller`: a sum of squares, compared
against `100`, entirely correct, in a block so deeply nested that
`dx7`, `dy7`, `b7`, `r7` and `bestD7` all carry a `7` to keep them
apart. A numeric suffix is a disambiguator in this tree, not a scale,
and a rule that cannot tell `d7` from `d` is one I invented rather than
one the code follows.

The cost of dropping it is honest and worth stating: the `SAO_Harness`
half of [B52] is **not** protected here. Reverting that rename raises
nothing, because the arithmetic stays correct - `d < bestD` compares
two squares. It was renamed for the next reader, and only the reader
can keep it.
"""
import math
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from lua_read import strip_lua

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"

# A name that claims to hold a squared value. Only the `d2` spelling -
# a bare trailing digit is a disambiguator in this tree, not a scale.
SQUARED_NAME = re.compile(r"[dD]2$")
ROOTED = re.compile(r"^\s*local\s+(\w+)\s*=\s*math\.sqrt\s*\(", re.M)
# `local d2 = dx * dx + dy * dy`, across a line break, as this tree
# writes it under deep indentation.
SUM_OF_SQUARES = re.compile(
    r"\blocal\s+(\w+)\s*=\s*(\w+)\s*\*\s*\2\s*\+\s*(\w+)\s*\*\s*\3\b", re.S)
# The two ways a squared distance meets a literal. Most are INLINE -
# `bdx * bdx + bdy * bdy <= 25.0` - which the first draft could not see
# at all: it matched only named `d2`-style locals, and so examined
# three comparisons out of a dozen.
INLINE_CMP = re.compile(
    r"(\w+)\s*\*\s*\1\s*\+\s*(\w+)\s*\*\s*\2\s*"
    r"(<=|>=|<|>)\s*(\d+(?:\.\d+)?)\b", re.S)

# Literals a squared comparison may use that are not perfect squares,
# with why. A sentinel is not a distance.
NOT_A_RADIUS = {
    "1e9": "a sentinel for 'nothing found yet', not a reach",
}


def is_square(text):
    value = float(text)
    if value < 0:
        return False
    root = math.isqrt(int(value)) if value == int(value) else math.sqrt(value)
    if value == int(value):
        return root * root == int(value)
    return abs(round(math.sqrt(value), 6) ** 2 - value) < 1e-9


def main():
    faults = []
    print("=" * 74)
    print("A SQUARED DISTANCE COMPARED AGAINST A DISTANCE")
    print("=" * 74)

    files = sorted(LUA.rglob("*.lua"))
    if not files:
        print()
        print("VERDICT:")
        print("  FAULT: no Lua was read, so no comparison was examined")
        return 1

    rooted = squared = compared = 0
    for path in files:
        raw = path.read_text(encoding="utf-8", errors="ignore")
        src = strip_lua(raw)
        rel = path.relative_to(ROOT).as_posix()

        for m in ROOTED.finditer(src):
            rooted += 1
            name = m.group(1)
            if SQUARED_NAME.search(name):
                faults.append(
                    f"{rel}:{src.count(chr(10), 0, m.start()) + 1} "
                    f"`{name}` is assigned `math.sqrt(...)` and named for a "
                    "square. Every comparison in this tree reads the name to "
                    "know the scale, and one that lies makes `<= 40` and "
                    "`<= 1600` both look right")

        # Every local that holds a sum of squares, so the comparisons
        # BELOW it can be read at the right scale. The name is not
        # asked to declare anything - the assignment already did.
        holds_square = {m.group(1) for m in SUM_OF_SQUARES.finditer(src)}
        squared += len(holds_square)

        def flag(where, shown, lit):
            root = math.sqrt(float(lit))
            faults.append(
                f"{rel}:{src.count(chr(10), 0, where) + 1} `{shown}` "
                "compares a squared distance against a literal that is not "
                f"a square. It reads as {lit} tiles and means {root:.2f} - "
                "the oldest arithmetic mistake in this kind of code, and "
                "the one nothing in the game will ever say out loud")

        for m in INLINE_CMP.finditer(src):
            compared += 1
            a, b, op, lit = m.groups()
            if lit in NOT_A_RADIUS or is_square(lit):
                continue
            flag(m.start(), f"{a}*{a} + {b}*{b} {op} {lit}", lit)

        if holds_square:
            named = re.compile(
                r"\b(" + "|".join(sorted(map(re.escape, holds_square)))
                + r")\s*(<=|>=|<|>)\s*(\d+(?:\.\d+)?)\b")
            for m in named.finditer(src):
                compared += 1
                name, op, lit = m.groups()
                if lit in NOT_A_RADIUS or is_square(lit):
                    continue
                flag(m.start(), f"{name} {op} {lit}", lit)

    print(f"  math.sqrt results     : {rooted}")
    print(f"  sum-of-squares locals : {squared}")
    print(f"  squared comparisons   : {compared}")

    if rooted == 0 or squared == 0 or compared == 0:
        faults.append(
            "one of the three counts is zero, which cannot be true of a mod "
            "whose whole subject is who can see whom. The reading failed "
            "rather than the code being clean")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  77) squared scale: all {compared} squared comparisons are "
          f"against a perfect square, and none of the {rooted} rooted "
          f"distances is named for one ({squared} squared locals)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
