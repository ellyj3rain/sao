# C27 - What one person knows, as one surface

| Field | Record |
|---|---|
| Batch | `C27` |
| Date | 2026-08-30 |
| Name | What one person knows, as one surface |
| Status | Closed append-only batch - awaiting its first live receipt |
| Threads | [`T-005`](THREADS.md#t-005), [`T-006`](THREADS.md#t-006) |

## Record

Rung 1 of the ratified talking-system design (SPEECH_ML_DESIGN.md,
all six decisions passed Crucible 2026-08-29/30), and the first code
the design permitted: `SAO_Knowledge.lua`, one surface answering
what survivor N knows about topic T, with how they know it and how
old it is.

**The shape is the models' contract.** Nine topics form the closed
answer space the understander will resolve free text into (self,
person, zombies, dead, food, water, house, ground, lessons). Every
fact is a flat record carrying source, teller where one exists, and
age both raw and in a person's words. `conditioning()` bundles what
the speaker is ratified to read beside the facts: the eight
temperament axes, trust toward the listener, and the moment - war,
grief with its name, debt, hostility, their own bite. `claims()` is
the one call an exchange turn makes. Food and water answers reach
through [C25]'s own knowledge surface - the county speaks the same
places it walks to.

**Read-only by law.** The one-loop law, enforced twice: textually
(no ModData - even getOrCreate writes on first touch - no trust
mutation, no tell, no record assignment) and by construction (every
sibling read sits behind pcall inside a function). Asking changes
nothing.

**Offline by construction, driven not asserted.** The module loads
in a bare Kahlua VM - the engine's own, via the gate's existing
LuaRun - against a stub county (probe_knowledge.lua), and Border
101 asks it eleven real questions every run: crowds counted and
aged, the dead named with their teller, lessons withheld below the
earned line and given past it, the house speaking its leader,
conditioning carrying the war and the debt. The border's own first
run taught the workdir law (Kahlua's stdlib loads from cwd - the
engine_facts idiom adopted), and the invariant sweep caught the
surface overloading the county's `kind` vocabulary - fact records
tag themselves `fact` now, and the news domain keeps its word.

**Gauging them starts today.** The inspect panel reads the selected
person through `claims()` - whether they answer you openly or
guardedly, what they carry (war, grief, debt), and how much they
hold per topic - so what a survivor knows can be examined before
anything speaks. Per the ratified order, what follows is the
in-process inference budget measured on the real game, then the
data pipeline as its own tracked project with harvest sourcing
brought to Crucible.

This governed record is the portable project history for this unit.
