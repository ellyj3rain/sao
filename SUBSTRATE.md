| Document | Survivor Awareness Overhaul Dependency Substrate |
|---|---|
| Version | `4.2.4.6-pre-alpha` |
| Author | ellyj3rain |
| Repository | `SUBSTRATE.md` |
| Status | CANONICAL - what exists, what is planned, and what each area of concern needs. |

# Dependency substrate

This file maps the substrate the three repositories stand on, what each planned
area of concern needs, and what remains independent. It is not a schedule.

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
| ZAO | design and engine evidence for the turned; no mod code yet |
| Speakeasy | dataset source, world documents, corpus, voice material, training plan; no models yet |
| SAO tools and borders | verification, county sweeps, dataset captures, deploy and build machinery |
| External mod catalogue | optional inputs, compatibility targets, art and mechanics sources |

## Planned substrate

| Layer | Planned role | Dependency shape |
|---|---|---|
| ZAO mod | owns the turned body and pathogen state | optional add-on; reads SAO where present, runs whole where absent |
| ZAO claim surface | lets other mods ask who owns a body | public contract decision still open |
| Recovery mods | antibody, cure, recovery, and repeat-infection inputs | optional inputs, never requirements |
| Speakeasy models | understander and speaker for free-form conversation | port into SAO; no code crosses |
| In-process inference | models run in SAO's Java jar | pure Java, self-contained, no service |
| Optional sidecar | larger local models for players who opt in | optional; never required for the base mod |
| Branching graph | one state-pressure-action graph across all concerns | SAO state surfaces plus Speakeasy decision models |

## What makes what possible

| Area of concern | Current substrate | Still needed |
|---|---|---|
| Isolation | person record, perception, `contactFactor`, wanted circle | live isolation spectrum and its effect on choices |
| Place attachment | known places, claims, home, visits, place offers | place-use ranking and attachment state |
| World development | claims, larders, hearths, water stores, motor pools, construction, farming | project choice, material inventory, and development branch |
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
| SAO to ZAO: afflicted and crossed | shaped | SAO executes the afflicted; ZAO owns pathogen state and executes the crossed |
| SAO to Speakeasy: dataset | rows exist; models do not | SAO supplies people and moments; Speakeasy supplies rows and models |
| ZAO to Speakeasy: degraded cognition | named, not built | waits until ZAO's record reaches a turned body with provenance intact |

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
