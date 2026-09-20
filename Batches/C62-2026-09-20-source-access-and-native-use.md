# C62 - Source access and native use

| Field | Record |
|---|---|
| Batch | `C62` |
| Date | 2026-09-20 |
| Timestamp | 2026-09-20 10:41 UTC / 03:41 PST |
| Name | Source access and native use |
| Status | Closed through the enforced full commit gate. |
| Threads | [`T-002`](THREADS.md#t-002), [`T-003`](THREADS.md#t-003), [`T-006`](THREADS.md#t-006), [`T-007`](THREADS.md#t-007), [`T-008`](THREADS.md#t-008), [`T-030`](THREADS.md#t-030) |

## Actor-owned source action

C61's exact source observation can now motivate one live actor without becoming
global availability. The actor must hold a private belief containing the exact
`sourceId@revision`; a bodyless record, another person's belief and a stale
revision cannot begin. One durable reservation owns the source-wide lock and
the phases from place approach through exact interaction approach, transfer,
native use and result.

Native Locomotion walks both legs and retains its existing door, window and
barrier consequences. Java resolves the same source fingerprint, revision and
item again, chooses a free source or adjacent interaction square, and binds
only after same-floor reach, obstruction, current claim permission and current
vehicle-part permission pass. Vehicles observed inside the place bounds enter
the private revision set even though they have no building ID; their offscreen
persistence is still never mutated.

The selected container item moves through SAO's vanilla-derived verified
transfer, and a ground item through vanilla grab. The exact carried item then
enters vanilla `ISEatFoodAction` or `ISDrinkFluidAction`. Java compares native
item/fluid and hunger/thirst state before and after completion or stop. A
completed physical effect stamps that actor's `lastFoodDay` or `lastWaterDay`
once. A partial native stop records interruption and actual quantity without
need credit. Queue acceptance, observation and reservation award nothing.

## Reconciliation and boundary

Unspent cancellation releases the reservation. Runtime engine references clear
on body/world teardown while the durable owner remains. Reload resumes from the
exact carried item when transfer completed, otherwise it re-approaches and
revalidates the source. Changed revision, fingerprint, item or permission
refuses or conflicts. The post-use observation applies under only that
reservation's optimistic-lock exception; a completing ground item may disappear,
while unrelated missing or changed sources remain conflicts.

The reservation is also the actor's mutation owner. While it remains pending,
the dormant life, attrition, settlement, provisioning and encounter passes skip
that actor; the bodyless PathogenEvents encounter/snapshot pass and WorldGenesis
graph pass do the same. The live controller first settles mortality and Crossed
handoff, then reconstructs the source phase before another action producer can
run. An unreadable future-schema reservation freezes those competing producers
rather than being mistaken for no owner.

The durable result includes actor, source, item, category, measured quantity,
status and pre/post revision. The bounded ledger retains completed receipts in
durable sequence until its sole `provisioning` consumer explicitly acknowledges
them. Delivery returns scalar copies, and acknowledgement is idempotent, so a
reload may redeliver unacknowledged work without letting the consumer mutate or
silently discard the ledger. Settlement material and recognition receive no C62
credit; R9 must consume and acknowledge the completed result against reconciled
inventory. Direct fluid held by a world object continues through the existing
loaded direct-drink path. C62's revision-bound carried-use path covers food and
clean-water items and does not fabricate a transferable vessel.

## Verification

[Border 179](../tools/source_use_test.py) executes 11 durable-ledger cases and
27 shipped-action lifecycle cases inside the installed Project Zomboid Kahlua
VM. They distinguish observation from access, private revision from another
actor's belief, live from bodyless, one source owner from concurrency,
completion from partial interruption, represented reload ownership, revision
conflict, expected ground-item removal, generic-observation ordering and the
full 2,048-receipt delivery bound. A separate static check holds 32 required
call/form anchors; it is structural evidence rather than a behavioral mutation
count. Installed engine inspection verifies interaction-square, obstruction and
vehicle APIs; the Java source compiles against Build 42.20.4.

[Border 162](../tools/person_handoff_test.py) executes the cross-pillar owner
boundaries: initial source projection, operator and internal-route preflight,
opaque-schema refusal, dormant exclusion, death, controller drop and Crossed
handoff. It proves a pending source action cannot be approximated, routed beside,
or transferred ahead of mortality.

[Border 168](../tools/shared_time_test.py) executes the WorldGenesis exclusion
with protected and unprotected actors; [Border 173](../tools/intentional_exposure_test.py)
does the same for the bodyless pathogen observation. Removing either ownership
guard makes its control fail while the ordinary daily consumer still runs.

The first installed startup exposed a separate inherited load-order defect that
the compile gate could not see: `History`, `Isolation` and `Lessons` spoke through
`SAO.Log` before the alphabetically later logger had loaded. Every pre-logger
shared call now checks the exact logger method first. Border 56 holds all eight
early calls and removes History's guard as a rejecting control.

The retained C60-C61 access, knowledge, scarcity, queue, reconstruction,
invariant and dual-mode Lua checks pass with the new lifecycle. The
[C62 evidence artifact](../artifacts/audits/20260920-1041Z-0341PST-source-access-native-use/README.md)
records the blocking review findings, complete gate, initial rejected startup,
load-order repair, exact deployment and clean final startup.

## Continuation

R6 is closed for the selected exact source interaction and R7's source-action
slice is closed. The next dependency layer moves settlement provisioning off
queue-time credit and onto completed results plus reconciled stock, then applies
the same action ownership discipline to the remaining R7/R8/R9 families. R10b
historical integration continues to wait for those producers. R11-R12 can
advance alongside them.
