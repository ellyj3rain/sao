#!/usr/bin/env python3
r"""Border 40 - an order the player can give is an order that can land.

[B42] added "go back to your own place", which sends a companion to
the home on their own record. That order has a precondition the county
itself can take away: [B7] clears `homeX`, `homeY` and `homeZ` for
every member of a house that gives up its ground - *"they have no home
until they find one"* - and [B42] made that moment recordable. A
survivor whose house abandoned has nowhere to be sent.

An order offered in that state does nothing when clicked. Nothing
errors, nothing is logged, and the player is left to conclude the
survivor ignored them - which is the same shape as every defect this
session found: a surface promising something the machinery underneath
cannot deliver, failing silently.

THE RULE
--------
Every menu option whose handler reads a record field to aim itself must
be OFFERED behind a test of that same field. Not a nil-check inside the
handler - by then the option is already on the menu and the player has
already chosen it. The gate and the aim have to read the same thing.

The fields are found from the handler, not listed here: whatever
`rec.<field>` the callback passes to an order function is what the
offer must have tested.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
HARNESS = LUA / "client" / "SAO_Harness.lua"

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from menu_reach import strip_lua                       # noqa: E402

# The calls that send somebody somewhere.
ORDERS = re.compile(r"(?:Controller|Ctl)\.(order\w+)\s*\(")
OPTION = re.compile(r'addOption\(\s*("(?:[^"\\]|\\.)*"|[\w.]+)')


def blocks(src):
    """Each addOption and the callback body that belongs to it."""
    lines = src.split("\n")
    for i, line in enumerate(lines):
        m = OPTION.search(line)
        if not m:
            continue
        depth, body, started = 0, [], False
        for j in range(i, min(i + 40, len(lines))):
            body.append(lines[j])
            opens = len(re.findall(r"\bfunction\b", lines[j]))
            closes = len(re.findall(r"\bend\b", lines[j]))
            if opens:
                started = True
            depth += opens - closes
            if started and depth <= 0 and j > i:
                break
        yield i + 1, m.group(1), "\n".join(body)


def main():
    faults = []
    print("=" * 74)
    print("AN ORDER OFFERED IS AN ORDER THAT CAN LAND")
    print("=" * 74)

    src = strip_lua(HARNESS.read_text(encoding="utf-8", errors="ignore"),
                    strings=False)
    lines = src.split("\n")

    aimed = 0
    for line_no, label, body in blocks(src):
        if not ORDERS.search(body):
            continue
        # The record fields the handler aims with.
        fields = set(re.findall(r"\b\w*[Rr]ec\w*\.(\w+)\b", body))
        fields = {f for f in fields
                  if f.startswith("home") or f.endswith("X")
                  or f.endswith("Y") or f.endswith("Z")}
        # A field read with a default is not a precondition - the
        # fallback IS the handling. `homeRec.homeZ or 0` aims at ground
        # level when the record has no floor, which lands fine; it is
        # `homeX` going missing that leaves the order with nowhere to
        # go. Requiring a gate on the defaulted one asks the menu to
        # guard against a case the code already answers.
        fields = {f for f in fields
                  if not re.search(r"\.%s\s+or\b" % re.escape(f), body)}
        if not fields:
            continue
        aimed += 1
        # Was the OFFER guarded on them? Look back from the addOption
        # to the start of its enclosing block.
        before = "\n".join(lines[max(0, line_no - 15):line_no - 1])
        for field in sorted(fields):
            if re.search(r"\.%s\b" % re.escape(field), before):
                continue
            faults.append(
                f"SAO_Harness.lua:{line_no} offers {label} and aims it "
                f"with `rec.{field}`, and nothing before the offer tests "
                f"`{field}` - when the county clears it the option is "
                "still on the menu, the click does nothing, and the "
                "player is left to think they were ignored")

    print(f"  options that aim with a record field: {aimed}")
    print(f"  offered without testing it:           {len(faults)}")

    if aimed == 0:
        faults.append(
            "no option was found aiming an order with a record field - "
            "this border's reading of how the menu aims is out of date, "
            "and it would pass on a tree it cannot see")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  40) order landing: every order the menu offers is tested "
          "against the field")
    print("      it aims with, so an order that cannot land is not "
          "offered")
    return 0


if __name__ == "__main__":
    sys.exit(main())
