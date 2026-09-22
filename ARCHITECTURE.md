| Document | Survivor Awareness Overhaul Architecture |
|---|---|
| Version | `2.8.10.0-pre-alpha` |
| Author | ellyj3rain |
| Repository | `ARCHITECTURE.md` |
| Status | ACTIVE - ratified framework shape. |

# Architecture

## Product boundary

A survivor is an autonomous human agent. It is not a scripted zombie, and it is
not a second local-input player.

Survivor Awareness Overhaul owns persistent survivor identity; perception and
memory; goals, planning and decisions; movement and interaction intent;
relationships, orders and territory; and serialization of all of the above.

Project Zomboid owns the active engine representation and every world mechanic
that can be reused safely — pathfinding, animation, inventory, timed actions,
combat resolution, `BodyDamage`.

## Runtime layers

1. **Identity** — stable IDs and persistent human state, independent of any loaded
   engine object.
2. **World representation** — an engine body created only while its cell is active.
3. **Perception** — what this survivor has observed, heard, been told, and still
   believes, with provenance and decay.
4. **Controller** — converts goals into movement, combat and interaction intent.
   One action owns the body at a time.
5. **Actions** — executes player-valid operations through normal engine paths.
6. **Simulation** — advances survivors outside loaded cells without keeping full
   engine objects alive.
7. **Persistence** — saves owned state and reconstructs bodies safely.

## The four pillars

### Perception — what is admitted

A survivor decides on a private belief set, never on map truth. Every fact carries
its origin (**observed**, **heard**, **told-by**, **inferred**) and a timestamp.
Beliefs decay; a room checked twenty minutes ago is not a room known now.

Perception owns sightlines, sound propagation, memory of places and people,
uncertainty, and the distinction between *there is no threat* and *I have not
looked*. It does not own map truth the survivor has not acquired, and it never
grants permission.

This pillar is the one whose absence produces the characteristic failure of
existing NPC mods: a decision function that reads the world directly, computes
against geometry the agent could not know, and so is simultaneously omniscient
about walls and oblivious about people.

### Disposition — what is wanted

Nerve, discipline, aggression, initiative, trust, self-preservation. Disposition
converts a belief set into a preference ordering under risk. It does not
manufacture facts and it does not grant permission.

Disposition is where skill lives, and it is bounded: it changes latency, breadth,
precision and coordination. It does not license behavior outside the human
envelope. A low-nerve survivor hesitates, withdraws early, and shoots badly. A
low-nerve survivor does not walk into a doorway it believes is covered.

### Standing — what is allowed

Relationships, group membership, orders, territory claims, hostility state, and
who may direct whom. Standing channels a preference into a permitted action. It
owns whether this survivor may enter that building, take that item, or fire on
that person. It does not own execution and it never invents knowledge. Its
command surface is `SAO_Command` (`[C16]`, DR-033): whose word a person takes,
in what matter, and why not - CAO's check on the standing that exists.

### Execution — what is done

Movement, entry, combat, looting, work, treatment, withdrawal. Execution rides the
engine: normal pathfinding, normal timed actions, normal combat resolution. It
owns *how*, never *whether*. It does not consult global truth, personality, or
relationships — those were already resolved upstream.

## Worked example: entry

The behavior that motivated this project. A hostile survivor breaks an intact
window to enter a house whose door stands open, climbs through, and stops.

Under a single geometric cost function that outcome is not a bug — it is the
correct output of a model with no term for anything that matters. The composition
produces a different decision because each pillar contributes what it owns:

| Pillar | Contribution |
|---|---|
| Perception | Which openings has this survivor actually seen? The open door on the far side is not an input unless it was observed. An armed occupant facing the window is an input **if and only if** the survivor perceived them. |
| Disposition | How much risk does this survivor accept to get inside? Under pressure the calculus changes and a smashed window becomes correct. |
| Standing | Is entry permitted at all? Hostility, territory and orders decide whether this is a break-in, a homecoming, or something not to attempt. |
| Execution | Given a chosen opening, open / climb / smash through normal engine actions, and report failure honestly when the route does not work. |

