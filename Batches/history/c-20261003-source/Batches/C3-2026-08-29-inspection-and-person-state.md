# C3 - Inspection and person state

| Field | Record |
|---|---|
| Batch | `C3` |
| Date | 2026-08-29 |
| Date range | 2026-08-29 to 2026-08-29 |
| Name | Inspection and person state |
| Status | Consolidated historical record; implementation limitations remain explicit. |
| Threads | [`T-006`](THREADS.md#t-006), [`T-009`](THREADS.md#t-009) |
| Superseded entries | `C6`, `C7` in the former C sequence |
| Raw provenance | Local ref `archive/c-era-raw-20260919`; exact source paths and hashes in `C_RECATALOG.json`. |

## Record

Added the inspection harness and integrated the person state visible through it. Existing menus carry the inspection and command surfaces through shared ownership prediction, with a fallback where those menus are unavailable. The harness exposes simulation state and diagnostic controls; observation alone does not establish completed behavior.

## Evidence and continuation

The original evidence is retained at the source ref above. This consolidation does not independently revalidate every earlier capability. Current limitations and the next work are owned by [SESSION_STATE.md](../SESSION_STATE.md) and [SUBSTRATE.md](../SUBSTRATE.md).

[Former-label crosswalk](FORMER_LABELS.md) resolves every source entry. The unit joins immediately adjacent work with a shared implementation or evidence purpose.
