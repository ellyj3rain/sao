# C65 - The years pass leaves a trajectory

| Field | Record |
|---|---|
| Batch | `C65` |
| Date | 2026-09-08 |
| Name | The years pass leaves a trajectory |
| Status | Closed append-only batch - awaiting live receipts (a 1996 start whose `SAO_telemetry.jsonl` holds one run line, about a thousand county lines under one run identifier, and a closing line naming who was left) |
| Threads | [`T-009`](THREADS.md#t-009), [`T-007`](THREADS.md#t-007) |

## Record

The operator ruled that a late start cannot afford first-principles
generation at distance, and chose a learned trajectory model fitted to the
generator's own per-year runs.

There were no runs. `[C45]` lives the days a later save owes by mutating
state in place, so the county at the end answers "what is this county like
now" and destroys "what happened", which is exactly the thing being
modelled. The only lines that reached the telemetry file during a span of
years were the incidental death and lesson events, with no boundary around
them and nothing about what the county held.

`SAO_Telemetry` was already the right surface and said so at `[B38]`: "A
daily snapshot of two hundred people answers what the county is like now
and destroys what happened." The instrument was built on the argument this
batch needed. It was never pointed at the years.

Three things were missing.

**A run boundary.** The file is append-only across every session on the
machine. Without one, the lines from three different counties interleave
into a single stream that reads like one county behaving impossibly.

**What the run was run under.** Two runs with identical population curves
can have had opposite risk settings, and no sandbox dial is recoverable
from the county lines afterwards.

**What the county held.** The county line counted living, dead, lessons and
units. It declared `dry` and `hungry` and never assigned or emitted them,
so it said nothing about need - the pressure that drives most of what the
county does - and nothing about groups, claims, or how shut the places are,
which are the outcomes the years are run to produce.

## What changed

`T.event` stamps `run` on every line while a run is open, and on none
outside one, which is what live play is.

`T.run(phase, fields)` opens and closes a span. `T.conditions()` reads what
it was run under off the sandbox and the record: the risk multiplier, the
trust line, desperation, refill days, road traffic, the population and
newcomer settings with their governed flags, the day-zero switch, the
save's own start date, and the days owed.

The run identifier is made once and kept in the save. A span sliced across
hundreds of passes and possibly a reload is ONE run; an identifier made per
pass would cut a single county's history into two thousand runs of one day
each. It is restored rather than regenerated on re-entry, and cleared when
the span closes.

The county line gained `dry`, `dryDaysMax`, `hungry`, `hungryDaysMax`,
`groups`, `grouped`, `largestGroup`, `claimsHeld`, `waysIn` and `waysShut`.
The need figures count PEOPLE who have gone a day or more without, plus the
worst case, because the tail is what kills and a mean hides it. No
threshold is invented here: the patience constants belong to the attrition
roll and stay there. The fortification figures are `[C46]`'s survey, which
until now only the inspect panel ever read.

`oneYearsDay` writes one line per simulated day. A thousand lines is
nothing beside what producing them cost.

**Border 133** drives the real `SAO_Telemetry` in the engine's own VM
against a stub county of four, with `getFileWriter` stubbed to capture what
is written - so every assertion is made against the actual JSONL the module
emits rather than against its source. Three living and one dead, one person
five days dry, one nine days hungry, two groups of two and one, two claims,
twelve ways in and three shut: every figure comes back on its predicted
value. The run line carries its conditions, a line written during a run
carries the identifier and a line written after it does not.

Its control is the tree at `[C64]`, where the county line carries seven
fields and none of the ten, and no run line is written at all.

## What was measured before it was designed

`SAO_Telemetry` was read before anything was written, and two things came
out of reading it that were not in the plan.

`dry` and `hungry` are declared in `T.county` and never assigned. Dead
locals since `[B38]`, and precisely two of the fields a trajectory needs.

`T.county`'s own comment says "the county once a day" and its only caller
is `bootDigest`, which runs on the first population tick of a session and
never again. In live play it is once per load, and the sentence describing
it had been wrong for the whole B era. The comment now says what the
function does.

## What the gate refused, and what that was worth

The first draft of this batch failed three borders, and every one of them
was right.

**Border 118** refused a simulated day calling `SAO.Telemetry.county`,
because the live county does not run it on its own cadence, and a call that
exists only in the years is the pass inventing rather than living. The first
draft had deferred the daily hook to a later batch and said so under "not in
this batch". That deferral was the defect: `[B38]` claimed the county line
was written once a day and wired it to `bootDigest`. Live play has the daily
cadence now, `dailyCounty` is one function run by both, and Border 118
admits it by name with the reason rather than as an exception.

**Border 33** caught five fallbacks in `T.conditions` that were not the
numbers the options screen declares - desperation, refill days, road
traffic, population and newcomers all fell back to zero. A run left on
default settings would have been recorded as having had no population target
and no desperation, so a model fitted to this corpus would have learned the
wrong conditioning for the commonest case there is.

**Border 74** caught the consequence of fixing Border 118's finding.
Making the county line daily turned a once-per-session walk over the whole
identity store into a daily one, and every grave is in that walk because the
store is what the dead never leave. It is declared now, in the table for
walks outside the population file, and declared UNBUDGETED with two reasons
that are not `driftStandings`': it is linear where that one was quadratic -
2.6 ms over thirty thousand records by this border's own cost table, against
the 231 ms `[B51]` had to slice - and a cursor would make it wrong rather
than slow, because a county line assembled from half a county on one day and
half on the next is not a count of anything.

**Border 108** caught `SAO_Population` touching `SAO.Telemetry.runId`
outside a pcall. The instrument must not be able to throw into the
simulation it measures. Every reference sits inside one now, and the
identifier is cleared in its own guard so a throw while writing the closing
line cannot leave live play filed under a span that has ended.

## Not in this batch

**Reproducibility.** The county's randomness is the engine's `ZombRand`,
which SAO does not seed, so two runs under identical conditions are not the
same run. That is a fact about the corpus rather than a defect: it makes
these samples rather than replays, which is what a fitted distribution
wants anyway.

**Anything that reads the trajectory.** This batch writes it. The extractor,
the corpus governance and the model are the sibling project's, under the
charter the operator ratified today.

This governed record is the portable project history for this unit.
