# C87 - What a belief carries

| Field | Record |
| --- | --- |
| Batch | `C87` |
| Date | 2026-09-10 |
| Name | What a belief carries |
| Status | Closed append-only batch - one mod seam and the display layer |
| Threads | [`T-006`](THREADS.md#t-006), [`T-008`](THREADS.md#t-008) |

## Record

`[C86]` came back with four named gaps and the operator ruled on
them, same day. **Distances: keep the value the county already
computes.** **Name keys: translate at the display layer.** **The
dead: decided inside the sister seam** - whether the dormant half
ever acquires zombie beliefs is folded into the ZAO trilateral work
so both halves of the dead-walking vocabulary land together; it is
not built here and stays named. And the next dataset proposal takes
**a new target the trades open up** - rows where the person's trade
is the situation's hinge - which is the batch after this one, not
this one.

This batch builds the two rulings that were ready to build.

## The distance travels the seam

The road-meeting caller computed the distance between two people to
decide whether they met - `dx * dx + dy * dy <= MEET_RANGE *
MEET_RANGE` (`SAO_Population.lua:2344`) - and threw it away,
passing only the position. The belief wrote `dist = (prev and
prev.dist) or 0` (`SAO_Perception.lua`). Two consequences, measured
before this was designed: **a first meeting was recorded at
distance zero**, and **a re-meeting carried the first meeting's
distance forever** - meet at three tiles, meet again at one, and the
county still believed the second meeting happened three tiles out.
The scanner path - the live half - always wrote the real distance;
`sawPerson` was the one person-belief writer that did not.

`sawPerson` now takes the distance as its last argument and the
caller passes the value it already computed. A caller that knows no
distance - the same write from any other hand - keeps the honest
seed: carried, then zero. The first-night spelling computes from the
mates' own positions rather than defaulting, so the two spellings of
one write cannot drift apart if mates ever spawn apart (they stand
on the same tile today, and the computed value is exactly that).

This is a mod change and the first here in five batches. What it
changes is bounded by the file's own doctrine (F-014): a belief's
`dist` is a seed, and every consumer with a position of their own
recomputes from it. Consumers without one - the dormant county,
which is everybody in a dump - now read the true meeting distance
instead of zero or a stale value.

## The plain reading beside the key

The engine stores a person's name as its own translation key
(`SurvivorName_Elliot`) and renders it in English as the key's own
suffix. That is not an assumption: Border 147 reads the engine's own
`Translate/EN/SurvivorNames.json` and holds that every entry
renders as its suffix - all 6008 of them, entry for entry.

`plainNameOf` lives in the sweep prelude - the environment the dump
actually runs - and the dump's member row carries `displayName`
beside `name`. Nothing captured is curated: the raw key stays, the
engine's own storage is unchanged, and a name that is not a key -
the plain county's sentinels - reads as itself. A row now reads
`Elliot Segura`; the key it came from stays recoverable beside it.

## Border 147, and its control

`tools/belief_payload_test.py`, in the gate, running the shipped
modules behind the REAL sweep prelude - the one the dump runs,
because the plain reading lives there.

| Property | Measured on the shipped tree |
|---|---|
| a meeting writes the computed distance, both ways | a pair held three tiles apart meets; both beliefs read `dist = 3` |
| a re-meeting carries the new distance | the same pair meets again at one tile; both beliefs read `dist = 1` - the stale carry is gone |
| a stated distance reaches the belief | a direct call stating 5 writes 5 |
| a silent caller keeps the honest seed | after a stated 5, a silent re-write carries 5; a silent first write gives 0 |
| the plain reading is the engine's own English | 6008 of 6008 entries of the engine's own EN table render as their key's suffix, checked in the border |
| the plain reading answers in the dump's own environment | `Elliot Segura` for a keyed name, `Unnamed Survivor` for a sentinel, read through the prelude the dump runs |
| the first-night spelling computes | the two `sawPerson` call sites in the unit-spawn path pass a distance computed from their own positions |

Its control is the `[C86]` tree, which fails naming thirteen things:
the three-tile meeting wrote zero, the re-meeting wrote zero both
ways, a stated 5 was refused, the carried seed was erased, the
prelude has no plain reading to ask, the dump's member row carries
no `displayName`, and the gate does not run the border.

## What comes next, ruled

- **The new target.** The next dataset proposal authors rows where
  the person's trade is the situation's hinge - the engine-paid
  skills are evidence the plain dump never had. That needs a new
  capture point in the dump, which is its own instrument batch, and
  then the rows as a proposal the operator rules on.
- **The dead.** Decided inside the sister seam; nothing here touches
  the zombie-belief set, which stays empty and stated until that
  work.
- **The flag.** `--engine` still moves to the default only after the
  operator has read rows authored from an engine dump - which the
  new target will produce.

## Mod code, one seam

Two files under `mod/` change: the meeting caller passes what it
computed, and the write takes what the caller says. Nothing else in
the shipped surface moves - the designation deal, the census reads,
the belief keys are exactly as they were. The seed discipline
(F-014) is unchanged; the seed itself is now the truth.