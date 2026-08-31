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

`0.6.0.0-pre-alpha`.

**Playable, but unproven.** No feature in this mod has live-play
verification: every batch is OPEN pending play receipts, and
`PLAYABILITY.md` says so in its own words. What exists is checked a
different way - a border gate of numbered mechanical and behavioural
checks runs on every commit (the current count lives in
`SESSION_STATE.md`, computed rather than written by hand), and every
engine surface used here is verified against the shipped
`projectzomboid.jar` before use rather than assumed.

That is a real standard and it is not the same as being tested by
playing. Treat it as pre-alpha.

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
