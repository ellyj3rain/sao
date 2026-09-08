# C61 - One clock for how long this has been going on

| Field | Record |
|---|---|
| Batch | `C61` |
| Date | 2026-09-08 |
| Name | One clock for how long this has been going on |
| Status | Closed append-only batch - awaiting live receipts (a 1996 start where the survivors talk and act like people three years in rather than one month; a day-zero start where nobody carries an apocalypse claim) |
| Threads | [`T-002`](THREADS.md#t-002), [`T-005`](THREADS.md#t-005) |

## Record

Three things in this tree answer how far into the collapse a save is,
and one of them answered from a different source.

| Reader | Source |
|---|---|
| `SAORecord.daysBehindAtStart` ([C45]) | the record's calendar |
| `SAORecord.recordDayToday` ([C42]) | the record's calendar |
| `SAO_History.clockMonths` | `SandboxVars.TimeSinceApo` |

[C42] ruled that whether the fall has come is derived from the county's
own stamps and the record's calendar, and never from the sandbox dial.
`clockMonths` is what ages every person's KNOWLEDGE - the split clock
turns it into contact months, and the lesson pool and the claims a
person carries are drawn from that - and it was still reading the dial.

So a 1996 save ran about a thousand days of county forward ([C45]) and
then told every survivor in it that they were one month in, because the
dial's default is one. The county's history and the county's people
disagreed about the same fact.

`clockMonths` reads the record's calendar now. Before the fall the
answer is zero, and that is not a fallback: a county that has not had
its outbreak has nobody who has lived through one, which is day zero's
whole premise ([A29] - innocent by construction). The dial remains the
answer where the calendar cannot be read at all - a bare VM, the
offline mirrors, a load before the bridge is up - so this module stays
offline by construction and nothing that ran before runs differently
there.

**Border 130** drives the real `SAO_History` in the engine's VM with
the bridge stubbed: a thousand record-days reads thirty-three months
with the dial at 1 and at 60 alike, before the fall is zero, day zero
is zero, and both the unreadable sentinel and a missing bridge fall
through to the dial.

Its own first seam was wrong in the way `GOVERNANCE.md` names: it
compared the position of the identifier `recordDayToday` against
`TimeSinceApo` and failed on this batch's own comment, which mentions
the dial while explaining why it is no longer asked first. Prose is not
code; the seam compares call forms now.

**Not in this batch.** The dial itself is still a sandbox option a
player can set and it still reads as it always did on a save whose
calendar cannot be resolved. Whether the option should exist at all is
a design call and is not taken here.

This governed record is the portable project history for this unit.
