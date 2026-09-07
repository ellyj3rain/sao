| Document | Survivor Awareness Overhaul Decision Registry |
|---|---|
| Version | `2.3.0.0-pre-alpha` |
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

**Why.** Operator direction at [A14]: survivors must read as true
agentic individuated actors whose understanding follows from their
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

**Why.** Operator review at [A16] live: six living against a target
of eight is not nearly enough people to start any measure of society;
the aim is far more significant.

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

**Why.** Operator at [A16]: either remove the old one or ensure
compatibility - compatibility being the better option, with this
mod overriding where they meet.

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

**Why.** Operator direction in session: they run a massive modlist,
and by first principles most of what exists there should be
inherently compatible; population distributions should follow real
Kentucky labor statistics, populating them
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

**Why.** The operator's anchors, paraphrased: nobody is ever doing
nothing or acting without a goal - even a goal is leisure; the
environment is the drill sergeant; people invent tasks because
standing still has a cost the institution collects; danger is
measured and routine is armor as lived claims, not flavor; the
training pipeline need not be simulated, only the tax kept in force
so that doing nothing is never free; the simulation cannot be
controlled, but it can be kept legible.

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

## DR-013 - The version is a machine

**Decision.** The version coordinate is computed, never picked. CAO's
version model is adopted whole - `major.minor.kohai.patch-maturity`,
hard caps minor 12 / kohai 16 / patch 24, cap movements rolling the
tier above, maturity moving on evidence only - and every closed batch
is classified one unit per batch by what the work is: minor for a new
player-visible capability or contract, kohai for a coherent extension
or maturation, patch for in-place correction or verification closure.
The tier table lives in `tools/version_replay.py`; the replay's output
is the version; `--write` stamps `VERSION` and renders
`VERSION_MAP.md`; Border 80 refuses a tree whose stated versions
disagree with the machine. To disagree with the coordinate, disagree
with a tier, in the table, with the argument written down.

**Why.** The operator's ruling, paraphrased: the version is a
machine and the number is not picked. The old 0.6 was in the tree
only because hundreds of diary batches had bumped it, and no map
may walk to it so it looks earned. Run the replay; the coordinate
is the output; show classifications and arithmetic; if the number
barely moves, that is the answer. The replay's answer is that
the old number undersold the catalog: under the caps the odometer
crossed `1.0.0.0` at `A26` by arithmetic, and the closed chronology
derives `1.10.6.0-pre-alpha`. Neither number is a release claim;
maturity stays `pre-alpha` until play receipts exist.

**Origin.** `[C2]`, operator work order, 2026-08-28. Controlled by
Border 80's own flip: a hand-edited `VERSION` (the exact former state,
a declared number the replay does not derive) goes red for the stated
reason.

## DR-014 - One person, one name

**Decision.** A person in this county has exactly one name, and every
surface renders it: the menu, the speech, the journal, and the ID card
the corpse yields. Death uses the living name. Concretely: Identity's
"Unnamed"/"Survivor" placeholders never overwrite the engine's
generated name at spawn; the papers a body carries are refreshed at
every materialization from `Identity.knownName` - the same renderer
the menu reads; and for the neighbour framework's people the
neighbour's own `profile.name` IS the name - the record takes it and
the engine descriptor is aligned to it, because his menu, his overhead
tag, and his ID card all render the profile and never the descriptor.
One menu carries one person: the county's person submenu is the single
interface, driving the neighbour's working verbs through his own
public functions on his own bodies (DR-009 stands - his bodies are
never driven by ours), and his duplicate per-survivor context root is
stripped. His generic root and his settings stay his.

**Why.** Operator work order, 2026-08-28: one person, one name -
menu name, speech name, and ID card are the same string. The
witnessed defect: a follower with one name on the menu dropped an ID
card carrying another when he died; death uses the living name. The
walk found three leaks under that one
symptom: the placeholder stamp destroying the engine's names, adoption
reading a descriptor the neighbour never shows, and the [B45] hold
testing global `KS` while the neighbour's global is `KnoxSurvivors`.

