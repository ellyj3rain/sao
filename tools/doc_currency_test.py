#!/usr/bin/env python3
r"""Border 43 - the doc-pack states one version, and the index knows the root.

Two claims the governance documents made about themselves, both false.

**The headers.** Twelve root documents carried a `Version` cell holding
a version AND a batch tip - `0.6.0.0-pre-alpha · A era closed at [A29]
· B tip [B30]` - while the sequence stood at `[B43]`. Three said
`0.4.0.0-pre-alpha · closed batch tip [A11]`, two minor versions and a
hundred and eleven batches behind. Every one is CANONICAL by
`MEMORY.md`'s own vocabulary: *"Current truth. Edit in place when
superseded."*

The tip was dropped rather than corrected. Keeping it means twelve
files to touch on every batch forever, and a claim nobody maintains is
worse than no claim - `BATCH_LOG.md` is the chronological index and the
tip belongs there alone. Same discipline as [B40]: one spelling.

**The index.** `MEMORY.md` states *"Nothing at the root is
unclassified."* Five root files were - `CREDITS.md`, `HANDOFF.md`,
`PLAYABILITY.md`, `POSITION.md`, `SPEECH.md` - and `PLAYABILITY.md` was
carrying a doc-pack header while being absent from the index that
governs doc-pack headers.

WHAT THIS HOLDS
---------------
  1. Every root `.md` with a `Version` cell states exactly the string in
     `VERSION`.
  2. No document except `BATCH_LOG.md` claims a batch tip in that cell.
     A clause saying `authored at [A14]` is PROVENANCE and is allowed -
     it records when a thing was written, which does not go stale.
  3. `MEMORY.md` classifies every file at the repository root, because
     it says it does.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
VERSION_FILE = ROOT / "VERSION"
MEMORY = ROOT / "MEMORY.md"

def sayable(text):
    """Quoted repository content, folded so it survives any capture.

    NOT because printing a middle dot crashes - it does not. `·` is
    U+00B7 and cp1252 encodes it as 0xB7, and Border 36 prints a
    U+2026 fault to this console without complaint. [B43] first
    recorded that as a border crash and it was wrong.

    The real problem is that a border's stdout encoding follows the
    locale, so when it is piped it emits `0xB7` - a lone byte that is
    not valid UTF-8. A harness capturing it as UTF-8 gets U+FFFD, and
    the finding stops saying what the file says. Folding at the source
    means a fault reads the same on any console and through any
    capture.
    """
    return text.encode("ascii", "replace").decode("ascii")


VERSION_ROW = re.compile(r"^\|\s*Version\s*\|\s*(.+?)\s*\|\s*$", re.M)
# A currency claim names a batch and says it is where things stand.
TIP_CLAIM = re.compile(r"(tip|next|closes at|era)\b", re.I)
PROVENANCE = re.compile(r"authored at\s*`\[[A-Z]\d+\]`", re.I)
# BATCH_LOG is where the tip lives.
TIP_OWNER = "BATCH_LOG.md"


def main():
    faults = []
    print("=" * 74)
    print("WHAT THE DOC-PACK SAYS ABOUT ITSELF")
    print("=" * 74)

    declared = VERSION_FILE.read_text(encoding="utf-8").strip()
    print(f"  VERSION: {declared}")

    headed = 0
    for path in sorted(ROOT.glob("*.md")):
        src = path.read_text(encoding="utf-8", errors="ignore")
        m = VERSION_ROW.search(src)
        if not m:
            continue
        headed += 1
        cell = m.group(1)
        # Strip a provenance clause before judging what is left.
        rest = PROVENANCE.sub("", cell)
        stated = re.search(r"`([^`]+)`", rest)
        if not stated:
            faults.append(
                f"{path.name} has a Version cell with no version in it: "
                f"{sayable(cell)!r}")
        elif stated.group(1) != declared:
            faults.append(
                f"{path.name} states `{stated.group(1)}` and VERSION says "
                f"`{declared}` - it is CANONICAL by MEMORY.md's own "
                'vocabulary, "current truth, edit in place when superseded"')
        if path.name != TIP_OWNER and TIP_CLAIM.search(rest):
            faults.append(
                f"{path.name}'s Version cell claims a batch position: "
                f"{sayable(cell)!r}. The tip lives in {TIP_OWNER} and nowhere else - "
                "a tip in twelve headers is twelve things to maintain and "
                "was a hundred and eleven batches stale when this was "
                "written")

    print(f"  root documents with a Version cell: {headed}")
    if headed == 0:
        faults.append(
            "no root document has a Version cell - this border is reading "
            "for a header shape the doc-pack no longer uses")

    # 3. The index's own completeness claim.
    mem = MEMORY.read_text(encoding="utf-8", errors="ignore")
    classified = set(re.findall(r"\|\s*`([A-Za-z_0-9.]+)`\s*\|", mem))
    classified |= set(re.findall(r"\[([A-Za-z_0-9]+\.md)\]", mem))
    present = {p.name for p in ROOT.iterdir()
               if p.is_file() and not p.name.startswith(".")}
    missing = sorted(present - classified)
    print(f"  root files: {len(present)}   unclassified: {len(missing)}")
    for name in missing:
        faults.append(
            f"`{name}` sits at the repository root and MEMORY.md does not "
            'classify it, while MEMORY.md says "Nothing at the root is '
            'unclassified"')

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  43) doc currency: every header states VERSION and nothing "
          "else, the tip lives")
    print("      in one file, and the index classifies the whole root")
    return 0


if __name__ == "__main__":
    sys.exit(main())
