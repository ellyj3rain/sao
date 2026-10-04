# C101 - Study terminal and human review handoff

| Field | Record |
|---|---|
| Batch | C101 |
| Date | 2026-09-29 |
| Timestamp | 2026-09-29 19:41 UTC / 12:41 PDT |
| Name | Study terminal and human review handoff |
| Status | Terminal receipt repair, durable saved-state recovery and immediate human-review handoff complete. |
| Threads | T-006, T-008, T-009, T-030 |

A normally saved native attempt was left looking live after its supervisor stop.
The launcher recorded a generic stop reason, the run verifier rejected that
legacy receipt, and the session supervisor killed the observation bridge before
it could project the terminal state. The native process itself had exited zero,
returned from the engine save path and left a complete save and observation
inventory. The failure was in terminal identity and handoff rather than the
simulation or save.

Future supervisor stops include the attempt, save, start clock, terminal clock
and bounded reason. The verifier accepts that exact receipt. Legacy recovery is
limited to the prior shape and requires its sole recorded error to be the
missing terminal receipt, a clean non-forced exit, sealed inputs and logs,
unchanged native images, exact save and observation inventories, a matching
final observed clock and a fully revalidated saved state. Recovery changes no
behavioral standing or dataset authority.

The durable study supervisor can restore a failed display state only after that
native run has become completed evidence. It accounts for the verified elapsed
world time, projects `saved` and `canContinue`, and leaves a replacement bridge
on the final frame. Terminal failure also receives a bounded projection window
before bridge cleanup, so Mousecat no longer retains an indefinitely live frame
when the producer has already stopped.

Every verified saved attempt now carries its cognition evidence into a durable
attempt-owned review outbox through the existing Speakeasy exporter and Mousecat
endpoint, so continuation cannot reuse an earlier attempt's evidence or receipt.
Preparation, queue success, delay, no reviewable outcome and ineligible evidence
are visible on the study projection. Delivery retries without advancing dataset
standing. A session with no completed disagreement records that fact instead of
manufacturing a review.

The retained attempt recovered from world hour 2.0 to 2.2500314712524414 with
reason `external-loadout-memory-boundary`, 121 saved files, zero runtime errors
and no observer player. Its durable study is now saved, continuation is
available, and its terminal cognition export contains no completed disagreement.
The separate R73 verified corpus has 15 completed disagreements awaiting human
disposition as two actor trajectories; 1,348 episodes without observed outcomes
remain sequestered and zero rows have been admitted or deleted.

| Verification | Result |
|---|---|
| Terminal receipt controls | Exact supervisor identity is accepted; duplicate, mismatched-save and mismatched-final-observation controls are refused. |
| Border 210 | Durable session recovery requires a completed clean native receipt and recognizes the terminal projection before cleanup. |
| Native verifier | The retained attempt re-verifies as completed against its sealed package, logs, images, observations and save inventory. |
| Real Mousecat handoff | Feed generation 2 projects `ended`, durable `saved`, `canContinue: true` and `no-reviewable-outcomes` at the fixed final clock. |
| Repository gate | `tools/check.sh` passes the complete current border suite. |

This batch strengthens the study and evaluation substrate. It does not approve a
scenario, infer a preferred strategy, choose between cognitive models or ratify
an observation as a dataset rule.
