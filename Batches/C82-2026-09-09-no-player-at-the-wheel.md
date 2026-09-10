# C82 - No player at the wheel

| Field | Record |
| --- | --- |
| Batch | `C82` |
| Date | 2026-09-09 |
| Name | No player at the wheel |
| Status | Closed append-only batch - evidence; no mod code |
| Threads | [`T-001`](THREADS.md#t-001), [`T-008`](THREADS.md#t-008) |

## Record

T-001's ledger has held NPC driving as engine-absent since the thread
was written - named, never promised. The second seam is why that got
asked now: ZAO's `[A12]` ruled the crossed's vocabulary a bidirectional
goal, and what the crossed need from driving feeds forward into this
project's half of it. This batch is that half, evidence first: a map
of what the engine holds, read before anything uses it.

## The consumers, named

The crossed's requirements ride in this record as named consumers, and
nothing here designs for them. **Driving as instrumental action** - a
car used to aim the turned, arrive at a target and leave it. **A
vehicle that carries noise** - a moving sound source, the seam's own
loudspeaker word. **Arrival and departure by car** around the seam's
explosives word. Every one is a body in seat 0 doing something the
county may one day watch; none is designed here, and whether the
county ever drives at all stays the operator's.

## What the bytecode holds

Every identity test along the driving path was disassembled from the
installed B42.20 jar, method by method, and they all point one way:
**the engine requires no player at the wheel.** Every gate that
mentions a player exists to exclude the blocked local player, and
none requires one. `isKeyboardControlled()` is an identity compare of
the seat-0 character against `IsoPlayer.players[0]` plus not being
towed, so an NPC answers false. `BaseVehicle.updateControls()` gates
on a controller existing, `isOperational()`, and the driver cast to
`IsoPlayer` blocking movement - the cast is null for an NPC, and the
gate passes. `CarController.updateControls()` reads the keyboard only
under `isKeyboardControlled()` and the joypad only at
`getJoypad() != -1`, so with an NPC at the wheel neither input branch
runs and the public `ClientControls.steering/forward/backward/brake/
shift` stand as written - the doorway, with `forceBrake` a
milliseconds window the method's tail honours and nothing else
overwriting them. `tryStartEngine()` bounds ANY driver by the same
gameplay a player faces - the debug cheat, or
`SandboxOptions.vehicleEasyUse`, or keys in the ignition, or
hotwired - with the engine part's condition and quality able to
refuse under named reasons. And `BaseVehicle.update()` ticks the
physics reading the controller and `isEnable` with no driver-identity
gate at all, as it must for a car that coasts with nobody in it.

Seating was already contract surface: `enter(seat, char)` is
Addendum D's fact, and seat 0 is the driver's by `getDriver()`'s own
typing - `getPassenger(0).character`, an `IsoGameCharacter`, not an
`IsoPlayer`.

## What no shipped code does

No precedent exists for any of this. KnoxSurvivors' own sources
contain no NPC driving - the only vehicle reference in the reference
mod is its health controller rejecting vehicle targets - so the
doorway is verified reachable and exercised by nobody. **What this
does not establish is that NPC driving works.** Live behaviour, the
cadence under the county's own passes, what an NPC-driven vehicle does
to the turned and to the county's claims: all hypothesis until a live
receipt, which is why T-001's ledger moves from engine-absent to
surface-mapped, receipt-owed rather than closing.

## No new border

Documents only - nothing under `mod/` changes and no capability moves.
The evidence lives in `ENGINE_CONTRACT.md` Addendum G and the finding
in `FINDINGS.md` F-067; T-001's ledger line moves because it was the
thing this evidence proved wrong.
