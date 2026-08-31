# Version map

The regulatory version replay: contiguous capability units over the closed
chronology, without rewriting the batch records. Threads classify work across
time; version units partition time; batches remain the atomic historical record.

| Field | Current state |
|---|---|
| Form | `major.minor.kohai.patch-maturity` |
| Replay start | `0.1.0.0-pre-alpha` |
| Current version | `0.6.0.0-pre-alpha` |
| Closed chronology | `A1-B52` |
| Next batch | `C1` |
| Executable source | none yet - this document is the record; a replay tool is C-era work |

## Tier meanings

| Tier | Meaning here |
|---|---|
| major | Project-identity or supported-compatibility boundary. Nothing so far. |
| minor | A new player-visible capability or a new contract. |
| kohai | A coherent extension or maturation of an existing capability. |
| patch | An in-place correction that does not change a capability boundary. |
| maturity | `pre-alpha -> alpha -> beta -> rc`; can move without a coordinate. |

## Chronological replay

Boundaries map onto the recataloged units; where a raw version boundary fell
inside what is honestly one piece of work, the unit's span is noted under the
rationale rather than split to satisfy the arithmetic.

| Unit | Batches | Dates | Tier | Resulting version | Name | Boundary rationale |
|---|---|---|---|---|---|---|
| VU-001 | A1-A5 | 2026-08-25 | initial | `0.1.0.0-pre-alpha` | Repository, engine verification, first survivor, the pillars | The repository's establishment and the verified substrate; formerly A1-A9. |
| VU-002 | A6-A11 | 2026-08-25/26 | minor | `0.2.0.0-pre-alpha` | The framework meets play | Combat, deeper perception, the persistent world, then the needs and social layers and persistence; formerly A10-A50. |
| VU-003 | A12-A14 | 2026-08-26 | minor | `0.3.0.0-pre-alpha` | The social economy and the society arc | Gifts, barter, debts, companion; then claims, lessons, leaders, settlement, membership, habits, bonds; formerly A51-A70. The 0.3 boundary fell inside what is now A12's span. |
| VU-004 | A15-A24 | 2026-08-26 | minor | `0.4.0.0-pre-alpha` | Epistemics, inhabitation, and the workday | Belief-gated permission, adoption, the census, the four answers, the political ladder; formerly A71-A151. |
| VU-005 | A24-A29 | 2026-08-26 | minor | `0.5.0.0-pre-alpha` | The written county and its media | Identity textures, the Ledger window, the wire both directions, governance of the player, derived possessions, day zero; formerly A152-A200. |
| VU-006 | B1-B52 | 2026-08-26/28 | minor | `0.6.0.0-pre-alpha` | The material county under a gate | The material economy and politics against instruments that now run on every commit; the era's method made verifiable. |
