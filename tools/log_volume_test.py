#!/usr/bin/env python3
r"""Border 56 - one door out to the console, and a lid on it.

Measured from the operator's own session log of 28 August, after the
[B44] fix had made the file readable again:

    Lua log lines total : 2353
    ours                : 898  (38%)

Thirty-eight per cent of everything written by every mod in that game
was this one. The shape was worse than the share - one line per
person, in a county of two hundred and thirty-four:

    234  [SAO][IDENTITY] created sao-N
    234  [SAO][HISTORY]  sao-N contact ...
    129  [SAO][POP]      the world gained a survivor in ...
    120  [SAO][POP]      sao-N and sao-M kept company on the road

Raise the population and it grows with it. There was no ceiling
anywhere in it.

[B44] is two days old and is this cost paid in full: our own flood
pushed the mod-loading phase out of `console.txt`, the operator asked
whether their mods had loaded, and the answer had been in that file
before we wrote over it. Being 38% of somebody's log is not a tidiness
problem. It is the thing that made a diagnosis impossible.

WHAT THIS DOES NOT REQUIRE
--------------------------
Silence. Those lines are how the county is legible from outside, and
[B33]'s finding is that a world running differently with nothing
saying so is the worst state there is. Going quiet trades one
invisible failure for another.

The distinction is between a report and a signal. Two hundred and
thirty-four lines saying a person was created is a report: true, unread,
and it costs the next reader the thing they came for. One line saying
two hundred and thirty-four people were created is a signal - the same
fact, and the log still fits in the file with everyone else's.

WHAT IT REQUIRES
----------------
1. **One door.** No `print(` anywhere in the shipped Lua except inside
   `SAO_Log.lua`. A module that prints directly cannot be throttled by
   anything, ever, and there were fifteen of them before [B47].

2. **Both paths exist.** `SAO.Log.line` for what happened once,
   `SAO.Log.tally` for what happens once per person.

3. **The lid is reachable.** `flush` must be called from the tick
   loop, or a tally that never reaches the burst threshold is a line
   the operator simply never sees - which is [B33] again, in the
   module written to avoid it.

4. **At least one site actually tallies.** A mechanism nothing uses is
   decoration, and this project has spent whole batches removing
   exactly that.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
LOGGER = "SAO_Log.lua"
TICK = "SAO_Controller.lua"

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from menu_reach import strip_lua                       # noqa: E402

PRINT = re.compile(r"(?<![\w.])print\s*\(")
# A CALL through a module's own helper - not the declaration
# (`local function tally(kind)`) and not the one hop inside it
# (`SAO.Log.tally(...)`). Both of those are the door rather than
# somebody walking through it, and counting them made the control
# that removes every real call unable to reach zero.
TALLY = re.compile(r"(?<!function )(?<![\w.])tally\s*\(")


def main():
    faults = []
    print("=" * 74)
    print("ONE DOOR OUT TO THE CONSOLE")
    print("=" * 74)

    srcs = {p: strip_lua(p.read_text(encoding="utf-8", errors="ignore"),
                         strings=False)
            for p in sorted(LUA.rglob("*.lua"))}
    if not srcs:
        print()
        print("VERDICT:")
        print("  FAULT: no Lua was read, so this border would be reporting "
              "on an empty set")
        return 1

    logger = next((s for p, s in srcs.items() if p.name == LOGGER), None)
    if logger is None:
        faults.append(
            f"{LOGGER} is gone. Every module printed straight to the console "
            "before [B47] and nothing could put a ceiling on any of it")
        logger = ""

    doors = {p.name: len(PRINT.findall(s)) for p, s in srcs.items()
             if PRINT.search(s) and p.name != LOGGER}
    tallies = sum(len(TALLY.findall(s)) for p, s in srcs.items()
                  if p.name != LOGGER)
    inside = len(PRINT.findall(logger))

    print(f"  print() inside {LOGGER}: {inside}")
    print(f"  print() anywhere else  : {sum(doors.values())}  "
          f"{', '.join(f'{k}({v})' for k, v in sorted(doors.items())) or 'none'}")
    print(f"  sites that tally       : {tallies}")

    for name, n in sorted(doors.items()):
        faults.append(
            f"{name} calls print() {n} time(s) directly. A module that "
            "writes to the console itself cannot be throttled by anything, "
            "and fifteen of them together were 38% of the operator's whole "
            f"session log. Route it through SAO.Log")

    if inside == 0 and logger:
        faults.append(
            f"{LOGGER} does not print at all, so the one door out is shut "
            "and the county has gone silent - which [B33] names as the "
            "worst state, not the best")

    for fn in ("function L.line(", "function L.tally(", "function L.flush("):
        if logger and fn not in logger:
            faults.append(
                f"{LOGGER} no longer defines `{fn[9:-1]}`. Without both a "
                "line path and a tally path there is nothing to choose "
                "between, and a per-person line goes back to being printed "
                "per person")

    tick = next((s for p, s in srcs.items() if p.name == TICK), "")
    if "SAO.Log.flush()" not in tick:
        faults.append(
            f"nothing in {TICK} calls SAO.Log.flush(), so a tally that never "
            "reaches the burst threshold is never printed at all. A count "
            "held forever is worse than a line - it is a fact the operator "
            "is never told, which is the shape [B33] exists for")

    if tallies == 0:
        faults.append(
            "not one site tallies, so the aggregation is decoration. The "
            "four that mattered were 717 of the 898 lines this mod wrote in "
            "one session")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  56) log volume: every one of the {len(srcs)} shipped Lua files "
          f"speaks through one door, {tallies} site(s) count rather than "
          "print, and the tick empties them")
    return 0


if __name__ == "__main__":
    sys.exit(main())