Both symmetric failures are excluded structurally. Widening the search until the
door is always found is omniscience and is refused by Perception. Forbidding
window-breaking outright is oblivion and is refused by Disposition — a survivor
fleeing a horde *should* go through the glass.

## Verified engine surface

Established in `[A2]`/`G0` against the installed Build 42.20 jar and shipped
Lua; each item cites its finding. `ENGINE_CONTRACT.md` is the CANONICAL
complete reference (movement transplant, combat patch, timed-action queue,
fluid surface, stair seams, ranged gate map); this list is the founding
subset. Anything in neither place is a hypothesis.

- `IsoPlayer.setNpc(boolean)`; the getter `isNpc()` is inherited from
  `IsoGameCharacter`, not declared on `IsoPlayer` (F-001).
- `zombie.characters.component.AIComponent`, an ECS component reached through
  `IsoPlayer.visitAllPlayersWithComponent(...)` (F-002).
- `AIComponent.getHumanControlVars()` → `AIBrainPlayerControlVars`: **an input
  channel, not a goal channel** — `strafeX/strafeY` axes plus intent booleans
  (`aiming`, `melee`, `initiateAttack`, `running`, …). The engine accepts no
  destination through this seam; Execution owns the route and converts it to
  per-tick axis values (F-003). Route *production* is separable and engine-owned:
  `PathFindBehavior2` is independently drivable (`pathToLocationF`, `update()` →
  `Working|Failed|Succeeded`), exposes its next waypoint as public fields, and
  even carries a Lua-table goal overload (F-007). Execution requests routes from
  the engine and follows them through the axis channel.
- Three `IsoPlayer` constructors including the `SurvivorDesc` + coordinates form
  used for reconstruction at a recorded square (F-004).
- `SpawnRegionMgr.getSpawnRegions()` in shipped shared Lua, for origin allocation
  that is not player-relative (F-005).
- NPC bodies occupy `IsoPlayer.players[]` slots; construction must not disturb
  the local player's slot (F-006).

## The needs layer (as built, [A8]-[A10])

