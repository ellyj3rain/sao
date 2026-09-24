# Enacted social decisions and character continuity

Status: proposed implementation specification for Field Test review. The operator's direction in GOVERNANCE_AND_ML_PLAN.md is established. This document defines the proposed first implementation unit and its relationship to the remaining roadmap; it does not report implemented behavior.

## Result and scope

People can raise a concrete shared matter, reach particular people, respond individually, assume limited responsibilities, act and revise their participation. A meeting can leave disagreement unresolved. Authority and separation follow those acts. The same process persists through distance, interruption, representation changes and saves. Survivors, Afflicted and Crossed have explicit paths through the mechanism, with distinct capabilities and motivations.

The first unit connects this process to performed acquisition, carrying and delivery, using existing source and handover owners. These activities supply observable consequences while the mechanism supports broader work and governance. It includes initiating and contesting scoped coordination, concurrent responsibilities, withdrawal and continuity. It does not claim to finish every election procedure, construction family, combat behavior or learned policy.

| Part | First unit | Following work |
| --- | --- | --- |
| Social production, R9 | A privately known matter produces proposals, delivered responses, scoped responsibility and revisions; retire encounter-triggered roster elections and automatic schism. | Broader enactment of institutional procedures, succession, enforcement and inter-group arrangements. |
| Perception and action, R6-R8 | Prove actual communication access and work-relevant observations; support ongoing work, justified interruption and resumption in this unit. | Complete native sensory fidelity across entity, place and sound consumers, broader combat and work repair. |
| Physical continuity, R7/R10 | Travel, attendance, acquisition and delivery carry the same process across loaded/dormant execution and reload. | Broader construction, usable-space development and county-scale historical production. |
| Integrated ML, R11-R12 | Capture private inputs, available choices, participant responses and later results for all three actor categories. | Human-reviewed task admission, training/export and runtime inference under R13-R15. |

The initial activity family is an implementation recommendation. It does not define a compulsory settlement objective, preferred government or progression by population size. The wider perception concern remains explicit work; proving conversation access alone cannot close it.

## Source anchors and prior art

SAO aaa5c8f9778f5633ae097b1fd2e183cefc4bc99a; ZAO af3dda04a383a79db1003f7f4202efc2367c3238; CAO 099313efab97d85c3fd24753304765a3aca7591b; active Speakeasy e1be69a7427dbec147ba0f81bd75c5a330192793. Reconfirm these before implementation.

ORGANIZATION.md already defines matter-specific authority, multiple holders, recognition and dissent. SAO_Standing.electLeader, formOf and checkSchism supply the shortcuts to replace. SAO_Exchange and SAO_DormantPopulation invoke them during encounters. SAO_Recognition.onElection infers recognition from membership. These findings and CAO file/line anchors are recorded in REVIEW.md and GOVERNANCE_AND_ML_PLAN.md.

CAO provides methods for delivered orders, authorization before native work, owned job continuity and completion-derived material results. Reuse those methods through PZ-native actions and SAO's existing owners. Its numeric obedience, perception calibration, map stock queries and role assignments do not establish PZ facts or individual assent.

Current SAO_Communication.send queues a message. Its generic deliver function marks delivery and may record a claim; that call by itself does not prove that a particular recipient heard, understood or accepted it. Current bodyFor resolves SAO bodies and the player, leaving ZAO-owned representation access to implement. GraphPersistence schema 3 binds organization, office, claim and decision tables; new process state must join that owner and its reset/migration lifecycle.

## Causal contract

| Stage | Producer and retained evidence | Consequence |
| --- | --- | --- |
| Raise a matter | A person's observed need, received request, disputed obligation or experienced failure; retain exact private source references and county time. | An issue and optional proposal become available to that person. People may act alone, seek help or defer. No group or office is created by the issue. |
| Contact and convene | Actual addressable recipient, known/reachable place or supported channel; travel and delivered-message receipts. | Record arrival and reception separately. Invited, affected, present and informed are different sets. |
| Respond | Each person's own knowledge, stakes, current activity, competence, relationships and applicable constraints enter the existing decision path. | Accept, qualify, counter-propose, decline, defer, contest or leave a request unanswered. Response history remains person-owned and versioned. |
| Establish responsibility | A proposal revision and actual responses identify jurisdiction, participants, limits, review/expiry conditions and any existing procedure invoked. | Commitments and recognized decision rights affect only their recorded scope. Multiple holders and competing claims remain representable. |
| Perform and reconsider | Execution owner revalidates current ability, access, materials and authority; actual work or refusal supplies a result. | Completion, partial work, failure and withdrawal have distinct consequences. Repeated cooperation may support later recognition; no count automatically creates an institution. |

