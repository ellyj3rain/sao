#!/usr/bin/env python3
r"""Border 85 - the inspect harness reads everything and teaches nothing.

[C6], the operator's terms: normal launch, not -debug; a bound key or
panel; the selected survivor's seen / heard / told, standing, needs,
last decision, tick cost, population counts; the same lines to the
local JSONL; the panel can see everything; the survivors gain no
knowledge from it.

A panel that can see everything is one function call away from being a
pathway - one `observe` to "refresh" a belief, one `tell` to "sync" a
view, one `adjustTrust` on a click, and the epistemic law is gone
through a debug window. This border holds the window shut.

WHAT THIS HOLDS
---------------
  1. SAO_Inspect.lua exists, binds its key through the options screen
     (`getKey`), and never checks for debug mode - it is a normal-
     launch surface by construction.
  2. It calls NONE of the mutating surfaces: observe, tell,
     reportReturn, adjustTrust, setState, order, orderTravel,
     seatInNearestVehicle, grantXP, markDead. Reading the stores raw
     is its licence; writing anything but the JSONL is not.
  3. The JSONL lines go through SAO.Telemetry.event - the one writer,
     behind the one sandbox dial, required inert.
  4. The tick cost it renders is measured where the tick runs
     (Ctl.lastTickMs in the Controller).

An optional argv[1] points the checker at another tree root, which is
how the control runs against the pre-fix state (where no inspect
surface existed at all - the absence is the original defect).
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
INSPECT = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Inspect.lua"
BINDING = ROOT / "mod" / "42.20" / "media" / "lua" / "shared" / "SAO_Binding.lua"
CTL = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Controller.lua"

FORBIDDEN = (
    "P.observe", "Perception.observe", "Perception.tell",
    "Perception.reportReturn", "adjustTrust", "setState(",
    "Locomotion.order", "orderTravel", "seatInNearestVehicle",
    "grantXP", "markDead",
)


def main():
    faults = []
    if not INSPECT.exists():
        faults.append("there is no inspect surface - the operator plays "
                      "blind or plays -debug")
    else:
        text = INSPECT.read_text(encoding="utf-8", errors="ignore")
        for name in FORBIDDEN:
            if name in text:
                faults.append("the inspect panel reaches a mutating "
                              f"surface ({name}) - a window became a "
                              "pathway")
        if "getKey" not in text:
            faults.append("the inspect panel has no options-screen key "
                          "binding read")
        if re.search(r"isDebugEnabled|getDebug\(", text):
            faults.append("the inspect panel gates on debug mode - the "
                          "operator's term was a NORMAL launch")
        if "SAO.Telemetry.event" not in text:
            faults.append("the panel's lines do not reach the JSONL "
                          "through the one telemetry writer")
    if not BINDING.exists():
        faults.append("no key binding is registered - the bound key "
                      "half of the harness is missing")
    ctl = CTL.read_text(encoding="utf-8", errors="ignore")
    if "lastTickMs" not in ctl:
        faults.append("the Controller does not measure its tick cost - "
                      "the panel would have nothing true to show")

    print("=" * 74)
    print("THE INSPECT HARNESS READS EVERYTHING AND TEACHES NOTHING")
    print("=" * 74)
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  85) inspect inert: the panel exists in a normal launch, binds its")
    print("      key through the options screen, touches no mutating surface,")
    print("      and its lines reach the JSONL through the one telemetry door")
    return 0


if __name__ == "__main__":
    sys.exit(main())
