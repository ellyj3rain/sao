| Document | Survivor Awareness Overhaul Representation Contract |
|---|---|
| Version | `4.2.4.5-pre-alpha` |
| Author | ellyj3rain |
| Repository | `REPRESENTATION.md` |
| Status | CANONICAL - what the county represents and which state carries each part. |

# Representation contract

This file states what Survivor Awareness Overhaul represents and how the tree's
current facts serve that target. It is written from the operator's direction on
2026-09-10.

The whole-system branching model is defined in
[BRANCHING.md](BRANCHING.md).

If a feature needs a fact this file does not name, this contract is extended
before the feature is built.

## The target

Survivor Awareness Overhaul represents a living county under survival pressure.
A person carries a body, a history, habits, skills, beliefs, relationships,
culture, politics, and whatever organizations form around them.

The game has no success state. It produces the next action for each person from
that person's own state and the pressures reaching them. Survival is the
setting and the source of pressure. It is not the model's objective.

The causal order is:

```text
pressure -> person -> relationship and material state -> action -> pattern -> organization
```

1. Pressure arises from need, threat, scarcity, injury, grief, addiction, or
   exposure.
2. It reaches a particular person because of where they are, what they know,
   what they can do, and who they are.
3. The person's traits, habits, skills, relationships, and available means
   decide the response.
4. The action happens through the engine.
5. If the same action repeats under the same pressure, a pattern appears.
6. An organization may later recognize, assign, elect, or formalize that pattern.

A settlement is one kind of organization. Work is one kind of action. Neither is
the objective of the simulation.

## What the game must answer

| Question | Answered by |
|---|---|
| Who is this person? | identity, body, age, sex, conditions, habits, lessons, census |
| What pressure are they under? | needs, threat, injury, infection, addiction, weather, time |
| What do they know? | private beliefs with provenance and age |
| What can they do? | skills, health, available tools, available ground |
| Who matters to them? | trust, bonds, obligations, grievances, kinship, authority |
| What is physically possible? | places, claims, stock, fire, water, tools, daylight |
| What do they do next? | the current action selected from pressure and state |
| What labor is possible? | capacity, pressure, obligation, material, project, organization |
| What do they do with ease? | disposition, habits, culture, relationships, available space |
| What pattern, if any, forms? | repeated action under the same pressure |
| What organization, if any, appears? | recognition or assignment of a pattern by a group |
| What claim is being made, and who recognizes it? | office, membership, resource, role, bond, recognition, response |
| What can the player do here? | membership, office, standing, pressure, available action |
| How does the player speak to a survivor? | free-form text or dictation, read by the understander and answered by the speaker |

## Existing state surfaces

The tree already carries the material for this contract. Most surfaces are
coarser than the target. A trust number is one fact about a relationship. A
claim is one fact about territory. A creed is one fact about culture. A
designation is one fact about repeated work. Each is useful and incomplete.

| Existing surface | What it stores | What it represents | Causal rule |
|---|---|---|---|
| [SAO_Identity.lua](mod/42.20/media/lua/shared/SAO_Identity.lua) | id, name, sex, position, created and updated time, death facts | the durable person | owns stable identity; never assigns behavior |
| [SAO_Body.lua](mod/42.20/media/lua/client/SAO_Body.lua) | active shell, pack, clothes, physical state | the body the record occupies | owns material presence; never decides why an action happens |
| [SAO_Perception.lua](mod/42.20/media/lua/shared/SAO_Perception.lua) | private beliefs about zombies, people, factions, and places | what this person has perceived or been told | only admitted beliefs may be read; map truth never enters a decision |
| [SAO_Disposition.lua](mod/42.20/media/lua/shared/SAO_Disposition.lua) | five trait numbers and a wanted circle | temperament and social appetite | shapes a response; never invents facts or permission |
| [SAO_Conditions.lua](mod/42.20/media/lua/shared/SAO_Conditions.lua) | condition sets and drift | mind and body state | changes latency, memory, learning, and perception; never widens the human envelope |
| [SAO_Habits.lua](mod/42.20/media/lua/shared/SAO_Habits.lua) | gained and quit habits, drink clocks | personal behavior and addiction | creates recurring pressure; never assigns a job |
| [SAO_Census.lua](mod/42.20/media/lua/shared/SAO_Census.lua) | occupation, class, skills, outfit | background and capability | informs what a person can do; never fixes what they must do |
| [SAO_Lessons.lua](mod/42.20/media/lua/shared/SAO_Lessons.lua) | key-to-weight survival knowledge | lived experience | shapes choices; never creates facts |
| [SAO_Knowledge.lua](mod/42.20/media/lua/shared/SAO_Knowledge.lua) | nine topic claims | what a person can say or reason about | read-only projection; never drives behavior directly |
| [SAO_Standing.lua](mod/42.20/media/lua/shared/SAO_Standing.lua) | trust, hostility, bonds, groups, claims, group metadata | relationships, territory, and organization | permits or refuses action; never decides what a person wants |
| [SAO_Command.lua](mod/42.20/media/lua/shared/SAO_Command.lua) | office, proven hand, obedience | authority | decides who may direct whom; never invents desire |
| [SAO_Exchange.lua](mod/42.20/media/lua/client/SAO_Exchange.lua) | meeting behavior between two people | direct social contact | consumes perception and standing; never creates them |
| [SAO_Places.lua](mod/42.20/media/lua/shared/SAO_Places.lua) | offers, bounds, room count, taken count, refill clock | the material world | enables action; never assigns purpose |
| [SAO_Claims.lua](mod/42.20/media/lua/shared/SAO_Claims.lua) | held and released ownership records | possession and territory | permits or refuses use; never creates social meaning |
| [SAO_Voice.lua](mod/42.20/media/lua/client/SAO_Voice.lua) | event lines | expression | renders a decision; never makes one |
| [SAO_Gesture.lua](mod/42.20/media/lua/client/SAO_Gesture.lua) | animations, seats, tunes, dances | visible expression | renders a decision; never makes one |
| [SAO_Controller.lua](mod/42.20/media/lua/client/SAO_Controller.lua) | action state and pressure answers | execution | moves the body; never chooses the reason |
| [SAO_Needs.lua](mod/42.20/media/lua/client/SAO_Needs.lua) | hunger, thirst, wounds, gear, water, warmth | survival pressure | initiates action; never defines the person |
| [SAO_Medical.lua](mod/42.20/media/lua/client/SAO_Medical.lua) and [SAO_Course.lua](mod/42.20/media/lua/shared/SAO_Course.lua) | wound readings and infection course | the body over time | changes pressure; never sets an outcome objective |
| [SAO_History.lua](mod/42.20/media/lua/shared/SAO_History.lua) | outbreak, clock, calendar, record day | world time | orders events; never assigns goals |
| [SAO_Telemetry.lua](mod/42.20/media/lua/client/SAO_Telemetry.lua) | events, county lines, run state | evidence | observes the county; never drives behavior |
| [SAO_Population.lua](mod/42.20/media/lua/client/SAO_Population.lua) | dormant day, meetings, movement, places | off-screen life | simulates pressure and movement; never assigns a result |

