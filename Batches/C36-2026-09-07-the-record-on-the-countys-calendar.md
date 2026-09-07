# C36 - The record on the county's calendar

| Field | Record |
|---|---|
| Batch | `C36` |
| Date | 2026-09-07 |
| Name | The record on the county's calendar |
| Status | Closed append-only batch - awaiting live receipts (a July 1 start hearing an ordinary county and finding the Knox Knews of July 1 to 3 on the shelves; the record's first day arriving eight days in; a default start unchanged) |
| Threads | [`T-002`](THREADS.md#t-002), [`T-006`](THREADS.md#t-006) |

## Record

DR-031 ruled that the game's own record of the Knox Event - the
broadcast schedule and the dated newspapers - is the living start's
to schedule, keyed to the dates the record itself carries. The engine
keys every broadcast to days since the save began and places no paper
on any calendar (ENGINE_CONTRACT Addendum E); the record carries the
dates: its broadcast day 0 is July 9, 1993 (the Speakeasy document
knox-event.md keys every entry to its absolute date), and each
paper's issues are named by their July day. This batch is the Day
Zero arc's slice 7.

**The arithmetic.** `SAORecord` (Java) holds the record's day 0 and
two pure functions: the save day the record's day 0 falls on, from
the save's own start date (the engine's month and day are zero-based
and are honoured as such), and the newest issue a paper had printed
by a date, read off the issue names. On the shipped July 9 start the
record's day 0 is save day 0 and nothing changes; a July 1 start puts
it on save day 8; a July 20 start on save day -11. Border 110 runs
these off the game against the installed jar.

**The broadcasts.** Once per save - at the radio scripts' load, with
an hourly retry until the channels exist - every vanilla channel's
running script is re-keyed to begin on that save day, through the
engine's own surface (`setActiveScript(name, startDay)`, the one its
"Initial Infection" and "Six Months Later" modes use). The county
wire is not vanilla and is left alone. A start after July 9 hands
each script a clock already past its beginning, and the script's own
update picks the broadcast valid at that time; nothing is simulated
by hand.

**The papers.** The engine names a paper at creation from Java
(`ItemCodeOnCreate`), so the re-dating happens where a mod can reach
it: at every container the world fills. Each paper in the container
takes the newest issue printed by the county's date, written the way
the engine writes it - the name, then the print media table in the
helper's own argument order (title, info, text, id, read off its
bytecode) - and is marked so it is not dated twice. A paper of no
named title keeps the paper the engine dealt it, read back from that
table; the county paper when there is none. A paper nothing has
printed yet is taken off the shelf: before July 6 only the Knox
Knews of July 1 to 5 exist to be found, which is the county before
the fall.

**The switch.** A sandbox option, on by default, in plain words: the
broadcasts and newspapers follow the calendar; off, the schedule
counts from the day the world began, as the game does. The harness
reports the record's day and which issue each paper would show.

**Border 110** compiles and runs the Java check against the installed
game and SAO's own jar: the shipped start at day 0, July 1 at 8,
July 20 at -11, August 1 at record day 23, and the issues by name and
date (the county paper on July 3 and in August, nothing on June 30;
the Herald on July 3, 10, 14 and a year on); the engine's own paper
registry is asked too and reported either way. By text it holds the
module (once per save, the retry, the container hook, the option),
the bridge's four calls, the option and its words, the harness, the
contract rows and the helper's argument order. Its control is the
pre-batch tree.

**Not in this batch.** The helicopters and the fall's other sounds
Week One holds, which would dress the record's days when the county
hears them; the vanilla helicopter event on the calendar (its surface
has not been asked for); the county's own reaction to what the
record says on each day, which is the lessons' and the wire's
business already.

This governed record is the portable project history for this unit.