Needs are engine stats read Java-side (`CharacterStat` HUNGER/THIRST/
FATIGUE/ENDURANCE) and satisfied through the game's OWN timed actions -
eating, container transfers, drinking from world objects, bandaging,
reloading are animated, timed, and interruptible exactly as they are for
the player. Priority under no-threat: bleeding > thirst > hunger > company
> homing > gear/ammo errands > roam. Every hunt (food, water, weapon
upgrade, ammunition) shares one discipline: Java-side scan with a one-floor
ring and a heavy cross-floor penalty, a remembered source revalidated
before use, reach checks, claims respected below desperation, night holds
on leisure errands. The one non-vanilla-action mutation in the loaded
world is rag-ripping ([A10]): time charged in a hold state, terminal state
  (Also named here for honesty, [A19]: `engineEat` - the eat fallback when the vanilla queue refuses - calls the engine's own Eat, the same semantics vanilla runs at complete(); an engine-call fallback, not a stat poke.)
identical to the vanilla recipe, recorded as pending real craft-system
comprehension.

## Revision-bound world-source action and result projection (C61-C64)

`SAO_WorldSources` owns durable native observations, conflicts, reservations
and results. A place belief stores the exact source revisions that person saw;
an observation remains neither public availability nor mutation authority.
`SAO_SourceUse` owns one live source action from proposal through result. It
routes first to the known place and then to a Java-selected interaction square,
asks Standing again against the current claim, and binds only after Java
re-resolves the current source fingerprint, revision, exact item, same-floor
reach, obstruction and vehicle-part permission.

The physical transfer remains a vanilla inventory-transfer or ground-grab
action. The physical consequence remains vanilla `Eat` or `DrinkFluid` on the
same exact carried item. Java's runtime-only body binding measures item/fluid
and need state before and after native completion or stop; it is cleared on
world reset and never becomes a second inventory. Lua persists the action
phase. An unspent cancellation releases, a changed revision conflicts, a
partial native stop records interruption without need credit, and a completed
effect publishes one pre/post-revision receipt and stamps that actor's food or
water day. Completed receipts remain in durable order until the provisioning
consumer acknowledges them idempotently.

C63-C64 consume that result without turning it into an authored outcome. At final
native binding, an exact source inside the actor's current group claim captures
that house and the current claim incarnation. Publishing the completed result
captures the Material setting with the event. The consumer resolves an isolated
copy of the latest exact native source
and replaces its prior house projection by source identity. A durable
single-owner index and result order prevent one source from remaining in two
houses or an older retry from reversing a newer owner. Applied reconciliation,
its chosen outcome and affected-house projection generation persist until
acknowledgement succeeds. Source
observation time orders completed-result claims against live quartermaster
scans; projection generation orders actual aggregate mutations and prevents an
applied older retry from reversing newer evidence. At most 256 source rows are retained; item and
finite-category totals are rebuilt from those rows. Personal use grants no new
house credit but may refresh an existing owner. Missing non-ground truth waits
when ownership exists; completed ground removal affects only the matching
fingerprint. A changed or re-created claim cannot receive an earlier event.

One selected source is exact but partial evidence. C64 marks every such store
with incomplete `selected-native-sources` coverage, so it does not derive a
house larder/water claim and cannot synchronize settlement storage. Those
aggregate projections require a future producer that proves complete coverage
of the held place. Recognition still cannot create a settlement, building,
organization, membership, room, food or water fact. The receipt is acknowledged
last. Standing setters, dormant need-day projection and queue acceptance are not
provisioning producers. Quartermaster scans retain their separate evidence
basis. Claim movement, abandonment and dissolution retire house material and
settlement-storage projections; delayed receipts revalidate held ground. C62
schema-3 results retire explicitly unattributed instead of borrowing later
membership. A refused acknowledgement resumes the persisted outcome before
source lookup; if execution stops after acknowledgement, the next delivery pass
cleans the retained transaction. The event-time Material setting cannot be
reinterpreted by a later toggle. Performed shelving and the remaining material
action families still need their own completion results under R9.

Native truth can change without another survivor action. WorldSources schema 5
therefore stores one coalescing, ordered change per source already relevant to a
Material projection. Provisioning drains that queue after reload. Material may
refresh or retire the exact existing owner while preserving the completed
result that first attributed it; ambient observation cannot create an owner or
completed-work credit. A change is acknowledged only after projection update,
and a newer observation cannot be removed by an older acknowledgement.

Graph schema 2 removes the outputs left by the superseded bridge: a pre-C63
house store without `native-sources` provenance and a base without a completed
`place-development` result are retired once with explicit upgrade provenance.
A linked provisioning-only organization is removed; an organization grounded
by an election keeps its chair while its old base-authored boundary,
governance and membership are cleared. Standing schema 2 retires legacy
larder/water/hearth claims and assigns claim incarnations without inventing
history. Future graph and Standing schemas refuse before mutation, and graph
refusal detaches every prior-world durable alias. `Settlement.claim` accepts
only completed place-development evidence and has no organization or membership
side effect. Person-facing material surfaces copy scalar maps. A combined
personal/house view has no aggregate owner; ownership remains explicit only on
its nested personal and house views, preserving Material as the sole mutable
owner even when Integration publishes the view.

Graph schema 3 marks every retained C63 native-source house store as partial and
clears storage synchronized from that partial projection. Standing schema 3
removes only C63 completed-source larder/water claims; independent quartermaster
evidence remains. Both migrations record what they retired and infer no earlier
history.

The reservation is also the cross-pillar actor owner. Dormant population
mutation, bodyless pathogen encounter/snapshot observation and WorldGenesis graph
application skip a source-owned actor. The live controller settles mortality and
Crossed transfer before restoring the durable source phase, and an unreadable
future-schema owner holds the actor rather than being interpreted as absence.

## Decision evidence boundary (C64-C65)

`tools/county_dump.py` observes the existing Standing election from outside the
mod. `tools/sweep/decision_capture.lua` deterministically serializes the complete
decision document before the real verb runs, then serializes the immediate
authored result separately. It rejects required-reader failure, unsupported
values, cycles and excess depth instead of rendering them as `null`. The real
election still executes when observation fails.

Each county belongs to a unique capture invocation and run namespace. The run
envelope retains a deterministic configuration hash, seed/draw state, settings,
engine mode, requested/reached horizon, clock/schema versions and source/model
provenance. The evidence host exposes unavailable loaded ground rather than the
sweep prelude's historical fixture. Every requested county must pass callback,
capture and horizon validation before a staged directory becomes visible by one
atomic rename.

This observer does not expose executable options, make a model choice or track
an action-specific consequence horizon. Those three fields are explicit and the
event is conditioning-ineligible. Speakeasy owns later option/choice authoring
and its fully namespaced join; runtime execution will revalidate a selected
option under R11-R14.

C65 exposes source selection before reservation. `WorldSources.actionOptions`
lists at most 128 stable source attempts at the place and need already admitted
by Controller. Each option names SourceUse, exact source/item/revision parameters
and private observation plus attempt-permission evidence. Truncation and total
candidate count are explicit. `SourceUse.chooseOption` retains the existing
first-source policy. `beginAction` rechecks the current body, private evidence,
permission and exact chosen parameters; an invalid selection refuses instead of
substituting another source. Arrival and native binding retain their physical
access and current permission checks.

The same capture tool observes that actual choice when SourceUse is loaded.
Person, private situation, policy context and offered options freeze before
selection; the choice is separate and binds to the returned reservation. A
detached actor-scoped result distinguishes completion, refusal, interruption,
pending work and a result no longer retained. Requested quantity and observed
native consumption are separate. An unreadable result store rejects capture.
The observation horizon ends at the action result or capture end; later effects
are unobserved. Runtime policy choices are unratified and conditioning-ineligible.
The county sweep has no loaded source executor and reports that coverage as
unavailable. C65 adds no synthetic source decisions to its output.

## Voice ([A9])

Terse lines through the engine's own `Say` bubbles at moments the pillars
already decided - state transitions and social events (warnings, grudges
told, company formed, violence witnessed, trespass, greeting, sharing).
Voice renders decisions audible; it never decides. Talkativeness is a
disposition trait; urgency always speaks; repeats are swallowed.

## Population lifecycle ([A6]-[A7], [A11], [A11])

Identities originate region-balanced from the map's real spawn tables -
inhabitants, not spawns around the player. The player band governs only
which records carry live BODIES. Hibernation packs what a body carries and
is into its record ([A11]); awakening restores it and charges the dormant
hours at approximate engine rates. C56 reconciles carried food and fluid
through native partial consumption, including nested containers, nutrition,
spoilage and quantity accounting. Dormant records drift through coarse days
([A11]): waypoints
near home in daylight, home at night, no geometry - an abstraction of a
person, not a hidden puppet. Where that day GOES is a decision: need
past patience reaches the nearest known place offering the thing
([C10]), somebody trusted and recently seen is somewhere to go
([C29]), and otherwise the neighbourhood's own places, ranked by what
they offer today and how long since they were seen. How far the walking
gets them is a rate over the county's clock - the ratified day-reach
scaled by the pace of the age (DR-040) - so a day of clock carries a
day's walking in either half of the county, and a goal further off
takes the days it takes. Death is durable: corpses belong to the
engine, records become death records, claims lapse ([A11]), refill waits
its sandbox-governed days and happens at spawn regions, never at the loss.
All policy numbers are sandbox options.

C57 gives `SAO_BodySnapshot` the shared native-envelope contract: version
interpretation, capture, validation and durable commit. `SAO_Body` owns
materialization, checkpoints, release and transfer transactions; the shared
module owns no body registry. Release and transfer validate supplied native
payloads and envelope fields before publishing durable state or ownership.
Afflicted return shares the version reader and retains source removal and
adoption. Native formats and save keys keep their existing readers.

C58 gives `SAO_Population` the population cadence, fault gates, daily order and
historical slice orchestration. `SAO_PopulationAdmissions` owns origins and
admissions; `SAO_PopulationRepresentation` owns loaded bands and passive foreign
adoption; `SAO_PhysicalFacts` owns physical capture and commit;
`SAO_DormantPopulation` owns offscreen advancement. Historical and live calls
receive the scheduler's current tick. Body owns temporary-body transactions;
History owns the clock. Existing public Population functions delegate to those
owners. Population replaces its stored callback on reload and clears runtime
caches and fault/cadence state on world initialization. Durable stores retain
their existing keys and progress fields.

C72 extends that ownership boundary to rest. BodySnapshot reads fatigue,
endurance and saved sleep-need traits from the native envelope without making a
body; PhysicalFacts captures loaded sleep and seated rest. DormantPopulation
advances the durable values on History's county clock before movement and
encounters. An at-home person rests from 22:00 to 06:00, crosses the existing
fatigue threshold into sleep, recovers under the loaded non-slot sleep law and
wakes at the morning boundary. Sleeping holds movement. Older records without
native measurement or explicit generated provenance remain unknown. Body first
restores the native envelope, then applies and verifies the completed durable
fatigue, endurance, sleep and posture before Controller adoption.

C73 extends the same temporary-body boundary to radio state. The native
inventory reader captures only direct-root communications radios, which is the
installed carried-frequency boundary, and records item identity, tuning,
on/off, volume, battery power/use and transmitter state. PhysicalFacts stages
that sidecar with the snapshot. While no body exists the record advances only
battery use and its resulting off transition; Body must match and apply that
state to the exact restored device before publication. A bagged device and a
legacy possession flag establish no endpoint.

Communication owns radio admission at an event hour. It joins a living awake
listener and measured hearing with an on, powered, audible, tuned receiver;
transmission additionally requires a two-way unmuted device. Perception writes
the recipient-private broadcast receipt before County Wire or player-radio
content changes knowledge, relationships or action. The receipt is the durable
link between transmission and claim acquisition. Household membership performs
no implicit relay.

## Combat doctrine ([A7], [A8], [A10]-[A10])

One evidence-based combat loop (approach, aim settle, `pressedAttack`,
damage-observed verdicts) serves any `IsoGameCharacter` target. Doctrine
chooses: an armed survivor whose temperament says fight stands ground
against a close zombie; a grudge (hostile standing) is confronted through
the same loop, by gun beyond arm's reach when one is loaded; overwhelmed-
with-nerve opens fire - at the engine-real price that everything hearing
the shot reacts. Quiet is the default: the bat comes back out after every
engagement. Person-permission is Standing's alone (hostility must exist;
same-group never).

