#!/usr/bin/env python3
r"""Border 32 - a mirror nobody runs is a claim nobody checks.

This project writes a mirror per batch and cites it in the batch
record as though writing it were the same as running it. It is not.

Measured at [B41]: **thirty-three mirrors in `tools/`, eleven in the
gate.** Twenty-two had never been invoked by anything, among them

  * `key_domain_test`, where [B37] and [B40] both put standing laws
  * `save_compat_test`, whose own record ([B36]) says *"this makes it
    a gate"* - it did not, and every "0 dropped" reported for twenty-six
    batches was a number somebody went and fetched by hand

And the cost was already paid. `belief_life_test` reads
`PLACE_SIGHT` out of `SAO_Perception`. [B40] exported that constant
from a file-level local to `P.PLACE_SIGHT` so both halves of the county
would read one reach - and blinded the mirror in the same edit. The
mirror said so, in its own output, to nobody, for as long as it stayed
out of the gate.

WHAT THIS REQUIRES
------------------
1. Every `tools/*_test.py` is invoked by `check.sh`, or declared here
   as a one-off with the batch that wrote it and why it does not
   stand. A file that is neither is a border nobody agreed to drop.

2. Every mirror has a path that can FAIL. [B36]'s second clause at
   fleet scale: a mirror whose every path returns zero is a REPORT. It
   may be worth reading and it is not a check, and gating it buys
   runtime in exchange for a guaranteed pass.

3. Every one-off declaration names a file that exists. An exemption
   that outlives its subject is how a list stops describing anything.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOOLS = ROOT / "tools"
CHECK = TOOLS / "check.sh"

# Mirrors deliberately outside the gate, each with the batch that
# wrote it and why it does not stand. Empty is the correct state; an
# entry here is a decision, not a default.
ONE_OFF = {}

FAILS = re.compile(r"return 1\b|sys\.exit\(1\)|else 1\b|raise SystemExit")


def invoked():
    """Every mirror check.sh actually runs, both spellings.

    Explicit `"$PY" tools/x.py` calls, and the bare names inside the
    `for mirror in ...` list, which is how [B41] gated twenty-two at
    once. A checker that saw only one spelling would report the other
    twenty-two as ungated the moment they were fixed.
    """
    src = CHECK.read_text(encoding="utf-8", errors="ignore")
    named = set(re.findall(r"tools/([a-z_0-9]+)\.py", src))
    loop = re.search(r"for mirror in \\?\n(.*?)\ndo", src, re.S)
    if loop:
        named |= set(re.findall(r"([a-z_0-9]+_test)", loop.group(1)))
    return named


def main():
    runs = invoked()
    mirrors = sorted(p.name for p in TOOLS.glob("*_test.py"))

    print("=" * 74)
    print(f"MIRRORS AND THE GATE - {len(mirrors)} mirrors")
    print("=" * 74)

    faults, gated, declared, reports = [], 0, 0, []
    for name in mirrors:
        stem = name[:-3]
        src = (TOOLS / name).read_text(encoding="utf-8", errors="ignore")
        can_fail = bool(FAILS.search(src))
        if not can_fail:
            reports.append(name)
            faults.append(
                f"{name} has no path that can fail - it is a report, and "
                "a report in the gate is runtime bought for a guaranteed "
                "pass. Give it a verdict or declare it one-off.")
        if stem in runs:
            gated += 1
        elif name in ONE_OFF:
            declared += 1
        else:
            faults.append(
                f"{name} is not invoked by check.sh and is not declared "
                "one-off - a border nobody agreed to drop")

    print(f"  invoked by check.sh : {gated}")
    print(f"  declared one-off    : {declared}")
    print(f"  neither             : {len(mirrors) - gated - declared}")
    print(f"  cannot fail         : {len(reports)}  "
          f"{', '.join(reports) or 'none'}")

    for name, why in sorted(ONE_OFF.items()):
        exists = (TOOLS / name).exists()
        print(f"  {'yes' if exists else 'NO '}  one-off: {name} - {why}")
        if not exists:
            faults.append(f"{name} is declared one-off and does not "
                          "exist - the exemption outlived its subject")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  32) gate reach: all {len(mirrors)} mirrors run, every one "
          "able to fail")
    return 0


if __name__ == "__main__":
    sys.exit(main())
