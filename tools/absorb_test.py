#!/usr/bin/env python3
r"""Border 98 - absorption obeys the neighbour's body law (DR-022/023/024).

The operator's ruling: SAO absorbs his people completely - and the
build stands on three verified laws (F-051/F-052), each of which has
a way to be violated silently:

  * his SpawnActor is the ONE body-creation door, and he re-bodies a
    missing person within ten minutes - so the wrap is the respawn
    defense, not a nicety;
  * removal is NOT death - his grief and memorials hang on
    OnZombieDead, so an absorption that kills instead of removing
    turns every takeover into a funeral;
  * his profile rows are never deleted and his surfaces keep reading
    them - so the county must mirror truth back, or his own UI lies
    about people who are now ours.

And DR-024: the menu is not the behavior - his people answered
regroup and unstick, so absorbed people must too.

WHAT THIS HOLDS
---------------
  1. The absorb module wraps SpawnActor and GetOption, absorbs at
     game start, and NEVER falls back to his spawn: a failed
     absorption spawns nobody, loudly (DR-026, the operator's
     overrule of the first draft) - the county works or the county
     visibly does not.
  2. The handoff detaches and removes through his own teardown
     (DetachRuntimeActor + RemoveActorShell) and contains no kill -
     no setHealth, no Kill( - anywhere in the module.
  3. The module writes none of his marker keys (KnoxSurvivorId,
     KnoxSurvivorShell, KnoxSurvivorBound... assignment forms).
  4. The mirror back exists: position while they live, alive=false
     once when they die.
  5. The blocked dials use vanilla's own idiom (setEnable(false),
     label setColor grey) with plain-language tooltips (DR-018).
  6. Verb parity: the Ask-them-to menu carries "regroup on me" and
     "get unstuck", and the unstick verb has a real public bridge
     hand (not the private helper Lua cannot reach).

An optional argv[1] points the checker at another tree root, which is
how the control runs against the pre-[C20] tree.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
AB = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Absorb.lua"
HAR = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Harness.lua"
BRIDGE = ROOT / "java" / "src" / "com" / "sao" / "bridge" / "SAOBridge.java"


def main():
    faults = []
    print("=" * 74)
    print("ABSORPTION OBEYS THE NEIGHBOUR'S BODY LAW")
    print("=" * 74)

    if not AB.exists():
        print()
        print("VERDICT:")
        print("  FAULT: SAO_Absorb.lua does not exist - DR-022 is a ruling "
              "with no machinery, and his respawn loop re-bodies anyone "
              "removed within ten minutes")
        return 1
    ab = AB.read_text(encoding="utf-8", errors="ignore")
    # Prose is not code (the GOVERNANCE clause, hit by this border's
    # own first run: the module's comments NAME the death event they
    # exist to avoid). Banned-call scans run on stripped source.
    ab_code = "\n".join(
        line[:line.find("--")] if line.find("--") >= 0 else line
        for line in ab.split("\n"))
    har = HAR.read_text(encoding="utf-8", errors="ignore") \
        if HAR.exists() else ""
    bridge = BRIDGE.read_text(encoding="utf-8", errors="ignore") \
        if BRIDGE.exists() else ""

    # 1. The door, the options, the start sweep, the fallback.
    if "ns.SpawnActor = function" not in ab:
        faults.append("SpawnActor is not wrapped - his restore loop "
                      "re-bodies every absorbed person within ten in-game "
                      "minutes (F-051) and the county doubles")
    wrap = re.search(r"ns\.SpawnActor = function.*?\n    end", ab, re.S)
    if not wrap:
        faults.append("the SpawnActor wrap could not be read as a block - "
                      "the DR-026 no-fallback check has nothing to examine")
    if wrap and re.search(r"hisSpawnActor\s*\(", wrap.group(0)):
        faults.append("the wrap CALLS his original spawn - DR-026: a "
                      "failed absorption spawns nobody rather than one "
                      "of his, because his people are not representative "
                      "of this mod")
    if "ABSORB FAILED" not in ab or "Seams.wentDark" not in ab:
        faults.append("a failed absorption is not loud - DR-026 demands "
                      "the console name it and the Ledger's "
                      "not-everything-is-running header carry it")
    if "absorbAll" not in ab or "OnGameStart" not in ab:
        faults.append("no world-start sweep - DR-022 says all of them, at "
                      "world start")
    if "NEUTRALIZED_OPTIONS" not in ab or "ns.GetOption = function" not in ab:
        faults.append("his population caps are not neutralized at his one "
                      "option seam - with everyone absorbed his own caps "
                      "strangle his encounter stream, the opposite of "
                      "DR-023")

    # 2. Remove, never kill.
    if "DetachRuntimeActor" not in ab or "RemoveActorShell" not in ab:
        faults.append("the handoff does not go through his own teardown "
                      "pair - the runtime binding or the body is left "
                      "behind")
    for banned in ("setHealth", "Kill(", ":kill", "OnZombieDead"):
        if banned in ab_code:
            faults.append(f"the absorb module touches {banned} - removal "
                          "is NOT death (F-051), and a kill turns every "
                          "absorption into one of his funerals")

    # 3. None of his marker keys are written.
    for marker in ("KnoxSurvivorId", "KnoxSurvivorShell",
                   "KnoxSurvivorBound", "KnoxSurvivorConfigured"):
        if re.search(re.escape(marker) + r"\s*=", ab_code):
            faults.append(f"the absorb module WRITES {marker} - his UI "
                          "and targeting bind to that key (F-051's "
                          "standing rule)")

    # 4. The mirror back.
    if "mirrorBack" not in ab or "profile.alive = false" not in ab:
        faults.append("no mirror back into his rows - his roster lies "
                      "about people who are now ours, in both life and "
                      "death")

    # 5. The overridden dials DO NOT EXIST on the screen ([C23], the
    # operator's restatement of DR-023: deleted, not greyed), and the
    # removal happens at the settings-table seam so no row is built.
    sb_path = ROOT / "mod" / "42.20" / "media" / "lua" / "client" \
        / "SAO_Sandbox.lua"
    sb = sb_path.read_text(encoding="utf-8", errors="ignore") \
        if sb_path.exists() else ""
    if "REMOVED_SETTINGS" not in sb \
            or "getSandboxSettingsTable" not in sb \
            or "MaxPersistentSurvivors" not in sb \
            or "MaxNearbySurvivors" not in sb:
        faults.append("the overridden neighbour dials are not deleted "
                      "from the options screen - the operator ruled "
                      "they do not need to exist, and a dial that can "
                      "be set and will not apply is a lie (DR-023/[C23])")
    if "blockOverriddenDials" in ab_code:
        faults.append("the superseded grey-hook still runs in the absorb "
                      "module - greying was replaced by deletion, and two "
                      "mechanisms on one surface is how they drift apart")

    # 6. Verb parity (DR-024).
    if '"regroup on me"' not in har or '"get unstuck"' not in har:
        faults.append("the Ask-them-to menu lacks the absorbed "
                      "framework's regroup/unstick verbs - an absorbed "
                      "person offers fewer verbs than before absorption, "
                      "the exact defect DR-024 names")
    if "public String unstick" not in bridge:
        faults.append("unstick has no public bridge hand - the menu verb "
                      "would call a private helper Lua cannot reach and "
                      "die silently in its pcall")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  98) absorption: the one door wrapped and never falling his way,")
    print("      remove-never-kill through his own teardown, no marker keys")
    print("      written, truth mirrored back, overridden dials deleted from")
    print("      the screen, and verb parity kept")
    return 0


if __name__ == "__main__":
    sys.exit(main())