## The society (as built, [A14]-[A15], DR-006)

Survivors organize independent of the player. Company forms from mutual
trust and grows by third wheels; leadership is a trust-sum fact with
consumers (following, flight refuges, household consolidation, move-in
hosts, succession at death); three members take a NAME and their leader
scouts scored buildings, claiming one by standing in it - homes converge
and the base is lived in, defended, and eventually inherited by its
widow, who keeps the house. Knowledge is claims with provenance
([A14] law): epistemic ages, formative claims that echo into traits,
lessons minted by deaths and carried one per conversation, faction and
place beliefs acquired by sight, introduction, or being told off - and
per DR-007 travelers respect only what they BELIEVE, with first offenses
pardoned aloud and taught. The player joins this society through three
plain verbs riding the same standing web as everyone else; bonds deepen
four behaviors and their loss forks a person once, by who they already
were. Habits live on the surfaces the install really has.

## The county (as built, [A17]-[A22], DR-008..DR-011)

**The census** (DR-010): every record carries an occupation drawn from a
circa-1993 Knox-area distribution over the engine's OWN profession
registry - modded registrations fold in automatically at classified
rarity ([A18]/[A18]). The trade shapes the settled past (claim affinity
+ provenance tilt, [A18]), the descriptor and live perk levels
([A18]/[A19]), the worn outfit ([A20], verified vanilla names), the
first-meeting kit ([A21] sidearms and tools), and genesis placement at
the engine's profession-keyed spawn points ([A18]); one in five births
brings a day-one bonded mate.

