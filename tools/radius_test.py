#!/usr/bin/env python3
r"""[B33] The two radii are a hysteresis pair, and nothing enforces it.

`materializeBand` in SAO_Population.lua is ONE if/elseif chain:

    if     rec.knox                                  (L403)
    elseif not hasBody and d <= conf.materialize     (L408)  build a shell
    elseif hasBody     and d >  conf.hibernate       (L616)  tear it down

Guarded by hasBody / not hasBody, so a single tick fires at most one.
ACROSS ticks they alternate whenever

    hibernate < d <= materialize

because the tick that builds a shell makes `hasBody` true, which arms
the branch that tears it down, which makes `hasBody` false again. The
gap between the two radii is HYSTERESIS - the band where neither fires
and the world holds still. Invert the pair and the band becomes a
thrash zone instead.

The sandbox screen declares them independently:

    MaterializeRadius  integer  20..120   default 45
    HibernateRadius    integer  30..160   default 70

Nothing in Lua or Java clamps one against the other, so every pairing
in that rectangle is reachable from the options screen - including the
one a performance-minded player reaches for first: pull HibernateRadius
DOWN to hold fewer live survivors, leave MaterializeRadius alone.

This measures the reachable thrash volume, and validates against the
shipped defaults, which must be quiet.
"""
import sys

# The declared ranges, read off media/sandbox-options.txt.
MAT_MIN, MAT_MAX, MAT_DEF = 20, 120, 45
HIB_MIN, HIB_MAX, HIB_DEF = 30, 160, 70


def transitions(mat, hib, d, ticks=8):
    """Run the chain for one survivor standing still at distance d.

    Returns the number of shell build/teardown events. A settled world
    is 0 or 1 - one event to reach the right state, then quiet.
    """
    has_body = False
    events = 0
    for _ in range(ticks):
        # if rec.knox -> not modelled; no survivor here is foreign.
        if not has_body and d <= mat:
            has_body = True
            events += 1
        elif has_body and d > hib:
            has_body = False
            events += 1
    return events


def thrashes(mat, hib):
    """Distances at which this pairing never settles."""
    return [d for d in range(0, HIB_MAX + 20)
            if transitions(mat, hib, d) > 1]


def _live_constants():
    """Read [B33]'s reconciliation constants out of the Lua.

    Ported rules drift. These two numbers decide whether the fix
    holds, so they are parsed from the file that ships rather than
    copied into this one.
    """
    import pathlib
    import re
    src = (pathlib.Path(__file__).resolve().parent.parent
           / "mod" / "42.20" / "media" / "lua" / "client"
           / "SAO_Population.lua").read_text(encoding="utf-8",
                                             errors="ignore")
    gap = re.search(r"local MIN_GAP = (\d+)", src)
    floor = re.search(r"if mat < (\d+) then", src)
    if not gap or not floor:
        raise SystemExit("radius_test: cannot find [B33]'s constants "
                         "in SAO_Population.lua - the fix moved or "
                         "was removed, and this mirror is blind")
    return int(gap.group(1)), int(floor.group(1))


MIN_GAP, MAT_FLOOR = _live_constants()


def reconcile(mat, hib):
    """[B33]'s rule, as SAO_Population.cfg() applies it."""
    if hib < mat + MIN_GAP:
        mat = hib - MIN_GAP
        if mat < MAT_FLOOR:
            mat = MAT_FLOOR
            hib = mat + MIN_GAP
    return mat, hib


