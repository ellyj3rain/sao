#!/usr/bin/env python3
r"""Border 34 - what an offer to speak opens on is what speaking can carry.

[B41] made the player's eyes work. This is the other half of the same
defect, one layer up.

`SAO_Harness.lua` offers "Tell them what I've seen" behind a gate that
iterated the player's `zombies` and `places`. `P.tell` writes
`to.factions` and `to.places` and NOTHING ELSE - the dead travel only
through `P.reportReturn`, which is firsthand-only and bounded on a
ground. So the gate was wrong in both directions at once:

  * it opened on `zombies`, which `tell` cannot carry, so a player who
    had walked past forty of them was offered the option and told
    "Nothing I didn't know" every single time;
  * it never counted `factions`, which `tell` CAN carry, so a player
    who knew where a house was and nothing else was never offered it.

Neither was visible before [B41], because the player's belief store
was empty and the option never appeared at all.

THE RULE, NOT THE INSTANCE
--------------------------
An offer to pass knowledge on must open on exactly the set of
categories the transfer functions actually write. Not a subset - that
hides knowledge the county could have had. Not a superset - that offers
a conversation that cannot do anything. Both sets are READ out of the
shipped Lua here rather than listed: the gate's categories come from
`P.hasAnythingToPass`, and the carriable ones from every `to.<name>[`
assignment inside `P.tell` and `P.reportReturn`. Add a category to
either side and this border requires the other side to move.

It also holds three things that follow from that:

  * The harness reads the predicate rather than re-deriving it. A gate
    spelled in the UI and a transfer spelled in Perception is [B40]'s
    two-spellings defect with a menu in front of it.
  * The option reaches BOTH transfer paths. `tell` alone cannot carry
    what the player saw, which is the thing the option is named for.
  * The listener's skepticism has ONE spelling. `P.tell` and
    `P.reportReturn` both read `P.willBelieve`, and the trust threshold
    appears exactly once in the file.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
PERCEPTION = LUA / "shared" / "SAO_Perception.lua"
HARNESS = LUA / "client" / "SAO_Harness.lua"

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from menu_reach import strip_lua                       # noqa: E402

# What a face-to-face conversation is made of. ONE function: `tell` is
# the channel a survivor uses on another survivor, and [B27]'s whole
# point is that the player uses the same one. `reportReturn` is the
# errand-report road ([B19]) - firsthand, bounded on the ground a goer
# was sent to - and the menu does not and should not reach it.
CARRIERS = ("tell",)
# Every road knowledge crosses between two people, though, has to apply
# the listener's refusal identically.
SPEAKERS = ("tell", "reportReturn")
# The one place the listener's refusal is allowed to be written.
SKEPTIC = "willBelieve"
THRESHOLD = "-0.2"


KEYWORD = re.compile(r"\b(function|if|for|while|repeat|do|end|until)\b")


def body_of(src, name):
    """`function P.name(...)` up to the `end` that actually closes it.

    Block depth, not the first column-0 `end`. The naive version was
    wrong here and wrong in a way that hid itself: SAO_Perception.lua
    defines `P.reportReturn`, `P.cryForHelp` and `P.announceDeparture`
    INSIDE `P.tell`'s body, so the first column-0 `end` after
    `function P.tell` belongs to reportReturn. That cut tell's body off
    at a third of its length - and the truncated slice still contained
    a `to.zombies[` write, reportReturn's, so the border reported the
    right categories for the wrong function and looked correct.

    `do` is the trap: `for ... do` and `while ... do` reuse the keyword
    that also opens a bare block, so a `do` is only an opener when no
    `for`/`while` is waiting to claim it.
    """
    start = re.search(r"^function P\.%s\(" % re.escape(name), src, re.M)
    if not start:
        return None
    depth, pending_do = 1, 0
    for tok in KEYWORD.finditer(src, start.end()):
        word = tok.group(1)
        if word in ("function", "if", "repeat"):
            depth += 1
        elif word in ("for", "while"):
            depth += 1
            pending_do += 1
        elif word == "do":
            if pending_do:
                pending_do -= 1
            else:
                depth += 1
        else:                                   # end / until
            depth -= 1
            if depth == 0:
                return src[start.end():tok.start()]
    return None


def main():
    faults = []
    print("=" * 74)
    print("WHAT THE OFFER OPENS ON, AND WHAT SPEAKING CARRIES")
    print("=" * 74)

    # Comments blanked, strings KEPT: two of the things this border has
    # to read are string literals the code compares against - the
    # firsthand test `source ~= "told"` and the option's own label - and
    # the default `strip_lua` blanks exactly those. It reported three
    # faults in the Lua that way, all of them defects in the reading.
    perception = strip_lua(PERCEPTION.read_text(encoding="utf-8",
                                                errors="ignore"),
                           strings=False)
    harness = strip_lua(HARNESS.read_text(encoding="utf-8", errors="ignore"),
                        strings=False)

    # -- 1. What can actually cross between two people -----------------
    carried = {}
    for name in CARRIERS:
        body = body_of(perception, name)
        if body is None:
            faults.append(f"P.{name} is not in SAO_Perception.lua - this "
                          "border's account of how knowledge crosses is "
                          "out of date")
            continue
        carried[name] = set(re.findall(r"\bto\.(\w+)\[", body))
        print(f"  P.{name:<13} writes: "
              f"{', '.join(sorted(carried[name])) or 'NOTHING'}")
    if len(carried) != len(CARRIERS):
        return report(faults)

    crossable = set().union(*carried.values())

    # -- 2. What the offer opens on ------------------------------------
    gate = body_of(perception, "hasAnythingToPass")
    if gate is None:
        faults.append("P.hasAnythingToPass is gone - the offer is deciding "
                      "for itself again what it can pass on")
        return report(faults)
    opened = set(re.findall(r"\bb\.(\w+)\b", gate))
    print(f"  the offer opens on:   {', '.join(sorted(opened)) or 'NOTHING'}")

    for category in sorted(opened - crossable):
        faults.append(
            f"the offer opens on `{category}` and neither "
            f"{' nor '.join('P.' + c for c in CARRIERS)} writes it - the "
            "option appears, the player speaks, and nothing crosses")
    for category in sorted(crossable - opened):
        who = [n for n in CARRIERS if category in carried[n]]
        faults.append(
            f"`{category}` can cross (P.{who[0]} writes it) and the offer "
            "never opens on it - a player holding only that is never "
            "asked to speak")

    # -- 3. The offer opens on what the transfer will still accept -----
    #
    # `tell` shares a sighting only while it is FIRSTHAND and still
    # ACTIONABLE - `tick - at <= ZOMBIE_HORIZON`, about ten seconds. A
    # gate that checks neither opens on a memory the transfer refuses:
    # the option appears, the player speaks, nothing crosses, and the
    # answer is always "nothing new to them". Both tests have to be on
    # both sides or the gate is describing a different rule.
    tell_body = body_of(perception, "tell") or ""
    for test, what in (('source ~= "told"', "the firsthand test"),
                       ("ZOMBIE_HORIZON", "the actionable-age test"),
                       (".dead", "the death test")):
        in_tell = test in tell_body
        in_gate = test in gate
        print(f"  {what:<24} tell: {'yes' if in_tell else 'no':<4} "
              f"offer: {'yes' if in_gate else 'no'}")
        if in_tell and not in_gate:
            faults.append(
                f"P.tell applies {what} to a zombie belief and "
                "P.hasAnythingToPass does not - the offer opens on "
                "sightings the transfer will refuse, so speaking does "
                "nothing and says so")
        if in_gate and not in_tell:
            faults.append(
                f"P.hasAnythingToPass applies {what} and P.tell does not "
                "- the offer stays shut on knowledge that would have "
                "crossed")

    # -- 4. The harness reads the rule instead of re-deriving it -------
    offer = re.search(r'addOption\(\s*"Tell them what I\'ve seen"'
                      r'(?:.|\n){0,2000}', harness)
    if not offer:
        faults.append('the "Tell them what I\'ve seen" option is gone from '
                      "the harness - the player cannot speak at all")
        return report(faults)
    block = offer.group(0)

    uses_predicate = "Perception.hasAnythingToPass(" in harness
    print(f"  harness gate:         "
          f"{'reads Perception.hasAnythingToPass' if uses_predicate else 'DERIVES ITS OWN'}")
    if not uses_predicate:
        faults.append(
            "the harness does not read P.hasAnythingToPass - the gate is "
            "spelled in the UI and the transfer in Perception, and they "
            "drift apart in silence, which is how this defect began")

    reached = [c for c in CARRIERS if f"Perception.{c}(" in block]
    print(f"  the option reaches:   "
          f"{', '.join('P.' + c for c in reached) or 'NOTHING'}")
    for name in CARRIERS:
        if name not in reached:
            faults.append(
                f"the option does not reach P.{name} - "
                + ("what the player SAW cannot travel, which is the one "
                   "thing the option is named for"
                   if name == "reportReturn"
                   else "places and factions cannot travel"))

    # -- 5. One spelling of the listener's refusal ---------------------
    for name in SPEAKERS:
        body = body_of(perception, name)
        if body and f"P.{SKEPTIC}(" not in body:
            faults.append(
                f"P.{name} does not read P.{SKEPTIC} - a listener who "
                "distrusts the speaker refuses on one road and not the "
                "other, so being believed depends on which function "
                "carried the words")
    spellings = perception.count(THRESHOLD)
    print(f"  `{THRESHOLD}` appears:      {spellings}x in SAO_Perception.lua")
    if spellings != 1:
        faults.append(
            f"the trust threshold {THRESHOLD} is written {spellings} times "
            f"- it belongs only inside P.{SKEPTIC}, or the two copies part "
            "company the first time one of them moves")

    return report(faults)


def report(faults):
    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  34) relay: the offer opens on exactly what speaking carries, "
          "the harness reads")
    print("      that rule rather than its own, both roads are reached, "
          "and the listener's")
    print("      skepticism is written once")
    return 0


if __name__ == "__main__":
    sys.exit(main())
