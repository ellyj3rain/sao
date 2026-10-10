| Field | Value |
|---|---|
| Batch | D3 |
| Name | Construction, crafting, repair and utilities |
| Opened | Following D2 closure on 2026-10-09 |
| Record timestamp | 2026-10-10 01:43 UTC / 18:43 PST |
| Status | OPEN - first material-work join implemented; whole product continues |
| Branch | neo/d3-construction-crafting-repair-utilities |
| Owner | Neo, SAO chief implementer and Objective Alignment Steward |
| Follows | batch:D2 |
| Shared contracts | C12, C18, C20, C21, C24, C30, C31, C32, C33 |
| Implementation | Closed children deliver native material crafting, held-tool maintenance, plumbing and rain-collector construction with private acquisition, measured effects and saved continuity. Remaining whole-domain work keeps the parent OPEN. |
| Verification | First-join evidence remains dated below. CLOSED D3.1 through D3.5 link native crafting, maintenance, plumbing and collector construction to private planning, lifecycle, cognition, persistence and usable-water evidence. |
| Version | 3.12.0.0-pre-alpha through D3.1-D3.5; this OPEN parent receives no duplicate capability credit. |
| Publication | D3.1-D3.4 are self-merged through PR142-PR145. D3.5 follows the established protected child workflow; actual merge evidence belongs to its publication receipt. The whole parent remains OPEN. |

## Product and current implementation

D3 retains its complete accepted module scope and integration obligations.
[D3.1](D3.1-20261010-0344Z-2044PST-native-plank-crafting.md) is its CLOSED
child: native plank crafting for the retained construction purpose. Its
reason, scope, owners, contracts, dependencies and required closure evidence
were recorded before the new crafting implementation. The first material-work
join retains its existing D3 history and supplies the child's integration.
Child closure and publication leave this parent active; capability changes
receive credit once under the existing odometer.

[D3.2](D3.2-20261010-0430Z-2130PST-native-saw-maintenance.md) is CLOSED with
native saw maintenance under the retained construction purpose. Its exact
target/file contract, native Maintenance gate, use-versus-maintain choice,
owners, dependencies and required closure evidence are recorded before
implementation. The full D3 parent remains active.

D3 carries the whole construction, crafting, repair and utilities domain through
personally acquired need, exact materials and source authority, native work,
measured physical effects, interruption, private feedback and persistence.
The first implemented join connects an observed permitted damaged window or
boarding entry to missing-material acquisition, native preparation, return to
the retained destination and authenticated native completion.

Observation precedes carried-material readiness. `SAO_WindowRepair` and
`SAO_Build` issue sealed body-bound offers from currently visible, reachable
entries under Standing. Their detached interaction coordinates become private
planning destinations. `SAO_ProceduralPlanning` retains the same purpose and
exact acquisition steps while `SAO_SourceUse` obtains personally remembered
items at their acquired source revision. Missing or refused means retain an
inspectable unfinished purpose. A temporarily unavailable boarding entry yields
to other visible work with a bounded retry while preserving the security purpose.

Finite material categories include the exact glass pane, usable hammer, native log and usable tagged saw. D3.1 joins exact private log/saw acquisition to installed handcraft, measured held planks and return to the original boarding entry.
Boarding counts and selects loose `Base.Nails`; a nail box supplies no loose-nail
credit. Native inventory transfer prepares items carried in nested bags. The
boarding owner equips the exact hammer and plank through installed actions,
then admits the installed `ISBarricadeAction`. The former eager Java boarding
entry point is inert. The actor-bound wrapper corrects the installed hammer-tag
validity call for this NPC work while retaining the original physical action.

Completion requires the exact owner, person, purpose, step, admission, queue,
materials and target. Window completion measures pane consumption and restored
glass. Boarding completion measures one consumed plank, two consumed loose
nails and changed barricade state. Admission, preparation and elapsed time grant
no completed construction credit. Cancellation retains the exact old action
until native acknowledgement without clearing successor queues or flags.

