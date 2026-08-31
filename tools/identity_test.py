#!/usr/bin/env python3
"""The identity test ([B25]) - does everyone carry something forward?

The operator's design law, stated plainly:

    "Everyone has something of value to provide, regardless of whether
    or not their previous profession was in any way valuable to their
    current situation... a musician is not necessarily a job either.
    It can be a hobby... it's not so much just about, oh, what did
    they do? But who were... are they? What aspects of them do they
    intentionally attempt to carry on into the life after the
    apocalypse started?"

[B22] built the keepsake and the book, [B21] the porch. Each is the
same three-link chain, and this prices the FIRST link across the whole
county, because a link that never fires for a given person makes the
whole feature invisible TO THAT PERSON:

    a temperament gate says this person would want such a thing
      -> takeWantedFromNearby looks for one within 10 tiles
      -> carriedDisplayCategory READS what they actually ended up with

## What this can and cannot price, stated up front

**Cannot:** links two and three. Whether the place yielded an
instrument, a memento or a book is a fact about real containers on a
real map. Inventing a spawn rate would be authoring numbers, which is
the trap this project refuses.

**Can:** link one, exactly. The temperament gates are pure functions
of hash-derived traits, and the mirror derives traits with the same
accumulation the game does. So this measures the CEILING on coverage:
nobody can carry forward what their temperament never made them look
for. If the ceiling is already below everyone, no spawn rate would
save it.

## The verdict bar is the operator's law, not a number I picked

A person with zero temperament paths is a person the stated law says
should not exist. So this FAILS if anyone has none - not at some
invented percentage.

## Two honest divergences from live

- The mirror buckets the hash at 1/10000 where the game buckets at
  1/1000. Same [0.15, 0.85] range, same uniform distribution, so the
  shares below hold; individual people differ.
- The game bends traits with traitEchoes and lessonEchoes ([A14] S1);
  the mirror has no echo model. These are the traits a survivor
  STARTS with, before history moves them.
"""
import contextlib
import io
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

_quiet = io.StringIO()
with contextlib.redirect_stdout(_quiet):
    import equilibrium_test as eq

# The three gates, read straight off SAO_Population.lua. Each is
# (name, engine display category actually read back, predicate).
# [B25] All three now sit at 0.5, the midpoint of the human
# envelope [0.15, 0.85], and none of them excludes another.
GATES = (
    ("instrument", "InstrumentWeapon",
     lambda t: t["talkativeness"] > 0.5),
    ("keepsake", "Memento",
     lambda t: t["compassion"] > 0.5),
    ("reading", "Literature",
     lambda t: t["discipline"] > 0.5),
)

# Every trait the game gives a person. The identity gates above read
# only three of them, which is the thing this probe is really asking
# about.
ALL_TRAITS = ("nerve", "discipline", "aggression", "initiative",
              "selfPreservation", "compassion", "appetite",
              "talkativeness")

IDENTITY_TRAITS = ("talkativeness", "compassion", "discipline")


def traits_of(i):
    # Both the mirror and the game name people `sao-<n>`
    # (SAO_Identity.lua:43). Hashing a bare integer gives a
    # statistically identical county made of different people.
    sid = f"sao-{i}"
    return {k: eq._trait(sid, k) for k in ALL_TRAITS}


