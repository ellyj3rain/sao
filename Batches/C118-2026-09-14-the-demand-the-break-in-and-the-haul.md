# C118 - The demand, the break-in, and the haul

| Field | Record |
| --- | --- |
| Batch | `C118` |
| Date | 2026-09-14 |
| Name | The demand, the break-in, and the haul |
| Status | Closed append-only batch - the raider vocabulary, built |
| Threads | [`T-002`](THREADS.md#t-002), [`T-004`](THREADS.md#t-004), [`T-008`](THREADS.md#t-008) |

## Record

The totality ruling named bandits and raiding as totality's own, and
the sweep found ten gaps where the county had no words for taking
from the living. This batch is those words - four laws, all of them
per-person decision machinery under the emergence rule: no raid
timeline, no raider class, no badge that flips a person hostile, and
no authored outcome anywhere. `D.wouldForceEntry` was the honest
hard-false it shipped as (a lock ended a walk, always); it is now a
real bar, and everything composed on top of it is character against
situation.

**The forcing bar.** `D.wouldForceEntry(id, fleeing, pressing)` - the
flee still always licenses the glass (the FLEE seam's own law,
unchanged); otherwise the person answers the lock out of their own
character: aggression against discipline is the fight, initiative
adds half its weight beyond the population's middle, and `pressing`
is the walk's own situation carried in by the caller on the same
0..1 scale - half a person's worth if the destination is claimed and
the claim holder is standing-hostile (`claimedByOther`, either
direction of `isHostileTo`), half again if hunger has crossed the
county's own desperation line (`policy().desperation`). Zero
authored constants: a disciplined person never forces anything, and
the standing question was already answered when the walk was ordered
(`mayEnterBelieved`, [A24]/[B35] untouched) - this is only the LOCK.
The unclaimed locked house stays standing-legal and
disposition-only, exactly as before.

**The breach, plumbed.** A barrier verdict at the movement seam
(LOCKED, BARRICADED, WINDOW_DECLINED) ends the walk's ROUTE, not the
want. The seam reads the destination out of the locomotion job's own
goal, computes the pressing, and asks the bar: the composed decline
with the same visible line as ever; the willing take it on. The
declined window re-licenses (`setForceEntry`) and re-orders the same
goal - the smash flow the FLEE state already owns, reached by
disposition instead of urgency. The locked or barricaded door and
the barricaded window answer a NEW bridge verb, `batterBarrier`,
backed by `SAOMovement.batter`: one engine hit per
verdict-hit-re-order cycle (the swing cadence emerges from the
walk's own pathing time), through the engine's own `WeaponHit` with
the held weapon, the edge toward the goal asked first then every
cardinal edge - the same price the player pays, barricade planks by
the engine's own damage math, door health down, and the thump noise
of it drawing whatever hears it. Bounded: forty swings and the walk
gives up wanting the door ("the barrier held"); the count resets the
moment a walk ends any other way, and an empty hand is an honest
stop - fists do not batter, and the walk gives up.

**The demand and the yield.** At the confrontation seam, before the
grudge's blow: an armed person with a standing grudge at talking
distance (`TALK_REACH`), permitted by standing and not overwhelmed,
whose own aggression, nerve and fear say demand rather than strike
(NEW `D.wouldDemand`), speaks it - Voice "demand" in the plain
register, logged, and this decision is the offer; no combat starts
this tick. What the other person does with the demand is THEIR
machinery: the window is the other side's next decision, and if
nobody answers, the silence is answered by the confrontation branch
on a later decision, exactly as it always has - the demand buys a
window, never an outcome. Once per pair per county day ([B3]'s
bitten cadence, robbed): a mugger does not nag. On the other side,
before the flee seam: a believed-hostile person at talking distance
faced by a character whose fear, nerve and self-preservation say
give (NEW `D.wouldYieldTo` - one whole person's worth of fright; a
settled adult does not yield to a shadow) hands over a spare piece
of food - `findSpareFood`, the second-best, the robbed keeping
their own last meal - through the same vanilla
`ISInventoryTransferAction` every kindness in this county uses, with
none of the kindness. Whether the other demanded is not this side's
question: each side reads only its own beliefs and its own
character, so a demand may meet no hand and a hand may rise with no
word before it. Once per pair per county day; the victim's trust
bends (`adjustTrust` −0.05) and the flow continues - fear's answer
walks away right after.

**The haul.** At the ROAM arrival seam, a warpath walk (`[A27]`'s
one watch leg in six, the marker that already travels on the
venture) that arrives on ground answering hostile - `claimedByOther`
and hostility either direction, the same gate the walk was ordered
under - takes the enemy's stores through the forager's own
`takeWantedFromNearby`, capped at the same ceiling a skilled sweep
tops out at (4). The taking is the feud made physical; the haul
walks home and shelves through the deposit machinery the forager's
haul already uses. No new state, no new venture kind, nothing a
witness cannot see: the smash is loud by the engine's own rules, and
the grudge machinery spreads the story the way testimony always has.

## What changed

- `mod/42.20/media/lua/shared/SAO_Disposition.lua` - the real
  forcing bar (`wouldForceEntry` with `pressing`), and NEW
  `wouldDemand` / `wouldYieldTo` (the demand's mouth and the robbed
  hand, both character-only readers).
- `java/src/com/sao/engine/SAOMovement.java` - NEW `batter` (the
  engine-true swing: direction-ordered edge scan, `faceThisObject`,
  `WeaponHit` with the primary-hand weapon, verdicts
  DOOR/DOOR_DOWN/WINDOW/UNARMED/NOTHING_TO_BATTER/BATTER_FAILED).
- `java/src/com/sao/bridge/SAOBridge.java` - NEW `batterBarrier`,
  the composition's only door to the swing.
- `mod/42.20/media/lua/client/SAO_Controller.lua` - the barrier
  answer at the movement-verdict seam (pressing, the window
  re-license, the batter loop with its bound and reset); the demand
  at the confrontation seam; the yield before the flee seam; the
  warpath haul at ROAM arrival.
- `mod/42.20/media/lua/client/SAO_Voice.lua` - `demand` and
  `yielded`, the plain register.
- `tools/version_replay.py` - the `C118` unit row; `--write` stamps
  the coordinate.
- `BATCH_LOG.md`, `THREADS.md`, `SESSION_STATE.md`, `ROADMAP.md` -
  the pointers.

## Honest limits

- No infrastructure sabotage verb exists: a raid's destruction is
  the batter's own honest seed (the planks fall because the engine
  says they fall), and no one seeks a generator to break. The gap
  stays open on purpose - machinery for sabotage would need its own
  prior-art sweep.
- Hostile interior occupation is entry only: nobody flips a claim by
  walking through a smashed door. Standing's claim verbs stay with
  the holders, and the intruder stands on ground the county still
  reads as the enemy's - every `mayEnter`, witness and testimony
  question answers as it did.
- The unarmed cannot batter, and the yield hands over spare FOOD
  only - the one want the engine's find-spare verb names. A robber
  who wanted the victim's weapon takes it the hard way or not at
  all.
- The forty-swing bound is the one authored number in the breach,
  and its direction is the county's (barricades should hold against
  a single afternoon). A metal door with a full plank load outlasts
  it, which is the honest price of wood.
