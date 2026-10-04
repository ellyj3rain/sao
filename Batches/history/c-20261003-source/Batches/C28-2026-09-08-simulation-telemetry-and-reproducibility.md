# C28 - Simulation telemetry and reproducibility

| Field | Record |
|---|---|
| Batch | `C28` |
| Date | 2026-09-08 |
| Date range | 2026-09-08 to 2026-09-08 |
| Name | Simulation telemetry and reproducibility |
| Status | Consolidated historical record; implementation limitations remain explicit. |
| Threads | [`T-007`](THREADS.md#t-007), [`T-009`](THREADS.md#t-009) |
| Superseded entries | `C65`, `C66` in the former C sequence |
| Raw provenance | Local ref `archive/c-era-raw-20260919`; exact source paths and hashes in `C_RECATALOG.json`. |

## Record

Added run boundaries, input conditions, county trajectory measurements and a county-owned random stream. These enable accountable observations of a simulation. A reproducible outcome can still come from a defective producer and is not automatically suitable training data.

## Evidence and continuation

The original evidence is retained at the source ref above. This consolidation does not independently revalidate every earlier capability. Current limitations and the next work are owned by [SESSION_STATE.md](../SESSION_STATE.md) and [SUBSTRATE.md](../SUBSTRATE.md).

[Former-label crosswalk](FORMER_LABELS.md) resolves every source entry. The unit joins immediately adjacent work with a shared implementation or evidence purpose.
