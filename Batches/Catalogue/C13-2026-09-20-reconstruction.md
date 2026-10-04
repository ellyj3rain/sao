# C13 - Durable data and runtime reconstruction

| Field | Current definition |
|---|---|
| Catalogue generation | `20261003-shared-boundaries` |
| Attainment anchor | 2026-09-20; reconstructed from the last contributing source, with original event chronology preserved |
| Standing | Evidenced implemented scope with separately stated remaining work; publication and rendered acceptance follow component evidence |
| Version classification | kohai: Plain durable data, runtime reset and narrow replay complete existing persistence lifecycles. |

## Shared contract

| Boundary | Definition |
|---|---|
| Canonical owners | [mod/42.20/media/lua/shared/SAO_GraphPersistence.lua](../../mod/42.20/media/lua/shared/SAO_GraphPersistence.lua); [mod/42.20/media/lua/shared/SAO_Branching.lua](../../mod/42.20/media/lua/shared/SAO_Branching.lua); [mod/42.20/media/lua/shared/SAO_Integration.lua](../../mod/42.20/media/lua/shared/SAO_Integration.lua); [mod/42.20/media/lua/client/SAO_Population.lua](../../mod/42.20/media/lua/client/SAO_Population.lua) |
| Admitted inputs | Plain durable data and load/save/world-reset events |
| Produced outputs | Rebuilt indexes/callbacks/controllers/memos and narrowly replayed journals |
| Owned state | Graph/person/world data and stable IDs; no persisted functions or Java handles |

## Boundary rationale

- C6/C29/C55/C58 meet at reconstruction; snapshot codec and return acknowledgement remain independent.

## Delivered scope

- Source C52 (implemented scoped partial): OnSave checkpoints and checksummed fragments retain durable source data; atomic transaction recovery was completed in source C55.
- Source C55 (completed scoped): Plain graph data; clean fresh/second-world indexes/callbacks/controllers/courses/Java maps.
- Source C58 (completed scoped): Reload callback replacement and fresh-state cadence/fault/origin/encounter reset.
- Source C64 (source-scoped implementation): Transactional graph rollback preserves pre-mutation state on refused durable writes.

## Dependencies and D work

| Dependency | Required relationship |
|---|---|
| [C3: Durable person identity and admission](C3-2026-09-08-identity.md) | Rebuild runtime indexes around stable durable keys. |

- Each D service declares durable state and fresh/second-world reset.

## Source contributions and measured status

Source C labels below belong to the preserved pre-migration generation. Each source can contribute to several contracts; its bytes and evidence are preserved once by the manifest.

| Source | Contribution | Implementation / verification / publication |
|---|---|---|
| [C6](../../Batches/history/c-20261003-source/Batches/C6-2026-08-29-person-state-across-reload.md) | Reload continuity retained gaps in optional counters and graph persistence. | partial historical / source-scoped evidence and limits retained in archived record / committed-at-source-head |
| [C13](../../Batches/history/c-20261003-source/Batches/C13-2026-09-06-conditions-habits-and-strain.md) | Later drug/brain persistence gaps remain. | partial historical / source-scoped evidence and limits retained in archived record / committed-at-source-head |
| [C29](../../Batches/history/c-20261003-source/Batches/C29-2026-09-08-dormant-social-continuity-and-county-measurement.md) | Social graph persistence required. | partial historical / source-scoped evidence and limits retained in archived record / committed-at-source-head |
| [C35](../../Batches/history/c-20261003-source/Batches/C35-2026-09-10-life-simulation-and-dependency-contracts.md) | One causal graph and dependency substrate. | ratified contracts not producer completion / source-scoped evidence and limits retained in archived record / committed-at-source-head |
| [C52](../../Batches/history/c-20261003-source/Batches/C52-2026-09-19-authorized-afflicted-return.md) | OnSave checkpoints and checksummed fragments retain durable source data; atomic transaction recovery was completed in source C55. | completed implementation loaded acceptance pending / source-scoped evidence and limits retained in archived record / committed-at-source-head |
| [C55](../../Batches/history/c-20261003-source/Batches/C55-2026-09-19-durable-runtime-reconstruction.md) | Plain graph data; clean fresh/second-world indexes/callbacks/controllers/courses/Java maps. | completed measured implementation / source-scoped evidence and limits retained in archived record / committed-at-source-head |
| [C58](../../Batches/history/c-20261003-source/Batches/C58-2026-09-20-population-reconstruction-and-scheduling.md) | Reload callback replacement and fresh-state cadence/fault/origin/encounter reset. | completed gate scoped refactor / source-scoped evidence and limits retained in archived record / committed-at-source-head |
| [C64](../../Batches/history/c-20261003-source/Batches/C64-2026-09-20-corrective-integrity-and-decision-evidence.md) | Transactional graph rollback preserves pre-mutation state on refused durable writes. | implemented scope recorded; corrections retained / source-scoped evidence and limits retained in archived record / committed-at-source-head |

Version replay credits the delivered scope of this contract once. Shared source membership does not create additional version rows. Current extensions and unmet D obligations retain their stated status.
