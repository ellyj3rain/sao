# C65 - Source action decisions

| Field | Record |
|---|---|
| Batch | `C65` |
| Date | 2026-09-21 |
| Name | Source action decisions |
| Status | Closed, validated and deployed; full gate enforced by the closing commit. |
| Threads | [`T-003`](THREADS.md#t-003), [`T-008`](THREADS.md#t-008), [`T-009`](THREADS.md#t-009), [`T-030`](THREADS.md#t-030) |

## Contract and measured substrate

R11 needs actual executable options, the separate selection and an observed
action result. C62 already owns the food/water lifecycle; C64 supplies immutable
capture and exact cross-repository joining. Source selection is currently hidden
inside reservation creation, so no explicit offered set exists at the decision
boundary.

| Contract | Producer and caller | Persistence and observation | Gap addressed here |
|---|---|---|---|
| Private opportunity | Perception source facts; Controller's need/ration/standing admission | Private source revision; Borders 178-179 | Expose only those source attempts the existing policy can consider. |
| Exact choice | WorldSources chooses the first source by stable identity inside `beginAction`; SourceUse calls it | Reservation already owns exact source/item/revision | Separate options and selection; revalidate the selected descriptor without substituting another source. |
| Performed action | SourceUse approach, current binding, transfer, native use and reconciliation | Durable reservation/result; Border 179 | Link capture to the exact reservation and preserve completed, refused, interrupted and pending results. |
| Decision evidence | C64 tool freezes person and situation before Standing election | Frozen JSON and atomic county publication; Border 181 | Observe the real source choice with executable parameters and decision-time evidence. |

The offered domain is a food or water attempt at the already selected known
place. It does not describe every decision the person could make. The existing
policy retains its stable first-source preference. Access is checked on arrival;
an offered attempt promises execution of that check, not successful consumption.

## Continuation boundary

Speakeasy choice authoring/ratification, decision-time knowledge reconstruction,
broader action producers and later social/physiological consequences remain with
R9/R11/R12. This batch observes the immediate native-use result and explicit
pending/censored evidence. It does not mark a runtime policy choice approved for
training.

## Implemented behavior

`WorldSources.actionOptions` enumerates a bounded, stable set of attempts from
the actor's own source beliefs after the existing need, standing and ownership
admission. Each descriptor identifies the action owner, source, native item,
revision, quantity and eligibility evidence. Listing creates no reservation.
`SourceUse.chooseOption` preserves the current first-source policy. `beginAction`
rechecks the selected descriptor immediately before reservation; a changed source
refuses instead of silently selecting another.

The capture tool freezes the person, situation and executable options before
the actual selector runs. It records the runtime choice separately, links the
executed reservation and reads that reservation's actor-scoped outcome at capture
end. Completed, refused, conflicting, interrupted and pending work remain
distinct. A result outside the bounded retained ledger is explicitly censored.
Requested quantity and observed native consumption are separate fields.

The county sweep does not load SourceUse and reports `source-executor-not-loaded`
with zero source events. Installed-VM fixtures exercise the real Lua owners with
controlled native adapters. They establish the mechanics of capture, not a
completed live-world corpus. The captured choice remains `runtime-policy`,
unratified and conditioning-ineligible; knowledge reconstruction and later
consequences remain absent.

## Review and verification

The independent action review found no actionable runtime defect. The capture
review found one Medium defect: an unreadable/newer-schema result store looked
like ordinary aged-out evidence. The corrected reader permits censorship only
for `result-not-retained`; every other failed required outcome read rejects
capture. The schema-6 control reproduces that distinction. Quantity controls
also prevent an interrupted request from claiming consumed material.

The independent validator passes normal/debug compilation of all 76 Lua files,
Border 179's exact source lifecycle, Border 180's 53 production cases and named
mutations, Border 181's immutable capture/publication controls, the shipped
version stamp and all 19 sort sites. C65 adds controls to Border 181; it adds no
new gate entry. Two production mutations prove detection of silent retargeting
and live mutable outcomes. Other controls cover source privacy, 128-option bounds,
stale revision, permission change, forged descriptors, selection-time mutation,
pending/interrupted/censored results and required-reader failure.

The first full gate found a stale Border 129 assertion that still required the
retired `selectedItem` local. Its identity check now follows the native item into
the option and from the selected option into the reservation, including the
revision. The corrected border passes; replacing the reservation's selected
item ID with zero makes the same named verdict fail. Runtime code is unchanged
by that gate repair.

The same gate exposed two older harness assumptions. The county inventory now
declares SourceUse among the loaded-body modules it intentionally does not run;
Border 159 refuses that dependency when its declaration is removed. Border 162's
WorldSources fixture now supplies the explicit option interface and asserts that
the chosen descriptor reaches reservation creation. The production source
executor remains covered by Borders 179/181. These repairs preserve the county's
reported coverage gap and the handoff border's actual ownership mutations.

The closing commit must pass the complete installed-engine gate: 179 test scripts
and 13 other Python entry points, 192 distinct scripts through Border 181. The
mandatory pre-commit hook validates the final staged tree before publication.

## Deployment and startup

Version `2.8.2.0-pre-alpha` is rebuilt and deployed through `tools/deploy.sh`.
All 258 installed files match source, including the subsequently synchronized
attribution document. The jar SHA-256 is
`91fe77163bec1a0921282d6cb8620d3678a4f6739d380319c76ab93d7771b1da`.
All 44,092 save paths, sizes and modification times and ZAO's 29-file content
and metadata manifest remain unchanged. The responsive client is visibly at
the main menu with SAO and ZAO among four active Java mods. Agent and Lua markers
load; the known early bridge exposure retry succeeds two seconds later.
No save was loaded. Startup does not establish save-backed action acceptance.

The [evidence record](../artifacts/audits/20260921-0057Z-1757PST-source-action-decisions/README.md)
holds focused verification, review disposition, exact deployment and startup.
The operator-supplied PZ_Optimization reference is assessed there against the
actual chunk-loading owners and recorded in SUBSTRATE/CREDITS. No external
implementation was installed or incorporated.
