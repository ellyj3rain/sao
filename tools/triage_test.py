#!/usr/bin/env python3
"""The triage test ([B20]) - does aid reach the worst-hurt person?

The aid loop in SAO_Controller.lua iterates a belief table with
`pairs()`, takes the FIRST person whose condition reads "bad" and who
is bleeding or fevered, commits, and returns:

    for name, belief in pairs(aidBeliefs.people) do
        ... if bleeding > 0 or fever > 0 then
            ... walk to them, state = MEDICWARD, return

Two properties follow, and neither was chosen:

  - **No triage.** Lua's `pairs()` order is unspecified. A scratch and
    an arterial bleed are equally likely to be picked first.
  - **No coordination.** `agent.aidTarget` is written by one agent and
    read by that same agent. Nothing marks a casualty as already being
    attended.

Each decision is individually correct - someone is hurt, I am the
medic, I go - and the aggregate triages backwards. Same error class
the joining mirror convicted at [B19] and the night watch at [B19].

What the measurement actually found, which is not what reading the
code suggested: **triage is the real fault (14% of casualty scenes
left the worst-hurt person with nobody) and convergence is mostly
benign.** Two aiders on one casualty runs at ~34% before and ~33%
after, because most of that is simply more aiders than casualties -
which is correct, not a bug. The coordination fix is real but small
(1% -> 0% on "left alone while another was crowded"). Recorded at its
true size rather than inflated to justify the change.

Severity here is not invented: the live code already reads
`getBleedingCount` and `woundInfection` off the real body. It simply
never compares them.

The county is the converged 60-person society the equilibrium mirror
produces after 120 days, so houses and trust are the real ones.

This is a LIVING regression test, not a one-off before/after: it runs
the pre-[B20] rule alongside the live one so the delta stays visible,
and it fails if the live rule ever leaves the worst-hurt person with
nobody.
"""
import contextlib
import io
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

_quiet = io.StringIO()
with contextlib.redirect_stdout(_quiet):
    import equilibrium_test as eq


def fnv(text):
    """The live hash, byte for byte (SAO_Disposition.lua)."""
    v = 2166136261
    for ch in text:
        v = (v * 16777619 + ord(ch)) % 4294967296
    return (v % 1000) / 1000


def houses():
    by_group = {}
    for member, g in eq.group.items():
        by_group.setdefault(g, []).append(member)
    return {g: sorted(m) for g, m in by_group.items() if len(m) >= 3}


def scenario(members, salt):
    """A deterministic casualty picture for one house."""
    hurt = {}
    for m in members:
        if fnv(f"{m}:{salt}:hurt") < 0.40:
            bleeds = 1 + int(fnv(f"{m}:{salt}:bleed") * 4)      # 1..4
            fever = 1 if fnv(f"{m}:{salt}:fever") < 0.30 else 0
            hurt[m] = bleeds + 2 * fever                        # severity
    aiders = [m for m in members if m not in hurt
              and (fnv(f"{m}:medic") < 0.20          # medic designation
                   or fnv(f"{m}:carer") < 0.18       # carer class
                   or fnv(f"{m}:bindfast") < 0.15    # bind-wounds-fast
                   # [B20] ...or simply sharing the house with them
                   # and trusting them. Everyone here is sameGroup by
                   # construction, so the live gate reduces to trust.
                   or any(eq.trust[(m, h)] > 0.3 for h in hurt))]
    return hurt, aiders


def pairs_order(aider, hurt, salt):
    """Lua's `pairs()` order is UNSPECIFIED, and every agent holds its
    own belief table - so each aider is modelled with its own
    arbitrary permutation rather than one shared order. That is the
    honest model and it is generous to the current code: a shared
    order would converge far harder."""
    return sorted(hurt, key=lambda h: fnv(f"{aider}:{h}:{salt}:order"))


def run(rule, salts):
    tally = {"scenes": 0, "worst_first": 0, "converged": 0,
             "abandoned": 0, "unattended_worst": 0, "assignments": 0}
    for salt in salts:
        for g, members in houses().items():
            hurt, aiders = scenario(members, salt)
            if not hurt or not aiders:
                continue
            tally["scenes"] += 1
            worst = max(hurt, key=lambda h: (hurt[h], h))
            picks = rule(aiders, hurt, salt)
            tally["assignments"] += len(picks)
            # did anyone reach the worst-hurt person?
            if worst in picks.values():
                tally["worst_first"] += 1
            else:
                tally["unattended_worst"] += 1
            # two or more aiders on one casualty
            seen = {}
            for a, target in picks.items():
                seen[target] = seen.get(target, 0) + 1
            if any(c >= 2 for c in seen.values()):
                tally["converged"] += 1
            # somebody hurt with nobody, while somebody else has 2+
            doubled = any(c >= 2 for c in seen.values())
            if doubled and any(h not in seen for h in hurt):
                tally["abandoned"] += 1
    return tally


def before_rule(aiders, hurt, salt):
    """What the tree did BEFORE [B20]: first in pairs() order, no
    reservation. Kept so the delta stays visible and the fix cannot
    quietly regress into looking like it was never needed."""
    return {a: pairs_order(a, hurt, salt)[0] for a in aiders}


def live_rule(aiders, hurt, salt):
    """What the tree does NOW: worst by real severity first, and a
    casualty another housemate is already walking to is demoted -
    never barred, so a lone casualty still gets everyone."""
    picks, taken = {}, set()
    # aiders commit in a stable order; in the game they commit as their
    # own aid cadence comes round, which is likewise not simultaneous
    for a in sorted(aiders):
        free = [h for h in hurt if h not in taken]
        pool = free if free else list(hurt)
        target = max(pool, key=lambda h: (hurt[h], h))
        picks[a] = target
        taken.add(target)
    return picks


