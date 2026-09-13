# C102 - The form registry and the pathogen roll

| Field | Record |
| --- | --- |
| Batch | `C102` |
| Date | 2026-09-11 |
| Name | The form registry and the pathogen roll |
| Status | Closed append-only batch - records and documents; no SAO mod code |
| Threads | [`T-008`](Batches/THREADS.md#t-008), [`T-030`](Batches/THREADS.md#t-030) |

## Record

ZAO's `[A20]` adds the form registry and the pathogen roll. The six
source-port forms are Puker, Husk, Skitter, Wrecker, Leaper, and Weeper.
A turned body has a 10 percent chance of taking one, and form performance is
a normalized state value between 0 and 1.

This batch carries that movement into the shared architecture table.

## What changed

- `PROJECTS.md` updates the ZAO status row to `[A20]`.
- `SESSION_STATE.md` advances to this batch.
- `BATCH_LOG.md` gains the `[C102]` row.
- `tools/version_replay.py` classifies `[C102]`.

## No new border

SAO does not own ZAO's form registry. ZAO's own gate covers the
implementation.
