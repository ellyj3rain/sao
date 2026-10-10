| Document | Survivor Awareness Overhaul Core |
|---|---|
| Version | `2.6.8.0-pre-alpha` |
| Author | ellyj3rain |
| Repository | `CORE.md` |
| Status | ACTIVE - genesis identity for this project. |

# Survivor Awareness Overhaul â€” core

**Survivor Awareness Overhaul** is a Project Zomboid Build 42 NPC framework, not a
survivor mod with better scripts. Survivors act on personal observations,
acquired knowledge, ordinary-life priors and defeasible conceptual inference.
DR-056 ratifies associations among situations, objects, activities and effects
as a basis for anticipating possibilities and investigating what remains unknown.
Particular local facts retain their acquisition source; inferred possibilities
retain their uncertainty. They are durable inhabitants of Knox County with their own
positions, intentions and histories, and they persist whether or not the player
is looking at them.

The design objective is survivor competence sufficient that the player relates to
them as people with intentions, not as props that demonstrate the mod is running.
Skill governs latency, precision, breadth and coordination. **Low skill never
licenses behavior no human would produce** â€” a poor survivor is slow, wasteful and
badly positioned; a poor survivor does not smash an intact window to enter a house
occupied by someone aiming at the opening.

## Identity

| Field | Value |
|---|---|
| Display name | Survivor Awareness Overhaul |
| Project key | `sao` |
| Mod id | `SurvivorAwareness` â€” **stable**; changing it breaks existing saves |
| Target | Project Zomboid Build 42.20 |
| Author | ellyj3rain |
| Sibling ground truth | the installed `projectzomboid.jar` and `media/` script + Lua tree |

The local project tree is canonical. Its governed batch and provenance records are
the portable project history.

## Canonical composition

Every behavior is the composition:

`Perception admits â†’ Disposition decides â†’ Standing channels â†’ Execution acts`

Four separate substrates, each with its own model, projecting into the game's
native machinery. `ARCHITECTURE.md` holds the ratified shape.

| Pillar | Owns | Does not own |
|---|---|---|
| Perception | survivor-private typed facts, provenance, sightlines, sound, memory decay, uncertainty, what was told and by whom | map truth the survivor has not observed, automatic permission |
| Disposition | nerve, discipline, aggression, initiative, trust, self-preservation; willingness and risk texture | facts, permission, physical execution |
| Standing | relationships, group membership, orders, territory claims, hostility state, who may command whom | tactical execution, invented knowledge |
| Execution | movement, entry, combat, looting, work, treatment, withdrawal | global truth, personality, relationship state |

Person-owned knowledge supports this four-pillar composition. It retains general
and learned associations with provenance; bounded inference proposes possible
means and unresolved questions. Perception supplies particular acquired facts,
Disposition and accepted purposes determine what matters, Standing governs
permission, and Execution owns the physical attempt and its result. A house can
suggest a bedroom and a bed without establishing that either exists at a local
coordinate. Observation and experience can refine those expectations.

Execution ships first and rides the engine's native substrate. The other three are
what make this a framework rather than a behavior list.

Every integrated mod mechanic becomes SAO-owned behavior under this composition.
Installed sources supply useful scaffolding and ideas; SAO adapts their mechanics,
state and effects to its own person, decision, Standing, execution and persistence
owners. This is the standing rule unless the operator changes it (DR-058, DR-060).

## Governing constraints

- **Verified APIs only.** Ground truth is the installed game â€” the decompiled
  `projectzomboid.jar` and the shipped `media/lua` and `media/scripts` trees.
  Engine behavior is never asserted from memory. A claim without a file and line
  behind it is a hypothesis, and is labelled as one.
- **The engine's own seams.** `IsoPlayer.setNpc(boolean)`,
  `AIComponent.getHumanControlVars()`, `SpawnRegionMgr.getSpawnRegions()`, normal
  inventory and equipment paths, normal timed actions. Override only where no seam
  exists.
- **A survivor is a person, not a shell.** Identity is a persistent record. The
  engine object is a temporary body that exists while its cell is loaded and is
  never the save entity.
- **No omniscience, no oblivion.** Particular local facts come from personal
  acquisition. General knowledge and defeasible inference can motivate inquiry
  without manufacturing observed rooms, contents, coordinates or permission.
  Ignoring a perceived threat and acting on fabricated local facts are both faults.
- **Declarations are promises.** Settings copy and in-game text match shipped
  behavior exactly.
- **Author causes, inspect consequences.** Simulation depth does not justify
  exposing every analytical category as a player control.

## Relationship to Colonist Awareness Overhaul

This project shares its methodology with `../colonist-awareness` â€” the pillar
composition with explicit *does not own* boundaries, the governed doc-pack, batch
discipline, and the constraint that low skill must not license inhuman behavior.
Both are the same author's work and the structures are common to both.
