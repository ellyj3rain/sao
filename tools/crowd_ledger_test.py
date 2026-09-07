#!/usr/bin/env python3
r"""Border 96 - the crowd ledger: two dials, one accounting.

DR-021's state agreement, the operator's direction: survivors are
also taken from the vanilla bulk by design, so state agreement must
hold there even with both layers controllable and configurable. The
pool-taking ([B21]) and the presence layer
mutate the same crowd, so they reconcile against one durable ledger:
every take is counted (the bridge's monotonic session counter, folded
durable each pulse), and restitution only ever repays that debt - one
body returned per body taken, paced per day, on distant town ground,
never inventing presence the pool did not consume. The derived totals
stay unratified until the census has measured.

WHAT THIS HOLDS
---------------
  1. The bridge counts every successful pool take, and the counter is
     read by the Lua ledger fold.
  2. The durable ledger exists (SurvivorAwareness_CrowdLedger), the
     fold runs on the daily pulse regardless of the dial (the truth
     accrues even when restitution is off), and restitution is gated
     on the sandbox option.
  3. Restitution repays AT MOST the debt (owed = taken - added), at a
     named daily pace, placed beyond the hibernate radius through the
     engine's own addVirtualZombie - no removeFromWorld, no invented
     budget.
  4. The option ships default false (DR-021: off until the census has
     measured), and its copy is ratified in Border 92's declaration.

An optional argv[1] points the checker at another tree root, which is
how the control runs against the pre-[C17] tree.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
BRIDGE = ROOT / "java" / "src" / "com" / "sao" / "bridge" / "SAOBridge.java"
POP = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Population.lua"
OPTS = ROOT / "mod" / "42.20" / "media" / "sandbox-options.txt"


def main():
    faults = []
    print("=" * 74)
    print("TWO DIALS, ONE ACCOUNTING")
    print("=" * 74)

    try:
        bridge = BRIDGE.read_text(encoding="utf-8", errors="ignore")
        pop = POP.read_text(encoding="utf-8", errors="ignore")
        opts = OPTS.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        print()
        print("VERDICT:")
        print("  FAULT: a ledger source is unreadable - no accounting to "
              "inspect")
        return 1

    # 1. The take is counted.
    pool = re.search(r"private static boolean takeFromThePool.*?\n    \}",
                     bridge, re.S)
    if not pool or "poolTaken++" not in pool.group(0):
        faults.append("takeFromThePool does not count its takes - the "
                      "ledger's feed is dry and restitution repays a debt "
                      "nobody recorded")
    if "poolTakenCount" not in bridge or "poolTakenCount" not in pop:
        faults.append("the take counter is not exposed or not read - the "
                      "two dials cannot see one accounting")

    # 2. The durable ledger and its fold.
    if 'ModData.getOrCreate("SurvivorAwareness_CrowdLedger")' not in pop:
        faults.append("no durable crowd ledger exists - the accounting "
                      "dies with the session")
    if "ledger.taken = ledger.taken + delta" not in pop:
        faults.append("takes are not folded into the durable ledger")
    fold = pop.find("SurvivorAwareness_CrowdLedger")
    gate = pop.find("RestoreTakenZombies == true")
    if fold != -1 and gate != -1 and gate < fold:
        faults.append("the fold runs behind the dial - with restitution "
                      "off, takes would go uncounted and a later enable "
                      "would repay nothing")

    # 3. Debt-bounded, paced, distant, additive-only.
    if "ledger.taken - ledger.added" not in pop:
        faults.append("restitution is not bounded by the debt - it could "
                      "invent presence the pool never consumed, which is "
                      "the unratified-total line DR-021 draws")
    if "RESTITUTION_PER_DAY" not in pop:
        faults.append("the repayment pace is not named - a late enable "
                      "dumps history into one night")
    if "conf.hibernate * conf.hibernate" not in pop:
        faults.append("restitution can place next to the player - 'never "
                      "near you' is the genesis law and this layer is not "
                      "above it")
    if "addVirtualZombie" not in pop:
        faults.append("restitution does not go through the engine's own "
                      "virtual add - whatever it does instead is unverified")

    # 4. The dial ships off.
    if not re.search(r"option SurvivorAwareness\.RestoreTakenZombies "
                     r"\{\s*\n\s*type = boolean, default = false,", opts):
        faults.append("the restitution dial does not ship default-false - "
                      "DR-021 holds the default until the census has "
                      "measured")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  96) the crowd ledger: every take counted durable, restitution")
    print("      debt-bounded and paced on distant ground, the dial off by")
    print("      default, and both dials reading one accounting")
    return 0


if __name__ == "__main__":
    sys.exit(main())
