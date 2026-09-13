# C114 - A real person at the wheel

| Field | Record |
| --- | --- |
| Batch | `C114` |
| Date | 2026-09-13 |
| Name | A real person at the wheel |
| Status | Closed append-only batch - the driving half of the Week One port ([C110]) |
| Threads | [`T-001`](THREADS.md#t-001), [`T-002`](THREADS.md#t-002) |

## Record

The doorway `[C82]` mapped (F-067: the engine requires no player at the
wheel) has never been exercised. This batch drives a car through it:
a live goer who took wheels on a venture (`[B19]`'s claim) walks to
the claimed car, enters seat 0, starts the engine lawfully, and drives
it to the venture's ground - a real SAO person in a real seat, which
the county can watch pass. The claim was facts about a car; now the
body is in it. `[C31]`'s fuel burn at order time, which always ran,
becomes real fuel spent on a real trip.

**What crossed from Week One, and what it became here.**

- **The engine-start-and-drive idiom** (their `BWOPeopleControl` /
  vehicle drives, read from the installed mod at Workshop 3403180543).
  The idiom is theirs; every surface it lands on here is the engine's
  own lawful one, disassembled from the installed B42.20 jar before a
  line was written: `enter(0, char)` is Addendum D's seat contract;
  `tryStartEngine()` - the no-argument form, because the boolean form
  is the cheat path - bounds the start by the same gameplay a player
  faces (condition and quality may refuse under their own named
  reasons, and a refusal is HONORED, never routed around); the gas,
  brake and steering reads in `CarController.updateControls()` are
  ungated on driver identity, so `getClientControls()` stands as
  written for an NPC at seat 0; steering sign verified from the same
  bytecode (Left key -1, Right key +1), and the steering is the
  bearing toward this very destination, cross-multiplied against the
  vehicle's own forward vector, clamped to the pedal's range.
- **The 30 km/h town figure** (their regulator drove at
  `30 * VehiclesSpeed + SymptomLevel*7`). Carried as `SPEED_CAP_KMH`,
  credited in the code where it lives: their authored figure for
  driving through a town, read off the real speedometer rather than
  written into the engine.

**What never crosses, named so it is not mistaken for lost:** the
ghost driver (their `SurvivorFactory` IsoPlayer with setSceneCulled,
setNpc, setGodMod, setInvisible, setGhostMode and collisions off - a
body that is not a person; SAO's driver is the real body, and the
county can mourn it); the forced engine trio (`tryStartEngine(true)`
plus `engineDoStartingSuccess` plus `engineDoRunning` - the cheat path,
and this batch's whole point is the lawful one); the regulator, which
their own comments say does not steer ("-- does not work") and which
they never steered with; the horn-at-zombies (no seam for it yet); and
as ever, none of their people's logic, none of their timeline, no
runtime dependency, none of their files loaded.

**The drive's shape.** One Java module, `SAODriver`, two modes
sharing one `SAODriveState`: drive (seat 0) and ride (a passenger
seat). The driver's phases are WALK (an ordinary SAOMovement route to
the claimed car, found by the same sanitized pool name the motor pool
appraised under), START (the starter turning), WAIT (holding the brake
for the seats the party was promised), DRIVE (steering by bearing,
capped at the credited figure, the engine's own
`isInvalidChunkAhead` brake standing as the unloaded-space law, a
stuck-patience for walls and wrecks), and STOP (brake to a halt, then
`park()` and `shutOff()` and the unseat). Passengers ride because
`[B19]`'s seat cap was a promise the goer drove off with: escorts are
flagged `rideWith` at assignment, walk to the same car, board a
passenger seat ([B1]'s boarding idiom, rollback on throw), and the
driver waits at the wheel until the promised seats are filled or
patience runs - latecomers' rides fail honestly (`RIDE_NO_SEAT`,
`RIDE_NO_CAR`) and they take the walk, arriving after the venture has
begun. A drive is committed: while the body is at the wheel, `decide`
has already returned early by the seat law on the books since `[B1]`
and corrected at `[C4]` - the seat outranks the flag - so no
mid-drive decision interrupts it; the county's dangers reach a driver
only through `setState`, whose exit rule parks the car and returns
the body to its own two feet. Every refusal - no car where the claim
said, a taken seat, an engine that will not catch, wheels that will
not cross - ends the drive and the ordinary walk takes the trip from
wherever the body stands: the same trip they always took, not an
error. On arrival the car parks NEAR, not on, and the last stretch is
walked, so the venture's own close-out (the forager's haul, the watch
post) runs on WALK arrival, unchanged.

**Physics, verified not assumed.** A car at rest with an NPC driver
can have its controller disabled - `shouldBeActive` branches on
physicActiveCheck, at-rest, a driver nearby in the 3x3, or engine
force - and a dead controller never consumes the controls. The
engine's own public `setPhysicsActive(true)` is called at board time
and at the engine-running transition; once moving, "not at rest"
holds it alive, and under throttle the engine force does. This was
read from `BaseVehicle`'s bytecode, like every other load-bearing
fact in this batch.

**Design, decided here** (no operator fork was open; per `[A11]`'s
posture, carried because it was understood):

- **The drive is era-general, not pre-fall-gated.** The `[C110]`
  charter gates the PORT by `fallHasCome`, and the port's own
  features (the street law `[C113]`) die at the fall. But the drive
  composes with SAO's own venture machinery - `[B19]`'s claims,
  `[C31]`'s burn, `[C82]`'s doorway - none of which was ever
  era-gated, and a post-fall goer who claimed a car and burned the
  tank for it driving it is the same honest fact it is before the
  fall. What the port carried into the mechanism (the lawful-start
  idiom, the 30 km/h figure) rides along in every era, because it is
  how the mechanism now drives. Pre-fall is where the Day Zero
  receipt watches it; post-fall is where the county's own dangers
  make it cost what it costs.
- **Passengers make the seat cap true.** Without riders the `[B19]`
  cap counted seats a party never filled; with riders the car holds
  who it was promised to hold, and the refusal is the honest outcome
  for whoever missed it.
- **The car-chase law.** Nobody anchors to wheels they are not
  seated in: the leader and lexical follow chains skip a body in
  DRIVE or RIDE, because an anchor receding at driving speed pins a
  walker in FOLLOW across the county. The escort rides; the chain
  waits for the car to park.
- **Two orphaned-route repairs found by the fall-through fact.**
  `decide` runs while a Lua walk is live (the movement block falls
  through for every state but TRAVEL), so both the drive order and
  the ride order retire any live Locomotion job explicitly - neither
  goes through `Locomotion.order`'s job replacement, and an orphaned
  job is F-012, the independent-wandering defect. The same structure
  showed `decide`'s own "back on foot" write would clobber the
  last-stretch walk after a park; the tick blocks clear the riding
  flag at the door, first.

## What changed

- `java/src/com/sao/engine/SAODriver.java` - new. The module: both
  modes, the phases, the lawful start, the bearing steering, the
  refusal verdicts, the park/shutOff/unseat finish, the
  deliberately-not-taken list in the javadoc.
- `java/src/com/sao/engine/SAODriveState.java` - new. Per-shell trip
  state, sibling to `SAORouteState`.
- `java/src/com/sao/engine/SAONeeds.java` - `poolName` widened to
  package-visible: `SAODriver` re-finds the claimed car by the same
  sanitized name the claim was made under.
- `java/src/com/sao/bridge/SAOBridge.java` - the `drives` map and
  five verbs, the movement idiom's shape: `driveBegin`, `rideBegin`,
  `driveWaitSeats`, `tickDrive`, `cancelDrive`.
- `mod/42.20/media/lua/client/SAO_Driving.lua` - new. The thin Lua
  face over the bridge's loop, `SAO_Locomotion`'s discipline: order,
  tick for a one-line verdict, log; every refusal is the caller's
  walk to take.
- `mod/42.20/media/lua/client/SAO_Controller.lua` - the wiring: the
  venture order's drive branch (the goer who took wheels DRIVES;
  `onWheels`/`driveGX`/`driveGY`; the live walk retired); the escort
  `rideWith` flag and the driver's `holdFor` after the party is
  known; `setState` keeps `onVenture` through DRIVE and its exit rule
  parks the car on any transition out; `MOVEMENT_STATES` gains
  DRIVE/RIDE; the escort validation accepts a driving goer and orders
  the ride; the leader/lexical anchors skip bodies under wheels; the
  DRIVE and RIDE tick blocks (verdict-driven, self-healing on a
  state with no job under it, the riding flag cleared at the door,
  the last stretch walked on arrival).