**Origin.** `[C3]`. Border 81 holds all of it; its control is the
pre-fix tree, which fails nine ways for the stated reasons.

## DR-015 - Superimposed, not beside (the neighbour's menus)

**Decision.** On a body the neighbour framework's menu attaches to,
the neighbour's own per-survivor root IS the person's one menu. This
county keeps it, retitles it to the person (DR-014's one name reaches
the label), clears what is inside, and rebuilds it: the county's talk
and tell surfaces first, then the neighbour's working verbs through
his own public functions, ownership-aware. The county adds no second
person menu for his people; his generic "Knox Survivors" root
(notebook, base setup, field guide) and unadopted people stay
untouched. The prediction of where his root attaches is one function
(`willSuperimpose`, mirroring his own nearest-actor radius), consulted
by both the county's menu builder and the superimposer, so the two
cannot disagree about who owns a click.

**Why.** The operator corrected [C3]'s reading: the task was
superimposing this mod onto the neighbour's menus, still lacking and
not what had been built. [C3] had stripped his root and grown a
second person menu beside where his used to be - removal where the
work order said to use what the neighbour already puts in the game
for UI and hooks. The surface the player of both mods already knows
is his; what it presents is ours.

**Origin.** `[C7]`, operator correction, 2026-08-29. Border 86 holds
it; its control is the [C3]-era strip, which fails eight ways for the
stated reasons.

## DR-016 - SAO owns death of the person completely; one brain per body

**Decision.** SAO owns the death of its people whole: the record, the
corpse's identity, and ensuring the turn actually fires under the
game's own rules - the sandbox's Transmission, the body's real
infection state, and the ZombieLore Reanimate timer, through the
engine's own death path (`die()` -> corpse -> died-listeners ->
`reanimateLater()`), never through timer arithmetic of SAO's own.
What SAO does not do is drive the risen body: that brain is
vanilla's, or the zombie-side sibling's when it is installed and on.
One brain per body.

**Why.** The operator's ruling, 2026-08-29, superseding the code's
inherited hands-off posture: the corpse-side hands-off posture in
the code comments is specifically ruled a GAP, not a principle. The
standing division: SAO owns death of the person completely - the
record, the corpse's identity, and ensuring the turn actually fires
under the game's own rules. What SAO does not do is drive the risen
body: that brain is vanilla's, or ZAO's when installed and on. One
brain per body.

**Origin.** Operator work order, 2026-08-29; landed at `[C8]`.
Border 87 holds the chain. The identity key on the body's modData
(`SAOPersonId`) is PROPOSED in the [C8] batch record and awaits the
operator's approval - the sibling project will read the same key
verbatim, so the name is the operator's to fix.

## DR-017 - The front end speaks player; representation is not implementation

**Decision.** No player-facing surface may require engine language to
read: no mode-sentinels ("0 = size it from the map"), no coded scales
("0 = none, 5 = an exodus"), no decode tables in labels or
descriptions ("5 = 48-72 hours"), and no tooltips apologizing for the
encoding ("Zero does NOT mean..."). A mode gets a worded switch; a
coded scale gets worded values; a genuine quantity keeps its number,
stated in plain units. The internal representation - sentinels,
enums, multipliers - may stay exactly what the backend wants, and the
translation between the two happens in one declared place.

**Why.** The operator, 2026-08-29, on the sandbox surface: the back
end may look like whatever it needs to - the failure is when that
collapses into making the internal representation the configurable
on the settings screen. Why should a user have to
know that five equals forty-eight and seventy-two... 'oh, zero means
default' - that's engine language. That's not front end language...
They don't need to be the same thing. It's just called
representationality."

**Origin.** Operator correction, 2026-08-29; landed at `[C12]`.
Border 91 holds the class over the sandbox surface.

## DR-018 - No Claude-isms in front-end copy

