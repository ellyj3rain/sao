#!/usr/bin/env python3
r"""Border 95 - the dead census exists, splits identity from crowd, and
teaches nothing.

DR-021's mechanism B: before any zombie-population number is
recommended, the install's actual crowd is MEASURED. The bridge reads
raw numbers - the fungible crowd vs the identity-bearing bodies (the
[C9] predicate is the splitter, so a living neighbour is never
counted as crowd), the loaded area's tile extent, the map's extent -
and the readers derive density and projection with the assumption
stated beside the figure. The [C6] instrument discipline holds: the
census reads everything and changes nothing.

WHAT THIS HOLDS
---------------
  1. The bridge verb exists and reads all four raw numbers through
     the javap-verified surfaces (identityBearing, the chunk map's
     public tile bounds, the meta grid times the cell size).
  2. The verb is INERT: no setter, no removal, no spawn appears in
     its body - a census that nudged what it counts would poison its
     own next line.
  3. The telemetry daily line carries the census with its derivation
     fields, and the projection's sampling assumption is stated where
     the number is made.
  4. The inspect panel shows the live split in plain copy.

An optional argv[1] points the checker at another tree root, which is
how the control runs against the pre-[C16] tree.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
BRIDGE = ROOT / "java" / "src" / "com" / "sao" / "bridge" / "SAOBridge.java"
TEL = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Telemetry.lua"
INS = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Inspect.lua"


def main():
    faults = []
    print("=" * 74)
    print("THE DEAD CENSUS COUNTS AND TEACHES NOTHING")
    print("=" * 74)

    try:
        bridge = BRIDGE.read_text(encoding="utf-8", errors="ignore")
        tel = TEL.read_text(encoding="utf-8", errors="ignore")
        ins = INS.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        print()
        print("VERDICT:")
        print("  FAULT: a census source is unreadable - nothing counted")
        return 1

    verb = re.search(r"public String deadCensus.*?\n    \}", bridge, re.S)
    if not verb:
        faults.append("the bridge has no deadCensus - DR-021's mechanism "
                      "has no instrument and the numbers stay guesses")
    else:
        body = verb.group(0)
        for needle, what in (
                ("identityBearing", "the crowd/identity split - a living "
                                    "neighbour counted as crowd"),
                ("getWorldXMaxTiles", "the loaded area's extent"),
                ("getMetaGrid", "the map's extent"),
                ("getCellSizeInSquares", "the cell-to-tile conversion")):
            if needle not in body:
                faults.append(f"deadCensus does not read {needle} - "
                              f"{what} is missing or invented")
        # 2. Inert: nothing in the body mutates the world.
        for banned in ("removeFromWorld", "spawn", "createRealZombie",
                       "createHorde", "Kill(", ".set"):
            if banned in body:
                faults.append(f"deadCensus touches the world ({banned}) - "
                              "a census that nudges what it counts poisons "
                              "its own next line")

    if '"deadcensus"' not in tel or "loadedDensityPerK" not in tel \
            or "mapProjection" not in tel:
        faults.append("the telemetry line does not carry the census with "
                      "its derived fields - the measurement never reaches "
                      "the record ratification reads")
    if "oversamples" not in tel:
        faults.append("the projection's sampling assumption is not stated "
                      "where the number is made - a figure without its "
                      "caveat reads as truth")
    if "deadCensus" not in ins:
        faults.append("the inspect panel does not show the live split - "
                      "the one normal-launch surface is blind to the count")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  95) dead census: raw numbers through verified surfaces, the")
    print("      identity split honored, the instrument inert, the derivation")
    print("      and its assumption written where the figure is made")
    return 0


if __name__ == "__main__":
    sys.exit(main())
