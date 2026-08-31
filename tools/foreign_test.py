#!/usr/bin/env python3
r"""[B33] Someone else's people, and whether we can find them again.

The operator asked for other NPC mods to be ancillary rather than
dependencies - "and also any other, like, models, like Bandit, for
instance."

The PREDICATE that finds them is genuinely generic.
`SAOPerceptionScanner.isForeignPerson` tests three engine facts and
names no mod:

    an IsoPlayer, that is NOT one of our shells, and that is NOT in
    IsoPlayer.players[]

Any mod whose NPCs are IsoPlayer-based is matched by construction.

The IDENTITY was not. A foreign person becomes a belief key through a
round trip across three files:

    scanner   label = "~" + person.getUsername()
    Lua       keyForObserved strips the ~   ->  foreign:<name>
    bridge    foreignBodyByName matches person.getUsername()

`IsoPlayer.username` is a plain field, null unless a mod calls
setUsername, and the scanner already anticipated that with

    label = "~" + (label == null ? "someone" : label)

so on the null path the key is `foreign:someone` and the lookup asks
`"someone".equals(null)`, which is false forever. Two failures at once:
the body can never be resolved, and every such NPC from every mod
collapses into ONE key - the "two Anas stay two records" collision that
[A17] named and that the Knox path already solves with a three-step id.

This models the round trip both ways and refuses to pass unless the
live Java is the fixed one.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCANNER = (ROOT / "java" / "src" / "com" / "sao" / "engine"
           / "SAOPerceptionScanner.java")
BRIDGE = (ROOT / "java" / "src" / "com" / "sao" / "bridge"
          / "SAOBridge.java")


class Person:
    """Someone else's IsoPlayer-based NPC."""

    def __init__(self, username=None, forename=None, surname=None,
                 oid=0):
        self.username = username
        self.forename = forename
        self.surname = surname
        self.oid = oid


def sanitize(s):
    return s.replace("|", "_").replace(":", "_")


def name_old(p):
    """The derivation as it stood: username, else a constant."""
    return p.username if p.username else "someone"


def name_new(p):
    """[B33]: username, else the descriptor, else the object's own id.

    Mirrors foreignName() in SAOPerceptionScanner - one derivation, and
    both the label and the lookup call it.
    """
    if p.username:
        return sanitize(p.username)
    if p.forename:
        full = p.forename + (" " + p.surname if p.surname else "")
        return sanitize(full)
    return "#" + str(p.oid)


def round_trip(people, derive, lookup_by_username_only):
    """key -> the people that key resolves to, over one cell."""
    keys = {}
    for p in people:
        keys.setdefault("foreign:" + derive(p), []).append(p)

    resolved = {}
    for key, group in keys.items():
        want = key[len("foreign:"):]
        found = []
        for p in people:
            # The bridge's match, as it is actually written.
            got = p.username if lookup_by_username_only else derive(p)
            if got is not None and got == want:
                found.append(p)
        resolved[key] = found
    return keys, resolved


def live_is_fixed():
    """Is the shipped Java the one-derivation version?"""
    if not SCANNER.exists() or not BRIDGE.exists():
        return None
    s = SCANNER.read_text(encoding="utf-8", errors="ignore")
    b = BRIDGE.read_text(encoding="utf-8", errors="ignore")
    declares = re.search(r"static\s+String\s+foreignName\s*\(", s)
    labels = "foreignName(" in s.split("isForeignPerson(person)")[-1] \
        if "isForeignPerson(person)" in s else False
    looks_up = "foreignName(" in b
    return bool(declares) and bool(labels) and bool(looks_up)


def main():
    cell = [
        Person(username="Bob", oid=1),
        Person(forename="Ana", surname="Reyes", oid=2),
        Person(forename="Bo", oid=3),
        Person(oid=4),
        Person(oid=5),
    ]
    print("=" * 68)
    print("A cell holding five of someone else's people")
    print("=" * 68)
    for p in cell:
        print(f"  username={str(p.username):<6} forename="
              f"{str(p.forename):<5} id={p.oid}")

    print()
    print("=" * 68)
    print("CONTROL - the OLD derivation must be shown broken, or this")
    print("          mirror is not modelling the defect it describes")
    print("=" * 68)
    keys, res = round_trip(cell, name_old, True)
    dead = [k for k, v in res.items() if not v]
    collided = {k: v for k, v in keys.items() if len(v) > 1}
    print(f"  distinct keys for 5 people: {len(keys)}")
    print(f"  keys that resolve to nobody: {len(dead)}  {dead}")
    print(f"  keys holding more than one person: "
          f"{[(k, len(v)) for k, v in collided.items()]}")
    old_broken = bool(dead) and bool(collided)
    print(f"  old derivation is broken: "
          f"{'YES' if old_broken else 'NO'}")

    print()
    print("=" * 68)
    print("THE FIX - username, else the descriptor, else the object id")
    print("=" * 68)
    keys2, res2 = round_trip(cell, name_new, False)
    dead2 = [k for k, v in res2.items() if not v]
    collided2 = {k: v for k, v in keys2.items() if len(v) > 1}
    ambiguous = {k: v for k, v in res2.items() if len(v) > 1}
    for k in sorted(keys2):
        print(f"    {k}")
    print(f"  distinct keys for 5 people: {len(keys2)}")
    print(f"  keys that resolve to nobody: {len(dead2)}")
    print(f"  keys holding more than one person: {len(collided2)}")
    print(f"  keys resolving ambiguously: {len(ambiguous)}")

    new_ok = (len(keys2) == len(cell) and not dead2
              and not collided2 and not ambiguous)

    print()
    print("=" * 68)
    print("IS THE SHIPPED JAVA THE FIXED ONE?")
    print("=" * 68)
    live = live_is_fixed()
    if live is None:
        print("  SKIPPED - java sources not present")
    else:
        print(f"  foreignName declared, used to label, and used to "
              f"look up: {'YES' if live else 'NO'}")

    print()
    print("VERDICT:")
    print(f"  old derivation demonstrably broken:  "
          f"{'YES' if old_broken else 'NO'}")
    print(f"  new derivation round-trips, 1:1:     "
          f"{'YES' if new_ok else 'NO'}")
    print(f"  live Java uses one derivation:       "
          f"{'YES' if live else 'NO'}")
    if not old_broken:
        print("  INSTRUMENT FAILED ITS CONTROL")
        return 1
    if not new_ok:
        print("  THE PROPOSED FIX DOES NOT CLOSE THE ROUND TRIP")
        return 1
    if live is False:
        print("  THE SHIPPED JAVA STILL HAS THE SPLIT DERIVATION")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
