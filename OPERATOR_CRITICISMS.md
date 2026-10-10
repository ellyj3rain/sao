# Operator criticisms — 2026-09-15

Not a batch. Runtime unchanged. These are the operator's objections, labelled so they can be picked up on the computer. Agent paraphrase is marked as such; quoted lines are the operator.

Open PRs this sits next to, not instead of: [C126 #62](https://github.com/ellyj3rain/sao/pull/62), [C127 #63](https://github.com/ellyj3rain/sao/pull/63), [C128 #64](https://github.com/ellyj3rain/sao/pull/64). C129 was written locally and was told not to be pushed.

---

## CLOCK — 365 days is 365 days

There is no sensible reason to collapse days and years. A year is 365 calendar days. If you simulate years, you simulate 365 times how many years. One to one.

Time *inside* a day is not one to one. It is variable. The default is one hour and thirty minutes of real time per in-game 24 hours.

> "Why are years going days? Why are we simulating years and days like what does that even mean … it needs to actually be like a very granular and slow simulation. Otherwise the data we're perceiving is not even reflective of how a game is ran."

C128 tried to live the cadence. That is the direction. It is not done, and it is not a twenty-minute job. A collapsed-year run that took fifty minutes does not imply a live year plus ZAO takes twenty.

## RIGOR — stop shipping tiny batches

C128 probably should not have been pushed. C129 should not have been pushed. Small batches for no real reason, not methodically rigorous.

Do not merge those as the work. Log this and keep measuring.

## HOUSE-SIZE — nobody asked for a cap of three

The operator did not set a house-size ceiling of three. Looked up on GitHub: it is not in any operator comment, issue, or PR.

What exists:

- **[B38]** — people *arrive* in twos and threes. Genesis composition, not a growth cap.
- **[A27]** — loners, band circles, unbounded houses. Three kinds of people. `Disposition.circleCap` then invented `3` for "band".
- **[C67 #12](https://github.com/ellyj3rain/sao/pull/12)** — already left this open: largest house measured was three, "whether the county should reach houses of eight or fifteen is a question about the gradient." Never answered.
- **[C127 #63](https://github.com/ellyj3rain/sao/pull/63)** — road join-only, mint only from genesis 3+. That was to stop the pair mill. Combined with the invented band cap it freezes `biggestHouse` at 3.

> "I don't see a sensible reason to cap houses at three people. I don't think I ever said anything like that … You would think as people learn more about what's happening, it would also be just as inclined to group up in larger groups."

`circleCap("house")` is already 999. Walk-out only fires when faith in the chair goes negative. The door never lets them use it. 50% of people want an unbounded house and never get one.

## DECAY — too many standing, not enough dying, pairs are not the metric

795 founded / 506 standing after a year is absurd. Too many people still alive. Not enough dying. Too many groups of two, three, four, and those are not what we are supposed to be measuring.

People pairing is real and we can see it. The rate is ridiculous. What is pertinent is what they decide to do when they get together.

115 at a shorter checkpoint was closer to reasonable than 506 at a year, and even 115 is probably still too many people at the end.

The machinery may be fine. The outcomes are not a real-world collapse, and they need to be extrapolatable from real-life theory about a situation like this.

## EARLY-KNOX — add people, subtract zeds

Vanilla start is not day zero. Lore says the start is during / at the beginning of the event; everybody has already turned. That contradicts itself. Measuring vanilla zed counts ("hundreds of thousands", 198 survivors) is not measuring pre-Knox, because pre-Knox would be regular people.

Work under: more living, fewer zeds. Ratios named: 1:10, 1:15, 1:20. Not day zero. Closer to it. Enough people in vicinity of each other that allyships can actually form as things decay, instead of everyone dying before groups stabilize.

## ZAO — without it the picture is incomplete

A county with no pathogen pressure is not the project. SAO alone is half the story. Years have to run with ZAO on the path. The live 1:15 year currently in the sandbox still shows ZAO living/infected/turned at 0 through day 5. That is a fact about the run, and it is a fact about the gap.

## METRIC — companies, not pair counts

Do not headline `housesStanding` of size 2–3. Headline: houses that grow past a band, what they do, whether they hold, whether they die, whether larger groups stabilize as knowledge of the event spreads.

## LIVE YEAR (sandbox, 2026-09-15/16, not a claim)

Same 1:15 county, live cadence, ZAO modules loaded, 5667 genesis. Watchdog on a 4 GB box after an OOM at `-Xmx4g`. Heap is 1800m. Pace ~50 min per calendar day.

| day | alive | dead | houses of 3 | biggest |
| --- | --- | --- | --- | --- |
| 0 | 5667 | 0 | 89 | 3 |
| 1 | 5667 | 0 | 376 | 3 |
| 2 | 5666 | 1 | 379 | 3 |
| 3 | 5665 | 2 | 383 | 3 |
| 4 | 5663 | 4 | 383 | 3 |
| 5 | 5662 | 5 | 386 | 3 |

The mill is day 1. Then almost nothing grows. Nobody makes a 4. ZAO has not touched anyone. This is the measurement the criticisms above are about, not a success.
