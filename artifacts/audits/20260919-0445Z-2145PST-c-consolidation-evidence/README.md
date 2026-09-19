# C catalog consolidation verification

The former 127-entry C catalog is represented by 50 adjacent units.
Every source entry has one destination and an exact original Git-blob hash.
The local archive and public source commit share the same tree. The
consolidation changes catalog coordinates and documentation; runtime Lua and
Java source remain unchanged. Both jars were rebuilt to stamp the coordinate.

Run from the repository root:

```
python artifacts/audits/20260919-0445Z-2145PST-c-consolidation-evidence/verify-catalog.py
python artifacts/audits/20260919-0445Z-2145PST-c-consolidation-evidence/verify-border-controls.py
```

The first probe checks the crosswalk, exact source hashes, records and current
map border. Removing or duplicating an entry is rejected; a changed C50 date
is rejected with a specific finding. The public source commit must be present
locally. Its final runtime-source check concerns the staged change, so that
check is meaningful while reviewing this consolidation, not an arbitrary
future staging area.

The second probe runs the five existing mechanism borders whose obsolete
roadmap SHIPPED assertions were removed. Each baseline passes. Each deliberate
source mutation is rejected with the expected mechanism finding. It changes
only the source text supplied to that instrument, not runtime files. These
engine checks use their normal compiled test output and require the installed
game and JDK. Run them sequentially with the full gate.

The first full gate found exactly those five obsolete documentation assertions.
The current checks preserve their runtime assertions; map_reference_test also
checks C-era dates, which its former A/B-only pattern missed. Gate results and
publication checks are recorded in the pull request. No new play observation,
model training or runtime deployment is claimed.

The implementation audit and substrate probes retain their original source
hashes and bounded conclusions. Byte preservation is explicit for audit
captures. Current Word exports were generated as local drafts; package checks
passed but the required LibreOffice renderer was unavailable, so earlier
published Word copies are classified as historical snapshots.