def main():
    print("=" * 68)
    print("CONTROL - the shipped defaults must be quiet at every distance")
    print("=" * 68)
    bad = thrashes(MAT_DEF, HIB_DEF)
    print(f"  materialize={MAT_DEF}  hibernate={HIB_DEF}")
    print(f"  distances that never settle: {len(bad)}")
    print(f"  hysteresis band (nothing happens): "
          f"{MAT_DEF + 1}..{HIB_DEF} tiles wide "
          f"= {HIB_DEF - MAT_DEF}")
    ok_default = not bad
    print(f"  quiet at defaults: {'YES' if ok_default else 'NO'}")

    print()
    print("=" * 68)
    print("CONTROL - an inverted pair MUST be detected, or this tool is")
    print("          measuring nothing")
    print("=" * 68)
    inv = thrashes(120, 30)
    print(f"  materialize=120 hibernate=30")
    print(f"  distances that never settle: {len(inv)}"
          f"  ({min(inv)}..{max(inv)} tiles)" if inv else "  none")
    ok_invert = bool(inv)
    print(f"  detected: {'YES' if ok_invert else 'NO'}")

    print()
    print("=" * 68)
    print("THE REACHABLE RECTANGLE - every pairing the screen allows")
    print("=" * 68)
    total = 0
    broken = 0
    worst = None
    for mat in range(MAT_MIN, MAT_MAX + 1):
        for hib in range(HIB_MIN, HIB_MAX + 1):
            total += 1
            t = thrashes(mat, hib)
            if t:
                broken += 1
                if worst is None or len(t) > worst[2]:
                    worst = (mat, hib, len(t))
    print(f"  pairings the options screen allows: {total}")
    print(f"  pairings that never settle:         {broken} "
          f"({100.0 * broken / total:.1f}%)")
    if worst:
        print(f"  widest thrash band: materialize={worst[0]} "
              f"hibernate={worst[1]} -> {worst[2]} tiles")

    print()
    print("=" * 68)
    print("THE LIKELY ONE - a player pulling HibernateRadius down for")
    print("                 performance, leaving MaterializeRadius alone")
    print("=" * 68)
    for hib in (HIB_MIN, 35, 40, HIB_DEF):
        t = thrashes(MAT_DEF, hib)
        band = f"{min(t)}..{max(t)}" if t else "-"
        print(f"  materialize={MAT_DEF} hibernate={hib:3}  "
              f"thrash tiles={len(t):3}  band={band}")

    print()
    print("=" * 68)
    print(f"AFTER [B33] - cfg() reconciles the pair "
          f"(MIN_GAP={MIN_GAP}, floor={MAT_FLOOR}, read from the Lua)")
    print("=" * 68)
    survived = []
    moved = 0
    for mat in range(MAT_MIN, MAT_MAX + 1):
        for hib in range(HIB_MIN, HIB_MAX + 1):
            m2, h2 = reconcile(mat, hib)
            if (m2, h2) != (mat, hib):
                moved += 1
            if thrashes(m2, h2):
                survived.append((mat, hib, m2, h2))
    print(f"  pairings reconciled:            {moved}/{total} "
          f"({100.0 * moved / total:.1f}%)")
    print(f"  pairings that STILL never settle: {len(survived)}")
    for mat, hib, m2, h2 in survived[:5]:
        print(f"      {mat}/{hib} -> {m2}/{h2}  STILL THRASHES")

    print("  the defaults are untouched: "
          f"{reconcile(MAT_DEF, HIB_DEF) == (MAT_DEF, HIB_DEF)}")
    print("  the likely one, reconciled: "
          f"{MAT_DEF}/{HIB_MIN} -> {reconcile(MAT_DEF, HIB_MIN)} "
          f"(hibernate honoured exactly, materialize follows it down)")

    print()
    print("VERDICT:")
    print(f"  defaults quiet?               {'YES' if ok_default else 'NO'}")
    print(f"  inversion detected?           {'YES' if ok_invert else 'NO'}")
    print(f"  broken before [B33]:          {broken}/{total}")
    print(f"  broken after  [B33]:          {len(survived)}/{total}")
    ok = ok_default and ok_invert
    if not ok:
        print("  INSTRUMENT FAILED ITS OWN CONTROLS")
        return 1
    if survived:
        print("  THE FIX DOES NOT COVER THE RECTANGLE")
        return 1
    if broken == 0:
        print("  the pre-fix sweep found nothing - this mirror is "
              "no longer measuring anything")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