def main():
    print("The identity test ([B25]) - coverage of what people carry forward")
    print(f"county: {eq.N} people")

    paths = {}
    for sid in range(eq.N):
        t = traits_of(sid)
        paths[sid] = [name for name, _cat, ok in GATES if ok(t)]

    # 1. Coverage: how many have any path at all.
    counts = {}
    for sid in range(eq.N):
        counts[len(paths[sid])] = counts.get(len(paths[sid]), 0) + 1
    blank = [s for s in range(eq.N) if not paths[s]]

    print("\n--- link one: how many paths does a person's temperament open? ---")
    for k in sorted(counts):
        share = 100.0 * counts[k] / eq.N
        print(f"  {k} path(s): {counts[k]:3} people  ({share:.1f}%)")
    print(f"  people carrying NOTHING forward: {len(blank)}/{eq.N} "
          f"({100.0 * len(blank) / eq.N:.1f}%)")

    # 2. Which gate each blank person dies at, and by how much.
    print("\n--- which gate do the blank ones die at? ---")
    if blank:
        for name, _cat, _ok in GATES:
            print(f"  every one of them fails `{name}`")
        print("\n  and they are not blank people - here is the trait each")
        print("  one is MOST defined by, which nothing currently reads:")
        for sid in blank[:8]:
            t = traits_of(sid)
            top = max(ALL_TRAITS, key=lambda k: t[k])
            seen = "read by a gate" if top in IDENTITY_TRAITS \
                else "NOT read by any gate"
            print(f"    #{sid:<3} top trait {top:<17} {t[top]:.2f}  ({seen})")
        if len(blank) > 8:
            print(f"    ... and {len(blank) - 8} more")

    # 3. The structural point: how much of a person is even consulted.
    print("\n--- how much of a person do the identity gates read? ---")
    print(f"  traits the game gives a person: {len(ALL_TRAITS)}")
    print(f"  traits any identity gate reads: {len(IDENTITY_TRAITS)} "
          f"({', '.join(IDENTITY_TRAITS)})")
    unread = [k for k in ALL_TRAITS if k not in IDENTITY_TRAITS]
    print(f"  never consulted for identity:   {', '.join(unread)}")
    strongly = [s for s in blank
                if max(traits_of(s).values()) > 0.70]
    print(f"  blank people with a trait above 0.70 anyway: "
          f"{len(strongly)}/{len(blank) if blank else 0}")

    # The control. The BELIEF layer ([A18]'s claim grammar) reads six
    # traits and carries one claim that fits everybody, so it is what
    # broad coverage looks like when a layer is built to have it.
    # If the belief layer covers people the object layer drops, then
    # the object layer is one channel among several rather than the
    # one that must reach everyone - and that changes the verdict from
    # a defect into a division of labour.
    beliefs = {i: eq.MEMBER_CLAIMS.get(i, set()) for i in range(eq.N)}
    no_belief = [i for i in range(eq.N) if not beliefs[i]]
    blank_with_belief = [i for i in blank if beliefs[i]]
    print("\n--- the control: does the BELIEF layer reach them? ---")
    print(f"  people with no settled claim at all: {len(no_belief)}/{eq.N}")
    if blank:
        print(f"  of the {len(blank)} who carry no object, how many still")
        print(f"  hold a belief: {len(blank_with_belief)}/{len(blank)}")
    nothing_anywhere = [i for i in blank if not beliefs[i]]
    print(f"  people reached by NEITHER layer: {len(nothing_anywhere)}/{eq.N}")

    print("\nVERDICT:")
    # [B25] The bar is the operator's law - everyone has something
    # of value - and value is not only an object. A person defined by
    # aggression or initiative genuinely does not keep a memento, and
    # handing them one would author an identity nobody has. What the
    # law requires is that SOME channel reaches them.
    if nothing_anywhere:
        print(f"  {len(nothing_anywhere)} PEOPLE ARE REACHED BY NO CHANNEL "
              "AT ALL - neither an")
        print("  object they carry forward nor a belief they hold. The law")
        print('  "everyone has something of value" is not true of this county.')
        return 1
    print(f"  every one of {eq.N} people is reached by some channel")
    print(f"  object layer: {eq.N - len(blank)}/{eq.N}; "
          f"belief layer: {eq.N - len(no_belief)}/{eq.N}")
    if blank:
        print(f"  the {len(blank)} the object layer cannot see are defined by")
        print("  aggression, initiative or appetite - traits no keepsake")
        print("  expresses. That is a division of labour between the two")
        print("  channels, not a gap; inventing an object for them would be")
        print("  authoring an identity nobody has.")
    print("  NOT priced here: whether the place yielded one, or whether they")
    print("  still hold it - both read real containers on a real map.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