- No new agent states and no movement-map churn: the whole vocabulary
  lives inside the states that already exist, on the seams they
  already own.
- "Raider" is never a class - it is a bar a person crosses on a
  given afternoon, and crosses back. Nobody is branded; the county's
  answer is the witnesses' (the noise draws them) and the grudge
  machinery's (testimony spreads the smash), both already built.
- No play receipt, as ever: nobody has watched a pressed and angry
  survivor batter a barricade down, a demand met by a yielded can of
  beans, or a warpath walk come home with the enemy's stores. All of
  it is verified by the gate's structural pass and waits on the
  play receipts.

## Verification

- Every surface used was swept before a line was written, per the
  prior-art law: KNOX_SOCIAL_AUDIT's ROBBERY (translated, not
  adopted - the reference rolls an outcome; ours is a window the
  victim's own machinery answers), [A24]/[B35]'s mayEnter law, [A27]'s
  war party and raidG, [A28]'s forager take, [C44]'s boardWindow as
  the new-bridge-verb precedent, the GEARWARD covet-decline ("wanting
  is not taking"), [B3]/bittenWary's per-pair daily cadence, and the
  engine surfaces verified by javap first: `WeaponHit` on
  IsoThumpable/IsoDoor/IsoWindow, `isLocked`/`isBarricaded`/
  `isDestroyed`, `getPrimaryHandItem`, `faceThisObject`, and the
  square's edge accessors.
- All shipped Lua files compile under the engine's own Kahlua
  compiler (Border 50); the jar is rebuilt from the new sources and
  shipped (35 classes, all sources present); the bridge border
  MATCHes every call site (`batterBarrier` answered by the shipped
  jar); the gate is clean at the new tip. The version machine derives
  4.8.0.0-pre-alpha (minor - a new player-visible simulation
  capability: the county raids itself). Deploy follows this record,
  then the branch, the pull request, and the squash - the publishing
  law.

## Deferred verification

Runtime behavior is the operator's receipt boundary ([A21]'s law): a
mod-load test is a world start, and world starts are the operator's.
The bar, the breach, the demand, the yield and the haul are verified
by the gate's structural pass and join the play-receipt queue - the
most legible receipts this arc names: a batter heard across a
street, a robbery survived by handing it over, a warpath walk that
comes home heavier than it left.

## Next

The totality order continues: Week One's moments and gestures (the
C119 seam the plan already numbers), age attachments, drugs in
totality - then the off-switch list before runtime verification
(task #21), and the corpus and training passes beyond.