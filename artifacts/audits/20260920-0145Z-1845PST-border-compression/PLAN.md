# Whole mod restructuring plan

Timestamp: 2026-09-20 01:45 UTC / 18:45 PST

Source baseline: SAO `08f9d6d32977a731f0af06c2824cbe72e2024550` (C56).

Restructure SAO's runtime ownership and module layout together with its borders,
then work toward a single private unified mod/project. DR-041 sets the
destination; DR-042 selects whole-mod runtime restructuring. The source map
precedes implementation. The R6-R15 producer, action and ML obligations travel
with the responsibilities being moved.

## What the precedent supplies

A/B/C consolidation grouped adjacent work by content and preserved the original
records through a crosswalk. It reorganized history without certifying its
implementation. Border compression needs the same traceability plus a mapping
from every claim to the production path and the defect its control can detect.
Fewer files or labels alone do not establish stronger coverage.

## Current evidence

The 1,982-line gate invokes 188 distinct Python entry points: 175 test files
and 13 other scripts. Its labels extend through Border 175. `inventory.json`
lists every entry point, source hash, declared title and lexical production-file
reference. References identify review candidates; they do not establish coverage.
The old session-state counts of 170 borders and 189 mirrors were stale.

`runtime-inventory.json` accounts for all 68 Lua files and 32 Java files under
the shipped Lua and Java source roots. Every source has a hash, review contract,
lexical references, directly named engine-event registrations and the gate
scripts that name it. The ten review groups organize this inventory; they do
not prescribe ten packages. Runtime dispatch and behavioral coverage still
require tracing and execution. Shipping metadata, translations and jars are
separate assembly inputs.

| Contract | Evidence inspected | Proposed treatment |
|---|---|---|
| Person persistence | Borders 163 and 169 compile the same native snapshot implementation and PersonSnapshotProbe. Their 19 and 12 controls include one identical appearance-loss mutation and expected failure. | Share the baseline and harness; preserve distinct cases; combine a control only after proving the same defect is caught in the same context. |
| Dormant physiology | Border 174 uses the same native probe but mutates hibernation and consumption rather than the snapshot codec. | Share setup where compatible; retain quantity, spoilage, nutrition and partition controls. |
| Time | The calendar, tick-law, shared-time and historical-progress checks exercise different consumers of History. | Group by the shared-time contract while retaining calendar, substep, host-pacing and catch-up cases. Shared source references alone do not justify deleting a case. |
| Perception and classification | Border 155 checks isForeignPerson; the live scan accepts IsoPlayer and still emits a person observation when that helper returns false. The existing audit already assigns this defect to R6. | Replace helper-only confidence with a check of actual scan output; retain the classification cases and attach the demonstrated repair to R6. |
| Gate reliability | Entry-point discovery currently depends on explicit Python calls and one mirror loop. Some failed checks run a second time to expose output. | Use one authoritative inventory, preserve exit/skip semantics and negative controls, and retain failure output from the first execution. Measure any speed improvement. |
| Cross-module ownership | Current PROJECTS.md assigns living execution to SAO, pathogen and turned execution to ZAO, and model/data ownership to Speakeasy. | Carry those contracts into later private assembly, including one controller per body and in-process model consumption. |

The native-control duplication was compared directly. The scanner gap was
traced in current source and matches the earlier implementation audit. No full
gate or new engine probe was run for this planning pass. The inventory is
complete for the gate's Python entry points; the semantic review is a sample.

## Responsibility map

The four pillars remain the causal composition: Perception admits facts,
Disposition evaluates them, Standing supplies permission, and Execution carries
out the chosen action. The restructuring gives each responsibility a clear
implementation owner and makes the handoffs observable.

| Current source concentration | Intended responsibility boundary | Migration obligations |
|---|---|---|
| Controller: 7,242 lines including comments; decide begins at 815, updateAgent at 5298; death/save/tick callbacks share the file | Separate candidate selection, action progression and death consequence delivery. The controller owns scheduling and one active action per body. | Preserve priority, private knowledge, permission, cancellation and the existing death funnel. R7 supplies real completion receipts; moving code does not discharge that work. |
| Population: 3,671 lines; genesis, body-fact capture, loaded bands, daily life and historical stepping | Separate admissions, representation scheduling, physical observations and dormant advancement under the existing History clock. | R2/R4/R5 behavior survives unchanged through extraction. R10a grounds world sources before dormant actions claim new world effects; R10b resolves admission/refill policy against the emergence contract. |
| Body, AfflictedReturn, CrossedTransfer, native snapshot/hibernation/return code | Body remains the shared ownership transaction boundary; return and deliberate exposure remain distinct producers. Native codecs own physical continuation. | Preserve one owner, current possessions, exact-once transition receipts, pending retries, migration readers and save/load order. Keep ZAO's pathogen authority and one-way Crossed transfer. |
| Perception, Knowledge, Claims, Lessons, Places and native scanner/ground adapters | Keep world observation, private belief, social permission and physical access as separate interfaces. | R6 fixes the actual scan and access paths. Hidden or stale ground cannot become an offered action; executor revalidation cannot silently teach the planner unseen facts. |
| SAONeeds: 2,721 lines; SAOBridge: 3,142 lines | Keep one public bridge facade and move engine operations to domain adapters for inventory/resources, health/care and vehicles/actions. Reuse existing movement, combat and animal adapters. | Preserve compiled signatures, wire formats and vanilla action semantics. R7 receipts and R8 action repairs land with their owning adapter; engine claims remain grounded in installed code. |
| Standing: 3,712 lines; Command, Organization, Recognition and Settlement | Separate pair relationships, collective membership, permission/authority and recognition of performed acts, with one owner for each durable record. | Preserve person-key domains and saved records. R9 replaces unsupported affiliation or office outcomes with actual producers and participant responses. |
| Integration, Branching, Labor, Material, Adaptation and WorldGenesis | Separate read-only state views, candidate selection, execution requests and accepted consequences. Graph registration remains runtime state reconstructed after load. | Integration.apply currently calls selection, and selection records a pattern before action completion. R7/R9 must distinguish choice history from completed experience. R11 captures immutable decision moments independently of later results. |
| Harness: 2,991 lines; Inspect, UI, Exchange, Voice, Radio and Telemetry | Presentation reads owned state; command and communication entry points enter the same permission/action paths as other actors. Capture observes declared stages. | Preserve supported player interactions. R11/R12 retain capture provenance and approved data; R13/R14 add learned consumption only when executable options and model artifacts exist. |
| Bootstrap, runtime registries, optional adapters and configuration | Make load/event registration and world reset explicit. Keep compatibility adapters at their existing domain boundaries. | New module files must load in the installed Lua environment; stale closures, duplicated callbacks and second-world state are checked. Existing mod IDs, save keys and bridge namespaces remain compatible throughout migration. |

