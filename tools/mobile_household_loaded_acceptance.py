#!/usr/bin/env python3
"""Verify the retained Build 42.21 mobile-household physical receipt."""
from __future__ import annotations

import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent
RECEIPT = ROOT / "artifacts/audits/c100-mobile-household-loaded-acceptance/loaded-receipt.json"


def check(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit("FAULT: " + message)


data = json.loads(RECEIPT.read_text(encoding="utf-8"))
check(data.get("schema") == "sao-mobile-household-loaded-receipt/1",
      "receipt schema differs")
check(data.get("engineVersion") == "42.21.0 4a0e9546ec", "engine version differs")
check(data.get("status") == "completed" and data.get("exitCode") == 0,
      "native run did not complete")
check(data.get("runtimeErrors") == [], "runtime error scanner was not clean")
check(data.get("datasetAdmission") == "unreviewed", "scenario was admitted without review")
check(data.get("behavioralVerdict") is None, "receipt invented a behavioral verdict")
for key in ("engineJarSha256", "packageSha256", "definitionSha256", "reportSha256",
            "observationSha256", "stdoutSha256"):
    check(re.fullmatch(r"[0-9a-f]{64}", str(data.get(key, ""))) is not None,
          key + " is not a bound SHA-256")
check(set(data.get("nativeCohort", ())) == {
    "PROJECTRVInterior42", "RollingRefuge",
    "Study-echo-creek-mobile-household-03f0a17c34f3",
    "SurvivorAwareness", "ZombieBuddy",
}, "exact native cohort differs")

map_dependency = data.get("mapDependency", {})
check(map_dependency.get("name") == "map_distanciado"
      and map_dependency.get("provider") == "PROJECTRVInterior42"
      and map_dependency.get("cells") == 44
      and (map_dependency.get("minCellX"), map_dependency.get("maxCellX"),
           map_dependency.get("minCellY"), map_dependency.get("maxCellY"))
      == (87, 97, 46, 49), "Project RV map dependency differs")

events = data.get("events", [])
check([row.get("kind") for row in events] == [
    "vehicle-spawned", "interior-entered", "physical-room-loaded", "exterior-returned"
], "physical transition event chain differs")
check([row.get("stdoutLine") for row in events] == sorted(
    row.get("stdoutLine") for row in events), "physical event order differs")

receipt = data.get("situationReceipt", {})
check(receipt.get("kind") == "mobile-household-loaded"
      and receipt.get("phase") == "completed" and receipt.get("result") == "completed",
      "mobile household situation did not complete")
check(receipt.get("script") == "Base.RollingRefuge"
      and receipt.get("vehicleId") == "mobile/1" and receipt.get("personId") == "sao-1",
      "native identities differ")
check(receipt.get("spawn") == {"x": 3782, "y": 10943, "z": 0}
      and receipt.get("moved") == {"x": 3792, "y": 10943, "z": 0},
      "exterior anchor movement differs")
interior = receipt.get("interior", {})
check(interior.get("loaded") is True and interior.get("outside") is False
      and interior.get("roomType") == "3x6caravan"
      and interior.get("floorSprite") == "floors_interior_carpet_01_7",
      "physical Project RV room differs")
check((interior.get("bodyX"), interior.get("bodyY"), interior.get("z"))
      == (22562, 12302, 0), "resident did not occupy the physical interior")
check(receipt.get("transitionCount") == 2 and receipt.get("materialRevision", 0) >= 1,
      "durable transition or material history differs")
check(receipt.get("spawnedAtHours", 0) <= receipt.get("enteredAtHours", 0)
      < receipt.get("exitInitiatedAtHours", 0) < receipt.get("exitedAtHours", 0),
      "transition timestamps are not ordered")
final, moved = receipt.get("final", {}), receipt.get("moved", {})
check((final.get("x") - moved.get("x")) ** 2
      + (final.get("y") - moved.get("y")) ** 2 <= 16
      and final.get("z") == moved.get("z"),
      "resident did not return beside the moved exterior anchor")

observation = data.get("observation", {})
coverage = observation.get("coverage", {})
check(observation.get("frames") == 6
      and observation.get("population", {}).get("captured") == 2,
      "bounded observation differs")
check(coverage.get("loadedSquares") == 2560
      and coverage.get("unavailableSquares") == 768
      and coverage.get("peopleComplete") is True
      and coverage.get("physicalCoverage") == "loaded-squares-only",
      "observation coverage differs")

print("213) mobile household loaded acceptance: Build 42.21 spawn, physical room, moved anchor and exit retained")
