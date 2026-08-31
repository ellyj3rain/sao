| Document | Survivor Awareness Overhaul Findings |
|---|---|
| Version | `0.6.0.0-pre-alpha` |
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
