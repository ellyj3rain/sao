#!/usr/bin/env python3
"""The joining test ([B19], mirrored per the same-batch doctrine).

[B19] wrote a new social law - who goes along when someone announces a
venture - and a social law that has never been run outside the game is
an assertion. This ports the LIVE gates exactly:

    bound   = their own pressure answer == "need"
    solo    = circle(id) == "loner"
    onWall  = designation == "watch" and kind ~= "warpath"
    pull    = trust(hearer, goer)
              + 0.3 if bonded
              + 0.20 * weight(hearer, "people-are-worth-it")
              - 0.20 * weight(hearer, "trust-carefully")
              + 0.20 * (nerve(hearer) - 0.5)
    join    = not bound and not solo and not onWall and pull > 0.55
    order   = by pull, keenest first
    cap     = circleCap(goer), then min(cap, free_seats - 1) with a
              car, then min(cap, hearers - 1) if the house holds a
              larder, a water store, or a hearth to mind

and the real FNV hash behind circle() and trait(), so circle and nerve
are the same facts here as in the game.

The county is not synthetic: it is the converged 60-person society the
equilibrium test produces after 120 days, so the trust values these
gates read are the ones the social physics actually generates.

Four hard laws with a right answer:
  - a loner must never be taken (the operator ruled joining is
    never forced)
  - the circle cap must never be exceeded
  - the free-seat cap must never be exceeded
  - a house holding stores must never be left with nobody in it

The last of those is here BECAUSE this mirror found it. On the first
run, houses of three or more emptied behind the goer on a fifth of
trips - everyone independently deciding to come, nobody left with a
larder or a fire to keep. Reading the code could not have shown that.
A house holding nothing may still all walk, and should: there is
nothing to mind.
"""
import io
import contextlib
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

# The equilibrium mirror has no main guard - importing runs its 120-day
# convergence. That is exactly what is wanted (real trust, real groups);
# its narration is not, so it is captured.
_quiet = io.StringIO()
with contextlib.redirect_stdout(_quiet):
    import equilibrium_test as eq


def fnv(text):
    """The live hash, byte for byte (SAO_Disposition.lua)."""
    v = 2166136261
    for ch in text:
        v = (v * 16777619 + ord(ch)) % 4294967296
    return (v % 1000) / 1000


def circle(i):
    h = fnv(f"{i}:circle")
    if h < 0.15:
        return "loner"
    if h < 0.50:
        return "band"
    return "house"


def circle_cap(i):
    return {"loner": 1, "band": 3}.get(circle(i), 999)


def nerve(i):
    return 0.15 + fnv(f"{i}:nerve") * 0.70


def houses():
    by_group = {}
    for member, g in eq.group.items():
        by_group.setdefault(g, []).append(member)
    return {g: sorted(m) for g, m in by_group.items() if len(m) >= 2}


