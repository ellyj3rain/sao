# C90 - Organization and deference

| Field | Record |
| --- | --- |
| Batch | `C90` |
| Date | 2026-09-10 |
| Name | Organization and deference |
| Status | Closed append-only batch - documents only; no mod code |
| Threads | [`T-004`](THREADS.md#t-004), [`T-006`](THREADS.md#t-006) |

## Record

The operator named the next missing model: hierarchy, governance form, offices,
and deference. Democratic, despotic, and localist were given as example terms,
not implementation targets. The tree had a leader, a second, a proven hand, and
group metadata, but no general model for how authority is constituted, why it
is accepted, how it transfers, or how people refuse it.

This batch writes that model.

## What changed here

`ORGANIZATION.md` is the canonical contract. It defines:

- organization as a durable group with members, a decision method, and a boundary
- office as a decision right with jurisdiction
- governance forms as unsettled, democratic, despotic, localist, federated, or communal
- legitimacy as consent, competence, custom, election, inheritance, coercion,
  resource control, emergency, or tradition
- deference as a decision about one matter, with refusal, appeal, contest, exit,
  and resistance as real outcomes
- succession and dissent as parts of the same model

`REPRESENTATION.md` now points at the organization contract.

The version machine rolled the patch coordinate, and the shipped jar was
rebuilt from the bumped `VERSION`.

## No new border

This batch changes documents only. No behavior under `mod/` changes.
