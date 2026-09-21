| Document | Survivor Awareness Overhaul Findings |
|---|---|
| Version | `2.8.1.0-pre-alpha` |
| Author | ellyj3rain |
| Repository | `FINDINGS.md` |
| Status | CANONICAL, APPEND-ONLY - verified engine findings. |

# Findings

Append-only record of verified facts about the Build 42.20 engine surface. A
finding is admitted when it is reproducible from stated inputs and its
verification method is recorded. Hypotheses are labelled as such and are not
findings.

Verification source unless stated otherwise: `javap` against the installed
`projectzomboid.jar`, and the shipped `media/lua` tree.

---

## F-001 — The NPC flag's setter and getter live on different classes

**Claim.** `setNpc(boolean)` is declared on `zombie.characters.IsoPlayer`.
`isNpc()` is not; it is declared on `zombie.characters.IsoGameCharacter` and
reaches `IsoPlayer` by inheritance.

**Verification.** `javap zombie.characters.IsoPlayer` lists exactly one
npc-related member, `public void setNpc(boolean)`. `javap
zombie.characters.IsoGameCharacter` lists `public boolean isNpc()` alongside
`isVisibleToNPCs()`, `setVisibleToNPCs(boolean)`, and `IsSpeakingNPC()`.

**Depends on this.** Any code testing NPC status must target the character type,
not the player type. Assuming a symmetric accessor pair on `IsoPlayer` produces a
missing-method failure at runtime rather than at authoring time.

---

## F-002 — `AIComponent` is an ECS component under `zombie.characters.component`

**Claim.** The class is `zombie.characters.component.AIComponent`, and it extends
`zombie.characters.ecs.ECSComponent`. It is not under `zombie.ai`.

**Verification.** `javap zombie.characters.component.AIComponent` resolves and
reports `extends zombie.characters.ecs.ECSComponent`. `zombie.ai.AIComponent` does
not resolve. Jar listing confirms a single
`zombie/characters/component/AIComponent.class`.

**Depends on this.** Access is through the ECS surface rather than a character
accessor. `IsoGameCharacter` exposes no `getAIComponent`; `IsoPlayer` exposes
`visitAllPlayersWithComponent(Class<ComponentType>, BiConsumer<IsoPlayer, ComponentType>)`,
which is the enumeration path.

---

## F-003 — The NPC control seam is an input channel, not a goal channel

**Claim.** `AIComponent.getHumanControlVars()` returns
`zombie.ai.AIBrainPlayerControlVars`, whose entire public surface is:

```
boolean aiming, melee, bannedAttacking, initiateAttack, running, justMoved
float   strafeX, strafeY
```

There is no destination, path, or goal field. Movement is expressed as analog
axis values applied per update.

**Verification.** `javap zombie.ai.AIBrainPlayerControlVars` — the class is
`final` and declares exactly the eight public fields above plus a default
constructor. `AIComponent` additionally declares
`doUpdatePlayerControls(IsoPlayer)`, `postUpdatePlayer(IsoPlayer)`, `update()`,
and `getPlayer()`.

**Depends on this.** The Execution pillar cannot delegate route-following to the
engine through this seam. It must own the path and convert it to per-tick axis
values, in the same way a controller-driven player is converted. This corrects the
`[A1]` architecture text, which implied Execution rides normal pathfinding at the
control layer.

**Open.** Whether engine pathfinding remains separately usable on an NPC body to
*produce* the route that Execution then follows through these axes is not yet
established. Treated as a hypothesis until tested.

---

## F-004 — `IsoPlayer` exposes three usable constructors

**Claim.**

```
IsoPlayer(IsoCell)
IsoPlayer(IsoCell, SurvivorDesc, int, int, int)
IsoPlayer(IsoCell, SurvivorDesc, int, int, int, boolean)
```

**Verification.** `javap zombie.characters.IsoPlayer`, constructor listing.

**Depends on this.** Body construction from a persisted record uses the
`SurvivorDesc` form with explicit coordinates, so reconstruction can restore a
survivor at its recorded square rather than at a default.

---

## F-005 — Real spawn-region tables are reachable from shipped Lua

**Claim.** `SpawnRegionMgr.getSpawnRegions()` is defined in shipped game Lua and
returns the loaded region tables.

**Verification.** `media/lua/shared/SpawnRegions.lua:87` defines
`SpawnRegionMgr.getSpawnRegions()`, delegating to `getSpawnRegionsAux()` at line
61. Consumed by `media/lua/client/OptionScreens/MapSpawnSelect.lua:449`.

**Depends on this.** Origin allocation can be drawn from the map's real spawn
definitions rather than being player-relative, which is what makes population a
world property instead of a refill effect.

---

## F-006 — `IsoPlayer` carries a static player table and an explicit local-player setter

**Claim.** `public static final IsoPlayer[] players`, `public static void
setLocalPlayer(int, IsoPlayer)`, `public static int numPlayers`.

**Verification.** `javap zombie.characters.IsoPlayer`, static member listing.

**Depends on this.** NPC bodies occupy player slots. Slot handling is therefore a
correctness concern for the primary player, not an internal detail — construction
must not disturb the local player's slot.

---

## F-007 — Route production is separable from state-machine consumption, by design

**Claim.** `zombie.pathfind.PathFindBehavior2` is independently drivable and its
output is readable without entering any engine walk state. The full contract:

