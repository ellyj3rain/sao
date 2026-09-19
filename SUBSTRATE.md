| Document | Survivor Awareness Overhaul Dependency Substrate |
|---|---|
| Version | `2.7.14.4-pre-alpha` |
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
recorded in F-077. Source names in the original evidence refer to its recorded runtime tree;
former batch labels inside evidence retain their historical meaning.

| Contract | Producer and caller | Durable state | Observation or test | Remaining gap |
|---|---|---|---|---|
| One person across loaded and dormant life | Identity owns the record; Body.materialize creates a body; Controller.adopt attaches decisions; Population manages range transitions | Person registry and hibernation pack; body registry is transient | B executes Body.release in the installed VM, with successful, empty and throwing capture | C51 repairs the supported capture/teardown/restore transaction (Borders 162-163). C52 repairs authorized Afflicted return, exact-source transfer and controller adoption. Native components preserve inventory, equipment, Stats, BodyDamage and XP. Other character components remain R3 work. |
| Returned afflicted people resume living | AfflictedReturn reads ZAO's loaded controlled bodies and calls Body.materialize | Existing person identity and ZAO pathogen state | C52/A35 execute the authorized transfer, source hold, return health and controller adoption under controlled Kahlua and installed-engine probes | R1 is closed. Running-save interruption across separate native save surfaces remains R4; the complete Crossed interaction remains assigned across R4-R10. |
| County time has consistent units | History owns county hours, day/tick conversion and quantization; Population advances historical substeps; Controller refreshes decision time | Historical progress and per-person timestamps | C53 Border 168 executes current substep reads, reload, midnight, Day Zero/DayLength invariance, WorldGenesis conversion and separate host pacing; three mutations restore the named defects | R2 is closed. R3-R10 consume this axis; their domain scheduling and event integration remain their own work. |
| Saved state reconstructs usable runtime behavior | GraphPersistence binds Branching tables to ModData; Integration.ensure registers built-ins | Serializable IDs and pattern history survive; closures do not | B saves and reloads an actual Kahlua table, then initializes the shipped modules | Built-ins reconstruct. An extension must re-register its callbacks; runtime registries need explicit ownership separate from durable history. No normal built-in reload failure is demonstrated. |
| Facts are private and acquired | Java scans feed Perception; Knowledge preserves acquisition and Standing evaluates permission | Beliefs with source, time and uncertainty | A reproduces animals entering the IsoPlayer human path and traces global activity participant discovery | Narrow scanner output before decision use, preserve provenance and distinguish animal facts. Visibility and permission do not imply physical access. |
| Actions have owned completion and interruption | Controller selects and queues engine actions; Driving, Medical, Animals and inventory adapters execute | Records should change from observed consequences | A exercises moving-vehicle cancellation, cancelled surrender, refused CPR and remote egg collection | Approach, queue, completion, failure and cancellation must be connected. A request must not award goods, experience, trust changes or learned capability. |
| Loaded and dormant opportunities describe the same world | Loaded engine supplies actual containers, ground and bodies; Places and Population provide dormant representations | Place facts, resources, position and history | A traces stale vehicle locations, missing compartment access and diagnostic invented ground | Unloaded geometry is unavailable unless grounded data exists. Dormant processing needs its own accountable producers; test fixtures cannot be accepted as world observations. |
| Health integrates actual events over time | Course, Medical, Habits and Neuroinflammation consume person state; ZAO StateStore owns pathogen transitions | Person health/habits and pathogen record; optional body counters need review | A reproduces cadence-dependent brain state, healthy-child wound fear and frozen-use withdrawal drift | Reconcile live inputs, cumulative versus current poison, owner reads and elapsed-time partitions. The brain graph request is not fulfilled by a scalar bar. |
| Social outcomes follow performed acts and recognition | Standing, Organization, Settlement and Integration mutate social records; Branching.record currently counts selections | Claims, membership, offices, patterns and experience | A traces automatic relocation, selection recorded before execution and recognition by repetition | Affiliation, legitimacy, dissent and development need causal producers. A chosen branch is not performed work; repeated choices do not establish public recognition. |
| Diagnostic populations support valid claims | Population genesis/refill and mortality produce open-population histories; county sweep exports observations | People, deaths, seeds and run progress | C50's independent 90/365-day receipts distinguish 12-person targets from 27/72 created records | Reconcile admission/refill with the life-simulation contract. These samples cannot be reported as 100 percent cohort survival or full simulation fidelity. |
| Training sees the actual decision moment | county_dump.py joins person, situation, options and choice; Speakeasy owns ratified rows and models | Immutable captured rows and source provenance are required | A mutates person/belief state after capture and shows future information leaking into an earlier row | Deep snapshots, capture failure accounting, complete horizons and executable options are unfinished. Ratification of 190 choices does not validate their exporter. |
| Learned cognition reaches consequences | Branching/Integration expose pressure and selection; Java inference and fact constraints are primitives | Versioned models, evaluation sets and execution receipts are required | Source tracing finds branch/work outputs consumed by inspection without general execution dispatch | Complete producers and the training/export/runtime path. A model choosing an unavailable action or a graph reporting a choice is not the promised behavior. |

