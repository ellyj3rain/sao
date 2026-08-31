#!/usr/bin/env python3
r"""Border 76 - the document that says where things stand, saying it wrongly.

`SESSION_STATE.md` is marked CANONICAL - *"where the work actually
stands"*. Until [B52] it opened with

    Two hundred A-batches and a hundred and fifty-five B-batches

when there were a hundred and eighty-nine, and said

    Forty-four borders in `tools/`

when there were seventy-five.

That is [B43]'s finding, in the document that exists to prevent it.
[B43] fixed twelve headers claiming a batch tip a hundred and eleven
batches behind, and Border 20 has kept the version cells and the tip
claims true ever since. It never looked at the prose.

A count in prose is a claim like any other, and worse than most: it is
believed on sight, it goes stale silently, and nothing about a wrong
one looks wrong.

WHY NOT JUST DELETE THE NUMBERS
-------------------------------
Because they are the useful part. "How much of this is there" is the
first question anybody asks of a tree with three hundred and ninety
batch records in it, and an answer that has to be recomputed by hand is
an answer nobody has.

So they stay, and they are DERIVED - the border computes each from the
tree and requires the document to state that figure. `SESSION_STATE.md`
is edited on every batch close anyway, so keeping one line true costs
nothing, and forgetting it is now impossible rather than merely
unlikely.

WHAT IS COUNTED
---------------
  * A-batch and B-batch documents in `Batches/`
  * the highest border number any mirror prints in its verdict
  * the mirrors `tools/check.sh` actually runs, both spellings - the
    same reading Border 54 uses, so the two cannot disagree about how
    many borders there are
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
STATE = ROOT / "SESSION_STATE.md"
TOOLS = ROOT / "tools"
CHECK = TOOLS / "check.sh"
BATCHES = ROOT / "Batches"

# Each claim: how to count it, and the phrase the document must use.
# The phrase is matched with the number in place, so a stale figure
# cannot satisfy it and a reworded sentence fails loudly rather than
# silently stopping being checked.
CLAIMS = (
    ("A-batch documents", lambda c: c["a"], "{n} A-batches"),
    ("B-batch documents", lambda c: c["b"], "{n} B-batches"),
    ("numbered borders", lambda c: c["borders"], "{n} numbered borders"),
    ("gated mirrors", lambda c: c["mirrors"], "{n} gated mirrors"),
)


def counts():
    # A-batches predate BATCH_LOG's current format and have no rows in
    # it, so they are counted as documents. B-batches are counted from
    # the LOG, which Border 20 calls the chronological index - and
    # which is the only place that gets B36 right: there are 188
    # documents named `B\d+` and 189 B-batches, because [B36]'s record
    # IS `GOVERNANCE.md`. Counting files would quietly lose a batch,
    # which is the shape of thing this border exists for.
    a = len([p for p in BATCHES.glob("A*.md")
             if re.match(r"^A\d+", p.name)])
    log = (ROOT / "BATCH_LOG.md").read_text(encoding="utf-8", errors="ignore")
    b = len(set(re.findall(r"^\| \[(B\d+)\]", log, re.M)))

    # The highest border number any mirror prints. Read from the
    # verdicts rather than from check.sh's comments, because the
    # verdict is what a person sees and the comment is optional.
    highest = 0
    for path in TOOLS.glob("*.py"):
        src = path.read_text(encoding="utf-8", errors="ignore")
        for m in re.finditer(r'"\s*(\d+)\)\s', src):
            highest = max(highest, int(m.group(1)))

    # The same reading Border 54 uses for "which mirrors are gated".
    src = CHECK.read_text(encoding="utf-8", errors="ignore")
    named = set(re.findall(r"tools/([a-z_0-9]+)\.py", src))
    loop = re.search(r"for mirror in \\?\n(.*?)\ndo", src, re.S)
    if loop:
        named |= set(re.findall(r"([a-z_0-9]+_test)", loop.group(1)))
    mirrors = len([n for n in named if (TOOLS / (n + ".py")).exists()])

    return {"a": a, "b": b, "borders": highest, "mirrors": mirrors}


def main():
    faults = []
    print("=" * 74)
    print("THE DOCUMENT THAT SAYS WHERE THINGS STAND")
    print("=" * 74)

    if not STATE.exists():
        print()
        print("VERDICT:")
        print("  FAULT: SESSION_STATE.md is gone, and it is the one document "
              "marked CANONICAL")
        return 1
    text = STATE.read_text(encoding="utf-8", errors="ignore")

    got = counts()
    if got["borders"] == 0 or got["mirrors"] == 0 or got["b"] == 0:
        print()
        print("VERDICT:")
        print("  FAULT: something counted as zero - no borders, no gated "
              "mirrors, or no batch records. The reading failed rather than "
              "the tree being empty")
        return 1

    for label, pick, phrase in CLAIMS:
        n = pick(got)
        want = phrase.format(n=n)
        ok = re.search(re.escape(want), text) is not None
        print(f"     {label:<20} {n:>4}   "
              f"{'stated' if ok else 'NOT STATED as ' + repr(want)}")
        if not ok:
            stale = re.search(
                phrase.format(n=r"\*{0,2}(\d+)\*{0,2}").replace(" ", r"\s+"),
                text)
            if stale:
                faults.append(
                    f"SESSION_STATE.md says {stale.group(1)} {label} and "
                    f"there are {n}. It is the document marked CANONICAL - "
                    "where the work actually stands - and a count in prose "
                    "is believed on sight, goes stale in silence, and never "
                    "looks wrong")
            else:
                faults.append(
                    f"SESSION_STATE.md no longer states its {label} count. "
                    f"Write `{want}` - the figure is derived here, so it "
                    "costs one line at a batch close and cannot drift")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  76) state counts: all {len(CLAIMS)} figures SESSION_STATE.md "
          "states about this tree are the figures the tree has")
    return 0


if __name__ == "__main__":
    sys.exit(main())
