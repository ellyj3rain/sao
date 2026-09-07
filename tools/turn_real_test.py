#!/usr/bin/env python3
r"""Border 87 - the turn is real, and identity rides the engine's own copies.

DR-016: SAO owns death of the person completely - the record, the
corpse's identity, and ensuring the turn actually fires under the
game's own rules - and never drives what rises. F-044/F-045 are the
javap ground: in single-player, `die()` for a player-class body is
called from exactly one live site (`PlayerOnGroundState.execute`), so
a shell that dies without reaching that state leaves no corpse, no
armed timer, no turn; and the identity that survives the turn is the
body's modData (copied character -> corpse -> risen body by the
engine itself), not the descriptor, which `reanimate()` builds fresh.

Before [C8] the tree assumed the opposite on both counts: nothing
ensured `die()` ran, recognition and named-corpse reads keyed on
descriptor names that die at reanimation, and the contract row said
"identity survives death and reanimation" - the false comfort the
operator's work order named. That tree IS this border's control.

WHAT THIS HOLDS
---------------
  1. The stamp: the person id is written to the body's modData at both
     materialization sites (shells and adopted neighbours) - the one
     write the engine's two copyTable calls carry through the turn.
  2. The net: the controller schedules every dead shell for the corpse
     net past a named grace, and the bridge verb calls the engine's
     own `die()` - refusing IsoZombie bodies, which are never ours.
  3. Recognition on the id: the scanner's Z row and the named-corpse
     read both read the modData mark first, encode ':' as '~' (Knox
     ids carry the separator), and one Lua resolver decodes both
     forms; the perception parser and every controller consumer go
     through that resolver rather than re-spelling name lookups.
  4. The contract tells the truth: the Addendum D row no longer claims
     descriptor identity survives reanimation.

An optional argv[1] points the checker at another tree root, which is
how the control runs against the pre-[C8] tree.
"""
import pathlib
import sys

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
JAVA = ROOT / "java" / "src" / "com" / "sao"

FILES = {
    "body": LUA / "client" / "SAO_Body.lua",
    "population": LUA / "client" / "SAO_Population.lua",
    "controller": LUA / "client" / "SAO_Controller.lua",
    "perception": LUA / "shared" / "SAO_Perception.lua",
    "identity": LUA / "shared" / "SAO_Identity.lua",
    "bridge": JAVA / "bridge" / "SAOBridge.java",
    "scanner": JAVA / "engine" / "SAOPerceptionScanner.java",
    "needs": JAVA / "engine" / "SAONeeds.java",
    "contract": ROOT / "ENGINE_CONTRACT.md",
}

KEY = "SAOPersonId"


def main():
    faults = []
    src = {}
    for name, path in FILES.items():
        try:
            src[name] = path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            faults.append(f"{path.name} is unreadable - the chain this "
                          "border holds cannot even be inspected")
            src[name] = ""

    # 1. The stamp, at both materialization sites.
    if KEY not in src["body"]:
        faults.append("SAO_Body.lua never stamps the person id on the "
                      "shell's modData - nothing identity-bearing survives "
                      "the turn (F-045)")
    if KEY not in src["population"]:
        faults.append("the adopted neighbours' bodies carry no person id - "
                      "their deaths and turns are anonymous to the county")

    # 2. The net.
    if "pendingCorpses" not in src["controller"] \
            or "CORPSE_GRACE_TICKS" not in src["controller"]:
        faults.append("the controller does not hold dead shells for the "
                      "corpse net - a quiet course death leaves a dead "
                      "character standing, no corpse, no turn (F-044)")
    if "ensureCorpse" not in src["controller"]:
        faults.append("the controller never calls the corpse net's bridge "
                      "verb")
    if "ensureCorpse" not in src["bridge"] \
            or "chr.die()" not in src["bridge"]:
        faults.append("the bridge has no lawful corpse net - die() is the "
                      "engine's only corpse-maker and only corpses arm the "
                      "turn")
    if "NOT_OURS" not in src["bridge"]:
        faults.append("the corpse net does not refuse IsoZombie bodies - "
                      "the risen and the neighbour's people are never ours "
                      "to fold into corpses (DR-016: one brain per body)")

    # 3. Recognition on the id.
    if KEY not in src["scanner"]:
        faults.append("the scanner's Z row still keys recognition on "
                      "descriptors, which reanimate() builds FRESH - the "
                      "turned are unrecognizable (F-045)")
    if "carry their\n        // descriptors through death" in src["scanner"]:
        faults.append("the scanner still CLAIMS descriptors survive death - "
                      "the false comfort the work order named")
    if KEY not in src["needs"]:
        faults.append("findNamedCorpsesNear ignores the corpse's modData "
                      "mark - named-corpse reads stay descriptor-only")
    for j in ("scanner", "needs"):
        if src[j] and "replace(':', '~')" not in src[j]:
            faults.append(f"{FILES[j].name} emits ids with their ':' intact "
                          "- a Knox id (\"ks:<kid>\") breaks the protocol's "
                          "own field separator")
    if "resolveBodyTag" not in src["identity"] \
            or 'gsub("~", ":")' not in src["identity"]:
        faults.append("there is no single decoder for the body tag - or it "
                      "does not undo the '~' encoding, so Knox ids never "
                      "resolve")
    if "resolveBodyTag" not in src["perception"]:
        faults.append("the perception parser does not go through the one "
                      "resolver - the '@id' form falls through idByName "
                      "and resolves to nobody")
    ctl_uses = src["controller"].count("resolveBodyTag")
    if ctl_uses < 3:
        faults.append(f"the controller resolves corpse tags at {ctl_uses} "
                      "of its 3 consumer sites - the rest still treat "
                      "'@id' as a name that matches nobody")

    # 4. The contract tells the truth.
    if "javap - identity survives death and reanimation" in src["contract"]:
        faults.append("ENGINE_CONTRACT.md still claims descriptor identity "
                      "survives reanimation - javap proved the field, not "
                      "the flow (F-045)")

    print("=" * 74)
    print("THE TURN IS REAL, AND IDENTITY RIDES THE ENGINE'S OWN COPIES")
    print("=" * 74)
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  87) the turn: every dead shell reaches die() through the net, the")
    print("      person id rides modData through the engine's own copies, and")
    print("      recognition keys on the id that survives rather than the")
    print("      descriptor that does not")
    return 0


if __name__ == "__main__":
    sys.exit(main())
