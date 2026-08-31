#!/usr/bin/env python3
r"""Border 59 - a pool the code builds must say what it drew.

The operator's session settled forty-nine pasts. Every single one of
them was `doors-decide-lives`.

The grammar has seven entries, and one of them -
`claimed-places-bite`, `fits = function(t) return true end` - fits
everybody, so it is in every pool that has ever been built. It came up
not once.

Simulating that loop over the same range of ids gives a healthy spread
across all seven, so the source as written does not explain it. Four
batches of reading that log did not explain it either. The only reason
anyone knows is that the same string appeared forty-nine times and
somebody noticed by eye.

That is the defect this border is about, and it is not the draw - it
is that the draw had no instrument. The county's most characterful
decision, who a person turns out to have been, ran two hundred and
thirty-four times with nothing counting the outcome.

WHAT COUNTS AS THIS SHAPE
-------------------------
`pool[(hash(...) % #pool) + 1]` - an index chosen by hash into a table
whose length the expression itself reads.

Only pools the code BUILDS are required to report. There are three
draws of this shape in the tree and the distinction between them is
the whole rule:

  * `fitting` in `SAO_History` is assembled per person by testing
    every grammar entry against their traits. Its membership varies,
    which means it can SILENTLY COLLAPSE to one entry - and a pool of
    one returns the same answer to every question asked of it.
  * `ORIGIN_NOTES[cls]` in `SAO_Census` and `LOST_NAMES` in
    `SAO_History` are module constants. A fixed list cannot collapse.
    Nothing is learned by counting draws from it, and requiring a
    tally there would be noise that teaches people to ignore this.

So: a pool declared as a runtime local (`local x = {}`, filled by a
loop) must tally its outcome. A pool that is a constant, or read out
of one, need not.

The reporting path is [B47]'s `tally`, which is why this border is
affordable at all - one counted line per outcome per flush, rather
than one line per person.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from menu_reach import strip_lua                       # noqa: E402

# The draw, and the name it lands in: `local pick = fitting[hash(..) % #fitting + 1]`
DRAW = re.compile(
    r"(?:local\s+(\w+)\s*=\s*)?"
    r"(\w+)\s*\[\s*\(?\s*(?:hashOf|hash|ZombRand)\s*\([^\]]*?%\s*#(\w+)[^\]]*\]")
FUNC = re.compile(r"^(?:local\s+)?function\b", re.M)


def built_pools(src):
    """Locals declared as an empty table - the ones a loop then fills."""
    return set(re.findall(r"local\s+([a-z]\w*)\s*=\s*\{\s*\}", src))


def enclosing(src, offset):
    """The function body containing this offset, as text."""
    starts = [m.start() for m in FUNC.finditer(src)]
    begin = max((s for s in starts if s <= offset), default=0)
    after = [s for s in starts if s > offset]
    return src[begin:(after[0] if after else len(src))]


def main():
    faults = []
    print("=" * 74)
    print("A POOL THE CODE BUILDS MUST SAY WHAT IT DREW")
    print("=" * 74)

    draws, reported, fixed = 0, 0, 0
    for path in sorted(LUA.rglob("*.lua")):
        src = strip_lua(path.read_text(encoding="utf-8", errors="ignore"),
                        strings=False)
        built = built_pools(src)
        for m in DRAW.finditer(src):
            holder, table, length = m.group(1), m.group(2), m.group(3)
            if table != length:
                continue
            draws += 1
            line = src.count("\n", 0, m.start()) + 1
            if table not in built:
                fixed += 1
                continue
            body = enclosing(src, m.start())
            # The tally must count THIS draw, not merely exist in the
            # same function. [B48]'s first draft accepted any tally,
            # so removing the instrument from the lesson draw left
            # `tally("history read")` behind and the border passed -
            # a control that could not fail.
            counts_it = holder and re.search(
                r"(?<!function )(?<![\w.])tally\s*\([^)]*\b" + re.escape(holder)
                + r"\b", body)
            if counts_it:
                reported += 1
            else:
                faults.append(
                    f"{path.name}:{line} draws from `{table}`, a pool this "
                    "code builds, and nothing counts what it drew. A built "
                    "pool can collapse to one entry, and a pool of one "
                    "returns the same answer to every question asked of "
                    "it - which is how forty-nine survivors in a row "
                    "learned the same lesson with nobody able to say why. "
                    f"Tally the outcome - a tally naming `{holder or table}`, "
                    "not just any tally in the same function")

    print(f"  hash-indexed draws     : {draws}")
    print(f"  from a built pool      : {reported + len(faults)}  "
          f"(reported: {reported})")
    print(f"  from a fixed constant  : {fixed}  (a fixed list cannot "
          "collapse; counting it would be noise)")

    if draws == 0:
        faults.append(
            "not one draw of this shape was found, which cannot be true of "
            "a mod that decides who people were by hashing them - the "
            "reading failed rather than the code being clean")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  59) pool draws: of {draws} hash-indexed draws, every one from "
          "a pool the code builds counts its own outcome")
    return 0


if __name__ == "__main__":
    sys.exit(main())
