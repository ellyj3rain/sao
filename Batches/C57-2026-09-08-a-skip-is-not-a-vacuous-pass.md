# C57 - A skip is not a vacuous pass

| Field | Record |
|---|---|
| Batch | `C57` |
| Date | 2026-09-08 |
| Name | A skip is not a vacuous pass |
| Status | Closed append-only batch - the CI run on the published tip is its receipt |
| Threads | [`T-030`](THREADS.md#t-030) |

## Record

The backfill landed and CI refused it - not for the reason `[C56]`
fixed, but for one next to it.

Border 54 runs every gated mirror against a tree with the Lua removed
and refuses any that still pass, because a verdict about an empty set
says nothing about the mod. It classified a run four ways: it was not
there, it threw, it refused, it passed. A border that reads the
installed game and declines to judge returns 0 and prints a
verdict-shaped line, so it landed in "passed" - and on a machine
without the game, which is CI, eleven of them did.

The distinction is the one `run_blind`'s own docstring argues for. It
already separates "ran and refused" from "was never asked", and gives
the reason: a border that was not there had been reported as a border
that failed, which is the mistake the instrument existed to catch,
made by the instrument. Declining to judge is a third thing, and it is
the loud opposite of a vacuous pass in the same way a traceback is.
A fifth state, and the census prints it.

**This was not `[C56]`'s doing.** Eight of the eleven flagged borders
already said SKIPPED before that batch; they were being read as
vacuous passes on any machine without the game, and nobody had run the
gate on one. CI Verify has never succeeded on this repository - not on
the 2026-08-31 publish, not on either dependabot pull request. The
gate is green on the operator's machine, where the game is installed,
and that is the only machine it had ever been green on.

**Not in this batch.** Whatever else CI refuses once this is past. The
run on the published tip says what is left, and a claim that the
public gate is green is not made until one is.

This governed record is the portable project history for this unit.
