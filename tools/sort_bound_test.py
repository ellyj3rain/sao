#!/usr/bin/env python3
r"""Border 67 - every sort is handed a list somebody has bounded.

[B50] found `Census.catalog()` blowing the stack in `table.sort` and
guarded it by size. This is the reason that guard is a heuristic and
not a proof.

The engine ships its own `stdlib.lua`, and `table.sort` is a quicksort
written in Lua:

    local function quicksort_comp(tbl, left, right, comp)
        if right > left then
            local pivot = left          -- always the leftmost element
            local newpivot = partition_comp(tbl, left, right, pivot, comp)
            quicksort_comp(tbl, left, newpivot - 1, comp)
            return quicksort_comp(tbl, newpivot + 1, right, comp)
        end

**The pivot is always the first element.** Recursion depth is therefore
a property of the input's ORDER, not of its length, and Kahlua's frame
ceiling is what runs out. Measured in the engine:

    sorted integers, n=1500          ok
    scattered integers, n=4000       ok
    `modx:FabricatedN` keys, n=1200  ok
    `modx:FabricatedN` keys, n=1500  THROWS
    `modx:FabricatedN` keys, n=2000  ok

A 1500-element list fails while a 4000-element one succeeds. No size
threshold is safe on its own, and no test on made-up data proves
anything about real data.

WHAT CAN BE DONE INSTEAD
------------------------
Depth cannot be bounded from here, so the input is. Every `table.sort`
in the tree is declared with **what limits the list it receives**, and
a bound in the low hundreds is safe by a margin wide enough that the
shape does not matter.

That is the honest shape of this: not "this is provably fine", but
"this is small for a stated reason, and the reason is checkable by a
person".

The largest anything here can be is the county itself - a single
company holding everybody, which the sandbox caps at 500 - against an
earliest observed failure at 1500 on adversarial data.

An undeclared sort is a fault, and a declaration whose sort has gone is
a fault, so the list describes what the tree does rather than what it
used to.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from menu_reach import strip_lua                       # noqa: E402

SORT = re.compile(r"table\.sort\s*\(\s*([A-Za-z_]\w*)")

# (file, the list being sorted) -> what bounds its length.
BOUNDED = {
    ("SAO_Controller.lua", "eligible"):
        "the watch pool of one company - members present and awake, so "
        "at most the company, and a company is at most the county",
    ("SAO_Controller.lua", "willing"):
        "those who heard a call and want to come; bounded by the "
        "company, and thinned again by who is in earshot",
    ("SAO_Harness.lua", "recentDead"):
        "the county's dead, read for one debug line and printed five at "
        "a time",
    ("SAO_Needs.lua", "out"):
        "the food in one person's inventory - a survivor carries what a "
        "survivor can carry",
    ("SAO_Telemetry.lua", "keys"):
        "the field names of one JSON record, which the writer authors "
        "itself",
    ("SAO_UI.lua", "recentDead"):
        "the county's dead, rendered as a Lost section that prints a "
        "handful",
    ("SAO_UI.lua", "near"):
        "people inside the Ledger's own forty-tile reach, so bounded by "
        "who can physically be standing there",
    ("SAO_UI.lua", "chron"):
        "the chronicle the county keeps, which is trimmed where it is "
        "written rather than where it is read",
    ("SAO_Census.lua", "classified"):
        "professions the engine registered; the one list here that a "
        "mod list can grow without limit, which is why [B50] put a "
        "SORT_CEILING in front of it",
    ("SAO_Lessons.lua", "parts"):
        "the lessons one person holds, out of a registry of twelve",
    ("SAO_Seams.lua", "out"):
        "the subsystems that have gone dark - five bulkheads exist",
    ("SAO_Standing.lua", "members"):
        "the members of one company. The largest list this mod sorts, "
        "and still the county itself: the sandbox caps population at "
        "500 against an earliest observed sort failure at 1500 on "
        "adversarial data",
    ("SAO_World.lua", "ranked"):
        "the item categories a world survey found, which is the game's "
        "own category list rather than the number of items",
}


def main():
    faults = []
    print("=" * 74)
    print("EVERY SORT IS HANDED A LIST SOMEBODY HAS BOUNDED")
    print("=" * 74)

    found = {}
    for path in sorted(LUA.rglob("*.lua")):
        src = strip_lua(path.read_text(encoding="utf-8", errors="ignore"),
                        strings=False)
        for m in SORT.finditer(src):
            line = src.count("\n", 0, m.start()) + 1
            found.setdefault((path.name, m.group(1)), []).append(line)

    sites = sum(len(v) for v in found.values())
    print(f"  table.sort call sites : {sites}")
    print(f"  distinct lists sorted : {len(found)}")
    print(f"  declared with a bound : {len(BOUNDED)}")

    if sites == 0:
        faults.append(
            "not one table.sort was found, which cannot be true of this "
            "tree - the reading failed rather than the code being clean")

    for key in sorted(found):
        if key not in BOUNDED:
            where = ", ".join(str(n) for n in found[key])
            faults.append(
                f"{key[0]} sorts `{key[1]}` at line {where} and nothing "
                "says what bounds it. This engine's table.sort always "
                "picks the leftmost pivot, so its recursion depth follows "
                "the input's ORDER - a 1500-element list has been seen to "
                "throw while a 4000-element one sorted fine. Depth cannot "
                "be bounded from here, so the list must be, and the reason "
                "written down")

    for key in sorted(BOUNDED):
        if key not in found:
            faults.append(
                f"{key[0]} is declared as sorting `{key[1]}` and no such "
                "sort exists any more - the entry describes no code")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  67) sort bounds: all {sites} sort sites across {len(found)} "
          "lists are bounded by something written down")
    return 0


if __name__ == "__main__":
    sys.exit(main())
