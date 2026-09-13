#!/usr/bin/env python3
r"""Border 94 - whole minds survive the reload (DR-020).

The operator's pick, past the recommended subset: everything a
survivor believes - zombies, people, factions, places - survives
save/reload. The store binds to ModData at game start. The world-hours
stamps carry real age; dead-flagged people never decay (F-033); places
prune by proximity, not time.

[C112] changed what the tick half of this border holds, and the
change is the operator's own ruling, not a drift: every timer moved
onto the county's clock (`SAO.History.ticks`, world-age quantized),
so the tick axis crosses sessions now as a matter of course and the
wholesale zero-on-load rebase would itself be the defect - it would
age a two-minute-old belief to the beginning of the world on every
reload. What survives from the old rebase is the one case it existed
for: a stamp AHEAD of now cannot exist in the county domain (stamps
are made at now, the clock never runs backwards), so ahead-of-now is
a foreign-domain mark, and it reads as ultra-fresh forever if left
standing. The bind drops every such stamp to 0, which reads as long
ago - one reload's relearn per pre-[C112] save, both directions
safe, then never again.

WHAT THIS HOLDS
---------------
  1. The bind exists, targets the SurvivorAwareness_Beliefs store,
     runs at game start, and reports through the one logging door.
  2. The foreign-stamp drop zeroes ahead-of-now stamps against the
     county's own ticks, spares the Hours stamps, and
     cannot run twice (the re-bind guard).
  3. Pre-bind session entries are carried into the store, not lost.
  4. The durability laws the persistence leans on still stand: the
     decay pass spares dead-flagged people, and the people writes
     still carry the atHours stamp.

An optional argv[1] points the checker at another tree root, which is
how the control runs against the pre-[C15] tree.
"""
import pathlib
import sys

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
PER = (ROOT / "mod" / "42.20" / "media" / "lua" / "shared"
       / "SAO_Perception.lua")


def main():
    faults = []
    print("=" * 74)
    print("WHOLE MINDS SURVIVE THE RELOAD")
    print("=" * 74)

    try:
        src = PER.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        print()
        print("VERDICT:")
        print("  FAULT: SAO_Perception.lua is unreadable - no mind can be "
              "examined at all")
        return 1

    if 'ModData.getOrCreate("SurvivorAwareness_Beliefs")' not in src:
        faults.append("the belief store never binds to ModData - minds die "
                      "with the session, which DR-020 struck")
    if "bindPersistentStore" not in src \
            or "Events.OnGameStart" not in src:
        faults.append("no game-start bind exists - the store may exist and "
                      "never be opened")
    # [C112] The wholesale rebase became a foreign-stamp drop, and the
    # drop has to keep BOTH edges of the old cure: the ahead-of-now
    # comparison (a drop that zeroed everything would age fresh
    # county-domain stamps - the old bug, reborn as its own fix) and
    # the `entry.at = 0` reset (a comparison that only TESTED for
    # foreign stamps without dropping them would leave the ultra-fresh
    # defect standing).
    if "dropForeignStamps" not in src \
            or "entry.at > now" not in src \
            or "entry.at = 0" not in src \
            or "SAO.History.ticks" not in src:
        faults.append("the foreign-stamp drop is not what [C112] left - a "
                      "stamp ahead of the county's own ticks would read as "
                      "ultra-fresh forever, and stale intel would act like "
                      "a live sighting")
    if 'key:find("Hours")' not in src:
        faults.append("the rebase does not spare the world-hours stamps - "
                      "the one axis that truly crosses sessions would be "
                      "zeroed with the one that cannot")
    if "persisted == P.beliefs" not in src:
        faults.append("no re-bind guard - a second game-start event would "
                      "re-zero live tick stamps mid-session")
    if "persisted[id] = b" not in src:
        faults.append("pre-bind session entries are not carried into the "
                      "store - the first minute of every session's "
                      "perception is lost on the next save")
    if "not belief.dead" not in src:
        faults.append("the decay pass no longer spares the dead-flagged - "
                      "F-033's durable memory of the dead is gone, and "
                      "persistence would persist amnesia")
    if "atHours" not in src:
        faults.append("the world-hours stamp is gone from the people "
                      "writes - restored beliefs would have no true age")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  94) whole minds: the store binds at game start, the tick axis")
    print("      crosses sessions on the county's own clock ([C112]) with")
    print("      foreign ahead-of-now stamps dropped, the hours axis crosses")
    print("      intact, and the durability laws underneath still stand")
    return 0


if __name__ == "__main__":
    sys.exit(main())
