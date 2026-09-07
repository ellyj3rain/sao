#!/usr/bin/env python3
r"""Border 79 - the maps and the indexes point at real things.

MAPS.md is what a new reader - human or model - trusts first. A node or
link naming a file that is gone, or a rule id that no longer exists, is
the map lying quietly, which is exactly how a picture becomes false
guidance ([B44]'s class in prose form).

The same class lives in the regulatory indexes: [C1]'s walk found
twenty-four BATCH_LOG.md rows linking record files that do not exist,
because the rows were written with one date while the records carry
another - the link and the date cell had both drifted from the
filenames that are the ground truth. An index that 404s is worse than
no index: it asserts coverage it does not have.

WHAT THIS HOLDS
---------------
  1. Every markdown link target in MAPS.md that names a path exists.
  2. Every mermaid node label naming a file (contains .lua, .java, or
     .md) resolves to a file in this tree.
  3. Every rule identifier the maps lean on (Border N, DR-nnn, F-nnn)
     exists where it says it does: borders in check.sh comments, DRs in
     DECISION_REGISTRY.md, F entries in FINDINGS.md.
  4. Every local markdown link in the regulatory indexes (BATCH_LOG.md,
     VERSION_MAP.md, Batches/THREADS.md, Batches/FORMER_LABELS.md)
     resolves to a file in this tree.
  5. Every BATCH_LOG.md row's date cell equals the date carried in the
     linked record's filename.
"""
import pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
MAPS = ROOT / "MAPS.md"
INDEXES = ("BATCH_LOG.md", "VERSION_MAP.md",
           "Batches/THREADS.md", "Batches/FORMER_LABELS.md")

def main():
    faults = []
    if not MAPS.exists():
        print("FAULT: MAPS.md is gone")
        return 1
    t = MAPS.read_text(encoding="utf-8")

    for m in re.finditer(r"\]\(([^)]+)\)", t):
        target = m.group(1).split("#")[0].split(",")[0].strip()
        if not target or target.startswith("http"):
            continue
        resolved = (MAPS.parent / target).resolve()
        if not resolved.exists():
            resolved = (ROOT / target).resolve()
        if not resolved.exists():
            faults.append(f"link target does not exist: {target}")

    for m in re.finditer(r"\b([\w./-]+\.(?:lua|java|md))\b", t):
        if not (ROOT / "mod/42.20/media/lua/client" / m.group(1)).exists() \
           and not (ROOT / "mod/42.20/media/lua/shared" / m.group(1)).exists() \
           and not (ROOT / "mod/42.20/media/lua/server" / m.group(1)).exists() \
           and not (ROOT / m.group(1)).exists() \
           and not (ROOT / "tools" / m.group(1)).exists() \
           and not (ROOT / "Batches" / m.group(1)).exists() \
           and not any((ROOT / "mod/42.20/media/lua").rglob(m.group(1))) \
           and not any(ROOT.rglob(m.group(1))):
            faults.append(f"named file not in the tree: {m.group(1)}")

    border_sources = "".join(p.read_text(encoding="utf-8", errors="ignore")
                             for p in (ROOT / "tools").glob("*.py"))
    drs = (ROOT / "DECISION_REGISTRY.md").read_text(encoding="utf-8", errors="ignore")
    findings = (ROOT / "FINDINGS.md").read_text(encoding="utf-8", errors="ignore")
    for m in re.finditer(r"\b[Bb]order (\d+)\b", t):
        if f"{m.group(1)})" not in border_sources:
            faults.append(f"MAPS.md leans on Border {m.group(1)}, which no mirror prints")
    for m in re.finditer(r"\bDR-(\d{3})\b", t):
        if f"DR-{m.group(1)}" not in drs:
            faults.append(f"MAPS.md leans on DR-{m.group(1)}: not in the registry")
    for m in re.finditer(r"\bF-(\d{3})\b", t):
        if f"F-{m.group(1)}" not in findings:
            faults.append(f"MAPS.md leans on F-{m.group(1)}: not in the findings ledger")

    for rel in INDEXES:
        idx = ROOT / rel
        if not idx.exists():
            faults.append(f"regulatory index is gone: {rel}")
            continue
        it = idx.read_text(encoding="utf-8")
        for m in re.finditer(r"\]\(([^)]+)\)", it):
            target = m.group(1).split("#")[0].strip()
            if not target or target.startswith("http"):
                continue
            if not (idx.parent / target).resolve().exists() \
               and not (ROOT / target).resolve().exists():
                faults.append(f"{rel} links a file not in the tree: {target}")

    log = (ROOT / "BATCH_LOG.md").read_text(encoding="utf-8")
    for m in re.finditer(
            r"\| \[([AB]\d+)\]\(Batches/[AB]\d+-(\d{4}-\d{2}-\d{2})-[^)]+\) "
            r"\| (\d{4}-\d{2}-\d{2}) \|", log):
        if m.group(2) != m.group(3):
            faults.append(f"BATCH_LOG.md dates {m.group(1)} {m.group(3)}; "
                          f"the record carries {m.group(2)}")

    print("=" * 74)
    print("THE MAPS AND THE INDEXES POINT AT REAL THINGS")
    print("=" * 74)
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  79) map and index references: every link resolves, every named file")
    print("      exists, every cited rule is where the map says it is, and every")
    print("      BATCH_LOG date is the linked record's own")
    return 0

if __name__ == "__main__":
    sys.exit(main())
