# C61 native world-source evidence

| Field | Value |
|---|---|
| Timestamp | 2026-09-20 08:44 UTC / 01:44 PST |
| Runtime authority | Installed Project Zomboid Build 42.20.4 jar, Lua and bundled JRE |
| Canonical contracts | `ROADMAP.md` R6/R7/R9/R10a; `SUBSTRATE.md` world-source and action boundaries |
| Operator decision | Mousecat Crucible selected `demand-led-native-hydration` |
| Implementation boundary | Native identity, demand hydration, exact observation, private knowledge, loaded reconciliation and bounded reservation substrate |

## Resulting behavior

When dormant search reaches a building, SAO now asks Project Zomboid to load or
generate each bounded chunk through its native streamer path. Unexplored static
containers roll their native loot while a density weave prevents a bodyless
request from inheriting the local player's zombie-density multiplier. Static
objects and ground items receive persistent UUID tokens in native ModData;
source fingerprints bind those tokens to physical location and kind. The chunk
is saved before an offscreen borrow is released.

Java returns exact containers, fluids, ground items, item IDs, quantities and
revisions. Lua accepts only a complete bounded protocol, keeps a bounded durable
working set, retries loaded observations after the chunk's main-thread load
phase, and marks removed, replaced or moved identities conflicted. Room and
distribution vocabulary now suggest where to explore; they no longer create,
deplete or refill stock.

Observed stock and executable availability are separate. Native hydration emits
`access=unknown`; vehicle sources emit `access=unsupported` because their
separate VehiclesDB2 persistence is not yet proven. Unknown or unsupported
sources cannot be reserved. A dormant arrival can learn exact stock privately,
but it cannot update `lastFoodDay` or `lastWaterDay` from that observation.

## Access and action continuation

The next unit is already specified across R6, R7 and R9. It must select one
exact source interaction point and prove floor, route, barriers and doors,
current claim or ownership permission, and vehicle-part permission. It must
then transfer the exact item or fluid to the actor, invoke the native carried
`Eat` or `DrinkFluid` consequence, and publish one durable result tied to the
source revision. Cancellation releases the reservation; save/reload preserves
or reconciles pending ownership; a changed revision becomes conflict. Only that
result may credit need or provisioning.

## Review findings and disposition

The required review panel rejected the first implementation. It consumed an
`access=unknown` source after arrival, bypassing path, doors, permission,
carrying and native physiology. Its Java mutation and Lua result were not one
crash-recoverable transaction; static `getEntityNetID` identity could alias a
replacement; offscreen code entered a live-map phase without active-map
adoption; loaded observation marked chunks seen before a successful read; the
agent manifest could not retransform a preloaded target; and ledgers were
unbounded.

The final tree removes dormant native mutation and need credit, requires
`access=accessible` for reservation, persists UUID identities, stays in the
streamer's pre-live raw-square phase, retries loaded reads, validates complete
protocols, authorizes retransformation and bounds chunks, places, conflicts,
pending loads, reservations and results. `review.json` records the review
panel's findings and repairs.

## Mechanical receipts

Border 178 runs the production ledger in Project Zomboid's Kahlua VM and proves
unknown-access refusal, exact item identity, source-wide locking, independent
source concurrency, private access belief, incomplete-protocol refusal, loaded
retry, replacement and movement conflicts, retention compaction and reservation
protection. It weaves the installed `ItemPickerJava` bytes and launches the
shipped jar as a real premain agent; the loaded target reports
`weave=ready|target=retransformed`.

The first enforced full gate reached every suite and refused only stale
canonical counts: 176 gated test files, 189 distinct scripts and Border 178.
After those records were corrected, `gate-final.txt` completed every suite and
reported `[check] all borders clean` with exit 0.

The enforced staged hook then resolved installed-engine paths that the WSL
shell-run gate had marked optional. It found two closure defects: the global
census still classified `getSandboxOptions` after its last production reader
was removed, and Border 140's VM module list omitted the new `SAO_WorldSources`
dependency, causing its tick callback to stop before walking. The obsolete
classification was deleted and the harness now loads the production dependency.
The installed VM again measures 150 tiles per day, 5 per hour and zero near-goal
overshoot. `gate-staged-final.txt` is the final installed-engine receipt.

The deployed `2.7.15.3-pre-alpha` install contains 256 files, with no missing,
extra or differing file against source. Its shipped jar SHA-256 is
`7df22e02ddc72d0d9fca0d62a388a6117d63c7ab151302dd0b35e9d344c9dc7d`.
All 44,092 pre-existing save-file paths, sizes and modification times remained
unchanged across deployment and startup. The responsive Project Zomboid window
listed SurvivorAwareness and ZombieAwareness as active Java mods; the current
agent log recorded premain, retransformation of the already-loaded loot-density
target and successful bridge exposure. Population and harness module markers
loaded with no Controller, Standing or cumulative-local compilation failure.
The process was left open for the operator.

No save was loaded during this startup receipt. Save-backed execution of an
offscreen hydration transaction and loaded-world behavior therefore remain
unobserved here; this record makes no acceptance claim for either.
