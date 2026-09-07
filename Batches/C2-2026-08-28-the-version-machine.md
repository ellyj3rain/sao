# C2 - The version machine

| Field | Record |
|---|---|
| Batch | `C2` |
| Date | 2026-08-28 |
| Name | The version machine |
| Status | Closed append-only batch - play verification pending (no play receipt) |
| Threads | [`T-030`](THREADS.md#t-030) |

## Record

The version stopped being picked (DR-013). `0.6.0.0` had been declared at
[B12] by a policy sentence after the diary bumped through hundreds of
entries, and the former VERSION_MAP walked to it in six flat minors so the
number looked earned - the exact shape the operator forbade.

CAO's version model is adopted whole: `major.minor.kohai.patch-maturity`,
hard caps minor 12 / kohai 16 / patch 24, a movement at the cap rolling the
tier above, maturity moving on evidence only. Every closed batch is
classified one unit per batch by what the work is - the recatalog already
made each batch the piece of work it actually was, so the unit grain is the
batch. The tier table with each unit's classification argument is the one
input, in [`tools/version_replay.py`](../tools/version_replay.py); names,
dates, and threads derive from BATCH_LOG.md, which owns them; the replay's
output is the version. `--write` stamps `VERSION` and renders
`VERSION_MAP.md`. Border 80 refuses a tree whose `VERSION`,
`VERSION_MAP.md`, or `mod.info` state anything the replay does not derive;
Border 42 already stamps the shipped jar from `VERSION` at build, and
Border 43 already holds the doc-pack headers to it - so no surface anywhere
states a version the machine did not compute.

**The answer the machine gave.** The closed chronology through `C1`
classifies as 22 minors, 29 kohai, 29 patches, and the initial unit; under
the caps the odometer crossed `1.0.0.0` at `A26` (the county wire, the
thirteenth minor) by arithmetic, not by honor, and the replay derives
`1.10.0.14-pre-alpha` at the C1 close - this batch's own kohai close moves
it to `1.10.1.0-pre-alpha`. The old number undersold the catalog rather
than overselling it; neither number was ever a release claim. Maturity
stays `pre-alpha` throughout because maturity moves on play receipts and no
batch has one. Classifications and arithmetic are shown row by row in
[`VERSION_MAP.md`](../VERSION_MAP.md); to disagree with the coordinate,
disagree with a tier, in the table, with the argument written down.

**Control.** Border 80 run against the exact former state - `VERSION`
hand-set to `0.6.0.0-pre-alpha` - goes red for the stated reason
("a stated version the machine does not derive") and green when the
machine's output is restored. Border 54's first run on this batch also
earned its keep twice: it refused the tool while it existed only on this
machine (`git ls-files` did not list it), and it caught that the untracked
tool made Border 76's declaration false in the blinded tree - both cleared
by tracking the file, not by widening a declaration.

This governed record is the portable project history for this unit.
