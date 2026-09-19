| Document | Survivor Awareness Overhaul Dependency Substrate |
|---|---|
| Version | `2.7.14.1-pre-alpha` |
| Author | ellyj3rain |
| Repository | `SUBSTRATE.md` |
| Status | CANONICAL - what exists, what is planned, and what each area of concern needs. |

# Dependency substrate

This file maps the substrate the three repositories stand on, its actual
producers and consumers, and what remains incomplete. ROADMAP.md owns the
dependency order. The 2026-09-19 assessment separates the ratified design
from implementation evidence; a named module is not a completed mechanism.

## Ground rules

- Project Zomboid Build 42.20 is the engine ground truth.
- ZombieBuddy is the only hard runtime mod dependency.
- No other mod becomes a requirement unless the operator rules it.
- External mods are inputs or sources, never owners.
- The three repositories are one project with separate licences and gates.
- ZAO is an add-on and an integrated sister; it is not a requirement.
- Speakeasy ships no mod. Its datasets and models port into SAO.
- No live AI service runs at runtime.
- Load order never decides body ownership.

## Current runtime substrate

| Layer | What it makes possible | Without it |
|---|---|---|
| Project Zomboid 42.20 | bodies, world state, save data, Lua, Java, vehicles, timed actions, traits, professions, radio, print media | nothing runs |
| ZombieBuddy 2.3.0+ | loads `SAO.jar`; provides the Java instrumentation path | the Lua side degrades to a thinner mod |
| SAO Java component | engine bridge, movement, perception scans, combat, hibernation, body scale | many engine reads and body changes are absent |
| SAO Lua component | the county, four pillars, needs, places, standing, voice, UI | no survivor county |

No other mod is required. `CREDITS.md` records every source read, copied, or
ported, and whether it is required.

## Current non-runtime substrate

| Layer | What it holds |
|---|---|
| ZAO | the shipped sister mod for the turned - Lua controller, per-form behaviors, overlay, pathogen, forms and recovery, the Java bridge (`ZAO.jar`), and the ratified read-only claim surface (`ZAO.owns`, `ZAO.formOf`, `ZAO.performanceOf`, DR-024); optional add-on - reads SAO where present, runs whole where absent, and SAO does not depend on it at runtime |
| Speakeasy | dataset source, world documents, corpus, voice material, training plan; no models yet |
| SAO tools and borders | verification, county sweeps, dataset captures, deploy and build machinery |
| External mod catalogue | optional inputs, compatibility targets, art and mechanics sources |

## Planned substrate

| Layer | Planned role | Dependency shape |
|---|---|---|
| Recovery mods | antibody, cure, recovery, and repeat-infection inputs | optional inputs, never requirements |
| Speakeasy models | cognition, choice and expression conditioned on a person and their perceived situation | versioned models and data port into SAO; no code crosses |
| In-process inference | models run in SAO's Java jar | pure Java, self-contained, no service |
| Optional sidecar | larger local models for players who opt in | optional; never required for the base mod |
| Branching graph | one state-pressure-action graph across all concerns | SAO state surfaces plus Speakeasy decision models |

## What makes what possible

| Area of concern | Current substrate | Still needed |
|---|---|---|
| Isolation | person record, perception, standing, disposition, history, live isolation state | effect on world-development and social choices |
| Place attachment | identity, perception, places, standing, live place-attachment state | effect on world-development choices |
| World development | identity, place attachment, standing, live world-development state | project choice and development branch |
| Material provisioning | needs, places, claims, containers, bridge verbs | stock, share, hoard, trade, and conserve branches |
| Movement and exploration | controller, locomotion, population, perception | isolation-aware goal choice and route memory |
| Social affiliation | standing, exchange, perception, circle | affiliation branch and live isolation input |
| Governance and deference | standing, command, organization contract | office, jurisdiction, legitimacy, recognition, dissent |
| Communication | voice, knowledge, exchange, radio | understander, speaker, constrained decoding, free-form UI |
| Learning and teaching | lessons, census, knowledge | learning branch and dataset rows |
| Conflict and defense | controller, combat, standing, claims | threat branch and, for the turned, ZAO's ownership seam |
| Culture and memory | lessons, voice, gesture, knowledge | memory and ritual branches; Speakeasy world model |
| Health and self-care | needs, medical, course, conditions, habits | treatment and self-care branches; ZAO pathogen state where relevant |
| Player interaction | harness, UI, command, organization actions | free-form conversation and player perturbation of the graph |

