| Document | The three projects and what each owns |
|---|---|
| Version | `4.2.4.4-pre-alpha` |
| Author | ellyj3rain |
| Repository | `PROJECTS.md` |
| Status | CANONICAL - the architecture across the three repositories. Held here; `../zombie-awareness` and `../zomboid-speakeasy` point at it. |

# The three projects

One county. Three repositories, because three things need separate
licences and separate gates, not because they are three products.

| | Repository | Licence | What it owns |
|---|---|---|---|
| **SAO** | `survivor-awareness` | GPL-3.0 | the living |
| **ZAO** | `../zombie-awareness` | GPL-3.0 | the turned |
| **Speakeasy** | `../zomboid-speakeasy` | MIT | how anybody decides |

The county is the same county in all three. A person walks through it,
dies in it, and gets up again in it, and no repository owns more than
its share of that sentence.

## What each one is

**SAO owns the living, and owns death.** A person is a record; the
engine character is a body the record is loaded into and is never what
persists (DR-002). Perception admits, Disposition decides, Standing
channels, Execution acts. Death of the person is SAO's completely
(DR-016) - the turn fires here, through the engine's own `die()`, and
the person's id rides the engine's own modData copies through it.

**ZAO owns the turned.** What a turned body does follows from who the
person was and how far the rot has gone, never from a species-level
behaviour table. It is an add-on that can be switched off: with ZAO
absent, vanilla handles the corpse and the engine misses nothing. Two
mechanisms, litigated separately and never merged - the rotting of a
particular mind, and the pathogen's own decay and mutation.

**Speakeasy owns how anybody decides.** A dataset and the models fitted
to it: how a person decides in the game space with limited awareness,
from their own attributes and personality. It ships no mod. What is
built there ports into a consumer, and the consumer runs it in-process
on the game's own Java, never through a service.

## What none of them owns

Nothing here places an outcome. A house is not put in the world, a
settlement is not scheduled, and a population is not balanced toward a
target. Every arrangement in the county is what its people did, and a
pass that placed one would destroy the only measurement there is
(DR-037).

## The three seams

### SAO to ZAO - the turn

The seam is one moment and it is already litigated on both sides. SAO
owns the death of the person completely and ZAO owns the risen mind;
exactly one controller runs any body, proven by observation rather than
by load order. The person's id crosses on the engine's own modData
copy, character to corpse to risen body.

What crosses is the **record**, not the belief cache. A record is
save-scoped and a belief store is bound to ModData with it, but what a
rotting mind is entitled to is what the person carried - their place,
their history, the verbs they had - and temperament is hash-derived
from the id, so almost nothing has to be stored for a mind to be
re-derived and then degraded.

ZAO reads SAO's mechanics and copies no files. Where the audit of the
sister found defects, they went back to SAO as repairs rather than being
worked around.

### SAO to ZAO - the ones who came back and the ones who went past

The second crossing between these two, opened at ZAO's `[A11]` and
running the other way from the turn. A person becomes ZAO's while
remaining inside SAO's county: an afflicted body is a person again, in a
house, holding bonds, being argued over; a crossed one looks like a
person and acts with the sister's own action vocabulary - driving,
explosives, loudspeakers - with what humanity gave it stripped out. The
sister's machinery for houses, standing, fear and temperament reaches a
body the sister no longer owns.

The seam is shaped - ZAO's `[A12]` carries the rulings, under one
principle of the operator's own framing: three repositories, one
project, separation of concerns, each machinery running what it owns.
SAO executes the afflicted, because a person again is a person - the
house argues over them because they never left the county's machinery
- while ZAO owns the pathogen state on them and executes the crossed,
who came through death as the risen did. The crossed's vocabulary is
a bidirectional goal: they read SAO's action machinery stripped of
what humanity gave it, and what they need from driving feeds forward
into SAO's mapping of it - `[C82]` has mapped what the engine gives a
driver who is not the player, and F-067 holds the finding - a
standing goal between the two repositories and never a dependency
in either direction. How they
hold ground is variable - some groups settle, some stay nomadic - and
never placed. The claim surface's concrete shape (ZAO's F-012) stays
open until mod code is near.

