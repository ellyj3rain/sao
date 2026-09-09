| Document | Survivor Awareness Overhaul Engine Contract |
|---|---|
| Version | `4.1.0.0-pre-alpha` |
| Author | ellyj3rain |
| Repository | `ENGINE_CONTRACT.md` |
| Status | CANONICAL - the verified engine mechanics an IsoPlayer NPC requires. |

# Engine contract — what a working IsoPlayer NPC actually requires

The complete set of load-bearing mechanisms for a drawn, safe, mobile NPC body
on Build 42.20, in lifecycle order. Sources: our own live runs (sao-1..sao-6),
`javap` against the installed jar, and reference reading of the working
implementation at `../KnoxSurvivors` (cited as `KNF` = KnoxNpcFactory.java,
`KSD` = KnoxIsoPlayerShellDefinition.java, `KN` = KnoxNpc.java). Our
implementation lives in `java/src/com/sao/` and `mod/42.20/media/lua/`.

Each mechanism records the failure you get without it — every one of these was
either observed live in our runs or is compensated explicitly in the reference.

## 1 · Class: a subclass, not IsoPlayer itself

A bare non-local `IsoPlayer` never draws (live: sao-1..sao-3, all flags green,
invisible). The body must be a subclass (`KSD:8`, F-009) with four behavior
patches (`KSD:138-232` comments):

| Override | Semantics | Failure without it |
|---|---|---|
| `isLocalPlayer() -> true` | zombie target/attack checks gate on it | zombies ignore or mishandle the NPC |
| `getAimVector -> getForwardDirection` | off-slot bodies have no mouse/controller aim source | aim resolves from a missing input channel |
| `updateLOS() -> no-op` | inherited version writes per-player alpha from this NPC's viewpoint | the real player and other NPCs fade |
| `update()` preserves the global player | `updateInternal2` assigns the receiver to `IsoPlayer.getInstance()` even for NPCs | camera/UI/Lua resolve an NPC as "the player" |

Plus an isolated `CharacterInputComponent` so the engine never reads slot-0
input through the NPC. Ours: `SAOIsoPlayerShell.java`.

## 2 · Construction and registration (spawn sequence)

`KNF.create` (`KNF:20-80`), ported in `SAOBridge.spawnShellNamed`:

```
new Shell(cell, desc, x, y, z, false)
setNpc(true)
remote = false
playerIndex = first free slot ABOVE 0        // slot 0 owns the system cursor:
serverPlayerIndex = -1                        // updateCursorVisibility hides it
setOnlineID(-1)                               // while index 0 aims (KNF:731-737)
setUsername(...)
setGhostMode(false)
setCurrent(square); setMovingSquareNow()
setZombiesDontAttack(false)                   // capability-gated in B21; differs
setAlphaAndTarget(1.0)                        // between normal/debug launches (KNF:66)
cell.addMovingObject(body)
ModelManager.instance.Add(body)               // WITHOUT THIS NOTHING DRAWS
verify players[] unchanged, else roll back    // slot-safety invariant
clear all movement intent                     // see §4
```

Visuals: `dressInRandomOutfit()` + `resetModelNextFrame()` (shipped-Lua idiom)
— construction alone yields a model-less body.

## 3 · Teardown

`KNF.safelyRemove` (`KNF:959-971`), ported in `SAOBridge.removeShellInternal`:
clear intent → `ModelManager.instance.Remove` → `setMovingSquare(null)` →
`removeFromWorld()`. Skipping the ModelManager removal leaks render
registrations across the body's lifetime.

## 4 · Movement intent — why an NPC wanders or stands

B21 skips normal input processing for `isNpc()` bodies; their update consumes
**two** intent surfaces, and both must be managed (`KNF:763-921`):

- **Body-level**: `playerMoveDir.x/y` (world direction), `setJustMoved(true)`,
  `setDirectionAngle(degrees)`, `setRunning/setSprinting/setSneaking`.
- **Control vars** (`AIComponent.getHumanControlVars()`): `justMoved`,
  `running`, and `strafeX/strafeY` in **animation control-space** — world
  direction with Y flipped, rotated by `getAnimAngleRadians()`
  (`KNF:903-921`), not world space.

Failures observed live: intent never zeroed after construction → the body
wanders on its own (sao-3). Control vars written in world space without
body-level intent → walk animation, zero displacement (sao-5).

Zeroing both surfaces is the stop contract (`KNF:923-947`,
`SAOBridge.clearMovementIntent`).

## 5 · Routes — the engine computes, the framework follows

`PathFindBehavior2` is a route **computer**, never left active as a follower:

1. Request: `pathToLocationF(x+0.5, y+0.5, z)`.
2. Poll `update()` only until a path exists (`Working` + `getPath2()`
   non-empty). `Failed` during this phase is a genuine no-route verdict.
3. **Capture the nodes, then `cancel()` the behavior and `setPath2(null)`**
   (`KNF:380-396`). Leaving the behavior active while the body is between
   drive ticks trips its own walking-on-the-spot stall detector, which
   terminates the walk as `Failed` (live: sao-6, `terminal: Failed` at the
   spawn square; the detector is the public `walkingOnTheSpot` field).
4. Drive node-to-node: advance within 0.35 tiles, per-tick §4 intent toward
   the current node (`KNF:398-448`), arrival = nodes exhausted.

