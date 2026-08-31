#!/usr/bin/env python3
r"""[B34] Trades that start and never finish.

SAO_Exchange is where the county transacts: food, drink, smokes, aid,
debt. A trade is a TWO-SIDED act with a queued action in the middle,
which is where [B33]'s class (two tests produced by different code
paths that must agree) and [B34]'s class (a queued action silently
dropped) could bite at once.

The dangerous shape is not a trade that cannot start. It is one that
starts, transfers, and then cannot finish - because the first leg has
already moved an item by the time the second leg fails. A survivor who
gives food and receives nothing, with nothing recorded, gives again
next tick and every tick after.

Two things are checked, both against the SHIPPED Lua rather than a
model of it - [B34]'s lesson, which [B34] proved has to be relearned:

  SEQUENCED LEGS      two transfers where the second is conditional on
                      the first. The first has already happened, so a
                      failure of the second MUST have a recovery
                      branch - a debt, a reversal, or at minimum a
                      cooldown so it does not repeat immediately.

  EFFECT BEFORE PROOF standing adjusted, debt settled or a cooldown
                      set before the transfer it is paying for is
                      known to have been queued. [B34] found ordering
                      matters wherever a guard opens once; a trade has
                      the same property.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
XCHG = (ROOT / "mod" / "42.20" / "media" / "lua" / "client"
        / "SAO_Exchange.lua")

# A leg of a trade: something that moves goods between two bodies.
LEG = re.compile(r"SAO\.Needs\.(share\w+|aidWound)\s*\(")
# An effect that assumes the trade happened.
EFFECT = re.compile(r"SAO\.Standing\.(adjustTrust|addDebt|settleDebt)"
                    r"|next\w*At\s*=")
# [B34] A recovery branch has to RECOVER something. The first
# version accepted the mere presence of `elseif <name> then`, so
# `elseif false then` - a branch that can never run - counted as
# handling the half-trade, and the control that was supposed to prove
# the detector works instead proved it did not. A recovery is a debt
# recorded, a debt settled, or at minimum a cooldown set so the
# half-trade does not repeat every tick.
RECOVERY = re.compile(r"addDebt|settleDebt|next\w*At\s*=")


def _elseif_body(lines, after_line):
    """The body of the first `elseif` following a trade's second leg.

    That branch is where "the first leg moved goods and the second did
    not" has to be answered. Bounded by the next `elseif`, `else` or
    `end` at the same indent, so the success branch above it and the
    code below it are both excluded.
    """
    start = None
    indent = 0
    for n in range(after_line, min(after_line + 30, len(lines))):
        m = re.match(r"^(\s*)elseif\b", lines[n])
        if m:
            start = n + 1
            indent = len(m.group(1))
            break
    if start is None:
        return ""
    out = []
    for n in range(start, len(lines)):
        line = lines[n]
        if not line.strip():
            continue
        m = re.match(r"^(\s*)(elseif|else|end)\b", line)
        if m and len(m.group(1)) <= indent:
            break
        out.append(line)
    return "\n".join(out)


def main():
    src = XCHG.read_text(encoding="utf-8", errors="ignore")
    lines = src.split("\n")

    legs = [(n + 1, LEG.search(l).group(1), l.strip()[:74])
            for n, l in enumerate(lines) if LEG.search(l)]
    print("=" * 70)
    print(f"{len(legs)} trade leg(s) in SAO_Exchange")
    print("=" * 70)
    by_kind = {}
    for _, kind, _ in legs:
        by_kind[kind] = by_kind.get(kind, 0) + 1
    for k in sorted(by_kind):
        print(f"  {k:<22} {by_kind[k]}")

    # Sequenced legs: a leg whose result is gated on a previous leg's
    # result, within a short window.
    print()
    print("=" * 70)
    print("SEQUENCED LEGS - the first has already moved goods")
    print("=" * 70)
    seq, unprotected = [], []
    for i, (ln, kind, text) in enumerate(legs):
        prev = [p for p in legs if 0 < ln - p[0] <= 4]
        if not prev:
            continue
        pln, pkind, _ = prev[-1]
        # [B34] `or` is an ALTERNATIVE, not a sequence. In
        # `shareFoodWith(...) or shareDrinkWith(...)` the second leg
        # runs only when the first gave nothing, so no goods have
        # moved and there is nothing to half-complete. Reading
        # adjacency as dependency called that a sequenced trade and
        # then congratulated it on a recovery branch it does not need.
        joiner = "\n".join(lines[pln - 1:ln])
        if re.search(r"\bor\b\s*$|^\s*or\b", joiner, re.M):
            continue
        # [B34] Search the RECOVERY BRANCH, not a window around the
        # trade. A 22-line window from the first leg swallows the
        # SUCCESS branch too, and its cooldown satisfied the pattern -
        # so the detector answered "handled" for a trade whose
        # half-completion branch had been emptied. Two controls in a
        # row passed against a tool that was reading the wrong lines.
        window = _elseif_body(lines, ln)
        protected = bool(RECOVERY.search(window))
        seq.append((pln, pkind, ln, kind, protected))
        if not protected:
            unprotected.append((pln, pkind, ln, kind))

    if not seq:
        print("  none - every leg stands alone")
    for pln, pkind, ln, kind, protected in seq:
        print(f"  line {pln} {pkind}  ->  line {ln} {kind}")
        print(f"      half-completion handled: "
              f"{'YES' if protected else 'NO'}")
        if protected:
            m = re.search(r"elseif\s+(\w+)\s+then", "\n".join(
                lines[pln - 1:pln + 22]))
            rec = re.search(r"(addDebt|settleDebt)", "\n".join(
                lines[pln - 1:pln + 22]))
            print(f"      recovery: elseif {m.group(1) if m else '?'} "
                  f"-> {rec.group(1) if rec else 'cooldown only'}")

    # Effect before proof: an effect line ABOVE the leg it pays for,
    # inside the same block.
    print()
    print("=" * 70)
    print("EFFECT BEFORE PROOF - paying for a trade not yet queued")
    print("=" * 70)
    early = []
    for ln, kind, _ in legs:
        # Look back to the opening of this block for an effect that
        # already fired.
        for k in range(max(0, ln - 9), ln - 1):
            line = lines[k]
            if EFFECT.search(line) and not line.strip().startswith("--"):
                # An effect is fine if it is inside a PREVIOUS
                # completed branch; only flag when no `if` intervenes.
                between = "\n".join(lines[k + 1:ln - 1])
                if not re.search(r"\bif\b|\belseif\b|\bend\b", between):
                    early.append((k + 1, line.strip()[:64], ln, kind))
    if not early:
        print("  none - every effect follows the leg it pays for")
    for eln, etxt, ln, kind in early:
        print(f"  line {eln}: {etxt}")
        print(f"      fires before line {ln} ({kind})")

    print()
    print("VERDICT:")
    print(f"  trade legs:                      {len(legs)}")
    print(f"  sequenced pairs:                 {len(seq)}")
    print(f"  sequenced without recovery:      {len(unprotected)}")
    print(f"  effects firing before their leg: {len(early)}")
    if unprotected or early:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
