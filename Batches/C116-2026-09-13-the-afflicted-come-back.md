# C116 - The afflicted come back

| Field | Record |
| --- | --- |
| Batch | `C116` |
| Date | 2026-09-13 |
| Name | The afflicted come back |
| Status | Closed append-only batch - the afflicted ruling, built |
| Threads | [`T-002`](THREADS.md#t-002), [`T-008`](THREADS.md#t-008), [`T-001`](THREADS.md#t-001) |

## Record

The operator ruled 2026-09-13, naming the next integration order: the
afflicted are just as important as the crossed, and the county's own
source must carry them whole. This batch is the afflicted's SAO half,
and it closes the two seam halves the sister's `[A32]` recorded as
owed by this side - the driving map's widening (`NOT_A_SHELL`) and
the `record.verbs` stamp - so the crossed's own machinery, already
shipped there, finds both ends waiting.

**What the afflicted are, read off the sister's own pathogen:** a
body the pathogen was turning that drew back out of the turn. The
reversion (`ZAO_Pathogen.lua`, verified) sets `terminalState
"afflicted"` with the residue scaled by the capability that survived
it, and there are TWO live-afflicted populations: the reverted turned
corpse, whose risen IsoZombie the sister drives, and the live-bodied
infected the sister's recovery branch flipped without a death -
people who kept their bodies and never came back from anywhere. Both
populations are carried here.

**The return, and it is a fact-reading, not a decision.** The
pathogen's own draw licensed the reversion; the adoption follows the
state. Once per county day, `SAO_AfflictedReturn.adopt` walks the
sister's controlled register: for a person whose state says
afflicted, whose record says the county's death, with no live body
and no earlier return standing, a body is minted where their risen
corpse stands (or at their last ground, if the corpse is out of the
world) through the same `materialize` every awakening uses - the
returnee registers in `Body.active` and carries `SAOPersonId` through
the whole identity chain ([C8], F-044), so they are claimable,
re-dieable and re-readable by the sister like any neighbor. The
order is atomic and deliberate: the mint runs FIRST on the record as
it stands, and only on success do the flags turn - `rec.dead` flips
to false, not an undoing of the death (`diedAtHours` and `deathCause`
stay durable; they DID die, out there, and it is still true) but the
county's present-tense judgment that they are gone, which the
reversion overturned. Everything the death funnel dropped stays
dropped: they come back with no beliefs, no voice, no company, a
stranger to their own house - which is what coming back from that
IS, and the material the social half (the next batch) argues over. A
refused mint leaves a death record a death record and the next
county day tries again.

**The presentation chain, closed at its one missing link.** The
scanner (`SAOPerceptionScanner.appendZaoForm`, verified) already
appends the form marks from any body's modData to BOTH person rows
and zombie rows, and the belief parser (`SAO_Perception.lua`'s
P-row suffix, [C104]) already reads them into person-beliefs. What
no live afflicted body carried was the marks. Two stamp paths close
it: the adoption mints the returnee with the pathogen's own three
marks (`ZAOForm`/`ZAOFormPerformance`/`ZAOAttributes`, read from the
sister's state through its own `attributeString`), and
`Return.stampLive` re-stamps every live afflicted body once per
county day - the same cadence the marks decay, so a formed person is
read as the form they have TODAY, and the recovery-flipped
population (never dead, never adopted, previously unmarked) becomes
visible too. A body without marks reads as a body with nothing on
it; now the ghoul shape is visible, and what survivors do with what
they see is their own pressure chain's business.

**The formed neighbor in the county's fear.** A person-belief
carrying a form now enters the threat reckoning
(`Perception.nearestFormedPerson`, gated behind the hostile-person
override so a hostile person still governs first) - and the
controller's `isZombieThreat` excludes it (`fromPerson`), so the
formed neighbor is FEARED and never fought: no stand-ground, no gun
combat, no grudge against them. The flee branch reads their believed
position, the pathogen pressure branch reads them at full weight
(`nearestBelievedThreat`, the nearest of zombie belief or formed
person - the pathogen presses by what a body carries, not by what
kind of body carries it), and the witness's adaptation observes the
form at the parser, so the county LEARNS from them as it does from
any horror it sees. The reunion machinery already fires: a returned
person meets their old world with `rec.dead` overturned and
`P.reunionHandler` live, their form riding the same belief.

**The exposure half, for the living.** The dormant observer loop
gated exposure behind bodylessness, so a live afflicted could stand
beside a crossed carrier all day and never be exposed - the sister's
own exposure verdict, gated behind a gate the sister never asked
for. The second loop in `SAO_PathogenEvents.simulateDay` crosses
only the exposure, and only for the afflicted near a crossed
carrier: the crossed work on them (`MUTATION.md`), the odds and
susceptibility stay the pathogen's own (`ZAO.Pathogen.expose`, read
once, never copied), and the observation half stays where it is -
the living observe through their eyes ([B41]'s scanner), not through
this pass.

**Both seam halves `[A32]` named as ours, closed:**

- **The `record.verbs` stamp.** `ZAO_Mind` reads `record.verbs or
  {}` and this side's record never carried any, so the retained-verb
  list the crossed's mind draws on was always empty. `Drv.order`
  stamps `"drive"` on the record when an order lands - only the
  demonstrated verb, never the census, so the crossed who kept some
  of what they were can remember having driven.
- **The map's widening.** `SAOBridge.driveBegin` dispatched
  shell-only and answered `NOT_A_SHELL` for the dead, so the
  sister's driveTick could never start a trip for the crossed. The
  IsoZombie dispatch is first now, over a
  `crossedDrives` WeakHashMap of its own (the dead are not shells
  and never enter the shell's map), and `SAOCrossedDriver` is the
  second entry in the driving map: the crossed walk the way the dead
  walk (`pathToLocationF`, the engine's own zombie pathing, one leg
  per scan - the same cadence the sister's hunt uses; SAOMovement
  is player-surface and was NOT widenable, by design law), then
  board seat 0 through the same character-typed engine surface
  `[C82]`/`[C114]` verified (enter/exit/setCharacterPosition/
  playPassengerAnim take IsoGameCharacter with no identity gate, and
  IsoZombie extends IsoGameCharacter - javap-verified before a line
  was written), start the engine lawfully (the no-argument
  `tryStartEngine`, a refusal honored - `ENGINE_REFUSED` climbs out
  and ends the trip), and drive the bearing to the named ground,
  capped at the drive dial's own default, parked and shut off at
  the end. There is no WAIT phase - the crossed wait for nobody.
  A thrown tick is caught at the bridge and answered
  `DRIVE_FAILED`, because the sister's verdict machine ends a trip
  only on Succeeded, IDLE, or a `DRIVE_` verdict - any other answer
  would hold the body's movement committed forever. The survivor
  trips (`SAODriver`) are untouched; the two drivers share the
  vehicle law and not the walk.

**The risen corpse is the sister's half, named here as `[A33]`
owed:** ZAO owns the turned body, and its release of a reverted body
this county has re-adopted (`SAO.Body.get(personId)` exists) is
recorded in both repos, mirroring `[A32]`'s own owed-by-the-sister
pattern. Until it lands, the corpse and the returned person share a
county, and the county's reunions and fears are honest about both.

**What is deliberately NOT here, so it is not mistaken for lost:**
the house argument over an afflicted member (quarrel and split
keyed on affliction), the cast-out and the gather (exile; cast-out
afflicted drifting toward low-claim abandoned ground through
`Perception.returnsOf` and `Standing.placesOf`, DR-037/DR-021), and
the survivor-side standing reaction in work, claims and recruitment.
Those are standing's questions and the next batch's, per the
operator's totality order - this batch is the seam halves, the
return, the presentation, and the exposure.

## What changed

- `mod/42.20/media/lua/client/SAO_AfflictedReturn.lua` - NEW: the
  adoption (`Return.adopt`, the mint-first return with the atomic
  flag order) and `Return.stampLive` (the marks on every live
  afflicted body, once per county day).
- `mod/42.20/media/lua/client/SAO_Population.lua` - `dailyCounty`
  calls `adopt` then `stampLive` after `simulateDay`, one call site
  so the live county and the years pass both drive it ([C65]'s
  law).
- `mod/42.20/media/lua/client/SAO_Driving.lua` - `Drv.order` stamps
  the demonstrated `drive` verb on the record.
- `mod/42.20/media/lua/client/SAO_Controller.lua` - the formed
  person enters the threat reckoning behind the hostile override;
  `isZombieThreat` excludes `fromPerson` beliefs.
- `mod/42.20/media/lua/shared/SAO_Perception.lua` -
  `nearestFormedPerson` and `nearestBelievedThreat`; the parser
  observes the form of a formed person-belief through Adaptation.
- `mod/42.20/media/lua/shared/SAO_Integration.lua` - the pathogen
  pressure branch reads `nearestBelievedThreat`.
- `mod/42.20/media/lua/shared/SAO_PathogenEvents.lua` - the
  live-bodied afflicted exposure loop.
- `java/src/com/sao/engine/SAOCrossedDriver.java` - NEW: the
  crossed's driving engine (XWALK/START/DRIVE/STOP, the lawful
  engine start, the honest refusals, the `DRIVE_`-bounded verdicts).
- `java/src/com/sao/engine/SAODriveLaw.java` - NEW: the vehicle law
  both drivers hold, lifted whole out of the two ([B31]: one
  definition, two callers) - the DRIVE phase's bearing, cap and
  patience, the STOP phase's halt, and the claimed car's re-finding,
  typed on IsoGameCharacter with each driver's own unseat handed in
  (the living's carries the needs pairing, the crossed's climbs out
  bare).
- `java/src/com/sao/engine/SAODriveState.java` - the `walkTicks`
  patience field.
- `java/src/com/sao/bridge/SAOBridge.java` - the `crossedDrives`
  map; the IsoZombie dispatch in `driveBegin` and `tickDrive`, the
  tick wrapped so a throw ends the trip under `DRIVE_FAILED`.
- `tools/version_replay.py` - the `C116` unit row; `--write` stamps
  the coordinate.
- `BATCH_LOG.md`, `THREADS.md` (T-001, T-002, T-008),
  `SESSION_STATE.md`, `ROADMAP.md` - the pointers.

## Honest limits

- The adoption mints a SECOND body at the corpse's position until
  the sister's `[A33]` lands - the corpse is the sister's to lay
  down, both records say so, and the county is honest about both.
- The returnee's forgetting is total by design: markDead's funnel
  dropped beliefs, voice, company, habits, disposition, material
  stores and organization membership, and the return overturns none
  of it. They come back hollow. The social half that argues over
  that hollowness is the next batch.
- `Return.stampLive` walks `Body.active` once per county day; the
  marks it writes are the sister's own state read back, never
  derived here.
- The crossed driver's walk patience (WALK_PATIENCE 900 legs) and
  the trip refusals are structurally verified only. No play
  receipt, as ever: nobody has watched a crossed body board a car,
  and nobody has watched the dead come back.

## Verification

- Every load-bearing engine fact was disassembled from the
  installed B42.20 jar before a line was written, the same law
  `[C82]`/`[C114]`/`[A32]` followed: `BaseVehicle.enter(int,
  IsoGameCharacter)`, `exit`, `setCharacterPosition`,
  `playPassengerAnim`, `getDriver`, the no-argument
  `tryStartEngine`, `getController().park()`, and
  `IsoZombie extends IsoGameCharacter` (final).
- All 63 shipped Lua files compile under the engine's own Kahlua
  compiler (Border 50); the seven touched files pass the structural
  check; the Java compiles clean against `projectzomboid.jar` and
  the jar is rebuilt and shipped to the tree (`SAOCrossedDriver` in
  the shipped bytecode, Border 32's surface).
- The gate ran clean with the batch in the tree; the version
  machine derives 4.6.0.0-pre-alpha (minor - a new player-visible
  simulation capability: the county's mid-course people return to
  it, and the crossed can drive). Deploy follows this record, then
  the branch, the pull request, and the squash - the publishing law.

## Deferred verification

Runtime behavior is the operator's receipt boundary ([A21]'s law
here, mirrored from the sister's): a mod-load test is a world start,
and world starts are the operator's. The return, the formed
neighbor's fear, the crossed under wheels - all verified by the
gate's structural pass and awaiting the same play receipts every
runtime batch awaits, together with the sister's `[A33]` half.

## Next

The afflicted among the living - the social half: the house
argument over an afflicted member (quarrel and split keyed on
affliction, through Standing's own machinery), the cast-out and the
gather (exile; the cast-out drifting toward low-claim abandoned
ground), and the survivor-side standing reaction to an afflicted
member in work, claims and recruitment. Then the operator's
totality order continues: raiders, Week One's moments and gestures,
age attachments, drugs in totality - and the off-switch list before
runtime verification, all in the queue the roadmap holds.