# Survivor Awareness Overhaul

A Project Zomboid Build 42 NPC framework.

Survivors decide on what they have actually perceived - what they saw, heard,
and were told - rather than on map truth they could not know. They are durable
inhabitants of the county with their own positions and intentions, not a
refill effect around the player. Skill governs how well they execute; it never
licenses behavior no person would produce.

Nothing here is scripted and no behaviour table is authored. What a survivor
does follows from temperament, standing, and the work a place actually needs;
what they own comes from what the place actually yielded. Houses form, elect,
quarrel, divide and hold ground, and the county governs itself. Once the
helicopter has stopped coming, newcomers walk in from outside.

## Where to read first

| Document | What it holds |
|---|---|
| `CORE.md` | Identity, the four-pillar composition, governing constraints. |
| `ARCHITECTURE.md` | Ratified shape, runtime layers, engine surface, worked example. |
| `GOVERNANCE.md` | Operating discipline and evidence standard. |
| `ROADMAP.md` | Gate order and what is deliberately deferred. |
| `SESSION_STATE.md` | Where the work actually stands right now. |
| `PLAYABILITY.md` | What a player would actually meet, and what is unproven. |
| `CREDITS.md` | Attribution and integration status per source. |

`MEMORY.md` indexes every root document and its standing.

## Status

`4.0.0.0-pre-alpha` - the coordinate is computed by the version machine
(`tools/version_replay.py`), never picked; `VERSION_MAP.md` shows the
classification and the arithmetic.

Pre-alpha, and the evidence comes in two kinds.

Play evidence accrues one observation at a time in `RECEIPTS.md`, which
holds 6 so far: surfaces witnessed doing what their record claims,
defects exposed in play, and observations still open. A batch stays open
until receipts touch its surfaces, and a fix made from a receipt is
pending until re-witnessed. Both are ordinary states, and a surface not
named there is one nobody has watched yet rather than one that failed.

Everything else is held by the gate: numbered mechanical and behavioural
checks run on every commit (the count lives in `SESSION_STATE.md`,
computed rather than written by hand), and every engine surface used
here is verified against the shipped `projectzomboid.jar` before use
rather than assumed.

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