**Decision.** Player-facing copy - option labels, option values,
tooltips, panel and Ledger lines, any UI string - must not carry the
assistant's house register: present-tense narration of what a
setting "does" as if it were a scene, evocative-verb miniatures,
portentous fragments, metaphor standing in for information ("The
road never quickens", "N between death and the ground" - both
shipped, both struck). This is NOT a rule that copy must be boring -
the operator's own refinement: it does not have to be boring - the
assistant is simply bad at making things interesting. The bar: copy serves the
reader first, in ordinary words; the assistant does not attempt
color on its own judgment, and copy with personality is written or
ratified by the operator. Until then, plain is the shipped baseline
- better dull than bad. Survivor SPEECH is exempt: a person talking
is diegetic voice, not UI copy ([C5] stands). The repository's
internal documents keep their own register; the screen does not
inherit it.

**Why.** The operator, 2026-08-29, on the [C12] copy: present-tense
narration of settings - "The road never quickens" being the shipped
example - ruled the worst kind of writing, a Claude-ism produced
nearly every time the assistant writes copy; refined in the same
conversation: "I don't wanna say it has to be boring. No. You're
just bad at making things interesting."

**Origin.** Operator correction, 2026-08-29; landed at `[C13]`.
Border 92 freezes the ratified copy so the register cannot drift
back silently - changing player-facing copy means re-ratifying it
there, with the operator's eyes.

## DR-019 - The identity key is SAOPersonId, ratified

**Decision.** The person-identity key on every body's modData is
`SAOPersonId`, exactly as [C8] proposed. The sibling project reads
the same string verbatim.

**Why.** Operator ratification through Crucible, 2026-08-29. Matches
the KnoxSurvivorId convention on the same table; renaming after the
sibling's first reader ships would be a two-repository migration.

**Origin.** Crucible session, 2026-08-29; DR-016's PROPOSED marker is
discharged.

## DR-020 - Whole minds survive a reload

**Decision.** The perception store persists entire: everything a
survivor believes - zombies, people, factions, places - survives
save/reload, not a graded subset. Belief timestamps carry a
world-hours stamp for persistence; session-tick fields rebase on
load. Death pruning (the existing forget funnel) bounds the growth.

**Why.** Operator's pick through Crucible, 2026-08-29, choosing the
full option over the recommended gravest-only subset: how much of a
person's mind survives a reload was the operator's call, and the
answer is all of it.

**Origin.** Crucible session, 2026-08-29; lands at `[C15]`.

## DR-021 - The grounded dead: measure, then guide; presence is shaped, optional, and reconciled

**Decision.** GROUNDED_DEAD_PROPOSAL.md is ratified as mechanism B
(measure, then guide) with the operator's amendments:

1. A dead-census instrument measures the install's actual crowd
   before any number is recommended; the derived total becomes a
   multiplier recommendation only after measurement.
2. A PRESENCE LAYER - sandbox-optional, off by default until the
   measurement argues otherwise - thickens the dead where the
   demography says people crowded (town cores, commercial ground)
   and treats highways as corridors: the county is a continuous body
   in a larger country and state, and the map edge is not the
   world's edge.