### SAO to Speakeasy - the dataset

No code crosses, and the licences are why the repositories are separate
at all. Speakeasy is MIT and SAO is GPL-3.0; a dataset and a fitted
model port into SAO, and nothing else does.

Speakeasy's rows are built from SAO's own people - the attributes,
conditions, history and belief set a person actually holds at the
moment of a decision - and they replace the places where SAO currently
authors a list: the five work words a company deals from, the four
creed names, the shape of a group's relationship to a place. A group
must be able to create a position because it needed one and have its
own word for it, and no table can stand in for that (DR-038).

### ZAO to Speakeasy - the degraded cognition

The third edge, and the one that is not yet built.

A turned mind is a cognition with its inputs failing. Speakeasy models
how a person decides from what they know and who they are; ZAO's first
mechanism is that same person deciding with perception, verbs and
continuity coming apart at rates that differ per body. The two are the
same model under a transform, not two models.

Nothing is designed here yet and nothing should be until ZAO's G2 lands
- the record reaching a turned body with provenance intact. Naming the
edge now is what stops it being invented twice.

## What holds across all three

- **Verified APIs only.** Ground truth is the installed game. An
  unsupported statement is a hypothesis and is labelled one.
- **Verify the instrument before trusting its output.** An analysis
  script is not evidence until its own correctness is established
  against a known-bad control.
- **The record is the person.** All three read the same identity; none
  mints a second one for the same being.
- **A batch closes with a record, a log row, a state advance, a border
  for the class it found, and a control that flips the verdict.**
- **Nothing becomes a requirement.** No capability in any of the three
  may require another survivor mod, and nothing runs through one
  unless the player asks (DR-035).
- **The operator is the design authority.** Code-level verification
  never settles how the game looks or plays.

## Where the work stands

| | Version | Standing |
|---|---|---|
| SAO | see `VERSION` | four pillars built, the county runs on them, play receipts outstanding. A bitten body now races the engine's own death hour instead of arriving at it, the unwatched county can catch Knox on its own, and one person can read another as far as their own First Aid allows. |
| ZAO | `../zombie-awareness/VERSION` | G0 closed at `[A6]` - the turn, the control surface, the player's dials and the recovery mods all have evidence. No mod code, which is what the gate ladder asks for here. Three decisions gate G1. `[A7]`-`[A9]` read the mods that already run behaviour on turned bodies and set what this project does with them (DR-014, DR-015). `[A10]` confirmed the actuators are Java-side. `[A11]` defined the mutation system - `MUTATION.md` is canonical - and the county gained two populations: the afflicted, who are people again, and the crossed, who only look like one. `[A12]` shaped the second seam under separation of concerns: SAO executes the afflicted while ZAO owns the pathogen state on them and executes the crossed, the crossed's vocabulary is a bidirectional goal, and their ground-holding is variable and never placed. `[A13]` carried the sister's driving map into the seam's goal the same turn it landed: what the crossed need from driving now rides as named consumers of a mapped surface, with its live receipt owed. |
| Speakeasy | `../zomboid-speakeasy/RECORD.md` | the dataset's source and row shape ratified (record 24); a ceiling for the inference budget measured (record 26); the first 112 rows are in `decisions/`, ratified by the operator (its record 29) |

Each of those is its own repository's to update. This table says where
the three stand relative to each other, which is the thing no single
repository can say about itself.

It is also the first thing to go stale when one of them moves, and it
does so silently, because no border in any of the three reads it. Twice
on 2026-09-09 a surface stating what a project IS was found describing
a charter that had already changed - Speakeasy's public description a
day after its own record redefined it, and ZAO's readme four batches
after the gate it named had closed. When a gate or a charter moves,
this table moves in the same turn.
