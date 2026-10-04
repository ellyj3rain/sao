# C48 - Vehicle animal and combat integration

| Field | Record |
|---|---|
| Batch | `C48` |
| Date | 2026-09-14 |
| Date range | 2026-09-14 to 2026-09-14 |
| Name | Vehicle animal and combat integration |
| Status | Consolidated historical record; implementation limitations remain explicit. |
| Threads | [`T-001`](THREADS.md#t-001), [`T-003`](THREADS.md#t-003), [`T-006`](THREADS.md#t-006), [`T-007`](THREADS.md#t-007), [`T-008`](THREADS.md#t-008) |
| Superseded entries | `C122`, `C123`, `C124` in the former C sequence |
| Raw provenance | Local ref `archive/c-era-raw-20260919`; exact source paths and hashes in `C_RECATALOG.json`. |

## Record

Added held-key vehicle access, vehicle storage, animal care and combat-perception compatibility. Verified key and action adapters remain useful. Rework is required for compartment access and moving positions, animal admission into human beliefs, remote hutch extraction, installed prone-state keys and active-target revalidation.

## Evidence and continuation

The [implementation audit](../artifacts/audits/20260919-0356Z-2056PST-c112-c126-implementation-audit.md) provides reproduced defects and source traces. Its C identifiers refer to the former sequence. Consolidation preserves those findings and does not certify the affected behavior.

[Former-label crosswalk](FORMER_LABELS.md) resolves every source entry. The unit joins immediately adjacent work with a shared implementation or evidence purpose.
