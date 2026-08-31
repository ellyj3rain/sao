#!/usr/bin/env python3
r"""Border 46 - one question about witnessing, asked one way.

The county asks whether somebody WITNESSED a thing happening to another
person in three places - a killing (twice) and a fight - and each asked
it identically in shape: do I hold an **observed** belief of that
person, taken **recently**, from **close by**.

One question, spelled three times, with two different answers: ten tiles
for a killing, twelve for a fight, and nothing anywhere saying why.

[B41] found this exact shape - a docstring reading "within 3 tiles"
against a `<= 9.0` in the code, true only by coincidence. Here the
coincidence had already broken, and nobody could see it because there
was no name for the two spellings to disagree about. [B40] kept two
feud reaches apart deliberately and wrote the reason down; there was no
reason here, so the twelve joined the rule.

WHAT THIS HOLDS
---------------
  1. `WITNESS_REACH` and `WITNESS_FRESH` are declared.
  2. Every site that tests `seen.dist` reads the declared reach - no
     bare number, because a bare number is what the third spelling was.
  3. Every site that ages a `seen` belief for witnessing reads the
     declared window.
  4. Both names are actually USED. A constant declared and never read
     is a comment with a semicolon ([B41]), and it reads as governed
     while the literal sits elsewhere governing.

The wider sweep this came out of is recorded in [B43]: twenty-six
radius comparisons in the tree and exactly one - [B41]'s `MEET_RANGE` -
reading a declared reach. This border holds the group that is provably
one rule; the rest are measured and named in the batch record rather
than left as an unstated remainder.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CTL = (ROOT / "mod" / "42.20" / "media" / "lua" / "client"
       / "SAO_Controller.lua")

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from menu_reach import strip_lua                       # noqa: E402

NAMES = ("WITNESS_REACH", "WITNESS_FRESH")
BARE_DIST = re.compile(r"seen\.dist\s*<=\s*([0-9][\w.]*)")
BARE_FRESH = re.compile(r"tickCount\s*-\s*seen\.at\)\s*<=\s*([0-9][\w.]*)")


def main():
    faults = []
    print("=" * 74)
    print("ONE QUESTION ABOUT WITNESSING")
    print("=" * 74)

    src = strip_lua(CTL.read_text(encoding="utf-8", errors="ignore"),
                    strings=False)

    for name in NAMES:
        declared = re.search(r"^local %s\s*=\s*([\d.]+)" % name, src, re.M)
        uses = len(re.findall(r"\b%s\b" % name, src)) - (1 if declared else 0)
        print(f"  {name:<15} "
              f"{'declared ' + declared.group(1) if declared else 'NOT DECLARED'}"
              f", read {uses}x")
        if not declared:
            faults.append(
                f"{name} is not declared - the witnessing rule has gone "
                "back to being a number typed at each site, which is how "
                "ten and twelve came to disagree with nothing saying why")
        elif uses < 1:
            faults.append(
                f"{name} is declared and never read - a constant nobody "
                "uses is a comment with a semicolon ([B41]): it reads as "
                "governed while the literal sits elsewhere governing")

    bare_d = BARE_DIST.findall(src)
    bare_f = BARE_FRESH.findall(src)
    print(f"  bare distance bounds:  {len(bare_d)}  {bare_d}")
    print(f"  bare freshness bounds: {len(bare_f)}  {bare_f}")
    for v in bare_d:
        faults.append(
            f"a witnessing site bounds `seen.dist` with the bare number "
            f"{v} - that is the third spelling all over again, and the "
            "next one to differ will differ silently")
    for v in bare_f:
        faults.append(
            f"a witnessing site ages a belief with the bare number {v} "
            "instead of the declared window")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  46) witness reach: the county asks one question about "
          "witnessing, in one")
    print("      place, with one answer")
    return 0


if __name__ == "__main__":
    sys.exit(main())
