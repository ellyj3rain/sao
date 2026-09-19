# C41 - County tick and ordinary activity

| Field | Record |
|---|---|
| Batch | `C41` |
| Date | 2026-09-13 |
| Date range | 2026-09-12 to 2026-09-13 |
| Name | County tick and ordinary activity |
| Status | Consolidated historical record; implementation limitations remain explicit. |
| Threads | [`T-002`](THREADS.md#t-002), [`T-007`](THREADS.md#t-007) |
| Superseded entries | `C112`, `C113` in the former C sequence |
| Raw provenance | Local ref `archive/c-era-raw-20260919`; exact source paths and hashes in `C_RECATALOG.json`. |

## Record

Defined the county tick from elapsed hours and added ordinary street activity with durable work locations. Rework remains required: controller time can stay cached during historical substeps, and the same stay-in decision has different loaded and dormant consequences.

## Evidence and continuation

The [implementation audit](../artifacts/audits/20260919-0356Z-2056PST-c112-c126-implementation-audit.md) provides reproduced defects and source traces. Its C identifiers refer to the former sequence. Consolidation preserves those findings and does not certify the affected behavior.

[Former-label crosswalk](FORMER_LABELS.md) resolves every source entry. The unit joins immediately adjacent work with a shared implementation or evidence purpose.
