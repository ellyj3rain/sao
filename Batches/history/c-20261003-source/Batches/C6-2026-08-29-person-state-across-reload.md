# C6 - Person state across reload

| Field | Record |
|---|---|
| Batch | `C6` |
| Date | 2026-08-29 |
| Date range | 2026-08-29 to 2026-08-29 |
| Name | Person state across reload |
| Status | Consolidated historical record; implementation limitations remain explicit. |
| Threads | [`T-006`](THREADS.md#t-006) |
| Superseded entries | `C15` in the former C sequence |
| Raw provenance | Local ref `archive/c-era-raw-20260919`; exact source paths and hashes in `C_RECATALOG.json`. |

## Record

Extended persistence so the person retains the state required to resume decisions across reload. The durable record is authoritative while engine bodies are temporary representations. Later optional drug counters and graph registrations still require their own persistence review.

## Evidence and continuation

The original evidence is retained at the source ref above. This consolidation does not independently revalidate every earlier capability. Current limitations and the next work are owned by [SESSION_STATE.md](../SESSION_STATE.md) and [SUBSTRATE.md](../SUBSTRATE.md).

[Former-label crosswalk](FORMER_LABELS.md) resolves every source entry. The unit joins immediately adjacent work with a shared implementation or evidence purpose.
