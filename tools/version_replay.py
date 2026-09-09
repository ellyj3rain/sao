#!/usr/bin/env python3
r"""Border 80 - the version is a machine, and the machine's output is stated.

The former version was hand-declared: 0.6.0.0 was picked at [B12] by a
policy sentence ("nineteen batches of shipped surface") and the old
VERSION_MAP walked to it in six flat minors so the number looked
earned. The operator's instruction (DR-013): the coordinate is not
picked, it is computed - classify each closed batch by what the work
is, run the replay under CAO's caps, and the output is the version.

THE MODEL (CAO's, adopted)
--------------------------
Form `major.minor.kohai.patch-maturity`; hard caps minor 12, kohai 16,
patch 24; a tier movement resets the coordinates beneath it; a movement
at the cap rolls the tier above (twelve minors of capability ARE a
major - that is the odometer, not an honor). Maturity moves on
evidence, never on arithmetic; SAO is pre-alpha throughout because no
batch has a play receipt.

Tiers: minor = a new player-visible simulation capability or a new
authoring/runtime contract; kohai = a coherent extension, integration,
or structural maturation of an existing capability; patch = an in-place
correction, verification closure, or repair that does not move a
capability boundary.

WHAT IS DERIVED AND WHAT IS INPUT
---------------------------------
The only input is the tier table below: one row per closed batch, with
the classification argument. Names, dates, and threads come from
BATCH_LOG.md - the index owns them, this file never respells them. The
replay derives the coordinate; --write stamps VERSION and renders
VERSION_MAP.md; the border refuses a tree whose VERSION, VERSION_MAP.md
or mod.info disagree with the machine.

To disagree with the coordinate, disagree with a tier: edit that unit's
row, state the argument in its rationale, run --write. The map and
VERSION follow. Nothing else in the tree may state a version of its own
(Border 42 stamps the jar from VERSION at build; Border 43 holds the
doc-pack headers to VERSION).
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
BATCH_LOG = ROOT / "BATCH_LOG.md"
VERSION_FILE = ROOT / "VERSION"
VERSION_MAP = ROOT / "VERSION_MAP.md"
MOD_INFOS = (ROOT / "mod" / "mod.info", ROOT / "mod" / "42.20" / "mod.info")

SCHEMA = "sao.version-model/1"
MINOR_CAP = 12
KOHAI_CAP = 16
PATCH_CAP = 24
MATURITY_LADDER = ("pre-alpha", "alpha", "beta", "rc")
REPLAY_START = "0.1.0.0-pre-alpha"

# (batch, tier, classification rationale). Chronological, one row per
# closed batch, covering BATCH_LOG.md exactly.
UNITS = [
    ("A1", "initial", "The governed repository itself: doc-pack, instruction surface, ratified pillar composition; no framework code."),
    ("A2", "kohai", "The verified engine substrate (F-001..F-007) before anything built on it; preparation, not a shipped capability."),
    ("A3", "minor", "The first survivor in the world: spawn, walk, remove - the first player-visible capability, and the mod tree ships."),
    ("A4", "minor", "The compiled agent, the bridge, and ENGINE_CONTRACT: the runtime contract everything renders and calls through."),
    ("A5", "minor", "The four pillars as code: perception with provenance, bounded disposition, standing, the controller composition."),
    ("A6", "minor", "Combat both directions and a persistent population in real towns: the framework becomes something a player meets."),
    ("A7", "kohai", "Genesis matured to the map's own spawn-region draw, off the forbidden refill shape; policy numbers become sandbox options."),
    ("A8", "minor", "The needs layer through the engine's own timed actions - eating, drinking, interruptible; grudges, testimony, gear errands."),
    ("A9", "minor", "The voice surface and real territory: claims, permission, first aid, sharing - with the one key schema (DR-005) under it."),
    ("A10", "kohai", "Multi-floor work, the ranged doctrine, and the F-011 sight repair: the loop polished, no new boundary."),
    ("A11", "kohai", "Hibernation made whole (F-013), dormant drift, estates, sleep: persistence matured into the person outliving the scene."),
    ("A12", "minor", "The social economy opens: gifts, barter, property with teeth and manners, dormant encounters."),
    ("A13", "kohai", "Debts, gunfire attribution, coordinated flight, companionship: the economy and relations grow edges."),
    ("A14", "minor", "The society arc ratified and built (DR-006): claims and lessons, leaders, settlement, membership, habits, bonds."),
    ("A15", "kohai", "Belief-gated permission (DR-007): the permission layer's last free knowledge made earned; epistemics matured."),
    ("A16", "patch", "The approval-chain repair (F-023) and the first live witness: verification closure on the existing line."),
    ("A17", "minor", "Inhabitant adoption: other mods' live humans join the social fabric with records, contact-scaled pasts, split clocks."),
    ("A18", "minor", "The census contract (DR-010/DR-011): 1993 labor distribution, profession-keyed origins, compatibility from first principles."),
    ("A19", "minor", "The workday taxonomy and elections: every tick carries a pressure answer; a mannequin is structurally impossible."),
    ("A20", "kohai", "Feuds, full-person talk, dormant attrition: politics closes its loop and gains its voice."),
    ("A21", "patch", "The hardening rotation: bulkheads, fault gates, F-031..F-034 - repair and closure, no boundary moved."),
    ("A22", "kohai", "Schism's mechanics, the war chronicle, the invariant sweep: politics matured under its audit trail."),
    ("A23", "kohai", "The offline equilibrium harness: 120 deterministic days prove the county's physics without the game; instrument, not capability."),
    ("A24", "kohai", "The engine rotation re-read end to end; full names and per-person texture make the people legible."),
    ("A25", "kohai", "Counsel, ration policy, the governance chronicle: the commons matured at community scale."),
    ("A26", "minor", "The county wire, 101.2, both directions: a new medium, built on the engine's own radio pattern."),
    ("A27", "kohai", "Player chairmanship, the arrival draw, war parties: the political physics completed."),
    ("A28", "minor", "Derived possessions: the convenience tables die; place provides, person spots - a new derivation contract."),
    ("A29", "minor", "Day-zero innocent-county mode: a new way to start the world, innocent by construction."),
    ("B1", "minor", "The venture as a designed feature-complex: motor pool, departure argument, terms, crews, briefings."),
    ("B2", "kohai", "Skill levels drive assignment and rates across the existing work; one truth, two read paths."),
    ("B3", "minor", "The bitten arc: bite visibility, the house's answer from character, turning recognition, promises kept."),
    ("B4", "minor", "Farming through vanilla timed actions: the renewable arm of the material economy."),
    ("B5", "patch", "Performance and sensor audits; three borders born - cost and truthfulness closure."),
    ("B6", "minor", "Water as the second material axis and fire as a need: stores, runs, the shutoff day, hearth tending and lighting."),
    ("B7", "kohai", "Council abandonment and the wound's full life: decisions the state earns, on existing machinery."),
    ("B8", "kohai", "Standing moves both directions: endorsement, decay, lapse, walking out - the ratchet removed."),
    ("B9", "kohai", "The engine's own chemistry colors meetings; wire bulletins land as told knowledge in real receivers."),
    ("B10", "patch", "The foreign key domain contained, wounds persist through the pack, the county lets go at player death - repairs."),
    ("B11", "kohai", "Housemate teaching and player barter: the circle law's cost and the player in the economy."),
    ("B12", "kohai", "The verb wall collapses into the game's own menu idiom; the index completed - surface maturation."),
    ("B13", "kohai", "Need-driven promotion at election: the house reads its own counted claims and adapts."),
    ("B14", "kohai", "The repository gate and pre-commit hook: discipline made mechanical, proven by breaking the tree."),
    ("B15", "kohai", "Corpse looting with dignity rules: the one place dignity outranks need."),
    ("B16", "patch", "The undeclared-identifier audit and the edit-verification law: instruments and closure."),
    ("B17", "kohai", "Night-light gating and weather's weight: dark and storms shape the existing behaviors."),
    ("B18", "kohai", "The Ledger learns live content; the player claims ground and homes companions through existing machinery."),
    ("B19", "kohai", "Player teaching, vehicle crews, venture staffing, night watch: the player joins the work."),
    ("B20", "kohai", "Severity-first aid, the distress cry and its cost, the cook designation: professional shapes on existing lines."),
    ("B21", "kohai", "Population exchange with the zombie pool, porch music, evidence-based judging: composition with the world."),
    ("B22", "kohai", "Keepsakes and reading, derived work stations, skill-book study: identity beyond employment."),
    ("B23", "minor", "Government's complete shapes: five forms, deputies, turns, scarcity asks, division-driven schism."),
    ("B24", "patch", "The dead pact layer revived (one-character typo) and the creed distribution corrected - repairs with their border."),
    ("B25", "patch", "Work-judgment probing, quarrel drivers, identity-gate corrections: probing and repair."),
    ("B26", "patch", "Engine item-vocabulary corrections: four dead literals replaced with the engine's own surfaces."),
    ("B27", "minor", "The player as channel participant: one experience loop, inbound and outbound, restoring a missing player-visible contract."),
    ("B28", "kohai", "Newcomer reach, arrival rates, registers, trespass teaching: the road matured and measured."),
    ("B29", "patch", "Road-frequency display, ledger paging, window sizing: small surfaces made honest."),
    ("B30", "patch", "Publishing metadata and the false description repaired; attribution made precise."),
    ("B31", "patch", "The duplication border, fuel accounting, protocol borders: drift measured before unified."),
    ("B32", "patch", "The between-time chain repaired, mirror coverage, analysis discipline: the county's habits fixed with their instrument."),
    ("B33", "patch", "The two radii reconciled into one honest band; the shipped jar found stale and made current."),
    ("B34", "patch", "Menu gating, measured claim extents, queue-drop detection: silent failure classes closed."),
    ("B35", "kohai", "The claim lifecycle completed: unlearning by proximity, protection, carry-light wired to its walk."),
    ("B36", "patch", "The save-field guard, deploy survival, the catch audit: the discipline layer hardened."),
    ("B37", "patch", "The county's truths made singular: one band constant, age arithmetic, death causes, shutoff revision."),
    ("B38", "minor", "The county's scale derived from the installed map and the census graded against the real 1990 - assumption replaced by contract."),
    ("B39", "minor", "Acquisition provenance completed (unknown fails the gate) and places spent by being visited - scarcity becomes a model."),
    ("B40", "patch", "Named constants, lived provenance at genesis, the perk vocabulary map: names that keep arithmetic honest."),
    ("B41", "patch", "The gate audits itself: all mirrors run, and the player's own perception repaired after 79 batches blind."),
    ("B42", "patch", "The silent surfaces hunted as a class; census authority ratified (DR-012)."),
    ("B43", "patch", "The jar stamps its own version, session-state truth gated, the dormant economy's unwired halves wired."),
    ("B44", "patch", "Legible option labels and the Kahlua runtime boundary learned from a live crash."),
    ("B45", "patch", "Distance naming, Kahlua-gated compilation, the nil-name repair, the neighbour narration hold."),
    ("B46", "patch", "The player-reply channel repaired: two stacked defects that silenced the conversational surface."),
    ("B47", "patch", "The log-reading defect pass: census rebuilt true, noise measured down, boot truth."),
    ("B48", "patch", "The distribution arc: everybody was the same person - the hash pathology found by instrument and fixed."),
    ("B49", "patch", "Frame-time pacing disclosed on every claim; the voice cooldown moved to the wall clock; decay verified."),
    ("B50", "patch", "Engine behavior facts re-asked of the machine each run; the bridge throw contract graphed."),
    ("B51", "patch", "The dead stop growing quietly: death-time cleanup, budgeted walks, derived art, the save protocol border."),
    ("B52", "patch", "The era's integrity closed: derived counts, aligned names, the scout read whole, the answer domain sealed."),
    ("C1", "patch", "The catalog walked against the tree: 152 index links corrected, the maps drawn and held by Border 79, the gate made caller-independent."),
    ("C2", "kohai", "The version machine (DR-013): CAO's model adopted, the tier table as the one input, Border 80 holding every stated version to the replay."),
    ("C3", "kohai", "One person, one name (DR-014): the placeholder stamp gone, papers named by the menu's renderer, the neighbour's people keep his name, one menu folds his verbs through his own hands."),
    ("C4", "kohai", "The follow crosses windows and fences through the engine's own climbs; vehicle boarding pairs the seat with the mesh, folds into follow, and answers a clear order."),
    ("C5", "kohai", "World text becomes a person talking: the tell speaks the thing itself, coordinates leave every mouth, the innocent assert nothing - and the swallowed-function class is repaired and bordered."),
    ("C6", "kohai", "The inspect harness: a normal-launch panel and bound key over every store - seen/heard/told, standing, needs, last decision, tick cost - to the one JSONL, reading everything and teaching nothing."),
    ("C7", "kohai", "Superimposed, not beside (DR-015): the neighbour's per-survivor root stays as the person's one menu, retitled to the name and rebuilt from the county - never stripped, never doubled."),
    ("C8", "kohai", "The turn is real (DR-016): every dead shell reaches the engine's own die() through the corpse net, the person id rides modData through the engine's own copies, and recognition keys on what survives the turn - the [B3] arc's structural repair, javap-grounded (F-044/F-045)."),
    ("C9", "patch", "The pool is only the fungible crowd (F-046): one deletion-grade identity predicate, failing closed, at every consumer of the zombie list that deletes or choreographs - a spawn can no longer quietly take a person, and the removeFromWorld census is closed (Border 88)."),
    ("C10", "patch", "The promise swings at the body: the mercy kill aims at the one risen body carrying the person's [C8] mark, misses honestly, and carries the promise instead of taking the nearest stranger (Border 89)."),
    ("C11", "patch", "The bite kills on the engine's clock (F-047): the invented dormant formula replaced by the deterministic infection window read off the body or mirrored with citation; dormant turning mirrors shouldBecomeZombieAfterDeath (Border 90)."),
    ("C12", "kohai", "The front end speaks player (DR-017): mode-sentinels became worded switches, the coded pressure scale became the engine's own worded enum, decode tables and sentinel apologies left every label and tooltip; representation split from implementation at one declared seam (Border 91)."),
    ("C13", "patch", "No Claude-isms in the copy (DR-018): the sandbox surface rewritten in plain language, the register struck from the Ledger, and Border 92 freezing player-facing copy to a verbatim ratified declaration."),
    ("C14", "patch", "The sweep, round one: the paid-for defect classes hunted with real denominators - 216 pcall pairs, 262 call targets, 63 clock fields, every engine-authority comment - zero findings; the precise instrument promoted to Border 93, the imprecise one recorded as a method."),
    ("C15", "minor", "Whole minds survive the reload (DR-020): the perception store binds to ModData, the tick axis rebases once on load while the hours axis crosses intact, and every belief a survivor holds persists with the world - a new persistence contract for the mind (Border 94)."),
    ("C16", "kohai", "The dead census (DR-021 mechanism B, first half): an inert instrument reads the fungible crowd, the identity-bearing bodies, and the loaded and mapped extents through verified surfaces; the telemetry line carries density and projection with the sampling assumption stated (Border 95)."),
    ("C17", "kohai", "The crowd ledger (DR-021 state agreement): every pool take counted durable, restitution debt-bounded and paced on distant town ground through the engine's own virtual add, the dial off by default until the census has measured (Border 96)."),
    ("C18", "patch", "The first play receipts (F-048/F-049): a re-issued order no longer restarts the route it is already walking - which was cancelling window and fence climbs mid-transition and flipping survivors between FLEE and IDLE 292 times a session - plus the two exceptions the operator's log exposed."),
    ("C19", "kohai", "Partial receipts are receipts (DR-025): RECEIPTS.md records what play settles one observation at a time, the perpetual-untested blanket claim is banned from the doc-pack, and the day's own sessions seeded R-001/R-002 (Border 97)."),
    ("C20", "minor", "The county takes them whole (DR-022/023/024): the neighbour's people absorbed at world start and at birth through his one verified spawn seam, removed never killed, carried whole into county records, truth mirrored back, his caps neutralized and blocked on screen, verb parity kept (F-051/F-052, Border 98)."),
    ("C21", "patch", "Fail completely, never his way (DR-026): the absorption wrap spawns nobody on failure - loudly, with the Ledger carrying the seam - and never falls back to the neighbour's spawn; Border 98 inverted to hold it, its control the overruled [C20] draft."),
    ("C22", "patch", "The switch gates the field: the manual number fields on the county's own page grey and lock until their switch is on - vanilla's per-frame gating idiom, held by Border 91."),
    ("C23", "patch", "Deleted, not greyed: the overridden neighbour dials are removed at the settings-table seam before any row is built (the operator's restatement of DR-023); the [C20] grey-hook retired and refused by Border 98; DR-027 (no leash constants) recorded for the next substantive batch."),
    ("C24", "patch", "The anchor was never there (F-053, R-003): [C22]'s gating hook hung on a vanilla per-file LOCAL and silently never attached - reattached through the real global SandboxOptionsScreen onto the page panel instance, cannot-attach paths made loud through the Seams, Border 91 refuses the dead anchor with the photographed [C22] tree as its control."),
    ("C25", "minor", "Need reaches for what they know (DR-027): the ErrandRadius dial deleted everywhere - the probe is a named perception span, all four live needs and the dormant day fall back to the nearest KNOWN offering under the same property law, horizons derive from the engine's own cell, held knowledge revalidates and absence expires (Border 99)."),
    ("C26", "patch", "The click lands and the line holds (R-005/R-006, F-054, DR-028): talk answers bypass the murmur guards and the trust wall falls to the advertised split, dressing is outcome-verified by worn count with retry and fallback, and the wake law pushes foreign-claim wakes out, moves homes off held ground, and seats one body per square (Border 100)."),
    ("C27", "minor", "What one person knows, as one surface (SPEECH_ML_DESIGN.md rung 1): SAO_Knowledge answers nine topics with provenance and age, bundles the ratified conditioning (eight axes, trust, the moment), stays read-only by the one-loop law, is driven offline in the engine's own VM by Border 101, and the inspect panel gauges a person through it."),
    ("C28", "kohai", "The inference budget instrument (SPEECH_ML_DESIGN.md): a deterministic model-shaped workload timed on the game's own JVM from the debug menu, reported under BUDGET - the measurement the sizing decision cites; instrument, not capability (A23's precedent)."),
    ("C29", "minor", "The body is scaled from inside the animation player (DR-032): a Byte Buddy exit advice on the animation player's model-transform build applies a per-person size held only on SAO's own shell, uniform about the feet; the bridge sets and reports it, the body takes it from the age once dressed, the harness clicks it, and Border 104 weaves the installed class off the game and verifies it - the child bands follow in the age batch."),
    ("C30", "minor", "Age is a system on the county's people (DR-032): the bands run from six to ninety weighted from the 1990 resident population, five life stages (Getting Old's, credited) drift the living every ten minutes on the engine's own stats, the age decides the work, the pace and the size, and the old die of it on the life table (NCHS 1997, the nearest machine-readable year) - Border 105 drives it in the engine's own VM."),
    ("C31", "minor", "The child's day (DR-032): Growing Up's fear floor by age with the night, the comfort object and the kills that harden, read by the disposition's decisions and held on the engine's panic; literacy by the school years lived; the experience throttle on the shell and the birthday floors on strength and fitness; the kit from the child's own temperament; the child's head - Border 106 drives it in the engine's own VM."),
    ("C32", "minor", "Conditions are facts about a person (DR-032): drawn at the record's prevalence and gated by age, the mind's and the body's conditions bend the axes, add fear, set how long a belief is kept, what the body carries every ten minutes, what the skills lose and what a book costs; named in plain words on every surface; the two Build 42 condition mods required for the player's side - Border 107 drives it in the engine's own VM."),
    ("C33", "minor", "Habits are facts about a person (DR-032, S6): the drinker at the record's prevalence with The Alcoholic's phases, the drink taken through the engine's own fluid action or found where one is, the habit lost after three weeks dry and gained by drinking often; the users the county fell with on N and C's schedule, gone by the twentieth clean day; what a habit carries every pass, and the day that settles it - Border 108 drives it in the engine's own VM."),
    ("C34", "patch", "The moment carries the strain (DR-033): the knowledge surface reads the situation the controller's pressure names and whether the speaker is spent, beside the axes, trust and the moment; Decision 5 amended with the register floors under strain; Border 101 asks for both."),
    ("C35", "minor", "The county's gestures (DR-034): existing art copied with permission and credited - Hobbies' conversation gestures, sitting loops, instrument plays and dances, Week One's serving, coughs and claps - bound by SAO's own nodes and wired to the meeting, the voice's events, the evening seat and the porch tune; Border 109 holds file, node and name to each other."),
    ("C36", "minor", "The record on the county's calendar (DR-031, Day Zero slice 7): every vanilla channel re-keyed once per save to begin on the save day July 9, 1993 falls on, through the engine's own surface; every paper a container is filled with dated to the newest issue printed by the county's day or taken off the shelf; a sandbox switch on by default - Border 110 runs the arithmetic off the game against the installed jar."),
    ("C37", "minor", "An order lands through standing (DR-033, ruled): every ask the player makes of a person goes through SAO_Command - CAO's obedience check on the Standing that exists, a proven hand standing as a second, the envelope's own refusals - voiced with its reason and seen; Border 111 runs the check in the engine's own VM over the county sampled."),
    ("C38", "minor", "The era remembered (Day Zero slice 6): the knowledge surface carries before - born, the war, where from, home, innocent or hardened - and the day it started - the person's own first horror with its date and what it taught, the county's stamps aired as news, the record's first day for a radio owner - as claims with provenance; the chronicle reads its days as the county's own dates through the same calendar; Border 112 drives both topics in the engine's own VM."),
    ("C39", "minor", "The conditions are SAO's own (DR-032 amended): the two required mods are gone and SAO registers the county's conditions as engine character traits from shared Lua, vanilla's where vanilla has one, every cost taken from the vanilla trait its shape is anchored to; a survivor's drawn conditions ride their shell as traits, the player's chosen ones are asserted and driven through the same functions; Border 113 holds it and Border 107's requirement seam is inverted."),
    ("C40", "minor", "The county stands on its own (DR-035): nothing of this mod runs through another survivor mod unless the player asks - the absorption, the menu superimposition and the prompt hold are all behind switches that default off, so a fresh world reaches into another mod zero times; what stays always on calls none of their code, the manifests require nothing but the loader, and the description no longer claims a requirement [C39] removed; Border 114 holds the law."),
    ("C41", "minor", "The world before the spawn (DR-036, one precondition): on a save that has never been settled genesis reaches its target in one pass instead of six people at a time, and it runs ahead of the band in the tick, so the county exists in full before the first body is materialised; the pace and its unit slack are named once and stand unchanged for refill; Border 115 holds the budget, the flag and the ordering law the claim rests on."),
    ("C42", "minor", "Before the fall, an ordinary life (DR-036): an audit of the day-zero switch found it reached two things and that no decision anywhere asked whether the fall had happened, though the county had written three stamps for it since [B1] and read them only to print a chronicle; the county can be asked now - derived from those stamps and the calendar, never from the dial - and the night watch, the journey for a weapon or ammunition and scouting somewhere defensible all wait for it, while eating, warmth, treatment and mourning deliberately do not; Border 116 holds it."),
    ("C43", "minor", "The record's timeline moves onto the start date (DR-036): the lore is canonically 1993 and [C36] pinned it to the dates it carries, so a March start sat in a quiet world until July; a player now picks any date in 1993 and, with the Day Zero switch on, the record's own first day lands there - its week of ordinary county, then the collapse, then the rest in shipped order, with the broadcasts and dated papers moving with it and a later start moving it backwards; the week is the record's own number and not a setting, and a 1994 or later start is refused the move because that save is owed the years between simulated forward; Border 110 runs the placement and the year gate off the game."),
    ("C44", "minor", "They either build or they do not (DR-036, ruled through Crucible): nothing is forced and no pass authors a fortification, so the county gets a capability instead - a person who holds ground, after the fall has come, standing on their own claim and carrying a hammer, a plank and two nails they found, boards a window through the engine's own barricade calls at the shipped action's own price, the materials leaving their bag; the panel reports what they managed and nothing when they managed none; Border 117 holds that every clause can fail and that no genesis, population, absorption or harness path places one."),
    ("C45", "minor", "The years between (DR-036): a save beginning after the record's year runs the county's own machinery forward over the days it owes before anybody is materialised - the dormant day, the meetings, attrition, the softening, the age table and the settling of habits, every one of them the live county's own call - at the daily cadence F-055 measured, sliced so it cannot hang, after genesis and holding the band; houses and leaders arrive out of the encounters as they do in play and nothing is placed; Border 118 refuses a day that reaches for a group, a bond, a claim or a death directly."),
    ("C46", "minor", "The ground is read during the years (DR-036, DR-037): the engine holds only an eight by eight chunk window around each player, so during the years no claim is in any cell - a chunk is loaded on its own instead, read, and let go, one claim a simulated day on a rotation with ground read inside thirty days left alone; the county learns the ways into the place a person holds and how many are shut, off ground actually read, and the panel says it; it writes nothing at all, because saving a chunk writes into the player's own save through shared static buffers and nothing here has a live receipt - Border 119 refuses any save, barricade or placement in that path, and Border 118 admits the look only on that evidence."),
    ("C47", "minor", "The fence (SPEECH_ML_DESIGN Decision 4, ratified): no-invention is enforced by constrained decoding rather than instruction, so a speaker is handed a vocabulary it cannot escape - every fact position fillable only from that person's own claims, the slots read off the knowledge surface rather than listed, the comparison exact and never advisory, an unknown slot refused rather than allowed and a fence that throws refusing rather than permitting; built before any model because it is what makes a wrong one harmless; Border 120 proves it over a corpus off the game with the near-misses included."),
    ("C48", "minor", "How hard a place is to get into (DR-037): the scout weighed rooms, area and water and could not see a door, so a glass-fronted shop beat a house whenever it had one more room; it now counts the ways in off the loaded ground with the boarding's own predicate and breaks ties within one room's worth by them - a tie-break rather than a weight, because pricing a door against a room would be inventing a rate nothing gives; Border 121 fails if the count ever appears inside the score."),
    ("C49", "minor", "Survivor orders use the command check (DR-033): [C37] routed the player's asks through SAO_Command and left survivor-to-survivor orders alone, so three decided for themselves - the keeper rousing the house checked nothing, an owner telling a trespasser to go was obeyed by anyone not starving, and a housemate objecting to somebody leaving used a hardcoded authority test written at that one site, which is the kind of table DR-033 rules out; it is deleted and all three go through SAO_Command, with no weights or thresholds added - three Standing facts became inputs, each worth what a proven hand is worth: a divided house withholds the leader's office from members leaning the other way, a designation gives standing in its own matter, and a claim gives standing in the matter of leaving it. Same class as C42 - an audit found decisions that did not consult a fact the county already kept, and wired them to it. Border 122 holds it."),
    ("C50", "kohai", "What a survivor says follows what they have learned (DR-036, Day Zero slice 3): every line table in SAO_Voice was flat, so a county that had learned nothing still fled saying a count and warned each other with a name that somebody acquires; the five tables about the dead and about violence are split by register now and the register is the county's own innocence boundary ([B1]/T-002), the taught lists unchanged, an unreadable lesson store keeping the taught register, and the first lesson audible once because after it the store is not empty. A coherent extension of an existing capability - the voice surface gains a dimension, no new state and no new threshold - so kohai rather than minor. Border 123 holds it."),
    ("C51", "minor", "The habits are the player's too (DR-032, the society arc's S6): [C39] registered the county's conditions as engine traits and left the habits behind, so nothing offered one at creation, nothing stamped one onto a survivor's shell and nothing would have driven one on the player if it had. Five are registered now - drinker, cocaine, opioids, stimulants, sedatives - each anchored to base:smoker and taking its cost of -3, because the habits differ only in schedule and the engine ships exactly one trait of that shape; cannabis is skipped because its source gives it no withdrawal and a costed trait that does nothing would be a lie about the game; smoking is left to vanilla's own SMOKER. The player gets a store for the habit to live in (their own modData, bound as a stand-in record) without which the dry clock never resets and the habit never lapses, the withdrawal drives on their own ten-minute pass, and a drink is read off CharacterStat.INTOXICATION rising rather than hooked to an action. Border 124 holds it; Border 72 caught three per-id tables with no forget and they have one."),
    ("C52", "kohai", "Psychosis and insomnia get their figures: two rows in the conditions table had stood at zero since [C32] with the reason in the file - no primary figure of the era had been read - so neither mechanism could ever fire for anybody. Psychosis draws at 70 per ten thousand off Kendler et al., Arch Gen Psychiatry 1996;53(11):1022-31 (broad nonaffective psychosis, clinician diagnosis, lifetime, 0.7 percent), and insomnia at 1020 off Ford and Kamerow, JAMA 1989;262(11):1479-84 (10.2 percent of 7954 ECA respondents noting insomnia at the first interview), the row saying plainly that this is a complaint recorded once rather than a chronic diagnosis and naming the persistence figure that would replace it. Border 125 turns the sourcing rule into a mechanism: every row names a year or points at the table above it, and every constant must be reachable from the comment's own figures by a derivation the row names - it caught four habit rows citing nothing of their own. An extension of an existing capability with no new mechanism, so kohai."),
    ("C53", "kohai", "Who goes along weighs who is asking (DR-036, Day Zero slice 4; DR-033): [B19]'s joining weighed everything about the hearer and nothing about the trip or the caller. The caller's office over the hearer now enters the pull in SAO_Command's own currency - a leader's call above a second's above a peer's, no number invented at the site, the divided house arriving with it - and a warpath asks the hearer's own envelope, so nobody is persuaded into a fight they would not take. Ported to the joining mirror in the same batch, per that script's doctrine, with each house's leader derived the way Standing derives it. The mirror then refused the first claim made about the change and produced F-056 instead: in the converged county the pull's median is 1.28 against a threshold of 0.55 and 96 percent of invitations clear it before any term is consulted, so the office carried nobody there; a sixth sweep over a house that formed recently is where it carries 46. An extension of an existing capability, so kohai."),
    ("C54", "patch", "The objection picks the car (Day Zero slice 5): SAO_Standing.roadworthy appraised a house's whole motor pool and returned one car, and the venture then applied the goer's own objection to that one - so somebody who has learned that noise is a debt discarded the yard and walked past a quiet runner they would have taken (F-057). The loudness ceiling goes in with the ask now, so what comes back is the roomiest car this person would actually take; passing nothing gives the old answer, which is what the panel does; a yard of only loud runners still ends in a walk, said as a choice about the yard rather than about one car; and the second loudness test at the call site is deleted rather than left sitting dead. An in-place correction of a capability that already existed and no boundary moved, so patch. Border 126 holds it, with the pre-batch tree as its control."),
    ("C55", "kohai", "Seeing a death is not seeing who did it (Law 1): the standing gap said the witness rule keys on a recent sighting of the victim rather than on the killing, and the freshness window is two seconds so that half is nearly not a gap - but nothing ever asked whether the witness saw the KILLER. The engine's attacker tag named who did it and both the death site and the wounding site spent that name on a witness whose only belief was about the victim, so somebody ten tiles from a victim shot from forty could declare a blood feud on a person behind a wall they had never seen. The death still lands, mourns and travels, because Law 1 calls oblivion a failure too; the name lands only where they could have seen who, asked in each half of the county's own currency - a fresh observed belief of the killer at the place for a live witness, the positional question for a dormant one. Border 127 lifts both predicates out of the controller and runs them in the engine's VM. A correction inside an existing capability that widens no boundary but changes what a whole class of survivors comes to believe, so kohai rather than patch."),
    ("C56", "patch", "Borders skip when the game is absent: the operator asked why nothing had reached the public repository, and there were two reasons. Publishing was never in the close order, so the local tree stood 112 commits ahead of the single squashed root pushed on 2026-08-31 - the whole C era - and NEO.md carries the step now on the operator's ruling: one squashed commit to origin/main at each close, after the deploy. And a push would have failed CI: the workflow runs the gate on a machine without the game, its own comment says such borders report SKIPPED, and fifteen exited 1 instead, which check.sh reads as the gate refusing. The comment said six and thirty-four tools read the install now, so a count in prose went stale in silence and eleven borders acquired the wrong behaviour unseen. All thirty-four skip cleanly; Border 128 holds it, and was itself wrong three times first, each time accusing a tool. The four Laws in NEO.md are rewritten plainly on the operator's direction, content unchanged. An in-place correction of the instruments with no capability boundary moved, so patch."),
    ("C57", "patch", "A skip is not a vacuous pass: the backfill landed and CI refused it for a defect beside the one [C56] fixed. Border 54 runs every gated mirror against a tree with no Lua and refuses any that still pass, and it read a border that declines to judge - returns 0 and prints SKIPPED because it reads the installed game - as one that passed on nothing. On a machine without the game, which is CI, eleven did. A fifth state, on the argument run_blind's own docstring already makes for separating ran-and-refused from was-never-asked. Eight of the eleven predate [C56], so they had been read that way on every machine but the operator's, and CI Verify has never succeeded on this repository. An in-place correction of an instrument, so patch."),
    ("C58", "patch", "The codeql-action halves travel together: two dependabot pull requests had stood open and failing since 2026-08-31, both with the same error - a configuration loaded for 4.37.7 while running 4.37.9. init and analyze are two dependencies to dependabot and one action to CodeQL, so a pull request bumping either half on its own produces a version mismatch CodeQL refuses, and neither could ever have passed because the fix is in neither. Both pins move to v4.37.9 in one commit, the tag read off the upstream repository rather than taken from the pull requests, and the dependabot config groups the action so a future bump carries both halves. Repository mechanics with no capability touched, so patch."),
    ("C59", "patch", "Main is protected and batches arrive by pull request: [C56] through [C58] were pushed straight to origin/main - thirty-one commits, no branch, no pull request, no merge - and CAO, which is the standard for how this repository publishes, lands work on main through squash-merged pull requests. Nothing stopped the direct pushes because nothing was set to: CAO's main is protected and SAO's answered 404. Main is protected now on the same shape with this repository's own checks, and NEO.md's publishing convention - which had written the mistake down as the rule two batches after it was made - says branch, pull request, merge. The thirty-one commits stay, because force-pushing the public record to make it look like the process was followed is worse than the record showing it was not. Repository mechanics, so patch."),
    ("C60", "minor", "The player's looting spends a place ([B39]'s standing gap): a survivor taking something calls SAO_Places.take and the place is spent for everybody, and the player's looting called nothing - so a shop the player had stripped still read as full stock and the county kept sending foragers to it. Read rather than hooked: the engine marks a container looted when it has been emptied (ItemContainer.isHasBeenLooted, javap-verified, a flag SAO never writes), so the ground itself is the reading, walked the way the needs layer already walks containers and taken to the place ledger on the player's own ten-minute pass. The tally is raised and never lowered, held at capacity, and the refill stamp moves only when the count raises it. Border 129 holds it. A player-visible simulation capability the county did not have, so minor."),
    ("C61", "kohai", "One clock for how long this has been going on: three readers answer how far into the collapse a save is, and SAO_History.clockMonths - the number that ages what every person KNOWS, through the split clock into contact months and from there the lesson pool and the claims a person carries - was reading SandboxVars.TimeSinceApo while [C42] had already ruled the fall is read from the record's calendar and never from the dial. A 1996 save ran a thousand days of county forward ([C45]) and then told every survivor in it they were one month in. It reads the calendar now, answers zero before the fall because a county without its outbreak has nobody who lived through one, and keeps the dial only where the calendar cannot be read at all, so the module stays offline by construction. Border 130 holds it, and its own first seam compared identifiers rather than call forms and failed on this batch's comment. A correction inside an existing capability that changes what the whole county knows, so kohai."),
    ("C62", "kohai", "One clock for the county, and the years pass moves it: [C45] lives the days a later save owes by calling the county's own systems one simulated day at a time, and it never moved the clock those systems read. Sixty-eight places asked GameTime for the world age in hours and GameTime does not advance while the years run, so every system that gates on a CHANGE of day saw one day for the whole span - attrition stamped lastRiskDay once and killed nobody after it, the water and food stamps never advanced so nobody grew thirsty, driftStandings returned on lastDriftDay for every day but the first, and three simulated years of winter ran in the save's start month. SAO_History gains the county's clock beside [C61]'s: the day being lived during the years, the days behind the record plus the game's own hours after them, meeting at the same number so a stamp made during the years stays in the past; the calendar month those hours fall in, anchored in SAORecord.countyMonth0; and the record day, which clockMonths now reads so what a person has had time to learn grows across the span. Sixty-seven sites and four season reads swept, leaving SAO_History the only module that asks the engine, and runTheYears publishes the day it is living before it lives it rather than once a slice. Border 131 holds it and its control is driftStandings on three consecutive simulated days, which moves nothing after the first on the pre-batch tree. Structural maturation of an existing capability - the whole tree gains one answer to what hour it is and [C45] does what it was written to do - so kohai."),
    ("C63", "patch", "A day-zero start owes no years: DR-036's two halves were deciding the same fact separately. [C43] moves the record's own first day onto a 1993 save's start when the day-zero switch is on, so the outbreak arrives leadIn() days in; [C45] counted the calendar days from the record's day 0 to the save's start and lived them before anybody was spawned; and daysBehindAtStart knew nothing about the switch. Measured off the game against the built class: a July 20 1993 start ran 11 days, an October 1 start 84 and a December 15 start 159, every one of them handed to a player whose record said the outbreak was eight days away. daysBehindAtStart takes the switch now and asks mayShift - the same refusal shiftTo makes - so a save the record may be moved onto owes nothing while a 1996 start still owes its thousand. countyMonth0 is handed that number rather than deriving it again, and SAO_History.daysOwed is the one reader on the Lua side, off the same sandbox switch SAO_Record.placeTimeline reads. The switch was chosen over a flag set by shiftTo because shiftTo runs from a module that legitimately never runs when the record option is off. Border 132 holds it, controlled against the [C62] tree where the same December start still owes its 3816 hours; Border 110 gains the arithmetic and Border 118 names the function rather than one spelling of its signature. An in-place correction of an interaction between two shipped capabilities, moving no boundary, so patch."),
    ("C64", "patch", "The blanket claim is gone from every document that carried it: DR-025 banned the perpetual-untested claim on 2026-08-29 and Border 97 has held it out of SESSION_STATE.md and PLAYABILITY.md ever since. The operator found it alive thirty-five batches later in README.md, and it was in five places - README.md, both mod.info descriptions (the string a player reads on the Workshop page), PLAYABILITY.md and PUBLISHING.md. Three were files the border never opened, because it read exactly two documents named as literals in a loop; the fourth was in a file it did open and the pattern walked past the wording. The claim is false and has been since [C19]: RECEIPTS.md holds six receipts, several of them defects found by playing. Border 97 now reads every root .md and both mod.info files, twenty-six documents, with RECEIPTS.md and DECISION_REGISTRY.md exempted by name because they quote the claim while explaining the ban, and it refuses to run against fewer than three. It also holds the receipt count the README states against the ledger, which is the durable half - a negative nobody can check does not decay, it stops being true. Border 43 reads the README's Status coordinate, which stood at 1.10.6.0 against a tree at 3.10.2.1 because the README carries no header cell to be caught by, and Border 43 gained the argv[1] control mechanism it never had. An in-place correction of the documents and the instruments that hold them, moving no capability boundary, so patch."),
    ("C65", "minor", "The years pass leaves a trajectory: the operator ruled that a late start cannot afford first-principles generation at distance and chose a learned trajectory model fitted to the generator's own per-year runs, and there were no runs. [C45] mutates state in place, so the county at the end answers what it is like now and destroys what happened, which is the thing being modelled; the only lines reaching the telemetry file during a span were incidental death and lesson events with no boundary around them. SAO_Telemetry was already built on that exact argument at [B38] and had never been pointed at the years. Every line now carries the run it belongs to while one is open and none outside it; T.run opens and closes a span and T.conditions records what it was run under - risk, trust, desperation, refill, traffic, population and newcomer settings, the day-zero switch, the save's start date and the days owed, none of which is recoverable from the county lines afterwards. The identifier is made once and kept in the save, because a span sliced across hundreds of passes and a reload is one run. The county line gained dry, hungry and their worst cases - two of them declared in T.county since [B38] and never assigned - plus groups, grouped, largestGroup, claimsHeld, waysIn and waysShut, the last two being [C46]'s survey that only the inspect panel ever read. oneYearsDay writes one line per simulated day. Border 133 drives the real module in the engine's VM with getFileWriter stubbed, so every assertion is made against the JSONL actually emitted; controlled against the [C64] tree, where the county line carries seven fields and no run line exists. The first draft failed three borders and each was right: 118 refused a simulated day calling T.county because the live county did not run it daily, which was the deferral in the draft and is fixed at the source now - dailyCounty is one function run by both; 33 caught five conditions fallbacks that were not the screen's declared defaults, so a run on default settings would have been recorded under settings nobody chose; 108 caught the instrument able to throw into the simulation it measures; and 74 caught the consequence of fixing 118 - a daily county line is a daily walk over a store the dead never leave - which is declared unbudgeted on the argument that it is linear where driftStandings was quadratic and that a cursor would make the count wrong rather than slow. A new runtime contract that the trajectory corpus and everything fitted to it depend on, so minor."),
    ("C66", "minor", "The county carries its own randomness: forty-two places asked the engine through ZombRand, which carries no state SAO can see, set or write down, so no county could be run twice - a reported defect could not be reproduced and a sweep moving one dial could not tell the dial from the draw. The operator chose the wider option: SAO carries its own generator and every draw goes through it, seeded off the save and private. SAO_Rand is counter-based rather than a state machine, so the state is a seed string and a count that persist into ModData as-is, and the arithmetic is [B48]'s already-verified split-multiply FNV rather than a second answer. The first draft ramped: SAO.Hash.of(seed, counter) % n put the counter in the salt position and read FNV's low digits, and 1626 of 1999 draws mod one hundred were exactly the one before plus one - [B48]'s arithmetic progression through a different door, on top of [B38]'s finding that the low bits are a parity checksum. Four candidate forms were measured before one was picked; the counter goes first and the answer comes from above the low sixteen bits, giving chi-square 0.0 at n=2, 1.9 at n=6 and 101.6 at n=100 against critical values of 10.83, 20.52 and 148.2. Border 134 measures the draw and does not read the formula, because a border asserting the module calls SAO.Hash would have passed the ramp; its own first draft cleared ModData while the module's memoised store survived and reported the module irreproducible when the probe had failed, so each behaviour case runs in its own process now. Controlled against the [C65] tree, which has no module and forty-two direct engine calls. The sweep also gave the draw one arity where the engine declares two, so the nine sites using ZombRand(a, b) handed their low bound over as a modulus and collapsed to a constant - every goal offset to the anchor tile, the fallback drift to no drift, every broadcast to SAOW-0 - which Border 22 caught indirectly by reading a spelling of the drift line the sweep had moved. A new runtime contract - every draw in the mod changes source and a save becomes reproducible - so minor."),
    ("C67", "minor", "Founding a company dissolved it: no company has ever formed in this project, in a sweep or in a save, since companies were built. A company was founded by joining one member and then the other, and joinGroup elects, and electLeader performs the widow release at a roster of one - a group of one is a memory rather than a membership, so the last member is released. The first join therefore made a house of one and freed its only member; the second join made a house of one again and freed that one too; the house was empty before the second line finished. Everything downstream of a company was unreachable code - the election, the creed, the designations, the chair, the steward, feuds, pacts, schisms, the radio news of all of them, and the perception gate that reads a company from three tiles away - while reading as if it worked. checkSchism batch-joins its leavers and elects once with a comment saying exactly why, so the hazard was known at one site and neither site where a company is BORN had the same treatment. S.formCompany writes the roster whole and elects once, over a house that already exists, and the three founding sites use it: the dormant road meeting, the observed conversation, and Knox adoption - which had the defect from a different direction, adoptees arriving one at a time so that each was released before the next appeared and the house could never assemble however many were adopted. The widow release is not removed and is not the defect: it is a rule about a roster that shrank and it is right, but electLeader is called from both directions and cannot tell growth from loss, so a house being born read as a house ending. A house of one still may not be founded and joinGroup is unchanged, because once there IS a house a single joiner is exactly right. Measured across twenty-four counties of 216 people over 1096 owed days against the real shipped map - eleven towns, 89 spawn points, 2831 buildings read from the game's own .lotheader files, one OS process each - the counties forming at least one company went from 0 of 24 to 24 of 24, with a median of 17 companies where there had been none. The row that names the defect is the trust line: 264 pairs already stood above the 0.5 company bar in the broken tree and not one of them could keep company, so the trust economy had been working the whole time and nothing could be built out of it. Genesis originates people in bonded units at 0.85 for family and 0.70 for friends, standing on the same tile, so a family of two should have kept company on the first pass after genesis in every county ever run. Survivors at day 1096 rose from a median of 1 to 4 and counties with anybody alive from 16 of 24 to 21 of 24, which was not designed and is not claimed as a target - people who keep company live longer. Border 135 measures the house rather than the call, because a border asserting that the site calls joinGroup twice would have passed the defect: it runs the real modules in the engine's VM, founds a company however the tree in front of it founds one, and asks whether anybody is in it, holding also that a shrinking house still releases its widow and clears their designation, that a house of one may not be founded, and that a standing house still takes a joiner. Controlled against the [C66] tree, where the branch takes the two consecutive joins and the house comes back empty. A capability the mod declares and could never perform now performs, so minor."),
]

TIER_MEANINGS = [
    ("major", "Formal release, project-identity, or supported-compatibility boundary. No unit requires it; the odometer reaches it by cap."),
    ("minor", "A new player-visible simulation capability or a new authoring/runtime contract."),
    ("kohai", "A coherent extension, integration, or structural maturation of an existing capability."),
    ("patch", "An in-place correction, verification closure, or repair that does not move a capability boundary."),
    ("maturity", "`pre-alpha -> alpha -> beta -> rc`; moves on evidence (play receipts), never on arithmetic. Everything here is pre-alpha."),
]


def parse_version(text):
    m = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)\.(\d+)(?:-([\w.-]+))?", text.strip())
    if not m:
        raise ValueError(f"malformed version {text!r}")
    maturity = m.group(5)
    if maturity and maturity not in MATURITY_LADDER:
        raise ValueError(f"unknown maturity {maturity!r}")
    return [int(m.group(1)), int(m.group(2)), int(m.group(3)), int(m.group(4)), maturity]


def fmt(v):
    major, minor, kohai, patch, maturity = v
    return f"{major}.{minor}.{kohai}.{patch}" + (f"-{maturity}" if maturity else "")


def bump(v, tier):
    major, minor, kohai, patch, maturity = v
    if tier == "major":
        major, minor, kohai, patch = major + 1, 0, 0, 0
    elif tier == "minor":
        if minor == MINOR_CAP:
            major, minor = major + 1, 0
        else:
            minor += 1
        kohai = patch = 0
    elif tier == "kohai":
        if kohai == KOHAI_CAP:
            if minor == MINOR_CAP:
                major, minor = major + 1, 0
            else:
                minor += 1
            kohai = 0
        else:
            kohai += 1
        patch = 0
    elif tier in ("patch", "hotfix"):
        if patch == PATCH_CAP:
            patch = 0
            if kohai == KOHAI_CAP:
                kohai = 0
                if minor == MINOR_CAP:
                    major, minor = major + 1, 0
                else:
                    minor += 1
            else:
                kohai += 1
        else:
            patch += 1
    elif tier == "initial":
        pass
    elif tier.startswith("maturity-"):
        maturity = tier.split("-", 1)[1]
        if maturity not in MATURITY_LADDER:
            raise ValueError(f"unknown maturity tier {tier!r}")
    else:
        raise ValueError(f"unknown tier {tier!r}")
    return [major, minor, kohai, patch, maturity]


ROW = re.compile(
    r"^\| \[([A-Z]\d+)\]\((Batches/[^)]+)\) \| (\d{4}-\d{2}-\d{2}) \| (.*?) \| (.*?) \|$",
    re.M)


def log_rows():
    """Batch id -> (date, name, threads-cell), in log order. The index owns
    the names and dates; this tool never respells them."""
    rows = {}
    for m in ROW.finditer(BATCH_LOG.read_text(encoding="utf-8")):
        rows[m.group(1)] = (m.group(3), m.group(4), m.group(5))
    return rows


def replay():
    v = parse_version(REPLAY_START)
    trace = []
    for batch, tier, rationale in UNITS:
        v = bump(v, tier)
        trace.append((batch, tier, rationale, fmt(v)))
    return trace


def render():
    rows = log_rows()
    trace = replay()
    current = trace[-1][3]
    tip = UNITS[-1][0]
    nxt = f"{tip[0]}{int(tip[1:]) + 1}"
    lines = [
        "# Version map",
        "",
        "The regulatory version replay: the closed batch chronology classified",
        "one unit per batch, the coordinate computed under CAO's caps. The",
        "version is a machine (DR-013): nobody picks the number - to disagree",
        "with the coordinate, disagree with a tier in",
        "[`tools/version_replay.py`](tools/version_replay.py) and run",
        "`python tools/version_replay.py --write`; the map and `VERSION`",
        "follow. Border 80 refuses a tree whose stated versions disagree with",
        "the machine. Names, dates, and threads below come from",
        "[`BATCH_LOG.md`](BATCH_LOG.md), which owns them.",
        "",
        "| Field | Current state |",
        "|---|---|",
        f"| Schema | `{SCHEMA}` (CAO's `cao.version-model/1`, adopted) |",
        "| Form | `major.minor.kohai.patch-maturity` |",
        f"| Hard caps | minor {MINOR_CAP}; kohai {KOHAI_CAP}; patch {PATCH_CAP} |",
        f"| Replay start | `{REPLAY_START}` |",
        f"| Current version | `{current}` |",
        f"| Closed chronology | `A1-{tip}` |",
        f"| Next batch | `{nxt}` |",
        "| Executable source | [`tools/version_replay.py`](tools/version_replay.py) |",
        "",
        "## Tier meanings",
        "",
        "| Tier | Meaning here |",
        "|---|---|",
    ]
    for tier, meaning in TIER_MEANINGS:
        lines.append(f"| {tier} | {meaning} |")
    lines += [
        "",
        "## Chronological replay",
        "",
        "| Batch | Date | Tier | Resulting version | Name | Classification |",
        "|---|---|---|---|---|---|",
    ]
    for batch, tier, rationale, version in trace:
        date, name, _threads = rows[batch]
        lines.append(f"| `{batch}` | {date} | {tier} | `{version}` | {name} | {rationale} |")
    lines += [
        "",
        "## The former number",
        "",
        "`0.6.0.0` was declared at [B12] by the former policy (\"nineteen",
        "batches of shipped surface\") after the prior assistant bumped through",
        "hundreds of diary entries, and the former map walked to it in six flat",
        "minors. The machine replay of the recatalogued units supersedes that",
        "walk: under the caps, twelve minors of capability roll the major - the",
        "odometer crossed `1.0.0.0` at `A26` (the county wire, the thirteenth",
        "minor) by arithmetic, not by honor. The old number undersold the",
        "catalog; neither number was ever a release claim.",
        "",
        "## Maturity",
        "",
        "`pre-alpha` throughout: maturity moves on play receipts and no batch",
        "has one. The offline harnesses and the border gate are what stand in",
        "the meantime, and they are not play.",
        "",
        "## Next movement",
        "",
        f"`{nxt}` is the next batch. Its content determines its tier after it",
        "exists:",
        "",
        f"| If {nxt} is | Result |",
        "|---|---|",
    ]
    v = parse_version(current)
    lines.append(f"| patch or hotfix | `{fmt(bump(v, 'patch'))}` |")
    lines.append(f"| kohai | `{fmt(bump(v, 'kohai'))}` |")
    lines.append(f"| minor | `{fmt(bump(v, 'minor'))}` |")
    lines.append("")
    return "\n".join(lines)


def validate():
    faults = []
    rows = log_rows()
    unit_ids = [u[0] for u in UNITS]
    if unit_ids != list(rows.keys()):
        missing = [b for b in rows if b not in unit_ids]
        extra = [b for b in unit_ids if b not in rows]
        faults.append(
            "the tier table and BATCH_LOG.md disagree about the closed "
            f"chronology (unclassified: {missing or 'none'}; not in the log: "
            f"{extra or 'none'}; or the order differs)")
    trace = replay()
    current = trace[-1][3]
    stated = VERSION_FILE.read_text(encoding="utf-8").strip()
    if stated != current:
        faults.append(f"VERSION states {stated}; the replay derives {current}")
    if not VERSION_MAP.exists() or VERSION_MAP.read_text(encoding="utf-8") != render():
        faults.append("VERSION_MAP.md is not the machine's rendering - run "
                      "python tools/version_replay.py --write")
    for info in MOD_INFOS:
        m = re.search(r"^modversion=(.*)$", info.read_text(encoding="utf-8"), re.M)
        if not m or m.group(1).strip() != current:
            rel = info.relative_to(ROOT).as_posix()
            faults.append(f"{rel} states modversion="
                          f"{m.group(1).strip() if m else 'NOTHING'}; the replay derives {current}")
    return faults, current


def main():
    write = "--write" in sys.argv[1:]
    if write:
        VERSION_FILE.write_text(replay()[-1][3] + "\n", encoding="utf-8")
        VERSION_MAP.write_text(render(), encoding="utf-8")
    faults, current = validate()
    print("=" * 74)
    print("THE VERSION IS A MACHINE")
    print("=" * 74)
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  80) version replay: {len(UNITS)} closed units classified; the machine")
    print(f"      derives {current}, and VERSION, the map, and mod.info all state it")
    return 0


if __name__ == "__main__":
    sys.exit(main())
