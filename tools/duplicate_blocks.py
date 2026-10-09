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
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
WINDOW = 15
LABEL = "14) duplicated blocks of %d+ lines:" % WINDOW


def normalised(path, inventory=None):
    """(original line number, collapsed text) for every code line."""
    out = []
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return out
    from menu_reach import strip_lua
    text = strip_lua(text, strings=False)
    if inventory is not None and inventory.row(path):
        # The importer contributes a verified two-statement availability
        # adapter. Count original mechanic duplication independently of it.
        lines = text.splitlines()
        row = inventory.row(path)
        if len(lines) >= 3 and lines[1].strip() == 'require "SAO_SourceIntegration"' and lines[2].strip() == 'if not SAO.SourceIntegration.active("' + row['sourceId'] + '") then return end':
            lines[1] = lines[2] = ''
        text = '\n'.join(lines)
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


def qualified_source_repetition(path, line, block, inventory, baseline):
    """A recorded repetition in an exact qualified source adaptation.

    Ported native API/namespace repairs can change an original window. Their
    accepted current occurrences retain a separate, byte-pinned baseline.
    A new file, changed revision or extra occurrence receives no admission.
    """
    from scanner_inventory import sha
    relative = pathlib.Path(path).relative_to(ROOT).as_posix()
    record = baseline.get('integratedRepetitions', {}).get(relative)
    if not record or sha(path.read_bytes()) != record['sha256']:
        return False
    row = inventory.row(path)
    if row:
        if record['sourceIds'] != [row['sourceId']] or record['sourceSha256'] != row['sourceSha256']:
            return False
    else:
        consumer = baseline['consumers'].get(relative)
        if not consumer or consumer['sha256'] != record['sha256'] or consumer['sourceIds'] != record['sourceIds']:
            return False
    return record['windows'].get(str(line)) == sha(block.encode('utf-8'))


def main():
    from scanner_inventory import current
    inventory = current()
    baseline = json.loads((ROOT / 'tools/source_scanner_consumers.json').read_text(encoding='utf-8'))
    files = sources()
    if not files:
        print(LABEL, "SKIPPED (no sources found)")
        return 0

    seen = collections.defaultdict(list)
    for path in files:
        lines = normalised(path, inventory)
        for i in range(len(lines) - WINDOW + 1):
            block = "\n".join(text for _, text in lines[i:i + WINDOW])
            seen[block].append((path, lines[i][0]))

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
        # Both sides must independently preserve this exact block in their
        # sealed original source. An imported path grants no generic waiver.
        if all(inventory.original_block(path, block, lambda p: normalised(p, inventory), WINDOW)
               or qualified_source_repetition(path, line, block, inventory, baseline)
               for path, line in where):
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
        print(f"     {span} lines: {fa.relative_to(ROOT)}:{la} and {fb.relative_to(ROOT)}:{lb}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
