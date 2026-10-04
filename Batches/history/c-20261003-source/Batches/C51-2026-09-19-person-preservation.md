# C51 - Person preservation

| Field | Record |
|---|---|
| Batch | `C51` |
| Date | 2026-09-19 |
| Name | Person preservation |
| Status | Closed. |
| Threads | [`T-006`](THREADS.md#t-006), [`T-007`](THREADS.md#t-007), [`T-008`](THREADS.md#t-008) |

## Behavior

Body release captures and validates the current person before relinquishing
ownership. Capture failure keeps the prior record, body and controller.
A failed or partial teardown retains a durable pending snapshot and the body
handle. Retries use that capture; a reload commits it before dormant simulation
or reconstruction. Pending bodies remain represented but are unavailable to
physical interactions. Their engine updates and independent health callbacks
pause until teardown finishes. Busy bodies, including patients of queued
treatment and inventories targeted by transfers, remain loaded.

Body.materialize owns restoration for Population and Harness alike. Failed
restoration retains the snapshot and cleans up the partial shell before retry.
Population accounting occurs after a usable shell exists. Profession defaults
precede restoration, preventing repeated starting-skill grants over saved XP.
Explicit Harness deletion removes identity only after teardown succeeds.
Death during a pending transition uses checked cleanup and retains ownership
on failure; population recovery retries it. Ordinary deaths retain the existing
engine corpse path. Dead records cannot materialize. The Ledger reports pending
handoffs, including restoration failures and explicit removals awaiting teardown.

## Snapshot and compatibility

New v3 snapshots use the installed engine's inventory, Stats, BodyDamage and XP
serializers. The envelope includes format and engine version, bounded sections,
SHA-256 integrity, an inventory identity/type/parent manifest, and held, worn
and attached item references. Nested contents and different instances of one
item type survive. Missing item scripts, corruption and incompatible native
versions refuse restoration. Radio possession is staged as a durable physical
fact instead of inferred from encoded inventory text.

Valid v1/v2 snapshots remain readable within their original limits. Their old
type/condition summaries cannot recover item details already discarded. Native
zero-elapsed restoration preserves captured state; positive elapsed time retains
the existing dormant-metabolism policy. This batch does not validate that policy.

The supported components do not include nutrition, fitness, learned recipes,
standalone character ModData or human appearance. Person identity and record-owned
state remain in Identity. Optional drug counters stored only in character
ModData remain an open persistence gap. Whole-player loading is unsuitable:
the installed loader also changes player settings and player-specific state.

## Evidence

Border 162 executes the shipped Body, Population, Controller, Harness, death
funnel and health callbacks in the installed Kahlua VM with explicit body/bridge
fault doubles.
It covers capture refusal, teardown retry, pending reload, restore failure,
manual deletion, incoming actions, independent callbacks and caller ownership.
Its sixteen controls mutate production source and require the corresponding
failure, including pending-death cleanup and dead-record restoration refusal.

Border 163 constructs real engine characters and factory-created items, then
executes the native component codecs. Its controls cover inventory, statistics,
wounds, experience, equipment, corruption, version and missing nested items.
Border 75 exercises the actual legacy parser and native dispatch contract.
The [evidence record](../artifacts/audits/20260919-0544Z-2244PST-c51-person-preservation-evidence/README.md)
states exact inputs, results and limits. Borders 70 and 100 now follow the
changed serializer and restoration owner. Offline body fixtures implement the
same presence/recovery interface as production.

The full repository gate passed with exit 0. The final native build and
shipping-adapter probe passed. Deployment through tools/deploy.sh succeeded;
all 249 installed files matched their source, with no missing or extra files.
The installed jar SHA-256 is
`d3592141fe8ac8deae1d9ef2f8253b649c84076421fb062a59222636302babdc`.
The first failed gate is preserved alongside the closing result. No game was
launched or polled for play evidence, and no save was changed.

## Continuation

Shared-time consumers, pathogen ownership, afflicted-return adoption and the
remaining audited action/producer defects remain open. These repairs protect
the supported handoff; they do not establish simulation readiness for training
or loaded-game play acceptance.
