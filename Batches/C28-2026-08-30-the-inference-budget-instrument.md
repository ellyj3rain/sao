# C28 - The inference budget instrument

| Field | Record |
|---|---|
| Batch | `C28` |
| Date | 2026-08-30 |
| Name | The inference budget instrument |
| Status | Closed append-only batch - awaiting its measurement receipt |
| Threads | [`T-005`](THREADS.md#t-005), [`T-008`](THREADS.md#t-008) |

## Record

The ratified talking-system design (SPEECH_ML_DESIGN.md) fixes
model size from a measurement: what a forward pass costs on the
game's own JVM, on the game's own thread. This batch builds the
instrument that takes it.

The bridge's `inferenceBudgetProbe(dim, layers, runs)` runs a
model-shaped workload - chained dim-by-dim matrix-times-vector
passes in float32 with a tanh between, the dominant cost of a small
network - with deterministic weights (no randomness: every run
measures the same work), one warm pass so the JIT is not what gets
timed, nanosecond clocks, and the checksum riding the report so the
JIT cannot delete the workload. It runs on the calling thread,
which is the honest worst case; a worker thread would lift the
per-frame ceiling, and that choice is made later, with these
numbers in hand.

The debug menu fires it ("Measure the speech budget"): a ladder of
five shapes from 64x4 to 512x8, thirty runs each, reported through
the one logger under the BUDGET tag. The console lines are the
receipt the design waits on; the sizing decision cites them, not a
guess.

Also this day, ratified through Crucible and recorded in the design
doc: the period world model comes as researched world documents
ratified by the operator before they teach anything, with curated
period text for language texture; and the speech-ML pipeline lives
as its own tracked project beside SAO (the mod-patches precedent),
with SAO receiving only the shipped models.

Border 102 holds the instrument's honesty: deterministic, warmed,
nanosecond-timed, checksum-carried, triggered, tagged, and its
worst-case conditions named. Its control is the pre-batch tree,
which faults five ways.

This governed record is the portable project history for this unit.
