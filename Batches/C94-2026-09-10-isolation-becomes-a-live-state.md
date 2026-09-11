# C94 - Isolation becomes a live state

| Field | Record |
| --- | --- |
| Batch | `C94` |
| Date | 2026-09-10 |
| Name | Isolation becomes a live state |
| Status | Closed append-only batch - mod state, instrument, and border |
| Threads | [`T-006`](THREADS.md#t-006), [`T-008`](THREADS.md#t-008) |

## Record

The first category from the dependency substrate is isolation. Before this
batch the county held a static contact factor and a wanted circle, but not a
live reading of how much company a person actually had.

`SAO_Isolation.lua` is that live state. It reads identity, perception,
standing, disposition and history; reports appetite, group size, known people,
trusted people, recent people, hours since contact, contact and isolation; and
writes nothing.

Appetite and isolation are separate facts. A loner alone and a house person
alone both read isolation `1.0`, but their appetite for company differs.

## What changed here

- `SAO_Isolation.lua` is added.
- `SAO_Standing.lua` gains a read-only `relationsOf(id)` surface.
- `SAO_Inspect.lua` shows the isolation state and writes it to the JSONL
  stream.
- Border 149, `tools/isolation_state_test.py`, holds the state live,
  read-only and visible.
- `SUBSTRATE.md`, `REPRESENTATION.md`, and `PLAYABILITY.md` name the new
  surface.

## Verification

Border 149 drives the shipped module in the engine's own VM against stub
identity, perception, standing, disposition and history facts. It holds:

- a solitary person reads isolation `1.0`
- a grouped person reads contact from living company
- a saturated social person reads contact `1.0`
- a dead person answers nothing
- appetite is separate from isolation
- the module writes no social state
- the inspect panel and JSONL stream expose the reading

## Operator boundary

No play receipt is claimed. The state is visible in the inspect panel, but
its effect on later choices is the next category's work.
