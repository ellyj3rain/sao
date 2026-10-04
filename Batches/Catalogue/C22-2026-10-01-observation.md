# C22 - Read-only person/world observation

| Field | Current definition |
|---|---|
| Catalogue generation | `20261003-shared-boundaries` |
| Attainment anchor | 2026-10-01; reconstructed from the last contributing source, with original event chronology preserved |
| Standing | Evidenced implemented scope with separately stated remaining work; publication and rendered acceptance follow component evidence |
| Version classification | kohai: Source-bound read-only projections and publication mature existing inspection and telemetry. |

## Shared contract

| Boundary | Definition |
|---|---|
| Canonical owners | [mod/42.20/media/lua/client/SAO_Inspect.lua](../../mod/42.20/media/lua/client/SAO_Inspect.lua); [mod/42.20/media/lua/client/SAO_Observation.lua](../../mod/42.20/media/lua/client/SAO_Observation.lua); [mod/42.20/media/lua/client/SAO_Telemetry.lua](../../mod/42.20/media/lua/client/SAO_Telemetry.lua); [mod/42.20/media/lua/shared/SAO_Isolation.lua](../../mod/42.20/media/lua/shared/SAO_Isolation.lua); [mod/42.20/media/lua/shared/SAO_PlaceAttachment.lua](../../mod/42.20/media/lua/shared/SAO_PlaceAttachment.lua); [mod/42.20/media/lua/shared/SAO_WorldDevelopment.lua](../../mod/42.20/media/lua/shared/SAO_WorldDevelopment.lua); [mod/42.20/media/lua/client/SAO_Harness.lua](../../mod/42.20/media/lua/client/SAO_Harness.lua); [tools/world_lab/StudyExport.java](../../tools/world_lab/StudyExport.java) |
| Admitted inputs | Existing person/world/graph state and run bounds; Produced private/runtime state, explicitly inspected person, budget and world/session epoch. |
| Produced outputs | Scoped summaries, inspection and explicit unknowns; Lean cache retains source clock; reserve bounded channel before copy; worker handles detached values only; truthful omission/defer/epoch result; drain on stop. |
| Owned state | Diagnostic receipts and run provenance; Hashed snapshots/publication receipts; transient worker queue, never actor belief. |

## Boundary rationale

- C3/C28/C36/C50 share observer semantics; observations become knowledge only through admission.
- Existing authority: Observation game-thread projections; StudyExport bounded detached serialization/atomic async publication. Consumers: Study archives, Speakeasy review, Mousecat inspect, diagnostics.

## Delivered scope

- Source C3 (implemented): Harness/person-state/menu inspection exposes prediction and fallback boundaries.
- Source C28 (implemented): Run bounds, inputs and trajectories recorded.
- Source C36 (read only): Isolation/attachment/development inspection and export.
- Source C50 (repair): Diagnostic refusal/provenance and bounded 90/365-day observations.
- Source C87 (source-scoped implementation): Bounded cached private source-clock state.
- Source C104 (source-scoped implementation): Bounded/deferred encoding and stable regions prevent observation/physics failure.
- Source C105 (source-scoped implementation): Game-thread detached capture, bounded async encoding/epoch/atomic write and stop drain.
- Source C106 (source-scoped implementation): Six coherent timing stages, scoped diagnostics and bounded atomic retry.
- Source C109 (source-scoped implementation): Lean cached versus explicitly inspected rich state retains source clock; truthful loaded-omitted/unavailable geometry budgets.

## Dependencies and D work

| Dependency | Required relationship |
|---|---|
| [C3: Durable person identity and admission](C3-2026-09-08-identity.md) | Identify the observed person without admitting observer knowledge into that person. |
| [C19: Immutable decision-time evidence and model/data joins](C19-2026-09-29-data.md) | Retain source/run/revision provenance and explicit evidence horizons. |

- Build missing causal producers rather than treating summaries as outcomes.
- R11/R14/R15: currentness/completeness/timing remain separate; bounded export cannot silently erase decision inputs or prove game-wide throughput.

## Source contributions and measured status

Source C labels below belong to the preserved pre-migration generation. Each source can contribute to several contracts; its bytes and evidence are preserved once by the manifest.

| Source | Contribution | Implementation / verification / publication |
|---|---|---|
| [C3](../../Batches/history/c-20261003-source/Batches/C3-2026-08-29-inspection-and-person-state.md) | Harness/person-state/menu inspection exposes prediction and fallback boundaries. | completed observation / source-scoped evidence and limits retained in archived record / committed-at-source-head |
| [C28](../../Batches/history/c-20261003-source/Batches/C28-2026-09-08-simulation-telemetry-and-reproducibility.md) | Run bounds, inputs and trajectories recorded. | completed scoped / source-scoped evidence and limits retained in archived record / committed-at-source-head |
| [C36](../../Batches/history/c-20261003-source/Batches/C36-2026-09-10-isolation-attachment-and-development-observations.md) | Isolation/attachment/development inspection and export. | completed read only observation / source-scoped evidence and limits retained in archived record / committed-at-source-head |
| [C50](../../Batches/history/c-20261003-source/Batches/C50-2026-09-18-historical-simulation-recovery-and-evidence.md) | Diagnostic refusal/provenance and bounded 90/365-day observations. | mixed withdrawal and completed repairs / source-scoped evidence and limits retained in archived record / committed-at-source-head |
| [C87](../../Batches/history/c-20261003-source/Batches/C87-20260926-2218Z-1518PST-survival-observation-and-continuity.md) | Bounded cached private source-clock state. | implemented scope recorded; corrections retained / source-scoped evidence and limits retained in archived record / committed-at-source-head |
| [C104](../../Batches/history/c-20261003-source/Batches/C104-20260930-0455Z-2155PST-sustained-resource-planning.md) | Bounded/deferred encoding and stable regions prevent observation/physics failure. | implemented scope recorded; corrections retained / source-scoped evidence and limits retained in archived record / committed-at-source-head |
| [C105](../../Batches/history/c-20261003-source/Batches/C105-20260930-1100Z-0400PST-resource-outcome-trials-and-asynchronous-observation.md) | Game-thread detached capture, bounded async encoding/epoch/atomic write and stop drain. | implemented scope recorded; corrections retained / source-scoped evidence and limits retained in archived record / committed-at-source-head |
| [C106](../../Batches/history/c-20261003-source/Batches/C106-20260930-1320Z-0620PST-regional-study-conditions-hydration-and-timing.md) | Six coherent timing stages, scoped diagnostics and bounded atomic retry. | implemented scope recorded; corrections retained / source-scoped evidence and limits retained in archived record / committed-at-source-head |
| [C109](../../Batches/history/c-20261003-source/Batches/C109-20261001-0459Z-2159PST-observer-capture-and-session-completion.md) | Lean cached versus explicitly inspected rich state retains source clock; truthful loaded-omitted/unavailable geometry budgets. | implemented scope recorded; corrections retained / source-scoped evidence and limits retained in archived record / committed-at-source-head |

Version replay credits the delivered scope of this contract once. Shared source membership does not create additional version rows. Current extensions and unmet D obligations retain their stated status.