3. STATE AGREEMENT is required: the county already pays for its
   living by taking from the vanilla bulk ([B21]'s pool), so the
   presence layer and the pool-taking reconcile against one shared
   crowd ledger - both dials stay independently configurable, but
   they read and write the same accounting, and neither blindly
   undoes the other.

**Why.** The operator through Crucible, 2026-08-29: "#1 but we
should also perhaps make this optional too and likely ensure that we
then add some to increase risk, presence and bulk of typically
crowded areas and keep in mind the highways and existence as a
continuous body in a larger country and state", and on the layer's
relationship to spawning: "we are also supposed to take survivors
from the vanilla bulk by design too so we need to ensure state
agreement here even if both are controllable and configurable."

**Origin.** Crucible session, 2026-08-29. The census instrument
lands at `[C16]`; the presence layer and its ledger follow. The
final population numbers remain the operator's, ratified against the
measurement.

## DR-022 - SAO absorbs the neighbour's people (SUPERSEDES DR-009's never-driven clause)

**Decision.** SAO takes over the neighbour framework's survivors
completely. On world start every one of his people is absorbed: SAO
removes his zombie-backed body and materializes its own shell for
that person, carrying the name, profile and inventory across. From
that moment they are ours entirely - our perception, disposition,
standing, locomotion, combat, needs, death and turn. His people
created later by his own encounter machinery are absorbed the same
way as they appear.

**What this supersedes.** DR-009 ratified coexistence in which "legacy
NPCs are IsoZombie-backed human shells... never driven" and SAO only
perceived them. That clause is overturned. What survives from DR-009
is its collision rule - every SAO zombie-consuming edge must exclude
his bodies as threats - which matters more now, not less, because a
body mid-absorption must never be read as one of the dead.

**Why.** The operator, through Crucible, 2026-08-29, after reading his
whole sandbox surface: he is "too deep to not take advantage of",
but the parallel-person problem is not solvable by holding prompts
and rebuilding menus - that was accretion, not design ("something
that just accreted in at the beginning when Claude was not
listening"). One person cannot be half his and half ours. Replacing
the body was chosen over driving his IsoZombie directly because
SAO's entire stack drives an IsoPlayer subclass and IsoZombie is
final with its own state machine; and over commanding through his
public API because that makes his executor a dependency that can
change underneath us.

**Cost, stated.** His per-actor systems - his combat, his squad
behaviour - stop applying to an absorbed person, because that person
is no longer one of his actors. The handoff must be seamless or
people visibly pop. Neither is a reason to reopen the decision; both
are work.

**Origin.** Crucible session, 2026-08-29. Nothing is built yet: the
absorption seam needs its own verification pass first (how his
runtime releases an actor without tripping his own deletion
heuristics, and what his profile actually carries).

## DR-023 - His options stay where they do not collide; the rest are blocked, not just documented

**Decision.** Of the neighbour framework's 27 sandbox options:

- **SAO sizes the county.** His persistent population controls
  (`MaxPersistentSurvivors`, `MaxNearbySurvivors`) are neutralized,
  because SAO's genesis and presence band own that axis.
- **His encounters stay live as events.** `EnableEncounters`,
  `EncounterChance`, `EncounterCooldownHours`, `GroupEncounterChance`,
  `MaxEncounterGroupSize` keep working; what they produce is absorbed
  under DR-022 rather than suppressed.
- **His own domains are left alone**: squads (`MaxSquadSize` - SAO has
  no squad structure at all), `SpawnWithWife`,
  `ProtectHomeBaseWindows`, and his combat tuning.
- **One name, aligned rather than hidden.** His overhead names keep
  rendering; SAO writes its name into the profile his display reads,
  so both surfaces say one string (DR-014 held by agreement, not by
  suppression).
- **An option SAO overrides is BLOCKED, not merely disclosed.** A dial
  the player can still set and that will not apply is a lie on the
  screen. Where SAO overrides a setting it removes or disables that
  control in game, and notifies as well.

**Why.** The operator, through Crucible, 2026-08-29: overridden
dials are literally blocked or removed in game, with notification as
well - and on the split, that aspects of his features do not all
contradict ours - the reconciliation has to be per option, not per
mod.

**Origin.** Crucible session, 2026-08-29. Blocking another mod's
sandbox control is UNVERIFIED as a capability and is the first thing
to establish before this is built.

## DR-024 - The menu is not the behavior (amends DR-022)

**Decision.** Absorbing a person (DR-022) takes the BEHAVIOR and
nothing else. The interaction surface the player already knows - the
neighbour framework's per-person menu, its shape, its affordances,
its verb set, its survivor card - is preserved for absorbed people.
SAO carries that surface forward itself and implements the verbs
natively. Nothing in DR-022 licenses removing a menu option because
the mod that authored it no longer owns the person.

**Why.** The operator, 2026-08-29, on the absorption ruling: taking
his people must not mean stripping the behavior from his menus - the
menus are related to the behavior, but they are not the behavior.
This is the same principle as DR-015, applied one
layer deeper: the surface the player of both mods already knows is
his; what it does is ours.

**The consequence that makes this work, not just intent.** Absorption
removes his actor, so this is NOT a matter of leaving his menu alone -
his menu stops attaching by itself (it binds to the nearest of HIS
actors), and his verbs stop functioning underneath it, because
`DispatchSurvivorCommand` resolves against an actor that no longer
exists. So SAO must:

1. present the same per-person surface for an absorbed person that
   his framework presented, rather than falling back to its own
   narrower menu; and
2. implement every verb that surface offers - his follow, hold,
   return, regroup, unstick, inventory, greet, recruit, offer, and
   the survivor card - as SAO behavior, because dispatching them to
   him will fail.

[C7]'s superimposition inverts here: there is no root of his left to
rebuild, so what was the fallback becomes the primary, and it has to
be at least as complete as what it replaces. An absorbed person
offering fewer verbs than an unabsorbed one is the defect this
decision exists to prevent, and is the shape the border for this
batch must catch.

**Origin.** Operator clarification, 2026-08-29, amending DR-022 before
any of it was built.

## DR-025 - Partial receipts are receipts; the perpetual-untested claim is dead

**Decision.** Play evidence is recorded incrementally in RECEIPTS.md
(CANONICAL, APPEND-ONLY) as it lands: surfaces witnessed working,
defects exposed in play (which are receipts for everything exercised
on the way to them), and open observations. A batch stays open until
receipts touch its surfaces, and a fix stays pending until
re-witnessed - but the doc-pack may never again make the blanket
claim that nothing has a play receipt. Border 97 holds both halves:
the ledger's integrity, and the ban on the blanket claim anywhere in
the canonical documents.

**Why.** The operator, 2026-08-29, paraphrased: the entire repo was
being classified as untested at runtime even when they had tested,
because no reporting mechanism existed; no single session will ever
uncover every bug, and live findings fixed on report were never
recorded, so everything stayed classified untested perpetually -
leaving something unmarked is one thing, claiming nothing has ever
been tested is tautological. The operator also named this systemic across their
repositories; the pattern is portable.

**Origin.** Operator correction, 2026-08-29; landed at `[C19]` with
the first two receipts seeded from that day's own sessions.

## DR-026 - Fail completely, never his way (amends DR-022's handoff)

**Decision.** When absorption fails for a person, NOBODY spawns. The
wrapped spawn seam never falls through to the neighbour framework's
own spawn; the failure is loud - the console names the person and the
Ledger's not-everything-is-running header carries the seam - and the
next restore pulse retries. His original spawn function is captured
and never called.

**Why.** The operator, 2026-08-29, overruling the first draft's
fallback (which reasoned that a person existing his way beats a
person existing no way - a preference the operator never stated):
they would prefer a complete, clearly visible failure over spawning
one of the neighbour's people, because his people are not
representative of this mod - either it fails plainly, or the mod
works.

**Origin.** Operator correction, 2026-08-29, minutes after [C20]
closed; landed as [C21]. Border 98 now holds the inverse of what it
first held: the wrap must NOT call his spawn, and the failure must be
loud.

## DR-027 - No leash constants: range comes from knowledge and desire

**Decision.** A survivor's reach is never a dial. Acquisition and
errands are knowledge-first: a person goes where they KNOW the thing
is - the map-derived places, their own beliefs, what desperation and
desire make worth the walk - and a radius may exist only as honest
PERCEPTION (how far you can see or probe from where you stand), never
as policy on how far a person may go. The 12-tile errand probe and
the 24-tile dormant day-walk cap are ruled leashes; the county
already owns the machinery ([B38]'s places and offers, [B39]'s
days-go-to-places, the belief layer) and must run acquisition on it.

**Why.** The operator, 2026-08-29, on seeing the errand radius
dial: twelve tiles is nothing, and encoding the limit of these
things is wrong. They are supposed to be more intelligent than
that - operating off social structures and social incentives and
personal desires and understanding and awareness, not a permitted
radius. The same objection stands against the neighbour framework.
Verified before recording: the live need path is a pure 12-tile
container probe with no knowledge fallback, and even the dormant
day-walk - the knowledge path - is capped at twice the same dial.

**Origin.** Operator ruling, 2026-08-29. Implementation is its own
batch (knowledge-first acquisition; the ErrandRadius dial's fate -
demotion to a perception constant or removal - is decided there,
because deleting the dial before fixing the behavior would hide the
leash rather than remove it).

## DR-028 - Property lines delineate, at all times - and never exclude life

**Decision.** Property lines exist at all times and bound where
people ARRIVE and settle - never where life may happen. Two halves,
both the operator's words on 2026-08-29:

1. **Nobody wakes uninvited on somebody else's held ground.** A
   materializing body whose square lies inside a FOREIGN claim (the
   player's included) wakes just past its nearest wall instead, and
   a home that predated the claim moves with them. Witnessed defect:
   two strangers stood up naked in the operator's own kitchen, three
   bodies on one square (R-006).
2. **Within and between, fair game.** A group POPULATES its own
   claim - the garages and houses of each property peopled, many
   serving different purposes - and the space between claims
   belongs to everyone:
   routes people walk, buildings people raise for security. The line
   is a border for settlement structure, not a spawn-free zone.

**Why.** The operator found no adequate logic bounding spawns to
actual property or holding property lines in existence at all
times - then clarified: lines exist so people can delineate
effective borders for their settlements, while everything within
and between stays fair game.

**Recorded alongside (direction, not yet built):** settlement
creation should learn from REAL bases - the operator's CAO
precedent: harvest actual player save data (and multiplayer server
raws, which show desperate and factional building) and feed it into
the spatial/behavioral logic that shapes NPC settlements, so what
they build is, simply put, nice and effective. Rich
NPC-NPC/NPC-player interaction breadth (build, work, love, wage war,
inner political strife) is the stated horizon; by the operator's
own measure the county is nowhere close to adequately modeled
there.

**Origin.** Operator rulings, 2026-08-29, mid-play on `1.12.0.4`.
Wake-law implementation is [C26]; the settlement corpus and
interaction breadth are recorded direction.

## DR-029 - Talking is a learned system, designed before it is built

**Decision.** The speech system's mechanism of record is deep
machine learning - the operator's ruling, 2026-08-29 -
and its build order is DESIGN FIRST: no dialogue code, no interim
speaking surface, no substrate until the ML system design (what it
learns, what data teaches it, where it runs, how it is kept unable
to invent) is ratified through Crucible. The substrate is then
built to fit the ratified design exactly.

Bounds set the same day, in order: a live language-model service
writing NPC replies is REFUSED outright - the mod ships
self-contained; learning is the mechanism, and where it sits
(build-time pipeline, in-process inference, both) is a design
question, not presumed; and design-first is the ratified ordering,
chosen over stand-in interim speech and over substrate-first.

**Why.** The operator, on the [C26] talk surface: not what the
system is supposed to be, not even close - conceptually diminutive
against what was described. And on process, after a unilateral
architecture reading: nothing was resolved, and nothing moves on
until it is. SPEECH.md was always the documented direction - it has
its own file, so there was no excuse - and its renderer fork was
never the assistant's to resolve alone.

**Supersedes in part.** SPEECH.md's clause "rung 1 with a template
grammar is the honest product" no longer names the destination -
the destination is the learned system. The RISK the clause guarded
(a renderer must be structurally unable to assert what the person
does not know) is untouched and binds the ML design.

**Standing condemnation.** The shipped talk surface (line tables,
[C26]'s opened rotation) is ruled not-the-system and its sentences
ruled bad writing (DR-018's register verdict, reapplied). It ships
only because nothing replaces it yet; it earns no further work.

**Origin.** Operator rulings via Crucible, 2026-08-29. The design
map lives in SPEECH_ML_DESIGN.md; each decision in it returns
through Crucible for ratification.

## DR-030 - Speech is corrected in scope: the system models a person

**Decision.** The talking system models a person speaking, never a
request-response pipe. Survivors carry a WORLD MODEL - the 90s,
scoped by who each one was and researched as declared ground; the
game world itself including mod assets, which shape knowledge,
culture, and mood; the politics, struggle, and growth of the
apocalypse - and speech expresses will, choice, and mood from that
inner state. SPEECH_ML_DESIGN.md's Decision 2 is OVERTURNED and
re-decided: no player-speech harvesting anywhere (the sources do
not exist and the scope was never the mod's); the data is the
period world model, the game derived live, and authored voice
material expanded at build time.

**Why.** The operator, 2026-08-30, rejected the harvest framing
whole: the scoping was wrong - the assumed sources do not exist,
and it does not fit the scope of what the mod is supposed to be.
This is not a productized survivor-chat feature. A survivor is just
how a person is: speech is not press-this-get-that, it is will and
choice and mood. Grandiose, by their own admission, without needing
to be earth-shattering in size - and still large.

**Origin.** Operator correction via Crucible, 2026-08-30. The
mechanical two-piece shape (DR-029/Decision 1) stands; every
description reduced to intent-lookup is corrected by this ruling.

## DR-031 - The shipped record of the fall is the living start's to schedule

**Decision.** The game's own record of the Knox Event - the
broadcast schedule and the dated newspapers - is a controllable
asset of the Day Zero arc, not a fixed backdrop. A living start
drives when each part of that record reaches the county, keyed to
the dates the record itself carries (the phones out from about
July 2, the illness noticed July 5, the outbreak reported July 6,
the cordon July 5-6, the boundary breached July 14, Louisville
overrun July 16, 1993), so that the shipped assets serve any 1993
start rather than only the shipped July 9 one.

**Why.** The operator ruled it on 2026-09-06, on seeing the digest
of the shipped record: the lines can be made controllable so the
available assets are usable across a 1993 living start. The claim
was verified against the installed jar before it was written down
(ENGINE_CONTRACT Addendum E):

- The engine keys every broadcast to days since the save began,
  never to the calendar - `ZomboidRadio.daysSinceStart` seeds from
  `GameTime.getNightsSurvived()`, persists in the radio save file,
  and steps at each hour-zero rollover.
- Each script's clock is `stamp - startDayStamp`, and the start day
  is a public setter (`RadioScript.setStartDayStamp`,
  `RadioChannel.setActiveScript`); the manager can simulate a
  schedule forward to any stamp and add or remove channels; the
  loader takes non-vanilla radio XML.
- The engine already re-keys its own schedule per game mode
  (`checkGameModeSpecificStart`): "Initial Infection" and "Six
  Months Later" are nothing but this control applied.
- The newspapers are dated absolutely in their titles but placed on
  no calendar at all: `RecipeCodeHelper.nameNewspaper` picks an
  issue at random from the paper's fixed list, or the newest issue
  for `NEWSPAPER_NEW` items; nothing reads the game day. The issue
  a found paper shows is a list index, and the print media of an
  item is modData (`printMedia` table) a mod can write.

So the schedule and the issue choice are both within reach of the
mod, in-process, with no engine patch.

**Consequence.** The Day Zero arc gains slice 7 (ROADMAP): the
record re-keyed to the county's calendar - a living start that
begins before July 6 hears the pre-outbreak county first (the six
Knox Knews issues, the phone outages, the Army truck on Route 60,
the parade), then the fall in its shipped order; Months since the
Apocalypse and later Start Days shift it the other way. Nothing is
built by this ruling; it scopes the work. The Speakeasy world
document knox-event.md keys every event to its absolute date for
the same reason, and records where the broadcasts' own
day-counting is loose by a day or two before day 3.

**Origin.** Operator ruling in chat, 2026-09-06; engine
verification the same day, per the operator's standing law that
their own claims are verified before they enter a record.

## DR-032 - Children, elders, and the conditions of a person come through required mods

**Decision.** The county is to have children and elders, and its
people are to carry the conditions that shape what they know and
remember - dementia and memory loss, chronic illness, disability,
the effects of age - and whatever else fleshes a person out. The
engine supplies none of it: it stores an age integer that nothing
reads, ships no child or elder body, and its 97 traits carry no
cognitive decline. So the mods that add these bodies and conditions
are catalogued (the Speakeasy scoping index, who-knows-what.md,
ruled 2026-09-06) and, once chosen, become native requirements of
SAO (mod.info `require`), with SAO's age bands, census and
knowledge machinery extended to read what they provide. Which
mods: pending the catalogue; each is chosen through Crucible.

**Why.** The operator ruled it 2026-09-06 through Crucible, on the
scoping index's open questions: the child's-memory band teaches
vagueness AND the county gets children and elders through
catalogued mods made natively required; knowledge decay varies per
person, so traits such as dementia and health mods for chronic
illness are to be located, with anything else that fleshes out the
world and its people. Verified the same day (ENGINE_CONTRACT
Addendum F): `IsoGameCharacter.getAge` / `setAge` exist and only
`IsoGameCharacter` itself references the field; the survivor type
enum is Friendly, Neutral, Aggressive; no class in the jar is named
for children or elders.

**Consequence.** A dependency ruling: SAO takes hard requirements
on third-party mods for bodies and conditions, so its population,
dressing, census and age arithmetic must read what those mods
provide, and the scoping index extends its age bands below 19 and
above 68 once the bodies exist. Two companion rulings the same day:
the follower share of the county is not a parameter - it follows
from who survives or is simulated to survive - and per-person
knowledge decay is designed once the catalogue is in.

**Amended the same day.** An elder model is not needed: an elderly
person is represented on the adult body by hair, condition, behavior
and age. Only children need a smaller body, and the engine's own
model-instance scale reaches it without a third-party mod. The
"bodies" this ruling requires from mods therefore narrow to none
that exist soundly; what it requires is conditions and age.

**Selection, ruled the same day through Crucible after the
catalogue's three parts (Speakeasy, world/people-mods.md).** Age:
Getting Old's mechanics are ported into SAO from its public source,
SAO's age the one truth, no runtime dependency, credited through
CREDITS.md. Memory and cognition: both - the Build 42 condition mods
(Infirmities, Even More Traits, Humans: Are Weak) become runtime
requirements with their frameworks for what players see, and the
memory conditions (Neurodiverse Traits' Alzheimer's, ADHD and
Bipolar; Custom Traits' Dyslexia; Scotty's Mental Health Expansion's
six; the Build 42 ADHD Trait) are ported as SAO's own to drive
per-person decay. Substances: the dependency model comes into SAO's
habits (S6); nothing required. Children's bodies: Growing Up was
subscribed and read (the Speakeasy catalogue records the read). It
never touches a model; Realism V4 applies its height and bone
sliders through 41 replaced engine classes built for an older
revision. Ruled, then corrected the same evening: the first ruling had SAO
scale its own people through the engine's model-instance scale, on
the claim that the renderer honours it; the jar says it does not -
nothing in the character render path reads `ModelInstance.scale`
(the vehicle class alone does), `ModelScript.scale` is read only by
the world-object and item drawers, and a calf is its own mesh. The
claim is withdrawn (ENGINE_CONTRACT Addendum F, corrected row).
What stands: Growing Up's plain-Lua systems come into SAO as its own
- the age curves for speed and weight, the fear floor by age with
night terrors and a comfort object, literacy earned by reads, the
experience throttle with birthday floors, the archetypes - credited
through CREDITS.md. The child body itself went back to the operator
with the corrected facts, and they ruled: SAO's own Java agent
instruments the animation player FIRST - a load-time transformer
that scales a character's bone transforms per person, verified live
- and the age systems follow it. Children are drawn only when that
lands; nothing wrong is drawn meanwhile.

**Origin.** Operator rulings via Crucible, 2026-09-06; the elder
clarification in chat the same day.
