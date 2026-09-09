# C76 - A house takes ground where its people already go

| Field | Record |
| --- | --- |
| Batch | `C76` |
| Date | 2026-09-09 |
| Name | A house takes ground where its people already go |
| Status | Closed append-only batch - awaiting its first live receipt |
| Threads | [`T-004`](THREADS.md#t-004), [`T-003`](THREADS.md#t-003) |

## Record

`setGroupClaim`, `setHearth`, `setLarder` and `setWaterStore` had call
sites in `SAO_Controller` alone, which needs materialised bodies. After
`[C67]` and `[C68]` houses form and settle their dead; after `[C71]`
and `[C72]` their people can know each other and go to each other; and
a house in the unwatched county still had nowhere to be. Every survival
modifier reading a hearth, a larder or a water store was inert unless a
player happened to be watching.

## Where the decision comes from

The live path scouts through `SAOJavaBridge:scoutBase`, which reads the
loaded ground and needs a body. The dormant half has none and needs
none, because the fact already exists.

`Perception.learnBuilding` has recorded every arrival since `[B37]` -
the building's bounds, what it offers, how it was come by, and how many
times that person has been. Its own comment says what the count means:
*somewhere returned to is somewhere that gave them something.*

So a house settles on the building its members keep returning to.
Nothing is scored that the county did not already measure by walking.

**Two returning outweighs one returning often.** The visits are summed
across the house's living members and multiplied by how many of them
have been, because a place a house SHARES is what a base is. Water
doubles it, and it is the only offer weighed: it is the need that kills
first ([B37]) and the one a building either has or has not.

**Nothing is placed.** A house whose people have never gone back
anywhere has no candidate and takes no ground. That is a correct
outcome rather than a failure - a frightened pair with one room they
sleep in is a house, and competency follows from who is in it. A house
of one takes nothing either, because a group of one is a memory rather
than a membership (`[C67]`'s widow rule).

**The refusals are the live path's own**, lifted into `barredGround` so
the two readers share one law rather than drifting apart the way
`[C25]` describes: never over another living company's claim, never
over a living person's home - including the player's, who holds ground
under a `player:` key and has no Identity record, which is `[B35]`'s
defect - and never inside a feuding company's keep-out (`[A20]`).
Contested ground comes from politics, not from blindness.

**Homes converge**, as they do on the live path: the members' own
anchors move to the base, so the dormant day walks from there with no
further wiring.

## What it costs, and what bounds it

One house a pass - `SETTLE_BUDGET`, with the walk breaking at it -
which is `[B51]`'s discipline. The walk is a house's
members times the buildings they have each entered, and `b.known` grows
with the walking - `[C75]` established that - so an unbudgeted sweep
over every unsettled house would get more expensive exactly as the
county got more interesting. A house settling a day later than it could
have is not a cost anybody can see.

A settled house is skipped entirely, because `groupClaimOf` answering
IS the skip, so the pass costs nothing once the county has settled.

## What this deliberately does not do

**A house cannot leave.** It settles once. A group deciding to go, or
holding a base in one town with stash houses around it, is not
representable at all while a group's ground is one rectangle under one
name - which is DR-006 S4 and the operator's named ontology error. That
is its own batch and nothing here smuggles it in.

**The hearth and the larder are still the controller's.** This gives a
dormant house ground. What it does with the ground - lighting a fire,
stocking a shelf - reads state a body produces, and is not touched.

## Border 141, and its control

`tools/settle_test.py`, in the gate. It builds four houses in the
engine's own VM, runs the real pass through the tick handler the mod
registers, and then reads `Standing.groupClaimOf`. A border asserting
that the pass calls `setGroupClaim` would pass a tree that called it
with the wrong building, or with ground somebody else holds.

| Property | Measured |
|---|---|
| a house settles where its people keep going | the claim's centre against the shared building |
| two returning outweighs one returning often | a rival building one member visited more |
| nothing is placed | a house whose people never returned anywhere |
| a house of one takes nothing | the widow rule, at the ground |
| never over another company's claim | ground already held |
| homes converge | a member's own anchor after settling |

Its control is the `[C75]` tree, where no dormant house ever takes
ground at all.

## Two borders refused this batch, and both were right

**Border 74** caught the walk before it was declared: the settling pass
walks `Identity.all()`, which is the whole store including every grave,
on a 240-frame cadence, and nothing said what bounded it. Declared -
and then refused again, because the first draft held itself back with a
boolean flag rather than a budget the loop breaks on, so it kept
walking the store after it had already settled a house. It is
`SETTLE_BUDGET` with a real break now, which is better code than the
flag was: the walk stops when the work is done.

**Border 118** caught the day: `[C45]`'s own rule is that every call in
a simulated day is the live county's own, and its list is by name.
`dormantSettle` is run by `populationTick` as a sub on the live
cadence, so this is `dailyCounty`'s case rather than
`lookAtSomeGround`'s - the years call the same function rather than
reaching past it - and the entry says so, because a list by name goes
stale silently otherwise.
