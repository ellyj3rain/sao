| Document | Survivor Awareness Overhaul Roadmap |
|---|---|
| Version | `2.7.15.1-pre-alpha` |
| Author | ellyj3rain |
| Repository | `ROADMAP.md` |
| Status | CANONICAL - readiness work and retained scope. |

# Roadmap

The intended progression is mechanical readiness across the simulation,
Speakeasy training and runtime integration, then tuning toward first play.
This follows Speakeasy RECORD entry 45. Batch closure and a green gate do not
establish readiness where causal mechanisms are missing or contradicted by
evidence. SESSION_STATE.md states the current assessment.

## Border compression and private unified project

DR-041 sets the immediate continuation after C56: compress the mod's borders,
following the A/B/C consolidation precedent, then work toward one private
unified mod/project across SAO, ZAO and Speakeasy's runtime artifacts.
The existing R contracts remain the implementation obligations.

DR-042 selects whole-mod runtime restructuring. The
[restructuring plan](artifacts/audits/20260920-0145Z-1845PST-border-compression/PLAN.md)
maps all 100 Lua/Java source files and 188 gate entry points, the current
ownership concentrations, the intended responsibility boundaries and migration
order. Behavioral contracts join production owners, cases and defect controls;
former-border and source crosswalks preserve provenance. C57 implements the first
unit: a shared body snapshot contract and consolidated native verification.
C58 completes population reconstruction and scheduling: separate admission,
representation, physical-observation and dormant owners under History, with
explicit callback replacement and world reset. Perception/access and R10a
world-source grounding are next. Decision/action separation, social producers
and presentation follow in dependency order. Existing R work moves with its owning contract.

Private assembly follows a cross-module inventory of loading, Java entry
points, save identity, settings, model artifacts and integration evidence.
That inventory determines the source layout and packaging plan before assembly.

## Implementation contracts after C56

