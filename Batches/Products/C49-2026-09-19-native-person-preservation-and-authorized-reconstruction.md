# C49 - Native person preservation and authorized reconstruction

| Field | Product record |
|---|---|
| Batch | C49 |
| Date | 2026-09-19 |
| Generation | 20261005-product-consolidation |
| Source generation | 20260919-through-C120 |
| Source range | C51–C55 |
| Tier | minor |
| Standing | Historical product synthesis; each component retains its exact implementation, verification, publication and remaining scope. |

## Product outcome

A durable person survives the replacement of its native body with exact retained inventory, health, skills and native sidecars. Authorized Afflicted return reuses that custody rather than creating a second person. Shared county time, transactional owner publication and graph/runtime reconstruction make the retained state meaningful on the replacement body.

## Chronological product boundary

Capture, source teardown, authorized return, exact native reconstruction and reload publication are consecutive phases of the same person-continuity outcome. They form one product; unauthorized resurrection and later pathogen policy remain separately owned.

Establishes a new player-visible capability or authoring/runtime contract. Capture, source teardown, authorized return, exact native reconstruction and reload publication are consecutive phases of the same person-continuity outcome. They form one product; unauthorized resurrection and later pathogen policy remain separately owned.

## Source contributions and custody

| Original contribution | Exact immutable record | SHA-256 |
|---|---|---|
| 20260919-through-C120:C51 — Person preservation | [Source record](../../Batches/history/c-20261003-source/Batches/C51-2026-09-19-person-preservation.md) | a39d916e7ef25ccef92e2ae307064a1fe7351b92b74483c2a5da16fdbd7de650 |
| 20260919-through-C120:C52 — Authorized afflicted return | [Source record](../../Batches/history/c-20261003-source/Batches/C52-2026-09-19-authorized-afflicted-return.md) | c6129fb7b05f86d4d0ed9eb97395125d587840ffd2bc22eb6814560c9b97af76 |
| 20260919-through-C120:C53 — Shared county time | [Source record](../../Batches/history/c-20261003-source/Batches/C53-2026-09-19-shared-county-time.md) | aecfc7bb043c6ab831646d2670610c683fdd8c4402000393ec9b2ddcdf5b2cad |
| 20260919-through-C120:C54 — Native person continuity | [Source record](../../Batches/history/c-20261003-source/Batches/C54-2026-09-19-native-person-continuity.md) | a51f1dfeaec43b5d442872be8cb427de8791fc499989ddc45eb88c0e0a214292 |
| 20260919-through-C120:C55 — Durable/runtime reconstruction | [Source record](../../Batches/history/c-20261003-source/Batches/C55-2026-09-19-durable-runtime-reconstruction.md) | 019094f3330d82b388f980d0ec06afdc84eda0e3a4bc4ac00e4b92b3cb81776b |

Each original contributes once to the product/version chronology. Its many-to-many shared-contract links remain in the unchanged ownership projection, and nonadjacent related work stays later in the chronology.

## Delivered mechanisms and evidence boundaries

The following excerpts preserve the source prose; relative navigation is resolved from this product record. The exact original record above owns the full context, mechanisms, controls and corrections.

### 20260919-through-C120:C51 — Person preservation

> Body release captures and validates the current person before relinquishing
> ownership. Capture failure keeps the prior record, body and controller.
> A failed or partial teardown retains a durable pending snapshot and the body
> handle. Retries use that capture; a reload commits it before dormant simulation
> or reconstruction. Pending bodies remain represented but are unavailable to
> physical interactions. Their engine updates and independent health callbacks
> pause until teardown finishes. Busy bodies, including patients of queued
> treatment and inventories targeted by transfers, remain loaded.

> Body.materialize owns restoration for Population and Harness alike. Failed
> restoration retains the snapshot and cleans up the partial shell before retry.
> Population accounting occurs after a usable shell exists. Profession defaults
> precede restoration, preventing repeated starting-skill grants over saved XP.
> Explicit Harness deletion removes identity only after teardown succeeds.
> Death during a pending transition uses checked cleanup and retains ownership
> on failure; population recovery retries it. Ordinary deaths retain the existing
> engine corpse path. Dead records cannot materialize. The Ledger reports pending
> handoffs, including restoration failures and explicit removals awaiting teardown.

> New v3 snapshots use the installed engine's inventory, Stats, BodyDamage and XP
> serializers. The envelope includes format and engine version, bounded sections,
> SHA-256 integrity, an inventory identity/type/parent manifest, and held, worn
> and attached item references. Nested contents and different instances of one
> item type survive. Missing item scripts, corruption and incompatible native
> versions refuse restoration. Radio possession is staged as a durable physical
> fact instead of inferred from encoded inventory text.

**Implementation:** completed measured implementation

**Verification:** source-scoped evidence and limits retained in archived record

**Publication:** committed-at-source-head

**Original standing:** Closed.

**Remaining scope retained from the source:**

- C54 supplies then-missing nutrition/fitness/recipes/modData/appearance; not loaded gameplay acceptance.

### 20260919-through-C120:C52 — Authorized afflicted return

> An Afflicted return is now one durable transaction between the repositories.
> ZAO owns the recovery event and exact turned source. SAO owns the returning
> person, supported living state, staged shell and controller adoption. The
> transaction records its authorization and phase before either side relinquishes
> ownership. Repeated callbacks, Lua reload and an acknowledged source removal
> resume the same transaction rather than minting another person or body.

> The source is held before publication. Its current possessions replace the
> historical living inventory while its pre-death statistics, wounds and
> experience come from the matching death sequence. SAO publishes the restored
> person only after ZAO confirms that the authorized source was removed. Loaded
> returns receive a controller; offscreen returns finish as durable living state
> without inventing a loaded body. Ordinary dead records remain unable to
> materialize.

