# C126 - Learned trajectory and headless simulation for post-1993 starts

| Field | Record |
| --- | --- |
| Batch | `C126` |
| Date | 2026-09-14 |
| Name | Learned trajectory and headless simulation for post-1993 starts |
| Status | Closed append-only batch - learned trajectory & headless simulation |
| Threads | [`T-007`](THREADS.md#t-007), [`T-008`](THREADS.md#t-008), [`T-009`](THREADS.md#t-009) |

## Record

The operator ruled on 2026-09-14 that the project must prepare for playtesting with primitive simulation capability integrating with the sibling `Zomboid-Speakeasy` repository, connecting `survivor-awareness` headless simulation with ML and trajectory modeling to extrapolate county generation data for late starts (1994–1996) without taxing the CPU or causing in-game loading latency.

1. **The years actually run past sixty days.** After [C112] the cadence gate compared `History.ticks()` from hours-behind (thousands) to the years clock (the day being lived, tens). The clock went backwards, the gate never fired again, and any save that owed more days than one 60ms slice could chew froze at that slice — in the sweep and in play. `runTheYears` now keeps catching up every frame until the span ends. A 1096-day county finishes.

2. **Headless VM without the game jar.** `LuaRun` compiles against Kahlua alone (`tools/lib/kahlua-j2se.jar`, MIT kahlua2, the same `se.krka.kahlua` classes). `--engine` still loads `LuaRunEngine` by name when `projectzomboid.jar` is on the classpath. `county_sweep.py` honours `SAO_SWEEP_CACHE` for the Knox extract (`regions.lua`, `map.lua`) and no longer hard-requires the Windows JDK path. Module list covers the dormant county (42 loaded, `NOT_DORMANT` declared).

3. **Measured Knox curve, not an invented exponential.** Headless runs against the 11 shipped towns (198 genesis):

   | days | alive | houses standing |
   | --- | --- | --- |
   | 1 | 198 | 8 |
   | 7 | 177 | 25 |
   | 30 | 45 | 12 |
   | 90 | 7 | 1 |
   | 180 | 2 | 0 |
   | 365 | 1 | 0 |
   | 1096 | 0, 5 | 0, 1 |

   Most of the county dies in the first month. A handful remain at a year; three years is none or a few. A single exponential `N0 * exp(-0.00205 d)` with an 8% floor predicts 175 alive on day 30 and 16 at 1096. Neither happened. Houses collapse with the people; they do not converge toward 85%. `SAO_Trajectory.lua` interpolates these anchors. Fast extrapolation stays opt-in (`FastSimulation`). Default is first-principles years, which now complete.

4. **Speakeasy seam.** `tools/county_trajectory.py` drives the horizons and writes JSONL. `tools/sweep/trajectories.jsonl` is the corpus from the runs above.

5. **Verification.** Border 159 refuses the invented 0.00205 / 8% floor, refuses LuaRun compiling against `zombie.*`, refuses a cadence that cannot catch up, and checks the measured anchors.

## What changed

- `mod/42.20/media/lua/client/SAO_Population.lua`: years catch up every frame; opt-in fast path still wired.
- `mod/42.20/media/lua/shared/SAO_Trajectory.lua`: measured Knox anchors; predict interpolates; extrapolate is opt-in.
- `tools/luacheck/LuaRun.java`: compiles against Kahlua alone.
- `tools/luacheck/LuaRunEngine.java`: `--engine` helpers, compiled only with the game jar.
- `tools/lib/kahlua-j2se.jar`: bundled Kahlua2 (MIT).
- `tools/county_sweep.py`: portable Java, Kahlua fallback, `SAO_SWEEP_CACHE`.
- `tools/county_trajectory.py`: corpus extractor.
- `tools/sweep/trajectories.jsonl`: measured points.
- `tools/trajectory_simulation_test.py`: Border 159.
- `tools/check.sh`: Border 159 in the gate.
