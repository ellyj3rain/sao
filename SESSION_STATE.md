| Document | Survivor Awareness Overhaul Session State |
|---|---|
| Version | `2.7.14.4-pre-alpha` |
| Author | ellyj3rain |
| Repository | `SESSION_STATE.md` |
| Status | CANONICAL - current implementation and continuation. |

# Session state

**As of** 2026-09-19, `[C53]` closes shared county time after the authorized Afflicted return and consolidated C1-C50 catalog.
The C catalog is consolidated by adjacency and content using
the A/B precedent: 29 A-batches, 52 B-batches and 51 C units, including the first post-consolidation repair. BATCH_LOG.md owns
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
| Person continuity | Durable identity, C51's supported body transaction and C52's authorized return/adoption/teardown with bodyless recovery | R3's remaining component persistence. |
| Time and health | Current decision ticks, explicit day/tick conversion, catch-up/reload progress, separate host pacing, infection course | Cadence-dependent brain health, drug scheduling and stale live inputs remain R5 work. |
| Afflicted and Crossed | ZAO pathogen state, Afflicted return transaction, four-pillar mind, a Crossed driving adapter | A32's Crossed decision pass is unreachable and lacks the retained human action system. Proximity exposure lacks an intentional action and SAO-to-ZAO ownership transfer. F-084 and SUBSTRATE assign the complete repair across R4-R10. |
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

R1 closes in C52 and ZAO A35. The living transaction, source holding and
acknowledged removal, controller adoption, failure diagnostics, repeated-death
binding, current-possession transfer and bodyless path have controlled VM
coverage. Review also found and repaired the missing observed-reanimation
producer and missing save-time checkpoint for loaded people. Current supported
appearance now has a durable native visual sidecar.

The [R1 evidence record](artifacts/audits/20260919-0735Z-0035PST-r1-return-evidence/README.md)
separates tested behavior and native verification. The operator selected
critical viability with actual injuries preserved. ZAO now clears native
lethal/fake Knox state, raises weighted body-part health only to the return
floor, and preserves wounds, treatment, fractures, ordinary wound infection,
statistics and XP. The Afflicted state remains the systemic-dormant Knox owner;
publication refuses if that operation fails. Pending-source preservation covers ordinary/fake-dead
checkpoints and exact native reanimated-registry ownership, including offscreen
return and held-equipment recovery. Large saved snapshots use bounded string
fragments; unsafe oversized native item fields refuse capture before teardown.
The added installed-engine physiology probe and four defect controls pass. Both
full gates pass: 167 SAO borders and seven ZAO borders, including 37 compiled
native source controls. Failed native source checkpoints are
isolated from other identities and ordinary item processing; failed identities
remain unavailable until a fresh world load.
Component/table serialization, running-world save/reopen and interrupted-save
guarantees remain distinct. C52/A35 are closed implementation batches and remain undeployed.

R2 closes in C53. `History` now owns the 9000-tick hour and 216000-tick day
conversions. `Controller.tick()` refreshes at the decision boundary, including
each historical substep inside one callback. WorldGenesis converts its day to a
day-start tick before Integration consumes it. Native death-fall grace and
operational flushing use a separate host-callback counter. The canonical unit
inventory records the legacy hour/day names, wall-millisecond surfaces and
non-time `updatedAt` counter rather than inferring units from `At` alone.

Border 168 executes the shipped History, Controller callback and WorldGenesis
in Kahlua across substeps, module reload, midnight, Day Zero settings,
nondefault DayLength and large county-time skips. Three controls restore the
cached decision value, day-as-tick call and county-paced corpse grace and fail
at those defects. Border 160 retains production partial-day catch-up/reload.
ZAO needs no R2 source change: its loaded controller reads the fresh SAO tick,
and its durable pathogen history is explicitly day-based. C53 is undeployed;
loaded-world pacing remains a play observation rather than a mechanical claim.

The same audit found that the published A32 Crossed-execution claim is false.
Normal Crossed state sets `currentForm` to `none`; the controller admits the
whole Crossed decision pass only for a non-`none` form. Even if entered, it does
not provide the canonical human-looking body's retained weapon, tool, combat or
general action vocabulary. Both exposure callers here are daily three-tile
proximity proxies, and a successful state change leaves the living Afflicted
body under SAO. There is no spontaneous Afflicted roll. F-084 and SUBSTRATE's
Crossed contract make the representation, actions, non-feeding Afflicted
interaction, exposure result, ownership transfer and loaded/dormant continuity
explicit work under R4-R10 rather than calling the connector complete.

ROADMAP.md now defines R1-R15 with owners, dependencies and completion evidence;
SUBSTRATE.md supplies the mechanisms, producer inventory and bounded technical
investigations. Remaining work is planned, with implementation and verification
still to do.

The immediate repair is R3: extend native person continuity and validate the
next native update on the repaired time axis. R4 follows with durable/runtime
reconstruction, including same-process world changes and pending work. R11-R12,
immutable capture, protected approved data and world-knowledge preparation, can
progress alongside these repairs. Pathogen state continues to belong to ZAO
when present.

C51 repairs the F-077 body handoff. Capture failure keeps the prior record and
ownership; incomplete teardown retains a durable snapshot for retry; all callers
restore through Body before adoption. Native supported-state snapshots preserve
inventory, equipment, wounds, statistics and experience. Legacy v1/v2 remain
readable within their original limits. Character ModData, nutrition, fitness,
recipes and human appearance are outside this snapshot. R3 also covers reading
progress, descriptor perk boosts and fluid-content validation; it assigns the
verified component seams and the remaining continuation probes.
See the C51 batch record and Borders 162-163 for the tested boundary.
Built-in graph callbacks do reconstruct after save/load; the engine omits
closures rather than failing the save. Extension registrations need their
own reconstruction contract.

R4-R10 cover reconstruction, health and dormant physiology, perception/access,
action receipts, the audited action repairs, each life-simulation producer and
historical/population accounting. R13-R15 cover reproducible training/export,
actual learned action and speech consumption, and evaluated late-start
acceleration. The coverage table maps every audited former C112-C127 entry and
the broader life concerns to these contracts. Available actions and their
consequences remain separate from the learned policy choosing among them.

## Verification and installed state

C53 has 168 numbered borders through 183 gated mirrors; the
published C51 baseline has 163 borders through 178 mirrors. These counts describe the
apparatus, not acceptance. The audit reproduced defects while targeted checks
passed. The earlier audit's intermittent Border 54 failure remains unexplained.
C51's separate first gate found a verdict-prefix defect and missing transition
registry surfaces/lifetimes. Its failed output is preserved with the corrections;
the closing full gate passed with exit 0.

The verified C51 install was deployed on 2026-09-19 through
tools/deploy.sh. All 249 installed files match source, with no missing or extra
files. The SAO jar SHA-256 is
`d3592141fe8ac8deae1d9ef2f8253b649c84076421fb062a59222636302babdc`.
The C51 evidence directory holds the build, gate and deployment receipts.
Saves remain untouched; no loaded-game acceptance is claimed.
The source coordinate follows
the consolidated replay; its movement does not measure implementation quality.

## Decisions and observations still owed

Grounded-dead numeric calibration, the denominator and phase of early Knox
ratios, and irreversible pruning of saved relationships remain unresolved.
They do not block already-ratified mechanics. Play observations belong in
RECEIPTS.md. No play session is requested or polled as a new prerequisite.
Loaded-game inference sizing remains a measurement for the actual model path.
