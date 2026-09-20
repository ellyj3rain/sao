# C57 person continuity evidence

Timestamp: 2026-09-20 01:58 UTC / 18:58 PST

This unit implements DR-041/DR-042's first runtime responsibility boundary.
The source inventory in the preceding planning directory describes C56;
this record describes the C57 delta.

| Contract | Producer and transaction owner | Persistence | Evidence | Limit |
|---|---|---|---|---|
| Durable body envelope | BodySnapshot captures, validates and commits; Body owns lifecycle | Existing person hibernation, visual, position/time and physical-fact fields | handoff-before/after; checkpoint-after | Older sidecars may be absent; supplied payloads are validated. |
| Exactly one body owner | Body release and external transfer; AfflictedReturn stages and adopts | Existing pending release/transfer/return records | handoff-after; return-after | Loaded-world save/reopen remains a separate observation. |
| Native continuation | Unchanged native snapshot and hibernation classes | Native v1-v4 readers and current v4 output | native/consolidated.json | Installed Build 42.20 probe, not play acceptance. |
| Historical verification coverage | Executable native cases and mutation crosswalk | Checked-in JSON inventories | native/inventory.json; missing-source receipts | 36 historical names represent 35 distinct mutations. |

The engine compiler accepted 69 Lua files. Targeted handoff verification passed
30 controls; checkpoint and joint return instruments also passed. The unchanged
native probe retains 84 assertion call sites. The baseline used 39 compile/probe
pairs across three entry points; consolidation uses 36 with unchanged-source
compilation shared and each changed-source run isolated in a fresh JVM and
working directory. Observed elapsed time was 101.31 seconds before and 84.26
seconds after (16.8% lower for this suite).

## Review disposition

Runtime review found no must-fix defect. It confirmed capture before publication,
release commit after teardown, checkpoint ownership, external transfer ordering
and shared-module loading without eager client dependencies. Its advisory is
retained: an absent legacy visual sidecar is compatible, so validation does not
prove every historically optional journal field is present. Stronger journal
completeness would need explicit schema provenance.

Coherence review matched all 36 historical mutation fingerprints and the
unchanged probe hash, verified isolated mutation classpaths, shared loading,
source-root overrides and removed-script consumers. It found one medium defect:
the combined success label was unreadable to the existing verdict parser. The
native suite now prints the recognized `163)` prefix and retains 169/174 in its
description. The blinded missing-Lua plus missing-engine case refuses before
environment skipping.

The canonical-count check had independently stale instrumentation: it counted
a comment as a call and missed later printed verdict forms. `state-counts.json`
retains the corrected executable reading and three controls that remove a test
call, remove a helper call and advance a printed label. Each makes the formerly
correct canonical claim fail. The six figures are 29 A records, 52 B records,
173 test files, 13 other scripts, 186 distinct gate scripts and highest label 175.

During the full gate, the standing-mirror loop suppressed output while progressing
through its checks. `triage_test.py` imports `equilibrium_test` at module load,
which reruns the fixed 120-day, 60-person simulation before triage prints.
Neither file consumes this batch's changed runtime code. This is a concrete
shared-setup candidate for later border restructuring; C57 retains that work.

The initial full gate refused at Border 159 because the county-simulation
module list omitted the new shared dependency. `county_sweep.py` now loads
BodySnapshot after Identity. The missing-dependency control removes that module
as well as the original Census case. `simulation-after.txt` records the passing
installed-VM evidence check after correction. The initial gate log preserves
the original failure.

F-088 arose in the subsequent closing run: the engine-facts check could read a
partially written shared `LuaRun.class` while Border 54 invoked other compilers.
`engine-facts-repro.json` retains a one-in-eight concurrent refusal and a
deterministic paused-writer reproduction. The correction isolates compilation
per invocation while retaining the check's valid independence from mod Lua.

Two refused closing attempts were stopped before completion. The second stop
unexpectedly returned success to Git; its unpublished commit was immediately
removed with a soft reset, preserving the index and working files. That
interrupted attempt is not accepted as verification. The final closing gate
must finish naturally with all borders clean before publication.

`full-gate.json` records the initial complete run (612.4 seconds, exit 1), whose
sole finding was the corrected Border 159 dependency. The enforced pre-commit
hook reruns every border on the final source before publication. The local
closing receipt and public PR checks record its result; the original failure
is retained rather than replaced by a success claim.

`deployment.json` verifies 251 SAO files and 29 ZAO A37 files with no missing,
extra or differing content. `saves-after.json` confirms unchanged size/time
entries across all 44,092 existing save files. `startup.json` records the game
window and loaded modules. Raw launch logs stay local because they include
unrelated mod output and account identifiers.

The original development launcher exited with `NoClassDefFoundError` for
`net/bytebuddy/agent/builder/AgentBuilder$TypeStrategy`: its agent ran before
ZombieBuddy supplied the bundled dependency. The corrected launch classpath
includes the installed ZombieBuddy jar. The game opens, lists both Java mods,
installs the body-scale weave through its normal mod entry point and exposes
the Lua bridge. The early agent's unavailable retransform attempt recovers
through that normal entry point. Startup establishes no loaded-world play claim.
