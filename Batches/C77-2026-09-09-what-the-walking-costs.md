# C77 - What the walking costs

| Field | Record |
| --- | --- |
| Batch | `C77` |
| Date | 2026-09-09 |
| Name | What the walking costs |
| Status | Closed append-only batch - verification closure; owes no play receipt of its own |
| Threads | [`T-008`](THREADS.md#t-008), [`T-009`](THREADS.md#t-009) |

## Record

`[C75]` let the county's people cross their neighbourhoods instead of
shuffling four tiles in them, and named two growths it could not
measure at the time: `Places.know_cache`, keyed by a quantised anchor
and evicted nowhere, and `Perception`'s `b.known`, an entry per
building per person riding `[C15]`'s ModData bind into the save.

Both are measured now and neither is a problem. The batch is the
measurement and the two findings it produced; nothing under `mod/`
changes.

## What was measured

Six counties of 1096 days on the shipped tree:

| | min | median | max |
|---|---|---|---|
| buildings known, whole county | 4 | 110 | 347 |
| ... most held by any one person | 2 | 48 | 109 |
| people holding any | 2 | 3 | 16 |
| place-knowledge cache keys | 766 | 805 | 863 |

The shipped map has 2,831 buildings. The survivor who knows the most
knows 109 of them.

## F-064 - the engine tears the Lua state down

`zombie.gameStates.IngameState` is the only game state that calls
`LuaManager.init()`, and the call is in **`exit()`** - leaving a world,
at the end of a teardown block that also resets the fence, overlay,
perk and sandbox-option singletons.

So a world's module state cannot reach the next world, which is the
fact `[C15]` was already built on when it bound the perception store to
ModData. `Places.reset` having no caller is not an oversight; the
engine does the job.

**Two wrong readings were each one `javap` from the record.** An
uncalled cleanup function reads like an oversight. Then the engine's
own answer read as init-on-entry when it is teardown-on-exit, and the
difference is which method the call sits in.

## F-065 - and `b.known` is pruned by dying

`[C75]`'s record said `b.known` was "pruned nowhere in the tree". That
was wrong. `Perception.forget(id)` drops the whole belief store -
`P.beliefs[id] = nil` - and `Identity.markDead` calls it, which is the
funnel every death path reaches, added at `[B51]` for exactly this
purpose.

So the count is bounded by the LIVING rather than by everyone who ever
lived, and the measurement shows it plainly: the people holding any
known places are exactly the people still alive.

**How the misreading happened.** The search was for `known[...] = nil`
and `known = {}` inside `SAO_Perception.lua`, and neither exists,
because the pruning is one level up - the whole store goes, not the
field. Searching the narrow spelling instead of the mechanism is
`[C70]`'s defect and GOVERNANCE's prose-is-not-code clause arrived at
from a third direction.

## No new border, and why

Nothing here is behaviour, and the two findings are about mechanisms
that already exist and already work. A border asserting that
`markDead` calls `Perception.forget` would be worth having - and
Border 136 already holds the death funnel's forgets, which is where
that assertion belongs rather than in a second border beside it.

The measurement itself is a scratch instrument and stays one, for the
reason `[C69]` gives about the sweep: a growth over a county is a
distribution, and a build gate that turned it into a pass or fail would
force a deterministic result over the thing being measured.

## What this retires, and what it does not

Both growth entries come off `ROADMAP.md`'s queue. Nothing needs
pruning, nothing needs a budget, and no save grows without bound.

What remains from `[C75]`'s cost is the one thing a sweep cannot
measure: how many ticks a real catching-up county takes before anyone
can be materialised. A county sweep went from about a minute to between
seven and seventeen, and what that is worth in a session is a play
receipt.
