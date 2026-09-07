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

## Byte Buddy

Rafael Winterhalter and contributors. Apache-2.0. **Used at runtime
through ZombieBuddy's bundled copy; not redistributed.** The
body-scale weave ([C29]) is a Byte Buddy exit advice installed
through the same self-attached instrumentation the melee patch uses.

## Growing Up and Realism V4 (PZ Chronicles)

**Read, with the authors' permission as the operator settled it
directly with them; no code taken.** The route to a body's size - the
animation player's bone transforms - was read from Realism V4's
replaced engine classes and Growing Up's Lua before SAO took its own
route to the same seam ([C29]). Growing Up's height-by-age table is
carried in `SAO_History.heightScaleOf` with this attribution. Its
fear model (the floor by age, the night, the comfort object, the
kills that harden), its literacy gate, its experience throttle and
birthday floors, its rule for a child's head and its kid types'
kits are carried in [C31] at SAO's own seams with the mod's numbers
(`SAO_History`, `SAO_Disposition.fear`, `SAO_Age`, `SAO_Body`,
`SAO_Appearance`, the bridge's scaled grant); its nightmares,
growth spurts, cooking, driving and grief systems and its voice
lines are not.

## Think Of The Children (Zomboides)

MIT. **Source read; no code taken.** Its model-instance scale was
checked against the installed jar and not borne out for characters
(ENGINE_CONTRACT Addendum F).

## Getting Old (Devlin)

**Mechanics taken, with the author's permission as the operator
settled it; source public (github.com/Bruce-Devlin/ProjectZomboidMods).**
Its five life stages and their per-stage drift on stamina, tiredness,
pain and stress, and the decline of an elder marked for death, are
carried in `SAO_History.stageOf` and `SAO_Age` ([C30]) at SAO's own
cadence. Its death chance is not taken (the life table stands in) and
its stumble is not (this build's Stats has no such method).