**The workday under the tax** (DR-011): every agent answers need /
designation / chosen rest / errand at the setState seam ([A18]) -
a mannequin is structurally impossible. Companies deal jobs at
election; the watch walks the claim edge, foragers sweep early,
quartermasters stock real containers, medics DELIVER bandages
([A19]/[A19]/[A19]) - and the player may ask a willing companion to
work a job ([A19]). Chosen rest is short and positioned; one in ten
carries an instrument ([A19]).

**Politics**: companies accrete creeds from their rosters
(order/mercy/wall/road, [A18]); opposed meetings cool pairs until words
become weapons, two hostile cross-pairs make a FEUD ([A20]), feuding
economies refuse the placed enemy ([A21]), the map bends around feuds
([A20]), leaders whose regard heals make PEACE ([A21]), divided
houses SCHISM into rival companies - in rooms and on roads
([A22]/[A22]) - and the ledger chronicles the wars ([A22]).

**Death's social shape**: one witnessDeath law for every death
([A17]/[A19]); news travels as belief cargo with told-weight grief
([A19]); dormant attrition under the sandbox dial with word-finds-them
delivery ([A20]); graveside lessons normalize over the whole cause
vocabulary ([A22]); mourners revisit ([A21]); the county mourns the
PLAYER ([A22]).

