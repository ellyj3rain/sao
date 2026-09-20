# C60 perception and world-access evidence

| Field | Value |
|---|---|
| Timestamp | 2026-09-20 05:17 UTC / 22:17 PST |
| Runtime authority | Installed Project Zomboid Build 42.20.4 jar and Lua |
| Canonical contracts | `ROADMAP.md` R6/R10a; `SUBSTRATE.md` R6-R8 and R10a |
| Implementation boundary | Loaded perception and access repair; unloaded source inventory and reconciliation plan |

## Execution packet

The target behavior is that a fact can offer an action only after the actor
acquires it, and that the action rechecks current permission and physical
access before changing the world. The installed engine owns classification,
visibility, container access, target activity, object contents and positions.
SAO owns person beliefs, cached-source invalidation and the decision that
consumes those facts.

This unit does not complete dormant resource production, social producers,
action receipts or historical integration. It records the exact substrate the
dormant path requires and keeps unknown ground unavailable.

## Loaded evidence matrix

| Contract | Producer and authority | Live consumer / cache | Persistence | Defect and repair | Acceptance |
|---|---|---|---|---|---|
| Animals do not become people | `IsoAnimal extends IsoPlayer`; cell moving-object list | `SAOPerceptionScanner.scan` emits `P` rows; Lua persists them as person beliefs | Person belief store | The classifier excluded animals but the emitting branch did not. The branch now rejects `IsoAnimal` before label/output. | Border 155 mutates classifier and emitted-row guards independently. |
| Activity partners are privately perceived and currently present | Scanner `P` row with `source=observed`, person key and timestamp | Cashier customer, player customer, child ball and player playmate actions; raw `Body.active` resolves the body only | Belief timestamp; action cooldown after the performed gesture | Raw coordinate proximity bypassed belief, floor and occlusion. Candidate selection now requires a fresh firsthand belief; the bridge rechecks the scanner's floor, facing, action range and occlusion law at use. | Border 176 refuses told, dead, stale, future, other-floor and occluded candidates through source and mutation controls at all four call sites. |
| Optional prone state is read from its owner | Engine floor/crawler state; installed Lethal Stealth `ltsproneposition` and `ret_lts_acostado` | Scanner silhouette/stance tags; combat floor aim | Observed stance is a time-bounded belief | The installed keys were absent. Both live animation and mirrored mod-data keys now feed the existing stance helper. | Border 157 names the installed keys and removes the live key as a control. |
| Deactivated targets cannot remain actionable | `IsoZombie.isUseless()` | Scanner, bridge target acquisition, director and held `SAOCombat.target` | Runtime target only | Acquisition skipped inactive zombies, but combat retained one that became inactive. Begin and every combat tick now refuse it and clear attack intent. | Border 157 removes the held-target recheck independently. |
| World contents require present physical access | Loaded square/container/item identity; `BaseVehicle.canAccessContainer(partIndex, character)` for vehicle parts | Food, drink, drug, weapon, ammo and offered-item caches; larder/cooking reads; nearby store target | Weak runtime maps cleared on world reset | Vehicles were inspected regardless of locks; cached reach ignored floors; ground offers retained no reach proof; vanilla transfer did not recheck ordinary vehicle parts. Readers now require loaded identity, same-floor unobstructed reach and current permission. A vanilla-derived transfer action keeps those checks live through completion. | Borders 154 and 177 mutate loaded membership, floor, obstruction, offer membership, vehicle permission and timed-action revalidation independently. |
| Source scans do not pass vacuously | Repository Lua inventory | `scope_split_audit.py` in the full gate | None | The gate invoked the scanner with no paths and reported zero. It now passes every shipped Lua source and empty input refuses. | Explicit all-source and empty-input runs; full gate. |

## Cached source and target inventory

| Runtime cache | Acquisition | Use-time validation | Vehicle / unloaded exposure |
|---|---|---|---|
| `SOURCES` | Loaded square containers plus accessible vehicle parts | Item remains in the same container; vehicle remains loaded; part/container/access and current position refresh; same-floor reach; timed transfer revalidates the world container | Vehicle defect repaired. No unloaded producer. |
| `WATER_SOURCES` | Loaded `IsoObject` fluid source | Object still has clean water; current loaded square, floor, reach and obstruction are checked | Static loaded object only. No unloaded producer. |
| `WEAPON_SOURCES` | Loaded square containers | Item remains in container; current stored floor and reach; timed transfer revalidates the world container | No vehicle acquisition. No unloaded producer. |
| `AMMO_SOURCES` | Loaded square containers | Shared item/container validation, current stored floor/reach and timed world-container validation | No vehicle acquisition. No unloaded producer. |
| `OFFERED` | Loaded world inventory object within two tiles | Same object remains in the square's world-object list with an item; current cell, floor, range and obstruction rechecked | Loaded ground only. |
| `SAOCombat.target` | Perceived/bridge-selected active body | Death, health and now deactivation rechecked each tick | Loaded body only. |
| Activity participant | Fresh observed person belief | Current body, range, floor, facing and occlusion | Loaded bodies only. |

