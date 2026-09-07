| Document | The talking system - design map |
|---|---|
| Author | ellyj3rain |
| Repository | `SPEECH_ML_DESIGN.md` |
| Source | DR-029 (deep ML, design-first), serving SPEECH.md |
| Status | RATIFIED - all six decisions passed Crucible (2026-08-29/30). Build follows this document. |

# The talking system, designed before it is built

## What the system models (operator correction, 2026-08-30)

The frame that governs every decision below, the operator's
correction paraphrased: this is not a productized survivor-chat
feature. Survivors have a world model and awareness of things in
the game; they know the 90s. Mod assets affect knowledge and
culture and mood. Post-apocalyptic politics, struggle, growth. It
is just how a person is - speech is not press-this-get-that, it is
will and choice and mood. Grandiose without needing to be
earth-shattering in size, and still large.

So the learned system models a person speaking. The speaker
expresses an inner state - world
model, disposition, mood, will - through words; the understander
reads the player INTO that person's world. The mechanical two-piece
shape (Decision 1) stands; any description of it that reduces
talking to intent-lookup is corrected by this section.

The goal is SPEECH.md's, the operator's direction paraphrased:
type almost anything to a survivor and have them understand you;
the answer
comes from what that exact person knows and remembers, in their own
voice, and could only have come out that way once. The mechanism of
record is a learned system (DR-029); a live AI service writing
replies is refused; the mod ships self-contained.

This document is the map of the decisions that design requires.
Each is OPEN until ratified through Crucible, in order - the first
constrains all the others. Rejecting the listed options and
describing a different shape is always available.

## What is already true, and binds the design

- **The knowledge exists.** A survivor already carries a
  census-derived past, memories with how-they-learned-it and how
  old, permanent memory of the dead, dated lessons, relations and
  debts, house facts. The system's job is never to invent a person
  - it is to let the one that exists speak.
- **The no-invention rule** (SPEECH.md's risk clause, untouched by
  DR-029): whatever produces words must be structurally unable to
  say what the person does not know. "Structurally" means the
  system cannot do it even when wrong - not that it was told not
  to.
- **One loop** ([B27]): talking is a transport over the same
  channels survivors already use with each other. What the player
  is told got told; what the player tells lands as told-by-them.
  No new kind of state.
- **Self-contained shipping.** Verified 2026-08-29: the game runs
  Java 25 (class major 69), and the county already ships and loads
  its own jar. Modern pure-Java inference with no native libraries
  is therefore feasible in-process; anything heavier needs its own
  ratified justification.
- **The register** (DR-017/DR-018): players read player language;
  nothing performs. The current line tables are condemned standing
  (DR-029) and earn no further work.

## Decision 1 - What does the learned system actually do?

The word "talking" hides two different jobs. Understanding: reading
the player's typed words and working out what is being asked, told,
or wanted. Speaking: producing the survivor's words back. Learning
can carry either, both, or the whole span between.

- **1a. It understands; the county speaks.** The model's whole job
  is reading free text into meaning against what the person knows.
  The reply is then assembled by game logic from the person's
  actual memories. No-invention is automatic (nothing generates
  text). The ceiling: reply wording is assembled, so its variety
  is what the assembly can reach.
- **1b. It speaks; the county understands.** Input is read by
  deterministic parsing; the model turns the person's selected
  memories into their sentences. Naturalness is highest where 1a
  is weakest; the no-invention rule now needs enforcement inside
  the model's decoding, which is the hard half.
- **1c. It does both** - two learned pieces (or one) spanning
  understanding and speaking. The full vision, the most training
  data, the most enforcement work.
- **1d. Staged: 1a first, 1b grafted later** - understanding is
  learned now, speaking stays assembled until its model earns
  ratification separately.

**RATIFIED 2026-08-29 (Crucible): 1c, as two learned pieces.** The
choice: speaking is learned too, from the start - over the single
end-to-end model and over every staged shape. Both halves
learn: an understander reads the player's free text into meaning;
a speaker turns the person's selected memories into their
sentences. The no-invention fence is built into the speaker's
decoding (Decision 4 picks the mechanism).

## Decision 2 - What data teaches it?

Constrained by Decision 1 (an understander trains on
player-utterance examples; a speaker trains on knowledge-to-words
pairs).

- **2a. Harvested real speech, CAO precedent.** The operator's
  named method: real player data - multiplayer server logs, chat
  corpora - showing how people actually type under pressure.
  Strongest realism; sourcing, consent, and cleaning are real work
  that the design must name honestly.
- **2b. Authored seed, machine-expanded at build time.** A ratified
  seed corpus grown by build-time tooling into training scale.
  Fully controlled register; risks teaching the model the seed's
  blind spots.
- **2c. Both** - harvested data for how players talk, authored data
  for how survivors answer.

**RATIFIED 2026-08-29, OVERTURNED 2026-08-30.** The 2c verdict
rested on harvest sources that do not exist and on a scope the mod
never had. No player-speech harvesting, anywhere.

**RE-DECIDED 2026-08-30, from the operator's correction.** The data
is the person's world, three kinds:

1. **The period world model** - the 90s as SPEECH.md always scoped
   it: researched declared ground, confidence recorded, carried
   scoped by who each person was. Sourced from period/world corpora
   curated at build time.
2. **The game itself, derived live** - the county already derives
   what places offer from mod content ([B38]); knowledge, culture,
   and mood extend the same law: what exists in the loaded world
   (vanilla or modded) is what people know, use, and are shaped by.