## Person preservation and continuation

C51 implements the first continuation contract: capture failure preserves the
prior record and body/controller ownership; failed teardown retains a durable
pending capture; restoration occurs before publication/adoption for every caller.
Explicit clearing removes identity after teardown. Incoming actions and retained
representations are distinguished from dormant people. Borders 162-163 exercise
the actual Lua ownership and native component codecs with source controls.

Supported native state comprises inventory (including nested contents), held,
worn and attached references, Stats, BodyDamage and XP/traits/perks. Nutrition,
fitness, learned recipes, standalone character ModData and appearance remain
outside that snapshot. v1/v2 compatibility retains the information those formats
actually stored. Existing positive-elapsed dormant metabolism remains unvalidated.

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
Normal ordinary-zombie offscreen life stays a separate mechanism. R4 owns
coordinated generation/replay for interrupted multi-file saves; a completed-save
roundtrip cannot establish that stronger guarantee.

`SAO_AfflictedReturn.adopt` calls `Body.materialize(rec)` while `rec.dead` is
true and clears that flag only after success. C51's general dead-record refusal
therefore blocks this caller. The actual-Lua
[continuation probe](artifacts/audits/20260919-0627Z-2327PST-continuation-evidence/README.md)
reports no returned body. Removing the guard in its control permits a body but
still supplies no controller, reproducing the earlier audit's separate defect.

SAO owns the living-person transaction; ZAO.StateStore owns the recovery fact
and ZAO.Controller owns the old turned body. Implement a durable return phase
with an authoritative recovery event, staged position/state, ownership and
retry information. Quiesce the old ZAO controller/body and incoming inventory
actions before capturing current possessions or physical state. Retain that hold
through teardown retry and reconstruct it on reload before either owner advances.
Construct and validate the new body under a paused pending owner, through the
authoritative return phase while ordinary materialization still refuses dead
records. Acknowledge teardown of the old representation before publishing the
living person and enrolling its controller once. Failed steps retain their
phase and a recoverable owner; a failure after old-body removal resumes from
that phase rather than pretending removal can be undone. They do not rerun the
death funnel. A pre-removal refusal with no committed transfer can safely resume
the old owner after releasing its hold. Prior death history stays historical.
Coordinate both repository records when the
runtime seam changes.

The existing ZAO cleanup clears `controlled[personId]` before its protected
remove calls and reports release regardless of their result. Replace that
ordering with acknowledged cleanup. Inventory the old body's current items
and their relationship to saved living state before implementing transfer:
looted possessions cannot reappear from an older hibernation pack. Enumerate
eligible durable records with ZAO-owned state for bodyless historical recovery;
loaded `Controller.controlled` membership is insufficient.

Proof covers ordinary-death refusal, loaded and bodyless recovery, both callback
orders, every failing phase, attempted source mutation after capture,
interruption/reload, repeat notifications, exactly one active controller and
conservation of actual possessions. Optional ZAO
absence preserves SAO's normal lifecycle.

