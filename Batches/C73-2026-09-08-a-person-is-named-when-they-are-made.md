# C73 - A person is named when they are made

| Field | Record |
| --- | --- |
| Batch | `C73` |
| Date | 2026-09-08 |
| Name | A person is named when they are made |
| Status | Closed append-only batch - awaiting its first live receipt |
| Threads | [`T-006`](THREADS.md#t-006), [`T-007`](THREADS.md#t-007) |

## Record

DR-039, built. `backfillName` read a forename and surname off the
engine descriptor the first time a body was materialised for somebody,
so a survivor nobody had ever stood near carried the `Unnamed` sentinel
for the life of the save. Measured in the engine's own VM against the
shipped map at `[C71]`: **271 of 271 people in a dormant county.**

`[C71]` made that survivable by keying beliefs on the person rather
than on what they are called. The operator ruled for the cure: a name
is a fact about a person and not about their body.

## What changed

`Identity.create` is the one funnel every person is made through -
genesis, the mates who arrive with them, and the harness - and a person
is named there, before any body exists.

**The names are the engine's own.** `SurvivorFactory.MaleForenames`,
`FemaleForenames` and `Surnames` are public statics on the installed
jar and need no body (javap-verified). Four bridge methods expose them
as a length and an index rather than drawing from them, because `[C66]`
made every draw in this mod SAO's: the engine's generator carries no
state SAO can see, set or write down, and a county drawing a name from
it could not be run twice. The engine owns the names; `SAO.Rand` owns
the draw. This project ships no name list of its own.

**The pools are split by sex, so the record carries one.**
`Identity.femaleOf` is a hash fact - the same idiom as every durable
trait, deterministic per id, stored nowhere, identical in every session
and every replay.

The rate is Kentucky's own rather than a half:

| | |
|---|---|
| Kentucky, July 1 1993 | 1,837,344 male, 1,954,944 female |
| female share | **51.551 percent** |
| source | Census Bureau CO-99-12, *Population Estimates for Counties by Age, Race, Sex, and Hispanic Origin: Annual Time Series, July 1 1990 to July 1 1999*, `casrh21.txt` |

Summed over every Kentucky county and every age band. Codes 1 to 10
partition the population; 11 and 12 recount Hispanics of any race and
are excluded. The arithmetic was checked against a figure it should
nearly reproduce: the same file's July 1 1990 total is 3,686,686
against the April 1 1990 census count of 3,685,296, which is the
estimate-against-count difference and not an error. Seven of the file's
14,400 data lines carry NUL bytes as served and are dropped; none of
them is in 1993, checked rather than assumed.

**The shell agrees with the record.** `spawnShellNamed` already stamped
a real forename onto the descriptor and refused the placeholders
([C3]), but the descriptor's SEX came from `CreateSurvivor`, which
draws its own - so a record named Rosa could be handed a male body and
nothing existed to notice it. The record decides now, before the name
is stamped, because the name was drawn against it. The old arity stays
and defers to the engine's own draw, for the Knox adoption edge where a
person arrives already made.

**Where there is no engine there are no names.** A border, the sweep, a
load before the agent is up: the record keeps the sentinel and nothing
throws, which is exactly the pre-batch behaviour and is survivable
because `[C71]` keys beliefs on the person. Inventing a name here would
mean shipping a name list, which is the thing this avoids.

## Border 139, and its control

`tools/named_at_genesis_test.py`, in the gate. It runs the shipped
modules in the engine's own VM with two stand-in pools whose members
cannot be confused - every male name starts with M and every female one
with F - and reads the records that come out. A border asserting that
`Identity.create` calls `nameFromEngine` would pass a tree that called
it and dropped the answer.

| Property | What it reads |
|---|---|
| a person made with no name comes out with one | the record, before any body |
| the name matches the sex | the initial against the pool it must have come from |
| the draw is the county's | the same save twice, and a different save once |
| no pool is no crash | the sentinel stands and nothing throws |
| the split is the sourced one | the female share over four hundred people |
| a caller that passed a name keeps it | Knox adoption is not overwritten |

Its control is the `[C72]` tree, where a person made with no name comes
out `Unnamed`.

## What this does not do

Occupation, appearance and history are untouched. Whether the county's
work is distributed differently by sex is a question about 1993 labour
data and is not this batch.
