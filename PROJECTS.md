| Document | The three projects and what each owns |
|---|---|
| Version | `2.9.2.0-pre-alpha` |
| Author | ellyj3rain |
| Repository | `PROJECTS.md` |
| Status | CANONICAL - the architecture across the three repositories. Held here; `../zombie-awareness` and `../zomboid-speakeasy` point at it. |

# The three projects

One county. Three repositories, because three things need separate
licences and separate gates, not because they are three products.

| | Repository | Licence | What it owns |
|---|---|---|---|
| **SAO** | `survivor-awareness` | GPL-3.0 | ordinary living-survivor execution and the county's person, social and native-action services |
| **ZAO** | `../zombie-awareness` | GPL-3.0 | the turned, the pathogen, and Afflicted/Crossed execution |
| **Speakeasy** | `../zomboid-speakeasy` | MIT | how anybody decides |

The county is the same county in all three. A person walks through it,
dies in it, and gets up again in it, and no repository owns more than
its share of that sentence.

The dependency substrate - what exists, what is planned, and what each area of
concern needs - is mapped in `SUBSTRATE.md`.

## Private unified project

DR-041 establishes the intended release destination: one private unified
mod/project. The immediate work compresses SAO's borders; later work combines
the cross-module contracts and the runtime pieces into that project. DR-042
makes the first pass a whole-mod runtime restructuring, including source
ownership and file layout. The three repositories and ownership contracts
below describe the current source layout.
The assembly plan will account for module loading, Java entry points, save
identity, settings, model artifacts, source provenance and integrated evidence
before choosing its source layout and packaging.

## What each one is

**SAO owns ordinary living-survivor execution, the county substrate, and
death.** A person is a record; the
engine character is a body the record is loaded into and is never what
persists (DR-002). Perception admits, Disposition decides, Standing
channels, Execution acts. Death of the person is SAO's completely
(DR-016) - the turn fires here, through the engine's own `die()`, and
the person's id rides the engine's own modData copies through it. Identity,
communication, relationships, material transfer and locomotion remain SAO
services even when a registered sister owns the actor's decisions.

**ZAO owns the turned and the living states its pathogen creates.** What a
turned, Afflicted or Crossed person does follows from who the person was, the
current state and its distinct constraints, never from a species-level behavior
table or an SAO survivor controller applied by default. It is an add-on that can
be switched off: with ZAO absent, vanilla handles the corpse and the ZAO living
states are not produced. Two mechanisms remain litigated separately - the
rotting of a particular mind, and the pathogen's own decay and mutation.

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
person and retains cognition, identity, history and established capability
within its actual constraints. Driving, explosives, loudspeakers and other
human actions stay available when their prerequisites remain. The
sister's machinery for houses, standing, fear and temperament reaches a
body the sister no longer owns.

The seam is implemented through C80/A39. The governing principle is the
operator's own framing: three repositories, one project, separation of
concerns, each machinery running what it owns. ZAO executes both Afflicted and
Crossed through one durable living-person driver, while each state keeps its
own motives, constraints, actions and satisfiers. SAO supplies the county record,
communication, social context, handover and native locomotion services; those
services do not possess the person.

An authorized Afflicted return transfers the human shell directly to that ZAO
owner. Intentional blood exposure later changes the state to Crossed without
replacing the driver. Crossed eat and may butcher or cook ordinary humans;
ordinary food can also sustain their retained human physiology. Human-origin
food is preferred because sustenance can reinforce cruelty, domination, fear
and contagion, not because biology excludes ordinary food. Blood-contaminated
weapons are a selected tactic and resolve through actual native hits and wounds,
while Afflicted exposure remains a separate pathogen action. No governed source
defines how Afflicted maintain themselves, so neither survivor maintenance nor
Crossed motives fill the gap. Butchery, cooked human food, contaminated weapons
and driving are concrete producers, not a closed list that defines Crossed
functionality. Routine strategy remains retained human cognition; wider action
remains open. How either state holds ground follows actual state-specific acts and
needs; settlements are never placed.

ZAO's `[A17]` records how the pathogen meets the branching graph: the
pathogen owns the mutation roll and the roll for form performance, crossed
is terminal, retained form traits are state rather than new branches, forms
and attribute mutations stack, and forms enter Perception as visible facts
that change pressure inside the living branching graph.

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

The third edge carries cognition conditioned by event-derived pathogen state.
Cross-module rows, a state producer and the row contract now exist. Complete
training and learned runtime consumption remain unfinished. ZAO owns pathogen
state and Afflicted/Crossed execution; SAO owns ordinary survivor execution and
the shared county/action services; Speakeasy owns datasets and models.
SUBSTRATE.md records the implementation boundaries and current evidence.

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
| SAO | see `VERSION` | C80 generalizes living external-owner handoff so Afflicted return enters ZAO directly and conversion preserves one driver token. Communication, coordination and native services still reach the person; Standing commits no Afflicted destination before arrival. C79's enacted proposals/work remain the bounded social path. |
| ZAO | `../zombie-awareness/VERSION` | A39 supplies one driver with distinct Afflicted/Crossed policies, actor-private option selection, state-evidenced settlements, retained Crossed human physiology, ordinary/human-origin sustenance, human-corpse butchery and selectively prepared finite blood-contaminated weapon uses. Afflicted maintenance and loaded-world observation remain open. |
| Speakeasy | active Record 63 worktree | The exact v3 namespace and executable options now bind one enacted process revision, actor/executor ownership, current work/competing priorities and separate decision/outcome horizons. Candidate observations remain unreviewed and training-ineligible; no model or native learned consumer exists. |

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
