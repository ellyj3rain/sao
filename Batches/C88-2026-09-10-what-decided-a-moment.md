# C88 - What decided a moment

| Field | Record |
| --- | --- |
| Batch | `C88` |
| Date | 2026-09-10 |
| Name | What decided a moment |
| Status | Closed append-only batch - instrument and border, no mod code |
| Threads | [`T-004`](THREADS.md#t-004), [`T-008`](THREADS.md#t-008) |

## Record

The next dataset proposal takes a new target the trades open up -
rows where the person's trade is the situation's hinge - and that
needs the dump's rows to hold more than they held. This batch is the
instrument for it: the survey that measured where a trade actually
decides something, the capture that fills the one gap the survey
found, and the border that holds both. The rows themselves are the
next batch, authored from the harvest this one launched, as a
proposal the operator rules on.

## The survey: two moments, measured

The dormant trades-hinge surface was measured, not assumed. Every
skill read in the dump's own verbs was walked; exactly two moments
sit inside `SAO.Standing.electLeader`, the verb the dump already
wraps, where a member's own engine-paid skill moves a designation:

- **The best-hand redirect** - the deal follows the best hand: when
  a member's own pay for another job beats their pay for the dealt
  one by three or more, the dealt work yields. The house hands the
  rifle to whoever can shoot.
- **The need-pull** - an unmet house need pulls the best-suited hand
  into the gap, skill first, class affinity as tiebreak, one
  promotion per election, and never from a job that is itself
  answering a need.

Everything else the survey walked is either live-half only (the
teaching seam needs a body; the controller's proven check needs the
player) or player-facing, so invisible to a dormant dump.

The `[C86]` harvest was then counted, not re-run: across six engine
counties, four redirects - all a burger flipper or chef's cook pay 4
against a dealt forager pay 0 - and eight need-pull promotions, all
to watch over organic feuds, and **all eight zero-pay**: the trade
decided none of them. Read closer, the whole harvest holds no
Foraging pay at all - of 5232 member-rows, forager pay is minus one
4457 times and zero 775 times, never more - because no profession
in the catalog boosts it. So the forager pull is never a trade's
decision; it is the class the county's own rule points at. The paid
trades are cook (pay 2: 273 rows, pay 4: 7), medic (pay 3: 44) and
watch (pay 4: 29, pay 2: 5) - and the medic need can never fire
dormant, because hurt detection needs a body. The honest count of
trades-hinge moments in the harvest is the four redirects, about
0.7 per engine county.

## The capture: the need state, at entry

A row that would say what decided a moment needs what the house was
missing when it asked - and that was the one thing the row did not
hold. The row now carries the house's need state as the election
opened: the shelves' word, the water's word, whether the hearth
burns, and who the house feuds with - read through the same
Standing verbs the need-pull reads inside the election, read once
at entry, because the deal writes the have-set mid-election and the
state the question is asked of is the state as it stood.

The have-set itself stays derived - the county's own arithmetic
over the roster, citable - and a house holding nothing reads as
holding nothing: the absent store stays absent in the row rather
than a dressed-up zero, because a nil store field serializes as
absent.

Two sanity runs before any border: a two-day plain county with the
need state present on every row, and a full engine county
reproducing `[C86]`'s County000 exactly - 305 moments, 768
member-rows - so the capture consumed no draw and `[C66]` holds
through it.

## Border 148, and its control

`tools/trades_moment_test.py`, in the gate, forcing both moments
through the tree's own instrument - the real prelude, the engine's
own name pools and profession definitions, the dump's own capture -
by wrapping the county's tick so the forcing runs at the first
tick, after the capture wrapper installs, so a forced election
lands as a real captured row rather than as the border's own
reading of the store.

| Property | Measured on the shipped tree |
|---|---|
| every row carries the need state | 5 of 5 captured rows, `captureFailures = 0` |
| a house holding nothing says so by absence | the redirect row's need holds no larder; the founding row's need holds none either |
| the redirect row shows the trade deciding | a trades-class member, dealt forager at pay 0, cook pay 4 in the row's own skills, `designationBefore` absent, `designationAfter` cook - the margin re-derived from the row, not trusted from the designation |
| the promotion row shows the need and the answer together | lean shelves in the row's need state (`word: lean, count: 0`), the outdoors hand pulled scout-to-forager, the settled hand's quartermaster work unmoved - one person changed, not the house reshuffled |
| the row records the trade's absence | the pulled hand's skills table reads forager pay minus one - no forager trade pays in this catalog, and the row says so |
| the vote is arithmetic, not contest | both rows' `leaderAfter` is the member the border boosted, never the hinge person |

Its control is the `[C87]` tree, which fails naming five things:
all five captured rows carry no need state, no captured row carries
the lean shelves the border set, the dump holds no need block, no
`[C88]` record, and the gate does not run the border - while the
same forcing still shows the cook's redirect in the C87 rows, which
is the point: the border measures the capture, not the county.

## The harvest, and what comes next

The scaled harvest launched with the capture in place: 120 engine
counties at 1096 days, six workers. The first six reproduce the
`[C86]` counties exactly, now with the need state on every row. The
next batch authors the dataset proposal from it - the redirect rows
where the trade is the hinge, the promotion rows where the need is,
with the trade's absence recorded in the skills table - landing in
the dataset repo as a proposal the operator rules on.

- **The dead.** Unchanged from the ruling: decided inside the sister
  seam, nothing here touches the zombie-belief set.
- **The flag.** `--engine` still moves to the default only after the
  operator has read rows authored from an engine dump - which is
  the next batch's proposal.

## No mod code

Nothing under `mod/` changes. The dump's capture, its docstring, a
new border, and the gate's wiring are the whole of it.