#!/usr/bin/env python3
r"""Border 45 - the shelves are spent by whoever actually empties them.

[B39] built the scarcity model: a place is spent by being VISITED,
holds as much as its room count says, and refills on the game's own
`LootRespawn`. Its own record admitted the player's looting was not
counted. What the record did not say, and nobody checked, is that
`Pl.take` had **exactly one caller** - inside `dormantLife`.

So the whole economy governed only the unloaded half of the county. A
survivor standing in a grocery could eat it bare while the ledger never
moved, and the two hundred dormant ones would still walk there
expecting food.

That is [B39] on `Desperation`, [B39] on `ErrandRadius` and [B42] on
whose ground it is, a fourth time - and the largest of them, because it
is not one option or one rule but an entire model that half the county
was outside of.

WHAT IS *NOT* AN ASYMMETRY HERE
-------------------------------
The live path does not read `offersNow` or `isSpent`, and that is
correct rather than missing. A loaded survivor finds food through the
bridge scanning the real world - `findFoodSource(body, radius)` - so it
has ground truth and needs no model. The stock ledger is the
abstraction the UNLOADED half needs, and the loaded half's job is to
keep it honest by recording what the world actually lost. Writing is
shared; reading is not, and the split is deliberate.

WHAT THIS HOLDS
---------------
  1. `Pl.take` is called from the dormant path.
  2. `Pl.take` is called from the live path.
  3. Every call sits behind a test that something was actually taken -
     the dormant rule is "recorded only when they actually took
     something, so walking through a warehouse for the shelter does not
     empty it", and a live caller that spends on arrival would empty
     the county by walking through it.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
DORMANT = LUA / "client" / "SAO_Population.lua"
LIVE = LUA / "client" / "SAO_Controller.lua"

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from menu_reach import strip_lua                       # noqa: E402

TAKE = re.compile(r"Places\.take\s*\(")
# What "they actually got something" looks like in either half.
GOT = re.compile(r"\b(got\.\w+|eatCarried|clearWater|offersNow)\b")


def sites(path):
    code = strip_lua(path.read_text(encoding="utf-8", errors="ignore"),
                     strings=False)
    lines = code.split("\n")
    out = []
    for n, line in enumerate(lines, 1):
        if TAKE.search(line):
            # The guard is above it, in the block that decided they got
            # something. The window has to clear a comment block: the
            # live sites carry a dozen lines explaining why they exist,
            # and a twelve-line window read straight past the
            # `eatCarried` guard sitting immediately above them and
            # called a correctly-guarded take unguarded.
            before = "\n".join(lines[max(0, n - 30):n])
            out.append((n, bool(GOT.search(before))))
    return out


def main():
    faults = []
    print("=" * 74)
    print("WHO SPENDS THE SHELVES")
    print("=" * 74)

    halves = {"the dormant day": DORMANT, "the loaded half": LIVE}
    for half, path in halves.items():
        found = sites(path)
        where = ", ".join(str(n) for n, _ in found) or "NOWHERE"
        print(f"  {half:<16} spends at {path.name}:{where}")
        if not found:
            faults.append(
                f"{half} never calls Places.take - "
                + ("a survivor standing in a grocery can eat it bare and "
                   "the county's ledger never moves, while the dormant "
                   "still walk there expecting food"
                   if path is LIVE else
                   "the unloaded half stopped spending the places it "
                   "visits, and [B39]'s whole model is inert"))
        for n, guarded in found:
            if not guarded:
                faults.append(
                    f"{path.name}:{n} spends a place with nothing above it "
                    "testing that anything was taken - walking through a "
                    "warehouse for the shelter would empty it, which is "
                    "the case [B39] wrote its condition to exclude")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  45) scarcity: both halves of the county spend the shelves "
          "they empty, and")
    print("      only when they actually took something")
    return 0


if __name__ == "__main__":
    sys.exit(main())
