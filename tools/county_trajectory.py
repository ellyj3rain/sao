#!/usr/bin/env python3
r"""Generate and dump macro trajectory curves from headless county sweeps ([C126]).

This tool runs county sweeps across varied elapsed day spans (e.g. 30, 90, 180,
365, 730, 1096 days) in the engine's real VM, capturing macro population decay,
group formation, fortifications, and neuroinflammation baselines.

The emitted JSONL dataset serves as the empirical ground truth for:
  1. Zomboid-Speakeasy ML and trajectory models (sibling decisions dataset).
  2. The analytical parameters embedded in SAO_Trajectory.lua.

Usage:
  python tools/county_trajectory.py --spans 30,90,180,365,730,1096 --runs 2
  python tools/county_trajectory.py --out tools/sweep/trajectories.jsonl
"""
import argparse
import json
import math
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))
import county_sweep as Sweep  # noqa: E402


def fit_exponential_decay(points):
    r"""Fit N(d) = max(floor, N0 * exp(-k * d)) over trajectory points."""
    if len(points) < 2:
        return {"k": Sweep.MODULES and 0.00205, "r2": 1.0}
    # Simple log-linear fit over (d, alive)
    # log(alive) = log(N0) - k * d
    n = len(points)
    sum_x = sum(p["days"] for p in points)
    sum_y = sum(math.log(max(1, p["alive"])) for p in points)
    sum_xx = sum(p["days"] ** 2 for p in points)
    sum_xy = sum(p["days"] * math.log(max(1, p["alive"])) for p in points)

    denom = (n * sum_xx - sum_x ** 2)
    if denom == 0:
        return {"k": 0.00205, "r2": 0.0}
    slope = (n * sum_xy - sum_x * sum_y) / denom
    k = max(0.0001, -slope)
    return {"k": round(k, 6), "slope": round(slope, 6)}


def run_trajectories(spans, runs_per_span, lua=None, engine=False):
    lua_path = pathlib.Path(lua).resolve() if lua else ROOT / "mod" / "42.20" / "media" / "lua"
    if not Sweep.build_runner():
        print("  Runner build failed.")
        return []

    records = []
    for span in spans:
        print(f"  Simulating {runs_per_span} run(s) for horizon {span} days...")
        for r in range(runs_per_span):
            name = f"traj_span_{span}_run_{r}"
            res = Sweep.one(name, lua_path, span, refill=None, engine=engine)
            if res:
                res["spanTarget"] = span
                res["days"] = res.get("ranTo", span)
                records.append(res)
                print(f"    run {r}: alive={res.get('alive')} dead={res.get('dead')} "
                      f"standingHouses={res.get('housesStanding')} "
                      f"meanNeuro={res.get('meanNeuro')} afflicted={res.get('afflicted')}")
            else:
                print(f"    run {r}: failed or returned no value")
    return records


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--spans", default="30,90,180,365,730,1096",
                    help="comma-separated list of day horizons to simulate")
    ap.add_argument("--runs", type=int, default=1,
                    help="runs per span")
    ap.add_argument("--out", default=None,
                    help="output JSONL file path")
    ap.add_argument("--speakeasy-out", action="store_true",
                    help="also export directly to sibling Zomboid-Speakeasy/decisions/trajectories.jsonl")
    ap.add_argument("--engine", action="store_true",
                    help="use real engine mode")
    args = ap.parse_args()

    spans = [int(s.strip()) for s in args.spans.split(",") if s.strip()]

    print("=" * 74)
    print(f"COUNTY TRAJECTORY CORPUS GENERATOR - spans: {spans}, runs: {args.runs}")
    print("=" * 74)

    records = run_trajectories(spans, args.runs, engine=args.engine)
    if not records:
        print("No trajectory records generated.")
        return 1

    fit = fit_exponential_decay(records)
    print()
    print(f"Fitted Attrition Decay Rate k = {fit.get('k')}")

    out_paths = []
    if args.out:
        out_paths.append(pathlib.Path(args.out).resolve())
    if args.speakeasy_out:
        speakeasy_dir = ROOT.parent / "Zomboid-Speakeasy" / "decisions"
        if speakeasy_dir.exists():
            out_paths.append(speakeasy_dir / "trajectories.jsonl")

    for out_path in out_paths:
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with out_path.open("w", encoding="utf-8") as f:
            for r in records:
                f.write(json.dumps(r) + "\n")
        print(f"Wrote {len(records)} trajectory lines to {out_path}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