### R2-R4: time, complete person state and reconstruction

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
work. Border 160 retains partial-day catch-up/reload and production callback
ordering. The controls remove the decision refresh, pass day as tick and put
corpse grace back on county time; each fails for its named reason. ZAO requires
no R2 code change: its controller already obtains decision ticks through
`SAO.Controller.tick()`, and its pathogen/state readers already use county hours
or explicit elapsed days.

R3 and R4 continue below. Their timestamp migrations must identify the old
axis before conversion; an unidentifiable frame counter cannot become claimed
historical time. R5 still owns drug scheduling and physiology partition
equivalence. A common clock makes those repairs possible but does not complete
them.

Extend `SAONativeSnapshot`, `SAOHibernation` and Body's restoration order with
the following field ownership. Native serializer availability is a starting
point for each next-update test, not proof that omitted runtime fields are inert.

| Person state | Native or record owner and implementation | Required proof or bounded investigation |
|---|---|---|
| Nutrition | `IsoPlayer.getNutrition()`; `Nutrition.save/load` stores calories, protein, lipids, carbohydrates and float-rounded weight. Add a bounded section and finite-value preflight. | Preserve nondefault values and the next update. Investigate omitted `updatedWeight`, flags and extrema; low-weight setters can apply damage and emit an event, so restoration must not invent another injury. |
| Fitness | `IsoPlayer.getFitness()`; `Fitness.save/load` preserves regularity, stiffness, affected parts and exercise timestamps. Restore into a fresh component after controlled initialization, or use an explicitly verified clearing route. | Pending stiffness/pain and conditioning survive repeated wakes. Native load inserts without clearing and no general clearing API is established; `lastUpdate` and current exercise are omitted. Resolve calendar-millisecond stamps and minute-boundary continuation against R2. |
| Recipes, reading and learning modifiers | Preserve the known-recipe string list, read-page/media/book collections and `SurvivorDesc.getXPBoostMap`; these are outside XP's existing codec. Restore after profession defaults without replaying learning callbacks. | Book progress, custom perk boosts and the next XP grant agree. Enumerate every read-media collection. Retain missing recipe IDs with separate current availability; missing required perk definitions refuse restoration. |
| Human appearance | `HumanVisual.save/load` preserves skin, hair/beard colors/models and body visuals. Restore it with exact worn references before final model reset. Identity owns name/sex/age projections. | Dyed/hat-dependent hair and body marks survive. Establish ownership/reconstruction of forced-model/outfit references. Investigate separate hair/beard growth timers, whose public preservation setters were not found; prove reconstruction or justify an engine adapter before using one. |
| Character metadata | `IsoObject.getModData/setModData` and Kahlua's codec exist, but unsupported values are silently omitted. Inventory keys, integration owner and durable/runtime meaning; persist declared durable values, reconstruct runtime values and reassert Identity's person ID. | Nested optional drug counters survive absent modules and repeated wakes without aliasing. Required unsupported values, cycles and oversized structures refuse capture. This work includes the optional methadone/withdrawal state, not just item ModData already preserved by C51. |
| Fluid contents | Native item/entity serialization reaches `FluidContainer.save/load`, which can silently drop missing fluid definitions. Extend validation beyond the item-ID/type/parent manifest. | Root and nested containers preserve mixture and amount. A removed definition must be detected; reload cannot accept a different mixture as the same carried item. |

Version the new envelope and retain v1-v3 readers. Missing historical fields
are marked absent and initialized once from a documented engine/record baseline
with migration provenance. They are not described as recovered history. Invalid
required sections preserve the durable snapshot and C51's cleanup/retry contract.

For R4, enumerate graph, person, pending-action and sibling state by durable
owner, runtime registry and startup reconstruction caller. Built-in graph
registration already reconstructs after native Kahlua load; retain that working
path. Extensions need explicit startup registration with stable IDs rather than
serialized closures. Exercise real save serialization, reload and switching
worlds in one process, including cached History stores and pending transactions.

### R5: health, exposure and dormant consumption

