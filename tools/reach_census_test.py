#!/usr/bin/env python3
r"""Border 47 - the reaches still typed bare are counted, and cannot grow.

[B43] measured every radius comparison in the tree: twenty-six, and
exactly one read a declared reach - [B41]'s `MEET_RANGE`. Nothing
recorded that the rest existed, so "we will get to them" and "we forgot"
were the same state. [B43], [B43] and [B45] then named five groups
and brought the count down.

[B47] REBUILT THE READER, and the count with it.

The old census matched two spellings: `x*x + y*y <= N`, and `<= N`
against a variable whose name contained "dist". [B46] found the first
miss - `survivorNear`, the gate under every person verb in the context
menu, compares `d <= 9.0`. Measuring the miss properly turned up five
more shapes it had never seen:

  * an upper bound rather than a lower one - `> 900`, `> 40000`
  * `<` rather than `<=`
  * a parenthesised expression - `(wdx * wdx + wdy * wdy) <= 100.0`
  * a named intermediate - `local d2 = dx * dx + dy * dy`
  * a flat distance through `math.sqrt`, then compared

So the backlog was not slightly understated, it was roughly half the
real one, and five batches reported a number that described what the
regex happened to match. A wrong count is worse than no count, because
it still looks like a measurement.

The reader now lives in `tools/reach_scan.py` and both reach borders
read through it, so 47 and 49 cannot disagree about what the tree
contains.

WHY A CENSUS AND NOT A BAN
--------------------------
Banning bare radii outright would force a name onto every one-off
comparison, and a name invented for a single use is worse than the
number: it reads as a shared rule that nothing shares. [B40]'s finding
cuts both ways - it kept two feud reaches apart BECAUSE they were
different rules.

So this counts instead. The number may fall - that is a batch naming a
group - and it may not rise. The count is per file, because a rise in
one file and a fall in another must not cancel out.
"""
import pathlib
import sys
from collections import Counter

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from menu_reach import strip_lua                       # noqa: E402
from reach_scan import bare_reaches, line_of           # noqa: E402

# The backlog as [B47] left it, measured by the rebuilt reader.
# Falling is progress and must be recorded here; rising is a finding.
CENSUS = {
    "SAO_Controller.lua": 14,
    "SAO_Harness.lua": 2,
    "SAO_Population.lua": 1,
    "SAO_UI.lua": 1,
    "SAO_Perception.lua": 1,
}


def main():
    faults = []
    print("=" * 74)
    print("REACHES STILL TYPED BARE")
    print("=" * 74)

    found = Counter()
    for path in sorted(LUA.rglob("*.lua")):
        src = strip_lua(path.read_text(encoding="utf-8", errors="ignore"),
                        strings=False)
        n = len(bare_reaches(src))
        if n:
            found[path.name] = n

    for name in sorted(set(found) | set(CENSUS)):
        now, was = found.get(name, 0), CENSUS.get(name, 0)
        arrow = "same" if now == was else ("FELL" if now < was else "ROSE")
        print(f"  {name:<24} declared {was:>3}   now {now:>3}   {arrow}")
        if now > was:
            faults.append(
                f"{name} has {now} bare radius comparisons and this border "
                f"declares {was} - a reach was typed rather than named. "
                "Every one of the twenty-six [B43] first counted started "
                "exactly here")
        elif now < was:
            faults.append(
                f"{name} is down to {now} bare from {was} - that is a group "
                "named, and the census has to come down with it or the "
                "backlog stops being a real number. Update CENSUS in this "
                "file and say which rule got its name in the batch record")

    total = sum(found.values())
    print(f"  total bare: {total}  (26 by the old reader at [B43]; the "
          "reader was rebuilt at [B47] and the number is not comparable "
          "across that line)")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  47) reach census: the reaches still typed bare are counted "
          "and have not grown")
    return 0


if __name__ == "__main__":
    sys.exit(main())
