# C103 - The form overlay

| Field | Record |
| --- | --- |
| Batch | `C103` |
| Date | 2026-09-11 |
| Name | The form overlay |
| Status | Closed append-only batch - records and documents; no SAO mod code |
| Threads | [`T-008`](Batches/THREADS.md#t-008), [`T-030`](Batches/THREADS.md#t-030) |

## Record

ZAO's `[A22]` adds a world-space form overlay and corrects the form roll so
only infected, dead, or turned bodies carry a form. The overlay draws the
current form and normalized performance above every nearby body that carries
one.

This batch carries that movement into the shared architecture table.

## What changed

- `PROJECTS.md` updates the ZAO status row to `[A22]`.
- `SESSION_STATE.md` advances to this batch.
- `BATCH_LOG.md` gains the `[C103]` row.
- `tools/version_replay.py` classifies `[C103]`.

## No new border

SAO does not own ZAO's overlay. ZAO's own gate covers the implementation.
