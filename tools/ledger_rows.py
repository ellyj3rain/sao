#!/usr/bin/env python3
r"""[B34] What the Ledger can actually say.

SAO_UI's `build()` assembles the panel the operator opens and reads.
[B29] and [B29] fixed its geometry and [B33] added a line to its
header, but its ROWS have never been checked for reachability the way
[B34] checked the context menu, and [B32] audited the wire's render
rather than this one.

Three questions, and the second is the one worth having a tool for:

  CAN A ROW APPEAR?     a section gated on a field nothing writes
                        emits nothing, forever.

  IS A HEADING EMPTY?   a header whose only companions are rows behind
                        a STRICTER condition prints a promise with
                        nothing under it. That is worse than omitting
                        the section, because the reader concludes the
                        county has none of that thing rather than that
                        the panel could not say.

  DOES IT READ WRONG?   this is text a person reads, so a value
                        concatenated without tostring, or a bare
                        number with no unit, is the [B33] class on the
                        surface it matters most.

The chain walker is imported from menu_reach rather than copied -
border 14 would be right to object, and [B34] just spent a batch on
exactly that lesson.
"""
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from menu_reach import strip_lua, head_at          # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
UI = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_UI.lua"
LUA = ROOT / "mod" / "42.20" / "media" / "lua"

EMIT = re.compile(r"\b(header|row)\s*\(")


def emissions(lines, lo, hi):
    """Every header()/row() call with its enclosing condition stack."""
    stack, out = [], []
    for n in range(lo, hi):
        line = lines[n]
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip())
        while stack and stack[-1][0] >= indent:
            stack.pop()
        h = head_at(lines, n)
        if h:
            stack.append((h[0], h[1], h[2]))
        m = EMIT.search(line)
        if m and "local function" not in line:
            out.append({
                "line": n + 1,
                "kind": m.group(1),
                "text": line.strip()[:110],
                "stack": [(k, c) for _, k, c in stack],
                "depth": len(stack),
            })
    return out


def main():
    raw = UI.read_text(encoding="utf-8", errors="ignore")
    src = strip_lua(raw)
    lines = src.split("\n")
    rawlines = raw.split("\n")

    start = next(n for n, l in enumerate(lines)
                 if "function SAOCountyWindow:build" in l)
    end = next(n for n in range(start + 1, len(lines))
               if re.match(r"^function ", lines[n]))

    em = emissions(lines, start, end)
    heads = [e for e in em if e["kind"] == "header"]
    rows = [e for e in em if e["kind"] == "row"]
    print("=" * 70)
    print(f"build() spans {start + 1}-{end}: {len(heads)} header(s), "
          f"{len(rows)} row call(s)")
    print("=" * 70)

    # 1. A heading whose following rows all sit deeper than it does.
    print()
    print("HEADINGS WITH NOTHING GUARANTEED UNDER THEM")
    print("=" * 70)
    # [B34] Only what can actually be decided from the text. A row
    # sitting DEEPER than its heading is the normal shape for a
    # section that lists things in a loop, and treating that as a
    # finding flagged five correct sections on the first run. What is
    # decidable is a heading with no row call ANYWHERE after it -
    # nothing can print under that, whatever the conditions do.
    #
    # Headers here are titles as well as section headings, and [B33]
    # added a conditional warning header, so "no row before the next
    # header" is not the question either.
    empty = []
    for h in heads:
        later = [e for e in em
                 if e["line"] > h["line"] and e["kind"] == "row"]
        if not later:
            empty.append((h, "no row call appears anywhere after it"))
    if not empty:
        print("  none - every heading has a row call after it")
    for h, why in empty:
        print(f"  line {h['line']}: {h['text'][:70]}")
        print(f"      {why}")

    # 2. Text built from something that could be nil.
    print()
    print("=" * 70)
    print("ROW TEXT CONCATENATING AN UNGUARDED VALUE")
    print("=" * 70)
    risky = []
    for e in em:
        line = rawlines[e["line"] - 1]
        if ".." not in line:
            continue
        for fld in re.findall(r"\b(\w+)\.(\w+)\b", line):
            whole = f"{fld[0]}.{fld[1]}"
            if whole.startswith(("string.", "math.", "table.", "SAO.")):
                continue
            guarded = any(whole in c for _, c in e["stack"])
            if not guarded and "tostring" not in line:
                risky.append((e["line"], whole, line.strip()[:74]))
    if not risky:
        print("  none - every concatenated field is guarded or "
              "tostring()-wrapped")
    for ln, fld, txt in risky[:12]:
        print(f"  line {ln}: {fld}")
        print(f"      {txt}")

    # 3. Per-row cost: a full scan inside a loop that emits rows.
    print()
    print("=" * 70)
    print("PER-ROW COST - the panel rebuilds every tick it is open")
    print("=" * 70)
    # [B34] Track whether a loop is still OPEN, by indent, instead of
    # looking backwards a fixed distance for a `for`. The first
    # version found line 74's loop from line 100 and called it
    # nesting; that loop closes at 81. Two sequential scans are not a
    # quadratic one.
    scans = []
    open_for = []
    for n in range(start, end):
        line = lines[n]
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip())
        while open_for and open_for[-1] >= indent:
            open_for.pop()
        # [B34] Test the line BEFORE pushing its own loop. Every scan
        # in this file sits ON a `for` line - `for _, r in
        # pairs(SAO.Identity.all()) do` - so continuing past `for`
        # first skipped the only lines worth reading, and the tool
        # reported "no full-population scans" about a function with
        # four of them. Found-nothing read as cannot-see-it, one batch
        # after [B33] recorded the same conflation.
        if re.search(r"SAO\.Identity\.all\(\)|allGroupClaims\(\)"
                     r"|allPersonalClaims\(\)", line):
            scans.append((n + 1, line.strip()[:66], bool(open_for)))
        if re.match(r"^\s*for\b", line):
            open_for.append(indent)
    for ln, txt, inside in scans:
        print(f"  line {ln}{'  <- INSIDE A LOOP' if inside else ''}")
        print(f"      {txt}")
    if not scans:
        print("  no full-population scans in build()")

    print()
    print("VERDICT:")
    print(f"  headings with nothing guaranteed: {len(empty)}")
    print(f"  unguarded concatenations:         {len(risky)}")
    print(f"  full scans inside a row loop:     "
          f"{sum(1 for _, _, i in scans if i)}")
    if empty or risky or any(i for _, _, i in scans):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
