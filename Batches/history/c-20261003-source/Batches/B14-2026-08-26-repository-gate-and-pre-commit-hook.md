# B14 - Repository gate and pre-commit hook

| Field | Record |
|---|---|
| Batch | `B14` |
| Date | 2026-08-26 |
| Name | Repository gate and pre-commit hook |
| Status | Closed append-only batch - play verification pending (no play receipt) |
| Threads | [`T-030`](THREADS.md#t-030) |
| Superseded entries | `B22` |
| Local Git commits | `977e1d1` - local Git retains the full pre-seam history as engineering evidence |
| Provenance | Boundary retained: the raw entry was already one piece of work. |

## Record

The borders stopped depending on discipline. The verification tools moved into
the repository, path-independent; tools/check.sh runs the structural checks
and the nine borders with a precise detector (an informational check does not
gate because a hook that cries wolf gets disabled); tools/pre-commit installs
into .git/hooks with its re-install line documented; and the whole gate was
proven by breaking the tree on purpose and watching it refuse, then clear.
A gate nobody has watched fail is not a gate. The repository's gate started
running in CI on every push from this point.

This governed record is the portable project history for this unit. Anything it
was found to have asserted against later corrections is corrected in place above
with the correction cited; the raw entries remain reachable through
[`FORMER_LABELS.md`](FORMER_LABELS.md).
