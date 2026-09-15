# C127 - The road joins a house

| Field | Record |
| --- | --- |
| Batch | `C127` |
| Date | 2026-09-15 |
| Name | The road joins a house |
| Status | Closed append-only batch - awaiting live receipts (a county where a road meeting writes trust without minting a two-person house, and where a unit of three that arrived together can still become a company) |
| Threads | [`T-004`](THREADS.md#t-004), [`T-007`](THREADS.md#t-007), [`T-008`](THREADS.md#t-008) |

## Record

Headless years against Knox at 1:15 living-to-zed (5667 people, DormantRisk 0.03, Day Zero off, no ZAO) produced 795 `formCompany` calls and 506 standing houses at day 365, mean size 2.3. Day 30 of the same county had 115 founded, which was in the band the operator called reasonable. The year was a pair mill.

The mill is the road door. `dormantEncounters` already writes trust, lessons, and doctrine. It then called `formCompany({idA, idB}, gA or gB or ("company-" .. idA))` whenever two people who were not both already housed cleared `companyStanding`. Genesis units sit at trust 0.50-0.85, so the door is already open. At 18 people a town that is a trickle. At a few hundred a town they share spawn points, distance zero, and the years pass mints a pair every other day for as long as anyone is alive.

Bonds are not companies. `[B38]` already said a unit is a bond, never a pre-formed faction, so the 3+ perception gate stays the company's. The road was ignoring that and notarizing a hello.

`roadCompanyTarget` is the door now:

- both housed: the meeting is schism, pact, feud, already handled above
- one housed: join that house, as before
- both unhoused, same `unitId`, three or more living mates: found that unit as a house
- otherwise: trust only

The sweep now reports `housesOf3` and `pacts` next to `housesStanding`, so a pair is not the headline.

This is not a new death rate and not a raised population default. Shipped scale is still 11 towns times 18. The 1:15 year had no ZAO pressure; Knox in the years still rides `DormantRisk`, so turning that dial down for "fewer zeds" also turned the pathogen down. That experiment is not this batch. Wiring ZAO into the same years is the next picture.

The C126 measured remainder (198, risk 1.0) is unchanged as the late-start *alive* curve. This batch changes how many houses that remainder founds. A 30-day remainder after the door: 41 alive, 16 founded, 4 standing, 3 of those three-or-more, 11 in a house, 0 pacts. Before the door that was 45 alive, 56 founded, 12 standing. Death is the same crash. The extra houses were the mill.

## What changed

- `mod/42.20/media/lua/client/SAO_Population.lua`: `roadCompanyTarget`; the road no longer mints `company-<id>`.
- `tools/county_sweep.py`: `housesOf3`, `pacts`.
- `tools/road_company_test.py`: Border 160, with a control that restores the mint.
- `tools/check.sh`: Border 160 in the gate.

## Verification

Border 160. Controlled: restoring `gA or gB or ("company-" .. idA)` flips the verdict.
