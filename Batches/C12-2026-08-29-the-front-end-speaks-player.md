# C12 - The front end speaks player

| Field | Record |
|---|---|
| Batch | `C12` |
| Date | 2026-08-29 |
| Name | The front end speaks player |
| Status | Closed append-only batch - play verification pending (no play receipt) |
| Threads | [`T-030`](THREADS.md#t-030) |

## Record

The operator's correction, mid-play (DR-017, quoted there in full):
"'oh, zero means default' - that's engine language. That's not front
end language... They don't need to be the same thing. It's just
called representationality." The sandbox surface had collapsed the
backend's representation into the player's: two mode-sentinels
("World population (0 = size it from the map)", "Newcomers ceiling
(0 = follow world population)"), a coded scale ("Pressure from
outside (0 = none, 5 = an exodus)"), decode parentheticals on five
more labels, a state-decode ("on = one county, one voice"), and
tooltips spending sentences apologizing for the encoding ("Zero does
NOT mean..." - the apology being the proof the encoding leaked).

**The cut.** A mode is now a worded switch: "You set the population"
(off, and the county sizes itself from the installed map - the words
say so) over a plain "World population, when you set it" whose floor
is 1, because a floor of 0 existed only to spell the mode. The same
pair for the newcomers ceiling. The coded pressure scale became the
engine's own enum option with six worded values ("The road never
quickens" ... "An exodus") - the parser's `numValues`/
`valueTranslation` surface, verified in the jar before use. Every
remaining label speaks plain units ("People the road brings at once",
"Presence radius, in tiles", "Danger away from you, times the danger
beside you"), and every decode table and sentinel apology left the
tooltips.

**Representation is not implementation.** The backend keeps its
sentinels: internally, population 0 still means derive-from-the-map
(the DR-008 schema default), and the road scalar still runs 0-5. The
policy reader is the ONE place the worded surface becomes the
internal form, and says so.

**Migration, stated.** New worlds and untouched old worlds behave
identically (the switches default off, which is the derive/follow
behavior the old zeros defaulted to). An old world that had WRITTEN a
number into a sentinel-era dial must flip the new switch to keep
governing it, and an old world's custom road pressure returns to
"never quickens" until re-chosen - both stated here rather than
discovered, and both believed to touch nobody (the operator's two
saves ran the derive defaults; the boot digest's "(sized from the
map)" is the receipt).

**The border.** Border 91 (`tools/frontend_language_test.py`): no
number-equals or state-equals decode in any county label or tooltip,
no sentinel apology, every enum value worded and none a number in
disguise, the switches present with sentinel-free floors, and the
word-to-internal translation present in the policy reader. Control:
the pre-[C12] surface, which fails sixteen ways.

This governed record is the portable project history for this unit.
