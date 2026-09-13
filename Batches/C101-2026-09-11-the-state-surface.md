# C101 - The state surface

| Field | Record |
| --- | --- |
| Batch | `C101` |
| Date | 2026-09-11 |
| Name | The state surface |
| Status | Closed append-only batch - records and documents; no SAO mod code |
| Threads | [`T-008`](Batches/THREADS.md#t-008), [`T-030`](Batches/THREADS.md#t-030) |

## Record

ZAO's `[A19]` adds `ZAO_State.lua`, the runtime state surface, and a matching
state producer. A body with no assigned form is in the `none` form, its
performance is zero, and its decay state follows the facts SAO already
records. The state is no longer null.

This batch carries that movement into the shared architecture table.

## What changed

- `PROJECTS.md` updates the ZAO status row to `[A19]`.
- `SESSION_STATE.md` advances to this batch.
- `BATCH_LOG.md` gains the `[C101]` row.
- `tools/version_replay.py` classifies `[C101]`.

## No new border

SAO does not own ZAO's state surface. The cross-repo movement is recorded
here, and ZAO's own gate covers the implementation.
