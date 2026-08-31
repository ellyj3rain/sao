# A3 - First survivor in the world

| Field | Record |
|---|---|
| Batch | `A3` |
| Date | 2026-08-26 |
| Name | First survivor in the world |
| Status | Closed append-only batch - play verification pending (no play receipt) |
| Threads | [`T-008`](THREADS.md#t-008) |
| Superseded entries | `A4`-`A6` |
| Local Git commits | `01da8b9`, `19040be`, `8716791` - local Git retains the full pre-seam history as engineering evidence |
| Provenance | Joined with immediately adjacent entries: the prior assistant fragmented this single piece of work across the listed raw entries; their substance is consolidated here. That fragmentation is the reason this catalog exists, and this note is its attribution. |

## Record

The G1 gate: one NPC body constructed from verified APIs, spawned at a valid
square drawn from real spawn-region data, rendered as a human, able to walk a
route, and removed cleanly - population capped at one until every condition
held. The work shipped as the mod/ tree with the dual mod.info layout, the
Identity/Body/Locomotion/Controller modules (records in global ModData are the
person; bodies materialize and release with snapshot-back), and a debug-gated
harness. The first live run caught two defects the static tree could not show:
construction does not load a model (fixed with the verified
dressInRandomOutfit + resetModelNextFrame pair), and a throw inside the
locomotion tick propagated to the tick handler (fixed with fault gates on
every per-tick path - log once, disable after three, never throw per frame).
Both fixes are the first instances of patterns the project reused forever
after.

This governed record is the portable project history for this unit. Anything it
was found to have asserted against later corrections is corrected in place above
with the correction cited; the raw entries remain reachable through
[`FORMER_LABELS.md`](FORMER_LABELS.md).
