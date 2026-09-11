| Document | Survivor Awareness Overhaul Branching System |
|---|---|
| Version | `4.2.7.0-pre-alpha` |
| Author | ellyj3rain |
| Repository | `BRANCHING.md` |
| Status | CANONICAL - the whole simulation's branching model. |

# Branching system

This file defines the shape of the whole simulation. Labor, organization,
deference, communication, and player interaction are projections of one
branching graph. They are not separate systems that happen to touch.

## The model

The simulation is a branching graph of state, pressure, and action.

```text
state surfaces -> pressure -> branch candidates -> weighted selection -> action -> consequence -> state update
```

Every state surface feeds the graph. Every action writes back into it.

## What a branch is

A branch is a causal path through the county's state.

It begins when pressure reaches a person and ends only when its consequence has
been written back into the world. A branch can continue, fork, merge, reverse,
specialize, become routine, or stop.

A branch is not a job title, a fixed role, or a menu option.

## State surfaces

| Surface | Role in the graph |
|---|---|
| Person | branch capacity |
| Perception | branch visibility |
| Material | branch availability |
| Relationship | branch weight |
| Organization | branch authorization |
| Action | branch execution |
| Communication | branch negotiation |
| Player | branch perturbation |
| Telemetry | branch evidence |

These are the same state surfaces named in `REPRESENTATION.md`. The graph is
what connects them.

## Gradients and dials

Every branch carries spectrums, not binaries:

- urgency
- skill
- fatigue
- enjoyment
- obligation
- risk
- available material
- social recognition
- authority

The same pressure can open different branches for different people. The same
person can follow a different branch tomorrow because their body, knowledge,
relationships, or material state changed.

## Emergence and recognition

A repeated branch can become a pattern. A pattern can be recognized as a role.
A role can gain jurisdiction and become an office. An office can change which
future branches are authorized, forbidden, funded, or contested.

That is the whole chain:

```text
branch -> pattern -> role -> office -> organization
```

No step in that chain creates the ability to do the work. It records, authorizes,
or contests what pressure and capacity already made possible.

## Player interaction

The player perturbs the graph.

The player may speak, petition, support, contest, provide, assign, refuse, or
leave. Every player action is a claim. The model records the claim, its
recognition, and the response.

The intended interface is free-form conversation. A menu may expose a known
action, but speech is the primary surface.

## Boundaries

These exclusions protect the model:

- Do not reduce the graph to a fixed job list.
- Do not treat a branch as a role.
- Do not treat a role as a person.
- Do not treat recognition as authorship.
- Do not treat authority as ability.
- Do not encode success or completion.
- Do not make the player the center of every branch.
