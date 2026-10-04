# C58 - Population reconstruction and scheduling

| Field | Record |
|---|---|
| Batch | `C58` |
| Date | 2026-09-20 |
| Name | Population reconstruction and scheduling |
| Status | Closed through the enforced full commit gate. |
| Threads | [`T-006`](THREADS.md#t-006), [`T-007`](THREADS.md#t-007), [`T-008`](THREADS.md#t-008) |

## Runtime ownership

The second DR-042 restructuring unit separates Population's responsibilities.
The scheduler owns county-tick cadence, fault isolation, daily orchestration,
historical slices, progress persistence, ground-survey scheduling and the boot
digest. Admissions owns map origins, genesis and subsequent admissions.
Representation owns the loaded body band and passive foreign adoption.
PhysicalFacts owns native physical observations and infection-window commit.
DormantPopulation owns movement, attrition, settlement, provisioning and meetings.

History remains the clock owner. The scheduler passes the current tick to each
admission and dormant entry point; historical substeps use that same interface.
Body remains the representation transaction owner. Existing Population entry
points delegate to their new owners, preserving caller signatures and save keys.
Moving physical observations does not change ZAO's pathogen authority.

F-089 repairs same-environment module reload: Population retains the registered
callback identity and removes it before replacement. OnInitGlobalModData resets
cadence, fault state, origin caches and encounter cursors, and restores a callback
previously detached by its fault gate. Ordinary engine world exit already creates
fresh Lua; the finding does not assert ordinary-world leakage.

## Verification

Existing source checks and executable harnesses now read/load the responsible
production modules. Mutation controls edit their actual owners. No border or
distinct control is removed. Border 170 adds ten controls for callback
replacement, cadence/fault reset, origin and encounter cache reset, callback
reattachment, and admission/dormant tick delivery. It executes the production
modules in Kahlua and checks each refusal's named reason.

Historical progress retains 90/365-day, partial-day reload, legacy progress,
missing timer, unfinished genesis, unreadable clock and real-record elapsed
health/death cases. Body handoff/checkpoint controls follow their representation
and physical-fact owners. The gate retains 173 test files and 13 other Python
entry points; 73 Lua sources now implement the existing responsibilities.

The [evidence record](../artifacts/audits/20260920-0341Z-2041PST-population-scheduling/README.md)
maps contracts, sources, persistent state, executed checks and open obligations.
Review and the enforced full commit gate validate the closing tree.

## Continuation

Perception and world access are next: R6 repairs the actual scanner and access
paths; R10a establishes grounded sources before dormant opportunity consumes
them. Dormant place offers and depletion, automatic settlement/provisioning
recognition and admission/refill policy retain their R6/R9/R10 obligations.
Extraction certifies no missing social or material producer. R7-R15 and the
eventual private unified assembly remain in the existing dependency order.
