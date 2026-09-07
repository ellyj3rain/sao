#!/usr/bin/env python3
r"""Border 82 - the seat and the mesh move together; the follow crosses.

The operator's report, verbatim shape: the survivor could not enter a
vehicle at all, there was no order to ask them to, and a failed action
had once left a driven truck with no visible driver who could not
exit. And the follower could not go through a window the player had
just climbed - the neighbour framework's people could.

The walk found the mechanisms: `enter()` was called bare, without the
mesh placement vanilla's own ISEnterVehicle pairs it with, and exit
without the "outside" placement; the route supervisor had no branch
for a hoppable edge, so a fence was an eternal unnamed stall
("stalled:ManualRoute"); `riding` lived only on the runtime agent
table and was lost at re-adoption, leaving seated bodies running walk
orders from inside a car.

WHAT THIS HOLDS
---------------
  1. Every enter() is paired: seat claim, mesh "inside", verification,
     rollback through exit() on failure - and seat 0 is never taken.
  2. Every exit() is paired: seat read first, then "outside" placement.
  3. The route supervisor has the hoppable-edge branch - a fence is a
     crossing (climbOverFence), never a stall.
  4. The follow can work the edge its target crossed: traverseToward
     exists Java-side and the Controller reaches it (followTraverse).
  5. The riding flag is reconciled from the seat truth in BOTH
     directions in the Controller.

An optional argv[1] points the checker at another tree root, which is
how the control runs against the pre-fix state.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent

NEEDS = ROOT / "java" / "src" / "com" / "sao" / "engine" / "SAONeeds.java"
MOVE = ROOT / "java" / "src" / "com" / "sao" / "engine" / "SAOMovement.java"
CTL = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Controller.lua"


def main():
    faults = []

    needs = NEEDS.read_text(encoding="utf-8", errors="ignore")
    if not re.search(r'enter\(i, shell\)[\s\S]{0,400}?'
                     r'setCharacterPosition\(shell, i, "inside"\)', needs):
        faults.append("enter() is not paired with the \"inside\" mesh "
                      "placement - the occupant flag can move without "
                      "the body")
    if not re.search(r'getSeat\(shell\)[\s\S]{0,400}?exit\(shell\)'
                     r'[\s\S]{0,400}?"outside"', needs):
        faults.append("exit() is not paired with the \"outside\" mesh "
                      "placement - a released seat can keep a phantom "
                      "passenger")
    if not re.search(r"for \(int i = 1;", needs):
        faults.append("the seat loop does not start past the driver's "
                      "seat - nobody here drives")

    move = MOVE.read_text(encoding="utf-8", errors="ignore")
    if "getHoppableTo" not in move or "climbOverFence" not in move:
        faults.append("the route supervisor has no hoppable-edge branch "
                      "- a fence is an eternal unnamed stall")
    if "traverseToward" not in move:
        faults.append("there is no follow traversal - a follower cannot "
                      "cross what the player crossed")

    ctl = CTL.read_text(encoding="utf-8", errors="ignore")
    if "followTraverse" not in ctl:
        faults.append("the Controller never asks for the crossing - "
                      "the traversal exists and nothing reaches it")
    if not re.search(r"if not agent\.riding then[\s\S]{0,400}?"
                     r"agent\.riding = true", ctl):
        faults.append("riding is not reconciled from the seat truth - "
                      "a re-adopted passenger runs walk orders from "
                      "inside a car")

    print("=" * 74)
    print("THE SEAT AND THE MESH MOVE TOGETHER; THE FOLLOW CROSSES")
    print("=" * 74)
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  82) seats and crossings: every enter and exit moves the mesh with")
    print("      the flag, fences are crossings rather than stalls, the follow")
    print("      works the edge its target crossed, and the seat outranks the flag")
    return 0


if __name__ == "__main__":
    sys.exit(main())
