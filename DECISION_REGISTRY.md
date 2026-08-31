| Document | Survivor Awareness Overhaul Decision Registry |
|---|---|
| Version | `0.6.0.0-pre-alpha` |
| Author | ellyj3rain |
| Repository | `DECISION_REGISTRY.md` |
| Status | CANONICAL, APPEND-ONLY - ratified decisions. |

# Decision registry

Append-only. A superseding decision references what it supersedes; prior entries
are never rewritten.

---

## DR-001 — Four-pillar composition as the framework shape

**Date** 2026-08-26 02:05 UTC / 2026-08-25 19:05 PDT
**Status** RATIFIED

**Decision.** Survivor behavior is composed as
`Perception admits → Disposition decides → Standing channels → Execution acts`,
with each pillar carrying an explicit *does not own* boundary.

**Rationale.** A single decision function that reads world state directly is
simultaneously omniscient about geometry and oblivious about people, and produces
outputs that are individually patchable but never correct as a class. Separating
what is known from what is wanted, what is permitted, and what is done makes each
failure attributable to one substrate.

**Consequences.** Perception must exist before any decision consumes world state.
Execution may not query global truth. Fixes that widen perception to improve a
decision are treated as defects in the decision model.

---

## DR-002 — Identity is a record; the engine object is a temporary body

**Date** 2026-08-26 02:05 UTC / 2026-08-25 19:05 PDT
**Status** RATIFIED

**Decision.** The authoritative survivor is a persistent record keyed by stable
ID. The engine character exists only while its cell is loaded, is reconstructed
from the record, and is never the save entity.

**Rationale.** Tying identity to a world object makes persistence hostage to
engine lifecycle, and makes every unload a potential loss of person.

**Consequences.** All owned state serializes from the record. Body reconstruction
is a lifecycle detail, not a respawn.

---

## DR-003 — Build the framework on engine NPC support, not on repurposed actors

**Date** 2026-08-26 02:05 UTC / 2026-08-25 19:05 PDT
**Status** RATIFIED

**Decision.** Survivors are driven through Build 42's own NPC surface —
`IsoPlayer.setNpc(boolean)` and `AIComponent.getHumanControlVars()` — rather than
by repurposing another actor type and suppressing its native behavior.

**Rationale.** Repurposing an actor inherits that actor's state machine, so the
default failure mode is reversion to its native idle behavior; it also exposes
survivors to every consumer of that actor type's update event.

**Consequences.** The framework cooperates with the engine's control path instead
of continuously correcting it.

---

## DR-004 — The framework carries a Java agent component

