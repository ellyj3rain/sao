# C108 - The place ontology

| Field | Record |
| --- | --- |
| Batch | `C108` |
| Date | 2026-09-12 |
| Name | The place ontology |
| Status | Closed append-only batch - implementation and records |
| Threads | [`T-003`](Batches/THREADS.md#t-003), [`T-004`](Batches/THREADS.md#t-004), [`T-008`](Batches/THREADS.md#t-008) |

## Record

DR-006 S4, the operator's named error: `s.groupClaims[groupName]` is
one rectangle per group, so a group holding a base plus stash houses
around it is unrepresentable, and so is a group deciding to leave.
The ratified direction (ROADMAP item 2) was that a place IS derived
from use, never declared - and that the batch is smaller than it
looks: generalise `[C76]`'s scorer from picking one to ranking all,
keep `groupClaimOf` and `allGroupClaims` answering the seat so the
twenty-nine read sites do not move, and read the ranked set where
holding several changes the answer - trespass, the feud keep-out, and
where a venture brings things back to.

That is what landed, and nothing more:

- **`Perception.returnsOf(members)`** - the generalised scorer. The
  same facts `[C76]` walked (every arrival `learnBuilding` has
  recorded: bounds, offers, visits, `at`), the same score (visits
  summed across members times distinct members, water doubled), now
  ranked best-first instead of picked from, with recency breaking
  ties: of two places equally returned to, the one somebody still
  goes to ranks above the one they have stopped going to. Nothing is
  stored, so nothing expires - a place stops being the group's when
  its people stop going, the same fact that made it theirs. The
  settling pass now reads the top of this ranking, so the seat and
  the set are one law, not two ([C25]).
- **`Standing.placesOf(groupName)` / `Standing.onGroundOf(g, x, y,
  margin)`** - the group-shaped readers. `placesOf` is cached against
  `Perception.beliefVersion` (a counter bumped by every belief
  write, drop, and save-load swap) and against the member roster
  itself, so a derivation is never served after the facts or the
  membership moved under it - `[C77]`'s cost law without a cache
  that lies. `onGroundOf` answers "is this point inside group G's
  ground" - the settled seat first (a scouted settlement `[B52]` is
  chosen off the loaded ground, not derived from visits), then every
  ranked place, each grown by the caller's margin. One definition of
  containment, so the two halves' refusals cannot drift.
- **The three readers where holding several changes the answer**:
  the settling refusals (`barredGround` in the dormant pass, the
  scout's claim-over check in the live pass) now refuse over ANY of
  another company's places, not only their seat - a house does not
  settle over another's stash while honouring their base; the feud
  keep-out (`[A20]`) falls around every place the enemy holds, in
  both halves; and a pact delivery is kept standing on ANY of the
  ally's ground - a stash or a second house answers the pact as
  well as their seat does. The roam still aims at the ally's seat,
  because "where is the group" is the seat's own question and the
  twenty-nine sites that ask it do not move.

The twenty-nine seat-reading sites are untouched. `groupClaimOf`
answers where the group IS; `placesOf` answers where it HOLDS.

## What changed

- `SAO_Perception.lua` - `beliefVersion` (bumped in `learnBuilding`,
  `forget`, and the save-store bind) and `returnsOf(members)`, the
  generalised `[C76]` scorer, ranked best-first with recency
  tie-breaks.
- `SAO_Standing.lua` - `placesOf(groupName)` (roster- and
  version-keyed cache over `returnsOf`) and `onGroundOf(groupName,
  x, y, margin)`, the one containment definition.
- `SAO_Population.lua` - `barredGround` reads `onGroundOf` for both
  clauses (another company's ground, a feud's shadow);
  `dormantSettle` reads the top of `returnsOf` instead of its own
  inline pick - the same law from one place.
- `SAO_Controller.lua` - the scout's claim-over refusal and feud
  shadow read `onGroundOf`; the pact delivery's `inAlly` check reads
  it too.
- `ROADMAP.md` - queue item 2 marked paid at `[C108]`.
- `SESSION_STATE.md` advances to this batch.
- `BATCH_LOG.md` gains the `[C108]` row; `THREADS.md` T-003, T-004
  and T-008 gain `C108`.

## Honest limits

- The seat does not move. A house that fails releases its claim
  through the existing abandon council and re-settles where its
  people now go; a healthy house deliberately relocating its seat has
  no seam, and none was invented here - the ratified batch named
  three readers, not a seat-move writer. The derived set already
  answers where they actually hold.
- Belief-gated trespass stays belief-gated: a stranger respects
  ground they KNOW is held, and the belief store records observed
  seat claims (`learnGroundNear`), not another house's private
  haunts. You cannot knowingly trespass on a stash you do not know
  is anybody's - which is honest, not a gap.
- Containment reads the full ranked set - every building living
  members have ever reached, however few times. The ratified design
  says containment is "any of them", and no threshold was invented
  to thin it; a place the house has all but abandoned stays theirs
  until other places outrank it, which the recency tie-break
  accelerates but does not force.
- Cost: the settle pass's all-barred worst case walks every group's
  ranked places per candidate. The cache bounds it to rect tests per
  candidate, and the pass settles one house per tick ([B51]), but a
  county where every candidate is claimed will pay it. Named here so
  it is not discovered in a profile.

## Verification

Deferred by the operator's standing order for this pass: no gate,
build, deploy, package, test, or git until the planned feature work
is finished; all of it runs once, at the end. Version stamps restamp
in that same end pass.