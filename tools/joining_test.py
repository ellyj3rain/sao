#!/usr/bin/env python3
"""The joining test ([B19], mirrored per the same-batch doctrine).

[B19] wrote a new social law - who goes along when someone announces a
venture - and a social law that has never been run outside the game is
an assertion. This ports the LIVE gates exactly:

    bound   = their own pressure answer == "need"
    solo    = circle(id) == "loner"
    onWall  = designation == "watch" and kind ~= "warpath"
    noFight = kind == "warpath" and the hearer's own envelope refuses
              that fight ([C53]; SAO_Command.envelope, the same
              question [C37] asks before an order to engage)
    office  = OFFICE[officeOf(goer, hearer)] - OFFICE.none, so 0 under
              a peer, 0.25 under a second or a proven hand, 0.40 under
              a leader ([C53]; SAO_Command's own ladder, no number
              invented at this site)
    pull    = trust(hearer, goer)
              + office
              + 0.3 if bonded
              + 0.20 * weight(hearer, "people-are-worth-it")
              - 0.20 * weight(hearer, "trust-carefully")
              + 0.20 * (nerve(hearer) - 0.5)
    join    = not bound and not solo and not onWall and not noFight
              and pull > 0.55
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


# [C53] The office the caller holds, in SAO_Command's own currency.
# The mirror derives the leader the way the live Standing does - the
# member with the highest trust-sum from the others, which is the sum
# the election runs on - so this is the same fact, not a stand-in. The
# second is the next-highest and only in a house of three or more,
# which is `secondOf`'s own rule.
OFFICE_LEADER = 0.80
OFFICE_SECOND = 0.65
OFFICE_NONE = 0.40


def offices(members):
    """(leader, second) of one house, by trust-sum."""
    if not members:
        return None, None
    ranked = sorted(members,
                    key=lambda m: (-sum(eq.trust[(o, m)]
                                        for o in members if o != m), m))
    leader = ranked[0]
    second = ranked[1] if len(members) >= 3 else None
    return leader, second


def office_bonus(goer, leader, second):
    if goer == leader:
        return OFFICE_LEADER - OFFICE_NONE
    if second is not None and goer == second:
        return OFFICE_SECOND - OFFICE_NONE
    return 0.0


def run(label, lesson_weight, needful_share, watch_share, seats=None,
        holds_stores=True, warpath=False, refuse_share=0.0, trust_scale=1.0):
    """One sweep. lesson_weight: 0.0 = day zero, nobody has learned
    anything; >0 = a lived-in county. warpath: the trip is a raid, so
    [C53]'s envelope gate applies and refuse_share stands in for the
    hearers whose own envelope refuses that fight. trust_scale: a house
    that formed recently has none of the converged county's trust yet
    (F-056), and this scales it - a stand-in, like needful_share, for
    state this mirror does not simulate. Returns the tallies."""
    stats = {
        "trips": 0, "loners_taken": 0, "cap_violations": 0,
        "seat_violations": 0, "emptied": 0, "party_sizes": [],
        "left_behind": 0, "refusers_taken": 0, "office_carried": 0,
        "office_cost": 0, "invites": 0,
    }
    for g, members in houses().items():
        leader, second = offices(members)
        for goer in members:
            hearers = [m for m in members if m != goer]
            if not hearers:
                continue
            stats["trips"] += 1
            stats["invites"] += len(hearers)
            office = office_bonus(goer, leader, second)
            willing = []
            for h in hearers:
                # deterministic, reproducible stand-ins for state the
                # mirror does not simulate
                bound = (fnv(f"{h}:need") < needful_share)
                on_wall = (fnv(f"{h}:desig") < watch_share)
                solo = circle(h) == "loner"
                # [C53] Nobody who will not take the fight is taken
                # on a raid. A stand-in for the envelope, like `bound`
                # and `on_wall` above: the mirror does not carry arms
                # or fear, and what is being held here is that the gate
                # is asked at all and only on a warpath.
                no_fight = warpath and fnv(f"{h}:fight") < refuse_share
                t = eq.trust[(h, goer)] * trust_scale
                bonded = (t > 0.7
                          and eq.trust[(goer, h)] * trust_scale > 0.7)
                pull = (t
                        + office                       # [C53]
                        + (0.3 if bonded else 0.0)
                        + 0.20 * (lesson_weight * fnv(f"{h}:worth"))
                        - 0.20 * (lesson_weight * fnv(f"{h}:careful"))
                        + 0.20 * (nerve(h) - 0.5))
                if (not bound and not solo and not on_wall
                        and not no_fight and pull > 0.55):
                    willing.append((h, pull))
                    # [C53] Would they have come if the caller held no
                    # office? The same hearer, the same trip, one term
                    # removed - which is the only way to see what the
                    # term does without house size and the goer's own
                    # circle cap standing in front of it.
                    if office > 0 and pull - office <= 0.55:
                        stats["office_carried"] += 1
                elif (not bound and not solo and not on_wall
                        and not no_fight and office < 0):
                    stats["office_cost"] += 1
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
                if warpath and fnv(f"{h}:fight") < refuse_share:
                    stats["refusers_taken"] += 1
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
# [C53] The raid, where a third of the house will not take that fight.
e = run("lived-in county, a warpath - a third refuse the fight",
        lesson_weight=1.0, needful_share=0.30, watch_share=0.20,
        warpath=True, refuse_share=0.33)
# [C53] A house that formed recently. F-056 measured the converged
# county's pull at a median of 1.28 against a threshold of 0.55, so
# nothing in the pull can decide anything there; a young house is
# where willingness is actually a question, and it is the house a
# day-zero county is made of.
f = run("a house formed recently - trust has not converged",
        lesson_weight=0.0, needful_share=0.15, watch_share=0.20,
        holds_stores=False, trust_scale=0.40)

print("\nVERDICT:")
for name, s in (("day zero", a), ("lived-in", b),
                ("4-seat car", c), ("2-seat pickup", d),
                ("warpath", e), ("young house", f)):
    for law, key in (("a loner was taken along", "loners_taken"),
                     ("the circle cap was exceeded", "cap_violations"),
                     ("the seat cap was exceeded", "seat_violations"),
                     ("somebody who refuses the fight was taken on a "
                      "raid", "refusers_taken")):
        if s[key]:
            fails.append(f"{name}: {law} ({s[key]}x)")

print("  loners are never forced along:",
      "VIOLATED" if any("loner" in f for f in fails) else "held")
print("  the circle cap always binds:",
      "VIOLATED" if any("circle" in f for f in fails) else "held")
print("  free seats always bind:",
      "VIOLATED" if any("seat" in f for f in fails) else "held")
# [C53] Nobody is persuaded into a fight they would not take.
print("  a raid never takes somebody who refuses the fight:",
      "VIOLATED" if any("refuses the fight" in f for f in fails) else "held")
# [C53] And the office pulls. Party sizes across houses cannot show
# this - a leader is not in the same house, with the same hearers and
# the same circle cap, as the peer being compared with - so the term
# is measured on the one hearer it applies to: with the office and
# without it, everything else held.
carried = sum(s["office_carried"] for s in (a, b, c, d, e, f))
invites = sum(s["invites"] for s in (a, b, c, d, e, f))
cost = sum(s["office_cost"] for s in (a, b, c, d, e, f))
print(f"  the office carries people who would not otherwise come: "
      f"{carried} of {invites} invitations across all six sweeps "
      f"({f['office_carried']} of them in the young house, where the "
      f"threshold is the one that binds - F-056)")
if carried == 0:
    fails.append("no invitation in the whole county turned on the office "
                 "term, so it changes nothing and is not being read")
if cost:
    fails.append(f"the office kept {cost} hearer(s) home; it is a bonus "
                 "above a peer's and can never be negative")

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