## Cross-repository synchronization

| Seam | Current state | Rule |
|---|---|---|
| SAO to ZAO: the turn | defined and evidenced | SAO owns death; ZAO owns the risen body; one controller per body |
| SAO to ZAO: afflicted and crossed | adapters exist; returned-body adoption and dormant recovery fail the audit | SAO executes the afflicted; ZAO owns pathogen state and executes the crossed |
| SAO to Speakeasy: dataset | 190 ratified choices and approved world documents; decision capture needs repair; no trained models | SAO supplies people and moments; Speakeasy supplies rows and models |
| ZAO to Speakeasy: degraded cognition | cross-module rows and state producers exist; complete learned consumption remains absent | cognition reads event-derived pathogen state with provenance; the row contract does not establish a functioning model |

When a seam moves, the repository that owns it updates its record and the
sibling pointer moves in the same turn.

## External mod posture

| Posture | Meaning |
|---|---|
| Required | ZombieBuddy only |
| Recognized | another NPC mod's people are identified by property and never confused with ours |
| Input | a loaded mod's state enriches the county when present |
| Source | mechanics or art are read, credited, and rebuilt at SAO's own seams |
| Compatibility target | behavior is kept coherent without depending on the mod |

## Build order principle

Ground the substrate first, then build one area of concern at a time. Each
area must state:

1. which existing state surfaces it reads,
2. which planned substrate it needs,
3. which repository owns the behavior,
4. which repository owns the model or dataset,
5. what happens when an optional dependency is absent.

## Verified ownership and evidence

The installed Build 42.20 engine owns loaded physics, animation, pathfinding,
inventory and timed-action mechanics. NPC control variables supply inputs to
that machinery. They do not supply goals, permission, private knowledge or a
completed action receipt. ZombieBuddy loads the Java component; successful
loading establishes no decision behavior. ENGINE_CONTRACT.md records the
verified engine interfaces and remains explicitly incomplete.

The matrix below is an implementation assessment. Evidence A is the
[recent implementation audit](artifacts/audits/20260919-0356Z-2056PST-c112-c126-implementation-audit.md)
and its preserved source hashes and controlled probes. Evidence B is the
[engine serialization and release probe](artifacts/audits/20260919-0433Z-2133PST-c-substrate-evidence/README.md),
recorded in F-077. Source names refer to the current unchanged runtime tree;
former batch labels inside evidence retain their historical meaning.

