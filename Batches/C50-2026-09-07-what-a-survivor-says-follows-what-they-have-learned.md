# C50 - What a survivor says follows what they have learned

| Field | Record |
|---|---|
| Batch | `C50` |
| Date | 2026-09-07 |
| Name | What a survivor says follows what they have learned |
| Status | Closed append-only batch - awaiting live receipts (a day-zero county fleeing its first dead without a word for them; the same people a week later; somebody saying the crossing line once and never again) |
| Threads | [`T-002`](THREADS.md#t-002), [`T-007`](THREADS.md#t-007) |

## Record

Day Zero slice 3, the talk half. Every line table in `SAO_Voice` was
flat: one list per state, one per event, and every survivor in the
county drew from the same list. So a county that had learned nothing
still fled saying "Too many!" and warned each other with "Dead
nearby" - a count and a name that somebody acquires by living through
something. On a day-zero start that is the one case the mode exists to
make different, and it was the case the voice got wrong.

**The register.** A line table is now either a flat list, which
everyone shares, or a table of registers, and `resolve` picks the
register from the speaker's own lesson store before `pick` picks the
line. The boundary is the county's own: `SAO_Lessons` already defines
innocence as having learned nothing yet ([B1]/T-002), and [A29] made
the era per person for this reason - the first witnessed horror
teaches the first lesson through machinery that already existed. So
nothing new is stored and no threshold is invented.

Five tables are split, the ones about the dead and about violence:
FLEE, ALERT, ENGAGE, `warned` and `turnedSeen`. The taught lists are
the lines that were already there, unchanged. The innocent lists are
what those moments sound like in a mouth with no name for what it is
looking at - a person who has never seen one does not count them,
does not call them dead, and argues with a familiar face rather than
recognising it. Everything else stays flat and costs nothing.

**The fallback is the old behaviour.** A lesson store that cannot be
read returns the taught register, not the innocent one. A missing
answer should not make the whole county sound like it has seen
nothing; it should leave the voice exactly as it was.

**The crossing.** `SAO_Lessons.firstLessonHours` already dated the
earliest lesson and called it the day the world changed for that
person. `L.learn` reads whether the store was empty before it writes,
and raises one event when it was. It is a murmur, not forced, so the
quiet cross over in silence - and it can only happen once, because
after it the store is not empty. Guarded exactly like the telemetry
hook beside it, for the same two reasons: Voice is `client/` and
Lessons is `shared/`, and saying a thing must never be able to break
the learning of it.

**Border 123** runs `SAO_Voice` and the real `SAO_Lessons` in the
engine's VM with a stub body that records what was said. It sweeps
each split table with an innocent speaker and a taught one and
requires the two sets to be disjoint and neither empty; walks a flat
table the same way and requires it to be shared; checks that a store
which throws and a store which is absent both give the taught
register; checks the first lesson speaks once, the second not at all,
and a veteran never; and checks by text that no innocent line uses a
word somebody acquires - dead, infected, bitten, horde, turned - with
the taught lines as its control. That control is currently one line
("Dead nearby"), which is the honest state of the tables: the check
would catch a regression into the innocent lists, and it fails loudly
if the last taught use is ever rewritten away.

**Not in this batch.** The other half of chaos legibility is the
wire. Before the fall it is a hobbyist beacon ([A29]) and the county
wire carries the survivors' own politics ([A26]); it has no collapse
to carry yet, and that is its own slice. The lines here are diegetic
speech, exempt from DR-018 as [C5] and DR-018 both state, and are not
sandbox copy - Border 92 is untouched.

This governed record is the portable project history for this unit.
