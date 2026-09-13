# C99 - The first cross-module rows

| Field | Record |
| --- | --- |
| Batch | `C99` |
| Date | 2026-09-11 |
| Name | The first cross-module rows |
| Status | Closed append-only batch - records and documents; no mod code |
| Threads | [`T-008`](Batches/THREADS.md#t-008), [`T-030`](Batches/THREADS.md#t-030) |

## Record

Speakeasy record 33 adds the first cross-module rows to
`decisions/cross-module/`. The ZAO state in these rows is derived from the
pathogen facts SAO already records, and the mutation-specific fields stay
null until ZAO supplies them.

This batch carries the data-side movement into the shared architecture table.

## What changed

- `PROJECTS.md` updates the Speakeasy status row to record 33.
- `SESSION_STATE.md` advances to this batch.
- `BATCH_LOG.md` gains the `[C99]` row.
- `tools/version_replay.py` classifies `[C99]`.

## No new border

Records and documents only. The doc-currency border covers them. No mod
code, no engine surface.
