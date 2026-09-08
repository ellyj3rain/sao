# C41 - The world before the spawn

| Field | Record |
|---|---|
| Batch | `C41` |
| Date | 2026-09-07 |
| Name | The world before the spawn |
| Status | Closed append-only batch - awaiting live receipts (a fresh save logging the county generated in one pass before anyone was spawned; the first survivor met standing in a county that is already full; a second load pacing normally) |
| Threads | [`T-007`](THREADS.md#t-007), [`T-002`](THREADS.md#t-002) |

## Record

One precondition of DR-036, and only that. The goal that ruling
records is a player checking the box for day zero and watching the
whole decay happen - and, where they start at a distance from the
fall instead, a county that has already lived those months. This
batch does neither. It does the thing that has to be true before
either can be: there is a county there to watch.

**What was actually wrong.** Genesis paced at six people per pass
whatever the state of the save - written for a county that grows
while somebody plays, and it did exactly that. A sixty-person county
took about a minute of play to exist, so the first survivors a
player met had woken into a world with almost nobody in it, and the
county accreted around the player rather than being there first.
That is not a pacing choice, it is a world that does not exist yet
being shown to somebody.

**The change.** On a save that has never been settled the budget is
the county's own target rather than six, so genesis reaches the
target in one pass. Because this subsystem already runs ahead of the
band in the tick rotation, that pass finishes before the first body
is materialised: the record side of the world is complete before
anybody is spawned into it. The cost is paid on the first tick of a
new save, where a pause is expected, and it is bounded by the target
the options screen already sets.

**Afterwards, nothing changes.** Once the county exists the old
pacing stands exactly as written, because from then on it is refill
and not creation - the road, the newcomer, the replaced dead - and
those are events in a world that already exists. The flag that says
which case this is lives in the county's own store and is written
only when the target is actually reached, so a run interrupted half
way carries on next pass instead of pacing a half-built county for
the rest of the save.

**Two numbers that were one rule.** A bare six bounded the pass and
a bare eight bounded a unit two hundred lines below it - the same
rule spelled twice, and the second was the slack that keeps a family
from being cut in half at the budget's edge. Both are named now, and
the slack is derived from the pace rather than sitting beside it.

**What is NOT generated first, and why.** Houses, leaders, creeds
and feuds. Those are derived facts in this design: a company needs
three people who have actually met, and a leader is the sum of what
the others think of them. Authoring them at genesis would be
authoring the same thing twice and would break the law the county
rests on. What every person gets first is what genesis always gave
them - the past and its trait echoes, the trade and the ground it
began on, the place they woke in as a lived belief, a home claim
from the first day, and the unit they began in with its bonds.

**Border 115** reads the budget off the source rather than assuming
it, holds the pace to one name, refuses the bare six and the bare
eight, checks the flag is written only on reaching the target, and
holds the ordering law the whole claim rests on: genesis before the
band in the tick. If that order ever inverts, the batch becomes a
lie and nothing else in the tree would notice. It also holds that
the per-person work is still in the loop, so a refactor cannot
quietly make the county faster by making its people emptier.

**Not in this batch, and the batch is not the goal.** The Day Zero
arc's own unbuilt slices, which are DR-036's near end and the
priority: outbreak dynamics, chaos legibility, ventures socialized,
vehicles as composition. The elapsed clock and the days actually run
forward for a later start; what a place becomes over years;
knowledge accumulating and decaying across the span; the dead of
those years. The communication pipeline and its training, the
operator's other named gap. A county generated with no engine loaded
at all, DR-033's third fork, which stays unscoped. Houses at
genesis, for the reason above.

This governed record is the portable project history for this unit.
