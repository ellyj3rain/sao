#!/usr/bin/env python3
r"""Border 121 - a place is judged by how hard it is to get into ([C48]).

The scout weighed rooms, area and water, and could not see a door. So
a glass-fronted shop with eleven ways in beat a house with three
whenever it had one more room, and the outcomes DR-037 describes - a
neighbourhood that becomes gated, choke points read once the ground is
clear - rest on exactly the fact the scout was blind to.

WHAT THIS HOLDS, AND WHY IT IS SHAPED THIS WAY
----------------------------------------------
  1. IT IS A TIE-BREAK, NOT A WEIGHT. Adding a coefficient for ways-in
     would be inventing a rate at which a door is worth part of a
     room, and nothing in the county gives that number. The check
     therefore refuses to find ways-in inside the score expression at
     all: the moment somebody multiplies it by anything, an invented
     rate has entered the county through the back door.
  2. The margin is the score's OWN unit - one room's worth, named -
     so it moves if the scoring ever does and nobody decides
     separately what a door is worth.
  3. The count is the same predicate the boarding uses, so what the
     scout counts and what somebody would later have to shut are the
     same set of things rather than two ideas of a way in.
  4. It reads the loaded cell and loads nothing: the scout is standing
     in the neighbourhood. Loading ground is [C46]'s, under its own
     border, and must not be duplicated here.
  5. An unreadable count never wins a tie-break.
  6. The Lua reads the field the Java sends - one more colon in a
     protocol string is exactly the kind of drift that fails silently.

An optional argv[1] points the checker at another tree root, which is
how its control runs: the pre-batch scout cannot see a door.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
SETTLEMENT = ROOT / "java" / "src" / "com" / "sao" / "engine" / "SAOSettlement.java"
BUILD = ROOT / "java" / "src" / "com" / "sao" / "engine" / "SAOBuild.java"
CONTROLLER = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Controller.lua"
CHECK = ROOT / "tools" / "check.sh"


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""


def strip_block_comments(java):
    out, i, n = [], 0, len(java)
    while i < n:
        if java.startswith("/*", i):
            j = java.find("*/", i)
            i = n if j < 0 else j + 2
        elif java.startswith("//", i):
            j = java.find("\n", i)
            i = n if j < 0 else j
        else:
            out.append(java[i])
            i += 1
    return "".join(out)


def main():
    faults = []
    print("=" * 74)
    print("A PLACE IS JUDGED BY HOW HARD IT IS TO GET INTO")
    print("=" * 74)

    settlement = read(SETTLEMENT)
    if not settlement:
        print("  FAULT: there is no scout to judge anything")
        return 1
    code = strip_block_comments(settlement)

    # 1. The score expression must not contain the count.
    score = re.search(r"double score = (.*?);", code, re.S)
    if not score:
        faults.append("the score expression cannot be read, so this border "
                      "cannot tell whether a door has been given a price")
    else:
        body = score.group(1)
        print("     the score: " + " ".join(body.split()))
        if "ways" in body:
            faults.append(
                "ways-in appears inside the score. That prices a door against "
                "a room, and nothing in the county gives that rate - the "
                "count is a tie-break precisely so nobody has to invent one")

    ways = re.search(r"public static int waysIn\(", code)
    checks = {
        "the count exists": ways is not None,
        "it is the same predicate the boarding uses":
            "BarricadeAble" in code and "BarricadeAble" in read(BUILD),
        "it reads the loaded cell":
            "cell.getGridSquare(" in code,
        "and loads nothing itself":
            "LoadFromDisk" not in code and "new IsoChunk" not in code,
        "an unreadable count is -1":
            "return -1;" in code,
        "and -1 never wins a tie-break":
            "bestWays >= 0 && ways >= 0" in code,

        # 2. The margin is the score's own unit.
        "a room's worth is named once":
            re.search(r"ROOM_WEIGHT = [\d.]+", code) is not None,
        "the score uses that name rather than the number":
            "rooms * ROOM_WEIGHT" in code and "rooms * 8.0" not in code,
        "and the margin is that same name":
            "Math.abs(score - bestScore) <= ROOM_WEIGHT" in code,

        # The tie-break itself.
        "fewer ways in wins a tie":
            "ways < bestWays" in code,
        "and only within the margin":
            re.search(r"Math\.abs\(score - bestScore\) <= ROOM_WEIGHT\s*\n?\s*&& ways < bestWays",
                      code) is not None,

        # 6. The wire.
        "the report carries the count":
            re.search(r'\+ \(bestWays < 0 \? waysIn\(cell, bestDef\) : bestWays\)', code) is not None,
        "and the Lua reads it":
            "brooms, barea, bwater, bscore, bways" in read(CONTROLLER),
        "the gate runs this border":
            "tools/ways_in_test.py" in read(CHECK),
    }

    print()
    for k, v in checks.items():
        print(f"  {'yes' if v else 'NO '}  {k}")
        if not v:
            faults.append(k)

    print()
    print("VERDICT:")
    if faults:
        for f in dict.fromkeys(faults):
            print("  FAULT: " + f)
        return 1
    print("  121) a place is judged by how hard it is to get into: a real "
          "count off the loaded ground, breaking ties within one room's "
          "worth, with no price ever put on a door")
    return 0


if __name__ == "__main__":
    sys.exit(main())
