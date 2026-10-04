# C33 - Controller ownership and driving surface verification

| Field | Record |
|---|---|
| Batch | `C33` |
| Date | 2026-09-09 |
| Date range | 2026-09-09 to 2026-09-09 |
| Name | Controller ownership and driving surface verification |
| Status | Consolidated historical record; implementation limitations remain explicit. |
| Threads | [`T-001`](THREADS.md#t-001), [`T-002`](THREADS.md#t-002), [`T-008`](THREADS.md#t-008) |
| Superseded entries | `C81`, `C82` in the former C sequence |
| Raw provenance | Local ref `archive/c-era-raw-20260919`; exact source paths and hashes in `C_RECATALOG.json`. |

## Record

Recognized externally controlled bodies and verified the installed engine surfaces through which an NPC could drive. Former C82 was an evidence record with no mod-code change. This unit did not introduce autonomous driving; later C42 integrated it and the implementation audit found route ownership, steering and progress defects. Control ownership must remain exclusive through approach, boarding, travel and release.

## Evidence and continuation

The original evidence is retained at the source ref above. This consolidation does not independently revalidate every earlier capability. Current limitations and the next work are owned by [SESSION_STATE.md](../SESSION_STATE.md) and [SUBSTRATE.md](../SUBSTRATE.md).

[Former-label crosswalk](FORMER_LABELS.md) resolves every source entry. The unit joins immediately adjacent work with a shared implementation or evidence purpose.
