#!/usr/bin/env python3
"""Offline port of SAO_Census.assign: does a 500-cohort county look like
1993 Kentucky, and do the spec-ops stay almost-never? Exact hash math."""
import re, pathlib

# [B19] Repo-relative: this mirror reads the REAL census table,
# so it must find it from any checkout rather than from one
# machine's temp path.
src = (pathlib.Path(__file__).resolve().parent.parent
       / "mod/42.20/media/lua/shared/SAO_Census.lua"
       ).read_text(encoding="utf-8")

rows = []
for m in re.finditer(r'\{ key = "([^"]+)",\s*label = "([^"]+)",\s*per10k = (\d+)', src):
    rows.append((m.group(1), int(m.group(3))))
# The three active SoldierOccupation registrations, classified specops=7,
# sorted by key as the catalog does.
for k in sorted(["SoldierOccupation:armyranger", "SoldierOccupation:deltaforce",
                 "SoldierOccupation:navyseal"]):
    rows.append((k, 7))
total = sum(w for _, w in rows)
print(f"rows {len(rows)}, total weight {total} (base should be 10000 + 21)")

def hash_of(sid, salt):
    text = f"{sid}:{salt}"
    v = 2166136261
    for ch in text:
        v = (v * 16777619 + ord(ch)) % 4294967296
    return v

def assign(sid):
    roll = hash_of(sid, "census") % total
    cum = 0
    for key, w in rows:
        cum += w
        if roll < cum:
            return key
    return rows[-1][0]

from collections import Counter
counts = Counter(assign(f"sao-{i}") for i in range(1, 501))
print("500-cohort county:")
for key, n in counts.most_common(12):
    print(f"  {key:16s} {n}")
rare = {k: counts.get(k, 0) for k in
        ("police", "doctor", "parkranger", "smither",
         "SoldierOccupation:navyseal", "SoldierOccupation:deltaforce",
         "SoldierOccupation:armyranger", "soldier", "veteran")}
print("the rare and the local:", rare)
missing = [k for k, w in rows if w >= 300 and counts.get(k, 0) == 0]
print("common rows absent (hash pathology if any):", missing or "none")

# --- [B35] The two key spellings are the DESIGN, and must stay ------
#
# `rec.occupation` holds a BARE key for our own professions and a
# NAMESPACED one (`ns:path`) for a profession another mod registered.
# CLASS_BY_KEY is written in bare keys, so it matches ours and misses
# theirs on purpose - we cannot hand-write a class for a profession we
# have never seen, and the bucket classifier exists for exactly that.
#
# Nothing said so anywhere, and reading it the other way makes a large
# false finding look obvious: that all 26 hand-written classifications
# are dead. They are not. This asserts the shape so the next reader
# does not have to re-derive it, and so a drift toward namespacing the
# base rows - which would silently coarsen EVERY classification to its
# bucket - fails here instead of in play.
import sys as _sys

_base = re.search(r"Census\.BASE = \{(.*?)\n\}", src, re.S)
_baseKeys = re.findall(r'\{ key = "([^"]+)"', _base.group(1)) if _base else []
_cbk = re.search(r"local CLASS_BY_KEY = \{(.*?)\n\}", src, re.S)
_classKeys = re.findall(r"(\w+)\s*=\s*\"", _cbk.group(1)) if _cbk else []

_nsBase = [k for k in _baseKeys if ":" in k]
_nsClass = [k for k in _classKeys if ":" in k]
_unknown = [k for k in _classKeys if k not in _baseKeys]

print()
print("[B35] key-spelling invariant")
print(f"  base rows: {len(_baseKeys)}, namespaced among them: "
      f"{_nsBase or 'none'}")
print(f"  CLASS_BY_KEY entries: {len(_classKeys)}, namespaced: "
      f"{_nsClass or 'none'}")
print(f"  CLASS_BY_KEY keys with no base row: {_unknown or 'none'}")
if _nsBase or _nsClass:
    print("  FAIL: a bare-key table has gone namespaced; every")
    print("  classification would silently fall through to its bucket")
    _sys.exit(1)
if not _baseKeys or not _classKeys:
    print("  FAIL: a table could not be read - this check is blind")
    _sys.exit(1)
print("  both tables are bare-keyed, as the classifier requires")
