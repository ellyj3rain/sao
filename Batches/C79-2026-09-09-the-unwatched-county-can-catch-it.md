# C79 - The unwatched county can catch it

| Field | Record |
| --- | --- |
| Batch | `C79` |
| Date | 2026-09-09 |
| Name | The unwatched county can catch it |
| Status | Closed append-only batch - awaiting its first live receipt |
| Threads | [`T-007`](THREADS.md#t-007), [`T-003`](THREADS.md#t-003) |

## Record

`[C78]` gave a bitten body a fight, and its own record had to state
that it reached almost nobody: `knoxInfected` and `biteDeathAtHours`
had exactly one writer in the tree - the block releasing a body to the
dormant county, reading the bite off the character as it went dark.

So the unwatched county could not contract Knox. Its people died of
thirst, of hunger and of the risk the county carries, and never of the
thing the game is about. A fight nobody ever has is not a capability.

## A bad day is not only a fatal day

When the county takes somebody, the encounter either kills them or they
get away from it having been opened up. On this build a bite infects
with certainty (F-047), so getting away IS catching it.

Which of the two happens follows from how well they handle danger, and
that is read off modifiers the pass already computes rather than from a
second stack invented for it. `risk` is how likely the county is to
take somebody; `handles` is the product of exactly those modifiers that
are about the PERSON rather than their condition or the weather - the
two lessons, the occupation class, being in a house, and months of
contact. The same facts, counted twice for two different questions.

`ESCAPE_BASE` is ours and says so. The engine settles this on a loaded
body's own damage and there is no body in the dormant county, so
nothing in the build establishes how often a survivable encounter draws
blood.

**A due bite is not a roll.** A course that has run out is a death the
engine already decided, so it never touches the ambient chance and
never takes the bite path. Border 90 holds that and refused the first
draft for folding the two into one expression.

## The defect this found in `[C78]`

Border 143 ran a county of a hundred and twenty people for two hundred
days and **nobody in it had ever thrown an infection off.**

Raising `PERFECT_COURSE_GAIN` looked like the fix and was not. The
defect was in `Course.advance`, which integrated the course's REMAINING
half instead of its elapsed one: it passed `pos` as the segment's
START, where `pos` is the ground the body has already covered. With a
daily cadence against a two-day window the first observation is already
at the midpoint, so every body silently forfeited the first half of
every course it ever ran and could not win at any constant.

The segment is `[pos - dPos, pos]` now. The constant is back at 0.55,
where the reasoning put it, and the arithmetic it was chosen against
actually happens.

**Border 142 could not have caught this.** It holds the model - the
integral, the curve, the cadence - and the model was right. What was
wrong was the caller's idea of which segment had elapsed, and that is
only visible when somebody actually runs a course over days. A border
at a point and a border over a county are different instruments, which
is `[C69]`'s argument arriving from the other side.

## Border 143, and its control

`tools/dormant_infection_test.py`, in the gate. It builds a county in
the engine's own VM, winds the risk dial up so encounters happen inside
a bounded run, and reads the records afterward.

| Property | Measured |
|---|---|
| the county catches it at all | infections in a county that could produce none |
| it resolves both ways | thrown off, and died-and-rose, both above zero |
| care is what decides it | a housed county against an unhoused one |
| a setting with no course infects nobody | `Mortality` at its instant band |
| and still kills them | the same run's deaths |

Measured on the shipped tree: over two hundred days, a housed county
threw off **8** and an unhoused one **2**, with 37 still carrying it
and 37 having died and risen. Care is a fourfold difference, which is
what the model says it should be.

The rate itself is not asserted. How often a county catches Knox is a
distribution and belongs to the sweep (`[C69]`); what a border can hold
is that the path exists, resolves both ways, and is bounded.

Its control is the `[C78]` tree, where `dormantAttrition` has no bite
path at all and a county runs for a year with not one infection in it.
The border prints that rather than merely failing.

## What this deliberately does not do

**It does not model who bit them.** There is no zombie out there to
meet; `DormantRisk` is the county's danger as one number, and this
splits its outcome rather than simulating an encounter. A dormant
county with real zombies in it is a different project.

**It does not touch the loaded path.** A materialised body is still
bitten by the engine, and still reads its clock off the character on
the way out. Both halves now feed one course.
