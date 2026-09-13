# C98 - The cross-module row exporter

| Field | Record |
| --- | --- |
| Batch | `C98` |
| Date | 2026-09-11 |
| Name | The cross-module row exporter |
| Status | Closed append-only batch - records and documents; no mod code |
| Threads | [`T-008`](Batches/THREADS.md#t-008), [`T-030`](Batches/THREADS.md#t-030) |

## Record

Speakeasy record 32 adds `tools/cross_module_rows.py`. The exporter takes an
SAO decision dump and a ZAO state dump keyed by the same person id, keeps the
SAO row unchanged, adds the `pathogen` block to the person half, adds the
`visibleForms` block to the situation half, and writes one cross-module row
per line.

This batch carries the data-side movement into the shared architecture table.

## What changed

- `PROJECTS.md` updates the Speakeasy status row to record 32.
- `SESSION_STATE.md` advances to this batch.
- `BATCH_LOG.md` gains the `[C98]` row.
- `tools/version_replay.py` classifies `[C98]`.

## No new border

Records and documents only. The doc-currency border covers them. No mod
code, no engine surface.
