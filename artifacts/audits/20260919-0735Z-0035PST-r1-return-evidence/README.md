# R1 return repair evidence record

| Field | Value |
|---|---|
| Timestamp | 2026-09-19 07:35 UTC / 00:35 PST |
| Status | Closure evidence for C52 and ZAO A35; publication pending at capture. |
| Baseline | Published SAO C51, 2.7.14.2-pre-alpha; ZAO A34, 0.3.1.1-pre-alpha. |
| Ownership | SAO owns living identity, restored state and controller adoption. ZAO owns the recovery event and turned source. |
| Installation | These changes had not been deployed at capture. |

## Implemented transaction

ZAO records observed reanimation and the current death sequence before daily
pathogen advancement can produce a reversion event. A new event authorizes one
SAO return. SAO stores the transaction before holding a source, captures current
possessions and native appearance, stages a paused living shell, verifies that
the source has not changed, acknowledges source removal, then publishes and
adopts the living person. Ordinary dead-record materialization remains refused.

Failed phases retain their owner and log their phase and reason when the reason
changes. Repeated callbacks and Lua reload rebind the same native stage. An
acknowledged removed source can reconstruct its living destination from the
serialized transaction. The tests exercise that reconstruction in an isolated
VM; a complete running-world save/reopen has not been exercised. Missing source
handles never establish bodyless recovery; that path requires an existing
`turnedDormant` record and supported saved living state.

At each loaded death, supported living statistics, wounds and experience are
captured against that death sequence. A failed later capture invalidates the
earlier death's copy. Current turned possessions override the historical living
inventory. Native zombie bodies have no living BodyDamage or XP components.

## Save continuity

Normal native saves omit the off-slot living shells used by SAO. Body now
checkpoints current supported state, native visual state, position, time and
physical facts on OnSave. The installed engine invokes this before IsoCell.save
and GlobalModData.save. Checkpointing preserves bodies, controllers and pending
actions, and leaves pending return/release journals authoritative.

A failed checkpoint retains the last valid snapshot and records the failure.
After restart, ordinary materialization refuses that known-stale snapshot.
The Lua event cannot stop the remaining native save sequence. This prevents a
silent rollback claim; it does not recover state that could not be captured.

The native table format limits each string to 32,767 UTF-8 bytes. Large person
snapshots and visual sidecars now use versioned, checksummed fragments. Native
item ModData has the same internal bound: oversized string keys or values can
silently corrupt later item fields even when loading returns successfully.
Recursive pre-save checks refuse those unsupported values before relinquishing
the original body. F-083 records the reproduced corruption and controlled fix.

## Evidence and limits

The joint Kahlua instrument executes production SAO and ZAO modules with explicit
engine/body doubles. It covers the reanimation-to-return producer, both callback
orders, current possessions, loaded and dormant paths, failure/retry, changed
source materials, repeated deaths, delayed source movement and diagnostics.
Its health function is a named fixture, not an approved physiology rule.

That limitation was resolved after the first receipt. The operator selected
critical viability with injuries preserved. The joint instrument now calls the
production Lua authorization path and a bridge double, while ZAO's separate
installed-engine probe executes the production Java health operation on a
world-version-249 death snapshot. Native lethal/fake Knox flags and statistics
are cleared; wounds, treatment, fractures, ordinary wound infection, adverse
statistics and XP remain; weighted health stops at the return floor and the
next native `BodyDamage.Update` remains alive. Four source controls reject a
surviving infected part, scalar-only health, full injury erasure and full heal.

Native probes execute installed world-version-249 serializers and body cleanup.
Current-source inventory tests include detached equipment and nested food;
visual restoration and processing registration are checked independently.
The staged-body probe cannot validate successful rendered publication without
a loaded world and model assets. No loaded-game acceptance is claimed.

Synchronous native hooks protect held sources before the Lua bridge becomes
available. The source probe exercises ordinary and fake-dead checkpoint
ownership around population serialization, virtualization and both chunk-removal
entry paths. It executes the real native serializers and Kahlua table round trip;
population-save selection is exercised up to its first JNI boundary.

An exact native preservation-registry lookup also finds offscreen reanimated
sources. A new return may find the uniquely identified unheld source; the Lua
authorization precedes holding it. Existing held sources recover their material
state at the native registry loader's exit, repairing its omitted hand reference
before later callbacks can edit inventory. A missing reanimated owner cannot
authorize a replacement clone. Ordinary and fake-dead sources can reconstruct
one checkpoint-owned unpublished source without a loaded square. Offscreen
returns finish in durable living state, with checked temporary-shell disposal
and no loaded controller. Their actual native flags remain intact.

Automatic registry-load and item-processing callbacks isolate checkpoint
failures by identity. An affected source stays held and unavailable, its previous
checkpoint bytes remain unchanged, and valid sources and unrelated native items
continue. Explicit source operations refuse a failed identity until a fresh
current-cell/world load. Save and chunk guards continue to refuse an
uncheckpointable held source; callback isolation cannot certify partial state.

