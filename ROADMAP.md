| Document | Survivor Awareness Overhaul Roadmap |
|---|---|
| Version | `3.9.0.0-pre-alpha` |
| Author | ellyj3rain |
| Repository | `ROADMAP.md` |
| Status | CANONICAL - thread map, backlog, live gates. |

# Roadmap

## Gate order

Each gate is narrow enough that a failure is attributable to one subsystem. A gate
is not passed on code presence; it is passed on observed behavior.

### G0 — Verification

The engine control surface is established from the installed build with
file-and-line evidence: NPC flagging, the control-variable path consumed during
update, spawn-region data, inventory and equipment paths, occlusion queries.
Nothing proceeds on remembered API behavior.

### G1 — One survivor in the world

One NPC body is constructed from verified APIs, spawns at a valid square drawn
from real spawn-region data, keeps distance from the player, renders as a human,
walks to a reachable destination on engine pathfinding, survives cell reload and
save/quit/reload, and is removed cleanly on teardown. Population stays capped at
one until every condition holds.

### G2 — Perception

The survivor maintains a private belief set with provenance and decay. It can
report what it believes and where that belief came from. No decision in the tree
reads world state directly.

### G3 — Execution loop

Threat, injury, need, travel — one action owns the body, executors finish, fail or
are cancelled cleanly, and failed traversal edges cool down instead of being
retried immediately.

### G4 — Disposition

The preference ordering under risk becomes a real substrate rather than constants.
Skill changes latency, precision and breadth without producing behavior outside
the human envelope.

### G5 — Standing

Relationships, group membership, territory and orders gate what a survivor may do,
separately from what it wants to do.

## Day zero forward (DR-036, 2026-09-07)

The case this mod is for: a player checks the box for the start of
it and begins in the county before the fall, then watches the whole
decay happen.

Day zero is also the GENERATOR, which is what makes the rest of this
arc cheap. A county started at the fall already produces the
structure by itself - people collaborate, choose ground and settle
it, hold or lose it, survive or do not - so nothing here fabricates
those results. Where a player starts at a distance from the fall
instead, the same machinery runs forward over the elapsed span with
nobody watching, and whoever is alive at the end is who they meet.
A start with the box unchecked is a first-class case too and is not
to be sacrificed to either.

So the Day Zero arc below is the priority: every hour spent making
that path richer is an hour spent on all three.

Preconditions and slices, none of them the whole thing:

1. SHIPPED as `[C41]`: the county exists before anybody meets it -
   on a fresh save genesis reaches its target in one pass, ahead of
   the band. Nothing can be watched or run forward while the county
   is still accreting around the player. Houses, leaders and feuds
   stay derived and are not authored at genesis.
2. The Day Zero arc's own slices: outbreak dynamics live-verified,
   chaos legibility, ventures socialized, vehicles as composition.
   Chaos legibility is half done. SHIPPED as `[C50]`: what a survivor
   says follows what they have learned. Every line table in
   SAO_Voice was flat, so a county that had learned nothing still
   said "Too many" and "Dead nearby" - counts and names somebody
   acquires. The five tables about the dead and about violence are
   split by register now, and the register is the county's own
   innocence boundary ([B1]/T-002, "having learned nothing yet"), so
   no threshold is invented and nothing new is stored. The crossing
   is audible: SAO_Lessons already dated the first lesson and called
   it the day the world changed for that person, and they say so
   once. Border 123 holds it. The other half is the wire: before the
   fall it is a hobbyist beacon ([A29]) and it has no collapse to
   carry yet.
