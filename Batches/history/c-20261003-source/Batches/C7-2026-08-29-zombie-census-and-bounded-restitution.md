# C7 - Zombie census and bounded restitution

| Field | Record |
|---|---|
| Batch | `C7` |
| Date | 2026-08-29 |
| Date range | 2026-08-29 to 2026-08-29 |
| Name | Zombie census and bounded restitution |
| Status | Consolidated historical record; implementation limitations remain explicit. |
| Threads | [`T-007`](THREADS.md#t-007), [`T-009`](THREADS.md#t-009) |
| Superseded entries | `C16`, `C17` in the former C sequence |
| Raw provenance | Local ref `archive/c-era-raw-20260919`; exact source paths and hashes in `C_RECATALOG.json`. |

## Record

Added the dead census, durable crowd ledger and optional debt-bounded zombie restitution. With RestoreTakenZombies enabled, the engine addVirtualZombie surface repays prior pool takes beyond the hibernation radius, at most six per daily pulse; the setting defaults off. Measurement and this limited mutation do not establish demographic calibration or complete population dynamics.

## Evidence and continuation

The original evidence is retained at the source ref above. This consolidation does not independently revalidate every earlier capability. Current limitations and the next work are owned by [SESSION_STATE.md](../SESSION_STATE.md) and [SUBSTRATE.md](../SUBSTRATE.md).

[Former-label crosswalk](FORMER_LABELS.md) resolves every source entry. The unit joins immediately adjacent work with a shared implementation or evidence purpose.
