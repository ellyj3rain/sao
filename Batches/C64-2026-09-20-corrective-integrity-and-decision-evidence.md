# C64 - Corrective integrity and decision evidence

| Field | Record |
|---|---|
| Batch | `C64` |
| Date | 2026-09-20 |
| Timestamp | 2026-09-20 23:20 UTC / 16:20 PST |
| Name | Corrective integrity and decision evidence |
| Status | Closed, validated and deployed. |
| Threads | [`T-003`](THREADS.md#t-003), [`T-006`](THREADS.md#t-006), [`T-008`](THREADS.md#t-008), [`T-009`](THREADS.md#t-009), [`T-030`](THREADS.md#t-030) |

## Why this batch exists

C64 audits the C49-C63 continuation before building further on it. The review
treated the last implementation batches as suspect and traced each claim back
to its producer, persistence boundary and executable control. It found that the
recent source-action work contained useful substrate, but C63 promoted one
selected source into complete house inventory, left that projection stale after
later native change, and inherited two earlier runtime defects. The old decision
dump and Speakeasy join also could not support ML conditioning.

The operator's 190 approved choices are retained. Their implementation context
is assessed independently from their intent.

## Runtime corrections

| Finding | Correction and evidence |
|---|---|
| C55 extension replacement could destroy the last accepted runtime graph when a new installer refused or threw. | Registration and removal now roll back the installer registry and reconstruct the accepted graph. Border 170 executes false-returning and throwing replacements. |
| C54 returned a person's visual body with hair-growth timing read from the temporary living shell. | Native return capture reads both growth timers from the returned source. The consolidated native suite adds a C64 mutation that substitutes the living shell and is rejected. |
| C63 material remained stale after player looting, rot, movement or disappearance. | WorldSources schema 5 persists a bounded, coalescing change queue. Provisioning drains it after reload and Material refreshes or retires only an already-owned exact source. Ambient observation never creates ownership or work credit. |
| C63 treated the source selected for one action as complete house coverage. | Every selected-source projection is explicitly partial. Partial stores do not derive larder/water claims or settlement storage. Graph schema 3 and Standing schema 3 retire C63's unsupported aggregate outputs while retaining exact source rows. |

The C63 substrate remains useful after correction: completed native use can
attribute one exact source to held ground, preserve one owner, and reconcile
that source later. It no longer claims to know every item in the house.

## Immutable decision evidence

The old county dump retained live Lua tables until the county ended, swallowed
required-reader failures as `nil`, inherited fabricated claim ground from the
sweep prelude, accepted partial horizons, omitted run identity and wrote each
county before the remaining workers validated.

The replacement uses the canonical evidence host and freezes deterministic JSON
before the real election runs. The result is captured afterwards in a separate
field. A unique capture invocation and per-county run identity sit beside the
deterministic configuration hash, county/event namespace, decision-time random
state, engine mode, requested and reached horizon, clock/schema versions,
settings and source/model provenance. Required-reader, cycle, unsupported-value,
callback and incomplete-horizon failures reject the run. Every requested county
must validate before one staged directory becomes visible through an atomic
rename.

The captured legacy election exposes neither executable options nor a model
choice, and no action-specific later consequence is observed. Each event says
so and is conditioning-ineligible. This is a trustworthy decision-authoring
input, not a manufactured training row.

[Border 181](../tools/decision_capture_test.py) mutates a nested identity
record, belief and claim during and after the real election. The frozen decision
retains the earlier bytes while the separate result sees the new designation.
Required-reader and cyclic-table controls reject capture while allowing the
real election to continue. Atomic-publication and repeated-run identity controls
cover the outer envelope.

A one-day live smoke was correctly refused because the canonical county sweep
also records 377 protected callback failures at that horizon. No partial dump
was published and the refusal is not presented as a completed-county receipt.

## Speakeasy boundary

The protected version 2 data contains 190 ratified choices. Of those rows, 184
contain a future death, 182 contain a future lesson and 163 contain a future
belief; all 190 options are bare strings. The `(person, hour)` join also
collapses six work-word and fifteen trade-hinge rows across counties. The
unmerged C126 trajectory branch contains eight aggregate diagnostics from
different seeds and horizons, without person decisions or reproducibility and
eligibility provenance. It is diagnostic history, not a corpus.

Speakeasy PR [#13](https://github.com/ellyj3rain/zomboid-speakeasy/pull/13)
merged the version 3 correction. It protects the approved choices, four
historical derivatives and nine approved world documents by hash; requires
run, county, person, event and hour; validates executable action owners,
parameters, eligibility evidence and conditioning time; prevalidates both
inputs; refuses inputs and protected destinations; and publishes by atomic
replace. The approved choices remain intent while their old conditioning stays
ineligible.

## Review disposition

All Critical and High findings from the corrective review are resolved in this
batch or the merged Speakeasy change. The returned-body timing Medium is also
fixed. One Medium remains deliberately open: `SAO_BodySnapshot` reaches current
physical facts through the Population facade. The audit found no state loss or
wrong result from that route, and changing the ownership seam inside this
corrective batch would expand the runtime restructure without behavioral
evidence. It remains named structural work for the next relevant ownership
slice.

## Verification

Focused production checks pass:

- Border 163/169/174 consolidated native continuation with 36 compiled
  mutations, including the C64 growth-timing substitution;
- Border 170 runtime reconstruction and transactional extension replacement;
- Border 178 world-source schema 5 and durable ambient-change evidence;
- Border 180 with 53 provisioning cases, partial-coverage rules, exact ambient
  refresh/retirement and C64 migrations;
- Border 181 immutable capture, labeled refusal, unique execution identity and
  atomic publication;
- normal and debug Lua compilation over 76 shipped files;
- seven Speakeasy version 3 join controls and the reproducible 190-row
  conditioning audit.

The first full-gate attempt found useful additional defects before closure: the
new ambient queue reached Kahlua's recursive `table.sort` without an explicit
read-bound; thirteen canonical version headers were stale; Border 147 still
looked for display-name capture in the retired Python owner; Border 148 still
invoked the pre-C64 mutable dump; Border 179 expected WorldSources schema 4;
and the shipped jar still carried the prior version. The queue now trims to its
2,048-entry ceiling before copying and sorting. The three older borders follow
their current owners and the jar is rebuilt from the version machine.

The closing full gate passes all 192 scripts through Border 181 against the
installed game and rebuilt jar. The exact deployment contains 258 files with
no missing, extra or different content. Its jar SHA-256 is
`EF5CBDE75EEA78825EFA9B86123B3205A37A263273C30F25346822BDFCA8E80A`.
All 44,092 pre-existing save files and ZAO A37's 29 installed files remain
unchanged across deployment and startup.

The final Project Zomboid window is responsive and visibly lists PeekAView,
Staircast, SurvivorAwareness and ZombieAwareness as the four active Java mods.
The agent verified `IsoPlayer`, installed the melee, body-scale and loot-density
hooks, loaded `com.sao.Main`, and exposed `SAOJavaBridge` after its known
two-second readiness retry. Harness and Population Lua markers loaded with zero
SAO failure lines. Existing third-party translation, fluid-name and attachment
errors remain outside SAO. No save was loaded, so startup proof remains distinct
from save-backed play acceptance. The process is left open.

The [C64 evidence record](../artifacts/audits/20260921-0003Z-1703PST-corrective-integrity/README.md)
holds the validation, deployment, unchanged-save/companion and startup receipts.

## Continuation

R11 remains open for real executable-option capture, separate choice authoring,
execution revalidation and action-specific consequence horizons. R12 proceeds
with versioned decision-time reconstruction and person-specific approved
knowledge. R13 training remains blocked until eligible R11/R12 views and the
relevant R8-R10 producer coverage exist.

R9 also remains open. Performed shelving, acquisition, carrying, storage,
sharing, hoarding, trade and place development still require their own action
results; a corrected partial source projection does not complete them.
