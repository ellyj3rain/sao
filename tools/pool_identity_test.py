#!/usr/bin/env python3
r"""Border 88 - the pool is only the fungible crowd.

The operator's item 2, confirmed independent of any sibling project:
every survivor spawn paid its population cost through
`takeFromThePool`, which did `nearest.removeFromWorld()` on whatever
IsoZombie stood closest - and the zombie list is not a list of
fungible zombies. It holds living neighbours (DR-009's Knox humans
are zombie-backed), risen players, and - since [C8] - the county's
own marked dead. A spawn could quietly DELETE a person.

The same fungibility assumption sat in `directNearestZombieAt`, which
could point a living neighbour at a shell as incoming combat, or
puppeteer a risen known body whose brain is vanilla's (DR-016 - one
brain per body). `beginCombatNearest` and the perception scanner
already discriminated (isKnoxHuman, [B10]/DR-009); the class was
never finished across its population, which is what this border now
holds.

WHAT THIS HOLDS
---------------
  1. One deletion-grade predicate: `SAOKnox.identityBearing` - Knox
     marks, `isReanimatedPlayer`, the [C8] `SAOPersonId` stamp - and
     it fails CLOSED (`return true` in the catch): a body whose
     identity cannot be read is spared.
  2. Both previously-blind consumers use it: `takeFromThePool` skips
     identity-bearing bodies before choosing, and
     `directNearestZombieAt` choreographs only the fungible crowd.
  3. The census of `.removeFromWorld()` in the Java tree is closed:
     every occurrence is one of the declared sites, so a new blind
     deletion cannot appear without arguing itself here.

An optional argv[1] points the checker at another tree root, which is
how the control runs against the pre-[C9] tree.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
JAVA = ROOT / "java" / "src" / "com" / "sao"

# Every `.removeFromWorld()` call the Java tree is allowed to make,
# with the reason it is not a blind deletion. Keyed by file name and a
# snippet that must appear within the preceding lines of the call.
ALLOWED_REMOVALS = {
    ("SAOBridge.java", "identityBearing"):
        "takeFromThePool - guarded by the deletion-grade predicate "
        "before any body is chosen",
    ("SAOBridge.java", "removeShell"):
        "the county's own shell teardown (KNF.safelyRemove port) - "
        "removing a body we made, never somebody else's",
}


def main():
    faults = []
    print("=" * 74)
    print("THE POOL IS ONLY THE FUNGIBLE CROWD")
    print("=" * 74)

    try:
        knox = (JAVA / "engine" / "SAOKnox.java").read_text(
            encoding="utf-8", errors="ignore")
        bridge = (JAVA / "bridge" / "SAOBridge.java").read_text(
            encoding="utf-8", errors="ignore")
    except OSError:
        print()
        print("VERDICT:")
        print("  FAULT: the Java sources are unreadable - nothing about "
              "the pool can be established")
        return 1

    # 1. The predicate, deletion-grade.
    m = re.search(r"public static boolean identityBearing.*?\n    \}",
                  knox, re.S)
    if not m:
        faults.append("SAOKnox has no identityBearing - there is no "
                      "deletion-grade answer to 'is this body a person'")
    else:
        body = m.group(0)
        for needle, what in (
                ("isKnoxHuman", "the living neighbours (DR-009)"),
                ("isReanimatedPlayer", "risen players"),
                ("SAOPersonId", "the county's own marked dead ([C8])")):
            if needle not in body:
                faults.append(f"identityBearing does not check {needle} - "
                              f"{what} are deletable again")
        if not re.search(r"catch\s*\(Throwable\s+\w+\)\s*\{\s*return true;",
                         body):
            faults.append("identityBearing fails OPEN - a body whose "
                          "identity cannot be read would be deleted, and "
                          "unreadable is exactly the state a foreign mod's "
                          "person is most likely to be in")

    # 2. Both previously-blind consumers.
    pool = re.search(r"private static boolean takeFromThePool.*?\n    \}",
                     bridge, re.S)
    if not pool or "identityBearing" not in pool.group(0):
        faults.append("takeFromThePool does not consult identityBearing - "
                      "a spawn can still quietly delete a person")
    direct = re.search(r"public String directNearestZombieAt.*?\n    \}",
                       bridge, re.S)
    if not direct or "identityBearing" not in direct.group(0):
        faults.append("directNearestZombieAt does not consult "
                      "identityBearing - a living neighbour can be pointed "
                      "at a shell as incoming combat, or a risen known "
                      "body puppeteered (DR-016)")
    combat = re.search(r"public String beginCombatNearest.*?\n    \}",
                       bridge, re.S)
    if not combat or "isKnoxHuman" not in combat.group(0):
        faults.append("beginCombatNearest no longer skips living "
                      "neighbours - the one consumer that discriminated "
                      "has stopped")

    # 3. The removeFromWorld census is closed.
    sites = 0
    for path in sorted(JAVA.rglob("*.java")):
        src = path.read_text(encoding="utf-8", errors="ignore")
        lines = src.split("\n")
        for i, line in enumerate(lines):
            if ".removeFromWorld()" not in line:
                continue
            sites += 1
            window = "\n".join(lines[max(0, i - 30):i + 1])
            hit = None
            for (fname, snippet), why in ALLOWED_REMOVALS.items():
                if path.name == fname and snippet in window:
                    hit = why
                    break
            if hit is None:
                faults.append(
                    f"{path.name}:{i + 1} calls removeFromWorld and no "
                    "declared site covers it - a deletion nobody argued. "
                    "Guard it or add it to ALLOWED_REMOVALS with the "
                    "reason it cannot be deleting a person")
    if sites == 0:
        faults.append("no removeFromWorld call was found at all - the "
                      "census read nothing and this verdict would be "
                      "about an empty set")
    print(f"  removeFromWorld sites: {sites}   declared: "
          f"{len(ALLOWED_REMOVALS)}")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  88) the pool: one deletion-grade predicate, failing closed; both")
    print("      blind consumers discriminate; the removeFromWorld census is")
    print("      closed and every site argued")
    return 0


if __name__ == "__main__":
    sys.exit(main())
