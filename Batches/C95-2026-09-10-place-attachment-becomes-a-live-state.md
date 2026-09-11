# C95 - Place attachment becomes a live state

| Field | Record |
| --- | --- |
| Batch | `C95` |
| Date | 2026-09-10 |
| Name | Place attachment becomes a live state |
| Status | Closed append-only batch - mod state, instrument, and border |
| Threads | [`T-006`](THREADS.md#t-006), [`T-008`](THREADS.md#t-008) |

## Record

The second category from the dependency substrate is place attachment. Before
this batch the county held homes, known places, visits and claims as separate
facts, but it did not read them together as one live state.

`SAO_PlaceAttachment.lua` is that state. It reads identity, perception,
places and standing; reports home, the current building, known and visited
places, personal and group claims, the most-returned-to place and a coarse
attachment summary; and writes nothing.

The four underlying facts - home, ground, visited places and known places -
remain visible beside the summary. The summary never replaces them.

## What changed here

- `SAO_PlaceAttachment.lua` is added.
- `SAO_Inspect.lua` shows the state and writes it to the JSONL stream.
- Border 150, `tools/place_attachment_test.py`, holds the state live,
  read-only and visible.
- `SUBSTRATE.md`, `REPRESENTATION.md`, `PLAYABILITY.md` and `MAPS.md` name
  the new surface.

## Verification

Border 150 drives the shipped module in the engine's own VM against stub
identity, perception, place and standing facts. It holds:

- a rootless person
- a homed person
- a grounded person
- a settled person
- a dead person
- the separation of the four attachment facts from the coarse summary

## Operator boundary

No play receipt is claimed. The state is visible in the inspect panel, but
its effect on world-development choices is the next category's work.
