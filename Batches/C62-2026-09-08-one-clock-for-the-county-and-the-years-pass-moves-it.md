# C62 - One clock for the county, and the years pass moves it

| Field | Record |
|---|---|
| Batch | `C62` |
| Date | 2026-09-08 |
| Name | One clock for the county, and the years pass moves it |
| Status | Closed append-only batch - awaiting live receipts (a 1996 start whose county has lost people, moved on from old grudges, and been through three winters by the time the player is spawned) |
| Threads | [`T-007`](THREADS.md#t-007), [`T-002`](THREADS.md#t-002) |

## Record

[C45] lives the days a later save owes before anybody is spawned. It
calls the county's own systems to do it - dormant life, encounters,
attrition, the standing drift, age and habits - one call per simulated
day, and the presence band is held until the span is finished.

It does not move the clock those systems read.

Sixty-eight places in the tree asked `GameTime` for the world age in
hours, and every one of them meant "how far along is this county".
`GameTime` does not advance while [C45] runs, so every one of them read
the same hour for the whole span, and the systems that gate on a
CHANGE of day never saw one.

| System | Gate | What it did across a thousand simulated days |
|---|---|---|
| `dormantAttrition` | `today > rec.lastRiskDay` | stamped `lastRiskDay` on the first day; nobody died on any day after it |
| `dormantLife` | `lastWaterDay`, `lastFoodDay` | stamped both once; nobody grew thirsty and nobody went looking for water |
| `chooseDayPlace` | `daysWithout(...)` | read zero dry days forever, so need never drove where anyone went |
| `driftStandings` | `s.lastDriftDay == day` | aged feelings on the first day and returned zero on every day after |
| the winter multiplier | `GameTime:getMonth()` | ran three simulated years in the save's start month |
| `dormantLife` | `GameTime:getTimeOfDay()` | a save begun at 3am sent everybody home for a thousand days |
| a child's night fear | the same | stood at its maximum for the same thousand |
| `clockMonths` ([C61]) | `recordDayToday()` | held the whole span at the record day the save started on |

A 1996 save ran about a thousand days and came out of them with the
same people, the same feelings and the same needs it went in with. The
batch that was supposed to make the years happen called every system
that would have made them happen and handed each one a clock that had
stopped.

## What changed

`SAO_History` gets the county's clock, beside the one [C61] put there.

`H.countyHours()` is the hour the county has reached. While the years
are being lived it is the day being lived, times twenty-four. Otherwise
it is the days this save began behind the record plus the game's own
hours. The two meet at the same number: a county that has lived all
thousand of its days reads 24000, and so does the same county on the
first hour of play. That join is what every stamp made during the years
depends on - a clock that dropped back to the game's own zero would put
all thousand days of them in the future.

A save with no years behind it reads the game's own hours and nothing
else, so nothing that ran before this runs differently on a 1993 start.

`H.countyMonth()` is the calendar month those hours fall in, so a
simulated January is cold. The arithmetic is `SAORecord.countyMonth0`,
which anchors on the save's start put back by the days behind it: a
1996 save is at the record's own July on county hour 0 and back at its
own start month once it has lived them all. A save that owes nothing
anchors on its own start and answers what `GameTime` answers, every day
of play.

`H.recordDay()` is where the record's calendar has got to, which is the
day being lived during the years and `recordDayToday()` after them.
[C61]'s `clockMonths` reads it, so what a person has had time to learn
grows across the span rather than standing still.

That is not the same quantity as `countyHours` and the two are kept
apart on purpose. One counts elapsed time from zero and never goes
backwards. The other is a position on a calendar that runs from before
day zero, and a shifted [C43] start begins at a negative number on it
with no time elapsed at all.

Every module in the tree reads the clock through `SAO_History` now -
sixty-seven substitutions across eighteen files, and four season reads
alongside them. `SAO_History` is the only module left that asks the
engine, which is the invariant Border 131 holds.

`H.countyTimeOfDay()` is the hour of day, and it needs a different
answer from the others. [C45] runs one call per simulated day, so a
simulated day has no hours in it to be at. While the years run this
says noon, which is a claim and not a derivation: what a simulated day
models is a day's worth of going out and coming back, and running each
of those days through its own twenty-four hours is what F-055 measured
and DR-037 ruled out. Outside the years it is the engine's, unchanged.

`runTheYears` writes the day it is living before it lives it, and on
every day. It wrote it once at the end of a slice, and a slice is up to
sixty milliseconds - which is hundreds of simulated days with one hour
on all of them.

One module owning the clock creates one way to lose it. Every read
goes through a pcall that answers zero when `SAO_History` cannot be
reached, and a zero here is not a small wrong number: it is a clock
that never moves, which is this batch's own defect arriving silently
and in live play rather than only during the years. So the population
tick asks once at boot whether the clock answers, says so in the log
if it does not, and marks the seam dark, which is the only place a
player would ever find it out ([B33]).

**Border 131** drives the real `SAO_History` and `SAO_Standing` in the
engine's own VM. The clock reads 24 on the first simulated day, 23976
on the nine hundred and ninety-ninth, 24000 when the years are done and
24048 two days into play; a save owing nothing reads the game's own 137
exactly; the month is asked for hour 9600 on simulated day 400 and the
engine's own month answers where no record can.

Its control is `driftStandings` called on three consecutive simulated
days with only the years store moved and the game clock held still. On
this tree it moves two feelings each day. On the pre-batch tree it
moves two on the first day and zero on the second and third, which is
the defect itself rather than something beside it.

Three borders that stub the engine clock and drive a module which now
reads the county's needed the real `SAO_History` loaded: Border 65
(time softens), Border 129 (the player's looting) and the motor pool
border. Stubbing `SAO.History` instead would have been testing the
stub. The gate caught all three, and caught the bridge method missing
from the shipped jar before the jar was rebuilt.

`S.fallHasCome` asked the bridge for the record day itself. It reads
`H.recordDay()` now, so the record's calendar has one reader in the
Lua tree. **Border 116** was retightened to match: it asserted the
literal `recordDayToday()` inside the function, and now asserts that
the function asks the one reader, that the one reader is the only
thing calling the bridge, and that an unreadable clock still cannot
reach the `day >= 0` comparison. That is a narrowing, and it is
recorded here rather than made quietly: the pre-batch tree fails the
three checks even though `fallHasCome` was correct there by its own
spelling.

**Border 110** gains the county-month arithmetic off the game: the
shipped start's own month, a month into it, a 1996 save at the record's
July on county hour 0, its January a hundred and eighty days in, its
own start month once it has lived all 1096, and a January 1993 start
that owes nothing reading its own month and July two hundred days on.

## What was measured before it was designed

The defect was read out of the source before anything was written.
`hoursNow` at `SAO_Population.lua:349` reads `getWorldAgeHours`;
`dormantAttrition` derives `today` from it and gates on
`today > rec.lastRiskDay`; `driftStandings` derives `day` from it and
returns on `s.lastDriftDay == day`; nothing in `oneYearsDay` advances
`GameTime`. Then the population was counted rather than assumed:
sixty-eight sites, thirty-four of them in one file. The fix follows the
count, not the first site found.

Border 118 ([C45]'s own) could not have caught this. It checks that the
years pass CALLS those systems, which it does. Whether a call does
anything is a different question and wants a different instrument.

## Not in this batch

**The body's own hour.** `GameTime:getHour()` and `getTimeOfDay()`
are still read directly in `SAO_Controller`, and stay that way: every
one of those sites runs on a body, and nobody is materialised during
the years. The two sites that run without one - `dormantLife` and a
child's night fear - ask the county.

**The water shut-off.** `SAO_Places.waterIsOn` now reads the county's
clock, so a 1996 county's mains go dry partway through its simulated
years instead of staying on for all of them. The player's own taps are
still the engine's to run, and a 1996 save will have working taps in a
county that lost them years earlier. That split is the engine's, not
SAO's, and closing it is a separate design call.

**What the years produce.** This batch makes the systems run. Whether
their tuning is right over a thousand days - the attrition base, the
drift rate, the thirst multiplier - has never been watched and is not
argued here.

This governed record is the portable project history for this unit.