- `CREDITS.md` - the Week One section carries the driving port: the
  idiom and the figure, and the ghost driver, forced trio, regulator
  and horn named as deliberately-not-taken.
- `ROADMAP.md` - Day Zero slice 1's driving-owed line closes; the
  Week One paragraph's "driving owed at `[C114]`" closes with it.
- `BATCH_LOG.md`, `THREADS.md` (T-001, T-002), `SESSION_STATE.md` -
  the pointers.

## Honest limits

- The Lua degrades gracefully until the end pass rebuilds the jar:
  without the new bridge verbs, `SAO.Driving.order` fails its pcall
  and every goer takes the ordinary walk, exactly as before. The jar
  rebuild is deferred to the end pass by the operator's standing
  order, and this batch is not observable in play until it runs.
- A save/load mid-drive leaves a seated body with no job under it -
  the runtime agent table and the Java drives map are both
  session-state. The seat law on the books (`[B1]`/`[C4]`: a body
  found seated IS riding) holds it in the seat, and that wedge is
  `[B1]`'s own, predating this batch; it is named here, not fixed
  silently under a feature batch.
- A driver's `WAIT` for promised seats ends at 900 ticks whether or
  not the party has boarded - the departure-without-latecomers is
  the honest outcome, and their rides fail into the walk.
- The ride's patience is 3600 ticks of a seated passenger with
  nothing happening; the safety net, not the design.
- No play receipt: the operator has not watched a goer walk to a
  claimed car, hear the engine catch, and roll out with company in
  the seats. The batch is OPEN pending that receipt, like every
  batch of this era - and it is the receipt `[C82]` has owed since
  it mapped the doorway.

## Verification

Deferred to the operator's standing order for this pass: no gate,
build, deploy, package, test, or git until the planned feature work is
finished; all of it runs once, at the end.