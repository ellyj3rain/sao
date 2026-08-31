# A2 - Engine control-surface verification

| Field | Record |
|---|---|
| Batch | `A2` |
| Date | 2026-08-26 |
| Name | Engine control-surface verification |
| Status | Closed append-only batch - play verification pending (no play receipt) |
| Threads | [`T-008`](THREADS.md#t-008) |
| Superseded entries | `A2`-`A3` |
| Local Git commits | `643d00c`, `7153ace` - local Git retains the full pre-seam history as engineering evidence |
| Provenance | Joined with immediately adjacent entries: the prior assistant fragmented this single piece of work across the listed raw entries; their substance is consolidated here. That fragmentation is the reason this catalog exists, and this note is its attribution. |

## Record

The first rule of the project was exercised on itself: the engine's NPC control
surface was established with file-and-line evidence before any claim built on
it. `javap` against the installed projectzomboid.jar and reads of the shipped
media/lua produced F-001 through F-006, correcting two A1-era assumptions -
isNpc() is declared on IsoGameCharacter, and the AIComponent seam is an input
channel of strafe axes and intent booleans with no goal field. The one open
question - whether engine pathfinding can produce routes an NPC body then
follows - was resolved affirmatively in the same sweep (F-007:
PathFindBehavior2 is independently drivable, request then poll then read the
next waypoint). G1 unblocked with every needed API on record.

This unit joins the A2 verification and the A2 resolution of its last open
question; the prior assistant logged them separately.

This governed record is the portable project history for this unit. Anything it
was found to have asserted against later corrections is corrected in place above
with the correction cited; the raw entries remain reachable through
[`FORMER_LABELS.md`](FORMER_LABELS.md).
