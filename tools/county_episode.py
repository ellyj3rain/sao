#!/usr/bin/env python3
"""Run, replay and export one causal production county as a bounded episode.

One episode advances once to its declared horizon and takes every checkpoint
from that causal prefix. A second isolated Kahlua process starts from the same
save identity and must reproduce the complete result exactly before export.
This is an execution/data instrument; it is not a replacement simulation and
does not fit outcomes back into generation rules.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
import pathlib
import sys
import tempfile
from typing import Any

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))
import county_sweep as Sweep  # noqa: E402


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"),
                      ensure_ascii=False, allow_nan=False).encode("utf-8")


def content_sha256(value: Any) -> str:
    return hashlib.sha256(canonical_bytes(value)).hexdigest()


def first_difference(left: Any, right: Any, path: str = "$") -> str | None:
    if type(left) is not type(right):
        return f"{path}: {type(left).__name__} != {type(right).__name__}"
    if isinstance(left, dict):
        if set(left) != set(right):
            missing = sorted(set(left) - set(right))
            added = sorted(set(right) - set(left))
            return f"{path}: keys removed={missing[:3]} added={added[:3]}"
        for key in sorted(left):
            changed = first_difference(left[key], right[key], f"{path}.{key}")
            if changed:
                return changed
        return None
    if isinstance(left, list):
        if len(left) != len(right):
            return f"{path}: length {len(left)} != {len(right)}"
        for index, (a, b) in enumerate(zip(left, right)):
            changed = first_difference(a, b, f"{path}[{index}]")
            if changed:
                return changed
        return None
    if left != right:
        return f"{path}: {left!r} != {right!r}"
    return None


def checkpoints_from(simulation: dict[str, Any], days: list[int]) -> list[dict[str, Any]]:
    snapshots = simulation.get("evidence", {}).get("snapshots", {})
    out = []
    for day in days:
        snapshot = snapshots.get(str(day))
        if not isinstance(snapshot, dict) or snapshot.get("completedDay") != day:
            raise Sweep.EvidenceError(f"episode checkpoint day {day} was not observed")
        out.append({"day": day, "snapshot": copy.deepcopy(snapshot)})
    return out


def episode_record(name: str, horizon: int, checkpoints: list[int],
                   simulation: dict[str, Any]) -> dict[str, Any]:
    evidence = simulation["evidence"]
    decisions = simulation["decisions"]
    terminal_fields = (
        "alive", "dead", "housesFounded", "survivorsJoined", "survivorsLeft",
        "housesStanding", "inAHouse", "biggestHouse", "housesGe4",
        "housesGe8", "housesGe15", "pacts", "pairsAtLine", "deadOnRosters",
        "meanNeuro", "afflicted", "infected", "turned", "zaoTurned",
        "zaoDead", "zaoInfected", "zaoAfflicted", "zaoCrossed",
    )
    record = {
        "schema": "sao-causal-episode",
        "schemaVersion": 1,
        "episodeId": name,
        "horizonDays": horizon,
        "seed": evidence.get("seed"),
        "drawCount": evidence.get("drawCount"),
        "checkpoints": checkpoints_from(simulation, checkpoints),
        "trajectory": {
            "dailySnapshots": copy.deepcopy(evidence.get("snapshots", {})),
            "socialEvents": copy.deepcopy(evidence.get("events", {})),
            "companies": copy.deepcopy(evidence.get("companies", {})),
            "deathCauses": copy.deepcopy(evidence.get("deathCauses", {})),
            "decisionCapture": copy.deepcopy(decisions),
            "processObservation": copy.deepcopy(
                decisions.get("processObservation", {})),
        },
        "terminal": {key: copy.deepcopy(simulation.get(key))
                     for key in terminal_fields},
        "source": copy.deepcopy(simulation.get("provenance", {})),
        "standing": "candidate-observation",
        "exclusions": [
            "loaded-gameplay-unobserved",
            "operator-judgment-not-recorded",
            "training-admission-not-recorded",
            "dormant-county-has-no-native-body-actions",
        ],
    }
    return record


def run_episode(name: str, horizon: int, checkpoints: list[int], *, lua: pathlib.Path,
                population: int | None, engine: bool, joint: bool,
                timeout: int) -> dict[str, Any]:
    if horizon <= 0 or not checkpoints or checkpoints[-1] > horizon:
        raise Sweep.EvidenceError("checkpoints must be nonempty and within the horizon")
    first = Sweep.one(name, lua, horizon, refill=None, population=population,
                      engine=engine, joint=joint, timeout=timeout)
    replay = Sweep.one(name, lua, horizon, refill=None, population=population,
                       engine=engine, joint=joint, timeout=timeout)
    changed = first_difference(first, replay)
    if changed:
        raise Sweep.EvidenceError(
            f"{name} did not replay exactly after isolated reset: {changed}")
    record = episode_record(name, horizon, checkpoints, first)
    record["replay"] = {
        "runs": 2,
        "reset": "fresh Kahlua process with no retained module-local state",
        "comparison": "complete canonical simulation result",
        "simulationSha256": content_sha256(first),
        "exact": True,
    }
    record["episodeSha256"] = content_sha256(record)
    return record


def run_episodes(horizon: int, checkpoints: list[int], runs: int, *,
                 lua: pathlib.Path | None = None, population: int | None = None,
                 engine: bool = True, joint: bool = True,
                 seed_prefix: str = "Episode", timeout: int = 3600) -> list[dict[str, Any]]:
    if runs <= 0 or horizon <= 0:
        raise Sweep.EvidenceError("positive run count and horizon required")
    points = sorted(set(int(day) for day in checkpoints))
    if not points or points[0] < 0 or points[-1] > horizon:
        raise Sweep.EvidenceError("checkpoint days must fall between zero and the horizon")
    lua_path = pathlib.Path(lua).resolve() if lua else ROOT / "mod/42.20/media/lua"
    Sweep.prepare(lua_path, engine, joint)
    return [run_episode(f"{seed_prefix}{index:03d}", horizon, points,
                        lua=lua_path, population=population, engine=engine,
                        joint=joint, timeout=timeout)
            for index in range(runs)]


def export_records(records: list[dict[str, Any]], path: pathlib.Path) -> None:
    target = pathlib.Path(path).resolve()
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8",
                                         dir=target.parent, delete=False) as stream:
            temporary = pathlib.Path(stream.name)
            for record in records:
                stream.write(json.dumps(record, sort_keys=True,
                                        allow_nan=False) + "\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.link(temporary, target)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--days", type=int, default=90)
    parser.add_argument("--checkpoints", default="0,7,30,90")
    parser.add_argument("--runs", type=int, default=1)
    parser.add_argument("--population", type=int)
    parser.add_argument("--lua")
    parser.add_argument("--out", help="new JSONL destination; existing evidence is preserved")
    parser.add_argument("--engine", action=argparse.BooleanOptionalAction, default=True)
    parser.add_argument("--joint", action=argparse.BooleanOptionalAction, default=True)
    parser.add_argument("--seed-prefix", default="Episode")
    parser.add_argument("--timeout", type=int, default=3600)
    args = parser.parse_args()
    try:
        checkpoints = [int(value.strip()) for value in args.checkpoints.split(",")]
        records = run_episodes(args.days, checkpoints, args.runs,
                               lua=pathlib.Path(args.lua) if args.lua else None,
                               population=args.population, engine=args.engine,
                               joint=args.joint, seed_prefix=args.seed_prefix,
                               timeout=args.timeout)
        if args.out:
            export_records(records, pathlib.Path(args.out))
            print(f"Recorded {len(records)} replay-proven episodes in {args.out}")
        else:
            for record in records:
                print(json.dumps(record, sort_keys=True))
        for record in records:
            decisions = record["trajectory"]["decisionCapture"]["eventCount"]
            processes = record["trajectory"].get("processObservation", {})
            terminal = record["terminal"]
            print(f"{record['episodeId']}: matters={processes.get('processCount', 0)} "
                  f"received={processes.get('receptionCount', 0)} "
                  f"contacts={processes.get('contactAttemptCount', 0)} "
                  f"arrivals={processes.get('contactArrivalCount', 0)} "
                  f"decisions={decisions} "
                  f"alive={terminal['alive']} dead={terminal['dead']} "
                  f"replay={record['replay']['simulationSha256']}", file=sys.stderr)
        return 0
    except (Sweep.EvidenceError, ValueError, OSError) as exc:
        print(f"FAILED: {exc}; no episode evidence accepted", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
