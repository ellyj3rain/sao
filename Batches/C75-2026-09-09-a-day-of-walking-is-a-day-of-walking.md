# C75 - A day of walking is a day of walking

| Field | Record |
| --- | --- |
| Batch | `C75` |
| Date | 2026-09-09 |
| Name | A day of walking is a day of walking |
| Status | Closed append-only batch - awaiting its first live receipt |
| Threads | [`T-007`](THREADS.md#t-007), [`T-008`](THREADS.md#t-008) |

## Record

F-061, corrected. The dormant walk stepped `math.min(4, len)` tiles per
pass, and a pass means two different things in the two halves of the
county. Live, `dormantLife` runs every 240 frames and the move gate
opens every 1800 to 3600, so a game day holds hundreds of them. In the
years, `[C45]` advances the counter 3600 ticks per simulated day and
calls the pass once, so a day held exactly one. **Four tiles.**

Measured before anything was changed: **1.8 tiles per person per
simulated day**, over four counties on each of two trees. Three
simulated years carried somebody under two kilometres across a map
fifteen thousand tiles wide with towns hundreds of tiles apart.

`[C45]` chose one move per simulated day deliberately and its record
says why: *a simulated day advances that counter far enough to open
each gate about once. One move and at most one meeting per pair is what
a day deserves when nobody is watching it.* The reasoning is about
cadence - how often each frame-paced gate opens - and it never crosses
into distance. What one move is WORTH was never asked.

## Where the rate comes from, and where it does not

The operator's ruling: people move as much as they need to move to
satisfy their needs to survive. A per-day distance allowance is an
authored standard wearing a derivation's clothes, and the first draft
of this batch was exactly that.

**A real-world walking distance was tried first and abandoned.** The
repository anchors its population facts to sources - BRFSS 1993 for
smoking, the NCHS life tables for death by age, the Census for the sex
split - and a person's daily walking distance is the same kind of fact.
It cannot be used, because nothing in the installed build establishes
what a tile is in metres:

- the shipped map is not to a consistent scale - **1.28 to 2.71 metres
  per tile** across ten real Kentucky town pairs, a 2.1x spread
- `BaseVehicle.getCurrentSpeedKmHour` returns a JNI physics value
  rather than a conversion over tiles
- nothing in the shipped translations or Lua states a unit for a tile

That is F-062, and it is recorded so the figure can be re-derived if a
length is ever established.

**So the rate is the county's own.** `[C25]` ratified
`Places.comfortHorizon` as the home neighbourhood, *reached by a day of
ordinary living*, and it derives from the engine's own
`getCellSizeInSquares`. A day of walking reaches it; an hour reaches a
twenty-fourth of it; a goal further off takes the days it takes.

Nobody is capped. Where somebody goes is still need and knowledge
(DR-027) and a person whose water is four neighbourhoods away still
sets out - it takes four days. Distance stays the consequence of the
decision rather than a budget on it.

The pace of the age scales it, the same modifier `[C30]` already sets
on a live body: short legs and old ones both walk slower.

## What changed

The step is a rate over the county's own clock ([C62]) rather than a
constant per pass:

```lua
step = min(len, comfortHorizon() * pace * (hours since the last walk / 24))
```

Both halves read one rule, which is the law that loaded and unloaded
survivors are governed by the same rules ([B39], [B42]). And `[C45]`'s
cost is kept, because a day's distance is covered inside one pass
rather than by running a day's passes.

**The watched half changes too, and it is worth saying which way.**
An unloaded survivor near a player was already getting many passes a
game day, each worth four tiles, so their day added up to whatever that
count happened to be - a number nobody chose, that follows from the
population cadence, the move gate and the frame rate, and that differs
between a 60Hz machine and a 144Hz one. It is the ratified day-reach
now, the same as everywhere else. Whether that is more or less ground
than before depends on the machine it used to run on, which is the
point: it depended on the machine, and now it does not.

That is one corner of the county's pace being frame time rather than
real time, which is the operator's standing item. This does not settle
it - sixty-odd other timers still count frames - it takes one of them
off that footing.

## What it costs

A day that carries a day's walking is a day that does more work. A
person now crosses their neighbourhood instead of shuffling four tiles
in it, so the anchor `Places.around` and `nearestOffering` search from
moves constantly and the per-anchor result cache `[C25]` relies on
stops hitting.

Measured on the sweep, which is the only place this can be measured
before play: a county of 216 people over 1096 simulated days went from
roughly one minute to between seven and seventeen on the same machine,
with a long tail rather than a flat cost. Every process was checked
mid-run and each was burning CPU at the wall-clock rate, so the tail is
work rather than a stall. That is the
sweep's cost, not the game's - the years pass is bounded by
`YEARS_BUDGET_MS` at sixty milliseconds a tick and picks up where it
stopped, so what this changes in a real session is how many ticks a
county takes to catch up, not whether a frame is dropped.

It is stated rather than optimised. `[C45]` chose one pass per day over
the live cadence on a cost argument and that trade is unchanged; this
makes the pass itself heavier, and if a catching-up county becomes a
visible wait, the ring search is where the time is and slicing it
across ticks is the follow-up `[C25]` already named.

**Where the time actually goes, read rather than guessed.**
`Places.nearestOffering` caches its answer against an anchor quantised
to `RING_STEP`, thirty tiles. A walker covering four tiles a day sat
inside one quantum for a week and paid one ring sweep; a walker
crossing their neighbourhood crosses five quanta a day and pays five.
The cost is the cache doing exactly what it was written to do, against
a walker who now moves.

**And two growths this exposes**, both harmless while nobody moved and
neither of them measured.

`Pl.know_cache` is keyed by that quantised anchor with the offer and
the horizon, it is never evicted, and `Pl.reset` - the only thing that
would clear it - has no caller anywhere in the tree. The key space was
a few dozen anchors when a walker sat in one quantum for a week; it now
grows with the ground the county covers. It is module state rather than
saved state, so it dies with the session and no save carries it.

`Perception`'s `b.known` is the one that persists. `learnBuilding`
writes an entry per distinct building a person has entered - bounds,
offers, provenance and a visit count - it is pruned nowhere in the
tree, and it rides `[C15]`'s ModData bind into the save. A survivor
who covered four tiles a day entered almost nothing; one who crosses
their neighbourhood can enter somewhere new most days, so this grows
with the walking, per person, forever, in the save file.

Neither is fixed here and neither should be guessed at. It is the same
shape as the standing item about `s.relations` keeping a row for
everyone who ever lived: bounded cost is a measurement, and pruning
somebody's save is a judgement about their save. Both are queued in
`ROADMAP.md` with the measurement first.

That `b.known` grows is also what makes `[C76]` possible - a house
settles on the building its members keep returning to, which is exactly
what those entries record. The same growth is the feature and the
cost, which is the reason to measure it rather than trim it blind.

## What the county did with it

Twenty-four counties of 1096 days against the shipped map, same seeds,
before and after. Both taken on committed trees, after the last edit -
which is F-063's rule, paid for earlier the same day.

| | `[C74]` | `[C75]` |
|---|---|---|
| houses founded, median | 20 | **43** |
| houses standing at the end, mean | 0.3 | **1.1** |
| counties with a house standing | 8 of 24 | **14 of 24** |
| survivors in a house, mean | 0.8 | **2.3** |
| largest house, mean | 0.7 | **1.3** |
| alive at the end, median | 2 | **5** |
| died over the run, mean | 284.0 | 269.5 |
| counties with anybody alive | 16 of 24 | **22 of 24** |

**The county's social life was not failing because the social model was
wrong.** It was failing because nobody could walk far enough to meet
anybody. Houses founded more than doubled, houses standing after three
years went from a mean of 0.3 to 1.1 and from a third of counties to
well over half, and the number of people alive at the end nearly
doubled while deaths fell.

Nothing in this batch touched a company, a meeting, a trust number or
the goal path. `[C67]` made companies able to form, `[C68]` let a death
leave one, `[C71]` let people know each other, `[C72]` let them decide
to go to each other - and all four were measured in a county whose
people covered four tiles a day. Every one of them was doing more than
its own measurement could show.

One row moved the other way and is reported rather than smoothed:
pairs above the company line fell from 263.6 to 237.9. It is not a
target and nothing here aims at it; the plainest reading is that a
county where people actually meet is one where standings move in both
directions instead of sitting where genesis left them, but that is a
reading and not a measurement, and the number is stated so somebody can
disagree with it.

## A correction this batch carries

Chasing why two sweep runs of the same thing disagreed established that
they do not: the sweep is reproducible, and a fresh run of the `[C74]`
tree reproduces an earlier one figure for figure. The trees differed.

`[C72]`'s own before-and-after table was launched and then that batch
kept being worked on - the genesis sighting and the refusal of a goal
the walker is already standing on both landed afterward - so it
reports a tree that never shipped. On the tree that did, houses
standing is 8 of 24 rather than 5, against `[C71]`'s 6. The record's
conclusion that nothing moved is wrong in its direction, though 6
against 8 over 24 counties is still a difference this sample cannot
separate from noise.

F-063 carries it, `SESSION_STATE.md` carries the corrected figures, and
`[C72]`'s record stands as written because the ledgers are append-only.
The rule it pays for: a measurement that closes a batch is taken on the
tree that is committed, after the last edit.

## Border 140, and its control

`tools/walk_rate_test.py`, in the gate. It runs the shipped module in
the engine's own VM, moves the county's clock by hand, and reads the
walker's position. A border reading `comfortHorizon` out of the source
would pass a tree that computed it and stepped four tiles anyway.

| Property | What it reads |
|---|---|
| a day of clock is a day of walking | ground covered over 24 county hours in one pass |
| an hour is an hour's worth | the same over one hour, against the day |
| the two halves agree | one pass against twenty-four, same day |
| nobody overshoots | a goal nearer than the day's reach |

Its floor is a tenth of the day's reach rather than the reach itself,
because the pace of the age is drawn per person and lives in
`[0.65, 1.0]`. A tenth sits far below any pace and far above the four
tiles a pass used to deliver, so it separates the two without pinning
either.

Its control is the `[C74]` tree, and it names the defect rather than
merely failing: a day of county clock carries four tiles, an hour
carries four, and a day delivered in twenty-four passes covers
ninety-six while the same day in one pass covers four - the two halves
of the county disagreeing, printed.

**It refused three times first, and each refusal was worth having.**

Its seam for "no constant tile step survives" matched the phrase
`math.min(4, len)` inside the comment explaining that the constant had
been retired. That is GOVERNANCE's prose-is-not-code clause, hit by the
border written to hold a batch that quotes its own history. Comments
are stripped before the search now, which is Border 99's rule.

It measured a walker's very first pass, which correctly covers nothing:
a record the county has never looked at has no previous reading to
measure a span from. Each walker is warmed by one pass now, and the
seeding is not mistaken for the walking.

And its parity test used two different walkers. The pace of the age is
drawn per person, so it was comparing two paces and passing on which
ids they happened to get; it uses one walker for both deliveries now,
and the tolerance tightened from a fifth to a twentieth because the two
answers are the same arithmetic delivered differently.

**And the batch's own first draft banked idle time.** The clock was
read only where there was somewhere to walk, so somebody standing at
their goal for a week accumulated the hours and would have crossed the
county in one stride the moment they were given a new one. The clock is
read every pass now, and Border 140 holds the property so the next
draft cannot lose it.
