# C14 - The sweep, round one

| Field | Record |
|---|---|
| Batch | `C14` |
| Date | 2026-08-29 |
| Name | The sweep, round one |
| Status | Closed append-only batch - play verification pending (no play receipt) |
| Threads | [`T-008`](THREADS.md#t-008), [`T-030`](THREADS.md#t-030) |

## Record

The operator's item 7: sweep the tree with the repository's own
analysis discipline, hunting the classes already paid for. This round
ran the named classes with real denominators, per GOVERNANCE's
clauses (controls that flip, empty-set refusals, idioms enumerated
before patterns, hand-checks on fresh instruments). The verdicts:

| Class (its receipt) | Checked | Found |
|---|---|---|
| Silent defaults - pcall results used without the ok flag | 216 ok-pairs | 0 |
| Uncited engine claims - numbers wearing engine authority | every engine-authority comment, hand-sampled | 0 (the one instance died at [C11]) |
| Name-vs-call-form drift - calls to undefined functions (F-030/F-039) | 262 distinct qualified calls vs 366 definitions | 0 |
| Two clocks (F-028) - fields stamped on one axis, read on the other | 63 clock-touching fields | 0 (one field-NAME collision, hand-checked distinct) |
| Locale-sensitive formatting (F-041) | all Java format/case sites; all Lua float-formats | 0 (Lua floats are log-only, never parsed) |
| Swallowed functions ([C5]'s class) | whole tree | held by Border 83 |
| Mirrors that cannot fail | all 107 gated mirrors | held by Border 54 every gate run |
| Noisy instruments | the log surface | held by the buffered Log module ([B47]) |

**The instrument confessed first, again.** The call-target scanner's
first run reported nine missing functions - all one module, all one
UNENUMERATED definition idiom (`local Census = {} ... SAO.Census =
Census`). The reader was wrong, not the Lua; the fix went into the
reader and the enumeration note went into the promoted border's own
docstring. This is the same lesson as the memory it echoes: verify
the instrument before the code.

**What ships.** The precise instrument is promoted: Border 93
(`tools/call_target_test.py`) holds the silent-no-op class
permanently, refuses an empty reading, and its control - an injected
misspelled call in a copied tree - flips the verdict on exactly the
motivating shape. The two-clocks scanner stays an UNGATED method (its
field-name keying cannot distinguish families sharing a name, so it
is a sweep tool with a hand-check step, not a border - the
[B32] declined-to-ship discipline).

**What this round did not do.** It did not re-read whole modules line
by line (the [A24] rotation's depth); it hunted the paid-for classes
with instruments. Deeper rounds remain available on the operator's
word, and the honest denominator for this one is the table above.

This governed record is the portable project history for this unit.