These are causal stages, not a mandatory ceremony or one global state machine. A conversation can be brief; a contested process can have simultaneous proposals, absent participants and continuing work. No response is inferred from silence, proximity, group membership or a timer. Expiry records expiry. A recognized procedure can prescribe how a matter is decided; its mandate and actual participation must be evidenced before it can bind others. The first unit supplies limited voluntary coordination and contention; unsupported procedures remain explicit outstanding work.

Proposed durable process fields: process ID, subject and scope, originating evidence, creation/update county times, proposal revisions, referenced participants and their separately recorded roles, intended/actual places, communication receipt references, person responses, resulting commitment/claim references, work references and closure reason. Each transition has an event ID, actor, revision, time and evidence. Keep large payloads in their existing owners and link them. Persist data only; runtime handlers re-register after load. Bound completed-process retention by explicit archival policy while retaining references needed by active obligations; do not silently discard unresolved obligations.

The process record is authoritative world history. Actor-facing views contain only events acquired by that person. A change to a proposal requires a new revision; previous assent cannot silently approve changed terms. Receiving words, accepting authority and completing work are independent facts. Coerced compliance and recognition remain distinguishable.

## Owners and integration

| Owner / paths | Required changes and consumer |
| --- | --- |
| SAO_Organization.lua; SAO_GraphPersistence.lua | Own durable processes, scoped commitments and claim/response revisions. Bind, reset, migrate and serialize through the existing graph store. Prevent existing claim/decision key reuse from erasing relevant history. |
| SAO_Standing.lua; SAO_Recognition.lua; SAO_Command.lua | Replace automatic succession, roster recognition and schism with matter/response producers. Consume jurisdiction-specific authority in command decisions. Group/form summaries read actual arrangements. Audit every caller, including joins, deaths, leaves and the harness. |
| SAO_Communication.lua; SAO_Exchange.lua; SAO_Knowledge.lua | Produce admitted reception and person-private process knowledge. Resolve the current body through its registered execution owner. Use native loaded access and evidenced dormant access. Avoid treating generic message delivery as assent. |
| SAO_Controller.lua; SAO_DormantPopulation.lua; SAO_Gesture.lua | Initiate from real needs/conflict and run approach, attendance, response, owned work and interruption. Gestures reflect present acts. Dormant passage uses the same requirements and county clock. |
| SAO_SourceUse.lua; SAO_Provisioning.lua; existing handover owner | Reuse exact-source approach, acquisition and delivery results. Audit the concrete handover paths before extending. A commitment references the actual operation and consumes its completion once. |
| ZAO_Controller.lua; ZAO_Crossed.lua; ZAO_Mind.lua; existing body/brain owners | Supply actor-private inputs, supported responses and executable activity under the current ZAO owner. Repair the first unit's missing Crossed execution path rather than classifying it as a permanent restriction. Audit kin knowledge and target treatment before capturing examples. |
| Speakeasy decisions contract, cross-module reader, task views and continuation | Preserve full event namespace and producer ownership. Extend actor/executor attribution where needed; carry unknown/unavailable state explicitly. Produce inspectable scene comparisons with independent input and outcome horizons. |

File names above identify responsibilities, not permission to create redundant owners. Before editing, enumerate actual producers, callers, persistence, observation, tests and gaps for each change. A helper may organize a domain's implementation; it must not introduce another social planner or controller.

## Character depth and ownership

| Concern | Survivor | Afflicted | Crossed |
| --- | --- | --- | --- |
| Individual continuity | Existing identity, history, private knowledge and capabilities. | Same living identity; ZAO supplies actual pathogen and brain effects. | Retained identity/history and acquired knowledge survive within applicable constraints; ZAO owns execution. |
| Participation | Personally evaluated proposal, responsibility, refusal and reconsideration. | Equivalent evaluation depth using actual current capacity and relationships. | Equivalent causal depth through supported cognition, drives and communication; implement missing response/action producers. |
| Work and consequences | Native acquisition, travel and delivery with completion receipts. | SAO executes the living body; avoid duplicate ZAO controller effects. | ZAO executor must perform the unit's supported work and preserve exact results, possessions and interruptions. |
| Physical expression | Present actor and current action determine motion/gesture. | Current condition modifies execution where supported. | Representation and retained capability determine expression; actor category alone is not an incapacity rule. |
| ML record | Private evidence, executable options, selection and result. | Include actual ZAO effects without revealing unknown diagnosis. | Capture the Crossed actor's own choices and outcomes, as well as living observers' separately acquired evidence. |