> Returned people are critically viable and still injured. ZAO clears native
> lethal and fake Knox state, restores only the weighted health needed to reach
> the return floor, and preserves wounds, treatment, fractures, ordinary wound
> infection, adverse statistics and experience. SAO records Knox as systemically
> dormant. There is no spontaneous Afflicted-to-Crossed roll.

**Implementation:** completed implementation loaded acceptance pending

**Verification:** source-scoped evidence and limits retained in archived record

**Publication:** committed-at-source-head

**Original standing:** Closed implementation batch; loaded-world receipt pending.

**Remaining scope retained from the source:**

- Dormant return creates no shell; C55 supplies cross-save atomicity; C80 updates living-state execution.

### 20260919-through-C120:C53 — Shared county time

> History owns the county's elapsed-time conversions: 9000 ticks per hour and
> 216000 per 24-hour day. A controller decision now refreshes that clock at the
> moment it is read. Historical catch-up can therefore execute many substeps
> inside one host callback without every consumer seeing the callback's opening
> time. The fallback advances once per host callback only when History cannot
> answer; repeated reads never manufacture time.

> WorldGenesis receives an elapsed county day and converts it to the tick at that
> day's start before Integration evaluates pressure and branches. Population uses
> History's named ticks-per-day constant. Day Zero changes the record timeline,
> and DayLength changes wall pacing; neither changes county units.

> Native pacing is separate. The death-fall grace and operational tally flush use
> the controller's transient host-callback counter. Voice, UI, profiling and the
> historical-slice budget retain their explicit wall-millisecond clocks. ZAO's
> loaded controller already reads `SAO.Controller.tick()` and its durable
> pathogen progression is day-based, so no sister source change is required.

**Implementation:** completed measured implementation

**Verification:** source-scoped evidence and limits retained in archived record

**Publication:** committed-at-source-head

**Original standing:** Closed implementation batch; loaded-world receipt pending.

**Remaining scope retained from the source:**

- UI wall milliseconds and corpse/native pacing stay distinct; scoped proofs are not rendered acceptance.

### 20260919-through-C120:C54 — Native person continuity

> The native-person writer advances from v3's five supported components to a v4
> envelope that also carries nutrition, fitness, recipes and all reading/media
> collections, descriptor perk boosts, human appearance, hair/beard growth timing
> and declared durable character ModData. Root and nested item identities retain
> exact native fluid-component facts, so a silently removed definition cannot
> turn one mixture into another during restoration.

> Nutrition restores the native values plus its omitted update counter, calorie
> extrema and direction flags. Unsafe weight refuses before the engine loader can
> apply its damaging low-weight setter. Fitness loads into a new component before
> exercise definitions initialize; its first update establishes the current
> ten-minute bucket and its next update advances normally. An in-progress exercise
> is a runtime action and remains R4 work.

> Learning state restores directly after profession defaults without replaying
> callbacks. Recipe IDs remain known even if their current definition is absent;
> required perk definitions refuse. Native appearance restores after worn-item
> references and before the final model reset. Outfit and forced-model script
> references are checked; the growth timers use a bounded engine-field adapter.

**Implementation:** completed measured implementation

**Verification:** source-scoped evidence and limits retained in archived record

**Publication:** committed-at-source-head

**Original standing:** Closed implementation batch; loaded-world receipt pending.

**Remaining scope retained from the source:**

- Unsafe data refuses; legacy limits persist. C55 owns runtime exercise; C56 health course.

### 20260919-through-C120:C55 — Durable/runtime reconstruction

> R4 separates durable authorities from the objects that only make sense inside
> one running world. Branching persists patterns and offices, while Integration
> builds a fresh function-bearing graph at startup. Built-ins install once in
> stable order and extensions re-register by stable ID. The runtime extension
> registry has a 128-entry ceiling before Kahlua sorts caller-supplied IDs. History store memos,
> Identity's name index, Places state, durable random-stream objects, controllers,
> courses, needs and Java bridge maps all release the prior world's objects before
> the next world advances.

> Pending work receives an explicit save and reconstruction result. A pending
> corpse is materialized during `OnSave` before native serialization; successful
> creation removes the pending record, while failure preserves its body and report
> for retry. An in-progress fitness exercise is runtime work: restore keeps its
> durable regularity and exercise timestamps but cancels `currentExe`, so a reload
> cannot turn interruption into completion credit.

> Project Zomboid writes participating return state through separate global and
> native body surfaces. A completed round trip could not prove recovery if one
> surface reached the new save and the other did not. ZAO A36 therefore adds a
> narrow write-ahead generation journal for identities that entered the
> Afflicted-return protocol. After Lua `OnSave` and before native body persistence,
> the journal captures the SAO record slice, ZAO pathogen/recovery slice and the
> exact source receipt or absence tombstone. The file is checksummed, forced and
> atomically replaced; generation markers bind both global tables and native
> bodies to that record.

**Implementation:** completed measured implementation

**Verification:** source-scoped evidence and limits retained in archived record

**Publication:** committed-at-source-head

**Original standing:** Closed implementation batch; loaded-world receipt pending.

**Remaining scope retained from the source:**

- Not a full-world duplicate snapshot; D services declare reset and journal requirements.

## Historical interpretation

This record consolidates development substance and its supporting integration, verification and publication. It supplies no new runtime, native-trial, learned-policy, visual-acceptance or release-maturity credit. Historical failures, incomplete work, source corrections and later D-era outcomes retain their dated generation-qualified records.
