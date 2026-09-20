# Debug-mode Lua compilation

Timestamp: 2026-09-20 04:14 UTC / 21:14 PST

The development launch rejected Controller although Border 50 passed.
The installed compiler uses the same entry point in both cases. With
`Core.debug=true`, `LexState.new_localvar` indexes a fixed 200-entry debug
array by cumulative declarations; its preceding check limits simultaneous
locals instead. Sequential scopes therefore still overflow the debug array.

Controller's decision function had 634 cumulative locals, its update function
238, and Standing's leader election 286. Separate private functions now own
the existing phases. Calls preserve priority, snapshot timing, random draws
and early returns. This repairs compilation without changing action policy.

| Evidence | Meaning |
|---|---|
| compiler-reproduction.txt | All 73 source files, three offending functions, sequential-local boundary controls. |
| CompilerProbe.java | Read-only driver using the installed compiler and explicit Core.debug. |
| controller-extraction.json | Original line spans, helper arguments and early-return counts. |
| controller-debug.txt | Refactored Controller compiles in the installed debug configuration. |
| review.json | Independent extraction and gate review, with bounded behavioral checks. |
| deployment.json | Installed file hashes and preserved save metadata. |

The full repository gate is enforced by the commit hook and CI. Its logs are
retained locally under `.git/c59-commit-gate.*`; the merged commit identifies
the checked source tree. Startup evidence is distinct from loaded-world play.

The first focused invariant check failed because its movement-block reader
assumed contiguous source. The corrected reader follows both owning functions
and checks a mutated dispatch guard. Original failed output remains beside the
correction. The gate's preexisting no-argument scope scanner examines no files;
C59 instead explicitly checked its changed Lua files and a bad fixture. R6
preparation owns the inventory/precision correction recorded in review.json.

The first full gate refused the gesture check's exact-indentation literal.
Its corrected reader checks the actual argument list, ignores comments and
rejects controls omitting the carried item or commenting out the call. A scan
of all 60 Controller/Standing Python readers found no other lost multiline
literal. `first-full-gate.*` retains the failed run; `gestures-corrected.txt`
records the focused repair. The enforced final commit reruns the complete gate.
`startup.json` records the repaired installation reaching the main menu without
the Controller/Standing compiler errors; no save was loaded for that check.
