# C10 - County scheduling and loaded/dormant orchestration

| Field | Current definition |
|---|---|
| Catalogue generation | `20261003-shared-boundaries` |
| Attainment anchor | 2026-09-20; reconstructed from the last contributing source, with original event chronology preserved |
| Standing | Evidenced implemented scope with separately stated remaining work; publication and rendered acceptance follow component evidence |
| Version classification | kohai: Explicit cadence/admission/representation seams mature the existing county scheduler. |

## Shared contract

| Boundary | Definition |
|---|---|
| Canonical owners | [mod/42.20/media/lua/client/SAO_Population.lua](../../mod/42.20/media/lua/client/SAO_Population.lua); [mod/42.20/media/lua/client/SAO_DormantPopulation.lua](../../mod/42.20/media/lua/client/SAO_DormantPopulation.lua); [mod/42.20/media/lua/client/SAO_PopulationAdmissions.lua](../../mod/42.20/media/lua/client/SAO_PopulationAdmissions.lua); [mod/42.20/media/lua/client/SAO_PopulationRepresentation.lua](../../mod/42.20/media/lua/client/SAO_PopulationRepresentation.lua); [mod/42.20/media/lua/shared/SAO_PhysicalFacts.lua](../../mod/42.20/media/lua/shared/SAO_PhysicalFacts.lua) |
| Admitted inputs | History ticks, inhabitants, loaded band and physical facts |
| Produced outputs | Ordered pulses, admissions/representation calls, catch-up progress and explicit faults |
| Owned state | County positions/workplaces, encounters and restitution ledger |

## Boundary rationale

- Scheduler orchestrates independent admission, custody and material authorities; C58 makes these seams explicit.

## Delivered scope

- Source C7 (implemented bounded): Restitution repays prior takes outside hibernation radius, at most six/day.
- Source C18 (implemented partial): Pre-spawn/precollapse historical county activity.
- Source C26 (consumer): Historical progression uses shared timeline.
- Source C29 (observation): Dormant county continuity measured.
- Source C41 (implemented partial): Ordinary street activity/durable workplaces.
- Source C50 (repair): Catch-up progress/company admission corrected.
- Source C53 (consumer): History fallback only if unavailable; explicit day-zero/native callback pacing.
- Source C58 (completed scoped): Separates cadence/fault/order/history progress from admissions/representation/physical facts/dormant activity.

## Dependencies and D work

| Dependency | Required relationship |
|---|---|
| [C6: Authoritative county time and explicit units](C6-2026-09-19-time.md) | Advance actual historical intervals and refresh time per substep. |
| [C3: Durable person identity and admission](C3-2026-09-08-identity.md) | Admission and census own who exists. |
| [C24: One native body owner and representation](C24-2026-10-01-custody.md) | Representation requests body transitions through the sole owner. |

- D needs causal domain producers and measured scale, not only scheduled reads.

## Source contributions and measured status

Source C labels below belong to the preserved pre-migration generation. Each source can contribute to several contracts; its bytes and evidence are preserved once by the manifest.

| Source | Contribution | Implementation / verification / publication |
|---|---|---|
| [C7](../../Batches/history/c-20261003-source/Batches/C7-2026-08-29-zombie-census-and-bounded-restitution.md) | Restitution repays prior takes outside hibernation radius, at most six/day. | completed bounded / source-scoped evidence and limits retained in archived record / committed-at-source-head |
| [C18](../../Batches/history/c-20261003-source/Batches/C18-2026-09-07-historical-county-simulation.md) | Pre-spawn/precollapse historical county activity. | partial historical / source-scoped evidence and limits retained in archived record / committed-at-source-head |
| [C26](../../Batches/history/c-20261003-source/Batches/C26-2026-09-08-shared-county-time-and-day-zero.md) | Historical progression uses shared timeline. | completed scoped later corrections / source-scoped evidence and limits retained in archived record / committed-at-source-head |
| [C29](../../Batches/history/c-20261003-source/Batches/C29-2026-09-08-dormant-social-continuity-and-county-measurement.md) | Dormant county continuity measured. | partial historical / source-scoped evidence and limits retained in archived record / committed-at-source-head |
| [C41](../../Batches/history/c-20261003-source/Batches/C41-2026-09-13-county-tick-and-ordinary-activity.md) | Ordinary street activity/durable workplaces. | partial historical later clock repair / source-scoped evidence and limits retained in archived record / committed-at-source-head |
| [C50](../../Batches/history/c-20261003-source/Batches/C50-2026-09-18-historical-simulation-recovery-and-evidence.md) | Catch-up progress/company admission corrected. | mixed withdrawal and completed repairs / source-scoped evidence and limits retained in archived record / committed-at-source-head |
| [C53](../../Batches/history/c-20261003-source/Batches/C53-2026-09-19-shared-county-time.md) | History fallback only if unavailable; explicit day-zero/native callback pacing. | completed measured implementation / source-scoped evidence and limits retained in archived record / committed-at-source-head |
| [C58](../../Batches/history/c-20261003-source/Batches/C58-2026-09-20-population-reconstruction-and-scheduling.md) | Separates cadence/fault/order/history progress from admissions/representation/physical facts/dormant activity. | completed gate scoped refactor / source-scoped evidence and limits retained in archived record / committed-at-source-head |

Version replay credits the delivered scope of this contract once. Shared source membership does not create additional version rows. Current extensions and unmet D obligations retain their stated status.
