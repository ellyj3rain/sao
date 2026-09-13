# C113 - The street hour and the trade's ground

| Field | Record |
| --- | --- |
| Batch | `C113` |
| Date | 2026-09-13 |
| Name | The street hour and the trade's ground |
| Status | Closed append-only batch - the streets half of the Week One port ([C110]) |
| Threads | [`T-002`](THREADS.md#t-002), [`T-007`](THREADS.md#t-007) |

## Record

The last unbuilt named slice of the Day Zero arc was "Normal-life
behaviour on open streets." This batch builds it, as the first half of
the port the operator ruled at `[C110]`: Week One's CODE, taken and
re-expressed on SAO's own people through the county's clock, gated by
`fallHasCome`, credited per author, no runtime dependency, and never
Bandits' programmed zombies on a scripted timeline. The second half -
the driving - is `[C114]`.

**What crossed, and what it became here.**

- **The street hour** (`BWOPopControl.getHourScore`'s `hmap`, Slayer's
  authored twenty-four values, read from the installed mod at Workshop
  3403180543 and carried whole). In Week One the curve scaled how many
  street civilians its spawner put around the player. Here it is a
  per-person propensity: `SAO.History.streetAffinity(hour)` answers the
  chance that this person's next ordinary leg of the day goes OUT
  rather than staying in. Same authored shape of a day - nobody at
  three in the morning, everybody at eight, the second wave at four in
  the afternoon - out of SAO's own census instead of out of a spawner.
  The values are prior art carried with credit, not numbers authored
  here; values above 1.0 mean certain out, and the `unit() < affinity`
  comparison answers that by construction.
- **The street occupations** (Week One's Runner 4% / Postal 4% /
  Gardener 5% / Janitor 3% / Vandal 1% / rest Walker). The weights do
  NOT cross: they are spawn-side rolls on a zombie spawner, and this
  ontology has no spawner - the census already decided who is what
  trade, and the trades already dress themselves
  (`Census.OUTFIT_BY_KEY`). What crosses is the idea: a person on the
  street is there doing their trade's ordinary thing. Re-expressed as
  the trade's ground - `chooseDayGoal` gains a WORK branch, behind
  need and ahead of company, that walks the person to a stable
  workplace picked once from the profession-filed points the county
  already reads (`pickOriginFor`, [A18]) and kept, because a commuter
  does not re-apply for a different office every morning.
- **What never crosses, named so it is not mistaken for lost:** the
  scripted world-age timeline (outbreak day 128, zombie-only at 170),
  the spawn/despawn controllers, the density math
  (`GetDensityScore`-scaled nominal populations), and the whole
  programmed-zombie substrate. The THINNING past the outbreak day is
  not ported because it is not a port - it is what the county's own
  machinery already does (DR-036's generator principle): people die
  and turn through the engine's own law, `fallHasCome` flips on the
  county's own stamps, and the street law dies with it. An ordinary
  county that bleeds thins on its own facts; nobody schedules it.

**Both halves, one law.**

- The dormant half (`dormantLife`): the flat night rule (`>= 21.0 or
  < 6.0`, home) now applies only after the fall. Before it, the roll
  sits at the LEG BOUNDARY - the one moment a decision is actually
  being made - not at every move gate (a gate opens every dozen county
  minutes; rolling there would churn a person between home and street
  hourly at any affinity under one). Out means the day-goal chooser
  answers (need, then work, then somebody, then places); staying in
  means the next leg is home, and the goal machinery is skipped
  entirely - an evening in is an evening in, not a failed errand. The
  authored curve itself thins the small hours (0.20 down to 0.05) and
  keeps the evening streets fed (0.90, 0.70, 0.40), which is the open
  street the slice asked for.
- The live half (`SAO_Controller`'s roam gate): before any
  survival-era machinery decides anything, an undesignated person in
  an ordinary county rolls the same street hour on the engine's own
  clock - the hour of the day is the hour of the day in whichever half
  you are standing in. Staying in is the leg not taken (the gate
  re-arms). Going out is a commute when the census filed ground under
  the trade, else the same stretch of legs the undesignated always
  had. The workplace is the SAME persisted fact the dormant half
  derives (`rec.workX`/`rec.workY`) - one job, both halves, whichever
  got there first - read through the one public export the points
  machinery gains (`SAO.Population.tradeGroundFor`).

**Gating, the county's own.** `fallHasCome` ([C42]) gates every piece
of it, read from the record's stamps and calendar, never the dial. The
street law runs only where the county says "before" - and its REASON
must be "before", not merely false: a county that cannot read its
calendar at all ("unknown") gets the survival law, not a street crowd
it may not have earned. Designated people (watch, scout) keep the
county's own organization in any era; the live night hold (22:00, the
evening seat and sleep) stands un-ported-over - people sleep at night
even in an ordinary county, and the curve's tail on the dormant half
carries what the record side needs of the late evening.

**Design, decided here** (no operator fork was open; carried far
enough to see it was understood, per `[A11]`'s posture):

- Work sits BEHIND need and AHEAD of company in the chooser. The job
  is the recurring anchor of an ordinary day; a person with no filed
  trade ground falls straight through to the social life `[C72]`
  built, so nobody is barred from company by having a job.
- The county-anchored ([A18]) already live where they work - the
  near-check sends them through to errands and visits, which is
  ordinary life too.
- The commute goal carries no `placeId`: a profession-filed point is
  street-side ground, not a known building; they learn the ground as
  they pass it, by the `[A15]` rule that already runs.

## What changed

- `SAO_History.lua` - `STREET_HOUR` (the credited curve, hour-indexed
  0..23 exactly as authored) and `H.streetAffinity(hour)`.
- `SAO_Population.lua` - `chooseDayGoal` gains the gated work branch
  (stable `rec.workX`/`rec.workY`); `dormantLife` computes `preFall`
  from `fallHasCome`'s reason and puts the street roll at the leg
  boundary, replacing the flat night rule before the fall;
  `Pop.tradeGroundFor` exported (the one public face of the
  profession-points machinery, for both halves).
- `SAO_Controller.lua` - the roam gate's pre-fall street leg: the roll
  on the engine hour, the commute through the same `rec.workX` fact,
  the near-check that turns arrival into a stroll, and the leg not
  taken when the hour says in.
- `CREDITS.md` - the Week One section now carries the code port
  (the curve, the street-occupations idea) beside its art.
- `ROADMAP.md` - Day Zero slice 1's unbuilt line closes for the
  streets; the driving half is named as owed at `[C114]`. The "named
  by the operator" Week One paragraph, which still said nothing of its
  logic crosses, now states the `[C110]` ruling and what crossed.
- `BATCH_LOG.md`, `THREADS.md` (T-002, T-007), `SESSION_STATE.md` -
  the pointers.

## Honest limits

- The curve's late-evening tail (21-23) is fully expressed only on
  the dormant half; the live half composes with the county's own
  night hold, so visible evening street life ends at the sleep law's
  edge (22:00), not the curve's. Stated above, not hidden.
- The street leg is walking. Pre-fall DRIVING - a live goer who took
  a car actually entering seat 0 and driving it - is the next batch
  (`[C114]`), and the live receipt it owes is named there.
- No play receipt: the operator has not stood in an ordinary county
  and watched the streets fill at eight and thin at three. The batch
  is OPEN pending that receipt, like every batch of this era.

## Verification

Deferred to the operator's standing order for this pass: no gate,
build, deploy, package, test, or git until the planned feature work is
finished; all of it runs once, at the end.