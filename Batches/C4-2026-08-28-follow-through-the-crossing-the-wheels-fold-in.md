# C4 - Follow through the crossing; the wheels fold in

| Field | Record |
|---|---|
| Batch | `C4` |
| Date | 2026-08-28 |
| Name | Follow through the crossing; the wheels fold in |
| Status | Closed append-only batch - play verification pending (no play receipt) |
| Threads | [`T-001`](THREADS.md#t-001), [`T-006`](THREADS.md#t-006) |

## Record

The operator's terms, kept whole: keep SAO locomotion and pace - it already
follows more cleanly than the neighbour - and add what it could not do.
The neighbour's traversal layer was read end to end first (mechanics
studied at file and line, no files lifted); its hardest-won lesson - hand
the body to the engine's own climb machinery and OBSERVE it, never run a
second traversal simulation - was already this county's shape, because the
route supervisor drives vanilla states throughout.

**The crossing.** The route supervisor had door and window branches and no
fence branch: the engine's own paths cross hoppable edges, the drive
walked into them forever, and the job died at the stall counter as
"stalled:ManualRoute" - a stall with no name, the exact class [B45]'s
verdict discipline exists to prevent. The square knows its edges exactly
(`getHoppableTo` / `getWallHoppableTo`, javap-verified): the supervisor
now faces the crossing and climbs through the engine's own
`climbOverFence`, and every route in the county benefits, not just the
follow. For the follow specifically: when a walk toward a close,
same-floor player has failed or stalled, one edge is in the way - the
window they climbed, the fence they hopped - and `traverseToward` works
that single synthesized step through the same transition logic a captured
route uses. Open, climb, hop; never a smash - `mayForceEntry` stays
wherever the composition left it.

**The wheels.** `enter()` was called bare where vanilla's own
ISEnterVehicle pairs the seat claim with the mesh placement; exit was
bare the same way. The operator had already met the class: a driven truck
with no visible driver who could not exit. Every boarding is now the
vanilla pairing - claim, mesh "inside", verify, roll back through exit()
on any failure - and every exit reads the seat first and places the mesh
"outside". Seat 0 is never taken: nobody here drives (T-001's engine
absence, named, never promised). The `riding` flag stopped being able to
lie: it lived on the runtime agent table and was lost at re-adoption,
leaving a seated survivor running walk orders from inside a car - the
seat truth now outranks the flag in both directions.

**Folded into follow, and a clear order.** A companion whose player is in
a vehicle makes for a free seat instead of walking after the bumper, and
steps out - the paired exit - when the player leaves the vehicle. Under
"Ask them to...": "get in the vehicle" names the vehicle nearest what was
clicked (a real record from `nearestBoardableVehicle`, walked to, boarded
on arrival), and "step out of the vehicle" appears while they are seated;
a refusal is spoken (`noRoom`), boarding and stepping out have their own
lines. The player's own enter, exit, and ignition are untouched surfaces:
nothing here queues on the player, and no county body can hold the
driver's seat.

**The border.** Border 82 (`tools/seat_and_crossing_test.py`) holds the
class: paired enter, paired exit, the driver's seat never taken, the
hoppable branch present, the traversal reachable from the Controller, and
the riding flag reconciled from the seat truth. Control: the checker
against the pre-fix tree fails six ways for the stated reasons.

This governed record is the portable project history for this unit.
