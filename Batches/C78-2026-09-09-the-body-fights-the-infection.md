# C78 - The body fights the infection

| Field | Record |
| --- | --- |
| Batch | `C78` |
| Date | 2026-09-09 |
| Name | The body fights the infection |
| Status | Closed append-only batch - awaiting its first live receipt |
| Threads | [`T-007`](THREADS.md#t-007), [`T-003`](THREADS.md#t-003) |

## Record

`[C11]` and F-047 established what the engine does with a bite on this
build: it infects with certainty, and the infected die at exactly
`infectionTime + pickMortalityDuration`. The record carries that hour
as `biteDeathAtHours` and `dormantAttrition` read it as a due date -
its own comment says *past it, death is not a risk, it is due.*

So every bitten person in the county died on schedule, and nothing they
had done before the bite made any difference to it. A survivor who had
been eating, drinking, sheltered and warm died at the same hour as one
who had been dying of thirst in a ditch.

The hour still stands. What changes is that the body can get there
first.

## Where the model comes from

Antibodies (lonegamedev, **MIT**) already answers this question for one
person, and answers it well. Its contest is driven by the body's real
condition rather than by a roll: antibody growth is a base plus the
condition and body effects, against the infection's advance. Its
response follows `sin(level * pi)` - weakest at the very start and the
very end of the course, strongest in between - which is the difference
between a race decided at the first hour and one with a window in the
middle where what somebody does still matters. And a body that has
fought the infection off before is better at it next time.

Those are taken, credited in `CREDITS.md`, and rebuilt here rather than
imported: Antibodies is built player-first, on
`player:getModData()` with an `IsoPlayer` branch in its own infection
update, and it models one immune system. The county has hundreds.

**Every input already existed.** How long since they reached water, how
long since they ate, whether a house is keeping them, whether a wound
is already septic, how old they are, what conditions they carry -
`dormantAttrition` computes all of it already, for the risk. The fight
costs the pass nothing it was not already paying.

## The course is measured against the engine's own window

Progress is a fraction of the course rather than a number of days, and
the course's length is the sandbox's own `ZombieLore.Mortality` window
- the same table `biteWindowHours` mirrors. A player who set a fast
pathogen gets a fast one and the fight scales to it.

`PERFECT_COURSE_GAIN` is the tuned number and it says what it means:
what a body of median constitution in good condition achieves over one
whole course. Winning takes 1.0 and it is set to 0.55, so a median body
kept well still loses. Knox is fictional and no source establishes how
a human fights it, so this number is **ours** and says so.

**The odds are the operator's** and this is a starting position rather
than a ruling. Where it stands: throwing off an infection needs a
constitution in roughly the top fifth of the county AND a house keeping
somebody warm and fed - usually both, and having survived it before
helps. A county where a bite is survivable by anyone who has been
drinking is a county where Knox has stopped meaning anything, which
would be a worse outcome than the defect this batch fixes.

## The spread, without which this is a threshold

Every term in `qualityOf` is circumstance, and circumstance is the same
for two people living the same way. Left there, the model answers
identically for everybody in identical conditions: a bite is survivable
by all of them or by none, and nothing in between ever happens. The
first draft had exactly that defect, and at its first constant it made
every well-kept survivor immune.

Constitution is the per-body variation the county already draws
everything else from - hashed off the person's own id, stable for their
whole life, drawn once and never rolled at the moment it is read, which
is `SAO_Conditions`' own pattern and DR-003's per-body variation. Two
people living the same way now die differently, which is what makes
this a model.

## Three defects found before anything shipped

**The cadence decided the answer.** The first `gainFor` sampled the
curve at each step's midpoint and multiplied by the step's width, which
is the obvious way to write it. One step across a whole course then
samples `sin` at its peak and returns `pi/2`; twenty-four steps of a
twenty-fourth sum to 1. A dormant body taking one step a day would have
out-fought a loaded body taking hundreds - which is `[C75]`'s defect,
the two halves of the county disagreeing because a pass means different
things in each, arriving in a different module a day later.

The step is the exact integral now. The area of `sin(pi*x)` over
`[a, b]`, normalised, is `(cos(pi*a) - cos(pi*b))/2` - one over a whole
course and additive over any partition of it. Cadence cannot move the
total, which is `[B39]` and `[B42]`.

**Every bonus term was dead code.** `qualityOf` clamped its result to
`[0, 1]`. A body wanting for nothing is already at 1, so being kept by
a house, being warm, being fed by a pact and having beaten the
infection before all multiplied a number that was then thrown straight
back down to 1. Four terms read as a model and did nothing. Quality is
floored and not capped now, so it is a multiplier around 1 rather than
a fraction of it, and care can carry somebody past the baseline - which
is the point of care.

**And the first constant made every well-kept survivor immune.** It was
1.15 against a win at 1.0, which meant anything above quality 0.87 won
- and a healthy dormant survivor who has been reaching water sits at
exactly 1.0. Every person in the county who was not actively dying of
thirst would have thrown off every bite, deterministically, with no
spread to soften it. Caught by working out what the number produced
rather than by the border, which did not yet hold an odds property and
still does not, because the odds are not a border's to fix.

## Border 142, and its control

`tools/course_test.py`, in the gate. It runs the shipped module in the
engine's own Kahlua VM and asks it the same question at different
cadences. A border reading `PERFECT_COURSE_GAIN` out of the source
would pass a tree that computed it and then handed the answer to
whichever half of the county happened to call it.

| Property | Measured |
|---|---|
| the cadence cannot change the answer | one step, 24 steps and 1000 steps of one course |
| the constant means what it says | a whole course against `PERFECT_COURSE_GAIN` |
| the middle of the course is where care pays | the middle third against the first |
| a body without water never wins | three days dry, over a whole course |
| care carries somebody past the baseline | a house keeping them, against wanting for nothing |
| winning clears the course and is remembered | the flags, the clock, and `infectionsSurvived` |
| the engine's hour never moves | `biteDeathAtHours` after a fight |
| two people are not the same body | constitution across 400 ids, and its stability |

Its control is any tree before this batch, where `SAO_Course.lua` does
not exist and nobody has ever fought anything - which the border names
rather than merely failing to import.

It also loads **only** `SAO_Log`, `SAO_Hash` and `SAO_Course`, so the
module's own claim to be offline by construction is checked by the
border every time it runs.

## What this deliberately does not do

**It does not move the engine's hour.** Antibodies wins by pushing
`infectionTime` against `infectionMortalityDuration`, and that was
tried here first. Ported onto this record it breaks: `positionOf`
measures the remaining time against a fixed span, so pushing the hour
out drives the position backwards and a body that fought WELL is
reported as permanently at the start of its own course, sitting in the
weakest part of the curve forever. Extending the span alongside the
clock fixes the arithmetic and leaves a body able to hold an infection
at bay indefinitely, which is a different mechanic. This is a race
against the hour `[C11]` read off the engine, and Border 142 holds it.

**It does not touch the loaded path yet.** A materialised body's
infection is still the engine's own, and the same model reading a live
body's real condition is the follow-up. The dormant half is where every
input already exists and where the defect was total.

## How far this actually reaches, which is less than it looks

`rec.knoxInfected` and `rec.biteDeathAtHours` are written in exactly one
place: the block that releases a body to the dormant county, reading
`SAOJavaBridge:biteHoursLeft` off the character as it goes dark. There
is no other writer in the tree.

So **the unwatched county cannot produce an infection of its own.** A
dormant survivor dies of thirst, of hunger, of the risk the county
carries - and can never be bitten, because a bite happens to a
materialised body. What this batch changes is therefore reachable only
for somebody who was bitten near a player and then went dormant still
carrying it.

That is a real capability and a narrow one, and it is stated rather
than implied by a record that talks about the county at large. The
dormant county contracting Knox at all is its own batch, and it is the
thing that would make this one matter everywhere instead of at the
edges.

## Why there is no sweep table

`tools/county_sweep.py` never materialises a body, never calls the
bridge, and never sets `knoxInfected` - checked rather than assumed. So
a dormant sweep cannot exercise this at all: nobody in one is ever
infected, and a before-and-after would print two identical tables and
call it a result.

The evidence here is Border 142 over the model, and the rest is a play
receipt. `[C69]`'s reason for the sweep not being a border cuts the
other way too - an instrument that cannot reach the mechanism is not
weak evidence about it, it is no evidence about it.
