| Document | Survivor Awareness Overhaul Session State |
|---|---|
| Version | `2.7.14.1-pre-alpha` |
| Author | ellyj3rain |
| Repository | `SESSION_STATE.md` |
| Status | CANONICAL - current implementation and continuation. |

# Session state

**As of** 2026-09-19, `[C50]` is the consolidated catalog tip.
The C catalog is consolidated by adjacency and content using
the A/B precedent: 29 A-batches, 52 B-batches and 50 C units. BATCH_LOG.md owns
the chronology. Batches/FORMER_LABELS.md maps every former entry;
Batches/C_RECATALOG.json preserves original paths and source hashes. The
original records remain at local ref `archive/c-era-raw-20260919`.
Consolidation does not certify the implementation or add a runtime capability.

## Current assessment

The [implementation audit](artifacts/audits/20260919-0356Z-2056PST-c112-c126-implementation-audit.md)
examined former C112-C126 and the former C127 recovery. Thirteen original
batches require rework; former C115's configuration wiring is retained;
former C126's fixed-outcome trajectory implementation is rejected and remains
removed. Those entries now belong to C41-C50. Immutable audit evidence keeps
its former labels and hashes.

The full life-simulation contract remains in force. Engine adapters, durable
records, state readers, action selection and completed consequences are distinct
parts of its implementation. SUBSTRATE.md maps the actual ownership boundaries,
producers, persistence, evidence and gaps.

| Area | Existing substrate | Open implementation |
|---|---|---|
| Engine execution | NPC shell, bridge, movement, combat, timed-action adapters | Driving route ownership and progress; action cancellation and completion receipts. |
| Person continuity | Durable identity, materialization, hibernation, adoption | Returned bodies lack adoption; dormant afflicted recovery is absent; optional drug counters need persistence. |
| Time and health | Shared hours/ticks, catch-up progress, infection course | Cached controller time, day/tick mismatch, cadence-dependent brain health and stale live inputs. |
| Knowledge and access | Private beliefs, scanner, remembered sources, permission | Animals enter human beliefs; integrations can read inaccessible or unperceived state. |
| Social development | Company mechanics, claims, observations, graph APIs | Automatic relocation and recognition; incomplete provisioning, affiliation, governance and other producers. |
| Speakeasy data | 190 ratified choices, cross-module contract, approved world documents | Mutable decision snapshots, source conditioning, executable options and complete capture provenance. |
| Models and late starts | Inference primitives, fact constraint, offline diagnostics | No trained cognition model, complete training/export path or validated accelerator. |

## Retained recovery evidence

C50 removed the invalid trajectory shortcut and repaired elapsed-time catch-up,
partial progress, company admission, diagnostic refusal and provenance. It also
repaired the neuroinflammation off switch. Those repairs do not close the later
audit's mechanism failures.

Independent 90/365-day joint samples completed 19,440,000/78,840,000 ticks with
zero recorded execution faults. Their population target was 12; refill produced
27/72 records and 15/60 deaths. These are open populations with different seeds,
not a survival cohort. A seven-day target-500 attempt timed out at 600 seconds
and exported no receipt. Original evidence lives in tools/sweep/receipts/;
filenames, seeds and hashes remain unchanged.

## Continuation

ROADMAP.md orders the remaining work. The first bounded repair concerns shared
time and durable-state handoffs: consumers must agree about time during live
callbacks, historical substeps and reload. The engine serialization boundary
must be verified before an in-memory registry is called persistent. Pathogen
state is read from its actual owner.

The first concrete defect is Body.release removing a body after failed
snapshot capture, with Population already having dropped its controller.
F-077 records successful, throwing and empty-capture engine-VM controls.
The repair must cover the caller and callee as one ownership transition.
Built-in graph callbacks do reconstruct after save/load; the engine omits
closures rather than failing the save. Extension registrations need their
own reconstruction contract.

Then repair perception/access and completed action consequences, complete the
missing life-simulation producers, repair capture and build the Speakeasy
training/runtime path. Available actions and their consequences are implemented
separately from the learned policy choosing among them. The full producer map
remains open; one repaired connector does not complete it.

## Verification and installed state

161 numbered borders run through 176 gated mirrors. These counts describe the
apparatus, not acceptance. The audit reproduced defects while targeted checks
passed. Border 54's intermittent failure remains unexplained; its first output
is now preserved rather than hidden by a clean replay.

The last verified install is the 2026-09-18 recovery at the former coordinate
recorded in tools/sweep/receipts/README.md, SAO jar SHA-256
`0abe4198166835b5f95f22215c4689dd9f3a787d03fdeccfe1e4285e112ac9be`.
All 249 SAO and 27 ZAO files matched at that inspection. This consolidation
claims no new deployment. Saves remain untouched. The source coordinate follows
the consolidated replay; its movement does not measure implementation quality.

## Decisions and observations still owed

Grounded-dead numeric calibration, the denominator and phase of early Knox
ratios, and irreversible pruning of saved relationships remain unresolved.
They do not block already-ratified mechanics. Play observations belong in
RECEIPTS.md. No play session is requested or polled as a new prerequisite.
Loaded-game inference sizing remains a measurement for the actual model path.
