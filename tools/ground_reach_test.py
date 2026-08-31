#!/usr/bin/env python3
r"""Border 35 - whose ground it is, learned by both halves of the county.

[A15], [A15] and [B35] built one rule: being near a held claim teaches
you it is held, and being near a claim that ended un-teaches it. [B35]
wired the PLAYER's own claim into that rule, because the player holds
ground under a `player:` key and has no Identity record, so a guard
written to skip the dead was skipping them.

All of it was written inside `dormantLife`, whose loop opens

    if not rec.dead and not rec.knox and not SAO.Body.get(id) ...

`not SAO.Body.get(id)` - **anyone with a loaded body is excluded**. So
an unloaded survivor drifting past a fence learned whose house it was,
and a survivor standing in the player's kitchen could not. The County
Ledger's "Nobody has come past it yet" was therefore not a report about
the county; it was a report about which half of the county the rule had
been written in. That is [B39]'s finding about `Desperation` and
[B39]'s about `ErrandRadius`, a third time.

THE RULE THIS HOLDS
-------------------
A rule that governs the whole county is written ONCE and read by both
halves. Specifically:

  1. `P.learnGroundNear` exists and carries the whole rule - group
     claims, the un-teaching, personal claims, and the `isPlayerKey`
     branch [B35] added.
  2. The LIVE path reaches it. `P.observe` is where the loaded half
     already throttles its perception, and the player runs through it
     too ([B41]).
  3. The DORMANT path reaches it.
  4. Nobody spells it a second time: no other site pairs a claim
     enumeration with a `learnPlace` write. A second copy is how this
     defect existed at all.
  5. The reach is read from `P.PLACE_SIGHT` rather than spelled bare,
     which is [B40]'s law and the reason the number is declared.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
PERCEPTION = LUA / "shared" / "SAO_Perception.lua"

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from menu_reach import strip_lua                       # noqa: E402
from relay_test import body_of                         # noqa: E402

RULE = "learnGroundNear"
# What the rule has to still contain to BE the rule.
PARTS = {
    "allGroupClaims": "the group claims half",
    "allPersonalClaims": "the personal claims half",
    "isPlayerKey": "[B35]'s branch for the player's own ground",
    "claimOf": "[B35]'s un-teaching when a claim has ended",
    "PLACE_SIGHT": "[B40]'s declared reach",
}
# Where both halves live.
READERS = {
    "the live half": ("shared/SAO_Perception.lua", "observe"),
    "the dormant half": ("client/SAO_Population.lua", None),
}


def main():
    faults = []
    print("=" * 74)
    print("WHOSE GROUND IT IS, IN BOTH HALVES")
    print("=" * 74)

    perception = strip_lua(
        PERCEPTION.read_text(encoding="utf-8", errors="ignore"),
        strings=False)

    # -- 1. The rule is whole ------------------------------------------
    rule = body_of(perception, RULE)
    if rule is None:
        faults.append(f"P.{RULE} is gone - the rule that both halves of "
                      "the county read no longer exists")
        return report(faults)
    missing = [why for token, why in PARTS.items() if token not in rule]
    print(f"  P.{RULE} carries: "
          f"{len(PARTS) - len(missing)}/{len(PARTS)} parts")
    for why in missing:
        faults.append(f"P.{RULE} no longer carries {why} - the halves now "
                      "read a rule that is missing a piece they had")

    # -- 2/3. Both halves reach it -------------------------------------
    for half, (rel, inside) in READERS.items():
        src = strip_lua((LUA / rel).read_text(encoding="utf-8",
                                              errors="ignore"),
                        strings=False)
        if inside:
            scope = body_of(src, inside)
            if scope is None:
                faults.append(f"P.{inside} is gone from {rel} - {half} has "
                              "no perception pass to hang this on")
                continue
            reaches = f"{RULE}(" in scope
        else:
            reaches = f"{RULE}(" in src
        where = f"{rel}" + (f" inside P.{inside}" if inside else "")
        print(f"  {half:<16} {'reads it' if reaches else 'DOES NOT'}"
              f"  ({where})")
        if not reaches:
            faults.append(
                f"{half} does not reach P.{RULE} - "
                + ("a survivor with a loaded body can stand on somebody's "
                   "ground forever and never learn whose it is"
                   if inside else
                   "an unloaded survivor can walk past a claim and never "
                   "learn it is held"))

    # -- 4. Nobody spells it twice -------------------------------------
    # A second copy is an enumeration of claims that writes a place
    # belief itself instead of asking for the rule.
    second = []
    for path in sorted(LUA.rglob("*.lua")):
        src = strip_lua(path.read_text(encoding="utf-8", errors="ignore"),
                        strings=False)
        for m in re.finditer(r"all(?:Group|Personal)Claims\(\)", src):
            window = src[m.end():m.end() + 900]
            if "learnPlace(" in window and RULE not in window:
                line = src[:m.start()].count("\n") + 1
                if path.name == PERCEPTION.name and rule in src[m.start():]:
                    continue
                second.append(f"{path.name}:{line}")
    # The rule's own body is the one legitimate pairing.
    second = [s for s in second if not s.startswith(PERCEPTION.name)]
    print(f"  second spellings: {', '.join(second) or 'none'}")
    for where in second:
        faults.append(
            f"{where} enumerates claims and writes a place belief itself "
            f"instead of reading P.{RULE} - two spellings of the county's "
            "property law, which is exactly how one half came to have it "
            "and the other not")

    # -- 5. The reach is declared --------------------------------------
    bare = re.findall(r"(?:minX|minY)\s*-\s*(\d+)", rule) \
        + re.findall(r"(?:maxX|maxY)\s*\+\s*(\d+)", rule)
    print(f"  bare reach literals in the rule: {len(bare)}")
    if bare:
        faults.append(
            f"P.{RULE} bounds a claim with the literal(s) {sorted(set(bare))} "
            "instead of the declared P.PLACE_SIGHT - [B40] exported that "
            "number precisely so learning and forgetting could not drift")

    return report(faults)


def report(faults):
    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  35) ground: the county's property law is written once and "
          "read by both halves -")
    print("      loaded or not, being there is what teaches you whose "
          "ground you are on")
    return 0


if __name__ == "__main__":
    sys.exit(main())