**One world with Knox Survivors** (DR-009): inhabitants adopt with
engine-true pasts, **the census deciding who somebody was** (DR-012 -
`[A20]` reversed; their archetype no longer overwrites the draw and no
longer clears the presumption flag), homes and
own-camp beliefs seeded read-only from their store ([A19]), their
relationship history imported at half-strength ([A21]/[A22]), the
name-key migration owes nothing ([A19]), and every player verb reaches
them ([A21]/F-032). Their mod is never written, their bodies never
driven.

**Resilience**: per-subsystem and per-agent bulkheads ([A21]); the
scope-split scanner and the cross-file invariant sweep run as
pre-commit habit ([A19]/[A22]).

## The material county (as built, B era)

The A era built a society of claims: who people are, what they know,
who they trust, and how houses form and fight. The B era gave that
society a world to live in, under one law: derive, do not author -
nothing exists because a table says so.

**Possessions and the economy.** Nobody is issued anything. At first
materialization a life's pockets come from PLACE x PERSON: the real
containers around the ground the census anchored them to, filtered by
what someone with their traits and trade would notice (`[A28]`).
Items MOVE - what a survivor carries left a shelf somewhere. Foragers
gather real food on real sweeps and shelve it at home (`[B4]`... see
`[A28]`); quartermasters count the shelves and the water and the
motor pool at their rounds, deriving claims that stale out honestly
rather than lying (`[A28]`, `[B1]`, `[B6]`); farm hands work real
plots through vanilla's own actions (`[B4]`); watchers board windows
with real hammers and planks (`[B2]`); the cold seek fires, feed them
what actually burns, and light them when they carry the means
(`[B6]`). Nothing in the dormant world fabricates goods, because
unloaded cells have no containers - stated, not fudged.

**Bodies and medicine.** Wounds outlive the moment: infections are
seen at a glance, cleaned with what is carried, dressings changed,
and medics walk to fever as they always walked to bleeding (`[B7]`).
The bitten are visible, spoken of, feared or nursed by creed, and
their promises are kept by whoever heard them (`[B3]`). A wound
follows its owner into dormancy and can kill them there (`[B10]`).

**Skill.** The engine's own perk levels are read back, so who is
capable actually matters: the election hands each job to the best
hand, work scales with skill, and housemates TEACH each other -
which is most of why anyone joins a house, and the true price of the
loner's circle (`[B2]`, `[B11]`).

**Knowledge at distance.** The wire runs both directions: the county
broadcasts its own politics and losses, whoever really owns a
receiver hears them as told-provenance claims, the player can be
heard, can call, can share a camp, and can petition houses they are
nowhere near (`[A26]`-`[A26]`, `[A27]`, `[B9]`).

