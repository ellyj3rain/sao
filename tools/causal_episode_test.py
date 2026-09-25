#!/usr/bin/env python3
"""Border 195: production episodes have one prefix, clean reset and exact replay."""
from __future__ import annotations

import copy
import importlib.util
import pathlib
import tempfile
from unittest import mock

import county_episode as Episode
import county_sweep as Sweep


ROOT = pathlib.Path(__file__).resolve().parent.parent


def specimen() -> dict:
    snapshots = {
        str(day): {"completedDay": day, "observedHour": day * 24,
                   "alive": 4, "dead": day // 30, "groups": {},
                   "groupSizes": {}, "deathCauses": {}, "pathogenStates": {}}
        for day in (0, 7, 30)
    }
    return {
        "ranTo": 30, "yearsTicks": 30 * 216000, "completed": True,
        "alive": 4, "dead": 1, "housesFounded": 0, "survivorsJoined": 0,
        "survivorsLeft": 0, "housesStanding": 0, "inAHouse": 0,
        "biggestHouse": 0, "housesGe4": 0, "housesGe8": 0,
        "housesGe15": 0, "pacts": 0, "pairsAtLine": 0,
        "deadOnRosters": 0, "meanNeuro": 0.1, "afflicted": 0,
        "infected": 1, "turned": 0, "zaoTurned": 0, "zaoDead": 0,
        "zaoInfected": 1, "zaoAfflicted": 0, "zaoCrossed": 0,
        "evidence": {"seed": "Episode000:1993-10-7", "drawCount": 45,
                     "snapshots": snapshots, "events": {}, "companies": {},
                     "deathCauses": {}, "faultCount": 0, "faults": {},
                     "callbackCounts": {"simulateDay": 30}},
        "decisions": {"schema": "sao-coordination-decision-capture",
                      "schemaVersion": 1, "status": "observed",
                      "attemptedEvents": 1, "eventCount": 1,
                      "captureFailureCount": 0, "failures": [],
                      "events": [{"namespace": {"runId": "Episode000",
                                                  "county": "Episode000",
                                                  "personId": "p1",
                                                  "eventId": "Episode000/coordination/1",
                                                  "hour": 24}}]},
        "provenance": {"schema": "sao-simulation-evidence-v1",
                       "saveName": "Episode000", "seed": "Episode000:1993-10-7"},
    }


def rejects(call) -> bool:
    try:
        call()
    except Sweep.EvidenceError:
        return True
    return False


def main() -> int:
    faults: list[str] = []
    row = specimen()
    calls = []

    def repeated(name, lua, owed, **kwargs):
        calls.append((name, owed, kwargs.get("joint")))
        return copy.deepcopy(row)

    with mock.patch.object(Sweep, "prepare"), mock.patch.object(Sweep, "one", repeated):
        records = Episode.run_episodes(30, [0, 7, 30], 1,
                                       lua=ROOT / "mod/42.20/media/lua")
    if calls != [("Episode000", 30, True), ("Episode000", 30, True)]:
        faults.append("episode did not replay the same save and horizon in two processes")
    record = records[0]
    if ([point["day"] for point in record["checkpoints"]] != [0, 7, 30]
            or record["replay"]["exact"] is not True
            or record["trajectory"]["decisionCapture"]["eventCount"] != 1):
        faults.append("one-prefix checkpoints or decision trajectory were lost")
    sealed = {key: value for key, value in record.items()
              if key != "episodeSha256"}
    if record["episodeSha256"] != Episode.content_sha256(sealed):
        faults.append("episode seal omitted replay/reset evidence")

    changed = copy.deepcopy(row)
    changed["evidence"]["drawCount"] += 1
    with mock.patch.object(Sweep, "one", side_effect=[copy.deepcopy(row), changed]):
        if not rejects(lambda: Episode.run_episode(
                "Episode000", 30, [0, 30],
                lua=ROOT / "mod/42.20/media/lua", population=None,
                engine=True, joint=True, timeout=1)):
            faults.append("replay drift was accepted")

    missing = copy.deepcopy(row)
    del missing["evidence"]["snapshots"]["7"]
    with mock.patch.object(Sweep, "one", side_effect=[copy.deepcopy(missing),
                                                       copy.deepcopy(missing)]):
        if not rejects(lambda: Episode.run_episode(
                "Episode000", 30, [0, 7, 30],
                lua=ROOT / "mod/42.20/media/lua", population=None,
                engine=True, joint=True, timeout=1)):
            faults.append("unobserved checkpoint was accepted")

    # Defect control: disabling the exact-comparison branch must reverse the
    # drift verdict under the same two production results.
    source = pathlib.Path(Episode.__file__).read_text(encoding="utf-8")
    needle = "    if changed:\n        raise Sweep.EvidenceError("
    if source.count(needle) != 1:
        faults.append("replay comparison mutation did not locate its owner")
    else:
        with tempfile.TemporaryDirectory() as tmp:
            mutant_path = pathlib.Path(tmp) / "county_episode_mutant.py"
            mutant_path.write_text(source.replace(
                needle, "    if False:  # defect control accepts replay drift\n"
                        "        raise Sweep.EvidenceError("), encoding="utf-8")
            spec = importlib.util.spec_from_file_location("episode_mutant", mutant_path)
            mutant = importlib.util.module_from_spec(spec)
            assert spec.loader is not None
            spec.loader.exec_module(mutant)
            with mock.patch.object(Sweep, "one", side_effect=[copy.deepcopy(row), changed]):
                try:
                    mutant.run_episode("Episode000", 30, [0, 30],
                                       lua=ROOT / "mod/42.20/media/lua",
                                       population=None, engine=True, joint=True,
                                       timeout=1)
                except Sweep.EvidenceError:
                    faults.append("disabled replay comparison still rejected its defect")

    with tempfile.TemporaryDirectory() as tmp:
        target = pathlib.Path(tmp) / "episodes.jsonl"
        Episode.export_records(records, target)
        before = target.read_bytes()
        try:
            Episode.export_records(records, target)
            faults.append("existing episode evidence was overwritten")
        except FileExistsError:
            pass
        if target.read_bytes() != before:
            faults.append("refused export changed existing episode evidence")

    for fault in faults:
        print("195) FAULT:", fault)
    if faults:
        return 1
    print("  195) causal episodes: one-prefix checkpoints, isolated reset, exact replay, "
          "decision trajectory and exclusive export held; replay mutation flips")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
