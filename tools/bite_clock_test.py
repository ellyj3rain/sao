#!/usr/bin/env python3
r"""Border 90 - the bite kills on the engine's clock, and no constant
claims an authority it does not have.

The operator's item 4: the dormant bite-risk formula
("0.10 + min(0.5, since/480)") carried a comment calling it "the
engine's own turning odds". The [C11] javap pass (F-047) found the
engine has no turning ODDS at all: a bite infects with CERTAINTY
(BodyPart.SetBitten sets isInfected under any saliva transmission -
no roll exists on this build), and the infected die EXACTLY at
infectionTime + pickMortalityDuration (BodyDamage.Update drives the
course to ReduceGeneralHealth(110) at progress 1.0). A deterministic
window, per-body, trait-scaled, sandbox-governed.

So the formula was not relabeled - it was replaced by the law it
falsely claimed: the record carries the body's own death hour (read
via biteHoursLeft as it goes dark, or mirrored from the sandbox table
when the course had not stamped its clock), past which death is due,
not rolled. Who rises mirrors shouldBecomeZombieAfterDeath (F-044).

WHAT THIS HOLDS
---------------
  1. The uncited formula is gone, and so is its false claim.
  2. The bridge reads the engine's clock (isInfected, infectionTime,
     mortality duration), and the population stamps the record with it.
  3. The mirror window exists for the unpicked case, cites
     pickMortalityDuration, and carries the default 48-72h band.
  4. A due bite bypasses the ambient roll, and the dormant turning
     predicate mirrors the engine's (infection, or Transmission 3).
  5. The wound-infection multiplier that remains is labeled OUR
     tuning, in so many words.

An optional argv[1] points the checker at another tree root, which is
how the control runs against the pre-[C11] tree.
"""
import pathlib
import sys

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
POP = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Population.lua"
BRIDGE = ROOT / "java" / "src" / "com" / "sao" / "bridge" / "SAOBridge.java"


def main():
    faults = []
    print("=" * 74)
    print("THE BITE KILLS ON THE ENGINE'S CLOCK")
    print("=" * 74)

    try:
        pop = POP.read_text(encoding="utf-8", errors="ignore")
        bridge = BRIDGE.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        print()
        print("VERDICT:")
        print("  FAULT: the population or the bridge is unreadable - the "
              "clock cannot be inspected")
        return 1

    # 1. The formula and its false claim are gone.
    if "since / 480" in pop or "0.10 + math.min(0.5" in pop:
        faults.append("the invented bite formula is still in the "
                      "population - a number of ours dressed as the "
                      "engine's")
    if "engine's own turning odds" in pop:
        faults.append("the comment still claims the numbers are the "
                      "engine's own turning odds - the false authority "
                      "the operator named")

    # 2. The engine's clock, read.
    if "biteHoursLeft" not in bridge \
            or "getInfectionMortalityDuration" not in bridge \
            or "getInfectionTime" not in bridge:
        faults.append("the bridge does not read the engine's own bite "
                      "clock - whatever the record carries is invented")
    if "biteHoursLeft" not in pop or "biteDeathAtHours" not in pop:
        faults.append("the population never stamps the record with the "
                      "body's death hour - the dormant arc has no clock "
                      "to obey")

    # 3. The mirror for the unpicked case.
    if "biteWindowHours" not in pop or "pickMortalityDuration" not in pop:
        faults.append("there is no cited sandbox-window mirror for a body "
                      "that went dark before the engine stamped its clock")
    if "48" not in pop.split("biteWindowHours()", 1)[-1][:1200] \
            and "local function biteWindowHours" in pop:
        pass  # band checked below on the definition
    defn = pop.split("local function biteWindowHours", 1)
    if len(defn) > 1:
        band = defn[1][:600]
        if "48" not in band or "168" not in band:
            faults.append("the mirror window does not carry the engine's "
                          "own bands (48-72h default, 1-2 weeks) - a "
                          "mirror that mirrors something else")

    # 4. Due beats rolled; turning mirrors the engine.
    if "if biteDue" not in pop:
        faults.append("a due bite still goes through the ambient roll - "
                      "a certain death made accidental")
    if "Transmission == 3" not in pop:
        faults.append("the dormant turning predicate does not mirror "
                      "Everyone's Infected - under that lore every death "
                      "turns, and out there nobody would")

    # 5. The surviving multiplier owns itself.
    if "woundInfected" in pop and "OUR tuning" not in pop:
        faults.append("the wound-infection multiplier no longer says it "
                      "is our tuning - an unlabeled constant is how this "
                      "class starts")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  90) the bite clock: the engine's deterministic window read off the")
    print("      body or mirrored with citation, due deaths not rolled, turning")
    print("      mirrored from the engine's own predicate, and the one surviving")
    print("      constant labeled as ours")
    return 0


if __name__ == "__main__":
    sys.exit(main())
