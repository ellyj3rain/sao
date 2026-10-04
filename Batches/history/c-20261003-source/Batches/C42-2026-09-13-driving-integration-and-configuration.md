# C42 - Driving integration and configuration

| Field | Record |
|---|---|
| Batch | `C42` |
| Date | 2026-09-13 |
| Date range | 2026-09-13 to 2026-09-13 |
| Name | Driving integration and configuration |
| Status | Consolidated historical record; implementation limitations remain explicit. |
| Threads | [`T-001`](THREADS.md#t-001), [`T-002`](THREADS.md#t-002), [`T-004`](THREADS.md#t-004) |
| Superseded entries | `C114`, `C115` in the former C sequence |
| Raw provenance | Local ref `archive/c-era-raw-20260919`; exact source paths and hashes in `C_RECATALOG.json`. |

## Record

Extended ordinary driving and wired the three associated configuration choices. The option wiring is retained. Driving requires substantial repair: its approach can cancel itself, unchanged status text cancels moving vehicles, promised passengers are not waited for, and rearward destinations can produce forward travel.

## Evidence and continuation

The [implementation audit](../artifacts/audits/20260919-0356Z-2056PST-c112-c126-implementation-audit.md) provides reproduced defects and source traces. Its C identifiers refer to the former sequence. Consolidation preserves those findings and does not certify the affected behavior.

[Former-label crosswalk](FORMER_LABELS.md) resolves every source entry. The unit joins immediately adjacent work with a shared implementation or evidence purpose.
