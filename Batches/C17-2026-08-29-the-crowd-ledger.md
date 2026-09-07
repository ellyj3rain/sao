# C17 - The crowd ledger

| Field | Record |
|---|---|
| Batch | `C17` |
| Date | 2026-08-29 |
| Name | The crowd ledger |
| Status | Closed append-only batch - play verification pending (no play receipt) |
| Threads | [`T-007`](THREADS.md#t-007) |

## Record

DR-021's second half, scoped to its first honest slice. The
operator's state-agreement constraint, verbatim in the DR: the county
already takes its living out of the vanilla bulk ([B21]'s pool), the
presence layer adds to that same bulk, and two systems mutating one
crowd need one accounting - "even if both are controllable and
configurable."

**The ledger.** Every successful pool take is counted (a monotonic
session counter on the bridge, folded into the durable
`SurvivorAwareness_CrowdLedger` store on the daily pulse). The fold
runs regardless of any dial: the truth accrues whether or not anyone
is repaying it, so a late enable has a real history to repay.

**Restitution, debt-bounded.** With the new dial on, the county
returns one virtual zombie to distant town ground per body the pool
took - at most `RESTITUTION_PER_DAY` (6) per pulse, so accumulated
history repays at a walk; jittered off a spawn-region town point (the
census's own where-people-crowded anchor); always beyond the
hibernate radius ("never near you" is the genesis law and this layer
is not above it); through the engine's own `addVirtualZombie`
(javap-verified `static (int,int)` - the native pool carries them
until streamed). The layer NEVER invents presence: it repays
`taken - added` and nothing else, because the derived totals
(~8,000-13,500) stay unratified until the [C16] census has measured
(DR-021). Crowded-area bulk beyond restitution, and the highway
corridors, are the measured next slice - named here, not smuggled in.

**The dial.** `RestoreTakenZombies`, boolean, DEFAULT FALSE per
DR-021's off-until-measured posture, with plain copy (DR-018)
declared in Border 92's ratified set as part of this batch's report.

**The border.** Border 96 (`tools/crowd_ledger_test.py`): the take
counted at its source, the counter read by the fold, the fold ahead
of the dial, restitution bounded by the debt at a named pace beyond
the hibernate radius through the engine's own add, and the dial
shipping off. Control: the pre-[C17] tree, which fails nine ways.

This governed record is the portable project history for this unit.
