# C57 - Person continuity contract

| Field | Record |
|---|---|
| Batch | `C57` |
| Date | 2026-09-20 |
| Name | Person continuity contract |
| Status | Closed through the enforced full commit gate. |
| Threads | [`T-006`](THREADS.md#t-006), [`T-007`](THREADS.md#t-007), [`T-008`](THREADS.md#t-008) |

## Responsibility and behavior

DR-041 and DR-042 establish whole-mod runtime and border restructuring, with
an eventual private unified project. This first unit separates the validated
body envelope from ownership of the temporary engine body.

`SAO_BodySnapshot` owns version interpretation, capture, validation and commit
of native state, position/time and physical observations. `SAO_Body` retains
materialization, release, checkpoints, staged returns and external ownership.
Release, checkpoints and Crossed transfer share the same capture/commit code.
Afflicted return uses the same version reader while retaining its distinct
source-removal and adoption transaction. Save keys and native formats retain
their existing readers.

Pending Crossed transfers now validate their supplied native payloads and
required envelope fields before publishing a new owner. Release validates a
provided visual payload through the bridge, permitting durable chunk tables
and refusing invalid supplied data. Compatibility permits absent legacy visual
sidecars; the journal does not identify every missing optional historical field.
Current v4 native envelopes carry appearance internally.

## Verification consolidation

`native_person_test.py` replaces the former snapshot, continuity and dormant
physiology entry points. Its executable case inventory and historical crosswalk
retain all 36 prior mutation names across Borders 163, 169 and 174. One exact
appearance mutation is shared, leaving 35 distinct compiled controls. The
unchanged probe retains all 84 assertion call sites. Three former baseline
invocations become one, retaining each success assertion.

Unchanged source and probe classes compile once. Each changed source compiles
successfully into a private directory and runs the complete probe in a fresh
JVM. Source, probe, engine and compiler fingerprints accompany the results.
Missing controls, altered failure expectations and removed baseline assertions
are themselves tested by changing the inventory and requiring refusal.

Observed suite time changed from 101.31 seconds to 84.26 seconds, with 39
compile/probe pairs reduced to 36. These are measurements of the retained runs,
not a full-gate performance claim.

Review also corrects the native suite's success label for the existing verdict
reader. Border 76 now counts executable calls rather than comments and reads
both printed border formats. Three file mutations establish that stale counts
refuse. The current gate invokes 173 test files and 13 other Python scripts;
its highest printed label is 175.

The first full gate found the county-simulation harness's explicit load list
missing BodySnapshot, now required by AfflictedReturn. The harness loads the
shared module, and Border 159's missing-dependency control includes it. The
targeted simulation evidence check passes after correction; the initial gate
receipt retains the refusal.

The closing run also exposed F-088: simultaneous engine probes can read an
incomplete shared Java helper. Eight concurrent Lua-free runs reproduced one
truncated-class refusal, and a paused-writer control reproduced the same defect.
Engine-facts compilation now has a private directory per invocation; its
correct declaration that it does not inspect mod Lua remains in force.

Deployment verifies all 251 SAO and 29 ZAO A37 files against source. The
development launch exposed a missing early-agent classpath dependency; adding
the installed ZombieBuddy jar resolves the reproduced Byte Buddy load failure.
The game opens and lists both Java mods. All 44,092 save-file size/time entries
remain unchanged. Loaded-world acceptance remains separate.

## Evidence and continuation

Border 162 executes the refactored production modules and extends its controls
through damaged pending native/visual payloads, invalid position/time, missing
physical facts, and opaque visual tables. Borders 164 and 166 retain joint
return and checkpoint coverage. The native suite and its controls pass against
the installed Build 42.20 engine. The engine compiler accepts all 69 Lua files.

The [evidence directory](../artifacts/audits/20260920-0158Z-1858PST-person-continuity/)
retains before/after ownership output, checkpoint/return output, native suite
receipts, crosswalk validation and final review/gate/deployment receipts.

The next restructuring unit is runtime reconstruction and scheduling:
population admissions, representation scheduling, physical observations and
dormant advancement retain separate responsibilities under History. R10a's
world-source investigation remains attached to dormant opportunity. The rest
of R6-R15 remains explicit work in ROADMAP and SUBSTRATE. This batch does not
close whole-mod restructuring, private assembly or loaded-world play acceptance.
