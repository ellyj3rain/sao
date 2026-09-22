| Document | Survivor Awareness Overhaul Dependency Substrate |
|---|---|
| Version | `2.8.11.0-pre-alpha` |
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
| Health and self-care | needs, medical, course, conditions, habits, C70's patient-bound open-wound result | disinfection, stitching, dormant treatment and the remaining self-care branches; ZAO pathogen state where relevant |
| Player interaction | harness, UI, command, organization actions | free-form conversation and player perturbation of the graph |

## Cross-repository synchronization

| Seam | Current state | Rule |
|---|---|---|
| SAO to ZAO: the turn | defined and evidenced | SAO owns death; ZAO owns the risen body; one controller per body |
| SAO to ZAO: afflicted and crossed | C52/A35 close returned-body adoption and dormant recovery; C56/A37 close intentional blood conversion and exact ownership transfer; the retained Crossed action vocabulary remains incomplete | SAO executes the afflicted; ZAO owns pathogen state and executes the crossed |
| SAO to Speakeasy: dataset | 190 choices and nine world documents are protected; C64 closes immutable capture-envelope and exact-join integrity; C65-C66 expose private consume/acquire/store options, runtime choice and immediate action result; Speakeasy supplies decision-time views and unratified proposals; broader options, curated acquisition, ratification, later consequences and trained models remain incomplete | SAO supplies people and moments; Speakeasy supplies protected source views, rows and models |
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