**Date** 2026-08-26 03:40 UTC / 2026-08-25 20:40 PDT
**Status** RATIFIED (operator-directed; the rebuild's architecture was the
declared model per DR-003's rationale)

**Decision.** Survivor Awareness Overhaul ships a Java agent
(`java/dist/SAOAgent.jar`, attached via `JAVA_TOOL_OPTIONS=-javaagent:...`)
alongside the Lua mod. The agent owns exactly what Kahlua cannot do: defining
the renderable `IsoPlayer` subclass (`SAOIsoPlayerShell`, F-009) and exposing a
bridge object (`SAOJavaBridge`) into the Lua environment via
`LuaManager.exposer`. All framework intelligence remains in Lua; each addition
to the Java surface must name the thing Lua cannot do.

**Consequences.** The dev launch path sets `JAVA_TOOL_OPTIONS` and starts
`ProjectZomboid64.bat`; the game process is jre64 `java.exe`, not the exe. Lua
construction remains as a named fallback (`lua-bare`) so the mod degrades to
functional-but-invisible without the agent rather than failing.

## DR-005 - Canonical person keys in Standing

**Decision.** Standing stores every person under one canonical key: a
survivor's RECORD ID; the real player as `player:<username>`. Perception
continues to speak usernames (it records appearances); conversion happens
once, at the controller boundary, via `Standing.keyForObserved` /
`keyForAttackerTag`, with `usernameForKey` for the reverse direction.

**Why.** [A9] audit found encounter trust writing relations under belief
usernames while company formation read record ids - two ledgers about the
same person that could never meet. One canonical key makes every standing
consequence (trust, hostility, groups, testimony) compose.

**Origin.** `[A9]`, defect found wiring witnessed violence.

## DR-006 - The society arc (operator-ratified expansion)

**Decision.** The framework expands from individual survivors to a
SOCIETY: survivors organize independent of the player (groups -> named
factions -> internal governance -> occupied territory with real work);
what a survivor KNOWS scales with the apocalypse clock (sandbox start time
+ engine hours-survived) and with LESSONS transmitted from other
survivors' recorded deaths; each identity carries a trait-coherent
BACKSTORY with formative events; the player can join their structures,
recruit from them, and influence their politics through a deliberately
SPARSE interface (stock menus judged cluttered); habit/judgment realism
(hygiene, substances) lands where the installed mod population exposes
surfaces; pair bonds deepen and witnessed-death trauma shapes traits.
Open-ended zombie-narrative shape, CAO methodology throughout.

**Why.** Operator direction at [A14]: survivors must read as "true
agentic individuated actors" whose understanding follows from their
context and history, not from scripts. The KnoxSurvivors reference
(audited: `KNOX_SOCIAL_AUDIT.md`) proves the organizational pipeline is
buildable; our pillars make it honest.

**Origin.** `[A14]`, operator ratification in session.

## DR-007 - The epistemic entry gate

**Decision.** Travelers respect claims they BELIEVE in, not claims that
merely exist. Place-beliefs form by seeing an owner at home, by being
told, or by being told OFF (the objection teaches, firsthand). A place
never learned is entered innocently; the first offense costs nothing and
converts ignorance to knowledge; the offense is returning against a held
belief. Owner-side knowledge remains Standing truth - you know your own
house, and group members know their base. The moral primitive
(mayEnter/claimedByOther) survives for owner-side consumers only.

**Why.** [A9] accepted one-directional social knowledge to ship
territory; [A15] built the belief machinery that makes the honest version
affordable. A survivor who avoids a claim they could not know about is
the same omniscience CORE.md's founding example rejects.

**Origin.** `[A15]`, closing the acceptance recorded at [A9]/[A15].

## DR-008 - County scale

**Decision.** The society is a county, not a hamlet: population default
60, ceiling 500 (was 8/64). Genesis is paced (six identities per
population pass) and the dormant-encounter sweep is budgeted (rotating
12-record cursor per pass) so scale costs constant per-tick work; only
banded survivors carry bodies, as ever.

**Why.** Operator review at [A16] live: "six living, target 8 - not
nearly enough people to start any measure of society... we're aiming for
something far more significant."

**Origin.** `[A16]`, operator direction in session.

## DR-009 - Legacy coexistence, SAO precedence

**Decision.** The legacy KnoxSurvivors workshop mod continues alongside;
compatibility over removal, and where the two systems collide SAO's
reading overrides on SAO's side. Concretely: legacy NPCs are
IsoZombie-backed human shells (their own predicate: variable
"KnoxSurvivor"/"KnoxSurvivorShell", modData KnoxSurvivorId/ProfileId/...)
- every SAO zombie-consuming edge must EXCLUDE them as threats and
ADMIT them as PEOPLE, so the trust web opens cross-mod. Their systems
are never driven by ours (no double-processing); their targeting reads
the slot array and cannot see our shells - benign by construction.

**Why.** Operator at [A16]: "either we remove the old one or ensure
compatibility... I think that is the better option. And obviously we
would override that."

**Origin.** `[A16]`/`[A16]`, operator direction in session.

## DR-010 - The census: occupations by first principles

**Decision.** Every survivor record carries an occupation drawn from a
realistic circa-1993 Knox-area labor distribution, and the occupation
catalog is built by FIRST PRINCIPLES from the engine's own registry -
`Registries.CHARACTER_PROFESSION` (`Registry<T> implements Iterable`,
`.keys()` -> namespaced ResourceLocations) - so every profession any
installed mod registers through `CharacterProfession.register` enters
the population automatically, weighted by classification (namespace +
path keywords -> rarity bucket), never by per-mod patches. Verified
present and active: SoldierOccupation (deltaforce, navyseal,
armyranger). Rarity is honest: a county has plumbers by the hundred and
a Navy SEAL almost never - but Fort Knox sits on this map, so military
weight is locally real. Occupation shapes History's claims, genesis
placement (where you were when it started - origins in the vocabulary
of the active "Where I Was When It Happened" scenario mod's
situations), gear, and doctrine leanings. Distribution figures are
defensible approximations of 1990s Kentucky labor statistics,
documented where encoded; the operator ratified approximation -
precision beyond 1993 does not matter.

**Why.** Operator direction in session: "I have a massive modlist...
by first principles, attempt to make most of what exists there
inherently compatible... look at distributions within the population...
real distributions of labor statistics from Kentucky... populate them
realistically... Each of these has a realistic start, and grouping,
solo starts... naturally generating and forming factions that disagree
and if they meet each other, there's political fallout... Take this
direction and make it grand."

**Origin.** `[A18]`, operator direction in session.

## DR-011 - The tax: no goalless tick, the environment is the drill sergeant

**Decision.** No survivor ever does nothing, and none does something
without a goal - not as a coded work ethic but because the environment
punishes slack and the simulation must keep that tax in force. At any
moment every body must answer "what is the pressure doing to me right
now" with one of four legible answers: **need** (the ladder's upper
rungs), **designation** (their job, worked in the world), **chosen
rest** (deliberate, short, pointed, interruptible, watch-paired - you
smoke facing the road, you pick the banjo on the porch with a bat in
reach, you do not take an afternoon), or **errand** (self-assigned
hour-filling). If the answer is nothing, the environment has stopped
existing for that actor and they are a mannequin again - a defect.

