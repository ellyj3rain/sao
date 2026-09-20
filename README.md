# Survivor Awareness Overhaul

A Project Zomboid Build 42 NPC framework.

Survivors decide on what they have actually perceived - what they saw, heard,
and were told. Map truth they could not know is unavailable to them. They are
durable inhabitants of the county, holding their own positions and intentions
whether or not a player is nearby. Skill governs how well they execute; it
never licenses behavior no person would produce.

The design calls for organizations, work, culture and settlements to emerge
from people's circumstances, actions and relationships. The implementation
contains useful engine adapters and durable state, but also fixed decision
rules, incomplete producers and reproduced continuity defects. Those gaps
remain implementation work; the intended behavior is not a completion claim.

The 2026-09-19 consolidation groups 127 former C records into 50 coherent
units, following the A/B precedent. [SESSION_STATE.md](SESSION_STATE.md)
states the current assessment. [SUBSTRATE.md](SUBSTRATE.md) traces the engine,
records, actions and observations needed before Speakeasy training can rely
on the simulation.

## Where to read first

| Document | What it holds |
|---|---|
| `CORE.md` | Identity, the four-pillar composition, governing constraints. |
| `ARCHITECTURE.md` | Ratified shape, runtime layers, engine surface, worked example. |
| `GOVERNANCE.md` | Operating discipline and evidence standard. |
| `ROADMAP.md` | Gate order and what is deliberately deferred. |
| `SESSION_STATE.md` | Where the work actually stands right now. |
| `PLAYABILITY.md` | What a player would actually meet, and what is unproven. |
| `PROJECTS.md` | The architecture across the three repositories: SAO, ZAO and Speakeasy. |
| `SUBSTRATE.md` | Existing and planned dependencies, and what each area of concern needs. |
| `CREDITS.md` | Attribution and integration status per source. |

`MEMORY.md` indexes every root document and its standing.

## Status

`2.7.15.1-pre-alpha` - the coordinate is computed by the version machine
(`tools/version_replay.py`), never picked; `VERSION_MAP.md` shows the
classification and the arithmetic.

Pre-alpha, and the evidence comes in two kinds.

Play evidence accrues one observation at a time in `RECEIPTS.md`, which
holds 6 so far: surfaces witnessed doing what their record claims,
defects exposed in play, and observations still open. Mechanical closure and
play acceptance are distinct: an unobserved surface remains unobserved, and a
fix made from a play receipt awaits observation of its resulting behavior.

Numbered mechanical and behavioural checks run on every commit; their count
lives in `SESSION_STATE.md`. The implementation audit reproduced defects
while targeted checks passed, so a green gate establishes only what its
instruments can observe. Engine claims are checked against the installed
`projectzomboid.jar` and shipped scripts.

Late-start history currently runs the causal dormant simulation in bounded
slices. Its completion and reload behavior are tested in the installed game VM.
The previous fast extrapolator was removed because it assigned outcomes from
unsupported curves. A validated learned accelerator remains unfinished.
Trajectory exports require completed horizons and report simulation faults;
headless receipts do not establish loaded-body behavior or play quality.

C51-C56 repair person preservation, authorized Afflicted return, shared county
time, complete native-person continuity, durable/runtime reconstruction and
health/dormant physiology. Possessions, wounds, experience,
nutrition, conditioning, learned/read material, appearance and declared durable
metadata survive the supported handoff; a returning person has one source and
controller; every decision read sees the current historical substep. Runtime
registries rebuild per world, pending save work has an explicit disposition and
interrupted return saves reconcile their native and global generations. The
brain-health graph is a durable event history with behavioral consumers, and
dormant carried food and drink use native partial effects. A completed,
interruptible Crossed blood action is the sole Afflicted conversion producer
and transfers the same human shell to ZAO without feeding on it. The complete
Crossed weapons, tools and general action system and the broader audit findings
remain explicit work in `SUBSTRATE.md`.

C57 begins the ratified whole-mod restructuring with one shared body snapshot
contract for release, checkpoints and ownership transfer. Its native test suite
retains the former snapshot, continuity and physiology assertions and controls
while sharing unchanged compilation. C58 separates population admission, body
representation, physical observations and dormant advancement from scheduling,
and repairs callback replacement and world reinitialization. Perception and
world access are next; `ROADMAP.md` preserves their grounding dependencies and
the remaining action, social and learned-model obligations.

## Requirements

Project Zomboid Build 42.20.

**ZombieBuddy** is required - the Java component (`media/java/SAO.jar`)
loads through it. Without ZombieBuddy the Lua degrades to a functional
but far thinner mod, because every engine read the Java side provides
is absent.

No other mod is required. Other NPC mods are recognised where present
and never depended on: another mod's people are handled by property,
so no mod is named anywhere in this codebase's logic.

## Licence

GPL-3.0 - full text in `LICENSE`. Attribution and per-source
integration status in `CREDITS.md`.
