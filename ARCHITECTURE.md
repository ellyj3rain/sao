| Document | Survivor Awareness Overhaul Architecture |
|---|---|
| Version | `3.12.0.0-pre-alpha` |
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
that can be reused safely â€” pathfinding, animation, inventory, timed actions,
combat resolution, `BodyDamage`.

## Runtime layers

1. **Identity** â€” stable IDs and persistent human state, independent of any loaded
   engine object.
2. **World representation** â€” an engine body created only while its cell is active.
3. **Perception** â€” what this survivor has observed, heard, been told, and still
   believes, with provenance and decay.
4. **Controller** â€” converts goals into movement, combat and interaction intent.
   One action owns the body at a time.
5. **Actions** â€” executes player-valid operations through normal engine paths.
6. **Simulation** â€” advances survivors outside loaded cells without keeping full
   engine objects alive.
7. **Persistence** â€” saves owned state and reconstructs bodies safely.

A mobile household has two simultaneous spatial facts. Its exterior vehicle is
the durable place anchor used by memory, planning, dormant simulation and save
state. An occupant's loaded body may be inside a provider-owned remote physical
room. Representation distance follows that physical body while it exists and
the durable interior binding reconstructs it after body replacement; body
capture never overwrites the exterior anchor with the remote-room coordinate.
Entry and exit remain native transitions with recorded results.

## The four pillars

### Perception â€” what is admitted

A survivor decides on a private belief set, never on map truth. Every fact carries
its origin (**observed**, **heard**, **told-by**, **inferred**) and a timestamp.
Beliefs decay; a room checked twenty minutes ago is not a room known now.

Perception owns sightlines, sound propagation, memory of places and people,
uncertainty, and the distinction between *there is no threat* and *I have not
looked*. It does not own map truth the survivor has not acquired, and it never
grants permission.

Native world sounds supply an audible origin without a reliable acoustic kind.
Perception retains them as unknown sounds. Own-source sounds are excluded by the
scanner; hearing alone supplies neither an enemy identity nor a shooter. Each
owned body's observation callback samples the short-lived native sound list;
the wider sight, ground and object scan keeps its county-time cadence. A
recognized voice resolves that sound without erasing independent threat evidence
at the same tile. Earlier unclassified heard entries migrate out of the threat
bucket on bind or acquisition; observed, reported and explicit phantom beliefs
retain their existing meaning.

Consecutive visible sightings of the same body update one observer-local track.
A visibility gap, observer replacement or new world breaks that continuity.
Tracks provide no identity after disappearance. Reported and restored beliefs
carry no tracking authority. Multiple bodies remain distinct even on the same tile.
Current sight can retire an obsolete location only when the native scanner
certifies the whole loaded tile on its recorded floor as visible. Hidden,
unloaded and unknown-floor memories retain uncertainty and ordinary expiry;
explicit phantom beliefs retain their separate owner.

Place familiarity belongs to the durable person. Every actual co-resident learns
the existing lived-home record at admission. Native building entry updates visits
once per entry; positive exterior evidence admits a later reentry, while unknown
interior binding preserves continuity. Save/load and dormant/loaded changes keep
that receipt. Residence and entry provide place knowledge; exact stock still
requires its separate private source evidence. Building visits and recency retain
their existing semantics alongside the distinct aging of person and threat facts.

This pillar is the one whose absence produces the characteristic failure of
existing NPC mods: a decision function that reads the world directly, computes
against geometry the agent could not know, and so is simultaneously omniscient
about walls and oblivious about people.

### Disposition â€” what is wanted

Nerve, discipline, aggression, initiative, trust, self-preservation. Disposition
converts a belief set into a preference ordering under risk. It does not
manufacture facts and it does not grant permission.

Disposition is where skill lives, and it is bounded: it changes latency, breadth,
precision and coordination. It does not license behavior outside the human
envelope. A low-nerve survivor hesitates, withdraws early, and shoots badly. A
low-nerve survivor does not walk into a doorway it believes is covered.

### Standing â€” what is allowed

Relationships, group membership, orders, territory claims, hostility state, and
who may direct whom. Standing channels a preference into a permitted action. It
owns whether this survivor may enter that building, take that item, or fire on
that person. It does not own execution and it never invents knowledge. Its
command surface is `SAO_Command` (`[C16]`, DR-033): whose word a person takes,
in what matter, and why not - CAO's check on the standing that exists.

An admission's origin and home coordinates identify a starting place and a
navigation reference. They confer no ownership. A move-in agreement can share
ground the anchor actually holds; an unclaimed destination remains unclaimed.
Deliberate claim actions and existing recorded claims retain their Standing owner.

### Execution â€” what is done

Movement, entry, combat, looting, work, treatment, withdrawal. Execution rides the
engine: normal pathfinding, normal timed actions, normal combat resolution. It
owns *how*, never *whether*. It does not consult global truth, personality, or
relationships â€” those were already resolved upstream.

Movement converts the admitted world direction into the installed engine's
rendered animation basis before writing AI strafe intent. The native human-input
method and NPC consumer ground that conversion; body-level direction and the
control axes remain separate managed surfaces. Route destinations, native
crossings and arrival retain their existing owners.

Repeated threat decisions preserve an executing escape route while its current
destination remains away from the privately believed threat, permitted and on
the body's floor. Changed danger, permission or a terminal movement result
returns the route to decision. Camera visits do not own or restart movement.

Following retains its beside-companion offset for the same executing job,
companion and body. Actual companion movement updates the goal. Changed owner,
floor, permission or terminal result returns the route to decision. Player
following preserves a failed movement receipt for its existing obstacle-crossing
owner; every new crossing still requires current permission. An already-started
crossing retains its exact body and job owner through completion.

Distant nonoverwhelming danger remains believed while ordinary home, water and
work routes continue. Close or overwhelming danger retains the person's existing
flight and engagement policy. An already-owned safe retreat continues beyond its
trigger distance. Leaving an old alert state preserves source reconciliation and
does not claim the remaining danger became clear. Native locked/barricaded
barriers and blocked diagonals have separate verdicts and handling.

Nighttime rest requires actual occupancy of a privately known permitted home or
the existing admitted claim. Home resolution uses the same household address for
return and rest. An unadmitted rest does not consume the decision, and awake or
cold intervals do not earn sleep recovery.

## Worked example: entry

The behavior that motivated this project. A hostile survivor breaks an intact
window to enter a house whose door stands open, climbs through, and stops.