**Exception — live pursuit** (`KNF:148-166`): chasing an `IsoGameCharacter`
uses `pathToCharacter` with the behavior left active — a moving goal defeats
the stall detector, and two movement owners must never coexist ("do not leave
a Knox waypoint route active beside it").

Single-edge crossings synthesize a one-node route directly (`KNF:168-196`).

## 6 · Traversal transitions (doors, windows, edges)

Per-edge checks while driving (`KNF:449-560`, state model `KN:17-30`):

- Z changes: unsupported (explicit FAILED state, not a silent stall).
- Diagonals: `isBlockedTo` between squares.
- **Doors**: `getDoorTo` → if closed: face it (`shouldBeTurning` gate), then
  `ToggleDoor(body)` — the same world action a player uses. Locked/barricaded
  are explicit failures.
- **Windows**: `getWindowTo` → climbing gate → barricade check → monitor
  `OpenWindowState`; B21 quirk: that state only toggles the world object for a
  local player, so the omitted world-state step is completed manually after
  the animation reports success (`KNF:552+`).
- **Failed edges cool down** (`KN:58-100`): 5 s for locked/barricaded, 1.8 s
  otherwise — the survivor tries another route instead of repeating the same
  edge forever.

## 7 · ECS access

`body.getECSComponent(AIComponent.class)` is the direct accessor
(`KNF:949-952`; `ECSEntity` default methods). Kahlua cannot iterate the
component map (live: "iterator of non-table"), so any component access belongs
Java-side. Our bridge's map loop should migrate to the typed accessor.

## 8 · Load path

ZombieBuddy loads Java mod jars in-process from `mod.info` keys
(`javaJarFile=`, `javaPkgName=`, entry `<pkg>.Main.main()`), with an approval
store. This is the shipping path — no agent, no launcher, no env vars.
Dev-only alternative: `-javaagent` via `JAVA_TOOL_OPTIONS` requires
`jre64\bin` on PATH for `instrument.dll` dependencies, and only the exe launch
path boots reliably (the shipped `.bat` omits `-agentlib:zbNative` and other
exe-config vmArgs; both `java.exe` launch attempts produced broken windows).

## 9 · Movement supervision (KnoxNpcRuntime, read in full)

One in-flight move request per body, supervised (`KnoxNpcRuntime.java`):
`beginMove` records start/target; `tickMovement` measures real displacement
and fails the request as `FailedStuck` after 45 ticks under 0.12 tiles of
progress — but ONLY in locomotion states. Turning, climbing and door/window
actions "legitimately hold the survivor in place" and are excluded from the
stuck check (`KnoxNpcRuntime:131-140`). Arrival distance 0.65. Every state
transition is logged. Terminal states reset pace to normal.

## 10 · NPC melee (KnoxCombatController, read in full)

Outgoing combat drives IsoPlayer's NORMAL attack entry, not a synthetic hit:

- Preconditions: `SwipeStatePlayer` class loaded, the animation-callback patch
  live (`KnoxCombatGate.isPatchReady()`), a real `HandWeapon` equipped.
- Phases IDLE→APPROACHING→AIMING(18 ticks)→ATTACKING with re-approach when the
  target moves outside `weaponMaxRange-0.40` (+0.20 buffer); pursuit refresh
  at most every 6 ticks.
- The swing itself: face target (`setTargetAndCurrentDirection` +
  `setForwardDirection` + `setDirectionAngle`), stance
  (`setAuthorizeMeleeAction`, `setIsAiming`, `isCharging=true`), then
  `useChargeDelta=36` and **`pressedAttack()`** — the same entry a real player
  presses — plus `setAttackStarted/setInitiateAttack` and AI-vars
  aiming/initiateAttack. Retry every 30 ticks when the previous cycle ended
  and `AttackType` is clear.
- Fallback: if no attack animation within 3 ticks and the action context is
  idle, `changeState(SwipeStatePlayer.instance())` directly, once.
- Between swings in live combat: yield a 24-tick defense window, clear
  `AttackType` (a stale value makes a frontal zombie collision return before
  damage is applied), and never override a hit-reaction action — reapplying
  input during `hitreaction*` suppresses the visible reaction.
- Floor targets: `setAimAtFloor` + `setAuthorizeShoveStomp` (stomp).
- Verdicts are evidence-based: SUCCEEDED requires observed damage, not just a
  dead target ("TARGET_DIED_WITHOUT_NPC_DAMAGE" is a FAIL).

## 11 · Incoming combat — making zombies fight an off-slot body
(KnoxHealthController, read in full)

An off-slot shell runs no local-player LOS updates, so vanilla zombie
perception starves. The acquisition bridge compensates surgically:

- `spotted(body, true)` + `setTarget` + `pathToCharacter` for pursuit.
- `vectorToTarget` and `lastTargetSeenX/Y/Z` mirrored manually — vanilla
  attack eligibility reads that live vector (`refreshZombieTargetVector`).
- Inside 1.0 tiles: private `canSeeTarget=true` and `targetSeenTime >= 0.55`
  (Zombie_Bite_Start gates on `targetSeenTime > 0.5`; resetting it every
  refresh keeps the animator ineligible forever). The perception vector is
  clamped to 0.70 because bAttack's threshold is 0.72 while the collision
  event accepts DistTo 1.0.
- Attack entry only from idle/lunge/walktoward/pathfind/turnalerted — never
  from hit reactions, falls, climbs or get-ups (forcing attack from
  hitreaction leaves the zombie in an invalid half-recovered loop).
- Terminal flags `AttackDidDamage`/`ZombieBiteDone` cleared before entry, and
  **both combat layers entered**: legacy `changeState(AttackState.instance())`
  for the collision callback AND the action-context `attack` state for the
  animation graph — setting only one leaves `ZombieIdleState/action=attack`
  that never reaches the damage event.
- `getShouldAttack()` (private, reflected) remains the authority; every other
  vanilla guard stays live.
- Health surface: `getBodyDamage()` health/parts/bleeding; controlled-injury
  and full-restore helpers for gated testing.

## 12 · The animation-callback patch (KnoxSwipeStateTransformer)

Melee animation callbacks contain local-player checks; the transformer
redirects exactly three of them to a predicate that also recognizes the shell
— "the callback bodies remain the game's own code." Without it, an NPC swing
animates but its hit callback never fires. This is the one place bytecode
transformation is genuinely required; combat refuses to start unless the
patch reports ready.

## 13 · Registry, persistence, and the API shape (KnoxNpcRegistry / KnoxBridge)

- Registry: `LinkedHashMap<id, KnoxNpcRuntime>`, all entry points
  synchronized, every operation answering a STRING verdict — the Lua side is
  a consumer of legible one-line results, exactly the harness discipline.
- Persistence: `captureRecord` → encoded string → `restorePersistentRecord`
  reconstructs at the recorded square (`restoreExactPosition`); recreate
  verifies capture→restore round-trips (`RECREATED matches=`).
- `abandonForEnvironmentChange()` drops runtimes when the Lua environment is
  replaced (world change) — body handles die with their world.
- Bridge API (~60 verbs): spawn/remove/move/cross/tick/cancel per id,
  climbing + protected-area toggles, equipment (seed, equipBest, wear/dress),
  combat begin/tick/reset + zombie direction + diagnostics, health gates,
  record capture/restore, render diagnostics. Verb-per-action, id-addressed,
  string-verdict — the contract SAO's bridge should converge on.

## 14 · Their Lua brain (structural read)

`KS_SurvivorAutonomyController.lua` (116 KB): threat selection with
per-target reservations (prevents dogpiling), flee heuristics, supply search,
directive-scoped exploration, formation following with pace matching, rest
spots. It calls the Java runtime's verbs; the division is brain-in-Lua,
body-in-Java. Two notes for SAO: (a) the reservation pattern is worth
carrying; (b) their brain reads world state directly (`nearestThreat` scans
the cell) — the omniscience SAO's Perception pillar exists to replace. The
engine contract above is pillar-neutral; everything in §1-13 is Execution
plumbing either way.

---

# Addendum A ([A11]): surfaces verified after the founding fourteen sections

Extends the contract; nothing above this line is rewritten.

## A.1 Timed-action queue seam ([A8], [A8], [A9], [A10])

`ISTimedActionQueue.queues` is keyed by the character OBJECT; `add()` has
no local-player gate (the only isLocalPlayer branch is corpse-drag halo
text). `begin()` -> `character:StartAction(action)` - per-character engine
machinery pumped by the character's own update; shells qualify. Verified
action constructors used: `ISEatFoodAction:new(character, item, pct)`
(complete() = `Eat(item, pct, utensil)`), `ISInventoryTransferAction:new(
character, item, src, dest)` (isValid demands src:contains(item); reach is
the caller's problem), `ISDrinkFluidAction:new(character, item, pct)`
(`DrinkFluid` at updateEat), `ISTakeWaterAction:new(character, nil,
waterObject, nil)` (item=nil drinks DIRECTLY, sized by the drinker's own
THIRST stat), `ISApplyBandage:new(character, character, item, bodyPart,
true)` (perform() reaches ISHealthPanel, which nil-guards unknown player
numbers - off-slot safe), `ISReloadWeaponAction:new(character, gun)`
(sources magazines/rounds from the actor's inventory; anim-timed).

## A.2 Fluid surface ([A8])

`InventoryItem.getFluidContainer()` -> `FluidContainer.getPrimaryFluid()/
getAmount()/isEmpty()`; `Fluid.Water/SodaPop/Tea/Coffee` constants exist
(`Fluid.Juice` does NOT - caught at build). World water: `IsoObject
.hasFluid()/getFluidAmount()/isTaintedWater()`. Ammo resolution ([A10]):
`InventoryItem.getAmmoType()` -> `AmmoType.getItemKey()` (loose-round item
type); `HandWeapon.getMagazineType()/getAmmoBox()` are plain strings.

## A.3 Stair seams ([A9])

Stairs are WALKED: crossing stair squares carries the body between floors
under ordinary body-level drive. A one-floor node step is CLEAR when the
seam carries stair geometry (`HasStairs`/`HasStairsBelow` on the current
square or the next column at either floor); Z changes without stairs stay
loud failures. Node advance requires z agreement (<0.8) - XY-coincident
nodes at a stairwell would otherwise skip route steps. Live walk still
pending; the first stairwell judges it.

## A.4 SwipeStatePlayer gate map, ranged ([A10])

Constant-pool audit by bytecode form. STATIC `isLocalPlayer(IsoGameCharacter)`
sites (the transformer's swap pattern): AttackCollisionCheck (patched),
PlaySwingSound (patched), PlaySwingSoundAlways (patched),
GrappleGrabCollisionCheck (unpatched, irrelevant), WeaponEmptyCheck
(unpatched - empty-click handling only), SetVariable x2 (unpatched -
did not block the live melee cycle). VIRTUAL `isLocalPlayer()` sites pass
via the shell's override, including `checkRangedWeaponFailedToShoot`.
`OnAnimEvent_ShotDone` carries NO gate: the shot resolves for anyone in
the state. Conclusion: ranged fire rides the existing pressedAttack cycle
with the existing three patches. NPC aim accuracy remains the open live
question.

## A.5 Worn-clothing restore ([A11])

`InventoryItem.getBodyLocation()` -> `ItemBodyLocation`;
`IsoGameCharacter.setWornItem(ItemBodyLocation, InventoryItem)` dresses a
shell; `resetModelNextFrame()` after. Random outfits belong to a first
body only.

## Addendum B - 42.20.4 re-verify ([A19], javap against the installed jar)

The operator's install moved to 42.20.4 (b0bbce05d5). Re-verified seams:

- **SwipeStatePlayer restructured**: the three `OnAnimEvent_*` melee
  callbacks are GONE (a single `dbgOnGlobalAnimEvent` appears; swing
  logic folded into `enter`). Four `isLocalPlayer` sites remain and all
  are `invokevirtual isLocalPlayer()Z` - the VIRTUAL form our shell
  overrides to true.
- **`IsoPlayer.isLocalPlayer(IsoGameCharacter)` (static)** now reads
  `instanceof IsoPlayer && virtual isLocalPlayer()` - it routes through
  the override. A new `isLocalPlayer(Object)` static overload exists.
- **Consequence**: the melee-callback patch is UNNECESSARY on 42.20.4 -
  every gate, static or virtual, admits the shell natively through its
  override. The transformer now recognizes the zero-static-sites shape,
  marks the gate genuinely ready, and logs PASS instead of ERROR. On a
  42.20.3 install the old patch path still runs unchanged.
- `Registries.CHARACTER_PROFESSION`, `CharacterProfession.register`,
  `SurvivorDesc.setCharacterProfession`, and the SpawnRegions
  profession-keyed points were all verified on this same 42.20.4 jar at
  [A18]-[A18]; compiles are clean against it.

## Addendum C - the 42.20.4 evidence ledger ([A24], all javap against the installed jar)

Accumulated engine verifications from the [A22]-[A24] audit rotation,
recorded so the contract carries its proofs:

- `PathFindBehavior2$BehaviorResult` = { Working, Failed, Succeeded } -
  the movement verdict contract's exact string domain ([A24]).
- `getCurrentAmmoCount()` MOVED UP from HandWeapon to `InventoryItem`
  (public there); the old reflective lookup still resolved via
  inherited-public search and was modernized to a direct call ([A24]).
- `IsoPlayer.instance` remains a private static field of that name (the
  shell's global-reference restore); `getAimVector(Vector2)` and
  `updateLOS()` signatures unchanged ([A24]).
- `IsoZombie`: `canSeeTarget` private field, `getShouldAttack()`
  private method, `vectorToTarget` public final, `lastTargetSeenX/Y/Z`
  public, seen-time accessors public - every director touchpoint
  ([A24]).
- `Registries.CHARACTER_PROFESSION` public static
  `Registry<CharacterProfession>` (iterable; keys() ->
  ResourceLocation with namespace = registering mod);
  `CharacterProfession.register(String)` is the mod seam; 25 vanilla
  paths extracted from the constant pool ([A18]-[A18]).
- `SurvivorDesc.setCharacterProfession/setProfessionSkills`;
  `CharacterProfessionDefinition.characterProfessionDefinitions`
  public static map with `getXpBoosts()`;
  `IsoGameCharacter.getPerkLevel/setPerkLevelDebug` ([A18]/[A19]).
- SpawnRegionMgr regions carry `points` tables KEYED BY PROFESSION
  PATH - the engine's own where-were-you map ([A18]).
- `IsoGameCharacter.dressInNamedOutfit(String)` + 235 outfit names
  enumerated from media/clothing/clothing.xml ([A20]).
- `Events.OnPlayerDeath` verified in shipped Lua ([A22]).
- SwipeStatePlayer's melee gates went VIRTUAL on 42.20.4 (Addendum B,
  [A19]) - the shell override governs natively.
- Locale law ([A23]): every parsed float crossing the Java->Lua
  boundary formats with Locale.ROOT; Double.toString concatenations
  are locale-safe by the JLS.

## Addendum D - the B-era evidence ledger (42.20.4, all verified before use)

One place to re-verify from at the next 42.x bump. Every surface below
was checked by javap against the installed jar, by reading vanilla's
own Lua use, or by compiling against it - never by assuming a name.

| Surface | Used for | How verified |
|---|---|---|
| `IsoCell.getVehicles()`, `BaseVehicle.getMaxPassengers/isSeatOccupied/getScriptName` | the motor-pool claim | javap |
| `BaseVehicle.enter(seat, char)` / `exit(char)` | seating a crew | javap + vanilla `ISEnterVehicle` reads these under its timed action |
| `InventoryItem.getFluidContainerFromSelfOrWorldItem()`, `FluidContainer.getAmount/getFreeCapacity/addFluid`, `Fluid.Water` | water carried and counted | javap; the `Fluid` package was WRONG on first guess (`zombie.fluids`) and corrected at compile |
| `IsoObject.hasFluid/getFluidAmount/isTaintedWater/useFluid` | drawing from real sources | javap (pre-existing, reused) |
| `IsoWorld.instance.isHydroPowerOn()` | the county's mains | javap |
| `IsoFireplace.isLit/hasFuel/getFuelAmount/addFuel/setLit` | the hearth | javap (`isLit` found only via `-p`) |
| `InventoryItem.getMinutesToBurn()` | what counts as fuel | javap + vanilla `ISInventoryPane` uses it |
| `Thermoregulator.getCoreTemperature()` | how cold someone is | javap; **this replaced `BodyDamage.getColdStrength()`, which is the cold ILLNESS** - the field's declaration neighbours (catchACold, sneeze timers) are what gave it away |
| `BodyDamage.getGeneralWoundInfectionLevel`, `BodyPart.getWoundInfectionLevel/setWoundInfectionLevel/getAlcoholLevel/setAlcoholLevel/bandaged/isBandageDirty/SetBitten` | medicine and the dormant wound | javap |
| `InventoryItem.getAlcoholPower()` | what cleans a wound | compile-verified |
| `Item.getReduceInfectionPower()` (script item) | what treats sickness | pcall-guarded read |
| `CharacterStat.INTOXICATION/PAIN/PANIC/STRESS/ANGER/MORALE` | the meeting's temper | javap enum listing |
| `SFarmingSystem.instance:getLuaObjectOnSquare`, plant `state`/`waterLvl`/`canHarvest()`, `ISPlowAction`/`ISSeedActionNew`/`ISWaterPlantAction`/`ISHarvestPlantAction`, `ISFarmingMenu.canDigHereSquare/getWaterUsesInteger`, `farming_vegetableconf.props`, `ItemTag.DIG_PLOW` | farming | read from KnoxSurvivors' working executors AND vanilla's own files; module presence guarded because these globals are indexed at argument-evaluation time |
| `ISBarricadeAction`, `IsoObject.isBarricadeAllowed/getBarricadeForCharacter`, `Barricade.canAddPlank` | boarding windows | vanilla + KS reads |
| `IsoPlayer.players` (slot array) | telling the real player from other mods' NPCs | javap; the basis of the `foreign:` key domain |
| `IsoGameCharacter.getHealth()` | the condition bracket | javap + vanilla `player:setHealth(1.0)` proves the 0..1 scale |
| `SurvivorDesc` on `IsoDeadBody` and zombies | recognizing the turned | CORRECTED [C8]: javap proved the FIELD, not the flow. The corpse ctor copies the character's descriptor AND modData (offsets 1007-1019, 1102-1113); `reanimate()` gives the zombie a FRESH descriptor (gender + voice only, offsets 43-74) and copies the CORPSE's modData onto it. Names survive to the corpse and die at reanimation; the modData id survives the whole turn (F-044/F-045) |
| `PerkFactory.PerkList` + `getPerkLevel`, `CharacterProfessionDefinition.getXpBoosts` | reading skill live and dormant | javap; `CharacterProfession.get` needs a `ResourceLocation`, corrected at compile |

## Addendum E - the broadcast and print schedule surface (2026-09-06, javap against the installed jar)

Verified for DR-031 before it was recorded: what the engine keys the
shipped record of the fall to, and where a mod can move it. Nothing
here is built yet; this is the surface the Day Zero arc's slice 7
will stand on.

| Surface | What it is | How verified |
|---|---|---|
| `ZomboidRadio.daysSinceStart` (private int; `getDaysSinceStart()`) | the schedule's clock: seeded from `GameTime.getNightsSurvived()` in `Init(int)`, written and read as `DaysSinceStart` in the radio save file, incremented at the hour-0 rollover in `UpdateScripts(hour, minute)` (called from `GameTime`; single-player and server only) | javap -c |
| `RadioAPI.timeToTimeStamp(day, hour, minute)` = day x 1440 + hour x 60 + minute; `timeStampToDays/Hours/Minutes`; `RadioAPI.getInstance().getChannels(category)` returns a Lua table | the stamp arithmetic and the Lua-facing channel list | javap -c |
| `RadioScript.setStartDayStamp(day)` sets `startDay = day` and `startDayStamp = day x 1440`; `UpdateScript(stamp)` sets `internalStamp = stamp - startDayStamp` and picks the next broadcast from it | a script's own zero; public | javap -c |
| `RadioChannel.setActiveScript(name, startDay)` and `(name, startDay, loopMin, loopMax)`: `Reset()`, `setStartDayStamp`, loop count from `Rand.Next(loopMin, loopMax)`; `setActiveScriptNull()`; `LoadAiringBroadcast(id, line)` | switch a channel's script and re-key it; public | javap -c |
| `RadioScriptManager.simulateScriptsUntil(stamp, bool)` / `simulateChannelUntil(freq, stamp, bool)` (skips time-synced channels); `AddChannel(channel, bool)` / `RemoveChannel(freq)`; `getChannels()` keyed by frequency; `getRadioChannel(guid)` | catch a schedule up to a stamp; add or drop stations | javap |
| `RadioChannel.AddRadioScript`, `RadioScript.AddBroadcast(RadioBroadCast[, bool])`, `RadioBroadCast(id, startStamp, endStamp)` + `AddRadioLine(RadioLine)`, `RadioScript.AddExitOption(name, chance, x)` | build or extend broadcasts in code | javap |
| `RadioData.fetchAllRadioData()` -> `searchForFiles`; per-file `isVanilla`, `RadioChannel.isVanilla()`; `ZomboidRadio.Init(int)` registers every channel of every file found | the loader takes non-vanilla radio XML too | javap -c |
| `ZomboidRadio.checkGameModeSpecificStart()` | the engine's own re-keying: when `Core.gameMode` is "Initial Infection" every channel's `init_infection` script is activated at `daysSinceStart` and stamped `daysSinceStart + 1`, with an exit option back to the running script (100, 0); when it is "Six Months Later", `Classified M1A1` goes to `numbers` and `NNR Radio` to `pastor`, both at `daysSinceStart` | javap -c (the string constants of the method) |
| `ZomboidRadio.disableBroadcasting` / `setDisableBroadcasting`, `postRadioSilence`, `louisvilleObfuscation`, `getRecordedMedia()` | the switches the engine exposes | javap |
| The shipped schedule: 18 `ChannelEntry` in `media/radio/RadioData.xml` (5 radio, 10 television, 2 amateur, 1 military), 905 broadcasts on days 0-27 (news to day 11, Triple-N's recorded loop on day 12, TURBO's static to day 27); 13,166 lines in `Translate/EN/RadioData.json` keyed `RD_<LineEntry ID>` | what there is to re-key | read with a join script over the two files |
| `Newspaper` (`zombie.scripting.objects`): four registered papers with fixed issue lists - `KentuckyHerald` July 6/13/14/15/16, `KnoxKnews` July 1-6, `LouisvilleSunTimes` July 6/13/14/15/16, `NationalDispatch` July 6/7/12/13/14/15 - `getIssues()`, `getTitle(issue)`, `getTranslationInfoKey/TextKey`; `Registries.NEWSPAPER` | the print record and its keys into `Print_Text.json` | javap -c (the static initializer's string constants) |
| `RecipeCodeHelper.nameNewspaper(item, paper)` (public static; called by `ItemCodeOnCreate.onCreate{Dispatch,Herald,Knews,Times}NewNewspaper` and `onCreateRecentNewspaper`, which first draws a random paper from the registry) | picks `Rand.Next(getIssues())`, or `issues.get(size - 1)` - the newest - when the item has `ItemTag.NEWSPAPER_NEW`; then `item.setName(Translator.getText(title))` and `setPrintMediaInfo`, which writes a `printMedia` table (title, info, id, text) and `literatureTitle` into the item's modData. **No call reads the game day.** | javap -c |
| `Newspaper_{Dispatch,Herald,Knews,Times}_New` in `scripts/generated/items/literature.txt` (`OnCreate = ItemCodeOnCreate.onCreate...NewNewspaper`, tags `base:newspaper;base:fastread`); `newspaper_dispatch` / `newspaper_herald` ... procedural lists in `lua/server/Items/Distributions.lua` | how the papers reach the world: loot rolls, no date | read from the shipped files |

## Addendum F - what the engine holds per person (2026-09-06, javap against the installed jar and the generated scripts)

Verified for DR-032 and for the Speakeasy scoping index: the whole
of what a character IS to the engine, and what it is not.

| Surface | What it is | How verified |
|---|---|---|
| `SurvivorDesc.getForename/getSurname/getFullname`, `isFemale`, `getCharacterGender` | name and gender | javap -p |
| `IsoGameCharacter.getAge()` / `setAge(int)` | an age integer that NOTHING reads: the only references to the field are inside `IsoGameCharacter` itself (constructor, getter, setter); `IsoPlayer`, `IsoZombie`, `HumanVisual`, `SurvivorDesc`, `SurvivorFactory` reference neither the field nor the getter. No body, animation or behavior changes with age | javap -c, reference count per class |
| `SurvivorDesc.getCharacterProfession()`, `isCharacterProfession(...)`; `scripts/generated/characters/character_professions.txt` | 25 shipped `character_profession_definition` blocks (burglar, burgerflipper, carpenter, chef, constructionworker, doctor, electrician, engineer, farmer, fireofficer, fisherman, fitnessinstructor, lumberjack, mechanics, metalworker, nurse, parkranger, policeofficer, rancher, repairman, securityguard, smither, tailor, unemployed, veteran), fields `CharacterProfession`, `Cost`, `UIName`, `UIDescription`, `IconPathName`, `GrantedTraits`, `XPBoosts`; mods register through the same script form | javap -p; grep of the generated script |
| `IsoGameCharacter.getCharacterTraits()`, `hasTrait(CharacterTrait...)`, `applyTraits(List)`; `scripts/generated/characters/character_traits.txt` | 97 shipped `character_trait_definition` blocks, fields `CharacterTrait`, `Cost`, `IsProfessionTrait`, `DisabledInMultiplayer`, `UIName`, `UIDescription` (84), `MutuallyExclusiveTraits` (70), `XPBoosts` (35), `GrantedRecipes` (18), `GrantedTraits` (2). None concerns memory or cognitive decline; the knowledge-bearing ones are illiterate/slowreader/fastreader, deaf/hardofhearing/keenhearing, slowlearner/fastlearner | javap -p; grep of the generated script |
| `SurvivorDesc.getBravery/getLoner/getAggressiveness/getCompassion/getTemper/getFriendliness/getFavourindoors/getLoyalty` | eight personality floats | javap -p |
| `SurvivorDesc.getVoicePrefix/getVoiceType/getVoicePitch`, `getHumanVisual`, `getWornItems`, `getObservations()`, `getDescription(String)`, `getMetCount`, `getGroup/isLeader`, `getXPBoostMap` | voice, appearance, the engine's own observations and descriptions, acquaintance counts, group | javap -p |
| `SurvivorFactory$SurvivorType` | Friendly, Neutral, Aggressive - the only kinds of survivor the factory knows | javap -p |
| Class-name search of the jar for child, kid, elder, aging | nothing (the only "age" classes are damage, texture pages and `AnimalGrowStage`); the engine ships no child or elder body | `unzip -l` grep |
| `ModelInstance.scale` (public float), `applyModelScriptScale`; `ModelScript.scale` | NOT a per-character scale: `ModelInstance.scale` is read by `BaseVehicle` alone; `ModelScript.scale` by `IsoObjectModelDrawer` (world objects) and `ItemModelRenderer` (items) only; no reader in the character or skinned-model render path; `ModelInstance` is not in the vanilla Lua exposer. A calf is its own mesh, not a scaled cow. Recorded 2026-09-06 to withdraw an earlier claim in DR-032 | javap -c over every class under skinnedmodel, iso/objects, characters, ui, vehicles, scripting/objects; the exposer's constant pool |
| `AnimationPlayer.boneTransforms` (public `AnimatorsBoneTransform[]`), `modelTransforms` (private `Matrix4f[]`), `getBoneTransformAt(int)` | the only place a human body's size or proportion could be changed: the bone transforms the renderer draws from. Realism V4 does it by replacing the class; SAO does it by weaving the class ([C29]) | javap -p |
| `AnimationPlayer.updateModelTransformsInternal()` (private) | builds `modelTransforms[i]` = `boneTransforms[i].getMatrix()` times `modelTransforms[parent]` (`BoneTransform.mul`), bone by bone - the seam [C29]'s exit advice sits on | javap -c |
| `AnimationPlayer.getSkinTransforms(SkinningData)` | `skinTransformData.transforms[j]` = `modelTransforms[boneMap[j]]` times `skinningData.boneOffset[j]` (`Matrix4f.mul`); consumed by `Model` (21 references), `AnimatedModel` (3) and `ModelInstanceRenderData` (2) - the render path, which is why scaling the model transforms scales the drawn body | javap -c |
| `getModelTransformsCount()`, `getModelTransformAt(int)`, `getIsoGameCharacter()`, public `parentPlayer` | the public surface the woven scaler uses: the matrices by reference, and the character they belong to | javap |
| `AnimationPlayer` is `final` and pooled (`PooledObject`, `s_pool`) | instances are reused across characters, so a size is keyed on the character (the shell's `bodyScale` field), never on the player | javap -p |
| Byte Buddy 1.18.8 inside `ZombieBuddy.jar` (`net.bytebuddy.ByteBuddy`, `agent.ByteBuddyAgent`, `asm.Advice`, `agent.builder.AgentBuilder`); the ZombieBuddy manifest declares `Can-Retransform-Classes: true` | the weaver and the self-attach the body scale rides - the path Main already takes for the melee patch | jar listing; manifest |
| `IsoGameCharacter.setSpeedMod(float)` / `getSpeedMod()` | the pace of the age ([C30]): a child's and an elder's walk, set once at materialize | javap |
| `Stats.get/set/add/remove(CharacterStat, float)`; the `CharacterStat` values include ENDURANCE, FATIGUE, PAIN, STRESS, PANIC, SANITY | what the age drift moves ([C30]); NO `setTripping` or tripping stat exists on 42.20's `Stats` (Getting Old's stumble calls one and would throw here) | javap; the enum's constant list |
| `IsoGameCharacter.getBodyDamage().getOverallBodyHealth/setOverallBodyHealth`, `getHealth/setHealth` | an elder's decline once marked, so the body dies on the engine's own path | javap (pre-existing surface, reused) |
| `IsoGameCharacter.setPerkLevelDebug(PerkFactory$Perk, int)`, `getPerkLevel(Perk)`; the Lua-exposed `Perks.<Name>` | the birthday floors on strength and fitness ([C31]); vanilla's own stats screen reads `Perks.Strength` from Lua | javap; grep of the shipped Lua |
| `IsoGameCharacter.getZombieKills()` | what hardens a child's fear ([C31]) | javap |
| `HumanVisual.getHairModel/setHairModel(String)`, `getBeardModel/setBeardModel(String)`; `IsoGameCharacter.resetBeardGrowingTime()`; the style names in `media/lua/shared/Definitions/HairOutfitDefinitions.lua` | the child's head ([C31]) | javap; the definitions file read whole |
| `ItemContainer.AddItem(String)`, `containsTypeRecurse(String)` | the kit a child carries, and the comfort object read back ([C31]) | javap |
| `GameTime.getTimeOfDay()` (float, 0 to 24) | the night ([C31]) | javap |
| `Stats.set(CharacterStat, float)` returning boolean, with `CharacterStat.PANIC` on the engine's 0 to 100 scale | the fear floor held on the body ([C31]) | javap |
| `IsoGameCharacter.isAsleep()` / `forceAwake()` | exist, unused: SAO's sleep is the agent's state, so Growing Up's nightmares have no seat yet ([C31], not in this batch) | javap |
| `IsoGameCharacter.getXp()` -> `IsoGameCharacter$XP`: `getXP(Perk)`, `AddXP(Perk, float)` (a negative amount takes experience, as Neurodiverse Traits does), `setXPToLevel(Perk, int)`; `IsoGameCharacter.LoseLevel(Perk)` | dementia's daily skill loss ([C32]) | javap |
| `PerkFactory$Perk.getParent()`, `getXpForLevel(int)`, `getTotalXpForLevel(int)`; `PerkFactory$Perks.None/Passiv/Agility` (static fields); `PerkFactory.PerkList` | which skills forget and how much ([C32]) | javap |
| `mod.info` `require=` | the two condition mods for the player's side ([C32], DR-032): `twbInfirmities` (3579088411), `EvenMoreTraits4220` (3777663603) | the Workshop pages' own id lines |
| `GameEntity.getFluidContainer()` (final; `InventoryItem extends GameEntity`), `InventoryItem.isFluidContainer()`; `FluidContainer.isEmpty/getAmount/getFilledRatio/isCategory(FluidCategory)`; `FluidCategory.Alcoholic`; the fluids in `scripts/generated/fluids_Alcoholic.txt` (Beer alcohol 0.05, ...) | Build 42 keeps beer, wine and whiskey as fluids in the Alcoholic category, not as food: the drink a drinker takes and the source it is taken from ([C33]). `InventoryItem.isAlcoholic()` is the bandages' flag (`AlcoholBandage`), not a drink's | javap; the generated scripts |
| `ISDrinkFluidAction:new(character, item, percentage)` (shared TimedActions; `complete()` applies the fluid's properties) | the drink itself, and the wrap that counts it ([C33]) | the shipped Lua |
| `BaseAction.setAnimVariable(String, String)`, `setActionAnim(String)`; `stopOnWalk`, `stopOnAim`, `forceStop`; the player's `actions` animation state entered by any timed action | a gesture is a timed action carrying one animation variable, and SAO's nodes under `AnimSets/player/actions` read it ([C35]) | javap; the shipped Lua's `ISBaseTimedAction:setAnimVariable` |
| `AnimSets/player/sitonground-sitting` (`sit_loop`, `sit_action` keyed on `hasTimedActions`, `m_Priority`) | the seat's variants ride the engine's own sitting state, keyed on a variable SAO sets ([C35]) | the shipped animation sets |
| `IsoGameCharacter.setVariable(String, String)`, `clearVariable(String)`, `playEmote(String)`, `playSound(String)` | the seat variable, the engine's own emotes for greetings and partings, the coughs and claps ([C35]) | javap |
| Animations load from any mod's `media/anims_X` by name; the copied files carry the Bip01 rig (`Bip01_Pelvis` ... `Bip01_Prop2`) the player model and its animations use, though Week One kept them under a `Zombie` folder and binds them to the zombie tree | the art crosses skeleton-true; the binding is what a mod writes ([C35]) | the files' own bone names; Hobbies' flat `anims_X` and its player-tree nodes |
| `RecipeCodeHelper.setPrintMediaInfo(item, title, info, text, id)` (public static; the bytecode writes `printMedia` = {title, info, id, text} and `literatureTitle` into the item's modData) | how a paper is dated by a mod: the same writes the engine makes, with the issue the calendar picks ([C36]) | javap -c |
| `ItemCodeOnCreate.onCreate{Knews,Herald,Times,Dispatch}NewNewspaper` call `nameNewspaper` on the paper's static; `onCreateRecentNewspaper` draws a random paper from `Registries.NEWSPAPER.values()`; these are Java, not Lua, so the re-dating happens at the container fill (`Events.OnFillContainer(roomType, containerType, container)`, server side) | when a paper can be re-dated ([C36]) | javap -c; the shipped Lua's `LootLog` |
| `GameTime.getStartYear/getStartMonth/getStartDay`, `getYear/getMonth/getDay` - month and day zero-based (the shipped debug Lua prints `getDay()+1`) | the county's calendar ([C36]) | javap; the shipped Lua |
| `RadioScriptManager.getChannelsList()`, `RadioChannel.isVanilla()`, `getCurrentScript()`, `RadioScript.GetName()`, `RadioChannel.setActiveScript(name, startDay)` | the once-per-save re-key of every vanilla channel to the save day July 9 falls on; the county wire is not vanilla and is left alone ([C36]) | javap |
| `CharacterTrait.register(String)` returns the trait; `CharacterTraitDefinition.addCharacterTraitDefinition(trait, name, cost, desc, free, disabledInMultiplayer)`, `setDescription`, `getCharacterTraitDefinition`, `getTraits`, `characterTraitDefinitions` (public static map) | how a mod adds a character trait in Build 42.20 - the B41 `TraitFactory` is gone ([C39]) | javap |
| `IsoGameCharacter.hasTrait(CharacterTrait)`, `getCharacterTraits().set(CharacterTrait, boolean)` / `add` / `remove` / `get`; `SAOIsoPlayerShell extends IsoPlayer`, so a shell carries traits like anyone | the condition rides the trait, on the player and on the county's people ([C39]) | javap |
| Vanilla ships `ASTHMATIC` and `INSOMNIAC` among its `CharacterTrait` constants, and prices every trait in `media/scripts/generated/characters/character_traits.txt` | SAO uses vanilla's trait where vanilla has one, and takes its costs from that file ([C39]) | javap; the shipped script |
| NOT in the engine | origin or hometown, schooling, family, service history, media taste, memory or decay of any kind: nothing on the descriptor says so. SAO derives origin region, age, birth year, service eligibility, occupation class, lessons and household itself (`SAO_History`, `SAO_Census`, `SAO_Identity`) | the getters above, read whole |
