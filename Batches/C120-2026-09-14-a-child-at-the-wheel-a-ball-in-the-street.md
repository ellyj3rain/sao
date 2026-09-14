# C120 - A child at the wheel, a ball in the street

| Field | Record |
| --- | --- |
| Batch | `C120` |
| Date | 2026-09-14 |
| Name | A child at the wheel, a ball in the street |
| Status | Closed append-only batch - the age attachments, built |
| Threads | [`T-001`](THREADS.md#t-001), [`T-002`](THREADS.md#t-002) |

## Record

The totality order named age attachments as the batch after Week
One's, and the prior-art law was paid before a line was written:
Growing Up was swept again for what the county now has machinery
for, and C31's not-carried list was found stale in four places -
driving (the county has driven since [C114]), growth spurts
(hunger is modeled and read), wound grief (fear and lesson
machinery both exist), voice lines (SAO_Voice has carried
registers since [C50]). Still honestly blocked, and named so they
are not mistaken for lost: their nightmares (agent-state sleep),
Getting Old's stumble (no setTripping on 42.20), the cooking
penalty (SAO people don't cook), their adaptation milestones
(Sunday Driver and Speed Demon are player traits the county's
hash people cannot hold), and their four-stage Kübler-Ross grief
machine with its doom spiral - authored outcomes, and the
emergence rule bars the door.

What crosses is the EVENT rendered through the county's own
machinery, at the figures of theirs that survive the translation:

- **The wheel.** A child under Growing Up's credited driving age
  of ten does not claim wheels on a venture at all - the venture's
  own claim gate reads the census's age ([C30]'s hash) before the
  door opens, and the car stays where it sits. A driver aged ten
  to seventeen takes the wheel with their credited thirty percent
  penalty: the drive's speed cap - the operator's own dial since
  [C115] - is scaled by `CHILD_DRIVE_PENALTY` for the whole ride.
  Their steering lag and brake scale are not carried; the cap is
  the one figure that survives.
- **The spurt.** Once a county day, a child under sixteen draws
  the credited eight percent (a per-person hash draw on the day,
  the way every county roll rolls), and a spurt lands as real
  hunger - the credited fifteen points on the engine's own 0..1
  stat, the same read every meal decision already listens to - and
  says so once. The dormant half feels nothing, and that is
  named: no body, no hunger.
- **The wound.** The every-ten-minute age pass now scans a child's
  own body for what the county's zombies leave - bites and
  scratches only; a cut is any edge's and the scan cannot know
  whose - and stamps the count on the record. A hurt child carries
  their grief the way the county carries everything else: as fear,
  `WOUND_FEAR` on every decision that reads it, until the same
  scan counts it healed and the voice says so. Their staged
  machine, their doom spiral and their delayed relief do not
  cross; the fear is ours and the one figure that survives is
  theirs.
- **The mouth.** A child's moments read differently from a grown
  one's - Growing Up's lines split by age band, credited; the
  words are SAO's own. Age now outranks the lesson where the table
  says so: eight tables carry a child register (FLEE, ALERT,
  ENGAGE, TREAT, warned, turnedSeen, firstLesson, grief), drawn
  from the census's own stage, and where childhood reads the same
  the table falls back to the lesson register exactly as before -
  so nothing that never split by age changes at all. Three flat
  banks - the spurt, the wound, the healing - are raised only at
  child sites. The child lines are held to the same law as the
  innocent ones: an age is not knowledge, so no child line names
  the thing.
- **The ball.** Week One's throw FBX was orphaned art - a zombie's
  throw in their mod, with no zombie-shaped moment to wear it
  here. It crosses as the eighteenth credited file and becomes a
  child's: at a ROAM arrival, a child who actually carries a ball
  (the engine's own `Base.Baseball`, or a basketball - and the
  jock kit now hands one out) with a playmate actually within
  reach - the player, or another live child within `PLAY_REACH`'s
  five named tiles, a throw travelling further than a counter's
  arm crowd - throws it, paced at two county hours like the
  counter's turn. The catch and the return are named in the code
  as having no machinery: the throw is the moment.

Border 123 was taught the third mouth before the register landed:
the border now walks three speakers - a grown innocent, a grown
taught, a child - checks the three draw disjoint sets on every
split table, holds the flat control (a child draws HOMEWARD's
lines like everyone), sweeps every child register structurally (a
child list that copies a grown line under another name faults),
keeps the child lines clear of the acquired vocabulary, and its
probe scans the hash for the speaker it wants so it cannot pass by
happening to draw adults. Border 63 gains the honest note: the
wound term is runtime record state, and Border 105's stub county
has no records, so the sampled 4.2..11.8 range describes the
sample it can reach and the comment prose names the term beside
it. Border 49 holds `PLAY_REACH` and its two bare-five collisions
argued in ALLOWED - the manual hand-off and the kindness window,
neither a play reach.

## What changed

- `mod/42.20/media/anims_X/Bob/BallThrow.fbx` - Week One's throw
  copied (347,708 bytes, byte-equal to the source), the eighteenth
  credited file; credited in CREDITS.md.
- `mod/42.20/media/AnimSets/player/actions/SAO_BallThrow.xml` -
  the node, generated on the cashier's own shape and keyed on
  `SAOGesture`; `tools/gestures_manifest.json` - the file entry
  and the `BallThrow`→`BWO_BallThrow` mapping; 96 files, 73 nodes.
- `mod/42.20/media/lua/shared/SAO_History.lua` - the [C120]
  figures block (`DRIVING_AGE`, `CHILD_DRIVE_PENALTY`,
  `GROWTH_SPURT_CHANCE`, `GROWTH_SPURT_MAX_AGE`,
  `GROWTH_SPURT_HUNGER`, `WOUND_FEAR`), each with the not-carried
  named beside it; the jock kit hands a baseball; a records
  correction at the height comment ([C109]'s way - the prose was
  wrong, the table never was).
- `mod/42.20/media/lua/client/SAO_Gesture.lua` - `G.BALL`,
  `TICKS.ball`, and the ball moment function.
- `mod/42.20/media/lua/client/SAO_Driving.lua` - `Drv.order`'s
  new `capScale` argument, applied to the sandbox cap.
- `mod/42.20/media/lua/client/SAO_Controller.lua` - the child
  wheel gate at the venture's claim (under ten leaves the car;
  ten to seventeen rides the penalty), and the ball moment at the
  ROAM arrival, with `PLAY_REACH` named.
