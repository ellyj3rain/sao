# C59 - Debug-mode Lua compilation

| Field | Record |
|---|---|
| Batch | `C59` |
| Date | 2026-09-20 |
| Name | Debug-mode Lua compilation |
| Status | Closed through the enforced full commit gate. |
| Threads | [`T-006`](THREADS.md#t-006), [`T-007`](THREADS.md#t-007) |

## Startup repair

The development launch rejected Controller although Border 50 passed.
The installed compiler uses the same entry point in both cases. With
`Core.debug=true`, `LexState.new_localvar` indexes a fixed 200-entry debug
array by cumulative declarations; its preceding check limits simultaneous
locals instead. Sequential scopes therefore still overflow the debug array.

Controller's decision function had 634 cumulative locals, its update function
238, and Standing's leader election 286. Separate private functions now own
the existing phases. Calls preserve priority, snapshot timing, random draws
and early returns. This repairs compilation without changing action policy.

## Verification

Border 50 now compiles every shipped Lua source with debug disabled and enabled.
Controls exercise malformed syntax and 200/201 sequential local declarations;
the 201-local control must pass normally and fail in debug mode for the engine
array overflow. Missing modes, missing verdicts and unsuccessful processes
cannot become a clean result. Existing behavioral and mutation checks remain. The first full gate found an
indentation-dependent gesture reader; its correction checks the argument list
and rejects missing-item/comment controls. The failed run is retained, and the
enforced closing commit reruns every border.

The [evidence record](../artifacts/audits/20260920-0414Z-2114PST-debug-compilation/README.md) holds the
installed-engine reproduction, extraction review, validation and deployment
receipts. C57's retained startup log contains the same Controller failure, so
the defect predates C58. The successful C58 offline gate did not establish
debug-mode startup. F-090 records that correction.

## Continuation

Perception and world access remain next under R6/R10a. Startup validation and
controlled behavior checks do not establish loaded-world play acceptance or
complete the outstanding action, social and learned-model producers.
