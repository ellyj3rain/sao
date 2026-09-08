# C63 - A day-zero start owes no years

| Field | Record |
|---|---|
| Batch | `C63` |
| Date | 2026-09-08 |
| Name | A day-zero start owes no years |
| Status | Closed append-only batch - awaiting live receipts (a December 1993 start with the switch on where the county is ordinary on day one and the outbreak arrives eight days later; the same date with the switch off where the county has already been through five months) |
| Threads | [`T-002`](THREADS.md#t-002), [`T-007`](THREADS.md#t-007) |

## Record

DR-036 has two halves and they were deciding the same fact separately.

[C43] moves the record's own first day onto a 1993 save's start when
the day-zero switch is on, so the outbreak arrives `leadIn()` days into
that save. [C45] counts the calendar days from the record's day 0 to
the save's start and lives them before anybody is spawned. Neither
knew about the other.

`daysBehindAtStart` was `max(0, recordDayOf(saveStart))` and knew
nothing about the switch. Measured against the built class off the
game:

| Start | Days the years pass ran | Where the record put day zero |
|---|---|---|
| January 1, 1993 | 0 | save day 8 |
| July 9, 1993 | 0 | save day 8 |
| July 20, 1993 | 11 | save day 8 |
| October 1, 1993 | 84 | save day 8 |
| December 15, 1993 | 159 | save day 8 |
| July 9, 1996 | 1096 | not moved |

A player who asked to watch the county before its outbreak, on a
December date, got a hundred and fifty-nine days of it having already
happened, handed to them with a record saying the outbreak was eight
days away. That is the artificial structure DR-036 exists to avoid,
produced by the two halves of DR-036.

## What changed

`daysBehindAtStart` takes the switch, and asks `mayShift` - the same
refusal `shiftTo` makes - rather than mirroring it. A save the record
MAY be moved onto, whose player asked for that, owes nothing. A 1996
start still owes its thousand with the switch on, because `mayShift`
refuses any year but the record's own.

`countyMonth0` is handed that number instead of working it out again
from `recordDayOf`. It would have read a shifted July 20 start's months
eleven days early for the whole save while [C62]'s clock read them
correctly, which is the same defect one module over.

`SAO_History.daysOwed` is the one reader on the Lua side. The years
pass asked the bridge itself and remembered the answer for the life of
the save; it goes through `daysOwed` now, and `daysOwed` reads
`SandboxVars.SurvivorAwareness.DayZero` - the same switch
`SAO_Record.placeTimeline` reads, so the timeline and the days owed
cannot disagree about which saves move.

The switch was chosen over a flag set by `shiftTo` for a reason worth
recording. `shiftTo` runs from `SAO_Record.rekey` on the server
module's own events, `yearsOwed` runs in the client population tick and
remembers its answer permanently, and `rekey` returns early when the
record option is off. A flag would have made the years depend on a
module that can legitimately never run. The sandbox switch is readable
from the first pass and `mayShift` is arithmetic on the save's own
start.

**Border 132** drives the real `SAO_History` in the engine's own VM
with the bridge stubbed to the rule the Java implements. A December 15
1993 start with the switch on reads hour zero and with it off reads its
3816; a 1996 start reads its 26304 either way; and the flag the bridge
is handed is the sandbox switch itself.

Its control is the tree at [C62]: the same December start reads 3816
hours with the switch on, which is the defect in its own units.

**Border 110** gains the day-zero arithmetic: the three 1993 dates and
their calendar distances, that all three may be shifted onto, that a
shifted start's own first day is the lead-in before day 0, that 1996
may not be shifted onto at all, and the month cases with the anchor
both ways.

**Border 118** named one spelling of `daysBehindAtStart`'s signature
and now names the function. Its subject - that an unreadable clock is
not nothing owed, and that the bridge decides nothing - is unchanged.

## What was measured before it was designed

The two numbers were printed side by side against the built
`SAORecord`, off the game, before anything was written: `recordDayOf`
and `recordDayOnSaveDay(...,0)` for six start dates. That table is
what is in the Record above.

It also killed the first draft of the fix. `max(0,
recordDayOnSaveDay(y, m, d, 0))` looked right and is -8 for every
start including 1996, because `recordDayOnSaveDay` applies `shiftFor`
whether or not the shift was taken. It would have zeroed the one case
that genuinely owes a thousand days.

## Not in this batch

**The lead-in itself.** A shifted save gets `leadIn()` days of ordinary
county before its outbreak, which is eight, derived from the record's
own first day to its day zero. Whether eight days is the right amount
of ordinary life is a design question and is not taken here.

**What a 1993 start after July 9 gets with the switch off.** It owes
its calendar days and lives them, unchanged. That is the shipped
timeline and it is correct.

This governed record is the portable project history for this unit.
