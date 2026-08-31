# Credits

**Licence.** This mod is GPL-3.0; the full text is in `LICENSE`. It is
built on the methodology of Colonist Awareness Overhaul, which is
GPL-3.0 and by the same author, so the terms are consistent rather
than merely compatible. Components below retain their own terms where
those are more specific.

Each entry states its own **integration status**. An entry describing
influence is not a claim that code was taken.

## Colonist Awareness Overhaul (CAO)

ellyj3rain. GPL-3.0. **Methodology, adapted; no code taken.**

Survivor Awareness is CAO's approach carried into another engine: the
four-pillar composition, the doc-pack and decision registry, the batch
discipline with append-only ledgers, and the founding law that content
must be *derived from real state rather than authored*. The pillars
here are Perception, Disposition, Standing and Execution, and the
provenance ladder (`observed > heard > told`) is the same idea CAO
applies to limited knowledge.

The two codebases share no source. RimWorld and Project Zomboid have
nothing in common at the implementation level; what transferred is how
to think about a living world and how to hold a project to it.

## KnoxSurvivors

**Reference-read for engine seams only. No code taken.**

Consulted to identify where Project Zomboid's own surfaces can carry
an NPC - `IsoPlayer.setNpc`, the slot array, `SpawnRegionMgr` - after
which this implementation is bespoke and license-clean. At runtime it
is recognised where present and **never required**: its people get
their own key domain so they are never confused with ours or with the
player (DR-009).

## ZombieBuddy

**Hard runtime dependency.** The Java component (`media/java/SAO.jar`)
loads through ZombieBuddy; `ZBVersionMin` in `mod.info` states the
floor. Without it the Lua degrades to a functional but far thinner
mod, because every engine read the Java side provides is absent.

## Project Zomboid

The Indie Stone. Engine surfaces are used as the game exposes them and
verified against the shipped `projectzomboid.jar` before use. No game
assets are redistributed.

## Other NPC mods

Recognised, never required. There is no `require=` in `mod.info`, and
another mod's people are handled by property - an `IsoPlayer` that is
not in the engine's slot array and is not one of ours - so no mod is
named anywhere in this codebase's logic.
