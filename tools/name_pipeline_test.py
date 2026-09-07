#!/usr/bin/env python3
r"""Border 81 - one person, one name ([C3], DR-014).

The operator's report: a follower shown as one name on the menu
dropped an ID card for somebody else when he died. The walk found the
whole pipeline leaking:

  * `spawnShellNamed` stamped Identity's "Unnamed"/"Survivor"
    placeholders over the engine's generated name, one call before
    `backfillName` existed to read it - every native record was
    "Unnamed Survivor" forever, and the menu fell back to raw ids.
  * The neighbour framework names its people from its own profile
    table and never writes the descriptor; this county adopted the
    DESCRIPTOR name - a random engine string the neighbour never shows
    - so his menu, his ID card, and our record disagreed on one body.
  * The [B45] hold on the neighbour's prompt channels tested the
    global `KS`, and his global is `KnoxSurvivors` (`KS` is a per-file
    local in his tree). The hold had never engaged once.

WHAT THIS HOLDS
---------------
  1. The Java spawn path guards both placeholder stamps: "Unnamed"
     and "Survivor" never overwrite the engine's generated name.
  2. The bare-Lua fallback spawn guards the same two sentinels.
  3. SAO_Neighbours resolves the neighbour's REAL global
     (`KnoxSurvivors`), not only the short alias.
  4. The papers say what the menu says: `refreshIdentityPapers` exists
     in the bridge and Population hands it `Identity.knownName` - the
     same renderer the menu label uses.
  5. Knox adoption prefers the neighbour's profile name and aligns the
     descriptor (`GetActorProfile` before `Identity.ensure`;
     `alignKnoxName` called once a body is in hand).

An optional argv[1] points the checker at another tree root, which is
how the control runs against the pre-fix state.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent

BRIDGE = ROOT / "java" / "src" / "com" / "sao" / "bridge" / "SAOBridge.java"
BODY = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Body.lua"
POP = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Population.lua"
NBR = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Neighbours.lua"


def main():
    faults = []

    bridge = BRIDGE.read_text(encoding="utf-8", errors="ignore")
    if not re.search(r'!\s*"Unnamed"\.equals\(forename\)', bridge):
        faults.append('spawnShellNamed can stamp "Unnamed" over the '
                      "engine's generated name (no sentinel guard in "
                      "SAOBridge.java)")
    if not re.search(r'!\s*"Survivor"\.equals\(surname\)', bridge):
        faults.append('spawnShellNamed can stamp "Survivor" over the '
                      "engine's generated surname (no sentinel guard)")
    if "refreshIdentityPapers" not in bridge:
        faults.append("the bridge has no refreshIdentityPapers - nothing "
                      "makes the corpse papers say the living name")
    if "alignKnoxName" not in bridge:
        faults.append("the bridge has no alignKnoxName - the descriptor "
                      "cannot follow the neighbour's profile name")

    body = BODY.read_text(encoding="utf-8", errors="ignore")
    if 'rec.forename ~= "Unnamed"' not in body:
        faults.append("SAO_Body's bare-Lua fallback stamps the placeholder "
                      "forename onto the descriptor")

    pop = POP.read_text(encoding="utf-8", errors="ignore")
    call = re.search(r"refreshIdentityPapers\(body,\s*(\w+)\)", pop)
    if not call:
        faults.append("Population never refreshes the identity papers at "
                      "materialization")
    else:
        source = re.search(
            r"local\s+" + call.group(1) + r"\s*=\s*SAO\.Identity\.knownName",
            pop)
        if not source:
            faults.append("the papers are not named by Identity.knownName - "
                          "the menu and the card can disagree again")
    adopt = re.search(r"GetActorProfile[\s\S]{0,900}?SAO\.Identity\.ensure",
                      pop)
    if not adopt:
        faults.append("Knox adoption does not read the neighbour's profile "
                      "name before creating the record")
    if "alignKnoxName" not in pop:
        faults.append("Knox adoption never aligns the descriptor to the "
                      "profile name")

    nbr = NBR.read_text(encoding="utf-8", errors="ignore")
    if "KnoxSurvivors" not in nbr:
        faults.append("SAO_Neighbours never names the neighbour's real "
                      "global (KnoxSurvivors) - the [B45] hold class: a "
                      "test against a name that does not exist")

    print("=" * 74)
    print("ONE PERSON, ONE NAME")
    print("=" * 74)
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  81) name pipeline: placeholders never overwrite the engine's name,")
    print("      the papers say what the menu says, the neighbour's people keep")
    print("      the neighbour's name, and the hold tests the real namespace")
    return 0


if __name__ == "__main__":
    sys.exit(main())