The line counts identify review concentrations and include comments. The
dependency inventory is lexical: references do not establish that a path runs.
Each migration begins by enumerating the actual callers and durable writes of
the specific responsibility being moved.

## Execution order

| Stage | Output and completion evidence |
|---|---|
| Establish the baseline | File/entry-point inventories are complete. Continue the semantic matrix per contract: invariant, producer, consumer, live/dormant path, persistence, executed case and defect control. Record blind spots and every former border's disposition. |
| Person continuity and verification | First implementation unit: trace Body/return/exposure transaction callers and durable writes; consolidate native snapshot harness setup and duplicated controls; organize source responsibility within the ownership boundary. Retain all distinct corruption, inventory, physiology, migration and failure-order cases. Borders 162-175 and relevant ZAO receipts constrain the work. |
| Runtime reconstruction and scheduling | Extract callback orchestration and population/physical-observation responsibilities. Preserve current time refresh, host pacing, partial history progress, pending corpses and world resets. Keep R10a's grounded-source investigation attached to dormant scheduling. |
| Perception and world access | Complete R6's actual scanner and access repairs, including the known animal bypass. Establish source-backed unloaded access through R10a before extending dormant opportunities. Check production observations and refused accesses. |
| Decisions and actions | Separate selection from action progression; implement R7 receipts and migrate R8 action families with their repairs. Interrupt each stage, repeat callbacks and reload pending work. Keep retained Crossed capabilities within the same action contracts. |
| Social and life producers | Reorganize Standing and graph responsibilities; implement the per-concern R9 mechanisms with their evidence. Choices, roster membership and repeated selections cannot award completed work, legitimacy or material success. Integrate R10b only against grounded producers. |
| Presentation and ML interfaces | Move UI, voice, exchange and capture onto the declared read/command/result interfaces. Carry R11/R12 through those migrations. R13-R15 retain their training, runtime and evaluation dependencies. |
| Close restructuring | Account for every source and prior border as retained, moved, combined, replaced or retired with evidence. Verify module loading, save migration, cross-module ownership and the full gate in repository-only and installed-engine environments. Compare controls, skips and measured execution cost; record loaded-world acceptance separately. |
| Prepare private assembly | Inventory SAO/ZAO loading and entry points, save identifiers and schemas, settings, native jars, Speakeasy artifacts and cross-module receipts. Specify one installable mod and private project from those facts. Resolve consequential source-layout choices before moving code. |

## First implementation acceptance

The first unit closes when the native-person suite has one authoritative case
inventory and compatible shared setup, every old case/control maps to its
successor, and the production ownership paths retain their distinct triggers
and one-body guarantees. Reuse compilation only when the source, probe,
classpath and compiler inputs match. Mutated controls retain isolated execution
so static engine state cannot contaminate the next case. Measure cold gate
cost before and after rather than promise a speedup from fewer files.

Source extraction and behavioral repair have separate evidence even when they
land in one coherent unit. Preserving an old defect is not acceptance; moving a
defect to a new module does not close its R item. Completion is measured against
the full original contract, with gaps carried explicitly until implemented.

## Current completion boundary

The scope decision, complete structural inventories, responsibility map and
migration order are recorded. Runtime restructuring and the per-contract
semantic audit have not yet been executed. The full gate was not rerun for
these planning changes. No new implementation batch or private assembly is
claimed complete.

## Evidence anchors

`BATCH_LOG.md:18`, `tools/check.sh`, `tools/gate_reach_test.py`,
`tools/person_snapshot_test.py`, `tools/person_continuity_test.py`,
`tools/dormant_physiology_test.py`, `tools/shared_time_test.py`,
`tools/tick_law_test.py`, `tools/one_clock_test.py`,
`tools/animal_ground_test.py`,
`java/src/com/sao/engine/SAOPerceptionScanner.java:161`, `PROJECTS.md`, and
`artifacts/audits/20260919-0356Z-2056PST-c112-c126-implementation-audit.md`.
