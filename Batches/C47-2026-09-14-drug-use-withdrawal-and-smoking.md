# C47 - Drug use withdrawal and smoking

| Field | Record |
|---|---|
| Batch | `C47` |
| Date | 2026-09-14 |
| Date range | 2026-09-14 to 2026-09-14 |
| Name | Drug use withdrawal and smoking |
| Status | Consolidated historical record; implementation limitations remain explicit. |
| Threads | [`T-002`](THREADS.md#t-002), [`T-008`](THREADS.md#t-008) |
| Superseded entries | `C121` in the former C sequence |
| Raw provenance | Local ref `archive/c-era-raw-20260919`; exact source paths and hashes in `C_RECATALOG.json`. |

## Record

Connected drug and ordinary consumption adapters, withdrawal, habits and optional real smoking. The audit reproduced a frozen-use clock that still removes dependency and daily processing that depends on the session-start minute. Optional body-owned counters and cumulative poison also need persistence and state-semantics correction.

## Evidence and continuation

The [implementation audit](../artifacts/audits/20260919-0356Z-2056PST-c112-c126-implementation-audit.md) provides reproduced defects and source traces. Its C identifiers refer to the former sequence. Consolidation preserves those findings and does not certify the affected behavior.

[Former-label crosswalk](FORMER_LABELS.md) resolves every source entry. The unit joins immediately adjacent work with a shared implementation or evidence purpose.
