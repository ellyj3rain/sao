# A16 - Approval-chain repair, first live witness, county scale, coexistence

| Field | Record |
|---|---|
| Batch | `A16` |
| Date | 2026-08-26 |
| Name | Approval-chain repair, first live witness, county scale, coexistence |
| Status | Closed append-only batch - play verification pending (no play receipt) |
| Threads | [`T-008`](THREADS.md#t-008), [`T-030`](THREADS.md#t-030) |
| Superseded entries | `A76`-`A81` |
| Local Git commits | `5891f04`, `6e19a7c`, `720f81f`, `980bf0c`, `dbcd8e3`, `ea1c5b8` - local Git retains the full pre-seam history as engineering evidence |
| Provenance | Joined with immediately adjacent entries: the prior assistant fragmented this single piece of work across the listed raw entries; their substance is consolidated here. That fragmentation is the reason this catalog exists, and this note is its attribution. |

## Record

The theory met the game. The first full session never loaded: ZombieBuddy's
approval store keys on jar hash, and diligent redeploys had been orphaning the
mod's own approval (F-023) - fixed by approving the current hash and by
teaching the deploy script to upsert it so a deploy can never orphan itself
again. Then the first witness, quoted from the live console: the county
genesis ran in real towns (Muldraugh, March Ridge - region-balanced, never
around the player), the self-attached melee patch passed its three calls, the
epistemic clock produced correctly unmarked fresh survivors, six records from
the earliest era survived the save untouched, and nothing blamed this mod in
the error stream. On that momentum the county grew to its real scale (DR-008):
population defaults to 60 with paced genesis and budgeted dormant sweeps. And
the other workshop population stopped being read as the dead: KnoxSurvivors'
people are zombie-backed, so the scanner now discriminates (their own
variables and modData), a Knox human scans as a person, combat refuses them
on both sides by construction, an attacker's tag carries the person, and the
one-representation-per-save rule holds (their store is read-only, their
bodies never driven).

This governed record is the portable project history for this unit. Anything it
was found to have asserted against later corrections is corrected in place above
with the correction cited; the raw entries remain reachable through
[`FORMER_LABELS.md`](FORMER_LABELS.md).
