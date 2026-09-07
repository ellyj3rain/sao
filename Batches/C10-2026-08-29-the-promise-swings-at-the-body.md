# C10 - The promise swings at the body

| Field | Record |
|---|---|
| Batch | `C10` |
| Date | 2026-08-29 |
| Name | The promise swings at the body |
| Status | Closed append-only batch - play verification pending (no play receipt) |
| Threads | [`T-002`](THREADS.md#t-002), [`T-006`](THREADS.md#t-006) |

## Record

The operator's item 3: the promise keeper's mercy kill was
`orderEngageNearest` - the nearest zombie to where the turned was
SEEN, which after any wander is a stranger's body. Mercy for the
wrong dead is nobody's mercy, and the person the promise was for
still walks.

**Aimed by identity.** [C8] put the one identity that survives the
turn on the risen body (the modData mark), so the keeper can now aim:
`beginCombatWithPersonId` finds the ONE body carrying the person's id
within `PROMISE_BODY_REACH` (8 tiles - wider than arrival because the
body wanders while the keeper walks, narrower than the follow reaches
because past that the sighting is stale) and opens the same combat
loop the named-person entry uses. This is the argued exception to
[C9]'s identity skip, stated at the verb: mercy FIGHTS the risen
known face - the keeper's own promise, a kill and never puppetry -
where [C9] forbids deleting or choreographing one.

**A miss carries the promise.** The promise is cleared - and the
`promiseKept` word spoken - only when the swing actually began
(`COMBAT_STARTED`). The body gone from the site is an honest
`BODY_NOT_FOUND`: the promise stays carried, the next sighting
re-arms the walk, and no nearest-body fallback exists on this path
any more. The three-tries damper on unreachable walks is unchanged.

**The border.** Border 89 (`tools/promise_body_test.py`): the verb
keys on the mark and misses honestly; the keeping block aims at it,
carries on a miss, and contains no `orderEngageNearest`; the reach is
named. Control: the pre-[C10] tree, which fails five ways.

This governed record is the portable project history for this unit.
