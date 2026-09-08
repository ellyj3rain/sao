# C59 - Main is protected and batches arrive by pull request

| Field | Record |
|---|---|
| Batch | `C59` |
| Date | 2026-09-08 |
| Name | Main is protected and batches arrive by pull request |
| Status | Closed append-only batch - this batch's own pull request is its receipt |
| Threads | [`T-030`](THREADS.md#t-030) |

## Record

`[C56]`, `[C57]` and `[C58]` were pushed straight to `origin/main`.
Thirty-one commits, no branch, no pull request, no merge. CAO is the
standard for how this repository publishes and always was; CAO's
`main` carries squash-merged pull requests. This one was taking direct
pushes.

Nothing stopped it because nothing was set to. CAO's `main` is
protected - a pull request is required, `ci-verify` and
`dependency-scan` are required and strict, admins are included, the
history must stay linear, and force pushes and deletions are refused.
SAO's `main` answered 404: no protection at all. On CAO those three
pushes would have been rejected at the server. Here they landed.

`main` is protected now on the same shape, with this repository's own
checks: a pull request required, `ci-verify` and `codeql-python`
required and strict, `enforce_admins` on, linear history, no force
pushes, no deletions, conversations resolved.

`NEO.md`'s publishing convention was wrong and is corrected. It said a
closed batch is pushed to `origin/main` as one squashed commit - which
is how the mistake got written down as the rule two batches after it
was made. It says branch, pull request, merge now, and says to merge
it rather than leave it open.

**The thirty-one commits stay.** Rewriting published history to
re-land them through pull requests would be a force push over the
public record to make the record look like the process was followed,
which is worse than the record showing that it was not. The
correction is forward-only and this batch is the first to use it.

**What this cost, stated because it is the point.** Three separate
times this session the check that was skipped was against the
standard rather than against errors: the writing register was matched
to the surrounding files instead of the stated rule, the borders were
never run the way CI runs them, and `main` was never asked whether it
should take a direct push. Errors announce themselves. A standard has
to be gone and read.

This governed record is the portable project history for this unit.