- `mod/42.20/media/lua/client/SAO_Age.lua` - `Age.growthSpurt`
  and `Age.woundWatch`, wired into the every-ten-minute bodies
  loop on their own cadences.
- `mod/42.20/media/lua/shared/SAO_Disposition.lua` - the wound
  term in `D.fear`, capped as fear is capped.
- `mod/42.20/media/lua/client/SAO_Voice.lua` - the child
  registers on eight tables, the three child-only flat banks,
  `childOf` (the census's own stage, not a new field) and
  `resolve`'s child-first branch.
- The gate's own borders: `tools/speech_register_test.py` taught
  the third speaker; `tools/decision_range_test.py` the wound-term
  note; `tools/reach_collision_test.py` the `PLAY_REACH` argument.
- `CREDITS.md` - the Week One section's eighteenth file, and the
  Growing Up section's carried figures with the still-not-carried
  named.
- `tools/version_replay.py` - the `C120` unit row; `--write`
  stamps the coordinate.
- `BATCH_LOG.md`, `THREADS.md`, `SESSION_STATE.md`, `ROADMAP.md` -
  the pointers.

## Honest limits

- The wound scan counts bites and scratches only. A cut is any
  edge's, and the scan cannot know whose; a child scratched by a
  thorn in this build carries the fear anyway, because the scan
  reads the shape and not the cause - the county's zombies leave
  bites and scratches, and that is what grief answers here.
- The spurt is hunger alone: no height change rides it (height
  is the census's own band, [C29]/[C31]), and the dormant half
  feels nothing - no body, no hunger, no draw.
- Their nightmares, cooking penalty, adaptation milestones,
  staged grief machine, doom spiral, delayed relief and TTS audio
  are not carried, named in the code comments where the reader
  would look for them and in CREDITS.md.
- The ball is one-way: the playmate does not catch it and the
  ball does not come back. The throw is the moment; the catch has
  no machinery and says so in the code.
- `rec.woundCarried` is runtime state a bare VM cannot carry
  (Border 105's county has no records), so no border sample
  reaches the wound term - the range comments and Border 63's
  docstring say so rather than promising a sample it cannot draw.
- No play receipt, as ever: nobody has watched a child leave a car
  where it sits, a teenager drive at the cap's seventy percent, a
  spurt voiced, a hurt child frightened and a healed one relieved,
  a child's FLEE line in a grown mouth's county, or a ball thrown
  down a street. All of it is verified by the gate's structural
  pass and waits on the play receipts.

## Verification

- The prior-art sweep was paid before the build: Growing Up's
  config read again for the driving age, the penalty, the spurt
  chance and ages and the hunger boost; the not-carried named in
  C31's stale list re-swept; the Week One throw FBX found
  orphaned in their tree and its bytes verified on the copy.
- All shipped Lua compiles under the engine's own Kahlua compiler
  (Border 50); the manifest's new file is present, rigged and
  credited, and Border 109 binds the ball's node to the county's
  vocabulary (71 names, none unbound); the jar is rebuilt from
  source and shipped after the stamp; the gate is clean at the
  new tip with Border 123 walking three speakers, Border 63
  holding nine documented ranges, and Border 49 holding
  `PLAY_REACH` and its two argued collisions. The version machine
  derives 4.10.0.0-pre-alpha (minor - a new player-visible
  simulation capability: the county's children live their age).
  Deploy follows this record, then the branch, the pull request,
  and the squash - the publishing law.

## Deferred verification

Runtime behavior is the operator's receipt boundary ([A21]'s
law): a mod-load test is a world start, and world starts are the
operator's. The age attachments are verified by the gate's
structural pass and join the play-receipt queue - the legible
receipts this batch names: a child stood at a car that stays
where it sits, a slower teen behind the wheel, one hunger line
out of a spurt, a bitten child flinching at distances a healed
one doesn't, a child's own words at a moment a grown voice
answered differently, and a ball thrown to somebody on a stretch
of street.

## Next

The totality order continues: drugs in totality (C121) - then the
crossed-doctrine batches, the common-enemy weight, the off-switch
list before runtime verification (task #21), and the corpus and
training passes beyond.