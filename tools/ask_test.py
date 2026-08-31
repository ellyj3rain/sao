#!/usr/bin/env python3
"""The ask test ([B24]) - can a hungry house ever be answered?

[B24] and [B24] established the lesson this exists for: **unmodelled
means uncheckable.** The pact layer was structurally dead for the life
of the project and nothing noticed, because no mirror simulated pacts.
[B23]'s ask is the same shape - a CHAIN of gates where one dead link
makes the whole feature invisible:

    a quartermaster counts the larder lean
      -> callForBread puts word out (three-day cooldown)
      -> another house's nearestAsking finds it, which needs
           that house's own larder FULL,
           its creed in {mercy, road, order} - wall refuses,
           both houses holding ground,
           and no feud between them
      -> a forager runs bread over
      -> addDebt, and the fed leader's trust rises

## What this can and cannot price, stated up front

**Cannot:** how OFTEN a house is lean or full. The live larder is
counted from real items in real containers on a real map. Inventing a
forage rate and a consumption rate to simulate that would be authoring
numbers, not porting them - the trap [B23] named and this project
refuses. Nor whether a given house holds ground, which comes from the
settle machinery arriving somewhere.

**Can:** everything that does not depend on food. The creed gate and
the feud gate are pure social facts, and the converged county has real
ones. If those alone make the ask unreachable, that is a structural
finding and no amount of larder simulation would change it.

So this reports **reachability, not frequency**, and says which gate
would be responsible.
"""
import contextlib
import io
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

_quiet = io.StringIO()
with contextlib.redirect_stdout(_quiet):
    import equilibrium_test as eq

# [B23]'s own table, read off the ration policies: mercy feeds the
# weakest and road holds nothing back, so both come; order comes from a
# full larder; wall does not come, because "their own and no one else"
# is what wall means.
ANSWERS_ASK = {"mercy": True, "road": True, "order": True, "wall": False}


def houses():
    by_group = {}
    for member, g in eq.group.items():
        by_group.setdefault(g, []).append(member)
    return {g: sorted(m) for g, m in by_group.items()}


def main():
    hs = houses()
    print("The ask test ([B24]) - reachability of [B23]'s chain")
    print(f"county: {len(hs)} companies out of {eq.N} people")

    # 1. The creed gate, priced against the converged county.
    by_creed = {}
    for g in hs:
        c = eq.settled_creed_of(g)
        by_creed.setdefault(c, []).append(g)
    print("\n--- the creed gate ---")
    for creed in sorted(by_creed):
        answers = "answers" if ANSWERS_ASK.get(creed) else "REFUSES"
        print(f"  {creed:7} {len(by_creed[creed]):3} companies  ({answers})")
    willing = [g for g in hs if ANSWERS_ASK.get(eq.settled_creed_of(g))]
    print(f"  companies that would answer an ask: {len(willing)}/{len(hs)}")

    # 2. The feud gate, over ordered pairs.
    pairs = blocked = open_pairs = 0
    for a in hs:
        for b in hs:
            if a == b:
                continue
            pairs += 1
            if not ANSWERS_ASK.get(eq.settled_creed_of(a)):
                continue
            if eq.in_feud(a, b):
                blocked += 1
                continue
            open_pairs += 1
    print("\n--- the feud gate ---")
    print(f"  ordered (answerer, asker) pairs: {pairs}")
    print(f"  blocked by war: {blocked}")
    print(f"  reachable on social gates alone: {open_pairs}")

    # [B25] A creed-keyed gate that has collapsed to ONE value is the
    # shape [B24] found years late: every company was `wall`, so every
    # gate keyed on the creed answered the same way and four
    # subsystems went quiet without a single error being raised. Watch
    # the gates themselves, not only this one chain.
    STRUCTURED = {"order", "wall"}
    forms = {}
    answers_split = {}
    for g in hs:
        creed = eq.settled_creed_of(g)
        key = "ladder-eligible" if creed in STRUCTURED else "council-or-flat"
        forms[key] = forms.get(key, 0) + 1
        akey = "answers" if ANSWERS_ASK.get(creed) else "refuses"
        answers_split[akey] = answers_split.get(akey, 0) + 1

    print("\n--- creed-keyed gates: still gates, or now constants? ---")
    print(f"  [B23] form gate: {forms}")
    print(f"  [B23] ask gate:  {answers_split}")

    collapsed = []
    if len(forms) < 2:
        collapsed.append("[B23] form")
    if len(answers_split) < 2:
        collapsed.append("[B23] ask")

    print("\nVERDICT:")
    if collapsed:
        print("  A CREED GATE HAS COLLAPSED TO A CONSTANT: "
              + ", ".join(collapsed))
        print("    every company answers it the same way, which is exactly")
        print("    how [B24] stayed hidden for the life of the project")
        return 1
    if open_pairs == 0:
        print("  NO HOUSE COULD EVER ANSWER ANOTHER - structural block")
        if not willing:
            print("    cause: no company holds a creed that answers")
        else:
            print("    cause: war covers every willing pair")
        return 1
    print(f"  the ask is reachable: {open_pairs} pairs could answer "
          "if the shelves lined up")
    print("  NOT priced here: how often a house is lean or full (the live "
          "count reads real containers), nor whether it holds ground.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
