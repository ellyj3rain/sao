# C119 - Week One's moments and the government's answer

| Field | Record |
| --- | --- |
| Batch | `C119` |
| Date | 2026-09-14 |
| Name | Week One's moments and the government's answer |
| Status | Closed append-only batch - the credited art's remainder and the nuke, built |
| Threads | [`T-002`](THREADS.md#t-002), [`T-004`](THREADS.md#t-004), [`T-007`](THREADS.md#t-007) |

## Record

The totality ruling named Week One in full, and the spectrum ruling
(Speakeasy records 49-50) settled the nuke's law before a line was
written: optional, randomized, never the default. This batch is two
halves under one law - the moments the county already occasions
dressed in the credited art's shapes, and the government's answer
re-expressed as a per-world fate behind a dial. The emergence rule
holds for both: no moment is authored on its own, and the strike
follows no script.

**The art crosses.** Seventeen more of the animator's files, copied
under the standing settlement ([C35], DR-034) and credited: the
cashier, the three protest stands, the three CPR stages, the four
dances, and the six instrument plays (flute, saxophone, trumpet,
violin, bass, electric), under `media/anims_X/Bob`; the two kabooms
(near and distant) under `media/sound/sao`, defined in the sound
script with the credit standing beside them. Every node is SAO's own
(`SAO_*`, keyed on `SAOGesture`), and the manifest holds every file,
its byte count, its author and - new, the waiter's precedent
generalized - the clip name inside it, because the engine knows
these files by the stack name within, not the file's name. The
manifest stands at 95 files and 72 nodes.

**The moments.** A gesture is never authored on its own; each rides
a decision the county already made, and the four new ones are:

- **The counter.** A street leg that arrives at the filed trade
  ground ([C113]) with somebody in front of them - the player, or
  any live body, within the counter's own four tiles
  (`COUNTER_REACH`, named, argued against the teaching stand-off and
  the porch band in ALLOWED) - takes the counter, paced at two county
  hours between turns so a busy shop is busy without one body stuck
  at the till all day. The commute was the decision; the customer is
  whoever the county actually put there.
- **The protest.** At the election seam, when BOTH members of a
  pair dissent from the policy, both hold the shape - a grumble
  with a body ([A25]'s seam grown visible), and a crowd of exactly
  the size the county's own politics produced. The voice still says
  the grievance.
- **The CPR.** At a medic's aid, when the hurt body is knocked down
  or nearly dead, the medic kneels: three queued actions (the start,
  the long loop, the letting-go) on the timed-action queue every
  gesture rides. The bandage is still real - desperate aid is the
  moment, and CPR is what desperate aid looks like.
- **The bard's own instrument.** The porch tune now carries the
  instrument the person actually holds: Population's instrument take
  reads the engine's own InstrumentWeapon category, and vanilla B42
  puts the flute, the saxophone, the trumpet, the violin and both
  electric guitars in it - so a bard with a flute plays the flute's
  clip, not the guitar's. The unmapped types keep the lists they had.
  The four dances join the porch crowd through the same hash-based
  pick every dance already uses.

**The government's answer.** Their `FinalSolution` is a script -
hour 168 of every world, eight to ten fixed circles, default on,
with a dream quest and a siren - and none of the script crosses.
What crosses is the event's engine idioms, credited: the fire
(`SetOnFire` on every body in the circles at ground level - the
county's people, the risen, the player), the ground (`BurnWalls` as
squares stream in, the burnt set kept per square so a re-visit does
not re-burn), the sound (their two kabooms, near or distant by
where the player actually stands), the sickness (the engine's own
food-sickness stat rising inside the circles - their radiation
idiom, twice as fast outside as under a roof, capped at the engine's
own severe band), and their town list (the ten `SetupNukes`
coordinates - map facts, like the street hour).

What replaces the script is the ruling, in full:

- **A dial, default OFF** (`SurvivorAwareness.WeekOneNuke`): a fresh
  world asks for nothing, and off stops the countdown, the strike,
  the fallout and the burning of new ground alike - a strike overdue
  while off lands when it is on again.
- **A draw, once per world.** When the dial is on, the first county
  day after the fall is asked about draws the fate - the delay (5 to
  21 days), the count (1 to 4 circles), the towns (drawn without
  replacement from the ten), the radii (500 to 1000) - off the
  engine's own dice, persisted in ModData: the same save carries one
  fate, and a new county is a novel apocalypse. The store's
  exclusive-high arithmetic is honored to the tile (the spans run
  one past the reachable end, the same idiom the roam's own
  `int(-range, range + 1)` leans on).
- **The fall's own calendar.** The countdown starts at THE FALL -
  the earliest stamp the county wrote at its moments that matter -
  not at the save. A world begun after the fall has its fall at
  county hour zero (county hours already count the world's behind),
  so a strike overdue at world start fires the first county day:
  the player walks into a struck county, which is the honest
  reading of a world that began deep into the outbreak.
- **After the strike, no script at all.** The engine's fire burns
  what fire burns, the sickness rises where the circles hold once a
  county day, and every consequence after is the county's own
  machinery reading a county that changed. The whole thing runs on
  the one county-day hook every other daily verb runs on
  (`dailyCounty`, the [C65] law), so the years pass drives a struck
  county exactly as the live one does.

## What changed

- `mod/42.20/media/anims_X/Bob/` - 17 FBX copied (cashier, protests,
  CPR stages, dances, instrument plays), credited in CREDITS.md.
- `mod/42.20/media/sound/sao/` - the two kabooms copied;
  `mod/42.20/media/scripts/sounds_SAO.txt` - `SAONukeNear` and
  `SAONukeDist` defined with the credit standing beside them.
- `mod/42.20/media/AnimSets/player/actions/` - 17 nodes generated,
  every one SAO-named and keyed on `SAOGesture`.
- `tools/gestures_manifest.json` - 17 file entries, 17 node→clip
  mappings, and the per-file `anim` key (the clip name inside),
  which the gate now reads; 95 files, 72 nodes.
- `mod/42.20/media/lua/client/SAO_Gesture.lua` - the vocabulary
  (`G.BARD`, `G.CASHIER`, `G.PROTEST`, `G.CPR`, the four dances in
  `G.DANCES`), the CPR tick stages, `playInstrument`'s carried-type
  fourth argument, and the three new moment functions.
- `mod/42.20/media/lua/client/SAO_Controller.lua` - the counter at
  the ROAM arrival seam (with `COUNTER_REACH` named), the CPR at the
  MEDICWARD aid success, the porch-tune's carried instrument read.
- `mod/42.20/media/lua/client/SAO_Exchange.lua` - both dissenters
  of a dissenting pair take the protest shape.
- `mod/42.20/media/lua/client/SAO_Nuke.lua` - NEW, the whole module:
  the dial, the draw, the strike, the fallout, the square burner.
- `mod/42.20/media/lua/client/SAO_Population.lua` - the nuke's day
  pass on the county-day hook.
- `mod/42.20/media/sandbox-options.txt` +
  `shared/Translate/EN/Sandbox.json` - the `WeekOneNuke` dial and
  its ratified copy, default OFF.
- `CREDITS.md` - the Week One section extended: the seventeen files,
  the two sounds, and the nuke's engine idioms, with what does not
  cross named so it is not mistaken for lost.
- The gate's own borders extended honestly: the manifest's `anim`
  key generalizes the waiter's case; the option-reach border learns
  the dial's owner; the copy border holds the ratified tooltip; the
  reach borders hold `COUNTER_REACH` and its two argued collisions.
- `tools/version_replay.py` - the `C119` unit row; `--write` stamps
  the coordinate.
- `BATCH_LOG.md`, `THREADS.md`, `SESSION_STATE.md`, `ROADMAP.md` -
  the pointers.

## Honest limits

- The dormant half feels no fire and no fallout: people simulated
  without bodies stand where they stood. The dial they answer is the
  dormant-risk dial, which is the off-screen danger of the world
  they walk - and a town's population thinning to a struck circle is
  that dial's own story.
- The distant booms do not stagger: a county struck in four places
  hears four booms at once. Their scheduler staggered them; the
  draw's honesty costs the theater.
- The strike is one pass at the county day: a body that walks into a
  circle after the strike meets the fallout, not the fire. The
  ground's burning follows the player's own horizon (squares burn as
  they stream in), which is how theirs behaves too.
- No nuclear winter (their climate override), no hazmat immunity,
  no hydro deaths, no player screen flash, no vehicles burned
  (their vehicle burn is a script-swap to a burnt wreck, not an
  engine call), no dream quest, no siren countdown, no
  in-game kill switch. All named in the module header and CREDITS
  so they are not mistaken for lost.
- The synth has no clip (their XML binds none) and the pianos are
  seated shapes with no piano object modeled in the county; the
  acoustic guitar keeps the clip the county already owns. A bard
  with a keytar or a banjo plays the guitar's shape, as before.
- The crossed eat only what the doctrine rules and this batch does
  not touch them; the nuke does not choose its towns by who holds
  them - the draw is blind, which is what a government's answer is.
- No play receipt, as ever: nobody has watched a cashier ring up a
  customer, a pair of dissenters stand together, a medic kneel and
  let go, a bard with a flute, or a county drawn for its fate and
  struck on schedule. All of it is verified by the gate's structural
  pass and waits on the play receipts.

## Verification

- Every surface was swept before a line was written, per the
  prior-art law: their `SetupNukes` (the ten town coordinates, read
  whole), their `Nuke`/`NukeDist` (the engine calls, translated),
  their `BWOPlayer` radiation idiom (the food-sickness stat, the
  outside/inside rates, the cap), their bumped XMLs (the clip names
  inside the FBX, read from their own bindings), their sound
  definitions, the vanilla InstrumentWeapon catalogue, and the
  engine surfaces javap-verified first: `getHealth`/`setHealth`,
  `isKnockedDown`, `getZombieList`, `Stats.get`/`set`,
  `CharacterStat.FOOD_SICKNESS`, `Events.LoadGridsquare`.
- All shipped Lua compiles under the engine's own Kahlua compiler
  (Border 50); the manifest's 17 new files are present, rigged
  (Bip01 bones read in the binary) and credited; the jar is rebuilt
  from source and shipped after the stamp; the gate is clean at the
  new tip with the two reach borders holding `COUNTER_REACH` and the
  copy border holding the ratified dial. The version machine derives
  4.9.0.0-pre-alpha (minor - a new player-visible simulation
  capability: the county's trades, politics and medicine wear
  bodies, and a world can ask for the government's answer). Deploy
  follows this record, then the branch, the pull request, and the
  squash - the publishing law.

## Deferred verification

Runtime behavior is the operator's receipt boundary ([A21]'s law):
a mod-load test is a world start, and world starts are the
operator's. The moments and the answer are verified by the gate's
structural pass and join the play-receipt queue - the legible
receipts this batch names: a cashier behind a counter with a
customer in front of them, two people standing together against a
policy they both hate, a medic's hands over a body that is down, a
flute that looks like a flute, and - for the one world that asks
for it - the government's answer arriving on the day the draw said.

## Next

The totality order continues: age attachments (C120), drugs in
totality (C121) - then the crossed-doctrine batches, the
common-enemy weight, the off-switch list before runtime
verification (task #21), and the corpus and training passes beyond.