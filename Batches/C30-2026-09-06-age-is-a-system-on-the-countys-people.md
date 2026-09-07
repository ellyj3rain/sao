# C30 - Age is a system on the county's people

| Field | Record |
|---|---|
| Batch | `C30` |
| Date | 2026-09-06 |
| Name | Age is a system on the county's people |
| Status | Closed append-only batch - awaiting live receipts (a child in the street, an elder's slower walk, a death of old age in the log) |
| Threads | [`T-002`](THREADS.md#t-002), [`T-007`](THREADS.md#t-007), [`T-006`](THREADS.md#t-006) |

## Record

[B37] gave everybody an age between nineteen and sixty-eight and
said why it stopped there: the mod modelled no children, and
inventing one was worse than the gap. The operator ruled (DR-032)
that the county is to have children and elders, that an elder needs
no model, and that the mods which already model age come in as
SAO's own where their source is readable. [C29] gave a child a body
on the render path. This batch gives the county its ages.

**The bands.** `SAO_History.AGE_BANDS` now runs from six to ninety,
weighted from the 1990 resident population by age (the source is
named in the code beside the numbers) and folded to a county that
keeps no infants: children from six, elders past sixty-eight. An age
is still a fact about the person, drawn from the identity hash, so
two sessions agree; the relations machinery ([B38]) already turns a
sixteen-year gap into parent and child, so households have children
the moment the bands do.

**The stages.** Getting Old's five (Devlin; source public; taken
with the author's permission as the operator settled it, CREDITS.md):
child, young, adult, middle, elder, at its boundaries.
`SAO_History.stageOf` is what the drift and the work read.

**The work.** The age decides before the draw does: a child is a
student, an elder past sixty-eight a retiree unless the census kept
them home - both the census's own rows (DR-011), so everything
downstream reads a real one.

**The pace and the size.** `speedModOf`: a child walks at Growing
Up's pace for the age, an elder slows from sixty-eight to four
fifths at ninety (ours, and said so), an adult answers 1 and nothing
is set. `heightScaleOf` ([C29]) now answers below 1 for real
children. The body takes both once, after it is dressed.

**The drift.** `SAO_Age` (client) runs every ten in-game minutes
over the living bodies and applies Getting Old's per-stage drift at
its chance - the young gain stamina and shed tiredness and pain, the
middle-aged lose stamina and gain tiredness, pain and stress, elders
more so - on the engine's own stats. The mod applies its numbers on
every player update; the numbers read as intent at a cadence, and
ours is the ten-minute pass. Its stumble calls a Stats method this
build does not carry (javap: no `setTripping` on 42.20), so there is
no stumble: nothing is called that the jar does not have.

**Death of old age.** Not the mod's per-frame chance but the life
table: `oldAgeRiskPerDay` is zero under sixty and, from sixty, the
yearly probability of dying at the age spread over the year's days
(NCHS, United States Life Tables, 1997, total population - the
nearest year whose table is machine-readable; the 1993 table is an
image scan, and the four years between move the figures by a few
percent). Once a day the module rolls it for everyone alive - a
hash of the person and the day, so who died when is a fact too. A
dormant elder dies on the roll with the cause "old age"; a living
one is marked, and the mod's decline finishes them so the body dies
on the engine's own path and the corpse net records it ([C8]).

**Border 105** drives `SAO_History` in the engine's own VM against
a stub county (the [B48] instrument): six hundred people carry
children and elders in the declared shares, no infants, and the same
age twice; the stages sit at their boundaries; the age decides the
work; a child is smaller and slower and an adult is 1 for both; an
elder is slower and not smaller; the risk is zero under sixty, rises
with age, and at eighty is the table's figure over the days. By text
it holds the module to the ten-minute pass, the cause, the mark, and
the absence of `setTripping`, and the body to pacing after sizing.
Its control is the pre-batch tree, which faults eight ways.

**Not in this batch.** The child's day - the fear floor, night
terrors and the comfort object, literacy earned by reads, the
experience throttle, the archetypes - and any change to what a
child decides in danger beyond what the settled class already does
(flee more than fight). The next batch.

This governed record is the portable project history for this unit.