The operator supplied [PZ_Optimization](https://github.com/xD3I/PZ_Optimization)
during C65. The review at `ae971981f582b702ddcf82469f7aa8d26970cffd` records it
as a performance reference and optional compatibility candidate. It shadows
engine classes for Build 42.20.4 / `b0bbce05d5`, including WorldStreamer, IsoChunk
and the Kahlua compiler/table. SAO's native source hydration reaches those same
chunk owners. Its worker-pool path requires the streamer thread and an actively
referenced chunk; SAO's standalone `addJobInstant` acquisition remains synchronous.
Reported frame-rate and streaming gains therefore do not establish faster SAO
dormant simulation. Upstream has not tested both its optimizations and
ZombieBuddy's optimizations active together; this install also uses ZAO,
PeekAView and Staircast. The [reference assessment](artifacts/audits/20260921-0057Z-1757PST-source-action-decisions/performance-reference.md)
maps the relevant owners, evidence limits and bounded comparison to perform
when evaluating this optional integration. No external code was incorporated.

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
recorded in F-077. Source names in the original evidence refer to its recorded runtime tree;
former batch labels inside evidence retain their historical meaning.

| Contract | Producer and caller | Durable state | Observation or test | Remaining gap |
|---|---|---|---|---|
| One person across loaded and dormant life | Identity owns the record; Body.materialize creates a body; Controller.adopt attaches decisions; Population manages range transitions | Person registry and hibernation pack; body registry is transient | B executes Body.release in the installed VM, with successful, empty and throwing capture | C51 repairs the supported capture/teardown/restore transaction (Borders 162-163). C52 repairs authorized Afflicted return, exact-source transfer and controller adoption. Native components preserve inventory, equipment, Stats, BodyDamage and XP. Other character components remain R3 work. |
| Returned afflicted people resume living | AfflictedReturn reads ZAO's loaded controlled bodies and calls Body.materialize; ZAO's save-generation journal reconciles the old source across engine save surfaces | Existing person identity and ZAO pathogen state; generation markers bind the participating return slices | C52/A35 execute the authorized return; C55/A36 exercise every old/new native/global generation pairing; C56/A37 transfer a later Crossed conversion back to ZAO through the same person envelope | R1, R4 and R5's conversion ownership are closed. General action receipts, the retained Crossed action vocabulary and grounded dormant execution remain R7-R10 work. |
| County time has consistent units | History owns county hours, day/tick conversion and quantization; Population advances historical substeps; Controller refreshes decision time | Historical progress and per-person timestamps | C53 Border 168 executes current substep reads, reload, midnight, Day Zero/DayLength invariance, WorldGenesis conversion and separate host pacing; three mutations restore the named defects | R2 is closed. R3-R10 consume this axis; their domain scheduling and event integration remain their own work. |
| Saved state reconstructs usable runtime behavior | GraphPersistence binds only serializable Branching history; Integration registers built-ins and stable-ID extensions into a fresh runtime graph | Pattern/office history survives; callbacks, caches, indexes, controllers, courses and Java maps are reconstructed projections | C55 Border 170 serializes through Kahlua, creates a fresh environment and then a second world; ZAO Border 8 reconstructs settlement/controller/course state and clears prior-world maps | R4 is closed for the inventoried owners. Later features must declare durable/runtime ownership as they add state; loaded-world play acceptance remains separate. |
| Facts are private and acquired | Java scans feed Perception; Knowledge preserves acquisition and Standing evaluates permission | Beliefs with source, time and uncertainty | A reproduces animals entering the IsoPlayer human path and traces global activity participant discovery | Narrow scanner output before decision use, preserve provenance and distinguish animal facts. Visibility and permission do not imply physical access. |
| Actions have owned completion and interruption | Controller selects and queues engine actions; Driving, Medical, Animals and inventory adapters execute | Records should change from observed consequences | A exercises moving-vehicle cancellation, cancelled surrender, refused CPR and remote egg collection | Approach, queue, completion, failure and cancellation must be connected. A request must not award goods, experience, trust changes or learned capability. |
| Loaded and dormant opportunities describe the same world | `SAO_WorldSources` requests bounded native chunks, records exact revisions and reconciles loaded changes; `SAO_SourceUse` turns one actor's private revision into a two-leg approach, current permission proof, exact native transfer and carried native use; `SAO_Provisioning` consumes only completed results and later native change; `SAOPrivateInventory` gives current decisions exact recursive holder rows | Native UUIDs and item IDs; bounded observations/conflicts and a schema-6 action/ambient-change store; one live reservation per actor; bounded ordered completed receipts; durable partial `Material` source projection, replay decision, projection generation and single-source owner index; schema-4 Standing migration retires inferred totals; fresh actor-private loaded views and exact v4 dormant carriage; runtime-only engine bindings | C61 Border 178 proves native grounding. C62 Border 179 runs the executable lifecycle. C63-C64 Border 180 executes the projection contract and C71 extends it with complete-coverage refusal. C71 Border 184 proves recursive holder conservation, removal/replacement, transfer, reload and loaded/dormant agreement. | R6 is closed for the selected source path, R7's source-action slice is complete and R9's exact partial-source projection slice is closed. C66 adds exact native acquisition/storage and completion-only experience. C71 closes actor-private inventory observation; complete household stock, dormant world holders and other action/producer families remain open. |
| Health integrates actual events over time | Course, Medical, Habits and Neuro consume current person/body facts; ZAO StateStore owns pathogen transitions and ZAO Brain owns history when installed | Durable health cursors, infection windows and brain event history; standalone SAO uses the same schema | C56 Borders 171-175 execute callback offsets, current exposures, exact interval partitions, reload, graphs and behavioral consumers; Borders 163/174 execute native dormant consumption | R5 is closed. Later health-and-care actions still require R7/R9 completion receipts and grounded opportunities. |
| Social outcomes follow performed acts and recognition | Standing, Organization, Settlement and Integration mutate social records; Branching.record currently counts selections | Claims, membership, offices, patterns and experience | A traces automatic relocation, selection recorded before execution and recognition by repetition | Affiliation, legitimacy, dissent and development need causal producers. A chosen branch is not performed work; repeated choices do not establish public recognition. |
| Diagnostic populations support valid claims | Population genesis/refill and mortality produce open-population histories; county sweep exports observations | People, deaths, seeds and run progress | C50's independent 90/365-day receipts distinguish 12-person targets from 27/72 created records | Reconcile admission/refill with the life-simulation contract. These samples cannot be reported as 100 percent cohort survival or full simulation fidelity. |
| Training sees the actual decision moment | `county_dump.py` freezes the legacy election's person/situation envelope before the real election and records its result separately; Speakeasy v3 validates exact namespaced joins | Immutable captured rows, execution identity, horizons, failures, settings and source provenance; protected approved data and documents | C64 Border 181 mutates nested identity, belief and claim state, rejects reader/cycle/incomplete/publication faults and distinguishes repeated executions. Speakeasy's seven join controls and conditioning audit protect and classify the approved sources. | The legacy election exposes no executable options or model choice and observes no action-specific consequence. All current captures are conditioning-ineligible; R11 still owes those producers. |
| Learned cognition reaches consequences | Branching/Integration expose pressure and selection; Java inference and fact constraints are primitives | Versioned models, evaluation sets and execution receipts are required | Source tracing finds branch/work outputs consumed by inspection without general execution dispatch | Complete producers and the training/export/runtime path. A model choosing an unavailable action or a graph reporting a choice is not the promised behavior. |

## Person preservation and continuation

C51 implements the ownership contract: capture failure preserves the
prior record and body/controller ownership; failed teardown retains a durable
pending capture; restoration occurs before publication/adoption for every caller.
Explicit clearing removes identity after teardown. Incoming actions and retained
representations are distinguished from dormant people. Borders 162-163 exercise
the actual Lua ownership and native component codecs with source controls.

C54 completes R3 with the v4 native-person envelope. It adds nutrition, fitness,
learning and reading collections, descriptor perk boosts, appearance, growth
timers and declared durable character ModData. Per-item native fluid facts detect
silent mixture or definition loss. v1-v3 readers retain only the information
those formats stored and record migration provenance when awakened. Positive-
elapsed dormant metabolism and in-progress runtime actions remain separate work.

C72 adds fatigue, endurance and saved sleep traits to the bodyless continuation
read without changing the v4 envelope. BodySnapshot commits the measured starting
point; DormantPopulation owns elapsed rest, sleep and wake; Body applies the
completed interval after native awaken. Explicit new-person provenance and
native capture are admitted. Older unmeasured records remain unknown.

The remaining work is assigned to R1-R15 in ROADMAP.md. The contracts below
define its implementation and proof. A remaining technical unknown has a
bounded investigation and an output needed by its dependent work.

## Implementation contracts

These contracts were checked against the C51 source, the recent audit, sibling
records and the installed Build 42.20 engine. Engine jar SHA-256:
`80e405a4bfc42f6072e75b3735f458a6514143da011d3226007ded305a442f44`.
Native method availability is verified; behavioral persistence beyond C51's
tested components is planned work. The current readiness claim remains the
scope proven by the existing tests.

### R1: authorized return and one owner

The closed C52/A35 R1 implementation and proof boundary are recorded in
the [working record](artifacts/audits/20260919-0735Z-0035PST-r1-return-evidence/README.md).
The incompatibility below describes the published C51 baseline. R1 now includes
the observed-reanimation producer, death-sequence-bound authorization and living
capture, staged transfer, native held-source protection, and save checkpoints
for loaded living people. A supported native visual sidecar persists alongside
the component snapshot. This does not complete the broader R3 person contract.

The physical-recovery rule is now ratified and implemented by ZAO: native lethal
and fake Knox state is cleared, weighted body-part health is lifted only to
critical viability, and actual wounds, treatment, fractures, ordinary wound
infection, statistics and XP remain. ZAO's Afflicted state is the authoritative
systemic-dormant Knox record. New transfers refuse before source holding when
that operation is absent or fails. Ordinary/fake-dead pending-source ownership uses per-incarnation source
snapshots, population-save and virtualization exclusion, chunk detachment and
exact load reconciliation. Held reanimated sources retain their native registry
owner, with an equipment overlay at native registry load. Verified offscreen
ownership can finish as a durable living record without publishing a body.
Large durable snapshots use bounded string fragments; native item strings
beyond the engine's byte limit refuse capture before teardown (F-083).
Normal ordinary-zombie offscreen life stays a separate mechanism. C55/A36 close
the return seam's interrupted multi-file save contract with a narrow write-ahead
generation journal. It is forced and atomically replaced after Lua `OnSave` but
before native body persistence. Replay runs after global mod data loads and
before native reanimated bodies load. Generation markers let reconciliation
retain, replace, reconstruct or retire the exact source for all four old/new
native/global pairings; missing or corrupt current journals refuse recovery.

`SAO_AfflictedReturn.adopt` calls `Body.materialize(rec)` while `rec.dead` is
true and clears that flag only after success. C51's general dead-record refusal
therefore blocks this caller. The actual-Lua
[continuation probe](artifacts/audits/20260919-0627Z-2327PST-continuation-evidence/README.md)
reports no returned body. Removing the guard in its control permits a body but
still supplies no controller, reproducing the earlier audit's separate defect.

SAO owns the living-person transaction; ZAO.StateStore owns the recovery fact
and ZAO.Controller owns the old turned body. C52/A35 implement the durable
return phase with an authoritative event, staged position/state, ownership and
retry information. They quiesce the old controller and source before capturing
current possessions, retain the hold through teardown retry, validate the new
body under a pending owner and acknowledge old-source removal before publishing
and enrolling the living controller once. Failed phases retain a recoverable
owner; an acknowledged removal resumes forward rather than rerunning the death
funnel, while a pre-removal refusal releases the hold back to the old owner.
Prior death history stays historical.

Source cleanup is acknowledged rather than inferred from a protected call.
Current possessions come from the held source, so looted items cannot reappear
from an older hibernation pack. Eligible durable records join ZAO-owned pathogen
and recovery state for bodyless historical recovery; loaded controller
membership is not the eligibility rule. C55/A36 add generation-aware replay
before either reconstructed owner advances.

Proof covers ordinary-death refusal, loaded and bodyless recovery, both callback
orders, each failing phase, attempted source mutation after capture,
interruption/reload, repeat notifications, exactly one active controller,
conservation of actual possessions and every native/global save-generation
pairing. Optional ZAO absence preserves SAO's normal lifecycle.

C57 assigns native-envelope versioning, capture, validation and durable commit
to `SAO_BodySnapshot`. Body retains lifecycle and ownership transactions;
AfflictedReturn retains source removal and adoption. Pending Crossed transfers
validate their supplied payloads and required envelope fields before publishing
ownership. Historical envelopes may omit visual sidecars; current v4 appearance
is native. The shared native suite retains the original probe assertions and
all historical defect controls across Borders 163, 169 and 174.

C58 separates the population scheduler from `PopulationAdmissions`,
`PopulationRepresentation`, `PhysicalFacts` and `DormantPopulation`. The
scheduler passes its current tick into admissions and dormant work; each
historical substep uses the same handoff. PhysicalFacts supplies both loaded
observations and BodySnapshot commits. Existing record/store keys and public
Population functions retain their contracts. Border 170 executes callback
replacement and world reinitialization with ten defect controls.

Dormant advancement still includes abstract place offers/depletion and
settlement/provisioning recognition. Admissions still derives a target and
refills after losses. Their extraction provides explicit owners for R6/R9/R10;
it does not establish private, accessible and conserved native resources or
resolve R10b's admission-policy obligation.

### R2-R4: time, complete person state and reconstruction (closed C53-C55/A36)

C53 closes R2 with one conversion owner in `History`. County time is elapsed
simulation time: 24 hours/day, 9000 ticks/hour and 216000 ticks/day. DayLength
changes wall pacing only. `Controller.tick()` refreshes from `History.ticks()`
at every decision read, so multiple historical substeps within one host callback
observe their own durable `yearsTicks`. A missing History answer advances only
the per-callback fallback. `WorldGenesis.applyDay` converts its elapsed day to
the tick at that day's start before calling `Integration.apply`.

| Axis and unit | Producer and conversion boundary | Current state and consumers |
|---|---|---|
| County hours | `History.countyHours()`; historical `yearsTicks / 9000`, then start offset plus engine world age | Durable physical/social stamps use `*Hours`: death, release, arrival, habits, rest, material use and event/news times. Legacy hour names are `Absorb.knoxProfiles.lastSeenAt`, Standing's `chairDeclinedAt`, `lastHeardAt`, `lastAckAt`, and runtime `bittenSaidAt`/`taughtAt`. |
| Elapsed county day | `floor(countyHours / 24)` at the daily producer; calendar `recordDay()` remains a separate record position | SAO `last*Day`, `worldGraphDay`, historical progress and daily gates; ZAO `startedDay`, `lastAdvancedDay`, `returnEvent.day` and pathogen-history `day`. Runtime `demandedAt` and `yieldedAt` are day buckets. |
| County tick | `History.ticksFromHours`, `tickAtDayStart` and `ticks`; floor, never round | Durable `yearsTicks`, belief/branch `at`, `lastAt`, `lastScanAt`, `nextDormantMoveAt`; runtime controller deadlines, `next*At`, `stateSince`, `taskDeadline`, `mournHoldUntil`, perception and action stamps. `Population` uses `History.TICKS_PER_DAY`; ZAO's loaded controller reads the fresh SAO tick. |
| Host callback | Controller-local `hostTickCount`; never serialized and never passed as county time | Native death-fall grace (`atHostTick`) and operational tally flushing. The old pending-corpse `at` shape is accepted only as a transient compatibility fallback. |
| Wall milliseconds | engine `getTimestampMs()` | Controller cost (`lastTickMs`), Voice cooldown (`lastSpokeMs`), UI/Inspect rebuild and JSONL pacing, historical-slice budget and diagnostic run identifiers. These never gate county outcomes. |
| Native calendar or component clock | engine-owned value, retained only by the component that defines it | `Identity.createdAt` is a legacy string containing engine calendar milliseconds and is provenance only. Fitness/exercise timestamps remain an R3 native-component question. Movement, animation and timed actions keep their engine clocks. |
| Non-time legacy names | no conversion permitted | `Identity.updatedAt` is a position revision counter. Organization `createdAt`/`joinedAt` are unused zero placeholders with no accepted time semantics; R9's actual producer must replace them before any temporal consumer exists. |

Border 168 runs the shipped History, Controller callback and WorldGenesis code
in Kahlua. It covers substeps without a host callback, a module reload, midnight,
Day Zero on/off, nondefault DayLength, skipped county time and host-paced native
work. It also holds WorldGenesis behind the source-action actor owner. Border 160
retains partial-day catch-up/reload and production callback ordering. The controls
remove the decision refresh, pass day as tick, bypass source ownership and put
corpse grace back on county time; each fails for its named reason. ZAO requires
no R2 code change: its controller already obtains decision ticks through
`SAO.Controller.tick()`, and its pathogen/state readers already use county hours
or explicit elapsed days.

R3 and R4 close below. Their timestamp migrations identify the old
axis before conversion; an unidentifiable frame counter cannot become claimed
historical time. C56 consumes that contract for drug scheduling, physical
observations and physiology partition equivalence.

### R3: complete person persistence (closed C54)

`SAONativeSnapshot`, `SAOHibernation` and Body restore the following field
ownership. Border 169 executes the production codec against installed Build
42.20 and removes each continuation or refusal seam as a control.

| Person state | Native or record owner and implementation | Verified boundary |
|---|---|---|
| Nutrition | Native calories, protein, lipids, carbohydrates and float-rounded weight share a bounded section with engine-adapter reads for `updatedWeight`, calorie extrema and weight-direction flags. Finite weight is preflighted at 35 or above before `Nutrition.load` can call its damaging low-weight setter. | Nondefault state survives repeated wakes. Two restored bodies agree on the next native update; removing the hidden cadence restore or low-weight preflight flips the verdict. |
| Fitness | Native regularity, stiffness, affected parts and exercise timestamps load into a new `Fitness` component before its exercise definitions initialize. | Destination defaults cannot leak through the insert-only loader. `lastUpdate` starts at `-1`, establishes the current ten-minute bucket on the first update and advances on the next. The in-progress `currentExe` action is runtime work for R4 and is not represented as completed history. |
| Recipes, reading and learning modifiers | The v4 learning section preserves recipe IDs, known media lines, per-book page progress, completed-book IDs, literature counts, print media and `SurvivorDesc.getXPBoostMap`. Direct collection restoration follows profession defaults and invokes no learning callback. | Missing recipe IDs remain known strings. Missing required perk definitions refuse; repeated wakes and the next boosted XP grant agree. |
| Human appearance | Native `HumanVisual` state restores after exact worn references and before the final model reset. Stable outfit names and forced-model script references are checked against their registries. Hair and beard growth timers use a bounded engine-field adapter. Identity continues to own name, sex and age. | Skin, color, hair/beard models, body visuals, outfit and growth timing survive. An unreferenced forced model, removed outfit, unavailable script or changed native visual refuses the staged body. |
| Character metadata | The v4 metadata section uses Kahlua's native codec after recursively rejecting unsupported required values, cycles, excessive depth and oversized strings. SAO/ZAO ownership keys are excluded and reapplied from the destination runtime. | Nested optional state including `NnCMethadoneEffect` survives without aliasing. `SAOPersonId` and return/pathogen marks remain reconstructed runtime state rather than copied history. |
| Fluid contents | The manifest records each carried item's native `FluidContainer` bytes in addition to item identity/type/parent. Restore reserializes every root and nested fluid component and compares its exact ownership and content. | Mixture and amount survive. Removing a fluid definition makes the staged restore refuse instead of accepting a silently altered carried item. |

The v4 writer retains v1-v3 readers. Older records initialize absent component
state from the fresh engine body and record `hibernationMigration.from` and the
county hour of that wake. No absent historical field is described as recovered.
Invalid required sections preserve the durable snapshot and C51's cleanup/retry
contract. v4 owns ordinary appearance; the older visual sidecar remains only for
older records and transient return-source comparison.

### R4: durable/runtime reconstruction (closed C55/A36)

| Owner | Durable authority | Runtime projection and reconstruction | Evidence |
|---|---|---|---|
| Branching and Integration | Serializable patterns, offices and stable extension IDs | A fresh callback graph installs sorted built-ins and re-registers extensions; no function-bearing registry enters ModData; a 128-entry ceiling bounds Kahlua's caller-ordered sort | Border 170 serializes the real Kahlua table, reloads it in a fresh environment, repeats initialization and rejects callback persistence, duplication or an unbounded extension registry. |
| History, Identity, Places and Rand | Their ModData stores and durable stream positions | Store memos, name/place indexes and stream-object caches clear and bind to the new world's tables | Border 170 changes worlds in one process and proves no prior-world table remains reachable. |
| Bodies and pending work | Person snapshots, pending captures and reports | Java maps, controllers, needs and return-body registries reset; pending corpses materialize at `OnSave`; in-progress exercise is cancelled while durable regularity/timestamps survive | Borders 169-170 cover repeated restoration, cancellation without credit, save-time corpse success/failure and two-world teardown. |
| ZAO state | Pathogen, recovery, settlement and source records | Settlements, controllers and courses reconstruct; Java controller/course/return maps reset before the next world advances | ZAO Border 8 loads the durable tables into fresh runtime owners and rejects retained prior-world state. |
| Cross-repository return | SAO record slice, ZAO pathogen/recovery slice and the exact return-source receipt or tombstone | A forced atomic generation journal precedes native save; replay precedes native source load and reconciles mixed generations by person, event, incarnation and token | ZAO Border 8 verifies engine order, all four old/new pairings, absent/reanimated sources, retirement, cancellation, repeated saves and corrupt/missing current-journal refusal. |

The journal is deliberately limited to identities that entered the Afflicted
return protocol; it is not a second general save system. Existing unmarked saves
remain readable. The first later save writes current generation markers and v2
source receipts. Mechanical probes establish ordering and reconstruction, while
loaded-world observation remains a separate acceptance step.

### R5: health, exposure and dormant consumption (closed C56/A37)

Drug daily work now closes from its durable `drugDay` cursor only when the
ten-minute pass runs. Skipped callback intervals replay, maintenance treatment
freezes abstinence at an exact county hour, and expiry resumes from the same
elapsed clean time. Loaded bodies publish current wound, Knox and toxic-burden
facts; cumulative poison history is not reused as current exposure.

ZAO owns pathogen terminal/form state and the durable brain-health history when
installed. Standalone SAO uses the same versioned schema on the person. Each
observation first integrates the facts active since the durable cursor, then
records the facts beginning at that boundary. Infection uses an exact sine
convolution over its fixed course window; wounds, toxin and withdrawal use
closed-form constant forcing with physical-clearance modifiers. Equal event
histories agree within the declared tolerance across one interval, hourly
partitions and reload. Inspection and medical views render the recorded series
and causal labels. Memory retention, decision cadence, existing pressure and
motor pace consume the same state. The off switch advances the cursor without
accruing burden and retains history.

The once-per-day three-tile calls to `ZAO.Pathogen.expose` are gone. A reachable
Crossed decision starts a durable approach/contact action against an Afflicted
person and clears ordinary attack targeting throughout it. Loss of range,
target, ownership or an available body interrupts. Only a matching action in
the resolving phase authorizes the exact-once result; the existing Crossed odds
times Afflicted susceptibility remains the probability. Proximity and forged
receipts cannot roll, and no spontaneous Afflicted conversion exists.

On success, the same human shell and supported person snapshot move from SAO's
controller to ZAO. Busy actions quiesce new SAO decisions and retry; save-time
checkpointing lets ZAO claim the dormant envelope after reload. External death
returns the corpse through SAO's existing death, witness and mourning funnel.
This closes the R5 exposure and ownership result. R7-R9 still own general
intent-through-result, retained weapons/tools/strategy and the complete Crossed
life/action producers.

Positive-elapsed awakening now searches nested carried containers, refreshes
food age, rejects spoiled, poisonous and dangerous uncooked food, and invokes
native partial `Eat` and `DrinkFluid`. Nutrition, fluid composition, quantity
and remaining demand agree across partitioned wakes and reload. The supported
equivalence covers the person and carried resources represented by the dormant
snapshot. C61 observes unloaded native ground; actor-specific access, transfer
and carried native use remain R6/R7 work.

### R6-R8: evidence, access and performed actions

C60 closes this contract for the audited loaded paths. The scanner classifies
animals before person output; installed prone state and target deactivation are
read at their consumers. Cashier and play partners require fresh firsthand
belief plus current floor, facing, range and occlusion. Every cached material
reader requires current floor/reach; vehicles also require loaded membership,
current position and `canAccessContainer`. A vanilla-derived transfer action
retains those checks through execution. Borders 154, 155, 157, 176 and 177 hold
the defects and their independent controls.

C61 closes the native-ground portion of R10a. When dormant search reaches a
building, its bounded chunks pass through the engine streamer and native loot
generator. Persistent UUIDs identify static objects and ground items; physical
fingerprints make replacements and movement conflict. Java returns exact
containers, fluids, items, quantities and revisions. Lua accepts only a complete
bounded protocol, persists the arriving person's private observation, protects
active reservations during compaction and retries loaded reconciliation. Places
and distribution names now answer only where a person might search.

Access and performed use remain separate, and C62 supplies the bridge rather
than collapsing them. Static and vehicle observations remain non-executable
global facts. One live actor can reserve only a source revision present in that
actor's private place belief. Locomotion first reaches the place and then an
engine-selected same-floor interaction square. Final binding re-resolves the
source fingerprint, revision and exact item, checks obstruction, current claim
permission and current vehicle-part permission, and holds only runtime engine
references. The vanilla transfer/grab moves the exact item; vanilla `Eat` or
`DrinkFluid` uses that exact carried item.

The durable reservation owns approach, transfer, use and reconciliation across
reload. An unspent cancellation releases it. A native partial stop publishes an
interrupted result without food/water credit. A proved completion publishes once
with pre/post source revision and actual quantity, then stamps only the actor's
`lastFoodDay` or `lastWaterDay`. Ground-item disappearance is expected only for
that completing reservation; unrelated replacement, movement or revision change
still conflicts. No C62 path calls settlement recognition or manufactures stock.
R9 provisioning may consume only the completed result and reconciled inventory.

C63 supplies that narrow consumer; C64 corrects its coverage claim. The final
action bind captures a group only when the current exact source lies within its
held claim; the receipt also captures that claim incarnation and the Material
setting at the event. `sourceProjection` copies the latest source without
aliasing WorldSources. Material replaces the one row by source identity, marks
the store partial, bounds retained rows at 256 and rebuilds totals only for
those observed rows. A conflict, a missing non-ground observation or any failed
downstream step remains unacknowledged. A completed ground-item removal and a
source now observed outside the receipt place remove only that source's row.
Personal use is acknowledged without house credit. A changed or re-formed claim
cannot inherit an old result.

WorldSources schema 5 retains a bounded coalescing queue when later loaded
observation changes that owned source. Provisioning drains the queue after
reload; Material refreshes or retires the exact existing owner and never creates
ownership, action credit or a new store from ambient observation. The original
result attribution remains intact. Source-observation time orders refreshes
against later material evidence, and projection generations distinguish stale
replay from a later mutation.

A partial store never derives larder/water claims or settlement storage. Graph
schema 3 marks C63 native stores partial and clears storage previously inferred
from them. Standing schema 3 removes C63's partial completed-source claims;
C71's schema 4 then retires larder/water claims inferred from bounded
quartermaster scans. Only a completed Material reconciliation with explicit
complete coverage may write those claims.
The applied exact-source outcome persists across reload and is resumed before a
later source conflict can reinterpret it; acknowledgement remains terminal and
post-acknowledgement cleanup recovers on the next pass if interrupted. The
event-time Material setting is not sampled again during delivery. Standing
setters, dormant need-day projection and queue acceptance create no provisioning
credit. This closes one completed-use-to-partial-source seam. C71 separately
closes actor-private inventory observation, while complete household stock and
performed shelving, acquisition, carrying, sharing, trade, conservation or
place development still require their own producers.

R7 gives each action an owner across proposal, approach, queued action, execution,
refusal, cancellation and observed result. C62 instantiates that contract for
source use with durable phases and a revision-bound receipt; the other families
must inventory their engine callbacks, bridge verdicts and teardown/reload
behavior before adopting the same shape. A receipt identifies person,
action/target, relevant time and result; repeat delivery is harmless. Separate
attempted effort from completed accomplishment.
Physical effects remain with their actual engine/domain owner; durable experience,
material projections and relationships follow the corresponding observed result.

| Action family | Concrete repair and retained substrate | Completion counterexamples |
|---|---|---|
| Driving | Retain vehicle/key adapters and C115's option wiring. Repair new-route cancellation, position-based progress, passenger wait phase and rearward steering. Stamp driving competence after actual performance. | Moving journey beyond 600 updates completes; blocked journey fails; failed approach earns no drive verb; passengers board or take an independent valid route; cancellation parks safely. |
| Ordinary activity and children | Execute the loaded `in` choice as homeward movement; align its dormant counterpart. Fix zero-wound truthiness and refresh healed state. Cover comfort, play, literacy, learning, age capacity and child driving limits. | Need interruption is respected; healthy/healed children do not retain wound fear; unseen/upstairs peers cannot become activity partners. |
| Care and optional events | Coordinate treatment and CPR readiness/sequence. Establish intended physiological effects and observe completion separately from gestures. Revalidate Week One/nuke event ownership, settings and calendar. | Busy/refused CPR grants no care result; cancelled aid grants no completed-help credit; nuke off/on, persisted draw and post-strike consequences are individually exercised. |
| Robbery and raids | Connect delivered demand, victim decision, completed transfer and aggressor reconsideration. Preserve witnesses and expiry. Gate breach pressure on the actual relationship/claim evidence. | Walking away cannot cancel a transfer already credited as yielding; interrupted surrender grants nothing; successful yield changes the next aggressor decision; a neutral claim alone does not justify forcing; haul equals goods acquired. |
| Animal care | Approach the selected hutch, trough or animal; revalidate reach, tools and availability; let the native action produce its result. | Distant/moved targets, empty yields and cancellation are respected. Horse and predator absence are supported. Ownership/companionship behavior requires its own evidenced semantics. |
| Provisioning | C63-C64 remove queue-time shelving credit and consume C62 completed-use receipts through exact partial-source replacement plus later native refresh/retirement. Give `depositSpareFood` and the remaining acquisition/carry/store/share/hoard/trade paths their own observed completion results. | Interrupted hauling creates no stock or completed-work recognition; one source cannot stand for a house; source replacement is idempotent; failed reconciliation stays pending; observed inventory and projected material remain reconcilable. |

### R9-R10: the full life simulation and its world

`Integration.apply` and `Branching.select` currently record selections, while the
controller mainly projects graph output into diagnostic pressure. Connect each
available candidate to an execution owner and its result. `recognize(count>=3)`
and `formOffice` are presently uncalled primitives; invoking them would not
supply the missing social evidence. C63 removes settlement creation and invented
rooms, water and food from `Recognition.onProvisioned`; an independent
place/development producer still has to ground the settlement. Election
projection still asserts every other member's recognition. Replace that and
the remaining invented facts with actual ground and each participant's
expressed/observed response.

F-084 also withdraws A32's completed-Crossed-execution claim. The Crossed are
not a special zombie target policy. The canonical subject is human-looking and
retains cognition, drives, learned competence and the ability to use the human
action vocabulary, while ZAO remains its one execution owner. The repair begins
from the following contract rather than by making the dormant pass callable in
isolation:

| Crossed substrate | Current implementation | Required producer and proof owner |
|---|---|---|
| Representation and ownership | A reanimated `IsoZombie`; Crossed state sets form `none`. No transition replaces a living Afflicted body. | ZAO chooses and owns a representation capable of the canonical appearance and actions. R1/R4's one-owner transaction pattern transfers SAO Afflicted to ZAO Crossed once and survives reload. |
| Cognition and goals | `ZAO_Mind` reads four pillars, but `Crossed.decide` is unreachable because the controller requires a non-`none` form. Its target policy reduces living people to nearest distance with an Afflicted bias. | R9 derives goals from retained person state, current pressures, relationships, group life and perceived opportunities. Outcomes remain variable rather than a universal hunt. |
| Retained human actions | Only `drive` is stamped as a retained verb. A special `IsoZombie` driver exists; weapons, tools, communication, leisure and most person actions do not. | R7-R9 enumerate the shared action contracts, map retained experience to available verbs, strip only the ruled human restraints, and obtain world-result receipts. No competence appears at the turn. |
| Dead, living and Afflicted interaction | Noise can attract dead; the generic fallback assigns a human target to an `IsoZombie`. Afflicted proximity rolls exposure daily. | ZAO goal/action producers distinguish strategy, diversion, combat, capture, use of the dead and the specific Afflicted interaction. Afflicted are not food. Exposure is an intentional completed result, not generic zombie contact. |
| Loaded and dormant continuity | Pathogen state persists; actions, goals and ownership transfer do not have equivalent loaded/dormant producers. | R4/R10 preserve pending actions and group/body ownership, ground dormant opportunities in available world facts, and reconcile later loaded consequences without replay or duplication. |

The representation is a design constraint, not a preselected class. Reusing a
human action mechanism does not transfer SAO's planner or ownership to ZAO; it
supplies an executor beneath ZAO's Crossed mind and goals.

Every row below needs loaded and dormant opportunities, execution, persistence
and consequence evidence. Existing modules are implementation starting points.
Before implementing each concern, produce its own mechanism inventory: current
producer/consumer classified as supported, defective or missing; trigger/pressure;
private opportunity; actor decision; executor; durable result; failure/reload
behavior; and a discriminating completion test. This is a bounded investigation
for childcare, art, ceremony, burial, overlapping/local/federated authority,
retained turned behaviors and animal ownership/companionship, whose complete
mechanisms are not established by the existing adapters. Name any needed
substantive ruling at that boundary instead of filling it with an invented rule.

| Concern and owners | Producer work and completion evidence |
|---|---|
| Provisioning — Needs, Material, engine inventory | Ground acquisition, carrying, storing, sharing, hoarding, trade, consumption and conservation in accessible resources. Preserve quantity and ownership through interruption, decay and loss. Honor the consumable-creation boundary in GOVERNANCE. |
| Place and development — Places, PlaceAttachment, WorldDevelopment, Settlement | Ground use, maintenance, repair, sanitation, construction and fortification in actual capability, materials, space and performed work where authorized. Multiple places, moving, abandonment and later loaded consequences must follow that history. No provisioning signal creates rooms, water or food. |
| Movement and exploration — Controller, Locomotion, Population, Perception | Generate destinations from needs, memory, curiosity, isolation and attachment; perform journeys and acquire route/place evidence. Unknown or unreachable ground stays unknown/unreachable; arrival changes occupancy only when it happens. |
| Affiliation and relationships — Standing, Exchange, Disposition | Derive recruitment, membership, rejection, exit, bonds, obligations, grief and trauma from private experience and communication. Replace daily afflicted relocation with motive, choice and completed travel. Solitude, rejected invitations and durable disagreement are valid outcomes. |
| Governance — Standing, Recognition, Organization, Command | Produce claims, responses, jurisdiction, legitimacy/coercion, office succession/vacancy, overlapping authority, coordination and dissent through acts and participant responses. Repetition and a roster do not imply assent, office or institutional success. |
| Learning and memory — Lessons, Knowledge, native reading/XP | Reading, practice, instruction and testimony have actual sources, participation and results. Preserve acquisition time, retention/decay, skills and reading state. Unseen acts never become shared knowledge automatically. |
| Culture, hobbies, childhood and rest — History, Lessons, Gesture, ordinary actions | Connect play, enjoyment, art, ceremony, care of children, burial/remembrance and rest to opportunities, performed acts and meaningful effects. A low-pressure day can remain leisure or solitude; occupations and jobs do not exhaust life. |
| Health and care — Course, Medical, Habits; ZAO pathogen owner | Offer feasible self-care and help, honor consent/standing where relevant and feed actual treatment and exposure into R5. Refusal, unmet need and ineffective treatment remain possible. |
| Communication and player participation — Knowledge, Communication, Voice, Command | Deliver person-scoped testimony, requests, promises and orders through real channels, with comprehension, provenance, refusal and durable consequences. Player interaction changes the same state as other interaction. |
| Conflict and defense — Perception, Standing, Controller, combat | Derive threat response, withdrawal, defense, diversion, capture and contested acquisition from perceived threats and permissions. Low skill affects execution within the human envelope; it does not grant hidden knowledge or impossible acts. |
| Turned and afflicted life — ZAO mind/pathogen/controllers; SAO living execution | Preserve the separation of retained cognition from pathogen mechanics. Strategy, kin coordination, diet, capture/diversion, rare social development and living responses consume retained capabilities and actual events. No verb is acquired merely by turning. |

C61 supplies R10a's grounded unloaded opportunity, persistent source identity,
exact private observations and loaded reconciliation. C62 supplies the selected
actor-specific access, exact transfer, native consequence and durable result;
C63-C64 consume that result into bounded partial-source material and reconcile
later native change. C66 extends the same actor-owned lifecycle to performed
food/water acquisition and storage, with conserved holders, current authority,
reconstruction and completion-only experience. C71 supplies the recursive
actor-private decision inventory without creating a household total. R7/R9 next
supply the remaining action families and other provisioning and development
producers. R10b then validates integrated historical behavior
after those relevant producers exist.
A fixture such as universal rooms/food/water is not a source. Preserve
day-zero-off and the same causal machinery through ordinary life, collapse and
late starts.

Population accounting distinguishes initial people, admissions, births, exits
and deaths. Reconcile the ratified delayed-refill path with the prohibition on
balancing generated populations toward a desired outcome before changing policy.
Keep any real conflicting ruling explicit. Diagnostic targets, refill cohorts
and natural survival have different denominators and must remain distinguishable
in captures and evaluation.

### R11-R15: data, learned decisions, expression and acceleration

C64 repairs the evidence envelope. SAO `tools/county_dump.py` freezes nested
records, beliefs and claims before the real election, captures the election
result separately, labels required-reader failures, records exact requested/
reached horizons, engine mode, county/run/event identity, random state, settings,
source/code/model provenance and schema/clock versions, and refuses fabricated
ground, callback faults and incomplete runs. Every requested county validates
before one staged directory becomes visible by atomic rename. Border 181 proves
nested immutability, labeled refusal, lossless control characters, unique
execution identity and atomic-publication failure. The legacy election exposes
no executable options or model choice and observes no action-specific later
consequence; the capture states those omissions and remains conditioning-
ineligible.

C65 supplies a real option producer for C62's food/water source action. The
Controller retains place/category admission under current need, ration and
standing. WorldSources enumerates the actor's private source revisions into a
stable bounded offer; SourceUse selects explicitly and reservation revalidates
that exact descriptor. A changed source, actor, item or permission refuses
without retargeting. Physical access remains an arrival-time check. The observer
freezes the person, private situation, policy context and options before choice;
captures the runtime choice separately; and joins to that reservation's detached
result. Requested quantities do not become observed consumption. Pending work,
refusal, interruption and evicted results are explicit; unreadable result storage
rejects capture. The source executor is absent from the current county sweep,
which reports unavailable coverage. R11 next extends real option producers across
the remaining actions and supplies separately authored/ratified choices and
later consequence horizons. C66 extends capture to acquire/store. Speakeasy
now constructs decision-time knowledge views and unratified proposals. C74 adds
one exact calendar, county-presence, adult lived-acquisition and retention
producer plus a deterministic same-person decision bundle. Protected extraction
review, acquisition adjudication and ratification remain R12 obligations.

Speakeasy version 3 namespaces joins by originating run, county, person, event
and hour, prevalidates both inputs, refuses protected inputs/destinations and
publishes only by atomic replacement. An admitted option names a real action
owner, parameters and eligibility evidence, and execution must still revalidate
it because the world may change after inference.

The protected manifest binds all 190 ratified choices, four historical
derivatives and nine approved world documents by hash. The audit finds future
death in 184 rows, future lessons in 182 and future beliefs in 163; all 190
option fields are bare strings. The approved choice and its conditioning
evidence therefore have distinct standing. Preserve the original and its
ruling. A versioned derived view identifies reconstructed, censored or unusable
context rather than silently rewriting approved intent. If changed context
changes the choice's meaning, obtain the required ruling at that point. The
unmerged former C126 branch has eight aggregate diagnostics across different
seeds and horizons, without person decisions or full provenance. It remains
diagnostic history, not a training corpus.

Compile approved knowledge with stable claim IDs, source/page/hash, confidence,
knowable date, carrier and acquisition rules. Separate language texture from
claims a person can know. LOW-confidence material cannot teach; October context
cannot become July knowledge. Apply age-at-event, occupation, region, literacy,
hearing and testimony constraints from Speakeasy's world plan. Speakeasy v3
corrects the mutable README/training status against its append-only RECORD;
C66/Speakeasy supplies versioned reconstruction tooling. The C74 bundle supplies
one bounded personal acquisition without protected prose.
Extraction review, acquisition adjudication, explicit ratification and approved
eligible views remain R12 work.

Build versioned corpus extraction with pinned dependencies and source hashes,
deterministic voice-seed expansion, understander utterance-to-meaning examples,
and speaker claim/conditioning-to-expression examples. Preserve each source's
actual approval status. Test reproducible extraction, expansion-family split
isolation and same-person ordinary/work/threat register pairs. These language
deliverables can proceed alongside mechanical repairs.

Build decision-authoring proposals and ratification tooling over frozen captures
with generator/prompt/version provenance. Cover all R9 concerns, ordinary rest and
degraded cognition. Split by originating person, county trajectory and source/
seed family, including derived copies. Report legal-action validity, hidden/future
information leakage, person-sensitive behavior, grounded expression and uncertainty
separately. Survival, unity and institutional prevalence remain observations.

Speakeasy currently has no implemented training/export pipeline; SAO's arithmetic
budget probe and `SAOFence` are primitives. The architecture investigation must
produce task definitions, candidate implementations, conditioning/tokenization,
memory/parameter costs, objectives and a versioned export contract before model
selection is treated as settled. Build a candidate inference/export harness in
this investigation to measure actual-model reference/Java parity, allocations
and latency before production integration; dimensions remain provisional until
the target budget is verified. The contract includes tensor/vocabulary/action
schemas, numerical conventions, checksums, provenance and compatibility. A fixed
checkpoint must export deterministically; Java/reference inference must agree
within a declared tolerance; damaged/incompatible models must refuse loading.

Connect the loaded model to actual Controller and dormant decision points,
revalidate availability, dispatch the selected option and record the result.
Define stale-option and inference-failure handling before integration. Prove that
a controlled change to model output changes the performed action and receipt,
not merely an inspector field. Measure actual-model allocations and latency;
idle-desktop arithmetic does not establish a loaded-game budget. No play request
or session polling is introduced as a new prerequisite.

The speech design retains both understanding and constrained expression. Keep
claim/entity relationships intact through decoding: independent field allowlists
can otherwise recombine a true name with a different person's true location.
Connect understood testimony/orders to Perception, Standing and Command, and
speaker output to the same exchange, including register, refusal and source.
Adversarial logits must not escape factual constraints; delivery changes durable
state once. Shared representations between cognition and speech are an
investigation, not an existing design ruling.

Finally compare any learned late-start accelerator against a repaired causal
baseline with matching initial conditions, seeds and model versions. Examine
event histories, joint state distributions, later decisions and resource/identity
invariants as well as compute cost. Reject direct assignment of survival,
settlements or completed work. Until evidence supports an accelerator, causal
stepping remains the implementation.

## Audit coverage in the execution plan

| Current catalog / former labels | Accounted work |
|---|---|
| C41 / C112-C113 | R2 clocks; R8 ordinary activities; R10 historical equivalence |
| C42 / C114-C115 | R7-R8 driving, passengers and real competence; retain tested option wiring |
| C43 / C116-C117 | R1 return; R9 motive, affiliation and completed movement |
| C44 / C118 | R6-R8 demands, surrender, raids and experienced consequences |
| C45 / C119 | R7-R8 care/CPR and optional event behavior |
| C46 / C120 | R5-R6 and R8 health, age, private partner discovery and actual activities |
| C47 / C121 | R2-R3 and R7 drug state and completed use; C56 closes R5 scheduling and frozen elapsed time |
| C48 / C122-C124 | R6-R8 vehicle access, animal care and combat perception |
| C49 / C125 | C56 closes R5's ZAO-led event-derived brain history, real consumers and graph |
| C50 / C126-C127 | Retain recovery; R10-R15 truthful historical execution, protected data, training and acceleration |
| C51 and older producer gaps | R1-R5 continuity, time and physiology are closed; R9 retains full life concerns and R11-R14 retain actual learned consumption |

Closing one row updates its implementation, controls and acceptance evidence in
this map and ROADMAP. Source inspection, a passing structural border, native
mechanism proof and observed gameplay remain separate evidence. Planning coverage
does not upgrade an unfinished mechanism to implemented.


### C67 producer update

| Contract | Producer and durable owner | Behavioral consumer | Remaining boundary |
|---|---|---|---|
| Performed transfer knowledge | Needs/SourceUse native mutation -> frozen WorldSources observation -> existing Provisioning consumer -> private Perception episode | Knowledge food/water and admitted testimony | Later source conflict preserves observation but grants no successful material projection. |
| Recipient response | Witness's own held-ground context and category need -> Disposition appraisal -> only their episode | Existing charity preference toward the actor | C69 closes the bounded household-request appraisal after testimony; testimony still does not copy feelings. |
| Asked assistance | Explicit request -> requesting speaker's private dated request -> admitted speech or C73 radio receipt | Carrier's private request/destination and urgency | C73 closes reception and origin-preserving radio delivery when a request exists. Complete-house shortage production and broader private work instructions remain separate producers. |
| Dormant spoken access | C67 measured hearing plus C72 native/generated rest acquisition and record-owned rest/sleep/wake before the adjacent unloaded encounter | Perception transfer/request testimony | Closed for adjacent speech. C73 separately closes County Wire reception; dormant exchange actions remain separate producers. |
| Source curation | Speakeasy Record50 literal approved-document excerpts | Existing source validator/knowledge authoring | Extraction review, same-person acquisition, calendar join, ratification and eligible examples remain absent. |

Episode retention is initially 64 recent acts over fourteen county days scaled
by existing personal memory conditions. The fourteen-day base follows the
existing relation window; it is an implementation calibration, not a population
measurement. Request expiry remains the existing 96-hour window. Original event
identity/time and eviction floors prevent replay from refreshing forgotten acts.

### C68 producer update

| Contract | Producer and durable owner | Behavioral consumer | Remaining boundary |
|---|---|---|---|
| Performed personal handover | Needs item selection -> Handover reservation -> verified vanilla transfer -> exact destination holder | Existing share, reading, care-gift, settlement and yield consequences | Reload-unknown pending work stays reserved until an item-resolution producer exists. |
| Accepted exchange | Exchange need/surplus proposal -> two independently admitted handover legs -> Handover acceptance | Existing food/water and smoke/food barter | No dormant barter or player trade interface is claimed. |
| Partial exchange debt | One accepted leg completes while its opposite leg reaches a terminal failed state | Existing Standing debt and later settlement handover | Private perceived obligation remains separate; gifts create no debt. |
| Treatment boundary | Needs/player request -> Treatment reservation -> exact vanilla `ISApplyBandage` -> effective patient dressing | Existing loaded patient response, care skill, voice and critical-care choreography consume the result once | C70 closes loaded open-wound bandaging. Disinfection, stitching, dormant care and other medical verbs retain separate result work. |

Handover retains at most 512 records and 256 terms, evicting only terminal
history when capacity is needed. Current bodies, items, inventories and actions
are never serialized. Duplicate reservation of the same pending actor/item is
refused. The existing death funnel releases a dead participant's pending work
and live handles. Border 182 executes the owner in the installed Kahlua VM and
rejects a production mutation that applies social credit at queue time.

### C69 producer update

| Contract | Producer and durable owner | Behavioral consumer | Remaining boundary |
|---|---|---|---|
| Reported household assistance | C67 performed transfer episode -> admitted testimony; listener's own active food request, current membership and explicit ground claim join in Perception | Disposition's credibility-weighted private appraisal | No historical body need, giver intent or complete household stock is reconstructed. |
| Private disagreement | Current compassion, actor trust and immediate-teller credibility -> frozen signed reciprocity on only that told episode | Existing charity preference toward the actor | Appraisals do not travel, accumulate trust or create trade debt. |
| Request category | `callForBread` explicitly records food; the sole pre-C69 producer migrates missing category as food | Request routing and appraisal eligibility | Other request categories need explicit producers and consumers. |

Border 180 executes 90 delivery-knowledge cases and 21 named mutations. It
proves both evidence arrival orders, current-household and claim containment,
request/event order, bounded lifetime, detached retelling, saved-state refusal
and a changed existing charity choice without any social-ledger write.

### C70 producer update

| Contract | Producer and durable owner | Behavioral consumer | Remaining boundary |
|---|---|---|---|
| Open-wound request | Needs or player menu selects an exact bleeding part and carried dressing -> Treatment validates actor, patient, reach, part membership and holder -> one vanilla action | No consequence at admission | Reload-unknown pending work remains reserved because no native witness survives. |
| Native result | `ISApplyBandage.complete` performs item removal and Doctor-shaped dressing life -> Treatment verifies the exact patient part and item outcome | Completed, ineffective, interrupted and released results | Disinfection, stitching and dormant treatment need their own native action owners. |
| Result consumption | Completed result -> per-channel response, aid stamp, additional Doctor experience, aid voice, treatment log and post-treatment critical-care gesture | Existing distress, relationship, learning, speech and gesture consumers | Loaded-save player acceptance remains separate; broader care learning remains R9/R11-R14. |

Treatment retains at most 512 scalar records and evicts only terminal history.
Live bodies, body parts, inventories, items and actions are never serialized.
The death, player-death and controller-release funnels terminate unfinished
work involving either participant. Border 183 executes the shipped owner in the
installed Kahlua VM and rejects a mutation that grants care credit at queue time.

### C71 producer update

Project Zomboid remains the sole inventory owner. `SAOPrivateInventory` creates
a fresh read-only view for one loaded body or one exact dormant v4 envelope. A
loaded view distinguishes carried, static-container, vehicle-part, placed-item
and corpse holders; each item keeps its native ID and direct parent. Static,
vehicle and placed holders reuse WorldSources identity. Vehicle permission is
person-specific, unexplored contents remain unknown and an inaccessible part
refuses. A dormant view exposes exact recursive carriage and states that world
holders are unknown.

Needs, Controller, Harness, Animals and Standing consume the shared
recursive reader. A selected nested item retains its direct source container
while its root holder supplies current permission; native actions and their
existing result owners still perform every mutation. The view stores no state,
moves no item and cannot answer for another person.

The protocol emits item rows and `aggregate=refused`. A quartermaster's bounded
inspection can guide a current action but cannot create a larder or water total.
Standing schema 4 retires those inferred claims and requires explicit complete-
coverage Material evidence for future aggregate writes. Border 184 proves
loaded/dormant/reload agreement, holder conservation, removal, replacement,
transfer, legacy refusal and recursive mutation sensitivity. Dormant world
access, complete household stock and performed material actions remain separate
producer obligations.

### C72 producer update

The native envelope remains the last measured loaded state. BodySnapshot reads
FATIGUE, ENDURANCE and saved less/more-sleep traits directly from that validated
envelope without constructing a body, then commits the values and county hour
with the physical sleep/rest observation. New generated people carry explicit
initial physiology provenance. The earlier generated speech-access marker does
not retroactively establish rest state for an older save.

DormantPopulation advances the record on History's clock inside its existing
single identity-store pass. The installed awake-fatigue ratio, current endurance
and saved sleep trait advance wakefulness. At-home people rest from 22:00 to
06:00, cross the existing sleep threshold, recover by the loaded non-slot sleep
law and wake at the morning boundary. Sleep prevents the movement leg. The
advance occurs before dormant encounters, so Communication admits or refuses the
same produced state while retaining C67's measured-hearing check.

Materialization restores the native envelope first, then replaces fatigue,
endurance, asleep and seated posture with the completed record state and verifies
the result before publication. Border 185 covers sleep, movement hold, encounter
refusal, wake, encounter admission, legacy refusal, native acquisition and saved
trait rates. Native-person and handoff suites cover exact read/apply and
loaded/bodyless continuity. C73 supplies the separate operating receiver,
channel and recipient-reception producer.

### C73 producer update

Project Zomboid remains the loaded radio owner. `SAOPrivateInventory` reads only
direct-root communications radios, matching the installed carried-frequency
boundary, and captures item identity plus current channel, on/off state, volume,
battery presence, power, native use rate, two-way capability, mute and transmit
permission. A television is excluded. A radio inside a bag remains possession
and does not become an active endpoint.

PhysicalFacts stages that state and its county hour with the body snapshot. The
record advances only on battery power while no body exists; elapsed use can
deplete and turn off the receiver. On wake the advanced power/off result must
match and overlay the exact restored device before body publication. Legacy
`hasRadio` state proves no receiver configuration and remains unknown.

Communication joins that device state with the C67 hearing and C72 awake state.
County Wire and explicit player transmissions then write a recipient-private,
bounded, idempotent Perception receipt before any content effect. The receipt
retains broadcast/source identity, time, frequency, loaded/dormant
representation, device identity and carried claim descriptors. An aired request
names the original requesting speaker and enters a listener's request memory as
told testimony only when that speaker's original private request exists.

Player aid calls, camp testimony, peace petitions and chat presence use the same
endpoint proof. Effects apply only to the admitted listener; household
membership performs no implicit relay. Border 186 covers the loaded and dormant
paths, native battery and wake behavior, legacy refusal, private evidence,
request provenance and per-person routing. C73 does not recreate the retired
bounded-shelf shortage trigger or add an autonomous survivor radio scheduler.

### C74 producer update

The selected protected source assigns the July 1-6 county events to county
residents as lived days, while its age rules reserve the exact adult claim from
children's vaguer memory. SAO therefore records the prerequisite rather than
copying the conclusion: PopulationAdmissions writes a county-presence interval
after choosing a person's origin ground. Genesis residents begin on the first
record day; later arrivals begin at admission and inherit no earlier event.
Pre-C74 people remain unknown because their origin labels do not prove a dated
presence interval.

History exposes a complete calendar instant and a record-day coordinate on its
durable county-hour axis. The Java owner uses the same history offset as mature
simulation, so late-start history and live time share one calendar. The daily
population pass asks WorldKnowledge to advance; the selected claim appears only
after its event hour lies inside that person's presence and only for the adult
detail slice. It remains on that person's durable record with its lived path,
source hashes and supporting presence record.

Knowledge exposes detached claim identities and provenance. A separate
retention observation binds the age, carrier, access and retained checks at the
decision hour without reconstructing acquisition. The R12 evidence generator
runs production WorldSources, SourceUse, WorldKnowledge and decision capture in
the installed Kahlua runtime and binds the same person's acquisition to the
frozen event. The controlled source/holder is mechanism evidence; natural-county
distribution and loaded-save acceptance remain unclaimed. Speakeasy owns the
protected extraction and every standing after production.