## Completion work

| Work | Owner and required result |
|---|---|
| Recovery physiology | COMPLETE: ZAO DR-028 clears native lethal/fake Knox state, restores critical viability and preserves distinguishable injuries, treatment, ordinary wound infection, adverse statistics and XP. SAO stamps systemic-dormant Knox and refuses publication on failure. |
| Interrupted saves | R4 persistence work: reconcile generations across native population/reanimated saves and GlobalModData. Completed-save tests do not establish atomic recovery from a process failure during those separate writes. |
| Closure | Both current full gates pass and their receipts and source hashes are preserved here. Canonical records and versioning are complete; publication follows through the two repository PR workflows. |

Normal offscreen movement for ordinary identified zombies is separate from
preserving a source already held for return. A pending-source checkpoint does not
replace ordinary offscreen movement with fixed locations.

Current eligible loaded sources come from SAO shells through native corpse
reanimation. Both reanimated-player and fake-dead branches transfer actual worn
items; `isUsingWornItems()` is true for both. Visual-only clothing therefore
remains an explicit unsupported external representation, rather than another
R1 prerequisite. Foreign IsoZombie-backed people can carry SAOPersonId but have
no supported living BodyDamage/XP provenance; ground-derived ZAO zombies have
ZAODerivedId and no corresponding SAO living capture. Neither can acquire a
fresh living-state snapshot merely from a tag.

## Verification record

The early SAO full gates refused. They exposed an unused field, a missing
explicit bridge exception report, new instruments absent from the gate and an
undeclared owned-shell cleanup site; the build artifact was also stale at the
first invocation. The checkpoint-failure field now prevents reconstruction from
a known-stale snapshot. Source resolution reports and propagates bridge failures
instead of treating an exception as proof that no destination exists. The
first closure run then caught the stale C51 jar stamp and session prose; the
jar was rebuilt from VERSION, the session record advanced to C52, and the full
gate reran clean. `sao-gate-metadata-refusal.log` preserves that refusal.

The final SAO and ZAO full gates both pass with exit code 0 against the source
hashes in `manifest.json`. SAO's cleanup audit was also updated to follow the
refactored, actually called return-commit helper; two negative controls verify
that removing the cleanup or its callers is rejected.

| Verification | Result and boundary |
|---|---|
| SAO full gate | PASS: 167 numbered borders, 182 gated mirrors. `sao-gate.log`; current build output in `sao-build.log`. |
| ZAO full gate | PASS: seven borders, including pathogen production plus five controls, native source production plus 37 compiled defect controls, and native return physiology plus four defect controls. `zao-gate.log`, `zao-native-source.json`, `zao-return-health.json`. |
| Person handoff and snapshot | PASS: 18 handoff controls and 19 compiled native snapshot controls, including current possessions, living-only death capture and oversized internal string refusal. |
| Joint afflicted return | PASS: production Lua with 15 controls, including deferred dormant-shell cleanup. It executes the production health authorization and a bridge double; native physiology has its own installed-engine border. |
| Staged body and save checkpoint | PASS: eight compiled body controls and 11 checkpoint controls. Rendered publication remains unobserved. |
| Durable snapshot text | PASS: eight compiled controls using the real Kahlua serializer and extracted production bridge adapters. Native codecs are exercised separately by the snapshot probe. |
| Engine health investigation | Infection removal preserves unrelated injuries but leaves a lethally damaged saved body dead. `health-probe-output.txt`. DR-028 selects the compatibility rule; `zao-return-health.json` preserves the production/control receipt. |

`native-string-corruption.json` preserves a direct native-save/load reproduction:
an oversized item string silently changes a later key identifier even though
loading succeeds. `cache-lifetime-controls.json` records the audit-rule controls.
Compact native receipts preserve all outcomes and source hashes; installed-engine
disassembly is represented by hashes and exact commands for regeneration.

These are controlled VM and installed-engine serializer checks. They do not
establish loaded-game acceptance, a full running-world save/reopen, or recovery
from an interrupted multi-file save. R1 implementation is closed; publication
was pending at evidence capture. R4 retains the planned cross-file persistence
work.

## Crossed interaction boundary found during physiology review

Systemic-dormant Knox does not create a spontaneous Afflicted-to-Crossed roll.
The existing stored transition requires a Crossed carrier and an Afflicted
target. Its only producers are daily three-tile proximity checks, however, and
success changes pathogen state without transferring the living body from SAO to
ZAO. The sibling's A32 Crossed decision pass is unreachable because Crossed
states have form `none` while the controller requires a non-`none` form; the
pass also lacks the canonical retained human weapon, tool and general action
vocabulary. Afflicted are not food, so the generic zombie-target fallback cannot
stand in for their distinct interaction. SAO F-084, ZAO F-017 and SUBSTRATE's
R4-R10 contract record the full repair. It is not part of the return transaction
and this R1 evidence makes no Crossed-execution claim.
