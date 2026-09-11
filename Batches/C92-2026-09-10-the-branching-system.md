# C92 - The branching system

| Field | Record |
| --- | --- |
| Batch | `C92` |
| Date | 2026-09-10 |
| Name | The branching system |
| Status | Closed append-only batch - documents only; no mod code |
| Threads | [`T-004`](THREADS.md#t-004), [`T-006`](THREADS.md#t-006) |

## Record

The operator corrected the scope: the branching shape applies to the entire
simulation, not to labor alone. The whole county is one branching graph of
state, pressure, and action.

`BRANCHING.md` is the canonical contract. It defines:

- state surfaces as inputs to a single graph
- a branch as a causal path from pressure to consequence
- spectrums on every branch
- emergence from branch to pattern to role to office
- the player as a perturbation of the graph
- free-form conversation as the primary player surface

Labor, organization, deference, and communication are projections of that one
graph.

## What changed here

- `BRANCHING.md` is added.
- `REPRESENTATION.md` points to it.
- `ORGANIZATION.md` points to it.

The version machine rolled the patch coordinate, and the shipped jar was rebuilt
from the bumped `VERSION`.

## No new border

This batch changes documents only. No behavior under `mod/` changes.
