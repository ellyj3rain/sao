# C100 - The ZAO state producer

| Field | Record |
| --- | --- |
| Batch | `C100` |
| Date | 2026-09-11 |
| Name | The ZAO state producer |
| Status | Closed append-only batch - records and documents; no mod code |
| Threads | [`T-008`](Batches/THREADS.md#t-008), [`T-030`](Batches/THREADS.md#t-030) |

## Record

ZAO's `[A18]` adds `tools/state_dump.py`, which emits one pathogen-state row
per SAO decision moment, keyed by person id and decision hour. The
ZAO-specific mutation fields stay null until ZAO has a real state surface to
read them from.

This batch carries that movement into the shared architecture table.

## What changed

- `PROJECTS.md` updates the ZAO status row to `[A18]`.
- `SESSION_STATE.md` advances to this batch.
- `BATCH_LOG.md` gains the `[C100]` row.
- `tools/version_replay.py` classifies `[C100]`.

## No new border

Records and documents only. The doc-currency border covers them. No mod
code, no engine surface.
