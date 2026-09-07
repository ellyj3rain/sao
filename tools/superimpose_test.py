#!/usr/bin/env python3
r"""Border 86 - the neighbour's menu stays, and the county is inside it.

DR-015, the operator's correction of [C3]'s reading: using what the
neighbour already puts in the game for UI means SUPERIMPOSE - the neighbour's
per-survivor root is the surface the player already knows, so it is
kept, retitled to the person, and rebuilt from the county: the
county's talk and tell, then his working verbs through his own public
functions. [C3] had read it as removal: strip his root, grow a second
person menu beside where his used to be - two UIs for one load order,
which is the miniature of the exact thing the work order forbade.

WHAT THIS HOLDS
---------------
  1. SAO_Neighbours superimposes rather than strips: it resolves his
     root's submenu (`getSubMenu`), clears it, retitles the root, and
     rebuilds - and it never removes his options (`removeOptionByName`
     is gone from this file).
  2. The prediction is shared: `willSuperimpose` exists and the
     Harness consults it before building its own person menu, so one
     body never carries two person menus.
  3. One definition of the tell surface: `H.addTellOption` exists, the
     Harness's own menu uses it, and the superimposed root uses it -
     "Tell them what I've seen" is spelled exactly once.
  4. The superimposed root drives the same talk surface (`H.talkTo`
     exported and used) and his verbs via `addPersonOptions`.

An optional argv[1] points the checker at another tree root, which is
how the control runs against the [C3]-era strip.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
NBR = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Neighbours.lua"
HAR = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Harness.lua"


def main():
    faults = []
    nbr = NBR.read_text(encoding="utf-8", errors="ignore")
    har = HAR.read_text(encoding="utf-8", errors="ignore")

    if "removeOptionByName" in nbr:
        faults.append("SAO_Neighbours still REMOVES the neighbour's menu "
                      "options - the correction was superimpose, not strip")
    if "getSubMenu" not in nbr or ":clear()" not in nbr:
        faults.append("SAO_Neighbours does not rebuild the neighbour's "
                      "root submenu - nothing is superimposed")
    if "willSuperimpose" not in nbr:
        faults.append("there is no shared prediction of where his root "
                      "attaches - the skip and the rewrite can disagree")
    if not re.search(r'root\.name\s*=', nbr):
        faults.append("the superimposed root keeps the neighbour's verb "
                      "summary as its label - one person, one name applies "
                      "to the label too")
    if "addTellOption" not in nbr or "talkTo" not in nbr:
        faults.append("the superimposed root does not carry the county's "
                      "talk and tell surfaces")

    if "willSuperimpose" not in har:
        faults.append("the Harness builds its own person menu without "
                      "asking whether the neighbour's root carries this "
                      "person - two menus on one body again")
    if "function H.addTellOption" not in har:
        faults.append("the tell surface has no single shared definition")
    if har.count("Tell them what I've seen") != 1:
        faults.append('"Tell them what I\'ve seen" is spelled '
                      f'{har.count("Tell them what I")} times - the shared '
                      "definition has been copied")
    if "H.talkTo = talkTo" not in har and "function H.talkTo" not in har:
        faults.append("the talk surface is not exported - the superimposed "
                      "root cannot drive it")

    print("=" * 74)
    print("THE NEIGHBOUR'S MENU STAYS, AND THE COUNTY IS INSIDE IT")
    print("=" * 74)
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  86) superimposition: his root is kept, retitled to the person, and")
    print("      rebuilt from the county; the prediction is shared; the talk and")
    print("      tell surfaces have one definition each")
    return 0


if __name__ == "__main__":
    sys.exit(main())
