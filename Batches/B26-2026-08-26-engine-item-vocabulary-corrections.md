# B26 - Engine item-vocabulary corrections

| Field | Record |
|---|---|
| Batch | `B26` |
| Date | 2026-08-26 |
| Name | Engine item-vocabulary corrections |
| Status | Closed append-only batch - play verification pending (no play receipt) |
| Threads | [`T-008`](THREADS.md#t-008) |
| Superseded entries | `B63`-`B64` |
| Local Git commits | `01c83c7`, `1aa480f` - local Git retains the full pre-seam history as engineering evidence |
| Provenance | Joined with immediately adjacent entries: the prior assistant fragmented this single piece of work across the listed raw entries; their substance is consolidated here. That fragmentation is the reason this catalog exists, and this note is its attribution. |

## Record

The mod stopped describing an engine that had moved on. Four want-vocabulary
literals matched nothing the engine produces: medical items read through an
accessor that cannot carry script data (every bandage unreachable), tools the
same, smokes hard-coded to an item id that does not exist in this build, seeds
matching exactly one sunflower against 79 real seeds. All corrected to the
engine's own surfaces (display categories, the SMOKABLE and IS_SEED tags),
with the plank/nails absence in the game's tag vocabulary recorded as a known
edge rather than papered. The border born here compares our literals against
the game itself - the only border reading data outside the repository, and
the one that reports SKIPPED rather than "none" when no install is present,
because a check that cannot run must never look like one that passed. The
skill-book gate decision was left for the operator with the sharpening number
(the script tag covers 561 items to the display category's 198), not widened
by fiat.

This governed record is the portable project history for this unit. Anything it
was found to have asserted against later corrections is corrected in place above
with the correction cited; the raw entries remain reachable through
[`FORMER_LABELS.md`](FORMER_LABELS.md).
