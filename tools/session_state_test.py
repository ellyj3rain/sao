#!/usr/bin/env python3
r"""Border 44 - the document that says where the work stands is where it stands.

`SESSION_STATE.md` is CANONICAL and its declared role is *"Where the
work actually stands."* It said:

    **As of** 2026-08-26, [A15] close.
    Seventy-one batches. ... Versions: 0.4.0.0

while the sequence stood at `[B43]` on `0.6.0.0-pre-alpha` - roughly
283 batches behind. It is the first file a new session reads to orient
itself, and `HANDOFF.md` exists at all because this one had stopped
carrying its own job.

WHY THIS ONE IS GATED AND THE HEADERS WERE NOT
----------------------------------------------
[B43] dropped the batch tip out of twelve document headers rather than
correct it, because a claim in twelve files is twelve things to
maintain on every batch and the first one that forgets undoes it.

This file is the opposite case. Currency is not incidental to it - it
is the whole purpose of the document. One file, one line, updated when
a batch closes. Making that a gate failure is what stops a 283-batch
drift from happening quietly again, and it costs a sentence.

WHAT THIS HOLDS
---------------
  1. The `As of` batch is the last row in `BATCH_LOG.md`.
  2. Every version string in the body is the one in `VERSION` - the
     body said 0.4.0.0 twice while the header said 0.6.0.0, so fixing
     headers alone would have left the prose lying.
  3. It still states a batch and a count at all. A file that stopped
     making the claim would pass a check that only compared claims.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
STATE = ROOT / "SESSION_STATE.md"
BATCH_LOG = ROOT / "BATCH_LOG.md"
VERSION_FILE = ROOT / "VERSION"

AS_OF = re.compile(r"\*\*As of\*\*[^\n]*?`?\[([ABC]\d+)\]`?")  # eras run A, B, C
ROW = re.compile(r"^\|\s*\[?`?\[?([ABC]\d+)\]?`?\]?\(", re.M)  # eras run A, B, C
# A version string anywhere in the prose. The pre-release suffix
# contains its own hyphen - `0.6.0.0-pre-alpha` - so the class has to
# admit one, or this reads the shipped version as `0.6.0.0-pre` and
# reports the file for disagreeing with itself.
SEMVER = re.compile(r"\b(\d+\.\d+\.\d+\.\d+(?:-[\w.+-]+)?)")


def main():
    faults = []
    print("=" * 74)
    print("WHERE THE WORK SAYS IT STANDS")
    print("=" * 74)

    declared = VERSION_FILE.read_text(encoding="utf-8").strip()
    state = STATE.read_text(encoding="utf-8", errors="ignore")
    log = BATCH_LOG.read_text(encoding="utf-8", errors="ignore")

    rows = ROW.findall(log)
    tip = rows[-1] if rows else None
    print(f"  BATCH_LOG tip:   {tip or 'NONE'}")
    if not tip:
        faults.append(
            "no batch rows found in BATCH_LOG.md - this border cannot see "
            "the sequence it is comparing against, so it would pass on "
            "anything")
        return report(faults)

    m = AS_OF.search(state)
    stated = m.group(1) if m else None
    print(f"  SESSION_STATE:   {stated or 'STATES NO BATCH'}")
    if not stated:
        faults.append(
            "SESSION_STATE.md states no `As of` batch - a document whose "
            "role is where the work stands has stopped saying where that "
            "is, which passes any check that only compares claims")
    elif stated != tip:
        faults.append(
            f"SESSION_STATE.md says the work stands at [{stated}] and "
            f"BATCH_LOG's last row is [{tip}] - it is the first file a new "
            "session reads, and it was 283 batches behind when this border "
            "was written")

    versions = set(SEMVER.findall(state))
    wrong = sorted(v for v in versions if v != declared)
    print(f"  versions in body: {', '.join(sorted(versions)) or 'none'}")
    for v in wrong:
        faults.append(
            f"SESSION_STATE.md names version {v} and VERSION says "
            f"{declared} - the header was corrected by [B43] and the "
            "prose is where the claim actually gets read")

    return report(faults)


def report(faults):
    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  44) session state: the file that says where the work stands "
          "names the current")
    print("      batch and the shipped version")
    return 0


if __name__ == "__main__":
    sys.exit(main())
