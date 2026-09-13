# C112 - The tick is the county's clock

| Field | Record |
| --- | --- |
| Batch | `C112` |
| Date | 2026-09-12 |
| Name | The tick is the county's clock |
| Status | Closed append-only batch - mod state and law |
| Threads | [`T-002`](THREADS.md#t-002), [`T-007`](THREADS.md#t-007) |

## Record

The queue's item 4 said everything except the voice cooldown counts
frames, so a 144Hz machine runs a county 2.4x faster than a 60Hz one,
and `[C75]` had moved only the dormant walk. Asked how far to take the
fix, the operator ruled (2026-09-12): all of it, and as one robust
system - "I would personally prefer to benefit from having a robust
system."

This batch pays that ruling with ONE law rather than sixty conversions:

**A tick is a 9000th of a county hour** - `SAO.History.ticks()`,
`floor(countyHours() * 9000)`. The number 9000 is a derivation, not an
authoring: at sixty frames a second on the default day length (a real
minute a game hour: 150 real seconds of frames), a frame WAS a 9000th
of a county hour. Every span constant already authored in ticks - the
1800 of a dormant move, the 240 of the population pass, the 20 of a
scan, the 600 of a zombie horizon, the 120 of a witness's freshness -
keeps its number and its default-day pace. What changes is the domain:
the tick now advances with the county, and the county's pace stops
following the machine.

The law's arithmetic corollaries, stated once in `SAO_History`:

- **A cadence is a last-fired stamp plus a span, never a modulo.** The
  county's clock can skip values (fast-forward, a lag spike), and a
  modulo gate only fires when a multiple lands exactly. The two modulo
  cadences that existed - the population pass gate and the tally-flush
  gate - are now last-fired stamps. Voice's `tick % #list` is not a
  cadence but a deterministic pick, and stays.
- **A stamp of 0 reads as long ago.** Every defaulted stamp in the mod
  means "do it now", never "never", so the migration below can drop
  foreign stamps to 0 in safety.

What the one law buys, all stated at the law:

- A 26fps machine and a 144Hz machine run the same county at the same
  pace ([B49] had measured the operator's own machine at 64.5fps and
  called the oddity by name).
- Fast-forward speeds the timers with the world they time, instead of
  the county rushing ahead of its own beliefs; a pause stops them with
  it.
- **The two tick clocks are one.** Controller's `tickCount` and
  Population's `tickCounter` each had its own OnTick, each counted its
  own frames, and Perception's belief axis was stamped by both -
  `SAO_Age` hallucinated on Controller's, `SAO_Population` looked on
  its own, and during the years they diverged by whole simulated days
  (the years advanced Population's counter 3600 a day and never touched
  Controller's). Both read the one clock now, so every stamp in the
  county - `agent.nextDecisionAt`, `belief.at`, `dormantLastMet`,
  `pb.lookedAt`, `dayGoalSeenAt` - is on the same axis by construction.
- **The tick axis crosses sessions.** County hours are world-age, so a
  stamp made yesterday reads as yesterday after a reload - which no
  frame count ever did. [C15]'s reload rebase existed because "the tick
  axis cannot cross sessions"; that sentence is now false, and the
  rebase is gone (see Migration).
- **The years advance the clock themselves.** A simulated day on the
  county's clock is 216,000 ticks, so `[C45]`'s calibrated
  `YEARS_TICKS_PER_DAY = 3600` fake advance is deleted: the gates open
  on the clock's own authority, and the pass's once-per-day cadence -
  which was always the real authority ("one move and at most one
  meeting per day") - still holds each person to their day.

Everything else in the tree inherits the law without an edit: the
timer sites in `SAO_Controller` (decisions, tasks, cries, drink seeks,
memorials, wood runs, builds, shot judges - all `tick + span` stamps
against `tickCount`), `SAO_Exchange`'s seams and elections, the
dormant systems' gates in `SAO_Population`, Perception's scans and
horizons, and every `SAO.Controller.tick()` reader (`SAO_Gesture`,
`SAO_Inspect`, `SAO_Harness`, `SAO_Command`, `SAO_PlaceAttachment`,
`SAO_Age`'s hallucinations) - all compare and stamp on the axis they
are handed, and the axis is now the county's. `SAO_Age`'s own
`passCounter` is untouched and correct by construction: it counts the
ENGINE's EveryTenMinutes events, which are game-time, and it is used
only as a hash salt, never as a timer. `SAO_Voice`'s cooldown keeps
[B49]'s wall clock - the named exception, restated there: the player's
ears are in real time no matter whose clock the county keeps.

## Migration, and why it is shaped this way

A save carried from an older build holds FRAME-domain stamps, and they
cut both ways:

- Most sit below the county's ticks and read as ANCIENT - stale,
  pruned by their horizon, rescan. The safe direction; nothing to do.
- A long pre-[C112] session's frame count can sit ABOVE a young
  county's ticks, and a stamp ahead of now reads as ultra-fresh forever
  (every freshness test passes a negative age). In the county domain a
  stamp can never be ahead of now - stamps are made at now and the
  clock never runs backwards - so ahead-of-now is a domain mark, not a
  value. On belief-store bind, `dropForeignStamps` walks every
  tick-stamped field (the `*At` fields, the `zombies`/`people`/
  `factions` sighting stamps, `criedTiles`, and the `places` and
  `known` maps, keyed by owner and building id, which the generic
  field walk cannot reach) and drops each foreign one to 0. One
  reload's relearn per old save, both directions safe, then never
  again.
- `rec.nextDormantMoveAt` is the one persisted FUTURE due-time in the
  county, and a frame-domain one could stall a walker forever. The
  field is only ever set to now + at most 3600, so at its read site
  anything further ahead than that is dropped to 0 - due now.

The rebase's deletion is the migration's other half, and the reason is
the reverse of [C15]'s: zeroing fresh stamps on every reload would now
be the bug the rebase cured - it would age a two-minute-old belief to
the beginning of the world on every load, because 0 is no longer "this
session's start" but "before the fall". A bind that happens before the
bridge is up understates the county's hours by the days it owes, which
can zero a legitimate stamp - and zeroing reads as ancient, the safe
direction, so an early bind costs freshness, never correctness; stated
at the check.

## What changed here

- `SAO_History.lua`: `H.ticks()` and the law, with both corollaries.
- `SAO_Controller.lua`: `tickCount` reads the clock (frame fallback
  only for a county whose `SAO_History` did not load - the dead county
  [C62] names at boot); the tally flush is a last-fired stamp.
- `SAO_Population.lua`: `tickCounter` reads the clock the same way;
  the pass gate is a last-fired stamp; `YEARS_TICKS_PER_DAY` and its
  advance deleted; `rec.nextDormantMoveAt` domain guard; the [C75]
  comment's years sentence re-stated.
- `SAO_Perception.lua`: the [C15] rebase deleted,
  `dropForeignStamps` in its place; the horizons' [B49] comment
  re-stated to county ticks.
- Comments re-stated where they said "frames" and now misstate the
  law: `SAO_Log`'s EVERY, `SAO_Disposition`'s roam interval,
  `SAO_Controller`'s WITNESS_FRESH and CORPSE_GRACE, `SAO_Voice`'s
  [B49] history, `SAO_Population`'s TICK_INTERVAL, MEET_COOLDOWN and
  BAND_PATIENCE. Numbers untouched everywhere.
- No span constant anywhere changed its value. That is the point: the
  unit was redefined, not the county re-tuned.

## Honest limits

- The 9000 derivation anchors to the DEFAULT day length. On a longer
  or shorter sandbox day, county-hour spans mean proportionally more
  or less real time - which is the correct semantics (the county lives
  in game time) but is a feel change on non-default days, and the feel
  is a play receipt.
- The first population pass of a session now fires on the first frame
  rather than 240 frames in (the cadence law stamps from "never
  fired"), so the boot digest speaks at load. Every subsystem it
  touches is pcall-bulkheaded and the years pass itself waits for
  genesis and the clock; stated here because it is a behavior change,
  however small.
- The upgrade reload costs one relearn: old-save minds age out and
  re-scan, and a `dayGoalSeenAt`/`lookedAt` pair can hold "already
  looked" over a zeroed sighting until the pair actually crosses
  paths again. One reload per old save, by design, not smoothed over.
- What the county FEELS like on the county's clock - on the
  operator's own machine, which [B49] measured at 64.5fps and which
  now runs at the same pace as everyone else's - is a play receipt
  the C era owes with the rest.
- A border for the law belongs to the end pass with the rest of the
  deferred verification; none was written here, per the standing
  order.
- END PASS, 2026-09-13: that border landed as Border 153
  (`tools/tick_law_test.py`). The arithmetic is measured in the VM
  (one county hour advances the tick exactly 9000, the clock is
  floored), and so is the skip: quarter-hour jumps in single steps,
  values no 240 modulo lands on, still open the pass gate and the
  meetings stamp on the county's own axis. One clock read fresh by
  both counters, the stamp-plus-span pass gate, the tally stamp, the
  domain-guarded due-time, the belief-bind foreign-stamp drop, the
  deleted calibrated jump, and the voice's wall-clock exception are
  held in text.

## Verification

Deferred by the operator's standing order for this pass: no gate,
build, deploy, package, test, or git until the planned feature work is
finished; all of it runs once, at the end. Version stamps restamp in
that same end pass.