# C93 - The dependency substrate

| Field | Record |
| --- | --- |
| Batch | `C93` |
| Date | 2026-09-10 |
| Name | The dependency substrate |
| Status | Closed append-only batch - documents only; no mod code |
| Threads | [`T-008`](THREADS.md#t-008), [`T-030`](THREADS.md#t-030) |

## Record

The operator directed the next step: ground the work in the underlying
dependency substrate before building the category areas. The tree needed a map
of what exists, what is planned, and what each area of concern requires.

`SUBSTRATE.md` is that map. It records the current runtime substrate, the
current non-runtime substrate, the planned substrate, what makes each area of
concern possible, the cross-repository seams, and the external mod posture.

## What changed here

- `SUBSTRATE.md` is added.
- `MEMORY.md`, `README.md`, and `PROJECTS.md` point to it.

The version machine rolled the patch coordinate, and the shipped jar was rebuilt
from the bumped `VERSION`.

## No new border

This batch changes documents only. No behavior under `mod/` changes.
