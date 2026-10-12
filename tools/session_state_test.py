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
  2. Current header/body/tip version claims agree with `VERSION`. Explicitly
     dated sections about earlier closed catalogue batches retain their own
     episode coordinates. A history label alone establishes no such boundary.
  3. It still states a batch and a count at all. A file that stopped
     making the claim would pass a check that only compared claims.
"""
import pathlib
import re
import sys
from datetime import date
from catalogue import BATCH_ID_PATTERN

ROOT = pathlib.Path(__file__).resolve().parent.parent
STATE = ROOT / "SESSION_STATE.md"
BATCH_LOG = ROOT / "BATCH_LOG.md"
VERSION_FILE = ROOT / "VERSION"

AS_OF = re.compile(rf"\*\*As of\*\*[^\n]*?`?\[({BATCH_ID_PATTERN})\]`?")
ROW = re.compile(rf"^\|\s*\[?`?\[?({BATCH_ID_PATTERN})\]?`?\]?\(", re.M)
# A version string anywhere in the prose. The pre-release suffix
# contains its own hyphen - `0.6.0.0-pre-alpha` - so the class has to
# admit one, or this reads the shipped version as `0.6.0.0-pre` and
# reports the file for disagreeing with itself.
SEMVER = re.compile(r"\b(\d+\.\d+\.\d+\.\d+(?:-[\w.+-]+)?)")
INDEX_ENTRY = re.compile(
    rf"^\|\s*\[({BATCH_ID_PATTERN})\]\((Batches/[^)]+\.md)\)\s*\|\s*(\d{{4}}-\d{{2}}-\d{{2}})\s*\|", re.M)
HEADING = re.compile(r"^#{1,6}\s+(.+)$", re.M)
DATED_BATCH_SECTION = re.compile(
    rf"^({BATCH_ID_PATTERN})\b.*?\s[-—]\s(\d{{4}}-\d{{2}}-\d{{2}})\b")
CLOSED_STATUS = re.compile(r"^\|\s*Status\s*\|\s*(?:\*\*)?CLOSED\b", re.M)


def version_claims(state, log, root):
    """Partition current claims from source-backed dated closed-batch episodes."""
    entries = list(INDEX_ENTRY.finditer(log))
    if not entries:
        return set(SEMVER.findall(state)), []
    tip = entries[-1].group(1)
    tip_date = date.fromisoformat(entries[-1].group(3))
    earlier = {m.group(1): m.group(2) for m in entries[:-1] if m.group(1) != tip}
    headings = list(HEADING.finditer(state))
    current = set(SEMVER.findall(state[:headings[0].start()] if headings else state))
    historical = []
    for index, heading in enumerate(headings):
        end = headings[index + 1].start() if index + 1 < len(headings) else len(state)
        section = state[heading.start():end]
        declared = DATED_BATCH_SECTION.match(heading.group(1))
        record = None
        if declared and declared.group(1) in earlier:
            relative = pathlib.PurePosixPath(earlier[declared.group(1)])
            if '..' not in relative.parts:
                candidate = root / relative
                if candidate.is_file() and date.fromisoformat(declared.group(2)) <= tip_date:
                    record = candidate.read_text(encoding='utf-8', errors='strict')
        versions = set(SEMVER.findall(section))
        if record is not None and CLOSED_STATUS.search(record):
            historical.append({'batch': declared.group(1), 'date': declared.group(2),
                               'record': earlier[declared.group(1)], 'versions': sorted(versions)})
        else:
            current.update(versions)
    return current, historical


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

    versions, historical = version_claims(state, log, ROOT)
    wrong = sorted(v for v in versions if v != declared)
    print(f"  current versions: {', '.join(sorted(versions)) or 'none'}")
    print(f"  dated closed-batch sections: {len(historical)}")
    if not versions:
        faults.append('SESSION_STATE.md states no current version; dated episode coordinates do not replace the current claim')
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
