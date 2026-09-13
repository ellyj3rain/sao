# C105 - The recognition bridge

| Field | Record |
| --- | --- |
| Batch | `C105` |
| Date | 2026-09-12 |
| Name | The recognition bridge |
| Status | Closed append-only batch - implementation and records |
| Threads | [`T-008`](Batches/THREADS.md#t-008), [`T-030`](Batches/THREADS.md#t-030) |

## Record

The graph's write side had zero callers: `SAO_Organization`,
`SAO_Settlement`, `SAO_Material`, and `SAO_Communication` were built
in the `[C104]` era and nothing in the county ever wrote to them, so
no organization, office, settlement, or player claim could ever come
to exist in a running game. The emergence chain stopped at "pattern".

This batch closes that gap with a recording bridge, not an authoring
pass. `SAO_Recognition.lua` is the whole write side, and one law
governs it: nothing there decides anything. Every function is called
AFTER a real event in the county's own machinery and records what
already happened:

- A house's first SETTLED election founds the organization and
  appoints the chair (re-election of the same leader records
  nothing; a changed settle is succession). The election roster is
  the real membership: the dead, exiled, and schism-leavers leave
  the record when the roster says so.
- The chair offer is the house's recognition, filed the moment the
  offer is made; accepting answers the claim; declining answers it
  the other way; unseating empties the office.
- The join petition is a claim; the leader's acceptance or refusal
  answers it.
- An order verdict from the chair - complies, reluctant, refuses -
  is the deference fact, recorded as decision and response.
- Real provisioning on claimed ground - a hearth actually burning,
  water actually counted, shelves actually counted - records the
  settlement.
- A pact formed records external relations on both houses; a
  schism records the leavers' exit on the house that broke.
- A promise asked is a claim ([B3]). A tell that moved someone is
  a message, delivered at the hearing and pruned after - the wire
  does not grow forever. A real item shelved on held ground is
  the material fact, counted under the house's store.

Three read-side violations fell with the same law:
`PlayerInteraction.response()` no longer files a new claim on every
read; `recognizedBy()` no longer counts an empty recognizers table
(or the claimant's own self-recognition) as recognition; and
`Organization.playerAction("support")` no longer self-recognizes - a
claim is recognized only when somebody else stands on it
(ORGANIZATION.md: "Do not treat a self-declared claim as a
recognized office").

The eight graph sandbox options (Branching, Pressure, Labor,
Organization, Settlement, PlayerInteraction, Material,
Communication) now carry their names and tooltips on the sandbox
screen (Border 16).

## What changed

- `SAO_Recognition.lua` is new - the recording bridge, sandbox-gated
  per surface.
- `SAO_Standing.lua` hooks the bridge into the real events: election
  settle and both dissolve paths, chair offer/accept/unseat/decline,
  the three provisioning setters, pact formation, promise asking,
  the two tells, and schism.
- `SAO_Controller.lua` and `SAO_Harness.lua` record the order verdict
  where orders actually land (`onTheirWord`, `onYourWord`).
- `SAO_Harness.lua` records the join petition's answer.
- `SAO_Needs.lua` records the real item movement at
  `depositSpareFood`.
- `SAO_Communication.lua` prunes delivered messages.
- `SAO_Organization.lua` drops support's self-recognition.
- `SAO_PlayerInteraction.lua` makes `response()` a read and
  `recognizedBy()` honest.
- `Translate/EN/Sandbox.json` names the eight graph options.
- `SESSION_STATE.md` advances to this batch.
- `BATCH_LOG.md` gains the `[C105]` row.

## Verification

Deferred by the operator's standing order for this pass: no gate,
build, deploy, package, test, or git until the planned feature work
is finished; all of it runs once, at the end. Version stamps restamp
in that same end pass.