# C107 - What a settled house does with its ground

| Field | Record |
| --- | --- |
| Batch | `C107` |
| Date | 2026-09-12 |
| Name | What a settled house does with its ground |
| Status | Closed append-only batch - implementation and records |
| Threads | [`T-003`](Batches/THREADS.md#t-003), [`T-008`](Batches/THREADS.md#t-008) |

## Record

`[C76]` settled the unwatched house on the ground its members keep
returning to. But a settled house still said nothing about its own
shelves: `setHearth`, `setLarder` and `setWaterStore` had call sites in
`SAO_Controller` alone, and the controller reads state a body produces -
`countEdibleNearby`, `findHearth`, `countStoredWaterNearby` all need a
materialised survivor to stand a round on. A dormant house had no body
and so no words. Every consumer of those words - the flight form, the
lean-house ladder, the forager need-pull, the abandon council, the
bread ask and the charity that answers it, the winter warming - was
inert in the half of the county nearly every house lives in, and a
dormant house could starve on spent ground forever without the county's
own machinery ever saying so.

The dormant half cannot count items and this batch does not pretend it
can. What a dormant house has is what its people actually DID:
`lastFoodDay` and `lastWaterDay` are stamped only when a walk really
arrived at a place that really still offered ([B37]/[C25] law - the
same stamps attrition already trusts), and the seat's own ledger -
`offersNow`, mains-aware and spent-aware, read exactly the way the
dormant day reads it. The words derive from those, against the
county's own patience constants (`THIRST_PATIENCE`, `HUNGER_PATIENCE`),
and no number is invented:

- The larder is **lean** when nobody in the house has reached food
  inside the county's food patience - a house whose every member is
  failing, not one unlucky member. It is **full** when every living
  member is fed AND the seat itself still offers food - surplus you
  could answer a stranger's hunger from, not a run of luck elsewhere.
  Between is **fair**.
- The water word follows the same shape at thirst's own, shorter
  patience: **dry**, **fair**, **full**.
- The hearth claim is the honest dark one: **no** member of this house
  has a body, so no fire of the house is burning - true by
  construction, and the live round overwrites the claim the moment a
  body lights one.

A house with any materialised member is skipped whole: two writers
with two strengths, and the live one counts real shelves. Counts are
never faked - `setLarder`/`setWaterStore` are called with nil counts,
so the setter-level `[C105]` hooks correctly stay silent; instead
`Recognition.onProvisioned` is called explicitly, once per house, only
when the house really is living on its ground (fed > 0 and watered >
0) - a settlement entering the `[C105]` graph by derivation rather
than by a smuggled count. A lean house calls for bread exactly as a
live one does; `callForBread`'s own 72-hour window paces the asking,
and no water ask is invented because none exists live.

The pass runs a full sweep per call with no budget, and that is a
considered departure from `[B51]`: the settle walk is a per-house
`members x knownPlaces` march and needs its one-house-a-pass budget,
but this round is a roster read plus one cached place lookup per
house - the same O(dormant people) sweep `dormantLife` already pays
each tick. A budget here would leave words stale past their 48-hour
honesty window ([A28]) during the years pass, which runs once per
simulated day. A word that goes stale between rounds is the county
saying nobody read those shelves lately, which is true.

Call sites follow the settle round in both halves: `populationTick`'s
`runSub("provision", dormantProvision)` immediately after settle, and
`oneYearsDay`'s `pcall(dormantProvision)` immediately after
`pcall(dormantSettle)` - after the day's walks stamp their reachings,
before the encounters and attrition that read the words.

## What changed

- `SAO_Population.lua` - `dormantProvision`, a [C107] round deriving
  the hearth/larder/water words for fully dormant settled houses from
  real reachings, the seat's own `offersNow` ledger, and the county's
  patience constants; called from `populationTick` (new "provision"
  sub) and `oneYearsDay`. Lean transitions log once per change, not
  per tick.
- `ROADMAP.md` - queue item 1's remainder marked paid at `[C107]`,
  with the derivation law recorded where the queue stated the debt.
- `SESSION_STATE.md` advances to this batch.
- `BATCH_LOG.md` gains the `[C107]` row; `THREADS.md` T-003 and T-008
  gain `C107`.

## Honest limits

- No item counts exist in the dormant half and none are manufactured:
  the claims are word-only. [C105]'s "actually counted" provisioning
  stays the live round's.
- The dormant house asks for bread but not water - the live county has
  no water-ask seam, and none was invented here.
- A dormant house never shows a burning hearth. That is a fact about
  bodies, not an approximation: the winter warming (`risk x 0.8`) is
  reachable in the dormant half only if some future batch gives a
  dormant house a real fire, which is a design question, not owed.
- Recognition fires only when fed > 0 and watered > 0 - a house
  failing at water is a settlement on its ground still, but this batch
  does not claim it is living well.

## Verification

Deferred by the operator's standing order for this pass: no gate,
build, deploy, package, test, or git until the planned feature work
is finished; all of it runs once, at the end. Version stamps restamp
in that same end pass.