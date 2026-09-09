# C72 - The dormant day can go to a person

| Field | Record |
| --- | --- |
| Batch | `C72` |
| Date | 2026-09-08 |
| Name | The dormant day can go to a person |
| Status | Closed append-only batch - awaiting its first live receipt |
| Threads | [`T-006`](THREADS.md#t-006), [`T-004`](THREADS.md#t-004) |

## Record

`chooseDayPlace` decided where a dormant survivor walks from thirst,
hunger, lessons, beliefs and barred ground. It is a real,
attribute-aware decision and it was the **only** decision a dormant
person made - and it had no social term in it at all.

Nobody in this county had ever decided to go to another person. Every
meeting was two need-driven walks coinciding within three tiles.

Measured over eight counties of 1096 days against the shipped map:

| | |
|---|---|
| housemate pairs seeded at genesis, bonded, trusting 0.6 to 0.9, standing on the same tile | 152 |
| of those, pairs that ever stood near each other again | 27 |
| people who lived and died without ever meeting anybody | 179 of 287 |
| pairs above the company line at the end, that had ever met | 16 of 129 |

The county's trust economy was working the whole time and coincidence
could not deliver anybody to it.

## What changed

`chooseDayPlace` is `chooseDayGoal`, and the goal it returns may be a
place or a person. `chooseWhoToGoTo` answers the second half, and every
term in it is a fact the county already produces about that person.

**Who is a candidate** is whoever they believe is somewhere, which
until `[C71]` was nobody at all. A belief about a living person comes
from having stood next to them; there is no other road into it, so
knowledge is the whole of the reach - which is DR-027's ruling, that
how far a person goes is knowledge and desire and never a radius.

**Whether they are worth going to** is the trust already between them,
against the county's own company line. Somebody you would keep house
with is somebody you would cross town to see, and reusing
`TrustToCompany` means the operator's dial moves both together rather
than a second number being invented here.

**Which one** is trust over the age of the sighting. An address a week
old is where somebody was, not where they are.

**Whether they set out at all** is `initiative` - Disposition's own
gloss is self-starts rather than waits, and this is the one decision in
a dormant day that nothing outside prompts. A hesitant person goes some
days and not others. The draw is taken only once there is somebody to
take it about, so a survivor who knows of nobody spends none and
`[C66]`'s sequence is not moved by a decision that was never available.

Need still cuts ahead: a person three days without water goes looking
for water. Going to somebody cuts ahead of curiosity, for the same
reason need does.

The feud and claim law is `placeBarred`, unchanged, asked about the
tile they would walk to - one law rather than a second copy of it,
which is how the two choosers were kept together at `[C25]`.

**People who arrive together have seen each other.** Genesis originates
the county in bonded units standing on the same tile - a family, a
pair - and nothing recorded that they had laid eyes on one another, so
the pairs that already trusted each other most had no address for each
other at all. `sawPerson` is written at genesis for the same reason it
is written at a road meeting: they were both there.

**Somebody believed to be where you are standing is not somewhere to
go.** This is what makes the genesis belief durable rather than spent
on the first day. Housemates believe each other to be at the home they
were both standing in, so on day one there is nothing to walk to and
the belief survives; a month later, when the day's roaming has carried
them apart, that same address is exactly where to look. Without it the
belief was consumed immediately and the county spent 225 decisions per
run choosing a goal it was already standing on - which was measured,
and is why that number is 16 now.

**An address that did not pan out stops being the answer.** Somebody
who walks to where they last saw a person and does not find them has
learned something, and without recording it they would re-order the
same doorstep every day forever - which is exactly the failure `[C25]`
names for a known place that turned out empty. Whether it paid off is
whether they have seen that person SINCE they set out: the encounter
pass writes a fresh sighting the moment two people are in meeting
range, so a stamp that has not moved means the address was empty.
Marking it on arrival regardless would spend the belief of somebody
they had just found.

## What the county did with it

Twenty-four counties of 1096 days against the shipped map, before and
after. Twelve was run first and read the other way; twenty-four is what
the numbers below are, and the twelve is recorded here because
reporting a direction off the first sample size that produces one is
the error.

| | `[C71]`, 24 | `[C72]`, 24 |
|---|---|---|
| houses founded, median | 20 | 18 |
| houses standing at the end, mean | 0.3 | 0.2 |
| counties with a house standing | 6 of 24 | 5 of 24 |
| survivors in a house, mean | 0.6 | 0.5 |
| largest house ever seen | 2 | **3** |
| alive at the end, mean | 3.3 | 1.9 |

**Nothing moved that this batch was written to move.** Houses standing
did not rise; the largest house reached three for the first time in one
county of twenty-four, which is one county. That is the honest reading
and the reason is measured rather than guessed.

Instrumented at each exit of the chooser, over twelve counties:

| | per county, 1096 days |
|---|---|
| day-goal choices made, by everybody, all run | 806 |
| need took the day | 380 |
| a place took the day | 419 |
| **somebody took the day** | **7.6** |
| nothing to walk to | 0 |

Seeking is not being out-ranked: need takes 47 percent and a place 52,
and in 790 of 806 choices there was no eligible person to go to at all.
The candidate list is empty because a belief about a living person
comes from a meeting, and meetings almost never happen.

**Why they almost never happen was the thing worth finding.** A
dormant survivor walks **1.8 tiles per simulated day**, measured over
four counties on both trees. The live county gives the same person a
move every 1800 to 3600 frames on a 240-frame population pass - about
eighty moves in a game day, up to 320 tiles. The years pass advances
its counter by 3600 ticks per simulated day and calls `dormantLife`
once, so a simulated day gets ONE move of at most four tiles: one
eightieth of the same person's own live movement. Three simulated
years carry somebody under two kilometres across a map fifteen
thousand tiles wide.

That figure is `[C45]`'s and it is deliberate: its record says a
simulated day advances the counter far enough to open each frame-paced
gate about once, and that one move and one meeting per pair is what a
day deserves when nobody is watching. What it never asked is what one
move is worth. Four tiles. The reasoning is about cadence and the
consequence is a distance, and the two were never compared - which is
the same shape as `[C45]`'s own defect, where Border 118 asserted the
years CALL those systems and `[C62]` found that calling them moved
nothing.

It is F-061 and it is not this batch. It matters here because every
measurement this project has taken of its own social life, `[C67]`'s
and `[C68]`'s included, was taken in a county whose people cover four
tiles a day.

`[C71]`'s own sweep is the control that matters: it changed what every
dormant survivor can KNOW about another person and moved not one number
in the county - houses founded, standing, largest, all identical to
`[C70]`. Nothing decided on a person-belief until this batch, so
everything below is the seeking decision and not the substrate under
it.

## Border 138, and its control

`tools/seek_test.py`, in the gate. It runs the shipped dormant modules
in the engine's own VM through the tick handler the mod registers, and
then reads `rec.dayGoalPerson` and `rec.dayGoalX/Y` off the record. A
border asserting that `chooseDayGoal` calls `chooseWhoToGoTo` would
pass a tree that called it and threw the answer away.

Whether somebody sets out on a given day is their own initiative drawn
against the county's generator, so every property is measured over
forty day-choices rather than one: a decision that is available is
taken at least once, and a decision that is not available is never
taken.

| Property | Measured |
|---|---|
| somebody trusted and seen is somewhere to go | 27 of 40 |
| trust below the company line is not | 0 of 40 |
| somebody hostile is not | 0 of 40 |
| thirst outranks company | 0 of 40 while three days dry |
| an address walked to and found empty | 0 of 40 |
| the goal points where they last saw them | 10650, the remembered tile |

Its control is the `[C71]` tree - the tree that already holds the
belief. A survivor who believes a person they trust at 0.85 is a
hundred and fifty tiles away sets out toward them **0 times in 40**.
That isolates the decision from the substrate `[C71]` built for it.

## Two seams that named a spelling

`tools/places_test.py` asserted the literals
`chooseDayPlace(id, rec, reach)` and
`rec.dayGoalX, rec.dayGoalY = chosen.cx`. Both went red on a correct
rename, which is the seam-names-a-declaration defect this repository
has paid for three times. They name the shape now: the dormant day asks
one chooser, with the person and the reach, and writes the goal out of
the answer it gets back, whatever either is called.

That border's Python mirror models the PLACE ordering and says so. It
does not model the person branch, and that is stated in the mirror
rather than left to be discovered: a mirror of a decision about trust,
hostility and a temperament draw would be a second answer to the
question, and Border 138 runs the real module instead.

## What this does not do

**A person is not a reason.** The pull is trust and nothing else, so
nobody goes to somebody BECAUSE they have water, or because they know
something the walker does not. Those are cognition rows and belong to
the dataset (DR-038), not to a term written here.

**Recruitment is untouched.** A house grows past a pair only when
somebody outside it reaches the company line with a member, and a road
meeting is worth 0.005 of trust. Seeking reconvenes people who already
trust each other; it does not introduce anybody to anybody.

**A house still cannot take ground.** `setGroupClaim`, `setHearth` and
`setLarder` have call sites only in `SAO_Controller`, which needs
materialised bodies, so a dormant house that now actually stands still
has nowhere to be. That is the next thing.
