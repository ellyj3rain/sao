# C34 - Decision capture and ratified data preparation

| Field | Record |
|---|---|
| Batch | `C34` |
| Date | 2026-09-10 |
| Date range | 2026-09-09 to 2026-09-10 |
| Name | Decision capture and ratified data preparation |
| Status | Consolidated historical record; implementation limitations remain explicit. |
| Threads | [`T-004`](THREADS.md#t-004), [`T-006`](THREADS.md#t-006), [`T-008`](THREADS.md#t-008), [`T-030`](THREADS.md#t-030) |
| Superseded entries | `C83`, `C84`, `C85`, `C86`, `C87`, `C88` in the former C sequence |
| Raw provenance | Local ref `archive/c-era-raw-20260919`; exact source paths and hashes in `C_RECATALOG.json`. |

## Record

Added decision-moment capture beside the county sweep, recorded the first ratified work-word rows, exposed engine names and occupations to the harness, enriched belief provenance and retained the needs that conditioned a work decision. The later audit reproduced mutable snapshot leakage in this exporter. Approved choices remain ratified while their source conditioning requires review.

## Evidence and continuation

The [implementation audit](../artifacts/audits/20260919-0356Z-2056PST-c112-c126-implementation-audit.md) provides reproduced defects and source traces. Its C identifiers refer to the former sequence. Consolidation preserves those findings and does not certify the affected behavior.

[Former-label crosswalk](FORMER_LABELS.md) resolves every source entry. The unit joins immediately adjacent work with a shared implementation or evidence purpose.
