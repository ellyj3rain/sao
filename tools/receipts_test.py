#!/usr/bin/env python3
r"""Border 97 - play receipts accrue, and the perpetual-untested claim
is dead (DR-025).

The operator's finding: everything was classified untested
perpetually - leaving something unmarked is one thing, claiming
nothing has ever been tested is tautological. The tautology was
structural:
no mechanism existed by which the operator's live reports became
recorded evidence, so the blanket claim could never be falsified -
the same hour that produced three play findings ([C18]) left every
document still saying "no play receipt".

WHAT THIS HOLDS
---------------
  1. RECEIPTS.md exists, parses, and is numbered R-001.. with no gaps
     and no duplicates - an append-only ledger whose shape cannot
     drift into prose.
  2. Every receipt carries a date/build line and an Observed line,
     and at least one of Settles / Exposed / Still open - an entry
     that observes nothing settles nothing.
  3. Every finding a receipt cites exists in FINDINGS.md and every
     batch it cites exists in BATCH_LOG.md - receipts point at real
     records, not at memory.
  4. The blanket claim is banned: SESSION_STATE.md and PLAYABILITY.md
     may no longer assert that NOTHING has a play receipt. Absence of
     a specific receipt stays a per-surface, per-batch statement.

An optional argv[1] points the checker at another tree root, which is
how the control runs against the pre-[C19] tree.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
RECEIPTS = ROOT / "RECEIPTS.md"
FINDINGS = ROOT / "FINDINGS.md"
BATCH_LOG = ROOT / "BATCH_LOG.md"

# \s+ between the words, not a literal space: the first control run
# passed against the OLD document because "play receipt" wrapped
# across a line break there - the instrument missed its own
# motivating case until the words were allowed to break.
BLANKET = re.compile(
    r"[Nn]othing[^.]{0,80}\bplay\s+receipt"
    r"|[Nn]othing[^.]{0,80}\bwitnessed\s+in\s+play"
    r"|no\s+play\s+receipts?\s+exist")


def main():
    faults = []
    print("=" * 74)
    print("PLAY RECEIPTS ACCRUE, AND THE BLANKET CLAIM IS DEAD")
    print("=" * 74)

    if not RECEIPTS.exists():
        print()
        print("VERDICT:")
        print("  FAULT: RECEIPTS.md does not exist - there is no mechanism "
              "by which play reports become recorded evidence, which is "
              "the tautology DR-025 ended")
        return 1

    text = RECEIPTS.read_text(encoding="utf-8", errors="ignore")
    entries = re.split(r"^## (R-\d{3})", text, flags=re.M)[1:]
    ids = entries[0::2]
    bodies = entries[1::2]

    if not ids:
        faults.append("RECEIPTS.md parses to zero receipts - either the "
                      "reader is broken or the ledger is empty prose; "
                      "both are faults, because [C19] seeded R-001")

    expected = [f"R-{n:03d}" for n in range(1, len(ids) + 1)]
    if ids != expected:
        faults.append(f"receipt numbering is {ids} - the ledger is "
                      "append-only and numbered without gaps from R-001")

    for rid, body in zip(ids, bodies):
        if "**Date / build**" not in body:
            faults.append(f"{rid} has no date/build line - a receipt "
                          "nobody can place in time settles nothing")
        if "**Observed**" not in body:
            faults.append(f"{rid} observes nothing")
        if not any(k in body for k in
                   ("**Settles", "**Exposed**", "**Still open**")):
            faults.append(f"{rid} neither settles, exposes, nor leaves "
                          "open - it is prose, not a receipt")

    findings = FINDINGS.read_text(encoding="utf-8", errors="ignore") \
        if FINDINGS.exists() else ""
    batches = BATCH_LOG.read_text(encoding="utf-8", errors="ignore") \
        if BATCH_LOG.exists() else ""
    for rid, body in zip(ids, bodies):
        for f in set(re.findall(r"\bF-\d{3}\b", body)):
            if f"## {f}" not in findings:
                faults.append(f"{rid} cites {f} and FINDINGS.md has no "
                              "such finding")
        for b in set(re.findall(r"\[([ABC]\d+)\]", body)):
            if f"[{b}]" not in batches:
                faults.append(f"{rid} cites [{b}] and BATCH_LOG.md has no "
                              "such batch")

    # A receipt names the build it happened on; the header's Version
    # cell tracks the tree. If every version string in the ledger body
    # equals the CURRENT tree version, history has been restamped over
    # - which happened once, the same hour this file was born.
    body_versions = set(re.findall(r"`(\d+\.\d+\.\d+\.\d+-[\w-]+)`",
                                   text.split("---", 1)[-1]))
    current = (ROOT / "VERSION").read_text(encoding="utf-8").strip()         if (ROOT / "VERSION").exists() else ""
    if body_versions and body_versions == {current}:
        faults.append("every build named in the ledger equals the current "
                      "tree version - a blanket restamp has rewritten the "
                      "receipts' history; restore the builds the sessions "
                      "actually ran")

    for name in ("SESSION_STATE.md", "PLAYABILITY.md"):
        doc = ROOT / name
        if not doc.exists():
            continue
        hit = BLANKET.search(doc.read_text(encoding="utf-8",
                                           errors="ignore"))
        if hit:
            faults.append(f"{name} still makes the blanket claim "
                          f"({hit.group(0)!r}) - absence of evidence is "
                          "stated per surface, never as 'nothing has "
                          "ever been tested'")

    print(f"  receipts on the ledger: {len(ids)}")
    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  97) receipts: the ledger parses, numbers cleanly, cites real")
    print("      records, and the perpetual-untested claim is gone from the")
    print("      canonical documents")
    return 0


if __name__ == "__main__":
    sys.exit(main())
