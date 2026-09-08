# C45 - The years between

| Field | Record |
|---|---|
| Batch | `C45` |
| Date | 2026-09-07 |
| Name | The years between |
| Status | Closed append-only batch - awaiting live receipts (a 1996 start logging the days it owes, living them over the first seconds with nobody spawned until it is done, and the count of who is left alive to meet; a 1993 start owing nothing and behaving exactly as before) |
| Threads | [`T-007`](THREADS.md#t-007), [`T-002`](THREADS.md#t-002) |

## Record

DR-036's other half. A save that begins in 1996 has three years of
county behind it, and the people the player meets are the people who
lived them. Until now nothing ran: a later start got a county
generated on the spot with no history at all.

**The county's own machinery, run forward.** One simulated day drives
the dormant day, the meetings on the road, attrition, the softening of
old feelings, the age table's roll and the settling of habits - every
one of them the call the live county already makes on its own cadence,
and not one of them written for this. Houses, leaders, feuds and pacts
arrive because the dormant encounters form them, exactly as they do in
play. Nothing is authored: the ruling that governs this is the one
that governs building - they either manage it or they do not, and a
pass that placed a house would destroy the only measurement there is.

**At a daily cadence, and the number is measured (F-055).** The
ten-minute pass the live county uses exists to drift a body's stats,
and nobody in the years has a body - the dormant day runs for exactly
the people the body lookup answers nothing for. At the live cadence
three years cost about five and a half hours of real time on the
machine this was measured on; at a day a day they cost about two
minutes, and nothing bodiless is skipped, because everything that
happens to a person without a body happens on a daily clock anyway.

**The dormant systems pace in frames, so a day has to buy them.** A
person moves every 1800 to 3600 of them and a pair may meet once per
1800, so a simulated day advances that counter far enough to open each
gate about once. One move and at most one meeting per pair is what a
day deserves when nobody is watching it, and the figure is named with
that reasoning rather than spelled into the loop.

**Sliced, never blocking.** Each pass spends at most sixty
milliseconds and picks up where it stopped, with the progress in the
county's own store. A county catching up is a few seconds of the game
running normally rather than a frozen window, and an interrupted save
resumes rather than starting over.

**In order, and holding the band.** Genesis first, because a county
has to exist before it can have a history ([C41]); then the years;
then everything else. While the years are being lived the live
subsystems are skipped - the years are already driving every one of
them - and the band is held, so nobody is materialised into a county
that has not finished happening.

**Nothing owed is not nothing known.** A 1993 start owes zero days and
the pass does nothing. An unreadable clock is a different answer and is
asked again next pass, rather than being recorded as a nothing that
would stand for the life of the save.

**Border 118** holds the thing that matters: every call inside a
simulated day must be one the live county already makes, and the pass
must actually drive all six. Reaching for a group, a bond, a claim, a
death or a barricade directly is a fault by name, because that is the
shape this would fail in - a pass that stopped running history and
started writing it. Its control is the pre-batch tree, which has no
pass at all.

**Not in this batch.** The world side: during the years nobody has a
body and no ground is loaded, so nothing anyone does to a building
happens - the boarding [C44] built cannot fire here. The operator
ruled the years run for real and F-055 measured the ground at 432
chunks and 406 KB, which is nothing; loading it per claim while the
years run is the next piece and is not in this one. Also: what a place
becomes over years, trade between places, burial.

This governed record is the portable project history for this unit.