Saved terminal results replay through the original canonical consumers. If
private runtime work is lost, reconciliation validates the saved work and exact
pending admission, native queue emptiness, ledger and county clock before
emitting an interrupted recovery result. That result grants no physical or
completion credit; the purpose and destination survive for a new attempt.
Live owners use normal cancellation and wait for native acknowledgement.
Malformed or unobservable saved work stays inspectable and blocks replay.
Controller adoption and IDLE continuation both invoke the recovery owners.

## Source ownership and integration

| Owner | Changed responsibility |
|---|---|
| `java/src/com/sao/engine/SAONeeds.java`, `SAOWorldSources.java`; `java/src/com/sao/bridge/SAOBridge.java` | Exact native categories, private carried counts, source encoding and current boarding visibility. |
| `mod/42.20/media/lua/shared/SAO_WorldSources.lua`, `SAO_Material.lua` | Finite personally acquired materials and durable source projections. |
| `mod/42.20/media/lua/shared/SAO_ProceduralPlanning.lua` | Material acquisition, retained destination, owner-authenticated terminal result and target retry under the same purpose. |
| `mod/42.20/media/lua/client/SAO_Build.lua`; `java/src/com/sao/engine/SAOBuild.java` | Native boarding preparation, execution, measured result, cancellation and saved-admission recovery. |
| `mod/42.20/media/lua/client/SAO_WindowRepair.lua` | Observation before pane readiness, nested-pane preparation and saved-admission recovery. |
| `mod/42.20/media/lua/client/SAO_Controller.lua`; `mod/42.20/media/lua/shared/SAO_Identity.lua` | Exact acquisition/return/execution, adoption recovery and death/transfer retirement. |

Installed engine actions remain physical producers. The optional repair action
remains its source-owned producer through the existing sealed wrapper; no source
bytes or license grant are invented. Its standalone-package replacement belongs
to the continuing proprietary integration scope. Existing WorldSources/SourceUse,
Standing, locomotion, cognition and person records keep their ownership.

The live Mousecat bulletin was read at this integration. Material-repair revision5
and owned-mod-mechanics-downstream revision1 retain exact materials, native
effects, private feedback, save continuity and concrete downstream ownership.
Their older D2-open/D3-queued status is superseded by current canonical D2 closure
and this D3 continuation. Physical-feedback revision2 reinforces trying other
remembered means after refusal. This join changes SAO producer/planning contracts;
it supplies no ZAO, Speakeasy or Post Latent implementation or reciprocal peer
acceptance. Liaison04 retains communication and state custody.

## Retained first-join verification

Changed inputs and selected checks are retained in
`_scratch/d3-material-work-01/verification-plan.json`. Production Java, finite
categories, material planning, native preparation/effect ownership, Controller
acquisition/return, saved work and lifecycle cancellation are affected contracts.
Unchanged SourceUse and earlier native owners retain applicable evidence.
The selected set covers this first join; it does not establish the whole D3 domain.

