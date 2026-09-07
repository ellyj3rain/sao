#!/usr/bin/env python3
r"""Border 89 - the kept promise swings at the body, not at the nearest.

The operator's item 3: the promise keeper's mercy kill was
`orderEngageNearest` - whatever zombie stood closest to where the
turned was SEEN, which after any wander is a stranger's body. Mercy
for the wrong dead is nobody's mercy, and the person the promise was
for still walks.

[C8] gave the risen body the one identity that survives the turn (the
modData mark), so [C10] can aim: `beginCombatWithPersonId` finds the
ONE body carrying the person's id within a named reach of the promise
site and opens the combat loop on it - the argued exception to [C9]'s
identity skip (mercy FIGHTS the risen known face; it never deletes or
puppeteers one). When the body is not there, the promise stays
carried and the next sighting re-arms the walk; no nearest-body
fallback exists on this path any more.

WHAT THIS HOLDS
---------------
  1. The bridge verb exists, keys on the [C8] mark, and reports the
     honest miss (`BODY_NOT_FOUND`) instead of substituting a target.
  2. The promise-keeping block calls it, no longer calls
     `orderEngageNearest`, and clears the promise ONLY once the swing
     actually began - a miss carries the promise.
  3. The search reach is named (`PROMISE_BODY_REACH`), not a bare
     number.

An optional argv[1] points the checker at another tree root, which is
how the control runs against the pre-[C10] tree.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
CTL = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Controller.lua"
BRIDGE = ROOT / "java" / "src" / "com" / "sao" / "bridge" / "SAOBridge.java"


def main():
    faults = []
    print("=" * 74)
    print("THE KEPT PROMISE SWINGS AT THE BODY")
    print("=" * 74)

    try:
        ctl = CTL.read_text(encoding="utf-8", errors="ignore")
        bridge = BRIDGE.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        print()
        print("VERDICT:")
        print("  FAULT: the controller or the bridge is unreadable - the "
              "promise path cannot be inspected")
        return 1

    # 1. The verb.
    verb = re.search(r"public String beginCombatWithPersonId.*?\n    \}",
                     bridge, re.S)
    if not verb:
        faults.append("the bridge has no beginCombatWithPersonId - there "
                      "is no way to open combat on the one body that "
                      "carries the person")
    else:
        body = verb.group(0)
        if "SAOPersonId" not in body:
            faults.append("beginCombatWithPersonId does not read the [C8] "
                          "mark - it cannot find the person's body")
        if "BODY_NOT_FOUND" not in body:
            faults.append("beginCombatWithPersonId has no honest miss - a "
                          "caller cannot tell an absent body from a swing")

    # 2. The promise-keeping block.
    block = re.search(
        r"if agent\.promiseTarget then.*?walks toward the promise",
        ctl, re.S)
    if not block:
        faults.append("the promise-keeping block is gone or reshaped past "
                      "recognition - nothing keeps promises at all")
    else:
        keep = block.group(0)
        if "beginCombatWithPersonId" not in keep:
            faults.append("the kept promise does not aim at the person's "
                          "body - whatever it swings at is chosen some "
                          "other way")
        if "orderEngageNearest" in keep:
            faults.append("the kept promise still falls back to the "
                          "NEAREST body - the exact wrong-body swing the "
                          "operator named")
        started = keep.find("COMBAT_STARTED")
        cleared = keep.find("clearPromise")
        if cleared != -1 and (started == -1 or cleared < started):
            faults.append("the promise is cleared before the swing is "
                          "known to have begun - a missed body would "
                          "silently discharge the promise")

    # 3. The named reach.
    if not re.search(r"local PROMISE_BODY_REACH\s*=", ctl) \
            or "PROMISE_BODY_REACH" not in (block.group(0) if block else ""):
        faults.append("the promise-site search reach is not the named "
                      "PROMISE_BODY_REACH - a bare number nobody can "
                      "argue with")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  89) the promise: aimed at the one body carrying the person's mark,")
    print("      honest about a miss, carried rather than discharged on absence,")
    print("      and never the nearest stranger again")
    return 0


if __name__ == "__main__":
    sys.exit(main())
