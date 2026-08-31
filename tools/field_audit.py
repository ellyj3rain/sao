#!/usr/bin/env python3
"""Field audit: reads without writers (the silent-nothing bug the B10
`owedToMe` catch was) and writes without readers (dead state).

Honest about its limits: Lua fields are written three ways - direct
assignment, multiple assignment, and table literals - and read through
receivers whose names vary. This tool collects ALL of them across the
whole tree, so a flag means "no site anywhere writes this name",
which is the condition that produced the B10 bug.
"""
import re
import pathlib
import collections

lroot = (pathlib.Path(__file__).resolve().parent.parent
         / "mod/42.20/media/lua")

files = (list((lroot / "client").glob("*.lua"))
         + list((lroot / "shared").glob("*.lua"))
         + list((lroot / "server").glob("*.lua")))

# Claim-state receivers: our own record/relation/meta/belief tables.
# Engine objects are called with ':' so ".field" never means them.
RECEIVERS = ("rec", "r", "meta", "meta0", "metaA", "metaB", "metaC",
             "metaS", "metaH", "metaW", "metaA8", "meta2", "metaK",
             "agent", "pb", "pb0", "pb2", "hr", "hr2", "mrec", "orec",
             "wrec", "lrec", "rec2", "drec", "hh", "l", "w", "v")
RECV_RE = r"\b(" + "|".join(RECEIVERS) + r")\.(\w+)\b"

writes = collections.defaultdict(set)
reads = collections.defaultdict(set)

for f in files:
    text = f.read_text(encoding="utf-8")
    # 1. Any field assigned on ANY table, including multiple assignment
    #    (rec.homeX, rec.homeY = ...) and ad-hoc receivers (sOB, sM).
    for m in re.finditer(r"\b\w+\.(\w+)\s*[,=][^=]", text):
        writes[m.group(1)].add(f.name)
    # 2. Table-literal writes: { field = value }. A field named in a
    #    constructor is written - what the first pass missed entirely.
    for m in re.finditer(r"[{,]\s*(\w+)\s*=", text):
        writes[m.group(1)].add(f.name)
    # 3. Reads on claim-state receivers.
    for m in re.finditer(RECV_RE + r"(?!\s*=(?!=))", text):
        reads[m.group(2)].add(f.name)

read_no_write = sorted(k for k in reads if k not in writes)
write_no_read = sorted(k for k in writes
                       if k not in reads and not k[0].isdigit()
                       and not k.startswith("_"))

print("READ but never WRITTEN anywhere (silent-nothing candidates):")
for k in read_no_write:
    print(f"   {k:22s} read in {sorted(reads[k])}")
print(f"   ({len(read_no_write)} flagged)")
print()
print("WRITTEN but never READ on a claim receiver (dead-state "
      "candidates - many are locals or engine-facing, triage each):")
for k in write_no_read[:25]:
    print(f"   {k:22s} written in {sorted(writes[k])}")
print(f"   ({len(write_no_read)} flagged)")
