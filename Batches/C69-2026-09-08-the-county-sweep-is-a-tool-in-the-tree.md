# C69 - The county sweep is a tool in the tree

| Field | Record |
| --- | --- |
| Batch | `C69` |
| Date | 2026-09-08 |
| Name | The county sweep is a tool in the tree |
| Status | Closed append-only batch - no live receipt is owed; nothing under `mod/` changes except the version stamp |
| Threads | [`T-008`](THREADS.md#t-008), [`T-009`](THREADS.md#t-009) |

## Record

The sweep found `[C67]` and `[C68]` - the two largest defects this
project has had - and it lived in a scratch directory. It has been
rebuilt from nothing in more than one session, and both times the
rebuild reintroduced a gap that invalidated its own results.

The operator asked why the shipped world was not built into the tool
in the first place. It is now, along with everything else the sweep
needs, in `tools/`.

## What changed

| File | What it is |
| --- | --- |
| `tools/county_sweep.py` | the entry point: N counties, a distribution |
| `tools/sweep/world.py` | the shipped world, read off the installed game |
| `tools/sweep/prelude.lua` | what the engine gives the mod |
| `tools/sweep/places.lua` | `IsoMetaGrid` over the extracted buildings |

Nothing under `mod/` changes except the version stamp. The shipped
artifact is unaffected.

## It is not a border and it is not in the gate

A border is a point and a county is a distribution. Whether a social
structure forms is a proportion over many runs, not a verdict about
one, and a gate that turned this gradient into a pass or a fail would
be forcing a deterministic result over the thing being measured. So it
prints min, median, max and mean over N counties and stops. What the
numbers mean is the reader's.

It skips cleanly with an explanation when the game is not installed,
the same discipline `[C56]` set for the borders - and there is nothing
to fail, so there is nothing to fake.

## The module check, which is the durable half

Twice a sweep ran to completion and reported a full set of numbers that
meant nothing, because a module the loaded code calls was not loaded.

- `SpawnRegionMgr` absent: `loadRegionPoints` returned nil, genesis
  deferred forever, and every county measured had genesis switched
  off. Zero arrivals, ever, reported as a county.
- `SAO_Census` absent: `SAO.Census` was nil, nobody in any county held
  an occupation, and every call reaching it died inside a `pcall` -
  including the one that deals a company its work.

Neither failed loudly, and each was found only after conclusions had
been drawn on top of it. So before any county runs, the tool resolves
every `SAO.X` the loaded modules reference against what is loaded.

A module can be correctly absent: the ones needing a body, a screen or
the player are, because a sweep is the unobserved half of the county.
Those are declared by name with the argument for each - eight of them -
so a real gap is reported on its own rather than buried in a list of
expected ones. The first draft of this printed all of them
undifferentiated, which is the failure mode `[C57]` named for borders
and is no better in an instrument.

It does not stop the run. It makes the gap visible instead of letting
it be found three conclusions later.

## What it reports

Against the tree at this batch, over four counties, 1096 owed days:

```
11 towns, 89 spawn points, 199 cells, 2831 buildings, 21202 rooms
spawn points inside an extracted building: 89 of 89

survivors at the end            1     4     5     3.0
houses founded                 16    22    23    20.2
houses standing at the end      0     0     1     0.2
pairs above the company line  248   258   274   257.5
dead still on a roster          0     0     0     0.0

counties that founded a house               4/4  (100%)
counties with a house standing at the end   1/4  ( 25%)
counties with anybody left alive            4/4  (100%)
```

The last row of the table is `[C68]` holding in the committed tool.
The two rows about houses are the distinction `[C68]` had to introduce
and this tool now reports as two separate things rather than one
number that quietly changed meaning.

## Cell size 256, checked rather than assumed

The `.lotheader` reader turns cell coordinates into world coordinates,
and getting that constant wrong would put every building in the wrong
place while still producing a plausible-looking map. It is established
by the spawn points: every one of the 89 shipped spawn points must land
inside an extracted building, and they land in livingrooms and
kitchens, which is what a spawn point is. The tool reports that count
on every world build rather than asserting it - the same posture as the
rest of it.

## Not in this batch

The generated world is not committed. It is the game's data, it is
large, and it is only meaningful against the install that produced it,
so it is cached outside the tree and rebuilt when the game's maps are
newer.

The trajectory corpus. `[C65]` gave the years pass a telemetry record
per simulated day, and this tool drives exactly the runs that would
fill it. Wiring the sweep's output into that corpus is its own batch.