| Contract | Producer and caller | Durable state | Observation or test | Remaining gap |
|---|---|---|---|---|
| One person across loaded and dormant life | Identity owns the record; Body.materialize creates a body; Controller.adopt attaches decisions; Population manages range transitions | Person registry and hibernation pack; body registry is transient | B executes Body.release in the installed VM, with successful, empty and throwing capture | Failed capture still removes the body; Population drops its controller first and ignores release failure. Capture and relinquishing ownership need one transaction. |
| Returned afflicted people resume living | AfflictedReturn reads ZAO's loaded controlled bodies and calls Body.materialize | Existing person identity and ZAO pathogen state | A reproduces a returned body with no controller; explicit adoption is the control | Materialization does not adopt; dormant recovery has no producer. State ownership and body ownership must be handled separately. |
| County time has consistent units | History derives county hours/ticks; Population advances historical substeps; Controller exposes time to consumers | Historical progress and per-person timestamps | A traces cached Controller.tick and WorldGenesis.applyDay passing a day as a tick | Every consumer must declare units and read the advancing simulation time. A frame callback cannot stand in for many historical substeps. |
| Saved state reconstructs usable runtime behavior | GraphPersistence binds Branching tables to ModData; Integration.ensure registers built-ins | Serializable IDs and pattern history survive; closures do not | B saves and reloads an actual Kahlua table, then initializes the shipped modules | Built-ins reconstruct. An extension must re-register its callbacks; runtime registries need explicit ownership separate from durable history. No normal built-in reload failure is demonstrated. |
| Facts are private and acquired | Java scans feed Perception; Knowledge preserves acquisition and Standing evaluates permission | Beliefs with source, time and uncertainty | A reproduces animals entering the IsoPlayer human path and traces global activity participant discovery | Narrow scanner output before decision use, preserve provenance and distinguish animal facts. Visibility and permission do not imply physical access. |
| Actions have owned completion and interruption | Controller selects and queues engine actions; Driving, Medical, Animals and inventory adapters execute | Records should change from observed consequences | A exercises moving-vehicle cancellation, cancelled surrender, refused CPR and remote egg collection | Approach, queue, completion, failure and cancellation must be connected. A request must not award goods, experience, trust changes or learned capability. |
| Loaded and dormant opportunities describe the same world | Loaded engine supplies actual containers, ground and bodies; Places and Population provide dormant representations | Place facts, resources, position and history | A traces stale vehicle locations, missing compartment access and diagnostic invented ground | Unloaded geometry is unavailable unless grounded data exists. Dormant processing needs its own accountable producers; test fixtures cannot be accepted as world observations. |
| Health integrates actual events over time | Course, Medical, Habits and Neuroinflammation consume person state; ZAO StateStore owns pathogen transitions | Person health/habits and pathogen record; optional body counters need review | A reproduces cadence-dependent brain state, healthy-child wound fear and frozen-use withdrawal drift | Reconcile live inputs, cumulative versus current poison, owner reads and elapsed-time partitions. The brain graph request is not fulfilled by a scalar bar. |
| Social outcomes follow performed acts and recognition | Standing, Organization, Settlement and Integration mutate social records; Branching.record currently counts selections | Claims, membership, offices, patterns and experience | A traces automatic relocation, selection recorded before execution and recognition by repetition | Affiliation, legitimacy, dissent and development need causal producers. A chosen branch is not performed work; repeated choices do not establish public recognition. |
| Diagnostic populations support valid claims | Population genesis/refill and mortality produce open-population histories; county sweep exports observations | People, deaths, seeds and run progress | C50's independent 90/365-day receipts distinguish 12-person targets from 27/72 created records | Reconcile admission/refill with the life-simulation contract. These samples cannot be reported as 100 percent cohort survival or full simulation fidelity. |
| Training sees the actual decision moment | county_dump.py joins person, situation, options and choice; Speakeasy owns ratified rows and models | Immutable captured rows and source provenance are required | A mutates person/belief state after capture and shows future information leaking into an earlier row | Deep snapshots, capture failure accounting, complete horizons and executable options are unfinished. Ratification of 190 choices does not validate their exporter. |
| Learned cognition reaches consequences | Branching/Integration expose pressure and selection; Java inference and fact constraints are primitives | Versioned models, evaluation sets and execution receipts are required | Source tracing finds branch/work outputs consumed by inspection without general execution dispatch | Complete producers and the training/export/runtime path. A model choosing an unavailable action or a graph reporting a choice is not the promised behavior. |

## First continuation contract

The next implementation unit addresses the loaded-body to durable-record
transition. Body.release and its callers must commit dormancy only
after capturing the current person successfully. Empty, malformed or throwing
capture must preserve the previous record and retain recoverable body and
controller ownership with a specific failure result. Successful capture must
preserve supported state through reconstruction and relinquish ownership once.
Population and the diagnostic Harness both drop control before release.
Harness.clear additionally removes identity, so intentional clearing needs
its own complete teardown path without leaving an orphaned body.
The acceptance test covers these caller sequences, failed capture, successful
capture and failed teardown in the installed VM; a callee-only check is
insufficient. B establishes the motivating failure, not its frequency in play.

Shared time, health ownership, perception, action consequences and all the
life-simulation producers remain subsequent work. This first repair protects
the person record; it does not certify the simulation as training ground.
