#!/usr/bin/env python3
r"""Border 41 - who somebody was is this county's own judgement to make.

DR-009 ratified how the two systems meet: *"where the two systems
collide SAO's reading overrides on SAO's side."* [A20] then let a
foreign profile's archetype overwrite `rec.occupation` through a
thirteen-entry table written by hand - its own comment said "mapped by
closest life-shape" - and contradicted that decision for thirty-odd
batches without anyone noticing, because the contradiction was in a
file and the decision was in a ledger.

The overwrite was the visible half. The other half was worse.

`rec.occupationPresumed` is this project's honesty about its own
guessing. `Census.describe` renders *"carries themselves like a nurse"*
while it is set and *"was a nurse in Riverside when it started"* once
it is not; `Census.originNote` refuses to invent a beginning for a
presumed trade at all ([A22] - *"we do not put a beginning in the
mouth of someone whose past we only guessed at"*). [A20] cleared it.
So it did not import a fact, it **laundered our own guess into one**.

WHAT THIS HOLDS
---------------
  1. `rec.occupation` is written in the census module and nowhere else.
  2. `rec.occupationPresumed` is written in the census module and
     nowhere else.
  3. Nothing anywhere CLEARS the presumption. A guess does not become
     knowledge by having its warning label removed, and if some future
     path really does learn a trade it must say how it learned it
     ([B39]) rather than quietly unsetting the flag.

Writers are found by parsing, and comparisons are not writes - `==`
after a field name is the trap that made an earlier sweep in this
session report fifty findings, every one of them a comparison.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
# The module whose job is deciding who somebody was.
CENSUS_OWNS = {"SAO_History.lua", "SAO_Census.lua"}
GUARDED = ("occupation", "occupationPresumed")

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from menu_reach import strip_lua                       # noqa: E402


def writers(field):
    """Every `<something>.field = ...` that is an assignment, not a test."""
    pattern = re.compile(
        r"(?<![=~<>!])\b\w+\.%s\s*=(?!=)\s*([^\n]*)" % re.escape(field))
    found = []
    for path in sorted(LUA.rglob("*.lua")):
        code = strip_lua(path.read_text(encoding="utf-8", errors="ignore"),
                         strings=False)
        for n, line in enumerate(code.split("\n"), 1):
            m = pattern.search(line)
            if m:
                found.append((path.name, n, m.group(1).strip()[:48]))
    return found


def main():
    faults = []
    print("=" * 74)
    print("WHO SOMEBODY WAS, AND WHO GETS TO SAY")
    print("=" * 74)

    for field in GUARDED:
        sites = writers(field)
        # A field of the same name on a DIFFERENT table (telemetry's
        # output row) is not this record's field.
        sites = [s for s in sites if not s[0].startswith("SAO_Telemetry")]
        where = ", ".join(f"{n}:{i}" for n, i, _ in sites) or "NOBODY"
        print(f"  {field:<20} written at {where}")
        if not sites:
            faults.append(
                f"nothing writes `{field}` any more - the census has "
                "stopped deciding it, and this border is measuring a "
                "tree that no longer exists")
        for name, line, rhs in sites:
            if name in CENSUS_OWNS:
                continue
            # The rule is about DIRECTION, not location, for the
            # presumption flag. Marking a trade as guessed is never a
            # lie - anyone may do it, and [B42]'s migration has to,
            # because H.generate returns early for records that already
            # have a past and cannot reach the worlds [A20] already
            # ran in. Clearing the flag is the defect, and that is
            # caught below regardless of who does it.
            if field == "occupationPresumed" and re.match(r"^true\b", rhs):
                continue
            faults.append(
                f"{name}:{line} writes `{field}` and is not the census "
                f"({' or '.join(sorted(CENSUS_OWNS))}). DR-009: where "
                "the two systems collide SAO's reading overrides on "
                "SAO's side - who somebody was is decided here or it "
                "is not decided here")

    # 3. The warning label is never removed.
    cleared = [(n, i, r) for n, i, r in writers("occupationPresumed")
               if re.match(r"^(nil|false)\b", r)]
    print(f"  presumption cleared:  {len(cleared)} site(s)")
    for name, line, rhs in cleared:
        faults.append(
            f"{name}:{line} clears `occupationPresumed` (= {rhs}) - a "
            "guess does not become knowledge by losing its warning "
            "label. Census.describe starts asserting \"was a\" instead of "
            "\"carries themselves like\", and originNote starts inventing "
            "a beginning ([A22]). If a trade is genuinely learned, it "
            "has to say how ([B39])")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  41) census authority: this county decides who somebody was, "
          "and says plainly")
    print("      when it is guessing")
    return 0


if __name__ == "__main__":
    sys.exit(main())
