#!/usr/bin/env python3
r"""Border 125 - every prevalence figure is traceable to a stated source
([C52]).

"A figure without a source does not ship" has been this repository's
rule for the county's epidemiology since [C32], and until now it was a
habit rather than a mechanism. It held: every row in
SAO_Conditions.PREVALENCE and SAO_Habits.PREVALENCE carries its source
in the comment above it. But nothing checked that the CONSTANT matches
the figure the comment claims, and nothing stopped a row from sitting
at zero without saying why - which is how psychosis and insomnia sat
undrawn for two batches with the note buried in the file.

This border reads both tables and holds four things per row.

  * A comment above it, naming a year (19xx or 20xx) or pointing
    explicitly at the table the row above cited.
  * At least one numeric figure in that comment.
  * A zero only where the comment says in so many words that no figure
    was read. The count of zero rows is printed either way, so a
    silent zero cannot hide in a table of forty numbers.
  * The constant derivable from the comment's own figures by one of
    the derivations the file already uses, each named in the row when
    it is used:
      - a percentage, times a hundred;
      - a rate per thousand, times ten;
      - two percentages SUMMED (the row says "summed");
      - a RANGE, "X to Y percent" (the constant falls inside it);
      - a MIDPOINT of two figures (the row says "midpoint"), to a
        tenth of a percentage point.
    A banded row is held to this band by band.

A row whose number cannot be reached that way is a finding, not a
style note: it means the constant and the citation have come apart,
and the citation is the only reason to believe the constant.

An optional argv[1] points the checker at another tree root, which is
how its control runs.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua" / "shared"
TABLES = (("SAO_Conditions.lua", "Cn.PREVALENCE"),
          ("SAO_Habits.lua", "Hb.PREVALENCE"))
CHECK = ROOT / "tools" / "check.sh"

# A tenth of a percentage point, for the rows that take a midpoint of
# two published figures and round it.
TOLERANCE = 10

NO_FIGURE = re.compile(r"no\s+(?:primary\s+)?figure", re.I)
# Rows that continue from the citation above them say so, and both
# tables already had a phrasing for it before this border existed.
SAME_TABLE = re.compile(r"the same (?:table|report|survey|paper)", re.I)


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""


def table_body(text, name):
    start = text.find(name + " = {")
    if start < 0:
        return None
    i = text.index("{", start)
    depth, j = 0, i
    while j < len(text):
        if text[j] == "{":
            depth += 1
        elif text[j] == "}":
            depth -= 1
            if depth == 0:
                return text[i + 1:j]
        j += 1
    return None


def rows(body):
    """(key, [per10k...], comment) for each row, comments accumulated."""
    out, comment, pending = [], [], None
    for line in body.split("\n"):
        stripped = line.strip()
        if stripped.startswith("--"):
            if pending:
                out.append(pending)
                pending, comment = None, []
            comment.append(stripped.lstrip("- ").rstrip())
            continue
        m = re.match(r"(\w+)\s*=\s*\{(.*)$", stripped)
        if m:
            if pending:
                out.append(pending)
            pending = [m.group(1),
                       [int(v) for v in re.findall(r"per10k\s*=\s*(\d+)",
                                                   m.group(2))],
                       " ".join(comment)]
            comment = []
        elif pending and stripped:
            pending[1] += [int(v) for v in
                           re.findall(r"per10k\s*=\s*(\d+)", stripped)]
    if pending:
        out.append(pending)
    return out


def reachable(value, comment):
    """Can this constant be reached from the comment's own numbers?"""
    figures = [float(f) for f in re.findall(r"(\d+(?:\.\d+)?)", comment)]
    if not figures:
        return False, "no figure in the comment"
    for f in figures:
        if abs(f * 100 - value) < 0.5:
            return True, "a percentage"
        if abs(f * 10 - value) < 0.5:
            return True, "a rate per thousand"
    ranged = re.search(r"(\d+(?:\.\d+)?)\s*to\s*(\d+(?:\.\d+)?)\s*percent",
                       comment, re.I)
    if ranged:
        lo, hi = (float(ranged.group(1)) * 100, float(ranged.group(2)) * 100)
        if lo <= value <= hi:
            return True, "inside a stated range"
    if re.search(r"\bsummed\b", comment, re.I):
        for i, a in enumerate(figures):
            for b in figures[i + 1:]:
                if abs((a + b) * 100 - value) < 0.5:
                    return True, "two percentages summed"
    if re.search(r"\bmidpoint\b", comment, re.I):
        for i, a in enumerate(figures):
            for b in figures[i + 1:]:
                if abs((a + b) / 2 * 100 - value) <= TOLERANCE:
                    return True, "a midpoint, rounded"
    return False, "no derivation reaches it"


def main():
    faults = []
    print("=" * 74)
    print("EVERY PREVALENCE FIGURE IS TRACEABLE TO A STATED SOURCE")
    print("=" * 74)
    total, zeros, checked = 0, 0, 0
    for name, table in TABLES:
        path = LUA / name
        body = table_body(read(path), table)
        if body is None:
            faults.append("%s has no %s table" % (name, table))
            continue
        found = rows(body)
        if not found:
            faults.append("%s: %s parsed to no rows" % (name, table))
            continue
        print("\n  %s (%s), %d rows" % (name, table, len(found)))
        for key, values, comment in found:
            total += 1
            if not values:
                faults.append("%s: %s declares no per10k at all" % (name, key))
                continue
            has_year = re.search(r"\b(?:19|20)\d\d\b", comment)
            if not (has_year or SAME_TABLE.search(comment)):
                faults.append("%s: %s names no year and does not point at "
                              "another row's table - the figure has no source"
                              % (name, key))
            if all(v == 0 for v in values):
                zeros += 1
                if not NO_FIGURE.search(comment):
                    faults.append("%s: %s is zero and the comment does not say "
                                  "no figure was read. A zero draws nobody, so "
                                  "the mechanism is dead and nothing says so"
                                  % (name, key))
                print("      %-11s ZERO - %s" % (key, "declared unsourced"))
                continue
            hows = []
            for v in values:
                ok, how = reachable(v, comment)
                checked += 1
                if not ok:
                    faults.append("%s: %s declares per10k=%d and %s from its "
                                  "own comment - the constant and the citation "
                                  "have come apart" % (name, key, v, how))
                hows.append(how if ok else "UNREACHED")
            uniq = sorted(set(hows))
            print("      %-11s %s <- %s"
                  % (key, "/".join(str(v) for v in values), ", ".join(uniq)))

    print()
    print("     %d rows, %d figures checked, %d declared unsourced"
          % (total, checked, zeros))
    if total < 15:
        faults.append("only %d rows were found across both tables; the parser "
                      "is not reading them" % total)

    seams = {
        "the gate runs this border":
            "tools/prevalence_sourced_test.py" in read(CHECK),
    }
    print()
    for k, v in seams.items():
        print(f"  {'yes' if v else 'NO '}  {k}")
        if not v:
            faults.append(k)

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print("  FAULT: " + f)
        return 1
    print("  125) prevalence sourced: %d figures across %d rows, every one "
          "reachable from the source its own comment cites, and %d row(s) "
          "declared unsourced out loud" % (checked, total, zeros))
    return 0


if __name__ == "__main__":
    sys.exit(main())
