# C56 - Borders skip when the game is absent

| Field | Record |
|---|---|
| Batch | `C56` |
| Date | 2026-09-08 |
| Name | Borders skip when the game is absent |
| Status | Closed append-only batch - the first CI run on the published tree is its receipt |
| Threads | [`T-030`](THREADS.md#t-030) |

## Record

The operator asked why nothing had reached the public repository.
`origin/main` was at the single squashed root pushed 2026-08-31 and
the local tree was 112 commits ahead - the whole C era from `[C8]` to
`[C55]`. Two reasons, one of them a blocker.

**Publishing was never in the close order.** The close ran record, log
row, state, version machine, jar, gate, commit, deploy, and stopped.
Nothing said to push, so nothing did, for eight days. `NEO.md` carries
the step now, ruled by the operator on 2026-09-08: a closed batch goes
to `origin/main` as one squashed commit, at the close, after the
deploy, and the divergence is checked at session start.

**And a push would have failed CI.** The workflow runs `tools/check.sh`
on ubuntu, where the game is not installed. Its own comment states the
design - the borders that read the installed game report SKIPPED,
because a check that cannot run must never look like a check that
passed - and fifteen of them exited 1 instead. `check.sh` reads
nonzero as a finding, so the gate would have refused and CI would have
gone red on the first commit.

The comment said "the six that read the installed game". That was true
when it was written; thirty-four tools read it now. A count in prose
goes stale in silence, which is exactly how eleven borders acquired
the wrong behaviour without anybody seeing it. The count is gone from
the comment and Border 128 counts them instead.

**What was wrong, per border.** Ten shared one guard that printed a
FAULT and returned 1; they print SKIPPED twice, in the convention
`item_api_test` already used, and return 0. Three built a `faults`
list from a missing install; they build a `skipped` list instead, so
the fault line still means a defect in this tree.
`age_bands_test` had no guard at all and walked into `build()`, which
runs `javac` and raises rather than returning false - a traceback in
place of a verdict. `traits_test` is narrowed rather than skipped: only
its driven half needs the game, so the text seams still run on CI, and
its cost check now tells a missing vanilla script from one that is
there and does not parse. `years_cost` said the right thing without
the agreed word.

**Border 128** holds the property, because nothing did. It finds every
tool that binds a path into the install, redirects those paths, runs
it, and requires exit 0 and a SKIPPED line. Thirty-four tools,
thirty-four skipping.

**It was wrong three times before it was right, and each time it
accused a tool.** Matching on any mention of the jar flagged
`modinfo_check`, which names an engine class in its docstring and
never opens it. Redirecting a fixed list of variable names missed
`places_test` (binds `GAME`) and `queue_drop_test` (binds `VANILLA`),
which then ran against the real install and passed silently. And even
with those names added it could not have worked, because
`places_test` derives its Distributions.lua from `GAME` on the next
line - a path computed at import is not fixed by rebinding the name
it came from. Redirecting by what a path IS rather than what it is
called fixed all three. Two of the four findings on its first run were
its own.

**The Laws in `NEO.md` are rewritten plainly**, on the operator's
direction, with the content unchanged. Two of the four were mirrored
turns - the register the writing rule directly above them bans. A law
written in the banned register teaches every session that reads it to
write that way, which is what happened.

**Not in this batch.** The publication itself. The tree is publishable
now; the backfill is the next act.

This governed record is the portable project history for this unit.
