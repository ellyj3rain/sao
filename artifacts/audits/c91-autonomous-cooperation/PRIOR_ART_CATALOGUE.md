# C91 cooperative action prior-art catalogue

Recorded against SAO `070d3fdc404c520c80243c864277ebdf514dbc4c`.
This catalogue covers cooperation in material work and in strategic movement,
positioning and action. It records mechanisms and transfer limits; it does not
make any observed scenario a training rule.

## Revisions examined

| System | Revision | Licence | Examined surface |
|---|---|---|---|
| OpenXRay A-Life | `b8c995cbb4f02826057d0f5b34112fdd8a645511` | MIT for OpenXRay changes; upstream game terms also apply | `alife_update_manager.cpp`, `alife_schedule_registry.cpp`, `alife_switch_manager.cpp`, `alife_online_offline_group*.cpp`, `stalker_alife_planner.cpp`, `stalker_alife_task_actions.cpp` |
| Living Fellows | `10436068ca32ba953d821ba8145ba70bdbff459f` | MIT | `SCActionSupervisor.lua`, `SCProduction.lua`, `SCGatherWork.lua`, `SCWorkTransport.lua`, `SCFarmWork.lua`, persistence and architecture records |
| Colonist Awareness | `099313efab97d85c3fd24753304765a3aca7591b` | GPL-3.0 | `BehaviorIntentModule.cs`, `BehaviorCatalogModule.cs`, `AuthorityModule.cs`, `SettlementProgramRuntimeModule.cs`, `SettlementProgramMaterializerModule.cs`, `AutonomousHomeModule.cs` |

No source is copied into SAO. The catalogue transfers architectural methods
through SAO's existing owners and Project Zomboid's native actions.

## Mechanisms

| Concern | A-Life | Living Fellows | CAO | SAO adaptation |
|---|---|---|---|---|
| Bounded simulation | `CALifeUpdateManager::update` separates switching from scheduled updates; `objects_per_update` and the configured process-time bound limit each pass. The schedule registry admits only objects that report a need to update. | Scans retain cursors and explicit square/object budgets. Blocked production rechecks on a cadence instead of spinning. | Planning and observation modules run on bounded map cadences and retain exact pending identity between passes. | Rotate cooperative matters, people and runnable steps under explicit per-pass budgets. A delayed update changes latency, never what a person is allowed to know or what work counts as complete. |
| Loaded/dormant continuity | `CALifeSwitchManager` and online/offline group code preserve one world object identity while changing representation. Group switching checks members, synchronizes location and reconstructs membership after load. | Durable orders and receipts contain scalar identity; runtime Java objects are rebuilt only from native postconditions. | Owned intent persists origin, authority, termination condition and exact pending native work. | The Organization procedure and each person-private projection remain durable. Controller, dormant simulation and external owners consume the same commitment; representation change cannot complete, duplicate or reassign a step. |
| Group movement | The online/offline group brain follows the current smart-terrain task through the movement manager. Online stalkers turn the same task into concrete game- and level-path destinations. | Work routes, personal-space reservations and choke leases keep actors from fighting over the same square. | Coordinated withdrawal and rescue support preserve an episode, actor-specific authority and native movement ownership. | A strategic procedure expresses actor-specific movement and posture steps. A later step can depend on several arrivals, forming a real synchronization barrier. Each route remains owned by Locomotion and completed by its exact receipt. |
| Division of action | A-Life separates group-level task continuity from the online actor's local planner and movement execution. | Production orders retain assigned workers separately from historical receipt actors. Quota reservations prevent two workers from consuming the last unit. | Runtime resolution requires a real operator, eligible workers and live assets before materialization. | Participants volunteer, qualify, counter-propose, refuse or withdraw. Accepted terms claim bounded procedure steps; capacity and capability are checked at the claim. A shared procedure never makes membership equivalent to assignment. |
| Action ownership | Online actions use planner conditions/effects and explicit initialize, execute and finalize boundaries. | `SCActionSupervisor` admits one actor-wide owner, legal phase transitions, urgent preemption at checked boundaries, exactly-once commit receipts and postcondition verification. | `TryAuthorizeAndRegister` authorizes before registering a native job; the behavior catalog checks knowledge, authority, capability, materials and current intent separately. | Organization records social scope and step claims. Existing SourceUse, Locomotion, Cooking, Handover and future native owners still admit and verify the actual action. Procedure state consumes their receipts and never performs the effect itself. |
| Failure and revision | Failed switching leaves the object in its prior representation; task selection remains separate from movement failure. | Wait, blocked, failed, cancelled, recovery and quarantine are distinct. Retry requires time or changed evidence; save/load reconciliation proves the native postcondition before advancing. | An owned intent has a termination condition and can end when knowledge, authority, material or capability no longer holds. | A failed attempt marks the actor's claim and private projection, records why the enacted step remains incomplete, and opens a revision need. Reallocation or a revised graph requires another communicated proposal and response; failure never silently assigns someone else. |
| Completion | Smart-terrain movement resolves against the task destination rather than planner narration. | Trees, planks, graves, bodies and cargo count only after world and inventory postconditions are reproved. | Materializers measure a deficit, place native work, then inspect the resulting structure. | Completion tokens are emitted only by native owners. Multi-actor steps retain one contribution per actor and complete only when the declared participant threshold is reached. |