3. The elapsed clock: read how far from the fall this save begins
   (the engine's own start year and months-since-apocalypse) and
   make it one number every system can ask for.
4. SHIPPED as `[C45]`: running the days for a later start - the
   dormant day, the meetings, attrition, the softening, the age
   table's roll and the settling of habits driven forward over the
   days the save owes, at the daily cadence F-055 measured, sliced so
   it cannot hang, after genesis and holding the band. Houses and
   leaders arrive out of the encounters as they do in play. Still
   record-side only: nobody has a body during the years, so nothing
   anyone does to a building happens yet - loading the ground per
   claim while they run is the next piece, and F-055 puts that ground
   at 432 chunks and 406 KB.
5. What a place becomes: ground held, fenced and built on over time;
   settlements of a size the elapsed time supports; enclaves that
   stay small; groups that confederate and come apart; trade between
   places.
6. Knowledge over the span: what the old world knew decaying at the
   county's own rate, what this one learns accumulating, and books,
   papers and media carrying either on where they survive.
7. The dead of those years: burials, graves, and a county that
   remembers who is in them.

What those years actually contain is DR-037: houses first, because
people take the buildings that are there; bespoke building only where
it is necessary; and the whole shape driven by how many people exist
and what risk they are under rather than by any settlement schedule.
The pass runs for real - the ground is loaded and the work happens -
and what that costs is to be measured rather than assumed. The stakes
come from the zombie side and are developed in the sibling project.

Governance stays the Standing pillar's - creeds, forms, elections -
and may gain a learned component. Where the people understand the
world and use the engine's own tools, this arc meets Speech
(DR-033). Week One's art is already crossed ([C35]) and dresses the
near end.

## Standing on our own (DR-035, 2026-09-07)

No capability planned here may require another survivor mod, and no
slice may be scoped around one being installed. The neighbour
framework's people and menus are reachable behind a switch that
defaults off ([C40]) and are not a factor in anything above.
ZombieBuddy remains the one requirement: it loads this mod's own
Java component and cannot be replaced from inside a mod.

## Deferred

- Settlement and base construction.
- Faction-level simulation.
- Companion command surfaces.
- Anything requiring a UI beyond diagnostic output.

Deferred items are not scheduled. They are recorded so the gates are not widened
to accommodate them.

---

## Standing note ([A11])

The gate ladder above remains the verification ORDER, and its live-run
criteria still bind. As of [A11] the construction has run far ahead of live
verification: G0 passed with evidence; G1 passed live through spawn/render/
release/rematerialize; everything since the movement transplant is compiled
and structurally checked but live-unverified (see SESSION_STATE honesty
ledger). Live verification is experiential - the operator plays; findings
feed batches. The backlog lives at the tail of each batch record ("Next"),
superseding any list that stood here.

---

## The society arc (DR-006, opened [A14])

Gate order, each verifiable in play:

### S1 - The clock and the past (corrected [A14])
World-age gradient: sandbox start month derives an EPISTEMIC AGE; each
survivor holds a SMALL set of settled claims with provenance (paid-for /
seen / told) that echo into traits and enter the lesson economy. Text is
only a rendering of the claims, produced at read time, never stored; the
dead are a rare attribution on the costliest lived claim, not a cast.
(The original gate text asked for generated backstories; [A14]'s operator
review named that a scope tilt toward fiction - claims are the record.)

### S2 - Lessons
Deaths leave LESSONS (cause-of-death -> cautionary knowledge); lessons
transmit along the existing word-of-mouth/testimony roads; behavior
consumes them (a survivor who knows "Marcus died forcing a claimed door"
weights forced entry lower). Clock seeds the starting lesson pool.

### S3 - Governance
Leaders with consumers: election by trust-sum inside groups; leader
choices weight group homing/flee/settlement; politics: standing between
members shifts leadership; the player influences by the same standing
machinery.

### S4 - Settlement
Factions at 3+ scout scored buildings (rooms/area/water), claim as GROUP
territory, occupy: zones, storage, a task loop through vanilla actions
(farm, barricade, haul). Territory is lived-in, not just fenced.

### S5 - The player among them
Sparse interface: Talk / ask-to-join-me / petition-to-join-them /
influence. Joining THEIR faction makes the player a member of their
governance, not an owner.

### S6 - Habits and judgment
Hygiene/substance dimensions where installed-mod surfaces are detectable;
survivors judge by disposition; addiction as a need-shaped pull.

### S7 - Bonds and trauma
Pair bonds; witnessed-death of a bonded partner as a formative event ON
THE LIVING (trait shifts divergent by disposition: nerve collapse or
vengeance).

---

## Society arc close ([A14])

All seven gates BUILT ([A14]-[A14]): S1 claims and the clock (corrected
to claims-first at [A14]), S2 lessons with provenance, S3 trust-sum
leadership with consumers, S4 faction names and scored settlement, S5 the
player among them (three verbs, one web), S6 habits on real surfaces with
gaps recorded, S7 bonds and the trauma fork. ALL LIVE-UNVERIFIED - the
arc was built during one deployed-but-unlaunched window; the first live
session is the arc's first witness. What play exposes reopens gates as
batches, not rewrites.

---

## S-gate reconciliation ([A15])

All seven gates BUILT and since deepened: S1 claims-first (corrected
A14, echoes at the primitive), S2 lessons (death-minted, road-carried,
decision-biting), S3 leadership (consumers incl. flight and move-in;
dead leaders succeeded at the grave), S4 settlement (named factions,
scored bases, group claims; witnessed settlement needs NO extra build -
a new claim enters neighbors' heads through the standard faction
acquisition on their next look), S5+S5b the player among them (three
verbs; talk pays in real knowledge), S6 habits (vanilla surfaces, gaps
recorded), S7 bonds and trauma (severance on betrayal). Epistemics
uniform per DR-007. Everything live-unverified; the deployed 0.4 build
is the arc's first witness whenever the next session begins.

## The census arc (DR-010 + DR-011, opened [A18]) - as built through [A22]

Reconciliation ([A23]): all five census items shipped and grew
consumers. After the recatalog they live in two units: `[A18]` (the
registry census, its distribution, the trade's past, profession-keyed
origins, visible trades) and `[A19]` (the workday taxonomy and its
deferred seams), with hardening in `[A22]` (F-036 and F-039). The
arcs stay OPEN per the never-closed law - the idea entire is the
condition, and live witness remains the standing debt.

The county populated by first principles: who people WERE decides where
they started, what they know, what they do all day, and what their
factions come to believe - under a standing tax that makes doing
nothing never free. Never declared closed; the idea entire is the
condition.

- **Census item 1 - Enumeration.** Bridge verb over `Registries.CHARACTER_PROFESSION`
  (iterable, namespaced keys): every registered profession, vanilla and
  modded, enumerated engine-true at runtime.
- **Census item 2 - The distribution.** `SAO_Census`: circa-1993 Knox-area weights
  over the vanilla 25; classification heuristics fold modded
  registrations into rarity buckets by namespace+path (spec-ops
  ultra-rare, military rare-but-local, trades common...). Occupation
  assigned at genesis and Knox adoption.
- **Census item 3 - The past has a trade.** History claims shaped by occupation
  (the deputy's measure-the-danger tends lived; the nurse's
  people-are-worth-it); origin situations in the active scenario mod's
  vocabulary; placement anchors.
- **Census item 4 - The workday under the tax.** Designation within a company
  (scout, watch, medic, quartermaster, none); job errands executed in
  the world; chosen rest short/positioned/interruptible; hour-filling
  errands stratified by held claims (routine-is-armor holders invent
  tasks; the claimless may legibly freeze); the four answers - need,
  designation, chosen rest, errand - surfaced on every agent.
- **Census item 5 - Doctrine and fallout.** Factions accrete a creed from member
  occupations and lessons; when factions meet, aligned creeds
  cooperate, opposed creeds produce political fallout through standing
  (wariness, objection, grudge - combat only ever through the existing
  hostility rules).

## The Day Zero arc (operator-directed macro arc, 2026-08-26)

"Everything else is built on top of the initial chaos." The county
starts BEFORE the fall: full living census, innocent lives (no
learned fear - the lessons machinery's zero state), normal-life
behavior (driving, noise, open streets), zombies removed or nearly so
by the player's own sandbox; the outbreak then PROPAGATES through the
engine's own infection/turning variables, and the county's collapse
is lived, witnessed, and remembered person by person. Slices:

1. `[A29]` the innocent county - DayZero sandbox mode: innocent
   histories, duty-only arms, era-per-person via lessons. SHIPPED.
   Extended by `[C42]`: an audit found the switch reached only
   those two things and that no decision anywhere asked whether
   the fall had happened, though the county had written three
   stamps for it since `[B1]`. The county can be asked now
   (`fallHasCome`, derived from those stamps and the record's
   calendar, never from the dial), and the night watch, the
   journey for a weapon or ammunition, and scouting somewhere
   defensible all wait for it. Normal-life behaviour on open
   streets is still unbuilt.
   And by `[C43]` the record's timeline moves onto the start date: a
   player picks any date in 1993 and, with the switch on, the record's
   own first day lands there, so its week of ordinary county plays
   out, then the collapse, then the rest in shipped order, with the
   broadcasts and dated papers moving with it. A start later in the
   year moves it backwards onto them. With the switch off, the shipped
   calendar is untouched; a 1994 or later start is refused the move,
   because that save is owed the years between simulated forward
   instead.
2. Outbreak dynamics live-verified: zombie bites/infection/turning on
   shells (BodyDamage + reanimation timers javap-verified; needs live
   confirmation), the first named death teaching the first lessons.
3. Chaos legibility: panic voices for the untrained, the wire
   erupting, the innocent-to-hardened arc visible in Talk.
4. Ventures socialized: the departure argument (who tries to stop
   them, who goes along), party ventures, announced terms ("back by
   dark", "don't expect us back").
5. Vehicles as composition (never dependency): party size meets seats,
   the sedan is low-key, the RV carries five.
6. SHIPPED as `[C38]`: the era remembered - the knowledge surface
   carries "before" (born, the war, where from, home, innocent or
   hardened) and "the day it started" (their own first horror with
   its date and what it taught, the county's own stamps aired as
   news, the record's first day for anyone with a radio) as claims
   with provenance, and the chronicle reads its days as the county's
   own dates through the same calendar; a journal waits on an item
   to write it in.
7. SHIPPED as `[C36]`: the shipped record on the county's calendar (DR-031): the game's
   own broadcast schedule and dated newspapers re-keyed from "days
   since the save began" to the dates the record itself carries
   (July 1 to 16, 1993), driven by the living start's own day - the
   pre-outbreak county first, then the fall in its shipped order.
   The engine's public re-keying surface (ENGINE_CONTRACT Addendum
   E) makes it in-process work; the Speakeasy world document
   knox-event.md keys the record to those dates.

Named by the operator 2026-09-06: Week One (Slayer, on the Bandits
NPC engine) as existing art for the living county before the fall -
civilian animations, vehicle models, sounds, outfits, several
credited authors' work under one mod. Catalogued in Speakeasy's
people-mods.md (part 4) from the pages; nothing of its logic
crosses (its people are programmed zombies on a scripted timeline).
The art was read on disk and selected through Crucible (DR-034):
SHIPPED as `[C35]` - the county's gestures, seats, tunes, dances,
claps and coughs, from Hobbies and Week One, copied and credited.

## People through required mods (DR-032, operator-ruled 2026-09-06)

The county is to have children and elders, and people with the
conditions that shape knowledge and memory - dementia, chronic
illness, disability, age. The engine holds none of it (ENGINE_CONTRACT
Addendum F), so it comes through third-party mods made native
requirements. Order:

1. The catalogue: mods that add child and elder bodies; mods that add
   cognitive, health and age conditions, and the traits-and-occupations
   overhauls - each read from its own Workshop page or repository, with
   Build 42 standing, dependencies and license. Held in the Speakeasy
   catalogue world/people-mods.md beside the scoping index. Part 1
   (bodies and age) found one child-body mod, closed and patching the
   game directory by hand; the engine-native path for a child is a
   scaled adult mesh (ModelInstance.scale). Elders need no model - the
   operator ruled it 2026-09-06: the adult body with hair, condition,
   behavior and age. Part 2 IN PROGRESS.
2. Selection through Crucible, mod by mod: DONE 2026-09-06 (DR-032).
   Age: Getting Old's mechanics ported. Memory and cognition: the
   Build 42 condition mods required (Infirmities, Even More Traits,
   Humans: Are Weak) and the memory conditions ported (Neurodiverse
   Traits, Custom Traits' Dyslexia, Scotty's Mental Health Expansion,
   the ADHD Trait). Substances: the dependency model taken into
   habits. Children: native model scale plus Growing Up's systems.
3. The batches: `[C29]` SHIPPED the body seam - the size woven into
   the animation player, awaiting its live receipt; `[C30]` SHIPPED
   age as a system - the bands from six to ninety, the stages, the
   work, the pace, the drift and death of old age, awaiting its live
   receipts; `[C31]` SHIPPED the child's day - the fear floor with
   the night and the comfort object, literacy, the throttle and the
   birthday floors, the kit from the child's own temperament, the
   child's head - awaiting its live receipts; `[C32]` SHIPPED the
   conditions - drawn at the record's prevalence, bending, fearing,
   keeping, carrying, forgetting and pricing at every seam, the two
   Build 42 condition mods required for the player's side - awaiting
   its live receipts; `[C33]` SHIPPED the habits - the drinker with
   The Alcoholic's phases and the drink taken or found, the users the
   county fell with on N and C's schedule - awaiting its live
   receipts. The people-through-required-mods arc is built through;
   what remains is the operator's: the live receipts of five batches,
   the two required mods subscribed, and the figures still waiting on
   a primary (psychosis, insomnia). As scoped: (a) age as a system - SAO's age
   drives Getting Old's
   life-stage effects, hair greying and death of old age on SAO's
   people; children get the age curves for speed and weight, the fear
   floor, the literacy progression and the experience throttle; the
   bands extend below 19 and above 68 and the census places children
   in households. The child BODY comes FIRST, by the operator's ruling
   on the corrected facts: SAO's Java agent instruments the animation
   player at load so a character's bone transforms carry a per-person
   scale (the renderer scales nobody on its own; ENGINE_CONTRACT
   Addendum F), verified live before the age systems land. (b) the memory conditions
   and per-person decay. (c) habits and dependency. (d) `require` for
   the condition mods, their traits read by the census, CREDITS.md
   entries for every source taken from.

## Speech (direction, not scheduled)

Free-text and dictated conversation with survivors, answered from
what that specific person actually knows rather than from a line
table. Operator direction of 2026-08-26; see [SPEECH.md](SPEECH.md)
for the position, the answers to the questions it raises, and the
reason the current derivation work is its foundation rather than a
detour from it.

The one piece worth building early is the **knowledge query surface**
- what does survivor N know about topic T, at what provenance, how
old - because every renderer needs it, it is testable offline against
the mirrors, and it improves the Ledger and the briefing today with
no dialogue attached.

Refined 2026-09-06 (DR-033): the register follows the strain, orders
follow standing, and the county runs without the engine. Two arcs
scoped from it, unscheduled until their forks pass Crucible:

- **Command through standing.** An order is an utterance the
  understander reads beside questions and requests; who may give it
  and who must weigh it is the Standing pillar's business - leader,
  designation, trust, the giver's shown competence - and real-time
  direction of several people by dictation follows where authority
  holds. First slice: the harness's operator orders re-routed through
  standing for the player, with refusal inside the disposition's
  envelope. SHIPPED as `[C37]`: every ask of a person in the county's
  menus lands through `SAO_Command` - CAO's check on the Standing
  that exists, a proven hand standing as a second, the envelope's own
  reasons - with the debug orders left as the operator's hand.
  SHIPPED as `[C49]`: survivor-to-survivor orders use the same
  check. The keeper rousing the house, a housemate objecting to
  someone leaving, and an owner telling a trespasser to go all go
  through `SAO_Command`, and the hardcoded authority test written in
  SAO_Controller for the objection is deleted. Three existing
  Standing facts carry them - divided houses, designations and
  claims - each worth what a proven hand is worth. Watching another
  survivor act is not an order and is not checked; an invitation is
  not an order and stays with the day zero arc. Directing several
  people at once by dictation, and reading an order as an utterance,
  still wait on the models.
- **The county without the engine.** The record side generated and
  run over simulated days in the bare VM the borders already use -
  people, pasts, relations, houses, conditions, habits, knowledge and
  its decay - as a test surface for the world as a world. First
  slice: a day-loop runner over the shared modules with a stub
  county, reporting who died, who quit what, what was forgotten.

And the register itself: the knowledge surface's conditioning gains
the situation and the speaker's energy - SHIPPED as `[C34]`. The
three forks returned through Crucible the same day (DR-033, ruled):
no authority table, command as CAO's Authority pillar does it on the
Standing that exists; refusal contextual; the engineless county not
scoped, the game being loaded anyway.

