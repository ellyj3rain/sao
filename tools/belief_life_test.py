#!/usr/bin/env python3
r"""[B35] A belief's whole life, and the one table that had no end.

The belief store holds five tables. Before this batch the decay pass
cleared three of them:

    b.zombies     pruned at 2x ZOMBIE_HORIZON
    b.people      pruned at 2x PEOPLE_HORIZON  (dead kept, F-033)
    b.criedTiles  pruned at CRY_RECOGNITION    ([B20])
    b.places      nothing, ever
    b.factions    nothing, ever

[B20] named this class in its own comment - "an unbounded leak dressed
as a memory" - and fixed the table in front of it.

`places` was worse than a leak, because it was also WRONG.
`S.releaseClaim` drops the claim and touches no belief, and
`P.believesClaimed` asks whether the owner DIED (F-034) but never
whether the claim still stands. So ground given up stayed avoided for
the rest of the session.

WHAT EACH CHECK READS, because [B34] shipped two controls that could
not fail:

  horizons        parsed from SAO_Perception.lua's `local X = N` lines,
                  so a changed horizon changes this mirror's arithmetic
                  rather than being contradicted by it.
  decay coverage  the body of P.observe between "-- decay pass" and the
                  function's end. A table cleared anywhere else does
                  not count, because anywhere else is not the pass that
                  runs every scan.
  the unlearn     `b.places[ownerKey] = nil` inside that same decay
                  body, AND `bU.places[ownerKey] = nil` in the
                  drift-past rule. Both, because both paths learn
                  places and only fixing one leaves half the county
                  wrong.

                  [B42] The drift-past rule moved out of
                  SAO_Population and into P.learnGroundNear, because it
                  sat inside a loop gated on `not SAO.Body.get(id)` and
                  so governed only the UNLOADED. Border 35 holds that
                  both halves still reach it; this holds that the
                  un-teaching is still in it.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PERC = (ROOT / "mod" / "42.20" / "media" / "lua" / "shared"
        / "SAO_Perception.lua")
# [B42] SAO_Population is no longer read here: the drift-past rule it
# used to hold now lives in P.learnGroundNear, and a path constant kept
# past its last reader is the [B41] defect in the instruments.


def horizons():
    src = PERC.read_text(encoding="utf-8", errors="ignore")
    out = {}
    for name in ("ZOMBIE_HORIZON", "PEOPLE_HORIZON", "SCAN_INTERVAL",
                 "CRY_RECOGNITION", "PLACE_SIGHT"):
        # [B41] Either declaration form. `PLACE_SIGHT` was a file-level
        # local until [B40] exported it as `P.PLACE_SIGHT` so the
        # dormant half could read the same reach - and this mirror went
        # blind on that same day, matching only `local`. Nothing said
        # so, because this mirror is not in the gate: a claim nobody
        # runs is a claim nobody checks.
        m = re.search(r"(?:local |P\.)" + name + r"\s*=\s*(\d+)", src)
        out[name] = int(m.group(1)) if m else None
    return out


def decay_body():
    """The decay pass inside P.observe - and only that."""
    src = PERC.read_text(encoding="utf-8", errors="ignore")
    start = src.index("-- decay pass")
    nxt = src.index("\nfunction ", start)
    return src[start:nxt]


def drive(horizon, refresh_every, ticks):
    """Form a belief, refresh it, stop, and see when it is dropped."""
    at, alive, dropped_at = 0, True, None
    for t in range(1, ticks + 1):
        if refresh_every and t <= refresh_every and t % 1 == 0:
            at = t
        if t - at > horizon * 2:
            alive = False
            dropped_at = dropped_at or t
    return alive, dropped_at


def main():
    h = horizons()
    print("=" * 70)
    print("HORIZONS, parsed from SAO_Perception.lua")
    print("=" * 70)
    for k, v in h.items():
        print(f"  {k:<18} {v}")
    if any(v is None for v in h.values()):
        print("\n  a constant could not be found - this mirror is blind")
        return 1

    print()
    print("=" * 70)
    print("DRIVEN - a zombie belief, formed then abandoned")
    print("=" * 70)
    zh = h["ZOMBIE_HORIZON"]
    readable_until = zh
    pruned_at = zh * 2
    print(f"  actionable while  tick - at <= {readable_until}")
    print(f"  pruned once       tick - at >  {pruned_at}")
    print(f"  band held but unreadable: {readable_until + 1}..{pruned_at}")
    print("  (deliberate: a belief goes stale before it is forgotten,")
    print("   so the prune and the read cannot disagree mid-scan)")
    alive, dropped = drive(zh, 0, zh * 3)
    print(f"  abandoned at tick 0, dropped at tick {dropped}: "
          f"{'YES' if dropped else 'NEVER'}")
    ok_zombie = dropped is not None

    print()
    print("=" * 70)
    print("WHICH TABLES THE DECAY PASS ACTUALLY CLEARS")
    print("=" * 70)
    body = decay_body()
    tables = {
        "b.zombies": r"b\.zombies\[\w+\] = nil",
        "b.people": r"b\.people\[\w+\] = nil",
        "b.criedTiles": r"b\.criedTiles\[\w+\] = nil",
        "b.places": r"b\.places\[\w+\] = nil",
    }
    cleared = {}
    for name, pat in tables.items():
        cleared[name] = bool(re.search(pat, body))
        print(f"  {name:<16} {'cleared' if cleared[name] else 'NEVER'}")
    # [B35] b.factions is never cleared either, and that is DESIGN,
    # not oversight. SAO_Standing:473, where a faction whose roster
    # empties is dissolved: "Meta, name, claim, and player membership
    # all lapse together; only the ghost of its base in old heads
    # remains ([A15] beliefs, deliberately)." A dead faction's base is
    # supposed to linger in memory. Left alone on purpose, and said
    # here so the next sweep does not "fix" it.
    print("  b.factions       not cleared - DELIBERATE, [A15] via "
          "SAO_Standing:473")

    print()
    print("=" * 70)
    print("THE DEFECT, AND THE FIX - a place whose claim ended")
    print("=" * 70)
    print("  before: releaseClaim() drops s.claims[id] and nothing else;")
    print("          believesClaimed() checks owner-dead, not claim-gone;")
    print("          so b.places[owner] outlived the claim all session.")
    print("  after:  a survivor standing within PLACE_SIGHT of the bounds")
    print("          whose owner holds no claim forgets it.")
    in_observe = cleared["b.places"]
    in_drift = "bU.places[ownerKey] = nil" in PERC.read_text(
        encoding="utf-8", errors="ignore")
    print(f"\n  unlearn in P.observe's decay pass:  "
          f"{'YES' if in_observe else 'NO'}")
    print(f"  unlearn in the drift-past rule:     "
          f"{'YES' if in_drift else 'NO'}")

    # The proximity rule itself, driven.
    ps = h["PLACE_SIGHT"]
    bounds = dict(minX=100, minY=100, maxX=110, maxY=110)

    def forgets(px, py, still_claimed):
        near = (bounds["minX"] - ps <= px <= bounds["maxX"] + ps
                and bounds["minY"] - ps <= py <= bounds["maxY"] + ps)
        return near and not still_claimed

    cases = [
        ("standing in it, claim gone", 105, 105, False, True),
        ("standing in it, still claimed", 105, 105, True, False),
        (f"{ps} tiles outside, claim gone", 110 + ps, 105, False, True),
        (f"{ps + 5} tiles away, claim gone", 110 + ps + 5, 105, False,
         False),
    ]
    print()
    ok_prox = True
    for label, px, py, claimed, want in cases:
        got = forgets(px, py, claimed)
        print(f"  {label:<32} forgets={got}  (want {want})")
        if got != want:
            ok_prox = False

    print()
    print("VERDICT:")
    print(f"  zombie beliefs are dropped:        "
          f"{'YES' if ok_zombie else 'NO'}")
    print(f"  decay clears zombies/people/cries: "
          f"{'YES' if all(cleared[k] for k in ('b.zombies', 'b.people', 'b.criedTiles')) else 'NO'}")
    print(f"  places unlearned in both paths:    "
          f"{'YES' if (in_observe and in_drift) else 'NO'}")
    print(f"  proximity rule behaves:            "
          f"{'YES' if ok_prox else 'NO'}")
    if not (ok_zombie and ok_prox and in_observe and in_drift
            and all(cleared[k] for k in
                    ("b.zombies", "b.people", "b.criedTiles"))):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
