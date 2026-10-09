#!/usr/bin/env python3
"""Exercise the historical/live civil-hour join in installed Kahlua.

The county-hour stamps stay on their saved axis. The civil hour used by
bodyless rest has a midnight historical phase and a native live phase.
"""
from __future__ import annotations

import pathlib
import tempfile

import county_clock_test as clock


EXPECTED = {
    "hist22": "22", "hist22join": "240", "hist239": "23",
    "hist239join": "240", "join240": "7", "live241": "8",
    "live242": "9", "noon": "12", "onepm": "13",
    "missinglive": "nil", "historywithoutlive": "23",
    "historywithoutlivejoin": "240", "lastcatchuptick": "0",
    "invalidowed": "nil",
}


def run(history_path: pathlib.Path) -> dict[str, str]:
    return clock.numbers(clock.value(clock.probe(clock.CIVIL_REPLAY, history_path)))


def main() -> int:
    if not all(path.is_file() for path in
               (clock.PZ, clock.STDLIB, clock.SRC, clock.HISTORY)):
        print("SKIPPED civil-hour join: installed engine or source unavailable")
        return 0
    if not clock.build():
        print("FAIL civil-hour join: LuaRun compile")
        return 1
    got = run(clock.HISTORY)
    wrong = {key: (got.get(key), wanted) for key, wanted in EXPECTED.items()
             if got.get(key) != wanted}
    if wrong:
        print(f"FAIL civil-hour join: {wrong}")
        return 1

    source = clock.HISTORY.read_text(encoding="utf-8")
    mutations = (
        ("historical-segment", "if atHours < join then return atHours % HOURS_PER_DAY, join end",
         "if false then return atHours % HOURS_PER_DAY, join end", "hist239"),
        ("native-phase", "return (atHours + civil - (current % HOURS_PER_DAY)\n        + HOURS_PER_DAY) % HOURS_PER_DAY",
         "return atHours % HOURS_PER_DAY", "live242"),
    )
    with tempfile.TemporaryDirectory(prefix="sao-civil-join-") as folder:
        for label, before, after, witness in mutations:
            if source.count(before) != 1:
                print(f"FAIL civil-hour join: {label} mutation anchor")
                return 1
            path = pathlib.Path(folder) / f"{label}.lua"
            path.write_text(source.replace(before, after, 1), encoding="utf-8")
            altered = run(path)
            if altered.get(witness) == EXPECTED[witness]:
                print(f"FAIL civil-hour join: {label} mutation survived")
                return 1
    print(f"PASS civil-hour join: {len(EXPECTED)} Kahlua cases, 2 controls")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