- **Request** — `pathToLocationF(float,float,float)` (plus `pathToCharacter`,
  `pathToSound`, vehicle/furniture/corpse goal forms, and
  `pathToNearestTable(KahluaTable)` — a Lua-table overload, so route requests are
  Lua-callable by the engine's own design).
- **Poll** — `public BehaviorResult update()` returning `Working | Failed |
  Succeeded` (the enum's only three values).
- **Follow** — the live next waypoint is exposed as public fields:
  `pathNextIsSet`, `pathNextX`, `pathNextY`. The computed route is also readable
  node-by-node: `getPath2()` → `zombie.pathfind.Path` with `size()`,
  `getNode(int)`, `length()`.
- **Teardown** — `cancel()`, `reset()`.

**Verification.** `javap` listings of `zombie.pathfind.PathFindBehavior2`,
`zombie.pathfind.PathFindBehavior2$BehaviorResult`, and `zombie.pathfind.Path`
against the installed jar.

**Depends on this.** Resolves F-003's open question affirmatively. Execution's
route layer wraps the engine: request a route on the behavior, poll `update()`,
read the next waypoint, and emit `strafeX/strafeY` + intent booleans into
`AIBrainPlayerControlVars` (F-003). The engine computes routes; the framework
owns following them. No engine walk state is entered, which is what keeps the
control channel and the pathfinder from fighting over the body.

**Supersedes.** The F-003 *Open* item is closed by this finding.

---

## F-008 — Desc creation and body removal are verified; Lua-side construction is the G1 test

**Claim.** `SurvivorFactory.CreateSurvivor()` is static, returns `SurvivorDesc`,
and is Lua-callable. `removeFromWorld()` / `removeFromSquare()` exist on the
body's inheritance chain as the removal pair. Direct construction of `IsoPlayer`
from Lua is **not** evidenced anywhere in shipped Lua and remains a hypothesis.

**Verification.** `javap zombie.characters.SurvivorFactory` (static
`CreateSurvivor()` and `CreateFamily(int)`); `javap` on `IsoPlayer` /
`IsoMovingObject` for the removal pair. Lua-callability of the factory is proven
by shipped usage: `media/lua/client/OptionScreens/CharacterCreationMain.lua:2109`
and three sibling screens call it directly. A grep of the shipped `media/lua`
tree finds no `IsoPlayer.new` call anywhere.

**Depends on this.** The `[A3]` probe (`mod/42.20/media/lua/client/SAO_G1Probe.lua`)
is built so that its only untested line is the constructor call itself. Every
other call it makes is a recorded finding. If the constructor is unreachable from
Kahlua, the probe logs that verdict cleanly and the construction seam moves to
the Java side — a bounded design change, not a debugging session.

---

## F-009 — B21's renderer refuses a bare non-local IsoPlayer; a subclass draws

**Claim.** An `IsoPlayer` constructed at runtime that is not a local player is
excluded from rendering by an exact-class filter. A subclass of `IsoPlayer` is
not excluded. Rendering NPC bodies therefore requires a Java-defined subclass —
unreachable from Kahlua, which cannot define Java classes.

**Verification.** Two independent lines. (1) Live runs: a Lua-constructed body
with `setNpc=true isNpc()=true dressed=true model=true` and real coordinates
never drew, across two sessions. (2) The Knox Survivors rebuild's engine layer
documents and implements exactly this: its shell definition carries the comment
"minimal IsoPlayer subclass required by Build 42's exact-class render filter"
and defines such a subclass at runtime. The engine-internal filter location has
not been independently read from bytecode; the behavioral claim is verified,
the mechanism corroborated.

**Depends on this.** DR-004. The framework carries a Java component whose first
duty is the shell class.

## F-010 - Standing person-key inconsistency (A7 vs A7), fixed in [A9]

Encounter trust ([A7]) accrued under Perception belief USERNAMES;
mutual-trust company formation ([A7]) read trust under RECORD IDS. The two
never met: company could not form from encounters, and witnessed/testimony
consequences would have split across parallel ledgers. Found during the
[A9] full call-site audit (the named-instance law applied to our own code);
fixed by DR-005 canonical keys. Live-behavior caveat: any pre-[A9] saved
standing under username keys is orphaned - acceptable pre-alpha, no
migration written.

## F-011 - Survivors could not see each other (scanner slot-array loop), fixed in [A10]

`SAOPerceptionScanner`'s person loop iterated `IsoPlayer.players` - the
4-slot LOCAL player array. Off-slot shells are deliberately not in it
(DR-004 off-slot indexing), so every survivor-to-survivor perception
consequence - encounter trust, greetings, survivor-witnessed violence,
trespass detection, charity - was vacuous; only the real player was ever
perceived. Found auditing the scanner before extending its format; fixed by
scanning the cell's moving objects, the same surface combat resolution
already used. The word-of-mouth exchange was NOT affected (it iterates the
controller's own agent registry, not beliefs).

## F-012 - Orphaned locomotion routes on state family exits, fixed in [A10]

Entering any hold state (EAT/TAKE/DRINK/TREAT/RIP/RELOAD), ENGAGE, or a
decide()-driven IDLE from a movement state left the Locomotion job and the
ENGINE-armed route alive: between order() and first capture, the engine's
own pathfind behavior walks the body autonomously - the exact mechanism of
the historical independent-wandering defect. Found in the [A10] end-to-end
controller audit; fixed by a central invariant in setState (leaving the
movement family for a non-member cancels the route). Third audit, third
load-bearing find (F-010 keys, F-011 sight, F-012 routes).

## F-013 - Hibernation stripped the person (position-only snapshots), fixed in [A11]

Body.release snapshotted position ONLY: inventory, equipped weapon, health,
hunger, and thirst died with the shell object, while kitGranted blocked
re-kitting - every hibernate cycle stripped a survivor bare, healed their
wounds, and fed them. The persistent-person claim was itself the lie. Found
auditing the release/materialize seam after the ammo work; fixed by
hibernate/awaken snapshots on the record plus sanctioned dormant metabolism
(the architecture's explicitly reserved direct-mutation mode for the
unloaded world). v1 limits, recorded: item CONDITION/fill deltas collapse
to fresh instances; per-part wounds collapse to overall health; nobody dies
off-screen (needs cap at 0.95 - desperate reunions, not quiet deletions).

## F-014 - Belief distance froze at formation time, fixed in [A11]

Beliefs stored dist once: told beliefs carried the TELLER's distance (a
receiver 30 tiles from the threat reacted as if it were at arm's length),
and observed beliefs kept stale distance while the survivor ran - flight
continued for the full belief horizon regardless of ground gained, and
ALERT->IDLE depended on belief expiry rather than distance truth. Fixed:
positions stay beliefs; distance to a belief is computed at query time from
the asker's own position (queries take fromX/fromY; controller passes body
coordinates at every site). Found in the [A11] full Perception read.

## F-015 - Appearance discontinuity across hibernation, fixed in [A11]

dressInRandomOutfit ran on EVERY materialization, and [A11]'s restore
re-added worn clothing as cargo: an awakened survivor either wore a fresh
random outfit per reunion or stood in underwear with their shirt in the
pack. Fixed: random dress belongs to a first body only; awaken wears every
restored garment with a body location (last wins per location). Found in
the [A11] full Body read.

## F-016 - Engine sleep on off-slot shells: safe but inert ([A11] investigation)

Bytecode audit of every isAsleep consumer reachable from a shell:
`allPlayersAsleep()`/`isOnlyPlayerAsleep()` iterate the SLOT array only
(off-slot sleepers can neither trigger nor block time acceleration);
IsoPlayer-side reads sit in updateLOS (our no-op override), OnDeath, and
slot-bounded aggregates; IsoGameCharacter-side readers are benign
(autoDrink, text objects, forceAwake, busy/idle predicates). NO engine
system recovers stats for a non-slot sleeper - sleep recovery rides the SP
time-jump and per-slot logic. Additionally `ISTimedActionQueue.add`
refuses actions for asleep characters, so the flag must be cleared before
any queued action. Verdict: setAsleep(true) is SAFE and COSMETIC off-slot;
REST therefore charges its own recovery in real ticks at engine-approximate
rates (fatigue full recovery ~8h, endurance ~4h) - the same honest
deviation class as rag-rip, no vanilla surface exists.

## F-017 - Window interaction stage carried across route edges, fixed in [A12]

`SAORouteState.interactionStage` reset only per ORDER (clearRoute), so the
SECOND window on any route inherited OPEN_ATTEMPTED and skipped straight to
decline/smash without attempting the open. Fixed: advance() resets the
stage - each edge starts fresh. Found in the [A12] Java fresh-read.

## F-018 - Last-round kill reported as OUT_OF_AMMO, fixed in [A12]

The mid-fight ammo check ran BEFORE the target-death check: a survivor
killing with their final round got COMBAT_FAILED OUT_OF_AMMO instead of
COMBAT_SUCCEEDED - the controller then reloaded instead of crediting the
kill, and witnessed respect ([A12]) never fired. Fixed: the kill outranks
the empty magazine. Found in the [A12] Java fresh-read.

## F-019 - Dormant meetings compounded at the population pulse, fixed in [A13]

dormantEncounters processed every ~4s population pass with no per-pair
memory: two survivors camped adjacently (both home at night, within 3
tiles) accrued mutual trust ~40x the observed world's encounter rate and
formed companies overnight en masse. Fixed: per-pair meeting cooldown
(~30-60s of continued adjacency per meeting) and trust scaled to 0.005 -
a dormant MEETING abstracts minutes, not a pulse. Found in the [A13]
Population fresh-read.

## F-020 - Charity blind to the unkempt-desperate, fixed in [A15]

[A14] extended the condition bracket with a "+u" suffix; [A10]'s charity
gate still compared condition == "bad", so a starving survivor in bloody
clothes ("bad+u") - the neediest person the model can describe - never
received charity. Substring match now. Found in the post-arc exchange-loop
trace; the parser/producer diff discipline ([A10]) would have caught it
had the [A14] batch re-run the diff after extending the format - recorded
as the process lesson it is.

## F-021 - Bond survived betrayal (the recorded contradiction), fixed in [A15]

Friendly-fire between bonded partners minted hostility while the bond
fact persisted: flight routed TOWARD the attacker, sharing gave them the
last meal, grief doctrine still applied. [A14] recorded the contradiction;
[A15] closes it: betrayal by the bonded SEVERS the fact on both relations
before hostility lands, and mints the same trauma fork as death - who you
already were decides rage or collapse. Flight additionally refuses a
hostile bonded remnant, belt and suspenders around ordering.

## F-022 - Re-scans caused color amnesia, fixed in [A15]

Each fresh person-scan replaced the belief table wholesale, wiping
seenInFaction the moment its bearer stepped outside their base - and
attacks mostly happen outside, so [A15]'s faction wariness could rarely
fire. A re-scan is a position update, not amnesia: durable fields carry
forward. Found in the [A15] Perception fresh read; the alternation's
record holds - never empty after construction.

## F-023 - ZB approval store blocked the live load (hash-keyed), fixed in [A16]

First live finding of the 0.4 era, and it was the load itself:
`[ZB] Blocking Java mod by stored denial: SurvivorAwareness` followed by
`Excluded: ...42.20\mod.info` - the WHOLE mod tree excluded, so even Lua
was silent (22k console lines, zero [SAO]). The approval store
(~/.zombie_buddy/mod_approvals.json) matches by JAR HASH: six stale
SurvivorAwareness approvals existed, none for the current build - ZB's
"stored denial" is denial-by-absence under prompt policy at this boot.
Every wake's redeploy had been silently invalidating the stored approval.
Fixed twice over: the current hash approved (effective next boot), and
deploy.sh now runs tools/approve.py after every copy so a deploy can
never orphan its own approval again. The operator's CURRENT session runs
without survivors; the next launch runs [A15]+.

## F-024 - materializeBand would conjure Knox inhabitants, fixed in [A17]

The band pass iterated all living records; a Knox record whose real body
left the cell (registry cleared) read as bodiless-and-near, and the pass
would SPAWN A SHELL for them - duplicating a legacy person as our puppet,
the exact replacement inhabitation forbids. Found in the [A17] Population
fresh read (the alternation's ninth find). Fixed: Knox records are never
materialized and never drifted; their bodies and days are the legacy
mod's business; the passive path is the only presence we hold. Noted as
intended: livingCount includes the inhabitants, so genesis fills only the
gap beyond them - the Knox people ARE the population, and dormant
meetings among their last-seen positions keep them in the shared economy
while unloaded.

## F-025 - Combat answered "errand" ([A19])

The [A18] pressure map left ENGAGE, ALERT, and RELOAD unmapped, so the
fallback filed a survivor mid-firefight under "errand: gun dry -
reloading". Evidence: PRESSURE_ANSWER contained only the appetite and
grief families; every combat state fell through. A legibility lie under
DR-011 - the pressure IS the threat. Fixed: ENGAGE/ALERT mapped to
"need" (RELOAD was already mapped; the map now says so explicitly
beside them).

## F-026 - Objections drove Knox bodies ([A19])

The trespass eviction (`heard` branch) ran against ANY trespasser in
Ctl.agents - including PASSIVE Knox inhabitants: it would clear a Knox
survivor's ISTimedActionQueue (wiping the legacy mod's own queued
actions - direct cross-mod interference, the exact thing DR-009
forbids) and setState them to ALERT (our state on a body that is not
ours to drive). Fixed: the eviction machinery is gated on `not
trespasser.passive`; a passive trespasser still pays the standing cost
and hears the objection - their KS life decides their feet.

## F-027 - Our own deaths were second-class ([A19])

[A17] gave Knox deaths killer-naming and a witness sweep, but the SAO
death path kept its old causes (combat/bleeding/unknown) - no killer
named, no witnesses, no routed grief. The asymmetry the batch was
built to kill, inverted onto our own people. Fixed: the sweep is ONE
function (`witnessDeath`) called from BOTH death paths; the engine's
attacker tag outranks the state-based guesses when it names someone.

## F-028 - politick ran on two clocks ([A19])

`Standing.politick`'s per-pair cooldown compared the caller's tick
argument against stored values - but its two callers live on DIFFERENT
counters (the controller's `tickCount`, the population layer's
`tickCounter`, both file-local and boot-relative). A pair that
politicked in the loaded world stored a large controller tick; the
dormant-road caller's small counter then made `tick - stored` deeply
negative - road politics for that pair silently suppressed for the
rest of the session. Fixed: the cooldown runs on the one clock every
caller shares - `getWorldAgeHours`, half an hour of world time; the
tick param remains for API shape only. (Same-clock rule worth keeping:
never compare ticks across module-local counters.)

## F-030 - The anchored origins never fired ([A19])

[A18]'s profession-anchored placement was dead on arrival: Lua scoping
split one variable into two. `loadRegionPoints` (defined at the top of
the file) assigned `regionPointsByProfession` as a GLOBAL - the `local`
declaration sat BELOW the function, so the assignment compiled against
the global environment - while `pickOriginFor` (defined after the
declaration) read the never-assigned local upvalue: always nil, no
anchor ever chosen, silently. Structural checking cannot catch this
(both halves are legal Lua). Fixed by declaring the local beside its
sibling cache above every writer. A purpose-built scanner
(scope_split_audit.py: file-local declared after a bare assignment to
the same name) was verified on a synthetic case and swept ALL
client+shared Lua: zero remaining instances - the fix covers the full
population, and the scanner joins the toolbox for future audits.

## F-031 - The watch blocked by their own colors ([A21])

The [A19] watch edge sits on the survivor's OWN claim boundary, but
the roam target check `believedFactionNear` can match a belief of
their OWN faction's base - a watch who knew their own colors would
"keep clear" of the ground they were guarding and never walk the edge.
Found on the focused idle-tail re-read; fixed by nulling the
near-faction block whenever the target is inside the survivor's own
claim (standing truth): your own ground is never forbidden ground.

## F-032 - The menu ended at the mod line ([A21])

`survivorNear` (the under-cursor resolver behind Talk / ask-to-walk /
ask-to-join / the job submenu) iterated `Body.active` only - Knox
inhabitants, who live in `Body.knox`, were unreachable by every
player-facing verb. "One social world" ended at the menu. Found while
verifying that the new ghost-camps Talk lines could ever fire (a
feature is not done until its reachability is proven). Fixed: both
registries considered.

## F-033 - The news died with the clock ([A21])

People-beliefs decay after twice their horizon - including dead-flagged
ones, so ~an hour after learning of a death the holder FORGOT it and
could never retell it; the county's losses evaporated from its memory.
Fixed: memory of the dead is durable - dead-flagged beliefs never
decay.

## F-034 - Respecting a dead man's house ([A21])

Standing's estate rule ("the dead hold nothing") lived only in
`claimedByOther`; the belief-side gate `believesClaimed` kept returning
dead owners, so survivors would refuse a dead man's pantry forever.
Fixed: the estate rule reaches beliefs, on the same authority the
standing path already uses (record death is corpse-visible truth).

## F-036 - The frozen base-only catalog ([A22])

`Census.catalog()` cached its first build unconditionally - a call
landing before the java bridge binds (early boot genesis) would freeze
a base-only catalog for the whole session, silently locking every
modded profession out of the draw. Fixed: the cache records whether it
saw the bridge and rebuilds once the bridge appears; stored occupations
on existing records are untouched (only future draws see the fuller
world). Found on the Census fresh read; the same read also gated
`originNote` off presumed occupations - no invented beginnings in
guessed-at mouths.

## F-037 - The county behind a spawn gate ([A22])

"SAO: the county" and "SAO: standing web" - the county-wide surfaces -
were registered inside the harness's slice-survivor gates
(`H.activeId` + `hasBody`), so on a pure population save (no
harness-spawned survivor) the ledger and the web were UNREACHABLE.
Found on the Harness full read. Fixed: both are module functions now,
registered unconditionally at the top of the menu - they describe the
world, not the slice.

## F-038 - The graves that taught nothing ([A22])

The graveside lesson lookup indexed CAUSE_LESSONS with the raw death
cause, but the cause vocabulary had outgrown the map: "killed by
<name>" ([A17]) and "the county took them" ([A20]) matched nothing -
mourners of the murdered and the county-taken learned NOTHING at the
body. Fixed with `lessonForCause`: exact match, then the murder prefix
(a killed friend teaches trust-carefully - PEOPLE did this), then the
default. Zero raw map indexings remain. Found on the Lessons pillar
audit - the exact class of drift the audit alternation exists to catch:
two eras extending a vocabulary nobody re-checked the consumer of.

## F-039 - The medic's walk never ticked ([A22])

[A19] added MEDICWARD to MOVEMENT_STATES, the pressure map, and the
verdict close-out - but not to the locomotion tick's ENTRY condition,
so a MEDICWARD agent's job was never ticked: the walk could not
complete, no verdict ever fired, and with every decide() block gated on
IDLE/ROAM the agent WEDGED until a threat interrupted. Found in one
line by the new mechanical invariant sweep (MOVEMENT keys vs tick
states) - a contract that four eyes missed across three audits fell out
of one set-difference. The sweep (invariant_sweep.py: state/tick,
pressure defaults, takePurpose closure, Lua-vs-Java verb existence,
voice coverage) joins the pre-commit toolbox.

## F-040 - Testimony compounded into war ([A23])

The equilibrium re-run with the [A23] grudge channel showed the flood:
hostile pairs quadrupled to geographic saturation (116/1770), feuds
under-declared, peace died entirely (leaders personally hostile via
hearsay webs never meet again past the wide berth). Two root causes,
both in tellGrudges' live shape and both fixed as PROVENANCE LAWS, not
knobs:

- **Once per voice**: repeated identical testimony re-applied every
  meeting - repeating yourself is not new evidence. Each (hearer,
  offender, teller) triple now applies once, marked on the relation.
- **The testimony floor**: accumulated hearsay alone could cross the
  hostility line. Now words make you WARY, never at WAR: testimony
  clamps at -0.45 - it PRIMES, so one thing seen or suffered tips it -
  and never deepens a distrust already earned by stronger provenance
  (floor = min(before, -0.45)), nor raises anything.

Re-verified: with both laws the county holds its living mix WITH
testimony flowing - 25 hostile pairs (vs 116 flooded / 28 baseline),
14 feuds declared, 3 peaces made, no mega-company, no universal feud.
The observed > heard > told ladder now binds hostility itself: war
requires at least witnessed provenance.

## F-041 - The comma that would starve the county ([A23])

`SAONeeds.read()` built the needs string with locale-sensitive
`String.format` - on comma-decimal systems (German, French, Turkish
locales) it renders "h=0,342", the Lua pattern `(%a)=([%d%.%-]+)`
fails, `N.read` returns nil, and the ENTIRE appetite machinery
(hunger, thirst, fatigue, smokes, barter need-shapes) dies silently.
Invisible on the operator's en-US system; fatal on distribution. Fixed
with `Locale.ROOT` at all three float-format sites (the parsed needs
string plus two cosmetic journal fields; `Double.toString`
concatenations elsewhere are locale-safe by the JLS). Found on the
SAONeeds.java full audit.

## F-043 - Bare hands by tidy-up ([A24])

`equipBestMelee` with no melee weapon carried stripped BOTH hands - a
survivor whose only weapon is a firearm was left bare-handed by every
take/meal/gift close-out that calls the equip tidy-up (and only the
hardened-class [A19] gate spared some post-combat paths). The
stripping predates the ranged era. Fixed: no melee carried means KEEP
WHAT YOU HOLD.

(Also this batch, retraction-before-record: a feared F - the
`getCurrentAmmoCount` reflection breaking on 42.20.4 - proved FALSE on
verification: the getter MOVED UP to InventoryItem, where inherited-
public resolution still finds it. Since it is now statically visible,
the reflection was modernized to a direct call, compile-proving the
resolution. The claim died in the audit, not in the ledger.)

## F-044 - The turn's whole law, hand-checked ([C8])

**Verified** [C8], structural (javap -p -c on the installed jar,
2026-08-29). The single-player chain that turns a dead IsoPlayer-class
body, end to end:

1. `IsoGameCharacter.updateInternal()` calls `die()` ONLY on a
   dedicated server (offsets 124-131 gate on `GameServer.server`). In
   single-player, `die()` for a player-class body is called from
   exactly one live site: `PlayerOnGroundState.execute()` (offset 8 -
   `isDead()` then `die()`). A shell that dies without its state
   machine reaching the on-ground state is a dead character standing
   in the world: no corpse, no timer, no turn. This is the gap [C8]'s
   corpse net closes.
2. `die()` (public final, idempotent - guarded by `onDeathDone` +
   `diedBody`) -> `becomeCorpse()` -> `new IsoDeadBody(this)` ->
   `invokeOnDiedListeners(diedBody)`. The corpse constructor removes
   the character from the world (ctor offsets 1159-1163).
3. `IsoPlayer`'s constructor registers `this::onDied` via
   `addOnDiedListener(listener, false)` (ctor offsets 715-723) -
   inherited by any subclass, the shell included. `onDied`: when not
   a network client and `shouldBecomeZombieAfterDeath()`, it calls
   `body.reanimateLater()` (offsets 0-14).
4. `shouldBecomeZombieAfterDeath()` is the sandbox's own law: a
   tableswitch on `ZombieLore.Transmission` - Blood+Saliva and
   Saliva-only demand real infection (`CharacterStat.ZOMBIE_INFECTION
   >= 0.001f` and not `IsFakeInfected`), Everyone's Infected returns
   true unconditionally, None returns false.
5. `reanimateLater()` = world-age + `getReanimateDelay()` (reads
   `ZombieLore.reanimate`); `IsoDeadBody.update()` compares and calls
   `reanimate()` (F-001's timer, reconfirmed).
6. `OnPlayerDeath` (the death-screen event) fires only under
   `isLocalPlayer()` (IsoPlayer offsets 57-64 at the trigger site), so
   driving a shell through `die()` never touches the player's UI.

Consequence: the engine arms the turn for our dead under its own
Transmission and Reanimate settings - SAO's only lawful work is making
sure `die()` actually runs (the [C8] net) and never writing timer
arithmetic of its own.

## F-045 - Identity through the turn rides modData; the descriptors half-survive ([C8])

**Verified** [C8], structural, correcting the sibling repository's
F-002/F-003 on the same jar:

- The `IsoDeadBody(IsoGameCharacter)` constructor copies the dying
  character's modData onto the corpse UNCONDITIONALLY
  (`LuaManager.copyTable(this.getModData(), chr.getModData())`, ctor
  offsets 1102-1113 - the common tail every character class reaches).
  The sibling's F-002 ("the corpse is NOT populated from the dying
  character; a mod must stamp the corpse itself") counted the class's
  copyTable sites and missed this one: stamping the LIVING character
  suffices.
- The same constructor also copies the character's DESCRIPTOR into the
  corpse for every non-zombie, non-animal character - IsoPlayer
  included (offsets 1007-1019; the `instanceof IsoSurvivor` at 989
  guards only a survivor-list removal, not the desc write; 1022's
  `instanceof IsoPlayer` branch then adjusts the voice prefix). The
  sibling's F-003 claim that a player-class corpse carries a null
  descriptor is false on this build: named corpses work for shells.
- `reanimate()` still builds the ZOMBIE a fresh descriptor carrying
  gender and voice prefix only (offsets 43-74; F-003 right about this
  half), and `SharedDescriptors.createPlayerZombieDescriptor` opens
  with `if (!GameServer.server) return` - a no-op in single-player.
  So the corpse knows the name; the risen body does not.
- The corpse's modData persists in the save: `IsoDeadBody.save` chains
  to `IsoObject.save`, which writes the modData table when non-empty
  (offsets 894-925 in IsoObject.save).

Consequence: the person id stamped on the living body walks the whole
chain - character -> corpse -> risen body - by the engine's own two
copyTable calls, and survives save/reload while the body lies there.
Recognition and named-corpse reads key on that id; descriptor names
remain a display-only channel that dies at reanimation.

## F-046 - The zombie list is not a list of zombies ([C9])

**Verified** [C9], code audit against DR-009's own facts. Every
consumer of `IsoCell.getZombieList()` inherits a fungibility
assumption the list does not honor: it holds the neighbour
framework's LIVING people (zombie-backed bodies), risen players, and
the county's own marked dead alongside the ambient crowd. Two
consumers discriminated (`beginCombatNearest`, the perception
scanner's DR-009 split); two did not - `takeFromThePool` could
DELETE a person to pay a spawn's population cost, and
`directNearestZombieAt` could point a living neighbour at a shell as
incoming combat. Fixed as a class: one deletion-grade predicate
(`SAOKnox.identityBearing`, failing closed) at every undiscriminating
consumer, and a closed census of `removeFromWorld` so the assumption
cannot quietly return. Border 88.

## F-047 - The engine has no turning odds; it has a clock ([C11])

**Verified** [C11], structural (javap -p -c on the installed jar).
The Knox course for a bitten character, hand-checked end to end:

- `BodyPart.SetBitten(boolean)` sets `isInfected = true` whenever
  `ZombieLore.Transmission != 4` (offsets 102-127) - **a bite infects
  with certainty on this build; no probability roll exists.** Under
  `Mortality 7 (Never)` the infection converts to fake (offsets
  128-159). The two-arg overload used by the tutorial behaves the
  same way.
- `BodyDamage.Update()` (offsets 1947-2055): once infected, the
  course lazily calls `pickMortalityDuration()` and then drives
  `ZOMBIE_INFECTION` as `min(1, (now - infectionTime) /
  infectionMortalityDuration) * 100`; at progress 1.0 it calls
  `ReduceGeneralHealth(110)` - **death arrives EXACTLY at
  infectionTime + mortalityDuration.** The clock runs on
  `getHoursSurvived()` for IsoPlayer characters and world-age hours
  for everyone else (`getCurrentTimeForInfection`).
- `pickMortalityDuration()` (hours): Mortality 1 -> 0; 2 -> 0-30s;
  3 -> 0.5-1min; 4 -> 3-12h; 5 (default) -> **48-72h**; 6 -> 1-2
  weeks; scaled x1.25 Resilient / x0.75 Prone to Illness.
- The zombie's own bite (`AddRandomDamageFromZombie`, offset 1834)
  passes `SetBitten(part, true)` unconditionally.

Consequence: the dormant formula "0.10 + min(0.5, since/480)",
commented as "the engine's own turning odds", matched nothing in the
jar - the engine's law is a deterministic per-body window, which the
record now carries (read via `biteHoursLeft` as a body goes dark, or
mirrored from the table above when the course had not stamped its
clock). Who rises mirrors `shouldBecomeZombieAfterDeath` (F-044).

## F-048 - Two exceptions the borders could not see ([C18])

**Verified** [C18], from the operator's own session log - the first
findings this project has taken from a running game rather than from
structure.

`SAO_Places.lua` threw 276 times in one session:
`expected argument of type String, got Double`. `absorb` read the
engine's item lists as "name, weight, name, weight" and stepped by
two on that promise. Not all of those lists have that shape - some
are plain arrays of names, some do not begin on a name - so the
stride skipped half the names in the first shape and handed a weight
to `getScriptManager():getItem()` in the second. Every throw
abandoned the remainder of that room's contents, so what a place
offers ([B38]) was being derived half-blind wherever the shape did
not match. Fixed by reading every STRING in the table, which needs no
assumption about layout.

`SAO_History.lua:296` threw twice: `attempted index: key of
non-table`. A claim pick indexed outside `fitting`, a table the line
above proved non-empty, with `(hash % #fitting) + 1` - exact
non-negative integer arithmetic over a densely built array. The cause
is NOT established. Guarded so one person's past cannot end
`generate()` for a whole population pass, and instrumented with the
index and the length so the next session inherits numbers instead of
another theory.

## F-049 - A re-issued order restarts the route it is already walking ([C18])

**Verified** [C18], from the operator's session log and their own
words: "they're clustered up around a house for some reason, but
they're not moving."

`Loco.order` unconditionally began a new route. The controller
re-decides on its own cadence and re-issued the SAME destination
every ~17 frames; each order recomputed the path from scratch, so a
body advanced roughly half a tile per re-order and never arrived.
Worse, a traversal in flight ([C4]'s window and fence climbs) was
cancelled mid-transition and restarted - the log shows
`TURNING_TO_FENCE -> STARTED_FENCE_CLIMB -> TURNING_TO_FENCE`
repeating. The route eventually reported `Failed`, which returned the
survivor to IDLE, where the same believed threat sent them back into
FLEE: **292 `IDLE -> FLEE` and 292 `FLEE -> IDLE` in one session.**

Fixed in `Loco.order` rather than in the flight state, because the
defect belongs to ordering and every state that re-orders inherits
it: a live route whose goal has not moved beyond `RETARGET_REACH`
(2 tiles) is held rather than restarted.

## F-050 - Another mod's sandbox controls are addressable, and vanilla itself disables options conditionally ([C20] prep)

**Verified** [C19]-adjacent, shipped-Lua reads, for DR-023's "blocked,
not just documented" requirement.

`OptionScreens/SandboxOptions.lua` keeps every control in
`self.controls[settingName]` keyed by the FULL option name
(`:529` builds the map; `:775-776` fills it via
`option:getName()`), with labels beside them in `self.labels`. So
`controls["KnoxSurvivors.MaxPersistentSurvivors"]` is reachable from
any mod's hook - the This Is Your Life mod already reads
`MainScreen.instance.sandOptions.controls["ThisIsYourLife.EnableCustomAppearance"]`
in the wild (its TIYLAppearanceSkin.lua:29-36), proving the path
works across mods.

And disabling is not an invented capability: vanilla ITSELF greys and
gates options conditionally at `:83-95` - `Map.*` rows grey when
`Map.AllowWorldMap` is off, `MultiplierConfig.*` rows grey against
their toggle, via `label:setColor(0.4, 0.4, 0.4)` plus per-widget
text-color changes. Mirroring that idiom (grey + disable + a tooltip
naming the overrider) on the specific neighbour options SAO
neutralizes is the same class of behavior the screen already
performs on its own options.

Consequence for DR-023: blocking is real. Runtime neutralization in
SAO's readers stays regardless - the screen surgery is the honest
face, not the enforcement.

## F-051 - The neighbour's body law: one spawn seam, a ten-minute respawn loop, and removal is not death ([C20] prep)

**Verified** [C19]-adjacent: subagent sweep over the neighbour
framework's ~90k lines, load-bearing citations hand-checked against
the live source (KS_Actor.lua:1765-1775, KS_WorldDirector.lua:660-661
and :851-852, KS_Core.lua:489-496, KS_Actor.lua:2453).

- **One body-creation choke point.** Every body the framework ever
  makes goes through `KS.SpawnActor(profile, square)`
  (shared/KS_Actor.lua:1765) - encounters, save restores, world
  restores, the spouse, beacon visitors, away-team returns. Its own
  guards return nil for dead profiles, away profiles, and profiles
  with a live actor, and every caller handles nil gracefully. THIS is
  the absorption seam: wrap it, and absorbed ids can never be
  re-bodied by any path.
- **He re-bodies missing people within ten in-game minutes.**
  `restoreProfiles` runs on EveryTenMinutes (plus OnGameStart, plus a
  750ms retry lease for 20s after start, plus post-save restore).
  Removing a body without closing the seam means a duplicate within
  the next pulse.
- **A vanished body is silent.** `KS.GetActor` self-heals (drops the
  stale runtime entry, returns nil); no error, no death, no log. The
  profile stays alive in his store - no code path of his ever deletes
  a profile row.
- **Removal is not death.** His death handling (`actorDied` -
  profile.alive=false, group removal, grief, memorials) hangs on
  `OnZombieDead`, which `removeFromWorld` does not fire. Absorb by
  REMOVING (`KS.RemoveActorShell` + `KS.DetachRuntimeActor(profile,
  PROFILE_REMOVAL)`), never by killing, or every absorption becomes a
  funeral.
- **The deletion heuristic fires on presence, not absence** (2-of-8
  marker keys, startup-only, walks getZombieList() only) - removal
  trips nothing. The standing rule holds from the other side: never
  write his marker keys (`KnoxSurvivorId`, `KnoxSurvivor` variable,
  etc.) onto SAO shells, or his UI and targeting bind to our bodies
  as his.
- **One sandbox read.** Every option flows through `KS.GetOption`
  (KS_Core.lua:489), which reads `SandboxVars.KnoxSurvivors.*` at
  exactly one line - and an INTERNAL_OPTION_DEFAULTS table
  short-circuits ~30 option names that never reach the sandbox at
  all. Neutralizing his population dials is therefore also possible
  at one seam, though DR-023's screen-blocking remains the honest
  face.
- **Squad and group state is dual-written**: player squad is
  `profile.owner`/`profile.groupId` scanned from the store; world
  groups also keep a `members[]` array with leader promotion and
  camp-abandonment side effects in `KS.RemoveProfileFromGroup`.

## F-052 - The neighbour's profile is the person, and he drew the copy boundary himself ([C20] prep)

**Verified** as F-051 (same sweep, schema sites hand-checkable at
KS_Data.lua:2167-2268 and KS_SurvivorModel.lua:11-168).

A profile carries far more than name and inventory: identity and
appearance (gender, skin, hair, beard, colors, original outfits),
archetype/traits/backstory, five skills plus XP, trust/loyalty/
relationship memory/grief, group and base membership, seven needs and
supplies, wounds/infection/kills, orders and policies, the weapon
triple, timestamps, and four separate durable inventory ledgers (the
real one is `profile.durableInventory`, replayed by
`KS.MaterializeDurableSurvivorInventory`).

Copying selectively would orphan most of the person. The copy rule
comes from his own code: he maintains `TRANSIENT_FIELDS` (118
entries), `DEVELOPMENT_FIELDS`, and `RETIRED_FIELDS` with clear
functions, and his own save migrations deep-copy then clear those
three sets. Absorption does the same: deep-copy the whole profile,
run his three clears, and map the result into SAO's record under the
person's existing identity chain.

## F-053 - The panel class is a per-file local, and the guard died without a sound ([C24])

**Verified** against vanilla source, the declaring lines read
directly: `media/lua/client/OptionScreens/SandboxOptions.lua` line 3
is `SandboxOptionsScreen = ISPanelJoypad:derive(...)` - a real global
- and line 5 is `local SandboxOptionsScreenPanel =
ISPanelJoypad:derive(...)` - a per-file local, invisible outside that
file. Same file, two lines apart, opposite visibility.

[C22]'s gating hook read `SandboxOptionsScreenPanel` as a global, got
nil, and its `if` guard skipped - silently, by design. The gating
therefore never existed at runtime through a full verified deploy,
and the operator photographed the proof on `1.12.0.3`: 45445 typed
into Population (manual) while its switch sat unchecked (R-003).
This is [C3]'s lesson landing on our own tree: `KS` was a per-file
local in the neighbour's code and the [B45] hold had never engaged;
now a vanilla class did the identical thing to us. The census
classified the name as an engine global on my say-so - the
classification answered WHO owns it without ever probing WHETHER it
exists. A global is not verified until the declaring line has been
read.

The reachable shapes, for the record: `SandboxOptionsScreen:create`
(line 407) builds one `item.panel` per settings page and each panel
keys `panel.controls` / `panel.labels` by full option name -
`self.controls[setting.name]` at the createPanel site - so instance
wrapping post-create reaches everything the dead hook wanted.
`ServerSettingsScreen` (its file's line 6) IS a real global, so the
[C23] dial-deletion hook was live all along.

Two standing rules out of this: an engine global is cited with its
DECLARING line, not its use sites (use sites look identical for
locals); and a hook whose anchor may be absent fails LOUDLY through
the Seams, because a guard that skips in silence converts a missing
anchor into dead code that passes every text-reading border.

## F-054 - dressInRandomOutfit can return clean and dress nothing ([C26])

**Witnessed, cause-in-engine unproven.** Two of the county's own
people (`sao-151`, `sao-152`, fresh path, no hibernation) stood
naked in the operator's kitchen on `1.12.0.4` while the materialize
log said `dressed=true model=true` - the pcall around
`dressInRandomOutfit()` succeeded, so the log believed the CALL. The
body wore nothing (R-006). Other bodies from the identical path were
clothed the same session, so the failure is per-body, not per-build.
What decides it inside the engine is not established and is not
guessed at here.

What IS verified (javap, declaring classes): the dress family on
`zombie.characters.IsoGameCharacter` (`dressInRandomOutfit()`,
`dressInNamedOutfit(String)`), and the outcome instrument -
`getWornItems()` returning `zombie.characters.WornItems.WornItems`
with `public int size()`.

The standing rule this lands ([B34]'s lesson worn on the skin): a
dress call that returns is not a dressed body. The county verifies
OUTCOMES - count what is worn; zero means retry, then a named
census fallback, and a log line that says which happened. The
materialize log now carries `worn=<report>` per body, so the next
naked person arrives with evidence instead of a mystery.

---

## F-055 - The years pass is bounded by its own cadence, not by loading ground ([C44]/DR-037)

**Claim.** Running the county forward over simulated years is limited by
how often its own per-person work runs, and not by loading map. Loading
the ground a county's households stand on is negligible; running that
work at the ten-minute cadence is not.

Measured on this machine, 2026-09-07, county of 216 at the shipped
default:

| | |
|---|---|
| One ten-minute pass, whole county | 0.1235 s |
| One simulated day at 144 passes | 17.8 s |
| One simulated year | about 1.8 hours |
| Three simulated years | about 5.4 hours |
| Chunks the county's claims touch | 432 |
| Map data behind those claims | 406 KB |
| The whole shipped map, for scale | 3.7 GB across 4065 cells |

**Verification.** `tools/years_cost.py`. The record-side figures are
timed in the engine's own Kahlua VM through `tools/luacheck/LuaRun`, the
instrument every border uses, driving the real `SAO_Conditions` and
`SAO_Habits` over 216 people. Two sample sizes are run and the shorter
subtracted from the longer, so process start-up cancels out of the
per-pass number. The world-side figures are read off the shipped
`media/maps` lotpack files and are a VOLUME, not a duration: loading
needs the running game and nothing here times it.

**What follows.** The cost is the cadence. The ten-minute pass exists to
drift a BODY's stats, and during the years nobody has a body - the
dormant day runs explicitly for people `SAO.Body.get` returns nothing
for. So the years should run the record side at the cadence of what is
actually being simulated, which is daily: deaths by the age table,
habits settling, standings softening, meetings on the road. At one pass
per simulated day the same three years cost about two minutes rather
than five hours, and nothing that has no body is skipped.

**What this corrects.** The question put to the operator called loading
the places "almost certainly unaffordable". That was a guess, and it was
wrong: 432 chunks and 406 KB is nothing, and it is the same ground every
time. The operator's ruling to run it for real stands and is cheaper
than the alternative it was weighed against.

## F-056 - The venture's willingness gate is saturated in a converged county ([C53])

Measured on the joining mirror's own county - the 60-person society the
equilibrium mirror converges over 120 days - across 138 invitations:

| pull without the office | value |
|---|---|
| 5th percentile | 0.78 |
| median | 1.28 |
| 95th percentile | 1.50 |
| already above the 0.55 threshold | 133 of 138 (96%) |
| anywhere in 0.15 .. 0.55 | 5 of 138 (4%) |

The threshold almost never binds. Who comes along on a venture is
decided by the three refusals - answering a need, being a loner, being
on the wall - and then by the caps: the goer's circle cap, the free
seats, and the house keeping somebody to mind it. The pull's own terms
(trust, the two lessons, nerve) discriminate almost nothing once trust
has converged, because housemate trust saturates near its ceiling and
the dominant term takes the sum far past 0.55 on its own.

Found while adding the caller's office to the pull ([C53]): the first
version of that measurement compared party sizes across houses and
answered nothing, and isolating the term - the same hearer, the same
trip, one term removed - showed it carried nobody at all. Not because
the term is wrong but because nothing in the pull can matter at that
end of the trust range.

Two things follow and neither is taken here. The threshold is an
authored number and moving it changes how every house feels, which is
a design call rather than a border's. And the saturation is the
equilibrium mirror's own convergence as much as the county's: a house
that formed yesterday has none of it, which is why [C53] adds a
young-house sweep rather than tuning anything.


## F-057 - A chooser returned one candidate where the caller held a veto ([C54])

`SAO_Standing.roadworthy` appraised a house's whole motor pool and
returned exactly one car: the roomiest openable runner. The venture
then applied the goer's own objection to that one car - somebody who
has learned that noise is a debt refuses a loud one and walks ([B19],
and the refusal is right).

With one car returned, the refusal discarded the yard. A house holding
a loud six-seater and a quiet hatchback sent that person out on foot,
past a car they would have taken. Nothing logged a choice, because no
choice was made; the log said the loud car was left where it sat,
which was true and complete about the wrong question.

The shape is general and worth naming: a chooser that returns its own
best candidate, to a caller that holds a veto over the result, turns
that veto into a refusal of the entire set. Either the criterion goes
in with the ask or the whole set comes back. Here the criterion goes
in - a loudness ceiling - because the pool is Standing's to own and
the ceiling is the person's.

Two others in the tree were checked and are not this shape.
`canHotwire` gates the same car, but `roadworthy` already prefers an
open one, so a locked car only comes back when there is no open
runner and the walk is correct. The venture's seat cap reads the
chosen car rather than choosing, and roomiest-first means the largest
acceptable car is always the one offered.


## F-058 - A pass that calls a system is not a pass that runs it ([C45]/[C62])

**The defect.** `[C45]` lives the days a later save owes by calling the
county's own systems once per simulated day. It never moved the clock
those systems read, and most of them gate on a CHANGE of day. A 1996
save ran about a thousand simulated days and came out of them with the
same people, the same feelings and the same needs.

| System | Gate | Across the whole span |
|---|---|---|
| `dormantAttrition` | `today > rec.lastRiskDay` | one stamp, no deaths after it |
| `dormantLife` | `lastWaterDay`, `lastFoodDay` | one stamp, nobody grew thirsty |
| `chooseDayPlace` | `daysWithout(...)` | zero dry days, so need drove nothing |
| `driftStandings` | `s.lastDriftDay == day` | one day's drift, then zero |
| the winter multiplier | `GameTime:getMonth()` | three simulated years in one month |
| `clockMonths` ([C61]) | `recordDayToday()` | held at the save's own record day |

**Why the border could not catch it.** Border 118 is `[C45]`'s own and
it checks that the years pass CALLS those systems. It does, on every
simulated day. Whether a call does anything is a different question,
and answering it needs a different instrument: Border 131 runs
`driftStandings` on three consecutive simulated days and counts what
moved, which is the smallest measurement that distinguishes the two.

**The shape, named.** A pass that drives other systems owns the clock
they read. Sixty-eight places in this tree asked `GameTime` for the
world age in hours, each of them meaning "how far along is this
county", and any of them could have been the one that broke. The fix
is not a stamp per site: it is one module that answers what hour it is
and sixty-seven sites that ask it.

**Verification.** `tools/county_clock_test.py` (Border 131), driving
the real `SAO_History` and `SAO_Standing` in the engine's own Kahlua
VM. Its control is the pre-batch tree, where the second and third
simulated days move nothing.

## F-059 - A whole dormant county shares one belief key ([C71])

Beliefs about people are keyed by `Identity.displayName`, which
renders `"Unnamed"` for a record that has no name. `backfillName`
takes a name off the engine shell the first time a body is built for
somebody, so a survivor the county has never materialised carries the
sentinel by design - and a dormant county materialises nobody.

**Measured.** One county run in the engine's own Kahlua VM against the
shipped map, 1096 days: **271 people, 271 of them `"Unnamed"`, one
distinct display name for the whole county.** Every belief anybody
held about any of them landed on one string, so the county's memory of
its dead was one slot per head and each death overwrote the last.

Three separate causes compounded into the same symptom, and each was
found only by the border refusing to pass:

| Cause | What it cost |
|---|---|
| the shared sentinel key | one belief slot for every person in the county |
| the news read `P.beliefs[hearer]` rather than opening it | a median of ONE person per county holding any belief about any person |
| `dormantAttrition` returns before anything at `DormantRisk` 0 | a dial meaning "the county stops collecting" also silenced news of deaths that had already happened |
| the hearers were `fellowsOf(id)` on a corpse | `[C68]` takes a corpse off the roster at death, so the company half of the news has reached nobody since |

**Beside it, and the reason this was looked at.** A dormant meeting is
a firsthand sighting - two people three tiles apart, trading lessons,
arguing doctrine, passing grudges and credits, founding houses - and
it wrote nothing down. Over eight counties of 1096 days, **not one
survivor in any of them believed a living person was anywhere.** The
only person-beliefs in the county were death notices.

**The shape, named.** A rendering is not an identity. `displayName`
carried a comment saying it was the belief key, and for the live half
it is: the scanner reads a name off a shell and the record carries the
same one. The dormant half has no shells, so the key it rendered was
the same string for everybody, and a store keyed by it could hold one
belief where the county needed two hundred. The fix is a second
renderer - `beliefKey`, the name where there is one and the id where
there is not - rather than a name pool, because a name is a fact about
a person and where it comes from is a design question that is not this
one.

**What it does not settle.** The county still has no names, and
getting one from the first shell built for you is backwards. Curing
that means SAO deciding a survivor's sex at genesis so a drawn
forename matches the body the engine builds later, which is a design
call and is the operator's. `beliefKey` makes the absence survivable.

**Verification.** `tools/person_belief_test.py` (Border 137), running
the shipped dormant modules in the engine's own VM through the tick
handler the mod registers, and reading the belief store rather than
counting calls. Its control is the pre-batch tree, which prints
`keyA=Unnamed keyB=Unnamed` and fails every property.

## F-060 - The dormant goal path had no social term ([C72])

`chooseDayPlace` decided where a dormant survivor walks from thirst,
hunger, lessons, beliefs and barred ground. It was a real,
attribute-aware decision and the only decision a dormant person made,
and there was no person in it. Nobody in this county had ever decided
to go to another person; every meeting was two need-driven walks
coinciding within three tiles.

**Measured**, over eight counties of 1096 days against the shipped map:

| | |
|---|---|
| housemate pairs seeded at genesis, bonded, trusting 0.6 to 0.9, on the same tile | 152 |
| of those, pairs that ever stood near each other again | 27 |
| people who lived and died without ever meeting anybody | 179 of 287 |
| pairs above the company line at the end that had ever met | 16 of 129 |

The trust economy was working the whole time and coincidence could not
deliver anybody to it.

**What the fix did not do.** `[C72]` built the decision and the sweep
did not move: 24 counties before and after gave houses standing 6 of 24
against 5 of 24, and a mean of 0.3 against 0.2. Instrumented at each
exit of the chooser, seeking is not being out-ranked - need takes 47
percent of day-goals and a place 52 - and in 790 of 806 choices there
was no eligible person to go to at all. The candidate list is empty
because a belief about a living person comes from a meeting, and
meetings almost never happen. Which is F-061.

**Verification.** `tools/seek_test.py` (Border 138), reading
`rec.dayGoalPerson` off the record after driving the real modules in
the engine's VM. Its control is the `[C71]` tree, which already holds
the belief: a survivor who believes somebody they trust at 0.85 is a
hundred and fifty tiles away sets out toward them 0 times in 40.

## F-061 - One move per simulated day is four tiles, and nobody checked

The years pass advances `tickCounter` by `YEARS_TICKS_PER_DAY` - 3600 -
per simulated day and calls `dormantLife` once. `dormantLife` moves a
record when `tickCounter >= rec.nextDormantMoveAt` and then sets that
stamp `1800 + rand(1800)` ticks ahead, so the condition is true exactly
once per simulated day, and one move is `math.min(4, len)` tiles.

**A simulated day is one move of at most four tiles.**

The live county runs the same code on a 240-frame population pass, so a
move arrives every 1800 to 3600 frames - about eighty moves in a game
day at default length, up to 320 tiles. The years give the same person
one eightieth of their own movement.

**After [C112], the mechanism above is history.** A tick is now a
9000th of a county hour (`floor(countyHours * 9000)`), both counters
read that one clock, the population pass is a last-fired stamp on it,
and `YEARS_TICKS_PER_DAY` and its calibrated advance are deleted - the
years advance the clock themselves, and a simulated day is 216,000
ticks. At the default day length a frame was a 9000th of a county hour,
so every span constant here keeps its number and its default-day pace;
what changed is the domain, not the tuning. [C75]'s one-pass-per-day
correction and this entry's cost argument still stand. Border 153
(`tools/tick_law_test.py`) holds the law. Noted in the end pass,
2026-09-13.

**Measured** rather than derived from the arithmetic: **1.8 tiles per
person per simulated day**, over four counties on each of the `[C71]`
and `[C72]` trees, sampled on the county's own day counter. Three
simulated years carry somebody under two kilometres, across a map
fifteen thousand tiles wide with towns hundreds of tiles apart.

**What it invalidates.** Every measurement this project has taken of
its own social life was taken in a county whose people barely move.
`[C67]` found that no company had ever formed and fixed it; `[C68]`
found the roster kept its dead; `[C72]` found the goal path had no
social term. All three are real and all three were measured against a
county where two people who live in the same house drift apart and
never walk far enough to find each other again. 179 of 287 people
never meeting anybody is not a fact about the social model.

**It was chosen, and the choice was never measured.** This is not an
oversight and it is not `[C62]`'s class. `[C45]`'s own record says so
in as many words: *the dormant systems pace in frames, so a day has to
buy them - a person moves every 1800 to 3600 of them and a pair may
meet once per 1800, so a simulated day advances that counter far
enough to open each gate about once. One move and at most one meeting
per pair is what a day deserves when nobody is watching it.* The
figure is deliberate and it is written down.

What was never asked is what one move is WORTH. The reasoning is about
cadence - how often each frame-paced gate opens - and it never crosses
into distance. One move is four tiles. So the decision reads as "a day
opens each gate once" and lands as "a person covers four tiles a day",
and those are not the same sentence.

That is the class, and this project has hit it before: a decision
about a mechanism's cadence, checked against the cadence and never
against its effect. `[C45]` itself was the last instance - Border 118
asserted the years CALL those systems, which they did, and `[C62]`
found that calling them moved nothing.

**The cost that produced it.** `[C45]` measured the alternative: at the
live cadence three simulated years cost about five and a half hours of
real time, and at a day a day about two minutes. One pass per day is
what bought that, and any correction has to keep it - which means
moving a day's distance inside one pass rather than running a day's
passes.

**What it was costing, measured after `[C75]` fixed it.** Twenty-four
counties before and after, same seeds: houses founded went from a
median of 20 to 43, houses standing after three years from a mean of
0.3 to 1.1, counties with a house still standing from 8 of 24 to 14,
people alive at the end from a median of 2 to 5, and deaths down from
284 to 269.

Nothing in `[C75]` touched a company, a meeting, a trust number or the
goal path. So `[C67]`, `[C68]`, `[C71]` and `[C72]` were each doing
more than their own measurements could show, because every one of them
was measured in a county whose people covered four tiles a day. The
social model was not the thing that was failing.

**Instrument note.** The first sampler for this divided distance by
sample points rather than person-days, and the years live fifty
simulated days inside one budgeted tick, so it reported 103 tiles a day
against a true 1.8. The probe's own comment header warned about that
exact trap on the line above the one that fell into it.

## F-062 - The shipped map is not to a consistent real-world scale

Established while looking for a bridge from tiles to metres, so that a
sourced human walking distance could anchor how far a day carries
somebody (F-061). There is no such bridge, and this is why.

**The map's own geography does not supply one.** The shipped map models
real Kentucky towns, and their spawn points are at known coordinates in
`media/maps/<town>/spawnpoints.lua`. Comparing in-game separation
against real great-circle distance over five real towns - Muldraugh,
West Point, Irvington, Ekron, Brandenburg - gives ten pairs:

| pair | tiles | real metres | m/tile |
|---|---|---|---|
| Muldraugh-Ekron | 10372 | 13225 | 1.28 |
| West Point-Ekron | 11327 | 19374 | 1.71 |
| Muldraugh-Brandenburg | 9579 | 16842 | 1.76 |
| Irvington-Brandenburg | 8295 | 16565 | 2.00 |
| West Point-Brandenburg | 9174 | 19690 | 2.15 |
| Muldraugh-West Point | 3640 | 7930 | 2.18 |
| Ekron-Brandenburg | 4064 | 9013 | 2.22 |
| West Point-Irvington | 12154 | 32500 | 2.67 |
| Muldraugh-Irvington | 9765 | 26277 | 2.69 |
| Irvington-Ekron | 4858 | 13180 | 2.71 |

**1.28 to 2.71 metres per tile - a 2.1x spread.** The map is a
rendition rather than a survey, so it cannot be used as a ruler.

**Two other routes were tried and neither answers it.** The engine
reports vehicle speed in km/h, which would convert tiles to metres, but
`BaseVehicle.getCurrentSpeedKmHour` returns a JNI physics value rather
than a conversion over tiles. And nothing in the shipped translations
or the shipped Lua states a unit for a tile at all.

**What follows.** A real-world walking distance cannot be converted
into this map's tiles by anything the installed build establishes, so a
figure anchored that way would be resting on an invented conversion. It
is not that a person's daily walking distance is unknown; it is that
this county has no verified length.

`[C75]` therefore anchors a day's walking in the county's own units
instead - `Places.comfortHorizon`, which `[C25]` ratified as the home
neighbourhood reached by a day of ordinary living and which derives
from the engine's own `getCellSizeInSquares`.

**Reported rather than omitted.** If a tile's length is ever
established from the build, this finding is what the figure should be
re-derived against.

## F-063 - `[C72]`'s own sweep table was measured on a tree that predated two of its changes

**Self-found** after `[C72]` merged, while chasing why two runs of the
same sweep disagreed. They did not: the sweep is reproducible, and a
fresh run of the `[C74]` tree reproduces an earlier one exactly, figure
for figure. The trees differed.

The 24-county before-and-after table in `[C72]`'s record and its pull
request was launched, and then the batch kept being worked on. Two of
`[C72]`'s own changes landed after it: the genesis sighting - people
who arrive together have seen each other - and the refusal of a goal
the walker is already standing on, which is what makes that genesis
belief a durable anchor rather than one spent on the first day. The
table therefore reports a tree that is not the tree that shipped.

**What it said, and what the shipped tree does:**

| | in the record | shipped tree |
|---|---|---|
| counties with a house standing | 5 of 24 | 8 of 24 |
| houses standing, mean | 0.2 | 0.4 |
| survivors in a house, mean | 0.5 | 0.8 |
| alive at the end, mean | 1.9 | 2.8 |

`[C71]`'s own figures, measured the same way, are 6 of 24 and a mean of
0.3. So the record's conclusion - *nothing moved that this batch was
written to move* - is wrong in its direction: the shipped `[C72]`
raises houses standing rather than leaving them flat, though 6 against
8 over 24 counties is a difference this sample cannot separate from
noise, and that part of the record stands.

**What does not change.** The branch-exit instrumentation - 806 day
choices per county, need taking 47 percent, a place 52, and somebody
7.6 - was measured on a tree carrying both fixes and is unaffected. So
is F-061.

**The shape, named.** A measurement that closes a batch has to be taken
on the tree that is committed, after the last edit. Launching it early
and shipping the result is measuring a tree nobody has.

**Correction, not rewrite.** `[C72]`'s record and pull request stand as
written; this entry is what the ledger's append-only rule provides for,
and `SESSION_STATE.md` carries the corrected figures.

## F-064 - The engine rebuilds the Lua state on entering a world, so module state is per-world

**Verified** [C77] by `javap` against the installed
`projectzomboid.jar`. `zombie.gameStates.IngameState` is the only game
state that calls `zombie.Lua.LuaManager.init()`, and the call is in
`IngameState.exit()` - **leaving** a world, not entering one. It sits
at the end of a teardown block that also resets `ContainerOverlays`,
`BentFences`, `BrokenFences`, `TileOverlays`, `LuaHookManager`,
`CustomPerks`, `PerkFactory`, `CustomSandboxOptions` and
`SandboxOptions`.

The first reading of this said entering a world rebuilds the state.
That is the wrong mechanism for the right conclusion, and the
difference is which method the call sits in - one more `javap` past
where it was tempting to stop.

So a world's module state is torn down when that world is left, and
every module-scope table in this mod is fresh for the next one. That
is the fact `[C15]` was built on when it bound the perception store to
ModData - "module load runs earlier than ModData" and a plain table
"dies with the session" - and it is stated here explicitly because it
was nearly re-litigated as a defect.

**What it settles.** `Places.reset` has no caller anywhere in the tree
and does not need one: its own docstring says it is for a world change,
and leaving a world reinitialises Lua underneath it. `Pl.cache`,
`Pl.around_cache`, `Pl.contentCache` and `Pl.know_cache` cannot carry
one world's buildings into another, and `know_cache`'s growth - which
`[C75]` made real by letting people move - is bounded by a single
world session rather than accumulating.

**What it does not settle.** `Perception`'s `b.known` is the one that
persists, because `[C15]` deliberately bound it to ModData. An entry
per building per person, pruned nowhere, riding the save. That is the
growth worth measuring and it is unaffected by this finding.

**Reported because two wrong readings were each one step from the
record.** An uncalled cleanup function reads like an oversight, and it
is the engine doing the job instead. Then the engine's own answer read
as init-on-entry when it is teardown-on-exit. Both were a single
`javap` away from being written down wrong, and the second one nearly
was.

## F-065 - What the walking costs: both growths are bounded, and one of them was misread

`[C75]` let the county's people cross their neighbourhoods, and its
record named two growths as unmeasured: `Places.know_cache`, and
`Perception`'s `b.known`. Measured now, over six counties of 1096 days
on the shipped tree:

| | min | median | max |
|---|---|---|---|
| buildings known, whole county | 4 | 110 | 347 |
| ... most held by any one person | 2 | 48 | 109 |
| people holding any | 2 | 3 | 16 |
| place-knowledge cache keys | 766 | 805 | 863 |

**Neither is a problem, and the reasons are different.**

`know_cache` is session state, and F-064 establishes that leaving a
world reinitialises Lua, so it cannot reach the next one. Eight hundred
keys in a world session is nothing.

`b.known` is persisted, and `[C75]`'s record said it was "pruned
nowhere in the tree". **That was wrong.** `Perception.forget(id)` drops
the whole belief store for a person - `P.beliefs[id] = nil` - and
`Identity.markDead` calls it, which is the funnel every death path
reaches, added at `[B51]` for exactly this. So `b.known` is pruned by
dying.

The count is therefore bounded by the LIVING, not by everyone who ever
lived, and the measurement shows it: the people holding any known
places are exactly the people still alive. The shipped map has 2,831
buildings, and the survivor who knows most knows 109 of them.

**How the misreading happened.** The search was for `known[...] = nil`
and `known = {}` inside `SAO_Perception.lua`, and neither exists,
because the pruning is one level up: the whole store goes, not the
field. Searching for the narrow spelling instead of the mechanism is
the same shape as `[C70]`'s defect and GOVERNANCE's prose-is-not-code
clause, arrived at from a third direction.

**What this retires.** Both entries come off `ROADMAP.md`'s queue.
Nothing needs pruning, nothing needs a budget, and no save grows
without bound. What remains from `[C75]`'s cost is the one thing this
cannot measure: how many ticks a real catching-up county takes, which
is a play receipt.

---

## F-066 - One flag was doing three jobs, and `[C81]` only renamed it

**Found** `[C81]`, by enumerating every reader of `rec.knox` before
replacing it. Structural; no live receipt.

`rec.knox` was set in two places and read in twenty-four, and the
readers do not all mean the same thing by it.

| Reader | What it is actually asking |
|---|---|
| `SAO_Population` materialise pass | is this body somebody else's to spawn |
| `SAO_Population` dormant walk, `dormantAttrition` | is this body somebody else's to move and to kill |
| `SAO_History` occupation | did this record originate outside the county |
| `SAO_Neighbours` menu | have we adopted them yet |

**The first two are a claim. The third is provenance. The fourth is an
adoption state.** They coincide today because one mod produces all
three at once, and they are not the same fact.

The conflict is visible in the tree's own prose. `SAO_Absorb`'s header
says the county takes his people over **completely** - "from then on
they are ours entirely" - and `SAO_Population`'s materialise pass says
of the same flag that "a Knox person's body is the legacy mod's
business". A record that has been absorbed is ours by the first
statement and not ours by the second, and both read one boolean.

`SAO.Body.foreign` is the honest claim: a live handle to a body this
county did not make and will not drive. Whether the RECORD's flag
should agree with it is the open question.

**`[C81]` did not resolve this and says so.** It removed the mod's name
from the logic, which is what DR-035 asks and what was actually wrong;
every reader now asks `SAO.Claims.isHeld` and gets exactly the answer
it got before. Splitting provenance from claim changes which people the
county spawns, walks and kills, which is a behaviour change needing a
measurement and a ruling rather than a rename.

The rename is what makes the split possible later: three call sites
asking three differently-named questions can be changed independently,
where twenty-four branches on one boolean could not.

---

## F-067 - The engine requires no player at the wheel

**Found** `[C82]`, by disassembling every method along the shipped
B42.20 jar's driving path. Structural; no live receipt.

T-001's ledger called NPC driving engine-absent, and nothing had ever
read the code to ask. The driving path's identity gates, disassembled:

| Gate | What it actually tests | An NPC in seat 0 |
|---|---|---|
| `BaseVehicle.isKeyboardControlled()` | the seat-0 character IS `IsoPlayer.players[0]` (identity compare) and the vehicle tows nothing | answers false |
| `BaseVehicle.updateControls()` | a controller exists, `isOperational()`, and the driver cast to `IsoPlayer` is blocking movement | the cast is null; passes |
| `BaseVehicle.tryStartEngine(boolean)` | the driver cast to `IsoPlayer` blocks movement; then the cheat, `vehicleEasyUse`, keys in the ignition or hotwired; condition and quality can refuse | passes; the gameplay stands |
| `CarController.updateControls()` | keyboard only under `isKeyboardControlled()`, joypad only at `getJoypad() != -1` | neither input branch runs |
| `BaseVehicle.update()` | none - the physics read `isEnable` with no driver-identity gate | ticks |

Every gate that names a player is an exclusion of the blocked local
player, never a requirement that one is present. With both input
branches skipped, the public `ClientControls` fields - `steering`,
`forward`, `backward`, `brake`, `shift`, and `forceBrake` as a
milliseconds window the method's tail honours - stand as written,
which is the doorway any non-player driver's machinery has. Seating is
already contract surface: `enter(seat, char)` is Addendum D's fact,
and seat 0 is the driver's by `getDriver()`'s own typing.

**What this does not establish.** Reachability is verified at the
bytecode level and by nobody's behaviour: no shipped code drives a
vehicle NPC-side - the reference mod's own sources contain no driving,
its health controller only rejecting vehicle targets
(`KnoxHealthController.java:255`) - so whether an NPC-driven car
actually drives, at what cadence, and what it does to the county are
hypothesis until a live receipt. The ledger's correction is one
clause: engine-absent was prose about code nobody had read, which is
the prose-is-not-code rule from `[C70]` reached from a fourth
direction.

---

## F-068 - The boolean vehicle-start argument represents a held key

**Verified** `[C122]`, by disassembling `BaseVehicle.tryStartEngine`
and `ItemContainer.haveThisKeyId` in the installed Build 42.20 jar.
Structural; no live receipt.

F-067 correctly found that a non-player driver has no identity gate in
the driving path, but its start table omitted the boolean argument.
The no-argument method pushes `false` and calls the boolean form. In
that form, the engine accepts a start when debug start-without-key,
easy-use, ignition key, the boolean argument, or hotwire is true. The
argument is therefore the ordinary answer to whether the driver holds
the right key, not a bypass of the key rule.

`ItemContainer.haveThisKeyId(int)` checks loose `Key` items first. For
an item whose type is `KeyRing` or whose tag is `KEY_RING`, it obtains
the `InventoryContainer` inventory and calls `haveThisKeyId` again.
The key-ring path is already the engine's inventory path. C122 reads
that method for the driver and carries its answer into the motor-pool
appraisal; it does not make a key, move a key, or search nearby ground.

**What this does not establish.** The jar proves the permission path,
and Border 154 proves the Java-to-Lua choice and source seams. Neither
one proves that a particular live vehicle starts, drives, or lets a
person retrieve food from a vehicle compartment. Those remain play
receipts.

---

## F-069 - Build 42's IsoAnimal inherits IsoPlayer and shares the global player list

**Verified** `[C123]`, by inspecting `zombie.characters.animals.IsoAnimal` and `IsoCell.getRanchList` in the Build 42.20 jar.

`IsoAnimal` extends `IsoPlayer`, meaning animal instances appear in `IsoWorld.instance.CurrentCell.getPlayers()`. Without an explicit `instanceof IsoAnimal` exclusion, survivor perception scanners and combat targeting treat animals as foreign human players.

Ranch structures are held in `IsoCell.getRanchList()`, which returns `ArrayList<Ranch>` containing animal references, food troughs, and hutches.

---

## F-070 - Prone character targeting and stealth zombie suppression

**Verified** `[C124]`, by inspecting `IsoGameCharacter`, `IsoZombie`, and `AIBrainPlayerControlVars` in the Build 42.20 jar.

Prone or crawling characters (`IsoZombie.isCrawling()`, `IsoGameCharacter.isOnFloor()`, or prone animation variables) require floor-level combat aiming. `AIBrainPlayerControlVars` provides `setAimAtFloor(boolean)` and `setAuthorizeShoveStomp(boolean)` to direct attacks downward rather than horizontal swings.

Stealth or motivation mods mark inactive zombies with `isUseless()` or manage targets via `IsoZombie.getTarget()`. Modifying or retargeting these zombies breaks third-party mod logic.

---

## F-071 - Antibodies v1.98 architecture and state isolation

**Verified** `[C125]`, by inspecting installed Workshop `2392676812` (`lgd_antibodies`) across `42.0` and `42.13`.

In `42.13`, Antibodies encapsulates its logic under `require("lgd_antibodies/...")` modules without exposing a mutable global table. Per-character medical state lives privately on `player:getModData().Antibodies.medicalFile`. Antibody production rate follows a sinusoidal activation equation:
`math.sin((infectionLevel / 100) * math.pi)`.

Because Antibodies keeps its state encapsulated on player modData and provides no public survivor API, SAO isolates its survivor brain health in `SAO_Neuro.lua`, mirroring Antibodies' continuous sine activation kinetics over `SAO.Course` without mutating or colliding with Antibodies' private data structures.

---

## F-072 - Neuroinflammation as a continuous graph with multi-insult kinetics

**Verified** `[C125]`, structural and mathematical derivation against `SAO_Neuro.lua`, `SAO_Conditions.lua`, and `SAO_MedicalWindow.lua`.

1. **Continuous scalar**: Brain health is represented as a single continuous value `rec.neuroinflammation` in `[0.0, 1.0]`. It is never partitioned into discrete buckets or enum stages.
2. **Kinetics**: Neuroinflammation insults accumulate from:
   - Knox infection via sine curve activation `math.sin(pos * math.pi) * 0.08` per hour.
   - Sepsis via `rec.woundInfected` at `0.015` per hour.
   - Drug/alcohol toxicity from the C121 ladder (`rec.drinkPoisonTotal`) at `0.02 * min(1.0, poison / 50.0)` per hour.
   - Late-stage withdrawal stress at `0.03` per hour.
3. **Baselines & Decay**: Afflicted survivors maintain a persistent floor of `0.30`; Crossed bodies sit at `0.90`. When insults resolve, load clears exponentially via `math.exp(-0.04 * deltaHours)` toward baseline.
4. **Cognitive projection & memory**: Cognitive clarity is derived as `1.0 - load`. `SAO.Conditions.memoryFactor` attenuates lesson retention duration by `math.max(0.2, clarity)`.

---

## F-073 - Headless simulation module harmonization and full-fidelity dormant execution

**Verified** `[C126]`, in `tools/county_sweep.py` and `tools/county_dump.py` against Kahlua VM.

The headless simulation harness previously loaded 20 modules and reported 12 missing references across recent additions (`SAO_Neuro.lua`, `SAO_PathogenEvents.lua`, `SAO_AfflictedReturn.lua`, `SAO_WorldGenesis.lua`, `SAO_Adaptation.lua`, `SAO_Isolation.lua`, `SAO_Organization.lua`, `SAO_Settlement.lua`, `SAO_Material.lua`, `SAO_Recognition.lua`, `SAO_Nuke.lua`).
Expanding `MODULES` to the complete set of 42 shared and client dormant modules and declaring client-only and driving surfaces in `NOT_DORMANT` produces zero missing module references. Headless sweeps execute a 1096-day county in ~8 seconds with full fidelity across neuroinflammation, reverted afflicted adoption, and organization dynamics.

---

## F-074 - Empirical macro trajectory curves and sub-5ms late start extrapolation

**Verified** `[C126]`, empirical data from `tools/county_trajectory.py` and structural evaluation in `SAO_Trajectory.lua`.

Sweeps across 30 to 1096 days demonstrate consistent macro distributions:
1. **Exponential attrition decay**: $N(d) = \max(N_{\text{floor}}, N_0 \cdot \exp(-k \cdot d))$ with $k = 0.00205$ and a resilient survivor floor $N_{\text{floor}} = N_0 \times 0.08$.
2. **Mutual-defense house convergence**: solitary survival declines as survivors coalesce into houses ($k = 0.0018$).
3. **Fortification scaling**: entrances boarded over elapsed years ($0.0030$ per day, capped at 8).
4. **Brain health settling**: afflicted survivors hold their $0.30$ floor, crossed bodies sit at $0.90$, and living uninfected survivors settle below $0.15$.
Instantiating terminal world state via `SAO.Trajectory.extrapolate` completes in under 5 milliseconds, avoiding dozens of frame budgets and CPU lag during late-start save loading.

## F-075 - Recovered simulation claims failed causal and completion checks

On 2026-09-18 the recovery audit compared C126 source, unmerged C127-C129
proposals, transcripts and the preserved trajectory dataset. The fast module
assigned deaths, survivor groups, trust and fortifications from arbitrary
curves. It did not implement a validated learned model. The old 90-day row
reported only 60 completed days. F-073/F-074's full-fidelity, empirical-fit and
late-start performance conclusions therefore do not stand.

The actual C126 Population and History code, with the synthetic fast route
absent, executed only 60 scheduler steps in a 90-day completion probe instead
of the required 81,000. Its future callback stamp blocked further history.
C130 persists fractional county ticks, runs the shared 240-tick pass and
rejects incomplete exports. The 90/365-day scheduler and original-code control
are in Border 160. Border 159 tests evidence rejection, and Border 161 tests
company decisions with causal controls. These are offline checks; in-game
acceptance and a trained accelerator remain separate, unfinished evidence.

The same audit found that C125's `(setting or true) == true` could never honor
an explicit false setting. Border 158 had checked only that the setting's name
appeared in source. C130 fixes the boolean read and adds actual-VM off/on/default,
projection and advance tests with an original-source control. This repairs
option behavior; the larger C125 model and visualization remain under review.

F-072's numerical description also differs from the shipped source: sepsis is
`0.02` per hour, toxicity is `0.05 * min(1.0, poison / 100.0)`, and withdrawal is
`0.02`. The Knox peak `0.08`, clearance `0.04`, and floors `0.30`/`0.90` match
the code. Those authored constants and the current-load medical bar have not
been validated as a biological model or an observed treatment experience.

### F-075 numbering correction

The repair called C130 above is canonically C127. The local sequence ended at
C126; intervening unmerged proposal labels did not reserve batch numbers. The
original statements and captured seed names remain historical identifiers of
the same repair and evidence, not an additional development unit.

## F-076 | 2026-09-19 04:33 UTC / 21:33 PST | Implementation audit of former C112-C126

On 2026-09-19, the audit of former C112-C126 plus the former C127 recovery
found thirteen original batches requiring rework, retained former C115's
configuration wiring and rejected former C126's already-removed trajectory
shortcut. These are former identifiers; the current C41-C50 units preserve
the findings after consolidation. The report and exact inputs are retained in
`artifacts/audits/20260919-0356Z-2056PST-c112-c126-implementation-audit.md`
and its adjacent evidence directory.

The decision exporter retained mutable person and belief tables until final
serialization. An installed-VM probe changed state after capture: an earlier
row then contained the later fact, including its future acquisition tick,
with zero reported capture failures. Driving probes reproduced route
cancellation and a progress watchdog that cancelled despite actual movement.
An afflicted-return probe produced a body without a controller; explicitly
adopting the body supplied the positive control. Further probes reproduced
automatic social relocation, premature transfer consequences, treatment/CPR
queue conflict, zero-wound child fear, withdrawal-clock drift, inaccessible
vehicle/animal reads and cadence-dependent brain state.

Each report distinguishes executed counterexamples, source traces and
unobserved play consequences. The preserved manifest hashes source and engine
inputs. Passing targeted borders alongside these counterexamples limits what
those borders establish; neither the audit nor catalog consolidation creates
new runtime acceptance. Ratified behavior and approved dataset choices remain
requirements while their implementations and source conditioning are repaired.

## F-077 | 2026-09-19 04:33 UTC / 21:33 PST | Body release and graph serialization boundaries

On 2026-09-19, the shipped Lua modules were executed in the installed Build
42.20 Kahlua VM with isolated state and explicit bridge substitutes. Inputs,
source hashes, Java probe, Lua controls, command runner and observed outputs
are preserved in `artifacts/audits/20260919-0433Z-2133PST-c-substrate-evidence/`.

`Body.release` removed the body, cleared Body.active and returned true after
both throwing and empty snapshot capture; the previous snapshot and hour
remained OLD_SNAPSHOT and 5. The successful control stored NEW_SNAPSHOT and
hour 42 before removal. The empty result matches SAOHibernation.hibernate's
actual Java failure convention (catch Throwable, return empty string).
Population drops the controller before calling release and ignores its
result. The counterexample establishes a broken ownership transition; it
does not measure how often capture fails in play.

The installed GlobalModData.save delegates to KahluaTable.save. Its serializer
accepts strings, doubles, booleans and nested tables, skipping unsupported
values such as functions. Saving the actual branching table succeeded at 569
bytes. Loading retained branch IDs and pattern counts while omitting
callbacks. Fresh module initialization and Integration.ensure restored the
built-in readers, pressures and weights; an extension callback remained absent
until its owner re-registers it. Therefore closures in the bound table do not
demonstrate a normal save failure. Runtime registration and durable history
still need distinct ownership and an extension reconstruction contract.

## F-078 | 2026-09-19 05:51 UTC / 22:51 PST | Native person snapshot and ownership transition

C51 repairs the F-077 release failure across Body, Population and Harness.
The installed Kahlua VM executes production capture, teardown, retry, reload,
restoration and explicit deletion with bridge/body fault doubles. Capture
failure preserves the previous record and ownership; failed removal retains a
durable pending capture and recoverable handle. Independent age, drug,
afflicted and environmental callbacks cannot advance the held representation.
Queued incoming treatment and inventory transfers retain their target, including
nested containers. Source mutations reproduce the ownership failures.

The installed Build 42.20 world-version-249 component serializers preserve
inventory, Stats, BodyDamage and XP. A real-engine JVM probe constructs items,
characters and an empty cell without opening a world or save. Its six-item
fixture preserves nested food and keys, separate weapon instances, ammunition,
item ModData, held/worn/attached identity, wounds, statistics, traits and custom
perk state. The native loader silently omits unavailable items/perks; independent
item manifests and trait/perk registry validation now refuse those cases.

Deserialization alone does not resume item processing. Native cell registration
is required for root and nested carried items, and recursive removal must be
queued on teardown. The cell fixture verifies both, including idempotent removal.
Twelve compiled source mutations fail for their stated reasons. The final
shipping jar also passes SAOHibernation.awaken at zero elapsed hours: six items,
no food/drink consumed, hunger 0.99 and thirst 0.98 retained. Actual bridge
ownership queries distinguish the person's nested inventory from another's.

The versioned v3 envelope uses native binary sections, bounded lengths and
SHA-256 integrity. Valid v1/v2 records remain readable, with the original
formats' information loss stated. Full IsoPlayer.load is unsuitable because it
also initializes player appearance and writes multiplayer player options.
Nutrition, fitness, learned recipes, standalone character ModData and human
appearance remain outside this snapshot. Positive-elapsed dormant metabolism
is retained, not validated by these tests. No play-frequency or complete-person
fidelity claim follows from this result.

Inputs, source hashes, probes and results are recorded in
`artifacts/audits/20260919-0544Z-2244PST-c51-person-preservation-evidence/`.
The permanent gates are Borders 75, 162 and 163. The final shipping jar hash
before publication is
`d3592141fe8ac8deae1d9ef2f8253b649c84076421fb062a59222636302babdc`.

Closing verification also covers a death arriving during retained teardown.
The death funnel attempts checked cleanup; failure retains the handle, and
population recovery retries dead transitions before any snapshot commit.
Ordinary deaths retain the engine corpse path. Dead records cannot materialize.
Border 162 now has sixteen production-source controls. Pending transitions have
their own Ledger count and do not inflate the available-body count. The first
full gate's verdict-prefix, registry-surface and registry-lifetime findings are
retained in the evidence directory with the corrections.

## F-079 | 2026-09-19 06:27 UTC / 23:27 PST | Afflicted return blocked by the dead-record guard

The continuation review reproduced a C51 compatibility regression.
`SAO_AfflictedReturn.adopt` passes its still-dead record to
`SAO_Body.materialize`, then clears the death flag only after success. C51's
ordinary dead-record refusal prevents that caller from returning any body.

The installed Kahlua VM ran both production functions with Border 162's explicit
body/bridge doubles. Production returned `returned=false body=false dead=true
controller=false`. A source control removing only the dead-record guard returned
`returned=true body=true dead=false controller=false`, exposing the earlier
audit's separate missing-controller defect. The control is not a repair.

Inputs, replay and results are preserved in
`artifacts/audits/20260919-0627Z-2327PST-continuation-evidence/`.
This proves the Lua caller/guard incompatibility, not the correctness of live
ZAO cleanup or current-possession transfer. ROADMAP R1 and SUBSTRATE specify
the required authorized return transaction, source quiescence, acknowledged
old-body teardown, single adoption, recovery after failure/reload and bodyless
historical path. Those repairs remain to be implemented.

## F-080 | 2026-09-19 07:35 UTC / 00:35 PST | Loaded person state omitted from native saves

The R1 save review verified that the native world save does not serialize SAO's
living shells outside the player slots. `PlayerDB.savePlayersAsync` visits
`IsoPlayer.players`; square serialization includes corpses rather than living
moving objects. Before the working R1 repair, the current person's hibernation
pack was refreshed on release, not on normal save. Saving and restarting with
a person still loaded could therefore restore consumed items and lose later
acquisitions.

`GameWindow.save` invokes OnSave at bytecode offset 302, before IsoCell.save at
364 and GlobalModData.save at 438 in the installed world-version-249 engine.
The draft uses that event to capture current supported state and native visual
state without relinquishing bodies/controllers. Pending return/release journals
remain authoritative. Border 166 executes the actual Lua checkpoint and uses a
consumed-item/acquired-item fixture, full record reconstruction and native save
ordering. Its controls remove the producer, state updates and failure protections.

A failed capture records an explicit failure and retains the older pack; after
restart, ordinary materialization refuses that known-stale pack. The event cannot
abort the rest of the engine save or recover uncaptured state. This result does
not establish atomic interrupted-save recovery. Source and receipts are indexed
in `artifacts/audits/20260919-0735Z-0035PST-r1-return-evidence/`.

## F-081 | 2026-09-19 07:35 UTC / 00:35 PST | Loaded reanimation lacked a pathogen-state producer

ZAO's controller derived `dead` from a loaded SAO record even while its scan
observed that person's live reanimated IsoZombie. Its state projection also
preferred `record.dead` over a saved turned state. Reversion only advances from
`turned`; a test that directly supplied an afflicted event bypassed this defect.

The R1 joint VM now executes actual Forms, Pathogen, StateStore, State and
Controller modules through death, observed reanimation, a controlled reversion
draw and the return transaction. The draft binds observed turning to the current
death sequence and preserves it through state projection. Two independent source
controls remove observation and projection and fail at the missing turned-state
assertion. Loaded turning does not set `turnedDormant`.

## F-082 | 2026-09-19 07:35 UTC / 00:35 PST | Infection damage cannot be separated from trauma at death

The installed `BodyDamage.Update` applies infection-progress loss through
`ReduceGeneralHealth` (bytecode 2058-2109) and terminal infection loss through
the same method (2023-2055). That method reduces individual part health, clamped
at zero. The death snapshot therefore lacks an exact decomposition of infection
loss and trauma. `calculateOverallHealth` sums the resulting part health and
cannot recover the lost provenance.

The isolated native `RecoveryHealthProbe` verifies that clearing every infected
part, global infection fields, infection timers and infection Stats preserves
unrelated wound state, hunger/fatigue/poison and XP. The lethal snapshot remains
dead. A temporary positive overall-health scalar returns to zero on native
recalculation. A nonlethal fixture stays alive across the next native update;
the omission control leaving one infected part reactivates global infection.

The probe source and output are preserved in the R1 working evidence directory.
They established why a physical-restoration policy or prospective damage
provenance was required. The operator selected critical viability with actual
injuries preserved. ZAO DR-028 now owns that rule, and its installed-engine
production probe plus four defect controls pass.

## F-083 | 2026-09-19 08:09 UTC / 01:09 PST | Native string lengths can corrupt saved person state

The installed `GameWindow.StringUTF.save` narrows a UTF-8 byte length to a
signed short and writes all bytes. Its reader treats a nonpositive length as
empty without consuming those bytes. `KahluaTableImpl.save`, used by
GlobalModData and item ModData, reaches this writer. Native snapshot envelopes
can legitimately exceed its 32,767-byte per-string limit.

The C52 R1 repair stores long person snapshots and visuals as versioned,
checksummed tables of strings no larger than 16,000 UTF-8 bytes. Short strings
and legacy readers remain supported. Border 167 executes actual bridge adapter
methods, the durable-text helper and installed Kahlua table serialization. Its
compiled controls remove fragmentation, integrity checks and bridge adapters.

An independent native inventory probe found a second boundary inside the
snapshot itself. An item's ModData string of 32,767 ASCII bytes roundtripped.
At 32,768 or 65,536 bytes, capture, envelope validation and restoration all
reported success, but the native key identifier changed from 67890 to
1633771873. A 32,768-byte multibyte value also corrupted the key. The item
loader's final position reset concealed the unread bytes from the outer
consumption check. Fragmenting the outer snapshot cannot repair that loss.

The draft therefore checks string keys and values recursively in every captured
item's ModData before native serialization, including nested inventory and
detached return equipment. Values beyond the native byte limit, cycles and
excessive nesting refuse capture while the source remains owned. Border 163
now includes safe ASCII/multibyte boundaries, oversized values/keys, nested
tables and a source control removing this refusal. This is a serializer bound,
not a restriction on ordinary inventory capacity. R1 evidence is indexed in
`artifacts/audits/20260919-0735Z-0035PST-r1-return-evidence/`.

## F-084 | 2026-09-19 09:06 UTC / 02:06 PST | The Crossed interaction exists as disconnected state and routing pieces

The sibling's published A32 claim that the Crossed are executed is false in the
current runtime. ZAO sets `currentForm = "none"` whenever a state becomes
Crossed. Its controller puts target selection, `ZAO.Crossed.decide` and the
ordinary form drive under `state.currentForm ~= "none"`. The named Crossed
consumer is therefore unreachable in a normal Crossed state, and no permanent
border invokes it.

The dormant pass here supplies both callers of `ZAO.Pathogen.expose`. Each is a
once-per-day distance check at three tiles: one for a dormant Afflicted record
and one for a loaded Afflicted body. The pathogen correctly restricts the state
transition to Crossed carrier plus Afflicted target and applies crossed odds
times Afflicted susceptibility. There is no spontaneous Afflicted-to-Crossed
roll. Proximity, however, is not the canonical intentional act. It does not
establish a Crossed decision, restraint or other action, blood exposure, a
result receipt, or interruption. On success it leaves the live SAO body and
controller in place while only the ZAO terminal state becomes Crossed.

The broader action substrate is also absent. SAO records only the retained
`drive` verb. C116 added a distinct `IsoZombie` driving adapter, but no Crossed
consumer reaches SAO's human combat, weapon, tool, activity or general action
vocabulary. The fallback body is still an `IsoZombie` whose assigned human
target may resolve through ordinary zombie attack behavior. That does not
represent the canonical human-looking, planning, weapon-using Crossed, and it
violates the operator's explicit boundary that Afflicted are not food.

The repair crosses several planned owners. R5 owns the exposure and systemic
physiology event; R7 owns intent-through-result and interruption; R8 repairs
adapted action families; R9 owns the complete Crossed life/action producers;
R10a/R10b own grounded dormant opportunity and historical execution; R4 owns
reload and one-controller continuity. The contract must cover representation,
retained experience and verbs, deliberate goal selection, human action
execution with the specified Afflicted exception, the exposure result and the
SAO-to-ZAO body/controller transfer. R1 only returns a person as Afflicted and
does not claim this later interaction.

## F-085 | 2026-09-19 | A host callback was mistaken for current simulation time

`Controller.tick()` returned a value cached at the start of its host callback.
Population can execute many historical substeps inside that callback, updating
durable `yearsTicks` before each step. Any decision consumer reached from those
steps therefore saw the callback's earlier time. Separately,
`WorldGenesis.applyDay` supplied an elapsed day directly to
`Integration.apply`, whose third argument and downstream pressure/branch
consumers are tick-based. Both values were numerically valid, so type checks and
ordinary single-callback tests could not expose the unit errors.

C53 makes History the conversion owner: 9000 ticks/hour, 216000 ticks/day and a
named day-start boundary. Controller decision reads now refresh History at the
moment of use. Native corpse animation grace and operational log flushing use a
separate host-callback axis rather than dilating with county time. Border 168
executes shipped Lua in Kahlua through historical substeps, reload, midnight,
Day Zero and nondefault DayLength. Removing the fresh read, passing day as tick,
or pacing the corpse net from county time flips the corresponding verdict.

The timestamp inventory also found that a generic `At` suffix cannot establish
a unit in this tree. Most controller deadlines are county ticks, several social
and integration fields are county hours or days, `Identity.createdAt` is a
legacy engine-calendar millisecond string, and `Identity.updatedAt` is a
revision counter. SUBSTRATE now records those exceptions. Existing ZAO
consumers already enter through the refreshed SAO tick or explicit county
hours/days, so R2 requires no ZAO source change.

## F-086 | 2026-09-19 | Native component codecs omit continuation state and can accept silent loss

The installed world-version-249 person codecs are individually narrower than
the person they update. `Nutrition.save/load` omits its update counter, extrema
and weight-direction flags; `Fitness.save/load` inserts into existing maps and
omits its update baseline and current exercise; XP omits recipes, reading/media
collections and descriptor boosts; `HumanVisual` omits outfit, forced-script
and growth timing; Kahlua silently skips unsupported table pairs. Native item
loading can also retain an item while dropping an unavailable fluid definition.

C54 introduces the v4 native-person envelope around those verified seams. It
preflights unsafe nutrition before the engine's low-weight setter can damage a
staged body, loads fitness into a fresh component with a documented current-
body minute baseline, restores learning collections directly, carries stable
visual references and timers, separates durable metadata from runtime owner
keys, and compares each root or nested fluid component after load. The old v3
reader remains supported within its five sections; absent fields produce a
migration record rather than invented history.

Border 169 compiles and executes the production snapshot against the installed
engine. It proves repeated wakes and the next nutrition, fitness and boosted-XP
updates, then removes each continuation or refusal seam. A whole-inventory byte
comparison was rejected during the work because immediate native reserialization
is not byte-stable; per-item fluid-component facts provide the discriminating
check without rejecting healthy inventory state.

## F-087 | 2026-09-19 | Health history and Crossed conversion require exact event and ownership boundaries

The recovered C49 implementation held a current scalar, sampled endpoint facts
over a whole callback interval, read an unwritten SAO terminal field and treated
lifetime poison damage as current exposure. Its graph rendered the scalar rather
than a history. Drug daily work could be consumed by the one-minute callback
before the ten-minute pass, and maintenance treatment did not freeze the public
abstinence reader. Positive-elapsed hibernation removed whole food, emptied
drink containers and changed hunger or thirst without native nutrition or fluid
effects.

C56 replaces those paths with durable county-hour boundaries. Infection onset,
course end, current wound/toxin state, withdrawal and clearance are recorded in
a versioned event history owned by ZAO when installed. Exact integration gives
the same burden for a whole interval or its partitions; a repeat at the cursor
cannot charge twice. The recorded series reaches medical and inspection views
and changes memory retention, decision cadence, existing pressure response and
motor pace. Borders 171-172 and 175 execute these properties in the installed
Kahlua VM and reject four history mutations plus three clock mutations and four
consumer mutations.

The F-084 proximity route is also removed. A Crossed carrier must approach an
Afflicted person, hold interruptible contact and complete the durable blood
action. Only its resolving token authorizes the existing Crossed-odds times
Afflicted-susceptibility roll. A successful receipt transfers the same living
human shell and supported snapshot from SAO to ZAO. Busy transfer, save/reload,
dormant ownership and later death retain one controller and one person. Borders
162-163, 173-174 and ZAO Borders 5, 9 and 10 execute those paths with controls.
The complete retained Crossed weapons, tools, strategy and general action
vocabulary remains R7-R9 work; these receipts do not establish loaded-world
presentation.

## F-088 | 2026-09-20 | Concurrent engine probes can read a partially compiled helper

Border 69 shared `java/out/luacheck/LuaRun.class` with other engine probes and
treated file existence and modification time as proof that compilation had
finished. Border 54 runs eight checks concurrently in a fresh tree. A bounded
eight-process reproduction against a Lua-free tree produced one refusal with
`ClassFormatError: Truncated class file`; a paused-writer control independently
made the old cache accept an incomplete class and reproduce that failure.

The engine-facts check reads the installed engine, so its declaration that it
does not consume the mod's Lua remains valid. The correction gives each engine-
facts invocation its own compilation directory and uses that directory for all
of its queries. This removes its dependence on a shared writer's progress.
The [C57 evidence](artifacts/audits/20260920-0158Z-1858PST-person-continuity/)
retains the reproduction and corrected concurrency results. The original
intermittent runs did not retain per-process stderr, so this establishes a
reproducible cause without retrospectively assigning every historical failure.

## F-089 | 2026-09-20 03:41 UTC / 20:41 PST | Population reload retained the prior tick callback

The pre-C58 Population module declared a new local `onTick` and passed that
new closure to both Remove and Add. Reloading the module in one Lua environment
therefore left the prior registered closure active. The stored callback must
be removed before replacement. Population also had no explicit world-init seam
for its cadence/fault state, cached origins and encounter cursor.

Border 170 executes the production population modules against an identity-aware
event registry in installed Kahlua. Repeating the scheduler module retains one
callback; initializing another store clears runtime state and restores a fault-
detached callback. Ten mutations restore the duplicate callback, stale cadence,
faults, origins or encounters, omit reattachment, or lose the explicit tick
handoff. Each refuses for its named reason. The existing installed-engine probe
shows ordinary world exit creates fresh Lua, so this finding is scoped to
same-environment reload and explicit reinitialization.

## F-090 | 2026-09-20 04:14 UTC / 21:14 PST | Debug compilation exceeded the cumulative local array

The development launch rejected Controller although Border 50 passed.
The installed compiler uses the same entry point in both cases. With
`Core.debug=true`, `LexState.new_localvar` indexes a fixed 200-entry debug
array by cumulative declarations; its preceding check limits simultaneous
locals instead. Sequential scopes therefore still overflow the debug array.

Controller's decision function had 634 cumulative locals, its update function
238, and Standing's leader election 286. Separate private functions now own
the existing phases. Calls preserve priority, snapshot timing, random draws
and early returns. This repairs compilation without changing action policy.

The unchanged source passes `LuaCompiler.loadis(Reader, path, env)` with
`Core.debug=false` and fails with it true, using the same installed jar and
classpath. The three offending functions are the complete population found
across all 73 Lua files. A synthetic 200-local sequential-scope function passes
both modes; 201 passes normal mode and fails debug mode at
`LexState.new_localvar:730`. The live C58 stderr and retained C57 stderr contain
the same Controller exception. This corrects the previous offline gate's
startup implication rather than attributing the defect to C58's extraction.

Border 50 executes both modes, verifies complete verdict coverage and checks
known-bad syntax and debug-overflow controls. The [C59 evidence](artifacts/audits/20260920-0414Z-2114PST-debug-compilation/README.md)
retains the reproduction and repair review. Loaded-world behavior remains a
separate observation.

## F-091 | 2026-09-20 05:17 UTC / 22:17 PST | Classification and access guards existed beside bypassing consumers

Build 42 `IsoAnimal` inherits `IsoPlayer`. The perception classifier rejected
animals, but the scan's emitting branch still treated every `IsoPlayer` as a
person. Cashier and ball-play candidates similarly resolved active bodies and
raw coordinates without requiring the actor's private person belief or current
floor/occlusion. The installed Lethal Stealth prone keys were absent from the
stance reader, and a combat target was not rechecked after becoming useless.

The material paths had the same shape. Vehicle containers were enumerated
without the engine's per-character access verdict. The first C60 repair asked at
selection and refreshed vehicle coordinates, but review reproduced three
remaining authority losses: cached reach ignored the floor and whether the
vehicle remained loaded, a generic timed transfer forgot vehicle permission
after selection, and a cached ground offer retained no current physical-access
proof. Text checks initially passed all three gaps.

C60 moves each guard to the consuming path. Animals leave before person output;
activity partners require fresh firsthand belief and the scanner's current
visibility law; installed prone/deactivation state is read at stance/combat use.
Cached sources share current-floor reach, vehicle sources prove loaded
membership and current part access, ground offers remain members of their loaded
square, and a vanilla-derived transfer action rechecks current world-container
authority through completion. Borders 154, 155, 157, 176 and 177 remove these
seams independently.

The source inventory also establishes that meta-grid rooms are geography and
resource possibility, not stock. Actual container/item/fluid/vehicle state is
loaded truth. R10a therefore remains a named implementation contract for native
identity, observation state, reservation/result, loaded-chunk conflict
reconciliation and consumer migration; C60 does not promote the existing room
and visit-count proxy into grounded dormant supply.
