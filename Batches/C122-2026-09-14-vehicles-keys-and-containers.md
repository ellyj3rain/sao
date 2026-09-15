# C122 - Vehicles, keys, and containers

| Field | Record |
| --- | --- |
| Batch | `C122` |
| Date | 2026-09-14 |
| Name | Vehicles, keys, and containers |
| Status | Closed append-only batch - vehicle composition |
| Threads | [`T-001`](THREADS.md#t-001), [`T-003`](THREADS.md#t-003), [`T-008`](THREADS.md#t-008) |

## Record

The vehicle port reached a real engine door in `[C114]` and held one
part of it wrong. `BaseVehicle.tryStartEngine()` calls the boolean form
with `false`; Build 42.20 reads `true` in that form as the held-key
condition after the debug, easy-use, and ignition cases. The earlier
record therefore treated the useful argument as a bypass when it is the
ordinary inventory answer. `ItemContainer.haveThisKeyId` is the engine
path for that answer: it checks loose keys, then recurses through a key
ring container. A person who holds a vehicle key can now use it when
driving; a person without it still gets the engine's own refusal unless
the key is in the ignition, the vehicle is hotwired, or an existing game
setting supplies the permission.

The motor-pool appraisal now carries that held-key fact through the Java
to Lua protocol. Standing favours a runner whose appraising person holds
the right key over a roomier locked vehicle. This is a preference rather
than a new eligibility rule: a vehicle with no present key still belongs
to the pool, and the start call remains the final engine verdict.

Vehicle parts also contain real supplies. The engine enumerates those
parts and marks only storage-bearing ones as containers, so the material
read now includes their item containers within the same radius as the
ordinary ground scan. The larder, food and drink source queries, dose
source query, the cook, and the nearest unclaimed store each read them.
This includes a camper or cargo trailer, which can carry containers
without an engine part; no interior teleport, scripted purge, container
fabrication, or vehicle spawning enters the slice.

## What changed

- `java/src/com/sao/engine/SAODriver.java` - the boarding path reads the
  driver's inventory with the engine's `haveThisKeyId` and passes that
  result to the ordinary engine start call.
- `java/src/com/sao/engine/SAONeeds.java` - vehicle appraisal transfers
  the held-key fact; vehicle-part containers enter the larder, item-
  source, cooking, and nearest-store reads within their actual radius.
- `mod/42.20/media/lua/client/SAO_Controller.lua` and
  `mod/42.20/media/lua/shared/SAO_Standing.lua` - the protocol receives
  the key field and prefers that runnable vehicle in a motor pool.
- `tools/vehicle_ground_test.py` and `tools/check.sh` - Border 154 runs
  the keyed choice in the engine's Kahlua VM, holds every source seam,
  and mutates the held-key start, every part-container guard, and the
  food vehicle-source seam to prove the verdict flips.

## Quality delta

The review panel found the initial gap in specific-item source queries:
counting vehicle food without returning that food as a source leaves a
person unable to take it. The shared vehicle source now covers food,
drink, and dose queries, and the border controls that source seam. The
nearest-store selection now takes the first real container at the nearest
vehicle root; vehicle parts have no separate world positions to rank.

The panel also noted hard-coded engine test paths and a possible extra
engine-health diagnostic field. The paths match the existing engine-VM
test convention, and portability requires a project-wide launcher
contract; the field has no consumer. Both are deferred rather than
introducing an unratified abstraction into this close.
- `FINDINGS.md` - F-068 records the corrected engine start reading and
  the key-ring recursion from the installed jar.

## Honest limits

- This is not a play receipt. Nobody has yet watched a survivor take a
  held key from their pack, start a vehicle, or eat, cook, and store
  supplies from a vehicle compartment in a live save.
- The key read is limited to the driver inventory and the engine's own
  recursive key-ring path. It does not search a house, a nearby body, or
  a vehicle container for a key.
- Material reads remain loaded-cell reads. A vehicle outside the scan
  radius, a part without a container, and unloaded ground remain outside
  this capability.

## Verification

- The installed Build 42.20 jar was disassembled before the correction:
  `tryStartEngine(boolean)` reads its argument after the debug,
  easy-use, and ignition paths and before the hotwire fallback;
  `haveThisKeyId(int)` recurses through an `InventoryContainer` key ring.
- Border 154 passes its source seams and engine-VM case: a two-seat
  runner with the held key is selected over a larger locked runner. All
  mutation controls are required to fault.
- The Java agent rebuilt from source and the complete gate passed. The
  prescribed deploy copied the tree, and the distribution, shipped, and
  installed jars are byte-identical at MD5
  `2EEE6219A5A0516837018D76A34F799E`.
- The deployment intentionally carries root `LICENSE` and `CREDITS.md`
  beside `mod/`; both installed copies match their canonical source MD5.
  No other installed file differs from `mod/`.