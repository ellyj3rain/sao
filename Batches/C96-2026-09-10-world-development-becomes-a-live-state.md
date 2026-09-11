# C96 - World development becomes a live state

| Field | Record |
| --- | --- |
| Batch | `C96` |
| Date | 2026-09-10 |
| Name | World development becomes a live state |
| Status | Closed append-only batch - mod state, instrument, and border |
| Threads | [`T-006`](THREADS.md#t-006), [`T-008`](THREADS.md#t-008) |

## Record

The third category from the dependency substrate is world development. Before
this batch the county held homes, claims, larders, water stores, hearths,
motor pools and fortification as separate facts, but it did not read them
together as one live state.

`SAO_WorldDevelopment.lua` is that state. It reads identity, place attachment
and standing; reports home, ground, larder, water, hearth, motor pool,
fortification and a coarse development summary; and writes nothing.

The seven underlying facts remain visible beside the summary. The summary never
replaces them.

## What changed here

- `SAO_WorldDevelopment.lua` is added.
- `SAO_Inspect.lua` shows the state and writes it to the JSONL stream.
- Border 151, `tools/world_development_test.py`, holds the state live,
  read-only and visible.
- `SUBSTRATE.md`, `REPRESENTATION.md`, `PLAYABILITY.md` and `MAPS.md` name
  the new surface.

## Verification

Border 151 drives the shipped module in the engine's own VM against stub
identity, place-attachment and standing facts. It holds:

- a rootless person
- a homed person
- a stocked person
- a developed person
- a dead person
- the separation of the seven development facts from the coarse summary

## Operator boundary

No play receipt is claimed. The state is visible in the inspect panel, but
project choice and world-changing work are the next category's work.
