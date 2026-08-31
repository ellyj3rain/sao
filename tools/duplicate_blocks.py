#!/usr/bin/env python3
r"""Border 14 ([B31]) - a second copy of a shared definition.

Four separate fixes this session turned on the same pattern: ONE
DEFINITION, two callers.

    [B20] tryCry, "copying the formula would be the same drift"
    [B27] hearTheWire, so what crosses the wire cannot diverge
    [B28] isForeignPerson, so the scanner and the bridge agree
    [B30] deploy copies the canonical LICENSE rather than duplicating

Nothing mechanically stopped anyone re-forking one of those, and
[B31] found the cost already paid: three copies of the hearth search,
two of the drink filter, and FOUR of the floor-ring sweep that had
drifted far enough apart that only two still matched.

## The threshold was measured, not chosen

A duplicate-block border needs a minimum length, and guessing it is
how a border becomes noise. So it was measured. On the tree as [B31]
found it:

    window 15: 10 repeated blocks, longest duplication 20 lines

A threshold above that would have been tuned to the mess rather than
derived. Instead the mess was fixed, and the tree now holds ZERO
duplicated blocks at fifteen normalised lines. Fifteen is therefore
not a tolerance - it is the line below which this codebase does not
repeat itself, and the border's baseline is zero.

## What normalisation means here

Comments and blank lines are dropped and whitespace is collapsed, so
reformatting a copy does not hide it. Two blocks are the same when
their normalised text matches exactly - no fuzzy similarity, because a
border that guesses is a border that cries wolf, and one that cries
wolf gets ignored.

## What this does NOT catch

Copies shorter than fifteen lines, and copies that have already
drifted - which is precisely how [B31]'s floor-ring sweep escaped
notice for so long. This border stops NEW duplication from being
introduced; it cannot recover a definition that was already forked
and then edited apart.
"""
import collections
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
WINDOW = 15
LABEL = "14) duplicated blocks of %d+ lines:" % WINDOW


def normalised(path):
    """(original line number, collapsed text) for every code line."""
    out = []
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return out
    for number, raw in enumerate(text.splitlines(), 1):
        stripped = raw.strip()
        if not stripped:
            continue
        if stripped.startswith(("--", "//", "*", "/*")):
            continue
        out.append((number, re.sub(r"\s+", " ", stripped)))
    return out


def sources():
    return sorted(list((ROOT / "mod/42.20/media/lua").rglob("*.lua"))
                  + list((ROOT / "java/src").rglob("*.java")))


def main():
    files = sources()
    if not files:
        print(LABEL, "SKIPPED (no sources found)")
        return 0

    seen = collections.defaultdict(list)
    for path in files:
        lines = normalised(path)
        for i in range(len(lines) - WINDOW + 1):
            block = "\n".join(text for _, text in lines[i:i + WINDOW])
            seen[block].append((path.name, lines[i][0]))

    # Collapse overlapping windows. Every consecutive window of one
    # duplication is its own match, so a single forked function
    # reports as dozens of findings unless runs are merged - and a
    # border that prints dozens of lines for one defect is a border
    # people learn to scroll past.
    #
    # Consecutive windows share a constant offset between their two
    # locations, so a run is (file_a, file_b, line_a - line_b) with
    # contiguous starts.
    pairs = {}
    for block, where in seen.items():
        if len(where) < 2:
            continue
        sites = sorted(set(where))
        for a in range(len(sites)):
            for b in range(a + 1, len(sites)):
                (fa, la), (fb, lb) = sites[a], sites[b]
                pairs.setdefault((fa, fb, la - lb), []).append((la, lb))

    regions = []
    for (fa, fb, _), starts in pairs.items():
        starts.sort()
        run_a, run_b, prev = starts[0][0], starts[0][1], starts[0][0]
        length = 1
        for la, lb in starts[1:]:
            if la == prev + 1:
                length += 1
                prev = la
                continue
            regions.append((fa, run_a, fb, run_b, length + WINDOW - 1))
            run_a, run_b, prev, length = la, lb, la, 1
        regions.append((fa, run_a, fb, run_b, length + WINDOW - 1))

    if not regions:
        print(LABEL, "none")
        return 0

    print(LABEL)
    for fa, la, fb, lb, span in sorted(regions, key=lambda r: -r[4]):
        print(f"     {span} lines: {fa}:{la} and {fb}:{lb}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
