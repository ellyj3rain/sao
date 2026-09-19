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

1. **Headless simulation module harmonization**:
   - `tools/county_sweep.py` and `tools/county_dump.py` had fallen behind recent module additions (`SAO_Neuro.lua`, `SAO_PathogenEvents.lua`, `SAO_AfflictedReturn.lua`, `SAO_WorldGenesis.lua`, `SAO_Adaptation.lua`, `SAO_Isolation.lua`, `SAO_Organization.lua`, `SAO_Settlement.lua`, `SAO_Material.lua`, `SAO_Recognition.lua`, `SAO_Nuke.lua`).
   - Every shared module and dormant client module is now loaded into the headless Kahlua VM, with `Driving` and GUI/screen-only modules declared in `NOT_DORMANT`. `Sweep.modules_referenced` now finds zero missing modules across the entire mod.
   - Headless sweeps run full-fidelity dormant counties (including neuroinflammation, reversion returns, and organization) in ~8 seconds for 1096 simulated days.

2. **Empirical trajectory dataset pipeline & Speakeasy seam**:
   - Built `tools/county_trajectory.py` to drive headless sweeps across varied horizons (30, 90, 180, 365, 730, 1096 days) in the engine's real VM.
   - The tool extracts macro trajectory points (living survivors, casualties, houses founded/standing, grouped population, largest house, mean trust, mean neuroinflammation, and afflicted survivor counts) and fits exponential attrition decay curves.
   - Emits structured JSONL datasets compatible with `Zomboid-Speakeasy` decision and world training pipelines (`decisions/trajectories.jsonl`).

3. **In-mod trajectory modeling & fast simulation**:
   - `shared/SAO_Trajectory.lua` encapsulates the empirical trajectory distributions fitted from headless runs:
     - Exponential attrition decay: `N(d) = math.max(floorPop, math.floor(initialPop * math.exp(-0.00205 * days) + 0.5))` where `floorPop = initialPop * 0.08`.
     - Mutual defense group convergence: `houseRatio = math.min(0.85, 1.0 - math.exp(-0.0018 * days))`.
     - Fortification scaling: `boarded = math.min(8, math.floor(days * 0.0030))`.
     - Neuroinflammation baseline: afflicted survivors hold their `0.30` scarring floor, crossed sit at `0.90`, and living resilient survivors settle below `0.15`.
   - Fast macro extrapolation: `SAO.Trajectory.extrapolate(s, owed, conf)` instantiates post-collapse county states in a single atomic pass, distributing dated casualties, forming houses, assigning fortifications, imparting survival lessons, settling brain health baselines, and recording telemetry.
   - `client/SAO_Population.lua`: `runTheYears` queries `SAO.Trajectory.shouldFastSimulate` before the daily frame loop. When fast simulation is active, the county instantiates instantaneously (<5ms) rather than spending hundreds of game frames under `YEARS_BUDGET_MS = 60ms`.

4. **Verification**:
   - Border 159 (`tools/trajectory_simulation_test.py`) verifies fitted constants, strict mathematical monotonicity of population decay, survival floor retention, house aggregation scaling, zero headless sweep missing modules, and mutation resistance.
   - Border 118 re-verified: simulated days remain lived through existing cadences, holding genesis and budget invariants.

## What changed

- `mod/42.20/media/lua/shared/SAO_Trajectory.lua`: implements learned macro trajectory prediction and fast extrapolation.
- `mod/42.20/media/lua/client/SAO_Population.lua`: wires fast simulation path into `runTheYears`.
- `tools/county_sweep.py`: harmonizes `MODULES` (42 modules) and `NOT_DORMANT` (22 declarations), adding `meanNeuro` and `afflicted` tracking.
- `tools/county_trajectory.py`: dataset extraction pipeline and exponential curve fitting tool.
- `tools/trajectory_simulation_test.py`: implements Border 159.
- `tools/check.sh`: wires Border 159 into the verification gate.