**Time.** Ventures are announced with terms, expectations are learned
by watching people come back, worry is felt per person, and searches
argue before they leave (`[A28]`-`[A28]`, `[B1]`). Standing itself
ages: what nobody refreshes drifts toward neutral, and enmity that
fades simply ends (`[B8]`).

**Coexistence.** Other mods' people are seen but never confused with
ours or with the player - they have their own key domain, and nothing
here can drive a body it does not own (`[B10]`, DR-009).

## Cross-pillar invariants (the F-ledger, load-bearing)

- **Engine-object interop law**: Lua never iterates or indexes engine
  objects; Java decides and hands Lua verdict strings or opaque values
  passed straight into vanilla constructors.
- **Canonical person keys** (DR-005/F-010): Standing stores record ids for
  survivors, `player:<name>` for the real player; Perception speaks
  usernames; conversion at the controller boundary only.
- **Sight is cell-wide** (F-011): the person scan walks the cell's moving
  objects, never the 4-slot local array.
- **Route-cancel invariant** (F-012): leaving the movement-state family
  for a non-member cancels the route centrally in setState - an armed
  engine route with no owner is the autonomous-wandering defect.
- **The person persists** (F-013): position, possessions, equipment, wounds,
  statistics, experience, nutrition, conditioning, learned/read material,
  appearance and declared durable metadata survive hibernation on the record.
  C51 stages a validated snapshot before teardown and restores through Body
  before adoption; C54 completes the native-person envelope and keeps older
  formats within their original limits. A retained transition counts as
  represented but has no available body for physical interaction. Runtime
  actions and registries reconstruct under R4 rather than becoming history.
- **Distance is personal** (F-014): belief positions are memory; distance
  to a belief is computed at query time from the asker's position.
- **Fault gates**: every per-tick path is pcall-wrapped, logs once, and
  disables itself after three faults rather than throwing per-tick.
- **Weight ladders**: perception provenance observed > heard > told;
  standing consequence suffered (1.0) > witnessed (0.6) > testimony
  (0.4-scaled by credibility). Told never overrides observed, in both
  pillars.

## Rejected approaches

**Zombie-backed humans.** Driving survivors as `IsoZombie` with the zombie
behavior suppressed in script. The approach inherits the zombie state machine, so
its failure mode is reversion to zombie idle; it is exposed to every consumer of
`OnZombieUpdate`; and it requires continuous correction against the engine rather
than cooperation with it. Rejected on those grounds.

**Widening perception to fix a decision.** Any fix that gives a survivor more
world access to make a better choice is treated as a defect in the decision model,
not a solution.


## Performed transfer knowledge (C67)

WorldSources remains the durable action/result owner and Provisioning the sole
result consumer. The verified native transfer wrapper freezes physical proof,
actor, contemporaneous witnesses, time and position before later reconciliation.
Private observation can survive a later material conflict without declaring the
action's final source reconciliation successful. Unacknowledged observations
remain protected until the same consumer delivers them.

Perception owns bounded private episodes and aid requests in its existing saved
beliefs. Episodes distinguish event time, personal acquisition time, origin and
immediate teller. Testimony uses listener skepticism and speaker willingness,
plus current loaded hearing or a supported adjacent dormant encounter. Actor
intent, hidden item properties and source inventory do not become witness facts.
Knowledge projects the facts through existing food/water topics without writes.
Historical request readers withhold current-only location joins.

A witness on their own held ground can assess a stored item against their own
category need, compassion and trust at that moment. Only that person's episode
contains the appraisal. Remembered reciprocity bends the existing charity
decision toward the benefactor; it creates no collectible balance or accumulating
trust. Appraisals never travel with testimony.

Native hearing reads current loaded conditions or validated v3/v4 saved traits
and worn gear; saved reading creates no body or item. Generated default access
has explicit Identity provenance. C72 adds record-owned rest/sleep/wake before
the dormant encounter pass, from native measurements or explicit generated
physiology. The prior speech marker alone does not establish an awake state.
C73 requires exact receiver access and a private reception receipt before radio
content is available to that mind; possession remains a separate inventory fact.

