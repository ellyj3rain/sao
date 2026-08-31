| Document | Direction on speech |
|---|---|
| Author | ellyj3rain |
| Repository | `SPEECH.md` |
| Source | Operator direction, 2026-08-26 (mid-[B20]) |
| Status | DIRECTION - not scheduled, deliberately. |

# Speech

## The goal

The operator's direction, paraphrased: you can type almost anything
to an NPC - or dictate and speak - and actually communicate. They
understand you even when what you say is not obviously grounded in
the game. Not a canned response: the capability to examine each
piece of information as it stands and, from the knowledge generated
for them beforehand, produce an answer that could only have come
out that way once.

And the reason it matters: then the game is fun beyond watching
them.

## The hard problem is not generation

Fluent text is the easy half. The hard half is that an NPC can only say
what that specific person actually knows - in their own voice, with the
right confidence and the right staleness - and must be structurally
incapable of inventing the rest.

That is the subject of the derivation work. A survivor already holds:

- a census-derived past - occupation, class, region, real skill levels
- beliefs with provenance - `observed` / `heard` / `told`, the teller
  named, positions that are memory rather than truth, and `presumed`
  flags where fear filled a gap ([A28])
- lessons with weights and dates, so "when did you learn that" has an
  answer
- relations carrying trust, hostility, debts, promises, whether they
  have ever been greeted
- house facts - leader, creed, ration policy, larder, water, hearth,
  motor pool, feuds, pacts, and a dated chronicle
- durable memory of the dead ([F-033]) that never decays

Every one of those is a claim with provenance, which is the standing
law: interiority is settled claims with provenance and epistemic age;
text renders at read time; storing prose is the smell. The line-tables
in `SAO_Voice.lua` are the placeholder a real answer surface replaces.

## The operator's questions, answered from that ground

**"Can they answer something about 1993?"**

Two readings, both answerable.

*Their own 1993* - yes, and already stored. A survivor knows they drove
a truck, that they came from a named region, what they were good at,
and when they learned what. Derived from the census; real state.

*The world's 1993* - the year, the war, the radio, the pennant.
Modelling known history is fidelity (the operator's standing rule; the
sixties and 1993 were named explicitly). A survivor carries the shared
past the way a person carries it: scoped by who they were - a nurse in
Muldraugh and a soldier out of Fort Knox do not carry the same 1993 -
held as dated claims like anything else, and answerable. What is
refused is invention at render time: an answer asserting something the
person holds no claim for. "How would I know?" stays for what THAT
PERSON would not have known, which is most things - but the boundary is
what they would plausibly have lived, not a refusal of the shared
world. The known history itself is declared ground: researched, its
confidence recorded, never confabulated and passed off as emergence.

**"How long do they hold on to the past?"**

The durations exist and their disagreement is an asset:

| what | how long |
|---|---|
| a sighting of a zombie | decays past `ZOMBIE_HORIZON * 2` |
| a sighting of a person | decays past `PEOPLE_HORIZON * 2` |
| that someone died | never decays ([F-033]) |
| lessons | permanent, and dated |
| relations, debts, feuds, pacts | permanent until resolved |
| the county chronicle | last 40 events |

An NPC who has lost track of a horde from weeks ago but never forgets
who died is not a limitation to code around; it is a memory with a
shape.

**"Canned, or generated?"**

Canned today. The path has two rungs and the second depends on the
first:

1. A knowledge query surface - what does survivor N know about topic T,
   at what provenance, how old. Testable offline against the mirrors,
   needs no external service, and every renderer needs it.
2. A renderer over that surface - a local template grammar
   (deterministic, offline, narrow) or a model call given the claim
   set as its only permitted ground (generative, needs a service, and
   needs the boundary enforced structurally, not by instruction).

Because the claim set is the contract, the renderer is swappable and
rung 1 is not wasted either way.

## The risk, stated once

A model handed a survivor's claim set will cheerfully invent a brother,
a hometown, a grudge. Whatever renders speech must be structurally
unable to assert what the claim set does not contain - enforced by
construction, not by instruction. If that cannot be guaranteed, rung 1
with a template grammar is the honest product.

## The governing law ([B27], operator, 2026-08-26)

The experience loop stays one loop: the only distinction is how the
player communicates with survivors versus how survivors communicate
with each other.

One loop. Speech, when built, is a transport, not a pathway: what
crosses, at what provenance, who is recorded as the teller, and what
the listener does with it are identical whether the words arrive as
free text, dictation, a menu click, or one survivor walking up to
another.

[B27] made this true for the belief channel: the player perceives
through the same `P.observe` every survivor uses and tells through the
same `P.tell`, recorded as the teller with `told` provenance. The only
branch is `chosen`, which skips the speaker's reticence gate - a
survivor decides to speak by a trust calculation and a player decided
by clicking. The listener's skepticism is not waived by either.

A speech surface that needs new state, new provenance, or a new way of
changing standing is, by this law, built wrong.

## Not scheduled

The operator was explicit that the current work comes first. This
document exists so the direction is not lost and so the next reader
knows the current work is the foundation for it, not a detour.

The one piece worth doing early, whenever it is picked up, is rung 1,
because it is useful on its own: it improves the Ledger, the debug
surface, and the briefing today, with no dialogue attached.