SAO's `Drugs.onTick` currently consumes the new-day flag before ten-minute work
is due; `Habits.cleanDays` ignores an active freeze. Make completed daily work
and frozen elapsed time durable and test callback offsets, skipped intervals,
reload and maintenance-drug expiry. Refresh living wound/infection observations
from their physical owner instead of waiting for hibernation.

ZAO owns pathogen terminal/form state. SAO reads that state rather than the
unwritten `rec.terminalState`. ZAO leads the ratified event-driven brain-health
contract, with SAO supplying actual exposures, care and observable effects;
standalone SAO health remains supported when ZAO is absent. Separate exposure
events and current toxic burden from cumulative historical totals. Integrate
infection, wound, drug and withdrawal events over their actual intervals rather
than sampling an endpoint and multiplying it by the whole day. Reverify the
installed prior art, record the state/clearance rules and numerical tolerances,
and preserve exposure/history ownership across reload.

F-084 corrects the current Crossed/Afflicted exposure claim. The stored
transition is properly restricted to a Crossed carrier and an Afflicted target,
using crossed odds multiplied by Afflicted susceptibility. There is no
spontaneous Afflicted roll. Both callers are nevertheless once-per-day
three-tile proximity checks. Replace them with a completed intentional action
and an exposure result that can be interrupted, persisted and observed. The
result must then transfer the body from SAO's living Afflicted owner to ZAO's
Crossed owner exactly once; changing only `terminalState` is incomplete.

The brain-health deliverable includes the requested history graph in existing
inspect/medical surfaces and real memory, cognitive, motor and affective
consumers. Medical inspection must reach it when Knox is absent. Verify those
effects and the off switch; a scalar display or a getter with no behavioral
consumer does not close the work.

Positive-elapsed hibernation currently removes whole food while adjusting hunger
alone, empties a drink container with capped relief, and searches root inventory
only. Reconcile its consumption with native effects, nested access, partial
quantities, nutrition, spoilage and resource accounting. This is a distinct
simulation repair from zero-time snapshot fidelity. Compare the same supported
event history across loaded, dormant and reloaded intervals; explicitly bound
the comparison where the engine has no unloaded-world equivalent.

### R6-R8: evidence, access and performed actions

Candidate generation uses the person's acquired facts, provenance and uncertainty.
Execution rechecks current physical access and permission. The actual scanner
must classify animals before its human output path; optional prone variables and
deactivated targets must be read at the consuming path. Activity partners need
perception and floor/visibility checks. Vehicle sources need current position and
`canAccessContainer` at inspection and use. Inventory every cached target/source
reader to cover the class of failures, including unavailable unloaded ground.

R7 gives each action an owner across proposal, approach, queued action, execution,
refusal, cancellation and observed result. Source-inventory the engine callbacks,
bridge verdicts and teardown/reload behavior before selecting the receipt format.
A receipt identifies person, action/target, relevant time and result; repeat
delivery is harmless. Separate attempted effort from completed accomplishment.
Physical effects remain with their actual engine/domain owner; durable experience,
material projections and relationships follow the corresponding observed result.

| Action family | Concrete repair and retained substrate | Completion counterexamples |
|---|---|---|
| Driving | Retain vehicle/key adapters and C115's option wiring. Repair new-route cancellation, position-based progress, passenger wait phase and rearward steering. Stamp driving competence after actual performance. | Moving journey beyond 600 updates completes; blocked journey fails; failed approach earns no drive verb; passengers board or take an independent valid route; cancellation parks safely. |
| Ordinary activity and children | Execute the loaded `in` choice as homeward movement; align its dormant counterpart. Fix zero-wound truthiness and refresh healed state. Cover comfort, play, literacy, learning, age capacity and child driving limits. | Need interruption is respected; healthy/healed children do not retain wound fear; unseen/upstairs peers cannot become activity partners. |
| Care and optional events | Coordinate treatment and CPR readiness/sequence. Establish intended physiological effects and observe completion separately from gestures. Revalidate Week One/nuke event ownership, settings and calendar. | Busy/refused CPR grants no care result; cancelled aid grants no completed-help credit; nuke off/on, persisted draw and post-strike consequences are individually exercised. |
| Robbery and raids | Connect delivered demand, victim decision, completed transfer and aggressor reconsideration. Preserve witnesses and expiry. Gate breach pressure on the actual relationship/claim evidence. | Walking away cannot cancel a transfer already credited as yielding; interrupted surrender grants nothing; successful yield changes the next aggressor decision; a neutral claim alone does not justify forcing; haul equals goods acquired. |
| Animal care | Approach the selected hutch, trough or animal; revalidate reach, tools and availability; let the native action produce its result. | Distant/moved targets, empty yields and cancellation are respected. Horse and predator absence are supported. Ownership/companionship behavior requires its own evidenced semantics. |
| Provisioning | `Needs.depositSpareFood` currently credits shelving on queue acceptance, and `Recognition.onShelved` changes material state immediately. Move credit to observed effects. | Interrupted hauling creates no stock or completed-work recognition; observed inventory and projected material remain reconcilable. |

