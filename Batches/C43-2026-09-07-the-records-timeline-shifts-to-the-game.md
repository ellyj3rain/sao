# C43 - The record's timeline moves onto the start date

| Field | Record |
|---|---|
| Batch | `C43` |
| Date | 2026-09-07 |
| Name | The record's timeline moves onto the start date |
| Status | Closed append-only batch - awaiting live receipts (a March 1993 Day Zero start with the record's own week of ordinary county, the papers showing pre-outbreak issues through it, the broadcasts beginning on day eight and the county starting to keep a watch; an October 1993 start doing the same; a July 9 start with the switch off, unchanged) |
| Threads | [`T-002`](THREADS.md#t-002), [`T-005`](THREADS.md#t-005) |

## Record

The lore is canonically 1993 and it has a set schedule. [C36] put the
county on that schedule's own calendar, which pins it to the dates it
carries: begin on July 9 and the fall is already here, begin on
March 1 and nothing happens for four months. The operator ruled that
wrong for the start this mod is for. Within 1993 a player picks a date
- January, March, October, whatever they want - and if they asked for
the day-zero start, the record's timeline moves onto that date rather
than sitting in July waiting for them.

**What moves.** The record's own first day - the July 1 issues and the
outages around them - lands on the save's start day. Its own eight
days of ordinary county play out from there, then the collapse, then
everything after it in its shipped order. The broadcasts and the dated
papers move with it, because they are read through the same date.
A start later in the year moves the timeline backwards onto it: an
October save gets the week and then the fall, rather than a fall that
happened three months before it began.

**The eight days are the record's, not a setting.** A first draft of
this batch invented a dial for the length of the ordinary county
before the outbreak. The operator had not asked for one and it was
removed. The number is derived from the record itself - the days
between its first day and its day 0 - so it is one fact in one place
and it moves if the record is ever read differently.

**Which saves this is for, and which it must never touch.** Any 1993
start, with the Day Zero switch on. Not a save that begins in 1994 or
2000: the Knox Event happened when it happened, and what that player
is owed is the years between simulated forward - DR-036's other half.
Moving the lore onto their start would erase exactly the history they
came for. The Java side refuses it by the year, so the two cases
cannot collide by accident. And a player with the switch off is
playing the shipped 1993, whose record must not move under them.

**One integer does all of it.** Every record read asks for the
effective date, which is the real one plus a shift, and every function
[C36] and [C38] already wrote works unchanged on it - which paper is
on the shelf, how far into the schedule the county is, what the radio
is keyed to. The chronicle's own dates deliberately do NOT shift: a
person who lived a day lived it on the day the calendar actually said.

**What follows without being wired.** [C42] gave the county the
question of whether the fall has reached it, derived from the record's
calendar and its own stamps. With the timeline moved, that question
answers itself: the county lives an ordinary life through the record's
week - no night watch, nobody crossing town for a weapon, nobody
scouting somewhere defensible - and the moment the record's day 0
arrives it is a county in the fall. That is the day-zero start
watching itself happen, and it is what the two batches are for
together.

**Border 110** now runs the placement off the game against the
installed jar: the record's own ordinary county measured at eight
days; a March start reaching record day 0 on save day eight and still
ordinary on day seven, with its first day being the record's first
day; a fortnight past the fall at record day 14; a January start doing
the same; an October start moving the record backwards onto it; and
the year gate - 1993 in any month may move, 1994 and 2000 may not.

**Not in this batch.** DR-036's other half: the years between 1993 and
a later start, simulated forward. The late end of it - settlements
that matter, an economy, a society. Normal-life behaviour on open
streets during the record's week, which is what the county should be
doing with those days beyond not keeping a watch. The outbreak's own
propagation through the engine's infection and turning.

This governed record is the portable project history for this unit.
