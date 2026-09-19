# C44 - Robbery and raiding actions

| Field | Record |
|---|---|
| Batch | `C44` |
| Date | 2026-09-14 |
| Date range | 2026-09-14 to 2026-09-14 |
| Name | Robbery and raiding actions |
| Status | Consolidated historical record; implementation limitations remain explicit. |
| Threads | [`T-002`](THREADS.md#t-002), [`T-004`](THREADS.md#t-004), [`T-008`](THREADS.md#t-008) |
| Superseded entries | `C118` in the former C sequence |
| Raw provenance | Local ref `archive/c-era-raw-20260919`; exact source paths and hashes in `C_RECATALOG.json`. |

## Record

Added demands, surrender transfers, forced entry and raiding transport using existing execution primitives. The audit found that demand and response lack a completed transaction, surrender consequences precede transfer completion, and subsequent aggressor behavior does not consume the result. Rework is required.

## Evidence and continuation

The [implementation audit](../artifacts/audits/20260919-0356Z-2056PST-c112-c126-implementation-audit.md) provides reproduced defects and source traces. Its C identifiers refer to the former sequence. Consolidation preserves those findings and does not certify the affected behavior.

[Former-label crosswalk](FORMER_LABELS.md) resolves every source entry. The unit joins immediately adjacent work with a shared implementation or evidence purpose.
