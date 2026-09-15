# C128 - The years are lived on the live cadence

| Field | Record |
| --- | --- |
| Batch | `C128` |
| Date | 2026-09-15 |
| Name | The years are lived on the live cadence |
| Status | Closed append-only batch - awaiting live receipts (a 1996 start whose catch-up has hours in it: people go home at night and out in the morning, and a week of it takes longer than a bundled day used to) |
| Threads | [`T-007`](THREADS.md#t-007), [`T-002`](THREADS.md#t-002) |

## Record

The operator asked why the years go in days, and said the simulation has to be the game: granular, slow, day for day. [C45] had compressed a day into one bundle so three years took two minutes (F-055: the live cadence was five and a half hours). A bundle jumped the clock 24 hours, froze the hour at noon, and opened every cooldown at once. One move, one meeting wave, one attrition roll. Headless 1:15 and the C126 remainder curve were that machine, not a game day.

[C128] deletes `oneYearsDay` as the driver. `runTheYears` advances `yearsTicks` by `TICK_INTERVAL` (240), the live population step, and runs the same dormant stack the live county runs on that cadence. `yearsRun` is `floor(ticks / (9000 * 24))`. Hours are `ticks / 9000`. Time of day is that wrapped onto 0..24. When a day of ticks completes, age, ground, and `dailyCounty` fire once.

A 7-day remainder at 198 after this and [C127]: 186 alive, 12 dead, 15 standing houses, 13 of three or more, 44 in a house, biggest 4. The bundled day 7 was 177 alive, 21 dead, 25 standing of mean size ~2. Death is in the same band. The houses are units of three living a week of hours, not 25 pairs from one hello.

The C126 ANCHORS table is still the bundled curve. Fast simulation is still opt-in and still interpolates it. Remeasure under this cadence is owed. ZAO is still not in the years.

## What changed

- `mod/42.20/media/lua/client/SAO_Population.lua`: `yearsCadencePass`, `yearsDayRolled`; the years loop steps `TICK_INTERVAL`.
- `mod/42.20/media/lua/shared/SAO_History.lua`: hours and time of day from `yearsTicks`; `TICKS_PER_HOUR` named above the functions that close over it (a local declared after `countyHours` was nil in that function, attrition's pcall swallowed `ticks / nil`, and a 30-day county collected nobody).
- `tools/years_between_test.py`, `tools/county_clock_test.py`: the years take the live step.

## Verification

Border 118, 131, 153, 159, 160. 7-day headless remainder after the clock fix: 186 alive, 12 dead, 13 houses of three or more.
