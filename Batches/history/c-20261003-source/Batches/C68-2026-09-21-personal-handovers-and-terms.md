# C68 - Personal handovers and terms

| Field | Record |
|---|---|
| Batch | `C68` |
| Date | 2026-09-21 |
| Name | Personal handovers and terms |
| Status | Closed; complete repository gate enforced by the publishing commit. |
| Threads | [`T-003`](THREADS.md#t-003), [`T-004`](THREADS.md#t-004), [`T-008`](THREADS.md#t-008), [`T-030`](THREADS.md#t-030) |

## Measured contract

Legacy person-to-person transfers treated a successful queue call as the
handover. Exchange immediately changed trust, debt and settlement; care and
yield paths immediately granted their own consequences. A dropped, interrupted
or invalid native action could therefore leave the item with its original holder
while the relationship recorded delivery. The two barter legs also acquired
debt before there was evidence of bilateral agreement or a completed first leg.

The [producer matrix](../artifacts/audits/20260921-0714Z-0014PST-personal-handovers/PLAN.md)
separates request, queue admission, accepted terms, native holder proof and
consequences. DR-044 remains the governing rule: a gift creates no collectible
balance; trade debt requires accepted terms and one completed leg.

## Implemented behavior

`SAO_Handover` owns personal transfer records. ModData retains only scalar actor,
recipient, item, kind, term, state and consequence data. Current bodies,
inventories, items and actions remain in a runtime map. The custom vanilla
transfer subclass rechecks body identity, same-floor six-tile access, exact
source holder and the pending record immediately before mutation. Completion is
published only when the item is in the recipient inventory and absent from the
source inventory.

Food, drink, smoke, bonded food, reading, disinfectant, an unused bandage,
fear-driven yielding and debt settlement now use this owner. Queue refusal,
action interruption, holder conflict and a pending record with no reload-time
runtime witness change no trust, debt, settlement, voice, aid timestamp or XP.
The exact pending item remains reserved, so a reload-unknown operation cannot be
queued a second time. Terminal records and terms are bounded at 512 and 256;
active unknown work is never evicted to make a claim disappear.
The existing death funnel releases proposals and pending actions involving the
dead participant and drops their live bodies, inventories, items and actions.
Completed handovers remain historical facts.

Barter creates a proposal first. Each person must independently admit their
native transfer action before the proposal becomes accepted. A failed second
admission cancels both queued work and creates no debt. After acceptance, two
completed legs apply the trade's trust and voice once. One completed leg plus a
terminal interrupted/conflicted opposite leg creates one debt from the recipient
of the completed item to its giver. Reconciliation is idempotent.

## Verification

Border 182 executes the shipped owner in the installed Kahlua VM with controlled
inventories and the same custom timed-action shape. It covers queue-only state,
native completion, interruption, holder conflict, proposal cancellation,
accepted partial and complete exchanges, repeat reconciliation, scalar durable
records, reload-unknown state, duplicate reservation, distinct actors and
future-schema refusal, and death-time release of live handles. Its production
mutation applies social credit at queue time; the border flips the named
`queued_without_effect` verdict.

Existing exchange, source-use, provisioning-result and decision-capture borders
remain in force. The [evidence record](../artifacts/audits/20260921-0714Z-0014PST-personal-handovers/README.md)
holds focused, full-gate, publication, installation and startup receipts.

## Limits and continuation

An open-wound `ISApplyBandage` treatment is a different native action. C68 routes
only its no-open-wound item gift through Handover; the treatment result, care
skill and patient response still need a treatment-specific completion owner.
Pending records whose runtime action is absent after reload withhold credit and
remain reserved because no supported item-resolution proof exists yet. C68 does
not infer completion from elapsed time or queue absence.

Recipient appraisal of testimony, dormant sleep/wake, actual radio reception,
complete private inventory coverage and the remaining life-simulation producers
retain their ROADMAP owners. Mechanical closure and main-menu startup do not
establish loaded-save behavior or play acceptance.