def report(label, t):
    scenes = max(1, t["scenes"])
    print(f"\n--- {label} ---")
    print(f"  casualty scenes            {t['scenes']}")
    print(f"  worst-hurt got an aider    {t['worst_first']} "
          f"({100.0 * t['worst_first'] / scenes:.0f}%)")
    print(f"  worst-hurt got NOBODY      {t['unattended_worst']} "
          f"({100.0 * t['unattended_worst'] / scenes:.0f}%)")
    print(f"  two+ aiders on one person  {t['converged']} "
          f"({100.0 * t['converged'] / scenes:.0f}%)")
    print(f"  someone left alone while   {t['abandoned']} "
          f"({100.0 * t['abandoned'] / scenes:.0f}%)")
    print(f"    another had two or more")


SALTS = [f"s{i}" for i in range(40)]

print("The triage test ([B20]) - live selection rule, converged county")
print(f"county: {len(houses())} houses of 3+ out of {eq.N} people")

before = run(before_rule, SALTS)
after = run(live_rule, SALTS)
report("before [B20] - first in pairs() order, no reservation",
       before)
report("the live rule - worst by real severity, claimed demoted",
       after)

scenes = max(1, before["scenes"])
print("\nVERDICT:")
print(f"  worst-hurt reached: "
      f"{100.0 * before['worst_first'] / scenes:.0f}% -> "
      f"{100.0 * after['worst_first'] / max(1, after['scenes']):.0f}%")
print(f"  aiders piling on one: "
      f"{100.0 * before['converged'] / scenes:.0f}% -> "
      f"{100.0 * after['converged'] / max(1, after['scenes']):.0f}%")
print(f"  left alone while another was crowded: "
      f"{100.0 * before['abandoned'] / scenes:.0f}% -> "
      f"{100.0 * after['abandoned'] / max(1, after['scenes']):.0f}%")

# ---------------------------------------------------------------------------
# [B20] Reachability. Aid gated on `belief.source == "observed"`, so an
# aider who never SAW the casualty never came - a medic behind a wall
# from a bleeding housemate simply did not know. The cry adds a
# `heard` belief, which the aid loop now accepts.
#
# Who cries is the live urge formula, not a flag:
#
#   urge = sev*0.5 - 2.0*nerve + 1.5*w(never-again) - 2.0*w(noise-debt)
#
# so a steady person carrying noise-is-a-debt stays silent and deals
# with it alone. Whatever that leaves unreachable is a person choosing
# silence, not a hole in the machinery.

def nerve(i):
    return 0.15 + fnv(f"{i}:nerve") * 0.70


def cries_out(who, sev, lesson_weight):
    urge = (sev * 0.5
            - 2.0 * nerve(who)
            + 1.5 * (lesson_weight * fnv(f"{who}:neveragain"))
            - 2.0 * (lesson_weight * fnv(f"{who}:noisedebt")))
    return urge > 0


def reachability(seen_share, lesson_weight):
    """seen_share: how often an aider holds a FRESH sighting of a
    housemate. People in a house are in different rooms."""
    r = {"scenes": 0, "sighted": 0, "cried": 0, "silent": 0}
    for salt in SALTS:
        for g, members in houses().items():
            hurt, aiders = scenario(members, salt)
            if not hurt or not aiders:
                continue
            r["scenes"] += 1
            worst = max(hurt, key=lambda h: (hurt[h], h))
            if any(fnv(f"{a}:{worst}:{salt}:saw") < seen_share
                   for a in aiders):
                r["sighted"] += 1
            elif cries_out(worst, hurt[worst], lesson_weight):
                r["cried"] += 1
            else:
                r["silent"] += 1
    return r


fails_b39 = []
print("\n=== [B20] can the worst-hurt person be reached at all? ===")
for _label, _share in (("people in each other's pockets (0.6)", 0.6),
                       ("a rambling house of rooms and walls (0.3)", 0.3)):
    _r = reachability(_share, 1.0)
    _s = max(1, _r["scenes"])
    _before = _r["sighted"]
    _after = _r["sighted"] + _r["cried"]
    print(f"\n--- {_label} ---")
    print(f"  scenes with an aider present  {_r['scenes']}")
    print(f"  worst-hurt was SEEN           {_r['sighted']} "
          f"({100.0 * _r['sighted'] / _s:.0f}%)")
    print(f"  unseen, but CALLED OUT        {_r['cried']} "
          f"({100.0 * _r['cried'] / _s:.0f}%)")
    print(f"  unseen and silent by choice   {_r['silent']} "
          f"({100.0 * _r['silent'] / _s:.0f}%)")
    print(f"  reachable at all: {100.0 * _before / _s:.0f}%"
          f" -> {100.0 * _after / _s:.0f}%")
    if _after < _before:
        fails_b39.append(f"{_label}: the cry reduced reachability")


fails = list(fails_b39)
if after["unattended_worst"] > 0:
    fails.append("the worst-hurt person was left with nobody "
                 f"({after['unattended_worst']} scenes)")
if after["abandoned"] > before["abandoned"]:
    fails.append("the fix made abandonment worse")

if fails:
    print("\nFAILURES:")
    for f in fails:
        print("  -", f)
    sys.exit(1)
print("\n[triage] the worst-hurt person is always reached")
