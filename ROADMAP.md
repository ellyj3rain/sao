| Document | Survivor Awareness Overhaul Roadmap |
|---|---|
| Version | `0.6.0.0-pre-alpha` |
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
6. The era remembered: journals, chronicle, and Talk carrying "before"
   and "the day it started" as lived claims.

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

