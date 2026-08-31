# B46 - Player-reply channel repair

| Field | Record |
|---|---|
| Batch | `B46` |
| Date | 2026-08-28 |
| Name | Player-reply channel repair |
| Status | Closed append-only batch - play verification pending (no play receipt) |
| Threads | [`T-005`](THREADS.md#t-005) |
| Superseded entries | `B165` |
| Local Git commits | `66305cf` - local Git retains the full pre-seam history as engineering evidence |
| Provenance | Boundary retained: the raw entry was already one piece of work. |

## Record

The player's four-word bug report - "talking doesn't surface anything" - was
two stacked defects that had silenced the whole conversational surface.
Nineteen call sites passed the literal 0 where a tick goes, and the cooldown
arithmetic made that answer silent forever (zero is the most dangerous constant
to type into arithmetic: plausible where nil would have thrown); the fix moved
tick resolution into Voice itself, and the border that now checks every call
filling a tick parameter found five sites the hand-fix missed, one of them
legitimate and argued rather than changed. Then temperament: talkativeness had
silently gated whether a direct question registered at all - the roll decides
whether anyone volunteers, never whether being spoken to registers. This unit
is the one named in the operator's session notes, and its pair of borders
exists because both halves failed in ways invisible from outside.

This governed record is the portable project history for this unit. Anything it
was found to have asserted against later corrections is corrected in place above
with the correction cited; the raw entries remain reachable through
[`FORMER_LABELS.md`](FORMER_LABELS.md).