Under a single geometric cost function that outcome is not a bug â€” it is the
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
window-breaking outright is oblivion and is refused by Disposition â€” a survivor
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
- `AIComponent.getHumanControlVars()` â†’ `AIBrainPlayerControlVars`: **an input
  channel, not a goal channel** â€” `strafeX/strafeY` axes plus intent booleans
  (`aiming`, `melee`, `initiateAttack`, `running`, â€¦). The engine accepts no
  destination through this seam; Execution owns the route and converts it to
  per-tick axis values (F-003). Route *production* is separable and engine-owned:
  `PathFindBehavior2` is independently drivable (`pathToLocationF`, `update()` â†’
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

### Shared physical mechanics and private completion (C111)

`SAO_Animals` drives the installed hand-feeding action on an owned living body.
`SAOAnimalCare` holds a bounded runtime capture of the exact actor, animal,
carried item and current native baseline. Native completion owns consumption and
XP. A canonical `rec.animalCare` outbox retains completed consumed-feed results
until Cognition acknowledges them. Separate model cursors make retry inert;
animal internal hunger and the native token stay with the producer. Each model
receives only the actor's performed feeding and consumed item quantity. Feeding
experience does not itself prove later animal health or complete another goal.

`SAO_ModMechanics` supplies installed carried-cooler processing with exact
off-slot living inventories. The source module owns ice, food age and item
timestamps. Body advances it before every fresh capture, including its
authenticated native-unload checkpoint; `BodySnapshot.capture` stays a reader.
Native item metadata persists with the existing inventory codec. An unresolved
native-pass error remains as plain `rec.inventoryMechanics.coolerFailure`
state across retry, retirement, runtime reset and record reload. Current native
world membership precedes ordinary processing. Multiplayer carried inventory
needs an explicit owning protocol before this adapter can drive it. Native
dormant food selection currently precedes cooler reconciliation and remains open.

DR-053 applies these ownership rules to the whole installed candidate collection.
Source adaptation and compatible shared APIs preserve one physical mechanism
per effect; source registration alone supplies no private knowledge or practice.

### Shared furniture relocation (C117)

`SAO_FurnitureMovement` guards the optional installed single-player push/pull
path. The installed module owns animation, native pickup and placement,
container transfer and feedback. SAO owns a bounded delayed-push queue because
the installed private queue resolves later work by coordinates and sprite
without an exact cancellation identity. The original shove runs with its own
queue disabled; each retained move pins its actor, object, member footprint,
destination and item instances until the physical boundary.

Both installed relocation functions enter one outer measurement, including
multi-part delegation. A completed diagnostic requires measured relocation and
exact retained contents. Effort completion alone supplies no movement result.
The bounded detached outcomes contain scalar diagnostics; they do not advance
person knowledge, practice or a maintained NPC purpose. The production caller
is the installed player's existing push/pull action. NPC furniture selection,
admission and private completion remain separate implementation work.

Native carrying wrappers and object events retain plumbing and electricity
ownership. Registered tub-system members refuse before movement. WaterPipes
registration reconciliation uses its owning commands after verified physical
relocation; fixtures outside the safely established state refuse before effects.
Multiplayer retains the installed path. Controlled installed-source execution
establishes the actor/object binding, relocation measurement and utility guards.

### Native window repair and private completion (C112)

The Controller's existing fortification decision asks `SAO_WindowRepair` for
an actor-bound adjoining-window offer. This body must currently see and face
the broken window, stand on a native interaction tile within reach, belong to
the current cell and have Standing permission. Observation is independent of
carried-pane readiness. The sealed offer provides a detached private destination;
the maintained purpose compiles exact personally acquired material sources,
SourceUse acquisition, return and native preparation before repair admission.
The scan admits no hidden building layout. Admission records accepted work
identity and advances no completed construction step.

The optional installed AddWindowAction remains the physical completion owner.
Its bespoke wrapper freezes the exact pane on the first native validity query
and checks actor, record, world, cell, queue, window, inventory and material
again immediately before completion. A completed canonical result requires
both native pane consumption and measured restored glass. An exact nested pane
first moves into the root inventory through installed native transfer; repair
starts only after its measured transfer state. Valid player queues use the same
physical action and material guard.

Each action owns a private token-checked binding capsule holding the exact
native handles. NPC runtime retains that capsule and original queue until
native acknowledgement; player completion retains it through its first exact
queue completion acknowledgement. Terminal disposal leaves a scalar tombstone,
so duplicate stop/perform cannot alter successor work or recapture another pane.
Native character/window fields remain intact. Installed Kahlua GC was measured;
no module action-key map depends on weak metatable semantics. The exact
`new(character, window)` formal names preserve installed native network argument
projection, which excludes the private capsule.

Native stop cleanup for players and NPCs requires the captured body and
window, the current body-to-queue lookup naming the original queue, and
this action still owning its current first entry. The NPC clears its old
farming flag before queue completion starts a legitimate successor. An
obsolete callback removes only its old exact entry and acknowledges that
owner, without resetting a replacement or advanced queue, dispatching
orphaned work or clearing successor flags. Perform requires the same original current-queue custody. Force-cancel
refuses changed captured body/window receivers and preserves native queue
iteration while scheduling exact old-owner cancellation.

`offers` retains only the latest decision-local slot per person, capped at 128
across the module. Replacement, begin consumption/refusal and forget/death retire
that slot; tick, world reset and module reload dispose abandoned slots.
Plain `rec.windowRepair` retains bounded
ordered results and `rec.windowRepairWork` retains the current purpose-bound
work. `ProceduralPlanning.consumeWindowRepairOutcome` requeries this owner and
advances only its exact completed result. `Cognition.windowRepairOutcome`
independently authenticates the completed receipt and projects performed
replacement into ordinary and associative model state, with separate replay
cursors. The private projection carries no native handles, internal completion
token, hidden source facts or new XP/recipe permission.

`SAO_Build` owns native boarding under the same material-work procedure. Its
private capsule binds the observed entry, actor, queue, purpose and exact tools
and materials. Installed transfer and equipment actions prepare nested items,
then installed `ISBarricadeAction` performs the physical work. Canonical
completion measures one consumed plank, two loose nails and changed barricade
state. The former eager Java call is inert. Cancellation retains old work until
native acknowledgement and preserves successor custody.

`SAO_ResourceProduction` owns the `Base.SawLogs` extension under that retained
boarding purpose. Exact `Base.Log` and usable native `ItemTag.SAW` categories
join the person's private SourceUse means. If finished planks are unavailable,
the planner can acquire a remembered log and saw, then bind their exact carried
identities to the installed recipe's manual input slots. Installed handcraft
logic, `ISHandcraftAction` and native inventory transfer own consumption, tool
wear, duration and outputs. Completion requires measured log consumption, the
retained saw and three distinct actual `Base.Plank` items held by that person.
The same purpose then returns to its original observed boarding entry.

The craft capsule uses ResourceProduction's existing scalar work and bounded
outcome ledger. Private native handles, current queue custody and cleanup
acknowledgement remain with the action owner. Ordinary bodies may have nil
external-owner tokens; exact body custody still governs execution. Saved work
cleanup remains available after runtime loss or a pending ownership transfer,
independently of permission to drive the actor. Canonical `resource:crafted`
results advance the exact craft step once; Cognition and both private models
receive authenticated performed-material experience. Queue admission and
interrupted work provide no manufactured stock or completed-craft credit.
This native craft adapter admits the installed single-player path; server-owned
craft effects require their own bound execution path under the continuing D3
scope.

`SAO_ResourceProduction` also owns `repair-held-item` for installed `Base.FixSaw`. Finite usable `ItemTag.FILE` stock joins private SourceUse. Planner compares native maintenance with continued plank work through the person's interpreter, binds exact held saw/file identities and preserves the original destination. Installed handcraft uses every exact kept manual slot; ResourceProduction measures native target condition/repair count and signed file wear. Canonical `resource:repaired` completion requires a retained improved target. Native completion without gain records failure and qualified negative feedback; interrupted recovery invents no effects. Owner-authenticated tool-repair facts reach both private models once. The same native custody, transfer, acknowledgement and scalar recovery discipline applies.

Portable maintenance also admits `Base.SharpenBlade` and `Base.SharpenBladePoorlyWithFile` through the same owner. Finite native whetstone categories join private SourceUse alongside files. Ordinary idle interpretation can retain a self-owned `maintain-tool` purpose under its exact carried target identity. Native eligibility distinguishes condition from sharpness; a full-condition dull blade may be sharpenable. Kept recipe inputs, skill and knowledge gates, actual native effects and bounded inventory scans govern execution. Canonical measurements separate sharpness gain, condition/head damage and tool wear, retaining admission-time maxima. Both private models receive independently authenticated benefit and damage consequences; no-effect and interrupted attempts grant no improvement credit. Executable means take precedence over unavailable maintenance alternatives within the private comparison. Existing construction upkeep retains its purpose and destination.

These work owners persist plain bounded result ledgers and scalar work anchors.
Controller adoption and IDLE continuation flush saved authentic results before
reconciling lost runtime ownership. Exact pending work with settled native queues
can become an interrupted recovery result; it grants no effects or completion
and retains the purpose and destination. Existing private owners cancel through
normal acknowledgement. Invalid clocks, ledgers or correlations retain blocked
inspectable work. A temporarily unavailable boarding entry yields to other
visible work while keeping its maintained purpose and bounded retry.

Learning acknowledges only an accepted unchanged canonical row. Automatic
EveryOneMinute/OnGameStart replay bounds each pass to 256 record lookups and
32 result owners. Canonical registry replacement and world/reset/reload clear
the retained iterator. The 32-result ledger distinguishes planning and learning
acknowledgement; an undelivered completed result retired after planning
acknowledgement increments `learningOmitted`.

An independent OnTick owner retries at most 32 exact cancellations per pass.
Death reaches it through Identity.markDead and Controller.forget. Native stop
and original queue acknowledgement retire a started binding, even after the
agent was removed. World reset retains refused cancellation handles and late
callbacks retire them; a replacement owner waits. Both loaded and bodyless
pending ZAO/Crossed handoffs cancel before resume, and completion itself refuses
pending transfer. Other queued work remains untouched.

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

C87 connects loaded static-container inspection to that same private source
record. Java offers visible holder identities and native approach squares;
contents remain unknown until the actual actor reaches and inspects the exact
holder. The installed native loot owner fills an unopened container once.
WorldSources publishes the resulting physical source, and Perception admits
only that inspected source to that person's memory. PrivateInventory exposes
current static-container stock only through the body's own inspection or an
exact remembered fingerprint and revision. A shared native explored flag alone
does not authorize another actor's decision query. Pending inspection and
bounded failed approaches have native weak body ownership and scalar state.
Controller returns from inspection to need selection; SourceUse retains
acquisition and completion authority.

Direct fixture drinking retains its native IsoObject owner. The clean-water
predicate includes municipal and reserve supplies, and immediate reach follows
the installed corrected fixture square and native canReachTo rule. A currently
usable source precedes a source requiring an approach; an at-hand drink enters
the verified native queue directly. Terminal failures suppress only that
body's exact attempted fixture for a bounded county-time interval. Native
reach or expiry reopens consideration. Selection and terminal diagnostics name
the actual fixture, while Controller preserves the transfer owner's refusal
reason separately from a successful route arrival.

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
ZAO living-person transfer before restoring the durable source phase, and an unreadable
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

D1 preserves the boundary between physical and dormant time. Dormant walking
starts after the later valid `lastWalkHours` or `releasedAtHours` checkpoint;
time already enacted by a body cannot become offscreen travel on reload. The
live population tick attempts nearby body admission before advancing remaining
dormant records. Historical catch-up keeps its own scheduling order and rate.
Native admission may still refuse a location, and existing saved positions and
histories remain authoritative.

C57 gives `SAO_BodySnapshot` the shared native-envelope contract: version
interpretation, capture, validation and durable commit. `SAO_Body` owns
materialization, checkpoints, release and transfer transactions; the shared
module owns no body registry. Release and transfer validate supplied native
payloads and envelope fields before publishing durable state or ownership.
Afflicted return shares the version reader, retains source removal and hands the
validated living shell to the registered ZAO owner. The historical
`CrossedTransfer` name remains a compatibility alias for the generalized
`ZAOPersonTransfer` owner. Native formats and save keys keep their existing
readers.

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

## Personal world-knowledge evidence (C77)

Speakeasy owns protected claim text, source review and training standing. SAO
owns each person's acquisition and retention. The boundary carries stable claim
identifiers, exact source/excerpt hashes and person-bound receipts. Protected
prose stays outside the mod.

`SAORecord` maps county hours to local instants using the save-start-minus-history
anchor. Population admission retains county-presence intervals as biographical
evidence. Presence, age and time passage grant no world claim.

WorldKnowledge schema 2 records a dated report only after `ISReadABook.complete`
returns success for an exact held issue and native print-read state confirms the
result. The observer binds the same living person record, loaded body, item ID,
item type and native info/text issue identifiers before and after completion.
The acquisition carries `path=read`, `knowledgeKind=reported`, the actual
completion hour and a durable linked receipt. Publication time remains separate.
The current bounded claim is the July 2 Knox report. Reading it establishes
knowledge of that report; it establishes no personal telephone or Internet use,
provider-wide measurement, outage end time or July 11 service condition.

Queries return detached records and never migrate. Schema-1 county-presence
acquisitions are withheld by ordinary and strict readers. The next producer
preserves the entire old owner state under `legacy` and starts empty active
acquisitions. Subsequent evidenced reading can establish new knowledge. Native
print-read collections alone lack the exact dated issue, so they cannot repair
legacy knowledge retrospectively.

The completion observer uses the installed native action. NPC source selection
and reading initiation remain their existing owners' responsibility; this batch
adds no autonomous newspaper-seeking policy. The controlled capture explicitly
supplies a reading encounter and executes the installed action over controlled
engine objects. It is not a recorded play session or a training row.

### Computer sources and service experience

A future computer integration must identify the acting person, exact endpoint,
service/application, reachable source or attempted operation, and the completed
result at the acquisition time. Reading content preserves source/version and
reception time as reported knowledge. An observed connection failure describes
that person's attempt and endpoint; it does not establish county-wide service
failure or its cause. Device ownership and installed-mod detection establish no
acquisition. The adapter supplies evidence to the existing perception/acquisition
owners; it does not assign awareness from compatibility flags. No computer
adapter is implemented by C77.

Speakeasy Record 55 preserves the C74 import and reviews as historical evidence,
revokes their unsupported acquisition basis for current admission, and refuses
regeneration of the retired reference. C74/C76 artifacts remain immutable.
The next data work imports the corrected C77 capture and reviews its authored
question and typed interpretation before independent retrieval review.

## Typed claim catalogues (C75)

`Knowledge.claimCatalogue` compiles the existing read-only knowledge surface
for one person, listener and tick into a detached, schema-versioned catalogue.
Every fact receives a reference local to the caller-owned immutable snapshot.
Ordering follows canonical fact content rather than Lua table insertion order;
known-person beliefs enter the same catalogue, and a protected world claim
retains its stable source claim identifier inside its local entry.

`Knowledge.selectClaims` accepts only references from that exact snapshot and
refuses malformed, duplicate, foreign or unknown references for the whole
selection. `Knowledge.flatSelectedClaims` projects only the admitted facts
through C47's existing scalar field/value rule. A future retriever can therefore
narrow what a speaker may say without adding a fact or exposing another fact the
person also knows.

C75 does not route current speech through this interface. The future asynchronous
runtime must own and bind the immutable snapshot reference; Speakeasy must still
author retriever targets and task datasets; and SAO's protected-world source
remains one report claim with C77 reading evidence rather than a complete county catalogue.

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


## Authored conversation capture (C76)

C78 adds optional capture version 2 with detached behavioral evidence under its
own schema. Trait contributions come from Disposition's decision calculation.
Knowledge names each channel's owner and availability, separates source data
from fact entitlement and rejects failed readers, foreign owners and future
observations. Current Neuro projections require a current recorded observation;
the read never advances it. Conditions, relationship, private zombie threat and
lesson provenance retain their distinct meanings. Raw physiological causes are
audit data, not model input or another person's knowledge.

The bodyless host publishes five explicitly authored comparison cases. Loaded
needs, controller state/reason and active movement have an ownership-checked
read API and controlled boundary tests, but remain unavailable in those cases.
Full active-purpose/alternative coverage needs action-specific producers;
reading this surface never calls Integration.apply or Branching.select.
Version 1 remains readable. No model or speech path is switched by this work.

`Knowledge.catalogueEvidence` reports source failures alongside all requested
Knowledge topics. Standing and WorldSources expose non-mutating readiness checks
against supported initialized stores, and WorldKnowledge checks its owned
acquisition structure. Unsupported, missing or uninitialized owners refuse before
catalogue reading. Strict Perception reception reads reject malformed stored
history. Personal started facts use received broadcasts with teller/broadcast
identity and heard dates; county-wide chronicle stamps are not personal facts.

The offline `tools/conversation_evidence.py` host runs the production modules
with explicitly authored people, ground, sighting and calendar inputs. It is
bodyless and records unavailable native needs, bite and controller conditioning.
The capture binds living participant identities, clock and calendar, freezes the
complete host durable stores and private beliefs around reading, and rejects
mutation or table replacement. Its serialized observation becomes a canonical
SHA-256 snapshot identity; claim references change with the question or source
state. Source hashes and the measured installed calendar accompany atomic,
non-overwriting publication. All captured data remains unapproved and
training-ineligible.

The Knowledge-topic coverage receipt proves successful reading under this
specific host and supported schemas. It does not establish corpus-wide world
knowledge, native loaded-body capture or task-specific output validity. Speakeasy
owns the next exact import, source adjudication, typed proposal and readable
operator review. Live asynchronous inference and result revalidation remain R14.

## Enacted social coordination (C79)

`SAO_Organization` owns one durable process instead of a parallel planner. A
matter contains immutable proposal revisions, addressed participants, actual
receptions, per-person responses and history, scoped commitments, work state and
events. GraphPersistence schema 4 serializes the data tables and consumed-result
IDs; runtime communication and execution adapters re-register after load.

Communication acquisition, response formation, response delivery and work are
different transitions. A transport must explicitly admit the proposal before a
person can answer. `SAO_Coordination` owns the common appraisal path for loaded
Controller, dormant population and Perception callers. The recipient freezes
their current activity, capability,
need, relationship, interests and constraints with their feasible response set.
Accept, qualify, counter-propose, decline, defer, contest and withdraw are
individual choices; an addressed person without a response remains unanswered.
A commitment exists only after the chosen response reaches the originator.

Commitment scope is the authority boundary. Command and office consumers require
the matching process matter, revision and jurisdiction. Several responsibilities
may coexist, and revision supersedes unfinished prior terms. No trust score,
roster size, title or generic message can authorize a different matter.

Food-delivery commitments reuse native owners:

```text
Organization commitment
  -> SourceUse exact acquisition
  -> Locomotion carrying route
  -> Handover exact delivery
  -> Organization consumes each terminal receipt once
```

Competing activity pauses rather than completes or erases the commitment. The
same actor may resume after the current execution owner revalidates capability
and access. Loaded SAO bodies, dormant people and registered external owners use
the same process record. Afflicted and Crossed keep the human identity/shell;
ZAO supplies the state-specific external activity/capability snapshot and
performs supported movement/work. SAO's communication, SourceUse, Handover and
Locomotion remain services, not a second actor planner.

An unsuccessful movement attempt retains its exact outcome and pauses the
accepted responsibility. Bounded reappraisal compares the private source facts,
approach and target rather than rescan timestamps. Other accepted work may proceed
while one responsibility waits. Reconstructed bodies reestablish their native
source cache before acquisition; withdrawal, death and supersession still stop
execution. Arrival supplies no acquisition or delivery credit.

C80 applies the same boundary to return and ordinary state activity. A returned
Afflicted body is never enrolled in `SAO_Controller`; ZAO accepts the loaded
shell or dormant envelope under the stable driver token. Standing exposes only
that person's private unheld destination evidence. ZAO decides whether to
travel, invokes SAO's native Locomotion owner, and reports arrival before
Standing may commit home or claim. The former daily record relocation is gone.
Afflicted-to-Crossed conversion preserves the owner token and changes only the
state policy. ZAO reports the body's current competing pressure without
exporting a diagnosis or diet label. Crossed human maintenance uses ordinary
human caloric passage under Crossed policy. Known Afflicted donor provenance is
categorically unavailable to Crossed feeding; intentional exposure remains a
distinct pathogen action.
Afflicted water, protein preference, penalized non-dairy alternatives and
donor-conditioned human-meal consequences remain under the distinct Afflicted
policy. SAO does not infer either policy from the exported generic pressure.

Personal food acquisition still uses the same native owner as survivor work:
SourceUse selects the privately known exact source, drives locomotion, transfers
the exact item and publishes the measured receipt. A registered ZAO diet
adapter selects only the terminal-state eating action after the item is carried.
Queue admission, transfer and eating remain separate outcomes through
interruption and reload.

### External life coordination (C83 / ZAO A40)

The enacted process is now generic at the execution-owner boundary. An
addressed person must acquire the current revision before their registered
owner may appraise it; the formed answer remains private until Communication
actually returns it. The external owner may replace only the bounded appraisal
envelope with current source-owned activity, capability, pressure, relationship,
interest and constraint evidence. It cannot write process state or export a
condition, diagnosis or diet label through that generic seam. Missing body or
owner evidence produces defer rather than inferred incapacity.
When a broadcast or relayed request cannot know its recipients at authorship,
the admitted radio or conversation transport atomically adds only the exact
listener and records that reception. A caller holding only a process identifier
cannot address itself or manufacture acquisition.

Accepted provisioning admits food and stored portable water. SourceUse owns
the exact reservation/acquisition, Locomotion owns approach and carrying travel,
and Handover owns delivery. Accepted rendezvous/holding uses the proposal's
bounded destination and an exact native Locomotion route; Organization closes
it only when the matching attempt reports arrival with the promised activity.
Pending attempts persist. A controller rebuilt after save/reload or a
loaded/dormant handoff reissues the same route ID, so reconstruction cannot
manufacture a second attempt or terminal receipt.

ZAO policies use this one store differently. Afflicted can originate food or
water provisioning from actual personal or settlement necessity. Crossed can
originate bounded rendezvous/holding with evidenced associates and ground.
Conversion keeps the process and revision while current-state dispatch selects
the new policy's appraisal. The generic process therefore preserves continuity
without flattening the two states' motives, physiology or action vocabularies.

`Organization.decisionEvidence` reconstructs a named proposal revision at the
response-formation hour. Its decision view contains no delivered-response fact
or commitment. The later view removes private inputs/proposal/reception and
contains only that actor's revision-bound commitments and current observation
hour. Speakeasy Record 63 binds those horizons to the exact v3 event namespace
and keeps same-moment pathogen truth outside the decision input.

`tools/sweep/decision_capture.lua` wraps the actual appraisal owner. It freezes
the person, proposal, private appraisal, executable response set and chosen
response before the caller can deliver it. It refreshes only the separate later
outcome, including one final read before bounded process retention may evict a
terminal record. `tools/county_dump.py` validates and atomically publishes those
rows as `*.coordination.jsonl`; `--joint` runs the dormant SAO+ZAO configuration.
The observer does not extend process retention or create a response or result.

### Causal episode runtime (C84 / ZAO A41 / Speakeasy Record 68)

`tools/county_episode.py` wraps the production county as one bounded causal
episode. It advances once to the declared maximum day and selects every
checkpoint from that trajectory. It then creates a fresh Kahlua process with
the same save identity and compares the complete canonical simulation result.
Only an exact match may be sealed and exclusively published as
`sao-causal-episode` version 1. The row contains daily snapshots, social events,
terminal state, source provenance and the complete coordination capture; it is
a candidate observation even when that capture contains no decision.

The joint loader installs ZAO's common execution owner before the county runs.
That adapter locates the retained human shell when present, obtains current work
and capability from the common driver and dispatches recipient appraisal to the
current Afflicted or Crossed provider. It is usable without the loaded client
controller, so dormant coordination does not fall back into SAO ownership.
The common envelope copies neither terminal-state nor diet truth. A missing
shell or unavailable pressure stays unavailable and can defer the answer.

The tracked 30-day episode has checkpoints 0, 7 and 30 and exact replay SHA-256
`4c96d2d0d6ceb7c2cce9fdd29d51394b0759b391fc44b072c060e5bed16dd09b`.
It observed deaths and ZAO state changes but no organization, matter or
coordination decision. Speakeasy retains the complete episode and therefore
emits no task. The separate twenty-scene audit exercises the response policies;
its authored initial situations do not populate or relabel the natural run.
Neither artifact establishes loaded gameplay, producer prevalence, training
admission or accelerator equivalence.

### Private situation contact and enacted work (C85 / ZAO A42)

Perception retains each person's known communication contacts and their last
usable address. A private provisioning pressure becomes one revisioned
Organization matter addressed to particular contacts. Coordination owns neither
telepathy nor a delivery shortcut: the originator opens a contact attempt,
Locomotion may reach its address, Communication must still complete an actual
exchange before reception exists, and every recipient forms and returns their
own answer from current private state. Waiting, unanswered, expired and retried
attempts remain explicit.

Accepted material work keeps its existing native owners. SourceUse reserves and
transfers the exact observed item; only a successful native transfer establishes
carrying. Locomotion owns the carrying route and exact arrival; Handover owns the
recipient transfer. Queue admission, source reservation, acquisition, arrival
and delivery are different states. Organization consumes the exact terminal
receipt once. A coordinated SourceUse release or conflict is therefore visible
to the work reconciler even though it projects no material gain; ordinary
abandoned source attempts remain private to their actor. GraphPersistence keeps
attempts, receptions, responses, commitments, work and consumed results across
loaded/dormant handoff and reload.

Registered external people enter the same contact and work process through their
execution owner. ZAO A42 supplies shared-driver contact continuation while its
Afflicted and Crossed policies remain distinct. SAO neither infers either
state's maintenance nor treats a generic message as hearing, assent or success.
Border 197 executes the complete SourceUse-to-Handover chain and failure/partial
branches in installed Kahlua, including exact acquisition, delivery and durable
result consumption.

### Cooperative procedure and private projections (C90)

An accepted responsibility may carry a bounded dependency graph without making
that graph a person's omniscient plan. `SAO_Organization` owns the enacted
procedure: ordered steps, dependency availability and exact completion receipts.
The proposal carries the procedure terms. Authorship or actual Communication
reception creates a separate projection for that person. Addressing, proximity,
another participant's receipt and operator observation do not copy progress into
that projection.

The controller requests `workPlan` as the commitment actor and receives that
actor's projection. Private reasoning, perception and model disagreement may
change a person's expected or intended next step without rewriting enacted
material truth or another person's plan. SourceUse acquisition updates the
actor who performed it. A carrying-route arrival updates its mover. SourceUse
storage updates its actor, while a completed Handover updates its direct actor
and recipient. The enacted procedure and all distinct projections persist inside
the existing GraphPersistence process store; old processes acquire empty owners
without inferred plans or progress.

Current provisioning and food-delivery producers describe acquisition, optional
carrying travel and delivery. Delivery depends on proved acquisition; direct
Handover remains valid when the people were already within reach. The schema is
generic enough for later preparation, construction, repair or multi-person work,
but those verbs still require their own native completion tokens and producers.
`SAO_Observation` exposes enacted status and the selected person's belief as two
separate operator rows, allowing Mousecat to compare them without changing either.
Border 207 exercises dependency refusal, acquisition, actor-private progress,
route progress, bilateral delivery, disagreement and save/rebind with five
defect controls. These establish the production procedure mechanics; broader
procedure frequency and quality remain behavioral assessment work.

### Cooperative role allocation and strategic action (C91)

C91 makes the C90 graph usable by several people without treating cooperation
as a shared inventory or a single aggregate body. A cooperative step declares
its domain, role, capability, bounded participant capacity, optional target and
posture. A recipient can accept one compatible role without possessing every
capability in the procedure. Delivered acceptance creates an actor-specific
claim; capacity prevents another person from taking the same exclusive role.
Qualification, counter-proposal, refusal and withdrawal remain ordinary
Organization responses.

Movement, material work and posture use the same procedure vocabulary but keep
their native owners. Locomotion can complete an actor's claimed movement step
from the exact arrived route. Cooking carries the accepted process and step
identity through its native appliance lifecycle and publishes
`cooking:prepared` only after heat, retrieval and shutdown succeed. Other action
owners enter through `consumeProcedureResult` only after exact admission and a
matching actor, commitment, step and receipt. The procedure never performs the
world effect.

Steps can require several distinct actor contributions. A first contribution
is retained without satisfying the threshold; dependent work opens only after
the enacted threshold completes and the participant separately acquires that
fact. This supports assemble, cover, hold, escort, withdraw, regroup and similar
strategic structures as parallel movement or action steps followed by explicit
synchronization barriers. It does not collapse member locations, perception or
dissent into group truth.

Failure marks the exact claim, preserves the unfinished enacted step and records
a revision need. It neither assigns a replacement nor edits another person's
projection. `Coordination.reviseCooperation` authors a new proposal revision;
participants must acquire and answer it again. Mousecat's existing person
inspection now shows objective, role/domain, claimants, contribution threshold,
the selected person's claim and revision reason. Border 208 executes twelve
formation, role, movement, knowledge, synchronization and revision cases with
four defect controls. The A-Life, Living Fellows and CAO source catalogue is in
`artifacts/audits/c91-autonomous-cooperation/PRIOR_ART_CATALOGUE.md`.

C91 establishes the executable role contract and Locomotion/Cooking call sites.
Posture owners for further strategic verbs and broader autonomous tactical
doctrine remain implementation work. Training admission follows Speakeasy's
existing source-review contract.

### Person-private procedural planning (C95)

`SAO_ProceduralPlanning` owns maintained personal purposes between immediate
decision and native execution. A purpose records its objective, origin,
revision, ordered prerequisites, current blocker, interruption history, next
native owner and the exact result token that can advance it. Recompilation
preserves completed prerequisites. Admission to a queue records only that an
owner accepted work; it never counts as reading, construction, practice or
social participation.

The active store represents current planning focus. Validated private conflict
appraisal can suspend an unadmitted purpose when an executable urgent response
needs that focus. The durable queue preserves its identity, revision, accepted
resource request, deadline, progress, steps and native result history. Ordinary
Controller comparison resumes an eligible queued obligation only after current
body, private threat and physical-owner checks permit an ordinary turn. Planning
restores the original position; the existing resource chooser compares it.
An owned native admission requires its executor's handback before suspension.

A completed solo leisure purpose with only optional sharing remaining can move
to a separate bounded suspended ledger under new pressure. It retains the
completed physical result and unresolved participation. Older optional records
have an explicit omission count. The required-obligation queue preserves its
retained rows and reports its capacity boundary directly. Resumption preserves
unfinished work rather than supplying a completion result.

The planner holds person-private spatial facts with provenance, confidence,
familiarity and decay. Familiar home ground lasts longer than a briefly seen
route. A native claim survey records the holder's aggregate understanding of
their own ground. A boardable-entry inspection records its exact aperture.
Tactical withdrawal prefers remembered cover, broken threat sightlines and a
known route when that person's evidence supports one; the earlier direct-away
vector remains the emergency result when no usable private fact exists.

Technique profiles read the engine's numeric perk levels, with occupation used
only through Census's existing engine-profession read path. Occupation does not
grant an action. Study compiles locating or acquiring the relevant book,
native literature use and later tested practice. Literacy, reading-time traits
and current fatigue inform the session. C102's `SAO_Study` executes the installed
`ISReadABook` action for a useful privately carried manual, including for a person
without a designation. The native skill range, literacy, lighting, duration,
page progress and XP multiplier remain authoritative. The legacy instant
`ReadLiterature` call is retired from the Controller study path.

The maintained purpose retains the exact book type, work identity and admission.
Current body and item ownership are revalidated before native completion.
Immediate needs and danger interrupt study; a different timed action retires the
reading owner before queue admission. Body handoff closes live study before its
native checkpoint. Interrupted pages persist through the existing native reading
snapshot, while missing runtime is reported as interrupted without completion
credit. A completed reading receipt advances the reading step once and keeps
practical work separate. C103 connects unknown stock to native container
inspection and inspected suitable manuals to explicit SourceUse acquisition.
The same purpose continues once the exact native item is held. Physical source
revisions cannot supply unseen stock to a private mind. Carried manuals retain
owned access when lighting or cooldown delays study.

C103 binds Cooking's actual work identity to pending Cooking practice or a
retained food-preparation purpose. Heat progression, native credit, retrieval
and safe shutdown precede a productive result. Interruptions retain the purpose;
canonical outcomes retry private delivery and advance exactly once. SourceUse's
purpose-bound terminal receipts pass through Provisioning. Superseded attempts
retire without crediting replacement steps or blocking ledger compaction.
C104 extends this store into private food and water purposes. Labor supplies a
detached assessment of native owned supplies, inspected source revisions,
personal capacity, current commitments and the eight canonical labor questions.
The ordinary model's chosen feasible alternative determines inspection,
acquisition, conditional exact-item preparation and refill of an owned vessel
at a privately observed native fixture. The opposing model retains
its own interpretation. SourceUse validates the selected source, item, type and
revision before admission; Cooking retains exact acquired-item continuity.
ResourceProduction binds the native water fixture and carried vessel, executes
ISTakeWaterAction and measures native fluid gain. Canonical clean, held final
water and exact attempt identity precede completed production. Both cognition
models receive that canonical experience once. The physically handled fixture
refreshes only the actor's exact private source memory after native gain;
bounded observation failures remain unconfirmed. SourceUse and Cooking respect
the active production owner. Failed routes retain bounded private retry delays.
D3.4 extends the same water purpose through native plumbing. Personally observed
fluid-source facts carry a scalar `plumbing` state: `unconnected`, `connected`
or an empty legacy value. An indoor pipeable fixture can be remembered without
water stock or knowledge of its roof supplier. Finite `pipe-wrench` stock uses
exact item identity through acquisition, native transfer and equipment. Planner
retains the fixture while acquiring that tool; ResourceProduction reacquires the
exact native object and validates installed supplier/mains eligibility before
ISPlumbItem. Its canonical `resource:plumbed` result measures the actual connection
transition and refreshes only the handled private source. Both cognitive models
record performed connection independently. The same hydration purpose remains
active for actual clean held-water gain through ISTakeWaterAction and for native
drinking; a connected fixture alone supplies no acquired water or bodily relief.
D3.5 supplies the rain-collector construction prerequisite within that same
hydration purpose. Perception retains detached exterior placement sites observed
on the person's floor; the native binding preserves their current world,
geometry and revision. Planner retains the original fixture, vessel and selected
site through each exact recipe-input acquisition and return. ResourceProduction
uses the four registered collector entity recipes, exact manual BuildLogic inputs
and actor-bound native build/payment/placement. Its authenticated
`resource:collector-built` result records actual construction and the created
collector separately from the original fixture and kept hammer. Both models
learn performed construction. Native precipitation, actual supplier equality,
plumbing, clean held-water gain and drinking retain distinct evidence. Empty
supply keeps hydration unfinished while ordinary competing needs proceed.
Partial transfer
can later satisfy stock demand without completed-work credit. A missing known
route preserves unknown environmental affordances rather than asserting an
absence of world resources.
Fresh blocked goals can request help through the existing social process owner,
while reception, independent response and native outcomes remain authoritative.
Ready accepted work retires the exact native reading action before replacement;
dependency waits or unavailable means preserve reading. Other practical skill
owners and longer production mechanisms remain implementation work.

Organization's bounded contact attempts retain exact loaded native failures
for the originator's own private approach. Controller attempts actual exchange
before applying delayed retries. Three equivalent failures await changed
privately observed address or meaningful actual approach evidence; missing
legacy context remains unknown. Urgent bodily needs precede pending contact
and its wait state. Exact locomotion ownership and acknowledged cancellation
precede retirement; a read-only native idle proof covers a completed trip.
ResourceProduction retains admission-time physiology and exact vessel identity.
Already appraised pressure without executable competing relief preserves its
selected action. Partial gain in the bound vessel remains owned progress;
distinct usable relief and new physiological danger can interrupt it.

Fortification compiles personally observed work, exact missing-material
acquisition and native construction over permitted held ground. `SAO_Build`
owns preparation, native action custody and measured completion; `SAOBuild`
provides current native visibility and readiness. Authentic canonical completion
closes the exact construction purpose. Instrument recreation records its physical
activity site and exact carried affordance. `SAO_Gesture` owns the supported
native instrument sound, its queue action and terminal result. Planning binds
the person, exact item and work occurrence before native queue admission can
start the action. A completed result requires observed sound emission, the
native world-sound stimulus, observed sound end and settled cleanup. Admission,
start, sound end and native completion retain their individual dates.

Controller compares materially eligible carried reading and a supported carried
instrument through the shared personal interpretation interface. Only the
selected alternative creates a physical purpose and attempts native admission.
Acquired sound experience can change that selection; rejected admission permits
another eligible choice during the existing retry interval. A plain private
decision record retains exact item identities, alternatives, model selections
and admission status. The existing person inspection projects this decision and
bounded deferred-purpose rows separately from completed use.

`SAO_Cognition` requeries this result owner before acquiring private
instrument-use experience. Independent cognitive models can predict the known
native sound effect from that evidence. Physical emission establishes neither
pleasure nor competence. Hearing, accepted joint participation, another body's
activity and its social consequences require their own acquired evidence; these
joins remain open. Optional sharing retains its unfinished standing after solo
performance and cannot establish a completed shared activity.

The ordinary and associative models receive detached copies of the same bounded
candidate set and their own model state. The ordinary model emphasizes evidence,
continuity and pressure. The associative model emphasizes adjacency, novelty and
information value. Mousecat exposes both selections and disagreement through
the existing read-only person feed. Neither interpretation creates a verb,
material, spatial fact, technique or outcome. Border 211 exercises private
memory, decay, numeric skills, model disagreement, study, fortification,
tactical ground, spatial leisure, persistence and exact receipt ownership.

### Natural cooperative formation and native posture (C92)

C92 connects the C91 procedure contract to ordinary private pressures. A
person who needs food may author a collect-prepare-deliver procedure for known
contacts. Acquisition, preparation, carrying and delivery retain one physical
item actor through `sameActorAs`; the graph cannot divide a held item among
abstract roles. The author may claim their own compatible step directly, while
each recipient still acquires and answers the proposal independently.

A privately perceived distant threat may form a bounded tactical procedure.
The author watches the perceived location while one or two known contacts move
toward a fallback vector derived from that actor's position and threat evidence;
covering posture can follow those arrivals. The population family spans two to
seven people. It is a producer over actual private evidence, not a scripted
scene or a shared tactical mind. A changed private intent can produce a new
revision; silence, refusal and disagreement remain possible outcomes.

`SAO_Posture` owns watch and cover execution. It admits an exact procedure
claim through the bridge, uses the native body and head orientation layer, and
completes only after the represented body maintains the requested facing for a
bounded interval. Movement, combat, timed actions, crossings, death, body
replacement, world reset and timeout interrupt the owner instead of minting completion.
The Controller starts this owner before material or movement work and consumes
only its matching native result.

Mousecat's existing observation feed now includes compact step targets and
postures plus a bounded recent procedure-event timeline. Border 209 executes
food continuity, private threat formation, independent disagreement, exact
posture/movement closure and the two-to-seven population family with three
causal mutations. Border 202 additionally exercises native posture admission,
identity, maintained-facing completion, movement refusal and exact release in
all three native loading orders. These establish the mechanisms, not their
loaded-world frequency, tactical quality or dataset admission.

### Durable study sessions (C93)

One study session owns a sequence of finite native attempts over the same
isolated save. `world_lab_run.py` continues to own preparation, native process
supervision, normal save return, attempt verification and `--resume` continuity.
`world_lab_session.py` owns only bounded attempt settings and transitions between
verified attempts. It never edits the save or promotes an observation.

The durable public state contains its session identity, attempt number, wall-time
budget, simulated clock, accumulated simulated hours, last stop reason and
whether the current state can checkpoint or continue. Lifecycle commands are
exact immutable files. Save requests use the existing native stop route;
configuration and continuation go to the supervisor through Speakeasy's
allowlisted bridge. The default verifier refuses incomplete predecessors.
A normally exited observer attempt with a returned native save may continue
under a separate, predecessor-bound reviewed-error manifest. The qualifier
checks the exact session, attempt, engine, log rows and retained incident
evidence. It preserves the original incomplete verdict and grants no clean-run
or behavioral acceptance. Forced termination, failed supervision and missing
native save return refuse continuation.

Saved-boundary gameplay delivery uses named profiles with exact file inventories,
predecessor and successor hashes, retained bytes and rollback through launch
failure. The shared-reasoning profile carries its thirteen Lua owners and the
rebuilt SAO Java archive; the existing two-file profiles remain readable.
Observer refresh is a separate verified transaction. Save bytes, engine,
other mods and source identities remain under the predecessor's authority.

Mousecat receives path-free session state with the native view. It exposes the
one action valid now and places duration and automatic continuation inside an
expandable settings section. The prior ended feed remains bound until a resumed
attempt publishes a complete successor frame. All session state and observations
remain unreviewed with no behavioral verdict or dataset-write surface.

### Study situation pressure (C94)

A study definition may carry one exact `situation` with bounded initial hunger,
thirst and fatigue ranges. `StudyWorld` deterministically samples each range by
person identity and writes the matching native `CharacterStat` only once after
that person's body exists. The applied value and county time persist in the
study save, so reload or another tick cannot reset physiology after ordinary
native action changes it.

The situation is copied into observation provenance and package identity. It
does not select a response, manufacture knowledge, score behavior or admit a
dataset row. Existing Needs, Cognition, Controller, Organization, SourceUse,
Cooking and other native owners remain responsible for turning bodily pressure
into decisions and world effects.

### Resource outcome trials and asynchronous observation (C105)

`situation.resourceObjectives` admits bounded desired-stock requests into the
existing person-private planner. A request identifies its source definition,
revision, experimental issuer, declared regional site and one actual actor.
`OperatorDirect` records the external trial authority. The actor's knowledge,
skills, social access and independent model interpretations determine the means.
No procedure or knowledge is supplied. Autonomous purposes retain their existing
origin. Live known-procedure admission remains an implementation gap.

The target persists through low pressure and completed work steps. Current native
private carried stock determines satisfaction: distinct usable food identities
or measured clean water-source fluid amount. Active native admissions, urgent
needs and accepted cooperation preserve their priority and execution ownership.
Bounded stock prefixes remain lower bounds. Deadline, death, revision and exact
request identity survive body replacement and save. Retired terminal purposes
retain durable provenance without pinning the active-purpose ledger; their exact
terminal request metadata remains observable and cannot replay new work.
Study binding uses native world-age hours; admission, deadline, resolution and
stock checks use explicitly named county-hour fields. The clocks retain their
own domains. NPC handover retains the recipient's native facing container while
clearing its player-panel selection field. Ordinary player transfers retain
vanilla UI and all transfers retain exact native ownership reconciliation.

`StudyExport` measures the existing JSON grammar and detaches immutable values
on the native game thread. Reserving one live and one archive channel precedes
snapshot acquisition. One bounded worker encodes and publishes those values,
with no native world or live-table reads. Verified atomic publication precedes
the Lua owner's acknowledgement. Captured source clocks and sequence remain
distinct from completion time; live completion starts its one-second cooldown.
Byte, node and depth exhaustion have explicit deferred reasons. Unsupported,
cyclic, nonfinite and foreign input, and I/O failure, retain failure authority.
An epoch lock prevents retired world completions from replacing current output.
Stop pauses native time and closes admission while exact receipts drain. Failed
drain publication retries within the existing bounded observer-state protocol.

### Regional study conditions, hydration and timing (C106)

`StudyWorld.start` stages source-bound initial regional counts before native
population admission. `SAO_PopulationAdmissions` consumes the authored conditions
through its existing identity, history, lived-presence and unit owners. Persistent
generated identities record actual coverage; configured counts are a premise.
Save replay retains that initial binding. The adapter follows CAO's founding
order and count authority within Project Zomboid's existing population owner.
`PopulationRepresentation` retains each actual materialization result's source
and returned failure cause for study people. Absent causes remain unknown.
`initialPeopleSnapshot` counts current native bodies independently of those
historical placement receipts.

`SAONeeds` owns actual safe native hydration. `SAOWorldSources` records amount and
taint under the observed item revision. `SAO_WorldSources` persists and projects
only privately inspected evidence, with old incomplete observations requiring
inspection. `Controller`, `Labor` and `ProceduralPlanning` distinguish physiological
hydration from material clean-water stock. `SourceUse` retains exact admission;
`Cognition` joins drink acquisition to thirst only when the native reservation,
actor, source, item, revision and outcome agree. Transfer and later measured
drinking remain separate events under their existing native owners.
Native carried medicine selection reads `InventoryItem.getReduceInfectionPower`
under `SAONeeds`, returning only finite positive native Food through the bridge.
The existing eat action owns consumption. Script `Item` has no such getter;
medicine selection does not imply knowledge of clinical benefit or cold relief.

`StudyExport` attaches a bounded six-stage timing bank to each epoch. Immutable
worker jobs retain that original bank. Owner-thread diagnostic snapshots carry
source identities, their sample clock and coherent rows for calls, inclusive
monotonic duration, examined quantities, failures, deferral and clipping.
`StudyObserver` uses the engine's native slow Lua callback timer and restores its
previous option after successful drain before owned quit. Callback warnings and
export stages describe inclusive owners; they do not expose survivor knowledge,
grant capabilities, label training data or claim exclusive cost attribution.

### Reference-learning source (C81)

`tools/coordination_scene_dump.py` declares twenty synthetic starting
situations and fixes each independent lineage to train, validation or test
before execution. The catalogue contains no expected response. Communication
and Perception establish actual reception; the shipped Controller appraises the
recipient; Organization freezes the response and its separate later-delivery
horizon. The resulting choices contain four each of accept, qualify,
counter-propose, defer and contest, with every observed response represented in
every partition.

Survivors execute through `SAO.Controller`. Afflicted and Crossed retain
separate pathogen audit state but both resolve the living human shell, current
activity, capability and generic competing pressure through the registered ZAO
adapter and `ZAO.Driver`. Their condition identity is not a task input. Border
191 changes or rejects the evidence when Controller pressure selection, ZAO
execution registration or Driver attribution is broken.

These rows are controlled headless observations with synthetic initial facts.
They are not loaded-world samples, independently approved labels, trained
behavior or a runtime integration. Decline and withdrawal are valid process
responses but are absent from this source family.

### Native coordination shadow (C82)

Speakeasy Records 66-67 independently review and train the exact C81 family,
then export a content-hashed `SAOCRD01` version 1 FP32 artifact. C82 packages
that 13,050-byte artifact as a jar resource. The JDK-only reader validates the
complete tokenizer, label/support, feature, tensor and source-identity contract
before constructing an evaluator; no external inference runtime participates.

`SAO.Organization` forms the production response first. The shared Lua owner
then serializes only the source-owned decision-time view and 16 typed channels
to immutable strings and arrays. A single low-priority daemon evaluates them
behind a bounded queue and pending map. On return, Lua requires the exact bundle
and input hashes, process/response revisions, feasible options, rebuilt input
and current registered execution-owner signature. Foreign, malformed, stale or
owner-changed results become bounded withheld observations. Graph bind and
world detach cancel all transient Lua and Java state; nothing is persisted.

The shadow is not a decision owner. It cannot select, revise or deliver a
response or create a commitment or work. Condition-private fields are refused
from proposal, reception, capability, constraint, interest and owner containers.
Afflicted and Crossed use the same registered ZAO executor while their distinct
maintenance, motives and action policies remain outside the generic input.

Borders 192-193 execute exact Python/Java/tokenizer parity, the packaged jar,
capacity and reset controls, authoritative response ordering, Survivor and
distinct ZAO-owner paths, and stale/foreign/hidden/owner-drift refusal. This is
mechanical headless evidence. Behavior activation, decline/withdraw data and full
JVM heap cost remain model and performance work.

The first unit covers voluntary coordination and contention. It does not yet
produce elections, deliberation, appeal, coercive enforcement, physical
separation or general institutional succession. Legacy election and schism entry
points explicitly require an enacted process while cleanup remains active.


### Competing cognition and discovery (C88)

`SAO_CognitiveModels` owns two independent computational contestants: ordinary
need-threshold cognition with direct evidence, and associative cognition with
anticipatory resource selection and a bounded relational hypothesis grammar.
Each person persists separate model versions, beliefs, receipts and hypothesis
revisions in `rec.cognition`. Neither model reads or adjudicates the other's
output. `SAO_Cognition` freezes both proposals and every candidate action's
prediction before deterministic balanced selection. Allocation weights describe
that selection policy, not randomized treatment propensities.

The initial executable seam is safe idle resource deliberation after immediate
threat and medical handling. Existing accepted work and timed actions retain
ownership. Water, food, inspection and continuing activity pass through existing
Standing, routes, SourceUse and native action handlers. Current private needs,
place/source counts, personal thresholds and Labor capabilities form the shared
input. Observer position and hidden stock supply no model evidence.

Actual personal inspection, exact native acquisition/storage, captured transfer
witnessing and measured own consumption enter an event-bound ledger. Admission,
queueing, attempts and effects remain distinct. Original episode tokens prevent
a late result from resolving newer work. Both models revise independently from
the same authenticated experience. Unavailable, interrupted and unmeasured
results are censored. Both predictions are scored against the selected action's
qualified outcome; unexecuted alternatives retain no outcome.

C120 extends that existing ledger to personally encountered entry outcomes and
measured native recovery. Perception owns exact-aperture receipts; Needs owns
observed recovery segments. Cognition rereads the producer's canonical receipt,
retains an actor-qualified sequence and updates both independent model states.
The ordinary model's applicable expectation changes entrance cost and close
recovery preferences through their existing consumers. Current observations,
emergency needs, danger, Standing and native feasibility govern admission.
Entry conditions remain tied to the actual encountered edge and its attempt;
arrival alone supplies no evidence about which opening was used. Recovery
requires the same body, measured values and observed elapsed time before its
owner clears. Reload starts a fresh observed segment. Repeated receipts and
unobserved elapsed time supply no additional experience. Confidence uses the
existing aging rule; reads do not train either model. Model versions /1 and /2
remain readable and migrate to /3 when authentic new evidence is admitted.

RecoveryPose owns an independent exact-body/person/token action capsule through
the existing native timed-action queue. SAO packages actions and namespaced
ground-animation nodes derived from Lean & Lie 1.27 mechanics, referencing the
installed game's native clips. The SAORecoveryGround variable owns ground state.
Admission, elapsed observation, cancellation and cleanup retain the same actual
body and ownership token. Needs admits physiological recovery only from the
qualified native pose and measured segment. Stale callbacks and retired receivers
cannot earn another person's recovery result.

Saved preparation retains its 1,800-county-tick navigation origin and deadline
separately from the 120 native-idle admission ticks begun at the observed approach.
An already started wait remains binding during displacement; reload or requeue
cannot renew either clock. Current person/body/custody, Standing, entry, needs,
threat, responsibility, locomotion job, offered-place geometry/index and runtime
key govern admission. Fresh reobservation retains prior-key provenance with
`persistentObjectIdentity=false`; native bed-pointer and pose/physiology ownership
remain exact.

The D1 saved continuation demonstrates this admission path: `sao-2` reacquired
the visible bed, entered owned sleep and retained nine intent/key acknowledgements.
Fatigue fell from 0.7783 to 0.3888 over 1.75 sampled county hours; the world
advanced and saved normally without runtime errors. The closed D1 record retains
the exact native observations. Unavailable or refused admission grants no
physiological recovery result.

`SAORecoveryPlace` produces personally visible resting-place candidates. Native
bed geometry supplies an exact furniture identity and a clear approach; ground
requires a clear lying envelope at the base and animation-offset positions,
away from doorways, windows, blocked seams and other bodies. Controller selects
a permitted usable bed before a ground alternative and routes through the
existing Locomotion owner to that exact approach. Arrival rechecks the body,
Standing, native place availability and ownership. Nighttime sleep uses this
same admission path. RecoveryPose reserves the exact bed while native entry is
queued, uses `ISGetOnBedAction`, and binds its physiological quality only after
native pose acknowledgment. Needs checks the selected furniture throughout
recovery and reacknowledgment; native get-up owns bed teardown. Ground remains
an explicitly considered fallback after inquiry, subject to physical clearance.
The visible bed's furniture `Facing` supplies the producer's head/foot geometry
and each owned native entry action's two direction calculations. The entry action
retains the installed queue, animation events, alignment and get-up lifecycle.
Native query diagnostics retain bounded visible rejection reasons and distinguish
an unavailable query from an available query with no admissible place.

The operator's qualitative-reasoning requirement applies across ordinary choice.
General knowledge of purposes and relationships combines with a person's prior
life, retained experience and current private observations to form alternatives
and conditional expectations. A remembered general relationship can guide
inference and investigation while the particular local condition remains unknown.
Execution and its measured consequences remain the existing owners' work.

The local shared-reasoning continuation gives private plan candidates explicit
conditional consequences. Labor supplies exact acquisition, preparation and
inspection alternatives. CognitiveModels compares applicable source, item type
and entry-condition evidence, retaining uncertainty and the contributing receipt
identities. Contrary outcomes revise these expectations; elapsed time weakens
confidence without creating experience. The associative model can transfer a
weaker expectation from related preparation or inspection evidence. Current
native capability supplies a labelled preparation prior, with no claim of corpus
comprehension or completed practice.

Cognition gives both models separate copies of the same alternatives and their
own retained state. Its configured contestant is stable within the private
decision interval and supplies the actual selected resource route. Candidate
pruning uses that same interpretation. Cold appraisal uses disposable model
state; it does not create a learning record. Entry alternatives and the choice
among sleep, awake rest and continuing activity use the same prediction owner.
Needs retains accepted responsibilities as competing purposes and limits learned
influence so repeated disappointment cannot veto extreme recovery pressure.
Standing, known destinations and native ownership still govern admission.
Planner observations retain detached, bounded predictions and their evidence.

D1 joins ordinary bodily recovery and resource needs, ready accepted commitments,
carried-manual study and retained cooking practice through that same private
interpretation. Controller produces personally valued alternatives and dispatches
the selected purpose through its existing native owner. Disposition, bodily
pressure, retained purpose, accepted responsibility and authentic recovery
experience contribute to the comparison. Urgent medical, danger and deprivation
responses retain their admission boundaries. A failed admission removes that
candidate and re-ranks the remaining alternatives; food and water retain separate
retry clocks. Study survives the ordinary caller, and asynchronous study
cancellation preserves the exact selected commitment for revalidation on resume.
The retained ordinary-purpose decision contains detached values and explanation;
native bodies, manuals and queued actions remain transient owner state.

DR-057 extends this shared reasoning to aggression, self-defense and cooperation.
`SAO_CognitiveModels` evaluates conceptual arguments about bodily harm, separation,
obstruction, defense, force, agreement, mutual support and coercion. The person's
private observations, learned associations, values and accepted responsibilities
change the available reasons and the selected response. `SAO_Cognition` admits
detached private frames; `SAO_ProceduralPlanning` retains the current purpose,
alternatives, native admission, exact attempt results and recent route refusals.
Numeric weights remain internal mechanisms. A conceptual expectation supplies
neither a local target nor permission to attack.

Every selected private contact may enter appraisal, including distant contacts.
Watching can preserve a real ordinary task; its route toward danger supplies an
objection. Appraisal may update during a native crossing while that owner retains
the body. `SAO_PathogenPressure.appraise` reads the actor's recognized form and
retained experience without acquiring another encounter. The resulting private
risk premise qualifies reassurance from distance and participates in continuity.
Physical distance still governs native reach. Anonymous audible events retain an
unknown cause; the generic native sound row supplies no acoustic category.
Personal outbreak knowledge and test initialization remain distinct from world
age and ordinary-life priors under DR-057's knowledge clarification.

`SAO_ConflictResponse` joins Controller's threat turn to this interpretation.
Personally remembered routes and immediately observed ground support withdrawal
and repositioning. Native combat offers a bounded shove, stomp, melee strike or
ranged attempt against the actor's exact observed target. Standing governs force;
the installed attack entry, physical reach, obstruction and native animation own
admission and body custody. Changed danger requests handback before another
action. A completed attempt proves neither injury nor threat elimination.
Accepted cooperative segments use existing Organization and Coordination owners;
spoken threats require Communication reception, and concessions use exact Handover
receipts. Cancellation preserves a material transfer that already completed and
waits for the exact action to leave both native and Lua queues. Agreement,
compliance and pacification require their own observed consequences.

Native player-versus-player permission is a remaining human-opponent boundary:
the installed single-player engine treats SAO player shells as players and rejects
their mutual attacks while cooperative PvP is disabled. Standing permission alone
does not bypass that native rule. No global PvP setting is changed by this slice.

Conflict admission and bounded feedback persist in the person record. Disposable
body/job bindings belong to the loaded controller. Detach settles exact admissions;
adoption reconciles orphaned work as unobserved. A terminal callback outside its
admitted observation interval releases the token without crediting the outcome.
Observation exposes beliefs, intended response, alternatives, physical admission,
result and unresolved consequences separately. Broader acquired ideologies,
self-destructive or last-stand commitments, coordinated attacks, pacification
and institutional consumers remain explicit DR-057 implementation joins.

`SAO_ConceptKnowledge` owns general relational expectations. Its declared
ordinary-life foundation connects places, likely constituents, usable means,
activities and effects. A person's canonical co-observations add private learned
associations. Bounded traversal returns defeasible paths with contributing
relations, provenance, contradictions and explicit unknowns. Reading an inference
does not initialize or train a person's record. A house can suggest a bedroom,
bed and sleep without supplying a bedroom's coordinates or asserting a usable bed.
The foundation is a small vocabulary. The existing Education/Registry owners
extend it with source-bound, dated personal schooling, work/training and
community/literary exposure. Versioned authored events retain the actual
carrier, acquisition channel and region chronology beside the literal held
source unit; reported norms keep assent unestablished. Current native
birth history and registry identity gate each background premise; refusal
preserves the record and withholds its meaning. Literal source content supplies
conditional inquiry, with retention and mastery unassessed. Native food
recognition supplies another exact personal premise through current item and
learned-recipe knowledge. Broader cultural differentiation and assessed
K-through-college assessment and retained transfer remain separate implementation work.

`PersonalAwareness` retains explicit initial personal reports and later private
evidence. `PopulationAdmissions` stages the optional authored study history
before genesis and binds its provider to the actual person, admission ordinal,
source definition and save. Empty history means uninformed; omission uses the
legacy setting. Current custody gates retained interpretation after reload.
Private radio reception supplies a report, and personally observed change of a
previously observed familiar body supplies a bounded association. Neither an
unknown sound nor a stranger's body supplies a confirmed outbreak cause.
Conflict appraisal consumes that private uncertainty while retaining ordinary
physical defense and withdrawal alternatives. Later ideology, pacification and
joint offensive coordination retain their separate behavior contracts.

`PersonalMemory` retains dated autobiographical episodes on the actual person's
record. `PopulationAdmissions.stageInitialLifeHistory` accepts source-defined
episode sets before genesis, binds the requested site/admission ordinal to its
generated identity and stamps that identity into each retained episode. Native
GameTime supplies the world start date; native History and an available education
profile must agree with the authored birth year. Occurrence precedes acquisition,
acquisition precedes the pre-1994 start cutoff, and reload requires the original
definition, save and complete source rows. An explicit empty episode set and an
omitted history remain distinct.

Configuration staging retains its attributed stamp separately from lived
admission chronology. A fresh historical replay can rebase county time before
genesis; custody remains tied to staging before identity generation and the
exact source rows. Recall reads `History.countyInstant` on that owned coordinate.
Episodes acquired after the current replay calendar remain retained and
unavailable until their acquisition date; admission does not reset episode age.

Each episode retains its description, participants, dates, valence, salience and
declared real or authored-synthetic source identity. These source attributions
do not themselves establish that a claimed real event occurred. Pure recall
reads present `Neuro.clarityOf` and existing `Conditions.memoryFactor`, including
its health-trait and age effects without applying its Neuro factor twice.
An absent condition owner is identified as a Neuro-only projection. Invalid
owned inputs withhold recall. The dated retention projection uses explicit
uncalibrated coefficients; impairment changes accessibility without rewriting
the underlying life. `ConceptKnowledge` consumes accessible autobiographical
associations as modal premises for its existing inference and inquiry paths.
A recalled counterexample remains attributed uncertainty alongside fresh
evidence. Autobiography supplies neither current coordinates nor native success,
mastery or another person's assent, and is not automatically a teaching offer.
Bounded autobiographical roots expose their omitted count to the inference
receipt; unresolved reasoning does not imply complete coverage of the history.
Neo carries the relevant person-source and model integration through the
participating repositories. Speakeasy owns its latent/post-latent pipeline and
relevant salience; Neo's existing personality/memory mechanisms, SAO's durable
person and reasoning, ZAO's bodily-state authority and the sibling Post-Latent
component retain their producer/consumer seams. Post-Latent is one canonical
participating repository. Wider clinical, hereditary and comprehensive life-history
grounding retain their actual source, availability and implementation evidence.

`History.calendarAgeOf` reads the actual current county instant and immutable
birth year. It returns nominal calendar-year age and the attained-age interval
implied by an unknown birthday. Conditions uses that current projection for its
existing age-dependent retention factor and exposes unavailable projection
metadata. Birth-year identity remains stable across elapsed time and replay.

The January 1 authored-history specimen and its completed native continuation
retain exact person/save/source custody, all three autobiographical episodes,
available owned recall and ten initial purpose identities across reload. These
bounded observations supplement the separately scoped causal owner controls;
they do not establish that autobiography caused a particular native action.
D1's final acceptance is CLOSED with controlled person-specific reasoning and bounded native recovery.

`SituationAppraisal.query` combines attributed reports, personally heard fresh
sound pulses, conceptual expectations, observed frontiers and current personal
disposition. Its detached questions retain interpretation, uncertainty, possible
consequences and source evidence. ProceduralPlanning offers a bounded inquiry
through the existing movement owner. Controller includes it in ordinary
arbitration alongside needs and commitments; a personally uninteresting concern
can lose to continuing activity. Retained questions and exact-once observation
revisions survive interruption and native serialization. Arrival supplies a
route result, while recognition of a cause requires acquired evidence.

`PersonState.query` exports `sao-person-state/1` for an exact registered person,
owned body and current clock. Its `modelView` contains the eight effective SAO
disposition axes, year-resolution age, accessible recalled episodes, native
temper and cognitive projections with observation provenance. `audit` retains
private trait, memory and question custody. Neuro supplies separate availability
metadata for native moodles and the durable event-derived brain state; numeric
compatibility defaults remain unavailable to the model task. Incarnation remains
explicitly unknown when no universal generation producer exists.

StudyWorld places this detached export at `people[].context.personState`, marks
its schema-owned lists and records whole-field omissions on byte-budget or owner
failure. The transport validates person and clock joins. Speakeasy's
`person_history_intake` binds frames, profile/facet assignment and source bytes;
its versioned person-context renderer selects only available person-state fields
and accessible episode IDs. The composed responder checks the canonical fitted
model owner and executes shared-base inference with complete-input bounds.
Prepared tasks retain selected concerns, rendered-view hashes and pre-outcome
custody. Output admission and training/assessment retain separate evidence.

`Cognition.choose` retains optional `episode.decisionPersonState` with schema
`sao-person-decision-state/1` before model proposals. The envelope binds the
person, decision frame ID, current tick and decision county hour to a detached
actual owner query. Missing ticks omit the optional field in legacy runtimes;
stale frames and unavailable owners retain explicit unavailable reasons. Full
snapshots preserve the whole state, and compact snapshots refuse an oversized
state whole. The observer marks frozen person-state lists on its detached export
before serialization. Frame IDs and trajectory episode IDs have separate roles.
Both Speakeasy's task intake and the actual native watcher validate the sidecar
and freeze its presence and contents across later snapshots. The model input uses
the decision view; later periodic state and outcomes remain diagnostic evidence.
The selected native concern joins through its canonical `question.key`. The
versioned semantic renderer retains the full selected question's substantive
evidence, uncertainty, anticipated consequences and acquired relation meanings;
source graphs, revisions and custody remain in the exact typed task/audit rather
than prompt metadata. A declared semantic projection is distinct from an exact
full-graph prompt. The fitted owner's fixed context bound refuses oversized
inputs whole, before generation, with no silent truncation or numeric health
substitution. The actual watcher retries bounded transient session-file sharing
failures; lasting denial, other errors and invalid schema remain failures.

Native perception retains actual contact floors through private beliefs, threat
selection, conflict interpretation and labor danger projection. A known separate
floor qualifies horizontal proximity and leaves contact reachability unknown.
Native combat opportunity continues to own admission of a physical defense or
strike, including a genuinely available ranged opportunity.

`SAOConceptObservation` supplies occupied-room geometry, personally visible
objects and visible doorway approaches through the existing native gaze, range
and line-of-sight owner. The bridge returns plain scalar records. Perception
checks the current body against its canonical person and controller. Ordinary
SAO bodies carry their person ID without an external-ownership token; foreign
ownership and mismatched tokens are rejected. Perception retains observations
privately; authored room names and hidden contents
do not become personal knowledge. A remembered home can supply a residence
classification. A visible doorway supplies an adjacent crossing to investigate;
the unseen destination's role and contents remain unknown.

ProceduralPlanning connects the selected concern's desired effect to those
personal expectations and observed inquiry frontiers. Controller admits the
resulting inquiry through Standing and the existing Locomotion owner. The
retained purpose carries its relational path, sought means and attempted
frontiers by their directed room-side edge. Untried doorways take precedence;
the same doorway may be crossed back out of a dead end within the retained
attempt bound. Runtime body and job bindings stay transient. An inquiry route result
establishes movement or obstruction, and fresh Perception supplies what was
actually found. Interruption preserves the question. Existing urgent needs and
native action ownership govern admission. Ordinary concern priority still uses
the earlier utility arbitration; this join makes conceptual knowledge causal in
the choice of means while the wider priority reform remains open.

Personally observed means also support inquiry after leaving the room. Perception
retains the object and a room anchor where that person actually stood.
ProceduralPlanning connects its known object-to-effect relation to the concern;
Controller routes to that observed anchor and refreshes perception on arrival.
Current native admission determines whether the object can be used. Attempts
remain bounded by object, room and context, with Standing and work availability
checked through their existing owners.

Recreational literature uses `SAO_Study` and its exact carried book, body and
native `ISReadABook` action. Planning retains the leisure purpose; Study separates
preparation, observed execution, completed use and interruption. Native progress
and completion own the book's effects. Reading retains the Controller turn until
completion or an admitted interruption. Inspection projects these phases and
does not infer a wall posture from the purpose. Musical gesture admission reports
preparation; listener effects require actual sound and reception. A keepsake
intention remains unresolved until a physical executor supplies its result.

Personally visible loose items now enter Perception through native same-floor
visibility. Private evidence retains item identity, visible type and geometry,
and established reading or instrument affordances. Exact physical signatures
remain with WorldSources for transfer validation; passive sight establishes no
fluid safety, quantity or hydration. Controller can compare a supported loose
material with carried activities through the existing ordinary chooser. Planning
retains its acquisition purpose, SourceUse owns current permission and native
pickup, and measured exact transfer advances that same purpose into Study or
Gesture. Repeated acquisition, interruption and reload preserve exact receipt
identity. Pickup establishes custody; the physical verb owns its later result.

Writable literature has a distinct native timed-action owner. Study admits exact
existing custom text from carried Literature, keeps unread content transient,
and revalidates body, material and full text through native perform/complete.
Private completed exposure remains separate from comprehension. Planning consumes
the canonical Study result under typed authority; native book page counters,
recipes and generic practice do not certify note exposure. Observation names
written notes and exposure while retaining unknown understanding.

Instrument work retains its exact native WorldSound occurrence. The normal
scanner's actual audible acquisition and witnessed emitter visibility can join
that occurrence to a listener-private hearing receipt. First anonymous hearing
and later witnessed hearing retain separate dates, native clock domain, body
generation and pulse epoch. Coordination and Organization use existing addressed
procedures and accepted commitments for perform/listen roles. Returned assent
precedes a fresh performance; native sound, private hearing and actual spoken
acknowledgement precede the performer's shared-purpose result. Controller dispatch
uses those private role offers. Waiting to hear yields an ordinary turn; recorded
hearing supplies its own observation. Controlled owner/consumer proofs establish
these source joins within the delivered D2 recreation product.

A source-owned Week One performance exposes only a current, exact native sound
occurrence to SAO's person. An awake owned body attempts its private hearing
claim on each observation callback, including between county-time full scans;
the native claim still requires live pulse, emitter, body generation and
personal audibility. A retained occurrence is not claimed again on later
frames. This carries actual performance evidence into the same person's
persistent hearing history without making the imported source role a native
person identity or treating hearing as participation or assent.

The ordinary observer acquires the native sound row before attempting the
performance claim on that callback. For a loaded Week One source proxy, the
source cache's separate advancing Java cursor admits a bounded candidate slice
on each tick while a performance is live; exact source body and SAO person
custody precede the same personal scanner and private claim. The cursor admits
the explicit performance-row and hearer streams. Its 128 raw visits per tick
bound candidates, while native sound-list work depends on nearby eligible
listeners and currently live sounds; a larger or continuously changing cache
can outlast a short pulse. These bounds do not imply universal reception.

The exact source proxy's cached program callback also acquires ordinary native
sound through the same `Perception.observeAudible` path before its next full
county-time sight and cognition scan. Repeated source program callbacks sample at most once per
SAO person, current source body, brain generation and tick; an exact saved
body rebind samples before the second cached appraisal return. The separate
live-performance OnTick path may rescan that listener in the same county tick
when a performance remains live, so the cache is not a global sampling cap. That sound is
the person's anonymous private evidence. Source ownership still governs its
physical task. The ordinary SAO Controller's situation-inquiry route requires
SAO body and native concept-observation custody. A source proxy can instead
offer the same person's unresolved question to the existing private cognitive
comparison when its exact current source body sees an outdoor ground approach.
`SAO.WeekOneContinuity` asks the source task actuator to move to that visible
square and records the selected attempt in the person's Planning purpose.
The source role stays provenance for the actuator, not a person identity.

The selected source inquiry has a Planning admission, which retains its purpose
through active-purpose capacity and conflict handoff. A separate bounded tick
poll reads the exact source body, selected native position and current target
visibility. Perception publishes a successful concept-read receipt only for
that body, brain generation, tick and source tile. Planning revises the retained
question only after those observations agree; the source move callback itself
never certifies arrival or a sound cause. Lost custody or a deadline records an
unconfirmed attempt. A transient reconciliation failure retains the pending
attempt and its admission. Terminal reconciliation runs at most once per county
tick. Sixteen failed terminal attempts mark it durably unresolved, then defer
another attempt for 240 county ticks; later failures repeat that backoff until
Planning acknowledges the result. The shared concept interrupter only releases
inquiries it owns, leaving this source inquiry with its Week One owner. The Java
cursor admits the pending-person stream and bounds each poll to sixteen IDs.
Sustained mutation of a larger pending table can restart iteration, so the bound
does not guarantee every pending ID advances.

An unresolved anonymous sound question retained by an admitted inquiry remains
available after its native pulse expires and across a save reload. Situation
appraisal reads only that person's saved revision, preserves its original
hearing date and unknown cause, and requires a current owned concept observation
before planning can offer another approach. The route targets a presently
visible object or ground lead; the remembered sound coordinate is evidence of
an earlier direction, not an independently actionable destination.

Study, practice and social consequences have explicit unknown predictions until
their authentic result owners supply applicable experience. D2 integrates leisure
choices and their native result owners. Wider anticipatory resource purposes,
educational/cultural priors, automatic assessment, retained understanding and
broader transfer remain work across the existing owners. The literal corpus
remains an actual knowledge and training input; trained general competence
remains model work.

Connected receipts can seed near associations and cross-domain technological
conjectures. Repeated identical operations cannot manufacture deeper evidence.
Contradicted branches keep bounded identity and revision continuity. Confidence
ages each receipt without erasing the observed fact or learning on reads. Every
hypothesis retains provenance and missing mechanisms. It supplies no recipe,
skill, construction method or native effect. The initial action seam supports
resource experiments; realization of deeper technological mechanisms remains an
explicit capability gap. These computational models are a training substrate,
not a trained aggregate or evidence of general awareness.

Mousecat's existing native person inspector displays both models, disagreement,
hypotheses and selected-action evidence through Speakeasy. Bounded controls set
opposing allocation, opportunities per county hour and association depth. The
complete command applies atomically, including while paused. Observation is
read-only; display reductions expose omissions. Archive cognition snapshots
cover up to 64 episodes and 256 experiences per person, separate from the small
live view. C104 shares an eight-MiB encoded-copy ledger across archive channels.
Selected-person detail takes priority; required inspection shapes and physical
squares remain whole or explicitly omitted. Loaded export omissions and
unavailable geometry have separate coverage counts. Final encoded overflow
produces a source-bound, read-back-verified deferred receipt without advancing
the archive sequence. Live inspection reports that condition, and successful
capture replaces its receipt. World state and private cognition retain their
existing owners; unexpected encoding and I/O failures remain fatal.
Expected byte exhaustion returns a nonthrowing bounded result from that same
encoder. Inspection, cognition, live core fallback and archive trials commit
bytes only when they fit. Unsupported values, non-finite numbers and cycles
retain strict failure, avoiding native debugger faults for optional omissions.
Unescaped strings retain the same UTF-8 byte accounting and pass through without
escape construction. Live export admission waits one second after successful
writer close. Its completion timer remains separate from captured source and
world clocks, while encoding and writer failures retain their stop authority.
Physical capture interleaves whole squares outward from each authored area
center under the shared budgets. Native automatic camera commands retain
regional residency only when their paired View target is proven loaded inside
that map's chunk boundary; explicit residency and independent coordinates keep
their exact semantics. Native streaming failure preserves its original cause
and last verified clock before subsequent stale-context lookups are refused.
Speakeasy validates and joins source-hashed trajectories for later aggregate
training, preserving frozen predictions, censoring and gaps. Scenario admission
keeps its existing operator evaluation boundary.

### Native perception and capabilities (C89)

SAO owns the admitted behavioral mechanisms in its source. Pharmacology,
conditions, selected gestures and material actions participate in the same
person, perception, decision and execution system. The prior-art catalogue
records each selected mechanism, producer, consumer, test and remaining gap.
ZombieBuddy remains the explicit native Java loader.

| Owner | Native mechanism and evidence |
|---|---|
| WorldSoundPulses, Perception | Bounded identities for actual audible occurrences; each person retains acquisition time and uncertainty. |
| Orienting, Orientation, OrientationAnimation, Senses | Exact current body ownership admits a finite head sweep and safe idle body turn. Existing Neuro and native physical state shape response. Sight uses the actual gaze and ordinary occlusion. |
| PharmacologyProfiles, Pharmacology, Habits, Drugs | Fifteen owned native items span seven admitted families and maintenance. Native dose completion, physiological passage and dependence persist on the person. |
| Needs | Actual timed-action start, completion and consumption identity bind dose receipts. Real partial alcohol consumption updates its existing history once. |
| Cooking, WorldSources, SAOCooking | Visible appliances and private food offers lead to exact acquisition, deposit, native activation, native heat, retrieval and shutdown. |
| BodySnapshot, Body, DormantPopulation; ZAO Maintenance | Pure checkpoints and exact removal precede dormancy. Existing metabolism/rest and owned effects replay chronologically; refused reconstruction restores prior owner state. |
| CapabilityExperience, Cognition, CognitiveModels | Own consumption, measured bodily change and completed preparation enter the same private evidence stream with capabilities captured at acquisition. Both models interpret independently. |
| Observation, Speakeasy, Mousecat | Read-only attention, medication and preparation state accompany the native camera and competing model inspector. |

Sound can initiate attention toward a possible source. Hearing itself admits no
visual target, identity or wall bypass. Head movement preserves native legs and
path ownership; body turns yield to work, travel, combat, sleep and handoff.
Repeated reads and repeated observations of the same occurrence cannot restart
it. Runtime native handles expire at removal, binding change and world reset.

Pharmacology requires the exact ordinary or ZAO-owned living body and a real
carried registered item. Completion follows a measured single dose consumed by
the native action. Physical effects use actual native Stats, body parts and
fitness receivers. Durable cursors prevent duplicate passage. Bounded dormant
replay composes with the current rest owner, including rollback of ZAO's own
Maintenance state when native reconstruction refuses.

The action owner preserves unresolved SourceUse evidence across interruption,
death and handoff. Cooking credit requires the same deposited raw item to cross
the engine's cooking threshold through native heat. Queueing, a cooked flag or
arrival supplies no completion. A later replacement item remains a physical
result with unavailable attribution until its continuity can be established.

Actor-private experience strips internal family, exposure and thermal-credit
attribution. A felt change is an observation; its cause remains inferential.
The first receipt captures current Labor capabilities and duplicate delivery
retains that original context. Existing saved model versions and frozen
predictions remain readable. Medication and preparation facts cannot settle an
earlier unperformed resource action, and conjectures grant no recipes or skills.

The current decision seam still selects food, water, inspection and continuation.
Cooking is available through its existing work designation. Broader autonomous
verb selection, local-player pharmacology without a person record, mounted
horse execution and complete animal/crafting/repair receipts remain explicit
producer work. The catalogue distinguishes these admitted gaps from reference
material whose mechanisms were never selected.


### Resource approaches and native threat conditions (C107)

An admitted matching loaded item resolves its native interaction square before
SourceUse orders movement. An unloaded remembered source retains the existing
place approach. Saved approach phases resume through the same owner. Resolution
does not bind, transfer or consume an item; current standing, proximity and exact
native revisions still admit those operations. Early refusal retains the private
memory without acquiring unseen changes.

Terminal climbing stalls and expired water approaches enter the exact fixture's
existing failure owner. Locomotion expires only its current body-owned water job;
Controller releases the route and returns to decision. No hydration or assertion
of absent supplies follows. A resolved study stock request preserves its original
outcome and county time through later death or identity loss.

Initial-cohort observation frames do not contain the native spawn-origin catalog.
Archive inspection obtains that catalog from the verified source package before
checking regional initial conditions. An unbound initial-cohort frame reports
missing authority; a synthetic inspection origin cannot replace the real catalog.

Study definitions may declare initial native threats near an observation site.
An unloaded square remains pending. Once loaded, StudyWorld records the exact
definition, save, site, position and count before calling the native constructor.
Existing attempt receipts must match that binding. Created, partial, refused and
ambiguous attempts persist without replay. VirtualZombieManager owns actor
identity, stats, events and ordinary AI; the study restores its temporary choices
and supplies no target or survivor perception. Observer exposes actual native
zombie count and the disabled flag.

The isolated observer skips instruction breakpoint lookup when the installed
KahluaThread's breakpoint map is empty. Source positions, stepping, nonempty maps,
watchpoints, error handling and Core.debug retain their native paths. Explicit
native lookup and ordinary launches remain available. Installed VM controls prove
these branches; live speed benefit remains an unmeasured performance question.

Loaded resource plans still lack a deliberate scout candidate. A nearby location
is not evidence of its supplies. Search appraisal needs person-private memory,
observation, reports and uncertain inference, plus perceived danger, home,
acquired responsibilities and allies. The execution repair does not establish
that wider appraisal or make an unobserved container accessible.


### Private survival planning and residence (C108)

Labor compares exact actor-private source and visibly observed holder locations
using the body's own position, this person's lived home, remembered destination
threats, acquired food requests and accepted delivery responsibilities. A request
does not supply destination knowledge, another person's capacity or assent.
Unknown route coverage and absent remembered danger remain explicit. Distances
are straight-line ordinal comparisons; travel duration and barriers retain their
native execution owner. The ordinary and associative models independently value
danger, approach, return and concern with explicit uncalibrated coefficients.
Ordinary truncation and fallback use the same terms. Detached purpose snapshots
carry the interpretations and uncertainty through existing observation.

WorldSources stores at most16 canonical inspection attempts per person, retaining
all admitted and unacknowledged terminal rows. Each binds person, purpose, step,
source, fingerprint and coordinates. It installs admission before Planner queries
that authority. Completion requires actual native inspection and successful
private fact acquisition; empty inspection completes only the inspection step.
Planner requeries the terminal owner and acknowledges one matching result.
Order refusal, lost runtime, successful handoff and native death interrupt or
fail the attempt without stock or practice. Unacknowledged delivery retries.
Inspection retry identity includes exact source and fingerprint, so failure of
one holder does not delay another holder in the same building.


Needs admits sleep through native SleepingEvent and measures the inherited
physiological update. The legacy manual helper grants no extra improvement.
Controller grades recovery after available relief attempts, revalidates private
threats and Standing, and bounds waiting without progress. Native reference
retirement protects the exact body across handoff, death, forget, reload and
reset. ResourceProduction keeps unfinished work through ordinary appetite or
fatigue while current injury, urgent deprivation and executable relief retain
their preemption authority.

C119 lets that same bodily preference compete with speculative residence search
and optional resource travel after immediate carried relief. Labor requires
private permitted home geometry for recovery return. Controller reconsiders an
admitted search after the existing movement tick supplies a current verdict;
native opening, smashing, climbing and queued actions retain their ownership.
A safe pause preserves the maintained purpose, private evidence and retry ledger.
Recovery arrival retains intent while actual native occupancy and Needs admission
decide whether recovery begins. The unfinished search is reconsidered using
current needs and evidence after recovery or interruption.

ProceduralPlanning persists a residence purpose separately from practical work.
Labor acquires its private home, comparative remembered danger, attachment,
conflict, responsibilities and movement capacity. Competing stay and travel
values use explicit uncalibrated coefficients. Native Locomotion owns the
admitted route; reconsideration preserves it until an actual preemption or
terminal verdict. Loaded and dormant consumers both respect refusal backoff.
Standing completes a residence only for the exact actor after native indoor
arrival at the privately acquired building. Prior home history remains bounded
and remembered. No group or player-companion callback rewrites other homes.

SAOPerceptionScanner produces exterior rows from actually visible loaded
boundaries and an observed free approach. Perception stores that acquisition
with provenance and time; neither bounds nor contents are inferred. An observed
doorway or window supports a bounded entry hypothesis. Visible aperture state
records open, closed, barricaded, smashed or clear conditions on the observed
side. Existing native movement resolves locks, opening and climbing; the resulting
perception may acquire current exact holders. A terminal interaction receipt
names the actual failed edge independently from the route goal. Exact native
job/body/route/step admission authenticates a matching personally acquired lead.
Separate geometry-bound entrance keys retain alternative entrances and independent
refusal deadlines. Scanner output is bounded at16, private retained entrance
memory at64. Reobserving an entrance updates acquisition time while preserving
its identity and the attempt backoff. Changed visible state permits reconsideration;
unchanged personally encountered resistance retains a bounded comparative cost.
These explicit uncalibrated weights compose with urgency, danger, disposition and
travel effort. An admitted route cannot be retargeted by
a newly acquired entrance. Dormant execution revalidates exact geometry and time.
WorldSources.currentInspectionAnchor accepts only the exact current candidate
and native actor/context/geometry and feeds its identity into the durable
inspection owner. Present Standing reads privately believed ownership; an
unacquired global claim cannot supply a physical veto. Claims retain their
existing record meaning; residence choice itself creates no property or assent.


### Bounded observer projection (C109)

Observer capture retains current needs, attention, action, pressure, exact
source receipts and events for sampled people. Only the explicitly inspected
person rebuilds background, inventory, planning, global process detail and
cognition summaries. Unrequested rich sections use the existing unavailable
status and empty rows. Failed refreshes retain the last successful source clock;
removed selections are omitted without automatic retargeting. The existing
sixteen-person inspection cap remains explicit.

Study archive capture skips square object and sprite projection once the shared
node or byte ledger cannot accept its table. Native square lookups retain the
distinction between loaded omissions and unavailable geometry. Archive order,
cadence, evidence budgets and optional full cognition ownership remain unchanged.
Process completeness reports row coverage; field omissions remain explicit.

Native terminal validation distinguishes the single initiating stop from its
observer drain and native save return. Valid wall-limit and supervisor stops
preserve their phase order, identities and clocks; duplicate or malformed
stages refuse. Existing direct-save formats remain readable. Twenty-six
terminal cases and eleven production controls pass within the thirty-one-test
unit suite. The retained C107 log passes the corrected parser and fails the
restored original parser; all 1,168 saved-file hashes and both log hashes match.
Its original failed records remain unchanged; corrected validation retains the
authentic native save and its original evidence.

Focused observation verification passes 78 production Lua checks, four default
inspection checks and 29 Lua controls, plus four actual native health checks and
three controls. The installed-Kahlua archive probe passes nine causal controls.
Node exhaustion makes zero object projections while retaining 48 native lookups,
24 loaded omissions, 24 unavailable squares and full cognition for three actors.
Byte-only exhaustion leaves one byte and 274 charged nodes; zero object or sprite
projections preserve the same physical counts. All three full cognition requests
are explicitly omitted when bytes cannot admit them. Removing only the byte
predicate fails the exact projection assertion.

Independent review found no Critical, High or Medium issue. Its byte-only proof
gap is closed by the separate causal control. These controlled proofs establish
avoided projection and truthful freshness. Loaded latency, 60/120 FPS targets,
broader survival quality and aggregate learning remain performance and model work;
dataset admission follows Speakeasy's existing source-review contract.


### Route progress and tactical continuity (C110)

Locomotion measures physical and native node progress before calling a route
stalled. Repeated ManualRoute verdicts preserve a route while it makes progress.
True lack of progress still cancels after the existing 300-tick interval. The
best progress baseline survives missing, malformed and alternating telemetry;
jitter, circling and changing verdicts cannot keep a stalled route alive.
The Java bridge exposes the current route node without changing it.

Coordination retains each actor's tactical intent while a moving fallback
changes within the same private threat cell and count band. Meaningful floor,
danger, cover, crowd and destination invalidation still revise the proposal.
Pause preserves the intent, and current Organization response revisions remain
the authority for assent and commitment. Stable destination identity cannot
create another person's reception, agreement or delivered work.

The sealed two-person C108 trace motivates both repairs. Nineteen consecutive
distance reductions preceded cancellation solely for 300 unchanged verdicts.
Another route was superseded as fallback moved one tile within the same threat
bucket. These source controls restore both defects. The historical trial and
its saved outcomes remain unchanged; a new loaded replay was not started.

Border 228 executes 31 route cases, 50 tactical cases, six native route checks
and eleven rejected source controls. Focused cooperation, home-route and flee
continuity checks pass, with independent correctness and coherence reviews.
The route-progress bridge has packaged bytecode evidence. The source-only
repair is reanchored onto the actual public C109 parent and rebuilt there.
The complete normal closing gate and public checks have their own receipts.
Broader threat reasoning, educational competence and speech continue through
their existing implementation and model owners.

### Persistent observer subjects (C115)

The independent sealed observer layout owns optional unique subject identities.
The bridge follows the assigned person's reported position through the authored
world and retains the native site identity. It qualifies pictured labels with
the applied command and captured native float pose. Missing observations and
death clear current claims. Manual camera control and automatic resumption are
per site; zoom remains the engine's existing projection operation. Current
control samples and pictured viewport metadata retain separate source clocks.

### Continuous native observation (C116)

`StudyVideoCapture` owns bounded asynchronous framebuffer readback and encoded
publication under the isolated observer. Optional encoder/fps arguments travel
through the study session into initial and resumed runs. Per-fragment crop
identity and pixel bounds require every sampled frame to agree; full camera
pose and native command epochs require their own stronger agreement. Actual
capture/frame/world intervals persist without interpolation. Speakeasy owns
source-bound relay validation, Mousecat owns shared decode and presentation.
Native cutaway retains the engine alpha owner. Observation produces no NPC
knowledge, result receipt or training admission by itself.
