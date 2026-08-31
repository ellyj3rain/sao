#!/usr/bin/env python3
r"""[B34] A queued action that was never queued.

Vanilla's ISTimedActionQueue.add RETURNS - it does not throw - on
three paths:

    action.ignoreAction
    character:isAsleep()
    isLocalPlayer() and isDraggingCorpse()
        and not action.allowedWhileDraggingCorpses

Read out of the shipped
media/lua/client/TimedActions/ISTimedActionQueue.lua, not assumed.

`pcall` reports only throws, so a dropped action came back as success.
The caller then set a state and a task deadline, and the survivor
stood in it doing nothing until the deadline expired. The third path
matters more than it looks: SAOIsoPlayerShell overrides
isLocalPlayer() to return true, so our survivors are INSIDE that gate.

This models the queue, drives an action through it both ways, and
checks that the sites where a drop is reachable AND costly actually
route through the verifying helper.

Which sites those are is a judgement, and it is recorded here rather
than left implicit:

    bandageSelf   the bleeding branch is not state-gated at all, so it
                  runs on a sleeping survivor - which is exactly when
                  a survivor starts bleeding.
    takePills     same branch shape, sickness rather than blood.
    eatCarried    hunger is checked from IDLE, and a sleeping survivor
                  still has state IDLE.
    drinkCarried  the same.

The other 18 sites in this file are reached only from a waking,
standing survivor, and converting them would be churn ([B34]).
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
NEEDS = (ROOT / "mod" / "42.20" / "media" / "lua" / "client"
         / "SAO_Needs.lua")
VANILLA = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"
    r"\media\lua\client\TimedActions\ISTimedActionQueue.lua")

MUST_VERIFY = ["bandageSelf", "takePills", "eatCarried", "drinkCarried"]


class Character:
    def __init__(self, asleep=False, dragging=False, local=True):
        self.asleep = asleep
        self.dragging = dragging
        self.local = local


class Action:
    def __init__(self, character, ignore=False, allowed_dragging=False):
        self.character = character
        self.ignoreAction = ignore
        self.allowedWhileDraggingCorpses = allowed_dragging


def vanilla_add(action, queues):
    """ISTimedActionQueue.add, as the shipped Lua writes it."""
    if action.ignoreAction:
        return
    if action.character.asleep:
        return
    if (action.character.local and action.character.dragging
            and not action.allowedWhileDraggingCorpses):
        return
    queues.setdefault(action.character, []).append(action)


def has_action(action, queues):
    return action in queues.get(action.character, [])


def old_shape(action, queues):
    """pcall(add) - true unless it THREW, which it never does."""
    vanilla_add(action, queues)
    return True


def new_shape(action, queues):
    """queueVerified - asks the queue whether it took it."""
    vanilla_add(action, queues)
    return has_action(action, queues)


def drop_paths_from_vanilla():
    """Confirm the three paths still exist in the shipped file."""
    if not VANILLA.exists():
        return None
    src = VANILLA.read_text(encoding="utf-8", errors="ignore")
    head = src[src.index("ISTimedActionQueue.add = function"):]
    head = head[:head.index("queue:addToQueue")]
    return {
        "ignoreAction": "action.ignoreAction" in head,
        "isAsleep": "isAsleep()" in head,
        "isDraggingCorpse": "isDraggingCorpse()" in head,
    }


def main():
    print("=" * 68)
    print("THE ENGINE'S OWN DROP PATHS")
    print("=" * 68)
    paths = drop_paths_from_vanilla()
    if paths is None:
        print("  SKIPPED - no game install to read")
    else:
        for k, v in paths.items():
            print(f"  {k:<20} {'present' if v else 'GONE'}")
        if not all(paths.values()):
            print("  a drop path this mirror models is no longer in the")
            print("  shipped queue - the model has drifted from vanilla")
            return 1

    print()
    print("=" * 68)
    print("DRIVEN - the same action, both shapes, three drop causes")
    print("=" * 68)
    cases = [
        ("awake, standing", Character()),
        ("asleep", Character(asleep=True)),
        ("dragging a corpse", Character(dragging=True)),
    ]
    ok_old_lies, ok_new_true = False, True
    for label, ch in cases:
        q1, q2 = {}, {}
        a1, a2 = Action(ch), Action(ch)
        said_old = old_shape(a1, q1)
        really = has_action(a1, q1)
        said_new = new_shape(a2, q2)
        print(f"  {label:<20} queued={str(really):<5} "
              f"old said {said_old!s:<5} new said {said_new}")
        if said_old and not really:
            ok_old_lies = True
        if said_new != has_action(a2, q2):
            ok_new_true = False

    print(f"\n  the old shape reports success on a drop: "
          f"{'YES' if ok_old_lies else 'NO'}")
    print(f"  the new shape never disagrees with the queue: "
          f"{'YES' if ok_new_true else 'NO'}")

    print()
    print("=" * 68)
    print("ROUTED - the sites where a drop is reachable and costly")
    print("=" * 68)
    src = NEEDS.read_text(encoding="utf-8", errors="ignore")
    unrouted = []
    for name in MUST_VERIFY:
        m = re.search(r"function N\." + name + r"\(", src)
        if not m:
            print(f"  {name:<16} FUNCTION GONE")
            unrouted.append(name)
            continue
        body = src[m.start():]
        end = body.find("\nfunction ", 1)
        body = body[:end if end > 0 else len(body)]
        routed = "N.queueVerified(" in body
        bare = re.search(r"^\s*ISTimedActionQueue\.add\(", body, re.M)
        print(f"  {name:<16} routed={routed}  bare-add={bool(bare)}")
        if not routed or bare:
            unrouted.append(name)

    total_add = len(re.findall(r"^\s*ISTimedActionQueue\.add\(", src,
                               re.M))
    print(f"\n  bare add() sites left in this file: {total_add} "
          "(deliberate - reached only while awake)")

    # [B34] The helper itself has to still ASK. Modelling the fix in
    # Python proves the idea and nothing about the shipped code - gut
    # queueVerified back to `return true` and every check above stays
    # green. This mirror's own second control caught that, one batch
    # after [B33] got the same thing right.
    hm = re.search(r"function N\.queueVerified\(action\)(.*?)\nend",
                   src, re.S)
    helper_asks = False
    if hm:
        body = hm.group(1)
        helper_asks = ("ISTimedActionQueue.hasAction" in body
                       and "return okH and has == true" in body)
    print(f"  the shipped helper asks the queue: "
          f"{'YES' if helper_asks else 'NO'}")

    print()
    print("VERDICT:")
    print(f"  model matches the shipped queue:  "
          f"{'YES' if paths is None or all(paths.values()) else 'NO'}")
    print(f"  defect reproduced:                "
          f"{'YES' if ok_old_lies else 'NO'}")
    print(f"  fix holds under all three causes: "
          f"{'YES' if ok_new_true else 'NO'}")
    print(f"  every costly site routed:         "
          f"{'YES' if not unrouted else 'NO ' + str(unrouted)}")
    print(f"  shipped helper still asks:        "
          f"{'YES' if helper_asks else 'NO'}")
    if not ok_old_lies or not ok_new_true or unrouted or not helper_asks:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
