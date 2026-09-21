# C69 - Recipient appraisal after testimony

| Field | Record |
|---|---|
| Batch | `C69` |
| Date | 2026-09-21 |
| Name | Recipient appraisal after testimony |
| Status | Closed; complete repository gate enforced by the publishing commit. |
| Threads | [`T-003`](THREADS.md#t-003), [`T-004`](THREADS.md#t-004), [`T-008`](THREADS.md#t-008), [`T-009`](THREADS.md#t-009), [`T-030`](THREADS.md#t-030) |

## Measured contract

C67 correctly refused to copy a witness's feeling into testimony, but that left
a later listener unable to respond even when the listener personally knew their
household had asked for food and accepted a report that somebody delivered it.
Copying the teller's gratitude would erase disagreement. Reconstructing the
listener's historical hunger or the giver's intent would invent facts. Writing
trust or debt from the report would turn private interpretation into an
automatic social outcome.

The [producer matrix](../artifacts/audits/20260921-0909Z-0209PST-recipient-appraisal/PLAN.md)
therefore requires the listener's own evidence at appraisal time: current
membership in the requesting household, their acquired still-active food
request, an explicit private claim covering the event location, accepted
testimony of a completed store act, and their current relationships and
disposition. The act, request and claim remain separate acquisitions.

## Implemented behavior

Aid requests now carry an explicit food category. The only pre-C69 request
producer was `callForBread`, so category-less saved requests migrate as food;
other categories are refused rather than inferred. After testimony, return
reporting or later place acquisition, Perception joins the listener's current
household to that household's request and claim. Only a remembered told store
episode after the request and inside the claimed ground is eligible.

Disposition applies the established testimony ladder: 0.4 of firsthand weight,
scaled by the existing credibility floor. Compassion and the listener's current
relationship with the actor can therefore produce gratitude, indifference or
resentment. The resulting appraisal freezes event, request, claim, immediate
teller, original requester, acquisition times, relationship trust, credibility
and compassion on that listener's private episode. Later relationship,
personality or membership changes do not rewrite it.

Retelling copies the performed act without copying the prior appraisal. A later
listener must independently possess qualifying context and uses the new teller's
credibility. The existing remembered-reciprocity reader can bend that listener's
own charity choice toward or away from the actor. No trust, debt, settlement or
public-recognition record is written.

## Verification

Border 180 executes 90 production delivery-knowledge cases in the installed
Kahlua VM. The C69 cases cover independent appraisal, complete private
provenance, signed disagreement, either evidence arrival order, current
membership, explicit ground and event containment, request/event order,
still-active requests, frozen results, malformed/future saved data, retelling,
testimony weight, absence of social-ledger writes and an actual change in the
existing charity decision. Twenty-one named mutations include forced membership,
snapped event location, backdated request, full testimony weight and copied
appraisal state.

The 51 delivery-integration cases retain the real `callForBread` request path and
its failure semantics. Lua compilation, sort bounds, provisioning and the whole
repository gate remain closure requirements. The [evidence record](../artifacts/audits/20260921-0909Z-0209PST-recipient-appraisal/README.md)
separates these controlled mechanics from loaded-save play.

## Limits and continuation

C69 responds to reported household food assistance. It does not derive shelf
counts, reconstruct historical body need, identify giver intent, create debt or
generalize to every favor. Complete private inventory, open-wound treatment,
dormant sleep/wake, actual radio reception and the remaining R9 producers retain
their existing owners. Main-menu startup verifies loading only; it is not a
loaded-save or play-acceptance receipt.