The work below is the ratified sequence; each row states whether it is closed or
still planned. Each item names an implementation owner, its dependency and the
evidence required to close it. The detailed
mechanisms and bounded investigations are in [SUBSTRATE.md](SUBSTRATE.md#implementation-contracts).
R identifiers refer to work in this plan; batch identifiers follow coherent
implementation units when those units close. They do not reserve future batches.

**Implementation dependencies carried through restructuring:** R1 closed in SAO C52 / ZAO A35, R2 in C53, R3 in
C54, R4 in C55 / ZAO A36 and R5 in C56 / ZAO A37. R10a establishes the
grounded world substrate needed by later dormant work; R6 repairs perception
and access against that substrate. R11-R12 can proceed alongside them.

R1's [evidence record](artifacts/audits/20260919-0735Z-0035PST-r1-return-evidence/README.md)
names the implemented mechanisms, controls, native-source continuation and the
selected critical-but-injured recovery rule. C53's Border 168 and the retained
Border 160 close current substep time, unit conversion, native pacing and
partial catch-up/reload. Neither batch is a loaded-world play receipt. Remaining
technical investigations have named outputs below; they are part of the work,
rather than indefinite deferrals.

| Work and owner | Depends on | Implementation and completion evidence |
|---|---|---|
| **R1. Authorized return — SAO + ZAO (closed C52/A35)** | C51 | Quiesce the old owner and incoming actions; stage/validate current state under a paused owner; acknowledge old-body teardown; then publish/adopt once. Enumerate durable eligible people for bodyless recovery. Refusal, partial cleanup, reload and retry preserve one owner and never duplicate possessions. Ordinary dead records remain refused. |
| **R2. Shared time — SAO; ZAO consumers (closed C53)** | C51 | Inventory clock readers and durable timestamps; make decision-time reads current within every historical substep; convert the WorldGenesis day argument at its boundary. Separate engine pacing from county time. Test actual callback order, day-zero on/off, nondefault day length, midnight, partial catch-up and reload. |
| **R3. Complete person persistence — SAO (closed C54)** | C51; R2 for next-update proof | The v4 snapshot owns nutrition, fitness, appearance, recipes, every reading collection, descriptor perk boosts and declared durable character metadata. Per-item native fluid facts validate mixtures as well as item identity. v1-v3 remain readable; absent fields carry migration provenance. Border 169 proves zero-time fidelity, repeated wakes, the next fitness/nutrition/XP updates, missing definitions and failure recovery. |
| **R4. Durable/runtime ownership — SAO + ZAO (closed C55/A36)** | R1-R3 | Function-bearing callbacks remain outside serialized history and extensions re-register by stable ID. Startup reconstructs caches, graph registries, controllers, courses and Java runtime maps without retaining the prior world. Save-time corpses materialize before serialization; pending fitness work cancels without credit. A write-ahead generation journal reconciles Afflicted-return records across every old/new native/global save pairing. Borders 170 and 8 execute actual serialization, new Lua environments, second worlds, engine lifecycle order, corrupt/missing journal refusal and repeated replay. |
| **R5. Health and dormant physiology — SAO + ZAO (closed C56/A37)** | R2-R3; R4 for persistence | Daily work and frozen abstinence use durable county time; current physical facts and ZAO-owned pathogen state feed a persisted event history whose integration agrees across partitions and reload. Brain history has medical/inspect graphs and memory, decision, affective and motor consumers. Dormant food and drink use native partial consumption with nested access, nutrition, spoilage and quantity conservation. A completed, interruptible non-feeding blood action is the sole Afflicted conversion producer; its exact-once result transfers the same human shell and dormant envelope from SAO to ZAO. Borders 162-163 and 171-175 plus ZAO Borders 5, 9 and 10 cover the mechanism and controls. |
| **R10a. World sources and reconciliation — SAO** | Source inventory now; R2, R4 for runtime integration | Establish source-backed unloaded geography/resource/access state and how performed changes reconcile when chunks load. Explicitly represent missing data. This supplies the world substrate needed by dormant R6/R9 proofs before historical integration. |
| **R6. Perception and access — SAO** | R2 for timestamps; R10a for dormant proof; loaded repair can begin now | Correct actual animal/human scan output, prone/deactivation reads, partner visibility/floor checks and moving/locked vehicle sources. Keep acquisition, permission and physical access distinct. Prove hidden, stale or inaccessible facts cannot offer an action or change its result; unavailable ground is explicit. |
| **R7. Action ownership and receipts — SAO; ZAO retained verbs** | R1-R2, R4, R6 | Connect intent, approach, queue, execution, interruption and observed result. Crossed actions use retained learned capability and the shared action contracts; the Afflicted exposure path has its own non-feeding result and cannot fall through to ordinary zombie attack or eating. Update inventory projections, experience and relationships only from the appropriate result. Interrupt each stage; repeat completion notifications; reload pending work. No cancelled action earns completed-work credit. |
| **R8. Repair audited actions — SAO + ZAO callers** | R5-R7 as used | Repair driving routes/progress/passengers/steering, ordinary homeward activity, child health/play, aid/CPR composition, robbery/raid response, animal approach and optional event consumers. Each path must reach a world consequence or a reasoned refusal. The contract table in SUBSTRATE names the counterexamples and retained working pieces. |
| **R9. Complete life-simulation producers — SAO + ZAO domain owners** | R5-R8 and R10a, incrementally by concern | Implement the producer rows in SUBSTRATE: provisioning and places, exploration, affiliation, care, learning, culture, rest, governance, communication and conflict. Rebuild Crossed execution from its canonical body and mind: human appearance, retained cognition, experience, drives and action vocabulary; weapons, tools, strategy, coordination, use of the dead, variable settlement/leisure and deliberate work on Afflicted. Each concern first produces the bounded mechanism inventory below. Connect candidates to executors; prove conservation, private knowledge and socially grounded recognition in both representations. |
| **R10b. Historical integration and population — SAO + ZAO** | R2, R4, R8-R9, R10a | Exercise grounded dormant opportunity and observable later changes across the integrated county. Account separately for initial people, arrivals, births, deaths and exits. Resolve the existing refill policy against the prohibition on target-seeking outcomes. Compare actual cohorts and open populations correctly; fixtures and target counts cannot establish fidelity. |
| **R11. Decision capture and joins — SAO + Speakeasy** | Start now; final eligibility follows R2, R6-R10 | Capture immutable person/situation/options before choice; attach action results separately. Include county/run/event identity, revisions, settings, source confidence, failures and requested/reached horizons. Validate entire joins before atomic export. Nested mutation, reader failure, duplicate/cross-county identities and incomplete runs must be detected. |
| **R12. Approved data and world knowledge — Speakeasy; SAO knowledge reader** | Start now; R11 for new captures | Preserve 190 approved choices and nine approved world documents with hashes/ruling references. Audit conditioning separately from approved intent. Build versioned corpus/claim views and person-specific acquisition. Future facts, LOW claims and lineage leakage are refused. Correct mutable sibling README/training status against RECORD 43; historical corrections are append-only. |
| **R13. Training and export — Speakeasy** | R11-R12; eligible R8-R10b coverage | Build decision authoring, deterministic voice expansion, understander utterance-to-meaning and speaker claims/conditioning-to-expression datasets, preserving actual approval status. Implement lineage-separated evaluation and reproducible training. Complete the architecture/export investigation; deliver deterministic versioned artifacts and reference inference with separate behavioral/grounding measures. |
| **R14. Learned execution and exchange — SAO Java/Lua + Speakeasy artifacts** | R7, R9, R13 | Load a compatible model in Java, infer at the real decision point, revalidate and execute the selected option. Complete both understanding and constrained expression through existing belief, standing and command channels. A changed model output must change an actual action or exchange; false claim recombination, stale options and failed inference cannot manufacture success. |
| **R15. Late-start acceleration — SAO + Speakeasy** | R10b; versioned policy/export from R13-R14 | Evaluate acceleration against the repaired causal stepper with matched seeds, initial conditions and policy version. Compare histories, distributions and subsequent behavior. Preserve provenance and quantify error/performance. Retain causal stepping until a candidate passes; fixed survival floors, settlement quotas and authored completed work remain invalid. |

R9 closes only when every producer row has its own evidence. R8 similarly
accounts for every audited action family. A thin demonstration in one family
does not discharge the rest of the row. Historical and learned runs declare
their supported coverage explicitly.

Corpus work, protected exports, capture mechanics, evaluation design and model
format experiments can advance while producers are repaired. Final training
eligibility depends on the truth of the captured mechanisms. Experimental
datasets retain their limitations; they do not establish full-scope readiness.

## Defined investigations

| Investigation | Owner and required output | Work it resolves |
|---|---|---|
| Native component continuation | Closed in C54 for person persistence and consumed by C56: the field inventory distinguishes serialized, reconstructed and omitted state; Borders 163, 169 and 174 cover fluid definitions, nutrition, nested carried resources, native partial consumption and partitioned wakes. | R5 closed |
| Return and action failure order | SAO + ZAO: callback/teardown inventory and a phase-by-phase recovery table, including current corpse possessions, failed removal and save/reload. | R1, R4, R7 |
| Unloaded world opportunity | SAO: source-backed map/resource/access inventory, resource depletion/renewal ownership and a reconciliation protocol for later loaded chunks. Unknown geometry remains unavailable until grounded. | R6, R9, R10 |
| Per-concern producer mechanisms | SAO/ZAO domain owner: for each R9 concern, classify existing producer/consumer as supported, defective or missing; specify trigger/pressure, private opportunity, actor decision, executor, durable result, interruption/reload and a discriminating test. Produce separate contracts for childcare, art/ceremony/burial, overlapping/local/federated authority, retained turned behaviors and animal companionship/ownership. Surface any missing substantive ruling before implementing it. | R8-R9 |
| Brain-health integration | Closed in C56/A37: ZAO owns the persisted history when installed, SAO supplies current physical observations and standalone storage, exact interval integration has numerical tolerances, and the same history drives medical/inspect graphs plus cognitive, memory, motor and affective effects. | R5 closed |
| Population policy | SAO: reconcile ratified delayed refill with the no-target-seeking generation contract. Document admissions and demographic sources, distinguish simulation rules from diagnostic population controls, and surface any real conflicting policy ruling. | R10 |
| Model architecture and interchange | Speakeasy + SAO: build a candidate inference/export harness; compare task-appropriate implementations, conditioning/tokenization, dimensions, memory and layout using reference/Java parity and measured actual-model allocations/latency. Candidate dimensions stay provisional until the target budget is verified. Loaded-game budget acceptance remains distinct from offline evidence and does not block corpus/schema/research work. Identify unresolved consequential choices before commitment. | R13-R14 |
| Accelerator suitability | SAO + Speakeasy: matched causal baseline, explicit equivalence measures and candidate error/performance results. A failed comparison leaves the causal stepper authoritative. | R15 |

Consumable production and synthesis mechanics remain outside the authorized
scope in GOVERNANCE.md. The provisioning plan covers existing-world access,
transport, storage, sharing, trade, conservation and permitted integration
wiring; it does not introduce creation recipes or synthesis rules.

## Ratified scope retained

| Concern | Continuing requirement |
|---|---|
| Day zero and late starts | Ordinary life, collapse and later states share causal machinery. Day-zero off remains a first-class start. |
| Person and life | Age, childhood, conditions, habits, hobbies, addictions, culture, relationships and material pressures condition choice. Work and roles are downstream observations. |
| Places and resources | Ground follows use; organizations can hold several places, move or abandon them. Provisioning follows real access, consumption and work. |
| Authority and recognition | Claims, recognition, response, jurisdiction, legitimacy and coercion remain distinct. Repetition alone does not appoint an office. |
| Afflicted and crossed | SAO executes afflicted people; ZAO owns pathogen state and crossed execution. Capability follows actual experience. Crossed remain human-looking, cognitive, organized and able to use retained human actions, weapons and tools. Strategy, diversion, capture, diet and living responses remain in scope; Afflicted are not food, and their conversion requires the distinct intentional exposure action and an SAO-to-ZAO ownership transfer. |
| Brain health | ZAO-led per-person event-driven brain-health and inflammatory state, integrating drug and pathogen effects, memory, health markers and a graph visualization. Authored decline curves do not replace causes. |
| Optional integrations | Every installed family is accounted for at its actual seam with its ratified settings and absence behavior. The nuke is optional and defaults off. |
| Cognition and speech | Person, perceived situation, available options and choice form the data contract. Models cover decisions as well as expression; no player-speech harvesting. |

[Detailed scope before consolidation](Batches/history/C-roadmap-before-consolidation.md)
retains the prior requirements and decision references. Its former C labels
resolve through FORMER_LABELS. Its historical progress and completion claims
are superseded by this roadmap and the audit. Settled operator ideas remain.

## Evidence and open decisions

The [implementation audit](artifacts/audits/20260919-0356Z-2056PST-c112-c126-implementation-audit.md)
and its probes identify the immediate defects. F-075 withdraws the old
full-fidelity and fitted-trajectory claims; F-076 records the broader audit.
Diagnostic samples remain observations within their documented limitations.

Grounded-dead calibration, early Knox ratio interpretation and destructive
relationship pruning remain operator decisions. Existing ratified mechanics
continue without waiting on them. Play acceptance is distinct from mechanical
verification; no new play-session prerequisite is introduced here.