### R9-R10: the full life simulation and its world

`Integration.apply` and `Branching.select` currently record selections, while the
controller mainly projects graph output into diagnostic pressure. Connect each
available candidate to an execution owner and its result. `recognize(count>=3)`
and `formOffice` are presently uncalled primitives; invoking them would not
supply the missing social evidence. `Recognition.onProvisioned` currently invents
rooms, water and food for a settlement, and election projection asserts every
other member's recognition. Replace invented facts with actual ground and each
participant's expressed/observed response.

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

R10a supplies grounded unloaded opportunity and the later world changes these
actions imply, before their dormant proofs. Inventory map/resource sources,
access, depletion/renewal and loaded-chunk reconciliation first. R10b then
validates integrated historical behavior after the relevant producers exist.
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

SAO `tools/county_dump.py` must freeze nested records, beliefs and claims before
selection. Export choice and subsequent observed consequences separately, with
pending/censored outcomes and action-specific observation horizons. Capture
required-reader failures, exact requested/reached horizons, engine mode, county/
run identity, seeds, settings, source/code/model hashes and schema/clock versions.
Repair the evidence host's fake-ground and incomplete-run behavior. A nested
mutation after capture must leave exported decision-time bytes unchanged.

Speakeasy's `tools/cross_module_rows.py` must namespace joins by originating run,
county, person and event/time identity, validate the whole input before atomic
output and refuse protected approved destinations. Retain the ratified four
halves: person, perceived situation, executable options and choice. Every offered
option names a real action owner, parameters and eligibility evidence. Execution
revalidates it because the world may change after inference.

Protect the 190 ratified choices and nine approved world documents. The reviewed
first work-word row has decision hour 3408 but later death/lesson stamps at 5616/
26304; its approved choice and its conditioning evidence have distinct standing.
Preserve the original and its ruling. A versioned derived view must identify
reconstructed, censored or unusable context rather than silently rewrite approved
intent. If changed context changes the choice's meaning, obtain the actual
required ruling at that point. Historical trajectory files are not admitted to
training merely because they exist.

Compile approved knowledge with stable claim IDs, source/page/hash, confidence,
knowable date, carrier and acquisition rules. Separate language texture from
claims a person can know. LOW-confidence material cannot teach; October context
cannot become July knowledge. Apply age-at-event, occupation, region, literacy,
hearing and testimony constraints from Speakeasy's world plan. Update its stale
README/training approval waits against RECORD 43 as part of R12.

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
| C47 / C121 | R2-R3, R5 and R7 drug state, scheduling, frozen use and completed use |
| C48 / C122-C124 | R6-R8 vehicle access, animal care and combat perception |
| C49 / C125 | R5 ZAO-led event-derived brain health, real consumers and graph |
| C50 / C126-C127 | Retain recovery; R10-R15 truthful historical execution, protected data, training and acceleration |
| C51 and older producer gaps | R1-R5 remaining fidelity/ownership; R9 full life concerns; R11-R14 actual learned consumption |

Closing one row updates its implementation, controls and acceptance evidence in
this map and ROADMAP. Source inspection, a passing structural border, native
mechanism proof and observed gameplay remain separate evidence. Planning coverage
does not upgrade an unfinished mechanism to implemented.