| Contract | Retained first-join evidence | Boundary |
|---|---|---|
| Finite materials and source projections | `_scratch/d3-material-categories-work-02/receipt.json`: PASS31 native +19 source checks /13 controls. | Native item factory, inventory and serialization; controlled acquired-source/world receivers. |
| Maintained material planning and target retry | `_scratch/d3-material-work-01/planning-target-reviewed.log`: PASS50 cases /9 controls. | Actual Planner in installed Kahlua; native work and source events have controlled ports. |
| Native pane preparation and saved recovery | `_scratch/d3-pane-recovery-work-02/receipt.json`: PASS54 cases /10 controls. | Installed transfer, queue, repair and serialization; controlled actor/map/dispatch/network receivers. |
| Native boarding, saved recovery and preparation cleanup | `_scratch/d3-native-boarding-proof-15/receipt.json`: PASS64 cases /11 controls. | Installed equipment, transfer, queue, barricade and serialization; controlled physical receivers. |
| Controller acquisition, return, adoption and retry | `_scratch/d3-construction-controller-proof-05/receipt.json`: PASS25 cases /13 controls. | Actual Controller/Planner and serialized WindowRepair recovery; locomotion, SourceUse transfer and Build ACK ports controlled. |
| Existing window ownership/learning regression | `_scratch/d3-material-work-01/window-proof-final-04/receipt.json`: PASS152 cases /43 controls, exit0. | Installed native action/queue and isolated native receivers; controlled map/body/dispatch/network. Earlier failures remain retained. |
| SourceUse | `_scratch/d3-material-work-01/source-use.log`: PASS41 transfer +58 lifecycle/capture +16 native-holder checks with detecting controls. | Existing exact acquisition owners; no loaded game. |
| Provisioning and delivery | `_scratch/d3-material-work-01/provisioning-final-01.log`: PASS54 provisioning +90 knowledge +51 integration cases; named controls detect their faults. | Installed Kahlua; native transfer and destination contracts keep their stated fixture boundaries. |
| Save compatibility | `_scratch/d3-material-work-01/save-compat.log`: zero unexplained persisted-field losses. | Static persistence comparison; native owner roundtrips are recorded above. |
| Java build | Full package build exit0; `_scratch/d3-build-validation-01/production-java-receipt.json` independently matches18 changed classes. | Both817-class JARs SHA256 `e6fd32833b18dddc90041ec926277c54ab98db47f154f8fd7605dae7a74d25ff`. |
| Standing check and CI registration | `_scratch/d3-material-work-01/ci-controls.log`, `gate-reach.log` and `d3-ci-plan.json`: PASS. | Four actual D3 invocations use fresh proof outputs; affected owners select their relevant instruments and absent installed input remains reported. |
| Delivered catalogue and version | `_scratch/d3-material-work-01/version-replay.log`: PASS165 delivered units /3.8.1.0-pre-alpha. | The open D3 record is linked outside the delivered index and receives no credit. |

The delivery fixture lacked the native player's required `getModData` port before
this join. A retained byte-identical baseline failure establishes that boundary;
the corrected fixture now includes a detecting control for its absence. It does
not represent a production provisioning repair. Root preserves all earlier
failed and incomplete runs alongside their successful replacements.

The window regression's three source mutation anchors were updated for the new
preparation, fallback and recovery shapes. Deliberately suppressed learning can
leave cognition absent, so its serialization fixture now preserves false
motivating verdicts through that state instead of crashing on a nil table.
The final normal run and all 43 controls pass. Controller proof05's executed
source capsules remain byte-identical across the unrelated mutation-tool edits;
the independent validation report records that evidence reuse.

Coherence review found and prompted corrections for lost-runtime admissions,
nail-box source selection, unavailable-target monopolization, boarding recovery
after a clock-rewind interruption and native preparation cleanup. The final
read-only review verifies all five fixes with no remaining Critical, High or
Medium finding established within this join. The 64-case boarding proof includes
exact native cleanup and preservation of queued successors, replacement queues
and changed action items. Independent final syntax, proof-pin and preservation
assessment is recorded under `_scratch/d3-build-validation-02/`. No blanket full-suite
result, loaded gameplay, installation, rendered acceptance or remote publication
is claimed. Scoped passing evidence is reused across the local continuation
commit through `git commit --no-verify`, as GOVERNANCE permits; that command is
not a passing full-suite gate result.

## Continuing D3 work

Native construction, handcraft, general repair and utilities still need their
actual source-owned procedures and consumer joins. The established continuation
anchors remain `ISBuildIsoEntity`/`ISBuildAction`, `ISHandcraftAction`, `ISFixAction`,
`ISPlumbItem` and `ISFixGenerator`. Pane making is crafting work alongside pane
installation; windows and boarding alone do not close the domain. Continue the
same acquired need/material/preparation/native effect/persistence chain across
these mechanisms, preserving actual recipes, skills, physical reach and Standing.
D4 whole food/preservation, D5 comprehensive animal care and D6 assessed learning
follow D3 in FIFO. The normal save, character and scenario flow continues.

## D3.2 delivered continuation

The CLOSED saw-maintenance child joins exact private file acquisition and native held-tool repair to the retained construction purpose. Its final80-case/17-control native proof and integrated regressions are linked from the child. The parent retains every unfinished construction, crafting, repair and utility obligation.

## D3.3 portable maintenance continuation

