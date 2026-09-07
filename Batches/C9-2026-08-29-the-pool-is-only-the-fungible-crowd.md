# C9 - The pool is only the fungible crowd

| Field | Record |
|---|---|
| Batch | `C9` |
| Date | 2026-08-29 |
| Name | The pool is only the fungible crowd |
| Status | Closed append-only batch - play verification pending (no play receipt) |
| Threads | [`T-007`](THREADS.md#t-007), [`T-008`](THREADS.md#t-008) |

## Record

The operator's item 2, confirmed independent of any sibling project:
stop the blind deletion. Every survivor spawn paid its population cost
through `takeFromThePool` - `nearest.removeFromWorld()` on whatever
IsoZombie stood closest, no questions asked. And the zombie list is
not a list of fungible zombies: it holds the neighbour framework's
LIVING people (DR-009 - their bodies are zombie-backed), risen
players, and since [C8] the county's own marked dead. A spawn could
quietly delete a person.

**The class, not the instance.** The sweep the order demanded found
the same fungibility assumption in one more consumer and confirmed two
clean ones. `directNearestZombieAt` (the incoming-combat choreography)
picked the nearest body with no discrimination - it could point a
living neighbour at a shell as a zombie, or puppeteer a risen known
body whose brain is vanilla's (DR-016: one brain per body).
`beginCombatNearest` and the perception scanner already discriminated
through `isKnoxHuman` - the discipline existed and had never been
finished across its population.

**One predicate, deletion-grade.** `SAOKnox.identityBearing`: the Knox
marks (through the existing `isKnoxHuman`), `isReanimatedPlayer`, and
the [C8] `SAOPersonId` stamp - and it fails CLOSED, returning true
from its catch, because a body whose identity cannot be read is most
likely exactly a foreign mod's person, and sparing a fungible zombie
costs one zombie while deleting a person costs a person.
`takeFromThePool` skips identity-bearing bodies before choosing (the
honest "added, not exchanged" fallback unchanged);
`directNearestZombieAt` choreographs only the fungible crowd.
`beginCombatNearest` keeps its narrower `isKnoxHuman` skip on purpose:
fighting a RISEN body is legitimate - survival, and item 3's mercy -
it is deleting or puppeteering one that never is.

**The census closed.** Border 88 (`tools/pool_identity_test.py`)
holds the predicate's three checks and its fail-closed catch, both
previously-blind consumers, and a closed census of every
`.removeFromWorld()` in the Java tree - each occurrence must match a
declared, argued site, so a new blind deletion cannot appear without
arguing itself past the gate. Control: the pre-[C9] tree, which fails
four ways.

This governed record is the portable project history for this unit.
