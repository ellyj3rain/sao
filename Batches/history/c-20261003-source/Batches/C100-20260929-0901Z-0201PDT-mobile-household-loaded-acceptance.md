# C100 - Mobile household loaded acceptance

| Field | Record |
|---|---|
| Batch | C100 |
| Date | 2026-09-29 |
| Timestamp | 2026-09-29 09:01 UTC / 02:01 PDT |
| Name | Mobile household loaded acceptance |
| Status | Source repair, retained current-engine receipt and verification complete. |
| Threads | T-002, T-004, T-006, T-008, T-030 |

Build 42.21 exposed two engine-shape assumptions in C99 before its loaded
acceptance could close. The loaded vehicle collection is a Java Set and must be
read through its iterator. Native vehicle material is exposed through
`getPartCount` and `getPartByIndex`, rather than an accessible parts wrapper.
The production mobile-household owner and its installed-Kahlua border now use
those exact surfaces.

A mobile resident also needs two positions at once. The exterior vehicle is the
durable spatial anchor used by memory, planning, dormant simulation and saving.
The represented body occupies Project RV's remote physical room. Entry now
retains the room, body point and provider identifiers; representation uses the
physical point for loading distance and reconstructs the provider binding after
body replacement. Snapshot capture preserves the exterior anchor instead of
persisting the remote room as a new world location. Deliberate daytime room use
is retained; the automatic morning exit applies only to an overnight-rest use.

The native study surface accepts an optional activated-map dependency and a
bounded mobile-household situation. The runner resolves the named map to one
copied provider, verifies its authored cells lie inside the world extent, and
seals the provider plus map metadata into the run. The situation creates the
real vehicle, uses the production entry and exit owners, verifies the loaded
room's floor and interior state, moves the exterior anchor, and returns the
resident beside it.

The engine Lua compiler border now divides its complete file set into bounded
Windows command lines and recombines every per-file, per-mode verdict. A forced
multi-batch control proves that splitting cannot omit a source or compile mode.

The retained Build 42.21 run completed with exit code zero and an empty runtime
error scan. It spawned `Base.RollingRefuge` at 3782,10943, loaded Project RV's
`3x6caravan` room at 22560,12300, moved the exterior anchor ten tiles, and
returned the resident at 3794,10943. The durable record contains two transitions
and one material revision. Six observations captured both people; unloaded
squares remain explicitly unavailable.

| Verification | Result |
|---|---|
| Border 212 | Passes native Set and indexed-part adapters, exterior-anchor propagation, body-replacement reconstruction, room use, rest, exit and persistence controls. |
| Border 213 | Retains the Build 42.21 package, definition, report, observation, stdout, native cohort, map dependency and completed transition receipt. |
| Native verifier | The sealed run re-verifies as completed with the same inputs, normal native save return and no runtime errors. |
| Source-integration lineage | Mobile-household continuity has no remaining known loaded-acceptance gap; external art and rooms retain their provider provenance. |

The situation, its behavioral quality and every captured observation remain
unreviewed. This batch supplies mechanical implementation evidence and does not
admit a scenario, observation or rule to the dataset.