## Personal handovers and terms (C68)

Handover owns person-to-person item transfer state. Its saved record contains
only scalar people, item identity, kind, term, status and consequence data. Live
bodies, inventories, items and timed actions exist only in its runtime map. The
vanilla transfer subclass repeats person binding, same-floor proximity and exact
source-holder checks at mutation, then requires the destination holder before it
publishes completion. Queue admission is only a pending reservation.

Exchange and Controller supply the intended consequence with the request.
Handover applies trust, voice, settlement, aid stamps and care experience once
after a non-term completion. Reading and fear-driven yielding use the same
owner. A pending record without a runtime witness after reload remains pending
and reserves its exact item; neither elapsed time nor queue absence supplies
holder proof. The person-death funnel releases pending work involving either
participant and drops its live engine handles while retaining completed history.

A bilateral term begins as a proposal. Both directed native actions must be
admitted before Handover records acceptance. A failed proposal cancels the
pending actions and creates no debt. Once accepted, two completed legs apply the
trade consequence; one completed leg and one terminal failed leg add exactly one
existing Standing debt in the completed giver's favor. Gifts never enter that
path. Open-wound treatment remains a separate owner because it mutates a named
patient rather than changing an item's holder.

## Open-wound treatment results (C70)

Treatment owns SAO-initiated bandaging across self-care, survivor aid and player
aid. Its saved record names the actor, patient, exact dressing and patient body
part, plus status and consequence receipts. Bodies, parts, inventories, items
and timed actions remain current-world handles only.

The treatment action delegates the physical mutation to Build 42.20's
`ISApplyBandage.complete`. It publishes effective completion only when vanilla
returns success, the exact patient part carries a positive-life dressing and
the exact item has left the actor inventory. Native refusal or a zero-life
dressing is ineffective. Stop, cancellation and queue loss are interruption.
Identity, reach, body-part membership and item ownership are rechecked before
native mutation.

Patient trust response, the answered-cry stamp, SAO care experience, aid voice,
the treatment log and the critical-care gesture consume the completed result
through separate durable flags. Reload can resume an unavailable channel, such
as Doctor experience while the actor body is absent, without repeating the
channels already consumed. A pending record with no current action handle stays
pending and reserved; neither time nor the patient's later appearance proves
who treated the wound. Death and body-ownership exit release unfinished work.

## Private inventory observation (C71)

The engine owns inventory state and movement. `SAOPrivateInventory` is a
call-site view: it recursively reads one person's native carriage and the
loaded static, vehicle, ground and corpse holders that person's decisions may
consult. Native item IDs, direct parents and persistent world-source holder IDs
remain distinct. The view is never persisted, never shared between people and
never executes a transfer.

Loaded world coverage is bounded and actor-specific. Vehicle permission is
evaluated for the named body, unexplored contents are unknown, and inaccessible
holders refuse. Dormant v4 coverage contains exact carriage only; world holders
are unknown. The encoded contract refuses aggregate stock, so a current radius
cannot become a household larder or water claim. Standing accepts those totals
only from a completed Material reconciliation with explicit complete coverage.

Decision readers use exact item objects from the view. A nested item keeps its
direct source container for native transfer and its root holder for permission.
Existing SourceUse, Handover, Treatment and engine timed-action owners retain
mutation and completion authority.

## Recipient appraisal after testimony (C69)

Testimony transfers a performed act, not the teller's response to it. A listener
who did not witness a stored food delivery may appraise it only when their own
private state supplies a still-active request from their current household and
an explicit faction/place claim containing the recorded event location. The
request must precede the act. Event, request and claim keep separate acquisition
and origin provenance; no historical body pressure or giver intent is rebuilt.

The listener's compassion, current trust in the actor and credibility assigned
to the immediate teller produce one signed reciprocity value at the established
testimony weight. That value and all inputs are frozen on the listener's told
episode. Retelling omits it, so the next listener either forms a different
appraisal from their own evidence or forms none. The existing private
reciprocity reader bends the listener's charity decision without adding trust,
debt, settlement credit or a public account of what the act meant.