## Strategic cooperation vocabulary

The procedure graph is domain-neutral. Material work is one use. Strategic
cooperation uses the same causal shape:

| Step family | Examples | Required evidence |
|---|---|---|
| Move | assemble, withdraw, flank, escort, carry, rendezvous | actor-owned route admission and exact arrival; destination was available to that actor |
| Posture | hold, watch, cover, conceal, rest, treat | native action or bounded maintained-state receipt from the owning subsystem |
| Synchronize | wait for two arrivals, hand off an item, cover a crossing, regroup after contact | distinct actor contributions or completion of named dependency steps |
| Act | acquire, prepare, deliver, breach, rescue, patrol, investigate | exact native result and current authority/capability/material checks |
| Reconsider | abort, re-route, swap roles, narrow objective, request help | observed failure or changed evidence plus a communicated revision and fresh participant responses |

A strategic procedure may therefore contain parallel actor-specific movement
steps, a dependency barrier, and later posture or action steps. It does not need
to collapse the group into one A-Life-style aggregate body. The aggregate is a
scheduling aid and a durable shared objective; people retain separate locations,
perception, commitments and ability to dissent.

## Transfer boundaries

OpenXRay's aggregate group location and smart-terrain assignment are useful for
continuity and scheduling, but cannot replace SAO's private knowledge or
individual physical bodies. Living Fellows' player-created production orders
are strong execution prior art, but C91 needs survivor-originated proposals and
role negotiation. CAO's catalog and settlement runtime are strong authorization
prior art, but its RimWorld stock queries, calibrations and institutional
authority cannot establish Project Zomboid facts.

SAO retains these owners: Organization for durable social process and enacted
procedure truth; Communication for acquisition of proposals and returned
responses; Cognition and CognitiveModels for person-private interpretation;
Controller and registered external executors for actor decisions; Locomotion,
SourceUse, Cooking, Handover and other action families for native work;
GraphPersistence for saves; Observation for read-only operator evidence.

## C91 implementation consequences

1. Extend procedure steps with bounded role, domain, participant capacity,
   target and posture metadata while preserving the acyclic dependency graph.
2. Record actor-specific step claims from accepted response terms. Capability
   for one role must be enough to participate in a cooperative proposal; no
   person has to possess every capability in the whole procedure.
3. Count exact actor contributions for multi-person synchronization steps.
4. Preserve failed and released claims, bounded retry evidence and a visible
   revision need. Reallocation requires a new claim; changed terms require a
   new proposal revision and response.
5. Join native cooking completion to preparation. Preserve locomotion arrivals
   as first-class strategic movement evidence and admit future posture/action
   tokens through the same exact receipt boundary.
6. Expose the enacted graph, role claims, actor-private next step, blockers and
   revision reason in Mousecat. Scenario observations remain review material,
   not automatic dataset admissions.
