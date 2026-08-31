#!/usr/bin/env python3
r"""The between-time test ([B32]) - who ever gets the slot?

DR-011's law is that the between-time is never nothing: a resting
survivor always has an honest answer to what they are doing. Five
branches compete for that one slot, in this order:

    1. no designation      keeps hands busy      (no cooldown)
    2. instrument          [B21] the porch       nextTuneAt     2400
    3. designation + perk  [B22] study           nextStudyAt    2400
    4. reading             [B22] the book        nextPageAt     3000
    5. keepsake            [B22] what they carry nextKeepsakeAt 3600
    6. discipline > 0.5    tends their kit       (no cooldown)
    7. otherwise           a short rest          (no cooldown)

Branches 6 and 7 are why DR-011 holds: whatever else is spent, there
is always an answer, and `agent.pressure` is written unconditionally
after the chain. A first draft of this mirror lacked them and reported
60% of slots as "nothing" - against the one law that says the
between-time is never nothing. Modelling error, not a finding.

[B32] found that three of those four cooldowns were tested INSIDE the
branch body rather than in the guard, so the branch was taken even
when spent and everything below it starved permanently. An
instrument-carrier could never study, never read, never handle a
keepsake.

That was found by reading. Nothing offline would have caught it, which
is precisely the [B24] condition this project keeps paying for. So
this prices the slot: across a county, how often does each activity
actually win, and can anyone who QUALIFIES for an activity never
reach it?

## One thing it does not model, stated

Live, `idleRec.designation` can be nil - [B21] revokes designations
and a newcomer may hold none - and branch 1 then takes the slot with
no cooldown at all. This assigns every survivor a designation by
work_test's class prior, so branch 1 never fires here and the
undesignated case is UNMODELLED rather than measured. Said plainly
because an unmodelled branch reads as a branch that never wins.

## What this cannot price

The world. Whether a survivor is actually resting rather than fleeing,
eating or fighting; whether the place yielded an instrument or a book
at all; whether a cook has a hearth to work. All of that reads real
bodies in a real cell. This models the CHAIN, given a population that
carries what identity_test says it carries.

So it reports reachability and share of slot, not frequency in play.

## The control

A mirror that cannot reproduce the defect it was written for is
decoration ([B24]). This one models the pre-[B32] guards too, and the
verdict FAILS if that variant does not show instrument-carriers
never studying.
"""
import contextlib
import io
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

_quiet = io.StringIO()
with contextlib.redirect_stdout(_quiet):
    import equilibrium_test as eq
    import identity_test as ident

# Live values, read off SAO_Controller.lua rather than remembered.
REFRESH = 600
COOLDOWN = {"instrument": 2400, "study": 2400,
            "reading": 3000, "keepsake": 3600}

# Census.JOB_PERK - only these designations ride a perk, so only these
# can study. quartermaster and leads have no perk and never can.
JOB_PERK = {"forager", "medic", "watch", "scout", "cook"}

# work_test's class prior, which is where designations come from.
DESIG_BY_CLASS = {"hardened": "watch", "outdoors": "scout",
                  "carer": "medic", "settled": "quartermaster",
                  "trades": "forager"}


def designation_of(i):
    """[B32] The deal loops over company MEMBERS and its class chain
    ends in `or "forager"`, so every member always gets one. A person
    with no company is undesignated - "solo lives stay undesignated,
    that is a different day" - and returns None here."""
    g = eq.group.get(i)
    if g is None:
        return None
    if eq.leader_of(g) == i:
        return "leads"
    return DESIG_BY_CLASS[eq.CLASSES[i]]


def carries(i):
    """What identity_test says this person carries."""
    t = ident.traits_of(i)
    return {name: ok(t) for name, _cat, ok in ident.GATES}