## R10a source inventory

The installed engine supplies several different kinds of truth. They cannot be
collapsed into a single “place offers food” flag.

| Concern | Available while unloaded | Available only when loaded | Current SAO status |
|---|---|---|---|
| Geography | `IsoMetaGrid`, `BuildingDef` and `RoomDef` provide stable building identity, bounds and room vocabulary for the whole map. | Current square objects, collision, stairs, doors and damage. | `SAO_Places.at` reads meta geography correctly. |
| Resource possibility | Room vocabulary and distributions describe where a class of source may occur. | Actual containers, item IDs/types/quantities/fluids, world items, vehicle parts and randomized loot. | `offers` currently promotes room vocabulary to availability. This is a legacy proxy, not R10a evidence. |
| Access | A destination's coarse location is known. | Path result, current barriers, lock/door state, vehicle `canAccessContainer`, ownership permission and exact interaction point. | Dormant travel assumes access from destination/claim rules. Unknown physical access is not represented. |
| Depletion and renewal | Sandbox loot-renewal policy and durable SAO ledgers are available. | Native container/item/fluid state and `isHasBeenLooted`. | Visit counts approximate depletion. They do not conserve native contents or reconcile player/native changes. |
| Reconciliation | County time and world-reset owners exist from R2/R4. | `Events.LoadGridsquare`, loaded source enumeration and native item/container identities. | No exact source ledger or chunk reconciliation owner exists yet. |

Room names can seed a search or a statement of possibility. They cannot prove
stock, access, quantity or successful acquisition. Until a native source has
been observed and assigned a durable identity, its state is `unavailable`, not
empty and not available.

## R10a implementation contract

The next world-source unit has five ordered stages.

| Stage | Mechanism | Required proof |
|---|---|---|
| 1. Native identity | Validate stable identities across unload/reload for static sources using building ID, square, object/container identity and native item ID; validate vehicle `sqlId`/`getId`, part index and item ID separately. | Same source survives save/reload; moved/removed/replaced sources do not alias. |
| 2. Observation ledger | Persist source kind, observed native contents/quantity, accessibility result, observer/provenance, county timestamp and revision. `unknown`, `available`, `spent`, `inaccessible` and `conflicted` are distinct states. | Missing or failed reads yield `unknown`; no room-derived stock enters the ledger. |
| 3. Reservation and result | A dormant actor may reserve only an observed available quantity. Reservation does not count as acquisition; completion records a quantity delta, while interruption releases it. | Concurrent actors cannot consume the same unit; failed or interrupted trips conserve stock. |
| 4. Loaded-chunk reconciliation | On square/chunk load, enumerate native state, match validated identities, compare the last observed revision and apply only committed dormant deltas. A mismatch becomes `conflicted` and refuses automatic mutation until reconciled from native truth. | Player looting, loot respawn, moved objects, destroyed objects, vehicles and partial fluids have positive and conflict controls. |
| 5. Consumer migration | Replace `SAO_Places.offersNow` as a material-availability answer. Person knowledge points to ledger observations; path/access and permission remain separate use-time gates. | Dormant and loaded actors given the same grounded source conserve the same quantity; unknown ground offers no action. |

This plan does not preselect settlements, completed work or survival outcomes.
It creates and depletes sources only from native observations and performed
actions, so later life-simulation results remain consequences of agents and
conditions.

## Verification receipts

The initial implementation compiled all Java against the installed jar and all
73 shipped Lua files in normal and debug modes. Focused Borders 154, 155, 157
and 176 passed. The required review then found stale-floor, unloaded-vehicle,
ground-offer and timed-transfer gaps; those were repaired and Border 177 was
added with independent defect controls. Final gate and runtime receipts are
recorded by the batch closure.

Both reviewers re-read the corrected tree and report no remaining Critical,
High or Medium finding in their assigned scopes. `review.json` retains the
initial findings, repairs and the non-blocking recommendation to consolidate
the repeated vehicle-container enumerators. `build-final.txt` records the
installed-engine Java build at `2.7.15.2-pre-alpha`. `deployment.json` records
255 installed files matching source, the shipped jar hash and unchanged
metadata for all 44,092 save files. `startup.json` records a responsive Project
Zomboid window, both SAO module-load markers and absence of the Controller,
Standing or cumulative-local compiler failures. No save was loaded; this is
startup evidence rather than loaded-world acceptance. The enforced commit gate
is the final repository-wide verification owner. Its first run completed the
native and historical suites and refused only two stale `COUNTER_REACH` /
`PLAY_REACH` allowances for raw arithmetic that C60 removed. The obsolete
exceptions are deleted; the closing commit reruns the complete gate.