Identical choices, eloquence, success rates or political arrangements are not required. Equivalent depth requires a causal path with individuality, alternatives and consequences. Every claimed restriction must cite the applicable established state contract; every missing producer remains an implementation gap. Preserve intentional Crossed-to-Afflicted exposure and the established non-feeding relationship. No spontaneous conversion rule is introduced.

## Continuity and migration

Loading reconstructs the current process and participants from actual positions and state. It does not teleport invitees, replay a completed meeting or mark all affected people informed. Offscreen simulation requires feasible movement, time, communication and current capability; blocked travel or unavailable source state remains blocked or unknown. A coarse update cannot finish work whose prerequisites were never met.

Save/reload and loaded/dormant handoff preserve active work, proposal revision, delivered/unreceived messages, responses, dissent and consumed-result IDs. State transitions route through the existing SAO/ZAO ownership transaction. One current executor controls a body; another owner cannot consume the same work result again.

Legacy leaders, memberships, claims and completed records retain their saved identity with legacy provenance. Migration does not manufacture historical ballots or endorsements. New authority effects must distinguish inherited claims from evidenced scope. Vacancies and disputes enter the live process rather than choosing a replacement by trust sum. A consumer still requiring one leader needs an explicit compatibility path that preserves unresolved authority; hiding the old election behind an adapter is not acceptable.

Implement representation and persistence together with the first producer. Do not publish an intermediate unit that merely disables social behavior while its replacement remains uncalled.

## Acceptance evidence

| Comparison | Required observation / control |
| --- | --- |
| Local meeting and absent members | Only actual recipients gain the proposal; two attendees cannot elect for an entire roster. Restoring roster recognition must fail the check. |
| Conditional agreement | A delivery-specific commitment cannot authorize unrelated commands; revised terms require a new response. Restore scope omission and the check must fail. |
| Shared and contested authority | Concurrent scoped responsibilities coexist; refusals persist and affect that person's conduct. Neither highest trust nor a disagreement count installs a leader or creates a feud. |
| Social consequence and work | Accepted feasible coordination reaches acquisition/travel/delivery; refused or undelivered requests do not. Interrupted work retains partial physical state and supplies no completed credit. |
| Separation | Expressed withdrawal changes the relevant commitment/membership through its owner; physical departure requires actual movement. Relationships and hostility change only through their own evidenced causes. |
| Work against danger | Hold current work fixed and vary an observed actionable danger, an old contact and unavailable information. Demonstrate continuation, justified interruption and resumption; low competence remains within human behavior. |
| Representation and saves | Change loaded/dormant boundaries and timestep partition, save mid-process and reload. No invented attendance, replayed decision, duplicate result or lost disagreement. Include actor ownership change. |
| Actor coverage | Run supported production paths for survivor, Afflicted and Crossed with distinct person histories. Missing Crossed work or response execution prevents first-unit completion. |
| Configuration and ML | Standalone, ZAO disabled and combined enabled; missing enabled-run ZAO data is not healthy baseline. Hidden pathogen truth and another actor's knowledge cannot leak into task inputs. Include optional effects present/absent only where actually supported. |

Validate shipped Lua/Java paths with discriminating defect controls, installed-engine checks, compilation/package checks and required repository gates. Speakeasy joins and task readers get specific controls for wrong person, stale revision, impossible option, hidden truth and outcome leakage. Human-facing examples show situation, active work, available choices and consequence before supporting detail. Authored labels and synthetic starting conditions are explicitly identified.

Mechanical acceptance, unattended native execution and operator gameplay judgment remain separate evidence levels. The user's desktop restriction remains active: no window opening, focusing, game launch or UI control. Use background verification and report any unobserved loaded-world behavior explicitly. Do not request a play session as a prerequisite.

## Closure and further direction

After approval, synchronize ORGANIZATION.md, SUBSTRATE.md, ROADMAP.md and SESSION_STATE.md with the implemented scope and Speakeasy Record 62; extend append-only records appropriately. Publish a closed implementation unit with source, evidence and the actual ruling under each repository's publishing discipline. Planning artifacts remain local until that unit.

The next dependency track continues native perception and competing activity across broader work/combat, then material development and richer institutional procedures, while complete bounded captures can feed ML earlier. No unit may use this sequencing to defer all Afflicted/Crossed producers to an unspecified extension pass. Later learned execution must be evaluated across the combined simulation as well as standalone compatibility.

Return for revision if a required Crossed action needs a materially different representation contract, if a new political rule is needed beyond the approved scope, or if migration would discard durable identity or evidence. Routine implementation choices and repairs within this scope proceed without reopening settled direction. Report missing mechanisms concretely instead of calling storage, tests or a demonstration scene full simulation completion.
