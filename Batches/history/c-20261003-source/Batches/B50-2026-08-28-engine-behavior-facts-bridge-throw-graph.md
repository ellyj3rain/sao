# B50 - Engine behavior facts; bridge throw graph

| Field | Record |
|---|---|
| Batch | `B50` |
| Date | 2026-08-28 |
| Name | Engine behavior facts; bridge throw graph |
| Status | Closed append-only batch - play verification pending (no play receipt) |
| Threads | [`T-008`](THREADS.md#t-008) |
| Superseded entries | `B180`-`B185` |
| Local Git commits | `06f471e`, `1be70c2`, `59c7323`, `bd5a803`, `c91ae51`, `e00a638` - local Git retains the full pre-seam history as engineering evidence |
| Provenance | Joined with immediately adjacent entries: the prior assistant fragmented this single piece of work across the listed raw entries; their substance is consolidated here. That fragmentation is the reason this catalog exists, and this note is its attribution. |

## Record

The VM facts arc: what this engine actually does, re-asked of the machine each
gate run. The census's share floor was boundary-documented rather than
vaguely true; then the probe hit a stack overflow and the sort was found to
be a left-pivot quicksort whose recursion depth follows input order, not size.
Half the standard library was found written in the engine's own stdlib.lua.
The protocol fields the engine emits were enumerated so our parsers match them
rather than our own guesses. And the bridge's throw contract was graphed:
every Lua-reachable Java method is safe by construction (catches, transitive
safety, or demonstrably no engine call), the graph computed rather than argued
per method, depth-capped; three reach checks got guards (guarded, not argued);
and the blinding border learned its four states after reporting an absent
border as a failed one - including the clone consequence of borders that exist
on one machine only.

This governed record is the portable project history for this unit. Anything it
was found to have asserted against later corrections is corrected in place above
with the correction cited; the raw entries remain reachable through
[`FORMER_LABELS.md`](FORMER_LABELS.md).