## The overconcentrated surface

`designation` currently stores one of a small set of work words. In the
representation target, a work word names a repeated pattern of action.

Today the same string also causes controller behavior, study choices, rationing,
and command standing. That is the defect: one field is carrying the whole work
and organization layer.

The correction is to derive work from pressure, ability, relationship, and
material state. A work word may remain as a label after the pattern exists. An
organization may assign or elect that label. The label itself does not create
the behavior.

## Absence and solitude

A survivor may know of nobody and want nobody nearby. That is a complete
behavior mode.

The state is explicit:

```text
knownPeople: []
socialOrientation: solitary or avoid
```

That person still has a full day. They eat, drink, sleep, heal, scavenge,
build, read, hide, patrol, follow a habit, or rest. Other people are optional
inputs, and social behavior is additive.

## Work and organizations

Work is a response to pressure and capability. A person cooks because food,
fire, skill, and trust are present. A person watches a road because threat,
position, nerve, and relationships make that the action they take. A person
forages because hunger, knowledge, ground, and ability meet.

A role is the name a household gives to a pattern after it repeats. A
settlement is a group that recognizes patterns and may assign or elect work.
The settlement exists because pressure and people produced it.

The organization and deference model is defined in
[ORGANIZATION.md](ORGANIZATION.md).

## Labor, surplus, and ease

Labor is broader than the current five work words. A settlement can require
construction, maintenance, farming, hauling, sanitation, repair, medicine,
teaching, childcare, cooking, trade, logistics, governance, security,
ceremony, art, memory work, and study. Some of those are recurring tasks. Some
are projects. Some are occasional obligations. Some are choices a person makes
because they enjoy the work or because the group values it.

The labor model must answer eight things:

1. What is needed now?
2. Who is able to do it?
3. Who has a claim on this person's time?
4. What materials and space are available?
5. What project or maintenance work is open?
6. What does the group value or require?
7. What does this person want to do when pressure is low?
8. Is there slack in the settlement?

Ease is a valid state. A person may sit, talk, play, study, wander, rest,
grieve, or choose work because they want to. A settlement with no slack cannot
rebuild, because rebuilding requires surplus, choice, and work that is not
immediately forced by survival.

The five current work words point at a few recurring survival activities. They
are not the settlement's complete labor model, and a person is not always
looking for one of them.

## Boundaries

These exclusions protect the representation target:

- The model does not optimize for survival, settlement success, or completion.
- A role label does not define a person.
- A trust number does not replace a relationship.
- A group name does not replace membership reasons.
- A claim rectangle does not replace the meaning of a place.
- A creed word does not replace culture.
- A voice line does not replace personality.
- Other people are never assumed to be known or desired.
- A closed job list is never the person's option space.

## Dataset consequence

A row records the person, the pressure, the available means, the relationships,
the culture and politics, and the action taken.

The label is the next action. Survival is the setting. An empty person-belief
set and a solitary orientation are valid data.

If a row needs a fact this contract does not name, the contract is extended
before the row is collected.
