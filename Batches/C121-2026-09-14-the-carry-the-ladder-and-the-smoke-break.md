# C121 - The carry, the ladder, and the smoke break

| Field | Record |
| --- | --- |
| Batch | `C121` |
| Date | 2026-09-14 |
| Name | The carry, the ladder, and the smoke break |
| Status | Closed append-only batch - drugs in totality, built |
| Threads | [`T-002`](THREADS.md#t-002), [`T-008`](THREADS.md#t-008) |

## Record

The totality order named drugs as the batch after the age
attachments, and the operator ruled real smoking onto it as an
option and nothing more - so the smoke break is a dial, on by
default, moving nobody's habit. The prior-art law was paid before a
line was written, and this sweep found the record itself wrong in
the way the record law names: C33 held N and C's Narcotics as
"source not public" and "no code read", and the Workshop folder
ships the mod's Lua UNCOMPILED - [C121] read it whole. The
correction stands dated beside the original in CREDITS.md; the
original line stands too, as what was believed.

What the sweep read and what came back, rendered through the
county's own machinery:

- **The carry.** Where N and C's Narcotics is loaded, the county's
  own bodies run their machinery. NEW `SAO_Drugs.lua` drives their
  own globals on the county's shells - their seven ten-minute
  dependency steps, their seven per-minute effect packets and their
  pain removal - on their own clock shape, the exact cadence their
  OnTick driver keeps for the player: minutes-stamp deltas, one
  pass per ten in-game minutes, one per minute. No body is driven
  twice, because their driver finds only the four player slots
  (`getOnlinePlayers`/`getSpecificPlayer` 0..3, the [B46] law) and
  the county's shells never appear in it, and their withdrawal
  fires only on their own trait. Where their globals are absent
  the calls are nothing - a named global that is not there reads
  nil, and the check is on the call - so a county without the mod
  runs exactly as C33 built it.
- **The yield.** Their machinery, taken over by their own trait,
  would stack a second withdrawal on the county's schedule - so the
  county's schedule yields family by family the moment the trait
  is observed on the body. `SAO_Drugs` observes the traits on the
  ten-minute pass and stamps the record; `SAO_Habits` reads the
  stamp in its withdrawal drift and stands down for that family. A
  use stamped without the trait does NOT yield: a person their
  machinery has not taken over still has only the county's
  schedule. `Hb.wantsFix` deliberately ignores the yield - a body
  whose withdrawal the trait carries still wants the dose;
  seeking relief is not stacking loads.
- **Methadone.** Their methadone level holds their opioid clock
  still, and the county's opioid clock yields to the same freeze:
  the level is read on the observation pass, and `SAO_Habits`'
  own `freezeUse`/`resumeUse` pair - built per-family for this
  batch - stops and starts the county's clean-clock drift.
- **The ladder.** The Alcoholic's late withdrawal, carried in full
  at the figures the source read holds: the sickness builds at
  their 0.001 per ten-minute pass on their one-in-(5-phase) draw,
  capped by their per-phase column (0.3, 0.5, 0.7, 1.0); past
  their 0.6 poison line the body takes their hit range (floor
  0.5x25 to 25, capped at 95) onto the engine's own food-sickness
  stat, with the running total kept on the record; past their 0.9
  death line the drink itself can kill, on their one-in-a-hundred -
  and their death is the county's death: the identity is marked
  with the cause FIRST (`markDead` is idempotent, so the
  controller funnel's later marking no-ops and "the drink" stands),
  and the body dies through their own call. The relief is their
  column too, reached through the `ISDrinkFluidAction` wrap:
  stress and unhappiness halved then eased a tenth, fatigue halved,
  pain eased a tenth, the poison worked out at half the running
  total, the intoxication held at their tolerance-scaled figure,
  the sickness dying on the spot. Their tolerance builds at their
  eight drinks a day, a hundredth at a time, capped at their tenth.
  Not carried, named in CREDITS.md: their poison scaling by player
  trait, their `alcoholicStress` channel, their headaches as
  BodyPart pain ([C33]'s shakes are ours and ours in size).
- **The verbs.** The controller's decision pass gains the dose
  verb beside the drink verb: a person in withdrawal who carries
  their family's drug takes it (the `ISEatFoodAction.perform` wrap
  stamps the use on the record, and the eat is the engine's own),
  and one who does not seeks it where the county believes a supply
  might be - the claimed-place law holds, and no dose is ever
  taken from a place somebody has claimed. The seek rides the
  believed-map the county already walks, throttled at its own
  pace, and never authorizes a trip a non-user would not take:
  the drive is the withdrawal's, and withdrawal is a fact about
  the person, not a schedule's opinion.
- **The smoke break.** A smoker who is not in withdrawal takes a
  smoke break now and then - a few a day, at their own hashed pace,
  a real cigarette from their own pocket through the engine's own
  eat, if they carry one. The dial `SurvivorAwareness.RealSmoking`
  governs only the visible act: OFF is exactly the county C33
  built, where a smoker lights one only when the craving bites.
  Who smokes is a fact about the person either way; the dial moves
  nobody's habit.

The gate refused the batch's first pass and every finding was
fixed at its root. The first was real and would have been silent:
the carry's dynamic global lookup reached for `_G`, and the
engine's interpreter is Kahlua, which registers no `_G` at all
(read in the jar - `rawget`, `getfenv`, `setfenv` in its BaseLib
and no more), so the index would have thrown inside the per-body
pcall and killed the whole ten-minute pass - the ladder included -
  without one line of output. The carry now names their fifteen
globals directly, checked as functions, called, never written, and
the globals census holds every one of them argued as a neighbour
read. The smoke dial was read live-only and moved to the needs
module that owns the body's acts, its ownership declared to the
option-reach border with the reason that shape exists to carry. The
tooltip copy was ratified with the batch. And Border 13 was taught
the loaded-neighbour vocabulary: their `Drugs` display category is
a word no vanilla item declares, so the literal is verified against
the neighbour's own shipped scripts, named, and faults if the mod
is absent and the want unsatisfiable - the recognised-never-required
posture made checkable instead of argued.

## What changed

- `mod/42.20/media/lua/client/SAO_Drugs.lua` - NEW: the carry
  (their fifteen globals on the county's bodies, their clock
  shape), the trait observation the yield reads, the methadone
  freeze, the drinker's ladder (sickness, poison, death, relief,
  tolerance), and the OnTick driver. Offline by construction.
- `mod/42.20/media/lua/shared/SAO_Habits.lua` - per-family
  clean-day clocks with `used()`, `freezeUse`/`resumeUse`, the
  drift yield that stands down on the trait stamp, and
  `Hb.wantsFix` (the strongest withdrawal a body wants relief
  from, the drinker excluded - the ladder owns the drink).
- `mod/42.20/media/lua/client/SAO_Needs.lua` - `useCarriedDrug`
  and `findDrugSource` (the family read and the claimed-place
  law), the `ISDrinkFluidAction` wrap reaching
  `SAO.Drugs.onDrink`, the `ISEatFoodAction.perform` wrap
  stamping `SAO.Habits.used`, and `N.casualSmokingOn` (the dial
  the smoke break reads).
- `mod/42.20/media/lua/client/SAO_Controller.lua` - the dose verb
  (take what is carried, else seek where believed, never from a
  claimed place) and the casual smoke beat on the decision pass.
- `java/src/com/sao/engine/SAONeeds.java` -
  `drugFamilyOf`/`carriedDrugFor`/`findDrugSourceNear`/`firstDrugIn`
  (the family read through their own tag vocabulary and, for the
  weed smokables that carry no family tag, vanilla's `SMOKABLE`
  plus their own `Drugs` display category);
  `java/src/com/sao/engine/SAOBridge.java` - the exposures. The
  jar rebuilt from source and shipped after the stamp.
- `mod/42.20/media/sandbox-options.txt` and
  `mod/42.20/media/lua/shared/Translate/EN/Sandbox.json` - the
  `RealSmoking` dial, Border 16's shape, copy ratified.
- `CREDITS.md` - both mods' sections: the dated correction of
  C33's wrong record beside the standing original, the Alcoholic
  ladder carried in full with the not-carried named, the N&C
  source-read carry and its own not-carried (their narcan - a
  knowledge rule - and their joint rolling).
- The gate's own borders: `tools/globals_census_test.py` taught the
  fifteen neighbour names; `tools/option_reach_test.py` the dial's
  owner; `tools/copy_ratified_test.py` the two new strings;
  `tools/engine_literals.py` the loaded-neighbour category
  vocabulary.
- `tools/version_replay.py` - the `C121` unit row; `--write`
  stamps the coordinate.
- `BATCH_LOG.md`, `SESSION_STATE.md`, `ROADMAP.md` - the pointers,
  and the neuroinflammation knot recorded as `[C125]`'s slot in
  the whole list - a ratified commitment, not a note.

## Honest limits

- The carry is exactly as deep as their own machinery: their pass
  scaling exists to fit their magnitudes to a day length, and the
  county's clock is its own ([C112]) - their steps run once per
  pass, unrescaled, the same pass their own driver keeps. Their
  psychedelics and steroids are usable and never sought: the
  county's 1993 figures name no dependency on them, and a
  LOW-confidence claim never teaches.
- The trait observation is the yield's whole truth: if their
  machinery gains a trait outside `NnCReg`, this file does not
  know it, and no family yields for it. The five families named
  are the five their registry holds for the county's families.
- The ladder's poison lands on the engine's own food-sickness
  stat - a body that is also food-poisoned carries both on one
  gauge, the way their own mod's drinkers do.
- No play receipt, as ever: nobody has watched a county body take
  a benzo and calm, a user seek a bag from a believed supply, a
  smoker on a porch at their own pace, or a drinker climb the
  ladder and live or die by it. All of it is verified by the
  gate's structural pass and waits on the play receipts.
- The `_G` defect is named in the census and the code comment
  both, because it is the shape every future engine reach must
  check first: this engine has no `_G`, and a lookup by string is
  a silent death here, not a convenience.

## Verification

- The prior-art sweep was paid before the build: both mods read
  from source (N&C's Lua uncompiled in the Workshop folder, The
  Alcoholic's MIT tree), their figures carried only where the
  translation survives, and C33's wrong record corrected by a
  dated entry with the original standing.
- All shipped Lua compiles under the engine's own Kahlua compiler
  (Border 50); the globals census walks the bytecode and holds
  all fifteen N&C names argued, read only, never written
  (Border 51); every dial reaches both halves or names its owner
  (Border 29); the new copy is ratified verbatim (Border 92); the
  `Drugs` literal is verified against the neighbour's own shipped
  scripts (Border 13). The jar is rebuilt from source and shipped
  after the stamp; the gate is clean at the new tip. The version
  machine derives 4.11.0.0-pre-alpha (minor - a new player-visible
  simulation capability: the county's habits are lived in the body,
  not just scheduled). Deploy follows this record, then the
  branch, the pull request, and the squash - the publishing law.

## Deferred verification

Runtime behavior is the operator's receipt boundary ([A21]'s
law): a mod-load test is a world start, and world starts are the
operator's. The carry, the ladder, and the smoke break are
verified by the gate's structural pass and join the play-receipt
queue - the legible receipts this batch names: a county body
under their benzo withdrawal calming on their own step, a user
walking to a believed supply and not a claimed one, a smoker
lighting one at their own pace with the dial on and only under
craving with it off, a drinker's sickness building and breaking,
and - for the one receipt the ladder can give that C33 could not -
a death laid to the drink.

## Next

The totality order continues: the county's ground moves (`C122`),
the county's animals (`C123`), combat-perception compatibility
(`C124`), then the neuroinflammation knot (`C125`, ZAO-led) - then
the crossed-doctrine batches, the off-switch list before runtime
verification (task #21), and the corpus and training passes
beyond.