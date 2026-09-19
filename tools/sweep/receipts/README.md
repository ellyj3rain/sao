# C130 completed county receipts

These are completed causal SAO/ZAO runs in the installed game's Kahlua VM,
captured on 2026-09-18 (America/Los_Angeles). Each JSONL contains one independent
county, its daily observations, membership/death events, effective settings,
seed, engine registry counts, module load order, and SHA-256 provenance.

| Requested days | Governed population target | Result | Wall seconds | Living / dead | Final groups |
| --- | --- | --- | ---: | --- | --- |
| 90 | 12 | Complete: `c130-90d-pop12.jsonl` | 102.65 | 12 / 15 | Three pairs and one trio |
| 365 | 12 | Complete: `c130-365d-pop12.jsonl` | 209.71 | 12 / 60 | Two pairs |
| 7 | 500 | Refused: timeout at 600 seconds | 600 limit | Unreported | Unreported |

The scale attempt produced no accepted receipt or partial result. No larger
500-person run followed it. Timings include VM startup and provenance checks;
two evidence workers and repository validation overlapped. At about 391 seconds,
the scale JVM had used about 391 CPU seconds and 786 MB of working memory.

| Days | Peak observed group | Foundings / joins / leaves / endings | Death causes | ZAO stored states |
| --- | ---: | --- | --- | --- |
| 90 | 4 | 11 / 3 / 16 / 7 | 11 `the county took them`; 4 `zombie` | 11 dead; 3 afflicted; 1 turned |
| 365 | 3 | 15 / 3 / 29 / 13 | 33 `the county took them`; 27 `zombie` | 33 dead; 27 afflicted |

Foundings and endings count company lifetime periods, including re-formation of
an existing identifier. The observer reconciles actual rosters after outer
membership mutations and at daily observations; maxima include changes between
daily snapshots. The two surviving year-end companies had lasted approximately
129 and 124 days. Border 159 exercises actual append, election walkout, widow,
and schism transitions in Kahlua.

Both completed runs recorded zero failed protected calls, exactly 19,440,000 /
78,840,000 county ticks, and all 91 / 366 day snapshots. Death events equal the
dead-record and death-cause totals. Joint pathogen daily callbacks numbered
91 / 366, including day zero. Their 50 loaded-module hashes and 18 host/source
hashes match across the two receipts. The final 90-day output also matched the
earlier default-on run exactly after the separate Neuro disabled-option repair.

The population override governs the ongoing target and refill policy. It is not
a closed cohort: 27 / 72 total person records existed by the two endpoints.
Twelve living people therefore does not mean twelve original survivors. The
stored sandbox has `PopulationGoverned=true`, `RefillDays=2`, and
`NewcomersGoverned=false`; the shipped code resolves arrivals and refills.

History starts on 1993-07-09. Exact Gregorian game-start dates are 1993-10-07 and
1994-07-09, with real seeds `C130Independent000:1993-9-6` and
`C130Independent000:1994-6-8` (seed month/day fields are zero-based). Production
initialization uses the target start date for randomness and start year for
birth history. These horizons are independent initializations, not prefixes of
one cohort or a fitted survival trajectory. The start-year birth-history
limitation remains explicit.

Reproduce the completed horizons from the SAO repository, choosing a new output
path because existing evidence is preserved:

```powershell
python tools/county_trajectory.py --spans 90,365 --runs 1 --population 12 --engine --joint --seed-prefix C130Independent --timeout 1800 --out "$env:TEMP/c130-reproduction.jsonl"
```

The bounded scale attempt uses the same options with `--spans 7 --population 500
--timeout 600` and a different output path. No descriptive fit is requested.
The collector rejects missing dependencies, incomplete horizons, callback/VM
faults, timeouts, absent engine registries, and source changes during a run.

The host was Windows x86_64, Python 3.14.6, and Temurin OpenJDK 25.0.3+9. Engine
mode loaded 993 male names, 1,320 female names, 3,799 surnames and 25 professions.
Installed cell span was 256, read from game bytecode. Full paths and hashes live
in each receipt; key runtime hashes are:

| Runtime artifact | SHA-256 |
| --- | --- |
| Project Zomboid jar | `80e405a4bfc42f6072e75b3735f458a6514143da011d3226007ded305a442f44` |
| SAO jar (5.3.0.1) | `0abe4198166835b5f95f22215c4689dd9f3a787d03fdeccfe1e4285e112ac9be` |

These runs cover dormant records, the installed map/spawn data, and real engine
name/profession data. They do not exercise loaded bodies, physical actions,
chunk surveys, or the loaded-game presentation. ZAO state counts are stored
pathogen states across all recorded people; they overlap SAO death records and
must not be added to deaths or read as living populations. They do not establish
Afflicted live-body return. Single seeds do not establish a population-wide
distribution or acceptable gameplay. The original `../trajectories.jsonl` is
preserved separately and is not part of this accepted receipt set.