Stratification is CLAIMS-DRIVEN, not coded courtesy: holders of
routine-is-armor / measure-the-danger fill every hour because they have
watched slack get someone killed (lived claims, not flavor);
early-grade minds without them may genuinely freeze or wait for
extraction - and that waiting is itself a legible state with a why. The
undesignated smoke is not sloth: it is a person with no designation
keeping their hands busy while the real background job - stay alive
until a better job appears - runs. Encounters between strangers resolve
by the standing rules, never scripted: the simulation is uncontrolled
BY DESIGN; the obligation is legibility.

**Why.** Operator, verbatim anchors: "you don't want them ever doing
nothing or doing something without a goal. Cause even a goal is
leisure"; "The environment is the drill sergeant"; "People invent tasks
because standing still has a cost that the institution will collect";
"That is measure-the-danger and routine-is-armor as lived claims, not
as flavor"; "You do not have to simulate OSUT. You have to keep the tax
in force so that doing nothing is never free"; "You can't control the
simulation. But you can ensure it's legible."

**Origin.** `[A18]`, operator direction in session.

## DR-012 - Who somebody was is this county's judgement (the former `[A115]`, now absorbed into `[A20]`, reversed)

**Decision.** The former `[A115]` - the archetype import now absorbed into `[A20]` and carried there with this reversal on the record - is reversed. A foreign store may inform this
county and may never decide for it: `rec.occupation` and
`rec.occupationPresumed` are written by the census and by nothing else,
and nothing anywhere clears the presumption flag. Their profile is
still read for what is genuinely theirs to state - the relationship
rows at half-strength ([A21]/[A22]) and their own camp ([A19]) - and
is no longer read for who a person was.

**Why.** DR-009 already ratified the precedence: where the two
systems collide, SAO's reading overrides on SAO's side. `[A20]` let a
foreign archetype overwrite the census draw through a thirteen-entry
table written by hand - its own comment said "mapped by closest
life-shape" - so it contradicted a standing decision for thirty-odd
batches. The contradiction survived because the decision lived in this
ledger and the code lived in a file, and nothing compared them.

The overwrite was the visible half. `[A20]` also cleared
`rec.occupationPresumed`, which is this project's honesty about its own
guessing: `Census.describe` says *"carries themselves like a nurse"*
while it is set and *"was a nurse in Riverside when it started"* once
it is not, and `Census.originNote` refuses to invent a beginning for a
presumed trade at all ([A22]). Clearing it did not import a fact. It
laundered our own guess into one.

The operator directed the reversal: the census does not yield to the
neighbour's profile.

**Origin.** `[B42]`, operator direction in session. Border 41 holds
it: the census owns both fields, and the warning label is never
removed. Controlled against `[A20]` restored verbatim, and against
each of its two halves alone - because a border watching only the
occupation field would have waved the laundering through.
