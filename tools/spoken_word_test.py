#!/usr/bin/env python3
r"""Border 84 - world text is a person talking ([C5], SPEECH.md).

The operator's law, applied: a counter like noting three things is
not speech; a
line with no place and no fact is empty; day-zero flavor that asserts
knowledge nobody holds is not knowledge. The walk found the tell
surface discarding everything it knew at the render, talk lines
printing raw tile coordinates ("holds a place at 10842,9195"), a creed
sentence that trailed into nothing, and an innocent asserting what the
radio said with no told claim behind it.

WHAT THIS HOLDS
---------------
  1. No talk offer concatenates a raw coordinate pair - believed
     positions render through `P.whereWord`, the words a person
     standing there would use.
  2. The tell surface speaks its content: `P.tell` returns the spoken
     acknowledgment beside the count, and the harness renders IT -
     never a count of things.
  3. The day-zero innocent speaks opinions, not asserted information:
     the radio-said line is gone.
  4. The creed sentence cannot trail into nothing.

An optional argv[1] points the checker at another tree root, which is
how the control runs against the pre-fix state.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
HARNESS = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Harness.lua"
PERCEPTION = ROOT / "mod" / "42.20" / "media" / "lua" / "shared" / "SAO_Perception.lua"


def main():
    faults = []
    harness = HARNESS.read_text(encoding="utf-8", errors="ignore")
    perception = PERCEPTION.read_text(encoding="utf-8", errors="ignore")

    for m in re.finditer(r"offers\[#offers \+ 1\][\s\S]{0,320}?(?=offers\[|"
                         r"\n\s*end\b)", harness):
        if re.search(r'\.\.\s*","\s*\.\.', m.group(0)):
            faults.append("a talk offer concatenates a raw coordinate "
                          "pair - a person talking does not say "
                          "coordinates: " + m.group(0)[:80].strip())

    if "whereWord" not in perception:
        faults.append("Perception has no whereWord - believed positions "
                      "have no way to become a person's words")
    if not re.search(r"return shared, spoken", perception):
        faults.append("P.tell does not return the spoken acknowledgment "
                      "- the listener has nothing to say but a count")
    if not re.search(r"local n, spoken = SAO\.Perception\.tell", harness):
        faults.append("the harness does not consume tell's spoken "
                      "acknowledgment")
    if re.search(r"they note", harness):
        faults.append('"they note N things" is rendered - a count of '
                      "things is not speech")
    if "The radio said" in harness:
        faults.append("the day-zero innocent asserts what the radio "
                      "said, and holds no told claim behind it")
    if re.search(r'\.\.\s*"\.\s*"\s*\n?\s*\.\.\s*\(CREED_LINES', harness):
        faults.append("the creed sentence can trail into nothing")

    print("=" * 74)
    print("WORLD TEXT IS A PERSON TALKING")
    print("=" * 74)
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  84) the spoken word: no coordinates in anyone's mouth, the tell")
    print("      surface speaks the thing itself, the innocent assert nothing")
    print("      they do not hold, and no sentence trails into nothing")
    return 0


if __name__ == "__main__":
    sys.exit(main())
