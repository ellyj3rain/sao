# C66 - Performed provisioning

| Field | Record |
|---|---|
| Batch | `C66` |
| Date | 2026-09-21 |
| Name | Performed provisioning |
| Status | Closed, validated and deployed; full gate enforced by the closing commit. |
| Threads | [`T-003`](THREADS.md#t-003), [`T-004`](THREADS.md#t-004), [`T-008`](THREADS.md#t-008), [`T-009`](THREADS.md#t-009), [`T-030`](THREADS.md#t-030) |

## Contract and measured substrate

Food and water collection and storage used native transfer actions, but queue
acceptance or later queue emptiness could stand in for completed work. C62-C65
already supplied one actor-owned source reservation, exact revisions, a stable
choice boundary and durable results. C66 extends that owner to `acquire` and
`store`; the older source action remains `consume`.

| Contract | Producer and caller | Persistence and observation | Change |
|---|---|---|---|
| Reachable native goods | SAOWorldSources/SAOBridge; Needs transfer adapters | Exact source/item identity and quantities; installed native holder probe | Offers prove current holder, physical access and transfer eligibility. |
| Owned acquisition/storage | WorldSources; SourceUse; Controller | Schema-6 reservation, native body inventory, bounded ordered result | One timed native transfer and exact before/after conservation. |
| Interrupted or reconstructed work | SourceUse resume/interrupt; existing body continuity | Durable operation and item/source signatures; runtime bindings reconstructed | Retain unavailable destinations, reject conflicts, never recreate goods. |
| Consequences | Controller; existing Provisioning/Material | Persisted credit cursor and exact partial-source projection | Completion-only experience and delivery speech; no queue-created stock or relationships. |
| Decision evidence | Existing decision_capture owner | Frozen option, selection, reservation and result | Acquire/store use the same capture boundary. |
| R12/authoring | Speakeasy decision_authoring and shared row validation | Hash-addressed views and unratified proposals | Versioned decision-time filtering and separately authored choices. |

## Implemented behavior

Loaded food collection, bounded nearby hauling, spare-food/water storage and
stored-water acquisition use the existing verified native transfer action.
Each reservation owns one exact item. Its carried identity, condition, uses,
fluid amount and content survive through the existing body snapshot; completed
results distinguish an item transfer from consumption. Queue rejection, an empty
queue and an interrupted unperformed action cannot earn stock, need relief or XP.

Offers privately inspect one reachable source. Complete chunk observations remain
separate from that person's exact-source knowledge. Targeted inspections preserve
other pending sources' pre-transfer observations and chunk membership. Independent
containers remain usable concurrently; each owner reconciles its own source.
The timed action repeats native access and current Standing checks immediately
before mutation, using the holder's live position. Food desperation retains its
decision-owned admission; legacy medication/alcohol errands retain their prior
native route.

Reload reconstructs the exact pending transfer. A completed native move is
reconciled once, carried goods remain carried, absent loaded destinations remain
pending, and duplicate/missing/conflicting holders cannot establish delivery.
Private source facts refresh after settlement, including outdoor and vehicle
anchors. Completion grants the actor's relevant XP once, using a persisted result
cursor. Delivery speech follows the carrier's real storage result. Recipient
recognition, debt, trust and complete-house storage still require their own
evidence and producers.

Bounded hauling schedules the next item only after the previous result; each
actual operation is durable. The runtime plan to start another item may be lost
across reload. The native/global save system does not provide a new atomic
transaction guarantee; divergent saved holders are diagnosed rather than repaired
by manufacturing an item.

## Review and verification

Independent runtime review reproduced a neighboring inspection poisoning another
actor's pending result. Source-scoped isolation repairs it. Review also repaired current
permission checks, moving-holder location, stale private anchor refresh,
unavailable-destination recovery and the hunger admission regression. A separate
review accepted the final hunger and legacy FORAGE routing. Cross-file review and
the closing gate supply the final integration verdict in the evidence record.
Cross-file review additionally repaired outdoor-source geometry and later recall,
excluded physical anchors from building visits, routed nearby collection to its
discovered holder, isolated pending-source evidence across consume and transfer siblings,
and rejected future/private enrichment in native Speakeasy inputs. The independent
reviewer reproduced the motivating defects and confirmed the repairs.

Border 179 incorporates the new cases through existing runners; no gate entry
point is added. It executes 41 production ledger cases and twelve mutations, 39
production lifecycle/capture cases and six mutations, plus 16 checks using real
installed ItemContainer/InventoryItem objects and a production Java mutation that
incorrectly accepts simultaneous holders. The existing source-use cases remain.
Borders 177/180 retain their motivating access and no-queue-credit controls after
the callers move behind the existing action owner.

The lifecycle cases load production WorldSources, Needs, SourceUse, Controller
and capture in installed Kahlua with controlled native adapters. Reconstructed
bodies and retained durable state exercise recovery; they do not prove save-file
atomicity or loaded-world acceptance. The native probe separately establishes
holder classification and inventory conservation against real engine objects.

Speakeasy's independent review found three admission gaps: incomplete shared-row
validation, native option evidence coherence and equivalent numeric-time
namespaces. All were repaired; 18 authoring tests and seven join controls pass.
The 190 approved choices, four historical derivatives and nine approved world
documents remain hash-protected. Claim metadata is unreviewed, acquisition
evidence unadjudicated and authored proposals unratified. No training eligibility
is conferred by this tooling.

## Continuation

C66 closes the acquisition/storage action slice of R7/R9 and extends R11 capture.
R9 still owes recipient recognition, broader material producers and complete
inventory evidence. R8's other audited action families retain separate obligations.
R12 now has decision-time views and proposal authoring; curated acquisition,
ratification, later consequences and eligible learned datasets remain. Historical
integration and learned-model work follow those causal producers.

Deployment and verification receipts live in
[the evidence record](../artifacts/audits/20260921-0213Z-1913PST-performed-provisioning/README.md).


The initial closing gate stopped on Border 6's 15-line queue-call lookback: the
expanded delivery arguments and an obsolete comment pushed the proven queue call
outside its window. Removing that comment restores adjacency; the motivating
check passes unchanged. The installed Controller received the identical
comment-only cleanup. No executable behavior or gate criterion changed.


The completed gate found stale Border 99 pattern matching and a real concurrency
regression in the first snapshot-protection repair. Border 99 now enumerates each
radius-bearing native finder, checks its own default (including comma-shaped
calls), and separately verifies private actor identity in both knowledge readers.
Fourteen wrong/removed-default controls and the private-actor control preserve the
motivating boundary; independent review reproduced the missed drug/default cases.
Border 178 correctly preserves simultaneous reservations on independent sources.
Its fixture now retains a named failed verdict when a reservation is absent.
Targeted snapshots now preserve other pending sources' prior observations and
chunk membership, including absent sources and changed native fingerprints.
Acquisition can interleave with another source's acquisition, storage or
consumption; each owner reconciles its own source. Unscoped observations retain
their existing conflict rules. Border 178's independent-container case passes,
and Border 179 carries the interleaving and invalid-owner controls.

Independent final review reproduced the original consume/acquire interleaving and
a separate acquire/store case. Both containers admitted work concurrently,
foreign pre-transfer evidence remained intact and both receipts completed.
Only consumption earned need credit. No final integration blocker remained.
