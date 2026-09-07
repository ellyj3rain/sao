# C18 - The first play receipts

| Field | Record |
|---|---|
| Batch | `C18` |
| Date | 2026-08-29 |
| Name | The first play receipts |
| Status | Closed append-only batch - three defects found IN PLAY, fixed; one anomaly unresolved |
| Threads | [`T-001`](THREADS.md#t-001), [`T-008`](THREADS.md#t-008) |

## Record

The operator played the deployed build and the county's log answered
questions no border could. Every batch before this one was
structurally verified only; this is the first unit whose findings come
from a running game.

**F-049, the standing crowd.** The operator's report: clustered up
around a house for some reason, and not moving. The log gave
the mechanism exactly: 292 `IDLE -> FLEE` and 292 `FLEE -> IDLE` in
one session, and under them a route restarting forever -

```
order sao-322 -> 10732,9479,0
ManualRoute
order sao-322 -> 10732,9479,0    (17 frames later, SAME goal)
Transition:TURNING_TO_FENCE -> STARTED_FENCE_CLIMB -> TURNING_TO_FENCE
FLEE -> IDLE (done:Failed)
IDLE -> FLEE (believed threat at 1.0 tiles, count=7)
```

The controller re-decides on its own cadence and re-issued the
destination whether or not the last order was still being walked.
Every order recomputes the path, so the body advanced about half a
tile per re-order and any window or fence climb ([C4]) was cancelled
mid-transition and restarted. The route eventually failed, which
returned the survivor to IDLE, where the same believed threat sent
them straight back into FLEE. Fixed at the source rather than in
FLEE: `Loco.order` now holds a live route whose goal has not moved
more than `RETARGET_REACH` (2 tiles), so a walk can finish. Every
state that re-orders benefits, not just flight.

**F-048, two exceptions the gate could not see.** 276 throws from
`SAO_Places.lua` - `absorb` read item lists as "name, weight, name,
weight" and stepped by two, but the engine's lists do not all have
that shape, so it skipped half the names in one shape and handed a
weight to `getItem()` in the other. Every throw abandoned the rest of
that room's contents, so what a place offers ([B38]) was being read
half-blind. Now it takes the strings and assumes no layout. Plus 2
throws from `SAO_History.lua`, where a claim pick landed outside a
table the line above proved non-empty; the arithmetic is exact
integers and the cause is NOT established, so the guard skips the
claim and logs the numbers rather than inventing a reason.

**Named apart.** `SHOT_ORIGIN_REACH` - how close a person you can see
must be to a shot you only heard before you are judged its author -
was a bare 4.0 sharing a value with the new retarget slack. Named so
moving one cannot move the other; the bare-reach census came down
14 -> 13 with it.

## What this batch did NOT establish

The operator saw a survivor with no clothes, ignored by zombies,
unhittable, and unresponsive to menu clicks. Three explanations were
advanced and all three were wrong: a stale belief-table alias (ruled
out - every read re-resolves), a corpse-stripping loot path (ruled
out - it takes one Food or HandWeapon and never clothing), and "these
are the neighbour framework's people, not ours" (ruled out by the
operator, and by a miscount of mine: `materialized` lines are TALLIED
by the [B47] logger, so counting them undercounts bodies badly - the
controller ticked NINE survivors that session while one line printed,
and the one that printed said `dressed=true`).

The anomaly is open and stated rather than closed with a story. What
would settle it: the inspect panel on that body, which says whether
the county knows the person at all.

This governed record is the portable project history for this unit.