3. **Authored voice material** - the language of the county's
   people, authored in the ratified register and machine-expanded
   at build time, demonstrating will, choice, and mood - serving
   both pieces.

**RATIFIED 2026-08-30 (Crucible), the sources fixed:** the period
world model comes as researched world documents - the county's 1993
written as a document set, every claim carrying its confidence,
RATIFIED BY THE OPERATOR before it teaches anything - with curated
public-domain period text supplying language texture on top. And
the pipeline lives as its own tracked project beside SAO (the
mod-patches precedent): datasets, world documents, and training
runs under their own records; SAO receives only the shipped models.
The operator named it 2026-08-30: **Zomboid-Speakeasy**, at
`Projects/Zomboid-Speakeasy` beside this repository -
collision-checked against the PZ workshop and the existing
speech-mod cluster. Its license is MIT, ratified
2026-08-30 (SAO stays GPL-3.0; no SAO code crosses into it; its
models ship into SAO freely), and it is public at
github.com/ellyj3rain/zomboid-speakeasy - main default, SSH
remote, CI to land with its first runnable check. The first
world-document cut is ratified as America 1993 first.

## Decision 3 - Where does it run?

- **3a. In-process, pure Java.** The model ships inside the
  county's jar and runs on the game's own Java 25. No
  dependencies, works for every subscriber. Bounds model size to
  what CPU inference tolerates mid-frame (small models; exact
  budget measured, not guessed).
- **3b. Build-time only.** Learning happens entirely before
  shipping; what ships is the model's OUTPUT baked to data, runtime
  is lookup and assembly. Zero runtime cost; understanding of
  arbitrary text is bounded by what got baked.
- **3c. Sidecar process.** A separate local program the mod talks
  to. Lifts the size ceiling; adds install burden and a seam that
  breaks on other machines. Named because it exists, not because
  it is recommended.

**RATIFIED 2026-08-29 (Crucible): 3a as the floor, 3c's door
open.** The models ship in-process, pure Java, inside the county's
jar - working for every subscriber with nothing to install - and
the inference socket is defined so a later OPTIONAL sidecar can
serve bigger models to players who opt in. The in-process frame
budget is MEASURED before any training run fixes a model size.

## Decision 4 - How is no-invention enforced, structurally?

Options differ by Decision 1. For an understander (1a): automatic -
it emits meaning, not facts. For a speaker (1b/1c), the honest
mechanisms are: constrained decoding (the model can only place the
person's own facts into sentence positions - it physically lacks a
vocabulary for a brother who does not exist); or
selection-not-generation (the model chooses and orders among
assembled candidate sentences, never emitting free tokens). "We
told it not to lie" is not on the list and never will be.

**RATIFIED 2026-08-29 (Crucible): constrained decoding.** The
speaker composes sentences freely, but every fact position can
only be filled from that person's actual memories - the freest
language the fence allows, and the hardest single piece in the
design. Its correctness gets its own border when built: no
emitted sentence may assert a fact absent from the input claim
set, verified mechanically over test corpora, not by review.

## Decision 5 - Whose voice is it?

How the person reaches the wording: temperament axes (reserve,
nerve, warmth), trust toward the listener, the moment (war, grief,
debt) - as conditioning the learned system reads, or as assembly
rules. Decided after 1; recorded here so it is not lost: the goal
is that a reserved survivor and an open one answer the same
question differently, and the same survivor answers you differently
at trust 0 and trust earned.

**RATIFIED 2026-08-30 (Crucible): both layers.** The speaker model
takes temperament, trust, and the moment as inputs and LEARNS the
voice - and deterministic rules enforce floors on top of whatever
it learned: a hostile person never over-shares, a guarded one
never rambles, grief never chats. The seed corpus must
demonstrate the voice differences the model is expected to learn;
the rule floors are authored and bordered like any other law.

## Decision 6 - What is the exchange?

Answering is the floor. Whether they also ask, request, remember
what you told them as it changes their plans, refuse, bargain -
and what of that lands in which stage - is a scope decision the
operator holds. Raised three times on 2026-08-29 without a ruling;
it returns to Crucible concretely once Decision 1 fixes what the
learned piece is.

**RATIFIED 2026-08-30 (Crucible): the full exchange, from the
start.** The understander learns questions, statements, requests,
offers, and threats; the speaker may answer, ask back, request,
refuse, and warn. Everything said lands through the county's
existing channels - the one-loop law - so words move trust,
beliefs, and what people do next. Conversation has consequences
because it uses the same machinery as everything else.

## The design, ratified

All six decisions passed Crucible (D1-D4 on 2026-08-29, D5-D6 on
2026-08-30). The system of record:

Two learned pieces, shipped in-process in pure Java inside the
county's jar (sidecar door open for opt-in bigger models). The
UNDERSTANDER reads the player's free text - question, statement,
request, offer, threat - into meaning against the person's
knowledge; trained on harvested real player speech (the CAO
method). The SPEAKER turns the person's selected memories into
their sentences under constrained decoding - fact positions
fillable only from what that person actually knows, correctness
bordered mechanically - conditioned on temperament, trust, and the
moment, with authored rule floors above it; trained on an authored
seed corpus in the ratified register, machine-expanded at build
time. The exchange is full and two-way, and every word crosses the
county's existing channels.

What follows, in order: the knowledge surface built to this
contract (the substrate the ruling deferred until design); the
in-process inference budget MEASURED on the real game before any
model size is fixed; the data pipeline opened as its own tracked
project with the harvest sourcing decisions brought to Crucible.
