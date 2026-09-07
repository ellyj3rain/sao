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

Recognised, never required. `require=` in `mod.info` names no NPC
mod (only the two condition mods below, since [C32]), and another
mod's people are handled by property - an `IsoPlayer` that is not in
the engine's slot array and is not one of ours - so no NPC mod is
named anywhere in this codebase's logic.

## Infirmities (Twuben)

Workshop 3579088411, mod id `twbInfirmities`, Build 42.20; itself
requires Moodle Framework and TchernoLib. **Hard runtime dependency
since [C32]** (DR-032: the player carries the conditions the
county's people carry). Its terms allow use, collections and
extension with credit. No code taken.

## Even More Traits (Darkyosh, after Dr. Lalaoz)

Workshop 3777663603, mod id `EvenMoreTraits4220`, Build 42.20 - a
port of Dr. Lalaoz's Build 41 mod, whose traits, effects and writing
the port credits whole. **Hard runtime dependency since [C32]**
(DR-032). No code taken.

## Neurodiverse Traits (Mxswat)

Source public (github.com/mxswat/pz-neurodiverse-traits), Build 41.
**Mechanisms taken, with the author's permission as the operator
settled it:** Alzheimer's daily skill loss (each skill outside the
passive and agility families, an even chance a day of losing 2.5
percent of the next level), ADHD's daily focus (35 percent plus half
a percent a day survived, to 70) and bipolar's daily phase, carried
in `SAO_Conditions` and the bridge's `loseSkillMemory` ([C32]). The
mod trades in vanilla traits and pills; the county's people have
axes and no pills, so those parts are not carried.

## Custom Traits Mod (0x00sec)

Workshop 3408520770, Build 41; source not public. **Two figures
taken from the page's own description:** dyslexia reads a quarter
slower and gains a tenth less experience ([C32]). No code read.

## Scotty's Mental Health Expansion (ScottyVenable)

MIT (github.com/ScottyVenable/Project-Zomboid-Mod--Scottys-Mental-
Health-Expansion), Build 41. **Mechanisms taken:** depression and
insomnia as chronic fatigue, anxiety as raised panic, PTSD as a
constant low panic with spikes at fresh horror, psychosis as a heard
threat nobody else hears ([C32]); its numbers are per update on a
player and the county's are per ten-minute pass on a person, so the
figures here are ours and say so. Its medications, self-help books
and journals are not carried.

## ADHD Trait (JoshuaSHenderson)

MIT (github.com/JoshuaSHenderson/ProjectZomboid-ADHD-Trait), Build
42. **Read; nothing taken.** The catalogue listed it as a cognition
mod; its mechanic is a comic one (actions three times faster and the
character dies after fifteen seconds standing still), not a memory
condition.

## The Alcoholic (axxessdenied)

MIT (github.com/axxessdenied/thealcoholic), Build 41. **Mechanisms
taken ([C33]):** the hours since the last drink, the four withdrawal
phases at 12, 24, 48 and 72 hours with their stress and fatigue,
the habit lost after 504 hours dry and gained by drinking often
(four a drink, one off an hour, gained at 200), the stress a drink
takes, and the wrap of the drink action that counts a drink -
carried in `SAO_Habits` and `SAO_Needs` at SAO's own cadence. Its
tolerance, poisoning, headaches and death by withdrawal are not.

## N and C's Narcotics (Neely, a_COW_says)

Workshop 3404956403, Build 42; source not public. **The page's own
schedule taken ([C33]):** a dependency lost after eighteen to
twenty clean days, with withdrawal medium from day one (three for
sedatives), bad from day five (six) and mild from day ten. The page
gives the tiers and not their sizes; the sizes in `SAO_Habits` are
ours and say so. Its drugs, items and interactions are not carried
- the county has no supply of any of them. No code read.

## Drugs of '93 (Red Jones), Just Drugs (Leuan), Psychology Skill (WindLother)

Read in the catalogue for the period set, the dependency pattern and
the nicotine and alcohol dependency they model; nothing taken, none
required.

## Lifestyle: Hobbies (Angry)

Workshop 3403870858, mod id `LifestyleHobbies`, Build 42.19+. Its
page asks that its work be added to or extended only with the
creator's express permission, with credit in the files and wherever
the mod goes. **Files copied, with the author's permission as the
operator settled it ([C35], DR-034):** twenty-two conversation
gestures, eight sitting loops, eight instrument plays and sixteen
dances, under `media/anims_X/Bob`, named as the mod names them;
the bindings are SAO's own. Nothing of its code, items, skills or
systems is taken.

## Week One (Slayer), for its art

Workshop 3403180543, mod id `BanditsWeekOne`; on the Bandits engine
(3268487204), whose page holds that all the author's work is
copyrighted and not to be reused without written permission.
**Files copied, with the authors' permission as the operator settled
it ([C35], DR-034):** the waiter's serving animation (SaneGuy, the
mod's animator) and the coughs and claps (Lauren Sinclair and AuD,
as the mod credits its sounds), under `media/anims_X/Bob` and
`media/sound/sao`. Nothing of its logic crosses: its people are
programmed zombies on a scripted timeline, and SAO's are not.

## Humans: Are Weak (SeahDokki)

Source-available (github.com/SeahDokki/seah_haw_pz), Build 42, not
on the Workshop. **Read for its design; nothing taken and not
required.** It cannot be a `require=` (no upload), and its
non-commercial source-available terms are not compatible with this
mod's GPL-3.0, so no code crosses. Recorded so the ruling that
named it (DR-032) has its answer.

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