def run_chain(i, desig, has, slots, *, guards_have_cooldowns,
              solo_first=False):
    """Walk the between-time `slots` times and tally who wins.

    `guards_have_cooldowns=False` is the pre-[B32] code: the branch is
    entered on state alone and the cooldown is checked inside, so the
    chain never falls through."""
    ready = {k: 0 for k in COOLDOWN}
    won = {"hands busy": 0, "instrument": 0, "study": 0,
           "reading": 0, "keepsake": 0,
           "tends kit": 0, "short rest": 0}
    tidy = ident.traits_of(i)["discipline"] > 0.5
    can_study = desig != "leads" and desig in JOB_PERK

    for n in range(slots):
        tick = n * REFRESH
        # [B32] Pre-fix, the undesignated branch was FIRST and had
        # no cooldown, so it took the slot every time and nothing
        # below it could ever run.
        if solo_first and not desig:
            won["hands busy"] += 1
            continue
        picked = None
        for name, present in (("instrument", has["instrument"]),
                              ("study", can_study),
                              ("reading", has["reading"]),
                              ("keepsake", has["keepsake"])):
            if not present:
                continue
            if guards_have_cooldowns and tick < ready[name]:
                continue
            picked = name
            break
        if picked is None:
            # [B32] The tail: DR-011's guarantee, not a dead slot.
            # [B32] The solo flavour sits ahead of the generic two.
            if not desig:
                won["hands busy"] += 1
            else:
                won["tends kit" if tidy else "short rest"] += 1
            continue
        # Pre-[B32]: the branch is taken, but only DOES anything when
        # its own cooldown has expired. Either way nothing below runs.
        if tick >= ready[picked]:
            ready[picked] = tick + COOLDOWN[picked]
            won[picked] += 1
        else:
            if not desig:
                won["hands busy"] += 1
            else:
                won["tends kit" if tidy else "short rest"] += 1
    return won


def survey(*, guards_have_cooldowns, solo_first=False, slots=200):
    totals = {"hands busy": 0, "instrument": 0, "study": 0,
              "reading": 0, "keepsake": 0,
              "tends kit": 0, "short rest": 0}
    starved = {"instrument": [], "study": [], "reading": [], "keepsake": []}
    for i in range(eq.N):
        desig = designation_of(i)
        has = carries(i)
        won = run_chain(i, desig, has, slots,
                        guards_have_cooldowns=guards_have_cooldowns,
                        solo_first=solo_first)
        for k, v in won.items():
            totals[k] += v
        can_study = desig != "leads" and desig in JOB_PERK
        qualifies = {"instrument": has["instrument"], "study": can_study,
                     "reading": has["reading"], "keepsake": has["keepsake"]}
        for act, q in qualifies.items():
            if q and won[act] == 0:
                starved[act].append(i)
    return totals, starved


def main():
    print("The between-time test ([B32]) - who ever gets the slot?")
    print(f"county: {eq.N} people, {REFRESH}-tick refresh, 200 slots each")

    totals, starved = survey(guards_have_cooldowns=True)
    grand = sum(totals.values()) or 1
    print("\n--- share of the slot, as the chain stands now ---")
    for k in ("hands busy", "instrument", "study", "reading",
              "keepsake", "tends kit", "short rest"):
        print(f"  {k:12} {totals[k]:6}  ({100.0 * totals[k] / grand:5.1f}%)")

    print("\n--- who QUALIFIES for an activity and never reaches it ---")
    for act in ("instrument", "study", "reading", "keepsake"):
        who = starved[act]
        print(f"  {act:12} {len(who):3} starved"
              + (f"   e.g. {who[:6]}" if who else ""))

    # The control: the pre-[B32] chain must show the defect.
    pre, pre_starved = survey(guards_have_cooldowns=False)
    caught = len(pre_starved["study"]) > len(starved["study"])
    print("\n--- the control: does this reproduce [B32]'s defect? ---")
    print(f"  pre-[B32] starved from study: {len(pre_starved['study'])}")
    print(f"  post-[B32] starved from study: {len(starved['study'])}")
    print(f"  reproduces the defect: {caught}")

    solo = [i for i in range(eq.N) if designation_of(i) is None]
    pre89, pre89_starved = survey(guards_have_cooldowns=True,
                                  solo_first=True)
    solo_caught = (len(pre89_starved["instrument"])
                   > len(starved["instrument"]))
    print("\n--- the second control: does it reproduce [B32]'s? ---")
    print(f"  undesignated (solo lives) in the county: {len(solo)}/{eq.N}")
    print(f"  pre-[B32] starved from instrument: "
          f"{len(pre89_starved['instrument'])}")
    print(f"  post-[B32] starved from instrument: "
          f"{len(starved['instrument'])}")
    print(f"  reproduces the defect: {solo_caught}")

    print("\nVERDICT:")
    fail = []
    if solo and not solo_caught:
        fail.append("this mirror cannot reproduce the defect [B32] fixed")
    if not caught:
        fail.append("this mirror cannot reproduce the defect [B32] fixed, "
                    "so a clean result from it means nothing")
    for act in ("instrument", "study", "reading", "keepsake"):
        if starved[act]:
            fail.append(f"{len(starved[act])} who qualify for `{act}` can "
                        "never reach it - the [B32] shape")
    if fail:
        for f in fail:
            print("  FAIL:", f)
        return 1
    print("  every activity is reachable by everyone who qualifies for it")
    print("  NOT priced here: whether anyone is actually resting, and "
          "whether the place yielded the object at all.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
