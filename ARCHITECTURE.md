| Document | Survivor Awareness Overhaul Architecture |
|---|---|
| Version | `0.6.0.0-pre-alpha` |
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
that person. It does not own execution and it never invents knowledge.

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
hours (metabolism at approximate engine rates, offset by eating carried
food - the architecture's sanctioned direct-mutation mode for the UNLOADED
world only). Dormant records drift through coarse days ([A11]): waypoints
near home in daylight, home at night, no geometry - an abstraction of a
person, not a hidden puppet. Death is durable: corpses belong to the
engine, records become death records, claims lapse ([A11]), refill waits
its sandbox-governed days and happens at spawn regions, never at the loss.
All policy numbers are sandbox options.

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
- **The person persists** (F-013): position, pack, hand, vitals, and worn
  clothes ([A11]) survive hibernation on the record.
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