def run(label, lesson_weight, needful_share, watch_share, seats=None,
        holds_stores=True):
    """One sweep. lesson_weight: 0.0 = day zero, nobody has learned
    anything; >0 = a lived-in county. Returns the tallies."""
    stats = {
        "trips": 0, "loners_taken": 0, "cap_violations": 0,
        "seat_violations": 0, "emptied": 0, "party_sizes": [],
        "left_behind": 0,
    }
    for g, members in houses().items():
        for goer in members:
            hearers = [m for m in members if m != goer]
            if not hearers:
                continue
            stats["trips"] += 1
            willing = []
            for h in hearers:
                # deterministic, reproducible stand-ins for state the
                # mirror does not simulate
                bound = (fnv(f"{h}:need") < needful_share)
                on_wall = (fnv(f"{h}:desig") < watch_share)
                solo = circle(h) == "loner"
                t = eq.trust[(h, goer)]
                bonded = t > 0.7 and eq.trust[(goer, h)] > 0.7
                pull = (t
                        + (0.3 if bonded else 0.0)
                        + 0.20 * (lesson_weight * fnv(f"{h}:worth"))
                        - 0.20 * (lesson_weight * fnv(f"{h}:careful"))
                        + 0.20 * (nerve(h) - 0.5))
                if not bound and not solo and not on_wall and pull > 0.55:
                    willing.append((h, pull))
            # [B19] The keenest go - ported with the live change.
            willing.sort(key=lambda w: (-w[1], w[0]))
            willing = [h for h, _ in willing]
            cap = circle_cap(goer)
            seat_bound = False
            if seats is not None:
                free = max(0, seats - 1)
                if free < cap:
                    cap, seat_bound = free, True
            # [B19] Somebody minds the place, when the house holds
            # anything worth minding.
            if holds_stores and len(hearers) >= 2:
                cap = min(cap, len(hearers) - 1)
            took = willing[:cap]
            stats["left_behind"] += max(0, len(willing) - cap)
            stats["party_sizes"].append(len(took))
            for h in took:
                if circle(h) == "loner":
                    stats["loners_taken"] += 1
            if len(took) > circle_cap(goer):
                stats["cap_violations"] += 1
            if seat_bound and len(took) > max(0, seats - 1):
                stats["seat_violations"] += 1
            if len(took) == len(members) - 1 and len(members) >= 3:
                stats["emptied"] += 1

    sizes = stats["party_sizes"]
    alone = sum(1 for s in sizes if s == 0)
    print(f"\n--- {label} ---")
    print(f"  trips simulated          {stats['trips']}")
    print(f"  went alone               {alone} "
          f"({100.0 * alone / max(1, len(sizes)):.0f}%)")
    print(f"  average company          {sum(sizes) / max(1, len(sizes)):.2f}")
    print(f"  largest company          {max(sizes) if sizes else 0}")
    print(f"  turned away (no room)    {stats['left_behind']}")
    print(f"  house emptied behind them {stats['emptied']} "
          f"({100.0 * stats['emptied'] / max(1, stats['trips']):.0f}% "
          f"of trips from houses of 3+)")
    return stats


print("The joining test ([B19]) - live gates, live hash, converged county")
print(f"county: {len(houses())} houses of 2+ out of {eq.N} people")

fails = []

a = run("day zero - no lessons, nothing stored yet, so nothing to mind",
        lesson_weight=0.0, needful_share=0.15, watch_share=0.20,
        holds_stores=False)
b = run("lived-in county - lessons weigh, the house holds stores",
        lesson_weight=1.0, needful_share=0.30, watch_share=0.20)
c = run("lived-in county, taking a 4-seat car",
        lesson_weight=1.0, needful_share=0.30, watch_share=0.20, seats=4)
d = run("lived-in county, taking a 2-seat pickup",
        lesson_weight=1.0, needful_share=0.30, watch_share=0.20, seats=2)

print("\nVERDICT:")
for name, s in (("day zero", a), ("lived-in", b),
                ("4-seat car", c), ("2-seat pickup", d)):
    for law, key in (("a loner was taken along", "loners_taken"),
                     ("the circle cap was exceeded", "cap_violations"),
                     ("the seat cap was exceeded", "seat_violations")):
        if s[key]:
            fails.append(f"{name}: {law} ({s[key]}x)")

print("  loners are never forced along:",
      "VIOLATED" if any("loner" in f for f in fails) else "held")
print("  the circle cap always binds:",
      "VIOLATED" if any("circle" in f for f in fails) else "held")
print("  free seats always bind:",
      "VIOLATED" if any("seat" in f for f in fails) else "held")

# [B19] A house that HOLDS something never empties; a house holding
# nothing may, and should - there is nothing to mind.
held = max(s["emptied"] / max(1, s["trips"]) for s in (b, c, d))
print(f"  a house with stores is never left empty:",
      "VIOLATED" if held > 0 else "held")
if held > 0:
    fails.append(f"a stocked house emptied ({100.0 * held:.0f}% of trips)")
bare = a["emptied"] / max(1, a["trips"])
print(f"  a house holding nothing may all walk: {100.0 * bare:.0f}% "
      "of day-zero trips (not a violation - nothing to mind)")

if fails:
    print("\nFAILURES:")
    for f in fails:
        print("  -", f)
    sys.exit(1)
print("\n[joining] all hard laws held")
