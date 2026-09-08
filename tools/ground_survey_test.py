#!/usr/bin/env python3
r"""Border 119 - the ground is looked at, and not written to ([C46]).

The operator ruled the years between run for real: the ground is
loaded and the work happens, rather than the pass recording an outcome
and dressing the world to match on arrival. The engine holds only an
8 x 8 chunk window around each player, so a distant claim is not in any
cell - a chunk has to be loaded on its own, which is what this does.

THE ONE THING THIS BORDER IS FOR. `IsoChunk.Save` writes into the
player's own save directory through shared static buffers, and no part
of this mod has a live receipt. The survey path must therefore write
NOTHING: no chunk saved, no barricade added, no object placed. If a
later batch reaches for those from inside this path, it will be doing
it to a real person's save, and this is what would catch it.

WHAT ELSE IT HOLDS
------------------
  1. A chunk the live world already holds is never loaded again - it
     is read where it sits, through the cell.
  2. There is a cap on chunks per survey, so one claim cannot stall a
     pass.
  3. Every engine call in the path is inside a catch: this runs at
     world creation while the streamer is busy.
  4. The years actually call it, and what it learns lands on the
     record of the person who holds the claim.

An optional argv[1] points the checker at another tree root, which is
how its control runs: the pre-batch tree never looks at the ground.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
GROUND = ROOT / "java" / "src" / "com" / "sao" / "engine" / "SAOGround.java"
BRIDGE = ROOT / "java" / "src" / "com" / "sao" / "bridge" / "SAOBridge.java"
POP = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Population.lua"
INSPECT = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Inspect.lua"
CHECK = ROOT / "tools" / "check.sh"

# Anything that would change the world or the save from inside a look.
WRITES = (
    ".Save(", "SafeWrite(", "flagForHotSave(", "AddBarricadeToObject(",
    "addPlank(", "addMetal(", "AddTileObject(", "setGridSquare(",
    "DeleteTileObject(", "transmitAdd", "requiresHotSave = true",
)


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""


def strip_comments(java):
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
    print("THE GROUND IS LOOKED AT, AND NOT WRITTEN TO")
    print("=" * 74)

    if not GROUND.exists():
        print("  FAULT: nothing looks at the ground, so the years run over a "
              "county that knows nothing about the places it holds")
        return 1
    ground = strip_comments(read(GROUND))
    pop = read(POP)

    # 1. The whole point.
    found = [w for w in WRITES if w in ground]
    print("     writes in the survey path: " + (", ".join(found) or "none"))
    for w in found:
        faults.append(
            "the survey path reaches for '%s'. It writes into a real save "
            "through shared static buffers and nothing here has a live "
            "receipt; looking at the ground and changing it are different "
            "batches on purpose" % w)

    checks = {
        "it loads a chunk on its own":
            "new IsoChunk(cell)" in ground and "LoadFromDisk()" in ground,
        "it reads squares off that chunk, not off the cell":
            "chunk.getGridSquare(" in ground,
        "a live chunk is read where it sits instead":
            "isInChunkMap(" in ground and "cell.getGridSquare(" in ground,
        "the chunk side is the engine's own figure":
            "CHUNK_SIDE = 8" in ground,
        "there is a cap on chunks per survey":
            re.search(r"CHUNK_BUDGET = \d+", ground) is not None
            and "touched >= CHUNK_BUDGET" in ground,
        "every engine call is inside a catch":
            ground.count("catch (Throwable") >= 6,
        "the bridge exposes it and decides nothing":
            "public String surveyClaim(" in read(BRIDGE),

        # 4. The years use it, and it lands somewhere.
        "a simulated day looks at some ground":
            "pcall(lookAtSomeGround, day)" in pop,
        "one claim a day, on a rotation":
            "(day % #holders) + 1" in pop,
        "and what it learns lands on the holder's record":
            "rec.waysIntoHome = ways" in pop and "rec.boardedAtHome" in pop,
        "the panel says what their place is":
            "their place: " in read(INSPECT),
        "the gate runs this border":
            "tools/ground_survey_test.py" in read(CHECK),
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
    print("  119) the ground is looked at and not written to: a claim's "
          "chunks loaded off disk, read and let go, with the live world's "
          "own never touched")
    return 0


if __name__ == "__main__":
    sys.exit(main())
