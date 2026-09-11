| Document | Survivor Awareness Overhaul Organization and Deference Contract |
|---|---|
| Version | `4.2.6.0-pre-alpha` |
| Author | ellyj3rain |
| Repository | `ORGANIZATION.md` |
| Status | CANONICAL - organization, hierarchy, offices, governance forms, and deference. |

# Organization and deference

This file defines the model for organizations, offices, governance forms, and
deference. It does not specify a fixed role list, a UI vocabulary, or a
settlement objective.

The whole-system branching graph is defined in [BRANCHING.md](BRANCHING.md).

## What an organization is

An organization is a durable group with members, a decision method, and a
boundary. A household, company, settlement, faction, coalition, council, or
work crew can be an organization.

An organization is a result. It appears after people repeatedly act together,
recognize that pattern, and create or accept a way to decide together.

The causal order is:

```text
pressure -> repeated action -> recognized pattern -> office -> organization
```

## What an office is

An office is a decision right, not a person.

An office has:

- a jurisdiction: what it may decide
- a governance form: how its authority is constituted
- a legitimacy source: why its authority is accepted
- a succession method: how it is filled, kept, transferred, or lost
- a decision record: what it has decided and on what basis
- a vacancy rule: what happens when no one holds it

An office is not a job. A job is labor. An office is authority over a matter.

## Claims and recognition

A claim is one person's assertion. Recognition is another person's acceptance.

A person may claim an office, a membership, a resource, a role, or a bond. That
claim becomes a social fact only when other people recognize it, when a recorded
institution confers it, or when coercion makes refusal costly.

The model records three separate facts:

| Fact | Meaning |
|---|---|
| Claim | what one person says or asserts |
| Recognition | who accepts it and on what basis |
| Response | what the affected person does |

For example:

- `I lead here` is a claim.
- The members' deference is recognition.
- One member's refusal is dissent.

Coercion can make a claim effective without making it legitimate.

## What deference is

Deference is a person accepting a decision from an office or from another
person acting in an office.

Deference is not unconditional obedience. It is a decision about one matter.

Deference depends on:

- the office's legitimacy
- the holder's personal standing
- the matter being decided
- the follower's own temperament
- trust or grievance between the two people
- whether another office has a stronger claim
- whether refusal is costly
- whether coercion is present
- whether an appeal or exit exists

Possible responses are:

| Response | Meaning |
|---|---|
| Accept | the person follows the decision |
| Reluctant accept | the person follows it and dislikes it |
| Ignore | the person does not treat it as binding |
| Refuse | the person says no |
| Appeal | the person asks another office or custom to overrule it |
| Contest | the person challenges the office |
| Exit | the person leaves the organization |
| Resist | the person opposes the decision openly |

## Governance forms

These forms are examples of how authority can be organized, not a fixed set of
implementation targets.

| Form | What it means | Decision shape |
|---|---|---|
| Unsettled | no stable office exists yet | whoever can persuade, coerce, or be trusted in the moment |
| Democratic | members delegate authority and can revoke it | deliberation, election, recall |
| Despotic | authority is concentrated in one person or small group | command, enforcement, succession by seizure or inheritance |
| Localist | households and neighborhoods decide most matters directly | household authority, local councils, cross-house coordination |
| Federated | local bodies share a higher body for matters that cross them | delegated representatives, assembly, compact |
| Communal | members decide together with minimal delegation | shared decisions, rotating duties, consensus |

A hierarchy is an ordering of offices. It is not a ranking of people. A person
may hold several offices. An office may have more than one holder. Authority may
overlap.

These names are analytical labels. They describe the shape of authority. They
are not self-descriptions and they are not speech lines.

No person in the county says, `I am despotic` or `I am localist`. A person says
what they actually do or expect: `I decide here`, `we vote`, `the house decides`,
`ask the council`, or `this ground is ours`.

## Player surface

Some organization facts are simulation state. Some are actions the player can
take.

The player may:

- observe an organization
- ask to join or leave
- petition a decision
- support or contest a claim
- ask for work
- accept or refuse an order
- claim an office
- call a vote where the organization allows one
- appeal to a custom or another office
- enforce or resist a decision

Each player action is a claim. The model records the claim, the recognition,
and the response. The player is not the implicit center of every organization.
An organization may ignore, refuse, or oppose the player, and it may continue
without them.

A player-facing menu names the action, not the analytical governance form. It
says `petition`, `support`, `contest`, `claim`, `vote`, or `leave`; it does not
say `despotic`, `localist`, or `communal`.

These actions are also reachable through conversation. The intended player
surface is free-form speech, not a fixed dialogue tree: the player types or
dictates what they want to say, the understander reads it against that person's
knowledge, and the speaker answers from that person's claims. A menu may expose
a known action, but conversation is the primary interface.

## Legitimacy sources

An office can draw legitimacy from more than one source:

- consent
- demonstrated competence
- custom
- election
- inheritance
- coercion
- control of a shared resource
- emergency necessity
- tradition

The same decision can be legitimate under one office and illegitimate under
another. The model must record the source rather than infer it from the
decision's outcome.

## Jurisdiction

An office's jurisdiction says what it may decide.

Jurisdiction can cover:

- territory
- membership
- resource allocation
- work assignment
- security
- dispute resolution
- external relations
- ritual and memory
- succession

An office with no jurisdiction is a title. A decision outside jurisdiction is a
personal request, not an exercise of authority.

## Succession and dissent

An office can pass by:

- election
- appointment
- inheritance
- seizure
- rotation
- consensus
- vacancy

Dissent can appear as refusal, appeal, contest, exit, passive resistance, or
schism.

An organization's health is not measured by whether it survives. It is measured
by whether its decision path, legitimacy, and dissent handling are represented
coherently.

## Current state

The tree currently has a thin organization surface:

- [SAO_Command.lua](mod/42.20/media/lua/shared/SAO_Command.lua) recognizes a
  leader, a second, a proven hand, or nobody.
- [SAO_Standing.lua](mod/42.20/media/lua/shared/SAO_Standing.lua) stores group
  membership, a leader, a creed, ration policy, government history, and claims.
- The current office model has no governance form, no jurisdiction, no
  succession method, no legitimacy source, no appeal path, no overlapping
  authority, and no localist layer.

The current leader/second model is a first approximation. It is not the final
organization model.

## Model primitives

| Primitive | Meaning |
|---|---|
| Organization | a durable group with members and a boundary |
| Membership | belonging and the obligations it creates |
| Office | a decision right with jurisdiction |
| Hierarchy | an ordering of offices |
| Governance form | how authority is constituted |
| Legitimacy | why an office is accepted |
| Deference | acceptance of a particular decision |
| Succession | how an office changes hands |
| Dissent | challenge to a decision or office |
| Decision record | the provenance of an act |
| Jurisdiction | what an office may decide |
| Coercion | authority backed by force |
| Custom | accepted practice |

## Boundaries

These exclusions protect the model:

- Do not implement a fixed list of offices.
- Do not treat a work word as an office.
- Do not treat a hierarchy as a ranking of human worth.
- Do not make deference universal or unconditional.
- Do not treat a self-declared claim as a recognized office.
- Do not use a governance label as a character's own words.
- Do not create an organization from a target.
- Do not make the player the implicit center of every organization.
- Do not treat survival or settlement success as the objective.