[D3.3](D3.3-20261010-0622Z-2222PST-portable-tool-maintenance.md) is CLOSED for portable saw repair and blade sharpening, exact private file/whetstone means, ordinary kit-tending purposes, measured native benefits/damage and saved continuity. Its scope, owners, contracts and required proof were recorded before implementation. D3.2 reached origin/main through self-merged [PR143](https://github.com/ellyj3rain/sao/pull/143), commit `78100a44524a7ea9bc57a81b7b076532ad4987b9`. The full D3 parent remains OPEN.

## D3.4 plumbing continuation

[D3.4](D3.4-20261010-0701Z-2301PST-plumbing-to-usable-water.md) is OPEN for personally observed fixture readiness, exact private pipe-wrench means, native connection and actual usable water under the same hydration purpose. Its reason, scope, owners, contracts, dependencies and required closure evidence are recorded before implementation. D3.3 reached origin/main through self-merged [PR144](https://github.com/ellyj3rain/sao/pull/144), commit `10efdee705f797cadaeed9197c8dcd243d23c49c`. The full D3 parent remains OPEN.

## D3.4 closure - 2026-10-10 07:30 UTC / 23:30 PST

[D3.4-20261010-0701Z-2301PST-plumbing-to-usable-water.md](D3.4-20261010-0701Z-2301PST-plumbing-to-usable-water.md) is CLOSED: exact private pipe-wrench acquisition, installed connection, handled-source refresh and actual clean held-water gain continue the same hydration purpose. Its evidence separates native geometry/fluid ports from controlled installed lifecycle receivers, with ordinary arbitration and saved continuity. The new native utility contract receives one minor credit. This parent keeps its complete remaining scope and stays OPEN.

## D3.5 rain-collector continuation

[D3.5](D3.5-20261010-0813Z-0113PST-rain-collector-construction.md) is OPEN for native rain-collector construction and personally observed placement feeding the existing plumbing and usable-water purpose. Its reason, complete four-variant native scope, owners, interfaces, dependencies and required closure evidence are recorded before implementation. D3.4 reached origin/main through self-merged [PR145](https://github.com/ellyj3rain/sao/pull/145), commit `3120fae3e9d71f3f5664bad48cfa0e409a3e41d7`. The full D3 parent remains OPEN.

## D3.5 closure - 2026-10-10 09:07 UTC / 02:07 PST

[D3.5](D3.5-20261010-0813Z-0113PST-rain-collector-construction.md) is CLOSED: exact recipe-derived materials, personally observed placement and native rain-collector construction feed the original plumbing and usable-water purpose. Its record links the current native construction, site/rain/fluid, private planning, cognition and saved-continuity evidence. The world-entity construction boundary receives one minor credit. This parent retains all general entity placement, other recipes/pane integration, general fixing, generator and native-server obligations and remains OPEN.

## D3.6 generator continuation

[D3.6](D3.6-20261010-0947Z-0247PST-generator-to-usable-power.md) is OPEN for native generator repair, fueling, connection and actual consumer power under a retained private utility purpose. Its full four-variant scope, owners, interfaces, dependencies and required evidence precede implementation. D3.5 reached origin/main through self-merged [PR146](https://github.com/ellyj3rain/sao/pull/146), commit `5b3eb409f654e82f46d82940b968366ecaa1f74d`. This parent retains its complete module and remains OPEN. The operator's version/batch/PR mapping follow-up is recorded separately in SESSION_STATE.

## D3.6 closure - 2026-10-10 10:47 UTC / 03:47 PST

[D3.6-20261010-0947Z-0247PST-generator-to-usable-power.md](D3.6-20261010-0947Z-0247PST-generator-to-usable-power.md) is CLOSED with native generator repair/fuelling/connection/activation, exact knowledge and material acquisition, return to reached consumer power and resumption of the retained original meal. Its linked proofs and first-pass corrections establish the child. The complete D3 parent remains OPEN for its remaining installed domain and integration obligations. The child receives one owning minor credit; the parent receives no repeated credit. The version/publication mapping and canonical Neo/GZDS carry remain recorded separately.
